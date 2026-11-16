part of 'model.dart';

// ===========================================================================
// The sentinel final rush (openspec/changes/demon-intelligence design §6).
//
// An eligible sentinel at a quarter of its hull (or left alone below half)
// raises its own rush shield and flies up to 1 / 2 / 3 passes (Easy /
// Normal / Hard) of rally (it rises and pulls back in depth), lock (it
// shudders, aims at the player forecast, its shadow snaps onto the ship's)
// and rush (it accelerates to 640 / 780 / 880 u/s, homing at 0 / 50 / 75
// °/s until the commit line, then straight). A miss comes around through
// the fog from depth; after the last pass it sacrifices itself off screen
// with no reward. Phase clocks run at the hostile rate.
// ===========================================================================

enum RushPhase { none, rally, lock, rush, recover }

/// Rush timing and geometry (seconds at hostile rate, arena units).
abstract final class RushTuning {
  /// Rally 0.8 s, not the design's 0.6: the radio warning borrows recorded
  /// sentinel-dive clips (shortest 1.46 s) and must end within 0.3 s of the
  /// charge at every difficulty (design.md §6.3, as built).
  static const rally = .8, recover = 1.2, ramp = .22, stagger = .45;

  /// Rally rise (u) and pull-back in depth (nearness).
  static const rise = 28.0, pullBack = .05;

  /// The rise from [y], never above y 32: a sentinel hovering at the top
  /// (y 44) would otherwise rear half out of the arena (review frames).
  static double riseFrom(double y) => math.max(0, math.min(rise, y - 32));

  /// Homing stops this far above the ship row; then it flies straight.
  static const commitAbove = 150.0;

  /// Speed factor while staggered (its rush shield just broke).
  static const staggerSlow = .4;

  /// playtest-fixes-3: score per (cycle + 1) × enemy points. A pass
  /// dodged (left without touching the ship) pays more than breaking the
  /// rush shield, and a sentinel that burns out after its last pass was
  /// dodged pays its full kill value: dodging is always the better play
  /// (standing in the charge to break the shield also risks a life).
  static const dodgePoints = 300, breakPoints = 150;

  /// The homing limit (degrees from the lock's aim): with it the whole
  /// homing reach stays inside the smallest dodge room (design §6.4, as
  /// built; Normal 104 u, Hard 124 u < 162 − 24).
  static double homingCap(Difficulty d) => switch (d) {
    Difficulty.easy => 0,
    Difficulty.normal => 14,
    Difficulty.hard => 16,
  };

  /// Lock seconds by difficulty.
  static double lock(Difficulty d) => d == Difficulty.hard ? .45 : .5;

  /// Rally plus lock, at hostile rate (the tell before any motion).
  static double tell(Difficulty d) => rally + lock(d);
}

/// Pure rush kinematics, shared by the model and the fairness checks.
abstract final class RushKinematics {
  /// One step of a rush: the new heading (radians from straight down)
  /// toward [aimX] on the ship row, bounded by [turnRate] (rad/s) while
  /// above the commit line; past it the rush is committed to a straight
  /// line. The heading never strays more than [cap] (rad) from [initial],
  /// the lock's aim: the homing limit that keeps every dodge escapable
  /// (§6.4, as built).
  static double steer({
    required double x,
    required double y,
    required double heading,
    required double aimX,
    required double turnRate,
    required double dt,
    double initial = 0,
    double cap = double.infinity,
  }) {
    if (turnRate <= 0 || y >= ArcadeModel.shipY - RushTuning.commitAbove) {
      return heading;
    }
    final want = math.atan2(aimX - x, math.max(1.0, ArcadeModel.shipY - y));
    final next =
        heading + (want - heading).clamp(-turnRate * dt, turnRate * dt);
    return next.clamp(initial - cap, initial + cap);
  }

