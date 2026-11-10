/// Per-run squad lineup: the Fleet Admiral anchors every run; each run seeds
/// a different set of pilots, officers and ground troopers (and so different
/// voices), deterministically from its seed.
library;

import 'dart:math' as math;

import 'comms_bank.dart';
import 'comms_types.dart';

class CommsLineup {
  const CommsLineup._(this.seed, this.fleet, this.ground);

  final int seed;

  /// This run's pilots and officers (besides the anchor) and ground troopers.
  final List<String> fleet, ground;

  /// Seeds tried when avoiding the previous lineup.
  static const attempts = 16;

  /// The lineup for [seed]. When [previous] is given, a few derived seeds are
  /// tried and the one sharing the fewest members with it wins (ties keep the
  /// earliest), so consecutive runs rarely repeat a lineup.
  factory CommsLineup.pick(
    int seed, {
    CommsLineup? previous,
    List<String> fleetPool = commsFleetPool,
    List<String> groundPool = commsGroundPool,
    int fleetSize = commsLineupFleet,
    int groundSize = commsLineupGround,
  }) {
    CommsLineup draw(int s) {
      final random = math.Random(s);
      List<String> take(List<String> pool, int n) =>
          ([...pool]..shuffle(random)).take(math.min(n, pool.length)).toList();
      return CommsLineup._(
        s,
        take(fleetPool, fleetSize),
        take(groundPool, groundSize),
      );
    }

    var best = draw(seed);
    if (previous == null) return best;
    var bestOverlap = best.overlap(previous);
    for (var i = 1; i < attempts && bestOverlap > 0; i++) {
      final candidate = draw(seed + i * 7919);
      final overlap = candidate.overlap(previous);
      if (overlap < bestOverlap) {
        best = candidate;
        bestOverlap = overlap;
      }
    }
    return best;
  }

  Set<String> get members => {commsAnchor, ...fleet, ...ground};

  int overlap(CommsLineup other) => {
    ...fleet,
    ...ground,
  }.intersection({...other.fleet, ...other.ground}).length;

  /// Who is on the call in each sector: the Admiral, two of this run's
  /// pilots (everyone at the Carrier), one ground trooper (all of them in the
  /// last two sectors) and the sector's demon officers.
  Map<int, Map<CommsSide, List<String>>> get roster => {
    for (var s = 1; s <= 5; s++)
      s: {
        CommsSide.fleet: [
          commsAnchor,
          if (s == 5)
            ...fleet
          else if (fleet.isNotEmpty) ...{
            fleet[(s - 1) % fleet.length],
            fleet[s % fleet.length],
          },
        ],
        CommsSide.ground: [
          if (s >= 4)
            ...ground
          else if (ground.isNotEmpty)
            ground[(s - 1) % ground.length],
        ],
        CommsSide.demon: [...?commsDemonSectors[s], ...commsMinions],
      },
  };

  Map<String, Object> toJson() => {
    'seed': seed,
    'fleet': fleet,
    'ground': ground,
  };

  /// Restores a saved lineup, keeping only ids still in the cast.
  static CommsLineup? fromJson(Object? data) {
    if (data is! Map) return null;
    final seed = data['seed'];
    List<String> ids(Object? v) => [
      if (v is List)
        for (final id in v)
          if (id is String && commsCast.containsKey(id)) id,
    ];
    final fleet = ids(data['fleet']), ground = ids(data['ground']);
    if (seed is! int || fleet.isEmpty) return null;
    return CommsLineup._(seed, fleet, ground);
  }

  @override
  String toString() =>
      'CommsLineup($seed: ${fleet.join(',')} / ${ground.join(',')})';
}
