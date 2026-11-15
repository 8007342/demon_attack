import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import 'atmosphere.dart';
import 'ground_blocks_atlas.dart';
import 'ground_blocks_cast.dart';
import 'ground_atmosphere.dart';
import 'ground_heading.dart';
import 'ground_presentation.dart';
import 'model.dart';

/// Per-unit presentation state of a block-drawn ground unit: its cells, its
/// hull and layer trackers, and what the last paint showed. Owned by the
/// painter, keyed by unit id; never read by the simulation.
class GroundBlockTrack {
  GroundBlockTrack(this.owner, this.cells)
      : hull = GroundHeading(cells.unit.headings, _turn(cells.unit),
            initial: _rest(cells.unit), pace: GroundPace.turn),
        art = cells.hasArt
            ? GroundHeading(cells.unit.angles, _turn(cells.unit),
                layer: true, initial: _rest(cells.unit),
                pace: GroundPace.turn)
            : null;

  static GroundTurnClass _turn(GroundBlockUnit u) =>
      GroundBlocks.turn[u.unitClass] ?? GroundBlocks.turn['heavy']!;

  /// Resting heading before any motion: up the plane (Fleet), the travel
  /// heading toward the camera (Host).
  static double _rest(GroundBlockUnit u) =>
      u.faction == 'fleet' ? u.headings.first : u.headings.last;

  /// The simulation object this track belongs to (ids restart each run).
  final Object owner;
  final GroundBlockCells cells;
  final GroundHeading hull;
  final GroundHeading? art;

  /// Last observed lateral position (texels from the plane's centre line)
  /// and depth.
  double? lastX, lastZ;
  int seen = 0;

  /// Most hp seen (damage overlays are fractions of it).
  int maxHp = 1;

  /// Seconds since the last heading step and its direction (skid dust).
  double stepAge = 9;
  int stepDir = 0;

  /// Driving backward (convoy falling back).
  bool reverse = false;

  /// Seconds since a saved squad began its flourish (< 0: none), and how
  /// long it lasts (easter eggs: dance, sector-clear dance, Host jig,
  /// convoy turret twirl).
  double flourish = -1, flourishLen = 1.6;
  bool wasSaved = false;

  /// Easter eggs: the foe last engaged (a won skirmish, an ally falling
  /// back) and whether the sector-clear dance has played.
  Object? lastFoe;
  bool clearDanced = false;

  bool get flourishing => flourish >= 0 && flourish < flourishLen;

  /// Screen muzzle of the layer as last drawn (friendly tracer origin).
  Offset? muzzle;

  /// Last observed velocity (texels/s, lateral and depth; squads' troopers
  /// turn after it) and the eased marching amount (0 holding .. 1).
  double vl = 0, vz = 0, march = 0;
  int marchSeen = -1;

  /// Ground covered on screen (texels at the perspective texel, signed:
  /// negative while backing up), the last screen point, and the walk cycle
  /// it has advanced ([GroundStride]; once per paint).
  double odo = 0, odoUsed = 0, gait = 0;
  double? lastSX, lastSY;
  int gaitSeen = -1;

  /// A squad's troopers, each turning on its own (presentation only), and
  /// where each fallen one lies (offset from the squad, texels).
  final List<GroundSquadMember> members = [];
  final Map<int, (double, double)> lying = {};
}

/// One trooper of a block-drawn squad: its own heading tracker, fed the
/// squad's march through its own lag (it turns a little after another).
class GroundSquadMember {
  GroundSquadMember(this.heading, this.follow);
  final GroundHeading heading;

  /// How quickly it follows the squad's velocity (1/s).
  final double follow;
  double vl = 0, vz = 0;
  int seen = -1;
}

/// Draws ground units from the per-sector ground-block atlases (openspec
/// change ground-blocks-runtime). Presentation only.
class GroundBlocksLayer {
  /// Loaded atlases of [sector] (file name -> image).
  final Map<String, ui.Image> images = {};
  int? sector;
  int? _loading;

  /// Reduced motion: headings still change, skid dust is not drawn.
  bool reducedMotion = false;

  /// Contract tests: every base cell and overlay name requested.
  Set<String>? requested, requestedOverlays;

  final Map<int, GroundBlockTrack> _units = {}, _allies = {};
  final Map<String, (ui.Image, Rect)?> _src = {};
  double _clock = -1, dt = 0;
  int _frame = 0;

  static const _flashTint = Color(0xB8FFFFFF);

  // --- depth fog (plan/ground-atmosphere.md §2): set by [GroundPainter]
  // per unit. [fogTint] null: no tint (no atmosphere art).
  Color? fogTint;
  double fogMix = 0;
  final Paint _paint = Paint()
    ..isAntiAlias = false
    ..filterQuality = FilterQuality.none;

  /// Asset paths (under assets/images/) of a sector's three atlases.
  static List<String> files(int sector) {
    final s = GroundBlocksCast.sectorName(sector);
    return {
      for (final p in GroundBlocks.placement[s]!.values) p.$1,
      for (final p in GroundBlocks.fxRow[s]!.values) p.$1,
    }.map((f) => 'ground-blocks/$f').toList();
  }

  /// Keeps the current level's sector loaded, and only that one.
  void sync(
    ArcadeModel model,
    Future<ui.Image> Function(String asset) load,
    void Function(String asset) evict,
  ) {
    final want = (model.level - 1).clamp(0, GroundBlocks.sectors.length - 1);
    if (sector == want || _loading == want) return;
    _loading = want;
    Future.wait(files(want).map(load)).then((list) {
      if (_loading != want) return;
      final old = sector;
      install(want, {
        for (var i = 0; i < list.length; i++)
          files(want)[i].substring('ground-blocks/'.length): list[i],
      });
      if (old != null && old != want) files(old).forEach(evict);
    }).catchError((Object _) {
      if (_loading == want) _loading = null;
    });
  }

  /// Installs a decoded sector set (also used by tests and review frames).
  void install(int sec, Map<String, ui.Image> atlases) {
    images
      ..clear()
      ..addAll(atlases);
    sector = sec;
    _loading = null;
    _src.clear();
  }

  bool ready(int unitSector) =>
      sector == unitSector && images.isNotEmpty;

