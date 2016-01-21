module NdrDevSupport
  module Rubocop
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
  end
end
