import 'dart:math' as math;

import 'model.dart' show Demon;
import 'perspective.dart';
import 'swarm_stream.dart' show SwarmGate, SwarmGateGeometry;

/// The swarm's flight (openspec/changes/continuous-swarm design §3, built on
/// openspec/changes/atmosphere-and-swarms design §3 and
/// plan/atmosphere-research.md §6-§9).
///
/// continuous-swarm: the flock is model-owned. It is stepped from
/// `ArcadeModel._step` at the model's fixed 60 Hz (one step per frame, no
/// interpolation), keeps an agent for a creature's whole flight, and flies
/// each skein a **parabolic swoop** out of the fog: a quadratic Bezier
/// ground track from its gate (or its reserve point) to its station that
/// swings out to the side opposite the gate, so the stream crosses the
/// arena (banked renders), and an altitude parabola that rises out of the
/// fog, crests and settles. The hand-off blends into the squad's pattern
/// target (the model's `_targetFormationPosition`), which decides where
/// hitboxes are; the parity rule below is retired (design §0).
///
/// Historical notes (atmosphere-and-swarms):
///
/// Every wave and reinforcement group flies in from inside the fog as a
/// flock: 2-4 squadrons, each led along a curved path from a point on the
/// horizon to its share of the formation; every creature steers toward its
/// own goal on that path (offset pursuit, Reynolds) with separation,
/// alignment and cohesion against its 7 nearest flock-mates (topological
/// neighbours, Ballerini et al. 2008) plus wander, with its own launch
/// delay, speed curve and altitude arc. A sentinel's escort comes as an
/// insect swarm instead: bound to a moving centre by a spring, no
/// alignment, strong noise (Kelley & Ouellette 2013).
///
/// Presentation over the simulation's timing: the entrance clock, rosters
/// and targetability are the model's (`entranceProgress`; entering creatures
/// cannot be hit and do not fire). The flock only decides *where* an
/// entering creature is drawn, and hands it to the model's own slot
/// position with a smooth blend that is complete exactly when its entrance
/// ends, so the fight is identical with or without it (parity test).
///
/// World space: lateral X = (x - 180) / n and depth Z = 348 / n arena units,
/// so a creature is about [spriteWorld] wide at every depth and neighbour
/// distances do not shrink in the distance. Seeded and deterministic: one
/// PRNG per batch from (run seed, sector, route, wave, batch), fixed
/// iteration order, 30 Hz fixed step with interpolation.
enum FlockStyle { squadrons, insect }

class FlockAgent {
  FlockAgent(this.demon, this.batch);
  final Demon demon;
  final FlockBatch batch;
  int squad = 0;

  // Seeded constants.
  double launch = 0, ease = 2, gain = 1, hPeak = 20;
  double wanderPhase = 0, wanderRate = 1, wingRate = 1;

  /// Crest of the published altitude parabola, times the fighting altitude.
  double altPeak = 1.7;
  double millPhase = 0;

  /// Home offset from the squadron anchor (world units).
  double offX = 0, offZ = 0;

  /// Simulation state (world) at the last two 30 Hz steps.
  double x = 0, z = 0, vx = 0, vz = 0, px = 0, pz = 0;

  /// Goal last step (for its velocity feed-forward).
  double gx = 0, gz = 0;
  bool _started = false;

  /// The model's own placement this frame (screen) and entrance progress.
  double refX = 0, refY = 0, refN = 0, e = 0;
  bool holding = false;
  int stamp = -1;

  /// Hand-off blend 0 (flock) -> 1 (slot), never decreasing.
  double beta = 0, lockTime = 0, flightTime = 0;

  /// Altitude above the flight sheet (screen units) for the shadows.
  double altitude = 0;

  /// Drawn screen position this frame and the frame before (kinematics).
  double drawnX = double.nan, drawnY = double.nan, prevX = 0, prevY = 0;
}

class FlockSquad {
  FlockSquad(
    this.p0x,
    this.p0z,
    this.p1x,
    this.p1z,
    this.p2x,
    this.p2z,
    this.p3x,
    this.p3z,
  );
  final double p0x, p0z, p1x, p1z, p2x, p2z, p3x, p3z;

