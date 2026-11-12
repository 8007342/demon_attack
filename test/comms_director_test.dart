import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:demon_attack/comms/comms_bank.dart';
import 'package:demon_attack/comms/comms_director.dart';
import 'package:demon_attack/comms/comms_lineup.dart';
import 'package:demon_attack/comms/comms_mouth.dart';
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
  bool urgent = false,
  CommsSide? exchange,
  bool overlap = false,
  int chain = 0,
}) => CommsTriggerSpec(
  name: name,
  priority: priority,
  cooldown: cooldown,
  ttl: ttl,
  lines: lines,
  delay: delay,
  chance: chance,
  urgent: urgent,
  exchange: exchange,
  overlap: overlap,
  chain: chain,
);

CommsCharacter _c(String id, CommsSide side) => CommsCharacter(
  id: id,
  side: side,
  name: id,
  rank: 'R',
  callsign: id,
  accent: 0xFFFFFFFF,
);

final _cast = {
  for (final id in ['cmd', 'p1', 'p2']) id: _c(id, CommsSide.fleet),
  'g1': _c('g1', CommsSide.ground),
  for (final id in ['dA', 'dB', 'dC']) id: _c(id, CommsSide.demon),
};

const _roster = {
  1: {
    CommsSide.fleet: ['cmd', 'p1'],
    CommsSide.ground: ['g1'],
    CommsSide.demon: ['dA', 'dC'],
  },
  2: {
    CommsSide.fleet: ['cmd', 'p2'],
    CommsSide.ground: ['g1'],
    CommsSide.demon: ['dB', 'dC'],
  },
};

CommsDirector _director({
  Map<String, CommsTriggerSpec>? human,
  Map<String, CommsTriggerSpec>? demon,
  double starveAfter = 1000,
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
          urgent: true,
        ),
        'big': _spec('big', 9, [_h('big.h0', 'cmd')], cooldown: 0),
        'brief': _spec(
          'brief',
          4,
          [_h('brief.h0', 'cmd'), _h('brief.h1', 'p1'), _h('brief.h2', 'p2')],
          cooldown: 0,
          ttl: 10,
        ),
        'help': _spec('help', 7, [_h('help.h0', 'g1')], cooldown: 0, ttl: 10),
        'win': _spec(
          'win',
          5,
          [_h('win.h0', 'cmd')],
          exchange: CommsSide.fleet,
          ttl: 10,
        ),
        'taunt': _spec(
          'taunt',
          4,
          [_h('taunt.h0', 'p1')],
          exchange: CommsSide.demon,
          ttl: 10,
        ),
      };
  final d =
      demon ??
      {
        'chatter': _spec(
          'chatter',
          4,
          [_d('chatter.d0', 'dA'), _d('chatter.d1', 'dB')],
          delay: .5,
          ttl: 10,
        ),
        'help': _spec('help', 4, [
          _d('help.d0', 'dA'),
          _d('help.d1', 'dB'),
        ], ttl: 10),
        'win': _spec(
          'win',
          5,
          [_d('win.d0', 'dA', d: 2.2)],
          exchange: CommsSide.fleet,
          ttl: 4,
        ),
        'taunt': _spec(
          'taunt',
          4,
          [_d('taunt.d0', 'dA')],
          exchange: CommsSide.demon,
          ttl: 10,
        ),
        'regroupStart': _spec(
          'regroupStart',
          5,
          [
            _d('rg.d0', 'dA', d: .8),
            _d('rg.d1', 'dC', d: .8),
            _d('rg.d2', 'dB', d: .8),
          ],
          overlap: true,
          chain: 2,
          cooldown: 1,
        ),
        'broodChatter': _spec('broodChatter', 3, [
          _d('bc.d0', 'dA'),
          _d('bc.d1', 'dC'),
        ], cooldown: 2),
      };
  return CommsDirector(
    random: math.Random(7),
    human: h,
    demon: d,
    cast: _cast,
    roster: _roster,
    starveAfter: starveAfter,
  );
}

/// Runs [c] to [until] in 50 ms steps and records the voices sounding.
List<Set<String>> _run(CommsDirector c, double from, double until) {
  final out = <Set<String>>[];
  for (var t = from; t <= until + 1e-9; t += .05) {
    c.update(t);
    out.add({
      for (final m in c.active)
        if (m.speaking(t)) m.line.id,
    });
  }
  return out;
}

