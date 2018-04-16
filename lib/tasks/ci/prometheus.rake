namespace :ci do
  namespace :prometheus do
    desc 'Set up Prometheus'
    task :setup do
      @metrics = []

      ENV['PROMETHEUS_PUSHGATEWAY'] ||= ask('Prometheus pushgateway (host:port): ')
      ENV['PROMETHEUS_PUSHGATEWAY'] = nil if ENV['PROMETHEUS_PUSHGATEWAY'] == ''

      ENV['PROMETHEUS_PROJECTNAME'] ||= ask('Prometheus project name: ')
      ENV['PROMETHEUS_PROJECTNAME'] = nil if ENV['PROMETHEUS_PROJECTNAME'] == ''
    end

    desc 'Push Prometheus stats'
    task publish: :setup do
      next if @metrics.empty? || ENV['PROMETHEUS_PUSHGATEWAY'].nil?

      require 'prometheus/client'
      require 'prometheus/client/push'

      # returns a default registry
      prometheus = Prometheus::Client.registry

      @metrics.each do |metric|
        name = metric[:name].to_sym
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
              prometheus.gauge(name, docstring, project: ENV['PROMETHEUS_PROJECTNAME'])
            end
          gauge.set(label_set, value)
        else
          raise "Unknown metric type (#{metric.inspect})"
        end
      end

      Prometheus::Client::Push.new(
        'rake-ci-job', nil, ENV['PROMETHEUS_PUSHGATEWAY']
      ).add(prometheus)
    end
  end
end
