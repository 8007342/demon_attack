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
}
