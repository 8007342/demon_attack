import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'carrier_script.dart';

/// carrier-v3 §2: one stored view (45°, yaw 0), bent at runtime. The bend
/// fakes a heading lean ψ, a bank φ and a pitch change θ of a few degrees
/// as an analytic displacement of a textured triangle mesh (the terrain's
/// technique), pivoted on the hangar deck so the hit windows never move.
///
/// Pure maths and buffers; the painter turns [CarrierMesh] into one
/// `drawVertices` per atlas page and pass.
class CarrierBend {
  CarrierBend({this.limits = const CarrierBendLimits()});

  CarrierBendLimits limits;

  /// The bend in radians (after the springs, before the buffet).
  double lean = 0, bank = 0, pitch = 0;
  double _leanV = 0, _bankV = 0, _pitchV = 0;

  /// The wings' lagged parameters (first-order lag, design §2.2).
  double wingLean = 0, wingBank = 0, wingPitch = 0;

  /// Buffet noise on bank and pitch (radians).
  double buffetBank = 0, buffetPitch = 0;
  double _clock = 0;

  /// Springs (critically damped): ω per parameter (design §2.3).
  static const leanOmega = 1.4, bankOmega = 1.8, pitchOmega = 1.2;

  static const deg = math.pi / 180;

  /// The view's pitch p₀ and the deck pivot Q (the core window).
  static const p0 = 45 * deg;
  static const qx = 0.0, qy = 25.0;

  /// The deck lock w(r) = smoothstep(lockInner, lockOuter, |P − Q|).
  static const lockInner = 40.0, lockOuter = 160.0;

  /// Until the re-render, the height-parallax terms are capped (§2.5).
  static const parallaxCap = 4.0;

  /// Total bend (springs + buffet) used by the mesh.
  double get psi => lean;
  double get phi => bank + buffetBank;
  double get theta => pitch + buffetPitch;

  void reset() {
    lean = bank = pitch = _leanV = _bankV = _pitchV = 0;
    wingLean = wingBank = wingPitch = 0;
    buffetBank = buffetPitch = 0;
  }

  /// One step. [vx], [ax]: the hull's horizontal velocity and acceleration
  /// normalised to its maxima (−1..1); [glide] its vertical glide velocity
  /// normalised (−1..1); [takeoff] the take-off pulse 0..1 (nose up to
  /// [CarrierBendLimits.takeoffPitch]); [buffet] the buffet's strength 0..1
  /// (climb × speed). [reduced]: no bend at all (drawn rigid).
  void update(
    double dt, {
    required double vx,
    required double ax,
    double glide = 0,
    double takeoff = 0,
    double buffet = 0,
    bool reduced = false,
  }) {
    _clock += dt;
    if (reduced) {
      reset();
      return;
    }
    final l = limits;
    final leanT = l.leanMax * deg * vx.clamp(-1.0, 1.0);
    final bankT = l.bankMax * deg * ax.clamp(-1.0, 1.0);
    final pitchT =
        takeoff > 0
            ? l.takeoffPitch * deg * takeoff.clamp(0.0, 1.0)
            : l.pitchMax * deg * glide.clamp(-1.0, 1.0);
    (lean, _leanV) = _spring(lean, _leanV, leanT, leanOmega, dt);
    (bank, _bankV) = _spring(bank, _bankV, bankT, bankOmega, dt);
    (pitch, _pitchV) = _spring(pitch, _pitchV, pitchT, pitchOmega, dt);
    lean = lean.clamp(-l.leanMax * deg, l.leanMax * deg);
    bank = bank.clamp(-l.bankMax * deg, l.bankMax * deg);
    final pm = math.max(l.pitchMax, l.takeoffPitch) * deg;
    pitch = pitch.clamp(-pm, pm);
    // Wings follow through: a first-order lag at 1.25 × amplitude.
    final k = 1 - math.exp(-dt / l.wingLag);
    wingLean += (lean * l.wingGain - wingLean) * k;
    wingBank += (bank * l.wingGain - wingBank) * k;
    wingPitch += (pitch * l.wingGain - wingPitch) * k;
    // A slow, low buffet: smooth noise at 1.5–3 Hz (two detuned sines per
    // axis), never on the hull's centre (the deck lock holds it).
    final b = l.buffet * deg * buffet.clamp(0.0, 1.0);
    final t = _clock;
    buffetBank =
        b * (.6 * math.sin(t * 2 * math.pi * 1.7) +
            .4 * math.sin(t * 2 * math.pi * 2.9 + 1.3));
    buffetPitch =
        b * (.6 * math.sin(t * 2 * math.pi * 1.5 + .7) +
            .4 * math.sin(t * 2 * math.pi * 2.6 + 2.1));
  }

  static (double, double) _spring(
    double x,
    double v,
    double target,
    double w,
    double dt,
  ) {
    // Sub-stepped semi-implicit Euler: stable at any frame time.
    final n = (dt / (1 / 120)).ceil().clamp(1, 8);
    final h = dt / n;
    for (var i = 0; i < n; i++) {
      final a = w * w * (target - x) - 2 * w * v;
      v += a * h;
      x += v * h;
    }
    return (x, v);
  }

