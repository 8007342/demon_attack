import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'carrier_bend.dart';

/// carrier-render-engine §2: compose, then warp.
///
/// The hull's module layers are drawn once into ONE texture per pass
/// ([CarrierComposer.compose], a `PictureRecorder` → `toImageSync`), cached
/// until the damage state changes, and that texture is warped by ONE
/// continuous grid mesh ([CarrierWarpMesh]) whose vertices are shared by
/// every layer. Neighbouring layers can no longer drift apart: there is
/// only one surface, displaced by one smooth height field
/// ([CarrierHeightGrid]), which is the projection of a rigid rotation of a
/// height-field body (design §2.2).

/// One layer drawn into the composite: its page rect (pixels) and its
/// hull-local destination rect (units, before any flip).
class CarrierCompositeLayer {
  const CarrierCompositeLayer({
    required this.page,
    required this.src,
    required this.dst,
    this.flip = false,
    this.height = 0,
    this.stump = false,
  });
  final int page;
  final ui.Rect src, dst;
  final bool flip;
  final double height;

  /// A torn-away module the art still draws at this stage: charred.
  final bool stump;

  /// The destination rect in hull-local units after the flip.
  ui.Rect get placed =>
      flip ? ui.Rect.fromLTRB(-dst.right, dst.top, -dst.left, dst.bottom) : dst;
}

/// One composed texture: the hull-local rect it covers and its density.
class CarrierComposite {
  CarrierComposite(this.image, this.rect, this.ppu, this.key);
  final ui.Image image;
  final ui.Rect rect;
  final double ppu;
  final String key;
  ui.ImageShader? _shader;

  /// The texture as a bilinear shader (texture coordinates are image
  /// pixels: `(x − left)·ppu`).
  ui.ImageShader get shader => _shader ??= ui.ImageShader(
    image,
    ui.TileMode.clamp,
    ui.TileMode.clamp,
    _identity,
    filterQuality: ui.FilterQuality.low,
  );

  static final _identity = Float64List.fromList([
    1, 0, 0, 0, //
    0, 1, 0, 0,
    0, 0, 1, 0,
    0, 0, 0, 1,
  ]);

  /// Image bytes (RGBA8888) for the budget.
  int get bytes => image.width * image.height * 4;

  void dispose() {
    _shader?.dispose();
    _shader = null;
    image.dispose();
  }
}

/// Builds composites. Pure drawing: the caller owns the cache.
class CarrierComposer {
  /// The art's own density (the packed pages are 2 px per unit): composing
  /// at it resamples nothing.
  static const ppu = 2.0;

  static const _char = ui.Color(0xFF140A0C);

