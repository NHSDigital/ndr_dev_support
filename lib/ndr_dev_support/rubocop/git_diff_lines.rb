module NdrDevSupport
  module Rubocop
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
  end
end
