import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'dart:ui' show Color, Paint, PaintingStyle, Path, StrokeCap;

import 'carrier_script.dart';

/// carrier-v3 §3: the hull-conforming force field.
///
/// **The distance map.** Until the re-render bakes a per-hull distance and
/// region texture, it is derived once at load time from the hull's S0 alpha
/// ([CarrierFieldMap.fromAlpha]): an exact Euclidean distance transform
/// (Felzenszwalb–Huttenlocher, separable) at 0.5 px per arena unit over the
/// envelope, signed (outside positive).
///
/// **The membrane.** Rather than a full-rectangle fragment shader over a
/// hull larger than the screen (the fill-rate risk of design §12), the
/// field is drawn as a vector membrane: the map's iso-contours at the
/// offsets the field can take (marching squares, every 2 units from 2 to
/// 24), split by region, bent with the hull and stroked with
/// `drawRawPoints` (one call per region and pass). The shader
/// (`shaders/carrier_field.frag`, task 4.1) is deferred: this path renders
/// identically in tests and on every backend, and its cost is a few
/// thousand line segments, not a full-screen fill.
class CarrierFieldMap {
  CarrierFieldMap._(this.left, this.top, this.width, this.height, this.ppu,
      this.distance);

  /// Hull-local origin of pixel (0, 0) (units), size (px), px per unit.
  final double left, top;
  final int width, height;
  final double ppu;

  /// Signed distance (units) per pixel: positive outside the hull.
  final Float32List distance;

  /// Iso-contour segments per level (units of offset, 2 … 24), as pairs
  /// of points (x0, y0, x1, y1, …) in hull-local units, per region.
  final Map<int, Map<CarrierRegion, Float32List>> contours = {};

  static const levels = [2, 4, 6, 8, 10, 12, 14, 16, 18, 20, 22, 24];

  /// The signed distance at hull-local ([x], [y]) (bilinear; far outside
  /// the map: the map's edge value).
  double at(double x, double y) {
    final fx = ((x - left) * ppu - .5).clamp(0.0, width - 1.001);
    final fy = ((y - top) * ppu - .5).clamp(0.0, height - 1.001);
    final i = fx.floor(), j = fy.floor();
    final u = fx - i, v = fy - j;
    double d(int a, int b) => distance[b * width + a];
    return (d(i, j) * (1 - u) + d(i + 1, j) * u) * (1 - v) +
        (d(i, j + 1) * (1 - u) + d(i + 1, j + 1) * u) * v;
  }

  /// Builds the map from a hull alpha mask: [alpha] is [w] × [h] bytes
  /// (rgba8888, alpha at +3 per pixel) rendered at [ppu] px per unit with
  /// hull-local origin ([left], [top]).
  static CarrierFieldMap fromAlpha(
    Uint8List rgba,
    int w,
    int h, {
    required double left,
    required double top,
    double ppu = .5,
  }) {
    final n = w * h;
    final inside = Uint8List(n);
    for (var i = 0; i < n; i++) {
      inside[i] = rgba[i * 4 + 3] >= 96 ? 1 : 0;
    }
    final out = _edt(inside, w, h, 1); // distance to the hull (outside)
    final inn = _edt(inside, w, h, 0); // distance to the outside (inside)
    final d = Float32List(n);
    for (var i = 0; i < n; i++) {
      // px → units; half a pixel splits the edge.
      d[i] = (inside[i] == 1 ? -(math.sqrt(inn[i]) - .5) : math.sqrt(out[i]) - .5) /
          ppu;
    }
    final map = CarrierFieldMap._(left, top, w, h, ppu, d);
    for (final l in levels) {
      map.contours[l] = map._contour(l.toDouble());
    }
    return map;
  }

