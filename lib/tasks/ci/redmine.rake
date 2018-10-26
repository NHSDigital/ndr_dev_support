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
      @api_key = ENV['REDMINE_API_KEY']
      @hostname = ENV['REDMINE_HOSTNAME']
      next if @api_key.nil? || @hostname.nil?

      require 'json'
      require 'net/http'

      @http = Net::HTTP.new(@hostname, 443)
      @http.use_ssl = true

      @headers = {
        'X-Redmine-API-Key' => @api_key,
        'Content-Type'      => 'application/json'
      }

      CLOSE_REGEX =
        /
          (
              (?:close[sd]?)    # close, closes, closed
            | (?:resolve[sd]?)  # resolve, resolves, resolved
            | (?:fix(?:e[sd])?) # fix, fixes, fixed
          )
        /ix

      MEGA_REGEX =
        /
            #{CLOSE_REGEX}
          | (relate[sd]\sto)  # relates to, related to
          | (?:
             \[?             # optional square bracket
             \#(\d+)         # ticket number with preceding hash character
             (?:\#note-\d+)? # optional note reference, ignored
             \]?             # optional square bracket
             \b              # word boundary
            )
        /ix

      def each_ticket_from(message)
        key_words     = message.scan(MEGA_REGEX).flatten.compact
        action_groups = key_words.slice_when { |_l, r| r.to_i.to_s != r }.to_a

        action_groups.each do |group|
          resolved = group.any? { |word| word =~ CLOSE_REGEX }
          tickets  = group.select { |word| word.to_i.to_s == word }.uniq

          tickets.each { |ticket| yield(ticket, resolved) }
        end
      end

      def update_ticket(message, user, revision, ticket, resolved)
        payload = { notes: "_#{resolved ? 'Resolved' : 'Referenced'} by #{user} in #{revision}_:" \
                           "\n> #{resolved ? message.gsub(CLOSE_REGEX, '+\1+') : message}" }

        payload[:status_id] = 3 if resolved && !ticket_closed?(ticket)
        @http.send_request('PUT',
                           "/issues/#{ticket.to_i}.json",
                           JSON.dump(issue: payload),
                           @headers)
      end

      def ticket_closed?(ticket)
        response = @http.send_request('GET', "/issues/#{ticket.to_i}.json", nil, @headers)
        JSON.parse(response.body)['issue']['status']['id'] == 5
      end

      def process_commit(user, revision, message)
        each_ticket_from(message) do |ticket, resolved|
          update_ticket(message, user, revision, ticket, resolved)
        end
      end

      process_commit(@commit.author[:name], @friendly_revision_name, @commit.message)
    end
  end
end
