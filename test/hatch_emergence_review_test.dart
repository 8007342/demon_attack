@Tags(['review'])
library;

import 'dart:io';
import 'dart:ui' as ui;

import 'package:demon_attack/game/boss_atlas.dart';
import 'package:demon_attack/game/boss_grammar.dart';
import 'package:demon_attack/game/carrier_gates.dart';
import 'package:demon_attack/game/carrier_hatch_painter.dart';
import 'package:demon_attack/game/hatch_emergence.dart';
import 'package:demon_attack/game/hatch_emergence_atlas.dart';
import 'package:demon_attack/game/hatch_emergence_painter.dart';
import 'package:demon_attack/game/model.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

import 'boss_carrier_wire_review_test.dart' show seedFor;
import 'fluid_transitions_test.dart' show dispose, launch;
import 'playtest_fixes_review_test.dart' show decodeReviewImage, loadReviewArt;

/// hatch-emergence review (design §6), opt-in:
///
///   flutter test --concurrency=1 --run-skipped --tags review \
///     test/hatch_emergence_review_test.dart --dart-define=HATCH_EMERGENCE_CONTACT=true
///
/// - `closeups`: one hatch at ×3 through its telegraph (pulse, grips), its
///   opening (peeks, the held door, steam), the launch (crouch, leap, glide),
///   its field thinning hit by hit, and its break;
/// - `strips`: per species, the 12 atlas poses at ×4, then the lead's drawn
///   sequence over time at a hatch;
/// - `fight` (+ `.gif`): real 360 × 640 page frames of one launch in the
///   fight (tour 1, violet), every 1/15 s.
///
/// Sheets go to `art/contact/hatch-emergence-<name>.png`; the GIF frames to
/// `.cache/hatch-emergence-review/fight/`, packed with tools/gifstrip.
const _contact = bool.fromEnvironment('HATCH_EMERGENCE_CONTACT');
const _dir = '.cache/hatch-emergence-review';
const _bg = Color(0xFF1A1424), _hull = Color(0xFF2E2438);

Future<void> _save(String path, ui.Image img) async {
  final png = await img.toByteData(format: ui.ImageByteFormat.png);
  final f = File(path);
  await f.parent.create(recursive: true);
  await f.writeAsBytes(png!.buffer.asUint8List());
}

/// A sheet of [cells] (each [w] × [h]) in [cols] columns.
Future<ui.Image> _grid(List<ui.Image> cells, int cols, {double gap = 4}) async {
  final w = cells.first.width.toDouble(), h = cells.first.height.toDouble();
  final rows = (cells.length / cols).ceil();
  final sw = gap + cols * (w + gap), sh = gap + rows * (h + gap);
  final rec = ui.PictureRecorder();
  final c = ui.Canvas(rec);
  c.drawRect(
    Rect.fromLTWH(0, 0, sw, sh),
    Paint()..color = const Color(0xFF0C0A12),
  );
  for (final (i, f) in cells.indexed) {
    c.drawImage(
      f,
      Offset(gap + (i % cols) * (w + gap), gap + (i ~/ cols) * (h + gap)),
      Paint(),
    );
  }
  final pic = rec.endRecording();
  final img = await pic.toImage(sw.round(), sh.round());
  pic.dispose();
  return img;
}

/// A painter-level close-up: a 120 × 120-unit window round hatch [g] of
/// carrier [b], drawn at ×[k] on a plain hull.
Future<ui.Image> _closeup(
  Carrier b,
  CarrierLaunches l,
  CarrierHatchPainter hatches,
  HatchEmergencePainter em,
  CarrierGate g, {
  List<(EmergeFrame, int)> lurk = const [],
  (EmergeFrame, int, Offset)? flier,
  double clock = 0,
  double k = 3,
}) async {
  const win = 120.0;
  final at = Offset(b.x + g.x, b.y + g.y);
  final rec = ui.PictureRecorder();
  final c = ui.Canvas(rec);
  c.drawRect(Rect.fromLTWH(0, 0, win * k, win * k), Paint()..color = _bg);
  c.scale(k);
  c.translate(win / 2 - at.dx, win * .62 - at.dy);
  c.drawCircle(at, 70, Paint()..color = _hull);
  hatches.paintHatches(c, b, l, clock: clock);
  for (final (f, row) in lurk) {
    em.paint(c, f, row, at);
  }
  if (flier != null) em.paint(c, flier.$1, flier.$2, at, modelAt: flier.$3);
  final pic = rec.endRecording();
  final img = await pic.toImage((win * k).round(), (win * k).round());
  pic.dispose();
  return img;
}

