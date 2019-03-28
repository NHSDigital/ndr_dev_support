namespace :rubocop do
  require 'ndr_dev_support/rubocop/range_finder'
  require 'ndr_dev_support/rubocop/range_augmenter'
  require 'ndr_dev_support/rubocop/executor'
  require 'ndr_dev_support/rubocop/reporter'

  def filtered_offenses_by_line(offenses, lines)
    offenses.select do |offense|
      line = offense['location']['line']
      1 == line || lines.include?(line)
    end
  end

  # For a given set of change locations (extract from a diff),
  # run rubocop on the relevant files, and report filtered results.
  def rubocop_file_ranges(file_ranges)
    output   = {}
    offenses = NdrDevSupport::Rubocop::Executor.new(file_ranges.keys).offenses_by_file

    threads = offenses.map do |file, file_offenses|
      Thread.new do
        # Expand ranges to include entire methods, etc:
        augmenter = NdrDevSupport::Rubocop::RangeAugmenter.new(file, file_ranges[file] || [])
        # Get subset of rubocop output for those files:
        output[file] = filtered_offenses_by_line(file_offenses, augmenter.augmented_lines)
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

  desc 'A summary of offense counts by cop'
  task :summary do
    # Usage: bin/rake rubocop:summary
    require 'json'

    output = `bundle exec rubocop --format json .`
    offenses = JSON.parse(output)['files'].flat_map { |file| file['offenses'] }
    cop_names = offenses.map { |offense| offense['cop_name'] }
    summary = cop_names.group_by { |x| x }.
              map { |cop_name, array| [cop_name, array.count] }.
              sort_by { |_cop_name, count| count }.
              reverse
    cop_name_max_length = cop_names.map(&:length).max

    puts "#{'Cop Name'.ljust(cop_name_max_length)} | Count"
    puts "#{'-' * cop_name_max_length}-+------"
    summary.each do |cop_name, count|
      puts "#{cop_name.ljust(cop_name_max_length)} | #{count}"
    end
  end
end
