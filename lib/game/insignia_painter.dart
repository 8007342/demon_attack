import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/painting.dart';

import 'insignia_atlas.dart';
import 'model.dart';
import 'sprite_atlas.dart';

/// Glyph tone: the brood's bone brand, gold while angry, white in a tell.
enum InsigniaTone { bone, angry, tell }

/// A force-shield cell: lit, spent (a dark socket), breaking (white), or a
/// rush-shield cell (ember-tinted).
enum ShieldCell { lit, spent, flash, rush }

/// One overlay mark placed this frame, in arena units (screen space when
/// the arena camera maps positions; sizes never scale with it).
class InsigniaMark {
  InsigniaMark(this.key, this.rect, this.alpha, {this.rank, this.owner});
  final String key;
  final Rect rect;
  final double alpha;

  /// Rank glyphs take part in the overlap rule; cells do not.
  final AlienRank? rank;
  final Object? owner;
}

class _Pending {
  _Pending(this.key, this.anchor, this.alpha, this.size, this.rank, this.owner);
  final String key;
  final Offset anchor; // bottom-centre (glyphs) or centre (cells)
  final double alpha, size;
  final AlienRank? rank;
  final Object? owner;
}

/// The alien-insignia overlay (openspec/changes/alien-insignia, design §2;
/// docs/styleguide/alien-troops.md): rank glyphs above the heads and
/// force-shield cells, collected during the creature pass and drawn
/// together after the arena camera with one `drawAtlas`, at a fixed size.
class InsigniaPainter {
  /// One glyph px in arena units (≈ CSS px on a 360-wide arena): the old
  /// 32-grid pixel, so strokes are 2 glyph px ≈ 2.7 units.
  static const double unitsPerGlyphPx = 1.35;

  /// A skipped lower-rank glyph stays skipped this long (no flicker).
  static const double holdSeconds = .3;

  /// Rim colours (styleguide §3) and the frame's rim budget (design §2).
  static const Color rimEmber = Color(0xFFFF5A36);
  static const Color rimCyan = Color(0xFF62F0FF);
  static const double shieldRimAlpha = .6;
  static const int maxRims = 8;

  /// The dive tell flashes the glyph and rim white (5 Hz), steady white
  /// under reduced motion: the only animated insignia element.
  static bool tellOn(double clock, {bool reducedMotion = false}) =>
      reducedMotion || (clock * 10).floor().isEven;

  ui.Image? image;

  /// `drawAtlas` calls so far and the marks of the last frame (tests).
  int drawCalls = 0;
  List<InsigniaMark> lastMarks = const [];
  final List<_Pending> _glyphs = [];
  final List<_Pending> _cells = [];
  final _skipUntil = Expando<double>('insigniaSkip');

  /// Reveal gate (design §2): nothing in the fog wears a glyph.
  static double revealAlpha(double transmittance) =>
      Perspective.smoothstep(.6, .75, transmittance);

