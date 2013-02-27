require 'process/dna_rna_manual_extraction'
require 'process/post_extraction_tube_racking'
require 'rubygems'
require 'ruby-debug/debugger'

module Lims::Api::Examples
  class ManualWorkflow
    include DnaRnaManualExtraction
    include PostExtractionTubeRacking

    def initialize(barcodes = [])
      @barcodes = barcodes
      @init_tubes_number = barcodes.size
      @parameters = {}
    end

    def start
      dna_rna_manual_extraction_workflow
      post_extraction_tube_racking_workflow
    end

    private

    def factory(resource_type)
      Array.new(@init_tubes_number).map do |_| 
        parameters = {resource_type.to_sym => {}}
        response = API::post("#{resource_type.to_s}s", parameters)
        resource_uuid = response[resource_type.to_s]["uuid"]
        barcode(resource_uuid)
        resource_uuid
      end
    end

    def method_missing(name, *args, &block)
      return @parameters[name.to_sym] if @parameters.include?(name.to_sym)
      super(name, *args, &block)
    end

    def barcode(resource_uuid)
      parameters = {:labellable => {:name => resource_uuid,
                                    :type => "resource",
                                    :labels => {"barcode" => {:value => API::barcode,
                                                              :type => "sanger-barcode"}}}}
      API::post("labellables", parameters)
    end

    def batch_uuid 
      @batch_uuid
    end

    # @items [Hash]
    # @example
    # {role => [uuid1, uuid2]}
    def parameters_for_adding_resources_in_order(items)
      {:items => {}.tap do |h|
        items.each do |role, uuids|
          h.merge!({role => {}.tap do |h_uuid|
            uuids.each { |uuid| h_uuid.merge!({uuid => {:event => :start, :batch_uuid => batch_uuid}}) }
          end
          })
        end
      end
      }
    end

    # @items [Hash]
    # @example
    # {role => {:uuids => [uuid1, uuid2], :event => :complete}}
    def parameters_for_changing_items_status(items)
      {:items => {}.tap do |h|
        items.each do |role, attributes|
          h.merge!({role => {}.tap do |h_uuid|
            attributes[:uuids].each { |uuid| h_uuid.merge!({uuid => {:event => attributes[:event]}}) }
          end
          })
        end
      end
      }
    end

    # @param [Hash] transfers
    # @example
    # [{:source => source_uuids, :target => target_uuids, :fraction => 0.5, :aliquot_type => type}] 
    def parameters_for_transfer(transfers)
      {:transfer_tubes_to_tubes => {:transfers => [].tap do |a|
        transfers.each do |transfer|
          transfer[:source].zip(transfer[:target]).each do |source_uuid, target_uuid|
            transfer_mode = transfer[:fraction] ? :fraction : :amount
            a << {:source_uuid => source_uuid, :target_uuid => target_uuid, transfer_mode => transfer[transfer_mode], :aliquot_type => transfer[:aliquot_type]}
          end
        end
      end
      }}
    end
  end
end
