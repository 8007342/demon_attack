import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/painting.dart';

import 'ground_atmosphere.dart';
import 'ground_atmosphere_atlas.dart';
import 'perspective.dart';

/// Layered atmosphere in depth (openspec/changes/atmosphere-and-swarms,
/// openspec/changes/fog-restoration, plan/atmosphere-research.md §1-§2):
/// fog over the whole depth of the field, built from soft layers that add
/// up. Back to front: a horizon band where waves hold, two far banks, an
/// upper veil and a mid veil, all interleaved with the air creatures by
/// nearness (an arrival rises up through them one by one); ground fog lying
/// on the terrain; one or two very thin sky sheets over the whole arena.
/// Presentation only: it reads the clock and the flight distance, never the
/// model.
///
/// World-anchored (fog-restoration): no layer reads the ship's position or
/// the controls. Layers drift with the wind and the ground fog scrolls with
/// the terrain; the camera does not follow the ship, so there is no lateral
/// parallax to apply.
///
/// Two renderers share the same slots and numbers:
/// - the fog fragment shader (`shaders/fog.frag`): domain-warped fBm per
///   pixel, ground fog projected through the flyover camera;
/// - the tile fallback, which is also the reduced-atmosphere path: two baked,
///   tileable fBm textures ([bakeTile]) scrolled at two scales in different
///   directions, so the shapes interfere and evolve instead of sliding.
///
/// The ground-atmosphere art atlas (plan/ground-atmosphere.md §3), once
/// installed in [Atmosphere.groundArt], adds to these layers instead of
/// replacing them: its horizon fog, mist banks, cloud shadows and dust veil
/// are drawn in the ground depth sort ([Atmosphere.groundLayers]) so ground
/// units emerge through them, and its low cloud deck sits under the soft
/// horizon band. [Atmosphere.art] still lets a single slot swap its tile.
enum FogSlot {
  horizonBand,
  farBankA,
  farBankB,
  upperVeil,
  midVeil,
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
    this.nearness = 0,
    this.lighten = 0,
    this.threshold = 0,
    this.warp = 1,
    this.clearsLane = false,
  });

  /// Vertical profile: 0 at [top], [alpha] at [peak], 0 at [bottom].
  final double top, peak, bottom, alpha;

  /// Texture scale (arena units per tile) and drift (units/s) of the main
  /// pass; the second pass runs at a smaller scale against the wind. The
  /// drift is the wind: the only lateral motion a layer has.
  final double scale;
  final Offset drift;

  /// Depth of the layer on the creatures' nearness scale: creatures nearer
  /// than this are drawn in front of it (0: not depth-sorted).
  final double nearness;

  /// Mix toward white (sky sheets read as pale haze over the dark ground).
  final double lighten;

  /// Extra wisp threshold (0-1): higher leaves larger gaps.
  final double threshold;

  /// Domain-warp strength in the shader.
  final double warp;

  /// Whether the layer reaches the near lane and thins over it
  /// ([Atmosphere.laneClear]), so the lane and the ship stay readable.
  final bool clearsLane;
}

class Atmosphere {
  Atmosphere();

  /// Every layer is wide and soft: each profile spans well over a hundred
  /// rows and overlaps its neighbours, so together they read as one deep
  /// body of fog instead of a band (fog-restoration design §2). The five
  /// air layers are spaced on the nearness scale between the arrival depth
  /// (.30) and the formation (>= .62): an arrival crosses them one at a
  /// time as it rises toward its slot.
  static const layers = <FogSlot, FogLayer>{
    // Waves hold here; peaks just above the horizon line (y 172).
    FogSlot.horizonBand: FogLayer(
      top: 92,
      peak: 172,
      bottom: 258,
      alpha: .7,
      scale: 300,
      drift: Offset(1.5, 0),
      nearness: .26,
      warp: 1.2,
    ),
    FogSlot.farBankA: FogLayer(
      top: 84,
      peak: 176,
      bottom: 262,
      alpha: .48,
      scale: 210,
      drift: Offset(3, 0),
      nearness: .335,
      threshold: .12,
    ),
    FogSlot.farBankB: FogLayer(
      top: 96,
      peak: 198,
      bottom: 286,
      alpha: .4,
      scale: 170,
      drift: Offset(-2, 0),
      nearness: .43,
      threshold: .16,
      warp: .8,
    ),
    // High cloud the arrivals climb through toward the upper rows.
    FogSlot.upperVeil: FogLayer(
      top: -40,
      peak: 92,
      bottom: 214,
      alpha: .3,
      scale: 340,
      drift: Offset(-2.6, .4),
      nearness: .5,
      threshold: .16,
      warp: .9,
    ),
    // Low cloud over the mid field: the last layer before the formation.
    FogSlot.midVeil: FogLayer(
      top: 112,
      peak: 226,
      bottom: 350,
      alpha: .3,
      scale: 260,
      drift: Offset(2.2, -.3),
      nearness: .565,
      threshold: .18,
      clearsLane: true,
    ),
    // Lies on the terrain from the far ground down to the ship's row,
    // scrolls with the ground.
    FogSlot.groundFog: FogLayer(
      top: 180,
      peak: 262,
      bottom: 540,
      alpha: .38,
      scale: 150,
      drift: Offset(3, 1),
      nearness: .55,
      threshold: .18,
      warp: .9,
      clearsLane: true,
    ),
    // Very thin, over everything (bullets, player, tells and HUD excepted).
    FogSlot.skySheet1: FogLayer(
      top: -40,
      peak: 120,
      bottom: 560,
      alpha: .08,
      scale: 420,
      drift: Offset(6, 2.2),
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
      lighten: .25,
      threshold: .1,
    ),
  };

