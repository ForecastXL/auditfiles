module Auditfiles
  module Xaf32
    class AfasProfit < Base
      def read
        # Pass each collected tag to the block
        products = []
        projects = []
        departments = []
        fiscal_year = false

        collector = SaxStream::Collectors::BlockCollector.new do |obj|
          obj_class = obj.class.name.split('::').last
          if obj_class == 'Header'
            fiscal_year = obj['fiscal_year']
            obj['product_version'] = '' unless obj['product_version']
            yield(obj_class, obj.attributes)
          elsif obj_class == 'Transaction'
            # Add info to transaction lines and extract other dimensions
            obj.relations['transaction_lines'].each do |line|
              # Stupid AFAS
              line['effective_date'] = obj['transaction_date'] if obj['period'] == '0'

              line['period'] = obj['period']
              line['debit_amount'] = line['amount_type'].casecmp('D').zero? ? line['amount'] : 0
              line['credit_amount'] = line['amount_type'].casecmp('C').zero? ? line['amount'] : 0
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
                                                   Transaction, TransactionLine])

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
