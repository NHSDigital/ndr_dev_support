Capistrano::Configuration.instance(:must_exist).load do
  namespace :deploy do
    desc <<~DESC
      Preinstall ruby and gems, then abort and rollback cleanly, leaving the
      current installation unchanged.

      This is particularly useful for ruby version bumps: installing the new
      ruby version and all the bundled gems can take a long time.

      This aborts before updating out-of-bundle gems, in case that causes
      issues when restarting the currently installed version.

      Usage:
        cap target deploy:preinstall
    DESC
    task :preinstall do
      # Running this task sets a flag, to make ndr_dev_support:check_preinstall abort.
      # We do this in a roundabout way on Capistrano 2, because deploy:update_code
      # explicitly runs deploy:finalize_update, instead of using task dependencies.
      set :preinstall, true
    end
  end

  namespace :ndr_dev_support do
    desc 'Hook to abort capistrano installation early after preinstalling ruby and in-bundle gems'
    task :check_preinstall do
      next unless fetch(:preinstall, false)

      log_deployment_message("preinstalled #{real_revision}")
      warn Rainbow("Successful preinstall for target: #{fetch(:name)}")
      abort 'Aborting after successful preinstall'
    end
  end

  after 'deploy:preinstall', 'deploy:update'
  before 'ndr_dev_support:update_out_of_bundle_gems', 'ndr_dev_support:check_preinstall'
end
