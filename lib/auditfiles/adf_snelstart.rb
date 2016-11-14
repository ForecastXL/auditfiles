# Fixes for Auditfiles from Snelstart.
module Auditfiles
  class AdfSnelstart < Adf

    # Transactions that are not associated to a relation do not leave their relation_id blank but
    # fill the empty space with '0's. When a relation_id is found where all chars are '0' then it
    # assumed not be a valid relation_id and it is subsistuded for an empty string.
    def parse_line(line)
      relation_id = line[345...360].strip

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
        relation_id: (relation_id.count('0') == relation_id.size ? '' : relation_id),
        relation_type: line[360...365].strip,
        relation_tax_registration_nr: line[365...381].strip,
        relation_name: line[381...411].strip,
        relation_address: line[411...441].strip,
        relation_postal_code: line[441...451].strip,
        relation_city: line[451...481].strip,
        relation_country: line[481...496].strip
      }
    end
  end
end
