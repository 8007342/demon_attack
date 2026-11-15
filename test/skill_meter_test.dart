// demon-intelligence task 4.4: the bounded skill meter (design §7).
import 'package:demon_attack/game/model.dart';
import 'package:flutter_test/flutter_test.dart';

/// [seconds] of perfect play: every shot hits, fast clears, many dodges.
void expert(SkillMeter s, double seconds) {
  var fired = 0, hit = 0, dodges = 0;
  s.cohortCleared(expected: 20, actual: 10);
  for (var t = 0.0; t < seconds; t += 1 / 60) {
    if ((t * 60).round() % 14 == 0) {
      fired++;
      hit++;
    }
    if ((t * 60).round() % 240 == 0) dodges++;
    s.observe(1 / 60, shotsFired: fired, shotsHit: hit, nearMisses: dodges);
  }
}

void main() {
  test('bounded by the difficulty cap', () {
    for (final (cap, d) in [
      (.5, Difficulty.easy),
      (.8, Difficulty.normal),
      (1.0, Difficulty.hard),
    ]) {
      expect(DifficultyPolicy(d).skillCap, cap);
      final s = SkillMeter(cap: cap);
      expert(s, 300);
      expect(s.level, lessThanOrEqualTo(cap));
      expect(s.level, greaterThan(cap - .05));
    }
  });

  test('a lost life drops it by at least 0.35 and freezes it for 10 s', () {
    final s = SkillMeter(cap: 1);
    expert(s, 200);
    final before = s.level;
    s.lifeLost();
    expect(before - s.level, greaterThanOrEqualTo(.35 - 1e-9));
    final dropped = s.level;
    var fired = 1000, hit = 1000;
    for (var t = 0.0; t < 9.9; t += 1 / 60) {
      fired += 1;
      hit += 1;
      s.observe(1 / 60, shotsFired: fired, shotsHit: hit, nearMisses: 0);
      expect(s.level, dropped);
    }
  });

  test('score, power-ups and time survived do not move it', () {
    // The meter takes accuracy, tempo and dodges only; a model that
    // scores and collects without firing stays at the initial level.
    final m = ArcadeModel()..startAt(sector: 2, route: 1);
    m.mode = RunMode.playing;
    m.invulnerable = 1000;
    m.demons
      ..clear()
      ..add(Demon(20, 40, 0, 99999, 0)..attackLeft = 1000);
    final start = m.skill.level;
    m.score += 1000000;
    m.collect(Power.powerful);
    m.collect(Power.shield);
    m.moveTo(340); // far from the only demon: shots miss
    for (var f = 0; f < 60 * 60; f++) {
      m.update(1 / 60);
    }
    expect(m.skill.level, lessThanOrEqualTo(start + 1e-9));
  });

  test('deterministic', () {
    final a = SkillMeter(), b = SkillMeter();
    expert(a, 77);
    expert(b, 77);
    expect(a.level, b.level);
    expect(a.target, b.target);
  });

  test('a restored checkpoint resets it to 0.3', () {
    final m = ArcadeModel()..startAt(sector: 2, route: 1);
    m.skill.level = .8;
    m.restoreCheckpoint(m.checkpoint());
    expect(m.skill.level, SkillMeter.initial);
  });
}
