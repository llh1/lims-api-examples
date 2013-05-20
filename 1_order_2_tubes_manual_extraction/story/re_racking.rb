require 'constant'

module Lims::Examples
  module ExampleManualExtraction
    module ReRacking
      include Constant

      def re_racking
        # Create a new empty tube rack
        API::new_step("Create a new tube rack")
        parameters = {:tube_rack => {:number_of_columns => 12,
                                     :number_of_rows => 8,
                                     :tubes => {}}}
        response = API::post(@routes["tube_racks"]["actions"]["create"], parameters)
        tube_rack_uuid = response["tube_rack"]["uuid"]

        # Add the tube rack in the order and start it
        API::new_step("Add the new tube rack in the order and start it")
        parameters = {:items => {ROLE_STOCK => {tube_rack_uuid => {:event => :start, :batch_uuid => batch_uuid}}}}
        API::put(@order_update_url, parameters)

        # Move tubes between tube racks
        API::new_step("Move tubes")
        parameters = {:tube_rack_move => {:moves => [
          {
            :source_uuid => @tube_rack_dna_uuid, :source_location => "A1",
            :target_uuid => tube_rack_uuid, :target_location => "A1"
          },
          {
            :source_uuid => @tube_rack_dna_uuid, :source_location => "A2",
            :target_uuid => tube_rack_uuid, :target_location => "A2"
          },
          {
            :source_uuid => @tube_rack_rna_uuid, :source_location => "A1",
            :target_uuid => tube_rack_uuid, :target_location => "A3"
          },
          {
            :source_uuid => @tube_rack_rna_uuid, :source_location => "A2",
            :target_uuid => tube_rack_uuid, :target_location => "A4"
          }
        ]}}
        API::post(@routes["tube_rack_moves"]["actions"]["create"], parameters)
        
        # Change status of tube racks
        API::new_step("Change the status of the dna and rna tube racks and stock tube rack")
        parameters = {:items => {
          ROLE_STOCK_DNA => {@tube_rack_dna_uuid => {:event => :unuse}},
          ROLE_STOCK_RNA => {@tube_rack_rna_uuid => {:event => :unuse}},
          ROLE_STOCK => {tube_rack_uuid => {:event => :complete}}
        }}
        API::put(@order_update_url, parameters)

        @stock_tube_rack_uuid = tube_rack_uuid
      end
    end
  end
end