  /// The displacement of hull-local point ([x], [y]) at height [h] for
  /// bend ([psi], [phi], [theta]) (radians), deck lock applied (design
  /// §2.2). Returns (dx, dy).
  static (double, double) displacement(
    double x,
    double y,
    double h,
    double psi,
    double phi,
    double theta, {
    double cap = parallaxCap,
  }) {
    final rx = x - qx, ry = y - qy;
    final r = math.sqrt(rx * rx + ry * ry);
    final w = _smooth(lockInner, lockOuter, r);
    if (w <= 0) return (0, 0);
    const sp = 0.7071067811865476, cp = 0.7071067811865476;
    // lean: a rotation in the hull's plane, projected, with height parallax.
    final leanPar = (-psi * h * cp / sp).clamp(-cap, cap);
    var dx = -psi * ry / sp + leanPar;
    var dy = psi * rx * sp;
    // bank: one flank drops, the other lifts; tall modules tip sideways;
    // the near side is slightly larger.
    dx += (-h * phi).clamp(-cap, cap) + x * (x * phi / 600);
    dy += -x * phi * cp;
    // pitch: a Mode-7 row scale plus height parallax.
    final s1 = math.sin(p0 + theta), c1 = math.cos(p0 + theta);
    dy += ry * (s1 / sp - 1) - (h * (c1 - cp)).clamp(-cap, cap);
    return (w * dx, w * dy);
  }

  /// Where hull-local point ([x], [y]) at height [h] is drawn under this
  /// bend (the main hull; [wing] 0..1 blends toward the lagged wings).
  ui.Offset displace(double x, double y, {double h = 0, double wing = 0}) {
    var (dx, dy) = displacement(x, y, h, psi, phi, theta);
    if (wing > 0) {
      final (wx, wy) = displacement(
        x,
        y,
        h,
        wingLean,
        wingBank + buffetBank,
        wingPitch + buffetPitch,
      );
      dx += (wx - dx) * wing;
      dy += (wy - dy) * wing;
    }
    return ui.Offset(x + dx, y + dy);
  }

  static double _smooth(double a, double b, double x) {
    final t = ((x - a) / (b - a)).clamp(0.0, 1.0);
    return t * t * (3 - 2 * t);
  }

  /// Height per module mount until the re-render (design §2.2): bow 0,
  /// ventral −20, lateral 10, dorsal 60. The carapace is the hull's
  /// reference plane (0).
  static double heightOf(String module) {
    final slot = module.split('.').first;
    return switch (slot) {
      'carapace' || 'prow' || 'barrier' || 'bow' => 0,
      'tendril' => -20,
      'wing' || 'maw' => 10,
      _ => 60, // spines, emitter, blister, sac, crown
    };
  }

  /// Whether a module lags the hull (wings, arms and sails).
  static bool lags(String module) {
    final slot = module.split('.').first;
    return slot == 'wing' || slot == 'emitter' || slot == 'tendril';
  }
}

/// One textured layer of the mesh: its sprite rect in hull-local units
/// and in page pixels, its height, and whether it lags (wings).
class CarrierMeshLayer {
  const CarrierMeshLayer({
    required this.page,
    required this.left,
    required this.top,
    required this.right,
    required this.bottom,
    required this.u0,
    required this.v0,
    required this.u1,
    required this.v1,
    this.flip = false,
    this.height = 0,
    this.lag = false,
  });
  final int page;

  /// Destination rect (hull-local units, before any flip).
  final double left, top, right, bottom;

  /// Source rect (page pixels).
  final double u0, v0, u1, v1;
  final bool flip;
  final double height;
  final bool lag;
}

/// The bend mesh of one pass (back or front): a grid of [step]-unit cells
/// over each layer, aligned to one lattice so neighbouring layers bend
/// alike; per page, typed buffers allocated once ([rebuild] rewrites only
/// the positions). No vertex colours (Impeller's fast path).
class CarrierMesh {
  CarrierMesh(this.layers, {this.step = 20}) {
    _build();
  }

  final List<CarrierMeshLayer> layers;
  final double step;

  /// Per page: rest positions (x, y), heights, wing weights, texture
  /// coordinates, indices.
  final Map<int, CarrierPageMesh> pages = {};

  int get vertexCount =>
      pages.values.fold(0, (n, p) => n + p.rest.length ~/ 2);
  int get triangleCount =>
      pages.values.fold(0, (n, p) => n + p.indices.length ~/ 3);

  static List<double> _cuts(double a, double b, double step) {
    final out = <double>[a];
    var k = (a / step).floor() + 1;
    while (k * step < b - 1e-6) {
      out.add(k * step);
      k++;
    }
    out.add(b);
    return out;
  }

