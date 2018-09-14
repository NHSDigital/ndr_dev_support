Capistrano::Configuration.instance(:must_exist).load do
  # Maintains a second checkout SVN locally, then uses sftp to push.
  # This avoids the deployment target needing to have any direct
  # access to the source code repository.
  set :scm, :subversion
  set :deploy_via, :copy
  set :copy_strategy, :export
  set :copy_cache, 'tmp/deployment'

  namespace :ndr_dev_support do
    desc 'Remove the SVN cache (it may be pointing at the wrong branch)'
    task :remove_svn_cache_if_needed do
      cache = fetch(:copy_cache)
      unless Dir.exist?(cache) && `svn info #{cache}`.include?(fetch(:repository))
        logger.debug "Cache is stale for #{fetch(:branch)}, wiping..."
        system("rm -rf #{cache}")
      end
    end
  end

  before 'deploy:update_code', 'ndr_dev_support:remove_svn_cache_if_needed'
end
