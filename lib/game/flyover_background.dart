import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import 'flyover_atlas.dart';
import 'model.dart';

/// Oblique 3/4 flyover parallax drawn on top of a sector's painted sky.
///
/// Layers, back to front: mid ridges (0.2x), near terrain with route
/// landmarks (0.6x) and ground with props and creatures (1.0x).  Every layer
/// is an endless sequence of seamless, vertically tiling bank strips on both
/// arena edges; strip variants and sprite placement come from seeded,
/// stateless hashes of the tile/segment index, so any flight distance renders
/// identically on every device.  Creatures react to explosions, the falling
/// carrier wreck and the ship's shadow — visually only, reading model state.
class FlyoverBackground {
  /// `assets/images/flyover-<sector>.png`: rows mid/near/ground, columns
  /// [left variants..., mirrored right variants...].
  final List<ui.Image?> strips = List.filled(5, null);
  ui.Image? props, creatures;

  /// Arena units flown at ground speed.
  double distance = 0;
  double _clock = 0;

  /// Tests (and accessibility settings) can force reduced decorative motion.
  bool? reducedMotionOverride;
  bool get reducedMotion {
    final o = reducedMotionOverride;
    if (o != null) return o;
    final f = ui.PlatformDispatcher.instance.accessibilityFeatures;
    return f.disableAnimations || f.reduceMotion;
  }

  bool ready(int sector) =>
      strips[sector] != null && props != null && creatures != null;

  static const _px = 2.0; // arena units per logical pixel
  static const _tile = FlyoverAtlas.stripHeight * _px;
  static const _w = FlyoverAtlas.stripWidth;
  static const _h = FlyoverAtlas.stripHeight;
  static const baseSpeed = 26.0; // ground layer, arena units per second
  static const _landmarkSegment = 118.0;
  static const _propSegment = 120.0;
  static const _critterSegment = 70.0;

  final _seqCache = <int, List<int>>{};
  final _critters = <int, _Critter>{};
  final _seenBlasts = Expando<bool>();
  double _shipX = 180;
  bool _shadow = false;
  int _sector = 0, _route = 0;

  /// Advances flight and creature reactions.  Called from the scene update
  /// while unpaused; reads [model] but never writes to it.
  void advance(double dt, ArcadeModel model, double environment) {
    _sector = environment.round().clamp(0, 4);
    _route = model.cycle.clamp(0, 4);
    final mode = model.presentationMode;
    _shipX = model.shipX;
    _shadow = model.mode != RunMode.title &&
        (model.canPilot || mode == RunMode.levelClear || mode == RunMode.gameOver && model.defeatActive);
    if (reducedMotion) return;
    final p = model.transitionProgress;
    final factor = switch (mode) {
      RunMode.travel => 1 + 9 * math.sin(math.pi * p),
      RunMode.levelClear || RunMode.victory => 1 + 2.5 * p * p,
      RunMode.gameOver => .5,
      _ => 1.0,
    };
    distance += dt * baseSpeed * factor;
    _clock += dt;
    _react(dt, model);
  }

  // ---------------------------------------------------------------------
  // Deterministic sequencing helpers
  // ---------------------------------------------------------------------

  /// Seeded uniform value in [0, 1).  Intermediate values stay far below
  /// 2^53 so the VM and the web compute the same seed.
  static double _rand(int a, [int b = 0, int c = 0, int d = 0]) {
    const m = 1000003;
    var h = a % m;
    h = (h * 7919 + b % m) % m;
    h = (h * 104729 + c % m) % m;
    h = (h * 31337 + d % m) % m;
    return math.Random(h).nextDouble();
  }

  /// Strip variant for tile [k]; never repeats the previous tile's variant.
  int _variant(int sector, int layer, int side, int k) {
    final key = (sector * 8 + layer) * 2 + side;
    final seq = _seqCache.putIfAbsent(key, () => <int>[]);
    while (seq.length <= k) {
      final i = seq.length;
      final r = _rand(key, i, 17);
      seq.add(i == 0
          ? (r * 3).floor()
          : (seq[i - 1] + 1 + (r * 2).floor()) % FlyoverAtlas.variants);
    }
    return seq[k];
  }

