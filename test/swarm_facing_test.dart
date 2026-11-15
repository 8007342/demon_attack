// Sideways facing (openspec/changes/continuous-swarm tasks 1.2, 6.2): the
// share of drawn ordinary-creature flight frames that use a banked render
// (CreatureMotion.dir != 0) over 60 s of Normal sector-2 combat, driven
// from the simulation alone (no rendering). Telegraph, dive and dive-prep
// poses have their own cells and are excluded.
import 'dart:convert';
import 'dart:io';

import 'package:demon_attack/game/creature_motion.dart';
import 'package:demon_attack/game/model.dart';
import 'package:flutter_test/flutter_test.dart';

import 'campaign_playtest_test.dart' show steer;

class FacingSample {
  int frames = 0, banked = 0;

  /// Shortest run of one direction (s) that ended in a change, over all
  /// creatures (flicker check).
  double shortestHold = double.infinity;
  double get share => frames == 0 ? 0 : banked / frames;
}

FacingSample measureFacing({int seed = 1982, double seconds = 60}) {
  final m = ArcadeModel(seed: seed)
    ..startAt(difficulty: Difficulty.normal, sector: 2);
  final tracker = CreatureMotionTracker();
  final sample = FacingSample();
  final held = Expando<double>('held');
  final lastDir = Expando<int>('dir');
  var combat = 0.0;
  for (var f = 0; f < 60 * 600 && combat < seconds; f++) {
    if (m.combat) {
      m.invulnerable = 2;
      steer(m);
    }
    m.update(1 / 60);
    tracker.update(m, 1 / 60);
    if (!m.combat) continue;
    combat += 1 / 60;
    for (final d in m.demons) {
      if (d.isLarge) continue;
      if (d.entering && d.entranceProgress <= 0) continue; // parked
      final motion = tracker.of(d);
      if (motion == null) continue;
      final prev = lastDir[d];
      if (prev != null && prev != motion.dir) {
        // The first run starts mid-hold (creation): only later runs count.
        final h = held[d];
        if (h != null && h < sample.shortestHold) sample.shortestHold = h;
        held[d] = 0;
      }
      lastDir[d] = motion.dir;
      final h = held[d];
      if (h != null) held[d] = h + 1 / 60;
      if (d.telegraph > 0 || d.dive > 0 || d.divePrep > 0) continue;
      sample.frames++;
      if (motion.dir != 0) sample.banked++;
    }
  }
  return sample;
}

void main() {
  test('banked renders over a minute of Normal sector-2 combat', () {
    final s = measureFacing();
    final out = File(
      Platform.environment['SWARM_FACING_PATH'] ?? '.cache/swarm-facing.json',
    );
    out.parent.createSync(recursive: true);
    out.writeAsStringSync(
      jsonEncode({
        'frames': s.frames,
        'banked': s.banked,
        'share': s.share,
        'shortestHold': s.shortestHold,
      }),
    );
    // ignore: avoid_print
    print(
      'facing: ${(s.share * 100).toStringAsFixed(1)} % banked of '
      '${s.frames} frames, shortest hold ${s.shortestHold}',
    );
    expect(s.frames, greaterThan(1000));
    // Task 6.2 (baseline 13.3 %, plan/calibration-current.md): banked
    // renders are the common case, and no direction flickers.
    expect(s.share, greaterThanOrEqualTo(.5));
    expect(s.shortestHold, greaterThanOrEqualTo(CreatureMotion.minHold - 1e-9));
  });
}
