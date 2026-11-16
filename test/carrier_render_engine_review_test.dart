@Tags(['review'])
library;

import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:demon_attack/game/boss_atlas.dart';
import 'package:demon_attack/game/boss_director.dart';
import 'package:demon_attack/game/boss_grammar.dart';
import 'package:demon_attack/game/model.dart';
import 'package:demon_attack/game/scene.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flame/components.dart' show Vector2;
import 'package:flame/game.dart' show GameWidget;
import 'package:flutter/services.dart' show ByteData;
import 'package:flutter_test/flutter_test.dart';

import 'boss_carrier_wire_review_test.dart' show seedFor;
import 'fluid_transitions_test.dart' show Rig, dispose, launch;
import 'playtest_fixes_review_test.dart' show decodeReviewImage, loadReviewArt;

/// carrier-render-engine: real in-game frames, the whole arcade page at
/// 360 × 640.
///
/// - `bend`: rest and the limits (held poses), one composed mesh;
/// - `collapse`: the cohesive breakup, 0 → 6.5 s;
/// - `field`: full → 75 % → 50 % → 25 % → 8 % → down (it thins in place);
/// - GIF frames of the collapse and of a lean/bank sweep go to
///   `.cache/carrier-render-engine-review/{collapse,sweep}/` (the strip is
///   packed by `tools/gifstrip`).
///
/// With `--dart-define=CARRIER_RENDER_CONTACT=true` the sheets go to
/// `art/contact/carrier-render-engine-<name>.png`.
const _contact = bool.fromEnvironment('CARRIER_RENDER_CONTACT');
const _dir = '.cache/carrier-render-engine-review';
const _size = Size(360, 640);

Future<void> _sheet(
  WidgetTester tester,
  String name,
  List<ui.Image> frames, {
  int? columns,
  double scale = .5,
}) async {
  if (_contact && frames.isNotEmpty) {
    await tester.runAsync(() async {
      const gap = 4.0;
      final cols = columns ?? frames.length;
      final rows = (frames.length / cols).ceil();
      final fw = _size.width * scale, fh = _size.height * scale;
      final sw = gap + cols * (fw + gap), sh = gap + rows * (fh + gap);
      final rec = ui.PictureRecorder();
      final c = ui.Canvas(rec);
      c.drawRect(
        Rect.fromLTWH(0, 0, sw, sh),
        Paint()..color = const Color(0xFF101018),
      );
      for (final (i, f) in frames.indexed) {
        final x = gap + (i % cols) * (fw + gap);
        final y = gap + (i ~/ cols) * (fh + gap);
        c.drawImageRect(
          f,
          Rect.fromLTWH(0, 0, f.width.toDouble(), f.height.toDouble()),
          Rect.fromLTWH(x, y, fw, fh),
          Paint()..filterQuality = FilterQuality.medium,
        );
      }
      final img = await rec.endRecording().toImage(sw.round(), sh.round());
      final png = await img.toByteData(format: ui.ImageByteFormat.png);
      img.dispose();
      final file = File('art/contact/carrier-render-engine-$name.png');
      await file.parent.create(recursive: true);
      await file.writeAsBytes(png!.buffer.asUint8List());
    });
  }
  for (final f in frames) {
    f.dispose();
  }
}

class _Drive {
  _Drive(this.tester, this.rig);
  final WidgetTester tester;
  final Rig rig;
  ArcadeModel get m => rig.model;
  DemonScene get scene => rig.scene;
  BossDirector get dir => scene.bossDirector;

