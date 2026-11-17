import 'package:demon_attack/comms/comms_bank.dart';
import 'package:demon_attack/comms/comms_briefing.dart';
import 'package:demon_attack/comms/comms_director.dart';
import 'package:demon_attack/comms/comms_types.dart';
import 'package:demon_attack/game/interlude.dart';
import 'package:demon_attack/game/model.dart';
import 'package:flutter_test/flutter_test.dart';

import 'progression_test.dart' show reach;

/// bonus-briefing: the urgent-mission card's line and the bonus levels'
/// banter on the radio channel (openspec/changes/bonus-levels, design
/// "Urgent-mission card"). One voice at a time, nothing cut, the card's
/// own written words. bonus-briefing-clarity: one radio line per level,
/// a guaranteed reading time, and the radio never closes the card.

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

/// Steps [b] and [d] together from [from] for [seconds] at 60 Hz. The
/// flight lasts [flightEnd] seconds of flight time, which (as in the game)
/// does not advance while the card holds the level's start; combat follows.
/// [each] runs every frame. Returns when the card closed (NaN: still open).
double _fly(
  CommsDirector d,
  BonusBriefing b, {
  double from = 0,
  double seconds = 20,
  double flightEnd = 30,
  void Function(double t)? each,
}) {
  const dt = 1 / 60;
  var flown = 0.0;
  for (var t = from; t < from + seconds; t += dt) {
    each?.call(t);
    d.update(t);
    var flying = flown < flightEnd;
    final held = b.holds(
      d,
      t,
      flying: flying,
      flightLeft: flying ? flightEnd - flown : 0,
    );
    if (!held) flown += dt;
    flying = flown < flightEnd;
    b.update(
      d,
      t,
      flying: flying,
      flightLeft: flying ? flightEnd - flown : 0,
      combat: !flying,
    );
    if (!b.open) return t;
  }
  return double.nan;
}

