require 'show_me_the_cookies'

module NdrDevSupport
  module IntegrationTesting
    module Drivers
      # A meta-driver that allows the driver to be set using the `INTEGRATION_DRIVER`
      # environment variable (e.g. for a CI matrix), assuming that driver has been pre-registered
      # with Capybara.

      # Although the aim is to move to Chrome headless, we keep poltergeist as the default
      # driver for now. For motivation behind not changing immediately, see the "Differences
      # between Poltergeist and Selenium" section of:
      #
      #   https://about.gitlab.com/2017/12/19/moving-to-headless-chrome/
      #
      module Switchable
        DEFAULT    = :poltergeist
        CONFIGURED = ENV.fetch('INTEGRATION_DRIVER', DEFAULT).to_sym

        Capybara.register_driver(:switchable) do |app|
          Capybara.drivers.fetch(CONFIGURED).call(app)
        end

        Capybara::Screenshot.register_driver(:switchable) do |driver, path|
          Capybara::Screenshot.registered_drivers.fetch(CONFIGURED).call(driver, path)
        end

        ShowMeTheCookies.register_adapter(:switchable, ShowMeTheCookies.adapters.fetch(CONFIGURED))
      end
    end
  end
end
