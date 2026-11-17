// phone-performance §7: the performance regression gate. Budgets on counts
// (draw calls, steps per frame, tier changes), never on wall time, so they
// hold on any machine. The heavy per-layer harness is the review test
// phone_performance_review_test.dart.
import 'dart:ui' as ui;

import 'package:demon_attack/game/model.dart';
import 'package:demon_attack/game/perf/frame_budget.dart';
import 'package:demon_attack/game/scene.dart';
import 'package:demon_attack/game/ship_painter.dart';
import 'package:demon_attack/game/shot_layer.dart';
import 'package:flame/game.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/counting_canvas.dart';

/// Steps a fixed 1/60 s accumulator through [intervals]; returns how many
/// frames stepped 0 times and how many stepped 2 or more.
(int, int) _cadence(Iterable<double> intervals, double Function(double) f) {
  var acc = 0.0, idle = 0, twice = 0;
  for (final dt in intervals) {
    acc += f(dt);
    var steps = 0;
    while (acc >= 1 / 60) {
      acc -= 1 / 60;
      steps++;
    }
    if (steps == 0) idle++;
    if (steps >= 2) twice++;
  }
  return (idle, twice);
}

ArcadeModel _fight(int shots) {
  final m = ArcadeModel(seed: 4)..startAt(sector: 2);
  m.mode = RunMode.playing;
  m.shots.clear();
  for (var i = 0; i < shots; i++) {
    m.shots.add(
      Shot(
        20 + (i * 13) % 320,
        40 + (i * 29) % 440,
        ((i % 5) - 2) * 30.0,
        i.isEven ? -390 : 240,
        hostile: i.isOdd,
        kind: i % 7 == 0 ? ShotKind.sentinel : ShotKind.ordinary,
      )..age = i * .02,
    );
  }
  return m;
}

