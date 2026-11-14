import 'dart:io';
import 'dart:typed_data';

import 'package:demon_attack/game/ground_blocks_atlas.dart';
import 'package:flutter_test/flutter_test.dart';

/// (width, height) from a PNG's IHDR chunk.
(int, int) _pngSize(String path) {
  final b = File(path).readAsBytesSync();
  final d = ByteData.sublistView(Uint8List.fromList(b));
  return (d.getUint32(16), d.getUint32(20));
}

void main() {
  test('cell names resolve to the block layout', () {
    final c = GroundBlocks.cell('ember', 'lodestar.hull.move.h045.f2')!;
    expect(c.file, 'ground-fleet-ember.png');
    expect(c.col, 2 * 4 + 2);
    expect((c.w, c.h), (48, 40));
    expect(GroundBlocks.cell('krybor', 'lodestar.hull.move.h045.f2'), isNull,
        reason: 'the Lodestar is not in the Krybor roster');
    final k = GroundBlocks.cell('hollow', 'chapterhouse.hull.move.h135.f0')!;
    expect(k.h, 80);
  });

  test('every placed cell lies inside its generated atlas', () {
    for (final sector in GroundBlocks.sectors) {
      final place = GroundBlocks.placement[sector]!;
      for (final MapEntry(key: id, value: (file, row0)) in place.entries) {
        final unit = GroundBlocks.units[id]!;
        final (w, h) = _pngSize('assets/images/ground-blocks/$file');
        for (final rc in GroundBlocks.layouts[unit.layout].values) {
          expect((rc.$2 + 1) * unit.cellW, lessThanOrEqualTo(w));
          final rowH = unit.block == 'K' ? unit.cellH ~/ 2 : unit.cellH;
          expect((row0 + rc.$1) * rowH + unit.cellH, lessThanOrEqualTo(h),
              reason: '$id in $file');
        }
      }
    }
  });

  test('heading sets follow the decision (5 per faction, 3 infantry/command)', () {
    for (final u in GroundBlocks.units.values) {
      final n = switch (u.block) { 'I' || 'K' => 3, _ => 5 };
      expect(u.headings.length, n, reason: u.id);
      expect(u.pivot.length, u.headings.length);
      expect(u.muzzle.length, u.angles.length);
      for (var i = 1; i < u.headings.length; i++) {
        expect(u.headings[i] > u.headings[i - 1], isTrue);
      }
    }
    expect(GroundBlocks.nearest([0, 22.5, 45, 67.5, 90], -50), (2, true));
  });
}
