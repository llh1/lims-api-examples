require 'json'
require 'rest_client'
require 'lims-core'
require 'lims-core/persistence/sequel'
require 'sequel'

API_ROOT = "http://localhost:9292"
HEADERS = {'Content-Type' => 'application/json', 'Accept' => 'application/json'}
API = RestClient::Resource.new(API_ROOT)

# ====
# Note:
# The script can be called with the option --no-request to 
# just print the JSON parameters for each request.
# ====

# ================
# Helper functions
# ================
def send_request?
  case ARGV[0]
  when "--no-request"
    return false
  end
  return true
end

def post(url, parameters)
  response = API[url].post(parameters.to_json, HEADERS) if send_request? 
  execution_trace(url, parameters, response)
  response
end

def put(url, parameters)
  response = API[url].put(parameters.to_json, HEADERS) if send_request? 
  execution_trace(url, parameters, response)
  response
end

def get(url)
  url = url.sub(API_ROOT, '')
  response = API[url].get(HEADERS) if send_request?
  execution_trace(url, nil, response)
  response
end

def execution_trace(url, parameters, response)
  puts "Request to #{API_ROOT}/#{url}"
  unless parameters.nil?
    puts "with the following JSON:"
    puts parameters.to_json
  end
  if send_request?
    puts "and get the response:"
    puts response
  end
  puts
end
# ====================
# End Helper functions
# ====================

# =================================================
# Create the resources needed in the order workflow
# =================================================

puts "CREATE THE RESOURCES NEEDED IN THE ORDER WORKFLOW"
puts "================================================="
puts 

# Initialization for --no-request use
input_uuid = "aaa000000"
spin_uuid = "bbb111111"
tubeout_uuid = "ccc222222"
epa_uuid = "ddd333333"

# Create a tube <Input>
parameters = {:tube => {}}
response = post("tubes", parameters)
if send_request?
  tube = JSON.parse(response)
  input_uuid = tube["tube"]["uuid"]
end

# Create a tube <TubeOut>
parameters = {:tube => {}}
response = post("tubes", parameters)
if send_request?
  tube = JSON.parse(response)
  tubeout_uuid = tube["tube"]["uuid"]
end

# Create a tube <EpA>
parameters = {:tube => {}}
response = post("tubes", parameters)
if send_request?
  tube = JSON.parse(response)
  epa_uuid = tube["tube"]["uuid"]
end 

# Create a spin column <Spin>
parameters = {:spin_column => {}}
response = post("spin_columns", parameters)
if send_request?
  spin = JSON.parse(response)
  spin_uuid = spin["spin_column"]["uuid"]
end

# =================
# Barcode resources
# =================

puts
puts "BARCODE RESOURCES"
puts "================="
puts

{input_uuid => "ABC1234", spin_uuid => "DEF1234", tubeout_uuid => "GHI1234", epa_uuid => "JKL1234"}.each do |uuid, barcode|
  parameters = {:labellable => {:name => uuid, 
                                :type => "resource",
                                :labels => {"front barcode" => {:value => barcode,
                                                                :type => "sanger-barcode"}}}}
  response = post("labellables", parameters)
end

# ====================================
# Needed in the order creation action:
# - a valid study uuid
# - a valid user uuid
# Add a user and a study in the core
# ===================================
path_to_db = '/Users/llh1/Developer/lims-api/dev.db'
store = Lims::Core::Persistence::Sequel::Store.new(Sequel.sqlite("file:#{path_to_db}"))
user_uuid = "66666666-2222-4444-9999-000000000000"
study_uuid = "55555555-2222-3333-6666-777777777777"

store.with_session do |session|
  user = Lims::Core::Organization::User.new
  session << user
  session.new_uuid_resource_for(user).send(:uuid=, user_uuid)

  study = Lims::Core::Organization::Study.new
  session << study
  session.new_uuid_resource_for(study).send(:uuid=, study_uuid)
end


# ==============
# Order workflow
# ==============
# Tube <Input> -> Spin Column <Spin> -> Tube <EpA>
#              -> Tube <TubeOut> -> X

puts 
puts "ORDER WORKFLOW"
puts "=============="
puts

# Initial state
# Create the order and setup the source and the targets.

puts "INITIAL STATE: CREATE THE ORDER AND SETUP THE SOURCE AND THE TARGETS"
puts

parameters = {:order => {:user_uuid => user_uuid,
                         :study_uuid => study_uuid,
                         :pipeline => "pipeline 1",
                         :cost_code => "cost code A",
                         :sources => {"Input" => [input_uuid]},
                         :targets => {"Spin" => [spin_uuid],
                                      "TubeOut" => [tubeout_uuid],
                                      "EpA" => [epa_uuid]}}}
response = post("orders", parameters) 
order_uuid = "{order_uuid}" # for --no-request use
if response
  result = JSON.parse(response.body)
  order_uuid = result["order"]["uuid"]
end

# The initial order status is set to draft.
# We need to first set it to pending, meaning it's validated
# by the end-user. Then we can set it to in_progress meaning
# some work are currently being done.

puts "CHANGE THE ORDER STATUS TO PENDING"
puts

parameters = {:event => :build}
response = put(order_uuid, parameters)

