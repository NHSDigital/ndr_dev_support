namespace :cd do
  desc 'Run Capistrano Continuous Deployment credentials server'
  task :credentials do
    require 'ndr_dev_support/daemon/cd_credentials'

    worker = NdrDevSupport::Daemon::CDCredentials.from_args(ENV)
    worker.run
  end
end
