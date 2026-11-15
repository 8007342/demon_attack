/// The cinematic flow's one clock (openspec/changes/cinematic-flow design
/// §1; plan/swarm-research.md §2.2-§2.3).
///
/// The macron.dev pattern in game form: a transition is one normalized clock
/// u in [0, 1], its beats are overlapping `bump` envelopes on that clock, and
/// every actor (ship pose, camera tilt, cloud cover, palette swap, the
/// pursued flock, the message slot, the sector title) is a pure function of
/// the envelopes plus its own phase offset. Nothing keeps its own timer.
///
/// The director owns presentation only. Gameplay timing (phase lengths,
/// pickups, invulnerability) stays in `ArcadeModel`, which feeds the
/// director its own phase clock ([FlowDirector.at]), so the two can never
/// drift: pause freezes both.
///
/// Pure Dart, deterministic, no Flutter.
library;

import 'dart:math' as math;

/// Hermite smoothstep of [x] over [e0, e1]; a step when e0 == e1.
double flowSmoothstep(double e0, double e1, double x) {
  if (e1 <= e0) return x < e0 ? 0 : 1;
  final t = ((x - e0) / (e1 - e0)).clamp(0.0, 1.0);
  return t * t * (3 - 2 * t);
}

/// Eases in over [a, b] and out over [c, d] (macron's `bump`).
double bump(double a, double b, double c, double d, double u) =>
    flowSmoothstep(a, b, u) * (1 - flowSmoothstep(c, d, u));

/// The beat length of the score's grid: 120 BPM.
const flowBeat = .5;

/// Rounds [seconds] up to whole beats of the 120 BPM grid.
double wholeBeats(double seconds) =>
    (seconds / flowBeat - 1e-9).ceilToDouble() * flowBeat;

/// One beat: an envelope on the plan's seconds, eased in over [a, b] and out
/// over [c, d]. A beat whose [c] lies past the plan's end is a ramp that
/// stays at its [gain]. [gain] scales the envelope (reduced motion zeroes the
/// motion beats but keeps their ids).
class FlowBeat {
  const FlowBeat(this.id, this.a, this.b, this.c, this.d, {this.gain = 1});
  final String id;
  final double a, b, c, d, gain;

  double at(double s) => gain * bump(a, b, c, d, s);

  /// Seconds this beat starts to be felt.
  double get start => a;
}

enum FlowKind {
  idle,
  sectorChange,
  bossArrival,
  bossVictory,
  campaignOutro,
  gameOverOutro,
  attract,
}

/// The beats of one transition kind at one motion setting. Times are plan
/// seconds; [env] reads them on the normalized clock.
class FlowPlan {
  const FlowPlan(
    this.kind,
    this.seconds,
    this.beats, {
    this.reduced = false,
    this.descentAt = 0,
    this.swapAt,
    this.pursuitSeconds = 0,
  });

  final FlowKind kind;
  final double seconds;
  final List<FlowBeat> beats;
  final bool reduced;

  /// Plan second the Descent begins (the next sector's arrival).
  final double descentAt;

  /// Plan second the palette swap starts, if the plan has one.
  final double? swapAt;

  /// Seconds of Pursuit (whole beats).
  final double pursuitSeconds;

  static const idle = FlowPlan(FlowKind.idle, 1, []);

  FlowBeat? beat(String id) {
    for (final b in beats) {
      if (b.id == id) return b;
    }
    return null;
  }

  Set<String> get ids => {for (final b in beats) b.id};

  /// The envelope of [id] at plan second [s] (0 for an unknown beat).
  double envAt(String id, double s) => beat(id)?.at(s) ?? 0;

  // --- timings --------------------------------------------------------------

  /// Rout: the salvage grace (gameplay, unchanged by this change).
  static const routSeconds = 2.0;

  /// Pursuit's model phases: level clear, then travel (full motion).
  static const clearSeconds = 2.0, travelSeconds = 4.0;

  /// Reduced motion: the same beats as shorter crossfades (Pursuit 3.5 s).
  static const clearSecondsReduced = 1.0, travelSecondsReduced = 2.5;

  /// The longest extension of Pursuit a message slot may ask for.
  static const maxExtra = 2.0;

  /// Descent: the next sector's opening arrival (`arrivalHintDuration`).
  static const descentSeconds = 4.5, descentSecondsReduced = 3.0;

  /// Boss victory celebration (the victory's Rout).
  static const victorySeconds = 5.5;

  /// A message slot never starts this close to the swap (cannonball: never
  /// an art beat and an instruction at the same instant).
  static const seamGuard = .5;

