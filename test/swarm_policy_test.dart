import 'dart:convert';
import 'dart:io';

import 'package:demon_attack/game/swarm_policy.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('SwarmPolicy matches manifest metadata and held-out parity fixtures', () {
    final manifest =
        jsonDecode(File('assets/policy/manifest.json').readAsStringSync())
            as Map<String, dynamic>;
    expect(manifest['architecture'], [SwarmPolicy.inputs, SwarmPolicy.hidden, 4]);
    expect(manifest['actions'], SwarmPolicy.actions);
    expect((manifest['weightPayloadBytes'] as num).toInt(), lessThan(5000));
    final heldOut = manifest['heldOut'] as Map<String, dynamic>;
    expect((heldOut['accuracy'] as num).toDouble(), greaterThan(0.95));

    final parityCases = manifest['parityCases'] as List<dynamic>;
    expect(parityCases, hasLength(5));
    for (final item in parityCases) {
      final map = item as Map<String, dynamic>;
      final features = (map['features'] as List<dynamic>)
          .map((e) => (e as num).toDouble())
          .toList();
      final expectedScores = (map['scores'] as List<dynamic>)
          .map((e) => (e as num).toDouble())
          .toList();
      final actualScores = SwarmPolicy.scores(features);
      expect(actualScores, hasLength(4));
      final sum = actualScores.reduce((a, b) => a + b);
      expect(sum, closeTo(1.0, 1e-12));
      for (var i = 0; i < 4; i++) {
        expect(actualScores[i], closeTo(expectedScores[i], 1e-12));
      }
    }
  });

  test('SwarmPolicy falls back to hold on invalid or non-finite inputs', () {
    expect(SwarmPolicy.scores(const []), const [1, 0, 0, 0]);
    expect(
      SwarmPolicy.scores(List.filled(SwarmPolicy.inputs, double.nan)),
      const [1, 0, 0, 0],
    );
    expect(
      SwarmPolicy.choose(List.filled(SwarmPolicy.inputs, double.infinity)),
      'hold',
    );
  });

  test('SwarmPolicy evades away from an incoming angled shot and walls', () {
    // Shot approaching just to the right of the demon -> evade_left.
    final evadeLeft = SwarmPolicy.suggest(
      demonX: 180,
      demonY: 120,
      shotX: 188,
      shotY: 185,
      shotVx: 0,
      shipX: 180,
      shipVx: 0,
      crowdBalance: 0.4,
      healthRatio: 1.0,
      tierFactor: -0.75,
    );
    expect(evadeLeft, 'evade_left');

    // Shot approaching just to the left of the demon -> evade_right.
    final evadeRight = SwarmPolicy.suggest(
      demonX: 180,
      demonY: 120,
      shotX: 172,
      shotY: 185,
      shotVx: 0,
      shipX: 180,
      shipVx: 0,
      crowdBalance: -0.4,
      healthRatio: 1.0,
      tierFactor: -0.75,
    );
    expect(evadeRight, 'evade_right');
  });
}
