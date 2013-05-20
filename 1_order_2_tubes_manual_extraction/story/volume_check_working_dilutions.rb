require 'constant'

module Lims::Examples
  module ExampleManualExtraction
    module VolumeCheckWorkingDilutions
      include Constant

      def volume_check
        # TODO
      end

      def working_dilutions
        # Create a new plate
        API::new_step("Create a new plate")
        parameters = {:plate => {:number_of_columns => 12,
                                 :number_of_rows => 8,
                                 :wells_description => {}}}
        response = API::post(@routes["plates"]["actions"]["create"], parameters)
        plate_uuid = response["plate"]["uuid"]

        # Add the plate in the order and start it
        API::new_step("Add the new plate in the order and start it")
        parameters = {:items => {ROLE_WORKING_DILUTIONS_PLATE => {plate_uuid => {:event => :start, :batch_uuid => batch_uuid}}}}
        API::put(@order_update_url, parameters)

        # Transfers between stock tube rack and working dilutions plate
        API::new_step("Transfer between stock rack and working dilutions plate")
        parameters = {:transfer_plates_to_plates => {
          :transfers => [].tap do |t|
            [:A1, :A2, :A3, :A4].each do |location|
              t << {
                :source_uuid => @stock_tube_rack_uuid, :source_location => location,
                :target_uuid => plate_uuid, :target_location => location,
                :fraction => 1.0
              }
            end
          end
        }}
        API::post(@routes["transfer_plates_to_plates"]["actions"]["create"], parameters)

        # Change status of tube racks
        API::new_step("Change the status of the stock tube rack and the working dilutions plate")
        parameters = {:items => {
          ROLE_STOCK => {@stock_tube_rack_uuid => {:event => :unuse}},
          ROLE_WORKING_DILUTIONS_PLATE => {plate_uuid => {:event => :complete}}
        }}
        API::put(@order_update_url, parameters)

        @working_dilutions_plate_uuid = plate_uuid
      end
    end
  end
end
