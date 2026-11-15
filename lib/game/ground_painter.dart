import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import 'atmosphere.dart';
import 'easter_eggs.dart';
import 'ground_atlas.dart';
import 'ground_atmosphere.dart';
import 'ground_atmosphere_atlas.dart';
import 'ground_blocks_painter.dart';
import 'ground_presentation.dart';
import 'ground_troops_atlas.dart';
import 'model.dart';
import 'ship_painter.dart';

/// Draws the ground war from `assets/images/ground-forces.png`
/// (tools/ground_forces_assets.py) and the homing missiles from the ship
/// atlas. Presentation only: it reads [ArcadeModel.ground], never writes.
///
/// Layers: [paintGround] goes between the flyover background and the air
/// combat (units, allies, tracers, wrecks: things standing on the ground);
/// [paintAir] goes above the air combat (ground missiles coming at the
/// camera, homing missiles, lock-on reticle, pickups).
/// Things standing on the ground that a nearer unit must not paint over
/// (the flyover's plants): ground war v4 depth-sorts them with the units.
abstract interface class GroundOccluders {
  /// Plants on the ground this frame: depth and screen box.
  List<(double, Rect)> get groundPlants;

  /// Paints plant [index] of [groundPlants] again (exactly as the
  /// background drew it).
  void paintGroundPlant(Canvas c, int index);
}

class GroundPainter {
  ui.Image? image;

  // --- ground war v4: mixed forces (tools/ground_troops) and plant depth.
  ui.Image? troops;
  GroundOccluders? occluders;

  // --- ground blocks runtime: per-sector block atlases (headings, layers,
  // overlays). The old atlases stay loaded: every effect still uses them.
  /// Feature switch: false draws every unit from the old atlases.
  static bool useBlocks = true;
  final GroundBlocksLayer blocks = GroundBlocksLayer();

  // --- ground atmosphere art: horizon fog, cloud shadows, the two mist
  // banks and the dust veil take part in the depth sort (draw order of
  // plan/ground-atmosphere.md §4). Nothing is drawn without the atlas.
  Atmosphere? atmosphere;
  // --- ground easter eggs (plan/ground-easter-eggs.md): the shared budget
  // (the flyover's; null keeps the pre-egg behaviour) and per-paint state.
  EasterEggBudget? eggs;
  ArcadeModel? _model;
  int _debrisDrawn = 0;

  // --- depth fog on units (plan/ground-atmosphere.md §2): the sector's fog
  // tint while the atmosphere art is installed (null: no tint, exactly the
  // pre-art look) and the mix of the unit being drawn.
  Color? _fogTint;
  double _fogMix = 0;

  /// The fog mix of the unit or ally drawn now (tests/tools).
  double get debugFogMix => _fogMix;

  void _setFog(double z, {bool threat = false, double? x, double? y}) {
    _fogMix = _fogTint == null
        ? 0
        : GroundFog.unitMix(z, threat: threat, x: x, y: y);
    blocks.fogMix = _fogMix;
  }

  /// Whether a demon unit can fire at the player (the fog caps it).
  static bool isThreat(GroundUnit u) => !u.skirmish;

  // --- battlefield smoke (plan/ground-atmosphere.md §3): the packed
  // smokeDrift / smokeWall sprites, while the atmosphere art is installed.
  GroundAtmosphereArt? _smoke;
  Color _smokeTint = const Color(0xFF555B65);
  bool _smokeFull = true, _smokeStill = false;
  int _smokeDrawn = 0;

  /// Smoke sprites at most per frame (the plan's draw-call budget).
  static const maxSmoke = 14;

  /// Smoke sprites drawn by the last paint (tests/tools).
  int get debugSmokeDrawn => _smokeDrawn;

  /// Screen rects of the smoke walls the last paint drew (tests/tools).
  final List<Rect> debugSmokeWalls = [];

  /// Screen rects and opacities of the drift puffs the last paint drew.
  final List<(Rect, double)> debugSmokePuffs = [];

  /// Troopers draw a little smaller than vehicles (they are people).
  static const troopScale = 1.0, allyTroopScale = .7;

  /// Draw scale of a demon unit on top of the simulation's perspective
  /// scale (openspec change ground-presentation-tuning): Host vehicles
  /// 1.3x, troopers 0.9x. The simulation's `scale`, `width` and `bodyY`
  /// (placement, launch point, homing aim) are unchanged.
  static double drawScale(GroundUnit u) =>
      u.scale *
      (u.force == GroundForce.infantry || u.force == GroundForce.rockets
          ? GroundSize.trooper
          : GroundSize.hostVehicle);

  /// Draw scale of an ally: Fleet vehicles 0.5x, troopers 0.9x.
  static double allyDrawScale(GroundAlly a) =>
      a.scale *
      (a.force == GroundForce.vehicle
          ? GroundSize.fleetVehicle
          : GroundSize.trooper);

  static const _warm = Color(0xFFFF8676), _hot = Color(0xFFFFD594);
  static const _mint = Color(0xFF70F5D5), _cyan = Color(0xFF6EDCFF);

  final Paint _paint = Paint()
    ..isAntiAlias = false
    ..filterQuality = FilterQuality.none;
  final Paint _block = Paint()..isAntiAlias = false;

  /// Brightness: subdued in the haze at the horizon, full on the near ground
  /// (the flyover's own fog runs from the horizon to about y = 330).
  static double depthLight(double z) => (.38 +
          .62 *
              ((GroundTuning.spawnZ - z) /
                      (GroundTuning.spawnZ - GroundTuning.fireZ))
                  .clamp(0.0, 1.0))
      .clamp(0.0, 1.0);

  void _cell(
    Canvas c,
    int row,
    int col,
    double cx,
    double bottom,
    double scale, {
    bool mirror = false,
    double light = 1,
    double opacity = 1,
    bool troop = false,
    bool emissive = false,
    bool tell = false,
    bool reveal = false,
  }) {
    final img = troop ? troops : image;
    if (img == null) return;
    final cw = troop ? GroundTroopsAtlas.cellW : GroundAtlas.cellW;
    final ch = troop ? GroundTroopsAtlas.cellH : GroundAtlas.cellH;
    final w = cw * scale, h = ch * scale;
    final v = (255 * light).round().clamp(0, 255);
    _paint.color = Color.fromARGB((255 * opacity).round().clamp(0, 255), v, v, v);
    final tint = _fogTint;
    final mix = tint == null || tell
        ? 0.0
        : emissive
            ? GroundFog.emissive(_fogMix)
            : _fogMix;
    _paint.colorFilter = mix > 0
        ? GroundFog.filter(light, mix, tint!)
        : light < .999
            ? ColorFilter.mode(Color.fromARGB(255, v, v, v), BlendMode.modulate)
            : null;
    final src = Rect.fromLTWH(
      col * cw * 1.0,
      row * ch * 1.0,
      cw * 1.0,
      ch * 1.0,
    );
    final left = (cx - w / 2).roundToDouble(), top = (bottom - h).roundToDouble();
    void draw() {
      if (mirror) {
        c.save();
        c.translate(left + w, top);
        c.scale(-1, 1);
        c.drawImageRect(img, src, Rect.fromLTWH(0, 0, w, h), _paint);
        c.restore();
      } else {
        c.drawImageRect(img, src, Rect.fromLTWH(left, top, w, h), _paint);
      }
    }

    draw();
    // Eyes and cracks baked into a fogged body show through at half rate.
    final r = reveal ? GroundBlocksLayer.revealAlpha(mix) : 0.0;
    if (r > 0) {
      _paint
        ..color = Color.fromRGBO(255, 255, 255, (opacity * r).clamp(0.0, 1.0))
        ..colorFilter = Atmosphere.glowMatrix;
      draw();
    }
  }

  void _px(Canvas c, double x, double y, double s, Color color) {
    _block.color = color;
    c.drawRect(
      Rect.fromLTWH(x.roundToDouble(), y.roundToDouble(), s, s),
      _block,
    );
  }

  /// A cell centred on (cx, cy) instead of bottom-centred.
  void _cellC(Canvas c, int row, int col, double cx, double cy, double scale,
          {bool mirror = false,
          double light = 1,
          double opacity = 1,
          bool troop = false,
          bool emissive = false,
          bool tell = false}) =>
      _cell(c, row, col, cx,
          cy + (troop ? GroundTroopsAtlas.cellH : GroundAtlas.cellH) * scale / 2, scale,
          mirror: mirror, light: light, opacity: opacity, troop: troop,
          emissive: emissive, tell: tell);

  /// Fire, flashes and sparks glow through the haze: they fog only half as
  /// much as hulls do.
  static double _glow(double light) => .55 + .45 * light;

