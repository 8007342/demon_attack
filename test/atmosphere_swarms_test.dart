// Atmosphere and swarm arrivals (openspec/changes/atmosphere-and-swarms):
// transmittance and the staged reveal, the sky-sheet cap over the ship,
// never-fogged bullets, flock determinism and timing parity, and the
// sentinel's foreshadowing as pure presentation.
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:demon_attack/game/atmosphere.dart';
import 'package:demon_attack/game/flock.dart';
import 'package:demon_attack/game/model.dart';
import 'package:demon_attack/game/scene.dart';
import 'package:flame/game.dart';
import 'package:flutter_test/flutter_test.dart';

/// A scripted pilot that never looks at entering creatures: sweeps the
/// ship and fires (the model fires on its own).
void _fly(ArcadeModel m, double seconds, void Function(int frame) each) {
  final frames = (seconds * 60).round();
  for (var f = 0; f < frames; f++) {
    final t = m.clock;
    m.moveTo(180 + 120 * math.sin(t * .9) + 30 * math.sin(t * 2.3));
    m.update(1 / 60);
    m.takeEvents();
    each(f);
  }
}

/// Everything the fight depends on, exactly: entering creatures by their
/// entrance clock only (they cannot be hit, do not fire or collide), every
/// other creature by its exact position.
String _signature(ArcadeModel m) {
  final b = StringBuffer()
    ..write('${m.mode} ${m.level} ${m.wave} ${m.score} ${m.lives} ')
    ..write('${m.kills} ${m.shots.length} ${m.incoming.length}|');
  for (final d in m.demons) {
    if (d.entering) {
      b.write('E${d.entranceProgress} ${d.waitingForEscort};');
    } else {
      b.write('${d.x},${d.y},${d.hp},${d.scale},${d.dive};');
    }
  }
  return b.toString();
}

