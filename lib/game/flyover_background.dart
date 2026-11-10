import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import 'flyover_atlas.dart';
import 'model.dart';
import 'terrain_field.dart';
import 'vegetation_atlas.dart';

/// Oblique 3/4 flyover with a horizon.
///
/// The upper third is the sector's painted sky (planets, moons, its painted
/// horizon), baked once per sector into an image.  Below the horizon line a
/// receding ground plane is drawn in one call with a perspective image
/// shader; everything standing on it (far ridges at 0.2x, slim broken side
/// walls, route landmarks, props and creatures) uses the same camera, so
/// objects emerge small near the horizon and grow and speed up as they
/// approach the ship.  Rows darken toward the horizon.
///
/// Every placement comes from stateless seeded hashes of world segments, so
/// any flight distance renders identically on every device.  Creatures react
/// to explosions, the falling carrier wreck and the ship's shadow — visually
/// only, reading model state.
class FlyoverBackground {
  /// `assets/images/flyover-<sector>.png`: rows mid (ridges) and wall,
  /// columns [left variants..., mirrored right variants...].
  final List<ui.Image?> strips = List.filled(5, null);

  /// `assets/images/flyover-<sector>-ground.png`: 2-D seamless ground tile.
  final List<ui.Image?> planes = List.filled(5, null);
  ui.Image? props, creatures;

  /// `assets/images/flyover-vegetation.png` (optional): plants and debris
  /// the ground fleet pushes through.
  ui.Image? vegetationSheet;

  /// The relief under the camera (surface, navigation, vegetation queries),
  /// shared with the ground war as its [GroundRelief].
  final TerrainView terrain = TerrainView();

  /// Rate-limited terrain radio events for the comms.
  final TerrainRadio radio = TerrainRadio();

  /// The relief, synced to the current flight distance.
  TerrainView get relief => terrain..cam = _cam;

  /// Sets the world(s) on screen: [sector]/[route], blending toward [far].
  void prepare(int sector, int route, {int? far, double blend = 0}) =>
      terrain.configure(sector, route, far: far, mix: blend);

  /// Arena units flown, measured at the bottom of the screen.
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
      strips[sector] != null &&
      planes[sector] != null &&
      props != null &&
      creatures != null;

  // ---------------------------------------------------------------------
  // Camera.  World units are ground texels; z is forward distance from the
  // camera.  The bottom row (y = 520) sees z = z0, where one texel is two
  // arena units (the game's pixel size); the horizon is y = horizon.
  // ---------------------------------------------------------------------

  static const horizon = 172.0;
  static const _g = 520 - horizon;
  static const _z0 = _g / 2;
  static const _zFar = 14 * _z0;
  static const _w = FlyoverAtlas.stripWidth;
  static const _h = FlyoverAtlas.stripHeight;
  static const _tile = _h * 1.0;
  static const baseSpeed = 26.0; // arena units/s at the bottom of the screen
  /// Outer edge of the central firing lane; nothing living may cross it.
  static const laneLeft = 96.0, laneRight = 264.0;

  double get _cam => distance / 2;
  static double _yOf(double z) => horizon + _g * _z0 / z;
  static double _zOf(double y) => _g * _z0 / (y - horizon);
  static double _scaleOf(double z) => _z0 / z;

  /// Distance fog: 1 near the ship, 0 at the horizon.
  static double _fog(double z) =>
      ((_zFar - z) / (_zFar - 2.2 * _z0)).clamp(0.0, 1.0);

  final _seqCache = <int, List<int>>{};
  final _critters = <int, _Critter>{};
  final _seenBlasts = Expando<bool>();
  double _shipX = 180;
  bool _shadow = false;
  int _sector = 0;

  /// Advances flight and creature reactions.  Called from the scene update
  /// while unpaused; reads [model] but never writes to it.
  void advance(double dt, ArcadeModel model, double environment) {
    _sector = environment.round().clamp(0, 4);
    final near = environment.floor().clamp(0, 4);
    prepare(near, model.cycle.clamp(0, 4),
        far: math.min(4, near + 1), blend: environment - near);
    // --- terrain: ground units ride the relief (visual and positional only).
    model.ground.relief = relief;
    final mode = model.presentationMode;
    _shipX = model.shipX;
    _shadow = model.mode != RunMode.title &&
        (model.canPilot ||
            mode == RunMode.levelClear ||
            mode == RunMode.gameOver && model.defeatActive);
    _pushVegetation(dt, model);
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
    _moveParticles(dt);
  }

  // ---------------------------------------------------------------------
  // Deterministic sequencing helpers
  // ---------------------------------------------------------------------

