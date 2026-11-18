// reduced-effects (openspec/changes/reduced-effects): the Reduced effects
// setting: Auto / On / Off, remembered per device, rendering only.
import 'dart:convert';
import 'dart:ui' as ui;

import 'package:demon_attack/comms/squad_comms.dart';
import 'package:demon_attack/game/model.dart';
import 'package:demon_attack/game/perf/frame_budget.dart';
import 'package:demon_attack/game/reduced_effects.dart';
import 'package:demon_attack/game/weather/lightning_painter.dart';
import 'package:demon_attack/game/weather/storm_layer.dart';
import 'package:demon_attack/main.dart';
import 'package:demon_attack/services/run_storage.dart';
import 'package:demon_attack/services/scores.dart';
import 'package:demon_attack/widgets/reduced_effects_toggle.dart';
import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void _reset() => ReducedEffects.set(ReducedEffectsMode.auto);

/// One presentation frame as `DemonScene.update` runs it (without Flame's
/// image loads): the tier, the budget, the presentation, the model's
/// reduced-motion flag, the fixed step.
void _frame(DemonScene scene, ArcadeModel m) {
  scene.perf.frame(1 / 60, moving: m.mode == RunMode.playing);
  scene.applyBudget();
  scene.advancePresentation(1 / 60);
  m.reducedMotion = scene.sectors.flyover.systemReducedMotion;
  m.update(1 / 60);
  scene.creatures.update(m, 1 / 60);
}

/// Everything the simulation decides, to the bit.
String _state(ArcadeModel m, List<String> events) => jsonEncode({
  'checkpoint': m.checkpoint(),
  'mode': m.mode.name,
  'level': m.level,
  'wave': m.wave,
  'score': m.score,
  'lives': m.lives,
  'clock': m.clock,
  'ship': [m.shipX, m.shipDrawY],
  'demons': [
    for (final d in m.demons) [d.x, d.y, d.dive, d.angry],
  ],
  'shots': [
    for (final s in m.shots) [s.x, s.y, s.hostile],
  ],
  'ground': [
    for (final u in m.ground.units) [u.x, u.y, u.z, u.alive],
  ],
  'flow': [m.flow.kind.name, m.flow.seconds, m.reducedMotion],
  'storm': m.stormCell?.strikes.length,
  'events': events,
});

