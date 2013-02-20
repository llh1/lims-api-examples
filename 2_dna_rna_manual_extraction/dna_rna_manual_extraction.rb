require 'json'
require 'rest_client'
require 'lims-core'
require 'optparse'

# This script goes through the different steps 
# of the DNA+RNA manual extraction pipeline.
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

NAP_TUBE_BARCODE = "XX123456K"

ALIQUOT_TYPE_RNAP = "RNA+P"
ALIQUOT_TYPE_DNA = "DNA"
ALIQUOT_TYPE_RNA = "RNA"

ROLE_TUBE_TO_BE_EXTRACTED = "tube_to_be_extracted"
ROLE_BY_PRODUCT_TUBE = "by_product_tube"
ROLE_BINDING_SPIN_COLUMN_DNA = "binding_spin_column_dna"
ROLE_ELUTION_SPIN_COLUMN_DNA = "elution_spin_column_dna"
ROLE_BINDING_SPIN_COLUMN_RNA = "binding_spin_column_rna"
ROLE_ELUTION_SPIN_COLUMN_RNA = "elution_spin_column_rna"
ROLE_EXTRACTED_TUBE = "extracted_tube"


# Helper functions

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

# =======================================
# Search the source tube in the order and
# assign it a batch
# =======================================

# Find the tube by barcode
parameters = {:search => {:description => "search for barcoded tube",
                          :model => "tube",
                          :criteria => {:label => {:position => "barcode",
                                                   :type => "sanger-barcode",
                                                   :value => NAP_TUBE_BARCODE}}}}
search_response = post("searches", parameters)
result_url = search_response["search"]["actions"]["first"]
result_response = get(result_url) 
source_tube_uuid = result_response["tubes"].first["tube"]["uuid"]

# Find the order by tube uuid and role
parameters = {:search => {:description => "search for order",
                          :model => "order",
                          :criteria => {:item => {:uuid => source_tube_uuid,
                                                  :role => ROLE_TUBE_TO_BE_EXTRACTED}}}}
search_response = post("searches", parameters)
result_url = search_response["search"]["actions"]["first"]
result_response = get(result_url)
order = result_response["orders"].first["order"]
order_uuid = order["uuid"]

# Check that no batch has been assigned to the tube
no_batch = order["items"][ROLE_TUBE_TO_BE_EXTRACTED].select do |item|
  item["uuid"] == source_tube_uuid 
end.first["batch"].nil?

abort("Error: A batch is already assigned to the source tube") unless no_batch

# Create a new batch
parameters = {:batch => {}}
response = post("batches", parameters)
batch_uuid = response["batch"]["uuid"]

# Assign the batch uuid to the tube in the order item
parameters = {:items => {ROLE_TUBE_TO_BE_EXTRACTED => {source_tube_uuid => {:batch_uuid => batch_uuid}}}}
put(order_uuid, parameters)


# =========================
# Build and start the order
# =========================

# Change the status of the order to pending
parameters = {:event => :build}
put(order_uuid, parameters)

# Change the status of the order to in_progress
parameters = {:event => :start}
put(order_uuid, parameters)


# =====================================
# Transfer the DNA from the source tube
# into a spin column
# =====================================

# Create a new spin column
parameters = {:spin_column => {}}
response = post("spin_columns", parameters)
dna_spin_uuid = response["spin_column"]["uuid"]

# Add the new spin column in the order and start it
parameters = {:items => {ROLE_BINDING_SPIN_COLUMN_DNA => {dna_spin_uuid => {:event => :start,
                                                                            :batch_uuid => batch_uuid}}}}
put(order_uuid, parameters)

# Transfer from source tube into the spin column
parameters = {:transfer_tubes_to_tubes => {:transfers => [{
  :source_uuid => source_tube_uuid, 
  :target_uuid => dna_spin_uuid, 
  :fraction => 0.5, 
  :aliquot_type => ALIQUOT_TYPE_DNA
}]}}
post("actions/transfer_tubes_to_tubes", parameters)

# Change the status of the spin column to done
parameters = {:items => {ROLE_BINDING_SPIN_COLUMN_DNA => {dna_spin_uuid => {:event => :complete}}}}
put(order_uuid, parameters)


# ==============================================
# Use the spin column in a new role elution
# and transfer the content to an extracted tube
# ==============================================

# Add the spin column in the order under the role elution and start it
parameters = {:items => {ROLE_ELUTION_SPIN_COLUMN_DNA => {dna_spin_uuid => {:event => :start,
                                                                            :batch_uuid => batch_uuid}}}}
put(order_uuid, parameters)

# Change the status of the spin column to done
parameters = {:items => {ROLE_ELUTION_SPIN_COLUMN_DNA => {dna_spin_uuid => {:event => :complete}}}}
put(order_uuid, parameters)

# Create a new tube
parameters = {:tube => {}}
response = post("tubes", parameters)
dna_tube_uuid = response["tube"]["uuid"]

# Add the tube in the order and start it
parameters = {:items => {ROLE_EXTRACTED_TUBE => {dna_tube_uuid => {:event => :start}}}}
put(order_uuid, parameters)

