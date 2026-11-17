// --- adaptive-soundtrack: the score's listening aid on /console.
//
// Drives the live web score player (web/audio/demon-score.js) through its own
// SongDirector with the game's real event names, so the operator can hear
// every song, every section and every transition rule without playing: the
// FULL RUN tour plays one route end to end (the overture, the four worlds with
// their bridges, a Stormfront bonus level, the first carrier, the next route's
// start) and then the last carrier into the ending's coda; the step buttons
// trigger every section move and stinger by hand. The score is the game's only
// music, so there is no recorded A/B any more.
//
// --- sample-bank: VOICES switches the score between its synth voices and the
// CC0 sample bank on this device (stored; off by default until the operator
// approves the bank, adaptive-soundtrack design §12.9.7).
import 'dart:async';

import 'package:flutter/material.dart';

import '../game/game_events.dart';
import '../game/scene.dart' show mint, gold;
import '../game/song_director.dart';
import '../game/song_map.dart';
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

void _event(
  SongDirector d,
  String name, [
  Map<String, Object?> data = const {},
]) => d.onGameEvent(GameEvent(name, data));

/// The carrier fight of tour [cycle] + 1 on its own timing (carrier-hatches:
/// a 3.5 s transformation, the victory 5.5 s after the collapse starts), from
/// [t0] seconds, with its accents. Every upper tier of the tour plays.
List<ScoreCueStep> scriptedFight({int cycle = 0, double t0 = 0}) {
  final song = scoreSongs[scoreSongFor(5, cycle)]!;
  final upper = song.hatchSections.length, tiers = upper + 1;
  final steps = <ScoreCueStep>[
    (
      t0,
      'carrier · tour ${cycle + 1}',
      (d) => d.cue('boss', level: 5, cycle: cycle),
    ),
    (t0 + 3, 'approach step', (_) => audioAccent('toll')),
    (t0 + 6, 'approach step', (_) => audioAccent('toll')),
    (t0 + 9, 'in range', (_) => audioAccent('hatch')),
  ];
  var t = t0 + 9.2;
  for (var k = 1; k <= upper; k++) {
    final tier = k;
    steps.add((
      t,
      'tier $tier of $upper',
      (d) => _event(d, GameEventNames.bossHatchTier, {
        'tier': tier,
        'tiers': tiers,
      }),
    ));
    steps.add((
      t + .8,
      'intensity ${(tier + 1).clamp(1, 4)}',
      (d) => _event(d, GameEventNames.musicIntensity, {
        'tier': (tier + 1).clamp(1, 4),
      }),
    ));
    steps.add((t + 2.8, 'hatch telegraph', (_) => audioAccent('riser')));
    steps.add((t + 4.3, 'volley', (_) => audioAccent('stab')));
    steps.add((t + 6.8, 'hatch destroyed', (_) => audioAccent('impact')));
    t += 7.8;
  }
  steps.addAll([
    (t, 'shield failing', (d) => _event(d, GameEventNames.bossShieldFailing)),
    (
      t + 3,
      'transformation',
      (d) => _event(d, GameEventNames.bossTransform, {'stage': 'start'}),
    ),
    (
      t + 6.5,
      'core exposed',
      (d) {
        _event(d, GameEventNames.bossTransform, {'stage': 'end'});
        _event(d, GameEventNames.bossCoreExposed);
        _event(d, GameEventNames.bossHatchTier, {
          'tier': tiers,
          'tiers': tiers,
        });
      },
    ),
    (
      t + 8,
      'intensity 4',
      (d) => _event(d, GameEventNames.musicIntensity, {'tier': 4}),
    ),
    (t + 15, 'module lost', (d) => _event(d, GameEventNames.bossModuleLost)),
    (
      t + 23,
      'collapse',
      (d) {
        d.cue('victory', level: 5, cycle: cycle);
        _event(d, GameEventNames.bossCollapseStart);
      },
    ),
    (t + 24, 'wreck falls', (_) => audioAccent('impact')),
    (t + 25, 'wreck falls', (_) => audioAccent('impact')),
    (
      t + 28.5,
      'victory',
      (d) {
        _event(d, GameEventNames.fleetIntact);
        _event(d, GameEventNames.bossCollapseEnd);
      },
    ),
  ]);
  return steps;
}

