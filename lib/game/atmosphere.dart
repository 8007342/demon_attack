import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/painting.dart';

import 'perspective.dart';

/// Layered atmosphere in depth (openspec/changes/atmosphere-and-swarms,
/// plan/atmosphere-research.md §1-§2): a horizon band where waves hold, two
/// distant fog banks interleaved with the arriving creatures by nearness,
/// ground fog lying on the lower terrain and one or two very thin sky sheets
/// drifting over the whole arena, ship included. Presentation only: it reads
/// the clock, the flight distance and the ship's position, never the model.
///
/// Two renderers share the same slots and numbers:
/// - the fog fragment shader (`shaders/fog.frag`): domain-warped fBm per
///   pixel, ground fog projected through the flyover camera;
/// - the tile fallback, which is also the reduced-atmosphere path: two baked,
///   tileable fBm textures ([bakeTile]) scrolled at two scales in different
///   directions, so the shapes interfere and evolve instead of sliding.
///
/// The ground-atmosphere art atlas (plan/ground-atmosphere.md §3) can later
/// replace a slot's texture through [art] without touching the draw order.
enum FogSlot {
  horizonBand,
  farBankA,
  farBankB,
  groundFog,
  skySheet1,
  skySheet2,
}

/// Atmosphere quality: full layers (shader where available) or the reduced
/// low-end tier (horizon band and ground fog from tiles, no sky sheets).
enum AtmosphereQuality {
  full,
  reduced;

  String get label => this == full ? 'FULL' : 'REDUCED';
  static AtmosphereQuality parse(String? value) =>
      value == 'reduced' ? reduced : full;
}

/// One slot's band on screen and look (arena units, 360 x 520 column).
class FogLayer {
  const FogLayer({
    required this.top,
    required this.peak,
    required this.bottom,
    required this.alpha,
    required this.scale,
    required this.drift,
    required this.parallax,
    this.nearness = 0,
    this.lighten = 0,
    this.threshold = 0,
    this.warp = 1,
  });

  /// Vertical profile: 0 at [top], [alpha] at [peak], 0 at [bottom].
  final double top, peak, bottom, alpha;

  /// Texture scale (arena units per tile) and drift (units/s) of the main
  /// pass; the second pass runs at a smaller scale against the wind.
  final double scale;
  final Offset drift;

  /// Lateral parallax against the ship's offset from the centre.
  final double parallax;

  /// Depth of the layer on the creatures' nearness scale: creatures nearer
  /// than this are drawn in front of it (0: not depth-sorted).
  final double nearness;

  /// Mix toward white (sky sheets read as pale haze over the dark ground).
  final double lighten;

  /// Extra wisp threshold (0-1): higher leaves larger gaps.
  final double threshold;

  /// Domain-warp strength in the shader.
  final double warp;
}

class Atmosphere {
  Atmosphere();

  static const layers = <FogSlot, FogLayer>{
    // Waves hold here; peaks just above the horizon line (y 172).
    FogSlot.horizonBand: FogLayer(
      top: 112,
      peak: 168,
      bottom: 236,
      alpha: .62,
      scale: 300,
      drift: Offset(1.5, 0),
      parallax: .08,
      nearness: .26,
      warp: 1.2,
    ),
    // Bottom edges at the ground-atmosphere mid-mist lines (y ~230/243).
    FogSlot.farBankA: FogLayer(
      top: 120,
      peak: 176,
      bottom: 238,
      alpha: .40,
      scale: 200,
      drift: Offset(3, 0),
      parallax: .2,
      nearness: .335,
      threshold: .12,
    ),
    FogSlot.farBankB: FogLayer(
      top: 130,
      peak: 194,
      bottom: 252,
      alpha: .30,
      scale: 170,
      drift: Offset(-2, 0),
      parallax: .3,
      nearness: .43,
      threshold: .2,
    ),
    // Lies on the terrain below the formation, scrolls with the ground.
    FogSlot.groundFog: FogLayer(
      top: 226,
      peak: 290,
      bottom: 540,
      alpha: .36,
      scale: 150,
      drift: Offset(3, 1),
      parallax: 1,
      nearness: .55,
      threshold: .18,
      warp: .9,
    ),
    // Very thin, over everything (bullets, player, tells and HUD excepted).
    FogSlot.skySheet1: FogLayer(
      top: -40,
      peak: 120,
      bottom: 560,
      alpha: .08,
      scale: 420,
      drift: Offset(6, 2.2),
      parallax: 1.2,
      lighten: .35,
      threshold: .05,
    ),
    FogSlot.skySheet2: FogLayer(
      top: 60,
      peak: 300,
      bottom: 560,
      alpha: .06,
      scale: 300,
      drift: Offset(-4.5, 3.2),
      parallax: 1.35,
      lighten: .25,
      threshold: .1,
    ),
  };

