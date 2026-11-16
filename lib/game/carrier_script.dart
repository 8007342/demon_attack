import 'dart:math' as math;

import 'carrier_gates.dart';

/// carrier-v3 §9: every number of a tour's carrier, as data. Tours 1–5
/// (routes 0–4) are authored ([CarrierScript.authored]); an unseeded run
/// (tests, the calibrated campaign) uses them as they are. A seeded run
/// varies the presentation (which gates launch first, the volley order,
/// the surge timing, ±10 % on the cue intensities) and keeps the gameplay
/// numbers authored ([CarrierScript.forRun]). Routes beyond tour 5 draw a
/// seeded script within tour 5's limits.
///
/// Pure Dart: the model reads the gameplay fields, the director and the
/// scene read the rest.
class CarrierScript {
  const CarrierScript({
    required this.route,
    required this.launchWaves,
    required this.approach,
    required this.gates,
    required this.gateOrder,
    this.volley = const CarrierVolley(),
    required this.camera,
    this.bend = const CarrierBendLimits(),
    required this.cues,
    this.field = const CarrierFieldStyle(),
    this.seeded = false,
  });

  /// Zero-based tour (route 0 is tour 1).
  final int route;
  int get tour => route + 1;

  /// Launch waves of the boss level (the old loom waves): 2 on tours 1–3,
  /// 3 from tour 4 (design §4.3).
  final int launchWaves;
  final CarrierApproachScript approach;

  /// The hull's gates (gameplay data, [CarrierGates.forTour]).
  final List<CarrierGate> gates;

  /// The round-robin order over [gates] (indices): authored left-right
  /// alternation, or a seeded permutation.
  final List<int> gateOrder;
  final CarrierVolley volley;
  final CarrierCamera camera;
  final CarrierBendLimits bend;
  final CarrierCues cues;
  final CarrierFieldStyle field;

  /// Whether a run seed varied this script.
  final bool seeded;

  /// Easy's second launch wave keeps this share of its roster (every tour
  /// keeps two launch waves; the boss level's clear time stays within its
  /// 10 % gate on Easy). One constant.
  static const easySecondWave = .5;

  /// The authored tours: routes 0–4; later routes clamp to tour 5.
  static CarrierScript authored(int route) {
    final r = route.clamp(0, 4);
    final waves = r <= 2 ? 2 : 3;
    final d0 = r == 0 ? 4.0 : (r <= 2 ? 4.5 : 5.0);
    final gates = CarrierGates.forTour(r);
    return CarrierScript(
      route: route,
      launchWaves: waves,
      approach: CarrierApproachScript(
        distances: waves == 2 ? [d0, 2.4, 1.35] : [d0, 3.2, 2.0, 1.35],
      ),
      gates: gates,
      gateOrder: CarrierGates.alternating(gates),
      camera: CarrierCamera(
        minZoom: CarrierCamera.minZoomFor(r),
        maxAltitude: 1.6 + .05 * r,
        envelope: CarrierCamera.envelopes[r],
      ),
      cues: CarrierCues(streakDensity: 12 + 7.0 * r),
    );
  }

  /// The script of tour [route] for a run seeded with [runSeed]: authored
  /// when the run is unseeded; otherwise the authored gameplay with seeded
  /// presentation; beyond tour 5, a seeded script within tour 5's limits.
  static CarrierScript forRun(int? runSeed, int route) {
    final base = authored(route);
    if (runSeed == null) return base;
    final rng = math.Random(_mix(runSeed, route));
    double vary(double v) => v * (.9 + .2 * rng.nextDouble());
    final order = List<int>.of(base.gateOrder);
    // Which gates launch first: rotate the alternation, then swap pairs.
    final start = rng.nextInt(order.length);
    final rotated = [...order.sublist(start), ...order.sublist(0, start)];
    for (var i = 0; i + 1 < rotated.length; i += 2) {
      if (rng.nextBool()) {
        final t = rotated[i];
        rotated[i] = rotated[i + 1];
        rotated[i + 1] = t;
      }
    }
    var camera = base.camera;
    var bend = base.bend;
    if (route > 4) {
      // Beyond tour 5: seeded within tour 5's limits (never wider than
      // 0.62, never a larger bend).
      final z = .62 + .02 * rng.nextInt(3);
      camera = CarrierCamera(
        minZoom: z,
        maxAltitude: 1.7 + .1 * rng.nextDouble(),
        envelope: CarrierCamera.envelopes[4],
      );
      final k = .8 + .2 * rng.nextDouble();
      bend = CarrierBendLimits(
        leanMax: base.bend.leanMax * k,
        bankMax: base.bend.bankMax * k,
        pitchMax: base.bend.pitchMax * k,
      );
    }
    final surge = 12 + 8 * rng.nextDouble();
    return CarrierScript(
      route: route,
      launchWaves: base.launchWaves,
      approach: base.approach,
      gates: base.gates,
      gateOrder: rotated,
      volley: base.volley,
      camera: camera,
      bend: bend,
      cues: CarrierCues(
        streakDensity: math.min(40, vary(base.cues.streakDensity)),
        flowBoostMax: math.min(
          base.cues.flowBoostMax * 1.1,
          vary(base.cues.flowBoostMax),
        ),
        firstSurge: surge,
        surgeSeed: rng.nextInt(1 << 30),
        intensity: vary(1),
      ),
      field: base.field,
      seeded: true,
    );
  }

