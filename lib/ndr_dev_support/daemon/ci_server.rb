require 'English'
require_relative 'stoppable'
require 'open3'
require 'rugged'
require 'shellwords'
require 'with_clean_rbenv'

module NdrDevSupport
  module Daemon
    # Wrapper around Rake based CI testing loop
    class CIServer
      include Stoppable

      GIT_SVN_REMOTE_BRANCH_NAME = 'git-svn'.freeze
      MASTER_BRANCH_NAME = 'master'.freeze
      ORIGIN_MASTER_BRANCH_NAME = 'origin/master'.freeze

      attr_reader :repo

      def self.from_args(env)
        name = env['WORKER_NAME'].to_s

        new(name: name)
      end

      def initialize(name:)
        super

        # Worker name can be used for clear logging:
        @name = name
        raise ArgumentError, 'No WORKER_NAME specified!' if name.blank?

        @repo = Rugged::Repository.new('.')
      end

      def self.friendly_revision_name(commit)
        if (matchdata = commit.message.match(/\bgit-svn-id: [^@]+@(\d+)\s/))
          matchdata[1]
        else
          commit.oid[0, 7]
        end
      end

      private

      def run_once
        log('running once...')

        git_fetch
        git_discard_changes
        git_checkout(MASTER_BRANCH_NAME)

        objectids_between_master_and_remote.each do |oid|
          if should_skip?(oid)
            log("skipping #{oid}")
            next
          end

          log("testing #{oid}...")
          git_discard_changes
          git_rebase(oid)

          WithCleanRbenv.with_clean_rbenv do
            # TODO: rbenv_install
            bundle_install
            system('rbenv exec bundle exec rake ci:all --trace')
          end
        end

        log('completed single run.')
      rescue => exception
        log(<<~MSG)
          Unhandled exception! #{exception.class}: #{exception.message}
          #{(exception.backtrace || []).join("\n")}
        MSG

        raise exception
      end

      def git_fetch
        system(svn_remote? ? 'git svn fetch' : 'git fetch')
      end

      def git_checkout(oid)
        Open3.popen3('git', 'checkout', oid) do |_stdin, _stdout, stderr, wait_thr|
          msg = stderr.read.strip
          log(msg) unless msg == "Already on '#{oid}'"

          process_status = wait_thr.value
          raise msg unless process_status.exited?
        end
      end

      def git_rebase(oid)
        system("git rebase #{Shellwords.escape(oid)}") || raise('Unable to rebase!')
      end

      def git_discard_changes
        # git clean would remove all unstaged files
        stash_output = `git stash`
        return if stash_output.start_with?('No local changes to save')
        `git stash drop stash@{0}`
      end

      # Skips over commits tagged with:
      #   [ci skip]
      #   [ci-skip]
      #   [CI-SKIP]
      #   ...etc
      def should_skip?(oid)
        message = `git show -s --format=%B #{Shellwords.escape(oid)}`
        message.match?(/\[ci(-| )skip\]/i)
      end

      def svn_remote?
        GIT_SVN_REMOTE_BRANCH_NAME == remote_branch
      end

      def remote_branch
        return @remote_branch if @remote_branch

        remote_branches = repo.branches.each_name(:remote)
        if remote_branches.count == 1
          @remote_branch = remote_branches.first
        elsif remote_branches.include?(ORIGIN_MASTER_BRANCH_NAME)
          @remote_branch = ORIGIN_MASTER_BRANCH_NAME
        else
          raise "One remote branch expected (#{remote_branches.to_a.inspect})"
        end
      end

      def objectids_between_master_and_remote
        walker = Rugged::Walker.new(@repo)
        walker.push(repo.branches[remote_branch].target_id)
        current_target_id = repo.branches[MASTER_BRANCH_NAME].target_id

        revisions = []
        # walk backwards from the most recent commit, breaking at the current one
        walker.each do |commit|
          break if commit.oid == current_target_id
          revisions << commit.oid
        end

        revisions.reverse
      end

      def bundle_install
        return unless File.file?('Gemfile')
        return if system('bundle check')

        system('rbenv exec bundle install --local --jobs=3')
        return if $CHILD_STATUS.exitstatus.zero? || ENV['SLACK_WEBHOOK_URL'].nil?

        slack_publisher = NdrDevSupport::SlackMessagePublisher.new(ENV['SLACK_WEBHOOK_URL'],
                                                                   username: 'Rake CI',
                                                                   icon_emoji: ':robot_face:',
                                                                   channel: ENV['SLACK_CHANNEL'])

        attachment = {
          color: 'danger',
          fallback: 'Failure running bundle install --local',
          text: 'Failure running `bundle install --local`',
          footer: 'bundle exec rake ci:bundle_install'
        }

        slack_publisher.post(attachments: [attachment])

        raise 'Failure running `bundle install --local`'
      end
    end
  end
end
