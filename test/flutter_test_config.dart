import 'dart:async';

import 'package:demon_attack/main.dart' as app;

/// Runs before every test file (flutter_test). Bonus levels: page-level
/// tests start runs without a run seed, so they play the calibrated
/// campaign with no bonus level and no run modifier, whatever the clock.
/// A test that wants a seeded run sets `app.arcadeRunSeed` itself (and
/// restores it).
Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  app.arcadeRunSeed = () => null;
  await testMain();
}
