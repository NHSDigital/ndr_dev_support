require 'minitest'

# Don't trigger full plugin autodiscovery, as we load this
# file through RUBYOPT extension (and full autodiscovery can
# lead to e.g. incomplete definitions of Rails existing).
require_relative 'rake_ci_plugin'
Minitest.extensions << 'rake_ci'

Minitest::RakeCIReporter.enable!
