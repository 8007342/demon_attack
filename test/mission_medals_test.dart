// mission-medals (openspec/changes/mission-medals): Supply Run reads at a
// glance (a one-sentence brief that holds the start until read, cues on
// the crates and the cargo, feedback when the player gets it right, the
// radio in its own words) and a run's missions show as medals, not text.
import 'dart:ui' as ui;

import 'package:demon_attack/comms/comms_bank.dart';
import 'package:demon_attack/comms/comms_briefing.dart';
import 'package:demon_attack/comms/comms_director.dart';
import 'package:demon_attack/comms/comms_view.dart' show BonusBriefingCard;
import 'package:demon_attack/game/bonus/bonus_painters.dart';
import 'package:demon_attack/game/interlude.dart';
import 'package:demon_attack/game/model.dart';
import 'package:demon_attack/services/scores.dart';
import 'package:demon_attack/widgets/mission_medal.dart';
import 'package:demon_attack/widgets/run_record.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'progression_test.dart' show reach;

ArcadeModel _supplyRun() {
  final m = ArcadeModel()..startAt(sector: 2, route: 0, bonus: 'supplyRun');
  reach(m, RunMode.playing);
  return m;
}

BonusBriefing _briefing(String level) {
  final pick = InterludePlanner(seed: 0).planRadio(
    InterludeContext(
      difficulty: Difficulty.normal,
      level: 3,
      route: 0,
      window: 7.5,
      bonus: level,
    ),
  )!;
  return BonusBriefing(
    level: bonusLevelById(level)!,
    sector: 3,
    invite: pick.radio!.line,
    inviteSpec: pick.radio!.spec,
  );
}

/// Steps [m] one frame at a time (ship safe), collecting raw and game
/// events; stops when [until] holds or after [frames].
(List<String>, List<String>) _steps(
  ArcadeModel m,
  int frames, {
  bool Function()? until,
  double? shipAt,
}) {
  final raw = <String>[], game = <String>[];
  for (var f = 0; f < frames && m.combat; f++) {
    m.invulnerable = 5;
    if (shipAt != null) m.moveTo(shipAt);
    m.update(1 / 60);
    raw.addAll(m.takeEvents());
    game.addAll([
      for (final e in m.takeGameEvents())
        e.variant == null ? e.name : '${e.name}.${e.variant}',
    ]);
    if (until?.call() ?? false) break;
  }
  return (raw, game);
}

