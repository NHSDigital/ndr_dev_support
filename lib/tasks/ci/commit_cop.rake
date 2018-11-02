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

  desc 'changes'
  task changes: 'ci:rugged:setup' do
    # Usage: bin/rake ci:changes
    require 'ndr_dev_support/rake_ci/commit_cop'

    changes = NdrDevSupport::RakeCI::CommitCop.changes(@commit)

    puts changes.inspect
  end
end
