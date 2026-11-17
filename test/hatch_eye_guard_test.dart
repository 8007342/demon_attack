import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:demon_attack/game/carrier_gates.dart';
import 'package:demon_attack/game/carrier_hatch_painter.dart';
import 'package:demon_attack/game/model.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// hatch-emergence design §1.7, the head-reading guard
/// (docs/styleguide/alien-capital-ships.md §3.4, §3.8): a hatch at rest must
/// not read as an eye. The hatch is drawn over the hull tone, area-averaged
/// to a 24 × 24 glance (size and detail removed, as the eye sees it at phone
/// scale) and scored two ways, each under its ceiling:
///
/// - **eye**: the Pearson correlation of its luminance with a reptile-eye
///   template (a bright almond iris, a dark vertical slit, a ring, a socket);
/// - **concentric**: the share of its luminance variance that rings about
///   its centre explain (an iris, a socket and a round field score high; a
///   tall slot between two tusks scores low).
///
/// The first draft (an amber almond with a slit inside a round field ring
/// and a round vignette) scored eye 0.53–0.58 and concentric 0.63–0.67; the
/// redesign (a ragged slot between two tusks, an open U field, a downward
/// spill) scores 0.21–0.22 and 0.36–0.41 (design §1.7).
const _n = 24;
const _window = 72.0; // arena units round the hatch
const eyeCeiling = .35, concentricCeiling = .45;

/// The reptile-eye template on the glance grid (window coordinates −1..1).
List<double> reptileEye() => [
  for (var j = 0; j < _n; j++)
    for (var i = 0; i < _n; i++)
      () {
        final x = (i + .5) / _n * 2 - 1, y = (j + .5) / _n * 2 - 1;
        final r = math.sqrt(x * x + y * y);
        final almond = (x / .27) * (x / .27) + (y / .53) * (y / .53) <= 1;
        if (almond) return x.abs() < .05 ? 0.0 : 1.0; // iris, slit pupil
        if (r < .62) return .25; // the dark sclera round the iris
        if (r < .74) return .9; // the bright ring
        if (r < 1) return .1; // the socket
        return .35; // the face round it
      }(),
];

double pearson(List<double> a, List<double> b) {
  final ma = a.reduce((p, q) => p + q) / a.length;
  final mb = b.reduce((p, q) => p + q) / b.length;
  var s = 0.0, va = 0.0, vb = 0.0;
  for (var i = 0; i < a.length; i++) {
    s += (a[i] - ma) * (b[i] - mb);
    va += (a[i] - ma) * (a[i] - ma);
    vb += (b[i] - mb) * (b[i] - mb);
  }
  return va == 0 || vb == 0 ? 0 : s / math.sqrt(va * vb);
}

/// R² of the best radial model (one mean per ring of the glance).
double concentric(List<double> g) {
  const rings = 8;
  final sum = List.filled(rings, 0.0), cnt = List.filled(rings, 0);
  int ring(int i, int j) {
    final x = (i + .5) / _n * 2 - 1, y = (j + .5) / _n * 2 - 1;
    return (math.sqrt(x * x + y * y) / math.sqrt2 * rings).floor().clamp(
      0,
      rings - 1,
    );
  }

  for (var j = 0; j < _n; j++) {
    for (var i = 0; i < _n; i++) {
      final k = ring(i, j);
      sum[k] += g[j * _n + i];
      cnt[k]++;
    }
  }
  final mean = g.reduce((a, b) => a + b) / g.length;
  var tot = 0.0, res = 0.0;
  for (var j = 0; j < _n; j++) {
    for (var i = 0; i < _n; i++) {
      final v = g[j * _n + i], k = ring(i, j);
      tot += (v - mean) * (v - mean);
      res += (v - sum[k] / cnt[k]) * (v - sum[k] / cnt[k]);
    }
  }
  return tot == 0 ? 0 : 1 - res / tot;
}

/// Draws hatch u1R of tour 1 at rest ([state], [t]) and returns its glance.
Future<List<double>> glance(GateState state, double t) async {
  const px = 4.0; // render px per unit
  final b = Carrier(0)
    ..x = 180
    ..y = 210;
  final l = CarrierLaunches(
    gates: CarrierHatches.forTour(0),
    order: const [],
    seed: 1,
  );
  l.runs[1]
    ..state = state
    ..t = t;
  final g = l.runs[1].gate;
  final painter = CarrierHatchPainter()..update(b, 3);
  final rec = ui.PictureRecorder();
  final c = ui.Canvas(rec);
  const side = _window * px;
  c.drawRect(
    const Rect.fromLTWH(0, 0, side, side),
    Paint()..color = const Color(0xFF2E2438),
  );
  c.scale(px);
  c.translate(_window / 2 - (b.x + g.x), _window / 2 - (b.y + g.y));
  painter.paintHatches(c, b, l, clock: 3, reduced: true);
  final pic = rec.endRecording();
  final img = await pic.toImage(side.round(), side.round());
  pic.dispose();
  final data = (await img.toByteData(format: ui.ImageByteFormat.rawRgba))!;
  img.dispose();
  final bytes = data.buffer.asUint8List();
  final w = side.round();
  final out = List.filled(_n * _n, 0.0);
  final cell = w / _n;
  for (var j = 0; j < _n; j++) {
    for (var i = 0; i < _n; i++) {
      var s = 0.0, k = 0;
      for (var y = (j * cell).floor(); y < ((j + 1) * cell).floor(); y++) {
        for (var x = (i * cell).floor(); x < ((i + 1) * cell).floor(); x++) {
          final o = (y * w + x) * 4;
          s +=
              (.2126 * bytes[o] + .7152 * bytes[o + 1] + .0722 * bytes[o + 2]) /
              255;
          k++;
        }
      }
      out[j * _n + i] = s / k;
    }
  }
  return out;
}

void main() {
  test('the templates score themselves (sanity)', () {
    final eye = reptileEye();
    expect(pearson(eye, eye), closeTo(1, 1e-9));
    // A round eye (a dark pupil, a lit iris, a ring) is concentric.
    final round = [
      for (var j = 0; j < _n; j++)
        for (var i = 0; i < _n; i++)
          () {
            final x = (i + .5) / _n * 2 - 1, y = (j + .5) / _n * 2 - 1;
            final r = math.sqrt(x * x + y * y);
            return r < .15 ? 0.0 : (r < .45 ? 1.0 : (r < .6 ? .2 : .5));
          }(),
    ];
    expect(concentric(round), greaterThan(concentricCeiling));
  });

  for (final (name, state, t) in [
    ('closed, live tier', GateState.closed, 0.0),
    ('telegraph', GateState.telegraph, 1.0),
    ('open', GateState.launching, 0.0),
  ]) {
    test('a hatch at rest does not read as an eye: $name', () async {
      final g = await glance(state, t);
      final eye = pearson(g, reptileEye()), conc = concentric(g);
      // ignore: avoid_print
      print(
        'HATCH_EYE_GUARD $name: eye ${eye.toStringAsFixed(2)} '
        'concentric ${conc.toStringAsFixed(2)}',
      );
      expect(eye, lessThan(eyeCeiling), reason: 'eye-template correlation');
      expect(conc, lessThan(concentricCeiling), reason: 'concentric rings');
    });
  }
}
