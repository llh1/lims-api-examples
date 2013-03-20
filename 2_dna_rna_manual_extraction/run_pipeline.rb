require 'lims-api-examples'
require 'optparse'
require 'helpers/api'

require 'workflows/manual_workflow'
require 'workflows/automated_workflow'

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
    opts.on("-r", "--rspec [PATH]") { |v| @options[:rspec] = v}
  end.parse!

  API::set_root(@options[:url] || "http://localhost:9292")
  API::set_verbose(@options[:verbose])
  API::set_output(@options[:output]) if @options[:output]
  API::set_rspec_json_output(@options[:rspec]) if @options[:rspec]

  case @options[:mode]
  when "manual" then
    # DNA + RNA Manual Extraction
    include Constant::DnaRnaManualExtraction
    manual = ManualWorkflow.new([[SOURCE_TUBE_BARCODES[0], SOURCE_TUBE_BARCODES[1]],
                                 [SOURCE_TUBE_BARCODES[2]]])

    API::set_rspec_title("DNA+RNA Manual Extraction")
    API::start_recording
    manual.start
    API::stop_recording

  when "automated" then
    # Automated tube-to-tube DNA+RNA extraction (QIACube)
    include Constant::DnaRnaAutomatedExtraction
    automated = AutomatedWorkflow.new(SOURCE_TUBE_BARCODE) 
    API::start_recording
    automated.start
    API::stop_recording
  end

  API::generate_json
  API::generate_rspec_json
end
