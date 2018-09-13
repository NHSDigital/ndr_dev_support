Capistrano::Configuration.instance(:must_exist).load do
  namespace :deploy do
    desc 'Trigger application to restart'
    task :restart do
      # The tmp/ directory should be shared, so this affects all prior deployments
      run "touch #{shared_path}/tmp/restart.txt"
    end
  end
end
