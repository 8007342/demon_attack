// --- dynamic-weather: the rain plan (openspec/changes/dynamic-weather §1).
//
// Pure Dart (no dart:ui): which regular levels of a seeded run rain, how
// hard, with what wind, and when the rain starts and stops. Presentation
// only: nothing in the simulation reads it, so calibration is unchanged.
// Lightning and thunder are not part of it; they stay Stormfront's.
library;

import 'dart:math' as math;

/// The three named strengths (also the audio events' `tier`).
enum RainTier {
  drizzle,
  rain,
  downpour;

  /// The tier an instantaneous intensity (0-1) reads as; null when dry.
  static RainTier? of(double intensity) => intensity < RainPlan.wet
      ? null
      : intensity < .4
      ? drizzle
      : intensity < .72
      ? rain
      : downpour;
}

/// One level's rain. Times are combat seconds into the level
/// (`ArcadeModel.levelClock`).
class RainSpec {
  const RainSpec({
    required this.tier,
    required this.peak,
    required this.wind,
    this.startAt = 0,
    this.stopAt = double.infinity,
    this.rampIn = 0,
    this.rampOut = 8,
    this.gustPhase = 0,
  });

  /// The strength the level is planned around.
  final RainTier tier;

  /// Peak intensity, 0-1.
  final double peak;

  /// Slant: horizontal drift per unit of fall (+ blows to the right).
  final double wind;

  /// When the rain begins, and over how many seconds it builds. A level
  /// that rains from its start ([startAt] 0, [rampIn] 0) is already wet
  /// when the cloud of the Descent clears.
  final double startAt, rampIn;

  /// When it begins to ease off (infinity: it rains to the level's end),
  /// and over how many seconds it stops.
  final double stopAt, rampOut;

  /// Phase of the slow gusts (presentation wobble of ±10 %).
  final double gustPhase;

  bool get stops => stopAt.isFinite;

  /// The planned intensity at [t] combat seconds (0-1). [gusts]: the slow
  /// ±10 % swell (off with reduced motion).
  double intensityAt(double t, {bool gusts = true}) {
    double ramp(double x, double len) =>
        len <= 0 ? (x >= 0 ? 1 : 0) : _smooth((x / len).clamp(0.0, 1.0));
    final on = ramp(t - startAt, rampIn);
    final off = stops ? 1 - ramp(t - stopAt, rampOut) : 1.0;
    final swell = gusts
        ? 1 + .1 * math.sin(t * .45 + gustPhase) * math.sin(t * .17)
        : 1.0;
    return (peak * on * off * swell).clamp(0.0, 1.0);
  }

  @override
  String toString() =>
      'RainSpec(${tier.name}, peak ${peak.toStringAsFixed(2)}, '
      'wind ${wind.toStringAsFixed(2)}, ${startAt.toStringAsFixed(0)}s'
      '${stops ? '-${stopAt.toStringAsFixed(0)}s' : '-end'})';

  static double _smooth(double x) => x * x * (3 - 2 * x);
}

/// Draws a seeded run's weather, level by level.
abstract final class RainPlan {
  /// The salt that keeps the weather's stream apart from the bonus plan's
  /// and the carrier's.
  static const salt = 0x5241494E; // 'RAIN'

  /// About one eligible level in four rains.
  static const chance = .25;

  /// Sectors that may rain. Sector 5 (the carrier's) stays dry: the boss
  /// fight has its own presentation (boss-grandeur, carrier-v3).
  static const sectors = {1, 2, 3, 4};

  /// Below this intensity the rain is not drawn and counts as stopped.
  static const wet = .015;

  /// The rain of sector [sector] on route [route] of the run [runSeed];
  /// null when it is dry. An unseeded run ([runSeed] null: tests, the
  /// calibrated campaign) is always dry, and a bonus level never rains
  /// (the caller passes [bonus]).
  static RainSpec? forLevel(
    int? runSeed, {
    required int route,
    required int sector,
    bool bonus = false,
  }) {
    if (runSeed == null || bonus || !sectors.contains(sector)) return null;
    final r = math.Random(
      ((runSeed ^ salt) + route * 977 + sector * 131) & 0x3fffffff,
    );
    // Draw every number every time, so one level's odds never shift
    // another's.
    final fires = r.nextDouble() < chance;
    final tierU = r.nextDouble(), peakU = r.nextDouble();
    final windU = r.nextDouble(), sideU = r.nextDouble();
    final startU = r.nextDouble(), startT = r.nextDouble();
    final stopU = r.nextDouble(), stopT = r.nextDouble();
    final rampU = r.nextDouble(), gustU = r.nextDouble();
    if (!fires) return null;
    final tier = tierU < .4
        ? RainTier.drizzle
        : tierU < .8
        ? RainTier.rain
        : RainTier.downpour;
    final (lo, hi) = switch (tier) {
      RainTier.drizzle => (.18, .32),
      RainTier.rain => (.46, .64),
      RainTier.downpour => (.82, 1.0),
    };
    // Heavier rain leans harder in the wind.
    final (wLo, wHi) = switch (tier) {
      RainTier.drizzle => (.02, .16),
      RainTier.rain => (.06, .26),
      RainTier.downpour => (.14, .38),
    };
    final fromStart = startU < .5;
    final startAt = fromStart ? 0.0 : 8 + 32 * startT;
    final stops = stopU < .3;
    return RainSpec(
      tier: tier,
      peak: lo + (hi - lo) * peakU,
      wind: (sideU < .5 ? -1 : 1) * (wLo + (wHi - wLo) * windU),
      startAt: startAt,
      rampIn: fromStart ? 0 : 6 + 6 * rampU,
      stopAt: stops ? startAt + 40 + 50 * stopT : double.infinity,
      rampOut: 7 + 5 * rampU,
      gustPhase: gustU * math.pi * 2,
    );
  }
}
