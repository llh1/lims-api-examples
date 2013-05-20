require 'constant'
require 'builder'
require 'story/manual_extraction'
require 'story/load_tubes_and_assign_batch'
require 'story/racking'

module Lims::Examples
  module ExampleManualExtraction
    class Story
      include Constant
      include Builder

      include LoadTubesAndAssignBatch
      include ManualExtraction
      include Racking

      def initialize(barcodes)
        @barcodes = barcodes       
      end

      def start
        root
        load_tubes_and_assign_batch
        manual_extraction
        racking
      end

      private

      def root
        API::new_step("Get the root JSON")
        @routes = API::get_root
      end

      def search_orders_by_batch
        API::new_step("Create the search order by batch")
        parameters = {:search => {:description => "search order by batch",
                                  :model => "order",
                                  :criteria => {:item => {:batch => @batch_uuid}}}}
        search_response = API::post(@routes["searches"]["actions"]["create"], parameters)

        API::new_step("Get the result orders")
        result_url = search_response["search"]["actions"]["first"]
        result_response = API::get(result_url)

        source_tube_uuids_array = [].tap do |arr|
          result_response["orders"].each do |o|
            if o.has_key?("items") && o["items"].has_key?(ROLE_BINDING_TUBE_TO_BE_EXTRACTED_NAP)
              arr << o["items"][ROLE_BINDING_TUBE_TO_BE_EXTRACTED_NAP].map { |item| item["uuid"] }
            end
          end
        end

        {:source_tube_uuids => source_tube_uuids_array.flatten}
      end

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
