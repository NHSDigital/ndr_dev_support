# The driver for PhantomJS is poltergeist:
require 'capybara/poltergeist'
require 'show_me_the_cookies'

Capybara.register_driver(:poltergeist) do |app|
  options = { phantomjs_options: ['--proxy-type=none'], timeout: 60 }

  options.merge!(debug: true, inspector: true) if ENV['DEBUG_PHANTOM_JS']

  Capybara::Poltergeist::Driver.new(app, options)
end

Capybara::Screenshot.register_driver(:poltergeist) do |driver, path|
  # Take full-height screenshots, rather than just capturing the viewport:
  driver.render(path, full: true)
end

ShowMeTheCookies.register_adapter(:poltergeist, ShowMeTheCookies::Poltergeist)
