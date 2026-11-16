import 'dart:math' as math;
import 'dart:typed_data';

/// carrier-render-engine §3: the cohesive collapse.
///
/// The dying carrier is ONE texture (the hull as it was at death, both
/// passes composed) cut into a two-level hierarchy of chunks
/// ([CarrierFracture]): sections (the wings, the stern, the fore hull that
/// keeps the deck) and, inside each, chunks. Every piece is a rigid body
/// of a closed-form ballistic model ([CarrierCollapse]): until its release
/// it rides its parent exactly; at release it inherits the parent's
/// velocity at its own pivot (v + ω × r) and spin, plus a small separation
/// impulse. So the hull sags, cracks along its structure, the sections
/// shear off with shared momentum, the smaller chunks follow, and the
/// whole wreck recedes (one depth scale) and sinks into the cloud deck as
/// one structure. Pure Dart: no `dart:ui`, deterministic per seed.

/// One rigid body of the collapse (level 0 the hull, 1 a section, 2 a
/// chunk): pivot [cx], [cy] (hull-local), parent body, release time,
/// impulse and gravity.
class CollapseBody {
  CollapseBody({
    required this.level,
    required this.parent,
    required this.cx,
    required this.cy,
    required this.release,
    this.ix = 0,
    this.iy = 0,
    this.iw = 0,
    this.alpha = 0,
    this.gravity = 0,
    this.section = 0,
  });
  final int level, parent, section;
  final double cx, cy, release, ix, iy, iw, alpha, gravity;

  /// The state at release (world units before the depth scale): pivot
  /// position, velocity, angle, angular velocity.
  double x0 = 0, y0 = 0, vx0 = 0, vy0 = 0, a0 = 0, w0 = 0;
}

/// A rigid transform of hull-local points: world = R(a)·(p − c) + (x, y).
class CollapsePose {
  const CollapsePose(this.x, this.y, this.a, this.cx, this.cy);
  final double x, y, a, cx, cy;

  (double, double) apply(double px, double py) {
    final c = math.cos(a), s = math.sin(a);
    final rx = px - cx, ry = py - cy;
    return (x + c * rx - s * ry, y + s * rx + c * ry);
  }
}

/// A blast riding a body: [t] seconds into the collapse at hull-local
/// ([x], [y]) of [body], [size] arena units.
class CollapseBlast {
  const CollapseBlast(this.t, this.body, this.x, this.y, this.size);
  final double t, x, y, size;
  final int body;
}

/// A smoke puff in world space (after the depth scale).
class CollapsePuff {
  CollapsePuff(this.x, this.y, this.r0, this.life);
  double x, y, age = 0;
  final double r0, life;
}

/// The timeline and the physics constants (design §3.2). Every value is
/// one constant, tuned on the review strip.
class CarrierCollapseScript {
  const CarrierCollapseScript();

  /// The whole collapse (s); the wreck is gone at its end.
  final double duration = 7.0;

  /// The hull holds together (shudder, sag, chain blasts) until here.
  final double shudder = 1.25;

  /// The sag at the wing tips and the stern's end (units, at full sag).
  final double sag = 12;

  /// Section releases: the stern, the wing on the side it lists to, then
  /// the other wing.
  final double sternAt = 1.25, firstWingAt = 1.55, secondWingAt = 2.05;

  /// Chunks release over [chunkFrom, chunkFrom + chunkSpan]; [chunkShare]
  /// of each section's chunks go (the outer ones first).
  final double chunkFrom = 2.4, chunkSpan = 2.0, chunkShare = .6;

  /// Gravity (units/s²): heavy and slow (a giant falls slowly on screen,
  /// because it is far and big; smaller pieces a little faster).
  final double gHull = 4, gSection = 6, gChunk = 10;

  /// The hull's list: angular acceleration (rad/s²) toward its travel.
  final double list = .011;

  /// Separation impulses (units/s) and spins (rad/s).
  final double sectionKick = 9,
      chunkKick = 8,
      sectionSpin = .035,
      chunkSpin = .09;

