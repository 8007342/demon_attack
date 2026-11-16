import 'package:demon_attack/comms/comms_bank.dart';
import 'package:demon_attack/comms/comms_briefing.dart';
import 'package:demon_attack/comms/comms_director.dart';
import 'package:demon_attack/comms/comms_types.dart';
import 'package:demon_attack/game/interlude.dart';
import 'package:demon_attack/game/model.dart';
import 'package:flutter_test/flutter_test.dart';

import 'progression_test.dart' show reach;

/// bonus-briefing: the urgent-mission card's script and the bonus levels'
/// banter on the radio channel (openspec/changes/bonus-levels, design
/// "Urgent-mission card"). One voice at a time, nothing cut, the card's
/// own written words.

BonusBriefing _briefing(
  String level, {
  int seed = 0,
  int sector = 3,
  String? modifier,
}) {
  final pick = InterludePlanner(seed: seed).planRadio(
    InterludeContext(
      difficulty: Difficulty.normal,
      level: sector,
      route: 0,
      window: 7.5,
      bonus: level,
    ),
  )!;
  return BonusBriefing(
    level: bonusLevelById(level)!,
    sector: sector,
    invite: pick.radio!.line,
    inviteSpec: pick.radio!.spec,
    modifier: modifier == null ? null : runModifierById(modifier),
    seed: seed,
  );
}

/// Runs [d] from [from] for [seconds] at 60 Hz, recording every start.
List<CommsMessage> _run(
  CommsDirector d,
  double from,
  double seconds, {
  void Function(double t)? each,
}) {
  final started = <CommsMessage>[];
  final previous = d.onStart;
  d.onStart = (m) {
    started.add(m);
    previous?.call(m);
  };
  for (var t = from; t < from + seconds; t += 1 / 60) {
    each?.call(t);
    d.update(t);
  }
  d.onStart = previous;
  return started;
}

/// No two speech windows overlap, and each starts after the grace gap.
void _oneVoice(List<CommsMessage> started, double gap) {
  final sorted = [...started]
    ..sort((a, b) => a.startedAt.compareTo(b.startedAt));
  for (var i = 1; i < sorted.length; i++) {
    expect(
      sorted[i].startedAt,
      greaterThanOrEqualTo(sorted[i - 1].speechEndsAt + gap - 1e-6),
      reason: '${sorted[i]} starts while ${sorted[i - 1]} is on air',
    );
  }
  for (final m in started) {
    expect(m.interrupted, isFalse, reason: '$m was cut');
  }
}

