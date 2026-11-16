@Tags(['review'])
library;

// mission-medals review sheets. Off by default; tagged `review`:
// `flutter test --concurrency=1 --run-skipped --tags review
// test/mission_medals_review_test.dart` (through the test lock) writes
// - art/contact/mission-medals-supply-run.png: the arcade page at 360 x 780
//   through the transition into Supply Run and its first crates: the card
//   with its one-sentence brief and pictogram, the card holding the start
//   (TAP TO START), the cues in the level (bracketed and cracked crates,
//   cargo on its landing marker, the magnet's pull, the tally), and the
//   feedback (a crate's burst, a catch, double score's coins);
// - art/contact/mission-medals-screens.png: the medal screen (initials entry
//   with the run record) and the board with the final-score card, 360 wide,
//   with mission medals instead of modifier text.
// `MISSION_MEDALS_FONTS` names a folder with Roboto-Regular.ttf and
// Roboto-Bold.ttf for real glyphs.
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:demon_attack/comms/comms_briefing.dart';
import 'package:demon_attack/game/ground_atlas.dart';
import 'package:demon_attack/game/ground_atmosphere.dart';
import 'package:demon_attack/game/ground_atmosphere_atlas.dart';
import 'package:demon_attack/game/ground_blocks_painter.dart';
import 'package:demon_attack/game/ground_troops_atlas.dart';
import 'package:demon_attack/game/model.dart';
import 'package:demon_attack/game/sentinel_silhouette_atlas.dart';
import 'package:demon_attack/main.dart';
import 'package:demon_attack/services/scores.dart';
import 'package:demon_attack/widgets/mission_medal.dart';
import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'fluid_transitions_test.dart' show Rig, dispose, launch;

const _fonts = String.fromEnvironment(
  'MISSION_MEDALS_FONTS',
  defaultValue: '/home/forge/.cache/tillandsias-project/tmp/fonts',
);

Future<void> _loadFonts() async {
  final dir = Directory(_fonts);
  if (!dir.existsSync()) return;
  for (final family in ['Roboto', 'monospace']) {
    final loader = FontLoader(family);
    for (final f in ['Roboto-Regular.ttf', 'Roboto-Bold.ttf']) {
      final bytes = File('${dir.path}/$f').readAsBytesSync();
      loader.addFont(Future.value(ByteData.sublistView(bytes)));
    }
    await loader.load();
  }
}

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

Future<ui.Image> _grab(WidgetTester tester, String key) async {
  await tester.pump();
  final boundary =
      tester.renderObject(find.byKey(ValueKey(key))) as RenderRepaintBoundary;
  return (await tester.runAsync(() => boundary.toImage()))!;
}

Future<void> _sheet(String path, List<ui.Image> frames) async {
  const gap = 8.0;
  final w = frames.fold<double>(gap, (a, f) => a + f.width + gap);
  var h = 0.0;
  for (final f in frames) {
    if (f.height > h) h = f.height.toDouble();
  }
  final rec = ui.PictureRecorder();
  final c = Canvas(rec);
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
  final png = await sheet.toByteData(format: ui.ImageByteFormat.png);
  File(path)
    ..createSync(recursive: true)
    ..writeAsBytesSync(png!.buffer.asUint8List());
  sheet.dispose();
}

