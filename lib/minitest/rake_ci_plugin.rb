require 'active_support/core_ext/string/inflections'
require 'minitest'
require 'rugged'
require 'ndr_dev_support/rake_ci/concerns/commit_metadata_persistable'

# The plugin needs to extend Minitest
module Minitest
  def self.plugin_rake_ci_init(options)
    reporter << RakeCIReporter.new(options[:io], options) if RakeCIReporter.enabled?
  end

  # Intermediate Reporter than can also track flakey failures
  class FlakeyStatisticsReporter < StatisticsReporter
    attr_accessor :flakey_results

    def initialize(*)
      super

      self.flakey_results = []
    end

    def record(result)
      super

      return unless result.respond_to?(:flakes)

      flakey_results << result if result.flakes.any?
    end

    def flakes
      flakey_results.sum { |result| result.flakes.length }
    end
  end

  # RakeCI Minitest Reporter
  class RakeCIReporter < FlakeyStatisticsReporter
    def self.enable!
      @enabled = true
    end

    def self.enabled?
      @enabled ||= !!ENV['MINITEST_RAKE_CI']
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

    redefine_method :commit do
      return @commit if @commit

      repo = Rugged::Repository.new('.')
      @commit = repo.lookup(repo.head.target_id)
    end

    def load_current_commit_hash
      load_current_commit_data
    end

    private

    def error_snippets
      snippets_for results.reject(&:skipped?).select(&:error?)
    end

    def failure_snippets
      snippets_for results.reject(&:skipped?).reject(&:error?)
    end

    def flake_snippets
      snippets_for flakey_results
    end

    # Adapted from Rails' TestUnit reporter in lib/rails/test_unit/reporter.rb
    def snippets_for(results, limit = 5)
      executable = defined?(Rails) ? 'bin/rails test ' : 'bundle exec rake test TEST='

      snippets = results[0, limit].map do |result|
        location, line =
          if result.respond_to?(:source_location)
            result.source_location
          else
            result.method(result.name).source_location
          end

        # Include test result details, as well has how to rerun the failed test
        "#{result}#{executable}#{location.sub(%r{^#{Dir.pwd}/?}, '')}:#{line}"
      end

      snippets << "+ #{results.length - limit} more" if (results.length - limit).positive?

      snippets.any? ? "\n```\n#{snippets.join("\n")}\n```" : ''
    end

    def current_statistics
      @current_statistics ||= {
        total_time: total_time, runs: count, assertions: assertions, failures: failures,
        errors: errors, skips: skips, flakes: flakes
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
      @current_attachments << flakes_attachment if flakes.positive?
      @current_attachments
    end

    def failures_attachment
      {
        color: 'danger',
        text: 'test failure'.pluralize(failures) + failure_snippets,
        footer: footer
      }
    end

    def flakes_attachment
      {
        color: '#bb44ff',
        text: 'flakey test'.pluralize(flakes) + flake_snippets,
        footer: footer
      }
    end

    def errors_attachment
      {
        color: 'warning',
        text: 'test error'.pluralize(errors) + error_snippets,
        footer: footer
      }
    end

    def pass_attachment
      {
        color: 'good',
        text: newly_passing? ? 'Tests now pass! :tada:' : 'Tests passed',
        footer: footer
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

    def footer
      "bundle exec rake ci:minitest --seed #{options[:seed]}"
    end
  end
end
