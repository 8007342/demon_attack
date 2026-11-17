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
import 'package:demon_attack/game/model.dart';
import 'package:demon_attack/game/scene.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

import 'boss_carrier_wire_review_test.dart' show seedFor;
import 'fluid_transitions_test.dart' show Rig, dispose, launch;
import 'playtest_fixes_review_test.dart' show decodeReviewImage, loadReviewArt;

/// carrier-v3 (runtime on today's art): real in-game frames, the whole
/// arcade page at 360 × 640.
///
/// - `intro`: approach far → nearer → close-in → hittable → take-off → climb;
/// - `bend`: lean ±, bank ±, pitch ± at the limits (held poses);
/// - `field`: full, half drained, failing;
/// - `gate`: a fight gate's telegraph, opening, ejection and closing;
/// - `zoom`: tour 1 at 0.70 against tour 5 at 0.62.
///
/// With `--dart-define=CARRIER_V3_CONTACT=true` the sheets go to
/// `art/contact/carrier-v3-runtime-<name>.png`; frames to
/// `.cache/carrier-v3-runtime-review`.
const _contact = bool.fromEnvironment('CARRIER_V3_CONTACT');
const _dir = '.cache/carrier-v3-runtime-review';
const _size = Size(360, 640);

Future<void> _hero(WidgetTester tester, DemonScene scene, String key, int cls) async {
  final hull = BossHeroAtlas.hulls[key]!;
  final pages = await tester.runAsync(() async => [
        for (final p in hull.pages) await decodeReviewImage('assets/images/$p'),
      ]);
  scene.armada.setHero(cls, hull, pages!);
  await tester.runAsync(() => scene.carrierV3.ensureField(scene.armada));
  expect(scene.carrierV3.field.map, isNotNull, reason: 'distance map for $key');
}

