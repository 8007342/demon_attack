// transition-ascent task 4.3: the sector change's radio slot answers a
// revisit with a front-line call from the destination sector.
import 'package:demon_attack/game/interlude.dart';
import 'package:demon_attack/game/model.dart';
import 'package:flutter_test/flutter_test.dart';

import 'progression_test.dart' show clearWave, reach;

InterludeContext _ctx({
  int level = 2,
  int route = 1,
  double window = 9,
  bool revisit = true,
  bool carrier = false,
  Set<String> crew = const {},
}) => InterludeContext(
  difficulty: Difficulty.normal,
  level: level,
  route: route,
  window: window,
  crew: crew,
  revisit: revisit,
  nextIsCarrier: carrier,
);

bool _front(InterludePlan? p) =>
    p?.radio?.spec.name.startsWith('frontCall') ?? false;

/// The model at the last kill of [sector] on [route].
ArcadeModel _atLastKill(int sector, int route) {
  final m = ArcadeModel(seed: 11)
    ..startAt(
      sector: sector,
      route: route,
      wave: ArcadeModel.wavesFor(sector: sector, route: route),
    );
  reach(m, RunMode.playing);
  clearWave(m);
  expect(m.mode, RunMode.salvage);
  return m;
}

void main() {
  test('the front-call pool is the destination\'s lines and the general', () {
    for (var level = 1; level <= 4; level++) {
      final pool = radioPool(RadioCategory.frontCall, level: level);
      final names = {for (final p in pool) p.spec.name};
      expect(names, {'frontCall.$level', 'frontCall'});
      expect(pool.length, 7, reason: 'sector $level: 2 own + 5 general');
      for (final p in pool) {
        // Placeholders: a recorded clip with its own subtitle.
        expect(p.line.clip, isNotNull, reason: p.line.id);
        expect(p.text, isNotEmpty, reason: p.line.id);
      }
    }
    // Never part of the seeded draw.
    expect(RadioCategory.drawn, isNot(contains(RadioCategory.frontCall)));
  });

  test('a revisit picks the destination\'s front call first', () {
    for (var level = 1; level <= 4; level++) {
      for (var seed = 0; seed < 20; seed++) {
        final planner = InterludePlanner(seed: seed);
        final plan = planner.planRadio(_ctx(level: level));
        expect(_front(plan), isTrue, reason: 'sector $level seed $seed');
        expect(plan!.radio!.spec.name, 'frontCall.$level');
        expect(plan.radio!.category, RadioCategory.frontCall);
      }
    }
  });

  test('once the destination\'s lines are spent, a general front call', () {
    final planner = InterludePlanner(seed: 3);
    final names = [
      for (var i = 0; i < 4; i++) planner.planRadio(_ctx())!.radio!.spec.name,
    ];
    expect(names.take(2), everyElement('frontCall.2'));
    expect(names.skip(2), everyElement('frontCall'));
  });

  test('a first visit keeps today\'s mission or banter pick', () {
    for (var seed = 0; seed < 40; seed++) {
      for (var level = 1; level <= 4; level++) {
        final planner = InterludePlanner(seed: seed);
        final plan = planner.planRadio(
          _ctx(level: level, route: 0, revisit: false),
        );
        expect(plan, isNotNull);
        expect(_front(plan), isFalse, reason: 'seed $seed level $level');
        // The seeded draw is untouched: the same seed, the same line.
        final again = InterludePlanner(seed: seed)
            .planRadio(_ctx(level: level, route: 0, revisit: false));
        expect(again!.id, plan!.id);
      }
    }
  });

  test('a carrier arrival keeps its own call, never a front call', () {
    for (var seed = 0; seed < 40; seed++) {
      final plan = InterludePlanner(seed: seed)
          .planRadio(_ctx(level: 5, carrier: true));
      expect(_front(plan), isFalse, reason: 'seed $seed');
    }
  });

  test('a window too short for every front call falls back', () {
    final pool = radioPool(RadioCategory.frontCall, level: 3);
    final shortest = pool.map((p) => p.needs).reduce((a, b) => a < b ? a : b);
    // Room = window - 2 fades - the adopt wait.
    final window =
        shortest + InterludeTiming.fade * 2 + InterludeTiming.adoptWait - .05;
    for (var seed = 0; seed < 20; seed++) {
      final plan = InterludePlanner(seed: seed)
          .planRadio(_ctx(level: 3, window: window));
      expect(plan, isNotNull);
      expect(_front(plan), isFalse, reason: 'seed $seed');
    }
  });

  test('the model calls a later tour\'s sector change a revisit', () {
    // Route 0, 2 -> 3: Ringfall to Ember Moon for the first time.
    expect(_atLastKill(2, 0).flowRevisit, isFalse);
    // Route 1, 2 -> 3: the second tour returns to Ember Moon.
    final later = _atLastKill(2, 1);
    expect(later.flowDestination, 3);
    expect(later.flowRevisit, isTrue);
    // 4 -> 5 is the carrier's arrival: its own call.
    expect(_atLastKill(4, 1).flowRevisit, isFalse);
    // A carrier's fall (5 -> the next route's 1) keeps the victory pick.
    final m = ArcadeModel(seed: 11)..startAt(sector: 5, route: 1);
    reach(m, RunMode.playing);
    final b = m.boss!
      ..shield = 0
      ..core = 1
      ..door = 1;
    m.hitBoss(b.x);
    expect(m.flow.kind, FlowKind.bossVictory);
    expect(m.flowRevisit, isFalse);
  });

  test('a sector entered earlier in the run is visited', () {
    final m = ArcadeModel(seed: 11)..startAt(sector: 1, route: 0);
    reach(m, RunMode.playing);
    expect(m.visitedSectors, contains(1));
    // A new run forgets the old one: only its first sector is visited.
    m.start();
    expect(m.visitedSectors, {1});
  });
}
