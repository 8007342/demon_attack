// The player forecast of demon-intelligence (openspec/changes/
// demon-intelligence design §2): the distilled "latent prediction" of the
// JEPA idea, written by hand. It forecasts the ship's x at t + τ as a
// Gaussian from a 3 s history sampled at 10 Hz. Pure Dart, deterministic,
// O(1) per query and allocation-free after construction.
import 'dart:math' as math;
import 'dart:typed_data';

class PilotModel {
  PilotModel() {
    reset(180);
  }

  /// History rate (Hz), length (samples) and the windows (samples) of the
  /// jitter (1 s moving mean) and the velocity persistence (1 s).
  static const rate = 10.0, capacity = 30, window = 10;

  /// Time constants (s): lane-mean EWMA, velocity decay, mean reversion.
  static const laneTau = 6.0, velocityTau = .5, revertTau = 1.2;

  /// Arena bounds of the ship centre.
  static const minX = 18.0, maxX = 342.0;

  final Float64List _x = Float64List(capacity), _v = Float64List(capacity);
  int _count = 0, _head = 0;
  double _clock = 0;

  /// Latest ship position and velocity, the lane mean m, the jitter j and
  /// the velocity persistence p (1: the last second flew one steady
  /// velocity, 0: it reversed or wandered).
  double x = 180, v = 0, laneMean = 180, jitter = 0, persistence = 1;

  /// Samples held (≤ [capacity]).
  int get samples => _count;

  /// The ring buffers (exposed so a test can check they are reused).
  Float64List get debugBuffer => _x;

  /// Forgets the history: a life loss or a new sector.
  void reset(double shipX) {
    _count = 0;
    _head = 0;
    _clock = 0;
    x = laneMean = shipX;
    v = jitter = 0;
    persistence = 1;
  }

  /// Feeds one simulation step of the ship (call while combat runs).
  void observe(double shipX, double shipVx, double dt) {
    x = shipX;
    v = shipVx;
    if (_count == 0) {
      _push(shipX, shipVx);
      return;
    }
    _clock += dt;
    while (_clock >= 1 / rate - 1e-9) {
      _clock -= 1 / rate;
      _push(shipX, shipVx);
    }
  }

  void _push(double sx, double sv) {
    _x[_head] = sx;
    _v[_head] = sv;
    _head = (_head + 1) % capacity;
    if (_count < capacity) _count++;
    laneMean = _count == 1
        ? sx
        : laneMean + (sx - laneMean) * (1 - math.exp(-1 / (rate * laneTau)));
    // Jitter about the 1 s moving mean; persistence of the 1 s velocity.
    final n = math.min(_count, window);
    var mx = 0.0, mv = 0.0;
    for (var i = 1; i <= n; i++) {
      final k = (_head - i + capacity) % capacity;
      mx += _x[k];
      mv += _v[k];
    }
    mx /= n;
    mv /= n;
    var sxx = 0.0, svv = 0.0;
    for (var i = 1; i <= n; i++) {
      final k = (_head - i + capacity) % capacity;
      sxx += (_x[k] - mx) * (_x[k] - mx);
      svv += (_v[k] - mv) * (_v[k] - mv);
    }
    jitter = math.sqrt(sxx / n);
    persistence = (1 - math.sqrt(svv / n) / (mv.abs() + 30)).clamp(0.0, 1.0);
  }

  /// μ(τ): constant velocity with decay plus mean reversion to the lane
  /// (design §2). The decay and the reversion are scaled by (1 − p): a
  /// steady glide is extrapolated as flown, a weaving player is pulled
  /// toward the lane it holds (deviation, recorded in design.md).
  double mean(double tau) {
    if (tau <= 0) return x;
    final q = 1 - persistence;
    final glide = v * tau * math.exp(-tau * q / velocityTau);
    final revert = (laneMean - x) * (1 - math.exp(-tau / revertTau)) * q;
    return (x + glide + revert).clamp(minX, maxX);
  }

  /// σ(τ) = 8 + 0.5 · |v| · τ + j.
  double spread(double tau) => 8 + .5 * v.abs() * math.max(0, tau) + jitter;

  /// P(the ship's centre is within [halfWidth] of [at] at τ).
  double pHit(double at, double tau, double halfWidth) {
    final mu = mean(tau), s = spread(tau);
    return normalCdf((at + halfWidth - mu) / s) -
        normalCdf((at - halfWidth - mu) / s);
  }

  /// The aim maximising [pHit]: μ(τ) for a Gaussian.
  double aim(double tau) => mean(tau);

  /// Φ(z), Abramowitz–Stegun 7.1.26 (|error| < 1.5e-7).
  static double normalCdf(double z) {
    final t = 1 / (1 + .3275911 * z.abs() / math.sqrt2);
    final y =
        1 -
        (((((1.061405429 * t - 1.453152027) * t) + 1.421413741) * t -
                        .284496736) *
                    t +
                .254829592) *
            t *
            math.exp(-z * z / 2);
    return z >= 0 ? (1 + y) / 2 : (1 - y) / 2;
  }
}
