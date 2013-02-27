require 'lims-api-examples'
require 'optparse'
require 'helper/api'

require 'process/manual_workflow'

# Note:
# The script can be called with the following parameters
module Lims::Api::Examples
  include API
  include Constant

  @options = {}
  OptionParser.new do |opts|
    opts.banner = "Usage: dna_rna_manual_extraction.rb [options]"
    opts.on("-u", "--url [URL]") { |v| @options[:url] = v}
    opts.on("-v", "--verbose") { |v| @options[:verbose] = v}
    opts.on("-m", "--mode [MODE]") { |v| @options[:mode] = v}
    opts.on("-o", "--output [OUTPUT]") { |v| @options[:output] = v}
  end.parse!

  API::set_root(@options[:url] || "http://localhost:9292")
  API::set_verbose(@options[:verbose])
  API::set_output(@options[:output]) if @options[:output]

  barcode_1 = [SOURCE_TUBE_BARCODES[2]]
  barcodes_2 = [SOURCE_TUBE_BARCODES[0], SOURCE_TUBE_BARCODES[1]]
  barcodes = case @options[:mode]
             when "manual-2" then barcodes_2 
             else barcode_1
             end

  case @options[:mode]
  when "manual-2", "manual-1", "manual" then
    # DNA + RNA Manual Extraction
    include Constant::DnaRnaManualExtraction
    manual = ManualWorkflow.new(barcodes)
    API::start_recording
    manual.start
    API::stop_recording
    API::generate_json

  when "automated" then
    # Re Tubing
    #ReTubing::start

    # Automated tube-to-tube DNA+RNA extraction (QIACube)
    #DnaRnaAutomatedExtraction::start
  end
end