/// Sector [level] of route [cycle] from [t0]: the arrival, four waves with
/// the intensity rising and falling, dives, a last stand, the clear and the
/// travel (the bridge into the next song). [bonus] makes it a Stormfront.
List<ScoreCueStep> scriptedSector(
  void Function(double) share, {
  int level = 1,
  int cycle = 0,
  double t0 = 0,
  bool long = true,
  bool bonus = false,
}) {
  final f = long ? 1.0 : .45;
  ScoreCueStep wave(double at, String label, double s) => (
    t0 + at * f,
    label,
    (d) {
      share(s);
      _event(d, GameEventNames.waveStart);
    },
  );
  ScoreCueStep tier(double at, int t) => (
    t0 + at * f,
    'intensity $t',
    (d) => _event(d, GameEventNames.musicIntensity, {'tier': t}),
  );
  return [
    (
      t0,
      'sector $level · route ${cycle + 1}',
      (d) {
        share(0);
        d.cue('level', level: level, cycle: cycle);
      },
    ),
    if (bonus)
      (
        t0 + 6 * f,
        'stormfront',
        (d) => _event(d, GameEventNames.bonusStart, {'variant': 'stormfront'}),
      ),
    tier(8, 2),
    (t0 + 12 * f, 'dive', (_) => audioAccent('dive')),
    if (!bonus) wave(16, 'wave 2', 1 / 3),
    tier(22, 3),
    (t0 + 27 * f, 'dive', (_) => audioAccent('dive')),
    if (!bonus) wave(30, 'wave 3', 2 / 3),
    tier(34, 1),
    if (!bonus) wave(42, 'wave 4', 1),
    tier(43, 4),
    (t0 + 48 * f, 'last stand', (_) => audioAccent('laststand')),
    (
      t0 + 55 * f,
      'sector clear',
      (d) {
        d.cue('levelclear', level: level, cycle: cycle);
        _event(d, GameEventNames.fleetIntact);
      },
    ),
    (
      t0 + 55 * f + 2,
      'travel',
      (d) => d.cue('travel', level: level, cycle: cycle),
    ),
  ];
}

/// The quick tour of the whole run: the overture, route 1 end to end (its
/// four worlds with their bridges, a Stormfront bonus level in Ember Moon,
/// the first carrier and the bridge into route 2), then the last carrier into
/// the ending's worldized bridge and the coda. About four minutes.
List<ScoreCueStep> scriptedRun(void Function(double) share) {
  final steps = <ScoreCueStep>[(0, 'overture', (d) => d.cue('menu'))];
  var t = 6.0;
  for (var level = 1; level <= 4; level++) {
    steps.addAll(
      scriptedSector(
        share,
        level: level,
        t0: t,
        long: false,
        bonus: level == 3,
      ),
    );
    t += 55 * .45 + 6.5;
  }
  final fight = scriptedFight(t0: t);
  steps.addAll(fight);
  t = fight.last.$1 + 4;
  steps.add((t, 'travel', (d) => d.cue('travel', level: 5)));
  steps.addAll(
    scriptedSector(share, level: 1, cycle: 1, t0: t + 4, long: false),
  );
  final last = scriptedFight(cycle: 4, t0: t + 40);
  steps.addAll(last);
  final end = last.last.$1;
  steps.add((end + 3, 'ending', (d) => d.cue('ending', level: 5, cycle: 4)));
  steps.add((
    end + 6,
    'completed',
    (d) => d.cue('completed', level: 5, cycle: 4),
  ));
  return steps;
}

class _ScoreListeningPanelState extends State<ScoreListeningPanel> {
  double _share = 0;
  late final SongDirector _songs = SongDirector(waveShare: () => _share);
  final List<Timer> _script = [];
  Timer? _poll;
  String _now = '';
  int _wave = 0, _sector = 1, _tour = 0;
  bool _bank = audioScoreBank();
  String _bankNow = '';

  String _bankText() {
    final b = audioScoreBankState();
    if (b == null || !b.on) return 'SYNTH VOICES';
    if (b.sprites == 0) return 'SAMPLED · LOADING THE BANK';
    final mb = (b.decodedBytes / 1e6).toStringAsFixed(1);
    return 'SAMPLED · ${b.loaded}/${b.sprites} SPRITES · $mb MB · ${b.sampled} NOTES';
  }

