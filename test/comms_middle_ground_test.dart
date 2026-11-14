/// comms-middle-ground: no line cuts another, readable holds, the dock
/// stacking, gated ground and air-cover lines, more voiced moments, the
/// fire forecast, and the transition hooks (hush, offer).
library;

import 'dart:math' as math;

import 'package:demon_attack/comms/comms_bank.dart';
import 'package:demon_attack/comms/comms_context.dart';
import 'package:demon_attack/comms/comms_director.dart';
import 'package:demon_attack/comms/comms_lineup.dart';
import 'package:demon_attack/comms/comms_types.dart';
import 'package:demon_attack/comms/comms_view.dart';
import 'package:demon_attack/game/model.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

CommsDirector _director([int seed = 3]) =>
    CommsDirector(random: math.Random(seed), jitter: math.Random(seed + 1))
      ..setLineup(CommsLineup.pick(seed))
      ..setSector(3, 0);

/// Runs [c] in 60 Hz ticks from [from] to [to].
void _run(CommsDirector c, double from, double to) {
  for (var t = from; t <= to + 1e-9; t += 1 / 60) {
    c.update(t, combat: true);
  }
}

CommsMessage _msg(
  String id,
  String text,
  double start, {
  double duration = 1,
  CommsMessage? inReplyTo,
}) {
  final who = commsCast.values.first;
  return CommsMessage(
      trigger: const CommsTriggerSpec(
        name: 'x',
        priority: 1,
        cooldown: 1,
        ttl: 10,
        lines: [],
      ),
      line: CommsLine(id: id, speaker: who.id, duration: duration, text: text),
      character: who,
      priority: 1,
      queuedAt: start,
      readyAt: start,
      expiresAt: start + 10,
      sequence: 0,
    )
    ..startedAt = start
    ..inReplyTo = inReplyTo;
}

