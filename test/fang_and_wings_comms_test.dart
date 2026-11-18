/// "Fang and Wings!": the brood's creed on the radio and the dive war cries
/// (openspec/changes/fang-and-wings-comms).
library;

import 'dart:math' as math;

import 'package:demon_attack/comms/comms_bank.dart';
import 'package:demon_attack/comms/comms_creed.dart';
import 'package:demon_attack/comms/comms_director.dart';
import 'package:demon_attack/comms/comms_moments.dart';
import 'package:demon_attack/comms/comms_one_line.dart';
import 'package:demon_attack/comms/comms_types.dart';
import 'package:demon_attack/game/dive_cry.dart';
import 'package:demon_attack/game/model.dart';
import 'package:flutter_test/flutter_test.dart';

const _ranks = BroodRank.values;

Map<String, Object?> _prep(
  BroodRank rank, {
  int kind = 0,
  double diveIn = 1.2,
}) => {
  'lead': .5,
  'tellIn': .5,
  'diveIn': diveIn,
  'x': 120.0,
  'y': 90.0,
  'sentinel': rank == BroodRank.sentinel,
  'elite': rank == BroodRank.hunter,
  'kind': rank == BroodRank.grunt ? kind.clamp(0, 1) : kind,
  'maxHp': switch (rank) {
    BroodRank.grunt => 1,
    BroodRank.veteran => 4,
    _ => 3,
  },
};