  /// Call once per paint, before any unit.
  void begin(double clock) {
    _frame++;
    if (_clock < 0 || clock < _clock || clock - _clock > 1) {
      dt = 0;
      if (clock < _clock) {
        _units.clear();
        _allies.clear();
      }
    } else {
      dt = math.min(clock - _clock, .1);
    }
    _clock = clock;
  }

  /// Call after the paint: drops the state of units no longer drawn.
  void end() {
    _units.removeWhere((_, t) => t.seen != _frame);
    _allies.removeWhere((_, t) => t.seen != _frame);
  }

  // ------------------------------------------------------------- tracks

  GroundBlockTrack? _track(Map<int, GroundBlockTrack> map, int id,
      Object owner, String? unit) {
    if (unit == null) return null;
    var t = map[id];
    if (t == null || !identical(t.owner, owner) || t.cells.id != unit) {
      t = map[id] = GroundBlockTrack(owner, GroundBlockCells(unit));
    }
    return t;
  }

  /// The block unit and track for a demon unit, or null (old atlases).
  GroundBlockTrack? unitTrack(GroundUnit u) {
    if (!ready(u.sector)) return null;
    final role = switch (u.force) {
      GroundForce.vehicle =>
        u.skirmish ? GroundCastRole.skirmishVehicle : GroundCastRole.threat,
      GroundForce.heavyTank => GroundCastRole.heavyTank,
      GroundForce.infantry => GroundCastRole.demonRifle,
      GroundForce.rockets => GroundCastRole.demonRocket,
    };
    return _track(_units, u.id, u,
        GroundBlocksCast.unitFor(role, u.sector, id: u.id));
  }

  /// The block unit and track for an ally, or null (old atlases).
  GroundBlockTrack? allyTrack(GroundAlly a, int variant) {
    if (!ready(a.sector)) return null;
    final role = switch (a.force) {
      GroundForce.infantry => GroundCastRole.allyRifle,
      GroundForce.rockets => GroundCastRole.allyRocket,
      _ => GroundCastRole.convoy,
    };
    return _track(_allies, a.id, a,
        GroundBlocksCast.unitFor(role, a.sector, id: a.id, variant: variant));
  }

  /// The friendly tracer origin of an ally drawn this paint.
  Offset? muzzleOf(GroundAlly a) {
    final t = _allies[a.id];
    return t != null && identical(t.owner, a) && t.seen == _frame
        ? t.muzzle
        : null;
  }

  /// Lateral ground position (texels from the centre line).
  static double _lateral(double x, double z) =>
      (x - 180) / GroundCamera.texel(math.max(z, 1));

  /// Advances the hull tracker from the unit's motion. [face] is a signed
  /// screen angle to square up to when slow; [reversible] lets a convoy
  /// vehicle back up instead of turning round.
  void observe(GroundBlockTrack t, double x, double z,
      {double? face, bool reversible = false}) {
    if (t.seen == _frame) return;
    t.seen = _frame;
    if (t.flourish >= 0) t.flourish += dt;
    final lx = _lateral(x, z);
    final px = t.lastX, pz = t.lastZ;
    // Odometer: screen distance in texels at this depth (feet plant).
    final sy = GroundCamera.yOf(math.max(z, 1));
    final sx0 = t.lastSX, sy0 = t.lastSY;
    t
      ..lastSX = x
      ..lastSY = sy;
    if (sx0 != null && sy0 != null) {
      final d = math.sqrt((x - sx0) * (x - sx0) + (sy - sy0) * (sy - sy0)) /
          GroundCamera.texel(math.max(z, 1));
      t.odo += t.reverse ? -d : d;
    }
    t.lastX = lx;
    t.lastZ = z;
    t.stepAge += dt;
    if (px == null || pz == null || dt <= 0) return;
    var vl = (lx - px) / dt, vz = (z - pz) / dt;
    t
      ..vl = vl
      ..vz = vz;
    final speed = math.sqrt(vl * vl + vz * vz);
    if (reversible && speed >= GroundHeading.vMin) {
      final a = GroundHeading.angleOf(vl, vz);
      t.reverse = a.abs() > 100;
      if (t.reverse) {
        vl = -vl;
        vz = -vz;
      }
    } else if (speed < GroundHeading.vMin) {
      t.reverse = false;
    }
    if (!t.hull.seeded && speed >= GroundHeading.vMin) {
      t.hull.seed(GroundHeading.angleOf(vl, vz));
      t.art?.seed(t.hull.signedAngle);
      return;
    }
    final step = t.hull.update(dt, lateral: vl, depth: vz, face: face);
    if (step != 0) {
      t.stepAge = 0;
      t.stepDir = step;
    }
  }

  /// Walk cycles [t] has advanced, locked to the ground it covered: [s] is
  /// the unit's draw scale at depth [z] (screen pixels per cell texel).
  /// Updated once per paint; every trooper of a squad reads the same clock.
  double gaitOf(GroundBlockTrack t, double s, double z) {
    if (t.gaitSeen != _frame) {
      t.gaitSeen = _frame;
      final u = t.cells.unit;
      final k = s / GroundCamera.texel(math.max(z, 1));
      final travel = k > 0 ? (t.odo - t.odoUsed) / k : 0.0;
      t.odoUsed = t.odo;
      t.gait += GroundStride.cycles(
          travel, GroundStride.of(u), GroundStride.maxOf(u), dt);
    }
    return t.gait;
  }

  /// Eases [t]'s marching amount toward [moving] (once per paint) and
  /// returns it: troopers lead and lag only while the squad marches.
  double marchOf(GroundBlockTrack t, bool moving) {
    if (t.marchSeen != _frame) {
      t.marchSeen = _frame;
      final q = 1 - math.exp(-2.5 * dt);
      t.march += ((moving ? 1.0 : 0.0) - t.march) * q;
    }
    return t.march;
  }

