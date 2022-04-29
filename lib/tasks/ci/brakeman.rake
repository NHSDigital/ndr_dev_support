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
      begin
        brakeman.run(strict: true)
      rescue StandardError => e
        warn <<~MESSAGE
          Error: Brakeman failed with #{e.class}: #{e}
          There is probably a ruby syntax error in one of the files. To find it, run:
          $ brakeman -I --debug
          For the full backtrace, run
          $ rake ci:brakeman --trace
        MESSAGE
        @attachments << {
          color: 'danger',
          title: 'Brakeman Error',
          text: 'Brakeman run failed. Run brakeman -I --debug',
          footer: 'bundle exec rake ci:brakeman:strict'
        }
        next
      end

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
      brakeman.run(strict: false)

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
