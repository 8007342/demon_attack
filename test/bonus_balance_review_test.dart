// bonus-balance review sheets. Off by default;
// `--dart-define=BONUS_BALANCE_CONTACT=true` writes
// - art/contact/bonus-balance-medal-screen.png: the arcade page at 360 x 780
//   at the end of a bonus run under a run rule: the initials entry with the
//   run record card, and the board (records with their date-and-modifiers
//   line) with the final-score card;
// - art/contact/bonus-balance-timeline.png: kills over combat time, the
//   protected calibration pilot, for a regular sector, its Supply Run as
//   balanced, and the Supply Run as first built (two thin waves), on Easy
//   route 0 sector 2 (where the operator met a three-second level) and on
//   Normal route 0 sector 3.
// `BONUS_BALANCE_FONTS` names a folder with Roboto-Regular.ttf and
// Roboto-Bold.ttf for real glyphs.
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:demon_attack/game/model.dart';
import 'package:demon_attack/main.dart';
import 'package:demon_attack/services/scores.dart';
import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'campaign_playtest_test.dart' show steer;
import 'progression_test.dart' show clearWave;
import 'run_record_test.dart' show seedWithLevelAndModifier;
import 'support/bonus_balance.dart' show chaseCrate;

const _contact = bool.fromEnvironment('BONUS_BALANCE_CONTACT');
const _fonts = String.fromEnvironment(
  'BONUS_BALANCE_FONTS',
  defaultValue: '/home/forge/.cache/tillandsias-project/tmp/fonts',
);

/// Supply Run as first built (bonus-levels, before bonus-balance).
const _supplyRunV1 = BonusLevelDef(
  id: 'supplyRun',
  label: 'SUPPLY RUN',
  weight: 1,
  waves: BonusWaves(
    count: 2,
    rosterScale: .6,
    reinforcementScale: .5,
    sentinels: false,
    elites: false,
    maxKind: 1,
  ),
  rules: PowerRules(killDrops: false),
  crates: BonusCrates(
    every: 4.5,
    first: 1.5,
    max: 3,
    total: 8,
    points: 150,
    powers: [Power.spread, Power.rapid, Power.shield, Power.powerful],
    bonusPowers: ['salvageMagnet', 'doubleScore'],
    bonusPowerChance: .3,
  ),
  scoring: BonusScoring(clearPar: 1, flawlessPar: .3, capPar: 1.5),
);

Future<void> _loadFonts() async {
  final dir = Directory(_fonts);
  if (!dir.existsSync()) return;
  for (final family in ['Roboto', 'monospace']) {
    final loader = FontLoader(family);
    for (final f in ['Roboto-Regular.ttf', 'Roboto-Bold.ttf']) {
      final bytes = File('${dir.path}/$f').readAsBytesSync();
      loader.addFont(Future.value(ByteData.sublistView(bytes)));
    }
    await loader.load();
  }
}

Future<void> _sheet(String path, List<ui.Image> frames) async {
  const gap = 8.0;
  final w = frames.fold<double>(gap, (a, f) => a + f.width + gap);
  var h = 0.0;
  for (final f in frames) {
    if (f.height > h) h = f.height.toDouble();
  }
  final rec = ui.PictureRecorder();
  final c = Canvas(rec);
  c.drawRect(
    Rect.fromLTWH(0, 0, w, h + gap * 2),
    Paint()..color = const Color(0xFF2A2F3A),
  );
  var x = gap;
  for (final f in frames) {
    c.drawImage(f, Offset(x, gap), Paint());
    x += f.width + gap;
  }
  final sheet = await rec.endRecording().toImage(
    w.round(),
    (h + gap * 2).round(),
  );
  final png = await sheet.toByteData(format: ui.ImageByteFormat.png);
  File(path)
    ..createSync(recursive: true)
    ..writeAsBytesSync(png!.buffer.asUint8List());
}

// --- the timeline

typedef _Trace = ({String name, List<Offset> points, bool dashed});

/// Kills over combat seconds from the sector's first combat frame. The run
/// reaches the sector through the previous one (cleared by force), so the
/// first-built level can be planned into it; powers are dropped on arrival.
_Trace _trace(
  String name,
  Difficulty d,
  int sector,
  BonusLevelDef? level, {
  bool dashed = false,
}) {
  final m = ArcadeModel(seed: 1982)
    ..startAt(difficulty: d, sector: sector - 1, runSeed: 1982);
  m.bonusRun.plan = level == null
      ? BonusPlan.none
      : BonusPlan.forced(level, route: 0, sector: sector);
  for (var f = 0; f < 60 * 120 && m.level < sector; f++) {
    if (m.combat) {
      clearWave(m);
    } else {
      m.update(1 / 60);
    }
  }
  for (var f = 0; f < 60 * 30 && !m.combat; f++) {
    m.update(1 / 60);
  }
  expect(m.level, sector);
  expect(m.bonus?.waves.count, level?.waves.count);
  m.powerTimers.clear();
  final base = m.kills;
  final points = <Offset>[Offset.zero];
  var t = 0.0;
  for (var f = 0; f < 60 * 400 && m.mode != RunMode.salvage; f++) {
    if (m.combat) {
      m.invulnerable = 2;
      steer(m, oracle: false);
      chaseCrate(m);
      t += 1 / 60;
    }
    final before = m.kills;
    m.update(1 / 60);
    m.takeEvents();
    m.takeGameEvents();
    if (m.kills != before) points.add(Offset(t, (m.kills - base) * 1.0));
  }
  return (name: name, points: points, dashed: dashed);
}

