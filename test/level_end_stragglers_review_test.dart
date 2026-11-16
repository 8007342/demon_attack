@Tags(['review'])
library;

import 'dart:io';
import 'dart:ui' as ui;

import 'package:demon_attack/game/boss_atlas.dart';
import 'package:demon_attack/game/boss_painter.dart';
import 'package:demon_attack/game/model.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fluid_transitions_test.dart' show dispose, launch;
import 'playtest_fixes_review_test.dart' show decodeReviewImage, loadReviewArt;

/// playtest R1 review sheet: three level ends at phone portrait, one row
/// each, as the operator sees them (whole arcade page):
///
/// 1. a normal sector (Normal, route 0, sector 3): late final wave, last
///    kill, Rout, Pursuit, cloud, Descent into sector 4, its first fight;
/// 2. a carrier level (Normal, route 1, sector 5): the fight with its
///    minions, the fall, the victory flight, cloud, Descent into route 2;
/// 3. a sentinel level (Normal, route 2, sector 2, whose final wave brings
///    an armoured sentinel): the sentinel fight, the last kill, the
///    transition into sector 3, where a later sentinel is due.
///
/// Checks by eye: from the last kill to the Descent nothing flies in or
/// behind the fog (no straggler, no flock, no silhouette, no shadow); the
/// Descent shows the new sector's first cohort only.
///
/// Frames go to `$LEVEL_END_REVIEW_DIR` (default .cache/level-end-review);
/// with `--dart-define=LEVEL_END_CONTACT=true` the sheet is also written to
/// art/contact/level-end-stragglers.png.
const _dir = String.fromEnvironment(
  'LEVEL_END_REVIEW_DIR',
  defaultValue: '.cache/level-end-review',
);
const _contact = bool.fromEnvironment('LEVEL_END_CONTACT');

