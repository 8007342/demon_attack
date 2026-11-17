import 'dart:convert';

import 'package:demon_attack/game/model.dart';
import 'package:flutter_test/flutter_test.dart';

import 'campaign_playtest_test.dart' show steer;

/// boss-grandeur task 2.3: boss endurance on the protected real-shot pilot
/// of `campaign_playtest_test.dart`: combat seconds from the carrier being
/// fight-ready to its fall, and the hits it takes, for all five carriers of
/// a full campaign, over the eight calibration seeds of
/// `swarm_calibration_test.dart` plus eight more. One seed's fights are
/// chaotic (a single carrier swings by ±50 % with the pilot's minion chase;
/// a campaign's sum by ±10 %), so the gate is on means over the seeds: the
/// three difficulties pooled within 5 % of [baseline], each difficulty
/// within 10 % (plan/calibration-current.md, "Boss grandeur").
const seeds = [
  1982, 7, 21, 42, 99, 314, 2718, 5150, 3, 11, 64, 128, 777, 1001, 4242, 9001,
];

/// Mean carrier seconds and hits per campaign (sum of the five carriers).
/// Seconds as measured with carrier-hatches (the boss made easier on
/// purpose, design §A11; plan/calibration-current.md, "Carrier hatches").
/// Hits re-measured with fire-rate-tune: the carrier has fewer hit points
/// for the slower gun, so it takes fewer hits by construction (was 483.9,
/// 790.8, 921.1; plan/calibration-current.md, "Fire-rate tune"). Later
/// changes stay within 5 % pooled and 10 % per difficulty of these.
const baseline = <String, ({double seconds, double hits})>{
  'easy': (seconds: 183.85, hits: 380.8),
  'normal': (seconds: 277.84, hits: 581.9),
  'hard': (seconds: 300.83, hits: 696.3),
};

/// Before carrier-hatches (`game` dde01449, the same harness): the easier
/// boss must stay at least 20 % faster to kill on every difficulty.
const preHatches = <String, ({double seconds, double hits})>{
  'easy': (seconds: 352.64, hits: 932.3),
  'normal': (seconds: 417.29, hits: 1211.7),
  'hard': (seconds: 436.03, hits: 1332.4),
};

final _measured = <String, ({double seconds, double hits})>{};

({List<double> seconds, List<int> hits}) measure(
  Difficulty difficulty,
  int seed,
) {
  final model = ArcadeModel(seed: seed)..start(difficulty: difficulty);
  final seconds = <double>[];
  final hits = <int>[];
  var fight = 0.0;
  var taken = 0;
  for (
    var frame = 0;
    frame < 900000 && model.mode != RunMode.completed;
    frame++
  ) {
    if (model.combat) {
      model.invulnerable = 2;
      steer(model);
    }
    final b = model.boss;
    final ready = b != null && _ready(b);
    model.update(1 / 60);
    if (ready && model.combat) fight += 1 / 60;
    for (final e in model.takeEvents()) {
      if (e == 'hit' && ready) taken++;
      if (e == 'bossDefeated') {
        seconds.add(fight);
        hits.add(taken);
        fight = 0;
        taken = 0;
      }
    }
  }
  return (seconds: seconds, hits: hits);
}

bool _ready(Object b) {
  try {
    return (b as dynamic).fightReady as bool;
  } on NoSuchMethodError {
    return true; // before boss-grandeur: ready on arrival
  }
}

void main() {
  for (final difficulty in Difficulty.values) {
    test('boss endurance ${difficulty.name}: mean within 5 % of baseline', () {
      var seconds = 0.0, hits = 0.0;
      final perSeed = <String, Object>{};
      for (final seed in seeds) {
        final m = measure(difficulty, seed);
        expect(m.seconds, hasLength(5), reason: 'seed $seed');
        final s = m.seconds.reduce((a, b) => a + b);
        final h = m.hits.reduce((a, b) => a + b);
        perSeed['$seed'] = [double.parse(s.toStringAsFixed(1)), h];
        seconds += s / seeds.length;
        hits += h / seeds.length;
      }
      // ignore: avoid_print
      print(
        'BOSS_ENDURANCE ${difficulty.name} seconds=${seconds.toStringAsFixed(2)} '
        'hits=${hits.toStringAsFixed(1)} ${jsonEncode(perSeed)}',
      );
      _measured[difficulty.name] = (seconds: seconds, hits: hits);
      expect(
        seconds / preHatches[difficulty.name]!.seconds,
        lessThanOrEqualTo(.8),
        reason: 'carrier-hatches: easier than before the hatches',
      );
      final base = baseline[difficulty.name]!;
      expect((seconds / base.seconds - 1).abs(), lessThanOrEqualTo(.10),
          reason: 'seconds $seconds vs ${base.seconds}');
      expect((hits / base.hits - 1).abs(), lessThanOrEqualTo(.10),
          reason: 'hits $hits vs ${base.hits}');
    });
  }
  test('boss endurance pooled over the difficulties within 5 %', () {
    double sum(Iterable<double> v) => v.reduce((a, b) => a + b);
    expect(_measured, hasLength(3));
    final s = sum(_measured.values.map((m) => m.seconds));
    final h = sum(_measured.values.map((m) => m.hits));
    final bs = sum(baseline.values.map((m) => m.seconds));
    final bh = sum(baseline.values.map((m) => m.hits));
    // ignore: avoid_print
    print('BOSS_ENDURANCE pooled seconds ${(s / bs - 1) * 100} % hits ${(h / bh - 1) * 100} %');
    expect((s / bs - 1).abs(), lessThanOrEqualTo(.05));
    expect((h / bh - 1).abs(), lessThanOrEqualTo(.05));
  });
}