  /// The depth scale at the end (the wreck recedes toward the deck).
  final double sink = .35;

  /// The depth scale's centre (hull-local, carried by the hull): high on
  /// the hull, so the far edge (off-screen above) stays off-screen while
  /// the near hull recedes toward it.
  final double sinkX = 0, sinkY = -150;

  /// Fade-out window at the end (s).
  final double fade = 1.8;
}

/// The collapse: a clock, the bodies (once a fracture is attached), the
/// blasts and the smoke.
class CarrierCollapse {
  CarrierCollapse({
    required this.x,
    required this.y,
    required double vx,
    required this.direction,
    required this.seed,
    this.detached = const {},
    this.stage = 3,
    this.reduced = false,
    this.script = const CarrierCollapseScript(),
  }) : vx = vx.clamp(-40.0, 40.0);

  /// The carrier's centre and velocity at death, its travel direction.
  final double x, y, vx;
  final int direction, seed;

  /// The damage state at death (the wreck is composed from it).
  final Set<int> detached;
  final int stage;
  final bool reduced;
  final CarrierCollapseScript script;

  double t = 0;
  bool get done => t >= script.duration;

  /// 0 at death, 1 at the end.
  double get progress => (t / script.duration).clamp(0.0, 1.0);

  /// The common depth scale (all pieces recede together).
  double scaleAt(double t) => 1 - script.sink * _smooth(0, script.duration, t);

  /// Opacity of the whole wreck (the cloud deck takes it at the end).
  double get opacity =>
      1 - ((t - (script.duration - script.fade)) / script.fade).clamp(0.0, 1.0);

  /// The sag (0..1): the hull's back bends before it breaks.
  double get sag => _smooth(.1, script.shudder + .3, t);

  final List<CollapseBody> bodies = [];
  final List<CollapseBlast> blasts = [];
  final List<CollapsePuff> puffs = [];

  /// Smoke emitters: (body, hull-local x, y, from, until).
  final List<(int, double, double, double, double)> _emitters = [];
  double _emit = 0;

  /// The fracture the bodies were built from (null until the painter
  /// attaches one; headless runs only keep the clock).
  CarrierFracture? fracture;

  static const maxPuffs = 90, maxBlasts = 32;

  /// Root pivot: the core window.
  static const pivotX = 0.0, pivotY = 25.0;

  void step(double dt) {
    t += dt;
    if (fracture == null) return;
    for (final p in puffs) {
      p.age += dt;
      p.y -= 10 * dt; // smoke lifts against the fall
    }
    puffs.removeWhere((p) => p.age >= p.life);
    if (reduced) return;
    _emit += dt;
    const every = 1 / 6;
    while (_emit >= every) {
      _emit -= every;
      for (final (i, (b, ex, ey, from, until)) in _emitters.indexed) {
        if (t < from || t > until || puffs.length >= maxPuffs) continue;
        if ((i + (t * 6).floor()) % 2 == 1) continue; // half rate each
        final (wx, wy) = world(b, ex, ey, t);
        final j = _hash(i * 31 + (t * 60).floor());
        puffs.add(
          CollapsePuff(wx + (j - .5) * 10, wy, 5 + 4 * j, 1.6 + .6 * j),
        );
      }
    }
  }

