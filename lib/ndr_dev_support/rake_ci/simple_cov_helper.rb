module NdrDevSupport
  module RakeCI
    # This helper persists the SimpleCov::Result
    class SimpleCovHelper
      require 'rugged'
      require 'simplecov'
      require_relative 'concerns/commit_metadata_persistable'

      include CommitMetadataPersistable

      def commit
        return @commit if @commit

        repo = Rugged::Repository.new('.')
        @commit = repo.lookup(repo.head.target_id)
      end

      def load_current_result
        load_current_commit_data
      end

      def save_current_result(result)
        save_current_commit_data(result)
      end
    end
  end
end
