part of 'model.dart';

// ===========================================================================
// Ground war v4: frequent skirmishes, mixed forces, full-width manoeuvre.
//
// The threat front of ground_war.dart (units that can break through and
// fire at the player) is unchanged: same schedule, same random stream, same
// rules. v4 adds a *skirmish* layer on top of it: mixed demon forces (their
// sector's vehicle, infantry squads, rocket troopers, heavy tanks) pushing
// in from the horizon across the whole ground plane, met by a mixed convoy
// (vehicles, rifle and rocket squads) that escorts the ship and advances
// only to attack. Skirmish units never cross their hold line (always short
// of fire range), never fire at the player, never move the pressure meter
// or allied strength, and never total an ally: a battered ally falls back to
// its escort slot for field repairs instead. Every unit, threat or
// skirmish, manoeuvres laterally (routes along valleys, flanking, spreading
// out); that is positional and visual, never a rule input.
//
// Skirmishes draw from their own seeded random stream, so the air war and
// the threat front see exactly the same sequence as before.
// Design: openspec/changes/ground-war-v4/design.md.
// ===========================================================================

/// What a ground unit is (both sides).
enum GroundForce {
  /// The sector's demon vehicle (ground-forces.png rows 0-3), or an allied
  /// vehicle (rows 4-11, never a squad variant).
  vehicle,

  /// A squad of riflemen (ground-troops.png): demon grunts or allied
  /// riflemen. One hit drops one trooper.
  infantry,

  /// A pair of rocket troopers: slow, heavy hitting.
  rockets,

  /// The demon heavy tank (ground-troops.png row 2). Demons only.
  heavyTank,
}

/// The skirmish layer of one sector.
class SkirmishFront {
  const SkirmishFront({
    required this.cap,
    required this.interval,
    required this.firstDelay,
    required this.forces,
    required this.allyForces,
    required this.convoy,
    required this.squad,
  });
  static const none = SkirmishFront(
    cap: 0,
    interval: 0,
    firstDelay: 0,
    forces: [],
    allyForces: [],
    convoy: 0,
    squad: 0,
  );

  /// Live skirmish units at the height of a surge (a lull keeps about a
  /// third of it).
  final int cap;

  /// Seconds between arrival groups at the surge (longer in a lull), and
  /// combat seconds into the level before the first one.
  final double interval, firstDelay;

  /// Demon forces drawn for arrivals, and the convoy's mix (by slot).
  final List<GroundForce> forces, allyForces;

  /// Convoy size (escort slots).
  final int convoy;

  /// Troopers per rifle squad.
  final int squad;

  bool get active => cap > 0;

  /// Test and comparison hook: false plays the v3 ground war exactly (no
  /// skirmish layer, no convoy slots, no manoeuvre).
  static bool enabled = true;

  /// Variety arrives progressively: grunts beside the sector vehicles in
  /// Krybor, rocket troopers from Ringfall, heavy tanks from Ember.
  static SkirmishFront of(
    Difficulty d, {
    required int route,
    required int sector,
  }) {
    if (!enabled ||
        sector < 1 ||
        sector > 5 ||
        const bool.fromEnvironment('GROUND_WAR_DISABLED')) {
      return none;
    }
    const v = GroundForce.vehicle,
        i = GroundForce.infantry,
        r = GroundForce.rockets,
        t = GroundForce.heavyTank;
    final extra = math.min(route, 2);
    return switch (sector) {
      1 => SkirmishFront(
        cap: 5 + (d == Difficulty.hard ? 1 : 0),
        interval: 3.8,
        firstDelay: 2.5,
        forces: const [v, i, i],
        allyForces: const [v, i, v, i],
        convoy: 4,
        squad: 3,
      ),
      2 => SkirmishFront(
        cap: 5,
        interval: 3.8,
        firstDelay: 2,
        forces: const [v, i, r, i],
        allyForces: const [v, i, r, v, i],
        convoy: 5,
        squad: 3,
      ),
      3 => SkirmishFront(
        cap: 5 + extra ~/ 2,
        interval: 3.6,
        firstDelay: 2,
        forces: const [v, i, r, t, i],
        allyForces: const [v, i, r, v, i, r],
        convoy: 6,
        squad: 4,
      ),
      4 => SkirmishFront(
        cap: 6,
        interval: 3.3,
        firstDelay: 2,
        forces: const [v, i, r, t, i, t],
        allyForces: const [v, i, r, v, i, r],
        convoy: 6,
        squad: 4,
      ),
      // The carrier: a lighter ground battle under the fleet fight.
      _ => SkirmishFront(
        cap: 3,
        interval: 5.5,
        firstDelay: 4,
        forces: const [i, r, t],
        allyForces: const [v, i, r, v],
        convoy: 4,
        squad: 3,
      ),
    };
  }
}

