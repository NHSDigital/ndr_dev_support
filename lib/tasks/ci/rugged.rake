namespace :ci do
  namespace :rugged do
    desc 'Setup Rugged, get the current commit and friendly version of the revision name'
    task :setup do
      require 'ndr_dev_support/daemon/ci_server'

      @repo = Rugged::Repository.new('.')
      @commit = @repo.lookup(@repo.head.target_id)
      @friendly_revision_name = NdrDevSupport::Daemon::CIServer.friendly_revision_name(@commit)
    end

    desc 'Show details of the commit and make it the first attachment'
    task commit_details: :setup do
      fields = [
        { title: 'Author', value: @commit.author[:name], short: true },
        { title: 'Revision', value: @friendly_revision_name, short: true }
      ]

      if File.exist?('.ruby-version')
        fields << {
          title: 'Target Ruby Version',
          value: File.read('.ruby-version').chomp,
          short: true
        }
      end

      text = @commit.message.lines.grep_v(/\Agit-svn-id: /).join.strip

      attachment = {
        fallback: text,
        text: text,
        fields: fields,
        ts: @commit.author[:time].to_i
      }

      @attachments ||= []
      @attachments.unshift(attachment)
      puts attachment.inspect
    end
  end
end
