# A rake task to update the bundled version of a gem

# Assumes constant SAFETY_FILE and function repository_type are defined in another rake task.

namespace :bundle do
  desc <<~USAGE
    Update to a later version of a gem interactively.

    Usage: bundle:update gem=rails [version=6.0.4.7]

    Updates the bundled gem (e.g. rails) version to e.g. 6.0.4.7
    and provides instructions for committing changes.
    It will attempt to modify a hardcoded version in the Gemfile if necessary.

    If a secondary Gemfile is present in the same directory, e.g. Gemfile.monterey,
    and it defines constants such as BUNDLER_OVERRIDE_PUMA=true, then this task
    will attempt to update the secondary lock file, e.g. Gemfile.monterey.lock too.
  USAGE
  task(:update) do
    unless %w[git git-svn].include?(repository_type)
      warn 'Error: Requires a git working copy. Aborting.'
      exit 1
    end

    gem = ENV['gem']
    if gem.blank? || gem !~ /\A[a-zA-Z0-9_.-]+\z/
      warn "Error: missing or invalid required 'gem' parameter. Aborting.\n\n"
      system('rake -D bundle:update')
      exit 1
    end

    gem_list = Bundler.with_unbundled_env { `bundle exec gem list ^#{gem}$` }
    # Needs to match e.g. "nokogiri (1.12.5 x86_64-darwin)"
    old_gem_version = gem_list.match(/ \(([0-9.]+)( [a-z0-9_-]*)?\)$/).to_a[1]
    unless old_gem_version
      warn <<~MSG.chomp
        Cannot determine gem version for gem=#{gem}. Aborting. Output from bundle exec gem list:
        #{gem_list}
      MSG
      exit 1
    end
    puts "Old #{gem} version from bundle: #{old_gem_version}"

    new_gem_version = ENV['version'].presence
    if new_gem_version && new_gem_version !~ /\A[0-9.a-zA-Z-]+\z/
      warn "Error: invalid 'version' parameter. Aborting.\n\n"
      system('rake -D bundle:update')
      exit 1
    end

    unless Bundler.with_unbundled_env { system('bundle check 2> /dev/null') }
      warn('Error: bundle check fails before doing anything.')
      warn('Please clean up the Gemfile before running this. Aborting.')
      exit 1
    end

    if gem == 'rails'
      # If updating Rails and using activemodel-caution, prompt to put
      # activemodel-caution gem in place, unless it's already installed for this rails version.
      activemodel_caution = Bundler.
                            with_unbundled_env { `bundle exec gem list activemodel-caution` }.
                            match?(/^activemodel-caution \([0-9.]+\)$/)
      if activemodel_caution && new_gem_version
        file_pattern = "activemodel-caution-#{new_gem_version}*.gem"
        unless Dir.glob("vendor/cache/#{file_pattern}").any? ||
               Bundler.with_unbundled_env do
                 `gem list ^activemodel-caution$ -i -v #{new_gem_version}`
               end.match?(/^true$/)
          warn("Error: missing #{file_pattern} file in vendor/cache")
          warn('Copy this file to vendor/cache, then run this command again.')
          exit 1
        end
      end
    end

    related_gems = if gem == 'rails'
                     gem_list2 = Bundler.with_unbundled_env do
                       `bundle exec gem list`
                     end
                     gem_list2.split("\n").
                       grep(/[ (]#{old_gem_version}(.0)*[,)]/).
                       collect { |row| row.split.first }
                   else
                     [gem]
                   end
    puts "Gems to update: #{related_gems.join(' ')}"

    if new_gem_version
      puts 'Tweaking Gemfile for new gem version'
      cmd = ['sed', '-i', '.bak', '-E']
      related_gems.each do |rgem|
        cmd += ['-e', "s/(gem '(#{rgem})', '(~> )?)#{old_gem_version}(')/\\1#{new_gem_version}\\4/"]
      end
      cmd += %w[Gemfile]
      system(*cmd)
      File.delete('Gemfile.bak')

      system('git diff Gemfile')
    end

    cmd = "bundle update --conservative --minor #{related_gems.join(' ')}"
    puts "Running: #{cmd}"
    Bundler.with_unbundled_env do
      system(cmd)
    end

    unless Bundler.with_unbundled_env { system('bundle check 2> /dev/null') }
      warn <<~MSG
        Error: bundle check fails after trying to update Rails version. Aborting.
        You will need to check your working copy, especially Gemfile, Gemfile.lock, vendor/cache
      MSG
      exit 1
    end

    gem_list = Bundler.with_unbundled_env { `bundle exec gem list ^#{gem}$` }
    new_gem_version2 = gem_list.match(/ \(([0-9.]+)( [a-z0-9_-]*)?\)$/).to_a[1]

    # Update secondary Gemfile.lock to keep vendored gems in sync
    secondary_gemfiles = `git ls-tree --name-only HEAD Gemfile.*`.split("\n").grep_v(/[.]lock$/)
    secondary_gemfiles.each do |secondary_gemfile|
      gem_re = /^BUNDLER_OVERRIDE_([^ =]*) *=/
      secondary_gems = File.readlines(secondary_gemfile).grep(gem_re).
                       collect { |s| gem_re.match(s)[1].downcase }
      if secondary_gems.empty?
        puts "Warning: cannot update #{secondary_gemfile}.lock - no BUNDLER_OVERRIDE_... entries"
        next
      end
      puts "Updating #{secondary_gemfile}.lock"
      FileUtils.cp('Gemfile.lock', "#{secondary_gemfile}.lock")
      Bundler.with_unbundled_env do
        system("BUNDLE_GEMFILE=#{secondary_gemfile} bundle update --quiet \
                --conservative --minor #{secondary_gems.join(' ')}")
      end
      system('git checkout -q vendor/cache/')
      system('git clean -q -f vendor/cache')
      Bundler.with_unbundled_env { system('bundle install --local --quiet 2> /dev/null') }
      puts "Finished updating #{secondary_gemfile}.lock"
    end

    # Retrieve binary gems for platforms listed in Gemfile.lock
    platforms = `bundle platform`.split("\n").grep(/^[*] x86_64-/).collect { |s| s[2..] }
    Dir.chdir('vendor/cache') do
      platforms.each do |platform|
        system("gem fetch #{gem} --version=#{new_gem_version2} --platform=#{platform}")
      end
    end if Dir.exist?('vendor/cache')

    if gem == 'webpacker'
      puts 'TODO: update package.json and yarn.lock with bin/rails webpacker:install'
      puts '      and git add / git remove files in vendor/npm-packages-offline-cache'
    end

    if File.exist?(SAFETY_FILE)
      # Remove references to unused files in code_safety.yml
      system('rake audit:tidy_code_safety_file')
    end

    if new_gem_version && new_gem_version != new_gem_version2
      puts <<~MSG
        Error: Tried to update gem #{gem} to version #{new_gem_version} but ended up at version #{new_gem_version2}. Aborting.
        You will need to check your working copy, especially Gemfile, Gemfile.lock, vendor/cache
        Try running:
           bundle exec rake bundle:update gem=#{gem} version=#{new_gem_version2}
      MSG
      exit 1
    end

    # At this point, we have successfully updated all the local files.
    # All that remains is to set up a branch, if necessary, and inform the user what to commit.

    puts "Looking for changed files using git status\n\n"
    files_to_git_rm = `git status vendor/cache/|grep 'deleted: ' | \
                       grep -o ': .*' | sed -e 's/^: *//'`.split("\n")
    secondary_lockfiles = secondary_gemfiles.collect { |s| "#{s}.lock" }
    files_to_git_add = `git status Gemfile Gemfile.lock #{secondary_gemfiles.join(' ')} \
                          #{secondary_lockfiles.join(' ')} code_safety.yml config/code_safety.yml| \
                        grep 'modified: ' | \
                        grep -o ': .*' | sed -e 's/^: *//'`.split("\n")
    files_to_git_add += `git status vendor/cache|expand|grep '^\s*vendor/cache' | \
                         sed -e 's/^ *//'`.split("\n")

    if files_to_git_rm.empty? && files_to_git_add.empty?
      puts <<~MSG
        No changes were made. Please manually update the Gemfile, run
          bundle update --conservative --minor #{related_gems.join(' ')}
      MSG
      puts '  rake audit:tidy_code_safety_file' if File.exist?(SAFETY_FILE)
      puts <<~MSG
        then run tests and git rm / git add any changes
        including vendor/cache Gemfile Gemfile.lock code_safety.yml
        then git commit
      MSG
      exit
    end

    if repository_type == 'git'
      # Check out a fresh branch, if a git working copy (but not git-svn)
      branch_name = "feature/#{gem}_#{new_gem_version2.gsub('.', '_')}"
      system('git', 'checkout', '-b', branch_name) # Create a new git branch
    end

    puts <<~MSG
      Gemfile updated. Please use "git status" and "git diff" to check the local changes,
      manually add any additional platform-specific gems required (e.g. for nokogiri),
      re-run tests locally, then run the following to commit the changes:

      $ git rm #{files_to_git_rm.join(' ')}
      $ git add #{files_to_git_add.join(' ')}
      $ git commit -m '# Bump #{gem} to #{new_gem_version2}'
    MSG
  end
end
