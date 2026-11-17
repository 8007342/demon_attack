// --- crosswind: the kites (openspec/changes/crosswind design §6).
//
// Each kite is a sprite from assets/images/wind-kites.png (tools/wind_kites:
// the studio's SDXL + pixel-art-xl + LayerDiffuse picks, finished on the
// CPU), banked by its speed across the wind, with a ribbon tail drawn as
// one line batch that streams down-wind. A popped kite shows its torn frame
// with a few scraps, fading. The tally: one pip per kite down, top left
// under the windsock. Reduced motion: no tail wave, no scraps.
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui';

import '../../model.dart';
import '../bonus_painters.dart';
import 'wind_kites_atlas.dart';

class CrosswindPainter extends BonusPainter {
  const CrosswindPainter();

  /// The atlas, loaded by the scene (null: the drawn fallback).
  static Image? image;

  static const ribbon = [Color(0xFFFFB070), Color(0xFFB8F0D8)];
  static const gold = Color(0xFFFFD27A);

  static final _tail = Float32List(CrosswindMechanic.maxAlive * 4 * 6 * 2);
  static final _line = Paint()
    ..isAntiAlias = false
    ..strokeWidth = 1;
  static final _sprite = Paint()
    ..isAntiAlias = false
    ..filterQuality = FilterQuality.none;

  @override
  void under(Canvas canvas, ArcadeModel model, double time) {
    final m = model.bonusMechanic;
    if (m is! CrosswindMechanic) return;
    final reduced = model.reducedMotion;
    for (final species in [0, 1]) {
      var n = 0;
      for (final k in m.kites) {
        if (k.species != species || k.popped != null) continue;
        n = _tailOf(k, n, time, reduced, model.windDrift);
      }
      if (n > 0) {
        _line.color = ribbon[species].withValues(alpha: .75);
        canvas.drawRawPoints(
          PointMode.lines,
          Float32List.sublistView(_tail, 0, n * 4),
          _line,
        );
      }
    }
    for (final k in m.kites) {
      _kite(canvas, k, reduced);
    }
  }

  /// Six segments trailing from the kite's foot, down-wind and down,
  /// waving. Returns the new segment count.
  int _tailOf(Kite k, int n, double time, bool reduced, double drift) {
    if ((n + 6) * 4 > _tail.length) return n;
    var x = k.x, y = k.y + k.halfH;
    final lean = (-drift / 70).clamp(-1.0, 1.0);
    for (var s = 0; s < 6; s++) {
      final wave = reduced ? 0.0 : math.sin(time * 7 + k.phase + s * .9) * 2;
      final nx = x + lean * 3 + wave * .5, ny = y + 3.2;
      _tail
        ..[n * 4] = x.roundToDouble()
        ..[n * 4 + 1] = y.roundToDouble()
        ..[n * 4 + 2] = (nx + wave).roundToDouble()
        ..[n * 4 + 3] = ny.roundToDouble();
      n++;
      x = nx + wave;
      y = ny;
    }
    return n;
  }

  void _kite(Canvas canvas, Kite k, bool reduced) {
    final popped = k.popped;
    final fade = popped == null
        ? 1.0
        : (1 - popped / CrosswindMechanic.popLife).clamp(0.0, 1.0);
    final img = image;
    final frame = popped != null
        ? WindKitesAtlas.tornFrame
        : WindKitesAtlas.bankFrame(k.bankDeg);
    final at = Offset(k.x.roundToDouble(), k.y.roundToDouble());
    if (img != null) {
      final src = WindKitesAtlas.cell(k.species, frame);
      _sprite.color = Color.fromRGBO(255, 255, 255, fade);
      canvas.drawImageRect(
        img,
        src,
        Rect.fromCenter(center: at, width: src.width, height: src.height),
        _sprite,
      );
    } else {
      // The drawn fallback: a diamond in the species' ribbon colour.
      final p = Path()
        ..moveTo(at.dx, at.dy - k.halfH)
        ..lineTo(at.dx + k.halfW, at.dy)
        ..lineTo(at.dx, at.dy + k.halfH)
        ..lineTo(at.dx - k.halfW, at.dy)
        ..close();
      canvas.drawPath(
        p,
        Paint()..color = ribbon[k.species].withValues(alpha: fade),
      );
    }
    if (popped != null && !reduced) {
      // Scraps flung out and falling.
      final paint = Paint()..color = ribbon[k.species].withValues(alpha: fade);
      for (var i = 0; i < 6; i++) {
        final a = i * math.pi / 3 + k.phase;
        final r = 6 + 26 * popped;
        canvas.drawRect(
          Rect.fromLTWH(
            (at.dx + math.cos(a) * r).roundToDouble(),
            (at.dy + math.sin(a) * r + 30 * popped * popped).roundToDouble(),
            2,
            2,
          ),
          paint,
        );
      }
    }
  }

  @override
  void over(Canvas canvas, ArcadeModel model, double time) {
    final m = model.bonusMechanic;
    if (m is! CrosswindMechanic) return;
    // The tally: a gold pip per kite down, a dim one per kite that got
    // away, under the windsock.
    final paint = Paint()..isAntiAlias = false;
    var x = 8.0;
    for (var i = 0; i < m.popped + m.escaped && i < 40; i++) {
      paint.color = i < m.popped ? gold : const Color(0x66B0B8C8);
      canvas.drawRect(Rect.fromLTWH(x, 50, 3, 3), paint);
      x += 5;
    }
  }
}
