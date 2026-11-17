# Design: build version stamp

## 1. Format
`v<YY>.<M>.<D>.<N>`, numbers unpadded: `v56.11.17.1` is the first production build of 2026-11-17.

- **YY = year − 1970.** This is the Tillandsias release scheme, `<years_since_epoch>.<month>.<day>.<build>`
  (e.g. `56.8.31.3`, the third build of 2026-08-31), whose executable definition is Tillandsias'
  `scripts/bump-version.sh` [source: Tillandsias, "merge-to-main-and-release" skill, `/opt/skills/merge-to-main-and-release/SKILL.md` in the forge image, read 2026-11-17].
  The lane reports the same shape (`56.11.15.5`, installed `56.11.17.1`) [source: Tillandsias host tool
  `tillandsias.lane_version`, read 2026-11-17]. It is derived, not inferred. `test/build_version_test.dart` pins
  2026-11-17 → 56 anyway.
- Month and day are unpadded, as in Tillandsias (`56.8.31.3`) and in the operator's example (`v56.11.17.1`).
- Other builds: `v56.11.17-dev+b29c9749` (not on `main`), `v56.11.17.0+58a1140f` (on `main`, number unknown).
  Both carry the commit, since the date alone does not identify them. Semver reads `-dev` as a pre-release and `+sha`
  as build metadata, so neither is mistaken for a production number.

## 2. The daily build number
Production deploys are Cloudflare Workers Builds runs on pushes to `main` (`wrangler.jsonc` `build.command`, the
dashboard trigger). The build has no counter of its own, so the number comes from git, which makes it deterministic:
rebuilding a commit gives the same version, and Workers Builds running `npm run build` twice (once as the build
command and again as Wrangler's custom build, as the 2026-11-17 build log shows) agrees with itself.

**Rule:** walk `main`'s first-parent history back from the commit being built. `N` is the number of commits on the
same day as it, itself included, counted until the first commit from an earlier day.

**Which day:** each commit's committer date in the **committer's own recorded UTC offset** (`%cI`'s date part). The
merges on `main` are made by GitHub with the operator's offset (`-08:00`), so this is the operator's calendar day.
In UTC, today's merge 58a1140f (16:21Z) would be build 6, because the licence merges of the evening of the 16th
(01:35–01:53Z) also fall on the 17th in UTC. With the committer-local day it is `.1`, which is the operator's
example. Checked on `origin/main`: 58a1140f → `v56.11.17.1`, 26ac20c3 → `v56.11.16.5`, 4cc54a70 → `v56.11.16.1`.
Tillandsias itself counts UTC days. Here the operator's own example wins (open question 1).

**What counts as a build:** every first-parent commit on `main`. Workers Builds skipped three of the 16th's licence
merges (outcome `skipped`, Cloudflare build list, 2026-11-17), yet they still take a number. Counting only real
deploys would need the Cloudflare API at build time, which the build has no credentials for. A skipped number is
harmless, because the operator compares versions and does not count deploys.

**Production or not:** `WORKERS_CI_BRANCH == main` (a Workers Builds default variable [source: Cloudflare, "Builds
configuration: environment variables", https://developers.cloudflare.com/workers/ci-cd/builds/configuration/, read
2026-11-17]); outside Workers Builds the checked-out branch decides. Anything else is a `-dev` build. Its date is
still the commit's.

**Shallow clones:** the Workers Builds docs do not state the clone depth. On a shallow checkout the oldest visible
commit shows no parents but is not a root, so the walk counts it as inconclusive, not as the start of history. It
then runs `git fetch --deepen` (32, 128, 512) from `origin` until it sees an earlier day. If it still can't, or the
fetch fails, the number is unknown and the version is `vYY.MM.DD.0+<sha>`. That is visibly not a real number, and
the deploy still goes ahead. Tested with a `--depth 1` clone.

**Tooling language:** Node, not Lua (CLAUDE.md §9 prefers Lua). The script runs inside Workers Builds, whose image
provides Node and npm but not Lua, and `scripts/build-web.sh` already shells out to Node.

## 3. Injection
`scripts/build-web.sh` runs `node scripts/build-version.mjs --out build/version.json` once, before the Flutter
builds, and then:
- passes `--dart-define=BUILD_VERSION=<version>` to both the game and the gallery builds (the gallery keeps
  `BUILD_COMMIT`);
- copies the record to `build/web/version.json` after both builds, since the record must not be clobbered by a build.

A dart-define is used because no generated file needs committing (so CLAUDE.md §4 is unchanged). `lib/build_info.dart`
reads it and, when it is empty (`flutter run`, tests), formats `vYY.MM.DD-dev` for the local day with the same rule.
`test/fixtures/build_version_cases.json` holds cases that both the Node and the Dart formatter must reproduce.

## 4. Where it shows
`lib/widgets/build_version_label.dart` defines one 9 px dim monospace label, which ignores the pointer, and three
placements:
- the title screen: `BuildVersionCorner`, bottom left (`lib/main.dart`, one `if (title)` line);
- the pause menu: under RETURN TO TITLE (one line);
- `/console`: `Scaffold.bottomNavigationBar: BuildVersionFooter()`; `/gallery` and `/studio`:
  `MaterialApp(builder: withBuildVersion)`. Each is one added line, so the parallel `dev-pages-overhaul` rework merges
  around it.

It is not shown during play: the arena's bottom edge belongs to the controls.

## 5. `/version`
`worker/version.mjs`: `GET|HEAD /version` (also with a trailing slash; routed Worker-first in `wrangler.jsonc`)
fetches `/version.json` from the assets and returns it with `cache-control: no-store`,
`access-control-allow-origin: *` and `x-build-version: <version>`. A missing record returns 404
`{"version":"unknown"}`. That covers both an asset 404 and the single-page fallback's HTML, which doesn't parse.
`/version.json` stays reachable as a plain static asset.

Record: `{version, channel, date, build, commit, branch}`.

## 6. Open questions
1. Day boundary: committer-local (matches the operator's `v56.11.17.1`) or UTC (Tillandsias' own rule, which would
   make today's deploy `.6`)? Committer-local is implemented, and switching is a one-function change (`localDay`).
2. Should skipped Workers Builds runs take a number (they do now)?
