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
    _routeLandmarks(c, sector, cycle, time);
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

  /// Coarse four-unit pixels distinguish named districts without covering fire.
  void _routeLandmarks(Canvas c, int sector, int route, double time) {
    if (route == 0) return;
    c.save();
    c.scale(4);
    final p = Paint()..isAntiAlias = false;
    void pixel(double x, double y, double w, double h, Color color) {
      p.color = color;
      c.drawRect(Rect.fromLTWH(x.floorToDouble(), y.floorToDouble(), w, h), p);
    }

    final tint = colors[sector];
    const shadow = Color(0xFF111D2C);
    final mid = Color.lerp(shadow, tint, .18)!;
    final light = tint.withValues(alpha: .45);
    // Two independently moving banks leave the center flight path open.
    for (var depth = 0; depth < 2; depth++) {
      final shift = (time * (depth == 0 ? .12 : .28)) % 38;
      final base = 119.0 + depth * 6;
      for (final side in [-1, 1]) {
        final edge = side < 0 ? -6.0 : 71.0;
        final x = edge + (side < 0 ? shift * .12 : -shift * .12);
        if (sector == 0 && route == 1) {
          // Slum roofs: crowded, uneven stacked homes with lit tiny windows.
          for (var i = 0; i < 5; i++) {
            final px = x + i * 5;
            final h = 5.0 + (i * 7 + depth * 3) % 11;
            pixel(px, base - h, 5, h + 10, depth == 0 ? shadow : mid);
            pixel(px + 1, base - h - 2, 3, 2, mid);
            pixel(px + 2, base - h + 2, 1, 1, light);
            pixel(px, base - h - 5, 1, 4, mid);
          }
        } else if (sector == 0 && route == 2) {
          // Docks/shipyards: piers, cargo stacks and unmistakable gantry cranes.
          pixel(x, base - 1, 25, 3, mid);
          for (var i = 0; i < 3; i++) {
            pixel(x + i * 8, base - 6, 6, 4, shadow);
            pixel(x + i * 8 + 1, base - 6, 1, 4, mid);
            pixel(x + i * 8 + 4, base + 2, 2, 8, shadow);
          }
          pixel(x + 4, base - 22, 2, 22, mid);
          pixel(x + 4, base - 23, 18, 2, mid);
          pixel(x + 6, base - 21, 2, 2, mid);
          pixel(x + 8, base - 19, 2, 2, mid);
          pixel(x + 20, base - 21, 1, 11, light);
          pixel(x + 19, base - 10, 3, 1, mid);
        } else if (sector == 0 && route == 3) {
          // Mountains are stepped columns, not smooth vector triangles.
          for (var i = 0; i < 8; i++) {
            final h = 7.0 + (i < 4 ? i : 7 - i) * 6;
            pixel(x + i * 3, base - h, 3, h + 12, depth == 0 ? shadow : mid);
          }
          pixel(x + 10, base - 28, 2, 1, light);
        } else if (sector == 0) {
          // Command: ordered defensive terraces and a broad antenna array.
          for (var tier = 0; tier < 3; tier++) {
            pixel(x + tier * 3, base - tier * 5, 26 - tier * 6, 10, mid);
            pixel(x + tier * 3, base - tier * 5, 26 - tier * 6, 1, light);
          }
          pixel(x + 9, base - 22, 8, 12, shadow);
          pixel(x + 8, base - 23, 10, 3, mid);
          for (var i = 0; i < 3; i++) {
            pixel(x + 9 + i * 3, base - 28, 1, 6, mid);
            pixel(x + 8 + i * 3, base - 27, 3, 1, light);
          }
        } else if (sector == 1 && route == 1) {
          // Patrol Belt: repeated winged relays guard an open marked lane.
          for (var i = 0; i < 3; i++) {
            final px = x + i * 9;
            final top = base - 20 + i % 2 * 5;
            pixel(px + 3, top, 2, 16, mid);
            pixel(px, top + 3, 8, 2, mid);
            pixel(px, top + 2, 2, 4, shadow);
            pixel(px + 6, top + 2, 2, 4, shadow);
            pixel(px + 3, top - 1, 2, 1, light);
            pixel(px + 3, base + 2, 2, 1, light);
          }
        } else if (sector == 1 && route == 2) {
          // Wreckfields: two severed hulls, exposed ribs and detached debris.
          for (var i = 0; i < 4; i++) {
            pixel(x + i * 4, base - 19 + i * 2, 5, 3, mid);
            pixel(x + i * 4 + 1, base - 16 + i * 2, 1, 4, shadow);
          }
          for (var i = 0; i < 3; i++) {
            pixel(x + 15 + i * 3, base - 8 - i * 2, 3, 3, mid);
            pixel(x + 2 + i * 7, base + 2 + i % 2 * 3, 2, 2, mid);
          }
          pixel(x + 4, base - 14, 3, 2, light);
        } else if (sector == 1 && route == 3) {
          // Shipyards: open construction cage around an unfinished hull.
          pixel(x + 1, base - 24, 24, 2, mid);
          pixel(x + 1, base, 24, 2, mid);
          for (var i = 0; i < 4; i++) {
            pixel(x + 1 + i * 7, base - 24, 2, 26, mid);
            pixel(x + 3 + i * 7, base - 20, 3, 1, light);
          }
          pixel(x + 4, base - 11, 15, 5, shadow);
          pixel(x + 6, base - 12, 11, 1, mid);
          pixel(x + 6, base - 6, 14, 2, mid);
          for (var i = 0; i < 3; i++) {
            pixel(x + 8 + i * 4, base - 10, 1, 4, mid);
          }
        } else if (sector == 1) {
          // Blockade: aligned armored platforms and continuous barrier bars.
          for (var tier = 0; tier < 2; tier++) {
            final top = base - 21 + tier * 15;
            pixel(x, top + 5, 27, 2, mid);
            for (var i = 0; i < 3; i++) {
              pixel(x + i * 10, top, 7, 4, mid);
              pixel(x + i * 10 + 2, top - 3, 3, 3, shadow);
              pixel(x + i * 10 + 3, top - 5, 1, 3, light);
              pixel(x + i * 10 + 2, top + 7, 3, 2, shadow);
            }
          }
        } else if (sector == 2 && route == 1) {
          // Ashlands: long low drifts interrupted by sparse burned trunks.
          for (var i = 0; i < 9; i++) {
            final h = 3.0 + (4 - (i - 4).abs());
            pixel(x + i * 3, base - h, 3, h + 10, mid);
          }
          pixel(x + 5, base - 17, 1, 14, shadow);
          pixel(x + 3, base - 14, 3, 1, mid);
          pixel(x + 21, base - 12, 2, 9, shadow);
          pixel(x + 20, base - 11, 4, 1, mid);
        } else if (sector == 2 && route == 2) {
          // Forges: capped chimneys over furnace mouths and feed channels.
          for (var i = 0; i < 3; i++) {
            final h = 14.0 + i % 2 * 8;
            pixel(x + i * 9, base - h, 6, h + 8, shadow);
            pixel(x + i * 9 - 1, base - h, 8, 2, mid);
            pixel(x + i * 9 + 1, base - 6, 4, 5, mid);
            pixel(x + i * 9 + 2, base - 5, 2, 3, light);
            pixel(x + i * 9 + 2, base, 1, 9, light);
          }
        } else if (sector == 2 && route == 3) {
          // Crucible: thick nested crater walls enclose a low molten basin.
          for (var i = 0; i < 7; i++) {
            final h = 6.0 + (i - 3).abs() * 5;
            pixel(x + i * 4, base - h, 4, h + 7, shadow);
            pixel(x + i * 4, base - h, 4, 2, mid);
          }
          pixel(x + 9, base - 5, 10, 3, mid);
          pixel(x + 11, base - 4, 6, 1, light);
          pixel(x + 12, base - 3, 4, 2, light);
        } else if (sector == 2) {
          // Brood Heart: lobed nests, connected by low organic conduits.
          for (var i = 0; i < 4; i++) {
            final px = x + i * 6;
            final top = base - 9 - i % 2 * 6;
            pixel(px + 1, top, 4, 2, mid);
            pixel(px, top + 2, 6, 7, mid);
            pixel(px + 1, top + 9, 4, 2, shadow);
            pixel(px + 2, top + 3, 2, 4, shadow);
            pixel(px + 2, top + 5, 2, 1, light);
          }
          pixel(x + 2, base + 2, 23, 2, mid);
        } else if (sector == 3 && route == 1) {
          // Outskirts: isolated broken arches over detached floating stones.
          for (var i = 0; i < 2; i++) {
            final px = x + i * 15;
            final top = base - 18 + i * 5;
            pixel(px, top + 4, 2, 11, mid);
            pixel(px + 8, top + 6, 2, 9, mid);
            pixel(px + 2, top + 2, 3, 2, mid);
            pixel(px + 6, top + 3, 2, 2, mid);
            pixel(px - 2, top + 15, 14, 3, shadow);
            pixel(px + 1, top + 18, 8, 2, mid);
          }
        } else if (sector == 3 && route == 2) {
          // Towers: tall clustered gothic shafts, tiered shoulders and spires.
          for (var i = 0; i < 3; i++) {
            final px = x + i * 8;
            final h = 24.0 + (i == 1 ? 9 : 0);
            pixel(px, base - h + 5, 7, h, shadow);
            pixel(px + 1, base - h, 5, 5, mid);
            pixel(px + 2, base - h - 3, 3, 3, mid);
            pixel(px + 3, base - h - 6, 1, 3, mid);
            pixel(px + 3, base - h + 8, 1, 5, light);
            pixel(px - 1, base - 7, 9, 2, mid);
          }
        } else if (sector == 3 && route == 3) {
          // Catacombs: wide stacked crypt terraces with recessed vault mouths.
          for (var tier = 0; tier < 3; tier++) {
            final top = base - 19 + tier * 8;
            pixel(x + tier, top, 26 - tier * 2, 8, mid);
            for (var i = 0; i < 3; i++) {
              pixel(x + 3 + i * 8, top + 3, 4, 5, shadow);
              pixel(x + 4 + i * 8, top + 2, 2, 1, shadow);
            }
            pixel(x + tier, top + 7, 26 - tier * 2, 1, shadow);
          }
        } else if (sector == 3) {
          // Throne: formal side keeps and descending ceremonial terraces.
          pixel(x + 3, base - 21, 7, 26, shadow);
          pixel(x + 2, base - 22, 9, 3, mid);
          pixel(x + 5, base - 26, 3, 4, mid);
          pixel(x + 6, base - 17, 1, 5, light);
          for (var i = 0; i < 4; i++) {
            pixel(x + 10 + i * 4, base - 10 + i * 3, 4, 20 - i * 3, mid);
          }
        } else if (route == 1) {
          // Brood Ark: a long transport spine carrying rows of hanging pods.
          pixel(x, base - 16, 27, 4, shadow);
          pixel(x + 3, base - 18, 21, 2, mid);
          pixel(x + 9, base - 21, 9, 3, shadow);
          for (var i = 0; i < 4; i++) {
            pixel(x + i * 6 + 2, base - 12, 4, 8, mid);
            pixel(x + i * 6 + 3, base - 4, 2, 2, mid);
            pixel(x + i * 6 + 3, base - 9, 2, 1, light);
          }
        } else if (route == 2) {
          // Siege Carrier: reinforced outriggers with raised gun batteries.
          pixel(x, base - 8, 27, 6, shadow);
          pixel(x + 2, base - 9, 23, 2, mid);
          pixel(x + 2, base - 2, 3, 8, mid);
          pixel(x + 22, base - 2, 3, 8, mid);
          for (var i = 0; i < 3; i++) {
            pixel(x + 2 + i * 9, base - 15, 6, 6, mid);
            pixel(x + 3 + i * 9, base - 21, 1, 6, light);
            pixel(x + 6 + i * 9, base - 21, 1, 6, mid);
          }
        } else if (route == 3) {
          // Brood Citadel: nested ramparts, dark gates and a dense spire crown.
          for (var tier = 0; tier < 3; tier++) {
            pixel(x + tier * 3, base - tier * 7, 28 - tier * 6, 12, mid);
            pixel(x + tier * 3, base - tier * 7 + 2, 28 - tier * 6, 1, shadow);
          }
          for (var i = 0; i < 5; i++) {
            final h = 5.0 + (i % 2) * 4;
            pixel(x + 5 + i * 4, base - 14 - h, 2, h, mid);
          }
          pixel(x + 12, base - 4, 4, 10, shadow);
          pixel(x + 13, base - 5, 2, 1, light);
        } else {
          // Flagship: orderly escort docks around the central command vessel.
          for (var i = 0; i < 3; i++) {
            final px = x + i * 9;
            pixel(px, base - 12, 7, 3, mid);
            pixel(px + 1, base - 15, 5, 3, shadow);
            pixel(px + 3, base - 18, 1, 3, light);
            pixel(px + 3, base - 9, 1, 12, mid);
          }
          pixel(x, base + 3, 27, 2, mid);
        }
      }
    }
    // Monumental centers sit below the firing lane and never mask projectiles.
    // Their small depth drift is independent of the moving side banks above.
    final center = 45.0 + math.sin(time * .035).floorToDouble();
    if (route == 4 && sector == 2) {
      final pulse = (time * 2).floor() % 3;
      pixel(center - 11, 125, 22, 5, shadow);
      pixel(center - 8, 121, 16, 5, mid);
      pixel(center - 5, 118, 10, 6, shadow);
      pixel(center - 2, 120, 4, 5, tint.withValues(alpha: .25 + pulse * .04));
      pixel(center - 10, 122, 2, 3, mid);
      pixel(center + 8, 122, 2, 3, mid);
    } else if (route == 4 && sector == 3) {
      pixel(center - 13, 128, 26, 2, mid);
      pixel(center - 9, 125, 18, 3, shadow);
      pixel(center - 6, 116, 12, 10, mid);
      pixel(center - 4, 118, 8, 6, shadow);
      pixel(center - 8, 113, 2, 14, mid);
      pixel(center + 6, 113, 2, 14, mid);
      pixel(center - 2, 114, 4, 2, light);
    } else if (route == 4 && sector == 4) {
      pixel(center - 24, 125, 48, 5, shadow);
      pixel(center - 18, 122, 36, 5, mid);
      pixel(center - 12, 119, 24, 4, shadow);
      pixel(center - 6, 114, 12, 7, mid);
      pixel(center - 3, 110, 6, 4, shadow);
      pixel(center - 1, 107, 2, 4, mid);
      pixel(center - 4, 116, 8, 1, light);
      for (final side in [-1, 1]) {
        pixel(center + side * 16 - 2, 117, 4, 6, mid);
        pixel(center + side * 16 - 1, 114, 2, 3, shadow);
      }
    }
    c.restore();
  }
}