  static int _mix(int seed, int route) {
    var h = (seed ^ 0xB055 ^ 0xC5C1) * 0x9E3779B1 + route * 0x85EBCA77;
    h &= 0xFFFFFFFF;
    h ^= h >> 15;
    h = (h * 0x2C1B3C6D) & 0xFFFFFFFF;
    return h ^ (h >> 12);
  }
}

/// The approach (design §5.2): the distance factor D (the carrier's scale
/// on screen is 1/D) steps closer each time a launch wave is cleared, and
/// creeps between steps; the Close takes it from [closeFrom] to 1.
class CarrierApproachScript {
  const CarrierApproachScript({
    required this.distances,
    this.creep = .012,
    this.stepSeconds = 3,
    this.closeSeconds = 4,
    this.cap = 90,
  });

  /// D at the start, then after each cleared launch wave; the last entry is
  /// the Close's start (1.35).
  final List<double> distances;
  double get d0 => distances.first;
  double get closeFrom => distances.last;

  /// D creeps down at this rate between steps (never past the next step).
  final double creep;

  /// Each step eases over this long (slow in, slow out).
  final double stepSeconds;

  /// The Close: [closeFrom] → 1 over this long; the carrier is hittable at
  /// its end (`Carrier.emerge` is its progress).
  final double closeSeconds;

  /// The approach's cap: the Close starts anyway (combat seconds).
  final double cap;

  /// Where the approaching carrier is drawn at distance [d] (arena units):
  /// high near the far banks, descending to its fight row as it closes;
  /// its drift dies out in range. [clock]: the approach's seconds.
  static ({double x, double y}) placement(double d, double clock) {
    final y = math.max(100.0, 205 - 87 * (d - 1) / 3);
    final x = 180 + 46 * math.sin(clock * .13) * (1 - 1 / d);
    return (x: x, y: y);
  }

  /// Aerial perspective (design §5.2): the fog mix at distance [d].
  static double fogMix(double d) =>
      d <= 1 ? 0 : 1 - math.exp(-.55 * (d - 1));
}

/// The volley timing (design §4.2).
class CarrierVolley {
  const CarrierVolley({
    this.telegraph = 1.2,
    this.open = .5,
    this.interval = .12,
    this.close = .8,
    this.maxOpen = 2,
  });
  final double telegraph, open, interval, close;
  final int maxOpen;

  /// From the telegraph's start to the first ejection.
  double get lead => telegraph + open;
}

/// The per-tour framing (design §6.2).
class CarrierCamera {
  const CarrierCamera({
    required this.minZoom,
    required this.maxAltitude,
    required this.envelope,
    this.horizonDrop = 18,
  });
  final double minZoom, maxAltitude;

  /// The visible envelope (carrier-relative x half-width, top y, bottom y).
  final (double, double, double) envelope;

  /// The horizon sinks by this × climb below its place (design §6.1).
  final double horizonDrop;

  /// The one constant of the zoom ladder: each later tour frames this much
  /// wider, from tour 1's 0.70 down to the mobile limit 0.62.
  static const zoomStep = .02, firstZoom = .70, mobileLimit = .62;
  static double minZoomFor(int route) =>
      math.max(mobileLimit, firstZoom - zoomStep * route.clamp(0, 4));

  static const envelopes = <(double, double, double)>[
    (360, -430, 240),
    (370, -450, 240),
    (375, -470, 240),
    (380, -490, 240),
    (390, -520, 240),
  ];
}

