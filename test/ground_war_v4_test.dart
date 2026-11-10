import 'dart:ui';

import 'package:demon_attack/game/ground_painter.dart';
import 'package:demon_attack/game/model.dart';
import 'package:flutter_test/flutter_test.dart';

/// Ground war v4 rules: the skirmish layer, mixed forces by level, full-width
/// manoeuvre, the convoy's fall-back and repair, and the plant depth sort.
ArcadeModel fly(int sector, double seconds,
    {Difficulty d = Difficulty.normal, void Function(ArcadeModel m)? each}) {
  final m = ArcadeModel(seed: 1982)..startAt(difficulty: d, sector: sector);
  var next = 0.0;
  for (var f = 0; f < (seconds * 60).round() && m.level == sector; f++) {
    if (m.combat) {
      m.invulnerable = 2;
      if (m.levelClock >= next) {
        next = m.levelClock + 2.5;
        final t = m.demons.where((x) => !x.entering).firstOrNull;
        if (t != null) m.hitDemon(t, damage: 99);
      }
    }
    m.update(1 / 60);
    each?.call(m);
  }
  return m;
}

class _Plants implements GroundOccluders {
  _Plants(this.groundPlants);
  @override
  final List<(double, Rect)> groundPlants;
  final painted = <int>[];
  @override
  void paintGroundPlant(Canvas c, int index) => painted.add(index);
}

