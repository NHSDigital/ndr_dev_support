# A meta-driver that allows the driver to be set using the `INTEGRATION_DRIVER`
# environment variable (e.g. for a CI matrix), assuming that driver has been pre-registered
# with Capybara.

# Although the aim is to move to Chrome headless, we keep poltergeist as the default
# driver for now. For motivation behind not changing immediately, see the "Differences
# between Poltergeist and Selenium" section of:
#
#   https://about.gitlab.com/2017/12/19/moving-to-headless-chrome/
#
Capybara.register_driver(:switchable) do |app|
  choice = ENV.fetch('INTEGRATION_DRIVER', 'poltergeist').to_sym

  Capybara.drivers.fetch(choice).call(app)
end

Capybara::Screenshot.register_driver(:switchable) do |driver, path|
  choice = ENV.fetch('INTEGRATION_DRIVER', 'poltergeist').to_sym

  Capybara::Screenshot.registered_drivers.fetch(choice).call(driver, path)
end
