## NdrDevSupport [![Build Status](https://travis-ci.org/PublicHealthEngland/ndr_dev_support.svg?branch=master)](https://travis-ci.org/PublicHealthEngland/ndr_dev_support) [![Gem Version](https://badge.fury.io/rb/ndr_dev_support.svg)](https://badge.fury.io/rb/ndr_dev_support)

This is the Public Health England (PHE) National Disease Registers (NDR) Developer Support ruby gem,
providing:

1. rake tasks to manage code auditing of ruby based projects
2. rake tasks to limit Rubocop's output to changed (and related) code
3. integration testing support, which can be required from a project's `test_helper.rb`

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'ndr_dev_support', group: [:development, :test]
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

For more details of the audit tasks available, execute:

    $ rake -T audit

### RuboCop configuration

ndr_dev_support includes tweaks to the default Ruby Style Guide, to better suit NDR.
To use this updated style guide from within a project, add the following to top of the project's `.rubocop.yml` file:

```yaml
inherit_from: 'https://raw.githubusercontent.com/PublicHealthEngland/ndr_dev_support/master/.rubocop.yml'
```

RuboCop also allows `inherit_gem`, but this currently doesn't work with relative paths (paths are deemed relative to the config file, rather than the project including `ndr_dev_support`).

In order for these configuration to apply, you will need to invoke RuboCop using Bundler:

```
$ bundle exec rubocop .
```
...or use the bundled rake task (see next section).

### RuboCop filtering

ndr_dev_support also provides rake tasks to enable more targeted use of RuboCop, to analyse only relevant code changes:
```
$ rake rubocop:diff HEAD
$ rake rubocop:diff HEAD~3..HEAD~2
$ rake rubocop:diff HEAD~3..HEAD~2
$ rake rubocop:diff aef12fd4
$ rake rubocop:diff master
$ rake rubocop:diff path/to/file
$ rake rubocop:diff dir/
```
As well as the primary `rubocop:diff` task, there are a number of convenience tasks provided:
```
$ rake rubocop:diff:head
$ rake rubocop:diff:staged
$ rake rubocop:diff:unstaged
$ find . -iregex .*\.rake$ | xargs rake rubocop:diff:file
```

To add development support tasks to your project, add this line to your application's Rakefile:

```ruby
require 'ndr_dev_support/tasks'
```

### Integration test environment

ndr_dev_support bundles a configured Rails integration testing environment. It uses `capybara` and `poltergeist` to drive a PhantomJS headless browser, and includes some sensible configuration.

If an integration test errors or fails, `capybara-screenshot` is used to automatically retrieve a full-height screenshot from PhantomJS, which is then stored in `tmp/`.

Beyond standard Capybara testing DSL, ndr_dev_support bundles some additional functionality:

* `clear_headless_session!` - causes PhantomJS to reset, simulating a browser restart.
* `delete_all_cookies!` - causes PhantomJS to delete all cookies. Helpful for testing AJAX logouts.
* `within_screenshot_compatible_window` – similar to `within_window`, but allows failure screenshots to be taken of the failing child window, rather than the spawning parent.

To use, ensure `phantomjs` is installed, and add the following to your application's `test_helper.rb`

```ruby
require 'ndr_dev_support/integration_testing'
```

When using `capybara` with PhantomJS, the test database must be consistent between the test runner and the application being tested. With transactional tests in operation, this means that both must share a connection. Doing so is error-prone, and can introduce race conditions. However, some projects have had success with the approach, so it is available within `ndr_dev_support` with the following additional require statement:

```ruby
# WARNING: can result in race conditions within the test suite
require 'ndr_dev_support/integration_testing/connection_sharing'
```

The slower, more reliable, alternative is to use the `database_cleaner` gem. `ndr_dev_support` provides no built-in support for this approach, as configuration can be quite project-specific. However, as a starting point:

Add to the `Gemfile`:

```ruby
group :test do
  gem 'database_cleaner'
end
```

Add to `test_helper.rb`:

```ruby
require 'database_cleaner'
DatabaseCleaner.strategy = :deletion # anecdotally, faster than :truncation for our projects

class ActionDispatch::IntegrationTest
  # Don't wrap each test case in a transaction:
  self.use_transactional_tests = false

  # Instead, insert fixtures afresh between each test:
  setup    { DatabaseCleaner.start }
  teardown { DatabaseCleaner.clean }
end
```

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

