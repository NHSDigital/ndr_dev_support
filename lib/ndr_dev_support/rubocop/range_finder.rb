require 'english'

module NdrDevSupport
  module Rubocop
    # Produces diffs, and parses from them the file/hunk boundaries
    class RangeFinder
      def diff_files(files)
        diff = Array(files).map { |file| git_diff(%(-- "#{file}")) }.join
        file_change_locations_from diff
      end

      def diff_head
        file_change_locations_from git_diff('HEAD')
      end

      def diff_staged
        file_change_locations_from git_diff('--staged')
      end

      def diff_unstaged
        file_change_locations_from git_diff('')
      end

      def diff_expr(expr)
        file_change_locations_from git_diff(expr)
      end

      private

      def git_diff(args)
        diff = `git diff --no-prefix --unified=0 #{args}`
        fail "Failed to diff: '#{args}'" unless $CHILD_STATUS.exitstatus.zero?
        diff
      end

      def file_changes_hash
        Hash.new { |hash, file| hash[file] = [] }
      end

      def file_change_locations_from(diff, changes = file_changes_hash)
        current_file = nil
        diff.each_line do |line|
          if line.start_with?('+++')
            current_file = line[4..-1].strip
          elsif line.start_with?('@@')
            range = hunk_range_from(line)
            changes[current_file].push(range) unless range.end.zero?
          end
        end

        changes
      end

      def hunk_range_from(line)
        match_data = line.match(/\A@@ -\d+(?:,\d+)? \+(\d+)(?:,(\d+))? @@/)
        start_line = match_data[1].to_i
        new_lines  = match_data[2].to_i
        end_line   = new_lines.zero? ? start_line : start_line + new_lines - 1

        start_line..end_line
      end
    end
  end
end
