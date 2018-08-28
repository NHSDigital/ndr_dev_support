namespace :ci do
  # Runs the Rails rake stats task (if using Rails) and converts counts into "metrics"
  # Usage: bundle exec rake ci:stats
  desc 'stats'
  task :stats do
    next unless Rake::Task.task_defined?('stats')

    @metrics ||= []

    summary_line = `bundle exec rake stats 2>/dev/null | tail -n 2 | head -n 1`
    matchdata = summary_line.match(/Code LOC: (\d+)\b\s+Test LOC: (\d+)\b/)
    code_loc = matchdata[1].to_i
    test_loc = matchdata[2].to_i
    test_ratio = 100.0 * test_loc / code_loc

    metrics = [
      { name: 'stats_code_loc', type: :gauge, value: code_loc },
      { name: 'stats_test_loc', type: :gauge, value: test_loc },
      { name: 'stats_test_ratio', type: :gauge, value: test_ratio }
    ]
    @metrics.concat(metrics)
    puts metrics.inspect
  end
end