  /// Sprite scale of something on the ground at screen row [y].
  static double _scaleAtY(double y) =>
      GroundCamera.texel(GroundCamera.zOf(math.max(y, GroundCamera.horizon + 4))) *
      GroundTuning.unitScale;

  /// Things on the ground, far to near: scorch decals first (they lie flat
  /// on the ground under everything), then units and allies depth-sorted,
  /// then tracers with their muzzle flashes and impacts.
  void paintGround(Canvas c, ArcadeModel m) {
    final on = useBlocks;
    _model = m;
    _debrisDrawn = 0;
    if (on) blocks.begin(m.visualClock);
    _paintGround(c, m);
    if (on) blocks.end();
  }

  void _paintGround(Canvas c, ArcadeModel m) {
    final g = m.ground;
    final atmo = m.perspective ? atmosphere : null;
    final air = atmo?.groundLayers ?? const [];
    _fogTint = atmo?.groundArt == null ? null : GroundFog.tintFor(atmo!.environment);
    blocks.fogTint = _fogTint;
    _setFog(0);
    _smoke = atmo?.groundArt;
    _smokeDrawn = 0;
    debugSmokeWalls.clear();
    debugSmokePuffs.clear();
    if (atmo != null) {
      _smokeTint = GroundFog.smokeFor(atmo.environment);
      _smokeFull = atmo.quality == AtmosphereQuality.full;
      _smokeStill = atmo.reducedMotion;
    }
    if (g.units.isEmpty && g.allies.isEmpty && g.tracers.isEmpty) {
      for (final (_, l) in air) {
        atmo!.paintGroundLayer(c, l);
      }
      return;
    }
    final clock = m.visualClock;
    for (final u in g.units) {
      if (u.destroyed && u.y >= GroundCamera.horizon + 2) {
        _setFog(u.z, x: u.x, y: u.y);
        _scorch(c, u);
      }
    }
    final items = <(double, void Function())>[
      for (final u in g.units) (u.z, () => _unit(c, u, clock, m)),
      for (final a in g.allies) (a.z, () => _ally(c, a, clock)),
      for (final (z, l) in air) (z, () => atmo!.paintGroundLayer(c, l)),
      if (_smoke != null) ..._smokeItems(c, g.units, clock),
    ];
    // --- ground war v4: a plant nearer than a unit it overlaps is painted
    // again after that unit, in depth order (the background drew it first).
    final occ = occluders;
    if (occ != null) {
      final boxes = <(double, Rect)>[
        for (final u in g.units)
          if (drawScale(u) case final ds)
            (u.z, Rect.fromLTWH(u.x - u.width * ds / u.scale / 2, u.y - 26 * ds,
                u.width * ds / u.scale, 26 * ds)),
        for (final a in g.allies)
          if (allyDrawScale(a) case final ds)
            (a.z, Rect.fromLTWH(a.x - a.width * ds / a.scale / 2, a.y - 26 * ds,
                a.width * ds / a.scale, 26 * ds)),
      ];
      final plants = occ.groundPlants;
      for (var i = 0; i < plants.length; i++) {
        final (pz, pr) = plants[i];
        if (boxes.any((b) => b.$1 > pz && b.$2.overlaps(pr))) {
          items.add((pz - .01, () => occ.paintGroundPlant(c, i)));
        }
      }
    }
    items.sort((a, b) => b.$1.compareTo(a.$1));
    for (final item in items) {
      item.$2();
    }
    // Tracers, shots and everything after the ground sort: never fogged.
    _setFog(0);
    for (final t in g.tracers) {
      _tracer(c, t, g.allies);
    }
  }

  // ---------------------------------------------------------------- demons

  void _scorch(Canvas c, GroundUnit u) {
    final s = drawScale(u);
    // The mark stays on the ground for the wreck's life, fading at the end.
    final fade = (1 - (u.wreckAge - 4.5) / 1.5).clamp(0.0, 1.0);
    final grow = (u.wreckAge / .25).clamp(.4, 1.0);
    _cell(c, GroundAtlas.effectRow,
        GroundAtlas.scorchCol + u.id % GroundAtlas.scorchVariants,
        u.x, u.y + 2 * s, s * 1.1 * grow,
        light: depthLight(u.z), opacity: fade * .95);
  }

  void _unit(Canvas c, GroundUnit u, double clock, ArcadeModel m) {
    if (u.y < GroundCamera.horizon + 2) return;
    _setFog(u.z, threat: isThreat(u), x: u.x, y: u.y);
    switch (u.force) {
      case GroundForce.infantry || GroundForce.rockets:
        return _squad(c, u, clock);
      case GroundForce.heavyTank:
        return _tank(c, u, clock, m);
      case GroundForce.vehicle:
        break;
    }
    final s = drawScale(u), width = u.width * GroundSize.hostVehicle;
    final row = GroundAtlas.demonRow(u.sector);
    final mirror = u.mirrored;
    final light = depthLight(u.z);
    final bt = useBlocks ? blocks.unitTrack(u) : null;
    if (u.destroyed) {
      if (bt != null) {
        _wreck(c, u, clock, mirror, light,
            (opacity) => blocks.hulk(c, u, bt, clock, light, opacity),
            bt);
        return;
      }
      _wreck(c, u, clock, mirror, light, (opacity) => _cell(c, row,
          GroundAtlas.wreckCol + ((clock * 8 * GroundPace.fx).floor() % 2), u.x, u.y, s,
          mirror: mirror, light: light, opacity: opacity));
      return;
    }
    final int col;
    if (u.fireFlash > GroundTuning.fireFlash * .5) {
      col = GroundAtlas.fireCol;
    } else if (u.fireFlash > 0) {
      col = GroundAtlas.postFireCol;
    } else if (u.telegraphing) {
      // Launcher raise, then the glow pulses faster toward launch.
      final p = u.telegraphProgress;
      col = p < .45
          ? GroundAtlas.telegraphCol
          : GroundAtlas.telegraphCol +
                ((clock * (p > .8 ? 16 : 8)).floor().isEven ? 1 : 0);
    } else {
      col = GroundAtlas.moveCol +
          ((clock * 10 * GroundPace.anim * (u.pose?.hesitate ?? 1) +
                      u.id * .37)
                  .floor() %
              GroundAtlas.moveFrames);
    }
    // Dust kicked up behind the advancing unit (toward the horizon).
    if (!u.telegraphing && u.fireFlash <= 0) {
      for (var k = 0; k < 2; k++) {
        final q = (clock * 1.6 * GroundPace.fx + k * .5 + u.id * .13) % 1;
        final sx = (k == 0 ? -1 : 1) * width * .32;
        _cell(c, GroundAtlas.fxRow,
            GroundAtlas.dustCol + (q * GroundAtlas.dustFrames).floor(),
            u.x + sx, u.y - q * 3 * s, s * .55,
            light: light * .8, opacity: (1 - q) * .55);
      }
    }
    if (bt != null) {
      blocks.demonVehicle(c, u, bt, clock, light, _glow(light), m);
    } else {
      _cell(c, row, col, u.x, u.y, s, mirror: mirror, light: light, reveal: true);
    }
    if (u.telegraphing) {
      // A warm warning bracket under the launcher: readable at phone size.
      final p = u.telegraphProgress;
      final w = width * .55, y = u.y + 2;
      final on = (clock * (p > .8 ? 14 : 7)).floor().isEven;
      final color = on ? _hot : _warm;
      final unit = math.max(2.0, s.roundToDouble());
      for (final sx in const [-1.0, 1.0]) {
        final x = u.x + sx * w - (sx > 0 ? unit : 0);
        _px(c, x, y, unit, color);
        _px(c, x - sx * unit, y, unit, color);
        _px(c, x, y - unit, unit, color);
      }
    }
    if (u.fireFlash > 0) {
      final k = 1 - u.fireFlash / GroundTuning.fireFlash;
      final mx = u.x + (mirror ? -1 : 1) * width * .2;
      _cell(c, GroundAtlas.effectRow, GroundAtlas.launchFlashCol, mx,
          u.y + s, s * 1.1,
          mirror: mirror, light: _glow(light), tell: true);
      _cellC(c, GroundAtlas.flameRow,
          GroundAtlas.muzzleWarmCol +
              (k * GroundAtlas.muzzleFrames).floor().clamp(0, 2),
          mx, u.y - 15 * s, s, light: _glow(light), tell: true);
    }
  }

