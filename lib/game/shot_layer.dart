// phone-performance §6 (openspec/changes/phone-performance): how bullets are
// drawn. Positions, speeds and fire rates are the model's (fire-rate-tune
// owns those); this layer only decides where and how a shot is shown.
//
// 1. Interpolation: the model steps at a fixed 1/60 s, so a frame can land
//    up to one step after the last one. Shots fly straight at a constant
//    velocity, so each is drawn where it is *now*: its position plus its
//    velocity times the time banked toward the next step
//    (ArcadeModel.stepRemainder). On 90 or 120 Hz displays, and on uneven
//    frames, the stream no longer moves 0-1-2 steps a frame.
// 2. Motion smear: a fast shot leaves a faint streak behind it, as long as
//    its travel in one display frame (sample-and-hold blur done on
//    purpose), so the eye reads continuous motion instead of a strobe.
// 3. Batching: every shot sprite is one drawAtlas call, and every streak
//    and wake of one colour is one path, instead of one to four draw calls
//    per shot.
import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'model.dart';
import 'ship_painter.dart';

const _mint = Color(0xFF70F5D5);
const _violet = Color(0xFFBDA7FF);
const _gold = Color(0xFFF4CA79);

class ShotLayer {
  /// A shot at least this fast (arena px/s) gets a motion smear.
  static const smearSpeed = 200.0;

  /// The smear never runs longer than this behind the sprite (arena px);
  /// fire-rate-tune: 16 (was 14), a player shot's jump at 30 Hz.
  static const smearMax = 16.0;

  /// The smear's opacity at the sprite, fading to none at its end.
  static const smearAlpha = .3;

  /// Half a shot sprite's body length: the smear starts under it.
  static const _body = 4.0;

  /// Draw calls issued last frame (tests: the regression gate).
  int lastCalls = 0;

  final Paint _sprite = Paint()
    ..isAntiAlias = false
    ..filterQuality = FilterQuality.none;
  final Paint _fill = Paint()..isAntiAlias = false;
  final List<RSTransform> _xforms = [];
  final List<Rect> _rects = [];
  final Map<int, Path> _paths = {};

  /// The shot's drawn position: its model position advanced by the time
  /// banked toward the next step. [lead] is 0 when the model isn't moving
  /// shots this frame.
  static Offset drawn(Shot s, double lead, double hostileRate) => Offset(
    // --- crosswind: the wind's drift and tailwind step move it too.
    (s.x + (s.vx * (s.hostile ? hostileRate : 1) + s.windVx) * lead)
        .roundToDouble(),
    (s.y + (s.vy + s.windVy) * lead).roundToDouble(),
  );

  /// Seconds to advance drawn shots: the model's banked step time while it
  /// is in play, else 0 (a paused or ended run shows them where they are).
  static double leadOf(ArcadeModel m) =>
      m.mode == RunMode.playing ? m.stepRemainder : 0;

  void paint(
    Canvas c,
    ArcadeModel m,
    ShipPainter ship, {
    double frameInterval = 1 / 60,
    bool smear = true,
  }) {
    lastCalls = 0;
    if (m.shots.isEmpty) return;
    final lead = leadOf(m);
    final rate = m.policy.hostileRate;
    for (final p in _paths.values) {
      p.reset();
    }
    void rect(Color color, Rect r) =>
        (_paths[color.toARGB32()] ??= Path()).addRect(r);

    final image = ship.image;
    _xforms.clear();
    _rects.clear();
    const k = ShipPainter.size / ShipPainter.cell;
    const half = ShipPainter.size / 2;
    for (final s in m.shots) {
      final at = drawn(s, lead, rate);
      final x = at.dx, y = at.dy;
      // Stepped pixel angled plasma wake/tail for slung or spread shots.
      if (!s.hostile && s.vx.abs() > 4) {
        final wakeDx = (-s.vx * 0.025).clamp(-6.0, 6.0);
        final wake = s.kind == ShotKind.powerful || s.damage > 1
            ? _gold
            : _mint;
        for (var step = 1; step <= 3; step++) {
          final f = step / 3.0;
          rect(
            wake.withValues(alpha: (0.55 - step * 0.14).clamp(0.1, 0.6)),
            Rect.fromLTWH(
              x + (wakeDx * f - 1).roundToDouble(),
              y + (4 + step * 2).toDouble(),
              2,
              2,
            ),
          );
        }
      }
      if (smear) _smear(s, x, y, rate, frameInterval, rect);
      if (image == null) {
        _blocks(s, x, y, rect);
        continue;
      }
      final col = ShipPainter.shotColumn(m, s) + ShipPainter.shotFrame(s);
      _xforms.add(RSTransform(k, 0, x - half, y - half));
      _rects.add(
        Rect.fromLTWH(
          col * ShipPainter.cell,
          ShipPainter.shotRow * ShipPainter.cell,
          ShipPainter.cell,
          ShipPainter.cell,
        ),
      );
    }
    for (final MapEntry(:key, :value) in _paths.entries) {
      if (value.getBounds().isEmpty) continue;
      _fill.color = Color(key);
      c.drawPath(value, _fill);
      lastCalls++;
    }
    if (image != null && _xforms.isNotEmpty) {
      c.drawAtlas(image, _xforms, _rects, null, null, null, _sprite);
      lastCalls++;
    }
  }

