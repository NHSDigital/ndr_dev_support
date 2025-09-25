Capistrano::Configuration.instance(:must_exist).load do
  namespace :ndr_dev_support do
    desc <<~DESC
      Ensure that the required ruby version is installed.

      This can be installed from /opt/rbenv.tar.gz (first installation only) or vendor/rbenv/

      To place an offline copy of rbenv in /opt/rbenv.tar.gz
      For ruby 3.1.6, run the following commands:
      $ mkdir clone_rbenv
      $ git clone https://github.com/rbenv/rbenv.git clone_rbenv/.rbenv
      $ git clone https://github.com/rbenv/ruby-build.git clone_rbenv/.rbenv/plugins/ruby-build
      $ mkdir clone_rbenv/.rbenv/cache
      $ (cd clone_rbenv/.rbenv/cache; curl -O https://cache.ruby-lang.org/pub/ruby/3.1/ruby-3.1.6.tar.gz)
      $ (cd clone_rbenv; rm -f ../rbenv.tar.gz; tar czf ../rbenv.tar.gz .rbenv)
      $ rm -rf clone_rbenv
      $ scp -p rbenv.tar.gz app-server:/opt/rbenv.tar.gz

      To add rbenv, ruby-build and additional ruby versions to the application vendor directory
      For ruby 3.2.6:
      $ mkdir clone_rbenv
      $ git clone https://github.com/rbenv/rbenv.git clone_rbenv/.rbenv
      $ mkdir -p vendor/rbenv; rm -f vendor/rbenv/rbenv.tar.gz
      $ tar czf vendor/rbenv/rbenv.tar.gz -C clone_rbenv .rbenv
      $ rm -rf clone_rbenv
      $ mkdir clone_ruby-build
      $ git clone https://github.com/rbenv/ruby-build.git clone_ruby-build/ruby-build
      $ mkdir -p vendor/rbenv/cache; rm -f vendor/rbenv/ruby-build.tar.gz
      $ tar czf vendor/rbenv/ruby-build.tar.gz -C clone_ruby-build ruby-build
      $ rm -rf clone_ruby-build
      $ (cd vendor/rbenv/cache; curl -O https://cache.ruby-lang.org/pub/ruby/3.2/ruby-3.2.6.tar.gz)
      $ git add vendor/rbenv/{rbenv,ruby-build}.tar.gz vendor/rbenv/cache/*
    DESC
    task :install_ruby do
      version = fetch(:ruby)
      # Note that ruby 3.1.x on CentOS 7 generally installs successfully but then reports an error:
      #   ERROR:  While executing gem ... (URI::InvalidURIError)
      #   bad URI(is not URI?): "bundler\r"
      # For this reason, we ignore the exit status, and run our own test.
      #
      # For some reason, SSH keepalive options have no effect with capistrano 2 and net-ssh 7.
      # So we run a poor-man's keepalive, because this installation can take over 10 minutes
      # and some of our SSH servers disconnect inactive sessions after 5 minutes.
      # We have a keepalive time limit of 40 minutes in case the installation fails unexpectedly.
      #
      # We remove ~/.rbenv paths from capistrano-defined PATH when running `rbenv init`
      # so that it knows the path is needed in ~/.bash_profile
      #
      # We use latest_release: this is broadly well-defined, and will point to the in-progress
      # release if we're part way through a deployment, or the most recent release if run
      # after a deployment has happened, or be blank if attempted after cap deploy:setup
      run <<~SHELL
        set -e;
        if ! rbenv versions --bare 2> /dev/null | grep -q ^#{Regexp.escape(version)}$; then
          echo Installing ruby #{version};
          { sleep 10; for i in `seq 1 80`; do echo -n '.'; sleep 30; done & } 2> /dev/null;
          sudo -i -n -u #{fetch(:application_user)} sh -c "
            if [ ! -e .rbenv ] && [ -e /opt/rbenv.tar.gz ]; then
              tar xf /opt/rbenv.tar.gz .rbenv;
              PATH=\\`echo \\"\\$PATH\\"|sed -e \\"s_[^:=]*/[.]rbenv[^:]*:__g\\"\\` .rbenv/bin/rbenv init bash;
            fi;
            if [ ! -e .rbenv ] && [ -f #{latest_release}/vendor/rbenv/rbenv.tar.gz ]; then
              tar xf #{latest_release}/vendor/rbenv/rbenv.tar.gz .rbenv;
              PATH=\\`echo \\"\\$PATH\\"|sed -e \\"s_[^:=]*/[.]rbenv[^:]*:__g\\"\\` .rbenv/bin/rbenv init bash;
            fi;
            if [ ! -e .rbenv ]; then
              echo rbenv not installed: aborting;
            else
              if [ -d #{latest_release}/vendor/rbenv/cache ] && [ -n \\"\\`ls #{latest_release}/vendor/rbenv/cache\\`\\" ]; then
                mkdir -p .rbenv/cache/;
                cp -nvp #{latest_release}/vendor/rbenv/cache/* .rbenv/cache/;
              fi;
              if [ -f #{latest_release}/vendor/rbenv/ruby-build.tar.gz ]; then
                mkdir -p .rbenv/plugins/;
                tar xf #{latest_release}/vendor/rbenv/ruby-build.tar.gz -C .rbenv/plugins/ ruby-build;
              fi;
              eval \\"\\$(.rbenv/bin/rbenv init - --no-rehash bash)\\";
              export TMPDIR=\\`mktemp -d \\"\\$HOME\\"/rbenv_tmp_XXXX\\`;
              if rbenv install #{version} --skip-existing 2>&1; then
                RBENV_VERSION=#{version} ruby --version;
                rm -rf \\"\\`printenv TMPDIR\\`\\";
                rbenv global #{version};
              fi;
            fi;
          ";
          { kill % && wait; } 2> /dev/null;
          set -e;
          if [ "`RBENV_VERSION=#{version} gem list --exact --installed bundler`" == "true" ]; then
            echo 'Please ignore the following error above:';
            echo '> ERROR:  While executing gem ... (URI::InvalidURIError)';
            echo '> bad URI(is not URI?): "bundler\\r"';
            echo Successfully installed ruby #{version};
          else
            echo ERROR: Failure installing ruby #{version}: aborting;
            exit 1;
          fi;
        fi
      SHELL
    end

    desc <<~DESC
      Cleanup bundled gems for old ruby versions.

      Deletes shared bundle files that no longer match any installed releases.

      This interacts reasonably with deploy:preinstall:
      When deploy:preinstall installs new .rbenv and new shared bundled gems, this
      will not delete them. If an older ruby version is then deployed, this removes
      the new version's installed bundle, but leaves the .rbenv installation.
    DESC
    task :cleanup_unused_bundles do
      # For ruby X.Y.Z, bundled gems are in .../shared/bundle/ruby/X.Y.0
      # Generates e.g.
      # find_options="-not ( -name DUMMY -or -name 3.1.0 -or -name 3.2.0 )"
      # and then removes e.g. shared/bundle/ruby/3.0.0
      run "find_options=\"-not ( -name DUMMY `grep -ho '^[0-9]*[.][0-9]*' " \
          "#{releases_path}/*/.ruby-version | sed -e 's/.*/-or -name &.0/'` ) \"; " \
          "find #{File.join(shared_path, 'bundle/ruby/*')} -maxdepth 0 $find_options " \
          "-exec echo rm -rf '{}' ';' -exec rm -rf '{}' ';'"
    end
  end

  before 'bundle:install', 'ndr_dev_support:install_ruby'
  after 'deploy:finalize_update', 'ndr_dev_support:cleanup_unused_bundles'
end
