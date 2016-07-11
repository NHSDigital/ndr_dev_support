module NdrDevSupport
  module IntegrationTesting
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
