require 'json'
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
# -d "connection string to the database"

options = {}
OptionParser.new do |opts|
  opts.banner = "Usage: setup_s2_environment.rb [options]"
  opts.on("-d", "--db [DB]") { |v| options[:db] = v}
end.parse!

CONNECTION_STRING = options[:db] || "sqlite:///Users/llh1/Developer/lims-api/dev.db"
DB = Sequel.connect(CONNECTION_STRING)
STORE = Lims::Core::Persistence::Sequel::Store.new(DB)

TUBE_ALIQUOT_TYPE = "NA+P"
TUBE_BARCODE = "XX123456K"
ORDER_PIPELINE = "DNA+RNA manual extraction"
TUBE_ROLE = "tube_to_be_extracted"
TUBE_ALIQUOT_QUANTITY = 10
TUBE_SOLVENT_QUANTITY = 10

# ==================
# Clean the database
# ==================
%w{items orders batches searches labels labellables tube_aliquots spin_column_aliquots  
aliquots tubes spin_columns studies users uuid_resources}.each do |table|
  DB[table.to_sym].delete
end

module Lims::Core

  # ====================================
  # Needed in the order creation action:
  # - a valid study uuid
  # - a valid user uuid
  # Add a user and a study in the core
  # ===================================
  order_config = STORE.with_session do |session|
    user = Organization::User.new
    session << user
    user_uuid = session.uuid_for!(user)

    study = Organization::Study.new
    session << study
    study_uuid = session.uuid_for!(study)

    lambda { {:user_id => session.id_for(user), :study_id => session.id_for(study)} }
  end.call

  # ===============
  # Create the tube
  # ===============
  tube_uuid = STORE.with_session do |session|
    tube = Laboratory::Tube.new
    tube << Laboratory::Aliquot.new(:type => TUBE_ALIQUOT_TYPE,
                                    :quantity => TUBE_ALIQUOT_QUANTITY)
    tube << Laboratory::Aliquot.new(:type => Laboratory::Aliquot::Solvent,
                                    :quantity => TUBE_SOLVENT_QUANTITY)
    session << tube
    tube_uuid = session.uuid_for!(tube)
    lambda { tube_uuid }
  end.call

  # ================
  # Barcode the tube
  # ================
  STORE.with_session do |session|
    labellable = Laboratory::Labellable.new(:name => tube_uuid, :type => "resource")
    labellable["barcode"] = Laboratory::Labellable::Label.new(:type => "sanger-barcode", :value => TUBE_BARCODE)
    session << labellable
    labellable_uuid = session.uuid_for!(labellable)
  end

  # ==============================
  # Create the order with the tube
  # ==============================
  STORE.with_session do |session|
    order = Organization::Order.new(:creator => session.user[order_config[:user_id]],
                                    :study => session.study[order_config[:study_id]],
                                    :pipeline => ORDER_PIPELINE,
                                    :cost_code => "cost code")
    order.add_source(TUBE_ROLE, [tube_uuid])
    session << order
    session.uuid_for!(order)
  end
end
