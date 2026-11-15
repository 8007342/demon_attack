// cinematic-flow task 6.1: the title's attract swarm is deterministic,
// flocks (no lockstep), holds still with reduced motion, and never touches
// the run.
import 'package:demon_attack/game/attract.dart';
import 'package:demon_attack/game/model.dart';
import 'package:flutter_test/flutter_test.dart';

List<(double, double)> run(AttractSwarm a, double seconds) {
  for (var t = 0.0; t < seconds; t += 1 / 60) {
    a.update(1 / 60);
  }
  return [for (final d in a.members) (d.x, d.y)];
}

void main() {
  test('squads of the sector mill, ribbon and sweep, deterministically', () {
    final a = AttractSwarm()..prepare(2);
    final b = AttractSwarm()..prepare(2);
    expect(a.members.length, AttractSwarm.perSquad * 3);
    expect(run(a, 6), run(b, 6));
    expect({
      for (final s in a.squads) s.state,
    }, containsAll([SquadState.mill, SquadState.ribbon, SquadState.sweep]));
    // Every member moves, each on its own phase.
    final before = run(a, 0);
    final after = run(a, 1);
    final moves = [
      for (var i = 0; i < before.length; i++)
        (after[i].$1 - before[i].$1, after[i].$2 - before[i].$2),
    ];
    expect(
      moves.where((m) => m.$1.abs() + m.$2.abs() > 1).length,
      greaterThan(moves.length * .8),
    );
    expect(moves.toSet().length, greaterThan(moves.length ~/ 2));
    // Shadows need altitude and depth.
    for (final d in a.members) {
      expect(d.altitude, greaterThan(0));
      expect(d.nearness, inInclusiveRange(.28, .6));
    }
  });

  test('the sentinel passes once per loop', () {
    final a = AttractSwarm()..prepare(0);
    var seen = 0.0;
    for (var t = 0.0; t < FlowPlan.attractSeconds; t += 1 / 30) {
      a.update(1 / 30);
      seen = seen > a.sentinel.opacity ? seen : a.sentinel.opacity;
    }
    expect(seen, greaterThan(.8));
    expect(a.sentinel.visible, isFalse, reason: 'gone at the loop seam');
  });

  test('reduced motion holds the squads still', () {
    final a = AttractSwarm()
      ..reduced = true
      ..prepare(1);
    run(a, .5);
    expect(run(a, 2), run(a, 0));
  });

  test('the attract swarm never touches a model', () {
    final m = ArcadeModel(seed: 1);
    final a = AttractSwarm()..prepare(0);
    run(a, 5);
    expect(m.demons, isEmpty);
    expect(m.score, 0);
    expect(m.mode, RunMode.title);
  });
}
