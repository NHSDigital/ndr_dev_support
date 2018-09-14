Capistrano::Configuration.instance(:must_exist).load do
  namespace :ndr_dev_support do
    desc "Refresh the start/stop scripts in the app user's $HOME directory"
    task :refresh_sysadmin_scripts, except: { no_release: true } do
      # This is desirable, but opt-in, behaviour:
      if fetch(:synchronise_sysadmin_scripts, false)
        type    = fetch(:daemon_deployment) ? 'god' : 'server'
        scripts = %W(start_#{type}.sh stop_#{type}_gracefully.sh)

        scripts.each do |script|
          source  = File.join(release_path, 'script', "#{script}.sample")
          dest    = File.join(fetch(:application_home), script)

          # Ensure the script is pre-existing, with the correct permissions (should be writeable
          # by deployers, but only runnable by the application user, to prevent the wrong user
          # attempting to start the processes.)
          run "test -w #{dest}"                              # Should exist and be writeable
          run "test -e #{source} && cat #{source} > #{dest}" # Replace without changing permissions
        end
      end
    end
  end

  after 'deploy:update_code', 'ndr_dev_support:refresh_sysadmin_scripts'
end