  /// Cubic Bezier point of the leader's path at [u].
  (double, double) at(double u) {
    final a = 1 - u;
    final b0 = a * a * a, b1 = 3 * a * a * u, b2 = 3 * a * u * u;
    final b3 = u * u * u;
    return (
      b0 * p0x + b1 * p1x + b2 * p2x + b3 * p3x,
      b0 * p0z + b1 * p1z + b2 * p2z + b3 * p3z,
    );
  }
}

class FlockBatch {
  FlockBatch(this.id, this.style, this.rng);
  final int id;
  final FlockStyle style;
  final math.Random rng;
  final squads = <FlockSquad>[];
  final agents = <FlockAgent>[];

  /// Insect swarm: the screen point it pours out of (a sentinel's
  /// silhouette), if any.
  double? originX, originY, originN;
}

/// Deprecated name of [SwarmFlock].
typedef ArrivalFlock = SwarmFlock;

class SwarmFlock {
  SwarmFlock({this.seed = 0});
  int seed;

  /// World units per screen unit at n = 1 (depth Z = depthUnit / n).
  static const depthUnit = 348.0;

  /// Width of an ordinary creature in world units (40 * 1.8 n / n).
  static const spriteWorld = 72.0;

  /// Nearness of the horizon points the squadrons set out from.
  static const startNear = .24;

  /// Fixed simulation step: the model's own.
  static const step = 1 / 60;

  /// Published altitude (screen units above the ground, for the shadows)
  /// of a creature fighting at home row [homeY]: 70 + 30 per row band.
  static double fightAltitude(double homeY) =>
      70 + 30 * ((homeY - 70) / 96).clamp(0.0, 3.0).floorToDouble();

  /// Altitude in the fog where a swoop sets out.
  static const fogAltitude = 14.0;

  /// Topological neighbours.
  static const neighbours = 7;

  final _agents = <Demon, FlockAgent>{};
  final _batches = <FlockBatch>[];
  int _batchCount = 0, _frame = 0;
  double _time = 0;

  Iterable<FlockAgent> get agents => _agents.values;
  FlockAgent? of(Demon d) => _agents[d];
  bool get isEmpty => _agents.isEmpty;

  void clear() {
    _agents.clear();
    _batches.clear();
  }

  static double _u(math.Random r, double a, double b) =>
      a + (b - a) * r.nextDouble();

  static double worldX(double x, double n) => (x - 180) / n;
  static double worldZ(double n) => depthUnit / n;
  static double nearOf(double z) => depthUnit / z;

