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
    load_hash_matching(*commit.parents.map(&:oid))[:payload]
  end

  def load_current_commit_data
    load_hash_matching(commit.oid)[:payload]
  end

  def load_hash_matching(*commits)
    match = Array.wrap(YAML.load_file(filename)).
            detect { |h| commits.include? h[:commit] }

    match || {}
  rescue Errno::ENOENT
    {}
  end

  def save_current_commit_data(data)
    hashes = [
      load_hash_matching(*commit.parents.map(&:oid)),
      { commit: commit.oid, payload: data }
    ].reject(&:blank?)

    File.write(filename, YAML.dump(hashes))
  end

  def filename
    "rake_ci.#{name}.yml"
  end

  def name
    self.class.name.demodulize.underscore.sub(/_helper\z/, '')
  end
end
