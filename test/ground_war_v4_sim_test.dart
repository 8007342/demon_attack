import 'package:demon_attack/game/model.dart';
import 'package:flutter_test/flutter_test.dart';

/// Ground war v4, "same threat, far more war": a deterministic simulation of
/// every sector, flown by protected pilots (fast and slow, routes 0 and 1,
/// every difficulty), with the skirmish layer off (the v3 ground war,
/// `SkirmishFront.enabled = false`) and on.
///
/// Threat: breakthroughs and ground missiles fired at the player must not
/// rise (zero in L1-L2, as before). War: visible ally-foe engagements per
/// minute must rise at least threefold in L1-L4.
class Tally {
  double seconds = 0;
  int breakthroughs = 0, shots = 0, engagements = 0, retreats = 0;
  int skirmishUnits = 0, falls = 0;
  double get perMinute => engagements / seconds * 60;
}

void flyLevel(Tally t, int sector, Difficulty d,
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
        final x = m.demons.where((x) => !x.entering).firstOrNull;
        if (x != null) m.hitDemon(x, damage: 99);
      }
    }
    m.update(1 / 60);
  }
  final g = m.ground;
  t
    ..seconds += combat
    ..breakthroughs += g.breakthroughs
    ..shots += g.missilesLaunched
    ..engagements += g.alliesEngaged
    ..retreats += g.alliesRetreated
    ..skirmishUnits += g.skirmish.spawned
    ..falls += g.skirmish.fallBacks;
}

List<Tally> tallies({required bool v4}) {
  SkirmishFront.enabled = v4;
  try {
    return [
      for (var s = 1; s <= 5; s++)
        () {
          final t = Tally();
          for (final d in Difficulty.values) {
            for (final k in const [.7, 1.6]) {
              for (final r in const [0, 1]) {
                flyLevel(t, s, d, killEvery: k, route: r);
              }
            }
          }
          return t;
        }(),
    ];
  } finally {
    SkirmishFront.enabled = true;
  }
}

void main() {
  test('same threat, far more war: before/after per level', () {
    final before = tallies(v4: false), after = tallies(v4: true);
    for (var s = 1; s <= 5; s++) {
      final b = before[s - 1], a = after[s - 1];
      // ignore: avoid_print
      print('L$s  before: ${(b.seconds / 60).toStringAsFixed(1)} min, '
          'breakthroughs ${b.breakthroughs}, shots ${b.shots}, '
          'engagements ${b.perMinute.toStringAsFixed(1)}/min, retreats ${b.retreats}'
          '  |  after: ${(a.seconds / 60).toStringAsFixed(1)} min, '
          'breakthroughs ${a.breakthroughs}, shots ${a.shots}, '
          'engagements ${a.perMinute.toStringAsFixed(1)}/min, retreats ${a.retreats}, '
          'skirmish units ${a.skirmishUnits}, fall-backs ${a.falls}');
    }
    for (var s = 1; s <= 2; s++) {
      final b = before[s - 1], a = after[s - 1];
      expect(a.breakthroughs, 0, reason: 'L$s: no breakthroughs, as before');
      expect(a.shots, 0, reason: 'L$s: no ground missiles at the player');
      expect(b.breakthroughs + b.shots, 0);
      expect(a.retreats, 0, reason: 'L$s: skirmishes never total an ally');
    }
    for (var s = 3; s <= 4; s++) {
      final b = before[s - 1], a = after[s - 1];
      // Same threat: the threat front is untouched by the skirmish layer.
      expect(a.breakthroughs, lessThanOrEqualTo(b.breakthroughs),
          reason: 'L$s breakthroughs');
      expect(a.shots, lessThanOrEqualTo(b.shots),
          reason: 'L$s ground shots at the player');
      expect(a.breakthroughs, greaterThan(0),
          reason: 'L$s: breakthroughs stay a later-level danger');
    }
    for (var s = 1; s <= 4; s++) {
      final b = before[s - 1], a = after[s - 1];
      expect(a.perMinute, greaterThanOrEqualTo(3 * b.perMinute),
          reason: 'L$s engagements ${b.perMinute} -> ${a.perMinute}/min');
    }
    // The carrier sector had no ground war at all; now a light one.
    expect(before[4].engagements, 0);
    expect(after[4].perMinute, greaterThan(6));
  });
}
