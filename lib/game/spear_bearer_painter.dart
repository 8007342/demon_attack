// --- spear-bearers (openspec/changes/spear-bearers design §4-§5): the
// bearer's gear over its body, its thrown spears and the bucklers knocked
// out of the sky. Presentation only: it reads the model and never writes it.
//
// Budget (phone-performance): at most three drawImageRect a bearer (the
// buckler, the spear, the wind-up glint), one a spear in flight and one a
// falling buckler. All of it is gameplay readout (the throw's telegraph,
// the shield's state), so no perf tier sheds it; reduced motion keeps the
// glint steady instead of pulsing.
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/painting.dart';

import 'model.dart';
import 'spear_bearer_atlas.dart';
import 'insignia_rank.dart';

abstract final class SpearBearerPainter {
  /// assets/images/spear-bearers.png (null in tests without art: nothing
  /// is drawn).
  static ui.Image? image;

  // --- spear-bearers ⟂ insignia-ranks (insignia-ranks design §4, round 8):
  // the mark is the insignia ladder's, not the behaviour rank. A bearer
  // keeps the hunter's behaviour (CombatAtlas.rankOf: hunter) but wears the
  // crownlet, the guard's mark, with no fang. InsigniaRanks.markOf is the
  // one source of truth; this only reads it.
  /// The mark above a bearer's head: the crownlet.
  static RankMark markOf(Demon d) => InsigniaRanks.markOf(d);

  /// Gear shifts this far (units) toward the bank, so it follows the 3/4
  /// banked frames.
  static const bankShift = 3.0;

  /// Arena units per art px (creatures draw their 64 px cell at 40 units).
  static const unitsPerPx = 40 / SpearBearerAtlas.cell;

  static final Paint _paint = Paint()
    ..isAntiAlias = false
    ..filterQuality = FilterQuality.none;

  static Paint _alpha(double a) =>
      _paint..color = Color.fromRGBO(255, 255, 255, a.clamp(0.0, 1.0));

  /// The spear-layer frame [d] shows (null: empty-handed, nothing).
  static int? spearFrame(Demon d, double clock) {
    final kit = d.spear;
    if (kit == null) return null;
    if (!kit.armed) {
      return clock - kit.releasedAt < SpearTuning.releasePose
          ? SpearBearerAtlas.spearRelease
          : null;
    }
    if (kit.windingUp) return SpearBearerAtlas.spearWind;
    if (d.dive > 0 || d.telegraph > 0) return SpearBearerAtlas.spearLevel;
    return SpearBearerAtlas.spearIdle;
  }

  /// The buckler-layer frame [d] shows (null: knocked away).
  static int? bucklerFrame(Demon d, double clock) {
    final kit = d.spear;
    if (kit == null || !kit.hasBuckler) return null;
    if (d.dive <= 0 || d.stunned) return SpearBearerAtlas.bucklerCarried;
    return clock - kit.hitAt < SpearTuning.hitFlash
        ? SpearBearerAtlas.bucklerHit
        : SpearBearerAtlas.bucklerRaised;
  }

  /// The gear over [d]'s body, in the body's transform (call it where the
  /// elite armour is drawn): [size] is the body's drawn size (40, or 44
  /// angry), [lift] the frame's whole-pixel body lift.
  static void gear(
    Canvas c,
    Demon d,
    Offset pos,
    double size,
    int lift,
    double clock, {
    double alpha = 1,
    bool reduced = false,
  }) {
    final img = image;
    if (img == null || d.spear == null || alpha <= 0) return;
    final k = size / SpearBearerAtlas.cell;
    final at = pos + Offset(d.bank * bankShift, lift * k);
    final dst = Rect.fromCenter(center: at, width: size, height: size);
    final b = bucklerFrame(d, clock);
    if (b != null) {
      c.drawImageRect(img, SpearBearerAtlas.buckler(b), dst, _alpha(alpha));
    }
    final s = spearFrame(d, clock);
    if (s != null) {
      c.drawImageRect(img, SpearBearerAtlas.spear(s), dst, _alpha(alpha));
    }
    final kit = d.spear!;
    if (kit.windingUp) {
      // The glint on the drawn-back head: it grows through the wind-up
      // and pulses (steady with reduced motion).
      final p = kit.windupProgress;
      final pulse = reduced ? 1.0 : .75 + .25 * math.sin(clock * 30);
      final g = SpearBearerAtlas.glint;
      final w = g.width * k * (.7 + .5 * p) * pulse;
      c.drawImageRect(
        img,
        g,
        Rect.fromCenter(
          center: at + SpearBearerAtlas.windTip * k,
          width: w,
          height: w,
        ),
        _alpha(alpha * (.6 + .4 * p)),
      );
    }
  }

  /// The lean (degrees, + tip right) a spear shows: along its drawn
  /// velocity, the wind's drift included.
  static double lean(Shot s, double hostileRate) {
    final vx = s.vx * hostileRate + s.windVx;
    final vy = s.vy + s.windVy;
    return math.atan2(vx, vy) * 180 / math.pi;
  }

  /// Every thrown spear, its tip on the shot's point (the hit point).
  static void spears(Canvas c, ArcadeModel m, double lead) {
    final img = image;
    if (img == null) return;
    final rate = m.policy.hostileRate;
    for (final s in m.shots) {
      if (s.kind != ShotKind.spear) continue;
      final x = (s.x + (s.vx * rate + s.windVx) * lead).roundToDouble();
      final y = (s.y + (s.vy + s.windVy) * lead).roundToDouble();
      const k = unitsPerPx;
      c.drawImageRect(
        img,
        SpearBearerAtlas.projectile(SpearBearerAtlas.leanFrame(lean(s, rate))),
        Rect.fromLTWH(
          x - SpearBearerAtlas.projW / 2 * k,
          y - SpearBearerAtlas.projTipY * k,
          SpearBearerAtlas.projW * k,
          SpearBearerAtlas.projH * k,
        ),
        _alpha(1),
      );
    }
  }

  /// The knocked-away bucklers, tumbling and fading.
  static void fallen(Canvas c, ArcadeModel m) {
    final img = image;
    if (img == null) return;
    for (final b in m.spearRun.fallen) {
      final a = 1 - (b.age / SpearTuning.fallLife).clamp(0.0, 1.0);
      final size = 40 * b.scale;
      c.save();
      c.translate(b.x.roundToDouble(), b.y.roundToDouble());
      c.rotate(b.rotation);
      c.drawImageRect(
        img,
        SpearBearerAtlas.buckler(SpearBearerAtlas.bucklerProp),
        Rect.fromCenter(center: Offset.zero, width: size, height: size),
        _alpha(a),
      );
      c.restore();
    }
  }
}
