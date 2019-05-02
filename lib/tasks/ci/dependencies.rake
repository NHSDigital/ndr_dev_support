require 'active_support/core_ext/object/blank'

namespace :ci do
  namespace :dependencies do
    desc 'setup'
    task :setup do
      require 'highline/import'
      ENV['PROJECT_NAME'] = gem_name || ask_for_project_name
    end

    desc 'process'
    task process: :setup do
      # Usage: bundle exec rake ci:dependencies:process
      arr = [
        ENV['PROJECT_NAME'],
        RUBY_VERSION,
        gem_requirement(*rails_family),
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
      puts "| #{arr.map { |val| val || '-' }.join(' | ')} |"
    end

    def current_dependencies
      @current_dependencies ||=
        begin
          gemspec, = Dir['*.gemspec']

          if gemspec
            Bundler.load_gemspec(gemspec).dependencies
          else
            Bundler.environment.current_dependencies
          end
        end
    end

    def ask_for_project_name
      dir_name = File.basename(Dir.pwd)
      response = ask("Project Name (leave blank to use '#{dir_name}'): ")

      response.presence || dir_name
    end

    # There is probably a simpler way of getting this information
    def gem_name
      self_dependency = Bundler.environment.current_dependencies.detect do |dep|
        dep.source && dep.source.path.to_s == '.'
      end
      self_dependency && self_dependency.name
    end

    def gem_requirement(*names)
      dependency = current_dependencies.detect { |dep| names.include?(dep.name) }

      return if dependency.nil? || (dependency.source && dependency.source.path.to_s == '.')
      return "@#{dependency.source.ref}@" if dependency.source
      dependency.requirement.to_s
    end

    def jquery_version
      Jquery::Rails::JQUERY_VERSION
    rescue NameError
      nil
    end

    def bootstrap_version
      require 'bootstrap-sass'
      Bootstrap::VERSION
    rescue LoadError
      nil
    end

    def rails_family
      %w[rails activesupport actionpack actionview activemodel activerecord
         actionmailer activejob actioncable activestorage railties]
    end
  end
end