  /// Sector title at the top edge during the Descent.
  static const titleSeconds = 1.5;

  /// The game-over mill over the wreck.
  static const millSeconds = 2.0;

  /// Level clear's length at a motion setting.
  static double clearFor(bool reduced) =>
      reduced ? clearSecondsReduced : clearSeconds;

  /// Travel's length at a motion setting with a slot's [extra] seconds
  /// (clamped to [maxExtra] and rounded up so Pursuit stays whole beats).
  static double travelFor(bool reduced, {double extra = 0}) =>
      (reduced ? travelSecondsReduced : travelSeconds) +
      wholeBeats(extra.clamp(0.0, maxExtra));

  // --- plans ------------------------------------------------------------------

  /// A sector change: Rout (salvage), Pursuit (level clear + travel) and
  /// Descent (the next sector's arrival). [boss]: the Descent is the
  /// carrier's arrival through the swarm (design §3.1). [victory]: the Rout
  /// is a carrier's 5.5 s celebration and Pursuit is travel alone.
  factory FlowPlan.sectorChange({
    bool reduced = false,
    double extra = 0,
    bool boss = false,
    bool victory = false,
  }) {
    final rout = victory ? victorySeconds : routSeconds;
    final pursuit =
        (victory ? 0 : clearFor(reduced)) + travelFor(reduced, extra: extra);
    final p0 = rout, p1 = rout + pursuit;
    final descent = reduced ? descentSecondsReduced : descentSeconds;
    final total = p1 + descent;
    final m = reduced ? 0.0 : 1.0; // motion gain
    final end = total + 1; // ramps that hold to the end
    // The cloud is up by the time the swap starts and stays up past the
    // level change at p1 (the new sector's ground loads under it).
    final cloudUp = reduced ? p0 + .5 : p0 + 1.0;
    final cloudFull = reduced ? p0 + 1.3 : p0 + 2.6;
    final swap = cloudFull + (reduced ? .2 : .4);
    final cloudOut = p1 + (reduced ? .2 : .4);
    final cloudClear = p1 + (reduced ? 1.2 : 2.2);
    final slot = p0 + (reduced ? .4 : .5);
    final title = p1 + (reduced ? .6 : 1.0);
    final kind = victory
        ? FlowKind.bossVictory
        : boss
        ? FlowKind.bossArrival
        : FlowKind.sectorChange;
    return FlowPlan(
      kind,
      total,
      [
        // The last kill: an instant flash, gone in a quarter second.
        const FlowBeat('hit', 0, 0, .06, .3),
        // The remaining brood flash-expands and flees into the fog.
        FlowBeat('rout', 0, .3, p0 - .4, p0 + .6),
        // The ship climbs nose-up and drops back to its row in the Descent.
        FlowBeat('climb', p0, p0 + 1.5, p1 - .5, p1 + 1.6, gain: m),
        FlowBeat('tilt', p0 + .2, p0 + 2.0, p1 - .3, p1 + 1.8, gain: m),
        FlowBeat('cloud', cloudUp, cloudFull, cloudOut, cloudClear),
        // The palette and backdrop change inside the cloud's peak.
        FlowBeat('swap', swap, swap + (reduced ? .5 : 1.0), end, end),
        // The fleeing flock streams ahead; the ship chases it.
        FlowBeat('pursue', rout - .4, p0 + 1.0, p1, p1 + 1.0),
        // One message slot: a radio line on the dock or a caption.
        FlowBeat('slot', slot, slot + .5, p1 - .5, p1),
        // The flock comes out of the cloud as the new sector's swarm.
        FlowBeat('wheel', p1 + .3, p1 + 1.5, end, end),
        FlowBeat(
          'title',
          title,
          title + .3,
          title + titleSeconds - .3,
          title + titleSeconds,
        ),
        if (boss) ...[
          // The flock rings the arrival point, parts for the carrier and
          // pours into its bays when it settles (design §3.1).
          FlowBeat('mill', p1 + .3, p1 + 1.2, p1 + 3.2, p1 + 3.8),
          FlowBeat('vacuole', p1 + 1.0, p1 + 2.0, end, end),
          FlowBeat('pour', p1 + 2.8, total - .6, end, end),
        ],
      ],
      reduced: reduced,
      descentAt: p1,
      swapAt: swap,
      pursuitSeconds: pursuit,
    );
  }

