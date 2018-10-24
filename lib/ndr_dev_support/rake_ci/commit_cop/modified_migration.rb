require_relative 'concerns/deputisable'

module NdrDevSupport
  module RakeCI
    module CommitCop
      # This cop checks for modified migrations
      class ModifiedMigration
        include Deputisable

        def check(changes)
          return if changes[:modified].none?(&migration_file?)

          attachment(:danger,
                     'Modified Migration',
                     'Migrations should not be modified. Create another migration.')
        end
      end
    end
  end
end