  double _layerOffset(int layer, int side) =>
      distance * FlyoverAtlas.layerSpeeds[layer] +
      side * _tile * .37 +
      layer * _tile * .21;

  /// Bank edge in arena x (distance from the screen edge) for a world row.
  double _edgeAt(int sector, int layer, int side, double world) {
    final k = (world / _tile).floor();
    if (k < 0) return 0;
    final v = _variant(sector, layer, side, k);
    final row = (((k + 1) * _tile - world) / _px).floor().clamp(0, _h - 1);
    final edges = FlyoverAtlas.edges[sector][layer];
    if (v >= edges.length) return 0;
    return (edges[v].codeUnitAt(row) - 48) * _px;
  }

  // ---------------------------------------------------------------------
  // Painting
  // ---------------------------------------------------------------------

  final _pixelPaint = Paint()
    ..filterQuality = FilterQuality.none
    ..isAntiAlias = false;

  void paintLayers(Canvas c, int sector, int route) {
    final image = strips[sector];
    final sheet = props;
    final critterSheet = creatures;
    if (image == null || sheet == null || critterSheet == null) return;
    for (var layer = 0; layer < 3; layer++) {
      _paintStrips(c, image, sector, layer);
    }
    // Landmarks scroll with the near terrain (0.6x) but are tall: seen from
    // the oblique camera they rise over the narrow ground rim, which also
    // keeps each route's identity readable at phone size.
    _paintLandmarks(c, sheet, sector, route);
    _paintProps(c, sheet, sector);
    _paintCritters(c, critterSheet, sector);
  }

  void _paintStrips(Canvas c, ui.Image image, int sector, int layer) {
    final transforms = <RSTransform>[];
    final rects = <Rect>[];
    for (var side = 0; side < 2; side++) {
      final o = _layerOffset(layer, side);
      final first = (o / _tile).floor();
      final last = ((o + 520) / _tile).floor();
      for (var k = first; k <= last; k++) {
        final v = _variant(sector, layer, side, k);
        final top = (520 - ((k + 1) * _tile - o)).roundToDouble();
        final col = side == 0 ? v : FlyoverAtlas.variants + v;
        rects.add(Rect.fromLTWH(col * _w * 1.0, layer * _h * 1.0, _w * 1.0, _h * 1.0));
        transforms.add(RSTransform.fromComponents(
          rotation: 0,
          scale: _px,
          anchorX: 0,
          anchorY: 0,
          translateX: side == 0 ? 0 : 360 - _w * _px,
          translateY: top,
        ));
      }
    }
    c.drawAtlas(image, transforms, rects, null, null, null, _pixelPaint);
  }

  /// Screen y of a world position on a layer/side.
  double _screenY(int layer, int side, double world) =>
      520 - (world - _layerOffset(layer, side));

