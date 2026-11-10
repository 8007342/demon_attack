/// Smoothed lip-sync: mouth shapes from a clip's measured openness envelope
/// and viseme estimates, at 30 samples per second.
///
/// 1. The 1/15 s openness track is eased (linearly interpolated) to 30 Hz
///    and smoothed with a fast attack and a slower release.
/// 2. It is quantised with hysteresis into five openness levels (closed,
///    slightly open, half, open, wide).
/// 3. The level moves at most one step per sample, so the mouth always
///    passes through the in-between shapes (closed -> slight -> half ->
///    open) instead of snapping from closed to fully open.
/// 4. A level is held at least [minHold] samples unless it is part of such
///    a monotone ramp, so there is never a single-sample blip.
/// 5. Rounded ('o') and spread ('e') visemes swap the open shapes for the
///    'oo' and teeth-showing 'ee' frames for runs where most samples agree.
/// The painter cross-fades the first [blend] seconds of every change.
library;

import 'dart:math' as math;

import 'comms_types.dart';

class CommsMouth {
  CommsMouth._(this.frames, this.levels);

  /// One portrait frame per 1/[fps] s of the clip.
  final List<int> frames;

  /// The openness level (0-4) behind each frame.
  final List<int> levels;

  /// Samples per second of [frames]; the measured tracks are at [trackFps].
  static const fps = 30, trackFps = 15;

  /// Openness rises fast and falls slower (per 1/30 s sample).
  static const attack = .55, release = .28;

  /// A mouth shape is held at least this many samples (67 ms), except as a
  /// step of a monotone opening or closing ramp.
  static const minHold = 2;

  /// Openness thresholds for levels 1-4 (with hysteresis).
  static const thresholds = [.12, .3, .52, .76];
  static const hysteresis = .05;

  /// Cross-fade at the start of each new shape (seconds).
  static const blend = .03;

  static final _cache = <String, CommsMouth>{};

  static CommsMouth of(CommsLine line) =>
      _cache[line.id] ??= CommsMouth.build(line);

  static int _digit(String track, int i) =>
      track.codeUnitAt(math.min(i, track.length - 1)) - 48;

  /// Openness 0..1 per 1/15 s: the measured `open` track, else the frame
  /// track mapped to openness, else a gentle synthetic cycle.
  static List<double> openness(CommsLine line) {
    final n = math.max(1, (line.duration * trackFps).ceil());
    if (line.open.isNotEmpty) {
      return [for (var i = 0; i < n; i++) _digit(line.open, i) / 9];
    }
    if (line.mouth.isNotEmpty) {
      const byFrame = {
        CommsFrame.talkA: .2,
        CommsFrame.talkB: .4,
        CommsFrame.talkC: .62,
        CommsFrame.talkD: .45,
        CommsFrame.shout: .9,
        CommsFrame.grunt: 1.0,
        CommsFrame.talkWide: .88,
        CommsFrame.talkEe: .35,
      };
      return [
        for (var i = 0; i < n; i++) byFrame[_digit(line.mouth, i)] ?? 0.0,
      ];
    }
    // No measurement: syllable-like pulses at about 4 Hz.
    return [
      for (var i = 0; i < n; i++)
        i < 1 || i >= n - 1 ? 0 : .5 + .4 * math.sin(i * 1.7 + line.id.length),
    ];
  }

  /// Viseme per 1/15 s: 'o', 'e' or '-' (from `vis`, else the legacy
  /// rounded frames of `mouth`).
  static String _viseme(CommsLine line, int i) {
    if (line.vis.isNotEmpty) {
      return line.vis[math.min(i, line.vis.length - 1)];
    }
    if (line.mouth.isNotEmpty) {
      final f = _digit(line.mouth, i);
      if (f == CommsFrame.talkD) return 'o';
      if (f == CommsFrame.talkEe) return 'e';
    }
    return '-';
  }