void main() {
  group('transmittance and reveal', () {
    test('veils the arrival depth and clears the formation', () {
      expect(Perspective.transmittance(.30), inInclusiveRange(.03, .1));
      expect(Perspective.transmittance(.62), 1);
      var last = -1.0;
      for (var n = .2; n <= 1; n += .01) {
        final t = Perspective.transmittance(n);
        expect(t, greaterThanOrEqualTo(last));
        last = t;
      }
    });

    test('stages: silhouette, gear before fire, eyes through the fog', () {
      expect(Perspective.gearReveal(.25), 0);
      expect(Perspective.gearReveal(.4), 0);
      expect(Perspective.gearReveal(.7), 1);
      // Gear is complete by the formation's depth (before it can fire).
      expect(
        Perspective.gearReveal(Perspective.transmittance(Perspective.nearTop)),
        1,
      );
      for (var t = 0.0; t <= 1; t += .1) {
        expect(Perspective.glowAlpha(t), greaterThanOrEqualTo(.5));
      }
    });

    test('a holding wave never shows its gear', () {
      final m = ArcadeModel(seed: 7)..startAt(sector: 2, wave: 2);
      _fly(m, 6, (_) {});
      m.flocksSpawned = m.flocksPlanned;
      while (m.demons.length > 2) {
        m.demons.removeLast();
      }
      var held = 0;
      _fly(m, 5, (_) {
        for (final d in m.incoming) {
          if (d.isLarge) continue;
          held++;
          final t = Perspective.transmittance(d.nearness, holding: true);
          expect(t, lessThanOrEqualTo(Perspective.holdingCap));
          expect(Perspective.gearReveal(t), 0);
        }
      });
      expect(held, greaterThan(0));
    });

    test('veil matrix keeps alpha and reaches the veil colour', () {
      const veil = ui.Color(0xFF3D3550);
      final m = Atmosphere.veilMatrix(0, veil);
      expect(m.sublist(15), [0, 0, 0, 1, 0]);
      // At t 0 a white pixel is mostly the veil colour.
      final r = (m[0] + m[1] + m[2]) * 255 + m[4];
      expect(r / 255, closeTo(veil.r, .15));
      expect(Atmosphere.veilMatrix(1, veil).sublist(0, 5), [1, 0, 0, 0, 0]);
    });
  });

  group('fog layers', () {
    test('sky sheets stay at or under 12 % over the ship', () {
      for (var y = ArcadeModel.shipY - 30; y <= 520; y += 1) {
        expect(Atmosphere.sheetsAlphaAt(y), lessThanOrEqualTo(.12));
      }
      for (var y = 0.0; y <= 520; y += 4) {
        expect(Atmosphere.sheetAlphaAt(FogSlot.skySheet1, y), lessThan(.1));
        expect(Atmosphere.sheetAlphaAt(FogSlot.skySheet2, y), lessThan(.1));
      }
    });

    test('reduced atmosphere keeps the horizon band and ground fog only', () {
      final a = Atmosphere()..quality = AtmosphereQuality.reduced;
      expect(a.shows(FogSlot.horizonBand), isTrue);
      expect(a.shows(FogSlot.groundFog), isTrue);
      expect(a.shows(FogSlot.skySheet1), isFalse);
      expect(a.shows(FogSlot.skySheet2), isFalse);
      expect(a.shows(FogSlot.farBankA), isFalse);
      expect(a.usesShader, isFalse);
      expect(AtmosphereQuality.parse('reduced'), AtmosphereQuality.reduced);
      expect(AtmosphereQuality.parse(null), AtmosphereQuality.full);
    });

    testWidgets('slow frames turn the fog shader off; fast frames keep it', (
      tester,
    ) async {
      await tester.runAsync(() async {
        Future<Atmosphere> loaded() async {
          final a = Atmosphere();
          await a.load();
          return a;
        }

        final fast = await loaded();
        // No shader on this platform: nothing to guard.
        if (!fast.usesShader) {
          return;
        }
        for (var i = 0; i < Atmosphere.guardFrames * 2; i++) {
          fast.advance(1 / 60, distance: 0);
        }
        expect(fast.usesShader, isTrue);
        final slow = await loaded();
        for (var i = 0; i < Atmosphere.guardFrames; i++) {
          slow.advance(1 / 30, distance: 0);
        }
        expect(slow.usesShader, isFalse);
        expect(slow.shaderThrottled, isTrue);
        // A long gap (hidden tab) alone does not count as slow.
        final paused = await loaded();
        paused.advance(5, distance: 0);
        for (var i = 0; i < Atmosphere.guardFrames; i++) {
          paused.advance(1 / 60, distance: 0);
        }
        expect(paused.usesShader, isTrue);
      });
    });

    test('reduced motion keeps the layers still', () {
      final a = Atmosphere()..reducedMotion = true;
      a.advance(1, distance: 10);
      expect(a.time, 0);
    });

    test('fBm tiles are tileable and have wisps with gaps', () {
      final px = Atmosphere.bakeTile(size: 64, seed: 3);
      var zero = 0, full = 0;
      for (var i = 3; i < px.length; i += 4) {
        if (px[i] == 0) zero++;
        if (px[i] > 200) full++;
      }
      expect(zero, greaterThan(64 * 64 ~/ 20));
      expect(full, greaterThan(0));
      // Wraps: the left and right columns differ about as little as
      // neighbouring columns do.
      var edge = 0, inner = 0;
      for (var y = 0; y < 64; y++) {
        edge += (px[(y * 64 + 63) * 4 + 3] - px[(y * 64) * 4 + 3]).abs();
        inner += (px[(y * 64 + 31) * 4 + 3] - px[(y * 64 + 32) * 4 + 3]).abs();
      }
      expect(edge, lessThan(inner * 3 + 64 * 8));
    });

    testWidgets('bullets and the ship are drawn above every fog layer', (
      tester,
    ) async {
      await tester.runAsync(() async {
        final m = ArcadeModel(seed: 3)..startAt(sector: 1, wave: 2);
        _fly(m, 4, (_) {});
        m.shots
          ..clear()
          ..add(Shot(100, 300, 0, 0, hostile: true))
          ..add(Shot(250, 160, 0, 0));
        final scene = DemonScene(m, () {});
        await scene.atmosphere.load(shader: false);
        scene.atmosphere.time = 40; // dense fog somewhere
        Future<ui.Image> render() async {
          final r = ui.PictureRecorder();
          scene.paintArena(ui.Canvas(r), Vector2(360, 520));
          return r.endRecording().toImage(360, 520);
        }

        Future<List<int>> pixels(ui.Image img, List<(int, int)> at) async {
          final data = (await img.toByteData())!;
          return [for (final (x, y) in at) data.getUint32((y * 360 + x) * 4)];
        }

        // Bullet cores (drawn after the sheets) do not change with fog.
        const cores = [(100, 300), (250, 160)];
        final full = await pixels(await render(), cores);
        scene.atmosphere.quality = AtmosphereQuality.reduced;
        final reduced = await pixels(await render(), cores);
        expect(full, reduced);
      });
    });
  });

  group('flock arrivals', () {
    List<String> trace(int seed, {bool flock = true}) {
      final m = ArcadeModel(seed: seed)..flockArrivals = flock;
      m.startAt(sector: 3, wave: 2);
      final out = <String>[];
      _fly(m, 3, (f) {
        if (f % 6 != 0) return;
        out.add(
          [
            for (final d in m.demons)
              if (d.entering)
                '${d.x.toStringAsFixed(6)},${d.y.toStringAsFixed(6)}',
          ].join(' '),
        );
      });
      return out;
    }

    test('deterministic: same seed, same paths; another seed differs', () {
      final a = trace(11), b = trace(11), c = trace(12);
      expect(a, b);
      expect(a.where((s) => s.isNotEmpty), isNotEmpty);
      expect(a, isNot(c));
    });

    test('creatures emerge at different moments and speeds', () {
      final m = ArcadeModel(seed: 5)..startAt(sector: 2, wave: 2);
      final agents = [for (final d in m.demons) m.flock.of(d)]
          .whereType<FlockAgent>()
          .toList();
      expect(agents.length, greaterThanOrEqualTo(6));
      expect(agents.map((a) => a.launch).toSet().length, agents.length);
      expect(agents.map((a) => a.ease).toSet().length, agents.length);
      expect(agents.map((a) => a.squad).toSet().length, greaterThan(1));
    });

    test('settles into the slot without a jump', () {
      // A jump is a discontinuity in motion: the per-frame displacement
      // changing abruptly (a second difference), at the hand-off above all.
      final m = ArcadeModel(seed: 9)..startAt(sector: 2, wave: 2);
      final last = <Demon, (double, double)>{};
      final step = <Demon, (double, double)>{};
      var maxKink = 0.0;
      _fly(m, 6, (_) {
        for (final d in m.demons) {
          if (d.isLarge ||
              d.dive > 0 ||
              d.telegraph > 0 ||
              d.evadeLeft > 0 ||
              d.evadeOffset.abs() > .5) {
            last.remove(d);
            step.remove(d);
            continue;
          }
          final p = last[d];
          if (p != null) {
            final v = (d.x - p.$1, d.y - p.$2);
            final q = step[d];
            if (q != null) {
              final k = math.sqrt(
                math.pow(v.$1 - q.$1, 2) + math.pow(v.$2 - q.$2, 2),
              );
              // Arrivals only: the formation's own boids and sidesteps
              // after settling are the fight's (identical without the
              // flock, see the parity test).
              if (d.entering) {
                maxKink = math.max(maxKink, k);
              }
            }
            step[d] = v;
          }
          last[d] = (d.x, d.y);
        }
      });
      // Units per frame of change in per-frame motion (~ 18 000 u/s²).
      expect(maxKink, lessThan(5));
    });

    test('the flock never brings an arrival near the ship', () {
      final m = ArcadeModel(seed: 4)..startAt(sector: 3, wave: 2);
      _fly(m, 60, (_) {
        for (final d in m.demons) {
          if (!d.entering || m.flock.of(d) == null) continue;
          final dx = d.x - m.shipX, dy = d.y - ArcadeModel.shipY;
          expect(math.sqrt(dx * dx + dy * dy), greaterThan(.25 * 360));
        }
      });
    });

    test('parity: the fight is identical with and without the flock', () {
      for (final (sector, route) in [(1, 0), (3, 0), (2, 1), (4, 2)]) {
        final a = ArcadeModel(seed: 21 + sector)..flockArrivals = true;
        final b = ArcadeModel(seed: 21 + sector)..flockArrivals = false;
        a.startAt(sector: sector, route: route);
        b.startAt(sector: sector, route: route);
        final sa = <String>[], sb = <String>[];
        var flocked = 0;
        _fly(a, 150, (f) {
          sa.add(_signature(a));
          if (a.demons.any((d) => a.flock.of(d) != null)) flocked++;
        });
        _fly(b, 150, (f) => sb.add(_signature(b)));
        for (var i = 0; i < sa.length; i++) {
          if (sa[i] != sb[i]) {
            fail(
              'sector $sector route $route diverged at frame $i:\n'
              '${sa[i]}\n${sb[i]}',
            );
          }
        }
        expect(flocked, greaterThan(60), reason: 'the flock was in play');
      }
    });
  });

  group('sentinel foreshadowing', () {
    test('seen two waves ahead, nearer and larger the next wave', () {
      final probe = ArcadeModel(seed: 7)..startAt(sector: 2, route: 1);
      final w =
          [
            for (var i = 3; i <= probe.wavesPerLevel; i++)
              if (probe.sentinelFor(i) != null &&
                  probe.sentinelFor(i - 1) == null &&
                  probe.sentinelFor(i - 2) == null)
                i,
          ].firstOrNull ??
          3;
      expect(probe.sentinelFor(w), isNotNull);
      final early = ArcadeModel(seed: 7)
        ..startAt(sector: 2, route: 1, wave: w - 2);
      _fly(early, 8, (_) {});
      final f0 = early.foreshadow;
      expect(f0, isNotNull);
      expect(f0!.stage, 0);
      final near = ArcadeModel(seed: 7)
        ..startAt(sector: 2, route: 1, wave: w - 1);
      _fly(near, 8, (_) {});
      final f1 = near.foreshadow;
      expect(f1, isNotNull);
      expect(f1!.stage, .5);
      expect(f1.growth, greaterThan(f0.growth));
      // Over a whole figure-eight, nearer and larger on average.
      double meanScale(ArcadeModel m) {
        var s = 0.0;
        for (var i = 0; i < 100; i++) {
          m.foreshadow!
            ..clock = i / 10
            ..place(180);
          s += m.foreshadow!.scale;
        }
        return s / 100;
      }

      expect(meanScale(near), greaterThan(meanScale(early)));
      // Pure presentation: never a creature, never in the roster.
      expect(early.demons.where((d) => d.isLarge), isEmpty);
    });

    test('the sentinel sets out from its silhouette', () {
      final m = ArcadeModel(seed: 7)..startAt(sector: 2, route: 1, wave: 3);
      Demon? sentinel;
      _fly(m, 12, (_) {
        sentinel ??= m.demons.where((d) => d.isLarge).firstOrNull;
      });
      expect(sentinel, isNotNull);
      expect(sentinel!.entryN, isNotNull);
      expect(sentinel!.entryN!, lessThan(.35));
    });
  });
}
