part of 'model.dart';

// ===========================================================================
// Life-loss sequence: explosion -> regroup -> re-emergence.
//
// A non-final hit no longer leaves the ship in place with invulnerability.
// The ship breaks apart (a multi-frame pixel explosion, hull shards and the
// fitted modules flying), then the swarm regroups while every hostile shot
// fizzles out and nothing can hit the player, then the reserve ship flies up
// from the bottom edge with blinking protection and play goes straight on.
// Scoring, lives and the loadout rules are unchanged: offensive modules
// survive the loss (they fly off as debris visually and are re-fitted on the
// reserve ship) and their timers are frozen while the ship is away.
//
// Events (lib/game/game_events.dart): `playerDestroyed` at the hit,
// `regroupStart` when the explosion gives way to the regroup, and
// `playerRespawn` when the reserve ship starts to fly in.
// Design: openspec/changes/gameplay-round-3/design.md.
// ===========================================================================

enum LifeLossPhase { none, exploding, regrouping, emerging }

/// Every life-loss tunable in one place (seconds, arena units).
abstract final class LifeLossTuning {
  /// The ship explosion before the regroup starts.
  static const explode = .7;

  /// The regroup pause: shots drain, the swarm reforms, nothing can hit.
  static const regroup = 1.6;

  /// Hostile shots fizzle at a random moment within this window.
  static const drainWindow = .35;

  /// The reserve ship's fly-in from below the bottom edge.
  static const emerge = .55;

  /// Blinking protection from the start of the fly-in.
  static const protection = 2.0;

  /// Where the fly-in starts (below the arena).
  static const emergeFromY = ArcadeModel.height + 26;

  /// The swarm's fastest regroup speed back to formation.
  static const regroupSpeedX = 240.0, regroupSpeedY = 200.0;

  /// Total ship-away time (explosion + regroup).
  static const away = explode + regroup;
}

/// A piece of the destroyed ship: a hull shard, or one of its fitted
/// modules ([power] non-null). Visual only.
class ShipDebris {
  ShipDebris(
    this.x,
    this.y,
    this.vx,
    this.vy,
    this.vRot, {
    this.power,
    this.size = 3,
    this.tone = 0,
  });
  double x, y, vx, vy, rotation = 0, age = 0;
  final double vRot, size;
  final Power? power;

  /// Shade index into the ship palette (0 hull light .. 3 burnt).
  final int tone;
  static const life = 1.6;
}

/// A hostile shot fizzling out during the regroup. Visual only.
class ShotFizzle {
  ShotFizzle(this.x, this.y, {this.sentinel = false});
  final double x, y;
  final bool sentinel;
  double age = 0;
  static const life = .32;
}

extension LifeLossSequence on ArcadeModel {
  /// A non-final life was lost at the ship's position: start the sequence.
  void _beginLifeLoss() {
    lifeLossPhase = LifeLossPhase.exploding;
    lifeLossLeft = LifeLossTuning.explode;
    lifeLossX = shipX;
    invulnerable = LifeLossTuning.away + LifeLossTuning.protection + 1;
    _spawnShipDebris();
    // A rich multi-stage blast: core, then staggered secondaries.
    blasts.addAll([
      Blast(shipX, ArcadeModel.shipY, big: true),
      Blast(shipX - 12, ArcadeModel.shipY - 7)..age = -0.07,
      Blast(shipX + 13, ArcadeModel.shipY - 4)..age = -0.14,
      Blast(shipX - 6, ArcadeModel.shipY + 6)..age = -0.22,
      Blast(shipX + 8, ArcadeModel.shipY + 8)..age = -0.3,
    ]);
    // Dives and tells stop at once: the swarm is about to regroup.
    for (final d in demons) {
      if (d.lastStand) continue;
      d.telegraph = 0;
      d.divePrep = 0;
    }
  }

  void _spawnShipDebris() {
    shipDebris.clear();
    for (var i = 0; i < 18; i++) {
      final a = -math.pi * (.08 + .84 * random.nextDouble());
      final v = 70 + random.nextDouble() * 150;
      shipDebris.add(
        ShipDebris(
          shipX + (random.nextDouble() - .5) * 14,
          ArcadeModel.shipY + (random.nextDouble() - .5) * 8,
          math.cos(a) * v,
          math.sin(a) * v,
          (random.nextBool() ? 1 : -1) * (4 + random.nextDouble() * 8),
          size: 2 + random.nextInt(3).toDouble(),
          tone: random.nextInt(4),
        ),
      );
    }
    // The fitted modules tumble away too (visual: the loadout survives).
    var k = 0;
    for (final p in activePowers) {
      if (p == Power.shield) continue;
      final side = k.isEven ? -1.0 : 1.0;
      shipDebris.add(
        ShipDebris(
          shipX + side * 10,
          ArcadeModel.shipY - 4,
          side * (60 + 30 * k),
          -150 - 20 * k.toDouble(),
          side * 7,
          power: p,
          size: 6,
        ),
      );
      k++;
    }
  }

