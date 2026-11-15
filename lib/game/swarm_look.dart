import 'dart:math' as math;

import 'model.dart';

/// Visible evasion (openspec/changes/continuous-swarm design §5,
/// plan/swarm-research.md §3.3): the swarm *looks* as if it reacts to the
/// predator. Pure presentation: a cosmetic offset per creature, clamped to a
/// third of its hitbox half-width, and a wing tilt. The model is never
/// written and hitboxes never move (gameplay dodging is W4's).
///
/// - **Agitation wave** (Procaccini et al. 2011): when a player shot's path
///   passes within 30 units of a fighting creature in the next 0.3 s, that
///   creature flinches away, and the flinch runs through its squad's
///   nearest neighbours at 40 ms per hop, 0.7 weaker each hop.
/// - **Flash expansion** (Storms et al. 2019): on a kill, neighbours within
///   50 units are pushed out and return over about 0.5 s.
/// - The vacuole (the gap closing) is the squad pattern's own (model).
class SwarmLookState {
  double x = 0, y = 0, vx = 0, vy = 0;

  /// Wing tilt, -1..1 (drawn as a small roll).
  double tilt = 0;
}

class _Hop {
  _Hop(this.demon, this.delay, this.strength, this.dirX, this.dirY, this.wave);
  final Demon demon;
  double delay;
  final double strength, dirX, dirY;
  final int wave;
}

class SwarmLook {
  final _state = Expando<SwarmLookState>('swarmLook');
  final _seenShot = Expando<bool>('swarmLookShot');
  final _hops = <_Hop>[];
  final _visited = <int, Set<Demon>>{};
  var _waves = 0;
  Set<Demon> _last = {};

  static const reach = 30.0, lookahead = .3, hop = .04, decay = .7;
  static const flashRadius = 50.0;

  /// Impulse (u/s) of a full-strength flinch and of a flash expansion.
  static const flinch = 90.0, flash = 120.0;

  /// The offset spring: about 0.5 s back to rest.
  static const stiffness = 60.0, damping = 11.0;

  SwarmLookState? of(Demon d) => _state[d];

  /// Cosmetic offset of [d] (0 when none).
  (double, double) offset(Demon d) {
    final s = _state[d];
    return s == null ? (0, 0) : (s.x, s.y);
  }

  bool _fighting(Demon d) =>
      !d.isLarge && !d.entering && d.dive == 0 && d.telegraph <= 0;

  void _kick(Demon d, double dx, double dy, double strength) {
    final s = _state[d] ??= SwarmLookState();
    s
      ..vx += dx * strength
      ..vy += dy * strength;
  }

  void update(ArcadeModel model, double dt) {
    if (dt <= 0) return;
    final demons = model.demons;
    // Flash expansion around a kill.
    final now = demons.toSet();
    for (final gone in _last.difference(now)) {
      if (gone.isLarge || gone.hp > 0) continue;
      for (final d in demons) {
        if (!_fighting(d)) continue;
        final dx = d.x - gone.x, dy = d.y - gone.y;
        final dist = math.sqrt(dx * dx + dy * dy);
        if (dist < 1 || dist > flashRadius) continue;
        _kick(d, dx / dist, dy / dist, flash * (1 - dist / flashRadius));
      }
    }
    _last = now;
    // A shot about to pass near a creature starts an agitation wave.
    for (final shot in model.shots) {
      if (shot.hostile || _seenShot[shot] != null) continue;
      Demon? first;
      var best = reach;
      var bx = 0.0, by = 0.0;
      for (final d in demons) {
        if (!_fighting(d)) continue;
        // Closest approach of the shot's path to d within the lookahead.
        final rx = d.x - shot.x, ry = d.y - shot.y;
        final v2 = shot.vx * shot.vx + shot.vy * shot.vy;
        final t = v2 <= 0
            ? 0.0
            : ((rx * shot.vx + ry * shot.vy) / v2).clamp(0.0, lookahead);
        final cx = rx - shot.vx * t, cy = ry - shot.vy * t;
        final dist = math.sqrt(cx * cx + cy * cy);
        if (dist < best) {
          best = dist;
          first = d;
          bx = cx;
          by = cy;
        }
      }
      if (first == null) continue;
      _seenShot[shot] = true;
      final n = math.max(1e-3, math.sqrt(bx * bx + by * by));
      final wave = _waves++;
      _visited[wave] = {first};
      _hops.add(_Hop(first, 0, 1, bx / n, by / n * .4, wave));
    }
    // Propagate the waves through each squad's nearest neighbours.
    final due = <_Hop>[];
    for (final h in _hops) {
      h.delay -= dt;
      if (h.delay <= 0) due.add(h);
    }
    _hops.removeWhere((h) => h.delay <= 0);
    for (final h in due) {
      final d = h.demon;
      if (!demons.contains(d)) continue;
      _kick(d, h.dirX, h.dirY, flinch * h.strength);
      final next = h.strength * decay;
      if (next < .15) continue;
      final seen = _visited[h.wave]!;
      final mates = [
        for (final o in demons)
          if (o.skein == d.skein &&
              d.skein >= 0 &&
              _fighting(o) &&
              !seen.contains(o))
            o,
      ]..sort((a, b) => _d2(a, d).compareTo(_d2(b, d)));
      for (final o in mates.take(2)) {
        seen.add(o);
        // The wave travels outward: the push points away from the source.
        final dx = o.x - d.x, dy = o.y - d.y;
        final n = math.max(1e-3, math.sqrt(dx * dx + dy * dy));
        _hops.add(
          _Hop(
            o,
            hop,
            next,
            (h.dirX + dx / n) / 2,
            (h.dirY + dy / n) * .3,
            h.wave,
          ),
        );
      }
    }
    if (_hops.isEmpty) _visited.clear();
    // Integrate the offsets and clamp them to a third of the hitbox.
    for (final d in demons) {
      final s = _state[d];
      if (s == null) continue;
      s
        ..vx += (-stiffness * s.x - damping * s.vx) * dt
        ..vy += (-stiffness * s.y - damping * s.vy) * dt
        ..x += s.vx * dt
        ..y += s.vy * dt;
      final lim = d.hitHalfWidth / 3;
      final r = math.sqrt(s.x * s.x + s.y * s.y);
      if (r > lim) {
        s
          ..x *= lim / r
          ..y *= lim / r;
      }
      s.tilt = (s.vx / flinch).clamp(-1.0, 1.0);
    }
  }

  static double _d2(Demon a, Demon b) {
    final dx = a.x - b.x, dy = a.y - b.y;
    return dx * dx + dy * dy;
  }
}
