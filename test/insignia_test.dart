import 'dart:io';
import 'dart:ui' as ui;

import 'package:demon_attack/game/insignia_atlas.dart';
import 'package:demon_attack/game/insignia_painter.dart';
import 'package:demon_attack/game/model.dart';
import 'package:demon_attack/game/scene.dart';
import 'package:demon_attack/game/sprite_atlas.dart';
import 'package:flame/game.dart';
import 'package:flutter_test/flutter_test.dart';

Future<ui.Image> decodeAsset(String file) async {
  final codec = await ui.instantiateImageCodec(await File(file).readAsBytes());
  final frame = await codec.getNextFrame();
  codec.dispose();
  return frame.image;
}

double luma(int r, int g, int b) => (.2126 * r + .7152 * g + .0722 * b) / 255;

/// A combat scene without art: the creature pass still queues its marks.
(ArcadeModel, DemonScene) bareScene() {
  final m = ArcadeModel(seed: 3)..startAt(sector: 2, route: 1);
  m
    ..mode = RunMode.playing
    ..clock = 2;
  m.demons.clear();
  m.incoming.clear();
  return (m, DemonScene(m, () {}));
}

/// Paints one arena frame and returns the overlay marks it placed.
List<InsigniaMark> paintMarks(DemonScene scene) {
  final r = ui.PictureRecorder();
  scene.paintArena(ui.Canvas(r), Vector2(360, 520));
  r.endRecording().dispose();
  return scene.insignia.lastMarks;
}

