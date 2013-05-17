require 'constant'

module Lims::Examples
  module ExampleManualExtraction
    module ManualExtraction
      include Constant

      def manual_extraction
        order_uuid = @order_uuid
        order_update_url = @order_update_url

        # Create 2 spin columns and 2 tubes
        uuids = []
        2.times do
          API::new_step("Create a new spin column")
          parameters = {:spin_column => {}}
          response = API::post(@root_json["spin_columns"]["actions"]["create"], parameters)
          uuids << {:read => response["spin_column"]["actions"]["read"], :type => "spin_column", :contents => "DNA", :uuid => response["spin_column"]["uuid"]}

          API::new_step("Create a new tube")
          parameters = {:tube => {}}
          response = API::post(@root_json["tubes"]["actions"]["create"], parameters)
          uuids << {:read => response["tube"]["actions"]["read"], :type => "tube", :contents => "RNA+P", :uuid => response["tube"]["uuid"]}
        end

        # Create 4 barcodes
        barcode_values = []
        uuids.each do |e|
          API::new_step("Generate a new barcode")
          barcode_values << API::mock_barcode_generation(e[:type], e[:contents])          
        end

        # Assign barcodes to the new tubes and spin columns
        uuids.each do |e|
          API::new_step("Assign a barcode to the #{e[:type]} with the uuid=#{e[:uuid]}")
          barcode(e[:uuid], barcode_values.shift) 
        end

        # Get the barcoded resources
        uuids.each do |e|
          API::new_step("Get the barcoded #{e[:type]}")
          API::get(e[:read])
        end

        # Printer service
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
