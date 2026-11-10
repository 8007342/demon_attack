import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import 'boss_atlas.dart';
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
  bool get ready => image != null && loadedClass != null;

  /// Installs an already decoded atlas (tests and the gallery).
  void setAtlas(int cls, ui.Image atlas) {
    image = atlas;
    loadedClass = cls;
  }

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
      if (image != null && loadedClass != null) {
        evict(BossAtlas.classes[loadedClass!].asset);
        image = null;
        loadedClass = null;
      }
      return;
    }
    if (loadedClass == want || _loading == want) return;
    _loading = want;
    load(BossAtlas.classes[want].asset).then((img) {
      if (_loading != want) return;
      final old = loadedClass;
      image = img;
      loadedClass = want;
      _loading = null;
      if (old != null && old != want) evict(BossAtlas.classes[old].asset);
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
    if (!ready) return;
    sprite(c, hull.jaws[(b.door.clamp(0.0, 1.0) * 3).round()], Offset(b.x, b.y));
  }

  /// Bay door frame for one side (the atlas holds the left bay).
  void paintBay(Canvas c, Carrier b, {required bool right, required int frame}) {
    if (!ready) return;
    sprite(c, hull.vents[frame], Offset(b.x, b.y), flipX: right);
  }

  /// Bow retro-thrusters braking the arrival: plumes pointing down from the
  /// bow corners, longest at the start of the descent.
  void paintRetro(Canvas c, Offset center, double descent, double clock) {
    if (!ready || descent <= .05) return;
    final h = hull;
    final level = descent > .6 ? 2 : (descent > .3 ? 1 : 0);
    final f = (clock * 12).floor() % 2;
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
