require 'helpers/constant'

module Lims::Api::Examples
  module DnaRnaAutomatedExtraction

    include Constant
    include Constant::DnaRnaAutomatedExtraction

    private
    
    def dna_rna_automated_workflow
      order_uuid = @parameters[:automated_extraction][:order_uuid]
      input_uuid = @parameters[:automated_extraction][:tube_to_be_extracted_uuid]


      # =====================================================
      API::new_stage("Create eppendorf a tube. Create aliquot a tube. Transfer the tube_to_be_extracted to eppendorf_a tube and to aliquot a tube.")
      # =====================================================
      API::new_step("Create the tube aliquot a") 
      aliquot_a_tube_uuid = factory("tube").first 

      API::new_step("Create the tube eppendorf a")
      eppendorf_a_tube_uuid = factory("tube").first

      API::new_step("Add the new tubes in the order and start them")
      parameters = {:items => {
        ROLE_ALIQUOT_A => {aliquot_a_tube_uuid => {:event => :start, :batch_uuid => batch_uuid}},
        ROLE_EPPENDORF_A => {eppendorf_a_tube_uuid => {:event => :start, :batch_uuid => batch_uuid}}}}
      API::put(order_uuid, parameters)

      API::new_step("Transfer")
      parameters = {:transfer_tubes_to_tubes => {:transfers => [
        {:source_uuid => input_uuid,
         :target_uuid => aliquot_a_tube_uuid,
         :fraction => 0.5}, 
         {:source_uuid => input_uuid,
          :target_uuid => eppendorf_a_tube_uuid,
          :fraction => 0.5,
          :aliquot_type => ALIQUOT_TYPE_DNA}
      ]}}
      API::post("actions/transfer_tubes_to_tubes", parameters)

      API::new_step("Change the status of source tube to unused, aliquot_a tube to done and eppendorf_a to done")
      parameters = {:items => {
        ROLE_TUBE_TO_BE_EXTRACTED => {input_uuid => {:event => :unuse}},
        ROLE_ALIQUOT_A => {aliquot_a_tube_uuid => {:event => :complete}},
        ROLE_EPPENDORF_A => {eppendorf_a_tube_uuid => {:event => :complete}}}}
      API::put(order_uuid, parameters)


      # ==============================================
      API::new_stage("Create aliquot b tube. Transfer fron aliquot a tube to aliquot b tube")
      # ==============================================
      API::new_step("Create the tube aliquot b")
      aliquot_b_tube_uuid = factory("tube").first 

      API::new_step("Add the new tube in the order and start it")
      parameters = {:items => {
        ROLE_ALIQUOT_B => {aliquot_b_tube_uuid => {:event => :start, :batch_uuid => batch_uuid}}}}
      API::put(order_uuid, parameters)

      API::new_step("Transfer")
      parameters = {:transfer_tubes_to_tubes => {:transfers => [
        {:source_uuid => aliquot_a_tube_uuid,
         :target_uuid => aliquot_b_tube_uuid,
         :fraction => 1}]}}
      API::post("actions/transfer_tubes_to_tubes", parameters)

      API::new_step("Change the status of aliquot a tube to unused, aliquot_b tube to done")
      parameters = {:items => {
        ROLE_ALIQUOT_A => {aliquot_a_tube_uuid => {:event => :unuse}},
        ROLE_ALIQUOT_B => {aliquot_b_tube_uuid => {:event => :complete}}}}
      API::put(order_uuid, parameters)


      # ============================================
      API::new_stage("Create eppendorf b tube. Create aliquot c tube. Transfer from aliquot b to eppendorf b tube and aliquot c tube")
      # ============================================
      API::new_step("Create the tube eppendorf b")
      eppendorf_b_tube_uuid = factory("tube").first 

      API::new_step("Create the tube eppendorf c")
      aliquot_c_tube_uuid = factory("tube").first

      API::new_step("Add the new tube in the order and start it")
      parameters = {:items => {
        ROLE_ALIQUOT_C => {aliquot_c_tube_uuid => {:event => :start, :batch_uuid => batch_uuid}},
        ROLE_EPPENDORF_B => {eppendorf_b_tube_uuid => {:event => :start, :batch_uuid => batch_uuid}}}}
      API::put(order_uuid, parameters)

      API::new_step("Transfer")
      parameters = {:transfer_tubes_to_tubes => {:transfers => [
        {:source_uuid => aliquot_b_tube_uuid,
         :target_uuid => eppendorf_b_tube_uuid,
         :fraction => 0.5,
         :aliquot_type => ALIQUOT_TYPE_RNA},
         {:source_uuid => aliquot_b_tube_uuid,
          :target_uuid => aliquot_c_tube_uuid,
          :fraction => 0.5}]}}
      API::post("actions/transfer_tubes_to_tubes", parameters)

      API::new_step("Change the status of aliquot b tube to unused, aliquot_c tube to done and eppendorf b to done")
      parameters = {:items => {
        ROLE_ALIQUOT_B => {aliquot_b_tube_uuid => {:event => :unuse}},
        ROLE_ALIQUOT_C => {aliquot_c_tube_uuid => {:event => :complete}},
        ROLE_EPPENDORF_B => {eppendorf_b_tube_uuid => {:event => :complete}}}}
      API::put(order_uuid, parameters)


      @parameters[:post_extraction] = {}
      @parameters[:post_extraction]["common"] = {:order_uuid => order_uuid, 
                                          :batch_uuid => batch_uuid,
                                          :extracted_tube_uuids => {:RNA => [eppendorf_b_tube_uuid],
                                                                    :DNA => [eppendorf_a_tube_uuid]}}
    end
  end
end
