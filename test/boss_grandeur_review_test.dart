@Tags(['review'])
library;

import 'dart:io';
import 'dart:ui' as ui;

import 'package:demon_attack/game/arena_camera.dart';
import 'package:demon_attack/game/boss_atlas.dart';
import 'package:demon_attack/game/boss_director.dart';
import 'package:demon_attack/game/boss_painter.dart';
import 'package:demon_attack/game/model.dart';
import 'package:demon_attack/game/scene.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fluid_transitions_test.dart' show Rig, dispose, launch;
import 'playtest_fixes_review_test.dart' show decodeReviewImage, loadReviewArt;

/// boss-grandeur task 5.1: review strips of the boss level as the operator
/// sees it (whole arcade page), with the frigate's packed view set:
///
/// - `overflight`: the carrier flies in from behind the ship and sinks into
///   the far fog (the boss arrival's Descent), 8 frames;
/// - `loom`: the loom wave is fought while the carrier looms under the fog
///   and rises through its layers, 6 frames;
/// - `rise`: it comes out of the fog to its fight row, 6 frames;
/// - `climb`: the fight climbs (ground recedes), the camera zooms out and
///   follows the glide and the swerve, 6 frames;
/// - `views`: the 3 × 3 view set in place (pitch 38/45/52 × yaw −12/0/+12);
/// - `stages`: S0 shielded, S1 scorched, S2 exposed (plates falling), S3 a
///   module broken away (list), S4 the collapse into module wrecks;
/// - `reduced`: the same climb under reduced motion (static framing);
/// - `phone`: four key frames at 1:1 phone scale (360 × 780);
/// - `wide`: the climb at 1280 × 720.
///
/// Frames go to `$BOSS_GRANDEUR_REVIEW_DIR` (default
/// .cache/boss-grandeur-review); with
/// `--dart-define=BOSS_GRANDEUR_CONTACT=true` the strips are written to
/// `art/contact/boss-grandeur-<name>.png`.
const _dir = String.fromEnvironment(
  'BOSS_GRANDEUR_REVIEW_DIR',
  defaultValue: '.cache/boss-grandeur-review',
);
const _contact = bool.fromEnvironment('BOSS_GRANDEUR_CONTACT');

Future<void> _hero(WidgetTester tester, DemonScene scene) async {
  // boss-carrier-wire: the frigate placeholder is retired; the tour-1
  // carrier an unseeded run draws (thorn) stands in.
  final hull = BossHeroAtlas.hulls['carrier1-thorn']!;
  final belly = BossPainter.bellyOf(hull);
  final imgs = await tester.runAsync(() async => [
        for (final p in hull.pages) await decodeReviewImage('assets/images/$p'),
        if (belly != null) await decodeReviewImage('assets/images/${belly.asset}'),
      ]);
  scene.armada.setHero(0, hull, imgs!.sublist(0, hull.pages.length),
      belly: belly == null ? null : imgs.last);
}

Future<void> _sheet(
  WidgetTester tester,
  String name,
  List<ui.Image> frames,
  Size size, {
  double scale = .5,
  int? columns,
}) async {
  if (!_contact || frames.isEmpty) return;
  await tester.runAsync(() async {
    const gap = 4.0;
    final cols = columns ?? frames.length;
    final rows = (frames.length / cols).ceil();
    final fw = size.width * scale, fh = size.height * scale;
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
    final file = File('art/contact/boss-grandeur-$name.png');
    await file.parent.create(recursive: true);
    await file.writeAsBytes(png!.buffer.asUint8List());
  });
}

class _Drive {
  _Drive(this.tester, this.rig);
  final WidgetTester tester;
  final Rig rig;
  ArcadeModel get m => rig.model;
  DemonScene get scene => rig.scene;
  final named = <String>[];

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

  /// Fights a little: kills the first settled creature every [every] s.
  Future<void> fight(double seconds, {double every = .5}) async {
    var cool = 0.0;
    for (var t = 0.0; t < seconds && m.combat; t += .1) {
      cool -= .1;
      if (cool <= 0) {
        final d = m.demons
            .where((d) => !d.entering && d.swarmState != SwarmState.reserve)
            .firstOrNull;
        if (d != null) {
          for (var guard = 0; guard < 1000 && m.demons.contains(d); guard++) {
            m.hitDemon(d);
          }
          cool = every;
        }
      }
      await step(.1);
    }
  }

  Future<ui.Image> grab(String label) async {
    // The ship is drawn steady (its protection blink is off for the grab).
    final protection = m.invulnerable;
    m.invulnerable = 0;
    await tester.pump();
    final boundary = tester.renderObject(find.byKey(const ValueKey('page')))
        as RenderRepaintBoundary;
    late ui.Image image;
    await tester.runAsync(() async {
      image = await boundary.toImage();
      named.add(label);
      final png = await image.toByteData(format: ui.ImageByteFormat.png);
      final file = File('$_dir/$label.png');
      await file.parent.create(recursive: true);
      await file.writeAsBytes(png!.buffer.asUint8List());
    });
    m.invulnerable = protection;
    return image;
  }
}

