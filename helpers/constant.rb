module Lims
  module Examples
    module Constant
      INITIAL_QUANTITY = 1000

      ALIQUOT_TYPE_RNAP = "RNA+P"
      ALIQUOT_TYPE_DNA = "DNA"
      ALIQUOT_TYPE_RNA = "RNA"
      ALIQUOT_TYPE_NA = "NA"
      ALIQUOT_TYPE_NAP = "NA+P"

      BARCODE_EAN13 = "ean13-barcode"
      BARCODE_2D = "2d-barcode"

      USER = "username"

      ORDER_PIPELINE = "DNA+RNA manual extraction"
      KIT_BARCODE = "1234567891011"

      SOURCE_TUBE_ALIQUOT_TYPE = ALIQUOT_TYPE_NAP

      ROLE_TUBE_TO_BE_EXTRACTED = "tube_to_be_extracted"
      ROLE_TUBE_TO_BE_EXTRACTED_NAP = "samples.extraction.manual.dna_and_rna.input_tube_nap"
      ROLE_TUBE_TO_BE_EXTRACTED_RNAP = "samples.extraction.manual.dna_and_rna.binding_input_tube_rnap"
      ROLE_BINDING_TUBE_TO_BE_EXTRACTED_NAP = "samples.extraction.manual.dna_and_rna.binding_input_tube_nap"
      ROLE_BY_PRODUCT_TUBE_RNAP = "samples.extraction.manual.dna_and_rna.byproduct_tube_rnap"
      ROLE_BINDING_SPIN_COLUMN_DNA = "samples.extraction.manual.spin_column_dna"
      ROLE_BINDING_SPIN_COLUMN_RNA = "samples.extraction.manual.spin_column_rna"
      ROLE_EXTRACTED_TUBE_DNA = "samples.extraction.manual.extracted_tube_dna" 
      ROLE_EXTRACTED_TUBE_RNA = "samples.extraction.manual.extracted_tube_rna"
      ROLE_NAME_DNA = "samples.extraction.manual.name_dna"
      ROLE_NAME_RNA = "samples.extraction.manual.name_rna"
      ROLE_STOCK_RNA = "samples.extraction.manual.stock_rna"
      ROLE_STOCK_DNA = "samples.extraction.manual.stock_dna"
    end
  end
end
