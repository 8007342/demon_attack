import 'dart:ui' as ui;

import 'package:demon_attack/game/model.dart';
import 'package:demon_attack/game/weather/rain_layer.dart';
import 'package:demon_attack/game/weather/rain_plan.dart';
import 'package:flutter_test/flutter_test.dart';

/// dynamic-weather (openspec/changes/dynamic-weather): the seeded rain plan,
/// its soft transitions, the audio events and the draw budget.
void main() {
  group('rain plan', () {
    test('an unseeded run is always dry', () {
      for (var route = 0; route < 4; route++) {
        for (var sector = 1; sector <= 5; sector++) {
          expect(RainPlan.forLevel(null, route: route, sector: sector), isNull);
        }
      }
    });

    test('about one regular level in four rains; every tier appears', () {
      var levels = 0, wet = 0;
      final tiers = <RainTier, int>{};
      for (var seed = 1; seed <= 2000; seed++) {
        for (var route = 0; route < 3; route++) {
          for (var sector = 1; sector <= 4; sector++) {
            levels++;
            final s = RainPlan.forLevel(seed, route: route, sector: sector);
            if (s == null) continue;
            wet++;
            tiers[s.tier] = (tiers[s.tier] ?? 0) + 1;
            expect(s.peak, inInclusiveRange(.18, 1.0));
            expect(s.wind.abs(), inInclusiveRange(.02, .38));
            expect(RainTier.of(s.peak), s.tier);
          }
        }
      }
      expect(wet / levels, inInclusiveRange(.22, .28));
      expect(tiers.keys, containsAll(RainTier.values));
      expect(tiers[RainTier.downpour]! < tiers[RainTier.rain]!, isTrue);
    });

    test('the carrier sector and bonus levels stay dry', () {
      for (var seed = 1; seed <= 500; seed++) {
        expect(RainPlan.forLevel(seed, route: 0, sector: 5), isNull);
        expect(
          RainPlan.forLevel(seed, route: 0, sector: 2, bonus: true),
          isNull,
        );
      }
    });

    test('deterministic per run seed, route and sector', () {
      for (var seed = 1; seed <= 200; seed++) {
        final a = RainPlan.forLevel(seed, route: 1, sector: 3);
        final b = RainPlan.forLevel(seed, route: 1, sector: 3);
        expect(a?.toString(), b?.toString());
      }
    });

    test('rain starts and stops softly mid-level', () {
      RainSpec? late, stopping;
      for (var seed = 1; late == null || stopping == null; seed++) {
        expect(seed, lessThan(5000));
        final s = RainPlan.forLevel(seed, route: 0, sector: 1);
        if (s == null) continue;
        if (s.startAt > 0) late ??= s;
        if (s.stops) stopping ??= s;
      }
      for (final s in [late, stopping]) {
        expect(s.intensityAt(0, gusts: false), s.startAt > 0 ? 0 : s.peak);
        var prev = s.intensityAt(0);
        for (var t = 0.0; t < 200; t += .1) {
          final now = s.intensityAt(t);
          // No step larger than the ramps allow (soft, no pops).
          expect((now - prev).abs(), lessThan(.04), reason: '$s at $t');
          prev = now;
        }
      }
      expect(stopping.intensityAt(stopping.stopAt + stopping.rampOut), 0);
    });
  });

  group('rain layer', () {
    test('an unseeded campaign never rains and sends nothing', () {
      final events = <GameEvent>[];
      final layer = RainLayer(emit: events.add);
      final m = ArcadeModel(seed: 7)..startAt(sector: 2, wave: 1);
      m.mode = RunMode.playing;
      for (var f = 0; f < 600; f++) {
        m.levelClock += 1 / 60;
        layer.advance(1 / 60, m, reduced: false);
      }
      expect(layer.amount, 0);
      expect(events, isEmpty);
    });

    test('a seeded rainy level rains; the travel out fades it', () {
      int? seed;
      for (var s = 1; seed == null; s++) {
        final spec = RainPlan.forLevel(s, route: 0, sector: 2);
        if (spec != null &&
            spec.startAt == 0 &&
            BonusPlan.forRun(s).at(0, 2) == null) {
          seed = s;
        }
      }
      final events = <GameEvent>[];
      final layer = RainLayer(emit: events.add);
      final m = ArcadeModel(seed: 7)
        ..startAt(sector: 2, wave: 1, runSeed: seed);
      expect(m.bonus, isNull);
      m.mode = RunMode.playing;
      for (var f = 0; f < 600; f++) {
        m.levelClock += 1 / 60;
        layer.advance(1 / 60, m, reduced: false);
      }
      expect(layer.amount, greaterThan(.1));
      expect(events.first.name, GameEventNames.rainStart);
      m.mode = RunMode.travel;
      for (var f = 0; f < 60 * 4; f++) {
        layer.advance(1 / 60, m, reduced: false);
      }
      expect(layer.amount, 0);
      expect(events.last.name, GameEventNames.rainStop);
    });

    test('start, intensity and stop events, with no chatter', () {
      final events = <GameEvent>[];
      final layer = RainLayer(emit: events.add);
      for (var f = 0; f < 60 * 4; f++) {
        layer.advanceTo(1 / 60, .9, wind: .2);
      }
      // A gusty plateau on a tier boundary must not chatter.
      for (var f = 0; f < 600; f++) {
        layer.advanceTo(1 / 60, .72 + .02 * ((f ~/ 20).isEven ? 1 : -1));
      }
      for (var f = 0; f < 60 * 4; f++) {
        layer.advanceTo(1 / 60, 0);
      }
      final names = [for (final e in events) '${e.name}:${e.data['tier']}'];
      expect(names.first, 'rainStart:drizzle');
      expect(names, contains('rainIntensity:rain'));
      expect(names, contains('rainIntensity:downpour'));
      expect(names.last, startsWith('rainStop'));
      expect(names.length, lessThanOrEqualTo(8));
      for (final e in events) {
        expect(GameEventNames.weather, contains(e.name));
        expect(e.data.keys, containsAll(['tier', 'intensity', 'wind']));
      }
    });

    testWidgets('draw budget: batched counts at a downpour, lighter reduced', (
      tester,
    ) async {
      final layer = RainLayer(emit: (_) {});
      for (var f = 0; f < 60 * 4; f++) {
        layer.advanceTo(1 / 60, 1, wind: .3);
      }
      void paint() {
        final r = ui.PictureRecorder();
        layer.paint(ui.Canvas(r), headroom: 120);
        r.endRecording().dispose();
      }

      paint();
      expect(layer.lastFar, RainLayer.farMax);
      expect(layer.lastNear, RainLayer.nearMax);
      expect(layer.lastSplashes, inInclusiveRange(1, RainLayer.splashMax));
      final sw = Stopwatch()..start();
      for (var i = 0; i < 300; i++) {
        layer.advanceTo(1 / 60, 1);
        paint();
      }
      final us = sw.elapsedMicroseconds / 300;
      // ignore: avoid_print
      print(
        'rain downpour: far ${layer.lastFar}, near ${layer.lastNear}, '
        'splashes ${layer.lastSplashes}; record ${us.toStringAsFixed(0)} us',
      );
      expect(us, lessThan(2000));
      // CPU raster at phone size (3x the arena plus the band): an upper
      // bound for a GPU.
      Future<double> raster(void Function(ui.Canvas c) draw) async {
        final r = ui.PictureRecorder();
        final c = ui.Canvas(r)
          ..scale(3)
          ..translate(0, 120);
        draw(c);
        final pic = r.endRecording();
        (await pic.toImage(1080, 1920)).dispose();
        final sw = Stopwatch()..start();
        for (var i = 0; i < 10; i++) {
          (await pic.toImage(1080, 1920)).dispose();
        }
        pic.dispose();
        return sw.elapsedMicroseconds / 10000;
      }

      late double empty, full;
      await tester.runAsync(() async {
        empty = await raster((c) {});
        full = await raster((c) => layer.paint(c, headroom: 120));
      });
      // ignore: avoid_print
      print(
        'rain downpour cpu raster 1080x1920: ${full.toStringAsFixed(2)} ms '
        '(empty picture ${empty.toStringAsFixed(2)} ms)',
      );
      layer.reduced = true;
      paint();
      expect(
        layer.lastFar,
        (RainLayer.farMax * RainLayer.reducedCount).round(),
      );
      expect(layer.lastSplashes, 0);
    });

    test('the hash stays in range and spreads', () {
      var lo = 0, hi = 0;
      for (var i = 0; i < 10000; i++) {
        final h = RainLayer.hash(i * 7 + 3);
        expect(h, inInclusiveRange(0, 1));
        if (h < .5) {
          lo++;
        } else {
          hi++;
        }
      }
      expect(lo / 10000, inInclusiveRange(.45, .55));
      expect(hi, greaterThan(0));
    });
  });
}
