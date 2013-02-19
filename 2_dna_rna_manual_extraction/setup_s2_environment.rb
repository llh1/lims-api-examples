require 'json'
require 'rest_client'
require 'lims-core'
require 'lims-core/persistence/sequel'
require 'sequel'
require 'optparse'

# This script setup a clean working environment for S2 
# and create an order with the following tube:
#   . aliquot type: NA+P
#   . role: tube_to_be_extracted
#   . barcode: "XX123456K"
# Note:
# The script can be called with the following parameters
# -u "root url to s2 api server"
# -d "connection string to the database"

options = {}
OptionParser.new do |opts|
  opts.banner = "Usage: setup_s2_environment.rb [options]"
  opts.on("-u", "--url [URL]") { |v| options[:url] = v}
  opts.on("-d", "--db [DB]") { |v| options[:db] = v}
end.parse!

API_ROOT = options[:url] || "http://localhost:9292"
HEADERS = {'Content-Type' => 'application/json', 'Accept' => 'application/json'}
API = RestClient::Resource.new(API_ROOT)

CONNECTION_STRING = options[:db] || "sqlite:///Users/llh1/Developer/lims-api/dev.db"
DB = Sequel.connect(CONNECTION_STRING)
STORE = Lims::Core::Persistence::Sequel::Store.new(DB)

TUBE_ALIQUOT_TYPE = "NA+P"
TUBE_BARCODE = "XX123456K"
ORDER_PIPELINE = "DNA+RNA manual extraction"
TUBE_ROLE = "tube_to_be_extracted"

# ==================
# Clean the database
# ==================
%w{items orders batches searches labels labellables tube_aliquots 
aliquots tubes studies users uuid_resources}.each do |table|
  DB[table.to_sym].delete
end

# ====================================
# Needed in the order creation action:
# - a valid study uuid
# - a valid user uuid
# Add a user and a study in the core
# ===================================
order_config = STORE.with_session do |session|
  user = Lims::Core::Organization::User.new
  session << user
  user_uuid = session.uuid_for!(user)

  study = Lims::Core::Organization::Study.new
  session << study
  study_uuid = session.uuid_for!(study)

  lambda { {:user_uuid => user_uuid, :study_uuid => study_uuid} }
end.call

# ===============
# Create the tube
# ===============
parameters = {:tube => {:type => TUBE_ALIQUOT_TYPE}}
response = API["tubes"].post(parameters.to_json, HEADERS) 
tube_uuid = JSON.parse(response)["tube"]["uuid"]

# ================
# Barcode the tube
# ================
parameters = {:labellable => {:name => tube_uuid,
                              :type => "resource",
                              :labels => {"barcode" => {:value => TUBE_BARCODE,
                                                        :type => "sanger-barcode"}}}}
API["labellables"].post(parameters.to_json, HEADERS)

# ==============================
# Create the order with the tube
# ==============================
parameters = {:order => {:user_uuid => order_config[:user_uuid],
                         :study_uuid => order_config[:study_uuid],
                         :pipeline => ORDER_PIPELINE,
                         :cost_code => "cost code",
                         :sources => {TUBE_ROLE => [tube_uuid]}}}
API["orders"].post(parameters.to_json, HEADERS)

