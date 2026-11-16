import 'package:demon_attack/comms/comms_briefing.dart';
import 'package:demon_attack/game/model.dart';
import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fluid_transitions_test.dart' show Rig, dispose, launch;

/// bonus-briefing: the "URGENT MISSION!" card on the whole arcade page
/// (openspec/changes/bonus-levels, design "Urgent-mission card"): it opens
/// in the transition into a bonus level, heads the comms dock, ends above
/// the ship row on every phone size, can be dismissed, respects reduced
/// motion and is gone before the fight gets busy.

const _card = ValueKey('bonus-briefing-card');

/// A run in sector 2 whose next sector (3) is [level]; returns at the
/// first frame of the sector change into it.
Future<Rig> _toBonus(
  WidgetTester tester,
  Size size,
  String level, {
  String? modifier,
}) async {
  final rig = await launch(tester, size);
  await rig.step(5);
  final m = rig.model;
  m.startAt(sector: 2, route: 0);
  await rig.step(6);
  m.bonusRun.plan = BonusPlan([
    BonusSlot(0, 3, bonusLevelById(level)!),
  ], modifier == null ? null : runModifierById(modifier));
  m.lives = 4;
  rig.clearSector();
  await rig.step(.05);
  expect(m.flow.kind, FlowKind.sectorChange);
  expect(m.bonusAhead?.id, level);
  return rig;
}

/// The arena's ship row top on screen (the arena is bottom-aligned).
double _shipRowTop(WidgetTester tester) {
  final games = find.byWidgetPredicate((w) => w is GameWidget);
  final rects = [
    for (var i = 0; i < games.evaluate().length; i++)
      tester.getRect(games.at(i)),
  ]..sort((a, b) => (a.width * a.height).compareTo(b.width * b.height));
  final arena = rects.first;
  final scale = (arena.width / 360) < (arena.height / 520)
      ? arena.width / 360
      : arena.height / 520;
  return arena.top +
      arena.height -
      520 * scale +
      (ArcadeModel.shipY - 26) * scale;
}

dynamic _briefing(Rig rig) => rig.transitions.briefing;

