import 'dart:math' as math;

import 'package:demon_attack/comms/comms_bank.dart';
import 'package:demon_attack/comms/comms_director.dart';
import 'package:demon_attack/comms/comms_lineup.dart';
import 'package:demon_attack/comms/comms_types.dart';
import 'package:demon_attack/game/game_events.dart';
import 'package:flutter_test/flutter_test.dart';

CommsLine _h(String id, String speaker, {double d = 1.5}) =>
    CommsLine(id: id, speaker: speaker, duration: d, text: id);
CommsLine _d(String id, String speaker, {double d = 1}) => CommsLine(
  id: id,
  speaker: speaker,
  duration: d,
  grunt: 'order',
  gloss: 'X',
);

CommsTriggerSpec _spec(
  String name,
  int priority,
  List<CommsLine> lines, {
  double cooldown = 5,
  double ttl = 3,
  double delay = 0,
  double chance = 1,
}) => CommsTriggerSpec(
  name: name,
  priority: priority,
  cooldown: cooldown,
  ttl: ttl,
  lines: lines,
  delay: delay,
  chance: chance,
);

const _cast = {
  'cmd': CommsCharacter(
    id: 'cmd',
    side: CommsSide.fleet,
    name: 'C',
    rank: 'CMDR',
    callsign: 'C',
    accent: 0xFFFFFFFF,
  ),
  'p1': CommsCharacter(
    id: 'p1',
    side: CommsSide.fleet,
    name: 'P1',
    rank: 'LT',
    callsign: 'P1',
    accent: 0xFFFFFFFF,
  ),
  'p2': CommsCharacter(
    id: 'p2',
    side: CommsSide.fleet,
    name: 'P2',
    rank: 'LT',
    callsign: 'P2',
    accent: 0xFFFFFFFF,
  ),
  'g1': CommsCharacter(
    id: 'g1',
    side: CommsSide.ground,
    name: 'G1',
    rank: 'SGT',
    callsign: 'G1',
    accent: 0xFFFFFFFF,
  ),
  'dA': CommsCharacter(
    id: 'dA',
    side: CommsSide.demon,
    name: 'DA',
    rank: 'MARSHAL',
    callsign: 'DA',
    accent: 0xFFFFFFFF,
  ),
  'dB': CommsCharacter(
    id: 'dB',
    side: CommsSide.demon,
    name: 'DB',
    rank: 'COLONEL',
    callsign: 'DB',
    accent: 0xFFFFFFFF,
  ),
};

const _roster = {
  1: {
    CommsSide.fleet: ['cmd', 'p1'],
    CommsSide.ground: ['g1'],
    CommsSide.demon: ['dA'],
  },
  2: {
    CommsSide.fleet: ['cmd', 'p2'],
    CommsSide.ground: ['g1'],
    CommsSide.demon: ['dB'],
  },
};

CommsDirector _director({
  Map<String, CommsTriggerSpec>? human,
  Map<String, CommsTriggerSpec>? demon,
}) {
  final h =
      human ??
      {
        'chatter': _spec('chatter', 3, [
          _h('chatter.h0', 'p1'),
          _h('chatter.h1', 'p2'),
        ]),
        'warn': _spec(
          'warn',
          9,
          [_h('warn.h0', 'cmd', d: 1)],
          cooldown: 4,
          ttl: 1.5,
        ),
        'brief': _spec('brief', 4, [
          _h('brief.h0', 'cmd'),
          _h('brief.h1', 'p1'),
          _h('brief.h2', 'p2'),
        ], cooldown: 0),
        'help': _spec('help', 7, [_h('help.h0', 'g1')], cooldown: 0),
      };
  final d =
      demon ??
      {
        'chatter': _spec('chatter', 4, [
          _d('chatter.d0', 'dA'),
          _d('chatter.d1', 'dB'),
        ], delay: .5),
        'help': _spec('help', 4, [_d('help.d0', 'dA'), _d('help.d1', 'dB')]),
      };
  return CommsDirector(
    random: math.Random(7),
    human: h,
    demon: d,
    cast: _cast,
    roster: _roster,
  );
}

