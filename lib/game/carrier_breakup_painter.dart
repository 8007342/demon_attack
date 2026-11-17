import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import 'boss_atlas.dart';
import 'boss_director.dart';
import 'boss_painter.dart';
import 'carrier_breakup.dart';
import 'model.dart';

/// carrier-hatches Part B: a v2 carrier's art leaves between damage states
/// as components, never as a whole layer. At hull install the removable
/// texels of every transition are cut into components (design §B6, the
/// fallback until the bake's `comp` pass): each detachable module's layer
/// (its form change) and each layer's S0 → S2 difference (the shed). The
/// director says when a transition starts and finishes; this releases the
/// components on the rate rule, flies them (closed form, `v + ω × r`) and
/// draws them, attached ones riding the bend, in one `drawVertices` per
/// atlas page.
class CarrierBreakupPainter {
  /// Transitions of the resident hull: detach rank → pieces; −1 the shed.
  final Map<int, _Transition> _transitions = {};
  String? _key;
  bool _building = false;

  /// Whether the components of the resident hull are ready.
  bool get ready => _key != null && !_building;
  final math.Random _rng = math.Random(0xB5EA);
  final Map<int, ui.ImageShader> _shaders = {};
  final Paint _paint = Paint()..filterQuality = FilterQuality.low;
  Carrier? _carrier;

  /// Counters for the review sheet and tests.
  int lastVertices = 0, lastCalls = 0;

  /// Components of every transition, for tests and sheets.
  Iterable<BreakupComponent> get components sync* {
    for (final t in _transitions.values) {
      for (final p in t.pieces) {
        yield p.piece.component;
      }
    }
  }

  void reset() {
    for (final t in _transitions.values) {
      t.resetState();
    }
  }

  /// Cuts the resident hull's transitions (async; once per hull).
  Future<void> prepare(BossPainter armada) async {
    final h = armada.hero;
    final pages = armada.heroPages;
    if (h == null || pages == null || !armada.carrier) return;
    if (_key == h.key || _building) return;
    _building = true;
    try {
      _transitions.clear();
      _shaders.clear();
      final v = h.views[BossView.hero.storedTag];
      if (v == null) return;
      var id = 0;
      for (final m in h.modules) {
        final (list, flip) = _layers(v, m.id);
        if (list == null) continue;
        final s0 = list[0];
        if (s0 == null) continue;
        final px0 = await _pixels(pages[s0.page], s0);
        if (px0 == null) continue;
        // The form change: the whole module, cut into its components.
        final d = m.detach;
        if (d != null) {
          final mask = [
            for (var i = 3; i < px0.length; i += 4) px0[i] > 128 ? 1 : 0,
          ];
          final (cx, cy) = _centroid(mask, s0, flip);
          final pieces = extractComponents(
            removed: mask,
            w: s0.w,
            h: s0.h,
            ppu: s0.ppu,
            left: s0.dx,
            top: s0.dy,
            flip: flip,
            root: (cx, cy),
            cellUnits: _cellFor(mask, s0.ppu),
            idBase: id,
          );
          id += pieces.length;
          (_transitions[d] ??= _Transition()).add(s0, flip, pieces);
        }
        // The shed: what S0 has and S2 drops (plates and crystals).
        final s2 = list.length > 2 ? list[2] : null;
        if (s2 != null && d == null) {
          final px2 = await _pixels(pages[s2.page], s2);
          if (px2 == null) continue;
          final removed = List<int>.filled(s0.w * s0.h, 0);
          final kept = List<int>.filled(s0.w * s0.h, 0);
          for (var y = 0; y < s0.h; y++) {
            for (var x = 0; x < s0.w; x++) {
              final i = (y * s0.w + x) * 4;
              if (px0[i + 3] <= 128) continue;
              // The same hull point in the S2 layer.
              final ux = s0.dx + (x + .5) / s0.ppu;
              final uy = s0.dy + (y + .5) / s0.ppu;
              final x2 = ((ux - s2.dx) * s2.ppu).floor();
              final y2 = ((uy - s2.dy) * s2.ppu).floor();
              var gone = true;
              if (x2 >= 0 && y2 >= 0 && x2 < s2.w && y2 < s2.h) {
                final j = (y2 * s2.w + x2) * 4;
                final diff =
                    (px0[i] - px2[j]).abs() +
                    (px0[i + 1] - px2[j + 1]).abs() +
                    (px0[i + 2] - px2[j + 2]).abs();
                gone = px2[j + 3] <= 128 || diff > 150;
              }
              if (gone) {
                removed[y * s0.w + x] = 1;
              } else {
                kept[y * s0.w + x] = 1;
              }
            }
          }
          final pieces = extractComponents(
            removed: removed,
            kept: kept,
            w: s0.w,
            h: s0.h,
            ppu: s0.ppu,
            left: s0.dx,
            top: s0.dy,
            flip: flip,
            cellUnits: _cellFor(removed, s0.ppu),
            idBase: id,
          );
          id += pieces.length;
          (_transitions[-1] ??= _Transition()).add(s0, flip, pieces);
        }
      }
      // A transition never has more than 48 components: the extraction
      // caps each layer, the shed spans layers, so keep its largest 48.
      for (final t in _transitions.values) {
        t.cap(48);
      }
      _key = h.key;
    } finally {
      _building = false;
    }
  }

