require 'minitest'
require 'rugged'
require 'ndr_dev_support/rake_ci/concerns/commit_metadata_persistable'

# The plugin needs to extend Minitest
module Minitest
  # RakeCI Minitest Reporter
  class RakeCIReporter < StatisticsReporter
    include CommitMetadataPersistable

    def report
      super

      hash = {
        statistics: current_statistics,
        # results: results,
        metrics: current_metrics,
        attachments: current_attachments
      }

      save_current_commit_data(hash)
    end

    def commit
      return @commit if @commit

      repo = Rugged::Repository.new('.')
      @commit = repo.lookup(repo.head.target_id)
    end

    def load_current_commit_hash
      load_current_commit_data
    end

    private

    def current_statistics
      @current_statistics ||= {
        total_time: total_time, runs: count, assertions: assertions, failures: failures,
        errors: errors, skips: skips
      }
    end

    def current_metrics
      return @current_metrics if @current_metrics

      @current_metrics = []
      (current_statistics.keys - %i[total_time]).each do |name|
        metric = {
          name: 'ci_test_count',
          type: :gauge,
          label_set: { name: name },
          value: current_statistics[name]
        }
        @current_metrics << metric
        io.puts metric.inspect
      end
      @current_metrics
    end

    def current_attachments
      return @current_attachments if @current_attachments

      @current_attachments = []
      @current_attachments << failures_attachment if failures.positive?
      @current_attachments << errors_attachment if errors.positive?
      @current_attachments << pass_attachment if newly_passing?
      @current_attachments
    end

    def failures_attachment
      {
        color: 'danger',
        text: ActionController::Base.helpers.pluralize(failures, 'test failure'),
        footer: 'bundle exec rake ci:minitest'
      }
    end

    def errors_attachment
      {
        color: 'warning',
        text: ActionController::Base.helpers.pluralize(errors, 'test error'),
        footer: 'bundle exec rake ci:minitest'
      }
    end

    def pass_attachment
      {
        color: 'good',
        text: 'Tests now pass',
        footer: 'bundle exec rake ci:minitest'
      }
    end

    def newly_passing?
      return false if failures.positive? || errors.positive?

      last_commit_hash = load_last_commit_data
      return false if last_commit_hash.nil?

      last_commit_hash[:statistics][:failures].positive? ||
        last_commit_hash[:statistics][:errors].positive?
    end

    def name
      'minitest'
    end
  end

  def self.plugin_rake_ci_init(_options)
    reporter << RakeCIReporter.new
  end
end

Minitest.extensions << 'rake_ci'
