require 'pathname'
require 'yaml'

SAFETY_FILE =
  if File.exist?('code_safety.yml')
    Pathname.new('code_safety.yml').expand_path
  elsif defined?(Rails)
    Rails.root.join('config', 'code_safety.yml')
  else
    Pathname.new('code_safety.yml').expand_path
  end

# Temporary overrides to only audit external access files
SAFETY_REPOS = [['/svn/era', '/svn/extra/era/external-access']]

# Parameter max_print is number of entries to print before truncating output
# (negative value => print all)
def audit_code_safety(max_print = 20, ignore_new = false, show_diffs = false, show_in_priority = false, user_name = 'usr')
  puts 'Running source code safety audit script.'
  puts

  max_print = 1_000_000 if max_print < 0
  safety_cfg = File.exist?(SAFETY_FILE) ? YAML.load_file(SAFETY_FILE) : {}
  file_safety = safety_cfg['file safety']
  if file_safety.nil?
    puts "Creating new 'file safety' block in #{SAFETY_FILE}"
    safety_cfg['file safety'] = file_safety = {}
  end
  file_safety.each do |_k, v|
    rev = v['safe_revision']
    v['safe_revision'] = rev.to_s if rev.is_a?(Integer)
  end
  orig_count = file_safety.size

  safety_repo = trunk_repo = get_trunk_repo

  # TODO: below is broken for git-svn
  # Is it needed?

  SAFETY_REPOS.each do |suffix, alt|
    # Temporarily override to only audit a different file list
    if safety_repo.end_with?(suffix)
      safety_repo = safety_repo[0...-suffix.length] + alt
      break
    end
  end

  if ignore_new
    puts "Not checking for new files in #{safety_repo}"
  else
    puts "Checking for new files in #{safety_repo}"
    new_files = get_new_files(safety_repo)
    # Ignore subdirectories, and exclude code_safety.yml by default.
    new_files.delete_if { |f| f =~ /[\/\\]$/ || Pathname.new(f).expand_path == SAFETY_FILE }
    new_files.each do |f|
      next if file_safety.key?(f)
      file_safety[f] = {
        'comments' => nil,
        'reviewed_by' => nil,
        'safe_revision' => nil }
    end
    File.open(SAFETY_FILE, 'w') do |file|
      # Consistent file diffs, as ruby preserves Hash insertion order since v1.9
      safety_cfg['file safety'] = Hash[file_safety.sort]
      YAML.dump(safety_cfg, file) # Save changes before checking latest revisions
    end
  end
  puts "Updating latest revisions for #{file_safety.size} files"
  set_last_changed_revision(trunk_repo, file_safety, file_safety.keys)
  puts "\nSummary:"
  puts "Number of files originally in #{SAFETY_FILE}: #{orig_count}"
  puts "Number of new files added: #{file_safety.size - orig_count}"

  # Now generate statistics:
  unknown = file_safety.values.select { |x| x['safe_revision'].nil? }
  unsafe = file_safety.values.select do |x|
    !x['safe_revision'].nil? && x['safe_revision'] != -1 &&
    x['last_changed_rev'] != x['safe_revision'] &&
    !(x['last_changed_rev'] =~ /^[0-9]+$/ && x['safe_revision'] =~ /^[0-9]+$/ &&
      x['last_changed_rev'].to_i < x['safe_revision'].to_i)
  end
  puts "Number of files with no safe version: #{unknown.size}"
  puts "Number of files which are no longer safe: #{unsafe.size}"
  puts
  printed = []
  file_list = sorted_file_list(file_safety, show_in_priority)

  # We also print a third category: ones which are no longer in the repository
  file_list.each do |f|
    if print_file_safety(file_safety, trunk_repo, f, false, printed.size >= max_print)
      printed << f
    end
  end
  puts "... and #{printed.size - max_print} others" if printed.size > max_print
  if show_diffs
    puts
    printed.each do |f|
      print_file_diffs(file_safety, trunk_repo, f, user_name)
    end
  end

  # Returns `true` unless there are pending reviews:
  unsafe.length.zero? && unknown.length.zero?
end

