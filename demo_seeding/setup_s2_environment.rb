require 'sequel'
require 'lims-laboratory-app'
require 'lims-support-app/kit/kit'
require 'lims-support-app/kit/kit_persistor'
require 'lims-support-app/kit/kit_sequel_persistor'
require 'lims-core/persistence/sequel'
require 'lims-core/persistence/sequel/filters'
require 'optparse'

# Setup the arguments passed to the script
options = {}
OptionParser.new do |opts|
  opts.banner = "Usage: setup_s2_environment.rb [options]"
  opts.on("-d", "--db [DB]") { |v| options[:db] = v }
  opts.on("-v", "--verbose") { |v| options[:verbose] = true }
end.parse!

CONNECTION_STRING = options[:db] || "sqlite:///Users/llh1/Developer/lims-laboratory-app/dev.db"
DB = Sequel.connect(CONNECTION_STRING)
STORE = Lims::Core::Persistence::Sequel::Store.new(DB)

%w{items orders batches searches labels labellables tube_aliquots spin_column_aliquots  
    aliquots tube_rack_slots tube_racks tubes spin_columns studies users uuid_resources samples kits}.each do |table|
  DB[table.to_sym].delete
end

# Needed for the order creation
# - a valid study uuid
# - a valid user uuid
order_config = STORE.with_session do |session|
  user = Lims::LaboratoryApp::Organization::User.new
  session << user
  user_uuid = session.uuid_for!(user)

  study = Lims::LaboratoryApp::Organization::Study.new
  session << study
  study_uuid = session.uuid_for!(study)

  lambda { {:user_id => session.id_for(user), 
            :user_uuid => user_uuid,
            :study_id => session.id_for(study),
            :study_uuid => study_uuid} }
end.call


pipelines = [
  {name: "manual RNA only",              kit_type: "RNA",     initial_type: "RNA+P", initial_role: "samples.extraction.manual.rna_only.input_tube_rnap"   },
  {name: "manual DNA only",              kit_type: "DNA",     initial_type: "DNA+P", initial_role: "samples.extraction.manual.dna_only.input_tube_dnap"   },
  {name: "manual RNA & DNA extraction",  kit_type: "DNA+RNA", initial_type: "NA+P",  initial_role: "samples.extraction.manual.dna_and_rna.input_tube_nap" },
  {name: "QIAcube RNA only",             kit_type: "RNA",     initial_type: "RNA+P", initial_role: "samples.extraction.qiacube.rna_only.input_tube_rnap"  },
  {name: "QIAcube DNA only",             kit_type: "DNA",     initial_type: "DNA+P", initial_role: "samples.extraction.qiacube.dna_only.input_tube_dnap"  },
  {name: "QIAcube RNA & DNA extraction", kit_type: "DNA+RNA", initial_type: "NA+P",  initial_role: "samples.extraction.qiacube.dna_and_rna.input_tube_nap"}
]


ean13_barcodes = Object.new.tap do |o|
  class << o
    attr_accessor :last_barcode
  end
  o.last_barcode = 8800000000000

  def o.pop
    self.last_barcode += 1
    self.last_barcode.to_s
  end
end


sanger_barcodes = Object.new.tap do |o|
  class << o
    attr_accessor :last_barcode
  end
  o.last_barcode = 8800000

  def o.pop
    self.last_barcode += 1
    "JD#{self.last_barcode}L"
  end
end

