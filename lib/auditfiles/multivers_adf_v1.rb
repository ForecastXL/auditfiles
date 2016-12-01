module Auditfiles
  # Multivers allows for duplicate relation codes for Creditors and Debtors.
  # So we append the relation_type to the relation_code.
  class MultiversAdfV1 < AdfV1
    def extract_relation(parsed_line)
      {
        relation_id: "#{parsed_line[:relation_id]}#{parsed_line[:relation_type]}",
        relation_name: parsed_line[:relation_name],
        relation_type: parsed_line[:relation_type]
      }
    end

    def extract_transaction(parsed_line)
      {
        record_id: parsed_line[:record_id],
        journal_id: parsed_line[:journal_id],
        account_id: parsed_line[:account_id],
        relation_id: "#{parsed_line[:relation_id]}#{parsed_line[:relation_type]}",
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
      }
    end
  end
end
