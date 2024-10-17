require 'csv'
require 'pathname'
require 'yaml'
require 'shellwords'

SAFETY_FILE =
  if File.exist?('code_safety.yml')
    Pathname.new('code_safety.yml').expand_path
  elsif defined?(Rails)
    Rails.root.join('config', 'code_safety.yml')
  else
    Pathname.new('code_safety.yml').expand_path
  end

# Returns the (Bundler aware) rake command
def rake_cmd
  ENV['BUNDLE_BIN_PATH'] ? 'bundle exec rake' : 'rake'
end

def load_file_safety
  safety_cfg = File.exist?(SAFETY_FILE) ? YAML.load_file(SAFETY_FILE) : {}
  file_safety = safety_cfg['file safety']
  if file_safety.nil?
    puts "Creating new 'file safety' block in #{SAFETY_FILE}"
    file_safety = {}
  end
  file_safety
end

def update_safety_file(file_safety)
  File.open(SAFETY_FILE, 'w') do |file|
    # Consistent file diffs, as ruby preserves Hash insertion order since v1.9
    list = {}
    list['file safety'] = file_safety.sort.to_h
    # Remove inconsistent whitespace which old libyaml version introduces at the ends of lines
    # https://github.com/yaml/libyaml/issues/46
    yaml = YAML.dump(list).gsub(/^( *[a-z_]*:) $/, '\1')
    yaml = YAML.dump(list) unless YAML.safe_load(yaml) == list
    file << yaml # Save changes before checking latest revisions
  end
end

def add_new_file_to_file_safety(file_safety, f)
  return if file_safety.key?(f)
  file_safety[f] = {
    'comments' => nil,
    'reviewed_by' => nil,
    'safe_revision' => nil
  }
end

# Parameter max_print is number of entries to print before truncating output
# (negative value => print all)
def audit_code_safety(max_print = 20, ignore_new = false, show_diffs = false, usr = 'usr', interactive = false, outfile = nil, filter = nil)
  max_print = 1_000_000 if max_print.negative?
  show_diffs = true if interactive
  ignore_new = true if filter

  file_safety = load_file_safety
  file_safety.each_value do |v|
    rev = v['safe_revision']
    v['safe_revision'] = rev.to_s if rev.is_a?(Integer)
  end
  orig_count = file_safety.size

  safety_repo = trunk_repo = get_trunk_repo

  if ignore_new
    puts "Not checking for new files in #{safety_repo}"
  else
    puts "Checking for new files in #{safety_repo}"
    add_new_files(safety_repo, file_safety)
  end

  missing_files = file_safety.keys.reject { |path| File.file?(path) }
  abort(<<~MESSAGE) if missing_files.any?

    The following file(s) no longer exist in the repository:
      #{missing_files.join("\n  ")}

    Please run `#{rake_cmd} audit:tidy_code_safety_file` to remove them.
  MESSAGE

  if filter
    filter_file_safety(file_safety, filter)
    puts "Applying provided file filter: #{file_safety.size} file(s) remain"
  end

  if interactive
    run_review_wizard(trunk_repo, file_safety, usr)

    # Post-wizard, reload the results and continue to print a summary:
    file_safety = load_file_safety
    filter_file_safety(file_safety, filter) if filter

    max_print = 0
    show_diffs = false
  else
    # Get updates for all files in one go:
    puts "Updating latest revisions for #{file_safety.size} files"
    set_last_changed_revisions(trunk_repo, file_safety)
  end

  print_summary(file_safety, usr, trunk_repo, max_print, show_diffs, orig_count, ignore_new, outfile, filter)
end

def filter_file_safety(file_safety, filter)
  filtered_paths = CSV.read(filter, headers: true).map { |row| row.to_h.fetch('path') }
  file_safety.select! { |fname, _entry| filtered_paths.include?(fname) }
end

def run_review_wizard(trunk_repo, file_safety, usr)
  puts <<~INTRO

    In interactive mode, you'll be presented with one diff at a time for review.

    For each diff, you can enter a decision (if you can make one) along with
    any comments you may have, before being taken to the next diff.

  INTRO

  file_safety.each_key do |fname|
    set_last_changed_revision(trunk_repo, file_safety, fname)
    next unless print_file_safety(file_safety, fname, false, true)

    print_file_diffs(file_safety, trunk_repo, fname, usr, true)
  end
end

