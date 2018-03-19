namespace :ci do
  namespace :rugged do
    desc 'setup'
    task :setup do
      require 'ndr_dev_support/daemon/ci_server'

      repo = Rugged::Repository.new('.')
      @commit = repo.lookup(repo.head.target_id)
      @friendly_revision_name = NdrDevSupport::Daemon::CIServer.friendly_revision_name(@commit)
    end
  end
end
