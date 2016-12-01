module Auditfiles
  class ImuisXafV2 < XafV2
    class LedgerType
      def self.parse(string)
        case string
        when 'A', 'P'
          'B'
        when 'B', 'L'
          'P'
        else
          ''
        end
      end
    end

    # Convert to currency amount
    class Amount
      def self.parse(string)
        string ||= '0'
        string.to_d
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

    # def parse_projects(data)
    #   data.map do |transaction|
    #     {
    #       project_id: transaction[:project_id]
    #     } unless transaction[:project_id] == '0'
    #   end.compact.uniq
    # end

    # def parse_departments(data)
    #   data.map do |transaction|
    #     {
    #       department_id: transaction[:department_id]
    #     } unless transaction[:department_id] == '0'
    #   end.compact.uniq
    # end

    # def parse_products(data)
    #   data.map do |transaction|
    #     {
    #       product_id: transaction[:product_id]
    #     } unless transaction[:product_id] == '0'
    #   end.compact.uniq
    # end

    # def parse_transaction_line(line, journal, trans)
    #   {
    #     record_id: line[:record_id],
    #     journal_id: journal[:journal_id],
    #     account_id: line[:account_id],
    #     relation_id: line[:cust_sup_id],
    #     product_id: line[:product_desc] == '0' ? nil : line[:product_desc],
    #     project_id: line[:project_desc] == '0' ? nil : line[:project_desc],
    #     department_id: line[:cost_desc] == '0' ? nil : line[:cost_desc],
    #     transaction_id: trans[:transaction_id],
    #     description: line[:description],
    #     effective_date: parse_date(line[:effective_date].to_s),
    #     transaction_date: parse_date(trans[:transaction_date].to_s),
    #     debit_amount: parse_amount(line[:debit_amount] || '0'),
    #     credit_amount: parse_amount(line[:credit_amount] || '0'),
    #     period: parse_period(line[:period], parse_date(trans[:transaction_date].to_s)),
    #     year: @header[:fiscal_year]
    #   }
    # end

    # def parse_period(period, date)
    #   if period.blank?
    #     date.respond_to?(:month) ? date.month : nil
    #   elsif period.respond_to?(:to_i)
    #     if period.to_i >= 0 && period.to_i <= 12
    #       period
    #     elsif period.to_i > 12
    #       12
    #     else
    #       nil
    #     end
    #   end
    # end
  end
end