  /// Starts a flock for [demons] (one wave roster or one reinforcement
  /// group). [salt] distinguishes batches of one wave for the seed.
  FlockBatch launch(
    List<Demon> demons, {
    required int sector,
    required int route,
    required int wave,
    FlockStyle style = FlockStyle.squadrons,
    double? originX,
    double? originY,
    double? originN,
    SwarmGate? gate,
  }) {
    final id = _batchCount++;
    final rng = math.Random(
      (seed * 73856093) ^
          (sector * 19349663) ^
          (route * 83492791) ^
          (wave * 2654435761) ^
          (id * 40503),
    );
    final batch = FlockBatch(id, style, rng)
      ..originX = originX
      ..originY = originY
      ..originN = originN;
    // A gate means one skein (continuous swarm): one squadron, flown on a
    // swoop; a creature already flying is relaunched (a diver's re-entry).
    final members = [
      for (final d in demons)
        if (!d.isLarge && (gate != null || !_agents.containsKey(d))) d,
    ];
    for (final d in members) {
      final old = _agents.remove(d);
      old?.batch.agents.remove(old);
    }
    if (members.isEmpty) return batch;
    // Squadrons by formation column band: 2 (small groups) to 4.
    final count = gate != null
        ? 1
        : members.length <= 6
        ? 2
        : members.length <= 14
        ? 3
        : 4;
    final squads = math.min(count, members.length);
    final cols = [for (final d in members) d.homeX]..sort();
    final lo = cols.first, hi = cols.last;
    int squadOf(Demon d) => hi - lo < 1
        ? 0
        : ((d.homeX - lo) / (hi - lo + 1e-6) * squads).floor().clamp(
            0,
            squads - 1,
          );
    final z0 = worldZ(startNear);
    final squadLaunch = <double>[];
    final order = List<int>.generate(squads, (i) => i);
    for (var i = squads - 1; i > 0; i--) {
      final j = rng.nextInt(i + 1);
      final t = order[i];
      order[i] = order[j];
      order[j] = t;
    }
    for (var s = 0; s < squads; s++) {
      // Anchor: the mean of the squadron's slots, in world space.
      var ax = 0.0, az = 0.0, k = 0;
      for (final d in members) {
        if (squadOf(d) != s) continue;
        final n = Perspective.nearnessAtY(d.homeY);
        ax += worldX(d.homeX, n);
        az += worldZ(n);
        k++;
      }
      if (k == 0) {
        squadLaunch.add(0);
        batch.squads.add(FlockSquad(0, z0, 0, z0, 0, z0, 0, z0));
        continue;
      }
      ax /= k;
      az /= k;
      // Horizon point spread around the vanishing point, toward its side.
      final side = squads == 1 ? 0.0 : (s / (squads - 1)) * 2 - 1;
      final double hx, hz;
      // Where the skein waited (its reserve point or the gate it was put
      // at), as the mean of its members' entry points.
      var ex = 0.0, en = 0.0, ek = 0;
      for (final d in members) {
        final x = d.entryX, n = d.entryN;
        if (x == null || n == null || n <= 0) continue;
        ex += worldX(x, n);
        en += worldZ(n);
        ek++;
      }
      if (style == FlockStyle.insect && originX != null) {
        final on = originN ?? startNear;
        hx = worldX(originX, on);
        hz = worldZ(on);
      } else if (gate != null && ek > 0) {
        hx = ex / ek;
        hz = en / ek;
      } else if (gate != null) {
        hx = worldX(gate.screenX, gate.nearness);
        hz = worldZ(gate.nearness);
      } else {
        hx = worldX(180 + side * _u(rng, 40, 95) + _u(rng, -18, 18), startNear);
        hz = z0 * _u(rng, .96, 1.08);
      }
      final swing = _u(rng, 160, 320) * (rng.nextBool() ? 1 : -1);
      if (gate != null && style == FlockStyle.squadrons) {
        // The swoop's ground track: a quadratic Bezier whose control point
        // swings out toward the side opposite the gate (design §3), as a
        // cubic with the same curve.
        final side = gate.side != 0 ? gate.side : (swing > 0 ? -1 : 1);
        final cx = (hx + ax) / 2 - side * swing.abs();
        final cz = hz * .6 + az * .4;
        batch.squads.add(
          FlockSquad(
            hx,
            hz,
            hx + (cx - hx) * 2 / 3,
            hz + (cz - hz) * 2 / 3,
            ax + (cx - ax) * 2 / 3,
            az + (cz - az) * 2 / 3,
            ax,
            az,
          ),
        );
        squadLaunch.add(0);
        continue;
      }
      batch.squads.add(
        FlockSquad(
          hx,
          hz,
          hx * .5 + swing,
          hz * .78 + az * .22,
          ax - swing * .35,
          az + (hz - az) * .3,
          ax,
          az,
        ),
      );
      // Squadron starts stagger across the first part of the entrance.
      squadLaunch.add(order[s] * _u(rng, .07, .11));
    }
    for (final d in members) {
      final s = squadOf(d);
      final sq = batch.squads[s];
      final a = FlockAgent(d, batch)
        ..squad = s
        ..launch = (squadLaunch[s] + _u(rng, .0, .06)).clamp(0.0, .4)
        ..ease = _u(rng, 1.7, 2.6)
        ..gain = _u(rng, .85, 1.15)
        ..hPeak =
            (gate != null ? _u(rng, 26, 40) : _u(rng, 16, 26)) *
            _u(rng, .8, 1.2)
        ..altPeak = _u(rng, 1.4, 2.0)
        ..wanderPhase = _u(rng, 0, 2 * math.pi)
        ..wanderRate = _u(rng, .8, 1.6)
        ..wingRate = _u(rng, .9, 1.1)
        ..millPhase = _u(rng, 0, 2 * math.pi);
      final n = Perspective.nearnessAtY(d.homeY);
      a
        ..offX = worldX(d.homeX, n) - sq.p3x
        ..offZ = worldZ(n) - sq.p3z;
      d.wingRate = a.wingRate;
      batch.agents.add(a);
      _agents[d] = a;
    }
    _batches.add(batch);
    return batch;
  }

