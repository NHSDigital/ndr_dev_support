module NdrDevSupport
  module IntegrationTesting
    # Grudging handling of flakey integration tests. Allows tests to be declared
    # with `flakey_test`. Our CI reporter gathers information on flakey failures.
    module FlakeyTests
      extend ActiveSupport::Concern

      included do
        class_attribute :attempts_per_test, default: {}
      end

      class_methods do
        def flakey_test(description, attempts: 3, &block)
          test(description, &block).tap do |test_name|
            self.attempts_per_test = attempts_per_test.merge(test_name.to_s => attempts)
          end
        end

        def test_repeatedly(description, times: 100, &block)
          (1..times).map do |n|
            test("#{description} - #{n}/#{times}", &block)
          end
        end
      end

      def flakes
        @flakes ||= []
      end

      def run
        attempts_remaining = attempts_per_test[name]
        return super unless attempts_remaining

        previous_failure = failures.last
        failed_attempts = []

        loop do
          break if attempts_remaining < 1

          super

          # No failure was added; we passed!
          break if failures.last == previous_failure

          # Ran out of attempts:
          break if (attempts_remaining -= 1) < 1

          # Loop round and have another go:
          failed_attempts << failures.pop
        end

        # Attempts were only flakey if we eventually passed:
        flakes.concat(failed_attempts) if failures.last == previous_failure

        self
      end
    end
  end
end

ActionDispatch::IntegrationTest.include(NdrDevSupport::IntegrationTesting::FlakeyTests)
