# -*- encoding: utf-8 -*-
require File.expand_path('../lib/auditfiles/version', __FILE__)

Gem::Specification.new do |s|
  s.name          = 'auditfiles'
  s.version       = Auditfiles::VERSION
  s.description   = 'Read financial audit files'
  s.authors       = ['ForecastXL']
  s.email         = ['developers@forecastxl.com']
  s.summary       = 'Supported formats: ADF, XAF v1, v2, v3, v3.1, v3.2 ...'
  s.homepage      = 'https://www.forecastxl.com/'

  # s.files         = `git ls-files`.split($\)
  s.files         = Dir['{lib}/**/*.rb', 'bin/*', 'LICENSE', '*.md']
  s.executables   = s.files.grep(%r{^bin/}).map { |f| File.basename(f) }
  s.test_files    = s.files.grep(%r{^(test|spec|features)/})
  s.require_paths = ['lib']

  s.add_runtime_dependency 'activesupport'
  s.add_runtime_dependency 'nokogiri'
  s.add_runtime_dependency 'nori'
  s.add_runtime_dependency 'sax_stream'
  s.add_runtime_dependency 'ox'
end
