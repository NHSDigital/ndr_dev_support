require 'tmpdir'

# Add a git or svn secrets respository for ndr_dev_support:deploy_secrets
def add_secrets_repo(name:, url:, scm:, branch: nil)
  raise "Invalid repo name #{name}" unless /\A[A-Z0-9_-]+\z/i.match?(name)
  raise "Unknown scm #{scm}" unless %w[svn git].include?(scm)
  raise "Expected branch for repo #{name}" if scm == 'git' && branch.to_s.empty?

  secrets_repositories = fetch(:secrets_repositories, {})
  secrets_repositories[name] = { url: url, scm: scm, branch: branch }
  set :secrets_repositories, secrets_repositories
end

# Add a secret to be deployed by ndr_dev_support:deploy_secrets
def add_secret(repo:, repo_path:, shared_dest:)
  secrets = fetch(:secrets, [])
  raise "Unknown repo #{repo}" unless fetch(:secrets_repositories, {}).key?(repo)

  secrets << { repo: repo, repo_path: repo_path, shared_dest: shared_dest }
  set :secrets, secrets
end

Capistrano::Configuration.instance(:must_exist).load do
  namespace :ndr_dev_support do
    desc <<~DESC
      Deploy updated application secrets to shared folders on application servers

      To use this in a project, add something like the code below to your
      Capistrano file config/deploy.rb, then run:
      $ cap target app:update_secrets

      namespace :app do
        desc 'Update application secrets'
        task :update_secrets do
          add_secrets_repo(name: 'userlists',
                           url: 'https://github.com/example/users.git',
                           branch: 'main',
                           scm: 'git')
          add_secrets_repo(name: 'encrypted_credentials_store',
                           url: 'https://svn-server.example.org/svn/creds', scm: 'svn')

          add_secret(repo: 'encrypted_credentials_store',
                     repo_path: 'path/to/credentials.yml.enc',
                     shared_dest: 'config/credentials.yml.enc')
          add_secret(repo: 'userlists',
                     repo_path: 'config/userlist.yml',
                     shared_dest: 'config/userlist.yml')
        end
      end
      after 'app:update_secrets', 'ndr_dev_support:deploy_secrets'
    DESC
    task :deploy_secrets do
      # List of repositories used for secrets
      secrets_repositories = fetch(:secrets_repositories, {})
      secrets = fetch(:secrets, [])
      secrets_repo_base = Pathname.new('tmp/deployment-secrets')

      if secrets.empty?
        Capistrano::CLI.ui.say 'Warning: No secret files configured to upload'
        next
      end

      # Allow quick indexing by filename
      secrets_map = secrets.to_h { |secret| [secret[:shared_dest], secret] } # rubocop:disable Rails/IndexBy
      changed = [] # List of changed files updated
      Dir.mktmpdir do |secret_dir|
        # Clone git secrets repositories if required
        used_repos = secrets.collect { |secret| secret[:repo] }.uniq
        repo_dirs = {}
        used_repos.each do |repo|
          repository = secrets_repositories[repo]
          next unless repository[:scm] == 'git'

          repo_dir = Pathname.new(secrets_repo_base).join(".git-#{repo}").to_s
          if File.directory?(repo_dir)
            ok = system("cd #{Shellwords.escape(repo_dir)} && git fetch")
            raise "Error: cannot fetch secrets repository #{repo}: aborting" unless ok
          else
            ok = system('git', 'clone', '--mirror', '--filter=blob:none', repository[:url], repo_dir)
            raise "Error: cannot clone secrets repository #{repo}: aborting" unless ok
          end
          repo_dirs[repo] = repo_dir
        end

        # Set up a temporary secrets directory of exported secrets,
        # creating nested structure if necessary
        secrets_map.each_value do |secret|
          repo = secret[:repo]
          repository = secrets_repositories[repo]
          raise "Unknown repository #{secret[:repo]}" unless repository

          repo_root = repository[:url]
          raise 'Unknown / unsupported repository' unless repo_root&.start_with?('https://')

          dest_fname = File.join(secret_dir, secret[:shared_dest])
          dest_dir = File.dirname(dest_fname)
          FileUtils.mkdir_p(dest_dir)
          case repository[:scm]
          when 'git'
            repo_dir = Pathname.new(secrets_repo_base).join(".git-#{repo}").to_s
            ok = system("GIT_DIR=#{Shellwords.escape(repo_dir)} git archive --format=tar " \
                        "#{Shellwords.escape(repository[:branch])} " \
                        "#{Shellwords.escape(secret[:repo_path])} | " \
                        "tar x -Ps %#{Shellwords.escape(secret[:repo_path])}%" \
                        "#{Shellwords.escape(File.join(secret_dir, secret[:shared_dest]))}% " \
                        "#{Shellwords.escape(secret[:repo_path])}")
          when 'svn'
            ok = system('svn', 'export', '--quiet', "#{repo_root}/#{secret[:repo_path]}",
                        File.join(secret_dir, secret[:shared_dest]))
            # TODO: use --non-interactive, and then run again interactively if there's an eror
          else
            raise "Error: unsupported scm #{repository[:scm]}"
          end

          raise 'Error: cannot export secrets files: aborting' unless ok

          secret[:digest] = Digest::SHA256.file(dest_fname).hexdigest
        end

        # Retrieve digests of secrets from application server
        escaped_fnames = secrets_map.keys.collect { |fname| Shellwords.escape(fname) }
        capture("cd #{shared_path.shellescape}; " \
                "sha256sum #{escaped_fnames.join(' ')} || true").split("\n").each do |digest_line|
          match = digest_line.match(/([0-9a-f]{64}) [ *](.*)/)
          raise "Invalid digest returned: #{digest_line}" unless match && secrets_map.key?(match[2])

          secrets_map[match[2]][:server_digest] = match[1]
        end

        # Upload replacements for all changed files
        secrets_map.each_value do |secret|
          if secret[:digest] == secret[:server_digest]
            # Capistrano::CLI.ui.say "Unchanged secret: #{secret[:shared_dest]}"
            next
          end

          Capistrano::CLI.ui.say "Uploading changed secret file: #{secret[:shared_dest]}"
          changed << secret[:shared_dest]
          # Capistrano does an in-place overwrite of the file, so use a temporary name,
          # then move it into place
          temp_dest = capture("mktemp -p #{shared_path.shellescape}").chomp
          dest_fname = File.join(secret_dir, secret[:shared_dest])
          put File.read(dest_fname), temp_dest
          escape_shared_dest = Shellwords.escape(secret[:shared_dest])
          escape_temp_dest = Shellwords.escape(temp_dest)
          capture("cd #{shared_path.shellescape}; " \
                  "chmod 664 #{escape_temp_dest}; " \
                  "if [ -e #{escape_shared_dest} ]; then cp -p #{escape_shared_dest}{,.orig}; fi; " \
                  "mv #{escape_temp_dest} #{escape_shared_dest}")
        end
      end

      if changed.empty?
        Capistrano::CLI.ui.say 'No changed secret files to upload'
      else
        Capistrano::CLI.ui.say "Uploaded #{changed.size} changed secret files: #{changed.join(', ')}"
      end
      # TODO: Support logging of changes, so that a calling script can report changes

      # TODO: maintain a per-target local cache of latest revisions uploaded / file checksums
      # then we don't need to re-connect to the remote servers, if nothing changed,
      # We could also then only need to do "svn ls" instead of "svn export"

      # TODO: Warn if some repos are inaccessible?
      # TODO: Add notes for passwordless SSH deployment, using ssh-agent
    end
  end
end