  /// Cell size (units) so a layer's removed area stays within about 700
  /// cells (the vertex budget, design §B7).
  static double _cellFor(List<int> mask, double ppu) {
    var n = 0;
    for (final v in mask) {
      n += v;
    }
    final area = n / (ppu * ppu); // square units
    var cell = 4.0;
    while (area / (cell * cell) > 700 && cell < 16) {
      cell += 2;
    }
    return cell;
  }

  static (double, double) _centroid(
    List<int> mask,
    BossHeroSprite s,
    bool flip,
  ) {
    var sx = 0.0, sy = 0.0, n = 0;
    for (var i = 0; i < mask.length; i++) {
      if (mask[i] == 0) continue;
      sx += i % s.w;
      sy += i ~/ s.w;
      n++;
    }
    if (n == 0) return (0, 0);
    final x = s.dx + sx / n / s.ppu, y = s.dy + sy / n / s.ppu;
    return (flip ? -x : x, y);
  }

  static (List<BossHeroSprite?>?, bool) _layers(BossHeroView v, String id) {
    var list = v.layers[id];
    var flip = false;
    if (list == null && id.endsWith('L')) {
      list = v.layers['${id.substring(0, id.length - 1)}R'];
      flip = true;
    }
    return (list, flip);
  }

  static Future<Uint8List?> _pixels(ui.Image page, BossHeroSprite s) async {
    final rec = ui.PictureRecorder();
    final c = Canvas(rec);
    c.drawImageRect(
      page,
      Rect.fromLTWH(
        s.x.toDouble(),
        s.y.toDouble(),
        s.w.toDouble(),
        s.h.toDouble(),
      ),
      Rect.fromLTWH(0, 0, s.w.toDouble(), s.h.toDouble()),
      Paint()..filterQuality = FilterQuality.none,
    );
    final pic = rec.endRecording();
    final img = await pic.toImage(s.w, s.h);
    pic.dispose();
    final data = await img.toByteData(format: ui.ImageByteFormat.rawRgba);
    img.dispose();
    return data?.buffer.asUint8List();
  }

  /// Starts and releases transitions from the director's signals; flies
  /// the released ones. [t]: the director's clock.
  void update(ArcadeModel m, BossDirector d, {bool reduced = false}) {
    final b = m.boss ?? m.wreckBoss;
    if (!identical(b, _carrier)) {
      _carrier = b;
      reset();
    }
    if (b == null) return;
    final t = d.clock;
    for (final e in d.breakStart.entries) {
      final tr = _transitions[e.key];
      if (tr == null) continue;
      tr.start(e.value, share: d.breakFinish.containsKey(e.key) ? 1 : .35);
      final fin = d.breakFinish[e.key];
      if (fin != null) tr.finish(fin);
    }
    final shed = _transitions[-1];
    final shedAt = d.shedStart;
    if (shed != null && shedAt != null) {
      shed.start(shedAt, share: 1, minSeconds: 2.5);
    }
    // The collapse: what is still attached goes in a 0.6 s burst.
    if (m.boss == null && m.wreckBoss != null) {
      for (final tr in _transitions.values) {
        if (tr.started) tr.finish(t, burst: .6);
      }
    }
    for (final tr in _transitions.values) {
      tr.step(t, b, _rng, reduced: reduced);
    }
  }