void main() {
  setUp(_reset);
  tearDown(_reset);

  group('the setting', () {
    test('cycles Auto -> On -> Off and parses safely', () {
      expect(ReducedEffectsMode.auto.next, ReducedEffectsMode.on);
      expect(ReducedEffectsMode.on.next, ReducedEffectsMode.off);
      expect(ReducedEffectsMode.off.next, ReducedEffectsMode.auto);
      expect(ReducedEffectsMode.parse('on'), ReducedEffectsMode.on);
      expect(ReducedEffectsMode.parse(null), ReducedEffectsMode.auto);
      expect(ReducedEffectsMode.parse('lots'), ReducedEffectsMode.auto);
    });

    test('Auto follows the system; On and Off force it; idempotent', () {
      for (final mode in ReducedEffectsMode.values) {
        ReducedEffects.set(mode);
        for (final system in [false, true]) {
          final calm = ReducedEffects.calm(system);
          expect(calm, switch (mode) {
            ReducedEffectsMode.auto => system,
            ReducedEffectsMode.on => true,
            ReducedEffectsMode.off => false,
          });
          expect(ReducedEffects.calm(calm), calm, reason: 'idempotent');
        }
      }
    });

    test('On implies reduced flashing whatever the system says', () {
      ReducedEffects.set(ReducedEffectsMode.on);
      expect(FlashSafety.reduced(reducedMotion: false), isTrue);
      ReducedEffects.set(ReducedEffectsMode.auto);
      expect(FlashSafety.reduced(reducedMotion: true), isTrue);
      expect(
        FlashSafety.reduced(reducedMotion: false),
        FlashSafety.queryAsks,
        reason: 'only ?flash=low reduces it then',
      );
      ReducedEffects.set(ReducedEffectsMode.off);
      expect(
        FlashSafety.reduced(reducedMotion: true),
        FlashSafety.queryAsks,
        reason: '?flash=low holds whatever the menu says',
      );
    });

    test('the menu row names the mode, the system and low power', () {
      String row({bool system = false, bool low = false}) =>
          ReducedEffects.menuLabel(system: system, lowPower: low);
      expect(row(), 'REDUCED EFFECTS: AUTO');
      expect(row(system: true), 'REDUCED EFFECTS: AUTO (SYSTEM)');
      expect(row(low: true), 'REDUCED EFFECTS: AUTO (LOW-POWER)');
      ReducedEffects.set(ReducedEffectsMode.on);
      expect(row(system: true, low: true), 'REDUCED EFFECTS: ON');
      ReducedEffects.set(ReducedEffectsMode.off);
      expect(row(low: true), 'REDUCED EFFECTS: OFF (LOW-POWER)');
    });

    test('low power is the governor stepping down, never a forced tier', () {
      final g = PerfGovernor();
      for (var t = 0.0; g.tier != PerfTier.lite && t < 30; t += 1 / 30) {
        g.frame(1 / 30);
      }
      expect(g.tier, PerfTier.lite);
      expect(g.lowPower, isTrue);
      expect(
        ReducedEffects.mode,
        ReducedEffectsMode.auto,
        reason: 'not forced',
      );
      expect(PerfGovernor(forced: PerfTier.lite).lowPower, isFalse);
      expect(PerfGovernor().lowPower, isFalse);
    });
  });

  group('On', () {
    test('caps the eye candy at LITE and keeps the telegraphs', () {
      for (final tier in PerfTier.values) {
        final own = FrameBudget.of(tier);
        final b = ReducedEffects.budget(tier, calm: true);
        expect(b.rainScale, lessThanOrEqualTo(FrameBudget.lite.rainScale));
        expect(b.windScale, lessThanOrEqualTo(FrameBudget.lite.windScale));
        expect(b.moteScale, lessThanOrEqualTo(FrameBudget.lite.moteScale));
        expect(b.blasts, lessThanOrEqualTo(FrameBudget.lite.blasts));
        expect([b.sparks, b.blur, b.emergence], [false, false, false]);
        expect(b.fogReduced, isTrue);
        expect(b.lurkers, own.lurkers, reason: 'hatch telegraphs');
        expect(b.hatchVents, own.hatchVents, reason: 'pulse rings');
        expect(ReducedEffects.budget(tier, calm: false), same(own));
      }
    });

    test('reaches the scene: calm look, LITE cap, flash=low', () {
      final m = ArcadeModel(seed: 3)..startAt(sector: 3);
      final scene = DemonScene(m, () {});
      ReducedEffects.set(ReducedEffectsMode.on);
      _frame(scene, m);
      expect(scene.sectors.flyover.reducedMotion, isTrue);
      expect(scene.sectors.flyover.systemReducedMotion, isFalse);
      expect(m.reducedMotion, isFalse, reason: 'the model keeps the system');
      expect(scene.calmLook, isTrue);
      expect(scene.budget.rainScale, FrameBudget.lite.rainScale);
      expect(scene.rain.budget, FrameBudget.lite.rainScale);
      expect(scene.sectors.moteScale, FrameBudget.lite.moteScale);
      expect(scene.atmosphere.tierReduced, isTrue);
      expect(scene.storm.reducedFlash, isTrue);
      expect(scene.rushShake(), (0.0, 0.0));
      m.shipShock = 10;
      for (var i = 0; i < 30; i++) {
        m.clock += 1 / 60;
        expect(LightningPainter.shipFlickerOff(m), isFalse);
      }
      ReducedEffects.set(ReducedEffectsMode.off);
      _frame(scene, m);
      expect(scene.calmLook, isFalse);
      expect(scene.budget.rainScale, FrameBudget.full.rainScale);
      expect(scene.storm.reducedFlash, FlashSafety.queryAsks);
    });

    test('never changes the model: identical state either way', () {
      // Two runs of one seed through combat, a sector change and the next
      // sector's ground war; one with the setting On, one Off, every frame.
      ArcadeModel run() => ArcadeModel(seed: 1982)..startAt(sector: 2);
      final on = run(), off = run();
      final sOn = DemonScene(on, () {}), sOff = DemonScene(off, () {});
      void pilot(ArcadeModel m) {
        if (!m.combat) return;
        m.invulnerable = 2;
        final target = m.demons.isEmpty ? 180.0 : m.demons.first.x;
        m.moveBy((target - m.shipX).clamp(-4.0, 4.0));
      }

      var sectorChanges = 0;
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);
      for (var f = 0; f < 60 * 150; f++) {
        ReducedEffects.set(ReducedEffectsMode.on);
        pilot(on);
        _frame(sOn, on);
        if (f % 30 == 0) sOn.paintArena(canvas, Vector2(360, 780));
        final eOn = on.takeEvents();
        ReducedEffects.set(ReducedEffectsMode.off);
        pilot(off);
        _frame(sOff, off);
        if (f % 30 == 0) sOff.paintArena(canvas, Vector2(360, 780));
        final eOff = off.takeEvents();
        if (eOn.contains('checkpoint')) sectorChanges++;
        if (f % 10 == 0 || eOn.isNotEmpty || eOff.isNotEmpty) {
          expect(_state(on, eOn), _state(off, eOff), reason: 'frame $f');
        }
      }
      recorder.endRecording().dispose();
      expect(_state(on, const []), _state(off, const []));
      expect(sectorChanges, greaterThan(0), reason: 'the run moved on');
    });
  });

  group('widgets', () {
    Future<RunStorage> launch(WidgetTester tester, {RunStorage? keep}) async {
      final storage = keep ?? RunStorage(store: MemoryLocalStore());
      tester.view.physicalSize = const Size(360, 780);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(
          builder: (_, child) => ReducedEffectsScope(child: child!),
          home: ArcadePage(
            key: UniqueKey(),
            scoreService: ScoreService(
              client: MockClient(
                (_) async => http.Response('{"scores":[]}', 200),
              ),
            ),
            runStorage: storage,
            squadComms: SquadComms(playAudio: false, lineupSeed: 5),
          ),
        ),
      );
      await tester.pump();
      return storage;
    }

    testWidgets('the menu rows render; the choice persists', (tester) async {
      final storage = await launch(tester);
      final title = find.byKey(const ValueKey('menu-reduced-effects'));
      expect(title, findsOneWidget);
      final r = tester.getRect(title);
      expect(r.width, greaterThanOrEqualTo(36), reason: 'tap target');
      expect(r.right, lessThanOrEqualTo(360));
      expect(find.text('AUTO'), findsOneWidget);
      await tester.tap(title);
      await tester.pump();
      expect(ReducedEffects.mode, ReducedEffectsMode.on);
      expect(storage.store.read(ReducedEffects.storageKey), 'on');
      expect(find.text('ON'), findsOneWidget);
      // The pause menu's row.
      await tester.tap(find.text('START GAME  →'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      await tester.tap(find.byTooltip('Pause game'));
      await tester.pump();
      final row = find.byKey(const ValueKey('pause-reduced-effects'));
      expect(row, findsOneWidget);
      expect(find.text('REDUCED EFFECTS: ON'), findsOneWidget);
      await tester.tap(row);
      await tester.pump();
      expect(find.text('REDUCED EFFECTS: OFF'), findsOneWidget);
      expect(storage.store.read(ReducedEffects.storageKey), 'off');
      // A new page view restores it.
      ReducedEffects.mode = ReducedEffectsMode.auto;
      await launch(tester, keep: storage);
      expect(ReducedEffects.mode, ReducedEffectsMode.off);
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('Auto passes the system setting through; On and Off win', (
      tester,
    ) async {
      bool? seen;
      Widget app() => MaterialApp(
        builder: (_, child) => ReducedEffectsScope(child: child!),
        home: Builder(
          builder: (context) {
            seen = MediaQuery.disableAnimationsOf(context);
            return const SizedBox();
          },
        ),
      );
      tester.platformDispatcher.accessibilityFeaturesTestValue =
          const FakeAccessibilityFeatures(disableAnimations: true);
      addTearDown(
        tester.platformDispatcher.clearAccessibilityFeaturesTestValue,
      );
      await tester.pumpWidget(app());
      expect(seen, isTrue, reason: 'Auto: the system asks');
      final m = ArcadeModel(seed: 3)..startAt(sector: 3);
      final scene = DemonScene(m, () {});
      expect(scene.sectors.flyover.reducedMotion, isTrue);
      ReducedEffects.set(ReducedEffectsMode.off);
      await tester.pump();
      expect(seen, isFalse, reason: 'Off wins over the system');
      expect(scene.sectors.flyover.reducedMotion, isFalse);
      expect(scene.sectors.flyover.systemReducedMotion, isTrue);
      tester.platformDispatcher.accessibilityFeaturesTestValue =
          const FakeAccessibilityFeatures();
      ReducedEffects.set(ReducedEffectsMode.auto);
      await tester.pump();
      expect(seen, isFalse, reason: 'Auto: the system does not ask');
      ReducedEffects.set(ReducedEffectsMode.on);
      await tester.pump();
      expect(seen, isTrue, reason: 'On');
      expect(scene.sectors.flyover.reducedMotion, isTrue);
    });
  });
}