  /// A streak behind a fast shot: two stepped 2 px segments (pixel art, no
  /// anti-aliasing), the near one brighter, covering one display frame's
  /// travel.
  void _smear(
    Shot s,
    double x,
    double y,
    double rate,
    double interval,
    void Function(Color, Rect) rect,
  ) {
    final vx = s.vx * (s.hostile ? rate : 1) + s.windVx, vy = s.vy + s.windVy;
    final speed = math.sqrt(vx * vx + vy * vy);
    if (speed < smearSpeed) return;
    final len = math.min(smearMax, speed * interval).roundToDouble();
    if (len < 2) return;
    final ux = -vx / speed, uy = -vy / speed;
    final color = _smearColor(s);
    final w = s.hostile ? 3.0 : 2.0;
    for (var seg = 0; seg < 2; seg++) {
      final from = _body + len * seg / 2, to = _body + len * (seg + 1) / 2;
      final cx = x + ux * (from + to) / 2, cy = y + uy * (from + to) / 2;
      final a = smearAlpha * (seg == 0 ? 1 : .5);
      // Mostly vertical: a 2 px wide bar along y, nudged along x.
      rect(
        color.withValues(alpha: a),
        Rect.fromCenter(
          center: Offset(cx.roundToDouble(), cy.roundToDouble()),
          width: w,
          height: (to - from).roundToDouble().clamp(1.0, smearMax),
        ),
      );
    }
  }

  static Color _smearColor(Shot s) {
    if (s.hostile) {
      return s.kind == ShotKind.sentinel
          ? const Color(0xFFFF4C70)
          : const Color(0xFFFF8676);
    }
    if (s.kind == ShotKind.large) return s.damage > 1 ? _gold : _violet;
    if (s.kind == ShotKind.powerful) return _gold;
    return _mint;
  }

  /// The atlas-less fallback (tests without art): the original blocks.
  static void _blocks(
    Shot s,
    double x,
    double y,
    void Function(Color, Rect) rect,
  ) {
    void block(double dx, double dy, double w, double h, Color color) =>
        rect(color, Rect.fromLTWH(x + dx, y + dy, w, h));
    if (s.kind == ShotKind.sentinel) {
      // Fast hostile bolts have a forked red head and an amber central spine.
      block(-2, -7, 4, 11, const Color(0xFFFF4C70));
      block(-4, -2, 2, 6, const Color(0xFFFF8676));
      block(2, -2, 2, 6, const Color(0xFFFF8676));
      block(-1, -4, 2, 10, const Color(0xFFFFE3AF));
      block(-1, 6, 2, 2, const Color(0xFFFF4C70));
    } else if (s.kind == ShotKind.large) {
      final rim = s.damage > 1 ? _gold : _violet;
      block(-3, -5, 6, 10, rim);
      block(-5, -2, 10, 5, rim);
      block(-2, -7, 4, 2, const Color(0xFFFFF5C9));
      block(-2, -2, 4, 5, const Color(0xFFFFF5C9));
      block(-1, 5, 2, 4, _mint);
    } else if (s.kind == ShotKind.powerful) {
      block(-2, -5, 4, 10, _gold);
      block(-1, -7, 2, 10, const Color(0xFFFFF5C9));
      block(-3, 3, 6, 2, _gold);
      block(-1, 5, 2, 4, _mint);
    } else if (s.hostile) {
      block(-2, -3, 5, 7, const Color(0xFFFF8676));
      block(-1, -2, 2, 3, const Color(0xFFFFE3AF));
    } else {
      block(-1, -5, 2, 10, _mint);
      block(-2, 4, 4, 5, _mint.withValues(alpha: .2));
    }
  }
}
