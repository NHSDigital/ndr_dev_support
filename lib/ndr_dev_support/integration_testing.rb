# Set up basic capybara:
require 'capybara/rails'
ActionDispatch::IntegrationTest.include(Capybara::DSL)

# Set up basic screenshotting capability:
#
# TODO: Once Rails 5.1 is the minimum version we support, we should be able to
#       use the built-in behaviour that Rails adds to after_teardown.
#
require 'capybara-screenshot'
if defined?(MiniTest)
  require 'capybara-screenshot/minitest'
  ActionDispatch::IntegrationTest.include(Capybara::Screenshot::MiniTestPlugin)
else
  require 'capybara-screenshot/testunit'
end

# Include our custom DSL extensions, that also cover screenshotting:
require 'ndr_dev_support/integration_testing/dsl'

# Keeps the selenium webdrivers automatically updated:
require 'webdrivers'
Webdrivers.cache_time = 24.hours

# These are all the drivers we have capybara / screenshot support for:
require 'ndr_dev_support/integration_testing/drivers/chrome'
require 'ndr_dev_support/integration_testing/drivers/chrome_headless'
require 'ndr_dev_support/integration_testing/drivers/firefox'
require 'ndr_dev_support/integration_testing/drivers/poltergeist'
require 'ndr_dev_support/integration_testing/drivers/switchable'

Capybara.default_driver    = :switchable
Capybara.javascript_driver = :switchable

Capybara.save_path = Rails.root.join('tmp', 'screenshots')
Capybara::Screenshot.prune_strategy = { keep: 20 }
