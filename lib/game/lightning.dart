part of 'model.dart';

// ===========================================================================
// lightning-rework (openspec/changes/lightning-rework): what a bolt does,
// whatever storm throws it (today only Stormfront; regular sectors have no
// lightning, by dynamic-weather's decision).
//
// - A creature in a bolt's column is STUNNED, never killed: it drops out of
//   the sky for a moment, then beats its wings and climbs back to its place.
//   While stunned it cannot fire, dive or dodge, and its shield and armour
//   are down. Shot down while stunned it scores its ordinary points.
// - The SHIP in a bolt's core is ZAPPED, never destroyed: every shield and
//   power-up is stripped at once, then a short grace keeps the next bolt
//   (a fork in the same instant) from striking it again.
// - Higher RANKS see the tell coming: a deterministic share of each rank,
//   growing with the rank and the route, sidesteps out of the told column.
// - LIGHTNING-ROD ARMOUR (sentinels from tour 2, hunters from tour 3, in a
//   storm) draws bolts from a wider reach and turns them into a CHARGE: a
//   few seconds of faster fire instead of a stun.
//
// Pure Dart. Nothing here draws from `random`: a storm's schedule and its
// effects never shift the simulation stream.
// ===========================================================================

/// Every lightning tunable in one place (seconds, arena units).
abstract final class LightningTuning {
  /// A small creature's fall: seconds, acceleration (u/s²) and the deepest
  /// it drops below the height it was struck at.
  static const fall = .45, gravity = 400.0, maxDrop = 44.0;

  /// A sentinel is heavy and armoured: a shorter, shallower sag.
  static const largeFall = .28, largeDrop = 18.0;

  /// The climb back to its place (u/s).
  static const climbX = 150.0, climbY = 130.0;

  /// Shortest climb, and the longest a whole stun may last.
  static const minRecover = .45, maxStun = 1.8;

  /// A stunned creature never falls closer than this above the ship's row.
  static const floorAboveShip = 70.0;

  /// The ship's lightning grace after a zap (no bolt strikes it again), and
  /// how long the zap shows on the ship (presentation).
  static const shipGrace = 1.5, shipShock = .9;

  /// A rod-armoured creature's charge (s) and its fire-rate factor.
  static const charge = 5.0, chargedRate = 1.8;

  /// Rods catch a bolt this far from its column's centre (u)...
  static const rodReach = 58.0;

  /// ...and draw a rod-armoured creature toward a tell this near (u).
  static const rodLure = 96.0;

  /// Per rank (R0 drone .. R4 sentinel, the insignia ladder): the share
  /// that dodges a tell on it, the tell progress (0-1) at which it reacts,
  /// and its sidestep speed (u/s).
  static const dodgeChance = [0.0, .25, .45, .7, .85];
  static const dodgeReact = [1.0, .4, .35, .25, .25];
  static const dodgeSpeed = [0.0, 150.0, 160.0, 190.0, 140.0];

  /// Each later route sharpens every marked rank by this much (routes 0-4).
  static const routeDodge = .04;

  /// How far past the column's edge a dodger aims (u).
  static const dodgeMargin = 10.0;

  /// Rod armour: sentinels from this route (0-based) on, hunters from this.
  static const rodSentinelRoute = 1, rodHunterRoute = 2;
}

/// A lightning tell, as a creature sees it.
typedef LightningTell = ({int index, double x, double column, double progress});

/// What one bolt did to the brood.
class LightningHit {
  final List<Demon> stunned = [], charged = [];
}

/// The creature's rank on the insignia ladder (0 drone .. 4 sentinel), as
/// `CombatAtlas.rankOf` draws it (the model may not import the atlas).
int lightningRank(Demon d) {
  if (d.isLarge) return 4;
  if (d.elite) return 3;
  if (d.kind >= 2 || d.maxHp >= 3) return d.maxHp >= 4 ? 2 : 1;
  return 0;
}

/// The share of rank [rank] that dodges on route [route].
double lightningDodgeChance(int rank, int route) => rank <= 0
    ? 0
    : math.min(
        .95,
        LightningTuning.dodgeChance[rank.clamp(0, 4)] +
            LightningTuning.routeDodge * route.clamp(0, 4),
      );

/// A creature's fixed roll (0-1) for strike [strike]: it dodges when the
/// roll is under its rank's chance, so a higher rank dodges every bolt a
/// lower one would. Integer-only below 2^53 (the same on the web).
double lightningRoll(Demon d, int strike) {
  var h = ((d.seed * 997).round() ^ (strike * 7919)) & 0xffffff;
  for (var i = 0; i < 3; i++) {
    h = (h * 0x2c1b3 + 0x9e37) & 0xffffff;
    h ^= h >> 11;
  }
  return h / 0x1000000;
}

