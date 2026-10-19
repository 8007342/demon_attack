import 'dart:math' as math;
import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/link.dart';

const eventUrl =
    'https://eventship.com/event/building-a-game-in-a-framework-i-ve-never-touched';
const ink = Color(0xFF090D12);
const muted = Color(0xFF849099);
const accent = Color(0xFFD0E4B0);

void main() => runApp(const DemonAttackApp());

class DemonAttackApp extends StatelessWidget {
  const DemonAttackApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'Demon Attack · Coded Live Oct 20',
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
          child: ExcludeSemantics(child: GameWidget(game: QuietSky())),
        ),
        SafeArea(
          child: LayoutBuilder(
            builder: (context, bounds) => SingleChildScrollView(
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: bounds.maxHeight),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 28,
                    vertical: 28,
                  ),
                  child: IntrinsicHeight(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.blur_on, color: accent, size: 22),
                            SizedBox(width: 10),
                            Text(
                              'DEMON ATTACK',
                              style: TextStyle(
                                fontSize: 12,
                                letterSpacing: 2.5,
                              ),
                            ),
                          ],
                        ),
                        const Spacer(),
                        Center(
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 560),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 9,
                                  ),
                                  decoration: BoxDecoration(
                                    border: Border.all(
                                      color: const Color(0xFF354038),
                                    ),
                                    borderRadius: BorderRadius.circular(4),
                                    color: const Color(0xFF111A16),
                                  ),
                                  child: const Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Icons.circle,
                                        size: 6,
                                        color: accent,
                                      ),
                                      SizedBox(width: 9),
                                      Text(
                                        'UNDER CONSTRUCTION',
                                        style: TextStyle(
                                          color: accent,
                                          fontSize: 10,
                                          letterSpacing: 1.7,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 32),
                                const Text(
                                  'A little chaos.\nBuilt from scratch.',
                                  style: TextStyle(
                                    fontSize: 14,
                                    height: 1.8,
                                    color: muted,
                                  ),
                                ),
                                const SizedBox(height: 16),
                                const Text(
                                  'Coded Live\nOct 20',
                                  semanticsLabel: 'Coded Live Oct 20',
                                  style: TextStyle(
                                    fontSize: 51,
                                    height: 1.13,
                                    letterSpacing: -3,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFFF0F0E8),
                                  ),
                                ),
                                const SizedBox(height: 24),
                                const Text(
                                  'An arcade classic, a new framework.\nWatch Demon Attack take shape,\none line at a time.',
                                  style: TextStyle(
                                    fontSize: 12,
                                    height: 1.9,
                                    color: muted,
                                  ),
                                ),
                                const SizedBox(height: 32),
                                Link(
                                  uri: Uri.parse(eventUrl),
                                  target: LinkTarget.blank,
                                  builder: (context, followLink) =>
                                      OutlinedButton(
                                        onPressed: followLink,
                                        style: OutlinedButton.styleFrom(
                                          foregroundColor: accent,
                                          side: const BorderSide(
                                            color: Color(0xFF48563F),
                                          ),
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 20,
                                            vertical: 19,
                                          ),
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(
                                              4,
                                            ),
                                          ),
                                        ),
                                        child: const Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Text(
                                              'Join the live build',
                                              style: TextStyle(fontSize: 12),
                                            ),
                                            SizedBox(width: 20),
                                            Icon(Icons.north_east, size: 16),
                                          ],
                                        ),
                                      ),
                                ),
                                const SizedBox(height: 20),
                                const Text(
                                  'LIVE CODING / OCTOBER 20',
                                  style: TextStyle(
                                    color: muted,
                                    fontSize: 9,
                                    letterSpacing: 1.5,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const Spacer(),
                        const SizedBox(height: 48),
                        const Divider(color: Color(0xFF252D32)),
                        const SizedBox(height: 12),
                        const Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'FLUTTER + FLAME',
                              style: TextStyle(
                                color: muted,
                                fontSize: 9,
                                letterSpacing: 1.3,
                              ),
                            ),
                            Text(
                              'INSERT CURIOSITY',
                              style: TextStyle(
                                color: muted,
                                fontSize: 9,
                                letterSpacing: 1.3,
                              ),
                            ),
                          ],
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

/// A static, understated Flame scene. No animation or motion sensitivity cost.
class QuietSky extends FlameGame {
  @override
  Color backgroundColor() => ink;

  @override
  void render(Canvas canvas) {
    super.render(canvas);
    final random = math.Random(1982);
    final paint = Paint()..color = const Color(0xFF263038);
    for (var i = 0; i < 65; i++) {
      final point = Offset(
        random.nextDouble() * size.x,
        random.nextDouble() * size.y,
      );
      canvas.drawRect(
        Rect.fromLTWH(point.dx, point.dy, i % 4 == 0 ? 2 : 1, 1),
        paint,
      );
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
