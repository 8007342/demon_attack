import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

/// Complete independently painted worlds inspired by the top-down scrolling
/// arcade aesthetic of the classic 1984 arcade flight game "1942".
/// Features top-down vertical scrolling oceans, organic island archipelagos,
/// military airstrips, coastal fortresses, volcanic atolls, and mothership superstructures
/// with high-altitude drifting cloud shadows.
class SectorBackground {
  final List<ui.Image?> images = List.filled(5, null);
  static const colors = [
    Color(0xFF68C9DE), // Krybor: Cyan / Coastal Ocean
    Color(0xFFB49AE9), // Ringfall: Amethyst / Cloud Ocean
    Color(0xFFF6916E), // Ember Moon: Incandescent Orange / Volcanic Basalt
    Color(0xFF79C798), // The Hollow: Bioluminescent Jade / Deep Abyss
    Color(0xFFE8787C), // Brood Carrier: Crimson / Dreadnought Hull
  ];

  void paint(
    Canvas c,
    double environment,
    double time,
    int cycle,
    ui.Image? fallback, {
    int wave = 1,
  }) {
    final near = environment.floor().clamp(0, 4);
    final far = math.min(4, near + 1);
    final blend = (environment - near).clamp(0.0, 1.0);
    _layer(c, near, time, cycle, wave, fallback);
    if (far != near && blend > .001) {
      c.saveLayer(
        const Rect.fromLTWH(0, 0, 360, 520),
        Paint()..color = Colors.white.withValues(alpha: blend),
      );
      _layer(c, far, time, cycle, wave, fallback);
      c.restore();
    }
  }