  /// Attaches [f] and builds the hierarchy (once).
  void attach(CarrierFracture f) {
    if (fracture != null) return;
    fracture = f;
    final s = script;
    final rng = math.Random(seed);
    final dir = direction < 0 ? -1.0 : 1.0;
    final k = reduced ? .4 : 1.0;
    // Level 0: the hull (and the fore section, which keeps the deck).
    bodies.add(
      CollapseBody(
          level: 0,
          parent: -1,
          cx: pivotX,
          cy: pivotY,
          release: 0,
          alpha: reduced ? 0 : dir * s.list,
          gravity: s.gHull,
        )
        ..x0 = x + pivotX
        ..y0 = y + pivotY
        ..vx0 = vx * .35
        ..vy0 = 3,
    );
    // Level 1: the sections (1 left wing, 2 right wing, 3 stern).
    final sectionBody = <int, int>{0: 0};
    for (final sec in const [3, 1, 2]) {
      final c = f.sectionCentre(sec);
      if (c == null) continue;
      final listSide = (sec == 2) == (dir > 0);
      final at = sec == 3
          ? s.sternAt
          : (listSide ? s.firstWingAt : s.secondWingAt);
      final dx = c.$1 - pivotX, dy = c.$2 - pivotY;
      final n = math.max(1e-6, math.sqrt(dx * dx + dy * dy));
      final outward = sec == 3 ? 0.0 : (sec == 2 ? 1.0 : -1.0);
      sectionBody[sec] = bodies.length;
      bodies.add(
        CollapseBody(
          level: 1,
          parent: 0,
          section: sec,
          cx: c.$1,
          cy: c.$2,
          release: at,
          ix: dx / n * s.sectionKick * k,
          iy: dy / n * s.sectionKick * k,
          iw: (sec == 3 ? -dir * .6 : outward) * s.sectionSpin * k,
          alpha: reduced ? 0 : (sec == 3 ? 0 : outward * s.list * .5),
          gravity: s.gSection,
        ),
      );
    }
    // Level 2: chunks, the outer ones of each section first.
    final bySection = <int, List<int>>{};
    for (var i = 0; i < f.chunks; i++) {
      (bySection[f.chunkSection[i]] ??= []).add(i);
    }
    f.chunkBody = Int32List(f.chunks);
    for (final e in bySection.entries) {
      final parent = sectionBody[e.key] ?? 0;
      final pc = (bodies[parent].cx, bodies[parent].cy);
      double dist(int i) {
        final dx = f.chunkX[i] - pc.$1, dy = f.chunkY[i] - pc.$2;
        return dx * dx + dy * dy;
      }

      final list = [...e.value]..sort((a, b) => dist(b).compareTo(dist(a)));
      final go = (list.length * s.chunkShare).floor();
      for (final (rank, i) in list.indexed) {
        final keep = rank >= go || f.chunkDeck[i] == 1;
        if (keep) {
          f.chunkBody[i] = parent;
          continue;
        }
        final r = rng.nextDouble();
        final dx = f.chunkX[i] - pc.$1, dy = f.chunkY[i] - pc.$2;
        final n = math.max(1e-6, math.sqrt(dx * dx + dy * dy));
        final at = math.max(
          s.chunkFrom +
              s.chunkSpan * rank / math.max(1, go) +
              (rng.nextDouble() - .5) * .3,
          bodies[parent].release + .5,
        );
        f.chunkBody[i] = bodies.length;
        bodies.add(
          CollapseBody(
            level: 2,
            parent: parent,
            section: e.key,
            cx: f.chunkX[i],
            cy: f.chunkY[i],
            release: at,
            ix: dx / n * s.chunkKick * (.6 + .8 * r) * k,
            iy: dy / n * s.chunkKick * (.6 + .8 * r) * k,
            iw: (dx >= 0 ? 1 : -1) * s.chunkSpin * (.4 + .9 * r) * k,
            gravity: s.gChunk,
          ),
        );
      }
    }
    // Release states, parents first (bodies are in level order).
    for (final b in bodies.skip(1)) {
      final p = bodies[b.parent];
      final (px, py) = world(b.parent, b.cx, b.cy, b.release, scaled: false);
      final (vx, vy, a, w) = _motion(p, b.release);
      // The parent's velocity at this pivot: v + ω × r.
      final (ox, oy) = _pivot(p, b.release);
      final rx = px - ox, ry = py - oy;
      b
        ..x0 = px
        ..y0 = py
        ..vx0 = vx - w * ry + b.ix
        ..vy0 = vy + w * rx + b.iy
        ..a0 = a
        ..w0 = w + b.iw;
    }
    // Blasts: a chain over the shudder, then along every break.
    for (var i = 0; i < 6 && blasts.length < maxBlasts; i++) {
      final p = f.boundary.isEmpty
          ? (pivotX, pivotY - 80.0)
          : f.boundary[(i * 7919) % f.boundary.length];
      blasts.add(CollapseBlast(.1 + i * .2, 0, p.$1, p.$2, 90 + 30 * (i % 2)));
    }
    for (final (bi, b) in bodies.indexed) {
      if (b.level == 0) continue;
      final edge = f.edgeOf(b.level == 1 ? b.section : -1, b.cx, b.cy);
      final n = b.level == 1 ? 3 : 1;
      for (var j = 0; j < n && blasts.length < maxBlasts; j++) {
        blasts.add(
          CollapseBlast(
            b.release - .05 + j * .12,
            bi,
            edge.$1 + (j - 1) * 30,
            edge.$2,
            b.level == 1 ? 120 : 70,
          ),
        );
      }
      _emitters.add((bi, edge.$1, edge.$2, b.release, script.duration - 1));
    }
  }

