# era
# NdrDevSupport::RakeCI::CommitCop.structure_dump_pattern = %r{\Adb/(development_)?structure\.sql\z}
# ndtms_v2
# NdrDevSupport::RakeCI::CommitCop.migration_path_pattern = %r{\Adbs/migrate/}
# NdrDevSupport::RakeCI::CommitCop.structure_dump_pattern = %r{\Adbs/(det|dams|ndtms)/structure\.sql\z}

namespace :ci do
  desc 'commit_cop'
  task commit_cop: 'ci:rugged:setup' do |t|
    # Usage: bin/rake ci:commit_cop
    require 'ndr_dev_support/rake_ci/commit_cop'

    @attachments ||= []
    changes = NdrDevSupport::RakeCI::CommitCop.changes(@commit)

    NdrDevSupport::RakeCI::CommitCop::COMMIT_COPS.each do |klass|
      attachment = klass.new.check(changes)
      next if attachment.nil?

      @attachments << attachment.merge(footer: "bundle exec rake #{t.name}")
      puts attachment.to_yaml
    end
  end
end

namespace :ci do
  desc 'changes'
  task changes: 'ci:rugged:setup' do
    # Usage: bin/rake ci:changes
    require 'ndr_dev_support/rake_ci/commit_cop'

    changes = NdrDevSupport::RakeCI::CommitCop.changes(@commit)

    puts changes.inspect
  end
end
