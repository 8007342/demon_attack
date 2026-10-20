import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'model.dart';

const ink = Color(0xFF080D18);
const mint = Color(0xFF70F5D5);
const violet = Color(0xFFBDA7FF);
const gold = Color(0xFFF4CA79);

class DemonScene extends FlameGame {
  DemonScene(this.model, this.onTick);
  final ArcadeModel model;
  final VoidCallback onTick;
  ui.Image? atlas, sky;
  double ambient = 0, _notify = 0;
  double environment = 0;
  double keyboardDirection = 0;
  String? assetError;
  @override
  Color backgroundColor() => ink;
  @override
  Future<void> onLoad() async {
    try {
      atlas = await images.load('combat.png');
    } catch (e) {
      assetError = '$e';
    }
    try {
      sky = await images.load('cosmic-sky.png');
    } catch (e) {
      assetError = '$e';
    }
  }

  @override
  void update(double dt) {
    super.update(dt);
    if (model.mode != RunMode.paused) {
      ambient += dt;
      environment += (model.level - 1 - environment) * math.min(1, dt * .45);
    }
    if (model.combat && keyboardDirection != 0) {
      model.moveBy(keyboardDirection * dt * 280);
    }
    model.update(dt);
    _notify += dt;
    if (_notify > .05 || model.events.isNotEmpty) {
      _notify = 0;
      onTick();
    }
  }

  @override
  void render(Canvas canvas) {
    super.render(canvas);
    paintArena(canvas, size, combat: false);
  }

  void paintArena(Canvas canvas, Vector2 dimensions, {bool combat = true}) {
    final scale = math.min(
      dimensions.x / ArcadeModel.width,
      dimensions.y / ArcadeModel.height,
    );
    canvas.save();
    canvas.translate(
      (dimensions.x - ArcadeModel.width * scale) / 2,
      (dimensions.y - ArcadeModel.height * scale) / 2,
    );
    canvas.scale(scale);
    canvas.clipRect(const Rect.fromLTWH(0, 0, 360, 520));
    _background(canvas);
    final active = model.mode != RunMode.title;
    if (active && combat) _combat(canvas);
    canvas.restore();
  }

