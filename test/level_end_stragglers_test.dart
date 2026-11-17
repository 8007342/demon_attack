// playtest R1 (plan/operator-feedback-2026-11-15b.md): no stragglers at a
// level's end. From the level-clear moment (the sector's last kill, a
// carrier's fall, the campaign's last carrier) through the whole transition
// (Rout, Pursuit, Descent) to the next sector, nothing alive is drawn in or
// behind the fog: no creature body, no veiled arrival, no flock member, no
// shadow on the terrain and no sentinel silhouette. The sweep runs every
// difficulty x route x sector (the carrier levels and the campaign end
// included) over several seeds, and reads what the scene's air passes draw
// (DemonScene.airCensus), not just the model's lists.
import 'package:demon_attack/game/model.dart';
import 'package:demon_attack/game/scene.dart';
import 'package:flutter_test/flutter_test.dart';

import 'progression_test.dart' show reach;

/// What one level end showed.
class _End {
  int frames = 0, dirty = 0, sentinels = 0, minions = 0;
  int descent = 0, descentDirty = 0;
  String? first;
  final modes = <RunMode>{};
}

/// Plays [m] from where it stands to the end of its sector and through the
/// transition. A landed creature dies every [every] seconds; a carrier is
/// brought down after [bossAfter] seconds of fighting its minions.
/// With [skip] the player taps through the transition once the Pursuit is
/// under way.
_End _play(
  ArcadeModel m, {
  double every = .3,
  double bossAfter = 9,
  bool skip = false,
}) {
  final scene = DemonScene(m, () {});
  final end = _End();
  final start = m.level, route = m.cycle;
  var cool = 0.0, fought = 0.0;
  var cleared = false;
  for (var f = 0; f < 60 * 300; f++) {
    m
      ..lives = 5
      ..invulnerable = 5;
    if (m.combat && m.level == start && m.cycle == route) {
      fought += 1 / 60;
      for (final d in m.demons) {
        if (d.isLarge && (d.entranceProgress > 0)) end.sentinels++;
      }
      final b = m.boss;
      if (b != null && fought >= bossAfter) {
        end.minions = m.demons
            .where((d) => d.swarmState != SwarmState.reserve)
            .length;
        b
          ..shield = 0
          ..core = 1
          ..door = 1;
        m.hitBoss(b.x);
      } else {
        cool -= 1 / 60;
        if (cool <= 0) {
          final target = m.demons
              .where((d) => !d.entering && d.swarmState != SwarmState.reserve)
              .firstOrNull;
          if (target != null) {
            for (var guard = 0; guard < 1000 && m.demons.contains(target); guard++) {
              m.hitDemon(target);
            }
            cool = every;
          }
        }
      }
    }
    m.update(1 / 60);
    final ending =
        m.level == start &&
        m.cycle == route &&
        const [
          RunMode.salvage,
          RunMode.levelClear,
          RunMode.travel,
          RunMode.victory,
          RunMode.completed,
        ].contains(m.mode);
    if (ending) {
      if (skip && m.mode == RunMode.travel) m.skipTransition();
      cleared = true;
      end.frames++;
      end.modes.add(m.mode);
      final census = scene.airCensus();
      if (!census.empty) {
        end.dirty++;
        end.first ??=
            '${m.mode.name} at frame ${end.frames}: $census '
            '(flow ${m.flow.seconds.toStringAsFixed(2)} s)';
      }
      if (m.mode == RunMode.completed) break;
    }
    if (cleared && !ending) {
      // The Descent into the next sector: its first cohort comes out of
      // the cloud (what the transition shows), but nothing waits in the
      // fog behind it: no drawn reserve, no sighted next cohort, no flock
      // and no sentinel silhouette until the flow is over.
      if (!m.flow.active || m.combat) break;
      end.descent++;
      final census = scene.airCensus();
      if (census.approaching.isNotEmpty ||
          census.flock.isNotEmpty ||
          census.silhouette) {
        end.descentDirty++;
        end.first ??=
            'descent ${m.mode.name} at frame ${end.descent}: $census '
            '(flow ${m.flow.seconds.toStringAsFixed(2)} s)';
      }
    }
  }
  expect(cleared, isTrue, reason: 'the level never ended');
  return end;
}

void main() {
  test('no creature, silhouette or shadow in the fog at any level end', () {
    var descents = 0;
    var sentinelLevels = 0, carrierEnds = 0, outros = 0, minions = 0;
    final failures = <String>[];
    for (final difficulty in Difficulty.values) {
      for (var route = 0; route <= 4; route++) {
        for (var sector = 1; sector <= 5; sector++) {
          for (final seed in const [3, 11, 1982]) {
            final waves = ArcadeModel.wavesFor(sector: sector, route: route);
            final m = ArcadeModel(seed: seed)
              ..startAt(
                difficulty: difficulty,
                sector: sector,
                route: route,
                // The penultimate wave, so the last one arrives the
                // realistic way (sighted, then merged).
                wave: waves > 1 ? waves - 1 : 1,
              );
            // Reduced motion runs the shorter plans (cuts, no hit-stop).
            m.reducedMotion = seed == 1982;
            reach(m, RunMode.playing);
            final r = _play(
              skip: seed == 11,
              m,
              every: seed == 11 ? .15 : .3,
              bossAfter: switch (seed) {
                3 => 9.0,
                11 => 16.0,
                _ => 4.0,
              },
            );
            final where =
                '${difficulty.name} route $route sector $sector seed $seed';
            expect(r.frames, greaterThan(60), reason: where);
            if (r.dirty > 0 || r.descentDirty > 0) {
              failures.add(
                '$where: ${r.dirty}/${r.frames} end frames, '
                '${r.descentDirty}/${r.descent} descent frames, ${r.first}',
              );
            }
            descents += r.descent;
            if (r.sentinels > 0) sentinelLevels++;
            if (sector == 5) {
              carrierEnds++;
              minions += r.minions;
              if (r.modes.contains(RunMode.completed)) outros++;
            }
          }
        }
      }
    }
    // The sweep covers what it claims: sentinel fights, carrier falls with
    // live minions around them, and the campaign's last carrier.
    expect(sentinelLevels, greaterThan(20));
    expect(carrierEnds, 45);
    expect(minions, greaterThan(0));
    expect(outros, 9);
    expect(descents, greaterThan(1000));
    expect(failures, isEmpty, reason: failures.take(40).join('\n'));
  });
}
