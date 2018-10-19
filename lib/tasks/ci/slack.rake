namespace :ci do
  namespace :slack do
    desc 'Set up Slack'
    task :setup do
      require 'highline/import'
      @attachments = []

      ENV['SLACK_WEBHOOK_URL'] ||= ask('Slack Webhook URL: ')
      ENV['SLACK_WEBHOOK_URL'] = nil if ENV['SLACK_WEBHOOK_URL'] == ''

      ENV['SLACK_CHANNEL'] ||= ask('Slack Channel: ')
      ENV['SLACK_CHANNEL'] = nil if ENV['SLACK_CHANNEL'] == ''
    end

    desc 'publish'
    task publish: :setup do
      next if @attachments.empty? || ENV['SLACK_WEBHOOK_URL'].nil?

      require 'ndr_dev_support/slack_message_publisher'

      # We have attachments so prepend them with basic commit details
      Rake::Task['ci:rugged:commit_details'].invoke

      slack_publisher = NdrDevSupport::SlackMessagePublisher.new(ENV['SLACK_WEBHOOK_URL'],
                                                                 username: 'Rake CI',
                                                                 icon_emoji: ':robot_face:',
                                                                 channel: ENV['SLACK_CHANNEL'])
      slack_publisher.post(attachments: @attachments)
    end
  end
end
