@Tags(['review'])
library;

import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:demon_attack/game/model.dart';
import 'package:demon_attack/game/scene.dart';
import 'package:flame/game.dart';
import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';

/// fire-rate-tune review (openspec/changes/fire-rate-tune design §6): the
/// player's stream before and after, drawn by the real scene.
///
/// Sheet `art/contact/fire-rate-tune.png` (with
/// `--dart-define=FIRE_RATE_CONTACT=true`; otherwise
/// `.cache/fire-rate-tune-review/`):
/// - row 1: one dense Hard fight (route 3, sector 3) at the same frame, four
///   times: the base gun before | after, Rapid before | after. Only the
///   player's stream differs; demons and hostile shots are the same frame.
/// - rows 2-5: eight consecutive displayed frames of the Rapid stream above
///   the ship (an 80 × 480 unit column): before at 60 fps, after at 60 fps,
///   before at 30 fps (every second model step), after at 30 fps.
///
/// "Before" is the old rule replayed: 0.23 s / 0.105 s volleys on the old
/// `_fire <= 0` timer at 390 u/s; "after" is the same replay with the
/// shipped constants. Both go through the scene's own shot painter.
///
/// Run alone: flutter test --concurrency=1 --run-skipped --tags review
///   test/fire_rate_tune_review_test.dart
const _contact = bool.fromEnvironment('FIRE_RATE_CONTACT');
const _out = _contact
    ? 'art/contact/fire-rate-tune.png'
    : '.cache/fire-rate-tune-review/fire-rate-tune.png';
const _ratio = 2.0;

typedef Rule = ({double speed, double base, double rapid, double eps});

const Rule before = (speed: 390, base: .23, rapid: .105, eps: 0);
const Rule after = (
  speed: ArcadeModel.shotSpeed,
  base: ArcadeModel.fireSteps / 60,
  rapid: ArcadeModel.rapidFireSteps / 60,
  eps: 1e-9,
);

/// The player's straight stream from x after [steps] model steps of
/// holding fire under [rule] (Rapid alternates the wing muzzles).
List<Shot> replay(Rule rule, double x, int steps, {required bool rapid}) {
  final out = <Shot>[];
  var fire = 0.0, side = -1;
  for (var n = 0; n < steps; n++) {
    fire -= 1 / 60;
    if (fire <= rule.eps) {
      // The shipped timer never carries an overdue step into the next gap.
      if (rule.eps > 0) fire = math.max(0.0, fire);
      fire += rapid ? rule.rapid : rule.base;
      if (rapid) {
        out.add(Shot(x + side * 15.5, ArcadeModel.shipY - 10, 0, -rule.speed));
        side = -side;
      } else {
        out.add(Shot(x, ArcadeModel.shipY - 13, 0, -rule.speed));
      }
    }
    for (final s in out) {
      s.y += s.vy / 60;
    }
    out.removeWhere((s) => s.y < -10);
  }
  return out;
}

Future<ui.Image> _decode(String file) async {
  final codec = await ui.instantiateImageCodec(await File(file).readAsBytes());
  final frame = await codec.getNextFrame();
  codec.dispose();
  return frame.image;
}

Future<ui.Image> _frame(DemonScene scene) async {
  final recorder = ui.PictureRecorder();
  final canvas = ui.Canvas(recorder)..scale(_ratio);
  scene.paintArena(canvas, Vector2(ArcadeModel.width, ArcadeModel.height));
  final picture = recorder.endRecording();
  final image = await picture.toImage(
    (ArcadeModel.width * _ratio).round(),
    (ArcadeModel.height * _ratio).round(),
  );
  picture.dispose();
  return image;
}

