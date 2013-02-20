require 'json'
require 'rest_client'
require 'lims-core'
require 'lims-core/persistence/sequel'
require 'sequel'
require 'optparse'

# This script goes through the different steps 
# of the DNA+RNA manual extraction pipeline.
# It does the following steps:
# 1 - Find a tube by barcode
# 2 - Find the order by tube uuid and role
# 3 - Check that no batch has been assigned to the tube
# 4 - Create a new batch
# 5 - Assign the batch uuid to the tube in the order item
# Note:
# The script can be called with the following parameters
# -u "root url to s2 api server"
# -v print the json for each request

@options = {}
OptionParser.new do |opts|
  opts.banner = "Usage: dna_rna_manual_extraction.rb [options]"
  opts.on("-u", "--url [URL]") { |v| @options[:url] = v}
  opts.on("-v", "--verbose") { |v| @options[:verbose] = v}
end.parse!

API_ROOT = @options[:url] || "http://localhost:9292"
HEADERS = {'Content-Type' => 'application/json', 'Accept' => 'application/json'}
API = RestClient::Resource.new(API_ROOT)

TUBE_BARCODE = "XX123456K"
TUBE_ROLE = "tube_to_be_extracted"
TUBE_ALIQUOT_TYPE_RNAP = "RNA+P"
SPIN_ALIQUOT_TYPE = "DNA"

# ================
# Helper functions
# ================
def post(url, parameters)
  response = API[url].post(parameters.to_json, HEADERS)
  dump_request("post", url, parameters, response)
  JSON.parse(response)
end

def put(url, parameters)
  response = API[url].put(parameters.to_json, HEADERS)
  dump_request("put", url, parameters, response)
  JSON.parse(response)
end

def get(url)
  url = url.sub(API_ROOT, '')
  response = API[url].get(HEADERS)
  dump_request("get", url, nil, response)
  JSON.parse(response)
end

def dump_request(method, url, parameters, response)
  if @options[:verbose]
    puts "#{method.upcase} /#{url}"
    puts "< #{parameters.to_json}" if parameters
    puts "> #{response}" if response
    puts
  end
end

# ============================
# 1 - Find the tube by barcode
# ============================
parameters = {:search => {:description => "search for barcoded tube",
                          :model => "tube",
                          :criteria => {:label => {:position => "barcode",
                                                   :type => "sanger-barcode",
                                                   :value => TUBE_BARCODE}}}}
search_response = post("searches", parameters)
result_url = search_response["search"]["actions"]["first"]
result_response = get(result_url) 
tube = result_response["tubes"].first["tube"]

# ========================================
# 2 - Find the order by tube uuid and role
# ========================================
parameters = {:search => {:description => "search for order",
                          :model => "order",
                          :criteria => {:item => {:uuid => tube["uuid"],
                                                  :role => TUBE_ROLE}}}}
search_response = post("searches", parameters)
result_url = search_response["search"]["actions"]["first"]
result_response = get(result_url)
order = result_response["orders"].first["order"]

# =====================================================
# 3 - Check that no batch has been assigned to the tube
# =====================================================
no_batch = order["items"][TUBE_ROLE].select do |item|
  item["uuid"] == tube["uuid"]
end.first["batch"].nil?

exit unless no_batch

# ======================
# 4 - Create a new batch
# ======================
parameters = {:batch => {}}
response = post("batches", parameters)
batch = response["batch"]

# =======================================================
# 5 - Assign the batch uuid to the tube in the order item
# =======================================================
parameters = {:items => {TUBE_ROLE => {tube["uuid"] => {:batch_uuid => batch["uuid"]}}}}
put(order["uuid"], parameters)

