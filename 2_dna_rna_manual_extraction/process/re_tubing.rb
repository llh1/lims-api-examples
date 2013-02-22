require 'helper/constant'

module Lims::Api::Examples
  module ReTubing
    include Constant

    def self.start
      @results = {}
      workflow
    end

    def self.results
      @results
    end

    private

    def self.workflow
      # Create a new tube
      parameters = {:tube => {:aliquots => [{:type => ALIQUOT_TYPE_NA, :quantity => INITIAL_QUANTITY}]}}
      response = API::post("tubes", parameters)
      tube_uuid = response["tube"]["uuid"]
     
      # Find the 2nd tube by barcode
      parameters = {:search => {:description => "search for barcoded tube",
                                :model => "tube",
                                :criteria => {:label => {:position => "barcode",
                                                         :type => "sanger-barcode",
                                                         :value => DnaRnaAutomatedExtraction::SOURCE_TUBE_BARCODE}}}}
      search_response = API::post("searches", parameters)
      result_url = search_response["search"]["actions"]["first"]
      result_response = API::get(result_url) 
      tube2_uuid = result_response["tubes"].first["tube"]["uuid"]
   
      # Transfer from first tube to second tube
      parameters = {:transfer_tubes_to_tubes => {:transfers => [{
        :source_uuid => tube_uuid,
        :target_uuid => tube2_uuid,
        :fraction => 1
      }]}}
      API::post("actions/transfer_tubes_to_tubes", parameters)

      # Results
      @results[:re_tubing_tube_uuid] = tube2_uuid 
    end
  end
end

