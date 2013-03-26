require 'lims-api-examples'
require 'json'
require 'lims-core'
require 'lims-core/persistence/sequel'
require 'sequel'
require 'optparse'
require 'helpers/constant'

# This script setup a clean working environment for S2 
module Lims::Api::Examples
  include Constant

  # Setup the arguments passed to the script
  options = {}
  OptionParser.new do |opts|
    opts.banner = "Usage: setup_s2_environment.rb [options]"
    opts.on("-d", "--db [DB]") { |v| options[:db] = v }
    opts.on("-v", "--verbose") { |v| options[:verbose] = true }
    opts.on("-a", "--api [URL]") { |v| options[:api] = v }
    opts.on("-m", "--mode [MODE]") { |v| options[:mode] = v }
  end.parse!

  CONNECTION_STRING = options[:db] || "sqlite:///Users/llh1/Developer/lims-api/dev.db"
  API_ROOT = options[:api]
  MODE = options[:mode] || "manual"
  DB = Sequel.connect(CONNECTION_STRING)
  STORE = Lims::Core::Persistence::Sequel::Store.new(DB)

  module API
    if options[:api]
      require 'rest_client'
      def post(url, parameters)
        response = RestClient.post(
          "#{API_ROOT}/#{url}", 
          parameters.to_json,
          {'Content-Type' => 'application/json', 'Accept' => 'application/json'}
        )
        JSON.parse(response)
      end
    end
  end
  extend API

  # Clean the database
  %w{items orders batches searches labels labellables tube_aliquots spin_column_aliquots  
    aliquots tube_rack_slots tube_racks tubes spin_columns studies users uuid_resources samples}.each do |table|
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

    lambda { {:user_id => session.id_for(user), 
              :user_uuid => user_uuid,
              :study_id => session.id_for(study),
              :study_uuid => study_uuid} }
  end.call

  case MODE
    # =======================================================
    # Setup the orders for dna_rna manual extraction pipeline
    # 2 tubes in 1 order
    # 1 tube in 1 order
    # =======================================================
  when "manual" then 
    # Create the needed samples
    sample_uuids = [0, 1, 2].map do |i|
      STORE.with_session do |session|
        sample = Lims::Core::Laboratory::Sample.new(:name => "sample_#{i}")
        session << sample
        sample_uuid = session.uuid_for!(sample)

        lambda { sample_uuid }
      end.call
    end

    # Create the tubes for dna+rna manual extraction orders
    # Barcode each tube
    labelled_tube_manual_uuids = [0, 1, 2]
    labelled_tube_manual_uuids.map! do |i|
      if options[:api] 
        parameters = {:tube => {:aliquots => [{
          :sample_uuid => sample_uuids[i], 
          :quantity => INITIAL_QUANTITY, 
          :type => DnaRnaManualExtraction::SOURCE_TUBE_ALIQUOT_TYPE
        }]}}
        resource = post("tubes", parameters)
        tube_uuid = resource["tube"]["uuid"]

        parameters = {:labellable => {:name => tube_uuid,
                                      :type => "resource",
                                      :labels => {:barcode => {:type => BARCODE_EAN13,
                                                               :value => DnaRnaManualExtraction::SOURCE_TUBE_BARCODES[i]}}}}
        resource = post("labellables", parameters)
        labellable_uuid = resource["labellable"]["uuid"]

        {:tube_uuid => tube_uuid, :labellable_uuid => labellable_uuid}
      else
        STORE.with_session do |session|
          tube = Lims::Core::Laboratory::Tube.new
          tube << Lims::Core::Laboratory::Aliquot.new(:sample => session[sample_uuids[i]],
                                                      :type => DnaRnaManualExtraction::SOURCE_TUBE_ALIQUOT_TYPE,
                                                      :quantity => INITIAL_QUANTITY)
          session << tube
          tube_uuid = session.uuid_for!(tube)

          labellable = Lims::Core::Laboratory::Labellable.new(:name => tube_uuid, :type => "resource")
          labellable["barcode"] = Lims::Core::Laboratory::Labellable::Label.new(:type => BARCODE_EAN13, 
                                                                                :value => DnaRnaManualExtraction::SOURCE_TUBE_BARCODES[i])
          session << labellable
          labellable_uuid = session.uuid_for!(labellable)

          lambda { {:tube_uuid => tube_uuid, :labellable_uuid => labellable_uuid} }
        end.call
      end
    end

    # Create orders
    # First order with 2 tubes, Second order with 1 tube
    tube_manual_uuids = labelled_tube_manual_uuids.map {|a| a[:tube_uuid]} 
    order_uuids = [[tube_manual_uuids[0], tube_manual_uuids[1]], [tube_manual_uuids[2]]].map do |source_tubes|
      if options[:api]
        parameters = {:order => {:user_uuid => order_config[:user_uuid],
                                 :study_uuid => order_config[:study_uuid],
                                 :pipeline => DnaRnaManualExtraction::ORDER_PIPELINE,
                                 :cost_code => "cost code",
                                 :sources => {ROLE_TUBE_TO_BE_EXTRACTED_NAP => source_tubes}}}
        resource = post("orders", parameters)
        resource["order"]["uuid"]
      else
        STORE.with_session do |session|
          # First order with 2 tubes
          order = Lims::Core::Organization::Order.new(:creator => session.user[order_config[:user_id]],
                                                      :study => session.study[order_config[:study_id]],
                                                      :pipeline => DnaRnaManualExtraction::ORDER_PIPELINE,
                                                      :cost_code => "cost code")
          order.add_source(ROLE_TUBE_TO_BE_EXTRACTED_NAP, source_tubes)
          session << order
          order_uuid = session.uuid_for!(order)

          lambda { order_uuid }
        end.call
      end
    end

    if options[:verbose]
      STORE.with_session do |session|
        puts "User uuid: #{session.uuid_for(session.user[order_config[:user_id]])}"
        puts "Study uuid: #{session.uuid_for(session.study[order_config[:study_id]])}"
      end

      sample_uuids.each_with_index do |uuid, index|
        puts "Sample ##{index} uuid: #{uuid}"
      end

      labelled_tube_manual_uuids.each_with_index do |uuid, index|
        puts "Tube ##{index} uuid: #{uuid[:tube_uuid]}"
        puts "Labellable ##{index} uuid: #{uuid[:labellable_uuid]}"
      end

      order_uuids.each_with_index do |uuid, index|
        puts "Order ##{index}: #{uuid}"
      end
    end


    # ===========================================================
    # Setup the orders for dna_rna automated extraction pipeline
    # 1 tube in 1 order
    # ===========================================================
  when "automatic" then
    # Create the tube for automated extraction pipeline 
    tube_automated_uuid = STORE.with_session do |session|
      tube = Lims::Core::Laboratory::Tube.new
      session << tube
      tube_uuid = session.uuid_for!(tube)

      labellable = Lims::Core::Laboratory::Labellable.new(:name => tube_uuid, :type => "resource")
      labellable["barcode"] = Lims::Core::Laboratory::Labellable::Label.new(:type => BARCODE_EAN13, 
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
      order.add_source(ROLE_TUBE_TO_BE_EXTRACTED, [tube_automated_uuid])
      session << order
      session.uuid_for!(order)
    end
  end
end
