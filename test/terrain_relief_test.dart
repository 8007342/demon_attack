import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:demon_attack/game/ground_atlas.dart';
import 'package:demon_attack/game/model.dart';
import 'package:demon_attack/game/scene.dart';
import 'package:demon_attack/game/terrain_field.dart';
import 'package:flame/game.dart';
import 'package:flutter_test/flutter_test.dart';

Future<ui.Image> _decode(String file) async {
  final codec = await ui.instantiateImageCodec(await File(file).readAsBytes());
  final frame = await codec.getNextFrame();
  codec.dispose();
  return frame.image;
}

/// Review frames land here (keep them off the checkout's small tmpfs).
final _out = Platform.environment['TERRAIN_REVIEW'] ?? '.cache/terrain';

Future<void> _save(ui.Picture picture, int w, int h, String name) async {
  final image = await picture.toImage(w, h);
  final file = File('$_out/$name');
  await file.parent.create(recursive: true);
  await file.writeAsBytes(
      (await image.toByteData(format: ui.ImageByteFormat.png))!.buffer.asUint8List());
  image.dispose();
}

Future<DemonScene> _scene(ArcadeModel model) async {
  final scene = DemonScene(model, () {});
  for (var i = 0; i < 5; i++) {
    scene.sectors.images[i] = await _decode('assets/images/sector-${i + 1}.png');
  }
  await scene.sectors.loadFlyover((f) => _decode('assets/images/$f'));
  scene.sectors.flyover.reducedMotionOverride = false;
  return scene;
}

