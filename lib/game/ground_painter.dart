import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import 'ground_atlas.dart';
import 'model.dart';
import 'ship_painter.dart';

/// Draws the ground war from `assets/images/ground-forces.png`
/// (tools/ground_forces_assets.py) and the homing missiles from the ship
/// atlas. Presentation only: it reads [ArcadeModel.ground], never writes.
///
/// Layers: [paintGround] goes between the flyover background and the air
/// combat (units, allies, tracers, wrecks: things standing on the ground);
/// [paintAir] goes above the air combat (ground missiles coming at the
/// camera, homing missiles, lock-on reticle, pickups).
class GroundPainter {
  ui.Image? image;

  static const _warm = Color(0xFFFF8676), _hot = Color(0xFFFFD594);
  static const _mint = Color(0xFF70F5D5), _cyan = Color(0xFF6EDCFF);

  final Paint _paint = Paint()
    ..isAntiAlias = false
    ..filterQuality = FilterQuality.none;
  final Paint _block = Paint()..isAntiAlias = false;

  /// Brightness: subdued in the haze at the horizon, full on the near ground
  /// (the flyover's own fog runs from the horizon to about y = 330).
  static double depthLight(double z) => (.38 +
          .62 *
              ((GroundTuning.spawnZ - z) /
                      (GroundTuning.spawnZ - GroundTuning.fireZ))
                  .clamp(0.0, 1.0))
      .clamp(0.0, 1.0);

  void _cell(
    Canvas c,
    int row,
    int col,
    double cx,
    double bottom,
    double scale, {
    bool mirror = false,
    double light = 1,
    double opacity = 1,
  }) {
    final img = image;
    if (img == null) return;
    final w = GroundAtlas.cellW * scale, h = GroundAtlas.cellH * scale;
    final v = (255 * light).round().clamp(0, 255);
    _paint.color = Color.fromARGB((255 * opacity).round().clamp(0, 255), v, v, v);
    _paint.colorFilter = light < .999
        ? ColorFilter.mode(Color.fromARGB(255, v, v, v), BlendMode.modulate)
        : null;
    final src = Rect.fromLTWH(
      col * GroundAtlas.cellW * 1.0,
      row * GroundAtlas.cellH * 1.0,
      GroundAtlas.cellW * 1.0,
      GroundAtlas.cellH * 1.0,
    );
    final left = (cx - w / 2).roundToDouble(), top = (bottom - h).roundToDouble();
    if (mirror) {
      c.save();
      c.translate(left + w, top);
      c.scale(-1, 1);
      c.drawImageRect(img, src, Rect.fromLTWH(0, 0, w, h), _paint);
      c.restore();
    } else {
      c.drawImageRect(img, src, Rect.fromLTWH(left, top, w, h), _paint);
    }
  }

  void _px(Canvas c, double x, double y, double s, Color color) {
    _block.color = color;
    c.drawRect(
      Rect.fromLTWH(x.roundToDouble(), y.roundToDouble(), s, s),
      _block,
    );
  }

  /// Things on the ground, far to near.
  void paintGround(Canvas c, ArcadeModel m) {
    final g = m.ground;
    if (g.units.isEmpty && g.allies.isEmpty) return;
    final clock = m.visualClock;
    final items = <(double, void Function())>[
      for (final u in g.units) (u.z, () => _unit(c, u, clock)),
      for (final a in g.allies) (a.z, () => _ally(c, a, clock)),
    ]..sort((a, b) => b.$1.compareTo(a.$1));
    for (final item in items) {
      item.$2();
    }
    for (final t in g.tracers) {
      _tracer(c, t);
    }
  }

