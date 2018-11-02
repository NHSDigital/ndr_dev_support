require_relative 'concerns/deputisable'

module NdrDevSupport
  module RakeCI
    module CommitCop
      # This cop checks for new migrations with no accompanying structure dump
      class MigrationWithoutStructureDump
        include Deputisable

        def check(changes)
          return unless changes[:added].any?(&unscoped_migration_file?) &&
                        changes[:modified].none?(&structure_dump_file?)

          attachment(:danger,
                     'No structure file committed',
                     'Migration(s) were added with no accompanying structure file(s)')
        end
      end
    end
  end
end