/// Every v4 tunable (seconds, texels of depth, arena units).
abstract final class GroundV4Tuning {
  /// Ebb and flow: one surge-and-lull cycle (combat seconds).
  static const tidePeriod = 34.0;
  static const surgeAbove = .72, lullBelow = .28;

  /// Depth-approach speed while advancing (texels/s, x hostileRate).
  static double approach(GroundForce f) => switch (f) {
    GroundForce.vehicle => 95.0,
    GroundForce.infantry => 58.0,
    GroundForce.rockets => 50.0,
    GroundForce.heavyTank => 70.0,
  };

  /// Lateral speed at depth z (arena units/s) = this x texel(z).
  static double lateral(GroundForce f) => switch (f) {
    GroundForce.vehicle => 62.0,
    GroundForce.infantry => 38.0,
    GroundForce.rockets => 32.0,
    GroundForce.heavyTank => 44.0,
  };

  /// Skirmish units hold at this depth or further: always short of
  /// [GroundTuning.fireZ] (and they never fire at the player anyway).
  static const holdMin = 430.0, holdSpread = 130.0;

  /// A unit holding with nobody to fight is shelled by allied artillery.
  static const idleArtillery = 7.0;
  static const maxLife = 45.0;

  /// Hits a skirmish unit takes.
  static int hp(GroundForce f, int squad) => switch (f) {
    GroundForce.vehicle => 4,
    GroundForce.infantry => squad,
    GroundForce.rockets => 3,
    GroundForce.heavyTank => 6,
  };

  /// Demon fire at its ally: seconds between shots and damage.
  static (double, int) demonFire(GroundForce f) => switch (f) {
    GroundForce.vehicle => (1.5, 1),
    GroundForce.infantry => (1.0, 1),
    GroundForce.rockets => (2.3, 2),
    GroundForce.heavyTank => (2.0, 2),
  };

  /// Allied fire in a skirmish.
  static (double, int) allyFire(GroundForce f) => switch (f) {
    GroundForce.vehicle => (.9, 1),
    GroundForce.infantry => (.75, 1),
    GroundForce.rockets => (1.9, 2),
    GroundForce.heavyTank => (.9, 1),
  };

  /// A battered ally (hp at or below this) falls back for repairs.
  static const fallBackHp = 3;
  static const repairTime = 3.5;

  /// Engaged allies stand this far short of a skirmish foe.
  static const standoff = 150.0;

  /// Skirmishes are fought on the visible near ground: an ally is assigned
  /// from [assignZ] and nobody fires before [fireStartZ] (screen y ~ 258).
  static const assignZ = 900.0, fireStartZ = 700.0;

  /// Skirmish arrivals enter a little nearer than the threat front.
  static const spawnZ = 1260.0;

  /// Escort slots around the ship: lateral offsets and depths.
  static const slotX = [-64.0, 64.0, -128.0, 128.0, -22.0, 22.0, -156.0, 156.0];
  static const slotZ = [250.0, 258.0, 286.0, 294.0, 318.0, 326.0, 270.0, 274.0];