void main() {
  testWidgets('mission-medals Supply Run strip', (tester) async {
    await tester.runAsync(_loadFonts);
    final rig = await launch(tester, const Size(360, 780));
    await tester.runAsync(() => _loadArt(rig));
    await rig.step(5);
    final m = rig.model;
    m.startAt(sector: 2, route: 0);
    await rig.step(6);
    m.bonusRun.plan = BonusPlan([BonusSlot(0, 3, supplyRun)], null);
    m.lives = 3;
    rig.clearSector();
    final frames = <ui.Image>[];
    // 1. The card in the flight: the brief and the pictogram.
    for (var i = 0; i < 400; i++) {
      await rig.step(.05, hold: true);
      final b = rig.transitions.briefing as BonusBriefing?;
      if (b != null &&
          b.open &&
          b.spoken().isNotEmpty &&
          rig.comms.now - b.spoken().first.startedAt > .8) {
        break;
      }
    }
    frames.add(await _grab(tester, 'page'));
    // 2. The card holding the start.
    var held = 0;
    for (var i = 0; i < 400 && held < 30; i++) {
      await rig.step(.05, hold: true);
      if (rig.scene.holdModel()) held++;
    }
    expect(held, greaterThan(0));
    frames.add(await _grab(tester, 'page'));
    // 3. In the level: wait for crates, then stage the cues.
    for (var i = 0; i < 600 && !(m.combat && m.supplyCrates.length >= 2); i++) {
      m.invulnerable = 5;
      await rig.step(.05, hold: true);
    }
    expect(m.supplyCrates.length, greaterThanOrEqualTo(2));
    final crates = m.supplyCrates;
    crates[0].hp = 3;
    crates[1].hp = 1; // two cracks
    m.moveTo(120);
    m.pickups.add(Pickup(200, 300, Power.spread));
    m.collectBonus(salvageMagnet);
    m.pickups.add(Pickup(160, 380, Power.rapid));
    final cues = m.bonusMechanic! as SupplyRunCues;
    cues.opened = 4;
    await rig.step(1 / 30);
    frames.add(await _grab(tester, 'page'));
    // 4. Feedback: a crate bursts, cargo is caught, double score's coins.
    final pop = crates.first;
    pop.hp = 0;
    m.supplyCrates.remove(pop);
    m.collectBonus(doubleScore);
    m.pickups.add(Pickup(m.shipX, ArcadeModel.shipY - 4, Power.shield));
    for (var i = 0; i < 4; i++) {
      m.invulnerable = 5;
      await rig.step(1 / 30);
    }
    frames.add(await _grab(tester, 'page'));
    await tester.runAsync(
      () => _sheet('art/contact/mission-medals-supply-run.png', frames),
    );
    for (final f in frames) {
      f.dispose();
    }
    await dispose(tester);
  });

  testWidgets('mission-medals medal screen and scoreboard', (tester) async {
    await tester.runAsync(_loadFonts);
    await tester.runAsync(() => MissionMedalSheet.load());
    expect(MissionMedalSheet.image.value, isNotNull, reason: 'atlas decoded');
    tester.view.physicalSize = const Size(360, 780);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final frames = <ui.Image>[];
    final mods = <List<String>>[
      ['supplyRun'],
      [],
      ['stormfront', 'noShield'],
      ['supplyRun', 'heavyOrdnance'],
      [],
      ['spreadOnly'],
      ['stormfront'],
      [],
      ['supplyRun', 'someFutureMission'],
      [],
    ];
    final board = [
      for (var i = 0; i < 10; i++)
        {
          'initials': [
            'ACE',
            'K9X',
            'ZED',
            'RUN',
            'MAX',
            'JET',
            'OWL',
            'B52',
            'FOX',
            'NOV',
          ][i],
          'score': 980000 - i * 61000,
          'medals': i < 2 ? 5 : 4 - i % 4,
          'activeMilliseconds': 2400000 - i * 90000,
          if (i == 0) 'remainingLives': 3,
          if (mods[i].isNotEmpty) 'modifiers': mods[i],
          if (i < 8)
            'playedOn': '2026-11-${(16 - i).toString().padLeft(2, '0')}',
        },
    ];
    for (final qualifies in [true, false]) {
      final service = ScoreService(
        endpoint: Uri.parse('https://scores.example/api/scores'),
        client: MockClient(
          (r) async => http.Response(
            jsonEncode({'scores': qualifies ? board.take(4).toList() : board}),
            200,
          ),
        ),
      );
      await tester.pumpWidget(
        RepaintBoundary(
          key: const ValueKey('sheet'),
          child: MaterialApp(home: ArcadePage(scoreService: service)),
        ),
      );
      await tester.pump();
      await tester.tap(find.text('START GAME  →'));
      await tester.pump();
      final scene =
          tester
                  .widgetList<GameWidget>(
                    find.byWidgetPredicate((w) => w is GameWidget),
                  )
                  .first
                  .game
              as DemonScene;
      final model = scene.model;
      // A run that met Supply Run under Heavy Ordnance.
      expect(
        model.restoreCheckpoint({
          'difficulty': 'normal',
          'routeIndex': 2,
          'sector': 3,
          'wave': 1,
          'score': qualifies ? 412350 : 9850,
          'lives': 1,
          'medals': 2,
          'kills': 600,
          'activeMilliseconds': 2468000,
        }),
        isTrue,
      );
      model.bonusRun.plan = BonusPlan([
        BonusSlot(0, 3, supplyRun),
      ], runModifierById('heavyOrdnance'));
      expect(model.runModifierIds, ['supplyRun', 'heavyOrdnance']);
      model.mode = RunMode.gameOver;
      scene.onTick();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump(const Duration(seconds: 1));
      expect(find.byKey(const ValueKey('run-record')), findsOneWidget);
      expect(find.text('SUPPLY RUN'), findsNothing);
      expect(find.text('HEAVY ORDNANCE'), findsNothing);
      if (!qualifies) {
        await tester.drag(
          find.byKey(const ValueKey('landing-scroll')),
          const Offset(0, -900),
        );
        await tester.pump();
      }
      expect(tester.takeException(), isNull);
      frames.add(await _grab(tester, 'sheet'));
      await tester.pumpWidget(const SizedBox());
      await tester.pump();
    }
    await tester.runAsync(
      () => _sheet('art/contact/mission-medals-screens.png', frames),
    );
    for (final f in frames) {
      f.dispose();
    }
  });
}