/// Whether [d] wears lightning-rod armour on route [route] in a storm.
bool lightningRodArmour(Demon d, int route) =>
    (d.isLarge && route >= LightningTuning.rodSentinelRoute) ||
    (d.elite && !d.isLarge && route >= LightningTuning.rodHunterRoute);

extension ArcadeLightning on ArcadeModel {
  /// A bolt lands on the column [x] ± [column]: every creature in it is
  /// stunned, every rod-armoured one within [LightningTuning.rodReach] is
  /// charged. [stunEvent] names the structured event for the stun (null:
  /// none); [data] rides along with it.
  LightningHit strikeLightning(
    double x,
    double column, {
    String? stunEvent = GameEventNames.lightningStun,
    Map<String, Object?> data = const {},
  }) {
    final out = LightningHit();
    if (!combat) return out;
    for (final d in demons) {
      if (d.entering || d.lastStand || d.gateWait > 0) continue;
      final dx = (d.x - x).abs();
      if (d.lightningRods) {
        if (dx > math.max(column, LightningTuning.rodReach)) continue;
        d
          ..charged = LightningTuning.charge
          ..flash = .12;
        out.charged.add(d);
        continue;
      }
      if (dx > column) continue;
      _stun(d);
      out.stunned.add(d);
    }
    if (out.stunned.isNotEmpty) {
      events.add('stormStun');
      if (stunEvent != null) {
        _queueGameEvent(stunEvent, {
          ...data,
          'x': x,
          'stunned': out.stunned.length,
        });
      }
    }
    if (out.charged.isNotEmpty) {
      events.add('demonCharged');
      _queueGameEvent(GameEventNames.lightningCharged, {
        'x': x,
        'charged': out.charged.length,
      });
    }
    return out;
  }

  void _stun(Demon d) {
    final large = d.isLarge;
    d
      ..stun = LightningTuning.maxStun
      ..stunFall = large ? LightningTuning.largeFall : LightningTuning.fall
      ..stunVy = 0
      ..stunFromY = d.y
      ..flash = .12
      // The bolt breaks whatever it was doing: no dive, no tell, no dodge.
      ..dive = 0
      ..diveShield = 0
      ..diveShieldMax = 0
      ..telegraph = 0
      ..divePrep = 0
      ..pincer = 0
      ..evadeLeft = 0
      ..boltDodgeGoal = 0;
  }

  /// A bolt meets the ship. It never costs a life: it strips every shield
  /// and power-up (bonus powers too) at once. Ignored while the ship is
  /// protected or away, and during the grace after a zap. Returns whether
  /// it zapped the ship.
  bool zapShip() {
    if (!combat ||
        shipAway ||
        invulnerable > 0 ||
        lightningGrace > 0 ||
        lifeLossPhase != LifeLossPhase.none) {
      return false;
    }
    final lost = [
      for (final p in Power.values)
        if (hasPower(p)) p,
    ];
    final bonusLost = [
      for (final e in bonusRun.timers.entries)
        if (e.value > 0) e.key,
    ];
    powerTimers.clear();
    bonusRun.timers.clear();
    // The modules are blown off the hull, fanned out and tumbling (fixed
    // velocities: the zap draws nothing from the simulation stream).
    final modules = lost.where((p) => p != Power.shield).toList();
    for (var i = 0; i < modules.length; i++) {
      final spread = i - (modules.length - 1) / 2;
      fallingParts.add(
        FallingPart(
          shipX + spread * 9,
          ArcadeModel.shipY - 2,
          modules[i],
          vx: spread * 70 + (modules.length == 1 ? 45 : 0) + shipVx * .2,
          vy: -110,
          vRot: (i.isEven ? 1 : -1) * 7.5,
        ),
      );
    }
    shockLost = lost;
    shipShock = LightningTuning.shipShock;
    lightningGrace = LightningTuning.shipGrace;
    shipZaps++;
    events.add('shipZapped');
    _queueGameEvent(GameEventNames.lightningShipHit, {
      'variant': lost.isEmpty && bonusLost.isEmpty ? 'clean' : 'powers',
      'x': shipX,
      'lost': lost.length + bonusLost.length,
      'shield': lost.contains(Power.shield),
    });
    return true;
  }