  void _unit(Canvas c, GroundUnit u, double clock) {
    if (u.y < GroundCamera.horizon + 2) return;
    final s = u.scale;
    final row = GroundAtlas.demonRow(u.sector);
    final mirror = u.side == 1;
    final light = depthLight(u.z);
    if (u.destroyed) {
      final fade = (1 - (u.wreckAge - 3) / 3).clamp(0.0, 1.0);
      _cell(c, GroundAtlas.effectRow, GroundAtlas.scorchCol, u.x, u.y + 2 * s, s,
          light: light, opacity: fade);
      _cell(c, row, GroundAtlas.wreckCol + ((clock * 8).floor() % 2), u.x, u.y, s,
          mirror: mirror, light: light, opacity: fade);
      // Rolling smoke from the hulk.
      for (var k = 0; k < 3; k++) {
        final t = (u.wreckAge * .9 + k / 3) % 1;
        _cell(c, GroundAtlas.effectRow,
            t < .5 ? GroundAtlas.smokeSmallCol : GroundAtlas.smokeLargeCol,
            u.x + (k - 1) * 4 * s + t * 6 * s, u.bodyY - t * 18 * s, s * (.7 + t * .6),
            light: light, opacity: (1 - t) * .8 * fade);
      }
      if (u.wreckAge < .7) {
        final f = (u.wreckAge / .7 * GroundAtlas.explosionFrames)
            .floor()
            .clamp(0, GroundAtlas.explosionFrames - 1);
        _cell(c, GroundAtlas.effectRow, GroundAtlas.explosionCol + f, u.x,
            u.y + 4 * s, s * 1.8);
      }
      return;
    }
    final int col;
    if (u.fireFlash > GroundTuning.fireFlash * .5) {
      col = GroundAtlas.fireCol;
    } else if (u.fireFlash > 0) {
      col = GroundAtlas.postFireCol;
    } else if (u.telegraphing) {
      // Launcher raise, then the glow pulses faster toward launch.
      final p = u.telegraphProgress;
      col = p < .45
          ? GroundAtlas.telegraphCol
          : GroundAtlas.telegraphCol +
                ((clock * (p > .8 ? 16 : 8)).floor().isEven ? 1 : 0);
    } else {
      col = GroundAtlas.moveCol +
          ((clock * 10 + u.id * .37).floor() % GroundAtlas.moveFrames);
    }
    _cell(c, row, col, u.x, u.y, s, mirror: mirror, light: light);
    _climbDust(c, u.pose, u.x, u.y, s, clock + u.id * .37, light); // --- terrain
    if (u.telegraphing) {
      // A warm warning bracket under the launcher: readable at phone size.
      final p = u.telegraphProgress;
      final w = u.width * .55, y = u.y + 2;
      final on = (clock * (p > .8 ? 14 : 7)).floor().isEven;
      final color = on ? _hot : _warm;
      final unit = math.max(2.0, s.roundToDouble());
      for (final sx in const [-1.0, 1.0]) {
        final x = u.x + sx * w - (sx > 0 ? unit : 0);
        _px(c, x, y, unit, color);
        _px(c, x - sx * unit, y, unit, color);
        _px(c, x, y - unit, unit, color);
      }
    }
    if (u.fireFlash > 0) {
      _cell(c, GroundAtlas.effectRow, GroundAtlas.launchFlashCol,
          u.x + (u.side == 0 ? 1 : -1) * u.width * .2, u.bodyY + 4 * s, s * 1.3,
          mirror: mirror);
    }
  }