void main() {
  group('triggers, priority and cooldowns', () {
    test('an event queues the human line and a delayed demon reaction', () {
      final c = _director();
      c.handle(const GameEvent('chatter'), 0);
      c.update(0);
      expect(c.active.map((m) => m.line.speaker), ['p1']);
      expect(c.queue.single.isDemon, isTrue);
      c.update(.4);
      expect(c.active.length, 1, reason: 'demon waits for its delay');
      c.update(.5);
      expect(c.active.map((m) => m.line.id).toSet(), {
        'chatter.h0',
        'chatter.d0',
      });
      expect(c.active.length, lessThanOrEqualTo(c.maxActive));
    });

    test('cooldown suppresses repeats; unknown events are ignored', () {
      final c = _director();
      c.handle(const GameEvent('chatter'), 0);
      c.update(0);
      c.handle(const GameEvent('chatter'), 3);
      c.update(3);
      c.handle(const GameEvent('somethingElse'), 3);
      c.update(10);
      expect(c.history.where((id) => id.startsWith('chatter.h')).length, 1);
      c.handle(const GameEvent('chatter'), 10);
      c.update(10);
      expect(c.history.where((id) => id.startsWith('chatter.h')).length, 2);
    });

    test(
      'a critical warning interrupts lower chatter; chatter never interrupts',
      () {
        final stopped = <String>[];
        final c = _director()..onStop = (m) => stopped.add(m.line.id);
        c.handle(const GameEvent('chatter'), 0);
        c.update(0);
        c.handle(const GameEvent('warn'), .2);
        c.update(.2);
        expect(stopped, ['chatter.h0']);
        expect(c.active.where((m) => !m.isDemon).single.line.id, 'warn.h0');
        // Lower priority waits behind the critical line, then expires.
        c.handle(const GameEvent('brief'), .3);
        c.update(.3);
        expect(c.active.where((m) => !m.isDemon).single.line.id, 'warn.h0');
        c.update(4);
        expect(c.history, isNot(contains(startsWith('brief'))));
      },
    );

    test(
      'queue drains by priority after the human gap; stale lines expire',
      () {
        final c = _director();
        c.handle(const GameEvent('brief'), 0);
        c.update(0);
        c.handle(const GameEvent('chatter'), .1);
        c.handle(const GameEvent('help'), .1);
        c.update(.1);
        final briefEnd = c.active.firstWhere((m) => !m.isDemon).endsAt;
        c.update(briefEnd);
        expect(c.active.where((m) => !m.isDemon), isEmpty);
        c.update(briefEnd + c.humanGap);
        // help (7) beats chatter (3)
        expect(c.active.firstWhere((m) => !m.isDemon).line.id, 'help.h0');
        c.update(30);
        expect(c.queue, isEmpty);
        expect(c.history.where((id) => id.startsWith('chatter.h')), isEmpty);
      },
    );

    test('never more than maxActive at once, one human voice at a time', () {
      final c = _director();
      var peak = 0;
      for (var t = 0.0; t < 20; t += .05) {
        if ((t * 20).round() % 7 == 0) c.handle(const GameEvent('chatter'), t);
        if ((t * 20).round() % 11 == 0) c.handle(const GameEvent('help'), t);
        if ((t * 20).round() % 23 == 0) c.handle(const GameEvent('warn'), t);
        c.update(t);
        peak = math.max(peak, c.active.length);
        expect(c.active.where((m) => !m.isDemon).length, lessThanOrEqualTo(1));
        expect(c.active.where((m) => m.isDemon).length, lessThanOrEqualTo(1));
        expect(c.queue.length, lessThanOrEqualTo(c.maxQueued));
      }
      expect(peak, 2);
    });

    test('chance gates chatter but still starts the cooldown', () {
      final c = _director(
        human: {
          'rare': _spec('rare', 2, [_h('rare.h0', 'p1')], chance: 0),
        },
        demon: const {},
      );
      c.handle(const GameEvent('rare'), 0);
      c.update(0);
      expect(c.history, isEmpty);
    });

    test('variant triggers win over the generic one', () {
      final c = _director(
        human: {
          'sectorStart': _spec('sectorStart', 4, [_h('g.h0', 'cmd')]),
          'sectorStart.2': _spec('sectorStart.2', 4, [_h('s2.h0', 'cmd')]),
        },
        demon: const {},
      );
      c.handle(const GameEvent('sectorStart', {'variant': '2'}), 0);
      c.update(0);
      expect(c.history, ['s2.h0']);
      expect(c.sector, 2);
    });
  });

  group('rotating cast and slots', () {
    test('speakers come from the sector roster and rotate', () {
      final c = _director();
      final speakers = <String>[];
      var t = 0.0;
      for (var i = 0; i < 6; i++) {
        c.handle(const GameEvent('brief'), t);
        c.update(t);
        speakers.add(c.active.firstWhere((m) => !m.isDemon).line.speaker);
        t += 5;
        c.update(t);
      }
      expect(speakers.toSet(), {'cmd', 'p1'}, reason: 'p2 is not on sector 1');
      for (var i = 1; i < speakers.length; i++) {
        expect(speakers[i], isNot(speakers[i - 1]));
      }
      c.handle(const GameEvent('sectorStart', {'variant': '2'}), t);
      final later = <String>{};
      for (var i = 0; i < 6; i++) {
        t += 5;
        c.handle(const GameEvent('brief'), t);
        c.update(t);
        later.add(c.active.firstWhere((m) => !m.isDemon).line.speaker);
      }
      expect(later, {'cmd', 'p2'});
    });

    test(
      'humans sit on the left, demons on the right, speakers keep slots',
      () {
        final c = _director();
        c.handle(const GameEvent('chatter'), 0);
        c.update(.6);
        final human = c.active.firstWhere((m) => !m.isDemon);
        final demon = c.active.firstWhere((m) => m.isDemon);
        expect(c.slots[human.slot].left, isTrue);
        expect(c.slots[demon.slot].left, isFalse);
        c.update(5);
        c.handle(const GameEvent('help'), 5);
        c.update(5);
        final ground = c.active.firstWhere((m) => !m.isDemon);
        expect(
          c.slots[ground.slot].left,
          isFalse,
          reason: 'ground link column',
        );
        expect(ground.slot, isNot(human.slot), reason: 'p1 stays on the call');
        final again = c.active.firstWhere((m) => m.isDemon);
        expect(again.slot, demon.slot, reason: 'dA keeps its tile');
        expect(c.slots.where((s) => s.occupant != null).length, 3);
      },
    );

    test('a fourth caller on a full side replaces the quietest idle tile', () {
      final c = _director();
      c.handle(const GameEvent('brief'), 0); // cmd or p1
      c.update(0);
      c.update(3);
      c.handle(const GameEvent('brief'), 3);
      c.update(3);
      c.update(7);
      final left = c.slots.where((s) => s.left).map((s) => s.occupant).toSet();
      expect(left.length, 2);
      c.handle(const GameEvent('help'), 7); // g1
      c.update(7);
      final g = c.active.firstWhere((m) => m.line.speaker == 'g1');
      // With the right column empty, a human may borrow it rather than
      // dropping someone.
      expect(c.slots.where((s) => s.occupant != null).length, 3);
      expect(c.slots[g.slot].occupant, 'g1');
      c.update(9);
      c.handle(const GameEvent('chatter'), 9);
      c.update(9.6);
      final d = c.active.firstWhere((m) => m.isDemon);
      expect(c.slots[d.slot].left, isFalse);
      expect(c.slots.map((s) => s.occupant).toSet().length, 4);
    });

    test('a new sector hangs up idle tiles with a disconnect transition', () {
      final c = _director();
      c.handle(const GameEvent('chatter'), 0);
      c.update(.6);
      c.update(5);
      c.handle(const GameEvent('sectorStart', {'variant': '2'}), 5);
      expect(c.slots.where((s) => s.occupant != null), isEmpty);
      expect(
        c.slots.where((s) => s.state(5.1) == CommsSlotState.disconnecting),
        isNotEmpty,
      );
      c.update(6);
      expect(c.slots.every((s) => s.state(6) == CommsSlotState.empty), isTrue);
    });

    test('mouth frames follow the measured envelope and fall back cleanly', () {
      final m = CommsMessage(
        trigger: _spec('x', 1, const []),
        line: const CommsLine(
          id: 'x',
          speaker: 'cmd',
          duration: .4,
          text: 'x',
          mouth: '023',
        ),
        character: _cast['cmd']!,
        priority: 1,
        queuedAt: 0,
        readyAt: 0,
        expiresAt: 1,
        sequence: 0,
      )..startedAt = 0;
      expect(m.frame(0), CommsFrame.idle);
      expect(m.frame(.07), CommsFrame.talkA);
      expect(m.frame(.14), CommsFrame.talkB);
      expect(m.frame(.3), CommsFrame.talkB, reason: 'last value holds');
      expect(m.frame(.5), CommsFrame.idle, reason: 'after the clip');
    });
  });

  group('shipped line bank', () {
    test('every trigger has 3-6 variants with more than one speaker', () {
      expect(commsHumanTriggers.length, greaterThanOrEqualTo(30));
      for (final spec in [
        ...commsHumanTriggers.values,
        ...commsDemonTriggers.values,
      ]) {
        expect(spec.lines.length, inInclusiveRange(2, 6), reason: spec.name);
        if (commsHumanTriggers[spec.name] == spec) {
          expect(spec.lines.length, inInclusiveRange(3, 6), reason: spec.name);
        }
        for (final line in spec.lines) {
          expect(commsCast, contains(line.speaker));
          expect(line.duration, greaterThan(.2));
          expect(
            line.isGrunt,
            commsCast[line.speaker]!.isDemon,
            reason: line.id,
          );
        }
      }
      for (final spec in commsHumanTriggers.values) {
        if (spec.name == 'defeat') continue;
        expect(
          spec.lines.map((l) => l.speaker).toSet().length,
          greaterThan(1),
          reason: spec.name,
        );
      }
    });

    test('any seeded lineup has its own crew for almost every trigger', () {
      var covered = 0, total = 0;
      for (var seed = 0; seed < 200; seed++) {
        final lineup = CommsLineup.pick(seed);
        for (final spec in commsHumanTriggers.values) {
          total++;
          if (spec.lines.any((l) => lineup.members.contains(l.speaker))) {
            covered++;
          }
        }
        for (var sector = 1; sector <= 5; sector++) {
          final crew = {
            for (final ids in lineup.roster[sector]!.values) ...ids,
          };
          for (final spec in commsDemonTriggers.values) {
            if (spec.name.startsWith('boss')) continue; // carrier sector only
            expect(
              spec.lines.any((l) => crew.contains(l.speaker)),
              isTrue,
              reason: 'demon ${spec.name} in sector $sector',
            );
          }
        }
      }
      // The rest are patched in from the wider fleet.
      expect(covered / total, greaterThan(.95));
    });

    test('ground-force and homing events plug in by name', () {
      for (final name in [
        GameEventNames.groundForceSighted,
        GameEventNames.groundForceInRange,
        GameEventNames.homingPickup,
        GameEventNames.allyUnderAttack,
        GameEventNames.allySaved,
        GameEventNames.allyRetreated,
        GameEventNames.flawlessSector,
        GameEventNames.flawlessVictory,
        GameEventNames.flawlessRun,
      ]) {
        expect(commsHumanTriggers, contains(name));
      }
      final help = commsHumanTriggers[GameEventNames.allyUnderAttack]!;
      expect(
        help.critical,
        isFalse,
        reason: 'below gameplay-critical warnings',
      );
      expect(
        help.lines.every((l) => commsCast[l.speaker]!.side == CommsSide.ground),
        isTrue,
      );
      for (final critical in [
        'sentinelDive',
        'shieldExpiring',
        'bossArrival',
      ]) {
        expect(
          commsHumanTriggers[critical]!.priority,
          greaterThan(help.priority),
        );
      }
      final c = CommsDirector(random: math.Random(3));
      c.handle(const GameEvent('sectorStart', {'variant': '4'}), 0);
      c.update(0);
      c.update(8);
      c.handle(const GameEvent('allyUnderAttack', {'payload': '2,140'}), 8);
      c.update(8);
      expect(
        c.active.where((m) => !m.isDemon).single.character.side,
        CommsSide.ground,
      );
      c.update(9.5);
      expect(
        c.active.where((m) => m.isDemon),
        isNotEmpty,
        reason: 'officers grunt orders to their ground troops',
      );
    });
  });
}
