require 'constant'

module Lims::Examples
  module ExampleManualExtraction
    module Racking
      include Constant

      def racking
        racking_for :dna
        racking_for :rna
      end


      private

      def racking_for(type)
        # Create new tubes
        tubes_to_be_racked = []
        2.times do 
          API::new_step("Create a new tube")
          parameters = {:tube => {}}
          response = API::post(@routes["tubes"]["actions"]["create"], parameters)
          tubes_to_be_racked << {:read => response["tube"]["actions"]["read"], :type => "tube", :content => type.to_s.upcase, :uuid => response["tube"]["uuid"]}
        end

        # Add barcodes
        add_barcode_to_resources(tubes_to_be_racked)

        # Add tubes to be racked in the order and start them
        role_tube_to_be_racked = type.to_s == "dna" ? ROLE_TUBE_TO_BE_RACKED_DNA : ROLE_TUBE_TO_BE_RACKED_RNA
        tubes_to_be_racked.each do |tube|
          API::new_step("Add the new tube in the order and start it")
          parameters = {:items => {role_tube_to_be_racked => {tube[:uuid] => {:event => :start, :batch_uuid => batch_uuid}}}}
          API::put(@order_update_url, parameters)
        end

        # Transfer from extracted tubes to tube to be racked
        extracted_tubes = type.to_s == "dna" ? @extracted_tubes_dna : @extracted_tubes_rna
        aliquot_type = type.to_s == "dna" ? ALIQUOT_TYPE_DNA : ALIQUOT_TYPE_RNA
        transfer_uuids = [
          [extracted_tubes[0][:uuid], tubes_to_be_racked[0][:uuid]], 
          [extracted_tubes[1][:uuid], tubes_to_be_racked[1][:uuid]]
        ] 
        transfer_uuids.each do |uuids|
          API::new_step("Transfer from extracted tube to tube to be racked")
          parameters = {:transfer_tubes_to_tubes => {:transfers => [
            {:source_uuid => uuids[0], :target_uuid => uuids[1], :fraction => 1.0, :aliquot_type => aliquot_type}
          ]}}
          API::post(@routes["transfer_tubes_to_tubes"]["actions"]["create"], parameters)
        end

        # Change the status of extracted tubes to unused and tube to be racked to done
        role_extracted_tube = type.to_s == "dna" ? ROLE_EXTRACTED_TUBE_DNA : ROLE_EXTRACTED_TUBE_RNA
        transfer_uuids.each do |uuids|
          API::new_step("Change the status of the extracted tube and the tube to be racked")
          parameters = {:items => {
            role_extracted_tube => {uuids[0] => {:event => :unuse}},
            role_tube_to_be_racked => {uuids[1] => {:event => :complete}}
          }}
          API::put(@order_update_url, parameters)
        end

        # Create a new tube rack
        API::new_step("Create a new tube rack")
        parameters = {:tube_rack => {:number_of_columns => 12,
                                     :number_of_rows => 8,
                                     :tubes => {
                                       :A1 => tubes_to_be_racked[0][:uuid],
                                       :A2 => tubes_to_be_racked[1][:uuid]
                                     }}}
        response = API::post(@routes["tube_racks"]["actions"]["create"], parameters)
        tube_rack_uuid = response["tube_rack"]["uuid"] 

        # Add the tube rack in the order and start it
        API::new_step("Add the tube rack in the order and start it")
        role_tube_rack = type.to_s == "dna" ? ROLE_STOCK_DNA : ROLE_STOCK_RNA 
        parameters = {:items => {role_tube_rack => {tube_rack_uuid => {:event => :start, :batch_uuid => batch_uuid}}}}
        API::put(@order_update_url, parameters)

        if type.to_s == "dna"
          @tube_rack_dna_uuid = tube_rack_uuid
        else 
          @tube_rack_rna_uuid = tube_rack_uuid
        end
      end
    end
  end
end