  /// Speed after [t] seconds (real) of rush at top speed [vmax] (real
  /// u/s) with the ramp at [rate].
  static double speedAt(double t, double vmax, double rate) =>
      vmax * (t * rate / RushTuning.ramp).clamp(0.0, 1.0);

  /// Worst-case homing: the rush turning at its full [turnRate] from the
  /// start for the whole homing window. Returns (lateral displacement
  /// during the window, lateral displacement at the ship row, seconds to
  /// the ship row) from [y0].
  static (double, double, double) worstCase({
    required double y0,
    required double vmax,
    required double turnRate,
    required double rate,
    double cap = double.infinity,
  }) {
    const dt = 1 / 600;
    var x = 0.0, y = y0, h = 0.0, t = 0.0, window = 0.0;
    while (y < ArcadeModel.shipY) {
      final v = speedAt(t, vmax, rate);
      if (y < ArcadeModel.shipY - RushTuning.commitAbove) {
        h = math.min(h + turnRate * dt, cap);
        window = x;
      }
      x += v * math.sin(h) * dt;
      y += v * math.cos(h) * dt;
      t += dt;
    }
    return (window, x, t);
  }

  /// How far the ship gets in [seconds] from rest (2600 u/s² to 360 u/s).
  static double dodge(double seconds) {
    const a = 2600.0, v = 360.0, tv = v / a;
    if (seconds <= tv) return a * seconds * seconds / 2;
    return a * tv * tv / 2 + v * (seconds - tv);
  }
}

extension SentinelRush on ArcadeModel {
  /// Whether [d] (a sentinel) may make a final rush: its birth roll under
  /// the difficulty's chance plus up to 0.10 with skill.
  bool rushEligible(Demon d) =>
      d.isLarge &&
      (d.lastStandEligible ||
          d.rushRoll < policy.rushChance + .10 * skillLevel);

  /// The escort spawned and fell, and no ordinary creature is present.
  bool _sentinelAlone() =>
      escortSpawned &&
      !demons.any((o) => !o.isLarge && o.swarmState != SwarmState.reserve);

  /// Starts the rush if [d] meets a trigger (design §6.1).
  void _maybeRush(Demon d) {
    if (d.lastStand || d.entering || !rushEligible(d)) return;
    final hull = d.hp / d.maxHp;
    if (hull <= .25 || (hull <= .5 && _sentinelAlone())) _startRush(d);
  }

  void _startRush(Demon d) {
    d
      ..lastStand = true
      ..divePrep = 0
      ..telegraph = 0
      ..dive = 0
      ..diveShield = 0
      ..diveShieldMax = 0
      ..rushShieldMax = policy.rushShieldFor(cycle)
      ..rushShield = policy.rushShieldFor(cycle)
      ..rushPass = 1
      ..evadeOffset = 0
      ..evadeLeft = 0;
    _beginRally(d);
  }

  void _beginRally(Demon d) {
    final rate = policy.hostileRate;
    d
      ..rushPhase = RushPhase.rally
      ..rushTell = RushTuning.tell(difficulty)
      ..rushClock = 0
      ..rushing = false
      ..rushContact = false
      ..rushStagger = 0
      ..targetX = shipX
      .._lastStandX = d.x
      .._lastStandY = d.y;
    _queueGameEvent(GameEventNames.sentinelRushTell, {
      'x': d.x,
      'y': d.y,
      // Seconds (real) until it charges: the warning ends on it.
      'rushIn': RushTuning.tell(difficulty) / rate,
      'pass': d.rushPass,
      'passes': policy.rushPasses,
    });
  }

  /// The rush's seconds (real) from now to the ship row at top speed.
  double _rushEta(Demon d) {
    final vmax = policy.rushSpeed * policy.hostileRate;
    final ramp = RushTuning.ramp / policy.hostileRate;
    return ramp / 2 +
        math.max(0, ArcadeModel.shipY - d.y - vmax * ramp / 2) / vmax;
  }

