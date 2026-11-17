import 'dart:math' as math;

/// carrier-hatches Part B: component break-up. Pure Dart (no `dart:ui`):
/// the release schedule and the closed-form bodies; the painters draw them.
///
/// Every piece of art removed between two damage states leaves as
/// components released one by one (design §B2–§B5): it rides the hull
/// until its release, tears at its root (m, l), then flies on the
/// carrier-render-engine closed form, `v + ω × r` at release, spinning,
/// sinking toward the cloud deck and fragmenting.

enum BreakupSize { s, m, l }

/// One component of a transition: its pivot (hull-local root), axis (unit,
/// root → tip), size class and length.
class BreakupComponent {
  const BreakupComponent({
    required this.id,
    required this.px,
    required this.py,
    required this.ax,
    required this.ay,
    required this.length,
  });
  final int id;
  final double px, py, ax, ay, length;
  BreakupSize get size => length <= 20
      ? BreakupSize.s
      : (length <= 60 ? BreakupSize.m : BreakupSize.l);
}

/// The release rule (design §B4): at most `max(2, ⌈25 %⌉)` of a
/// transition's components in any 0.25 s, gaps of 0.05–0.2 s, never in
/// under [minSeconds]. [order] lists component indices, first to go
/// first. Returns each component's release offset (s), by index.
List<double> breakupSchedule(
  List<int> order, {
  required int seed,
  double minSeconds = 1.2,
}) {
  final n = order.length;
  final out = List<double>.filled(n, 0);
  if (n == 0) return out;
  final rng = math.Random(seed);
  final perWindow = math.max(2, (n * .25).ceil());
  // The gap that spreads n releases over at least minSeconds, within the
  // 0.05–0.2 s band and the window rule.
  final spread = n <= 1 ? 0.0 : minSeconds / (n - 1);
  final base = spread.clamp(.25 / perWindow + 1e-3, .2);
  var t = 0.0;
  for (final (k, i) in order.indexed) {
    out[i] = t;
    if (k + 1 < n) t += (base * (.8 + .4 * rng.nextDouble())).clamp(.05, .2);
  }
  // Enforce the window rule exactly (it may stretch the tail).
  final times = [for (final i in order) out[i]];
  for (var k = perWindow; k < n; k++) {
    final floor = times[k - perWindow] + .25 + 1e-6;
    if (times[k] < floor) times[k] = floor;
    if (k > 0 && times[k] < times[k - 1]) times[k] = times[k - 1];
  }
  // Never in under minSeconds: stretch the last if needed.
  if (n > 1 && times.last < minSeconds) {
    final k = minSeconds / math.max(1e-6, times.last);
    for (var j = 0; j < n; j++) {
      times[j] *= k;
    }
  }
  for (final (k, i) in order.indexed) {
    out[i] = times[k];
  }
  return out;
}

/// Whether [times] obeys the window rule for [n] components.
bool breakupRateOk(List<double> times) {
  final n = times.length;
  if (n == 0) return true;
  final perWindow = math.max(2, (n * .25).ceil());
  final s = [...times]..sort();
  for (var k = perWindow; k < n; k++) {
    if (s[k] - s[k - perWindow] < .25 - 1e-9) return false;
  }
  return true;
}

/// A free component (or fragment) in world units, on a closed form from
/// its release (design §B5).
class BreakupBody {
  BreakupBody({
    required this.x0,
    required this.y0,
    required this.vx0,
    required this.vy0,
    required this.a0,
    required this.w0,
    required this.gravity,
    required this.life,
    required this.size,
    required this.t0,
    this.tear = 0,
    this.tearSeconds = 0,
    this.split = -1,
    this.component = -1,
    this.fragment = 0,
    this.ox = 0,
    this.oy = 0,
  });

  /// Release pose and velocity (world), angle and spin.
  final double x0, y0, vx0, vy0, a0, w0, gravity, life;
  final BreakupSize size;

  /// Release time (s, on the owner's clock).
  final double t0;

  /// The root tear: an angle (rad) swung about the pivot over
  /// [tearSeconds] before free flight (m, l).
  final double tear, tearSeconds;

  /// When it splits into fragments (s after the tear), negative never.
  final double split;

  /// The textured component it draws (−1: a procedural splinter), and
  /// which fragment of it (0 whole, 1… a part).
  final int component, fragment;

  /// The drawn piece's offset from the pivot (fragments' own centres).
  final double ox, oy;
  bool done(double t) => t - t0 >= life;

