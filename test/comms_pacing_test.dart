/// Radio pacing, measured: a long seeded run of busy combat events through
/// the real line bank (see comms_pacing_sim.dart).
///
/// Targets (openspec/changes/comms-pacing, amended by
/// openspec/changes/comms-middle-ground):
/// - paced airtime (everything but the must-play ground-fire warnings)
///   35-45 % in busy combat, clearly less in a calm stretch;
/// - no overlapping voices and no cut line at all; every line is followed
///   by the grace gap before the next one starts (the regroup chorus
///   overlaps only itself);
/// - every dive call ends within 0.3 s of its dive start, except an urgent
///   sentinel call that had to wait for the channel (it still starts
///   before the dive);
/// - a falling shield or power-up the ship lacks is recommended (in full)
///   within 8 s at least 95 % of the time and always within 12 s, unless
///   one was recommended in the last [CommsPacing.hintCooldown];
/// - every ground launch has a full warning ending at or at most
///   [CommsPacing.warningCover] before it, or (rarely, when the channel was
///   busy) a full warning that ends late;
/// - lines about air cover and the ground battle play only when true.
library;

import 'dart:math' as math;

import 'package:demon_attack/comms/comms_context.dart';
import 'package:demon_attack/comms/comms_director.dart';
import 'package:demon_attack/game/game_events.dart';
import 'package:flutter_test/flutter_test.dart';

import 'comms_pacing_sim.dart';

const _dive = {
  GameEventNames.diveWarning,
  GameEventNames.sentinelDive,
  GameEventNames.divePrep,
};
const _hints = {GameEventNames.shieldSpotted, GameEventNames.powerupSpotted};

bool _ground(HeardLine h) => h.message.mustPlay;

