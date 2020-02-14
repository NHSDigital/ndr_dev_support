Capistrano::Configuration.instance(:must_exist).load do
  # Maintains a second checkout SVN locally, then uses sftp to push.
  # This avoids the deployment target needing to have any direct
  # access to the source code repository.
  set :scm, :subversion
  set :deploy_via, :copy
  set :copy_strategy, :export
  set :copy_cache, 'tmp/deployment'
  set :copy_dir, 'tmp/staging'

  namespace :ndr_dev_support do
    desc 'Remove the SVN cache (it may be pointing at the wrong branch)'
    task :remove_svn_cache_if_needed do
      cache = fetch(:copy_cache)
      unless Dir.exist?(cache) && `svn info #{cache}`.include?(fetch(:repository))
        logger.debug "Cache is stale for #{fetch(:branch)}, wiping..."
        system("rm -rf #{cache}")
      end
    end

    desc 'Ensures compilation artefacts are removed from the compressed archive sent to the server'
    task :augment_copy_exclude do
      set :copy_exclude, (fetch(:copy_exclude) || []) + %w[node_modules tmp/*]
    end
  end

  before 'deploy:update_code', 'ndr_dev_support:augment_copy_exclude'
  before 'deploy:update_code', 'ndr_dev_support:remove_svn_cache_if_needed'
end
