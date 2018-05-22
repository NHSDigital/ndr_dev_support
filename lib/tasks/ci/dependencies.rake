namespace :ci do
  namespace :dependencies do
    desc 'setup'
    task :setup do
      ENV['PROJECT_NAME'] = gem_name || ask('Project Name: ')
    end

    desc 'process'
    task process: :setup do
      # Usage: bundle exec rake ci:dependencies:process
      arr = [
        ENV['PROJECT_NAME'],
        RUBY_VERSION,
        gem_requirement('rails'),
        gem_requirement('activemodel-caution'),
        gem_requirement('ndr_dev_support'),
        gem_requirement('ndr_error'),
        gem_requirement('ndr_import'),
        gem_requirement('ndr_support'),
        gem_requirement('ndr_ui'),
        gem_requirement('ndr_workflow'),
        jquery_version,
        bootstrap_version
      ]
      puts "| #{arr.join(' | ')} |"
    end

    def current_dependencies
      @current_dependencies ||= Bundler.environment.current_dependencies
    end

    # There is probably a simpler way of getting this information
    def gem_name
      self_dependency = current_dependencies.detect do |dep|
        dep.source && dep.source.path.to_s == '.'
      end
      self_dependency && self_dependency.name
    end

    def gem_requirement(name)
      dependency = current_dependencies.detect { |dep| dep.name == name }

      return '-' if dependency.nil? || (dependency.source && dependency.source.path.to_s == '.')
      return "@#{dependency.source.ref}@" if dependency.source
      dependency.requirement.to_s
    end

    def jquery_version
      Jquery::Rails::JQUERY_VERSION
    rescue NameError
      '-'
    end

    def bootstrap_version
      require 'bootstrap-sass'
      Bootstrap::VERSION
    rescue LoadError
      '-'
    end
  end
end
