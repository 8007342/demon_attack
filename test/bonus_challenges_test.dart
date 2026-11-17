import 'dart:ui' as ui;

import 'package:demon_attack/comms/comms_bank.dart';
import 'package:demon_attack/comms/comms_briefing.dart';
import 'package:demon_attack/game/bonus/challenge_badge.dart';
import 'package:demon_attack/game/model.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'progression_test.dart' show reach;
import 'support/counting_canvas.dart';

/// Bonus challenges (openspec/changes/bonus-challenges): one perfect-run
/// condition per bonus level, paying a 1UP. Every loop here is bounded.

ArcadeModel _level(String id, {int sector = 2, int route = 0}) {
  final m = ArcadeModel(seed: 1982)
    ..startAt(sector: sector, route: route, bonus: id);
  reach(m, RunMode.playing);
  return m;
}

StormfrontMechanic _storm(ArcadeModel m) =>
    m.bonusMechanic! as StormfrontMechanic;

/// One protected combat step; returns the bonus game events it queued.
List<GameEvent> _step(ArcadeModel m, {bool protect = true}) {
  if (protect) m.invulnerable = 5;
  m.update(1 / 60);
  return [
    for (final e in m.takeGameEvents())
      if (GameEventNames.bonus.contains(e.name)) e,
  ];
}

/// Kills every present creature until the level's last kill, protected and
/// with [each] before every step; returns the bonus events and raw events.
(List<GameEvent>, List<String>) _clear(ArcadeModel m, {void Function()? each}) {
  final events = <GameEvent>[];
  final raw = <String>[];
  for (var f = 0; f < 60 * 300 && m.mode == RunMode.playing; f++) {
    each?.call();
    for (final d in List<Demon>.of(m.demons)) {
      if (d.entering) continue;
      for (var guard = 0; guard < 1000 && m.demons.contains(d); guard++) {
        m.hitDemon(d);
      }
    }
    events.addAll(_step(m));
    raw.addAll(m.takeEvents());
  }
  expect(m.mode, isNot(RunMode.playing), reason: 'cleared within 300 s');
  return (events, raw);
}