  /// The model's own placement of [d] last frame (its slot track), while
  /// the flock draws it elsewhere; null when the flock has not placed it.
  (double, double)? slotTrack(Demon d) {
    final a = _agents[d];
    if (a == null || a.stamp < 0) return null;
    return (a.refX, a.refY);
  }

  /// Records the model's own placement of [d] this frame (its slot track)
  /// and its entrance progress; creates a solo flock for strays (restored
  /// checkpoints, hand-built fixtures).
  void reference(
    Demon d, {
    required int sector,
    required int route,
    required int wave,
    bool holding = false,
  }) {
    var a = _agents[d];
    if (a == null) {
      launch([d], sector: sector, route: route, wave: wave);
      a = _agents[d];
      if (a == null) return;
    }
    a
      ..refX = d.x
      ..refY = d.y
      ..refN = d.nearness
      ..e = d.entranceProgress
      ..holding = holding
      ..stamp = _frame;
  }

  /// Leader-path parameter for agent progress [e]: launch delay, then its
  /// own ease-out (speed variety without lockstep).
  static double pathU(FlockAgent a, double e) {
    final tau = ((e - a.launch) / (1 - a.launch)).clamp(0.0, 1.0);
    return 1 - math.pow(1 - tau, a.ease).toDouble();
  }

  /// Hand-off window (share of the entrance) for an entrance of [duration].
  static double handoffShare(double duration) =>
      (.4 / math.max(.2, duration)).clamp(.25, .5);

  (double, double) _goal(FlockAgent a, double u) {
    final sq = a.batch.squads[a.squad];
    var (x, z) = sq.at(u);
    // The formation unfolds as it nears: tight far away, slots at the end.
    final spread = .3 + .7 * u * u;
    x += a.offX * spread;
    z += a.offZ * spread;
    if (a.batch.style == FlockStyle.insect) {
      // Insect swarm: a personal orbit about the moving centre, strong
      // noise, shrinking into the slot.
      final r = (1 - u) * 110;
      final w = _time * (2.2 + a.wanderRate) + a.wanderPhase;
      x += math.cos(w) * r;
      z += math.sin(w * 1.3) * r * .8;
    }
    if (a.holding) {
      // Milling in the fog while the wave holds: a slow squadron circle.
      final w = _time * .55 + a.millPhase * .25 + a.squad * 1.7;
      x += math.cos(w) * 70;
      z += math.sin(w) * 55;
    }
    return (x, z);
  }

  /// Advances the flock by [dt] (the entrance's own clock) and writes the
  /// drawn position of every agent referenced this frame. Agents whose
  /// creature has finished entering or left are dropped.
  List<FlockAgent> advance(double dt) {
    final live = <FlockAgent>[
      for (final a in _agents.values)
        if (a.stamp == _frame && a.demon.entering) a,
    ];
    // Agents live for the creature's whole flight (continuous swarm);
    // creatures no longer placed at all (removed from play) leave after a
    // grace of ten seconds of frames.
    _agents.removeWhere((d, a) => a.stamp >= 0 && _frame - a.stamp > 600);
    _batches.removeWhere(
      (b) => b.agents.every((a) => !_agents.containsKey(a.demon)),
    );
    _frame++;
    if (live.isEmpty) return live;
    for (final a in live) {
      if (!a._started) {
        final u = pathU(a, a.e);
        final (gx, gz) = _goal(a, u);
        a
          ..x = a.px = a.gx = gx
          ..z = a.pz = a.gz = gz
          ..vx = 0
          ..vz = 0
          .._started = true;
      }
    }
    // One step per model frame (the model is already fixed-step): no
    // accumulator, no interpolation between gameplay positions.
    if (dt <= 0) {
      for (final a in live) {
        _place(a, 1, dt);
      }
      return live;
    }
    _time += dt;
    _step(live, dt);
    for (final a in live) {
      _place(a, 1, dt);
    }
    return live;
  }

