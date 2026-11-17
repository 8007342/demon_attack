import 'dart:math' as math;

import 'carrier_gates.dart';

/// carrier-hatches (design §A2–§A6): the carrier's launch hatches on the
/// top surface, in tiers, and the core door. Pure Dart, simulation data:
/// the art conforms to these points (the rig's anchor gate), never the
/// reverse.
///
/// Hatches reuse [CarrierGate] (the volley state machine of carrier-v3
/// runs on them unchanged); [CarrierHatch] adds the tier and the hit
/// radii. The old carrier-v3 gates ([CarrierGates.forTour]) stay as art
/// decor and for the re-render's anchor check.
class CarrierHatch extends CarrierGate {
  const CarrierHatch(
    super.id,
    super.slot,
    super.kind,
    super.x,
    super.y,
    super.nx,
    super.ny, {
    required this.tier,
    super.width = 22,
  });

  /// 0-based upper tier (0 = U1, the topmost); [CarrierHatches.coreTier]
  /// for the core door.
  final int tier;

  bool get isCore => tier == CarrierHatches.coreTier;
}

/// One upper hatch's state in a fight (model-owned).
class HatchState {
  HatchState(this.hatch, {required this.fieldMax, required this.hullMax})
    : field = fieldMax,
      hull = hullMax;
  final CarrierHatch hatch;
  final int fieldMax, hullMax;
  int field, hull;

  /// Seconds since it was destroyed; negative while it stands.
  double fallen = -1;
  bool get destroyed => fallen >= 0;

  /// Its break-up is done ([CarrierHatches.fallSeconds] after the kill).
  bool get down => fallen >= CarrierHatches.fallSeconds;
  int get hp => field + hull;
  int get hpMax => fieldMax + hullMax;
}

enum CarrierChapter { hatches, transform, core }

abstract final class CarrierHatches {
  /// The core door's tier index.
  static const coreTier = 99;

  /// Hit radii (units): a hatch's field, then its hull (design §A3).
  static const fieldRadius = 24.0, hullRadius = 16.0;

  /// The armour band at the vulnerable tier's row: a shot crossing it
  /// within this half-width of the carrier's centre sparks off.
  static const armourHalfWidth = 130.0;

  /// The old shield's HP redistributed into the hatches (design §A3,
  /// calibrated §A11) and the field's share of each hatch.
  /// Per difficulty (easy, normal, hard; index [Difficulty.index]).
  /// Calibrated (plan/calibration-current.md, "Carrier hatches").
  static const pools = [.5, .55, .65], fieldShare = .6;

  /// The core's HP share per difficulty (calibration, §A11).
  static const coreShares = [.65, .8, .8];

  /// The carrier's fan-attack rate per difficulty (lever 5, §A11).
  static const fanShares = [.7, .85, .75];

  /// The core door's openness from which it takes hits (was 0.6).
  static const coreOpenAt = .4;

  /// A destroyed hatch has fallen when its break-up is done (§B4).
  static const fallSeconds = 1.2;

  /// The transformation (§A4) and its zoom-in rate (per second).
  static const transformSeconds = 3.5, zoomInRate = .04;

  /// The lateral glide's phase-rate factor per chapter (§A5).
  static const hatchGlide = .25, transformGlide = .25, coreGlide = .4;

  /// The core door's hit half-width per unit of openness (was 12).
  static const coreWindow = 24.0;

  /// The core door (the lower, delicate hatch).
  static const core = CarrierHatch(
    'core',
    'prow',
    CarrierGateKind.tusk,
    0,
    25,
    0,
    1,
    tier: coreTier,
    width: 20,
  );

  /// Upper tier rows per tour: (y, |x|).
  static const _rows = <List<(double, double)>>[
    [(-150, 72), (-70, 92)],
    [(-150, 72), (-70, 92)],
    [(-165, 70), (-110, 96), (-55, 80)],
    [(-165, 70), (-110, 96), (-55, 80)],
    [(-170, 68), (-125, 96), (-80, 84), (-35, 62)],
  ];

  /// Upper tiers of tour [route] (zero-based; later tours use tour 5's).
  static int tiersFor(int route) => _rows[route.clamp(0, 4)].length;

  /// The upper hatches of tour [route], tier by tier, left then right.
  static List<CarrierHatch> forTour(int route) {
    final rows = _rows[route.clamp(0, 4)];
    return [
      for (final (t, (y, x)) in rows.indexed)
        for (final s in const [-1, 1])
          CarrierHatch(
            'u${t + 1}${s < 0 ? 'L' : 'R'}',
            'carapace',
            CarrierGateKind.tusk,
            s * x,
            y,
            s * .2,
            -.98,
            tier: t,
          ),
    ];
  }

  /// Field and hull HP of each of [count] hatches from the old shield
  /// [shieldMax]: the pool split equally, 60 % field, each at least 3.
  static (int field, int hull) hpOf(
    int shieldMax,
    int count, {
    int difficulty = 1,
  }) {
    final each = (pools[difficulty] * shieldMax / math.max(1, count)).round();
    final field = math.max(3, (each * fieldShare).round());
    final hull = math.max(3, each - field);
    return (field, hull);
  }

  /// Seconds from a hatch at hull-local [y] to the fight's home row
  /// (y + 70): the 0.3 s pop-up, then the swoop at 300 units/s, rounded
  /// to 0.05 s (design §A6). The deck gives 0.55 s, today's entrance.
  static double transit(double y, {double dx = 0}) {
    final l = math.sqrt(dx * dx + (70 - y) * (70 - y));
    final t = .3 + math.max(.25, 1.1 * l / 300);
    return (t / .05).round() * .05;
  }

  /// How much earlier than today a flock from hull-local [y] must leave so
  /// it arrives at today's moment (today's entrance is 0.55 s).
  static double early(double y) => math.max(0, transit(y) - .55);
}
