import 'dart:math' as math;

import 'ground_presentation.dart';
import 'model.dart';

/// The ground war's easter eggs (plan/ground-easter-eggs.md; openspec
/// change ground-easter-eggs).
enum EasterEgg {
  /// A Fleet squad's victory flourish (or a convoy vehicle's turret twirl)
  /// after a skirmish win or a save.
  dance,

  /// Every Fleet squad on screen dances once at sector clear.
  sectorDance,

  /// A Host squad's taunt jig when the ally it fought falls back.
  jig,

  /// A light Host vehicle's turret pops, spins and lands; a crew of two
  /// scampers off.
  jackpot,

  /// Small flyers burst from a falling tree and fly off into the fog.
  flock,

  /// Critters near the troops scatter toward the outer edge.
  critters,
}

/// One egg's rarity (`num` in `den`), cooldown and running time.
typedef EasterEggRule = ({
  int num,
  int den,
  double cooldown,
  bool perBand,
  double duration,
});

/// The one place that says when an easter egg may run (plan section 1).
/// Presentation only: it reads the model, never writes it, and never draws
/// from `model.random` or any simulation stream. Decisions are a pure
/// function of the run seed, the egg, its key and the budget's own clock,
/// so the same run shows the same eggs.
class EasterEggBudget {
  EasterEggBudget({this.seed = 1982});

  /// The run seed (`ArcadeModel.seed`).
  int seed;

  /// Master switch (tests, comparisons): false grants nothing.
  bool enabled = true;

  /// Reduced motion: dances, jigs, flocks, critter flights and the jackpot
  /// are off (a light vehicle's breakup becomes the plain wreck).
  bool reducedMotion = false;

  /// Tests only: grant every rarity roll.
  bool alwaysRoll = false;

  /// The budget's clock (seconds of unpaused play).
  double clock = 0;

  /// Why eggs are suppressed right now (null: they may run).
  String? quiet;

  static const maxConcurrent = 2, maxPerBand = 1;
  static const maxFlock = 9, maxCritters = 8;
  static const maxDebrisPerBreakup = 8, maxDebrisOnScreen = 16;

  /// Depth beyond which eggs are not seen (flocks excepted).
  static const farZ = 900.0;

  /// The operator's defaults (plan sections 2-5). Running times of the
  /// one-shot eggs are doubled (openspec change ground-presentation-tuning:
  /// ground motion at half speed): dance 3.2 s, jig 2 s, jackpot 5 s,
  /// critter scatter 5 s. The sector-clear dance loops, so it keeps 3 s.
  static const Map<EasterEgg, EasterEggRule> rules = {
    EasterEgg.dance: (
      num: 1,
      den: 3,
      cooldown: 40,
      perBand: false,
      duration: 1.6 / GroundPace.egg,
    ),
    EasterEgg.sectorDance: (
      num: 1,
      den: 1,
      cooldown: 0,
      perBand: false,
      duration: 3,
    ),
    EasterEgg.jig: (
      num: 1,
      den: 4,
      cooldown: 60,
      perBand: false,
      duration: 1.0 / GroundPace.egg,
    ),
    EasterEgg.jackpot: (
      num: 1,
      den: 8,
      cooldown: 20,
      perBand: false,
      duration: 2.5 / GroundPace.egg,
    ),
    EasterEgg.flock: (
      num: 2,
      den: 5,
      cooldown: 12,
      perBand: false,
      duration: 2.5,
    ),
    EasterEgg.critters: (
      num: 1,
      den: 1,
      cooldown: 8,
      perBand: true,
      duration: 2.5 / GroundPace.fx,
    ),
  };

  final List<({EasterEgg egg, int band, double until})> _running = [];
  final Map<(EasterEgg, int), double> _last = {};
  final Map<EasterEgg, Expando<bool>> _decided = {};

  /// Eggs started this run, by kind (tests, review).
  final Map<EasterEgg, int> started = {};

  /// Advances the clock and the suppression state (scene update).
  void update(double dt, ArcadeModel m) {
    quiet = quietReason(m);
    tick(dt);
  }

  /// Advances the clock alone (tests, tools).
  void tick(double dt) {
    clock += dt;
    _running.removeWhere((r) => r.until <= clock);
  }