/// alien-insignia (openspec/changes/alien-insignia, design §7): the rank
/// ladder from game data, head anchors, glyph contrast, fixed size under
/// zoom, the overlap rule and the reveal gate.
void main() {
  group('rankOf (design §1)', () {
    Demon demon(
      int kind,
      int maxHp, {
      bool elite = false,
      EnemyArchetype archetype = EnemyArchetype.ordinary,
    }) => Demon(0, 0, kind, maxHp, 0, elite: elite, archetype: archetype);

    final table = <(Demon, AlienRank)>[
      (demon(0, 1), AlienRank.drone),
      (demon(1, 2), AlienRank.drone),
      (demon(2, 1), AlienRank.skirmisher),
      (demon(3, 2), AlienRank.skirmisher),
      (demon(0, 3), AlienRank.skirmisher),
      (demon(1, 4), AlienRank.veteran),
      (demon(2, 5), AlienRank.veteran),
      (demon(0, 1, elite: true), AlienRank.hunter),
      (demon(3, 5, elite: true), AlienRank.hunter),
      (
        demon(0, 9, archetype: EnemyArchetype.shieldSentinel),
        AlienRank.sentinel,
      ),
      (
        demon(1, 12, archetype: EnemyArchetype.armoredSentinel),
        AlienRank.sentinel,
      ),
    ];
    for (final (d, rank) in table) {
      test('kind ${d.kind} maxHp ${d.maxHp} elite ${d.elite} '
          '${d.archetype.name} -> ${rank.name}', () {
        expect(CombatAtlas.rankOf(d), rank);
      });
    }

    test('is a pure read: damage never changes the rank', () {
      final d = demon(2, 4);
      final before = CombatAtlas.rankOf(d);
      d.hp = 1;
      expect(CombatAtlas.rankOf(d), before);
      expect(d.maxHp, 4);
    });
  });

  group('head anchors (design §3)', () {
    test('every flight, flash and action cell has a skull top above the '
        'centre, near the cell middle', () {
      for (var k = 0; k < 4; k++) {
        final b = CombatAtlas.base(k);
        for (var r = 0; r < 5; r++) {
          for (var col = 0; col < 30; col++) {
            final a = CombatAtlas.headAnchor(b + r, col);
            expect(a.dx.abs(), lessThan(8), reason: 'k$k r$r c$col');
            expect(a.dy, inInclusiveRange(-16, -6), reason: 'k$k r$r c$col');
          }
        }
        for (final col in [0, 3, 4, 8, 20, 29, 30, 31]) {
          final a = CombatAtlas.headAnchor(b + 7, col);
          expect(a.dy, inInclusiveRange(-16, -4), reason: 'action c$col');
        }
      }
    });

    test('the anchor follows the flap lift and leans into banks', () {
      final b = CombatAtlas.base(0);
      // Neutral flap frames 0 (lift 0) and 2 (lift -2): the head rises.
      final level = CombatAtlas.headAnchor(b, 10);
      final up = CombatAtlas.headAnchor(b, 12);
      expect(up.dy, level.dy - 2);
      // Banking left / right shifts the head to that side.
      expect(CombatAtlas.headAnchor(b, 8).dx, lessThan(level.dx));
      expect(CombatAtlas.headAnchor(b, 28).dx, greaterThan(level.dx));
    });

    test('cells without a head fall back to the species value plus lift', () {
      final death = CombatAtlas.headAnchor(CombatAtlas.deathRow(2), 14);
      expect(death, Offset(0, CombatAtlas.neutralHeadTop[2] - 32.0));
      final lifted = CombatAtlas.headAnchor(
        CombatAtlas.eliteRow(1),
        3,
        lift: -2,
      );
      expect(lifted.dy, CombatAtlas.neutralHeadTop[1] - 32.0 - 2);
    });
  });

  group('glyphs and legibility (styleguide §7)', () {
    test('every rank has its own glyph; drones none; carrier ladder', () {
      final keys = {
        for (final r in AlienRank.values.skip(1))
          InsigniaPainter.glyphKey(r, InsigniaTone.bone),
      };
      expect(keys, hasLength(4));
      for (final k in keys) {
        expect(InsigniaAtlas.rects, contains(k));
      }
      expect(
        [for (var f = 0; f < 4; f++) InsigniaPainter.carrierRank(f)],
        [
          AlienRank.skirmisher,
          AlienRank.veteran,
          AlienRank.hunter,
          AlienRank.sentinel,
        ],
      );
    });

    test('strokes are 2 glyph px (2.7 units) and the smallest fill is at '
        'least 9 x 6 units', () {
      expect(2 * InsigniaPainter.unitsPerGlyphPx, closeTo(2.7, .01));
      final talon = InsigniaPainter.sizeOf('talon/bone');
      // The atlas rect carries a 1 glyph px outline on each side.
      final outline = 2 * InsigniaPainter.unitsPerGlyphPx;
      expect(talon.width - outline, greaterThanOrEqualTo(9));
      expect(talon.height - outline, greaterThanOrEqualTo(6));
    });

    testWidgets('bone glyphs differ from every species hide by luma >= 0.35', (
      tester,
    ) async {
      await tester.runAsync(() async {
        final atlas = await decodeAsset('assets/images/combat.png');
        final px = (await atlas.toByteData())!.buffer.asUint8List();
        final boneLuma = luma(0xF6, 0xEB, 0xC8);
        for (var k = 0; k < 4; k++) {
          var sum = 0.0, n = 0;
          final row = CombatAtlas.base(k), col = 18; // neutral glide
          for (var y = 0; y < 64; y++) {
            for (var x = 0; x < 64; x++) {
              final i = ((row * 64 + y) * atlas.width + col * 64 + x) * 4;
              if (px[i + 3] < 200) continue;
              final l = luma(px[i], px[i + 1], px[i + 2]);
              if (l < .14) continue; // the outline
              sum += l;
              n++;
            }
          }
          final hide = sum / n;
          expect(
            (boneLuma - hide).abs(),
            greaterThanOrEqualTo(.35),
            reason: 'species $k hide luma ${hide.toStringAsFixed(2)}',
          );
        }
        atlas.dispose();
      });
    });
  });

  group('InsigniaPainter (design §2)', () {
    test('a fixed size under camera zoom; positions follow the camera', () {
      final p = InsigniaPainter()
        ..begin()
        ..rank(Object(), AlienRank.hunter, const Offset(100, 100))
        ..cell(const Offset(100, 130), ShieldCell.lit);
      final z1 = p.layout();
      const centre = Offset(180, 260);
      final z86 = p.layout(toScreen: (o) => centre + (o - centre) * .86);
      expect(z86, hasLength(2));
      for (var i = 0; i < z1.length; i++) {
        expect(z86[i].rect.width, closeTo(z1[i].rect.width, 1e-9));
        expect(z86[i].rect.height, closeTo(z1[i].rect.height, 1e-9));
      }
      final moved = centre + (const Offset(100, 100) - centre) * .86;
      expect(z86[0].rect.bottomCenter.dx, closeTo(moved.dx, 1e-9));
      expect(z86[0].rect.bottomCenter.dy, closeTo(moved.dy, 1e-9));
      expect(z1[0].rect.bottomCenter, const Offset(100, 100));
    });

    test('the lower rank yields where glyphs would overlap, and holds', () {
      final p = InsigniaPainter();
      final low = Object(), high = Object();
      List<InsigniaMark> frame(double now, Offset lowAt) {
        p
          ..begin()
          ..rank(low, AlienRank.skirmisher, lowAt)
          ..rank(high, AlienRank.hunter, const Offset(100, 100));
        return p.layout(now: now);
      }

      var marks = frame(0, const Offset(104, 102));
      expect(marks.map((m) => m.owner), [high]);
      // Apart again within the hold: still skipped (no flicker).
      marks = frame(.2, const Offset(160, 100));
      expect(marks.map((m) => m.owner), [high]);
      // After the hold it comes back.
      marks = frame(.35, const Offset(160, 100));
      expect(marks.map((m) => m.owner).toSet(), {high, low});
      final fills = [
        for (final m in marks) m.rect.deflate(InsigniaPainter.unitsPerGlyphPx),
      ];
      expect(fills[0].overlaps(fills[1]), isFalse);
    });

    test('reveal gate: nothing in the fog wears a glyph', () {
      expect(InsigniaPainter.revealAlpha(.5), 0);
      expect(InsigniaPainter.revealAlpha(.6), 0);
      expect(InsigniaPainter.revealAlpha(.75), 1);
      final (m, scene) = bareScene();
      final fogged = Demon(100, 120, 2, 3, 1)..nearness = .05;
      final clear = Demon(220, 120, 2, 3, 2)..nearness = 1;
      m.demons.addAll([fogged, clear]);
      final marks = paintMarks(scene);
      expect(marks.where((k) => k.owner == fogged), isEmpty);
      expect(marks.where((k) => k.owner == clear), hasLength(1));
    });

    test('drones carry nothing; the glyph rides the head anchor', () {
      final (m, scene) = bareScene();
      final drone = Demon(80, 150, 0, 1, 1)..nearness = 1;
      final vet = Demon(200, 150, 1, 4, 2)..nearness = 1;
      m.demons.addAll([drone, vet]);
      final marks = paintMarks(scene);
      expect(marks.where((k) => k.owner == drone), isEmpty);
      final g = marks.singleWhere((k) => k.owner == vet);
      expect(g.key, 'talon2/bone');
      // Just above the skull: 5-12 units above the body centre.
      expect(150 - g.rect.bottom, inInclusiveRange(5, 12));
      expect((g.rect.center.dx - 200).abs(), lessThan(4));
    });

    test('angry glyphs turn gold; a telling creature flashes white', () {
      final (m, scene) = bareScene();
      final angry = Demon(80, 150, 2, 3, 1)
        ..nearness = 1
        ..hp = 1;
      final tell = Demon(200, 150, 2, 3, 2)
        ..nearness = 1
        ..telegraph = .5;
      m.demons.addAll([angry, tell]);
      final marks = paintMarks(scene);
      expect(marks.singleWhere((k) => k.owner == angry).key, 'talon/angry');
      final on = InsigniaPainter.tellOn(m.visualClock);
      expect(
        marks.singleWhere((k) => k.owner == tell).key,
        on ? 'talon/tell' : 'talon/bone',
      );
      expect(scene.rimCount, on ? 2 : 1);
      expect(InsigniaPainter.tellOn(1.05, reducedMotion: true), isTrue);
      expect(InsigniaPainter.tellOn(1.15), isFalse);
    });
  });

  group('force shields (design §4)', () {
    test('spent points go from the outside in', () {
      expect(InsigniaPainter.litCells(5, 3), [false, true, true, true, false]);
      expect(InsigniaPainter.litCells(5, 0), everyElement(false));
      expect(InsigniaPainter.litCells(3, 3), everyElement(true));
      final arc = InsigniaPainter.arc(5, Offset.zero, 30, 22);
      expect(arc[2].dy, closeTo(22, 1e-9)); // the middle faces the player
      expect(arc[0].dx, lessThan(0));
      expect(arc[4].dx, greaterThan(0));
    });

    test('a 5-point sentinel shield after two hits: 3 cells, 2 sockets, '
        'white flash then shards (spec scenario)', () {
      final (m, scene) = bareScene();
      final s = Demon(
        180,
        90,
        0,
        9,
        0,
        archetype: EnemyArchetype.shieldSentinel,
        shieldMax: 5,
      )..nearness = 1;
      m.demons.add(s);
      scene.creatures.update(m, 1 / 60);
      var cells = paintMarks(scene).where((k) => k.key.startsWith('cell/'));
      expect(cells, hasLength(5));
      expect(cells.map((k) => k.key), everyElement('cell/lit'));
      s.shield = 3;
      scene.creatures.update(m, 1 / 60);
      cells = paintMarks(scene).where((k) => k.key.startsWith('cell/'));
      expect(cells.where((k) => k.key == 'cell/flash'), hasLength(2));
      scene.creatures.update(m, 2 / 60);
      cells = paintMarks(scene).where((k) => k.key.startsWith('cell/'));
      expect(cells.where((k) => k.key == 'cell/lit'), hasLength(3));
      expect(cells.where((k) => k.key == 'cell/spent'), hasLength(2));
      expect(scene.creatures.shields.shards, hasLength(inInclusiveRange(4, 6)));
      expect(scene.rimCount, 1, reason: 'the cyan rim remains');
      expect(
        scene.insignia.lastMarks.where((k) => k.owner == s).single.key,
        'crown/bone',
      );
    });

    test('at most 12 shards alive', () {
      final fx = ShieldFx();
      for (var i = 0; i < 10; i++) {
        fx.spawnShards(Offset(i * 10.0, 0));
      }
      expect(fx.shards.length, ShieldFx.maxShards);
    });

    test('the carrier lights ceil(12 shield / max) hull cells', () {
      expect(ShieldFx.bossCells(10, 10), 12);
      expect(ShieldFx.bossCells(6, 10), 8);
      expect(ShieldFx.bossCells(1, 10), 2);
      expect(ShieldFx.bossCells(0, 10), 0);
      final (m, scene) = bareScene();
      final b = Carrier(1)
        ..x = 180
        ..y = 205;
      b.shield = (b.shieldMax * .6).round();
      m.boss = b;
      final marks = paintMarks(scene);
      final cells = marks.where((k) => k.key.startsWith('cell/'));
      expect(cells, hasLength(12));
      expect(
        cells.where((k) => k.key == 'cell/lit'),
        hasLength(ShieldFx.bossCells(b.shield, b.shieldMax)),
      );
      expect(marks.where((k) => k.owner == b).single.key, 'talon/bone');
    });
  });

  group('health and state (design §5)', () {
    List<double> apply(List<double> m, List<double> rgb) => [
      for (var r = 0; r < 3; r++)
        m[r * 5] * rgb[0] +
            m[r * 5 + 1] * rgb[1] +
            m[r * 5 + 2] * rgb[2] +
            m[r * 5 + 4],
    ];

    test('molt 0 is the identity; the warm-up moves hide toward ember and '
        'barely moves the outline', () {
      final id = InsigniaPainter.warmMatrix(0);
      expect(apply(id, [10, 120, 200]), [10, 120, 200]);
      const hide = [40.0, 140.0, 130.0]; // teal hide
      final warm = apply(InsigniaPainter.warmMatrix(3), hide);
      expect(warm[0], greaterThan(hide[0] + 30));
      expect(warm[2], lessThan(hide[2]));
      const outline = [12.0, 14.0, 24.0];
      final o = apply(InsigniaPainter.warmMatrix(3), outline);
      for (var i = 0; i < 3; i++) {
        expect((o[i] - outline[i]).abs(), lessThan(10));
      }
      final identity = <double>[
        1, 0, 0, 0, 0, //
        0, 1, 0, 0, 0,
        0, 0, 1, 0, 0,
        0, 0, 0, 1, 0,
      ];
      expect(
        InsigniaPainter.compose(identity, InsigniaPainter.warmMatrix(2)),
        InsigniaPainter.warmMatrix(2),
      );
    });

    test('rims stay within the budget in a crowded frame', () {
      final (m, scene) = bareScene();
      for (var i = 0; i < 20; i++) {
        m.demons.add(
          Demon(30 + (i % 10) * 32.0, 80 + (i ~/ 10) * 40.0, 2, 3, i * .3)
            ..nearness = 1
            ..hp = 1,
        );
      }
      paintMarks(scene);
      expect(scene.rimCount, InsigniaPainter.maxRims);
    });
  });

  // Performance (design §7): one drawAtlas per frame for every glyph and
  // cell, and a bounded cost over a full combat frame.
  testWidgets('one drawAtlas per frame; bounded cost at the active cap', (
    tester,
  ) async {
    await tester.runAsync(() async {
      final (m, scene) = bareScene();
      scene.atlas = await decodeAsset('assets/images/combat.png');
      scene.effectsAtlas = await decodeAsset(
        'assets/images/sentinel-effects.png',
      );
      final glyphs = await decodeAsset('assets/images/${InsigniaAtlas.file}');
      for (var i = 0; i < ArcadeModel.maxActiveDemons; i++) {
        m.demons.add(
          Demon(
              20 + (i % 10) * 34.0,
              60 + (i ~/ 10) * 36.0,
              i % 4,
              1 + i % 5,
              i * .7,
              elite: i % 9 == 0,
            )
            ..nearness = 1
            ..hp = i % 7 == 0 ? 1 : 1 + i % 5,
        );
      }
      double cost() {
        final sw = Stopwatch()..start();
        for (var i = 0; i < 60; i++) {
          final r = ui.PictureRecorder();
          scene.paintArena(ui.Canvas(r), Vector2(360, 780));
          r.endRecording().dispose();
        }
        return sw.elapsedMicroseconds / 60;
      }

      scene.insignia.image = null;
      cost();
      final without = cost();
      scene.insignia.image = glyphs;
      cost();
      final calls = scene.insignia.drawCalls;
      final withGlyphs = cost();
      expect(scene.insignia.drawCalls - calls, 60, reason: 'one per frame');
      expect(scene.rimCount, lessThanOrEqualTo(InsigniaPainter.maxRims));
      // ignore: avoid_print
      print(
        'insignia: ${scene.insignia.lastMarks.length} marks, frame '
        '${(without / 1000).toStringAsFixed(3)} -> '
        '${(withGlyphs / 1000).toStringAsFixed(3)} ms',
      );
      expect(withGlyphs - without, lessThan(1000));
    });
  });
}