  /// Footprint widths (texels) used for placement and the reticle.
  static double width(GroundForce f, {bool ally = false}) => switch (f) {
    GroundForce.vehicle =>
      ally ? GroundTuning.allyWidthTexels : GroundTuning.unitWidthTexels,
    GroundForce.infantry => 26.0,
    GroundForce.rockets => 20.0,
    GroundForce.heavyTank => 30.0,
  };

  /// Allies draw this much larger than demon units (phone readability).
  static const allyScale = 1.3;

  /// Live tracers kept at once (perf cap on phones).
  static const maxTracers = 48;

  /// Minimum seconds between two of the same v4 radio event.
  static const eventGap = {
    GameEventNames.groundSkirmish: 6.0,
    GameEventNames.infantryEngaged: 12.0,
    GameEventNames.skirmishWon: 7.0,
    GameEventNames.allyFallingBack: 10.0,
    GameEventNames.heavyArmorSighted: 20.0,
  };
}

/// Skirmish state of [GroundWar] (one per run; reset per level).
class GroundSkirmish {
  math.Random rng = math.Random(1);
  double spawnLeft = 0, clock = 0, phase = 0;

  /// Smoothed escort anchor (follows the ship's x).
  double convoyX = 180;

  /// 0 lull .. 1 surge; [tideState] -1 lull, 0 ebb/flow, 1 surge.
  double tide = .5;
  int tideState = 0;
  final Map<String, double> lastEvent = {};

  // Run statistics (tests, tools).
  int spawned = 0, killedByAllies = 0, killedByHoming = 0, artillery = 0;
  int fallBacks = 0;

  void reset() {
    spawnLeft = clock = 0;
    tide = .5;
    tideState = 0;
    lastEvent.clear();
  }
}

extension GroundWarV4 on ArcadeModel {
  GroundSkirmish get _sk => ground.skirmish;

  void _v4Event(String name, [Map<String, Object?> data = const {}]) {
    final gap = GroundV4Tuning.eventGap[name] ?? 0;
    final last = _sk.lastEvent[name];
    if (last != null && _sk.clock - last < gap) return;
    _sk.lastEvent[name] = _sk.clock;
    _groundEvent(name, data);
  }

  /// New level: the skirmish front, its own random stream and the tide.
  void _v4BeginLevel() {
    final sk = _sk..reset();
    sk.rng = math.Random(
      7919 * level + 104729 * cycle + 31 * difficulty.index + 17,
    );
    sk.phase = sk.rng.nextDouble() * math.pi * 2;
    sk.spawnLeft = ground.front.skirmish.firstDelay;
    sk.convoyX = shipX;
  }

  /// The convoy's force for escort [slot].
  GroundForce _v4AllyForce(int slot) {
    final mix = ground.front.skirmish.allyForces;
    if (mix.isEmpty) return GroundForce.vehicle;
    return mix[slot % mix.length];
  }

  /// Screen x of escort [slot] around the convoy anchor.
  double _v4SlotX(int slot) {
    const xs = GroundV4Tuning.slotX;
    return (_sk.convoyX + xs[slot % xs.length]).clamp(22.0, 338.0);
  }

  double _v4SlotZ(int slot) {
    const zs = GroundV4Tuning.slotZ;
    return zs[slot % zs.length];
  }

  // -------------------------------------------------------------------------
  // Update
  // -------------------------------------------------------------------------

  void _v4Update(double dt) {
    final sk = _sk;
    sk.clock += dt;
    final rate = policy.hostileRate;
    if (ground.front.skirmish.active) {
      _v4Tide();
      _v4Spawn(dt * rate);
    }
    for (final u in ground.units) {
      if (!u.skirmish || u.destroyed) continue;
      _v4Advance(u, dt, rate);
    }
    for (final u in ground.units) {
      if (u.alive && u.lx != null) _v4Steer(u, dt);
    }
    _v4Convoy(dt);
    if (ground.tracers.length > GroundV4Tuning.maxTracers) {
      ground.tracers.removeRange(
        0,
        ground.tracers.length - GroundV4Tuning.maxTracers,
      );
    }
  }

