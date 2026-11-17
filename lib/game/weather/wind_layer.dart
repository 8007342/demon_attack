// --- crosswind: the wind's look (openspec/changes/crosswind design §2-§3).
//
// The model owns the wind (model_wind.dart); this layer only shows it, and
// always shows it early: it draws the field's FORECAST (the wind
// [WindField.lead] seconds ahead), so the clouds, the wisps and the
// windsock turn before a shot bends.
//
// - Clouds: soft billows high over the backdrop that stream with the wind
//   (the operator: "we'll use clouds as effect").
// - Wisps: long, thin cloud streaks driven across the sky, faster and more
//   of them in a gust; under the play, like the rain.
// - The windsock: a small pole and a striped sock at the arena's top edge,
//   over the play (it is the one thing the player reads), that swings to
//   the coming wind and pulses amber while a call is on.
//
// Stateless fields like the rain's: each wisp and billow is a pure
// function of its index and the integrated wind ([run]), so a swing
// reverses them smoothly and nothing is allocated per frame. Wisps are
// one drawRawPoints batch; billows are a fixed handful of ovals.
library;

import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui';

import '../model.dart';
import 'rain_layer.dart' show RainLayer;

class WindLayer {
  /// The heaviest wind's wisps and billows (phone and web).
  static const wispMax = 56, billowMax = 7;

  /// Wisp drift (u/s) at full strength, far and near.
  static const wispSpeed = 150.0;

  /// The windsock's place: the arena's top-left corner, clear of the
  /// swarm's rows and of the HUD's score (top right).
  static const sockAt = Offset(16, 30);

  /// Seconds the drawn wind takes to swing all the way (it already leads
  /// the model by [WindField.lead]; this only smooths a level's start).
  static const slew = 1.5;

  /// --- phone-performance: the tier's share of the wisps and billows.
  double budget = 1;

  /// The drawn wind (forecast, smoothed): lateral -1..1, its share (0-1),
  /// the integrated drift that moves the field, and a clock.
  double lateral = 0, amount = 0, run = 0, time = 0;

  /// A call is on (a big swing or a gust is coming): 0-1, fading.
  double tell = 0;
  bool reduced = false;

  /// Counts drawn last frame (perf tests).
  int lastWisps = 0, lastBillows = 0;

  /// Forces a wind on the drawing (review harnesses); null: the model's.
  ({double lateral, double amount})? override;

  /// Reads the model (never writes it).
  void advance(double dt, ArcadeModel model, {required bool reduced}) {
    this.reduced = reduced;
    final f = model.windField;
    final live =
        model.mode != RunMode.title &&
        model.mode != RunMode.victory &&
        model.mode != RunMode.completed;
    final o = override;
    double want = 0, share = 0;
    if (o != null) {
      want = o.lateral;
      share = o.amount;
    } else if (f != null && live) {
      final s = f.forecast(model.levelClock);
      want = s.amount > 0 ? s.lateral / s.amount : 0;
      share = s.amount;
      for (final shift in f.tellsBetween(
        model.levelClock - WindField.lead,
        model.levelClock,
      )) {
        if (shift.gust || (shift.lateral - want).abs() > .3) tell = 1;
      }
    }
    advanceTo(dt, want, share);
  }

  /// Moves the drawn wind toward [want] at [share] (also the review
  /// harness's entry point).
  void advanceTo(double dt, double want, double share) {
    time += dt;
    final k = math.min(1.0, dt / (slew / 3));
    lateral += (want - lateral) * k;
    amount += (share - amount) * k;
    tell = math.max(0, tell - dt / WindField.lead);
    final speed = reduced ? .35 : 1.0;
    run += lateral * amount * wispSpeed * speed * dt;
  }

  void reset() {
    lateral = amount = run = tell = 0;
  }

  // --- painting ------------------------------------------------------------

  final _wisps = Float32List(wispMax * 4);
  static final _line = Paint()
    ..isAntiAlias = false
    ..strokeWidth = 1
    ..strokeCap = StrokeCap.butt;
  final _soft = Paint();