  void _ally(Canvas c, GroundAlly a, double clock) {
    if (a.y < GroundCamera.horizon + 2) return;
    final s = a.scale;
    final row = GroundAtlas.allyRow(a.sector);
    final mirror = a.side == 0; // allies face their foe, away from the lane
    final light = depthLight(a.z);
    if (a.totalled) {
      // Totalled, never killed: sparking, smoking, limping off to the edge.
      final t = a.retreatAge;
      final hop = ((clock * 9).floor().isEven ? 0.0 : -s).roundToDouble();
      _cell(c, row, GroundAtlas.allyLimpCol + ((clock * 7).floor() % 2), a.x,
          a.y + hop, s, mirror: a.side == 1, light: light);
      for (var k = 0; k < 3; k++) {
        final q = (t * 1.3 + k / 3) % 1;
        _cell(c, GroundAtlas.effectRow,
            q < .5 ? GroundAtlas.smokeSmallCol : GroundAtlas.smokeLargeCol,
            a.x + (a.side == 0 ? 1 : -1) * q * 10 * s, a.bodyY - q * 14 * s,
            s * (.6 + q * .5),
            light: light, opacity: (1 - q) * .75);
      }
      if ((clock * 11).floor() % 3 == 0) {
        _cell(c, GroundAtlas.effectRow, GroundAtlas.tracerCol,
            a.x + ((clock * 37).floor() % 5 - 2) * s, a.bodyY, s * .8);
      }
      if (a.ejects && t < 2.5) {
        final (dx, dy) = a.podOffset;
        _cell(c, row, GroundAtlas.allyPodCol, a.x + dx, a.bodyY + dy, s,
            mirror: a.side == 1);
        _px(c, a.x + dx - 1, a.bodyY + dy + 1, 2, _cyan);
      }
      return;
    }
    final firing = a.fireLeft > GroundTuning.allyTracerEvery - .14;
    final col = a.flash > 0
        ? GroundAtlas.allyHitCol
        : firing
        ? GroundAtlas.allyFireCol + ((clock * 14).floor() % 2)
        : GroundAtlas.allyMoveCol +
              ((clock * 9 + a.id * .31).floor() % GroundAtlas.allyMoveFrames);
    _cell(c, row, col, a.x, a.y, s, mirror: mirror, light: light);
    _climbDust(c, a.pose, a.x, a.y, s, clock + a.id * .31, light); // --- terrain
    if (a.flash > 0) {
      _cell(c, GroundAtlas.effectRow, GroundAtlas.tracerCol, a.x, a.bodyY + 3 * s, s);
    }
    if (a.underAttack && (a.attacker?.calledForHelp ?? false)) {
      // Distress beacon while calling for help (a breakthrough looms): a
      // blinking friendly cyan cross over the ally. Quiet skirmishes the
      // allies are winning show none.
      if ((clock * 3).floor().isEven) {
        final unit = math.max(1.0, (s * .9).roundToDouble());
        final top = a.y - GroundAtlas.cellH * s * .8 - 3 * unit;
        _px(c, a.x - unit / 2, top - unit, unit, _mint);
        _px(c, a.x - unit / 2, top + unit, unit, _mint);
        _px(c, a.x - unit * 1.5, top, unit, _mint);
        _px(c, a.x + unit * .5, top, unit, _mint);
        _px(c, a.x - unit / 2, top, unit, Colors.white);
      }
    }
  }

  // --- terrain: grey dust thrown up behind a unit grinding up a slope
  // (the relief pose comes from the flyover; visual only).
  void _climbDust(Canvas c, GroundPose? pose, double x, double y, double s,
      double clock, double light) {
    final climb = pose?.climb ?? 0;
    if (climb < .1) return;
    final n = climb > .3 ? 3 : 2;
    for (var k = 0; k < n; k++) {
      final q = (clock * 1.6 + k / n) % 1;
      _cell(c, GroundAtlas.effectRow, GroundAtlas.smokeSmallCol,
          x + (k.isEven ? -1 : 1) * (6 + q * 8) * s, y - q * 7 * s, s * (.5 + q * .5),
          light: light * .8, opacity: (1 - q) * .6);
    }
  }

  void _tracer(Canvas c, GroundTracer t) {
    final p = (t.age / GroundTracer.life).clamp(0.0, 1.0);
    final color = t.friendly ? _cyan : _warm;
    // A bright head with a fading streak, then an impact spark.
    for (var k = 0; k < 5; k++) {
      final q = (p - k * .07).clamp(0.0, 1.0);
      _px(c, t.fromX + (t.toX - t.fromX) * q, t.fromY + (t.toY - t.fromY) * q,
          k == 0 ? 2 : 1, k == 0 ? Colors.white : color.withValues(alpha: 1 - k * .18));
    }
    if (p > .75) {
      _cell(c, GroundAtlas.effectRow, GroundAtlas.tracerCol, t.toX,
          t.toY + 6, .7, opacity: 1);
    }
  }