  /// Seeded uniform value in [0, 1): Park–Miller steps whose products stay
  /// below 2^53, so the VM and the web agree, with no allocation.
  static double _rand(int a, [int b = 0, int c = 0, int d = 0]) {
    const m = 2147483647;
    var h = (a * 73 + 19) % m;
    h = (h * 48271 + b % 100003) % m;
    h = (h * 48271 + c % 100003) % m;
    h = (h * 48271 + d % 100003) % m;
    h = (h * 48271) % m;
    h = (h * 48271) % m;
    return h / m;
  }

  /// Strip variant for tile [k]; never repeats the previous tile's variant.
  int _variant(int sector, int layer, int side, int k) {
    if (k < 0) return 0;
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

  /// Wall inner edge (texels from the screen edge) at world row [w].
  double _wallEdge(int sector, int side, double w) {
    final k = (w / _tile).floor();
    if (k < 0) return 0;
    final v = _variant(sector, 1, side, k);
    final row = ((k + 1) * _tile - w).floor().clamp(0, _h - 1);
    final edges = FlyoverAtlas.edges[sector][1];
    if (v >= edges.length) return 0;
    return (edges[v].codeUnitAt(row) - 48).toDouble();
  }

  // ---------------------------------------------------------------------
  // Painting
  // ---------------------------------------------------------------------

  final _pixelPaint = Paint()
    ..filterQuality = FilterQuality.none
    ..isAntiAlias = false;

  final _skyBakes = List<ui.Image?>.filled(5, null);
  final _skySources = List<ui.Image?>.filled(5, null);
  static const _bakeScale = 3.0;
  static const _skyTop = -8.0, _skyBottom = horizon + 8;

  /// Sky + painted horizon + stars, baked once per sector at 3x arena
  /// resolution, so the far layer is a single image draw per frame.
  ui.Image _sky(int sector, ui.Image painting, Color tint) {
    final cached = _skyBakes[sector];
    if (cached != null && identical(_skySources[sector], painting)) {
      return cached;
    }
    final recorder = ui.PictureRecorder();
    final c = Canvas(recorder);
    c.scale(_bakeScale);
    c.translate(0, -_skyTop);
    c.drawRect(const Rect.fromLTWH(0, _skyTop, 360, _skyBottom - _skyTop),
        Paint()..color = const Color(0xFF070B16));
    // The painting keeps its width; its sky (planets, moons, nebulae) fills
    // the band above the horizon at the painting's own aspect ratio.
    final scale = 360 / painting.width;
    final skyRows = (_skyBottom - _skyTop) / scale;
    c.drawImageRect(
      painting,
      Rect.fromLTWH(0, 0, painting.width.toDouble(), skyRows),
      const Rect.fromLTWH(0, _skyTop, 360, _skyBottom - _skyTop),
      Paint()
        ..filterQuality = FilterQuality.medium
        ..colorFilter =
            const ColorFilter.mode(Color(0x70060914), BlendMode.srcATop),
    );
    // The painting's own horizon (its far ridges) sits on our horizon line.
    final bandTop = painting.height * .62, bandH = painting.height * .10;
    c.drawImageRect(
      painting,
      Rect.fromLTWH(0, bandTop, painting.width.toDouble(), bandH),
      Rect.fromLTWH(0, horizon + 6 - bandH * scale, 360, bandH * scale),
      Paint()
        ..filterQuality = FilterQuality.medium
        ..colorFilter =
            const ColorFilter.mode(Color(0x80060914), BlendMode.srcATop),
    );
    final random = math.Random(1982 + sector * 709);
    final star = Paint()..isAntiAlias = false;
    for (var i = 0; i < 46; i++) {
      final x = random.nextDouble() * 360;
      final y = random.nextDouble() * (horizon - 40);
      star.color = tint.withValues(alpha: .14 + .06 * (i % 3));
      c.drawRect(Rect.fromLTWH(x.floorToDouble(), y.floorToDouble(),
          i % 13 == 0 ? 2 : 1, 1), star);
    }
    final picture = recorder.endRecording();
    final image = picture.toImageSync(
        (360 * _bakeScale).round(), ((_skyBottom - _skyTop) * _bakeScale).round());
    picture.dispose();
    _skyBakes[sector]?.dispose();
    _skyBakes[sector] = image;
    _skySources[sector] = painting;
    return image;
  }

  /// Draws one complete world.  [opacity] < 1 is used for the travel
  /// crossfade, so no full-screen saveLayer is needed.
  void paintWorld(Canvas c, int sector, int route, ui.Image? painting,
      Color tint, double opacity) {
    final strip = strips[sector], plane = planes[sector];
    final sheet = props, critterSheet = creatures;
    if (strip == null || plane == null || sheet == null || critterSheet == null) {
      return;
    }
    final alpha = (opacity * 255).round().clamp(0, 255);
    // Far layer: baked sky with a slow ~0.02x sway.
    if (painting != null) {
      final sky = _sky(sector, painting, tint);
      final sway = reducedMotion ? 0.0 : 3 * math.sin(distance * .02 / 40);
      c.drawImageRect(
        sky,
        Rect.fromLTWH(0, 0, sky.width.toDouble(), sky.height.toDouble()),
        Rect.fromLTWH(0, _skyTop + sway, 360, _skyBottom - _skyTop),
        Paint()
          ..filterQuality = FilterQuality.none
          ..color = Color.fromARGB(alpha, 255, 255, 255),
      );
    }
    _paintGround(c, plane, sector, alpha);
    _paintRidges(c, strip, sector, alpha);
    _paintWalls(c, strip, sector, alpha);
    _paintSprites(c, sheet, sector, route, alpha);
    final veg = vegetationSheet;
    if (veg != null) _paintVegetation(c, veg, sector, route, alpha);
    _paintCritters(c, critterSheet, sector, alpha);
  }

  // Ground mesh buffers, reused every frame.
  static final _meshIndices = _buildIndices();
  final _meshPos = Float32List(TerrainView.columns * TerrainView.rows * 2);
  final _meshTex = Float32List(TerrainView.columns * TerrainView.rows * 2);
  final _meshCol = Int32List(TerrainView.columns * TerrainView.rows);

  static Uint16List _buildIndices() {
    const cols = TerrainView.columns;
    final rows = TerrainView.rows;
    final out = Uint16List((rows - 1) * (cols - 1) * 6);
    var k = 0;
    // Far rows first: nearer relief paints over what it hides.
    for (var i = rows - 2; i >= 0; i--) {
      for (var j = 0; j < cols - 1; j++) {
        final a = i * cols + j, b = a + 1, c = a + cols, d = c + 1;
        out[k++] = a;
        out[k++] = b;
        out[k++] = c;
        out[k++] = b;
        out[k++] = d;
        out[k++] = c;
      }
    }
    return out;
  }

  /// Distance fog on the ground (the old 110 px gradient): 0 clear, toward
  /// 0.85 at the horizon.
  static double _groundFog(double flatY) {
    final t = (flatY - horizon) / 110;
    if (t >= 1) return 0;
    if (t < .3) return .847 + (.439 - .847) * (t / .3).clamp(0.0, 1.0);
    return .439 * (1 - (t - .3) / .7);
  }

  /// The receding ground as one textured triangle mesh: rows at fixed
  /// depths, columns at fixed screen x, displaced by the relief, lit by the
  /// sector's sky and fogged with distance (vertex colours).
  void _paintGround(Canvas c, ui.Image plane, int sector, int alpha) {
    final t = relief..prepare();
    final n = plane.width.toDouble();
    final cam = _cam % n;
    const cols = TerrainView.columns;
    final rows = TerrainView.rows;
    final light = TerrainProfile.sectors[sector].lightColor;
    // Vertex light is scaled down and the baked tile brightened instead,
    // so lit slopes and high ground can brighten the tile while flat
    // ground stays at about 82% of it.
    const base = .82 / _groundGain;
    for (var i = 0; i < rows; i++) {
      final z = TerrainView.rowZ[i];
      final fog = 1 - _groundFog(TerrainView.rowFlatY[i]);
      final half = z / (2 * _z0);
      for (var j = 0; j < cols; j++) {
        final idx = i * cols + j;
        final x = j * TerrainView.columnStep;
        _meshPos[idx * 2] = x;
        _meshPos[idx * 2 + 1] = t.gridY[idx];
        _meshTex[idx * 2] = 96 + (x - 180) * half;
        _meshTex[idx * 2 + 1] = cam + z;
        final v = math.min(1.0, base * t.gridShade[idx]) * fog * 255;
        final r = (v * light.$1).round().clamp(0, 255);
        final g = (v * light.$2).round().clamp(0, 255);
        final b = (v * light.$3).round().clamp(0, 255);
        _meshCol[idx] = (alpha << 24) | (r << 16) | (g << 8) | b;
      }
    }
    final vertices = ui.Vertices.raw(
      VertexMode.triangles,
      _meshPos,
      textureCoordinates: _meshTex,
      colors: _meshCol,
      indices: _meshIndices,
    );
    c.drawVertices(
      vertices,
      BlendMode.modulate,
      _groundPaint(plane),
    );
    vertices.dispose();
  }

  static const _groundGain = 1.8;
  static const _gainFilter = ColorFilter.matrix(<double>[
    _groundGain, 0, 0, 0, 0, //
    0, _groundGain, 0, 0, 0, //
    0, 0, _groundGain, 0, 0, //
    0, 0, 0, 1, 0,
  ]);
  final _groundPaints = Expando<Paint>();

  /// The ground tile brightened by [_groundGain], baked once per tile (a
  /// colour filter on the mesh itself would cost a third of the frame).
  Paint _groundPaint(ui.Image plane) => _groundPaints[plane] ??= () {
        final recorder = ui.PictureRecorder();
        Canvas(recorder).drawImage(plane, Offset.zero,
            Paint()..colorFilter = _gainFilter);
        final picture = recorder.endRecording();
        final bright = picture.toImageSync(plane.width, plane.height);
        picture.dispose();
        return Paint()
          ..shader = ImageShader(bright, TileMode.repeated, TileMode.repeated,
              Matrix4.identity().storage,
              filterQuality: FilterQuality.none);
      }();

  /// Far ridges: rotated ridge strips standing on the ground near the
  /// horizon, approaching at 0.2x of the ground speed and handing over.
  void _paintRidges(Canvas c, ui.Image strip, int sector, int alpha) {
    const near = 6.5 * _z0, far = 13.0 * _z0, span = far - near;
    final width = FlyoverAtlas.layerWidths[0].toDouble();
    final transforms = <RSTransform>[];
    final rects = <Rect>[];
    final colors = <Color>[];
    final travel = _cam * .2;
    for (var i = 0; i < 3; i++) {
      final phase = travel + i * span / 3;
      final id = (phase / span).floor() * 3 + i;
      final z = far - phase % span;
      final scale = 2 * _scaleOf(z);
      // Fade in at the far end, out as the next band takes over.
      final fade = ((z - near) / (.6 * _z0)).clamp(0.0, 1.0) *
          ((far - z) / (.8 * _z0)).clamp(0.0, 1.0) *
          .55;
      if (fade <= .01) continue;
      final shade = (255 * fade).round();
      final base = _yOf(z).roundToDouble();
      final tileW = _h * scale;
      var x = -_rand(sector, id, 31) * tileW;
      var t = 0;
      while (x < 360) {
        final v = (_rand(sector, id, t, 32) * FlyoverAtlas.variants).floor();
        rects.add(Rect.fromLTWH(v * _w * 1.0, 0, width, _h * 1.0));
        transforms.add(RSTransform.fromComponents(
          rotation: -math.pi / 2,
          scale: scale,
          anchorX: 0,
          anchorY: 0,
          translateX: x,
          translateY: base,
        ));
        colors.add(Color.fromARGB(alpha, shade, shade, shade));
        x += tileW;
        t++;
      }
    }
    if (rects.isEmpty) return;
    c.drawAtlas(strip, transforms, rects, colors, BlendMode.modulate, null,
        _pixelPaint);
  }

  /// Slim broken side walls in perspective: one textured triangle mesh.
  void _paintWalls(Canvas c, ui.Image strip, int sector, int alpha) {
    final width = FlyoverAtlas.layerWidths[1].toDouble();
    final cam = _cam;
    final t = relief;
    // Screen rows: uniform steps plus every tile boundary, so no quad ever
    // spans two strip variants.
    final ys = <double>[];
    final yTop = _yOf(_zFar);
    for (var y = yTop; y < 520; y += 5) {
      ys.add(y);
    }
    ys.add(520);
    for (var k = ((cam + _z0) / _tile).ceil(); k * _tile < cam + _zFar; k++) {
      final y = _yOf(k * _tile - cam);
      if (y > yTop && y < 520) ys.add(y);
    }
    ys.sort();
    final pos = <double>[], tex = <double>[];
    final cols = <int>[];
    for (var side = 0; side < 2; side++) {
      for (var i = 0; i + 1 < ys.length; i++) {
        final ya = ys[i], yb = ys[i + 1];
        if (yb - ya < .01) continue;
        final za = _zOf(ya), zb = _zOf(yb);
        final wa = cam + za, wb = cam + zb;
        final k = (((wa + wb) / 2) / _tile).floor();
        final v = _variant(sector, 1, side, k);
        final ra = ((k + 1) * _tile - wa).clamp(0.0, _tile);
        final rb = ((k + 1) * _tile - wb).clamp(0.0, _tile);
        final row0 = _h * 1.0; // wall row in the atlas
        final xa = width * 2 * _scaleOf(za), xb = width * 2 * _scaleOf(zb);
        // --- terrain: the rim rides the relief at its inner edge.
        final ga = t.yOf(side == 0 ? xa * .6 : 360 - xa * .6, za);
        final gb = t.yOf(side == 0 ? xb * .6 : 360 - xb * .6, zb);
        final fa = (255 * _fog(za)).round(), fb = (255 * _fog(zb)).round();
        final ca = (alpha << 24) | (fa << 16) | (fa << 8) | fa;
        final cb = (alpha << 24) | (fb << 16) | (fb << 8) | fb;
        double sx0a, sx1a, sx0b, sx1b, u0, u1;
        if (side == 0) {
          sx0a = 0;
          sx1a = xa;
          sx0b = 0;
          sx1b = xb;
          u0 = v * _w * 1.0;
          u1 = u0 + width;
        } else {
          sx0a = 360 - xa;
          sx1a = 360;
          sx0b = 360 - xb;
          sx1b = 360;
          u1 = (FlyoverAtlas.variants + v + 1) * _w * 1.0;
          u0 = u1 - width;
        }
        // Two triangles: (0a,1a,0b) and (1a,1b,0b).
        pos.addAll([sx0a, ga, sx1a, ga, sx0b, gb, sx1a, ga, sx1b, gb, sx0b, gb]);
        tex.addAll([
          u0, row0 + ra, u1, row0 + ra, u0, row0 + rb,
          u1, row0 + ra, u1, row0 + rb, u0, row0 + rb,
        ]);
        cols.addAll([ca, ca, cb, ca, cb, cb]);
      }
    }
    if (pos.isEmpty) return;
    final vertices = ui.Vertices.raw(
      VertexMode.triangles,
      Float32List.fromList(pos),
      textureCoordinates: Float32List.fromList(tex),
      colors: Int32List.fromList(cols),
    );
    c.drawVertices(
      vertices,
      BlendMode.modulate,
      Paint()
        ..shader = ImageShader(strip, TileMode.clamp, TileMode.clamp,
            Matrix4.identity().storage,
            filterQuality: FilterQuality.none),
    );
    vertices.dispose();
  }

  /// Route landmarks and ground props: emerge small at the horizon, grow
  /// and accelerate toward the ship; one sorted atlas draw.
  void _paintSprites(Canvas c, ui.Image sheet, int sector, int route, int alpha) {
    final cam = _cam;
    final t = relief;
    final placed = <(double, RSTransform, Rect, Color)>[];
    void put(FlyoverSprite s, double w, int side, double offset, double size) {
      final z = w - cam;
      if (z < _z0 * .55 || z > _zFar) return;
      final scale = 2 * _scaleOf(z) * size;
      final edge = _wallEdge(sector, side, w);
      final centre = (edge + offset) * 2 * _scaleOf(z);
      final width = s.w * scale;
      final left = side == 0 ? centre - width / 2 : 360 - centre - width / 2;
      // --- terrain: stands on the relief under its centre.
      final base = t.yOf(left + width / 2, z);
      if (base - s.h * scale > 520) return;
      final f = (255 * _fog(z)).round();
      placed.add((
        z,
        RSTransform.fromComponents(
            rotation: 0,
            scale: scale,
            anchorX: 0,
            anchorY: 0,
            translateX: left.roundToDouble(),
            translateY: (base - s.h * scale).roundToDouble()),
        Rect.fromLTWH(s.x * 1.0, s.y * 1.0, s.w * 1.0, s.h * 1.0),
        Color.fromARGB(alpha, f, f, f),
      ));
    }

    const segment = 120.0;
    final marks = _spritesFor(sector, route);
    if (marks.isNotEmpty) {
      for (var j = ((cam + _z0 * .5) / segment).floor();
          j * segment < cam + _zFar;
          j++) {
        if (j < 0 || _rand(sector, route, j, 1) > .9) continue;
        final side = (j + (_rand(sector, route, j, 2) < .25 ? 1 : 0)) % 2;
        final idx = (j + (_rand(sector, route, j ~/ 5, 4) * marks.length).floor()) %
            marks.length;
        put(marks[idx], j * segment + _rand(sector, route, j, 5) * segment * .5,
            side, 10 + _rand(sector, route, j, 6) * 6, 1.3);
      }
    }
    final pool = _spritesFor(sector, -1);
    if (pool.isNotEmpty) {
      const propSegment = 110.0;
      for (var side = 0; side < 2; side++) {
        for (var j = ((cam + _z0 * .5) / propSegment).floor();
            j * propSegment < cam + _zFar;
            j++) {
          if (j < 0 || _rand(sector, side, j, 11) > .55) continue;
          final s = pool[(j + side + (_rand(sector, side, j, 12) * 2).floor()) %
              pool.length];
          put(s, j * propSegment + _rand(sector, side, j, 13) * propSegment * .7,
              side, 4 + _rand(sector, side, j, 14) * 14, .9);
        }
      }
    }
    if (placed.isEmpty) return;
    placed.sort((a, b) => b.$1.compareTo(a.$1));
    c.drawAtlas(sheet, [for (final p in placed) p.$2],
        [for (final p in placed) p.$3], [for (final p in placed) p.$4],
        BlendMode.modulate, null, _pixelPaint);
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
  // Creatures: on the open ground between each wall and the central lane.
  // ---------------------------------------------------------------------

  static const _critterSegment = 64.0;

  Iterable<_CritterView> _visibleCritters(int sector) sync* {
    final species = _species(sector);
    if (species.isEmpty) return;
    final cam = _cam;
    final density = .32 + sector * .05;
    for (var side = 0; side < 2; side++) {
      for (var j = ((cam + _z0 * .7) / _critterSegment).floor();
          j * _critterSegment < cam + 6 * _z0;
          j++) {
        if (j < 0) continue;
        for (var i = 0; i < 2; i++) {
          if (_rand(sector, side * 997 + j, i, 21) > density) continue;
          final id = ((sector * 2 + side) * 1000000 + j) * 2 + i;
          final kind = species[(_rand(sector, side, j * 2 + i, 22) *
                      species.length)
                  .floor() %
              species.length];
          final state = _critters[id];
          // Patrol: walk, pause, walk back, pause.
          final period = 4 + _rand(id, 24) * 4;
          final reach = (kind.gait == 'crawl' ? 6 : 12) + _rand(id, 25) * 10;
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
          final w = j * _critterSegment +
              _rand(sector, side, j * 2 + i, 23) * _critterSegment +
              math.sin(heading) * reach * travel -
              (state?.dw ?? 0);
          final z = w - cam;
          if (z < _z0 * .8 || z > 6 * _z0) continue;
          final scale = 2 * _scaleOf(z);
          final spriteW = kind.w * scale;
          final wallX = (_wallEdge(sector, side, w) + 1) * scale;
          final room = math.max(0.0, laneLeft - spriteW - wallX);
          final across = (_rand(id, 28) +
                  math.cos(heading) * travel * .18 +
                  (state?.du ?? 0))
              .clamp(0.0, 1.0);
          // Never past the lane edge, even where the wall leaves no room
          // (the creature then stands in front of the wall).
          final inner = math.min(wallX + across * room, laneLeft - spriteW);
          if (inner < -spriteW * .3) continue;
          final x = side == 0 ? inner : 360 - inner - spriteW;
          var facing = math.cos(heading) * dir * (side == 0 ? 1 : -1) >= 0;
          if (state != null && state.fleeT > 0) facing = state.fvx >= 0;
          yield _CritterView(id, kind, x, relief.yOf(x + spriteW / 2, z), scale,
              z, moving, facing);
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
      impacts.add((Offset(b.x, b.y), b.big || b.isLarge ? 120 : 72));
    }
    // The defeated carrier's wreck falls toward the planet (same path the
    // scene draws); creatures under its landing zone scatter.
    final wreck = model.wreckBoss;
    if (model.presentationMode == RunMode.victory && wreck != null) {
      final p = model.transitionProgress;
      final fallY = wreck.y + p * p * 360;
      if (fallY > 300) impacts.add((Offset(wreck.x, fallY), 190));
    }
    final shadow = Offset(_shipX + 12, ArcadeModel.shipY + 24);
    final live = <int>{};
    for (final v in _visibleCritters(_sector)) {
      live.add(v.id);
      final s = _critters.putIfAbsent(v.id, _Critter.new);
      final center = Offset(v.x + v.kind.w * v.scale / 2, v.y - v.kind.h * v.scale / 2);
      for (final (at, radius) in impacts) {
        final away = center - at;
        final d = away.distance;
        if (d > radius) continue;
        if (v.kind.gait == 'burrow') {
          s.burrowT = math.max(s.burrowT, 2.6);
        } else {
          final n = d < 1 ? const Offset(1, 0) : away / d;
          s.fvx = n.dx.abs() < .2 ? (_rand(v.id, 29) < .5 ? -1 : 1) : n.dx.sign;
          s.fvy = n.dy.abs() < .3 ? (_rand(v.id, 30) < .5 ? -1 : 1) : n.dy.sign;
          s.fleeT = 1.2 + (1 - d / radius) * .6;
        }
      }
      final ds = center - shadow;
      if (_shadow && ds.dx.abs() < 40 && ds.dy.abs() < 30) s.duckT = .5;
      if (s.fleeT > 0) {
        s.fleeT -= dt;
        final fast = v.kind.gait == 'crawl' ? .55 : 1.0;
        // Sideways within the open band (screen fraction) and along the
        // ground (world texels): toward the camera when fleeing downward.
        final outward = v.x < 180 ? -1.0 : 1.0;
        s.du = (s.du + s.fvx * outward * -1.4 * fast * dt).clamp(-1.0, 1.0);
        s.dw += s.fvy * 70 * fast * dt;
      }
      if (s.duckT > 0) s.duckT -= dt;
      if (s.burrowT > 0) s.burrowT -= dt;
    }
    if (_critters.length > 400) {
      _critters.removeWhere((k, _) => !live.contains(k));
    }
  }

  void _paintCritters(Canvas c, ui.Image sheet, int sector, int alpha) {
    final views = _visibleCritters(sector).toList()
      ..sort((a, b) => b.z.compareTo(a.z));
    if (views.isEmpty) return;
    final transforms = <RSTransform>[];
    final rects = <Rect>[];
    final colors = <Color>[];
    for (final v in views) {
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
      rects.add(Rect.fromLTWH(col * v.kind.w * 1.0, v.kind.y * 1.0,
          v.kind.w * 1.0, v.kind.h * 1.0));
      transforms.add(RSTransform.fromComponents(
        rotation: 0,
        scale: v.scale,
        anchorX: 0,
        anchorY: 0,
        translateX: v.x.roundToDouble(),
        translateY: (v.y - v.kind.h * v.scale).roundToDouble(),
      ));
      final f = (235 * _fog(v.z)).round();
      colors.add(Color.fromARGB(alpha, f, f, f));
    }
    c.drawAtlas(sheet, transforms, rects, colors, BlendMode.modulate, null,
        _pixelPaint);
  }

  // ---------------------------------------------------------------------
  // Vegetation: pushed through by the ground units (visual only).
  // ---------------------------------------------------------------------

  final _particles = <VegetationParticle>[];

  /// Push timeline (seconds after contact) of the bend / break frames.
  static const _pushSteps = [.07, .16, .28, .4, .52];
  static const _pushCols = [
    VegetationAtlas.bendA,
    VegetationAtlas.bendB,
    VegetationAtlas.breakA,
    VegetationAtlas.breakB,
    VegetationAtlas.breakC,
  ];

  static int _particleKind(String kind) => switch (kind) {
        'tree' => 1,
        'crystal' => 2,
        'debris' => 3,
        'stalk' => 4,
        _ => 5,
      };

  /// Ground units (demon and allied) shove the plants in their path; allies
  /// tell the radio. Reads the model, never writes gameplay state.
  void _pushVegetation(double dt, ArcadeModel model) {
    final t = relief;
    final sector = model.level;
    final playing = model.combat && model.presentationMode != RunMode.travel;
    radio.clock += dt;
    if (playing) radio.lookAhead(t.primary, t.cam, sector);
    final g = model.ground;
    if (g.units.isEmpty && g.allies.isEmpty) return;
    final plants = t.vegetation(TerrainView.vegetationNear, 6 * _z0);
    void contact(int side, double x, double z, double width, {bool ally = false}) {
      final window = 10 + z * .03;
      for (final v in plants) {
        if (v.side != side || v.hitAt != null) continue;
        final vz = v.w - t.cam;
        if ((vz - z).abs() > window) continue;
        final vx = v.xAt(vz);
        final scale = 2 * _scaleOf(vz) * v.size;
        if ((vx - x).abs() > width * .45 + v.species.w * scale * .3) continue;
        v.hitAt = _clock;
        v.dir = vx >= x ? 1 : -1;
        final vy = t.yOf(vx, vz);
        if (ally && playing) radio.cleared(v, vx, vy, sector);
        if (reducedMotion) continue;
        final pk = _particleKind(v.species.kind);
        for (var k = 0; k < 7; k++) {
          final r1 = _rand(v.id, k, 61), r2 = _rand(v.id, k, 62);
          final kind = k < 3 ? 0 : pk;
          _particles.add(VegetationParticle(
            kind,
            vx + (r1 - .5) * 10 * scale,
            vy - (kind == 0 ? 2 : 6 + 10 * r2) * scale,
            (v.dir * (.3 + r1) * 30 + (r2 - .5) * 30) * scale,
            -(kind == 0 ? 10 + 14 * r2 : 22 + 30 * r2) * scale,
            scale * (kind == 0 ? 1.2 : 1),
            .55 + .4 * r2,
            r1,
          ));
        }
      }
    }

    for (final u in g.units) {
      if (u.alive) contact(u.side, u.x, u.z, u.width);
    }
    for (final a in g.allies) {
      if (!a.alive) continue;
      contact(a.side, a.x, a.z, a.width, ally: true);
      final pose = a.pose;
      if (playing && pose != null && a.z < GroundTuning.sightZ) {
        radio.ally(a.id, a.side, pose.climb, dt, a.x, a.y, sector);
      }
    }
    if (_particles.length > 160) _particles.removeRange(0, _particles.length - 160);
  }

  void _moveParticles(double dt) {
    for (final p in _particles) {
      p.age += dt;
      p.x += p.vx * dt;
      p.y += p.vy * dt + 70 * p.scale * p.age * dt;
    }
    _particles.removeWhere((p) => p.age >= p.life);
  }

  /// Number of plants currently pushed over (tests/tools).
  int get pushedVegetation =>
      relief.vegetation().where((v) => v.hitAt != null).length;

  /// Live burst particles (tests/tools).
  int get vegetationParticles => _particles.length;

  /// Screen rectangles of the plants on screen (tests/tools).
  List<Rect> debugVegetationRects() => [
        for (final v in relief.vegetation())
          () {
            final z = v.w - _cam;
            final scale = 2 * _scaleOf(z) * v.size;
            final x = v.xAt(z);
            final y = relief.yOf(x, z);
            return Rect.fromLTWH(x - VegetationAtlas.cellW * scale / 2,
                y - VegetationAtlas.cellH * scale, VegetationAtlas.cellW * scale,
                VegetationAtlas.cellH * scale);
          }(),
      ];

  void _paintVegetation(
      Canvas c, ui.Image sheet, int sector, int route, int alpha) {
    final t = relief;
    final field = t.field(sector, route);
    final plants = t.vegetationOf(field);
    if (plants.isEmpty && _particles.isEmpty) return;
    final transforms = <RSTransform>[];
    final rects = <Rect>[];
    final colors = <Color>[];
    const cw = VegetationAtlas.cellW * 1.0, ch = VegetationAtlas.cellH * 1.0;
    for (final v in plants) {
      final z = v.w - t.cam;
      final scale = 2 * _scaleOf(z) * v.size;
      var x = v.xAt(z);
      int col;
      final hit = v.hitAt;
      if (hit == null) {
        final sway = v.species.kind != 'debris' &&
            !reducedMotion &&
            ((_clock * .8 + _rand(v.id, 63)) % 2) >= 1;
        col = sway ? VegetationAtlas.idleB : VegetationAtlas.idleA;
      } else {
        final e = reducedMotion ? 99.0 : _clock - hit;
        col = VegetationAtlas.down;
        for (var k = 0; k < _pushSteps.length; k++) {
          if (e < _pushSteps[k]) {
            col = _pushCols[k];
            break;
          }
        }
        if (v.species.kind == 'debris') {
          // Shoved aside along the ground.
          final u = (e / .6).clamp(0.0, 1.0);
          x += v.dir * 9 * scale * (1 - (1 - u) * (1 - u));
        }
      }
      if (v.dir < 0) col += VegetationAtlas.frames;
      final base = t.yOf(x, z);
      if (base - ch * scale > 520 || base < horizon) continue;
      rects.add(Rect.fromLTWH(col * cw, v.species.row * ch, cw, ch));
      transforms.add(RSTransform.fromComponents(
        rotation: 0,
        scale: scale,
        anchorX: 0,
        anchorY: 0,
        translateX: (x - cw * scale / 2).roundToDouble(),
        translateY: (base - ch * scale).roundToDouble(),
      ));
      final f = (240 * _fog(z)).round();
      colors.add(Color.fromARGB(alpha, f, f, f));
    }
    if (sector == _sector) {
      const ps = VegetationAtlas.particleSize * 1.0;
      for (final p in _particles) {
        final frame = p.age / p.life > .5 ? 1 : 0;
        final col = p.kind * 2 + frame;
        rects.add(Rect.fromLTWH(
            col * cw, VegetationAtlas.particleRow * ch, ps, ps));
        transforms.add(RSTransform.fromComponents(
          rotation: 0,
          scale: p.scale,
          anchorX: ps / 2,
          anchorY: ps / 2,
          translateX: p.x.roundToDouble(),
          translateY: p.y.roundToDouble(),
        ));
        final fade = (1 - p.age / p.life).clamp(0.0, 1.0);
        colors.add(Color.fromARGB((alpha * (.4 + .6 * fade)).round(), 230, 230, 230));
      }
    }
    if (rects.isEmpty) return;
    c.drawAtlas(sheet, transforms, rects, colors, BlendMode.modulate, null,
        _pixelPaint);
  }

  /// Ship shadow cast on the ground, stepped in coarse pixels.  Creatures
  /// duck as it passes.
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

  /// Number of creature reaction states currently active (diagnostics/tests).
  int get reactingCreatures => _critters.values
      .where((s) => s.fleeT > 0 || s.duckT > 0 || s.burrowT > 0)
      .length;

  /// Screen centres of the creatures currently on screen (tests/tools).
  List<Offset> debugCreaturePositions(int sector) => [
        for (final v in _visibleCritters(sector))
          if (v.y > horizon && v.y < 520)
            Offset(v.x + v.kind.w * v.scale / 2, v.y - v.kind.h * v.scale / 2),
      ];

  /// Screen rectangles of the creatures currently on screen (tests/tools).
  List<Rect> debugCreatureRects(int sector) => [
        for (final v in _visibleCritters(sector))
          Rect.fromLTWH(v.x, v.y - v.kind.h * v.scale, v.kind.w * v.scale,
              v.kind.h * v.scale),
      ];
}

class _Critter {
  double du = 0, dw = 0, fvx = 0, fvy = 0;
  double fleeT = 0, duckT = 0, burrowT = 0;
}

class _CritterView {
  _CritterView(this.id, this.kind, this.x, this.y, this.scale, this.z,
      this.moving, this.facing);
  final int id;
  final FlyoverCreature kind;
  final double x, y, scale, z;
  final bool moving, facing;
}