void _text(
  Canvas c,
  String s,
  Offset at, {
  Color color = const Color(0xFFB8C4D0),
  double size = 13,
  bool right = false,
  bool bold = false,
}) {
  final b =
      ui.ParagraphBuilder(
          ui.ParagraphStyle(
            fontFamily: 'Roboto',
            fontSize: size,
            fontWeight: bold ? FontWeight.bold : FontWeight.normal,
          ),
        )
        ..pushStyle(ui.TextStyle(color: color))
        ..addText(s);
  final p = b.build()..layout(const ui.ParagraphConstraints(width: 600));
  final w = p.longestLine;
  c.drawParagraph(p, right ? at - Offset(w, 0) : at);
}

/// One panel: kills (y) over combat seconds (x), one 2 px line per trace.
void _panel(Canvas c, Rect r, String title, List<_Trace> traces) {
  const colors = [Color(0xFF3987E5), Color(0xFFD95926), Color(0xFF199E70)];
  c.drawRect(r, Paint()..color = const Color(0xFF1A1A19));
  _text(c, title, r.topLeft + const Offset(16, 12), size: 15, bold: true);
  final plot = Rect.fromLTRB(
    r.left + 56,
    r.top + 48,
    r.right - 150,
    r.bottom - 44,
  );
  var maxT = 10.0, maxK = 10.0;
  for (final t in traces) {
    for (final p in t.points) {
      if (p.dx > maxT) maxT = p.dx;
      if (p.dy > maxK) maxK = p.dy;
    }
  }
  maxT = (maxT / 10).ceil() * 10.0;
  maxK = (maxK / 20).ceil() * 20.0;
  Offset at(Offset p) => Offset(
    plot.left + p.dx / maxT * plot.width,
    plot.bottom - p.dy / maxK * plot.height,
  );
  final grid = Paint()
    ..color = const Color(0xFF34343A)
    ..strokeWidth = 1;
  for (var k = 0.0; k <= maxK; k += 20) {
    final y = at(Offset(0, k)).dy;
    c.drawLine(Offset(plot.left, y), Offset(plot.right, y), grid);
    _text(
      c,
      '${k.round()}',
      Offset(plot.left - 8, y - 8),
      right: true,
      size: 11,
    );
  }
  final step = maxT > 60 ? 20.0 : 10.0;
  for (var s = 0.0; s <= maxT; s += step) {
    final x = at(Offset(s, 0)).dx;
    _text(c, '${s.round()} s', Offset(x - 10, plot.bottom + 6), size: 11);
  }
  _text(c, 'kills', Offset(r.left + 12, plot.top - 22), size: 11);
  _text(
    c,
    'combat seconds (protected calibration pilot, seed 1982)',
    Offset(plot.left, r.bottom - 22),
    size: 11,
  );
  for (var i = 0; i < traces.length; i++) {
    final t = traces[i];
    final color = colors[i % colors.length];
    final path = Path()..moveTo(at(t.points.first).dx, at(t.points.first).dy);
    for (final p in t.points.skip(1)) {
      final o = at(p);
      path.lineTo(o.dx, o.dy);
    }
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..strokeJoin = StrokeJoin.round;
    if (t.dashed) {
      for (final metric in path.computeMetrics()) {
        for (var d = 0.0; d < metric.length; d += 10) {
          c.drawPath(metric.extractPath(d, d + 6), paint);
        }
      }
    } else {
      c.drawPath(path, paint);
    }
    // Direct label at the line's end: name, seconds, kills (text ink).
    final end = at(t.points.last);
    c.drawCircle(end, 4, Paint()..color = color);
    c.drawCircle(
      end,
      4,
      Paint()
        ..color = const Color(0xFF1A1A19)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
    final last = t.points.last;
    _text(
      c,
      '${t.name}: ${last.dx.toStringAsFixed(0)} s, ${last.dy.round()} kills',
      Offset(plot.right + 10, end.dy - 8 + i * 0.0),
      size: 11,
      color: const Color(0xFFE4E8EE),
    );
  }
  // Legend row (identity is never color alone: names and line styles).
  var lx = plot.left;
  for (var i = 0; i < traces.length; i++) {
    final y = r.top + 36.0;
    final paint = Paint()
      ..color = colors[i % colors.length]
      ..strokeWidth = 2;
    if (traces[i].dashed) {
      c.drawLine(Offset(lx, y), Offset(lx + 6, y), paint);
      c.drawLine(Offset(lx + 10, y), Offset(lx + 16, y), paint);
    } else {
      c.drawLine(Offset(lx, y), Offset(lx + 16, y), paint);
    }
    _text(c, traces[i].name, Offset(lx + 22, y - 8), size: 11);
    lx += 200;
  }
}

void main() {
  testWidgets('bonus-balance medal screen sheet', (tester) async {
    await tester.runAsync(_loadFonts);
    tester.view.physicalSize = const Size(360, 780);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final frames = <ui.Image>[];
    final board = [
      for (var i = 0; i < 10; i++)
        {
          'initials': [
            'ACE',
            'K9X',
            'ZED',
            'RUN',
            'MAX',
            'JET',
            'OWL',
            'B52',
            'FOX',
            'NOVA'.substring(0, 3),
          ][i],
          'score': 980000 - i * 61000,
          'medals': i < 2 ? 5 : 4 - i % 4,
          'activeMilliseconds': 2400000 - i * 90000,
          if (i == 0) 'remainingLives': 3,
          if (i % 3 == 0) 'modifiers': ['supplyRun'],
          if (i == 4) 'modifiers': ['stormfront', 'noShield'],
          if (i < 8)
            'playedOn': '2026-11-${(16 - i).toString().padLeft(2, '0')}',
        },
    ];
    for (final qualifies in [true, false]) {
      final service = ScoreService(
        endpoint: Uri.parse('https://scores.example/api/scores'),
        client: MockClient(
          (r) async => http.Response(
            jsonEncode({'scores': qualifies ? board.take(4).toList() : board}),
            200,
          ),
        ),
      );
      await tester.pumpWidget(
        RepaintBoundary(
          key: const ValueKey('sheet'),
          child: MaterialApp(home: ArcadePage(scoreService: service)),
        ),
      );
      await tester.pump();
      await tester.tap(find.text('START GAME  →'));
      await tester.pump();
      final scene =
          tester
                  .widgetList<GameWidget>(
                    find.byWidgetPredicate((w) => w is GameWidget),
                  )
                  .first
                  .game
              as DemonScene;
      // A bonus run under a run rule, two carriers down, 41 minutes in.
      final seed = seedWithLevelAndModifier();
      final model = scene.model;
      expect(
        model.restoreCheckpoint({
          'difficulty': 'normal',
          'routeIndex': 2,
          'sector': 3,
          'wave': 1,
          'score': qualifies ? 412350 : 9850,
          'lives': 1,
          'medals': 2,
          'kills': 600,
          'activeMilliseconds': 2468000,
          'runSeed': seed,
        }),
        isTrue,
      );
      expect(model.runModifierIds, hasLength(2));
      model.mode = RunMode.gameOver;
      scene.onTick();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.byKey(const ValueKey('run-record')), findsOneWidget);
      if (!qualifies) {
        await tester.drag(
          find.byKey(const ValueKey('landing-scroll')),
          const Offset(0, -900),
        );
        await tester.pump();
      }
      expect(tester.takeException(), isNull);
      final boundary = tester.renderObject(
        find.byKey(const ValueKey('sheet')),
      ) as RenderRepaintBoundary;
      frames.add((await tester.runAsync(() => boundary.toImage()))!);
      await tester.pumpWidget(const SizedBox());
      await tester.pump();
    }
    await tester.runAsync(
      () => _sheet('art/contact/bonus-balance-medal-screen.png', frames),
    );
  }, skip: !_contact);

  testWidgets('bonus-balance timeline sheet', (tester) async {
    await tester.runAsync(_loadFonts);
    final rows = [
      (
        Difficulty.easy,
        2,
        'Easy · route 1 · sector 2 (the three-second level)',
      ),
      (Difficulty.normal, 3, 'Normal · route 1 · sector 3'),
    ];
    final panels = <(String, List<_Trace>)>[];
    for (final (d, sector, title) in rows) {
      panels.add((
        title,
        [
          _trace('Regular sector', d, sector, null),
          _trace('Supply Run (balanced)', d, sector, supplyRun),
          _trace(
            'Supply Run (first built)',
            d,
            sector,
            _supplyRunV1,
            dashed: true,
          ),
        ],
      ));
    }
    await tester.runAsync(() async {
      const w = 1100.0, ph = 380.0;
      final rec = ui.PictureRecorder();
      final c = Canvas(rec);
      c.drawRect(
        Rect.fromLTWH(0, 0, w, ph * panels.length + 8),
        Paint()..color = const Color(0xFF2A2F3A),
      );
      for (var i = 0; i < panels.length; i++) {
        _panel(
          c,
          Rect.fromLTWH(8, 8 + i * ph, w - 16, ph - 8),
          panels[i].$1,
          panels[i].$2,
        );
      }
      final img = await rec.endRecording().toImage(
        w.round(),
        (ph * panels.length + 8).round(),
      );
      final png = await img.toByteData(format: ui.ImageByteFormat.png);
      File('art/contact/bonus-balance-timeline.png')
        ..createSync(recursive: true)
        ..writeAsBytesSync(png!.buffer.asUint8List());
    });
  }, skip: !_contact);
}
