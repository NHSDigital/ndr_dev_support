Capistrano::Configuration.instance(:must_exist).load do
  namespace :ndr_dev_support do
    desc 'Configure  / precompile assets'
    task :configure_assets do
      asset_script = fetch(:asset_script, <<~SHELL)
        set -e
        ruby -ryaml -e "puts YAML.dump('production' => { 'secret_key_base' => 'compile_me' })" > config/secrets.yml
        RAILS_ENV=production bundle exec rake assets:precompile
        rm config/secrets.yml
      SHELL

      if fetch(:webapp_deployment)
        # Prepend the build script with asset compilation steps:
        set :build_script, asset_script + fetch(:build_script, '')

        # We'll have replaced all the assets if they're needed:
        set :normalize_asset_timestamps, false
      end
    end
  end

  after 'ndr_dev_support:prepare', 'ndr_dev_support:configure_assets'
end