  /// Destroyed demon unit: shock ring, fireball, flying debris, then a
  /// burning hulk with flame tongues and a rising smoke column.
  void _wreck(Canvas c, GroundUnit u, double clock, bool mirror,
      double light, void Function(double opacity) hulk,
      [GroundBlockTrack? bt]) {
    final s = drawScale(u), t = u.wreckAge;
    final width = u.width * s / u.scale;
    // The visual timeline at half speed (flames, debris arcs, shock ring,
    // fireball); the wreck's life (6 s, the simulation's) is unchanged.
    final vt = t * GroundPace.fx, fc = clock * GroundPace.fx;
    final glow = _glow(light);
    final fade = (1 - (t - 5) / 1).clamp(0.0, 1.0);
    if (vt < .36) {
      _cell(c, GroundAtlas.fxRow,
          GroundAtlas.shockCol + (vt / .36 * GroundAtlas.shockFrames).floor(),
          u.x, u.y + 3 * s, s * 1.9,
          light: glow, emissive: true, opacity: 1 - vt / .5);
    }
    if (t > .12) hulk(fade);
    // Flame tongues on the hulk: tall at first, dying down after ~3 s.
    final burn = t < .3 ? 0.0 : (1 - (t - 3) / 1.6).clamp(0.0, 1.0);
    if (burn > 0) {
      const sites = [(-.18, 1.0), (.2, .75), (-.02, .6)];
      for (var k = 0; k < sites.length; k++) {
        final (fx, size) = sites[k];
        final f = (fc * 12 + k * 2 + u.id).floor() % GroundAtlas.flameFrames;
        _cell(c, GroundAtlas.flameRow, GroundAtlas.flameCol + f,
            u.x + fx * width * (mirror ? -1 : 1), u.y - 4 * s,
            s * .62 * size * (.55 + .45 * burn),
            light: glow, emissive: true, opacity: math.min(1, burn * 1.6) * fade);
      }
    }
    // Smoke column: puffs born dense and dark at the hulk, rising, growing
    // and thinning, drifting with the wind; with the atmosphere art, its
    // smokeDrift puffs carry the column on into a drifting battlefield haze.
    if (t > .5 && _smoke != null) _wreckSmoke(c, u, t);
    if (t > .5) {
      final strength = (1 - (t - 4) / 2).clamp(0.0, 1.0);
      for (var k = 0; k < 5; k++) {
        final q = (vt * .55 + k / 5) % 1;
        _cellC(c, GroundAtlas.fxRow,
            GroundAtlas.puffCol + (q * GroundAtlas.puffFrames).floor(),
            u.x + (k.isEven ? -2 : 2) * s + q * q * 14 * s,
            u.y - 12 * s - q * 34 * s, s * (.7 + q * .9),
            light: light, opacity: (1 - q * .8) * .95 * strength);
      }
    }
    // Fireball over everything for the first second.
    if (vt < 1.0) {
      final f = (vt / 1.0 * GroundAtlas.explosionFrames)
          .floor()
          .clamp(0, GroundAtlas.explosionFrames - 1);
      _cell(c, GroundAtlas.effectRow, GroundAtlas.explosionCol + f, u.x,
          u.y + 3 * s, s * 2.0, light: glow, emissive: true);
    }
    // --- ground easter eggs: the breakup (5-8 pieces for a light Host
    // vehicle, 3-4 for a heavier one, at most 16 on screen, clipped at the
    // lane edge), the plain wreck with reduced motion, and the jackpot.
    final e = bt == null ? null : eggs;
    var pieces = 7;
    var jackpot = false;
    var head = -1;
    if (e != null) {
      final unit = bt!.cells.unit;
      final small = unit.faction == 'host' && unit.unitClass == 'light';
      pieces = e.reducedMotion && small
          ? 0
          : e.debrisPieces(u.id, light: small);
      if (small && u.z < EasterEggBudget.farZ &&
          (t < .2 || e.decided(u, EasterEgg.jackpot) != null)) {
        jackpot = e.decide(u, EasterEgg.jackpot,
            key: u.id * 97 + (_model?.level ?? 0),
            band: EasterEggBudget.bandOf(u.x));
      }
      if (jackpot) head = GroundBlocksLayer.jackpotHead(bt.cells).$2;
    }
    // Debris: chunks thrown out on ballistic arcs; they lie where they land.
    if (t < 5.5) {
      final rnd = math.Random(u.id * 7919 + 17);
      for (var k = 0; k < pieces; k++) {
        final vx = (rnd.nextDouble() * 2 - 1) * 34;
        final vy = 26 + rnd.nextDouble() * 34;
        final spin = rnd.nextInt(4);
        const grav = 120.0;
        final land = 2 * vy / grav + .05;
        final tt = math.min(vt, land);
        final h = math.max(0.0, 7 + vy * tt - .5 * grav * tt * tt);
        var x = u.x + vx * tt * s * .7;
        final y = u.y + (rnd.nextDouble() * 4 - 1) * s * (tt / land) - h * s;
        final flying = vt < land;
        if (e != null) {
          if (jackpot && k == head) continue; // it pops instead
          if (_debrisDrawn >= EasterEggBudget.maxDebrisOnScreen) break;
          _debrisDrawn++;
          x = _laneClip(u.x, x, y);
        }
        // --- ground blocks runtime: the unit's authored pieces.
        if (bt != null &&
            blocks.piece(c, bt, k, x, y, s,
                flying ? (vt * 14 + spin).floor() : spin,
                light: flying ? glow : light * .85, opacity: fade, emissive: flying)) {
          continue;
        }
        _cellC(c, GroundAtlas.flameRow,
            GroundAtlas.debrisCol +
                (flying ? (vt * 14 + spin).floor() % GroundAtlas.debrisFrames : spin),
            x, y, s * .8,
            light: flying ? glow : light * .85, opacity: fade, emissive: flying);
      }
    }
    if (jackpot) blocks.jackpot(c, u, bt!, clock, light, glow);
  }

  // ---------------------------------------------- battlefield smoke

  /// One smokeDrift puff, frame [frame], bottom-centred on ([x], [bottom])
  /// at sprite scale [s]: the lane cap applies to its screen rect.
  void _puff(Canvas c, double x, double bottom, double s, int frame,
      double opacity, {bool mirror = false}) {
    final art = _smoke;
    if (art == null || _smokeDrawn >= maxSmoke || opacity <= 0) return;
    final src = GroundAtmosphereAtlas.smokeDrift(
        frame.clamp(0, GroundAtmosphereAtlas.smokeDriftFrames - 1));
    final w = src.width * s, h = src.height * s;
    final dst = Rect.fromLTWH(x - w / 2, bottom - h, w, h);
    final o = GroundSmoke.driftOpacity(dst, opacity);
    art.paintSmoke(c, src, dst, opacity: o, tint: _smokeTint, mirror: mirror);
    _smokeDrawn++;
    debugSmokePuffs.add((dst, o));
  }

  /// Smoke over a wreck: puffs born dense at the hulk, rising 4 units a
  /// second and swaying ±2 while they thin through the six frames. Reduced
  /// atmosphere keeps one puff; reduced motion holds the densest frame and
  /// fades it out.
  void _wreckSmoke(Canvas c, GroundUnit u, double t) {
    final strength = (1 - (t - 4) / 2).clamp(0.0, 1.0);
    final s = u.scale;
    final base = u.y - 24 * u.scale; // over the column's dense puffs
    if (_smokeStill) {
      _puff(c, u.x, base, s, 0, .7 * strength);
      return;
    }
    final n = _smokeFull ? 3 : 1;
    const life = GroundSmoke.puffLife;
    for (var k = 0; k < n; k++) {
      final q = ((t - .5) + k * life / n) % life;
      // Born only after the wreck is: no puff older than the smoke.
      if (q > t - .5) continue;
      final p = q / life;
      final sway = GroundSmoke.sway * math.sin(t * 2.1 + k * 2 + u.id);
      _puff(
        c,
        u.x + (sway + q * 4) * u.scale,
        base - GroundSmoke.rise * q * u.scale * 3.5,
        s * (.85 + .6 * p),
        (p * GroundAtmosphereAtlas.smokeDriftFrames).floor(),
        (.7 - .4 * p) * strength,
        mirror: (u.id + k).isOdd,
      );
    }
  }

