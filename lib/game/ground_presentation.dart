import 'dart:math' as math;

import 'ground_blocks_atlas.dart';

// ===========================================================================
// Operator tuning of the ground's presentation (playtest 2026-11-15; openspec
// change ground-presentation-tuning). Presentation only: nothing here is
// read by the simulation, and nothing draws from `model.random` or any
// simulation stream.
// ===========================================================================

/// How fast ground animation plays, as a fraction of the authored rate: the
/// ground reads as distant events. Applied to cycle clocks (move, tread,
/// walk, idle, lights, flames, dust), turn rates and one-shot visual
/// timelines. Never applied to the threat telegraph (its blink is the
/// timing contract), to simulation timers (fire flash, recoil, hit flash)
/// or to unit travel (positions are the simulation's).
abstract final class GroundPace {
  /// Every ground animation cycle (vehicles, infantry, overlays, dances).
  static const anim = .5;

  /// Legged units' stride cadence: slower still than the troops.
  static const walker = .3;

  /// Hull and turret slew (degrees per second) and the minimum hold
  /// between shown headings (stretched by the inverse).
  static const turn = .5;

  /// Purely visual ground effects: dust, flames, wreck flicker, debris
  /// arcs, smoke-column puffs, critter leaps.
  static const fx = .5;

  /// Easter-egg motion (dances, jig, turret twirl, jackpot).
  static const egg = .5;

  /// Legged block units: the W-block walkers (Stilt, Kiln Ox, Buttress
  /// Strider, Belfry) and the K-block Chapterhouse.
  static bool isWalker(GroundBlockUnit u) => u.block == 'W' || u.block == 'K';

  /// The stride or tread cadence factor of [u].
  static double of(GroundBlockUnit u) => isWalker(u) ? walker : anim;
}

/// Draw-size multipliers on top of the perspective scale (the simulation's
/// `scale` and `width` are unchanged: placement, launch points and homing
/// aim stay where they were).
abstract final class GroundSize {
  /// Allied (Fleet) vehicles and walkers: half the size.
  static const fleetVehicle = .5;

  /// Enemy (Host) vehicles, walkers and the heavy tank: 30 % larger.
  static const hostVehicle = 1.3;

  /// Foot soldiers of both factions: 10 % smaller.
  static const trooper = .9;
}

/// How a squad is drawn: a group of 1-5 individuals (most often 2-4), each
/// on its own gait phase and cadence, with its own spacing, a slow drift,
/// a little lead or lag along the march and its own turn. Deterministic
/// from the unit id and the visual clock.
abstract final class GroundSquadLook {
  /// Base formation slots (texels at the unit's scale; dy > 0 nearer).
  static const formation = [
    (0.0, 0.0), (-11.0, -3.0), (11.0, -2.0), (-5.0, 3.0), (6.0, 4.0),
  ];

  /// A stable value in [0, 1) for ([a], [b], [salt]). Integer arithmetic
  /// that stays exact on the web (every product below 2^53).
  static double hash(int a, int b, int salt) {
    const m = 2147483647;
    var x = ((a % 46337) * 9973 + (b % 46337) * 7919 + salt * 104729 + 1) % m;
    x = (x * 48271) % m;
    x = (x * 48271) % m;
    x = (x * 48271) % m;
    return x / m;
  }

  /// Salt separating demon ids from ally ids (they count separately).
  static const allySalt = 5003, demonSalt = 7001;

  /// Troopers drawn for a squad: rifle squads 1-5 with weights 1:3:4:3:1
  /// (2-4 five times in six), rocket teams 1-3 with weights 1:2:1.
  static int size(int id, {required bool rockets, required bool ally}) {
    final h = hash(id, 0, ally ? allySalt : demonSalt);
    if (rockets) return h < .25 ? 1 : (h < .75 ? 2 : 3);
    return h < 1 / 12
        ? 1
        : h < 4 / 12
            ? 2
            : h < 8 / 12
                ? 3
                : h < 11 / 12
                    ? 4
                    : 5;
  }

  /// Troopers of [n] still standing for a demon squad at [hp] of [maxHp]
  /// (the simulation's squad is [maxHp] strong; the drawn group is [n]).
  static int standing(int n, int hp, int maxHp) =>
      maxHp <= 0 ? 0 : (hp * n / maxHp).ceil().clamp(0, n);

  /// Troopers that fell to the latest hit (indices standing .. this − 1).
  static int fellLast(int n, int hp, int maxHp) =>
      standing(n, math.min(maxHp, hp + 1), maxHp);

  /// Offset of trooper [k] from the squad position (texels at the unit's
  /// scale; dy > 0 nearer): the formation slot, its own spacing, a slow
  /// drift, and a lead or lag along [heading] (signed screen degrees, 0 up
  /// the plane) in proportion to [march] (0 holding .. 1 marching, eased
  /// by the caller so nobody jumps when the squad stops).
  static (double, double) offset(int seed, int k, double clock,
      {required double heading, required double march}) {
    final (fx, fy) = formation[k % formation.length];
    double h(int salt) => hash(seed, k, salt);
    // Spacing: each trooper's own place in the loose group.
    var dx = fx + (h(1) - .5) * 5;
    var dy = fy + (h(2) - .5) * 3;
    // Drift: a slow wander of a couple of texels (smaller while holding).
    final wander = .4 + .6 * march;
    dx += wander *
        (1.6 + h(3)) *
        math.sin(clock * (.25 + .3 * h(4)) + 6.3 * h(5));
    dy += wander *
        (.8 + .6 * h(6)) *
        math.sin(clock * (.2 + .25 * h(7)) + 6.3 * h(8));
    // Speed variance: a steady lead or lag plus a slow surge.
    final lead = (h(9) - .5) * 4 +
        1.6 * math.sin(clock * (.3 + .3 * h(10)) + 6.3 * h(11));
    final a = heading * math.pi / 180;
    dx += march * math.sin(a) * lead;
    dy -= march * math.cos(a) * lead;
    return (dx, dy);
  }

  /// Walk cadence multiplier (±15 %) and phase (frames) of trooper [k].
  static (double, double) gait(int seed, int k) =>
      (.85 + .3 * hash(seed, k, 12), 4 * hash(seed, k, 13));

  /// How quickly trooper [k] follows a change of the squad's march
  /// (1/s; lower turns later) and how much longer it holds a heading.
  static (double, double) turn(int seed, int k) =>
      (.8 + 2 * hash(seed, k, 14), 1 + .8 * hash(seed, k, 15));
}
