require 'English'
require_relative 'stoppable'
require 'ndr_dev_support/slack_message_publisher'
require 'shellwords'
require 'with_clean_rbenv'

module NdrDevSupport
  module Daemon
    # Wrapper around Capistrano based Continuous Deployment of application credentials
    #
    # Assumes there is a capistrano task "app:update_secrets" which can be used together
    # with a target name, e.g. cap target app:update_secrets
    # to update a capistrano target with secrets / credentials from one or more repositories.
    # To use this daemon, a number of environment variables need to be set
    # including CD_TARGETS and CD_URLS.
    class CDCredentials
      include Stoppable

      def self.from_args(env)
        name = env['WORKER_NAME'].to_s
        cd_targets = env['CD_TARGETS'].to_s.split
        cd_urls = env['CD_URLS'].to_s.split

        new(name: name, cd_targets: cd_targets, cd_urls: cd_urls)
      end

      def initialize(name:, cd_targets:, cd_urls:)
        super

        # Worker name can be used for clear logging:
        @name = name
        raise ArgumentError, 'No WORKER_NAME specified!' if name.blank?

        # Capistrano targets to use for deployments
        @cd_targets = cd_targets
        raise ArgumentError, 'No CD_TARGETS specified!' unless cd_targets&.present?

        # URLs to watch for continuous deployment
        @cd_urls = cd_urls
        raise ArgumentError, 'No CD_URLS specified!' unless cd_urls&.present?
      end

      private

      def run_once
        log('running once...')

        # Keep state, watch repositories for changes, maybe save state to disk?
        if (revisions = check_for_new_revisions)
          log("deploying with revisions #{revisions}...")
          deploy_credentials # should also notify slack if any changes deployed, but not
        else
          log('nothing new to deploy')
        end
        log('completed single run.')
      rescue => e
        log(<<~MSG)
          Unhandled exception! #{e.class}: #{e.message}
          #{(e.backtrace || []).join("\n")}
        MSG

        raise e
      end

      # Check for new revisions, and cache the latest one.
      # If there are new revisions in the repositories available since the last check,
      # return a hash of repo -> latest revision
      # If no revisions have changed, returns nil
      def check_for_new_revisions
        # TODO: implement this, by checking for updates to @cd_urls
        # Stub implementation, pretends things always changed
        { 'dummy_repo' => '0' }
      end

      # Deploy credentials to all targets. Should also notify slack if any changes deployed
      def deploy_credentials
        log("Deploying to #{@cd_targets.join(', ')}...")
        @changed_targets = []
        @unchanged_targets = []
        @failed_targets = []
        @cd_targets.each do |target|
          deploy_to_target(target)
        end
        publish_results
      end

      # Deploy credentials to a single target.
      def deploy_to_target(target)
        WithCleanRbenv.with_clean_rbenv do
          results = `rbenv exec bundle exec cap #{Shellwords.escape(target)} \
                       app:update_secrets < /dev/null`.split("\n")
          puts results
          if $CHILD_STATUS.exitstatus.zero?
            if results.include?('No changed secret files to upload')
              @unchanged_targets << target
              log("Unchanged target #{target}")
            elsif results.grep(/^Uploaded [0-9]+ changed secret files: /).any?
              @changed_targets << target
              log("Changed target #{target}")
            else
              @failed_targets << target
              log("Unparseable result deploying to target #{target}")
            end
          else
            @failed_targets << target
            log("Failed to deploy to target #{target}")
          end
        end
      end

      def publish_results
        slack_publisher = NdrDevSupport::SlackMessagePublisher.new(ENV['SLACK_WEBHOOK_URL'],
                                                                   username: 'Rake CI',
                                                                   icon_emoji: ':robot_face:',
                                                                   channel: ENV['SLACK_CHANNEL'])
        slack_publisher.post(attachments: attachments)
      end

      # Status / warning messages for slack notifications
      def attachments
        attachments = []

        if @failed_targets.any?
          attachment = {
            color: 'danger',
            title: "#{@failed_targets.count} failed credential updates :rotating_light:",
            text: "Failed targets: `#{@failed_targets.join(', ')}`",
            footer: 'bundle exec cap target app:update_secrets',
            mrkdwn_in: ['text']
          }
          attachments << attachment
          puts attachment.inspect
        end

        if @changed_targets.any?
          text = "Changed targets: `#{@changed_targets.join(', ')}`\n"
          text << (if @unchanged_targets.any?
                     "Unchanged targets: `#{@unchanged_targets.join(', ')}`"
                   else
                     'No unchanged targets'
                   end)
          attachment = {
            color: 'good',
            title: "#{@changed_targets.size} successful credential updates",
            text: text,
            footer: 'bundle exec cap target app:update_secrets',
            mrkdwn_in: ['text']
          }
          attachments << attachment
          puts attachment.inspect
        end

        attachments
      end
    end
  end
end
