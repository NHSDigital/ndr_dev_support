module NdrDevSupport
  module IntegrationTesting
    # ==========================================================================
    #
    #                 !! Caution - please read carefully !!
    #
    #   This approach to connection sharing is known to be susceptible
    #   to race conditions. Anecdotally, we've managed to avoid this
    #   being a problem with Oracle because of the use of the confuration
    #
    #     ActiveRecord::Base.connection.raw_connection.non_blocking = false
    #
    #   which prevents the C extension in the adapter being able to run
    #   non-blocking code (i.e. outside of the control of the global interpretter
    #   lock). On Postgres, we haven't employed an equivalent workaround.
    #
    #   For a more resilient alternative, please use the 'database_cleaner'
    #   gem (see README for details).
    #
    # ==========================================================================
    #
    # Capybara starts another rails application in a new thread
    # to test against. For transactional fixtures to work, we need
    # to share the database connection between threads.
    #
    # Derived from: https://gist.github.com/josevalim/470808
    #
    # Modified to support multiple connection pools
    #
    module ConnectionSharing
      def self.prepended(base)
        base.mattr_accessor :shared_connections
        base.shared_connections = {}

        base.singleton_class.prepend(ClassMethods)
      end

      module ClassMethods
        def connection
          shared_connections[connection_config] ||= retrieve_connection
        end
      end
    end
  end
end

ActiveRecord::Base.prepend(NdrDevSupport::IntegrationTesting::ConnectionSharing)