def sorted_file_list(file_safety, show_in_priority)
  if show_in_priority
    pairs = file_safety.sort_by do |path, info|
      # Sort using derived ordering, then alphabetically
      [priority_ordering_for(path, info), path]
    end

    pairs.map(&:first)
  else
    file_safety.keys.sort
  end
end

# Returns an orderable value for `path`, so that reviews
# can be performed in order of priority. For a file that has
# not been reviewed as safe
def priority_ordering_for(path, info)
  if info['safe_revision'].nil?
    initial_ordering_for(path)
  else
    reviewed_ordering_for(path, info)
  end
end

# Returns for `path` a value which allows paths to
# be sorted chronologically by their creation date
def initial_ordering_for(path)
  case repository_type
  when 'svn'
    %x[svn log -r 1:HEAD --limit 1 -q "#{path}" | grep -v '^-' | cut -d' ' -f1 | tr -d 'r'].to_i
  when 'git-svn'
    # TODO: there seems to be a bug in git-svn's --oneline implmentation:
    #       $ git svn --version #=> git-svn version 2.9.0 (svn 1.9.4)
    #       It truncates revisions that are longer than the first revision it prints.
    #
    #       I think the below would work around the issue, although I don't believe we're
    #       actually affected; we only ever care about the first revision printed anyway.
    #
    #       %x[git svn log --reverse "#{path}" | grep -E '^-+$' -A1 | grep -v '^-' | \
    #          cut -d'|' -f1 | tr -d 'r'].to_i
    #
    #       We do care more in #reviewed_ordering_for, though, as for that we're interested
    #       in the subsequent file to affect the `path`.
    #
    %x[git svn log --oneline --reverse --limit 1 "#{path}" | cut -d'|' -f1 | tr -d 'r'].to_i
  when 'git'
    # Get full SHA of first commit, and then count parent commits from there:
    %x[git log --format=%H --reverse -- "#{path}" | head -1 | xargs git rev-list --count].to_i
  else
    0
  end
end

# Returns for `path` a value which allows paths to be sorted chronologically by the
# date which they were first changed after they were last reviewed and marked as safe.
def reviewed_ordering_for(path, info)
  case repository_type
  when 'svn'
    # Get the quiet log of first commit after the safe_revision that modified `path`,
    # and extract from that the revision number:
    %x[svn log -r #{info['safe_revision'].to_i + 1}:HEAD --limit 1 -q "#{path}" | \
       grep -v '^-' | cut -d' ' -f1 | tr -d 'r'].to_i
  when 'git-svn'
    # Pull out commit history for path in chronological order, filter to lines
    # matching revisions, file the line matching the known safe revision, then
    # extract the next revision (er, yuk?):
    %x[git svn log --reverse "#{path}" | grep -E '^-+$' -A1 | grep -v '^-' | \
       grep '^r#{info['safe_revision']}' -A1 | tail -1 | cut -d'|' -f1 | tr -d 'r'].to_i
  when 'git'
    # Find first commit (chronologically) in the safe_revision..HEAD range that modifies
    # `path`, then count reachable parents from there. In the case that there was no commit
    # in the range, returns the ordering for the safe revision instead.
    %x[git log --format=%H --reverse #{info['safe_revision']}^..HEAD -- "#{path}" | \
       head -2 | tail -1 | xargs git rev-list --count].to_i
  else
    0
  end
end

# Print summary details of a file's known safety
# If not verbose, only prints details for unsafe files
# Returns true if anything printed (or would have been printed if silent),
# or false otherwise.
def print_file_safety(file_safety, repo, fname, verbose = false, silent = false)
  msg = "#{fname}\n  "
  entry = file_safety[fname]
  msg += 'File not in audit list' if entry.nil?

  if entry['safe_revision'].nil?
    msg += 'No safe revision known'
    msg += ", last changed #{entry['last_changed_rev']}" unless entry['last_changed_rev'].nil?
  else
    repolatest = entry['last_changed_rev'] # May have been prepopulated en mass
    msg += 'Not in repository: ' if entry['last_changed_rev'] == -1
    if (repolatest != entry['safe_revision']) &&
       !(repolatest =~ /^[0-9]+$/ && entry['safe_revision'] =~ /^[0-9]+$/ &&
         repolatest.to_i < entry['safe_revision'].to_i)
      # (Allow later revisions to be treated as safe for svn)
      msg += "No longer safe since revision #{repolatest}: "
    else
      return false unless verbose
      msg += 'Safe: '
    end
    msg += "revision #{entry['safe_revision']} reviewed by #{entry['reviewed_by']}"
  end
  msg += "\n  Comments: #{entry['comments']}" if entry['comments']
  puts msg unless silent
  true