void main() {
  const phones = [
    Size(360, 780),
    Size(390, 844),
    Size(412, 915),
    Size(740, 360), // a phone held sideways: the tight card
  ];
  for (final size in phones) {
    for (final level in bonusLevels) {
      testWidgets('${level.id} at ${size.width.round()}x${size.height.round()}'
          ': the card opens, stays above the ship row, then goes', (
        tester,
      ) async {
        final rig = await _toBonus(
          tester,
          size,
          level.id,
          modifier: 'noShield',
        );
        final m = rig.model;
        var seen = false, hiddenTurns = true;
        double? combatAt;
        for (var i = 0; i < 260; i++) {
          await rig.step(.1);
          if (m.combat) combatAt ??= rig.comms.now;
          final card = find.byKey(_card);
          if (card.evaluate().isEmpty) continue;
          seen = true;
          final rect = tester.getRect(card);
          expect(
            rect.bottom,
            lessThanOrEqualTo(_shipRowTop(tester)),
            reason: 'over the ship row at step $i',
          );
          expect(rect.left, greaterThanOrEqualTo(0));
          expect(rect.right, lessThanOrEqualTo(size.width));
          expect(find.textContaining(BonusBriefing.title), findsOneWidget);
          expect(find.text(level.label), findsOneWidget);
          // The card's own turns never show twice (dock and card).
          final b = _briefing(rig) as BonusBriefing;
          for (final t in b.turns) {
            if (find
                .byKey(ValueKey('comms-strip-${t.line.id}'))
                .evaluate()
                .isNotEmpty) {
              hiddenTurns = false;
            }
          }
          if (combatAt != null) {
            expect(
              rig.comms.now - combatAt,
              lessThan(BonusBriefing.combatGrace + BonusBriefing.fade + .2),
              reason: 'gone before the fight gets busy',
            );
          }
        }
        expect(seen, isTrue);
        expect(hiddenTurns, isTrue);
        expect(m.combat, isTrue);
        expect(m.bonus?.id, level.id);
        expect(find.byKey(_card), findsNothing);
        expect(tester.takeException(), isNull);
        await dispose(tester);
      });
    }
  }

  testWidgets('the card shows the rule, the run rule and the chatter', (
    tester,
  ) async {
    final rig = await _toBonus(
      tester,
      const Size(390, 844),
      'stormfront',
      modifier: 'noShield',
    );
    for (var i = 0; i < 80; i++) {
      await rig.step(.1);
      final b = _briefing(rig) as BonusBriefing?;
      if (b != null && b.spoken().length >= 2) break;
    }
    final b = _briefing(rig) as BonusBriefing;
    expect(find.byKey(_card), findsOneWidget);
    expect(find.byKey(const ValueKey('bonus-briefing-brief')), findsOneWidget);
    expect(find.text(stormfront.brief), findsOneWidget);
    expect(find.byKey(const ValueKey('bonus-briefing-rule')), findsOneWidget);
    expect(
      find.byKey(const ValueKey('bonus-briefing-portrait')),
      findsOneWidget,
    );
    // The written lines themselves, not a borrowed clip's subtitle.
    for (final t in b.spoken()) {
      expect(
        find.byKey(ValueKey('bonus-briefing-turn-${t.line.id}')),
        findsOneWidget,
      );
      expect(t.line.silent, isTrue);
    }
    await dispose(tester);
  });

  testWidgets('wide screens show the card over the arena', (tester) async {
    final rig = await _toBonus(tester, const Size(1440, 900), 'supplyRun');
    var seen = false;
    for (var i = 0; i < 60 && !seen; i++) {
      await rig.step(.1);
      seen = find.byKey(_card).evaluate().isNotEmpty;
    }
    expect(seen, isTrue);
    expect(
      tester.getRect(find.byKey(_card)).bottom,
      lessThanOrEqualTo(_shipRowTop(tester)),
    );
    await dispose(tester);
  });

  testWidgets('a tap on the card dismisses it, not the transition', (
    tester,
  ) async {
    final rig = await _toBonus(tester, const Size(360, 780), 'supplyRun');
    final m = rig.model;
    for (var i = 0; i < 140; i++) {
      await rig.step(.1);
      final b = _briefing(rig) as BonusBriefing?;
      if (b != null && b.spoken().isNotEmpty) break;
    }
    final b = _briefing(rig) as BonusBriefing;
    final first = b.turns.first;
    expect(first.started, isTrue);
    final rest = [for (final t in b.turns.skip(1)) t.line.id];
    final phase = m.mode;
    await tester.tap(find.byKey(const ValueKey('bonus-briefing-dismiss')));
    await rig.step(.05);
    expect(b.dismissed, isTrue);
    expect(m.skipPending, isFalse, reason: 'the tap was the card\'s');
    expect(m.mode, phase);
    await rig.step(.5);
    expect(find.byKey(_card), findsNothing);
    // The turn on air finishes (in the dock); the rest never plays.
    expect(first.interrupted, isFalse);
    await rig.step(12);
    for (final id in rest) {
      expect(rig.comms.director.history, isNot(contains(id)));
    }
    expect(tester.takeException(), isNull);
    await dispose(tester);
  });

  testWidgets('Space closes the card once nothing else is to skip', (
    tester,
  ) async {
    final rig = await _toBonus(tester, const Size(390, 844), 'stormfront');
    final m = rig.model;
    BonusBriefing? b;
    for (var i = 0; i < 200; i++) {
      await rig.step(.1);
      b = _briefing(rig) as BonusBriefing?;
      if (b != null && b.open && m.mode == RunMode.transition) break;
    }
    expect(b?.open, isTrue);
    await tester.sendKeyEvent(LogicalKeyboardKey.space);
    await rig.step(.05);
    expect(b!.dismissed, isTrue);
    await dispose(tester);
  });

  // --- mission-medals: the card holds the level's start until read.
  testWidgets('the card holds the start until read, then the level runs', (
    tester,
  ) async {
    final rig = await _toBonus(tester, const Size(360, 780), 'supplyRun');
    final m = rig.model;
    var heldFor = 0.0, prompt = false, pictogram = false;
    for (var i = 0; i < 400 && !m.combat; i++) {
      final held = rig.scene.holdModel();
      await rig.step(.1, hold: true);
      if (held) {
        heldFor += .1;
        expect(m.mode, isNot(RunMode.playing));
      }
      prompt |= find
          .byKey(const ValueKey('bonus-briefing-start'))
          .evaluate()
          .isNotEmpty;
      pictogram |= find
          .byKey(const ValueKey('bonus-briefing-howto'))
          .evaluate()
          .isNotEmpty;
    }
    final b = _briefing(rig) as BonusBriefing?;
    expect(m.combat, isTrue);
    expect(prompt, isTrue, reason: 'TAP TO START while holding');
    expect(pictogram, isTrue);
    expect(heldFor, lessThanOrEqualTo(BonusBriefing.maxHold + .2));
    expect(b == null || b.read(rig.comms.director, rig.comms.now), isTrue);
    expect(tester.takeException(), isNull);
    await dispose(tester);
  });

  testWidgets('a tap on the held card starts the level', (tester) async {
    final rig = await _toBonus(tester, const Size(360, 780), 'supplyRun');
    final m = rig.model;
    var held = false;
    for (var i = 0; i < 400 && !held; i++) {
      await rig.step(.1, hold: true);
      held = rig.scene.holdModel();
    }
    expect(held, isTrue);
    await tester.tap(find.byKey(_card));
    await rig.step(.05, hold: true);
    expect(rig.scene.holdModel(), isFalse);
    await rig.step(1, hold: true);
    expect(m.combat, isTrue);
    await dispose(tester);
  });

  testWidgets('reduced motion: the card appears and goes without a fade', (
    tester,
  ) async {
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
    final rig = await _toBonus(tester, const Size(360, 780), 'supplyRun');
    double? first;
    for (var i = 0; i < 120 && first == null; i++) {
      await rig.step(1 / 30);
      final card = find.byKey(_card);
      if (card.evaluate().isNotEmpty) {
        first = (tester.widget(card) as Opacity).opacity;
      }
    }
    expect(first, 1.0, reason: 'no fade in');
    final b = _briefing(rig) as BonusBriefing;
    b.dismiss(rig.comms.director, rig.comms.now);
    await rig.step(1 / 30);
    expect(find.byKey(_card), findsNothing, reason: 'no fade out');
    await dispose(tester);
  });
}
