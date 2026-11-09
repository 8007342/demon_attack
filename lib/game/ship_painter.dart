import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import 'model.dart';

/// Draws the player ship, its weapon modules, muzzle flashes, power-up
/// transitions, the shield bubble and every projectile from
/// `assets/images/ship-weapons.png` (tools/generate_ship_sprites.py).
///
/// Each 64x64 cell is a full layer centred on the ship and drawn at 48x48
/// arena units. Wing cannons are authored on the left and mirrored for the
/// right. Everything here reads the model; nothing writes to it.
class ShipPainter {
  ui.Image? image;

  static const double cell = 64, size = 48;
  static const int hullRow = 0, shotRow = 6;
  static const rows = {
    Power.spread: 1,
    Power.rapid: 2,
    Power.shield: 3,
    Power.powerful: 4,
    Power.large: 5,
  };

  /// Seconds a freshly collected module plays its deploy transition.
  static const double deploySeconds = 0.24;

  bool get ready => image != null;

  final Paint _paint = Paint()
    ..isAntiAlias = false
    ..filterQuality = FilterQuality.none;

  void layer(
    Canvas c,
    int row,
    int col,
    Offset center, {
    bool mirror = false,
    double opacity = 1,
    double dy = 0,
    double scale = 1,
  }) {
    final img = image;
    if (img == null) return;
    _paint.color = Colors.white.withValues(alpha: opacity);
    final src = Rect.fromLTWH(col * cell, row * cell, cell, cell);
    final s = size * scale;
    if (mirror) {
      c.save();
      c.translate(center.dx, center.dy + dy);
      c.scale(-1, 1);
      c.drawImageRect(
        img,
        src,
        Rect.fromCenter(center: Offset.zero, width: s, height: s),
        _paint,
      );
      c.restore();
    } else {
      c.drawImageRect(
        img,
        src,
        Rect.fromCenter(
          center: center.translate(0, dy),
          width: s,
          height: s,
        ),
        _paint,
      );
    }
  }

  int _wear(ArcadeModel m, Power p) {
    final left = m.timeLeft(p);
    if (left > ArcadeModel.powerDuration * 0.5) return 0;
    if (left > 2.5) return 1;
    // Overheating: flicker between worn and glowing-critical plating.
    return (m.clock * 12).floor() % 2 == 0 ? 2 : 1;
  }

  double _deploy(ArcadeModel m, Power p) =>
      ArcadeModel.powerDuration - m.timeLeft(p);

  /// 1 right after a volley, falling to 0 over the recoil duration.
  double _kick(double seconds) =>
      (seconds / ArcadeModel.wingRecoilDuration).clamp(0.0, 1.0);

  int _recoilCol(double k) => k > .66 ? 3 : (k > .33 ? 4 : 5);
  int _flashFrame(double k) => ((1 - k) * 4).floor().clamp(0, 3);

  /// Draws the composed ship at [center] (caller applies bank transform).
  void paintShip(Canvas c, ArcadeModel m, Offset center) {
    final at = Offset(center.dx.roundToDouble(), center.dy.roundToDouble());
    layer(c, hullRow, 2 + (m.clock * 14).floor() % 4, at);
    final hit = m.invulnerable > 2.25;
    layer(c, hullRow, hit ? 1 : 0, at);

    final volley = _kick(
      [m.noseFlash, m.wingRecoil[0], m.wingRecoil[1]].reduce(
        (a, b) => a > b ? a : b,
      ),
    );
    final wingGun = m.wingGun;

    if (m.hasPower(Power.shield)) _module(c, m, Power.shield, at, 0);
    for (final p in const [Power.spread, Power.large]) {
      if (m.hasPower(p)) _module(c, m, p, at, volley);
    }
    for (final p in const [Power.rapid, Power.powerful]) {
      if (!m.hasPower(p)) continue;
      if (p == wingGun) {
        for (final side in const [0, 1]) {
          _module(c, m, p, at, _kick(m.wingRecoil[side]), mirror: side == 1);
        }
      } else {
        _module(c, m, p, at, 0);
      }
    }

    // Single shooter: nose cannon flash, distinct from the wing kick.
    final nose = _kick(m.noseFlash);
    if (nose > 0) layer(c, hullRow, 6 + _flashFrame(nose), at);
  }

  void _module(
    Canvas c,
    ArcadeModel m,
    Power p,
    Offset at,
    double kick, {
    bool mirror = false,
  }) {
    final row = rows[p]!;
    final deploy = _deploy(m, p);
    if (deploy < deploySeconds) {
      final f = (deploy / deploySeconds * 4).floor().clamp(0, 3);
      layer(c, row, 10 + f, at, mirror: mirror);
      return;
    }
    final wear = _wear(m, p);
    final firing = kick > 0 && p != Power.shield;
    layer(c, row, firing ? _recoilCol(kick) : wear, at, mirror: mirror);
    if (!firing && wear == 2) layer(c, row, 15, at, mirror: mirror);
    if (firing) layer(c, row, 6 + _flashFrame(kick), at, mirror: mirror);
  }

  /// Hex-segment force bubble: healthy mint, degrading gold, critical red.
  void paintShield(Canvas c, ArcadeModel m, Offset center) {
    final t = m.timeLeft(Power.shield);
    if (t <= 0) return;
    final int col;
    if (t >= 4.5) {
      col = 3 + (m.clock * 6).floor() % 3;
    } else if (t >= 2.0) {
      col = 6 + (m.clock * 8).floor() % 2;
    } else {
      col = 8 + (m.clock * 16).floor() % 2;
    }
    layer(c, rows[Power.shield]!, col, center, opacity: .85);
  }

  /// A spent module tumbling away (caller translates and rotates).
  void paintPart(Canvas c, FallingPart part) {
    final row = rows[part.power];
    if (row == null) return;
    layer(c, row, 14, Offset.zero, mirror: part.vx > 0);
  }

  /// Projectile sprite; returns false if the atlas is not loaded.
  bool paintShot(Canvas c, ArcadeModel m, Shot s, int index) {
    if (image == null) return false;
    final frame = ((m.clock * 12).floor() + index) % 2;
    final int col;
    if (s.hostile) {
      col = s.kind == ShotKind.sentinel ? 12 : 10;
    } else if (s.kind == ShotKind.large) {
      col = 6;
    } else if (s.kind == ShotKind.powerful) {
      col = 4;
    } else if (s.vy == -370) {
      col = 8; // spread's angled pair
    } else if (m.hasPower(Power.rapid)) {
      col = 2;
    } else {
      col = 0;
    }
    layer(
      c,
      shotRow,
      col + frame,
      Offset(s.x.roundToDouble(), s.y.roundToDouble()),
    );
    return true;
  }
}