  /// The pivot's position at [t] (before the depth scale).
  (double, double) _pivot(CollapseBody b, double t) {
    if (b.level > 0 && t < b.release) {
      return world(b.parent, b.cx, b.cy, t, scaled: false);
    }
    final u = math.max(0.0, t - b.release);
    return (b.x0 + b.vx0 * u, b.y0 + b.vy0 * u + .5 * b.gravity * u * u);
  }

  /// Velocity, angle and angular velocity of body [b] at [t].
  (double, double, double, double) _motion(CollapseBody b, double t) {
    if (b.level > 0 && t < b.release) return _motion(bodies[b.parent], t);
    final u = math.max(0.0, t - b.release);
    return (
      b.vx0,
      b.vy0 + b.gravity * u,
      b.a0 + b.w0 * u + .5 * b.alpha * u * u,
      b.w0 + b.alpha * u,
    );
  }

  /// Body [i]'s pose at [t] (before the depth scale).
  CollapsePose pose(int i, double t) {
    final b = bodies[i];
    if (b.level > 0 && t < b.release) return pose(b.parent, t);
    final (px, py) = _pivot(b, t);
    final (_, _, a, _) = _motion(b, t);
    return CollapsePose(px, py, a, b.cx, b.cy);
  }

  /// Where hull-local ([px], [py]) of body [i] is at [t]; [scaled]: after
  /// the common depth scale about the hull's pivot.
  (double, double) world(
    int i,
    double px,
    double py,
    double t, {
    bool scaled = true,
  }) {
    final (wx, wy) = pose(i, t).apply(px, py);
    if (!scaled) return (wx, wy);
    final (ox, oy) = sinkCentre(t);
    final k = scaleAt(t);
    return (ox + (wx - ox) * k, oy + (wy - oy) * k);
  }

  /// The depth scale's centre in world units at [t] (on the hull).
  (double, double) sinkCentre(double t) => bodies.isEmpty
      ? (x + script.sinkX, y + script.sinkY)
      : pose(0, t).apply(script.sinkX, script.sinkY);

  /// The sag displacement of hull-local ([px], [py]) (down-screen): the
  /// wing tips and the stern's end droop before the back breaks.
  double sagAt(double px, double py) {
    final a = sag;
    if (a <= 0 || reduced) return 0;
    final wx = (px / 360).clamp(-1.0, 1.0);
    final st = ((-py - 200) / 230).clamp(0.0, 1.0);
    return a * script.sag * (wx * wx + .8 * st * st);
  }

  static double _smooth(double a, double b, double x) {
    final u = ((x - a) / (b - a)).clamp(0.0, 1.0);
    return u * u * (3 - 2 * u);
  }

  static double _hash(int n) {
    final v = math.sin(n * 12.9898) * 43758.5453;
    return v - v.floorToDouble();
  }
}

/// A seed of the fracture: hull-local position and section (0 fore hull,
/// 1 left wing, 2 right wing, 3 stern).
typedef FractureSeed = (double, double, int);

/// The fracture of the wreck's texture: triangles (unshared vertices,
/// hull-local, jittered off the grid so the cracks are ragged) grouped
/// into chunks of a Voronoi partition with a noisy metric. From the
/// re-render on the chunk masks come with the art (spec: `carrier-render`);
/// until then the seeds are the module layers' centres (the structure).
class CarrierFracture {
  CarrierFracture._();