  void _background(Canvas c) {
    c.drawRect(const Rect.fromLTWH(0, 0, 360, 520), Paint()..color = ink);
    final image = sky;
    if (image != null) {
      // Generated texture stays behind the independently moving celestial layers.
      final w = image.width.toDouble(), h = image.height.toDouble();
      c.drawImageRect(
        image,
        Rect.fromLTWH(w * .2, 0, w * .6, h),
        const Rect.fromLTWH(0, 0, 360, 520),
        Paint()
          ..filterQuality = FilterQuality.none
          ..color = const Color(0x99506080),
      );
      c.drawRect(
        const Rect.fromLTWH(0, 0, 360, 520),
        Paint()..color = const Color(0x88080D18),
      );
    }
    final palettes = [
      const Color(0xFF67CFC2),
      const Color(0xFFAD8FE3),
      const Color(0xFFEF9A7D),
      const Color(0xFF8B9ACB),
      const Color(0xFFEFAE68),
    ];
    final base = environment.floor().clamp(0, 4);
    final tint = Color.lerp(
      palettes[base],
      palettes[math.min(4, base + 1)],
      environment - base,
    )!;
    final random = math.Random(1982);
    for (var i = 0; i < 100; i++) {
      final depth = i % 3 + 1;
      final x = random.nextDouble() * 360;
      final y = (random.nextDouble() * 520 + ambient * depth * 1.3) % 520;
      final alpha = i % 7 == 0 ? .8 : .25 + depth * .1;
      c.drawRect(
        Rect.fromLTWH(
          x.floorToDouble(),
          y.floorToDouble(),
          i % 7 == 0 ? 2 : 1,
          i % 7 == 0 ? 2 : 1,
        ),
        Paint()
          ..color = Color.lerp(
            tint,
            Colors.white,
            .5,
          )!.withValues(alpha: alpha),
      );
    }
    final rise = math.sin(ambient * .012 + environment * .48) * 48;
    final center = Offset(293, 113 - rise);
    c.save();
    c.translate(center.dx, center.dy);
    c.rotate(-.35);
    c.drawOval(
      const Rect.fromLTWH(-84, -16, 168, 32),
      Paint()
        ..color = tint.withValues(alpha: .22)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 8,
    );
    c.drawCircle(Offset.zero, 39, Paint()..color = const Color(0xFF272B49));
    for (var i = 0; i < 8; i++) {
      c.drawRect(
        Rect.fromLTWH(-33, -28 + i * 8, 66, 3),
        Paint()..color = tint.withValues(alpha: .06 + (i % 3) * .025),
      );
    }
    c.drawArc(
      const Rect.fromLTWH(-84, -16, 168, 32),
      0,
      math.pi,
      false,
      Paint()
        ..color = tint.withValues(alpha: .3)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 5,
    );
    c.restore();
    c.drawCircle(
      Offset(62, 174 + rise * .7),
      16,
      Paint()..color = tint.withValues(alpha: .16),
    );
    c.drawCircle(
      Offset(56, 170 + rise * .7),
      14,
      Paint()..color = const Color(0xFF11182A),
    );
    final horizon = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Colors.transparent, tint.withValues(alpha: .12)],
      ).createShader(const Rect.fromLTWH(0, 380, 360, 140));
    c.drawRect(const Rect.fromLTWH(0, 380, 360, 140), horizon);
    final path = Path()..moveTo(0, 520);
    for (var x = 0; x <= 360; x += 12) {
      path.lineTo(
        x.toDouble(),
        500 - math.sin(x * .053 + ambient * .009) * 7 - (x % 36 == 0 ? 7 : 0),
      );
    }
    path
      ..lineTo(360, 520)
      ..close();
    c.drawPath(path, Paint()..color = const Color(0xFF101E2C));
    c.drawLine(
      const Offset(0, 515),
      const Offset(360, 515),
      Paint()..color = tint.withValues(alpha: .35),
    );
  }

  void sprite(
    Canvas c,
    int row,
    int col,
    Offset center,
    double width, {
    double? height,
    Color? tint,
  }) {
    final a = atlas;
    if (a == null) return;
    final paint = Paint()..filterQuality = FilterQuality.none;
    if (tint != null) {
      paint.colorFilter = ColorFilter.mode(tint, BlendMode.srcATop);
    }
    c.drawImageRect(
      a,
      Rect.fromLTWH(col * 64.0, row * 64.0, 64, 64),
      Rect.fromCenter(center: center, width: width, height: height ?? width),
      paint,
    );
  }

  void _combat(Canvas c) {
    for (final p in model.pickups) {
      c.drawCircle(
        Offset(p.x, p.y),
        13,
        Paint()..color = mint.withValues(alpha: .12),
      );
      sprite(c, 4, 4 + p.power.index, Offset(p.x, p.y), 30);
    }
    for (final d in model.demons) {
      final frame =
          ((model.clock * 8 + d.seed).floor() % 4) + (d.angry ? 4 : 0);
      final pos = Offset(d.x, d.y);
      if (d.telegraph > 0) {
        c.drawCircle(
          pos,
          22,
          Paint()
            ..color = const Color(0xAAFF786C)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1,
        );
        c.drawLine(
          pos + const Offset(0, 22),
          pos + const Offset(0, 36),
          Paint()..color = const Color(0x66FF786C),
        );
      }
      sprite(
        c,
        d.hp < d.maxHp && !d.angry
            ? 8 + d.kind * 3 + (d.maxHp - d.hp - 1).clamp(0, 2)
            : d.kind,
        frame,
        pos,
        d.angry ? 44 : 40,
        tint: d.flash > 0 ? Colors.white : null,
      );
      if (d.hp > 1) {
        for (var i = 0; i < d.hp; i++) {
          c.drawRect(
            Rect.fromLTWH(d.x - d.hp * 2 + i * 4, d.y - 22, 2, 2),
            Paint()..color = violet,
          );
        }
      }
    }
    final b = model.boss;
    if (b != null) {
      sprite(c, 6, b.phase, Offset(b.x, b.y), 184, height: 118);
      final core = Offset(b.x, b.y + 25);
      c.drawRect(
        Rect.fromCenter(center: core, width: 32, height: 22),
        Paint()..color = const Color(0xFF070A14),
      );
      c.drawRect(
        Rect.fromCenter(center: core, width: 24, height: 12),
        Paint()..color = b.shield > 0 ? violet : gold,
      );
      final closed = 16 * (1 - b.door);
      for (final direction in [-1, 1]) {
        c.drawRect(
          Rect.fromLTWH(
            core.dx + direction * 16 - (direction < 0 ? 0 : closed),
            core.dy - 11,
            closed,
            22,
          ),
          Paint()..color = const Color(0xFF57617E),
        );
      }
      if (b.shield > 0) {
        final shieldPaint = Paint()
          ..color = mint.withValues(alpha: .35 + math.sin(model.clock * 8) * .1)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3;
        c.drawArc(
          Rect.fromCenter(
            center: Offset(b.x, b.y + 24),
            width: 166,
            height: 38,
          ),
          0,
          math.pi,
          false,
          shieldPaint,
        );
        for (var x = -70; x <= 70; x += 14) {
          c.drawLine(
            Offset(b.x + x, b.y + 39),
            Offset(b.x + x + 5, b.y + 45),
            Paint()..color = mint.withValues(alpha: .35),
          );
        }
      }
      final remaining = b.shield > 0
          ? b.shield / b.shieldMax
          : b.core / b.coreMax;
      c.drawRect(
        const Rect.fromLTWH(72, 26, 216, 3),
        Paint()..color = const Color(0xFF263049),
      );
      c.drawRect(
        Rect.fromLTWH(72, 26, 216 * remaining, 3),
        Paint()..color = b.shield > 0 ? mint : gold,
      );
      _text(
        c,
        b.shield > 0 ? 'BREAK THE SHIELD' : 'SHOOT THROUGH THE DOOR',
        const Offset(180, 12),
        8,
        b.shield > 0 ? mint : gold,
      );
    }
    for (final s in model.shots) {
      final color = s.hostile ? const Color(0xFFFF8676) : mint;
      final paint = Paint()..color = color;
      if (s.hostile) {
        c.drawRect(
          Rect.fromCenter(center: Offset(s.x, s.y), width: 5, height: 7),
          paint,
        );
        c.drawRect(
          Rect.fromLTWH(s.x - 1, s.y - 2, 2, 3),
          Paint()..color = const Color(0xFFFFE3AF),
        );
      } else {
        c.drawRect(Rect.fromLTWH(s.x - 1, s.y - 5, 2, 10), paint);
        c.drawRect(
          Rect.fromLTWH(s.x - 2, s.y + 4, 4, 5),
          Paint()..color = color.withValues(alpha: .2),
        );
      }
    }
    if (model.mode != RunMode.gameOver &&
        (model.invulnerable == 0 || (model.clock * 12).floor() % 2 == 0)) {
      sprite(
        c,
        4,
        (model.clock * 14).floor() % 4,
        Offset(model.shipX, ArcadeModel.shipY),
        42,
      );
      if (model.power == Power.shield || model.invulnerable > 0) {
        c.drawCircle(
          Offset(model.shipX, ArcadeModel.shipY),
          22,
          Paint()
            ..color = mint.withValues(alpha: .5)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.5,
        );
      }
    }
    for (final b in model.blasts) {
      sprite(
        c,
        5,
        (b.age / .55 * 8).floor().clamp(0, 7),
        Offset(b.x, b.y),
        b.big ? 200 : 56,
      );
    }
  }

  void _text(Canvas c, String value, Offset center, double size, Color color) {
    final tp = TextPainter(
      text: TextSpan(
        text: value,
        style: TextStyle(
          color: color,
          fontSize: size,
          fontFamily: 'monospace',
          letterSpacing: 1,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(c, center - Offset(tp.width / 2, tp.height / 2));
  }
}