  void _v4Tide() {
    final sk = _sk;
    final w = 2 * math.pi * levelClock / GroundV4Tuning.tidePeriod + sk.phase;
    final s = math.sin(w);
    sk.tide = .5 + .5 * s;
    final state = sk.tide > GroundV4Tuning.surgeAbove
        ? 1
        : sk.tide < GroundV4Tuning.lullBelow
        ? -1
        : sk.tideState;
    if (state != sk.tideState) {
      sk.tideState = state;
      _groundEvent(GameEventNames.groundTide, {
        'state': state > 0 ? 'surge' : 'lull',
      });
    }
  }

  int get _v4LiveSkirmish {
    var n = 0;
    for (final u in ground.units) {
      if (u.skirmish && u.alive) n++;
    }
    return n;
  }

  void _v4Spawn(double dt) {
    final sk = _sk, f = ground.front.skirmish;
    sk.spawnLeft -= dt;
    if (sk.spawnLeft > 0) return;
    final capNow = math.max(1, (f.cap * (.35 + .65 * sk.tide)).round());
    final live = _v4LiveSkirmish;
    if (live >= capNow) {
      sk.spawnLeft = .5;
      return;
    }
    sk.spawnLeft = f.interval * (1.55 - .85 * sk.tide) *
        (.8 + .4 * sk.rng.nextDouble());
    // An arrival group pushes in along one route across the plane.
    final group = math.min(capNow - live, sk.tide > .55 ? 2 : 1);
    final routeX = 36 + sk.rng.nextDouble() * 288;
    for (var k = 0; k < group; k++) {
      final force = f.forces[sk.rng.nextInt(f.forces.length)];
      final x = (routeX + (k == 0 ? 0 : (sk.rng.nextBool() ? 1 : -1) * 46.0))
          .clamp(18.0, 342.0);
      final u = GroundUnit(
        ground.nextId++,
        level - 1,
        x < 180 ? 0 : 1,
        .5,
        GroundV4Tuning.spawnZ - sk.rng.nextDouble() * 120,
        shotsLeft: 0,
        hp: GroundV4Tuning.hp(force, f.squad),
      )
        ..skirmish = true
        ..force = force
        ..lx = x
        ..goalX = x
        ..retarget = .5 + sk.rng.nextDouble() * 2
        ..holdZ = GroundV4Tuning.holdMin +
            sk.rng.nextDouble() * GroundV4Tuning.holdSpread
        ..tracerLeft = .4 + sk.rng.nextDouble() * .6;
      u.maxHp = u.hp;
      u.facing = x < 180 ? 1 : -1;
      ground.units.add(u);
      sk.spawned++;
      if (force == GroundForce.heavyTank) {
        _v4Event(GameEventNames.heavyArmorSighted, {'x': u.x, 'y': u.y});
      }
    }
  }