  Future<void> step(double seconds, {bool kill = false}) async {
    for (var t = 0.0; t < seconds - 1e-9; t += 1 / 60) {
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
    await tester.pump();
  }

  /// One frame: kept as an image for a sheet when [keep], always written
  /// to `$_dir/<label>.png`.
  Future<ui.Image?> grab(String label, {bool keep = true}) async {
    final protection = m.invulnerable;
    m.invulnerable = 0;
    await tester.pump();
    final boundary = tester.renderObject(
      find.byKey(const ValueKey('page')),
    ) as RenderRepaintBoundary;
    late ui.Image image;
    await tester.runAsync(() async {
      image = await boundary.toImage();
      final png = await image.toByteData(format: ui.ImageByteFormat.png);
      final file = File('$_dir/$label.png');
      await file.parent.create(recursive: true);
      await file.writeAsBytes(png!.buffer.asUint8List());
    });
    m.invulnerable = protection;
    if (keep) return image;
    image.dispose();
    return null;
  }

  Future<Carrier> fight(int route, {int set = 0}) async {
    final key = BossGrammar.baked[route][set];
    m.startAt(
      sector: 5,
      route: route,
      wave: ArcadeModel.wavesFor(sector: 5, route: route),
      runSeed: seedFor(route, set),
    );
    dir.reset();
    final hull = BossHeroAtlas.hulls[key]!;
    final pages = await tester.runAsync(
      () async => [
        for (final p in hull.pages) await decodeReviewImage('assets/images/$p'),
      ],
    );
    scene.armada.setHero(route, hull, pages!);
    await tester.runAsync(() => scene.carrierV3.ensureField(scene.armada));
    expect(scene.carrierV3.field.map, isNotNull);
    for (var g = 0; g < 200 && !m.boss!.fightReady; g++) {
      await step(.25);
    }
    expect(m.boss!.fightReady, isTrue);
    return m.boss!;
  }
}

/// The straight-edge pixel test (coordinator's blocker, 2026-11-16): an
/// offscreen layer, a tint or a composite drawn with its bounds visible
/// shows as a long straight luminance step. The arena is painted alone at
/// 1 px per unit; along the four sides of every recorded layer and
/// composite (and of the zoomed arena rect, where the hit-beat flash once
/// drew a box) the mean signed step across the side must stay small
/// against the local texture, and no whole column or row of the arena may
/// carry one.
class _Edges {
  _Edges(this.d);
  final _Drive d;
  final faults = <String>[];
  int checked = 0;

