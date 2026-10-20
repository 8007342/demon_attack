import 'dart:math' as math;
import 'package:flame/game.dart';
import 'package:flutter/material.dart';

const ink = Color(0xFF090D12);
const accent = Color(0xFFD0E4B0);

void main() => runApp(const DemonAttackApp());

class DemonAttackApp extends StatelessWidget {
  const DemonAttackApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'Demon Attack · Under Construction',
    debugShowCheckedModeBanner: false,
    theme: ThemeData(
      brightness: Brightness.dark,
      scaffoldBackgroundColor: ink,
      colorScheme: ColorScheme.fromSeed(
        seedColor: accent,
        brightness: Brightness.dark,
      ),
      fontFamily: 'monospace',
    ),
    home: const LandingPage(),
  );
}

class LandingPage extends StatelessWidget {
  const LandingPage({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
    body: Stack(
      children: [
        Positioned.fill(
          child: ExcludeSemantics(
            child: GameWidget.controlled(gameFactory: QuietSky.new),
          ),
        ),
        SafeArea(
          child: LayoutBuilder(
            builder: (context, bounds) => SingleChildScrollView(
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: bounds.maxHeight),
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 28,
                      vertical: 48,
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Semantics(
                          label: 'Demon logo',
                          image: true,
                          child: const CustomPaint(
                            size: Size(144, 112),
                            painter: DemonLogoPainter(),
                          ),
                        ),
                        const SizedBox(height: 36),
                        const FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            'DEMON ATTACK',
                            semanticsLabel: 'Demon Attack',
                            style: TextStyle(
                              fontSize: 44,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 5,
                              color: Color(0xFFF0F0E8),
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),
                        const Text(
                          'UNDER CONSTRUCTION',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: accent,
                            fontSize: 11,
                            height: 1.8,
                            letterSpacing: 3,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    ),
  );
}

/// A crisp arcade demon mark drawn on a pixel grid.
class DemonLogoPainter extends CustomPainter {
  const DemonLogoPainter();

  static const pixels = [
    '010000000000010',
    '011000000000110',
    '011100000001110',
    '001111111111100',
    '000111111111000',
    '001110111011100',
    '111110111011111',
    '111111111111111',
    '110011111110011',
    '100001111100001',
    '000001010100000',
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final cell = math.min(size.width / 15, size.height / 11);
    final offset = Offset(
      (size.width - cell * 15) / 2,
      (size.height - cell * 11) / 2,
    );
    final paint = Paint()..color = accent;
    for (var y = 0; y < pixels.length; y++) {
      for (var x = 0; x < pixels[y].length; x++) {
        if (pixels[y][x] == '1') {
          canvas.drawRect(
            Rect.fromLTWH(
              offset.dx + x * cell,
              offset.dy + y * cell,
              cell,
              cell,
            ),
            paint,
          );
        }
      }
    }
  }

  @override
  bool shouldRepaint(DemonLogoPainter oldDelegate) => false;
}

/// A static, understated Flame scene. No animation or motion sensitivity cost.
class QuietSky extends FlameGame {
  @override
  Color backgroundColor() => ink;

  @override
  void render(Canvas canvas) {
    super.render(canvas);
    final random = math.Random(1982);
    final paint = Paint();
    for (var i = 0; i < 95; i++) {
      final point = Offset(
        random.nextDouble() * size.x,
        random.nextDouble() * size.y,
      );
      final bright = i % 7 == 0;
      paint.color = bright ? const Color(0xFFB5C8BC) : const Color(0xFF718895);
      final radius = bright ? 1.8 : 1.2;
      canvas.drawCircle(point, radius, paint);
      if (bright) {
        paint.color = const Color(0x228EAE9C);
        canvas.drawCircle(point, 4, paint);
      }
    }
    final glow = Paint()
      ..shader =
          const RadialGradient(
            colors: [Color(0x182E5348), Color(0x00090D12)],
          ).createShader(
            Rect.fromCircle(
              center: Offset(size.x, size.y * .45),
              radius: size.y * .6,
            ),
          );
    canvas.drawRect(Offset.zero & Size(size.x, size.y), glow);
  }
}
