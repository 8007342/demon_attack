part of 'model.dart';

// ===========================================================================
// weather-everywhere (openspec/changes/weather-everywhere): lightning storms
// in the regular sectors, and the smart brood riding the wind into a dive.
//
// - STORMS: a seeded level whose rain is heavy enough may storm
//   (`StormPlan`, about one eligible level in seven). Its bolts follow
//   lightning-rework's rule (stun, zap, rank dodges); their schedule is a
//   `StormCell` with the slower regular tuning. Unseeded runs never storm,
//   so every calibration gate is unchanged.
// - WIND DIVES: ranks that read the sky (veterans, hunters, sentinels;
//   skirmishers from the third tour) hold a dive for up to 2.4 s until the
//   wind will blow toward the ship when it starts, then let a stronger
//   share of it carry them: the dive curves in on the wind. Drones and
//   young skirmishers dive when picked and fight the wind as before.
//
// Pure Dart; nothing here draws from `random`.
// ===========================================================================

/// The weather state of one run beyond the wind (`WindRun`): the level's
/// storm and the wind-dive tallies.
class WeatherRun {
  /// Tools, review harnesses and tests: the storm of every level ([route],
  /// [sector]); null: the run's plan. Return null for no storm.
  StormSpec? Function(int route, int sector)? forceStorm;

  /// The level's storm (null: none) and its schedule.
  StormSpec? storm;
  StormCell? cell;

  /// Whether `stormStart` was sent and `stormStop` not yet.
  bool raging = false;

  /// Tells already announced, and ship-aimed tells (every other one says
  /// "Avoid lightning!").
  int warned = 0, shipTells = 0;

  /// This level's bolts, ship zaps and creatures stunned.
  int bolts = 0, zaps = 0, stuns = 0;

  /// Dives started in a wind, by who dived (smart: reads the sky) and
  /// whether the wind blew toward the ship as the dive began; rides: smart
  /// dives that let the wind carry them. The run's totals (tests, tools).
  int smartDives = 0, smartAligned = 0, gruntDives = 0, gruntAligned = 0;
  int rides = 0;

  /// Picks a smart creature let go because only a headwind was in reach.
  int declined = 0;
}

extension ArcadeStorm on ArcadeModel {
  /// The level's storm schedule (null: no storm). The storm layer draws it.
  StormCell? get stormCell => weatherRun.cell;

  /// Called by `_windBeginLevel` (one weather begin per level).
  void _stormBeginLevel() {
    final run = weatherRun;
    final force = run.forceStorm;
    final StormSpec? spec;
    if (bonus != null || level == 5) {
      spec = null;
    } else if (force != null) {
      spec = force(cycle, level);
    } else {
      spec = StormPlan.forLevel(runSeed, route: cycle, sector: level);
    }
    run
      ..storm = spec
      ..cell = spec == null
          ? null
          : StormCell(spec.seed, tuning: StormPlan.regular)
      ..raging = false
      ..warned = 0
      ..shipTells = 0
      ..bolts = 0
      ..zaps = 0
      ..stuns = 0;
  }

  /// One combat step of the storm: its start and stop calls, the tells
  /// (sound, the squad's warning, the brood's dodges) and the bolts.
  void _stormStep(double dt) {
    final run = weatherRun;
    final cell = run.cell, spec = run.storm;
    if (cell == null || spec == null || bonusMechanic != null) return;
    final on = spec.activeAt(levelClock);
    if (on && !run.raging) {
      run.raging = true;
      _queueGameEvent(GameEventNames.stormStart, {
        'variant': spec.rain.tier.name,
        'sector': level,
      });
    } else if (!on && run.raging && !cell.telling) {
      run.raging = false;
      _queueGameEvent(GameEventNames.stormStop, {'sector': level});
    }
    final landed = cell.step(
      dt,
      shipX: shipX,
      swarm: [
        for (final d in demons)
          if (!d.entering) d.x,
      ],
      active: on && combat && !shipAway,
      rate: policy.hostileRate,
    );
    for (final s in cell.strikes) {
      if (s.index < run.warned) continue;
      run.warned = s.index + 1;
      events.add('stormTell');
      if (s.aim == StrikeAim.ship) {
        run.shipTells++;
        _queueGameEvent(GameEventNames.stormStrike, {
          'x': s.x,
          'endIn': s.tellLeft,
          if (run.shipTells.isOdd) 'variant': 'avoid',
        });
      }
    }
    dodgeLightning([
      for (final s in cell.strikes)
        if (s.telling)
          (index: s.index, x: s.x, column: s.column, progress: s.tellProgress),
    ]);
    for (final s in landed) {
      run.bolts++;
      if ((shipX - s.x).abs() < cell.tuning.core && !shipAway && zapShip()) {
        s.hitShip = true;
        run.zaps++;
      }
      final hit = strikeLightning(s.x, s.column);
      s
        ..stunned = hit.stunned.length
        ..charged = hit.charged.length;
      run.stuns += s.stunned;
      events.add('stormBolt');
    }
  }
}

extension ArcadeWindDive on ArcadeModel {
  /// Lateral wind toward the ship (share of full strength) that makes a
  /// tailwind worth riding.
  static const rideMin = .45;