puts "CHANGE THE ORDER STATUS TO IN_PROGRESS"
puts

parameters = {:event => :start}
response = put(order_uuid, parameters)

# Spin and TubeOut are in progress

puts "CHANGE THE SPIN AND TUBEOUT STATUS TO IN_PROGRESS"
puts

parameters = {:items => {"Spin" => {spin_uuid => {:event => :start}},
                         "TubeOut" => {tubeout_uuid => {:event => :start}}}}
response = put(order_uuid, parameters)

# Do the work: transfer from tube Input 
# to tube TubeOut and spin column Spin

puts "DO THE WORK: TRANSFER FROM TUBE INPUT TO TUBE TUBEOUT AND SPIN COLUMN"
puts

parameters = {:transfer_tubes_to_tubes => {:transfers => [{:source => input_uuid,
                                                           :target => tubeout_uuid,
                                                           :fraction => 0.5,
                                                           :aliquot_type => "NA"},
                                                           {:source => input_uuid,
                                                            :target => spin_uuid,
                                                            :fraction => 0.5,
                                                            :aliquot_type => "DNA"}]}}
# TO DO:  Tubes to tubes action still needs to be tested in the API.
#response = post("actions/transfer_tubes_to_tubes", parameters)

# Spin and TubeOut are done. 
# Input is unused.

puts "CHANGE THE SPIN AND TUBEOUT STATUS TO DONE"
puts "AND CHANGE THE INPUT STATUS TO UNUSED"
puts

parameters = {:items => {"Spin" => {spin_uuid => {:event => :complete}},
                         "TubeOut" => {tubeout_uuid => {:event => :complete}},
                         "Input" => {input_uuid => {:event => :unuse}}}}
response = put(order_uuid, parameters)

# Do the work: transfer from spin column to tube EpA

puts "DO THE WORK: TRANSFER FRON SPIN COLUMN TO TUBE EPA"
puts

parameters = {:transfer_tubes_to_tubes => {:transfers => [{:source_uuid => spin_uuid,
                                                           :target_uuid => epa_uuid,
                                                           :fraction => 1.0,
                                                           :aliquot_type => "NA"}]}}
# TO DO:  Tubes to tubes action still needs to be tested in the API.
#response = post("actions/transfer_tubes_to_tubes", parameters)

# EpA is done.
# Spin is unused.

puts "CHANGE EPA STATUS TO DONE AND SPIN STATUS TO UNUSED"
puts

parameters = {:items => {"EpA" => {epa_uuid => {:event => :complete}},
                         "Spin" => {spin_uuid => {:event => :unuse}}}}
response = put(order_uuid, parameters)


# ========
# Searches
# ========

puts 
puts "SEARCHES"
puts "========"
puts

# Search all the tubes which have the role "Input"
# and a "done" status in an order.
# Use a search by order

puts "SEARCH ALL THE TUBES WITH: ROLE=INPUT AND STATUS=DONE"
puts

parameters = {:search => {:description => "search input tubes with done status",
                          :model => "tube",
                          :criteria => {:order => {:item => {:role => "Input",
                                                             :status => "done"}}}}}
response = post("searches", parameters)

# The post request only creates the search.
# The following get the actual results of the search
if response
  results = JSON.parse(response.body)
  results_url = results["search"]["actions"]["first"]
  response = get(results_url)
end

# Search all the orders which have items with the role "Input" 
# and a "done" status.
# Use a classic search resource.

puts "SEARCH ALL THE ORDERS WHICH HAVE ITEMS WITH: ROLE=INPUT AND STATUS=DONE"
puts

parameters = {:search => {:description => "search orders with input tubes with a done status",
                          :model => "order",
                          :criteria => {:item => {:role => "Input",
                                                  :status => "done"}}}}
response = post("searches", parameters)

# The post request only creates the search.
# The following get the actual results of the search
if response
  results = JSON.parse(response.body)
  results_url = results["search"]["actions"]["first"]
  response = get(results_url)
end


# Search orders which contain tube having "JKL1234" barcode.
# 2 steps:
# - search the tube resource by barcode
# - search the order with the tube resource uuid

puts "SEARCH ALL THE ORDERS WHICH HAVE A TUBE WITH: BARCODE=JKL1234"
puts

parameters = {:search => {:description => "search tube by barcode",
                          :model => "tube",
                          :criteria => {:label => {:type => "sanger-barcode",
                                                   :value => "JKL1234"}}}}
response = post("searches", parameters)

# The post request only creates the search.
# The following get the uuid of the found tube 
if response
  results = JSON.parse(response.body)
  results_url = results["search"]["actions"]["first"]
  response = get(results_url)
  
  results = JSON.parse(response.body)
  tube_uuid = results["tubes"].first["tube"]["uuid"] 
end

# We then use the tube uuid to get the order.
parameters = {:search => {:description => "search orders containing barcoded JKL1234 tube",
                          :model => "order",
                          :criteria => {:item => {:uuid => tube_uuid}}}}
response = post("searches", parameters)

# The search is created by the post request and 
# we get the results using the following:
if response
  results = JSON.parse(response.body)
  results_url = results["search"]["actions"]["first"]
  response = get(results_url)
end

