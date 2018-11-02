require 'test_helper'
require 'ndr_dev_support/rake_ci/commit_cop'

module RakeCI
  module CommitCop
    # Test RenamedMigration cop functionality
    class RenamedMigrationTest < Minitest::Test
      def setup
        NdrDevSupport::RakeCI::CommitCop.migration_paths = ['db/migrate']
        @cop = NdrDevSupport::RakeCI::CommitCop::RenamedMigration.new
        @changes = { added: Set.new, deleted: Set.new, modified: Set.new, renamed: Set.new }
      end

      def test_should_not_respond_to_no_migration
        assert_nil @cop.check(@changes)
      end

      def test_should_not_respond_to_added_migration
        @changes[:added].add('db/migrate/20181020223344_create_something.rb')
        assert_nil @cop.check(@changes)
      end

      def test_should_not_respond_to_deleted_migration
        @changes[:deleted].add('db/migrate/20181020223344_create_something.rb')
        assert_nil @cop.check(@changes)
      end

      def test_should_not_respond_to_modified_migration
        @changes[:modified].add('db/migrate/20181020223344_create_something.rb')
        assert_nil @cop.check(@changes)
      end

      def test_should_not_respond_to_renamed_non_migration
        @changes[:renamed].add([
                                 'tmp/somthing_else.rb',
                                 'tmp/somthang_else.rb'
                               ])
        assert_nil @cop.check(@changes)
      end

      def test_should_not_respond_to_scope_renamed_timestamp_unchanged_migration
        @changes[:renamed].add([
                                 'db/migrate/20181020223344_create_something.rb',
                                 'db/migrate/20181020223344_create_something.some_scope.rb'
                               ])
        assert_nil @cop.check(@changes)
      end

      def test_should_not_respond_to_renamed_timestamp_unchanged_migration
        @changes[:renamed].add([
                                 'db/migrate/20181020223344_create_lookup.rb',
                                 'db/migrate/20181020223344_create_specific_lookup.rb'
                               ])
        assert_nil @cop.check(@changes)
      end

      def test_should_respond_to_timestamp_changed_migration
        @changes[:renamed].add([
                                 'db/migrate/20181020223344_create_something.rb',
                                 'db/migrate/20181020223355_create_somethang.rb'
                               ])
        assert_kind_of Hash, @cop.check(@changes)
      end

      def test_custom_pattern_should_respond_to_timestamp_changed_migration
        NdrDevSupport::RakeCI::CommitCop.with_pattern do
          NdrDevSupport::RakeCI::CommitCop.migration_paths = ['database/migrate/', 'db/migrate']

          @changes[:renamed].add([
                                   'database/migrate/20181020223344_create_something.rb',
                                   'database/migrate/20181020223355_create_somethang.rb'
                                 ])
          assert_kind_of Hash, @cop.check(@changes)
        end
      end

      def test_should_respond_to_timestamp_changed_migration_outside_rails
        NdrDevSupport::RakeCI::CommitCop.with_pattern do
          NdrDevSupport::RakeCI::CommitCop.migration_paths = []
          @changes[:renamed].add([
                                   'db/migrate/20181020223344_create_something.rb',
                                   'db/migrate/20181020223355_create_somethang.rb'
                                 ])
          assert_nil @cop.check(@changes)
        end
      end
    end
  end
end
