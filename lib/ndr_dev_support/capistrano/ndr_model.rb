require 'rainbow'

# Discrete bits of functionality we use automatically:
require_relative 'assets'
require_relative 'restart'
require_relative 'revision_logger'
require_relative 'ruby_version'
require_relative 'standalone_gems'
require_relative 'svn_cache'
require_relative 'sysadmin_scripts'

# This file contains logic for managing deployments structured in our preferred "NDRv2" style.
# More details on the structure can be found on plan.io issue #6565.
#
# == Configuration
#
#   The following variables are used:
#     * :application
#     * :application_user
#     * :explicitly_writeable_shared_paths
#     * :repository_branches
#     * :ruby
#     * :shared_paths
#
#   You'll want to use the `add_target` helper method to register individual deployment targets,
#   by supplying "env" (beta/live etc), "name", "host", "port", "app_user" (e.g. "blog_live"),
#   and "is_web_server" (e.g. should it get assets compiled).
#
#   A configuration file (config/deployments.yml) can be used to set per-environment ruby versions
#   and SVN branches. To use the latter, be sure to set the `:repository_branches` variable
#   to point at the root of the branches. Otherwise, just set `:repository` directly as normal.
#
Capistrano::Configuration.instance(:must_exist).load do
  # Paths that are symlinked for each release to the "shared" directory:
  set :shared_paths, %w[config/database.yml config/secrets.yml log tmp]

  # Paths in shared/ that the application can write to:
  set :explicitly_writeable_shared_paths, %w[log tmp tmp/pids]

  # This flag gets set only when running `ndr_dev_support:prepare`, which means it can be used
  # to toggle behaviour in environments where some targets are using the NDR model of deployment,
  # and others aren't.
  set :ndr_model_deployment, false

  namespace :ndr_dev_support do
    desc 'Custom tasks to be run once, immediately before the initial `cap setup`'
    task :pre_setup do
      # Ensure that the deployment area is owned by the deployer group, and that this is
      # sticky; all deployments made within it should be owned by the deployer group too. This
      # means that e.g. a deployment by "bob.smith" can then be rolled back by "tom.jones".
      run "mkdir -p #{deploy_to}"
      run "chgrp -R deployer #{deploy_to}"

      # The sticky group will apply automatically to new subdirectories, but
      # any existing subdirectories will need it manually applying via `-R`.
      run "chmod -R g+s #{deploy_to}"
    end

    desc 'Custom tasks to be run once, after the initial `cap setup`'
    task :post_setup do
      fetch(:explicitly_writeable_shared_paths, []).each do |path|
        full_path = File.join(shared_path, path)
        run "mkdir -p #{full_path}"

        # Allow the application to write into here:
        run "chgrp -R #{application_group} #{full_path}"
        run "chmod -R g+s #{full_path}"
      end

      fetch(:shared_paths, []).each do |path|
        full_path = File.join(shared_path, path)
        parent_dir = File.dirname(full_path)

        if /^n$/ =~ capture("test -e #{parent_dir} && echo 'y' || echo 'n'")
          run "mkdir -p #{parent_dir}"
          logger.info "Created shared '#{parent_dir}'"
        end

        if /^n$/ =~ capture("test -e #{full_path} && echo 'y' || echo 'n'")
          logger.important "Warning: shared '#{path}' is not yet present!"
        end
      end
    end

    before 'deploy:setup', 'ndr_dev_support:pre_setup'
    after  'deploy:setup', 'ndr_dev_support:post_setup'

    desc 'More generic configuration, built on top of target-specific config.'
    task :prepare do
      warn Rainbow('                                                                        ').red.underline
      warn Rainbow('')
      warn Rainbow("Target: #{Rainbow(fetch(:name)).bright.green}")
      warn Rainbow("Branch: #{Rainbow(fetch(:branch)).bright.green} (see config/deployments.yml)")
      warn Rainbow("Ruby:   #{Rainbow(fetch(:ruby)).bright.green}")
      warn Rainbow('')
      warn Rainbow("DBs:    Migrations are not run automatically by capistrano;")
      warn Rainbow("        #{Rainbow('please run any necessary manually before proceeding').underline.bright}.")
      warn Rainbow('                                                                        ').red.underline
      warn Rainbow('')

      # Gather SSH credentials: (password is asked for by Net::SSH, if needed)
      set :use_sudo, false
      set :user, Capistrano::CLI.ui.ask('Deploy as: ')

      # If no alternate user is specified, deploy to the crediental-holding user.
      set :application_user, fetch(:user) unless fetch(:application_user)

      # The home folder of the application user:
      set :application_home, File.join('/home', fetch(:application_user))

      # The deploying user will need to be a member of the application user's group,
      # as well as being a member of the "deployer" group:
      set :application_group, fetch(:application_user)

      # Where we'll be deploying to:
      set :deploy_to, File.join(application_home, fetch(:application))

      # Use the application user's ruby:
      set(:default_environment) do
        {
          'PATH'       => "#{application_home}/.rbenv/shims:#{application_home}/.rbenv/bin:$PATH",
          'RBENV_ROOT' => "#{application_home}/.rbenv"
        }
      end

      # Set a flag so behaviour can toggle in mixed use cases
      set(:ndr_model_deployment, true)
    end

    after 'deploy:update', 'deploy:cleanup' # Keep only 5 deployments

    desc 'Symlink to the release any :shared_paths, ensure private/ is writeable'
    task :filesystem_tweaks do
      # This task binds after a standard capistrano step, so we need to be careful:
      next unless ndr_model_deployment

      # Make the private/ directory in the release writeable to the application user:
      private_directory = File.join(release_path, 'private')
      run "mkdir -p #{private_directory} && chgrp #{fetch(:application_group)} #{private_directory} && chmod g+s #{private_directory}"

      fetch(:shared_paths, []).each do |path|
        # Symlink `path` from the shared space to the release being prepared, replacing anything
        # already there:
        run "rm -rf #{File.join(release_path, path)} && ln -s #{File.join(shared_path, path)} #{File.join(release_path, path)}"
      end
    end

    after 'deploy:finalize_update', 'ndr_dev_support:filesystem_tweaks'
  end
end

def release_config_for(env)
  branches = YAML.load_file('config/deployments.yml')
  branches.fetch(env.to_s) { raise 'Unknown release branch!' }
end

def target_ruby_version_for(env)
  raw   = release_config_for(env).fetch('ruby')
  match = raw.match(/\A(?<version>\d+\.\d+\.\d+)\z/)

  match ? match[:version] : raise('Unrecognized Ruby version!')
end

def add_target(env, name, app, port, app_user, is_web_server)
  desc "Deploy to #{env} service #{app_user || 'you'}@#{app}:#{port}"
  task(name) do
    set :name, name

    set :application_user, app_user

    role :app, app
    set :port, port

    set :webapp_deployment, is_web_server
    set :daemon_deployment, !is_web_server

    set :branch, release_config_for(env).fetch('branch')
    if exists?(:repository_branches)
      set :repository, fetch(:repository_branches) + fetch(:branch)
    end

    # Extract Ruby configuration if available:
    ruby_version = target_ruby_version_for(env)
    set :ruby, ruby_version if ruby_version
  end
  after name, 'ndr_dev_support:prepare'
end
