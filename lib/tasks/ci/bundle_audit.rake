namespace :ci do
  # Checks bundle audit and converts advisories into "attachments"
  # Usage: bin/rake ci:bundle_audit
  desc 'Patch-level verification for Bundler'
  task :bundle_audit do
    require 'English'

    COLOURS = {
      'High' => 'danger',
      'Medium' => 'warning'
    }.freeze

    # Update ruby-advisory-db
    `bundle audit update`
    # Check for insecure dependencies
    output = `bundle audit check`
    next if $CHILD_STATUS.exitstatus.zero?

    output.split("\n\n").each do |advisory|
      lines = advisory.split("\n")
      next if lines.count == 1

      hash = {}
      lines.each do |line|
        matchdata = line.match(/\A([^:]+):\s(.*)\z/)
        next if matchdata.nil?

        hash[matchdata[1]] = matchdata[2]
      end
      title = hash.delete('Title')
      url = hash.delete('URL')
      solution = hash.delete('Solution')
      criticality = hash['Criticality']

      attachment = {
        fallback: title,
        title: title,
        title_link: url,
        text: solution,
        fields: hash.map { |key, value| { title: key, value: value, short: true } },
        footer: 'bundle exec rake ci:bundle_audit'
      }
      attachment[:color] = COLOURS[criticality] if COLOURS[criticality]

      @attachments ||= []
      @attachments << attachment
      puts attachment.inspect
    end
  end
end
