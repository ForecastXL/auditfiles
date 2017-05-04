require 'active_support/all'

# Require the SaxStream classes
require 'sax_stream/mapper'
require 'sax_stream/parser'
require 'sax_stream/collectors/block_collector'
require 'sax_stream/collectors/naive_collector'

# Require the base files
require 'auditfiles/version'
require 'auditfiles/importer_factory'
require 'auditfiles/generic_header'
require 'auditfiles/importer'
require 'auditfiles/xaf'
require 'auditfiles/xaf_v2'
require 'auditfiles/adf'
require 'auditfiles/default_xaf_v2'
require 'auditfiles/adf_v1'
require 'auditfiles/xaf32/base'

# Require all software specific files
Dir["#{File.dirname(__FILE__)}/auditfiles/**/*.rb"].each { |file| require file }
