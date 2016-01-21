namespace :rubocop do
  desc 'Run Rubocop filtered to altered and related code'
  task :diff do
    # Usage: bin/rake rubocop:diff <paths>
    require 'ndr_dev_support/rubocop/diff'

    ARGV[1..-1].each do |path|
      exit(false) unless NdrDevSupport::Rubocop::Diff.new(path).report
    end
  end
end
