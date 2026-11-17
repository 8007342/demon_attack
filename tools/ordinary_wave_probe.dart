// fire-rate-tune: how hard the ordinary sectors feel, before and after a
// change to the player's weapon (openspec/changes/fire-rate-tune design §5).
//
//   dart run tools/ordinary_wave_probe.dart [seeds=8] [wind=off|on] [skill=0]
//
// --- crosswind: `wind=on` makes every eligible sector windy (the plan's own
// tiers and timings, WindPlan.forLevel(always: true); route 0 sector 1
// stays calm, as in a run), and `skill` is the share of the wind's drift
// the pilot leads its aim by. A run meets wind on one eligible level in
// five (WindPlan.chance), so the scheduled effect is a fifth of the
// difference between `wind=on` and `wind=off`.
//
// The Average pilot of continuous-swarm (test/support/average_pilot.dart:
// not invulnerable, 0.25 s reaction, 70 % aim, dodges the nearest shot)
// plays sectors 1-4 of routes 0-2 from their start, with lives refilled so
// every lost life counts and the sector goes on. It prints, per difficulty,
// the mean lives lost and the mean seconds to clear a sector, and a JSON
// line per difficulty. A measurement of workload and exposure for one
// scripted pilot, not of human survival.
import 'dart:convert';

import 'package:demon_attack/game/model.dart';

import '../test/support/average_pilot.dart';

void main(List<String> args) {
  final count = args.isEmpty ? 8 : int.parse(args.first);
  final windy = args.contains('wind=on');
  final skill = double.parse(
    args
        .firstWhere((a) => a.startsWith('skill='), orElse: () => 'skill=0')
        .substring(6),
  );
  const all = [
    1982, 7, 21, 42, 99, 314, 2718, 5150, 3, 11, 64, 128, //
    777, 1001, 4242, 9001, 5, 13, 17, 23, 29, 31, 37, 41,
  ];
  final seeds = all.take(count).toList();
  for (final difficulty in Difficulty.values) {
    var lost = 0, cleared = 0, runs = 0, withSentinel = 0;
    var sentinelSeconds = 0.0;
    var byRush = 0, byContact = 0;
    var seconds = 0.0;
    final perRoute = <String, double>{};
    for (final route in [0, 1, 2]) {
      var routeLost = 0;
      for (var sector = 1; sector <= 4; sector++) {
        for (final seed in seeds) {
          final m = ArcadeModel(seed: seed);
          if (windy) {
            m.windRun.force = (r, s) =>
                WindPlan.forLevel(seed, route: r, sector: s, always: true);
          }
          m.startAt(difficulty: difficulty, sector: sector, route: route);
          m.lives = 99;
          final pilot = AveragePilot(seed: seed, windSkill: skill);
          var t = 0.0;
          for (var f = 0; f < 60 * 900 && m.level == sector; f++) {
            if (m.mode == RunMode.salvage) {
              cleared++;
              break;
            }
            if (m.combat) {
              pilot.steer(m, 1 / 60);
              t += 1 / 60;
            }
            final sentinel = m.demons.any((d) => d.isLarge);
            if (sentinel && m.combat) sentinelSeconds += 1 / 60;
            // The likely cause of a life lost this step: a rushing
            // sentinel, a diver at the ship (contact), else a shot.
            final rush = m.demons.any((d) => d.lastStand);
            final contact = m.demons.any(
              (d) =>
                  d.dive > 0 &&
                  (d.x - m.shipX).abs() < d.contactHalf + 8 &&
                  (d.y - ArcadeModel.shipY).abs() < 40,
            );
            m.update(1 / 60);
            final lives = m.takeEvents().where((e) => e == 'life').length;
            if (sentinel) withSentinel += lives;
            if (rush) {
              byRush += lives;
            } else if (contact) {
              byContact += lives;
            }
            m.takeGameEvents();
          }
          lost += 99 - m.lives;
          routeLost += 99 - m.lives;
          seconds += t;
          runs++;
        }
      }
      perRoute['route$route'] = double.parse(
        (routeLost / seeds.length).toStringAsFixed(2),
      );
    }
    // ignore: avoid_print
    print(
      'ORDINARY_WAVES ${difficulty.name} wind=${windy ? 'on' : 'off'} '
      'skill=$skill ${jsonEncode({
        'livesPerSector': double.parse((lost / runs).toStringAsFixed(3)),
        'secondsPerSector': double.parse((seconds / runs).toStringAsFixed(1)),
        'cleared': '$cleared/$runs',
        // Lives lost, and combat seconds, while a sentinel is on the field.
        'livesWithSentinel': double.parse((withSentinel / runs).toStringAsFixed(3)),
        'sentinelSeconds': double.parse((sentinelSeconds / runs).toStringAsFixed(1)),
        'livesToRush': double.parse((byRush / runs).toStringAsFixed(3)),
        'livesToContact': double.parse((byContact / runs).toStringAsFixed(3)),
        'livesPerRoute': perRoute,
      })}',
    );
  }
}
