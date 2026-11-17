// phone-performance (openspec/changes/phone-performance): the frame budget.
//
// Pure Dart (no dart:ui): the quality tiers, their caps, the governor that
// picks a tier from measured frame intervals, the frame-pacing snap and the
// layer marker the frame-cost harness listens to. Painters read the caps;
// nothing here touches the simulation.
import 'dart:math' as math;

/// The quality tier. Tier 0 is the full look; higher tiers shed ambient
/// load first (fog sheets, rain, ambient flyers, blur), never gameplay.
enum PerfTier {
  full('FULL'),
  lean('LEAN'),
  lite('LITE');

  const PerfTier(this.label);
  final String label;

  static PerfTier? parse(String? s) => switch (s?.toLowerCase()) {
    'full' || '0' => PerfTier.full,
    'lean' || '1' => PerfTier.lean,
    'lite' || '2' => PerfTier.lite,
    _ => null,
  };
}

/// Per-tier budgets. Every number is a hard ceiling on what a painter may
/// draw in one frame; the review sheets justify each (design §4).
class FrameBudget {
  const FrameBudget._({
    required this.rainScale,
    required this.moteScale,
    required this.blasts,
    required this.sparks,
    required this.blur,
    required this.fogReduced,
    required this.emergence,
    required this.lurkers,
    required this.hatchVents,
  });

  /// Rain drops and splashes, as a fraction of the weather's own count.
  final double rainScale;

  /// Sector motes (dust, embers, spores), as a fraction.
  final double moteScale;

  /// Explosion sprites (model.blasts) drawn at once; the oldest beyond the
  /// cap are skipped by the painter (the model keeps them).
  final int blasts;

  /// Ricochet sparks around a deflect star (the star itself always shows).
  final bool sparks;

  /// Blur filters (ImageFilter.blur, MaskFilter.blur) on ambient effects.
  final bool blur;

  /// Forces the atmosphere's reduced quality: 2 fog slots of 8, tiles
  /// only, one sharp creature-shadow layer, one smoke puff per wreck.
  final bool fogReduced;

  // --- hatch-emergence (design §5): the carrier hatches' candy.
  /// The launched creatures' one-shot emergence frames (LITE: off, the
  /// flight sprites as before).
  final bool emergence;

  /// Lurkers drawn per held hatch (the claws, peeks and held doors).
  final int lurkers;

  /// The hatches' steam vents and telegraph pulse rings.
  final bool hatchVents;

  static const full = FrameBudget._(
    rainScale: 1,
    moteScale: 1,
    blasts: 28,
    sparks: true,
    blur: true,
    fogReduced: false,
    emergence: true,
    lurkers: 3,
    hatchVents: true,
  );
  static const lean = FrameBudget._(
    rainScale: .6,
    moteScale: .75,
    blasts: 20,
    sparks: true,
    blur: true,
    fogReduced: true,
    emergence: true,
    lurkers: 1,
    hatchVents: true,
  );
  static const lite = FrameBudget._(
    rainScale: .35,
    moteScale: .5,
    blasts: 14,
    sparks: false,
    blur: false,
    fogReduced: true,
    emergence: false,
    lurkers: 0,
    hatchVents: false,
  );

  static FrameBudget of(PerfTier t) => switch (t) {
    PerfTier.full => full,
    PerfTier.lean => lean,
    PerfTier.lite => lite,
  };
}

/// Picks the tier from measured frame intervals (design §3).
///
/// A frame is slow when its interval exceeds [slowFrame] (1.5 × a 60 Hz
/// frame). Over a window of [window] frames, more than [downRatio] slow
/// frames steps down one tier; fewer than [upRatio] for [upSeconds] steps
/// back up. A step down within [flapSeconds] of a step up makes the tier it
/// falls to the session's ceiling (no oscillation). Intervals longer than
/// [ignoreAbove] (a background tab, a debugger pause) and the first
/// [warmup] seconds are ignored.
class PerfGovernor {
  PerfGovernor({this.forced});

  /// A tier fixed by the player or a URL (`?perf=lite`): no adaptation.
  PerfTier? forced;

  static const slowFrame = 1.5 / 60;
  static const window = 120;
  static const downRatio = .1;
  static const upRatio = .02;
  static const upSeconds = 20.0;
  static const flapSeconds = 30.0;
  static const ignoreAbove = .25;
  static const warmup = 2.0;

  PerfTier _tier = PerfTier.full;
  PerfTier get tier => forced ?? _tier;
  FrameBudget get budget => FrameBudget.of(tier);

  /// The lowest tier index adaptation may climb back to.
  int _ceiling = 0;
  int get ceiling => _ceiling;

  final List<bool> _slow = [];
  int _slowCount = 0;
  double _clock = 0, _calm = 0, _lastUp = -1e9;

  /// Smoothed display interval (s), for frame-length effects such as the
  /// shots' motion smear. Starts at 60 Hz; held while nothing moves, so a
  /// paused frame stays exactly as it was.
  double interval = 1 / 60;

  /// Tier changes so far (tests, the perf overlay).
  int changes = 0;

  /// Slow frames in the current window, as a fraction.
  double get slowRatio => _slow.isEmpty ? 0 : _slowCount / _slow.length;

  /// Feeds one frame's wall-clock interval [dt] (seconds); [moving] is
  /// false while the run is paused or not in play.
  void frame(double dt, {bool moving = true}) {
    if (dt <= 0 || dt > ignoreAbove) return;
    _clock += dt;
    if (moving) interval += (dt.clamp(1 / 144, 1 / 20) - interval) * .1;
    if (_clock < warmup) return;
    final slow = dt > slowFrame;
    _slow.add(slow);
    if (slow) _slowCount++;
    if (_slow.length > window) {
      if (_slow.removeAt(0)) _slowCount--;
    }
    if (_slow.length < window) return;
    final ratio = slowRatio;
    if (ratio > downRatio && _tier != PerfTier.lite) {
      _tier = PerfTier.values[_tier.index + 1];
      changes++;
      // Fell back right after climbing: this device can't hold the richer
      // tier, so this one is the session's ceiling.
      if (_clock - _lastUp < flapSeconds) {
        _ceiling = math.max(_ceiling, _tier.index);
      }
      _calm = 0;
      _slow.clear();
      _slowCount = 0;
      return;
    }
    _calm = ratio < upRatio ? _calm + dt : 0;
    if (_calm >= upSeconds && _tier.index > _ceiling) {
      _tier = PerfTier.values[_tier.index - 1];
      changes++;
      _lastUp = _clock;
      _calm = 0;
      _slow.clear();
      _slowCount = 0;
    }
  }
}

/// Frame pacing (design §5.1): a frame interval within [tolerance] of a
/// whole number of 60 Hz steps is snapped to it, so a vsync-locked display
/// whose timestamps jitter (rounded rAF times, 59.94 Hz panels) steps the
/// fixed 1/60 s simulation exactly once per frame instead of 0, 2, 1, ...
/// [tolerance] is in seconds. Other intervals (90 or 120 Hz, a hitch) pass
/// through unchanged.
double snapFrameDelta(double dt, {double tolerance = .002}) {
  const step = 1 / 60;
  final k = (dt / step).round();
  if (k >= 1 && k <= 4 && (dt - k * step).abs() <= tolerance) return k * step;
  return dt;
}

/// The frame-cost harness's hook: a canvas that implements it is told which
/// layer the scene is drawing (test/support/counting_canvas.dart). In the
/// game the check is one type test per marker.
abstract interface class LayerSink {
  void layer(String name);
}
