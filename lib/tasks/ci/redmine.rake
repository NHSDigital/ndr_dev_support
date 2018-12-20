namespace :ci do
  namespace :redmine do
    desc 'Set up Redmine'
    task :setup do
      require 'highline/import'

      ENV['REDMINE_HOSTNAME'] ||= ask('Redmine URL: ')
      ENV['REDMINE_HOSTNAME'] = nil if ENV['REDMINE_HOSTNAME'] == ''

      ENV['REDMINE_API_KEY'] ||= ask('Redmine API Key: ') { |q| q.echo = '*' }
      ENV['REDMINE_API_KEY'] = nil if ENV['REDMINE_API_KEY'] == ''
    end

    desc 'Update Redmine tickets'
    task update_tickets: ['ci:rugged:setup', 'ci:redmine:setup'] do
      api_key = ENV['REDMINE_API_KEY']
      hostname = ENV['REDMINE_HOSTNAME']
      next if api_key.nil? || hostname.nil?

      require 'ndr_dev_support/rake_ci/redmine/ticket_resolver'

      ticket_resolver = NdrDevSupport::RakeCI::Redmine::TicketResolver.new(api_key, hostname)
      resolved_tickets = ticket_resolver.process_commit(@commit.author[:name],
                                                        @friendly_revision_name,
                                                        @commit.message)

      next if resolved_tickets.empty?
      resolved_tickets.map! { |ticket_id| "https://#{hostname}/issues/#{ticket_id}" }

      issue_s = resolved_tickets.count == 1 ? 'issue' : 'issues'
      attachment = {
        color: 'good',
        title: "#{issue_s.capitalize} Resolved",
        text: "Tests pass, so #{issue_s} #{resolved_tickets.join(', ')}" \
              " #{resolved_tickets.count == 1 ? 'has' : 'have'} been resolved",
        footer: 'bundle exec rake ci:minitest',
        mrkdwn_in: ['text']
      }
      @attachments ||= []
      @attachments << attachment
    end
  end
end