  static String glyphKey(AlienRank rank, InsigniaTone tone) =>
      '${switch (rank) {
        AlienRank.drone => '',
        // --- gargoyle-insignia: fangs and wings (styleguide §4).
        AlienRank.skirmisher => 'fang',
        AlienRank.veteran => 'fang2',
        AlienRank.hunter => 'wingfang',
        AlienRank.sentinel => 'wingcrown',
      }}/${tone.name}';

  /// The carrier's form ladder: fang, twin fangs, winged fang, winged crown.
  static AlienRank carrierRank(int form) => const [
    AlienRank.skirmisher,
    AlienRank.veteran,
    AlienRank.hunter,
    AlienRank.sentinel,
  ][form.clamp(0, 3)];

  static String cellKey(ShieldCell cell) => 'cell/${cell.name}';

  /// The drawn size of an atlas entry in arena units.
  static Size sizeOf(String key, [double size = 1]) {
    final r = InsigniaAtlas.rects[key]!;
    final k = unitsPerGlyphPx / InsigniaAtlas.devicePerGlyphPx * size;
    return Size(r.width * k, r.height * k);
  }

  void begin() {
    _glyphs.clear();
    _cells.clear();
  }

  /// A rank glyph with its bottom-centre at [anchor] (arena units, just
  /// above the head). Drones carry nothing.
  void rank(
    Object owner,
    AlienRank rank,
    Offset anchor, {
    InsigniaTone tone = InsigniaTone.bone,
    double alpha = 1,
    double size = 1,
  }) {
    if (rank == AlienRank.drone || alpha <= 0) return;
    _glyphs.add(
      _Pending(glyphKey(rank, tone), anchor, alpha, size, rank, owner),
    );
  }

  /// A force-shield cell centred at [centre].
  void cell(
    Offset centre,
    ShieldCell cell, {
    double alpha = 1,
    double size = 1,
  }) {
    if (alpha <= 0) return;
    _cells.add(_Pending(cellKey(cell), centre, alpha, size, null, null));
  }

  /// Places this frame's marks: positions through [toScreen] (the arena
  /// camera; identity until one exists), sizes fixed. Glyphs are tested in
  /// rank order; a lower-rank glyph that would overlap a placed one is
  /// skipped, and stays skipped for [holdSeconds] from [now].
  List<InsigniaMark> layout({
    double now = 0,
    Offset Function(Offset)? toScreen,
  }) {
    final map = toScreen ?? (Offset p) => p;
    final out = <InsigniaMark>[];
    final order = List.of(_glyphs)
      ..sort((a, b) => b.rank!.index.compareTo(a.rank!.index));
    final placed = <Rect>[];
    for (final g in order) {
      final s = sizeOf(g.key, g.size);
      final p = map(g.anchor);
      final rect = Rect.fromLTWH(
        p.dx - s.width / 2,
        p.dy - s.height,
        s.width,
        s.height,
      );
      final owner = g.owner;
      final held = owner == null ? null : _skipUntil[owner];
      if (held != null && now < held && now >= held - holdSeconds) continue;
      // Outlines may touch; the fills may not.
      final inner = rect.deflate(unitsPerGlyphPx * g.size);
      if (placed.any((r) => r.overlaps(inner))) {
        if (owner != null) _skipUntil[owner] = now + holdSeconds;
        continue;
      }
      placed.add(inner);
      out.add(InsigniaMark(g.key, rect, g.alpha, rank: g.rank, owner: owner));
    }
    for (final c in _cells) {
      final s = sizeOf(c.key, c.size);
      final p = map(c.anchor);
      out.add(
        InsigniaMark(
          c.key,
          Rect.fromCenter(center: p, width: s.width, height: s.height),
          c.alpha,
        ),
      );
    }
    return out;
  }

  /// Draws the frame's marks with one `drawAtlas` (cells under glyphs).
  void paint(Canvas c, {double now = 0, Offset Function(Offset)? toScreen}) {
    final marks = lastMarks = layout(now: now, toScreen: toScreen);
    final img = image;
    if (img == null || marks.isEmpty) return;
    final transforms = <RSTransform>[];
    final rects = <Rect>[];
    final colors = <Color>[];
    for (final m in marks.reversed) {
      final src = InsigniaAtlas.rects[m.key]!;
      transforms.add(
        RSTransform.fromComponents(
          rotation: 0,
          scale: m.rect.width / src.width,
          anchorX: 0,
          anchorY: 0,
          translateX: m.rect.left,
          translateY: m.rect.top,
        ),
      );
      rects.add(src);
      colors.add(Color.fromRGBO(255, 255, 255, m.alpha.clamp(0.0, 1.0)));
    }
    drawCalls++;
    c.drawAtlas(
      img,
      transforms,
      rects,
      colors,
      BlendMode.modulate,
      null,
      Paint()
        ..isAntiAlias = false
        ..filterQuality = FilterQuality.none,
    );
  }

  // --- geometry -------------------------------------------------------------

  /// Force-shield cell centres: [n] cells on an arc in front of the body
  /// (toward the player, screen down) about [centre], 0.44 rad apart
  /// (styleguide §5.1; 30 × 22 art px for a 40-unit flier).
  static List<Offset> arc(
    int n,
    Offset centre,
    double rx,
    double ry, {
    double step = .44,
  }) => [
    for (var i = 0; i < n; i++)
      () {
        final t = n > 1 ? i / (n - 1) - .5 : 0.0;
        final a = math.pi / 2 - t * (n - 1) * step; // index 0 on the left
        return centre + Offset(rx * math.cos(a), ry * math.sin(a));
      }(),
  ];

  /// Which cells of an [n]-cell arc are lit when [lit] points remain:
  /// spent points are taken from the outside in (left end first).
  static List<bool> litCells(int n, int lit) {
    final order = List.generate(n, (i) => i)
      ..sort((a, b) {
        final da = (a - (n - 1) / 2).abs(), db = (b - (n - 1) / 2).abs();
        return da != db ? db.compareTo(da) : a.compareTo(b);
      });
    final out = List.filled(n, true);
    for (var k = 0; k < n - lit.clamp(0, n); k++) {
      out[order[k]] = false;
    }
    return out;
  }

  // --- wound warm-up (design §5) ---------------------------------------------

  static const Color woundEmber = Color(0xFFFF6E3C);

  /// The whole-hide warm-up for molt 1-3: each channel lerps toward ember by
  /// 0.12 per molt, weighted by the pixel's own luma (gain 2.2: mid hide
  /// reaches full ember, the dark outline barely moves). A colour matrix
  /// cannot threshold, so the luma weight stands in for "luma > 0.14".
  static List<double> warmMatrix(int molt) {
    final k = .12 * molt.clamp(0, 3);
    const lr = .2126, lg = .7152, lb = .0722, gain = 2.2;
    final e = [woundEmber.r, woundEmber.g, woundEmber.b];
    return [
      for (var row = 0; row < 3; row++) ...[
        (1 - k) * (row == 0 ? 1 : 0) + k * e[row] * gain * lr,
        (1 - k) * (row == 1 ? 1 : 0) + k * e[row] * gain * lg,
        (1 - k) * (row == 2 ? 1 : 0) + k * e[row] * gain * lb,
        0,
        0,
      ],
      0, 0, 0, 1, 0, //
    ];
  }

  /// [a] after [b] (4 × 5 colour matrices, offsets in 0-255).
  static List<double> compose(List<double> a, List<double> b) {
    double at(List<double> m, int r, int c) =>
        r == 4 ? (c == 4 ? 1 : 0) : m[r * 5 + c];
    return [
      for (var r = 0; r < 4; r++)
        for (var c = 0; c < 5; c++)
          () {
            var s = 0.0;
            for (var k = 0; k < 5; k++) {
              s += at(a, r, k) * at(b, k, c);
            }
            return s;
          }(),
    ];
  }
}

