@Tags(['review'])
library;

import 'dart:io';
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

/// carrier-hatches review (design §A10, §B; tasks 10.1): real in-game frames
/// of the whole arcade page at 360 × 640.
///
/// - `cascade`: tier 1's hatches and their fields, a pop-up, a field worn
///   down, a hatch destroyed (ivory splinters), the cascade to tier 2;
/// - `transform`: the last hatch falls, the tusks part, the core door is
///   exposed with the camera zoomed back in, the lead pip;
/// - `breakup`: a module breaking off component by component (its armour
///   step, then the form change) and the S2 shed.
///
/// With `--dart-define=CARRIER_HATCHES_CONTACT=true` the sheets go to
/// `art/contact/carrier-hatches-<name>.png`; every frame (and the GIF
/// frames, `fight/NN.png`) to `.cache/carrier-hatches-review`.
const _contact = bool.fromEnvironment('CARRIER_HATCHES_CONTACT');
const _dir = '.cache/carrier-hatches-review';
const _size = Size(360, 640);

Future<void> _hero(
  WidgetTester tester,
  DemonScene scene,
  String key,
  int cls,
) async {
  final hull = BossHeroAtlas.hulls[key]!;
  final pages = await tester.runAsync(
    () async => [
      for (final p in hull.pages) await decodeReviewImage('assets/images/$p'),
    ],
  );
  scene.armada.setHero(cls, hull, pages!);
  await tester.runAsync(() => scene.breakup.prepare(scene.armada));
  expect(scene.breakup.ready, isTrue, reason: 'components for $key');
}

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
        final x = gap + (i % cols) * (fw + gap),
            y = gap + (i ~/ cols) * (fh + gap);
        c.drawImageRect(
          f,
          Rect.fromLTWH(0, 0, f.width.toDouble(), f.height.toDouble()),
          Rect.fromLTWH(x, y, fw, fh),
          Paint()..filterQuality = FilterQuality.medium,
        );
      }
      final pic = rec.endRecording();
      final img = await pic.toImage(sw.round(), sh.round());
      pic.dispose();
      final png = await img.toByteData(format: ui.ImageByteFormat.png);
      img.dispose();
      final file = File('art/contact/carrier-hatches-$name.png');
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
  int gif = 0;

  /// The GIF frames' folder and name prefix (sorted by name when packed).
  String clipName = 'fight/a';

  Future<void> step(
    double seconds, {
    bool kill = false,
    bool clip = false,
  }) async {
    var next = 0.0;
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
      if (clip && t >= next) {
        next += .2;
        await tester.pump();
        (await grab('$clipName${(gif++).toString().padLeft(3, '0')}')).dispose();
      }
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
    scene.bossDirector.reset();
    await _hero(tester, scene, key, route);
    for (var g = 0; g < 200 && !m.boss!.fightReady; g++) {
      await step(.25);
    }
    expect(m.boss!.fightReady, isTrue);
    return m.boss!;
  }

  /// Wears the vulnerable tier down: [fraction] of each hatch's HP.
  void wear(Carrier b, double fraction) {
    for (final (i, h) in b.hatches.indexed) {
      if (h.destroyed || h.hatch.tier != b.vulnerableTier) continue;
      m.hitHatch(i, damage: (h.hpMax * fraction).ceil());
    }
  }
}