  /// The air layers drawn in the creatures' depth sort, far to near.
  static const depthSlots = [
    FogSlot.horizonBand,
    FogSlot.farBankA,
    FogSlot.farBankB,
    FogSlot.upperVeil,
    FogSlot.midVeil,
  ];

  // --- continuous-swarm depth contract (its design §0, fog-restoration
  // §2): the swarm reads the fog only through these accessors.

  /// Nearness of every depth-sorted air layer, far to near (sorted). The
  /// swarm's reserve waits below the first; arrival paths cross them all.
  static List<double> get bandNearness =>
      [for (final s in depthSlots) layers[s]!.nearness]..sort();

  /// Light left through the ground fog for a ground shadow (t_ground);
  /// fog-restoration may refine it per row. 0.85 is the swarm's fallback.
  static double groundLight([double y = 400]) => .85;

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

  // --- the near lane (plan/ground-atmosphere.md §5.2) ----------------------
  /// Share of a lane-clearing layer removed over the lane: full inside x
  /// [laneLeft]-[laneRight] below [laneTop], ramping in over [laneRamp]
  /// units sideways and above.
  static const laneLeft = GroundAtmosphereAtlas.laneLeft;
  static const laneRight = GroundAtmosphereAtlas.laneRight;
  static const laneTop = GroundAtmosphereAtlas.laneTop;
  static const laneRamp = 36.0, laneClear = .62;

  /// The lane mask at ([x], [y]): 0 outside, 1 inside.
  static double laneMask(double x, double y) {
    final h = math.min(
      Perspective.smoothstep(laneLeft - laneRamp, laneLeft, x),
      1 - Perspective.smoothstep(laneRight, laneRight + laneRamp, x),
    );
    return h * Perspective.smoothstep(laneTop - laneRamp, laneTop, y);
  }

  /// Peak opacity layer [slot] can apply at ([x], [y]): its profile, the
  /// ship-zone cap of the sky sheets and the lane clearing. The noise only
  /// thins it, so this is an upper bound for every pixel.
  static double peakAlphaAt(FogSlot slot, double x, double y) {
    final l = layers[slot]!;
    if (slot == FogSlot.skySheet1 || slot == FogSlot.skySheet2) {
      return sheetAlphaAt(slot, y);
    }
    final a = _profile(l, y) * l.alpha;
    return l.clearsLane ? a * (1 - laneClear * laneMask(x, y)) : a;
  }

  /// Combined peak opacity of the full tier's fog layers at ([x], [y]).
  static double combinedAlphaAt(double x, double y) {
    var clear = 1.0;
    for (final slot in FogSlot.values) {
      clear *= 1 - peakAlphaAt(slot, x, y);
    }
    return 1 - clear;
  }

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
  double environment = 0;

  Color get air => _lerpTable(airFog, environment);
  Color get veil => _lerpTable(veilFog, environment);

  /// Optional authored tile texture per slot (replaces tile A).
  final art = <FogSlot, ui.Image>{};

  // --- ground-atmosphere art (ground_atmosphere.dart) ----------------------
  /// The ground-atmosphere atlas, when loaded.
  GroundAtmosphereArt? groundArt;

  /// The skirmish tide (0 lull .. 1 surge): raises the dust veil.
  double tide = .5;

  /// Opacity factor of the art's low cloud deck, drawn under the soft
  /// horizon band: the band blurs the deck's stepped edges.
  static const lowCloudUnderBand = .45;

  bool _artLayerShown(GroundAtmosphereLayer l) =>
      quality == AtmosphereQuality.full || l.reduced;

  /// Art layers drawn in the ground depth sort at the current quality, back
  /// to front: (depth, layer); a layer with no depth goes after every
  /// ground object (depth -infinity). Empty without the atlas.
  List<(double, GroundAtmosphereLayer)> get groundLayers {
    if (groundArt == null) return const [];
    return [
      for (final l in GroundAtmosphereAtlas.layers)
        if (l.pass == 'ground' && _artLayerShown(l))
          (l.sortZ ?? double.negativeInfinity, l),
    ];
  }

