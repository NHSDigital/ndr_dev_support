require 'test_helper'
require 'ndr_dev_support/rake_ci/commit_cop'

module RakeCI
  module CommitCop
    # Test missing associated test cop functionality
    class MissingAssociatedTestFileTest < Minitest::Test
      def setup
        NdrDevSupport::RakeCI::CommitCop.monitored_paths = ['app/monitored_path']
        @cop = NdrDevSupport::RakeCI::CommitCop::MissingAssociatedTestFile.new
        @changes = { added: Set.new, deleted: Set.new, modified: Set.new, renamed: Set.new }
      end

      def test_should_not_respond_to_no_new_file
        assert_nil @cop.check(@changes)
      end

      def test_should_not_respond_to_commit_with_new_file_with_associated_test
        @changes[:added].add('app/monitored_path/new_file.rb')
        @changes[:added].add('test/monitored_path/new_file_test.rb')

        @changes[:added].add('app/monitored_path/namespace/new_file.rb')
        @changes[:added].add('test/monitored_path/namespace/new_file_test.rb')
        assert_nil @cop.check(@changes)
      end

      def test_should_respond_to_commit_with_new_file_but_test_is_not_associated
        @changes[:added].add('app/monitored_path/users_controller.rb')
        @changes[:added].add('test/monitored_path/incorrect_test.rb')
        assert_kind_of Hash, @cop.check(@changes)
      end

      def test_should_respond_to_new_file_without_associated_test
        @changes[:added].add('app/monitored_path/users_controller.rb')
        assert_kind_of Hash, @cop.check(@changes)
      end

      def test_should_not_respond_to_unmonitored_path
        @changes[:added].add('app/unmonitored_path/new_file.rb')
        assert_nil @cop.check(@changes)
      end
    end
  end
end