  /// Composes [layers] (in draw order) from [pages] over [rect] at [ppu].
  /// [char]: a warm char over the hull's own pixels (the wreck's last
  /// look); [feather]: dissolve the art over this many units at each edge
  /// of [rect] (the wreck's cut edges never read as straight lines).
  static CarrierComposite compose(
    List<CarrierCompositeLayer> layers,
    List<ui.Image> pages,
    ui.Rect rect, {
    required String key,
    double density = ppu,
    double char = 0,
    double feather = 0,
  }) {
    final w = (rect.width * density).ceil(), h = (rect.height * density).ceil();
    final rec = ui.PictureRecorder();
    final c = ui.Canvas(rec);
    c.scale(density);
    c.translate(-rect.left, -rect.top);
    final paint = ui.Paint()..filterQuality = ui.FilterQuality.low;
    final stump = ui.Paint()
      ..colorFilter = const ui.ColorFilter.mode(
        ui.Color(0xD8140A0C),
        ui.BlendMode.srcATop,
      );
    final full = rect.inflate(2);
    if (char > 0 || feather > 0) c.saveLayer(full, ui.Paint());
    for (final l in layers) {
      if (l.stump) c.saveLayer(full, stump);
      c.save();
      if (l.flip) c.scale(-1, 1);
      c.drawImageRect(pages[l.page], l.src, l.dst, paint);
      c.restore();
      if (l.stump) c.restore();
    }
    if (char > 0) {
      c.drawRect(
        full,
        ui.Paint()
          ..blendMode = ui.BlendMode.srcATop
          ..color = _char.withValues(alpha: char.clamp(0.0, 1.0)),
      );
    }
    if (feather > 0) {
      // dstOut ramps on the four edges: opaque art at the frame's edge is
      // a cut (the art stops there), so it dissolves instead.
      final f = feather;
      void ramp(ui.Rect r, ui.Offset a, ui.Offset b) {
        c.drawRect(
          r,
          ui.Paint()
            ..blendMode = ui.BlendMode.dstOut
            ..shader = ui.Gradient.linear(a, b, const [
              ui.Color(0xFF000000),
              ui.Color(0x00000000),
            ]),
        );
      }

      final l = rect.left, t = rect.top, r = rect.right, b = rect.bottom;
      ramp(
        ui.Rect.fromLTRB(l - 2, t - 2, l + f, b + 2),
        ui.Offset(l, 0),
        ui.Offset(l + f, 0),
      );
      ramp(
        ui.Rect.fromLTRB(r - f, t - 2, r + 2, b + 2),
        ui.Offset(r, 0),
        ui.Offset(r - f, 0),
      );
      ramp(
        ui.Rect.fromLTRB(l - 2, t - 2, r + 2, t + f),
        ui.Offset(0, t),
        ui.Offset(0, t + f),
      );
    }
    if (char > 0 || feather > 0) c.restore();
    final pic = rec.endRecording();
    final img = pic.toImageSync(w, h);
    pic.dispose();
    return CarrierComposite(img, rect, density, key);
  }
}

/// One smooth height field over the hull (units above the reference
/// plane), sampled at the mesh's nodes. From the re-render on it is the
/// merged per-layer height grids (spec: `carrier-render`); until then each
/// node takes the height of the topmost layer whose rect covers it, then
/// two box-blur passes, so the surface has no steps for the parallax to
/// tear along.
class CarrierHeightGrid {
  CarrierHeightGrid(this.left, this.top, this.step, this.nx, this.ny, this.h);
  final double left, top, step;
  final int nx, ny;
  final Float32List h;

  static CarrierHeightGrid fromLayers(
    ui.Rect rect,
    List<CarrierCompositeLayer> layers, {
    double step = 20,
    int blur = 2,
  }) {
    final nx = (rect.width / step).ceil() + 1;
    final ny = (rect.height / step).ceil() + 1;
    var h = Float32List(nx * ny);
    for (var j = 0; j < ny; j++) {
      for (var i = 0; i < nx; i++) {
        final x = rect.left + i * step, y = rect.top + j * step;
        var v = 0.0;
        for (final l in layers) {
          if (l.placed.contains(ui.Offset(x, y))) v = l.height;
        }
        h[j * nx + i] = v;
      }
    }
    for (var p = 0; p < blur; p++) {
      final o = Float32List(nx * ny);
      for (var j = 0; j < ny; j++) {
        for (var i = 0; i < nx; i++) {
          var s = 0.0, n = 0;
          for (var b = -1; b <= 1; b++) {
            for (var a = -1; a <= 1; a++) {
              final ii = i + a, jj = j + b;
              if (ii < 0 || jj < 0 || ii >= nx || jj >= ny) continue;
              s += h[jj * nx + ii];
              n++;
            }
          }
          o[j * nx + i] = s / n;
        }
      }
      h = o;
    }
    return CarrierHeightGrid(rect.left, rect.top, step, nx, ny, h);
  }

  /// Bilinear height at hull-local ([x], [y]); clamped at the edges.
  double at(double x, double y) {
    final fx = ((x - left) / step).clamp(0.0, nx - 1.001);
    final fy = ((y - top) / step).clamp(0.0, ny - 1.001);
    final i = fx.floor(), j = fy.floor();
    final u = fx - i, v = fy - j;
    double g(int a, int b) => h[b * nx + a];
    return (g(i, j) * (1 - u) + g(i + 1, j) * u) * (1 - v) +
        (g(i, j + 1) * (1 - u) + g(i + 1, j + 1) * u) * v;
  }
}