void main() {
  for (final seed in [4, 11, 23]) {
    for (final busy in [true, false]) {
      test('pacing seed $seed ${busy ? 'busy combat' : 'calm stretch'}', () {
        final c = CommsDirector(
          random: math.Random(seed),
          jitter: math.Random(seed * 7 + 1),
        );
        final s = simulate(c, seed: seed, busy: busy);
        final paced = s.duty(where: (h) => !_ground(h));
        final ground = s.duty(where: _ground);

        final calls = [
          for (final h in s.heard)
            if (_dive.contains(h.trigger)) h,
        ];
        final (aligned, diveTotal) = s.diveAlignment(c.pacing.diveTolerance);
        // Recommendations when the ship lacks what is falling.
        final hinted = [
          for (final h in s.heard)
            if (_hints.contains(h.trigger) &&
                h.message.kind == CommsClass.hint &&
                !h.cut)
              h,
        ];
        var due = 0, met = 0, late = 0;
        final missed = <double>[];
        for (final chance in s.hintChances) {
          // One recommendation per cooldown: a chance soon after one that
          // was already made (or queued) is not due.
          final recent = hinted.any(
            (h) =>
                h.message.queuedAt < chance - 1e-6 &&
                chance - h.message.queuedAt < c.pacing.hintCooldown,
          );
          if (recent || chance > s.seconds - 12) continue;
          due++;
          bool within(double w) => hinted.any(
            (h) => h.start >= chance - 1e-6 && h.start <= chance + w,
          );
          if (within(8)) {
            met++;
          } else if (within(12)) {
            late++;
          } else {
            missed.add(chance);
          }
        }
        final lateWarnings = s.lateWarnings;
        final moments = s.byTrigger;
        // ignore: avoid_print
        print(
          'seed $seed ${busy ? 'busy' : 'calm'}: paced airtime '
          '${(paced * 100).toStringAsFixed(1)} %, ground warnings '
          '${(ground * 100).toStringAsFixed(1)} %, total '
          '${(s.duty() * 100).toStringAsFixed(1)} %; '
          '${s.heard.length} lines, ${s.overlaps().length} overlaps, '
          '${s.cut.length} cut, dive calls $aligned/$diveTotal aligned '
          '(${c.lateDiveCalls} late), ${s.shots.length} launches '
          '(${c.coveredLaunches} shared a warning, ${lateWarnings.length} '
          'warned late), $met/$due hints; waveStart '
          '${moments['waveStart'] ?? 0}, reinforcements '
          '${moments['reinforcements'] ?? 0}, sentinelIncoming '
          '${moments['sentinelIncoming'] ?? 0}',
        );

        for (final h in calls) {
          expect(h.message.endBy, isNotNull, reason: h.message.toString());
          expect(
            s.dives.any((d) => (d - h.message.endBy!).abs() < .02),
            isTrue,
            reason: 'a dive call for a real dive',
          );
          if (h.message.late) {
            // Waited for the channel: urgent, and still before the dive.
            expect(h.message.urgent, isTrue, reason: '${h.message}');
            expect(h.start, lessThanOrEqualTo(h.message.endBy! + 1e-6));
            continue;
          }
          expect(
            (h.end - h.message.endBy!).abs(),
            lessThanOrEqualTo(c.pacing.diveTolerance + 1e-6),
            reason:
                '${h.message} ended ${h.end} for a dive at '
                '${h.message.endBy}',
          );
        }

        // No two voices at once, nothing cut, and a grace gap after every
        // line (a 60 Hz tick may start a must-play warning a frame early).
        expect(s.overlaps(), isEmpty);
        expect(s.cut, isEmpty);
        expect(c.interruptedLines, isEmpty);
        final sorted = [...s.heard]..sort((a, b) => a.start.compareTo(b.start));
        for (var i = 1; i < sorted.length; i++) {
          final a = sorted[i - 1], b = sorted[i];
          if (a.message.overlap && b.message.overlap) continue;
          expect(
            b.start - a.end,
            greaterThanOrEqualTo(c.lineGap - CommsDirector.warningLead - 1e-6),
            reason: '$a then $b',
          );
        }

        // Every ground launch: a full warning that ended at or just before
        // it, or, rarely, one that waited for the channel and ended late.
        for (final shot in s.shots) {
          final cover = s.heard.where(
            (h) =>
                _ground(h) &&
                h.end <= shot + 1e-6 &&
                h.end >= shot - c.pacing.warningCover - 1e-6,
          );
          final lateCover = lateWarnings.where(
            (h) => (h.message.endBy! - shot).abs() < .05,
          );
          expect(
            cover.isNotEmpty || lateCover.isNotEmpty,
            isTrue,
            reason: 'launch at $shot unwarned',
          );
        }
        for (final h in s.heard.where(_ground)) {
          expect(h.end, closeTo(h.start + h.message.line.duration, 1e-9));
        }
        expect(lateWarnings.length, c.lateWarnings);
        expect(
          lateWarnings.length,
          lessThanOrEqualTo((s.shots.length * .08).ceil()),
          reason: 'late warnings stay rare',
        );

        // Lines about the fight below match what the simulation staged.
        for (final h in s.heard) {
          final gates = {
            ...?commsLineGates[h.message.line.id],
            ...?commsTriggerGates[h.trigger],
          };
          final t = h.message.queuedAt;
          for (final gate in gates) {
            switch (gate) {
              case CommsGate.overFight:
                expect(s.overAt(t), isTrue, reason: '$h over the fight');
              case CommsGate.groundEngaged:
                expect(s.engagedAt(t), isTrue, reason: '$h engaged');
              case CommsGate.allyAttacked:
                expect(
                  s.engagedAt(t) &&
                      s.allyCalledBefore(t, CommsGroundPicture.attackedWindow),
                  isTrue,
                  reason: '$h allies under attack',
                );
              default:
                break;
            }
          }
        }

        expect(due, greaterThan(5));
        expect(missed, isEmpty, reason: 'no recommendation within 12 s');
        expect(met / due, greaterThanOrEqualTo(.95), reason: '$late late');

        if (busy) {
          expect(paced, inInclusiveRange(.35, .45));
          expect(moments['waveStart'] ?? 0, greaterThan(4));
          expect(moments['reinforcements'] ?? 0, greaterThan(4));
        } else {
          expect(paced, lessThan(.30));
        }
        expect(calls.length, greaterThan(busy ? 15 : 8));
      });
    }
  }

  test('the rests carry seeded noise, and the same seed replays exactly', () {
    List<double> starts(int jitterSeed) {
      final c = CommsDirector(
        random: math.Random(4),
        jitter: math.Random(jitterSeed),
      );
      return [
        for (final h in simulate(c, seed: 4, seconds: 180).heard) h.start,
      ];
    }

    expect(starts(1), starts(1));
    expect(starts(1), isNot(starts(2)));
  });
}