  /// Smoke that is not part of one wreck, as depth-sort entries: a smoke
  /// wall along a burning wreck line (two hulks burning close together on
  /// one side; never inside the lane; full atmosphere only) and gun smoke
  /// over skirmish units trading fire.
  List<(double, void Function())> _smokeItems(
      Canvas c, List<GroundUnit> units, double clock) {
    final out = <(double, void Function())>[];
    final burning = [
      for (final u in units)
        if (u.destroyed && u.wreckAge > .8 && u.wreckAge < 5 &&
            u.y >= GroundCamera.horizon + 2)
          u,
    ];
    var walls = 0;
    for (var i = 0; i < burning.length && _smokeFull && walls < 2; i++) {
      for (var j = i + 1; j < burning.length && walls < 2; j++) {
        final a = burning[i], b = burning[j];
        if (a.side != b.side || (a.z - b.z).abs() > 220) continue;
        if ((a.x - b.x).abs() > 80) continue;
        final z = math.max(a.z, b.z);
        final s = GroundCamera.texel(z) * GroundTuning.unitScale * .7;
        const life = 5.0;
        final age = math.min(a.wreckAge, b.wreckAge);
        final strength = ((age - .8) / .8).clamp(0.0, 1.0) *
            (1 - (math.max(a.wreckAge, b.wreckAge) - 4) / 1).clamp(0.0, 1.0);
        final src = GroundAtmosphereAtlas.smokeWall(_smokeStill
            ? 0
            : ((clock * 1 / 1.6).floor() + a.id) %
                GroundAtmosphereAtlas.smokeWallFrames);
        final w = src.width * s, h = src.height * s;
        final drift = _smokeStill ? 0.0 : ((clock + a.id) % life) * 1 * s;
        final cx = (a.x + b.x) / 2 + drift - .5 * s;
        final bottom = math.min(a.y, b.y) - 4 * s;
        final dst = Rect.fromLTWH(cx - w / 2, bottom - h, w, h);
        if (GroundSmoke.inLane(dst)) continue;
        walls++;
        final o = GroundAtmosphereAtlas.smokeWallMin +
            (GroundAtmosphereAtlas.smokeWallMax -
                    GroundAtmosphereAtlas.smokeWallMin) *
                strength;
        out.add((z + .5, () {
          final art = _smoke;
          if (art == null || _smokeDrawn >= maxSmoke || strength <= 0) return;
          art.paintSmoke(c, src, dst,
              opacity: o, tint: _smokeTint, mirror: a.side == 1);
          _smokeDrawn++;
          debugSmokeWalls.add(dst);
        }));
      }
    }
    // Gun smoke: a thin puff lingers over a skirmish unit while it trades
    // fire (one every 3 s per unit, at most four on screen).
    var gun = 0;
    for (final u in units) {
      if (gun >= 4 || !_smokeFull) break;
      if (!u.skirmish || !u.alive || !(u.ally?.alive ?? false)) continue;
      if (u.z > 1150 || u.y < GroundCamera.horizon + 2) continue;
      final q = _smokeStill ? 0.0 : (clock + u.id * .7) % 3.0;
      if (q > GroundSmoke.puffLife) continue;
      gun++;
      final p = q / GroundSmoke.puffLife;
      out.add((u.z + .5, () => _puff(
            c,
            u.x + (u.mirrored ? -1 : 1) * u.width * .3 + q * 2 * u.scale,
            u.bodyY - 2 * u.scale - GroundSmoke.rise * q * u.scale,
            u.scale * .45 * (.8 + .4 * p),
            _smokeStill ? 0 : 2 + (p * 4).floor(),
            GroundAtmosphereAtlas.smokeDriftMin * (1 - p * .6),
            mirror: u.id.isOdd)));
    }
    return out;
  }

  // ---------------------------------------------- ground easter eggs

  /// A piece thrown from a unit outside the lane lands short of the lane
  /// edge below the swarm band (plan rule 2).
  static double _laneClip(double from, double x, double y) {
    if (y <= 300) return x;
    if (from < GroundCamera.laneLeft) return math.min(x, GroundCamera.laneLeft - 2);
    if (from > GroundCamera.laneRight) return math.max(x, GroundCamera.laneRight + 2);
    return x;
  }

  /// Rough ground distance in texels between two units.
  static double _texelDistance(double x1, double z1, double x2, double z2) {
    final l1 = (x1 - 180) / GroundCamera.texel(math.max(z1, 1));
    final l2 = (x2 - 180) / GroundCamera.texel(math.max(z2, 1));
    final dl = l1 - l2, dz = z1 - z2;
    return math.sqrt(dl * dl + dz * dz);
  }

  /// A Fleet dance may play: near enough to see, no Host unit within 200
  /// texels, no totalled ally smoking within 100 (plan section 2).
  bool _danceOk(GroundAlly a) {
    final m = _model;
    if (m == null || a.z >= EasterEggBudget.farZ || !a.alive) return false;
    for (final u in m.ground.units) {
      if (u.alive && _texelDistance(a.x, a.z, u.x, u.z) < 200) return false;
    }
    for (final o in m.ground.allies) {
      if (!identical(o, a) && o.totalled &&
          _texelDistance(a.x, a.z, o.x, o.z) < 100) {
        return false;
      }
    }
    return true;
  }

  /// Dance triggers of a Fleet squad or vehicle: a skirmish it fought was
  /// won by the allies, it was saved, or the sector is clear.
  void _danceTriggers(GroundAlly a, GroundBlockTrack bt) {
    final e = eggs;
    final m = _model;
    if (e == null || m == null) return;
    final band = EasterEggBudget.bandOf(a.x);
    final foe = a.attacker;
    if (foe != null) bt.lastFoe = foe;
    final last = bt.lastFoe;
    if (last is GroundUnit && last.destroyed) {
      bt.lastFoe = null;
      if (last.destroyedByAllies && !bt.flourishing && _danceOk(a) &&
          e.request(EasterEgg.dance, key: a.id * 1009 + last.id, band: band)) {
        blocks.startFlourish(bt);
      }
    }
    if (m.presentationMode == RunMode.levelClear && !bt.clearDanced) {
      bt.clearDanced = true;
      if (a.alive && a.z < EasterEggBudget.farZ &&
          e.request(EasterEgg.sectorDance,
              key: a.id, band: band, guaranteed: true)) {
        blocks.startFlourish(bt, 3);
      }
    }
  }

  /// A Host squad jigs when the ally it fought falls back.
  void _jigTrigger(GroundUnit u, GroundBlockTrack bt) {
    final e = eggs;
    if (e == null) return;
    final foe = u.ally;
    if (foe != null) bt.lastFoe = foe;
    final last = bt.lastFoe;
    if (last is GroundAlly && (last.fallingBack || last.totalled)) {
      bt.lastFoe = null;
      if (last.fallingBack && u.alive && u.z < EasterEggBudget.farZ &&
          e.request(EasterEgg.jig,
              key: u.id * 1013 + last.id, band: EasterEggBudget.bandOf(u.x))) {
        blocks.startFlourish(bt, 1 / GroundPace.egg);
      }
    }
  }

  // ---------------------------------------------- ground war v4: new forces

  /// Troopers drawn for a demon squad (1-5, most often 2-4; rocket teams
  /// 1-3). The simulation's squad strength (its hp) is unchanged: the
  /// drawn group falls in proportion (openspec change
  /// ground-presentation-tuning, design §4).
  static int squadSize(GroundUnit u) => GroundSquadLook.size(u.id,
      rockets: u.force == GroundForce.rockets, ally: false);

  /// Troopers drawn for an allied squad.
  static int allySquadSize(GroundAlly a) => GroundSquadLook.size(a.id,
      rockets: a.force == GroundForce.rockets, ally: true);