  /// Sky sheets fade near the ship's row so the two together stay at or
  /// under 12 % over the player (research §11).
  static const shipZoneTop = 410.0, shipZoneFactor = .7;
  static const maxOverShip = .12;

  /// Peak opacity a sky sheet can apply at screen [y].
  static double sheetAlphaAt(FogSlot slot, double y) {
    final l = layers[slot]!;
    final profile = _profile(l, y) * l.alpha;
    final zone = Perspective.smoothstep(shipZoneTop - 30, shipZoneTop, y);
    return profile * (1 - zone * (1 - shipZoneFactor));
  }

  /// Combined peak opacity of both sky sheets at screen [y].
  static double sheetsAlphaAt(double y) =>
      1 -
      (1 - sheetAlphaAt(FogSlot.skySheet1, y)) *
          (1 - sheetAlphaAt(FogSlot.skySheet2, y));

  static double _profile(FogLayer l, double y) {
    if (y <= l.top || y >= l.bottom) return 0;
    if (y < l.peak) return Perspective.smoothstep(l.top, l.peak, y);
    return 1 - Perspective.smoothstep(l.peak, l.bottom, y);
  }

  // --- sector colours (plan/ground-atmosphere.md §2, lifted for the air) --
  /// The air's colour per sector (Krybor, Ringfall, Ember, Hollow, Carrier):
  /// the ground-atmosphere fog tints lifted toward the horizon's light.
  static const airFog = [
    Color(0xFF66728E),
    Color(0xFF6B6390),
    Color(0xFF7A5C56),
    Color(0xFF5B6F68),
    Color(0xFF6F5469),
  ];

  /// The veil a distant creature fades into: the fog tint itself, a little
  /// darker than the air in front of it, so a far body reads as a darker
  /// patch of fog rather than a black cutout (research §5).
  static const veilFog = [
    Color(0xFF3A4458),
    Color(0xFF3D3550),
    Color(0xFF46302C),
    Color(0xFF2E3A35),
    Color(0xFF3A2836),
  ];

  static Color _lerpTable(List<Color> table, double environment) {
    final e = environment.clamp(0.0, 4.0);
    final i = e.floor().clamp(0, 4);
    final j = math.min(4, i + 1);
    return Color.lerp(table[i], table[j], e - i)!;
  }

  // --- state ---------------------------------------------------------------
  AtmosphereQuality quality = AtmosphereQuality.full;

  /// Reduced motion keeps every layer still (accessibility).
  bool reducedMotion = false;

  /// Seconds of fog time (frozen while [reducedMotion]).
  double time = 0;

  /// Flight distance (arena units at the bottom row; flyover `distance`).
  double groundDistance = 0;
  double shipX = 180, shipY = 477;
  double environment = 0;

  Color get air => _lerpTable(airFog, environment);
  Color get veil => _lerpTable(veilFog, environment);

  /// Optional authored texture per slot (ground-atmosphere art atlas).
  final art = <FogSlot, ui.Image>{};

  ui.Image? tileA, tileB;
  ui.FragmentProgram? program;
  final _shaders = <FogSlot, ui.FragmentShader>{};

  /// The shader renders the full tier when it compiled on this platform.
  bool shaderEnabled = true;
  bool get usesShader =>
      shaderEnabled && program != null && quality == AtmosphereQuality.full;
  bool get ready => tileA != null && tileB != null;

  /// Frame-time guard for the shader: if frames average slower than
  /// [slowFrame] over [guardFrames] frames while the shader draws, the fog
  /// drops to the tile path for the rest of the session (phones whose GPU
  /// compiles the shader but cannot afford it). Long gaps (a hidden tab, a
  /// debugger pause) are ignored.
  static const guardFrames = 120;
  static const slowFrame = 1 / 45;
  double _guardTime = 0;
  int _guardCount = 0;

