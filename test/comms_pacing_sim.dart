/// A seeded airtime simulation of the squad radio in busy (or calm) combat:
/// the event stream the model and [GameEventObserver] raise, fed to a
/// [CommsDirector] at 60 Hz, with every started line recorded.
library;

import 'dart:math' as math;

import 'package:demon_attack/comms/comms_director.dart';
import 'package:demon_attack/comms/comms_lineup.dart';
import 'package:demon_attack/game/model.dart';

/// One line as it was heard.
class HeardLine {
  HeardLine(this.message);
  final CommsMessage message;
  double get start => message.startedAt;
  double end = double.nan;
  bool cut = false;
  String get trigger => message.trigger.name;

  @override
  String toString() =>
      '${message.line.id} ${message.kind.name} '
      '${start.toStringAsFixed(2)}-${end.toStringAsFixed(2)}${cut ? ' cut' : ''}';
}

class PacingStats {
  PacingStats(this.seconds);
  final double seconds;
  final heard = <HeardLine>[];

  /// Dive starts and ground launches the simulation scheduled.
  final dives = <double>[];
  final shots = <double>[];

  /// (time, kind) whenever a pickup fell while the ship lacked it.
  final hintChances = <double>[];

  /// The fight below as the simulation staged it: (from, to) spans while
  /// demon ground units were engaged, and while the ship flew over them,
  /// and the times allies called for help.
  final engagedSpans = <(double, double)>[];
  final overSpans = <(double, double)>[];
  final allyCalls = <double>[];

  static bool _within(List<(double, double)> spans, double t) =>
      spans.any((s) => t >= s.$1 - 1e-6 && t < s.$2 + 1e-6);
  bool engagedAt(double t) => _within(engagedSpans, t);
  bool overAt(double t) => _within(overSpans, t);
  bool allyCalledBefore(double t, double window) =>
      allyCalls.any((a) => a <= t + 1e-6 && t - a <= window);

  /// Ground warnings that ended after their launch (the channel was busy).
  List<HeardLine> get lateWarnings => [
    for (final h in heard)
      if (h.message.mustPlay && h.end > h.message.endBy! + 1e-6) h,
  ];

  /// Dive calls that ended within the tolerance of their dive, of all.
  (int, int) diveAlignment(double tolerance) {
    var aligned = 0, total = 0;
    for (final h in heard) {
      if (!const {
        'diveWarning',
        'sentinelDive',
        'divePrep',
      }.contains(h.trigger)) {
        continue;
      }
      total++;
      if ((h.end - h.message.endBy!).abs() <= tolerance + 1e-6) aligned++;
    }
    return (aligned, total);
  }

  /// Lines started per trigger.
  Map<String, int> get byTrigger {
    final out = <String, int>{};
    for (final h in heard) {
      out[h.trigger] = (out[h.trigger] ?? 0) + 1;
    }
    return out;
  }

  /// Seconds of speech (union of voices) over [seconds].
  double duty({bool Function(HeardLine)? where}) {
    final spans = [
      for (final h in heard)
        if (where == null || where(h)) (h.start, h.end),
    ]..sort((a, b) => a.$1.compareTo(b.$1));
    var total = 0.0, from = -1.0, to = -1.0;
    for (final (a, b) in spans) {
      if (a > to) {
        total += to - from;
        from = a;
        to = b;
      } else {
        to = math.max(to, b);
      }
    }
    total += to - from;
    return total / seconds;
  }

  /// Pairs of different messages whose voices overlapped (a regroup chorus
  /// counts as one transmission).
  List<(HeardLine, HeardLine)> overlaps() {
    final out = <(HeardLine, HeardLine)>[];
    final sorted = [...heard]..sort((a, b) => a.start.compareTo(b.start));
    for (var i = 0; i < sorted.length; i++) {
      for (var j = i + 1; j < sorted.length; j++) {
        final a = sorted[i], b = sorted[j];
        if (b.start >= a.end - 1e-6) continue;
        if (a.message.overlap && b.message.overlap && a.trigger == b.trigger) {
          continue;
        }
        out.add((a, b));
      }
    }
    return out;
  }

  List<HeardLine> get cut => [
    for (final h in heard)
      if (h.cut) h,
  ];
}

