import 'dart:io';
import 'dart:ui' as ui;

import 'package:demon_attack/game/ground_atlas.dart';
import 'package:demon_attack/game/ground_atmosphere.dart';
import 'package:demon_attack/game/ground_atmosphere_atlas.dart';
import 'package:demon_attack/game/ground_blocks_painter.dart';
import 'package:demon_attack/game/ground_troops_atlas.dart';
import 'package:demon_attack/game/sentinel_silhouette_atlas.dart';
import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fluid_transitions_test.dart' show Rig, dispose, launch;

/// mobile-top-trim review: the whole arcade page at two phone sizes
/// mid-fight, with the radio toasts (two callers) and the heart-piece toast
/// up, then a single caller. Checks by eye: a short HUD band, toasts sized
/// to their text, and the arena bottom-aligned over the pilot dock.
///
/// Frames go to `$MOBILE_TRIM_DIR/<tag>/` (default
/// .cache/mobile-top-trim-review/after). With `MOBILE_TRIM_BEFORE=<dir>`
/// naming an earlier run's frames, the before/after sheet is written to
/// `$MOBILE_TRIM_DIR/mobile-top-trim.png`, and also to
/// art/contact/mobile-top-trim.png with `MOBILE_TRIM_CONTACT=true`.
/// `MOBILE_TRIM_FONTS` names a folder with Roboto-Regular.ttf and
/// Roboto-Bold.ttf for real glyphs.
const _dir = String.fromEnvironment(
  'MOBILE_TRIM_DIR',
  defaultValue: '.cache/mobile-top-trim-review',
);
const _tag = String.fromEnvironment('MOBILE_TRIM_TAG', defaultValue: 'after');
const _before = String.fromEnvironment('MOBILE_TRIM_BEFORE');
const _contact = bool.fromEnvironment('MOBILE_TRIM_CONTACT');
const _fonts = String.fromEnvironment('MOBILE_TRIM_FONTS');

const _sizes = [Size(390, 844), Size(360, 780)];
const _shots = ['pair-heart', 'single'];

