// playtest-fixes 1: the sector's final wave leaves the fog empty. Once the
// last wave of a sector (or its sentinel finale) is under way nothing more
// is staged in the deep fog, everything it held back is admitted into the
// fight, and the rout at the last kill scatters only creatures that were
// fighting: none, so no flock flies away through the fog.
import 'package:demon_attack/game/model.dart';
import 'package:flutter_test/flutter_test.dart';

import 'progression_test.dart' show reach;

/// Plays [m] from the penultimate wave (so the final wave arrives as the
/// sighted cohort and merges, the realistic path) to the next sector's
/// fight, killing one landed creature every [every] seconds. Returns what
/// it saw.
({int finalFrames, int heldBack, int stagedFinal, int stagedEnd, int flock})
_play(ArcadeModel m, {double every = .35}) {
  var finalFrames = 0, heldBack = 0, stagedFinal = 0, stagedEnd = 0;
  var flock = 0;
  var cool = 0.0;
  final start = m.level;
  for (var f = 0; f < 60 * 240; f++) {
    m
      ..lives = 5
      ..invulnerable = 5;
    if (m.combat) {
      cool -= 1 / 60;
      if (cool <= 0) {
        final target = m.demons
            .where((d) => !d.entering && d.swarmState != SwarmState.reserve)
            .firstOrNull;
        if (target != null) {
          while (m.demons.contains(target)) {
            m.hitDemon(target);
          }
          cool = every;
        }
      }
    }
    m.update(1 / 60);
    if (m.level == start && m.combat && m.wave == m.wavesPerLevel) {
      finalFrames++;
      expect(m.finalWave, isTrue);
      if (m.swarmReserve.isNotEmpty) heldBack++;
      stagedFinal += m.fogStaged.length;
      expect(m.incoming, isEmpty, reason: 'no cohort after the last');
    }
    if (const [
      RunMode.salvage,
      RunMode.levelClear,
      RunMode.travel,
    ].contains(m.mode)) {
      stagedEnd += m.fogStaged.length + m.swarmReserve.length;
      flock += m.flowFlock.length;
    }
    if (m.level != start && m.combat) break;
  }
  return (
    finalFrames: finalFrames,
    heldBack: heldBack,
    stagedFinal: stagedFinal,
    stagedEnd: stagedEnd,
    flock: flock,
  );
}

void main() {
  test('the final wave stages nothing in the fog, the rout is empty', () {
    var heldBack = 0, runs = 0;
    for (final (sector, route) in [(1, 0), (2, 1), (3, 2), (4, 1), (2, 3)]) {
      for (final seed in [3, 11]) {
        final waves = ArcadeModel.wavesFor(sector: sector, route: route);
        final m = ArcadeModel(seed: seed)
          ..startAt(sector: sector, route: route, wave: waves - 1);
        reach(m, RunMode.playing);
        final r = _play(m);
        final where = 'sector $sector route $route seed $seed';
        expect(r.finalFrames, greaterThan(60), reason: where);
        expect(r.stagedFinal, 0, reason: '$where: fog-staged in final wave');
        expect(r.stagedEnd, 0, reason: '$where: waiting at level end');
        expect(r.flock, 0, reason: '$where: nothing flees through the fog');
        expect(m.level, isNot(sector), reason: '$where: reached next sector');
        heldBack += r.heldBack;
        runs++;
      }
    }
    // The final wave does hold creatures back (later skeins, groups); they
    // wait unseen and are all admitted before the wave can end.
    expect(runs, 10);
    expect(heldBack, greaterThan(0));
  });

  test('earlier waves still show their reserve in the fog', () {
    final m = ArcadeModel(seed: 7)..startAt(sector: 2, route: 1);
    reach(m, RunMode.playing);
    expect(m.finalWave, isFalse);
    expect(m.swarmReserve, isNotEmpty);
    expect(m.fogStaged, isNotEmpty);
  });

  test('a carrier fall takes its fighting minions with it', () {
    final m = ArcadeModel(seed: 3)..startAt(sector: 5, route: 1);
    reach(m, RunMode.playing);
    for (var i = 0; i < 60 * 12; i++) {
      m.invulnerable = 5;
      m.update(1 / 60);
    }
    final fighting = m.demons
        .where((d) => d.swarmState != SwarmState.reserve && !d.entering)
        .toList();
    expect(fighting, isNotEmpty);
    final b = m.boss!
      ..shield = 0
      ..core = 1
      ..door = 1;
    m.hitBoss(b.x);
    expect(m.mode, RunMode.victory);
    // playtest R1: none flees into the fog; they die where they are (the
    // scene bursts them) and nothing is left after the boss fight.
    expect(m.flowFlock, isEmpty);
    expect(m.demons, isEmpty);
    expect(fighting.every((d) => d.hp <= 0), isTrue);
    expect(m.fogStaged, isEmpty);
  });
}
