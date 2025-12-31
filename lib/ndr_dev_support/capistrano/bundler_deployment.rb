# Support capistrano 2 with old (< 4) and new (>= 4) bundler versions
#
# Add "require 'ndr_dev_support/capistrano/ndr_model'" in your Capistrano deploy.rb,
# but remove calls to "require 'bundler/capistrano'", and
# Bundler will be activated after each new deployment.

if Gem::Version.new(Bundler::VERSION).release < Gem::Version.new('4.0')
  require 'bundler/capistrano' unless defined?(Bundler::Deployment)
else
  # Redefine deployment helpers for Capistrano 2, previously defined in bundler < 4
  # cf. https://blog.rubygems.org/2025/12/03/upgrade-to-rubygems-bundler-4.html
  # Code copied from bundler 2 source files bundler/deployment.rb and bundler/capistrano.rb
  # rubocop:disable Style/Documentation, Metrics/AbcSize, Metrics/MethodLength, Style/StringLiterals, Style/SymbolArray, Style/RaiseArgs, Layout/EmptyLineAfterGuardClause, Style/StringLiteralsInInterpolation, Style/Lambda
  module Bundler
    class Deployment
      def self.define_task(context, task_method = :task, opts = {})
        if defined?(Capistrano) && context.is_a?(Capistrano::Configuration)
          context_name = "capistrano"
          role_default = "{:except => {:no_release => true}}"
          error_type = ::Capistrano::CommandError
        else
          context_name = "vlad"
          role_default = "[:app]"
          error_type = ::Rake::CommandFailedError
        end

        roles = context.fetch(:bundle_roles, false)
        opts[:roles] = roles if roles

        context.send :namespace, :bundle do
          send :desc, <<-DESC
            Install the current Bundler environment. By default, gems will be \
            installed to the shared/bundle path. Gems in the development and \
            test group will not be installed. The install command is executed \
            with the --deployment and --quiet flags. If the bundle cmd cannot \
            be found then you can override the bundle_cmd variable to specify \
            which one it should use. The base path to the app is fetched from \
            the :latest_release variable. Set it for custom deploy layouts.

            You can override any of these defaults by setting the variables shown below.

            N.B. bundle_roles must be defined before you require 'bundler/#{context_name}' \
            in your deploy.rb file.

              set :bundle_gemfile,  "Gemfile"
              set :bundle_dir,      File.join(fetch(:shared_path), 'bundle')
              set :bundle_flags,    "--deployment --quiet"
              set :bundle_without,  [:development, :test]
              set :bundle_with,     [:mysql]
              set :bundle_cmd,      "bundle" # e.g. "/opt/ruby/bin/bundle"
              set :bundle_roles,    #{role_default} # e.g. [:app, :batch]
          DESC
          send task_method, :install, opts do
            bundle_cmd     = context.fetch(:bundle_cmd, "bundle")
            bundle_flags   = context.fetch(:bundle_flags, "--deployment --quiet")
            bundle_dir     = context.fetch(:bundle_dir, File.join(context.fetch(:shared_path), "bundle"))
            bundle_gemfile = context.fetch(:bundle_gemfile, "Gemfile")
            bundle_without = [*context.fetch(:bundle_without, [:development, :test])].compact
            bundle_with    = [*context.fetch(:bundle_with, [])].compact
            app_path = context.fetch(:latest_release)
            if app_path.to_s.empty?
              raise error_type.new("Cannot detect current release path - make sure you have deployed at least once.")
            end
            args = ["--gemfile #{File.join(app_path, bundle_gemfile)}"]
            args << "--path #{bundle_dir}" unless bundle_dir.to_s.empty?
            args << bundle_flags.to_s
            args << "--without #{bundle_without.join(" ")}" unless bundle_without.empty?
            args << "--with #{bundle_with.join(" ")}" unless bundle_with.empty?

            run "cd #{app_path} && #{bundle_cmd} install #{args.join(" ")}"
          end
        end
      end
    end
  end

  # Capistrano task for Bundler.
  require "capistrano/version"

  if defined?(Capistrano::Version) && Gem::Version.new(Capistrano::Version).release >= Gem::Version.new("3.0")
    raise "For Capistrano 3.x integration, please use https://github.com/capistrano/bundler"
  end

  Capistrano::Configuration.instance(:must_exist).load do
    before "deploy:finalize_update", "bundle:install"
    Bundler::Deployment.define_task(self, :task, except: { no_release: true })
    set :rake, lambda { "#{fetch(:bundle_cmd, "bundle")} exec rake" }
  end
  # rubocop:enable Style/Documentation, Metrics/AbcSize, Metrics/MethodLength, Style/StringLiterals, Style/SymbolArray, Style/RaiseArgs, Layout/EmptyLineAfterGuardClause, Style/StringLiteralsInInterpolation, Style/Lambda
end
