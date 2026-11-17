// --- bonus level #3: Crosswind (openspec/changes/crosswind design §5-§6,
// specs/bonus-level-crosswind)
//
// A gale sweeps the sector and the brood flies its kites in it: crimson
// ember kites and jade lantern moths that ride every gust across the sky.
// Pop them. The gun fires single shots only (no Spread, no Rapid), and the
// wind bends every shot, so the player leads each kite upwind and lets the
// gust carry the shot in. The demons fly too, thinner than usual, and the
// wind bends their fire as well.
//
// Pure Dart (no dart:ui): the painter is `crosswind_painter.dart`, reached
// through `bonus_painters.dart` by the scene only. The kites draw from
// their own PRNG on the level's seed (bonus_mechanic.dart rules).
import 'dart:math' as math;

import '../../model.dart';

const crosswind = BonusLevelDef(
  id: 'crosswind',
  label: 'CROSSWIND',
  // bonus-briefing-clarity: one goal line and one how-to line. Checked
  // against CrosswindMechanic: kites cross the sky on the wind and take
  // one hit; the gun fires one shot at a time and the wind bends it.
  brief: 'Pop the kites riding the wind!',
  how: 'Single shots only. Aim upwind and let the gust carry it.',
  weight: 1,
  // The kites are the show: a thinner swarm.
  waves: BonusWaves(rosterScale: .7, reinforcementScale: .6),
  // No multifire, no Rapid: single deliberate shots (the mechanic also
  // strips any carried in, whatever the run modifier says).
  rules: PowerRules(banned: {Power.spread, Power.rapid}),
  scoring: BonusScoring(
    pointsScale: .6,
    clearPar: .2,
    flawlessPar: .1,
    capPar: .45,
  ),
  look: BonusLook(
    tint: 0xFF9FC4D8, // a cold, clear, wind-scoured blue
    strength: .2,
    glow: 0x40D8ECFF,
    fog: .04,
    cue: 'bonus-wind', // bonus-music's loop (fails soft until it exists)
  ),
  wind: true,
  mechanic: CrosswindMechanic.new,
);

/// One kite riding the wind.
class Kite {
  Kite(this.index, this.species, this.x, this.y, this.phase, this.side);
  final int index;

  /// 0 ember kite, 1 lantern moth (WindKitesAtlas rows).
  final int species;
  double x, y;
  final double phase;

  /// The side it came in from (-1 left, 1 right, 0 the top).
  final int side;
  double vx = 0, age = 0;

  /// The height it rides at (it bobs about it).
  double ride = 0;

  /// Seconds since it popped (null: flying).
  double? popped;

  /// It rode off the screen (or, at the end of the level, was let go).
  bool gone = false;

  /// Half its size for a hit (units): the ember kite is tall, the moth wide.
  double get halfW => species == 0 ? 9 : 12;
  double get halfH => species == 0 ? 12 : 7;

  /// Its bank in degrees (+ leans right), from its speed across the wind.
  double get bankDeg => (vx / 70 * 24).clamp(-24.0, 24.0);
}

/// Crosswind's rule of play: the kites, and the single-shot gun.
class CrosswindMechanic extends BonusMechanic {
  CrosswindMechanic(BonusMechanicContext c)
    : _rng = math.Random((c.seed ^ 0xC0157) & 0x3fffffff),
      perWave = 3 + math.min(c.route, 2);

  final math.Random _rng;

  /// Kites launched per wave of the level.
  final int perWave;

  /// At most this many in the sky at once.
  static const maxAlive = 3;

  /// Seconds between launches (the first comes soon after the start).
  static const every = 2.8, first = 1.5;

  /// Points per kite, × (route + 1), inside the level's cap.
  static const kitePoints = 120;

  /// A kite rides the wind this much harder than a shot does.
  static const ride = 1.5;

  /// A kite that has flown this long climbs away.
  static const maxAge = 15.0;

  /// The pop's drawn life (s).
  static const popLife = .6;

  final kites = <Kite>[];
  int launched = 0, popped = 0, escaped = 0;
  double _next = first;
  int _wave = 0, _waveLaunched = 0;

  /// Every kite launched so far came down (the challenge's condition).
  bool get everyKite => escaped == 0 && popped == launched;

