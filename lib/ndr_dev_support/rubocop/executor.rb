require 'json'
require 'open3'
require 'shellwords'

module NdrDevSupport
  module Rubocop
    # This class filters the Rubocop report of a file
    # to only the given lines.
    class Executor
      class << self
        # Use RuboCop to produce a list of all files that should be scanned.
        def target_files
          @target_files ||= `rubocop -L`.each_line.map(&:strip)
        end
      end

      def initialize(filenames)
        @filenames = Executor.target_files & filenames

        check_ruby_syntax
      end

      def offenses_by_file
        return [] if @filenames.empty?

        output = JSON.parse(`rubocop --format json #{escaped_paths.join(' ')}`)

        output['files'].each_with_object({}) do |file_output, result|
          result[file_output['path']] = file_output['offenses']
        end
      end

      private

      def escaped_paths
        @escaped_paths ||= @filenames.map { |path| Shellwords.escape(path) }
      end

      def check_ruby_syntax
        escaped_paths.each do |path|
          stdout_and_err_str, status = Open3.capture2e("ruby -c #{path}")
          next if status.exitstatus.zero?

          raise stdout_and_err_str
        end
      end
    end
  end
end