String _name(Size s, String shot) =>
    '${s.width.round()}x${s.height.round()}-$shot.png';

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
  for (final size in _sizes) {
    testWidgets('mobile top trim frames ${size.width}x${size.height}', (
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
      final rig = await launch(tester, size);
      await tester.runAsync(() => _loadArt(rig));
      await rig.step(5);
      final m = rig.model;
      m.startAt(sector: 1, route: 1, wave: 2);
      await rig.step(6);
      Future<void> hold() async {
        m
          ..lives = 4
          ..invulnerable = 0;
      }

      await hold();
      m.events.add('life');
      await rig.step(.6);
      await hold();
      final state = rig.state;
      state.heartNotice = 'HEART PIECE COLLECTED';
      state.heartNoticeUntil = m.clock + 5;
      await rig.step(.05);
      await _grab(tester, size, _shots[0]);
      _report(tester, size, _shots[0]);
      state.heartNotice = null;
      await rig.step(9);
      await hold();
      m.events.add('diveWarning');
      await rig.step(.8);
      await _grab(tester, size, _shots[1]);
      _report(tester, size, _shots[1]);
      await dispose(tester);
    });
  }

  testWidgets('mobile top trim sheet', (tester) async {
    if (_before.isEmpty) return;
    await tester.runAsync(() async {
      const gap = 8.0;
      final pairs = <(ui.Image, ui.Image)>[];
      for (final size in _sizes) {
        for (final shot in _shots) {
          final b = File('$_before/${_name(size, shot)}');
          final a = File('$_dir/$_tag/${_name(size, shot)}');
          if (!b.existsSync() || !a.existsSync()) continue;
          pairs.add((await _decode(b.path), await _decode(a.path)));
        }
      }
      if (pairs.isEmpty) return;
      // One row per shot: before | after, then the next shot beside it.
      var sw = gap, sh = gap, rowW = gap, rowH = 0.0, col = 0;
      final spots = <Offset>[];
      for (final (b, a) in pairs) {
        spots.add(Offset(rowW, sh));
        rowW += b.width + gap + a.width + gap * 3;
        rowH = rowH > b.height ? rowH : b.height.toDouble();
        if (++col == 2) {
          sw = sw > rowW ? sw : rowW;
          sh += rowH + gap * 3;
          rowW = gap;
          rowH = 0;
          col = 0;
        }
      }
      if (col != 0) {
        sw = sw > rowW ? sw : rowW;
        sh += rowH + gap;
      }
      final rec = ui.PictureRecorder();
      final c = ui.Canvas(rec);
      c.drawRect(
        Rect.fromLTWH(0, 0, sw, sh),
        Paint()..color = const Color(0xFF2A2F3A),
      );
      for (var i = 0; i < pairs.length; i++) {
        final (b, a) = pairs[i];
        final o = spots[i];
        c.drawImage(b, o, Paint());
        c.drawImage(a, o.translate(b.width + gap, 0), Paint());
        // Before frames carry a red tick, after frames a green one.
        c.drawRect(
          Rect.fromLTWH(o.dx, o.dy - 6, b.width.toDouble(), 4),
          Paint()..color = const Color(0xFFE05555),
        );
        c.drawRect(
          Rect.fromLTWH(o.dx + b.width + gap, o.dy - 6, a.width.toDouble(), 4),
          Paint()..color = const Color(0xFF55D08A),
        );
      }
      final sheet = await rec.endRecording().toImage(sw.round(), sh.round());
      final png = (await sheet.toByteData(format: ui.ImageByteFormat.png))!
          .buffer
          .asUint8List();
      for (final path in [
        '$_dir/mobile-top-trim.png',
        if (_contact) 'art/contact/mobile-top-trim.png',
      ]) {
        final file = File(path);
        await file.parent.create(recursive: true);
        await file.writeAsBytes(png);
      }
      sheet.dispose();
      for (final (b, a) in pairs) {
        b.dispose();
        a.dispose();
      }
    });
  });
}

Future<void> _grab(WidgetTester tester, Size size, String shot) async {
  await tester.pump();
  final boundary = tester.renderObject(
    find.byKey(const ValueKey('page')),
  ) as RenderRepaintBoundary;
  await tester.runAsync(() async {
    final image = await boundary.toImage();
    final png = (await image.toByteData(format: ui.ImageByteFormat.png))!.buffer
        .asUint8List();
    final file = File('$_dir/$_tag/${_name(size, shot)}');
    await file.parent.create(recursive: true);
    await file.writeAsBytes(png);
    image.dispose();
  });
}

/// Prints the band, toast and arena geometry for the report.
void _report(WidgetTester tester, Size size, String shot) {
  Rect? rect(String key) {
    final f = find.byKey(ValueKey(key));
    return f.evaluate().isEmpty ? null : tester.getRect(f.first);
  }

  final games = find.byWidgetPredicate((w) => w is GameWidget);
  final rects = [
    for (var i = 0; i < games.evaluate().length; i++)
      tester.getRect(games.at(i)),
  ]..sort((a, b) => (a.width * a.height).compareTo(b.width * b.height));
  final arena = rects.first;
  final scale = (arena.width / 360) < (arena.height / 520)
      ? arena.width / 360
      : arena.height / 520;
  final strips = find.byWidgetPredicate(
    (w) =>
        w.key is ValueKey<String> &&
        (w.key! as ValueKey<String>).value.startsWith('comms-strip-'),
  );
  final toasts = [
    for (var i = 0; i < strips.evaluate().length; i++)
      tester.getRect(strips.at(i)),
  ];
  // ignore: avoid_print
  print(
    'TRIM ${size.width.round()}x${size.height.round()} $shot '
    'arena=$arena render=${(520 * scale).toStringAsFixed(1)} '
    'stack=${rect('comms-hud-stack')} heart=${rect('heart-notice')} '
    'toasts=$toasts',
  );
}