  @override
  void step(ArcadeModel model, double dt) {
    final m = model;
    _singleShots(m);
    _fly(m, dt);
    if (!m.combat || m.shipAway) return;
    if (m.wave != _wave) {
      _wave = m.wave;
      _waveLaunched = 0;
    }
    _next -= dt;
    final alive = kites.where((k) => k.popped == null && !k.gone).length;
    if (_next <= 0 && alive < maxAlive && _waveLaunched < perWave) {
      _launch(m);
      _next = every;
    }
    _hits(m);
  }

  @override
  void idle(ArcadeModel model, double dt) {
    // Outside combat the kites are let go: they climb away and no longer
    // count (the clear is not the player's miss).
    for (final k in kites) {
      if (k.popped == null && !k.gone) k.y -= 60 * dt;
      if (k.y < -30) k.gone = true;
    }
    _age(dt);
  }

  /// No Spread and no Rapid, ever, in this level: carried-in modules are
  /// stripped and such drops vanish (a run modifier cannot bring them).
  void _singleShots(ArcadeModel m) {
    m.powerTimers.remove(Power.spread);
    m.powerTimers.remove(Power.rapid);
    m.pickups.removeWhere(
      (p) =>
          p.bonus == null &&
          (p.power == Power.spread || p.power == Power.rapid),
    );
  }

  void _launch(ArcadeModel m) {
    // Fixed draws per kite: species, height, phase, side.
    final su = _rng.nextDouble(), hu = _rng.nextDouble();
    final pu = _rng.nextDouble(), xu = _rng.nextDouble();
    final drift = m.windDrift;
    final species = su < .5 ? 0 : 1;
    final ride = 60 + 150 * hu;
    // In from the upwind edge; in a lull, down from the top.
    final side = drift.abs() < 10 ? 0 : (drift > 0 ? -1 : 1);
    final x = side == 0 ? 50 + 260 * xu : (side < 0 ? -16.0 : 376.0);
    final y = side == 0 ? -16.0 : ride;
    kites.add(
      Kite(launched, species, x, y, pu * math.pi * 2, side)..ride = ride,
    );
    launched++;
    _waveLaunched++;
  }

  void _fly(ArcadeModel m, double dt) {
    final drift = m.windDrift;
    for (final k in kites) {
      if (k.popped != null || k.gone) continue;
      k.age += dt;
      // It rides the gust: its speed settles toward the wind's, harder
      // than a shot's, with a little push of its own the way it came in.
      final own = k.side == 0 ? 0.0 : -k.side * 14.0;
      k.vx += (drift * ride + own - k.vx) * math.min(1.0, dt / .8);
      k.x += k.vx * dt;
      if (k.age > maxAge) {
        k.y -= 50 * dt; // tired of the game: it climbs away
      } else {
        final bob = 12 * math.sin(k.age * 1.4 + k.phase);
        final want = k.ride + bob;
        k.y += (want - k.y) * math.min(1.0, dt * 1.5);
      }
      if (k.x < -40 || k.x > ArcadeModel.width + 40 || k.y < -40) {
        k.gone = true;
        if (m.combat) {
          escaped++;
          m.bonusEvent(GameEventNames.kiteEscaped, {
            'kites': popped,
            'escaped': escaped,
            'total': launched,
            'x': k.x.clamp(0.0, ArcadeModel.width),
          });
        }
      }
    }
    _age(dt);
  }

  void _age(double dt) {
    for (final k in kites) {
      final p = k.popped;
      if (p != null) k.popped = p + dt;
    }
    kites.removeWhere((k) => k.gone || (k.popped ?? 0) > popLife);
  }

  void _hits(ArcadeModel m) {
    for (final k in kites) {
      if (k.popped != null || k.gone) continue;
      for (final s in m.shots) {
        if (s.hostile) continue;
        final reach = s.blastRadius > 0 ? 6.0 : 2.0;
        if ((s.x - k.x).abs() > k.halfW + reach ||
            (s.y - k.y).abs() > k.halfH + reach) {
          continue;
        }
        k.popped = 0;
        popped++;
        m.shots.remove(s);
        final award = m.bonusAward(kitePoints * (m.cycle + 1));
        m.events.add('hit');
        m.bonusEvent(GameEventNames.kitePopped, {
          'kites': popped,
          'escaped': escaped,
          'total': launched,
          'x': k.x,
          'award': award,
        });
        break;
      }
    }
  }
}
