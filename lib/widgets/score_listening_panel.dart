// --- adaptive-soundtrack: the score's listening aid on /console.
//
// Drives the live web score player (web/audio/demon-score.js) through its own
// SongDirector with the game's real event names, so the operator can hear
// every section and every transition rule without playing: step through the
// sector song and the carrier fight by hand, or let a scripted run fire the
// events on the fight's own timing. SCORE / RECORDED switches the game between
// the score and the recorded cues (remembered per device) for an A/B.
import 'dart:async';

import 'package:flutter/material.dart';

import '../game/game_events.dart';
import '../game/scene.dart' show mint, gold;
import '../game/song_director.dart';
import '../services/audio.dart';

class ScoreListeningPanel extends StatefulWidget {
  const ScoreListeningPanel({super.key});

  @override
  State<ScoreListeningPanel> createState() => _ScoreListeningPanelState();
}

/// One scripted step: seconds after the start, and what it does.
typedef ScoreCueStep = (
  double at,
  String label,
  void Function(SongDirector d) run,
);

/// The carrier fight on its own timing (carrier-hatches: a 3.5 s
/// transformation, the victory 5.5 s after the collapse starts), with its
/// accents.
List<ScoreCueStep> scriptedFight() => [
  (0, 'carrier level', (d) => d.cue('level', level: 5)),
  (3, 'approach step', (_) => audioAccent('toll')),
  (6, 'approach step', (_) => audioAccent('toll')),
  (9, 'in range', (_) => audioAccent('hatch')),
  (
    9.2,
    'tier 1',
    (d) => _event(d, GameEventNames.bossHatchTier, {'tier': 1, 'tiers': 3}),
  ),
  (
    10,
    'intensity 2',
    (d) => _event(d, GameEventNames.musicIntensity, {'tier': 2}),
  ),
  (12, 'hatch telegraph', (_) => audioAccent('riser')),
  (13.5, 'volley', (_) => audioAccent('stab')),
  (16, 'hatch destroyed', (_) => audioAccent('impact')),
  (
    17,
    'tier 2',
    (d) => _event(d, GameEventNames.bossHatchTier, {'tier': 2, 'tiers': 3}),
  ),
  (
    19,
    'intensity 3',
    (d) => _event(d, GameEventNames.musicIntensity, {'tier': 3}),
  ),
  (21, 'field down', (_) => audioAccent('glass')),
  (23, 'shield failing', (d) => _event(d, GameEventNames.bossShieldFailing)),
  (
    26,
    'transformation',
    (d) => _event(d, GameEventNames.bossTransform, {'stage': 'start'}),
  ),
  (
    29.5,
    'core exposed',
    (d) {
      _event(d, GameEventNames.bossTransform, {'stage': 'end'});
      _event(d, GameEventNames.bossCoreExposed);
      _event(d, GameEventNames.bossHatchTier, {'tier': 3, 'tiers': 3});
    },
  ),
  (
    31,
    'intensity 4',
    (d) => _event(d, GameEventNames.musicIntensity, {'tier': 4}),
  ),
  (38, 'module lost', (d) => _event(d, GameEventNames.bossModuleLost)),
  (
    46,
    'collapse',
    (d) {
      d.cue('victory', level: 5);
      _event(d, GameEventNames.bossCollapseStart);
    },
  ),
  (47, 'wreck falls', (_) => audioAccent('impact')),
  (48, 'wreck falls', (_) => audioAccent('impact')),
  (
    51.5,
    'victory',
    (d) {
      _event(d, GameEventNames.fleetIntact);
      _event(d, GameEventNames.bossCollapseEnd);
    },
  ),
];