Future<void> _sheet(WidgetTester tester, String name, List<ui.Image> frames,
    {int? columns, double scale = .5}) async {
  if (_contact && frames.isNotEmpty) {
    await tester.runAsync(() async {
      const gap = 4.0;
      final cols = columns ?? frames.length;
      final rows = (frames.length / cols).ceil();
      final fw = _size.width * scale, fh = _size.height * scale;
      final sw = gap + cols * (fw + gap), sh = gap + rows * (fh + gap);
      final rec = ui.PictureRecorder();
      final c = ui.Canvas(rec);
      c.drawRect(Rect.fromLTWH(0, 0, sw, sh), Paint()..color = const Color(0xFF101018));
      for (final (i, f) in frames.indexed) {
        final x = gap + (i % cols) * (fw + gap), y = gap + (i ~/ cols) * (fh + gap);
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
      final file = File('art/contact/carrier-v3-runtime-$name.png');
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

  Future<ui.Image> grab(String label) async {
    final protection = m.invulnerable;
    m.invulnerable = 0;
    await tester.pump();
    final boundary = tester.renderObject(find.byKey(const ValueKey('page')))
        as RenderRepaintBoundary;
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

  /// Starts tour [route]'s boss level with combination [set] at [wave].
  Future<void> begin(int route, int set, {int wave = 1}) async {
    final key = BossGrammar.baked[route][set];
    m.startAt(sector: 5, route: route, wave: wave, runSeed: seedFor(route, set));
    scene.bossDirector.reset();
    await _hero(tester, scene, key, route);
  }

  Future<Carrier> fight(int route, {int set = 0}) async {
    await begin(route, set, wave: ArcadeModel.wavesFor(sector: 5, route: route));
    for (var g = 0; g < 200 && !m.boss!.fightReady; g++) {
      await step(.25);
    }
    expect(m.boss!.fightReady, isTrue);
    return m.boss!;
  }
}

void main() {
  testWidgets('intro: approach, close-in, hittable, take-off, climb', (tester) async {
    final rig = await launch(tester, _size, seed: 11);
    await tester.runAsync(() => loadReviewArt(rig));
    final d = _Drive(tester, rig);
    final frames = <ui.Image>[];
    await d.begin(0, 0);
    for (var g = 0; g < 400 && !(d.m.combat && d.m.approachD > 0); g++) {
      await d.step(.1);
    }
    await d.step(5); // the first volley out of the gates
    expect(d.dir.phase, BossPhase.approach);
    frames.add(await d.grab('intro-0-far'));
    // Wave 1 cleared: D steps to 2.4.
    final w = d.m.wave;
    for (var g = 0; g < 600 && d.m.wave == w && d.m.boss == null; g++) {
      await d.step(1 / 6, kill: true);
    }
    await d.step(3.5);
    frames.add(await d.grab('intro-1-nearer'));
    for (var g = 0; g < 600 && d.m.boss == null; g++) {
      await d.step(1 / 6, kill: true);
    }
    expect(d.dir.phase, BossPhase.close);
    await d.step(2);
    frames.add(await d.grab('intro-2-close-in'));
    for (var g = 0; g < 300 && !d.m.boss!.fightReady; g++) {
      await d.step(1 / 30);
    }
    frames.add(await d.grab('intro-3-hittable'));
    await d.step(.8);
    expect(d.dir.phase, BossPhase.takeoff);
    frames.add(await d.grab('intro-4-takeoff'));
    await d.step(4);
    expect(d.dir.phase, BossPhase.climb);
    frames.add(await d.grab('intro-5-climb'));
    await _sheet(tester, 'intro', frames, columns: 6);
    await dispose(tester);
  });

  testWidgets('bend extremes: lean, bank, pitch', (tester) async {
    final rig = await launch(tester, _size, seed: 11);
    await tester.runAsync(() => loadReviewArt(rig));
    final d = _Drive(tester, rig);
    await d.fight(0);
    await d.step(10);
    const deg = math.pi / 180;
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
      final b = d.m.boss!;
      // The hit windows stay on the deck.
      final core = d.scene.armada.bent(0, 24.74);
      expect((core - const Offset(0, 24.74)).distance, lessThan(3));
      expect(b.fightReady, isTrue);
      frames.add(await d.grab('bend-$name'));
    }
    d.dir.bend.pose = null;
    expect(d.scene.armada.meshCalls, greaterThan(0));
    // ignore: avoid_print
    print('CARRIER_MESH_DRAWN vertices=${d.scene.armada.meshVertices} '
        'triangles=${d.scene.armada.meshTriangles} calls=${d.scene.armada.meshCalls}');
    await _sheet(tester, 'bend', frames, columns: 4);
    await dispose(tester);
  });

  testWidgets('field: full, half drained, failing', (tester) async {
    final rig = await launch(tester, _size, seed: 11);
    await tester.runAsync(() => loadReviewArt(rig));
    final d = _Drive(tester, rig);
    final b = await d.fight(0);
    await d.step(6);
    final frames = <ui.Image>[];
    frames.add(await d.grab('field-full'));
    for (var g = 0; g < 400 && b.shield * 2 > b.shieldMax; g++) {
      d.m.hitBoss(b.x + 60 * math.sin(g * 1.3));
      await d.step(1 / 30);
    }
    await d.step(.1);
    frames.add(await d.grab('field-half'));
    for (var g = 0; g < 400 && b.shield * 5 > b.shieldMax; g++) {
      d.m.hitBoss(b.x + 60 * math.sin(g * 1.3));
      await d.step(1 / 30);
    }
    d.m.hitBoss(b.x - 30);
    await d.step(1 / 30);
    frames.add(await d.grab('field-failing'));
    // ignore: avoid_print
    print('CARRIER_FIELD_SEGMENTS ${d.scene.carrierV3.field.drawnSegments}');
    await _sheet(tester, 'field', frames, columns: 3);
    await dispose(tester);
  });

  testWidgets('gate: telegraph, open, eject, close', (tester) async {
    final rig = await launch(tester, _size, seed: 11);
    await tester.runAsync(() => loadReviewArt(rig));
    final d = _Drive(tester, rig);
    await d.fight(0);
    final frames = <ui.Image>[];
    final seen = <GateState>{};
    for (var g = 0; g < 60 * 40 && seen.length < 4; g++) {
      // The flock timer spawns only under the cap: clear the minions.
      await d.step(1 / 60, kill: g % 30 == 0);
      final runs = d.m.launches?.runs ?? const <GateRun>[];
      for (final r in runs) {
        final s = r.state;
        if (s == GateState.closed || seen.contains(s)) continue;
        final ok = switch (s) {
          GateState.telegraph => r.t > .8,
          GateState.opening => r.t > .3,
          GateState.launching => true,
          GateState.closing => r.t > .2,
          GateState.closed => false,
        };
        if (!ok) continue;
        seen.add(s);
        frames.add(await d.grab('gate-${s.name}-${r.gate.id}'));
        break;
      }
    }
    expect(seen.length, 4);
    await _sheet(tester, 'gate', frames, columns: 4);
    await dispose(tester);
  });

  testWidgets('zoom: tour 1 at 0.70 against tour 5 at 0.62 (360 × 640)', (tester) async {
    final rig = await launch(tester, _size, seed: 11);
    await tester.runAsync(() => loadReviewArt(rig));
    final d = _Drive(tester, rig);
    final frames = <ui.Image>[];
    for (final route in [0, 4]) {
      await d.fight(route);
      await d.step(12);
      final floor = ArenaCamera.carrierMinZoomFor(route);
      expect(d.dir.camera.carrierFloor, floor);
      d.dir.camera.zoom = floor;
      frames.add(await d.grab('zoom-tour${route + 1}'));
    }
    await _sheet(tester, 'zoom', frames, columns: 2, scale: 1);
    await dispose(tester);
  });
}
