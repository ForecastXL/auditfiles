# require 'stringio'
require 'ox'

class Auditfiles::Xaf
  def initialize(document_path)
    @file = IO.open(IO.sysopen(document_path)) # File.read(document_path)
  end

  class Yielder < ::Ox::Sax
    @context = []

    class << self
      attr_accessor :context
    end

    def initialize(block)
      @pos = nil
      @line = nil
      @column = nil

      @yield_to = block
    end

    def start_element(name)
      Element.add_element(name)

      @yield_to.call(name)
    end

    def text(value)
      @text = value
      Element.add_value(value)
    end

    def end_element(name)
      # Element.remove_element(name)
      Yielder.context << { name: name, text: @text }
    end
  end

  class Element
    @context = {}
    @levels = []
    @opts = { level: '' }

    class << self
      attr_accessor :context, :levels, :opts, :type, :closed, :is_parent

      def add_element(name)
        self.type = name
        self.closed = false
        levels << name
        opts[:level] = levels.join('.')
        context[opts[:level]] = nil

        self.is_parent = true
      end

      def add_value(value)
        context[opts[:level]] = value

        self.is_parent = false
      end

      def remove_element(_name)
        if is_parent
          context.reject! { |key, _value| key.starts_with?(opts[:level]) }
          self.closed = true
        end

        levels.pop
        opts[:level] = levels.join('.')

        self.is_parent = true
      end
    end
  end

  def read
    proc = proc { puts Yielder.context }
    handler = Yielder.new(proc)
    puts 'before parse'
    Ox.sax_parse(handler, @file)

    # puts Element.context
    puts 'after parse'
  end
end
