// The /console route: start a fresh run at any sector, route and difficulty.
//
// Runs launched here are review runs: one life, 0 points, and never ranked.
// They skip no rule of play, but the top-10 board, the initials entry, the
// saved checkpoint and the unlock history are all closed to them
// (ArcadeModel.startAt with console: true; ArcadePage reads model.ranked).
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../game/model.dart';
import '../game/scene.dart' show ink, mint, gold;
import '../review/page_notes.dart';
import '../review/review_notes.dart';
import '../services/audio.dart';

/// Path of the console page.
const consoleRoute = '/console';

/// Path of the asset review studio (the gallery app, served by the Worker).
const studioRoute = '/studio';

/// What console notes are attached to: the page as a whole.
final consoleNotesAsset = ReviewAsset(
  kind: ReviewKind.page,
  id: 'console',
  title: 'Console',
  source: 'lib/widgets/dev_console.dart (/console)',
);

/// Whether [path] (a browser path or route name) names the console page.
bool isConsoleRoute(String? path) {
  if (path == null) return false;
  var p = Uri.tryParse(path)?.path ?? path;
  while (p.length > 1 && p.endsWith('/')) {
    p = p.substring(0, p.length - 1);
  }
  return p.toLowerCase() == consoleRoute;
}

/// Where a console run begins; consumed by ArcadePage.
@immutable
class ConsoleStart {
  const ConsoleStart({
    this.difficulty = Difficulty.normal,
    this.sector = 1,
    this.route = 0,
    this.wave = 1,
  });
  final Difficulty difficulty;

  /// Sector 1-5 (5 is the carrier).
  final int sector;

  /// Zero-based route (run 1 = route 0).
  final int route;
  final int wave;

  /// The carrier of [route].
  factory ConsoleStart.boss({
    Difficulty difficulty = Difficulty.normal,
    int route = 0,
  }) => ConsoleStart(difficulty: difficulty, sector: 5, route: route);

  /// The first sentinel wave on [route] (at least route 1), preferring
  /// [sector] when it has one.
  factory ConsoleStart.sentinel({
    Difficulty difficulty = Difficulty.normal,
    int sector = 2,
    int route = 1,
  }) {
    final r = route < 1 ? 1 : route;
    final order = [sector, 1, 2, 3, 4];
    for (final s in order) {
      final w = ArcadeModel.sentinelWave(
        difficulty: difficulty,
        sector: s,
        route: r,
      );
      if (w != null) {
        return ConsoleStart(
          difficulty: difficulty,
          sector: s,
          route: r,
          wave: w,
        );
      }
    }
    // Sector 2's last wave always qualifies on route >= 1; keep a fallback.
    return ConsoleStart(
      difficulty: difficulty,
      sector: 2,
      route: r,
      wave: ArcadeModel.wavesFor(sector: 2, route: r),
    );
  }

  void applyTo(ArcadeModel model) => model.startAt(
    difficulty: difficulty,
    sector: sector,
    route: route,
    wave: wave,
    console: true,
  );

  String get label =>
      'RUN ${route + 1} · SECTOR $sector${sector == 5 ? '' : ' · WAVE $wave'}';
}

/// The console page. [onStart] launches a run; the app pushes ArcadePage.
class DevConsolePage extends StatefulWidget {
  const DevConsolePage({super.key, required this.onStart, this.galleryUrl});
  final void Function(BuildContext context, ConsoleStart start) onStart;

  /// Link to the art gallery build, or null to hide it.
  final String? galleryUrl;

  @override
  State<DevConsolePage> createState() => _DevConsolePageState();
}

class _DevConsolePageState extends State<DevConsolePage> {
  Difficulty difficulty = Difficulty.normal;
  int sector = 1;
  int route = 0;

  static const _dim = Color(0xFF8D9EB3);
  static const _faint = Color(0xFF52677E);
  static const _line = Color(0xFF2B4254);
  static const _panel = Color(0xC9081220);
  static const _sectorNames = [
    '',
    'KRYBOR',
    'RINGFALL',
    'EMBER MOON',
    'THE HOLLOW',
    'THE CARRIER',
  ];

  void _launch(ConsoleStart start) {
    // Unlock audio inside the user gesture; the arcade page starts after.
    audioUnlock();
    widget.onStart(context, start);
  }

