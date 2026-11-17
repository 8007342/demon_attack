// bonus-challenges: how often each level's 1UP is won (design §5). The
// suite gate is small: the challenge can be won by a pilot trying for it,
// and is not won by default. `--dart-define=BONUS_CHALLENGE=1` prints the
// full table (routes 0-1, sectors 2-4, every difficulty, eight seeds) that
// plan/calibration-current.md records.
import 'package:demon_attack/game/model.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/challenge_pilot.dart';

void main() {
  const full = bool.fromEnvironment('BONUS_CHALLENGE');
  final levels = [
    for (final l in bonusLevels)
      if (l.challenge != null) l.id,
  ];

  test('earn rates: hard but fair', () {
    final seeds = full
        ? const [1982, 7, 21, 42, 99, 314, 2718, 5150]
        : const [1982, 7, 21, 42];
    final difficulties = full ? Difficulty.values : const [Difficulty.normal];
    final routes = full ? const [0, 1] : const [0];
    final average = measureChallenges(
      levels: levels,
      challenger: false,
      seeds: seeds,
      routes: routes,
      difficulties: difficulties,
    );
    final challenger = measureChallenges(
      levels: levels,
      challenger: true,
      seeds: seeds,
      routes: routes,
      difficulties: difficulties,
    );
    if (full) {
      // ignore: avoid_print
      print(
        challengeMarkdown({
          'average': average,
          'challenger': challenger,
        }, levels),
      );
    }
    for (final level in levels) {
      final a = pooledRate(average, level), c = pooledRate(challenger, level);
      // Hard: a pilot not trying rarely wins it; fair: one trying can.
      expect(a, lessThanOrEqualTo(.5), reason: '$level average $a');
      expect(c, greaterThan(0), reason: '$level challenger $c');
      expect(c, greaterThanOrEqualTo(a), reason: level);
    }
  }, timeout: const Timeout(Duration(minutes: 20)));
}
