require 'selenium-webdriver'
require 'show_me_the_cookies'

Capybara.register_driver(:firefox) do |app|
  Capybara::Selenium::Driver.new app, browser: :firefox
end

Capybara::Screenshot.register_driver(:firefox) do |driver, path|
  driver.browser.save_screenshot(path)
end

ShowMeTheCookies.register_adapter(:firefox, ShowMeTheCookies::Selenium)
