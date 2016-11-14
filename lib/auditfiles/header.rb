require 'ostruct'

module Auditfiles
  class Header < OpenStruct
    def initialize(hash_values)
      super.new(hash_values)
    end
  end
end
