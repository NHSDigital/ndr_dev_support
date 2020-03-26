module NdrDevSupport
  module RakeCI
    # Brakeman helper
    class BrakemanHelper
      require 'set'
      require 'brakeman'
      require_relative 'concerns/commit_metadata_persistable'

      include CommitMetadataPersistable

      attr_reader :new_fingerprints, :old_fingerprints, :tracker

      def run(strict:)
        @strict = strict

        @tracker = ::Brakeman.run(app_path: '.')

        last_commit_fingerprints = load_last_commit_data
        if last_commit_fingerprints
          @new_fingerprints = current_fingerprints - last_commit_fingerprints
          @old_fingerprints = last_commit_fingerprints - current_fingerprints
        else
          @new_fingerprints = @old_fingerprints = Set.new
        end
      end

      # All warnings (including those we've flagged as false positives)
      def warnings
        @tracker.warnings
      end

      # Only the warnings we haven't flagged as false positives (i.e. the outstanding ones)
      def filtered_warnings
        @tracker.filtered_warnings
      end

      def warning_counts_by_confidence
        return @warning_counts_by_confidence if @warning_counts_by_confidence

        @warning_counts_by_confidence = {}
        warnings.group_by(&:confidence).each do |confidence, grouped_warnings|
          @warning_counts_by_confidence[confidence] = grouped_warnings.count
        end
        @warning_counts_by_confidence
      end

      def filtered_warning_counts_by_confidence
        return @filtered_warning_counts_by_confidence if @filtered_warning_counts_by_confidence

        @filtered_warning_counts_by_confidence = {}
        filtered_warnings.group_by(&:confidence).each do |confidence, grouped_warnings|
          @filtered_warning_counts_by_confidence[confidence] = grouped_warnings.count
        end
        @filtered_warning_counts_by_confidence
      end

      def current_fingerprints
        @current_fingerprints ||= filtered_warnings.map(&:fingerprint).to_set
      end

      def save_current_fingerprints
        save_current_commit_data(current_fingerprints)
      end

      def metrics
        metrics = []

        ::Brakeman::Warning::TEXT_CONFIDENCE.each do |confidence, text|
          overall_metric = {
            name: 'brakeman_warnings',
            type: :gauge,
            label_set: { confidence: text },
            value: warning_counts_by_confidence[confidence] || 0
          }
          filtered_metric = {
            name: 'brakeman_filtered_warnings',
            type: :gauge,
            label_set: { confidence: text },
            value: filtered_warning_counts_by_confidence[confidence] || 0
          }
          metrics << overall_metric << filtered_metric
          puts overall_metric.inspect
          puts filtered_metric.inspect
        end

        metrics
      end

      def attachments
        attachments = []

        if @strict && current_fingerprints.any?
          # all warnings found
          attachment = {
            color: 'danger',
            title: "#{current_fingerprints.size} Brakeman warning(s) :rotating_light:",
            text: '_Brakeman_ warning fingerprint(s):' \
            "```#{current_fingerprints.to_a.join("\n")}```",
            footer: 'bundle exec rake ci:brakeman:fingerprint_details FINGERPRINTS=...',
            mrkdwn_in: ['text']
          }
          attachments << attachment
          puts attachment.inspect
        elsif new_fingerprints.any?
          # new warnings found
          attachment = {
            color: 'danger',
            title: "#{new_fingerprints.size} new Brakeman warning(s) :rotating_light:",
            text: '_Brakeman_ warning fingerprint(s):' \
            "```#{new_fingerprints.to_a.join("\n")}```",
            footer: 'bundle exec rake ci:brakeman:fingerprint_details FINGERPRINTS=...',
            mrkdwn_in: ['text']
          }
          attachments << attachment
          puts attachment.inspect
        end

        unless old_fingerprints.empty?
          # old warnings missing
          attachment = {
            color: 'good',
            title: "#{old_fingerprints.size} Brakeman warning(s) resolved :+1:",
            footer: 'bundle exec rake ci:brakeman'
          }
          attachments << attachment
          puts attachment.inspect
        end

        attachments
      end
    end
  end
end