  void _step(List<FlockAgent> live, double h) {
    // Goals and their velocities first (fixed order).
    final goals = <(double, double, double, double)>[];
    for (final a in live) {
      final (gx, gz) = _goal(a, pathU(a, a.e));
      final gvx = (gx - a.gx) / h, gvz = (gz - a.gz) / h;
      a
        ..gx = gx
        ..gz = gz;
      goals.add((gx, gz, gvx, gvz));
    }
    final ax = List<double>.filled(live.length, 0);
    final az = List<double>.filled(live.length, 0);
    final nearest = List<int>.filled(neighbours, -1);
    final nearestD = List<double>.filled(neighbours, double.infinity);
    for (var i = 0; i < live.length; i++) {
      final a = live[i];
      final (gx, gz, gvx, gvz) = goals[i];
      final u = pathU(a, a.e);
      final insect = a.batch.style == FlockStyle.insect;
      // Arrive-to-slot as a critically damped pursuit of the moving goal
      // (offset pursuit with feed-forward): weight .6 -> 2 as it settles.
      final w = (5.5 + 4.5 * u) * a.gain;
      var fx = w * w * (gx - a.x) + 2 * .8 * w * (gvx - a.vx);
      var fz = w * w * (gz - a.z) + 2 * .8 * w * (gvz - a.vz);
      // k nearest flock-mates in the same batch (brute force, N <= ~40).
      for (var k = 0; k < neighbours; k++) {
        nearest[k] = -1;
        nearestD[k] = double.infinity;
      }
      for (var j = 0; j < live.length; j++) {
        if (j == i || !identical(live[j].batch, a.batch)) continue;
        final dx = live[j].x - a.x, dz = live[j].z - a.z;
        final d2 = dx * dx + dz * dz;
        if (d2 >= nearestD[neighbours - 1]) continue;
        var k = neighbours - 1;
        while (k > 0 && nearestD[k - 1] > d2) {
          nearestD[k] = nearestD[k - 1];
          nearest[k] = nearest[k - 1];
          k--;
        }
        nearestD[k] = d2;
        nearest[k] = j;
      }
      var sepX = 0.0, sepZ = 0.0, aliX = 0.0, aliZ = 0.0;
      var cohX = 0.0, cohZ = 0.0, count = 0;
      const sepR = spriteWorld * 1.2;
      for (var k = 0; k < neighbours; k++) {
        final j = nearest[k];
        if (j < 0) break;
        final o = live[j];
        final dx = a.x - o.x, dz = a.z - o.z;
        final d = math.sqrt(nearestD[k]) + 1e-6;
        if (d < sepR) {
          final push = (sepR - d) / sepR;
          sepX += dx / d * push;
          sepZ += dz / d * push;
        }
        aliX += o.vx;
        aliZ += o.vz;
        cohX += o.x;
        cohZ += o.z;
        count++;
      }
      final settle = u * u;
      // Weights (research §6), arrival -> settle.
      fx += 1.5 * 2600 * sepX;
      fz += 1.5 * 2600 * sepZ;
      if (count > 0) {
        if (!insect) {
          final wa = 1.0 * 2.2;
          fx += wa * (aliX / count - a.vx);
          fz += wa * (aliZ / count - a.vz);
        }
        final wc = (insect ? 1.6 : .8 - .6 * settle) * 6;
        fx += wc * (cohX / count - a.x);
        fz += wc * (cohZ / count - a.z);
      }
      final wander = (insect ? 3.2 : .3 - .25 * settle) * 2400;
      final phase = a.wanderPhase + _time * a.wanderRate * 2.1;
      fx += wander * math.cos(phase);
      fz += wander * math.sin(phase * 1.31) * .7;
      ax[i] = fx;
      az[i] = fz;
    }
    for (var i = 0; i < live.length; i++) {
      final a = live[i];
      a
        ..px = a.x
        ..pz = a.z
        ..vx += ax[i] * h
        ..vz += az[i] * h;
      // Speed cap well above the goal's own pace.
      final (_, _, gvx, gvz) = goals[i];
      final cap = 2.2 * math.sqrt(gvx * gvx + gvz * gvz) + 420;
      final sp = math.sqrt(a.vx * a.vx + a.vz * a.vz);
      if (sp > cap) {
        a
          ..vx *= cap / sp
          ..vz *= cap / sp;
      }
      a
        ..x += a.vx * h
        ..z = math.max(depthUnit / .95, a.z + a.vz * h);
    }
  }

