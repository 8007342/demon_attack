import 'dart:math' as math;
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
  static const int hullRow = 0, shotRow = 6, homingRow = 7;
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
  ///
  /// [live] false is the cinematic pose: the same equipped modules, at rest.
  /// Weapon timers do not tick outside combat, so a muzzle flash, hit frame
  /// or deploy frame caught when combat ended would otherwise hold for the
  /// whole cutscene.
  void paintShip(Canvas c, ArcadeModel m, Offset center, {bool live = true}) {
    final at = Offset(center.dx.roundToDouble(), center.dy.roundToDouble());
    layer(c, hullRow, 2 + (m.clock * 14).floor() % 4, at);
    final hit = live && m.invulnerable > 2.25;
    layer(c, hullRow, hit ? 1 : 0, at);

    double kick(double seconds) => live ? _kick(seconds) : 0;
    final volley = kick(
      [m.noseFlash, m.wingRecoil[0], m.wingRecoil[1]].reduce(
        (a, b) => a > b ? a : b,
      ),
    );
    final wingGun = m.wingGun;

    if (m.hasPower(Power.shield)) {
      _module(c, m, Power.shield, at, 0, settled: !live);
    }
    for (final p in const [Power.spread, Power.large]) {
      if (m.hasPower(p)) _module(c, m, p, at, volley, settled: !live);
    }
    for (final p in const [Power.rapid, Power.powerful]) {
      if (!m.hasPower(p)) continue;
      if (p == wingGun) {
        for (final side in const [0, 1]) {
          _module(
            c,
            m,
            p,
            at,
            kick(m.wingRecoil[side]),
            mirror: side == 1,
            settled: !live,
          );
        }
      } else {
        _module(c, m, p, at, 0, settled: !live);
      }
    }

    // Single shooter: nose cannon flash, distinct from the wing kick.
    final nose = kick(m.noseFlash);
    if (nose > 0) layer(c, hullRow, 6 + _flashFrame(nose), at);
    paintHomingRack(c, m, at, live: live);
  }

  // --- homing missiles (row 7 of ship-weapons.png) ---

  bool get _hasHomingRow => (image?.height ?? 0) >= (homingRow + 1) * cell;

  /// Wing pylons with the missiles still loaded; a launch flash when one
  /// leaves. Combines with every other module and the shield.
  void paintHomingRack(Canvas c, ArcadeModel m, Offset at, {bool live = true}) {
    final salvo = m.ground.salvo;
    if (!salvo.busy || !_hasHomingRow) return;
    final loaded = salvo.loaded.clamp(0, 3);
    layer(c, homingRow, 3 - loaded, at);
    final h = salvo.active;
    if (live && h != null && h.age < .12) {
      layer(c, homingRow, 8 + (h.age / .06).floor().clamp(0, 1), at);
    }
  }

  /// A homing missile in flight (cyan exhaust), turned along its heading.
  void paintHomingMissile(
    Canvas c,
    HomingMissile h,
    double clock, {
    double scale = 1,
  }) {
    final at = Offset(h.x.roundToDouble(), h.y.roundToDouble());
    if (!_hasHomingRow) {
      final p = Paint()..isAntiAlias = false;
      c.drawRect(Rect.fromCenter(center: at, width: 3, height: 8), p..color = const Color(0xFFD8E2FF));
      c.drawRect(Rect.fromLTWH(at.dx - 1, at.dy + 4, 2, 4), p..color = const Color(0xFF6EDCFF));
      return;
    }
    c.save();
    c.translate(at.dx, at.dy);
    // Quarter-step headings keep the pixel grid readable.
    final steps = (h.heading / (math.pi / 8)).round();
    c.rotate(steps * math.pi / 8);
    layer(
      c,
      homingRow,
      4 + (clock * 16).floor() % 2,
      Offset.zero,
      scale: 1.3 * scale,
    );
    c.restore();
  }

  /// Lock-on reticle on the current homing target.
  void paintReticle(Canvas c, Offset at, double clock, {double scale = 1}) {
    if (!_hasHomingRow) return;
    layer(c, homingRow, 6 + (clock * 6).floor() % 2,
        Offset(at.dx.roundToDouble(), at.dy.roundToDouble()), scale: scale);
  }

  /// The homing pickup badge (drawn at [width] arena units).
  void paintHomingBadge(Canvas c, Offset at, double width) {
    if (!_hasHomingRow) return;
    layer(c, homingRow, 15, at, scale: width / size);
  }

  void _module(
    Canvas c,
    ArcadeModel m,
    Power p,
    Offset at,
    double kick, {
    bool mirror = false,
    bool settled = false,
  }) {
    final row = rows[p]!;
    final deploy = _deploy(m, p);
    if (!settled && deploy < deploySeconds) {
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