end

def flag_file_as_safe(release, reviewed_by, comments, f)
  safety_cfg = YAML.load_file(SAFETY_FILE)
  file_safety = safety_cfg['file safety']

  unless File.exist?(f)
    abort("Error: Unable to flag non-existent file as safe: #{f}")
  end
  unless file_safety.key?(f)
    file_safety[f] = {
      'comments' => nil,
      'reviewed_by' => :dummy, # dummy value, will be overwritten
      'safe_revision' => nil }
  end
  entry = file_safety[f]
  entry_orig = entry.dup
  if comments.to_s.length > 0 && entry['comments'] != comments
    entry['comments'] = if entry['comments'].to_s.empty?
                          comments
                        else
                          "#{entry['comments']}#{'.' unless entry['comments'].end_with?('.')} Revision #{release}: #{comments}"
                        end
  end
  if entry['safe_revision']
    unless release
      abort("Error: File already has safe revision #{entry['safe_revision']}: #{f}")
    end
    if release.is_a?(Integer) && release < entry['safe_revision']
      puts("Warning: Rolling back safe revision from #{entry['safe_revision']} to #{release} for #{f}")
    end
  end
  entry['safe_revision'] = release
  entry['reviewed_by'] = reviewed_by
  if entry == entry_orig
    puts "No changes when updating safe_revision to #{release || '[none]'} for #{f}"
  else
    File.open(SAFETY_FILE, 'w') do |file|
      # Consistent file diffs, as ruby preserves Hash insertion order since v1.9
      safety_cfg['file safety'] = Hash[file_safety.sort]
      YAML.dump(safety_cfg, file) # Save changes before checking latest revisions
    end
    puts "Updated safe_revision to #{release || '[none]'} for #{f}"
  end
end

# Determine the type of repository
def repository_type
  @repository_type ||= if Dir.exist?('.svn') || system("svn info . > /dev/null 2>&1")
                         'svn'
                       elsif Dir.exist?('.git') && open('.git/config').grep(/svn/).any?
                         'git-svn' 
                       elsif Dir.exist?('.git') && open('.git/config').grep(/git/).any?
                         'git'
                       else
                         'not known'
                       end
end

def get_trunk_repo
  case repository_type
  when 'svn'
    repo_info = %x[svn info]
    puts 'svn case'
    return repo_info.split("\n").select { |x| x =~ /^URL: / }.collect { |x| x[5..-1] }.first
  when 'git-svn'
    puts 'git-svn case'
    repo_info = %x[git svn info]
    return repo_info.split("\n").select { |x| x =~ /^URL: / }.collect { |x| x[5..-1] }.first
  when 'git'
    puts 'git case'
    repo_info = %x[git remote -v]
    return repo_info.split("\n").first[7..-9]
  else
    return 'Information not available. Unknown repository type'
  end
end

def get_new_files(safety_repo)
  case repository_type
  when 'svn', 'git-svn'
    %x[svn ls -R "#{safety_repo}"].split("\n")
  when 'git'
    #%x[git ls-files --modified].split("\n")
    %x[git ls-files].split("\n")

    # TODO: Below is for remote repository - for testing use local files
    #new_files = %x[git ls-files --modified #{safety_repo}].split("\n")
    # TODO: Do we need the --modified option?
    #new_files = %x[git ls-files --modified].split("\n")
  else
    []
  end
end