  /// Screen placement: interpolated simulation, projected through the
  /// camera with the altitude arc, blended into the model's slot by beta.
  void _place(FlockAgent a, double alpha, double dt) {
    final d = a.demon;
    final x = a.px + (a.x - a.px) * alpha;
    final z = a.pz + (a.z - a.pz) * alpha;
    final n = nearOf(z);
    final u = pathU(a, a.e);
    final slotN = Perspective.nearnessAtY(d.homeY);
    final y0 = Perspective.arrivalYFor(d.homeY);
    double yBase;
    if (n >= Perspective.nearFar) {
      final k = slotN <= Perspective.nearFar
          ? 1.0
          : ((n - Perspective.nearFar) / (slotN - Perspective.nearFar)).clamp(
              0.0,
              1.2,
            );
      yBase = y0 + (d.homeY - y0) * k;
    } else {
      // Beyond the arrival depth: sinking toward the horizon line.
      final k = ((Perspective.nearFar - n) / (Perspective.nearFar - .16)).clamp(
        0.0,
        1.0,
      );
      yBase = y0 + (Perspective.horizonY - 3 - y0) * k;
    }
    // Parabolic altitude arc, as the ground missiles (research §7).
    final h = a.hPeak * 4 * u * (1 - u) * (n / .5);
    final sx = 180 + x * n;
    final sy = yBase - h;
    // Hand-off: a smoothstep ramp over the last part of the entrance
    // (complete exactly at its end), or earlier once close and slow.
    final share = handoffShare(d.entranceDuration);
    var beta = Perspective.smoothstep(1 - share, 1, a.e);
    if (!a.holding && a.e > 0) {
      a.flightTime += dt;
      final dx = sx - a.refX, dy = sy - a.refY;
      if ((dx * dx + dy * dy < 16 && u > .6) || a.flightTime > 4) {
        a.lockTime += dt;
      }
      beta = math.max(beta, Perspective.smoothstep(0, .4, a.lockTime));
    }
    if (a.e >= 1) beta = 1;
    a.beta = math.max(a.beta, beta);
    final b = a.beta;
    // Published altitude (shadows): out of the fog, a crest, the fight's
    // height (design §3): h0 + (h_peak - h0) 4u(1 - u) + (h_fight - h0) u².
    final hf = fightAltitude(d.homeY);
    const h0 = fogAltitude;
    final hu = h0 + (a.altPeak * hf - h0) * 4 * u * (1 - u) + (hf - h0) * u * u;
    a
      ..prevX = a.drawnX.isNaN ? a.refX : a.drawnX
      ..prevY = a.drawnY.isNaN ? a.refY : a.drawnY;
    d.x = (sx + (a.refX - sx) * b).clamp(-40.0, 400.0);
    d.y = sy + (a.refY - sy) * b;
    d.nearness = n + (a.refN - n) * b;
    a.altitude = hu + (hf - hu) * b;
    d.altitude = a.altitude;
    a
      ..drawnX = d.x
      ..drawnY = d.y;
  }
}