/// Bend limits in degrees and the drivers' constants (design §2.3).
class CarrierBendLimits {
  const CarrierBendLimits({
    this.leanMax = 3,
    this.bankMax = 2.5,
    this.pitchMax = 2,
    this.takeoffPitch = 3,
    this.wingLag = .25,
    this.wingGain = 1.25,
    this.buffet = .25,
  });
  final double leanMax, bankMax, pitchMax, takeoffPitch;

  /// Wing follow-through: first-order lag (s) and amplitude at the tip.
  final double wingLag, wingGain;

  /// Buffet amplitude on bank and pitch (degrees).
  final double buffet;
}

/// Speed-cue intensities (design §7).
class CarrierCues {
  const CarrierCues({
    required this.streakDensity,
    this.flowBoostMax = 2.2,
    this.takeoffBoost = 3.0,
    this.surgeBoost = .6,
    this.surgeEvery = (12, 20),
    this.firstSurge = 14,
    this.surgeSeed = 0,
    this.punchShare = 3,
    this.vortex = true,
    this.wisps = 1,
    this.intensity = 1,
  });

  /// Streaks per screen at full climb (12–40).
  final double streakDensity;
  final double flowBoostMax, takeoffBoost, surgeBoost;

  /// Seconds between surges (seeded within), and the first one.
  final (double, double) surgeEvery;
  final double firstSurge;
  final int surgeSeed;

  /// One surge in [punchShare] is a cloud punch.
  final int punchShare;
  final bool vortex;
  final double wisps, intensity;
}

/// The force field's look (design §3).
class CarrierFieldStyle {
  const CarrierFieldStyle({
    this.regionOrder = defaultOrder,
    this.offsetMin = 6,
    this.offsetMax = 24,
    this.scanPeriod = 4,
  });

  /// Regions in the order they go dark (design §3.2): from the outer arms
  /// inward, alternating sides, the prow last.
  final List<CarrierRegion> regionOrder;

  /// The membrane sits `offsetMin + (offsetMax − offsetMin)·s` units outside
  /// the hull's edge (s = shield / shieldMax).
  final double offsetMin, offsetMax, scanPeriod;

  static const defaultOrder = [
    CarrierRegion.wingTipL,
    CarrierRegion.wingTipR,
    CarrierRegion.wingRootL,
    CarrierRegion.wingRootR,
    CarrierRegion.prongOuterL,
    CarrierRegion.prongOuterR,
    CarrierRegion.aftFlankL,
    CarrierRegion.aftFlankR,
    CarrierRegion.prongInnerL,
    CarrierRegion.prongInnerR,
    CarrierRegion.citadel,
    CarrierRegion.prow,
  ];

  /// The region shield cell [cell] (0–11, lost from 11 down) guards.
  CarrierRegion regionOfCell(int cell) => regionOrder[11 - cell.clamp(0, 11)];

  /// The regions still lit with [cells] shield cells left.
  Set<CarrierRegion> litRegions(int cells) =>
      {for (var c = 0; c < cells.clamp(0, 12); c++) regionOfCell(c)};

  double offsetFor(double s) => offsetMin + (offsetMax - offsetMin) * s;
}

/// The twelve field regions, one per shield cell (design §3.2).
enum CarrierRegion {
  wingTipL,
  wingTipR,
  wingRootL,
  wingRootR,
  aftFlankL,
  aftFlankR,
  prongOuterL,
  prongOuterR,
  prongInnerL,
  prongInnerR,
  citadel,
  prow;

  /// The region of hull-local point ([x], [y]) (arena units from the
  /// carrier centre, y down-screen). A fixed partition of the envelope:
  /// the prow under the deck, the citadel above it, prongs left and right
  /// of the prow, aft flanks behind them, wings outermost.
  static CarrierRegion at(double x, double y) {
    final ax = x.abs();
    final left = x < 0;
    CarrierRegion side(CarrierRegion l, CarrierRegion r) => left ? l : r;
    if (ax >= 250) {
      return y < -150
          ? side(CarrierRegion.wingTipL, CarrierRegion.wingTipR)
          : side(CarrierRegion.wingRootL, CarrierRegion.wingRootR);
    }
    if (y >= -30) {
      if (ax < 90) return CarrierRegion.prow;
      return ax < 170
          ? side(CarrierRegion.prongInnerL, CarrierRegion.prongInnerR)
          : side(CarrierRegion.prongOuterL, CarrierRegion.prongOuterR);
    }
    if (ax < 120) return CarrierRegion.citadel;
    return y < -200
        ? side(CarrierRegion.wingRootL, CarrierRegion.wingRootR)
        : side(CarrierRegion.aftFlankL, CarrierRegion.aftFlankR);
  }
}
