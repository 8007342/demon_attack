part of 'model.dart';

// --- crosswind (openspec/changes/crosswind design §1-§4)
//
// The model's side of the wind: which wind a level has, the field sampled
// once per step, the drift every projectile picks up (the player's and the
// demons' alike) and the calls that telegraph a change. A level without
// wind (every unseeded run: the tests and the calibrated campaign) costs
// one null check per step and per shot, and draws nothing.

/// `MusicBridge.accentEvent` (lib/game/music_director.dart), named here so
/// the pure model can ask for a stinger without importing audio.
const musicAccentEvent = 'musicAccent';

/// The wind state of one run.
class WindRun {
  /// The level's wind (null: calm) and its field.
  WindSpec? spec;
  WindField? field;

  /// Tools and review harnesses: the wind of every level ([route],
  /// [sector]); null: the run's plan. Return null for a calm level.
  WindSpec? Function(int route, int sector)? force;

  /// The wind this step.
  WindSample now = WindSample.calm;

  /// The level clock of the last step (the calls fire once each).
  double told = -1e9;

  /// Whether `windStart` was sent and `windStop` not yet.
  bool blowing = false;

  /// Calls sent this level (tests, the console).
  int gusts = 0;
}

extension ArcadeWind on ArcadeModel {
  /// The level's wind field (null: calm).
  WindField? get windField => windRun.field;

  /// The wind this step.
  WindSample get wind => windRun.now;

  /// The sideways speed (u/s) a projectile settles to in this wind.
  double get windDrift => wind.lateral * (windRun.spec?.peakDrift ?? 0);

  /// Shifts at least this big (or any gust) are called on the radio.
  static const callShift = .6;

  void _windBeginLevel() {
    final run = windRun;
    final def = bonus;
    final force = run.force;
    final WindSpec? spec;
    if (force != null) {
      spec = level == 5 ? null : force(cycle, level);
    } else if (def?.wind ?? false) {
      spec = WindPlan.bonusLevel(
        BonusPlan.levelSeed(runSeed ?? seed, cycle, level),
      );
    } else {
      spec = WindPlan.forLevel(
        runSeed,
        route: cycle,
        sector: level,
        bonus: def != null,
      );
    }
    run
      ..spec = spec
      ..field = spec == null ? null : WindField(spec)
      ..now = WindSample.calm
      ..told = -1e9
      ..blowing = false
      ..gusts = 0;
    _stormBeginLevel(); // --- weather-everywhere: the level's storm
  }

  /// One combat step: the field at the level clock, and its calls.
  void _windStep() {
    final run = windRun;
    final f = run.field;
    if (f == null) return;
    final t = levelClock;
    run.now = f.at(t);
    final amount = run.now.amount;
    if (!run.blowing && amount > .05) {
      run.blowing = true;
      _queueGameEvent(GameEventNames.windStart, {
        'tier': f.spec.tier.name,
        'variant': f.spec.tier.name, // --- weather-everywhere: radio
        'sector': level,
        'side': run.now.lateral < 0 ? 'left' : 'right',
      });
    } else if (run.blowing && amount < .02 && t > f.spec.startAt) {
      run.blowing = false;
      _queueGameEvent(GameEventNames.windStop, {'tier': f.spec.tier.name});
    }
    if (run.blowing && !shipAway) {
      // The telegraph: a big swing or a gust is called [WindField.lead]
      // seconds before it pushes (radio, the gust stinger).
      for (final s in f.tellsBetween(run.told, t)) {
        final before = f.at(s.at - .01).lateral;
        final after = s.lateral * f.spec.amountAt(s.at + s.ramp);
        if (!s.gust && (after - before).abs() < callShift) continue;
        run.gusts++;
        _queueGameEvent(GameEventNames.windGust, {
          'from': after < 0 ? 'right' : 'left', // where it blows from
          'to': after < 0 ? 'left' : 'right',
          'gust': s.gust,
          // --- weather-everywhere: a swing (the wind turns) has its own
          // radio lines; a gust keeps the trigger's own.
          if (!s.gust) 'variant': 'swing',
          'strength': double.parse(after.abs().toStringAsFixed(2)),
          'endIn': WindField.lead,
        });
        // The gust swell (bonus-music's `gust` stinger, through
        // `MusicBridge.accentEvent`; an unknown name plays nothing).
        _queueGameEvent(musicAccentEvent, {'name': 'gust'});
      }
    }
    run.told = t;
  }

