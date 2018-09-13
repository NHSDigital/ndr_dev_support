Capistrano::Configuration.instance(:must_exist).load do
  namespace :ndr_dev_support do
    desc 'Creates a .ruby-version file for this release'
    task :set_ruby_version, except: { no_release: true } do
      run "cd #{release_path} && echo #{fetch(:ruby)} > .ruby-version"
    end
  end

  before 'bundle:install', 'ndr_dev_support:set_ruby_version'
end