// --- shields: breaks, flashes and shards (design §4) ----------------------

class _ShieldMemo {
  int shield = -1, rush = -1, dive = -1;
  final Map<String, double> flashes = {}; // '<kind>:<index>' -> age
  final Set<String> shed = {}; // breaks that already dropped shards
}

/// A falling fragment of a broken force-shield cell (a particle).
class ShieldShard {
  ShieldShard(this.x, this.y, this.vx, this.vy, this.color);
  double x, y, vx, vy, age = 0;
  final Color color;
}

/// Presentation bookkeeping for shield readouts: which cell just broke
/// (white for two frames, then shards) and the shards themselves. Reads the
/// model; never writes it.
class ShieldFx {
  static const double flashSeconds = 2 / 60;
  static const double diveFlashSeconds = .12;
  static const int maxShards = 12;
  static const double shardLife = .7;

  final _memo = Expando<_ShieldMemo>('shieldMemo');
  final List<ShieldShard> shards = [];
  int _bossLit = -1;
  final Map<int, double> bossFlashes = {};
  final Set<int> _bossShed = {};

  /// Lit cells of the carrier's 12-cell hull arc.
  static int bossCells(int shield, int shieldMax) =>
      shieldMax <= 0 ? 0 : (12 * shield / shieldMax).ceil().clamp(0, 12);

