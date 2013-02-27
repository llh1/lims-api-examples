require 'lims-api-examples'
require 'json'
require 'lims-core'
require 'lims-core/persistence/sequel'
require 'sequel'
require 'optparse'
require 'helper/constant'

# This script setup a clean working environment for S2 
# Note:
# The script can be called with the following parameters
# -d "connection string to the database"
module Lims::Api::Examples
  include Constant

  # Setup the arguments passed to the script
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
    aliquots tube_rack_slots tube_racks tubes spin_columns studies users uuid_resources}.each do |table|
    DB[table.to_sym].delete
  end

  # Needed for the order creation
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

  # =======================================================
  # Setup the orders for dna_rna manual extraction pipeline
  # 2 tubes in 1 order
  # 1 tube in 1 order
  # =======================================================
  # Create the tubes for dna+rna manual extraction orders
  # Barcode each tube
  tube_manual_uuids = [0, 1, 2]
  tube_manual_uuids.map! do |i|
    STORE.with_session do |session|
      tube = Lims::Core::Laboratory::Tube.new
      tube << Lims::Core::Laboratory::Aliquot.new(:type => DnaRnaManualExtraction::SOURCE_TUBE_ALIQUOT_TYPE,
                                                  :quantity => INITIAL_QUANTITY)
      session << tube
      tube_uuid = session.uuid_for!(tube)

      labellable = Lims::Core::Laboratory::Labellable.new(:name => tube_uuid, :type => "resource")
      labellable["barcode"] = Lims::Core::Laboratory::Labellable::Label.new(:type => "sanger-barcode", 
                                                                            :value => DnaRnaManualExtraction::SOURCE_TUBE_BARCODES[i])
      session << labellable
      session.uuid_for!(labellable)

      lambda { tube_uuid }
    end.call
  end

  # Create orders
  # First order with 2 tubes, Second order with 1 tube
  [[tube_manual_uuids[0], tube_manual_uuids[1]], [tube_manual_uuids[2]]].each do |source_tubes|
    STORE.with_session do |session|
      # First order with 2 tubes
      order = Lims::Core::Organization::Order.new(:creator => session.user[order_config[:user_id]],
                                                  :study => session.study[order_config[:study_id]],
                                                  :pipeline => DnaRnaManualExtraction::ORDER_PIPELINE,
                                                  :cost_code => "cost code")
      order.add_source(DnaRnaManualExtraction::ROLE_TUBE_TO_BE_EXTRACTED, source_tubes)
      session << order
      session.uuid_for!(order)
    end
  end
 
  # ===========================================================
  # Setup the orders for dna_rna automated extraction pipeline
  # 1 tube in 1 order
  # ===========================================================
  # Create the tube for automated extraction pipeline 
  tube_automated_uuid = STORE.with_session do |session|
    tube = Lims::Core::Laboratory::Tube.new
    session << tube
    tube_uuid = session.uuid_for!(tube)

    labellable = Lims::Core::Laboratory::Labellable.new(:name => tube_uuid, :type => "resource")
    labellable["barcode"] = Lims::Core::Laboratory::Labellable::Label.new(:type => "sanger-barcode", 
                                                                          :value => DnaRnaAutomatedExtraction::SOURCE_TUBE_BARCODE)
    session << labellable
    session.uuid_for!(labellable)

    lambda { tube_uuid }
  end.call

  # Create the order with the tube
  STORE.with_session do |session|
    order = Lims::Core::Organization::Order.new(:creator => session.user[order_config[:user_id]],
                                                :study => session.study[order_config[:study_id]],
                                                :pipeline => DnaRnaAutomatedExtraction::ORDER_PIPELINE,
                                                :cost_code => "cost code")
    order.add_source(DnaRnaAutomatedExtraction::ROLE_TUBE_TO_BE_EXTRACTED, [tube_automated_uuid])
    session << order
    session.uuid_for!(order)
  end
end
