import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

/// Complete independently painted worlds: artwork, moons, orbitals and horizon
/// geometry crossfade together, rather than recoloring a shared planet.
class SectorBackground {
  final List<ui.Image?> images = List.filled(5, null);
  static const colors = [
    Color(0xFF68C9DE),
    Color(0xFFB49AE9),
    Color(0xFFF6916E),
    Color(0xFF79C798),
    Color(0xFFE8787C),
  ];

  void paint(
    Canvas c,
    double environment,
    double time,
    int cycle,
    ui.Image? fallback,
  ) {
    final near = environment.floor().clamp(0, 4);
    final far = math.min(4, near + 1);
    final blend = (environment - near).clamp(0.0, 1.0);
    _layer(c, near, time, cycle, fallback);
    if (far != near && blend > .001) {
      c.saveLayer(
        const Rect.fromLTWH(0, 0, 360, 520),
        Paint()..color = Colors.white.withValues(alpha: blend),
      );
      _layer(c, far, time, cycle, fallback);
      c.restore();
    }
  }

  void _layer(
    Canvas c,
    int sector,
    double time,
    int cycle,
    ui.Image? fallback,
  ) {
    final tint = colors[sector];
    c.drawRect(
      const Rect.fromLTWH(0, 0, 360, 520),
      Paint()..color = const Color(0xFF070B16),
    );
    final image = images[sector] ?? fallback;
    if (image != null) {
      final imageRatio = image.width / image.height;
      const ratio = 360 / 520;
      final source = imageRatio > ratio
          ? Rect.fromLTWH(
              (image.width - image.height * ratio) / 2,
              0,
              image.height * ratio,
              image.height.toDouble(),
            )
          : Rect.fromLTWH(
              0,
              (image.height - image.width / ratio) / 2,
              image.width.toDouble(),
              image.width / ratio,
            );
      c.drawImageRect(
        image,
        source,
        const Rect.fromLTWH(0, 0, 360, 520),
        Paint()..filterQuality = FilterQuality.none,
      );
      c.drawRect(
        const Rect.fromLTWH(0, 0, 360, 520),
        Paint()..color = const Color(0x80060914),
      );
    }
    final random = math.Random(1982 + sector * 709 + cycle * 41);
    for (var i = 0; i < 80; i++) {
      final depth = i % 3 + 1;
      final x = random.nextDouble() * 360;
      final y = (random.nextDouble() * 520 + time * depth * .65) % 520;
      c.drawRect(
        Rect.fromLTWH(
          x.floorToDouble(),
          y.floorToDouble(),
          i % 13 == 0 ? 2 : 1,
          1,
        ),
        Paint()
          ..color = tint.withValues(
            alpha: image == null ? .65 + .1 * depth : .12 + .06 * depth,
          ),
      );
    }
    // Additional route layers move at independent depth rates. Their dark
    // silhouettes remain behind shots and preserve each world's original tint.
    for (var depth = 0; depth <= cycle.clamp(0, 4); depth++) {
      final speed = 1.8 + depth * 1.7;
      final drift = (time * speed) % 96;
      for (var i = -1; i < 6; i++) {
        final x =
            (i * 83.0 + depth * 31 + time * (.2 + depth * .13)) % 440 - 40;
        final y = 430 + depth * 17.0 + drift * .17;
        final h = 20.0 + ((i + 2) * 19 + cycle * 11 + depth * 7) % 53;
        final paint = Paint()
          ..color = tint.withValues(alpha: .035 + depth * .012);
        if (sector == 2 || sector == 3) {
          c.drawPath(
            Path()
              ..moveTo(x - 35, 540)
              ..lineTo(x, y - h)
              ..lineTo(x + 42, 540)
              ..close(),
            paint,
          );
        } else {
          c.drawRect(Rect.fromLTWH(x, y - h, 18 + depth * 7.0, 130), paint);
          c.drawLine(
            Offset(x - 24, y - h + 9),
            Offset(x + 38, y - h + 9),
            Paint()..color = tint.withValues(alpha: .08),
          );
        }
      }
      // Slowly passing orbital girders add depth at the screen edges.
      for (final side in [0.0, 345.0]) {
        final y = (time * speed * 2.4 + depth * 103) % 620 - 70;
        c.drawRect(
          Rect.fromLTWH(side, y, 15, 45 + depth * 5.0),
          Paint()..color = tint.withValues(alpha: .05 + depth * .015),
        );
      }
    }
    // Moon constellations grow as the route approaches occupied space.
    for (var i = 0; i <= sector; i++) {
      final x = i.isEven ? 30.0 + i * 14 : 320.0 - i * 10;
      final y = 65.0 + i * 52 + math.sin(time * .018 + i) * 15;
      final radius = 6.0 + (sector + i) % 4 * 3;
      c.drawCircle(
        Offset(x, y),
        radius,
        Paint()..color = tint.withValues(alpha: .2),
      );
      c.drawCircle(
        Offset(x - radius * .3, y - radius * .15),
        radius * .88,
        Paint()..color = const Color(0xFF101525),
      );
    }
    // Orbiting hardware stays near the side channels; solar wings distinguish
    // frontier survey satellites from the thorned relays in demon territory.
    final occupation = math.min(7, cycle);
    for (var i = 0; i < 1 + sector + occupation; i++) {
      final side = i.isEven ? 1.0 : -1.0;
      final x = 180 + side * (128 + math.sin(time * .04 + i) * 17);
      final y = 110.0 + (i * 63 + time * (1.4 + sector * .2)) % 285;
      c.save();
      c.translate(x, y);
      c.rotate(math.sin(time * .06 + i) * .25);
      c.drawRect(
        const Rect.fromLTWH(-2, -4, 5, 8),
        Paint()..color = tint.withValues(alpha: .4),
      );
      c.drawLine(
        const Offset(-12, 0),
        const Offset(12, 0),
        Paint()..color = tint.withValues(alpha: .3),
      );
      if (sector < 3 && i < sector + 1) {
        for (final sign in [-1.0, 1.0]) {
          c.drawRect(
            Rect.fromLTWH(sign * 9 - 4, -5, 8, 10),
            Paint()..color = tint.withValues(alpha: .17),
          );
          c.drawLine(
            Offset(sign * 9, -5),
            Offset(sign * 9, 5),
            Paint()..color = tint.withValues(alpha: .28),
          );
        }
      } else {
        c.drawPath(
          Path()
            ..moveTo(-11, -7)
            ..lineTo(-5, 0)
            ..lineTo(-11, 7)
            ..moveTo(11, -7)
            ..lineTo(5, 0)
            ..lineTo(11, 7),
          Paint()
            ..color = tint.withValues(alpha: .35)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2,
        );
      }
      c.drawRect(
        const Rect.fromLTWH(-1, -1, 2, 2),
        Paint()
          ..color = tint.withValues(
            alpha: .4 + .2 * math.sin(time * 2 + i).abs(),
          ),
      );
      c.restore();
    }
    // Sector-specific foreground structures, independently animated beacons.
    for (var i = 0; i < 8 + sector * 3 + occupation; i++) {
      final x = (i * 47.0 + 13) % 360;
      final h = 4.0 + (i * 17 % 19) + sector * 5;
      final y = 513.0 - h;
      if (sector == 0) {
        c.drawRect(
          Rect.fromLTWH(x, y, 9, h),
          Paint()..color = const Color(0xFF142A38),
        );
        c.drawRect(
          Rect.fromLTWH(x + 2, y - 2, 5, 2),
          Paint()..color = tint.withValues(alpha: .25),
        );
      } else if (sector == 1) {
        c.drawCircle(
          Offset(x, y + h * .5),
          h * .45,
          Paint()..color = const Color(0xFF201A35),
        );
        c.drawCircle(
          Offset(x - 2, y + h * .4),
          h * .12,
          Paint()..color = const Color(0xFF110F24),
        );
      } else if (sector == 2) {
        c.drawPath(
          Path()
            ..moveTo(x - 8, 520)
            ..lineTo(x + 2, y - 12)
            ..lineTo(x + 13, 520)
            ..close(),
          Paint()..color = const Color(0xFF281923),
        );
        c.drawLine(
          Offset(x + 3, y + 7),
          Offset(x + 6, 517),
          Paint()
            ..color = tint.withValues(
              alpha: .2 + .08 * math.sin(time + i).abs(),
            ),
        );
      } else {
        c.drawRect(
          Rect.fromLTWH(x, y, 7, h + 7),
          Paint()
            ..color = sector == 3
                ? const Color(0xFF132921)
                : const Color(0xFF301722),
        );
        c.drawPath(
          Path()
            ..moveTo(x - 3, y)
            ..lineTo(x + 3, y - 12)
            ..lineTo(x + 10, y)
            ..close(),
          Paint()..color = const Color(0xFF100E1C),
        );
        c.drawRect(
          Rect.fromLTWH(x + 3, y + 5, 1, 4),
          Paint()..color = tint.withValues(alpha: .35),
        );
      }
    }
    if (cycle > 0) {
      // Occupation scars grow each run without obstructing the firing lane.
      for (var i = 0; i < math.min(8, cycle + 2); i++) {
        final y = 35.0 + i * 56;
        for (final side in [0.0, 354.0]) {
          c.drawRect(
            Rect.fromLTWH(side, y, 6, 20),
            Paint()..color = const Color(0xFF793849).withValues(alpha: .45),
          );
          c.drawRect(
            Rect.fromLTWH(side + 2, y + 4, 2, 8),
            Paint()..color = const Color(0xFFFF8C87).withValues(alpha: .3),
          );
        }
      }
    }
  }
}
