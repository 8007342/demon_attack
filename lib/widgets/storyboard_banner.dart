import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../game/campaign_story.dart';
import '../game/model.dart';
import '../game/sector_background.dart';

/// Curated widescreen pictorial storyboard banner for sector arrivals,
/// outpost liberation, hyperspace route traversal, and carrier destruction.
class StoryboardBanner extends StatelessWidget {
  const StoryboardBanner({
    super.key,
    required this.level,
    required this.cycle,
    required this.phase,
    this.progress = 0.5,
    this.steering = 0.0,
    this.compact = false,
    this.height,
  });

  final int level;
  final int cycle;
  final RunMode phase;
  final double progress;
  final double steering;
  final bool compact;
  final double? height;

  static const _sectorShortNames = [
    'KRYBOR',
    'RINGFALL',
    'EMBER',
    'HOLLOW',
    'CARRIER',
  ];

  @override
  Widget build(BuildContext context) {
    final effectiveHeight = height ?? (compact ? 84.0 : 112.0);
    final clampedLevel = level.clamp(1, 5);
    final clampedCycle = cycle.clamp(0, 4);
    final clampedProgress = progress.clamp(0.0, 1.0);
    final clampedSteering = steering.clamp(-1.0, 1.0);

    final semanticLabel = switch (phase) {
      RunMode.transition =>
        'Sector arrival storyboard: ${CampaignStory.name(clampedLevel, clampedCycle)}',
      RunMode.levelClear =>
        'Sector secured storyboard: ${CampaignStory.name(clampedLevel, clampedCycle)}',
      RunMode.travel =>
        'Sector route star chart from ${CampaignStory.name(clampedLevel, clampedCycle)}',
      RunMode.victory || RunMode.completed =>
        'Carrier destruction storyboard: ${CampaignStory.name(clampedLevel, clampedCycle)}',
      _ => 'Tactical sector storyboard',
    };

    return Semantics(
      image: true,
      label: semanticLabel,
      child: ExcludeSemantics(
        child: SizedBox(
          height: effectiveHeight,
          width: double.infinity,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: const Color(0xFF070C18),
              border: Border.all(color: const Color(0xFF284260), width: 1.5),
              borderRadius: BorderRadius.circular(6),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(4.5),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  CustomPaint(
                    painter: _StoryboardPainter(
                      level: clampedLevel,
                      cycle: clampedCycle,
                      phase: phase,
                      progress: clampedProgress,
                      steering: clampedSteering,
                      compact: compact,
                    ),
                  ),
                  if (phase == RunMode.travel)
                    Positioned(
                      left: 6,
                      right: 6,
                      bottom: compact ? 3 : 5,
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: SizedBox(
                          width: 300,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              for (var i = 0; i < 5; i++)
                                Text(
                                  _sectorShortNames[i],
                                  style: TextStyle(
                                    color: i + 1 == clampedLevel
                                        ? const Color(0xFFFFD594)
                                        : (i < clampedLevel
                                              ? const Color(0xFF70F5D5)
                                              : const Color(0xFF6B829E)),
                                    fontSize: compact ? 8.5 : 9.5,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 0.6,
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _StoryboardPainter extends CustomPainter {
  const _StoryboardPainter({
    required this.level,
    required this.cycle,
    required this.phase,
    required this.progress,
    required this.steering,
    required this.compact,
  });

  final int level;
  final int cycle;
  final RunMode phase;
  final double progress;
  final double steering;
  final bool compact;

  @override
  void paint(Canvas canvas, Size size) {
    final sectorIndex = (level - 1).clamp(0, 4);
    final tint = SectorBackground.colors[sectorIndex];

    // Deep space backdrop & subtle scanlines
    final bgPaint = Paint()..color = const Color(0xFF070C18);
    canvas.drawRect(Offset.zero & size, bgPaint);

    final scanPaint = Paint()..color = const Color(0x141A2C47);
    for (var y = 0.0; y < size.height; y += 4) {
      canvas.drawRect(Rect.fromLTWH(0, y, size.width, 1), scanPaint);
    }

    // Deterministic parallax starfield
    final rng = math.Random(409 + level * 97 + cycle * 31);
    final starPaint = Paint()..isAntiAlias = false;
    for (var i = 0; i < 36; i++) {
      final sx =
          (rng.nextDouble() * size.width - progress * (8 + (i % 3) * 10)) %
          size.width;
      final sy = rng.nextDouble() * (size.height * 0.78);
      starPaint.color = i % 5 == 0
          ? tint.withValues(alpha: 0.75)
          : const Color(0x99C7D9EC);
      canvas.drawRect(
        Rect.fromLTWH(
          sx < 0 ? sx + size.width : sx,
          sy,
          i % 7 == 0 ? 2 : 1.5,
          i % 7 == 0 ? 2 : 1.5,
        ),
        starPaint,
      );
    }

    switch (phase) {
      case RunMode.travel:
        _paintWarpTravel(canvas, size, tint);
      case RunMode.levelClear:
        _paintSectorClear(canvas, size, tint);
      case RunMode.victory:
      case RunMode.completed:
        _paintBossFall(canvas, size, tint);
      case RunMode.transition:
      default:
        _paintSectorArrival(canvas, size, tint);
    }

    // Corner tactical framing brackets
    _paintCornerBrackets(canvas, size, tint);
  }

  void _paintSectorPanorama(
    Canvas canvas,
    Size size,
    Color tint, {
    required bool secured,
  }) {
    final p = Paint()..isAntiAlias = false;
    final w = size.width;
    final h = size.height;
    final horizonY = h * 0.72;

    // Atmospheric horizon glow band
    p.color = tint.withValues(alpha: secured ? 0.24 : 0.16);
    canvas.drawRect(Rect.fromLTWH(0, horizonY - 14, w, 16), p);
    p.color = const Color(0xFF101B2E);
    canvas.drawRect(Rect.fromLTWH(0, horizonY, w, h - horizonY), p);

    switch (level) {
      case 1:
        // Krybor: Frontier mountain ridges & relay towers
        final ridge = Path()
          ..moveTo(0, horizonY)
          ..lineTo(w * 0.14, horizonY - 18)
          ..lineTo(w * 0.28, horizonY - 8)
          ..lineTo(w * 0.46, horizonY - 24)
          ..lineTo(w * 0.64, horizonY - 10)
          ..lineTo(w * 0.82, horizonY - 20)
          ..lineTo(w, horizonY - 6)
          ..lineTo(w, h)
          ..lineTo(0, h)
          ..close();
        p.color = const Color(0xFF15263D);
        canvas.drawPath(ridge, p);
        for (final rx in [0.18, 0.46, 0.78]) {
          final tx = w * rx;
          p.color = const Color(0xFF3E5F82);
          canvas.drawRect(Rect.fromLTWH(tx - 2, horizonY - 28, 4, 18), p);
          p.color = secured ? const Color(0xFFFFD594) : const Color(0xFF70F5D5);
          canvas.drawRect(Rect.fromLTWH(tx - 3, horizonY - 31, 6, 4), p);
        }
      case 2:
        // Ringfall: Sweeping planetary ring arc & orbital gantry silhouettes
        final ringPaint = Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 5
          ..color = tint.withValues(alpha: 0.35);
        canvas.drawArc(
          Rect.fromLTWH(-w * 0.1, horizonY - 36, w * 1.2, 76),
          math.pi * 1.08,
          math.pi * 0.84,
          false,
          ringPaint,
        );
        for (final gx in [0.22, 0.52, 0.80]) {
          final x = w * gx;
          p.color = const Color(0xFF23324D);
          canvas.drawRect(Rect.fromLTWH(x - 10, horizonY - 20, 20, 8), p);
          canvas.drawRect(Rect.fromLTWH(x - 2, horizonY - 28, 4, 24), p);
        }
      case 3:
        // Ember Moon: Volcanic calderas, furnace stacks & magma channels
        for (final vx in [0.20, 0.50, 0.82]) {
          final cx = w * vx;
          final cone = Path()
            ..moveTo(cx - 28, horizonY + 4)
            ..lineTo(cx - 8, horizonY - 22)
            ..lineTo(cx + 8, horizonY - 22)
            ..lineTo(cx + 28, horizonY + 4)
            ..close();
          p.color = const Color(0xFF2B1A24);
          canvas.drawPath(cone, p);
          p.color = secured ? const Color(0xFF70F5D5) : const Color(0xFFFF786C);
          canvas.drawRect(Rect.fromLTWH(cx - 5, horizonY - 24, 10, 4), p);
        }
      case 4:
        // The Hollow: Ancient monolith spires & command arches
        for (final sx in [0.15, 0.35, 0.65, 0.85]) {
          final x = w * sx;
          p.color = const Color(0xFF172E2A);
          canvas.drawRect(Rect.fromLTWH(x - 5, horizonY - 34, 10, 34), p);
          p.color = secured ? const Color(0xFFFFD594) : const Color(0xFF79C798);
          canvas.drawRect(Rect.fromLTWH(x - 2, horizonY - 30, 4, 14), p);
        }
      case 5:
      default:
        // The Carrier: Looming Brood Dreadnought silhouette on high orbit horizon
        final cx = w * 0.5;
        final cy = h * 0.34;
        p.color = const Color(0xFF281D42);
        canvas.drawRect(Rect.fromLTWH(cx - 54, cy - 10, 108, 20), p);
        canvas.drawRect(Rect.fromLTWH(cx - 34, cy - 18, 68, 28), p);
        p.color = const Color(0xFFE8787C);
        for (final bx in [-24.0, 0.0, 24.0]) {
          canvas.drawRect(Rect.fromLTWH(cx + bx - 5, cy + 4, 10, 5), p);
        }
    }
  }

  void _paintSectorArrival(Canvas canvas, Size size, Color tint) {
    _paintSectorPanorama(canvas, size, tint, secured: false);

    final w = size.width;
    final h = size.height;

    // 5-Stage route progress indicator along top edge:
    // [0]-0-0-0-0 on stage 1, [0-0]-0-0-0 on stage 2,
    // [0-0-0]-0-0 on stage 3, [0-0-0-0]-0 on stage 4, 0-0-0-[0-0] on stage 5.
    final currentSector = (level - 1).clamp(0, 4);
    const indicatorY = 12.0;
    for (var i = 0; i < 4; i++) {
      final x1 = w * (0.26 + i * 0.12);
      final x2 = w * (0.26 + (i + 1) * 0.12);
      final connected = i < currentSector;
      canvas.drawLine(
        Offset(x1, indicatorY),
        Offset(x2, indicatorY),
        Paint()
          ..strokeWidth = connected ? 2.0 : 1.2
          ..color = connected ? const Color(0xFF70F5D5) : const Color(0xFF283B4F),
      );
    }
    for (var i = 0; i < 5; i++) {
      final cx = w * (0.26 + i * 0.12);
      final isCurrent = i == currentSector;
      final isVisited = i < currentSector;
      canvas.drawCircle(
        Offset(cx, indicatorY),
        isCurrent ? 5.0 : 3.5,
        Paint()
          ..color = isCurrent
              ? const Color(0xFFFFD594)
              : (isVisited ? const Color(0xFF70F5D5) : const Color(0xFF283B4F)),
      );
    }

    // Physical stage brackets matching the exact notation:
    // Stage 1: [0]-0-0-0-0 (bracket around 0)
    // Stage 2: [0-0]-0-0-0 (bracket from 0 to 1)
    // Stage 3: [0-0-0]-0-0 (bracket from 0 to 2)
    // Stage 4: [0-0-0-0]-0 (bracket from 0 to 3)
    // Stage 5: [0-0-0-0-0] (bracket all 5 sectors into boss)
    final double leftBx, rightBx;
    if (currentSector == 4) {
      leftBx = w * 0.26 - 8.0;
      rightBx = w * (0.26 + 4 * 0.12) + 8.0;
    } else {
      leftBx = w * 0.26 - 8.0;
      rightBx = w * (0.26 + currentSector * 0.12) + 8.0;
    }
    _paintBracket(canvas, leftBx, indicatorY, true, const Color(0xFFFFD594));
    _paintBracket(canvas, rightBx, indicatorY, false, const Color(0xFFFFD594));

    // Sweeping tactical radar arc on right side
    final radarCenter = Offset(w * 0.76, h * 0.46);
    final radarRadius = h * 0.34;
    final radarRingPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2
      ..color = const Color(0x5570F5D5);
    canvas.drawCircle(radarCenter, radarRadius, radarRingPaint);
    canvas.drawCircle(radarCenter, radarRadius * 0.58, radarRingPaint);

    final sweepAngle = (progress * math.pi * 2) - math.pi / 2;
    final sweepEnd = Offset(
      radarCenter.dx + math.cos(sweepAngle) * radarRadius,
      radarCenter.dy + math.sin(sweepAngle) * radarRadius,
    );
    canvas.drawLine(
      radarCenter,
      sweepEnd,
      Paint()
        ..color = const Color(0xCC70F5D5)
        ..strokeWidth = 1.8,
    );

    // Animated formation target blips locking in
    final blipPaint = Paint()..isAntiAlias = false;
    const blipOffsets = [
      Offset(-12, -10),
      Offset(10, -12),
      Offset(-4, 6),
      Offset(14, 8),
    ];
    for (var i = 0; i < blipOffsets.length; i++) {
      final b = radarCenter + blipOffsets[i];
      final locked = ((progress * 4) + i * 0.3) % 1.0 > 0.25;
      blipPaint.color = locked
          ? const Color(0xFFFF786C)
          : const Color(0x77FFD594);
      canvas.drawRect(Rect.fromLTWH(b.dx - 2, b.dy - 2, 4, 4), blipPaint);
      if (locked) {
        canvas.drawRect(
          Rect.fromLTWH(b.dx - 5, b.dy - 5, 10, 10),
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1
            ..color = const Color(0x88FFD594),
        );
      }
    }

    // Player starfighter banking into the sector on the left/center
    final fighterX = w * (0.22 + progress * 0.14) + steering * 12;
    final fighterY = h * (0.58 - progress * 0.10);
    _paintStarfighter(
      canvas,
      Offset(fighterX, fighterY),
      bank: steering * 0.35 + 0.18,
      scale: compact ? 0.9 : 1.1,
    );
  }

  void _paintSectorClear(Canvas canvas, Size size, Color tint) {
    _paintSectorPanorama(canvas, size, tint, secured: true);

    final w = size.width;
    final h = size.height;
    final horizonY = h * 0.72;
    final p = Paint()..isAntiAlias = false;

    // Secured outpost beacons lighting up in gold with vertical uplink beams
    for (var i = 0; i < 4; i++) {
      final bx = w * (0.18 + i * 0.21);
      final beamAlpha = ((progress * 1.4 - i * 0.18).clamp(0.15, 1.0) * 0.55);
      p.color = const Color(0xFFFFD594).withValues(alpha: beamAlpha);
      canvas.drawRect(Rect.fromLTWH(bx - 2, 6, 4, horizonY - 6), p);
      p.color = const Color(0xFFFFF5C9);
      canvas.drawRect(Rect.fromLTWH(bx - 4, horizonY - 6, 8, 6), p);
    }

    // Celebratory flak / signal bursts in upper sky
    for (var i = 0; i < 5; i++) {
      final fx = w * (0.15 + i * 0.17);
      final fy = h * (0.24 + (i % 2) * 0.14);
      final r = 4.0 + ((progress * 12 + i * 3) % 7);
      p.color = i.isEven ? const Color(0xFF70F5D5) : const Color(0xFFFFD594);
      for (var a = 0; a < 4; a++) {
        final ang = a * math.pi / 2 + progress * math.pi;
        canvas.drawRect(
          Rect.fromLTWH(
            fx + math.cos(ang) * r - 1.5,
            fy + math.sin(ang) * r - 1.5,
            3,
            3,
          ),
          p,
        );
      }
    }

    // Starfighter climbing triumphantly into orbit
    final climbX = w * 0.50 + steering * 14;
    final climbY = h * (0.64 - progress * 0.34);
    _paintStarfighter(
      canvas,
      Offset(climbX, climbY),
      bank: steering * 0.25,
      scale: compact ? 0.95 : 1.15,
    );
  }

  void _paintWarpTravel(Canvas canvas, Size size, Color tint) {
    final w = size.width;
    final h = size.height;
    final mapY = h * 0.44;

    // Hyperspace vector speed lines
    final streakPaint = Paint()..strokeWidth = 1.5;
    for (var i = 0; i < 10; i++) {
      final sy = 10.0 + (i * (h - 28) / 9.0);
      final sx = ((w - (progress * w * 1.8) + i * 53) % w);
      streakPaint.color = i.isEven
          ? const Color(0x4470F5D5)
          : tint.withValues(alpha: 0.28);
      canvas.drawLine(Offset(sx, sy), Offset(sx + 22, sy), streakPaint);
    }

    // 5-node Sector Route Star Chart:
    // Krybor (0) -> Ringfall (1) -> Ember Moon (2) -> The Hollow (3) -> The Carrier (4)
    final nodes = List<Offset>.generate(5, (i) {
      final nx = w * (0.10 + i * 0.20);
      final ny = mapY + (i.isEven ? -6.0 : 6.0);
      return Offset(nx, ny);
    });

    final isBossWrap = level >= 5;
    final fromSector = (level - 1).clamp(0, 4);
    final toSector = isBossWrap ? 0 : fromSector + 1;

    // Connecting route lines:
    // 0 -> 1 on level 1 ([0-0]-0-0-0), 1 -> 2 on level 2 ([0-0-0]-0-0),
    // 2 -> 3 on level 3 ([0-0-0-0]-0), 3 -> 4 on level 4 (0-0-0-[0-0] boss entry).
    for (var i = 0; i < 4; i++) {
      final completedLeg = i < fromSector;
      final activeLeg = !isBossWrap && i == fromSector;
      final legPaint = Paint()
        ..strokeWidth = activeLeg ? 2.5 : 1.8
        ..color = completedLeg
            ? const Color(0xFF70F5D5)
            : (activeLeg ? const Color(0xFFFFD594) : const Color(0xFF29405E));
      canvas.drawLine(nodes[i], nodes[i + 1], legPaint);
    }

    if (isBossWrap) {
      // Deep Sector Hyperspace Re-Entry:
      // Golden warp arc connecting back from Carrier (4) to Krybor (0) for next tour!
      final wrapPaint = Paint()
        ..color = const Color(0xFFFFD594).withValues(alpha: 0.8)
        ..strokeWidth = 2.2
        ..style = PaintingStyle.stroke;
      final wrapPath = Path()
        ..moveTo(nodes[4].dx, nodes[4].dy)
        ..cubicTo(nodes[4].dx, mapY + 22, nodes[0].dx, mapY + 22, nodes[0].dx, nodes[0].dy);
      canvas.drawPath(wrapPath, wrapPaint);
    }

    // Draw each sector node icon
    for (var i = 0; i < 5; i++) {
      final center = nodes[i];
      final nodeColor = SectorBackground.colors[i];
      final isFrom = i == fromSector;
      final isTo = i == toSector;
      final isCompleted = i <= fromSector && !isBossWrap;

      canvas.drawCircle(
        center,
        isFrom || isTo ? 8.5 : 6.5,
        Paint()..color = const Color(0xFF0A1324),
      );
      canvas.drawCircle(
        center,
        isFrom || isTo ? 8.5 : 6.5,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = isFrom || isTo ? 2.0 : 1.4
          ..color = isBossWrap
              ? const Color(0xFFFFD594)
              : (isTo
                    ? const Color(0xFFFFD594)
                    : (isCompleted
                          ? const Color(0xFF70F5D5)
                          : const Color(0xFF476282))),
      );
      canvas.drawCircle(
        center,
        isFrom || isTo ? 4.5 : 3.2,
        Paint()..color = nodeColor,
      );
    }

    // Active route segment brackets matching exact notation:
    // Leg 0 (level 1 clear): [0-0]-0-0-0
    // Leg 1 (level 2 clear): [0-0-0]-0-0
    // Leg 2 (level 3 clear): [0-0-0-0]-0
    // Leg 3 (level 4 clear into boss): [0-0-0-0-0]
    if (!isBossWrap) {
      final double bLeft = nodes[0].dx - 12.0;
      final double bRight = nodes[toSector].dx + 12.0;
      _paintBracket(canvas, bLeft, mapY, true, const Color(0xFFFFD594));
      _paintBracket(canvas, bRight, mapY, false, const Color(0xFFFFD594));
    }

    // Animated starfighter icon traversing between fromSector and toSector
    final Offset shipPos;
    if (isBossWrap) {
      final warpT = progress.clamp(0.0, 1.0);
      final wx = nodes[4].dx + (nodes[0].dx - nodes[4].dx) * warpT;
      final wy = (mapY + 20) + math.sin(warpT * math.pi) * 10;
      shipPos = Offset(wx, wy);
    } else {
      shipPos = Offset.lerp(nodes[fromSector], nodes[toSector], progress.clamp(0.0, 1.0))!;
    }
    _paintStarfighter(
      canvas,
      Offset(shipPos.dx, shipPos.dy - 12),
      bank: 0.25 + steering * 0.2,
      scale: compact ? 0.82 : 0.95,
    );
  }

  void _paintBracket(
    Canvas canvas,
    double x,
    double y,
    bool isLeft,
    Color color,
  ) {
    final p = Paint()
      ..color = color
      ..strokeWidth = 1.8
      ..style = PaintingStyle.stroke;
    final dir = isLeft ? 1.0 : -1.0;
    canvas.drawPath(
      Path()
        ..moveTo(x + dir * 4, y - 7)
        ..lineTo(x, y - 7)
        ..lineTo(x, y + 7)
        ..lineTo(x + dir * 4, y + 7),
      p,
    );
  }

  void _paintBossFall(Canvas canvas, Size size, Color tint) {
    final w = size.width;
    final h = size.height;
    final cx = w * 0.5;
    final cy = h * 0.46;
    final p = Paint()..isAntiAlias = false;

    // Fleet command golden/teal uplink waves locking in across the background
    for (var ring = 1; ring <= 3; ring++) {
      final rad = (progress * 38 + ring * 22) % (w * 0.45);
      canvas.drawCircle(
        Offset(cx, cy),
        rad,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.4
          ..color = ring.isEven
              ? const Color(0x5570F5D5)
              : const Color(0x66FFD594),
      );
    }

    // Fractured Dreadnought Carrier splitting apart in orbital reentry flames
    final split = 6.0 + progress * 22.0;
    final drop = progress * 8.0;

    // Core supernova glow between halves
    canvas.drawCircle(
      Offset(cx, cy),
      14 + (1 - (progress - 0.5).abs()) * 10,
      Paint()..color = const Color(0x66FF786C),
    );
    canvas.drawCircle(
      Offset(cx, cy),
      7,
      Paint()..color = const Color(0xFFFFF5C9),
    );

    // Left fractured carrier wing/hull half
    p.color = const Color(0xFF4A3D7A);
    canvas.drawRect(Rect.fromLTWH(cx - split - 46, cy - 12 + drop, 42, 22), p);
    p.color = const Color(0xFFFF786C);
    canvas.drawRect(Rect.fromLTWH(cx - split - 6, cy - 10 + drop, 4, 18), p);

    // Right fractured carrier wing/hull half
    p.color = const Color(0xFF643482);
    canvas.drawRect(Rect.fromLTWH(cx + split + 4, cy - 10 + drop, 42, 22), p);
    p.color = const Color(0xFFFFD594);
    canvas.drawRect(Rect.fromLTWH(cx + split + 2, cy - 8 + drop, 4, 18), p);

    // Victorious starfighter soaring past the foreground
    _paintStarfighter(
      canvas,
      Offset(w * 0.24 + steering * 10, h * 0.34),
      bank: steering * 0.25,
      scale: compact ? 0.95 : 1.1,
    );
  }

  void _paintStarfighter(
    Canvas canvas,
    Offset center, {
    double bank = 0.0,
    double scale = 1.0,
  }) {
    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(bank * 0.35);
    canvas.scale(scale);

    final p = Paint()..isAntiAlias = false;
    // Thruster flame
    p.color = const Color(0xFFFF786C);
    canvas.drawRect(const Rect.fromLTWH(-3, 5, 6, 5), p);
    p.color = const Color(0xFFFFF5C9);
    canvas.drawRect(const Rect.fromLTWH(-1.5, 5, 3, 3), p);

    // Swept wings
    p.color = const Color(0xFF70F5D5);
    canvas.drawRect(const Rect.fromLTWH(-11, 0, 22, 4), p);
    canvas.drawRect(const Rect.fromLTWH(-6, -4, 12, 5), p);
    // Fuselage nose & gold canopy
    p.color = const Color(0xFFE1EBF4);
    canvas.drawRect(const Rect.fromLTWH(-2, -9, 4, 14), p);
    p.color = const Color(0xFFFFD594);
    canvas.drawRect(const Rect.fromLTWH(-1.5, -4, 3, 4), p);

    canvas.restore();
  }

  void _paintCornerBrackets(Canvas canvas, Size size, Color tint) {
    final p = Paint()
      ..color = tint.withValues(alpha: 0.7)
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;
    const len = 8.0;
    // Top-left
    canvas.drawPath(
      Path()
        ..moveTo(2, len + 2)
        ..lineTo(2, 2)
        ..lineTo(len + 2, 2),
      p,
    );
    // Top-right
    canvas.drawPath(
      Path()
        ..moveTo(size.width - len - 2, 2)
        ..lineTo(size.width - 2, 2)
        ..lineTo(size.width - 2, len + 2),
      p,
    );
    // Bottom-left
    canvas.drawPath(
      Path()
        ..moveTo(2, size.height - len - 2)
        ..lineTo(2, size.height - 2)
        ..lineTo(len + 2, size.height - 2),
      p,
    );
    // Bottom-right
    canvas.drawPath(
      Path()
        ..moveTo(size.width - len - 2, size.height - 2)
        ..lineTo(size.width - 2, size.height - 2)
        ..lineTo(size.width - 2, size.height - len - 2),
      p,
    );
  }

  @override
  bool shouldRepaint(_StoryboardPainter oldDelegate) =>
      oldDelegate.level != level ||
      oldDelegate.cycle != cycle ||
      oldDelegate.phase != phase ||
      oldDelegate.progress != progress ||
      oldDelegate.steering != steering ||
      oldDelegate.compact != compact;
}
