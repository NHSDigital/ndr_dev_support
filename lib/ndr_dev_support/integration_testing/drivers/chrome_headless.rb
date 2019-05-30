require 'selenium-webdriver'

Capybara.register_driver(:chrome_headless) do |app|
  capabilities = Selenium::WebDriver::Remote::Capabilities.chrome(
    chromeOptions: {
      args: %w[
        headless disable-gpu no-sandbox
        --window-size=1920,1080
        --enable-features=NetworkService,NetworkServiceInProcess
      ]
    }
  )

  Capybara::Selenium::Driver.new(
    app,
    browser: :chrome,
    desired_capabilities: capabilities
  )
end

Capybara::Screenshot.register_driver(:chrome_headless) do |driver, path|
  driver.browser.save_screenshot(path)
end
