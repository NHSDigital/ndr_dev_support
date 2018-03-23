namespace :ci do
  desc 'linguist'
  task linguist: 'ci:rugged:setup' do
    require 'linguist'

    def linguist_loc_metrics(language, line_count, percent)
      metrics = [
        {
          name: 'linguist_code_count', type: :gauge,
          label_set: { language: language }, value: line_count
        },
        {
          name: 'linguist_code_percent', type: :gauge,
          label_set: { language: language }, value: percent.round(1)
        }
      ]
      puts metrics.inspect
      metrics
    end

    @metrics ||= []

    project = Linguist::Repository.new(@repo, @repo.head.target_id)
    total_line_count = project.languages.values.reduce(:+)
    other_line_count = 0

    project.languages.each do |language, line_count|
      percent = 100.0 * line_count / total_line_count

      if percent > 1
        @metrics.concat(linguist_loc_metrics(language, line_count, percent))
      else
        other_line_count += line_count
      end
    end

    if other_line_count > 0
      other_percent = 100.0 * other_line_count / total_line_count
      @metrics.concat(linguist_loc_metrics('Other', other_line_count, other_percent))
    end
  end
end
