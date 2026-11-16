import 'package:demon_attack/game/boss_atlas.dart';
import 'package:demon_attack/game/carrier_gates.dart';
import 'package:flutter_test/flutter_test.dart';

/// carrier-v3-render: every packed carrier carries the re-render's data
/// (plan/render-runs/carrier-v3.md): one stored view, the door layers of its
/// gates, the vortex points, its data page (field texture, height grids,
/// fracture chunks) and a resident page under 16 MB.
void main() {
  const tours = {
    'carrier1-thorn': 0,
    'carrier1-lattice': 0,
    'carrier1-shroud': 0,
    'carrier2-thorn': 1,
    'carrier3-lattice': 2,
    'carrier4-shroud': 3,
    'carrier5-thorn': 4,
  };

  test('every carrier has its gates, doors, vortex points and data page', () {
    for (final MapEntry(key: key, value: route) in tours.entries) {
      final h = BossHeroAtlas.hulls[key];
      expect(h, isNotNull, reason: key);
      expect(h!.residentBytes, lessThanOrEqualTo(16 << 20), reason: key);
      final v = h.views['p45_y+00']!;
      expect(v.vortex, isNotEmpty, reason: '$key vortex points');
      for (final g in CarrierGates.forTour(route)) {
        final inst = h.gates[g.id];
        expect(inst, isNotNull, reason: '$key gate ${g.id}');
        if (inst!.startsWith('gate_bay')) continue; // the deck's own hatches
        final id = v.doors.containsKey(inst)
            ? inst
            : '${inst.substring(0, inst.length - 1)}R';
        expect(v.doors[id]?.first, isNotNull, reason: '$key door $inst');
      }
      final d = h.data;
      expect(d, isNotNull, reason: '$key data page');
      expect(d!.heights.containsKey('carapace'), isTrue, reason: key);
      expect(d.chunks, isNotNull, reason: key);
      expect(d.chunkCentres.length, greaterThan(12), reason: key);
      // the grids lie on the page
      for (final gr in [d.field, ...d.heights.values]) {
        expect(gr.x + gr.w, lessThanOrEqualTo(d.w), reason: key);
        expect(gr.y + gr.h, lessThanOrEqualTo(d.h), reason: key);
      }
    }
  });
}