  /// A skirmish unit: approach to its hold line, find an ally, trade fire.
  void _v4Advance(GroundUnit u, double dt, double rate) {
    u.life += dt;
    if (u.lastHit >= 0) u.lastHit += dt;
    u.fireFlash = math.max(0, u.fireFlash - dt);
    if (u.z > u.holdZ) {
      u.z = math.max(u.holdZ, u.z - GroundV4Tuning.approach(u.force) * rate * dt);
    }
    if (!u.sighted && u.z <= GroundTuning.sightZ) u.sighted = true;
    final ally = u.ally;
    final engaged = ally != null && ally.alive && identical(ally.attacker, u);
    if (!engaged) {
      u.ally = null;
      if (u.z <= GroundV4Tuning.assignZ) _v4FindAlly(u);
    }
    if (u.ally == null && u.z <= u.holdZ + 1) {
      u.idle += dt;
    } else {
      u.idle = 0;
    }
    if (u.idle > GroundV4Tuning.idleArtillery || u.life > GroundV4Tuning.maxLife) {
      ground.skirmish.artillery++;
      _v4Destroy(u, byAllies: true, artillery: true);
      return;
    }
    final a = u.ally;
    if (a == null || !a.announced || u.z > GroundV4Tuning.fireStartZ) return;
    u.tracerLeft -= dt * rate;
    if (u.tracerLeft <= 0) {
      final (every, damage) = GroundV4Tuning.demonFire(u.force);
      u.tracerLeft = every * (.85 + .3 * _sk.rng.nextDouble());
      u.fireFlash = .12;
      ground.tracers.add(
        GroundTracer(u.x, u.bodyY, a.x, a.bodyY, kind: _tracerKind(u.force)),
      );
      a.hp -= damage;
      a.flash = .15;
      if (a.hp <= GroundV4Tuning.fallBackHp) _v4FallBack(a);
    }
  }

  static int _tracerKind(GroundForce f) => switch (f) {
    GroundForce.infantry => GroundTracer.smallArms,
    GroundForce.rockets => GroundTracer.rocket,
    GroundForce.heavyTank => GroundTracer.shell,
    GroundForce.vehicle => GroundTracer.bolt,
  };

  /// The nearest free convoy ally meets [u]; a reinforcement rolls in from
  /// below while the convoy has an empty slot.
  void _v4FindAlly(GroundUnit u) {
    GroundAlly? best;
    var bestD = double.infinity;
    for (final a in ground.allies) {
      if (!a.alive || a.fallingBack) continue;
      final foe = a.attacker;
      if (foe != null && foe.alive) continue;
      final d = (a.x - u.x).abs() + (a.z - u.z).abs() * .2;
      if (d < bestD) {
        bestD = d;
        best = a;
      }
    }
    if (best == null) {
      final convoy = ground.allies.where((a) => a.alive).length;
      if (convoy >= ground.front.skirmish.convoy) return;
      best = _v4NewConvoyAlly(rollIn: true);
    }
    final first = !best.announced || best.attacker == null;
    best
      ..attacker = u
      ..announced = true
      ..saved = false
      ..fireLeft = .4 + _sk.rng.nextDouble() * .4;
    u.ally = best;
    ground.alliesEngaged++;
    ground.alliesEngagedThisLevel++;
    ground.engagements++;
    if (first) {
      _v4Event(GameEventNames.groundSkirmish, {
        'x': u.x,
        'y': u.y,
        'force': u.force.name,
        'allyForce': best.force.name,
      });
    }
    if (u.force == GroundForce.infantry ||
        u.force == GroundForce.rockets ||
        best.force != GroundForce.vehicle) {
      _v4Event(GameEventNames.infantryEngaged, {
        'x': u.x,
        'y': u.y,
        'force': u.force.name,
        'allyForce': best.force.name,
      });
    }
  }

  /// A convoy ally in the first free escort slot.
  GroundAlly _v4NewConvoyAlly({bool rollIn = false}) {
    final used = <int>{
      for (final a in ground.allies)
        if (a.alive) a.slot,
    };
    var slot = 0;
    while (used.contains(slot)) {
      slot++;
    }
    final x = _v4SlotX(slot), z = _v4SlotZ(slot);
    final a = GroundAlly(
      ground.nextId++,
      level - 1,
      x < 180 ? 0 : 1,
      .5,
      rollIn ? GroundTuning.allyRollInZ : z,
      GroundTuning.allyHp,
    )
      ..slot = slot
      ..force = _v4AllyForce(slot)
      ..lx = x
      ..holdZ = z;
    ground.allies.add(a);
    return a;
  }

