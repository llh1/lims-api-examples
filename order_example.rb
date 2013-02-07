require 'json'
require 'rest_client'

API_ROOT = "http://localhost:9292"
HEADERS = {'Content-Type' => 'application/json', 'Accept' => 'application/json'}
API = RestClient::Resource.new(API_ROOT)

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

def execution_trace(url, parameters, response)
  puts "Request to #{API_ROOT}/#{url}"
  puts "with the following JSON:"
  puts parameters.to_json
  if send_request?
    puts "and get the response:"
    puts response
  end
  puts
end
# ====================
# End Helper functions
# ====================

input_uuid = "aaa000000"
spin_uuid = "bbb111111"
tubeout_uuid = "ccc222222"
epa_uuid = "ddd333333"

# =================
# Barcode resources
# =================
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

# Initial state
# Create the order and setup the source and the targets.
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
parameters = {:event => :build}
response = post(order_uuid, parameters)

parameters = {:event => :start}
response = post(order_uuid, parameters)

# Spin and TubeOut are in progress
parameters = {:items => {"Spin" => {spin_uuid => {:event => :start}},
                         "TubeOut" => {tubeout_uuid => {:event => :start}}}}
response = post(order_uuid, parameters)

# Spin and TubeOut are done. 
# Input is exhausted.
parameters = {:items => {"Spin" => {spin_uuid => {:event => :complete}},
                         "TubeOut" => {tubeout_uuid => {:event => :complete}},
                         "Input" => {input_uuid => {:event => :unuse}}}}
response = post(order_uuid, parameters)

# EpA is done.
# Spin is exhausted.
parameters = {:items => {"EpA" => {epa_uuid => {:event => :complete}},
                         "Spin" => {spin_uuid => {:event => :unuse}}}}
response = post(order_uuid, parameters)


# ========
# Searches
# ========

# Search all the tubes which have the role "Input"
# and a "done" status in an order.
# Use a search by order action.
parameters = {:search => {:description => "search input tubes with done status",
                          :model => "tube",
                          :criteria => {:order => {:item => {:role => "Input",
                                                             :status => "done"}}}}}
response = post("searches", parameters)

# Search all the orders which have items with the role "Input" 
# and a "done" status.
# Use a classic search resource.
parameters = {:search => {:description => "search orders with input tubes with a done status",
                          :model => "order",
                          :criteria => {:item => {:role => "Input",
                                                  :status => "done"}}}}
response = post("searches", parameters)

# Search orders which contain tube having "JKL1234" barcode.
# 2 steps:
# - search the tube resource by barcode
# - search the order with the tube resource uuid
parameters = {:search => {:description => "search tube by barcode",
                          :model => "tube",
                          :criteria => {:label => {:type => "sanger-barcode",
                                                   :value => "JKL1234"}}}}
response = post("searches", parameters)
tube_uuid = response[:uuid] if response

parameters = {:search => {:description => "search orders containing barcoded JKL1234 tube",
                          :model => "order",
                          :criteria => {:item => {:uuid => tube_uuid}}}}
response = post("searches", parameters)