  /// Trooper [k]'s own heading in squad [t] (squad [seed]): it follows the
  /// squad's march through its own lag and holds each heading a little
  /// longer or shorter than the others, so the group turns one by one.
  GroundHeading memberHeading(GroundBlockTrack t, int k, int seed) {
    final u = t.cells.unit;
    while (t.members.length <= k) {
      final (follow, hold) = GroundSquadLook.turn(seed, t.members.length);
      t.members.add(GroundSquadMember(
          GroundHeading(u.headings, GroundBlockTrack._turn(u),
              initial: t.hull.signedAngle, pace: GroundPace.turn, hold: hold),
          follow));
    }
    final m = t.members[k];
    if (m.seen != _frame) {
      m.seen = _frame;
      if (!m.heading.seeded) {
        if (t.hull.seeded) {
          m.heading.seed(t.hull.signedAngle);
          m
            ..vl = t.vl
            ..vz = t.vz;
        }
      } else if (dt > 0) {
        final q = 1 - math.exp(-m.follow * dt);
        m
          ..vl += (t.vl - m.vl) * q
          ..vz += (t.vz - m.vz) * q;
        m.heading.update(dt, lateral: m.vl, depth: m.vz);
      }
    }
    return m.heading;
  }

  /// Advances the layer tracker toward [target] (signed degrees), or the
  /// hull's heading when null.
  void aim(GroundBlockTrack t, double? target) {
    t.art?.update(dt, target: target ?? t.hull.signedAngle);
  }

  /// Signed screen angle from (x, y) to (tx, ty).
  static double angleTo(double x, double y, double tx, double ty) =>
      math.atan2(tx - x, y - ty) * 180 / math.pi;

  // ------------------------------------------------------------- LOD

  /// Hull heading shown at depth [z]: every other heading beyond 1200.
  static (int, bool) hullShown(GroundHeading h, double z) {
    var k = h.index;
    final n = h.ring.steps.length;
    if (z >= 1200 && n >= 9 && k.isOdd) {
      final authored = GroundHeadingRing.signed(h.angle).abs();
      final lo = h.ring.steps.firstWhere((s) => s.index == k - 1);
      final hi = h.ring.steps.firstWhere((s) => s.index == k + 1);
      final dLo = (GroundHeadingRing.signed(lo.u).abs() - authored).abs();
      final dHi = (GroundHeadingRing.signed(hi.u).abs() - authored).abs();
      k = dLo < dHi ? k - 1 : k + 1;
    }
    return (k, h.mirror);
  }

  /// Layer angle shown at depth [z]: a0/a2/a4 from 900, the hull's heading
  /// from 1200.
  static (int, bool) artShown(GroundHeading art, (int, bool) hull, double z,
      List<double> headings, List<double> angles) {
    if (z >= 1200) {
      final a = headings[hull.$1];
      var best = 0;
      for (var i = 1; i < angles.length; i++) {
        if ((angles[i] - a).abs() < (angles[best] - a).abs()) best = i;
      }
      return (best, hull.$2);
    }
    var k = art.index;
    if (z >= 900 && angles.length == 5 && k.isOdd) {
      final a = GroundHeadingRing.signed(art.angle).abs();
      k = (angles[k - 1] - a).abs() < (angles[k + 1] - a).abs() ? k - 1 : k + 1;
    }
    return (k, art.mirror);
  }

  /// Overlays other than `lights` are dropped beyond z 900.
  static bool nearDetail(double z) => z < 900;

  // ------------------------------------------------------------- drawing

  (ui.Image, Rect)? _resolve(String name) {
    final sec = sector;
    if (sec == null) return null;
    return _src.putIfAbsent(name, () {
      final ref = GroundBlocks.cell(GroundBlocksCast.sectorName(sec), name);
      if (ref == null) return null;
      final img = images[ref.file];
      if (img == null) return null;
      final rowH = ref.h == 80 ? 40 : ref.h;
      return (
        img,
        Rect.fromLTWH(ref.col * ref.w * 1.0, ref.row * rowH * 1.0,
            ref.w * 1.0, ref.h * 1.0),
      );
    });
  }

  /// Opacity of the emissive-mask pass for a body at fog [mix]: none in
  /// clear air, rising to one half in the murk (so a warm pixel fogs at
  /// half the body's rate: plan/ground-atmosphere.md §2).
  static double revealAlpha(double mix) =>
      mix <= .1 ? 0 : .5 * ((mix - .1) / .2).clamp(0.0, 1.0);

  void _blit(Canvas c, ui.Image img, Rect src, double left, double top,
      double s, bool mirror, double light, double opacity, bool flash,
      {bool emissive = false, bool tell = false, bool reveal = false}) {
    final w = src.width * s, h = src.height * s;
    final v = (255 * light).round().clamp(0, 255);
    _paint.color =
        Color.fromARGB((255 * opacity).round().clamp(0, 255), v, v, v);
    if (reveal) {
      // The emissive mask (warm eyes, cracks) drawn again over the fogged
      // body: the half-rate rule for pixels baked into the body cell.
      _paint
        ..color = Color.fromRGBO(255, 255, 255, opacity.clamp(0.0, 1.0))
        ..colorFilter = Atmosphere.glowMatrix;
      _draw(c, img, src, left, top, w, h, mirror);
      return;
    }
    final tint = fogTint;
    final mix = tint == null || tell || flash
        ? 0.0
        : emissive
            ? GroundFog.emissive(fogMix)
            : fogMix;
    _paint.colorFilter = flash
        ? const ColorFilter.mode(_flashTint, BlendMode.srcATop)
        : mix > 0
            ? GroundFog.filter(light, mix, tint!)
            : light < .999
                ? ColorFilter.mode(Color.fromARGB(255, v, v, v), BlendMode.modulate)
                : null;
    _draw(c, img, src, left, top, w, h, mirror);
  }

  void _draw(Canvas c, ui.Image img, Rect src, double left, double top,
      double w, double h, bool mirror) {
    final l = left.roundToDouble(), t = top.roundToDouble();
    if (mirror) {
      c.save();
      c.translate(l + w, t);
      c.scale(-1, 1);
      c.drawImageRect(img, src, Rect.fromLTWH(0, 0, w, h), _paint);
      c.restore();
    } else {
      c.drawImageRect(img, src, Rect.fromLTWH(l, t, w, h), _paint);
    }
  }