  void _build() {
    final rest = <int, List<double>>{};
    final heights = <int, List<double>>{};
    final wings = <int, List<double>>{};
    final tex = <int, List<double>>{};
    final idx = <int, List<int>>{};
    for (final l in layers) {
      final xs = _cuts(l.left, l.right, step);
      final ys = _cuts(l.top, l.bottom, step);
      final r = rest.putIfAbsent(l.page, () => []);
      final hs = heights.putIfAbsent(l.page, () => []);
      final ws = wings.putIfAbsent(l.page, () => []);
      final t = tex.putIfAbsent(l.page, () => []);
      final ix = idx.putIfAbsent(l.page, () => []);
      final base = r.length ~/ 2;
      final w = l.right - l.left, h = l.bottom - l.top;
      // The wing weight ramps from the module's root (nearest the centre
      // line) to its tip, so the root never separates from the carapace.
      final inner = math.min(l.left.abs(), l.right.abs());
      final outer = math.max(l.left.abs(), l.right.abs());
      final straddles = l.left < 0 && l.right > 0;
      for (final y in ys) {
        for (final x in xs) {
          final fx = (x - l.left) / w, fy = (y - l.top) / h;
          r
            ..add(l.flip ? -x : x)
            ..add(y);
          hs.add(l.height);
          var wt = 0.0;
          if (l.lag && !straddles && outer > inner) {
            final s = ((x.abs() - inner) / (outer - inner)).clamp(0.0, 1.0);
            wt = s * s * (3 - 2 * s);
          }
          ws.add(wt);
          t
            ..add(l.u0 + (l.u1 - l.u0) * fx)
            ..add(l.v0 + (l.v1 - l.v0) * fy);
        }
      }
      final nx = xs.length;
      for (var j = 0; j + 1 < ys.length; j++) {
        for (var i = 0; i + 1 < nx; i++) {
          final a = base + j * nx + i, b = a + 1;
          final c = a + nx, d = c + 1;
          ix.addAll([a, b, c, b, d, c]);
        }
      }
    }
    for (final p in rest.keys) {
      if (rest[p]!.length ~/ 2 > 65535) {
        throw StateError('carrier mesh page $p exceeds 16-bit indices');
      }
      pages[p] = CarrierPageMesh(
        rest: Float32List.fromList(rest[p]!),
        heights: Float32List.fromList(heights[p]!),
        wings: Float32List.fromList(wings[p]!),
        texture: Float32List.fromList(tex[p]!),
        indices: Uint16List.fromList(idx[p]!),
      );
    }
  }

  (double, double, double)? _built;

  /// Whether the last [rebuild] changed the positions.
  bool dirty = true;

  /// Rewrites the positions for [bend] when a parameter moved more than
  /// 0.02° since the last rebuild (design §2.4); null bend: rest.
  void rebuild(CarrierBend? bend) {
    final key = bend == null
        ? (0.0, 0.0, 0.0)
        : (bend.psi, bend.phi, bend.theta);
    final b = _built;
    const eps = .02 * CarrierBend.deg;
    if (b != null &&
        (key.$1 - b.$1).abs() < eps &&
        (key.$2 - b.$2).abs() < eps &&
        (key.$3 - b.$3).abs() < eps &&
        (bend == null ||
            (bend.wingLean - _wing.$1).abs() < eps &&
                (bend.wingBank - _wing.$2).abs() < eps &&
                (bend.wingPitch - _wing.$3).abs() < eps)) {
      dirty = false;
      return;
    }
    _built = key;
    if (bend != null) _wing = (bend.wingLean, bend.wingBank, bend.wingPitch);
    for (final p in pages.values) {
      final n = p.rest.length ~/ 2;
      for (var i = 0; i < n; i++) {
        final x = p.rest[2 * i], y = p.rest[2 * i + 1];
        if (bend == null) {
          p.positions[2 * i] = x;
          p.positions[2 * i + 1] = y;
          continue;
        }
        final o = bend.displace(x, y, h: p.heights[i], wing: p.wings[i]);
        p.positions[2 * i] = o.dx;
        p.positions[2 * i + 1] = o.dy;
      }
      p.vertices?.dispose();
      p.vertices = null;
    }
    dirty = true;
  }

  (double, double, double) _wing = (0, 0, 0);

  /// The page's vertices for drawing (created on demand, reused until the
  /// next change).
  ui.Vertices verticesOf(int page) {
    final p = pages[page]!;
    return p.vertices ??= ui.Vertices.raw(
      ui.VertexMode.triangles,
      p.positions,
      textureCoordinates: p.texture,
      indices: p.indices,
    );
  }

  void dispose() {
    for (final p in pages.values) {
      p.vertices?.dispose();
      p.vertices = null;
    }
  }
}

class CarrierPageMesh {
  CarrierPageMesh({
    required this.rest,
    required this.heights,
    required this.wings,
    required this.texture,
    required this.indices,
  }) : positions = Float32List.fromList(rest);
  final Float32List rest, heights, wings, texture;
  final Float32List positions;
  final Uint16List indices;
  ui.Vertices? vertices;
}
