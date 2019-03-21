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
    brakeman.run

    Brakeman::Warning::TEXT_CONFIDENCE.each do |confidence, text|
      metric = {
        name: 'brakeman_warnings',
        type: :gauge,
        label_set: { confidence: text },
        value: brakeman.warning_counts_by_confidence[confidence] || 0
      }
      @metrics << metric
      puts metric.inspect
    end

    unless brakeman.new_fingerprints.empty?
      # new warnings found
      attachment = {
        color: 'danger',
        title: "#{brakeman.new_fingerprints.size} new Brakeman warning(s) :rotating_light:",
        text: '_Brakeman_ warning fingerprint(s):' \
              "```#{brakeman.new_fingerprints.to_a.join("\n")}```",
        footer: 'bundle exec rake ci:brakeman',
        mrkdwn_in: ['text']
      }
      @attachments << attachment
      puts attachment.inspect
    end

    unless brakeman.old_fingerprints.empty?
      # old warnings missing
      attachment = {
        color: 'good',
        title: "#{brakeman.old_fingerprints.size} Brakeman warning(s) resolved :+1:",
        footer: 'bundle exec rake ci:brakeman'
      }
      @attachments << attachment
      puts attachment.inspect
    end

    brakeman.save_current_fingerprints
  end

  namespace :brakeman do
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

      text_reporter = Brakeman::Report::Text.new(nil, brakeman.tracker)

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
