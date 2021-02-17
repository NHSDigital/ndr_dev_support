require 'rainbow'

module NdrDevSupport
  module Rubocop
    # Handles the display of any rubocop output
    class Reporter
      HEADER = (('=' * 34) << ' Summary: ' << ('=' * 34)).freeze
      FOOTER = ('=' * HEADER.length).freeze

      COLOURS = {
        'refactor'   => :yellow,
        'convention' => :yellow,
        'warning'    => :magenta,
        'error'      => :red,
        'fatal'      => :red
      }.freeze

      def initialize(offenses)
        @offenses = Hash[offenses.sort_by { |file, _offenses| file }]
      end

      # Prints out a report, and returns an appriopriate
      # exit status for the rake task to terminate with.
      def report
        if @offenses.none?
          puts Rainbow('No relevant changes found.').yellow
          return true
        end

        print_summary
        puts
        print_offenses

        @offenses.values.all?(&:empty?)
      end

      private

      def colour_severity(severity, initial_only = false)
        colour  = COLOURS[severity]
        message = initial_only ? severity[0, 1].upcase : severity
        colour ? Rainbow(message).color(colour) : message
      end

      def print_summary
        puts HEADER
        @offenses.each do |filename, file_offenses|
          puts format(' * %s has %d relevant offence%s.',
                      Rainbow(filename).fg(file_offenses.empty? ? :green : :red),
                      file_offenses.length,
                      file_offenses.one? ? '' : 's'
                     )
        end
        puts FOOTER
      end

      def print_offenses
        @offenses.each do |filename, file_offenses|
          file_offenses.each do |offense|
            puts formatted_offense(filename, offense)
          end
        end
      end

      def formatted_offense(filename, offense)
        format('%s:%d:%d: %s: %s %s',
               Rainbow(filename).cyan,
               offense['location']['line'],
               offense['location']['column'],
               colour_severity(offense['severity'], true),
               offense['message'],
               colour_severity(offense['severity'])
              )
      end
    end
  end
end
