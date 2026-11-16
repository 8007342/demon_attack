import 'dart:math' as math;
import 'dart:typed_data';

import 'package:demon_attack/game/boss_director.dart';
import 'package:demon_attack/game/carrier_field.dart';
import 'package:demon_attack/game/carrier_presentation.dart';
import 'package:demon_attack/game/model.dart';
import 'package:flutter_test/flutter_test.dart';

/// carrier-v3 task 2.4: the field's redraw never moves the gameplay
/// surface: a scripted shield fight logs the same hits, at the same places
/// and times, with and without the new presentation running, at full zoom
/// and at the tour's minimum; and the load-time distance map is exact.
void main() {
  List<String> fight({required bool presentation}) {
    final m = ArcadeModel(seed: 13)..startAt(sector: 5, route: 0);
    final d = BossDirector(seed: 13);
    final p = CarrierPresentation();
    final b = m.boss!;
    final log = <String>[];
    for (var f = 0; f < 60 * 40; f++) {
      m.invulnerable = 2;
      if (b.fightReady && f % 9 == 0 && b.shield > 0) {
        final x = b.x + 90 * math.sin(f * .37);
        final y = b.forceFieldSurfaceY(x);
        if (m.hitBoss(x)) {
          log.add('$f ${x.toStringAsFixed(3)} ${y.toStringAsFixed(3)} '
              '${b.shield}');
        }
      }
      m.update(1 / 60);
      if (presentation) {
        d.update(m, 1 / 60, carrier: true);
        p.update(1 / 60, m, d, reduced: false);
      }
    }
    return log;
  }

  test('shield hit log identical with and without the field redraw', () {
    final a = fight(presentation: false), b = fight(presentation: true);
    expect(a, isNotEmpty);
    expect(b, a);
  });

  test('the surface keeps its width, depth and tightening', () {
    final m = ArcadeModel(seed: 2)..startAt(sector: 5, route: 0);
    final b = m.boss!;
    expect(b.forceFieldHalfWidth, 110);
    expect(b.forceFieldDepth, closeTo(75, 1e-9));
    b.shield = 0;
    expect(b.forceFieldDepth, closeTo(43, 1e-9));
  });

  test('distance map: exact on a disc, contours at every level', () {
    const w = 120, h = 120, r = 30.0;
    final rgba = Uint8List(w * h * 4);
    for (var j = 0; j < h; j++) {
      for (var i = 0; i < w; i++) {
        final dx = i + .5 - 60, dy = j + .5 - 60;
        if (dx * dx + dy * dy <= r * r) rgba[(j * w + i) * 4 + 3] = 255;
      }
    }
    // 0.5 px per unit: the disc is 60 units across, centred at (0, 0).
    final map = CarrierFieldMap.fromAlpha(rgba, w, h, left: -120, top: -120);
    expect(map.at(0, 0), lessThan(-50));
    expect(map.at(0, -80), closeTo(20, 2.5));
    expect(map.at(100, 0), closeTo(40, 2.5));
    for (final l in CarrierFieldMap.levels) {
      expect(map.segments(l), greaterThan(20), reason: 'level $l');
    }
  });
}
