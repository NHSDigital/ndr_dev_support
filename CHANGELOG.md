## [Unreleased]
*no unreleased changes*

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
