module Auditfiles
  class ImporterFactory
    def self.create(path_to_file)
      type, header = GenericHeader.determine(path_to_file)
      case type
      when :adf
        case header[:product_id]
        when /Multivers/
          MultiversAdfV1
        when /imuis/i
          AdfImuis
        when /snelstart/i
          AdfSnelstart
        else
          AdfV1
        end
      when :xaf
        case header[:auditfile_version]
        when 'CLAIR2.00.00'
          case header[:product_id]
          when 'iMUIS'
            ImuisXafV2
          when 'KLEISTEEN'
            KleisteenXafV2
          when 'e-Boekhouden.nl'
            EboekhoudenXafV2
          when 'Asperion'
            AsperionXafV2
          when /snelstart/i
            Xaf2Snelstart
          when 'Profit'
            Xaf2Afas
          else
            DefaultXafV2
          end
        else
          case header[:product_id]
          when 'Profit'
            Xaf32::AfasProfit
          else
            Xaf32::Base
          end
        end
      else
        raise "Unknown auditfile format: #{File.basename(path_to_file)}"
      end.new(path_to_file)
    end
  end
end
