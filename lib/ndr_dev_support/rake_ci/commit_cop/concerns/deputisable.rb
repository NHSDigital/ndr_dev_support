require 'active_support/concern'

module NdrDevSupport
  module RakeCI
    module CommitCop
      # Deputisable cop concern
      module Deputisable
        extend ActiveSupport::Concern

        private

        def migration_file?
          proc do |file|
            if file.is_a?(Array)
              file.any?(&migration_file?)
            else
              file.start_with?(*NdrDevSupport::RakeCI::CommitCop.migration_paths) &&
                file =~ /\d{14}_.*\.rb\z/
            end
          end
        end

        def unscoped_migration_file?
          proc do |file|
            file.start_with?(*NdrDevSupport::RakeCI::CommitCop.migration_paths) &&
              file =~ /\d{14}_[^\.]*\.rb\z/
          end
        end

        def structure_dump_file?
          proc { |file| file =~ NdrDevSupport::RakeCI::CommitCop.structure_dump_pattern }
        end

        def attachment(severity, title, text)
          {
            color: severity.to_s, title: title, text: text, mrkdwn_in: ['text']
          }
        end
      end
    end
  end
end