  /// Allied fire on a skirmish foe (called from `_updateAllies`).
  void _v4AllyFight(GroundAlly a, GroundUnit foe, double dt) {
    if (foe.z > GroundV4Tuning.fireStartZ) return;
    a.fireLeft -= dt;
    if (a.fireLeft > 0) return;
    final (every, damage) = GroundV4Tuning.allyFire(a.force);
    a.fireLeft = every * (.85 + .3 * _sk.rng.nextDouble());
    a.recoil = GroundTuning.allyRecoil;
    ground.tracers.add(
      GroundTracer(
        a.x,
        a.bodyY,
        foe.x,
        foe.bodyY,
        friendly: true,
        kind: _tracerKind(a.force),
      ),
    );
    foe.hp -= damage;
    foe.lastHit = 0;
    if (foe.hp <= 0) _v4Destroy(foe, byAllies: true);
  }

  void _v4FallBack(GroundAlly a) {
    final foe = a.attacker;
    if (foe != null && identical(foe.ally, a)) foe.ally = null;
    a
      ..attacker = null
      ..fallingBack = true
      ..repair = GroundV4Tuning.repairTime;
    _sk.fallBacks++;
    _v4Event(GameEventNames.allyFallingBack, {
      'x': a.x,
      'y': a.y,
      'force': a.force.name,
    });
  }

  /// A skirmish unit is destroyed (allies, artillery or a homing missile).
  /// No pressure, strength or breakthrough bookkeeping: skirmishes are the
  /// ambient war.
  void _v4Destroy(GroundUnit u, {bool byAllies = false, bool artillery = false}) {
    if (u.destroyed) return;
    u
      ..destroyed = true
      ..destroyedByAllies = byAllies
      ..telegraph = 0
      ..threatening = false
      ..hp = 0
      ..lastHit = 0;
    final a = u.ally;
    if (a != null && identical(a.attacker, u)) a.attacker = null;
    events.add('groundExplosion');
    if (byAllies) {
      _sk.killedByAllies++;
      _v4Event(GameEventNames.skirmishWon, {
        'x': u.x,
        'y': u.y,
        'force': u.force.name,
        'by': artillery ? 'artillery' : (a?.force.name ?? 'convoy'),
      });
    } else {
      _sk.killedByHoming++;
      score += ((150 + 50 * u.sector) * (cycle + 1) * policy.enemyPoints).round();
      _groundEvent(GameEventNames.groundUnitDestroyed, {
        'x': u.x,
        'y': u.y,
        'by': 'homing',
        'brokeThrough': false,
        'skirmish': true,
        'force': u.force.name,
      });
    }
  }

  // -------------------------------------------------------------------------
  // Manoeuvre
  // -------------------------------------------------------------------------

  /// Lateral route of a unit: lower ground (valley floors, around hills),
  /// room from its neighbours, a flank on its foe, and a little wander.
  double _v4Route(GroundUnit u) {
    final rng = _sk.rng;
    final x = u.lx!;
    final relief = ground.relief;
    final foe = u.ally;
    final flank = foe != null && foe.alive
        ? foe.x + (u.id.isEven ? 1 : -1) * (46 + 40 * rng.nextDouble())
        : null;
    var best = x, bestCost = double.infinity;
    for (var k = -3; k <= 3; k++) {
      final px = (x + k * 42.0 + (rng.nextDouble() - .5) * 20).clamp(16.0, 344.0);
      var cost = (px - x).abs() / 140 + rng.nextDouble() * .9;
      if (relief != null) cost += relief.heightAt(px, u.z) / 7;
      for (final o in ground.units) {
        if (identical(o, u) || !o.alive) continue;
        if ((o.z - u.z).abs() > 160) continue;
        final d = (o.x - px).abs();
        if (d < 34) cost += 1.2 * (1 - d / 34);
      }
      if (flank != null) cost += (px - flank).abs() / 70;
      // Pushing toward the convoy: drift a little toward the ship's side.
      cost += (px - _sk.convoyX).abs() / 900;
      if (cost < bestCost) {
        bestCost = cost;
        best = px;
      }
    }
    return best;
  }

