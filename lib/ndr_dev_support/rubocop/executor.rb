require 'json'
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
      end

      def offenses_by_file
        return [] if @filenames.empty?

        escaped_paths = @filenames.map { |path| Shellwords.escape(path) }
        output = JSON.parse(`rubocop --format json #{escaped_paths.join(' ')}`)

        output['files'].each_with_object({}) do |file_output, result|
          result[file_output['path']] = file_output['offenses']
        end
      end
    end
  end
end