  /// The brood aims with the wind (it is their planet): the share of the
  /// drift a demon expects over its shot's fall that it aims off by.
  static const broodAim = .6;

  /// The sideways speed (u/s, before the hostile rate) a demon adds to a
  /// shot fired from [y] falling at [vy] so the wind carries it back
  /// toward its mark: [broodAim] of the expected drift. 0 when calm.
  double _windLead(double y, double vy) {
    if (windRun.spec == null || vy <= 0) return 0;
    final t = (ArcadeModel.shipY - y) / vy;
    if (t <= .05) return 0;
    const tau = WindField.settle;
    final drift = windDrift * (t - tau * (1 - math.exp(-t / tau)));
    final rate = policy.hostileRate > 0 ? policy.hostileRate : 1.0;
    return -broodAim * drift / t / rate;
  }

  /// The wind on one projectile this step: a tailwind's grid step at the
  /// muzzle, then its sideways speed settles toward the wind's drift.
  void _windShot(Shot s, double dt) {
    final spec = windRun.spec;
    if (spec == null) return;
    final w = windRun.now;
    if (s.age == 0 && s.vy != 0) {
      // + along blows down the screen: behind a hostile shot, against ours.
      final tail = s.vy < 0 ? -w.along : w.along;
      if (tail >= WindField.tailwind) {
        s.windVy = s.vy.sign * ArcadeModel.hostileSpeedGrid;
      }
    }
    final target = w.lateral * spec.peakDrift;
    s.windVx += (target - s.windVx) * math.min(1.0, dt / WindField.settle);
  }
}

// --- crosswind: the demons fight the wind (the operator: "the demons
// should fight the strong wind a little, but not as much, it's their
// planet and they know how to deal with it"). Each creature is pushed a
// little and leans into it; higher ranks are steadier.
extension ArcadeWindDemons on ArcadeModel {
  /// Seconds of drift a creature lets the wind have before it corrects:
  /// at full yield its push settles at drift × yield × this.
  static const pushHorizon = .6;

  /// Seconds the push takes to settle (and to fade when the wind drops).
  static const pushSettle = .8;

  /// Bank added per step against the wind, at full strength (the lean).
  static const lean = .04;

  /// How much of the wind a creature yields to (0-1; a shot yields 1):
  /// ordinary creatures by species (the heavier ones steadier), elites and
  /// escorts less, sentinels hardly at all; a committed dive less again.
  static double windYield(Demon d) {
    var k = d.isLarge ? .08 : .24 - .02 * d.kind.clamp(0, 3);
    if (d.elite) k *= .7;
    if (d.isEscort) k *= .8;
    if (d.dive > 0) k *= .6;
    return k;
  }

  void _windUnpush() {
    if (windRun.field == null) return;
    for (final d in demons) {
      d.x -= d.windOffset;
    }
  }

  void _windPush(double dt) {
    final spec = windRun.spec;
    if (spec == null) return;
    final drift = windDrift;
    final k = math.min(1.0, dt / pushSettle);
    for (final d in demons) {
      // --- weather-everywhere: a smart diver rides a tailwind (a curve).
      final ride = _windRide(d);
      final target = ride
          ? drift * ArcadeWindDive.rideYield * ArcadeWindDive.rideHorizon
          : drift * windYield(d) * pushHorizon;
      d.windOffset += (target - d.windOffset) * k;
      final x = d.x + d.windOffset;
      final clamped = x.clamp(18.0, ArcadeModel.width - 18.0);
      d.windOffset += clamped - x; // never pushed off the arena
      d.x = clamped;
      // Lean into the wind (against the push): the flight's bank carries
      // it, so a creature visibly corrects.
      if (!d.entering) {
        d.bank = (d.bank - wind.lateral * lean * (1 - windYield(d))).clamp(
          -1.0,
          1.0,
        );
      }
    }
  }
}
