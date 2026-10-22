import 'package:flutter/material.dart';

/// A deliberately stepped 16px heart, shared by pickups and inventory slots.
class HeartParts extends StatelessWidget {
  const HeartParts({super.key, required this.mask, this.size = 24});
  final int mask;
  final double size;
  @override
  Widget build(BuildContext context) => Semantics(
    label: mask == 15
        ? 'Complete heart, extra life'
        : 'Heart pieces: ${[if (mask & 1 != 0) 'bottom left', if (mask & 2 != 0) 'bottom right', if (mask & 4 != 0) 'top left', if (mask & 8 != 0) 'top right'].join(', ')}${mask == 0 ? 'empty' : ''}',
    child: CustomPaint(
      size: Size.square(size),
      painter: HeartPartPainter(mask),
    ),
  );
}

class HeartPartPainter extends CustomPainter {
  const HeartPartPainter(this.mask);
  final int mask;
  static const rows = [
    '................',
    '..####....####..',
    '.######..######.',
    '################',
    '################',
    '################',
    '################',
    '.##############.',
    '..############..',
    '...##########...',
    '....########....',
    '.....######.....',
    '......####......',
    '.......##.......',
    '................',
    '................',
  ];

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 16, size.height / 16);
    final paint = Paint()..isAntiAlias = false;
    for (var y = 0; y < rows.length; y++) {
      for (var x = 0; x < 16; x++) {
        if (rows[y][x] != '#') continue;
        final part = y < 6 ? (x < 8 ? 4 : 8) : (x < 8 ? 1 : 2);
        final edge =
            x == 0 ||
            x == 15 ||
            y == 0 ||
            y == 15 ||
            rows[y][x - 1] != '#' ||
            rows[y][x + 1] != '#' ||
            rows[y - 1][x] != '#' ||
            rows[y + 1][x] != '#';
        paint.color = edge
            ? mask == 15
                  ? const Color(0xFFFFD594)
                  : const Color(0xFF758A9E)
            : mask & part != 0
            ? const Color(0xFFFF8676)
            : const Color(0xFF263547);
        canvas.drawRect(Rect.fromLTWH(x.toDouble(), y.toDouble(), 1, 1), paint);
      }
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(HeartPartPainter oldDelegate) => mask != oldDelegate.mask;
}

class HeartInventory extends StatelessWidget {
  const HeartInventory({super.key, required this.slots, this.completedSlot});
  final List<int> slots;
  final int? completedSlot;
  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: List.generate(3, (index) {
      final completed = completedSlot == index && slots[index] == 0;
      final mask = completed ? 15 : slots[index];
      final count = [1, 2, 4, 8].where((part) => mask & part != 0).length;
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 2),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            HeartParts(
              key: ValueKey('heart-slot-$index'),
              mask: mask,
              size: 22,
            ),
            Text(
              completed ? '+1' : '$count/4',
              key: ValueKey('heart-count-$index'),
              style: TextStyle(
                fontSize: 8,
                color: completed
                    ? const Color(0xFFFFD594)
                    : const Color(0xFFB5C4D2),
              ),
            ),
          ],
        ),
      );
    }),
  );
}