  void update(ArcadeModel model, double dt) {
    for (final d in model.demons) {
      final m = _memo[d] ??= _ShieldMemo();
      void track(String kind, int now, int was, int max) {
        if (was > now) {
          final lit = InsigniaPainter.litCells(max, now);
          final before = InsigniaPainter.litCells(max, was);
          for (var i = 0; i < max; i++) {
            if (before[i] && !lit[i]) m.flashes['$kind:$i'] = 0;
          }
        }
      }

      if (m.shield >= 0) track('shield', d.shield, m.shield, d.shieldMax);
      if (m.rush >= 0) track('rush', d.rushShield, m.rush, d.rushShieldMax);
      if (m.dive >= 0) track('dive', d.diveShield, m.dive, d.diveShieldMax);
      m
        ..shield = d.shield
        ..rush = d.rushShield
        ..dive = d.diveShield;
      m.flashes.updateAll((_, age) => age + dt);
      m.flashes.removeWhere((key, age) => age > diveFlashSeconds);
      m.shed.retainWhere(m.flashes.containsKey);
    }
    final b = model.boss;
    if (b != null) {
      final lit = bossCells(b.shield, b.shieldMax);
      if (_bossLit > lit) {
        for (var i = lit; i < _bossLit; i++) {
          bossFlashes[i] = 0;
        }
      }
      _bossLit = lit;
    } else {
      _bossLit = -1;
    }
    bossFlashes.updateAll((_, age) => age + dt);
    bossFlashes.removeWhere((_, age) => age > diveFlashSeconds);
    _bossShed.retainWhere(bossFlashes.containsKey);
    for (final s in shards) {
      s
        ..age += dt
        ..vy += 420 * dt
        ..x += s.vx * dt
        ..y += s.vy * dt;
    }
    shards.removeWhere((s) => s.age >= shardLife);
  }

  /// Seconds since cell [index] of [kind] ('shield', 'rush', 'dive') broke
  /// on [d], or null.
  double? flashAge(Demon d, String kind, int index) =>
      _memo[d]?.flashes['$kind:$index'];

  /// dive-shield-thinning: the white flash of the newest hit on [d]'s
  /// [kind] shield, 1 at the hit fading to 0 over [diveFlashSeconds].
  double hitFlash(Demon d, String kind) {
    final flashes = _memo[d]?.flashes;
    if (flashes == null || flashes.isEmpty) return 0;
    var age = double.infinity;
    flashes.forEach((k, v) {
      if (k.startsWith('$kind:') && v < age) age = v;
    });
    return age.isFinite ? (1 - age / diveFlashSeconds).clamp(0.0, 1.0) : 0;
  }

  /// Whether a cell of [kind] on [d] is still breaking (flash or shards
  /// pending): the arc stays up until the last cell has shed.
  bool breaking(Demon d, String kind) =>
      _memo[d]?.flashes.keys.any((k) => k.startsWith('$kind:')) ?? false;

  /// A force-shield cell's look this frame. A breaking cell is white for
  /// two frames and then sheds its shards at [at] (once).
  ShieldCell cellState(
    Demon d,
    String kind,
    int index,
    bool lit,
    Offset at, {
    ShieldCell litAs = ShieldCell.lit,
  }) {
    if (lit) return litAs;
    final m = _memo[d];
    final age = m?.flashes['$kind:$index'];
    if (m == null || age == null) return ShieldCell.spent;
    if (age < flashSeconds) return ShieldCell.flash;
    if (m.shed.add('$kind:$index')) {
      spawnShards(at, litAs == ShieldCell.rush);
    }
    return ShieldCell.spent;
  }

  /// The carrier's hull cell [index] (see [cellState]).
  ShieldCell bossCellState(int index, bool lit, Offset at) {
    if (lit) return ShieldCell.lit;
    final age = bossFlashes[index];
    if (age == null) return ShieldCell.spent;
    if (age < flashSeconds) return ShieldCell.flash;
    if (_bossShed.add(index)) spawnShards(at);
    return ShieldCell.spent;
  }

  /// Two or three shards fall from a broken cell (at most [maxShards]).
  void spawnShards(Offset at, [bool rush = false]) {
    final color = rush ? const Color(0xFFFFA88C) : const Color(0xFF62F0FF);
    final seed = (at.dx * 7 + at.dy * 13).round();
    final n = 2 + seed % 2;
    for (var i = 0; i < n; i++) {
      final dir = i - (n - 1) / 2;
      shards.add(ShieldShard(at.dx, at.dy, dir * 34, -40 + i * 14, color));
    }
    while (shards.length > maxShards) {
      shards.removeAt(0);
    }
  }

  void paintShards(Canvas c) {
    if (shards.isEmpty) return;
    final p = Paint()..isAntiAlias = false;
    for (final s in shards) {
      p.color = (s.age < flashSeconds * 2 ? const Color(0xFFFFFFFF) : s.color)
          .withValues(alpha: (1 - s.age / shardLife).clamp(0.0, 1.0));
      c.drawRect(
        Rect.fromLTWH(
          s.x.roundToDouble() - 1,
          s.y.roundToDouble() - 1,
          2.7,
          2.7,
        ),
        p,
      );
    }
  }
}
