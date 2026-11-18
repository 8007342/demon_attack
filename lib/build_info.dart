// build-version: the deploy's version stamp, vYY.MM.DD.<daily build number>
// (openspec/changes/build-version). scripts/build-web.sh computes it with
// scripts/build-version.mjs and passes it as --dart-define=BUILD_VERSION;
// this file formats the same scheme for builds without it (flutter run,
// tests). Pure Dart: no Flutter imports.

/// The version this build was stamped with; empty when built without
/// scripts/build-web.sh.
const stampedBuildVersion = String.fromEnvironment('BUILD_VERSION');

/// The Tillandsias major: years since the Unix epoch (2026 -> 56).
int epochMajor(int year) => year - 1970;

/// Formats the version: `v56.11.17.1` for the first production build of
/// 2026-11-17, `v56.11.17.0+<commit>` when the production number is unknown
/// (0), and `v56.11.17-dev[+<commit>]` for any other build. [day] is a
/// calendar date (its time of day is ignored).
String formatBuildVersion({
  required DateTime day,
  int build = 0,
  bool production = false,
  String commit = '',
}) {
  final base = 'v${epochMajor(day.year)}.${day.month}.${day.day}';
  final sha = commit.isEmpty ? '' : '+$commit';
  if (!production) return '$base-dev$sha';
  if (build <= 0) return '$base.0$sha';
  return '$base.$build';
}

/// The version to show: the stamped one, else a dev version for [now]
/// (default: today, local time).
String buildVersion({String stamped = stampedBuildVersion, DateTime? now}) =>
    stamped.isNotEmpty
    ? stamped
    : formatBuildVersion(day: now ?? DateTime.now());