  /// The campaign's end (design §4.1): the final victory's Rout, then the
  /// fog thins, shadows lift, and the ship climbs above the clouds into the
  /// ending, which fades up at [endingAt].
  factory FlowPlan.campaignOutro({bool reduced = false}) {
    const total = victorySeconds;
    final m = reduced ? 0.0 : 1.0;
    const end = total + 1;
    return FlowPlan(
      FlowKind.campaignOutro,
      total,
      [
        const FlowBeat('hit', 0, 0, .06, .3),
        const FlowBeat('rout', 0, .3, 2.0, 3.0),
        const FlowBeat('thin', 1.5, 4.0, end, end),
        const FlowBeat('lift', 1.5, 3.5, end, end),
        FlowBeat('climb', 2.5, 5.0, end, end, gain: m),
        FlowBeat('tilt', 2.6, 5.0, end, end, gain: m),
        // Bright cloud tops below the ship; never more than a soft veil.
        const FlowBeat('cloud', 2.8, 4.6, end, end, gain: .7),
        FlowBeat('ending', endingAt, endingAt + .8, end, end),
      ],
      reduced: reduced,
      descentAt: total,
    );
  }

  /// The ending page fades up at this plan second (main.dart opens it).
  static const endingAt = victorySeconds * .72;

  /// Game over (design §4.2): the swarm mills over the wreck for
  /// [millSeconds], then breaks upward with the skyward pan. [seconds] is
  /// the defeat celebration's length; [panAt] its pan's start.
  factory FlowPlan.gameOverOutro({
    bool reduced = false,
    double seconds = 5.8,
    double panAt = 5.8 * .74,
  }) {
    final millIn = panAt - millSeconds - .6;
    return FlowPlan(
      FlowKind.gameOverOutro,
      seconds,
      [
        FlowBeat('mill', millIn, millIn + .6, panAt, panAt + .8),
        // Reduced motion: a static ring that fades (no rotation).
        FlowBeat(
          'spin',
          millIn,
          millIn + .6,
          panAt,
          panAt + .8,
          gain: reduced ? 0 : 1,
        ),
        FlowBeat('break', panAt, panAt + 1.0, seconds + 1, seconds + 1),
      ],
      reduced: reduced,
      descentAt: seconds,
    );
  }

  /// The title's attract loop (design §5): squads mill and stream, the
  /// sentinel passes once per loop.
  factory FlowPlan.attract({bool reduced = false}) => FlowPlan(
    FlowKind.attract,
    attractSeconds,
    [
      const FlowBeat('mill', 0, 2, attractSeconds - 2, attractSeconds),
      const FlowBeat('sentinel', 4, 7, 13, 16),
      FlowBeat(
        'drift',
        0,
        2,
        attractSeconds - 2,
        attractSeconds,
        gain: reduced ? 0 : 1,
      ),
    ],
    reduced: reduced,
    descentAt: attractSeconds,
  );

  static const attractSeconds = 20.0;
}

/// Plays one [FlowPlan] on the clock its owner feeds it.
class FlowDirector {
  FlowPlan plan = FlowPlan.idle;

  /// Plan seconds elapsed.
  double seconds = 0;

  bool get active => plan.kind != FlowKind.idle;
  FlowKind get kind => plan.kind;

  /// The normalized clock.
  double get u => (seconds / plan.seconds).clamp(0.0, 1.0);

  /// Starts [next] at its beginning.
  void start(FlowPlan next) {
    plan = next;
    seconds = 0;
  }

  /// Replaces the plan keeping the clock (a slot extended Pursuit).
  void replan(FlowPlan next) => plan = next;

  void stop() {
    plan = FlowPlan.idle;
    seconds = 0;
  }

  /// Sets the clock to plan second [s] (the model's phase clock).
  void at(double s) => seconds = s.clamp(0.0, plan.seconds);

  /// Advances the clock (loops for attract).
  void advance(double dt) {
    if (!active) return;
    seconds += dt;
    if (plan.kind == FlowKind.attract) {
      seconds %= plan.seconds;
    } else {
      seconds = math.min(seconds, plan.seconds);
    }
  }

  /// Jumps to the Descent (skip).
  void skipToDescent() => at(plan.descentAt);

  /// The envelope of beat [id] now.
  double env(String id) => plan.envAt(id, seconds);

  /// A beat [id] is being felt now.
  bool on(String id) => env(id) > 0;

  /// The pursued flock's member [i] of [n] (seed [seed]) at the current
  /// clock: a normalized screen offset per member, macron's per-instance
  /// phase offset (`sin(ph · 3 + k · 0.9)`), so the flock never moves in
  /// lockstep. Returns (dx, dy) in -1..1.
  (double, double) phase(int i, double seed) {
    final ph = seconds;
    return (
      math.sin(ph * 3 + i * .9 + seed),
      math.cos(ph * 2.3 + i * 1.3 + seed * .7),
    );
  }
}
