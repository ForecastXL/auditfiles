module Auditfiles
  class KleisteenXafV2Old < XafV2
    # FIXME: ledgers do not get created in import_data
    # FIXME: accounts do not get created in import_data
    # Kleisteen doesn't give the account type, it just gives repeats the account_id
    def parse_account_type(type)
      nil
    end

    # FIXME: 1 empty project gets created in import_data
    def parse_projects(data)
      data.map do |transaction|
        {
          project_id: transaction[:project_id]
        } unless transaction[:project_id].blank?
      end.compact.uniq
    end

    # FIXME: 1 empty department gets created in import_data
    def parse_departments(data)
      data.map do |transaction|
        {
          department_id: transaction[:department_id]
        } unless transaction[:department_id].blank?
      end.compact.uniq
    end

    # FIXME: 1 empty product gets created in import_data
    def parse_products(data)
      data.map do |transaction|
        {
          product_id: transaction[:product_id]
        } unless transaction[:product_id].blank?
      end.compact.uniq
    end

    def parse_transaction_line(line, journal, trans)
      {
        record_id: line[:record_id],
        journal_id: journal[:journal_id],
        account_id: line[:account_id],
        relation_id: line[:cust_sup_id],
        product_id: line[:product_desc] == '0' ? nil : line[:product_desc],
        project_id: line[:project_desc] == '0' ? nil : line[:project_desc],
        department_id: line[:cost_desc] == '0' ? nil : line[:cost_desc],
        transaction_id: trans[:transaction_id],
        description: line[:description],
        effective_date: parse_date(line[:effective_date].to_s),
        transaction_date: parse_date(trans[:transaction_date].to_s),
        debit_amount: parse_amount(line[:debit_amount] || '0'),
        credit_amount: parse_amount(line[:credit_amount] || '0'),
        period: parse_period(line[:period], parse_date(trans[:transaction_date].to_s)),
        year: @header[:fiscal_year]
      }
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
