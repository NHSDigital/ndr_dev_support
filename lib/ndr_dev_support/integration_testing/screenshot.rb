require 'capybara-screenshot'

module NdrDevSupport
  module IntegrationTesting
    module Screenshot
      # Allow integration tests to open screenshotable popup windows.
      module DSL
        delegate :within_screenshot_compatible_window, to: :page
      end

      # Adds variant of Capybara's #within_window method, that doesn't return
      # to the preview window on an exception. This allows us to screenshot
      # a popup automatically if a test errors/fails whilst it has focus.
      module SessionExtensions
        def within_screenshot_compatible_window(window_or_proc)
          original = current_window

          case window_or_proc
          when Capybara::Window
            switch_to_window(window_or_proc) unless original == window_or_proc
          when Proc
            switch_to_window { window_or_proc.call }
          else
            fail ArgumentError, 'Unsupported window type!'
          end

          scopes << nil
          yield
          @scopes.pop
          switch_to_window(original)
        end
      end
    end
  end
end

if defined?(MiniTest)
  require 'capybara-screenshot/minitest'
  ActionDispatch::IntegrationTest.include(Capybara::Screenshot::MiniTestPlugin)
else
  require 'capybara-screenshot/testunit'
end

Capybara::Session.include(NdrDevSupport::IntegrationTesting::Screenshot::SessionExtensions)
ActionDispatch::IntegrationTest.include(NdrDevSupport::IntegrationTesting::Screenshot::DSL)

# Save screenshots to tmp/capybara/... on integration test error/failure:
Capybara::Screenshot.register_driver(:poltergeist) do |driver, path|
  # Take full-height screenshots, rather than just capturing the viewport:
  driver.render(path, full: true)
end
