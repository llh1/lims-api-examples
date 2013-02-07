require 'json'
require 'rest_client'

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

def get(url)
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
parameters = {:tube => {}}
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

parameters = {:order => {:user_uuid => "user uuid",
                         :study_uuid => "study uuid",
                         :pipeline => "pipeline 1",
                         :cost_code => "cost code A",
                         :sources => {"Input" => [{:uuid => input_uuid}]},
                         :targets => {"Spin" => [{:uuid => spin_uuid}],
                                      "TubeOut" => [{:uuid => tubeout_uuid}],
                                      "EpA" => [{:uuid => epa_uuid}]}}}
response = post("orders", parameters) 
order_uuid = nil 

# The initial order status is set to draft.
# We need to first set it to pending, meaning it's validated
# by the end-user. Then we can set it to in_progress meaning
# some work are currently being done.

puts "CHANGE THE ORDER STATUS TO PENDING"
puts

parameters = {:event => :build}
response = post(order_uuid, parameters)

puts "CHANGE THE ORDER STATUS TO IN_PROGRESS"
puts

parameters = {:event => :start}
response = post(order_uuid, parameters)

# Spin and TubeOut are in progress

puts "CHANGE THE SPIN AND TUBEOUT STATUS TO IN_PROGRESS"
puts

parameters = {:items => {"Spin" => {spin_uuid => {:event => :start}},
                         "TubeOut" => {tubeout_uuid => {:event => :start}}}}
response = post(order_uuid, parameters)

# Spin and TubeOut are done. 
# Input is unused.

puts "CHANGE THE SPIN AND TUBEOUT STATUS TO DONE"
puts "AND CHANGE THE INPUT STATUS TO UNUSED"
puts

parameters = {:items => {"Spin" => {spin_uuid => {:event => :complete}},
                         "TubeOut" => {tubeout_uuid => {:event => :complete}},
                         "Input" => {input_uuid => {:event => :unused}}}}
response = post(order_uuid, parameters)

# EpA is done.
# Spin is unused.

puts "CHANGE EPA STATUS TO DONE AND SPIN STATUS TO UNUSED"
puts

parameters = {:items => {"EpA" => {epa_uuid => {:event => :complete}},
                         "Spin" => {spin_uuid => {:event => :unused}}}}
response = post(order_uuid, parameters)


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
  results_url = response["search"]["actions"]["first"]
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
  results_url = response["search"]["actions"]["first"]
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
tube_uuid = response[:uuid] if response

# The post request only creates the search.
# The following get the uuid of the found tube 
if response
  results = JSON.parse(response.body)
  results_url = response["search"]["actions"]["first"]
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
  results_url = response["search"]["actions"]["first"]
  response = get(results_url)
end

