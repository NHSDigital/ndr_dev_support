# Set up basic capybara:
require 'capybara/rails'
ActionDispatch::IntegrationTest.include(Capybara::DSL)

# Set up basic screenshotting capability:
require 'capybara-screenshot'
if defined?(MiniTest)
  require 'capybara-screenshot/minitest'
  ActionDispatch::IntegrationTest.include(Capybara::Screenshot::MiniTestPlugin)
else
  require 'capybara-screenshot/testunit'
end

# Include our custom DSL extensions, that also cover screenshotting:
require 'ndr_dev_support/integration_testing/dsl'

# These are all the drivers we have capybara / screenshot support for:
require 'ndr_dev_support/integration_testing/drivers/chrome'
require 'ndr_dev_support/integration_testing/drivers/chrome_headless'
require 'ndr_dev_support/integration_testing/drivers/firefox'
require 'ndr_dev_support/integration_testing/drivers/poltergeist'

# Keep poltergeist as the default driver for now. For motivation behind not changing
# immediately, see the "Differences between Poltergeist and Selenium" section of:
#
#   https://about.gitlab.com/2017/12/19/moving-to-headless-chrome/
#
Capybara.default_driver    = :poltergeist
Capybara.javascript_driver = :poltergeist
