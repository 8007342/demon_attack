import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import 'hatch_emergence.dart';
import 'hatch_emergence_atlas.dart';

/// hatch-emergence (design §4): draws the one-shot emergence frames from
/// `assets/images/hatch-emergence.png` (HatchEmergenceAtlas: a row per
/// species, a column per pose). One drawImageRect per creature or lurker;
/// a clip at the rim while the body is still inside the hatch.
class HatchEmergencePainter {
  ui.Image? image;
  final Paint _p = Paint()
    ..isAntiAlias = false
    ..filterQuality = FilterQuality.none;

  /// Arena units per stored atlas px: the glide frame's span (62 px) drawn
  /// as wide as the combat atlas's glide (60 combat px at 40/64 units).
  static const unitsPerPx = 60 * 40 / 64 / 62;

  /// The glide frames' body centre from the cell origin (stored px): where
  /// the model's own position (the flight sprite's centre) sits, so the
  /// hand-off to the flight sprites does not jump.
  static const glideCentre = Offset(.6, -11);

  /// The hatch's rim line below the hatch centre (units): the slot's widest
  /// point, where a climbing body is cut.
  static const rimY = -3.0;

  /// A lurker or launched claw may overlap the rim by this much (units).
  static const rimOverlap = 1.5;

  /// Draw calls this frame (the budget test reads it).
  int calls = 0;
  void beginFrame() => calls = 0;

  /// Draws [f] of atlas [row]: [hatchAt] is the hatch centre (bent, world),
  /// [modelAt] the creature's own position (null for a lurker), [scale] the
  /// creature's draw scale (the carrier band's floor), [opacity] its alpha.
  void paint(
    Canvas c,
    EmergeFrame f,
    int row,
    Offset hatchAt, {
    Offset? modelAt,
    double scale = 1,
    double opacity = 1,
  }) {
    final img = image;
    if (img == null) return;
    final k = unitsPerPx * scale;
    final rim = hatchAt + Offset(f.dx, rimY - f.hop);
    var at = rim;
    if (modelAt != null && f.toModel > 0) {
      final target = modelAt - glideCentre * k;
      at = Offset.lerp(rim, target, f.toModel)!;
    }
    const cw = HatchEmergenceAtlas.cellWidth,
        ch = HatchEmergenceAtlas.cellHeight;
    final src = Rect.fromLTWH(
      f.pose.index * cw.toDouble(),
      row * ch.toDouble(),
      cw.toDouble(),
      ch.toDouble(),
    );
    final dst = Rect.fromLTWH(
      at.dx - HatchEmergenceAtlas.originX * k,
      at.dy - HatchEmergenceAtlas.originY * k,
      cw * k,
      ch * k,
    );
    c.save();
    if (f.clipped) {
      c.clipRect(
        Rect.fromLTRB(
          dst.left - 4,
          dst.top - 4,
          dst.right + 4,
          hatchAt.dy + rimY + rimOverlap,
        ),
      );
    }
    if (f.flip) {
      c.translate(at.dx, 0);
      c.scale(-1, 1);
      c.translate(-at.dx, 0);
    }
    _p.color = Colors.white.withValues(alpha: opacity.clamp(0.0, 1.0));
    c.drawImageRect(img, src, dst, _p);
    c.restore();
    calls++;
  }
}
