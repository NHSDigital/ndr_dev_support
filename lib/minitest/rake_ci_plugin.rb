require 'active_support/core_ext/string/inflections'
require 'minitest'
require 'rugged'
require 'ndr_dev_support/rake_ci/concerns/commit_metadata_persistable'

# The plugin needs to extend Minitest
module Minitest
  def self.plugin_rake_ci_init(_options)
    reporter << RakeCIReporter.new if RakeCIReporter.enabled?
  end

  # RakeCI Minitest Reporter
  class RakeCIReporter < StatisticsReporter
    def self.enable!
      @enabled = true
    end

    def self.enabled?
      @enabled ||= false
    end

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
      @current_attachments << pass_attachment if passing?
      @current_attachments
    end

    def failures_attachment
      {
        color: 'danger',
        text: 'test failure'.pluralize(failures),
        footer: 'bundle exec rake ci:minitest'
      }
    end

    def errors_attachment
      {
        color: 'warning',
        text: 'test error'.pluralize(errors),
        footer: 'bundle exec rake ci:minitest'
      }
    end

    def pass_attachment
      {
        color: 'good',
        text: newly_passing? ? 'Tests now pass! :tada:' : 'Tests passed',
        footer: 'bundle exec rake ci:minitest'
      }
    end

    def passing?
      !(failures.positive? || errors.positive?)
    end

    def newly_passing?
      return false unless passing?

      last_commit_hash = load_last_commit_data
      return false if last_commit_hash.nil?

      last_commit_hash[:statistics][:failures].positive? ||
        last_commit_hash[:statistics][:errors].positive?
    end

    def name
      'minitest'
    end
  end
end
