## NdrDevSupport [![Build Status](https://travis-ci.org/PublicHealthEngland/ndr_dev_support.svg?branch=master)](https://travis-ci.org/PublicHealthEngland/ndr_dev_support) [![Gem Version](https://badge.fury.io/rb/ndr_dev_support.svg)](https://badge.fury.io/rb/ndr_dev_support)

This is the Public Health England (PHE) National Disease Registers (NDR) Developer Support ruby gem,
providing:

1. rake tasks to manage code auditing of ruby based projects
2. rake tasks to limit Rubocop's output to changed (and related) code
3. integration testing support, which can be required from a project's `test_helper.rb`
4. Deployment support, through Capistrano.
5. a rake task based Continuous Integration (CI) server.

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'ndr_dev_support', group: [:development, :test]
```

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install ndr_dev_support

To add development support tasks (see below) to your project, add this line to your application's `Rakefile`:

```ruby
require 'ndr_dev_support/tasks'
```

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

### Integration test environment

ndr_dev_support bundles a configured Rails integration testing environment.

By default, it uses `capybara` and `poltergeist` to drive a PhantomJS headless browser, and includes some sensible configuration.

To use, simply add the following to your application's `test_helper.rb`

```ruby
require 'ndr_dev_support/integration_testing'
```

#### Other drivers

Other drivers are also supported; `chrome` / `chrome_headless` / `firefox` are all powered by selenium, and can either be explicitly used with:

```ruby
Capybara.default_driver    = :chrome_headless
Capybara.javascript_driver = :chrome_headless
```

...or, assuming no driver has been explicitly set, can be selected at runtime:

```
$ INTEGRATION_DRIVER=chrome_headless bin/rake test
```

#### Screenshots

If an integration test errors or fails, `capybara-screenshot` is used to automatically retrieve a full-height screenshot from the headless browser, which is then stored in `tmp/`.

#### DSL extensions

Beyond standard Capybara testing DSL, ndr_dev_support bundles some additional functionality:

* `clear_headless_session!` - causes the headless browser to reset, simulating a browser restart.
* `delete_all_cookies!` - causes the headless browser to delete all cookies. Helpful for testing AJAX logouts.
* `within_screenshot_compatible_window` – similar to `within_window`, but allows failure screenshots to be taken of the failing child window, rather than the spawning parent.
* `within_modal` - scope capybara to only interact within a modal, and (by default) expect the modal to disappear when done.

#### Database synchronisation

When using a headless browser for integration tests, the test database must be consistent between the test runner and the application being tested. With transactional tests in operation, this means that both must share a connection. It is up to the individual project to provide this facility; as of Rails 5.1, it is built in to the framework directly.

### Deployment support

There are various capistrano plugins in the `ndr_dev_support/capistrano` directory - see each one for details.
For new projects, you should likely add the following:

```ruby
# in config/deploy.rb
require 'ndr_dev_support/capistrano/ndr_model'
```

This will pull in the majority of behaviour needed to deploy in our preferred style.

## Rake CI server

ndr_dev_support provides a rake based continuous integration server that runs on a `git` or `git svn` working copy of your application.
It polls for changes to the respository and, unlike some CI servers, it checks out and tests every commit; enabling full and comparative analysis of code quality and other statistical trends.

Out of the box it does nothing, but does provide a number of rake tasks that you can opt to use.
Those rake tasks utilise the concepts of metrics and attachments (messages) and tasks tend to either generate them or publish them.

NOTE: As the way tests are run across applications differs, the `:default` rake task must be able to run your full suite of tests.

CI rake tasks have been written for:

* `ci:brakeman` - [brakeman](https://brakemanscanner.org/) vulnerability scanner metrics are generated for warning counts and "danger" messages for new warnings and "good" messages for fixed warnings.
* `ci:bundle_audit` - generates "danger" messages for high criticality [bundle audit](https://github.com/rubysec/bundler-audit) advisories and "warning" messages for all others.
* `ci:commit_cop` - Runs a number of commit "Cops" which create messages when common commit mistakes occur. Current cops look for a Rails migration added without a structure dump file, modified Rails migrations and renamed Rails migrations.
* `ci:dependencies:process` - generates a line of pipe delimited markup showing system dependencies (that could be used in a wiki page on Redmine)
* `ci:housekeep` - runs `rake log:clear` and `rake tmp:clear` if defined
* `ci:linguist` - generates project programming language metrics for languages over 1% of codebase.
* `ci:minitest` - sets up Minitest and SimpleCov to capture metrics and messages and runs the `default` rake task and `ci:simplecov:process` before running `ci:redmine:update_tickets` if all tests pass.
* `ci:notes` - runs the Rails `rake notes` task (if using Rails) and converts annotation counts into metrics.
* `ci:prometheus:publish` - sends all metrics to specified [Prometheus](https://prometheus.io/) push gateway.
* `ci:redmine:update_tickets` - if all tests pass, this will parse the commit message and resolve associated [Redmine](https://www.redmine.org/) tickets.
* `ci:rugged:commit_details` - if there are messages, then it prepends message list with commit details.
* `ci:simplecov:process` - generates metrics for [SimpleCov](https://github.com/colszowka/simplecov) measured test covered lines, test coverage percentage and total lines of code.
* `ci:slack:publish` - sends all messages to specified [Slack](https://slack.com/) channel.
* `ci:stats` - runs the Rails `rake stats` task (if using Rails) and converts counts into metrics

To start the server, `cd` to the working copy and execute:

    $ rake ci:server

Configuration is managed within your application by implementing the `ci:all` rake task. When a new commit is detected, it checks it out and runs `rake ci:all`.

An example Rails application rake task might look like:

```ruby
namespace :ci do
  desc 'Setup CI stack, integrations, etc up front'
  task setup: [
    'ci:rugged:setup',
    'ci:slack:setup',
    'ci:prometheus:setup'
  ]

  desc 'all'
  task all: [
    # Setup
    'ci:setup',
    'ci:housekeep',
    'db:migrate',
    # Test and Analyse
    'ci:minitest',
    'ci:brakeman',
    'ci:bundle_audit',
    'ci:linguist',
    'ci:notes',
    'ci:stats',
    # Report
    'ci:publish'
  ]
end
```

NOTE: Defining the `ci:setup` rake tasks up front is not necessary, but will prompt for missing server credentials at the start of the first CI run.

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

