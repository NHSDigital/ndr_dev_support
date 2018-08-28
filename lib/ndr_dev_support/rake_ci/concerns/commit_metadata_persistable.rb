require 'active_support/concern'
require 'active_support/inflector'
require 'yaml'

# Provides methods relating to persisting commit metadata
module CommitMetadataPersistable
  extend ActiveSupport::Concern

  included do
    attr_accessor :commit
  end

  private

  def load_last_commit_data
    hash = YAML.load_file(filename)

    if commit.parents.map(&:oid).include?(hash[:commit])
      # payload from parent commit
      hash[:payload]
    end
  rescue Errno::ENOENT
    nil
  end

  def load_current_commit_data
    hash = YAML.load_file(filename)

    if commit.oid == hash[:commit]
      # payload from parent commit
      hash[:payload]
    end
  rescue Errno::ENOENT
    nil
  end

  def save_current_commit_data(data)
    hash = { commit: commit.oid, payload: data }
    File.write(filename, YAML.dump(hash))
  end

  def filename
    "rake_ci.#{name}.yml"
  end

  def name
    self.class.name.demodulize.underscore.sub(/_helper\z/, '')
  end
end