void main() {
  group('readable holds', () {
    test('a subtitle stays up for its reading time or its hold', () {
      final short = _msg('a', 'Go!', 0, duration: 1.5);
      expect(short.endsAt, closeTo(1.5 + CommsMessage.textHold, 1e-9));
      final long = _msg('b', 'x' * 100, 0, duration: .8);
      expect(
        long.endsAt,
        closeTo(CommsMessage.readBase + CommsMessage.readPerChar * 100, 1e-9),
      );
      final huge = _msg('c', 'x' * 400, 0, duration: .8);
      expect(huge.endsAt, closeTo(CommsMessage.readCap, 1e-9));
    });

    test('the dock never hides a card that is still being read', () {
      final a = _msg('a', 'First', 0);
      final b = _msg('b', 'Second', 1.4);
      final c = _msg('c', 'Third', 2.8);
      final (:placed, :overflow) = CommsHudStack.dockEntries([c, a, b]);
      expect(placed.map((e) => e.single.line.id), ['a', 'b']);
      expect(overflow.single.single.line.id, 'c');
      // An exchange takes both halves; a newer call waits in the ticker.
      final opening = _msg('o', 'That sector is mine!', 0);
      final answer = _msg('r', 'Only until my turn!', 1.4, inReplyTo: opening);
      final warn = _msg('w', 'Missile up!', 2.9);
      final dock = CommsHudStack.dockEntries([opening, answer, warn]);
      expect(dock.placed.single.map((m) => m.line.id), ['o', 'r']);
      expect(dock.overflow.single.single.line.id, 'w');
    });

    testWidgets('a waiting card shows as a ticker under the exchange', (
      tester,
    ) async {
      final director = CommsDirector();
      final opening = _msg('o', 'That sector is mine!', 0);
      final answer = _msg('r', 'Only until my turn!', 1.4, inReplyTo: opening);
      final warn = _msg('w', 'Missile up! It is going for you!', 2.9);
      director.active.addAll([opening, answer, warn]);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 360,
              child: CommsHudStack(director: director, now: 3.2),
            ),
          ),
        ),
      );
      expect(find.byKey(const ValueKey('comms-conversation')), findsOneWidget);
      expect(find.byKey(const ValueKey('comms-ticker-w')), findsOneWidget);
      for (final text in [
        'That sector is mine!',
        'Only until my turn!',
        'Missile up!',
      ]) {
        expect(
          find.textContaining(text, findRichText: true),
          findsOneWidget,
          reason: text,
        );
      }
      final dock = tester.getSize(find.byType(CommsHudStack));
      expect(dock.height, lessThanOrEqualTo(CommsHudStack.maxHeight));
      expect(tester.takeException(), isNull);
    });
  });

  group('no line cuts another', () {
    test('a ground warning waits for the line on air, then the grace gap', () {
      final heard = <CommsMessage>[];
      final c = _director()..onStart = heard.add;
      c.handle(const GameEvent(GameEventNames.lowLives), 0);
      _run(c, 0, .1);
      final first = heard.single;
      // The warning is due before the line on air can finish.
      c.handle(
        const GameEvent(GameEventNames.groundFirePrep, {'fireIn': 1.0}),
        .2,
      );
      _run(c, .2, 8);
      expect(c.interruptedLines, isEmpty);
      final warning = heard.firstWhere((m) => m.mustPlay);
      expect(warning.late, isTrue);
      expect(c.lateWarnings, 1);
      final shortest = commsHumanTriggers[GameEventNames.groundMissileLaunch]!
          .lines
          .map((l) => l.duration)
          .reduce(math.min);
      expect(warning.line.duration, shortest);
      expect(
        warning.startedAt,
        greaterThanOrEqualTo(
          first.speechEndsAt + c.lineGap - CommsDirector.warningLead - 1e-9,
        ),
      );
    });

    test('a forecast keeps the channel clear for the warning', () {
      final heard = <CommsMessage>[];
      final c = _director()..onStart = heard.add;
      c.handle(
        const GameEvent(GameEventNames.groundFireForecast, {'fireIn': 4.0}),
        0,
      );
      // A long line would still be speaking when the warning is due.
      c.handle(const GameEvent(GameEventNames.lowLives), .1);
      c.handle(
        const GameEvent(GameEventNames.groundFirePrep, {'fireIn': 2.5}),
        1.5,
      );
      _run(c, 0, 4.2);
      final warning = heard.firstWhere((m) => m.mustPlay);
      expect(warning.late, isFalse);
      expect(warning.speechEndsAt, lessThanOrEqualTo(4.0 + 1e-6));
      expect(heard.first.mustPlay, isTrue, reason: 'nothing started before');
    });
  });

  group('lines match the fight below', () {
    test('air-cover lines only while the ship is over the battle', () {
      final gates = CommsGroundPicture();
      final spec = commsHumanTriggers[GameEventNames.groundForceInRange]!;
      final over = spec.lines.firstWhere((l) => l.id.endsWith('.h4'));
      expect(over.text, contains('right over them'));
      gates.note(
        const GameEvent(GameEventNames.groundPicture, {
          'engaged': 2,
          'over': false,
        }),
        0,
      );
      expect(gates.allows(spec, over, null, 1), isFalse);
      gates.note(
        const GameEvent(GameEventNames.groundPicture, {
          'engaged': 2,
          'over': true,
        }),
        2,
      );
      expect(gates.allows(spec, over, null, 2.5), isTrue);
      gates.note(
        const GameEvent(GameEventNames.groundPicture, {
          'engaged': 0,
          'over': false,
        }),
        3,
      );
      expect(gates.allows(spec, over, null, 3.5), isFalse);
    });

    test('calls for help only after allies were attacked', () {
      final gates = CommsGroundPicture();
      final spec = commsHumanTriggers[GameEventNames.groundPressureHigh]!;
      final help = spec.lines.firstWhere((l) => l.id.endsWith('.h0'));
      gates.note(const GameEvent(GameEventNames.groundSkirmish), 0);
      expect(gates.allows(spec, help, null, 1), isFalse);
      gates.note(const GameEvent(GameEventNames.allyUnderAttack), 2);
      expect(gates.allows(spec, help, null, 3), isTrue);
      expect(
        gates.allows(
          spec,
          help,
          null,
          2 + CommsGroundPicture.attackedWindow + 1,
        ),
        isFalse,
      );
    });

    test('flank, artillery and thanks match the event', () {
      final gates = CommsGroundPicture();
      final skirmish = commsHumanTriggers[GameEventNames.groundSkirmish]!;
      final left = skirmish.lines.firstWhere((l) => l.id.endsWith('.h0'));
      expect(left.text, contains('left flank'));
      expect(
        gates.allows(skirmish, left, const GameEvent('x', {'x': 60.0}), 0),
        isTrue,
      );
      expect(
        gates.allows(skirmish, left, const GameEvent('x', {'x': 300.0}), 0),
        isFalse,
      );
      final won = commsHumanTriggers[GameEventNames.skirmishWon]!;
      final thunder = won.lines.firstWhere((l) => l.id.endsWith('.h4'));
      expect(
        gates.allows(won, thunder, const GameEvent('x', {'by': 'vehicle'}), 0),
        isFalse,
      );
      expect(
        gates.allows(
          won,
          thunder,
          const GameEvent('x', {'by': 'artillery'}),
          0,
        ),
        isTrue,
      );
      // Every gated id is a real clip.
      final ids = {
        for (final bank in [commsHumanTriggers, commsDemonTriggers])
          for (final s in bank.values) ...s.lines.map((l) => l.id),
      };
      expect(ids, containsAll(commsLineGates.keys));
    });
  });

  group('more voiced moments, from recorded clips', () {
    test('reinforcements arriving twice in a frame make one call', () {
      final heard = <String>[];
      final c = _director()..onStart = (m) => heard.add(m.line.id);
      c.handle(const GameEvent(GameEventNames.reinforcements), 0);
      c.handle(const GameEvent(GameEventNames.reinforcementsArrived), 0);
      _run(c, 0, 12);
      expect(
        heard.where((id) => id.startsWith('reinforcements.h')),
        hasLength(1),
      );
    });

    test('the carrier hatch and the next wave on the horizon are voiced', () {
      final heard = <CommsMessage>[];
      final c = _director()..onStart = heard.add;
      c.handle(const GameEvent(GameEventNames.carrierHatchOpen), 0);
      _run(c, 0, 8);
      expect(heard.map((m) => m.trigger.name), contains('carrierHatchOpen'));
      heard.clear();
      c.handle(const GameEvent(GameEventNames.incoming), 9);
      _run(c, 9, 14);
      final call = heard.firstWhere((m) => !m.isDemon);
      expect(call.trigger.name, GameEventNames.incoming);
      expect(call.kind, CommsClass.useful);
      expect(commsHumanTriggers['waveStart']!.lines, contains(call.line));
      // Its arrival right after shares the cooldown: no second wave call.
      heard.clear();
      c.handle(const GameEvent(GameEventNames.waveStart), 15);
      _run(c, 15, 20);
      expect(heard.where((m) => !m.isDemon), isEmpty);
    });
  });

  group('transition hooks', () {
    test('hush holds chatter and briefings but not warnings', () {
      final heard = <CommsMessage>[];
      final c = _director()..onStart = heard.add;
      c.hush(4, at: 0);
      c.handle(const GameEvent(GameEventNames.lowLives), 0);
      c.handle(
        const GameEvent(GameEventNames.groundFirePrep, {'fireIn': 2.5}),
        0,
      );
      _run(c, 0, 3.9);
      expect(heard, isNotEmpty);
      expect(heard.every((m) => m.mustPlay || m.urgent), isTrue);
      _run(c, 3.9, 8);
      expect(heard.map((m) => m.trigger.name), contains('lowLives'));
      final low = heard.firstWhere((m) => m.trigger.name == 'lowLives');
      expect(low.startedAt, greaterThanOrEqualTo(4));
      c.hushFor(const Duration(seconds: 2));
      expect(c.hushed, isTrue);
      c.hush(0);
      expect(c.hushed, isFalse);
    });

    test('offer queues a chosen bank line through the pacing', () {
      final heard = <CommsMessage>[];
      final c = _director()..onStart = heard.add;
      c.handle(const GameEvent(GameEventNames.lowLives), 0);
      _run(c, 0, .1);
      final first = heard.single;
      final line = commsHumanTriggers['transmissionMission']!.lines.first;
      final m = c.offer(line, at: .2, ttl: 12);
      expect(m, isNotNull);
      expect(m!.trigger.name, 'transmissionMission');
      _run(c, .2, 12);
      expect(heard, contains(m));
      expect(
        m.startedAt,
        greaterThanOrEqualTo(first.speechEndsAt + c.lineGap - 1e-9),
      );
      expect(c.interruptedLines, isEmpty);
    });
  });

  group('observer', () {
    test('groundPicture on change, and a forecast of each shot', () {
      final model = ArcadeModel()..start();
      final o = GameEventObserver(model, dispatch: false);
      o.observe(model.takeEvents());
      model.mode = RunMode.playing;
      expect(
        o.observe(const []).where((e) => e.name == 'groundPicture'),
        isEmpty,
      );
      final u = GroundUnit(model.ground.nextId++, 2, 0, .5, GroundTuning.fireZ)
        ..cooldown = 1;
      model.ground.units.add(u);
      model.shipX = u.x;
      final events = o.observe(const []);
      final picture = events.firstWhere(
        (e) => e.name == GameEventNames.groundPicture,
      );
      expect(picture.data['engaged'], 1);
      expect(picture.data['over'], isTrue);
      final forecast = events.firstWhere(
        (e) => e.name == GameEventNames.groundFireForecast,
      );
      expect(
        forecast.data['fireIn'] as double,
        closeTo((1 + GroundTuning.telegraph) / model.policy.hostileRate, 1e-9),
      );
      final again = o.observe(const []);
      expect(again.where((e) => e.name == 'groundPicture'), isEmpty);
      expect(again.where((e) => e.name == 'groundFireForecast'), isEmpty);
    });
  });
}
