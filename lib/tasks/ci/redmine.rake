namespace :ci do
  namespace :redmine do
    desc 'Set up Redmine'
    task :setup do
      ENV['REDMINE_HOSTNAME'] ||= ask('Redmine URL: ')
      ENV['REDMINE_HOSTNAME'] = nil if ENV['REDMINE_HOSTNAME'] == ''

      ENV['REDMINE_API_KEY'] ||= ask('Redmine API Key: ') { |q| q.echo = '*' }
      ENV['REDMINE_API_KEY'] = nil if ENV['REDMINE_API_KEY'] == ''
    end
  end

  namespace :redmine do
    desc 'Update Redmine tickets'
    task update_tickets: ['ci:rugged:setup', 'ci:redmine:setup'] do
      api_key = ENV['REDMINE_API_KEY']
      hostname = ENV['REDMINE_HOSTNAME']
      next if api_key.nil? || hostname.nil?

      require 'ndr_dev_support/rake_ci/redmine/ticket_resolver'

      ticket_resolver = NdrDevSupport::RakeCI::Redmine::TicketResolver.new(api_key, hostname)
      ticket_resolver.process_commit(@commit.author[:name],
                                     @friendly_revision_name,
                                     @commit.message)
    end
  end
end