void main() {
  testWidgets('close-ups and strips (painter level)', (tester) async {
    await tester.runAsync(() async {
      final atlas = await decodeReviewImage(
        'assets/images/${HatchEmergenceAtlas.asset.split('/').last}',
      );
      final em = HatchEmergencePainter()..image = atlas;
      const v = CarrierVolleyTiming();

      // ---- close-ups: hatch u1R of tour 1, a violet volley.
      final b = Carrier(0)
        ..x = 180
        ..y = 210;
      final gates = CarrierHatches.forTour(0);
      final l = CarrierLaunches(gates: gates, order: const [], seed: 1);
      final run = l.runs[1]; // u1R
      final g = run.gate;
      final hatches = CarrierHatchPainter();
      final cells = <ui.Image>[];
      Future<void> shot(
        double clock, {
        bool lurkers = true,
        (EmergeFrame, int, Offset)? flier,
      }) async {
        hatches.update(b, clock);
        final lurk = <(EmergeFrame, int)>[
          if (lurkers)
            for (var i = 0; i < 3; i++)
              if (lurkFrame(emergeVariantOf(i), g, run.state, run.t, v)
                  case final f?)
                (f, 0),
        ];
        cells.add(
          await _closeup(
            b,
            l,
            hatches,
            em,
            g,
            lurk: lurk,
            flier: flier,
            clock: clock,
          ),
        );
      }

      var clock = 0.0;
      run
        ..state = GateState.telegraph
        ..tier = 1;
      for (final t in [.3, .8, 1.05]) {
        run.t = t;
        await shot(clock += .1);
      }
      run.state = GateState.opening;
      for (final t in [.05, .1, .25, .45]) {
        run.t = t;
        await shot(clock += .05);
      }
      run
        ..state = GateState.launching
        ..t = 0;
      final at = Offset(b.x + g.x, b.y + g.y);
      for (final e in [.04, .12, .22, .32, .4, .5]) {
        final model = Offset.lerp(at, Offset(at.dx - 20, at.dy + 90), e / 1.1)!;
        await shot(
          clock += .05,
          lurkers: false,
          flier: (launchFrame(EmergeVariant.peek, g, e), 0, model),
        );
      }
      run.state = GateState.closed;
      // The field thinning hit by hit, then the break.
      final h = b.hatches[1];
      for (final share in [1.0, .66, .33, .1]) {
        h.field = (h.fieldMax * share).ceil();
        await shot(clock += .1, lurkers: false);
        await shot(clock += .06, lurkers: false); // the ripple
        cells.removeAt(cells.length - 2);
      }
      h
        ..field = 0
        ..hull = 0
        ..fallen = 0;
      for (final dt in [.03, .12, .3]) {
        await shot(clock += dt, lurkers: false);
      }
      final sheet = await _grid(cells, 6);
      if (_contact) {
        await _save('art/contact/hatch-emergence-closeups.png', sheet);
      }
      sheet.dispose();
      for (final c in cells) {
        c.dispose();
      }

      // ---- strips: per species, the atlas poses ×4, then the drawn
      // sequence (lurk, launch) at a fresh hatch.
      final rows = <ui.Image>[];
      for (var row = 0; row < HatchEmergenceAtlas.rows.length; row++) {
        final poses = <ui.Image>[];
        for (final p in EmergePose.values) {
          final rec = ui.PictureRecorder();
          final c = ui.Canvas(rec);
          const w = HatchEmergenceAtlas.cellWidth * 4.0,
              hh = HatchEmergenceAtlas.cellHeight * 4.0;
          c.drawRect(const Rect.fromLTWH(0, 0, w, hh), Paint()..color = _bg);
          c.drawImageRect(
            atlas,
            Rect.fromLTWH(
              p.index * HatchEmergenceAtlas.cellWidth.toDouble(),
              row * HatchEmergenceAtlas.cellHeight.toDouble(),
              HatchEmergenceAtlas.cellWidth.toDouble(),
              HatchEmergenceAtlas.cellHeight.toDouble(),
            ),
            const Rect.fromLTWH(0, 0, w, hh),
            Paint()..filterQuality = FilterQuality.none,
          );
          // the rim line (z = 0)
          c.drawLine(
            const Offset(0, HatchEmergenceAtlas.originY * 4),
            const Offset(w, HatchEmergenceAtlas.originY * 4),
            Paint()..color = const Color(0x55FF5A36),
          );
          final pic = rec.endRecording();
          poses.add(await pic.toImage(w.round(), hh.round()));
          pic.dispose();
        }
        rows.add(await _grid(poses, 12, gap: 2));
        for (final p in poses) {
          p.dispose();
        }
        // The drawn sequence at a hatch.
        final hb = Carrier(0)
          ..x = 180
          ..y = 210;
        final hl = CarrierLaunches(gates: gates, order: const [], seed: 1);
        final hr = hl.runs[1]..tier = row + 1;
        final hp = CarrierHatchPainter();
        final seq = <ui.Image>[];
        var ck = 0.0;
        Future<void> frame({
          EmergeFrame? lurk,
          (EmergeFrame, Offset)? fly,
        }) async {
          hp.update(hb, ck += .05);
          seq.add(
            await _closeup(
              hb,
              hl,
              hp,
              em,
              hr.gate,
              lurk: [if (lurk != null) (lurk, row)],
              flier: fly == null ? null : (fly.$1, row, fly.$2),
              clock: ck,
              k: 2,
            ),
          );
        }

        hr.state = GateState.telegraph;
        for (final t in [.8, 1.05]) {
          hr.t = t;
          await frame(
            lurk: lurkFrame(EmergeVariant.peek, hr.gate, hr.state, t, v),
          );
        }
        hr.state = GateState.opening;
        for (final t in [.1, .25, .45]) {
          hr.t = t;
          await frame(
            lurk: lurkFrame(EmergeVariant.peek, hr.gate, hr.state, t, v),
          );
        }
        hr.state = GateState.launching;
        final at = Offset(hb.x + hr.gate.x, hb.y + hr.gate.y);
        for (final e in [.04, .12, .22, .32, .4, .52, .7]) {
          final model = Offset.lerp(
            at,
            Offset(at.dx - 20, at.dy + 90),
            e / 1.1,
          )!;
          await frame(
            fly: (launchFrame(EmergeVariant.peek, hr.gate, e), model),
          );
        }
        rows.add(await _grid(seq, 12, gap: 2));
        for (final s in seq) {
          s.dispose();
        }
      }
      // stack the rows
      final maxW = rows.map((r) => r.width).reduce((a, c) => a > c ? a : c);
      final rec = ui.PictureRecorder();
      final c = ui.Canvas(rec);
      var y = 0.0;
      final total = rows.fold(0.0, (a, r) => a + r.height + 6);
      c.drawRect(
        Rect.fromLTWH(0, 0, maxW.toDouble(), total),
        Paint()..color = const Color(0xFF0C0A12),
      );
      for (final r in rows) {
        c.drawImage(r, Offset(0, y), Paint());
        y += r.height + 6;
      }
      final pic = rec.endRecording();
      final strips = await pic.toImage(maxW, total.round());
      pic.dispose();
      if (_contact) {
        await _save('art/contact/hatch-emergence-strips.png', strips);
      }
      strips.dispose();
      for (final r in rows) {
        r.dispose();
      }
      atlas.dispose();
    });
  });

  testWidgets('fight: one launch, real page frames', (tester) async {
    const size = Size(360, 640);
    final rig = await launch(tester, size, seed: 11);
    await tester.runAsync(() => loadReviewArt(rig));
    final m = rig.model, scene = rig.scene;
    await tester.runAsync(() async {
      scene.emergencePainter.image = await decodeReviewImage(
        'assets/images/hatch-emergence.png',
      );
    });
    final key = BossGrammar.baked[0][0];
    m.startAt(
      sector: 5,
      route: 0,
      wave: ArcadeModel.wavesFor(sector: 5, route: 0),
      runSeed: seedFor(0, 0),
    );
    scene.bossDirector.reset();
    final hull = BossHeroAtlas.hulls[key]!;
    final pages = await tester.runAsync(
      () async => [
        for (final p in hull.pages) await decodeReviewImage('assets/images/$p'),
      ],
    );
    scene.armada.setHero(0, hull, pages!);
    var n = 0;
    Future<ui.Image> grab(String label) async {
      await tester.pump();
      final boundary = tester.renderObject(
        find.byKey(const ValueKey('page')),
      ) as RenderRepaintBoundary;
      late ui.Image image;
      await tester.runAsync(() async {
        image = await boundary.toImage();
        await _save('$_dir/$label.png', image);
      });
      return image;
    }

    Future<void> step(double s, {bool kill = false}) async {
      for (var t = 0.0; t < s - 1e-9; t += 1 / 60) {
        m
          ..lives = 5
          ..invulnerable = 5;
        if (kill) {
          for (final d in List.of(m.demons)) {
            if (!d.entering) m.hitDemon(d, damage: 999);
          }
        }
        scene.advancePresentation(1 / 60);
        m.update(1 / 60);
        scene.creatures.update(m, 1 / 60);
        scene.onTick();
      }
    }

    for (var g = 0; g < 400 && !m.boss!.fightReady; g++) {
      await step(.25, kill: true);
    }
    expect(m.boss!.fightReady, isTrue);
    // Wait for a hatch to start its telegraph with a clear sky.
    var found = false;
    for (var g = 0; g < 60 * 30 && !found; g++) {
      await step(1 / 60, kill: true);
      found = m.launches!.runs.any(
        (r) => r.state == GateState.telegraph && r.t < .1,
      );
    }
    expect(found, isTrue);
    final frames = <ui.Image>[];
    for (var i = 0; i < 48; i++) {
      final img = await grab('fight/${(n++).toString().padLeft(3, '0')}');
      if (i % 6 == 0) {
        frames.add(img);
      } else {
        img.dispose();
      }
      await step(1 / 15);
    }
    expect(scene.emergence.started, greaterThan(0));
    // ignore: avoid_print
    print(
      'HATCH_EMERGENCE started=${scene.emergence.started} '
      'finished=${scene.emergence.finished}',
    );
    await tester.runAsync(() async {
      final sheet = await _grid(frames, 4);
      if (_contact) await _save('art/contact/hatch-emergence-fight.png', sheet);
      sheet.dispose();
    });
    for (final f in frames) {
      f.dispose();
    }
    for (final p in pages) {
      p.dispose();
    }
    await dispose(tester);
  });
}