def print_summary(file_safety, usr, trunk_repo, max_print, show_diffs, orig_count, ignore_new, outfile, filter)
  puts "\nSummary:"
  puts "Number of files originally in #{SAFETY_FILE}: #{orig_count}"
  puts "Number of new files added: #{file_safety.size - orig_count}" unless ignore_new

  # Now generate statistics:
  unknown = file_safety.values.select { |x| unreviewed?(x) }
  unsafe = file_safety.values.select { |x| stale_review?(x) }
  puts "Number of#{' filtered' if filter} files with no safe version: #{unknown.size}"
  puts "Number of#{' filtered' if filter} files which are no longer safe: #{unsafe.size}"
  puts
  printed = []

  file_list =
      file_safety.
      sort_by { |_k, v| v.nil? ? -100 : v['last_changed_rev'].to_i }.
      map(&:first)

  file_list.each do |f|
    printed << f if print_file_safety(file_safety, f, false, printed.size >= max_print)
  end
  puts "... and #{printed.size - max_print} others" if printed.size > max_print && max_print > 0
  if show_diffs
    puts
    printed.each do |f|
      print_file_diffs(file_safety, trunk_repo, f, usr, false)
    end
  end

  export_csv(trunk_repo, file_safety, printed, outfile) if outfile

  # Returns `true` unless there are pending reviews:
  unsafe.length.zero? && unknown.length.zero?
end

def export_csv(repo, file_safety, printed, outfile)
  CSV.open(outfile, 'w') do |csv|
    csv << %w[path last_changed_revision safe_revision diff_lines]

    file_safety.each do |fname, entry|
      # Only emit files needing review:
      next unless printed.include?(fname)

      last_changed_revision = entry['last_changed_rev']
      safe_revision = entry['safe_revision']

      _cmd, diffs = capture_file_diffs(repo, fname, safe_revision, last_changed_revision)
      diff_lines = diffs.force_encoding('BINARY').split("\n").length

      csv << [fname, last_changed_revision, safe_revision, diff_lines]
    end
  end

  puts <<~MESSAGE

    CSV output exported to: #{outfile}

  MESSAGE
end

def stale_review?(entry)
  return false if unreviewed?(entry)

  # Could be comparing Git SHAs, or SVN revisions:
  entry['last_changed_rev'] != entry['safe_revision']
end

def unreviewed?(entry)
  entry['safe_revision'].nil?
end

def needs_review?(entry)
  unreviewed?(entry) || stale_review?(entry)
end

# Print summary details of a file's known safety
# If not verbose, only prints details for unsafe files
# Returns true if anything printed (or would have been printed if silent),
# or false otherwise.
def print_file_safety(file_safety, fname, verbose = false, silent = false)
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
  abort("Error: Unable to flag non-existent file as safe: #{f}") unless File.exist?(f)
  file_safety = load_file_safety
  add_new_file_to_file_safety(file_safety, f)
  entry = file_safety[f]
  entry_orig = entry.dup
  if !comments.to_s.empty? && entry['comments'] != comments
    entry['comments'] = if entry['comments'].to_s.empty?
                          comments
                        else
                          "#{entry['comments']}#{'.' unless entry['comments'].end_with?('.')} Revision #{release}: #{comments}"
                        end
  end
  if entry['safe_revision']
    abort("Error: File already has safe revision #{entry['safe_revision']}: #{f}") unless release
    if release.is_a?(Integer) && release < entry['safe_revision']
      puts("Warning: Rolling back safe revision from #{entry['safe_revision']} to #{release} for #{f}")
    end
  end
  entry['safe_revision'] = release
  entry['reviewed_by'] = reviewed_by
  if entry == entry_orig
    puts "No changes when updating safe_revision to #{release || '[none]'} for #{f}"
  else
    update_safety_file(file_safety)
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
    repo_info.split("\n").select { |x| x =~ /^URL: / }.collect { |x| x[5..-1] }.first
  when 'git-svn'
    repo_info = %x[git svn info]
    repo_info.split("\n").select { |x| x =~ /^URL: / }.collect { |x| x[5..-1] }.first
  when 'git'
    repo_info = %x[git remote -v]
    repo_info.split("\n").first[7..-9]
  else
    'Information not available. Unknown repository type'
  end
end

