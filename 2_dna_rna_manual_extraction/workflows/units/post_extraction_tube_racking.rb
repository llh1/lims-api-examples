require 'helpers/constant'

module Lims::Api::Examples
  module PostExtractionTubeRacking

    include Constant

    private

    def set_post_extraction_constants(constant)
      @constant = constant
    end

    def post_extraction_tube_racking_workflow
      post_extraction_tube_racking_workflow_for("RNA")
      post_extraction_tube_racking_workflow_for("DNA")
      finish_order
    end

    def post_extraction_tube_racking_workflow_for(type)
      @parameters[:post_extraction].each do |order_nb, p|
        order_uuid = p[:order_uuid]
        batch_uuid = p[:batch_uuid]
        extracted_tube_uuids = p[:extracted_tube_uuids]
        n_entries = extracted_tube_uuids[type.to_sym].size

        API::new_order(order_nb)

        # =================================== 
        API::new_stage("#{type} post extraction tube racking. Create new tubes. Add them in the order. Transfer #{type} extracted tubes into 2D tubes. Then rack the 2D tubes in a tube rack.")
        # =================================== 

        API::new_step("Create new tubes")
        tube_2d_uuids = factory(:tube, n_entries, BARCODE_2D)

        API::new_step("Add the 2d tubes in the order and start them")
        role_name = (type == "RNA") ? @constant::ROLE_NAME_RNA : @constant::ROLE_NAME_DNA
        parameters = parameters_for_adding_resources_in_order(role_name => tube_2d_uuids)
        API::put(order_uuid, parameters)

        API::new_step("Transfer extracted tubes into 2D tubes")
        parameters = parameters_for_transfer([{:source => extracted_tube_uuids[type.to_sym], :target => tube_2d_uuids, :fraction => 1}])
        API::post("actions/transfer_tubes_to_tubes", parameters)

        API::new_step("Change the status of extracted_tube tubes to unused. Change the status of 2d tubes to complete")
        role_extracted_tube = (type == "RNA") ? @constant::ROLE_EXTRACTED_TUBE_RNA : @constant::ROLE_EXTRACTED_TUBE_DNA
        parameters = parameters_for_changing_items_status({
          role_extracted_tube => {:uuids => extracted_tube_uuids[type.to_sym], :event => :unuse},
          role_name => {:uuids => tube_2d_uuids, :event => :complete}
        })
        API::put(order_uuid, parameters)

        API::new_step("Create a new tube rack ")
        tubes = {}.tap { |h|
          tube_2d_uuids.zip(('A'..'H').map { |r| (1..12).map { |c| "#{r}#{c}" } }.flatten).each { |uuid, location|
            h[location] = uuid
          }}
        parameters = {:tube_rack => {:number_of_columns => 12,
                                     :number_of_rows => 8,
                                     :tubes => tubes}}
        response = API::post("tube_racks", parameters)
        tube_rack_uuid = response["tube_rack"]["uuid"]

        API::new_step("Add the tube rack in the order and start it")
        tube_rack_role = (type == "RNA") ? @constant::ROLE_STOCK_RNA : @constant::ROLE_STOCK_DNA
        parameters = {:items => {tube_rack_role => {
          tube_rack_uuid => {:event => :start, :batch_uuid => batch_uuid}}}} 
        API::put(order_uuid, parameters)

        API::new_step("Change the type of the rube rack to complete")
        parameters = {:items => {tube_rack_role => {tube_rack_uuid => {:event => :complete}}}}
        API::put(order_uuid, parameters)
      end
    end

    def finish_order
      @parameters[:post_extraction].each do |order_nb, p|
        order_uuid = p[:order_uuid]
        API::new_order(order_nb)

        # ============================================
        API::new_stage("Change the status of the order to completed.")
        # ============================================
        parameters = {:event => :complete}
        API::put(order_uuid, parameters)
      end
    end
  end
end