void main() {
  test('relief is deterministic per sector and route', () {
    for (var sector = 0; sector < 5; sector++) {
      final a = TerrainField(sector, 1), b = TerrainField(sector, 1);
      final c = TerrainField(sector, 2);
      var differs = false;
      for (var w = 0.0; w < 6000; w += 37) {
        for (final s in const [-90.0, -40.0, -5.0, 25.0, 70.0]) {
          expect(a.heightAt(s, w), b.heightAt(s, w));
          if ((a.heightAt(s, w) - c.heightAt(s, w)).abs() > .5) differs = true;
        }
      }
      expect(differs, isTrue, reason: 'routes get their own relief');
    }
  });

  test('relief is endless and seamless, with notable features', () {
    for (var sector = 0; sector < 5; sector++) {
      final f = TerrainField(sector, 0);
      final kinds = <TerrainKind>{};
      for (var j = 0; j < 400; j++) {
        kinds.add(f.feature(j).kind);
      }
      expect(kinds.length, greaterThanOrEqualTo(4), reason: 'sector $sector mix');
      // Continuity: no jump anywhere, including segment boundaries and far
      // along a long session.
      for (final start in const [0.0, 90000.0, 2.5e6]) {
        for (final s in const [-70.0, -40.0, -12.0, 30.0, 55.0]) {
          // Every segment boundary is continuous ...
          for (var b = (start / TerrainField.segment).ceil() * TerrainField.segment;
              b < start + 6 * TerrainField.segment;
              b += TerrainField.segment) {
            expect((f.heightAt(s, b + .001) - f.heightAt(s, b - .001)).abs(),
                lessThan(.05), reason: 'sector $sector seam at w=$b s=$s');
          }
          // ... and nothing jumps between neighbouring texels.
          var prev = f.heightAt(s, start);
          for (var w = start; w < start + 3 * TerrainField.segment; w += .5) {
            final h = f.heightAt(s, w);
            expect((h - prev).abs(), lessThan(6),
                reason: 'sector $sector step at w=$w s=$s');
            prev = h;
          }
        }
      }
    }
  });

  test('the central lane stays gentle and relief fades at the horizon', () {
    final view = TerrainView();
    for (var sector = 0; sector < 5; sector++) {
      view.configure(sector, 2);
      var lane = 0.0, sides = 0.0;
      for (var cam = 0.0; cam < 8000; cam += 53) {
        view.cam = cam;
        for (final z in const [180.0, 300.0, 500.0, 800.0]) {
          for (var x = 140.0; x <= 220; x += 10) {
            lane = math.max(lane, view.rawHeight(x, z).abs());
          }
          for (final x in const [10.0, 40.0, 320.0, 350.0]) {
            sides = math.max(sides, view.rawHeight(x, z).abs());
          }
        }
        expect(view.rawHeight(30, TerrainView.fadeFar + 10), 0);
      }
      expect(lane, lessThan(sides * .25), reason: 'sector $sector lane relief');
      expect(sides, greaterThan(14), reason: 'sector $sector side relief');
    }
  });

  test('surface API matches the mesh and the flat projection', () {
    final view = TerrainView()..configure(2, 1);
    for (final cam in const [0.0, 1234.0, 98765.0]) {
      view.cam = cam;
      view.prepare();
      for (var i = 0; i < TerrainView.rows - 1; i += 7) {
        for (var j = 0; j < TerrainView.columns - 1; j += 3) {
          final x = j * TerrainView.columnStep;
          final z = TerrainView.rowZ[i];
          expect(view.surfaceAt(x, z).y, closeTo(view.vertexY(i, j), 1e-6));
        }
      }
      for (var z = 140.0; z < 1500; z *= 1.07) {
        for (var x = 3.0; x < 360; x += 23) {
          final s = view.surfaceAt(x, z);
          expect(s.y, closeTo(view.yOf(x, z), 1e-9));
          if (!s.hidden) {
            expect(s.y, closeTo(GroundCamera.yOf(z) - s.height * GroundCamera.texel(z), 1.6),
                reason: 'x=$x z=$z');
          }
          expect(s.y, lessThanOrEqualTo(GroundCamera.yOf(z) - s.height * GroundCamera.texel(z) + 1.6));
        }
      }
    }
    // Zero relief is exactly the flat camera.
    final flat = TerrainView()..configure(0, 0);
    flat.cam = 0; // the first segment is gentle but noisy; check the envelope
    expect(flat.yOf(180, 9000), closeTo(GroundCamera.yOf(9000), 1e-6));
  });

  test('navigation keeps depth and lane, follows the surface', () {
    final view = TerrainView()..configure(3, 2);
    for (var cam = 500.0; cam < 6000; cam += 97) {
      view.cam = cam;
      for (final z in const [1300.0, 900.0, 400.0, 220.0]) {
        for (final side in const [0, 1]) {
          final width = 28 * GroundCamera.texel(z) * 1.25;
          final p = view.place(side, .7, width, z);
          if (side == 0) {
            expect(p.x + width / 2, lessThanOrEqualTo(GroundCamera.laneLeft + 1e-6));
          } else {
            expect(p.x - width / 2, greaterThanOrEqualTo(GroundCamera.laneRight - 1e-6));
          }
          expect(p.y, closeTo(view.yOf(p.x.clamp(0, 360), z), 1e-9));
          expect(p.pace, inInclusiveRange(.5, 1.25));
        }
      }
    }
  });

  test('ground units ride the relief without changing the rules', () {
    final model = ArcadeModel()..start();
    model.mode = RunMode.playing;
    model.level = 4;
    final view = TerrainView()..configure(3, 0);
    view.cam = 3000;
    model.ground.relief = view;
    final u = GroundUnit(1, 3, 0, .5, 600);
    model.ground.units.add(u);
    model.update(1 / 60);
    expect(u.pose, isNotNull);
    expect(u.y, closeTo(view.yOf(u.x, u.z), 1e-6));
    expect(u.inRange, isFalse, reason: 'range is logical depth');
    model.ground.relief = null;
    model.update(1 / 60);
    expect(u.x, GroundCamera.bandX(u.side, u.across, u.width));
  });

  test('terrain radio events are rate limited', () {
    final events = <String>[];
    final kinds = <String, double>{};
    final times = <double>[];
    final radio = TerrainRadio(emit: (e) => events.add(e.name));
    final field = TerrainField(0, 1);
    var lastKindOk = true;
    for (var t = 0.0; t < 900; t += 1 / 30) {
      radio.clock = t;
      final before = events.length;
      radio.lookAhead(field, t * 13, 1);
      if (events.length > before) {
        final kind = radio.log.last.data['kind'] as String;
        times.add(t);
        if (kinds.containsKey(kind) && t - kinds[kind]! < TerrainRadio.aheadKindGap) {
          lastKindOk = false;
        }
        kinds[kind] = t;
      }
    }
    expect(times.length, greaterThan(3));
    for (var i = 1; i < times.length; i++) {
      expect(times[i] - times[i - 1], greaterThanOrEqualTo(TerrainRadio.aheadGap));
    }
    expect(lastKindOk, isTrue);
    // Climbing / stuck: a sustained steep climb gives one call per gap.
    events.clear();
    for (var t = 0.0; t < 60; t += 1 / 60) {
      radio.clock = 1000 + t;
      radio.ally(7, 0, .5, 1 / 60, 40, 400, 2);
    }
    final climbs = events.where((e) => e == GameEventNames.convoyClimbing).length;
    final stuck = events.where((e) => e == GameEventNames.convoyStuck).length;
    expect(climbs, inInclusiveRange(3, 4));
    expect(stuck, 1);
  });

  testWidgets('review: relief per sector, units on slopes, travel blend, sizes',
      (tester) async {
    await tester.runAsync(() async {
      final model = ArcadeModel()..start();
      model.mode = RunMode.playing;
      model.demons.clear();
      final scene = await _scene(model);
      scene.atlas = await _decode('assets/images/combat.png');
      final flyover = scene.sectors.flyover;
      // Every sector: two distances in one sheet.
      final recorder = ui.PictureRecorder();
      final sheet = ui.Canvas(recorder);
      for (var sector = 0; sector < 5; sector++) {
        for (var k = 0; k < 4; k++) {
          model.level = sector + 1;
          model.cycle = k;
          scene.environment = sector.toDouble();
          flyover.distance = 2400.0 + k * 1900;
          scene.sectors.advance(0, model, sector.toDouble());
          final cell = ui.PictureRecorder();
          scene.paintArena(ui.Canvas(cell), Vector2(360, 520), combat: false);
          final pic = cell.endRecording();
          sheet.save();
          sheet.translate(k * 364.0, sector * 524.0);
          sheet.drawPicture(pic);
          sheet.restore();
          pic.dispose();
        }
      }
      await _save(recorder.endRecording(), 4 * 364, 5 * 524, 'sectors.png');

      // Travel blend frames.
      for (final p in const [.25, .5, .75]) {
        model.level = 2;
        scene.environment = 1 + p;
        flyover.distance = 5000;
        final r = ui.PictureRecorder();
        scene.paintArena(ui.Canvas(r), Vector2(360, 520), combat: false);
        await _save(r.endRecording(), 360, 520, 'travel-${(p * 100).round()}.png');
      }
      // Phone (3x) and desktop-ish (2x) sizes.
      model.level = 3;
      scene.environment = 2;
      flyover.distance = 7000;
      for (final (name, scale) in const [('phone', 3.0), ('desktop', 2.0)]) {
        final r = ui.PictureRecorder();
        scene.paintArena(ui.Canvas(r), Vector2(360 * scale, 520 * scale),
            combat: false);
        await _save(r.endRecording(), (360 * scale).round(), (520 * scale).round(),
            'size-$name.png');
      }
    });
  });

  testWidgets('review: features, units on the relief, vegetation pushed',
      (tester) async {
    await tester.runAsync(() async {
      final model = ArcadeModel()..start();
      model.mode = RunMode.playing;
      model.demons.clear();
      final scene = await _scene(model);
      scene.atlas = await _decode('assets/images/combat.png');
      scene.groundForces.image =
          await _decode('assets/images/${GroundAtlas.file}');
      final flyover = scene.sectors.flyover;
      const z0 = GroundCamera.z0;
      const kinds = [
        TerrainKind.ridge,
        TerrainKind.mesa,
        TerrainKind.canyon,
        TerrainKind.valley,
        TerrainKind.forest,
        TerrainKind.crystalField,
        TerrainKind.ruins,
      ];
      // One frame per sector and feature kind, the feature 1.6 z0 ahead.
      final recorder = ui.PictureRecorder();
      final sheet = ui.Canvas(recorder);
      for (var sector = 0; sector < 5; sector++) {
        model.level = sector + 1;
        model.cycle = 1;
        scene.environment = sector.toDouble();
        final field = TerrainField(sector, 1);
        var col = 0;
        for (final kind in kinds) {
          var j = 1;
          while (j < 400 && field.feature(j).kind != kind) {
            j++;
          }
          if (j >= 400) continue;
          flyover.distance = 2 * (field.feature(j).w - 1.6 * z0);
          scene.sectors.advance(0, model, sector.toDouble());
          final cell = ui.PictureRecorder();
          scene.paintArena(ui.Canvas(cell), Vector2(360, 520), combat: false);
          final pic = cell.endRecording();
          sheet.save();
          sheet.translate(col * 364.0, sector * 524.0);
          sheet.drawPicture(pic);
          sheet.restore();
          pic.dispose();
          col++;
        }
      }
      await _save(recorder.endRecording(), 7 * 364, 5 * 524, 'features.png');

      // Units on slopes and in valleys (Ember and Hollow).
      for (final sector in const [2, 3]) {
        model.level = sector + 1;
        scene.environment = sector.toDouble();
        final field = TerrainField(sector, 1);
        var j = 1;
        while (field.feature(j).kind != TerrainKind.mesa &&
            field.feature(j).kind != TerrainKind.valley) {
          j++;
        }
        flyover.distance = 2 * (field.feature(j).w - 2.2 * z0);
        scene.sectors.advance(0, model, sector.toDouble());
        model.ground.units.clear();
        model.ground.allies.clear();
        var id = 0;
        for (final (side, across, z) in const [
          (0, .3, 900.0),
          (1, .6, 700.0),
          (0, .7, 520.0),
          (1, .3, 430.0),
          (0, .45, 330.0),
          (1, .5, 260.0),
        ]) {
          final u = GroundUnit(id++, sector, side, across, z);
          final a = GroundAlly(id++, sector, side, (across + .35) % 1, z - 110, 8)
            ..announced = true;
          model.ground.units.add(u);
          model.ground.allies.add(a);
        }
        for (final u in model.ground.units) {
          u.pose = flyover.relief.place(u.side, u.across, u.width, u.z);
        }
        for (final a in model.ground.allies) {
          a.pose =
              flyover.relief.place(a.side, a.across, a.width, a.z, ally: true);
        }
        final r = ui.PictureRecorder();
        scene.paintArena(ui.Canvas(r), Vector2(720, 1040));
        await _save(r.endRecording(), 720, 1040, 'units-sector${sector + 1}.png');
      }

      // An ally ploughs through a Krybor stand of frost pines.
      model.level = 1;
      scene.environment = 0;
      model.ground.units.clear();
      model.ground.allies.clear();
      final field = TerrainField(0, 1);
      var j = 1;
      while (field.feature(j).kind != TerrainKind.forest) {
        j++;
      }
      flyover.distance = 2 * (field.feature(j).w - 1.8 * z0);
      scene.sectors.advance(0, model, 0);
      final plants = flyover.relief
          .vegetation(250, 420)
          .where((v) => v.hitAt == null)
          .toList();
      expect(plants, isNotEmpty);
      final target = plants.last;
      final ally = GroundAlly(99, 0, target.side, target.across.clamp(0, 1),
          target.w - flyover.relief.cam + 30, 8)
        ..announced = true;
      model.ground.allies.add(ally);
      final frames = ui.PictureRecorder();
      final strip = ui.Canvas(frames);
      final tz = target.w - flyover.relief.cam;
      final tx = target.xAt(tz), ty = flyover.relief.yOf(tx, tz);
      await File('$_out/push-target.txt').writeAsString('$tx $ty');
      for (var f = 0; f < 8; f++) {
        ally.z -= 5;
        ally.pose = flyover.relief
            .place(ally.side, ally.across, ally.width, ally.z, ally: true);
        flyover.advance(1 / 12, model, 0);
        final cell = ui.PictureRecorder();
        scene.paintArena(ui.Canvas(cell), Vector2(360, 520));
        final pic = cell.endRecording();
        strip.save();
        strip.translate(f * 364.0, 0);
        strip.drawPicture(pic);
        strip.restore();
        pic.dispose();
      }
      await _save(frames.endRecording(), 8 * 364, 520, 'push-krybor.png');
      expect(flyover.pushedVegetation, greaterThan(0));
    });
  });

  testWidgets('review: relief wireframe over the ground', (tester) async {
    await tester.runAsync(() async {
      final model = ArcadeModel()..start();
      model.mode = RunMode.playing;
      model.demons.clear();
      final scene = await _scene(model);
      final flyover = scene.sectors.flyover;
      final recorder = ui.PictureRecorder();
      final sheet = ui.Canvas(recorder);
      for (var sector = 0; sector < 5; sector++) {
        model.level = sector + 1;
        model.cycle = 1;
        scene.environment = sector.toDouble();
        flyover.distance = 6000.0 + sector * 777;
        scene.sectors.advance(0, model, sector.toDouble());
        final cell = ui.PictureRecorder();
        final c = ui.Canvas(cell);
        scene.paintArena(c, Vector2(360, 520), combat: false);
        final t = flyover.relief..prepare();
        final p = ui.Paint()
          ..color = const ui.Color(0xAAFF4040)
          ..strokeWidth = .6
          ..style = ui.PaintingStyle.stroke;
        for (var i = 0; i < TerrainView.rows; i += 3) {
          final path = ui.Path();
          for (var j = 0; j < TerrainView.columns; j++) {
            final pt = ui.Offset(j * TerrainView.columnStep, t.vertexY(i, j));
            j == 0 ? path.moveTo(pt.dx, pt.dy) : path.lineTo(pt.dx, pt.dy);
          }
          c.drawPath(path, p);
        }
        final pic = cell.endRecording();
        sheet.save();
        sheet.translate(sector * 364.0, 0);
        sheet.drawPicture(pic);
        sheet.restore();
        pic.dispose();
      }
      await _save(recorder.endRecording(), 5 * 364, 520, 'wire.png');
    });
  });
}