def add_new_files(safety_repo, file_safety)
  new_files =
    case repository_type
    when 'svn', 'git-svn'
      %x[svn ls -R "#{safety_repo}"].split("\n")
    when 'git'
      %x[git ls-files].split("\n")
    else
      []
    end

  # Ignore subdirectories, and exclude code_safety.yml by default.
  new_files.delete_if { |f| f =~ /[\/\\]$/ || Pathname.new(f).expand_path == SAFETY_FILE }

  # Save changes before checking latest revisions
  new_files.each { |f| add_new_file_to_file_safety(file_safety, f) }
  update_safety_file(file_safety)
end

# Fill in the latest changed revisions in a file safety map.
# (Don't write this data to the YAML file, as it is intrinsic to the SVN
# repository.)
def set_last_changed_revisions(repo, file_safety)
  fnames = file_safety.keys
  dot_freq = (fnames.size / 40.0).ceil # Print up to 40 progress dots

  fnames.each_with_index do |f, i|
    set_last_changed_revision(repo, file_safety, f)
    print '.' if (i % dot_freq) == 0
  end
  puts
end

# Fill in the latest changed revision for the given file in a file safety map.
def set_last_changed_revision(repo, file_safety, fname)
  last_revision = get_last_changed_revision(repo, fname)
  last_revision = -1 if last_revision.blank?

  file_safety[fname]['last_changed_rev'] = last_revision
end

