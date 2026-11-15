import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/painting.dart';

import 'ground_atmosphere_atlas.dart';

/// The ground-atmosphere art (plan/ground-atmosphere.md, atlas
/// `assets/images/ground-atmosphere.png` from tools/ground_atmosphere):
/// horizon fog, low cloud, two mist banks, cloud shadows and the tide's dust
/// veil, drawn as stepped-alpha pixel strips at whole arena units. It is
/// installed into [Atmosphere.groundArt]; without it the atmosphere keeps
/// its baked fBm tiles and fog shader.
///
/// Presentation only: it reads the fog clock, the scene's environment and
/// the skirmish tide, never writes the model. World-anchored
/// (fog-restoration): the bands drift with the wind and never follow the
/// ship; the atlas' generated `parallax` numbers are not used at runtime.
class GroundAtmosphereArt {
  GroundAtmosphereArt(this.image);

  final ui.Image image;

  final Paint _paint = Paint()
    ..isAntiAlias = false
    ..filterQuality = FilterQuality.none;

  /// Source rect of band [id] for sector [s].
  static Rect bandRect(String id, int s) => switch (id) {
    'horizonFog' => GroundAtmosphereAtlas.horizonFog(s),
    'lowCloud' => GroundAtmosphereAtlas.lowCloud(s),
    'midMistA' => GroundAtmosphereAtlas.midMistA(s),
    'midMistB' => GroundAtmosphereAtlas.midMistB(s),
    'dustVeil' => GroundAtmosphereAtlas.dustVeil(s),
    _ => throw ArgumentError.value(id, 'id', 'not a tiled band'),
  };

  /// The sectors drawn for the scene's [environment] (0 Krybor .. 4
  /// Carrier) and their weights: one sector in a level, a cross-fade of two
  /// while travelling between them.
  static List<(int, double)> sectorWeights(double environment) {
    final e = environment.clamp(0.0, 4.0);
    final i = e.floor().clamp(0, 4);
    final f = e - i;
    return [
      if (f < .99) (i, 1 - f),
      if (f > .01 && i < 4) (i + 1, f),
    ];
  }

  /// Lateral offset in whole arena units: the drift with the fog clock.
  static int offset(GroundAtmosphereLayer l, double time) =>
      (l.drift * time).round();

  /// Paints tiled band [l] across the 360-unit arena column at its row.
  void paintBand(
    Canvas c,
    GroundAtmosphereLayer l, {
    required double time,
    required double environment,
    double opacity = 1,
  }) {
    final a = (l.opacity * opacity).clamp(0.0, 1.0);
    if (a <= 0) return;
    const w = GroundAtmosphereAtlas.width;
    final u0 = (-offset(l, time)) % w;
    for (final (s, weight) in sectorWeights(environment)) {
      final src = bandRect(l.id, s);
      _paint.color = Color.fromRGBO(255, 255, 255, a * weight);
      // The strip is wider than the column: at most two pieces.
      final first = math.min(360, w - u0);
      c.drawImageRect(
        image,
        Rect.fromLTWH(u0.toDouble(), src.top, first.toDouble(), src.height),
        Rect.fromLTWH(0, l.top, first.toDouble(), src.height),
        _paint,
      );
      if (first < 360) {
        c.drawImageRect(
          image,
          Rect.fromLTWH(0, src.top, 360.0 - first, src.height),
          Rect.fromLTWH(first.toDouble(), l.top, 360.0 - first, src.height),
          _paint,
        );
      }
    }
  }

  /// Ring the cloud shadows travel on (arena units): wider than the column
  /// so each leaves the screen before it wraps.
  static const shadowPeriod = 760;

  /// Paints the cloud shadows sliding over the far and mid ground,
  /// squashed by the ground's foreshortening.
  void paintShadows(
    Canvas c,
    GroundAtmosphereLayer l, {
    required double time,
    double opacity = 1,
  }) {
    final a = (l.opacity * opacity).clamp(0.0, 1.0);
    if (a <= 0) return;
    _paint.color = Color.fromRGBO(255, 255, 255, a);
    final o = offset(l, time);
    const n = GroundAtmosphereAtlas.cloudShadowFrames;
    const top = GroundAtmosphereAtlas.shadowRowTop;
    const span =
        GroundAtmosphereAtlas.shadowRowBottom - GroundAtmosphereAtlas.shadowRowTop;
    for (var i = 0; i < n; i++) {
      final src = GroundAtmosphereAtlas.cloudShadow(i);
      final x = ((i * 197 + 61 * (i % 2) + o) % shadowPeriod) - src.width;
      if (x >= 360 || x + src.width <= 0) continue;
      final y = top + ((i * 5) % (span.round() + 1));
      final h = (src.height * GroundAtmosphereAtlas.shadowSquash).roundToDouble();
      c.drawImageRect(
        image,
        src,
        Rect.fromLTWH(x.toDouble(), y, src.width, h),
        _paint,
      );
    }
  }

  final Paint _smoke = Paint()
    ..isAntiAlias = false
    ..filterQuality = FilterQuality.none;
  int _smokeKey = 0;

