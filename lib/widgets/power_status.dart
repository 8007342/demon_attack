import 'package:flutter/material.dart';

import '../game/model.dart';

const powerColors = <Power, Color>{
  Power.spread: Color(0xFF70F5D5),
  Power.rapid: Color(0xFFF4CA79),
  Power.shield: Color(0xFFA888FF),
  Power.powerful: Color(0xFFFF786C),
  Power.large: Color(0xFFFFAD53),
};
const powerNames = <Power, String>{
  Power.spread: 'SPREAD',
  Power.rapid: 'RAPID',
  Power.shield: 'SHIELD',
  Power.powerful: 'POWERFUL',
  Power.large: 'LARGE',
};

class PowerStatus extends StatelessWidget {
  const PowerStatus({
    super.key,
    required this.timers,
    this.homingMissiles = 0,
    this.compact = false,
  });
  final Map<Power, double> timers;

  /// Homing missiles still to fire; shown as a HOMING row with pips.
  final int homingMissiles;
  final bool compact;
  @override
  Widget build(BuildContext context) {
    final active = Power.values.where((p) => (timers[p] ?? 0) > 0).toList();
    if (active.isEmpty && homingMissiles <= 0) return const SizedBox.shrink();
    return Semantics(
      label:
          'Active power-ups: ${[for (final p in active) '${powerNames[p]} ${timers[p]!.ceil()} seconds', if (homingMissiles > 0) 'HOMING $homingMissiles missiles'].join(', ')}',
      child: ExcludeSemantics(
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: EdgeInsets.all(compact ? 2 : 5),
              decoration: BoxDecoration(
                color: const Color(0xEF0A1421),
                border: Border.all(color: const Color(0xFF46617A)),
              ),
              child: CustomPaint(
                key: const ValueKey('combined-power-glyph'),
                size: Size.square(compact ? 32 : 40),
                painter: PowerGlyphPainter(
                  active.toSet(),
                  homingMissiles: homingMissiles,
                ),
              ),
            ),
            SizedBox(width: compact ? 4 : 7),
            SizedBox(
              width: compact ? 86 : 92,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: active
                    .map<Widget>(
                      (p) => Padding(
                        padding: const EdgeInsets.symmetric(vertical: 3),
                        child: Column(
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  powerNames[p]!,
                                  style: TextStyle(
                                    color: powerColors[p],
                                    fontSize: 8,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: .5,
                                  ),
                                ),
                                Text(
                                  '${timers[p]!.ceil()}s',
                                  key: ValueKey('power-time-${p.name}'),
                                  style: const TextStyle(
                                    color: Color(0xFFE1EBF4),
                                    fontSize: 8,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 2),
                            SizedBox(
                              height: 2,
                              child: LinearProgressIndicator(
                                value: (timers[p]! / ArcadeModel.powerDuration)
                                    .clamp(0, 1),
                                color: powerColors[p],
                                backgroundColor: const Color(0xFF25384D),
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                    .toList()
                  ..addAll([
                    if (homingMissiles > 0) _homingRow(homingMissiles),
                  ]),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _homingRow(int count) => Padding(
    key: const ValueKey('power-homing'),
    padding: const EdgeInsets.symmetric(vertical: 3),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        const Text(
          homingName,
          style: TextStyle(
            color: homingColor,
            fontSize: 8,
            fontWeight: FontWeight.bold,
            letterSpacing: .5,
          ),
        ),
        Row(
          key: ValueKey('power-homing-$count'),
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var i = 0; i < 3; i++)
              Container(
                width: 4,
                height: 7,
                margin: const EdgeInsets.only(left: 2),
                color: i < count ? homingColor : const Color(0xFF25384D),
              ),
          ],
        ),
      ],
    ),
  );
}

/// Homing missiles: a salvo, not a timer (see ground_war.dart).
const homingColor = Color(0xFF6EDCFF);
const homingName = 'HOMING';

/// Side weapon layers leave room for a central bolt/heavy cannon and the outer
/// shield. Each mark uses the original logical pixel grid over a cockpit ship schematic.
class PowerGlyphPainter extends CustomPainter {
  const PowerGlyphPainter(this.active, {this.homingMissiles = 0});
  final Set<Power> active;

  /// Missiles left on the wing pylons (0-3), drawn under the wings.
  final int homingMissiles;
  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 32, size.height / 32);
    final paint = Paint()..isAntiAlias = false;

    // Stylized cockpit starfighter chassis schematic (dark slate tones distinct from powerColors).
    paint
      ..style = PaintingStyle.fill
      ..color = const Color(0xFF152536);
    canvas.drawPath(
      Path()
        ..moveTo(16, 4)
        ..lineTo(21, 14)
        ..lineTo(28, 22)
        ..lineTo(28, 27)
        ..lineTo(20, 25)
        ..lineTo(12, 25)
        ..lineTo(4, 27)
        ..lineTo(4, 22)
        ..lineTo(11, 14)
        ..close(),
      paint,
    );
    paint.color = const Color(0xFF233B52);
    canvas.drawRect(const Rect.fromLTWH(14, 9, 4, 15), paint);
    canvas.drawRect(const Rect.fromLTWH(7, 19, 18, 4), paint);

    if (active.contains(Power.shield)) {
      paint
        ..color = powerColors[Power.shield]!
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2;
      canvas.drawPath(
        Path()
          ..moveTo(16, 2)
          ..lineTo(29, 7)
          ..lineTo(27, 21)
          ..lineTo(16, 30)
          ..lineTo(5, 21)
          ..lineTo(3, 7)
          ..close(),
        paint,
      );
    }
    paint.style = PaintingStyle.fill;
    if (active.contains(Power.spread)) {
      paint.color = powerColors[Power.spread]!;
      // Twin side barrels leave the central modifier unobstructed.
      for (final x in [8.0, 24.0]) {
        canvas.drawPath(
          Path()
            ..moveTo(x - 3, 26)
            ..lineTo(x - 2, 10)
            ..lineTo(x + 2, 10)
            ..lineTo(x + 3, 26)
            ..close(),
          paint,
        );
        canvas.drawRect(Rect.fromLTWH(x - 3, 8, 6, 4), paint);
        canvas.drawRect(
          Rect.fromLTWH(x - 1, 8, 2, 3),
          Paint()..color = const Color(0xFF0A1421),
        );
        canvas.drawRect(Rect.fromLTWH(x - 1, 3, 2, 3), paint);
      }
    }
    if (active.contains(Power.large)) {
      paint.color = powerColors[Power.large]!;
      // Wide explosive shells and their stepped bursts occupy the side lanes.
      for (final x in [8.0, 24.0]) {
        canvas.drawRect(Rect.fromLTWH(x - 3, 12, 6, 11), paint);
        canvas.drawRect(Rect.fromLTWH(x - 2, 10, 4, 2), paint);
        canvas.drawRect(Rect.fromLTWH(x - 2, 24, 4, 2), paint);
        canvas.drawRect(Rect.fromLTWH(x - 1, 5, 2, 3), paint);
        canvas.drawRect(Rect.fromLTWH(x - 4, 8, 2, 2), paint);
        canvas.drawRect(Rect.fromLTWH(x + 2, 8, 2, 2), paint);
        canvas.drawRect(
          Rect.fromLTWH(x - 1, 14, 2, 6),
          Paint()..color = const Color(0xFF0A1421),
        );
      }
    }
    if (active.contains(Power.powerful)) {
      paint.color = powerColors[Power.powerful]!;
      // A chunky central double-shell cannon, with an open muzzle.
      canvas.drawRect(const Rect.fromLTWH(13, 11, 6, 15), paint);
      canvas.drawRect(const Rect.fromLTWH(12, 8, 8, 5), paint);
      canvas.drawRect(
        const Rect.fromLTWH(14, 8, 4, 3),
        Paint()..color = const Color(0xFF0A1421),
      );
      canvas.drawRect(const Rect.fromLTWH(13, 3, 2, 3), paint);
      canvas.drawRect(const Rect.fromLTWH(17, 3, 2, 3), paint);
      canvas.drawRect(
        const Rect.fromLTWH(15, 15, 2, 7),
        Paint()..color = const Color(0xFFFFD6A4),
      );
    }
    if (active.contains(Power.rapid)) {
      final bolt = Path()
        ..moveTo(17, 4)
        ..lineTo(11, 18)
        ..lineTo(16, 18)
        ..lineTo(13, 28)
        ..lineTo(23, 13)
        ..lineTo(18, 13)
        ..lineTo(22, 4)
        ..close();
      canvas.drawPath(
        bolt,
        Paint()
          ..isAntiAlias = false
          ..color = const Color(0xFF0A1421)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2,
      );
      canvas.drawPath(bolt, paint..color = powerColors[Power.rapid]!);
    }
    if (homingMissiles > 0) {
      // Pylon missiles under the wings: left outer, right outer, left inner.
      const slots = [(5.0, 18.0), (26.0, 18.0), (9.0, 21.0)];
      for (var i = 0; i < 3; i++) {
        if (i < 3 - homingMissiles.clamp(0, 3)) continue;
        final (x, y) = slots[i];
        canvas.drawRect(Rect.fromLTWH(x, y, 2, 7), paint..color = const Color(0xFFD8E2FF));
        canvas.drawRect(Rect.fromLTWH(x, y - 1, 2, 1), paint..color = const Color(0xFF70F5D5));
        canvas.drawRect(Rect.fromLTWH(x, y + 7, 2, 2), paint..color = homingColor);
      }
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(PowerGlyphPainter oldDelegate) =>
      homingMissiles != oldDelegate.homingMissiles ||
      active.length != oldDelegate.active.length ||
      !active.containsAll(oldDelegate.active);
}
