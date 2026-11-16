@Tags(['review'])
library;

import 'dart:io';
import 'dart:ui' as ui;

import 'package:demon_attack/game/arena_camera.dart';
import 'package:demon_attack/game/boss_atlas.dart';
import 'package:demon_attack/game/boss_director.dart';
import 'package:demon_attack/game/boss_grammar.dart';
import 'package:demon_attack/game/boss_painter.dart';
import 'package:demon_attack/game/model.dart';
import 'package:demon_attack/game/scene.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fluid_transitions_test.dart' show Rig, dispose, launch;
import 'playtest_fixes_review_test.dart' show decodeReviewImage, loadReviewArt;

/// boss-carrier-wire: in-game frames of the packed v2 carriers (the whole
/// arcade page, as the operator sees it):
///
/// - `boss-carrier-wire-<set>` for the three tour-1 set combinations
///   (thorn, lattice, shroud): engage, climb with a swerve, S2, S3;
/// - `-phone`: the zoom-out at 0.70 on a 360 × 640 phone, 1:1, each set;
/// - `-tour3`, `-tour5`: later tours (S0 bakes; S2 and S3 are the runtime
///   overlay fallback with charred stumps);
/// - `-overflight`: the belly in the Overflight;
/// - `-collapse`: the module wrecks with their shadows.
///
/// Frames go to `$BOSS_CARRIER_WIRE_REVIEW_DIR` (default
/// .cache/boss-carrier-wire-review); with
/// `--dart-define=BOSS_CARRIER_WIRE_CONTACT=true` the sheets are written to
/// `art/contact/boss-carrier-wire-<name>.png`. Without it the test still
/// drives every frame and checks the wiring (hull picked per run seed, the
/// carrier band, stages drawn).
const _dir = String.fromEnvironment(
  'BOSS_CARRIER_WIRE_REVIEW_DIR',
  defaultValue: '.cache/boss-carrier-wire-review',
);
const _contact = bool.fromEnvironment('BOSS_CARRIER_WIRE_CONTACT');

/// A run seed whose tour-[route] pick is set combination [set].
int seedFor(int route, int set) {
  for (var s = 1;; s++) {
    if (BossGrammar.forRun(
          route: route,
          variant: BossGrammar.variantFor(s, route),
          packed: BossPainter.packed,
        ).set ==
        set) {
      return s;
    }
  }
}

