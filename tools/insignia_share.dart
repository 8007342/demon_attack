// insignia-ranks: how many of the creatures on screen wear a mark, and
// how many wear a fang, wave by wave, before (every rank above the drone,
// all fang marks) and after (lib/game/insignia_rank.dart).
//
//   dart run tools/insignia_share.dart [out-dir]
//
// Writes <out-dir>/insignia-share.md (the table in
// plan/render-runs/insignia-ranks.md) and <out-dir>/sample-waves.json (two
// mid-wave frames for the Go contact sheet: `go run . ranks`). Headless:
// the model only, no dart:ui. It drives the real model the way
// tools/analyze_difficulty.dart does (seed 1982, controlled casualties
// when admission stalls); the share is sampled every quarter second over
// the creatures in the fight (not the fog reserve, not a waiting sentinel).
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:demon_attack/game/insignia_rank.dart';
import 'package:demon_attack/game/model.dart';

bool onScreen(Demon d) =>
    d.swarmState != SwarmState.reserve &&
    d.swarmState != SwarmState.approaching &&
    !(d.isLarge && d.waitingForEscort) &&
    d.y > 0;

/// The mark before this change: every rank above the drone wore one, and
/// every one of them carried a fang (fang, twin fangs, winged fang, winged
/// crown).
bool oldMarked(Demon d) => lightningRank(d) > 0;

class WaveShare {
  WaveShare(this.mode, this.route, this.sector, this.wave);
  final Difficulty mode;
  final int route, sector, wave;
  int samples = 0;
  double marked = 0, fang = 0, old = 0;

  /// Creature-samples: on screen, marked, fanged, marked before.
  int seenN = 0, seenMarked = 0, seenFang = 0, seenOld = 0;
  double peakMarked = 0, peakFang = 0, peakOld = 0;
  int births = 0, birthsMarked = 0, birthsFang = 0, birthsOld = 0;
  final Map<RankMark, int> byMark = {for (final m in RankMark.values) m: 0};

  // The wave's share: marked creature-samples over all creature-samples
  // (a wave's thin tail of three survivors weighs what it shows).
  double get meanMarked => seenN == 0 ? 0 : seenMarked / seenN;
  double get meanFang => seenN == 0 ? 0 : seenFang / seenN;
  double get meanOld => seenN == 0 ? 0 : seenOld / seenN;
}

Map<String, Object?> snapshot(ArcadeModel m, String label) => {
  'label': label,
  'width': ArcadeModel.width,
  'height': ArcadeModel.height,
  'demons': [
    for (final d in m.demons.where(onScreen))
      {
        'x': d.x,
        'y': d.y,
        'kind': d.kind,
        'large': d.isLarge,
        'old': lightningRank(d),
        'mark': InsigniaRanks.markOf(d).name,
      },
  ],
};

WaveShare measure(
  Difficulty mode,
  int route,
  int sector,
  int wave, {
  void Function(ArcadeModel m, int frame)? peek,
}) {
  final s = WaveShare(mode, route, sector, wave);
  final m = ArcadeModel(seed: 1982)
    ..restoreCheckpoint({
      'difficulty': mode.name,
      'routeIndex': route,
      'sector': sector,
      'wave': wave,
    });
  m.mode = RunMode.playing;
  m.invulnerable = 100000;
  final seen = <Demon>{};
  final needsEscort = m.demons.any((d) => d.isLarge);
  var lastArrival = 0;
  void born(Iterable<Demon> ds) {
    for (final d in ds) {
      if (!seen.add(d)) continue;
      final mark = InsigniaRanks.markOf(d);
      s.births++;
      s.byMark[mark] = s.byMark[mark]! + 1;
      if (mark != RankMark.none) s.birthsMarked++;
      if (InsigniaRanks.hasFang(mark)) s.birthsFang++;
      if (oldMarked(d)) s.birthsOld++;
    }
  }

  born(m.demons);
  // Bounded: at most 2 minutes of play per wave (never an open loop).
  for (var frame = 0; frame < 7200; frame++) {
    if (m.flocksRemaining == 0 &&
        (!needsEscort || m.escortSpawned) &&
        m.demons.where((d) => !d.isLarge).length < 3) {
      break;
    }
    if (frame % 15 == 0) {
      final live = m.demons.where(onScreen).toList();
      if (live.length >= 3) {
        final marks = live.map(InsigniaRanks.markOf).toList();
        final mk = marks.where((k) => k != RankMark.none).length / live.length;
        final fg = marks.where(InsigniaRanks.hasFang).length / live.length;
        final od = live.where(oldMarked).length / live.length;
        s
          ..seenN += live.length
          ..seenMarked += marks.where((k) => k != RankMark.none).length
          ..seenFang += marks.where(InsigniaRanks.hasFang).length
          ..seenOld += live.where(oldMarked).length
          ..samples += 1
          ..marked += mk
          ..fang += fg
          ..old += od;
        // Peaks only over a real formation (six or more in the fight).
        if (live.length >= 6) {
          s
            ..peakMarked = math.max(s.peakMarked, mk)
            ..peakFang = math.max(s.peakFang, fg)
            ..peakOld = math.max(s.peakOld, od);
        }
      }
      peek?.call(m, frame);
    }
    // Let waves fill naturally; when admission stalls, make controlled
    // casualties (one creature at a time, a bounded number of hits).
    if (frame - lastArrival > 150 && frame % 30 == 0) {
      final victim = m.demons
          .where((d) => !d.isLarge && onScreen(d))
          .firstOrNull;
      if (victim != null) {
        for (var i = 0; i < 64 && m.demons.contains(victim); i++) {
          m.hitDemon(victim, damage: 100000);
        }
      }
    }
    m.update(1 / 60);
    m.shots.removeWhere((x) => !x.hostile);
    final before = seen.length;
    born(m.demons);
    if (seen.length > before) lastArrival = frame;
  }
  return s;
}

