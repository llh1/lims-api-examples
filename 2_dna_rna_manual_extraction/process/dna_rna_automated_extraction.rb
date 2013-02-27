require 'helper/constant'

module Lims::Api::Examples
  module DnaRnaAutomatedExtraction
    include Constant
    include Constant::DnaRnaAutomatedExtraction

    def self.start
      workflow
    end

    private
    
    def self.workflow
      # =======================================
      # Search the source tube in the order and
      # assign it a batch
      # =======================================
      # Find the tube by barcode
      parameters = {:search => {:description => "search for barcoded tube",
                                :model => "tube",
                                :criteria => {:label => {:position => "barcode",
                                                         :type => "sanger-barcode",
                                                         :value => SOURCE_TUBE_BARCODE}}}}
      search_response = API::post("searches", parameters)
      result_url = search_response["search"]["actions"]["first"]
      result_response = API::get(result_url) 
      source_tube_uuid = result_response["tubes"].first["tube"]["uuid"]

      # Find the order by tube uuid and role
      parameters = {:search => {:description => "search for order",
                                :model => "order",
                                :criteria => {:item => {:uuid => source_tube_uuid,
                                                        :role => ROLE_TUBE_TO_BE_EXTRACTED}}}}
      search_response = API::post("searches", parameters)
      result_url = search_response["search"]["actions"]["first"]
      result_response = API::get(result_url)
      order = result_response["orders"].first["order"]
      order_uuid = order["uuid"]

      # Check that no batch has been assigned to the tube
      no_batch = order["items"][ROLE_TUBE_TO_BE_EXTRACTED].select do |item|
        item["uuid"] == source_tube_uuid 
      end.first["batch"].nil?

      abort("Error: A batch is already assigned to the source tube") unless no_batch

      # Create a new batch
      parameters = {:batch => {}}
      response = API::post("batches", parameters)
      batch_uuid = response["batch"]["uuid"]

      # Assign the batch uuid to the tube in the order item
      parameters = {:items => {ROLE_TUBE_TO_BE_EXTRACTED => {source_tube_uuid => {:batch_uuid => batch_uuid}}}}
      API::put(order_uuid, parameters)

      # =========================
      # Build and start the order
      # =========================

      # Change the status of the order to pending
      parameters = {:event => :build}
      API::put(order_uuid, parameters)

      # Change the status of the order to in_progress
      parameters = {:event => :start}
      API::put(order_uuid, parameters)

      # =====================================================
      # Create eppendorf a tube
      # create aliquot a tube
      # Transfer the tube_to_be_extracted to eppendorf_a tube
      # and to aliquot a tube
      # =====================================================
      # Create the tube appendorf a 
      parameters = {:tube => {}}
      response = API::post("tubes", parameters)
      aliquot_a_tube_uuid = response["tube"]["uuid"]

      # Create the tube eppendorf a
      parameters = {:tube => {}}
      response = API::post("tubes", parameters)
      eppendorf_a_tube_uuid = response["tube"]["uuid"]

      # Barcode the tube eppendorf a
      parameters = {:labellable => {:name => eppendorf_a_tube_uuid,
                                    :type => "resource",
                                    :labels => {"barcode" => {:type => "sanger-barcode",
                                                              :value => EPPENDORF_A_DNA_BARCODE}}}}
      API::post("labellables", parameters)

      # Add the new tubes in the order and start them
      parameters = {:items => {
        ROLE_ALIQUOT_A => {aliquot_a_tube_uuid => {:event => :start, :batch_uuid => batch_uuid}},
        ROLE_EPPENDORF_A => {eppendorf_a_tube_uuid => {:event => :start, :batch_uuid => batch_uuid}}}}
      API::put(order_uuid, parameters)

      # Transfer
      parameters = {:transfer_tubes_to_tubes => {:transfers => [
        {:source_uuid => source_tube_uuid,
         :target_uuid => aliquot_a_tube_uuid,
         :fraction => 0.5}, 
         {:source_uuid => source_tube_uuid,
          :target_uuid => eppendorf_a_tube_uuid,
          :fraction => 0.5,
          :aliquot_type => ALIQUOT_TYPE_DNA}
      ]}}
      API::post("actions/transfer_tubes_to_tubes", parameters)

      # Change the status of source tube to unused,
      # aliquot_a tube to done and eppendorf_a to done
      parameters = {:items => {
        ROLE_TUBE_TO_BE_EXTRACTED => {source_tube_uuid => {:event => :unuse}},
        ROLE_ALIQUOT_A => {aliquot_a_tube_uuid => {:event => :complete}},
        ROLE_EPPENDORF_A => {eppendorf_a_tube_uuid => {:event => :complete}}}}
      API::put(order_uuid, parameters)

      # ==============================================
      # Create aliquot b tube 
      # Transfer fron aliquot a tube to aliquot b tube
      # ==============================================
      # Create the tube aliquot b
      parameters = {:tube => {}}
      response = API::post("tubes", parameters)
      aliquot_b_tube_uuid = response["tube"]["uuid"]

      # Add the new tube in the order and start it
      parameters = {:items => {
        ROLE_ALIQUOT_B => {aliquot_b_tube_uuid => {:event => :start, :batch_uuid => batch_uuid}}}}
      API::put(order_uuid, parameters)

      # Transfer
      parameters = {:transfer_tubes_to_tubes => {:transfers => [
        {:source_uuid => aliquot_a_tube_uuid,
         :target_uuid => aliquot_b_tube_uuid,
         :fraction => 1}]}}
      API::post("actions/transfer_tubes_to_tubes", parameters)

      # Change the status of aliquot a tube to unused,
      # aliquot_b tube to done
      parameters = {:items => {
        ROLE_ALIQUOT_A => {aliquot_a_tube_uuid => {:event => :unuse}},
        ROLE_ALIQUOT_B => {aliquot_b_tube_uuid => {:event => :complete}}}}
      API::put(order_uuid, parameters)

      # ============================================
      # Create eppendorf b tube
      # Create aliquot c tube
      # Transfer from aliquot b to eppendorf b tube
      # end aliquot c tube
      # ============================================
      # Create the tube eppendorf b
      parameters = {:tube => {}}
      response = API::post("tubes", parameters)
      eppendorf_b_tube_uuid = response["tube"]["uuid"]

      # Barcode the tube eppendorf b
      parameters = {:labellable => {:name => eppendorf_b_tube_uuid,
                                    :type => "resource",
                                    :labels => {"barcode" => {:type => "sanger-barcode",
                                                              :value => EPPENDORF_B_RNA_BARCODE}}}}
      API::post("labellables", parameters)

      # Create the tube eppendorf c
      parameters = {:tube => {}}
      response = API::post("tubes", parameters)
      aliquot_c_tube_uuid = response["tube"]["uuid"]

      # Add the new tube in the order and start it
      parameters = {:items => {
        ROLE_ALIQUOT_C => {aliquot_c_tube_uuid => {:event => :start, :batch_uuid => batch_uuid}},
        ROLE_EPPENDORF_B => {eppendorf_b_tube_uuid => {:event => :start, :batch_uuid => batch_uuid}}}}
      API::put(order_uuid, parameters)

      # Transfer
      parameters = {:transfer_tubes_to_tubes => {:transfers => [
        {:source_uuid => aliquot_b_tube_uuid,
         :target_uuid => eppendorf_b_tube_uuid,
         :fraction => 0.5,
         :aliquot_type => ALIQUOT_TYPE_RNA},
         {:source_uuid => aliquot_b_tube_uuid,
          :target_uuid => aliquot_c_tube_uuid,
          :fraction => 0.5}]}}
      API::post("actions/transfer_tubes_to_tubes", parameters)

      # Change the status of aliquot b tube to unused,
      # aliquot_c tube to done
      # eppendorf b to done
      parameters = {:items => {
        ROLE_ALIQUOT_B => {aliquot_b_tube_uuid => {:event => :unuse}},
        ROLE_ALIQUOT_C => {aliquot_c_tube_uuid => {:event => :complete}},
        ROLE_EPPENDORF_B => {eppendorf_b_tube_uuid => {:event => :complete}}}}
      API::put(order_uuid, parameters)
 
      # ============================================
      # Change the status of the order to completed
      # ============================================

      parameters = {:event => :complete}
      API::put(order_uuid, parameters)
    end
  end
end
