module Auditfiles
  class Xaf2Snelstart < XafV2
    class LedgerType
      def self.parse(string)
        case string
        when 'B', 'BAL', 'Balans', 'A', 'BAS', 'Blns', 'Activa', 'Passiva', 'Debiteur', 'Crediteur'
          'B'
        when 'P', 'R', 'V/W', 'W/V', 'W', 'PNL', 'V W', 'W V', 'L', 'Winst &amp; verlies', 'Winst & verlies', 'WenV', 'Kosten', 'Opbrengsten', 'Resultaten'
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