  /// Draws cell [name] with its point [at] (texels from the cell's top-left,
  /// default the unit's hull origin) on screen point ([ax], [ay]).
  /// Returns false when the cell is not in the loaded atlases.
  bool cell(Canvas c, GroundBlockUnit u, String name, double ax, double ay,
      double s,
      {bool mirror = false,
      double light = 1,
      double opacity = 1,
      bool flash = false,
      bool overlay = false,
      bool emissive = false,
      bool tell = false,
      bool reveal = false,
      (double, double)? at}) {
    (overlay ? requestedOverlays : requested)?.add(name);
    final src = _resolve(name);
    if (src == null || opacity <= 0) return false;
    final tl = topLeft(src.$2.width, at ?? u.origin, mirror, ax, ay, s);
    _blit(c, src.$1, src.$2, tl.dx, tl.dy, s, mirror, light, opacity, flash,
        emissive: emissive, tell: tell);
    final r = revealAlpha(fogTint == null || flash ? 0 : fogMix);
    if (reveal && r > 0) {
      _blit(c, src.$1, src.$2, tl.dx, tl.dy, s, mirror, light, opacity * r,
          false, reveal: true);
    }
    return true;
  }

  /// Screen top-left of a cell [width] texels wide whose point [at] (texels
  /// from its top-left) lands on ([ax], [ay]); mirrored about that point.
  static Offset topLeft(double width, (double, double) at, bool mirror,
      double ax, double ay, double s) {
    final x = mirror ? width - at.$1 : at.$1;
    return Offset(ax - x * s, ay - at.$2 * s);
  }

  /// One fx-row cell of [faction] (0-3 skid dust, 4-7 dust ring, 8-10
  /// muzzle ring, 11-13 shards), centred on ([cx], [cy]).
  void fx(Canvas c, String faction, int col, double cx, double cy, double s,
      {double light = 1,
      double opacity = 1,
      bool mirror = false,
      bool emissive = false}) {
    final sec = sector;
    if (sec == null) return;
    final row = GroundBlocks.fxRow[GroundBlocksCast.sectorName(sec)]?[faction];
    final img = row == null ? null : images[row.$1];
    if (row == null || img == null) return;
    final src = Rect.fromLTWH(col * 48.0, row.$2 * 40.0, 48, 40);
    _blit(c, img, src, cx - 24 * s, cy - 20 * s, s, mirror, light, opacity,
        false, emissive: emissive);
  }

  /// A debris piece [j] of [t]'s unit (16 x 20 sub-cells, 6 per sheet),
  /// centred on ([cx], [cy]) and turned by [quarter] quarter turns.
  bool piece(Canvas c, GroundBlockTrack t, int j, double cx, double cy,
      double s, int quarter,
      {double light = 1, double opacity = 1, bool emissive = false}) {
    final pieces = t.cells.unit.pieces;
    if (pieces.isEmpty) return false;
    final k = j % pieces.length;
    final name = t.cells.debris(k ~/ 6);
    if (name == null) return false;
    requested?.add(name);
    final src = _resolve(name);
    if (src == null) return false;
    final sub = k % 6;
    final r = Rect.fromLTWH(
        src.$2.left + (sub % 3) * GroundBlocks.debrisSubW,
        src.$2.top + (sub ~/ 3) * GroundBlocks.debrisSubH,
        GroundBlocks.debrisSubW * 1.0,
        GroundBlocks.debrisSubH * 1.0);
    c.save();
    c.translate(cx.roundToDouble(), cy.roundToDouble());
    if (quarter % 4 != 0) c.rotate((quarter % 4) * math.pi / 2);
    _blit(c, src.$1, r, -r.width / 2 * s, -r.height / 2 * s, s, false, light,
        opacity, false, emissive: emissive);
    c.restore();
    return true;
  }

  // ------------------------------------------------------------- vehicles

  /// Slope along the nose: > 0 climbing.
  static double _slope(GroundPose? pose, double heading) =>
      (pose?.climb ?? 0) * -math.cos(heading * math.pi / 180);

  /// Ford band and crest hop: no simulation source yet (hooks).
  bool fording(Object unit) => false;
  bool airborne(Object unit) => false;

  /// Seconds into an unearthing arrival, or null (the runtime fog and
  /// arrival work owns when a unit unearths).
  double? arrivalAge(GroundUnit u) => null;

  /// The hull cell for a moving or resting vehicle at shown heading [k].
  String _hullCell(GroundBlockTrack t, Object unit, int k, double heading,
      GroundPose? pose, int phase, bool moving) {
    final cells = t.cells;
    if (fording(unit) && cells.frames('ford', k) > 0) {
      return cells.hull('ford', k, phase ~/ 2);
    }
    if (airborne(unit) && cells.frames('air', k) > 0) {
      return cells.hull('air', k, 0);
    }
    final slope = _slope(pose, heading);
    if (slope > .1 && cells.frames('pitchUp', k) > 0) {
      return cells.hull('pitchUp', k, 0);
    }
    if (slope < -.1 && cells.frames('pitchDown', k) > 0) {
      return cells.hull('pitchDown', k, 0);
    }
    if (!moving && cells.frames('idle', k) > 0) {
      return cells.hull('idle', k, (_clock * 2.5 * GroundPace.of(t.cells.unit)).floor());
    }
    return cells.hull('move', k, moving ? phase : 0);
  }

  /// Skid dust on the outside of a turn, for a short while after a step.
  void _skid(Canvas c, GroundBlockTrack t, double x, double y, double s,
      double light, int k) {
    const life = .32 / GroundPace.fx;
    if (reducedMotion || t.stepAge > life || t.stepDir == 0) return;
    final q = t.stepAge / life;
    final w = t.cells.unit.size[k].$1 / 2;
    final side = t.stepDir * (t.hull.mirror ? 1 : -1);
    fx(c, t.cells.unit.faction, (q * 4).floor().clamp(0, 3),
        x + side * w * s, y - 2 * s, s * .8,
        light: light * .85, opacity: (1 - q) * .8);
  }

