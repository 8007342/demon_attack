import 'package:demon_attack/game/model.dart';
import 'package:flutter_test/flutter_test.dart';

/// One level flown by a protected pilot that kills an air demon every
/// [killEvery] seconds. Returns (combat seconds, breakthroughs, ground
/// missiles launched, engagements).
(double, int, int, int) flyLevel(int sector, Difficulty d,
    {double killEvery = .7, int route = 0, double maxSeconds = 150}) {
  final m = ArcadeModel(seed: 1982)
    ..startAt(difficulty: d, sector: sector, route: route);
  var next = 0.0, combat = 0.0;
  for (var f = 0; f < 60 * 60 * 6; f++) {
    if (m.level != sector || combat > maxSeconds) break;
    if (m.combat) {
      combat += 1 / 60;
      m.invulnerable = 2;
      if (m.levelClock >= next) {
        next = m.levelClock + killEvery;
        final t = m.demons.where((x) => !x.entering).firstOrNull;
        if (t != null) m.hitDemon(t, damage: 99);
      }
    }
    m.update(1 / 60);
  }
  final g = m.ground;
  return (combat, g.breakthroughs, g.missilesLaunched, g.alliesEngaged);
}

/// Totals per sector 1-5 over pilots, routes and difficulties.
List<(double, int, int, int)> totals() => [
      for (var s = 1; s <= 5; s++)
        () {
          var t = 0.0;
          var b = 0, shots = 0, e = 0;
          for (final d in Difficulty.values) {
            for (final k in const [.7, 1.6]) {
              for (final r in const [0, 1]) {
                final x = flyLevel(s, d, killEvery: k, route: r);
                t += x.$1;
                b += x.$2;
                shots += x.$3;
                e += x.$4;
              }
            }
          }
          return (t, b, shots, e);
        }(),
    ];

void main() {
  test('ground war v4 numbers', () {
    final all = totals();
    for (var s = 1; s <= 5; s++) {
      final (t, b, shots, e) = all[s - 1];
      // ignore: avoid_print
      print('L$s: ${(t / 60).toStringAsFixed(1)} min, breakthroughs $b, '
          'shots $shots, engagements $e (${(e / t * 60).toStringAsFixed(1)}/min)');
    }
  });
}