  /// Plan rule 4: quiet when it matters. Also quiet in a dense fight
  /// (several dives or hostile shots at once).
  static String? quietReason(ArcadeModel m) {
    if (m.boss != null) return 'boss';
    final g = m.ground;
    if (g.missiles.isNotEmpty ||
        g.units.any((u) => u.alive && u.telegraphing)) {
      return 'telegraph';
    }
    if (m.lives <= 1 && m.mode != RunMode.title) return 'last life';
    if (m.lifeLossPhase != LifeLossPhase.none ||
        (m.combat && m.invulnerable > 0)) {
      return 'player hit';
    }
    if (m.presentationMode == RunMode.transition) return 'arrival hint';
    var hostile = 0;
    for (final s in m.shots) {
      if (s.hostile) hostile++;
    }
    var diving = 0;
    for (final d in m.demons) {
      if (d.dive > 0 || d.telegraph > 0) diving++;
    }
    if (hostile >= 6 || diving >= 3) return 'dense fight';
    return null;
  }

  /// Seeded uniform value in [0, 1) for ([egg], [key]): Park-Miller steps
  /// (the VM and the web agree).
  double roll(EasterEgg egg, int key) {
    const m = 2147483647;
    var h = (seed * 73 + 19) % m;
    h = (h * 48271 + egg.index * 7919 + 1) % m;
    h = (h * 48271 + key % 100003) % m;
    h = (h * 48271 + (key ~/ 100003) % 100003) % m;
    h = (h * 48271) % m;
    h = (h * 48271) % m;
    return h / m;
  }

  /// A seeded integer in [lo, hi] for ([egg], [key], [salt]).
  int pick(EasterEgg egg, int key, int salt, int lo, int hi) =>
      lo +
      (roll(egg, key * 31 + salt) * (hi - lo + 1)).floor().clamp(0, hi - lo);

  int get running => _running.length;
  int runningIn(int band) => _running.where((r) => r.band == band).length;
  bool isRunning(EasterEgg egg) => _running.any((r) => r.egg == egg);

  /// May [egg] start now for [key] in side [band] (0 left, 1 right)? A
  /// grant registers it as running. [guaranteed] skips rarity, cooldown,
  /// concurrency and suppression (the sector-clear dance) but not reduced
  /// motion or the master switch.
  bool request(
    EasterEgg egg, {
    required int key,
    required int band,
    bool guaranteed = false,
  }) {
    if (!enabled || reducedMotion) return false;
    final rule = rules[egg]!;
    if (!guaranteed) {
      if (quiet != null) return false;
      if (!alwaysRoll && roll(egg, key) * rule.den >= rule.num) return false;
      final last = _last[(egg, rule.perBand ? band : -1)];
      if (last != null && clock - last < rule.cooldown) return false;
      if (running >= maxConcurrent || runningIn(band) >= maxPerBand) {
        return false;
      }
      _last[(egg, rule.perBand ? band : -1)] = clock;
      _running.add((egg: egg, band: band, until: clock + rule.duration));
    }
    started[egg] = (started[egg] ?? 0) + 1;
    return true;
  }

  /// [request], asked once per [owner] (a simulation object): later calls
  /// return the first answer, so a painter may ask every frame.
  bool decide(
    Object owner,
    EasterEgg egg, {
    required int key,
    required int band,
    bool guaranteed = false,
  }) {
    final memo = _decided.putIfAbsent(egg, Expando<bool>.new);
    return memo[owner] ??= request(
      egg,
      key: key,
      band: band,
      guaranteed: guaranteed,
    );
  }

  /// Whether [owner] was already asked about [egg] (and the answer).
  bool? decided(Object owner, EasterEgg egg) => _decided[egg]?[owner];

  /// Debris pieces of one breakup: 5-8 for a light Host vehicle, 3-4 for a
  /// heavier one (plan section 3).
  int debrisPieces(int key, {required bool light}) => math.min(
    maxDebrisPerBreakup,
    light
        ? pick(EasterEgg.jackpot, key, 3, 5, 8)
        : pick(EasterEgg.jackpot, key, 4, 3, 4),
  );

  /// Side band of a screen x.
  static int bandOf(double x) => x < 180 ? 0 : 1;

  /// Forgets running eggs and cooldowns (a new run).
  void reset() {
    _running.clear();
    _last.clear();
    _decided.clear();
    started.clear();
    clock = 0;
  }
}
