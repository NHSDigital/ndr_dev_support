namespace :ci do
  desc 'Brakeman'
  task brakeman: 'ci:rugged:setup' do
    next unless defined?(Rails)

    require 'ndr_dev_support/rake_ci/brakeman_helper'
    # Usage: bundle exec rake ci:brakeman

    @metrics ||= []
    @attachments ||= []

    brakeman = NdrDevSupport::RakeCI::BrakemanHelper.new
    brakeman.commit = @commit
    brakeman.run(strict: false)

    @metrics.concat(brakeman.metrics)
    @attachments.concat(brakeman.attachments)

    brakeman.save_current_fingerprints
  end

  namespace :brakeman do
    desc "Brakeman (strict mode - all issues must be reviewed by Brakeman's interactive mode)"
    task strict: 'ci:rugged:setup' do
      next unless defined?(Rails)

      require 'ndr_dev_support/rake_ci/brakeman_helper'
      # Usage: bundle exec rake ci:brakeman:strict

      @metrics ||= []
      @attachments ||= []

      brakeman = NdrDevSupport::RakeCI::BrakemanHelper.new
      brakeman.commit = @commit
      brakeman.run(strict: true)

      @metrics.concat(brakeman.metrics)
      @attachments.concat(brakeman.attachments)

      brakeman.save_current_fingerprints
    end

    desc 'Brakeman fingerprint details'
    task fingerprint_details: 'ci:rugged:setup' do
      # Usage: bundle exec rake ci:brakeman:fingerprint_details FINGERPRINTS=fp1,fp2,...
      next unless defined?(Rails)

      require 'ndr_dev_support/rake_ci/brakeman_helper'
      require 'brakeman/scanner'
      require 'brakeman/report/report_text'

      fingerprints = ENV['FINGERPRINTS'].split(/,/)

      puts 'Scanning for fingerprints...'
      puts fingerprints
      puts

      brakeman = NdrDevSupport::RakeCI::BrakemanHelper.new
      brakeman.commit = @commit
      brakeman.run

      text_reporter = Brakeman::Report::Text.new(brakeman.tracker)

      brakeman.warnings.each do |warning|
        next unless fingerprints.include?(warning.fingerprint)

        puts
        puts text_reporter.label('Fingerprint', warning.fingerprint.to_s)
        puts text_reporter.output_warning(warning)
      end
      puts
    end
  end
end
