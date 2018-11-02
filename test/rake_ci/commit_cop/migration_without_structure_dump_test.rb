require 'test_helper'
require 'ndr_dev_support/rake_ci/commit_cop'

module RakeCI
  module CommitCop
    # Test ModifiedMigration cop functionality
    class MigrationWithoutStructureDumpTest < Minitest::Test
      def setup
        NdrDevSupport::RakeCI::CommitCop.migration_paths = ['db/migrate']
        @cop = NdrDevSupport::RakeCI::CommitCop::MigrationWithoutStructureDump.new
        @changes = { added: Set.new, deleted: Set.new, modified: Set.new, renamed: Set.new }
      end

      def test_should_not_respond_to_no_migration
        assert_nil @cop.check(@changes)
      end

      def test_should_not_respond_to_migration_with_structure_file
        @changes[:added].add('db/migrate/20181020223344_create_something.rb')
        @changes[:modified].add('db/structure.sql')
        assert_nil @cop.check(@changes)
      end

      def test_should_not_respond_to_migration_with_schema_file
        @changes[:added].add('db/migrate/20181020223344_create_something.rb')
        @changes[:modified].add('db/schema.rb')
        assert_nil @cop.check(@changes)
      end

      def test_should_respond_to_migration_with_no_structure_or_schema_file
        @changes[:added].add('db/migrate/20181020223344_create_something.rb')
        assert_kind_of Hash, @cop.check(@changes)
      end

      def test_custom_patterns
        NdrDevSupport::RakeCI::CommitCop.with_pattern do
          NdrDevSupport::RakeCI::CommitCop.migration_paths = ['database/migrate/', 'db/migrate']
          NdrDevSupport::RakeCI::CommitCop.structure_dump_pattern = %r{\Adatabase/struct\.sql\z}

          @changes[:added].add('database/migrate/20181020223344_create_something.rb')
          @changes[:modified].add('database/struct.sql')
          assert_nil @cop.check(@changes)

          @changes[:modified].delete('database/struct.sql')
          assert_kind_of Hash, @cop.check(@changes)
        end
      end

      def test_should_not_respond_to_migration_with_no_structure_or_schema_file_outside_rails
        NdrDevSupport::RakeCI::CommitCop.with_pattern do
          NdrDevSupport::RakeCI::CommitCop.migration_paths = []
          @changes[:added].add('db/migrate/20181020223344_create_something.rb')
          assert_nil @cop.check(@changes)
        end
      end
    end
  end
end
