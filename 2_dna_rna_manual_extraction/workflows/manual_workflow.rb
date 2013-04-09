require 'helpers/constant'
require 'workflows/units/dna_rna_manual_extraction'
require 'workflows/units/post_extraction_tube_racking'
require 'workflows/workflow'

module Lims::Api::Examples
  class ManualWorkflow < Workflow

    include DnaRnaManualExtraction
    include PostExtractionTubeRacking

    def start
      super
      dna_rna_manual_extraction_workflow
      #set_post_extraction_constants(Constant::DnaRnaManualExtraction)
      #post_extraction_tube_racking_workflow
    end
  end
end
