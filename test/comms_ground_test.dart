import 'dart:math' as math;

import 'package:demon_attack/comms/comms_bank.dart';
import 'package:demon_attack/comms/comms_director.dart';
import 'package:demon_attack/comms/comms_lineup.dart';
import 'package:demon_attack/comms/squad_comms.dart';
import 'package:demon_attack/game/model.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('ground pressure narrates rising, high, and re-arms after calm', () {
    final model = ArcadeModel()..start();
    final o = GameEventObserver(model, dispatch: false);
    List<String> p(double level) => [
      for (final e in o.onGameEvent(
        GameEvent(GameEventNames.groundPressure, {'level': level}),
      ))
        e.name,
    ];
    expect(p(.1), isEmpty);
    expect(p(.5), [GameEventNames.groundPressureRising]);
    expect(p(.6), isEmpty);
    expect(p(.85), [GameEventNames.groundPressureHigh]);
    expect(p(.9), isEmpty);
    expect(p(.4), isEmpty, reason: 'still above calm');
    expect(p(.2), [GameEventNames.groundPressureEased]);
    expect(p(.5), [GameEventNames.groundPressureRising]);
    expect(
      o
          .onGameEvent(
            const GameEvent(GameEventNames.groundPressure, {
              'pressure': '0.95',
            }),
          )
          .map((e) => e.name),
      [GameEventNames.groundPressureHigh],
    );
  });

  test('ground narration is rate-limited as a group, air callouts are not', () {
    final c = CommsDirector(random: math.Random(4))
      ..setLineup(CommsLineup.pick(4));
    c.handle(const GameEvent('sectorStart', {'variant': '4'}), 0);
    var t = 8.0;
    c.update(t);
    final gap = commsGroupGap['ground']!;
    var groundQueued = 0, airQueued = 0;
    for (var i = 0; i < 40; i++) {
      for (final name in [
        GameEventNames.groundUnitDestroyed,
        GameEventNames.groundForceSighted,
        GameEventNames.allySaved,
        GameEventNames.groundPressureRising,
      ]) {
        final before = c.queue.length + c.active.length;
        c.handle(GameEvent(name), t);
        if (c.queue.length + c.active.length > before) groundQueued++;
      }
      final before = c.queue.where((m) => !m.isDemon).length;
      c.handle(const GameEvent(GameEventNames.reinforcements), t);
      if (c.queue.where((m) => !m.isDemon).length > before) airQueued++;
      t += 1;
      c.update(t);
    }
    // At most one ground line per gap (plus its demon reaction).
    expect(groundQueued, lessThanOrEqualTo(2 * (40 / gap).ceil() + 2));
    expect(airQueued, greaterThan(0));
    for (final name in [
      'groundUnitDestroyed',
      'groundPressureRising',
      'groundPressureHigh',
      'groundBreakthrough',
      'groundForceSighted',
      'allyUnderAttack',
    ]) {
      expect(commsHumanTriggers[name]!.group, 'ground', reason: name);
      expect(
        commsHumanTriggers[name]!.critical,
        name == 'groundBreakthrough',
        reason: 'only the breakthrough is an urgent warning',
      );
    }
    expect(
      commsHumanTriggers['groundBreakthrough']!.priority,
      greaterThan(commsHumanTriggers['groundPressureRising']!.priority),
    );
    expect(
      commsHumanTriggers['groundForceSighted']!.lines.first.text,
      contains('Ground enemies incoming'),
    );
  });

  test('only allied kills are reported', () {
    var t = 0.0;
    final comms = SquadComms(playAudio: false, wallClock: () => t)
      ..useLineup(CommsLineup.pick(9));
    comms.tick(
      events: const [
        GameEvent(GameEventNames.groundUnitDestroyed, {'by': 'homing'}),
      ],
      paused: false,
    );
    expect(comms.director.queue, isEmpty);
    expect(comms.director.active, isEmpty);
    var reported = false;
    for (var i = 0; i < 40 && !reported; i++) {
      t += 30;
      comms.tick(
        events: const [
          GameEvent(GameEventNames.groundUnitDestroyed, {'by': 'allies'}),
        ],
        paused: false,
      );
      reported = comms.director.history.any(
        (id) => id.startsWith('groundUnitDestroyed'),
      );
    }
    expect(reported, isTrue);
  });
}