void main() {
  testWidgets('boss grandeur review strips', (tester) async {
    const size = Size(360, 780);
    final rig = await launch(tester, size, seed: 11);
    await tester.runAsync(() => loadReviewArt(rig));
    await _hero(tester, rig.scene);
    final d = _Drive(tester, rig);
    final m = rig.model;
    final scene = rig.scene;
    final dir = scene.bossDirector;
    final phone = <ui.Image>[];

    // --- the overflight: sector 4's last kill, then the boss arrival.
    m.startAt(sector: 4, route: 0, wave: ArcadeModel.wavesFor(sector: 4, route: 0));
    scene.environment = 3;
    await d.step(4.6);
    m.endSector();
    while (!(m.flow.active && m.flow.seconds >= m.flow.plan.descentAt)) {
      await d.step(.1);
    }
    expect(m.flow.kind.name, 'bossArrival');
    final over = <ui.Image>[];
    for (var i = 0; i < 8; i++) {
      while (dir.overflight < (i + .5) / 8 && dir.phase == BossPhase.overflight) {
        await d.step(1 / 30);
      }
      over.add(await d.grab('overflight-$i'));
    }
    expect(dir.overflight, greaterThan(.8));
    phone.add(over[2]);
    await _sheet(tester, 'overflight', over, size, columns: 4);

    // --- the loom: the ordinary wave while the carrier looms.
    while (!m.combat) {
      await d.step(.2);
    }
    expect(m.looming, isTrue);
    final loom = <ui.Image>[];
    for (var i = 0; i < 6; i++) {
      await d.fight(5, every: 2.6);
      if (m.boss != null) break;
      loom.add(await d.grab('loom-$i'));
    }
    expect(dir.phase, anyOf(BossPhase.approach, BossPhase.close));
    if (loom.length > 2) phone.add(loom[2]);
    await _sheet(tester, 'loom', loom, size, columns: loom.length);

    // --- the rise.
    while (m.boss == null) {
      await d.fight(.5, every: .1);
    }
    final rise = <ui.Image>[];
    for (var i = 0; i < 6; i++) {
      rise.add(await d.grab('rise-$i'));
      await d.step(Carrier.riseSeconds / 6);
    }
    await _sheet(tester, 'rise', rise, size, columns: 6);

    // --- the climb, zoom and follow.
    final climb = <ui.Image>[];
    for (var i = 0; i < 6; i++) {
      await d.step(2);
      climb.add(await d.grab('climb-$i'));
    }
    expect(dir.altitude, greaterThan(1.3));
    expect(dir.camera.zoom, lessThan(1));
    phone.add(climb[4]);
    await _sheet(tester, 'climb', climb, size, columns: 6);

    // --- the view set in place (the director's choice overridden).
    final views = <ui.Image>[];
    for (final p in [0, 1, 2]) {
      for (final y in [-1, 0, 1]) {
        dir
          ..view = BossView(p, y)
          ..previous = BossView(p, y)
          ..blend = 1;
        views.add(await d.grab('view-p${BossView.pitches[p]}-y${12 * y}'));
      }
    }
    await _sheet(tester, 'views', views, size, columns: 3);

    // --- the damage stages and the collapse, on a fresh carrier.
    m.startAt(sector: 5, route: 0);
    dir.reset();
    await d.step(4.7);
    final stages = <ui.Image>[];
    final b = m.boss!;
    b
      ..shield = b.shieldMax
      ..core = b.coreMax;
    await d.step(.2);
    stages.add(await d.grab('stage-S0'));
    b.shield = b.shieldMax ~/ 2;
    await d.step(.6);
    stages.add(await d.grab('stage-S1'));
    b.shield = 0;
    await d.step(3);
    stages.add(await d.grab('stage-S2'));
    b.core = b.coreMax ~/ 2 - 1;
    await d.step(1.2);
    expect(dir.stage, 3);
    stages.add(await d.grab('stage-S3'));
    b
      ..core = 1
      ..door = 1;
    m.hitBoss(b.x);
    expect(m.mode, RunMode.victory);
    for (var i = 0; i < 4; i++) {
      await d.step(.9);
      stages.add(await d.grab('stage-S4-$i'));
    }
    expect(dir.phase, BossPhase.collapse);
    phone.add(stages[5]);
    await _sheet(tester, 'stages', stages, size, columns: 4);
    await _sheet(tester, 'phone', phone, size, scale: 1, columns: 4);

    // --- reduced motion: one static framing, no follow.
    scene.sectors.flyover.reducedMotionOverride = true;
    m.startAt(sector: 5, route: 0);
    dir.reset();
    final reduced = <ui.Image>[];
    await d.step(4.6);
    for (var i = 0; i < 6; i++) {
      await d.step(2);
      reduced.add(await d.grab('reduced-$i'));
      expect(dir.camera.followStrength, lessThan(1e-6));
    }
    expect(dir.camera.zoom, closeTo(ArenaCamera.carrierReducedZoom, .01));
    await _sheet(tester, 'reduced', reduced, size, columns: 6);
    scene.sectors.flyover.reducedMotionOverride = false;
    await dispose(tester);
  });

  testWidgets('boss grandeur widescreen 1280 x 720', (tester) async {
    const size = Size(1280, 720);
    final rig = await launch(tester, size, seed: 11);
    await tester.runAsync(() => loadReviewArt(rig));
    await _hero(tester, rig.scene);
    final d = _Drive(tester, rig);
    rig.model.startAt(sector: 5, route: 0);
    rig.scene.environment = 4;
    await d.step(4.6);
    final wide = <ui.Image>[];
    for (var i = 0; i < 4; i++) {
      await d.step(2.5);
      wide.add(await d.grab('wide-$i'));
    }
    await _sheet(tester, 'wide', wide, size, columns: 2);
    await dispose(tester);
  });
}