  /// Lateral range: skirmish units roam the whole plane; a threat unit
  /// weaves inside its own side band, so its missiles leave from where they
  /// always did (the dodge stays exactly as hard as before).
  (double, double) _v4Range(GroundUnit u) {
    if (u.skirmish) return (14.0, 346.0);
    final w = u.width;
    final left = GroundCamera.bandX(u.side, 0, w), right = GroundCamera.bandX(u.side, 1, w);
    return left < right ? (left, right) : (right, left);
  }

  void _v4Steer(GroundUnit u, double dt) {
    u.retarget -= dt;
    if (u.retarget <= 0) {
      u.retarget = 1.8 + _sk.rng.nextDouble() * 2.6;
      u.goalX = _v4Route(u);
    }
    final maxV = GroundV4Tuning.lateral(u.force) * GroundCamera.texel(u.z);
    final want = ((u.goalX - u.lx!) * 1.4).clamp(-maxV, maxV);
    u.vx += (want - u.vx) * math.min(1.0, dt * 2.5);
    final (lo, hi) = _v4Range(u);
    u.lx = (u.lx! + u.vx * dt).clamp(lo, hi);
    if (u.goalX < lo || u.goalX > hi) u.goalX = u.goalX.clamp(lo, hi);
    final foe = u.ally;
    if (u.vx.abs() > 3) {
      u.facing = u.vx > 0 ? 1 : -1;
    } else if (foe != null && foe.alive) {
      u.facing = foe.x >= u.x ? 1 : -1;
    }
  }

  /// The convoy: escort slots follow the ship; engaged allies close on
  /// their foe laterally, then fall back; battered ones repair at the slot.
  void _v4Convoy(double dt) {
    final sk = _sk;
    sk.convoyX += (shipX - sk.convoyX) * math.min(1.0, dt * 1.1);
    final front = ground.front.skirmish;
    if (front.active) {
      // Keep the convoy filled on station (outside of skirmishes too).
      final alive = ground.allies.where((a) => a.alive).length;
      if (alive < math.min(front.convoy, 2 + (levelClock / 4).floor())) {
        _v4NewConvoyAlly(rollIn: levelClock > .5);
      }
    }
    for (final a in ground.allies) {
      final lx = a.lx;
      if (lx == null) continue;
      if (a.totalled) {
        a.lx = lx + (lx < 180 ? -1 : 1) * 40 * dt;
        continue;
      }
      if (a.fallingBack) {
        a.repair -= dt;
        if (a.repair <= 0) {
          a
            ..fallingBack = false
            ..hp = GroundTuning.allyHp;
        }
      }
      a.holdZ = _v4SlotZ(a.slot);
      final foe = a.attacker;
      var goal = foe != null && foe.alive && !a.fallingBack
          ? foe.x + (a.id.isEven ? -1 : 1) * 30
          : _v4SlotX(a.slot);
      // Spread out: never stack on a neighbour at about the same depth.
      for (final o in ground.allies) {
        if (identical(o, a) || !o.alive || (o.z - a.z).abs() > 45) continue;
        final d = a.x - o.x;
        if (d.abs() < 30) goal += (d >= 0 ? 1 : -1) * (30 - d.abs()) * 1.5;
      }
      final maxV = (a.force == GroundForce.vehicle ? 70.0 : 44.0) *
          GroundCamera.texel(a.z);
      final want = ((goal - lx) * 1.5).clamp(-maxV, maxV);
      a.vx += (want - a.vx) * math.min(1.0, dt * 3);
      a.lx = (lx + a.vx * dt).clamp(16.0, 344.0);
    }
  }
}
