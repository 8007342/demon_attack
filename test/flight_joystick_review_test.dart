@Tags(['review'])
library;

import 'dart:io';
import 'dart:ui' as ui;

import 'package:demon_attack/game/boss_atlas.dart';
import 'package:demon_attack/game/boss_grammar.dart';
import 'package:demon_attack/game/boss_painter.dart';
import 'package:demon_attack/game/model.dart';
import 'package:demon_attack/game/scene.dart';
import 'package:demon_attack/widgets/flight_joystick.dart';
import 'package:demon_attack/widgets/flight_joystick_atlas.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

import 'boss_carrier_wire_review_test.dart' show seedFor;
import 'fluid_transitions_test.dart' show Rig, dispose, launch;
import 'playtest_fixes_review_test.dart' show decodeReviewImage, loadReviewArt;

/// flight-joystick: in-game frames of the control pad's flight stick on a
/// 360 × 780 phone at DPR 2 (the whole arcade page, as the operator sees it):
/// at rest, moving left at full speed, and moving up-right fast (steering
/// right while the ship climbs with the carrier, the flow boost at its top).
///
/// With `--dart-define=FLIGHT_JOYSTICK_CONTACT=true` the sheet is written to
/// `art/contact/flight-joystick-ingame.png`: the three pages over the three
/// pads at device pixels. Without it the test still drives every frame and
/// checks the stick's cell.
const _contact = bool.fromEnvironment('FLIGHT_JOYSTICK_CONTACT');

/// A folder with Roboto-Regular.ttf and Roboto-Bold.ttf, for readable text
/// on the sheet (the test font draws boxes).
const _fonts = String.fromEnvironment('FLIGHT_JOYSTICK_FONTS');
const _size = Size(360, 780);
const _dpr = 2.0;

class _Drive {
  _Drive(this.tester, this.rig);
  final WidgetTester tester;
  final Rig rig;
  ArcadeModel get m => rig.model;
  DemonScene get scene => rig.scene;

  /// Simulation and widget time together (the stick's ease runs on frames).
  Future<void> step(double seconds) async {
    for (var t = 0.0; t < seconds - 1e-9; t += 1 / 60) {
      m
        ..lives = 5
        ..invulnerable = 5;
      scene.advancePresentation(1 / 60);
      m.update(1 / 60);
      scene.creatures.update(m, 1 / 60);
      scene.onTick();
      await tester.pump(const Duration(microseconds: 16667));
    }
  }

  int get cell =>
      tester.state<FlightJoystickState>(find.byType(FlightJoystick)).cell;

  Future<ui.Image> grab() async {
    final protection = m.invulnerable;
    m.invulnerable = 0;
    await tester.pump();
    final boundary = tester.renderObject(
      find.byKey(const ValueKey('page')),
    ) as RenderRepaintBoundary;
    late ui.Image image;
    await tester.runAsync(() async {
      image = await boundary.toImage(pixelRatio: _dpr);
    });
    m.invulnerable = protection;
    return image;
  }
}

void main() {
  testWidgets('the flight stick at rest, moving left, moving up-right fast', (
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
    final rig = await launch(tester, _size, seed: 11);
    tester.view
      ..devicePixelRatio = _dpr
      ..physicalSize = _size * _dpr;
    await tester.runAsync(() async {
      await loadReviewArt(rig);
      // let the stick's AssetImage decode
      await Future<void>.delayed(const Duration(milliseconds: 400));
    });
    await tester.pump();
    final d = _Drive(tester, rig);
    final m = rig.model;
    const dirs = FlightJoystickAtlas.directions;

    // 1. at rest: playing, the ship still at cruise
    m.startAt(sector: 1, route: 0, runSeed: 11);
    m.mode = RunMode.playing;
    await d.step(1.5);
    expect(m.shipVx, 0);
    expect(d.cell, 0, reason: 'idle: the stick rests');
    final rest = await d.grab();

    // 2. moving left at full speed
    m.moveTo(18);
    await d.step(.22);
    expect(m.shipVx, lessThan(-300));
    expect(d.cell, 1 + 2 * dirs + 4, reason: 'full tilt, left');
    final left = await d.grab();

    // 3. up-right fast: the carrier climb (flow boost) while steering right
    m.startAt(sector: 5, route: 0, runSeed: seedFor(0, 0));
    rig.scene.bossDirector.reset();
    final hull = BossHeroAtlas.hulls[BossGrammar.baked[0][0]]!;
    final belly = BossPainter.bellyOf(hull);
    final imgs = await tester.runAsync(
      () async => [
        for (final p in hull.pages) await decodeReviewImage('assets/images/$p'),
        if (belly != null)
          await decodeReviewImage('assets/images/${belly.asset}'),
      ],
    );
    rig.scene.armada.setHero(
      0,
      hull,
      imgs!.sublist(0, hull.pages.length),
      belly: belly == null ? null : imgs.last,
    );
    while (!m.boss!.fightReady) {
      await d.step(.25);
    }
    await d.step(9);
    expect(rig.scene.bossDirector.flowBoost, greaterThan(1.7));
    m.moveTo(180);
    await d.step(1);
    m.moveTo(342);
    await d.step(.2);
    expect(m.shipVx, greaterThan(300));
    expect(d.cell, 1 + 2 * dirs + 1, reason: 'full tilt, forward-right');
    final upRight = await d.grab();

    if (_contact) {
      await tester.runAsync(() async {
        final frames = [rest, left, upRight];
        const labels = ['AT REST', 'MOVING LEFT', 'UP-RIGHT FAST'];
        const gap = 12.0, scale = .5; // pages at 1 CSS px, pads at 1 device px
        final pw = _size.width * _dpr * scale, ph = _size.height * _dpr * scale;
        // the pad: the bottom 128 CSS px of the page
        const padH = 128.0 * _dpr;
        final padW = _size.width * _dpr;
        final sw = gap + 3 * (padW + gap);
        final sh = gap + ph + gap + padH + gap + 20;
        final rec = ui.PictureRecorder();
        final c = Canvas(rec);
        c.drawRect(
          Rect.fromLTWH(0, 0, sw, sh),
          Paint()..color = const Color(0xFF101018),
        );
        for (final (i, f) in frames.indexed) {
          final x = gap + i * (padW + gap);
          final full = Rect.fromLTWH(
            0,
            0,
            f.width.toDouble(),
            f.height.toDouble(),
          );
          c.drawImageRect(
            f,
            full,
            Rect.fromLTWH(x + (padW - pw) / 2, gap, pw, ph),
            Paint()..filterQuality = FilterQuality.medium,
          );
          c.drawImageRect(
            f,
            Rect.fromLTWH(0, f.height - padH, padW, padH),
            Rect.fromLTWH(x, gap + ph + gap, padW, padH),
            Paint()..filterQuality = FilterQuality.none,
          );
          final tp = TextPainter(
            text: TextSpan(
              text: labels[i],
              style: const TextStyle(
                color: Color(0xFF99B4C7),
                fontSize: 14,
                fontFamily: 'Roboto',
                letterSpacing: 1,
              ),
            ),
            textDirection: TextDirection.ltr,
          )..layout();
          tp.paint(c, Offset(x, gap + ph + gap + padH + 4));
        }
        final img = await rec.endRecording().toImage(sw.round(), sh.round());
        final png = await img.toByteData(format: ui.ImageByteFormat.png);
        final file = File('art/contact/flight-joystick-ingame.png');
        await file.parent.create(recursive: true);
        await file.writeAsBytes(png!.buffer.asUint8List());
      });
    }
    await dispose(tester);
  });
}
