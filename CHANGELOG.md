## [Unreleased]
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