  /// A demon squad: each trooper walks on its own phase and cadence, keeps
  /// its own place in a loose group, drifts, leads or lags and turns on its
  /// own; kneels to aim while holding, fires in turn; the fallen topple and
  /// crack into stone rubble.
  void _squad(Canvas c, GroundUnit u, double clock) {
    final s = drawScale(u) * troopScale;
    final spread = u.scale * GroundSize.trooper;
    final light = math.max(.62, depthLight(u.z)); // v4: threats read in haze
    final row = u.force == GroundForce.rockets
        ? GroundTroopsAtlas.demonRocketRow
        : GroundTroopsAtlas.demonGruntRow;
    final n = squadSize(u);
    final alive =
        u.destroyed ? 0 : GroundSquadLook.standing(n, u.hp, u.maxHp);
    final fell = u.destroyed ? n : GroundSquadLook.fellLast(n, u.hp, u.maxHp);
    final moving = !u.destroyed && (u.z > u.holdZ + 1 || u.vx.abs() > 2);
    final engaged = u.ally?.alive ?? false;
    final bt = useBlocks ? blocks.unitTrack(u) : null;
    if (bt != null) {
      blocks.observe(bt, u.x, u.z);
      _jigTrigger(u, bt);
    }
    final march = bt == null ? (moving ? 1.0 : 0.0) : blocks.marchOf(bt, moving);
    final heading = bt?.hull.signedAngle ?? 180.0;
    final seed = u.id * 31 + GroundSquadLook.demonSalt;
    final ac = clock * GroundPace.anim;
    // A fallen trooper lies where it fell: its place frozen at the hit
    // (the legacy path has no memory and freezes it at the latest hit).
    (double, double) fallenAt(int k) => GroundSquadLook.offset(
        seed, k, clock - (u.destroyed ? u.wreckAge : math.max(0, u.lastHit)),
        heading: heading, march: 0);
    final lying = bt?.lying ?? <int, (double, double)>{};
    final place = [
      for (var k = 0; k < n; k++)
        k < alive
            ? GroundSquadLook.offset(seed, k, clock,
                heading: heading, march: march)
            : lying.putIfAbsent(k, () => fallenAt(k)),
    ];
    final order = List.generate(n, (k) => k)
      ..sort((a, b) => place[a].$2.compareTo(place[b].$2));
    for (final k in order) {
      final (ox, oy) = place[k];
      final x = u.x + ox * spread, y = u.y + oy * spread * .5;
      if (k >= alive) {
        // Fallen: those dropped by the last hit topple, then everyone lies
        // as rubble.
        final t = u.destroyed ? u.wreckAge : (k < fell ? u.lastHit : 9.0);
        if (t < 0) continue;
        final fade = (1 - (t - 4) / 1.5).clamp(0.0, 1.0);
        if (fade <= 0) continue;
        if (bt != null) {
          blocks.demonTrooper(c, u, bt, k, n, x, y, s, clock, light,
              fallen: t, fires: false, moving: false, engaged: false,
              opacity: fade, seed: seed);
        } else {
          _cell(c, row,
              t * GroundPace.anim < .35
                  ? GroundTroopsAtlas.fallCol
                  : GroundTroopsAtlas.rubbleCol,
              x, y, s, mirror: u.mirrored, light: light, opacity: fade, troop: true);
        }
        final ct = t * GroundPace.fx;
        if (ct < .5) {
          _cell(c, GroundTroopsAtlas.fxRow,
              GroundTroopsAtlas.crumbleCol +
                  (ct / .5 * GroundTroopsAtlas.crumbleFrames).floor().clamp(0, 2),
              x, y + s, s, light: _glow(light), emissive: true, troop: true);
        }
        continue;
      }
      final fires = u.fireFlash > 0 && k == u.id % math.max(1, alive);
      final int col;
      if (fires) {
        col = GroundTroopsAtlas.fireCol;
      } else if (engaged && !moving) {
        col = GroundTroopsAtlas.aimCol;
      } else if (moving) {
        final (rate, phase) = GroundSquadLook.gait(seed, k);
        col = GroundTroopsAtlas.walkCol +
            ((ac * 8 * rate + phase).floor() % GroundTroopsAtlas.walkFrames);
      } else {
        col = GroundTroopsAtlas.walkCol;
      }
      if (moving && k == 0) {
        final q = (clock * 1.8 * GroundPace.fx + u.id * .13) % 1;
        final back = u.mirrored ? -1.0 : 1.0;
        _cell(c, GroundAtlas.fxRow,
            GroundAtlas.dustCol + (q * GroundAtlas.dustFrames).floor(),
            x - back * 6 * s, y - q * 2 * s, s * .4,
            light: light * .8, opacity: (1 - q) * .45);
      }
      if (bt != null) {
        blocks.demonTrooper(c, u, bt, k, n, x, y, s, clock, light,
            fires: fires, moving: moving, engaged: engaged, seed: seed);
      } else {
        _cell(c, row, col, x, y, s,
            mirror: u.mirrored, light: light, troop: true, reveal: true);
      }
    }
  }

  /// The demon heavy tank: treads, furnace vents, a recoiling cannon.
  void _tank(Canvas c, GroundUnit u, double clock, ArcadeModel m) {
    final s = drawScale(u), width = u.width * GroundSize.hostVehicle;
    final light = math.max(.62, depthLight(u.z));
    const row = GroundTroopsAtlas.demonTankRow;
    final mirror = u.mirrored;
    final bt = useBlocks ? blocks.unitTrack(u) : null;
    if (u.destroyed && bt != null) {
      _wreck(c, u, clock, mirror, light,
          (opacity) => blocks.hulk(c, u, bt, clock, light, opacity), bt);
      return;
    }
    if (u.destroyed) {
      _wreck(c, u, clock, mirror, light, (opacity) => _cell(c, row,
          GroundTroopsAtlas.tankWreckCol + ((clock * 8 * GroundPace.fx).floor() % 2), u.x, u.y,
          s, mirror: mirror, light: light, opacity: opacity, troop: true));
      return;
    }
    final moving = u.z > u.holdZ + 1 || u.vx.abs() > 2;
    final int col;
    if (u.fireFlash > .06) {
      col = GroundTroopsAtlas.tankFireCol;
    } else if (u.fireFlash > 0) {
      col = GroundTroopsAtlas.tankRecoilCol;
    } else {
      col = GroundTroopsAtlas.tankMoveCol +
          (moving
              ? (clock * 10 * GroundPace.anim * (u.pose?.hesitate ?? 1) +
                      u.id * .37)
                  .floor() %
                  GroundTroopsAtlas.tankMoveFrames
              : 0);
    }
    if (moving) {
      for (var k = 0; k < 2; k++) {
        final q = (clock * 1.6 * GroundPace.fx + k * .5 + u.id * .13) % 1;
        _cell(c, GroundAtlas.fxRow,
            GroundAtlas.dustCol + (q * GroundAtlas.dustFrames).floor(),
            u.x + (mirror ? 1 : -1) * width * (.3 + .1 * k), u.y - q * 3 * s,
            s * .6, light: light * .8, opacity: (1 - q) * .55);
      }
    }
    if (bt != null) {
      blocks.demonVehicle(c, u, bt, clock, light, _glow(light), m);
      return;
    }
    _cell(c, row, col, u.x, u.y, s,
        mirror: mirror, light: light, troop: true, reveal: true);
  }

  /// An allied squad: rifle or rocket troopers from behind, walking with the
  /// convoy (each on its own gait, place, drift and turn), kneeling to
  /// fire, running back to the escort slot to repair.
  void _allySquad(Canvas c, GroundAlly a, double clock) {
    final s = allyDrawScale(a) * allyTroopScale;
    final spread = a.scale * GroundSize.trooper;
    final light = depthLight(a.z);
    final row = a.force == GroundForce.rockets
        ? GroundTroopsAtlas.allyRocketRow
        : GroundTroopsAtlas.allyRifleRow;
    final n = allySquadSize(a);
    final moving = a.vz != 0 || a.vx.abs() > 3;
    final mirror = a.vx < -3;
    final kick = (a.recoil / GroundTuning.allyRecoil).clamp(0.0, 1.0);
    final bt = useBlocks ? blocks.allyTrack(a, 0) : null;
    if (bt != null) {
      final e = eggs;
      // A short dance for one in three saved squads (through the budget).
      blocks.observeSquad(bt, a.x, a.z,
          saved: a.saved,
          dances: () => e == null
              ? a.id % 3 == 0
              : _danceOk(a) &&
                  e.request(EasterEgg.dance,
                      key: a.id, band: EasterEggBudget.bandOf(a.x)));
      _danceTriggers(a, bt);
    }
    final ac = clock * GroundPace.anim;
    if (a.totalled || a.fallingBack) {
      // Retreat smoke over a squad that is pulling back.
      for (var k = 0; k < (a.totalled ? 4 : 2); k++) {
        final q = (clock * .9 * GroundPace.fx + k / 4 + a.id * .1) % 1;
        _cellC(c, GroundAtlas.fxRow,
            GroundAtlas.puffCol + (q * GroundAtlas.puffFrames).floor(),
            a.x + math.sin(q * 6 + k) * 3 * s, a.y - 10 * s - q * 24 * s,
            s * (.5 + q * .7), light: light, opacity: (1 - q * .8) * .5);
      }
    }
    final march = bt == null
        ? (moving ? 1.0 : 0.0)
        : blocks.marchOf(bt, moving || a.fallingBack || a.totalled);
    final heading = bt?.hull.signedAngle ?? 0.0;
    final seed = a.id * 31 + GroundSquadLook.allySalt;
    final place = [
      for (var k = 0; k < n; k++)
        GroundSquadLook.offset(seed, k, clock, heading: heading, march: march),
    ];
    final order = List.generate(n, (k) => k)
      ..sort((p, q) => place[p].$2.compareTo(place[q].$2));
    for (final k in order) {
      final (ox, oy) = place[k];
      final x = a.x + ox * spread * .9, y = a.y + oy * spread * .5;
      if (bt != null) {
        blocks.allyTrooper(c, a, bt, k, n, x, y, s, clock, light,
            moving: moving, kick: kick, seed: seed);
        continue;
      }
      final (rate, phase) = GroundSquadLook.gait(seed, k);
      final int col;
      if (a.totalled || a.fallingBack) {
        col = GroundTroopsAtlas.runCol +
            ((ac * 10 * rate + phase).floor() % GroundTroopsAtlas.runFrames);
      } else if (a.flash > 0 && k == a.id % n) {
        col = GroundTroopsAtlas.hitCol;
      } else if (kick > 0 && k == (a.id + (ac * 3).floor()) % n) {
        col = GroundTroopsAtlas.fireCol;
      } else if (a.underAttack && !moving) {
        col = GroundTroopsAtlas.aimCol;
      } else if (moving) {
        col = GroundTroopsAtlas.walkCol +
            ((ac * 8 * rate + phase).floor() % GroundTroopsAtlas.walkFrames);
      } else {
        col = GroundTroopsAtlas.walkCol;
      }
      _cell(c, row, col, x, y, s, mirror: mirror, light: light, troop: true);
    }
  }

