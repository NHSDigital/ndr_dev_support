require 'active_support/core_ext/module/attribute_accessors'
require_relative 'commit_cop/migration_without_structure_dump'
require_relative 'commit_cop/modified_migration'
require_relative 'commit_cop/renamed_migration'

module NdrDevSupport
  module RakeCI
    # This module encapsulates commit cop logic
    module CommitCop
      # This defines the regular expression that identifies the path to migration files.
      mattr_accessor :migration_path_pattern
      self.migration_path_pattern = %r{\Adb/migrate/}

      # This defines the regular expression that identifies structure dump files.
      mattr_accessor :structure_dump_pattern
      self.structure_dump_pattern = %r{\Adb/(structure\.sql|schema\.rb)\z}

      COMMIT_COPS = [
        MigrationWithoutStructureDump,
        ModifiedMigration,
        RenamedMigration
      ].freeze

      # enumerates over each delta of the commmit
      def self.each_delta(commit, &block)
        diffs = commit.parents.first.diff(commit)
        diffs.find_similar!
        diffs.each_delta(&block)
      end

      # converts the deltas into a simpler changes hash of filename sets representation
      def self.changes(commit)
        changes = { added: Set.new, deleted: Set.new, modified: Set.new, renamed: Set.new }

        each_delta(commit) do |delta|
          if delta.status == :renamed
            changes[delta.status].add([delta.old_file[:path], delta.new_file[:path]])
          else
            # old_file and new_file are the same
            changes[delta.status].add(delta.old_file[:path])
          end
        end

        changes
      end

      # Isolates migration/structure pattern changes by resetting them after yielding
      def self.with_pattern
        default_migration_path_pattern = migration_path_pattern
        default_structure_dump_pattern = structure_dump_pattern

        yield

        self.migration_path_pattern = default_migration_path_pattern
        self.structure_dump_pattern = default_structure_dump_pattern
      end
    end
  end
end
