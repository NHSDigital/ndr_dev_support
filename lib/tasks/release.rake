namespace :ndr_dev_support do
  namespace :gem do
    desc 'Quits if the current version has already been tagged.'
    task :exit_if_already_released do
      gemspec_path = Dir['{,*}.gemspec'].first
      raise 'No gemspec found!' unless gemspec_path

      gemspec = Bundler.load_gemspec(gemspec_path)
      release_tag = "v#{gemspec.version}"

      existing_tags = `git tag`
      raise 'Error getting git tags!' if $?.exitstatus > 0

      if existing_tags.split("\n").include?(release_tag)
        puts "The tag for the release (#{release_tag}) already exists; nothing to do!"
        exit 0
      end
    end
  end
end

# `audit:ensure_safe` is our legacy code review process, a precursor to a PR-based
# workflow with branch-protection. We continue to use this for the time being.
# This prevents bundler from building gems if there are outstanding code reviews to be done.
#
# When doing a build/release, don't bother if the version has already been tagged.
# This allows a CD pipeline to conditionally build/release when run against every commit,
# without needing to rely on existing tags (which are harder to protect).
desc <<~DESC
  NdrDevSupport prevents building/releasing if either:
    * legacy code review fails
    * the release has already been tagged (for CD)
DESC
task build: [
  'audit:ensure_safe',
  'ndr_dev_support:gem:exit_if_already_released'
]
