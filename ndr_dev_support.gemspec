lib = File.expand_path('lib', __dir__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'ndr_dev_support/version'

Gem::Specification.new do |spec|
  spec.name          = 'ndr_dev_support'
  spec.version       = NdrDevSupport::VERSION
  spec.authors       = ['NCRS Development Team']
  spec.email         = []
  spec.summary       = 'NDR Developer Support library'
  spec.description   = 'Provides support to developers of NDR projects'
  spec.homepage      = 'https://github.com/NHSDigital/ndr_dev_support'
  spec.license       = 'MIT'

  gem_files          = %w[CHANGELOG.md CODE_OF_CONDUCT.md LICENSE.txt README.md
                          config lib ndr_dev_support.gemspec]
  spec.files         = `git ls-files -z`.split("\x0").
                       select { |f| gem_files.include?(f.split('/')[0]) }
  spec.bindir        = 'exe'
  spec.executables   = spec.files.grep(%r{^exe/}) { |f| File.basename(f) }
  spec.require_paths = ['lib']

  spec.required_ruby_version = '>= 3.0'

  spec.add_dependency 'pry'

  # Audit dependencies:
  spec.add_dependency 'highline', '>= 1.6.0'

  # Rubocop dependencies:
  spec.add_dependency 'parser'
  spec.add_dependency 'rainbow'
  spec.add_dependency 'rubocop', '~> 1.7'
  spec.add_dependency 'rubocop-rails', '~> 2.9'
  spec.add_dependency 'rubocop-rake', '~> 0.5'
  spec.add_dependency 'unicode-display_width', '>= 1.3.3'

  # Integration test dependencies:
  spec.add_dependency 'capybara', '>= 3.34'
  spec.add_dependency 'capybara-screenshot'
  spec.add_dependency 'minitest', '~> 5.11'
  spec.add_dependency 'selenium-webdriver', '~> 4.8'
  spec.add_dependency 'show_me_the_cookies'

  # CI server dependencies:
  spec.add_dependency 'activesupport', '>= 6.1', '< 7.1'
  spec.add_dependency 'brakeman', '>= 4.7.1'
  spec.add_dependency 'bundler-audit'
  spec.add_dependency 'github-linguist'
  spec.add_dependency 'prometheus-client', '~> 4.0.0'
  spec.add_dependency 'rugged'
  spec.add_dependency 'simplecov'
  spec.add_dependency 'with_clean_rbenv'

  # Deployment dependencies:
  spec.add_dependency 'capistrano', '~> 2.15'
  spec.add_dependency 'net-scp', '>= 2.0.0'

  spec.add_development_dependency 'bundler'
  spec.add_development_dependency 'mocha'
  spec.add_development_dependency 'rake', '>= 12.3.3'
end
