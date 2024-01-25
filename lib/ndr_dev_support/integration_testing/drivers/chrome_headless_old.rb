require 'selenium-webdriver'
require 'show_me_the_cookies'

# Use the old chrome headless driver
Capybara.register_driver :chrome_headless_old do |app|
  Capybara::Selenium::Driver.load_selenium
  browser_options = Selenium::WebDriver::Chrome::Options.new.tap do |opts|
    opts.args << '--headless'
    opts.args << '--disable-gpu' if Gem.win_platform?
    opts.args << '--no-sandbox'
    # Workaround https://bugs.chromium.org/p/chromedriver/issues/detail?id=2650&q=load&sort=-id&colspec=ID%20Status%20Pri%20Owner%20Summary
    opts.args << '--disable-site-isolation-trials'
    opts.args << '--window-size=1920,1080'
    opts.args << '--enable-features=NetworkService,NetworkServiceInProcess'
  end
  # Hide messages such as the following:
  # WARN Selenium [:logger_info] Details on how to use and modify Selenium logger:
  #   https://selenium.dev/documentation/webdriver/troubleshooting/logging#ruby
  Selenium::WebDriver.logger.ignore([:logger_info])

  Capybara::Selenium::Driver.new(app, browser: :chrome, options: browser_options)
end

Capybara::Screenshot.register_driver(:chrome_headless_old) do |driver, path|
  driver.browser.save_screenshot(path)
end

ShowMeTheCookies.register_adapter(:chrome_headless_old, ShowMeTheCookies::SeleniumChrome)
