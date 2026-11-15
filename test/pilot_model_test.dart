// demon-intelligence task 1.2: the player forecast (design §2).
import 'dart:math' as math;

import 'package:demon_attack/game/model.dart';
import 'package:flutter_test/flutter_test.dart';

const dt = 1 / 60;

PilotModel fly(double Function(double t) xAt, double seconds) {
  final p = PilotModel()..reset(xAt(0));
  for (var t = 0.0; t < seconds; t += dt) {
    final v = (xAt(t + dt) - xAt(t)) / dt;
    p.observe(xAt(t), v, dt);
  }
  return p;
}

void main() {
  test('a constant velocity is predicted within 2 u at τ 0.3', () {
    for (final v in [-160.0, -60.0, 0.0, 45.0, 120.0]) {
      double xAt(double t) => 180 + v * (t - 2);
      final p = fly(xAt, 2);
      expect(p.mean(.3), closeTo(xAt(2.3), 2), reason: 'v $v');
    }
  });

  test('a player weaving around a lane is predicted toward the lane', () {
    // Weaves ±60 u around x = 230 with a 1.6 s period.
    double xAt(double t) => 230 + 60 * math.sin(t * 2 * math.pi / 1.6);
    for (final end in [6.2, 6.6, 7.0, 7.4]) {
      final p = fly(xAt, end);
      final now = (p.x - 230).abs();
      final ahead = (p.mean(1.5) - 230).abs();
      expect(ahead, lessThan(now + 1e-9), reason: 'at $end');
      expect((p.laneMean - 230).abs(), lessThan(20));
    }
  });

  test('σ grows with |v| and τ', () {
    final slow = fly((t) => 120 + 20 * t, 2);
    final fast = fly((t) => 60 + 140 * t, 2);
    expect(fast.spread(.5), greaterThan(slow.spread(.5)));
    expect(slow.spread(1), greaterThan(slow.spread(.2)));
    expect(slow.spread(0), greaterThanOrEqualTo(8));
  });

  test('pHit peaks at the forecast and is a probability', () {
    final p = fly((t) => 100 + 50 * t, 1.5);
    final mu = p.mean(.4);
    final at = p.pHit(mu, .4, 10);
    expect(at, inInclusiveRange(0, 1));
    expect(at, greaterThan(p.pHit(mu + 30, .4, 10)));
    expect(at, greaterThan(p.pHit(mu - 30, .4, 10)));
    expect(p.aim(.4), mu);
    expect(PilotModel.normalCdf(0), closeTo(.5, 1e-7));
    expect(PilotModel.normalCdf(1.96), closeTo(.975, 1e-4));
  });

  test('deterministic, and the ring buffer is reused', () {
    double xAt(double t) => 180 + 90 * math.sin(t * 1.3) + 20 * math.cos(t * 5);
    final a = fly(xAt, 9), b = fly(xAt, 9);
    for (final tau in [0.0, .2, .7, 1.5]) {
      expect(a.mean(tau), b.mean(tau));
      expect(a.spread(tau), b.spread(tau));
    }
    final buffer = a.debugBuffer;
    for (var i = 0; i < 1000; i++) {
      a.observe(180, 0, dt);
      a.mean(.3);
      a.pHit(180, .3, 10);
    }
    expect(identical(a.debugBuffer, buffer), isTrue);
    expect(a.samples, PilotModel.capacity);
    expect(buffer.length, PilotModel.capacity);
  });

  test('the model owns one, reset on a new sector and a lost life', () {
    final m = ArcadeModel()..startAt(sector: 2);
    m.mode = RunMode.playing;
    m.invulnerable = 0;
    for (var i = 0; i < 120; i++) {
      m.moveTo(i.isEven ? 60 : 300);
      m.update(dt);
    }
    expect(m.pilot.samples, greaterThan(5));
    m.hitPlayer();
    expect(m.pilot.samples, 0);
  });
}
