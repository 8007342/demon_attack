/// Radio pacing, measured: a long seeded run of busy combat events through
/// the real line bank (see comms_pacing_sim.dart).
///
/// Targets (openspec/changes/comms-pacing):
/// - paced airtime (everything but the must-play ground-fire warnings)
///   15-25 % in busy combat, less in a calm stretch;
/// - no overlapping voices and no cut line, except a flavour or useful line
///   cut by an urgent or must-play warning;
/// - every dive call ends within 0.3 s of its dive start;
/// - a falling shield or power-up the ship lacks is recommended (in full)
///   within 8 s at least 95 % of the time and always within 12 s, unless
///   one was recommended in the last [CommsPacing.hintCooldown];
///   (unless one was recommended in the last [CommsPacing.hintCooldown]);
/// - every ground launch has a full, uncut warning ending at or at most
///   [CommsPacing.warningCover] before it.
library;

import 'dart:math' as math;

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

        // Dive calls: every one that played in full ended on its dive.
        final calls = [
          for (final h in s.heard)
            if (_dive.contains(h.trigger)) h,
        ];
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
        // ignore: avoid_print
        print(
          'seed $seed ${busy ? 'busy' : 'calm'}: paced airtime '
          '${(paced * 100).toStringAsFixed(1)} %, ground warnings '
          '${(ground * 100).toStringAsFixed(1)} %, total '
          '${(s.duty() * 100).toStringAsFixed(1)} %; '
          '${s.heard.length} lines, ${calls.length} dive calls, '
          '${s.shots.length} launches (${c.coveredLaunches} shared a '
          'warning), $met/$due hints, ${s.cut.length} cut by warnings',
        );

        for (final h in calls) {
          expect(h.message.endBy, isNotNull, reason: h.message.toString());
          expect(
            s.dives.any((d) => (d - h.message.endBy!).abs() < .02),
            isTrue,
            reason: 'a dive call for a real dive',
          );
          if (h.cut) continue; // a must-play warning took the channel
          expect(
            (h.end - h.message.endBy!).abs(),
            lessThanOrEqualTo(c.pacing.diveTolerance + 1e-6),
            reason:
                '${h.message} ended ${h.end} for a dive at '
                '${h.message.endBy}',
          );
        }

        // No two voices at once. Only an urgent or must-play warning cuts a
        // line, always one of a lower class, and never a must-play one.
        expect(s.overlaps(), isEmpty);
        for (final h in s.cut) {
          expect(h.message.mustPlay, isFalse, reason: '${h.message} was cut');
          final cutter = s.heard.firstWhere(
            (o) => (o.start - h.end).abs() < 1e-6 && !identical(o, h),
          );
          expect(cutter.message.urgent, isTrue, reason: '$cutter');
          expect(
            cutter.message.kind.index,
            greaterThan(h.message.kind.index),
            reason: '$cutter cut ${h.message}',
          );
        }

        // Every ground launch: a full warning that ended at or just before
        // it.
        for (final shot in s.shots) {
          final cover = s.heard.where(
            (h) =>
                _ground(h) &&
                !h.cut &&
                h.end <= shot + 1e-6 &&
                h.end >= shot - c.pacing.warningCover - 1e-6,
          );
          expect(cover, isNotEmpty, reason: 'launch at $shot unwarned');
        }
        for (final h in s.heard.where(_ground)) {
          expect(h.cut, isFalse);
          expect(h.end, closeTo(h.start + h.message.line.duration, 1e-9));
        }

        expect(due, greaterThan(5));
        expect(missed, isEmpty, reason: 'no recommendation within 12 s');
        expect(met / due, greaterThanOrEqualTo(.95), reason: '$late late');

        if (busy) {
          expect(paced, inInclusiveRange(.15, .25));
        } else {
          expect(paced, lessThan(.18));
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
