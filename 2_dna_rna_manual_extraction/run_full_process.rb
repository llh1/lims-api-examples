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
  include ReTubing

  @options = {}
  OptionParser.new do |opts|
    opts.banner = "Usage: dna_rna_manual_extraction.rb [options]"
    opts.on("-u", "--url [URL]") { |v| @options[:url] = v}
    opts.on("-v", "--verbose") { |v| @options[:verbose] = v}
  end.parse!

  API::set_root(@options[:url] || "http://localhost:9292")
  API::set_verbose(@options[:verbose])

  # DNA + RNA Manual Extraction
  DnaRnaManualExtraction::start

  # Re Tubing
  ReTubing::start
  re_tubing_results = ReTubing::results

  # Automated tube-to-tube DNA+RNA extraction (QIACube)
  DnaRnaAutomatedExtraction::set_parameters(re_tubing_results)
  DnaRnaAutomatedExtraction::start
end
