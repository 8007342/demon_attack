import 'dart:io';
import 'dart:ui' as ui;

import 'package:demon_attack/game/ground_atlas.dart';
import 'package:demon_attack/game/ground_atmosphere.dart';
import 'package:demon_attack/game/ground_atmosphere_atlas.dart';
import 'package:demon_attack/game/ground_blocks_painter.dart';
import 'package:demon_attack/game/ground_troops_atlas.dart';
import 'package:demon_attack/game/model.dart';
import 'package:demon_attack/game/sentinel_silhouette_atlas.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fluid_transitions_test.dart' show Rig, dispose, launch;

/// playtest-fixes review strip: the whole arcade page (HUD, comms dock and
/// the transition overlay over the arena) at phone portrait through the late
/// final wave of sector 2 into the sector change, as the operator sees it.
/// Checks by eye: an empty fog during the final wave and at its end, and no
/// floating caption or title text (the radio line is on the dock).
///
/// Frames go to `$PLAYTEST_FIXES_REVIEW_DIR` (default
/// .cache/playtest-fixes-review); with `--dart-define=
/// PLAYTEST_FIXES_CONTACT=true` the strip is also written to
/// art/contact/playtest-fixes-final-wave.png. `PLAYTEST_FIXES_FONTS` names
/// a folder with Roboto-Regular.ttf and Roboto-Bold.ttf for real glyphs.
const _dir = String.fromEnvironment(
  'PLAYTEST_FIXES_REVIEW_DIR',
  defaultValue: '.cache/playtest-fixes-review',
);
const _contact = bool.fromEnvironment('PLAYTEST_FIXES_CONTACT');
const _fonts = String.fromEnvironment('PLAYTEST_FIXES_FONTS');

Future<ui.Image> _decode(String file) async {
  final codec = await ui.instantiateImageCodec(await File(file).readAsBytes());
  final frame = await codec.getNextFrame();
  codec.dispose();
  return frame.image;
}

Future<void> _loadArt(Rig rig) async {
  final scene = rig.scene;
  for (var i = 0; i < 5; i++) {
    scene.sectors.images[i] = await _decode(
      'assets/images/sector-${i + 1}.png',
    );
  }
  await scene.sectors.loadFlyover((f) => _decode('assets/images/$f'));
  scene.atlas = await _decode('assets/images/combat.png');
  scene.effectsAtlas = await _decode('assets/images/sentinel-effects.png');
  scene.sky = await _decode('assets/images/cosmic-sky.png');
  scene.silhouetteAtlas = await _decode(
    'assets/images/${SentinelSilhouetteAtlas.file}',
  );
  scene.ship.image = await _decode('assets/images/ship-weapons.png');
  scene.groundForces
    ..image = await _decode('assets/images/${GroundAtlas.file}')
    ..troops = await _decode('assets/images/${GroundTroopsAtlas.file}');
  for (var s = 0; s < 5; s++) {
    scene.groundForces.blocks.install(s, {
      for (final f in GroundBlocksLayer.files(s))
        f.substring('ground-blocks/'.length): await _decode('assets/images/$f'),
    });
  }
  await scene.atmosphere.load();
  scene.atmosphere.groundArt = GroundAtmosphereArt(
    await _decode('assets/images/${GroundAtmosphereAtlas.file}'),
  );
}

