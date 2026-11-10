import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:demon_attack/game/boss_atlas.dart';
import 'package:demon_attack/game/model.dart';
import 'package:flutter_test/flutter_test.dart';

Future<ui.Image> _decode(String file) async {
  final codec = await ui.instantiateImageCodec(await File(file).readAsBytes());
  final frame = await codec.getNextFrame();
  codec.dispose();
  return frame.image;
}

/// RGBA pixels of one atlas with sprite-relative lookups in arena units.
class _Atlas {
  _Atlas(this.width, this.data);
  final int width;
  final Uint8List data;

  int alpha(int x, int y) => data[(y * width + x) * 4 + 3];
  int red(int x, int y) => data[(y * width + x) * 4];

  /// Whether sprite [s] is opaque at arena point (ux, uy) from its anchor.
  bool opaqueAt(BossSprite s, double ux, double uy) {
    final px = ((ux - s.dx) * 2).floor(), py = ((uy - s.dy) * 2).floor();
    if (px < 0 || py < 0 || px >= s.w || py >= s.h) return false;
    return alpha(s.x + px, s.y + py) > 0;
  }

  int redAt(BossSprite s, double ux, double uy) =>
      red(s.x + ((ux - s.dx) * 2).floor(), s.y + ((uy - s.dy) * 2).floor());

  /// Opaque pixels of [s] as arena points (pixel centres) from its anchor.
  Iterable<(double, double)> points(BossSprite s) sync* {
    for (var y = 0; y < s.h; y++) {
      for (var x = 0; x < s.w; x++) {
        if (alpha(s.x + x, s.y + y) > 0) {
          yield (s.dx + (x + .5) / 2, s.dy + (y + .5) / 2);
        }
      }
    }
  }
}