  /// Over the backdrop (and the rain), under the play: billows, then
  /// wisps. [cloud]: the sector's cloud colour. [blur]: the tier allows
  /// blurred billows.
  void paintSky(
    Canvas c, {
    double headroom = 0,
    Color cloud = const Color(0xFFB4BED2),
    bool blur = true,
  }) {
    lastWisps = lastBillows = 0;
    final k = amount;
    if (k < .02) return;
    final top = -headroom;
    final strength = lateral.abs() * k;
    // Billows: soft clouds high in the sky, streaming with the wind.
    final billows = (billowMax * budget).round().clamp(0, billowMax);
    // One soft radial puff (unit radius), scaled into each oval: no blur
    // filter, so every tier draws the same soft edge for the cost of a
    // gradient fill. [blur] only adds the softer centre on FULL and LEAN.
    final a = (.08 + .1 * strength) * k;
    _soft.shader = Gradient.radial(
      Offset.zero,
      1,
      [
        cloud.withValues(alpha: a),
        cloud.withValues(alpha: a * (blur ? .55 : .4)),
        cloud.withValues(alpha: 0),
      ],
      const [0, .55, 1],
    );
    for (var i = 0; i < billows; i++) {
      final depth = .4 + .6 * RainLayer.hash(i * 19 + 4);
      final y = top + 18 + (150 + headroom * .5) * RainLayer.hash(i * 7 + 2);
      final x = (RainLayer.hash(i * 11 + 9) * 520 + run * depth) % 520 - 80;
      final w = 70 + 60 * RainLayer.hash(i * 3 + 1);
      // Stretched along the wind: the stronger, the longer and flatter.
      final stretch = 1 + .5 * strength;
      for (var p = 0; p < 3; p++) {
        final dx = (p - 1) * w * .32 * stretch;
        final r = w * (p == 1 ? .34 : .24);
        c
          ..save()
          ..translate(x + dx, y + (p == 1 ? -3 : 2))
          ..scale(r * stretch, r * (.55 - .15 * strength))
          ..drawCircle(Offset.zero, 1, _soft)
          ..restore();
      }
      lastBillows++;
    }
    _soft.shader = null;
    // Wisps: thin streaks driven across, more and brighter in a gust.
    final count = (reduced ? .5 : 1.0) * budget * (.35 + .65 * strength);
    final n = math.min(wispMax, (wispMax * count).round());
    final span = 520 + headroom;
    for (var i = 0; i < n; i++) {
      final depth = .45 + .55 * RainLayer.hash(i * 13 + 1);
      final y = top + span * RainLayer.hash(i * 7 + 3);
      final len = (14 + 30 * RainLayer.hash(i * 5 + 2)) * (.4 + strength);
      final x =
          (RainLayer.hash(i * 11 + 7) * 440 + run * depth * 1.6) % 440 - 40;
      final dir = lateral < 0 ? -1.0 : 1.0;
      _wisps[i * 4] = x.roundToDouble();
      _wisps[i * 4 + 1] = y.roundToDouble();
      _wisps[i * 4 + 2] = (x - dir * len).roundToDouble();
      _wisps[i * 4 + 3] = y.roundToDouble();
    }
    lastWisps = n;
    if (n > 0) {
      _line.color = cloud.withValues(
        alpha: ((.16 + .22 * strength + .12 * tell) * k).clamp(0.0, 1.0),
      );
      c.drawRawPoints(
        PointMode.lines,
        Float32List.sublistView(_wisps, 0, n * 4),
        _line,
      );
    }
  }

  static const _stripeA = Color(0xFFFF8A4C), _stripeB = Color(0xFFF4EEE4);
  static const _pole = Color(0xFF8C96A8), _amber = Color(0xFFFFC14D);
  final _fill = Paint()..isAntiAlias = false;

  /// The windsock, over the play: four tapering stripes that lift and
  /// point down-wind as the coming wind strengthens, with a flutter; an
  /// amber ring pulses while a call is on.
  void paintSock(Canvas c) {
    final k = amount;
    if (k < .02) return;
    // Drawn at 1.5 x about its foot: big enough to read on a phone.
    c
      ..save()
      ..translate(sockAt.dx, sockAt.dy)
      ..scale(1.5)
      ..translate(-sockAt.dx, -sockAt.dy);
    final base = sockAt;
    _fill.color = _pole.withValues(alpha: .9 * math.min(1, k * 3));
    c.drawRect(Rect.fromLTWH(base.dx - 1, base.dy - 2, 2, 16), _fill);
    final strength = (lateral.abs() * k).clamp(0.0, 1.0);
    final dir = lateral < 0 ? -1.0 : 1.0;
    // Droops toward the pole when calm, stands out level at full wind.
    final droop = (1 - strength) * 1.15;
    final flutter = reduced ? 0.0 : math.sin(time * (6 + 8 * strength)) * .08;
    final angle = droop + flutter;
    var x = base.dx, y = base.dy;
    for (var s = 0; s < 4; s++) {
      final w = 4.0 - s * .6, h = 5.0 - s * .7;
      final dx = math.cos(angle) * 4.2 * dir, dy = math.sin(angle) * 4.2;
      _fill.color = (s.isEven ? _stripeA : _stripeB).withValues(
        alpha: math.min(1, k * 3),
      );
      c.drawRect(
        Rect.fromCenter(
          center: Offset(
            (x + dx / 2).roundToDouble(),
            (y + dy / 2).roundToDouble(),
          ),
          width: w,
          height: h,
        ),
        _fill,
      );
      x += dx;
      y += dy;
    }
    if (tell > 0) {
      final pulse = reduced ? .6 : .5 + .5 * math.sin(time * 12);
      c.drawCircle(
        base + Offset(8 * dir, 3),
        11 + 3 * (1 - tell),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5
          ..color = _amber.withValues(alpha: .7 * tell * pulse),
      );
    }
    c.restore();
  }
}