  /// Draws a living demon vehicle (threat, skirmish or heavy tank).
  void demonVehicle(Canvas c, GroundUnit u, GroundBlockTrack t, double clock,
      double light, double glow, ArcadeModel m) {
    final s = u.scale * GroundSize.hostVehicle;
    final unit = t.cells.unit;
    t.maxHp = math.max(t.maxHp, math.max(u.hp, u.maxHp));
    final foe = u.ally;
    final engaged = foe != null && foe.alive;
    observe(t, u.x, u.z,
        face: engaged ? angleTo(u.x, u.bodyY, foe.x, foe.bodyY) : null);
    final hull = hullShown(t.hull, u.z);
    var (k, mirror) = hull;
    final moving = u.z > u.holdZ + 1 || u.vx.abs() > 2 || !u.skirmish;
    final rate = unit.unitClass == 'heavy' ? 8.0 : 10.0;
    var phase = GroundPace.isWalker(unit) && moving
        // Feet plant: the stride follows the ground covered.
        ? (gaitOf(t, s, u.z) * t.cells.moveFrames(k) + u.id * .37).floor()
        : (clock * rate * GroundPace.of(unit) * (moving ? 1 : .6) + u.id * .37)
            .floor();
    // The telegraph contract (old columns 4-7): same clock arithmetic.
    int? special;
    var fill = 0;
    if (unit.threat && !u.skirmish) {
      if (u.fireFlash > GroundTuning.fireFlash * .5) {
        special = 2;
        fill = 3;
      } else if (u.fireFlash > 0) {
        special = 3;
      } else if (u.telegraphing) {
        final p = u.telegraphProgress;
        special = p < .45
            ? 0
            : ((clock * (p > .8 ? 16 : 8)).floor().isEven ? 1 : 0);
        fill = p < .33 ? 1 : (p < .66 ? 2 : 3);
      }
    } else if (engaged && u.tracerLeft < .5) {
      fill = u.tracerLeft < .17 ? 3 : (u.tracerLeft < .33 ? 2 : 1);
    }
    if (u.fireFlash > 0 && fill == 0) fill = 3;
    final near = nearDetail(u.z);
    final flash = u.lastHit >= 0 && u.lastHit < .12;
    final arrive = arrivalAge(u);
    if (arrive != null && t.cells.headingOf('arrive') != null) {
      final f = arrive < .2 ? 0 : (arrive < .34 ? 1 : (arrive < .48 ? 2 : 3));
      final (name, _) = t.cells.state('arrive', k, f);
      cell(c, unit, name, u.x, u.y, s, mirror: mirror, light: light);
      return;
    }
    if (moving) _skid(c, t, u.x, u.y, s, light, k);
    String name;
    var composite = false;
    if (special != null) {
      final (n, at) = t.cells.state('special', k, special);
      name = n;
      k = at;
      composite = true;
    } else {
      name = _hullCell(t, u, k, unit.headings[k] * (mirror ? -1 : 1), u.pose,
          phase, moving);
    }
    cell(c, unit, name, u.x, u.y, s,
        mirror: mirror, light: light, flash: flash, reveal: true);
    _hullOverlays(c, t, k, mirror, u.x, u.y, s, light, glow, clock,
        near: near, hp: u.hp, seed: u.id, fill: t.cells.hasArt ? 0 : fill, flare: fill > 1);
    if (!t.cells.hasArt) return;
    // The articulated layer: toward the foe, the ship while telegraphing.
    final pv = _pivot(unit, k, mirror, u.x, u.y, s, phase, moving);
    double? target;
    if (special != null) {
      target = angleTo(pv.dx, pv.dy, m.shipX, ArcadeModel.shipY);
    } else if (engaged) {
      target = angleTo(pv.dx, pv.dy, foe.x, foe.bodyY);
    }
    aim(t, target);
    var (a, am) = artShown(t.art!, hull, u.z, unit.headings, unit.angles);
    if (composite) {
      // The special cell holds the layer already; only its fill shows.
      a = k.clamp(0, unit.angles.length - 1);
      am = mirror;
    } else {
      final kick = (u.fireFlash / .12).clamp(0.0, 1.0);
      _art(c, t, a, am, pv, s, light, flash: flash, recoil: kick * 1);
    }
    if (near && fill > 0) {
      final o = t.cells.artOverlay('fill$fill', a);
      if (o != null) {
        cell(c, unit, o, pv.dx, pv.dy, s,
            mirror: am, light: glow, overlay: true, tell: true,
            at: unit.artPivot);
      }
    }
  }

  /// Screen point of the layer pivot at shown heading [k].
  Offset _pivot(GroundBlockUnit u, int k, bool mirror, double x, double y,
      double s, int phase, bool moving) =>
      pivotAt(u, k, mirror, x, y, s,
          u.bob.isEmpty || !moving ? 0.0 : u.bob[phase % u.bob.length]);

  /// The layer pivot on screen for a hull anchored at ([x], [y]) showing
  /// heading [k], lifted by the walker [bob] (texels).
  static Offset pivotAt(GroundBlockUnit u, int k, bool mirror, double x,
      double y, double s, [double bob = 0]) {
    final (dx, dy) = u.pivot[k];
    return Offset(x + (mirror ? -dx : dx) * s, y - (dy + bob) * s);
  }

  /// The layer cell at angle [a] on pivot [pv], kicked back by [recoil]
  /// texels along its angle; records the muzzle.
  void _art(Canvas c, GroundBlockTrack t, int a, bool mirror, Offset pv,
      double s, double light,
      {bool flash = false, double recoil = 0, bool fire = false,
      int elevation = 0, double opacity = 1}) {
    final u = t.cells.unit;
    final ang = u.angles[a] * (mirror ? -1 : 1) * math.pi / 180;
    final back = recoil * s;
    final ox = -math.sin(ang) * back, oy = math.cos(ang) * back;
    cell(c, u, t.cells.art(a, fire: fire, elevation: elevation),
        pv.dx + ox, pv.dy + oy, s,
        mirror: mirror, light: light, flash: flash, opacity: opacity,
        at: u.artPivot);
    final (mx, my) = u.muzzle[a];
    t.muzzle = Offset(pv.dx + ox + (mirror ? -mx : mx) * s, pv.dy + oy - my * s);
  }