  /// One fixed step of the sequence (combat mode only).
  void _updateLifeLoss(double dt) {
    for (final d in shipDebris) {
      d.vy += 210 * dt;
      d.vx *= math.exp(-.6 * dt);
      d.x += d.vx * dt;
      d.y += d.vy * dt;
      d.rotation += d.vRot * dt;
      d.age += dt;
    }
    shipDebris.removeWhere(
      (d) => d.age > ShipDebris.life || d.y > ArcadeModel.height + 30,
    );
    for (final f in shotFizzles) {
      f.age += dt;
    }
    shotFizzles.removeWhere((f) => f.age > ShotFizzle.life);
    if (lifeLossPhase == LifeLossPhase.none) return;
    lifeLossLeft = math.max(0, lifeLossLeft - dt);
    switch (lifeLossPhase) {
      case LifeLossPhase.exploding:
        if (lifeLossLeft <= 0) _beginRegroup();
      case LifeLossPhase.regrouping:
        _drainHostileShots(dt);
        if (lifeLossLeft <= 0) _beginEmergence();
      case LifeLossPhase.emerging:
        if (lifeLossLeft <= 0) lifeLossPhase = LifeLossPhase.none;
      case LifeLossPhase.none:
        break;
    }
  }

  void _beginRegroup() {
    lifeLossPhase = LifeLossPhase.regrouping;
    lifeLossLeft = LifeLossTuning.regroup;
    var shots = 0;
    for (final s in this.shots) {
      if (!s.hostile) continue;
      s.fizzleIn = random.nextDouble() * LifeLossTuning.drainWindow;
      shots++;
    }
    var missiles = 0;
    for (final m in ground.missiles) {
      if (m.spent) continue;
      m.spent = true;
      shotFizzles.add(ShotFizzle(m.x, m.y));
      missiles++;
    }
    for (final u in ground.units) {
      if (u.telegraph > 0) u.telegraph = 0;
      u.firePrep = 0;
    }
    _queueGameEvent(GameEventNames.regroupStart, {
      'x': lifeLossX,
      'y': ArcadeModel.shipY,
      'lives': lives,
      'duration': LifeLossTuning.regroup,
      'shotsDrained': shots,
      'missilesDrained': missiles,
    });
  }

  void _drainHostileShots(double dt) {
    for (final s in shots) {
      if (!s.hostile || s.fizzleIn == null) continue;
      s.fizzleIn = s.fizzleIn! - dt;
      if (s.fizzleIn! <= 0) {
        shotFizzles.add(
          ShotFizzle(s.x, s.y, sentinel: s.kind == ShotKind.sentinel),
        );
        s.y = ArcadeModel.height + 40;
      }
    }
    // Anything that slipped in (none should: hostile fire is held) drains too.
    for (final s in shots) {
      if (s.hostile && s.fizzleIn == null) s.fizzleIn = 0;
    }
  }

  void _beginEmergence() {
    lifeLossPhase = LifeLossPhase.emerging;
    lifeLossLeft = LifeLossTuning.emerge;
    // Any hostile shot still around ends now; the reserve ship starts clean.
    for (final s in shots) {
      if (s.hostile) {
        shotFizzles.add(ShotFizzle(s.x, s.y));
        s.y = ArcadeModel.height + 40;
      }
    }
    shipX = targetX = ArcadeModel.width / 2;
    shipVx = shipBank = shipThrust = 0;
    invulnerable = LifeLossTuning.protection;
    _fire = LifeLossTuning.emerge;
    // Ground launchers reload while the reserve flies in.
    for (final u in ground.units) {
      u.cooldown = math.max(u.cooldown, 1.2);
    }
    _queueGameEvent(GameEventNames.playerRespawn, {
      'x': shipX,
      'y': ArcadeModel.shipY,
      'lives': lives,
      'protection': LifeLossTuning.protection,
    });
  }

  /// Hostile fire, dives and ground launches are held while the ship is
  /// away (exploding or regrouping).
  bool get holdHostileFire =>
      lifeLossPhase == LifeLossPhase.exploding ||
      lifeLossPhase == LifeLossPhase.regrouping;

  /// The swarm regroups: every demon not entering flies back to its
  /// formation slot (dives pull out), at a bounded speed.
  bool _regroupDemon(Demon d, double prevX, double prevY, double dt) {
    if (!holdHostileFire || d.entering || d.lastStand) return false;
    if (d.dive > 0) {
      d.dive = 0;
      d.diveShield = 0;
      d.diveShieldMax = 0;
    }
    d.telegraph = 0;
    d.divePrep = 0;
    final (tx, ty) = _targetFormationPosition(d);
    d.x += (tx - d.x).clamp(
      -LifeLossTuning.regroupSpeedX * dt,
      LifeLossTuning.regroupSpeedX * dt,
    );
    d.y += (ty - d.y).clamp(
      -LifeLossTuning.regroupSpeedY * dt,
      LifeLossTuning.regroupSpeedY * dt,
    );
    _updateDemonKinematics(d, prevX, prevY, dt);
    return true;
  }
}
