import 'dart:io';
import 'dart:ui' as ui;

import 'package:demon_attack/comms/comms_bank.dart';
import 'package:demon_attack/comms/comms_view.dart' show CommsPortraitAtlas;
import 'package:demon_attack/comms/squad_comms.dart';
import 'package:demon_attack/game/interlude.dart';
import 'package:demon_attack/game/model.dart';
import 'package:demon_attack/main.dart';
import 'package:demon_attack/services/run_storage.dart';
import 'package:demon_attack/services/scores.dart';
import 'package:demon_attack/widgets/interlude_card.dart';
import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

/// The travel leg plus the arrival that follows it.
const releaseWindow = 4 + ArcadeModel.storyReadingTime + 4.5;

InterludeContext ctx(int i, {double window = releaseWindow}) =>
    InterludeContext(
      difficulty: Difficulty.normal,
      level: 1 + i % 4,
      route: i ~/ 5,
      window: window,
      flawless: i % 3 == 0,
      struggling: i % 5 == 4,
    );

final _bankIds = {
  for (final bank in [commsHumanTriggers, commsDemonTriggers])
    for (final spec in bank.values)
      for (final line in spec.lines) line.id,
};

double _wall = 0;

/// Review frames go to this directory with --dart-define=FLUID_RENDER=/abs/dir
/// (never into the checkout); FLUID_FONTS names a folder holding
/// Roboto-Regular.ttf and Roboto-Bold.ttf for real glyphs.
const renderDir = String.fromEnvironment('FLUID_RENDER');
const _fontDir = String.fromEnvironment('FLUID_FONTS');
bool _fontsLoaded = false;

Future<void> snap(WidgetTester tester, String name) async {
  if (renderDir.isEmpty) return;
  if (!_fontsLoaded && _fontDir.isNotEmpty) {
    _fontsLoaded = true;
    await tester.runAsync(() async {
      final roboto = FontLoader('Roboto');
      for (final file in ['Roboto-Regular.ttf', 'Roboto-Bold.ttf']) {
        final bytes = File('$_fontDir/$file').readAsBytesSync();
        roboto.addFont(Future.value(ByteData.sublistView(bytes)));
      }
      await roboto.load();
    });
    await tester.pump();
  }
  final boundary = tester.renderObject(
    find.byKey(const ValueKey('page')),
  ) as RenderRepaintBoundary;
  await tester.runAsync(() async {
    final image = await boundary.toImage();
    final png = await image.toByteData(format: ui.ImageByteFormat.png);
    final file = File('$renderDir/$name.png');
    await file.parent.create(recursive: true);
    await file.writeAsBytes(png!.buffer.asUint8List());
    image.dispose();
  });
}

class Rig {
  Rig(this.tester, this.comms, this.scene, this.state);
  final WidgetTester tester;
  final SquadComms comms;
  final DemonScene scene;
  final dynamic state;
  ArcadeModel get model => scene.model;
  dynamic get transitions => state.transitions;

  /// Advances the simulation and the comms clock together.
  Future<void> step(double seconds, {double dt = 1 / 30}) async {
    for (var t = 0.0; t < seconds - 1e-9; t += dt) {
      _wall += dt;
      model.update(dt);
      scene.onTick();
    }
    await tester.pump();
  }

  /// Ends the current sector so the release (clear, travel, arrival) runs.
  void clearSector() {
    model.demons.clear();
    model.mode = RunMode.levelClear;
    model.transitionDuration = 4 + ArcadeModel.storyReadingTime;
    model.transitionLeft = model.transitionDuration;
    model.events.add('levelclear');
  }

  int primaries() =>
      find.byKey(const ValueKey('interlude-card')).evaluate().length +
      find.byKey(const ValueKey('story-card')).evaluate().length +
      find.byKey(const ValueKey('boss-alert')).evaluate().length;
}

Future<Rig> launch(WidgetTester tester, Size size, {int seed = 7}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  _wall = 0;
  final comms = SquadComms(
    playAudio: false,
    lineupSeed: 5,
    wallClock: () => _wall,
  );
  await tester.runAsync(() => CommsPortraitAtlas.instance.load());
  await tester.pumpWidget(
    MaterialApp(
      home: RepaintBoundary(
        key: const ValueKey('page'),
        child: ArcadePage(
          scoreService: ScoreService(
            client: MockClient(
              (_) async => http.Response('{"scores":[]}', 200),
            ),
          ),
          runStorage: RunStorage(store: MemoryLocalStore()),
          squadComms: comms,
          interludeSeed: seed,
        ),
      ),
    ),
  );
  await tester.pump();
  await tester.tap(find.text('START GAME  →'), warnIfMissed: false);
  await tester.pump();
  final scene =
      tester
              .widgetList<GameWidget>(
                find.byWidgetPredicate((w) => w is GameWidget),
              )
              .first
              .game
          as DemonScene;
  return Rig(tester, comms, scene, tester.state(find.byType(ArcadePage)));
}

Future<void> dispose(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox());
  await tester.pump();
}

