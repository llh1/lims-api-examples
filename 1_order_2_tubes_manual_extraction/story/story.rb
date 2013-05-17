require 'constant'
require 'builder'

module Lims::Examples
  module ExampleManualExtraction
    class Story
      include Constant
      include Builder
      
      def initialize(barcodes)
        @barcodes = barcodes       
      end

      def start
        root
        load_tubes_and_assign_batch
        manual_extraction
      end

      private

      def root
        API::new_stage("Get the root JSON")
        API::new_step("Get the root JSON")
        @root_json = API::get_root
      end

      def load_tubes_and_assign_batch
        API::new_stage("Search the tubes by barcode and then search their corresponding order. Assign a batch to the tubes in the orders. Once the batch has been assigned, the tube gets the role binding.")
        order_uuid = nil
        order = nil
        source_tube_uuids = []
        tube_uuid = nil # just save the second tube uuid

        @barcodes.each_with_index do |barcode,index|
          API::new_step("Find tube by barcode (#{barcode})")
          parameters = {:search => {:description => "search for barcoded tube",
                                    :model => "tube",
                                    :criteria => {:label => {:position => "barcode",
                                                             :type => BARCODE_EAN13,
                                                             :value => barcode}}}}
          search_response = API::post(@root_json["searches"]["actions"]["create"], parameters)

          API::new_step("Get the search result (tube)")
          result_url = search_response["search"]["actions"]["first"]
          result_response = API::get(result_url) 
          tube_uuid = result_response["tubes"].first["uuid"]
          source_tube_uuids << tube_uuid 

          if index == 0
            API::new_step("Find the order by tube uuid")
            parameters = {:search => {:description => "search for order",
                                      :model => "order",
                                      :criteria => {:item => {:uuid => tube_uuid}}}}
            search_response = API::post(@root_json["searches"]["actions"]["create"], parameters)

            API::new_step("Get the search results (order)")
            result_url = search_response["search"]["actions"]["first"]
            result_response = API::get(result_url)
            order = result_response["orders"].first
            order_uuid = order["uuid"]
          end
        end

        unless @batch_uuid
          API::new_step("Create a new batch")
          parameters = {:batch => {}}
          response = API::post(@root_json["batches"]["actions"]["create"], parameters)
          @batch_uuid = response["batch"]["uuid"]
        end

        API::new_step("Find the order by tube uuid")
        parameters = {:search => {:description => "search for order",
                                  :model => "order",
                                  :criteria => {:item => {:uuid => tube_uuid}}}}
        search_response = API::post(@root_json["searches"]["actions"]["create"], parameters)

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
        result[:source_tube_uuids_array].each do |tube_uuid|
          API::get("#{API::root}/#{tube_uuid}")
          #API::get("#{API::root}/lims-laboratory/#{tube_uuid}")
        end

        {:order_uuid => order_uuid, :order_update_url => order["actions"]["update"]}
        @order_uuid = order_uuid
        @order_update_url = order["actions"]["update"]
      end


      def search_orders_by_batch
        API::new_stage("Search the orders by batch")
        API::new_step("Create the search order by batch")
        parameters = {:search => {:description => "search order by batch",
                                  :model => "order",
                                  :criteria => {:item => {:batch => @batch_uuid}}}}
        search_response = API::post(@root_json["searches"]["actions"]["create"], parameters)

        API::new_step("Get the result orders")
        result_url = search_response["search"]["actions"]["first"]
        result_response = API::get(result_url)

        order_uuids = result_response["orders"].reduce([]) { |m,e| m << e["uuid"] }
        source_tube_uuids_array = [].tap do |arr|
          result_response["orders"].each do |o|
            if o.has_key?("items") && o["items"].has_key?(ROLE_BINDING_TUBE_TO_BE_EXTRACTED_NAP)
              arr << o["items"][ROLE_BINDING_TUBE_TO_BE_EXTRACTED_NAP].map { |item| item["uuid"] }
            end
          end
        end

        {:order_uuids => order_uuids, :source_tube_uuids_array => source_tube_uuids_array.flatten}
      end


      def manual_extraction
        order_uuid = @order_uuid
        order_update_url = @order_update_url

        uuids = []
        2.times do
          API::new_step("Create new spin column")
          parameters = {:spin_column => {}}
          response = API::post(@root_json["spin_columns"]["actions"]["create"], parameters)
          uuids << {:read => response["spin_column"]["actions"]["read"], :type => "spin_column", :contents => "DNA", :uuid => response["spin_column"]["uuid"]}

          API::new_step("Create new tube")
          parameters = {:tube => {}}
          response = API::post(@root_json["tubes"]["actions"]["create"], parameters)
          uuids << {:read => response["tube"]["actions"]["read"], :type => "tube", :contents => "RNA+P", :uuid => response["tube"]["uuid"]}
        end

        barcode_values = []
        uuids.each do |e|
          API::new_step("Generate a new barcode")
          barcode_values << API::mock_barcode_generation(e[:type], e[:contents])          
        end

        uuids.each do |e|
          API::new_step("Add a barcode to #{e[:uuid]}")
          barcode(e[:uuid], barcode_values.shift) 
        end

        uuids.each do |e|
          API::new_step("Get the barcoded resource")
          API::get(e[:read])
        end

        API::new_step("Printer service")
        API::mock_printer_service

        result = search_orders_by_batch
        initial_tube_uuids = result[:source_tube_uuids_array]

        new_asset_uuids = [[uuids[0][:uuid], uuids[1][:uuid]], [uuids[2][:uuid], uuids[3][:uuid]]]
        new_asset_uuids.each do |uuid|
          API::new_step("Add the new spin column and new tube in the order and start each of them")
          parameters = parameters_for_adding_resources_in_order({
            ROLE_BINDING_SPIN_COLUMN_DNA => [uuid[0]],
            ROLE_BY_PRODUCT_TUBE_RNAP => [uuid[1]]})
          API::put(order_update_url, parameters)
        end

        transfer_uuids = [[initial_tube_uuids[0], uuids[0][:uuid], uuids[1][:uuid]], [initial_tube_uuids[1], uuids[2][:uuid], uuids[3][:uuid]]] 
        transfer_uuids.each do |uuid|
          API::new_step("Transfer from tube to spin column and tube")
          parameters = {:transfer_tubes_to_tubes => {:transfers => [
            {:source_uuid => uuid[0], :target_uuid => uuid[1], :fraction => 0.5, :aliquot_type => ALIQUOT_TYPE_DNA}, 
            {:source_uuid => uuid[0], :target_uuid => uuid[2], :fraction => 0.5, :aliquot_type => ALIQUOT_TYPE_RNAP}
          ]}}
          API::post(@root_json["transfer_tubes_to_tubes"]["actions"]["create"], parameters)
        end

      end
    end
  end
end
