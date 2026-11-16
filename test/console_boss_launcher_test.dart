import 'package:demon_attack/game/model.dart';
import 'package:demon_attack/main.dart';
import 'package:demon_attack/widgets/dev_console.dart';
import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Operator C2 (round 3b): the /console boss launcher. The carrier's fight
/// straight away (approach and launch waves skipped), its approach, or its
/// fight with the decay fast-forwarded through shield → armour → modules →
/// collapse. Debug only: a ranked run never decays on its own.
void main() {
  test('FIGHT: the carrier is in range at once, no launch waves', () {
    for (var route = 0; route < 5; route++) {
      final m = ArcadeModel(seed: 3);
      ConsoleStart.boss(route: route).applyTo(m);
      expect(m.boss, isNotNull);
      expect(m.boss!.fightReady, isTrue);
      expect(m.looming, isFalse);
      expect(m.cycle, route);
      expect(m.consoleDecay, isFalse);
      expect(m.ranked, isFalse);
    }
  });

  test('APPROACH: the launch waves first', () {
    final m = ArcadeModel(seed: 3);
    ConsoleStart.boss(route: 1, carrier: ConsoleCarrier.approach).applyTo(m);
    expect(m.boss, isNull);
    expect(m.looming, isTrue);
    expect(m.wave, 1);
  });

  test('FAST DECAY: shield, armour, modules, core, collapse, in order', () {
    for (final route in [0, 4]) {
      final m = ArcadeModel(seed: 5);
      ConsoleStart.boss(route: route, carrier: ConsoleCarrier.decay).applyTo(m);
      expect(m.consoleDecay, isTrue);
      final names = <String>[];
      var t = 0.0;
      for (var f = 0; f < 60 * 120 && m.mode != RunMode.victory; f++) {
        m.invulnerable = 5;
        m.lives = 3;
        m.update(1 / 60);
        if (m.combat) t += 1 / 60;
        names.addAll(m.takeGameEvents().map((e) => e.name));
      }
      expect(m.mode, RunMode.victory, reason: 'route $route');
      // One step every 2.5 s: 2 shield steps and 2 per form.
      expect(t, lessThan(ArcadeModel.consoleDecaySeconds * (2 + 2 * 4) + 6));
      int at(String n) => names.indexOf(n);
      for (final n in [
        GameEventNames.bossShieldFailing,
        GameEventNames.bossShieldDown,
        GameEventNames.bossArmourShed,
        GameEventNames.bossModuleLost,
        GameEventNames.bossCoreExposed,
        GameEventNames.bossCollapseStart,
      ]) {
        expect(at(n), greaterThanOrEqualTo(0), reason: '$n, route $route');
      }
      expect(at(GameEventNames.bossShieldFailing),
          lessThan(at(GameEventNames.bossShieldDown)));
      expect(at(GameEventNames.bossShieldDown),
          lessThan(at(GameEventNames.bossArmourShed)));
      expect(at(GameEventNames.bossModuleLost),
          lessThan(at(GameEventNames.bossCoreExposed)));
      expect(at(GameEventNames.bossCoreExposed),
          lessThan(at(GameEventNames.bossCollapseStart)));
    }
  });

  test('debug only: a ranked run never fast-forwards, a new run clears it', () {
    final m = ArcadeModel(seed: 2)..startAt(sector: 5, route: 0);
    expect(m.ranked, isTrue);
    m.consoleDecay = true; // even if something set it
    final b = m.boss!;
    final shield = b.shield;
    for (var f = 0; f < 60 * 10; f++) {
      m.invulnerable = 5;
      m.update(1 / 60);
    }
    m.consoleDecayNow();
    expect(b.shield, greaterThanOrEqualTo(shield - 60),
        reason: 'only the fight itself wore it');
    expect(m.boss, isNotNull);
    final c = ArcadeModel(seed: 2);
    ConsoleStart.boss(carrier: ConsoleCarrier.decay).applyTo(c);
    expect(c.consoleDecay, isTrue);
    c.start();
    expect(c.consoleDecay, isFalse);
  });

  testWidgets('the console CARRIER row picks how BOSS starts', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(const DemonAttackApp(initialRoute: '/console'));
    await tester.pump();
    expect(find.byKey(const ValueKey('console-carrier-0')), findsNothing);
    expect(find.byKey(const ValueKey('console-bonus-0')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('console-sector-4')));
    await tester.pump();
    expect(find.byKey(const ValueKey('console-bonus-0')), findsNothing);
    for (final c in ConsoleCarrier.values) {
      expect(find.byKey(ValueKey('console-carrier-${c.index}')), findsOneWidget);
    }
    final decay = find.byKey(const ValueKey('console-carrier-2'));
    await tester.ensureVisible(decay);
    await tester.tap(decay);
    await tester.pump();
    final boss = find.byKey(const ValueKey('console-boss'));
    await tester.ensureVisible(boss);
    await tester.tap(boss);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
    final model = (tester
            .widgetList<GameWidget>(find.byWidgetPredicate((w) => w is GameWidget))
            .first
            .game as dynamic)
        .model as ArcadeModel;
    expect(model.boss?.fightReady, isTrue);
    expect(model.consoleDecay, isTrue);
    expect(model.ranked, isFalse);
    await tester.pumpWidget(const SizedBox());
    await tester.pump();
  });
}