  /// Whether the frame-time guard turned the shader off.
  bool shaderThrottled = false;

  void _guard(double dt) {
    if (!usesShader || dt <= 0 || dt > .25) return;
    _guardTime += dt;
    _guardCount++;
    if (_guardCount < guardFrames) return;
    if (_guardTime / _guardCount > slowFrame) {
      shaderEnabled = false;
      shaderThrottled = true;
    }
    _guardTime = 0;
    _guardCount = 0;
  }

  void advance(double dt, {required double distance, double? x, double? y}) {
    _guard(dt);
    if (!reducedMotion) time += dt;
    groundDistance = distance;
    if (x != null) shipX = x;
    if (y != null) shipY = y;
  }

  /// Bakes the fallback tiles and, where supported, loads the fog shader.
  /// Never throws: a failed shader leaves the tile path in charge.
  Future<void> load({bool shader = true}) async {
    tileA ??= await _image(bakeTile(size: 256, seed: 11, period: 4), 256);
    tileB ??= await _image(
      bakeTile(size: 128, seed: 29, period: 4, warp: false, lo: .42, hi: .82),
      128,
    );
    if (shader && program == null) {
      try {
        program = await ui.FragmentProgram.fromAsset('shaders/fog.frag');
      } catch (_) {
        program = null; // no runtime effects here: tiles carry the fog
      }
    }
  }

  static Future<ui.Image> _image(Uint8List pixels, int size) {
    final done = Completer<ui.Image>();
    ui.decodeImageFromPixels(
      pixels,
      size,
      size,
      ui.PixelFormat.rgba8888,
      done.complete,
    );
    return done.future;
  }

  // --- tileable fBm --------------------------------------------------------
  /// A tileable fBm texture (premultiplied white, density in alpha): value
  /// noise on a periodic lattice, 4 octaves (lacunarity 2, gain .5), with
  /// optional domain warping `fbm(p + 2 q)` (Quilez) so the billows fold.
  /// `smoothstep(lo, hi, n)` leaves wisps with gaps.
  static Uint8List bakeTile({
    int size = 256,
    int seed = 1,
    int period = 4,
    bool warp = true,
    double lo = .3,
    double hi = .78,
  }) {
    final out = Uint8List(size * size * 4);
    double fbm(double x, double y) {
      var sum = 0.0, amp = .5, p = period;
      var fx = x, fy = y;
      for (var o = 0; o < 4; o++) {
        sum += amp * _valueNoise(fx * p, fy * p, p, seed + o * 101);
        fx *= 1;
        p *= 2;
        amp *= .5;
      }
      return sum / .9375;
    }

    for (var j = 0; j < size; j++) {
      for (var i = 0; i < size; i++) {
        final x = i / size, y = j / size;
        var n = fbm(x, y);
        if (warp) {
          final qx = fbm(x + .31, y + .17), qy = fbm(x + .52, y + .83);
          n = fbm(x + .5 * (qx - .5), y + .5 * (qy - .5));
        }
        final a = (Perspective.smoothstep(lo, hi, n) * 255).round();
        final k = (j * size + i) * 4;
        out[k] = out[k + 1] = out[k + 2] = out[k + 3] = a;
      }
    }
    return out;
  }

  /// Periodic value noise at lattice coordinates ([px], [py]) wrapping every
  /// [period] cells: smooth (quintic) interpolation of hashed corners.
  static double _valueNoise(double px, double py, int period, int seed) {
    final x0 = px.floor(), y0 = py.floor();
    final fx = px - x0, fy = py - y0;
    double h(int x, int y) {
      final xi = x % period, yi = y % period;
      var v = xi * 374761393 + yi * 668265263 + seed * 2147483647;
      v = (v ^ (v >> 13)) * 1274126177;
      v = v ^ (v >> 16);
      return (v & 0xFFFF) / 0xFFFF;
    }

    final u = fx * fx * fx * (fx * (fx * 6 - 15) + 10);
    final w = fy * fy * fy * (fy * (fy * 6 - 15) + 10);
    final a = h(x0, y0), b = h(x0 + 1, y0);
    final c = h(x0, y0 + 1), d = h(x0 + 1, y0 + 1);
    return a + (b - a) * u + (c - a) * w + (a - b - c + d) * u * w;
  }

