require 'json'
require 'net/http'

module NdrDevSupport
  module RakeCI
    module Redmine
      # This class encapsulates Redmine ticket logic
      class TicketResolver
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

        def initialize(api_key, hostname)
          @headers = {
            'X-Redmine-API-Key' => api_key,
            'Content-Type'      => 'application/json'
          }
          @hostname = hostname
        end

        def process_commit(user, revision, message, tests_passed)
          resolved_tickets = []

          each_ticket_from(message) do |ticket, resolved|
            update_ticket(message, user, revision, ticket, resolved, tests_passed)

            resolved_tickets << ticket if resolved && tests_passed
          end

          resolved_tickets
        end

        def each_ticket_from(message, &block)
          return enum_for(:each_ticket_from, message) unless block

          key_words     = message.scan(MEGA_REGEX).flatten.compact
          action_groups = key_words.slice_when { |_l, r| r.to_i.to_s != r }.to_a

          action_groups.each do |group|
            resolved = group.any? { |word| word =~ CLOSE_REGEX }
            tickets  = group.select { |word| word.to_i.to_s == word }.uniq

            tickets.each { |ticket| yield(ticket, resolved) }
          end
        end

        def update_payload(message, user, revision, ticket_closed, resolved, tests_passed)
          if resolved && !ticket_closed && !tests_passed
            message += "\n\n*Automated tests did not pass successfully, so ticket status left unchanged.*"
          end

          payload = {
            notes: "_#{resolved ? 'Resolved' : 'Referenced'} by #{user} in #{revision}_:" \
                   "#{resolved ? message.gsub(CLOSE_REGEX, '+\1+') : message}"
          }

          payload[:status_id] = 3 if resolved && !ticket_closed && tests_passed
          payload
        end

        private

        # Connect lazily
        def http
          return @http if @http
          @http = Net::HTTP.new(@hostname, 443)
          @http.use_ssl = true
          @http
        end

        def update_ticket(message, user, revision, ticket, resolved)
          payload = update_payload(message, user, revision, ticket_closed?(ticket), resolved, tests_passed)

          http.send_request('PUT',
                            "/issues/#{ticket.to_i}.json",
                            JSON.dump(issue: payload),
                            @headers)
        end

        def ticket_closed?(ticket)
          response = http.send_request('GET', "/issues/#{ticket.to_i}.json", nil, @headers)
          JSON.parse(response.body)['issue']['status']['id'] == 5
        end
      end
    end
  end
end
