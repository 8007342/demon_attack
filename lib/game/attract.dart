/// The title's attract loop (openspec/changes/cinematic-flow design §5,
/// task 6.1): two or three squads of the current sector's species mill,
/// ribbon and sweep in the fog behind the title (swarm_patterns.dart, no
/// model run), the sentinel's silhouette passes once per loop, and the
/// scene casts their shadows on the ground. Presentation only: no hitboxes,
/// no score, nothing written; deterministic from its seed.
library;

import 'dart:math' as math;

import 'model.dart';

class AttractSwarm {
  AttractSwarm({this.seed = 1982});
  final int seed;

  /// The loop's clock (FlowPlan.attract): the mill fades in and out at the
  /// loop's ends, the sentinel passes in the middle.
  final flow = FlowDirector()..start(FlowPlan.attract());

  final squads = <Squad>[];
  final members = <Demon>[];
  final _squadOf = <Demon, Squad>{};

  /// The sentinel's silhouette (the giant circling deep in the fog).
  final sentinel = SentinelForeshadow(EnemyArchetype.shieldSentinel, .5);

  int _sector = -1;
  bool reduced = false;

  /// Members per squad and squads (a light combat frame's worth).
  static const perSquad = 6;
  static const stations = [(104.0, 150.0), (252.0, 176.0), (178.0, 214.0)];
  static const states = [SquadState.mill, SquadState.ribbon, SquadState.sweep];

  /// Builds the squads for [sector] (0-4) if it changed.
  void prepare(int sector) {
    if (sector == _sector) return;
    _sector = sector;
    squads.clear();
    members.clear();
    _squadOf.clear();
    final rng = math.Random(seed ^ (sector * 7919));
    for (var s = 0; s < stations.length; s++) {
      final (x, y) = stations[s];
      final squad = Squad(
        s,
        math.Random(rng.nextInt(1 << 30)),
        stationX: x,
        stationY: y,
        state: states[s],
      );
      squads.add(squad);
      for (var i = 0; i < perSquad; i++) {
        final d = Demon(x, y, (sector + s + i) % 4, 1, rng.nextDouble() * 10)
          ..swarmState = SwarmState.present
          ..entranceProgress = 1;
        squad.add(d, i);
        _squadOf[d] = squad;
        members.add(d);
      }
    }
    sentinel
      ..archetype = sector.isEven
          ? EnemyArchetype.shieldSentinel
          : EnemyArchetype.armoredSentinel
      ..clock = 0;
  }

  /// Advances the loop by [dt] seconds.
  void update(double dt) {
    _age += dt;
    flow.advance(dt);
    final motion = reduced ? 0.0 : dt;
    for (final squad in squads) {
      squad.update(
        math.max(motion, 1e-6),
        tempo: 1,
        flying: [
          for (final d in members)
            if (identical(_squadOf[d], squad)) d,
        ],
      );
    }
    final k = reduced ? 1.0 : 1 - math.exp(-4 * dt);
    for (final d in members) {
      final target = _squadOf[d]!.target(d);
      if (target == null) continue;
      final (tx, ty) = target;
      final ox = d.x;
      d
        ..x += (tx - d.x) * k
        ..y += (ty - d.y) * k
        ..vx = dt > 0 ? (d.x - ox) / dt : 0
        ..altitude = 40 + _squadOf[d]!.altitude(d, 0)
        ..nearness = Perspective.nearnessAtY(d.y).clamp(.28, .6)
        ..scale = Perspective.scaleOf(Perspective.nearnessAtY(d.y));
    }
    sentinel
      ..clock += reduced ? 0 : dt
      ..growth = .45
      ..opacity = .85 * flow.env('sentinel')
      ..place();
  }

  double _age = 0;

  /// Squad presence 0-1: fades in once when the title opens (the squads'
  /// own clocks never loop, so there is no seam to hide).
  double get presence => Perspective.smoothstep(0, 2, _age);
}
