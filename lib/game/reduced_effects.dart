// --- reduced-effects (openspec/changes/reduced-effects): the player's
// "Reduced effects" setting: reduced flashing and calmer motion.
//
// Pure Dart (no dart:ui, no Flutter): the scene, the painters and the
// menu read it; the model never does. It is rendering only: the
// simulation's own `reducedMotion` (the shorter cinematic plans) follows
// the system setting alone, so the setting never changes the rules, the
// timing or the deterministic model (design §2).
import 'perf/frame_budget.dart';

/// Auto follows the system's reduced-motion setting; On and Off force it.
enum ReducedEffectsMode {
  auto('AUTO'),
  on('ON'),
  off('OFF');

  const ReducedEffectsMode(this.label);
  final String label;

  /// The menu cycles Auto -> On -> Off -> Auto.
  ReducedEffectsMode get next => values[(index + 1) % values.length];

  /// A stored value; anything unknown is Auto.
  static ReducedEffectsMode parse(String? s) => values.firstWhere(
    (m) => m.name == s,
    orElse: () => ReducedEffectsMode.auto,
  );
}

/// The setting (one per page view) and what it implies.
abstract final class ReducedEffects {
  /// Where the choice is remembered (localStorage on the web).
  static const storageKey = 'demonAttack.reducedEffects';

  /// The player's choice. Tests reset it to Auto.
  static ReducedEffectsMode mode = ReducedEffectsMode.auto;

  /// Told after [set] changes the mode (the app's MediaQuery scope).
  static final listeners = <void Function()>{};

  static void set(ReducedEffectsMode next) {
    if (next == mode) return;
    mode = next;
    for (final l in List.of(listeners)) {
      l();
    }
  }

  /// The calm look, given the system's reduced motion ([system]). Applying
  /// it twice changes nothing (`calm(calm(x)) == calm(x)`), so a painter
  /// handed an already-resolved flag may resolve it again safely.
  static bool calm(bool system) => switch (mode) {
    ReducedEffectsMode.on => true,
    ReducedEffectsMode.off => false,
    ReducedEffectsMode.auto => system,
  };

  /// The frame budget the painters get: the tier's own, or, with the calm
  /// look, the tier's capped at LITE for the eye candy (design §3).
  static FrameBudget budget(PerfTier tier, {required bool calm}) =>
      calm ? _calmed[tier.index] : FrameBudget.of(tier);

  static final _calmed = [
    for (final t in PerfTier.values) FrameBudget.of(t).calmed(),
  ];

  /// The menu row: `REDUCED EFFECTS: AUTO`, with `(SYSTEM)` when Auto is on
  /// because the system asks, and `(LOW-POWER)` when the frame budget has
  /// adapted down to LITE by itself ([lowPower]).
  static String menuLabel({required bool system, required bool lowPower}) {
    final notes = [
      if (mode == ReducedEffectsMode.auto && system) 'SYSTEM',
      if (lowPower && mode != ReducedEffectsMode.on) 'LOW-POWER',
    ];
    final tail = notes.isEmpty ? '' : ' (${notes.join(', ')})';
    return 'REDUCED EFFECTS: ${mode.label}$tail';
  }

  /// What the row says to a screen reader.
  static String spoken({required bool system, required bool lowPower}) {
    final now = switch (mode) {
      ReducedEffectsMode.auto =>
        'automatic, ${system ? 'on' : 'off'} from the system setting',
      ReducedEffectsMode.on => 'on',
      ReducedEffectsMode.off => 'off',
    };
    final low = lowPower ? '; this device is running at low power' : '';
    return 'Reduced flashing and motion: $now$low';
  }
}
