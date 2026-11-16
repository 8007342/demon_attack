@Tags(['review'])
library;

import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:demon_attack/game/arena_camera.dart';
import 'package:demon_attack/game/boss_atlas.dart';
import 'package:demon_attack/game/boss_director.dart';
import 'package:demon_attack/game/boss_grammar.dart';
import 'package:demon_attack/game/carrier_gates.dart';
import 'package:demon_attack/game/carrier_render_data.dart';
import 'package:demon_attack/game/model.dart';
import 'package:demon_attack/game/scene.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

import 'boss_carrier_wire_review_test.dart' show seedFor;
import 'fluid_transitions_test.dart' show Rig, dispose, launch;
import 'playtest_fixes_review_test.dart' show decodeReviewImage, loadReviewArt;

/// carrier-v3-render: the re-rendered carriers in real in-game frames, the
/// whole arcade page at 360 × 640, with each hull's baked data page loaded
/// (height grids, field distance, fracture chunks):
///
/// - `ingame`: tours 1 and 5 in the climb, then at S2 and S3;
/// - `bend`: the bend's extremes on tours 1 and 5 at phone size;
/// - `zoom5`: tour 5 at its 0.62 floor (no hull edge, no empty sky);
/// - `gates`: a prong gate and a tour-5 aft gate closed, opening, open.
///
/// With `--dart-define=CARRIER_V3_RENDER_CONTACT=true` the sheets go to
/// `art/contact/carrier-v3-render-<name>.png`.
const _contact = bool.fromEnvironment('CARRIER_V3_RENDER_CONTACT');
const _dir = '.cache/carrier-v3-render-review';
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
      final file = File('art/contact/carrier-v3-render-$name.png');
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

  Future<void> step(double seconds) async {
    for (var t = 0.0; t < seconds - 1e-9; t += 1 / 60) {
      m
        ..lives = 5
        ..invulnerable = 5;
      scene.advancePresentation(1 / 60);
      m.update(1 / 60);
      scene.creatures.update(m, 1 / 60);
      scene.onTick();
    }
    await tester.pump();
  }

  Future<ui.Image> grab(String label) async {
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
    return image;
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
    final data = hull.data!;
    final (pages, page) = (await tester.runAsync(
      () async => (
        [
          for (final p in hull.pages)
            await decodeReviewImage('assets/images/$p'),
        ],
        await decodeReviewImage('assets/images/${data.asset}'),
      ),
    ))!;
    final rd = await tester.runAsync(
      () => CarrierRenderData.decode(data, page),
    );
    page.dispose();
    scene.armada.setHero(route, hull, pages, data: rd);
    await tester.runAsync(() => scene.carrierV3.ensureField(scene.armada));
    for (var g = 0; g < 200 && !m.boss!.fightReady; g++) {
      await step(.25);
    }
    expect(m.boss!.fightReady, isTrue);
    return m.boss!;
  }
}

void main() {
  const deg = math.pi / 180;

  testWidgets('ingame: tours 1 and 5, intact, S2 and S3', (tester) async {
    final rig = await launch(tester, _size, seed: 11);
    await tester.runAsync(() => loadReviewArt(rig));
    final d = _Drive(tester, rig);
    final frames = <ui.Image>[];
    for (final route in [0, 4]) {
      final b = await d.fight(route);
      await d.step(10);
      frames.add(await d.grab('ingame-tour${route + 1}-s0'));
      b.shield = 0;
      await d.step(2);
      frames.add(await d.grab('ingame-tour${route + 1}-s2'));
      for (var g = 0; g < 4000 && d.dir.stage < 3 && d.m.boss != null; g++) {
        b.door = 1;
        d.m.hitBoss(b.x, damage: 20);
        await d.step(1 / 30);
      }
      await d.step(1);
      frames.add(await d.grab('ingame-tour${route + 1}-s3'));
    }
    await _sheet(tester, 'ingame', frames, columns: 3);
    await dispose(tester);
  });

  testWidgets('bend: the extremes on tours 1 and 5 at phone size', (
    tester,
  ) async {
    final rig = await launch(tester, _size, seed: 11);
    await tester.runAsync(() => loadReviewArt(rig));
    final d = _Drive(tester, rig);
    final frames = <ui.Image>[];
    for (final route in [0, 4]) {
      await d.fight(route);
      await d.step(10);
      for (final (name, pose) in [
        ('rest', (0.0, 0.0, 0.0)),
        ('lean-bank+', (3 * deg, 2.5 * deg, 2 * deg)),
        ('lean-bank-', (-3 * deg, -2.5 * deg, -2 * deg)),
      ]) {
        d.dir.bend.pose = pose;
        await d.step(1 / 60);
        final core = d.scene.armada.bent(0, 24.74);
        expect((core - const Offset(0, 24.74)).distance, lessThan(3));
        frames.add(await d.grab('bend-tour${route + 1}-$name'));
      }
      d.dir.bend.pose = null;
    }
    await _sheet(tester, 'bend', frames, columns: 3);
    await dispose(tester);
  });

  testWidgets('zoom5: tour 5 at 0.62, no hull edge and no empty sky', (
    tester,
  ) async {
    final rig = await launch(tester, _size, seed: 11);
    await tester.runAsync(() => loadReviewArt(rig));
    final d = _Drive(tester, rig);
    final frames = <ui.Image>[];
    await d.fight(4);
    await d.step(12);
    final floor = ArenaCamera.carrierMinZoomFor(4);
    for (final (name, pose) in [
      ('rest', (0.0, 0.0, 0.0)),
      ('lean+', (3 * deg, 2.5 * deg, 2 * deg)),
      ('lean-', (-3 * deg, -2.5 * deg, -2 * deg)),
    ]) {
      d.dir.camera.zoom = floor;
      d.dir.bend.pose = pose;
      await d.step(1 / 60);
      d.dir.camera.zoom = floor;
      frames.add(await d.grab('zoom5-$name'));
    }
    d.dir.bend.pose = null;
    await _sheet(tester, 'zoom5', frames, columns: 3, scale: 1);
    await dispose(tester);
  });

  testWidgets('gates: closed, opening, open (baked door states)', (
    tester,
  ) async {
    final rig = await launch(tester, _size, seed: 11);
    await tester.runAsync(() => loadReviewArt(rig));
    final d = _Drive(tester, rig);
    final frames = <ui.Image>[];
    await d.fight(4);
    await d.step(4);
    final l = d.m.launches!;
    final hull = d.scene.armada.hero!;
    for (final id in ['prongR', 'aftR', 'mawR']) {
      final r = l.runs.firstWhere((r) => r.gate.id == id);
      expect(hull.gates[id], isNotNull, reason: id);
      // Drive the gate's states directly (the volley's timing is the
      // model's); the art is what this sheet checks.
      for (final (st, t) in [
        (GateState.closed, 0.0),
        (GateState.opening, .25),
        (GateState.launching, 0.0),
      ]) {
        r
          ..state = st
          ..t = t;
        await d.step(1 / 60);
        r
          ..state = st
          ..t = t;
        frames.add(await d.grab('gate-$id-${st.name}'));
      }
    }
    await _sheet(tester, 'gates', frames, columns: 3);
    await dispose(tester);
  });
}
