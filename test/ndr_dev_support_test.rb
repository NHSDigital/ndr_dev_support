require 'test_helper'

class NdrDevSupportTest < Minitest::Test
  def test_that_it_has_a_version_number
    refute_nil ::NdrDevSupport::VERSION
  end
end
