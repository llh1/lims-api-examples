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

      end
    end
  end
end
