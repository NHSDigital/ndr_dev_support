require 'selenium-webdriver'

Capybara.register_driver(:firefox) do |app|
  Capybara::Selenium::Driver.new app, browser: :firefox
end

Capybara::Screenshot.register_driver(:firefox) do |driver, path|
  driver.browser.render_screenshot(path)
end