  /// Draws the attached and flying components ([bent]: the hull's bend,
  /// hull-local → bent hull-local).
  void paint(
    Canvas c,
    BossPainter armada,
    double t, {
    Offset Function(double x, double y)? bent,
  }) {
    final b = _carrier;
    final pages = armada.heroPages;
    lastVertices = 0;
    lastCalls = 0;
    if (b == null || pages == null) return;
    final byPage = <int, (List<double>, List<double>)>{};
    for (final tr in _transitions.values) {
      if (!tr.started) continue;
      tr.emit(t, b, bent, byPage);
    }
    for (final e in byPage.entries) {
      final (pos, tex) = e.value;
      if (pos.isEmpty) continue;
      final shader = _shaders[e.key] ??= ui.ImageShader(
        pages[e.key],
        TileMode.clamp,
        TileMode.clamp,
        Float64List.fromList([1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1]),
        filterQuality: FilterQuality.low,
      );
      final v = ui.Vertices.raw(
        ui.VertexMode.triangles,
        Float32List.fromList(pos),
        textureCoordinates: Float32List.fromList(tex),
      );
      _paint.shader = shader;
      c.drawVertices(v, BlendMode.srcOver, _paint);
      _paint.shader = null;
      v.dispose();
      lastVertices += pos.length ~/ 2;
      lastCalls++;
    }
  }
}

/// One cut piece in its layer: the sprite it is drawn from.
class _Placed {
  _Placed(this.sprite, this.flip, this.piece);
  final BossHeroSprite sprite;
  final bool flip;
  final BreakupPiece piece;
  int get cellPx => piece.cellPx;
  int get gw => piece.gridW;
}

class _Transition {
  final List<_Placed> pieces = [];
  bool started = false;
  final Map<int, double> _release = {};
  final Map<int, List<BreakupBody>> _bodies = {};
  final Set<int> _split = {};
  List<int> _order = const [];

  void add(BossHeroSprite s, bool flip, List<BreakupPiece> cut) {
    for (final p in cut) {
      pieces.add(_Placed(s, flip, p));
    }
  }

  void cap(int n) {
    if (pieces.length <= n) return;
    pieces.sort((a, b) => b.piece.cells.length.compareTo(a.piece.cells.length));
    pieces.removeRange(n, pieces.length);
  }

  void resetState() {
    started = false;
    _release.clear();
    _bodies.clear();
    _split.clear();
  }

  /// Starts at [t0]: [share] of the components scheduled now (outer
  /// first), the rest when [finish]ed.
  void start(double t0, {double share = .35, double minSeconds = 1.2}) {
    if (started) return;
    started = true;
    _order = breakupOrder([for (final p in pieces) p.piece.component]);
    final n = (pieces.length * share).ceil().clamp(0, pieces.length);
    final first = _order.take(n).toList();
    final times = breakupSchedule(
      [for (var i = 0; i < first.length; i++) i],
      seed: pieces.length * 31 + n,
      minSeconds: minSeconds,
    );
    for (final (k, i) in first.indexed) {
      _release[i] = t0 + times[k];
    }
  }

  /// The rest go from [t] on (over ≥ 1.6 s, or [burst] seconds at the
  /// collapse), on the rate rule.
  void finish(double t, {double? burst}) {
    final rest = [
      for (final i in _order)
        if (!_release.containsKey(i)) i,
    ];
    if (rest.isEmpty) return;
    final times = breakupSchedule(
      [for (var i = 0; i < rest.length; i++) i],
      seed: rest.length * 17,
      minSeconds: burst ?? 1.6,
    );
    final k = burst == null
        ? 1.0
        : math.min(1.0, burst / math.max(1e-6, times.reduce(math.max)));
    for (final (j, i) in rest.indexed) {
      _release[i] = t + times[j] * k;
    }
  }

