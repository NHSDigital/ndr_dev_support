require 'test_helper'
require 'ndr_dev_support/integration_testing/flakey_tests'

module IntegrationTesting
  # Smoke test our minitest integration. This does not cover all functionality.
  class FlakeyTestsTest < ActiveSupport::TestCase
    include NdrDevSupport::IntegrationTesting::FlakeyTests

    test 'should register flakey tests' do
      refute attempts_per_test.key?(name), 'a non-flakey test should not be registered'
      assert_equal 3, attempts_per_test.fetch('test_might_be_a_bit_flakey')
      assert_equal 10, attempts_per_test.fetch('test_might_be_very_flakey')
    end

    test 'should not be flakey' do
      assert true, 'we just need this to pass...'
    end

    flakey_test 'might be a bit flakey' do
      assert true, 'we just need this to pass...'
    end

    flakey_test 'might be very flakey', attempts: 10 do
      assert true, 'we just need this to pass...'
    end
  end
end
