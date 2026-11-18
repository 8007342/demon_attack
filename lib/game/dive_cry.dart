/// Dive war cries (openspec/changes/fang-and-wings-comms design §3, §API).
///
/// The brood's creed is "Fang and Wings!": the marks above a creature's
/// head say what it has earned. When a creature commits to a dive it may
/// shout its war cry. [DiveCryGate] decides which dives cry (few, and
/// mostly the higher ranks) and turns the model's `divePrep` into a
/// `diveCry` event that the radio (a brood-lane toast timed to the dive)
/// and the demon choir (wordless grunts quantised to the music) both read.
///
/// Pure Dart, presentation only: it never touches the model or its random
/// generator, so the simulation and every calibration stay byte-identical.
library;

import 'dart:math' as math;

/// The ranks a war cry knows, from the mark the creature wears (the
/// insignia-ranks ladder: grunts bare, elite grunts a winglet or a
/// crownlet, "Fang and Wings" for hunters, the winged crown of fangs for
/// sentinels). The cry follows the mark, so what the player sees above
/// the head and reads on the radio agree.
enum BroodRank {
  /// Grunts, no mark. They squeak.
  grunt,

  /// Elite grunts: a winglet, or a crownlet (sentinel escorts and
  /// spear-bearers). They roar.
  veteran,

  /// Hunters (elites): Fang and Wings. They snarl.
  hunter,

  /// Sentinels: the winged crown of fangs. They intone the creed.
  sentinel;

  /// The rank from `divePrep` data. With `mark` (insignia-ranks'
  /// `RankMark` name: none, winglet, crownlet, fangWings, wingCrown) the
  /// mark decides; the model publishes it on every `divePrep` (round 8,
  /// `ArcadeModel._prepDive`), so in play the cry's rank is the mark the
  /// player sees. Only data without a mark (synthetic preps: tests, the
  /// pacing simulation) falls back to the fields: sentinels, elites, and
  /// the route-hardened (`maxHp >= 4`) as the stand-in for the elite grunts.
  static BroodRank of({
    required bool sentinel,
    required bool elite,
    required int kind,
    required int maxHp,
    String? mark,
  }) {
    switch (mark) {
      case 'wingCrown':
        return BroodRank.sentinel;
      case 'fangWings':
        return BroodRank.hunter;
      case 'winglet' || 'crownlet':
        return BroodRank.veteran;
      case 'none':
        return BroodRank.grunt;
    }
    if (sentinel) return BroodRank.sentinel;
    if (elite) return BroodRank.hunter;
    if (maxHp >= 4) return BroodRank.veteran;
    return BroodRank.grunt;
  }
}

/// The four gargoyle species by `Demon.kind` (hide colour,
/// plan/sprite-atlas.md): teal imp, violet brute, coral hunter, gold elder.
const broodSpecies = ['teal', 'violet', 'coral', 'gold'];

String broodSpeciesOf(int kind) => broodSpecies[kind.clamp(0, 3)];

/// One cry the gate let through: the `diveCry` event's data.
typedef DiveCry = Map<String, Object?>;

/// Which dives cry. At most one cry is in flight (from the decision until
/// [hold] seconds after its dive starts), two cries are at least [minGap]
/// seconds apart, and each rank cries with its own [chance].
class DiveCryGate {
  DiveCryGate({int seed = 1666}) : _seed = seed, _random = math.Random(seed);

  final int _seed;
  math.Random _random;

  /// Probability that a dive of each rank cries when the gate is free.
  static const chance = {
    BroodRank.grunt: .15,
    BroodRank.veteran: .35,
    BroodRank.hunter: .6,
    BroodRank.sentinel: .9,
  };

  /// How loud the choir may make the grunt (0..1), by rank.
  static const intensity = {
    BroodRank.grunt: .25,
    BroodRank.veteran: .5,
    BroodRank.hunter: .75,
    BroodRank.sentinel: 1.0,
  };

  /// Seconds between two cries' decisions, and how long after its dive
  /// starts a cry still counts as in flight (the toast, the plunge).
  static const minGap = 8.0, hold = .8;

  double _lastAt = -1e9, _busyUntil = -1e9;
  int _count = 0;

  /// Cries let through since the last [reset] (ids count from 1).
  int get count => _count;

  void reset() {
    _random = math.Random(_seed);
    _lastAt = _busyUntil = -1e9;
    _count = 0;
  }

  /// The cry for a `divePrep` with [data] at [clock] (seconds), or null.
  /// Reads `diveIn` (seconds until the dive starts), `lead` (until its
  /// tell), `tellIn`, `sentinel`, `elite`, `kind`, `maxHp`, `mark`
  /// (optional, the insignia-ranks mark), `x`, `y`.
  DiveCry? consider(Map<String, Object?> data, double clock) {
    double? n(Object? v) => v is num ? v.toDouble() : null;
    final diveIn = n(data['diveIn']);
    if (diveIn == null || diveIn <= 0) return null;
    if (clock < _busyUntil || clock - _lastAt < minGap) return null;
    final kind = n(data['kind'])?.toInt() ?? 0;
    final rank = BroodRank.of(
      sentinel: data['sentinel'] == true,
      elite: data['elite'] == true,
      kind: kind,
      maxHp: n(data['maxHp'])?.toInt() ?? 1,
      mark: data['mark'] as String?,
    );
    if (_random.nextDouble() >= chance[rank]!) return null;
    _lastAt = clock;
    _busyUntil = clock + diveIn + hold;
    _count++;
    return {
      'variant': rank.name,
      'rank': rank.name,
      'species': broodSpeciesOf(kind),
      'kind': kind.clamp(0, 3),
      'x': n(data['x']) ?? 0.0,
      'y': n(data['y']) ?? 0.0,
      'diveIn': diveIn,
      'tellIn': math.min(n(data['tellIn']) ?? n(data['lead']) ?? 0.0, diveIn),
      'intensity': intensity[rank],
      'cry': _count,
      'mark': ?data['mark'] as String?,
    };
  }
}