/// The sector song: arrival, four waves with intensity rising and falling,
/// dives, the clear.
List<ScoreCueStep> scriptedSector(void Function(double) share) => [
  (0, 'sector start', (d) => d.cue('level', level: 1)),
  (
    8,
    'intensity 2',
    (d) => _event(d, GameEventNames.musicIntensity, {'tier': 2}),
  ),
  (12, 'dive', (_) => audioAccent('dive')),
  (
    16,
    'wave 2',
    (d) {
      share(1 / 3);
      _event(d, GameEventNames.waveStart);
    },
  ),
  (
    22,
    'intensity 3',
    (d) => _event(d, GameEventNames.musicIntensity, {'tier': 3}),
  ),
  (27, 'dive', (_) => audioAccent('dive')),
  (
    30,
    'wave 3',
    (d) {
      share(2 / 3);
      _event(d, GameEventNames.waveStart);
    },
  ),
  (
    34,
    'intensity 1',
    (d) => _event(d, GameEventNames.musicIntensity, {'tier': 1}),
  ),
  (
    42,
    'wave 4',
    (d) {
      share(1);
      _event(d, GameEventNames.waveStart);
    },
  ),
  (
    43,
    'intensity 4',
    (d) => _event(d, GameEventNames.musicIntensity, {'tier': 4}),
  ),
  (48, 'last stand', (_) => audioAccent('laststand')),
  (
    55,
    'sector clear',
    (d) {
      d.cue('levelclear', level: 1);
      _event(d, GameEventNames.fleetIntact);
    },
  ),
];

void _event(
  SongDirector d,
  String name, [
  Map<String, Object?> data = const {},
]) => d.onGameEvent(GameEvent(name, data));

class _ScoreListeningPanelState extends State<ScoreListeningPanel> {
  double _share = 0;
  late final SongDirector _songs = SongDirector(waveShare: () => _share);
  final List<Timer> _script = [];
  Timer? _poll;
  String _now = '';
  bool _scoreOn = audioScoreOn();
  int _wave = 0;

  @override
  void dispose() {
    _cancel();
    _poll?.cancel();
    super.dispose();
  }

  void _cancel() {
    for (final t in _script) {
      t.cancel();
    }
    _script.clear();
  }

  // Every press unlocks audio inside the gesture and starts the status poll.
  void _do(String label, void Function() action) {
    audioUnlock();
    audioResume();
    action();
    _poll ??= Timer.periodic(const Duration(milliseconds: 250), (_) {
      final p = audioScorePosition();
      final text = p == null ? 'recorded music' : '${p.song} · ${p.section}';
      if (mounted && text != _now) setState(() => _now = text);
    });
    setState(() => _now = label);
  }

  void _run(List<ScoreCueStep> steps) {
    _cancel();
    for (final (at, label, run) in steps) {
      _script.add(
        Timer(Duration(milliseconds: (at * 1000).round()), () {
          run(_songs);
          if (mounted) setState(() => _now = label);
        }),
      );
    }
  }

  void _stop() {
    _cancel();
    if (!_songs.cue('menu')) audioCue('menu', 1, 1, 0);
  }

  void _hatch(int tier) =>
      _event(_songs, GameEventNames.bossHatchTier, {'tier': tier, 'tiers': 3});
  void _tier(int tier) =>
      _event(_songs, GameEventNames.musicIntensity, {'tier': tier});

