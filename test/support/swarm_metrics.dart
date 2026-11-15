// Campaign pilot metrics (openspec/changes/continuous-swarm tasks 1.1, 3.6,
// 5.4): per (mode, route, sector, wave) clear time, shots fired and hit,
// peak active, peak hostile bullets and lives lost. Written to
// `.cache/swarm-metrics.json` (override with SWARM_METRICS_PATH) with a
// Markdown summary next to it, for plan/calibration-current.md.
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:demon_attack/game/model.dart';

class WaveMetrics {
  WaveMetrics(this.mode, this.route, this.sector, this.wave, this.boss);
  final String mode;
  final int route, sector, wave;
  final bool boss;

  /// Seconds of combat (RunMode.playing) and of every non-paused mode
  /// while this wave was the current one.
  double combatSeconds = 0, wallSeconds = 0;
  int shotsFired = 0, shotsHit = 0, peakActive = 0, peakHostile = 0;
  int livesLost = 0;
  bool cleared = false;

  /// Total maxHp of the ordinary (non-escort) creatures this wave brought,
  /// and the combat seconds at which the next wave was triggered (the old
  /// 'incoming' event, the new 'cohortSighted'), if it was.
  int ordinaryHp = 0;
  double? triggerSeconds;

  double get hitRatio => shotsFired == 0 ? 0 : shotsHit / shotsFired;

  Map<String, Object?> toJson() => {
    'mode': mode,
    'route': route,
    'sector': sector,
    'wave': wave,
    'boss': boss,
    'clear': double.parse(combatSeconds.toStringAsFixed(3)),
    'wall': double.parse(wallSeconds.toStringAsFixed(3)),
    'fired': shotsFired,
    'hit': shotsHit,
    'peakActive': peakActive,
    'peakHostile': peakHostile,
    'livesLost': livesLost,
    'ordinaryHp': ordinaryHp,
    'trigger': triggerSeconds,
    'cleared': cleared,
  };
}

/// Observes a model after every `update`; call [observe] once per frame.
class SwarmMetrics {
  final rows = <WaveMetrics>[];
  WaveMetrics? _current;
  final _live = <Shot>{};
  final _born = Expando<bool>('born');
  int _lives = -1;

  void observe(ArcadeModel m, double dt, [List<String> events = const []]) {
    final key = (m.difficulty.name, m.cycle, m.level, m.wave);
    var w = _current;
    if (w == null || (w.mode, w.route, w.sector, w.wave) != key) {
      if (w != null) w.cleared = true;
      w = _current = WaveMetrics(
        m.difficulty.name,
        m.cycle,
        m.level,
        m.wave,
        m.boss != null,
      );
      rows.add(w);
    }
    if (m.mode != RunMode.paused) w.wallSeconds += dt;
    if (m.combat) w.combatSeconds += dt;
    // Player shots: new ones are fired; ones gone while still inside the
    // arena were consumed by a hit (demon, crate or carrier).
    final now = <Shot>{
      for (final s in m.shots)
        if (!s.hostile) s,
    };
    for (final s in now) {
      if (!_live.contains(s)) w.shotsFired++;
    }
    for (final s in _live) {
      if (now.contains(s)) continue;
      // A hit parks the shot below the arena (y = height + 20) before it is
      // removed; a miss leaves through the top or a side.
      final hit =
          s.y > ArcadeModel.height ||
          (s.y >= -10 && s.x >= -10 && s.x <= ArcadeModel.width + 10);
      if (hit) w.shotsHit++;
    }
    _live
      ..clear()
      ..addAll(now);
    w.peakActive = math.max(w.peakActive, m.demons.length);
    w.peakHostile = math.max(
      w.peakHostile,
      m.shots.where((s) => s.hostile).length,
    );
    for (final d in m.demons) {
      if (d.isLarge || d.isEscort || _born[d] != null) continue;
      _born[d] = true;
      w.ordinaryHp += d.maxHp;
    }
    if (w.triggerSeconds == null &&
        (events.contains('incoming') || events.contains('cohortSighted'))) {
      w.triggerSeconds = w.combatSeconds;
    }
    if (_lives >= 0 && m.lives < _lives) w.livesLost += _lives - m.lives;
    _lives = m.lives;
  }