void main() {
  group('the catalogue', () {
    test('every shipped level declares a challenge the badge can draw', () {
      final ids = <String>{};
      for (final level in bonusLevels) {
        final c = level.challenge;
        expect(c, isNotNull, reason: level.id);
        expect(ids.add(c!.id), isTrue, reason: 'unique: ${c.id}');
        expect(c.label.length, lessThanOrEqualTo(18), reason: c.label);
        expect(c.label, c.label.toUpperCase());
        expect(ChallengeIcons.byId, contains(c.icon), reason: c.icon);
        expect(c.failOn, isNotEmpty, reason: c.id);
        expect(c.lives, 1);
        // The perfect-run medal's id passes the score worker's check.
        expect(
          oneUpRecordId(level.id),
          matches(RegExp(r'^[a-z][A-Za-z0-9]{0,31}$')),
        );
        expect(oneUpLevelOf(oneUpRecordId(level.id)), level.id);
        expect(runTagLabel(oneUpRecordId(level.id)), '${level.label} · 1UP');
      }
      expect(supplyRun.challenge!.failOn, {
        ChallengeNotes.crateMissed,
        ChallengeNotes.cargoMissed,
      });
      expect(stormfront.challenge!.failOn, {
        ChallengeNotes.boltHit,
        ChallengeNotes.boltGrazed,
      });
    });
  });

  group('the state', () {
    const def = BonusChallengeDef(
      id: 'test',
      label: 'TEST',
      icon: 'star',
      failOn: {'bad'},
      atLeast: {'good': 2},
    );

    test('a failOn note fails it at once, and only once', () {
      final c = BonusChallenge(def);
      expect(c.live && c.possible, isTrue);
      expect(c.note('good', at: 1), isFalse);
      expect(c.note('bad', at: 2), isTrue);
      expect(c.status, ChallengeStatus.failed);
      expect(c.failedBy, 'bad');
      expect(c.changedAt, 2);
      expect(c.note('bad', at: 3), isFalse, reason: 'settled');
      expect(c.settle(at: 4), isFalse);
      expect(c.changedAt, 2);
    });

    test('the clear earns it once when on track, else fails it', () {
      final short = BonusChallenge(def)..note('good', at: 0);
      expect(short.onTrack, isFalse);
      expect(short.settle(at: 1), isFalse);
      expect(short.failed, isTrue);
      expect(short.failedBy, isNull);
      final ok = BonusChallenge(def)
        ..note('good', at: 0)
        ..note('good', at: 0);
      expect(ok.settle(at: 5), isTrue);
      expect(ok.earned, isTrue);
      expect(ok.settle(at: 6), isFalse, reason: 'paid once');
      expect(ok.note('bad', at: 7), isFalse, reason: 'earned stays earned');
    });
  });

  group('Supply Run: catch all the cargo', () {
    test('a crate passing the ship unopened fails it within a frame', () {
      final m = _level('supplyRun');
      final c = m.bonusChallenge!;
      final crate = SupplyCrate(40, ArcadeModel.shipY - 3, Power.spread);
      m.supplyCrates.add(crate);
      List<GameEvent>? at;
      for (var f = 0; f < 120 && c.live; f++) {
        final below = crate.y > ArcadeModel.shipY;
        final events = _step(m);
        if (!c.live) {
          at = events;
          expect(below, isTrue, reason: 'not before it passed');
        }
      }
      expect(c.failedBy, ChallengeNotes.crateMissed);
      final failed = at!.where(
        (e) => e.name == GameEventNames.bonusChallengeFailed,
      );
      expect(failed.single.variant, 'supplyRun');
      expect(failed.single.data['by'], ChallengeNotes.crateMissed);
      // Nothing more is said about it.
      for (var f = 0; f < 120; f++) {
        expect(
          _step(m).where((e) => e.name == GameEventNames.bonusChallengeFailed),
          isEmpty,
        );
      }
    });

    test('cargo falling past the ship fails it; caught cargo counts', () {
      final m = _level('supplyRun');
      final c = m.bonusChallenge!;
      m
        ..shipX = 180
        ..targetX = 180;
      m.pickups.add(Pickup(180, ArcadeModel.shipY - 30, Power.rapid));
      for (
        var f = 0;
        f < 60 && (c.tally[ChallengeNotes.cargoCaught] ?? 0) == 0;
        f++
      ) {
        _step(m);
      }
      expect(c.tally[ChallengeNotes.cargoCaught], 1);
      expect(c.live, isTrue);
      m.pickups.add(Pickup(30, ArcadeModel.shipY - 10, Power.rapid));
      for (var f = 0; f < 120 && c.live; f++) {
        _step(m);
      }
      expect(c.failedBy, ChallengeNotes.cargoMissed);
    });

    test('a clear with nothing caught falls short (no 1UP)', () {
      final m = _level('supplyRun');
      final lives = m.lives;
      final (events, raw) = _clear(m, each: () => m.supplyCrates.clear());
      final c = m.bonusChallenge!;
      expect(c.failed, isTrue);
      expect(c.failedBy, isNull);
      expect(m.lives, lives);
      expect(raw, isNot(contains('bonusOneUp')));
      final failed = events.where(
        (e) => e.name == GameEventNames.bonusChallengeFailed,
      );
      expect(failed.single.data['by'], '');
    });
  });

  group('Stormfront: dodge every bolt', () {
    test('a bolt on the ship fails it the step it lands', () {
      final m = _level('stormfront');
      m.lives = 9;
      final mech = _storm(m);
      final c = m.bonusChallenge!;
      for (var f = 0; f < 60 * 120 && c.live && m.combat; f++) {
        // Stand on every tell, nothing else touches the ship.
        final tell = mech.cell.strikes.where((s) => s.telling).firstOrNull;
        if (tell != null) {
          m
            ..shipX = tell.x
            ..targetX = tell.x;
        }
        m.invulnerable = 0;
        m.shots.clear();
        final hits = mech.shipHits;
        _step(m, protect: false);
        if (!c.live) {
          expect(mech.shipHits, hits + 1, reason: 'failed by the bolt');
        }
      }
      expect(c.failedBy, ChallengeNotes.boltHit);
    });

    test('a graze inside the bright column fails it, costing no life', () {
      final m = _level('stormfront');
      final mech = _storm(m);
      final c = m.bonusChallenge!;
      final lives = m.lives;
      for (var f = 0; f < 60 * 120 && c.live && m.combat; f++) {
        // 20 units off every tell: outside the core, inside the column.
        final tell = mech.cell.strikes.where((s) => s.telling).firstOrNull;
        if (tell != null) {
          final x = tell.x < 180 ? tell.x + 20 : tell.x - 20;
          m
            ..shipX = x
            ..targetX = x;
        }
        m.invulnerable = 0;
        m.shots.clear();
        _step(m, protect: false);
      }
      expect(c.failedBy, ChallengeNotes.boltGrazed);
      expect(mech.shipHits, 0);
      expect(m.lives, lives);
    });

    test('a shield knocked off by a bolt counts; the rod does not', () {
      final m = _level('stormfront');
      final mech = _storm(m);
      final c = m.bonusChallenge!;
      // The rod: every tell is drawn to the ship and grounded.
      for (var f = 0; f < 60 * 30 && mech.grounded < 2 && m.combat; f++) {
        m.bonusPowerTimers[lightningRod.id] = 5;
        _step(m);
      }
      expect(mech.grounded, greaterThanOrEqualTo(2));
      expect(c.live, isTrue);
      m.bonusPowerTimers.remove(lightningRod.id);
      for (var f = 0; f < 60 * 120 && c.live && m.combat; f++) {
        final tell = mech.cell.strikes.where((s) => s.telling).firstOrNull;
        if (tell != null) {
          m
            ..shipX = tell.x
            ..targetX = tell.x;
        }
        m.invulnerable = 0;
        m.shots.clear();
        m.powerTimers[Power.shield] = 9;
        _step(m, protect: false);
      }
      expect(c.failedBy, ChallengeNotes.boltHit);
    });

    test('a clean storm pays one 1UP, once, through the extra-life path', () {
      final m = _level('stormfront');
      final lives = m.lives;
      final (events, raw) = _clear(m);
      final c = m.bonusChallenge!;
      expect(c.earned, isTrue);
      expect(m.lives, lives + 1);
      expect(raw.where((e) => e == 'bonusOneUp'), hasLength(1));
      final earned = events.where(
        (e) => e.name == GameEventNames.bonusChallengeEarned,
      );
      expect(earned.single.variant, 'stormfront');
      // The cheer is queued before the clear's own line.
      expect(
        events.indexOf(earned.single),
        lessThan(
          events.indexWhere((e) => e.name == GameEventNames.bonusCleared),
        ),
      );
      expect(
        events
            .firstWhere((e) => e.name == GameEventNames.bonusCleared)
            .data['challenge'],
        'earned',
      );
      expect(m.bonusOneUps, ['stormfront']);
      // Nothing more is paid on the way out or in the next sector.
      for (var f = 0; f < 60 * 30 && m.mode != RunMode.playing; f++) {
        m.update(1 / 60);
        expect(m.takeEvents(), isNot(contains('bonusOneUp')));
      }
      expect(m.lives, lives + 1);
      expect(m.bonusChallenge, isNull, reason: 'a regular sector');
      // The run record and the checkpoint keep it.
      expect(m.runModifierIds, contains('stormfrontOneUp'));
      expect(m.runModifierIds, isNot(contains('stormfront')));
      final saved = m.checkpoint();
      expect(saved['bonusOneUps'], ['stormfront']);
      final restored = ArcadeModel()..restoreCheckpoint(saved);
      // (A forced level is not in the seed's own plan, so the restored
      // record's slots differ; the won 1UP is kept all the same.)
      expect(restored.bonusOneUps, ['stormfront']);
    });
  });

  group('radio', () {
    for (final level in bonusLevels) {
      test('${level.id}: one challenge call, a quip and a cheer', () {
        final call = commsHumanTriggers['bonusChallenge.${level.id}']!;
        expect(call.lines, hasLength(1));
        final text = call.lines.single.text!;
        expect(RegExp(r'[.!?]').allMatches(text).length, 1, reason: text);
        expect(text, contains('1UP'));
        expect(call.lines.single.silent, isTrue, reason: 'written line');
        expect(commsCast[call.lines.single.speaker]!.isDemon, isFalse);
        // The card speaks the challenge call, its only line.
        final b = BonusBriefing(
          level: level,
          sector: 2,
          invite: call.lines.single,
          inviteSpec: call,
        );
        expect(b.script().single.$1.id, call.lines.single.id);
        expect(b.challenge, level.challenge);
        final quip = commsHumanTriggers['bonusChallengeFailed.${level.id}']!;
        expect(quip.lines, isNotEmpty);
        for (final line in [
          ...quip.lines,
          ...?commsDemonTriggers['bonusChallengeFailed.${level.id}']?.lines,
        ]) {
          expect(line.silent, isTrue, reason: line.id);
        }
      });
    }

    test('the 1UP cheer: squadmates, with an optional brood retort', () {
      final cheer = commsHumanTriggers['bonusChallengeEarned']!;
      expect(cheer.lines.length, greaterThanOrEqualTo(3));
      for (final line in cheer.lines) {
        expect(commsCast[line.speaker]!.isDemon, isFalse);
      }
      final retort = commsDemonTriggers['bonusChallengeEarned']!;
      expect(retort.lines, isNotEmpty);
      for (final line in retort.lines) {
        expect(commsCast[line.speaker]!.isDemon, isTrue);
      }
    });
  });

  group('the badge', () {
    testWidgets('live, failed and earned read out and paint', (tester) async {
      for (final status in ChallengeStatus.values) {
        for (final age in [null, 0.0, .2, 1.0, 5.0]) {
          await tester.pumpWidget(
            Directionality(
              textDirection: TextDirection.ltr,
              child: Center(
                child: ChallengeBadge(
                  challenge: supplyRun.challenge!,
                  status: status,
                  age: age,
                  height: 20,
                  label: true,
                ),
              ),
            ),
          );
          expect(
            find.bySemanticsLabel(
              ChallengeBadge.describe(supplyRun.challenge!, status),
            ),
            findsOneWidget,
          );
          expect(find.text('CATCH ALL CARGO'), findsOneWidget);
        }
      }
    });

    test('each state draws differently; the burst fades', () {
      int ops(ChallengeStatus s, {double? age, bool reduced = false}) {
        final recorder = ui.PictureRecorder();
        final canvas = CountingCanvas(recorder);
        ChallengeBadgePainter(
          icon: 'bolt',
          status: s,
          age: age,
          reduced: reduced,
        ).paint(canvas, const Size(43, 20));
        recorder.endRecording().dispose();
        return canvas.total.calls;
      }

      final live = ops(ChallengeStatus.live);
      final failed = ops(ChallengeStatus.failed, age: 5);
      final flash = ops(ChallengeStatus.failed, age: .1);
      final burst = ops(ChallengeStatus.earned, age: .3);
      final after = ops(ChallengeStatus.earned, age: 5);
      expect(failed, greaterThan(live), reason: 'the slash');
      expect(flash, greaterThan(failed), reason: 'the flip flash');
      expect(burst, greaterThan(after), reason: 'rays, ring, sparks');
      expect(
        ops(ChallengeStatus.earned, age: .3, reduced: true),
        lessThan(burst),
        reason: 'reduced motion: a steady halo',
      );
      // Unknown pictograms fall back to the star.
      expect(ChallengeIcons.of('nope'), ChallengeIcons.paintStar);
    });
  });
}
