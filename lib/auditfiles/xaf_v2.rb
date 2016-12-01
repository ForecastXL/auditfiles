module Auditfiles
  class XafV2 < Importer
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
      parser = SaxStream::Parser.new(collector, [
                                       self.class::Auditfile,
                                       self.class::Header, self.class::Relation, self.class::Ledger,
                                       self.class::Transaction, self.class::TransactionLine
                                     ])

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