# Return the last changed revision
def get_last_changed_revision(repo, fname)
  case repository_type
  when 'git'
    %x[git log -n 1 -- "#{fname}"].split("\n").first[7..-1]
  when 'git-svn', 'svn'
    begin
      dest = "#{repo}/#{fname}@"
      svn_info = %x[svn info -r head #{Shellwords.escape(dest)}]
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

# # Print file diffs, for code review
def print_file_diffs(file_safety, repo, fname, usr, interactive)
  entry = file_safety[fname]
  repolatest = entry['last_changed_rev']
  safe_revision = entry['safe_revision']

  return unless safe_revision.nil? || repolatest != safe_revision
  safe_revision ||= root_revision
  print_repo_file_diffs(repolatest, repo, fname, usr, safe_revision, interactive)
end

# Returns first commit for git and 0 for svn in order to be used to display
# new files. Called from print_file_diffs
def root_revision
  case repository_type
  when 'git'
    `git rev-list --max-parents=0 HEAD`.chomp
  when 'git-svn', 'svn'
    0
  end
end

def capture_file_diffs(repo, fname, safe_revision, repolatest)
  cmd =
    case repository_type
    when 'git'
      ['git', '--no-pager', 'diff', '--color', '-b', "#{safe_revision}..#{repolatest}", fname]
    when 'git-svn', 'svn'
      ['svn', 'diff', '-r', "#{safe_revision.to_i}:#{repolatest.to_i}", '-x', '-b',
       "#{repo}/#{fname}@"]
    end

  stdout_and_err_str, _status = Open3.capture2e(*cmd)

  if stdout_and_err_str.start_with?('fatal: Invalid revision range ')
    abort <<~ERROR
      Error running:
        #{cmd}

      Invalid commit ID in code_safety.yml for #{fname}? (#{safe_revision})
    ERROR
  end

  [cmd.join(' '), stdout_and_err_str]
end

def print_repo_file_diffs(repolatest, repo, fname, usr, safe_revision, interactive)
  require 'open3'
  require 'highline/import'

  if interactive
    ask("<%= color('Press Enter to continue ...', :yellow) %>")
    system('clear')
    system("printf '\033[3J'") # clear the scrollback
  end

  cmd, diffs = capture_file_diffs(repo, fname, safe_revision, repolatest)
  puts cmd
  puts
  puts diffs
  puts

  if interactive
    response = ask("Flag #{fname} changes safe? [Yes|No|Abort]: ") { |q| q.case = :down }
    if %w[yes y].include?(response)
      puts 'Flagging as safe...'
      release = get_release(repolatest)
      if usr.to_s.strip.empty?
        usr = ask('File reviewed by: ') do |q|
          q.whitespace = :strip_and_collapse
          q.validate = /\A[\w \-.]+\z/
        end
      end
      comment = ask('Please write your comments (optional): ')
      # use to_s to convert response from !ruby/string:HighLine::String to String
      flag_file_as_safe(release, usr.to_s, comment.to_s, fname)
    elsif response =~ /\Aa/i
      say("\n<%= color('Aborted by user.', :red) %>")
      abort
    else
      say("\n<%= color('Skipping review of #{fname}.', :magenta) %>")
    end
  else
    puts 'To flag the changes to this file as safe, run:'
    puts "  #{rake_cmd} audit:safe release=#{repolatest} file=#{fname} reviewed_by=#{usr}" \
         ' comments=""'
  end
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

def get_release(release = nil)
  release ||= ENV['release']
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

def remove_non_existent_files_from_code_safety
  file_safety = load_file_safety
  files_no_longer_in_repo = file_safety.keys.reject { |ff| File.file?(ff) }
  files_no_longer_in_repo.each do |f|
    puts 'No longer in repository ' + f
    file_safety.delete f
  end
  update_safety_file(file_safety)
end

namespace :audit do
  desc "Audit safety of source code.
Usage: audit:code [max_print=n] [ignore_new=false|true] [show_diffs=false|true] [reviewed_by=usr] [interactive=false|true]

File #{SAFETY_FILE} lists the safety and revision information
of the era source code. This task updates the list, and [TODO] warns about
files which have changed since they were last verified as safe."
  task(:code) do
    puts <<~USAGE

      NDR's code auditing tool.

      Usage:

        #{rake_cmd} audit:code
          [interactive=false|true]      # use an interactive wizard to perform code review
          [max_print=n]                 # limit the number of summary rows to n
          [ignore_new=false|true]       # don't add new files to code_safety.yml
          [show_diffs=false|true]       # display the full diff for each file
          [reviewed_by=usr]             # your name, to author to any reviews added
          [filter=path/to/input.csv]    # filter reviewing to only files specified in the filter file
          [outfile=path/to/output.csv]  # dump a summary of outstanding review to CSV

    USAGE

    puts "This is a #{repository_type} repository."
    puts

    ignore_new = (ENV['ignore_new'].to_s =~ /\Atrue\Z/i)
    show_diffs = (ENV['show_diffs'].to_s =~ /\Atrue\Z/i)
    max_print = ENV['max_print'] =~ /\A-?[0-9][0-9]*\Z/ ? ENV['max_print'].to_i : 20
    reviewer  = ENV['reviewed_by']
    interactive = (ENV['interactive'].to_s =~ /\Atrue\Z/i)
    filter = ENV['filter']
    outfile = ENV['outfile']

    all_safe = audit_code_safety(max_print, ignore_new, show_diffs, reviewer, interactive, outfile, filter)

    unless show_diffs || interactive
      puts "To show file diffs, run:  #{rake_cmd} audit:code max_print=-1 show_diffs=true"
    end

    exit(1) unless all_safe
  end

  desc "Flag a source file as safe.
Usage:
  Flag as safe:   #{rake_cmd} audit:safe release=revision reviewed_by=usr [comments=...] file=f
  Needs review:   #{rake_cmd} audit:safe release=0 [comments=...] file=f"
  task(:safe) do
    release = get_release

    required_fields = %w(release file)
    required_fields << 'reviewed_by' if release # 'Needs review' doesn't need a reviewer
    missing = required_fields.collect { |f| (f if ENV[f].to_s.empty? || (f == 'reviewed_by' && ENV[f] == 'usr')) }.compact # Avoid accidental missing username
    unless missing.empty?
      puts "Usage: #{rake_cmd} audit:safe release=revision reviewed_by=usr [comments=...] file=f"
      puts "or, to flag a file for review: #{rake_cmd} audit:safe release=0 [comments=...] file=f"
      abort("Error: Missing required argument(s): #{missing.join(', ')}")
    end

    unless release.nil? || release_valid?(release)
      puts "Usage: #{rake_cmd} audit:safe release=revision reviewed_by=usr [comments=...] file=f"
      puts "or, to flag a file for review: #{rake_cmd} audit:safe release=0 [comments=...] file=f"
      abort("Error: Invalid release: #{ENV['release']}")
    end

    flag_file_as_safe(release, ENV['reviewed_by'], ENV['comments'], ENV['file'])
  end

  desc 'Deletes any files from code_safety.yml that are no longer in repository.'
  task(:tidy_code_safety_file) do
    puts 'Checking code safety for missing files...'

    remove_non_existent_files_from_code_safety
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
      puts "  - to review the files in question, run:  #{rake_cmd} audit:code"
      puts '=============================================================='

      raise ex
    end
  end
end
