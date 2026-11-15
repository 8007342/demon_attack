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
/// Presentation only: it reads the fog clock, the ship's x, the scene's
/// environment and the skirmish tide, never writes the model.
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

  /// Lateral offset in whole arena units: drift with the fog clock plus
  /// parallax against the ship's offset from the centre.
  static int offset(GroundAtmosphereLayer l, double time, double shipX) =>
      (l.drift * time - (shipX - 180) * l.parallax).round();

  /// Paints tiled band [l] across the 360-unit arena column at its row.
  void paintBand(
    Canvas c,
    GroundAtmosphereLayer l, {
    required double time,
    required double shipX,
    required double environment,
    double opacity = 1,
  }) {
    final a = (l.opacity * opacity).clamp(0.0, 1.0);
    if (a <= 0) return;
    const w = GroundAtmosphereAtlas.width;
    final u0 = (-offset(l, time, shipX)) % w;
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
    required double shipX,
    double opacity = 1,
  }) {
    final a = (l.opacity * opacity).clamp(0.0, 1.0);
    if (a <= 0) return;
    _paint.color = Color.fromRGBO(255, 255, 255, a);
    final o = offset(l, time, shipX);
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
}
