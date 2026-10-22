import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flame/game.dart';
import 'package:flutter/material.dart';

import 'model.dart';
import 'sector_background.dart';
import '../widgets/heart_parts.dart';

const ink = Color(0xFF080D18);
const mint = Color(0xFF70F5D5);
const violet = Color(0xFFBDA7FF);
const gold = Color(0xFFF4CA79);

class DemonScene extends FlameGame {
  DemonScene(this.model, this.onTick);
  final ArcadeModel model;
  final VoidCallback onTick;
  ui.Image? atlas, effectsAtlas, sky;
  final sectors = SectorBackground();
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
    _background(canvas);
    final active = model.mode != RunMode.title;
    if (active && combat) {
      _combat(canvas);
      _cinematic(canvas);
    }
    canvas.restore();
  }

  void _background(Canvas c) =>
      sectors.paint(c, environment, ambient, model.cycle, sky);

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
    for (final d in model.demons) {
      // Ordinary tells are changes to the existing monster animation only:
      // quicker cocked wing frames and the atlas's own angry eyes/palette.
      final warning = d.telegraph > 0;
      final frame = warning
          ? 4 + ((model.clock * 12 + d.seed).floor() % 2)
          : ((model.clock * 8 + d.seed).floor() % 4) + (d.angry ? 4 : 0);
      final entrance =
          !d.entering && model.presentationMode == RunMode.transition
          ? Curves.easeOutCubic.transform(
              ((model.transitionProgress - (d.seed % 5) * .035) / .75).clamp(
                0.0,
                1.0,
              ),
            )
          : 1.0;
      final pos = Offset(
        d.x +
            math.sin((1 - entrance) * math.pi) *
                36 *
                (d.seed.floor().isEven ? 1 : -1),
        d.y - (1 - entrance) * (d.y + 45),
      );
      if (d.isLarge) {
        // Large creatures have their own delayed entrance in simulation.
        if (d.entranceProgress > 0) {
          _sentinel(c, Offset(d.x, d.y), d);
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
        c.translate(
          0,
          -180 * (1 - Curves.easeOutCubic.transform(model.transitionProgress)),
        );
      }
      sprite(c, 6, b.phase, Offset(b.x, b.y), 184, height: 118);
      _carrierEyes(c, b);
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
        for (var offset = 0.0; offset <= b.forceFieldHalfWidth; offset += 2) {
          for (final side in [-1.0, 1.0]) {
            final worldX = b.x + side * offset;
            final surface = b.forceFieldSurfaceY(worldX);
            paint.color = mint.withValues(alpha: .65 + strength * .3);
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
      }
      _damage(c, Offset(b.x, b.y), 1 - b.core / b.coreMax, model.clock);
      c.restore();
    }
    for (final s in model.shots) {
      final x = s.x.roundToDouble(), y = s.y.roundToDouble();
      final p = Paint()..isAntiAlias = false;
      void block(double dx, double dy, double w, double h, Color color) {
        p.color = color;
        c.drawRect(Rect.fromLTWH(x + dx, y + dy, w, h), p);
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
      sprite(
        c,
        4,
        (model.clock * 14).floor() % 4,
        Offset(model.shipX, ArcadeModel.shipY),
        42,
      );
      if (model.hasPower(Power.shield) || model.invulnerable > 0) {
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
    effectSprite(
      c,
      row,
      frame,
      pos,
      tint: demon.flash > 0 ? Colors.white : null,
    );
    if (demon.shield > 0 && demon.shieldMax > 0) {
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
      c.save();
      c.translate(
        wreck.x.roundToDouble(),
        (wreck.y + p * p * 360).roundToDouble(),
      );
      sprite(
        c,
        6,
        wreck.phase,
        Offset.zero,
        184,
        height: 118,
        tint: const Color(0xFF8B665F),
      );
      _damage(c, Offset.zero, 1, p * 10);
      c.restore();
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
