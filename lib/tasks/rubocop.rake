namespace :rubocop do
  # Usage: bin/rake rubocop:diff <paths>
  task :diff do
    # Given a ruby filepath and array of line numbers, this class returns related line numbers
    # i.e. the (range of) line numbers of the related method and the first line number
    # of the related class/module definition. This enables us to filter rubocop output where
    # there is a lot of code that was implemented prior to the use of rubocop inforced coding
    # standards and our changes are lost within the noise (and where wholesale fixes could
    # produce undesired regressions).
    class DiffRelatedLines
      require 'parser/current'

      attr_accessor :filename, :input_lines, :output_line_ranges

      def initialize(filename, input_lines)
        @filename = filename
        @input_lines = input_lines
        @output_line_ranges = []
      end

      def parse
        file_contents = IO.readlines(filename).join('')
        node = Parser::CurrentRuby.parse(file_contents)

        parse_node(node)

        self
      end

      def output_lines
        @output_line_ranges.map { |line| line.is_a?(Range) ? line.to_a : line }.flatten.uniq
      end

      private

      def node_start_and_end_line(expression)
        start_line = expression.line
        end_line, _column = expression.source_buffer.decompose_position(expression.end_pos)

        [start_line, end_line]
      end

      def add_to_output_if_related(node)
        start_line, end_line = node_start_and_end_line(node.location.expression)
        return if ((start_line..end_line).to_a & @input_lines).empty?
        # return unless [:module, :class, :def, :defs].include?(node.type)

        if [:def, :defs].include?(node.type)
          # add all the lines of the affected method
          @output_line_ranges << (start_line..end_line)
        elsif [:module, :class].include?(node.type)
          # :module or :class, so add all the first line of the affected module/class
          @output_line_ranges << start_line
          # else
          # puts [start_line..end_line, node.type].inspect
        end
      end

      # recursively parses nodes to see if they are related to the specified input lines.
      def parse_node(node)
        return unless node.is_a?(Parser::AST::Node)
        return if node.location.nil? || node.location.expression.nil?

        add_to_output_if_related(node)

        node.children.each do |child_node|
          parse_node(child_node)
        end
      end
    end

    # This class interprets a git diff output for a given file and returns the altered line numbers
    class GitDiffLines
      attr_accessor :filename, :altered_lines

      def initialize(filename)
        @filename = filename
        @altered_lines = []
      end

      def diff_head
        hunk_lines.each do |line|
          @altered_lines << hunk_line_number_range(line).to_a
        end
        @altered_lines.flatten!
        @altered_lines.uniq!

        self
      end

      private

      def hunk_lines
        output = `git diff --unified=0 HEAD -- "#{filename}"`
        output = output.split("\n").select { |line| line =~ /\A@@/ }

        output
      end

      def hunk_line_number_range(line)
        matchdata = line.match(/\A@@ -\d+(?:,\d+)? \+(\d+)(?:,(\d+))? @@/)
        fail "something is not working #{line.inspect}" if matchdata[1].nil?

        start_line = matchdata[1].to_i
        new_lines = matchdata[2].to_i
        end_line = 0 == new_lines ? start_line : start_line + new_lines - 1

        start_line..end_line
      end
    end

    # This class filters the Rubocop report to lines related to altered lines.
    class RubocopDiff
      require 'json'
      require 'yaml'
      require 'rainbow'

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

    ARGV[1..-1].each do |path|
      exit(false) unless RubocopDiff.new(path).report
    end
  end
end