void main() {
  // The simulation's carrier geometry (lib/game/model.dart): hatches at
  // Carrier.sideHatchOffset, hits accepted inside |dx| < 78 and
  // -25 < dy < 43, the force field 110 wide each side.
  final probe = Carrier(0);

  test('functional anchors are the simulation geometry', () {
    expect(BossAtlas.bayWindow.x, Carrier.sideHatchOffset);
    expect(BossAtlas.bayWindow.y, 21);
    expect((BossAtlas.bayWindow.w, BossAtlas.bayWindow.h), (22, 16));
    expect(BossAtlas.coreWindow, (x: 0.0, y: 25.0, w: 32.0, h: 22.0));
    expect(BossAtlas.turretPivot, (x: 28.0, y: 36.0));
    expect(BossAtlas.solidBody, (halfWidth: 78.0, top: -25.0, bottom: 43.0));
    expect(probe.forceFieldHalfWidth, 110);
  });

  test('one class per run, forms match the fight, the armada escalates', () {
    expect(BossAtlas.classes, hasLength(5));
    for (var k = 0; k < 5; k++) {
      final h = BossAtlas.classes[k];
      expect(h.forms, Carrier(k).formCount, reason: h.key);
      expect(h.superstructure, hasLength(h.forms));
      expect(h.hull, hasLength(h.forms));
      for (final row in h.hull) {
        expect(row, hasLength(4), reason: '${h.key}: four idle frames');
      }
      if (k > 0) {
        final prev = BossAtlas.classes[k - 1];
        expect(h.engines.length, greaterThan(prev.engines.length),
            reason: '${h.key} has more engines');
        double area((double, double, double, double) e) =>
            (e.$3 - e.$1) * (e.$4 - e.$2);
        expect(area(h.extent), greaterThan(area(prev.extent) * 1.15),
            reason: '${h.key} is bigger');
      }
    }
  });

  testWidgets('every class aligns its art with the simulation anchors', (
    tester,
  ) async {
    await tester.runAsync(() async {
      for (final h in BossAtlas.classes) {
        final image = await _decode('assets/images/${h.asset}');
        expect((image.width, image.height), (h.width, h.height));
        expect(image.width * image.height * 4, lessThanOrEqualTo(16 << 20),
            reason: '${h.key}: at most 16 MiB of texture');
        final bytes = (await image.toByteData())!.buffer.asUint8List();
        final a = _Atlas(image.width, bytes);
        var soft = 0;
        for (var i = 3; i < bytes.length; i += 4) {
          if (bytes[i] != 0 && bytes[i] != 255) soft++;
        }
        expect(soft, 0, reason: '${h.key}: hard pixel edges');
        final core = BossAtlas.coreWindow, bay = BossAtlas.bayWindow;

        // The maw and both bays are transparent windows in every bow frame,
        // edged by an opaque lip, and the eyes sit where the rage overlay
        // and the simulation expect them.
        void windows(BossSprite s, String what, {bool eyes = true}) {
          for (final (cx, w, hh) in [
            (core.x, core.w, core.h),
            (-bay.x, bay.w, bay.h),
            (bay.x, bay.w, bay.h),
          ]) {
            final cy = cx == core.x ? core.y : bay.y;
            for (var y = cy - hh / 2 + .25; y < cy + hh / 2; y += .5) {
              for (var x = cx - w / 2 + .25; x < cx + w / 2; x += .5) {
                expect(a.opaqueAt(s, x, y), isFalse,
                    reason: '${h.key} $what: window at ($cx, $cy)');
              }
            }
            var edge = 0, lit = 0;
            for (var x = cx - w / 2 + .25; x < cx + w / 2; x += .5) {
              for (final y in [cy - hh / 2 - .25, cy + hh / 2 + .25]) {
                edge++;
                if (a.opaqueAt(s, x, y)) lit++;
              }
            }
            expect(lit, edge, reason: '${h.key} $what: lip around ($cx, $cy)');
          }
          if (eyes) {
            for (final side in [-1.0, 1.0]) {
              expect(a.redAt(s, side * 15.5, -5), greaterThan(180),
                  reason: '${h.key} $what: glowing eye');
            }
          }
        }

        for (var f = 0; f < h.forms; f++) {
          windows(h.hull[f][0], 'form $f');
          for (var i = 1; i < 4; i++) {
            if (!h.hullPatch[f][i]) windows(h.hull[f][i], 'form $f idle $i');
          }
        }

        // Jaws stay inside the maw, bay doors inside the left bay.
        for (final s in h.jaws) {
          for (final (x, y) in a.points(s)) {
            expect(
              (x - core.x).abs() <= core.w / 2 &&
                  (y - core.y).abs() <= core.h / 2,
              isTrue,
              reason: '${h.key}: jaw pixel ($x, $y) outside the maw',
            );
          }
        }
        for (final s in h.vents) {
          for (final (x, y) in a.points(s)) {
            expect(
              (x + bay.x).abs() <= bay.w / 2 && (y - bay.y).abs() <= bay.h / 2,
              isTrue,
              reason: '${h.key}: bay door pixel ($x, $y) outside the bay',
            );
          }
        }
        // Turret muzzles glow at the barrel pivots.
        for (final s in h.turrets) {
          for (final side in [-1.0, 1.0]) {
            expect(a.opaqueAt(s, side * BossAtlas.turretPivot.x,
                BossAtlas.turretPivot.y + .5), isTrue,
                reason: '${h.key}: turret muzzle at the pivot');
          }
        }

        // No hull pixel hangs below the full force-field egg, and the
        // outer hull never reaches the creatures' and player's band.
        final full = Carrier(0)..x = 0..y = 0;
        for (final s in [...h.superstructure, ...h.hull.map((r) => r[0])]) {
          for (final (x, y) in a.points(s)) {
            if (x.abs() < full.forceFieldHalfWidth) {
              expect(y, lessThanOrEqualTo(full.forceFieldSurfaceY(x)),
                  reason: '${h.key}: hull ($x, $y) below the shield egg');
            } else {
              expect(y, lessThanOrEqualTo(12),
                  reason: '${h.key}: outer hull ($x, $y) in the combat band');
            }
          }
        }
        expect(205 + h.extent.$4, lessThan(ArcadeModel.shipY - 150),
            reason: '${h.key}: clear of the player zone');
        // Engines sit on the stern side, plumes point away from the player.
        for (final (x, y, size) in h.engines) {
          expect(y, lessThan(BossAtlas.solidBody.top), reason: h.key);
          expect(size, lessThan(h.plumes.length));
          expect(x.abs(), lessThanOrEqualTo(-h.extent.$1 + .5));
        }
        image.dispose();
      }
    });
  });

  test('the outer hull widens beyond the solid body only as background', () {
    for (final h in BossAtlas.classes) {
      // The bright bow stays within the hit box's width (plus its lip).
      final bow = h.hull[0][0];
      expect(bow.dx, greaterThanOrEqualTo(-BossAtlas.solidBody.halfWidth - 30));
      expect(bow.dx + bow.w / 2,
          lessThanOrEqualTo(BossAtlas.solidBody.halfWidth + 30));
      expect(math.max(-h.extent.$1, h.extent.$3),
          greaterThan(BossAtlas.solidBody.halfWidth));
    }
  });
}
