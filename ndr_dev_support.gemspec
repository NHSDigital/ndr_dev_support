# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'ndr_dev_support/version'

Gem::Specification.new do |spec|
  spec.name          = 'ndr_dev_support'
  spec.version       = NdrDevSupport::VERSION
  spec.authors       = ['NCRS Development Team']
  spec.email         = []
  spec.summary       = 'NDR Developer Support library'
  spec.description   = 'Provides support to developers of NDR projects'
  spec.homepage      = 'https://github.com/PublicHealthEngland/ndr_dev_support'
  spec.license       = 'MIT'

  spec.files         = `git ls-files -z`.split("\x0").reject { |f| f.match(%r{^(test|spec|features)/}) }
  spec.bindir        = 'exe'
  spec.executables   = spec.files.grep(%r{^exe/}) { |f| File.basename(f) }
  spec.require_paths = ['lib']

  spec.required_ruby_version = '>= 2.2'

  # Rubocop dependencies:
  spec.add_dependency 'rubocop', '0.44.1'
  spec.add_dependency 'parser'
  spec.add_dependency 'rainbow'

  # Integration test dependencies:
  spec.add_dependency 'capybara'
  spec.add_dependency 'capybara-screenshot'
  spec.add_dependency 'poltergeist', '>= 1.8.0'

  spec.add_development_dependency 'bundler', '~> 1.7'
  spec.add_development_dependency 'rake', '~> 10.0'
  spec.add_development_dependency 'pry'
  spec.add_development_dependency "minitest", "~> 5.0"
end
