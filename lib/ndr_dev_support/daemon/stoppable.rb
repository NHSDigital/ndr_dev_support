require 'active_support/all'
require 'active_support/core_ext/numeric/bytes'

module NdrDevSupport
  module Daemon
    # Behaviour that allows daemons to be restarted, and stopped by god.
    # To use, you need to call `super` in the initialize method, if defined.
    module Stoppable
      extend ActiveSupport::Concern

      # touch this file to trigger graceful exit
      RESTART_FILENAME =
        defined?(Rails) ? Rails.root.join('tmp', 'restart.txt') : 'restart.txt'

      MAX_MEMORY = 3.gigabytes # restart between jobs if memory consumption exceeds this
      MAX_UPTIME = 2.hours     # restart between jobs if have been up this long

      # how long the daemon waits when it runs out of things to do:
      BIG_SLEEP = 1.minute

      # when idle, how long the daemon between making restart checks?
      LITTLE_SLEEP = 5.seconds

      included do
        attr_reader :name, :start_time
        attr_writer :logger
      end

      def initialize(*)
        setup_signals

        @start_time = Time.current
      end

      def stop
        @should_stop = true
      end

      def should_stop?
        @should_stop ||= restart_file_touched? || excessive_memory? || been_up_a_while?
      end

      def run(exit_when_done: false)
        loop do
          run_once

          # we've done all we can for the time being; either exit now, or
          # have a sleep and loop round for another go:
          break if exit_when_done
          snooze(BIG_SLEEP)
          # Our snooze may have come to an abrupt end:
          break if should_stop?
        end

        if should_stop?
          # An instruction to stop has been received:
          log('Stopping')
          return :stopped
        else
          # Processing has come to a natural end:
          log('Done, exiting')
          return :exiting
        end
      end

      def logger
        @logger ||= defined?(Rails) && Rails.logger ? Rails.logger : Logger.new($stdout)
      end

      def log(message, level = :info)
        tags    = "[#{Time.current.to_s(:db)}] [#{level.upcase}] [daemon: #{name} (#{Process.pid})]"
        message = "#{tags} #{message}"

        logger.send(level, message)
      end

      private

      def setup_signals
        Signal.trap('TERM') { stop }
      end

      def restart_file_touched?
        File.exist?(RESTART_FILENAME) && File.mtime(RESTART_FILENAME) > start_time
      end

      def excessive_memory?
        (`ps -o rss= -p #{$$}`.to_i.kilobytes) > MAX_MEMORY
      rescue
        false
      end

      def been_up_a_while?
        start_time < MAX_UPTIME.ago
      end

      # sleeps for `duration`, but wakes up periodically to
      # see if the daemon has been asked to restart. If so,
      # returns immediately.
      def snooze(duration)
        number_of_mini_sleeps = duration / LITTLE_SLEEP
        initial_sleep_length  = duration % LITTLE_SLEEP

        sleep(initial_sleep_length)

        number_of_mini_sleeps.times do
          return if should_stop?

          sleep(LITTLE_SLEEP)
        rescue Interrupt
          # Ctrl-C should stop cleanly if used while the process is snoozing
          @should_stop = true
          return
        end
      end
    end
  end
end
