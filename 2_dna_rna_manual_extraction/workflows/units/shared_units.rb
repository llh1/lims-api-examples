require 'helpers/constant'

module Lims::Api::Examples
  module SharedUnits

    include Constant
    # TODO: to change when we'll want to use the automated extraction
    include Constant::DnaRnaManualExtraction

    def assign_batch
      # =======================================
      API::new_stage("Search the tubes by barcode and then search their corresponding order. Assign a batch to the tubes in the orders. Once the batch has been assigned, the tube gets the role binding.")
      # =======================================

      @barcodes.each do |barcodes_array|
        source_tube_uuids = []
        barcodes_array.each do |barcode|
          API::new_step("Find tube by barcode for #{barcode}")
          parameters = {:search => {:description => "search for barcoded tube",
                                    :model => "tube",
                                    :criteria => {:label => {:position => "barcode",
                                                             :type => BARCODE_EAN13,
                                                             :value => barcode}}}}
          search_response = API::post("searches", parameters)

          API::new_step("Get the search result (tube)")
          result_url = search_response["search"]["actions"]["first"]
          result_response = API::get(result_url) 
          source_tube_uuids << result_response["tubes"].first["uuid"]
        end

        API::new_step("Find the order by tube uuid and role")
        parameters = {:search => {:description => "search for order",
                                  :model => "order",
                                  :criteria => {:item => {:uuid => source_tube_uuids.first,
                                                          :role => ROLE_TUBE_TO_BE_EXTRACTED_NAP}}}}
        search_response = API::post("searches", parameters)

        API::new_step("Get the search results (order)")
        result_url = search_response["search"]["actions"]["first"]
        result_response = API::get(result_url)
        order = result_response["orders"].first
        order_uuid = order["uuid"]

        # Check that no batch has been assigned to the tubes
        no_batch = order["items"][ROLE_TUBE_TO_BE_EXTRACTED_NAP].reduce(true) { |m,e| m = m && e["batch"].nil? }
        abort("Error: A batch is already assigned to the source tube") unless no_batch

        unless @batch_uuid
          API::new_step("Create a new batch")
          parameters = {:batch => {}}
          response = API::post("batches", parameters)
          @batch_uuid = response["batch"]["uuid"]
        end

        API::new_step("Assign the batch uuid to the tubes in the order items")
        parameters = {:items => {ROLE_TUBE_TO_BE_EXTRACTED_NAP => {}.tap do |h|
          source_tube_uuids.each { |uuid| h.merge!({uuid => {:batch_uuid => batch_uuid}}) }
        end }}
        API::put(order_uuid, parameters)

        API::new_step("Add the tube_to_be_extracted_nap under the role binding_tube_to_be_extracted_nap and start them.")
        parameters = parameters_for_adding_resources_in_order(ROLE_BINDING_TUBE_TO_BE_EXTRACTED_NAP => source_tube_uuids)
        API::put(order_uuid, parameters)

        API::new_step("Change the status of binding_tube_to_be_extracted_nap to done. Change the status of tube_to_be_extracted_nap to unused.")
        parameters = parameters_for_changing_items_status({
          ROLE_BINDING_TUBE_TO_BE_EXTRACTED_NAP => {:uuids => source_tube_uuids, :event => :complete},
          ROLE_TUBE_TO_BE_EXTRACTED_NAP => {:uuids => source_tube_uuids, :event => :unuse}
        })
        API::put(order_uuid, parameters)
      end
      
      API::new_step("Add the kit barcode to the batch")
      parameters = { :kit => KIT_BARCODE }
      API::put(@batch_uuid, parameters)
    end


    def search_orders_by_batch
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
      order_uuids = result_response["orders"].reduce([]) { |m,e| m << e["uuid"] }
      source_tube_uuids_array = [].tap do |arr|
        result_response["orders"].each do |o|
          arr << o["items"][ROLE_BINDING_TUBE_TO_BE_EXTRACTED_NAP].map { |item| item["uuid"] }
        end
      end

      {:order_uuids => order_uuids, :source_tube_uuids_array => source_tube_uuids_array}
    end
  end
end