  // --- creature tint (design §1) ------------------------------------------
  final _tintCache = <int, ColorFilter>{};
  int _tintKey = 0;

  /// A colour filter veiling a sprite by transmittance [t]: saturation
  /// `mix(.2, 1, t)`, contrast pulled toward the veil's value, then mixed
  /// toward the sector's veil colour by `1 - t`. Cached per depth bucket.
  ColorFilter? tintFor(double t) {
    final bucket = Perspective.tintBucket(t);
    if (bucket >= 15) return null;
    final v = veil;
    final key = v.toARGB32();
    if (key != _tintKey) {
      _tintCache.clear();
      _tintKey = key;
    }
    return _tintCache[bucket] ??= ColorFilter.matrix(
      veilMatrix(bucket / 15, v),
    );
  }

  /// The 4x5 colour matrix behind [tintFor] (offsets in 0-255).
  static List<double> veilMatrix(double t, Color veil) {
    const lr = .2126, lg = .7152, lb = .0722;
    final s = .2 + .8 * t; // saturation
    final c = .4 + .6 * t; // contrast toward the veil's value
    final m = (1 - t) * .9; // share of the veil colour
    final vr = veil.r, vg = veil.g, vb = veil.b;
    final pivot = lr * vr + lg * vg + lb * vb;
    final rows = <double>[];
    for (final target in [vr, vg, vb]) {
      final row = rows.length ~/ 5;
      // saturation: L + s (x - L), per input channel
      final sat = [
        lr * (1 - s) + (row == 0 ? s : 0),
        lg * (1 - s) + (row == 1 ? s : 0),
        lb * (1 - s) + (row == 2 ? s : 0),
      ];
      final k = (1 - m) * c;
      rows.addAll([
        k * sat[0],
        k * sat[1],
        k * sat[2],
        0,
        ((1 - m) * (1 - c) * pivot + m * target) * 255,
      ]);
    }
    rows.addAll([0, 0, 0, 1, 0]);
    return rows;
  }

  /// Emissive mask: keeps the warm, bright pixels (eyes, cracks, flames) and
  /// drops the body, so glows can be drawn again over a veiled sprite.
  static const glowMatrix = ColorFilter.matrix(<double>[
    1.25, 0, 0, 0, 10, //
    0, 1.2, 0, 0, 6,
    0, 0, 1.1, 0, 0,
    3.4, 7.0, -6.6, 0, -1500,
  ]);

  // --- painting ------------------------------------------------------------
  /// Slots the shader draws: the bands where the depth reads (horizon band
  /// and far banks, about three quarters of a screen together). The ground
  /// fog and the full-screen sky sheets stay on the tiles, which cost a
  /// texture fetch per pixel instead of ~12 noise evaluations: the fog pass
  /// keeps to its 2 ms budget on a phone without a half-resolution target.
  static const shaderSlots = {
    FogSlot.horizonBand,
    FogSlot.farBankA,
    FogSlot.farBankB,
  };

  /// Whether [slot] is drawn at the current quality.
  bool shows(FogSlot slot) => switch (slot) {
    FogSlot.horizonBand || FogSlot.groundFog => true,
    _ => quality == AtmosphereQuality.full,
  };

  /// Paints [slot] over the arena (360 x 520 arena units on [c]).
  void paint(Canvas c, FogSlot slot) {
    if (!shows(slot)) return;
    final l = layers[slot]!;
    if (usesShader && shaderSlots.contains(slot) && _paintShader(c, slot, l)) {
      return;
    }
    if (!ready) {
      _paintGradientOnly(c, slot, l);
      return;
    }
    _paintTiles(c, slot, l);
  }

  Color _colorOf(FogSlot slot, FogLayer l) {
    final base = slot == FogSlot.groundFog ? Color.lerp(air, veil, .35)! : air;
    return l.lighten > 0
        ? Color.lerp(base, const Color(0xFFE6E8F4), l.lighten)!
        : base;
  }