  @override
  Widget build(BuildContext context) {
    final sentinel = ConsoleStart.sentinel(
      difficulty: difficulty,
      sector: sector == 5 ? 2 : sector,
      route: route,
    );
    final waves = ArcadeModel.wavesFor(sector: sector, route: route);
    final sentinelHere = ArcadeModel.sentinelWave(
      difficulty: difficulty,
      sector: sector,
      route: route,
    );
    return Scaffold(
      backgroundColor: ink,
      // Notes on the console and the runs started from it, shared with the
      // studio and the gallery (lib/review/page_notes.dart).
      floatingActionButton: PageNotesButton(asset: consoleNotesAsset),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            key: const ValueKey('console-scroll'),
            padding: const EdgeInsets.fromLTRB(16, 28, 16, 40),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _label('KRYBOR / DEFENSE SYSTEM', const Color(0xFF94A6B8), 9),
                  const SizedBox(height: 18),
                  const FittedBox(
                    child: Text(
                      'CONSOLE',
                      style: TextStyle(
                        fontSize: 54,
                        height: 1,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 10,
                        color: mint,
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  _label(
                    'JUMP TO ANY SECTOR · 1 LIFE · 0 POINTS · NOT RANKED',
                    _dim,
                    9,
                  ),
                  const SizedBox(height: 26),
                  _panelBox([
                    _heading('DIFFICULTY'),
                    _choices(
                      'difficulty',
                      [for (final d in Difficulty.values) d.name.toUpperCase()],
                      Difficulty.values.indexOf(difficulty),
                      (i) => setState(() => difficulty = Difficulty.values[i]),
                    ),
                    const SizedBox(height: 18),
                    _heading('RUN'),
                    _choices(
                      'run',
                      ['1', '2', '3', '4', '5'],
                      route,
                      (i) => setState(() => route = i),
                    ),
                    const SizedBox(height: 18),
                    _heading('SECTOR'),
                    _choices(
                      'sector',
                      ['1', '2', '3', '4', '5'],
                      sector - 1,
                      (i) => setState(() => sector = i + 1),
                    ),
                    const SizedBox(height: 10),
                    _label(
                      sector == 5
                          ? 'CARRIER · BOSS FORM ${route + 1}'
                          : '${_sectorNames[sector]} · $waves WAVES · '
                                '${sentinelHere == null ? 'NO SENTINEL' : 'SENTINEL W$sentinelHere'}',
                      _dim,
                      8,
                    ),
                  ]),
                  const SizedBox(height: 16),
                  FilledButton(
                    key: const ValueKey('console-launch'),
                    onPressed: () => _launch(
                      ConsoleStart(
                        difficulty: difficulty,
                        sector: sector,
                        route: route,
                      ),
                    ),
                    child: Text(
                      'LAUNCH · RUN ${route + 1} · SECTOR $sector  →',
                      textAlign: TextAlign.center,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          key: const ValueKey('console-boss'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: gold,
                            side: const BorderSide(color: Color(0xFF6B5A33)),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 20,
                            ),
                          ),
                          onPressed: () => _launch(
                            ConsoleStart.boss(
                              difficulty: difficulty,
                              route: route,
                            ),
                          ),
                          child: const Text('BOSS'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: OutlinedButton(
                          key: const ValueKey('console-sentinel'),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 20,
                            ),
                          ),
                          onPressed: () => _launch(sentinel),
                          child: const Text('SENTINEL'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: _label('CARRIER · RUN ${route + 1}', _faint, 8),
                      ),
                      const SizedBox(width: 10),
                      Expanded(child: _label(sentinel.label, _faint, 8)),
                    ],
                  ),
                  // --- console links: review pages opened from here (the
                  // art gallery; an asset viewer / notes link joins this row).
                  if (widget.galleryUrl != null) ...[
                    const SizedBox(height: 22),
                    TextButton.icon(
                      key: const ValueKey('console-gallery'),
                      style: TextButton.styleFrom(
                        foregroundColor: mint,
                        shape: const RoundedRectangleBorder(),
                      ),
                      onPressed: () => launchUrl(
                        Uri.base.resolve(widget.galleryUrl!),
                        webOnlyWindowName: '_self',
                      ),
                      icon: const Icon(Icons.grid_view, size: 16),
                      label: const Text(
                        'ART GALLERY',
                        style: TextStyle(fontSize: 11, letterSpacing: 2),
                      ),
                    ),
                    // Asset review studio (lib/review/), served at /studio.
                    TextButton.icon(
                      key: const ValueKey('console-review'),
                      style: TextButton.styleFrom(
                        foregroundColor: mint,
                        shape: const RoundedRectangleBorder(),
                      ),
                      onPressed: () => launchUrl(
                        Uri.base.resolve(studioRoute),
                        webOnlyWindowName: '_self',
                      ),
                      icon: const Icon(Icons.rate_review, size: 16),
                      label: const Text(
                        'ASSET REVIEW',
                        style: TextStyle(fontSize: 11, letterSpacing: 2),
                      ),
                    ),
                  ],
                  const SizedBox(height: 18),
                  _label(
                    'EARLIER RUNS COUNT AS WON · NO TOP 10 · NO SAVED RUN',
                    _faint,
                    8,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _panelBox(List<Widget> children) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: _panel,
      border: Border.all(color: _line),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: children,
    ),
  );

  Widget _heading(String text) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Text(
      text,
      style: const TextStyle(fontSize: 9, letterSpacing: 2, color: gold),
    ),
  );

  Widget _choices(
    String id,
    List<String> labels,
    int selected,
    ValueChanged<int> onSelect,
  ) => Row(
    children: [
      for (var i = 0; i < labels.length; i++) ...[
        if (i > 0) const SizedBox(width: 6),
        Expanded(
          child: TextButton(
            key: ValueKey('console-$id-$i'),
            style: TextButton.styleFrom(
              minimumSize: const Size(0, 44),
              padding: const EdgeInsets.symmetric(horizontal: 4),
              shape: const RoundedRectangleBorder(),
              foregroundColor: i == selected ? ink : const Color(0xFFD7E5EF),
              backgroundColor: i == selected ? mint : const Color(0xFF101F2D),
              side: BorderSide(
                color: i == selected ? mint : const Color(0xFF33485A),
              ),
            ),
            onPressed: () => onSelect(i),
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                labels[i],
                style: TextStyle(
                  fontSize: 11,
                  letterSpacing: 2,
                  fontWeight: i == selected ? FontWeight.bold : null,
                ),
              ),
            ),
          ),
        ),
      ],
    ],
  );

  Widget _label(String value, Color color, double size) => Text(
    value,
    textAlign: TextAlign.center,
    style: TextStyle(
      fontSize: size,
      letterSpacing: 1.5,
      color: color,
      height: 1.4,
    ),
  );
}
