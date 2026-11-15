import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;

import 'atmosphere.dart';
import 'attract.dart';
import 'ground_atmosphere.dart';
import 'ground_atmosphere_atlas.dart';
import 'boss_painter.dart';
import 'ground_painter.dart';
import 'insignia_atlas.dart';
import 'insignia_painter.dart';
import 'model.dart';
import 'music_director.dart'; // --- music event hook
import 'flock.dart' show SwarmFlock;
import 'flyover_background.dart';
import 'sector_background.dart';
import 'shadow_projector.dart';
import 'sentinel_silhouette_atlas.dart';
import 'ship_painter.dart';
import 'sprite_atlas.dart';
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
  ui.Image? atlas, effectsAtlas, sky, cockpitAtlas;

  /// The foreshadow silhouette sheet (tools/sentinel_silhouettes); the
  /// placeholder from the flight frames is drawn while it is missing.
  ui.Image? silhouetteAtlas;
  final ship = ShipPainter();
  // Boss armada: one hull class per run, its atlas loaded on approach.
  final armada = BossPainter();
  final sectors = SectorBackground();
  final creatures = CreaturePresentation();
  // --- alien-insignia: rank glyphs and shield cells over the arena.
  final insignia = InsigniaPainter();
  // --- atmosphere: fog layers and creature veils (atmosphere.dart).
  final atmosphere = Atmosphere();
  final music = MusicDirector(); // --- music event hook (read-only)
  // --- ground war (ground_painter.dart) ---
  late final groundForces = GroundPainter()
    ..occluders = (sectors.flyover..deferFlyers = true)
    ..atmosphere =
        atmosphere // --- ground atmosphere art in the depth sort
    ..eggs = sectors.flyover.eggs;
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
      cockpitAtlas = await images.load('cockpit-panel.png');
    } catch (_) {}
    try {
      insignia.image = await images.load(InsigniaAtlas.file);
    } catch (_) {}
    try {
      silhouetteAtlas = await images.load(SentinelSilhouetteAtlas.file);
    } catch (_) {}
    try {
      // Ship, cannons, muzzle flashes and shots (tools/generate_ship_sprites.py).
      ship.image = await images.load('ship-weapons.png');
      final meta = jsonDecode(
        await rootBundle.loadString('assets/images/ship-weapons.json'),
      ) as Map<String, dynamic>;
      final muzzles = meta['wing_muzzles'] as Map<String, dynamic>? ?? {};
      for (final MapEntry(:key, :value) in muzzles.entries) {
        final power = Power.values.where((p) => p.name == key).firstOrNull;
        if (power == null || value is! Map) continue;
        model.wingMuzzles[power] = (
          x: (value['x'] as num).toDouble(),
          y: (value['y'] as num).toDouble(),
        );
      }
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
    // --- flyover parallax hook (background only) ---
    await sectors.loadFlyover(images.load);
    await atmosphere.load(); // --- atmosphere: fog tiles and shader
    try {
      // --- ground atmosphere art (tools/ground_atmosphere); without it the
      // fBm tiles and the shader keep every slot.
      atmosphere.groundArt = GroundAtmosphereArt(
        await images.load(GroundAtmosphereAtlas.file),
      );
    } catch (_) {}
    // --- ground war art (tools/ground_forces_assets.py) ---
    try {
      groundForces.image = await images.load('ground-forces.png');
      groundForces.troops = await images.load(
        'ground-troops.png',
      ); // --- ground war v4
    } catch (_) {}
  }

  @override
  void update(double dt) {
    super.update(dt);
    if (model.mode != RunMode.paused) advancePresentation(dt);
    if (model.canPilot && keyboardDirection != 0) {
      model.moveBy(keyboardDirection * dt * 280);
    }
    // --- cinematic flow: the accessibility setting picks the plan.
    model.reducedMotion = sectors.flyover.reducedMotion;
    model.update(dt);
    armada.sync(model, images.load, images.clear);
    // --- ground blocks runtime: the current sector's block atlases.
    if (GroundPainter.useBlocks) {
      groundForces.blocks.sync(model, images.load, images.clear);
    }
    music.observe(
      model,
      dt,
    ); // --- music event hook (reads model, before onTick takes events)
    creatures.update(model, dt);
    _notify += dt;
    if (_notify > .05 || model.events.isNotEmpty) {
      _notify = 0;
      onTick();
    }
  }

  /// One presentation step (unpaused): the backdrop's sector blend, the
  /// flyover and the fog. Review harnesses call it with the model step.
  /// The title's attract swarm (cinematic-flow task 6.1).
  final attract = AttractSwarm();

  /// The drawn reserve's opacity: hidden through a transition (playtest
  /// R1), it fades back into the deep fog over [reserveFade] seconds once
  /// the fight is on, instead of popping in.
  double reserveIn = 1;
  static const reserveFade = 1.2;

  void advancePresentation(double dt) {
    reserveIn = model.flow.active
        ? 0
        : math.min(1.0, reserveIn + dt / reserveFade);
    if (model.mode == RunMode.title) {
      attract
        ..reduced = sectors.flyover.reducedMotion
        ..prepare(environment.round().clamp(0, 4))
        ..update(dt);
    }
    // --- cinematic flow: a 60 ms hit-stop on the last kill freezes the
    // presentation clocks only (the model runs on).
    final flow = model.flow;
    final hitStop =
        flow.active && flow.plan.beat('hit') != null && flow.seconds < .06;
    if (!hitStop) {
      ambient += dt;
      final swap = flow.plan.beat('swap');
      final pursuing =
          swap != null &&
          const [
            RunMode.salvage,
            RunMode.levelClear,
            RunMode.travel,
            RunMode.victory,
          ].contains(model.presentationMode);
      if (pursuing) {
        // The palette and backdrop change only inside the cloud's peak.
        final from = (model.level - 1).toDouble();
        final to = (model.nextLevel - 1).toDouble();
        final k = flow.env('swap');
        environment = (to - from).abs() <= 1
            ? from + (to - from) * k
            : (k < .5 ? from : to);
      } else if (flow.active && swap != null) {
        environment = (model.level - 1).toDouble();
      } else {
        final destination = model.presentationMode == RunMode.travel
            ? model.nextLevel - 1
            : model.level - 1;
        environment += (destination - environment) * math.min(1, dt * .65);
      }
      // --- transition ascent: the streaks and the cloud billows scroll at
      // the world's speed (design §3).
      if (flow.active && !model.reducedMotion) {
        final factor = flow.plan.beat('speed') == null
            ? 1.0
            : flow.plan.speedFactor(flow.env('speed'));
        streakRun += dt * streakSpeed * factor;
        cloudRun += dt * 28 * factor;
      } else {
        streakRun = cloudRun = 0;
      }
      // --- flyover parallax hook (visual only; reads model state) ---
      sectors.advance(dt, model, environment);
      syncAtmosphere(dt);
    }
  }

  /// Feeds the fog its clock and the flight distance (visual only). The fog
  /// is world-anchored: it is never given the ship's position.
  void syncAtmosphere(double dt) {
    groundForces.blocks.reducedMotion = sectors.flyover.reducedMotion;
    atmosphere
      ..environment = environment
      ..reducedMotion = sectors.flyover.reducedMotion
      ..tide = model.ground.units.isEmpty ? .5 : model.ground.skirmish.tide
      // --- cinematic flow: the Pursuit's cloud and the outro's thinning.
      ..cloudCover = model.flow.env('cloud')
      ..fogThin = model.flow.env('thin')
      ..cloudScroll = model.reducedMotion ? 0 : cloudRun
      ..advance(dt, distance: sectors.flyover.distance);
  }

  @override
  void render(Canvas canvas) {
    super.render(canvas);
    paintArena(canvas, size, combat: false);
  }

  /// Paints the 360 × 520 arena scaled to fit [dimensions]: centred
  /// across, and at [alignY] down the spare height (0 top, .5 centred,
  /// 1 bottom; the cabinet arena is bottom-aligned on the pilot dock).
  void paintArena(
    Canvas canvas,
    Vector2 dimensions, {
    bool combat = true,
    double alignY = .5,
  }) {
    final scale = math.min(
      dimensions.x / ArcadeModel.width,
      dimensions.y / ArcadeModel.height,
    );
    canvas.save();
    canvas.translate(
      (dimensions.x - ArcadeModel.width * scale) / 2,
      (dimensions.y - ArcadeModel.height * scale) * alignY,
    );
    canvas.scale(scale);
    canvas.clipRect(const Rect.fromLTWH(0, 0, 360, 520));
    final (shakeX, shakeY) = rushShake(); // --- sentinel rush (≤ 2 px)
    if (shakeX != 0 || shakeY != 0) canvas.translate(shakeX, shakeY);
    final panY = model.mode == RunMode.gameOver ? model.cameraPanY : 0.0;
    if (panY > 0.5) {
      _deepStarfieldPan(canvas, panY);
      canvas.save();
      canvas.translate(0, panY);
      _background(canvas);
      final active = model.mode != RunMode.title;
      if (active && combat) {
        groundForces.paintGround(
          canvas,
          model,
        ); // --- ground war: on the ground
        _combat(canvas);
        groundForces.paintAir(
          canvas,
          model,
          ship,
        ); // --- ground war: in the air
        _cinematic(canvas);
      } else {
        sectors.flyover.paintFlyers(canvas); // --- easter eggs: flocks
      }
      canvas.restore();
    } else {
      // --- cinematic flow: the outro's flat tilt (the world slides down)
      // and the shake on the last kill (never in reduced motion).
      // --- transition ascent (design §2): in a sector change the camera
      // pitches up instead: the horizon drops by [pitchDrop]·q and the
      // ground foreshortens about it, and the world banks toward the
      // pursuit about the ship. The band the drop uncovers is already
      // cloud. HUD, comms dock, ship and bullets are never pitched or
      // rolled (the flow ship and the cover are drawn after the world).
      final tilt = model.flow.env('tilt') * flowTilt;
      final q = model.flow.env('pitch');
      final drop = pitchDrop * q;
      final band = tilt + drop;
      final roll = model.flow.env('roll');
      final shake = _flowShake();
      if (roll > .001) {
        // Under a banked world the corners show the cloud, never black.
        canvas.drawRect(
          const Rect.fromLTWH(0, 0, 360, 520),
          Paint()..color = atmosphere.cloud,
        );
      } else if (band > .01) {
        canvas.drawRect(
          Rect.fromLTWH(0, 0, 360, band + 2),
          Paint()..color = atmosphere.cloud,
        );
      }
      canvas.save();
      canvas.translate(shake.dx, tilt + shake.dy);
      if (roll > .001) {
        // About the arena's centre, with just enough overscan that the
        // banked world still covers every edge and corner (a bank about
        // the ship's low row would uncover the frame; design §2,
        // deviations).
        const pivot = Offset(180, 260);
        final k = 1 + rollOverscan * roll;
        canvas
          ..translate(pivot.dx, pivot.dy)
          ..rotate(worldRoll(roll, model.flowDirection))
          ..scale(k, k)
          ..translate(-pivot.dx, -pivot.dy);
      }
      final active = model.mode != RunMode.title;
      if (q > .001) {
        // The sky translates with the horizon; the ground plane turns
        // about it (near rows leave the bottom first).
        final h = Perspective.horizonY + drop;
        canvas.save();
        // Overlaps the ground pass by 2 units: no hairline at the seam.
        canvas.clipRect(Rect.fromLTRB(-40, -40, 400, h + 2));
        canvas.translate(0, drop);
        _background(canvas);
        canvas.restore();
        canvas.save();
        canvas.clipRect(Rect.fromLTRB(-40, h, 400, 760));
        _groundPitch(canvas, q);
        _background(canvas);
        canvas.restore();
        _groundPitch(canvas, q);
      } else {
        _background(canvas);
      }
      if (active && combat) {
        groundForces.paintGround(
          canvas,
          model,
        ); // --- ground war: on the ground
        _combat(canvas);
        groundForces.paintAir(
          canvas,
          model,
          ship,
        ); // --- ground war: in the air
        _cinematic(canvas);
      } else {
        sectors.flyover.paintFlyers(canvas); // --- easter eggs: flocks
        if (!active) _attractPass(canvas); // --- cinematic flow: attract
      }
      canvas.restore();
      if (active && combat) {
        // --- cinematic flow: the cover, the pursued flock (sprites that
        // turn to dark silhouettes in the cloud) and the climbing ship.
        if (band > .01) {
          // Feather the band the tilt or pitch uncovered into the scene
          // below it.
          canvas.drawRect(
            Rect.fromLTWH(0, 0, 360, band + 36),
            Paint()
              ..shader = ui.Gradient.linear(
                Offset.zero,
                Offset(0, band + 36),
                [atmosphere.cloud, atmosphere.cloud.withValues(alpha: 0)],
                [band / (band + 36), 1],
              ),
          );
        }
        atmosphere.paintCloudCover(
          canvas,
          below: model.flow.kind == FlowKind.campaignOutro,
          warmth: model.flow.env('thin'),
        );
        _fogStreaks(canvas); // --- transition ascent: speed past the ship
        _flowFlockPass(canvas, band);
        _cinematicFlowShip(canvas);
      }
    }
    canvas.restore();
  }

  /// The transition's flock: in clear air the creature itself (veiled by
  /// depth), in the cloud a dark silhouette ahead of the ship (design §3.1:
  /// pattern sweep, silhouette tint).
  void _flowFlockPass(Canvas c, double tilt) {
    if (model.flowFlock.isEmpty) return;
    // Under an outro the cloud is below the flock: no silhouettes.
    final cloud = model.flow.kind == FlowKind.campaignOutro
        ? 0.0
        : model.flow.env('cloud');
    // The rout's flash expansion: a white flash as the brood breaks.
    final flash = model.flow.on('rout') && model.flow.seconds < .2;
    final ink = Color.lerp(atmosphere.veil, const Color(0xFF0B0E18), .55)!;
    final silhouette = ColorFilter.mode(ink, BlendMode.srcIn);
    final members = [...model.flowFlock]
      ..sort((a, b) => a.demon.nearness.compareTo(b.demon.nearness));
    for (final m in members) {
      final o = model.flowOpacity(m);
      if (o <= AirCensus.flockDrawn) continue;
      final d = m.demon;
      final pos = Offset(
        d.x.roundToDouble(),
        (d.y + tilt * .4).roundToDouble(),
      );
      final cell = CombatAtlas.creature(d, model.clock);
      // Fleeing in clear air it stays readable: a creature in the haze.
      final t = math.max(.55, Perspective.transmittance(d.nearness));
      c.save();
      _scaleAbout(c, pos, d.scale);
      final body = o * (1 - .8 * cloud) * _bodyOpacity(d.nearness);
      if (body > .01) {
        sprite(
          c,
          cell.row,
          cell.col,
          pos,
          40,
          tint: flash ? Colors.white : null,
          filter: flash ? null : atmosphere.tintFor(t),
          opacity: body,
        );
      }
      final shade = o * .82 * cloud;
      if (shade > .01) {
        sprite(
          c,
          cell.row,
          cell.col,
          pos,
          40,
          filter: silhouette,
          opacity: shade,
        );
      }
      c.restore();
    }
  }

  /// The title's attract swarm (design §5): shadows on the ground, the
  /// squads drawn far to near between the fog layers, the sentinel's
  /// silhouette in the horizon band.
  void _attractPass(Canvas c) {
    final a = attract;
    if (a.members.isEmpty || atlas == null) return;
    final presence = a.presence;
    _creatureShadows(c, also: presence > .3 ? a.members : const []);
    final fogSlots = Atmosphere.depthSlots;
    var next = 0;
    void fog() {
      final slot = fogSlots[next++];
      atmosphere.paint(c, slot);
      if (slot == FogSlot.horizonBand) _foreshadowSilhouette(c, a.sentinel);
    }

    final sorted = [...a.members]
      ..sort((x, y) => x.nearness.compareTo(y.nearness));
    for (final d in sorted) {
      while (next < fogSlots.length &&
          Atmosphere.layers[fogSlots[next]]!.nearness <= d.nearness) {
        fog();
      }
      final pos = Offset(d.x.roundToDouble(), d.y.roundToDouble());
      final cell = CombatAtlas.creature(d, ambient);
      final t = Perspective.transmittance(d.nearness);
      c.save();
      _scaleAbout(c, pos, d.scale);
      sprite(
        c,
        cell.row,
        cell.col,
        pos,
        40,
        filter: atmosphere.tintFor(t),
        opacity: presence * _bodyOpacity(d.nearness),
      );
      c.restore();
    }
    while (next < fogSlots.length) {
      fog();
    }
  }

  /// Shake on the last kill: at most 2 units, none with reduced motion.
  Offset _flowShake() {
    final hit = model.flow.env('hit');
    if (hit <= 0 || model.reducedMotion) return Offset.zero;
    final t = model.flow.seconds;
    return Offset(
      (math.sin(t * 91) * 2 * hit).roundToDouble(),
      (math.cos(t * 73) * 2 * hit).roundToDouble(),
    );
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
      paint.color =
          (i % 7 == 0 ? gold : (i % 4 == 0 ? mint : const Color(0xFFD8E6FF)))
              .withValues(
                alpha: (twinkle * (0.28 + depth * 0.18)).clamp(0.1, 0.95),
              );
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
    c.drawRect(cardRect, Paint()..color = const Color(0xF2070D18));
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
    c.drawPath(
      Path()
        ..moveTo(24, boardY + 60 + clen)
        ..lineTo(24, boardY + 60)
        ..lineTo(24 + clen, boardY + 60),
      cornerPaint,
    );
    c.drawPath(
      Path()
        ..moveTo(336 - clen, boardY + 60)
        ..lineTo(336, boardY + 60)
        ..lineTo(336, boardY + 60 + clen),
      cornerPaint,
    );
    c.drawPath(
      Path()
        ..moveTo(24, boardY + 440 - clen)
        ..lineTo(24, boardY + 440)
        ..lineTo(24 + clen, boardY + 440),
      cornerPaint,
    );
    c.drawPath(
      Path()
        ..moveTo(336 - clen, boardY + 440)
        ..lineTo(336, boardY + 440)
        ..lineTo(336, boardY + 440 - clen),
      cornerPaint,
    );

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
    final blink = (math.sin(model.visualClock * 6).abs() * 0.7 + 0.3).clamp(
      0.0,
      1.0,
    );
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

  void _background(Canvas c) => sectors.paint(
    c,
    environment,
    ambient,
    model.cycle,
    sky,
    wave: model.wave,
  );

  void sprite(
    Canvas c,
    int row,
    int col,
    Offset center,
    double width, {
    double? height,
    Color? tint,
    ColorFilter? filter,
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
    } else if (filter != null) {
      paint.colorFilter = filter;
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
    ColorFilter? filter,
    ui.ImageFilter? blur,
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
    } else if (filter != null) {
      paint.colorFilter = filter;
    }
    if (blur != null) paint.imageFilter = blur;
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
    insignia.begin(); // --- alien-insignia: this frame's marks
    _rims = 0;
    // --- atmosphere: ground fog lies on the terrain, over the shadows.
    if (model.perspective) atmosphere.paint(c, FogSlot.groundFog);
    // --- easter eggs: flock flyers over the ground fog (in the air).
    sectors.flyover.paintFlyers(c);
    _creatureShadows(c); // --- continuous swarm: every flyer, the ship
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
      sprite(
        c,
        CombatAtlas.pickupRow,
        CombatAtlas.badge(p.power),
        Offset(p.x, p.y),
        36,
      );
    }
    for (final crate in model.supplyCrates) {
      _paintSupplyCrate(c, crate);
    }
    _carrierBackdrop(c);
    // --- perspective: far to near, each drawn at its simulated scale. The
    // next wave, still approaching (model.incoming), is the farthest of all.
    // The fog layers are drawn when the sort passes their nearness, so a
    // creature at n .35 is behind bank B and in front of bank A, and an
    // arrival rises up through the layers one by one (fog-restoration).
    // --- continuous swarm: the reserve (groups and later skeins waiting in
    // the deep fog) is drawn veiled with the approaching cohort; neither
    // shows gear (swarmState is the contract with the fog layers).
    final census = airCensus();
    final approaching = census.approaching;
    final fogSlots = model.perspective
        ? Atmosphere.depthSlots
        : const <FogSlot>[];
    var nextFog = 0;
    final tells = <Demon>[];
    void fog() {
      final slot = fogSlots[nextFog++];
      atmosphere.paint(c, slot);
      // The sentinel's silhouette circles in the murk: in front of the
      // horizon band's glow (a darker shape in the fog), behind the far
      // banks and both veils, which drift across it at their own winds.
      if (slot == FogSlot.horizonBand) _foreshadowSilhouette(c);
    }

    for (final d in _byDepth(census.bodies)) {
      while (nextFog < fogSlots.length &&
          Atmosphere.layers[fogSlots[nextFog]]!.nearness <= d.nearness) {
        fog();
      }
      final warning = d.telegraph > 0;
      // continuous-swarm: visible evasion moves the drawing only (a third
      // of the hitbox at most), never the creature.
      final (lx, ly) = d.isLarge ? (0.0, 0.0) : creatures.look.offset(d);
      final pos = Offset(d.x + lx, d.y + ly);
      if (d.isLarge) {
        // Large creatures have their own delayed entrance in simulation
        // (the census leaves one that has not set out undrawn).
        {
          // --- sentinel rush: the lock shudders it in place (±2 px).
          final shudder =
              d.lastStand &&
                  d.rushPhase == RushPhase.lock &&
                  !sectors.flyover.reducedMotion
              ? Offset(
                  (math.sin(model.clock * 71) * 2).roundToDouble(),
                  (math.cos(model.clock * 53) * 1).roundToDouble(),
                )
              : Offset.zero;
          final at = pos + shudder;
          if (d.lastStand) _sentinelBerserkTrail(c, at, d);
          c.save();
          _scaleAbout(c, at, d.scale);
          _sentinel(c, at, d);
          if (d.lastStand) _sentinelBerserk(c, at, d);
          c.restore();
          if (d.lastStand) _rushShieldRing(c, at, d);
        }
        continue;
      }
      // One transmittance per creature drives tint, saturation, contrast
      // and the staged reveal: shields, armour and rank halos (no health pips:
      // ux-declutter; hits read from the flash and the shed armour)
      // belong to a creature that has come out of the weather.
      final holding = approaching.contains(d);
      final t = _transmittance(d, holding: holding);
      final reveal = Perspective.gearReveal(t);
      c.save();
      _scaleAbout(c, pos, d.scale); // sizes below are at scale 1
      // --- alien-insignia: the elite's dotted ring is gone; its ocellus
      // (and every rank's glyph) is drawn over the arena after the fog.
      // Gargoyle frames carry their own banking (3/4 left/neutral/right
      // renders), so the sprite is drawn upright; see CombatAtlas.creature.
      c.save();
      final tilt = creatures.look.of(d)?.tilt ?? 0;
      if (tilt.abs() > .02) {
        // Wing tilt of the agitation wave: a small roll about the body.
        c.translate(pos.dx, pos.dy);
        c.rotate(tilt * .14);
        c.translate(-pos.dx, -pos.dy);
      }
      final cell = CombatAtlas.creature(
        d,
        model.clock,
        fireAge: creatures.fireAge(d),
        motion: creatures.motion.of(d),
      );
      final size = d.angry ? 44.0 : 40.0;
      final far =
          (model.perspective ? _bodyOpacity(d.nearness) : 1.0) *
          (census.reserve.contains(d) ? reserveIn : 1.0);
      // --- alien-insignia: state rim under the body, wound warm-up in the
      // body's colour filter, the rank glyph queued at the head anchor.
      final mark = InsigniaPainter.revealAlpha(t) * far;
      final telling = d.telegraph > 0 && _tellOn;
      final rim = mark <= 0
          ? null
          : telling
          ? const Color(0xFFFFFFFF)
          : d.angry
          ? InsigniaPainter.rimEmber
          : null;
      if (rim != null && _rims < InsigniaPainter.maxRims) {
        _rims++;
        final w = InsigniaPainter.unitsPerGlyphPx / d.scale;
        for (final o in [
          Offset(w, 0),
          Offset(-w, 0),
          Offset(0, w),
          Offset(0, -w),
        ]) {
          sprite(
            c,
            cell.row,
            cell.col,
            pos + o,
            size,
            tint: rim,
            opacity: mark,
          );
        }
      }
      sprite(
        c,
        cell.row,
        cell.col,
        pos,
        size,
        tint: cell.tintFlash ? Colors.white : null,
        filter: cell.tintFlash ? null : _bodyFilter(t, d.moltStage.clamp(0, 3)),
        opacity: far,
      );
      if (mark > 0) {
        final head = CombatAtlas.headAnchor(
          cell.row,
          cell.col,
          lift: cell.lift,
        );
        final k = size / CombatAtlas.cell * d.scale;
        insignia.rank(
          d,
          CombatAtlas.rankOf(d),
          pos + Offset(head.dx * k, (head.dy - 1) * k),
          tone: telling
              ? InsigniaTone.tell
              : d.angry
              ? InsigniaTone.angry
              : InsigniaTone.bone,
          alpha: mark,
        );
      }
      final glow = Perspective.glowAlpha(t) - t;
      if (glow > .02 && !cell.tintFlash) {
        // Eyes and cracks punch through the fog (research §1).
        sprite(
          c,
          cell.row,
          cell.col,
          pos,
          size,
          filter: Atmosphere.glowMatrix,
          opacity: glow * far,
        );
      }
      if (d.elite && reveal > 0) {
        // Authored elite armour for this direction/pose, shed one level per
        // hit, offset by the frame's whole-pixel body lift.
        sprite(
          c,
          cell.eliteRow,
          cell.eliteCol,
          pos + Offset(0, cell.lift * size / CombatAtlas.cell),
          size,
          opacity: reveal,
        );
      }
      _creatureLighting(
        c,
        pos,
        0,
        width: d.angry ? 36 : 32,
        diving: d.dive > 0,
      );
      c.restore();
      final fired = creatures.fireAge(d);
      if (fired != null && fired < 0.16) {
        sprite(
          c,
          CombatAtlas.effectRow,
          CombatAtlas.enemyMuzzleCol + (fired / 0.04).floor().clamp(0, 3),
          pos + const Offset(0, 12),
          20,
        );
      }
      if (warning) tells.add(d); // drawn above the sky sheets
      if (d.dive > 0 && d.diveShield > 0 && reveal > 0) {
        _smallOrMediumDiveShield(c, pos, d);
      }
      c.restore();
    }
    while (nextFog < fogSlots.length) {
      fog();
    }
    if (fogSlots.isEmpty) _foreshadowSilhouette(c);
    for (final fx in creatures.deaths) {
      c.save();
      c.translate(fx.x, fx.y);
      c.rotate(fx.bank.clamp(-1.0, 1.0) * 0.09);
      sprite(
        c,
        CombatAtlas.deathRow(fx.kind),
        CombatAtlas.deathCol + fx.frame,
        Offset.zero,
        44 * fx.scale,
      );
      c.restore();
    }
    final b = model.boss;
    if (b != null) {
      c.save();
      _carrierArrival(c, b, effects: true);
      final carrierBank = _carrierBank(b);
      final hullDamage = (1 - b.core / b.coreMax).clamp(0.0, 1.0);
      if (armada.ready) {
        // Bright bow: idle life (eye pulse, ear-fin breath, spine flex and
        // fissure flicker at 2 fps), damage and the turret heads.
        final turretFrame =
            ((model.visualClock * 6 + (model.shipX > b.x ? 1 : 0)).floor() % 4);
        armada.paintBow(
          c,
          b,
          clock: model.visualClock,
          damageCell: _carrierDamageCell(hullDamage),
          turretFrame: turretFrame,
        );
        _carrierTurretBarrels(c, b);
        armada.paintRcs(c, Offset(b.x, b.y), carrierBank, model.visualClock);
      } else {
        sprite(
          c,
          CombatAtlas.fallbackRow,
          4 + b.phase.clamp(0, 3),
          Offset(b.x, b.y),
          184,
          height: 118,
        );
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
      if (armada.ready) {
        // Authored blast jaws: fanged armoured leaves.
        armada.paintJaws(c, b);
      } else {
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
      }
      if (b.shield > 0) {
        // A fixed-width egg encases the hull; depletion brings its surface
        // inward vertically, so incoming fire visibly reaches nearer the ship.
        final strength = b.shield / b.shieldMax;
        final paint = Paint()..isAntiAlias = false;
        // alien-insignia: the force-shield cyan family (styleguide §3),
        // dimming toward the spent-socket teal as it wears.
        final Color shieldColor;
        if (strength > 0.6) {
          shieldColor = InsigniaPainter.rimCyan;
        } else if (strength > 0.25) {
          // Stressed force field dims with fracture flicker.
          shieldColor = const Color(0xFF3FC4DC);
        } else {
          // Critical force field flickers rapidly with warning energy
          final flicker = (math.sin(model.visualClock * 24) + 1.0) * 0.5;
          shieldColor = Color.lerp(
            const Color(0xFF1C6F86),
            InsigniaPainter.rimCyan,
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
              b.x +
              math.sin(model.visualClock * 9) * (b.forceFieldHalfWidth * 0.7);
          final arcY = b.forceFieldSurfaceY(arcX);
          c.drawLine(
            Offset(arcX - 6, arcY - 3),
            Offset(arcX + 4, arcY + 2),
            arcP,
          );
        }
      }
      _damage(c, Offset(b.x, b.y), hullDamage, model.visualClock);
      c.restore();
      _carrierInsignia(b);
    }
    // --- atmosphere: one or two very thin sheets over the arena, creatures
    // and carrier included. Bullets, the player, tells and the HUD are drawn
    // after them: never fogged (research §11).
    if (model.perspective) {
      atmosphere.paint(c, FogSlot.skySheet1);
      atmosphere.paint(c, FogSlot.skySheet2);
    }
    for (final d in tells) {
      final pos = Offset(d.x, d.y);
      c.save();
      _scaleAbout(c, pos, d.scale);
      _wingTellChevrons(c, pos);
      c.restore();
    }
    // --- alien-insignia: rank glyphs, shield cells and shards, drawn after
    // the arena camera at a fixed size (identity until boss-grandeur's
    // camera lands: pass its toScreen here).
    creatures.shields.paintShards(c);
    insignia.paint(c, now: model.visualClock);
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

      if (ship.paintShot(c, model, s, (s.y / 9).floor())) continue;
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
        !model.shipAway && // --- life-loss sequence: the ship is away
        (model.invulnerable == 0 || (model.clock * 12).floor() % 2 == 0)) {
      // --- life-loss sequence: the reserve ship flies in from below.
      final rise = model.shipDrawY - ArcadeModel.shipY;
      if (rise.abs() > .01) {
        c.save();
        c.translate(0, rise.roundToDouble());
        _playerShip(c);
        c.restore();
      } else {
        _playerShip(c);
      }
    }
    _lifeLossEffects(c); // --- life-loss sequence
    // Spent modules are debris outside the ship's own drawing, so they keep
    // falling through cutscenes and damage blinking instead of vanishing.
    _fallingParts(c);
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
      // A creature with an authored death sequence replaces its blast.
      if (creatures.suppressed(b)) continue;
      sprite(
        c,
        CombatAtlas.explosionRow,
        (b.blastRadius > 0 ? 8 : 0) + (b.age / .55 * 8).floor().clamp(0, 7),
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

  /// alien-insignia: the carrier's form glyph on the brood sigil (the
  /// rank ladder: talon, two talons, ocellus, crown) and its 12 hull cells
  /// on the force field's lower arc, `ceil(12 · shield / shieldMax)` lit.
  void _carrierInsignia(Carrier b) {
    insignia.rank(
      b,
      InsigniaPainter.carrierRank(b.phase),
      Offset(b.x, b.y + carrierSigilY),
      size: 2,
    );
    final fx = creatures.shields;
    if (b.shieldMax <= 0 || (b.shield <= 0 && fx.bossFlashes.isEmpty)) return;
    final lit = ShieldFx.bossCells(b.shield, b.shieldMax);
    final on = InsigniaPainter.litCells(12, lit);
    for (var i = 0; i < 12; i++) {
      final x = b.x + (i / 11 - .5) * 1.5 * b.forceFieldHalfWidth;
      final at = Offset(x, b.forceFieldSurfaceY(x));
      insignia.cell(at, fx.bossCellState(i, on[i], at), size: 1.5);
    }
  }

  /// Where the carrier's sigil glyph sits (units below its centre).
  static const double carrierSigilY = -16;

  // --- alien-insignia: per-frame rim budget, the tell flash and the
  // wound warm-up composed into the body's veil filter (design §5).
  int _rims = 0;

  /// Rims drawn in the last frame (at most InsigniaPainter.maxRims).
  int get rimCount => _rims;
  bool get _tellOn => InsigniaPainter.tellOn(
    model.visualClock,
    reducedMotion: sectors.flyover.reducedMotion,
  );
  final Map<int, ColorFilter?> _warmFilters = {};
  int _warmVeil = 0;

  ColorFilter? _bodyFilter(double t, int molt) {
    if (molt <= 0) return atmosphere.tintFor(t);
    final bucket = Perspective.tintBucket(t);
    final veil = atmosphere.veil;
    if (veil.toARGB32() != _warmVeil) {
      _warmFilters.clear();
      _warmVeil = veil.toARGB32();
    }
    return _warmFilters[bucket * 4 + molt] ??= ColorFilter.matrix(
      bucket >= 15
          ? InsigniaPainter.warmMatrix(molt)
          : InsigniaPainter.compose(
              Atmosphere.veilMatrix(bucket / 15, veil),
              InsigniaPainter.warmMatrix(molt),
            ),
    );
  }

  /// Jettisoned overheated or replaced components tumbling off the ship.
  void _fallingParts(Canvas c) {
    for (final part in model.fallingParts) {
      c.save();
      c.translate(part.x, part.y);
      c.rotate(part.rotation);
      if (ship.ready && ShipPainter.rows.containsKey(part.power)) {
        ship.paintPart(c, part);
        c.restore();
        continue;
      }
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
        if (damage > .8 && vent.isEven) {
          // Critical hull: black smoke columns, big flames and shed plates.
          effectSprite(
            c,
            12,
            frame,
            point + Offset(side * 3, -18.0 - frame * 4),
            scale: .6,
          );
          effectSprite(
            c,
            12,
            4 + frame,
            point + const Offset(0, -6),
            scale: .5,
          );
          effectSprite(
            c,
            5,
            4 + (time * 6 + vent).floor() % 4,
            point,
            scale: .5,
          );
        }
      }
    }
  }

  /// Bow damage overlay (stage 0-2, flicker frame) in the class atlas:
  /// cracked plating, then torn plates over the glowing interior, then
  /// gaping breaches; each stage alternates two authored flicker frames.
  (int, int)? _carrierDamageCell(double damage) {
    if (damage <= .15) return null;
    final flick = (model.visualClock * 5).floor().isOdd ? 1 : 0;
    if (damage > .75) return (2, flick);
    if (damage > .45) return (1, flick);
    return (0, flick);
  }

  double _carrierBank(Carrier b) => model.defeatActive
      ? (math.sin(model.visualClock * 2.5) * 0.45).clamp(-1.0, 1.0)
      : (b.horizontalVelocity / 90).clamp(-1.0, 1.0);

  /// Arrival descent offset (and, once, its effects) shared by both layers.
  void _carrierArrival(Canvas c, Carrier b, {bool effects = false}) {
    if (model.presentationMode != RunMode.transition) return;
    final p = model.transitionProgress.clamp(0.0, 1.0);
    final descent = 1 - Curves.easeOutCubic.transform(p);
    c.translate(0, -180 * descent);
    if (effects) _bossOrbitalArrivalEffects(c, b, p, descent);
  }

  /// The armada's background layer (engine plumes, superstructure, its
  /// breaches and running lights), drawn before the creatures so the
  /// outer hull reads as non-solid background that shots pass over.
  void _carrierBackdrop(Canvas c) {
    final b = model.boss;
    if (b == null || !armada.ready) return;
    c.save();
    _carrierArrival(c, b);
    final arriving = model.presentationMode == RunMode.transition;
    armada.paintBackdrop(
      c,
      b,
      clock: model.visualClock,
      bank: _carrierBank(b),
      damage: (1 - b.core / b.coreMax).clamp(0.0, 1.0),
      burn: arriving
          ? .2
          : model.defeatActive
          ? (math.sin(model.visualClock * 9.2) > 0 ? 1.0 : .5)
          : -1,
    );
    c.restore();
  }

  void _carrierEyes(Canvas c, Carrier carrier) {
    if (carrier.rage <= 0) return;
    // Rage over the authored gargoyle eyes (boss-carrier.png: slanted eyes
    // from x 6.5 to 20 units off centre, y -8.5 to 0). Stepped red surrounds
    // supply glow without blurred circles; the inner strip runs hotter.
    final center = Offset(carrier.x.roundToDouble(), carrier.y.roundToDouble());
    final pulse = (model.clock * 6).floor().isEven ? .12 : 0.0;
    final hot = Color.lerp(gold, const Color(0xFFFF274E), carrier.rage)!;
    final paint = Paint()..isAntiAlias = false;
    // Three steps per eye, outer (higher) to inner (lower): x, y, width.
    const steps = [(-20.0, -8.0, 5.0), (-15.0, -6.0, 4.0), (-11.0, -4.0, 4.0)];
    for (final side in [-1.0, 1.0]) {
      for (var i = 0; i < steps.length; i++) {
        final (x, y, w) = steps[i];
        final left = side < 0 ? center.dx + x : center.dx - x - w;
        paint.color = const Color(0xFFFF274E)
            .withValues(alpha: carrier.rage * (.2 + pulse));
        c.drawRect(Rect.fromLTWH(left - 1, center.dy + y - 2, w + 2, 6), paint);
        paint.color = hot.withValues(alpha: .35 + carrier.rage * .45);
        c.drawRect(Rect.fromLTWH(left, center.dy + y, w, 2), paint);
        if (carrier.rage > .6 && i == 1) {
          paint.color = const Color(0xFFFFC7AF);
          c.drawRect(Rect.fromLTWH(left + 1, center.dy + y, 2, 1), paint);
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
    final flameLen =
        7.0 + thrust * 6.0 + ((model.clock * 18).floor() % 2) * 2.0;
    final tailShift = (-bank * 5.0).roundToDouble();
    paint.color = mint.withValues(alpha: 0.48 + thrust * 0.25);
    c.drawRect(
      Rect.fromLTWH(
        (center.dx - 3 + tailShift * 0.5).roundToDouble(),
        (center.dy + (ship.ready ? 18 : 13)).roundToDouble(),
        6,
        flameLen,
      ),
      paint,
    );
    paint.color = const Color(0xFFFFEDBF);
    c.drawRect(
      Rect.fromLTWH(
        (center.dx - 1 + tailShift).roundToDouble(),
        (center.dy + (ship.ready ? 19 : 14)).roundToDouble(),
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
    if (ship.ready) {
      // continuous-swarm: a creature's shadow over the ship dims it a
      // little (capped at 15 %, so the outline stays readable).
      final dim = shipShadowDim;
      if (dim > .005) {
        final g = (255 * (1 - dim)).round();
        c.saveLayer(
          null,
          Paint()
            ..colorFilter = ColorFilter.mode(
              Color.fromARGB(255, g, g, g),
              BlendMode.modulate,
            ),
        );
      }
      ship.paintShip(c, model, center);
      if (dim > .005) c.restore();
    } else {
      sprite(
        c,
        CombatAtlas.fallbackRow,
        (model.clock * 14).floor() % 4,
        center,
        42,
      );
    }
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
      // Gimbal ticks sit on the canards of the 64-grid hull.
      final mountX = (center.dx + side * (ship.ready ? 3.5 : 5))
          .roundToDouble();
      final mountY = (center.dy - (ship.ready ? 6 : 10)).roundToDouble();
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
    if (!ship.ready && model.hasPower(Power.rapid)) {
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
    if (!ship.ready && model.hasPower(Power.spread)) {
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
    if (!ship.ready && model.hasPower(Power.large)) {
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

    // Player Force Field with 3 Decay Stages
    final shieldTime = model.timeLeft(Power.shield);
    if (shieldTime > 0 && ship.ready) {
      ship.paintShield(c, model, center);
    } else if (shieldTime > 0) {
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
      Rect.fromCenter(center: Offset(canopyX, canopyY), width: 34, height: 20),
      math.pi,
      math.pi,
      true,
      Paint()..color = const Color(0xFFF0F5FA),
    );
    c.drawArc(
      Rect.fromCenter(center: Offset(canopyX, canopyY), width: 14, height: 20),
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
    sprite(
      c,
      CombatAtlas.pickupRow,
      CombatAtlas.badge(crate.power),
      Offset(cx, cy),
      22,
    );

    // No durability pips (ux-declutter): each hit flashes the crate.
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
      paint.color = diving ? const Color(0xB8FF9100) : const Color(0x9970F5D5);
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

  // --- perspective (lib/game/perspective.dart, plan/perspective.md) ---
  // --- atmosphere (lib/game/atmosphere.dart, atmosphere-and-swarms) ---

  /// Transmittance of the air in front of [d]: 1 when depth is off or the
  /// creature is not yet placed on the camera; capped while it holds in the
  /// fog with the approaching wave.
  double _transmittance(Demon d, {bool holding = false}) {
    if (!model.perspective || d.nearness <= 0) return holding ? 0 : 1;
    return Perspective.transmittance(d.nearness, holding: holding);
  }

  /// Body opacity with depth: the farthest arrivals are thinner shapes in
  /// the weather (the tint carries most of the veil).
  static double _bodyOpacity(double n) =>
      .55 + .45 * Perspective.smoothstep(.22, .42, n);

  /// The coming sentinel's silhouette (design §5): a darker patch of the
  /// fog in its shape, soft-edged, with a thin warm rim toward the sun and
  /// eyes that ignore most of the fog. The silhouette sheet (task 5.1)
  /// carries the bank and the softness; the sentinel's own flight frames are
  /// the fallback while it is missing.
  void _foreshadowSilhouette(Canvas c, [SentinelForeshadow? override]) {
    final f = override ?? model.foreshadow;
    if (f == null || !f.visible) return;
    final species = f.archetype == EnemyArchetype.armoredSentinel ? 1 : 0;
    if (silhouetteAtlas != null) {
      _bankedSilhouette(c, f, species);
      return;
    }
    if (effectsAtlas == null) return;
    // A slow, heavy stroke: the giant's wings beat at about half the rate.
    const strokes = [0, 1, 2, 3, 2, 1];
    final frame = strokes[(f.clock / .55).floor() % strokes.length];
    final pos = Offset(f.x.roundToDouble(), f.y.roundToDouble());
    final o = f.opacity;
    c.save();
    c.translate(pos.dx, pos.dy);
    c.rotate(f.bank * .1);
    // Slow breathing: +-1 % over five seconds.
    final breathe = 1 + .01 * math.sin(f.clock * 2 * math.pi / 5);
    c.scale(f.scale * breathe * (1 - f.bank.abs() * .06), f.scale * breathe);
    c.translate(-pos.dx, -pos.dy);
    _silhouetteSprite(c, species, frame, pos, o);
    c.restore();
  }

  /// The foreshadow from the silhouette sheet: the banking frame for the
  /// path's bank, far blur cross-fading to near blur as it comes closer.
  void _bankedSilhouette(Canvas c, SentinelForeshadow f, int species) {
    final sheet = silhouetteAtlas!;
    final frame = SentinelSilhouetteAtlas.frameFor(f.bank);
    final pos = Offset(f.x.roundToDouble(), f.y.roundToDouble());
    final o = f.opacity;
    final near = Perspective.smoothstep(.12, .26, f.nearness);
    final breathe = 1 + .01 * math.sin(f.clock * 2 * math.pi / 5);
    final k = f.scale * breathe;
    const w = SentinelSilhouetteAtlas.cellW * 1.0;
    const h = SentinelSilhouetteAtlas.cellH * 1.0;
    final dst = Rect.fromLTWH(
      (pos.dx - w / 2 * k).roundToDouble(),
      (pos.dy - h / 2 * k).roundToDouble(),
      w * k,
      h * k,
    );
    void draw(
      int blur,
      Color colour,
      double alpha, {
      Offset shift = Offset.zero,
    }) {
      if (alpha <= .01) return;
      c.drawImageRect(
        sheet,
        SentinelSilhouetteAtlas.cell(species, frame, blur),
        dst.shift(shift),
        Paint()
          ..isAntiAlias = false
          ..filterQuality = FilterQuality.none
          ..color = Colors.white.withValues(alpha: alpha.clamp(0.0, 1.0))
          ..colorFilter = ColorFilter.mode(colour, BlendMode.srcIn),
      );
    }

    final veil = atmosphere.veil, air = atmosphere.air;
    final body = Color.lerp(veil, const Color(0xFF06050B), .7)!;
    // Warm rim toward the sun, the body (far and near blur), a breath of air.
    draw(0, const Color(0xFFE2A46E), .26 * o, shift: const Offset(-1.5, -1.5));
    draw(1, body, .92 * o * (1 - near));
    draw(0, body, .92 * o * near);
    draw(1, air, .05 * o, shift: const Offset(0, 3));
    final a = SentinelSilhouetteAtlas.bankDeg[frame] * math.pi / 180;
    _sentinelEyes(c, pos, .95 * o, angle: a, scale: k);
  }

  /// The silhouette treatment of a sentinel frame at [pos], opacity [o].
  void _silhouetteSprite(
    Canvas c,
    int species,
    int frame,
    Offset pos,
    double o,
  ) {
    final veil = atmosphere.veil, air = atmosphere.air;
    final body = Color.lerp(veil, const Color(0xFF06050B), .7)!;
    // Warm rim: the body shifted toward the sun, under the body.
    effectSprite(
      c,
      species,
      frame,
      pos.translate(-1.5, -1.5),
      filter: const ColorFilter.mode(Color(0xFFE2A46E), BlendMode.srcIn),
      opacity: .26 * o,
    );
    effectSprite(
      c,
      species,
      frame,
      pos,
      filter: ColorFilter.mode(body, BlendMode.srcIn),
      blur: ui.ImageFilter.blur(sigmaX: 1.6, sigmaY: 1.6),
      opacity: .92 * o,
    );
    // A breath of the air over its far wing edge: depth inside the shape.
    effectSprite(
      c,
      species,
      frame,
      pos.translate(0, 3),
      filter: ColorFilter.mode(air, BlendMode.srcIn),
      blur: ui.ImageFilter.blur(sigmaX: 4, sigmaY: 4),
      opacity: .05 * o,
    );
    _sentinelEyes(c, pos, .95 * o);
  }

  /// Emissive eyes for a fogged sentinel: the gold species' body is as warm
  /// as its eyes, so an emissive mask cannot separate them; two embers at
  /// the head (cell 128 x 64, eyes 6 px either side, 6 px above centre).
  void _sentinelEyes(
    Canvas c,
    Offset pos,
    double o, {
    double angle = 0,
    double scale = 1,
  }) {
    if (o <= .02) return;
    final halo = Paint()
      ..color = const Color(0xFFFF9A3C).withValues(alpha: .35 * o)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2.5);
    final core = Paint()
      ..isAntiAlias = false
      ..color = const Color(0xFFFFE7A8).withValues(alpha: o);
    for (final side in [-1.0, 1.0]) {
      final ex = side * 5.5 * scale, ey = -6.0 * scale;
      final e = pos.translate(
        ex * math.cos(angle) - ey * math.sin(angle),
        ex * math.sin(angle) + ey * math.cos(angle),
      );
      c.drawCircle(e, 3.2, halo);
      c.drawRect(Rect.fromCenter(center: e, width: 2, height: 2), core);
    }
  }

  List<Demon> _byDepth(List<Demon> demons) {
    final order = List<int>.generate(demons.length, (i) => i)
      ..sort((a, b) {
        final c = demons[a].nearness.compareTo(demons[b].nearness);
        return c != 0 ? c : a - b;
      });
    return [for (final i in order) demons[i]];
  }

  /// An arrival waiting to set out stays parked, undrawn, at its far start.
  bool _parked(Demon d) =>
      model.perspective &&
      d.entering &&
      d.arrivesFromDistance &&
      d.entranceProgress <= 0 &&
      d.swarmState != SwarmState.reserve;

  /// Whether [d] casts a shadow on the terrain: a body that is drawn.
  bool _casts(Demon d) =>
      d.swarmState != SwarmState.reserve &&
      !_parked(d) &&
      !(d.isLarge && d.entranceProgress <= 0);

  /// What the air passes draw this frame (playtest R1: the one list the
  /// combat pass, the flock pass and the shadow pass all read, so a test
  /// can prove what is in or behind the fog without painting).
  AirCensus airCensus() {
    final reserve = <Demon>{if (model.perspective) ...model.drawnReserve};
    final approaching = <Demon>{
      for (final d in model.incoming)
        if (!d.isLarge && d.swarmState != SwarmState.reserve) d,
      ...reserve,
    };
    final bodies = <Demon>[
      for (final d in approaching)
        if (!_parked(d)) d,
      for (final d in model.demons)
        if (!approaching.contains(d) &&
            (d.isLarge
                ? d.entranceProgress > 0
                : d.swarmState != SwarmState.reserve && !_parked(d)))
          d,
    ];
    final flock = [
      for (final m in model.flowFlock)
        if (model.flowOpacity(m) > AirCensus.flockDrawn) m,
    ];
    final shadows = <Demon>[
      if (model.perspective && creatureShadows) ...{
        for (final d in model.incoming)
          if (_casts(d)) d,
        for (final d in model.demons)
          if (_casts(d)) d,
        for (final m in model.flowFlock)
          if (model.flowOpacity(m) > AirCensus.flockShadow) m.demon,
      },
    ];
    final f = model.foreshadow;
    return AirCensus(
      approaching: approaching,
      reserve: reserve,
      bodies: bodies,
      flock: flock,
      shadows: shadows,
      silhouette: f != null && f.visible,
    );
  }

  void _scaleAbout(Canvas c, Offset pos, double scale) {
    if (scale == 1) return;
    c.translate(pos.dx, pos.dy);
    c.scale(scale);
    c.translate(-pos.dx, -pos.dy);
  }

  static const _shadowHMax = 300.0;
  static final _shadowTan = math.tan(32 * math.pi / 180);
  static const _shadowInk = ColorFilter.mode(
    Color(0xFF020309),
    BlendMode.srcIn,
  );

  /// Three blur levels by altitude (research §3: soft when high), shared.
  static final _shadowBlur = [
    ui.ImageFilter.blur(sigmaX: .6, sigmaY: .4),
    ui.ImageFilter.blur(sigmaX: 1.6, sigmaY: 1.0),
    ui.ImageFilter.blur(sigmaX: 3.0, sigmaY: 1.8),
  ];

  // --- continuous swarm: shadows (openspec/changes/continuous-swarm §8) ---
  // Every flying creature casts its silhouette on the ground from its
  // published altitude: arriving, fighting, diving, re-entering. Shadows
  // stay in the front row and move with the swarm; they fade only on death.
  // The ship casts its own on the same sun; a creature's shadow over the
  // ship dims it slightly. Batched: one save-layer per blur bucket (at most
  // three) holding drawAtlas calls; the reduced tier uses one sharp layer.

  /// Save-layers the last shadow pass used (tests: at most three).
  int shadowLayers = 0;

  /// False skips the pass (the perf test's baseline frame).
  bool creatureShadows = true;

  /// Shadows drawn by the last pass, and whose (tests and review).
  int shadowCount = 0;
  final List<Demon> shadowed = [];

  /// Multiply dim of the ship from creature shadows over it (cap 0.15).
  double shipShadowDim = 0;
  static const shipDimCap = .15;

  final Map<Demon, _ShadowSpec> _lastShadows = {};
  final List<(_ShadowSpec, double)> _shadowGhosts = [];
  double _ghostClock = 0;

  /// The sun's azimuth drifts ±4° over 40 s, seeded per sector.
  double get _sunDrift =>
      4 *
      math.pi /
      180 *
      math.sin(2 * math.pi * model.clock / 40 + model.level * 1.7);

  /// How shadows are placed (terrain-shadows design §2): draped on the
  /// relief, or today's flat plane on the reduced atmosphere tier. There is
  /// no separate frame-time governor yet: one that drops the atmosphere to
  /// reduced drops the shadows with it. [shadowModeOverride] forces a mode
  /// (tests, review strips, the perf baseline).
  ShadowMode? shadowModeOverride;
  ShadowMode get shadowMode => atmosphere.quality == AtmosphereQuality.reduced
      ? ShadowMode.flat
      : shadowModeOverride ?? ShadowMode.draped;

  /// Draw calls of the last pass, total and the most in one bucket (tests:
  /// at most four per bucket, one per image).
  int shadowDrawCalls = 0, shadowDrawCallsPerBucket = 0;

  /// The surface shadows fall on this frame.
  ShadowSurface get _shadowSurface => shadowMode == ShadowMode.draped
      ? sectors.flyover.relief
      : const FlatShadowSurface();

  final _shadowShaders = Expando<ImageShader>('shadow shader');
  static final _identity4 = Float64List.fromList(const [
    1,
    0,
    0,
    0,
    0,
    1,
    0,
    0,
    0,
    0,
    1,
    0,
    0,
    0,
    0,
    1,
  ]);

  /// Where the ship's own shadow falls: its legacy point on flat ground,
  /// the sun-ray hit on the relief otherwise.
  ShadowHit _shipShadowHit(ShadowSurface surface) {
    if (shadowMode == ShadowMode.flat) {
      final p = Offset(
        model.shipX + 6 + 40 * _shadowTan * .22,
        ArcadeModel.shipY + 24,
      );
      return ShadowHit(p, p, 0);
    }
    return ShadowProjector.hit(
      surface,
      Offset(model.shipX + 6, ArcadeModel.shipY + 24),
      40,
      ShadowProjector.shipDir,
    );
  }

  _ShadowSpec? _shadowOf(
    Demon d,
    ShadowSurface surface, {
    bool handoff = false,
  }) {
    final n = d.nearness;
    var h = d.altitude;
    if (h <= 0 && d.isLarge && d.entering && d.entranceProgress > 0) {
      // terrain-shadows §4: a sentinel rising out of the fog has no
      // published altitude yet; its shadow eases from the lurking shadow's
      // low pass down to its fight altitude (presentation only).
      h =
          LurkTrack.nearAltitude +
          (SwarmFlock.fightAltitude(d.homeY) - LurkTrack.nearAltitude) *
              Perspective.smoothstep(0, 1, d.entranceProgress);
    }
    if (n <= 0 || h <= 0) return null;
    final gy = Perspective.groundY(n);
    if (gy > 530) return null;
    final az = _sunDrift;
    // The caster's ground hit (flat: the legacy centre, kept verbatim so the
    // reduced tier stays byte-identical).
    final Offset flat, center;
    var lift = 0.0;
    if (shadowMode == ShadowMode.flat) {
      final off = h * _shadowTan * .22;
      flat = center = Offset(
        d.x + off * math.cos(az),
        gy + off * .25 + off * math.sin(az),
      );
    } else {
      final hit = ShadowProjector.hit(
        surface,
        Offset(d.x, gy),
        h,
        ShadowProjector.flyerDir(az),
      );
      flat = hit.flat;
      center = hit.center;
      lift = hit.lift;
    }
    // Softness from the height above the surface it falls on (task 2.4):
    // a creature low over a ridge casts a sharper, darker shadow there.
    final k = lift == 0
        ? (h / _shadowHMax).clamp(0.0, 1.0)
        : ShadowProjector.softness(h, lift);
    // 0.95, not the design's 0.55: on the dark sector grounds 0.55 read as
    // nothing (review frames); 0.95 is the old arrival shadow the operator
    // praised.
    var alpha = .95 * (1 - .4 * k) * Atmosphere.groundLight(center.dy);
    if (d.dive > 0 || d.rushing) alpha *= 1.25;
    if (d.entering && d.swarmState != SwarmState.reentering && !handoff) {
      alpha *= Perspective.smoothstep(0, .12, d.entranceProgress);
    }
    if (alpha < .015 && !handoff) return null;
    final grow = n * 1.8 * (1 + .3 * k);
    final bucket = ShadowProjector.bucketOf(k);
    if (d.isLarge) {
      var at = center, atFlat = flat;
      var size = grow / 1.8 * 1.6;
      if (d.lastStand &&
          (d.rushPhase == RushPhase.lock || d.rushPhase == RushPhase.rush)) {
        // --- sentinel rush: on lock its shadow snaps over the ship's
        // (W3 shadows), at its largest; on the relief, onto the ship's
        // projected hit point.
        final ship = _shipShadowHit(surface);
        final snap = d.rushPhase == RushPhase.rush
            ? 1.0
            : Perspective.smoothstep(0, .12, d.rushClock);
        at = Offset.lerp(center, ship.center, snap)!;
        atFlat = Offset.lerp(flat, ship.flat, snap)!;
        size = math.max(size, 1.6 * 1.25);
      }
      final img = effectsAtlas;
      if (img == null) return null;
      final species = d.archetype == EnemyArchetype.armoredSentinel ? 1 : 0;
      final frame = (model.clock / .4 + d.seed).floor() % 8;
      return _ShadowSpec(
        img,
        Rect.fromLTWH(frame * 128.0, species * 64.0, 128, 64),
        at,
        size,
        alpha.clamp(0.0, .9),
        bucket,
        atFlat,
      );
    }
    final img = atlas;
    if (img == null) return null;
    final cell = CombatAtlas.creature(
      d,
      model.clock,
      motion: creatures.motion.of(d),
    );
    return _ShadowSpec(
      img,
      Rect.fromLTWH(cell.col * 64.0, cell.row * 64.0, 64, 64),
      center,
      40 * grow / 64,
      alpha.clamp(0.0, .9),
      bucket,
      flat,
    );
  }

  // --- terrain-shadows §4: the sentinel's lurking shadow ---

  /// The lurking shadow drawn last (its hand-off source), the sentinel it
  /// hands off to and since when.
  _ShadowSpec? _lurkLast, _handoffFrom;
  Demon? _handoffTo;
  double _handoffAt = 0;
  static const lurkHandoff = .8;

  /// The lurking shadow's visible footprint this frame (ground units and
  /// critters under it hesitate), or null.
  Rect? lurkCover;

  /// The visible centre of [d]'s shadow in the last pass (tests, review).
  Offset? shadowCenterOf(Demon d) => _lastShadows[d]?.center;

  /// The last lurking shadow (tests and review), null when none is drawn.
  Offset? get lurkCenter => _lurkLast?.center;

  /// The flat-ground point and visible centre of a caster over [base] at
  /// [h] on the sun of this frame (flyers' direction).
  ShadowHit _flyerHit(ShadowSurface surface, Offset base, double h) =>
      shadowMode == ShadowMode.flat
      ? (() {
          final p = ShadowProjector.flatCenter(
            base,
            h,
            ShadowProjector.flyerDir(_sunDrift),
          );
          return ShadowHit(p, p, 0);
        })()
      : ShadowProjector.hit(
          surface,
          base,
          h,
          ShadowProjector.flyerDir(_sunDrift),
        );

  _ShadowSpec? _lurkSpec(
    SentinelForeshadow f,
    ui.Image fx,
    ShadowSurface surface,
  ) {
    final l = f.lurk;
    final base = Offset(l.x(meander: !sectors.flyover.reducedMotion), l.flatY);
    final hit = _flyerHit(surface, base, l.altitude);
    // Size by the ground's nearness there: about 2.5 x the sentinel's own,
    // growing 1.0 -> 1.3 as it nears (and its virtual altitude falls).
    final n = ((hit.flat.dy - Perspective.horizonY) / Perspective.groundSpan)
        .clamp(0.0, 1.0);
    final rise = Perspective.smoothstep(0, 1, f.opacity);
    // In thick ground fog it is a darkening, not a shape.
    final clear = 1 - FlyoverBackground.groundFogAt(hit.flat.dy);
    final alpha = .30 * rise * Atmosphere.groundLight(hit.center.dy) * clear;
    if (alpha < .01) return null;
    final species = f.archetype == EnemyArchetype.armoredSentinel ? 1 : 0;
    return _ShadowSpec(
      fx,
      Rect.fromLTWH(
        ((f.clock / .55).floor() % 4) * 128.0,
        species * 64.0,
        128,
        64,
      ),
      hit.center,
      2.5 * 1.6 * n * (1 + .3 * l.progress),
      alpha.clamp(0.0, .3),
      2,
      hit.flat,
    );
  }

  /// Blends the lurking shadow into the rising sentinel's own over
  /// [lurkHandoff] s: position, size and darkness; the in-play shadow is
  /// this blend until then.
  _ShadowSpec? _handOff(_ShadowSpec? to) {
    final from = _handoffFrom;
    final u = (model.clock - _handoffAt) / lurkHandoff;
    if (from == null || to == null || u >= 1) {
      _handoffTo = null;
      _handoffFrom = null;
      return to;
    }
    final k = Perspective.smoothstep(0, 1, u.clamp(0.0, 1.0));
    double mix(double a, double b) => a + (b - a) * k;
    return _ShadowSpec(
      to.image,
      k < .5 ? from.src : to.src,
      Offset.lerp(from.center, to.center, k)!,
      mix(from.scale, to.scale),
      mix(from.alpha, to.alpha),
      k < .5 ? from.bucket : to.bucket,
      Offset.lerp(from.flat, to.flat, k)!,
    );
  }

  // --- terrain-shadows §3: the boss shadow ---

  /// The boss's altitude above the terrain (arena units) for its shadow.
  /// `boss-grandeur` owns it: the shadow shrinks and fades as it climbs.
  double bossShadowAltitude = defaultBossShadowAltitude;
  static const defaultBossShadowAltitude = 160.0;

  /// The boss shadow cell (the hull's alpha, area-downscaled to one pixel
  /// per arena unit, inked), baked once per hull load, and where the
  /// boss's centre sits in it.
  ui.Image? _bossShadowCell;
  Object? _bossShadowFor;
  Offset _bossShadowAnchor = Offset.zero;

  /// The last boss shadow (tests and review): visible centre, size, alpha.
  ({Offset center, double scale, double alpha})? bossShadow;

  ui.Image? _bossShadowImage() {
    final img = armada.image;
    if (!armada.ready || img == null) return null;
    final key = (img, armada.loadedClass);
    if (_bossShadowFor == key) return _bossShadowCell;
    final h = armada.hull;
    final parts = [h.superstructure[0], h.hull[0][0]];
    Rect? bounds;
    for (final p in parts) {
      final r = Rect.fromLTWH(p.dx, p.dy, p.w / 2, p.h / 2);
      bounds = bounds?.expandToInclude(r) ?? r;
    }
    final b = bounds!;
    final rec = ui.PictureRecorder();
    final c = Canvas(rec)..translate(-b.left, -b.top);
    final paint = Paint()
      ..filterQuality = FilterQuality.medium
      ..colorFilter = _shadowInk;
    for (final p in parts) {
      c.drawImageRect(
        img,
        Rect.fromLTWH(
          p.x.toDouble(),
          p.y.toDouble(),
          p.w.toDouble(),
          p.h.toDouble(),
        ),
        Rect.fromLTWH(p.dx, p.dy, p.w / 2, p.h / 2),
        paint,
      );
    }
    final pic = rec.endRecording();
    _bossShadowCell?.dispose();
    _bossShadowCell = pic.toImageSync(b.width.ceil(), b.height.ceil());
    pic.dispose();
    _bossShadowAnchor = -b.topLeft;
    _bossShadowFor = key;
    return _bossShadowCell;
  }

  _ShadowSpec? _bossShadow(ShadowSurface surface) {
    bossShadow = null;
    final b = model.boss;
    if (b == null || model.mode == RunMode.title) return null;
    final cell = _bossShadowImage();
    if (cell == null) return null;
    final h = math.max(1.0, bossShadowAltitude);
    var alpha = .35 * (defaultBossShadowAltitude / h).clamp(0.0, 1.0) * .85;
    if (model.presentationMode == RunMode.transition) {
      // It firms up as the carrier settles out of its descent.
      alpha *= Curves.easeOutCubic.transform(
        model.transitionProgress.clamp(0.0, 1.0),
      );
    }
    if (alpha < .01) return null;
    final scale = .9 * math.sqrt(defaultBossShadowAltitude / h).clamp(.4, 1.2);
    final gy = Perspective.groundY(Perspective.nearnessAtY(b.y));
    // The cell's centre relative to the carrier's centre, on the ground.
    final mid = Offset(cell.width / 2, cell.height / 2) - _bossShadowAnchor;
    final base = Offset(
      b.x + mid.dx * scale,
      gy + mid.dy * scale * ShadowProjector.squash,
    );
    final hit = _flyerHit(surface, base, h);
    bossShadow = (center: hit.center, scale: scale, alpha: alpha);
    return _ShadowSpec(
      cell,
      Rect.fromLTWH(0, 0, cell.width.toDouble(), cell.height.toDouble()),
      hit.center,
      scale,
      alpha.clamp(0.0, .35),
      2,
      hit.flat,
    );
  }

  /// The shadow pass alone (tests: the reduced-tier identity fixture).
  @visibleForTesting
  void paintShadowPass(Canvas c) => _creatureShadows(c);

  void _creatureShadows(Canvas c, {Iterable<Demon> also = const []}) {
    shadowLayers = 0;
    shadowCount = 0;
    lurkCover = null;
    shadowDrawCalls = 0;
    shadowDrawCallsPerBucket = 0;
    shipShadowDim = 0;
    shadowed.clear();
    if (!model.perspective || !creatureShadows) {
      sectors.flyover.terrain.lurkCover = null;
      return;
    }
    final reduced = atmosphere.quality == AtmosphereQuality.reduced;
    final draped = shadowMode == ShadowMode.draped;
    final surface = _shadowSurface;
    final buckets = [<_ShadowSpec>[], <_ShadowSpec>[], <_ShadowSpec>[]];
    final now = <Demon, _ShadowSpec>{};
    final flying = <Demon>{
      ...airCensus().shadows,
      ...also, // --- cinematic flow: the title's attract swarm
    };
    // terrain-shadows §4: the lurking shadow hands off to the sentinel that
    // rises out of the fog (one sentinel shadow at all times).
    final lastLurk = _lurkLast;
    if (lastLurk != null && !(model.foreshadow?.visible ?? false)) {
      final heir = model.demons
          .where(
            (d) =>
                d.isLarge &&
                d.entryScale != null &&
                d.entering &&
                d.entranceProgress > 0,
          )
          .firstOrNull;
      if (heir != null) {
        _handoffTo = heir;
        _handoffFrom = lastLurk;
        _handoffAt = model.clock;
      }
      _lurkLast = null;
    }
    for (final d in flying) {
      if (!_casts(d)) continue;
      final heir = identical(d, _handoffTo);
      var s = _shadowOf(d, surface, handoff: heir);
      if (heir) s = _handOff(s);
      if (s == null) continue;
      now[d] = s;
      shadowed.add(d);
      buckets[reduced ? 0 : s.bucket].add(s);
    }
    // Death: the shadow fades with the creature (0.3 s).
    _ghostClock = model.clock;
    for (final e in _lastShadows.entries) {
      if (!now.containsKey(e.key) && e.key.hp <= 0) {
        _shadowGhosts.add((e.value, _ghostClock));
      }
    }
    _lastShadows
      ..clear()
      ..addAll(now);
    _shadowGhosts.removeWhere((g) => _ghostClock - g.$2 > .3);
    for (final (s, born) in _shadowGhosts) {
      final left = 1 - (_ghostClock - born) / .3;
      buckets[reduced ? 0 : s.bucket].add(s.faded(left));
    }
    // The ship's silhouette, on the same sun at its fixed altitude.
    final shipImg = ship.image;
    final flyover = sectors.flyover;
    flyover.shipShadowByScene = shipImg != null;
    if (shipImg != null && flyover.shipShadowVisible) {
      final hit = _shipShadowHit(surface);
      buckets[reduced ? 0 : 1].add(
        _ShadowSpec(
          shipImg,
          const Rect.fromLTWH(0, 0, ShipPainter.cell, ShipPainter.cell),
          hit.center,
          ShipPainter.size / ShipPainter.cell * 1.05,
          .5,
          1,
          hit.flat,
        ),
      );
    }
    // terrain-shadows §4: a coming sentinel's lurking shadow creeps from the
    // far terrain toward the front while it circles in the fog.
    final f = model.foreshadow;
    final fx = effectsAtlas;
    final lurk = f != null && f.visible && fx != null
        ? _lurkSpec(f, fx, surface)
        : null;
    if (lurk != null) {
      buckets[reduced ? 0 : 2].add(lurk);
      _lurkLast = lurk;
      if (lurk.alpha > .06) {
        lurkCover = Rect.fromCenter(
          center: lurk.center,
          width: lurk.src.width * lurk.scale * .8,
          height: lurk.src.height * lurk.scale * ShadowProjector.squash * .8,
        );
      }
    }
    flyover.terrain.lurkCover = lurkCover;
    // terrain-shadows §3: the boss's large, soft, low shadow.
    final boss = _bossShadow(surface);
    if (boss != null) buckets[reduced ? 0 : 2].add(boss);
    // Shadow over the ship: a multiply dim by overlap, capped.
    final hull = Rect.fromCenter(
      center: Offset(model.shipX, ArcadeModel.shipY),
      width: 36,
      height: 28,
    );
    for (final s in now.values) {
      final w = s.src.width * s.scale, hgt = s.src.height * s.scale * .42;
      final quad = Rect.fromCenter(center: s.center, width: w, height: hgt);
      final o = quad.intersect(hull);
      if (o.width <= 0 || o.height <= 0) continue;
      final share = o.width * o.height / (hull.width * hull.height);
      shipShadowDim += shipDimCap * share * (s.alpha / .55).clamp(0.0, 1.0);
    }
    shipShadowDim = shipShadowDim.clamp(0.0, shipDimCap);
    // Draw: one layer per bucket, the ground seen at a slant.
    for (var b = 0; b < 3; b++) {
      final specs = buckets[b];
      if (specs.isEmpty) continue;
      shadowLayers++;
      shadowCount += specs.length;
      c.saveLayer(
        null,
        Paint()
          ..colorFilter = _shadowInk
          ..imageFilter = reduced ? null : _shadowBlur[b]
          // --- cinematic flow: the campaign outro lifts every shadow.
          ..color = Color.fromRGBO(0, 0, 0, 1 - model.flow.env('lift')),
      );
      final byImage = <ui.Image, List<_ShadowSpec>>{};
      for (final s in specs) {
        (byImage[s.image] ??= []).add(s);
      }
      final calls = draped
          ? _drapedBatches(c, surface, byImage)
          : _flatBatches(c, byImage);
      shadowDrawCalls += calls;
      shadowDrawCallsPerBucket = math.max(shadowDrawCallsPerBucket, calls);
      c.restore();
    }
  }

  /// Today's path (ShadowMode.flat): one drawAtlas per image on a plane
  /// squashed to the slant.
  int _flatBatches(Canvas c, Map<ui.Image, List<_ShadowSpec>> byImage) {
    c.save();
    c.scale(1, .42);
    for (final e in byImage.entries) {
      c.drawAtlas(
        e.key,
        [
          for (final s in e.value)
            RSTransform.fromComponents(
              rotation: 0,
              scale: s.scale,
              anchorX: s.src.width / 2,
              anchorY: s.src.height / 2,
              translateX: s.center.dx,
              translateY: s.center.dy / .42,
            ),
        ],
        [for (final s in e.value) s.src],
        [
          for (final s in e.value)
            Color.fromRGBO(255, 255, 255, s.alpha.clamp(0.0, 1.0)),
        ],
        BlendMode.modulate,
        null,
        Paint()..filterQuality = FilterQuality.none,
      );
    }
    c.restore();
    return byImage.length;
  }

  /// Draped (design §2): every silhouette a 4 x 3 vertex mesh on the
  /// visible surface, one drawVertices per image.
  int _drapedBatches(
    Canvas c,
    ShadowSurface surface,
    Map<ui.Image, List<_ShadowSpec>> byImage,
  ) {
    var calls = 0;
    const nv = ShadowProjector.vertices;
    for (final e in byImage.entries) {
      final specs = e.value;
      final pos = Float32List(specs.length * nv * 2);
      final tex = Float32List(specs.length * nv * 2);
      final col = Int32List(specs.length * nv);
      final idx = Uint16List(specs.length * ShadowProjector.cells * 6);
      var v = 0, n = 0;
      for (final s in specs) {
        n += ShadowProjector.drape(
          surface,
          s.flat,
          s.src.width * s.scale,
          s.src.height * s.scale * ShadowProjector.squash,
          s.src,
          pos,
          tex,
          idx,
          v,
          n,
        );
        final argb = Color.fromRGBO(
          255,
          255,
          255,
          s.alpha.clamp(0.0, 1.0),
        ).toARGB32();
        col.fillRange(v, v + nv, argb);
        v += nv;
      }
      if (n == 0) continue;
      final shader = _shadowShaders[e.key] ??= ImageShader(
        e.key,
        TileMode.clamp,
        TileMode.clamp,
        _identity4,
        filterQuality: FilterQuality.none,
      );
      c.drawVertices(
        ui.Vertices.raw(
          ui.VertexMode.triangles,
          pos,
          textureCoordinates: tex,
          colors: col,
          indices: Uint16List.sublistView(idx, 0, n),
        ),
        BlendMode.modulate,
        Paint()..shader = shader,
      );
      calls++;
    }
    return calls;
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

  /// alien-insignia: the thermal bow is cut into one segment per
  /// dive-shield point (palette unchanged). Returns true when the column at
  /// [dx] is not drawn as plasma: a gap between segments, a burnt-off
  /// segment, or one burning off this instant (a white flash).
  bool _diveSegmentGap(
    Canvas c,
    Demon d,
    double dx,
    double halfSpan,
    double sx,
    double sy,
    Paint paint,
  ) {
    final n = d.diveShieldMax;
    if (n <= 1) return false;
    final width = 2 * halfSpan / n;
    final seg = ((dx + halfSpan) / width).floor().clamp(0, n - 1);
    if (seg > 0 && dx + halfSpan - seg * width < 6) return true;
    if (InsigniaPainter.litCells(n, d.diveShield)[seg]) return false;
    if (creatures.shields.flashAge(d, 'dive', seg) != null) {
      paint.color = const Color(0xFFFFFFFF);
      c.drawRect(Rect.fromLTWH(sx, sy - 4, 3, 6), paint);
    }
    return true;
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
        if (_diveSegmentGap(c, d, dx, halfSpan, sx, sy, paint)) continue;

        // Turbulent ablation envelope (superheated flame orange to deep crimson).
        final tongueHeight =
            ((1 - absNorm * 0.7) * 3.0 +
                    (math.sin(model.clock * 32 + dx * 1.3).abs() * 3.0))
                .roundToDouble();
        paint.color = const Color(0xFFDD2C00)
            .withValues(alpha: (0.55 + 0.35 * ratio) * (1 - absNorm * 0.35));
        c.drawRect(
          Rect.fromLTWH(sx, sy - 4 - tongueHeight, 3, 2 + tongueHeight),
          paint,
        );
        paint.color = const Color(0xFFFF6D00)
            .withValues(alpha: 0.75 + 0.2 * ratio);
        c.drawRect(Rect.fromLTWH(sx, sy - 4 + jitter, 3, 3), paint);

        // Primary compression shock (incandescent solar yellow-gold).
        paint.color =
            (absNorm < 0.55 ? const Color(0xFFFFD54F) : const Color(0xFFFFAB00))
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
        c.drawRect(
          Rect.fromLTWH(wx, (pos.dy + 3 - sparkShift).roundToDouble(), 2, 3),
          paint,
        );
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
        if (_diveSegmentGap(c, d, dx, halfSpan, sx, sy, paint)) continue;

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
    // Banking catches the key light on the leading deck plate's edge and
    // drops the trailing one into shadow (bow armour geometry).
    final lead = bank >= 0 ? 1.0 : -1.0;
    paint.color = const Color(0x40FFE6C0);
    c.drawRect(
      Rect.fromLTWH(
        (center.dx + lead * 54 - 10).roundToDouble(),
        (center.dy - 33).roundToDouble(),
        20,
        2,
      ),
      paint,
    );
    paint.color = const Color(0x55060A16);
    c.drawRect(
      Rect.fromLTWH(
        (center.dx - lead * 54 - 12).roundToDouble(),
        (center.dy - 28).roundToDouble(),
        24,
        6,
      ),
      paint,
    );
  }

  void _carrierSideHatches(Canvas c, Carrier b) {
    final paint = Paint()..isAntiAlias = false;
    if (armada.ready) {
      // Interior glow first, then the authored bay door (mirrored for the
      // right bay); the final form seals both bays with rune-locked plates.
      for (final (dx, openness, flip) in [
        (-Carrier.sideHatchOffset, b.sideDoorLeft, false),
        (Carrier.sideHatchOffset, b.sideDoorRight, true),
      ]) {
        final center = Offset(b.x + dx, b.y + 21);
        c.drawRect(
          Rect.fromCenter(center: center, width: 22, height: 16),
          paint..color = const Color(0xFF070A14),
        );
        if (!b.sideHatchesLocked) {
          c.drawRect(
            Rect.fromCenter(center: center, width: 16, height: 9),
            paint..color = b.shield > 0 ? violet : mint,
          );
        }
        final frame = b.sideHatchesLocked
            ? 3
            : (openness.clamp(0.0, 1.0) * 2).round();
        armada.paintBay(c, b, right: flip, frame: frame);
      }
      return;
    }
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
              ? (demon.rushStagger > 0
                    // Reeling from its broken shield: it tumbles.
                    ? (model.clock * 20).floor() % 8
                    : 4 + (model.clock * 12).floor() % 4)
              : (demon.lastStandTellProgress * 4).floor().clamp(0, 3)
        : diving
        ? 4 + (model.clock * 8).floor() % 4
        : warning
        ? (model.clock * 8).floor() % 4
        : ((model.clock / .4 + demon.seed).floor() % 8);
    // Hover-only presentation: the beak discharge plays over the stroke when
    // this sentinel's bolt leaves, and hits use authored flash frames.
    final hovering = !demon.lastStand && !warning && !diving;
    final fired = creatures.fireAge(demon);
    final firing = hovering && fired != null && fired < .28;
    final flashFrame = hovering && demon.flash > 0;
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
    final t = _transmittance(demon);
    final whiteFlash = demon.flash > 0 && !flashFrame;
    // A foreshadowed sentinel leaves its silhouette behind as it comes out
    // of the fog: the dark shape crossfades into the veiled body.
    final shade = demon.entering && demon.entryScale != null
        ? 1 - Perspective.smoothstep(.05, .4, demon.entranceProgress)
        : 0.0;
    final bodyRow = firing ? 13 : (flashFrame ? 10 + species : row);
    final bodyCol = firing
        ? species * 4 + (fired / .07).floor().clamp(0, 3)
        : frame;
    // --- alien-insignia: a white rim in the tell, cyan while shielded.
    final mark = InsigniaPainter.revealAlpha(t) * (1 - shade);
    final telling = warning && _tellOn;
    final shielded = demon.shield > 0 && demon.shieldMax > 0;
    if (mark > 0 && (telling || shielded) && _rims < InsigniaPainter.maxRims) {
      _rims++;
      final w = InsigniaPainter.unitsPerGlyphPx / demon.scale;
      for (final o in [
        Offset(w, 0),
        Offset(-w, 0),
        Offset(0, w),
        Offset(0, -w),
      ]) {
        effectSprite(
          c,
          bodyRow,
          bodyCol,
          pos + o,
          tint: telling ? const Color(0xFFFFFFFF) : InsigniaPainter.rimCyan,
          opacity: mark * (telling ? 1 : InsigniaPainter.shieldRimAlpha),
        );
      }
    }
    effectSprite(
      c,
      bodyRow,
      bodyCol,
      pos,
      tint: whiteFlash ? Colors.white : null,
      filter: whiteFlash ? null : atmosphere.tintFor(t),
      opacity: 1 - shade,
    );
    if (shade > 0) {
      _silhouetteSprite(c, species, bodyCol.clamp(0, 7), pos, shade);
    }
    final glow = (Perspective.glowAlpha(t) - t) * (1 - shade);
    if (glow > .02 && !whiteFlash) _sentinelEyes(c, pos, glow);
    _creatureLighting(c, pos, bank, width: 92, diving: diving);
    c.restore();
    final reveal = Perspective.gearReveal(t);
    if (mark > 0) {
      // --- alien-insignia: the crown over the head, and one cyan cell per
      // shield point in front of the body (spent points stay as sockets).
      // Overlays are queued in arena units (the canvas here is scaled).
      insignia.rank(
        demon,
        AlienRank.sentinel,
        pos + Offset(0, sentinelHeadTop * demon.scale),
        tone: telling ? InsigniaTone.tell : InsigniaTone.bone,
        alpha: mark,
      );
      final shieldUp =
          demon.shield > 0 || creatures.shields.breaking(demon, 'shield');
      if (demon.shieldMax > 0 &&
          shieldUp &&
          !(diving && demon.diveShield > 0)) {
        _shieldCells(
          demon,
          'shield',
          demon.shield,
          demon.shieldMax,
          pos + Offset(0, 4 * demon.scale),
          demon.scale,
          mark,
        );
      }
    }
    if (reveal <= 0) return;
    if (demon.armor > 0 && demon.armorMax > 0) {
      final layers = (demon.armor / demon.armorMax * 4).ceil();
      for (var layer = 0; layer < layers; layer++) {
        effectSprite(
          c,
          2,
          4 + layer,
          pos,
          tint: demon.flash > 0 ? Colors.white : null,
          opacity: reveal,
        );
      }
    }
    if (diving && demon.diveShield > 0) {
      _sentinelDiveShield(c, pos, demon);
    }
  }

  // --- sentinel rush presentation (demon-intelligence design §6.5) ------

  /// Screen shake of a sentinel rush (arena units, at most 2 px): a
  /// tremor on the lock, a rumble growing with the rush's speed; none with
  /// reduced motion.
  (double, double) rushShake() {
    if (sectors.flyover.reducedMotion) return (0, 0);
    var amp = 0.0;
    for (final d in model.demons) {
      if (!d.lastStand || d.entering) continue;
      if (d.rushPhase == RushPhase.lock) amp = math.max(amp, 1);
      if (d.rushPhase == RushPhase.rush) {
        final v = math.sqrt(d.rushVx * d.rushVx + d.rushVy * d.rushVy);
        final top = model.policy.rushSpeed * model.policy.hostileRate;
        amp = math.max(amp, 2 * (v / top).clamp(0.0, 1.0));
      }
    }
    if (amp <= 0) return (0, 0);
    final t = model.clock;
    return (
      (amp * math.sin(t * 83)).roundToDouble().clamp(-2.0, 2.0),
      (amp * math.cos(t * 67) * .6).roundToDouble().clamp(-2.0, 2.0),
    );
  }

  /// The smoke trail behind a rushing sentinel (unscaled, behind it).
  void _sentinelBerserkTrail(Canvas c, Offset pos, Demon d) {
    if (d.rushPhase != RushPhase.rush) return;
    final v = math.sqrt(d.rushVx * d.rushVx + d.rushVy * d.rushVy);
    if (v < 1) return;
    final ux = -d.rushVx / v, uy = -d.rushVy / v;
    final paint = Paint()..isAntiAlias = false;
    for (var i = 1; i <= 9; i++) {
      final k = i / 9;
      final wobble = math.sin(model.clock * 19 + i * 1.7) * 4 * k;
      final p = pos.translate(
        ux * (22 + i * 13) * d.scale - uy * wobble,
        uy * (22 + i * 13) * d.scale + ux * wobble,
      );
      final r = (4 + 7 * k) * d.scale;
      paint.color = Color.lerp(
        const Color(0xFF8E1020),
        const Color(0xFF120608),
        k,
      )!.withValues(alpha: .62 * (1 - k * .7));
      c.drawRect(
        Rect.fromCenter(
          center: Offset(p.dx.roundToDouble(), p.dy.roundToDouble()),
          width: r * 2,
          height: r * 2,
        ),
        paint,
      );
    }
  }

  /// The berserk aura (drawn scaled with the sentinel): flaring eyes in the
  /// rally and lock, a crimson-to-black thermal bow (≈ 128 px) in the
  /// rush, and the rush-shield ring that shrinks as the shield wears.
  void _sentinelBerserk(Canvas c, Offset pos, Demon d) {
    final paint = Paint()..isAntiAlias = false;
    final phase = d.rushPhase;
    if (phase == RushPhase.rally || phase == RushPhase.lock) {
      final flare = phase == RushPhase.lock
          ? 1.0
          : (d.rushClock / RushTuning.rally).clamp(0.0, 1.0);
      _sentinelEyes(c, pos, .6 + .4 * flare, scale: 1 + .25 * flare);
    }
    if (phase == RushPhase.rush) {
      const halfSpan = 64.0;
      final reel = d.rushStagger > 0 ? .5 : 1.0;
      for (var dx = -halfSpan; dx <= halfSpan; dx += 3) {
        final norm = dx / halfSpan, absNorm = norm.abs();
        final bow = (1 - norm * norm) * 18.0;
        final jitter = math.sin(model.clock * 41 + dx * .8) * 1.5;
        final sx = (pos.dx + dx - 1).roundToDouble();
        final sy = (pos.dy + 18 + bow).roundToDouble();
        final tongue =
            ((1 - absNorm * .6) * 6 +
                    math.sin(model.clock * 31 + dx * 1.3).abs() * 6)
                .roundToDouble();
        paint.color = const Color(0xFF1A0508)
            .withValues(alpha: .7 * (1 - absNorm * .4) * reel);
        c.drawRect(Rect.fromLTWH(sx, sy - 8 - tongue, 3, 3 + tongue), paint);
        paint.color = const Color(0xFF8E1020)
            .withValues(alpha: (.75 + .2 * (1 - absNorm)) * reel);
        c.drawRect(
          Rect.fromLTWH(sx, (sy - 5 + jitter).roundToDouble(), 3, 3),
          paint,
        );
        paint.color =
            (absNorm < .45 ? const Color(0xFFFF3B3B) : const Color(0xFFC2182B))
                .withValues(alpha: .9 * reel);
        c.drawRect(Rect.fromLTWH(sx, sy - 2, 3, 3), paint);
        if (absNorm < .3) {
          paint.color = const Color(0xFFFFC2B0).withValues(alpha: reel);
          c.drawRect(Rect.fromLTWH(sx, sy, 3, 2), paint);
        }
      }
    }
  }

  /// The rush shield (alien-insignia): the force-shield cell arc one row
  /// below the sentinel's own, in ember-tinted cells, one per point, spent
  /// points kept as sockets. Fixed size, so it reads at any depth.
  void _rushShieldRing(Canvas c, Offset pos, Demon d) {
    if (d.rushShieldMax <= 0 || d.entering) return;
    if (d.rushShield <= 0 && !creatures.shields.breaking(d, 'rush')) return;
    final scale = math.max(d.scale, .8);
    _shieldCells(
      d,
      'rush',
      d.rushShield,
      d.rushShieldMax,
      pos + Offset(0, 4 * scale + 11),
      scale,
      InsigniaPainter.revealAlpha(_transmittance(d)),
      litAs: ShieldCell.rush,
    );
  }

  /// Head top of the sentinel sheet's creature (units above the centre at
  /// scale 1): where its crown sits.
  static const double sentinelHeadTop = -17;

  /// Queues a force-shield arc: [max] cells about [centre] (arena units)
  /// for a body at [scale], [lit] of them lit, breaks flashing white and
  /// then shedding shards.
  void _shieldCells(
    Demon d,
    String kind,
    int lit,
    int max,
    Offset centre,
    double scale,
    double alpha, {
    ShieldCell litAs = ShieldCell.lit,
  }) {
    final on = InsigniaPainter.litCells(max, lit);
    final at = InsigniaPainter.arc(max, centre, 34 * scale, 24 * scale);
    for (var i = 0; i < max; i++) {
      insignia.cell(
        at[i],
        creatures.shields.cellState(d, kind, i, on[i], at[i], litAs: litAs),
        alpha: alpha,
      );
    }
  }
  // --- end sentinel rush presentation

  void _sentinelDiveShield(Canvas c, Offset pos, Demon demon) {
    // Tier 3: Massive roaring spacecraft atmospheric re-entry plasma bow shock (~104 px).
    final ratio = (demon.diveShield / math.max(1, demon.diveShieldMax)).clamp(
      0.3,
      1.0,
    );
    final paint = Paint()..isAntiAlias = false;
    const halfSpan = 52.0;
    for (var dx = -halfSpan; dx <= halfSpan; dx += 3) {
      final norm = dx / halfSpan;
      final absNorm = norm.abs();
      final bow = (1 - norm * norm) * 15.0;
      final jitter = math.sin(model.clock * 38 + dx * 0.9) * 1.5;
      final sx = (pos.dx + dx - 1).roundToDouble();
      final sy = (pos.dy + 16 + bow).roundToDouble();
      if (_diveSegmentGap(c, demon, dx, halfSpan, sx, sy, paint)) continue;

      // Jagged trailing flame tongues licking backward along the flanks.
      final tongueHeight =
          ((1 - absNorm * 0.65) * 5.0 +
                  math.sin(model.clock * 34 + dx * 1.1).abs() * 5.0)
              .roundToDouble();
      paint.color = const Color(0xFFDD2C00)
          .withValues(alpha: (0.5 + 0.35 * ratio) * (1 - absNorm * 0.3));
      c.drawRect(
        Rect.fromLTWH(sx, sy - 6 - tongueHeight, 3, 2 + tongueHeight),
        paint,
      );

      // Turbulent ablation envelope (superheated flame orange).
      paint.color = const Color(0xFFFF6D00)
          .withValues(alpha: 0.72 + 0.22 * ratio);
      c.drawRect(
        Rect.fromLTWH(sx, (sy - 5 + jitter).roundToDouble(), 3, 3),
        paint,
      );

      // Primary compression shock (incandescent solar yellow-gold).
      paint.color =
          (absNorm < 0.5 ? const Color(0xFFFFD54F) : const Color(0xFFFFAB00))
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

  void _bossOrbitalArrivalEffects(
    Canvas c,
    Carrier b,
    double p,
    double descent,
  ) {
    if (descent <= 0.01) return;
    final flamePaint = Paint()..isAntiAlias = false;
    final flicker = (model.visualClock * 24).floor() % 4;
    // Bow retro-thrusters brake the warship out of its descent.
    if (armada.ready) {
      armada.paintRetro(c, Offset(b.x, b.y), descent, model.visualClock);
    } else {
      for (final xOff in [-52.0, -24.0, 24.0, 52.0]) {
        final bx = b.x + xOff;
        final by = b.y - 38;
        final plumeLen = (18.0 + descent * 34.0 + flicker * 3.0);
        flamePaint.color = const Color(0xFFFFD54F).withValues(alpha: 0.9);
        c.drawRect(
          Rect.fromLTWH(bx - 3, by - plumeLen * 0.5, 6, plumeLen * 0.5),
          flamePaint,
        );
        flamePaint.color = const Color(0xFFFF6D00).withValues(alpha: 0.75);
        c.drawRect(
          Rect.fromLTWH(bx - 4, by - plumeLen, 8, plumeLen * 0.6),
          flamePaint,
        );
      }
    }
    // Atmospheric / gravitational entry shockwaves.
    final rippleW = 220.0 * (1.0 - descent * 0.5);
    final rippleH = 46.0 * (1.0 - descent * 0.5);
    final ripplePaint = Paint()
      ..color = mint.withValues(alpha: (0.45 * (1.0 - descent)).clamp(0.0, 1.0))
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;
    c.drawOval(
      Rect.fromCenter(
        center: Offset(b.x, b.y + 35),
        width: rippleW,
        height: rippleH,
      ),
      ripplePaint,
    );
  }

  void _carrierTurretBarrels(Canvas c, Carrier b) {
    final aim = math
        .atan2(ArcadeModel.shipY - (b.y + 36), model.shipX - b.x)
        .clamp(0.4, 2.74);
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
        final fy =
            ArcadeModel.shipY +
            math.sin(fa) * fdist * 0.7 +
            (prog * prog * 40.0);
        fragPaint.color = (f.isEven ? mint : const Color(0xFFD6E2EE))
            .withValues(alpha: shockAlpha);
        c.drawRect(
          Rect.fromLTWH(fx, fy, f % 2 == 0 ? 3 : 2, f % 3 == 0 ? 3 : 2),
          fragPaint,
        );
      }
    }

    // 2. Ordinary Small Demons: Synchronized victory swarms, high-five wing claps, & spark bursts
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
        Paint()
          ..color = (i % 3 == 0 ? gold : mint).withValues(
            alpha: 1.0 - sparkPhase,
          ),
      );
    }

    // High-Five wing clashes between paired celebrating creatures
    for (var i = 0; i < smallDemons.length - 1; i += 2) {
      final d1 = smallDemons[i];
      final d2 = smallDemons[i + 1];
      final dx = (d1.x - d2.x).abs();
      final dy = (d1.y - d2.y).abs();
      if (dx < 18.0 && dy < 16.0) {
        final hx = (d1.x + d2.x) * 0.5;
        final hy = (d1.y + d2.y) * 0.5;
        final clapStrength = (1.0 - dx / 18.0).clamp(0.0, 1.0);
        final flashPaint = Paint()..isAntiAlias = false;

        // Central bright high-five sparkle
        flashPaint.color = Colors.white.withValues(alpha: clapStrength);
        c.drawRect(
          Rect.fromCenter(center: Offset(hx, hy), width: 3.5, height: 3.5),
          flashPaint,
        );

        // Radiant arcade spark pips
        flashPaint.color = mint.withValues(alpha: clapStrength * 0.95);
        c.drawRect(Rect.fromLTWH(hx - 5, hy - 1, 2, 2), flashPaint);
        c.drawRect(Rect.fromLTWH(hx + 3, hy - 1, 2, 2), flashPaint);
        flashPaint.color = const Color(0xFFFFD54F)
            .withValues(alpha: clapStrength * 0.95);
        c.drawRect(Rect.fromLTWH(hx - 1, hy - 5, 2, 2), flashPaint);
        c.drawRect(Rect.fromLTWH(hx - 1, hy + 3, 2, 2), flashPaint);

        // Micro-shockwave ring
        c.drawCircle(
          Offset(hx, hy),
          5.0 + (1.0 - clapStrength) * 4.0,
          Paint()
            ..color = mint.withValues(alpha: clapStrength * 0.5)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.0,
        );
      }
    }

    // 3. Big Birds (Sentinels) Apex Hover & Twin Skyward Salute Beams
    for (final d in model.demons) {
      if (d.isLarge) {
        final beamAlpha = (0.5 + 0.4 * math.sin(model.visualClock * 14).abs())
            .clamp(0.0, 1.0);
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

    // 4. Carrier Boss Dominance Pulse, Victory Dance Exhaust Flares & Drone Halo
    final b = model.boss;
    if (b != null) {
      // Alternating retro-thruster burst plumes dancing to the groove
      final danceBeat = math.sin(model.visualClock * 9.2);
      final flarePaint = Paint()..isAntiAlias = false;
      for (final side in [-52.0, -24.0, 24.0, 52.0]) {
        final sideBeat = (side < 0) ? danceBeat : -danceBeat;
        if (sideBeat > 0.15) {
          final plumeLen = 8.0 + sideBeat * 16.0;
          flarePaint.color = const Color(0xFFFFD54F);
          c.drawRect(
            Rect.fromLTWH(b.x + side - 3, b.y + 36, 6, plumeLen * 0.5),
            flarePaint,
          );
          flarePaint.color = const Color(0xFFFF5252);
          c.drawRect(
            Rect.fromLTWH(
              b.x + side - 2,
              b.y + 36 + plumeLen * 0.4,
              4,
              plumeLen * 0.5,
            ),
            flarePaint,
          );
        }
      }

      final pulseRadius = 110.0 + math.sin(model.visualClock * 10) * 14.0;
      c.drawOval(
        Rect.fromCenter(
          center: Offset(b.x, b.y),
          width: pulseRadius * 2,
          height: 110,
        ),
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
    if (armada.ready) {
      // Charred hull of this run's class: chain explosions along engines
      // and tower, bigger hulls snapping in two, debris tumbling free.
      armada.paintWreck(
        c,
        wreck,
        pos,
        p,
        blast: (at, frame, scale) => sprite(
          c,
          CombatAtlas.explosionRow,
          frame,
          at,
          120 * scale,
          opacity: .8,
        ),
      );
      c.save();
      c.translate(pos.dx, pos.dy);
      c.rotate(p * (.22 + .06 * (armada.loadedClass ?? 0)));
      _damage(c, Offset.zero, 1, p * 10);
      c.restore();
      return;
    }
    c.save();
    c.translate(pos.dx, pos.dy);
    c.rotate(p * 0.22);
    sprite(
      c,
      CombatAtlas.fallbackRow,
      4 + wreck.phase.clamp(0, 3),
      Offset.zero,
      184,
      height: 118,
      tint: const Color(0xFF8B665F),
    );
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
    final flow = model.flow;

    if (triumph && model.wreckBoss != null) {
      final wreck = model.wreckBoss!;
      final fallY = (wreck.y + p * p * 360).roundToDouble();
      _bossMeltdownWreckage(
        c,
        wreck,
        Offset(wreck.x.roundToDouble(), fallY),
        p,
      );
    }
    if (clear || triumph) {
      // Fireworks over the rescued sector: on the Rout's last kill for a
      // sector, through the carrier's whole fall.
      final random = math.Random(triumph ? 1982 : 8200 + model.level);
      final count = triumph ? 10 : 5;
      final clock = triumph ? p * 3.2 : p * 1.4 + .2;
      for (var burst = 0; burst < count; burst++) {
        final origin = Offset(
          45 + random.nextDouble() * 270,
          70 + random.nextDouble() * 210,
        );
        final age = clock - burst * .16;
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
    }
    // The last kill's flash (the hit beat): a translucent glow, never a wipe.
    final hit = flow.env('hit');
    if (hit > 0) {
      c.drawRect(
        const Rect.fromLTWH(0, 0, 360, 520),
        Paint()..color = (triumph ? gold : mint).withValues(alpha: hit * .18),
      );
    }
  }

  /// The ship during a transition (drawn over the cloud cover): it climbs
  /// nose-up into the cloud on the climb beat and drops back to its row in
  /// the Descent; at the run's opening it rises in from below.
  void _cinematicFlowShip(Canvas c) {
    final mode = model.presentationMode;
    final intro = mode == RunMode.transition;
    if (!intro &&
        mode != RunMode.levelClear &&
        mode != RunMode.travel &&
        mode != RunMode.victory) {
      return;
    }
    final flow = model.flow;
    final p = model.transitionProgress.clamp(0.0, 1.0);
    if (intro && !flow.active) {
      final wave = model.wave > 1;
      final arrival = Curves.easeOutCubic.transform((p / .8).clamp(0.0, 1.0));
      final y = wave
          ? ArcadeModel.shipY
          : ArcadeModel.shipY + (1 - arrival) * 130;
      _cinematicShip(c, Offset(model.shipX, y), 42, 1 + (1 - arrival) * 2);
      return;
    }
    final climb = flow.env('climb');
    final cloud = flow.env('cloud');
    final speed = flow.env('speed');
    // In the cloud the ship is a little veiled, never lost.
    final veil = (1 - .35 * cloud).clamp(0.0, 1.0);
    c.saveLayer(
      const Rect.fromLTWH(0, 0, 360, 520),
      Paint()..color = Color.fromRGBO(0, 0, 0, veil),
    );
    // transition ascent (design §2): the plume grows with the speed and the
    // hull pulls away (a 4 % scale-down, none in reduced motion).
    final nudge = model.reducedMotion ? 0.0 : shipNudge * speed;
    _cinematicShip(
      c,
      flowShipAt(),
      42 * (1 - nudge),
      1 + climb * 2.5 + speed * 1.5,
    );
    c.restore();
  }

  /// Where the transition ship is drawn: its row, raised by the climb beat
  /// (at most [FlowPlan.climb] units: 24 in a sector change).
  Offset flowShipAt() => Offset(
    model.shipX,
    ArcadeModel.shipY - model.flow.plan.climb * model.flow.env('climb'),
  );

  /// The camera pitch's ground transform at pitch [q] (design §2): a row
  /// at y moves to horizon + drop + (y - horizon)(1 + [pitchStretch]·q).
  void _groundPitch(Canvas c, double q) {
    const h = Perspective.horizonY;
    c
      ..translate(0, h + pitchDrop * q)
      ..scale(1, 1 + pitchStretch * q)
      ..translate(0, -h);
  }

  /// Where a ground row at [y] is drawn at pitch [q] (tests, review).
  static double pitchedRow(double y, double q) {
    const h = Perspective.horizonY;
    return y < h
        ? y + pitchDrop * q
        : h + pitchDrop * q + (y - h) * (1 + pitchStretch * q);
  }

  /// The world's bank at roll envelope [roll] toward [dir] (radians).
  static double worldRoll(double roll, int dir) =>
      roll * FlowPlan.maxRollDegrees * math.pi / 180 * dir.sign;

  /// Fog streaks rushing down past both sides of the ship (design §3):
  /// 12 thin cloud-tinted strokes seeded from the run and the sector, at a
  /// speed proportional to the world's. None in reduced motion (the beat's
  /// gain is 0).
  void _fogStreaks(Canvas c) {
    final k = model.flow.env('streaks');
    if (k <= .01 || model.reducedMotion) return;
    final ship = flowShipAt();
    final seed = model.seed * 31 + model.level * 7 + model.cycle;
    final colour = Color.lerp(atmosphere.cloud, Atmosphere.cloudLight, .7)!;
    for (var i = 0; i < streakCount; i++) {
      double r(int salt) {
        final v = math.sin((seed + i * 17 + salt * 131) * 12.9898) * 43758.5;
        return v - v.floorToDouble();
      }

      final side = i.isEven ? -1 : 1;
      final x = ship.dx + side * (26 + r(1) * 110);
      final length = 18 + r(2) * 22;
      final span = 520 + length;
      final y = (r(3) * span + streakRun * (.8 + .4 * r(4))) % span - length;
      final a = k * streakAlpha * (.5 + .5 * r(5));
      c.drawRect(
        Rect.fromLTWH(x.roundToDouble(), y.roundToDouble(), 2, length),
        Paint()..color = colour.withValues(alpha: a),
      );
    }
  }

  /// Camera tilt in the campaign outro (still zero gain): the world below
  /// slides down this far.
  static const flowTilt = 46.0;

  /// transition ascent (design §2): the horizon drops this far at full
  /// pitch, and the ground below it stretches by this much.
  static const pitchDrop = 96.0, pitchStretch = .35;

  /// The banked world's overscan at full roll: a 3° bank about the arena
  /// centre needs 260·sin 3° / 180 ≈ 7.6 % to keep the corners covered.
  static const rollOverscan = .09;

  /// The hull's pull-away at full speed (a scale-down).
  static const shipNudge = .04;

  /// Fog streaks: how many, their peak alpha and their speed per unit of
  /// world speed (arena units a second).
  static const streakCount = 12, streakAlpha = .35, streakSpeed = 150.0;

  /// The streaks' and the cloud billows' scroll, integrated from the
  /// world's speed (reset when no flow is playing).
  double streakRun = 0, cloudRun = 0;

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
    if (ship.ready) {
      // The same layered ship as [_playerShip]: hull, every equipped module
      // and the shield bubble. Width 42 is the in-play size, so the handoff
      // between cutscene and combat keeps the ship's scale.
      final at = Offset(center.dx.roundToDouble(), center.dy.roundToDouble());
      c.save();
      c.translate(at.dx, at.dy);
      c.scale(width / 42);
      c.translate(-at.dx, -at.dy);
      ship.paintShip(c, model, at, live: false);
      ship.paintShield(c, model, at);
      c.restore();
      return;
    }
    sprite(c, CombatAtlas.fallbackRow, frame, center, width);
  }

  // =========================================================================
  // --- life-loss sequence: ship explosion, debris, shot fizzles, regroup.
  // Presentation only; state in lib/game/life_loss.dart.
  // =========================================================================

  static const _fireRamp = [
    Color(0xFFFFFFFF),
    Color(0xFFFFF5C9),
    Color(0xFFFFD594),
    Color(0xFFFFA85A),
    Color(0xFFFF6A3D),
    Color(0xFFC23B3B),
    Color(0xFF5E2335),
  ];
  static const _smokeRamp = [
    Color(0xFF7A7290),
    Color(0xFF574F6E),
    Color(0xFF3A3450),
  ];
  static const _hullTones = [
    Color(0xFFD7E5EF),
    Color(0xFF8FA3B8),
    Color(0xFF4E6074),
    Color(0xFF2A2230),
  ];

  /// Pixel block on the 2-unit explosion grid.
  void _lp(Canvas c, double x, double y, double s, Color color) {
    c.drawRect(
      Rect.fromLTWH(x.roundToDouble(), y.roundToDouble(), s, s),
      Paint()
        ..color = color
        ..isAntiAlias = false,
    );
  }

  /// Deterministic hash noise in [0, 1).
  static double _ln(int a, int b, int c) {
    var h = a * 374761393 + b * 668265263 + c * 2147483647;
    h = (h ^ (h >> 13)) * 1274126177;
    return ((h ^ (h >> 16)) & 0xFFFF) / 65536.0;
  }

  void _lifeLossEffects(Canvas c) {
    final m = model;
    // Hostile shots fizzling out during the regroup: a pop of sparks.
    for (final f in m.shotFizzles) {
      final p = (f.age / ShotFizzle.life).clamp(0.0, 1.0);
      final frame = (p * 4).floor();
      final core = f.sentinel ? violet : const Color(0xFFFF8676);
      if (frame == 0) {
        _lp(c, f.x - 2, f.y - 2, 4, Colors.white);
      }
      final r = 2 + p * 7;
      for (var k = 0; k < 6; k++) {
        final a = k * math.pi / 3 + f.x * .1;
        _lp(
          c,
          f.x + math.cos(a) * r - 1,
          f.y + math.sin(a) * r - 1,
          frame < 2 ? 2 : 1,
          (k.isEven ? core : const Color(0xFFFFE3AF)).withValues(alpha: 1 - p),
        );
      }
      if (frame >= 2) {
        _lp(
          c,
          f.x - 1,
          f.y - 2 - p * 6,
          2,
          _smokeRamp[0].withValues(alpha: .7 * (1 - p)),
        );
      }
    }
    if (m.lifeLossPhase == LifeLossPhase.none && m.shipDebris.isEmpty) return;
    final t = m.lifeLossElapsed;
    final cx = m.lifeLossX, cy = ArcadeModel.shipY;
    if (m.lifeLossPhase != LifeLossPhase.none && t < 1.5) {
      // 12 fps pixel animation: flash, fireball with noise holes, shock
      // ring, then a rising smoke column with embers.
      final f = (t * 12).floor();
      final ft = f / 12;
      if (ft < .17) {
        final r = 8 + ft * 90;
        for (var y = -r; y <= r; y += 2) {
          for (var x = -r; x <= r; x += 2) {
            if (x * x + y * y > r * r) continue;
            _lp(c, cx + x, cy + y, 2, ft < .09 ? Colors.white : _fireRamp[1]);
          }
        }
      }
      if (ft >= .05 && ft < .9) {
        final u = ((ft - .05) / .85).clamp(0.0, 1.0);
        final r = 12 + 16 * math.sqrt(u);
        for (var y = -r; y <= r; y += 2) {
          for (var x = -r; x <= r; x += 2) {
            final d = math.sqrt(x * x + y * y) / r;
            if (d > 1) continue;
            final n = _ln(x.round(), y.round(), f ~/ 2);
            // Holes eat the fireball from the rim inward as it cools.
            if (n < u * 1.1 - (1 - d) * .55) continue;
            final heat = (d * .55 + u * .75 + n * .25).clamp(0.0, .999);
            final col = _fireRamp[1 + (heat * 6).floor().clamp(0, 5)];
            _lp(c, cx + x, cy + y - u * 10, 2, col);
          }
        }
      }
      if (ft >= .08 && ft < .6) {
        final u = (ft - .08) / .52;
        final r = 16 + u * 52;
        final n = (r * 1.4).round();
        for (var k = 0; k < n; k++) {
          if (_ln(k, f, 7) < u * .7) continue;
          final a = k / n * math.pi * 2;
          _lp(
            c,
            cx + math.cos(a) * r - 1,
            cy + math.sin(a) * r * .55 - 1,
            2,
            (u < .4 ? _fireRamp[2] : _fireRamp[4]).withValues(alpha: 1 - u),
          );
        }
      }
      if (ft >= .4) {
        final u = ((ft - .4) / 1.1).clamp(0.0, 1.0);
        for (var k = 0; k < 7; k++) {
          final ox = (_ln(k, 3, 1) - .5) * 26 + math.sin(t * 2 + k) * 3;
          final oy = -8 - u * (40 + k * 6) - _ln(k, 5, 2) * 8;
          final rr = 4 + u * 7 + k % 3;
          final col = _smokeRamp[k % 3].withValues(alpha: .75 * (1 - u));
          for (var y = -rr; y <= rr; y += 2) {
            for (var x = -rr; x <= rr; x += 2) {
              if (x * x + y * y > rr * rr) continue;
              _lp(c, cx + ox + x, cy + oy + y, 2, col);
            }
          }
        }
      }
      // Embers drifting up out of the blast.
      for (var k = 0; k < 14; k++) {
        final life = (t * 1.6 + _ln(k, 9, 4)) % 1;
        if (t > 1.2 && life > .6) continue;
        final ex = cx + (_ln(k, 1, 8) - .5) * 50 + math.sin(t * 5 + k) * 4;
        final ey = cy + 6 - life * 70;
        _lp(
          c,
          ex,
          ey,
          1,
          _fireRamp[2 + (life * 4).floor()].withValues(alpha: 1 - life),
        );
      }
    }
    // Hull shards and the fitted modules tumbling away.
    for (final d in m.shipDebris) {
      final fade = (1 - d.age / ShipDebris.life).clamp(0.0, 1.0);
      if (d.power != null &&
          ship.ready &&
          ShipPainter.rows.containsKey(d.power)) {
        c.save();
        c.translate(d.x, d.y);
        c.rotate(d.rotation);
        ship.paintPart(c, FallingPart(0, 0, d.power!, vx: d.vx));
        c.restore();
      } else {
        c.save();
        c.translate(d.x.roundToDouble(), d.y.roundToDouble());
        c.rotate((d.rotation / (math.pi / 4)).round() * (math.pi / 4));
        final s = d.size;
        c.drawRect(
          Rect.fromLTWH(-s / 2, -s / 2, s, s),
          Paint()
            ..isAntiAlias = false
            ..color = _hullTones[d.tone].withValues(alpha: fade),
        );
        c.drawRect(
          Rect.fromLTWH(-s / 2, -s / 2, math.max(1, s / 2), 1),
          Paint()
            ..isAntiAlias = false
            ..color = _fireRamp[3].withValues(alpha: fade),
        );
        c.restore();
      }
      // A short burning trail behind each piece.
      final speed = math.max(1.0, math.sqrt(d.vx * d.vx + d.vy * d.vy));
      for (var k = 1; k <= 3; k++) {
        _lp(
          c,
          d.x - d.vx / speed * k * 3,
          d.y - d.vy / speed * k * 3,
          1,
          _fireRamp[2 + k].withValues(alpha: fade * (1 - k * .25)),
        );
      }
    }
    // Fly-in exhaust: a tall mint thruster plume below the rising ship.
    if (m.lifeLossPhase == LifeLossPhase.emerging) {
      final y = m.shipDrawY;
      final u = m.emergeProgress;
      for (var k = 0; k < 10; k++) {
        _lp(
          c,
          m.shipX - 2 + ((k * 7 + (m.clock * 30).floor()) % 3) - 1,
          y + 18 + k * 4,
          k < 3 ? 4 : 2,
          (k < 2 ? const Color(0xFFFFEDBF) : mint).withValues(
            alpha: (1 - k / 10) * (1 - u * .6),
          ),
        );
      }
    }
  }
}

/// One ground shadow of the batched pass (continuous swarm).
class _ShadowSpec {
  const _ShadowSpec(
    this.image,
    this.src,
    this.center,
    this.scale,
    this.alpha,
    this.bucket,
    this.flat,
  );
  final ui.Image image;
  final Rect src;

  /// Visible centre (on the surface) and the flat-ground point the drape is
  /// built around (terrain-shadows; equal on flat ground).
  final Offset center, flat;
  final double scale, alpha;
  final int bucket;

  _ShadowSpec faded(double k) => _ShadowSpec(
    image,
    src,
    center,
    scale,
    alpha * k.clamp(0.0, 1.0),
    bucket,
    flat,
  );
}

/// One frame's census of the air (DemonScene.airCensus): every creature body,
/// fog-veiled arrival, transition-flock member and shadow caster the passes
/// draw, and whether the sentinel's foreshadow silhouette is up.
class AirCensus {
  AirCensus({
    required this.approaching,
    required this.reserve,
    required this.bodies,
    required this.flock,
    required this.shadows,
    required this.silhouette,
  });

  /// A flock member is drawn above this opacity, casts a shadow above
  /// [flockShadow].
  static const flockDrawn = .01, flockShadow = .3;

  /// The veiled cohort and drawn reserve (in the fog, no gear).
  final Set<Demon> approaching;

  /// The drawn reserve alone (a subset of [approaching]).
  final Set<Demon> reserve;

  /// Every creature the depth sort draws (approaching included).
  final List<Demon> bodies;
  final List<FlowMember> flock;
  final List<Demon> shadows;
  final bool silhouette;

  /// Nothing alive is drawn in the air, in the fog or on the ground below.
  bool get empty =>
      bodies.isEmpty && flock.isEmpty && shadows.isEmpty && !silhouette;

  @override
  String toString() =>
      'bodies ${bodies.length} (veiled ${approaching.length}), '
      'flock ${flock.length}, shadows ${shadows.length}, '
      'silhouette $silhouette';
}