void main() {
  group('instructions', () {
    for (final level in bonusLevels) {
      test('${level.id}: one goal line and one how-to line', () {
        expect(level.brief, isNotEmpty);
        expect(level.how, isNotEmpty);
        // Short enough to take in at a glance on a phone.
        expect(level.brief.length, lessThanOrEqualTo(40), reason: level.brief);
        expect(level.how.length, lessThanOrEqualTo(60), reason: level.how);
        // Short words: no word longer than "lightning".
        for (final w in '${level.brief} ${level.how}'.split(RegExp(r'\W+'))) {
          expect(w.length, lessThanOrEqualTo(9), reason: w);
        }
      });
    }

    test('the words match the rules in code', () {
      // Supply Run: crates are shot open (several hits), the cargo falls
      // and is caught by flying under it.
      expect(SupplyCrate(0, 0, Power.shield).maxHp, greaterThan(1));
      expect(supplyRun.how.toLowerCase(), contains('crate'));
      expect(supplyRun.how.toLowerCase(), contains('fly under'));
      expect(supplyRun.rules.killDrops, isFalse);
      // Stormfront: the bolt goes where the mark blinked; the player slides
      // out from under it.
      expect(stormfront.brief.toLowerCase(), contains('lightning'));
      expect(stormfront.how.toLowerCase(), contains('slide away'));
    });

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

  group('one radio line per level', () {
    for (final level in bonusLevels) {
      test('${level.id}: exactly one line, one sentence, its own words', () {
        final spec = commsHumanTriggers['bonusCall.${level.id}'];
        expect(spec, isNotNull);
        expect(spec!.lines, hasLength(1));
        final line = spec.lines.single;
        final text = line.text!;
        // One sentence: one end mark, at the end.
        expect(RegExp(r'[.!?]').allMatches(text).length, 1, reason: text);
        expect(text, matches(RegExp(r'[.!?]$')));
        // A squadmate speaks it, as a written line (no borrowed voice).
        expect(commsCast[line.speaker]!.isDemon, isFalse);
        expect(line.silent, isTrue);
        expect(line.clip, line.id);
        // Not a copy of the card's text.
        expect(text, isNot(contains(level.brief)));
        expect(text, isNot(contains(level.how)));
        for (var seed = 0; seed < 8; seed++) {
          final b = _briefing(level.id, seed: seed);
          final script = b.script();
          expect(script, hasLength(1));
          expect(script.single.$1.id, line.id);
        }
      });
    }

    test('it plays once alongside the card, and nothing else talks', () {
      for (final level in bonusLevels) {
        final d = CommsDirector();
        final b = _briefing(level.id);
        expect(b.offer(d, now: 0, ttl: 6), isTrue);
        final started = _run(
          d,
          0,
          10,
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
        expect(script, hasLength(1), reason: level.id);
        expect(script.single.line.id, 'bonusCall.${level.id}.h0');
        // While the card is up the squad is hushed: nothing else starts.
        expect([
          for (final m in started)
            if (!m.scripted) m,
        ], isEmpty);
      }
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
    test('it stays up for its reading time, whatever the radio does', () {
      for (final level in bonusLevels) {
        final d = CommsDirector();
        final b = _briefing(level.id, modifier: 'heavyOrdnance');
        expect(b.readFor, greaterThanOrEqualTo(BonusBriefing.minRead));
        expect(b.readFor, lessThanOrEqualTo(BonusBriefing.maxRead));
        b.offer(d, now: 0, ttl: 6);
        // A flight that ends early: the card still stays for its read.
        final closed = _fly(d, b, flightEnd: 1, seconds: 20);
        expect(closed.isNaN, isFalse);
        expect(closed, greaterThanOrEqualTo(b.readFor - 1e-6));
      }
    });

    test('the briefing survives incoming radio', () {
      final d = CommsDirector();
      final b = _briefing('stormfront');
      b.offer(d, now: 0, ttl: 6);
      // Urgent warnings, ground fire and squad chatter pile in, and the
      // card's own line is pushed back until it expires.
      final closed = _fly(
        d,
        b,
        seconds: 12,
        each: (t) {
          final f = (t * 60).round();
          if (f % 30 == 0) {
            d.handle(const GameEvent(GameEventNames.levelClear), t);
            d.handle(const GameEvent(GameEventNames.salvage), t);
            d.handle(const GameEvent(GameEventNames.shieldExpiring), t);
            d.handle(const GameEvent(GameEventNames.groundBreakthrough), t);
          }
        },
      );
      // The flight is 30 s long: nothing but the player closes the card.
      expect(closed.isNaN, isTrue, reason: 'the radio closed the card');
      expect(b.open, isTrue);
    });

    test('a line that never plays leaves the card up', () {
      final d = CommsDirector();
      final b = _briefing('supplyRun');
      // The line expires at once: the card is up all the same.
      expect(b.offer(d, now: 0, ttl: 0), isTrue);
      final closed = _fly(d, b, flightEnd: 2, seconds: 20);
      expect(closed, greaterThanOrEqualTo(b.readFor - 1e-6));
    });

    test('dismissing it lets the line on air finish', () {
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
      _run(d, d.now, 8);
      expect(first.interrupted, isFalse);
      expect(first.endsAt, ends, reason: 'never cut');
      // The channel is free again: the squad speaks.
      d.handle(const GameEvent(GameEventNames.levelClear), d.now);
      final after = _run(d, d.now, 6);
      expect(after, isNotEmpty);
    });

    test('a tap closes it before its reading time', () {
      final d = CommsDirector();
      final b = _briefing('stormfront');
      b.offer(d, now: 0, ttl: 6);
      _fly(d, b, seconds: 1);
      b.dismiss(d, d.now);
      expect(b.open, isFalse);
      expect(d.now, lessThan(b.readFor));
    });

    test('it is gone before the fight gets busy', () {
      final d = CommsDirector();
      final b = _briefing('supplyRun');
      b.offer(d, now: 0, ttl: 6);
      // The Descent ends at 6 s (after the reading time); combat follows.
      final closed = _fly(d, b, flightEnd: 6, seconds: 12);
      expect(closed, lessThanOrEqualTo(6 + BonusBriefing.combatGrace + .05));
      expect(
        b.visible(6 + BonusBriefing.combatGrace + BonusBriefing.fade + .05),
        isFalse,
      );
      // Nothing of it is left to talk over the fight.
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
