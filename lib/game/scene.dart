import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flame/game.dart';
import 'package:flutter/material.dart';

import 'model.dart';
import 'sector_background.dart';
import '../services/scores.dart';
import '../widgets/heart_parts.dart';

const ink = Color(0xFF080D18);
const mint = Color(0xFF70F5D5);
const violet = Color(0xFFBDA7FF);
const gold = Color(0xFFF4CA79);

class DemonScene extends FlameGame {
  DemonScene(this.model, this.onTick);
  final ArcadeModel model;
  final VoidCallback onTick;
  ui.Image? atlas, effectsAtlas, sky, bossAtlas, cockpitAtlas;
  final sectors = SectorBackground();
  List<ScoreEntry> topScores = const [];
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
      effectsAtlas = await images.load('sentinel-effects.png');
    } catch (e) {
      assetError = '$e';
    }
    try {
      sky = await images.load('cosmic-sky.png');
    } catch (e) {
      assetError = '$e';
    }
    try {
      bossAtlas = await images.load('boss-carrier.png');
    } catch (_) {}
    try {
      cockpitAtlas = await images.load('cockpit-panel.png');
    } catch (_) {}
    await Future.wait(
      List.generate(5, (i) async {
        try {
          sectors.images[i] = await images.load('sector-${i + 1}.png');
        } catch (_) {
          /* Keep the original sky as a fallback. */
        }
      }),
    );
  }

  @override
  void update(double dt) {
    super.update(dt);
    if (model.mode != RunMode.paused) {
      ambient += dt;
      final destination = model.presentationMode == RunMode.travel
          ? model.nextLevel - 1
          : model.level - 1;
      environment += (destination - environment) * math.min(1, dt * .65);
    }
    if (model.canPilot && keyboardDirection != 0) {
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
    final panY = model.mode == RunMode.gameOver ? model.cameraPanY : 0.0;
    if (panY > 0.5) {
      _deepStarfieldPan(canvas, panY);
      canvas.save();
      canvas.translate(0, panY);
      _background(canvas);
      final active = model.mode != RunMode.title;
      if (active && combat) {
        _combat(canvas);
        _cinematic(canvas);
      }
      canvas.restore();
    } else {
      _background(canvas);
      final active = model.mode != RunMode.title;
      if (active && combat) {
        _combat(canvas);
        _cinematic(canvas);
      }
    }
    canvas.restore();
  }

  void _deepStarfieldPan(Canvas c, double panY) {
    c.drawRect(
      const Rect.fromLTWH(0, 0, 360, 520),
      Paint()..color = const Color(0xFF050811),
    );
    final s = sky;
    if (s != null) {
      final imageRatio = s.width / s.height;
      const ratio = 360 / 520;
      final source = imageRatio > ratio
          ? Rect.fromLTWH(
              (s.width - s.height * ratio) / 2,
              0,
              s.height * ratio,
              s.height.toDouble(),
            )
          : Rect.fromLTWH(
              0,
              (s.height - s.width / ratio) / 2,
              s.width.toDouble(),
              s.width / ratio,
            );
      c.drawImageRect(
        s,
        source,
        Rect.fromLTWH(0, panY - 520, 360, 520),
        Paint()..filterQuality = FilterQuality.none,
      );
      c.drawRect(
        const Rect.fromLTWH(0, 0, 360, 520),
        Paint()..color = const Color(0x70050812),
      );
    }
    final rng = math.Random(4096 + model.level * 131);
    final paint = Paint()..isAntiAlias = false;
    for (var i = 0; i < 96; i++) {
      final depth = (i % 3) + 1;
      final sx = (rng.nextDouble() * 356 + 2).floorToDouble();
      final baseY = rng.nextDouble() * 520;
      final sy = ((baseY + panY * (0.35 + depth * 0.22)) % 520).floorToDouble();
      final twinkle =
          0.35 + 0.55 * math.sin(model.visualClock * 3.5 + i * 1.7).abs();
      paint.color = (i % 7 == 0
              ? gold
              : (i % 4 == 0 ? mint : const Color(0xFFD8E6FF)))
          .withValues(alpha: (twinkle * (0.28 + depth * 0.18)).clamp(0.1, 0.95));
      final sz = i % 11 == 0 ? 2.0 : 1.0;
      c.drawRect(Rect.fromLTWH(sx, sy, sz, sz), paint);
    }

    // Stylized Top Scores Leaderboard rolling down with the starfield canopy during defeat pan
    final boardY = (panY - 520.0);
    if (boardY > -480.0) {
      _paintDefeatLeaderboard(c, boardY);
    }
  }

  void _paintDefeatLeaderboard(Canvas c, double boardY) {
    // Dark translucent backdrop panel
    final cardRect = Rect.fromLTWH(24, boardY + 60, 312, 380);
    c.drawRect(
      cardRect,
      Paint()..color = const Color(0xF2070D18),
    );
    c.drawRect(
      cardRect,
      Paint()
        ..color = const Color(0xFF344D66)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );

    // Decorative corner brackets
    final cornerPaint = Paint()
      ..color = mint
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;
    const clen = 10.0;
    c.drawPath(Path()..moveTo(24, boardY + 60 + clen)..lineTo(24, boardY + 60)..lineTo(24 + clen, boardY + 60), cornerPaint);
    c.drawPath(Path()..moveTo(336 - clen, boardY + 60)..lineTo(336, boardY + 60)..lineTo(336, boardY + 60 + clen), cornerPaint);
    c.drawPath(Path()..moveTo(24, boardY + 440 - clen)..lineTo(24, boardY + 440)..lineTo(24 + clen, boardY + 440), cornerPaint);
    c.drawPath(Path()..moveTo(336 - clen, boardY + 440)..lineTo(336, boardY + 440)..lineTo(336, boardY + 440 - clen), cornerPaint);

    // Header text
    _paintBitmapText(
      c,
      'HALL OF FAME',
      Offset(180, boardY + 84),
      gold,
      fontSize: 16,
      centered: true,
      letterSpacing: 2.0,
    );
    _paintBitmapText(
      c,
      'KRYBOR FLEET TOP DEFENDERS',
      Offset(180, boardY + 106),
      const Color(0xFF8BA2B8),
      fontSize: 9,
      centered: true,
      letterSpacing: 1.2,
    );

    // Final score callout
    c.drawRect(
      Rect.fromLTWH(36, boardY + 122, 288, 38),
      Paint()..color = const Color(0x3370F5D5),
    );
    c.drawRect(
      Rect.fromLTWH(36, boardY + 122, 288, 38),
      Paint()
        ..color = mint.withValues(alpha: 0.5)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1,
    );
    _paintBitmapText(
      c,
      'YOUR SCORE: ${model.score}',
      Offset(180, boardY + 144),
      mint,
      fontSize: 14,
      centered: true,
      letterSpacing: 1.5,
    );

    // Score entries list
    final entries = topScores.isNotEmpty
        ? topScores.take(5).toList()
        : [
            ScoreEntry('ACE', 14200, difficulty: model.difficulty, medals: 5),
            ScoreEntry('CMD', 9850, difficulty: model.difficulty, medals: 3),
            ScoreEntry('SKY', 6420, difficulty: model.difficulty, medals: 2),
            ScoreEntry('FOX', 4100, difficulty: model.difficulty, medals: 1),
            ScoreEntry('ROO', 2280, difficulty: model.difficulty, medals: 0),
          ];

    var entryY = boardY + 182;
    for (var i = 0; i < entries.length; i++) {
      final entry = entries[i];
      final isTop = i == 0;
      final rankColor = isTop ? gold : const Color(0xFFCCD9E6);
      final scoreColor = isTop ? gold : Colors.white;

      _paintBitmapText(
        c,
        '#${i + 1}  ${entry.initials}',
        Offset(52, entryY),
        rankColor,
        fontSize: 11,
      );
      _paintBitmapText(
        c,
        '${entry.score}',
        Offset(250, entryY),
        scoreColor,
        fontSize: 11,
      );
      if (entry.medals > 0) {
        _paintBitmapText(
          c,
          '★${entry.medals}',
          Offset(290, entryY),
          gold,
          fontSize: 10,
        );
      }
      entryY += 28;
    }

    // Interactive skip / continue prompt
    final blink = (math.sin(model.visualClock * 6).abs() * 0.7 + 0.3).clamp(0.0, 1.0);
    _paintBitmapText(
      c,
      'TAP OR PRESS ANY KEY TO SUBMIT',
      Offset(180, boardY + 418),
      mint.withValues(alpha: blink),
      fontSize: 9,
      centered: true,
      letterSpacing: 1.2,
    );
  }

  void _paintBitmapText(
    Canvas c,
    String text,
    Offset pos,
    Color color, {
    double fontSize = 12,
    bool centered = false,
    double letterSpacing = 1.0,
  }) {
    final painter = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          color: color,
          fontSize: fontSize,
          fontWeight: FontWeight.bold,
          letterSpacing: letterSpacing,
          fontFamily: 'monospace',
        ),
      ),
      textDirection: TextDirection.ltr,
    );
    painter.layout();
    final drawPos = centered
        ? Offset(pos.dx - painter.width / 2, pos.dy - painter.height / 2)
        : pos;
    painter.paint(c, drawPos);
  }

  void _background(Canvas c) =>
      sectors.paint(c, environment, ambient, model.cycle, sky, wave: model.wave);

  void bossSprite(
    Canvas c,
    int row,
    int col,
    Offset center,
    double width, {
    double? height,
    Color? tint,
    double opacity = 1,
    bool flipX = false,
  }) {
    final image = bossAtlas;
    if (image == null) return;
    final paint = Paint()
      ..isAntiAlias = false
      ..color = Colors.white.withValues(alpha: opacity)
      ..filterQuality = FilterQuality.none;
    if (tint != null) {
      paint.colorFilter = ColorFilter.mode(tint, BlendMode.srcATop);
    }
    final h = height ?? (width * 240.0 / 368.0);
    if (flipX) {
      c.save();
      c.translate(center.dx, center.dy);
      c.scale(-1, 1);
      c.drawImageRect(
        image,
        Rect.fromLTWH(col * 368.0, row * 240.0, 368, 240),
        Rect.fromCenter(center: Offset.zero, width: width, height: h),
        paint,
      );
      c.restore();
    } else {
      c.drawImageRect(
        image,
        Rect.fromLTWH(col * 368.0, row * 240.0, 368, 240),
        Rect.fromCenter(center: center, width: width, height: h),
        paint,
      );
    }
  }

  void sprite(
    Canvas c,
    int row,
    int col,
    Offset center,
    double width, {
    double? height,
    Color? tint,
    double opacity = 1,
  }) {
    final a = atlas;
    if (a == null) return;
    final paint = Paint()
      ..isAntiAlias = false
      ..color = Colors.white.withValues(alpha: opacity)
      ..filterQuality = FilterQuality.none;
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

  // Every effects cell is 64x32 logical pixels, enlarged exactly 2x in
  // the PNG. Integer destinations preserve the original square-pixel grid.
  void effectSprite(
    Canvas c,
    int row,
    int col,
    Offset center, {
    double scale = 1,
    Color? tint,
    double opacity = 1,
  }) {
    final image = effectsAtlas;
    if (image == null) return;
    final paint = Paint()
      ..isAntiAlias = false
      ..color = Colors.white.withValues(alpha: opacity)
      ..filterQuality = FilterQuality.none;
    if (tint != null) {
      paint.colorFilter = ColorFilter.mode(tint, BlendMode.srcATop);
    }
    c.drawImageRect(
      image,
      Rect.fromLTWH(col * 128.0, row * 64.0, 128, 64),
      Rect.fromLTWH(
        (center.dx - 64 * scale).roundToDouble(),
        (center.dy - 32 * scale).roundToDouble(),
        128 * scale,
        64 * scale,
      ),
      paint,
    );
  }

  void _combat(Canvas c) {
    for (final p in model.heartPickups) {
      c.save();
      c.translate(p.x - 10, p.y - 10);
      HeartPartPainter(p.part.mask).paint(c, const Size(20, 20));
      c.restore();
    }
    for (final p in model.pickups) {
      c.drawCircle(
        Offset(p.x, p.y),
        13,
        Paint()..color = mint.withValues(alpha: .12),
      );
      switch (p.power) {
        case Power.powerful:
          effectSprite(c, 5, 4, Offset(p.x, p.y), scale: .5);
        case Power.large:
          effectSprite(c, 5, 5, Offset(p.x, p.y), scale: .5);
        case Power.spread:
        case Power.rapid:
        case Power.shield:
          sprite(c, 4, 4 + p.power.index, Offset(p.x, p.y), 30);
      }
    }
    for (final crate in model.supplyCrates) {
      _paintSupplyCrate(c, crate);
    }
    for (final d in model.demons) {
      // Ordinary tells are changes to the existing monster animation only:
      // quicker cocked wing frames and the atlas's own angry eyes/palette.
      final warning = d.telegraph > 0;
      final frame = warning
          ? 4 + ((model.clock * 12 + d.seed).floor() % 2)
          : ((model.clock * 8 + d.seed).floor() % 4) + (d.angry ? 4 : 0);
      final pos = Offset(d.x, d.y);
      if (d.isLarge) {
        // Large creatures have their own delayed entrance in simulation.
        if (d.entranceProgress > 0) {
          _sentinel(c, pos, d);
        }
        continue;
      }
      if (d.elite) {
        final armor = (d.maxHp - d.moltStage).clamp(1, 7);
        for (var i = 0; i < 12; i++) {
          if ((i + (model.clock * 2).floor()) % 4 == 0) continue;
          final angle = i * math.pi / 6;
          c.drawRect(
            Rect.fromLTWH(
              (pos.dx + math.cos(angle) * 24).roundToDouble(),
              (pos.dy + math.sin(angle) * 24).roundToDouble(),
              2,
              2,
            ),
            Paint()..color = d.angry ? gold : violet,
          );
        }
        // Every hit removes an outer plate; stages beyond the atlas's three
        // molts still have a visibly distinct silhouette and exposed core.
        for (var plate = 0; plate < armor; plate++) {
          final angle = math.pi + plate * math.pi / math.max(1, armor - 1);
          final offset = Offset(math.cos(angle) * 21, math.sin(angle) * 21);
          c.drawRect(
            Rect.fromCenter(center: pos + offset, width: 4, height: 5),
            Paint()..color = (d.angry ? gold : violet).withValues(alpha: .7),
          );
        }
        if (d.moltStage < 4) {
          for (final side in [-1.0, 1.0]) {
            for (var step = 0; step < 5 - d.moltStage; step++) {
              c.drawRect(
                Rect.fromLTWH(
                  (pos.dx + side * (10 + step)).roundToDouble(),
                  (pos.dy - 12 - step * 2).roundToDouble(),
                  2,
                  3,
                ),
                Paint()..color = d.angry ? gold : violet,
              );
            }
          }
        }
      }
      final bank = d.bank.abs() > 0.01
          ? d.bank.clamp(-1.0, 1.0)
          : (d.vx / 140).clamp(-1.0, 1.0);
      c.save();
      if (bank.abs() > 0.04) {
        c.translate(pos.dx, pos.dy);
        c.rotate(bank * 0.09);
        c.scale(1.0 - bank.abs() * 0.1, 1.0);
        c.translate(-pos.dx, -pos.dy);
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
      _creatureLighting(c, pos, bank, width: d.angry ? 36 : 32, diving: d.dive > 0);
      c.restore();
      if (warning) {
        _wingTellChevrons(c, pos);
      }
      if (d.dive > 0 && d.diveShield > 0) {
        _smallOrMediumDiveShield(c, pos, d);
      }
      if (d.hp > 1) {
        for (var i = 0; i < d.hp; i++) {
          c.drawRect(
            Rect.fromLTWH(pos.dx - d.hp * 2 + i * 4, pos.dy - 22, 2, 2),
            Paint()..color = violet,
          );
        }
      }
    }
    final b = model.boss;
    if (b != null) {
      c.save();
      if (model.presentationMode == RunMode.transition) {
        final p = model.transitionProgress.clamp(0.0, 1.0);
        final descent = 1 - Curves.easeOutCubic.transform(p);
        c.translate(0, -180 * descent);
        _bossOrbitalArrivalEffects(c, b, p, descent);
      }
      final carrierBank = (b.horizontalVelocity / 90).clamp(-1.0, 1.0);
      final hullDamage = (1 - b.core / b.coreMax).clamp(0.0, 1.0);
      if (bossAtlas != null) {
        final mandibleFrame = model.presentationMode == RunMode.transition
            ? (model.transitionProgress * 3.99).floor().clamp(0, 3)
            : b.sideHatchesLocked
            ? 0
            : ((model.visualClock * (3 + b.rage * 4) + b.door * 2).floor() % 4);
        bossSprite(
          c,
          1,
          mandibleFrame,
          Offset(b.x, b.y),
          184,
          height: 120,
        );
        bossSprite(
          c,
          0,
          b.phase.clamp(0, 3),
          Offset(b.x, b.y),
          184,
          height: 120,
        );
        if (hullDamage > 0.15) {
          bossSprite(
            c,
            3,
            hullDamage > 0.55 ? 1 : 0,
            Offset(b.x, b.y),
            184,
            height: 120,
            opacity: (hullDamage * 0.95).clamp(0.2, 1.0),
          );
        }
        final turretFrame =
            ((model.visualClock * 6 + (model.shipX > b.x ? 1 : 0)).floor() % 4);
        bossSprite(
          c,
          2,
          turretFrame,
          Offset(b.x, b.y),
          184,
          height: 120,
        );
        _carrierTurretBarrels(c, b);
      } else {
        sprite(c, 6, b.phase, Offset(b.x, b.y), 184, height: 118);
      }
      _carrierLighting(c, Offset(b.x, b.y), carrierBank);
      _carrierEyes(c, b);
      _carrierSideHatches(c, b);
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
            core.dx + (direction < 0 ? -16 : 16 - closed),
            core.dy - 11,
            closed,
            22,
          ),
          Paint()..color = const Color(0xFF57617E),
        );
      }
      if (b.shield > 0) {
        // A fixed-width egg encases the hull; depletion brings its surface
        // inward vertically, so incoming fire visibly reaches nearer the ship.
        final strength = b.shield / b.shieldMax;
        final paint = Paint()..isAntiAlias = false;
        final Color shieldColor;
        if (strength > 0.6) {
          shieldColor = mint;
        } else if (strength > 0.25) {
          // Stressed force field shifts to electric jade/lime with fracture flicker
          shieldColor = const Color(0xFF45E898);
        } else {
          // Critical force field flickers rapidly with warning energy
          final flicker = (math.sin(model.visualClock * 24) + 1.0) * 0.5;
          shieldColor = Color.lerp(
            const Color(0xFF50E070),
            const Color(0xFF70F050),
            flicker,
          )!;
        }

        for (var offset = 0.0; offset <= b.forceFieldHalfWidth; offset += 2) {
          for (final side in [-1.0, 1.0]) {
            final worldX = b.x + side * offset;
            final surface = b.forceFieldSurfaceY(worldX);
            paint.color = shieldColor.withValues(alpha: .65 + strength * .3);
            c.drawRect(
              Rect.fromLTWH(
                (worldX - 1).roundToDouble(),
                surface.roundToDouble(),
                2,
                strength > .5 ? 3 : 2,
              ),
              paint,
            );
            if (strength > .25) {
              paint.color = violet.withValues(alpha: .22 + strength * .2);
              c.drawRect(
                Rect.fromLTWH(
                  (worldX - 1).roundToDouble(),
                  surface.roundToDouble() - 4,
                  2,
                  2,
                ),
                paint,
              );
            }
          }
        }
        if (strength <= 0.6) {
          final arcP = Paint()
            ..color = shieldColor.withValues(alpha: 0.8)
            ..strokeWidth = 1.5;
          final arcX =
              b.x + math.sin(model.visualClock * 9) * (b.forceFieldHalfWidth * 0.7);
          final arcY = b.forceFieldSurfaceY(arcX);
          c.drawLine(Offset(arcX - 6, arcY - 3), Offset(arcX + 4, arcY + 2), arcP);
        }
      }
      _damage(c, Offset(b.x, b.y), hullDamage, model.visualClock);
      c.restore();
    }
    for (final s in model.shots) {
      final x = s.x.roundToDouble(), y = s.y.roundToDouble();
      final p = Paint()..isAntiAlias = false;
      void block(double dx, double dy, double w, double h, Color color) {
        p.color = color;
        c.drawRect(Rect.fromLTWH(x + dx, y + dy, w, h), p);
      }

      if (!s.hostile && s.vx.abs() > 4) {
        // Stepped pixel angled plasma wake/tail for slung or spread shots.
        final wakeDx = (-s.vx * 0.025).clamp(-6.0, 6.0);
        for (var step = 1; step <= 3; step++) {
          final f = step / 3.0;
          block(
            (wakeDx * f - 1).roundToDouble(),
            (4 + step * 2).toDouble(),
            2,
            2,
            (s.kind == ShotKind.powerful || s.damage > 1 ? gold : mint)
                .withValues(alpha: (0.55 - step * 0.14).clamp(0.1, 0.6)),
          );
        }
      }

      if (s.kind == ShotKind.sentinel) {
        // Fast hostile bolts have a forked red head and an amber central spine.
        block(-2, -7, 4, 11, const Color(0xFFFF4C70));
        block(-4, -2, 2, 6, const Color(0xFFFF8676));
        block(2, -2, 2, 6, const Color(0xFFFF8676));
        block(-1, -4, 2, 10, const Color(0xFFFFE3AF));
        block(-1, 6, 2, 2, const Color(0xFFFF4C70));
      } else if (s.kind == ShotKind.large) {
        final rim = s.damage > 1 ? gold : violet;
        block(-3, -5, 6, 10, rim);
        block(-5, -2, 10, 5, rim);
        block(-2, -7, 4, 2, const Color(0xFFFFF5C9));
        block(-2, -2, 4, 5, const Color(0xFFFFF5C9));
        block(-1, 5, 2, 4, mint);
      } else if (s.kind == ShotKind.powerful) {
        block(-2, -5, 4, 10, gold);
        block(-1, -7, 2, 10, const Color(0xFFFFF5C9));
        block(-3, 3, 6, 2, gold);
        block(-1, 5, 2, 4, mint);
      } else if (s.hostile) {
        block(-2, -3, 5, 7, const Color(0xFFFF8676));
        block(-1, -2, 2, 3, const Color(0xFFFFE3AF));
      } else {
        block(-1, -5, 2, 10, mint);
        block(-2, 4, 4, 5, mint.withValues(alpha: .2));
      }
    }
    if (model.mode != RunMode.gameOver &&
        model.presentationMode != RunMode.levelClear &&
        model.presentationMode != RunMode.travel &&
        model.presentationMode != RunMode.victory &&
        model.presentationMode != RunMode.transition &&
        (model.invulnerable == 0 || (model.clock * 12).floor() % 2 == 0)) {
      _playerShip(c);
    }
    if (model.defeatActive) {
      _defeatCelebration(c);
    }
    for (final b in model.blasts) {
      if (b.age < 0) continue;
      if (b.isLarge) {
        effectSprite(
          c,
          4,
          (b.age / 1.4 * 8).floor().clamp(0, 7),
          Offset(b.x, b.y + (b.age * 12).floorToDouble()),
          opacity: .65,
        );
        continue;
      }
      sprite(
        c,
        5,
        (b.age / .55 * 8).floor().clamp(0, 7),
        Offset(b.x, b.y),
        b.blastRadius > 0
            ? 32
            : b.big
            ? 200
            : 56,
        opacity: b.blastRadius > 0 ? .5 : .65,
      );
    }
  }

  void _damage(Canvas c, Offset center, double damage, double time) {
    if (damage < .12) return;
    // Paired vents preserve the carrier's silhouette. Animation is held at
    // eight frames/sec, with solid dithered smoke rather than soft particles.
    for (var vent = 0; vent < (damage * 4).ceil(); vent++) {
      final frame = (time * 8 + vent).floor() % 4;
      for (final side in [-1.0, 1.0]) {
        final point =
            center + Offset(side * (18 + vent * 13), -3 - vent % 2 * 8);
        effectSprite(
          c,
          3,
          frame,
          point + Offset(side * frame * 2, -10.0 - frame * 5),
          scale: .5,
        );
        if (damage > .4) {
          effectSprite(c, 5, frame, point, scale: .5);
        }
        if (damage > .65) {
          effectSprite(c, 3, 4 + frame, point + const Offset(0, -8), scale: .5);
        }
      }
    }
  }

  void _carrierEyes(Canvas c, Carrier carrier) {
    if (carrier.rage <= 0) return;
    // Match the native hull eye pixels. Stepped red surrounds supply glow
    // without blurred circles; the hotter inner pixels remain symmetrical.
    final center = Offset(carrier.x.roundToDouble(), carrier.y.roundToDouble());
    final pulse = (model.clock * 6).floor().isEven ? .12 : 0.0;
    final hot = Color.lerp(gold, const Color(0xFFFF274E), carrier.rage)!;
    final paint = Paint()..isAntiAlias = false;
    for (var column = 0; column < 6; column++) {
      final x = 17.0 + column * 6;
      final y = 12.0 - column ~/ 2 * 4;
      for (final side in [-1.0, 1.0]) {
        final left = center.dx + side * x - 3;
        paint.color = const Color(0xFFFF274E)
            .withValues(alpha: carrier.rage * (.18 + pulse));
        c.drawRect(Rect.fromLTWH(left - 2, center.dy + y - 2, 10, 12), paint);
        paint.color = hot;
        c.drawRect(Rect.fromLTWH(left, center.dy + y, 6, 8), paint);
        if (carrier.rage > .6 && column < 3) {
          paint.color = const Color(0xFFFFC7AF);
          c.drawRect(Rect.fromLTWH(left + 2, center.dy + y + 4, 2, 2), paint);
        }
      }
    }
  }

  void _playerShip(Canvas c) {
    final center = Offset(model.shipX, ArcadeModel.shipY);
    final bank = model.shipBank.clamp(-1.0, 1.0);
    final thrust = model.shipThrust.clamp(0.0, 1.0);
    final paint = Paint()..isAntiAlias = false;

    // Angled ventral thruster flame opposite the bank direction.
    final flameLen = 7.0 + thrust * 6.0 + ((model.clock * 18).floor() % 2) * 2.0;
    final tailShift = (-bank * 5.0).roundToDouble();
    paint.color = mint.withValues(alpha: 0.48 + thrust * 0.25);
    c.drawRect(
      Rect.fromLTWH(
        (center.dx - 3 + tailShift * 0.5).roundToDouble(),
        (center.dy + 13).roundToDouble(),
        6,
        flameLen,
      ),
      paint,
    );
    paint.color = const Color(0xFFFFEDBF);
    c.drawRect(
      Rect.fromLTWH(
        (center.dx - 1 + tailShift).roundToDouble(),
        (center.dy + 14).roundToDouble(),
        2,
        (flameLen * 0.65).roundToDouble(),
      ),
      paint,
    );

    // Lateral counter-thruster puff on the side opposite the slide.
    if (bank.abs() > 0.08) {
      final puffSide = bank > 0 ? -1.0 : 1.0;
      paint.color = const Color(0xAA9FFFEA);
      c.drawRect(
        Rect.fromLTWH(
          (center.dx + puffSide * 19 - 1).roundToDouble(),
          (center.dy + 3).roundToDouble(),
          3,
          2,
        ),
        paint,
      );
    }

    c.save();
    c.translate(center.dx, center.dy);
    c.rotate(bank * 0.14);
    c.scale(1.0 - bank.abs() * 0.14, 1.0);
    c.translate(-center.dx, -center.dy);
    sprite(c, 4, (model.clock * 14).floor() % 4, center, 42);
    // 2.5D directional hemisphere & rim lighting on the banked ship wings/hull.
    if (bank.abs() > 0.08) {
      final raised = bank < 0 ? 1.0 : -1.0;
      final dipped = -raised;
      paint.color = const Color(0xCC9FFFEA);
      c.drawRect(
        Rect.fromLTWH(
          (center.dx + raised * 10 - 2).roundToDouble(),
          (center.dy - 4).roundToDouble(),
          5,
          2,
        ),
        paint,
      );
      paint.color = const Color(0xAAFFE699);
      c.drawRect(
        Rect.fromLTWH(
          (center.dx + raised * 15 - 1).roundToDouble(),
          (center.dy + 1).roundToDouble(),
          4,
          2,
        ),
        paint,
      );
      paint.color = const Color(0x880B0F29);
      c.drawRect(
        Rect.fromLTWH(
          (center.dx + dipped * 12 - 2).roundToDouble(),
          (center.dy - 1).roundToDouble(),
          5,
          4,
        ),
        paint,
      );
    }
    c.restore();

    // Twin rotating gun turret barrels and subtle aim vector reticle tick.
    final aim = model.aimAngle.clamp(-0.42, 0.42);
    final dirX = math.sin(aim);
    final dirY = -math.cos(aim);
    for (final side in [-1.0, 1.0]) {
      final mountX = (center.dx + side * 5).roundToDouble();
      final mountY = (center.dy - 10).roundToDouble();
      paint.color = const Color(0xFF232B42);
      c.drawRect(Rect.fromLTWH(mountX - 1, mountY - 1, 3, 3), paint);
      final tipX = (mountX + dirX * 5).roundToDouble();
      final tipY = (mountY + dirY * 5).roundToDouble();
      paint.color = mint;
      c.drawRect(
        Rect.fromLTWH(
          ((mountX + tipX) * 0.5 - 1).roundToDouble(),
          ((mountY + tipY) * 0.5 - 1).roundToDouble(),
          2,
          2,
        ),
        paint,
      );
      paint.color = const Color(0xFFFFF5C9);
      c.drawRect(Rect.fromLTWH(tipX - 1, tipY - 1, 2, 2), paint);
    }
    if (aim.abs() > 0.02 || model.steering.abs() > 0.05) {
      final reticleX = (center.dx + dirX * 24).roundToDouble();
      final reticleY = (center.dy + dirY * 24).roundToDouble();
      paint.color = gold.withValues(alpha: 0.8);
      c.drawRect(Rect.fromLTWH(reticleX - 1, reticleY - 1, 3, 2), paint);
      paint.color = const Color(0xFFFFF5C9).withValues(alpha: 0.9);
      c.drawRect(Rect.fromLTWH(reticleX, reticleY - 2, 1, 2), paint);
    }

    // Composable weapon attachments:
    // 1. Rapid fire: Wingtip dual accelerator cannons at (center.dx ± 16, center.dy + 2)
    if (model.hasPower(Power.rapid)) {
      final tRapid = model.timeLeft(Power.rapid);
      final overheat = tRapid < 2.5;
      final Color podColor = overheat
          ? Color.lerp(
              mint,
              const Color(0xFFFF3311),
              (math.sin(model.clock * 24) + 1) * 0.5,
            )!
          : const Color(0xFF6EDCFF);
      final pPod = Paint()..color = podColor;
      for (final side in [-1.0, 1.0]) {
        final wx = (center.dx + side * 16).roundToDouble();
        final wy = (center.dy + 2).roundToDouble();
        c.drawRect(
          Rect.fromLTWH(wx - 2, wy - 3, 4, 7),
          Paint()..color = const Color(0xFF1E2838),
        );
        c.drawRect(Rect.fromLTWH(wx - 1, wy - 5, 2, 4), pPod);
        if (overheat) {
          c.drawCircle(
            Offset(wx, wy - 7),
            2,
            Paint()..color = const Color(0x77FFAA33),
          );
        }
      }
    }

    // 2. Spread shot: Nose trifurcated prism emitter at (center.dx, center.dy - 13)
    if (model.hasPower(Power.spread)) {
      final tSpread = model.timeLeft(Power.spread);
      final overheat = tSpread < 2.5;
      final Color prismColor = overheat
          ? Color.lerp(
              gold,
              const Color(0xFFFF3311),
              (math.sin(model.clock * 24) + 1) * 0.5,
            )!
          : gold;
      c.drawRect(
        Rect.fromCenter(
          center: Offset(center.dx, center.dy - 13),
          width: 7,
          height: 4,
        ),
        Paint()..color = prismColor,
      );
      c.drawRect(
        Rect.fromCenter(
          center: Offset(center.dx, center.dy - 15),
          width: 3,
          height: 2,
        ),
        Paint()..color = Colors.white,
      );
      if (overheat) {
        c.drawCircle(
          Offset(center.dx, center.dy - 17),
          2,
          Paint()..color = const Color(0x77FFAA33),
        );
      }
    }

    // 3. Large / Explosive shot: Heavy hyper-plasma barrel between the dual turrets
    if (model.hasPower(Power.large)) {
      final tLarge = model.timeLeft(Power.large);
      final overheat = tLarge < 2.5;
      final Color cannonColor = overheat
          ? Color.lerp(
              const Color(0xFFFFAA00),
              const Color(0xFFFF2200),
              (math.sin(model.clock * 24) + 1) * 0.5,
            )!
          : const Color(0xFFFFAA33);
      c.drawRect(
        Rect.fromCenter(
          center: Offset(center.dx, center.dy - 11),
          width: 4,
          height: 8,
        ),
        Paint()..color = const Color(0xFF263345),
      );
      c.drawRect(
        Rect.fromCenter(
          center: Offset(center.dx, center.dy - 13),
          width: 2,
          height: 4,
        ),
        Paint()..color = cannonColor,
      );
      if (overheat) {
        c.drawCircle(
          Offset(center.dx, center.dy - 16),
          2.5,
          Paint()..color = const Color(0x88FF5522),
        );
      }
    }

    // Jettisoned overheated components tumbling off the ship
    for (final part in model.fallingParts) {
      c.save();
      c.translate(part.x, part.y);
      c.rotate(part.rotation);
      c.drawRect(
        const Rect.fromLTWH(-3, -3, 6, 6),
        Paint()..color = const Color(0xFFFF5522),
      );
      c.drawRect(
        const Rect.fromLTWH(-2, -2, 4, 4),
        Paint()..color = const Color(0xFF4A2518),
      );
      c.restore();
      c.drawCircle(
        Offset(part.x - part.vx * 0.05, part.y - part.vy * 0.05),
        2.5,
        Paint()..color = const Color(0x55888888),
      );
    }

    // Player Force Field with 3 Decay Stages
    final shieldTime = model.timeLeft(Power.shield);
    if (shieldTime > 0) {
      final Color shieldColor;
      final double ripple;
      if (shieldTime >= 4.5) {
        // Stage 1: Healthy Mint / Cyan
        shieldColor = mint;
        ripple = 0.0;
      } else if (shieldTime >= 2.0) {
        // Stage 2: Degrading Amber / Gold with ripple pulse
        final pulse = (math.sin(model.clock * 14) + 1) * 0.5;
        shieldColor = Color.lerp(gold, const Color(0xFFFF9900), pulse)!;
        ripple = pulse * 2.5;
      } else {
        // Stage 3: Critical Warning Red with micro-shivers and sparks
        final flicker = (math.sin(model.clock * 28) + 1) * 0.5;
        shieldColor = Color.lerp(
          const Color(0xFFFF2222),
          const Color(0xFFFF7744),
          flicker,
        )!;
        ripple = flicker * 3.5;
      }

      // Outer force bubble ellipse
      c.drawOval(
        Rect.fromCenter(
          center: center,
          width: 48 + ripple,
          height: 40 + ripple,
        ),
        Paint()
          ..color = shieldColor.withValues(alpha: 0.65)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.8,
      );
      // Inner shimmer lattice
      c.drawOval(
        Rect.fromCenter(center: center, width: 44, height: 36),
        Paint()
          ..color = shieldColor.withValues(alpha: 0.18)
          ..style = PaintingStyle.fill,
      );

      // Micro spark discharges on critical decay
      if (shieldTime < 2.0) {
        final sparkAngle = model.clock * 18;
        final sx = center.dx + math.cos(sparkAngle) * 24;
        final sy = center.dy + math.sin(sparkAngle) * 19;
        c.drawLine(
          Offset(sx - 2, sy - 2),
          Offset(sx + 3, sy + 3),
          Paint()
            ..color = Colors.white
            ..strokeWidth = 1.5,
        );
      }
    }

    if (model.invulnerable > 0) {
      // Kinetic deflection flash ring
      final expand = (2.5 - model.invulnerable).clamp(0.0, 1.0) * 10.0;
      c.drawCircle(
        center,
        22 + expand,
        Paint()
          ..color = Colors.white.withValues(
            alpha: (model.invulnerable / 2.5).clamp(0.0, 0.7),
          )
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.0,
      );
    }
  }

  void _paintSupplyCrate(Canvas c, SupplyCrate crate) {
    final cx = crate.x;
    final cy = crate.y;
    final swing = math.sin(crate.swingTime * 3.2) * 4.0;

    // 1. Striped Parachute Canopy
    final canopyX = cx + swing;
    final canopyY = cy - 22.0;
    c.drawArc(
      Rect.fromCenter(
        center: Offset(canopyX, canopyY),
        width: 34,
        height: 20,
      ),
      math.pi,
      math.pi,
      true,
      Paint()..color = const Color(0xFFF0F5FA),
    );
    c.drawArc(
      Rect.fromCenter(
        center: Offset(canopyX, canopyY),
        width: 14,
        height: 20,
      ),
      math.pi,
      math.pi,
      true,
      Paint()..color = mint,
    );

    // 2. Parachute Rigging Lines
    final pLine = Paint()
      ..color = const Color(0x88D0E0EE)
      ..strokeWidth = 1.0;
    c.drawLine(Offset(canopyX - 16, canopyY), Offset(cx - 8, cy - 8), pLine);
    c.drawLine(Offset(canopyX - 6, canopyY - 4), Offset(cx - 4, cy - 8), pLine);
    c.drawLine(Offset(canopyX + 6, canopyY - 4), Offset(cx + 4, cy - 8), pLine);
    c.drawLine(Offset(canopyX + 16, canopyY), Offset(cx + 8, cy - 8), pLine);

    // 3. Heavy Armored Supply Cargo Crate Container
    final flash = crate.hitFlash > 0;
    final crateRect = Rect.fromCenter(
      center: Offset(cx, cy),
      width: 22,
      height: 20,
    );
    c.drawRect(
      crateRect,
      Paint()..color = flash ? Colors.white : const Color(0xFF23364A),
    );
    c.drawRect(
      crateRect,
      Paint()
        ..color = flash ? const Color(0xFFFF5555) : const Color(0xFF5B7894)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );

    // Flashing tactical beacon on top
    final beaconPulse = (math.sin(model.clock * 10) + 1.0) * 0.5;
    c.drawCircle(
      Offset(cx, cy - 10),
      2.5,
      Paint()..color = Color.lerp(gold, Colors.white, beaconPulse)!,
    );

    // Powerup Icon preview inside crate
    switch (crate.power) {
      case Power.large:
        effectSprite(c, 5, 5, Offset(cx, cy), scale: .35);
      case Power.powerful:
        effectSprite(c, 5, 4, Offset(cx, cy), scale: .35);
      case Power.spread:
      case Power.rapid:
      case Power.shield:
        sprite(c, 4, 4 + crate.power.index, Offset(cx, cy), 18);
    }

    // Health pips (dots showing durability)
    for (var i = 0; i < crate.maxHp; i++) {
      final pipX = cx - (crate.maxHp - 1) * 3.0 + i * 6.0;
      final active = i < crate.hp;
      c.drawRect(
        Rect.fromLTWH(pipX - 1.5, cy + 12, 3, 2),
        Paint()..color = active ? mint : const Color(0xFF40556B),
      );
    }
  }

  void _creatureLighting(
    Canvas c,
    Offset pos,
    double bank, {
    required double width,
    bool diving = false,
  }) {
    final paint = Paint()..isAntiAlias = false;
    final half = width * 0.42;
    if (bank.abs() > 0.06) {
      final lead = bank >= 0 ? 1.0 : -1.0;
      final trail = -lead;
      paint.color = const Color(0xB8FFF5C9);
      c.drawRect(
        Rect.fromLTWH(
          (pos.dx + lead * half - 2).roundToDouble(),
          (pos.dy - 6).roundToDouble(),
          4,
          2,
        ),
        paint,
      );
      paint.color = diving
          ? const Color(0xB8FF9100)
          : const Color(0x9970F5D5);
      c.drawRect(
        Rect.fromLTWH(
          (pos.dx + lead * (half * 0.65) - 1).roundToDouble(),
          (pos.dy - 10).roundToDouble(),
          3,
          2,
        ),
        paint,
      );
      paint.color = const Color(0x80080D1C);
      c.drawRect(
        Rect.fromLTWH(
          (pos.dx + trail * half - 2).roundToDouble(),
          (pos.dy - 4).roundToDouble(),
          4,
          4,
        ),
        paint,
      );
    }
    if (diving) {
      paint.color = const Color(0xCCFFAB00);
      c.drawRect(
        Rect.fromLTWH(
          (pos.dx - 6).roundToDouble(),
          (pos.dy + 6).roundToDouble(),
          12,
          2,
        ),
        paint,
      );
    }
  }

  void _wingTellChevrons(Canvas c, Offset pos) {
    final pulse = (model.clock * 16).floor().isEven;
    final paint = Paint()
      ..isAntiAlias = false
      ..color = pulse ? const Color(0xFFFFF5C9) : gold;
    for (final side in [-1.0, 1.0]) {
      final wx = (pos.dx + side * 13).roundToDouble();
      final wy = (pos.dy - 8).roundToDouble();
      c.drawRect(Rect.fromLTWH(wx - 1, wy - 2, 3, 2), paint);
      c.drawRect(Rect.fromLTWH(wx + side * 2 - 1, wy, 2, 3), paint);
    }
  }

  void _smallOrMediumDiveShield(Canvas c, Offset pos, Demon d) {
    final paint = Paint()..isAntiAlias = false;
    final notSoSmall =
        d.diveShieldMax >= 2 || d.elite || d.kind >= 2 || d.maxHp >= 3;
    final ratio = (d.diveShield / math.max(1, d.diveShieldMax)).clamp(
      0.35,
      1.0,
    );
    if (notSoSmall) {
      // Tier 2: Not-so-small creature double-shock incandescent re-entry plasma (~48 px).
      const halfSpan = 24.0;
      for (var dx = -halfSpan; dx <= halfSpan; dx += 3) {
        final norm = dx / halfSpan;
        final absNorm = norm.abs();
        final curve = (1 - norm * norm) * 7.5;
        final jitter = math.sin(model.clock * 38 + dx * 0.9) > 0.15 ? 1.0 : 0.0;
        final sx = (pos.dx + dx - 1).roundToDouble();
        final sy = (pos.dy + 11 + curve).roundToDouble();

        // Turbulent ablation envelope (superheated flame orange to deep crimson).
        final tongueHeight =
            ((1 - absNorm * 0.7) * 3.0 +
                    (math.sin(model.clock * 32 + dx * 1.3).abs() * 3.0))
                .roundToDouble();
        paint.color = const Color(0xFFDD2C00).withValues(
          alpha: (0.55 + 0.35 * ratio) * (1 - absNorm * 0.35),
        );
        c.drawRect(
          Rect.fromLTWH(sx, sy - 4 - tongueHeight, 3, 2 + tongueHeight),
          paint,
        );
        paint.color = const Color(0xFFFF6D00).withValues(
          alpha: 0.75 + 0.2 * ratio,
        );
        c.drawRect(Rect.fromLTWH(sx, sy - 4 + jitter, 3, 3), paint);

        // Primary compression shock (incandescent solar yellow-gold).
        paint.color = (absNorm < 0.55
                ? const Color(0xFFFFD54F)
                : const Color(0xFFFFAB00))
            .withValues(alpha: 0.85 + 0.15 * ratio);
        c.drawRect(Rect.fromLTWH(sx, sy - 2, 3, 2), paint);

        // Leading stagnation nose (blinding white-hot core).
        if (absNorm < 0.75) {
          paint.color = absNorm < 0.35
              ? const Color(0xFFFFFFFF)
              : const Color(0xFFFFF6CC);
          c.drawRect(Rect.fromLTWH(sx, sy, 3, 2), paint);
        }
      }
      // Ablative ember trail & smoke puffs streaming upward behind wingtips.
      final sparkShift = ((model.clock * 24).floor() % 4).toDouble();
      for (final side in [-1.0, 1.0]) {
        final wx = (pos.dx + side * 23 - 1).roundToDouble();
        paint.color = const Color(0xFFFF9100).withValues(alpha: 0.85);
        c.drawRect(Rect.fromLTWH(wx, (pos.dy + 3 - sparkShift).roundToDouble(), 2, 3), paint);
        paint.color = const Color(0xFFFF3D00).withValues(alpha: 0.7);
        c.drawRect(
          Rect.fromLTWH(
            (wx + side * 2).roundToDouble(),
            (pos.dy - 2 - sparkShift).roundToDouble(),
            2,
            2,
          ),
          paint,
        );
        paint.color = const Color(0xAA6D1B1B);
        c.drawRect(
          Rect.fromLTWH(
            (wx + side).roundToDouble(),
            (pos.dy - 6 - sparkShift).roundToDouble(),
            2,
            2,
          ),
          paint,
        );
      }
    } else {
      // Tier 1: Small creature compact white-yellow nose cone with flickering orange-red wisps (~32 px).
      const halfSpan = 16.0;
      for (var dx = -halfSpan; dx <= halfSpan; dx += 3) {
        final norm = dx / halfSpan;
        final absNorm = norm.abs();
        final curve = (1 - norm * norm) * 5.5;
        final jitter = math.sin(model.clock * 38 + dx * 0.9) > 0.2 ? 1.0 : 0.0;
        final sx = (pos.dx + dx - 1).roundToDouble();
        final sy = (pos.dy + 11 + curve).roundToDouble();

        // Turbulent orange-crimson ablation wisps.
        paint.color = const Color(0xFFDD2C00).withValues(alpha: 0.65);
        c.drawRect(Rect.fromLTWH(sx, sy - 4 - jitter, 3, 2), paint);
        paint.color = const Color(0xFFFF6D00).withValues(alpha: 0.82);
        c.drawRect(Rect.fromLTWH(sx, sy - 3, 3, 2), paint);

        // Solar yellow-gold compression shock.
        paint.color = const Color(0xFFFFD54F).withValues(alpha: 0.9);
        c.drawRect(Rect.fromLTWH(sx, sy - 1, 3, 2), paint);

        // White-hot stagnation nose.
        if (absNorm < 0.75) {
          paint.color = absNorm < 0.35
              ? const Color(0xFFFFFFFF)
              : const Color(0xFFFFF6CC);
          c.drawRect(Rect.fromLTWH(sx, sy, 2, 2), paint);
        }
      }
      final flicker = ((model.clock * 22).floor() % 3).toDouble();
      for (final side in [-1.0, 1.0]) {
        paint.color = const Color(0xFFFF9100).withValues(alpha: 0.8);
        c.drawRect(
          Rect.fromLTWH(
            (pos.dx + side * 16 - 1).roundToDouble(),
            (pos.dy + 5 - flicker).roundToDouble(),
            2,
            3,
          ),
          paint,
        );
        paint.color = const Color(0xFFFF3D00).withValues(alpha: 0.65);
        c.drawRect(
          Rect.fromLTWH(
            (pos.dx + side * 17 - 1).roundToDouble(),
            (pos.dy + 1 - flicker).roundToDouble(),
            2,
            2,
          ),
          paint,
        );
      }
    }
  }

  void _carrierLighting(Canvas c, Offset center, double bank) {
    final paint = Paint()..isAntiAlias = false;
    final lead = bank >= 0 ? 1.0 : -1.0;
    paint.color = const Color(0x669FFFEA);
    c.drawRect(
      Rect.fromLTWH(
        (center.dx + lead * 52 - 12).roundToDouble(),
        (center.dy - 24).roundToDouble(),
        24,
        3,
      ),
      paint,
    );
    paint.color = const Color(0x66060A16);
    c.drawRect(
      Rect.fromLTWH(
        (center.dx - lead * 56 - 12).roundToDouble(),
        (center.dy - 14).roundToDouble(),
        24,
        5,
      ),
      paint,
    );
  }

  void _carrierSideHatches(Canvas c, Carrier b) {
    final paint = Paint()..isAntiAlias = false;
    final hatches = [
      (Offset(b.x - Carrier.sideHatchOffset, b.y + 21), b.sideDoorLeft),
      (Offset(b.x + Carrier.sideHatchOffset, b.y + 21), b.sideDoorRight),
    ];
    for (final (center, openness) in hatches) {
      c.drawRect(
        Rect.fromCenter(center: center, width: 22, height: 16),
        paint..color = const Color(0xFF070A14),
      );
      if (b.sideHatchesLocked) {
        // Final form: side hatches clamped shut with armored cross-bars & crimson lock pips.
        c.drawRect(
          Rect.fromCenter(center: center, width: 20, height: 14),
          paint..color = const Color(0xFF3E4660),
        );
        c.drawRect(
          Rect.fromCenter(center: center, width: 18, height: 3),
          paint..color = const Color(0xFF23293A),
        );
        c.drawRect(
          Rect.fromCenter(center: center, width: 4, height: 4),
          paint..color = const Color(0xFFFF274E),
        );
      } else {
        c.drawRect(
          Rect.fromCenter(center: center, width: 16, height: 9),
          paint..color = b.shield > 0 ? violet : mint,
        );
        final closed = 10 * (1 - openness.clamp(0.0, 1.0));
        for (final direction in [-1, 1]) {
          c.drawRect(
            Rect.fromLTWH(
              center.dx + (direction < 0 ? -10 : 10 - closed),
              center.dy - 8,
              closed,
              16,
            ),
            paint..color = const Color(0xFF57617E),
          );
        }
      }
    }
  }

  void _sentinel(Canvas c, Offset pos, Demon demon) {
    final species = demon.archetype == EnemyArchetype.armoredSentinel ? 1 : 0;
    final warning = demon.telegraph > 0;
    final diving = demon.dive > 0;
    final row = demon.lastStand
        ? 6 + species
        : warning || diving
        ? 8 + species
        : species;
    final frame = demon.lastStand
        ? demon.rushing
              ? 4 + (model.clock * 12).floor() % 4
              : (demon.lastStandTellProgress * 4).floor().clamp(0, 3)
        : diving
        ? 4 + (model.clock * 8).floor() % 4
        : warning
        ? (model.clock * 8).floor() % 4
        : ((model.clock / .4 + demon.seed).floor() % 8);
    final bank = demon.bank.abs() > 0.01
        ? demon.bank.clamp(-1.0, 1.0)
        : (demon.vx / 140).clamp(-1.0, 1.0);
    c.save();
    if (bank.abs() > 0.04) {
      c.translate(pos.dx, pos.dy);
      c.rotate(bank * 0.08);
      c.scale(1.0 - bank.abs() * 0.08, 1.0);
      c.translate(-pos.dx, -pos.dy);
    }
    effectSprite(
      c,
      row,
      frame,
      pos,
      tint: demon.flash > 0 ? Colors.white : null,
    );
    _creatureLighting(c, pos, bank, width: 92, diving: diving);
    c.restore();
    if (demon.shield > 0 &&
        demon.shieldMax > 0 &&
        !(diving && demon.diveShield > 0)) {
      effectSprite(
        c,
        2,
        ((1 - demon.shield / demon.shieldMax) * 4).floor().clamp(0, 3),
        pos,
      );
    }
    if (demon.armor > 0 && demon.armorMax > 0) {
      final layers = (demon.armor / demon.armorMax * 4).ceil();
      for (var layer = 0; layer < layers; layer++) {
        effectSprite(
          c,
          2,
          4 + layer,
          pos,
          tint: demon.flash > 0 ? Colors.white : null,
        );
      }
    }
    if (diving && demon.diveShield > 0) {
      _sentinelDiveShield(c, pos, demon);
    }
  }

  void _sentinelDiveShield(Canvas c, Offset pos, Demon demon) {
    // Tier 3: Massive roaring spacecraft atmospheric re-entry plasma bow shock (~104 px).
    final ratio =
        (demon.diveShield / math.max(1, demon.diveShieldMax)).clamp(0.3, 1.0);
    final paint = Paint()..isAntiAlias = false;
    const halfSpan = 52.0;
    for (var dx = -halfSpan; dx <= halfSpan; dx += 3) {
      final norm = dx / halfSpan;
      final absNorm = norm.abs();
      final bow = (1 - norm * norm) * 15.0;
      final jitter = math.sin(model.clock * 38 + dx * 0.9) * 1.5;
      final sx = (pos.dx + dx - 1).roundToDouble();
      final sy = (pos.dy + 16 + bow).roundToDouble();

      // Jagged trailing flame tongues licking backward along the flanks.
      final tongueHeight =
          ((1 - absNorm * 0.65) * 5.0 +
                  math.sin(model.clock * 34 + dx * 1.1).abs() * 5.0)
              .roundToDouble();
      paint.color = const Color(0xFFDD2C00).withValues(
        alpha: (0.5 + 0.35 * ratio) * (1 - absNorm * 0.3),
      );
      c.drawRect(
        Rect.fromLTWH(sx, sy - 6 - tongueHeight, 3, 2 + tongueHeight),
        paint,
      );

      // Turbulent ablation envelope (superheated flame orange).
      paint.color = const Color(0xFFFF6D00).withValues(
        alpha: 0.72 + 0.22 * ratio,
      );
      c.drawRect(
        Rect.fromLTWH(sx, (sy - 5 + jitter).roundToDouble(), 3, 3),
        paint,
      );

      // Primary compression shock (incandescent solar yellow-gold).
      paint.color = (absNorm < 0.5
              ? const Color(0xFFFFD54F)
              : const Color(0xFFFFAB00))
          .withValues(alpha: 0.85 + 0.15 * ratio);
      c.drawRect(Rect.fromLTWH(sx, sy - 2, 3, 3), paint);

      // Leading stagnation nose (blinding white-hot core).
      if (absNorm < 0.75) {
        paint.color = absNorm < 0.35
            ? const Color(0xFFFFFFFF)
            : const Color(0xFFFFF6CC);
        c.drawRect(Rect.fromLTWH(sx, sy, 3, 2), paint);
      }
    }

    // Roaring wingtip fire plumes & ablative ember trail streaming upward.
    final flicker = (model.clock * 20).floor() % 4;
    for (final side in [-1.0, 1.0]) {
      for (var plume = 0; plume < 4; plume++) {
        final px = (pos.dx + side * (46 + plume * 2) - 1).roundToDouble();
        final py = (pos.dy + 9 - plume * 5 - flicker).roundToDouble();
        paint.color = switch (plume) {
          0 => const Color(0xFFFFD54F).withValues(alpha: 0.9),
          1 => const Color(0xFFFF9100).withValues(alpha: 0.82),
          2 => const Color(0xFFFF3D00).withValues(alpha: 0.68),
          _ => const Color(0xAA6D1B1B),
        };
        c.drawRect(Rect.fromLTWH(px, py, 3, 3), paint);
      }
    }
  }

  void _bossOrbitalArrivalEffects(Canvas c, Carrier b, double p, double descent) {
    if (descent <= 0.01) return;
    final flamePaint = Paint()..isAntiAlias = false;
    final flicker = (model.visualClock * 24).floor() % 4;
    // Roaring retro-thrusters braking the dreadnought from upper orbit.
    for (final xOff in [-52.0, -24.0, 24.0, 52.0]) {
      final bx = b.x + xOff;
      final by = b.y - 38;
      final plumeLen = (18.0 + descent * 34.0 + flicker * 3.0);
      flamePaint.color = const Color(0xFFFFD54F).withValues(alpha: 0.9);
      c.drawRect(Rect.fromLTWH(bx - 3, by - plumeLen * 0.5, 6, plumeLen * 0.5), flamePaint);
      flamePaint.color = const Color(0xFFFF6D00).withValues(alpha: 0.75);
      c.drawRect(Rect.fromLTWH(bx - 4, by - plumeLen, 8, plumeLen * 0.6), flamePaint);
    }
    // Atmospheric / gravitational entry shockwaves.
    final rippleW = 220.0 * (1.0 - descent * 0.5);
    final rippleH = 46.0 * (1.0 - descent * 0.5);
    final ripplePaint = Paint()
      ..color = mint.withValues(alpha: (0.45 * (1.0 - descent)).clamp(0.0, 1.0))
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;
    c.drawOval(Rect.fromCenter(center: Offset(b.x, b.y + 35), width: rippleW, height: rippleH), ripplePaint);
  }

  void _carrierTurretBarrels(Canvas c, Carrier b) {
    final aim = math.atan2(ArcadeModel.shipY - (b.y + 36), model.shipX - b.x).clamp(0.4, 2.74);
    final turretPaint = Paint()
      ..color = const Color(0xFFF4CA79)
      ..style = PaintingStyle.fill;
    for (final side in [-28.0, 28.0]) {
      c.save();
      c.translate(b.x + side, b.y + 36);
      c.rotate(aim - math.pi / 2);
      c.drawRect(const Rect.fromLTWH(-3, 0, 2, 7), turretPaint);
      c.drawRect(const Rect.fromLTWH(1, 0, 2, 7), turretPaint);
      c.restore();
    }
  }

  void _defeatCelebration(Canvas c) {
    final prog = model.defeatProgress;
    // 1. Player ship breakup shockwave & tumbling hull fragments at (shipX, shipY)
    if (prog < 0.45) {
      final shockR = (prog / 0.45) * 64.0;
      final shockAlpha = (1.0 - prog / 0.45).clamp(0.0, 1.0);
      c.drawCircle(
        Offset(model.shipX, ArcadeModel.shipY),
        shockR,
        Paint()
          ..color = mint.withValues(alpha: shockAlpha * 0.7)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.5,
      );
      c.drawCircle(
        Offset(model.shipX, ArcadeModel.shipY),
        shockR * 0.6,
        Paint()
          ..color = const Color(0xFFFFD54F).withValues(alpha: shockAlpha * 0.8)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5,
      );

      // Tumbling hull fragments flying outward
      final fragPaint = Paint()..isAntiAlias = false;
      for (var f = 0; f < 6; f++) {
        final fa = f * (math.pi / 3) + 0.4;
        final fdist = prog * 85.0;
        final fx = model.shipX + math.cos(fa) * fdist;
        final fy = ArcadeModel.shipY + math.sin(fa) * fdist * 0.7 + (prog * prog * 40.0);
        fragPaint.color = (f.isEven ? mint : const Color(0xFFD6E2EE)).withValues(alpha: shockAlpha);
        c.drawRect(Rect.fromLTWH(fx, fy, f % 2 == 0 ? 3 : 2, f % 3 == 0 ? 3 : 2), fragPaint);
      }
    }

    // 2. Ordinary Small Demons: Synchronized figure-8 victory swarms & celebratory spark bursts
    final smallDemons = model.demons.where((d) => !d.isLarge).toList();
    for (var i = 0; i < smallDemons.length; i++) {
      final d = smallDemons[i];
      // Wing-flare glints during celebratory loops
      final wingGlint = (math.sin(model.visualClock * 16.0 + i) * 0.5 + 0.5);
      if (wingGlint > 0.6) {
        c.drawCircle(
          Offset(d.x - 10, d.y),
          2.0,
          Paint()..color = Colors.white.withValues(alpha: 0.85),
        );
        c.drawCircle(
          Offset(d.x + 10, d.y),
          2.0,
          Paint()..color = Colors.white.withValues(alpha: 0.85),
        );
      }

      // Celebratory micro-sparks trailing behind each celebrating creature
      final sparkPhase = (model.visualClock * 8.0 + d.seed) % 1.0;
      final sparkY = d.y + sparkPhase * 14.0;
      c.drawRect(
        Rect.fromLTWH(d.x + (i.isEven ? 4 : -4), sparkY, 1.5, 1.5),
        Paint()..color = (i % 3 == 0 ? gold : mint).withValues(alpha: 1.0 - sparkPhase),
      );
    }

    // 3. Big Birds (Sentinels) Apex Hover & Twin Skyward Salute Beams
    for (final d in model.demons) {
      if (d.isLarge) {
        final beamAlpha = (0.5 + 0.4 * math.sin(model.visualClock * 14).abs()).clamp(0.0, 1.0);
        final beamPaint = Paint()
          ..color = const Color(0xFF70F5D5).withValues(alpha: beamAlpha)
          ..strokeWidth = 2.5;
        // Twin vertical skyward victory beams
        c.drawLine(Offset(d.x - 8, d.y - 14), Offset(d.x - 8, 0), beamPaint);
        c.drawLine(Offset(d.x + 8, d.y - 14), Offset(d.x + 8, 0), beamPaint);
        // Golden pauldron corona halo
        c.drawCircle(
          Offset(d.x, d.y - 10),
          26,
          Paint()
            ..color = const Color(0xFFF4CA79).withValues(alpha: 0.35)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2,
        );
      }
    }

    // 4. Carrier Boss Dominance Pulse & Circling Drone Halo
    final b = model.boss;
    if (b != null) {
      final pulseRadius = 110.0 + math.sin(model.visualClock * 10) * 14.0;
      c.drawOval(
        Rect.fromCenter(center: Offset(b.x, b.y), width: pulseRadius * 2, height: 110),
        Paint()
          ..color = const Color(0xFFFF3D68).withValues(alpha: 0.4)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.5,
      );
      // Dominance telemetry halo rings
      c.drawCircle(
        Offset(b.x, b.y + 12),
        44,
        Paint()
          ..color = const Color(0xFFFF7E84).withValues(alpha: 0.25)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5,
      );
    }
  }

  void _bossMeltdownWreckage(Canvas c, Carrier wreck, Offset pos, double p) {
    c.save();
    c.translate(pos.dx, pos.dy);
    c.rotate(p * 0.22);
    if (bossAtlas != null) {
      bossSprite(
        c,
        0,
        wreck.phase.clamp(0, 3),
        Offset.zero,
        184,
        height: 120,
        tint: const Color(0xFF8B665F),
      );
      bossSprite(
        c,
        3,
        1,
        Offset.zero,
        184,
        height: 120,
        opacity: (p * 1.2).clamp(0.4, 1.0),
      );
      // Detached tumbling wing debris
      final debrisLeft = Offset(-70 - p * 60, p * p * 120);
      bossSprite(c, 3, 2, debrisLeft, 92, height: 60);
      final debrisRight = Offset(70 + p * 60, p * p * 140);
      bossSprite(c, 3, 3, debrisRight, 92, height: 60);
    } else {
      sprite(c, 6, wreck.phase, Offset.zero, 184, height: 118, tint: const Color(0xFF8B665F));
    }
    _damage(c, Offset.zero, 1, p * 10);
    c.restore();
  }

  // All cutscene motion is derived from simulation progress, so pausing freezes
  // the shot and seeded particles remain identical on desktop and touch devices.
  void _cinematic(Canvas c) {
    final mode = model.presentationMode;
    final intro = mode == RunMode.transition;
    final clear = mode == RunMode.levelClear;
    final triumph = mode == RunMode.victory;
    final travel = mode == RunMode.travel;
    if (!intro && !clear && !triumph && !travel) return;
    final p = model.transitionProgress.clamp(0.0, 1.0);
    final ease = Curves.easeInOutCubic.transform(p);
    final wave = intro && model.wave > 1;
    final envelope = math.sin(math.pi * p);
    final bar = (wave ? 9.0 : 24.0) * math.min(1.0, envelope * 4);

    if (triumph && model.wreckBoss != null) {
      final wreck = model.wreckBoss!;
      final fallY = (wreck.y + p * p * 360).roundToDouble();
      _bossMeltdownWreckage(c, wreck, Offset(wreck.x.roundToDouble(), fallY), p);
    }
    if (clear || triumph) {
      final random = math.Random(triumph ? 1982 : 8200 + model.level);
      final count = triumph ? 10 : 5;
      for (var burst = 0; burst < count; burst++) {
        final origin = Offset(
          45 + random.nextDouble() * 270,
          70 + random.nextDouble() * 210,
        );
        final age = p * (triumph ? 3.2 : 2.3) - burst * .16;
        if (age < 0 || age > 1.15) continue;
        final fade = (1 - age / 1.15).clamp(0.0, 1.0);
        final color = [mint, gold, violet, const Color(0xFFFF8676)][burst % 4];
        for (var ray = 0; ray < 16; ray++) {
          final angle = ray * math.pi / 8 + burst;
          final radius = age * (36 + burst % 3 * 14);
          final point =
              origin +
              Offset(
                math.cos(angle) * radius,
                math.sin(angle) * radius + age * age * 20,
              );
          c.drawRect(
            Rect.fromCenter(
              center: point,
              width: ray.isEven ? 3 : 2,
              height: ray.isEven ? 3 : 2,
            ),
            Paint()..color = color.withValues(alpha: fade * .65),
          );
        }
        effectSprite(
          c,
          5,
          (age / 1.15 * 4).floor().clamp(0, 3),
          origin,
          opacity: .65,
        );
      }
      // The rescued sector glows once before the ship accelerates away.
      c.drawRect(
        const Rect.fromLTWH(0, 0, 360, 520),
        Paint()
          ..color = (triumph ? gold : mint).withValues(
            alpha: math.pow(math.max(0, 1 - p * 6), 2).toDouble() * .24,
          ),
      );
      final departure = Curves.easeInCubic.transform(
        ((p - .35) / .65).clamp(0.0, 1.0),
      );
      _cinematicShip(
        c,
        Offset(
          model.shipX + (180 - model.shipX) * ease,
          ArcadeModel.shipY - departure * 650,
        ),
        42 - departure * 12,
        1 + departure * 3,
      );
    }

    if (travel) {
      c.drawRect(
        const Rect.fromLTWH(0, 0, 360, 520),
        Paint()..color = ink.withValues(alpha: envelope * .72),
      );
      final random = math.Random(1701);
      final velocity = math.sin(math.pi * p).clamp(0.0, 1.0);
      for (var i = 0; i < 88; i++) {
        final angle = random.nextDouble() * math.pi * 2;
        final radius = 15 + ((random.nextDouble() + p * 1.7) % 1) * 420;
        final length = (8 + random.nextDouble() * 90) * velocity;
        final near = Offset(
          180 + math.cos(angle) * radius,
          210 + math.sin(angle) * radius,
        );
        final far =
            near + Offset(math.cos(angle) * length, math.sin(angle) * length);
        c.drawLine(
          near,
          far,
          Paint()
            ..color = (i % 4 == 0 ? violet : mint).withValues(
              alpha: velocity * .6,
            )
            ..strokeWidth = i % 7 == 0 ? 2 : 1,
        );
      }
      // A ringed destination crosses the viewport as the jump resolves.
      final arrival = Curves.easeOutCubic.transform(
        ((p - .42) / .58).clamp(0.0, 1.0),
      );
      if (arrival > 0) {
        final center = Offset(330 - arrival * 125, -120 + arrival * 240);
        c.save();
        c.translate(center.dx, center.dy);
        c.rotate(-.35);
        final radius = 30 + arrival * 60;
        final color = [
          mint,
          violet,
          const Color(0xFFEF9A7D),
          gold,
          const Color(0xFF8B9ACB),
        ][(model.nextLevel - 1).clamp(0, 4)];
        final ring = Rect.fromCenter(
          center: Offset.zero,
          width: radius * 3.7,
          height: radius * .7,
        );
        c.drawOval(
          ring,
          Paint()
            ..color = color.withValues(alpha: arrival * .28)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 6,
        );
        c.drawCircle(
          Offset.zero,
          radius,
          Paint()..color = const Color(0xFF242A48),
        );
        c.save();
        c.clipPath(
          Path()..addOval(Rect.fromCircle(center: Offset.zero, radius: radius)),
        );
        for (var band = -8; band <= 8; band++) {
          c.drawRect(
            Rect.fromLTWH(-radius, band * radius / 8, radius * 2, 4),
            Paint()..color = color.withValues(alpha: .08 + (band % 3) * .025),
          );
        }
        c.drawCircle(
          Offset(-radius * .6, -radius * .1),
          radius,
          Paint()..color = ink.withValues(alpha: .55),
        );
        c.restore();
        c.drawArc(
          ring,
          0,
          math.pi,
          false,
          Paint()
            ..color = color.withValues(alpha: arrival * .5)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 4,
        );
        c.restore();
        c.drawCircle(
          Offset(55 + arrival * 25, 160 + arrival * 100),
          13,
          Paint()..color = color.withValues(alpha: arrival * .4),
        );
      }
      _cinematicShip(
        c,
        Offset(
          180 + math.sin(p * math.pi * 2) * 10,
          340 + math.sin(p * math.pi) * 22,
        ),
        30,
        2 + velocity * 2,
      );
    }

    if (intro) {
      final arrival = Curves.easeOutCubic.transform((p / .8).clamp(0.0, 1.0));
      final y = wave
          ? ArcadeModel.shipY
          : ArcadeModel.shipY + (1 - arrival) * 130;
      _cinematicShip(c, Offset(model.shipX, y), 42, 1 + (1 - arrival) * 2);
      // The scan sweeps toward the horizon while the approaching flock unfolds.
      final scanY = 40 + p * 460;
      c.drawRect(
        Rect.fromLTWH(0, scanY, 360, 2),
        Paint()..color = mint.withValues(alpha: envelope * .18),
      );
      if (model.boss != null) {
        for (final x in [20.0, 340.0]) {
          c.drawRect(
            Rect.fromLTWH(x, 40, 2, 440),
            Paint()
              ..color = const Color(0xFFFF8676).withValues(
                alpha: envelope * (.15 + .1 * math.sin(p * math.pi * 12).abs()),
              ),
          );
        }
      }
    }
    c.drawRect(Rect.fromLTWH(0, 0, 360, bar), Paint()..color = ink);
    c.drawRect(Rect.fromLTWH(0, 520 - bar, 360, bar), Paint()..color = ink);
    c.drawLine(
      Offset(0, bar),
      Offset(360, bar),
      Paint()
        ..color = (triumph ? gold : mint).withValues(alpha: envelope * .35),
    );
    // Fade across cuts so departure, transit, and arrival can use distinct
    // compositions without exposing a discontinuous ship or planet position.
    var blackout = 0.0;
    if (clear || triumph || travel) {
      blackout = ((p - .85) / .15).clamp(0.0, 1.0);
    }
    if (travel) {
      blackout = math.max(blackout, (1 - p / .12).clamp(0.0, 1.0));
    } else if (intro && !wave) {
      blackout = (1 - p / .15).clamp(0.0, 1.0);
    }
    if (blackout > 0) {
      c.drawRect(
        const Rect.fromLTWH(0, 0, 360, 520),
        Paint()..color = Colors.black.withValues(alpha: blackout),
      );
    }
  }

  void _cinematicShip(Canvas c, Offset center, double width, double thrust) {
    if (center.dy < -70 || center.dy > 590) return;
    final frame = (model.clock * 14).floor() % 4;
    final flame = 10 * thrust;
    c.drawPath(
      Path()
        ..moveTo(center.dx - 3, center.dy + width * .3)
        ..lineTo(center.dx + 3, center.dy + width * .3)
        ..lineTo(center.dx, center.dy + width * .3 + flame)
        ..close(),
      Paint()..color = mint.withValues(alpha: .5),
    );
    c.drawLine(
      center + Offset(0, width * .35),
      center + Offset(0, width * .35 + flame * .65),
      Paint()
        ..color = const Color(0xFFFFEDBF)
        ..strokeWidth = 2,
    );
    sprite(c, 4, frame, center, width);
  }
}