  /// Squared EDT to the nearest pixel whose mask equals [target].
  static Float64List _edt(Uint8List mask, int w, int h, int target) {
    const inf = 1e20;
    final g = Float64List(w * h);
    for (var i = 0; i < w * h; i++) {
      g[i] = mask[i] == target ? 0 : inf;
    }
    final m = math.max(w, h);
    final f = Float64List(m), d = Float64List(m), z = Float64List(m + 1);
    final v = Int32List(m);
    void pass(int len) {
      var k = 0;
      v[0] = 0;
      z[0] = -inf;
      z[1] = inf;
      for (var q = 1; q < len; q++) {
        var s = ((f[q] + q * q) - (f[v[k]] + v[k] * v[k])) / (2 * q - 2 * v[k]);
        while (s <= z[k]) {
          k--;
          s = ((f[q] + q * q) - (f[v[k]] + v[k] * v[k])) / (2 * q - 2 * v[k]);
        }
        k++;
        v[k] = q;
        z[k] = s;
        z[k + 1] = inf;
      }
      k = 0;
      for (var q = 0; q < len; q++) {
        while (z[k + 1] < q) {
          k++;
        }
        final dq = q - v[k];
        d[q] = dq * dq + f[v[k]];
      }
    }

    for (var x = 0; x < w; x++) {
      for (var y = 0; y < h; y++) {
        f[y] = g[y * w + x];
      }
      pass(h);
      for (var y = 0; y < h; y++) {
        g[y * w + x] = d[y];
      }
    }
    for (var y = 0; y < h; y++) {
      for (var x = 0; x < w; x++) {
        f[x] = g[y * w + x];
      }
      pass(w);
      for (var x = 0; x < w; x++) {
        g[y * w + x] = d[x];
      }
    }
    return g;
  }

  /// Marching squares at iso [level] (units), per region.
  Map<CarrierRegion, Float32List> _contour(double level) {
    final seg = <CarrierRegion, List<double>>{};
    double val(int i, int j) => distance[j * width + i] - level;
    // Pixel centre → hull-local units.
    double ux(double i) => left + (i + .5) / ppu;
    double uy(double j) => top + (j + .5) / ppu;
    void add(double x0, double y0, double x1, double y1) {
      final r = CarrierRegion.at((x0 + x1) / 2, (y0 + y1) / 2);
      (seg[r] ??= []).addAll([x0, y0, x1, y1]);
    }

    for (var j = 0; j + 1 < height; j++) {
      for (var i = 0; i + 1 < width; i++) {
        final a = val(i, j), b = val(i + 1, j);
        final c = val(i + 1, j + 1), d = val(i, j + 1);
        final k = (a > 0 ? 8 : 0) | (b > 0 ? 4 : 0) | (c > 0 ? 2 : 0) |
            (d > 0 ? 1 : 0);
        if (k == 0 || k == 15) continue;
        // Edge crossings (top, right, bottom, left).
        double t(double p, double q) => p / (p - q);
        final top = (ux(i + t(a, b)), uy(j.toDouble()));
        final right = (ux(i + 1.0), uy(j + t(b, c)));
        final bottom = (ux(i + t(d, c)), uy(j + 1.0));
        final lft = (ux(i.toDouble()), uy(j + t(a, d)));
        void s((double, double) p, (double, double) q) =>
            add(p.$1, p.$2, q.$1, q.$2);
        switch (k) {
          case 1 || 14:
            s(lft, bottom);
          case 2 || 13:
            s(bottom, right);
          case 3 || 12:
            s(lft, right);
          case 4 || 11:
            s(top, right);
          case 5:
            s(lft, top);
            s(bottom, right);
          case 6 || 9:
            s(top, bottom);
          case 7 || 8:
            s(lft, top);
          case 10:
            s(top, right);
            s(lft, bottom);
        }
      }
    }
    return {
      for (final e in seg.entries) e.key: Float32List.fromList(e.value),
    };
  }

  /// Segment count at [level] (tests, profiling).
  int segments(int level) => (contours[level] ?? const {}).values.fold(
    0,
    (n, l) => n + l.length ~/ 4,
  );
}

