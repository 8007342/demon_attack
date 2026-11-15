// The bounded skill reaction of demon-intelligence (openspec/changes/
// demon-intelligence design §7): accuracy, clear tempo and near-miss
// dodges, never score, power-ups or time survived. Deterministic: it is
// derived from model counters only.
import 'dart:math' as math;
import 'dart:typed_data';

class SkillMeter {
  SkillMeter({this.cap = .8});

  /// Per-difficulty cap (Easy 0.5, Normal 0.8, Hard 1.0).
  double cap;

  /// Starting level and the level a restored checkpoint resets to.
  static const initial = .3;

  /// Window (s) of the accuracy and dodge rates; smoothing time constant.
  static const window = 20, tau = 20.0;

  /// Lost life: the drop and the seconds the level stays frozen after it.
  static const lifeDrop = .35, freeze = 10.0;

  double level = initial;

  /// The latest target ŝ and its inputs (instrumentation).
  double target = initial, accuracy = 0, tempo = 1, dodgesPerMinute = 0;
  double _tick = 0, _frozen = 0;
  int _fired = 0, _hit = 0, _dodges = 0, _slot = 0, _filled = 0;
  final Int32List _firedRing = Int32List(window),
      _hitRing = Int32List(window),
      _dodgeRing = Int32List(window);

  /// Linear normalisation of [v] between [lo] and [hi], clamped to [0, 1].
  static double n(double v, double lo, double hi) =>
      ((v - lo) / (hi - lo)).clamp(0.0, 1.0);

  /// ŝ = 0.4 n(a; .25, .65) + 0.4 n(p; .8, 1.6) + 0.2 n(d; 2, 10).
  static double targetOf(double a, double p, double d) =>
      (.4 * n(a, .25, .65) + .4 * n(p, .8, 1.6) + .2 * n(d, 2, 10)).clamp(
        0.0,
        1.0,
      );

  void reset({double to = initial}) {
    level = math.min(to, cap);
    target = level;
    accuracy = dodgesPerMinute = 0;
    tempo = 1;
    _tick = _frozen = 0;
    _fired = _hit = _dodges = _slot = _filled = 0;
    _firedRing.fillRange(0, window, 0);
    _hitRing.fillRange(0, window, 0);
    _dodgeRing.fillRange(0, window, 0);
  }

  /// Feeds one step of combat with the model's running totals: player
  /// shots fired and hit, and hostile near misses. Updates once a second.
  void observe(
    double dt, {
    required int shotsFired,
    required int shotsHit,
    required int nearMisses,
  }) {
    _frozen = math.max(0, _frozen - dt);
    _tick += dt;
    if (_tick < 1) return;
    _tick -= 1;
    _firedRing[_slot] = shotsFired - _fired;
    _hitRing[_slot] = shotsHit - _hit;
    _dodgeRing[_slot] = nearMisses - _dodges;
    _fired = shotsFired;
    _hit = shotsHit;
    _dodges = nearMisses;
    _slot = (_slot + 1) % window;
    _filled = math.min(window, _filled + 1);
    var f = 0, h = 0, d = 0;
    for (var i = 0; i < window; i++) {
      f += _firedRing[i];
      h += _hitRing[i];
      d += _dodgeRing[i];
    }
    accuracy = f == 0 ? 0 : h / f;
    dodgesPerMinute = d * 60 / _filled;
    if (_frozen > 0) return;
    target = targetOf(accuracy, tempo, dodgesPerMinute);
    level = (level + (target - level) * (1 - math.exp(-1 / tau))).clamp(
      0.0,
      cap,
    );
  }

  /// Rebases the counters (the model's totals were reset or restored).
  void rebase({int shotsFired = 0, int shotsHit = 0, int nearMisses = 0}) {
    _fired = shotsFired;
    _hit = shotsHit;
    _dodges = nearMisses;
  }

  /// The last cohort's T_expected / T_actual (continuous-swarm).
  void cohortCleared({required double expected, required double actual}) {
    tempo = expected / math.max(actual, .1);
  }

  void lifeLost() {
    level = math.max(0, level - lifeDrop);
    _frozen = freeze;
  }

  bool get frozen => _frozen > 0;
}
