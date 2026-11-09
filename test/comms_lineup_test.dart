import 'dart:math' as math;

import 'package:demon_attack/comms/comms_bank.dart';
import 'package:demon_attack/comms/comms_director.dart';
import 'package:demon_attack/comms/comms_lineup.dart';
import 'package:demon_attack/comms/comms_types.dart';
import 'package:demon_attack/comms/squad_comms.dart';
import 'package:demon_attack/game/model.dart';
import 'package:demon_attack/services/run_storage.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('per-run lineup', () {
    test('cast is large and diverse in role; the Admiral anchors', () {
      final humans = commsCast.values.where((c) => !c.isDemon).toList();
      expect(humans.length, inInclusiveRange(10, 14));
      expect(commsCast[commsAnchor]!.rank, contains('ADM'));
      expect(commsFleetPool, isNot(contains(commsAnchor)));
      expect(commsGroundPool.length, greaterThanOrEqualTo(2));
      expect(commsCast.values.where((c) => c.isDemon).length, 5);
    });

    test('a seed always picks the same lineup', () {
      final a = CommsLineup.pick(42), b = CommsLineup.pick(42);
      expect(a.fleet, b.fleet);
      expect(a.ground, b.ground);
      expect(a.fleet.length, commsLineupFleet);
      expect(a.ground.length, commsLineupGround);
      expect(a.members, contains(commsAnchor));
      expect(CommsLineup.pick(43).members, isNot(a.members));
    });

    test('consecutive runs avoid repeating the previous lineup', () {
      var previous = CommsLineup.pick(1);
      for (var seed = 2; seed < 60; seed++) {
        final next = CommsLineup.pick(seed, previous: previous);
        expect({
          ...next.fleet,
          ...next.ground,
        }, isNot({...previous.fleet, ...previous.ground}));
        expect(next.overlap(previous), lessThanOrEqualTo(3));
        previous = next;
      }
    });

    test('rosters rotate pilots per sector and keep the Admiral', () {
      final lineup = CommsLineup.pick(7);
      final seen = <String>{};
      for (var s = 1; s <= 5; s++) {
        final fleet = lineup.roster[s]![CommsSide.fleet]!;
        expect(fleet.first, commsAnchor);
        seen.addAll(fleet);
        expect(lineup.roster[s]![CommsSide.demon], commsDemonSectors[s]);
      }
      expect(seen, containsAll(lineup.fleet));
      expect(
        lineup.roster[1]![CommsSide.fleet],
        isNot(lineup.roster[2]![CommsSide.fleet]),
      );
    });

    test('saved lineups resume; new runs re-seed', () {
      final store = MemoryLocalStore();
      final comms = SquadComms(playAudio: false);
      final first = comms.startRun(store, seed: 11);
      final resumed = comms.startRun(store, resume: true);
      expect(resumed.seed, first.seed);
      final next = comms.startRun(store, seed: 12);
      expect({
        ...next.fleet,
        ...next.ground,
      }, isNot({...first.fleet, ...first.ground}));
      expect(comms.director.reserve, next.members);
      expect(
        CommsLineup.fromJson({
          'seed': 1,
          'fleet': ['nobody'],
        }),
        isNull,
      );
    });

    test(
      'lines come from this run\'s crew, and different runs sound different',
      () {
        final speakersByRun = <Set<String>>[];
        for (final seed in [3, 4]) {
          final c = CommsDirector(random: math.Random(seed))
            ..setLineup(CommsLineup.pick(seed));
          final speakers = <String>{};
          var t = 0.0;
          for (var round = 0; round < 40; round++) {
            for (final name in [
              'waveStart',
              'reinforcements',
              'levelClear',
              'diveWarning',
            ]) {
              c.handle(GameEvent(name), t);
              for (var k = 0; k < 6; k++) {
                t += .5;
                c.update(t);
              }
            }
            t += 30;
            c.update(t);
          }
          for (final id in c.history.where((id) => id.contains('.h'))) {
            final line = commsHumanTriggers.values
                .expand((s) => s.lines)
                .firstWhere((l) => l.id == id);
            speakers.add(line.speaker);
          }
          final members = CommsLineup.pick(seed).members;
          expect(speakers.difference(members), isEmpty, reason: 'seed $seed');
          speakersByRun.add(speakers);
        }
        expect(speakersByRun[0], isNot(speakersByRun[1]));
      },
    );
  });

  group('personality and celebrations', () {
    test('signature lines are rationed', () {
      const sig = CommsTriggerSpec(
        name: 'joke',
        priority: 3,
        cooldown: 0,
        ttl: 2,
        lines: [
          CommsLine(
            id: 'joke.h0',
            speaker: 'rook',
            duration: 1,
            text: 'pun',
            signature: true,
          ),
          CommsLine(id: 'joke.h1', speaker: 'rook', duration: 1, text: 'plain'),
        ],
      );
      final c = CommsDirector(
        random: math.Random(1),
        human: {'joke': sig},
        demon: const {},
        roster: {
          1: {
            CommsSide.fleet: ['rook'],
          },
        },
        reserve: {'rook'},
      );
      var t = 0.0;
      for (var i = 0; i < 20; i++) {
        c.handle(const GameEvent('joke'), t);
        c.update(t);
        t += 4;
        c.update(t);
      }
      final puns = c.history.where((id) => id == 'joke.h0').length;
      expect(puns, inInclusiveRange(1, 1 + (80 ~/ CommsDirector.signatureGap)));
    });

    test('a flawless victory chains crew lines and raises the banner', () {
      final c = CommsDirector(random: math.Random(5))
        ..setLineup(CommsLineup.pick(5));
      c.handle(const GameEvent(GameEventNames.flawlessVictory), 0);
      expect(c.celebrating(1), isTrue);
      expect(c.celebrating(CommsDirector.celebration + .1), isFalse);
      final spec = commsHumanTriggers[GameEventNames.flawlessVictory]!;
      var t = 0.0;
      while (t < 30) {
        c.update(t);
        t += .1;
      }
      final lines = c.history.where((id) => id.startsWith('flawlessVictory.h'));
      expect(lines.length, greaterThanOrEqualTo(2));
      expect(lines.length, lessThanOrEqualTo(1 + spec.chain));
      final speakers = {
        for (final id in lines)
          spec.lines.firstWhere((l) => l.id == id).speaker,
      };
      expect(speakers.length, lines.length, reason: 'each from someone else');
    });

    test('the mood face holds after a line', () {
      final c = CommsDirector(random: math.Random(2));
      c.handle(const GameEvent(GameEventNames.levelClear), 0);
      c.update(0);
      final m = c.active.firstWhere((m) => !m.isDemon);
      final slot = c.slots[m.slot];
      expect(slot.mood, CommsMood.happy);
      expect(
        slot.moodUntil,
        closeTo(m.line.duration + CommsDirector.moodHold, 1e-9),
      );
    });

    test(
      'allies never die: losses read as retreats and break the flawless streak',
      () {
        for (final spec in commsHumanTriggers.values) {
          for (final line in spec.lines) {
            final text = line.text!.toLowerCase();
            for (final word in [
              ' dead',
              ' died',
              ' killed',
              ' die ',
              'rest in',
              'fallen',
              'grief',
            ]) {
              expect(text.contains(word), isFalse, reason: '${line.id}: $text');
            }
          }
        }
        expect(
          commsHumanTriggers[GameEventNames.allyRetreated]!.lines.first.text,
          contains('totalled'),
        );
        final model = ArcadeModel()..start();
        final o = GameEventObserver(model, dispatch: false);
        o.observe(model.takeEvents());
        List<String> names(List<String> raw) => [
          for (final e in o.observe(raw)) e.name,
        ];
        List<String> queued(String scope) => [
          for (final e in o.onGameEvent(
            GameEvent(GameEventNames.fleetIntact, {'scope': scope}),
          ))
            e.name,
        ];
        // The model reports fleetIntact (ground allies held); the squad
        // also has to keep every ship.
        expect(queued('level'), [GameEventNames.flawlessSector]);
        expect(names(['life']), contains(GameEventNames.lifeLost));
        expect(queued('level'), isEmpty, reason: 'a ship was totalled');
        expect(names(['level']), contains(GameEventNames.sectorStart));
        expect(queued('level'), [GameEventNames.flawlessSector]);
        expect(
          names(['victory']),
          isNot(contains(GameEventNames.flawlessVictory)),
          reason: 'the tour lost a ship',
        );
        expect(names(['allyLost']), [GameEventNames.allyRetreated]);
        expect(
          o.onGameEvent(const GameEvent(GameEventNames.allyRetreated)),
          isEmpty,
        );
        expect(
          names(['victory']),
          isNot(contains(GameEventNames.flawlessVictory)),
          reason: 'the next tour lost a ground unit',
        );
        expect(
          names(['victory']),
          contains(GameEventNames.flawlessVictory),
          reason: 'a clean tour',
        );
        expect(queued('campaign'), isEmpty);
        o.reset();
        expect(queued('campaign'), [GameEventNames.flawlessRun]);
        o.reset(freshRun: false);
        expect(
          queued('campaign'),
          isEmpty,
          reason: 'a resumed run cannot prove its earlier sectors',
        );
      },
    );
  });
}