void main() {
  group('frame pacing (§5.1)', () {
    // Rounded rAF timestamps: 16 or 17 ms, never 16.67 (one Safari-like
    // quantisation), and a 59.94 Hz panel.
    final rounded = [for (var i = 0; i < 600; i++) i % 3 == 0 ? .016 : .017];
    final ntsc = List.filled(600, 1 / 59.94);

    test('a jittered 60 Hz vsync steps the model exactly once a frame', () {
      final (idleRaw, doubleRaw) = _cadence(rounded, (d) => d);
      final (idle, dbl) = _cadence(rounded, snapFrameDelta);
      expect(idleRaw + doubleRaw, greaterThan(100), reason: 'the strobe');
      expect(idle, 0);
      expect(dbl, 0);
      final (i2, d2) = _cadence(ntsc, snapFrameDelta);
      expect(i2 + d2, 0);
    });

    test('30 Hz (Low Power Mode) steps exactly twice; 120 Hz passes', () {
      final low = [for (var i = 0; i < 300; i++) i.isEven ? .033 : .034];
      var acc = 0.0;
      for (final dt in low) {
        acc += snapFrameDelta(dt);
        var steps = 0;
        while (acc >= 1 / 60) {
          acc -= 1 / 60;
          steps++;
        }
        expect(steps, 2);
      }
      expect(snapFrameDelta(1 / 120), 1 / 120);
      expect(snapFrameDelta(.05), .05);
    });
  });

  group('quality tiers (§3)', () {
    test('a steady 60 Hz device stays at the full tier', () {
      final g = PerfGovernor();
      for (var i = 0; i < 60 * 60; i++) {
        g.frame(i % 50 == 0 ? .03 : 1 / 60); // 2 % hitches
      }
      expect(g.tier, PerfTier.full);
      expect(g.changes, 0);
    });

    test('sustained slow frames step down to lite in two windows', () {
      final g = PerfGovernor();
      var t = 0.0;
      while (g.tier != PerfTier.lite && t < 30) {
        g.frame(1 / 30);
        t += 1 / 30;
      }
      expect(g.tier, PerfTier.lite);
      expect(t, lessThan(PerfGovernor.warmup + 2 * 4.0 + .5));
    });

    test('recovers after calm, and a flap pins the ceiling', () {
      final g = PerfGovernor();
      void run(double dt, double seconds) {
        for (var t = 0.0; t < seconds; t += dt) {
          g.frame(dt);
        }
      }

      // Slow frames until the first step down (warm-up plus one window).
      void until(PerfTier t) {
        for (var i = 0; i < 60 * 30 && g.tier != t; i++) {
          g.frame(1 / 30);
        }
      }

      until(PerfTier.lean);
      expect(g.tier, PerfTier.lean);
      run(1 / 60, PerfGovernor.upSeconds + 3);
      expect(g.tier, PerfTier.full);
      until(PerfTier.lean); // straight back down: it can't hold full
      expect(g.tier, PerfTier.lean);
      expect(g.ceiling, PerfTier.lean.index);
      run(1 / 60, 3 * PerfGovernor.upSeconds);
      expect(g.tier, PerfTier.lean, reason: 'no oscillation');
    });

    test('background-tab gaps and a forced tier are respected', () {
      final g = PerfGovernor(forced: PerfTier.lite);
      for (var i = 0; i < 2000; i++) {
        g.frame(1 / 60);
      }
      expect(g.tier, PerfTier.lite);
      final h = PerfGovernor();
      for (var i = 0; i < 2000; i++) {
        h.frame(i % 10 == 0 ? 2.0 : 1 / 60); // a tab coming back
      }
      expect(h.tier, PerfTier.full);
      expect(PerfTier.parse('lite'), PerfTier.lite);
      expect(PerfTier.parse('nope'), isNull);
    });

    test('each tier draws no more than the one above it', () {
      const tiers = [FrameBudget.full, FrameBudget.lean, FrameBudget.lite];
      for (var i = 1; i < tiers.length; i++) {
        final a = tiers[i - 1], b = tiers[i];
        expect(b.rainScale, lessThanOrEqualTo(a.rainScale));
        expect(b.moteScale, lessThanOrEqualTo(a.moteScale));
        expect(b.blasts, lessThanOrEqualTo(a.blasts));
        expect(!b.blur || a.blur, isTrue);
        expect(!b.sparks || a.sparks, isTrue);
        expect(!a.fogReduced || b.fogReduced, isTrue);
      }
    });
  });

  group('shots (§6)', () {
    test(
      'drawn where they are now: model position + velocity x banked time',
      () {
        final s = Shot(100, 300, 40, -390);
        final at = ShotLayer.drawn(s, .01, 1);
        expect(at.dx, (100 + 40 * .01).roundToDouble());
        expect(at.dy, (300 - 3.9).roundToDouble());
        final h = Shot(100, 300, 40, 240, hostile: true);
        expect(
          ShotLayer.drawn(h, .01, .5).dx,
          (100 + 40 * .01 * .5).roundToDouble(),
        );
        final m = ArcadeModel(seed: 1)..startAt(sector: 1);
        m.mode = RunMode.paused;
        expect(ShotLayer.leadOf(m), 0);
      },
    );

    test('the shimmer runs on age (12 Hz), not on height', () {
      final s = Shot(100, 300, 0, -390);
      final frames = <int>[];
      for (var f = 0; f < 24; f++) {
        s
          ..age = f / 60
          ..y = 300 - f * 6.5;
        frames.add(ShipPainter.shotFrame(s));
      }
      // Five frames of one, five of the other: a steady rhythm.
      expect(frames.take(10), [0, 0, 0, 0, 0, 1, 1, 1, 1, 1]);
    });

    test('a bullet fight is a handful of draw calls, whatever its size', () {
      final small = _fight(10), big = _fight(240);
      int calls(ArcadeModel m, {bool smear = true}) {
        final rec = ui.PictureRecorder();
        final c = CountingCanvas(rec);
        ShotLayer().paint(c, m, ShipPainter(), smear: smear);
        rec.endRecording().dispose();
        return c.total.calls;
      }

      // Without the atlas (the block fallback): one path per colour.
      expect(calls(small), lessThanOrEqualTo(16));
      expect(calls(big), lessThanOrEqualTo(16));
      expect(calls(big), calls(small), reason: 'independent of count');
    });
  });

  group('scene (§4)', () {
    test('the backdrop lands on the sector after the approach', () {
      final m = ArcadeModel(seed: 3)..startAt(sector: 3);
      m.mode = RunMode.playing;
      final scene = DemonScene(m, () {});
      scene.environment = 2 - 1e-12;
      scene.advancePresentation(1 / 60);
      expect(scene.environment, 2.0);
    });

    test('the tier reaches the painters; the player choice is kept', () {
      final m = ArcadeModel(seed: 3)..startAt(sector: 3);
      final scene = DemonScene(m, () {});
      scene.perf.forced = PerfTier.lite;
      scene.applyBudget();
      expect(scene.atmosphere.tierReduced, isTrue);
      expect(scene.rain.budget, FrameBudget.lite.rainScale);
      expect(scene.sectors.moteScale, FrameBudget.lite.moteScale);
      expect(scene.atmosphere.quality.name, 'full', reason: 'saved choice');
      scene.perf.forced = PerfTier.full;
      scene.applyBudget();
      expect(scene.atmosphere.tierReduced, isFalse);
    });

    test('the shots layer of a 200-shot frame stays batched', () {
      final m = _fight(200);
      final scene = DemonScene(m, () {});
      final rec = ui.PictureRecorder();
      final c = CountingCanvas(rec);
      scene.paintArena(c, Vector2(390, 844));
      rec.endRecording().dispose();
      final shots = c.layers['shots'];
      expect(shots, isNotNull);
      expect(shots!.calls, lessThanOrEqualTo(16));
      expect(scene.shots.lastCalls, shots.calls);
    });
  });
}
