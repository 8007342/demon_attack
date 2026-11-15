// cinematic-flow task 2.4 (design §7, model level): the transition's phase
// chain, lengths, skip, pause, the boss and outro plans.
import 'package:demon_attack/game/model.dart';
import 'package:flutter_test/flutter_test.dart';

import 'progression_test.dart' show clearWave, reach, tick;

/// A model in the last wave of [sector], cleared: the Rout has begun.
ArcadeModel routed({
  int sector = 1,
  int route = 0,
  bool reduced = false,
  int seed = 7,
}) {
  final m = ArcadeModel(seed: seed)
    ..reducedMotion = reduced
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

/// Phase lengths seen from the salvage to the next sector's fight.
List<(RunMode, double)> chain(ArcadeModel m) {
  final out = <(RunMode, double)>[];
  RunMode? last;
  for (var f = 0; f < 60 * 30 && m.mode != RunMode.playing; f++) {
    if (m.mode != last) {
      out.add((m.mode, m.transitionDuration));
      last = m.mode;
    }
    m.update(1 / 60);
  }
  return out;
}

void main() {
  test('sector change: Rout 2.0, Pursuit 2.0 + 4.0, Descent 4.5', () {
    final m = routed();
    expect(m.flow.kind, FlowKind.sectorChange);
    final c = chain(m);
    expect(
      [for (final p in c) p.$1],
      [RunMode.salvage, RunMode.levelClear, RunMode.travel, RunMode.transition],
    );
    expect(c[0].$2, 2.0);
    expect(c[1].$2, 2.0);
    expect(c[2].$2, 4.0);
    expect(c[3].$2, ArcadeModel.arrivalHintDuration);
    expect(m.level, 2);
    expect(m.flow.active, isFalse, reason: 'the flow ends with the Descent');
    expect(m.flowFlock, isEmpty);
  });

  test('reduced motion: the same phases, Pursuit 1.0 + 2.5', () {
    final m = routed(reduced: true);
    expect(m.flow.plan.reduced, isTrue);
    final c = chain(m);
    expect([for (final p in c) p.$2].take(3), [2.0, 1.0, 2.5]);
    expect(m.flow.plan.beat('tilt'), isNull, reason: 'flow ended');
  });

  test('a slot extends Pursuit by whole beats, at most 2 s', () {
    for (final (extra, travel) in [(0.3, 4.5), (1.2, 5.5), (9.0, 6.0)]) {
      final m = routed();
      reach(m, RunMode.levelClear);
      m.slotExtra = extra;
      reach(m, RunMode.travel);
      expect(m.transitionDuration, travel);
      expect(m.flow.plan.pursuitSeconds, 2 + travel);
      expect((m.flow.plan.pursuitSeconds / flowBeat) % 1, 0);
    }
  });

  test('music cues land on the 120 BPM grid (task 5.1)', () {
    for (final (reduced, extra) in [(false, 0.0), (false, 1.2), (true, 0.0)]) {
      final m = routed(reduced: reduced)..takeEvents();
      final at = <String, double>{};
      var t = 0.0;
      for (var f = 0; f < 60 * 20 && m.mode != RunMode.playing; f++) {
        if (m.mode == RunMode.levelClear) m.slotExtra = extra;
        m.update(1 / 60);
        t += 1 / 60;
        for (final e in m.takeEvents()) {
          if (const ['levelclear', 'travel', 'level'].contains(e)) {
            at.putIfAbsent(e, () => t);
          }
        }
      }
      // The stinger is immediate at the Pursuit's start (it starts its own
      // grid); travel 4 beats later; the next sector's cue whole beats later.
      final travel = at['travel']! - at['levelclear']!;
      final level = at['level']! - at['levelclear']!;
      expect(travel, closeTo(FlowPlan.clearFor(reduced), 1 / 20));
      final beats = level / flowBeat;
      // Within three 60 Hz frames (phase boundaries step on frames; the
      // worklet snaps the cue to its bar grid).
      expect((beats - beats.round()).abs() * flowBeat, lessThan(1 / 20));
      expect(
        level,
        closeTo(
          FlowPlan.clearFor(reduced) +
              FlowPlan.travelFor(reduced, extra: extra),
          1 / 20,
        ),
      );
    }
  });

  test('the director runs on the model clock and pause freezes it', () {
    final m = routed();
    tick(m, 1);
    final s = m.flow.seconds;
    expect(s, closeTo(1, .05));
    m.pause();
    tick(m, 2);
    expect(m.flow.seconds, s);
    m.resume();
    reach(m, RunMode.travel);
    // Rout 2 + clear 2 = the travel's start on the plan clock.
    expect(m.flow.seconds, closeTo(4, .05));
  });

  test('skip lands in the Descent within one step', () {
    for (final phase in [RunMode.levelClear, RunMode.travel]) {
      final m = routed();
      reach(m, phase);
      tick(m, .5);
      final lives = m.lives, medals = m.medals, score = m.score;
      expect(m.skipTransition(), isTrue);
      m.update(1 / 60);
      expect(m.mode, RunMode.transition);
      expect(m.level, 2);
      expect(m.flow.seconds, closeTo(m.flow.plan.descentAt, .05));
      expect((m.lives, m.medals, m.score), (lives, medals, score));
    }
  });

  test('skip never shortens the pickup grace', () {
    final m = routed();
    tick(m, .5);
    expect(m.skipTransition(), isTrue);
    expect(m.skipPending, isTrue);
    tick(m, 1.2);
    expect(m.mode, RunMode.salvage, reason: 'the grace runs its 2 s');
    m.update(1 / 60);
    tick(m, .4);
    expect(m.mode, RunMode.transition);
    expect(m.level, 2);
  });

  test('the last kill leaves no flock: nothing flees through the fog', () {
    // playtest-fixes: the rout scatters only creatures that were fighting,
    // and a sector ends when every one of them fell.
    final m = routed();
    expect(m.flowFlock, isEmpty);
    expect(m.demons, isEmpty);
    expect(m.fogStaged, isEmpty);
    expect(m.flowDirection.abs(), 1, reason: 'the cohort side is still set');
    while (m.flow.active && m.mode != RunMode.transition) {
      m.update(1 / 60);
      expect(m.flowFlock, isEmpty);
      if (m.level != 1) break; // the next sector's own reserve
      expect(m.fogStaged, isEmpty);
    }
  });

  test(
    'the next sector\'s lead skein leaves the cloud where the flock went',
    () {
      var matched = 0, total = 0;
      for (var seed = 1; seed <= 6; seed++) {
        for (final sector in [1, 2, 3]) {
          final m = routed(sector: sector, seed: seed);
          final dir = m.flowDirection;
          reach(m, RunMode.transition);
          final lead = [
            for (final d in m.demons)
              if (d.gate != null && d.gate!.side != 0) d,
          ]..sort((a, b) => a.skein.compareTo(b.skein));
          if (lead.isEmpty) continue;
          total++;
          if (lead.first.gate!.side == dir) matched++;
        }
      }
      expect(total, greaterThan(10));
      expect(matched, total);
    },
  );

  test('boss arrival: the carrier overflies and sinks into the far fog', () {
    final m = routed(sector: 4);
    expect(m.flow.kind, FlowKind.bossArrival);
    reach(m, RunMode.transition);
    // boss-grandeur: the level opens with its loom wave; the carrier is a
    // presentation overflight, then looms under the fog (no carrier yet).
    expect(m.isBoss, isFalse);
    expect(m.looming, isTrue);
    expect(m.flowFlock, isEmpty, reason: 'nobody was left fighting');
    var overflown = false;
    while (m.mode == RunMode.transition) {
      if (m.flow.env('overflight') > .9) overflown = true;
      m.update(1 / 60);
    }
    expect(overflown, isTrue);
    expect(m.mode, RunMode.playing);
    expect(m.flowFlock, isEmpty, reason: 'gone into the fog with it');
    expect(m.flow.active, isFalse);
  });

  test('boss victory: the fighting minions scatter, then the route jump', () {
    final m = ArcadeModel(seed: 3)..startAt(sector: 5);
    reach(m, RunMode.playing);
    final fighting = m.demons
        .where((d) => d.swarmState != SwarmState.reserve)
        .length;
    final b = m.boss!
      ..shield = 0
      ..core = 1
      ..door = 1;
    m.hitBoss(b.x);
    expect(m.mode, RunMode.victory);
    expect(m.transitionDuration, 5.5);
    expect(m.flow.kind, FlowKind.bossVictory);
    expect(m.flowFlock.length, fighting.clamp(0, 18));
    final medals = m.medals, lives = m.lives;
    final c = chain(m);
    expect(
      [for (final p in c) p.$1],
      [RunMode.victory, RunMode.travel, RunMode.transition],
    );
    expect(c[1].$2, 4.0);
    expect((m.level, m.cycle), (1, 1));
    expect((m.medals, m.lives), (medals, lives));
  });

  test('campaign outro ends in completed', () {
    final m = ArcadeModel(seed: 3)
      ..startAt(sector: 5, route: ArcadeModel.finalRoute);
    reach(m, RunMode.playing);
    final b = m.boss!
      ..shield = 0
      ..core = 1
      ..door = 1;
    m.hitBoss(b.x);
    expect(m.flow.kind, FlowKind.campaignOutro);
    expect(m.skipTransition(), isFalse, reason: 'the ending has its own skip');
    var thin = 0.0;
    while (m.mode == RunMode.victory) {
      thin = m.flow.env('thin');
      m.update(1 / 60);
    }
    expect(thin, greaterThan(.9));
    expect(m.mode, RunMode.completed);
  });

  test('game over: the swarm mills over the wreck before the pan', () {
    final m = ArcadeModel(seed: 5)..start();
    reach(m, RunMode.playing);
    m.lives = 1;
    m.invulnerable = 0;
    m.shots.add(Shot(m.shipX, ArcadeModel.shipY, 0, 0, hostile: true));
    m.update(.1);
    expect(m.mode, RunMode.gameOver);
    expect(m.flow.kind, FlowKind.gameOverOutro);
    var milledBeforePan = false;
    while (m.defeatActive) {
      if (m.flow.env('mill') > .95 && m.cameraPanY == 0) {
        milledBeforePan = true;
      }
      m.update(1 / 60);
    }
    expect(milledBeforePan, isTrue);
    expect(m.flow.active, isFalse);
  });
}