  /// A small cyan IFF chevron over every allied unit (phone readability).
  void _iff(Canvas c, GroundAlly a, double height) {
    final unit = math.max(1.0, (a.scale * .75).roundToDouble());
    final top = (a.y - height - 2 * unit).roundToDouble();
    final color = _mint.withValues(alpha: .85);
    _px(c, a.x - unit * 1.5, top, unit, color);
    _px(c, a.x + unit * .5, top, unit, color);
    _px(c, a.x - unit / 2, top + unit, unit, color);
  }

  // ----------------------------------------------------------------- allies

  /// Presentation variant of an ally (two per sector), from its id.
  static int allyVariant(GroundAlly a) {
    final v = (a.id ~/ 2) % GroundAtlas.allyVariants;
    // --- ground war v4: a convoy vehicle never draws a squad row (squads
    // are their own force now).
    if (a.lx != null && a.force == GroundForce.vehicle) {
      final k = GroundAtlas.allyRow(a.sector, v) - 4;
      if (GroundAtlas.allyKind[k] == 1) return (v + 1) % GroundAtlas.allyVariants;
    }
    return v;
  }

  /// Turret frame (0 = straight up the plane .. 4 = side-on) and whether to
  /// mirror it (aiming left), toward the screen position of its foe.
  (int, bool) _aim(GroundAlly a, double clock) {
    final foe = a.attacker;
    if (foe == null || foe.destroyed && foe.wreckAge > 1.2) {
      // Idle scan: a slow look outward and back.
      final scan = math.sin(clock * .7 * GroundPace.anim + a.id * 1.7);
      return (scan > .55 ? 1 : 0, a.side == 0);
    }
    final dx = foe.x - a.x, dy = a.bodyY - foe.bodyY;
    final deg = math.atan2(dx.abs(), math.max(dy, 0.0)) * 180 / math.pi;
    return ((deg / 22.5).round().clamp(0, GroundAtlas.allyTurretFrames - 1), dx < 0);
  }

  /// Screen muzzle point of an ally's current turret frame.
  Offset _muzzle(GroundAlly a, int frame, bool mirror, double bob) {
    final k = GroundAtlas.allyRow(a.sector, allyVariant(a)) - 4;
    final (mx, my) = GroundAtlas.allyMuzzle[k][frame];
    final s = allyDrawScale(a);
    return Offset(a.x + (mirror ? -mx : mx) * s, a.y - my * s - bob);
  }

  void _ally(Canvas c, GroundAlly a, double clock) {
    if (a.y < GroundCamera.horizon + 2) return;
    _setFog(a.z, x: a.x, y: a.y);
    if (a.force != GroundForce.vehicle) {
      _allySquad(c, a, clock);
      if (!a.totalled) _iff(c, a, 18 * allyDrawScale(a) * allyTroopScale);
      return;
    }
    final s = allyDrawScale(a);
    final variant = allyVariant(a);
    final row = GroundAtlas.allyRow(a.sector, variant);
    final k = row - 4;
    final kind = GroundAtlas.allyKind[k];
    final light = depthLight(a.z);
    final hullMirror = a.side == 1;
    final bt = useBlocks && kind != 1 ? blocks.allyTrack(a, variant) : null;
    if (a.totalled) {
      _allyTotalled(c, a, clock, row, kind, light, bt);
      return;
    }
    if (a.lx != null) {
      _iff(c, a, ((bt?.cells.unit.size[bt.hull.index].$2 ??
                  GroundAtlas.allySize[k].$2) +
              2) *
          s);
    }
    // Treads and gait: the convoy always rolls with the player; faster while
    // advancing on a foe, backward while falling back to station.
    // --- terrain: slower treads uphill (the flyover's relief pose).
    final rate = (7 + math.min(10.0, a.vz.abs() * .05)) *
        (a.pose?.pace ?? 1) *
        (a.pose?.hesitate ?? 1) * // terrain-shadows: lurk
        GroundPace.anim;
    final dir = a.vz < 0 ? -1 : 1;
    final phase = ((clock * rate * dir + a.id * .37).floor() %
                GroundAtlas.allyMoveFrames +
            GroundAtlas.allyMoveFrames) %
        GroundAtlas.allyMoveFrames;
    final moving = a.vz != 0;
    // Dust from the tracks and wheels, trailing toward the camera.
    if (kind != 1 || moving) {
      // --- terrain: more dust while grinding up a slope.
      final strength = (moving ? .8 : .45) +
          (a.pose?.climb ?? 0).clamp(0.0, .5);
      final puffs = kind == 1 ? 1 : 3;
      for (var side = -1; side <= 1; side += 2) {
        for (var p = 0; p < puffs; p++) {
          final q = (clock * (moving ? 2.2 : 1.4) * GroundPace.fx + p / puffs + (side + 1) * .17 + a.id * .21) % 1;
          _cell(c, GroundAtlas.fxRow,
              GroundAtlas.dustCol + (q * GroundAtlas.dustFrames).floor(),
              a.x + side * (8.5 + q * 3) * s,
              a.y + q * 5 * s,
              s * (kind == 1 ? .4 : .62) * (moving ? 1.15 : .9),
              light: light * .85, opacity: (1 - q) * strength);
        }
      }
    }
    final kick = (a.recoil / .14).clamp(0.0, 1.0);
    if (bt != null) {
      if (bt.cells.hasArt) {
        if (a.saved && !bt.wasSaved && _danceOk(a) &&
            (eggs?.request(EasterEgg.dance,
                    key: a.id, band: EasterEggBudget.bandOf(a.x)) ??
                false)) {
          blocks.startFlourish(bt, 1.2 / GroundPace.egg);
        }
        bt.wasSaved = a.saved;
        _danceTriggers(a, bt);
      }
      blocks.convoy(c, a, bt, clock, light, _glow(light));
      final mz = blocks.muzzleOf(a);
      if (kick > 0 && mz != null) {
        _cellC(c, GroundAtlas.flameRow,
            GroundAtlas.muzzleCyanCol +
                ((1 - kick) * GroundAtlas.muzzleFrames).floor().clamp(0, 2),
            mz.dx, mz.dy, s * (kind == 2 ? .7 : .9),
            light: _glow(light), emissive: true);
      }
    } else if (kind == 1) {
      // Infantry: walk; kneel when engaged and holding; a volley on a shot.
      final int col;
      if (a.flash > 0) {
        col = GroundAtlas.allyHitCol;
      } else if (kick > 0) {
        col = GroundAtlas.squadFireCol + ((clock * 14 * GroundPace.anim).floor() % 2);
      } else if (a.underAttack && !moving) {
        col = GroundAtlas.squadKneelCol;
      } else {
        col = GroundAtlas.allyMoveCol + phase;
      }
      _cell(c, row, col, a.x, a.y, s, mirror: hullMirror, light: light);
    } else {
      final (frame, aimMirror) = _aim(a, clock);
      final bob = GroundAtlas.allyBob[k][phase] * s;
      _cell(c, row, a.flash > 0 ? GroundAtlas.allyHitCol : GroundAtlas.allyMoveCol + phase,
          a.x, a.y + (kick > .5 ? s * .5 : 0), s,
          mirror: hullMirror, light: light);
      // Recoil: the turret kicks back along its barrel, then settles.
      final ang = GroundAtlas.allyTurretAngles[frame] * math.pi / 180;
      final back = kick * 1.6 * s;
      final ox = -(aimMirror ? -1 : 1) * math.sin(ang) * back;
      final oy = math.cos(ang) * back;
      _cell(c, row, GroundAtlas.allyTurretCol + frame, a.x + ox, a.y - bob + oy, s,
          mirror: aimMirror, light: light);
      if (kick > 0) {
        final mz = _muzzle(a, frame, aimMirror, bob);
        _cellC(c, GroundAtlas.flameRow,
            GroundAtlas.muzzleCyanCol +
                ((1 - kick) * GroundAtlas.muzzleFrames).floor().clamp(0, 2),
            mz.dx + ox, mz.dy + oy, s * (kind == 2 ? .7 : .9),
            light: _glow(light), emissive: true);
      }
    }
    if (a.flash > 0) {
      final f = ((1 - a.flash / .15) * GroundAtlas.sparkFrames).floor().clamp(0, 2);
      _cellC(c, GroundAtlas.fxRow, GroundAtlas.sparkCol + f,
          a.x + ((a.id % 3) - 1) * 4 * s, a.y - 9 * s, s * .9, light: _glow(light), emissive: true);
    }
    if (a.underAttack && (a.attacker?.calledForHelp ?? false)) {
      // Distress beacon while calling for help (a breakthrough looms): a
      // blinking friendly cyan cross over the ally. Quiet skirmishes the
      // allies are winning show none.
      if ((clock * 3).floor().isEven) {
        final unit = math.max(1.0, (s * .9).roundToDouble());
        final top = a.y - (GroundAtlas.allySize[k].$2 + 3) * s - 3 * unit;
        _px(c, a.x - unit / 2, top - unit, unit, _mint);
        _px(c, a.x - unit / 2, top + unit, unit, _mint);
        _px(c, a.x - unit * 1.5, top, unit, _mint);
        _px(c, a.x + unit * .5, top, unit, _mint);
        _px(c, a.x - unit / 2, top, unit, Colors.white);
      }
    }
  }

