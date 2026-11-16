import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import 'boss_atlas.dart';
import 'boss_director.dart';
import 'boss_grammar.dart';
import 'model.dart';

/// Draws the boss armada from `assets/images/boss-<class>.png`
/// (tools/generate_boss_sprites.py; contract: plan/sprite-atlas.md).
///
/// Each run meets a bigger hull class (run 1 frigate ... run 5
/// dreadnought). Every class shares the carrier's simulation geometry: the
/// bright bow layer (figurehead, maw, hangar bays, turrets) has the same
/// footprint in every class, and the extra size is the darker
/// superstructure (stern, engines, tower, sails) drawn as background
/// before the creatures. Only the current class's atlas is resident: it is
/// loaded on approach to the Carrier sector and released after the run.
///
/// Everything here reads the model; nothing writes to it.
class BossPainter {
  ui.Image? image;

  /// Hull class of [image] (index into [BossAtlas.classes]).
  int? loadedClass;

  static int classFor(int cycle) =>
      cycle.clamp(0, BossAtlas.classes.length - 1);

  BossHull get hull => BossAtlas.classes[loadedClass ?? 0];

  /// The frontal atlas is resident (the fallback for a hull whose view set
  /// is not packed yet).
  bool get ready => image != null && loadedClass != null;

  // --- boss-grandeur / boss-hero-assets 4.4: the packed view set ---
  /// The hero hull drawn this run (one of [BossHeroAtlas]'s set
  /// combinations), when its view set is packed; null while a hull falls
  /// back to its frontal atlas.
  BossHeroHull? hero;
  List<ui.Image>? heroPages;

  /// The Overflight's underside (`fin_belly`), loaded with the hull.
  ui.Image? bellyImage;
  BossHeroBelly? bellySprite;
  bool get heroReady => hero != null && heroPages != null;

  /// Either art is resident.
  bool get anyReady => ready || heroReady;

  /// The resident art's key: a hero hull key, or `frontal:<class>`.
  String? loadedKey;
  String? _loadingKey;

  /// The drawn hull's modules and detach orders (for the director).
  List<(String, int?)> get modules => [
    if (heroReady)
      for (final m in hero!.modules) (m.id, m.detach)
    else if (ready)
      ('spine', null),
  ];

  /// A v2 carrier (boss-carrier-v2: a GIANORMOUS hull that spills off
  /// the screen) is drawn: the camera uses the carrier band.
  bool get carrier => heroReady && hero!.set.isNotEmpty;

  /// Installs an already decoded atlas (tests and the gallery).
  void setAtlas(int cls, ui.Image atlas) {
    image = atlas;
    loadedClass = cls;
    loadedKey = 'frontal:$cls';
    hero = null;
    heroPages = null;
    bellyImage = null;
    bellySprite = null;
  }

  /// Installs a decoded hero view set (tests, review).
  void setHero(
    int cls,
    BossHeroHull hull,
    List<ui.Image> pages, {
    ui.Image? belly,
  }) {
    image = null;
    loadedClass = cls;
    loadedKey = hull.key;
    hero = hull;
    heroPages = pages;
    bellySprite = belly == null ? null : bellyOf(hull);
    bellyImage = belly;
  }

  /// The belly a hull draws in the Overflight: its own, else the first
  /// packed one (only the thorn carrier's underside is baked so far).
  static BossHeroBelly? bellyOf(BossHeroHull hull) =>
      hull.belly ??
      BossHeroAtlas.hulls.values.map((h) => h.belly).nonNulls.firstOrNull;

  /// The packed hero hulls (keys).
  static Set<String> get packed => BossHeroAtlas.hulls.keys.toSet();

  /// The hero hull a run draws at route [route]: the run's set combination
  /// (boss_grammar, picked from the run seed's [variant]) among the packed
  /// ones; null when none of its tour is packed (frontal atlas).
  static BossHeroHull? heroForRun(int route, int variant) =>
      BossHeroAtlas.hulls[BossGrammar.forRun(
        route: route,
        variant: variant,
        packed: packed,
      ).hull];

  /// Every asset of hero hull [key] (pages and belly), or of frontal class
  /// `frontal:<n>`.
  static List<String> assetsOf(String key) {
    final h = BossHeroAtlas.hulls[key];
    if (h == null) {
      return [BossAtlas.classes[int.parse(key.split(':').last)].asset];
    }
    return [...h.pages, if (bellyOf(h) case final b?) b.asset];
  }