  /// Pose at time [t]: position, angle, scale and opacity.
  (double x, double y, double a, double scale, double alpha) pose(double t) {
    final u = math.max(0.0, t - t0);
    if (u < tearSeconds) {
      final k = u / tearSeconds;
      final e = k * k * (3 - 2 * k);
      return (x0, y0, a0 + tear * e, 1, 1);
    }
    final v = u - tearSeconds;
    final x = x0 + vx0 * v;
    final y = y0 + vy0 * v + .5 * gravity * v * v;
    final a = a0 + tear + w0 * v;
    final p = (u / life).clamp(0.0, 1.0);
    final sm = p * p * (3 - 2 * p);
    final scale = 1 - .45 * sm;
    final alpha = 1 - ((p - .65) / .35).clamp(0.0, 1.0);
    return (x, y, a, scale, alpha);
  }

  /// Velocity at [t] (free flight).
  (double vx, double vy) velocity(double t) {
    final v = math.max(0.0, t - t0 - tearSeconds);
    return (vx0, vy0 + gravity * v);
  }
}

/// The size-class constants (design §B5; CH-8).
class BreakupPhysics {
  const BreakupPhysics._();
  static (double lo, double hi) kick(BreakupSize s) => switch (s) {
    BreakupSize.s => (22, 30),
    BreakupSize.m => (16, 24),
    BreakupSize.l => (10, 16),
  };
  static (double lo, double hi) spin(BreakupSize s) => switch (s) {
    BreakupSize.s => (1.2, 3.0),
    BreakupSize.m => (.6, 1.6),
    BreakupSize.l => (.2, .6),
  };
  static double gravity(BreakupSize s) => switch (s) {
    BreakupSize.s => 60,
    BreakupSize.m => 45,
    BreakupSize.l => 30,
  };

  /// Releases [c] at time [t] from a hull at world ([hx], [hy]) moving at
  /// ([hvx], [hvy]) with spin [hw] (rad/s), the pivot at world
  /// ([wx], [wy]). [reduced]: no tear, spin or fragments; kicks at 40 %.
  static BreakupBody release(
    BreakupComponent c, {
    required double t,
    required double wx,
    required double wy,
    required double hx,
    required double hy,
    double hvx = 0,
    double hvy = 0,
    double hw = 0,
    required math.Random rng,
    bool reduced = false,
    int fragment = 0,
    double ox = 0,
    double oy = 0,
  }) {
    final s = c.size;
    final (klo, khi) = kick(s);
    final k = (klo + (khi - klo) * rng.nextDouble()) * (reduced ? .4 : 1);
    final (slo, shi) = spin(s);
    // Turning away from the centre line (x = 0 hull-local).
    final away = c.px >= 0 ? 1.0 : -1.0;
    final w = reduced ? 0.0 : away * (slo + (shi - slo) * rng.nextDouble());
    // v + ω × r: the hull's velocity at the pivot.
    final rx = wx - hx, ry = wy - hy;
    final vx = hvx - hw * ry + k * c.ax + (rng.nextDouble() - .5) * 8;
    final vy = hvy + hw * rx + k * c.ay;
    final tear = reduced || s == BreakupSize.s
        ? 0.0
        : away * (8 + 12 * rng.nextDouble()) * math.pi / 180;
    final tearSeconds = tear == 0 ? 0.0 : .15 + .2 * rng.nextDouble();
    return BreakupBody(
      x0: wx,
      y0: wy,
      vx0: vx,
      vy0: vy,
      a0: 0,
      w0: w,
      gravity: gravity(s),
      life: 2.4 + 1.2 * rng.nextDouble(),
      size: s,
      t0: t,
      tear: tear,
      tearSeconds: tearSeconds,
      split: reduced || s == BreakupSize.s ? -1 : .25 + .45 * rng.nextDouble(),
      component: c.id,
      fragment: fragment,
      ox: ox,
      oy: oy,
    );
  }

  /// The fragments of [b] at its split: 2 (m) or 3 (l), each inheriting
  /// `v + ω × r` from its parent plus ±6 units/s of separation.
  static List<BreakupBody> fragments(
    BreakupBody b,
    BreakupComponent c, {
    required math.Random rng,
  }) {
    final n = b.size == BreakupSize.l ? 3 : 2;
    final t = b.t0 + b.tearSeconds + b.split;
    final (x, y, a, _, _) = b.pose(t);
    final (vx, vy) = b.velocity(t);
    final w = b.w0;
    final out = <BreakupBody>[];
    for (var i = 0; i < n; i++) {
      // Fragment centres along the axis, from root to tip.
      final f = (i + .5) / n - .5;
      final d = f * c.length;
      final rx = math.cos(a) * c.ax * d - math.sin(a) * c.ay * d;
      final ry = math.sin(a) * c.ax * d + math.cos(a) * c.ay * d;
      final sep = 6 * (rng.nextDouble() * 2 - 1);
      out.add(
        BreakupBody(
          x0: x + rx,
          y0: y + ry,
          vx0: vx - w * ry + sep * c.ax + (rng.nextDouble() - .5) * 6,
          vy0: vy + w * rx + sep * c.ay,
          a0: a,
          w0: w * (1.2 + .6 * rng.nextDouble()),
          gravity: b.gravity * 1.15,
          life: math.max(.6, b.life - (t - b.t0)),
          size: BreakupSize.s,
          t0: t,
          component: c.id,
          fragment: i + 1,
          ox: d * c.ax,
          oy: d * c.ay,
        ),
      );
    }
    return out;
  }
}

