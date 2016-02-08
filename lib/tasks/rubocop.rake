namespace :rubocop do
  require 'ndr_dev_support/rubocop/range_finder'
  require 'ndr_dev_support/rubocop/range_augmenter'
  require 'ndr_dev_support/rubocop/executor'
  require 'ndr_dev_support/rubocop/reporter'

  # For a given set of change locations (extract from a diff),
  # run rubocop on the relevant files, and report filtered results.
  def rubocop_file_ranges(file_ranges)
    output  = {}
    threads = file_ranges.map do |file, ranges|
      Thread.new do
        # Expand ranges to include entire methods, etc:
        lines = NdrDevSupport::Rubocop::RangeAugmenter.new(file, ranges).augmented_lines
        # Get rubocop output for those files:
        output[file] = NdrDevSupport::Rubocop::Executor.new(file, lines).output
      end
    end
    threads.each(&:join)

    # Report on output:
    exit NdrDevSupport::Rubocop::Reporter.new(output).report
  end

  desc <<-USAGE
    Usage:
      rake rubocop:diff HEAD
      rake rubocop:diff HEAD~3..HEAD~2
      rake rubocop:diff HEAD~3..HEAD~2
      rake rubocop:diff aef12fd4
      rake rubocop:diff master
  USAGE
  task :diff do
    args = ARGV.dup
    nil until 'rubocop:diff' == args.shift

    ranges = NdrDevSupport::Rubocop::RangeFinder.new.diff_expr args.join(' ')
    rubocop_file_ranges ranges
  end

  namespace :diff do
    desc 'Usage: rake rubocop:diff:head'
    task :head do
      rubocop_file_ranges NdrDevSupport::Rubocop::RangeFinder.new.diff_head
    end

    desc 'Usage: rake rubocop:diff:unstaged'
    task :unstaged do
      rubocop_file_ranges NdrDevSupport::Rubocop::RangeFinder.new.diff_unstaged
    end

    desc 'Usage: rake rubocop:diff:staged'
    task :staged do
      rubocop_file_ranges NdrDevSupport::Rubocop::RangeFinder.new.diff_staged
    end

    desc 'Usage: rake rubocop:diff:file file [,file]'
    task :file do
      files = ARGV.uniq.select { |file| File.exist?(file) }

      file_ranges = NdrDevSupport::Rubocop::RangeFinder.new.diff_files(files)
      rubocop_file_ranges(file_ranges)
    end
  end
end
