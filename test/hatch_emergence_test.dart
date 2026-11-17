import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:demon_attack/game/carrier_gates.dart';
import 'package:demon_attack/game/carrier_hatch_painter.dart';
import 'package:demon_attack/game/hatch_emergence.dart';
import 'package:demon_attack/game/hatch_emergence_atlas.dart';
import 'package:demon_attack/game/hatch_emergence_painter.dart';
import 'package:demon_attack/game/model.dart';
import 'package:demon_attack/game/perf/frame_budget.dart';
import 'package:demon_attack/game/scene.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/counting_canvas.dart';

/// hatch-emergence (design §2–§6): the one-shot emergence of every creature a
/// carrier hatch launches, its timing inside the launch budget, its parity
/// with the simulation, the LITE skip and the budgets.
void main() {
  ArcadeModel fight({int route = 0, int seed = 4}) {
    final m = ArcadeModel(seed: seed)..startAt(sector: 5, route: route);
    for (var g = 0; g < 60 * 240; g++) {
      final b = m.boss;
      if (b != null && b.fightReady && m.combat) break;
      m.invulnerable = 2;
      for (final d in List.of(m.demons)) {
        if (!d.entering) m.hitDemon(d, damage: 99);
      }
      m.update(1 / 60);
    }
    expect(m.boss?.fightReady, isTrue);
    return m;
  }

  /// One fight step: the player is protected and the settled creatures are
  /// cleared, so the hatches keep launching (bounded by [frames]).
  void step(ArcadeModel m) {
    m.invulnerable = 2;
    for (final d in List.of(m.demons)) {
      if (!d.entering && !d.isLarge && d.y > 0) m.hitDemon(d, damage: 99);
    }
    m.update(1 / 60);
  }

  group('timing (design §3)', () {
    test('the lurk beats fit inside the telegraph and the opening', () {
      const v = CarrierVolleyTiming();
      expect(EmergeTiming.gripLead, lessThanOrEqualTo(v.telegraph));
      expect(EmergeTiming.peek2End, lessThan(v.open));
    });

    test('the launch beats fit inside the shortest transit', () {
      // The core door's 0.55 s entrance is the shortest; the upper tiers'
      // are longer. The leap, the unfurl and the flare end before it does,
      // leaving at least 0.1 s of glide before the hand-off.
      final shortest = CarrierHatches.transit(CarrierHatches.core.y);
      expect(shortest, closeTo(.55, 1e-9));
      expect(EmergeTiming.launchBeats + .1, lessThanOrEqualTo(shortest));
      for (var r = 0; r < 5; r++) {
        for (final h in CarrierHatches.forTour(r)) {
          expect(
            CarrierHatches.transit(h.y),
            greaterThanOrEqualTo(shortest),
            reason: h.id,
          );
        }
      }
    });

    test('each variant plays its beats in order, then glides', () {
      const h = CarrierHatches.core;
      for (final v in EmergeVariant.values) {
        final seen = <EmergePose>[];
        for (var e = 0.0; e < 1.2; e += 1 / 60) {
          final p = launchFrame(v, h, e).pose;
          if (seen.isEmpty || seen.last != p) seen.add(p);
        }
        expect(seen.toSet().length, seen.length, reason: '$v never repeats');
        expect(seen.last, EmergePose.glide2);
        expect(
          seen,
          containsAllInOrder([
            EmergePose.crouch2,
            EmergePose.leap,
            EmergePose.unfurl,
            EmergePose.flare,
            EmergePose.glide1,
          ]),
        );
      }
      // The blend into the model's own path is complete before the shortest
      // entrance ends: the hand-off to the flight sprites cannot jump.
      expect(launchFrame(EmergeVariant.peek, h, .56).toModel, closeTo(1, 1e-9));
    });

    test('the lead grips, peeks and holds; the others differ', () {
      const v = CarrierVolleyTiming();
      final h = CarrierHatches.forTour(0).first; // u1L
      List<EmergePose> lurk(EmergeVariant x) {
        final out = <EmergePose>[];
        for (var t = 0.0; t < v.telegraph; t += 1 / 60) {
          final f = lurkFrame(x, h, GateState.telegraph, t, v);
          if (f != null && (out.isEmpty || out.last != f.pose)) out.add(f.pose);
        }
        for (var t = 0.0; t < v.open + .4; t += 1 / 60) {
          final f = lurkFrame(x, h, GateState.opening, t, v);
          if (f != null && (out.isEmpty || out.last != f.pose)) out.add(f.pose);
        }
        return out;
      }

      expect(lurk(EmergeVariant.peek), [
        EmergePose.grip1,
        EmergePose.grip2,
        EmergePose.peek1,
        EmergePose.peek2,
        EmergePose.hold,
      ]);
      expect(lurk(EmergeVariant.vault), [EmergePose.grip1, EmergePose.grip2]);
      expect(lurk(EmergeVariant.spring), [EmergePose.grip1]);
      // The lead holds the outboard tusk; the vault the other one.
      expect(emergeFlip(EmergeVariant.peek, h), isTrue);
      expect(emergeFlip(EmergeVariant.vault, h), isFalse);
    });
  });

  group('the fight (design §2, §6)', () {
    test('parity: the director never changes the simulation', () {
      final a = fight(), b = fight();
      final dir = HatchEmergence();
      List<num> fp(ArcadeModel m) => [
        m.boss!.x,
        m.boss!.shield,
        m.demons.length,
        for (final d in m.demons) ...[d.x, d.y, d.hp, d.entranceProgress],
        m.score,
      ];
      for (var f = 0; f < 60 * 30; f++) {
        step(a);
        step(b);
        dir.update(a);
        dir.lurking(a);
      }
      expect(dir.started, greaterThan(0));
      expect(fp(a), fp(b));
    });

    test('every launch plays its sequence exactly once', () {
      for (final route in [0, 2, 4]) {
        final m = fight(route: route, seed: 7 + route);
        final dir = HatchEmergence();
        final launched = Set<Demon>.identity();
        for (var f = 0; f < 60 * 40; f++) {
          step(m);
          for (final d in m.demons) {
            if (d.entering &&
                d.entranceStartX != null &&
                !d.isLarge &&
                emergeRow(d.kind) != null) {
              launched.add(d);
            }
          }
          dir.update(m);
          // While a registered creature enters, it is drawn by its sequence.
          for (final e in dir.active) {
            expect(e.frame, isNotNull);
          }
        }
        expect(launched, isNotEmpty, reason: 'route $route');
        expect(dir.started, launched.length, reason: 'route $route');
        expect(
          dir.finished + dir.active.length + dir.dropped,
          dir.started,
          reason: 'route $route',
        );
        final variants = <EmergeVariant>{};
        for (final e in dir.history) {
          variants.add(e.variant);
          expect(
            e.shown.toSet().length,
            e.shown.length,
            reason: 'one pass, never restarted: ${e.shown}',
          );
          if (e.done && !e.cut) {
            expect(
              e.shown,
              containsAllInOrder([
                EmergePose.leap,
                EmergePose.unfurl,
                EmergePose.flare,
              ]),
            );
          }
        }
        expect(variants.length, greaterThanOrEqualTo(2), reason: 'variety');
      }
    });

    test('held hatches show their lurkers, within the budget', () {
      final m = fight();
      final dir = HatchEmergence();
      var most = 0, seen = 0;
      for (var f = 0; f < 60 * 20; f++) {
        step(m);
        dir.update(m);
        final l = dir.lurking(m);
        if (l.isNotEmpty) seen++;
        if (l.length > most) most = l.length;
      }
      expect(seen, greaterThan(0));
      // FULL: three a hatch, at most two hatches busy at once.
      expect(most, lessThanOrEqualTo(3 * const CarrierVolleyTiming().maxOpen));
    });
  });

  group('phone tiers (design §5)', () {
    test('LITE skips the emergence and the vents cleanly', () {
      final m = fight();
      final scene = DemonScene(m, () {});
      scene.perf.forced = PerfTier.lite;
      scene.applyBudget();
      expect(scene.emergence.enabled, isFalse);
      expect(scene.emergence.lurkers, 0);
      expect(scene.hatchPainter.rich, isFalse);
      for (var f = 0; f < 60 * 20; f++) {
        step(m);
        scene.emergence.update(m);
        expect(scene.emergence.lurking(m), isEmpty);
        expect(scene.emergence.active, isEmpty);
      }
      expect(scene.emergence.started, 0);
      scene.perf.forced = PerfTier.lean;
      scene.applyBudget();
      expect(scene.emergence.enabled, isTrue);
      expect(scene.emergence.lurkers, 1);
      scene.perf.forced = PerfTier.full;
      scene.applyBudget();
      expect(scene.emergence.lurkers, 3);
      expect(scene.hatchPainter.rich, isTrue);
    });

    test('the atlas holds its budget', () {
      final bytes = File('assets/images/hatch-emergence.png').readAsBytesSync();
      final bd = ByteData.sublistView(bytes);
      final w = bd.getUint32(16), h = bd.getUint32(20); // the IHDR
      expect(
        w,
        HatchEmergenceAtlas.cellWidth * HatchEmergenceAtlas.poses.length,
      );
      expect(
        h,
        HatchEmergenceAtlas.cellHeight * HatchEmergenceAtlas.rows.length,
      );
      expect(HatchEmergenceAtlas.poses, [
        for (final p in EmergePose.values) p.name,
      ]);
      expect(HatchEmergenceAtlas.rows, ['violet', 'coral', 'gold']);
      // Budgets (design §5): ≤ 64 KB on the wire, ≤ 1 MB resident, a cell
      // no larger than 80 x 80 stored px, one page.
      expect(bytes.length, lessThanOrEqualTo(64 * 1024));
      expect(w * h * 4, lessThanOrEqualTo(1024 * 1024));
      expect(HatchEmergenceAtlas.cellWidth, lessThanOrEqualTo(80));
      expect(HatchEmergenceAtlas.cellHeight, lessThanOrEqualTo(80));
    });

    test('draw calls: one image per creature, the hatches bounded', () async {
      final bytes = File('assets/images/hatch-emergence.png').readAsBytesSync();
      final codec = await ui.instantiateImageCodec(bytes);
      final image = (await codec.getNextFrame()).image;
      codec.dispose();
      final m = fight(route: 4);
      final dir = HatchEmergence();
      final hatches = CarrierHatchPainter();
      final painter = HatchEmergencePainter()..image = image;
      var worstHatch = 0, worstEmerge = 0, frames = 0;
      for (var f = 0; f < 60 * 20; f++) {
        step(m);
        dir.update(m);
        hatches.update(m.boss, m.visualClock);
        if (f % 5 != 0) continue;
        final rec = ui.PictureRecorder();
        final c = CountingCanvas(rec);
        final b = m.boss!;
        hatches.paintHatches(c, b, m.launches, clock: m.visualClock);
        final hatchCalls = c.total.calls;
        painter.beginFrame();
        final lurk = dir.lurking(m);
        for (final (g, fr, row) in lurk) {
          painter.paint(c, fr, row, ui.Offset(b.x + g.x, b.y + g.y));
        }
        for (final e in dir.active) {
          painter.paint(
            c,
            e.frame!,
            e.row,
            ui.Offset(b.x + e.hatch.x, b.y + e.hatch.y),
            modelAt: ui.Offset(e.demon.x, e.demon.y),
          );
        }
        rec.endRecording().dispose();
        expect(painter.calls, lurk.length + dir.active.length);
        expect(c.total.images, painter.calls);
        if (hatchCalls > worstHatch) worstHatch = hatchCalls;
        if (painter.calls > worstEmerge) worstEmerge = painter.calls;
        frames++;
      }
      image.dispose();
      expect(frames, greaterThan(0));
      expect(worstEmerge, greaterThan(0));
      // Tour 5 (8 upper hatches): the hatches, their fields, vents, bursts
      // and splinters stay within the budget (design §5).
      expect(worstHatch, lessThanOrEqualTo(HatchBudget.hatchCalls));
      expect(worstEmerge, lessThanOrEqualTo(HatchBudget.emergeCalls));
      // ignore: avoid_print
      print(
        "HATCH_BUDGET worst hatch calls $worstHatch, emergence $worstEmerge",
      );
    });
  });
}