void main() {
  testWidgets('playtest fixes: final wave into a sector change', (
    tester,
  ) async {
    if (_fonts.isNotEmpty) {
      await tester.runAsync(() async {
        final roboto = FontLoader('Roboto');
        for (final file in ['Roboto-Regular.ttf', 'Roboto-Bold.ttf']) {
          final bytes = File('$_fonts/$file').readAsBytesSync();
          roboto.addFont(Future.value(ByteData.sublistView(bytes)));
        }
        await roboto.load();
      });
    }
    const size = Size(390, 844);
    final rig = await launch(tester, size);
    await tester.runAsync(() => _loadArt(rig));
    await rig.step(5);
    final m = rig.model;
    final waves = ArcadeModel.wavesFor(sector: 2, route: 1);
    m.startAt(sector: 2, route: 1, wave: waves);
    rig.scene.environment = 1;
    final frames = <ui.Image>[];
    final labels = <String>[];
    Future<void> grab(String label) async {
      await tester.pump();
      final boundary =
          tester.renderObject(find.byKey(const ValueKey('page')))
              as RenderRepaintBoundary;
      await tester.runAsync(() async {
        frames.add(await boundary.toImage());
      });
      labels.add(label);
    }

    Future<void> fight(double seconds, {double every = .5}) async {
      var cool = 0.0;
      for (var t = 0.0; t < seconds; t += .1) {
        m
          ..lives = 5
          ..invulnerable = 5;
        cool -= .1;
        if (m.combat && cool <= 0) {
          final d = m.demons.where((d) => !d.entering).firstOrNull;
          if (d != null) {
            while (m.demons.contains(d)) {
              m.hitDemon(d);
            }
            cool = every;
          }
        }
        await rig.step(.1);
        if (m.combat && m.level == 2) {
          expect(m.fogStaged, isEmpty, reason: 'final wave fog at $t');
        }
      }
    }

    // The final wave: its arrival, then the fight with held-back skeins and
    // groups admitted as the roster thins.
    await rig.step(4.6);
    expect(m.mode, RunMode.playing);
    expect(m.finalWave, isTrue);
    await grab('final wave');
    for (var i = 0; i < 3 && m.level == 2 && m.combat; i++) {
      await fight(3);
      await grab('final wave');
    }
    // Finish it (the last kill), then the transition to sector 3.
    while (m.combat && m.level == 2) {
      await fight(.5, every: .1);
    }
    expect(m.mode, RunMode.salvage);
    await grab('last kill');
    for (final (label, s) in [
      ('rout', 1.2),
      ('pursuit', 1.5),
      ('pursuit', 1.5),
      ('cloud', 1.5),
      ('cloud', 1.5),
      ('descent', 1.5),
      ('descent', 1.5),
    ]) {
      await rig.step(s);
      expect(find.byKey(const ValueKey('flow-caption')), findsNothing);
      expect(find.byKey(const ValueKey('flow-title')), findsNothing);
      expect(m.flowFlock, isEmpty);
      await grab(label);
    }
    expect(m.level, 3);
    // Tile the page frames 6 wide at 0.4.
    await tester.runAsync(() async {
      const scale = .4, gap = 4.0, cols = 6;
      final fw = size.width * scale, fh = size.height * scale;
      final rows = (frames.length / cols).ceil();
      final sw = gap + cols * (fw + gap), sh = gap + rows * (fh + gap);
      final rec = ui.PictureRecorder();
      final c = ui.Canvas(rec);
      c.drawRect(
        Rect.fromLTWH(0, 0, sw, sh),
        Paint()..color = const Color(0xFF101218),
      );
      for (var i = 0; i < frames.length; i++) {
        final x = gap + (i % cols) * (fw + gap);
        final y = gap + (i ~/ cols) * (fh + gap);
        final f = frames[i];
        c.drawImageRect(
          f,
          Rect.fromLTWH(0, 0, f.width.toDouble(), f.height.toDouble()),
          Rect.fromLTWH(x, y, fw, fh),
          Paint()..filterQuality = FilterQuality.medium,
        );
      }
      final pic = rec.endRecording();
      final sheet = await pic.toImage(sw.round(), sh.round());
      final png = (await sheet.toByteData(
        format: ui.ImageByteFormat.png,
      ))!.buffer.asUint8List();
      for (final path in [
        '$_dir/playtest-fixes-final-wave.png',
        if (_contact) 'art/contact/playtest-fixes-final-wave.png',
      ]) {
        final file = File(path);
        await file.parent.create(recursive: true);
        await file.writeAsBytes(png);
      }
      sheet.dispose();
      for (final f in frames) {
        f.dispose();
      }
    });
    // ignore: avoid_print
    print('frames: ${labels.join(', ')}');
    await dispose(tester);
  });
}
