## [Unreleased]
### Added
* `deploy:setup` creates more of the "NDR model" shared directories

### Fixed
* Fix ruby warnings in CI plugin

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