  /// Things in the air above the combat layer.
  void paintAir(Canvas c, ArcadeModel m, ShipPainter ship) {
    final g = m.ground;
    final clock = m.visualClock;
    for (final p in g.pickups) {
      c.drawCircle(Offset(p.x, p.y), 13, Paint()..color = _mint.withValues(alpha: .14));
      ship.paintHomingBadge(c, Offset(p.x, p.y), 36);
    }
    for (final missile in g.missiles) {
      _groundMissile(c, missile, clock);
    }
    final h = g.homing;
    if (h != null) {
      if (h.target != null) {
        final (tx, ty) = m.homingAim(h);
        final size = switch (h.target) {
          final GroundUnit u => (u.width / 30).clamp(.5, 1.4),
          final Demon d => d.isLarge ? 1.4 : .9,
          final Carrier _ => 1.2,
          _ => 1.0,
        };
        ship.paintReticle(c, Offset(tx, ty), clock, scale: size.toDouble());
      }
      // A short cyan exhaust trail behind the missile.
      final speed = math.max(1.0, math.sqrt(h.vx * h.vx + h.vy * h.vy));
      for (var k = 1; k <= 4; k++) {
        _px(c, h.x - h.vx / speed * k * 4 - 1, h.y - h.vy / speed * k * 4 - 1,
            k < 3 ? 2 : 1, _cyan.withValues(alpha: 1 - k * .2));
      }
      ship.paintHomingMissile(c, h, clock);
    }
  }

  void _groundMissile(Canvas c, GroundMissile m, double clock) {
    final img = image;
    // Target marker: where the fixed path crosses the ship's plane.
    if (m.t > .25 && m.t < 1) {
      final on = (clock * (m.t > .7 ? 14 : 7)).floor().isEven;
      if (on) {
        final r = 6 + (1 - m.t) * 14;
        for (final sx in const [-1.0, 1.0]) {
          _px(c, m.targetX + sx * r - 1, ArcadeModel.shipY + 14, 2, _warm);
          _px(c, m.targetX + sx * (r - 3) - 1, ArcadeModel.shipY + 14, 2, _warm);
        }
      }
    }
    // Smoke trail: analytic, from earlier points on the same fixed path.
    for (var k = 6; k >= 1; k--) {
      final t = m.t - k * .055;
      if (t <= 0) continue;
      final x = m.xAt(t), y = m.yAt(t);
      final grow = GroundTuning.missileMinSize +
          (GroundTuning.missileMaxSize - GroundTuning.missileMinSize) * t * t;
      final scale = grow * .55 / 10;
      if (img != null) {
        _cell(c, GroundAtlas.missileRow, GroundAtlas.smokeCol + (k > 3 ? 2 : (k > 1 ? 1 : 0)),
            x, y + GroundAtlas.cellH * scale / 2, scale,
            opacity: (1 - k / 7) * .85);
      } else {
        _px(c, x - 2, y - 2, 4, const Color(0x887A7290));
      }
    }
    if (m.age < .16) {
      final s = GroundCamera.texel(GroundCamera.zOf(math.max(m.y0, GroundCamera.horizon + 20)));
      _cell(c, GroundAtlas.effectRow, GroundAtlas.launchFlashCol, m.x0,
          m.y0 + GroundAtlas.cellH * s * .6, s * 1.1);
    }
    // The warhead: one high-detail cell scaled with nearest-neighbour from
    // small at launch to full size at the ship.
    final scale = m.size / 22;
    final frame = (clock * 16).floor() % 2;
    if (img != null) {
      c.save();
      c.translate(m.x.roundToDouble(), m.y.roundToDouble());
      c.rotate((m.heading * .35 / (math.pi / 16)).round() * (math.pi / 16));
      _cell(c, GroundAtlas.missileRow, GroundAtlas.missileCol + frame, 0,
          GroundAtlas.cellH * scale / 2, scale);
      c.restore();
    } else {
      _block.color = _warm;
      c.drawCircle(Offset(m.x, m.y), m.size / 2, _block);
    }
  }
}
