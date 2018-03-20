namespace :ci do
  # Runs the Rails rake notes task (if using Rails) and converts annotation counts into "metrics"
  # Usage: bundle exec rake ci:notes
  desc 'Count notes and other annotations'
  task :notes do
    next unless Rake::Task.task_defined?('notes')

    hash = {}
    `bundle exec rake notes | grep "\\["`.split(/\n/).map do |line|
      matchdata = line.match(/\[\s*\d+\] \[([^\]]+)\]/)
      annotation = matchdata[1]
      hash[annotation] ||= 0
      hash[annotation] += 1
    end

    hash.each do |annotation, count|
      metric = {
        name: 'annotation_count',
        type: :gauge,
        label_set: {
          annotation: annotation
        },
        value: count
      }
      @metrics ||= []
      @metrics << metric
      puts metric.inspect
    end
  end
end
