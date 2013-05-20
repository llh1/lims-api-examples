require 'constant'

module Lims::Examples
  module ExampleManualExtraction
    module Gel
      include Constant

      def gel
        gel_for :dna
        gel_for :rna
      end


      private

      def gel_for(type)
        # Create a new empty gel plate
        API::new_step("Create a new gel plate")
        parameters = {:gel => {:number_of_columns => 12,
                               :number_of_rows => 8,
                               :windows_description => {}}}
        response = API::post(@routes["gels"]["actions"]["create"], parameters)
        gel_uuid = response["gel"]["uuid"]

        # Add the gel in the order and start it
        API::new_step("Add the new gel plate in the order and start it")
        role_gel = type.to_s == "dna" ? ROLE_GEL_DNA : ROLE_GEL_RNA
        parameters = {:items => {role_gel => {gel_uuid => {:event => :start, :batch_uuid => batch_uuid}}}}
        API::put(@order_update_url, parameters)

        # Transfers
        # TODO

        # Change status of gel plate
        # TODO
      end
    end
  end
end
