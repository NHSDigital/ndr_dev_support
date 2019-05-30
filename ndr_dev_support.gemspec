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
  # SECURE BNS 2018-08-06: Minimise sharing of (public-key encrypted) slack secrets in .travis.yml
  spec.files         -= %w[.travis.yml] # Not needed in the gem
  spec.bindir        = 'exe'
  spec.executables   = spec.files.grep(%r{^exe/}) { |f| File.basename(f) }
  spec.require_paths = ['lib']

  spec.required_ruby_version = '>= 2.4'

  spec.add_dependency 'pry'

  # Audit dependencies:
  spec.add_dependency 'highline', '>= 1.6.0'

  # Rubocop dependencies:
  spec.add_dependency 'parser'
  spec.add_dependency 'rainbow'
  spec.add_dependency 'rubocop', '0.52.1'
  spec.add_dependency 'unicode-display_width', '>= 1.3.3'

  # Integration test dependencies:
  spec.add_dependency 'capybara'
  spec.add_dependency 'capybara-screenshot'
  spec.add_dependency 'poltergeist', '>= 1.8.0'
  spec.add_dependency 'selenium-webdriver'
  spec.add_dependency 'show_me_the_cookies'
  spec.add_dependency 'webdrivers', '>= 3.9'

  # CI server dependencies:
  spec.add_dependency 'activesupport', '< 6.1'
  spec.add_dependency 'brakeman', '>= 4.2.0'
  spec.add_dependency 'bundler-audit'
  spec.add_dependency 'github-linguist'
  spec.add_dependency 'prometheus-client', '>= 0.9.0'
  spec.add_dependency 'rugged'
  spec.add_dependency 'simplecov'
  spec.add_dependency 'with_clean_rbenv'

  # Deployment dependencies:
  spec.add_dependency 'capistrano', '~> 2.15'

  spec.add_development_dependency 'bundler'
  spec.add_development_dependency 'minitest', '~> 5.0'
  spec.add_development_dependency 'mocha'
  spec.add_development_dependency 'rake', '~> 10.0'
end
