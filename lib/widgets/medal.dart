import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../game/model.dart';

class Medal extends StatelessWidget {
  const Medal({
    super.key,
    required this.difficulty,
    required this.ordinal,
    this.earned = true,
    this.size = 24,
  });
  final Difficulty difficulty;
  final int ordinal;
  final bool earned;
  final double size;
  @override
  Widget build(BuildContext context) => Semantics(
    label:
        '${difficulty.name} medal ${ordinal + 1}${earned ? '' : ', unearned'}',
    child: CustomPaint(
      size: Size.square(size),
      painter: MedalPainter(difficulty, ordinal, earned),
    ),
  );
}

class MedalPainter extends CustomPainter {
  const MedalPainter(this.difficulty, this.ordinal, this.earned);
  final Difficulty difficulty;
  final int ordinal;
  final bool earned;
  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 40, size.height / 40);
    final rank = difficulty.index;
    final color = earned
        ? [
            const Color(0xFF70F5D5),
            const Color(0xFFF4CA79),
            const Color(0xFFBDA7FF),
          ][rank]
        : const Color(0xFF465568);
    final p = Paint()
      ..color = color
      ..style = earned ? PaintingStyle.fill : PaintingStyle.stroke
      ..strokeWidth = 1.4;
    for (final side in [-1.0, 1.0]) {
      canvas.drawPath(
        Path()
          ..moveTo(20 + side * 2, 4)
          ..lineTo(20 + side * 12, 2)
          ..lineTo(20 + side * 9, 18)
          ..lineTo(20, 23)
          ..close(),
        p,
      );
    }
    final points = 5 + ordinal.clamp(0, 4);
    final badge = Path();
    for (var i = 0; i < points * 2; i++) {
      final a = i * math.pi / points - math.pi / 2;
      final r = i.isEven ? 13.0 : (rank == 0 ? 10.0 : 7.5);
      final x = 20 + math.cos(a) * r, y = 24 + math.sin(a) * r;
      if (i == 0) {
        badge.moveTo(x, y);
      } else {
        badge.lineTo(x, y);
      }
    }
    badge.close();
    canvas.drawPath(badge, p);
    if (earned) {
      canvas.drawCircle(
        const Offset(20, 24),
        6,
        Paint()..color = const Color(0xFF101827),
      );
      for (var i = 0; i <= ordinal; i++) {
        final a = i * math.pi * 2 / (ordinal + 1) - math.pi / 2;
        canvas.drawCircle(
          Offset(
            20 + math.cos(a) * (ordinal == 0 ? 0 : 3),
            24 + math.sin(a) * (ordinal == 0 ? 0 : 3),
          ),
          1.2,
          Paint()..color = color,
        );
      }
      if (rank > 0) {
        canvas.drawCircle(
          const Offset(20, 24),
          9,
          Paint()
            ..color = const Color(0xFF101827)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1,
        );
      }
      if (rank > 1) {
        for (final side in [-1.0, 1.0]) {
          for (var i = 0; i < 4; i++) {
            canvas.drawOval(
              Rect.fromCenter(
                center: Offset(20 + side * (14 - i), 28 - i * 4.0),
                width: 4,
                height: 2,
              ),
              Paint()..color = color,
            );
          }
        }
      }
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(MedalPainter oldDelegate) =>
      difficulty != oldDelegate.difficulty ||
      ordinal != oldDelegate.ordinal ||
      earned != oldDelegate.earned;
}
