import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'boss_atlas.dart';
import 'carrier_compose.dart';
import 'carrier_field.dart';
import 'carrier_wreck.dart';

/// carrier-v3-render: a hull's baked data page ([BossHeroData], its own
/// small PNG), decoded once when the hull is installed. It feeds the
/// rendering engine's interfaces (carrier-render-engine design §5):
/// - [heights]: the per-instance height grids merged by the topmost
///   (largest) height per 20-unit node, then one 3 × 3 blur (§5.2);
/// - [field]: the signed distance to the S0 silhouette (§5.6);
/// - [chunkAt] / [chunkSeeds]: the fracture chunks and their sections
///   (§5.4).
/// Everything here is data; the engine's code decides how it is drawn.
class CarrierRenderData {
  CarrierRenderData._(this.data, this._rgba);

  final BossHeroData data;
  final Uint8List _rgba;

  /// Decodes [page] (the data page image of [data]). Null when the page
  /// cannot be read back.
  static Future<CarrierRenderData?> decode(
    BossHeroData data,
    ui.Image page,
  ) async {
    final bytes = await page.toByteData(
      format: ui.ImageByteFormat.rawStraightRgba,
    );
    if (bytes == null) return null;
    return fromRgba(data, bytes.buffer.asUint8List());
  }

  /// From the page's straight RGBA bytes ([data].w × [data].h).
  static CarrierRenderData fromRgba(BossHeroData data, Uint8List rgba) =>
      CarrierRenderData._(data, rgba);

  int _px(int x, int y, int c) => _rgba[(y * data.w + x) * 4 + c];

  /// The baked height of instance [id] at its grid node (i, j), or null
  /// where the instance has no surface.
  double? _node(BossHeroGrid g, int i, int j) {
    final v = _px(g.x + i, g.y + j, 0) * 256 + _px(g.x + i, g.y + j, 1);
    return v == 0 ? null : (v - 32768).toDouble();
  }

  /// The height field over [rect] (the hull frame), at the grids' 20-unit
  /// step: per node the largest baked height of any instance covering it
  /// (the topmost surface the camera sees), 0 where none does, then one
  /// 3 × 3 box blur (design §2.4, "after the re-render").
  CarrierHeightGrid heights(ui.Rect rect, {Set<String>? only}) {
    final step = data.step;
    final nx = (rect.width / step).ceil() + 1;
    final ny = (rect.height / step).ceil() + 1;
    var h = Float32List(nx * ny);
    for (final e in data.heights.entries) {
      if (only != null && !only.contains(e.key)) continue;
      final g = e.value;
      for (var j = 0; j < ny; j++) {
        for (var i = 0; i < nx; i++) {
          final x = rect.left + i * step, y = rect.top + j * step;
          final fi = ((x - g.left) / step).round(),
              fj = ((y - g.top) / step).round();
          if (fi < 0 || fj < 0 || fi >= g.w || fj >= g.h) continue;
          final v = _node(g, fi, fj);
          if (v != null && v > h[j * nx + i]) h[j * nx + i] = v;
        }
      }
    }
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
    return CarrierHeightGrid(rect.left, rect.top, step, nx, ny, h);
  }

  /// The field's signed distance map (units, outside positive), decoded
  /// from the field texture's R channel.
  CarrierFieldMap field() {
    final f = data.field;
    final d = Float32List(f.w * f.h);
    for (var j = 0; j < f.h; j++) {
      for (var i = 0; i < f.w; i++) {
        d[j * f.w + i] =
            (_px(f.x + i, f.y + j, 0) - 128) * data.fieldRange / 127;
      }
    }
    return CarrierFieldMap.fromDistance(
      d,
      f.w,
      f.h,
      left: f.left,
      top: f.top,
      ppu: data.fieldPpu,
    );
  }

  /// The fracture chunk (0-based index into [chunkSeeds]) at hull-local
  /// ([x], [y]), or −1 outside the S0 silhouette or without chunks.
  int chunkAt(double x, double y) {
    final g = data.chunks;
    if (g == null) return -1;
    final i = ((x - g.left) * data.fieldPpu).floor();
    final j = ((y - g.top) * data.fieldPpu).floor();
    if (i < 0 || j < 0 || i >= g.w || j >= g.h) return -1;
    final id = _px(g.x + i, g.y + j, 2);
    return id == 0 || id > data.chunkCentres.length ? -1 : id - 1;
  }

  /// The chunks as fracture seeds (centre and section).
  List<FractureSeed> get chunkSeeds => [
    for (final c in data.chunkCentres) (c.$1, c.$2, c.$4),
  ];

  /// The nearest chunk to ([x], [y]) (for a triangle just outside the
  /// silhouette, e.g. in the under-painted margin).
  int nearestChunk(double x, double y) {
    var best = -1;
    var bd = double.infinity;
    for (final (k, c) in data.chunkCentres.indexed) {
      final d = math.pow(c.$1 - x, 2) + math.pow(c.$2 - y, 2);
      if (d < bd) {
        bd = d.toDouble();
        best = k;
      }
    }
    return best;
  }
}
