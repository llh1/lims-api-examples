require 'constant'

module Lims::Examples
  module ExampleManualExtraction
    module ReRacking
      include Constant

      def re_racking
        API::new_step("Create a new tube rack")
        parameters = {:tube_rack => {:number_of_columns => 12,
                                     :number_of_rows => 8,
                                     :tubes => {}}}
        response = API::post(@routes["tube_racks"]["actions"]["create"], parameters)
        tube_rack_uuid = response["tube_rack"]["uuid"]
        tube_rack_update_url = response["tube_rack"]["actions"]["update"]

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
      end
    end
  end
end