# Transfer the spin column to the extracted_tube
parameters = {:transfer_tubes_to_tubes => {:transfers => [{
  :source_uuid => dna_spin_uuid, 
  :target_uuid => dna_tube_uuid, 
  :amount => 5, 
  :aliquot_type => ALIQUOT_TYPE_DNA
}]}}
post("actions/transfer_tubes_to_tubes", parameters)

# Change the status of the dna tube to done
parameters = {:items => {ROLE_EXTRACTED_TUBE => {dna_tube_uuid => {:event => :complete}}}}
put(order_uuid, parameters)


# =================================
# Transfer from source tube to a 
# by product tube containing RNA+P
# =================================

# Create a new tube
parameters = {:tube => {}}
response = post("tubes", parameters)
rnap_tube_uuid = response["tube"]["uuid"]

# Add the new tube in the order and start it
parameters = {:items => {ROLE_BY_PRODUCT_TUBE => {rnap_tube_uuid => {:event => :start,
                                                                     :batch_uuid => batch_uuid}}}}
put(order_uuid, parameters)

# Transfer the source tube to rna+p tube
parameters = {:transfer_tubes_to_tubes => {:transfers => [{
  :source_uuid => source_tube_uuid, 
  :target_uuid => rnap_tube_uuid, 
  :fraction => 1, 
  :aliquot_type => ALIQUOT_TYPE_RNAP
}]}}
post("actions/transfer_tubes_to_tubes", parameters)

# Change the status of the by product tube to done
parameters = {:items => {ROLE_BY_PRODUCT_TUBE => {rnap_tube_uuid => {:event => :complete}}}}
put(order_uuid, parameters)


# =====================================
# Transfer from by product tube to tube 
# to be extracted
# =====================================

# Create a new tube
parameters = {:tube => {}}
response = post("tubes", parameters)
rnap_tube2_uuid = response["tube"]["uuid"]

# Add the new tube in the order and start it
parameters = {:items => {ROLE_TUBE_TO_BE_EXTRACTED => {rnap_tube2_uuid => {:event => :start,
                                                                           :batch_uuid => batch_uuid}}}}
put(order_uuid, parameters)

# Transfer the by product tube to tube to be extracted
parameters = {:transfer_tubes_to_tubes => {:transfers => [{
  :source_uuid => rnap_tube_uuid, 
  :target_uuid => rnap_tube2_uuid, 
  :amount => 5
}]}}
post("actions/transfer_tubes_to_tubes", parameters)

# Change the status of the by product tube to done
parameters = {:items => {ROLE_TUBE_TO_BE_EXTRACTED => {rnap_tube2_uuid => {:event => :complete}}}}
put(order_uuid, parameters)


# =============================================
# Transfer the content of tube to be extracted
# into a spin column
# =============================================

# Create a new spin column
parameters = {:spin_column => {}}
response = post("spin_columns", parameters)
rna_spin_uuid = response["spin_column"]["uuid"]

# Add the new spin column in the order and start it
parameters = {:items => {ROLE_BINDING_SPIN_COLUMN_RNA => {rna_spin_uuid => {:event => :start,
                                                                            :batch_uuid => batch_uuid}}}}
put(order_uuid, parameters)

# Transfer from tube to be extracted into the spin column
parameters = {:transfer_tubes_to_tubes => {:transfers => [{
  :source_uuid => rnap_tube2_uuid, 
  :target_uuid => rna_spin_uuid, 
  :amount => 1, 
  :aliquot_type => ALIQUOT_TYPE_RNA
}]}}
post("actions/transfer_tubes_to_tubes", parameters)

# Change the status of the spin column to done
parameters = {:items => {ROLE_BINDING_SPIN_COLUMN_RNA => {rna_spin_uuid => {:event => :complete}}}}
put(order_uuid, parameters)


# ==============================================
# Use the spin column in a new role elution
# and transfer the content to an extracted tube
# ==============================================

# Add the spin column in the order under the role elution and start it
parameters = {:items => {ROLE_ELUTION_SPIN_COLUMN_RNA => {rna_spin_uuid => {:event => :start,
                                                                            :batch_uuid => batch_uuid}}}}
put(order_uuid, parameters)

# Change the status of the spin column to done
parameters = {:items => {ROLE_ELUTION_SPIN_COLUMN_RNA => {rna_spin_uuid => {:event => :complete}}}}
put(order_uuid, parameters)

# Create a new tube
parameters = {:tube => {}}
response = post("tubes", parameters)
rna_tube_uuid = response["tube"]["uuid"]

# Add the tube in the order and start it
parameters = {:items => {ROLE_EXTRACTED_TUBE => {rna_tube_uuid => {:event => :start}}}}
put(order_uuid, parameters)

# Transfer the spin column to the extracted_tube
parameters = {:transfer_tubes_to_tubes => {:transfers => [{
  :source_uuid => rna_spin_uuid, 
  :target_uuid => rna_tube_uuid, 
  :amount => 1, 
  :aliquot_type => ALIQUOT_TYPE_RNA
}]}}
post("actions/transfer_tubes_to_tubes", parameters)

# Change the status of the rna tube to done
parameters = {:items => {ROLE_EXTRACTED_TUBE => {rna_tube_uuid => {:event => :complete}}}}
put(order_uuid, parameters)


# ============================================
# Change the status of the order to completed
# ============================================

parameters = {:event => :complete}
put(order_uuid, parameters)