void main() {
  group('one channel: sequencing, no cutoffs', () {
    test('a human line and the demon reaction play one after the other', () {
      final c = _director();
      c.handle(const GameEvent('chatter'), 0);
      final voices = _run(c, 0, 5);
      expect(voices.every((v) => v.length <= 1), isTrue);
      expect(c.history, ['chatter.h0', 'chatter.d0']);
      final demon = c.active.isEmpty ? null : c.active.last;
      expect(
        demon?.startedAt ?? 2,
        greaterThanOrEqualTo(1.5 + c.lineGap - 1e-6),
      );
      expect(c.interruptedLines, isEmpty);
    });

    test('higher priority waits its turn; only urgent warnings cut', () {
      final stopped = <String>[];
      final c = _director()..onStop = (m) => stopped.add(m.line.id);
      c.handle(const GameEvent('brief'), 0);
      c.update(0);
      c.handle(const GameEvent('big'), .2); // priority 9, not urgent
      _run(c, .2, 1.2);
      expect(c.interruptedLines, isEmpty, reason: 'non-urgent never cuts');
      c.handle(const GameEvent('warn'), 1.3); // urgent
      c.update(1.3);
      expect(c.interruptedLines, hasLength(1));
      expect(c.active.where((m) => m.speaking(1.3)).single.line.id, 'warn.h0');
      _run(c, 1.3, 6);
      expect(c.history.last, 'big.h0', reason: 'the queued line still plays');
    });

    test('cooldowns, chance and variants', () {
      final c = _director(
        human: {
          'rare': _spec('rare', 2, [_h('rare.h0', 'p1')], chance: 0),
          'sectorStart': _spec('sectorStart', 4, [_h('g.h0', 'cmd')]),
          'sectorStart.2': _spec('sectorStart.2', 4, [_h('s2.h0', 'cmd')]),
        },
        demon: const {},
      );
      c.handle(const GameEvent('rare'), 0);
      c.handle(const GameEvent('sectorStart', {'variant': '2'}), 0);
      _run(c, 0, 3);
      expect(c.history, ['s2.h0']);
      expect(c.sector, 2);
    });

    test(
      'a burst of calls queues and drains in priority order, nothing cut',
      () {
        final c = _director();
        c.handle(const GameEvent('brief'), 0);
        c.handle(const GameEvent('help'), 0);
        c.handle(const GameEvent('chatter'), 0);
        final voices = _run(c, 0, 20);
        expect(voices.every((v) => v.length <= 1), isTrue);
        expect(c.interruptedLines, isEmpty);
        expect(c.history.first, 'help.h0');
        expect(c.history, containsAll(['brief.h0', 'help.d0']));
      },
    );

    test('random storm: one voice at a time, gaps respected, no cutoffs', () {
      final c = _director();
      final rng = math.Random(3);
      double lastEnd = -10;
      String? speaking;
      for (var t = 0.0; t < 120; t += .05) {
        if (rng.nextDouble() < .03) {
          c.handle(
            GameEvent(
              ['chatter', 'brief', 'help', 'win', 'taunt'][rng.nextInt(5)],
            ),
            t,
          );
        }
        c.update(t);
        final now = [
          for (final m in c.active)
            if (m.speaking(t) && !m.overlap) m,
        ];
        expect(now.length, lessThanOrEqualTo(1));
        if (now.isNotEmpty && now.single.line.id != speaking) {
          expect(
            now.single.startedAt - lastEnd,
            greaterThanOrEqualTo(c.lineGap - .06),
          );
          speaking = now.single.line.id;
        }
        if (now.isNotEmpty) lastEnd = now.single.speechEndsAt;
        expect(c.queue.length, lessThanOrEqualTo(c.maxQueued));
      }
      expect(c.interruptedLines, isEmpty);
    });
  });

  group('exchanges', () {
    test('our line, then the boss answers; the channel is reserved', () {
      final c = _director();
      c.handle(const GameEvent('win'), 0);
      c.update(0);
      expect(c.history, ['win.h0']);
      final opening = c.active.single;
      expect(identical(opening.reply!.inReplyTo, opening), isTrue);
      // Another call arrives mid-exchange: it must wait for the answer.
      c.handle(const GameEvent('help'), .5);
      _run(c, .5, 12);
      final i = c.history.indexOf('win.d0');
      expect(i, 1, reason: '${c.history}');
      expect(c.history.indexOf('help.h0'), greaterThan(i));
    });

    test('the brood taunts first, our retort answers', () {
      final c = _director();
      c.handle(const GameEvent('taunt'), 0);
      _run(c, 0, 6);
      expect(c.history.take(2), ['taunt.d0', 'taunt.h0']);
    });

    test('an urgent warning cutting the first turn cancels the reply', () {
      final c = _director();
      c.handle(const GameEvent('win'), 0);
      c.update(0);
      c.handle(const GameEvent('warn'), .3);
      _run(c, .3, 8);
      expect(c.interruptedLines, ['win.h0']);
      expect(c.history, isNot(contains('win.d0')));
    });
  });

  group('the brood gets airtime', () {
    test('demon lines get a boost while under their share', () {
      final c = _director();
      // Fill the queue with equal-priority human and demon lines.
      c.handle(const GameEvent('brief'), 0); // 4
      _run(c, 0, .1);
      c.handle(const GameEvent('taunt'), .2); // demon first, 4
      _run(c, .2, 10);
      final firstDemon = c.history.indexWhere((id) => id.contains('.d'));
      expect(firstDemon, 1, reason: '${c.history}');
    });

    test('the starvation timer brings in brood chatter during combat', () {
      final c = _director(starveAfter: 6);
      for (var t = 0.0; t < 20; t += .1) {
        if ((t * 10).round() % 30 == 0) c.handle(const GameEvent('brief'), t);
        c.update(t, combat: true);
      }
      expect(c.history.where((id) => id.startsWith('bc.')), isNotEmpty);
      expect(c.demonShareNow, greaterThan(0));
    });

    test('regroup celebration overlaps briefly, capped', () {
      final c = _director();
      c.handle(const GameEvent('regroupStart'), 0);
      final voices = _run(c, 0, 2);
      final peak = voices.map((v) => v.length).reduce(math.max);
      expect(peak, inInclusiveRange(2, c.overlapCap));
      // Two speakers on this roster; the real roster adds the minions.
      expect(c.history.where((id) => id.startsWith('rg.')).length, 2);
      expect(c.interruptedLines, isEmpty);
    });
  });

  group('rotating cast and slots', () {
    test('speakers come from the sector roster and rotate', () {
      final c = _director(demon: const {});
      final speakers = <String>[];
      var t = 0.0;
      for (var i = 0; i < 6; i++) {
        c.handle(const GameEvent('brief'), t);
        _run(c, t, t + 3);
        t += 3.1;
      }
      for (final id in c.history) {
        speakers.add(
          id == 'brief.h0'
              ? 'cmd'
              : id == 'brief.h1'
              ? 'p1'
              : 'p2',
        );
      }
      expect(speakers.toSet(), {'cmd', 'p1'}, reason: 'p2 is not on sector 1');
      for (var i = 1; i < speakers.length; i++) {
        expect(speakers[i], isNot(speakers[i - 1]));
      }
    });

    test('air squad left, ground and brood right; speakers keep slots', () {
      final c = _director();
      c.handle(const GameEvent('chatter'), 0);
      _run(c, 0, 3);
      final slotOf = {
        for (final s in c.slots)
          if (s.occupant != null) s.occupant!: s,
      };
      expect(slotOf['p1']!.left, isTrue);
      expect(slotOf['dA']!.left, isFalse);
      c.handle(const GameEvent('help'), 4);
      _run(c, 4, 8);
      final slots = {
        for (final s in c.slots)
          if (s.occupant != null) s.occupant!: s.index,
      };
      expect(c.slots[slots['g1']!].left, isFalse);
      expect(slots['dA'], slotOf['dA']!.index);
    });

    test('a new sector hangs up idle tiles with a disconnect transition', () {
      final c = _director();
      c.handle(const GameEvent('chatter'), 0);
      _run(c, 0, 4);
      c.handle(const GameEvent('sectorStart', {'variant': '2'}), 5);
      expect(c.slots.where((s) => s.occupant != null), isEmpty);
      expect(
        c.slots.where((s) => s.state(5.1) == CommsSlotState.disconnecting),
        isNotEmpty,
      );
    });
  });

  group('lip-sync', () {
    /// Openness levels must move one step per sample, never blip for a
    /// single sample except as a step of a monotone ramp, and end closed.
    void expectSmooth(CommsMouth mouth, String why) {
      final l = mouth.levels;
      expect(mouth.frames.last, CommsFrame.idle, reason: why);
      for (var i = 1; i < l.length; i++) {
        expect(
          (l[i] - l[i - 1]).abs(),
          lessThanOrEqualTo(1),
          reason: '$why: jump at $i in $l',
        );
      }
      var i = 0;
      while (i < l.length) {
        var j = i;
        while (j < l.length && l[j] == l[i]) {
          j++;
        }
        if (j - i < CommsMouth.minHold &&
            i > 0 &&
            j < l.length &&
            l.length > CommsMouth.minHold) {
          expect(
            (l[i - 1] - l[i]).sign,
            (l[i] - l[j]).sign,
            reason: '$why: blip at $i in $l',
          );
        }
        i = j;
      }
    }

    test('eased, no blips, one level per sample, ends closed', () {
      final rng = math.Random(5);
      for (var trial = 0; trial < 200; trial++) {
        final n = 8 + rng.nextInt(50);
        final open = String.fromCharCodes([
          for (var i = 0; i < n; i++) 48 + rng.nextInt(10),
        ]);
        final line = CommsLine(
          id: 'flicker$trial',
          speaker: 'cmd',
          duration: n / 15,
          text: 'x',
          open: open,
        );
        expectSmooth(CommsMouth.of(line), open);
      }
    });

    test('closed to fully open passes through the in-between shapes', () {
      const line = CommsLine(
        id: 'ramp',
        speaker: 'cmd',
        duration: 1,
        text: 'x',
        open: '099999999999990',
      );
      final frames = CommsMouth.of(line).frames;
      final first = frames.indexWhere((f) => f != CommsFrame.idle);
      final opening = <int>[];
      for (final f in frames.skip(first)) {
        if (opening.isEmpty || opening.last != f) opening.add(f);
        if (opening.length == 4) break;
      }
      expect(opening, [
        CommsFrame.talkA,
        CommsFrame.talkB,
        CommsFrame.talkC,
        CommsFrame.talkWide,
      ]);
    });

    test('rounded and spread visemes pick the oo and ee shapes', () {
      const o = CommsLine(
        id: 'vis-o',
        speaker: 'cmd',
        duration: 1,
        text: 'x',
        open: '055555555555550',
        vis: '-oooooooooooo--',
      );
      const e = CommsLine(
        id: 'vis-e',
        speaker: 'cmd',
        duration: 1,
        text: 'x',
        open: '055555555555550',
        vis: '-eeeeeeeeeeee--',
      );
      expect(CommsMouth.of(o).frames, contains(CommsFrame.talkD));
      expect(CommsMouth.of(e).frames, contains(CommsFrame.talkEe));
    });

    test('the cross-fade eases into each new shape', () {
      const line = CommsLine(
        id: 'blend',
        speaker: 'cmd',
        duration: 1,
        text: 'x',
        open: '099999999999990',
      );
      final mouth = CommsMouth.of(line);
      final i = mouth.frames.indexWhere((f) => f != CommsFrame.idle);
      final t = (i + 1e-6) / CommsMouth.fps;
      final (from, to, start) = mouth.blendAt(t);
      expect(from, isNot(to));
      expect(start, closeTo(0, .001));
      expect(mouth.blendAt(t + CommsMouth.blend / 2).$3, closeTo(.5, .01));
      expect(mouth.blendAt(t + CommsMouth.blend).$3, 1);
    });

    test(
      'every shipped clip has a smooth track that uses the in-between shapes',
      () {
        var withMiddle = 0, humans = 0;
        for (final spec in [
          ...commsHumanTriggers.values,
          ...commsDemonTriggers.values,
        ]) {
          for (final line in spec.lines) {
            final mouth = CommsMouth.of(line);
            expect(mouth.frames, isNotEmpty);
            expectSmooth(mouth, line.id);
            if (!line.isGrunt && line.open.isNotEmpty) {
              humans++;
              if (mouth.levels.toSet().length >= 4) withMiddle++;
            }
          }
        }
        // Nearly every spoken line moves through at least three open levels.
        if (humans > 0) expect(withMiddle / humans, greaterThan(.9));
      },
    );
  });
  group('comms v4 brood voices', () {
    test('battle cries on divePrep: many voices, no immediate repeat, nothing cut', () {
      final d = CommsDirector(random: math.Random(3));
      d.setSector(3, 0);
      for (var t = 0.0; t < 600; t += .1) {
        final tick = (t * 10).round();
        if (tick % 23 == 0) d.handle(const GameEvent(GameEventNames.divePrep), t);
        if (tick % 170 == 5) d.handle(const GameEvent(GameEventNames.waveStart), t);
        d.update(t, combat: true);
      }
      final cries = d.history.where((id) => id.startsWith('divePrep.d')).toList();
      expect(cries.length, greaterThan(20));
      expect(cries.toSet().length, greaterThanOrEqualTo(8));
      for (var i = 1; i < cries.length; i++) {
        expect(cries[i], isNot(cries[i - 1]), reason: 'repeat at $i');
      }
      final voices = {
        for (final id in cries)
          commsDemonTriggers['divePrep']!.lines.firstWhere((l) => l.id == id).speaker,
      };
      expect(voices.length, greaterThanOrEqualTo(5), reason: '$voices');
      expect(voices.intersection(commsMinions.toSet()).length, greaterThanOrEqualTo(4));
      expect(d.interruptedLines, isEmpty);
    });

    test('battle cries are short enough to land before the dive', () {
      for (final line in commsDemonTriggers['divePrep']!.lines) {
        expect(line.duration, lessThanOrEqualTo(.9), reason: line.id);
      }
      expect(commsDemonTriggers['divePrep']!.overlap, isTrue);
    });

    test('reinforcements: the brood cheers with two different voices', () {
      final d = CommsDirector(random: math.Random(8));
      d.setSector(2, 0);
      d.handle(const GameEvent(GameEventNames.reinforcements), 0);
      for (var t = 0.0; t < 15; t += .05) {
        d.update(t);
      }
      final cheers = [
        for (final id in d.history.where((id) => id.startsWith('reinforcements.d')))
          commsDemonTriggers['reinforcements']!.lines.firstWhere((l) => l.id == id).speaker,
      ];
      expect(cheers.length, 2, reason: '${d.history}');
      expect(cheers.toSet().length, 2);
      expect(d.interruptedLines, isEmpty);
    });

    test('the ground war v4 events are voiced (the tide only on a surge)', () {
      for (final name in GameEventNames.groundWarV4) {
        final key = name == GameEventNames.groundTide ? '$name.surge' : name;
        expect(commsHumanTriggers[key]?.lines, isNotEmpty, reason: key);
        expect(commsHumanTriggers[key]!.group, 'ground', reason: key);
      }
      expect(commsHumanTriggers[GameEventNames.groundTide], isNull);
      expect(commsDemonTriggers['heavyArmorSighted']?.lines, isNotEmpty);
      expect(commsDemonTriggers['groundTide.surge']?.lines, isNotEmpty);
      final d = CommsDirector(random: math.Random(2));
      // The surge line has a chance below 1: a few tides, past its cooldown.
      for (var k = 0; k < 8 && d.history.isEmpty; k++) {
        d.handle(
          const GameEvent(GameEventNames.groundTide, {'variant': 'surge'}),
          k * 40.0,
        );
        d.update(k * 40.0);
      }
      expect(d.history.first, startsWith('groundTide.surge.h'));
    });

    test('several distinct minion timbres', () {
      expect(commsMinions.toSet(), containsAll(['skritch', 'grunnok', 'blatch', 'nibb', 'krag', 'sliss']));
    });
  });
  group('shipped line bank', () {
    test('large and varied, every speaker in the cast', () {
      final lines = [
        for (final spec in commsHumanTriggers.values) ...spec.lines,
      ];
      expect(lines.length, greaterThanOrEqualTo(300));
      for (final spec in [
        ...commsHumanTriggers.values,
        ...commsDemonTriggers.values,
      ]) {
        expect(spec.lines.length, inInclusiveRange(2, 30), reason: spec.name);
        for (final line in spec.lines) {
          expect(commsCast, contains(line.speaker));
          expect(
            line.isGrunt,
            commsCast[line.speaker]!.isDemon,
            reason: line.id,
          );
        }
      }
      for (final line in lines) {
        expect(line.emotion, isNotNull, reason: line.id);
      }
    });

    test('no screen or device words in any line (immersive language only)', () {
      final bank = jsonDecode(
        File('art/comms/lines.json').readAsStringSync(),
      ) as Map<String, dynamic>;
      final banned = RegExp(
        r'\b(screen|screens|phone|display|tap|swipe|button|hud|ui|click)\b',
        caseSensitive: false,
      );
      for (final MapEntry(:key, :value)
          in (bank['triggers'] as Map<String, dynamic>).entries) {
        final spec = value as Map<String, dynamic>;
        for (final line in [
          ...spec['lines'] as List,
          ...((spec['demon'] as Map?)?['lines'] as List? ?? const []),
        ]) {
          for (final field in ['text', 'gloss']) {
            final text = (line as Map)[field] as String?;
            if (text == null) continue;
            expect(banned.hasMatch(text), isFalse, reason: '$key: $text');
          }
        }
      }
      for (final spec in commsHumanTriggers.values) {
        for (final line in spec.lines) {
          expect(banned.hasMatch(line.text!), isFalse, reason: line.id);
        }
      }
    });

    test('only true gameplay-critical warnings may cut a line', () {
      final urgent = {
        for (final s in [
          ...commsHumanTriggers.values,
          ...commsDemonTriggers.values,
        ])
          if (s.urgent) s.name,
      };
      expect(urgent, {'sentinelDive', 'shieldExpiring', 'groundBreakthrough'});
    });

    test('shield and loot chatter no longer dominate', () {
      // A typical busy minute: frequent pickups and shields, a steady ground
      // war, a few dives and waves. Count started lines per family.
      final c = CommsDirector(random: math.Random(11))
        ..setLineup(CommsLineup.pick(11));
      c.handle(const GameEvent('sectorStart', {'variant': '3'}), 0);
      final loot = {
        'weaponPickup',
        'shieldCollected',
        'shieldSpotted',
        'salvage',
        'homingPickup',
        'extraLife',
        'shieldBroken',
      };
      final ground = {
        'groundForceSighted',
        'groundUnitDestroyed',
        'allyUnderAttack',
        'allySaved',
        'groundPressureRising',
        'groundMissileLaunch',
        'terrainAhead',
        'convoyClimbing',
      };
      final rng = math.Random(2);
      // The model fires divePrep before every dive (v4 battle cries); its
      // own generator keeps the other events' sequence unchanged.
      final dives = math.Random(5);
      for (var t = 0.0; t < 300; t += .1) {
        if (dives.nextDouble() < .02) {
          c.handle(const GameEvent(GameEventNames.divePrep), t);
        }
        if (rng.nextDouble() < .03) {
          c.handle(
            GameEvent(GameEventNames.weaponPickup, {
              'variant': ['spread', 'rapid', 'large'][rng.nextInt(3)],
            }),
            t,
          );
        }
        if (rng.nextDouble() < .02) {
          c.handle(const GameEvent('shieldCollected'), t);
        }
        if (rng.nextDouble() < .02) {
          c.handle(const GameEvent('shieldSpotted'), t);
        }
        if (rng.nextDouble() < .03) {
          c.handle(
            GameEvent(ground.elementAt(rng.nextInt(ground.length)), {
              'by': 'allies',
              'kind': 'ridge',
            }),
            t,
          );
        }
        if (rng.nextDouble() < .01) c.handle(const GameEvent('diveWarning'), t);
        if (rng.nextDouble() < .005) c.handle(const GameEvent('waveStart'), t);
        c.update(t, combat: true);
      }
      String family(String id) =>
          id.substring(0, id.lastIndexOf('.')).split('.').first;
      final started = c.history.map(family).toList();
      final lootShare = started.where(loot.contains).length / started.length;
      final groundShare =
          started.where(ground.contains).length / started.length;
      expect(lootShare, lessThan(.3), reason: '$started');
      expect(groundShare, greaterThan(lootShare));
      expect(c.demonShareNow, greaterThan(.15), reason: 'the brood is heard');
      expect(c.interruptedLines, isEmpty);
    });

    test('new events plug in by name', () {
      for (final name in [
        GameEventNames.regroupStart,
        GameEventNames.broodTaunt,
        GameEventNames.demonRout,
        GameEventNames.broodChatter,
      ]) {
        expect(commsDemonTriggers, contains(name));
      }
      for (final name in [
        GameEventNames.playerRespawn,
        GameEventNames.terrainAhead,
        'terrainAhead.forest',
        GameEventNames.convoyClimbing,
        GameEventNames.convoyClearingVegetation,
        GameEventNames.convoyStuck,
        GameEventNames.groundMissileLaunch,
        GameEventNames.groundPressureEased,
        'transmissionMission.3',
        GameEventNames.transmissionJunior,
      ]) {
        expect(commsHumanTriggers, contains(name));
      }
      expect(
        commsHumanTriggers['playerRespawn']!.lines.length,
        greaterThanOrEqualTo(10),
      );
      expect(commsHumanTriggers['transmissionJunior']!.transmission, isTrue);
      expect(commsDemonTriggers['regroupStart']!.overlap, isTrue);
      expect(commsHumanTriggers['levelClear']!.exchange, CommsSide.fleet);
      expect(commsHumanTriggers['broodTaunt']!.exchange, CommsSide.demon);
    });
  });
}
