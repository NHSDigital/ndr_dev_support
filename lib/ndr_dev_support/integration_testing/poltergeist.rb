require 'capybara/poltergeist'

module NdrDevSupport
  module IntegrationTesting
    module Poltergeist
      # Additional testing DSL, for phantomjs-specific interactions.
      module DSL
        # Instruct phantomjs to clear its session:
        def clear_headless_session!
          page.driver.reset!
        end

        # Get phantomjs to delete all of the cookies
        # for the current page without resetting:
        def delete_all_cookies!
          page.driver.cookies.each do |name, value|
            page.driver.remove_cookie(name)
          end
        end
      end
    end
  end
end

ActionDispatch::IntegrationTest.include(NdrDevSupport::IntegrationTesting::Poltergeist::DSL)

# Register poltergeist as an available driver for capybara to use:
Capybara.register_driver :poltergeist do |app|
  options = { phantomjs_options: ['--proxy-type=none'], timeout: 60 }

  # If Ruby warn level is high, switch on additional output.
  options.merge!(debug: true, inspector: true) if $VERBOSE

  Capybara::Poltergeist::Driver.new(app, options)
end

# ...and make it the default:
Capybara.default_driver    = :poltergeist
Capybara.javascript_driver = :poltergeist
