/// Smoothed lip-sync: viseme-like mouth openness from a clip's envelope with
/// attack/release smoothing, hysteresis and a minimum hold, so the portrait
/// never flickers for a single frame.
library;

import 'dart:math' as math;

import 'comms_types.dart';

class CommsMouth {
  CommsMouth._(this.frames);

  /// One portrait frame per 1/15 s of the clip.
  final List<int> frames;
  static const fps = 15;

  /// Openness rises fast and falls slower (per 1/15 s sample).
  static const attack = .7, release = .38;

  /// A mouth shape is held at least this many samples (133 ms).
  static const minHold = 2;

  /// Openness thresholds for talkA, talkB and talkC (with hysteresis).
  static const levels = [.16, .42, .7];
  static const hysteresis = .06;

  static final _cache = <String, CommsMouth>{};

  static CommsMouth of(CommsLine line) =>
      _cache[line.id] ??= CommsMouth.build(line);

  /// Openness 0..1 per sample: the measured `open` track, else the frame
  /// track mapped to openness, else a gentle synthetic cycle.
  static List<double> openness(CommsLine line) {
    final n = math.max(1, (line.duration * fps).ceil());
    if (line.open.isNotEmpty) {
      return [
        for (var i = 0; i < n; i++)
          (line.open.codeUnitAt(math.min(i, line.open.length - 1)) - 48) / 9,
      ];
    }
    if (line.mouth.isNotEmpty) {
      const byFrame = {
        0: 0.0,
        1: 0.0,
        2: .3,
        3: .55,
        4: .85,
        5: .55,
        6: 1.0,
        7: 1.0,
      };
      return [
        for (var i = 0; i < n; i++)
          byFrame[line.mouth.codeUnitAt(math.min(i, line.mouth.length - 1)) -
                  48] ??
              0,
      ];
    }
    // No measurement: syllable-like pulses at about 4 Hz.
    return [
      for (var i = 0; i < n; i++)
        i < 1 || i >= n - 1 ? 0 : .5 + .4 * math.sin(i * 1.7 + line.id.length),
    ];
  }

  factory CommsMouth.build(CommsLine line) {
    final raw = openness(line);
    final rounded = <bool>[
      for (var i = 0; i < raw.length; i++)
        line.mouth.isNotEmpty &&
            line.mouth.codeUnitAt(math.min(i, line.mouth.length - 1)) == 53,
    ];
    // 1. attack/release envelope follower
    final smooth = <double>[];
    var s = 0.0;
    for (final v in raw) {
      s += (v - s) * (v > s ? attack : release);
      smooth.add(s);
    }
    // 2. quantise with hysteresis
    final level = <int>[];
    var current = 0;
    for (final v in smooth) {
      while (current < levels.length && v > levels[current] + hysteresis) {
        current++;
      }
      while (current > 0 && v < levels[current - 1] - hysteresis) {
        current--;
      }
      level.add(current);
    }
    // 3. minimum hold: a shape shorter than minHold samples merges into
    // its predecessor (or successor at the start).
    // The clip always ends on a closed mouth (held, too).
    for (var k = math.max(0, level.length - minHold); k < level.length; k++) {
      level[k] = 0;
    }
    if (level.length > minHold) {
      for (var pass = 0; pass < 8; pass++) {
        var changed = false;
        var i = 0;
        while (i < level.length) {
          var j = i;
          while (j < level.length && level[j] == level[i]) {
            j++;
          }
          if (j - i < minHold) {
            final fill = i > 0 ? level[i - 1] : level[j];
            for (var k = i; k < j; k++) {
              level[k] = fill;
            }
            changed = true;
          }
          i = j;
        }
        if (!changed) break;
      }
    }
    // A run of the middle opening is the rounded 'oo' shape when most of it
    // was measured rounded; the shape holds for the whole run.
    final frames = List<int>.filled(level.length, CommsFrame.idle);
    var i = 0;
    while (i < level.length) {
      var j = i;
      while (j < level.length && level[j] == level[i]) {
        j++;
      }
      final roundCount = [for (var k = i; k < j; k++) rounded[k]]
          .where((r) => r)
          .length;
      final frame = switch (level[i]) {
        0 => CommsFrame.idle,
        1 => CommsFrame.talkA,
        2 =>
          !line.isGrunt && roundCount * 2 > j - i
              ? CommsFrame.talkD
              : CommsFrame.talkB,
        _ => line.isGrunt ? CommsFrame.grunt : CommsFrame.talkC,
      };
      for (var k = i; k < j; k++) {
        frames[k] = frame;
      }
      i = j;
    }
    return CommsMouth._(frames);
  }

  int frameAt(double t) {
    if (frames.isEmpty) return CommsFrame.idle;
    final index = (t * fps).floor().clamp(0, frames.length - 1);
    return frames[index];
  }
}
