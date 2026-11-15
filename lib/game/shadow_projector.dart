import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui';

import 'model.dart' show GroundCamera;

/// Terrain-conforming shadows (openspec/changes/terrain-shadows design §2).
///
/// Pure Dart: every caster's shadow is found where the sun ray from the
/// caster meets the visible terrain, then draped over that surface as a
/// 4 x 3 vertex mesh. On flat ground both steps reduce exactly to the
/// legacy placement (a centre and a 0.42-squashed quad), so the shadows
/// that already read well do not move.
///
/// Coordinates are the arena's: screen x, and *flat-ground y* (where a
/// ground point would be drawn without relief; `GroundCamera.yOf(z)`). The
/// design's `zStretch` disappears in that frame: an offset along flat-ground
/// y is exactly the legacy screen offset. Heights ("lift") are in arena
/// units, the visible rise of the surface above flat ground at that point
/// (texel height x `GroundCamera.texel(z)`), the same unit as the caster's
/// altitude.

/// What a shadow can be cast on.
abstract interface class ShadowSurface {
  /// Visible lift (arena units) of the surface above flat ground at screen
  /// [x] and flat-ground y [flatY], before crest occlusion.
  double shadowLift(double x, double flatY);

  /// Visible screen y of the ground point ([x], [flatY]) and whether it is
  /// hidden behind a nearer crest (then y is the crest line).
  (double, bool) shadowDrape(double x, double flatY);
}

/// Flat ground: today's plane.
class FlatShadowSurface implements ShadowSurface {
  const FlatShadowSurface();
  @override
  double shadowLift(double x, double flatY) => 0;
  @override
  (double, bool) shadowDrape(double x, double flatY) => (flatY, false);
}

/// Who casts (design §3).
enum ShadowKind { creature, diver, sentinel, lurk, ship, boss }

/// Flat drawing (today's path) or draped on the relief.
enum ShadowMode { flat, draped }

/// One caster: lateral [x], flat-ground y [groundY] under it (the design's
/// z: `GroundCamera.zOf(groundY)`), altitude [h] (arena units), its
/// silhouette footprint [footprint] (arena units, before the 0.42 ground
/// squash) and [kind].
class ShadowCaster {
  const ShadowCaster(this.x, this.groundY, this.h, this.footprint, this.kind);
  final double x, groundY, h;
  final Size footprint;
  final ShadowKind kind;
  double get z => GroundCamera.zOf(groundY);
}

/// The hit point: flat-ground [flat] point, visible [center] on the
/// surface, and the surface [lift] there (the design's t).
class ShadowHit {
  const ShadowHit(this.flat, this.center, this.lift);
  final Offset flat, center;
  final double lift;
}

abstract final class ShadowProjector {
  /// Sun elevation complement (32°) and the ground-offset scale the swarm
  /// shadows were tuned with.
  static final tanSun = math.tan(32 * math.pi / 180);
  static const offsetScale = .22;

  /// The softness / altitude scale: k = (h − t) / [hMax].
  static const hMax = 300.0;

  /// Vertical squash of the ground seen at a slant (legacy drawAtlas).
  static const squash = .42;

  /// Ground direction of the sun's offset for a flyer at sun azimuth
  /// drift [az] (legacy: x by cos, y by .25 + sin).
  static Offset flyerDir(double az) => Offset(math.cos(az), .25 + math.sin(az));

  /// The ship's fixed offset (legacy: lateral only).
  static const shipDir = Offset(1, 0);

  /// The legacy flat centre of a shadow from [base] at altitude [h].
  static Offset flatCenter(Offset base, double h, Offset dir) {
    final off = h * tanSun * offsetScale;
    return base + dir * off;
  }

  /// The sun ray from a caster over [base] (flat ground point) at [h]
  /// meets [surface]: three fixed-point steps
  /// `p_i = base + (h − t_i)·tanθ·0.22·dir`, `t_{i+1} = lift(p_i)`.
  static ShadowHit hit(
    ShadowSurface surface,
    Offset base,
    double h,
    Offset dir,
  ) {
    var t = 0.0;
    var p = flatCenter(base, h, dir);
    for (var i = 0; i < 3; i++) {
      t = math.min(h, math.max(0.0, surface.shadowLift(p.dx, p.dy)));
      p = flatCenter(base, h - t, dir);
    }
    t = math.min(h, math.max(0.0, surface.shadowLift(p.dx, p.dy)));
    final (y, _) = surface.shadowDrape(p.dx, p.dy);
    return ShadowHit(p, Offset(p.dx, y), t);
  }

  /// Softness 0..1 from the caster's height above the surface it falls on.
  static double softness(double h, double lift) =>
      ((h - lift) / hMax).clamp(0.0, 1.0);

  /// Blur bucket of softness [k] (sharp, medium, soft).
  static int bucketOf(double k) => k < .45 ? 0 : (k < .8 ? 1 : 2);

  /// Drape columns x rows of vertices (3 x 2 cells).
  static const cols = 4, rows = 3;
  static const vertices = cols * rows;
  static const cells = (cols - 1) * (rows - 1);

  /// Writes one draped silhouette into the batch: [w] x [hgt] (screen
  /// units, already squashed) centred on flat point [flat], sampling [src]
  /// of the image. Appends [vertices] positions and texture coordinates at
  /// vertex [v0] and the indices of every cell not wholly hidden at
  /// [i0]; returns the number of indices written.
  static int drape(
    ShadowSurface surface,
    Offset flat,
    double w,
    double hgt,
    Rect src,
    Float32List pos,
    Float32List tex,
    Uint16List idx,
    int v0,
    int i0,
  ) {
    var hiddenMask = 0;
    for (var r = 0; r < rows; r++) {
      final v = r / (rows - 1);
      final fy = flat.dy + (v - .5) * hgt;
      for (var c = 0; c < cols; c++) {
        final u = c / (cols - 1);
        final x = flat.dx + (u - .5) * w;
        final (y, hidden) = surface.shadowDrape(x, fy);
        final k = v0 + r * cols + c;
        pos[k * 2] = x;
        pos[k * 2 + 1] = y;
        tex[k * 2] = src.left + u * src.width;
        tex[k * 2 + 1] = src.top + v * src.height;
        if (hidden) hiddenMask |= 1 << (r * cols + c);
      }
    }
    var n = i0;
    for (var r = 0; r < rows - 1; r++) {
      for (var c = 0; c < cols - 1; c++) {
        final a = r * cols + c, b = a + 1, d = a + cols, e = d + 1;
        final all = (1 << a) | (1 << b) | (1 << d) | (1 << e);
        if (hiddenMask & all == all) continue; // behind a crest: dropped
        idx[n++] = v0 + a;
        idx[n++] = v0 + b;
        idx[n++] = v0 + d;
        idx[n++] = v0 + b;
        idx[n++] = v0 + e;
        idx[n++] = v0 + d;
      }
    }
    return n - i0;
  }
}