  /// The longest a smart creature holds a dive for the wind (seconds of
  /// prep time, which runs at the hostile rate), and the step it reads the
  /// field in.
  static const maxWait = 2.4, waitStep = .1;

  /// A rider's yield to the wind and its horizon (s): a full gale carries
  /// it about 52 × 0.45 × 1.0 ≈ 23 units, the curve of its dive.
  static const rideYield = .45, rideHorizon = 1.0;

  /// Share of the expected carry a rider aims upwind of the ship by, so
  /// the wind brings it in.
  static const rideAim = .7;

  /// Whether [d] reads the wind (its rank on the insignia ladder): hunters,
  /// veterans and sentinels always, skirmishers from the third tour,
  /// drones never.
  static bool windSmart(Demon d, int route) {
    final rank = lightningRank(d);
    return rank >= 2 || (rank == 1 && route >= 2);
  }

  /// The wind at combat second [t] blowing from [x] toward [toX] (share of
  /// full strength; + is a tailwind). 0 when calm.
  double tailwindAt(double t, double x, double toX) {
    final f = windRun.field;
    if (f == null) return 0;
    return f.at(t).lateral * (toX >= x ? 1 : -1);
  }

  /// How long (prep seconds) [d] holds the dive it was just picked for:
  /// the first wait in 0..[maxWait] after which its dive would start in a
  /// tailwind of at least [rideMin] toward the ship. 0 for a creature that
  /// does not read the wind, in calm air, or when no such gust comes and
  /// the wind is not against it; -1 when only a headwind is in reach (it
  /// lets the pick go).
  double windDiveDelay(Demon d) {
    if (windRun.field == null || !windSmart(d, cycle)) return 0;
    final rate = policy.hostileRate > 0 ? policy.hostileRate : 1.0;
    final lead = ArcadeModel.divePrepBeat + ArcadeModel.diveTellFor(d);
    final steps = (maxWait / waitStep).round();
    for (var i = 0; i <= steps; i++) {
      final wait = math.min(maxWait, i * waitStep);
      final at = levelClock + (wait + lead) / rate;
      if (tailwindAt(at, d.x, shipX) >= rideMin) return wait;
    }
    // No gust in reach: into a headwind it lets this dive go (-1); across
    // a weak wind it dives now and fights it (0).
    final at = levelClock + (maxWait + lead) / rate;
    return tailwindAt(at, d.x, shipX) < 0 ? -1 : 0;
  }

  /// The dive picker's call: a smart creature may hold its dive for the
  /// wind (it counts as preparing meanwhile: no second dive, no evasion,
  /// its slot held); any other dives now.
  void _windPrepDive(Demon d) {
    final wait = windDiveDelay(d);
    if (wait < 0) {
      // It reads a headwind and lets this pick go: the picker tries again
      // after its ordinary gap (never more often than in calm air).
      weatherRun.declined++;
      return;
    }
    if (wait == 0) {
      _prepDive(d);
      return;
    }
    d
      ..windWait = wait
      ..divePrep = ArcadeModel.divePrepBeat + wait;
  }

  /// A held dive's countdown (before the prep's own): when the wait is
  /// over, the ordinary prep begins (its radio beat included). A stun, a
  /// regroup or a pincer ends the wait.
  void _windDiveWait(Demon d, double dt) {
    if (d.windWait <= 0) return;
    if (d.divePrep <= 0) {
      d.windWait = 0;
      return;
    }
    d.windWait -= dt * policy.hostileRate;
    if (d.windWait <= 0 || d.pincer != 0) {
      d.windWait = 0;
      _prepDive(d);
    }
  }

  /// Whether [d] rides the wind this step (from `_windPush`): at the start
  /// of each dive it is tallied and, if it reads the wind and the wind
  /// blows toward the ship, it rides, aiming upwind of the ship so the
  /// carry brings it in (`windDive`). The ride lasts while the dive does
  /// and the wind keeps its side.
  bool _windRide(Demon d) {
    if (d.dive <= 0) {
      d
        ..windRide = 0
        ..windDiveSeen = false;
      return false;
    }
    if (!d.windDiveSeen) {
      d.windDiveSeen = true;
      final run = weatherRun;
      final smart = windSmart(d, cycle);
      final tail = tailwindAt(levelClock, d.x, d.targetX);
      final aligned = tail >= rideMin;
      if (smart) {
        run.smartDives++;
        if (aligned) run.smartAligned++;
      } else {
        run.gruntDives++;
        if (aligned) run.gruntAligned++;
      }
      if (smart && aligned) {
        run.rides++;
        final side = wind.lateral >= 0 ? 1 : -1;
        d
          ..windRide = side
          ..targetX =
              (d.targetX -
                      side *
                          windDrift.abs() *
                          rideYield *
                          rideHorizon *
                          rideAim)
                  .clamp(24.0, ArcadeModel.width - 24.0);
        _queueGameEvent(GameEventNames.windDive, {
          'x': d.x,
          'side': side < 0 ? 'left' : 'right',
          'sentinel': d.isLarge,
          'elite': d.elite,
        });
      }
    }
    return d.windRide != 0 && wind.lateral * d.windRide > 0;
  }
}