  void _paintLandmarks(Canvas c, ui.Image sheet, int sector, int route) {
    final first = ((_layerOffset(1, 0) - 140) / _landmarkSegment).floor();
    final last = ((_layerOffset(1, 1) + 520 + 140) / _landmarkSegment).floor();
    final pool = _spritesFor(sector, route);
    if (pool.isEmpty) return;
    final placed = <(double, RSTransform, Rect)>[];
    for (var j = math.max(0, first); j <= last; j++) {
      if (_rand(sector, route, j, 1) > .9) continue;
      // Alternate sides, with an occasional seeded swap.
      final side = (j + (_rand(sector, route, j, 2) < .25 ? 1 : 0)) % 2;
      // Rotate through the pool, starting at a seeded index, so neighbours
      // differ while the order still varies along the route.
      final idx = (j + (_rand(sector, route, j ~/ 5, 4) * pool.length).floor()) % pool.length;
      final s = pool[idx];
      final world = j * _landmarkSegment + _rand(sector, route, j, 5) * _landmarkSegment * .55;
      final y = _screenY(1, side, world).roundToDouble();
      if (y < -10 || y - s.h * _px > 530) continue;
      final edge = _edgeAt(sector, 1, side, world);
      final width = s.w * _px;
      final inset = edge - width * (.42 + _rand(sector, route, j, 6) * .25);
      final left = side == 0 ? inset.clamp(-width * .3, 120.0) : 360 - inset.clamp(-width * .3, 120.0) - width;
      placed.add((y, RSTransform.fromComponents(rotation: 0, scale: _px, anchorX: 0, anchorY: 0, translateX: left.roundToDouble(), translateY: y - s.h * _px), Rect.fromLTWH(s.x * 1.0, s.y * 1.0, s.w * 1.0, s.h * 1.0)));
    }
    _flush(c, sheet, placed);
  }

  void _paintProps(Canvas c, ui.Image sheet, int sector) {
    final pool = _spritesFor(sector, -1);
    if (pool.isEmpty) return;
    final placed = <(double, RSTransform, Rect)>[];
    for (var side = 0; side < 2; side++) {
      final o = _layerOffset(2, side);
      final first = ((o - 60) / _propSegment).floor();
      final last = ((o + 580) / _propSegment).floor();
      for (var j = math.max(0, first); j <= last; j++) {
        if (_rand(sector, side, j, 11) > .62) continue;
        final s = pool[(j + side + (_rand(sector, side, j, 12) * 2).floor()) % pool.length];
        final world = j * _propSegment + _rand(sector, side, j, 13) * _propSegment * .7;
        final y = _screenY(2, side, world).roundToDouble();
        final edge = _edgeAt(sector, 2, side, world);
        final width = s.w * _px;
        if (edge < width * .6) continue;
        final x = 2 + _rand(sector, side, j, 14) * math.max(0, edge - width - 4);
        final left = side == 0 ? x : 360 - x - width;
        placed.add((y, RSTransform.fromComponents(rotation: 0, scale: _px, anchorX: 0, anchorY: 0, translateX: left.roundToDouble(), translateY: y - s.h * _px), Rect.fromLTWH(s.x * 1.0, s.y * 1.0, s.w * 1.0, s.h * 1.0)));
      }
    }
    _flush(c, sheet, placed);
  }

  void _flush(Canvas c, ui.Image sheet, List<(double, RSTransform, Rect)> placed) {
    if (placed.isEmpty) return;
    placed.sort((a, b) => a.$1.compareTo(b.$1));
    c.drawAtlas(sheet, [for (final p in placed) p.$2], [for (final p in placed) p.$3], null, null, null, _pixelPaint);
  }

  final _spriteCache = <int, List<FlyoverSprite>>{};
  List<FlyoverSprite> _spritesFor(int sector, int route) =>
      _spriteCache.putIfAbsent(sector * 10 + route + 1, () => [
            for (final s in FlyoverAtlas.sprites)
              if (s.sector == sector && s.route == route) s,
          ]);

  final _speciesCache = <int, List<FlyoverCreature>>{};
  List<FlyoverCreature> _species(int sector) =>
      _speciesCache.putIfAbsent(sector, () => [
            for (final s in FlyoverAtlas.creatures)
              if (s.sector == sector) s,
          ]);

  // ---------------------------------------------------------------------
  // Creatures
  // ---------------------------------------------------------------------

