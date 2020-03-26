namespace :ci do
  desc 'Test the system'
  task :minitest do
    raise 'Your test command must be the rake default' unless Rake::Task.task_defined?('default')

    # Run the tests
    test_cmd = 'bundle exec rake ci:minitest:setup ci:simplecov:setup default'
    system({ 'RAILS_ENV' => nil }, test_cmd)

    Rake::Task['ci:minitest:process'].invoke

    next if ENV['RAKECI_HEADLESS']
    puts @metrics.inspect
    puts @attachments.inspect
  end

  namespace :minitest do
    desc 'setup'
    task :setup do
      # Ensure the rake_ci plugin auto-enables:
      ENV['MINITEST_RAKE_CI'] = 'true'
    end

    desc 'process'
    task :process do
      require 'minitest/rake_ci'

      @attachments ||= []
      @metrics ||= []

      rake_ci_reporter = Minitest::RakeCIReporter.new
      hash = rake_ci_reporter.load_current_commit_hash
      if hash.nil?
        # Tests didn't run properly
        attachment = {
          color: 'danger',
          title: 'Testing Error',
          text: "Minitest didn't run properly",
          footer: 'bundle exec rake ci:minitest',
          mrkdwn_in: ['text']
        }
        @attachments << attachment

        next
      end

      # Test(s) ran
      Rake::Task['ci:simplecov:process'].invoke

      if Rake::Task.task_defined?('ci:redmine:update_tickets')
        tests_passed = hash[:statistics][:failures].zero? && hash[:statistics][:errors].zero?
        Rake::Task['ci:redmine:update_tickets'].invoke(tests_passed)
      end

      @attachments.concat(hash[:attachments])
      @metrics.concat(hash[:metrics])
    end
  end
end
