import 'dart:convert';

import 'package:demon_attack/game/model.dart';

/// carrier-hatches §A11: the carrier-fairness harness (pure Dart, so it
/// also runs headless: `dart run test/support/boss_fairness.dart`). Two
/// pilots play each tour's carrier from the boss level's start, unprotected
/// but with lives refilled, so every lost life is counted and the fight
/// goes on:
/// - the expert leads every target by the forecast (the campaign pilot);
/// - the naive pilot aims at where the target is now, as a new player does.
/// It reads the hatch API dynamically, so it also ran on the code before
/// the change (the "before" values).
const fairnessSeeds = [1982, 7, 21, 42, 99, 314];
const fairnessCap = 240.0;

/// Where the pilot aims for carrier [b]: the target's x when a shot fired
/// now arrives ([lead]) or where it is now.
double fairnessAim(ArcadeModel m, Carrier b, {required bool lead}) {
  var dx = 0.0, dy = 25.0;
  try {
    final d = b as dynamic;
    if ((d.chapter as Object).toString().endsWith('hatches')) {
      double best = double.infinity;
      for (final h in (d.vulnerableHatches as Iterable)) {
        final hx = (h.hatch.x as num).toDouble();
        final dist = (b.x + hx - m.shipX).abs();
        if (dist < best) {
          best = dist;
          dx = hx;
          dy = (h.hatch.y as num).toDouble();
        }
      }
    }
  } on NoSuchMethodError {
    // Before the change: the field over the deck, then the core door.
    dy = b.shield > 0 ? 50 : 25;
  }
  if (!lead) return b.x + dx;
  final flight = (ArcadeModel.shipY - (b.y + dy)) / ArcadeModel.shotSpeed;
  return b.forecastX(flight, m.speed) + dx;
}

({double seconds, int lives, bool killed}) fairnessFight(
  Difficulty difficulty,
  int route,
  int seed, {
  required bool lead,
}) {
  final m = ArcadeModel(seed: seed)
    ..startAt(difficulty: difficulty, sector: 5, route: route);
  var seconds = 0.0;
  var lives = 0;
  for (var f = 0; f < 60 * 900; f++) {
    m.lives = 9;
    final b = m.boss;
    final ready = b != null && b.fightReady && m.combat;
    if (b != null && m.combat) {
      m.moveTo(fairnessAim(m, b, lead: lead));
    } else if (m.combat && m.demons.isNotEmpty) {
      final d =
          m.demons.where((d) => !d.entering).firstOrNull ?? m.demons.first;
      final flight = (ArcadeModel.shipY - d.y) / ArcadeModel.shotSpeed;
      m.moveTo(lead ? d.x + d.vx * flight : d.x);
    }
    m.update(1 / 60);
    if (ready) seconds += 1 / 60;
    for (final e in m.takeEvents()) {
      if (e == 'life' && ready) lives++;
      if (e == 'bossDefeated') {
        return (seconds: seconds, lives: lives, killed: true);
      }
    }
    if (seconds >= fairnessCap) break;
  }
  return (seconds: seconds, lives: lives, killed: false);
}

/// Per pilot: mean seconds and lives per campaign's five carriers (summed
/// over the tours, averaged over the seeds) and the kill share.
Map<String, Map<String, double>> fairnessOf(Difficulty difficulty) {
  final out = <String, Map<String, double>>{};
  for (final lead in [true, false]) {
    var seconds = 0.0, lives = 0, kills = 0, n = 0;
    for (var route = 0; route < 5; route++) {
      for (final seed in fairnessSeeds) {
        final r = fairnessFight(difficulty, route, seed, lead: lead);
        seconds += r.seconds;
        lives += r.lives;
        if (r.killed) kills++;
        n++;
      }
    }
    out[lead ? 'expert' : 'naive'] = {
      'seconds': double.parse(
        (seconds / fairnessSeeds.length).toStringAsFixed(1),
      ),
      'lives': double.parse((lives / fairnessSeeds.length).toStringAsFixed(2)),
      'kill': double.parse((kills / n).toStringAsFixed(3)),
    };
  }
  return out;
}

void main(List<String> args) {
  for (final d in Difficulty.values) {
    if (args.isNotEmpty && !args.contains(d.name)) continue;
    // ignore: avoid_print
    print('BOSS_FAIRNESS ${d.name} ${jsonEncode(fairnessOf(d))}');
  }
}
