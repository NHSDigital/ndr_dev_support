Capistrano::Configuration.instance(:must_exist).load do
  namespace :ndr_dev_support do
    desc 'Append to the log of deployments the user and revision.'
    task :log_deployment, except: { no_release: true } do
      name = fetch(:deployer_name, capture('id -un'))
      log  = File.join(shared_path, 'revisions.log')
      msg  = "[#{Time.now}] #{name} deployed #{latest_revision}"

      run "(test -e #{log} || (touch #{log} && chmod 664 #{log})) && echo #{msg} >> #{log};"
    end
  end

  after 'deploy:update_code', 'ndr_dev_support:log_deployment'
end
