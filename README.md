## NdrDevSupport

This is the Public Health England (PHE) National Disease Registers (NDR) Developer Support ruby gem,
providing:

1. rake tasks to manage code auditing of ruby based projects; and
2. a rake task to limit Rubocop's output to changed (and related) code.

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'ndr_dev_support'
```

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install ndr_dev_support

## Usage

### Code Auditing Rake Tasks

ndr_dev_support provides a mechanism to manage the state of routine code quality and security peer reviews. It should be used as part of wider quality and security policies.

It provides rake tasks to help manage the process of persisting the state of security reviews.

Once files have been reviewed as secure, the revision number for that file is stored in code_safety.yml. If used within a Rails app, this file is stored in the config/ folder, otherwise it is kept in the project's root folder.

Note: This feature works with svn and git repositories and svn, git-svn and git working copies.

To add code auditing to your project add this line to your application's Rakefile:

```ruby
require 'ndr_dev_support/tasks'
```

For more details of the tasks available, execute:

    $ rake -T audit

## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `rake test` to run the tests. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version, push git commits and tags, and push the `.gem` file to [rubygems.org](https://rubygems.org).

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/PublicHealthEngland/ndr_dev_support. This project is intended to be a safe, welcoming space for collaboration, and contributors are expected to adhere to the [Contributor Covenant](http://contributor-covenant.org) code of conduct.

1. Fork it ( https://github.com/PublicHealthEngland/ndr_dev_support/fork )
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create a new Pull Request

## License

The gem is available as open source under the terms of the [MIT License](http://opensource.org/licenses/MIT).

