Capistrano::Configuration.instance(:must_exist).load do
  namespace :ndr_dev_support do
    desc 'Append to the log of deployments the user and revision.'
    task :log_deployment, except: { no_release: true } do
      log_deployment_message("deployed #{latest_revision}")
    end
  end

  after 'deploy:update_code', 'ndr_dev_support:log_deployment'
end
