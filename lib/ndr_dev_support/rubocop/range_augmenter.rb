module NdrDevSupport
  module Rubocop
    # For a given file, and set of line ranges, computes a list of
    # all lines covered, expanding the ranges to include full method
    # defintions, and class/module headers.
    class RangeAugmenter
      MODULE_TYPES = [:module, :class].freeze
      METHOD_TYPES = [:def, :defs].freeze

      attr_reader :filename

      class << self
        def augmented_lines_for(file_ranges)
          output = {}
          file_ranges.each do |file, ranges|
            output[file] = new(file, ranges).lines
          end
          output
        end
      end

      def initialize(filename, ranges)
        @filename = filename
        @lines    = ranges.map(&:to_a).flatten
      end

      def augmented_lines
        require 'parser/current'
        root  = Parser::CurrentRuby.parse IO.read(filename)
        nodes = extract_augmenting_nodes(root)

        lines_covering(@lines, nodes)
      end

      private

      def range_for(node)
        expression = node.location.expression
        start_line = expression.line
        end_line, _column = expression.source_buffer.decompose_position(expression.end_pos)

        start_line..end_line
      end

      def lines_covering(lines, nodes)
        nodes.each do |node|
          range = range_for(node)
          next unless lines.detect { |line| range.cover?(line) }

          if method?(node)
            lines.concat(range.to_a)
          elsif module?(node)
            lines.push(range.begin)
          end
        end
        lines.uniq.sort
      end

      def extract_augmenting_nodes(parent, result = [])
        return result if dead_end?(parent)
        result.push(parent) if method?(parent) || module?(parent)
        parent.children.each { |node| extract_augmenting_nodes(node, result) }
        result
      end

      def module?(node)
        MODULE_TYPES.include? node.type
      end

      def method?(node)
        METHOD_TYPES.include? node.type
      end

      def dead_end?(node)
        return true unless node.is_a?(Parser::AST::Node)
        location = node.location
        !(location && location.expression)
      end
    end
  end
end
