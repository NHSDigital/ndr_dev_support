require 'selenium-webdriver'
require 'show_me_the_cookies'

Capybara.register_driver(:chrome) do |app|
  Capybara::Selenium::Driver.new app, browser: :chrome
end

Capybara::Screenshot.register_driver(:chrome) do |driver, path|
  driver.browser.save_screenshot(path)
end

ShowMeTheCookies.register_adapter(:chrome, ShowMeTheCookies::SeleniumChrome)