  void _hullOverlays(Canvas c, GroundBlockTrack t, int k, bool mirror,
      double x, double y, double s, double light, double glow, double clock,
      {required bool near, required int hp, int seed = 0, int fill = 0, bool flare = false,
      bool flicker = false}) {
    final u = t.cells.unit;
    final lights = t.cells.hullOverlay('lights', k);
    final ac = clock * GroundPace.anim;
    if (lights != null && !(flicker && (ac * 9).floor() % 3 == 0)) {
      final pulse = u.faction == 'host' && !flare
          ? .6 + .4 * (.5 + .5 * math.sin(ac * 3 + seed * 1.3))
          : 1.0;
      cell(c, u, lights, x, y, s,
          mirror: mirror, light: glow, opacity: pulse, overlay: true,
          emissive: true);
    }
    if (!near) return;
    final frac = hp / math.max(1, t.maxHp);
    final dmg = frac <= 1 / 3 ? 2 : (frac <= 2 / 3 ? 1 : 0);
    if (dmg > 0) {
      final o = t.cells.hullOverlay('dmg$dmg', k);
      if (o != null) {
        cell(c, u, o, x, y, s, mirror: mirror, light: light, overlay: true);
      }
    }
    if (fill > 0) {
      final o = t.cells.hullOverlay('fill$fill', k);
      if (o != null) {
        cell(c, u, o, x, y, s,
            mirror: mirror, light: glow, overlay: true, tell: true);
      }
    }
  }

  /// A destroyed Host unit's hulk: wreck A/B, then cooling rubble (the
  /// Chapterhouse falls instead). Effects around it are the old ones.
  void hulk(Canvas c, GroundUnit u, GroundBlockTrack t, double clock,
      double light, double opacity) {
    final unit = t.cells.unit;
    final tt = u.wreckAge;
    final fc = clock * GroundPace.fx;
    final (k, mirror) = (t.hull.index, t.hull.mirror);
    String name;
    if (t.cells.headingOf('fall') != null && unit.block == 'K') {
      // The fall at half speed: 2 s of the wreck's 6.
      final ft = tt * GroundPace.fx;
      name = ft < 1
          ? t.cells.state('fall', k, (ft / .2).floor().clamp(0, 4)).$1
          : t.cells.state('rubble', k, (fc * 3).floor()).$1;
    } else if (t.cells.headingOf('wreck') != null) {
      name = tt < 2.5
          ? t.cells.state('wreck', k, (fc * 8).floor()).$1
          : t.cells.state('rubble', k, tt < 3.8 ? 0 : 1).$1;
    } else {
      name = t.cells.hull('move', k, 0);
    }
    t.seen = _frame;
    cell(c, unit, name, u.x, u.y, u.scale * GroundSize.hostVehicle,
        mirror: mirror, light: light, opacity: opacity);
  }

  // ------------------------------------------------------------- allies

  /// A convoy vehicle (or walker) of the Fleet.
  void convoy(Canvas c, GroundAlly a, GroundBlockTrack t, double clock,
      double light, double glow) {
    final s = a.scale * GroundSize.fleetVehicle;
    final unit = t.cells.unit;
    t.maxHp = math.max(t.maxHp, math.max(a.hp, GroundTuning.allyHp));
    final foe = a.attacker;
    final live = foe != null && !(foe.destroyed && foe.wreckAge > 1.2);
    double? face;
    if (live && unit.unitClass == 'heavy' && a.vz == 0) {
      final f = angleTo(a.x, a.bodyY, foe.x, foe.bodyY);
      if ((f - t.hull.signedAngle).abs() > 67.5) face = f;
    }
    observe(t, a.x, a.z, face: face, reversible: true);
    final hull = hullShown(t.hull, a.z);
    final (k, mirror) = hull;
    final moving = a.vz != 0 || a.vx.abs() > 3;
    final turning = t.hull.hold > 0;
    final rate = (7 + math.min(10.0, a.vz.abs() * .05)) *
        (a.pose?.pace ?? 1) *
        GroundPace.of(unit) *
        (moving ? 1 : (turning ? .6 : 0));
    final dir = t.reverse ? -1 : 1;
    final n = math.max(1, t.cells.moveFrames(k));
    // Feet plant: a walker's stride follows the ground covered (signed).
    final step = GroundPace.isWalker(unit) && moving
        ? gaitOf(t, s, a.z) * n
        : clock * rate * dir;
    final phase = (((step + a.id * .37).floor()) % n + n) % n;
    final kick = (a.recoil / .14).clamp(0.0, 1.0);
    final near = nearDetail(a.z);
    final flash = a.flash > 0;
    if (moving || turning) _skid(c, t, a.x, a.y, s, light, k);
    final name = _hullCell(t, a, k, unit.headings[k] * (mirror ? -1 : 1),
        a.pose, phase, moving || turning);
    // Easter egg: a one-texel hull hop on beat 3 of the twirl.
    final hop = t.flourishing &&
            t.flourish >= .36 / GroundPace.egg &&
            t.flourish < .48 / GroundPace.egg
        ? s.roundToDouble()
        : 0.0;
    cell(c, unit, name, a.x, a.y + (kick > .5 ? s * .5 : 0) - hop, s,
        mirror: mirror, light: light, flash: flash);
    _hullOverlays(c, t, k, mirror, a.x, a.y, s, light, glow, clock,
        near: near, hp: a.hp);
    if (flash) {
      final f = ((1 - a.flash / .15) * 3).floor().clamp(0, 2);
      fx(c, 'fleet', 11 + f, a.x, a.y - 9 * s, s * .8,
          light: glow, emissive: true);
    }
    if (!t.cells.hasArt) return;
    final pv = _pivot(unit, k, mirror, a.x, a.y, s, phase, moving);
    double? target;
    var elevation = 0;
    if (live) {
      target = angleTo(pv.dx, pv.dy, foe.x, foe.bodyY);
      final gap = foe.z - a.z;
      elevation = gap > 500 ? 2 : (gap > 300 ? 1 : 0);
    } else {
      // Idle scan: a slow look outward and back, relative to the hull.
      final scan = math.sin(clock * .7 * GroundPace.anim + a.id * 1.7);
      target = t.hull.signedAngle +
          (scan > .55 ? (a.side == 0 ? -22.5 : 22.5) : 0);
    }
    aim(t, target);
    var (ai, am) = artShown(t.art!, hull, a.z, unit.headings, unit.angles);
    if (t.flourishing) {
      // Easter egg: a turret twirl a0 -> a4 -> a0 (no new art).
      final n = unit.angles.length;
      final cyc = math.max(1, 2 * (n - 1));
      final p = (t.flourish * GroundPace.egg / .08).floor() % cyc;
      ai = p < n ? p : cyc - p;
      am = mirror;
    }
    _art(c, t, ai, am, pv, s, light,
        flash: flash,
        recoil: kick * 2,
        fire: kick > .5,
        elevation: elevation);
    if (near && t.maxHp > 0 && a.hp / t.maxHp <= 2 / 3) {
      final o = t.cells.artOverlay('dent', ai);
      if (o != null) {
        cell(c, unit, o, pv.dx, pv.dy, s,
            mirror: am, light: light, overlay: true, at: unit.artPivot);
      }
    }
  }

