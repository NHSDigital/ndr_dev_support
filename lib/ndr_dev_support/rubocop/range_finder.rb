require 'English'
require 'open3'
require 'rubocop'
require 'shellwords'

module NdrDevSupport
  module Rubocop
    # Produces diffs, and parses from them the file/hunk boundaries
    class RangeFinder
      class << self
        # Use RuboCop to produce a list of all files that should be scanned.
        def target_files
          @target_files ||= begin
            defaults = ::RuboCop::ConfigStore.new
            ::RuboCop::TargetFinder.new(defaults, {}).target_files_in_dir
          end
        end
      end

      def diff_files(files)
        file_change_locations_from git_diff(files * ' ')
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
        diff_cmd = 'git diff --no-prefix --unified=0 '
        diff_cmd << Shellwords.escape(args) unless args.empty?
        stdout, stderr, status = Open3.capture3(diff_cmd)

        return stdout if status.success?

        fail Rainbow(<<-MSG).red
Failed to generate diff from:
  #{diff_cmd}

#{stderr}
        MSG
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

        ruby_files_from changes
      end

      # Don't report on changes in files that RuboCop won't understand:
      def ruby_files_from(changes)
        whitelist = RangeFinder.target_files
        changes.reject { |file, _ranges| !whitelist.include? File.join(Dir.pwd, file) }
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
