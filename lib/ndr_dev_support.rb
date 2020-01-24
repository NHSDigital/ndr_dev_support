require 'ndr_dev_support/rubocop/inject'
require 'ndr_dev_support/version'

module NdrDevSupport
  # Bootstrap our RuboCop config in to any project
  # when ndr_dev_support is required in .rubocop.yml.
  Rubocop::Inject.defaults!
end
