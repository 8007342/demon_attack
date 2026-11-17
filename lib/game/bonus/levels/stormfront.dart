// --- bonus level #2: Stormfront (openspec/changes/bonus-levels,
// specs/bonus-level-stormfront, design "Bonus level #2: Stormfront";
// reworked by openspec/changes/lightning-rework)
//
// The squadron follows the brood into a thunderstorm. Lightning strikes
// telegraphed columns and does not take sides, but it no longer kills:
// a bolt STUNS the creatures in its column (they drop out of the sky for a
// moment, defenceless) and ZAPS a ship it catches (every shield and
// power-up stripped, never a life). Most tells sample the ship's position
// once, so the player lures a bolt under the swarm, slides away, then
// shoots the stunned creatures while they fall: each one shot down from a
// baited bolt pays the bait bonus, and the wave's first drops the
// lightning rod, which grounds the ship and draws every bolt to it. Half
// the kill drops are shields. Rod-armoured sentinels (tour 2 on) and
// hunters (tour 3 on) drink the bolts instead and fire faster for a while.
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
  // bonus-briefing-clarity: one goal line and one how-to line.
  // lightning-rework: the stun is the opening. Checked against StormCell:
  // most tells sample the ship's x once and blink an amber marker on the
  // ship's row; the bolt then stuns that column and zaps the ship if it
  // stayed.
  brief: 'Lure the lightning onto the demons!',
  how: 'Sit under them, slide away, then shoot them as they fall.',

  weight: 1,
  // lightning-rework: the storm stuns and no longer kills, so the pilot
  // shoots every creature: the sector's own rosters (was × 1.15).
  waves: BonusWaves(rosterScale: .93),
  // "A certain percentage of a chance": half the kill drops are shields.
  rules: PowerRules(chances: [PowerChance(Power.shield, .5)]),
  // Shares of the replaced sector's par (measured in the change's design,
  // "Bonus level #2"): a clean storm is worth about the sector on the
  // first tour. The bait bonus lives inside the same cap.
  scoring: BonusScoring(
    pointsScale: .77,

    clearPar: .15,
    flawlessPar: .1,
    capPar: .3,
  ),
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
    : route = c.route,
      cell = StormCell(
        c.seed ^ 0x570f,
        tuning: switch (c.difficulty) {
          Difficulty.easy => StormTuning.easy,
          Difficulty.normal => StormTuning.normal,
          Difficulty.hard => StormTuning.hard,
        }.forRoute(c.route),
      );

  /// Zero-based route (rod armour arrives on later tours).
  final int route;

  /// The seeded schedule (the painter reads it).
  final StormCell cell;

  /// Bait bonus per stunned creature shot down from a ship-aimed bolt,
  /// × (route + 1).
  static const baitPoints = 100;

  /// The wave whose first baited kill already dropped a rod.
  int _rodWave = 0;

  /// Tells that already had their warning event, and ship tells warned.
  int _warned = 0, _shipTells = 0;

  /// Creatures stunned by a bolt that was drawn to the ship and missed it.
  final Set<Demon> _baited = Set.identity();

  /// Totals for the level (tests, the clear event, the 1UP challenge):
  /// bolts landed, creatures stunned, stunned creatures shot down (all,
  /// and from baited bolts), rods dropped, ship zaps, grounded bolts and
  /// rod-armoured creatures charged.
  int bolts = 0, stuns = 0, stormKills = 0, baitKills = 0, rods = 0;
  int shipHits = 0, grounded = 0, charges = 0;

  @override
  void step(ArcadeModel m, double dt) {
    // Rod armour is worn from the first frame a creature is seen.
    for (final d in m.demons) {
      d.lightningRods = lightningRodArmour(d, route);
    }
    _collect(m);
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
    // the squad's warning, which ends on the bolt (`endIn`). Every other
    // warning is the plain "Avoid lightning!" (variant `avoid`).
    for (final s in cell.strikes) {
      if (s.index < _warned) continue;
      _warned = s.index + 1;
      if (s.aim == StrikeAim.fork) continue; // one call per group
      m.events.add('stormTell');
      if (s.aim == StrikeAim.ship && !s.rod) {
        _shipTells++;
        m.bonusEvent(GameEventNames.stormStrike, {
          'x': s.x,
          'endIn': s.tellLeft,
          if (_shipTells.isOdd) 'variant': 'avoid',
        });
      }
    }
    // The brood sees the tells too: ranks dodge, rods are drawn in.
    m.dodgeLightning([
      for (final s in cell.strikes)
        if (s.telling)
          (index: s.index, x: s.x, column: s.column, progress: s.tellProgress),
    ]);
    for (final s in landed) {
      _land(m, s);
    }
  }

  @override
  void idle(ArcadeModel m, double dt) {
    // Outside combat: running tells fizzle, afterglows fade, nothing new.
    cell.step(dt, shipX: m.shipX, swarm: const [], active: false);
    m.stunKills.clear();
    _baited.clear();
  }

  /// Stunned creatures shot down since the last step: the storm's kills,
  /// the bait bonus and the wave's rod.
  void _collect(ArcadeModel m) {
    for (final d in m.stunKills) {
      stormKills++;
      if (!_baited.remove(d)) continue;
      baitKills++;
      m.bonusAward(baitPoints * (m.cycle + 1));
      // The first baited kill of a wave drops the rod where the creature
      // fell (never while one is falling or carried).
      if (_rodWave != m.wave &&
          !m.hasBonusPower(lightningRod.id) &&
          !m.pickups.any((p) => p.bonus == lightningRod)) {
        _rodWave = m.wave;
        rods++;
        m.pickups.add(Pickup(d.x, d.y, Power.shield, bonus: lightningRod));
      }
    }
    m.stunKills.clear();
    _baited.removeWhere((d) => !d.stunned);
  }

  void _land(ArcadeModel m, StormStrike s) {
    bolts++;
    // The ship first: the rod grounds the bolt; otherwise a zap (every
    // shield and power-up, never a life; protection and the zap's grace
    // ignore it).
    if ((m.shipX - s.x).abs() < cell.tuning.core && m.combat && !m.shipAway) {
      if (m.hasBonusPower(lightningRod.id)) {
        s.grounded = true;
        grounded++;
      } else if (m.zapShip()) {
        s.hitShip = true;
        shipHits++;
      }
    }
    // A bolt drawn to the ship that missed it is a bait: its stun is the
    // squad's cue (`stormBait`, variant `stun`); any other stun is the
    // brood's yelp (`lightningStun`).
    final bait = s.aim != StrikeAim.swarm && !s.hitShip;
    final hit = m.strikeLightning(
      s.x,
      s.column,
      stunEvent: bait ? GameEventNames.stormBait : GameEventNames.lightningStun,
      data: bait ? const {'variant': 'stun'} : const {},
    );
    s
      ..stunned = hit.stunned.length
      ..charged = hit.charged.length;
    stuns += s.stunned;
    charges += s.charged;
    if (bait) _baited.addAll(hit.stunned);
    // The thunder (raw event: the sound, and a plain `stormBolt` for the
    // music), once per instant however many columns fork.
    if (s.aim != StrikeAim.fork) m.events.add('stormBolt');
  }
}