  /// Creatures live on the ground banks.  Deeper sectors are busier.
  Iterable<_CritterView> _visibleCritters(int sector) sync* {
    final species = _species(sector);
    if (species.isEmpty) return;
    final density = .34 + sector * .07;
    for (var side = 0; side < 2; side++) {
      final o = _layerOffset(2, side);
      final first = ((o - 40) / _critterSegment).floor();
      final last = ((o + 560) / _critterSegment).floor();
      for (var j = math.max(0, first); j <= last; j++) {
        for (var i = 0; i < 2; i++) {
          if (_rand(sector, side * 997 + j, i, 21) > density) continue;
          final id = ((sector * 2 + side) * 100000 + j) * 2 + i;
          final kind = species[(_rand(sector, side, j * 2 + i, 22) * species.length).floor() % species.length];
          final baseWorld = j * _critterSegment + _rand(sector, side, j * 2 + i, 23) * _critterSegment;
          final state = _critters[id];
          // Patrol: walk, pause, walk back, pause — on a seeded heading.
          final period = 5 + _rand(id, 24) * 5;
          final reach = (kind.gait == 'crawl' ? 5 : 9) + _rand(id, 25) * 9;
          final heading = _rand(id, 26) * math.pi * 2;
          final u = ((_clock + _rand(id, 27) * period) / period) % 1;
          double travel;
          var moving = true;
          var dir = 1.0;
          if (u < .35) {
            travel = u / .35;
          } else if (u < .5) {
            travel = 1;
            moving = false;
          } else if (u < .85) {
            travel = 1 - (u - .5) / .35;
            dir = -1;
          } else {
            travel = 0;
            moving = false;
          }
          if (reducedMotion) {
            travel = 0;
            moving = false;
          }
          final world = baseWorld + math.sin(heading) * reach * travel - (state?.dy ?? 0);
          final edge = _edgeAt(sector, 2, side, world);
          final spriteW = (kind.w) * _px;
          if (edge < spriteW + 6) continue;
          var x = 3 + _rand(id, 28) * (edge - spriteW - 6) + math.cos(heading) * reach * travel + (state?.dx ?? 0);
          x = x.clamp(2.0, edge - spriteW - 2);
          final y = _screenY(2, side, world);
          if (y < -20 || y > 540) continue;
          final screenX = side == 0 ? x : 360 - x - spriteW;
          var facing = math.cos(heading) * dir * (side == 0 ? 1 : -1) >= 0;
          if (state != null && state.fleeT > 0) facing = state.fvx >= 0;
          yield _CritterView(id, kind, screenX, y, moving, facing);
        }
      }
    }
  }

  void _react(double dt, ArcadeModel model) {
    final impacts = <(Offset, double)>[];
    for (final b in model.blasts) {
      if (_seenBlasts[b] == true) continue;
      _seenBlasts[b] = true;
      if (b.age < 0) continue;
      impacts.add((Offset(b.x, b.y), b.big || b.isLarge ? 110 : 64));
    }
    // The defeated carrier's wreck falls toward the planet (same path the
    // scene draws); creatures under its landing zone scatter.
    final wreck = model.wreckBoss;
    if (model.presentationMode == RunMode.victory && wreck != null) {
      final p = model.transitionProgress;
      final fallY = wreck.y + p * p * 360;
      if (fallY > 300) impacts.add((Offset(wreck.x, fallY), 170));
    }
    final shadow = Offset(_shipX + 12, ArcadeModel.shipY + 24);
    final live = <int>{};
    for (final v in _visibleCritters(_sector)) {
      live.add(v.id);
      final s = _critters.putIfAbsent(v.id, _Critter.new);
      final center = Offset(v.x + v.kind.w, v.y - v.kind.h);
      for (final (at, radius) in impacts) {
        final away = center - at;
        final d = away.distance;
        if (d > radius) continue;
        if (v.kind.gait == 'burrow') {
          s.burrowT = math.max(s.burrowT, 2.6);
        } else {
          final n = d < 1 ? const Offset(1, 0) : away / d;
          s.fvx = n.dx;
          s.fvy = n.dy;
          s.fleeT = 1.1 + (1 - d / radius) * .6;
        }
      }
      final ds = center - shadow;
      if (_shadow && ds.dx.abs() < 34 && ds.dy.abs() < 26) s.duckT = .45;
      if (s.fleeT > 0) {
        s.fleeT -= dt;
        final speed = v.kind.gait == 'crawl' ? 28.0 : 52.0;
        // Banks are narrow: mostly run along the bank, away from the blast.
        s.dx += s.fvx * speed * dt * (v.x < 180 ? 1 : -1) * .6;
        s.dy += s.fvy * speed * dt;
      }
      if (s.duckT > 0) s.duckT -= dt;
      if (s.burrowT > 0) s.burrowT -= dt;
    }
    if (_critters.length > 400) {
      _critters.removeWhere((k, _) => !live.contains(k));
    }
  }

