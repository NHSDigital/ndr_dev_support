require 'test_helper'
require 'rubocop'

class NdrDevSupportTest < Minitest::Test
  def test_that_it_has_a_version_number
    refute_nil ::NdrDevSupport::VERSION
  end

  # Test that we don't distribute a malformed RuboCop configuration file
  # within ndr_dev_support. This also checks that the version of RuboCop
  # that we bundle is able to understand all of the configuration we use.
  def test_rubocop_config_is_valid
    config_filepath = File.join(File.dirname(__FILE__), '..', '.rubocop.yml')

    $stderr = StringIO.new
    RuboCop::ConfigLoader.load_file(config_filepath)
    refute_match(/Warning:/, $stderr.string, ".rubocop.yml was unparseable!")
  ensure
    $stderr = STDERR
  end
end