  Rect _bounds(FogLayer l) =>
      Rect.fromLTRB(0, math.max(0, l.top), 360, math.min(520, l.bottom));

  /// Lateral offset of a layer for the ship's position (parallax).
  /// Nearer layers shift more; the ground fog stays locked to the ground.
  double _shift(FogLayer l) => -(shipX - 180) * l.parallax * .1;

  void _paintGradientOnly(Canvas c, FogSlot slot, FogLayer l) {
    final r = _bounds(l);
    final color = _colorOf(slot, l);
    c.drawRect(r, Paint()..shader = _profileGradient(l, color, .55, r));
  }

  ui.Gradient _profileGradient(FogLayer l, Color color, double k, Rect r) {
    final stops = <double>[];
    final colors = <Color>[];
    for (var i = 0; i <= 8; i++) {
      final y = r.top + (r.bottom - r.top) * i / 8;
      stops.add(i / 8);
      var a = _profile(l, y) * k;
      if (l.lighten > 0) {
        final zone = Perspective.smoothstep(shipZoneTop - 30, shipZoneTop, y);
        a *= 1 - zone * (1 - shipZoneFactor);
      }
      colors.add(color.withValues(alpha: a.clamp(0.0, 1.0)));
    }
    return ui.Gradient.linear(
      Offset(0, r.top),
      Offset(0, r.bottom),
      colors,
      stops,
    );
  }

  Float64List _matrix(double scale, double sy, double ox, double oy) =>
      Float64List.fromList([
        scale, 0, 0, 0, //
        0, scale * sy, 0, 0,
        0, 0, 1, 0,
        ox, oy, 0, 1,
      ]);

  /// Tile path: the layer's band is isolated, filled by two scrolled noise
  /// passes, then shaped by its vertical profile (dstIn).
  void _paintTiles(Canvas c, FogSlot slot, FogLayer l) {
    final r = _bounds(l);
    final color = _colorOf(slot, l);
    final a = art[slot] ?? tileA!, b = tileB!;
    final t = time;
    final shift = _shift(l);
    final ground = slot == FogSlot.groundFog;
    c.saveLayer(r, Paint());
    final tint = ColorFilter.mode(color, BlendMode.srcIn);
    if (ground) {
      _paintGroundStrips(c, r, a, b, tint, l);
    } else {
      // Main pass: big billows; flattened (sy .5) toward the horizon.
      final sy = slot == FogSlot.skySheet1 || slot == FogSlot.skySheet2
          ? .7
          : .45;
      final s1 = l.scale / a.width;
      c.drawRect(
        r,
        Paint()
          ..colorFilter = tint
          ..color = const Color(0xFFFFFFFF)
          ..filterQuality = FilterQuality.low
          ..shader = ImageShader(
            a,
            TileMode.repeated,
            TileMode.repeated,
            _matrix(s1, sy, l.drift.dx * t + shift, l.drift.dy * t),
            filterQuality: FilterQuality.low,
          ),
      );
      // Second pass: finer wisps against the wind, eroding the billows so
      // the outline changes as they cross (not a sliding bitmap).
      final s2 = l.scale * .55 / b.width;
      c.drawRect(
        r,
        Paint()
          ..blendMode = BlendMode.dstOut
          ..color = Color.fromRGBO(255, 255, 255, .55 + l.threshold)
          ..filterQuality = FilterQuality.low
          ..shader = ImageShader(
            b,
            TileMode.repeated,
            TileMode.repeated,
            _matrix(
              s2,
              sy,
              -l.drift.dx * .7 * t + shift * 1.3 + 37,
              -l.drift.dy * .5 * t + 11 + math.sin(t * .05) * 20,
            ),
            filterQuality: FilterQuality.low,
          ),
      );
    }
    // Vertical profile (and the ship-zone cap of the sky sheets).
    c.drawRect(
      r,
      Paint()
        ..blendMode = BlendMode.dstIn
        ..shader = _profileGradient(l, const Color(0xFFFFFFFF), l.alpha, r),
    );
    c.restore();
  }