void main() {
  group('planner', () {
    test('opens with a tip, then tips and radio cards alternate', () {
      final planner = InterludePlanner(seed: 3);
      final kinds = [for (var i = 0; i < 12; i++) planner.plan(ctx(i))!.kind];
      for (var i = 0; i < kinds.length; i++) {
        expect(
          kinds[i],
          i.isEven ? InterludeKind.tip : InterludeKind.radio,
          reason: 'interlude $i',
        );
      }
    });

    test('is seeded and never shows the same item twice in a row', () {
      List<String> run(int seed) {
        final planner = InterludePlanner(seed: seed);
        return [for (var i = 0; i < 40; i++) planner.plan(ctx(i))!.id];
      }

      expect(run(11), run(11));
      expect(run(11), isNot(run(12)));
      for (final seed in [1, 2, 3, 11, 99]) {
        final ids = run(seed);
        for (var i = 1; i < ids.length; i++) {
          expect(ids[i], isNot(ids[i - 1]), reason: 'seed $seed at $i');
        }
        // Radio cards never repeat a line within the last few cards either.
        final radio = [for (var i = 1; i < ids.length; i += 2) ids[i]];
        for (var i = 1; i < radio.length; i++) {
          expect(
            radio.sublist(0, i).reversed.take(3),
            isNot(contains(radio[i])),
          );
        }
      }
    });

    test('radio cards play recorded bank lines of several kinds', () {
      final planner = InterludePlanner(seed: 5);
      final categories = <RadioCategory>{};
      for (var i = 0; i < 60; i++) {
        final plan = planner.plan(ctx(i))!;
        if (plan.kind != InterludeKind.radio) continue;
        expect(_bankIds, contains(plan.radio!.line.id));
        expect(plan.text, isNotEmpty);
        categories.add(plan.radio!.category);
      }
      expect(categories.length, greaterThanOrEqualTo(3), reason: '$categories');
    });

    test('every card can be read (and heard) inside its window', () {
      for (final window in [releaseWindow, 4 + 1 / 3, 4.5]) {
        final planner = InterludePlanner(seed: 21);
        for (var i = 0; i < 30; i++) {
          final plan = planner.plan(ctx(i, window: window));
          expect(plan, isNotNull, reason: 'window $window, card $i');
          if (plan!.kind == InterludeKind.tip) {
            expect(
              readSeconds(plan.text) + InterludeTiming.fade,
              lessThanOrEqualTo(window),
            );
          } else {
            expect(
              plan.radio!.needs +
                  InterludeTiming.adoptWait +
                  2 * InterludeTiming.fade,
              lessThanOrEqualTo(window),
            );
          }
        }
      }
      // The long release shows the whole tip, detail included.
      final planner = InterludePlanner(seed: 1);
      expect(planner.plan(ctx(0))!.showDetail, isTrue);
    });

    test('no card when the transition leaves no time to read one', () {
      expect(InterludePlanner(seed: 1).plan(ctx(0, window: 1.5)), isNull);
    });

    test('reading time grows with the text', () {
      expect(readSeconds('One two three four'), closeTo(2.2, 1e-9));
      expect(readSeconds('a ' * 40), greaterThan(readSeconds('a ' * 10) + 7));
    });
  });

  group('arcade page', () {
    testWidgets('one primary message at a time through a whole release', (
      tester,
    ) async {
      final rig = await launch(tester, const Size(390, 844));
      // The opening briefing is a silent tip.
      expect(find.text('TACTICAL BRIEFING'), findsOneWidget);
      expect(rig.primaries(), 1);
      // Music only: the director holds chatter (warnings still sound); the
      // player's voice setting is untouched.
      expect(
        rig.comms.director.hushed,
        isTrue,
        reason: 'music only under a tip',
      );
      expect(rig.comms.voiceOn, isTrue);
      await rig.step(5);
      expect(rig.model.mode, RunMode.playing);
      expect(rig.comms.director.hushed, isFalse, reason: 'the radio is back');
      expect(rig.comms.voiceOn, isTrue);
      expect(rig.primaries(), 0);

      rig.clearSector();
      final seen = <String>{};
      var frames = 0;
      while (rig.model.mode != RunMode.playing && frames < 600) {
        await rig.step(1 / 10, dt: 1 / 30);
        frames++;
        expect(
          rig.primaries(),
          lessThanOrEqualTo(1),
          reason: '${rig.model.mode}',
        );
        // The full-size comms overlay never doubles the card.
        expect(
          find.byKey(const ValueKey('comms-hud-stack')).evaluate().isEmpty ||
              find.byKey(const ValueKey('interlude-card')).evaluate().isEmpty,
          isTrue,
        );
        if (rig.model.cinematic) {
          expect(
            find.byKey(const ValueKey('transition-strip')),
            findsOneWidget,
          );
        }
        if (find.byKey(const ValueKey('story-card')).evaluate().isNotEmpty) {
          seen.add('story-${rig.model.mode.name}');
        }
        if (find
            .byKey(const ValueKey('interlude-card'))
            .evaluate()
            .isNotEmpty) {
          seen.add('card-${rig.model.mode.name}');
        }
      }
      expect(rig.model.mode, RunMode.playing);
      expect(seen, containsAll(['story-levelClear', 'card-travel']));
      // The second interlude of the run is the radio card.
      expect(find.text('TACTICAL BRIEFING'), findsNothing);
      expect(tester.takeException(), isNull);
      await dispose(tester);
    });

    testWidgets('a wave change shows only the slim strip', (tester) async {
      final rig = await launch(tester, const Size(390, 844));
      await rig.step(5);
      rig.model.wave = 2;
      rig.model.mode = RunMode.transition;
      rig.model.transitionDuration = 1.4 + ArcadeModel.storyReadingTime;
      rig.model.transitionLeft = rig.model.transitionDuration;
      await rig.step(.5);
      expect(rig.primaries(), 0);
      expect(find.byKey(const ValueKey('transition-strip')), findsOneWidget);
      expect(find.textContaining('WAVE 2/'), findsOneWidget);
      await dispose(tester);
    });

    testWidgets('the radio card stays up until its line is read', (
      tester,
    ) async {
      final rig = await launch(tester, const Size(1440, 900));
      await rig.step(5);
      rig.clearSector();
      while (rig.model.mode != RunMode.travel) {
        await rig.step(.1);
      }
      double? shownFor, needs;
      var t = 0.0;
      while (rig.model.mode != RunMode.playing && t < 20) {
        await rig.step(.1);
        t += .1;
        if (rig.transitions.showingCard as bool) {
          final message = rig.transitions.shown;
          final text = (message.line.text ?? message.line.gloss) as String;
          needs = [
            message.line.duration + InterludeTiming.hold,
            readSeconds(text),
          ].reduce((a, b) => a > b ? a : b) as double;
          final (elapsed, _) = rig.transitions.cardTime(rig.model);
          shownFor = elapsed as double;
        }
      }
      expect(needs, isNotNull, reason: 'a radio card was shown');
      expect(shownFor! + .2, greaterThanOrEqualTo(needs!));
      expect(tester.takeException(), isNull);
      await dispose(tester);
    });

    testWidgets('tap skips the card; the arrival then starts the fight', (
      tester,
    ) async {
      final rig = await launch(tester, const Size(390, 844));
      await rig.step(.6);
      final card = find.byKey(const ValueKey('interlude-card'));
      expect(card, findsOneWidget);
      expect(find.text('TAP TO SKIP ▸'), findsOneWidget);
      await tester.tap(card);
      await tester.pump();
      expect(card, findsNothing);
      expect(rig.comms.voiceOn, isTrue);
      expect(rig.model.transitionLeft, 0);
      await rig.step(1 / 30);
      expect(rig.model.mode, RunMode.playing);
      await dispose(tester);
    });

    testWidgets('a skipped travel card keeps the flow and does not return', (
      tester,
    ) async {
      final rig = await launch(tester, const Size(390, 844));
      await rig.step(5);
      rig.clearSector();
      while (rig.model.mode != RunMode.travel) {
        await rig.step(.1);
      }
      await rig.step(1.6);
      final card = find.byKey(const ValueKey('interlude-card'));
      expect(card, findsOneWidget);
      final left = rig.model.transitionLeft;
      await tester.tap(card);
      await tester.pump();
      expect(card, findsNothing);
      expect(rig.model.mode, RunMode.travel);
      expect(rig.model.transitionLeft, closeTo(left, 1e-9));
      await rig.step(2);
      expect(card, findsNothing);
      expect(rig.primaries(), 0);
      await dispose(tester);
    });

    for (final size in const [
      Size(390, 844),
      Size(900, 900),
      Size(1440, 900),
    ]) {
      testWidgets('tip and radio cards fit at ${size.width.toInt()} px', (
        tester,
      ) async {
        final rig = await launch(tester, size);
        Future<void> check(String kind) async {
          final card = find.byKey(const ValueKey('interlude-card'));
          expect(card, findsOneWidget, reason: kind);
          final rect = tester.getRect(card);
          expect(rect.left, greaterThanOrEqualTo(0));
          expect(rect.right, lessThanOrEqualTo(size.width));
          expect(rect.width, lessThanOrEqualTo(460.01));
          // Desktop-sized in the cabinet; full width on a phone.
          expect(
            rect.width,
            greaterThanOrEqualTo(size.width < 500 ? 360 : 440),
          );
          final hud = tester.getRect(find.byKey(const ValueKey('hud-score')));
          expect(rect.overlaps(hud), isFalse, reason: kind);
          expect(tester.takeException(), isNull, reason: kind);
          await snap(tester, '$kind-${size.width.toInt()}');
        }

        await rig.step(1);
        await check('tip');
        await rig.step(4.5);
        rig.clearSector();
        while (!(rig.transitions.showingCard as bool) &&
            rig.model.mode != RunMode.playing) {
          await rig.step(.1);
        }
        await rig.step(1);
        expect(
          find.byWidgetPredicate((w) => w is RadioInterludeCard),
          findsOneWidget,
        );
        await check('radio');
        await dispose(tester);
      });
    }
  });
}
