require 'lims-api-examples'
require 'json'
require 'lims-core'
require 'lims-core/persistence/sequel'
require 'sequel'
require 'optparse'
require 'helper/constant'

# This script setup a clean working environment for S2 
# and create an order with the following tube:
#   . aliquot type: NA+P
#   . role: tube_to_be_extracted
#   . barcode: "XX123456K"
# Note:
# The script can be called with the following parameters
# -d "connection string to the database"
module Lims::Api::Examples
  include Constant

  options = {}
  OptionParser.new do |opts|
    opts.banner = "Usage: setup_s2_environment.rb [options]"
    opts.on("-d", "--db [DB]") { |v| options[:db] = v}
  end.parse!

  CONNECTION_STRING = options[:db] || "sqlite:///Users/llh1/Developer/lims-api/dev.db"
  DB = Sequel.connect(CONNECTION_STRING)
  STORE = Lims::Core::Persistence::Sequel::Store.new(DB)


  # Clean the database
  %w{items orders batches searches labels labellables tube_aliquots spin_column_aliquots  
aliquots tubes spin_columns studies users uuid_resources}.each do |table|
    DB[table.to_sym].delete
  end

  # Needed in the order creation action:
  # - a valid study uuid
  # - a valid user uuid
  # Add a user and a study in the core
  order_config = STORE.with_session do |session|
    user = Lims::Core::Organization::User.new
    session << user
    user_uuid = session.uuid_for!(user)

    study = Lims::Core::Organization::Study.new
    session << study
    study_uuid = session.uuid_for!(study)

    lambda { {:user_id => session.id_for(user), :study_id => session.id_for(study)} }
  end.call

  # Create the tube for dna+rna manual extraction order
  tube_manual_uuid = STORE.with_session do |session|
    tube = Lims::Core::Laboratory::Tube.new
    tube << Lims::Core::Laboratory::Aliquot.new(:type => DnaRnaManualExtraction::SOURCE_TUBE_ALIQUOT_TYPE,
                                                :quantity => INITIAL_QUANTITY)
    tube << Lims::Core::Laboratory::Aliquot.new(:type => Lims::Core::Laboratory::Aliquot::Solvent,
                                                :quantity => INITIAL_QUANTITY)
    session << tube
    tube_uuid = session.uuid_for!(tube)
    lambda { tube_uuid }
  end.call

  # Create the tube
  tube_automated_uuid = STORE.with_session do |session|
    tube = Lims::Core::Laboratory::Tube.new
    session << tube
    tube_uuid = session.uuid_for!(tube)
    lambda { tube_uuid }
  end.call

  # Setup the order for dna+rna manual extraction pipeline
  # and for dna+rna automated pipeline
  [DnaRnaManualExtraction, DnaRnaAutomatedExtraction].zip([tube_manual_uuid, tube_automated_uuid]).each do |pipeline, tube_uuid|  
    # Barcode the tube
    STORE.with_session do |session|
      labellable = Lims::Core::Laboratory::Labellable.new(:name => tube_uuid, :type => "resource")
      labellable["barcode"] = Lims::Core::Laboratory::Labellable::Label.new(:type => "sanger-barcode", 
                                                                            :value => pipeline::SOURCE_TUBE_BARCODE)
      session << labellable
      labellable_uuid = session.uuid_for!(labellable)
    end

    # Create the order with the tube
    STORE.with_session do |session|
      order = Lims::Core::Organization::Order.new(:creator => session.user[order_config[:user_id]],
                                                  :study => session.study[order_config[:study_id]],
                                                  :pipeline => pipeline::ORDER_PIPELINE,
                                                  :cost_code => "cost code")
      order.add_source(pipeline::ROLE_TUBE_TO_BE_EXTRACTED, [tube_uuid])
      session << order
      session.uuid_for!(order)
    end
  end
end
