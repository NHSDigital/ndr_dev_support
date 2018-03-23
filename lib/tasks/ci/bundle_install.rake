namespace :ci do
  desc 'Install bundled gems'
  task :bundle_install do
    require 'English'

    # `gem install bundler`
    `bundle install --local`
    next if $CHILD_STATUS.exitstatus.zero?

    attachment = {
      color: 'danger',
      fallback: 'Failure running bundle install --local',
      text: 'Failure running `bundle install --local`',
      footer: 'bundle exec rake ci:bundle_install'
    }

    @attachments ||= []
    @attachments << attachment
    puts attachment.inspect
  end
end
