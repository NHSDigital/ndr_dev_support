namespace :ci do
  namespace :simplecov do
    desc 'setup'
    task :setup do
      # Usage: bundle exec rake ci:simplecov:setup test
      require 'simplecov'
      require 'ndr_dev_support/rake_ci/simple_cov_helper'

      SimpleCov.at_exit do
        result = SimpleCov.result
        result.format! if ENV['RAKECI_HEADLESS'].nil?
        NdrDevSupport::RakeCI::SimpleCovHelper.new.save_current_result(result)
      end

      SimpleCov.start
    end

    desc 'process'
    task :process do
      require 'simplecov'
      require 'ndr_dev_support/rake_ci/simple_cov_helper'

      helper = NdrDevSupport::RakeCI::SimpleCovHelper.new
      result = helper.load_current_result
      next if result.nil?

      metrics = [
        { name: 'simplecov_covered_percent', type: :gauge, value: result.covered_percent },
        { name: 'simplecov_covered_lines', type: :gauge, value: result.covered_lines },
        { name: 'simplecov_total_lines', type: :gauge, value: result.total_lines }
      ]
      @metrics ||= []
      @metrics.concat(metrics)
      puts metrics.inspect
    end
  end
end
