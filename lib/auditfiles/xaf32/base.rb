module Auditfiles
  module Xaf32
    class Base
      def initialize(document_path)
        @document_path = document_path
      end

      # Converts all different ledger_types to a standard one.
      #
      # Each vendor has its own way of indicating whether a ledger belongs on the balance or on the
      # profitandloss.
      class LedgerType
        # @param value [String] the ledger_type as used by the vendor.
        # @return [String] 'B' or 'P', raises if not found.
        def self.parse(value)
          case value
          when 'B', 'BAL', 'Balans', 'A', 'BAS', 'Blns', 'Activa', 'Passiva'
            'B'
          when 'P', 'R', 'V/W', 'W/V', 'W', 'PNL', 'V W', 'W V', 'L', 'Winst &amp; verlies',
            'Winst & verlies', 'WenV', 'Kosten', 'Opbrengsten'
            'P'
          else
            raise ArgumentError, "LedgerType is not recognized: #{value}"
          end
        end
      end

      # Convert to currency amount
      class Amount
        # @param value [String] the amount as used by the vendor.
        # @return [BigDecimal] 'B' or 'P' or raises if not found.
        def self.parse(string)
          string ||= '0'
          if string.index(/[,\.]/)
            string.gsub(/[,\.]/, '').to_i / 100.0
          else
            string.to_d
          end
        end
      end

      class RelationType
        def self.parse(value)
          value == 'S' ? 'C' : 'D'
        end
      end

      class Header
        include SaxStream::Mapper

        node 'header'

        map :fiscal_year, to: 'fiscalYear'
        map :start_date, to: 'startDate', as: Date
        map :end_date, to: 'endDate', as: Date
        map :currency, to: 'curCode'
        map :date_created, to: 'dateCreated', as: Date
        map :product_id, to: 'softwareDesc'
        map :product_version, to: 'softwareVersion'
      end

      class TransactionLine
        include SaxStream::Mapper

        node 'trLine'

        map :nr, to: 'nr'
        map :account_id, to: 'accID'
        map :document_id, to: 'docRef'
        map :effective_date, to: 'effDate', as: Date
        map :description, to: 'desc'
        map :amount, to: 'amnt', as: Amount
        map :amount_type, to: 'amntTp'
        map :relation_id, to: 'custSupID'
        map :invRef, to: 'invRef'
        map :costID, to: 'costID'
        map :product_id, to: 'prodID'
        map :project_id, to: 'projID'
        map :artGrpID, to: 'artGrpID'
        map :qntityID, to: 'qntityID'
        map :qntity, to: 'qntity'
        map :currencyCode, to: 'currency/curCode'
        map :currencyAmount, to: 'currency/curAmnt'
      end

      class Transaction
        include SaxStream::Mapper

        node 'transaction'

        map :nr, to: 'nr'
        map :description, to: 'desc'
        map :period, to: 'periodNumber'
        map :transaction_date, to: 'trDt', as: Date
        map :amount, to: 'amnt', as: Amount
        map :amount_type, to: 'amntTp'
        map :sourceID, to: 'sourceID'

        relate :transaction_lines, to: 'trLine', as: [TransactionLine], parent_collects: true
      end

      class Ledger
        include SaxStream::Mapper

        node 'ledgerAccount'

        map :account_id, to: 'accID'
        map :account_desc, to: 'accDesc'
        map :account_type, to: 'accTp', as: LedgerType
      end

      class Relation
        include SaxStream::Mapper

        node 'customerSupplier'

        map :relation_id, to: 'custSupID'
        map :relation_name, to: 'custSupName'
        map :relation_type, to: 'custSupTp', as: RelationType
      end

      class Period
        include SaxStream::Mapper

        node 'period'

        map :period, to: 'periodNumber'
        map :name, to: 'periodDesc'
        map :start_date, to: 'startDatePeriod', as: Date
        map :end_date, to: 'endDatePeriod', as: Date
      end

      class Company
        include SaxStream::Mapper

        node 'company'

        map :company_ident, to: 'companyIdent'
        map :company_name, to: 'companyName'
        map :tax_registration_country, to: 'taxRegistrationCountry'
        map :tag_reg_ident, to: 'taxRegIdent'

        relate :relations, to: 'customersSuppliers/customerSupplier', as: [Relation]
        relate :ledgers, to: 'generalLedger/ledgerAccount', as: [Ledger]
        relate :periods, to: 'periods/period', as: [Period]
        relate :transactions, to: 'transactions/journal/transaction', as: [Transaction]
      end

      class Auditfile
        include SaxStream::Mapper

        node 'auditfile'

        relate :header, to: 'header', as: Header
        relate :company, to: 'company', as: Company
      end

      def read
        # Pass each collected tag to the block
        products = []
        projects = []
        departments = []
        fiscal_year = nil

        collector = SaxStream::Collectors::BlockCollector.new do |obj|
          obj_class = obj.class.name.split('::').last
          if obj_class == 'Header'
            fiscal_year = obj['fiscal_year']
            obj['product_version'] ||= ''
            yield(obj_class, obj.attributes)
          elsif obj_class == 'Transaction'
            # Add info to transaction lines and extract other dimensions
            obj.relations['transaction_lines'].each do |line|
              line['period'] = obj['period']
              line['debit_amount'] = line['amount_type'].casecmp('d').zero? ? line['amount'] : 0
              line['credit_amount'] = line['amount_type'].casecmp('c').zero? ? line['amount'] : 0
              line['year'] = fiscal_year || line['effective_date'].year.to_s

              products << { product_id: line['product_id'] }
              projects << { project_id: line['project_id'] }
              departments << { department_id: line['department_id'] }

              yield('TransactionLine', line.attributes)
            end
          else
            yield(obj_class, obj.attributes)
          end
        end

        # Create parser
        parser = SaxStream::Parser.new(collector, [Auditfile, Header, Company, Relation, Ledger,
                                                   Period, Transaction])

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
    end
  end
end
