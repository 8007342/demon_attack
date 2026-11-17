import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;

import 'arena_camera.dart';
import 'atmosphere.dart';
import 'weather/rain_layer.dart';
import 'weather/wind_layer.dart'; // --- crosswind
import 'attract.dart';
import 'boss_director.dart';
import 'ground_atmosphere.dart';
import 'ground_atmosphere_atlas.dart';
import 'bonus/bonus_look.dart'; // --- bonus levels
import 'bonus/bonus_painters.dart'; // --- bonus levels: mechanics
import 'bonus/levels/crosswind_painter.dart'; // --- crosswind
import 'bonus/levels/wind_kites_atlas.dart'; // --- crosswind
import 'boss_painter.dart';
import 'carrier_breakup_painter.dart';
import 'carrier_hatch_painter.dart';
import 'carrier_presentation.dart';
import 'carrier_script.dart' show CarrierApproachScript;
import 'dive_shield.dart'; // --- dive-shield-thinning
import 'ground_painter.dart';
import 'insignia_atlas.dart';
import 'insignia_painter.dart';
import 'model.dart';
import 'perf/frame_budget.dart'; // --- phone-performance
import 'hatch_emergence.dart'; // --- hatch-emergence
import 'carrier_gates.dart' show CarrierGate;
import 'hatch_emergence_painter.dart';
import 'shot_layer.dart'; // --- phone-performance
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

  /// --- mission-medals: true while the urgent-mission card holds a bonus
  /// level's start; the model is not stepped (presentation runs on).
  bool Function() holdModel = _never;
  static bool _never() => false;
  ui.Image? atlas, effectsAtlas, sky, cockpitAtlas;

  /// The foreshadow silhouette sheet (tools/sentinel_silhouettes); the
  /// placeholder from the flight frames is drawn while it is missing.
  ui.Image? silhouetteAtlas;
  final ship = ShipPainter();
  // Boss armada: one hull class per run, its atlas loaded on approach.
  final armada = BossPainter();

  /// boss-grandeur: the boss level's phases, altitude, camera and views.
  late final bossDirector = BossDirector(seed: model.seed);

  /// carrier-v3: the field, the gates and the speed cues.
  final carrierV3 = CarrierPresentation();
  final hatchPainter = CarrierHatchPainter(); // --- carrier-hatches
  // --- hatch-emergence: the launched creatures' one-shot emergence.
  final emergence = HatchEmergence();
  final emergencePainter = HatchEmergencePainter();
  final breakup = CarrierBreakupPainter(); // --- carrier-hatches Part B

  /// The gameplay layer is drawn under the arena camera's zoom this frame.
  bool _zoomApplied = false;

  /// boss-carrier-wire: the creature draw-size floor under the zoom (1
  /// unless the carrier band takes the far-row creature under 34 CSS px).
  double get _creatureFloor => _zoomApplied
      ? bossDirector.camera.floorScale(
          44 * Perspective.scaleOf(Perspective.nearTop),
          ArenaCamera.creatureFloor,
        )
      : 1.0;
  final sectors = SectorBackground();
  final creatures = CreaturePresentation();
  // --- alien-insignia: rank glyphs and shield cells over the arena.
  final insignia = InsigniaPainter();
  // --- atmosphere: fog layers and creature veils (atmosphere.dart).
  final atmosphere = Atmosphere();
  // --- dynamic-weather: a regular level's rain (lib/game/weather/).
  final rain = RainLayer();

  // --- crosswind: the wind's clouds, wisps and windsock.
  final wind = WindLayer();
  final music = MusicDirector(); // --- music event hook (read-only)
  // --- phone-performance: the quality tier (from measured frame
  // intervals) and the batched, interpolated shot layer.
  final perf = PerfGovernor(
    forced: PerfTier.parse(Uri.base.queryParameters['perf']),
  );
  FrameBudget get budget => perf.budget;
  final shots = ShotLayer();

  /// The fog-bank boss shadow's cell and its pre-blurred copy (§4.4).
  ui.Image? _fogShadowSource, _fogShadowSoft;

  /// The frame-cost harness's layer marker (one type test in the game).
  String _layerNow = 'frame';
  void _mark(Canvas c, String layer) {
    if (c case final LayerSink sink) {
      _layerNow = layer;
      sink.layer(layer);
    }
  }

  // --- ground war (ground_painter.dart) ---
  late final groundForces = GroundPainter()
    ..occluders = (sectors.flyover..deferFlyers = true)
    ..atmosphere =
        atmosphere // --- ground atmosphere art in the depth sort
    ..eggs = sectors.flyover.eggs;
  List<ScoreEntry> topScores = const [];
  double ambient = 0, _notify = 0;
  double environment = 0;

  /// --- bonus levels: the grade over a bonus level's backdrop.
  final bonusLook = BonusLookLayer();
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
      sky = await images.load('cosmic-sky.webp');
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
      // --- crosswind: the kites (tools/wind_kites).
      CrosswindPainter.image = await images.load(WindKitesAtlas.file);
    } catch (_) {}
    try {
      // --- hatch-emergence (tools/rigkit, plan/render-runs/hatch-emergence.md)
      emergencePainter.image = await images.load('hatch-emergence.png');
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
          sectors.images[i] = await images.load('sector-${i + 1}.webp');
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
    // --- phone-performance: the tier from frame intervals.
    perf.frame(dt, moving: model.mode == RunMode.playing);
    applyBudget();
    if (model.mode != RunMode.paused) advancePresentation(dt);
    final held = holdModel(); // --- mission-medals
    if (!held && model.canPilot && keyboardDirection != 0) {
      model.moveBy(keyboardDirection * dt * 280);
    }
    // --- cinematic flow: the accessibility setting picks the plan.
    model.reducedMotion = sectors.flyover.reducedMotion;
    // --- phone-performance §5.1: a jittered vsync interval steps the
    // fixed-step model exactly once (snapFrameDelta), not 0 then 2.
    if (!held) model.update(snapFrameDelta(dt));
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

  /// --- phone-performance §3-§4: hands the tier's budget to the painters.
  void applyBudget() {
    final b = budget;
    atmosphere.tierReduced = b.fogReduced;
    rain.budget = b.rainScale;
    wind.budget = b.windScale; // --- crosswind
    sectors.moteScale = b.moteScale;
    // --- hatch-emergence §5: LITE skips the emergence and the vents.
    emergence
      ..enabled = b.emergence
      ..lurkers = b.lurkers;
    hatchPainter.rich = b.hatchVents;
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
    bonusLook.advance(model, dt); // --- bonus levels
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
        // --- phone-performance §4.3: land on the sector. The exponential
        // approach never reaches the integer, and a hair short of it the
        // backdrop draws both worlds (the far one at 99.9 %) every frame.
        if ((destination - environment).abs() < 1e-3) {
          environment = destination.toDouble();
        }
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
      advanceBoss(dt);
      syncAtmosphere(dt);
      // --- dynamic-weather: visual only; reads the run seed and the level.
      rain.advance(dt, model, reduced: sectors.flyover.reducedMotion);
      // --- crosswind: the wind's look; a shower slants with it.
      wind.advance(dt, model, reduced: sectors.flyover.reducedMotion);
      if (wind.amount > .02) {
        rain.wind += (wind.lateral * .3 - rain.wind) * wind.amount;
      }
    }
  }

  /// boss-grandeur: the director's step and what it drives elsewhere: the
  /// boss shadow's altitude (terrain-shadows hook) and the ground sprites'
  /// altitude (they keep their size as the ground stretches below).
  void advanceBoss(double dt) {
    final b = model.boss;
    if (b != null && armada.heroReady) armada.assemble(b, model.cycle);
    armada.beginFrame(); // carrier-v3: the mesh counters, per frame
    bossDirector.update(
      model,
      dt,
      reduced: sectors.flyover.reducedMotion,
      modules: armada.modules,
      carrier: armada.carrier,
    );
    bossShadowAltitude = defaultBossShadowAltitude * bossDirector.altitude;
    GroundCamera.spriteAltitude = bossDirector.camera.altitude;
    // carrier-v3 §2: the carrier is drawn bent (rigid under reduced motion);
    // its field's distance map is derived once per hull at load.
    final reduced = sectors.flyover.reducedMotion;
    armada.bend = armada.carrier && !reduced ? bossDirector.bend : null;
    if (armada.carrier && model.level >= 4) carrierV3.ensureField(armada);
    carrierV3.update(dt, model, bossDirector, reduced: reduced);
    hatchPainter.update(model.boss, model.visualClock, reduced: reduced);
    emergence.update(model); // --- hatch-emergence
    // --- carrier-hatches Part B: the hull's components, cut at install.
    if (armada.carrier && model.level >= 4) breakup.prepare(armada);
    breakup.update(model, bossDirector, reduced: reduced);
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
      // boss-grandeur (R8): the fight plays higher and faster: the fog
      // flows faster past it (the ground below slows by the altitude).
      // carrier-v3 §7: and each layer at its own rate, the near faster.
      ..flowBoost = bossDirector.flowBoost
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
    final spare = (dimensions.y - ArcadeModel.height * scale) * alignY;
    canvas.translate((dimensions.x - ArcadeModel.width * scale) / 2, spare);
    canvas.scale(scale);
    // --- playtest-fixes-3: the spare height above the arena (the toast
    // band on a tall phone) is background, always: sky, parallax, fog and
    // cloud reach the viewport's top. Gameplay stays clipped to the arena.
    headroom = scale > 0 ? math.max(0.0, spare / scale) : 0.0;
    atmosphere.headroom = headroom;
    _mark(canvas, 'background'); // --- phone-performance: harness layers
    canvas.clipRect(Rect.fromLTWH(0, -headroom, 360, 520 + headroom));
    final (shakeX, shakeY) = rushShake(); // --- sentinel rush (≤ 2 px)
    if (shakeX != 0 || shakeY != 0) canvas.translate(shakeX, shakeY);
    final panY = model.mode == RunMode.gameOver ? model.cameraPanY : 0.0;
    if (panY > 0.5) {
      _deepStarfieldPan(canvas, panY);
      canvas.save();
      canvas.translate(0, panY);
      _background(canvas);
      rain.paint(canvas, haze: atmosphere.cloud); // --- dynamic-weather
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
      // carrier-v3 §7: the carrier's trauma shake joins the flow's (four
      // beats only). Its take-off pitch goes through the arena camera's
      // background transform (no uncovered band over the hull).
      final q = model.flow.env('pitch');
      final drop = pitchDrop * q;
      final band = tilt + drop;
      final roll = model.flow.env('roll');
      final shake = _flowShake() + bossDirector.shake;
      // playtest-fixes-3: the band the pitch uncovers is the deep sky above
      // the painted one in clear air, and cloud once the cloud is in (the
      // pitch now starts with the climb, before the cloud).
      final bandSky = Color.lerp(
        const Color(0xFF070B16),
        atmosphere.cloud,
        model.flow.env('cloud').clamp(0.0, 1.0),
      )!;
      if (roll > .001) {
        // Under a banked world the corners show the cloud, never black.
        canvas.drawRect(
          Rect.fromLTWH(0, -headroom, 360, 520 + headroom),
          Paint()..color = atmosphere.cloud,
        );
      } else if (band > .01) {
        canvas.drawRect(
          Rect.fromLTRB(0, -headroom, 360, band + 2 - headroom),
          Paint()..color = bandSky,
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
      // --- boss-grandeur: the background (sky, terrain, ground units) is
      // drawn through the camera's altitude and follow; the gameplay layer
      // through its zoom only (design §2–§4).
      final cam = bossDirector.camera;
      final bgCam = active && combat && !cam.identity;
      if (bgCam) {
        canvas.save();
        canvas.transform(cam.backgroundMatrix);
      }
      if (q > .001) {
        // The sky translates with the horizon; the ground plane turns
        // about it (near rows leave the bottom first).
        final h = Perspective.horizonY + drop;
        canvas.save();
        // Overlaps the ground pass by 2 units: no hairline at the seam.
        canvas.clipRect(Rect.fromLTRB(-40, -40 - headroom, 400, h + 2));
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
      _mark(canvas, 'rain');
      bonusLook.paint(canvas); // --- bonus levels: the level's grade
      // --- dynamic-weather: rain over the backdrop (and the band above the
      // arena), under the ground units, the fog, the creatures and shots.
      rain.paint(
        canvas,
        headroom: headroom,
        haze: atmosphere.cloud,
        perspective: model.perspective,
      );
      wind.paintSky(
        canvas,
        headroom: headroom,
        cloud: atmosphere.cloud,
        blur: budget.blur,
      ); // --- crosswind
      if (active && combat) {
        // --- bonus levels: a level's mechanic, under the fight.
        BonusPainters.under(canvas, model, model.visualClock);
        _mark(canvas, 'ground');
        groundForces.paintGround(
          canvas,
          model,
        ); // --- ground war: on the ground
      }
      if (bgCam) canvas.restore();
      if (active && combat) {
        // Gameplay never draws in the band above the arena.
        canvas.save();
        canvas.clipRect(
          const Rect.fromLTWH(0, 0, 360, 520),
          doAntiAlias: false,
        );
        _zoomApplied = cam.zoom != 1;
        if (_zoomApplied) {
          canvas.save();
          canvas.transform(cam.gameplayMatrix);
        }
        _combat(canvas);
        _mark(canvas, 'air');
        groundForces.paintAir(
          canvas,
          model,
          ship,
        ); // --- ground war: in the air
        _mark(canvas, 'overlay');
        // --- bonus levels: a level's mechanic, over the fight.
        BonusPainters.over(canvas, model, model.visualClock);
        wind.paintSock(canvas); // --- crosswind: the windsock
        _bossOverflight(canvas); // --- boss-grandeur: over the ship
        _cinematic(canvas);
        if (_zoomApplied) {
          canvas.restore();
          _arenaEdge(canvas, cam);
        }
        _zoomApplied = false;
        canvas.restore();
        _carrierHeadroom(canvas, cam);
        // The high fog over the band (the layers that reach the arena's
        // top carry on to the viewport's).
        if (model.perspective) atmosphere.paintBand(canvas);
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
            Rect.fromLTRB(0, -headroom, 360, band + 36 - headroom),
            Paint()
              ..shader = ui.Gradient.linear(
                Offset(0, -headroom),
                Offset(0, band + 36 - headroom),
                [bandSky, bandSky.withValues(alpha: 0)],
                [band / (band + 36), 1],
              ),
          );
        }
        _mark(canvas, 'flow');
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
      Rect.fromLTWH(0, -headroom, 360, 520 + headroom),
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
    headroom: headroom,
  );

  /// playtest-fixes-3: arena units of viewport above the arena this frame
  /// (the band a bottom-aligned arena leaves on a tall phone). Background
  /// only: no spawn, target, shot or HUD element is ever placed there.
  double headroom = 0;

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
    _mark(c, 'creatures'); // --- phone-performance: harness layers
    insignia.begin(); // --- alien-insignia: this frame's marks
    _rims = 0;
    // --- atmosphere: ground fog lies on the terrain, over the shadows.
    if (model.perspective) _fogSlot(c, FogSlot.groundFog);
    // --- easter eggs: flock flyers over the ground fog (in the air).
    sectors.flyover.paintFlyers(c);
    _mark(c, 'shadows');
    _creatureShadows(c); // --- continuous swarm: every flyer, the ship
    _bossOverflightShadow(c); // --- boss-grandeur: it sweeps the ground first
    _mark(c, 'creatures');
    for (final p in model.heartPickups) {
      c.save();
      c.translate(p.x - 10, p.y - 10);
      HeartPartPainter(p.part.mask).paint(c, const Size(20, 20));
      c.restore();
    }
    for (final p in model.pickups) {
      final special = p.bonus; // --- bonus levels
      if (special != null) {
        _bonusBadge(c, special, Offset(p.x, p.y), 36, aura: true);
        continue;
      }
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
    _bonusPowerStatus(c); // --- bonus levels
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
      _fogSlot(c, slot);
      // The sentinel's silhouette circles in the murk: in front of the
      // horizon band's glow (a darker shape in the fog), behind the far
      // banks and both veils, which drift across it at their own winds.
      if (slot == FogSlot.horizonBand) _foreshadowSilhouette(c);
      // --- boss-grandeur: the looming carrier rises through the layers
      // (one per ~8 s), and the fighting carrier's shadow falls on the
      // intermediate fog banks (operator R8).
      if (nextFog - 1 == _loomLayer(fogSlots.length)) _bossLoom(c);
      if (nextFog > 1) _bossFogShadow(c, slot);
      if (nextFog == fogSlots.length) lurkFogPass(c);
    }

    // --- carrier-hatches §A6: in the fight, the hull (prow, deck, hatches)
    // is drawn before the creatures, so none is ever covered by it.
    final front = model.boss;
    if (front != null && _carrierFrontFirst(front)) {
      _carrierFront(c, front);
      _hatchLurkers(c, front); // --- hatch-emergence: beats 1-3
    }
    emergencePainter.beginFrame();

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
      // --- hatch-emergence: beats 4-6 replace the flight sprite until the
      // entrance hands off (beat 7).
      if (!d.isLarge && _emergingCreature(c, d, pos)) continue;
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
      // sizes below are at scale 1; boss-carrier-wire: the 34-CSS-px
      // creature floor is a draw-size floor in the carrier band.
      _scaleAbout(c, pos, d.scale * _creatureFloor);
      // --- alien-insignia: the elite's dotted ring is gone; its winged
      // fang (gargoyle-insignia; and every rank's glyph) is drawn over the arena after the fog.
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
      // --- dive-shield-thinning: one shield in the body's own transform.
      if (d.dive > 0 && reveal > 0) _diveShield(c, pos, d, reveal);
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
      c.restore();
    }
    while (nextFog < fogSlots.length) {
      fog();
    }
    if (fogSlots.isEmpty) {
      _foreshadowSilhouette(c);
      _bossLoom(c);
    }
    _bossLoomLights(c);
    _deflectSparks(c); // --- playtest-fixes-3: hits glancing off
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
    if (b != null && !_carrierFrontFirst(b)) _carrierFront(c, b);
    _bossWrecks(c); // --- boss-grandeur: plates, modules, the collapse
    // --- atmosphere: one or two very thin sheets over the arena, creatures
    // and carrier included. Bullets, the player, tells and the HUD are drawn
    // after them: never fogged (research §11).
    if (model.perspective) {
      _fogSlot(c, FogSlot.skySheet1);
      _fogSlot(c, FogSlot.skySheet2);
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
    if (_zoomApplied) {
      // Undo the zoom: the marks are placed through the camera and drawn
      // at their fixed size (alien-insignia's hook).
      final cam = bossDirector.camera;
      c.save();
      final z = 1 / cam.zoom;
      c
        ..translate(ArenaCamera.pivotX, ArenaCamera.pivotY)
        ..scale(z, z)
        ..translate(-ArenaCamera.pivotX, -ArenaCamera.pivotY);
      insignia.paint(c, now: model.visualClock, toScreen: cam.toScreen);
      c.restore();
    } else {
      insignia.paint(c, now: model.visualClock);
    }
    // --- phone-performance §6: shots are drawn interpolated, smeared and
    // batched (shot_layer.dart); speeds and fire rates stay the model's.
    _mark(c, 'shots');
    shots.paint(
      c,
      model,
      ship,
      frameInterval: perf.interval,
      smear: !sectors.flyover.reducedMotion,
    );
    _mark(c, 'player');
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
    // --- phone-performance §4.2: at most budget.blasts explosion sprites,
    // the newest (the model keeps every blast; only drawing is capped).
    final blasts = model.blasts;
    final firstBlast = math.max(0, blasts.length - budget.blasts);
    for (var bi = firstBlast; bi < blasts.length; bi++) {
      final b = blasts[bi];
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
  /// gargoyle-insignia ladder: fang, twin fangs, winged fang, winged
  /// crown) and its 12 hull cells
  /// on the force field's lower arc, `ceil(12 · shield / shieldMax)` lit.
  /// carrier-hatches §A6: the fighting carrier's front pass goes under the
  /// creatures.
  bool _carrierFrontFirst(Carrier b) => b.fightReady;

  // --- hatch-emergence (design §4): the hatch's anchor on the bent hull.
  Offset _hatchAt(Carrier b, CarrierGate g) =>
      Offset(b.x, b.y) +
      (armada.carrier ? armada.bent(g.x, g.y) : Offset(g.x, g.y));

  /// Beats 1-3: the claws, peeks and held doors of the held hatches.
  void _hatchLurkers(Canvas c, Carrier b) {
    for (final (g, f, row) in emergence.lurking(model)) {
      emergencePainter.paint(
        c,
        f,
        row,
        _hatchAt(b, g),
        scale: _creatureFloor,
      );
    }
  }

  /// Beats 4-6 for [d] when it is emerging; false to draw it as usual.
  bool _emergingCreature(Canvas c, Demon d, Offset pos) {
    final b = model.boss;
    final e = emergence.of(d);
    final f = e?.frame;
    if (b == null || e == null || f == null) return false;
    emergencePainter.paint(
      c,
      f,
      e.row,
      _hatchAt(b, e.hatch),
      modelAt: pos,
      scale: d.scale * _creatureFloor,
    );
    return true;
  }

  /// The carrier's front pass: the prow, deck, gates and core door.
  void _carrierFront(Canvas c, Carrier b) {
    c.save();
    _carrierArrival(c, b, effects: true);
    final rising = _bossRiseBegin(c, b);
    final carrierBank = _carrierBank(b);
    final hullDamage = (1 - b.core / b.coreMax).clamp(0.0, 1.0);
    final hero = armada.heroReady;
    if (hero) {
      // boss-grandeur: the bow of the view set (the functional face) at
      // the director's view and stage; the scene adds barrels, hatches,
      // maw and shield as before.
      final d = bossDirector;
      armada.paintHero(
        c,
        Offset(b.x, b.y),
        view: d.view,
        previous: d.previous,
        blend: d.blend,
        stage: d.stage,
        front: true,
        detached: d.detached,
        clock: model.visualClock,
      );
      if (!armada.carrier) _carrierTurretBarrels(c, b);
      armada.paintRcs(c, Offset(b.x, b.y), carrierBank, model.visualClock);
    } else if (armada.ready) {
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
    if (armada.carrier) {
      // boss-carrier-wire: the v2 prow's hangar deck carries its own
      // doors (no fanged jaws, no lit windows: styleguide §3.4).
      _carrierDeck(c, b);
      // carrier-v3 §4: the prow's gates (deck bays, prong gates), over
      // the deck's furniture.
      carrierV3.paintGates(
        c,
        model.launches,
        Offset(b.x, b.y),
        front: true,
        clock: model.visualClock,
        bend: armada.bent,
        armada: armada,
        stage: armada.lastStage,
      );
    } else {
      _carrierLighting(c, Offset(b.x, b.y), carrierBank);
      if (!hero) _carrierEyes(c, b); // the view set's eyes are its own
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
      if (armada.anyReady) {
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
    }
    // carrier-v3 §3: a v2 carrier's field is the hull-conforming
    // membrane; its front lip (where shots stop) is drawn here, over the
    // prow. Without a distance map, today's arc.
    // --- carrier-hatches §A3–§A5: no hull-wide field any more; the core
    // door (the tusk-framed slot, its shutter and the lead pip).
    if (b.fightReady) {
      hatchPainter.paintCore(
        c,
        b,
        bend: armada.carrier ? armada.bent : null,
        clock: model.visualClock,
        reduced: sectors.flyover.reducedMotion,
        pip: model.leadPipShown
            ? Offset(model.leadPipAt(b).dx, model.leadPipAt(b).dy)
            : null,
      );
      // Part B: the breaking modules' components, attached or flying.
      if (armada.carrier) {
        breakup.paint(c, armada, bossDirector.clock, bent: armada.bent);
      }
    }
    // The view set carries its own damage stages (S1–S3).
    if (!hero) _damage(c, Offset(b.x, b.y), hullDamage, model.visualClock);
    if (rising) c.restore();
    c.restore();
    if (b.fightReady) _carrierInsignia(b);
  }

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

  /// --- carrier-render-engine: on a tall phone the band above the arena
  /// (headroom) is background, and gameplay is clipped out of it; but the
  /// carrier is larger than the screen, and clipped there its hull (and its
  /// wreck) ended in a straight line at the arena's top. Its two passes, its
  /// wreck and the sky sheets over them are drawn again into that band
  /// only, through the same camera, so the hull continues to the top.
  void _carrierHeadroom(Canvas canvas, ArenaCamera cam) {
    if (headroom <= .5 || !armada.carrier) return;
    final b = model.boss;
    final k = bossDirector.collapse;
    final wreck = k != null && !k.done;
    if (b == null && !wreck) return;
    canvas.save();
    canvas.clipRect(Rect.fromLTRB(0, -headroom, 360, 0), doAntiAlias: false);
    _zoomApplied = cam.zoom != 1;
    if (_zoomApplied) canvas.transform(cam.gameplayMatrix);
    if (b != null) {
      _carrierBackdrop(canvas);
      if (armada.heroReady) {
        // The prow too: the back pass is cut out beneath it.
        canvas.save();
        _carrierArrival(canvas, b);
        final rising = _bossRiseBegin(canvas, b);
        final d = bossDirector;
        armada.paintHero(
          canvas,
          Offset(b.x, b.y),
          view: d.view,
          previous: d.previous,
          blend: d.blend,
          stage: d.stage,
          front: true,
          detached: d.detached,
          clock: model.visualClock,
        );
        if (rising) canvas.restore();
        canvas.restore();
      }
    }
    if (wreck) _bossWrecks(canvas);
    if (model.perspective) {
      _fogSlot(canvas, FogSlot.skySheet1);
      _fogSlot(canvas, FogSlot.skySheet2);
    }
    _zoomApplied = false;
    canvas.restore();
  }

  /// The armada's background layer (engine plumes, superstructure, its
  /// breaches and running lights), drawn before the creatures so the
  /// outer hull reads as non-solid background that shots pass over.
  void _carrierBackdrop(Canvas c) {
    final b = model.boss;
    if (b == null || !armada.anyReady) return;
    c.save();
    _carrierArrival(c, b);
    final arriving = model.presentationMode == RunMode.transition;
    if (armada.heroReady) {
      final rising = _bossRiseBegin(c, b);
      // S3: the hull lists as a module breaks away (the outer hull only;
      // the functional face stays on its windows).
      final list = bossDirector.list;
      if (list != 0) {
        c
          ..translate(b.x, b.y)
          ..rotate(list * (b.direction < 0 ? -1 : 1))
          ..translate(-b.x, -b.y);
      }
      armada.paintHeroBackdrop(
        c,
        b,
        director: bossDirector,
        clock: model.visualClock,
        bank: _carrierBank(b),
        damage: (1 - b.core / b.coreMax).clamp(0.0, 1.0),
        burn: arriving
            ? .2
            : model.defeatActive
            ? (math.sin(model.visualClock * 9.2) > 0 ? 1.0 : .5)
            : -1,
      );
      if (armada.carrier) {
        // carrier-v3: the hull's own gates, the field's membrane, then the
        // speed cues over the hull and under the creatures.
        carrierV3.paintGates(
          c,
          model.launches,
          Offset(b.x, b.y),
          front: false,
          clock: model.visualClock,
          bend: armada.bent,
          armada: armada,
          stage: armada.lastStage,
        );
        if (b.fightReady) {
          // --- carrier-hatches §A3: the upper hatches and their own fields
          // replace the hull-wide membrane.
          hatchPainter.paintHatches(
            c,
            b,
            model.launches,
            bend: armada.bent,
            clock: model.visualClock,
            reduced: sectors.flyover.reducedMotion,
          );
          carrierV3.paintTrails(
            c,
            b,
            armada,
            bossDirector,
            bossDirector.camera,
          );
          carrierV3.paintCues(
            c,
            bossDirector,
            bossDirector.camera,
            cloud: atmosphere.cloud,
            cloudLight: Atmosphere.cloudLight,
            seed: model.seed * 31 + model.cycle,
          );
        }
      }
      if (rising) c.restore();
      c.restore();
      return;
    }
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
    // boss-carrier-wire: the ship's 36-CSS-px floor is a draw-size floor in
    // the carrier band (Z < 0.75); its hitbox is untouched.
    if (_zoomApplied) {
      c.scale(
        bossDirector.camera.floorScale(ShipPainter.size, ArenaCamera.shipFloor),
      );
    }
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

  // --- bonus levels: a bonus-only powerup is a regular badge from the
  // combat atlas, recoloured (and paired when `twin`), so it never reads
  // as the regular power. No new art.
  void _bonusBadge(
    Canvas c,
    BonusPowerDef def,
    Offset at,
    double size, {
    bool aura = false,
    double opacity = 1,
  }) {
    final tint = Color(def.tint);
    if (aura) {
      final pulse = .5 + .5 * math.sin(model.clock * 7);
      c.drawCircle(
        at,
        15 + 2 * pulse,
        Paint()..color = tint.withValues(alpha: .16 + .10 * pulse),
      );
    }
    final filter = ColorFilter.mode(tint, BlendMode.modulate);
    final shift = def.twin ? size * .14 : 0.0;
    if (def.twin) {
      sprite(
        c,
        CombatAtlas.pickupRow,
        def.badge,
        at + Offset(-shift, -shift * .6),
        size,
        filter: filter,
        opacity: opacity * .8,
      );
    }
    sprite(
      c,
      CombatAtlas.pickupRow,
      def.badge,
      at + Offset(shift, shift * .6),
      size,
      filter: filter,
      opacity: opacity,
    );
  }

  /// Active bonus powers ride beside the ship: the badge and a ring that
  /// runs down with its timer (no text over the play area).
  void _bonusPowerStatus(Canvas c) {
    if (model.shipAway) return;
    var i = 0;
    for (final def in model.activeBonusPowers) {
      final left = model.bonusPowerTimers[def.id] ?? 0;
      final side = i.isEven ? -1.0 : 1.0;
      final at = Offset(
        model.shipX + side * (30 + 4 * (i ~/ 2)),
        model.shipDrawY + 8 - 16.0 * (i ~/ 2),
      );
      final ending = left < 2 && (model.clock * 8).floor().isEven;
      final tint = Color(def.tint);
      c.drawArc(
        Rect.fromCircle(center: at, radius: 11),
        -math.pi / 2,
        2 * math.pi * (left / def.seconds).clamp(0.0, 1.0),
        false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..color = tint.withValues(alpha: ending ? .35 : .9),
      );
      _bonusBadge(c, def, at, 20, opacity: ending ? .5 : 1);
      i++;
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
      // --- bonus levels: a bonus power's crate flies its colour.
      Paint()..color = crate.bonus == null ? mint : Color(crate.bonus!.tint),
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
    final special = crate.bonus; // --- bonus levels
    if (special != null) {
      _bonusBadge(c, special, Offset(cx, cy), 22);
      return;
    }
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
      // --- phone-performance §4.1: the lite tier draws the halo sharp.
      ..maskFilter = budget.blur
          ? const MaskFilter.blur(BlurStyle.normal, 2.5)
          : null;
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
  ShadowMode get shadowMode => atmosphere.drawnQuality == AtmosphereQuality.reduced
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
    if (d.isLarge && h <= 0 && !d.entering) h = sentinelShadowAltitude(d);
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
      if (d.lastStand &&
          (d.rushPhase == RushPhase.lock || d.rushPhase == RushPhase.rush)) {
        // --- sentinel rush: on lock its shadow snaps over the ship's
        // (W3 shadows); on the relief, onto the ship's projected hit point.
        final ship = _shipShadowHit(surface);
        final snap = d.rushPhase == RushPhase.rush
            ? 1.0
            : Perspective.smoothstep(0, .12, d.rushClock);
        at = Offset.lerp(center, ship.center, snap)!;
        atFlat = Offset.lerp(flat, ship.flat, snap)!;
      }
      final img = effectsAtlas;
      if (img == null) return null;
      final species = d.archetype == EnemyArchetype.armoredSentinel ? 1 : 0;
      // playtest-fixes-3: one sentinel shadow from lurk through play and
      // the rush: the lurk's occluder look, sized by the one rule
      // [sentinelShadowScale] (ground nearness under it, its altitude).
      final frame = (model.clock / .55 + d.seed).floor() % 4;
      final clear = .7 + .3 * (1 - FlyoverBackground.groundFogAt(atFlat.dy));
      var a = lurkAlpha * clear;
      if (d.entering && d.swarmState != SwarmState.reentering && !handoff) {
        a *= Perspective.smoothstep(0, .12, d.entranceProgress);
      }
      return _ShadowSpec(
        img,
        Rect.fromLTWH(frame * 128.0, species * 64.0, 128, 64),
        at,
        sentinelShadowScale(groundNearness(atFlat.dy), h),
        a.clamp(0.0, lurkAlpha),
        2,
        atFlat,
        occluder: true,
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

  /// lurk-visibility: the occluder's strength at its core (multiply
  /// darkening toward [lurkTint], plus [lurkDesaturate] of the colour
  /// under it), and the smallest ground nearness its size uses.
  static const lurkAlpha = .9, lurkDesaturate = .6, lurkMinNearness = .2;

  /// Share of the occluder repeated over the depth fog banks above it.
  static const lurkFog = .65;
  static const lurkTint = Color(0xFF323C64);

  /// Tests and review: false leaves the lurking shadow undrawn (it is
  /// still tracked, so hesitation and the hand-off are unchanged).
  bool drawLurk = true;

  /// What the lurk pass draws this frame (the lurk, or its fading half
  /// during the hand-off).
  _ShadowSpec? _lurkDraw;

  /// The lurking shadow's visible footprint this frame (ground units and
  /// critters under it hesitate), or null.
  Rect? lurkCover;

  /// The visible centre of [d]'s shadow in the last pass (tests, review).
  Offset? shadowCenterOf(Demon d) => _lastShadows[d]?.center;

  /// The footprint scale of [d]'s shadow in the last pass (tests, review).
  double? shadowScaleOf(Demon d) => _lastShadows[d]?.scale;

  /// The last lurking shadow (tests and review), null when none is drawn.
  Offset? get lurkCenter => _lurkLast?.center;

  /// The last lurking shadow's footprint scale (tests and review).
  double? get lurkScale => _lurkLast?.scale;

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
    // lurk-visibility: never smaller than a broad patch near the fog, so it
    // is seen as soon as it appears.
    final n = ((hit.flat.dy - Perspective.horizonY) / Perspective.groundSpan)
        .clamp(lurkMinNearness, 1.0);
    // Full within 1.5 s of the silhouette appearing.
    final rise = Perspective.smoothstep(0, .5, f.opacity);
    // In thick ground fog it is a little softer, never nothing (the fog
    // over it dims too: [lurkFogPass]).
    final clear = .7 + .3 * (1 - FlyoverBackground.groundFogAt(hit.flat.dy));
    final alpha = lurkAlpha * rise * clear;
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
      sentinelShadowScale(n, l.altitude),
      alpha.clamp(0.0, lurkAlpha),
      2,
      hit.flat,
      occluder: true,
    );
  }

  /// playtest-fixes-3: the one size rule of every sentinel shadow (the
  /// lurk, the rising sentinel, the fight and the rush), as a scale of
  /// the 128 × 64 strip: the ground's nearness [n] under it (perspective)
  /// times its softness growth, spread by its altitude [h] above the
  /// fight's (a high caster's penumbra). In the fight it matches the
  /// sentinel's own drawn size; far and high, the lurk is broad for the
  /// ground it lies on, and nothing jumps at the hand-off.
  static double sentinelShadowScale(double n, double h) {
    final k = (h / _shadowHMax).clamp(0.0, 1.0);
    final spread = 1 + 1.2 * math.max(0.0, h - 90) / 130;
    return 1.6 * n.clamp(lurkMinNearness, 1.0) * (1 + .3 * k) * spread;
  }

  /// The ground's nearness at flat-ground row [y].
  static double groundNearness(double y) =>
      ((y - Perspective.horizonY) / Perspective.groundSpan).clamp(0.0, 1.0);

  /// A fighting sentinel's shadow altitude (presentation: it publishes
  /// none once it has arrived, which once left it shadowless): its flight
  /// sheet's altitude, falling toward the ship's 40 as a rush comes down.
  static double sentinelShadowAltitude(Demon d) {
    final fight = SwarmFlock.fightAltitude(d.homeY);
    if (!d.lastStand || d.rushPhase != RushPhase.rush) return fight;
    final k = ((d.y - 40) / (ArcadeModel.shipY - 40)).clamp(0.0, 1.0);
    return fight + (40 - fight) * k;
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
    // playtest-fixes-3: one occluder gliding from the lurk onto the
    // sentinel (both are drawn alike and sized by one rule).
    return _ShadowSpec(
      k < .5 ? from.image : to.image,
      k < .5 ? from.src : to.src,
      Offset.lerp(from.center, to.center, k)!,
      mix(from.scale, to.scale),
      mix(from.alpha, to.alpha),
      2,
      Offset.lerp(from.flat, to.flat, k)!,
      occluder: true,
    );
  }

  // --- lurk-visibility: the lurk as an occluder of the ground's light ---

  /// The effects strip's sentinel frames as soft white masks (blurred once,
  /// padded by [_lurkPad]), so the lurk is soft without a blur layer.
  ui.Image? _lurkMask;
  ui.Image? _lurkMaskFor;
  ImageShader? _lurkMaskShader;
  static const _lurkPad = 12.0;

  ui.Image _lurkMaskImage(ui.Image fx) {
    final cached = _lurkMask;
    if (cached != null && identical(_lurkMaskFor, fx)) return cached;
    const cw = 128 + 2 * _lurkPad, ch = 64 + 2 * _lurkPad;
    final rec = ui.PictureRecorder();
    final c = Canvas(rec);
    final paint = Paint()
      ..filterQuality = FilterQuality.medium
      ..colorFilter = const ColorFilter.mode(Color(0xFFFFFFFF), BlendMode.srcIn)
      ..imageFilter = ui.ImageFilter.blur(sigmaX: 3.2, sigmaY: 2.4);
    for (var row = 0; row < 2; row++) {
      for (var col = 0; col < 4; col++) {
        c.drawImageRect(
          fx,
          Rect.fromLTWH(col * 128.0, row * 64.0, 128, 64),
          Rect.fromLTWH(col * cw + _lurkPad, row * ch + _lurkPad, 128, 64),
          paint,
        );
      }
    }
    final pic = rec.endRecording();
    _lurkMask?.dispose();
    final mask = pic.toImageSync((4 * cw).round(), (2 * ch).round());
    pic.dispose();
    _lurkMask = mask;
    _lurkMaskFor = fx;
    _lurkMaskShader = ImageShader(
      mask,
      TileMode.clamp,
      TileMode.clamp,
      _identity4,
      filterQuality: FilterQuality.medium,
    );
    return mask;
  }

  /// Draws [s] (a strip frame of the effects atlas) as the lurking
  /// shadow: its soft mask draped on the surface, first desaturating the
  /// ground under it, then multiplying it toward [lurkTint]. Lit slopes,
  /// crest rims and the ground fog's glow dim with it, so it reads as a
  /// great shape passing over the light, never as a black blob.
  int _paintLurk(
    Canvas c,
    ShadowSurface surface,
    _ShadowSpec s, {
    double strength = 1,
    bool desaturate = true,
  }) {
    final fx = s.image;
    _lurkMaskImage(fx);
    final shader = _lurkMaskShader!;
    final lift = 1 - model.flow.env('lift');
    final a = (s.alpha * lift * strength).clamp(0.0, 1.0);
    if (a < .01) return 0;
    const cw = 128 + 2 * _lurkPad, ch = 64 + 2 * _lurkPad;
    final col = (s.src.left / 128).round(), row = (s.src.top / 64).round();
    final src = Rect.fromLTWH(col * cw, row * ch, cw, ch);
    const nv = ShadowProjector.vertices;
    final pos = Float32List(nv * 2), tex = Float32List(nv * 2);
    final idx = Uint16List(ShadowProjector.cells * 6);
    final n = ShadowProjector.drape(
      surface,
      s.flat,
      cw * s.scale,
      ch * s.scale * ShadowProjector.squash,
      src,
      pos,
      tex,
      idx,
      0,
      0,
    );
    if (n == 0) return 0;
    final indices = Uint16List.sublistView(idx, 0, n);
    ui.Vertices mesh(Color color) => ui.Vertices.raw(
      ui.VertexMode.triangles,
      pos,
      textureCoordinates: tex,
      colors: Int32List(nv)..fillRange(0, nv, color.toARGB32()),
      indices: indices,
    );
    if (desaturate) {
      c.drawVertices(
        mesh(Color.fromRGBO(128, 128, 128, lurkDesaturate * a)),
        BlendMode.modulate,
        Paint()
          ..shader = shader
          ..blendMode = BlendMode.saturation,
      );
    }
    c.drawVertices(
      mesh(lurkTint.withValues(alpha: a)),
      BlendMode.modulate,
      Paint()
        ..shader = shader
        ..blendMode = BlendMode.multiply,
    );
    return desaturate ? 2 : 1;
  }

  /// The fog banks drawn over the far ground dim over the lurk too, as the
  /// great shape above blocks their light (after the last depth bank).
  void lurkFogPass(Canvas c) {
    final s = _lurkDraw;
    if (s == null || !drawLurk || !model.perspective) return;
    _paintLurk(c, _shadowSurface, s, strength: lurkFog, desaturate: false);
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
    if (armada.heroReady) return _heroShadowImage();
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
    if (model.mode == RunMode.title) return null;
    // boss-grandeur: before the carrier exists its shadow still moves: it
    // sweeps the ground in the overflight and lurks toward the front while
    // the carrier looms under the fog.
    final caster = _bossShadowCaster();
    if (caster == null) return null;
    final (bx, by, k) = caster;
    final b = model.boss;
    final cell = _bossShadowImage();
    if (cell == null) return null;
    final h = math.max(1.0, bossShadowAltitude);
    var alpha = .35 * (defaultBossShadowAltitude / h).clamp(0.0, 1.0) * .85 * k;
    if (b != null && model.presentationMode == RunMode.transition) {
      // It firms up as the carrier settles out of its descent.
      alpha *= Curves.easeOutCubic.transform(
        model.transitionProgress.clamp(0.0, 1.0),
      );
    }
    if (alpha < .01) return null;
    final scale = .9 * math.sqrt(defaultBossShadowAltitude / h).clamp(.4, 1.2);
    final gy = Perspective.groundY(Perspective.nearnessAtY(by));
    // The cell's centre relative to the carrier's centre, on the ground.
    final mid = Offset(cell.width / 2, cell.height / 2) - _bossShadowAnchor;
    final base = Offset(
      bx + mid.dx * scale,
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
    _lurkDraw = null;
    shadowDrawCalls = 0;
    shadowDrawCallsPerBucket = 0;
    shipShadowDim = 0;
    shadowed.clear();
    if (!model.perspective || !creatureShadows) {
      sectors.flyover.terrain.lurkCover = null;
      return;
    }
    final reduced = atmosphere.drawnQuality == AtmosphereQuality.reduced;
    final draped = shadowMode == ShadowMode.draped;
    final surface = _shadowSurface;
    final buckets = [<_ShadowSpec>[], <_ShadowSpec>[], <_ShadowSpec>[]];
    final now = <Demon, _ShadowSpec>{};
    final occluders = <_ShadowSpec>[];
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
      if (s.occluder) {
        occluders.add(s);
      } else {
        buckets[reduced ? 0 : s.bucket].add(s);
      }
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
      if (s.occluder) {
        occluders.add(s.faded(left));
      } else {
        buckets[reduced ? 0 : s.bucket].add(s.faded(left));
      }
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
      _lurkDraw = lurk;
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
    // lurk-visibility: the lurking shadow first, as a passing occluder of
    // the ground's light (no layer of its own).
    final lurkNow = _lurkDraw;
    if (lurkNow != null && drawLurk) {
      shadowDrawCalls += _paintLurk(c, surface, lurkNow);
    }
    // playtest-fixes-3: the fighting sentinel's shadow, the same occluder.
    for (final s in occluders) {
      shadowDrawCalls += _paintLurk(c, surface, s);
    }
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

  // --- dive-shield-thinning: one shield that thins in place ---------------
  //
  // Replaces playtest-fixes-3's segmented crescents: those were cut into one
  // segment per point and spent from the outside in (the shield narrowed),
  // their flame lick throbbed the thickness on its own clock, they turned
  // with the heading while the body did not, and they were drawn outside
  // the body's wing roll (and the sentinel's bank squash). Now the same
  // crescent, whole and in the body's transform, loses only thickness
  // (to 40 % of full on the last point; design §5).

  /// The shield spec for an ordinary diver or a sentinel.
  static DiveShieldSpec diveShieldSpec(Demon d) {
    if (d.isLarge) return DiveShield.sentinel;
    final notSoSmall =
        d.diveShieldMax >= 2 || d.elite || d.kind >= 2 || d.maxHp >= 3;
    final s = notSoSmall ? DiveShield.medium : DiveShield.small;
    // The angry gargoyle is drawn 44 units wide instead of 40.
    return d.angry ? s.scaled(44 / 40) : s;
  }

  /// Where a sentinel's body is drawn: [effectSprite] snaps its corner to
  /// whole local units, and the shield snaps with it.
  static Offset _sentinelCentre(Offset pos) => Offset(
    (pos.dx - 64).roundToDouble() + 64,
    (pos.dy - 32).roundToDouble() + 32,
  );

  /// A diving creature's shield, in the caller's (the body's) transform.
  void _diveShield(Canvas c, Offset pos, Demon d, double reveal) {
    final flash = creatures.shields.hitFlash(d, 'dive');
    if (d.diveShield <= 0 && flash <= 0) return;
    DiveShield.paint(
      c,
      d.isLarge ? _sentinelCentre(pos) : pos,
      diveShieldSpec(d),
      points: d.diveShield,
      max: math.max(1, d.diveShieldMax),
      flash: flash,
      clock: model.clock,
      calm: sectors.flyover.reducedMotion,
      opacity: reveal.clamp(0.0, 1.0),
      seed: d.seed,
    );
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
    final bank = sentinelBank(demon);
    c.save();
    _bankAbout(c, pos, bank);
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
    final reveal = Perspective.gearReveal(t);
    // --- dive-shield-thinning: under the body's bank, on its snapped centre.
    if (diving && reveal > 0) _diveShield(c, pos, demon, reveal);
    c.restore();
    if (mark > 0) {
      // --- alien-insignia: the winged crown (gargoyle-insignia) over the
      // head, and one cyan cell per
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
  }

  /// The sentinel's bank (-1..1): the simulation's, or its sideways speed.
  static double sentinelBank(Demon demon) => demon.bank.abs() > 0.01
      ? demon.bank.clamp(-1.0, 1.0)
      : (demon.vx / 140).clamp(-1.0, 1.0);

  /// The sentinel body's bank transform about [pos]: a roll and a squash.
  void _bankAbout(Canvas c, Offset pos, double bank) {
    if (bank.abs() <= 0.04) return;
    c.translate(pos.dx, pos.dy);
    c.rotate(bank * 0.08);
    c.scale(1.0 - bank.abs() * 0.08, 1.0);
    c.translate(-pos.dx, -pos.dy);
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
  /// rally and lock while its crimson bow forms (the transformation, when
  /// nothing hurts it), then the bow at full size in the rush: the
  /// super-powerful diving shield, dimming as the rush shield wears.
  void _sentinelBerserk(Canvas c, Offset pos, Demon d) {
    final phase = d.rushPhase;
    final forming = phase == RushPhase.rally || phase == RushPhase.lock;
    if (forming) {
      final flare = phase == RushPhase.lock
          ? 1.0
          : (d.rushClock / RushTuning.rally).clamp(0.0, 1.0);
      _sentinelEyes(c, pos, .6 + .4 * flare, scale: 1 + .25 * flare);
    }
    if (!forming && phase != RushPhase.rush) return;
    final breaking = creatures.shields.breaking(d, 'rush');
    if (d.rushShield <= 0 && phase == RushPhase.rush && !breaking) return;
    final reel = d.rushStagger > 0 ? .5 : 1.0;
    final grow = forming
        ? Perspective.smoothstep(0, 1, d.lastStandTellProgress)
        : 1.0;
    // --- dive-shield-thinning: the super-strong shield, the thickest. It
    // fades in at its full size (never growing) and thins with the rush
    // shield's points, in the body's bank.
    final max = d.rushShieldMax > 0 ? d.rushShieldMax : 1;
    final points = d.rushShieldMax > 0 ? d.rushShield : 1;
    c.save();
    _bankAbout(c, pos, sentinelBank(d));
    DiveShield.paint(
      c,
      _sentinelCentre(pos),
      DiveShield.rush,
      points: points,
      max: max,
      flash: creatures.shields.hitFlash(d, 'rush'),
      clock: model.clock,
      calm: sectors.flyover.reducedMotion,
      opacity: forming ? .3 + .7 * grow : reel,
      seed: d.seed,
    );
    c.restore();
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

  /// playtest-fixes-3: a hit glancing off a berserk sentinel: a white-hot
  /// star at the impact and five sparks ricocheting away from the body
  /// (gold to ember), gone in [Deflect.life] s. Reduced motion keeps the
  /// star only.
  /// phone-performance §4.2: the hard cap on deflect stars drawn at once.
  static const maxDeflectsDrawn = 24;

  void _deflectSparks(Canvas c) {
    if (model.deflects.isEmpty) return;
    final paint = Paint()..isAntiAlias = false;
    // --- phone-performance §4.2: the newest [maxDeflectsDrawn]; the lite
    // tier keeps the stars and drops the ricochet sparks.
    final all = model.deflects;
    final sparks = budget.sparks;
    for (var di = math.max(0, all.length - maxDeflectsDrawn);
        di < all.length;
        di++) {
      final f = all[di];
      final u = (f.age / Deflect.life).clamp(0.0, 1.0);
      final at = Offset(f.x, f.y);
      // The star: a plus of white and gold, shrinking.
      final r = (5 * (1 - u) + 1).roundToDouble();
      paint.color = const Color(0xFFFFFFFF).withValues(alpha: 1 - u * .6);
      c.drawRect(
        Rect.fromCenter(center: at, width: r * 2 + 1, height: 3),
        paint,
      );
      c.drawRect(
        Rect.fromCenter(center: at, width: 3, height: r * 2 + 1),
        paint,
      );
      paint.color = const Color(0xFFFFD54F).withValues(alpha: 1 - u);
      c.drawRect(Rect.fromCenter(center: at, width: 3, height: 3), paint);
      if (sectors.flyover.reducedMotion || !sparks) continue;
      // Away from the sentinel's centre (a ricochet off its ward).
      final away = math.atan2(f.y - f.cy, f.x - f.cx);
      for (var i = 0; i < 5; i++) {
        final a = away + (i - 2) * .42 + math.sin(f.x * 3.1 + i) * .12;
        final reach = (6 + 16 * u) * (.75 + .25 * ((i * 7) % 3));
        final p = at + Offset(math.cos(a), math.sin(a)) * reach;
        paint.color = Color.lerp(
          const Color(0xFFFFF6CC),
          const Color(0xFFFF6D00),
          u,
        )!.withValues(alpha: 1 - u);
        c.drawRect(
          Rect.fromCenter(
            center: Offset(p.dx.roundToDouble(), p.dy.roundToDouble()),
            width: 2,
            height: 2,
          ),
          paint,
        );
      }
    }
  }

  // --- end sentinel rush presentation

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

  /// boss-carrier-wire: the v2 carrier's hangar deck furniture over the
  /// prow art, at the simulation windows (core, bays, turret pivots). The
  /// head-reading guard (styleguide §3.4) shapes every piece: the slot is
  /// split into three hatches by solid chitin bulkheads, the weak points
  /// glow through vertical slits (a horizontal lit slot reads as a mouth),
  /// the doors are plain chitin leaves (no fangs), and the gun barrels are
  /// dark with an ember muzzle (pale pegs read as teeth).
  void _carrierDeck(Canvas c, Carrier b) {
    final paint = Paint()..isAntiAlias = false;
    const black = Color(0xFF05040A), chitin = Color(0xFF2B2234);
    const edge = Color(0xFF55456A), ember = Color(0xFFFF7A2A);
    final weak = b.shield > 0 ? violet : gold;
    // A hatch: black well, a vertical slit glow, two chitin leaves closing
    // from the sides with a lighter lip.
    void hatch(
      Offset at,
      double w,
      double h,
      double open, {
      bool locked = false,
    }) {
      c.drawRect(
        Rect.fromCenter(center: at, width: w, height: h),
        paint..color = black,
      );
      if (!locked) {
        final glow = .35 + .65 * open.clamp(0.0, 1.0);
        c.drawRect(
          Rect.fromCenter(center: at, width: 4 + 3 * open, height: h - 6),
          paint..color = weak.withValues(alpha: glow),
        );
      }
      final closed = (w / 2) * (locked ? 1 : 1 - open.clamp(0.0, 1.0));
      for (final dir in const [-1.0, 1.0]) {
        final x0 = dir < 0 ? at.dx - w / 2 : at.dx + w / 2 - closed;
        c.drawRect(
          Rect.fromLTWH(x0, at.dy - h / 2, closed, h),
          paint..color = chitin,
        );
        if (closed > 1) {
          final lip = dir < 0 ? x0 + closed - 1 : x0;
          c.drawRect(
            Rect.fromLTWH(lip, at.dy - h / 2, 1, h),
            paint..color = edge,
          );
        }
      }
      if (locked) {
        c.drawRect(
          Rect.fromCenter(center: at, width: 3, height: 3),
          paint..color = ember,
        );
      }
    }

    hatch(Offset(b.x, b.y + 25), 32, 22, b.door);
    for (final (dx, open) in [
      (-Carrier.sideHatchOffset, b.sideDoorLeft),
      (Carrier.sideHatchOffset, b.sideDoorRight),
    ]) {
      hatch(
        Offset(b.x + dx, b.y + 21),
        22,
        16,
        open,
        locked: b.sideHatchesLocked,
      );
    }
    // Bulkheads between the core and the bays: the deck reads as three
    // hangar mouths in a row, not one slot.
    for (final dx in const [-28.0, 28.0]) {
      final r = Rect.fromLTWH(b.x + dx - 3, b.y + 10, 6, 26);
      c.drawRect(r, paint..color = chitin);
      c.drawRect(
        Rect.fromLTWH(r.left, r.top, 1, r.height),
        paint..color = edge,
      );
    }
    // The art paints pale bone tusks under the sill blisters (y 38–56):
    // pegs in a slot read as fangs; a chitin tint takes them to hull value.
    for (final side in const [-28.0, 28.0]) {
      c.drawRect(
        Rect.fromLTWH(b.x + side - 6, b.y + 39, 12, 19),
        paint..color = const Color(0xB0140E1C),
      );
    }
    // Gun barrels on the sill: dark, an ember muzzle.
    final aim = math
        .atan2(ArcadeModel.shipY - (b.y + 36), model.shipX - b.x)
        .clamp(0.4, 2.74);
    for (final side in const [-28.0, 28.0]) {
      c.save();
      c.translate(b.x + side, b.y + 36);
      c.rotate(aim - math.pi / 2);
      c.drawRect(const Rect.fromLTWH(-3, 0, 2, 7), paint..color = chitin);
      c.drawRect(const Rect.fromLTWH(1, 0, 2, 7), paint..color = chitin);
      c.drawRect(const Rect.fromLTWH(-3, 6, 2, 1), paint..color = ember);
      c.drawRect(const Rect.fromLTWH(1, 6, 2, 1), paint..color = ember);
      c.restore();
    }
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

    if (triumph && model.wreckBoss != null && !armada.heroReady) {
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
    // --- carrier-render-engine: a radial glow around the kill that fades
    // to nothing before the nearest visible edge. A rectangle showed its
    // edges under the boss zoom, and on tall phones at the arena's top.
    final hit = flow.env('hit');
    if (hit > 0) {
      final cam = bossDirector.camera;
      final view = _zoomApplied
          ? Rect.fromPoints(
              cam.toArena(Offset.zero),
              cam.toArena(const Offset(360, 520)),
            )
          : const Rect.fromLTWH(0, 0, 360, 520);
      final w = model.wreckBoss;
      final at = w != null
          ? Offset(w.x, w.y).translate(0, 40)
          : view.center;
      final r = math
          .min(
            math.min(at.dx - view.left, view.right - at.dx),
            math.min(at.dy - view.top, view.bottom - at.dy),
          )
          .clamp(80.0, 260.0);
      final tint = triumph ? gold : mint;
      c.drawCircle(
        at,
        r,
        Paint()
          ..shader = ui.Gradient.radial(at, r, [
            tint.withValues(alpha: hit * .2),
            tint.withValues(alpha: hit * .1),
            tint.withValues(alpha: 0),
          ], const [0, .55, 1]),
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
    this.flat, {
    this.occluder = false,
  });
  final ui.Image image;
  final Rect src;

  /// playtest-fixes-3: drawn as an occluder of the ground's light (the
  /// lurk's look), not as ink in a blur bucket: every sentinel shadow.
  final bool occluder;

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
    occluder: occluder,
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

// --- boss-grandeur: the boss level's presentation (design §1–§6) ---------
extension _BossGrandeur on DemonScene {
  /// A fog layer over the arena. Under the camera's zoom the fog is not
  /// zoomed (it is weather, world-anchored, drawn to the whole frame), so
  /// the zoomed arena never shows a fog rectangle's edge.
  void _fogSlot(Canvas c, FogSlot slot) {
    final layer = _layerNow; // --- phone-performance: harness layers
    _mark(c, 'fog');
    _fogSlotIn(c, slot);
    _mark(c, layer);
  }

  void _fogSlotIn(Canvas c, FogSlot slot) {
    if (!_zoomApplied) {
      atmosphere.paint(c, slot);
      return;
    }
    final z = 1 / bossDirector.camera.zoom;
    c.save();
    c
      ..translate(ArenaCamera.pivotX, ArenaCamera.pivotY)
      ..scale(z, z)
      ..translate(-ArenaCamera.pivotX, -ArenaCamera.pivotY);
    atmosphere.paint(c, slot);
    c.restore();
  }

  /// A colour matrix toward [fog] by [t] (alpha kept), darkened by [dark].
  static ColorFilter fogFilter(Color fog, double t, {double dark = 0}) {
    final k = (1 - t) * (1 - dark);
    return ColorFilter.matrix([
      k, 0, 0, 0, fog.r * 255 * t, //
      0, k, 0, 0, fog.g * 255 * t,
      0, 0, k, 0, fog.b * 255 * t,
      0, 0, 0, 1, 0,
    ]);
  }

  /// The carrier's shade under the fog: the fog's colour, deep in shadow.
  Color get _bossShade =>
      Color.lerp(atmosphere.cloud, const Color(0xFF0A0710), .78)!;

  /// The whole hull (both layers) at [center], drawn from the view set's
  /// hero view, or the frontal atlas's first form.
  void paintBossBody(Canvas c, Offset center) {
    if (armada.heroReady) {
      for (final front in const [false, true]) {
        armada.paintHero(
          c,
          center,
          view: BossView.hero,
          stage: 0,
          front: front,
        );
      }
    } else if (armada.ready) {
      final h = armada.hull;
      armada.sprite(c, h.superstructure[0], center);
      armada.sprite(c, h.hull[0][0], center);
    }
  }

  /// The fog layer after which the loom is drawn: it starts behind all
  /// but the horizon band and rises one layer per ~8 s.
  ///
  /// carrier-v3 §5.2: by the approach distance D: between the far banks
  /// for D ≥ 3, between the veils for 1.8 ≤ D < 3, under the near sheets
  /// below (one bank nearer than the design: behind every far bank the
  /// hull read as a pale ghost on the review strip).
  int _loomLayer(int layers) {
    if (layers == 0) return 0;
    final d = bossDirector.distance;
    if (d >= 3) return math.min(layers - 1, 1);
    if (d >= 1.8) return math.min(layers - 1, 3);
    return layers - 1;
  }

  /// The carrier looming under the fog: a dark mass between the far banks.
  void _bossLoom(Canvas c) {
    if (bossDirector.phase != BossPhase.approach || !armada.anyReady) return;
    final at = bossDirector.loomAt;
    final k = bossDirector.loomScale;
    c.save();
    c
      ..translate(at.dx, at.dy)
      ..scale(k, k);
    // carrier-v3 §5.2: aerial perspective, toward the fog's colour (value
    // and contrast, never blur) by 1 − e^(−0.55 (D − 1)).
    c.saveLayer(
      null,
      Paint()
        ..colorFilter = fogFilter(_approachFog, .85 * bossDirector.fog)
        ..color = const Color.fromRGBO(255, 255, 255, .94),
    );
    paintBossBody(c, Offset.zero);
    c.restore();
    c.restore();
  }

  /// The approach's haze colour: the fog's, a little into its shade.
  Color get _approachFog => Color.lerp(_bossShade, atmosphere.cloud, .3)!;

  /// Its running lights blink through the fog (drawn after the banks), and
  /// its gates telegraph and launch through it (carrier-v3 §4.3).
  void _bossLoomLights(Canvas c) {
    if (bossDirector.phase != BossPhase.approach || !armada.heroReady) return;
    final at = bossDirector.loomAt;
    final k = bossDirector.loomScale;
    if (armada.carrier) {
      carrierV3.paintGates(
        c,
        model.launches,
        at,
        front: false,
        scale: k,
        clock: model.visualClock,
        opacity: .9,
        armada: armada,
      );
      carrierV3.paintGates(
        c,
        model.launches,
        at,
        front: true,
        scale: k,
        clock: model.visualClock,
        opacity: .9,
        armada: armada,
      );
    }
    if ((ambient * 1.4).floor().isOdd) return;
    final paint = Paint()..isAntiAlias = false;
    for (final l in armada.heroPoints(BossView.hero, 0, kind: 'lights')) {
      final p = at + Offset(l.x, l.y) * k;
      paint.color =
          (l.kind == 0
                  ? const Color(0xFFFF3048)
                  : (l.kind == 1
                        ? const Color(0xFF40FF90)
                        : const Color(0xFFFFC45A)))
              .withValues(alpha: .5);
      c.drawRect(Rect.fromCenter(center: p, width: 2, height: 2), paint);
    }
  }

  /// The Rise: the carrier comes out of the fog from its loom position to
  /// its fight row, shedding the fog; true when a layer was pushed (the
  /// caller restores it).
  bool _bossRiseBegin(Canvas c, Carrier b) {
    if (b.fightReady) return false;
    final e = Curves.easeInOutCubic.transform(b.emerge.clamp(0.0, 1.0));
    final from = bossDirector.loomAt;
    final k = bossDirector.loomScale + (1 - bossDirector.loomScale) * e;
    final x = from.dx + (b.x - from.dx) * e;
    final y = from.dy + (b.y - from.dy) * e;
    c
      ..translate(x, y)
      ..scale(k, k)
      ..translate(-b.x, -b.y);
    // carrier-v3 §5.2: the Close sheds the haze of distance D.
    c.saveLayer(
      null,
      Paint()
        ..colorFilter = fogFilter(
          _approachFog,
          .85 * CarrierApproachScript.fogMix(bossDirector.distance),
        )
        ..color = Color.fromRGBO(255, 255, 255, .9 + .1 * e),
    );
    return true;
  }

  /// The intermediate fog banks take the fighting carrier's shadow
  /// (operator R8), as the lurk dims them: a soft dark shape on the band.
  void _bossFogShadow(Canvas c, FogSlot slot) {
    final b = model.boss;
    if (b == null || !b.fightReady || !model.perspective) return;
    final cell = _bossShadowImage();
    if (cell == null) return;
    final l = Atmosphere.layers[slot];
    if (l == null || l.nearness <= 0) return;
    final a = (.1 + .14 * bossDirector.climb) * (l.alpha * 2).clamp(0.0, 1.0);
    if (a < .01) return;
    final scale = .8 + .25 * (l.nearness - .3);
    final mid = Offset(cell.width / 2, cell.height / 2) - _bossShadowAnchor;
    final center = Offset(b.x + 14 + mid.dx * scale, l.peak);
    // --- phone-performance §4.4: the blur is baked into the cell once (a
    // per-draw ImageFilter is an offscreen layer, up to four a frame).
    final soft = _fogShadowCell(cell);
    c.save();
    c.clipRect(Rect.fromLTRB(-60, l.top, 420, l.bottom));
    c.drawImageRect(
      soft,
      Rect.fromLTWH(0, 0, soft.width.toDouble(), soft.height.toDouble()),
      Rect.fromCenter(
        center: center,
        width: soft.width * scale,
        height: soft.height * scale * .45,
      ),
      Paint()
        ..color = Color.fromRGBO(255, 255, 255, a)
        ..blendMode = BlendMode.multiply
        ..filterQuality = FilterQuality.medium,
    );
    c.restore();
  }

  /// [cell] blurred as the fog-bank shadow draws it: the blur of (4, 3)
  /// arena units, at the cell's mean drawn scale (.875 across, .875 × .45
  /// down), in cell pixels, with a margin of three sigmas.
  ui.Image _fogShadowCell(ui.Image cell) {
    final hit = _fogShadowSoft;
    if (hit != null && identical(_fogShadowSource, cell)) return hit;
    const k = .875, sx = 4 / k, sy = 3 / (k * .45);
    final px = (sx * 3).ceilToDouble(), py = (sy * 3).ceilToDouble();
    final rec = ui.PictureRecorder();
    Canvas(rec).drawImage(
      cell,
      Offset(px, py),
      Paint()
        ..filterQuality = FilterQuality.medium
        ..imageFilter = ui.ImageFilter.blur(sigmaX: sx, sigmaY: sy),
    );
    final pic = rec.endRecording();
    _fogShadowSoft?.dispose();
    final soft = pic.toImageSync(
      (cell.width + 2 * px).round(),
      (cell.height + 2 * py).round(),
    );
    pic.dispose();
    _fogShadowSource = cell;
    return _fogShadowSoft = soft;
  }

  /// Overflight geometry at progress [p]: centre, scale, and the hull's
  /// opacity (never more than 0.55 while it covers the ship's row).
  (Offset, double, double) overflightPose(double p) {
    final e = Curves.easeOutCubic.transform(p);
    final y = 760 + (112 - 760) * e;
    final x = 180 + 26 * math.sin(p * math.pi);
    final k = 2.9 + (.42 - 2.9) * math.pow(p, .55);
    final top = y - 160 * k, bottom = y + 90 * k;
    final overShip =
        top < ArcadeModel.shipY + 30 && bottom > ArcadeModel.shipY - 30;
    var o = overShip ? .55 : .85;
    o *= 1 - Perspective.smoothstep(.72, 1, p); // into the far fog
    o *= Perspective.smoothstep(0, .06, p);
    return (Offset(x, y), k.toDouble(), o);
  }

  /// The carrier flies in from behind the camera, over the ship, and sinks
  /// into the far fog (presentation only, no hitbox).
  void _bossOverflight(Canvas c) {
    if (bossDirector.phase != BossPhase.overflight || !armada.anyReady) return;
    final p = bossDirector.overflight;
    if (p <= 0 || p >= 1) return;
    final (at, k, o) = overflightPose(p);
    if (o < .01) return;
    c.save();
    c
      ..translate(at.dx, at.dy)
      ..scale(k, k);
    // Its dark belly, fogging as it recedes.
    final far = Perspective.smoothstep(.5, 1, p);
    c.saveLayer(
      null,
      Paint()
        ..colorFilter = fogFilter(
          Color.lerp(_bossShade, atmosphere.cloud, far)!,
          .62 + .3 * far,
        )
        ..color = Color.fromRGBO(255, 255, 255, o),
    );
    // boss-carrier-wire: the carrier's baked underside (`fin_belly`, 0.5
    // px/unit, ≈ 926 units wide), drawn at [bellyScale] so it passes over
    // the ship about as wide as the frigate did, still two screens across
    // as it enters; the hull from above where no belly is packed.
    c.save();
    c.scale(bellyScale);
    final belly = armada.paintBelly(c, Offset.zero);
    c.restore();
    if (!belly) paintBossBody(c, Offset.zero);
    c.restore();
    c.restore();
  }

  /// The belly's scale in the overflight's frame (see [_bossOverflight]).
  static const bellyScale = .3;

  /// Its shadow sweeps the ground first, a little ahead of the hull.
  void _bossOverflightShadow(Canvas c) {
    if (bossDirector.phase != BossPhase.overflight) return;
    final p = bossDirector.overflight;
    if (p <= 0 || p >= 1) return;
    final (at, k, o) = overflightPose((p + .12).clamp(0.0, 1.0));
    final a = .3 * (1 - p) * (o > 0 ? 1 : 0);
    if (a < .01) return;
    c.drawOval(
      Rect.fromCenter(
        center: at + Offset(10, 30 * k),
        width: 220 * k,
        height: 80 * k,
      ),
      Paint()
        ..color = DemonScene.lurkTint.withValues(alpha: a)
        ..blendMode = BlendMode.multiply
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, 10 * k),
    );
  }

  /// The director's falling pieces: plates (S2), modules breaking away
  /// (S3) and the collapse's module wrecks (S4), each with a blast as it
  /// breaks.
  void _bossWrecks(Canvas c) {
    // --- carrier-hatches Part B: components still flying after the kill.
    if (model.boss == null && armada.heroReady) {
      breakup.paint(c, armada, bossDirector.clock);
    }
    // --- carrier-render-engine §3: a v2 carrier falls as one wreck.
    bossDirector.ensureCollapse(model, armada.modules);
    final collapse = bossDirector.collapse;
    if (collapse != null && !collapse.done && armada.heroReady) {
      final k = 1 - collapse.progress;
      armada.paintCollapse(
        c,
        collapse,
        fog: Color.lerp(atmosphere.cloud, DemonScene.lurkTint, .55)!,
        cloud: atmosphere.cloud,
        shadowInk: Color.lerp(DemonScene.lurkTint, const Color(0xFF05030A), .5),
        shadowAlpha: .45 * k,
        shadowShift: Offset(10 + 22 * k, 16 + 40 * k) * bossDirector.altitude,
      );
      armada.paintCollapseSmoke(
        c,
        collapse,
        fog: atmosphere.cloud,
        blast: (at, size, age) => sprite(
          c,
          CombatAtlas.explosionRow,
          (age * 8).floor().clamp(0, 7),
          at,
          size,
          opacity: .8 * (1 - collapse.progress * .5),
        ),
      );
    }
    if (bossDirector.wrecks.isEmpty) return;
    // boss-carrier-wire: each wreck throws its shadow onto the fog it
    // falls into, its own sprite's alpha as the mask; the shadow closes in
    // and fades into the fog as the wreck sinks.
    if (armada.heroReady) {
      final ink = Color.lerp(DemonScene.lurkTint, const Color(0xFF05030A), .5)!;
      for (final w in bossDirector.wrecks) {
        if (!w.started) continue; // at rest it is still the hull
        final k = 1 - w.progress;
        armada.paintHeroWreckShadow(
          c,
          w,
          shift: Offset(10 + 22 * k, 16 + 40 * k) * bossDirector.altitude,
          ink: ink,
          alpha: (w.plate ? .3 : .5) * w.opacity * (.35 + .65 * k),
        );
      }
    }
    // Pieces that have not broken away yet hold the hull's shape where it
    // died (back to front: the carapace, the modules, the prow), so the
    // carrier never vanishes before its pieces fall.
    if (armada.heroReady) {
      int depth(String id) => id == 'carapace' || id == 'spine'
          ? 0
          : (id == 'prow' || id == 'bow' ? 2 : 1);
      final waiting = [
        for (final w in bossDirector.wrecks)
          if (!w.started && !w.plate) w,
      ]..sort((a, b) => depth(a.module) - depth(b.module));
      for (final w in waiting) {
        armada.paintHeroWreck(c, w, fog: atmosphere.cloud);
      }
    }
    for (final w in bossDirector.wrecks) {
      if (!w.started) continue;
      if (armada.heroReady) {
        armada.paintHeroWreck(c, w, fog: atmosphere.cloud);
      } else if (armada.ready && w.plate && armada.hull.debris.isNotEmpty) {
        c.save();
        c.translate(w.x, w.y);
        c.rotate(w.rotation);
        armada.sprite(
          c,
          armada.hull.debris[0],
          Offset.zero,
          opacity: w.opacity,
        );
        c.restore();
      }
      final age = w.age - w.delay;
      if (!w.plate && age < .55) {
        sprite(
          c,
          CombatAtlas.explosionRow,
          (age / .55 * 8).floor().clamp(0, 7),
          Offset(w.x, w.y - 30),
          120,
          opacity: .75,
        );
      }
    }
  }

  /// A soft 12 % vignette outside the zoomed arena's bounds.
  void _arenaEdge(Canvas c, ArenaCamera cam) {
    final tl = cam.toScreen(Offset.zero);
    final br = cam.toScreen(const Offset(360, 520));
    final k = ((1 - cam.zoom) / (1 - ArenaCamera.minZoom)).clamp(0.0, 1.0);
    if (k <= 0) return;
    const ink = Color(0xFF05040A);
    Paint shade(Offset a, Offset b) => Paint()
      ..shader = ui.Gradient.linear(a, b, [
        ink.withValues(alpha: .12 * k + .1 * k),
        ink.withValues(alpha: 0),
      ]);
    if (tl.dx > 0) {
      c.drawRect(
        Rect.fromLTRB(0, 0, tl.dx + 6, 520),
        shade(Offset.zero, Offset(tl.dx + 6, 0)),
      );
      c.drawRect(
        Rect.fromLTRB(br.dx - 6, 0, 360, 520),
        shade(const Offset(360, 0), Offset(br.dx - 6, 0)),
      );
    }
    if (tl.dy > 0) {
      c.drawRect(
        Rect.fromLTRB(0, 0, 360, tl.dy + 6),
        shade(Offset.zero, Offset(0, tl.dy + 6)),
      );
    }
  }

  /// The hero hull's shadow cell (its S0 hero view, inked, 1 px per unit).
  ui.Image? _heroShadowImage() {
    final pages = armada.heroPages;
    final h = armada.hero;
    if (pages == null || h == null) return null;
    final key = (pages, armada.loadedClass, 'hero');
    if (_bossShadowFor == key) return _bossShadowCell;
    final (l, t, r, bt) = h.frame;
    final rec = ui.PictureRecorder();
    final c = Canvas(rec)..translate(-l, -t);
    c.saveLayer(
      null,
      Paint()
        ..filterQuality = FilterQuality.medium
        ..colorFilter = DemonScene._shadowInk,
    );
    for (final front in const [false, true]) {
      armada.paintHero(
        c,
        Offset.zero,
        view: BossView.hero,
        stage: 0,
        front: front,
      );
    }
    c.restore();
    final pic = rec.endRecording();
    _bossShadowCell?.dispose();
    _bossShadowCell = pic.toImageSync((r - l).ceil(), (bt - t).ceil());
    pic.dispose();
    _bossShadowAnchor = Offset(-l, -t);
    _bossShadowFor = key;
    return _bossShadowCell;
  }

  /// Where the boss shadow's caster is (x, row) and its strength.
  (double, double, double)? _bossShadowCaster() {
    final b = model.boss;
    if (b != null) return (b.x, b.y, b.fightReady ? 1 : b.emerge);
    final d = bossDirector;
    if (d.phase == BossPhase.approach) {
      // The lurking shadow crawls from the far terrain toward the front.
      return (d.loomAt.dx, -60 + 210 * d.loom, .7);
    }
    if (d.phase == BossPhase.overflight &&
        d.overflight > 0 &&
        d.overflight < 1) {
      final (at, _, _) = overflightPose(d.overflight);
      return (at.dx, at.dy, .9 * (1 - d.overflight));
    }
    return null;
  }
}