  /// The brood's answer to the tells on screen: a share of each marked
  /// rank sidesteps out of a told column; rod-armoured creatures drift into
  /// it. Call once per step while tells run; a creature with no tell to
  /// answer eases back to its place on its own.
  void dodgeLightning(Iterable<LightningTell> tells) {
    for (final d in demons) {
      if (d.entering || d.stunned || d.lastStand || d.dive > 0) continue;
      final rank = lightningRank(d);
      final chance = lightningDodgeChance(rank, cycle);
      // Where it means to fly without the dodge (its formation or pattern
      // target, which already carries any shot evasion), not where it is.
      final base = _targetFormationPosition(d).$1 - d.boltDodge;
      for (final t in tells) {
        if (d.lightningRods) {
          if (t.progress >= .2 &&
              (base - t.x).abs() <= LightningTuning.rodLure) {
            d.boltDodgeGoal = t.x - base;
          }
          continue;
        }
        if (chance <= 0 || t.progress < LightningTuning.dodgeReact[rank]) {
          continue;
        }
        if (lightningRoll(d, t.index) >= chance) continue;
        final reach = t.column + LightningTuning.dodgeMargin;
        if ((base - t.x).abs() >= reach) continue;
        // The side it already leans to (its drawn x), so the sway never
        // flips a dodge halfway.
        var side = d.x >= t.x ? 1.0 : -1.0;
        if (t.x + side * reach > ArcadeModel.width - 24) side = -1;
        if (t.x + side * reach < 24) side = 1;
        d.boltDodgeGoal = t.x + side * reach - base;
      }
    }
  }

  /// Per combat step: the ship's grace and zap, every creature's charge,
  /// and the rank dodges easing toward their goals (then cleared: a storm
  /// sets them again each step while its tells run).
  void _lightningStep(double dt) {
    lightningGrace = math.max(0, lightningGrace - dt);
    shipShock = math.max(0, shipShock - dt);
    for (final d in demons) {
      if (d.charged > 0) d.charged = math.max(0, d.charged - dt);
      // A life-loss regroup gathers the stunned too.
      if (holdHostileFire && d.stun > 0) d.stun = 0;
      if (d.boltDodge != 0 || d.boltDodgeGoal != 0) {
        final speed = d.lightningRods
            ? 140.0
            : math.max(90.0, LightningTuning.dodgeSpeed[lightningRank(d)]);
        d.boltDodge += (d.boltDodgeGoal - d.boltDodge).clamp(
          -speed * dt,
          speed * dt,
        );
        if (d.boltDodge.abs() < .01 && d.boltDodgeGoal == 0) d.boltDodge = 0;
        d.boltDodgeGoal = 0;
      }
    }
    // Without a storm to read them, the stunned kills are not kept.
    if (bonusMechanic == null) stunKills.clear();
  }

  /// A charged rod-armoured creature fires [LightningTuning.chargedRate]
  /// times as often.
  double _chargeRate(Demon d) =>
      d.charged > 0 ? LightningTuning.chargedRate : 1.0;

  /// A stunned creature's step: the fall, then the climb back to its place.
  /// Returns false when [d] is not stunned (its ordinary step runs).
  bool _stunnedDemon(Demon d, double prevX, double prevY, double dt) {
    if (d.stun <= 0) return false;
    if (dt <= 0) return true;
    d.stun = math.max(0, d.stun - dt);
    if (d.stunFall > 0) {
      d.stunFall = math.max(0, d.stunFall - dt);
      d.stunVy += LightningTuning.gravity * dt;
      final floor = math.min(
        d.stunFromY +
            (d.isLarge ? LightningTuning.largeDrop : LightningTuning.maxDrop),
        ArcadeModel.shipY - LightningTuning.floorAboveShip,
      );
      d.y = math.max(d.y, math.min(floor, d.y + d.stunVy * dt));
    } else {
      final (tx, ty) = _targetFormationPosition(d);
      d.x += (tx - d.x).clamp(
        -LightningTuning.climbX * dt,
        LightningTuning.climbX * dt,
      );
      d.y += (ty - d.y).clamp(
        -LightningTuning.climbY * dt,
        LightningTuning.climbY * dt,
      );
      final climbed =
          LightningTuning.maxStun -
          d.stun -
          (d.isLarge ? LightningTuning.largeFall : LightningTuning.fall);
      if (climbed >= LightningTuning.minRecover &&
          (tx - d.x).abs() < 1.5 &&
          (ty - d.y).abs() < 1.5) {
        d.stun = 0;
      }
    }
    if (d.stun <= 0) d.stunVy = 0;
    _updateDemonKinematics(d, prevX, prevY, dt);
    return true;
  }
}
