## ADDED Requirements

### Requirement: Build version stamp
Every web build SHALL carry a version derived from git alone: `v<YY>.<M>.<D>.<N>` for a production build from `main`, where YY is the year minus 1970, M and D are unpadded, and the date is the built commit's committer-local day. Other builds SHALL read `v<YY>.<M>.<D>-dev+<sha>`.

#### Scenario: First production build of the day
- **WHEN** Workers Builds builds merge 58a1140f (committed 2026-11-17T08:21:59-08:00) on `main`, the first `main` commit of that day
- **THEN** the version is `v56.11.17.1`

#### Scenario: Work branch build
- **WHEN** commit b29c9749 of 2026-11-17 is built on any branch other than `main`
- **THEN** the version is `v56.11.17-dev+b29c9749`

#### Scenario: Rebuilding a commit
- **WHEN** the same commit is built twice
- **THEN** both builds carry the same version

### Requirement: Daily build number
N SHALL count the first-parent commits on `main` that share the built commit's day, up to and including it. A shallow checkout SHALL deepen its history until an earlier day is visible; when it cannot, the build SHALL still succeed with N shown as `0` and the commit appended.

#### Scenario: Several merges in one day
- **WHEN** `main` has merges at 17:50 and 17:53 on 2026-11-16 (-08:00) after one on 2026-11-15
- **THEN** they build as `v56.11.16.1` and `v56.11.16.2`

#### Scenario: Shallow clone without history
- **WHEN** a depth-1 clone of a mid-day merge cannot fetch more history
- **THEN** the version is `v56.11.17.0+<sha>` and the build continues

### Requirement: Version visible in the app
The game SHALL show the build version in small, non-interactive text on the title screen and in the pause menu, and the `/console`, `/gallery` and `/studio` pages SHALL show it in a footer. It SHALL NOT be shown over the arena during play.

#### Scenario: Checking a deploy from the title
- **WHEN** the operator opens the game after a deploy
- **THEN** the title screen's bottom-left corner reads that deploy's version

### Requirement: Version endpoint
The Worker SHALL answer `GET /version` with the build record (`version`, `channel`, `date`, `build`, `commit`, `branch`) as uncached JSON with an `x-build-version` header, and with 404 `{"version":"unknown"}` when the build wrote no record.

#### Scenario: Checking what is live without playing
- **WHEN** the operator requests `https://demonattack.tlatoani.net/version`
- **THEN** the JSON's `version` is the deployed build's version and the response is not cached