  void _paintCritters(Canvas c, ui.Image sheet, int sector) {
    final transforms = <RSTransform>[];
    final rects = <Rect>[];
    final colors = <Color>[];
    for (final v in _visibleCritters(sector)) {
      final s = _critters[v.id];
      int frame;
      if (s != null && s.burrowT > 0) {
        // Sink (6), hide (7), then re-emerge through the same frames.
        final t = 2.6 - s.burrowT;
        frame = t < .25 || s.burrowT < .25 ? 6 : 7;
      } else if (s != null && s.duckT > 0) {
        frame = s.duckT > .3 ? 4 : 5;
      } else if (s != null && s.fleeT > 0) {
        frame = (_clock * 14).floor() % 4;
      } else if (v.moving) {
        frame = (_clock * (v.kind.gait == 'crawl' ? 5 : 8)).floor() % 4;
      } else {
        frame = 0;
      }
      final col = frame + (v.facing ? 0 : v.kind.frames);
      rects.add(Rect.fromLTWH(col * v.kind.w * 1.0, v.kind.y * 1.0, v.kind.w * 1.0, v.kind.h * 1.0));
      transforms.add(RSTransform.fromComponents(
        rotation: 0,
        scale: _px,
        anchorX: 0,
        anchorY: 0,
        translateX: v.x.roundToDouble(),
        translateY: (v.y - v.kind.h * _px).roundToDouble(),
      ));
      colors.add(const Color(0xD8FFFFFF));
    }
    if (rects.isEmpty) return;
    c.drawAtlas(sheet, transforms, rects, colors, BlendMode.modulate, null, _pixelPaint);
  }

  /// Ship shadow cast on the ground layer, stepped in coarse pixels.  Drawn
  /// once over the blended worlds; creatures duck as it passes.
  void paintShadow(Canvas c) {
    if (!_shadow) return;
    final x = (_shipX + 12).roundToDouble();
    const y = ArcadeModel.shipY + 24;
    final p = Paint()
      ..color = const Color(0x55000000)
      ..isAntiAlias = false;
    c.drawRect(Rect.fromLTWH(x - 2, y - 8, 4, 16), p);
    c.drawRect(Rect.fromLTWH(x - 12, y, 24, 4), p);
    c.drawRect(Rect.fromLTWH(x - 6, y - 4, 12, 10), p);
  }

  /// Number of creature reaction states currently held (diagnostics/tests).
  int get reactingCreatures => _critters.values
      .where((s) => s.fleeT > 0 || s.duckT > 0 || s.burrowT > 0)
      .length;

  /// Screen centres of the creatures currently on screen (tests/tools).
  List<Offset> debugCreaturePositions(int sector) => [
        for (final v in _visibleCritters(sector))
          if (v.y > 0 && v.y < 520) Offset(v.x + v.kind.w, v.y - v.kind.h),
      ];

  /// The sector/route the reactions were last computed for.
  (int, int) get reactingWorld => (_sector, _route);
}

class _Critter {
  double dx = 0, dy = 0, fvx = 0, fvy = 0;
  double fleeT = 0, duckT = 0, burrowT = 0;
}

class _CritterView {
  _CritterView(this.id, this.kind, this.x, this.y, this.moving, this.facing);
  final int id;
  final FlyoverCreature kind;
  final double x, y;
  final bool moving, facing;
}
