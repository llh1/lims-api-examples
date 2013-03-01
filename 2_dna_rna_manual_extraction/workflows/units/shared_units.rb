require 'helpers/constant'

module Lims::Api::Examples
  module SharedUnits

    include Constant
    include Constant::DnaRnaManualExtraction
 
    def assign_batch
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
      order_uuids = result_response["orders"].reduce([]) { |m,e| m << e["order"]["uuid"] }
      source_tube_uuids_array = [].tap do |arr|
        result_response["orders"].each do |o|
          o["order"]["items"].each do |k,items|
            arr << items.reduce([]) { |m,e| m << e["uuid"] }
          end
        end
      end

      {:order_uuids => order_uuids, :source_tube_uuids_array => source_tube_uuids_array}
    end
  end
end

