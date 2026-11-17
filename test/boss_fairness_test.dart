import 'dart:convert';

import 'package:demon_attack/game/model.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/boss_fairness.dart';

/// carrier-hatches §A11: the carrier fight made easier on purpose, checked
/// against the values measured before the change with the same harness
/// (`test/support/boss_fairness.dart`; plan/calibration-current.md,
/// "Carrier hatches"). Per difficulty: the expert's time-to-kill and lives
/// lost within their target bands, and the naive pilot's kill share.
/// Measured on `game` at dde01449 (before carrier-hatches) with this
/// harness: the expert's seconds and lives per five carriers, the naive
/// pilot's kill share.
const before = <String, ({double expert, double lives, double naiveKill})>{
  'easy': (expert: 476.7, lives: 72.67, naiveKill: .967),
  'normal': (expert: 689.3, lives: 111.83, naiveKill: .7),
  'hard': (expert: 666.0, lives: 109.83, naiveKill: .8),
};

void main() {
  for (final difficulty in Difficulty.values) {
    test('carrier fairness ${difficulty.name}: easier within its targets', () {
      final out = fairnessOf(difficulty);
      // ignore: avoid_print
      print('BOSS_FAIRNESS ${difficulty.name} ${jsonEncode(out)}');
      final b = before[difficulty.name]!;
      final e = out['expert']!, nv = out['naive']!;
      final ratio = e['seconds']! / b.expert - 1;
      final lostRatio = b.lives <= 0 ? 0.0 : e['lives']! / b.lives - 1;
      final (lo, hi, llo, lhi, killMin) = switch (difficulty) {
        Difficulty.easy => (-.30, -.20, -.35, -.25, 1.0),
        Difficulty.normal => (-.25, -.15, -.30, -.20, .9),
        Difficulty.hard => (-.15, -.05, -.20, -.10, 0.0),
      };
      expect(ratio, inInclusiveRange(lo, hi), reason: 'expert time-to-kill');
      if (b.lives > 0) {
        expect(lostRatio, inInclusiveRange(llo, lhi), reason: 'expert lives');
      }
      expect(
        nv['kill']!,
        greaterThanOrEqualTo(killMin),
        reason: 'naive pilot kill share',
      );
    });
  }
}