  /// A totalled convoy vehicle: track thrown, then limping off; the turret
  /// askew; every other crew in a pod.
  void totalled(Canvas c, GroundAlly a, GroundBlockTrack t, double clock,
      double light, double glow) {
    final s = a.scale * GroundSize.fleetVehicle, tt = a.retreatAge;
    final unit = t.cells.unit;
    t.seen = _frame;
    t.muzzle = null;
    final ac = clock * GroundPace.of(unit);
    final hop = ((ac * 9).floor().isEven ? 0.0 : -s).roundToDouble();
    final mirror = a.side == 1;
    final f = (ac * 7).floor() % 2 + (tt < .5 ? 0 : 2);
    final (name, k) = t.cells.state('totalled', 0, f);
    cell(c, unit, name, a.x, a.y + hop, s, mirror: mirror, light: light);
    _hullOverlays(c, t, k, mirror, a.x, a.y + hop, s, light, glow, clock,
        near: nearDetail(a.z), hp: 0, flicker: true);
    if (t.cells.hasArt) {
      final pv = _pivot(unit, k, mirror, a.x, a.y + hop + s, s, 0, false);
      _art(c, t, 1.clamp(0, unit.angles.length - 1), a.side == 0, pv, s,
          light * .75);
      t.muzzle = null;
    }
  }

  /// The crew's escape pod (lit and dark alternately).
  void pod(Canvas c, GroundAlly a, GroundBlockTrack t, double x, double y,
      double clock) {
    final (name, _) =
        t.cells.state('pod', 0, (clock * 6 * GroundPace.anim).floor());
    cell(c, t.cells.unit, name, x, y, a.scale * GroundSize.fleetVehicle,
        mirror: a.side == 1);
  }

  // ------------------------------------------------------------- infantry

  /// Demon trooper [k] of a squad (member 0 may be a different unit: the
  /// leader). [fallen] is seconds since it fell (null: standing). [seed]
  /// keys the trooper's own gait and turn.
  void demonTrooper(Canvas c, GroundUnit u, GroundBlockTrack squad, int k,
      int members, double x, double y, double s, double clock, double light,
      {double? fallen, required bool fires, required bool moving,
      required bool engaged, double opacity = 1, int seed = 0}) {
    final id = GroundBlocksCast.unitFor(
            u.force == GroundForce.rockets
                ? GroundCastRole.demonRocket
                : GroundCastRole.demonRifle,
            u.sector,
            id: u.id,
            member: k,
            members: members) ??
        squad.cells.id;
    final cells = id == squad.cells.id ? squad.cells : _cells(id);
    final (h, mirror) = hullShown(memberHeading(squad, k, seed), u.z);
    final ac = clock * GroundPace.anim;
    String name;
    if (fallen != null) {
      // The topple at half speed.
      final ft = fallen * GroundPace.anim;
      name = ft < .35
          ? cells.state('fall', h, ft < .17 ? 0 : 1).$1
          : (cells.headingOf('rubble') != null
              ? cells.state('rubble', h, 0).$1
              : cells.state('fall', h, 1).$1);
    } else if (fires) {
      name = cells.state('fire', h, 0).$1;
    } else if (squad.flourishing && !moving && !engaged &&
        cells.headingOf('flourish') != null) {
      // Easter egg: the taunt jig, one frame of ripple per trooper.
      name = cells.state('flourish', h,
              (squad.flourish * GroundPace.egg / .12).floor() + k)
          .$1;
    } else if (engaged && !moving) {
      name = cells.state('aim', h, u.tracerLeft < .25 ? 1 : 0).$1;
    } else if (moving) {
      // Feet plant: the walk follows the ground the squad covers.
      final (rate, phase) = GroundSquadLook.gait(seed, k);
      final n = math.max(1, cells.moveFrames(h));
      name = cells.hull(
          'walk', h, (gaitOf(squad, s, u.z) * n * rate + phase).floor());
    } else {
      name = cells.state('idle', h, (ac * 2.5 + k * .5).floor()).$1;
    }
    cell(c, cells.unit, name, x, y, s,
        mirror: mirror, light: light, opacity: opacity, reveal: fallen == null);
  }

  /// Allied trooper [k] of a squad of [n] ([seed]: its gait and turn).
  void allyTrooper(Canvas c, GroundAlly a, GroundBlockTrack squad, int k,
      int n, double x, double y, double s, double clock, double light,
      {required bool moving, required double kick, int seed = 0}) {
    final cells = squad.cells;
    final (h, mirror) = hullShown(memberHeading(squad, k, seed), a.z);
    final ac = clock * GroundPace.anim;
    final (rate, phase) = GroundSquadLook.gait(seed, k);
    String name;
    if (a.totalled || a.fallingBack) {
      name = cells.state('run', h, (ac * 10 * rate + phase).floor()).$1;
    } else if (a.flash > 0 && k == a.id % n) {
      name = cells.state('hit', h, 0).$1;
    } else if (kick > 0 && k == (a.id + (ac * 3).floor()) % n) {
      name = cells.state('fire', h, 0).$1;
    } else if (a.underAttack && !moving) {
      name = cells.state('aim', h, kick > 0 ? 1 : 0).$1;
    } else if (squad.flourishing && !moving) {
      // 4 frames at 0.24 s, each trooper a frame behind the one before.
      name = cells.state('flourish', h,
              (squad.flourish * GroundPace.egg / .12).floor() + k)
          .$1;
    } else if (moving) {
      // Feet plant: the walk follows the ground the squad covers.
      final n = math.max(1, cells.moveFrames(h));
      name = cells.hull(
          'walk', h, (gaitOf(squad, s, a.z) * n * rate + phase).floor());
    } else {
      name = cells.state('idle', h, (ac * 2.5 + k * .5).floor()).$1;
    }
    cell(c, cells.unit, name, x, y, s, mirror: mirror, light: light);
  }

