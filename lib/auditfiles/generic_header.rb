module Auditfiles
  # Read header from all kinds of XML and ADF files
  class GenericHeader
    def self.determine(document_path)
      self.new(document_path).read_header
    end

    def initialize(document_path)
      @document_path = document_path
    end

    def read_header
      case File.extname(@document_path).downcase
      when '.adf'
        [:adf, read_adf_header.with_indifferent_access]
      when '.xaf'
        [:xaf, read_xaf_header.with_indifferent_access]
      end
    end

    ### ADF types

    def read_adf_header
      text = File.open(@document_path, "r:ISO-8859-1:UTF-8").read
      parse_header_line(text.lines.first)
    end

    def parse_header_line(line)
      header = {}

      begin
        header[:auditfile_version]   = line[0...12].strip
        header[:product_id]          = line[12...62].strip
        header[:product_version]     = line[12...62].strip # kopie van id
        header[:company_id]          = line[62...82].strip
        header[:fiscal_year]         = line[82...97].strip[0...4]
        header[:tax_registration_nr] = line[97...112].strip
        header[:company_name]        = line[112...162].strip
        header[:company_address]     = line[162...192].strip
        header[:company_city]        = line[192...222].strip

        header[:number_entries]      = line[222...232].strip.to_i
        header[:date_created]        = parse_date(line[232...242].strip)
        header[:total_debit]         = parse_amount(line[242...258].strip)
        header[:total_credit]        = parse_amount(line[258...278].strip)
      rescue
        raise "Error in ADF header"
      end

      header
    end

    # 16,2 waarbij decimaalteken een punt of komma mag zijn
    # nil of lege string wordt: 0.0
    def parse_amount(amount)
      (amount || '0').gsub(/[,\.]/, '').to_i / 100.0
    end

    # 2009-01-12 or 12012009 (equals 12 jan 2009)
    def parse_date(date)
      return nil if date.blank?
      begin
        Date.parse(date)
      rescue
        Date.strptime(date, '%d%m%Y')
      end
    end


    ### XAF types

    # Determine auditfile type and header properties
    def read_xaf_header
      # Pass each collected tag to the block
      collector = SaxStream::Collectors::NaiveCollector.new

      # Create parser
      parser = SaxStream::Parser.new(collector, [Auditfile, Company, Header, Transactions])

      # Start parsing as a stream
      parser.parse_stream(File.open(@document_path))

      header = collector.for_type(Header).first.attributes
      header['product_version'] = '' unless header['product_version']

      # Only for xafv2
      transactions = begin
        collector.for_type(Transactions).first.attributes
      rescue
        {}
      end
      header.merge(transactions)
    end

    # Convert to currency amount
    class Amount
      def self.parse(value)
        (value || '0').gsub(/[,\.]/, '').to_i / 100.0
      end
    end

    class Header
      include SaxStream::Mapper

      node 'header'

      # xafv2
      map :auditfile_version, to: 'auditfileVersion'
      map :company_id, to: 'companyID'
      map :taxRegistrationNr, to: 'taxRegistrationNr'
      map :product_id, to: 'productID'
      map :product_version, to: 'productVersion'

      # xafv3
      map :fiscal_year, to: 'fiscalYear'
      map :start_date, to: 'startDate', as: Date
      map :end_date, to: 'endDate', as: Date
      map :date_created, to: 'dateCreated', as: Date
      map :product_id, to: 'softwareDesc'
      map :product_version, to: 'softwareVersion'
    end

    class Transactions
      include SaxStream::Mapper

      node 'transactions'

      map :number_entries, to: 'numberEntries'
      map :total_debit, to: 'totalDebit', as: Amount
      map :total_credit, to: 'totalCredit', as: Amount

      map :number_entries, to: 'linesCount'
    end

    class Company
      include SaxStream::Mapper

      node 'company'

      map :company_ident, to: 'companyIdent'
      map :company_name, to: 'companyName'
      map :tax_registration_country, to: 'taxRegistrationCountry'
      map :tag_reg_idend, to: 'taxRegIdent'

      # v3
      relate :transactions, to: 'transactions', as: Transactions
    end

    class Auditfile
      include SaxStream::Mapper

      node 'auditfile'

      relate :header, to: 'header', as: Header
      relate :company, to: 'company', as: Company

      # v2
      relate :transactions, to: 'transactions', as: Transactions
    end
  end
end