void main() {
  testWidgets('cascade: tier 1, a pop-up, a field worn, destroyed, tier 2', (
    tester,
  ) async {
    final rig = await launch(tester, _size, seed: 11);
    await tester.runAsync(() => loadReviewArt(rig));
    final d = _Drive(tester, rig);
    final b = await d.fight(0);
    final frames = <ui.Image>[];
    await d.step(5, clip: true);
    frames.add(await d.grab('cascade-0-tier1'));
    // A pop-up: a creature leaving a hatch.
    for (var g = 0; g < 60 * 12; g++) {
      await d.step(1 / 60, kill: g % 90 == 0);
      final out = d.m.demons.any(
        (x) =>
            x.entering && x.entranceProgress > .05 && x.entranceProgress < .3,
      );
      if (out) break;
    }
    frames.add(await d.grab('cascade-1-popup'));
    d.wear(b, .45);
    await d.step(.6, clip: true);
    frames.add(await d.grab('cascade-2-field-worn'));
    // Tier 1 destroyed (field, then hull), tier 2 untouched.
    for (final (i, h) in b.hatches.indexed) {
      if (h.hatch.tier != 0) continue;
      d.m.hitHatch(i, damage: h.hpMax);
      d.m.hitHatch(i, damage: h.hpMax);
    }
    await d.step(.35);
    frames.add(await d.grab('cascade-3-destroyed'));
    await d.step(1.2, clip: true);
    expect(
      b.hatches.where((h) => h.hatch.tier == 0).every((h) => h.destroyed),
      isTrue,
    );
    frames.add(await d.grab('cascade-4-tier2'));
    await d.step(4, clip: true);
    frames.add(await d.grab('cascade-5-tier2-launch'));
    await _sheet(tester, 'cascade', frames, columns: 3);
    await dispose(tester);
  });

  testWidgets('transform: the tusks part, the core door, the lead pip', (
    tester,
  ) async {
    final rig = await launch(tester, _size, seed: 11);
    await tester.runAsync(() => loadReviewArt(rig));
    final d = _Drive(tester, rig)..clipName = 'fight/b';
    final b = await d.fight(0);
    await d.step(4);
    for (var g = 0; g < 40 && b.vulnerableTier != null; g++) {
      d.wear(b, 1);
      await d.step(.4, clip: true);
    }
    expect(b.hatches.every((h) => h.destroyed), isTrue);
    final frames = <ui.Image>[];
    final zoom = d.dir.camera.zoom;
    for (var g = 0; g < 200 && b.chapter != CarrierChapter.transform; g++) {
      await d.step(1 / 30, clip: true);
    }
    frames.add(await d.grab('transform-0-start'));
    await d.step(1.2, clip: true);
    frames.add(await d.grab('transform-1'));
    await d.step(1.2, clip: true);
    frames.add(await d.grab('transform-2'));
    await d.step(1.3, clip: true);
    expect(b.chapter, CarrierChapter.core);
    frames.add(await d.grab('transform-3-core'));
    await d.step(3, clip: true);
    expect(d.dir.camera.zoom, greaterThan(zoom), reason: 'zoomed back in');
    d.m.leadHinted = true; // the pip after the lead hint (Normal)
    for (var g = 0; g < 120 && b.door < .8; g++) {
      await d.step(1 / 30);
    }
    frames.add(await d.grab('transform-4-pip'));
    // ignore: avoid_print
    print(
      'CARRIER_HATCHES_ZOOM ${zoom.toStringAsFixed(3)} → '
      '${d.dir.camera.zoom.toStringAsFixed(3)}',
    );
    await _sheet(tester, 'transform', frames, columns: 5);
    await dispose(tester);
  });

  testWidgets('breakup: a module piece by piece; the shed', (tester) async {
    final rig = await launch(tester, _size, seed: 11);
    await tester.runAsync(() => loadReviewArt(rig));
    final d = _Drive(tester, rig)..clipName = 'breakup/';
    final b = await d.fight(0);
    await d.step(3);
    // The shield out: straight into the core (fixture), then the shed.
    b.shield = 0;
    await d.step(.1);
    expect(b.chapter, CarrierChapter.core);
    final frames = <ui.Image>[];
    await d.step(.6, clip: true);
    frames.add(await d.grab('breakup-0-shed'));
    await d.step(1.2, clip: true);
    frames.add(await d.grab('breakup-1-shed'));
    // The armour step before form 1: the spines start to break.
    b.core = (b.coreMax * (1 - 1 / b.armourSteps)).floor();
    b.door = 1;
    d.m.hitBoss(b.x);
    await d.step(.5, clip: true);
    expect(d.dir.breakStart, isNotEmpty);
    frames.add(await d.grab('breakup-2-cracking'));
    await d.step(.8, clip: true);
    frames.add(await d.grab('breakup-3-cracking'));
    // The form change: the rest goes, one by one.
    b.core = (b.coreMax * (1 - 2 / b.armourSteps)).floor() + 1;
    b.door = 1;
    d.m.hitBoss(b.x);
    await d.step(.4, clip: true);
    frames.add(await d.grab('breakup-4-form'));
    await d.step(.8, clip: true);
    frames.add(await d.grab('breakup-5-form'));
    await d.step(1.2, clip: true);
    frames.add(await d.grab('breakup-6-form'));
    // ignore: avoid_print
    print(
      'CARRIER_BREAKUP components=${d.scene.breakup.components.length} '
      'vertices=${d.scene.breakup.lastVertices} '
      'calls=${d.scene.breakup.lastCalls}',
    );
    await _sheet(tester, 'breakup', frames, columns: 4);
    await dispose(tester);
  });
}
