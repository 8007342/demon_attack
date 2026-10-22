import 'package:flutter/material.dart';

/// Three complementary polygons share one heart outline: left/right/top = 1/2/4.
class HeartParts extends StatelessWidget {
  const HeartParts({super.key, required this.mask, this.size = 24});
  final int mask;
  final double size;
  @override
  Widget build(BuildContext context) => Semantics(
    label: 'Heart parts: ${mask & 7}',
    child: CustomPaint(
      size: Size.square(size),
      painter: HeartPartPainter(mask),
    ),
  );
}

class HeartPartPainter extends CustomPainter {
  const HeartPartPainter(this.mask);
  final int mask;
  static Path outline() => Path()
    ..moveTo(16, 30)
    ..lineTo(3, 17)
    ..cubicTo(-5, 7, 7, -1, 16, 7)
    ..cubicTo(25, -1, 37, 7, 29, 17)
    ..close();
  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 32, size.height / 32);
    canvas.drawPath(outline(), Paint()..color = const Color(0xFF29394A));
    canvas.save();
    canvas.clipPath(outline());
    final pieces = [
      Path()
        ..moveTo(0, 15)
        ..lineTo(16, 15)
        ..lineTo(16, 32)
        ..lineTo(0, 32)
        ..close(),
      Path()
        ..moveTo(16, 15)
        ..lineTo(32, 15)
        ..lineTo(32, 32)
        ..lineTo(16, 32)
        ..close(),
      Path()..addRect(const Rect.fromLTWH(0, 0, 32, 15)),
    ];
    for (var i = 0; i < 3; i++) {
      if (mask & (1 << i) != 0) {
        canvas.drawPath(pieces[i], Paint()..color = const Color(0xFFFF8676));
      }
      canvas.drawPath(
        pieces[i],
        Paint()
          ..color = const Color(0xFF080D18)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1,
      );
    }
    canvas.restore();
    canvas.drawPath(
      outline(),
      Paint()
        ..color = const Color(0xFFF4CA79)
        ..style = PaintingStyle.stroke
        ..strokeWidth = .8,
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(HeartPartPainter oldDelegate) => mask != oldDelegate.mask;
}
