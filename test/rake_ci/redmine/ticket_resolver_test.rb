require 'test_helper'
require 'ndr_dev_support/rake_ci/redmine/ticket_resolver'

module RakeCI
  module Redmine
    # Test TicketResolver functionality
    class TicketResolverTest < Minitest::Test
      def test_each_ticket_from_should_not_resolve_tickets
        resolver = NdrDevSupport::RakeCI::Redmine::TicketResolver.new(nil, nil)

        resolver.each_ticket_from('Similar to #123') do |ticket, resolved|
          assert_equal '123', ticket
          refute resolved
        end

        assert_equal [], resolver.each_ticket_from('Resolve 123').to_a
        assert_equal [['123', false]], resolver.each_ticket_from('Mentions #123').to_a
        assert_equal [['123', false]], resolver.each_ticket_from('Relates to #123').to_a
      end

      def test_each_ticket_from_should_resolve_tickets
        resolver = NdrDevSupport::RakeCI::Redmine::TicketResolver.new(nil, nil)

        resolver.each_ticket_from('Closes #123') do |ticket, resolved|
          assert_equal '123', ticket
          assert resolved
        end

        assert_equal [['123', true]], resolver.each_ticket_from('Close #123').to_a
        assert_equal [['123', true]], resolver.each_ticket_from('Closed: #123').to_a
        assert_equal [['123', true]], resolver.each_ticket_from('Fix: [#123]').to_a
        assert_equal [['123', true]], resolver.each_ticket_from('Fixed: [#123#note-22]').to_a

        assert_equal [['34', true], ['23', true], ['42', true]],
                     resolver.each_ticket_from('This closes #34, resolved #23, and fixes #42').to_a
        assert_equal [['34', true], ['23', true], ['42', true]],
                     resolver.each_ticket_from('This resolves #34, #23 and #42').to_a
      end

      def test_update_payload
        resolver = NdrDevSupport::RakeCI::Redmine::TicketResolver.new(nil, nil)

        # resolved, ticket open
        payload = resolver.update_payload('Resolves #123', 'Bob', 'r9876', false, true, true)
        assert_kind_of Hash, payload
        assert_equal '_Resolved by Bob in r9876_:+Resolves+ #123', payload[:notes]
        assert_equal 3, payload[:status_id]

        # resolved, ticket open
        payload = resolver.update_payload('Resolves #123', 'Bob', 'r9876', false, true, false)
        assert_kind_of Hash, payload
        assert_equal <<~MSG.strip, payload[:notes]
          _Resolved by Bob in r9876_:+Resolves+ #123

          *Automated tests did not pass successfully, so ticket status left unchanged.*
        MSG
        assert_nil payload[:status_id]

        # resolved, ticket closed
        payload = resolver.update_payload('Resolves #123', 'Bob', 'r9876', true, true, true)
        assert_kind_of Hash, payload
        assert_equal '_Resolved by Bob in r9876_:+Resolves+ #123', payload[:notes]
        assert_nil payload[:status_id]

        # unresolved, ticket open
        payload = resolver.update_payload('Mentions #123', 'Bob', 'r9876', false, false, true)
        assert_kind_of Hash, payload
        assert_equal '_Referenced by Bob in r9876_:Mentions #123', payload[:notes]
        assert_nil payload[:status_id]

        # unresolved, ticket closed
        payload = resolver.update_payload('Mentions #123', 'Bob', 'r9876', true, false, true)
        assert_kind_of Hash, payload
        assert_equal '_Referenced by Bob in r9876_:Mentions #123', payload[:notes]
        assert_nil payload[:status_id]
      end

      def test_process_commit
        resolver = NdrDevSupport::RakeCI::Redmine::TicketResolver.new(nil, nil)

        resolver.stubs(:ticket_closed?).returns(true)
        resolver.stubs(:update_ticket).returns(nil)

        assert_equal %w[34 23 42],
                     resolver.process_commit('Bob Fossil',
                                             @friendly_revision_name,
                                             'This closes #34, resolved #23, and fixes #42', true)

        assert_equal [],
                     resolver.process_commit('Bob Fossil',
                                             @friendly_revision_name,
                                             'This closes #34, resolved #23, and fixes #42', false)
      end

      # TODO: Test Redmine API
    end
  end
end
