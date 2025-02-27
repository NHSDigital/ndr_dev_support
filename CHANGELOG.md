## [Unreleased]
### Fixed
* Capistrano: Add missing `tmpdir` requirement to deploy application secrets

## 7.3.1 / 2025-01-02
### Added
* Capistrano: deploy application secrets from a subversion or git repository

## 7.3.0 / 2024-12-19
### Added
* Capistrano: install rbenv and ruby from /opt/rbenv.tar.gz or vendor/rbenv/

## 7.2.6 / 2024-11-13
### Fixed
* Support Rails 7.2, 8.0, Ruby 3.3

## 7.2.5 / 2024-10-24
### Changed
* Capistrano: fix up installed gem permissions after deployment.
* Capistrano: identify errors when installing out-of-bundle gems.
* Allow either hash `EnforcedShorthandSyntax` style

### Added
* `deploy:setup` creates more of the "NDR model" shared directories

## 7.2.4 / 2024-05-01
### Changed
* Change default browser for integration tests to new headless Chrome
* Support old chrome headless driver
* Reduce the number of releases kept on application servers

## 7.2.3 / 2023-12-08
### Fixed
* use default rubocop line limit (120)

## 7.2.2 / 2023-10-26
### Fixed
* Support Rails 7.1
* Convenience updates for rake bundle:update

## 7.2.1 / 2023-09-04
### Changed
* Use feature/ branch names for rake bundle:update

### Fixed
* Fix outdated MiniTest reference

## 7.2.0 / 2023-07-20
## Changed
* Drop support for Ruby 2.7, Rails 6.0
* Remove dependency on outdated `webdrivers` gem

## 7.1.0 / 2023-03-02
### Fixed
* Support Ruby 3.2

### Changed
* CI: include minitest error details in slack output

## 7.0.0 / 2022-10-05
## Changed
* Change default browser for integration tests to headless Chrome
* Drop support for Poltergeist and PhantomJS
* Replace Public Health England naming with NHS Digital
* Drop support for Rails 5.2

## 6.1.9 / 2022-10-04
### Fixed
* CD: don't post empty messages to Slack
* Adjust dependencies to continue to support Poltergeist

## 6.1.8 / 2022-08-09
### Fixed
* Fixed ActiveSupport 7 deprecation messages

## 6.1.7 / 2022-07-15
### Added
* Add `cd:credentials` rake task for continuous deployment of credentials

## 6.1.6 / 2022-07-01
### Added
* capistrano: use DEPLOYER environment variable for non-interactive deployments

## 6.1.5 / 2022-06-24
### Fixed
* audit:code should allow special characters in filenames

## 6.1.4 / 2022-06-16
### Added
* Add warning when upgrading webpacker

## 6.1.3 / 2022-05-25
### Fixed
* bundle:update should update secondary gem lock files

## 6.1.2 / 2022-05-24
### Fixed
* bundle:update should fetch binary gems for all bundled platforms

## 6.1.1 / 2022-04-29
### Fixed
* CI: fix crashes when brakeman parsing fails

## 6.1.0 / 2022-04-28
### Fixed
* CI: support Ruby 3.0

### Changed
* Allow Ctrl-C to cleanly interrupt an idle daemon
* Drop support for Ruby 2.6

## 6.0.5 / unreleased

## 6.0.4 / 2022-03-14
### Fixed
* bundle:update should commit code_safety.yml changes.

## 6.0.3 / 2022-03-14
### Added
* Add `bundle:update` rake task to update bundled gem files

## 6.0.2 / 2022-01-14
### Fixed
* Support Rails 7, Ruby 3.1

## 6.0.1 / 2021-07-09
### Fixed
* Fix ruby warnings in CI plugin
* Remove inconsistent trailing whitespace in code_safety.yml

