// The Average pilot (openspec/changes/continuous-swarm design §9, task
// 5.5): not invulnerable, 0.25 s reaction, 70 % aim, dodges the nearest
// shots. It reports lives lost per sector (the W4 baseline); it never
// fails a test.
import 'dart:math' as math;

import 'package:demon_attack/game/model.dart';

class AveragePilot {
  AveragePilot({int seed = 1}) : _rng = math.Random(seed);
  final math.Random _rng;

  /// Reaction delay (s) and aim quality.
  static const reaction = .25, aim = .7;

  final _seen = <double>[];
  double _aimError = 0, _decide = 0;

  void steer(ArcadeModel m, double dt) {
    final d =
        m.demons.where((d) => !d.entering).firstOrNull ??
        (m.demons.isEmpty ? null : m.demons.first);
    final boss = m.boss;
    final want = boss != null
        ? boss.x
        : d == null
        ? m.shipX
        : d.x;
    // What it saw a reaction time ago.
    _seen.add(want);
    final lag = (reaction / dt).round();
    while (_seen.length > lag + 1) {
      _seen.removeAt(0);
    }
    var x = _seen.first;
    _decide -= dt;
    if (_decide <= 0) {
      _decide = .5;
      _aimError = _rng.nextDouble() < aim
          ? 0
          : (_rng.nextBool() ? 1 : -1) * (20 + 20 * _rng.nextDouble());
    }
    x += _aimError;
    // Dodge: the nearest hostile shot that will cross the ship's row soon.
    Shot? threat;
    var soonest = .6;
    for (final s in m.shots) {
      if (!s.hostile || s.vy <= 0) continue;
      final t = (ArcadeModel.shipY - s.y) / s.vy;
      if (t < 0 || t > soonest) continue;
      final at = s.x + s.vx * t * m.policy.hostileRate;
      if ((at - m.shipX).abs() < 16) {
        threat = s;
        soonest = t;
      }
    }
    if (threat != null) {
      final left = m.shipX - 40, right = m.shipX + 40;
      x = (threat.x < m.shipX && right < ArcadeModel.width - 18) || left < 18
          ? right
          : left;
    }
    m.moveTo(x);
  }
}