  /// Squad trackers: heading from the squad's motion; the saved flourish
  /// ([dances] is asked once, when the squad is saved).
  void observeSquad(GroundBlockTrack t, double x, double z,
      {bool saved = false, bool Function()? dances}) {
    observe(t, x, z);
    if (saved && !t.wasSaved && (dances?.call() ?? false)) startFlourish(t);
    t.wasSaved = saved;
  }

  /// Starts a flourish (dance, jig or turret twirl) of [len] seconds (the
  /// authored 1.6 s dance played at [GroundPace.egg]).
  void startFlourish(GroundBlockTrack t, [double len = 1.6 / GroundPace.egg]) {
    t
      ..flourish = 0
      ..flourishLen = len;
  }

  // ------------------------------------------------------------- jackpot

  /// Pieces that can serve as the popped head of a vehicle with no layer.
  static const headPieces = ['turret', 'gun', 'head', 'hood', 'heads'];

  /// The cell drawn as a popped turret: the layer at its middle angle, else
  /// the first head-like debris piece (index into the unit's pieces).
  static (String?, int) jackpotHead(GroundBlockCells cells) {
    final u = cells.unit;
    if (cells.hasArt) return (cells.art(u.angles.length ~/ 2), -1);
    for (final p in headPieces) {
      final i = u.pieces.indexOf(p);
      if (i >= 0) return (null, i);
    }
    return (null, u.pieces.isEmpty ? -1 : 0);
  }

  /// The crew unit of a light Host vehicle in [sector]: Rubblings.
  static String crewUnit(int sector) {
    final s = GroundBlocksCast.sectorName(sector);
    return GroundBlocks.placement[s]!.containsKey('rubbling')
        ? 'rubbling'
        : GroundBlocksCast.unitFor(GroundCastRole.demonRifle, sector)!;
  }

  /// A whole cell centred on ([cx], [cy]) turned by [quarter] quarter turns.
  bool spinCell(Canvas c, GroundBlockUnit u, String name, double cx,
      double cy, double s, int quarter, {double light = 1, double opacity = 1}) {
    requested?.add(name);
    final src = _resolve(name);
    if (src == null || opacity <= 0) return false;
    final r = src.$2;
    c.save();
    c.translate(cx.roundToDouble(), cy.roundToDouble());
    if (quarter % 4 != 0) c.rotate((quarter % 4) * math.pi / 2);
    _blit(c, src.$1, r, -r.width / 2 * s, -r.height / 2 * s, s, false, light,
        opacity, false);
    c.restore();
    return true;
  }

  /// Screen point of the popped turret [tt] seconds into the wreck, and
  /// whether it is still in the air (two arcs: 40% restitution).
  static (double dx, double h, bool flying) jackpotArc(double tt) {
    const g = 150.0, v0 = 72.0, start = .12;
    const land1 = 2 * v0 / g, v1 = v0 * .4, land2 = 2 * v1 / g;
    final p = tt - start;
    if (p <= 0) return (0, 0, true);
    final travel = math.min(p, land1 + land2);
    if (p < land1) return (travel * 10, v0 * p - .5 * g * p * p, true);
    if (p < land1 + land2) {
      final q = p - land1;
      return (travel * 10, v1 * q - .5 * g * q * q, true);
    }
    return (travel * 10, 0, false);
  }

  /// The jackpot breakup of a light Host vehicle: its turret (or head)
  /// pops high, spins in quarter turns, bounces once and lands upright; a
  /// crew of two climbs out, looks at it and scampers off outward.
  void jackpot(Canvas c, GroundUnit u, GroundBlockTrack t, double clock,
      double light, double glow) {
    // The whole breakup at half speed (5.2 s of the wreck's 6).
    final tt = u.wreckAge * GroundPace.egg;
    if (tt > 2.6) return;
    final s = u.scale * GroundSize.hostVehicle;
    final out = u.x < 180 ? -1.0 : 1.0;
    double clip(double x, double y) => y <= 300
        ? x
        : (u.x < GroundCamera.laneLeft
            ? math.min(x, GroundCamera.laneLeft - 2)
            : (u.x > GroundCamera.laneRight
                ? math.max(x, GroundCamera.laneRight + 2)
                : x));
    final (dx, h, flying) = jackpotArc(tt);
    if (tt > .12) {
      final y = u.y - 6 * s - h * s;
      final x = clip(u.x + out * dx * s, y);
      final quarter = flying ? (tt * 10).floor() : 0;
      final fade = ((2.6 - tt) / .4).clamp(0.0, 1.0);
      final (art, piece) = jackpotHead(t.cells);
      if (art != null) {
        spinCell(c, t.cells.unit, art, x, y, s, quarter,
            light: flying ? glow : light, opacity: fade);
      } else if (piece >= 0) {
        this.piece(c, t, piece, x, y, s, quarter,
            light: flying ? glow : light, opacity: fade);
      }
    }
    final crew = _cells(crewUnit(u.sector));
    final cs = u.scale * .9 * GroundSize.trooper;
    final turretX = u.x + out * jackpotArc(9).$1 * s;
    for (var i = 0; i < 2; i++) {
      final e = tt - 1.1 - .15 * i;
      if (e < 0) continue;
      final side = i == 0 ? -1.0 : 1.0;
      var x = u.x + side * 4 * s;
      final y = u.y + (i == 0 ? 1 : 2) * s;
      String name;
      var mirror = out < 0;
      if (e < .45) {
        name = crew.state('arrive', 0, (e / .15).floor().clamp(0, 2)).$1;
      } else if (e < .8) {
        // Looks at the turret.
        name = crew.state('idle', 0, 0).$1;
        mirror = turretX < x;
      } else {
        x += out * 30 * (e - .8) * cs;
        name = crew.state('run', 0, (clock * 10 * GroundPace.anim + i).floor()).$1;
      }
      final fade = ((2.6 - tt) / .35).clamp(0.0, 1.0);
      cell(c, crew.unit, name, clip(x, y), y, cs,
          mirror: mirror, light: light, opacity: fade);
    }
  }

  final Map<String, GroundBlockCells> _cellCache = {};
  GroundBlockCells _cells(String id) =>
      _cellCache.putIfAbsent(id, () => GroundBlockCells(id));
}
