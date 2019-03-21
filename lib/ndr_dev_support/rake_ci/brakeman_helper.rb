module NdrDevSupport
  module RakeCI
    # Brakeman helper
    class BrakemanHelper
      require 'set'
      require 'brakeman'
      require_relative 'concerns/commit_metadata_persistable'

      include CommitMetadataPersistable

      attr_reader :new_fingerprints, :old_fingerprints, :tracker

      def run
        @tracker = ::Brakeman.run(app_path: '.')

        last_commit_fingerprints = load_last_commit_data
        if last_commit_fingerprints
          @new_fingerprints = current_fingerprints - last_commit_fingerprints
          @old_fingerprints = last_commit_fingerprints - current_fingerprints
        else
          @new_fingerprints = @old_fingerprints = Set.new
        end
      end

      def warnings
        @tracker.warnings
      end

      def warning_counts_by_confidence
        return @warning_counts_by_confidence if @warning_counts_by_confidence

        @warning_counts_by_confidence = {}
        warnings.group_by(&:confidence).each do |confidence, grouped_warnings|
          @warning_counts_by_confidence[confidence] = grouped_warnings.count
        end
        @warning_counts_by_confidence
      end

      def current_fingerprints
        @current_fingerprints ||= warnings.map(&:fingerprint).to_set
      end

      def save_current_fingerprints
        save_current_commit_data(current_fingerprints)
      end
    end
  end
end