  /// Per triangle vertex: hull-local rest positions (x, y).
  late final Float32List rest;

  /// Per triangle: its chunk.
  late final Int32List triChunk;

  /// Per chunk: centroid, section, whether it holds the deck (never
  /// released), and (after [CarrierCollapse.attach]) its body.
  late final Float32List chunkX, chunkY;
  late final Int32List chunkSection, chunkDeck;
  Int32List chunkBody = Int32List(0);
  int get chunks => chunkX.length;
  int get triangles => triChunk.length;

  /// Points on the cracks between sections (hull-local), and per section
  /// its crack points.
  final List<(double, double)> boundary = [];
  final Map<int, List<(double, double)>> _sectionEdge = {};
  final Map<int, (double, double)> _sectionCentre = {};

  (double, double)? sectionCentre(int s) => _sectionCentre[s];

  /// The crack point of section [s] nearest ([x], [y]); for a chunk
  /// ([s] −1) the nearest crack point overall, else its own centre.
  (double, double) edgeOf(int s, double x, double y) {
    final list = s >= 0 ? (_sectionEdge[s] ?? boundary) : boundary;
    if (list.isEmpty) return (x, y);
    var best = list.first;
    var bd = double.infinity;
    for (final p in list) {
      final d = (p.$1 - x) * (p.$1 - x) + (p.$2 - y) * (p.$2 - y);
      if (d < bd) {
        bd = d;
        best = p;
      }
    }
    return s >= 0 ? best : (x + (best.$1 - x) * .5, y + (best.$2 - y) * .5);
  }

  /// The section of a seed at hull-local ([x], [y]).
  static int sectionOf(double x, double y) {
    if (x < -120) return 1;
    if (x > 120) return 2;
    return y < -200 ? 3 : 0;
  }

