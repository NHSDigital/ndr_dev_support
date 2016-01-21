require 'json'
require 'yaml'
require 'rainbow'
require 'ndr_dev_support/rubocop/git_diff_lines'
require 'ndr_dev_support/rubocop/diff_related_lines'

module NdrDevSupport
  module Rubocop
    # This class filters the Rubocop report to lines related to altered lines.
    class Diff
      COLOURS = {
        'refactor'   => :yellow,
        'convention' => :yellow,
        'warning'    => :magenta,
        'error'      => :red,
        'fatal'      => :red
      }

      attr_accessor :filename, :line_numbers

      def initialize(filename)
        @filename = filename

        altered_lines = GitDiffLines.new(filename).diff_head.altered_lines
        diff_related_lines = DiffRelatedLines.new(filename, altered_lines).parse
        @line_numbers = diff_related_lines.output_lines + altered_lines
      end

      def report
        related_offenses.each { |offense| puts offense_message(offense) }.empty?
      end

      private

      def offense_message(offense)
        format('%s:%d:%d: %s: %s %s',
               Rainbow(filename).cyan,
               offense['location']['line'],
               offense['location']['column'],
               colour_severity(offense['severity'], initial_only: true),
               offense['message'],
               colour_severity(offense['severity'])
              )
      end

      def colour_severity(severity, initial_only: false)
        colour  = COLOURS[severity]
        message = initial_only ? severity[0, 1].upcase : severity
        colour ? Rainbow(message).color(colour) : message
      end

      def related_offenses
        return all_offenses if line_numbers.empty?

        all_offenses.select { |offense| line_numbers.include?(offense['location']['line']) }
      end

      def all_offenses
        return @all_offenses unless @all_offenses.nil?

        hash = JSON.parse(`rubocop --format json #{filename}`)
        @all_offenses = hash['files'].first['offenses']
      end
    end
  end
end
