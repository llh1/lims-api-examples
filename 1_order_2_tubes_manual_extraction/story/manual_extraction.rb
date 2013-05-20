require 'constant'

module Lims::Examples
  module ExampleManualExtraction
    module ManualExtraction
      include Constant

      def manual_extraction
        order_uuid = @order_uuid
        order_update_url = @order_update_url

        # Create 2 spin columns and 2 tubes
        spin_columns_dna = []
        tubes_rnap = []
        2.times do
          API::new_step("Create a new spin column")
          parameters = {:spin_column => {}}
          response = API::post(@routes["spin_columns"]["actions"]["create"], parameters)
          spin_columns_dna << {:read => response["spin_column"]["actions"]["read"], :type => "spin_column", :content => "DNA", :uuid => response["spin_column"]["uuid"]}

          API::new_step("Create a new tube")
          parameters = {:tube => {}}
          response = API::post(@routes["tubes"]["actions"]["create"], parameters)
          tubes_rnap << {:read => response["tube"]["actions"]["read"], :type => "tube", :content => "RNA+P", :uuid => response["tube"]["uuid"]}
        end

        # Add barcodes
        new_assets = spin_columns_dna.zip(tubes_rnap).flatten
        add_barcode_to_resources(new_assets)

        # Search the order by batch
        result = search_orders_by_batch
        initial_tube_uuids = result[:source_tube_uuids]

        # Add new spin columns and new tubes in the order and start them
        new_assets_uuids = [[spin_columns_dna[0][:uuid], tubes_rnap[0][:uuid]], [spin_columns_dna[1][:uuid], tubes_rnap[1][:uuid]]]
        new_assets_uuids.each do |uuids|
          API::new_step("Add the new spin column and new tube in the order and start each of them")
          parameters = {:items => {
            ROLE_BINDING_SPIN_COLUMN_DNA => {uuids[0] => {:event => :start, :batch_uuid => batch_uuid}},
            ROLE_BY_PRODUCT_TUBE_RNAP => {uuids[1] => {:event => :start, :batch_uuid => batch_uuid}}
          }}
          API::put(order_update_url, parameters)
        end

        # Transfer from initial tubes to new spin columns and new tubes
        transfer_uuids = [
          [initial_tube_uuids[0], spin_columns_dna[0][:uuid], tubes_rnap[0][:uuid]], 
          [initial_tube_uuids[1], spin_columns_dna[1][:uuid], tubes_rnap[1][:uuid]]
        ] 
        transfer_uuids.each do |uuids|
          API::new_step("Transfer from tube to spin column and tube")
          parameters = {:transfer_tubes_to_tubes => {:transfers => [
            {:source_uuid => uuids[0], :target_uuid => uuids[1], :fraction => 0.5, :aliquot_type => ALIQUOT_TYPE_DNA}, 
            {:source_uuid => uuids[0], :target_uuid => uuids[2], :fraction => 0.5, :aliquot_type => ALIQUOT_TYPE_RNAP}
          ]}}
          API::post(@routes["transfer_tubes_to_tubes"]["actions"]["create"], parameters)
        end

        # Change the status of binding tube to be extracted, binding spin columns dna 
        # and by product tube rnap to done
        transfer_uuids.each do |uuids|
          API::new_step("Change the status of the spin column and the tube")
          parameters = {:items => {
            ROLE_BINDING_TUBE_TO_BE_EXTRACTED_NAP => {uuids[0] => {:event => :unuse}},
            ROLE_BINDING_SPIN_COLUMN_DNA => {uuids[1] => {:event => :complete}},
            ROLE_BY_PRODUCT_TUBE_RNAP => {uuids[2] => {:event => :complete}}
          }}
          API::put(order_update_url, parameters)
        end

        # Create new tubes for extracted dna
        extracted_tubes_dna = []
        2.times do 
          API::new_step("Create a new tube")
          parameters = {:tube => {}}
          response = API::post(@routes["tubes"]["actions"]["create"], parameters)
          extracted_tubes_dna << {:read => response["tube"]["actions"]["read"], :type => "tube", :content => "DNA", :uuid => response["tube"]["uuid"]}
        end
        
        # Add barcodes
        add_barcode_to_resources(extracted_tubes_dna)

        # Add extracted DNA tubes in the order and start them
        extracted_tubes_dna.each do |tube|
          API::new_step("Add the new extracted tube dna in the order and start it")
          parameters = {:items => {ROLE_EXTRACTED_TUBE_DNA => {tube[:uuid] => {:event => :start, :batch_uuid => batch_uuid}}}}
          API::put(order_update_url, parameters)
        end

        # Transfer from spin columns dnas to extracted tubes dna 
        transfer_uuids = [
          [new_assets_uuids[0][0], extracted_tubes_dna[0][:uuid]], 
          [new_assets_uuids[1][0], extracted_tubes_dna[1][:uuid]]
        ] 
        transfer_uuids.each do |uuids|
          API::new_step("Transfer from spin column to extracted tube")
          parameters = {:transfer_tubes_to_tubes => {:transfers => [
            {:source_uuid => uuids[0], :target_uuid => uuids[1], :fraction => 1.0, :aliquot_type => ALIQUOT_TYPE_DNA}
          ]}}
          API::post(@routes["transfer_tubes_to_tubes"]["actions"]["create"], parameters)
        end

        # Change the status of spin columns to unused and extracted tubes to done
        transfer_uuids.each do |uuids|
          API::new_step("Change the status of the spin column and the extracted tube")
          parameters = {:items => {
            ROLE_BINDING_SPIN_COLUMN_DNA => {uuids[0] => {:event => :unuse}},
            ROLE_EXTRACTED_TUBE_DNA => {uuids[1] => {:event => :complete}}
          }}
          API::put(order_update_url, parameters)
        end

        # Create new tubes to be extracted
        tubes_to_be_extracted = []
        2.times do 
          API::new_step("Create a new tube")
          parameters = {:tube => {}}
          response = API::post(@routes["tubes"]["actions"]["create"], parameters)
          tubes_to_be_extracted << {:read => response["tube"]["actions"]["read"], :type => "tube", :content => "RNA+P", :uuid => response["tube"]["uuid"]}
        end

        # Add barcodes
        add_barcode_to_resources(tubes_to_be_extracted)

        # Add tubes to be extracted in the order and start them
        # TODO: check if the role name is correct
        tubes_to_be_extracted.each do |tube|
          API::new_step("Add the new tube to be extracted in the order and start it")
          parameters = {:items => {ROLE_TUBE_TO_BE_EXTRACTED_RNAP => {tube[:uuid] => {:event => :start, :batch_uuid => batch_uuid}}}}
          API::put(order_update_url, parameters)
        end

        # Transfer from by product tube rnap to tube to be extracted rnap
        transfer_uuids = [
          [new_assets_uuids[0][1], tubes_to_be_extracted[0][:uuid]], 
          [new_assets_uuids[1][1], tubes_to_be_extracted[1][:uuid]]
        ] 
        transfer_uuids.each do |uuids|
          API::new_step("Transfer from by product tube rnap to tube to be extracted rnap")
          parameters = {:transfer_tubes_to_tubes => {:transfers => [
            {:source_uuid => uuids[0], :target_uuid => uuids[1], :fraction => 1.0, :aliquot_type => ALIQUOT_TYPE_RNAP}
          ]}}
          API::post(@routes["transfer_tubes_to_tubes"]["actions"]["create"], parameters)
        end

        # Change the status of by product tube rnap to unused and tube to be extracted rnap to done
        transfer_uuids.each do |uuids|
          API::new_step("Change the status of the by product tube and the tube to be extracted")
          parameters = {:items => {
            ROLE_BY_PRODUCT_TUBE_RNAP => {uuids[0] => {:event => :unuse}},
            ROLE_TUBE_TO_BE_EXTRACTED_RNAP => {uuids[1] => {:event => :complete}}
          }}
          API::put(order_update_url, parameters)
        end

        # Create 2 spin columns and 2 tubes
        spin_columns_rna = []
        tubes_rnap = []
        2.times do
          API::new_step("Create a new spin column")
          parameters = {:spin_column => {}}
          response = API::post(@routes["spin_columns"]["actions"]["create"], parameters)
          spin_columns_rna << {:read => response["spin_column"]["actions"]["read"], :type => "spin_column", :content => "RNA", :uuid => response["spin_column"]["uuid"]}

          API::new_step("Create a new tube")
          parameters = {:tube => {}}
          response = API::post(@routes["tubes"]["actions"]["create"], parameters)
          tubes_rnap << {:read => response["tube"]["actions"]["read"], :type => "tube", :content => "RNA+P", :uuid => response["tube"]["uuid"]}
        end

        # Add barcodes
        new_assets = spin_columns_rna.zip(tubes_rnap).flatten
        add_barcode_to_resources(new_assets)

        # Add new spin columns and new tubes in the order and start them
        new_assets_uuids = [[spin_columns_rna[0][:uuid], tubes_rnap[0][:uuid]], [spin_columns_rna[1][:uuid], tubes_rnap[1][:uuid]]]
        new_assets_uuids.each do |uuids|
          API::new_step("Add the new spin column and new tube in the order and start each of them")
          parameters = {:items => {
            ROLE_BINDING_SPIN_COLUMN_RNA => {uuids[0] => {:event => :start, :batch_uuid => batch_uuid}},
            ROLE_BY_PRODUCT_TUBE_RNAP => {uuids[1] => {:event => :start, :batch_uuid => batch_uuid}}
          }}
          API::put(order_update_url, parameters)
        end

        # Transfer from tubes to be extracted rnap to new spin columns and new tubes
        transfer_uuids = [
          [tubes_to_be_extracted[0][:uuid], spin_columns_rna[0][:uuid], tubes_rnap[0][:uuid]], 
          [tubes_to_be_extracted[1][:uuid], spin_columns_rna[1][:uuid], tubes_rnap[1][:uuid]]
        ] 
        transfer_uuids.each do |uuids|
          API::new_step("Transfer from tube to spin column and tube")
          parameters = {:transfer_tubes_to_tubes => {:transfers => [
            {:source_uuid => uuids[0], :target_uuid => uuids[1], :fraction => 0.5, :aliquot_type => ALIQUOT_TYPE_RNA}, 
            {:source_uuid => uuids[0], :target_uuid => uuids[2], :fraction => 0.5, :aliquot_type => ALIQUOT_TYPE_RNAP}
          ]}}
          API::post(@routes["transfer_tubes_to_tubes"]["actions"]["create"], parameters)
        end

        # Change the status of tubes to be extracted to unused, binding spin columns rna 
        # and by product tube rnap to done
        transfer_uuids.each do |uuids|
          API::new_step("Change the status of the spin column and the tube")
          parameters = {:items => {
            ROLE_TUBE_TO_BE_EXTRACTED_RNAP => {uuids[0] => {:event => :unuse}},
            ROLE_BINDING_SPIN_COLUMN_RNA => {uuids[1] => {:event => :complete}},
            ROLE_BY_PRODUCT_TUBE_RNAP => {uuids[2] => {:event => :complete}}
          }}
          API::put(order_update_url, parameters)
        end

        # Create new tubes for extracted rna
        extracted_tubes_rna = []
        2.times do 
          API::new_step("Create a new tube")
          parameters = {:tube => {}}
          response = API::post(@routes["tubes"]["actions"]["create"], parameters)
          extracted_tubes_rna << {:read => response["tube"]["actions"]["read"], :type => "tube", :content => "RNA", :uuid => response["tube"]["uuid"]}
        end
        
        # Add barcodes
        add_barcode_to_resources(extracted_tubes_rna)

        # Add extracted RNA tubes in the order and start them
        extracted_tubes_rna.each do |tube|
          API::new_step("Add the new extracted tube rna in the order and start it")
          parameters = {:items => {ROLE_EXTRACTED_TUBE_RNA => {tube[:uuid] => {:event => :start, :batch_uuid => batch_uuid}}}}
          API::put(order_update_url, parameters)
        end

        # Transfer from spin columns rna to extracted tubes rna 
        transfer_uuids = [
          [spin_columns_rna[0][:uuid], extracted_tubes_rna[0][:uuid]], 
          [spin_columns_rna[1][:uuid], extracted_tubes_rna[1][:uuid]]
        ] 
        transfer_uuids.each do |uuids|
          API::new_step("Transfer from spin column to extracted tube")
          parameters = {:transfer_tubes_to_tubes => {:transfers => [
            {:source_uuid => uuids[0], :target_uuid => uuids[1], :fraction => 1.0, :aliquot_type => ALIQUOT_TYPE_RNA}
          ]}}
          API::post(@routes["transfer_tubes_to_tubes"]["actions"]["create"], parameters)
        end

        # Change the status of spin columns to unused and extracted tubes to done
        transfer_uuids.each do |uuids|
          API::new_step("Change the status of the spin column and the extracted tube")
          parameters = {:items => {
            ROLE_BINDING_SPIN_COLUMN_RNA => {uuids[0] => {:event => :unuse}},
            ROLE_EXTRACTED_TUBE_RNA => {uuids[1] => {:event => :complete}}
          }}
          API::put(order_update_url, parameters)
        end
      end


      private 

      def add_barcode_to_resources(assets)
        # Create barcodes
        barcode_values = []
        assets.each do |e|
          API::new_step("Generate a new barcode")
          barcode_values << API::mock_barcode_generation(e[:type], e[:content])
        end

        # Assign barcodes to the new tubes and spin columns
        assets.each do |e|
          API::new_step("Assign a barcode to the #{e[:type]} with the uuid=#{e[:uuid]}")
          barcode(e[:uuid], barcode_values.shift) 
        end

        # Get the barcoded resources
        assets.each do |e|
          API::new_step("Get the barcoded #{e[:type]}")
          API::get(e[:read])
        end

        # Printer service
        API::new_step("Printer service")
        API::mock_printer_service
      end
    end
  end
end