/// A component cut from a layer's removed texels (design §B6), on a grid
/// of [cell] texels: its cells (indices into the grid), and its fragment
/// split (the cells' fragment index, 0-based, for 2 or 3 fragments).
class BreakupPiece {
  BreakupPiece(
    this.component,
    this.cells,
    this.fragmentOf, {
    this.cellPx = 1,
    this.gridW = 1,
  });

  /// The grid: texels per cell and its width in cells.
  final int cellPx, gridW;
  final BreakupComponent component;
  final List<int> cells;

  /// Per cell (parallel to [cells]): its fragment (0 … n − 1).
  final List<int> fragmentOf;
}

/// The removed texels of a layer as components (design §B6, the fallback
/// until the bake's `comp` pass): [removed] is a [w] × [h] mask (1 =
/// removed), [kept] the texels that stay opaque in the after state (the
/// seam), both at [ppu] texels per unit with the texel (0, 0) at hull-local
/// ([left], [top]); [flip] mirrors x about the hull's centre line. [root]
/// is the hull-local point a seamless piece is nearest to (a detached
/// module's base). Pure and deterministic.
List<BreakupPiece> extractComponents({
  required List<int> removed,
  List<int>? kept,
  required int w,
  required int h,
  required double ppu,
  required double left,
  required double top,
  bool flip = false,
  (double, double) root = (0, -150),
  double cellUnits = 4,
  double maxUnits = 96,
  int maxComponents = 48,
  int idBase = 0,
}) {
  final c = math.max(1, (cellUnits * ppu).round());
  final gw = (w / c).ceil(), gh = (h / c).ceil();
  final on = List<bool>.filled(gw * gh, false);
  final seam = List<bool>.filled(gw * gh, false);
  for (var gy = 0; gy < gh; gy++) {
    for (var gx = 0; gx < gw; gx++) {
      var n = 0, k = 0, total = 0;
      for (var y = gy * c; y < math.min(h, gy * c + c); y++) {
        for (var x = gx * c; x < math.min(w, gx * c + c); x++) {
          total++;
          if (removed[y * w + x] != 0) n++;
          if (kept != null && kept[y * w + x] != 0) k++;
        }
      }
      on[gy * gw + gx] = n * 4 >= total;
      seam[gy * gw + gx] = k > 0;
    }
  }
  final unit = c / ppu; // units per cell
  (double, double) centre(int i) {
    final x = left + ((i % gw) + .5) * unit;
    final y = top + ((i ~/ gw) + .5) * unit;
    return (flip ? -x : x, y);
  }

  // Connected regions (4-neighbour).
  final label = List<int>.filled(gw * gh, -1);
  final regions = <List<int>>[];
  for (var i = 0; i < on.length; i++) {
    if (!on[i] || label[i] >= 0) continue;
    final r = <int>[];
    final stack = [i];
    label[i] = regions.length;
    while (stack.isNotEmpty) {
      final j = stack.removeLast();
      r.add(j);
      final x = j % gw, y = j ~/ gw;
      for (final (nx, ny) in [(x - 1, y), (x + 1, y), (x, y - 1), (x, y + 1)]) {
        if (nx < 0 || ny < 0 || nx >= gw || ny >= gh) continue;
        final k = ny * gw + nx;
        if (on[k] && label[k] < 0) {
          label[k] = regions.length;
          stack.add(k);
        }
      }
    }
    regions.add(r);
  }
  // Split regions wider than maxUnits by a Voronoi of lattice seeds.
  final pieces = <List<int>>[];
  final step = math.max(1, (maxUnits * .8 / unit).round());
  for (final r in regions) {
    var minX = gw, maxX = 0, minY = gh, maxY = 0;
    for (final j in r) {
      minX = math.min(minX, j % gw);
      maxX = math.max(maxX, j % gw);
      minY = math.min(minY, j ~/ gw);
      maxY = math.max(maxY, j ~/ gw);
    }
    if ((maxX - minX + 1) * unit <= maxUnits &&
        (maxY - minY + 1) * unit <= maxUnits) {
      pieces.add(r);
      continue;
    }
    final seeds = <(int, int)>[];
    for (var y = minY + step ~/ 2; y <= maxY; y += step) {
      for (var x = minX + step ~/ 2; x <= maxX; x += step) {
        seeds.add((x, y));
      }
    }
    if (seeds.isEmpty) seeds.add(((minX + maxX) ~/ 2, (minY + maxY) ~/ 2));
    final parts = List.generate(seeds.length, (_) => <int>[]);
    for (final j in r) {
      final x = j % gw, y = j ~/ gw;
      var best = 0, bd = 1 << 30;
      for (final (s, (sx, sy)) in seeds.indexed) {
        final d = (x - sx) * (x - sx) + (y - sy) * (y - sy);
        if (d < bd) {
          bd = d;
          best = s;
        }
      }
      parts[best].add(j);
    }
    pieces.addAll(parts.where((p) => p.isNotEmpty));
  }
  // Merge the tiny (< 2 cells) and cap the count: smallest into nearest.
  (double, double) mean(List<int> p) {
    var sx = 0.0, sy = 0.0;
    for (final j in p) {
      final (x, y) = centre(j);
      sx += x;
      sy += y;
    }
    return (sx / p.length, sy / p.length);
  }

  pieces.sort((a, b) => b.length.compareTo(a.length));
  while (pieces.length > 1 &&
      (pieces.length > maxComponents || pieces.last.length < 2)) {
    final small = pieces.removeLast();
    final (mx, my) = mean(small);
    var best = 0;
    var bd = double.infinity;
    for (final (k, p) in pieces.indexed) {
      final (px, py) = mean(p);
      final d = (px - mx) * (px - mx) + (py - my) * (py - my);
      if (d < bd) {
        bd = d;
        best = k;
      }
    }
    pieces[best].addAll(small);
    pieces.sort((a, b) => b.length.compareTo(a.length));
  }
  // Pivot (seam centroid, else the cell nearest [root]), axis, length,
  // fragments along the axis.
  final out = <BreakupPiece>[];
  for (final (k, p) in pieces.indexed) {
    final seamCells = p.where((j) {
      final x = j % gw, y = j ~/ gw;
      for (final (nx, ny) in [(x - 1, y), (x + 1, y), (x, y - 1), (x, y + 1)]) {
        if (nx < 0 || ny < 0 || nx >= gw || ny >= gh) continue;
        final q = ny * gw + nx;
        if (seam[q] && !on[q]) return true;
      }
      return false;
    }).toList();
    double px, py;
    if (seamCells.isNotEmpty) {
      (px, py) = mean(seamCells);
    } else {
      var bd = double.infinity;
      px = py = 0;
      for (final j in p) {
        final (x, y) = centre(j);
        final d = (x - root.$1) * (x - root.$1) + (y - root.$2) * (y - root.$2);
        if (d < bd) {
          bd = d;
          px = x;
          py = y;
        }
      }
    }
    var fx = px, fy = py, fd = -1.0;
    for (final j in p) {
      final (x, y) = centre(j);
      final d = (x - px) * (x - px) + (y - py) * (y - py);
      if (d > fd) {
        fd = d;
        fx = x;
        fy = y;
      }
    }
    final len = math.max(unit, math.sqrt(fd));
    var ax = (fx - px) / len, ay = (fy - py) / len;
    if (fd <= 0) {
      ax = 0;
      ay = -1;
    }
    final comp = BreakupComponent(
      id: idBase + k,
      px: px,
      py: py,
      ax: ax,
      ay: ay,
      length: len,
    );
    final n = switch (comp.size) {
      BreakupSize.s => 1,
      BreakupSize.m => 2,
      BreakupSize.l => 3,
    };
    final frag = [
      for (final j in p)
        () {
          final (x, y) = centre(j);
          final t = ((x - px) * ax + (y - py) * ay) / len;
          return (t * n).floor().clamp(0, n - 1);
        }(),
    ];
    out.add(BreakupPiece(comp, p, frag, cellPx: c, gridW: gw));
  }
  return out;
}

/// The order a transition releases its components: outer first (by
/// distance from the hull's centre line, then from the tip), the side of
/// the most recent hit ([side], −1 / 0 / 1) first.
List<int> breakupOrder(List<BreakupComponent> cs, {int side = 0}) {
  final idx = [for (var i = 0; i < cs.length; i++) i];
  double key(BreakupComponent c) {
    final tipX = c.px + c.ax * c.length, tipY = c.py + c.ay * c.length;
    final sideBias = side != 0 && c.px * side > 0 ? 1000.0 : 0.0;
    return sideBias + tipX.abs() + .2 * (-tipY);
  }

  idx.sort((a, b) => key(cs[b]).compareTo(key(cs[a])));
  return idx;
}
