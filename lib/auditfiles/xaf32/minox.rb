module Auditfiles::Xaf32
  class Minox < Base
    class TransactionLine
      include SaxStream::Mapper

      node 'trLine'

      map :nr, to: 'nr'
      map :account_id, to: 'accID'
      map :document_id, to: 'docRef'
      map :effective_date, to: 'effDate', as: Date
      map :description, to: 'desc'
      map :amount, to: 'amnt', as: Auditfiles::Xaf32::Base::Amount
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
      map :amount, to: 'amnt', as: Auditfiles::Xaf32::Base::Amount
      map :amount_type, to: 'amntTp'
      map :sourceID, to: 'sourceID'

      relate :transaction_lines, to: 'trLine', as: [TransactionLine], parent_collects: true
    end

    class OpeningBalanceLine
      include SaxStream::Mapper

      node 'obLine'

      map :nr, to: 'nr'
      map :account_id, to: 'accID'
      map :amount, to: 'amnt', as: Auditfiles::Xaf32::Base::Amount
      map :amount_type, to: 'amntTp'
    end

    class OpeningBalance
      include SaxStream::Mapper

      node 'openingBalance'

      map :date, to: 'opBalDate', as: Date
      map :description, to: 'opBalDesc'
      map :lines_Count, to: 'linesCount'
      map :total_debit, to: 'totalDebit', as: Auditfiles::Xaf32::Base::Amount
      map :total_credit, to: 'totalCredit', as: Auditfiles::Xaf32::Base::Amount

      relate :opening_balance_lines, to: 'obLine', as: [OpeningBalanceLine], parent_collects: true
    end

    class Company
      include SaxStream::Mapper

      node 'company'

      map :company_ident, to: 'companyIdent'
      map :company_name, to: 'companyName'
      map :tax_registration_country, to: 'taxRegistrationCountry'
      map :tag_reg_ident, to: 'taxRegIdent'

      relate :relations, to: 'customersSuppliers/customerSupplier', as: [Auditfiles::Xaf32::Base::Relation]
      relate :ledgers, to: 'generalLedger/ledgerAccount', as: [Auditfiles::Xaf32::Base::Ledger]
      relate :periods, to: 'periods/period', as: [Auditfiles::Xaf32::Base::Period]
      relate :transactions, to: 'transactions/journal/transaction', as: [Transaction]
      relate :opening_balances, to: 'openingBalance', as: [OpeningBalance]
    end

    class Auditfile
      include SaxStream::Mapper

      node 'auditfile'

      map :xsd, to: '@xsi:schemaLocation'

      relate :header, to: 'header', as: Auditfiles::Xaf32::Base::Header
      relate :company, to: 'company', as: Company
    end

    # Pass each collected tag to the block
    def read
      products = []
      projects = []
      departments = []
      fiscal_year = nil

      collector = SaxStream::Collectors::BlockCollector.new do |obj|
        obj_class = obj.class.name[/[^:]+\z/]
        if obj_class == 'Header'
          fiscal_year = obj['fiscal_year']
          obj['product_version'] = '' unless obj['product_version']
          yield(obj_class, obj.attributes)
        elsif obj_class == 'OpeningBalance'
          obj.relations['opening_balance_lines'].each do |line|
            line['effective_date'] = obj['date']
            line['year'] = fiscal_year || line['date'].year.to_s
            line['period'] = '0'

            line['debit_amount'] = line['amount_type'].casecmp('d').zero? ? line['amount'] : 0
            line['debit_amount'] = line['debit_amount'].abs if line['debit_amount'].zero?
            line['credit_amount'] = line['amount_type'].casecmp('c').zero? ? line['amount'] : 0
            line['credit_amount'] = line['credit_amount'].abs if line['credit_amount'].zero?

            line['description'] = obj['description']
            yield('TransactionLine', line.attributes)
          end
        elsif obj_class == 'Transaction'
          # Add info to transaction lines and extract other dimensions
          obj.relations['transaction_lines'].each do |line|
            # Stupid AFAS
            line['effective_date'] = obj['transaction_date'] if obj['period'] == '0'
            line['period'] = obj['period']
            line['year'] = fiscal_year || line['effective_date'].year.to_s

            line['debit_amount'] = line['amount_type'].casecmp('d').zero? ? line['amount'] : 0
            line['debit_amount'] = line['debit_amount'].abs if line['debit_amount'].zero?
            line['credit_amount'] = line['amount_type'].casecmp('c').zero? ? line['amount'] : 0
            line['credit_amount'] = line['credit_amount'].abs if line['credit_amount'].zero?

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
                                                 Transaction, TransactionLine, OpeningBalance,
                                                 OpeningBalanceLine])

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