void main() {
  group('script', () {
    for (final level in bonusLevels) {
      test('${level.id}: invite, a squadmate\'s dare, the brood\'s retort', () {
        for (var seed = 0; seed < 12; seed++) {
          final b = _briefing(level.id, seed: seed);
          final parts = b.script();
          expect(parts, hasLength(3), reason: 'seed $seed');
          final (invite, inviteSpec) = parts[0];
          final (dare, dareSpec) = parts[1];
          final (retort, retortSpec) = parts[2];
          expect(inviteSpec.name, 'bonusEntry.${level.id}');
          expect(dareSpec.name, 'bonusDare.${level.id}');
          expect(retortSpec.name, 'bonusDare.${level.id}');
          expect(dare.speaker, isNot(invite.speaker));
          expect(commsCast[invite.speaker]!.isDemon, isFalse);
          expect(commsCast[dare.speaker]!.isDemon, isFalse);
          expect(commsCast[retort.speaker]!.isDemon, isTrue);
          // The brood voice is one on that sector's net, or a minion.
          expect([
            ...commsDemonSectors[3]!,
            ...commsMinions,
          ], contains(retort.speaker));
          // Written lines: their own words, no borrowed voice.
          for (final (line, _) in parts) {
            expect(line.silent, isTrue, reason: line.id);
            expect(line.clip, line.id, reason: line.id);
            expect(line.text ?? line.gloss, isNotEmpty);
          }
        }
      });

      test('${level.id}: the card has a rule to show', () {
        expect(level.brief, isNotEmpty);
        expect(level.brief.length, lessThan(110), reason: 'two short lines');
      });
    }

    test('every run modifier has a run rule for the card', () {
      for (final m in runModifiers) {
        expect(m.brief, isNotEmpty, reason: m.id);
      }
      final b = _briefing('stormfront', modifier: 'noShield');
      expect(b.rule, 'No shield modules this run.');
      expect(_briefing('stormfront').rule, isNull);
    });

    test('the entry call fits the transition slot', () {
      for (final level in bonusLevels) {
        for (final line
            in commsHumanTriggers['bonusEntry.${level.id}']!.lines) {
          final pick = RadioPick(
            commsHumanTriggers['bonusEntry.${level.id}']!,
            line,
            RadioCategory.bonusEntry,
          );
          // The slot's room in a 7.5 s window (fades and adoption wait).
          expect(pick.needs, lessThanOrEqualTo(7.5 - 1 - 1.2), reason: line.id);
        }
      }
    });
  });

  group('sequencing', () {
    test('the turns play one after another, one voice at a time', () {
      for (final level in bonusLevels) {
        for (var seed = 0; seed < 8; seed++) {
          final d = CommsDirector();
          final b = _briefing(level.id, seed: seed);
          expect(b.offer(d, now: 0, ttl: 6), isTrue);
          expect(b.open, isTrue);
          final started = _run(d, 0, 16);
          final script = [
            for (final m in started)
              if (m.scripted) m,
          ];
          expect(script, hasLength(3), reason: '${level.id} seed $seed');
          expect(
            [for (final m in script) m.line.id],
            [for (final m in b.turns) m.line.id],
            reason: 'in order',
          );
          _oneVoice(started, d.lineGap);
          // Each answer follows right after the turn before it.
          for (var i = 1; i < script.length; i++) {
            expect(
              script[i].startedAt - script[i - 1].speechEndsAt,
              lessThan(d.lineGap + .1),
            );
          }
        }
      }
    });

    test('squad chatter waits for the script and never talks over it', () {
      final d = CommsDirector();
      final b = _briefing('supplyRun');
      b.offer(d, now: 0, ttl: 6);
      final started = _run(
        d,
        0,
        18,
        each: (t) {
          // The ordinary transition chatter keeps coming meanwhile.
          if ((t * 60).round() % 90 == 0) {
            d.handle(const GameEvent(GameEventNames.levelClear), t);
            d.handle(const GameEvent(GameEventNames.salvage), t);
          }
        },
      );
      _oneVoice(started, d.lineGap);
      final script = [
        for (final m in started)
          if (m.scripted) m,
      ];
      expect(script, hasLength(3));
      // Nothing else starts between the first turn and the retort.
      final others = [
        for (final m in started)
          if (!m.scripted) m,
      ];
      for (final o in others) {
        expect(
          o.startedAt < script.first.startedAt ||
              o.startedAt >= script.last.speechEndsAt,
          isTrue,
          reason: '$o interleaved with the script',
        );
      }
    });

    test('a hush holds the squad but not the card\'s turns', () {
      final d = CommsDirector()..hush(30, at: 0);
      final b = _briefing('stormfront');
      b.offer(d, now: 0, ttl: 6);
      final started = _run(d, 0, 14);
      expect([
        for (final m in started)
          if (m.scripted) m,
      ], hasLength(3));
    });

    test('a written turn keeps the portrait\'s mouth closed', () {
      final d = CommsDirector();
      final b = _briefing('supplyRun');
      b.offer(d, now: 0, ttl: 6);
      _run(d, 0, 1);
      final m = b.current()!;
      expect(m.speaking(d.now), isTrue);
      expect(m.line.silent, isTrue);
      expect(m.frame(d.now), CommsFrame.idle);
      expect(m.mouthBlend(d.now).$2, CommsFrame.idle);
    });
  });

  group('the card', () {
    test('dismissing it lets the turn on air finish and drops the rest', () {
      final d = CommsDirector();
      final b = _briefing('supplyRun');
      b.offer(d, now: 0, ttl: 6);
      _run(d, 0, 1.5);
      final first = b.turns.first;
      expect(first.started, isTrue);
      final ends = first.endsAt;
      b.dismiss(d, d.now);
      expect(b.open, isFalse);
      expect(b.visible(d.now), isTrue, reason: 'fading');
      expect(b.visible(d.now + BonusBriefing.fade + .01), isFalse);
      final later = _run(d, d.now, 14);
      expect(first.interrupted, isFalse);
      expect(first.endsAt, ends, reason: 'never cut');
      expect([
        for (final m in later)
          if (m.scripted) m,
      ], isEmpty);
      // The channel is free again: the squad speaks after the first turn.
      d.handle(const GameEvent(GameEventNames.levelClear), d.now);
      final after = _run(d, d.now, 6);
      expect(after, isNotEmpty);
    });

    test('it closes when the script has been read', () {
      final d = CommsDirector();
      final b = _briefing('stormfront');
      b.offer(d, now: 0, ttl: 6);
      var closed = double.nan;
      for (var t = 0.0; t < 20; t += 1 / 60) {
        d.update(t);
        b.update(d, t, flying: true, flightLeft: 30, combat: false);
        if (!b.open && closed.isNaN) closed = t;
      }
      expect(closed.isNaN, isFalse);
      expect(closed, greaterThanOrEqualTo(b.turns.last.endsAt - 1e-6));
    });

    test('it is gone before the fight gets busy', () {
      final d = CommsDirector();
      final b = _briefing('supplyRun');
      b.offer(d, now: 0, ttl: 6);
      // The Descent ends at 4 s; combat follows.
      double? closed;
      for (var t = 0.0; t < 10; t += 1 / 60) {
        d.update(t);
        final flying = t < 4;
        b.update(
          d,
          t,
          flying: flying,
          flightLeft: flying ? 4 - t : 0,
          combat: !flying,
        );
        if (!b.open) {
          closed ??= t;
        }
      }
      expect(closed, isNotNull);
      expect(closed!, lessThanOrEqualTo(4 + BonusBriefing.combatGrace + .05));
      expect(
        b.visible(4 + BonusBriefing.combatGrace + BonusBriefing.fade + .05),
        isFalse,
      );
      // Unplayed turns were withdrawn, not left to talk over the fight.
      expect(d.queue.where((m) => m.scripted), isEmpty);
    });

    test('reduced motion: no fade, the card is simply up or gone', () {
      final d = CommsDirector();
      final b = _briefing('supplyRun');
      b.offer(d, now: 2, ttl: 6);
      expect(b.opacity(2.01, reduce: true), 1);
      expect(b.opacity(2.01), lessThan(.1));
      b.dismiss(d, 3);
      expect(b.opacity(3.01, reduce: true), 0);
      expect(b.opacity(3.01), greaterThan(.9));
    });
  });

  group('mid-level banter', () {
    test('the second wave asks for it once, with the level\'s id', () {
      for (final level in bonusLevels) {
        final m = ArcadeModel()..startAt(sector: 2, bonus: level.id);
        reach(m, RunMode.playing);
        final events = <GameEvent>[];
        for (var f = 0; f < 60 * 90 && m.mode == RunMode.playing; f++) {
          m.invulnerable = 5;
          for (final d in List<Demon>.of(m.demons)) {
            if (d.entering) continue;
            for (var guard = 0; guard < 1000 && m.demons.contains(d); guard++) {
              m.hitDemon(d);
            }
          }
          m.update(1 / 60);
          events.addAll(m.takeGameEvents());
        }
        final midway = [
          for (final e in events)
            if (e.name == GameEventNames.bonusMidway) e,
        ];
        expect(midway, hasLength(1), reason: level.id);
        expect(midway.single.variant, level.id);
      }
    });

    test('a regular sector never asks for it', () {
      final m = ArcadeModel()..startAt(sector: 2);
      reach(m, RunMode.playing);
      for (var f = 0; f < 60 * 20; f++) {
        m.invulnerable = 5;
        m.update(1 / 60);
        expect(
          m.takeGameEvents().where((e) => e.name == GameEventNames.bonusMidway),
          isEmpty,
        );
      }
    });

    test('it is a back-and-forth: squad first, the brood answers', () {
      for (final level in bonusLevels) {
        for (var seed = 0; seed < 6; seed++) {
          final d = CommsDirector();
          d.setSector(2, 0);
          final started = _run(
            d,
            0,
            14,
            each: (t) {
              if (t == 0) {
                d.handle(
                  GameEvent(GameEventNames.bonusMidway, {'variant': level.id}),
                  0,
                );
              }
            },
          );
          final banter = [
            for (final m in started)
              if (m.trigger.name == 'bonusMidway.${level.id}') m,
          ];
          expect(banter, hasLength(2), reason: '${level.id} seed $seed');
          expect(banter.first.isDemon, isFalse);
          expect(banter.last.isDemon, isTrue);
          expect(identical(banter.last.inReplyTo, banter.first), isTrue);
          _oneVoice(started, d.lineGap);
          for (final m in banter) {
            expect(m.line.silent, isTrue, reason: 'its own written words');
          }
        }
      }
    });
  });
}
