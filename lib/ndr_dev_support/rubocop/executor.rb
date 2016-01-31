require 'json'

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
          @lines.include? offense['location']['line']
        end
      end

      private

      def offenses
        hash = JSON.parse(`rubocop --format json #{@filename}`)
        hash['files'].first['offenses']
      end
    end
  end
end