  /// Totalled, never killed: dented and sparking, a track thrown, it limps
  /// off under a column of retreat smoke; every other crew ejects in a pod.
  void _allyTotalled(Canvas c, GroundAlly a, double clock, int row, int kind,
      double light, [GroundBlockTrack? bt]) {
    final s = allyDrawScale(a), t = a.retreatAge;
    // Visual cycles at half speed (the limp itself is the simulation's).
    final ac = clock * GroundPace.anim, fc = clock * GroundPace.fx;
    final hop = ((ac * 9).floor().isEven ? 0.0 : -s).roundToDouble();
    final out = a.side == 0 ? -1.0 : 1.0; // it limps toward its screen edge
    // Retreat smoke: dark puffs from the engine deck, leaning away.
    for (var k = 0; k < 6; k++) {
      final q = (t * .9 * GroundPace.fx + k / 6) % 1;
      _cellC(c, GroundAtlas.fxRow,
          GroundAtlas.puffCol + (q * GroundAtlas.puffFrames).floor(),
          a.x - out * q * 9 * s + math.sin(q * 6 + k) * 2 * s,
          a.y - 11 * s - q * 30 * s, s * (.7 + q * .9),
          light: light, opacity: (1 - q * .8) * (kind == 1 ? .55 : .95));
    }
    if (bt != null) {
      blocks.totalled(c, a, bt, clock, light, _glow(light));
    } else {
      _cell(c, row, GroundAtlas.allyLimpCol + ((ac * 7).floor() % 2), a.x,
          a.y + hop, s, mirror: a.side == 1, light: light);
    }
    if (kind != 1) {
      if (bt == null) {
        _cell(c, row, GroundAtlas.allyTurretCol + 1, a.x, a.y + hop + s, s,
            mirror: a.side == 0, light: light * .75);
      }
      if (t < 1.4) {
        _cell(c, GroundAtlas.flameRow,
            GroundAtlas.flameCol + (fc * 12).floor() % GroundAtlas.flameFrames,
            a.x + out * 3 * s, a.y - 9 * s, s * .4 * (1 - t / 1.4) + s * .1,
            light: _glow(light), emissive: true);
      }
      if ((fc * 11).floor() % 3 == 0) {
        _cellC(c, GroundAtlas.fxRow,
            GroundAtlas.sparkCol + (fc * 20).floor() % GroundAtlas.sparkFrames,
            a.x + ((fc * 37).floor() % 5 - 2) * 2 * s, a.y - 10 * s, s * .8,
            light: _glow(light), emissive: true);
      }
    }
    if (a.ejects && t < 2.5 && kind != 1) {
      final (dx, dy) = a.podOffset;
      if (bt != null) {
        blocks.pod(c, a, bt, a.x + dx, a.bodyY + dy, clock);
      } else {
        _cell(c, row, GroundAtlas.allyPodCol, a.x + dx, a.bodyY + dy, s,
            mirror: a.side == 1);
      }
      _px(c, a.x + dx - 1, a.bodyY + dy + 1, 2, _cyan);
    }
  }

  // ---------------------------------------------------------------- tracers

  void _tracer(Canvas c, GroundTracer t, List<GroundAlly> allies) {
    if (t.kind != GroundTracer.bolt) return _weaponTracer(c, t);
    final p = (t.age / GroundTracer.life).clamp(0.0, 1.0);
    var from = Offset(t.fromX, t.fromY);
    final to = Offset(t.toX, t.toY);
    if (t.friendly) {
      // Leave from the shooter's muzzle when it is still there.
      for (final a in allies) {
        if (a.totalled || (a.x - t.fromX).abs() > 14 || (a.bodyY - t.fromY).abs() > 14) continue;
        if (GroundAtlas.allyKind[GroundAtlas.allyRow(a.sector, allyVariant(a)) - 4] == 1) break;
        // --- ground blocks runtime: the shown layer angle's muzzle.
        final bm = useBlocks ? blocks.muzzleOf(a) : null;
        if (bm != null) {
          from = bm;
          break;
        }
        final (frame, mirror) = _aim(a, 0);
        final k = GroundAtlas.allyRow(a.sector, allyVariant(a)) - 4;
        from = _muzzle(a, frame, mirror,
            GroundAtlas.allyBob[k][0] * allyDrawScale(a));
        break;
      }
    }
    final sFrom = _scaleAtY(from.dy), sTo = _scaleAtY(to.dy);
    final lFrom = _glow(depthLight(GroundCamera.zOf(math.max(from.dy, GroundCamera.horizon + 4))));
    final lTo = _glow(depthLight(GroundCamera.zOf(math.max(to.dy, GroundCamera.horizon + 4))));
    final hot = t.friendly ? _cyan : _hot;
    final body = t.friendly ? _mint : _warm;
    // The bolt: a bright head and a fading streak, thicker up close.
    final head = (p * 1.3).clamp(0.0, 1.0), tail = (head - .45).clamp(0.0, 1.0);
    if (p < .85) {
      const n = 10;
      for (var k = 0; k <= n; k++) {
        final q = tail + (head - tail) * k / n;
        final x = from.dx + (to.dx - from.dx) * q, y = from.dy + (to.dy - from.dy) * q;
        final sc = sFrom + (sTo - sFrom) * q;
        final w = math.max(1.0, (sc * (k == n ? 1.1 : .7)).roundToDouble());
        final a = (k / n);
        _px(c, x - w / 2, y - w / 2, w,
            k >= n - 1 ? Colors.white : (k > n * .6 ? hot : body).withValues(alpha: .25 + .75 * a));
      }
    }
    // Muzzle flash at the shooter, impact sparks at the target.
    if (p < .3) {
      _cellC(c, GroundAtlas.flameRow,
          (t.friendly ? GroundAtlas.muzzleCyanCol : GroundAtlas.muzzleWarmCol) +
              (p / .3 * GroundAtlas.muzzleFrames).floor().clamp(0, 2),
          from.dx, from.dy, sFrom * .75, light: lFrom);
    }
    if (p > .6) {
      _cellC(c, GroundAtlas.missileRow,
          (t.friendly ? GroundAtlas.impactCyanCol : GroundAtlas.impactWarmCol) +
              ((p - .6) / .4 * GroundAtlas.impactFrames).floor().clamp(0, 2),
          to.dx, to.dy, sTo * .9, light: lTo);
    }
  }