  /// Ground fog is locked to the terrain: thin strips, each mapped through
  /// the flyover camera (y = 172 + 348 z0/z), so it scrolls and foreshortens
  /// with the ground beneath it.
  void _paintGroundStrips(
    Canvas c,
    Rect r,
    ui.Image a,
    ui.Image b,
    ColorFilter tint,
    FogLayer l,
  ) {
    const h = Perspective.horizonY, g = Perspective.groundSpan;
    // Ground texels: depth W = cam + z, z = g * z0 / (y - h), z0 = g / 2.
    final cam = groundDistance / 2;
    double depthAt(double y) => cam + g * (g / 2) / math.max(1, y - h);
    final t = time;
    var y = r.top;
    while (y < r.bottom) {
      final step = y < 300 ? 5.0 : (y < 400 ? 9.0 : 14.0);
      final y2 = math.min(r.bottom, y + step);
      final w1 = depthAt(y), w2 = depthAt(y2);
      final n = ((y + y2) / 2 - h) / g; // ground scale at the strip
      for (final (img, scale, k, wind) in [
        (a, l.scale, 1.0, l.drift),
        (b, l.scale * .6, .6, -l.drift * .8),
      ]) {
        final texel = scale / img.width; // ground texels per image pixel
        // Image v at screen y: (W + wind) / texel, mapped linearly over the
        // strip; image u: lateral ground texels (x - 180) / (2 n).
        final v1 = (w1 + wind.dy * t) / texel, v2 = (w2 + wind.dy * t) / texel;
        final syc = (y2 - y) / (v1 - v2); // canvas units per image pixel (v)
        final sxc = 2 * n * texel; // canvas units per image pixel (u)
        final ox = 180 - wind.dx * t * 2 * n;
        c.drawRect(
          Rect.fromLTRB(r.left, y, r.right, y2),
          Paint()
            ..colorFilter = tint
            ..blendMode = k < 1 ? BlendMode.dstOut : BlendMode.srcOver
            ..color = Color.fromRGBO(255, 255, 255, k < 1 ? .5 : 1)
            ..filterQuality = FilterQuality.low
            ..shader = ImageShader(
              img,
              TileMode.repeated,
              TileMode.repeated,
              Float64List.fromList([
                sxc, 0, 0, 0, //
                0, -syc, 0, 0,
                0, 0, 1, 0,
                ox, y + v1 * syc, 0, 1,
              ]),
              filterQuality: FilterQuality.low,
            ),
        );
      }
      y = y2;
    }
  }

  // --- shader path ---------------------------------------------------------
  /// One rect per slot with the fog shader; false if it cannot draw here.
  bool _paintShader(Canvas c, FogSlot slot, FogLayer l) {
    final p = program;
    if (p == null) return false;
    final ui.FragmentShader s;
    try {
      s = _shaders[slot] ??= p.fragmentShader();
    } catch (_) {
      shaderEnabled = false;
      return false;
    }
    // FlutterFragCoord is in local (arena) coordinates on every backend,
    // so the mapping is the identity; kept as a uniform for half-res use.
    const sx = 1.0, sy = 1.0, tx = 0.0, ty = 0.0;
    final color = _colorOf(slot, l);
    final ground = slot == FogSlot.groundFog;
    final sheet = slot == FogSlot.skySheet1 || slot == FogSlot.skySheet2;
    var i = 0;
    void f(double v) => s.setFloat(i++, v);
    // uXform: device = arena * scale + offset
    f(sx);
    f(sy);
    f(tx);
    f(ty);
    // uBand: top, peak, bottom, alpha
    f(l.top);
    f(l.peak);
    f(l.bottom);
    f(l.alpha);
    // uColor (premultiplied in the shader)
    f(color.r);
    f(color.g);
    f(color.b);
    f(l.threshold);
    // uMotion: time, drift x, drift y, warp
    f(time);
    f(l.drift.dx);
    f(l.drift.dy);
    f(l.warp);
    // uLook: scale, flatten, ground (0/1), lateral shift
    f(l.scale);
    f(sheet ? .7 : .45);
    f(ground ? 1 : 0);
    f(_shift(l));
    // uShip: ship-zone top, factor (sheets only), ground cam, seed
    f(sheet ? shipZoneTop : 9999);
    f(shipZoneFactor);
    f(groundDistance / 2);
    f(slot.index * 17.0);
    c.drawRect(_bounds(l), Paint()..shader = s);
    return true;
  }
}
