import 'package:demon_attack/game/bonus/levels/storm_cell.dart';
import 'package:flutter_test/flutter_test.dart';

/// The pure storm schedule of bonus level #2 (Stormfront).
List<String> _trace(int seed, {StormTuning tuning = StormTuning.normal}) {
  final cell = StormCell(seed, tuning: tuning);
  final log = <String>[];
  var seen = 0;
  for (var i = 0; i < 60 * 40; i++) {
    final ship = 180 + 120 * ((i ~/ 90) % 3 - 1);
    cell.step(1 / 60, shipX: ship.toDouble(), swarm: const [60, 80, 96, 250]);
    while (seen < cell.started) {
      final s = cell.strikes.firstWhere((s) => s.index == seen);
      log.add('$i ${s.aim.name} ${s.x.toStringAsFixed(1)}');
      seen++;
    }
  }
  return log;
}

void main() {
  test('one seed gives one storm; another seed another', () {
    expect(_trace(7), _trace(7));
    expect(_trace(7), isNot(_trace(8)));
    expect(_trace(7).length, greaterThan(6));
  });

  test('a tell lasts at least a second and its column never moves', () {
    for (final tuning in [
      StormTuning.easy,
      StormTuning.normal,
      StormTuning.hard,
      StormTuning.hard.forRoute(4),
    ]) {
      expect(tuning.tell, greaterThanOrEqualTo(1.0));
      final cell = StormCell(3, tuning: tuning);
      final began = <int, (int, double)>{};
      for (var i = 0; i < 60 * 60; i++) {
        final landed = cell.step(
          1 / 60,
          shipX: 40.0 + (i * 7) % 280,
          swarm: const [100, 110, 300],
          rate: 1.05,
        );
        for (final s in cell.strikes) {
          began.putIfAbsent(s.index, () => (i, s.x));
          expect(s.x, began[s.index]!.$2);
        }
        for (final s in landed) {
          expect((i - began[s.index]!.$1) / 60, greaterThanOrEqualTo(1.0));
        }
      }
      expect(cell.landed, greaterThan(8));
    }
  });

  test('bolts land at most once a second', () {
    final cell = StormCell(11, tuning: StormTuning.hard.forRoute(4));
    var last = -1000;
    for (var i = 0; i < 60 * 90; i++) {
      final landed = cell.step(1 / 60, shipX: 180, swarm: const [], rate: 1.05);
      if (landed.isNotEmpty) {
        expect(i - last, greaterThanOrEqualTo(60));
        last = i;
      }
    }
  });

  test(
    'a ship-aimed tell samples the ship once; a fork leaves a side open',
    () {
      final cell = StormCell(
        5,
        tuning: const StormTuning(forkChance: 1, shipShare: 1),
      );
      for (var i = 0; i < 60 * 4; i++) {
        cell.step(1 / 60, shipX: 100, swarm: const [200]);
        if (cell.telling) break;
      }
      final tells = cell.strikes.where((s) => s.telling).toList();
      expect(tells.length, 2);
      expect(tells.first.aim, StrikeAim.ship);
      expect(tells.first.x, 100);
      expect(tells.last.aim, StrikeAim.fork);
      // The fork is on the roomier side: the other side stays open.
      expect(tells.last.x, greaterThan(100 + 60));
      expect(tells.last.x, lessThanOrEqualTo(342));
    },
  );

  test('swarm-aimed tells take the densest column', () {
    expect(StormCell.densest(const [20, 200, 210, 220, 340], 34), 200);
    final cell = StormCell(5, tuning: const StormTuning(shipShare: 0));
    for (var i = 0; i < 60 * 4 && !cell.telling; i++) {
      cell.step(1 / 60, shipX: 30, swarm: const [300, 310, 60]);
    }
    expect(cell.strikes.single.aim, StrikeAim.swarm);
    expect(cell.strikes.single.x, 300);
  });

  test('no tell begins and a running tell fizzles while inactive', () {
    final cell = StormCell(9);
    for (var i = 0; i < 60 * 10; i++) {
      cell.step(1 / 60, shipX: 180, swarm: const [], active: false);
    }
    expect(cell.started, 0);
    while (!cell.telling) {
      cell.step(1 / 60, shipX: 180, swarm: const []);
    }
    final landed = cell.step(
      1 / 60,
      shipX: 180,
      swarm: const [],
      active: false,
    );
    expect(landed, isEmpty);
    expect(cell.strikes, isEmpty);
    expect(cell.landed, 0);
  });

  test('the rod draws every tell to the ship with a wider column, no fork', () {
    final cell = StormCell(
      2,
      tuning: const StormTuning(shipShare: 0, forkChance: 1),
    );
    while (!cell.telling) {
      cell.step(1 / 60, shipX: 222, swarm: const [40, 50], rod: true);
    }
    final s = cell.strikes.single;
    expect(s.aim, StrikeAim.ship);
    expect(s.x, 222);
    expect(s.rod, isTrue);
    expect(s.column, const StormTuning().rodColumn);
  });

  test('the schedule of a seed does not depend on the aim taken', () {
    // Same seed, different worlds: tells begin on the same steps.
    List<int> starts(List<double> swarm, bool rod) {
      final cell = StormCell(21, tuning: const StormTuning());
      final out = <int>[];
      var seen = 0;
      for (var i = 0; i < 60 * 30; i++) {
        cell.step(1 / 60, shipX: 180, swarm: swarm, rod: rod);
        if (cell.started > seen) {
          out.add(i);
          seen = cell.started;
        }
      }
      return out;
    }

    expect(starts(const [], false), starts(const [10, 20, 30], true));
  });
}
