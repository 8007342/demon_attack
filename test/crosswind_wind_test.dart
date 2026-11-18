import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:demon_attack/game/model.dart';
import 'package:demon_attack/game/music_director.dart';
import 'package:demon_attack/game/perf/frame_budget.dart';
import 'package:demon_attack/game/song_director.dart';
import 'package:demon_attack/game/song_map.dart';
import 'package:demon_attack/game/weather/wind_layer.dart';
import 'package:flutter_test/flutter_test.dart';

/// crosswind (openspec/changes/crosswind): the wind field, its plan, what
/// it does to the shots and the demons, its telegraph, its music and its
/// draw budget. Every loop here is bounded by a frame or seed count.
void main() {
  WindSpec gale(int seed) => WindPlan.draw(seed, tier: WindTier.gale);

  /// A run on [sector] with a gale forced on every level.
  ArcadeModel windy({int sector = 2, int seed = 7, String? bonus}) {
    final m = ArcadeModel(seed: seed)
      ..windRun.force = bonus == null ? (r, s) => gale(seed * 31 + s) : null;
    m.startAt(
      sector: sector,
      runSeed: bonus == null ? null : seed,
      bonus: bonus,
    );
    m.mode = RunMode.playing;
    return m;
  }

  group('wind field', () {
    test('deterministic: the same spec samples identically', () {
      for (var seed = 1; seed <= 40; seed++) {
        final a = WindField(gale(seed)), b = WindField(gale(seed));
        for (var t = 0.0; t < 120; t += .37) {
          expect(a.at(t).lateral, b.at(t).lateral);
          expect(a.at(t).along, b.at(t).along);
        }
      }
      // ... and different seeds blow differently.
      final a = WindField(gale(1)), b = WindField(gale(2));
      var differ = 0;
      for (var t = 0.0; t < 60; t += 1) {
        if ((a.at(t).lateral - b.at(t).lateral).abs() > .1) differ++;
      }
      expect(differ, greaterThan(10));
    });

    test('bounded: strengths within -1..1, a finite plan, holds in range', () {
      for (var seed = 1; seed <= 60; seed++) {
        for (final tier in WindTier.values) {
          final f = WindField(WindPlan.draw(seed, tier: tier));
          expect(f.shifts.length, lessThanOrEqualTo(WindField.maxShifts));
          expect(f.shifts.last.at, greaterThanOrEqualTo(WindField.horizon));
          for (var t = -2.0; t < 400; t += .5) {
            final s = f.at(t);
            expect(s.lateral.abs(), lessThanOrEqualTo(1));
            expect(s.along.abs(), lessThanOrEqualTo(1));
          }
          final hold = WindField.holdOf(tier);
          for (var i = 2; i < f.shifts.length; i++) {
            final gap = f.shifts[i].at - f.shifts[i - 1].at;
            expect(gap, lessThanOrEqualTo(hold.hi + 1e-9));
            expect(gap, greaterThanOrEqualTo(1.0));
          }
        }
      }
    });

    test('the direction swings: both sides within a minute', () {
      for (var seed = 1; seed <= 30; seed++) {
        final f = WindField(gale(seed));
        var left = false, right = false;
        for (var t = 0.0; t < 60; t += .25) {
          final l = f.at(t).lateral;
          if (l < -.3) left = true;
          if (l > .3) right = true;
        }
        expect(left && right, isTrue, reason: 'seed $seed');
      }
    });

    test('the forecast is the wind [lead] seconds ahead', () {
      final f = WindField(gale(5));
      for (var t = 0.0; t < 50; t += .7) {
        expect(f.forecast(t).lateral, f.at(t + WindField.lead).lateral);
      }
      expect(WindField.lead, greaterThanOrEqualTo(1.0));
    });
  });

  group('wind plan', () {
    test('unseeded runs, the carrier, bonus levels and the first sector '
        'are calm', () {
      for (var route = 0; route < 4; route++) {
        for (var sector = 1; sector <= 5; sector++) {
          expect(WindPlan.forLevel(null, route: route, sector: sector), isNull);
        }
      }
      for (var seed = 1; seed <= 500; seed++) {
        expect(WindPlan.forLevel(seed, route: 1, sector: 5), isNull);
        expect(WindPlan.forLevel(seed, route: 0, sector: 1), isNull);
        expect(
          WindPlan.forLevel(seed, route: 1, sector: 2, bonus: true),
          isNull,
        );
      }
    });

    test('"sometimes": about one eligible level in five; both tiers', () {
      var levels = 0, windy = 0;
      final tiers = <WindTier>{};
      for (var seed = 1; seed <= 2000; seed++) {
        for (var route = 0; route < 3; route++) {
          for (var sector = 1; sector <= 4; sector++) {
            if (route == 0 && sector == 1) continue;
            levels++;
            final s = WindPlan.forLevel(seed, route: route, sector: sector);
            if (s == null) continue;
            windy++;
            tiers.add(s.tier);
          }
        }
      }
      expect(windy / levels, inInclusiveRange(.17, .23));
      expect(tiers, {WindTier.breeze, WindTier.gale});
    });

    test('the calibrated campaign (unseeded) has no wind', () {
      final m = ArcadeModel(seed: 1982)..start();
      expect(m.windField, isNull);
      m.mode = RunMode.playing;
      for (var f = 0; f < 120; f++) {
        m.update(1 / 60);
      }
      expect(m.shots.every((s) => s.windVx == 0 && s.windVy == 0), isTrue);
    });
  });

  group('wind on the shots', () {
    test('deflects ours and the demons\' toward the wind, never faster '
        'than its drift', () {
      final m = windy()..invulnerable = 1e6;
      var player = 0, hostile = 0;
      for (var f = 0; f < 60 * 40; f++) {
        m.update(1 / 60);
        final w = m.windDrift;
        final peak = m.windRun.spec!.peakDrift;
        for (final s in m.shots) {
          expect(s.windVx.abs(), lessThanOrEqualTo(peak + 1e-9));
          if (w.abs() > peak * .5 && s.age > .6) {
            // Settled shots drift with a strong wind, both sides.
            if (s.windVx.sign == w.sign && s.windVx.abs() > peak * .2) {
              s.hostile ? hostile++ : player++;
            }
          }
        }
      }
      expect(player, greaterThan(0));
      expect(hostile, greaterThan(0));
    });

    test('a strong crosswind carries a shot a target\'s width off line', () {
      // A shot fired straight up from the ship's row into a steady full
      // crosswind: about 20 units by the swarm's rows (~0.7 s).
      final t = (ArcadeModel.shipY - 140) / ArcadeModel.shotSpeed;
      const tau = WindField.settle;
      final drift =
          WindField.peakDrift[WindTier.gale]! *
          (t - tau * (1 - math.exp(-t / tau)));
      expect(drift, inInclusiveRange(12.0, 30.0));
    });

    test('the tailwind speed-up is one hostile grid step at most', () {
      final m = windy(seed: 11)..invulnerable = 1e6;
      var boosted = 0;
      for (var f = 0; f < 60 * 60; f++) {
        m.update(1 / 60);
        for (final s in m.shots) {
          expect(s.windVy.abs(), anyOf(0.0, ArcadeModel.hostileSpeedGrid));
          if (s.windVy != 0) {
            boosted++;
            // Along its own track: faster, never slower.
            expect(s.windVy.sign, s.vy.sign);
          }
        }
      }
      expect(boosted, greaterThan(0));
      // On the grid: a player shot stays on whole quarter-units per step.
      const boostedStep = (ArcadeModel.shotSpeed + 15) / 60;
      expect((boostedStep * 4) % 1, 0);
    });

    test('a call comes [lead] seconds before its shift pushes', () {
      final m = windy(seed: 3)..invulnerable = 1e6;
      var calls = 0;
      for (var frame = 0; frame < 60 * 90; frame++) {
        m.update(1 / 60);
        for (final e in m.takeGameEvents()) {
          if (e.name != GameEventNames.windGust) continue;
          calls++;
          expect(e.data['endIn'], WindField.lead);
          // The shift it calls begins [lead] seconds later (one step of
          // slack either way).
          final t = m.levelClock;
          final f = m.windField!; // this level's field
          expect(
            f.shifts.any(
              (s) => (s.at - t - WindField.lead).abs() <= 1 / 30 + 1e-9,
            ),
            isTrue,
            reason: 'call at $t',
          );
        }
      }
      expect(calls, greaterThan(3));
    });
  });

  group('wind on the demons', () {
    test('they yield to it far less than shots, higher ranks least', () {
      final ordinary = Demon(0, 0, 0, 1, 1);
      final heavy = Demon(0, 0, 3, 1, 1);
      final elite = Demon(0, 0, 0, 1, 1, elite: true);
      final sentinel = Demon(
        0,
        0,
        0,
        9,
        1,
        archetype: EnemyArchetype.values.last,
      );
      final y = ArcadeWindDemons.windYield;
      expect(y(ordinary), lessThan(.3));
      expect(y(heavy), lessThan(y(ordinary)));
      expect(y(elite), lessThan(y(ordinary)));
      expect(y(sentinel), lessThan(y(elite)));
    });

    test('the push is bounded and fades when the wind does', () {
      final m = windy(seed: 5)..invulnerable = 1e6;
      final peak = m.windRun.spec!.peakDrift;
      var pushed = 0;
      for (var f = 0; f < 60 * 30; f++) {
        m.update(1 / 60);
        for (final d in m.demons) {
          // weather-everywhere: a smart diver riding a tailwind yields
          // more (ArcadeWindDive.rideYield): the curve of its dive.
          // (it eases back from that after the dive).
          final bound = math.max(
            peak * ArcadeWindDive.rideYield * ArcadeWindDive.rideHorizon,
            peak * .24 * ArcadeWindDemons.pushHorizon,
          );
          expect(d.windOffset.abs(), lessThanOrEqualTo(bound + 1));
          if (d.windOffset.abs() > 1) pushed++;
        }
      }
      expect(pushed, greaterThan(0));
    });
  });

  group('music', () {
    test('every called gust asks the music for its `gust` swell', () {
      final m = windy(seed: 3)..invulnerable = 1e6;
      var calls = 0, swells = 0;
      for (var f = 0; f < 60 * 60; f++) {
        m.update(1 / 60);
        for (final e in m.takeGameEvents()) {
          if (e.name == GameEventNames.windGust) calls++;
          if (e.name == musicAccentEvent && e.data['name'] == 'gust') swells++;
        }
      }
      expect(calls, greaterThan(0));
      expect(swells, calls);
    });

    test('the swell goes through bonus-music\'s accent event', () {
      expect(musicAccentEvent, MusicBridge.accentEvent);
      expect(scoreAccents, contains('gust'));
      final accents = <String>[];
      MusicBridge(onAccent: accents.add)(
        const GameEvent(musicAccentEvent, {'name': 'gust'}),
      );
      expect(accents, ['gust']);
    });

    test('Crosswind starts its own song, and fails soft without it', () {
      final played = <SongMove>[];
      SongDirector rig(Map<String, ScoreSong> songs) => SongDirector(
        sendMove: (m) {
          played.add(m);
          return 10;
        },
        clock: _Clock(),
        songs: songs,
        sendAccent: (_) {},
      );
      const start = GameEvent(GameEventNames.bonusStart, {
        'variant': 'crosswind',
      });
      final d = rig(scoreSongs)..cue('level', level: 2);
      d.onGameEvent(start);
      expect(played.last.song, scoreBonusSongs['crosswind']);
      // Without the song (an older score): no move, no crash.
      played.clear();
      final missing = Map.of(scoreSongs)..remove(scoreBonusSongs['crosswind']);
      final d2 = rig(missing)..cue('level', level: 2);
      final before = played.length;
      d2.onGameEvent(start);
      expect(played.length, before);
      expect(d2.log.map((s) => s.section), ['arrival']);
    });
  });

  group('wind layer budget', () {
    test('caps per tier, and nothing drawn when calm', () {
      final counts = <PerfTier, int>{};
      for (final tier in PerfTier.values) {
        final w = WindLayer()..budget = FrameBudget.of(tier).windScale;
        w.advanceTo(10, 1, 1);
        final rec = ui.PictureRecorder();
        final canvas = ui.Canvas(rec);
        w.paintSky(canvas, blur: FrameBudget.of(tier).blur);
        w.paintSock(canvas);
        rec.endRecording().dispose();
        expect(w.lastWisps, lessThanOrEqualTo(WindLayer.wispMax));
        expect(w.lastBillows, lessThanOrEqualTo(WindLayer.billowMax));
        counts[tier] = w.lastWisps + w.lastBillows;
      }
      expect(counts[PerfTier.lite]!, lessThan(counts[PerfTier.full]! * .4));
      expect(counts[PerfTier.lean]!, lessThan(counts[PerfTier.full]!));
      final calm = WindLayer();
      final rec = ui.PictureRecorder();
      calm.paintSky(ui.Canvas(rec));
      rec.endRecording().dispose();
      expect(calm.lastWisps + calm.lastBillows, 0);
    });
  });
}

class _Clock implements SongClock {
  @override
  double now = 0;
  @override
  ({String song, String section, double start})? position;
}