/// One field hit, for the ripple and the hex flash (hull-local).
class FieldImpact {
  FieldImpact(this.x, this.y);
  final double x, y;
  double age = 0;
}

/// The field's presentation state and drawing (design §3.1–§3.2).
class CarrierFieldPainter {
  CarrierFieldMap? map;

  /// The hull key the map was built for.
  String? mapKey;

  final List<FieldImpact> impacts = [];

  /// Region flash ages (s) after going dark, and their falling shards.
  final Map<CarrierRegion, double> flashes = {};
  final List<(double, double, double, double, double)> _shards = [];
  Set<CarrierRegion> _lit = {...CarrierRegion.values};
  int _cells = 12;
  double _clock = 0;

  /// The membrane's collapse at shield down (0..1 over 0.4 s; −1: none).
  double down = -1;

  static const rim = Color(0xFF62F0FF), teal = Color(0xFF3FC4DC);
  static const deepTeal = Color(0xFF1C6F86), fill = Color(0xFFBDA7FF);

  void reset() {
    impacts.clear();
    flashes.clear();
    _shards.clear();
    _lit = {...CarrierRegion.values};
    _cells = 12;
    down = -1;
  }

  /// Steps the field: [cells] lit shield cells (0–12), [style] the
  /// script's region order; [hit] a new impact (hull-local) or null.
  void update(
    double dt, {
    required int cells,
    required CarrierFieldStyle style,
    (double, double)? hit,
    bool reduced = false,
  }) {
    _clock += dt;
    if (cells < _cells) {
      final now = style.litRegions(cells);
      for (final r in _lit.difference(now)) {
        flashes[r] = 0;
        // Shards from the region's emitter crystal.
        final c = _centreOf(r);
        for (var i = 0; i < 5; i++) {
          final a = (i * 2.4 + r.index) % (2 * math.pi);
          _shards.add((c.$1, c.$2, 40 * math.cos(a), 30 + 20 * math.sin(a), 0));
        }
      }
      _lit = now;
      if (cells == 0) down = 0;
    } else if (cells > _cells) {
      _lit = style.litRegions(cells);
      down = -1;
    }
    _cells = cells;
    if (hit != null) {
      impacts.add(FieldImpact(hit.$1, hit.$2));
      if (impacts.length > 4) impacts.removeAt(0);
    }
    for (final i in impacts) {
      i.age += dt;
    }
    impacts.removeWhere((i) => i.age > (reduced ? .2 : .8));
    flashes.updateAll((_, a) => a + dt);
    flashes.removeWhere((_, a) => a > .35);
    for (var i = 0; i < _shards.length; i++) {
      final (x, y, vx, vy, age) = _shards[i];
      _shards[i] = (x + vx * dt, y + vy * dt, vx, vy + 120 * dt, age + dt);
    }
    _shards.removeWhere((s) => s.$5 > .9);
    if (down >= 0) down = math.min(1, down + dt / .4);
  }

  static (double, double) _centreOf(CarrierRegion r) {
    final side = r.name.endsWith('L') ? -1.0 : 1.0;
    return switch (r) {
      CarrierRegion.wingTipL || CarrierRegion.wingTipR => (side * 300, -260),
      CarrierRegion.wingRootL || CarrierRegion.wingRootR => (side * 270, -100),
      CarrierRegion.aftFlankL || CarrierRegion.aftFlankR => (side * 190, -150),
      CarrierRegion.prongOuterL ||
      CarrierRegion.prongOuterR => (side * 200, 30),
      CarrierRegion.prongInnerL ||
      CarrierRegion.prongInnerR => (side * 130, 50),
      CarrierRegion.citadel => (0, -200),
      CarrierRegion.prow => (0, 60),
    };
  }

  final Map<CarrierRegion, Float32List> _scratch = {};
  final Paint _glow = Paint()
    ..strokeCap = StrokeCap.round
    ..isAntiAlias = true;
  final Paint _core = Paint()
    ..strokeCap = StrokeCap.round
    ..isAntiAlias = true;

