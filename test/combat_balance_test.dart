import 'package:demon_attack/game/model.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // continuous-swarm task 4.3: a streamed skein's swoop hands over to its
  // squad's fighting pattern with no position or velocity snap.
  test('swoop hands over to the squad pattern without a snap', () {
    for (final seed in [3, 42, 77]) {
      final model = ArcadeModel(seed: seed)
        ..startAt(difficulty: Difficulty.normal, sector: 2, route: 1);
      for (var i = 0; i < 600 && model.mode != RunMode.playing; i++) {
        model.update(1 / 60);
      }
      // Clear wave 1 at once: wave 2 streams in skein by skein.
      model.flocksSpawned = model.flocksPlanned;
      for (final d in List.of(model.demons)) {
        model.hitDemon(d, damage: 99);
      }
      final last = <Demon, (double, double)>{};
      final step = <Demon, (double, double)>{};
      final entering = <Demon, bool>{};
      var handoffs = 0;
      var maxJerk = 0.0;
      for (var f = 0; f < 60 * 8; f++) {
        model.invulnerable = 5;
        model.shots.removeWhere((s) => !s.hostile);
        model.update(1 / 60);
        for (final d in model.demons) {
          if (d.isLarge ||
              d.dive > 0 ||
              d.telegraph > 0 ||
              d.divePrep > 0 ||
              d.evadeLeft > 0 ||
              d.swarmState == SwarmState.reserve) {
            last.remove(d);
            step.remove(d);
            entering.remove(d);
            continue;
          }
          final p = last[d];
          if (p != null) {
            final v = (d.x - p.$1, d.y - p.$2);
            final q = step[d];
            final wasEntering = entering[d] ?? false;
            if (q != null && wasEntering != d.entering) {
              handoffs++;
              final dv = (v.$1 - q.$1).abs() + (v.$2 - q.$2).abs();
              if (dv > maxJerk) maxJerk = dv;
              expect(
                (v.$1.abs() + v.$2.abs()),
                lessThan(6),
                reason: 'position snap at the hand-off',
              );
            }
            step[d] = v;
          }
          last[d] = (d.x, d.y);
          entering[d] = d.entering;
        }
      }
      expect(handoffs, greaterThan(5), reason: 'seed $seed');
      expect(maxJerk, lessThan(1.5), reason: 'velocity snap, seed $seed');
    }
  });

  test(
    'wave entrance transitions smoothly into formation without position snap',
    () {
      final model = ArcadeModel(seed: 42)..start();
      // Advance past Wave 1 arrival hint into RunMode.playing.
      for (var i = 0; i < 300 && model.mode != RunMode.playing; i++) {
        model.update(1 / 60);
      }
      expect(model.mode, RunMode.playing);
      final tracked = model.demons.first;
      expect(tracked.entering, isTrue);

      var prevX = tracked.x;
      var prevY = tracked.y;
      var sawHandoff = false;
      for (var step = 0; step < 180; step++) {
        final wasEntering = tracked.entering;
        model.update(1 / 60);
        final dx = (tracked.x - prevX).abs();
        final dy = (tracked.y - prevY).abs();
        if (wasEntering && !tracked.entering) {
          sawHandoff = true;
          // Previously snapped by up to 42px in a single tick; now C1/C2 continuous.
          expect(dx, lessThan(4.5));
          expect(dy, lessThan(4.5));
        }
        prevX = tracked.x;
        prevY = tracked.y;
      }
      expect(sawHandoff, isTrue);
    },
  );

  test('ship banking inertia bends sling shots while stationary shots stay straight', () {
    final model = ArcadeModel(seed: 7)..start();
    model.mode = RunMode.playing;
    model.shots.clear();

    // Stationary shot fires straight up (vx == 0).
    model.shipX = 180;
    model.targetX = 180;
    model.shipVx = 0;
    model.shipBank = 0;
    for (var i = 0; i < 20 && model.shots.isEmpty; i++) {
      model.update(1 / 60);
    }
    final straightShot = model.shots.firstWhere((s) => !s.hostile);
    expect(straightShot.vx, 0);

    // Sliding right builds shipVx and shipBank, slinging shots with positive vx.
    model.shots.clear();
    model.moveTo(320);
    for (var i = 0; i < 16; i++) {
      model.update(1 / 60);
    }
    expect(model.shipVx, greaterThan(50));
    expect(model.shipBank, greaterThan(0.15));
    final slungShot = model.shots.lastWhere((s) => !s.hostile);
    expect(slungShot.vx, greaterThan(8));
  });

  test('3-tier diving shields: small, not-so-small, and powerup-gated large sentinel', () {
    final model = ArcadeModel(seed: 99)..start();
    model.mode = RunMode.playing;
    model.demons.clear();

    // Tier 1: Small creature (1-HP lil' diving shield).
    final small = Demon(120, 120, 0, 2, 0.1)
      ..entranceProgress = 1
      ..telegraph = 0.01;
    // Tier 2: Not-so-small creature (elite / higher species -> 2..3 HP medium diving shield).
    final medium = Demon(180, 120, 2, 3, 0.2, elite: true)
      ..entranceProgress = 1
      ..telegraph = 0.01;
    // Tier 3: Large Sentinel (4+ HP re-entry diving shield, breakable only with powerups).
    final large =
        Demon(
            240,
            80,
            3,
            10,
            0.3,
            archetype: EnemyArchetype.shieldSentinel,
            shieldMax: 4,
            armorMax: 2,
          )
          ..entranceProgress = 1
          ..waitingForEscort = false
          ..telegraph = 0.01;

    model.demons.addAll([small, medium, large]);
    model.update(1 / 60);
    model.update(1 / 60);

    expect(small.dive, greaterThan(0));
    expect(small.diveShieldMax, 1);
    expect(small.diveShield, 1);

    expect(medium.dive, greaterThan(0));
    expect(medium.diveShieldMax, 3);
    expect(medium.diveShield, 3);

    expect(large.dive, greaterThan(0));
    expect(large.diveShieldMax, greaterThanOrEqualTo(4));
    expect(large.diveShield, large.diveShieldMax);

    // 2-damage Powerful shot pierces small demon's 1-HP dive shield and deals 1 HP damage.
    model.hitDemon(small, damage: 2);
    expect(small.diveShield, 0);
    expect(small.hp, 1);

    // Medium demon's 3-HP dive shield absorbs a 2-damage shot with 1 shield remaining.
    model.hitDemon(medium, damage: 2);
    expect(medium.diveShield, 1);
    expect(medium.hp, 3);

    // Without active offensive powerups, unpowered shots cannot break the large dive shield!
    expect(model.hasOffensivePower, isFalse);
    for (var i = 0; i < 10; i++) {
      model.hitDemon(large, damage: 1);
    }
    expect(large.diveShield, greaterThan(0));
    expect(large.shield, 4);

    // Collecting an offensive powerup allows breaking the large sentinel's dive shield!
    model.collect(Power.powerful);
    expect(model.hasOffensivePower, isTrue);
    final scoreBefore = model.score;
    while (large.diveShield > 0) {
      model.hitDemon(large, damage: 2);
    }
    expect(large.diveShield, 0);
    // Plasma Shatter awards bonus points and deals 1 stun overflow damage to shield layer.
    expect(model.score, greaterThan(scoreBefore));
    expect(large.shield, 3);
  });

  // carrier-hatches §A5: the core door is the only opening; the side
  // hatches are sealed in every form (supersedes the side-hatch rule).
  test('carrier core: side hatches sealed, the wider core door the only opening', () {
    final model = ArcadeModel(seed: 12)..start();
    model.mode = RunMode.playing;
    model.level = 5;
    final boss = Carrier(1)
      ..shield = 0
      ..core = 24;
    model.boss = boss;
    expect(boss.phase, 0);
    expect(boss.sideHatchesLocked, isTrue);
    boss.door = 0;
    boss.sideDoorLeft = 1.0;
    expect(model.hitBoss(boss.x), isFalse);
    expect(model.hitBoss(boss.x - Carrier.sideHatchOffset), isFalse);
    expect(boss.core, 24);
    boss.door = 1.0;
    // 24 × openness (was 12; carrier-hatches §A11).
    expect(model.hitBoss(boss.x + 23), isTrue);
    expect(boss.core, 23);
    expect(model.hitBoss(boss.x + 25), isFalse);

  });
}
