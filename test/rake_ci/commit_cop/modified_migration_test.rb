require 'test_helper'
require 'ndr_dev_support/rake_ci/commit_cop'

module RakeCI
  module CommitCop
    # Test ModifiedMigration cop functionality
    class ModifiedMigrationTest < Minitest::Test
      def setup
        @cop = NdrDevSupport::RakeCI::CommitCop::ModifiedMigration.new
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

      def test_should_respond_to_modified_migration
        @changes[:modified].add('db/migrate/20181020223344_create_something.rb')
        assert_kind_of Hash, @cop.check(@changes)
      end

      def test_should_respond_to_modified_scoped_migration
        @changes[:modified].add('db/migrate/20181020223344_create_something.some_scope.rb')
        assert_kind_of Hash, @cop.check(@changes)
      end

      def test_custom_pattern
        NdrDevSupport::RakeCI::CommitCop.with_pattern do
          NdrDevSupport::RakeCI::CommitCop.migration_path_pattern = %r{\Adatabase/migrate/}

          @changes[:modified].add('database/migrate/20181020223344_create_something.rb')
          assert_kind_of Hash, @cop.check(@changes)
        end
      end
    end
  end
end
