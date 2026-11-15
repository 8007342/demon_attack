// --- bonus level #2: Stormfront (openspec/changes/bonus-levels,
// specs/bonus-level-stormfront, design "Bonus level #2: Stormfront")
//
// The squadron follows the brood into a thunderstorm. Lightning strikes
// telegraphed columns and does not take sides: most tells sample the ship's
// position once, so the player baits a bolt under the swarm and slides
// away. The first baited kill of each wave drops the lightning rod, which
// grounds the ship and draws every bolt to it. Half the kill drops are
// shields. Dark, tense and loud where the Supply Run is bright and greedy.
//
// Pure Dart (no dart:ui): the painter is `stormfront_painter.dart`, reached
// through `bonus_painters.dart` by the scene only.
import '../../model.dart';
import 'storm_cell.dart';

/// Grounds the ship and draws every bolt to it (the effect is the level's
/// mechanic; the framework only runs its timer and its pickup).
const lightningRod = BonusPowerDef(
  id: 'lightningRod',
  label: 'ROD',
  badge: 1, // the rapid-fire bolt, recoloured: a lightning rod
  tint: 0xFFE4DCFF,
  seconds: 9,
);

const stormfront = BonusLevelDef(
  id: 'stormfront',
  label: 'STORMFRONT',
  brief:
      'Lure the lightning onto the swarm. When the air hums over you, '
      'slide out.',
  weight: 1,
  waves: BonusWaves(count: 2, rosterScale: .85, reinforcementScale: .5),
  // "A certain percentage of a chance": half the kill drops are shields.
  rules: PowerRules(chances: [PowerChance(Power.shield, .5)]),
  // Shares of the replaced sector's par (measured in the change's design,
  // "Bonus level #2"): a clean storm is worth about the sector on the
  // first tour. The bait bonus lives inside the same cap.
  scoring: BonusScoring(clearPar: .8, flawlessPar: .4, capPar: 1.6),
  look: BonusLook(
    tint: 0xFF0B1030, // a storm-dark blue over the sector's own backdrop
    strength: .46,
    glow: 0x50CFC4FF,
    fog: .14,
  ),
  mechanic: StormfrontMechanic.new,
);

/// Stormfront's rule of play: the storm, applied to the model.
class StormfrontMechanic implements BonusMechanic {
  StormfrontMechanic(BonusMechanicContext c)
    : cell = StormCell(
        c.seed ^ 0x570f,
        tuning: switch (c.difficulty) {
          Difficulty.easy => StormTuning.easy,
          Difficulty.normal => StormTuning.normal,
          Difficulty.hard => StormTuning.hard,
        }.forRoute(c.route),
      );

  /// The seeded schedule (the painter reads it).
  final StormCell cell;

  /// Bait bonus per creature a ship-aimed bolt destroys, × (route + 1).
  static const baitPoints = 100;

  /// The wave whose first baited kill already dropped a rod.
  int _rodWave = 0;

  /// Tells that already had their warning event.
  int _warned = 0;

  /// Totals for the level (tests, the clear event).
  int bolts = 0, stormKills = 0, baitKills = 0, rods = 0, shipHits = 0;
  int grounded = 0;

  @override
  void step(ArcadeModel m, double dt) {
    final rod = m.hasBonusPower(lightningRod.id);
    final landed = cell.step(
      dt,
      shipX: m.shipX,
      swarm: [
        for (final d in m.demons)
          if (!d.entering) d.x,
      ],
      active: m.combat && !m.shipAway,
      rate: m.policy.hostileRate,
      rod: rod,
    );
    // A new tell: its crackle (raw event: the sound, and a plain
    // `stormTell` for the music) and, for a tell on an unprotected ship,
    // the squad's warning, which ends on the bolt (`endIn`).
    for (final s in cell.strikes) {
      if (s.index < _warned) continue;
      _warned = s.index + 1;
      if (s.aim == StrikeAim.fork) continue; // one call per group
      m.events.add('stormTell');
      if (s.aim == StrikeAim.ship && !s.rod) {
        m.bonusEvent(GameEventNames.stormStrike, {
          'x': s.x,
          'endIn': s.tellLeft,
        });
      }
    }
    for (final s in landed) {
      _land(m, s);
    }
  }

  @override
  void idle(ArcadeModel m, double dt) {
    // Outside combat: running tells fizzle, afterglows fade, nothing new.
    cell.step(dt, shipX: m.shipX, swarm: const [], active: false);
  }

  void _land(ArcadeModel m, StormStrike s) {
    bolts++;
    Demon? last;
    for (final d in List<Demon>.of(m.demons)) {
      if (d.entering || (d.x - s.x).abs() > s.column) continue;
      m.hitDemon(d, damage: cell.tuning.damage, homing: true);
      if (!m.demons.contains(d)) {
        s.kills++;
        last = d;
      }
    }
    stormKills += s.kills;
    // The ship: the rod grounds the bolt; otherwise an ordinary hit (the
    // shield absorbs it, protection ignores it).
    if ((m.shipX - s.x).abs() < cell.tuning.core && m.combat && !m.shipAway) {
      if (m.hasBonusPower(lightningRod.id)) {
        s.grounded = true;
        grounded++;
      } else {
        final lives = m.lives;
        final shielded = m.hasPower(Power.shield);
        m.hitPlayer();
        s.hitShip = m.lives < lives || (shielded && !m.hasPower(Power.shield));
        if (s.hitShip) shipHits++;
      }
    }
    var award = 0;
    final baited = s.aim != StrikeAim.swarm && s.kills > 0 && !s.hitShip;
    if (baited) {
      baitKills += s.kills;
      award = m.bonusAward(baitPoints * (m.cycle + 1) * s.kills);
      // The first baited kill of a wave drops the rod where the creature
      // fell (never while one is falling or carried).
      if (_rodWave != m.wave &&
          last != null &&
          !m.hasBonusPower(lightningRod.id) &&
          !m.pickups.any((p) => p.bonus == lightningRod)) {
        _rodWave = m.wave;
        rods++;
        m.pickups.add(
          Pickup(last.x, last.y, Power.shield, bonus: lightningRod),
        );
      }
    }
    // The thunder (raw event: the sound, and a plain `stormBolt` for the
    // music), once per instant however many columns fork.
    if (s.aim != StrikeAim.fork) m.events.add('stormBolt');
    if (baited) {
      m.bonusEvent(GameEventNames.stormBait, {
        'x': s.x,
        'kills': s.kills,
        'award': award,
      });
    }
  }
}