/// Feeds a seeded stream of combat events to [c] for [seconds].
///
/// [busy] raises the event rates of a heavy sector-3 fight (ground war,
/// dives every couple of seconds, pickups, waves); otherwise a calm stretch.
/// [forecast] adds the observer's `groundFireForecast` ahead of each shot,
/// [intensity] the music director's tier (3 in busy combat, 1 when calm).
PacingStats simulate(
  CommsDirector c, {
  int seed = 1,
  double seconds = 600,
  bool busy = true,
  bool forecast = true,
  bool intensity = true,
}) {
  final stats = PacingStats(seconds);
  final byMessage = <CommsMessage, HeardLine>{};
  c
    ..setLineup(CommsLineup.pick(seed))
    ..onStart = (m) {
      final h = HeardLine(m)..end = m.speechEndsAt;
      byMessage[m] = h;
      stats.heard.add(h);
    }
    ..onStop = (m) {
      final h = byMessage[m];
      if (h != null && m.interrupted) {
        h
          ..cut = true
          ..end = math.min(h.end, c.now);
      }
    };
  final rng = math.Random(seed);
  double next(double mean) => -math.log(1 - rng.nextDouble()) * mean;
  final scheduled = <(double, GameEvent)>[];
  void at(double t, GameEvent e) => scheduled.add((t, e));
  final rate = busy ? 1.0 : 3.0; // mean gaps scale up in a calm stretch
  // Dives: the model's divePrep, then the observer's late calls.
  var t = 2.0;
  final diveStarts = <double>[];
  while (t < seconds) {
    final sentinel = rng.nextDouble() < .12;
    final elite = !sentinel && rng.nextDouble() < .15;
    final tell = sentinel ? .9 : (elite ? .55 : .7);
    final diveIn = .5 + tell;
    at(
      t,
      GameEvent(GameEventNames.divePrep, {
        'lead': .5,
        'diveIn': diveIn,
        'sentinel': sentinel,
        'elite': elite,
      }),
    );
    if (sentinel) {
      at(t + .5, GameEvent(GameEventNames.sentinelDive, {'diveIn': tell}));
    }
    stats.dives.add(t + diveIn);
    diveStarts.add(t + diveIn);
    t += busy ? 1.2 + rng.nextDouble() * 2.2 : 5 + next(8);
  }
  // The observer's "two dives within 1.2 s" call, at the second dive start.
  diveStarts.sort();
  for (var i = 1; i < diveStarts.length; i++) {
    if (diveStarts[i] - diveStarts[i - 1] <= 1.2) {
      at(
        diveStarts[i],
        const GameEvent(GameEventNames.diveWarning, {'diveIn': 0.0}),
      );
    }
  }
  // Ground fire at the player (GroundTuning): a unit that reaches fire
  // range spends its two shots a reload apart (tell + reload); now and
  // then a second unit fires alongside. One tell at a time.
  const reload = GroundTuning.telegraph + GroundTuning.cooldown;
  final preps = <double>[];
  // The observer's forecast of each shot (GameEventObserver.fireForecast
  // ahead, or at the previous launch for a unit's second shot), planned
  // before "one tell at a time" may push a launch a little later.
  final forecasts = <(double, double)>[];
  t = 8;
  while (t < seconds) {
    for (final u in [t, if (rng.nextDouble() < .35) t + .5]) {
      preps.addAll([u, u + reload]);
      final launch = u + GroundTuning.fireLead;
      // (when, launch): the second shot is forecast at the first launch.
      forecasts.addAll([
        (launch - GameEventObserver.fireForecast, launch),
        (launch, launch + reload),
      ]);
    }
    t += busy ? 18 + next(10) : 45 + next(30);
  }
  if (forecast) {
    for (final (forecastAt, launch) in forecasts) {
      if (launch >= seconds) continue;
      at(
        forecastAt,
        GameEvent(GameEventNames.groundFireForecast, {
          'fireIn': launch - forecastAt,
        }),
      );
    }
  }
  preps.sort();
  for (var k = 1; k < preps.length; k++) {
    preps[k] = math.max(preps[k], preps[k - 1] + GroundTuning.telegraph);
  }
  for (final prep in preps) {
    if (prep + GroundTuning.fireLead >= seconds) break;
    at(
      prep,
      const GameEvent(GameEventNames.groundFirePrep, {
        'fireIn': GroundTuning.fireLead,
      }),
    );
    final launch = prep + GroundTuning.fireLead;
    at(launch, const GameEvent(GameEventNames.groundMissileLaunch));
    stats.shots.add(launch);
  }
  // Pickups and the ship's powers.
  var shieldUntil = -1.0, weaponUntil = -1.0;
  final pickups = <(double, bool)>[];
  t = 5;
  while (t < seconds) {
    pickups.add((t, rng.nextDouble() < .4));
    t += busy ? 6 + next(8) : 20 + next(20);
  }
  // Everything else, as Poisson streams.
  const ground = [
    'groundForceSighted',
    'groundForceInRange',
    'groundUnitDestroyed',
    'allyUnderAttack',
    'allySaved',
    'groundSkirmish',
    'infantryEngaged',
    'skirmishWon',
    'allyFallingBack',
    'terrainAhead',
    'convoyClimbing',
  ];
  void stream(double mean, GameEvent Function() make) {
    var s = next(mean * rate);
    while (s < seconds) {
      at(s, make());
      s += next(mean * rate);
    }
  }

  stream(
    4,
    () => GameEvent(ground[rng.nextInt(ground.length)], const {
      'by': 'allies',
      'kind': 'ridge',
    }),
  );
  stream(30, () => const GameEvent(GameEventNames.waveStart));
  stream(30, () => const GameEvent(GameEventNames.broodTaunt));
  stream(45, () => const GameEvent(GameEventNames.transmissionJunior));
  // A reinforcement flock: the model's raw event and the music director's
  // arrival tell, in the same frame.
  var r = next(40 * rate);
  while (r < seconds) {
    at(r, const GameEvent(GameEventNames.reinforcements));
    at(r, const GameEvent(GameEventNames.reinforcementsArrived));
    r += next(40 * rate);
  }
  // A sentinel's escort wing (the model's `escort`, read as
  // sentinelIncoming).
  stream(60, () => const GameEvent(GameEventNames.sentinelIncoming));
  // The fight below: engaged stretches (and quiet ones) and, while engaged,
  // the ship flying over the battle or away from it. The observer reports
  // each change as `groundPicture`.
  var g = 4.0;
  var engaged = true;
  while (g < seconds) {
    final span = engaged
        ? (busy ? 14 : 8) + next(busy ? 14 : 8)
        : (busy ? 6 : 25) + next(busy ? 6 : 20);
    final end = math.min(seconds, g + span);
    if (engaged) {
      // Engaged from g to end; over in alternating stretches.
      stats.engagedSpans.add((g, end));
      var o = g;
      var over = rng.nextDouble() < .6;
      while (o < end) {
        final to = math.min(end, o + 2 + next(5));
        if (over) stats.overSpans.add((o, to));
        at(
          o,
          GameEvent(GameEventNames.groundPicture, {
            'engaged': 3,
            'threats': 1,
            'over': over,
          }),
        );
        over = !over;
        o = to;
      }
      at(
        end,
        const GameEvent(GameEventNames.groundPicture, {
          'engaged': 0,
          'threats': 0,
          'over': false,
        }),
      );
    }
    engaged = !engaged;
    g = end;
  }
  stream(35, () => const GameEvent(GameEventNames.eliteSighted));
  stream(20, () => const GameEvent(GameEventNames.demonRout));
  stream(40, () => const GameEvent(GameEventNames.heavyArmorSighted));
  stream(60, () => const GameEvent(GameEventNames.groundPressureHigh));
  stream(120, () => const GameEvent(GameEventNames.lifeLost));
  scheduled.sort((a, b) => a.$1.compareTo(b.$1));
  stats.allyCalls.addAll([
    for (final (t, e) in scheduled)
      if (e.name == GameEventNames.allyUnderAttack) t,
  ]);

  c.handle(const GameEvent('sectorStart', {'variant': '3'}), 0);
  if (intensity) {
    c.handle(
      GameEvent(GameEventNames.musicIntensity, {'tier': busy ? 3 : 1}),
      0,
    );
  }
  var i = 0, p = 0;
  const dt = 1 / 60;
  for (var now = 0.0; now < seconds; now += dt) {
    while (p < pickups.length && pickups[p].$1 <= now) {
      final (spawned, shield) = pickups[p++];
      final bare = shield ? spawned >= shieldUntil : spawned >= weaponUntil;
      if (bare) stats.hintChances.add(spawned);
      c.handle(
        GameEvent(
          shield ? GameEventNames.shieldSpotted : GameEventNames.powerupSpotted,
          {'hint': bare, if (!shield) 'variant': 'spread'},
        ),
        now,
      );
      // The player catches about two in three, a couple of seconds later.
      if (rng.nextDouble() < .65) {
        if (shield) {
          shieldUntil = spawned + 2 + 12;
          at(spawned + 2, const GameEvent(GameEventNames.shieldCollected));
        } else {
          weaponUntil = spawned + 2 + 15;
          at(
            spawned + 2,
            const GameEvent(GameEventNames.weaponPickup, {'variant': 'spread'}),
          );
        }
        scheduled.sort((a, b) => a.$1.compareTo(b.$1));
      }
    }
    while (i < scheduled.length && scheduled[i].$1 <= now) {
      final e = scheduled[i++].$2;
      c.handle(e, now);
      if (e.name == GameEventNames.lifeLost) {
        c.handle(const GameEvent(GameEventNames.regroupStart), now);
        at(now + 2.8, const GameEvent(GameEventNames.playerRespawn));
        scheduled.sort((a, b) => a.$1.compareTo(b.$1));
      }
    }
    c.update(now, combat: true);
  }
  return stats;
}