  Future<void> check(String label) async {
    final scene = d.scene, armada = scene.armada;
    armada
      ..recordLayers = true
      ..beginFrame();
    // The arena exactly as the page paints it (`_ArenaView`: the widget's
    // size, bottom-aligned, the headroom band above it included).
    final size = d.tester.getSize(
      find.byWidgetPredicate((x) => x is GameWidget && x.game is! DemonScene),
    );
    final w = size.width.round(), h = size.height.round();
    final rec = ui.PictureRecorder();
    scene.paintArena(ui.Canvas(rec), Vector2(w * 1.0, h * 1.0), alignY: 1);
    final pic = rec.endRecording();
    late ui.Image img;
    late ByteData bytes;
    await d.tester.runAsync(() async {
      img = await pic.toImage(w, h);
      bytes = (await img.toByteData(format: ui.ImageByteFormat.rawRgba))!;
    });
    pic.dispose();
    img.dispose();
    armada.recordLayers = false;
    final k = math.min(w / 360, h / 520);
    final ox = (w - 360 * k) / 2, oy = h - 520 * k;
    Rect toCanvas(Rect r) => Rect.fromLTRB(
      ox + r.left * k,
      oy + r.top * k,
      ox + r.right * k,
      oy + r.bottom * k,
    );
    double lum(int x, int y) {
      final o = (y.clamp(0, h - 1) * w + x.clamp(0, w - 1)) * 4;
      return .299 * bytes.getUint8(o) +
          .587 * bytes.getUint8(o + 1) +
          .114 * bytes.getUint8(o + 2);
    }

    final cam = d.dir.camera;
    final rects = [
      ...armada.layerBounds,
      toCanvas(
        Rect.fromPoints(
          cam.toScreen(Offset.zero),
          cam.toScreen(const Offset(360, 520)),
        ),
      ),
      // The arena itself: its top is the headroom band's edge.
      toCanvas(const Rect.fromLTWH(0, 0, 360, 520)),
    ];
    // Across a side at [p] (vertical: x = p, along y in [a, b]): the mean
    // step and its spread. A layer's or a tint's edge shifts the colour
    // alike all along it (spread below the mean); an edge in the art
    // (a bone, a spine) varies from row to row.
    var spread = 0.0;
    double step(bool vertical, int p, int a, int b, int out, int inn) {
      var s = 0.0, s2 = 0.0, n = 0;
      for (var q = a; q < b; q++) {
        final v = vertical
            ? lum(p + inn, q) - lum(p + out, q)
            : lum(q, p + inn) - lum(q, p + out);
        s += v;
        s2 += v * v;
        n++;
      }
      if (n == 0) return 0;
      final m = s / n;
      spread = math.sqrt(math.max(0.0, s2 / n - m * m));
      return m;
    }

    for (final r in rects) {
      final sides = [
        (true, r.left.round(), r.top, r.bottom, -2, 2),
        (true, r.right.round(), r.top, r.bottom, 2, -2),
        (false, r.top.round(), r.left, r.right, -2, 2),
        (false, r.bottom.round(), r.left, r.right, 2, -2),
      ];
      for (final (vertical, p, lo, hi, out, inn) in sides) {
        final lim = vertical ? w : h;
        if (p < 4 || p > lim - 5) continue; // off the arena: never seen
        final a = math.max(2, lo.round()),
            b = math.min((vertical ? h : w) - 2, hi.round());
        if (b - a < 40) continue;
        final edge = step(vertical, p, a, b, out, inn);
        final uniform = spread < edge.abs();
        final base = step(vertical, p, a, b, inn * 2, inn * 4);
        checked++;
        if (edge.abs() > 6 && edge.abs() > 2 * base.abs() + 2 && uniform) {
          faults.add(
            '$label: ${vertical ? 'x' : 'y'} = $p over $a..$b '
            'step ${edge.toStringAsFixed(1)} (texture ${base.toStringAsFixed(1)})',
          );
        }
      }
    }
    // Any column or row with a long one-sided step: a layer whose bounds
    // were not recorded. A thin line (a beam, a shot stream) steps up and
    // back down within a few pixels; a layer edge does not.
    final cols = <double>[], rows = <double>[];
    final colU = <bool>[], rowU = <bool>[];
    for (var x = 0; x < w - 1; x++) {
      cols.add(step(true, x, 0, h, 0, 1));
      colU.add(spread < cols.last.abs());
    }
    for (var y = 0; y < h - 1; y++) {
      rows.add(step(false, y, 0, w, 0, 1));
      rowU.add(spread < rows.last.abs());
    }
    void scan(List<double> s, List<bool> u, String what) {
      for (var i = 4; i < s.length - 4; i++) {
        if (s[i].abs() <= 14 || !u[i]) continue;
        var paired = false;
        for (var k = -24; k <= 24 && !paired; k++) {
          final j = i + k;
          if (k == 0 || j < 0 || j >= s.length) continue;
          paired = s[j].sign != s[i].sign && s[j].abs() > s[i].abs() * .4;
        }
        if (!paired) {
          faults.add('$label: $what $i step ${s[i].toStringAsFixed(1)}');
        }
      }
    }

    scan(cols, colU, 'column');
    scan(rows, rowU, 'row');
    if (faults.length > reported) {
      reported = faults.length;
      await d.tester.runAsync(() async {
        final rec2 = ui.PictureRecorder();
        d.scene.paintArena(
          ui.Canvas(rec2),
          Vector2(w * 1.0, h * 1.0),
          alignY: 1,
        );
        final pic2 = rec2.endRecording();
        final im = await pic2.toImage(w, h);
        final png = await im.toByteData(format: ui.ImageByteFormat.png);
        im.dispose();
        pic2.dispose();
        final f = File('$_dir/edges/arena-$label.png');
        await f.parent.create(recursive: true);
        await f.writeAsBytes(png!.buffer.asUint8List());
      });
    }
  }

