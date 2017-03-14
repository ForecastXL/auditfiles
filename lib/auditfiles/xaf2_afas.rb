module Auditfiles
  class Xaf2Afas < Importer
    def initialize(document_path)
      @document_path = document_path
    end

    def read
      # Pass each collected tag to the block
      products = []
      projects = []
      departments = []
      fiscal_year = nil

      collector = SaxStream::Collectors::BlockCollector.new do |obj|
        obj_class = obj.class.name.split('::').last
        case obj_class
        when 'Header'
          fiscal_year = obj['fiscal_year']
          obj['product_version'] ||= ''
          yield(obj_class, obj.attributes)
        when 'Transaction'
          # Add info to transaction lines and extract other dimensions
          obj.relations['transaction_lines'].each do |line|
            # Afas sets the transaction dates for the openingbalance on the last day of the previous
            # year on the line level. Oddly enough they do set the correct date on the transaction
            # level.
            line['effective_date'] = obj['transaction_date'] if obj['period'] == '0'
            line['period'] = obj['period']
            line['debit_amount'] ||= 0
            line['credit_amount'] ||= 0
            line['year'] = fiscal_year || line['effective_date'].year.to_s

            products << { product_id: line['product_id'] }
            projects << { project_id: line['project_id'] }
            departments << { department_id: line['cost_id'] }

            yield('TransactionLine', line.attributes)
          end
        else
          yield(obj_class, obj.attributes)
        end
      end

      # Create parser
      parser = SaxStream::Parser.new(collector, [self.class::Auditfile,
                                                 self.class::Header, self.class::Relation, self.class::Ledger,
                                                 self.class::Transaction, self.class::TransactionLine])

      # Start parsing as a stream
      parser.parse_stream(File.open(@document_path))

      # Pass other dimensions to block
      products.uniq.each do |product|
        yield('Product', product)
      end

      projects.uniq.each do |project|
        yield('Project', project)
      end

      departments.uniq.each do |department|
        yield('Department', department)
      end

      true
    end

    class LedgerType
      def self.parse(string)
        case string
        when 'B', 'BAL', 'Balans', 'A', 'BAS', 'Blns', 'Activa', 'Passiva', 'Debiteur', 'Crediteur'
          'B'
        when 'P', 'R', 'V/W', 'W/V', 'W', 'PNL', 'V W', 'W V', 'L', 'Winst &amp; verlies',
          'Winst & verlies', 'WenV', 'Kosten', 'Opbrengsten', 'Resultaten'
          'P'
        else
          ''
        end
      end
    end

    # Convert to currency amount
    class Amount
      def self.parse(string)
        string&.to_d || BigDecimal.new(0)
      end
    end

    class Header
      include SaxStream::Mapper

      node 'header'

      map :auditfile_version, to: 'auditfileVersion'
      map :company_id, to: 'companyID'
      map :tax_registration_nr, to: 'taxRegistrationNr'
      map :company_name, to: 'companyName'
      map :company_address, to: 'companyAddress'
      map :company_city, to: 'companyCity'
      map :company_postal_code, to: 'companyPostalCode'
      map :fiscal_year, to: 'fiscalYear'
      map :start_date, to: 'startDate'
      map :end_date, to: 'endDate'
      map :currency_code, to: 'currencyCode'
      map :date_created, to: 'dateCreated'
      map :product_id, to: 'productID'
      map :product_version, to: 'productVersion'
    end

    class TransactionLine
      include SaxStream::Mapper

      node 'line'

      map :nr, to: 'recordID'
      map :account_id, to: 'accountID'
      map :relation_id, to: 'custSupID'
      map :description, to: 'description'
      map :effective_date, to: 'effectiveDate', as: Date
      # map :document_id, to: 'documentID'
      map :cost_id, to: 'costDesc'
      map :product_id, to: 'productDesc'
      map :project_id, to: 'projectDesc'
      map :debit_amount, to: 'debitAmount', as: Amount
      map :credit_amount, to: 'creditAmount', as: Amount
    end

    class Transaction
      include SaxStream::Mapper

      node 'transaction'

      map :transaction_id, to: 'transactionID'
      map :description, to: 'description'
      map :period, to: 'period'
      map :transaction_date, to: 'transactionDate', as: Date

      relate :transaction_lines, to: 'line', as: [TransactionLine], parent_collects: true
    end

    # class Period
    #   include SaxStream::Mapper

    #   node 'period'

    #   map :relation_id, to: 'custSupID'
    #   map :relation_name, to: 'companyName'
    #   map :relation_type, to: 'type'
    # end

    class Relation
      include SaxStream::Mapper

      node 'customerSupplier'

      map :relation_id, to: 'custSupID'
      map :relation_name, to: 'companyName'
      map :relation_type, to: 'type'
    end

    class Ledger
      include SaxStream::Mapper

      node 'ledgerAccount'

      map :account_id, to: 'accountID'
      map :account_desc, to: 'accountDesc'
      map :account_type, to: 'accountType', as: LedgerType
    end

    class Auditfile
      include SaxStream::Mapper

      node 'auditfile'

      relate :header, to: 'header', as: Header
      relate :relations, to: 'customersSuppliers/customerSupplier', as: [Relation]
      relate :ledgers, to: 'generalLedger/ledgerAccount', as: [Ledger]
      relate :transactions, to: 'transactions/journal/transaction', as: [Transaction]
    end
  end
end
