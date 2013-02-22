module Lims::Api::Examples
  module Constant
    INITIAL_QUANTITY = 1000

    ALIQUOT_TYPE_RNAP = "RNA+P"
    ALIQUOT_TYPE_DNA = "DNA"
    ALIQUOT_TYPE_RNA = "RNA"
    ALIQUOT_TYPE_NA = "NA"
    ALIQUOT_TYPE_NAP = "NA+P"

    # DNA+RNA manual extraction
    module DnaRnaManualExtraction
      ORDER_PIPELINE = "DNA+RNA manual extraction"
      SOURCE_TUBE_BARCODE = "XX123456K"
      SOURCE_TUBE_ALIQUOT_TYPE = ALIQUOT_TYPE_NAP
      ROLE_TUBE_TO_BE_EXTRACTED = "tube_to_be_extracted"
      ROLE_BY_PRODUCT_TUBE = "by_product_tube"
      ROLE_BINDING_SPIN_COLUMN_DNA = "binding_spin_column_dna"
      ROLE_ELUTION_SPIN_COLUMN_DNA = "elution_spin_column_dna"
      ROLE_BINDING_SPIN_COLUMN_RNA = "binding_spin_column_rna"
      ROLE_ELUTION_SPIN_COLUMN_RNA = "elution_spin_column_rna"
      ROLE_EXTRACTED_TUBE = "extracted_tube"
    end

    module DnaRnaAutomatedExtraction
      ORDER_PIPELINE = "DNA+RNA automated extraction"
      SOURCE_TUBE_BARCODE = "XX987654K"
      SOURCE_TUBE_ALIQUOT_TYPE = ALIQUOT_TYPE_NA
      ROLE_TUBE_TO_BE_EXTRACTED = "tube_to_be_extracted"
      ROLE_ALIQUOT_A = "aliquot_a"
      ROLE_EPPENDORF_A = "eppendorf_a"
      ROLE_ALIQUOT_B = "aliquot_b"
      ROLE_EPPENDORF_B = "eppendorf_b"
      ROLE_ALIQUOT_C = "aliquot_c"
    end
  end
end