void main() {
  group('Supply Run: the brief', () {
    test('one short sentence on the goal', () {
      final brief = supplyRun.brief;
      expect(brief.length, lessThanOrEqualTo(60));
      expect(RegExp(r'[.!?]').allMatches(brief).length, 1);
      expect(brief.toLowerCase(), contains('crate'));
      expect(brief.toLowerCase(), contains('catch'));
    });

    test('the card holds the start until it has been read', () {
      final d = CommsDirector();
      final b = _briefing('supplyRun');
      b.offer(d, now: 0, ttl: 6);
      // Far from the flight's end: no hold.
      expect(b.holds(d, 0, flying: true, flightLeft: 3), isFalse);
      // At the flight's end and unread: it holds, and says so.
      expect(b.holds(d, .1, flying: true, flightLeft: .2), isTrue);
      expect(b.holding, isTrue);
      var released = double.nan;
      for (var t = .1; t < 30; t += 1 / 60) {
        d.update(t);
        if (!b.holds(d, t, flying: true, flightLeft: .2)) {
          released = t;
          break;
        }
      }
      expect(released.isNaN, isFalse);
      expect(released, greaterThanOrEqualTo(b.readFor - 1e-6));
      expect(b.read(released), isTrue);
      expect(released, lessThan(BonusBriefing.maxHold));
    });

    test('a tap releases the hold at once', () {
      final d = CommsDirector();
      final b = _briefing('supplyRun');
      b.offer(d, now: 0, ttl: 6);
      expect(b.holds(d, .1, flying: true, flightLeft: .1), isTrue);
      b.dismiss(d, .5);
      expect(b.holds(d, .5, flying: true, flightLeft: .1), isFalse);
    });

    test('it never holds longer than maxHold', () {
      final d = CommsDirector();
      final b = _briefing('stormfront');
      b.offer(d, now: 0, ttl: 6);
      // The director is never updated: the turns never finish.
      var t = 0.0;
      while (t < 60 && b.holds(d, t, flying: true, flightLeft: .1)) {
        t += 1 / 60;
      }
      expect(t, lessThanOrEqualTo(BonusBriefing.maxHold + .05));
    });

    test('the rule as a pictogram on the card', () {
      expect(BonusBriefingCard.howTo['supplyRun'], isNotNull);
    });
  });

  group('Supply Run: cues and feedback', () {
    test('a crate shot open pops, counts and makes its own sound', () {
      final m = _supplyRun();
      _steps(m, 150, shipAt: 18, until: () => m.supplyCrates.isNotEmpty);
      final crate = m.supplyCrates.first;
      final cues = m.bonusMechanic! as SupplyRunCues;
      final (raw, game) = _steps(
        m,
        240,
        until: () => !m.supplyCrates.contains(crate) && cues.opened > 0,
        shipAt: crate.x,
      );
      expect(cues.opened, 1);
      expect(cues.pops, isNotEmpty);
      expect(raw, contains('crateOpen'));
      expect(raw, isNot(contains('salvage')), reason: 'not the wave jingle');
      expect(game, contains('bonusCrate.supplyRun'));
    });

    test('cargo caught at the ship flashes and counts', () {
      final m = _supplyRun();
      m.bonusRun.crateLeft = 1e9;
      m.moveTo(180);
      _steps(m, 2);
      m.pickups.add(Pickup(180, ArcadeModel.shipY - 30, Power.rapid));
      final cues = m.bonusMechanic! as SupplyRunCues;
      _steps(m, 90, shipAt: 180, until: () => cues.caught > 0);
      expect(cues.caught, 1);
      expect(cues.catches, isNotEmpty);
      expect(m.hasPower(Power.rapid), isTrue);
    });

    test('a crate that falls past unopened draws the squad\'s banter', () {
      final m = _supplyRun();
      m.bonusRun.crateLeft = 1e9;
      m.supplyCrates.add(SupplyCrate(320, ArcadeModel.shipY + 20, Power.rapid));
      final (_, game) = _steps(
        m,
        120,
        shipAt: 18,
        until: () => m.supplyCrates.isEmpty,
      );
      _steps(m, 2, shipAt: 18).$2.forEach(game.add);
      expect(game, contains('bonusCrateMissed.supplyRun'));
      expect(commsHumanTriggers['bonusCrateMissed.supplyRun'], isNotNull);
    });

    test('the painter draws crates, cargo, magnet and coins', () {
      final m = _supplyRun();
      _steps(m, 150, shipAt: 18, until: () => m.supplyCrates.isNotEmpty);
      m.pickups.add(Pickup(m.shipX + 40, ArcadeModel.shipY - 90, Power.rapid));
      m
        ..collectBonus(salvageMagnet)
        ..collectBonus(doubleScore);
      m.supplyCrates.first.hp = 1;
      final recorder = ui.PictureRecorder();
      BonusPainters.over(Canvas(recorder), m, 1.5);
      recorder.endRecording().dispose();
    });

    test('its in-level radio speaks its own words', () {
      for (final key in [
        'bonusStart.supplyRun',
        'bonusCrate.supplyRun',
        'bonusPickup.salvageMagnet',
        'bonusPickup.doubleScore',
        'bonusCrateMissed.supplyRun',
      ]) {
        final spec = commsHumanTriggers[key]!;
        for (final line in spec.lines) {
          expect(line.clip, line.id, reason: '$key: not a borrowed clip');
          expect(line.silent, isTrue, reason: key);
        }
      }
    });
  });

  group('mission medals on the run record', () {
    Future<void> pump(WidgetTester tester, ScoreEntry entry) async {
      tester.view.physicalSize = const Size(360, 780);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Padding(
              padding: const EdgeInsets.all(16),
              child: RunRecordCard(entry: entry),
            ),
          ),
        ),
      );
    }

    testWidgets('missions are medals, never text chips', (tester) async {
      await pump(
        tester,
        const ScoreEntry(
          'YOU',
          1,
          medals: 2,
          modifiers: ['supplyRun', 'heavyOrdnance'],
        ),
      );
      expect(find.text('SUPPLY RUN'), findsNothing);
      expect(find.text('HEAVY ORDNANCE'), findsNothing);
      expect(
        find.byKey(const ValueKey('mission-medal-supplyRun')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('mission-medal-heavyOrdnance')),
        findsOneWidget,
      );
      expect(find.bySemanticsLabel('SUPPLY RUN mission medal'), findsOneWidget);
      // The name is a tap tooltip.
      await tester.tap(find.byKey(const ValueKey('mission-medal-supplyRun')));
      await tester.pump(const Duration(milliseconds: 200));
      expect(find.text('SUPPLY RUN'), findsOneWidget);
      await tester.pump(const Duration(seconds: 3));
      expect(tester.takeException(), isNull);
    });

    testWidgets('every mission and an unknown one compose a medal', (
      tester,
    ) async {
      await pump(
        tester,
        ScoreEntry(
          'YOU',
          1,
          modifiers: [
            for (final l in bonusLevels) l.id,
            for (final r in runModifiers) r.id,
            'someFutureMission',
          ],
        ),
      );
      expect(tester.takeException(), isNull);
      expect(MissionMedalSheet.layers('someFutureMission'), isNotEmpty);
      for (final id in [
        for (final l in bonusLevels) l.id,
        for (final r in runModifiers) r.id,
      ]) {
        expect(MissionMedalSheet.knows(id), isTrue, reason: id);
      }
    });
  });
}
