require 'show_me_the_cookies'

module NdrDevSupport
  module IntegrationTesting
    module Drivers
      # A meta-driver that allows the driver to be set using the `INTEGRATION_DRIVER`
      # environment variable (e.g. for a CI matrix), assuming that driver has been pre-registered
      # with Capybara.
      module Switchable
        DEFAULT    = :chrome_headless
        CONFIGURED = ENV.fetch('INTEGRATION_DRIVER', DEFAULT).to_sym

        Capybara.register_driver(:switchable) do |app|
          configured_driver = Capybara.drivers[CONFIGURED]
          raise "Driver #{CONFIGURED} not found!" unless configured_driver

          configured_driver.call(app)
        end

        Capybara::Screenshot.register_driver(:switchable) do |driver, path|
          configured_screenshot_driver = Capybara::Screenshot.registered_drivers[CONFIGURED]
          raise "Screenshot driver #{CONFIGURED} not found!" unless configured_screenshot_driver

          configured_screenshot_driver.call(driver, path)
        end

        cookie_driver = ShowMeTheCookies.adapters[CONFIGURED]
        raise "Cookie driver #{CONFIGURED} not found!" unless cookie_driver

        ShowMeTheCookies.register_adapter(:switchable, cookie_driver)
      end
    end
  end
end