  static CarrierFracture build({
    required double left,
    required double top,
    required double right,
    required double bottom,
    required List<FractureSeed> seeds,
    required bool Function(double l, double t, double r, double b) keep,
    double step = 20,
    int seed = 1,
  }) {
    final f = CarrierFracture._();
    final nx = ((right - left) / step).ceil(),
        ny = ((bottom - top) / step).ceil();
    double h(int a, int b) {
      final v = math.sin((a * 127.1 + b * 311.7 + seed * 74.7)) * 43758.5453;
      return v - v.floorToDouble();
    }

    // Jittered nodes (the frame's border stays straight).
    (double, double) node(int i, int j) {
      var x = math.min(left + i * step, right);
      var y = math.min(top + j * step, bottom);
      if (i > 0 && j > 0 && i < nx && j < ny) {
        x += (h(i, j) - .5) * step * .6;
        y += (h(j + 7, i + 3) - .5) * step * .6;
      }
      return (x, y);
    }

    // Value noise (60-unit lattice) for a ragged Voronoi metric.
    double noise(double x, double y, int s) {
      final gx = x / 60, gy = y / 60;
      final i = gx.floor(), j = gy.floor();
      final u = gx - i, v = gy - j;
      double g(int a, int b) => h(a * 3 + s * 17, b * 5 - s * 13);
      final su = u * u * (3 - 2 * u), sv = v * v * (3 - 2 * v);
      return (g(i, j) * (1 - su) + g(i + 1, j) * su) * (1 - sv) +
          (g(i, j + 1) * (1 - su) + g(i + 1, j + 1) * su) * sv;
    }

    int chunkAt(double x, double y) {
      var best = 0;
      var bd = double.infinity;
      for (final (k, (sx, sy, _)) in seeds.indexed) {
        final dx = x - sx, dy = y - sy;
        final d = math.sqrt(dx * dx + dy * dy) * (1 + .45 * noise(x, y, k));
        if (d < bd) {
          bd = d;
          best = k;
        }
      }
      return best;
    }

    final pos = <double>[];
    final tc = <int>[];
    final cellChunk = <int, (int, int)>{}; // cell → (chunk a, chunk b)
    for (var j = 0; j < ny; j++) {
      for (var i = 0; i < nx; i++) {
        final l = left + i * step, t = top + j * step;
        if (!keep(l, t, l + step, t + step)) continue;
        final a = node(i, j), b = node(i + 1, j);
        final c = node(i, j + 1), d = node(i + 1, j + 1);
        final flip = h(i * 3 + 1, j * 5 + 2) > .5;
        final tris = flip ? [(a, b, d), (a, d, c)] : [(a, b, c), (b, d, c)];
        final ids = <int>[];
        for (final (p, q, r) in tris) {
          final k = chunkAt((p.$1 + q.$1 + r.$1) / 3, (p.$2 + q.$2 + r.$2) / 3);
          ids.add(k);
          pos.addAll([p.$1, p.$2, q.$1, q.$2, r.$1, r.$2]);
          tc.add(k);
        }
        cellChunk[j * nx + i] = (ids[0], ids[1]);
      }
    }
    f.rest = Float32List.fromList(pos);
    // Chunks: only seeds that own triangles, renumbered.
    final used = <int, int>{};
    for (final k in tc) {
      used.putIfAbsent(k, () => used.length);
    }
    f.triChunk = Int32List.fromList([for (final k in tc) used[k]!]);
    final n = used.length;
    final sx = Float64List(n), sy = Float64List(n), sa = Float64List(n);
    for (var t = 0; t < f.triChunk.length; t++) {
      final o = t * 6;
      final ax = pos[o], ay = pos[o + 1], bx = pos[o + 2], by = pos[o + 3];
      final cx = pos[o + 4], cy = pos[o + 5];
      final area = ((bx - ax) * (cy - ay) - (cx - ax) * (by - ay)).abs() / 2;
      final k = f.triChunk[t];
      sx[k] += area * (ax + bx + cx) / 3;
      sy[k] += area * (ay + by + cy) / 3;
      sa[k] += area;
    }
    f.chunkX = Float32List(n);
    f.chunkY = Float32List(n);
    f.chunkSection = Int32List(n);
    f.chunkDeck = Int32List(n);
    for (final e in used.entries) {
      final k = e.value;
      final s = seeds[e.key];
      f.chunkX[k] = sa[k] > 0 ? sx[k] / sa[k] : s.$1;
      f.chunkY[k] = sa[k] > 0 ? sy[k] / sa[k] : s.$2;
      f.chunkSection[k] = s.$3;
    }
    // The deck's chunk (nearest the core window) never breaks away.
    final deck = chunkAt(CarrierCollapse.pivotX, CarrierCollapse.pivotY);
    if (used[deck] case final k?) f.chunkDeck[k] = 1;
    // Section centres (area-weighted) and the cracks between sections.
    for (final s in const [1, 2, 3]) {
      var ax = 0.0, ay = 0.0, aa = 0.0;
      for (var k = 0; k < n; k++) {
        if (f.chunkSection[k] != s) continue;
        ax += f.chunkX[k] * sa[k];
        ay += f.chunkY[k] * sa[k];
        aa += sa[k];
      }
      if (aa > 0) f._sectionCentre[s] = (ax / aa, ay / aa);
    }
    int secOf(int seedChunk) => seeds[seedChunk].$3;
    for (final e in cellChunk.entries) {
      final i = e.key % nx, j = e.key ~/ nx;
      final mine = secOf(e.value.$1);
      final others = [
        secOf(e.value.$2),
        if (cellChunk[e.key + 1] case final r?) secOf(r.$1),
        if (cellChunk[e.key + nx] case final d?) secOf(d.$1),
      ];
      for (final o in others) {
        if (o == mine) continue;
        final p = (left + (i + .5) * step, top + (j + .5) * step);
        f.boundary.add(p);
        // A crack belongs to the section that is not the fore hull.
        final s = mine == 0 ? o : mine;
        (f._sectionEdge[s] ??= []).add(p);
        break;
      }
    }
    return f;
  }
}