/// The one warp mesh of a composite: a grid of [step]-unit cells over the
/// composite's rect, keeping only the cells [keep] accepts (the hull's
/// footprint), with shared vertices (no seams can open) and texture
/// coordinates into the composite. Positions are rewritten only when the
/// bend moved more than 0.02° (carrier-v3 §2.4). No vertex colours.
class CarrierWarpMesh {
  CarrierWarpMesh(
    this.rect,
    this.ppu, {
    required this.heights,
    required bool Function(ui.Rect cell) keep,
    this.step = 20,
  }) {
    final nx = (rect.width / step).ceil(), ny = (rect.height / step).ceil();
    final index = Int32List((nx + 1) * (ny + 1))
      ..fillRange(0, (nx + 1) * (ny + 1), -1);
    final pos = <double>[], tex = <double>[], hs = <double>[];
    final idx = <int>[];
    int node(int i, int j) {
      final k = j * (nx + 1) + i;
      if (index[k] >= 0) return index[k];
      final x = math.min(rect.left + i * step, rect.right);
      final y = math.min(rect.top + j * step, rect.bottom);
      index[k] = pos.length ~/ 2;
      pos
        ..add(x)
        ..add(y);
      tex
        ..add((x - rect.left) * ppu)
        ..add((y - rect.top) * ppu);
      hs.add(heights.at(x, y));
      return index[k];
    }

    for (var j = 0; j < ny; j++) {
      for (var i = 0; i < nx; i++) {
        final cell = ui.Rect.fromLTWH(
          rect.left + i * step,
          rect.top + j * step,
          step,
          step,
        );
        if (!keep(cell)) continue;
        final a = node(i, j), b = node(i + 1, j);
        final c = node(i, j + 1), d = node(i + 1, j + 1);
        idx.addAll([a, b, c, b, d, c]);
      }
    }
    if (pos.length ~/ 2 > 65535) {
      throw StateError('carrier warp mesh exceeds 16-bit indices');
    }
    rest = Float32List.fromList(pos);
    positions = Float32List.fromList(pos);
    texture = Float32List.fromList(tex);
    this.hs = Float32List.fromList(hs);
    indices = Uint16List.fromList(idx);
  }

  final ui.Rect rect;
  final double ppu, step;
  final CarrierHeightGrid heights;
  late final Float32List rest, positions, texture, hs;
  late final Uint16List indices;
  ui.Vertices? _vertices;
  (double, double, double)? _built;

  int get vertexCount => rest.length ~/ 2;
  int get triangleCount => indices.length ~/ 3;

  /// Rewrites the positions for [bend] (null: rest).
  void rebuild(CarrierBend? bend) {
    final key = bend == null
        ? (0.0, 0.0, 0.0)
        : (bend.psi, bend.phi, bend.theta);
    final b = _built;
    const eps = .02 * CarrierBend.deg;
    if (b != null &&
        (key.$1 - b.$1).abs() < eps &&
        (key.$2 - b.$2).abs() < eps &&
        (key.$3 - b.$3).abs() < eps) {
      return;
    }
    _built = key;
    final n = vertexCount;
    for (var i = 0; i < n; i++) {
      final x = rest[2 * i], y = rest[2 * i + 1];
      if (bend == null) {
        positions[2 * i] = x;
        positions[2 * i + 1] = y;
        continue;
      }
      final (dx, dy) = CarrierBend.displacement(
        x,
        y,
        hs[i],
        key.$1,
        key.$2,
        key.$3,
      );
      positions[2 * i] = x + dx;
      positions[2 * i + 1] = y + dy;
    }
    _vertices?.dispose();
    _vertices = null;
  }

  ui.Vertices get vertices => _vertices ??= ui.Vertices.raw(
    ui.VertexMode.triangles,
    positions,
    textureCoordinates: texture,
    indices: indices,
  );

  void dispose() {
    _vertices?.dispose();
    _vertices = null;
  }
}
