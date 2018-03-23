module NdrDevSupport
  # This Class publishes messages to Slack
  class SlackMessagePublisher
    def initialize(url, default_options = {})
      @url = url
      @default_options = default_options
    end

    def post(options = {})
      request = json_request
      request.body = message(options)

      use_ssl = request.uri.scheme == 'https'
      http =
        if proxy
          proxy.start(request.uri.host, use_ssl: use_ssl)
        else
          Net::HTTP.start(request.uri.host, request.uri.port, use_ssl: use_ssl)
        end

      http.request(request)
    end

    private

    def json_request
      uri = URI.parse(@url)
      request = Net::HTTP::Post.new(uri)
      # request.basic_auth(*@auth.split(':')) if @auth
      request['Content-Type'] = 'application/json'
      request
    end

    def message(options)
      @default_options.merge(options).to_json
    end

    def proxy
      return @proxy if @proxy

      return if ENV['https_proxy'].nil?
      host_and_port = ENV['https_proxy'].match(%r{\A(?:https?://)?([^:]+):(\d+)})[1, 2]

      return if host_and_port.nil?
      @proxy = Net::HTTP.Proxy(*host_and_port)
    end
  end
end
