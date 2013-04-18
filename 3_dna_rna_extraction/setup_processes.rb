require 'sequel'
require 'lims-core'
require 'lims-core/persistence/sequel'
require 'optparse'

# Setup the arguments passed to the script
options = {}
OptionParser.new do |opts|
  opts.banner = "Usage: setup_s2_environment.rb [options]"
  opts.on("-d", "--db [DB]") { |v| options[:db] = v }
  opts.on("-v", "--verbose") { |v| options[:verbose] = true }
end.parse!

CONNECTION_STRING = options[:db] || "sqlite:///Users/llh1/Developer/lims-api/dev.db"
DB = Sequel.connect(CONNECTION_STRING)
STORE = Lims::Core::Persistence::Sequel::Store.new(DB)

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


pipelines = [{:name => "manual RNA only", :initial_type => "RNA+P", :initial_role => "samples.extraction.manual.rna_only.input_tube_rnap"},
             {:name => "manual DNA only", :initial_type => "DNA+P", :initial_role => "samples.extraction.manual.dna_only.input_tube_dnap"}, 
             {:name => "manual RNA & DNA extraction", :initial_type => "NA+P", :initial_role => "samples.extraction.manual.dna_and_rna.input_tube_nap"},
             {:name => "QIAcube RNA only", :initial_type => "RNA+P", :initial_role => "samples.extraction.qiacube.rna_only.input_tube_rnap"}, 
             {:name => "QIAcube DNA only", :initial_type => "DNA+P", :initial_role => "samples.extraction.qiacube.dna_only.input_tube_dnap"},
             {:name => "QIAcube RNA & DNA extraction", :initial_type => "NA+P", :initial_role => "samples.extraction.qiacube.dna_and_rna.input_tube_nap"}]

ean13_barcodes = ["2748670880727", "2741854757853", "2748746359751", "2747595068692", "2740339747792", "2742794419689", "2864342335729", "2862020760818", "2861142419659", "2864843093845", "2861652094766", "2868634585687", "2883368706764", "2888290344824", "2887672984771", "2882890700769", "2885978789816", "2888089913668"] 
sanger_barcodes = ["JD8670880H", "JD1854757U", "JD8746359K", "JD7595068E", "JD0339747O", "JD2794419D", "JP4342335H", "JP2020760Q", "JP1142419A", "JP4843093T", "JP1652094L", "JP8634585D", "JR3368706L", "JR8290344R", "JR7672984M", "JR2890700L", "JR5978789Q", "JR8089913B"] 

pipelines.each do |pipeline|
  # Create 3 samples
  sample_uuids = [0, 1, 2].map do |i|
    STORE.with_session do |session|
      sample = Lims::Core::Laboratory::Sample.new(:name => "sample_#{i}")
      session << sample
      sample_uuid = session.uuid_for!(sample)

      lambda { sample_uuid }
    end.call
  end

  # Create 3 tubes
  labelled_tubes = [0, 1, 2]
  labelled_tubes.map! do |i|
    STORE.with_session do |session|
      tube = Lims::Core::Laboratory::Tube.new
      tube << Lims::Core::Laboratory::Aliquot.new(:sample => session[sample_uuids[i]],
                                                  :type => pipeline[:initial_type],
                                                  :quantity => 1000)
      session << tube
      tube_uuid = session.uuid_for!(tube)

      labellable = Lims::Core::Laboratory::Labellable.new(:name => tube_uuid, :type => "resource")
      labellable["barcode"] = Lims::Core::Laboratory::Labellable::Label.new(:type => "ean13-barcode", 
                                                                            :value => ean13_barcodes.pop)
      labellable["sanger label"] = Lims::Core::Laboratory::Labellable::Label.new(:type => "sanger-barcode", 
                                                                                 :value => sanger_barcodes.pop)
      session << labellable
      labellable_uuid = session.uuid_for!(labellable)

      lambda { {:tube_uuid => tube_uuid, :labellable_uuid => labellable_uuid} }
    end.call
  end

  # Create 2 orders
  # First order with 2 tubes, Second order with 1 tube
  tube_uuids = labelled_tubes.map {|a| a[:tube_uuid]} 
  order_uuids = [[tube_uuids[0], tube_uuids[1]], [tube_uuids[2]]].map do |source_tubes|
    STORE.with_session do |session|
      order = Lims::Core::Organization::Order.new(:creator => session.user[order_config[:user_id]],
                                                  :study => session.study[order_config[:study_id]],
                                                  :pipeline => pipeline[:name],
                                                  :cost_code => "cost code")
      order.add_source(pipeline[:initial_role], source_tubes)
      session << order
      order_uuid = session.uuid_for!(order)

      lambda { order_uuid }
    end.call
  end
end
