@Tags(['review'])
library;

import 'dart:io';
import 'dart:ui' as ui;

import 'package:demon_attack/comms/comms_briefing.dart';
import 'package:demon_attack/game/bonus/bonus_catalog.dart';
import 'package:demon_attack/game/bonus/bonus_plan.dart';
import 'package:demon_attack/game/ground_atlas.dart';
import 'package:demon_attack/game/ground_atmosphere.dart';
import 'package:demon_attack/game/ground_atmosphere_atlas.dart';
import 'package:demon_attack/game/ground_blocks_painter.dart';
import 'package:demon_attack/game/ground_troops_atlas.dart';
import 'package:demon_attack/game/sentinel_silhouette_atlas.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fluid_transitions_test.dart' show Rig, dispose, launch;

/// bonus-briefing review strip: the whole arcade page at two phone sizes
/// through the transition into each bonus level, three frames per strip:
/// the card opening on the invite, the squadmate's dare, and the brood's
/// retort in the Descent. Checks by eye: the "URGENT MISSION!" card in the
/// dock's toast style, compact, above the ship row, the level's rule and
/// the run rule readable, the chatter in the card's own written words.
///
/// Off by default. `--dart-define=BONUS_BRIEFING_CONTACT=true` writes
/// `art/contact/bonus-briefing-<level>-<w>x<h>.png`;
/// `BONUS_BRIEFING_FONTS` names a folder with Roboto-Regular.ttf and
/// Roboto-Bold.ttf for real glyphs.
const _contact = bool.fromEnvironment('BONUS_BRIEFING_CONTACT');
const _fonts = String.fromEnvironment('BONUS_BRIEFING_FONTS');

const _sizes = [Size(360, 780), Size(390, 844)];

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

Future<ui.Image> _grab(WidgetTester tester) async {
  await tester.pump();
  final boundary = tester.renderObject(
    find.byKey(const ValueKey('page')),
  ) as RenderRepaintBoundary;
  return (await tester.runAsync(() => boundary.toImage()))!;
}

Future<void> _sheet(String path, List<ui.Image> frames) async {
  const gap = 8.0;
  final w = frames.fold<double>(gap, (a, f) => a + f.width + gap);
  final h = frames.fold<double>(0, (a, f) => a > f.height ? a : f.height + 0);
  final rec = ui.PictureRecorder();
  final c = ui.Canvas(rec);
  c.drawRect(
    Rect.fromLTWH(0, 0, w, h + gap * 2),
    Paint()..color = const Color(0xFF2A2F3A),
  );
  var x = gap;
  for (final f in frames) {
    c.drawImage(f, Offset(x, gap), Paint());
    x += f.width + gap;
  }
  final sheet = await rec.endRecording().toImage(
    w.round(),
    (h + gap * 2).round(),
  );
  final png = (await sheet.toByteData(format: ui.ImageByteFormat.png))!.buffer
      .asUint8List();
  final file = File(path);
  await file.parent.create(recursive: true);
  await file.writeAsBytes(png);
  sheet.dispose();
}

void main() {
  for (final level in bonusLevels) {
    for (final size in _sizes) {
      final name =
          'bonus-briefing-${level.id}-${size.width.round()}x${size.height.round()}';
      testWidgets(name, (tester) async {
        if (!_contact) return;
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
        m.startAt(sector: 2, route: 0);
        await rig.step(6);
        // The Supply Run strip also shows a run rule on the card.
        m.bonusRun.plan = BonusPlan([
          BonusSlot(0, 3, level),
        ], level.id == 'supplyRun' ? runModifierById('noShield') : null);
        m.lives = 3;
        rig.clearSector();
        final frames = <ui.Image>[];
        var want = 1;
        for (var i = 0; i < 400 && frames.length < 3; i++) {
          await rig.step(.05);
          final b = rig.transitions.briefing as BonusBriefing?;
          if (b == null || !b.open) continue;
          final spoken = b.spoken();
          // One frame per turn, a little after it starts (the card's
          // fade and the caller's static are over).
          if (spoken.length >= want &&
              rig.comms.now - spoken[want - 1].startedAt > .6) {
            frames.add(await _grab(tester));
            want++;
          }
        }
        expect(frames, isNotEmpty);
        await tester.runAsync(() => _sheet('art/contact/$name.png', frames));
        for (final f in frames) {
          f.dispose();
        }
        await dispose(tester);
      });
    }
  }
}