  void _setBank(bool on) {
    audioUnlock();
    final now = audioSetScoreBank(on);
    setState(() {
      _bank = now;
      _bankNow = _bankText();
    });
  }

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
      final text = p == null ? 'silence' : '${p.song} · ${p.section}';
      final bank = _bankText();
      if (mounted && (text != _now || bank != _bankNow)) {
        setState(() {
          _now = text;
          _bankNow = bank;
        });
      }
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
    _songs.cue('menu');
  }

  void _hatch(int tier) {
    final upper = scoreSongs[scoreSongFor(5, _tour)]!.hatchSections.length;
    _event(_songs, GameEventNames.bossHatchTier, {
      'tier': tier.clamp(1, upper),
      'tiers': upper + 1,
    });
  }

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
    String upper(int level) =>
        (scoreSongs[scoreSongFor(level, 0)]?.name ?? '').toUpperCase();
    final hatches = scoreSongs[scoreSongFor(5, _tour)]!.hatchSections.length;
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
          heading('VOICES · ${_bankNow.isEmpty ? _bankText() : _bankNow}'),
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Wrap(
              spacing: 6,
              children: [
                for (final (label, on) in [('SYNTH', false), ('SAMPLED', true)])
                  OutlinedButton(
                    key: ValueKey('score-voices-${label.toLowerCase()}'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: _bank == on
                          ? mint
                          : const Color(0xFFD7E5EF),
                      side: BorderSide(
                        color: _bank == on ? mint : const Color(0xFF33485A),
                      ),
                      minimumSize: const Size(0, 40),
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      shape: const RoundedRectangleBorder(),
                    ),
                    onPressed: () => _setBank(on),
                    child: Text(
                      label,
                      style: const TextStyle(fontSize: 10, letterSpacing: 1.5),
                    ),
                  ),
              ],
            ),
          ),
          heading('SCRIPTED'),
          row('script', [
            ('FULL RUN', () => _run(scriptedRun((v) => _share = v))),
            (
              'SECTOR SONG',
              () => _run(
                scriptedSector((v) => _share = v, level: _sector, cycle: 0),
              ),
            ),
            ('CARRIER FIGHT', () => _run(scriptedFight(cycle: _tour))),
            ('STOP', _stop),
          ]),
          heading('SECTOR · ${upper(_sector)}'),
          row('world', [
            for (var level = 1; level <= 4; level++)
              (
                upper(level),
                () {
                  _cancel();
                  _share = 0;
                  _wave = 0;
                  setState(() => _sector = level);
                  _songs.cue('level', level: level);
                },
              ),
          ]),
          row('sector', [
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
            (
              'STORMFRONT',
              () => _event(_songs, GameEventNames.bonusStart, {
                'variant': 'stormfront',
              }),
            ),
            ('CLEAR', () => _songs.cue('levelclear', level: _sector)),
            ('TRAVEL', () => _songs.cue('travel', level: _sector)),
          ]),
          heading('CARRIER · TOUR ${_tour + 1} · $hatches TIERS'),
          row('tour', [
            for (var cycle = 0; cycle <= 4; cycle++)
              (
                'TOUR ${cycle + 1}',
                () {
                  _cancel();
                  setState(() => _tour = cycle);
                  _songs.cue('boss', level: 5, cycle: cycle);
                },
              ),
          ]),
          row('carrier', [
            for (var k = 1; k <= hatches; k++) ('TIER $k', () => _hatch(k)),
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
            ('TRAVEL', () => _songs.cue('travel', level: 5, cycle: _tour)),
            ('ENDING', () => _songs.cue('ending', level: 5, cycle: _tour)),
          ]),
          heading('SCENES'),
          row('scene', [
            ('OVERTURE', () => _songs.cue('menu')),
            ('DEFEAT', () => _songs.cue('gameover')),
            ('CODA', () => _songs.cue('ending')),
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
          const Text(
            'EVERY SCENE OF THE GAME PLAYS THE SCORE · BOSS → FIGHT OR FAST DECAY ABOVE PLAYS A CARRIER LIVE',
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