  /// Keeps exactly the art the model needs resident: the current run's
  /// hull from the sector before the carrier until its wreck has fallen,
  /// none during the other sectors. [load] decodes an asset name; [evict]
  /// releases a cached one.
  void sync(
    ArcadeModel model,
    Future<ui.Image> Function(String asset) load,
    void Function(String asset) evict,
  ) {
    final needed =
        model.boss != null || model.wreckBoss != null || model.level >= 4;
    final cls = classFor(model.cycle);
    final heroHull = heroForRun(model.cycle, model.bossVariant);
    final want = heroHull?.key ?? 'frontal:$cls';
    if (!needed) {
      if (anyReady && loadedKey != null) {
        assetsOf(loadedKey!).forEach(evict);
        image = null;
        hero = null;
        heroPages = null;
        bellyImage = null;
        bellySprite = null;
        loadedClass = null;
        loadedKey = null;
      }
      return;
    }
    if (loadedKey == want || _loadingKey == want) return;
    _loadingKey = want;
    // One hull resident at a time: its hero pages (≤ 16 MB) and the
    // Overflight's belly, or its frontal atlas while its view set is not
    // packed yet.
    final belly = heroHull == null ? null : bellyOf(heroHull);
    final pending = heroHull != null
        ? Future.wait(
            [...heroHull.pages, if (belly != null) belly.asset].map(load),
          )
        : load(BossAtlas.classes[cls].asset).then((i) => [i]);
    pending
        .then((imgs) {
          if (_loadingKey != want) return;
          final old = loadedKey;
          if (heroHull != null) {
            hero = heroHull;
            heroPages = imgs.sublist(0, heroHull.pages.length);
            bellySprite = belly;
            bellyImage = belly == null ? null : imgs.last;
            image = null;
          } else {
            image = imgs.single;
            hero = null;
            heroPages = null;
            bellyImage = null;
            bellySprite = null;
          }
          loadedClass = cls;
          loadedKey = want;
          _loadingKey = null;
          if (old != null && old != want) assetsOf(old).forEach(evict);
        })
        .catchError((Object _) {
          _loadingKey = null;
        });
  }

  final Paint _paint = Paint()
    ..isAntiAlias = false
    ..filterQuality = FilterQuality.none;
  final Paint _block = Paint()..isAntiAlias = false;

  /// Draws [s] with its anchor at [anchor] (arena units).
  void sprite(
    Canvas c,
    BossSprite s,
    Offset anchor, {
    double opacity = 1,
    bool flipX = false,
    bool flipY = false,
  }) {
    final img = image;
    if (img == null) return;
    _paint.color = Colors.white.withValues(alpha: opacity);
    final src = Rect.fromLTWH(
      s.x.toDouble(),
      s.y.toDouble(),
      s.w.toDouble(),
      s.h.toDouble(),
    );
    if (!flipX && !flipY) {
      c.drawImageRect(
        img,
        src,
        Rect.fromLTWH(anchor.dx + s.dx, anchor.dy + s.dy, s.w / 2, s.h / 2),
        _paint,
      );
      return;
    }
    c.save();
    c.translate(anchor.dx, anchor.dy);
    c.scale(flipX ? -1 : 1, flipY ? -1 : 1);
    c.drawImageRect(
      img,
      src,
      Rect.fromLTWH(s.dx, s.dy, s.w / 2, s.h / 2),
      _paint,
    );
    c.restore();
  }

  static int formOf(Carrier b, BossHull h) => b.phase.clamp(0, h.forms - 1);

  // --- boss-grandeur: drawing the hero view set ---

  /// Draws hero sprite [s] with its anchor at [anchor] (arena units).
  void heroSprite(
    Canvas c,
    BossHeroSprite s,
    Offset anchor, {
    double opacity = 1,
    bool flipX = false,
    bool flipY = false,
  }) {
    final pages = heroPages;
    if (pages == null) return;
    _paint.color = Colors.white.withValues(alpha: opacity.clamp(0.0, 1.0));
    final src = Rect.fromLTWH(
      s.x.toDouble(),
      s.y.toDouble(),
      s.w.toDouble(),
      s.h.toDouble(),
    );
    final k = s.ppu.toDouble();
    if (!flipX && !flipY) {
      c.drawImageRect(
        pages[s.page],
        src,
        Rect.fromLTWH(anchor.dx + s.dx, anchor.dy + s.dy, s.w / k, s.h / k),
        _paint,
      );
      return;
    }
    c.save();
    c.translate(anchor.dx, anchor.dy);
    c.scale(flipX ? -1 : 1, flipY ? -1 : 1);
    c.drawImageRect(
      pages[s.page],
      src,
      Rect.fromLTWH(s.dx, s.dy, s.w / k, s.h / k),
      _paint,
    );
    c.restore();
  }

  /// The stored view, whether it is drawn mirrored, for [view].
  BossHeroView? storedView(BossView view) => hero?.views[view.storedTag];

