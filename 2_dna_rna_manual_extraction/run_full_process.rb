require 'lims-api-examples'
require 'optparse'
require 'helper/api'

require 'process/dna_rna_manual_extraction'
require 'process/re_tubing'
require 'process/dna_rna_automated_extraction'

# Note:
# The script can be called with the following parameters
# -u "root url to s2 api server"
# -v print the json for each request
module Lims::Api::Examples
  include API
  include DnaRnaManualExtraction
  include Constant
  include Constant::DnaRnaManualExtraction

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

  case @options[:mode]
  when "manual" then
    # DNA + RNA Manual Extraction
    DnaRnaManualExtraction::set_barcodes([SOURCE_TUBE_BARCODES[0], SOURCE_TUBE_BARCODES[1]])
    DnaRnaManualExtraction::start

    API::generate_json

    #DnaRnaManualExtraction::set_barcodes([SOURCE_TUBE_BARCODES[2]])
    #DnaRnaManualExtraction::start

  when "automated" then
    # Re Tubing
    #ReTubing::start

    # Automated tube-to-tube DNA+RNA extraction (QIACube)
    #DnaRnaAutomatedExtraction::start
  end
end