  /// Per (mode, sector): mean ordinary-wave clear time, hit ratio, peaks.
  List<SectorSummary> summary() {
    final out = <SectorSummary>[];
    for (final mode in ['easy', 'normal', 'hard']) {
      for (var sector = 1; sector <= 5; sector++) {
        final waves = [
          for (final r in rows)
            if (r.mode == mode && r.sector == sector && r.cleared) r,
        ];
        if (waves.isEmpty) continue;
        final fired = waves.fold<int>(0, (a, r) => a + r.shotsFired);
        final hit = waves.fold<int>(0, (a, r) => a + r.shotsHit);
        out.add(
          SectorSummary(
            mode,
            sector,
            waves.length,
            waves.fold<double>(0, (a, r) => a + r.combatSeconds) / waves.length,
            fired == 0 ? 0 : hit / fired,
            waves.map((r) => r.peakActive).reduce(math.max),
            waves.map((r) => r.peakHostile).reduce(math.max),
            waves.fold<int>(0, (a, r) => a + r.livesLost),
          ),
        );
      }
    }
    return out;
  }

  /// The efficiency e of T_expected = 2 + HP / (4.35 e) (design §2.3)
  /// that makes the median T_actual / T_expected 1.0 for [mode]; null
  /// without triggered waves.
  double? fitEfficiency(String mode) {
    final samples = [
      for (final r in rows)
        if (r.mode == mode && !r.boss && r.triggerSeconds != null)
          (r.triggerSeconds!, r.ordinaryHp),
    ];
    if (samples.isEmpty) return null;
    double median(double e) {
      final q = [for (final (t, hp) in samples) t / (2 + hp / (4.35 * e))]
        ..sort();
      return q[q.length ~/ 2];
    }

    // The median ratio grows with e: bisect for 1.0.
    var lo = .01, hi = 5.0;
    for (var i = 0; i < 60; i++) {
      final mid = (lo + hi) / 2;
      if (median(mid) < 1) {
        lo = mid;
      } else {
        hi = mid;
      }
    }
    return (lo + hi) / 2;
  }

  String markdown() {
    final b = StringBuffer()
      ..writeln(
        '| Mode | Sector | Waves | Mean clear (s) | Hit ratio | Peak active | Peak hostile | Lives lost |',
      )
      ..writeln('|---|---:|---:|---:|---:|---:|---:|---:|');
    for (final s in summary()) {
      b.writeln(
        '| ${s.mode} | ${s.sector} | ${s.waves} | '
        '${s.meanClear.toStringAsFixed(2)} | '
        '${(s.hitRatio * 100).toStringAsFixed(1)} % | ${s.peakActive} | '
        '${s.peakHostile} | ${s.livesLost} |',
      );
    }
    for (final mode in ['easy', 'normal', 'hard']) {
      final e = fitEfficiency(mode);
      if (e != null) {
        b.writeln();
        b.writeln(
          'Fitted T_expected efficiency ($mode): ${e.toStringAsFixed(3)}',
        );
      }
    }
    return b.toString();
  }

  /// Merges [rows] into the JSON file (one key per mode, so the three
  /// campaign tests can write in any order).
  void write(String mode) {
    final path =
        Platform.environment['SWARM_METRICS_PATH'] ??
        '.cache/swarm-metrics.json';
    final file = File(path);
    file.parent.createSync(recursive: true);
    Map<String, Object?> all = {};
    if (file.existsSync()) {
      try {
        all = Map<String, Object?>.from(
          jsonDecode(file.readAsStringSync()) as Map,
        );
      } on FormatException {
        all = {};
      }
    }
    all[mode] = [for (final r in rows) r.toJson()];
    file.writeAsStringSync(const JsonEncoder.withIndent(' ').convert(all));
    File(path.replaceAll(RegExp(r'\.json$'), '-$mode.md'))
        .writeAsStringSync(markdown());
  }
}

class SectorSummary {
  SectorSummary(
    this.mode,
    this.sector,
    this.waves,
    this.meanClear,
    this.hitRatio,
    this.peakActive,
    this.peakHostile,
    this.livesLost,
  );
  final String mode;
  final int sector, waves, peakActive, peakHostile, livesLost;
  final double meanClear, hitRatio;
}
