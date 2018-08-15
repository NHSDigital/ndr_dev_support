require 'capybara/rails'

module NdrDevSupport
  module IntegrationTesting
    # Additional integration testing DSL:
    module DSL
      # Instruct the headless browser to clear its session:
      def clear_headless_session!
        page.driver.reset!
      end

      # Get the headless browser to delete all of the cookies
      # for the current page without resetting:
      def delete_all_cookies!
        page.driver.cookies.each_key do |name|
          page.driver.remove_cookie(name)
        end
      end

      # Wrap up interacting with modals. The assumption is that the modal
      # should be gone one the interaction is complete (as this is a good
      # proxy for a triggered AJAX request to have completed, and therefore
      # a signal for capybara to wait for); if this is not the case, pass
      # `remain: true` to signal that the modal should remain active.
      def within_modal(selector: '#modal', remain: false)
        within(selector) { yield }

        message = "modal was #{'not ' unless remain} expected to remain visible!"
        assert(remain ? has_selector?(selector) : has_no_selector?(selector), message)
      end

      def find_new(*args, **options)
        # There is no point waiting to see there are no existing matches:
        pre_options = { wait: 0 }.merge(options)
        prior_matches = find_all(*args, **pre_options)

        yield

        # We expect exactly one new match as a result of the interaction:
        post_options = { count: prior_matches.length + 1 }
        current_matches = find_all(*args, **post_options)

        additional_matches = current_matches.to_a - prior_matches.to_a
        additional_matches.first
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
            raise ArgumentError, 'Unsupported window type!'
          end

          scopes << nil
          yield
          @scopes.pop
          switch_to_window(original)
        end
      end

      Capybara::Session.include(SessionExtensions)

      delegate :within_screenshot_compatible_window, to: :page
    end
  end
end

ActionDispatch::IntegrationTest.include(NdrDevSupport::IntegrationTesting::DSL)
