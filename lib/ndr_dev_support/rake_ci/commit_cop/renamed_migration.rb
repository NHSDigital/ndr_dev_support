require_relative 'concerns/deputisable'

module NdrDevSupport
  module RakeCI
    module CommitCop
      # This cop checks for renamed migrations that change timestamp
      class RenamedMigration
        include Deputisable

        def check(changes)
          renamed_migrations = changes[:renamed].select(&migration_file?)
          return if renamed_migrations.all? do |old_file, new_file|
            File.basename(old_file)[0, 14] == File.basename(new_file)[0, 14]
          end

          attachment(:danger,
                     'Renamed Migration',
                     'Migrations should not change timestamp')
        end
      end
    end
  end
end
