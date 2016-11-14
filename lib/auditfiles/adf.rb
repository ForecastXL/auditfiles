module Auditfiles
  class Adf < Importer
    def initialize(document_path)
      @document_path = document_path
      @header = {}
      @header_rows_count = 1
    end

    def read_header
      parse_header_line(File.open(@document_path, "r:ISO-8859-1:UTF-8").readline)
    end

    def read(&block)
      relations = []
      products = []
      projects = []
      departments = []
      ledgers = []

      File.open(@document_path, "r:ISO-8859-1:UTF-8").each_line(sep="\r\n") do |line|
        if $. <= @header_rows_count
          @header = parse_header_line(line)
          block.call('Header', @header)
        else
          parsed_line = parse_line(line)
          relations << extract_relation(parsed_line)
          products << extract_product(parsed_line)
          projects << extract_project(parsed_line)
          departments << extract_department(parsed_line)
          ledgers << extract_ledger(parsed_line)

          block.call('TransactionLine', extract_transaction(parsed_line))
        end
      end

      relations.compact.reject { |e| e[:relation_name].empty? }.uniq.each do |obj|
        block.call('Relation', obj)
      end

      products.compact.reject { |e| e[:product_id].empty? }.uniq.each do |obj|
        block.call('Product', obj)
      end

      projects.compact.reject { |e| e[:project_id].empty? }.uniq.each do |obj|
        block.call('Project', obj)
      end

      departments.compact.reject { |e| e[:department_id].empty? }.uniq.each do |obj|
        block.call('Department', obj)
      end

      ledgers.compact.uniq.each do |obj|
        block.call('Ledger', obj)
      end

      true
    end

    private

    # KNOWN BUG: Some auditfiles start number_entries one pos earlier than specs say...
    # But we stick to the specs!
    def parse_header_line(line)
      {
        auditfile_version: line[0...12].strip,
        product_id: line[12...62].strip,
        product_version: line[12...62].strip, # kopie van id
        company_id: line[62...82].strip,
        fiscal_year: line[82...97].strip[0...4],
        tax_registration_nr: line[97...112].strip,
        company_name: line[112...162].strip,
        company_address: line[162...192].strip,
        company_city: line[192...222].strip,
        number_entries: line[222...232].strip.to_i,
        date_created: parse_date(line[232...242].strip),
        total_debit: parse_amount(line[242...258].strip),
        total_credit: parse_amount(line[258...278].strip)
      }
    rescue
      raise "Error in ADF header: #{File.basename(@document_path)}"
    end

    def parse_line(line)
      {
        journal_id: line[0...20].strip,
        journal_description: line[20...50].strip,
        period: line[50...55].strip,
        transaction_id: line[55...65].strip,
        record_id: line[65...70].strip,
        journaalpost: line[70...90].strip,
        effective_date: line[90...100].strip,
        account_id: line[100...115].strip,
        account_type: line[115...120].strip,
        account_cluster: line[120...135].strip,
        account_desc: line[135...165].strip,
        transaction_date: line[165...175].strip,
        document_id: line[175...190].strip,
        soortMutatie: line[190...195].strip,
        relatieAndereAdministraties: line[195...210].strip,
        kostenplaats: line[210...225].strip,
        kostensoort: line[225...240].strip,
        kostendrager: line[240...255].strip,
        description: line[255...285].strip,
        debit_amount: line[285...301].strip,
        credit_amount: line[301...317].strip,
        vat_code: line[317...322].strip,
        valuta: line[322...332].strip,
        koers: line[332...345].strip,
        relation_id: line[345...360].strip,
        relation_type: line[360...365].strip,
        relation_tax_registration_nr: line[365...381].strip,
        relation_name: line[381...411].strip,
        relation_address: line[411...441].strip,
        relation_postal_code: line[441...451].strip,
        relation_city: line[451...481].strip,
        relation_country: line[481...496].strip
      }
    end

    def extract_relation(parsed_line)
      {
        relation_id: parsed_line[:relation_id],
        relation_name: parsed_line[:relation_name],
        relation_type: parsed_line[:relation_type]
      }
    end

    def extract_product(parsed_line)
      {
        product_id: parsed_line[:kostendrager]
      }
    end

    def extract_project(parsed_line)
      {
        project_id: parsed_line[:kostensoort]
      }
    end

    def extract_department(parsed_line)
      {
        department_id: parsed_line[:kostenplaats]
      }
    end

    def extract_ledger(parsed_line)
      {
        account_id: parsed_line[:account_id],
        account_desc: parsed_line[:account_desc],
        account_type: parse_account_type(parsed_line[:account_type])
      }
    end

    def extract_journal(parsed_line)
      {
        journal_id: parsed_line[:journal_id],
        journal_description: parsed_line[:journal_description],
        journal_type: parsed_line[:journal_type]
      }
    end

    def extract_transaction(parsed_line)
      {
        record_id: parsed_line[:record_id],
        journal_id: parsed_line[:journal_id],
        account_id: parsed_line[:account_id],
        relation_id: parsed_line[:relation_id],
        product_id: parsed_line[:kostendrager],
        project_id: parsed_line[:kostensoort],
        department_id: parsed_line[:kostenplaats],
        transaction_id: parsed_line[:transaction_id],
        description: parsed_line[:description],
        effective_date: parse_date(parsed_line[:effective_date]),
        transaction_date: parse_date(parsed_line[:transaction_date]),
        debit_amount: parse_amount(parsed_line[:debit_amount]),
        credit_amount: parse_amount(parsed_line[:credit_amount]),
        period: parse_period(parsed_line[:period], parse_date(parsed_line[:transaction_date])),
        year: @header[:fiscal_year].blank? ? parse_date(parsed_line[:transaction_date]).year : @header[:fiscal_year]
        # period: parsed_line[:period].to_i
      }
    end

    # 16,2 waarbij decimaalteken een punt of komma mag zijn
    # nil of lege string wordt: 0.0
    def parse_amount(amount)
      amount.gsub(/[,\.]/, '').to_i / 100.0
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

    def parse_account_type(type)
      case type
      when 'B', 'BAL', 'Balans', 'BAS', 'Blns'
        'B'
      when 'P', 'R', 'V/W', 'W/V', 'W', 'PNL', 'V&W', 'W&V', 'W V', 'V W', 'WenV'
        'P'
      else
        ''
      end
    end

    def parse_period(period, date)
      if period.blank?
        date.respond_to?(:month) ? date.month : nil
      elsif period.respond_to?(:to_i)
        if period.to_i >= 0 && period.to_i <= 12
          period
        elsif period.to_i > 12
          12
        else
          nil
        end
      end
    end
  end
end
