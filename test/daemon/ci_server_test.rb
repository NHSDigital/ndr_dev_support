require 'test_helper'
require 'ndr_dev_support/daemon/ci_server'

module Daemon
  # Test daemon CI server functionality
  class CiServerTest < Minitest::Test
    def setup
      @worker = NdrDevSupport::Daemon::CIServer.new(name: 'test worker')
    end

    def test_should_parse_arguments
      args   = { 'WORKER_NAME' => 'test' }
      worker = NdrDevSupport::Daemon::CIServer.from_args(args)

      assert_equal 'test', worker.name
    end

    def test_should_sense_check_arguments
      exception = assert_raises(ArgumentError) do
        NdrDevSupport::Daemon::CIServer.new(name: '')
      end
      assert_match(/no worker_name specified!/i, exception.message)
    end

    def test_should_be_stoppable
      refute @worker.should_stop?
      @worker.stop
      assert @worker.should_stop?
    end

    def test_should_be_stoppable_by_sending_a_term_signal
      refute @worker.should_stop?
      Process.kill('TERM', Process.pid)
      assert @worker.should_stop?
    end

    def test_should_be_stoppable_by_touching_file
      @worker.stubs(restart_file_touched?: false)
      refute @worker.should_stop?

      @worker.stubs(restart_file_touched?: true)
      assert @worker.should_stop?
    end
  end
end