# Fill in the latest changed revisions in a file safety map.
# (Don't write this data to the YAML file, as it is intrinsic to the SVN
# repository.)
def set_last_changed_revision(repo, file_safety, fnames)
  dot_freq = (file_safety.size / 40.0).ceil # Print up to 40 progress dots
  case repository_type
  when 'git'
    fnames = file_safety.keys if fnames.nil?

    fnames.each_with_index do |f, i|
      info = %x[git log -n 1 #{f}].split("\n").first[7..-1]
      if info.nil? || info.empty?
        file_safety[f]['last_changed_rev'] = -1
      else
        file_safety[f]['last_changed_rev'] = info
      end
      # Show progress
      print '.' if (i % dot_freq) == 0
    end
    puts
  when 'git-svn', 'svn'
    fnames = file_safety.keys if fnames.nil?

    fnames.each_with_index do |f, i|
      last_revision = get_last_changed_revision(repo, f)
      if last_revision.nil? || last_revision.empty?
        file_safety[f]['last_changed_rev'] = -1
      else
        file_safety[f]['last_changed_rev'] = last_revision
      end
      # Show progress
      print '.' if (i % dot_freq) == 0
    end
    puts
    # NOTE: Do we need the following for retries?
#     if retries && result.size != fnames.size && fnames.size > 1
#        # At least one invalid (deleted file --> subsequent arguments ignored)
#        # Try each file individually
#        # (It would probably be safe to continue from the extra_info.size argument)
#        puts "Retrying (got #{result.size}, expected #{fnames.size})" if debug >= 2
#        result = []
#        fnames.each{ |f|
#           result += svn_info_entries([f], repo, false, debug)
#        }
#      end
  end
end

# Return the last changed revision
def get_last_changed_revision(repo, fname)
  case repository_type
  when 'git'
    %x[git log -n 1 "#{fname}"].split("\n").first[7..-1]
  when 'git-svn', 'svn'
    begin
      svn_info = %x[svn info -r head "#{repo}/#{fname}"]
    rescue
      puts 'we have an error in the svn info line'
    end
    begin
      svn_info.match('Last Changed Rev: ([0-9]*)').to_a[1]
    rescue
      puts 'We have an error in getting the revision'
    end
  end
end

# Get mime type. Note that Git does not have this information
def get_mime_type(repo, fname)
  case repository_type
  when 'git'
    'Git does not provide mime types'
  when 'git-svn', 'svn'
    %x[svn propget svn:mime-type "#{repo}/#{fname}"].chomp
  end
end

# # Print file diffs, for code review
def print_file_diffs(file_safety, repo, fname, user_name)
  entry = file_safety[fname]
  repolatest = entry['last_changed_rev']
  safe_revision = entry['safe_revision']

  if safe_revision.nil?
    first_revision = set_safe_revision
    print_repo_file_diffs(repolatest, repo, fname, user_name, first_revision)
  else

    rev = get_last_changed_revision(repo, fname)
    if rev
      mime = get_mime_type(repo, fname)
    end

    print_repo_file_diffs(repolatest, repo, fname, user_name, safe_revision) if repolatest != safe_revision
  end
end

# Returns first commit for git and 0 for svn in order to be used to display
# new files. Called from print_file_diffs
def set_safe_revision
  case repository_type
  when 'git'
    %x[git rev-list --max-parents=0 HEAD].chomp
  when 'git-svn', 'svn'
    0
  end
end

def print_repo_file_diffs(repolatest, repo, fname, user_name, safe_revision)
  require 'open3'
  cmd = nil
  case repository_type
  when 'git'
    cmd = ['git', '--no-pager', 'diff', '--color', '-b', "#{safe_revision}..#{repolatest}", fname]
  when 'git-svn', 'svn'
    cmd = ['svn', 'diff', '-r', "#{safe_revision.to_i}:#{repolatest.to_i}", '-x', '-b', "#{repo}/#{fname}"]
  end
  if cmd
    puts(cmd.join(' '))
    stdout_and_err_str, status = Open3.capture2e(*cmd)
    puts(stdout_and_err_str)
  else
    puts 'Unknown repo'
  end

  puts %(To flag the changes to this file as safe, run:)
  puts %(  rake audit:safe release=#{repolatest} file=#{fname} reviewed_by=#{user_name} comments="")
  puts
end

def release_valid?(release)
  case repository_type
  when 'svn', 'git-svn'
    release =~ /\A[0-9][0-9]*\Z/
  when 'git'
    release =~ /\A[0-9a-f]{40}\Z/
  else
    false
  end
end

def get_release
  release = ENV['release']
  release = nil if release == '0'
  case repository_type
  when 'svn', 'git-svn'
    release.to_i
  when 'git'
    release
  else
    ''
  end
  release
end

def clean_working_copy?
 case repository_type
 when 'svn'
   system('svn status | grep -q [^AMCDG]')
 when 'git', 'git-svn'
   system('git diff --quiet HEAD')
 end
end

namespace :audit do
  desc "Audit safety of source code.
Usage: audit:code [max_print=n] [ignore_new=false|true] [show_diffs=false|true] [reviewed_by=usr]

File #{SAFETY_FILE} lists the safety and revision information
of the era source code. This task updates the list, and [TODO] warns about
files which have changed since they were last verified as safe."
  task(:code) do
    puts 'Usage: audit:code [max_print=n] [ignore_new=false|true] [show_diffs=false|true] [show_in_priority=false|true] [reviewed_by=usr]'
    puts "This is a #{repository_type} repository"

    ignore_new = (ENV['ignore_new'].to_s =~ /\Atrue\Z/i)
    show_diffs = (ENV['show_diffs'].to_s =~ /\Atrue\Z/i)
    show_in_priority = (ENV['show_in_priority'].to_s =~ /\Atrue\Z/i)
    max_print = ENV['max_print'] =~ /\A-?[0-9][0-9]*\Z/ ? ENV['max_print'].to_i : 20
    reviewer  = ENV['reviewed_by']

    all_safe = audit_code_safety(max_print, ignore_new, show_diffs, show_in_priority, reviewer)

    unless show_diffs
      puts 'To show file diffs, run:  rake audit:code max_print=-1 show_diffs=true'
    end

    exit(1) unless all_safe
  end

  desc "Flag a source file as safe.

Usage:
  Flag as safe:   rake audit:safe release=revision reviewed_by=usr [comments=...] file=f
  Needs review:   rake audit:safe release=0 [comments=...] file=f"
  task(:safe) do
    release = get_release

    required_fields = %w(release file)
    required_fields << 'reviewed_by' if release # 'Needs review' doesn't need a reviewer
    missing = required_fields.collect { |f| (f if ENV[f].to_s.empty? || (f == 'reviewed_by' && ENV[f] == 'usr')) }.compact # Avoid accidental missing username
    unless missing.empty?
      puts 'Usage: rake audit:safe release=revision reviewed_by=usr [comments=...] file=f'
      puts 'or, to flag a file for review: rake audit:safe release=0 [comments=...] file=f'
      abort("Error: Missing required argument(s): #{missing.join(', ')}")
    end

    unless release.nil? || release_valid?(release)
      puts 'Usage: rake audit:safe release=revision reviewed_by=usr [comments=...] file=f'
      puts 'or, to flag a file for review: rake audit:safe release=0 [comments=...] file=f'
      abort("Error: Invalid release: #{ENV['release']}")
    end

    flag_file_as_safe(release, ENV['reviewed_by'], ENV['comments'], ENV['file'])
  end

  desc 'Wraps audit:code, and stops if any review is pending/stale.'
  task(:ensure_safe) do
    abort('You have local changes, cannot verify code safety!') unless clean_working_copy?

    puts 'Checking code safety...'

    begin
      begin
        $stdout = $stderr = StringIO.new
        Rake::Task['audit:code'].invoke
      ensure
        $stdout, $stderr = STDOUT, STDERR
      end
    rescue SystemExit => ex
      puts '=============================================================='
      puts 'Code safety review of some files are not up-to-date; aborting!'
      puts '  - to review the files in question, run:  rake audit:code'
      puts '=============================================================='

      raise ex
    end
  end
end

# Prevent building of un-reviewed gems:
task build: :'audit:ensure_safe'

