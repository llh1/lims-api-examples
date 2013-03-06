require 'helpers/constant'
require 'workflows/units/re_tubing'
require 'workflows/units/dna_rna_automated_extraction'
require 'workflows/workflow'

module Lims::Api::Examples
  class AutomatedWorkflow < Workflow

    include ReTubing
    include DnaRnaAutomatedExtraction
    include PostExtractionTubeRacking

    def start
      super
      re_tubing_workflow
      dna_rna_automated_workflow
      set_post_extraction_constants(Constant::DnaRnaAutomatedExtraction)
      post_extraction_tube_racking_workflow
    end
  end
end