  void step(double t, Carrier b, math.Random rng, {bool reduced = false}) {
    if (!started) return;
    for (final e in _release.entries) {
      if (t < e.value || _bodies.containsKey(e.key)) continue;
      final c = pieces[e.key].piece.component;
      _bodies[e.key] = [
        BreakupPhysics.release(
          c,
          t: t,
          wx: b.x + c.px,
          wy: b.y + c.py,
          hx: b.x,
          hy: b.y,
          hvx: b.horizontalVelocity,
          rng: rng,
          reduced: reduced,
        ),
      ];
    }
    for (final e in _bodies.entries) {
      final whole = e.value.first;
      if (_split.contains(e.key) || whole.split < 0) continue;
      if (t >= whole.t0 + whole.tearSeconds + whole.split) {
        _split.add(e.key);
        _bodies[e.key] = BreakupPhysics.fragments(
          whole,
          pieces[e.key].piece.component,
          rng: rng,
        );
      }
    }
  }

  /// Emits the triangles of every component: attached (on the bent hull)
  /// or flying (its body, or its fragments' bodies).
  void emit(
    double t,
    Carrier b,
    Offset Function(double x, double y)? bent,
    Map<int, (List<double>, List<double>)> out,
  ) {
    for (final (i, p) in pieces.indexed) {
      final bodies = _bodies[i];
      if (bodies != null && bodies.every((x) => x.done(t))) continue;
      final s = p.sprite;
      final (pos, tex) = out[s.page] ??= (<double>[], <double>[]);
      final c = p.piece.component;
      final unit = p.cellPx / s.ppu;
      for (final (k, j) in p.piece.cells.indexed) {
        final gx = j % p.gw, gy = j ~/ p.gw;
        // Texel rect of the cell (clamped to the sprite).
        final tx0 = s.x + gx * p.cellPx, ty0 = s.y + gy * p.cellPx;
        final tx1 = math.min(s.x + s.w, tx0 + p.cellPx).toDouble();
        final ty1 = math.min(s.y + s.h, ty0 + p.cellPx).toDouble();
        // Hull-local corners.
        final lx0 = s.dx + gx * unit, ly0 = s.dy + gy * unit;
        final lx1 = s.dx + (tx1 - s.x) / s.ppu,
            ly1 = s.dy + (ty1 - s.y) / s.ppu;
        final corners = [
          (p.flip ? -lx0 : lx0, ly0, tx0.toDouble(), ty0.toDouble()),
          (p.flip ? -lx1 : lx1, ly0, tx1, ty0.toDouble()),
          (p.flip ? -lx1 : lx1, ly1, tx1, ty1),
          (p.flip ? -lx0 : lx0, ly1, tx0.toDouble(), ty1),
        ];
        Offset place(double x, double y) {
          if (bodies == null) {
            final q = bent == null ? Offset(x, y) : bent(x, y);
            return Offset(b.x + q.dx, b.y + q.dy);
          }
          final body = bodies.length == 1
              ? bodies.first
              : bodies[p.piece.fragmentOf[k].clamp(0, bodies.length - 1)];
          if (t < body.t0) {
            return Offset(b.x + x, b.y + y);
          }
          final (bx, by, a, k0, alpha) = body.pose(t);
          // It shrinks away as it fades (no per-vertex alpha: the mesh
          // keeps the fast path).
          final sc = k0 * alpha;
          // The piece's frame: its pivot (or the fragment's own centre).
          final rx = (x - c.px - body.ox) * sc, ry = (y - c.py - body.oy) * sc;
          final ca = math.cos(a), sa = math.sin(a);
          return Offset(bx + rx * ca - ry * sa, by + rx * sa + ry * ca);
        }

        final q = [for (final (x, y, _, _) in corners) place(x, y)];
        for (final tri in const [
          [0, 1, 2],
          [0, 2, 3],
        ]) {
          for (final v in tri) {
            pos
              ..add(q[v].dx)
              ..add(q[v].dy);
            tex
              ..add(corners[v].$3)
              ..add(corners[v].$4);
          }
        }
      }
    }
  }
}