  /// One frame of [d]'s rush (the `lastStand` branch of `_updateDemons`).
  /// Returns false when [d] left the model (sacrificed).
  bool _updateRush(Demon d, double dt) {
    final rate = policy.hostileRate;
    d.rushClock += dt * rate;
    switch (d.rushPhase) {
      case RushPhase.none:
        _beginRally(d);
      case RushPhase.rally:
        final u = (d.rushClock / RushTuning.rally).clamp(0.0, 1.0);
        final ease = u * u * (3 - 2 * u);
        d.x = d._lastStandX;
        d.y = d._lastStandY - RushTuning.riseFrom(d._lastStandY) * ease;
        if (d.rushClock >= RushTuning.rally) {
          d
            ..rushPhase = RushPhase.lock
            ..rushClock -= RushTuning.rally
            ..targetX = pilot
                .aim(_rushEta(d))
                .clamp(18.0, ArcadeModel.width - 18.0);
          _queueGameEvent(GameEventNames.sentinelRush, {
            'x': d.x,
            'aim': d.targetX,
            'rushIn': (RushTuning.lock(difficulty) - d.rushClock) / rate,
          });
        }
      case RushPhase.lock:
        d.x = d._lastStandX;
        d.y = d._lastStandY - RushTuning.riseFrom(d._lastStandY);
        if (d.rushClock >= RushTuning.lock(difficulty)) {
          d
            ..rushPhase = RushPhase.rush
            ..rushClock -= RushTuning.lock(difficulty)
            ..rushing = true
            ..rushHeading = math.atan2(
              d.targetX - d.x,
              math.max(1.0, ArcadeModel.shipY - d.y),
            );
          d.rushHeading0 = d.rushHeading;
        }
      case RushPhase.rush:
        final vmax = policy.rushSpeed * rate;
        var v = RushKinematics.speedAt(d.rushClock / rate, vmax, rate);
        if (d.rushStagger > 0) {
          d.rushStagger = math.max(0, d.rushStagger - dt * rate);
          v *= RushTuning.staggerSlow;
        }
        final left = math.max(
          .05,
          (ArcadeModel.shipY - d.y) / math.max(v, vmax * .5),
        );
        d.rushHeading = RushKinematics.steer(
          x: d.x,
          y: d.y,
          heading: d.rushHeading,
          aimX: pilot.aim(left),
          turnRate: policy.rushTurnRate * math.pi / 180 * rate,
          dt: dt,
          initial: d.rushHeading0,
          cap: RushTuning.homingCap(difficulty) * math.pi / 180,
        );
        d.rushVx = v * math.sin(d.rushHeading);
        d.rushVy = v * math.cos(d.rushHeading);
        d.x += d.rushVx * dt;
        d.y += d.rushVy * dt;
        if (d.x < -56 ||
            d.x > ArcadeModel.width + 56 ||
            d.y > ArcadeModel.height + 32) {
          if (!d.rushContact) {
            score += _rushPoints(RushTuning.dodgePoints);
            _queueGameEvent(GameEventNames.rushSurvived, {'pass': d.rushPass});
            _queueGameEvent(GameEventNames.sentinelRushMissed, {
              'pass': d.rushPass,
            });
          }
          if (d.rushPass >= policy.rushPasses) {
            // Outlasted: the last pass was dodged, so it burns out paying
            // its kill value (never a power drop or a kill count).
            if (!d.rushContact) {
              score += _bonusKillPoints(_killBase(d).round());
            }
            _sacrifice(d);
            return false;
          }
          _beginRecover(d);
        }
      case RushPhase.recover:
        // Out of the fog: the entrance from depth has finished.
        d.rushPass++;
        _beginRally(d);
    }
    return true;
  }