  int reported = 0;
}

void main() {
  const deg = math.pi / 180;

  testWidgets('bend: rest and the limits, one composed mesh', (tester) async {
    final rig = await launch(tester, _size, seed: 11);
    await tester.runAsync(() => loadReviewArt(rig));
    final d = _Drive(tester, rig);
    await d.fight(0);
    await d.step(10);
    final frames = <ui.Image>[];
    for (final (name, pose) in [
      ('rest', (0.0, 0.0, 0.0)),
      ('lean+', (3 * deg, 0.0, 0.0)),
      ('lean-', (-3 * deg, 0.0, 0.0)),
      ('bank+', (0.0, 2.5 * deg, 0.0)),
      ('bank-', (0.0, -2.5 * deg, 0.0)),
      ('pitch+', (0.0, 0.0, 3 * deg)),
      ('pitch-', (0.0, 0.0, -2 * deg)),
      ('all', (3 * deg, 2.5 * deg, 2 * deg)),
    ]) {
      d.dir.bend.pose = pose;
      await d.step(1 / 60);
      final core = d.scene.armada.bent(0, 24.74);
      expect((core - const Offset(0, 24.74)).distance, lessThan(3));
      frames.add((await d.grab('bend-$name'))!);
    }
    final a = d.scene.armada;
    // One painted frame alone: one drawVertices per pass.
    a.beginFrame();
    await tester.pump();
    expect(a.meshCalls, 2, reason: 'one drawVertices per pass');
    // ignore: avoid_print
    print(
      'CARRIER_RENDER_MESH vertices=${a.meshVertices} '
      'triangles=${a.meshTriangles} calls=${a.meshCalls} '
      'composites=${a.composites} bytes=${a.compositeBytes} '
      'sizes=${a.compositeSizes}',
    );
    // The sweep: lean and bank through their range, 4 s, 24 frames.
    for (var i = 0; i < 24; i++) {
      final u = math.sin(i / 24 * 2 * math.pi);
      final v = math.sin(i / 24 * 2 * math.pi + 1.1);
      d.dir.bend.pose = (3 * deg * u, 2.5 * deg * v, 1.5 * deg * v);
      await d.step(1 / 60);
      await d.grab('sweep/${i.toString().padLeft(2, '0')}', keep: false);
    }
    d.dir.bend.pose = null;
    await _sheet(tester, 'bend', frames, columns: 4);
    await dispose(tester);
  });

  testWidgets('collapse: one structure breaking up and sinking', (
    tester,
  ) async {
    final rig = await launch(tester, _size, seed: 11);
    await tester.runAsync(() => loadReviewArt(rig));
    final d = _Drive(tester, rig);
    final b = await d.fight(0);
    await d.step(6);
    b.shield = 0;
    for (var g = 0; g < 4000 && d.m.boss != null; g++) {
      b.door = 1;
      d.m.hitBoss(b.x, damage: 50);
      await d.step(1 / 60);
    }
    expect(d.m.boss, isNull);
    final frames = <ui.Image>[];
    const marks = [.1, .7, 1.4, 2.0, 2.8, 3.8, 5.0, 6.3];
    var t = 0.0;
    var gif = 0;
    for (final mark in marks) {
      // GIF frames every 1/8 s up to the mark.
      while (t + 1 / 8 <= mark + 1e-9) {
        await d.step(1 / 8);
        t += 1 / 8;
        await d.grab(
          'collapse/${(gif++).toString().padLeft(2, '0')}',
          keep: false,
        );
      }
      if (mark > t) {
        await d.step(mark - t);
        t = mark;
      }
      final k = d.dir.collapse;
      expect(k, isNotNull);
      expect(d.dir.phase, BossPhase.collapse);
      frames.add((await d.grab('collapse-${mark.toStringAsFixed(1)}'))!);
    }
    final a = d.scene.armada;
    // ignore: avoid_print
    print(
      'CARRIER_RENDER_WRECK triangles=${a.wreckTriangles} '
      'chunks=${a.wreckFracture?.chunks} bodies=${d.dir.collapse?.bodies.length} '
      'puffs=${d.dir.collapse?.puffs.length}',
    );
    await _sheet(tester, 'collapse', frames, columns: 4);
    await dispose(tester);
  });

  testWidgets('field: it thins in place', (tester) async {
    final rig = await launch(tester, _size, seed: 11);
    await tester.runAsync(() => loadReviewArt(rig));
    final d = _Drive(tester, rig);
    final b = await d.fight(0);
    await d.step(6);
    final frames = <ui.Image>[];
    for (final (name, s) in [
      ('100', 1.0),
      ('75', .75),
      ('50', .5),
      ('25', .25),
      ('8', .08),
    ]) {
      for (var g = 0; g < 400 && b.shield > (b.shieldMax * s).ceil(); g++) {
        d.m.hitBoss(b.x + 60 * math.sin(g * 1.3));
        await d.step(1 / 30);
      }
      await d.step(.5);
      frames.add((await d.grab('field-$name'))!);
    }
    for (var g = 0; g < 400 && b.shield > 0; g++) {
      d.m.hitBoss(b.x);
      await d.step(1 / 30);
    }
    await d.step(.1);
    frames.add((await d.grab('field-down'))!);
    await _sheet(tester, 'field', frames, columns: 6);
    await dispose(tester);
  });
  testWidgets('no straight layer edge: take-off, re-composes, collapse '
      '(360 × 780)', (tester) async {
    final rig = await launch(tester, const Size(360, 780), seed: 11);
    await tester.runAsync(() => loadReviewArt(rig));
    final d = _Drive(tester, rig);
    final e = _Edges(d);
    final b = await d.fight(0);
    // The take-off's first frames (the director's phase follows the model
    // by one presentation step).
    for (var g = 0; g < 30 && d.dir.phase != BossPhase.takeoff; g++) {
      await d.step(1 / 60);
    }
    expect(d.dir.phase, BossPhase.takeoff);
    expect(d.dir.phaseTime, lessThan(.2));
    for (var i = 0; i < 3; i++) {
      await d.step(1 / 60);
      await e.check('takeoff-$i');
      await d.grab('edges/takeoff-$i', keep: false);
    }
    await d.step(4);
    // The frame after every re-compose (each damage step).
    var seen = d.scene.armada.composites;
    var steps = 0;
    for (var g = 0; g < 6000 && d.m.boss != null && steps < 8; g++) {
      if (b.shield > 0) {
        d.m.hitBoss(b.x + 40 * math.sin(g * .7));
      } else {
        b.door = 1;
        if (g % 6 == 0) d.m.hitBoss(b.x, damage: 4);
      }
      await d.step(1 / 60);
      final now = d.scene.armada.composites;
      if (now != seen) {
        seen = now;
        steps++;
        await e.check('recompose-$steps');
        await d.grab('edges/recompose-$steps', keep: false);
      }
    }
    expect(steps, greaterThanOrEqualTo(2), reason: 'damage steps re-compose');
    // The killing blow and the whole collapse, every 0.25 s.
    for (var g = 0; g < 4000 && d.m.boss != null; g++) {
      b
        ..shield = 0
        ..door = 1;
      d.m.hitBoss(b.x, damage: 50);
      await d.step(1 / 60);
    }
    for (var i = 0; i < 28; i++) {
      final t = (i * .25).toStringAsFixed(2);
      await e.check('collapse-$t');
      // The wreck is on screen from the killing blow's own frame: the ship
      // never blinks out.
      expect(d.scene.armada.wreckTriangles, greaterThan(0), reason: t);
      if (i % 4 == 0) await d.grab('edges/collapse-$t', keep: false);
      await d.step(.25);
    }
    // ignore: avoid_print
    print('CARRIER_EDGES checked=${e.checked} faults=${e.faults.length}');
    expect(e.checked, greaterThan(50));
    expect(e.faults, isEmpty, reason: e.faults.take(12).join('\n'));
    await dispose(tester);
  });
}
