require 'json'
require 'shellwords'

module NdrDevSupport
  module Rubocop
    # This class filters the Rubocop report of a file
    # to only the given lines.
    class Executor
      def initialize(filename, lines)
        @filename = filename
        @lines    = lines
      end

      def output
        offenses.select do |offense|
          line_number = offense['location']['line']
          1 == line_number || @lines.include?(line_number)
        end
      end

      private

      def offenses
        hash = JSON.parse(`rubocop --format json #{Shellwords.escape(@filename)}`)
        hash['files'].first['offenses']
      end
    end
  end
end
