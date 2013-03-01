require 'helpers/constant'
require 'workflows/units/shared_units'

module Lims::Api::Examples
  module ReTubing

    include Constant::DnaRnaAutomatedExtraction
    include SharedUnits

    private

    def re_tubing_workflow
      assign_batch
      results = search_orders_by_batch
      order_uuid = results[:order_uuids].first
      source_tube_uuid = results[:source_tube_uuids_array].first.first

      # =========================
      API::new_stage("Build and start the order")
      # =========================

      API::new_step("Change the status of the order to pending")
      parameters = {:event => :build}
      API::put(order_uuid, parameters)

      API::new_step("Change the status of the order to in_progress")
      parameters = {:event => :start}
      API::put(order_uuid, parameters)


      # ===============================
      API::new_stage("Re-Tubing. Create new tube and transfer from tube to tube.")
      # ===============================

      API::new_step("Create a new tube")
      tube_uuid = factory(:tube).first

      API::new_step("Add the new tube in the order and start it")
      parameters = {:items => {ROLE_TUBE_TO_BE_EXTRACTED => {tube_uuid => {:event => :start, :batch_uuid => batch_uuid}}}}
      API::put(order_uuid, parameters)

      API::new_step("Transfer from first tube to second tube")
      parameters = {:transfer_tubes_to_tubes => {:transfers => [{
        :source_uuid => source_tube_uuid,
        :target_uuid => tube_uuid,
        :fraction => 1
      }]}}
      API::post("actions/transfer_tubes_to_tubes", parameters)

      API::new_step("Change the status of source tube to unused, new tube_to_be_extracted tube to done")
      parameters = {:items => {
        ROLE_TUBE_TO_BE_EXTRACTED => {source_tube_uuid => {:event => :unuse}},
        ROLE_TUBE_TO_BE_EXTRACTED => {tube_uuid => {:event => :complete}}}}
      API::put(order_uuid, parameters)


      @parameters[:automated_extraction] = {:order_uuid => order_uuid, :tube_to_be_extracted_uuid => tube_uuid}
    end
  end
end