Future<void> _hero(WidgetTester tester, DemonScene scene, String key, int cls) async {
  final hull = BossHeroAtlas.hulls[key]!;
  final belly = BossPainter.bellyOf(hull);
  final imgs = await tester.runAsync(() async => [
        for (final p in hull.pages) await decodeReviewImage('assets/images/$p'),
        if (belly != null) await decodeReviewImage('assets/images/${belly.asset}'),
      ]);
  scene.armada.setHero(cls, hull, imgs!.sublist(0, hull.pages.length),
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
    final file = File('art/contact/boss-carrier-wire-$name.png');
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

  /// A carrier of tour [route] drawn with combination [set], engaged.
  Future<Carrier> engage(int route, int set) async {
    final key = BossGrammar.baked[route][set];
    m.startAt(sector: 5, route: route, runSeed: seedFor(route, set));
    scene.bossDirector.reset();
    await _hero(tester, scene, key, route);
    expect(BossPainter.heroForRun(route, m.bossVariant)!.key, key,
        reason: 'the run seed picks $key');
    while (!m.boss!.fightReady) {
      await step(.25);
    }
    await step(2);
    expect(scene.armada.hero!.key, key, reason: 'sync keeps the picked hull');
    expect(scene.armada.carrier, isTrue);
    return m.boss!;
  }

  /// The four fight frames of one combination: engage, climb + swerve, S2,
  /// S3 (stage frames hold the director's view at the swerve).
  Future<List<ui.Image>> fight(String name, int route, int set) async {
    final dir = scene.bossDirector;
    final out = <ui.Image>[];
    final b = await engage(route, set);
    out.add(await grab('$name-engage'));
    await step(9);
    expect(dir.altitude, greaterThan(1.3));
    expect(dir.camera.zoom, lessThanOrEqualTo(ArenaCamera.carrierMaxZoom + 1e-9));
    dir
      ..view = const BossView(0, -1)
      ..previous = const BossView(0, -1)
      ..blend = 1;
    out.add(await grab('$name-climb-swerve'));
    b.shield = 0;
    await step(1.5);
    expect(dir.stage, 2);
    out.add(await grab('$name-S2'));
    b.core = b.coreMax ~/ 2 - 1;
    await step(1.2);
    expect(dir.stage, 3);
    out.add(await grab('$name-S3'));
    return out;
  }
}

void main() {
  testWidgets('carrier sets at engage, climb, S2 and S3 (360 × 780)', (tester) async {
    const size = Size(360, 780);
    final rig = await launch(tester, size, seed: 11);
    await tester.runAsync(() => loadReviewArt(rig));
    final d = _Drive(tester, rig);
    for (final (i, set) in BossGrammar.baked[0].indexed) {
      final name = set.split('-').last;
      final frames = await d.fight(name, 0, i);
      await _sheet(tester, name, frames, size, columns: 4);
    }
    await dispose(tester);
  });

  testWidgets('the zoom-out at 0.70 on a 360 × 640 phone', (tester) async {
    const size = Size(360, 640);
    final rig = await launch(tester, size, seed: 11);
    await tester.runAsync(() => loadReviewArt(rig));
    final d = _Drive(tester, rig);
    final dir = rig.scene.bossDirector;
    final frames = <ui.Image>[];
    for (final (i, _) in BossGrammar.baked[0].indexed) {
      await d.engage(0, i);
      await d.step(12);
      // The band's floor: the wide framing at full range, swerve and climb.
      dir.camera.zoom = ArenaCamera.carrierMinZoom;
      frames.add(await d.grab('phone-z070-$i'));
    }
    await _sheet(tester, 'phone', frames, size, scale: 1, columns: 3);
    await dispose(tester);
  });

  testWidgets('later tours: S0 bakes with the overlay fallback', (tester) async {
    const size = Size(360, 780);
    final rig = await launch(tester, size, seed: 11);
    await tester.runAsync(() => loadReviewArt(rig));
    final d = _Drive(tester, rig);
    for (final route in [2, 4]) {
      final frames = await d.fight('tour${route + 1}', route, 0);
      // S2/S3 are not baked for tours 2–5: the overlay carries them.
      final painter = rig.scene.armada;
      expect(painter.drawnStage(BossView.hero, 3), 0);
      expect(BossPainter.overlayFor(3, 0), greaterThan(0));
      await _sheet(tester, 'tour${route + 1}', frames, size, columns: 4);
    }
    await dispose(tester);
  });

  testWidgets('the overflight belly and the collapse wreck shadows', (tester) async {
    const size = Size(360, 780);
    final rig = await launch(tester, size, seed: 11);
    await tester.runAsync(() => loadReviewArt(rig));
    final d = _Drive(tester, rig);
    final m = rig.model;
    final scene = rig.scene;
    final dir = scene.bossDirector;
    // The overflight: sector 4's last kill, then the boss arrival.
    m.startAt(sector: 4, route: 0, wave: ArcadeModel.wavesFor(sector: 4, route: 0));
    await _hero(tester, scene, 'carrier1-thorn', 0);
    await d.step(4.6);
    m.endSector();
    while (!(m.flow.active && m.flow.seconds >= m.flow.plan.descentAt)) {
      await d.step(.1);
    }
    expect(scene.armada.bellyImage, isNotNull);
    final over = <ui.Image>[];
    for (var i = 0; i < 6; i++) {
      while (dir.overflight < (i + .5) / 6 && dir.phase == BossPhase.overflight) {
        await d.step(1 / 30);
      }
      over.add(await d.grab('overflight-$i'));
    }
    await _sheet(tester, 'overflight', over, size, columns: 6);

    // The collapse: every module falls with its shadow, the carapace last.
    final b = await d.engage(0, 0);
    b
      ..shield = 0
      ..core = 1
      ..door = 1;
    await d.step(.5);
    m.hitBoss(b.x);
    expect(m.mode, RunMode.victory);
    final fall = <ui.Image>[];
    for (var i = 0; i < 4; i++) {
      await d.step(.8);
      expect(dir.phase, BossPhase.collapse);
      fall.add(await d.grab('collapse-$i'));
    }
    expect(
      dir.wrecks.where((w) => !w.plate && scene.armada.wreckSprite(w) != null),
      isNotEmpty,
    );
    await _sheet(tester, 'collapse', fall, size, columns: 4);
    await dispose(tester);
  });
}