String pct(double v) => '${(v * 100).toStringAsFixed(1)} %';

void main(List<String> args) {
  final out = Directory(args.isEmpty ? '.' : args.first)
    ..createSync(recursive: true);
  final rows = <WaveShare>[];
  final samples = <Map<String, Object?>>[];
  for (final mode in [Difficulty.normal, Difficulty.hard]) {
    for (var route = 0; route < 5; route++) {
      for (var sector = 1; sector <= 4; sector++) {
        final waves = ArcadeModel.wavesFor(sector: sector, route: route);
        for (var wave = 1; wave <= waves; wave++) {
          // The two sample frames: the fang-heaviest wave of the old
          // ladder (tour 1, sector 4) and a tour-3 wave with elites and an
          // escort, both at 12 s.
          final want =
              mode == Difficulty.normal &&
              ((route == 0 && sector == 4 && wave == 2) ||
                  (route == 2 && sector == 3 && wave == 3));
          rows.add(
            measure(
              mode,
              route,
              sector,
              wave,
              peek: want
                  ? (m, frame) {
                      if (frame == 720) {
                        samples.add(
                          snapshot(
                            m,
                            'TOUR ${route + 1} SECTOR $sector WAVE $wave '
                            '(${mode.name.toUpperCase()}, 12 S)',
                          ),
                        );
                      }
                    }
                  : null,
            ),
          );
        }
      }
    }
  }
  final md = StringBuffer()
    ..writeln('# Insignia share per wave (tools/insignia_share.dart)')
    ..writeln()
    ..writeln(
      'Seed 1982. The share of the creatures in the fight that wear a mark '
      '(and a fang). A wave\'s share counts creature-samples (every creature '
      'in the fight, every 0.25 s); "mean" averages the tour\'s waves, '
      '"worst wave" is its highest wave, and "peak" is the worst single '
      'sample with six or more creatures in the fight. Old: every rank above '
      'the drone wore a fang mark. New: lib/game/insignia_rank.dart (elite '
      'grunts: species 2-3, 1 in ${InsigniaRanks.eliteGruntOneIn}).',
    )
    ..writeln()
    ..writeln(
      '| Mode | Tour | Waves | Old marked (mean / worst wave / peak) '
      '| New marked (mean / worst wave / peak) '
      '| New fang (mean / worst wave / peak) | Births: winglet / crownlet / '
      'fang-and-wings / winged crown / none |',
    )
    ..writeln('|---|---:|---:|---|---|---|---|');
  for (final mode in [Difficulty.normal, Difficulty.hard]) {
    for (var route = 0; route < 5; route++) {
      final r = rows
          .where((w) => w.mode == mode && w.route == route && w.samples > 0)
          .toList();
      double mean(double Function(WaveShare) f) =>
          r.fold<double>(0, (a, w) => a + f(w)) / r.length;
      double worst(double Function(WaveShare) f) => r.map(f).reduce(math.max);
      int sum(RankMark k) => r.fold<int>(0, (a, w) => a + w.byMark[k]!);
      md.writeln(
        '| ${mode.name} | ${route + 1} | ${r.length} '
        '| ${pct(mean((w) => w.meanOld))} / ${pct(worst((w) => w.meanOld))} / ${pct(worst((w) => w.peakOld))} '
        '| ${pct(mean((w) => w.meanMarked))} / ${pct(worst((w) => w.meanMarked))} / ${pct(worst((w) => w.peakMarked))} '
        '| ${pct(mean((w) => w.meanFang))} / ${pct(worst((w) => w.meanFang))} / ${pct(worst((w) => w.peakFang))} '
        '| ${sum(RankMark.winglet)} / ${sum(RankMark.crownlet)} / '
        '${sum(RankMark.fangWings)} / ${sum(RankMark.wingCrown)} / '
        '${sum(RankMark.none)} |',
      );
    }
  }
  final all = rows.where((w) => w.samples > 0).toList();
  double worstAll(double Function(WaveShare) f) => all.map(f).reduce(math.max);
  md
    ..writeln()
    ..writeln(
      'Worst wave mean, all ${all.length} waves: old marked '
      '${pct(worstAll((w) => w.meanOld))}; new marked '
      '${pct(worstAll((w) => w.meanMarked))}; new fang '
      '${pct(worstAll((w) => w.meanFang))}.',
    );
  File('${out.path}/insignia-share.md').writeAsStringSync(md.toString());
  File('${out.path}/sample-waves.json')
      .writeAsStringSync(const JsonEncoder.withIndent(' ').convert(samples));
  stdout.write(md);
}