  factory CommsMouth.build(CommsLine line) {
    final coarse = openness(line);
    final n = math.max(1, (line.duration * fps).ceil());
    const k = fps ~/ trackFps;
    // 1. ease the 15 Hz track to 30 Hz, then attack/release smoothing.
    final smooth = <double>[];
    var s = 0.0;
    for (var i = 0; i < n; i++) {
      final at = i / k;
      final a = at.floor().clamp(0, coarse.length - 1);
      final b = math.min(a + 1, coarse.length - 1);
      final v = coarse[a] + (coarse[b] - coarse[a]) * (at - at.floor());
      s += (v - s) * (v > s ? attack : release);
      smooth.add(s);
    }
    // 2. quantise with hysteresis; 3. at most one level per sample.
    final level = <int>[];
    var target = 0, current = 0;
    for (final v in smooth) {
      while (target < thresholds.length &&
          v > thresholds[target] + hysteresis) {
        target++;
      }
      while (target > 0 && v < thresholds[target - 1] - hysteresis) {
        target--;
      }
      current += (target - current).sign;
      level.add(current);
    }
    // The clip always ends on a closed mouth, closing step by step.
    for (var i = level.length - 1, cap = 0; i >= 0; i--, cap++) {
      if (level[i] <= cap) break;
      level[i] = cap;
    }
    // 4. no blips (also where the closing ramp met the line): a run
    // shorter than minHold inside the clip that is not a
    // step of a monotone ramp takes its predecessor's level.
    for (var pass = 0; pass < 8; pass++) {
      var changed = false;
      for (final (i, j) in _runs(level).toList()) {
        if (j - i >= minHold || i == 0 || j == level.length) continue;
        final before = level[i - 1], after = level[j];
        if ((before - level[i]).sign == (level[i] - after).sign) continue;
        for (var q = i; q < j; q++) {
          level[q] = before;
        }
        changed = true;
      }
      if (!changed) break;
    }
    // 5. shapes: a run of an open level is the rounded 'oo' or the spread
    // 'ee' when most of it was measured so (demons keep fangs: no 'oo',
    // and the loudest moments of a grunt are the roar frame).
    final frames = List<int>.filled(level.length, CommsFrame.idle);
    for (final (i, j) in _runs(level)) {
      final l = level[i];
      var o = 0, e = 0, loud = 0;
      for (var q = i; q < j; q++) {
        final c = _viseme(line, q ~/ k);
        if (c == 'o') o++;
        if (c == 'e') e++;
        if (smooth[q] >= .93) loud++;
      }
      var frame = CommsFrame.byLevel[l];
      if (line.isGrunt) {
        if (l == 4 && loud * 2 >= j - i) frame = CommsFrame.grunt;
      } else if (l >= 1 && l <= 3 && o * 2 > j - i) {
        frame = CommsFrame.talkD;
      } else if (l >= 1 && l <= 3 && e * 2 > j - i) {
        frame = CommsFrame.talkEe;
      }
      for (var q = i; q < j; q++) {
        frames[q] = frame;
      }
    }
    return CommsMouth._(frames, level);
  }

  static Iterable<(int, int)> _runs(List<int> values) sync* {
    var i = 0;
    while (i < values.length) {
      var j = i;
      while (j < values.length && values[j] == values[i]) {
        j++;
      }
      yield (i, j);
      i = j;
    }
  }

  int _index(double t) => (t * fps).floor().clamp(0, frames.length - 1);

  int frameAt(double t) => frames.isEmpty ? CommsFrame.idle : frames[_index(t)];

  /// The shape before the current one and how far (0..1) the cross-fade
  /// into the current shape has come at [t]: 1 once [blend] has passed.
  (int from, int to, double amount) blendAt(double t) {
    if (frames.isEmpty) return (CommsFrame.idle, CommsFrame.idle, 1);
    final i = _index(t);
    final to = frames[i];
    if (i == 0 || frames[i - 1] == to) return (to, to, 1);
    final into = t - i / fps;
    return (frames[i - 1], to, (into / blend).clamp(0.0, 1.0).toDouble());
  }
}