  @override
  Widget build(BuildContext context) {
    Widget row(String id, List<(String, void Function())> buttons) => Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Wrap(
        spacing: 6,
        runSpacing: 6,
        children: [
          for (final (label, action) in buttons)
            OutlinedButton(
              key: ValueKey(
                'score-$id-${label.toLowerCase().replaceAll(' ', '-')}',
              ),
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFFD7E5EF),
                side: const BorderSide(color: Color(0xFF33485A)),
                minimumSize: const Size(0, 40),
                padding: const EdgeInsets.symmetric(horizontal: 10),
                shape: const RoundedRectangleBorder(),
              ),
              onPressed: () => _do(label, action),
              child: Text(
                label,
                style: const TextStyle(fontSize: 10, letterSpacing: 1.5),
              ),
            ),
        ],
      ),
    );
    Widget heading(String text) => Padding(
      padding: const EdgeInsets.only(top: 10, bottom: 6),
      child: Text(
        text,
        style: const TextStyle(fontSize: 9, letterSpacing: 2, color: gold),
      ),
    );
    return Container(
      key: const ValueKey('score-panel'),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xC9081220),
        border: Border.all(color: const Color(0xFF2B4254)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'SCORE · LISTEN',
            style: TextStyle(
              fontSize: 11,
              letterSpacing: 3,
              color: mint,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            _now.isEmpty
                ? 'THE GAME\'S MIDI SCORE, MOVED BY ITS REAL EVENTS'
                : _now.toUpperCase(),
            key: const ValueKey('score-now'),
            style: const TextStyle(
              fontSize: 9,
              letterSpacing: 1.5,
              color: Color(0xFF8D9EB3),
            ),
          ),
          heading('SCRIPTED'),
          row('script', [
            ('CARRIER FIGHT', () => _run(scriptedFight())),
            (
              'SECTOR SONG',
              () {
                _share = 0;
                _run(scriptedSector((v) => _share = v));
              },
            ),
            ('STOP', _stop),
          ]),
          heading('KRYBOR · SECTOR 1'),
          row('sector', [
            (
              'ARRIVAL',
              () {
                _cancel();
                _share = 0;
                _wave = 0;
                _songs.cue('level', level: 1);
              },
            ),
            (
              'NEXT WAVE',
              () {
                _wave = (_wave + 1).clamp(0, 3);
                _share = _wave / 3;
                _event(_songs, GameEventNames.waveStart);
              },
            ),
            ('CALM', () => _tier(1)),
            ('PERIL', () => _tier(3)),
            ('MAX', () => _tier(4)),
            ('DIVE', () => audioAccent('dive')),
            ('CLEAR', () => _songs.cue('levelclear', level: 1)),
          ]),
          heading('CARRIER · TOUR 1'),
          row('carrier', [
            (
              'ARRIVAL',
              () {
                _cancel();
                _songs.cue('level', level: 5);
              },
            ),
            ('TIER 1', () => _hatch(1)),
            ('TIER 2', () => _hatch(2)),
            (
              'SHIELD FAILING',
              () => _event(_songs, GameEventNames.bossShieldFailing),
            ),
            (
              'TRANSFORM',
              () => _event(_songs, GameEventNames.bossTransform, {
                'stage': 'start',
              }),
            ),
            (
              'MODULE LOST',
              () => _event(_songs, GameEventNames.bossModuleLost),
            ),
            (
              'COLLAPSE',
              () => _event(_songs, GameEventNames.bossCollapseStart),
            ),
            ('VICTORY', () => _event(_songs, GameEventNames.bossCollapseEnd)),
            ('FLEET', () => _event(_songs, GameEventNames.fleetIntact)),
          ]),
          heading('STINGERS'),
          row('sting', [
            for (final name in [
              'toll',
              'riser',
              'stab',
              'glass',
              'impact',
              'laststand',
              'gloat',
              'respawn',
            ])
              (name.toUpperCase(), () => audioAccent(name)),
          ]),
          heading('IN THE GAME'),
          row('mode', [
            (
              _scoreOn ? 'SCORE ✓' : 'SCORE',
              () => setState(() => _scoreOn = audioScoreEnabled(true)),
            ),
            (
              !_scoreOn ? 'RECORDED ✓' : 'RECORDED',
              () => setState(() => _scoreOn = audioScoreEnabled(false)),
            ),
          ]),
          const Text(
            'SECTOR 1 AND EVERY CARRIER PLAY THE SCORE · BOSS → FIGHT OR FAST DECAY ABOVE PLAYS IT LIVE',
            style: TextStyle(
              fontSize: 8,
              letterSpacing: 1.5,
              color: Color(0xFF52677E),
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}
