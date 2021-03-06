require 'constant'

module Lims::Examples
  module ExampleManualExtraction
    module LoadTubesAndAssignBatch
      include Constant

      def load_tubes_and_assign_batch
        order_uuid = nil
        order = nil
        source_tube_uuids = []

        # Get the tubes by their barcodes
        @barcodes.each_with_index do |barcode,index|
          API::new_step("Find tube by barcode (#{barcode})")
          parameters = {:search => {:description => "search for barcoded tube",
                                    :model => "tube",
                                    :criteria => {:label => {:position => "barcode",
                                                             :type => BARCODE_EAN13,
                                                             :value => barcode}}}}
          search_response = API::post(@routes["searches"]["actions"]["create"], parameters)

          API::new_step("Get the search result (tube)")
          result_url = search_response["search"]["actions"]["first"]
          result_response = API::get(result_url) 
          tube_uuid = result_response["tubes"].first["uuid"]
          source_tube_uuids << tube_uuid 

          # Get the corresponding order
          # Only one time for the first tube
          if index == 0
            API::new_step("Find the order by tube uuid")
            parameters = {:search => {:description => "search for order",
                                      :model => "order",
                                      :criteria => {:item => {:uuid => tube_uuid}}}}
            search_response = API::post(@routes["searches"]["actions"]["create"], parameters)

            API::new_step("Get the search results (order)")
            result_url = search_response["search"]["actions"]["first"]
            result_response = API::get(result_url)
            order = result_response["orders"].first
            order_uuid = order["uuid"]
          end
        end

        second_tube_uuid = source_tube_uuids.last

        API::new_step("Create a new batch")
        parameters = {:batch => {}}
        response = API::post(@routes["batches"]["actions"]["create"], parameters)
        @batch_uuid = response["batch"]["uuid"]

        API::new_step("Find the order by tube uuid")
        parameters = {:search => {:description => "search for order",
                                  :model => "order",
                                  :criteria => {:item => {:uuid => second_tube_uuid}}}}
        search_response = API::post(@routes["searches"]["actions"]["create"], parameters)

        API::new_step("Get the search results (order)")
        result_url = search_response["search"]["actions"]["first"]
        result_response = API::get(result_url)
        order = result_response["orders"].first
        order_uuid = order["uuid"]

        API::new_step("Assign the batch uuid to the tubes in the order items")
        parameters = {:items => {ROLE_TUBE_TO_BE_EXTRACTED_NAP => {}.tap do |h|
          source_tube_uuids.each { |uuid| h.merge!({uuid => {:batch_uuid => @batch_uuid}}) }
        end }}
        API::put(order["actions"]["update"], parameters)

        search_orders_by_batch

        API::new_step("Add the tube_to_be_extracted_nap under the role binding_tube_to_be_extracted_nap and start them.")
        parameters = parameters_for_adding_resources_in_order(ROLE_BINDING_TUBE_TO_BE_EXTRACTED_NAP => source_tube_uuids)
        API::put(order["actions"]["update"], parameters)

        API::new_step("Change the status of binding_tube_to_be_extracted_nap to done. Change the status of tube_to_be_extracted_nap to unused.")
        parameters = parameters_for_changing_items_status({
          ROLE_TUBE_TO_BE_EXTRACTED_NAP => {:uuids => source_tube_uuids, :event => :unuse},
          ROLE_BINDING_TUBE_TO_BE_EXTRACTED_NAP => {:uuids => source_tube_uuids, :event => :complete}
        })
        API::put(order["actions"]["update"], parameters)

        result = search_orders_by_batch

        API::new_step("Get the initial tubes in the order")
        result[:source_tube_uuids].each do |tube_uuid|
          #API::get("#{API::root}/#{tube_uuid}")
          # Uncomment in production environment
          API::get("#{API::root}/lims-laboratory/#{tube_uuid}")
        end

        @order_uuid = order_uuid
        @order_update_url = order["actions"]["update"]
      end
    end
  end
end
