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
  int? _loading;

  static int classFor(int cycle) =>
      cycle.clamp(0, BossAtlas.classes.length - 1);

  BossHull get hull => BossAtlas.classes[loadedClass ?? 0];

  /// The frontal atlas is resident (the fallback for a hull whose view set
  /// is not packed yet).
  bool get ready => image != null && loadedClass != null;

  // --- boss-grandeur / boss-hero-assets 4.4: the packed view set ---
  /// The hero hull of [loadedClass], when its view set is packed
  /// ([BossHeroAtlas]); null while a hull falls back to its frontal atlas.
  BossHeroHull? hero;
  List<ui.Image>? heroPages;
  bool get heroReady => hero != null && heroPages != null;

  /// Either art is resident.
  bool get anyReady => ready || heroReady;

  /// The drawn hull's modules and detach orders (for the director).
  List<(String, int?)> get modules => [
    if (heroReady)
      for (final m in hero!.modules) (m.id, m.detach)
    else if (ready)
      ('spine', null),
  ];

  /// Installs an already decoded atlas (tests and the gallery).
  void setAtlas(int cls, ui.Image atlas) {
    image = atlas;
    loadedClass = cls;
    hero = null;
    heroPages = null;
  }

  /// Installs a decoded hero view set (tests, review).
  void setHero(int cls, BossHeroHull hull, List<ui.Image> pages) {
    image = null;
    loadedClass = cls;
    hero = hull;
    heroPages = pages;
  }

  /// The packed hero hull of class [cls], if any.
  static BossHeroHull? heroFor(int cls) =>
      BossHeroAtlas.hulls[BossAtlas.classes[cls].key];

  /// Every asset of class [cls]: its hero pages, else its frontal atlas.
  static List<String> assetsFor(int cls) =>
      heroFor(cls)?.pages ?? [BossAtlas.classes[cls].asset];

  /// Keeps exactly the atlas the model needs resident: the current run's
  /// class from the sector before the carrier until its wreck has fallen,
  /// none during the other sectors. [load] decodes an asset name; [evict]
  /// releases a cached one.
  void sync(
    ArcadeModel model,
    Future<ui.Image> Function(String asset) load,
    void Function(String asset) evict,
  ) {
    final needed =
        model.boss != null || model.wreckBoss != null || model.level >= 4;
    final want = classFor(model.cycle);
    if (!needed) {
      if (anyReady && loadedClass != null) {
        assetsFor(loadedClass!).forEach(evict);
        image = null;
        hero = null;
        heroPages = null;
        loadedClass = null;
      }
      return;
    }
    if (loadedClass == want || _loading == want) return;
    _loading = want;
    final heroHull = heroFor(want);
    // One hull resident at a time: its hero pages (≤ 16 MB), or its
    // frontal atlas while its view set is not packed yet.
    final pending = heroHull != null
        ? Future.wait(heroHull.pages.map(load))
        : load(BossAtlas.classes[want].asset).then((i) => [i]);
    pending.then((imgs) {
      if (_loading != want) return;
      final old = loadedClass;
      if (heroHull != null) {
        hero = heroHull;
        heroPages = imgs;
        image = null;
      } else {
        image = imgs.single;
        hero = null;
        heroPages = null;
      }
      loadedClass = want;
      _loading = null;
      if (old != null && old != want) assetsFor(old).forEach(evict);
    }).catchError((Object _) {
      _loading = null;
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
    c.drawImageRect(pages[s.page], src,
        Rect.fromLTWH(s.dx, s.dy, s.w / k, s.h / k), _paint);
    c.restore();
  }

  /// The stored view, whether it is drawn mirrored, for [view].
  BossHeroView? storedView(BossView view) => hero?.views[view.storedTag];

  /// The run's assembly (boss_grammar): which of the hull's modules are
  /// drawn and from which art set. Null draws every packed module.
  BossAssembly? assembly;

  /// Picks the run's assembly for carrier [b] (its seeded module set,
  /// R8.6; visual only). A hull whose packed modules share no id with the
  /// assembly (art not in yet) draws everything packed.
  void assemble(Carrier b, int route) {
    final h = hero;
    if (h == null) {
      assembly = null;
      return;
    }
    final a = BossGrammar.forRun(route: route, variant: b.variant);
    final ids = {for (final m in a.modules) m.id};
    final packed = {for (final m in h.modules) m.id};
    assembly = ids.intersection(packed).isEmpty ? null : a;
  }

  bool _assembled(String id) =>
      assembly == null || assembly!.modules.any((m) => m.id == id);

  /// Whether any module has a layer at [stage] (a hull baked without a
  /// stage falls back to S0).
  int _drawnStage(BossHeroView v, int stage) {
    for (var s = stage; s > 0; s--) {
      if (v.layers.values.any((l) => l[s] != null)) return s;
    }
    return 0;
  }

  /// One view of the hull's module layers at [stage]. [front]: only the
  /// bow (the functional face, drawn after the creatures); otherwise every
  /// other module. Modules whose detach order is in [detached] are gone.
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
      if ((m.id == 'bow') != front) continue;
      if (!_assembled(m.id)) continue;
      if (m.detach != null && detached.contains(m.detach)) continue;
      var layers = v.layers[m.id];
      var flip = false;
      if (layers == null && m.id.endsWith('L')) {
        layers = v.layers['${m.id.substring(0, m.id.length - 1)}R'];
        flip = true;
      }
      final sprite = layers?[st];
      if (sprite == null) continue;
      heroSprite(c, sprite, center, opacity: opacity, flipX: flip);
    }
    c.restore();
  }

  /// The hull's layers in [view], crossfading from [previous] by [blend]
  /// (both views share the simulation anchors, so the blend never pops).
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
  }) {
    if (!heroReady) return;
    if (previous != null && previous != view && blend < 1) {
      _paintHeroView(c, center, previous,
          stage: stage, front: front, detached: detached, opacity: opacity);
      _paintHeroView(c, center, view,
          stage: stage, front: front, detached: detached,
          opacity: opacity * blend);
      return;
    }
    _paintHeroView(c, center, view,
        stage: stage, front: front, detached: detached, opacity: opacity);
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
    return [
      for (final p in list) BossHeroPoint(-p.x, p.y, p.kind, p.module),
    ];
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
    for (final (i, n) in heroPoints(director.view, stage, kind: 'nozzles').indexed) {
      if (h.plumes.isEmpty) break;
      final t = burn >= 0 ? burn : thrust(n.x, bank, b.rage);
      final level = t < .42 ? 0 : (t < .72 ? 1 : 2);
      final size = n.kind.clamp(0, h.plumes.length - 1);
      heroSprite(c, h.plumes[size][level][(flick + i) % 2], at + Offset(n.x, n.y),
          opacity: opacity);
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
      opacity: opacity,
    );
    if (damage > .45 && h.breach.isNotEmpty) {
      final fires = heroPoints(director.view, stage, kind: 'fires');
      final count = fires.isEmpty
          ? 0
          : (fires.length * ((damage - .45) / .45)).ceil().clamp(1, fires.length);
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

  /// A cosmetic wreck of the director: a module's wreck sprite (rest, then
  /// tumbled) or an armour plate (a frontal debris piece), sinking into the
  /// fog. [fog] tints it as it goes.
  void paintHeroWreck(Canvas c, BossWreck w, {Color fog = const Color(0xFF2A2436)}) {
    if (!heroReady || !w.started) return;
    final h = hero!;
    final BossHeroSprite? s;
    var flip = false;
    if (w.plate) {
      s = h.debris.isEmpty ? null : h.debris[w.module.hashCode.abs() % h.debris.length];
    } else {
      var frames = h.wrecks[w.module];
      if (frames == null && w.module.length > 1) {
        // A mirrored pair's wreck is stored once: the other side flips it.
        final base = w.module.substring(0, w.module.length - 1);
        final other = w.module.endsWith('R') ? '${base}L' : '${base}R';
        frames = h.wrecks[other];
        flip = frames != null;
      }
      s = frames == null ? null : frames[w.progress > .35 ? 1 : 0] ?? frames[0];
    }
    if (s == null) return;
    c.save();
    c.translate(w.x, w.y);
    c.rotate(w.rotation);
    c.scale(w.scale * (w.plate ? .5 : 1));
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
      final count = (h.fire.length * ((damage - .45) / .45))
          .ceil()
          .clamp(1, h.fire.length);
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
      _block.color = (i == 0 ? const Color(0xFFE8F4FF) : const Color(0xFF8AB4D8))
          .withValues(alpha: .8 - i * .22);
      final w = 2.0 + i;
      c.drawRect(
        Rect.fromLTWH(p.dx + side * (i * 2.5 + f) - (side < 0 ? w : 0),
            p.dy - w / 2, w, w),
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
        heroSprite(c, j[(b.door.clamp(0.0, 1.0) * (j.length - 1)).round()],
            Offset(b.x, b.y));
      }
      return;
    }
    if (!ready) return;
    sprite(c, hull.jaws[(b.door.clamp(0.0, 1.0) * 3).round()], Offset(b.x, b.y));
  }

  /// Bay door frame for one side (the atlas holds the left bay).
  void paintBay(Canvas c, Carrier b, {required bool right, required int frame}) {
    if (heroReady) {
      final v = hero!.vents;
      if (v.isNotEmpty) {
        heroSprite(c, v[frame.clamp(0, v.length - 1)], Offset(b.x, b.y),
            flipX: right);
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
        heroSprite(c, hero!.plumes[0][level][f], center + Offset(x, 30),
            flipY: true);
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
    sprite(c, h.damage[2][((p * 30).floor()) % 2], Offset.zero,
        opacity: (p * 1.2).clamp(.4, 1.0));
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
      final at = pos +
          Offset(side * (50 + i * 12 + p * spread), -10 + p * p * (110 + i * 30));
      c.save();
      c.translate(at.dx, at.dy);
      c.rotate(side * p * (2 + i * .7));
      sprite(c, d, Offset.zero);
      c.restore();
    }
  }
}
