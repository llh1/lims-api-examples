require 'helper/constant'
require 'rubygems'
require 'ruby-debug/debugger'

# This script goes through the different steps 
# of the DNA+RNA manual extraction pipeline.

module Lims::Api::Examples
  module DnaRnaManualExtraction    

    include Constant
    include Constant::DnaRnaManualExtraction

    private

    def dna_rna_manual_extraction_workflow
      # =======================================
      API::new_stage("Search the tubes by barcode and then search their corresponding order. Assign a batch to the tubes in the orders.")
      # =======================================

      @barcodes.each do |barcodes_array|
        API::new_step("Find the tubes by barcodes for #{barcodes_array.to_s}")
        parameters = {:search => {:description => "search for barcoded tube",
                                  :model => "tube",
                                  :criteria => {:label => {:position => "barcode",
                                                           :type => "sanger-barcode",
                                                           :value => barcodes_array}}}}
        search_response = API::post("searches", parameters)

        API::new_step("Get the search results (tubes)")
        result_url = search_response["search"]["actions"]["first"]
        result_response = API::get(result_url) 
        source_tube_uuids = result_response["tubes"].reduce([]) { |m,e| m << e["tube"]["uuid"] }
        @parameters[:source_tube_uuids] ||= []
        @parameters[:source_tube_uuids] << source_tube_uuids

        API::new_step("Find the order by tube uuid and role")
        parameters = {:search => {:description => "search for order",
                                  :model => "order",
                                  :criteria => {:item => {:uuid => source_tube_uuids.first,
                                                          :role => ROLE_TUBE_TO_BE_EXTRACTED}}}}
        search_response = API::post("searches", parameters)

        API::new_step("Get the search results (order)")
        result_url = search_response["search"]["actions"]["first"]
        result_response = API::get(result_url)
        order = result_response["orders"].first["order"]
        order_uuid = order["uuid"]

        # Check that no batch has been assigned to the tubes
        no_batch = order["items"][ROLE_TUBE_TO_BE_EXTRACTED].reduce(true) { |m,e| m = m && e["batch"].nil? }
        abort("Error: A batch is already assigned to the source tube") unless no_batch

        unless @batch_uuid
          API::new_step("Create a new batch")
          parameters = {:batch => {}}
          response = API::post("batches", parameters)
          @batch_uuid = response["batch"]["uuid"]
        end

        API::new_step("Assign the batch uuid to the tubes in the order items")
        parameters = {:items => {ROLE_TUBE_TO_BE_EXTRACTED => {}.tap do |h|
          source_tube_uuids.each { |uuid| h.merge!({uuid => {:batch_uuid => batch_uuid}}) }
        end }}
        API::put(order_uuid, parameters)
      end


      # =========================================== 
      API::new_stage("Search the orders by batch")
      # ===========================================
      API::new_step("Create the search order by batch")
      parameters = {:search => {:description => "search order by batch",
                                :model => "order",
                                :criteria => {:item => {:batch => @batch_uuid}}}}
      search_response = API::post("searches", parameters)

      API::new_step("Get the result orders")
      result_url = search_response["search"]["actions"]["first"]
      result_response = API::get(result_url)
      order_uuids = result_response["orders"].reduce([]) { |m,e| m << e["order"]["uuid"] }


      order_nb = 0
      order_uuids.zip(@parameters[:source_tube_uuids]).each do |order_uuid, source_tube_uuids|
        order_nb += 1
        n_entries = source_tube_uuids.size

        API::new_order(order_nb)

        # =========================
        API::new_stage("[Order #{order_nb}] Build and start the order")
        # =========================

        API::new_step("Change the status of the order to pending")
        parameters = {:event => :build}
        API::put(order_uuid, parameters)

        API::new_step("Change the status of the order to in_progress")
        parameters = {:event => :start}
        API::put(order_uuid, parameters)


        # ============================================
        API::new_stage("[Order #{order_nb}] Create binding_spin_columns_dna spin columns. Create by_product_tube tubes. Transfers from tube_to_be_extracted into binding_spin_column_dna and by_product_tube tubes.") 
        # ============================================

        API::new_step("Create new spin columns")
        binding_spin_column_dna_uuids = factory(:spin_column, n_entries)

        API::new_step("Create new tubes ")
        by_product_tube_uuids = factory(:tube, n_entries) 

        API::new_step("Add the new spin columns and new tubes in the order and start each of them")
        parameters = parameters_for_adding_resources_in_order({
          ROLE_BINDING_SPIN_COLUMN_DNA => binding_spin_column_dna_uuids,
          ROLE_BY_PRODUCT_TUBE => by_product_tube_uuids})
        API::put(order_uuid, parameters)

        API::new_step("Transfers from tube_to_be_extracted into binding_spin_column_dna spins and into by_product_tube tubes.")
        parameters = parameters_for_transfer([
          {:source => source_tube_uuids, :target => binding_spin_column_dna_uuids, :fraction => 0.5, :aliquot_type => ALIQUOT_TYPE_DNA},
          {:source => source_tube_uuids, :target => by_product_tube_uuids, :fraction => 0.5, :aliquot_type => ALIQUOT_TYPE_RNAP}
        ])
        API::post("actions/transfer_tubes_to_tubes", parameters)

        API::new_step("Change the status of the binding_spin_column_dna to done. Change the status of the by_product_tube to done. Change the status of the tube_to_be_extracted to unused")
        parameters = parameters_for_changing_items_status({
          ROLE_BINDING_SPIN_COLUMN_DNA => {:uuids => binding_spin_column_dna_uuids, :event => :complete},
          ROLE_BY_PRODUCT_TUBE => {:uuids => by_product_tube_uuids, :event => :complete},
          ROLE_TUBE_TO_BE_EXTRACTED => {:uuids => source_tube_uuids, :event => :unuse}
        })
        API::put(order_uuid, parameters)


        # ==============================================
        API::new_stage("[Order #{order_nb}] Use the binding_spin_column_dna spins in a new role elution_spin_column_dna. Then transfer the content of the spin columns to new extracted_tube tubes.")
        # ==============================================

        API::new_step("Add the binding_spin_column_dna under the role elution_spin_column_dna and start them.")
        elution_spin_column_dna_uuids = binding_spin_column_dna_uuids # alias
        parameters = parameters_for_adding_resources_in_order(ROLE_ELUTION_SPIN_COLUMN_DNA => elution_spin_column_dna_uuids)
        API::put(order_uuid, parameters)

        API::new_step("Change the status of elution_spin_column_dna to done. Change the status of binding_spin_column_dna to unused ")
        parameters = parameters_for_changing_items_status({
          ROLE_ELUTION_SPIN_COLUMN_DNA => {:uuids => elution_spin_column_dna_uuids, :event => :complete},
          ROLE_BINDING_SPIN_COLUMN_DNA => {:uuids => binding_spin_column_dna_uuids, :event => :unuse}
        })
        API::put(order_uuid, parameters)

        API::new_step("Create new tubes ")
        extracted_tube_dna_uuids = factory(:tube, n_entries)

        API::new_step("Add the extracted_dna_tube in the order and start them")
        parameters = parameters_for_adding_resources_in_order(ROLE_EXTRACTED_TUBE => extracted_tube_dna_uuids)
        API::put(order_uuid, parameters)

        API::new_step("Transfer elution_spin_column_dna into extracted_tube")
        parameters = parameters_for_transfer([{:source => elution_spin_column_dna_uuids, :target => extracted_tube_dna_uuids, :fraction => 1}])
        API::post("actions/transfer_tubes_to_tubes", parameters)

        API::new_step("Change the status of extracted_tube tubes to done. Change the status of elution_spin_column_dna to unused")
        parameters = parameters_for_changing_items_status({
          ROLE_EXTRACTED_TUBE => {:uuids => extracted_tube_dna_uuids, :event => :complete},
          ROLE_ELUTION_SPIN_COLUMN_DNA => {:uuids => elution_spin_column_dna_uuids, :event => :unuse}
        })
        API::put(order_uuid, parameters)


        # =====================================
        API::new_stage("[Order #{order_nb}] Create new tube_to_be_extracted tube. Transfer from by_product_tube into tube_to_be_extracted.")
        # =====================================

        API::new_step("Create new tubes ")
        tube_to_be_extracted_uuids = factory(:tube, n_entries)

        API::new_step("Add tube_to_be_extracted tubes in the order and start them.")
        parameters = parameters_for_adding_resources_in_order(ROLE_TUBE_TO_BE_EXTRACTED => tube_to_be_extracted_uuids)
        API::put(order_uuid, parameters)

        API::new_step("Transfer from by_product_tube tubes into tube_to_be_extracted tubes")
        parameters = parameters_for_transfer([{:source => by_product_tube_uuids, :target => tube_to_be_extracted_uuids, :fraction => 1}])
        API::post("actions/transfer_tubes_to_tubes", parameters)

        API::new_step("Change the status of by_product_tube to done. Change the status of tube_to_be_extracted to done")
        parameters = parameters_for_changing_items_status({
          ROLE_TUBE_TO_BE_EXTRACTED => {:uuids => tube_to_be_extracted_uuids, :event => :complete},
          ROLE_BY_PRODUCT_TUBE => {:uuids => by_product_tube_uuids, :event => :unuse}
        })
        API::put(order_uuid, parameters)


        # =============================================
        API::new_stage("[Order #{order_nb}] Create binding_spin_column_rna spins. Create by_product_tube tubes. Transfer tube_to_be_extracted into binding_spin_column_rna and into by_product_tube.")
        # =============================================

        API::new_step("Create new spin columns")
        binding_spin_column_rna_uuids = factory(:spin_column, n_entries)

        API::new_step("Create new tubes ")
        by_product_tube_uuids = factory(:tube, n_entries)

        API::new_step("Add the new spin columns and new tubes in the order and start each of them")
        parameters = parameters_for_adding_resources_in_order({ROLE_BINDING_SPIN_COLUMN_RNA => binding_spin_column_rna_uuids,
                                                               ROLE_BY_PRODUCT_TUBE => by_product_tube_uuids})
        API::put(order_uuid, parameters)

        API::new_step("Transfers from tube_to_be_extracted into binding_spin_column_rna spins and into by_product_tube tubes.")
        parameters = parameters_for_transfer([
          {:source => tube_to_be_extracted_uuids, :target => binding_spin_column_rna_uuids, :fraction => 0.5, :aliquot_type => ALIQUOT_TYPE_RNA},
          {:source => tube_to_be_extracted_uuids, :target => by_product_tube_uuids, :fraction => 0.5}
        ])
        API::post("actions/transfer_tubes_to_tubes", parameters)

        API::new_step("Change the status of binding_spin_column_rna to done. Change the status of by_product_tube to done. Change the status of tube_to_be_extracted to unused")
        parameters = parameters_for_changing_items_status({
          ROLE_BINDING_SPIN_COLUMN_RNA => {:uuids => binding_spin_column_rna_uuids, :event => :complete},
          ROLE_BY_PRODUCT_TUBE => {:uuids => by_product_tube_uuids, :event => :complete},
          ROLE_TUBE_TO_BE_EXTRACTED => {:uuids => tube_to_be_extracted_uuids, :event => :unuse}
        })
        API::put(order_uuid, parameters)


        # ==============================================
        API::new_stage("[Order #{order_nb}] Use the binding_spin_column_rna spins in a new role elution_spin_column_rna. Then transfer the content of the spin columns to new extracted_tube tubes.")
        # ==============================================

        API::new_step("Add the binding_spin_column_rna under the role elution_spin_column_rna and start them.")
        elution_spin_column_rna_uuids = binding_spin_column_rna_uuids # alias
        parameters = parameters_for_adding_resources_in_order(ROLE_ELUTION_SPIN_COLUMN_RNA => elution_spin_column_rna_uuids)
        API::put(order_uuid, parameters)

        API::new_step("Change the status of elution_spin_column_rna to done. Change the status of binding_spin_column_rna to unused ")
        parameters = parameters_for_changing_items_status({
          ROLE_ELUTION_SPIN_COLUMN_RNA => {:uuids => elution_spin_column_rna_uuids, :event => :complete},
          ROLE_BINDING_SPIN_COLUMN_RNA => {:uuids => binding_spin_column_rna_uuids, :event => :unuse}
        })
        API::put(order_uuid, parameters)

        API::new_step("Create new tubes ")
        extracted_tube_rna_uuids = factory(:tube, n_entries)

        API::new_step("Add the extracted_rna_tube in the order and start them")
        parameters = parameters_for_adding_resources_in_order(ROLE_EXTRACTED_TUBE => extracted_tube_rna_uuids)
        API::put(order_uuid, parameters)

        API::new_step("Transfer elution_spin_column_rna into extracted_tube")
        parameters = parameters_for_transfer([{:source => elution_spin_column_rna_uuids, :target => extracted_tube_rna_uuids, :fraction => 1}])
        API::post("actions/transfer_tubes_to_tubes", parameters)

        API::new_step("Change the status of extracted_tube tubes to done. Change the status of elution_spin_column_rna to unused")
        parameters = parameters_for_changing_items_status({
          ROLE_EXTRACTED_TUBE => {:uuids => extracted_tube_rna_uuids, :event => :complete},
          ROLE_ELUTION_SPIN_COLUMN_RNA => {:uuids => elution_spin_column_rna_uuids, :event => :unuse}
        })
        API::put(order_uuid, parameters)


        # ============================================
        API::new_stage("[Order #{order_nb}] Change the status of the order to completed.")
        # ============================================

        parameters = {:event => :complete}
        API::put(order_uuid, parameters)


        # Pass parameters needed to continue the workflow in
        # post extraction tube racking
        @parameters[:post_extraction] ||= {}
        @parameters[:post_extraction][order_nb] = {:order_uuid => order_uuid, 
                       :batch_uuid => batch_uuid,
                       :extracted_tube_uuids => {:RNA => extracted_tube_rna_uuids,
                                                 :DNA => extracted_tube_dna_uuids}}
      end
    end
  end
end
