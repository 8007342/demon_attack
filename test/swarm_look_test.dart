// Visible evasion (lib/game/swarm_look.dart, continuous-swarm design §5,
// task 6.3): a ripple runs through the squad, within a third of the
// hitbox, and the simulation never moves for it.
import 'dart:math' as math;

import 'package:demon_attack/game/model.dart';
import 'package:demon_attack/game/swarm_look.dart';
import 'package:flutter_test/flutter_test.dart';

ArcadeModel _fight() {
  final m = ArcadeModel(seed: 9)
    ..startAt(difficulty: Difficulty.normal, sector: 2, route: 1);
  for (var i = 0; i < 60 * 12; i++) {
    m.invulnerable = 5;
    m.shots.removeWhere((s) => !s.hostile);
    m.update(1 / 60);
  }
  return m;
}

void main() {
  test('a shot through a squad ripples outward from the nearest creature', () {
    final m = _fight();
    final look = SwarmLook();
    final d = m.demons.firstWhere(
      (d) => !d.isLarge && !d.entering && d.dive == 0 && d.telegraph <= 0,
    );
    m.shots.add(Shot(d.x + 12, d.y + 60, 0, -390));
    final reached = <Demon, int>{};
    for (var f = 0; f < 30; f++) {
      look.update(m, 1 / 60);
      for (final o in m.demons) {
        final s = look.of(o);
        if (s != null && reached[o] == null && (s.vx.abs() + s.vy.abs()) > 1) {
          reached[o] = f;
        }
        if (s != null) {
          final r = math.sqrt(s.x * s.x + s.y * s.y);
          expect(r, lessThanOrEqualTo(o.hitHalfWidth / 3 + 1e-9));
        }
      }
    }
    expect(
      reached.values.reduce(math.min),
      0,
      reason: 'the creature nearest the path flinches at once',
    );
    expect(reached.length, greaterThan(1), reason: 'the wave travels');
    expect(reached.values.reduce(math.max), greaterThan(0));
  });

  test('the model is never moved by the look', () {
    final a = _fight(), b = _fight();
    final look = SwarmLook();
    for (var f = 0; f < 240; f++) {
      a.invulnerable = b.invulnerable = 5;
      a.update(1 / 60);
      b.update(1 / 60);
      look.update(a, 1 / 60);
      expect(
        [for (final d in a.demons) (d.x, d.y, d.hitHalfWidth)],
        [for (final d in b.demons) (d.x, d.y, d.hitHalfWidth)],
      );
    }
  });
}