  /// Segments drawn last frame (profiling).
  int drawnSegments = 0;

  /// Draws the membrane around the hull at [center] (arena units) with
  /// shield fraction [s]; [lipY] is the gameplay surface's hull-local y at
  /// hull-local x (the field's front lip, `Carrier.forceFieldSurfaceY`
  /// minus the centre) within ±[lipHalf]; [bend] maps a hull-local point to
  /// where the hull draws it. [lip]: only the front lip (drawn over the
  /// prow, where shots stop); otherwise everything else (drawn after the
  /// hull's back pass, before the creatures).
  void paint(
    ui.Canvas c,
    ui.Offset center, {
    required double s,
    required double Function(double x) lipY,
    double lipHalf = 110,
    required ui.Offset Function(double x, double y) bend,
    bool lip = false,
    bool reduced = false,
    double opacity = 1,
    double scan = 0,
  }) {
    final m = map;
    if (!lip) drawnSegments = 0;
    if (m == null) return;
    var off = 6 + 18 * s.clamp(0.0, 1.0);
    var alpha = opacity;
    if (down >= 0) {
      // Shield down: the membrane snaps inward over 0.4 s and is gone.
      off *= 1 - down;
      alpha *= 1 - down;
      if (alpha <= .01) {
        if (!lip) _paintShards(c, center, bend);
        return;
      }
    }
    final level = (off / 2).round().clamp(1, 12) * 2;
    final segs = m.contours[level];
    if (segs == null) return;
    final critical = s <= .25;
    final flick = critical
        ? .55 + .45 * (math.sin(_clock * 24) * .5 + .5)
        : 1.0;
    final color = s > .6 ? rim : (s > .25 ? teal : deepTeal);
    final scanY = 100 - ((_clock / 4) % 1) * 560; // prow → stern, 4 s
    c.save();
    c.translate(center.dx, center.dy);
    for (final e in segs.entries) {
      final region = e.key;
      final lit = _lit.contains(region);
      final flash = flashes[region];
      if (!lit && flash == null) continue;
      final src = e.value;
      final dst = _scratch[region] =
          (_scratch[region]?.length == src.length)
          ? _scratch[region]!
          : Float32List(src.length);
      var n = 0, scanN = 0;
      final scanAt = _scanBuf.length >= src.length
          ? _scanBuf
          : (_scanBuf = Float32List(src.length));
      for (var i = 0; i < src.length; i += 4) {
        // The front lip: inside the gameplay band the rim is drawn exactly
        // on the intercept surface (unbent: shots stop there), blended
        // over 20 units at its ends.
        final w0 = _lipWeight(src[i], src[i + 1], lipHalf);
        final w1 = _lipWeight(src[i + 2], src[i + 3], lipHalf);
        if ((w0 > 0 || w1 > 0) != lip) continue;
        final start = n;
        for (var k = 0; k < 4; k += 2) {
          final x = src[i + k];
          var y = src[i + k + 1];
          final w = k == 0 ? w0 : w1;
          if (w > 0) {
            final ax = x.abs();
            final ly = lipY(ax <= lipHalf ? x : x.sign * lipHalf);
            y += (ly - y) * w;
          }
          final p = bend(x, y);
          dst[n++] = p.dx + (x - p.dx) * w;
          dst[n++] = p.dy + (y - p.dy) * w;
        }
        if (!lip && scan > 0 && (src[i + 1] - scanY).abs() < 26) {
          for (var k = 0; k < 4; k++) {
            scanAt[scanN++] = dst[start + k];
          }
        }
      }
      if (n == 0) continue;
      final pts = Float32List.sublistView(dst, 0, n);
      drawnSegments += n ~/ 4;
      final a = alpha * (lit ? flick : 0);
      if (flash != null) {
        final f = 1 - flash / .35;
        _core
          ..color = const Color(0xFFFFFFFF).withValues(alpha: alpha * f)
          ..strokeWidth = 2.4;
        c.drawRawPoints(ui.PointMode.lines, pts, _core);
        if (!lit) continue;
      }
      _glow
        ..color = color.withValues(alpha: .16 * a)
        ..strokeWidth = 6;
      c.drawRawPoints(ui.PointMode.lines, pts, _glow);
      _core
        ..color = color.withValues(alpha: .85 * a)
        ..strokeWidth = 1.6;
      c.drawRawPoints(ui.PointMode.lines, pts, _core);
      if (!reduced && scanN > 0) {
        // The slow scan: a band sweeping from the prow to the stern.
        _core
          ..color = fill.withValues(alpha: .15 * a * scan)
          ..strokeWidth = 4;
        c.drawRawPoints(
          ui.PointMode.lines,
          Float32List.sublistView(scanAt, 0, scanN),
          _core,
        );
      }
    }
    if (lip) _paintImpacts(c, bend, alpha, reduced);
    c.restore();
    if (!lip) _paintShards(c, center, bend);
  }