pipelines.each do |pipeline|
  if options[:verbose] 
    puts "Seed #{pipeline[:name]}" 
    puts "=============="
  end

  # Create 3 samples
  sample_uuids = [0, 1, 2].map do |i|
    STORE.with_session do |session|
      sample = Lims::LaboratoryApp::Laboratory::Sample.new(:name => "sample_#{i}")
      session << sample
      sample_uuid = session.uuid_for!(sample)

      lambda { sample_uuid }
    end.call
  end

  expiry_dates_amounts  = [
    [Date::civil(2014,05,01), 10],
    [Date::civil(2013,01,01), 10],
    [Date::civil(2014,05,01), 0 ]
  ]

  expiry_dates_amounts.each do |expiry_date, amount|
    STORE.with_session do |session|
      kit = Lims::SupportApp::Kit.new(
        :process      => pipeline[:name],
        :aliquot_type => pipeline[:kit_type],
        :expires      => expiry_date,
        :amount       => amount
      )
      session << kit
      kit_uuid = session.uuid_for!(kit)

      barcode_value = ean13_barcodes.pop
      sanger_barcode_value = sanger_barcodes.pop
      labellable                 = Lims::LaboratoryApp::Labels::Labellable.new(       :type => "resource",       :name => kit_uuid)
      labellable["barcode"]      = Lims::LaboratoryApp::Labels::Labellable::Label.new(:type => "ean13-barcode",  :value => barcode_value)
      labellable["sanger label"] = Lims::LaboratoryApp::Labels::Labellable::Label.new(:type => "sanger-barcode", :value => sanger_barcode_value)

      session << labellable
      labellable_uuid = session.uuid_for!(labellable)

      if options[:verbose]
        puts "Kit created with ean13-barcode=#{barcode_value}, sanger-barcode=#{sanger_barcode_value}"
      end

      lambda { {:kit_uuid => kit_uuid, :labellable_uuid => labellable_uuid} }
    end.call
  end

  # Create 3 tubes
  labelled_tubes = [0, 1, 2]
  labelled_tubes.map! do |i|
    STORE.with_session do |session|
      tube = Lims::LaboratoryApp::Laboratory::Tube.new
      tube << Lims::LaboratoryApp::Laboratory::Aliquot.new(
        :type => Lims::LaboratoryApp::Laboratory::Aliquot::Solvent,
        :quantity => 1000
      )
      tube << Lims::LaboratoryApp::Laboratory::Aliquot.new(
        :sample   => session[sample_uuids[i]],
        :type     => pipeline[:initial_type],
        :quantity => 1000
      )
      session << tube
      tube_uuid = session.uuid_for!(tube)

      barcode_value = ean13_barcodes.pop 
      sanger_barcode_value = sanger_barcodes.pop
      labellable = Lims::LaboratoryApp::Labels::Labellable.new(:name => tube_uuid, :type => "resource")
      labellable["barcode"] = Lims::LaboratoryApp::Labels::Labellable::Label.new(:type => "ean13-barcode", :value => barcode_value)
      labellable["sanger label"] = Lims::LaboratoryApp::Labels::Labellable::Label.new(:type => "sanger-barcode", :value => sanger_barcode_value)

      session << labellable
      labellable_uuid = session.uuid_for!(labellable)

      if options[:verbose]
        puts "Tube created with ean13-barcode=#{barcode_value}, sanger-barcode=#{sanger_barcode_value}"
      end

      lambda { {:tube_uuid => tube_uuid, :labellable_uuid => labellable_uuid} }
    end.call
  end

  # Create 2 orders
  # First order with 2 tubes, Second order with 1 tube
  tube_uuids = labelled_tubes.map {|a| a[:tube_uuid]} 
  order_uuids = [[tube_uuids[0], tube_uuids[1]], [tube_uuids[2]]].map do |source_tubes|
    STORE.with_session do |session|
      order = Lims::LaboratoryApp::Organization::Order.new(:creator => session.user[order_config[:user_id]],
                                                           :study => session.study[order_config[:study_id]],
                                                           :pipeline => pipeline[:name],
                                                           :cost_code => "cost code")
      order.add_source(pipeline[:initial_role], source_tubes)
      session << order
      order_uuid = session.uuid_for!(order)

      if options[:verbose]
        puts "Order created with #{source_tubes.size} tubes"
      end

      lambda { order_uuid }
    end.call
  end

  puts if options[:verbose]
end