  /// A missed pass comes around through the fog (W3's re-entry): it
  /// reappears from depth at the top, untargetable until it is out.
  void _beginRecover(Demon d) {
    final rate = policy.hostileRate;
    final x = d.x.clamp(62.0, ArcadeModel.width - 62.0);
    d
      ..rushPhase = RushPhase.recover
      ..rushClock = 0
      ..rushing = false
      ..rushVx = 0
      ..rushVy = 0
      ..vx = 0
      ..vy = 0
      ..homeX = x
      ..homeY = 44
      ..x = x
      ..y = Perspective.horizonY - 6
      ..waitingForEscort = false
      ..swarmState = SwarmState.reentering
      ..arrivesFromDistance = true
      ..entryX = x
      ..entryY = Perspective.horizonY - 6
      ..entryN = .1
      ..entryScale = null
      ..entranceStartY = -48
      ..entranceProgress = 0
      ..entranceDelay = 0
      ..entranceElapsed = 0
      ..entranceHold = 0
      ..entranceDuration = RushTuning.recover / rate;
    if (!perspective) d.y = d.entranceStartY;
    _queueGameEvent(GameEventNames.sentinelRushAgain, {
      'pass': d.rushPass + 1,
      'rushIn': (RushTuning.recover + RushTuning.tell(difficulty)) / rate,
    });
  }

  int _rushPoints(int base) =>
      (base * (cycle + 1) * policy.enemyPoints).round();

  /// Whether [d] is in its berserk transformation (the rally and lock):
  /// nothing hurts it then (playtest-fixes-3).
  bool berserkTransforming(Demon d) =>
      d.lastStand &&
      (d.rushPhase == RushPhase.none ||
          d.rushPhase == RushPhase.rally ||
          d.rushPhase == RushPhase.lock);

  /// A hit that glances off: a spark at the impact (or the body's edge).
  void _deflect(Demon d, double? atX, double? atY) {
    deflects.add(Deflect(atX ?? d.x, atY ?? d.y + d.hitHalfHeight, d.x, d.y));
    if (deflects.length > 24) deflects.removeAt(0);
    // No white body flash: the hit did not land; the spark says so.
    d.flash = 0;
    events.add('hit');
  }

  /// A player hit on a berserk sentinel (playtest-fixes-3):
  /// - in the transformation (rally, lock) it is invulnerable: the hit
  ///   deflects with a spark and nothing is damaged;
  /// - in the rush, its rush shield is the super-powerful diving shield:
  ///   only offensive powers and homing hits wear it, with breaker damage
  ///   (damage + 1 Powerful + 1 Large); the bare gun deflects. The hull
  ///   takes nothing while it holds.
  /// Returns true when the hit was absorbed.
  bool _rushShieldHit(
    Demon d,
    int damage, {
    bool homing = false,
    double? atX,
    double? atY,
  }) {
    if (!d.lastStand) return false;
    if (berserkTransforming(d)) {
      _deflect(d, atX, atY);
      return true;
    }
    if (d.rushShield <= 0) return false;
    if (!hasOffensivePower && !homing) {
      _deflect(d, atX, atY);
      return true;
    }
    final breaker =
        damage +
        (hasPower(Power.powerful) ? 1 : 0) +
        (hasPower(Power.large) ? 1 : 0);
    d.rushShield = math.max(0, d.rushShield - breaker);
    events.add('hit');
    if (d.rushShield == 0) {
      final midRush = d.rushPhase == RushPhase.rush;
      if (midRush) {
        score += _rushPoints(RushTuning.breakPoints);
        d.rushStagger = RushTuning.stagger;
      }
      _queueGameEvent(GameEventNames.rushShieldBroken, {
        'x': d.x,
        'y': d.y,
        'midRush': midRush,
      });
    }
    return true;
  }

  /// Contact with the ship during a rush: a lost life ends it (the old
  /// sacrifice); a shield or protection ends only this pass's contact.
  void _rushContact(Demon d) {
    if (d.rushContact) return;
    final before = lives;
    hitPlayer();
    if (lives < before) {
      _sacrifice(d);
    } else {
      d.rushContact = true;
    }
  }
}
