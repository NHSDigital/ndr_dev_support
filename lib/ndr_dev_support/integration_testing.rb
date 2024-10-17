# Set up basic capybara:
require 'capybara/rails'
ActionDispatch::IntegrationTest.include(Capybara::DSL)

# Set up basic screenshotting capability:
#
# TODO: Once Rails 5.1 is the minimum version we support, we should be able to
#       use the built-in behaviour that Rails adds to after_teardown.
#
require 'capybara-screenshot'
if defined?(Minitest)
  require 'capybara-screenshot/minitest'
  ActionDispatch::IntegrationTest.include(Capybara::Screenshot::MiniTestPlugin)
else
  require 'capybara-screenshot/testunit'
end

# Include our custom DSL extensions, that also cover screenshotting:
require 'ndr_dev_support/integration_testing/dsl'

# Include support for retrying tests that sporadically fail:
require 'ndr_dev_support/integration_testing/flakey_tests'

# These are all the drivers we have capybara / screenshot support for:
require 'ndr_dev_support/integration_testing/drivers/chrome'
require 'ndr_dev_support/integration_testing/drivers/chrome_headless'
require 'ndr_dev_support/integration_testing/drivers/chrome_headless_old'
require 'ndr_dev_support/integration_testing/drivers/firefox'
require 'ndr_dev_support/integration_testing/drivers/switchable'

Capybara.default_driver    = :switchable
Capybara.javascript_driver = :switchable

# Inject middleware to disable jQuery fx, CSS transitions/animations
Capybara.disable_animation = true

Capybara.save_path = Rails.root.join('tmp', 'screenshots')
Capybara::Screenshot.prune_strategy = { keep: 20 }
