Capistrano::Configuration.instance(:must_exist).load do
  namespace :ndr_dev_support do
    desc <<~DESC
      Ensure that the required ruby version is installed.

      An offline copy of rbenv should be placed in /opt/rbenv.tar.gz
      To make this file, for ruby 3.1.6, run the following commands:
      $ mkdir clone_rbenv
      $ git clone https://github.com/rbenv/rbenv.git clone_rbenv/.rbenv
      $ git clone https://github.com/rbenv/ruby-build.git clone_rbenv/.rbenv/plugins/ruby-build
      $ mkdir clone_rbenv/.rbenv/cache
      $ (cd clone_rbenv/.rbenv/cache; curl -O https://cache.ruby-lang.org/pub/ruby/3.1/ruby-3.1.6.tar.gz)
      $ (cd clone_rbenv; rm -f ../rbenv.tar.gz; tar czf ../rbenv.tar.gz .rbenv)
      $ rm -rf clone_rbenv
      $ scp -p rbenv.tar.gz app-server:/opt/rbenv.tar.gz
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
      #
      # We remove ~/.rbenv paths from capistrano-defined PATH when running `rbenv init`
      # so that it knows the path is needed in ~/.bash_profile
      run <<~SHELL
        set -e;
        if ! rbenv versions --bare 2> /dev/null | grep -qF #{version}; then
          echo Installing ruby #{version};
          { while true; do sleep 20; echo -n '.'; done & } 2> /dev/null;
          sudo -i -n -u #{fetch(:application_user)} sh -c "
            if [ ! -e .rbenv ] && [ -e /opt/rbenv.tar.gz ]; then
              tar xf /opt/rbenv.tar.gz .rbenv;
              PATH=\\`echo \\"\\$PATH\\"|sed -e \\"s_[^:=]*/[.]rbenv[^:]*:__g\\"\\` .rbenv/bin/rbenv init bash;
            fi;
            eval \\"\\$(.rbenv/bin/rbenv init - --no-rehash bash)\\";
            export TMPDIR=\\`mktemp -d \\"\\$HOME\\"/rbenv_tmp_XXXX\\`;
            set +e;
            rbenv install #{version} --skip-existing 2>&1;
            set -e;
            RBENV_VERSION=#{version} ruby --version;
            rm -rf \\"\\`printenv TMPDIR\\`\\";
            rbenv global #{version};
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
  end

  before 'bundle:install', 'ndr_dev_support:install_ruby'
end
