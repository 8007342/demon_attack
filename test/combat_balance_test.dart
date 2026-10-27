import 'package:demon_attack/game/model.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('wave entrance transitions smoothly into formation without position snap', () {
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
  });

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
    final large = Demon(
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

  test('carrier boss opens side hatches in early forms and locks them in final form', () {
    final model = ArcadeModel(seed: 12)..start();
    model.mode = RunMode.playing;
    model.level = 5;
    final boss = Carrier(1)
      ..shield = 0
      ..core = 24;
    model.boss = boss;

    // Form 0 of 3: sideHatchesLocked is false; side hatches can take core damage.
    expect(boss.phase, 0);
    expect(boss.sideHatchesLocked, isFalse);
    boss.door = 0;
    boss.sideDoorLeft = 1.0;
    boss.sideDoorRight = 0;
    expect(model.hitBoss(boss.x), isFalse);
    expect(model.hitBoss(boss.x - Carrier.sideHatchOffset), isTrue);
    expect(boss.core, 23);

    // Advance core damage into the final form (phase == formCount - 1).
    boss.core = 4;
    expect(boss.phase, boss.formCount - 1);
    expect(boss.sideHatchesLocked, isTrue);
    model.update(1 / 60);
    expect(boss.sideDoorLeft, 0);
    expect(boss.sideDoorRight, 0);
    expect(model.hitBoss(boss.x - Carrier.sideHatchOffset), isFalse);
    expect(model.hitBoss(boss.x + Carrier.sideHatchOffset), isFalse);

    // Center hatch still damages the core in final form.
    boss.door = 1.0;
    expect(model.hitBoss(boss.x), isTrue);
    expect(boss.core, 3);
  });
}
