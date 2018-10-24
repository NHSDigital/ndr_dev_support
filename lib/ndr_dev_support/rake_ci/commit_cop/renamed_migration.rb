require_relative 'concerns/deputisable'

module NdrDevSupport
  module RakeCI
    module CommitCop
      # This cop checks for renamed migrations allowing for unscoped to scoped name changes
      class RenamedMigration
        include Deputisable

        def check(changes)
          renamed_migrations = changes[:renamed].select(&migration_file?)
          return if renamed_migrations.empty?
          return if renamed_migrations.all? do |old_file, new_file|
            unscoped_migration_file?.call(old_file) && !unscoped_migration_file?.call(new_file)
          end

          attachment(:danger,
                     'Renamed Migration',
                     'Migrations should not be renamed unless adding a scope')
        end
      end
    end
  end
end