void main() {
  test('skirmishes never threaten the ship, never pass their hold line', () {
    var minZ = double.infinity;
    final m = fly(2, 90, each: (m) {
      for (final u in m.ground.units) {
        if (u.skirmish && u.alive && u.z < minZ) minZ = u.z;
        if (u.skirmish) {
          expect(u.shotsLeft, 0);
          expect(u.brokeThrough || u.threatening, isFalse);
        }
      }
    });
    expect(m.ground.skirmish.spawned, greaterThanOrEqualTo(8));
    expect(minZ, greaterThan(GroundTuning.fireZ));
    expect(m.ground.missilesLaunched, 0);
    expect(m.ground.alliesRetreated, 0, reason: 'a skirmish never totals an ally');
    expect(m.ground.skirmish.killedByAllies, greaterThan(5));
  });

  test('variety arrives progressively by level, on both sides', () {
    Set<GroundForce> demons(int s) => {
          for (final f in SkirmishFront.of(Difficulty.normal, route: 0, sector: s).forces) f,
        };
    Set<GroundForce> allies(int s) => {
          for (final f in SkirmishFront.of(Difficulty.normal, route: 0, sector: s).allyForces) f,
        };
    expect(demons(1), {GroundForce.vehicle, GroundForce.infantry});
    expect(allies(1), {GroundForce.vehicle, GroundForce.infantry});
    expect(demons(2), contains(GroundForce.rockets));
    expect(allies(2), contains(GroundForce.rockets));
    expect(demons(2), isNot(contains(GroundForce.heavyTank)));
    expect(demons(3), contains(GroundForce.heavyTank));
    expect(demons(4).length, 4);
    expect(SkirmishFront.of(Difficulty.normal, route: 0, sector: 5).active, isTrue);
    // A live level fields them all.
    final seen = <GroundForce>{}, allySeen = <GroundForce>{};
    fly(4, 80, each: (m) {
      for (final u in m.ground.units) {
        if (u.alive) seen.add(u.force);
      }
      for (final a in m.ground.allies) {
        allySeen.add(a.force);
      }
    });
    expect(seen, containsAll(GroundForce.values));
    expect(allySeen, containsAll([GroundForce.vehicle, GroundForce.infantry, GroundForce.rockets]));
  });

  test('units manoeuvre across the whole width, not a line from their spawn', () {
    var minX = 999.0, maxX = -999.0;
    final drift = <int, (double, double)>{};
    fly(3, 90, each: (m) {
      for (final u in m.ground.units) {
        if (!u.alive || u.lx == null) continue;
        minX = u.x < minX ? u.x : minX;
        maxX = u.x > maxX ? u.x : maxX;
        final (lo, hi) = drift[u.id] ?? (u.x, u.x);
        drift[u.id] = (lo < u.x ? lo : u.x, hi > u.x ? hi : u.x);
      }
    });
    expect(minX, lessThan(60));
    expect(maxX, greaterThan(300));
    // Most units weave laterally by tens of arena units on their way in.
    final moved = drift.values.where((r) => r.$2 - r.$1 > 25).length;
    expect(moved, greaterThan(drift.length * .5),
        reason: '$moved of ${drift.length} units manoeuvred');
    // Units visit the central lane too.
    expect(drift.values.any((r) => r.$1 < 200 && r.$2 > 160), isTrue);
  });

  test('the convoy escorts the ship, advances to fight, falls back to repair', () {
    final m = ArcadeModel(seed: 1982)..startAt(sector: 3);
    var maxZ = 0.0, fellBack = false, repaired = false;
    final hurt = <int>{};
    for (var f = 0; f < 60 * 70 && m.level == 3; f++) {
      if (m.combat) m.invulnerable = 2;
      // The player drifts right: the escort slots follow.
      m.shipX = m.targetX = 240;
      m.update(1 / 60);
      for (final a in m.ground.allies) {
        if (!a.alive || a.lx == null) continue;
        if (a.z > maxZ) maxZ = a.z;
        if (a.fallingBack) {
          fellBack = true;
          hurt.add(a.id);
        } else if (hurt.contains(a.id) && a.hp == GroundTuning.allyHp) {
          repaired = true;
        }
      }
    }
    expect(m.ground.skirmish.convoyX, closeTo(240, 6));
    final idle = m.ground.allies.where((a) => a.alive && a.attacker == null && !a.fallingBack);
    for (final a in idle) {
      expect(a.z, lessThan(GroundTuning.allyMaxAdvanceZ));
    }
    expect(maxZ, greaterThan(GroundTuning.allyHoldZ + 60), reason: 'advances to attack');
    expect(maxZ, lessThanOrEqualTo(GroundTuning.allyMaxAdvanceZ + 1));
    expect(fellBack, isTrue);
    expect(repaired, isTrue);
    expect(m.ground.alliesRetreated, 0);
  });

  test('ebb and flow: surges and lulls, announced on the radio', () {
    final names = <String>[];
    fly(2, 100, each: (m) {
      names.addAll(m.takeGameEvents().map((e) => e.name));
    });
    expect(names, contains(GameEventNames.groundTide));
    expect(names, contains(GameEventNames.groundSkirmish));
    expect(names, contains(GameEventNames.infantryEngaged));
    expect(names, contains(GameEventNames.skirmishWon));
    // Rate-limited: never a flood.
    expect(names.where((n) => n == GameEventNames.groundSkirmish).length,
        lessThanOrEqualTo(100 ~/ 6 + 1));
    expect(GameEventNames.all, containsAll(GameEventNames.groundWarV4));
  });

  test('the v3 ground war is unchanged with the skirmish layer off', () {
    SkirmishFront.enabled = false;
    try {
      final m = fly(1, 40);
      expect(m.ground.skirmish.spawned, 0);
      expect(m.ground.units.every((u) => u.lx == null), isTrue);
      expect(m.ground.allies.every((a) => a.lx == null), isTrue);
    } finally {
      SkirmishFront.enabled = true;
    }
  });

  test('a plant in front of a unit is painted again after it', () {
    final m = ArcadeModel(seed: 3)..start();
    m.ground.clearField();
    final u = GroundUnit(1, 0, 0, .5, 600)..lx = 100;
    m.ground.units.add(u);
    final box = Rect.fromLTWH(u.x - 6, u.y - 10, 12, 12);
    final plants = _Plants([
      (500, box), // nearer, overlapping: in front of the unit
      (700, box), // further: behind it, left alone
      (500, box.shift(const Offset(120, 0))), // nearer but elsewhere
    ]);
    final painter = GroundPainter()..occluders = plants;
    painter.paintGround(Canvas(PictureRecorder()), m);
    expect(plants.painted, [0]);
  });
}
