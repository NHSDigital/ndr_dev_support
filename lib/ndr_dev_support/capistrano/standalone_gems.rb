require_relative 'ruby_version'

Capistrano::Configuration.instance(:must_exist).load do
  namespace :ndr_dev_support do
    desc 'Ensure gems outside the bundle are up to date'
    task :update_out_of_bundle_gems, except: { no_release: true } do
      # You can seed this list in your configuration with something like:
      #
      #   before 'ndr_dev_support:update_out_of_bundle_gems' do
      #     set :out_of_bundle_gems, webapp_deployment ? %w[puma] : %[god]
      #   end
      #
      gem_list = Array(fetch(:out_of_bundle_gems, []))

      # By default, gems are installed using passwordless sudo as the application
      # user; set to false if you want to install gems as the deploying user.
      gem_install =
        if fetch(:out_of_bundle_gems_use_sudo, true)
          "sudo -i -n -u #{fetch(:application_user)} RBENV_VERSION=$RBENV_VERSION gem install"
        else
          'gem install'
        end

      # Extract the current version requirements for each of the gems from the lockfile,
      # and then check they're installed. If not, install them from the vendored cache.
      run <<~CMD if gem_list.any?
        export RBENV_VERSION=`cat "#{latest_release}/.ruby-version"`;
        cat "#{latest_release}/Gemfile.lock" | egrep "^    (#{gem_list.join('|')}) " | tr -d '()' | \
        while read gem ver; do
          gem list -i "$gem" --version "$ver" > /dev/null || \
          #{gem_install} "#{latest_release}/vendor/cache/$gem-$ver.gem" \
            --ignore-dependencies --conservative --no-document;
        done
      CMD
    end
  end

  after 'bundle:install', 'ndr_dev_support:update_out_of_bundle_gems'
end