  /// The run's assembly (boss_grammar): which of the hull's modules are
  /// drawn and from which art set. Null draws every packed module.
  BossAssembly? assembly;

  /// Picks the run's assembly for carrier [b] (its seeded set combination,
  /// R8.6; visual only). A hull whose packed modules share no id with the
  /// assembly (art not in yet) draws everything packed.
  void assemble(Carrier b, int route) {
    final h = hero;
    if (h == null) {
      assembly = null;
      return;
    }
    final a = BossGrammar.forRun(
      route: route,
      variant: b.variant,
      packed: packed,
    );
    final ids = {for (final m in a.modules) m.id};
    final have = {for (final m in h.modules) m.id};
    assembly = ids.intersection(have).isEmpty ? null : a;
  }

  bool _assembled(String id) =>
      assembly == null || assembly!.modules.any((m) => m.id == id);

  /// The front pass (drawn after the creatures): the v2 `prow` (mount
  /// bow, the hangar deck with the functional windows), or the v1 `bow`.
  static bool isFront(BossHeroModule m) =>
      m.module == 'prow' || m.module.startsWith('prow.') || m.id == 'bow';

  /// Whether any module has a layer at [stage] (a hull baked without a
  /// stage falls back to S0).
  int _drawnStage(BossHeroView v, int stage) {
    for (var s = stage; s > 0; s--) {
      if (v.layers.values.any((l) => l[s] != null)) return s;
    }
    return 0;
  }

  /// The stage the art of [view] really draws for [stage] (tests, review).
  int drawnStage(BossView view, int stage) {
    final v = storedView(view);
    return v == null ? 0 : _drawnStage(v, stage);
  }

  /// The runtime decay overlay's strength for [stage] drawn from the art's
  /// stage [drawn]: S1 is always the overlay on S0 (boss-hero-assets §8.4:
  /// not baked); a stage the hull has no layers for (tours 2–5 so far: S0
  /// only) falls back to S0 under a heavier overlay. Baked S2/S3 looks
  /// carry their own damage.
  static double overlayFor(int stage, int drawn) {
    if (stage <= 0 || drawn >= 2) return 0;
    return switch (stage) {
      1 => .35,
      2 => .6,
      _ => .8,
    };
  }

  static const _char = Color(0xFF140A0C);
  static const _ember = Color(0xFFFF6A24), _emberHot = Color(0xFFFFB060);
  final Paint _stump = Paint()
    ..colorFilter = const ColorFilter.mode(
      Color(0xD8140A0C),
      BlendMode.srcATop,
    );

  /// One view of the hull's module layers at [stage]. [front]: only the
  /// prow (the functional face, drawn after the creatures); otherwise every
  /// other module. Modules whose detach order is in [detached] are gone;
  /// where the art still draws such a module at this stage (a stage it has
  /// no layers for), its layer is drawn as a charred stump so the hull
  /// never shows a hole where the module was held out.
  void _paintHeroView(
    Canvas c,
    Offset center,
    BossView view, {
    required int stage,
    required bool front,
    Set<int> detached = const {},
    double opacity = 1,
  }) {
    final h = hero!;
    final v = h.views[view.storedTag];
    if (v == null) return;
    final st = _drawnStage(v, stage);
    c.save();
    if (view.mirrored) {
      c.translate(center.dx * 2, 0);
      c.scale(-1, 1);
    }
    for (final m in h.modules) {
      if (isFront(m) != front) continue;
      if (!_assembled(m.id)) continue;
      var layers = v.layers[m.id];
      var flip = false;
      if (layers == null && m.id.endsWith('L')) {
        layers = v.layers['${m.id.substring(0, m.id.length - 1)}R'];
        flip = true;
      }
      final sprite = layers?[st];
      if (sprite == null) continue;
      if (m.detach != null && detached.contains(m.detach)) {
        // Torn away. A baked stage that sheds it has no layer for it; a
        // fallback stage still has one: char it.
        if (st >= stage) continue;
        c.saveLayer(null, _stump);
        heroSprite(c, sprite, center, opacity: opacity, flipX: flip);
        c.restore();
        continue;
      }
      heroSprite(c, sprite, center, opacity: opacity, flipX: flip);
    }
    c.restore();
  }