  /// Dust veil opacity: none in a lull, full in a surge.
  double get dustOpacity => Perspective.smoothstep(.55, .95, tide);

  /// Paints art layer [l] (ground pass or air pass).
  void paintGroundLayer(Canvas c, GroundAtmosphereLayer l) {
    final g = groundArt;
    if (g == null || !_artLayerShown(l)) return;
    if (l.id == 'cloudShadow') {
      g.paintShadows(c, l, time: time);
      return;
    }
    g.paintBand(
      c,
      l,
      time: time,
      environment: environment,
      opacity: l.id == 'dustVeil'
          ? dustOpacity
          : (l.pass == 'air' ? lowCloudUnderBand : 1),
    );
  }

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

  /// Advances the fog clock and the ground under it. The fog takes no ship
  /// position: it is world-anchored (fog-restoration).
  void advance(double dt, {required double distance}) {
    _guard(dt);
    if (!reducedMotion) time += dt;
    groundDistance = distance;
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

  /// Whether [slot] is drawn at the current quality (reduced: the horizon
  /// band and the ground fog).
  bool shows(FogSlot slot) => switch (slot) {
    FogSlot.horizonBand || FogSlot.groundFog => true,
    _ => quality == AtmosphereQuality.full,
  };

  /// Paints [slot] over the arena (360 x 520 arena units on [c]).
  void paint(Canvas c, FogSlot slot) {
    if (!shows(slot)) return;
    if (slot == FogSlot.horizonBand && groundArt != null) {
      // The art's low cloud deck lies under the soft horizon band.
      for (final l in GroundAtmosphereAtlas.layers) {
        if (l.pass == 'air') paintGroundLayer(c, l);
      }
    }
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

  void _paintGradientOnly(Canvas c, FogSlot slot, FogLayer l) {
    final r = _bounds(l);
    final color = _colorOf(slot, l);
    if (!l.clearsLane) {
      c.drawRect(r, Paint()..shader = _profileGradient(l, color, .55, r));
      return;
    }
    c.saveLayer(r, Paint());
    c.drawRect(r, Paint()..shader = _profileGradient(l, color, .55, r));
    _clearLane(c, r);
    c.restore();
  }

  /// Thins the layer being composited over the near lane by [laneClear]
  /// (a soft-edged rectangle: horizontal ramp times vertical ramp, the
  /// same mask as [laneMask]).
  void _clearLane(Canvas c, Rect r) {
    final lane = Rect.fromLTRB(
      laneLeft - laneRamp,
      math.max(r.top, laneTop - laneRamp),
      laneRight + laneRamp,
      r.bottom,
    );
    if (lane.isEmpty) return;
    c.saveLayer(lane, Paint()..blendMode = BlendMode.dstOut);
    final k = Color.fromRGBO(0, 0, 0, laneClear);
    const z = Color(0x00000000);
    final hs = <double>[], hc = <Color>[];
    for (var i = 0; i <= 8; i++) {
      final x = lane.left + lane.width * i / 8;
      hs.add(i / 8);
      hc.add(Color.lerp(z, k, math.min(
        Perspective.smoothstep(laneLeft - laneRamp, laneLeft, x),
        1 - Perspective.smoothstep(laneRight, laneRight + laneRamp, x),
      ))!);
    }
    c.drawRect(
      lane,
      Paint()
        ..shader = ui.Gradient.linear(
          Offset(lane.left, 0),
          Offset(lane.right, 0),
          hc,
          hs,
        ),
    );
    const w = Color(0xFFFFFFFF), o = Color(0x00FFFFFF);
    final vs = <double>[], vc = <Color>[];
    for (var i = 0; i <= 6; i++) {
      final y = laneTop - laneRamp + laneRamp * i / 6;
      vs.add(i / 6);
      vc.add(Color.lerp(o, w,
          Perspective.smoothstep(laneTop - laneRamp, laneTop, y))!);
    }
    c.drawRect(
      lane,
      Paint()
        ..blendMode = BlendMode.dstIn
        ..shader = ui.Gradient.linear(
          const Offset(0, laneTop - laneRamp),
          const Offset(0, laneTop),
          vc,
          vs,
        ),
    );
    c.restore();
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
            _matrix(s1, sy, l.drift.dx * t, l.drift.dy * t),
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
              -l.drift.dx * .7 * t + 37,
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
    if (l.clearsLane) _clearLane(c, r);
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
    // uLook: scale, flatten, ground (0/1), lateral offset (world-anchored)
    f(l.scale);
    f(sheet ? .7 : .45);
    f(ground ? 1 : 0);
    f(0);
    // uShip: ship-zone top, factor (sheets only), ground cam, seed
    f(sheet ? shipZoneTop : 9999);
    f(shipZoneFactor);
    f(groundDistance / 2);
    f(slot.index * 17.0);
    c.drawRect(_bounds(l), Paint()..shader = s);
    return true;
  }
}
