require 'rubocop'

module NdrDevSupport
  module Rubocop
    # Following approach of rubocop-hq/rubocop-extension-generator,
    # monkey-patch in default configuration.
    module Inject
      def self.defaults!
        root = Pathname.new(__dir__).parent.parent.parent.expand_path
        path = root.join('config', 'rubocop', 'ndr.yml').to_s

        # Whereas by default, the raw YAML would be processed, we pass
        # through the ConfigLoader fully - this ensures `require` and
        # `inherit_from` statements are properly evaluated.
        #
        # PR at rubocop-hq/rubocop-extension-generator/pull/9
        #
        config = ::RuboCop::ConfigLoader.load_file(path)
        puts "configuration from \#{path}" if ::RuboCop::ConfigLoader.debug?

        config = ::RuboCop::ConfigLoader.merge_with_default(config, path)
        ::RuboCop::ConfigLoader.instance_variable_set(:@default_configuration, config)
      end
    end
  end
end