void main() {
  test('the replay matches the model: whole-step gaps, 8 u per step', () {
    final shots = replay(after, 180, 600, rapid: false);
    final ys = shots.map((s) => s.y).toList()..sort();
    for (var i = 1; i < ys.length; i++) {
      expect(ys[i] - ys[i - 1], closeTo(ArcadeModel.shotSpeed * .3, 1e-6));
    }
    final old = replay(before, 180, 600, rapid: false);
    final gaps = {
      for (var i = 1; i < old.length; i++)
        ((old[i - 1].y - old[i].y).abs() / 6.5).round(),
    };
    expect(gaps.length, greaterThan(1), reason: 'the old 13/14-step beat');
  });

  testWidgets('fire-rate-tune review sheet', (tester) async {
    await tester.runAsync(() async {
      final model = ArcadeModel(seed: 1982)
        ..startAt(difficulty: Difficulty.hard, sector: 3, route: 2);
      final scene = DemonScene(model, () {});
      final art = <ui.Image>[
        scene.atlas = await _decode('assets/images/combat.png'),
        scene.effectsAtlas = await _decode(
          'assets/images/sentinel-effects.png',
        ),
        scene.sky = await _decode('assets/images/cosmic-sky.png'),
        scene.ship.image = await _decode('assets/images/ship-weapons.png'),
      ];
      for (var i = 0; i < 5; i++) {
        art.add(
          scene.sectors.images[i] = await _decode(
            'assets/images/sector-${i + 1}.png',
          ),
        );
      }
      await scene.sectors.loadFlyover((f) async {
        final image = await _decode('assets/images/$f');
        art.add(image);
        return image;
      });
      scene.sectors.flyover.reducedMotionOverride = true;
      scene.environment = 2;

      // A dense moment: protected, chasing the first settled demon, until
      // the swarm is out and hostile shots are in the air (bounded).
      for (var f = 0; f < 60 * 40; f++) {
        model.invulnerable = 5;
        final d = model.demons.where((d) => !d.entering).firstOrNull;
        if (d != null) model.moveTo(d.x);
        model.update(1 / 60);
        scene.creatures.update(model, 1 / 60);
        model.takeEvents();
        model.takeGameEvents();
        model.shots.removeWhere((s) => !s.hostile); // keep the swarm whole
        if (f > 60 * 12 &&
            model.demons.length >= 14 &&
            model.shots.where((s) => s.hostile).length >= 6) {
          break;
        }
      }
      expect(model.demons, isNotEmpty);
      final hostile = [...model.shots];
      final x = model.shipX;

      Future<ui.Image> shoot(Rule rule, {required bool rapid, int at = 600}) {
        if (rapid) {
          model.powerTimers[Power.rapid] = 9;
        } else {
          model.powerTimers.remove(Power.rapid);
        }
        model.shots
          ..clear()
          ..addAll(hostile)
          ..addAll(replay(rule, x, at, rapid: rapid));
        return _frame(scene);
      }

      final dense = [
        await shoot(before, rapid: false),
        await shoot(after, rapid: false),
        await shoot(before, rapid: true),
        await shoot(after, rapid: true),
      ];
      final strips = <List<ui.Image>>[];
      for (final (rule, every) in [
        (before, 1),
        (after, 1),
        (before, 2),
        (after, 2),
      ]) {
        strips.add([
          for (var k = 0; k < 8; k++)
            await shoot(rule, rapid: true, at: 600 + k * every),
        ]);
      }

      // The sheet: dense frames at half size, strip columns at full size.
      const gap = 6.0, colW = 80.0, colH = 480.0;
      final denseW = ArcadeModel.width / 2, denseH = ArcadeModel.height / 2;
      final width = gap + 4 * (denseW + gap);
      final height = gap + denseH + gap + 4 * (colH + gap);
      final rec = ui.PictureRecorder();
      final c = ui.Canvas(rec)..scale(_ratio);
      c.drawRect(
        Rect.fromLTWH(0, 0, width, height),
        Paint()..color = const Color(0xFF101018),
      );
      for (final (i, img) in dense.indexed) {
        c.drawImageRect(
          img,
          Rect.fromLTWH(0, 0, img.width.toDouble(), img.height.toDouble()),
          Rect.fromLTWH(gap + i * (denseW + gap), gap, denseW, denseH),
          Paint()..filterQuality = FilterQuality.medium,
        );
      }
      final left = (x - colW / 2).clamp(0.0, ArcadeModel.width - colW);
      for (final (r, row) in strips.indexed) {
        final y = gap + denseH + gap + r * (colH + gap);
        for (final (k, img) in row.indexed) {
          c.drawImageRect(
            img,
            Rect.fromLTWH(left * _ratio, 0, colW * _ratio, colH * _ratio),
            Rect.fromLTWH(gap + k * (colW + gap), y, colW, colH),
            Paint(),
          );
        }
      }
      final picture = rec.endRecording();
      final sheet = await picture.toImage(
        (width * _ratio).round(),
        (height * _ratio).round(),
      );
      picture.dispose();
      final file = File(_out);
      await file.parent.create(recursive: true);
      await file.writeAsBytes(
        (await sheet.toByteData(format: ui.ImageByteFormat.png))!.buffer
            .asUint8List(),
      );
      sheet.dispose();
      for (final img in [...dense, for (final s in strips) ...s, ...art]) {
        img.dispose();
      }
    });
  });
}