## 6.0.0 / 2021-02-25
### Changed
* Linting: return a zero exit status when there are no lintable changes (#97)

## 5.10.2 / 2021-02-15
### Fixed
* Fixed an issue using `flakey_test` with `minitest` v5.11 onwards
* Allow use with Rails 6.1

## 5.10.1 / 2021-02-01
### Fixed
* Fixed an issue with binary files breaking certain code audit modes (#94)

## 5.10.0 / 2021-01-29
### Added
* Added `test_repeatedly` for integration test debugging (#85)
* Added `outfile` and `filter` options to code auditing (#93)

### Fixed
* Fixed excessive `parser/current` warnings (#91)
* Improved performance of interactive code auditing (#93)

## 5.9.0 / 2021-01-12
### Added
* Move to keep up with Rubocop releases
* Add `rubocop-rake`, for additional rake-specific Rubocop checks
* Disable browser animations in the test environment by default

### Fixed
* Fix unnecessary 'parser/current' warnings when not using rubocop
* Test against Ruby 3.0

## 5.8.2 / 2020-07-22
### Fixed
* Tweak integration testing driver config, for capybara 3.33.0 deprecations

## 5.8.1 / 2020-07-10
### Fixed
* Fix issue running `brakeman:fingerprint_details` task

## 5.8.0 / 2020-04-07
### Added
* Ability to select git CI branch by exporting `RAKE_CI_BRANCH_NAME`

## 5.7.1 / 2020-04-07
### Fixed
* Address issue updating redmine using commit message tags

## 5.7.0 / 2020-03-26
### Added
* Add `ci:brakeman:strict` alternative CI task. (#77)
* Send `brakeman_filtered_warnings` metrics. (#78)
* Allow redmine tickets to be updated (but not resolved) when the build fails (#73)

### Fixed
* Stop including asset compilation caches in the deployment archive.
* Ensure brakeman alerts aren't sent to Slack if they've been reviewed and filtered out

## 5.6.0 / 2020-02-14
### Added
* Add `flakey_test` to the minitest DSL, to allow sporadic failures to be retried
* CI: include minitest seed in slack output

## 5.5.0 / 2020-01-27
### Added
* bundle master RuboCop config, and allow it to be `required`

## 5.4.8 / 2020-01-24
### Fixed
* deploy: insert temporary DB config to allow asset precompilation
* bump rubocop version (#72)

## 5.4.7 / 2019-12-17
### Fixed
* Fix issue with `prometheus-client` API changing.

## 5.4.6 / 2019-12-12
### Fixed
* Fix issue with CI invoked through rake binstub for projects using Spring (#69)
* Fix issue with shared paths in the `private/` directory
* Fix CI brakeman task with recent brakeman version

## 5.4.5 / 2019-07-24
### Fixed
* Fix issue where other minitest plugins sporadically fail to load

## 5.4.4 / 2019-07-24
### Fixed
* Fix issue with `rake_ci` minitest plugin loading breaking webpacker

## 5.4.3 / 2019-06-18
### Fixed
* Avoid `RBENV_ROOT` issues when deploying to NDR-model targets
* Avoid duplicate 'tests passed' notifications (#49)

## 5.4.2 / 2019-06-18
### Fixed
* Tweak `:chrome_headless` driver for Chrome 75+

## 5.4.1 / 2019-06-04
### Fixed
* Bump `rubocop` to a version that properly supports Ruby 2.6

## 5.4.0 / 2019-05-30
### Added
* Introduce `show_me_the_cookies` into the integration testing DSL

### Fixed
* Use command line args to prevent headless Chrome hanging

## 5.3.1 / 2019-05-20
### Fixed
* Use `webdrivers` gem for Selenium WebDriver managements.

## 5.3.0 / 2019-05-15
### Added
* Offer current checkout name as project name when outputting system version info
* Added a rake rubocop:summary task to list offence counts by cop (#52)
* Include rerun snippets in the slack attachments when tests error/fai (#55)

### Fixed
* rake rubocop:diff now gracefully reports ruby syntax errors (#54)
* Support Rails 6 release candidate

## 5.2.0 / 2019-03-21
### Added
* Added rake task to filter brakeman output to specific fingerprints. (#51)

### Fixed
* CI: Remove duplicated revision information from commit message

## 5.1.0 / 2019-01-31
### Added
* CI: send a slack message whenever tests pass
* CI: send a slack message if Redmine update fails

### Fixed
* prevent `commit_metadata_persistable` from wiping prior result immediately
* fix issue with multiple prometheus clients erasing each others' pushes
* CI: improve git cleanup to aid auto-recovery after failure

## 5.0.1 / 2019-01-31
### Fixed
* fix CI issue when Rails isn't fully loaded.

## 5.0.0 / 2019-01-31
### Changed
* Setting the Capybara save path and prune strategy. Resolves #45 (#46)

### Added
* Added an additional cop to check commits for missing associated test files.

### Fixed
* capistrano: address filesystem issue with using NDR-model in mixed-mode project
* support Ruby 2.6. Minimum version is now 2.4
* ci_server: don't crash out if the prometheus gateway is unreachable

## 4.2.1 / 2018-12-18
### Fixed
* ci_server: improve logging and error handling (#44)

## 4.2.0 / 2018-11-28
### Added
* Improve `Stoppable` integration within a Rails project, adding configurable logger.

## 4.1.3 / 2018-11-13
### Fixed
* Avoid race condition when introducing minutest plugins (#41)

## 4.1.2 / 2018-11-09
### Fixed
* capistrano: use passwordless sudo when installing out-of-bundle gems (#40)

## 4.1.1 / 2018-11-09
### Fixed
* Added missing Rugged require

## 4.1.0 / 2018-11-09
### Added
* Added CI redmine ticket update task (#30)
* Added a mechanism and cops to check for undesirable migration changes (#32)
* Added Minitest::RakeCIReporter to integrate tests into the RakeCI (#37)
* Added the Redmine TicketResolver (#36, #38)

### Fixed
* rubocop: Metrics/AbcSize now excludes tests
* Replaced blanket db folder rubocop exclusion with cop specific exemptions (#31)