  /// Paints a shared smoke sprite [src] (smokeDrift / smokeWall) into
  /// [dst] (rounded to whole units), tinted with [tint] (srcATop at 50%,
  /// as the metadata says) at [opacity] times its baked alpha.
  void paintSmoke(Canvas c, Rect src, Rect dst,
      {required double opacity, required Color tint, bool mirror = false}) {
    if (opacity <= 0) return;
    final key = tint.toARGB32();
    if (key != _smokeKey) {
      _smokeKey = key;
      _smoke.colorFilter =
          ColorFilter.mode(tint.withValues(alpha: .5), BlendMode.srcATop);
    }
    _smoke.color = Color.fromRGBO(255, 255, 255, opacity.clamp(0.0, 1.0));
    final d = Rect.fromLTWH(dst.left.roundToDouble(), dst.top.roundToDouble(),
        dst.width.roundToDouble(), dst.height.roundToDouble());
    if (mirror) {
      c.save();
      c.translate(d.right, d.top);
      c.scale(-1, 1);
      c.drawImageRect(image, src, Rect.fromLTWH(0, 0, d.width, d.height), _smoke);
      c.restore();
    } else {
      c.drawImageRect(image, src, d, _smoke);
    }
  }
}

/// Depth fog on ground units (plan/ground-atmosphere.md §2): a unit's body
/// colour mixes toward the sector's fog tint by [GroundAtmosphereAtlas.fogMix]
/// on top of the existing depth light; emissive pixels (eyes, lights, flames)
/// fog at half rate, so the far murk shows a unit's light pattern before its
/// shape (the ground's version of the air creatures' staged reveal). Threat
/// units cap at [GroundAtmosphereAtlas.threatCap]; telegraph tells, launch
/// flashes and hit flashes are never tinted; inside the lane below its top
/// row the mix stays at or under the lane cap. Presentation only.
abstract final class GroundFog {
  /// Steps of the mix (stepped like the art, and a small filter cache).
  static const steps = 32;

  /// The fog mix of a body at depth [z] standing at screen ([x], [y]),
  /// quantised down to [steps] (never past a cap).
  static double unitMix(double z, {bool threat = false, double? x, double? y}) {
    var m = GroundAtmosphereAtlas.fogMix(z, threat: threat);
    if (x != null &&
        y != null &&
        y >= GroundAtmosphereAtlas.laneTop &&
        x >= GroundAtmosphereAtlas.laneLeft &&
        x <= GroundAtmosphereAtlas.laneRight) {
      m = math.min(m, GroundAtmosphereAtlas.laneCap);
    }
    return (m * steps).floor() / steps;
  }

  /// The mix an emissive pixel gets for body mix [mix].
  static double emissive(double mix) =>
      ((mix * GroundAtmosphereAtlas.emissiveRate) * steps).floor() / steps;

  /// The scene's fog tint for [environment] (a cross-fade between sectors
  /// while travelling).
  static Color tintFor(double environment) =>
      blend(GroundAtmosphereAtlas.fogTint, environment);

  /// The scene's smoke tint for [environment].
  static Color smokeFor(double environment) =>
      blend(GroundAtmosphereAtlas.smokeTint, environment);

  /// Per-sector colour [table] (ARGB) blended for [environment].
  static Color blend(List<int> table, double environment) {
    var r = 0.0, g = 0.0, b = 0.0;
    for (final (s, w) in GroundAtmosphereArt.sectorWeights(environment)) {
      final c = Color(table[s]);
      r += c.r * w;
      g += c.g * w;
      b += c.b * w;
    }
    return Color.from(alpha: 1, red: r, green: g, blue: b);
  }

  /// The 4x5 matrix: rgb x [light] x (1 - [mix]) + [tint] x [mix]; alpha
  /// unchanged.
  static List<double> matrix(double light, double mix, Color tint) {
    final k = light * (1 - mix);
    return [
      k, 0, 0, 0, tint.r * 255 * mix, //
      0, k, 0, 0, tint.g * 255 * mix,
      0, 0, k, 0, tint.b * 255 * mix,
      0, 0, 0, 1, 0,
    ];
  }

  static final _cache = <int, ColorFilter>{};
  static int _tintKey = 0;

  /// A cached colour filter for [matrix] (light in 1/64 steps).
  static ColorFilter filter(double light, double mix, Color tint) {
    final key = tint.toARGB32();
    if (key != _tintKey) {
      _cache.clear();
      _tintKey = key;
    }
    final l = (light.clamp(0.0, 1.0) * 64).round();
    final m = (mix.clamp(0.0, 1.0) * steps).round();
    return _cache[l * 64 + m] ??=
        ColorFilter.matrix(matrix(l / 64, m / steps, tint));
  }
}

/// Battlefield smoke from the packed `smokeDrift` / `smokeWall` sprites
/// (plan/ground-atmosphere.md §3): world-locked over wrecks, burning wreck
/// lines and skirmish fire, tinted with the sector's smoke tint, kept under
/// the lane cap. Presentation only.
abstract final class GroundSmoke {
  /// Seconds a smokeDrift puff lives (dense frame 0 to thin frame 5).
  static const puffLife = 2.4;

  /// Rise in arena units per second and sway amplitude (plan §3).
  static const rise = 4.0, sway = 2.0;

  /// Whether screen rect [r] reaches into the lane below its top row.
  static bool inLane(Rect r) =>
      r.bottom > GroundAtmosphereAtlas.laneTop &&
      r.right > GroundAtmosphereAtlas.laneLeft &&
      r.left < GroundAtmosphereAtlas.laneRight;

  /// Opacity of a drift puff at [r] for wanted opacity [a]: within the
  /// plan's range, at most the lane cap inside the lane.
  static double driftOpacity(Rect r, double a) {
    final o = a.clamp(0.0, GroundAtmosphereAtlas.smokeDriftMax);
    return inLane(r) ? math.min(o, GroundAtmosphereAtlas.smokeLaneMax) : o;
  }
}