  void _layer(
    Canvas c,
    int sector,
    double time,
    int cycle,
    int wave,
    ui.Image? fallback,
  ) {
    final tint = colors[sector];

    // Background base fill
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
        Paint()..color = const Color(0x66060914),
      );
    }

    // Top-down 1942-style vertical scrolling planetary world
    // Smooth high-altitude downward scroll at 24 px/s
    final scrollY = (time * 24.0) % 520.0;

    // 1. Deep Ocean & Water Surface / Atmospheric base
    _paint1942WaterBase(c, sector, scrollY, tint, time);

    // 2. Wave crests and wake ripples
    _paint1942WaveCrests(c, sector, scrollY, tint, time);

    // 3. 1942-Style Landmasses, Atolls, Airstrips, and Fortresses
    _paint1942Landmasses(c, sector, scrollY, tint, time, cycle);

    // 4. Autonomous marine fauna & scout vessels with wake lines
    _paint1942Vessels(c, sector, scrollY, tint, time);

    // 5. High-Altitude Parallax Drifting Clouds & Soft Drop Shadows
    _paint1942CloudsAndShadows(c, sector, time, tint);

    // 6. District and coastal route landmarks (gantries, docks, antennas, forges)
    _routeLandmarks(c, sector, cycle, time);

    // 7. Atmospheric lighting scaling with wave
    _paintAtmosphere(c, sector, time, wave, tint);
  }

  /// 1. Deep Ocean / Base Atmospheric Gradient
  void _paint1942WaterBase(
    Canvas c,
    int sector,
    double scrollY,
    Color tint,
    double time,
  ) {
    final Color oceanDeep;
    final Color oceanMid;

    switch (sector) {
      case 0: // Krybor: Classic 1942 Pacific deep navy/azure ocean
        oceanDeep = const Color(0xFF09162A);
        oceanMid = const Color(0xFF0E223D);
      case 1: // Ringfall: Cloud sea and amethyst stratosphere
        oceanDeep = const Color(0xFF15102A);
        oceanMid = const Color(0xFF1E173D);
      case 2: // Ember Moon: Dark basalt sea with ash clouds
        oceanDeep = const Color(0xFF1D0F14);
        oceanMid = const Color(0xFF2B161D);
      case 3: // The Hollow: Bioluminescent deep abyssal trench
        oceanDeep = const Color(0xFF0A1C1C);
        oceanMid = const Color(0xFF0F2B2B);
      case 4: // Carrier: Dreadnought colossal dark armor trench
        oceanDeep = const Color(0xFF13141A);
        oceanMid = const Color(0xFF1B1D26);
      default:
        oceanDeep = const Color(0xFF09162A);
        oceanMid = const Color(0xFF0E223D);
    }

    // Gradient sea wash
    final gradient = ui.Gradient.linear(
      const Offset(0, 0),
      const Offset(0, 520),
      [oceanDeep, oceanMid, oceanDeep],
      [0.0, 0.5, 1.0],
    );
    c.drawRect(
      const Rect.fromLTWH(0, 0, 360, 520),
      Paint()..shader = gradient,
    );
  }

  /// 2. Water swells, wake patterns, and surface foam lines
  void _paint1942WaveCrests(
    Canvas c,
    int sector,
    double scrollY,
    Color tint,
    double time,
  ) {
    if (sector == 4) {
      // For Brood Carrier, draw hull panel seams instead of waves
      final pSeam = Paint()
        ..color = const Color(0xFF262A36).withValues(alpha: 0.45)
        ..strokeWidth = 1.0;
      for (var y = 0.0; y < 520; y += 65) {
        final sy = (y + scrollY) % 520.0;
        c.drawLine(Offset(0, sy), Offset(360, sy), pSeam);
      }
      for (var x = 30.0; x < 360; x += 80) {
        c.drawLine(Offset(x, 0), Offset(x, 520), pSeam);
      }
      return;
    }

    final pFoam = Paint()
      ..color = tint.withValues(alpha: 0.16)
      ..strokeWidth = 1.0;

    // Scrolling wave crest ripples
    for (var i = 0; i < 18; i++) {
      final y = (i * 32.0 + scrollY) % 520.0;
      final xOffset = math.sin((i * 47) + time * 1.5) * 16.0;
      final waveLen = 22.0 + (i % 5) * 8.0;
      final wx = ((i * 73.0) + xOffset) % (360.0 - waveLen);

      c.drawLine(
        Offset(wx, y),
        Offset(wx + waveLen, y),
        pFoam,
      );
      // Small wake glint
      c.drawRect(
        Rect.fromLTWH(wx + waveLen * 0.4, y - 1, 4, 1),
        Paint()..color = Colors.white.withValues(alpha: 0.22),
      );
    }
  }

  /// 3. Biome Landmasses: Islands, Atolls, Airstrips, and Defense Fortresses
  void _paint1942Landmasses(
    Canvas c,
    int sector,
    double scrollY,
    Color tint,
    double time,
    int cycle,
  ) {
    switch (sector) {
      case 0:
        _paintKryborIslands(c, scrollY, tint, time, cycle);
      case 1:
        _paintRingfallSkyPlatforms(c, scrollY, tint, time, cycle);
      case 2:
        _paintEmberVolcanicAtolls(c, scrollY, tint, time, cycle);
      case 3:
        _paintHollowAbyssalTrenches(c, scrollY, tint, time, cycle);
      case 4:
        _paintCarrierSuperstructure(c, scrollY, tint, time, cycle);
    }
  }

  /// Sector 0: Krybor 1942-Style Island Archipelago & Military Airfields
  void _paintKryborIslands(
    Canvas c,
    double scrollY,
    Color tint,
    double time,
    int cycle,
  ) {
    // 2 Major organic islands scrolling through the area
    for (var idx = 0; idx < 2; idx++) {
      final baseY = (idx * 270.0 + scrollY) % 520.0;
      final islandX = idx == 0 ? 90.0 : 250.0;

      // Outer golden sand beach (wider path)
      final beachPath = Path();
      beachPath.addOval(
        Rect.fromCenter(
          center: Offset(islandX, baseY + 60),
          width: idx == 0 ? 140 : 120,
          height: idx == 0 ? 190 : 160,
        ),
      );
      c.drawPath(
        beachPath,
        Paint()..color = const Color(0xFFC4B17B).withValues(alpha: 0.75),
      );

      // Shallow turquoise coastal reef fringe
      c.drawPath(
        beachPath,
        Paint()
          ..color = const Color(0xFF4AC4B8).withValues(alpha: 0.35)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 5.0,
      );

      // Inner lush tropical jungle/canopy
      final junglePath = Path();
      junglePath.addOval(
        Rect.fromCenter(
          center: Offset(islandX, baseY + 60),
          width: idx == 0 ? 116 : 98,
          height: idx == 0 ? 166 : 138,
        ),
      );
      c.drawPath(
        junglePath,
        Paint()..color = const Color(0xFF1B4E38).withValues(alpha: 0.9),
      );

      // Deep jungle foliage shading
      c.drawCircle(
        Offset(islandX - 10, baseY + 45),
        24,
        Paint()..color = const Color(0xFF133C2A).withValues(alpha: 0.7),
      );
      c.drawCircle(
        Offset(islandX + 15, baseY + 75),
        22,
        Paint()..color = const Color(0xFF133C2A).withValues(alpha: 0.7),
      );

      // 1942 Iconic Airfield Runway on the larger island
      if (idx == 0) {
        final runwayX = islandX - 6;
        final runwayY = baseY + 10;
        // Dark asphalt tarmac
        c.drawRect(
          Rect.fromLTWH(runwayX, runwayY, 20, 100),
          Paint()..color = const Color(0xFF22262E),
        );
        // White dashed center line (-- -- --)
        final pLine = Paint()
          ..color = Colors.white.withValues(alpha: 0.7)
          ..strokeWidth = 1.5;
        for (var dy = 4.0; dy < 96.0; dy += 12) {
          c.drawLine(
            Offset(runwayX + 10, runwayY + dy),
            Offset(runwayX + 10, runwayY + dy + 6),
            pLine,
          );
        }
        // Runway threshold stripes
        for (var tx = 2.0; tx <= 18.0; tx += 4) {
          c.drawLine(
            Offset(runwayX + tx, runwayY + 2),
            Offset(runwayX + tx, runwayY + 8),
            pLine,
          );
          c.drawLine(
            Offset(runwayX + tx, runwayY + 92),
            Offset(runwayX + tx, runwayY + 98),
            pLine,
          );
        }
        // Coastal radar tower
        c.drawCircle(
          Offset(runwayX - 16, runwayY + 50),
          6,
          Paint()..color = const Color(0xFF4C5D6E),
        );
        final radarAngle = time * 3.5;
        c.drawLine(
          Offset(runwayX - 16, runwayY + 50),
          Offset(
            runwayX - 16 + math.cos(radarAngle) * 9,
            runwayY + 50 + math.sin(radarAngle) * 9,
          ),
          Paint()
            ..color = const Color(0xFF54D2D2)
            ..strokeWidth = 1.5,
        );
      } else {
        // Hexagonal coastal defense battery on Island 2
        final fortX = islandX;
        final fortY = baseY + 50;
        c.drawRect(
          Rect.fromCenter(center: Offset(fortX, fortY), width: 28, height: 28),
          Paint()..color = const Color(0xFF333D4B),
        );
        c.drawCircle(
          Offset(fortX, fortY),
          7,
          Paint()..color = const Color(0xFF1E242C),
        );
        c.drawCircle(
          Offset(fortX, fortY),
          3,
          Paint()..color = const Color(0xFF88A4BE),
        );
      }
    }
  }

  /// Sector 1: Ringfall Floating Sky Docks & Cloud Platforms
  void _paintRingfallSkyPlatforms(
    Canvas c,
    double scrollY,
    Color tint,
    double time,
    int cycle,
  ) {
    for (var i = 0; i < 2; i++) {
      final baseY = (i * 260.0 + scrollY) % 520.0;
      final platX = i == 0 ? 110.0 : 250.0;

      // Platform shadow on cloud layer below
      c.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(
            center: Offset(platX + 10, baseY + 70),
            width: 90,
            height: 120,
          ),
          const Radius.circular(8),
        ),
        Paint()..color = const Color(0x33000000),
      );

      // High-tech floating sky platform
      c.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(
            center: Offset(platX, baseY + 60),
            width: 86,
            height: 114,
          ),
          const Radius.circular(8),
        ),
        Paint()..color = const Color(0xFF282542),
      );

      // Inner platform landing deck
      c.drawRect(
        Rect.fromCenter(
          center: Offset(platX, baseY + 60),
          width: 50,
          height: 84,
        ),
        Paint()..color = const Color(0xFF1B192E),
      );

      // Energy guidance lines & pulsing beacons
      final pGuidance = Paint()
        ..color = tint.withValues(alpha: 0.6)
        ..strokeWidth = 1.5;
      c.drawLine(
        Offset(platX - 20, baseY + 24),
        Offset(platX - 20, baseY + 96),
        pGuidance,
      );
      c.drawLine(
        Offset(platX + 20, baseY + 24),
        Offset(platX + 20, baseY + 96),
        pGuidance,
      );

      // Corner guidance beacons blinking in sequence
      final pulse = (math.sin(time * 4.0 + i) + 1.0) * 0.5;
      for (final cx in [-38.0, 38.0]) {
        for (final cy in [-50.0, 50.0]) {
          c.drawCircle(
            Offset(platX + cx, baseY + 60 + cy),
            3,
            Paint()..color = Color.lerp(tint, Colors.white, pulse)!,
          );
        }
      }
    }
  }

  /// Sector 2: Ember Moon Volcanic Atolls & Glowing Magma Veins
  void _paintEmberVolcanicAtolls(
    Canvas c,
    double scrollY,
    Color tint,
    double time,
    int cycle,
  ) {
    for (var i = 0; i < 2; i++) {
      final baseY = (i * 260.0 + scrollY) % 520.0;
      final atollX = i == 0 ? 120.0 : 240.0;

      // Dark basalt volcanic island
      final basaltPath = Path();
      basaltPath.addOval(
        Rect.fromCenter(
          center: Offset(atollX, baseY + 60),
          width: i == 0 ? 130 : 110,
          height: i == 0 ? 170 : 150,
        ),
      );
      c.drawPath(
        basaltPath,
        Paint()..color = const Color(0xFF211317),
      );
      c.drawPath(
        basaltPath,
        Paint()
          ..color = const Color(0xFF3B1D22)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 4.0,
      );

      // Caldera crater with incandescent magma pool
      final calderaCenter = Offset(atollX, baseY + 50);
      c.drawCircle(
        calderaCenter,
        18,
        Paint()..color = const Color(0xFF140A0D),
      );
      final magmaGlow = 0.7 + math.sin(time * 3.0 + i) * 0.25;
      c.drawCircle(
        calderaCenter,
        12,
        Paint()..color = const Color(0xFFFF5222).withValues(alpha: magmaGlow),
      );
      c.drawCircle(
        calderaCenter,
        6,
        Paint()..color = const Color(0xFFFFDF7A).withValues(alpha: magmaGlow),
      );

      // Glowing magma river carving through the rock into the ash sea
      final riverPath = Path();
      riverPath.moveTo(calderaCenter.dx, calderaCenter.dy);
      riverPath.quadraticBezierTo(
        calderaCenter.dx + 25,
        calderaCenter.dy + 40,
        calderaCenter.dx + 15,
        calderaCenter.dy + 90,
      );
      c.drawPath(
        riverPath,
        Paint()
          ..color = const Color(0xFFFF4818)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 4.0,
      );
      c.drawPath(
        riverPath,
        Paint()
          ..color = const Color(0xFFFFD460)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5,
      );
    }
  }

  /// Sector 3: The Hollow Bioluminescent Abyssal Trenches
  void _paintHollowAbyssalTrenches(
    Canvas c,
    double scrollY,
    Color tint,
    double time,
    int cycle,
  ) {
    for (var i = 0; i < 2; i++) {
      final baseY = (i * 260.0 + scrollY) % 520.0;
      final trenchX = i == 0 ? 100.0 : 260.0;

      // Sunken alien continental shelf
      final shelfPath = Path();
      shelfPath.addOval(
        Rect.fromCenter(
          center: Offset(trenchX, baseY + 60),
          width: 120,
          height: 160,
        ),
      );
      c.drawPath(
        shelfPath,
        Paint()..color = const Color(0xFF0B2120),
      );

      // Bioluminescent abyssal trench fissure
      final fissurePath = Path();
      fissurePath.moveTo(trenchX - 20, baseY + 10);
      fissurePath.quadraticBezierTo(
        trenchX + 15,
        baseY + 50,
        trenchX - 10,
        baseY + 110,
      );

      // Glowing aquatic trench glow
      c.drawPath(
        fissurePath,
        Paint()
          ..color = const Color(0xFF2BF2A3).withValues(alpha: 0.35)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 12.0
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
      );
      c.drawPath(
        fissurePath,
        Paint()
          ..color = const Color(0xFF62FFD2)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.5,
      );

      // Ancient sunken alien monoliths
      for (var m = 0; m < 3; m++) {
        final mx = trenchX + (m - 1) * 32.0;
        final my = baseY + 45.0 + (m % 2) * 25.0;
        c.drawRect(
          Rect.fromLTWH(mx - 4, my - 6, 8, 12),
          Paint()..color = const Color(0xFF143D39),
        );
        c.drawRect(
          Rect.fromLTWH(mx - 2, my - 4, 4, 8),
          Paint()..color = const Color(0xFF38FFBE).withValues(alpha: 0.7),
        );
      }
    }
  }

  /// Sector 4: Brood Carrier Colossal Exterior Superstructure
  void _paintCarrierSuperstructure(
    Canvas c,
    double scrollY,
    Color tint,
    double time,
    int cycle,
  ) {
    // Top-down flight over gargantuan mothership hull plates
    for (var i = 0; i < 3; i++) {
      final baseY = (i * 180.0 + scrollY) % 520.0;

      // Heavy interlocking graphene armor tiles
      c.drawRect(
        Rect.fromLTWH(20, baseY + 10, 150, 75),
        Paint()..color = const Color(0xFF1E212B),
      );
      c.drawRect(
        Rect.fromLTWH(180, baseY + 20, 160, 75),
        Paint()..color = const Color(0xFF171A24),
      );

      // Rivets & armor panel borders
      c.drawRect(
        Rect.fromLTWH(20, baseY + 10, 150, 75),
        Paint()
          ..color = const Color(0xFF34394A)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5,
      );
      c.drawRect(
        Rect.fromLTWH(180, baseY + 20, 160, 75),
        Paint()
          ..color = const Color(0xFF34394A)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5,
      );

      // Central thermal exhaust trench with plasma glow
      final trenchY = baseY + 80;
      c.drawRect(
        Rect.fromLTWH(0, trenchY, 360, 16),
        Paint()..color = const Color(0xFF0F1017),
      );
      final plasmaPulse = 0.5 + math.sin(time * 5.0 + i) * 0.3;
      c.drawRect(
        Rect.fromLTWH(0, trenchY + 4, 360, 8),
        Paint()..color = const Color(0xFFFF3344).withValues(alpha: plasmaPulse),
      );

      // Blinking carrier warning lights
      for (var lx = 30.0; lx < 360.0; lx += 45.0) {
        c.drawCircle(
          Offset(lx, trenchY + 2),
          2.5,
          Paint()..color = const Color(0xFFFF8888),
        );
        c.drawCircle(
          Offset(lx, trenchY + 14),
          2.5,
          Paint()..color = const Color(0xFFFF8888),
        );
      }
    }
  }

  /// 4. Autonomous marine fauna & scout vessels with wake trails
  void _paint1942Vessels(
    Canvas c,
    int sector,
    double scrollY,
    Color tint,
    double time,
  ) {
    if (sector == 4) return; // Superstructure has no marine vessels

    for (var i = 0; i < 3; i++) {
      final vy = (i * 175.0 + scrollY * 1.3) % 520.0;
      final vx = ((i * 110.0 + 40.0) + math.sin(time * 0.8 + i) * 20.0) % 320.0 + 20.0;

      // White water V-wake lines behind moving vessel
      final pWake = Paint()
        ..color = Colors.white.withValues(alpha: 0.28)
        ..strokeWidth = 1.2;
      c.drawLine(Offset(vx, vy), Offset(vx - 8, vy - 14), pWake);
      c.drawLine(Offset(vx, vy), Offset(vx + 8, vy - 14), pWake);

      // Vessel / creature hull
      c.drawRect(
        Rect.fromCenter(center: Offset(vx, vy), width: 4, height: 7),
        Paint()..color = const Color(0xFFE2EFF5),
      );
    }
  }

  /// 5. High-Altitude Parallax Drifting Clouds & Soft Drop Shadows
  void _paint1942CloudsAndShadows(
    Canvas c,
    int sector,
    double time,
    Color tint,
  ) {
    // Clouds scroll slightly faster (parallax velocity 36 px/s)
    final cloudScrollY = (time * 36.0) % 520.0;

    for (var i = 0; i < 4; i++) {
      final cy = (i * 135.0 + cloudScrollY) % 520.0;
      final cx = (i * 85.0 + 35.0 + math.sin(time * 0.25 + i) * 30.0) % 360.0;
      final w = 60.0 + (i % 3) * 18.0;
      final h = 32.0 + (i % 2) * 12.0;

      // 1. Soft ground shadow cast onto ocean & islands below
      final shadowOffset = const Offset(14, 22);
      c.drawOval(
        Rect.fromCenter(
          center: Offset(cx, cy) + shadowOffset,
          width: w * 0.95,
          height: h * 0.95,
        ),
        Paint()..color = const Color(0x35000000),
      );

      // 2. Fluffy white high-altitude cumulus cloud body
      final cloudPaint = Paint()..color = Colors.white.withValues(alpha: 0.42);
      c.drawCircle(Offset(cx - w * 0.2, cy), h * 0.45, cloudPaint);
      c.drawCircle(Offset(cx, cy - h * 0.1), h * 0.55, cloudPaint);
      c.drawCircle(Offset(cx + w * 0.2, cy), h * 0.42, cloudPaint);

      // Highlight crest
      c.drawCircle(
        Offset(cx - 2, cy - h * 0.18),
        h * 0.35,
        Paint()..color = Colors.white.withValues(alpha: 0.55),
      );
    }
  }

  /// 6. Atmospheric lighting scaling with wave progression
  void _paintAtmosphere(
    Canvas c,
    int sector,
    double time,
    int wave,
    Color tint,
  ) {
    final intensity = (wave / 4.0).clamp(0.25, 1.0);
    // Subtle top-down sunbeam sweep
    final sunX = 180.0 + math.sin(time * 0.15) * 80.0;
    final sweepGradient = ui.Gradient.radial(
      Offset(sunX, 0),
      400,
      [
        tint.withValues(alpha: 0.08 * intensity),
        Colors.transparent,
      ],
      [0.0, 1.0],
    );
    c.drawRect(
      const Rect.fromLTWH(0, 0, 360, 520),
      Paint()..shader = sweepGradient,
    );
  }

  /// 7. Distinct route and district horizon silhouettes
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
