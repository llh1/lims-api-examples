require 'optparse'
require 'api'
require 'story/story'

module Lims
  module Examples
    module ExampleManualExtraction
      include API

      options = {}
      OptionParser.new do |opts|
        opts.on("-u", "--url [URL]") { |v| options[:url] = v}
        opts.on("-v", "--verbose") { |v| options[:verbose] = v}
        opts.on("-o", "--output [OUTPUT]") { |v| options[:output] = v}
      end.parse!

      output = options[:output] || "outputs/1_order_2_tubes_manual_extraction.json" 
      abort "API url is required" unless options[:url]

      API::set_root(options[:url] || "http://localhost:9292")
      API::set_verbose(options[:verbose])
      API::set_output(output)

      # These barcodes need to be the same as the barcode
      # created in demo_seeding/setup_s2_environment script.
      tube_barcode_1 = "8800000000016"
      tube_barcode_2 = "8800000000017"
      story = Story.new([tube_barcode_1, tube_barcode_2])

      API::start_recording
      story.start
      API::stop_recording
      API::generate_json
    end
  end
end
