namespace :ci do
  namespace :prometheus do
    desc 'Set up Prometheus'
    task :setup do
      require 'highline/import'
      @metrics = []

      ENV['PROMETHEUS_PUSHGATEWAY'] ||= ask('Prometheus pushgateway (host:port): ')
      ENV['PROMETHEUS_PUSHGATEWAY'] = nil if ENV['PROMETHEUS_PUSHGATEWAY'] == ''

      ENV['PROMETHEUS_PROJECTNAME'] ||= ask('Prometheus project name: ')
      ENV['PROMETHEUS_PROJECTNAME'] = nil if ENV['PROMETHEUS_PROJECTNAME'] == ''
    end

    desc 'Push Prometheus stats'
    task publish: :setup do
      gateway = ENV['PROMETHEUS_PUSHGATEWAY']
      project = ENV['PROMETHEUS_PROJECTNAME']

      next if @metrics.empty? || gateway.nil?

      require 'prometheus/client'
      require 'prometheus/client/push'

      # returns a default registry
      prometheus = Prometheus::Client.registry

      @metrics.each do |metric|
        name = "ci_#{metric[:name]}".to_sym
        # TODO: Add :docstring where required
        docstring = metric[:docstring] || 'TODO'
        label_set = metric[:label_set] || {}
        value = metric[:value]

        case metric[:type]
        when :gauge
          gauge =
            if prometheus.exist?(name)
              prometheus.get(name)
            else
              prometheus.gauge(name, docstring, project: project)
            end
          gauge.set(label_set, value)
        else
          raise "Unknown metric type (#{metric.inspect})"
        end
      end

      client = Prometheus::Client::Push.new("rake-ci-#{project}", nil, gateway)

      begin
        client.add(prometheus)
      rescue Errno::ECONNREFUSED => exception
        warn "Failed to push metrics to Prometheus: #{exception.message}"

        @attachments ||= []
        @attachments << {
          color: 'danger',
          title: 'Publishing Error',
          text: 'Build metrics could not be pushed - the Prometheus gateway was uncontactable',
          footer: 'bundle exec rake ci:prometheus:publish',
          mrkdwn_in: ['text']
        }
      end
    end
  end
end
