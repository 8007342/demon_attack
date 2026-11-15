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
  int shotsAimed = 0, aimedHit = 0;
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
    'aimed': shotsAimed,
    'aimedHit': aimedHit,
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
  final _aimed = Expando<bool>('aimed');
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
    final targets = m.boss != null || m.demons.any((d) => !d.entering);
    for (final s in now) {
      if (_live.contains(s)) continue;
      w.shotsFired++;
      // Aimed: fired while something could be hit (the stream's arrivals
      // and lulls are dead time the auto-fire spends either way).
      if (targets) {
        _aimed[s] = true;
        w.shotsAimed++;
      }
    }
    for (final s in _live) {
      if (now.contains(s)) continue;
      // A hit parks the shot below the arena (y = height + 20) before it is
      // removed; a miss leaves through the top or a side.
      final hit =
          s.y > ArcadeModel.height ||
          (s.y >= -10 && s.x >= -10 && s.x <= ArcadeModel.width + 10);
      if (hit) w.shotsHit++;
      if (hit && _aimed[s] != null) w.aimedHit++;
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
        final aimed = waves.fold<int>(0, (a, r) => a + r.shotsAimed);
        final aimedHit = waves.fold<int>(0, (a, r) => a + r.aimedHit);
        out.add(
          SectorSummary(
            mode,
            sector,
            waves.length,
            waves.fold<double>(0, (a, r) => a + r.combatSeconds) / waves.length,
            waves.fold<double>(0, (a, r) => a + r.wallSeconds) / waves.length,
            fired == 0 ? 0 : hit / fired,
            aimed == 0 ? 0 : aimedHit / aimed,
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
        '| Mode | Sector | Waves | Mean clear (s) | Mean wall (s) | Hit ratio | Aimed hit | Peak active | Peak hostile | Lives lost |',
      )
      ..writeln('|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|');
    for (final s in summary()) {
      b.writeln(
        '| ${s.mode} | ${s.sector} | ${s.waves} | '
        '${s.meanClear.toStringAsFixed(2)} | ${s.meanWall.toStringAsFixed(2)} | '
        '${(s.hitRatio * 100).toStringAsFixed(1)} % | '
        '${(s.aimedRatio * 100).toStringAsFixed(1)} % | ${s.peakActive} | '
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
    this.meanWall,
    this.hitRatio,
    this.aimedRatio,
    this.peakActive,
    this.peakHostile,
    this.livesLost,
  );
  final String mode;
  final int sector, waves, peakActive, peakHostile, livesLost;
  final double meanClear, meanWall, hitRatio, aimedRatio;
}

// --- demon-intelligence task 7.1 (design §9): per-tier hit ratio and
// evasions, dive and rush outcomes, the skill trajectory. Written so the
// same recorder also runs on the pre-W4 model (new fields read through
// `dynamic`, absent ones count as nothing), for the before/after table.

/// The tier of [d] by what it is (demon-intelligence design §4).
String tierName(Demon d) => d.isLarge
    ? 'T3'
    : d.elite
    ? 'T2'
    : (d.kind >= 2 || d.maxHp >= 3)
    ? 'T1'
    : 'T0';

class TierStats {
  int fired = 0, hit = 0, evasions = 0;
  int dives = 0, diveHitShip = 0, diveDodged = 0, diveShotDown = 0;
  double get hitRatio => fired == 0 ? 0 : hit / fired;
}

class IntelMetrics {
  /// Per (mode, route ≥ 1?) bucket, then tier.
  final tiers = <String, Map<String, TierStats>>{};
  final rush = <String, Map<String, int>>{};
  final skill = <String, List<double>>{};
  final combatSeconds = <String, double>{};
  final _target = Expando<String>('tier');
  final _evading = Expando<bool>('evading');
  final _diving = Expando<bool>('diving');
  final _touched = Expando<bool>('touched');
  final _rushing = Expando<bool>('rushing');
  final _contact = Expando<bool>('contact');
  final _live = <Shot>{};
  final _demons = <Demon>{};
  int _wave = -1, _kills = 0;

  static String bucket(ArcadeModel m) =>
      '${m.difficulty.name}/${m.cycle == 0 ? 'r0' : 'r1+'}';

  TierStats _t(String b, String tier) =>
      (tiers[b] ??= {})[tier] ??= TierStats();
  void _r(String b, String k) => (rush[b] ??= {})[k] = (rush[b]?[k] ?? 0) + 1;

  void observe(ArcadeModel m, double dt) {
    final b = bucket(m);
    if (m.combat) combatSeconds[b] = (combatSeconds[b] ?? 0) + dt;
    // Shots: attributed to the tier the pilot aims at when fired.
    final aim = m.demons.where((d) => !d.entering).firstOrNull;
    final now = <Shot>{
      for (final s in m.shots)
        if (!s.hostile) s,
    };
    for (final s in now) {
      if (_live.contains(s) || aim == null) continue;
      _target[s] = tierName(aim);
      _t(b, tierName(aim)).fired++;
    }
    for (final s in _live) {
      if (now.contains(s)) continue;
      final tier = _target[s];
      if (tier == null) continue;
      final hit =
          s.y > ArcadeModel.height ||
          (s.y >= -10 && s.x >= -10 && s.x <= ArcadeModel.width + 10);
      if (hit) _t(b, tier).hit++;
    }
    _live
      ..clear()
      ..addAll(now);
    // Evasions, dives and rushes.
    final killed = m.kills > _kills;
    _kills = m.kills;
    for (final d in _demons) {
      if (m.demons.contains(d)) continue;
      final tier = tierName(d);
      if (_diving[d] == true) {
        if (_touched[d] == true) {
          _t(b, tier).diveHitShip++;
        } else {
          _t(b, tier).diveShotDown++;
        }
      }
      if (_rushing[d] == true) {
        _r(b, _contact[d] == true ? 'passHit' : 'passEnded');
      }
      if (d.isLarge && _lastStand(d)) _r(b, killed ? 'shotDown' : 'sacrificed');
    }
    _demons
      ..clear()
      ..addAll(m.demons);
    for (final d in m.demons) {
      final tier = tierName(d);
      final evading = d.evadeLeft > 0;
      if (evading && _evading[d] != true) _t(b, tier).evasions++;
      _evading[d] = evading;
      final contact =
          (d.x - m.shipX).abs() < d.contactHalf &&
          (d.y - ArcadeModel.shipY).abs() < d.contactHalf;
      if (!d.isLarge) {
        final diving = d.dive > 0;
        if (diving && _diving[d] != true) {
          _t(b, tier).dives++;
          _touched[d] = false;
        }
        if (diving && contact) _touched[d] = true;
        if (!diving && _diving[d] == true) {
          _touched[d] == true
              ? _t(b, tier).diveHitShip++
              : _t(b, tier).diveDodged++;
        }
        _diving[d] = diving;
      } else {
        final rushing = d.rushing;
        if (rushing && _rushing[d] != true) {
          _r(b, 'passes');
          _contact[d] = false;
        }
        if (rushing && contact) _contact[d] = true;
        if (!rushing && _rushing[d] == true) {
          _r(b, _contact[d] == true ? 'passHit' : 'passDodged');
        }
        _rushing[d] = rushing;
      }
    }
    // Skill: sampled once per wave.
    final key = m.cycle * 100 + m.level * 10 + m.wave;
    if (key != _wave) {
      _wave = key;
      final s = _skill(m);
      if (s != null) (skill[b] ??= []).add(s);
    }
  }

  void observeEvents(List<GameEvent> events, ArcadeModel m) {
    for (final e in events) {
      if (e.name == 'rushShieldBroken') _r(bucket(m), 'shieldBroken');
      if (e.name == 'sentinelRushTell') _r(bucket(m), 'tells');
    }
  }

  static bool _lastStand(Demon d) => d.lastStand;
  static double? _skill(ArcadeModel m) {
    try {
      return ((m as dynamic).skill.level as num).toDouble();
    } on NoSuchMethodError {
      return null;
    }
  }

  Map<String, Object?> toJson() => {
    for (final b in tiers.keys.toList()..sort())
      b: {
        'combatMinutes': (combatSeconds[b] ?? 0) / 60,
        'tiers': {
          for (final e in tiers[b]!.entries)
            e.key: {
              'fired': e.value.fired,
              'hit': e.value.hit,
              'hitRatio': e.value.hitRatio,
              'evasionsPerMin':
                  e.value.evasions /
                  math.max(1e-9, (combatSeconds[b] ?? 0) / 60),
              'dives': e.value.dives,
              'diveHitShip': e.value.diveHitShip,
              'diveDodged': e.value.diveDodged,
              'diveShotDown': e.value.diveShotDown,
            },
        },
        'rush': rush[b] ?? const {},
        'skillMean': (skill[b]?.isEmpty ?? true)
            ? null
            : skill[b]!.reduce((a, c) => a + c) / skill[b]!.length,
        'skillMax': (skill[b]?.isEmpty ?? true)
            ? null
            : skill[b]!.reduce(math.max),
      },
  };
}