  /// The hull's layers in [view], crossfading from [previous] by [blend]
  /// (both views share the simulation anchors, so the blend never pops),
  /// under the runtime decay overlay ([overlayFor]): scorch, crystal
  /// flicker and ember hairline cracks from the fire points, clipped to the
  /// hull's own pixels.
  void paintHero(
    Canvas c,
    Offset center, {
    required BossView view,
    BossView? previous,
    double blend = 1,
    required int stage,
    required bool front,
    Set<int> detached = const {},
    double opacity = 1,
    double clock = 0,
  }) {
    if (!heroReady) return;
    final v = hero!.views[view.storedTag];
    final sev = v == null ? 0.0 : overlayFor(stage, _drawnStage(v, stage));
    final dome = front && hero!.set.isNotEmpty;
    if (sev > 0 || dome) {
      final f = hero!.frame;
      c.saveLayer(
        Rect.fromLTRB(
          center.dx + f.$1 - 8,
          center.dy + f.$2 - 8,
          center.dx + f.$3 + 8,
          center.dy + f.$4 + 8,
        ),
        Paint(),
      );
    }
    if (previous != null && previous != view && blend < 1) {
      _paintHeroView(
        c,
        center,
        previous,
        stage: stage,
        front: front,
        detached: detached,
        opacity: opacity,
      );
      _paintHeroView(
        c,
        center,
        view,
        stage: stage,
        front: front,
        detached: detached,
        opacity: opacity * blend,
      );
    } else {
      _paintHeroView(
        c,
        center,
        view,
        stage: stage,
        front: front,
        detached: detached,
        opacity: opacity,
      );
    }
    if (dome) _domeShade(c, center, opacity);
    if (sev > 0) {
      _decayOverlay(
        c,
        center,
        view,
        stage,
        sev,
        front: front,
        clock: clock,
        opacity: opacity,
      );
    }
    if (sev > 0 || dome) c.restore();
  }

  /// boss-carrier-wire: the v2 prow's dome above the hangar deck is painted
  /// lighter than the hull's value ceiling (styleguide §7.1, `#56456C`), and
  /// its rows of dark ports then read as eyes over the deck (§3.4). A shade
  /// over the prow's own pixels, deepest at the crown and gone at the deck
  /// sill, takes the dome down to the hull's value so the gallery reads
  /// first (§7.3).
  void _domeShade(Canvas c, Offset center, double opacity) {
    final top = center.dy - 80, sill = center.dy + 10;
    c.drawRect(
      Rect.fromLTRB(center.dx - 240, top, center.dx + 240, sill),
      Paint()
        ..blendMode = BlendMode.srcATop
        ..shader = ui.Gradient.linear(
          Offset(0, top),
          Offset(0, sill),
          [
            _char.withValues(alpha: .62 * opacity),
            _char.withValues(alpha: .5 * opacity),
            _char.withValues(alpha: 0),
          ],
          const [0, .62, 1],
        ),
    );
  }