void main() {
  testWidgets('level ends: normal sector, carrier, sentinel', (tester) async {
    const size = Size(390, 844);
    final rig = await launch(tester, size);
    await tester.runAsync(() => loadReviewArt(rig));
    final m = rig.model;
    final scene = rig.scene;
    final hull = BossAtlas.classes[BossPainter.classFor(1)];
    final hullArt = await tester.runAsync(
      () => decodeReviewImage('assets/images/${hull.asset}'),
    );
    scene.armada.setAtlas(BossPainter.classFor(1), hullArt!);
    final rows = <List<ui.Image>>[];
    final named = <String>[];

    /// The scene's own frame (presentation, creature deaths) with the
    /// model: the backdrop and fog follow the sector change.
    Future<void> step(double seconds) async {
      for (var t = 0.0; t < seconds - 1e-9; t += 1 / 60) {
        scene.advancePresentation(1 / 60);
        m.update(1 / 60);
        scene.creatures.update(m, 1 / 60);
        scene.onTick();
      }
      await tester.pump();
    }

    var sentinelSeen = false;

    Future<void> grab(List<ui.Image> row, String label) async {
      await tester.pump();
      final boundary = tester.renderObject(
        find.byKey(const ValueKey('page')),
      ) as RenderRepaintBoundary;
      await tester.runAsync(() async {
        final image = await boundary.toImage();
        row.add(image);
        final name = 'r${rows.length + 1}-${row.length}-$label';
        named.add(name);
        final png = await image.toByteData(format: ui.ImageByteFormat.png);
        final file = File('$_dir/$name.png');
        await file.parent.create(recursive: true);
        await file.writeAsBytes(png!.buffer.asUint8List());
      });
    }

    Future<void> fight(double seconds, {double every = .4}) async {
      var cool = 0.0;
      for (var t = 0.0; t < seconds && m.combat; t += .1) {
        m
          ..lives = 5
          ..invulnerable = 5;
        cool -= .1;
        if (cool <= 0) {
          final d = m.demons
              .where((d) => !d.entering && d.swarmState != SwarmState.reserve)
              .firstOrNull;
          if (d != null) {
            if (d.isLarge) sentinelSeen = true;
            for (var guard = 0; guard < 1000 && m.demons.contains(d); guard++) {
              m.hitDemon(d);
            }
            cool = every;
          }
        }
        await step(.1);
      }
    }

    /// The transition after the clear, frame by frame.
    Future<void> transition(List<ui.Image> row, int level) async {
      for (final (label, s) in [
        ('rout', 1.0),
        ('pursuit', 2.0),
        ('cloud', 2.0),
        ('descent', 2.4),
      ]) {
        await step(s);
        if (m.level == level) {
          expect(
            scene.airCensus().empty,
            isTrue,
            reason: '$label: ${scene.airCensus()}',
          );
        }
        await grab(row, label);
      }
      // Nothing alive in or behind the fog through the whole transition.
      expect(scene.airCensus().empty, isTrue, reason: '${scene.airCensus()}');
      while (!m.combat) {
        await step(.5);
      }
      await grab(row, 'first-fight'); // the new sector's first cohort
    }

    // 1. A normal sector's end.
    {
      final row = <ui.Image>[];
      final waves = ArcadeModel.wavesFor(sector: 3, route: 0);
      m.startAt(sector: 3, route: 0, wave: waves);
      scene.environment = 2;
      await step(4.6);
      await fight(6);
      await grab(row, 'final-wave');
      while (m.combat && m.level == 3) {
        await fight(.5, every: .35);
      }
      expect(m.mode, RunMode.salvage);
      await grab(row, 'last-kill');
      await transition(row, 3);
      rows.add(row);
    }
    // 2. A carrier's fall.
    {
      final row = <ui.Image>[];
      m.startAt(sector: 5, route: 1);
      scene.environment = 4;
      await step(4.6);
      for (var i = 0; i < 12; i++) {
        m
          ..lives = 5
          ..invulnerable = 5;
        await step(.5);
      }
      await grab(row, 'carrier-fight');
      final b = m.boss!
        ..shield = 0
        ..core = 1
        ..door = 1;
      m.hitBoss(b.x);
      expect(m.mode, RunMode.victory);
      expect(m.flowFlock, isEmpty);
      await step(.2);
      await grab(row, 'carrier-fall');
      await transition(row, 5);
      rows.add(row);
    }
    // 3. A sentinel level's end.
    {
      final row = <ui.Image>[];
      final waves = ArcadeModel.wavesFor(sector: 2, route: 2);
      m.startAt(sector: 2, route: 2, wave: waves);
      scene.environment = 1;
      await step(4.6);
      await fight(9, every: .6);
      await grab(row, 'sentinel-fight');
      while (m.combat && m.level == 2) {
        await fight(.5, every: .35);
      }
      expect(m.mode, RunMode.salvage);
      expect(sentinelSeen, isTrue, reason: 'the final wave had a sentinel');
      await grab(row, 'last-kill');
      await transition(row, 2);
      rows.add(row);
    }

    await tester.runAsync(() async {
      const scale = .5, gap = 4.0;
      final cols = rows.map((r) => r.length).reduce((a, b) => a > b ? a : b);
      final fw = size.width * scale, fh = size.height * scale;
      final sw = gap + cols * (fw + gap), sh = gap + rows.length * (fh + gap);
      final rec = ui.PictureRecorder();
      final c = ui.Canvas(rec);
      c.drawRect(
        Rect.fromLTWH(0, 0, sw, sh),
        Paint()..color = const Color(0xFF101218),
      );
      for (var r = 0; r < rows.length; r++) {
        for (var i = 0; i < rows[r].length; i++) {
          final f = rows[r][i];
          c.drawImageRect(
            f,
            Rect.fromLTWH(0, 0, f.width.toDouble(), f.height.toDouble()),
            Rect.fromLTWH(gap + i * (fw + gap), gap + r * (fh + gap), fw, fh),
            Paint()..filterQuality = FilterQuality.medium,
          );
        }
      }
      final sheet = await rec.endRecording().toImage(sw.round(), sh.round());
      final png = (await sheet.toByteData(format: ui.ImageByteFormat.png))!
          .buffer
          .asUint8List();
      for (final path in [
        '$_dir/level-end-stragglers.png',
        if (_contact) 'art/contact/level-end-stragglers.png',
      ]) {
        final file = File(path);
        await file.parent.create(recursive: true);
        await file.writeAsBytes(png);
      }
      sheet.dispose();
      for (final row in rows) {
        for (final f in row) {
          f.dispose();
        }
      }
    });
    // ignore: avoid_print
    print('frames: ${named.join(', ')}');
    await dispose(tester);
  });
}