  Float32List _scanBuf = Float32List(0);

  /// The lip blends into the contour over this many units past the band.
  static const blend = 70.0;

  static double _lipWeight(double x, double y, double half) {
    if (y <= -12) return 0;
    final ax = x.abs();
    if (ax >= half + blend) return 0;
    if (ax <= half) return 1.0;
    final u = (half + blend - ax) / blend;
    return u * u * (3 - 2 * u);
  }

  /// Hits: a ripple and a ring of hex cells lighting outward (design §3.1);
  /// reduced motion: one flash, no ripple.
  void _paintImpacts(
    ui.Canvas c,
    ui.Offset Function(double, double) bend,
    double alpha,
    bool reduced,
  ) {
    final p = Paint()
      ..style = PaintingStyle.stroke
      ..isAntiAlias = true;
    for (final i in impacts) {
      final at = bend(i.x, i.y);
      if (reduced) {
        p
          ..color = rim.withValues(alpha: alpha * (1 - i.age / .2))
          ..strokeWidth = 2;
        c.drawCircle(at, 6, p);
        continue;
      }
      final r = 6 + i.age * 160;
      final f = (1 - i.age / .8).clamp(0.0, 1.0);
      p
        ..color = rim.withValues(alpha: .5 * f * alpha)
        ..strokeWidth = 1.4;
      c.drawOval(
        ui.Rect.fromCenter(center: at, width: r * 2, height: r * .9),
        p,
      );
      // The lattice: hex cells near the ring, flattened onto the field.
      const cell = 9.0;
      p
        ..color = rim.withValues(alpha: .35 * f * alpha)
        ..strokeWidth = 1;
      for (var q = -4; q <= 4; q++) {
        for (var k = -2; k <= 2; k++) {
          final hx = q * cell * 1.5;
          final hy = (k + (q.isOdd ? .5 : 0)) * cell * math.sqrt(3) * .45;
          final d = math.sqrt(hx * hx + hy * hy * 4);
          if ((d - r).abs() > 14 || d > 70) continue;
          final hc = at + ui.Offset(hx, hy);
          final path = Path();
          for (var v = 0; v < 6; v++) {
            final a = v * math.pi / 3;
            final pt = hc +
                ui.Offset(math.cos(a) * cell * .5, math.sin(a) * cell * .22);
            v == 0 ? path.moveTo(pt.dx, pt.dy) : path.lineTo(pt.dx, pt.dy);
          }
          path.close();
          c.drawPath(path, p);
        }
      }
    }
  }

  void _paintShards(
    ui.Canvas c,
    ui.Offset center,
    ui.Offset Function(double, double) bend,
  ) {
    if (_shards.isEmpty) return;
    final p = Paint()..color = rim;
    for (final (x, y, _, _, age) in _shards) {
      final at = center + bend(x, y);
      p.color = rim.withValues(alpha: (1 - age / .9).clamp(0.0, 1.0));
      c.drawRect(ui.Rect.fromCenter(center: at, width: 3, height: 2), p);
    }
  }
}