  /// The overlay itself, drawn `srcATop` over the hull's layer: a warm char
  /// (deeper as the stage rises; S1's crystal flicker dims it in pulses),
  /// then ember hairline cracks radiating from the view's fire points. The
  /// prow keeps its gallery dark: no cracks within 60 units of the centre
  /// line (embers around the deck would read as teeth; styleguide §3.4).
  void _decayOverlay(
    Canvas c,
    Offset center,
    BossView view,
    int stage,
    double sev, {
    required bool front,
    required double clock,
    double opacity = 1,
  }) {
    final f = hero!.frame;
    final flicker = stage == 1 && (clock * 7).floor() % 3 == 0 ? .12 : 0.0;
    final atop = Paint()
      ..blendMode = BlendMode.srcATop
      ..color = _char.withValues(
        alpha: ((.55 * sev + flicker) * opacity).clamp(0.0, 1.0),
      );
    c.drawRect(
      Rect.fromLTRB(
        center.dx + f.$1,
        center.dy + f.$2,
        center.dx + f.$3,
        center.dy + f.$4,
      ),
      atop,
    );
    final fires = [
      for (final p in heroPoints(view, stage, kind: 'fires'))
        if ((p.module == 'prow' || p.module == 'bow') == front &&
            !(front && p.x.abs() < 60))
          p,
    ];
    if (fires.isEmpty) return;
    final n = (fires.length * sev).ceil().clamp(1, fires.length);
    final glow = (math.sin(clock * 5.3) * .5 + .5) * .3 + .55;
    // Strokes in arena units: at Z 0.70 on a DPR-2 phone one unit is 1.4
    // device px, so the glow stays ≥ 4 px and the hot core ≥ 2 px.
    final a = (glow * (.5 + .5 * sev) * opacity).clamp(0.0, 1.0);
    final halo = Paint()
      ..blendMode = BlendMode.srcATop
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4.5
      ..strokeCap = StrokeCap.round
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2.5)
      ..color = _ember.withValues(alpha: a * .55);
    final wide = Paint()
      ..blendMode = BlendMode.srcATop
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.2
      ..strokeCap = StrokeCap.round
      ..color = _ember.withValues(alpha: a);
    final hot = Paint()
      ..blendMode = BlendMode.srcATop
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0
      ..color = _emberHot.withValues(alpha: a * .9);
    final pore = Paint()
      ..blendMode = BlendMode.srcATop
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5)
      ..color = _ember.withValues(alpha: (.55 * sev * opacity).clamp(0.0, 1.0));
    for (var i = 0; i < n; i++) {
      final p = fires[(i * 7) % fires.length];
      final o = center + Offset(p.x, p.y);
      // Seeded by the point (mirror-stable: |x|), never by the frame.
      final rng = math.Random(
        (p.x.abs() * 13).round() * 7919 + (p.y * 7).round(),
      );
      final path = Path();
      final arms = 3 + rng.nextInt(2);
      for (var a = 0; a < arms; a++) {
        var dir = rng.nextDouble() * math.pi * 2;
        var q = o;
        path.moveTo(q.dx, q.dy);
        final segs = 2 + (sev * 3).round();
        for (var s = 0; s < segs; s++) {
          dir += (rng.nextDouble() - .5) * 1.1;
          final len = 6 + rng.nextDouble() * 9;
          q += Offset(math.cos(dir), math.sin(dir) * .7) * len;
          path.lineTo(q.dx, q.dy);
        }
      }
      c.drawCircle(o, 4 + 8 * sev, pore);
      c.drawPath(path, halo);
      c.drawPath(path, wide);
      c.drawPath(path, hot);
    }
  }

  /// Points of [view] (mirrored for yaw −12) at [stage].
  List<BossHeroPoint> heroPoints(
    BossView view,
    int stage, {
    required String kind,
  }) {
    final v = storedView(view);
    if (v == null) return const [];
    final broken = stage >= 3;
    final list = switch (kind) {
      'lights' => broken ? v.lightsBroken : v.lights,
      'fires' => broken ? v.firesBroken : v.fires,
      _ => broken ? v.nozzlesBroken : v.nozzles,
    };
    if (!view.mirrored) return list;
    return [for (final p in list) BossHeroPoint(-p.x, p.y, p.kind, p.module)];
  }

  /// Background layer of the hero hull: plumes at its nozzles, every module
  /// but the bow, breaches at its fire points, running lights (S1 flickers).
  void paintHeroBackdrop(
    Canvas c,
    Carrier b, {
    required BossDirector director,
    required double clock,
    required double bank,
    required double damage,
    double burn = -1,
    Offset? center,
    double opacity = 1,
  }) {
    if (!heroReady) return;
    final h = hero!;
    final at = center ?? Offset(b.x, b.y);
    final flick = (clock * 12).floor() % 2;
    final stage = director.stage;
    for (final (i, n) in heroPoints(
      director.view,
      stage,
      kind: 'nozzles',
    ).indexed) {
      if (h.plumes.isEmpty) break;
      final t = burn >= 0 ? burn : thrust(n.x, bank, b.rage);
      final level = t < .42 ? 0 : (t < .72 ? 1 : 2);
      final size = n.kind.clamp(0, h.plumes.length - 1);
      heroSprite(
        c,
        h.plumes[size][level][(flick + i) % 2],
        at + Offset(n.x, n.y),
        opacity: opacity,
      );
    }
    paintHero(
      c,
      at,
      view: director.view,
      previous: director.previous,
      blend: director.blend,
      stage: stage,
      front: false,
      detached: director.detached,
      clock: clock,
      opacity: opacity,
    );
    if (damage > .45 && h.breach.isNotEmpty) {
      final fires = heroPoints(director.view, stage, kind: 'fires');
      final count = fires.isEmpty
          ? 0
          : (fires.length * ((damage - .45) / .45)).ceil().clamp(
              1,
              fires.length,
            );
      final sev = damage > .8 ? 2 : (damage > .62 ? 1 : 0);
      for (var i = 0; i < count; i++) {
        final f = fires[(i * 5) % fires.length];
        final pick = (sev * 2 + (flick + i) % 2).clamp(0, h.breach.length - 1);
        heroSprite(c, h.breach[pick], at + Offset(f.x, f.y), opacity: opacity);
      }
    }
    // S1 scorched: the running lights flicker.
    if (stage == 1 && (clock * 7).floor() % 3 == 0) return;
    final strobe = (clock * 8).floor() % 10 == 0;
    final pulse = (clock * 2).floor().isEven;
    for (final l in heroPoints(director.view, stage, kind: 'lights')) {
      final Color color = switch (l.kind) {
        0 => const Color(0xFFFF3048),
        1 => const Color(0xFF40FF90),
        2 => strobe ? const Color(0xFFFFFFFF) : const Color(0x00000000),
        _ => pulse ? const Color(0xFFFFC45A) : const Color(0xFFB0702A),
      };
      if (color.a == 0) continue;
      final p = at + Offset(l.x, l.y);
      _block.color = color.withValues(alpha: .3 * opacity);
      c.drawRect(Rect.fromLTWH(p.dx - 2, p.dy - 2, 4, 4), _block);
      _block.color = color.withValues(alpha: opacity);
      c.drawRect(Rect.fromLTWH(p.dx - 1, p.dy - 1, 2, 2), _block);
    }
  }

  /// The sprite a director wreck draws: a module's wreck frame (rest, then
  /// tumbled; a mirrored pair stores one side), an armour plate (a debris
  /// piece), or for a module baked without wreck frames (the v2 carapace
  /// and prow: `wreck: "layer"`) its own layer at the hero view and the
  /// last stage the hull has, sinking whole.
  (BossHeroSprite, bool)? wreckSprite(BossWreck w) {
    if (!heroReady) return null;
    final h = hero!;
    if (w.plate) {
      return h.debris.isEmpty
          ? null
          : (h.debris[w.module.hashCode.abs() % h.debris.length], false);
    }
    var frames = h.wrecks[w.module];
    var flip = false;
    if (frames == null && w.module.length > 1) {
      final base = w.module.substring(0, w.module.length - 1);
      final other = w.module.endsWith('R') ? '${base}L' : '${base}R';
      frames = h.wrecks[other];
      flip = frames != null;
    }
    if (frames != null) {
      final s = frames[w.progress > .35 ? 1 : 0] ?? frames[0];
      return s == null ? null : (s, flip);
    }
    final v = h.views[BossView.hero.storedTag];
    if (v == null) return null;
    var layers = v.layers[w.module];
    flip = false;
    if (layers == null && w.module.endsWith('L')) {
      layers = v.layers['${w.module.substring(0, w.module.length - 1)}R'];
      flip = true;
    }
    if (layers == null) return null;
    for (var s = _drawnStage(v, 3); s >= 0; s--) {
      if (layers[s] != null) return (layers[s]!, flip);
    }
    return null;
  }

  void _wreckTransform(Canvas c, BossWreck w, Offset shift) {
    c.translate(w.x + shift.dx, w.y + shift.dy);
    c.rotate(w.rotation);
    c.scale(w.scale * (w.plate ? .5 : 1));
  }

  /// A cosmetic wreck of the director, sinking into the fog. [fog] tints
  /// it as it goes. Before it breaks away ([BossWreck.started]) it is drawn
  /// at rest, as part of the dying hull.
  void paintHeroWreck(
    Canvas c,
    BossWreck w, {
    Color fog = const Color(0xFF2A2436),
  }) {
    final pick = wreckSprite(w);
    if (pick == null) return;
    final (s, flip) = pick;
    c.save();
    _wreckTransform(c, w, Offset.zero);
    final layer = Paint()
      ..colorFilter = ColorFilter.mode(
        fog.withValues(alpha: (w.progress * .85).clamp(0.0, .85)),
        BlendMode.srcATop,
      );
    c.saveLayer(null, layer);
    heroSprite(c, s, Offset.zero, opacity: w.opacity, flipX: flip);
    c.restore();
    c.restore();
  }

  /// The wreck's shadow (boss-carrier-wire): the wreck sprite's own alpha
  /// as the mask, inked with [ink] at [alpha], softened, and thrown by
  /// [shift] (down and to the right, the light's side; it closes in as the
  /// wreck sinks toward the fog it falls on).
  void paintHeroWreckShadow(
    Canvas c,
    BossWreck w, {
    required Offset shift,
    required Color ink,
    required double alpha,
  }) {
    if (!w.started || alpha < .01) return;
    final pick = wreckSprite(w);
    if (pick == null) return;
    final (s, flip) = pick;
    c.save();
    _wreckTransform(c, w, shift);
    c.saveLayer(
      null,
      Paint()
        ..colorFilter = ColorFilter.mode(
          ink.withValues(alpha: alpha.clamp(0.0, 1.0)),
          BlendMode.srcIn,
        )
        ..imageFilter = ui.ImageFilter.blur(sigmaX: 3, sigmaY: 3)
        ..blendMode = BlendMode.multiply,
    );
    heroSprite(c, s, Offset.zero, opacity: w.opacity, flipX: flip);
    c.restore();
    c.restore();
  }

  /// The Overflight's belly (boss-carrier-v2 `fin_belly`), centred on
  /// [center] in the overflight's own scaled frame; false when the hull
  /// has none resident (the caller draws the hull from above instead).
  bool paintBelly(Canvas c, Offset center, {double opacity = 1}) {
    final img = bellyImage, b = bellySprite;
    if (img == null || b == null) return false;
    _paint.color = Colors.white.withValues(alpha: opacity.clamp(0.0, 1.0));
    final w = b.w / b.ppu, h = b.h / b.ppu;
    c.drawImageRect(
      img,
      Rect.fromLTWH(0, 0, img.width.toDouble(), img.height.toDouble()),
      Rect.fromCenter(center: center, width: w, height: h),
      _paint,
    );
    return true;
  }

  /// Engine thrust 0..1 per nozzle: idle burn, rage, and vectoring (the
  /// engines on the side away from the motion push harder).
  static double thrust(double x, double bank, double rage) {
    final push = x.abs() < 1 ? bank.abs() * .5 : math.max(0.0, -x.sign * bank);
    return (.3 + rage * .25 + push * .5 + bank.abs() * .12).clamp(0.0, 1.0);
  }

  /// Background layer, drawn before the creatures: engine plumes, the
  /// superstructure, its breaches and running lights.
  void paintBackdrop(
    Canvas c,
    Carrier b, {
    required double clock,
    required double bank,
    required double damage,
    double burn = -1,
  }) {
    if (!ready) return;
    final h = hull;
    final center = Offset(b.x, b.y);
    final form = formOf(b, h);
    final flick = (clock * 12).floor() % 2;
    for (final (i, (x, y, size)) in h.engines.indexed) {
      final t = burn >= 0 ? burn : thrust(x, bank, b.rage);
      final level = t < .42 ? 0 : (t < .72 ? 1 : 2);
      final f = (flick + i) % 2;
      sprite(c, h.plumes[size][level][f], center + Offset(x, y));
    }
    sprite(c, h.superstructure[form], center);
    if (damage > .45) {
      final stage = damage > .8 ? 2 : (damage > .62 ? 1 : 0);
      final count = (h.fire.length * ((damage - .45) / .45)).ceil().clamp(
        1,
        h.fire.length,
      );
      for (var i = 0; i < count; i++) {
        final (x, y) = h.fire[(i * 5) % h.fire.length];
        sprite(c, h.breach[stage][(flick + i) % 2], center + Offset(x, y));
      }
    }
    paintLights(c, center, clock);
  }

  void paintLights(Canvas c, Offset center, double clock) {
    final h = hull;
    final strobe = (clock * 8).floor() % 10 == 0;
    final pulse = (clock * 2).floor().isEven;
    for (final (x, y, kind) in h.lights) {
      final Color color;
      switch (kind) {
        case 0:
          color = const Color(0xFFFF3048);
        case 1:
          color = const Color(0xFF40FF90);
        case 2:
          if (!strobe) continue;
          color = const Color(0xFFFFFFFF);
        default:
          color = pulse ? const Color(0xFFFFC45A) : const Color(0xFFB0702A);
      }
      final p = center + Offset(x, y);
      _block.color = color.withValues(alpha: .3);
      c.drawRect(Rect.fromLTWH(p.dx - 2, p.dy - 2, 4, 4), _block);
      _block.color = color;
      c.drawRect(Rect.fromLTWH(p.dx - 1, p.dy - 1, 2, 2), _block);
    }
  }

  /// Lateral thruster puffs on the bow flank opposite the motion.
  void paintRcs(Canvas c, Offset center, double bank, double clock) {
    if (bank.abs() < .3) return;
    final side = bank > 0 ? -1.0 : 1.0;
    final f = (clock * 16).floor() % 3;
    final p = center + Offset(side * 87, 4);
    for (var i = 0; i < 3 - f; i++) {
      _block.color =
          (i == 0 ? const Color(0xFFE8F4FF) : const Color(0xFF8AB4D8))
              .withValues(alpha: .8 - i * .22);
      final w = 2.0 + i;
      c.drawRect(
        Rect.fromLTWH(
          p.dx + side * (i * 2.5 + f) - (side < 0 ? w : 0),
          p.dy - w / 2,
          w,
          w,
        ),
        _block,
      );
    }
  }

  /// Bright bow: the idle frame of the current form, bow damage and the
  /// turret heads. The scene adds barrels, eyes, bays, maw and shield.
  void paintBow(
    Canvas c,
    Carrier b, {
    required double clock,
    required (int, int)? damageCell,
    required int turretFrame,
  }) {
    if (!ready) return;
    final h = hull;
    final center = Offset(b.x, b.y);
    final form = formOf(b, h);
    final idle = (clock * 2).floor() % 4;
    if (idle == 0 || h.hullPatch[form][idle]) {
      sprite(c, h.hull[form][0], center);
    }
    if (idle > 0) sprite(c, h.hull[form][idle], center);
    if (damageCell != null) {
      sprite(c, h.damage[damageCell.$1][damageCell.$2], center);
    }
    sprite(c, h.turrets[turretFrame], center);
  }

  void paintJaws(Canvas c, Carrier b) {
    if (heroReady) {
      final j = hero!.jaws;
      if (j.isNotEmpty) {
        heroSprite(
          c,
          j[(b.door.clamp(0.0, 1.0) * (j.length - 1)).round()],
          Offset(b.x, b.y),
        );
      }
      return;
    }
    if (!ready) return;
    sprite(
      c,
      hull.jaws[(b.door.clamp(0.0, 1.0) * 3).round()],
      Offset(b.x, b.y),
    );
  }

  /// Bay door frame for one side (the atlas holds the left bay).
  void paintBay(
    Canvas c,
    Carrier b, {
    required bool right,
    required int frame,
  }) {
    if (heroReady) {
      final v = hero!.vents;
      if (v.isNotEmpty) {
        heroSprite(
          c,
          v[frame.clamp(0, v.length - 1)],
          Offset(b.x, b.y),
          flipX: right,
        );
      }
      return;
    }
    if (!ready) return;
    sprite(c, hull.vents[frame], Offset(b.x, b.y), flipX: right);
  }

  /// Bow retro-thrusters braking the arrival: plumes pointing down from the
  /// bow corners, longest at the start of the descent.
  void paintRetro(Canvas c, Offset center, double descent, double clock) {
    if (descent <= .05) return;
    final level = descent > .6 ? 2 : (descent > .3 ? 1 : 0);
    final f = (clock * 12).floor() % 2;
    if (heroReady) {
      if (hero!.plumes.isEmpty) return;
      for (final x in const [-70.0, 70.0]) {
        heroSprite(
          c,
          hero!.plumes[0][level][f],
          center + Offset(x, 30),
          flipY: true,
        );
      }
      return;
    }
    if (!ready) return;
    final h = hull;
    for (final x in const [-70.0, 70.0]) {
      sprite(c, h.plumes[0][level][f], center + Offset(x, 30), flipY: true);
    }
  }

  /// The falling wreck: the charred superstructure (bigger hulls snap in
  /// two and the halves drift apart), the charred bow, chain explosions
  /// along the engines and tower, and tumbling debris.
  void paintWreck(
    Canvas c,
    Carrier wreck,
    Offset pos,
    double p, {
    required void Function(Offset at, int frame, double scale) blast,
  }) {
    if (!ready) return;
    final h = hull;
    final cls = loadedClass ?? 0;
    final heavy = cls / 4;
    final roll = p * (.22 + .06 * cls);
    c.save();
    c.translate(pos.dx, pos.dy);
    c.rotate(roll);
    if (h.superWreck.length == 1) {
      sprite(c, h.superWreck[0], Offset.zero);
    } else {
      // The keel snaps: each half pivots outward and drifts apart.
      final split = Curves.easeIn.transform(p);
      for (final (i, piece) in h.superWreck.indexed) {
        final side = i == 0 ? -1.0 : 1.0;
        c.save();
        c.translate(side * split * (18 + 26 * heavy), -split * 10);
        c.rotate(side * split * (.12 + .1 * heavy));
        sprite(c, piece, Offset.zero);
        c.restore();
      }
    }
    sprite(c, h.hullWreck, Offset.zero);
    sprite(
      c,
      h.damage[2][((p * 30).floor()) % 2],
      Offset.zero,
      opacity: (p * 1.2).clamp(.4, 1.0),
    );
    // Chain explosions run along the fire points, outer engines first.
    final fire = h.fire;
    for (var i = 0; i < fire.length; i++) {
      final start = (i / fire.length) * .7;
      final age = (p - start) / (.22 + .05 * heavy);
      if (age < 0 || age > 1) continue;
      final (x, y) = fire[i];
      blast(Offset(x, y), (age * 8).floor().clamp(0, 7), .45 + .25 * heavy);
    }
    c.restore();
    // Debris tumbles free of the hull.
    for (final (i, d) in h.debris.indexed) {
      final side = i.isEven ? -1.0 : 1.0;
      final spread = 60.0 + i * 18 + 40 * heavy;
      final at =
          pos +
          Offset(
            side * (50 + i * 12 + p * spread),
            -10 + p * p * (110 + i * 30),
          );
      c.save();
      c.translate(at.dx, at.dy);
      c.rotate(side * p * (2 + i * .7));
      sprite(c, d, Offset.zero);
      c.restore();
    }
  }
}