  /// Ground war v4 weapons: small-arms streaks, arcing rockets with smoke,
  /// fast tank shells; impact flashes at the target.
  void _weaponTracer(Canvas c, GroundTracer t) {
    final p = (t.age / t.duration).clamp(0.0, 1.0);
    final sFrom = _scaleAtY(t.fromY), sTo = _scaleAtY(t.toY);
    final hot = t.friendly ? _cyan : _hot;
    final body = t.friendly ? _mint : _warm;
    final lTo = _glow(depthLight(GroundCamera.zOf(math.max(t.toY, GroundCamera.horizon + 4))));
    Offset at(double q, double arc) => Offset(
          t.fromX + (t.toX - t.fromX) * q,
          t.fromY + (t.toY - t.fromY) * q - arc * math.sin(math.pi * q),
        );
    switch (t.kind) {
      case GroundTracer.smallArms:
        for (var k = 0; k < 3; k++) {
          final q = (p - k * .12).clamp(0.0, 1.0);
          final o = at(q, 0);
          final sc = sFrom + (sTo - sFrom) * q;
          final w = math.max(1.0, (sc * .5).roundToDouble());
          _px(c, o.dx - w / 2, o.dy - w / 2, w,
              (k == 0 ? Colors.white : body).withValues(alpha: 1 - k * .3));
        }
        if (p < .4) {
          _px(c, t.fromX - 1, t.fromY - 1, math.max(2.0, sFrom.roundToDouble()), hot);
        }
      case GroundTracer.rocket:
        final arc = 10 * (sFrom + sTo) / 2;
        for (var k = 5; k >= 1; k--) {
          final q = p - k * .07;
          if (q <= 0) continue;
          final o = at(q, arc);
          final sz = math.max(1.0, ((1.5 + k * .5) * (sFrom + (sTo - sFrom) * q) * .6).roundToDouble());
          _px(c, o.dx - sz / 2, o.dy - sz / 2, sz,
              const Color(0xFF7A808A).withValues(alpha: .7 - k * .1));
        }
        if (p < .92) {
          final o = at(p, arc);
          final sc = (sFrom + (sTo - sFrom) * p) * .55;
          _cellC(c, GroundTroopsAtlas.fxRow,
              (t.friendly ? GroundTroopsAtlas.rocketCyanCol : GroundTroopsAtlas.rocketWarmCol) +
                  ((t.age * 20).floor() % GroundTroopsAtlas.rocketFrames),
              o.dx, o.dy, sc, mirror: t.toX < t.fromX, troop: true);
        }
      case GroundTracer.shell:
        final head = (p * 1.6).clamp(0.0, 1.0), tail = (head - .35).clamp(0.0, 1.0);
        if (p < .7) {
          for (var k = 0; k <= 6; k++) {
            final q = tail + (head - tail) * k / 6;
            final o = at(q, 0);
            final sc = sFrom + (sTo - sFrom) * q;
            final w = math.max(1.0, (sc * (k == 6 ? 1.3 : .8)).roundToDouble());
            _px(c, o.dx - w / 2, o.dy - w / 2, w,
                k >= 5 ? Colors.white : hot.withValues(alpha: .3 + .1 * k));
          }
        }
    }
    if (p > .72) {
      _cellC(c, GroundAtlas.missileRow,
          (t.friendly ? GroundAtlas.impactCyanCol : GroundAtlas.impactWarmCol) +
              ((p - .72) / .28 * GroundAtlas.impactFrames).floor().clamp(0, 2),
          t.toX, t.toY, sTo * (t.kind == GroundTracer.smallArms ? .5 : 1.0),
          light: lTo);
    }
  }

  /// Things in the air above the combat layer.
  void paintAir(Canvas c, ArcadeModel m, ShipPainter ship) {
    final g = m.ground;
    final clock = m.visualClock;
    for (final p in g.pickups) {
      c.drawCircle(Offset(p.x, p.y), 13, Paint()..color = _mint.withValues(alpha: .14));
      ship.paintHomingBadge(c, Offset(p.x, p.y), 36);
    }
    for (final missile in g.missiles) {
      _groundMissile(c, missile, clock);
    }
    // Homing smoke: puffs laid along the flight, each sized by the
    // perspective where it was laid, so a dive into the ground plane leaves
    // a trail that narrows and fogs into the distance.
    for (final puff in [...g.homingSmoke, ...?g.homing?.trail]) {
      _homingPuff(c, puff);
    }
    final h = g.homing;
    if (h != null) {
      if (h.target != null) {
        final (tx, ty) = m.homingAim(h);
        final size = switch (h.target) {
          final GroundUnit u => (u.width / 30).clamp(.5, 1.4),
          final Demon d => d.isLarge ? 1.4 : .9,
          final Carrier _ => 1.2,
          _ => 1.0,
        };
        ship.paintReticle(c, Offset(tx, ty), clock, scale: size.toDouble());
      }
      // Exhaust flame right behind the warhead, scaled with perspective.
      final scale = h.perspective;
      final speed = math.max(1.0, math.sqrt(h.vx * h.vx + h.vy * h.vy));
      for (var k = 1; k <= 3; k++) {
        final px = math.max(1.0, ((k < 2 ? 3 : 2) * scale).roundToDouble());
        _px(c, h.x - h.vx / speed * k * 4 * scale - px / 2,
            h.y - h.vy / speed * k * 4 * scale - px / 2, px,
            (k == 1 ? _hot : _cyan).withValues(alpha: 1 - k * .22));
      }
      if (h.toGround) {
        // Fogged as it dives deep into the ground plane.
        final light = depthLight(h.depth);
        c.saveLayer(null, Paint()
          ..colorFilter = ColorFilter.mode(
              Color.fromARGB(255, (255 * light).round(), (255 * light).round(),
                  (255 * (light * .9 + .1)).round()),
              BlendMode.modulate));
        ship.paintHomingMissile(c, h, clock, scale: scale);
        c.restore();
      } else {
        ship.paintHomingMissile(c, h, clock);
      }
    }
  }

  void _homingPuff(Canvas c, HomingPuff puff) {
    final q = (puff.age / HomingPuff.life).clamp(0.0, 1.0);
    final size = math.max(1.0, ((3 + q * 5) * puff.size).roundToDouble());
    // Light where it was laid: far puffs sit in the haze.
    final far = (1 - puff.size).clamp(0.0, 1.0);
    final base = Color.lerp(const Color(0xFFDCE6F5), const Color(0xFF7A7290), q * .7 + far * .3)!;
    _px(c, puff.x - size / 2, puff.y - size / 2 - q * 3 * puff.size, size,
        base.withValues(alpha: (1 - q) * (.9 - far * .3)));
  }

  void _groundMissile(Canvas c, GroundMissile m, double clock) {
    final img = image;
    // Target marker: where the fixed path crosses the ship's plane.
    if (m.t > .25 && m.t < 1) {
      final on = (clock * (m.t > .7 ? 14 : 7)).floor().isEven;
      if (on) {
        final r = 6 + (1 - m.t) * 14;
        for (final sx in const [-1.0, 1.0]) {
          _px(c, m.targetX + sx * r - 1, ArcadeModel.shipY + 14, 2, _warm);
          _px(c, m.targetX + sx * (r - 3) - 1, ArcadeModel.shipY + 14, 2, _warm);
        }
      }
    }
    // Smoke trail: analytic, from earlier points on the same fixed path.
    for (var k = 6; k >= 1; k--) {
      final t = m.t - k * .055;
      if (t <= 0) continue;
      final x = m.xAt(t), y = m.yAt(t);
      final grow = GroundTuning.missileMinSize +
          (GroundTuning.missileMaxSize - GroundTuning.missileMinSize) * t * t;
      final scale = grow * .55 / 10;
      if (img != null) {
        _cell(c, GroundAtlas.missileRow, GroundAtlas.smokeCol + (k > 3 ? 2 : (k > 1 ? 1 : 0)),
            x, y + GroundAtlas.cellH * scale / 2, scale,
            opacity: (1 - k / 7) * .85);
      } else {
        _px(c, x - 2, y - 2, 4, const Color(0x887A7290));
      }
    }
    if (m.age < .16) {
      final s = GroundCamera.texel(GroundCamera.zOf(math.max(m.y0, GroundCamera.horizon + 20)));
      _cell(c, GroundAtlas.effectRow, GroundAtlas.launchFlashCol, m.x0,
          m.y0 + GroundAtlas.cellH * s * .6, s * 1.1);
    }
    // The warhead: one high-detail cell scaled with nearest-neighbour from
    // small at launch to full size at the ship.
    final scale = m.size / 22;
    final frame = (clock * 16).floor() % 2;
    if (img != null) {
      c.save();
      c.translate(m.x.roundToDouble(), m.y.roundToDouble());
      c.rotate((m.heading * .35 / (math.pi / 16)).round() * (math.pi / 16));
      _cell(c, GroundAtlas.missileRow, GroundAtlas.missileCol + frame, 0,
          GroundAtlas.cellH * scale / 2, scale);
      c.restore();
    } else {
      _block.color = _warm;
      c.drawCircle(Offset(m.x, m.y), m.size / 2, _block);
    }
  }
}