void main() {
  final demonBank = commsDemonBank(commsDemonTriggers);

  group('ranks and species', () {
    test('the cry ladder follows the marks', () {
      BroodRank of({
        bool sentinel = false,
        bool elite = false,
        int kind = 0,
        int maxHp = 1,
        String? mark,
      }) => BroodRank.of(
        sentinel: sentinel,
        elite: elite,
        kind: kind,
        maxHp: maxHp,
        mark: mark,
      );
      // Without the insignia-ranks mark: the fields' stand-in.
      expect(of(), BroodRank.grunt);
      expect(of(kind: 2, maxHp: 3), BroodRank.grunt);
      expect(of(maxHp: 4), BroodRank.veteran);
      expect(of(elite: true, kind: 3, maxHp: 3), BroodRank.hunter);
      expect(of(sentinel: true, elite: true), BroodRank.sentinel);
      // With it, the mark decides: the cry says what the head shows.
      expect(of(kind: 2, maxHp: 4, mark: 'none'), BroodRank.grunt);
      expect(of(kind: 2, mark: 'winglet'), BroodRank.veteran);
      expect(of(kind: 3, mark: 'crownlet'), BroodRank.veteran);
      expect(of(elite: true, mark: 'fangWings'), BroodRank.hunter);
      expect(of(sentinel: true, mark: 'wingCrown'), BroodRank.sentinel);
      expect(broodSpecies, ['teal', 'violet', 'coral', 'gold']);
      expect(broodSpeciesOf(7), 'gold');
    });

    test('the model tells the radio the diver\'s species and toughness', () {
      final m = ArcadeModel(seed: 7)..startAt(sector: 3, route: 1);
      while (!m.combat) {
        m.update(1 / 60);
      }
      m.takeGameEvents();
      GameEvent? prep;
      for (var i = 0; i < 60 * 40 && prep == null; i++) {
        m.invulnerable = 2;
        m.shots.removeWhere((s) => !s.hostile);
        m.update(1 / 60);
        prep = m
            .takeGameEvents()
            .where((e) => e.name == GameEventNames.divePrep)
            .firstOrNull;
      }
      expect(prep, isNotNull);
      final data = prep!.data;
      expect(data['kind'], isA<int>());
      expect(data['maxHp'], isA<int>());
      expect(data['tellIn'] as double, greaterThan(0));
      expect(data['tellIn'] as double, lessThan(data['diveIn'] as double));
    });

    test('the observer turns some dive preps into a diveCry', () {
      final m = ArcadeModel()..start();
      final observer = GameEventObserver(m, dispatch: false);
      final cries = <GameEvent>[];
      for (var i = 0; i < 40; i++) {
        m.clock = i * 10.0;
        cries.addAll(
          observer.onGameEvent(
            GameEvent(GameEventNames.divePrep, _prep(BroodRank.sentinel)),
          ),
        );
      }
      expect(cries, isNotEmpty);
      final cry = cries.first;
      expect(cry.name, GameEventNames.diveCry);
      expect(cry.variant, 'sentinel');
      for (final key in [
        'rank',
        'species',
        'kind',
        'x',
        'y',
        'diveIn',
        'tellIn',
        'intensity',
        'cry',
        'clock',
      ]) {
        expect(cry.data.containsKey(key), isTrue, reason: key);
      }
      expect(cry.data['intensity'], 1.0);
      observer.reset();
      expect(observer.diveCries.count, 0);
    });
  });

  group('cry gate', () {
    test('few dives cry: one in flight, a gap between, the same per seed', () {
      List<(double, String)> run(int seed) {
        final gate = DiveCryGate(seed: seed);
        final rng = math.Random(seed);
        final out = <(double, String)>[];
        // A swarm diving every 0.3-1 s for ten minutes.
        for (var t = 0.0; t < 600; t += .3 + rng.nextDouble() * .7) {
          final rank = _ranks[rng.nextInt(_ranks.length)];
          final cry = gate.consider(_prep(rank, kind: rng.nextInt(4)), t);
          if (cry != null) out.add((t, cry['rank'] as String));
        }
        return out;
      }

      final cries = run(3);
      expect(run(3), cries);
      expect(cries.length, greaterThan(30));
      // At least minGap apart, and never while the last one is in flight.
      for (var i = 1; i < cries.length; i++) {
        final gap = cries[i].$1 - cries[i - 1].$1;
        expect(gap, greaterThanOrEqualTo(DiveCryGate.minGap - 1e-9));
        expect(gap, greaterThanOrEqualTo(1.2 + DiveCryGate.hold - 1e-9));
      }
      // About one dive in eight cries in a swarm.
      expect(cries.length / (600 / .65), lessThan(.2));
    });

    test('cries favour the higher ranks', () {
      final asked = {for (final r in _ranks) r: 0};
      final cried = {for (final r in _ranks) r: 0};
      final gate = DiveCryGate(seed: 9);
      final rng = math.Random(9);
      var t = 0.0;
      for (var i = 0; i < 8000; i++) {
        final rank = _ranks[rng.nextInt(_ranks.length)];
        // Space the preps so the gap never decides: only the rank's chance.
        t += DiveCryGate.minGap + 2;
        asked[rank] = asked[rank]! + 1;
        if (gate.consider(_prep(rank), t) != null) {
          cried[rank] = cried[rank]! + 1;
        }
      }
      double share(BroodRank r) => cried[r]! / asked[r]!;
      for (var i = 1; i < _ranks.length; i++) {
        expect(share(_ranks[i]), greaterThan(share(_ranks[i - 1]) + .1));
      }
      for (final r in _ranks) {
        expect(share(r), closeTo(DiveCryGate.chance[r]!, .05), reason: '$r');
      }
    });

    test('a prep without a dive time never cries', () {
      final gate = DiveCryGate();
      expect(gate.consider(const {'sentinel': true}, 0), isNull);
      expect(gate.consider(const {'sentinel': true, 'diveIn': 0}, 0), isNull);
    });
  });

  group('cry lines', () {
    test('every rank has lines for every species, short enough', () {
      for (final rank in _ranks) {
        final spec = demonBank['diveCry.${rank.name}'];
        expect(spec, isNotNull, reason: rank.name);
        for (var kind = 0; kind < 4; kind++) {
          final lines = commsCryLines(spec!, kind);
          expect(lines.length, greaterThanOrEqualTo(3), reason: '$rank $kind');
          expect(
            lines.any((l) => l.speaker == commsSpeciesVoice[kind]),
            isTrue,
            reason: '$rank: the ${broodSpecies[kind]} voice',
          );
          // No other species' voice.
          for (final l in lines) {
            expect(
              l.speaker == commsSpeciesVoice[kind] ||
                  !commsSpeciesVoice.contains(l.speaker),
              isTrue,
              reason: l.id,
            );
          }
        }
        for (final l in spec!.lines) {
          expect(commsCast.containsKey(l.speaker), isTrue, reason: l.id);
          expect(l.gloss!.length, lessThanOrEqualTo(commsOneLineMax));
        }
      }
    });

    test('grunts squeak, veterans roar, hunters snarl, sentinels intone', () {
      List<CommsLine> written(BroodRank r) => [
        for (final l in demonBank['diveCry.${r.name}']!.lines)
          if (l.id.startsWith('diveCry.')) l,
      ];
      expect(
        written(BroodRank.grunt).map((l) => l.grunt).toSet(),
        everyElement(isIn(['cackle', 'warcry'])),
      );
      expect(written(BroodRank.veteran).map((l) => l.grunt).toSet(), {'roar'});
      expect(written(BroodRank.hunter).map((l) => l.grunt).toSet(), {'snarl'});
      for (final l in written(BroodRank.sentinel)) {
        expect(
          l.gloss!.replaceAll(RegExp('[^A-Z ]'), ''),
          contains('FANG AND W'),
          reason: l.id,
        );
      }
      expect(
        written(BroodRank.hunter).where((l) => l.gloss!.contains('Fang and')),
        isNotEmpty,
      );
      // The recorded cries keep their voices in the lower ranks.
      expect(
        demonBank['diveCry.grunt']!.lines.any(
          (l) => l.id.startsWith('divePrep.'),
        ),
        isTrue,
      );
      expect(
        demonBank['diveCry.veteran']!.lines.any(
          (l) => l.id.startsWith('divePrep.'),
        ),
        isTrue,
      );
    });

    test('the creed is a topic on both sides, and borrows no voice', () {
      final creed = [
        for (final name in [
          'diveCry.grunt',
          'diveCry.veteran',
          'diveCry.hunter',
          'diveCry.sentinel',
          'fangChatter',
          'fangBanter',
          'fangTease',
          'spearThrow',
        ])
          for (final bank in [commsHumanTriggers, commsDemonTriggers])
            ...?bank[name]?.lines,
      ];
      expect(creed.length, greaterThan(80));
      for (final l in creed) {
        // Written lines until voices land: their own words, no placeholder.
        expect(l.clip, l.id, reason: l.id);
        expect(l.silent, isTrue, reason: l.id);
        expect(commsCast.containsKey(l.speaker), isTrue, reason: l.id);
      }
      final squad = commsHumanTriggers['fangBanter']!.lines;
      expect(squad.map((l) => l.text), contains(contains('Flap and Whine')));
      expect(
        commsDemonTriggers['fangChatter']!.lines.map((l) => l.gloss),
        contains(contains('Earn your wings')),
      );
      // Spear-bearers' throw shouts, spearThrow.d0-d5.
      expect(commsDemonTriggers['spearThrow']!.lines.map((l) => l.id), [
        for (var i = 0; i < 6; i++) 'spearThrow.d$i',
      ]);
      // Every thread names real lines of its own exchange.
      final ids = {
        for (final name in ['fangBanter', 'fangTease'])
          for (final bank in [commsHumanTriggers, commsDemonTriggers])
            for (final l in bank[name]!.lines) l.id,
      };
      commsCreedThreads.forEach((opening, answers) {
        expect(ids, contains(opening));
        expect(ids, containsAll(answers));
        final trigger = opening.split('.').first;
        for (final a in answers) {
          expect(a.startsWith('$trigger.'), isTrue);
          expect(a[trigger.length + 1], isNot(opening[trigger.length + 1]));
        }
      });
    });
  });

  group('cries on the radio', () {
    CommsDirector director({int seed = 3}) =>
        CommsDirector(random: math.Random(seed))..setSector(3, 0);

    void runTo(CommsDirector d, double from, double to) {
      for (var t = from; t < to; t += 1 / 60) {
        d.update(t);
      }
    }

    test('alone, a cry ends as its dive starts', () {
      final started = <CommsMessage>[];
      final d = director()..onStart = started.add;
      d.handle(
        GameEvent(GameEventNames.diveCry, {
          ..._prep(BroodRank.hunter, kind: 2, diveIn: 1.4),
          'variant': 'hunter',
        }),
        10,
      );
      runTo(d, 10, 14);
      final cry = started.single;
      expect(cry.trigger.name, 'diveCry.hunter');
      expect(cry.isDemon, isTrue);
      expect(cry.speechEndsAt, closeTo(11.4, d.pacing.diveTolerance + 1e-6));
      // A coral diver: Blatch's channel, or a voice of no species.
      expect(cry.line.speaker, isNot(isIn(['skritch', 'grunnok', 'morth'])));
    });

    test('behind the squad\'s dive call, the cry rides the plunge', () {
      for (final seed in [1, 2, 3, 4, 5]) {
        final started = <CommsMessage>[];
        final d = director(seed: seed)..onStart = started.add;
        final prep = _prep(BroodRank.sentinel, kind: 0, diveIn: 1.4);
        // The model's prep and the observer's cry arrive in one batch.
        d.handle(GameEvent(GameEventNames.divePrep, prep), 10);
        d.handle(
          GameEvent(GameEventNames.diveCry, {...prep, 'variant': 'sentinel'}),
          10,
        );
        runTo(d, 10, 16);
        final names = started.map((m) => m.trigger.name).toList();
        expect(names.first, GameEventNames.sentinelDive, reason: '$seed');
        final cry = started.where((m) => m.trigger.name == 'diveCry.sentinel');
        expect(cry, hasLength(1), reason: '$names');
        final squad = started.first;
        expect(cry.single.startedAt, greaterThanOrEqualTo(11.4 - 1e-9));
        expect(cry.single.startedAt, lessThanOrEqualTo(11.4 + commsCryAfter));
        expect(
          cry.single.startedAt,
          greaterThanOrEqualTo(squad.speechEndsAt + d.lineGap - 1e-9),
        );
        expect(cry.single.line.gloss, contains('FANG AND WING'));
        expect(d.plungeCries, 1);
      }
    });

    test('a waiting recommendation drops the cry', () {
      final started = <CommsMessage>[];
      final d = director()..onStart = started.add;
      final prep = _prep(BroodRank.hunter, diveIn: 1.4);
      d.handle(GameEvent(GameEventNames.divePrep, prep), 10);
      d.handle(
        GameEvent(GameEventNames.diveCry, {...prep, 'variant': 'hunter'}),
        10,
      );
      d.update(10);
      d.handle(const GameEvent('shieldSpotted', {'hint': true}), 10.1);
      runTo(d, 10.1, 20);
      expect(
        started.where((m) => m.trigger.name.startsWith('diveCry')),
        isEmpty,
      );
      expect(started.map((m) => m.trigger.name), contains('shieldSpotted'));
    });
  });

  group('banter threads in one combined toast', () {
    test('a brood cry, then a squad comeback written for it', () {
      var threaded = 0, total = 0;
      for (var seed = 0; seed < 40; seed++) {
        final started = <CommsMessage>[];
        final d = CommsDirector(random: math.Random(seed))
          ..onStart = started.add
          ..setSector(2, 0);
        d.handle(const GameEvent(GameEventNames.fangBanter), 5);
        for (var t = 5.0; t < 20; t += 1 / 60) {
          d.update(t);
        }
        expect(started, hasLength(2), reason: 'seed $seed');
        final (opening, answer) = (started[0], started[1]);
        expect(opening.isDemon, isTrue);
        expect(answer.isDemon, isFalse);
        expect(answer.inReplyTo, same(opening));
        expect(identical(opening.reply, answer), isTrue);
        expect(
          answer.startedAt - opening.speechEndsAt,
          closeTo(d.lineGap, .05),
        );
        total++;
        final best = commsCreedThreads[opening.line.id];
        if (best != null && best.contains(answer.line.id)) threaded++;
      }
      // The written answer whenever its speaker is on the line.
      expect(threaded / total, greaterThan(.5));
    });

    test('a squad tease about the marks, then the brood retort', () {
      for (var seed = 0; seed < 10; seed++) {
        final started = <CommsMessage>[];
        final d = CommsDirector(random: math.Random(seed))
          ..onStart = started.add
          ..setSector(4, 0);
        d.handle(const GameEvent(GameEventNames.fangTease), 5);
        for (var t = 5.0; t < 20; t += 1 / 60) {
          d.update(t);
        }
        expect(started, hasLength(2));
        expect(started[0].isDemon, isFalse);
        expect(started[1].isDemon, isTrue);
        expect(started[1].inReplyTo, same(started[0]));
      }
    });

    test('the creed stands in for some brood chatter', () {
      final d = CommsDirector(random: math.Random(4))..setSector(3, 0);
      for (var t = 0.0; t < 900; t += 1 / 20) {
        d.update(t, combat: true);
      }
      final triggers = d.history.map((id) => id.split('.').first).toSet();
      expect(
        triggers,
        containsAll(['broodChatter', 'fangChatter', 'fangBanter']),
      );
      expect(d.interruptedLines, isEmpty);
    });
  });
}
