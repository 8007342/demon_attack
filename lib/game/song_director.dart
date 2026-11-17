import 'dart:math' as math;

import '../services/audio.dart';
import 'game_events.dart';
import 'song_map.dart';

/// The music clock the score plays on (the audio clock on the web).
abstract interface class SongClock {
  /// Seconds on the music clock; negative before audio is unlocked.
  double get now;

  /// What the player reports it is playing (the section and the time of its
  /// beat 0), or null when it reports nothing.
  ({String song, String section, double start})? get position;
}

/// The audio engine's own clock (`demonAudio.time` and `.scorePosition`).
class AudioSongClock implements SongClock {
  const AudioSongClock();
  @override
  double get now => audioTime();
  @override
  ({String song, String section, double start})? get position =>
      audioScorePosition();
}

/// One request to the score player (`demonAudio.song`, web/audio/demon-score.js
/// `move()`): a section move, a mask change, or both.
class SongMove {
  const SongMove({
    required this.song,
    this.section,
    this.at = -1,
    this.quantum = 'bar',
    this.enter = 'start',
    this.tier,
    this.variant,
    this.fleet,
    required this.reason,
    this.fallback,
  });
  final String song;

  /// The section to move to; null for a mask change only.
  final String? section;

  /// The landing time on the music clock (a bar or beat line of the playing
  /// section); -1 lets the player pick the next [quantum] line itself.
  final double at;

  /// 'bar', 'beat' or 'now'.
  final String quantum;

  /// 'start' (the section's first bar) or 'same' (the same bar position).
  final String enter;
  final int? tier;

  /// 'v1' or 'v2' (the v2 layer: harmony lead and choir).
  final String? variant;

  /// The fleet layer (the brass fanfare of an intact fleet).
  final bool? fleet;

  /// The event that asked for it (diagnostics).
  final String reason;

  /// The recorded cue to play if the score is off: mode, level, phase, cycle.
  final Map<String, Object?>? fallback;

  Map<String, Object?> toJson() => {
    'song': song,
    'section': ?section,
    'at': at,
    'quantum': quantum,
    'enter': enter,
    'tier': ?tier,
    'variant': ?variant,
    'fleet': ?fleet,
    'reason': reason,
    'fallback': ?fallback,
  };
}

/// One section start the director has planned or seen (its log).
class SongStep {
  const SongStep(this.song, this.section, this.at, this.reason);
  final String song;
  final String section;

  /// Music-clock time of the start; null when the player chose it alone.
  final double? at;
  final String reason;
  @override
  String toString() => '$song/$section@${at?.toStringAsFixed(3)} ($reason)';
}

/// Turns game events into moves of the MIDI-first score (adaptive-soundtrack
/// design §4.3, §11.7). Pure Dart: no dart:ui, no audio; [send] and [clock]
/// are injected (main.dart wires them to the web audio engine).
///
/// It owns the song graph: which song a sector plays (`scorePlays`), the
/// sector's arrival and wave-progress sections, the carrier's hatch tiers,
/// transformation, core, collapse and victory, the intensity mask and the v2
/// and fleet layers. It keeps its own picture of the bar grid (section starts
/// on the music clock), so every move it sends lands on a bar line (or a beat
/// line for the collapse and the clear), and it applies the rules of design
/// §4.3: a section requested within [scoreDwellBars] bars of the last start
/// waits until they have played, and the latest waiting request wins (two
/// hatch tiers in quick succession play only the later one). The player
/// re-checks each time against what it has already scheduled.
class SongDirector {
  SongDirector({
    double Function(SongMove move)? sendMove,
    SongClock? clock,
    this.waveShare,
    Map<int, String>? plays,
    Map<String, ScoreSong>? songs,
  }) : _send = sendMove ?? ((m) => audioSong(m.toJson())),
       clock = clock ?? const AudioSongClock(),
       plays = plays ?? scorePlays,
       songs = songs ?? scoreSongs;

  final double Function(SongMove move) _send;
  final SongClock clock;
  final Map<int, String> plays;
  final Map<String, ScoreSong> songs;

  /// Wave progress of the sector, 0 (first wave) .. 1 (last wave).
  final double Function()? waveShare;

  /// Seconds ahead of the clock a requested line must be: beyond the player's
  /// lookahead (demon-score.js LOOKAHEAD, 0.25 s) and a timer tick.
  static const margin = .3;

  /// The transformation bridge waits at most one bar after a tier change.
  static const transformDwellBars = 1;

  String? song;
  String? section;

  /// Music-clock time of the playing section's beat 0 (null: not synced).
  double? start;
  String? pendingSection;
  double? pendingAt;
  int tier = 1;
  bool fleet = false;
  bool _shieldFailing = false, _moduleLost = false;
  int _level = 1, _cycle = 0;
  final List<SongStep> log = [];

  ScoreSong? get _song => song == null ? null : songs[song];
  bool get _carrier => _song?.form == 'carrier';
  bool get _sector => _song?.form == 'sector';

  /// A scene cue from the game (main.dart's raw events). Returns whether the
  /// score plays it; false means the recorded cue plays (and the score yields
  /// on its bar line).
  bool cue(String mode, {int level = 1, int phase = 1, int cycle = 0}) {
    _advance(clock.now);
    switch (mode) {
      case 'level' || 'boss':
        final id = plays[level];
        if (id == null || !songs.containsKey(id)) return _stop();
        // The carrier's repeated cues (the rise, a form change, the
        // transformation) never restart its song.
        if (mode == 'boss' && song == id && _carrier) return true;
        _startSong(id, level: level, cycle: cycle, mode: mode, phase: phase);
        return true;
      case 'levelclear':
        if (!_sector) return _stop();
        _request('clear', quantum: 'beat', dwell: 0, reason: 'levelClear');
        return true;
      case 'travel':
        // The clear's (or the victory's) hold bars carry the travel.
        if (song == null) return false;
        return true;
      case 'victory':
        if (!_carrier) return _stop();
        if (!{'collapse', 'victory'}.contains(_target)) {
          _request('collapse', quantum: 'beat', dwell: 0, reason: 'victory');
        }
        return true;
      default:
        // completed (the last carrier's finale into the ending), gameover,
        // menu, ending: recorded cues.
        return _stop();
    }
  }

  /// Shared-bridge listener (GameEvents.listen).
  void onGameEvent(GameEvent event) {
    if (song == null) return;
    _advance(clock.now);
    switch (event.name) {
      case GameEventNames.musicIntensity:
        final t = ((event.data['tier'] as int?) ?? 1).clamp(1, 4);
        if (t == tier) return;
        tier = t;
        _mask(reason: event.name, tier: t);
      case GameEventNames.waveStart || GameEventNames.cohortMerged:
        if (_sector) _waveProgress(event.name);
      case GameEventNames.fleetIntact:
        if (fleet) return;
        fleet = true;
        _mask(reason: event.name, fleet: true);
      case GameEventNames.bossHatchTier:
        if (!_carrier) return;
        final hatch = _hatchSection(event.data);
        if (hatch != null && hatch != _target) {
          _request(hatch, reason: event.name);
        }
      case GameEventNames.bossTransform:
        if (_carrier && event.data['stage'] == 'start') {
          _request('transform', dwell: transformDwellBars, reason: event.name);
        }
      case GameEventNames.bossCoreExposed:
        if (_carrier && !{'transform', 'core'}.contains(_target)) {
          _request('core', reason: event.name);
        }
      case GameEventNames.bossShieldFailing:
        if (!_carrier || _shieldFailing) return;
        _shieldFailing = true;
        if (_isHatch(_target)) _mask(reason: event.name, variant: 'v2');
      case GameEventNames.bossModuleLost:
        if (!_carrier || _moduleLost) return;
        _moduleLost = true;
        if (_target == 'core') _mask(reason: event.name, variant: 'v2');
      case GameEventNames.bossCollapseStart:
        if (_carrier && !{'collapse', 'victory'}.contains(_target)) {
          _request('collapse', quantum: 'beat', dwell: 0, reason: event.name);
        }
      case GameEventNames.bossCollapseEnd:
        if (_carrier && _target == 'collapse') {
          _request('victory', dwell: 0, reason: event.name);
        }
    }
  }

  // --- the bar grid ---------------------------------------------------------

  /// Rolls the planned timeline forward to [now]: a pending move that has
  /// landed becomes the section, and a tail or bridge hands over to its next
  /// section at its end.
  void _advance(double now) {
    final s = _song;
    if (s == null) return;
    for (var guard = 0; guard < 16; guard++) {
      final current = section == null ? null : s.sections[section];
      final edge = (current != null && start != null && current.next != null)
          ? start! + current.bars * s.barSeconds
          : double.infinity;
      final pending = pendingAt;
      if (pending != null && pending <= now && pending <= edge) {
        section = pendingSection;
        start = pending;
        pendingSection = pendingAt = null;
        _pendingStep = null;
      } else if (edge <= now) {
        section = current!.next;
        start = edge;
        _log(SongStep(song!, section!, edge, 'end'));
      } else {
        return;
      }
    }
  }

  /// Adopts what the player reports when it differs (a slipped move, or a
  /// start it chose alone).
  void _sync(double now) {
    _advance(now);
    final p = clock.position;
    if (p == null || p.song != song) return;
    if (pendingAt != null && pendingAt! > now) return;
    section = p.section;
    start = p.start;
  }

  /// The section the music is in or heading to.
  String? get _target => pendingSection ?? section;

  /// The first [beats]-line of the playing section at least [margin] ahead.
  double? _nextLine(double now, int beats) {
    final s = _song, origin = start;
    if (s == null || origin == null || now < 0) return null;
    final unit = s.beatSeconds * beats;
    final k = ((now + margin - origin) / unit - 1e-9).ceil();
    return origin + math.max(0, k) * unit;
  }

  String _variantFor(String id) =>
      (_isHatch(id) && _shieldFailing) || (id == 'core' && _moduleLost)
      ? 'v2'
      : 'v1';
  bool _isHatch(String? id) => id != null && _song?.sections[id]?.hatch != null;

  void _request(
    String id, {
    String quantum = 'bar',
    int dwell = scoreDwellBars,
    required String reason,
  }) {
    final s = _song;
    if (s == null || !s.sections.containsKey(id)) return;
    final now = clock.now;
    _sync(now);
    var at = _nextLine(now, quantum == 'beat' ? 1 : 4);
    if (at != null && dwell > 0 && start != null && section != null) {
      // Minimum dwell: wait for the section's first [dwell] bars.
      final dwellEnd = start! + dwell * s.barSeconds;
      if (at < dwellEnd) at = dwellEnd;
    }
    final landed = _send(
      SongMove(
        song: song!,
        section: id,
        at: at ?? -1,
        quantum: quantum,
        tier: tier,
        variant: _variantFor(id),
        fleet: fleet,
        reason: reason,
      ),
    );
    _landed(id, landed, reason);
  }

  void _landed(String id, double landed, String reason) {
    if (landed == -2) {
      _stop();
      return;
    }
    if (landed < 0) {
      // The player starts it once it is ready; its grid is unknown till then.
      section = id;
      start = null;
      pendingSection = pendingAt = null;
      _log(SongStep(song!, id, null, reason));
      return;
    }
    // The latest request replaces a waiting one.
    if (_pendingStep != null) log.remove(_pendingStep);
    pendingSection = id;
    pendingAt = landed;
    _log(_pendingStep = SongStep(song!, id, landed, reason));
  }

  SongStep? _pendingStep;

  /// Keeps the log in time order (an auto hand-over can be planned after a
  /// later move was requested).
  void _log(SongStep step) {
    var i = log.length;
    final at = step.at;
    if (at != null) {
      while (i > 0 && (log[i - 1].at ?? -1) > at) {
        i--;
      }
    }
    log.insert(i, step);
  }

  void _mask({
    required String reason,
    int? tier,
    String? variant,
    bool? fleet,
  }) {
    final now = clock.now;
    _sync(now);
    _send(
      SongMove(
        song: song!,
        at: _nextLine(now, 4) ?? -1,
        tier: tier,
        variant: variant,
        fleet: fleet,
        reason: reason,
      ),
    );
  }

  void _startSong(
    String id, {
    required int level,
    required int cycle,
    required String mode,
    required int phase,
  }) {
    final previous = song;
    song = id;
    _level = level;
    _cycle = cycle;
    _shieldFailing = _moduleLost = fleet = false;
    pendingSection = pendingAt = null;
    _pendingStep = null;
    final now = clock.now;
    // Within one song the arrival starts on its bar line; from another song
    // or recorded music the player picks that music's next bar line.
    double at = -1;
    if (previous == id) {
      _sync(now);
      at = _nextLine(now, 4) ?? -1;
    }
    section = null;
    start = null;
    final landed = _send(
      SongMove(
        song: id,
        section: 'arrival',
        at: at,
        tier: tier,
        variant: 'v1',
        fleet: false,
        reason: mode,
        fallback: {
          'mode': mode,
          'level': level,
          'phase': phase,
          'cycle': cycle,
        },
      ),
    );
    if (landed >= 0) {
      section = 'arrival';
      start = landed;
      _log(SongStep(id, 'arrival', landed, mode));
    } else {
      _landed('arrival', landed, mode);
    }
  }

  bool _stop() {
    song = section = start = pendingSection = pendingAt = null;
    _pendingStep = null;
    return false;
  }

  /// The sector's wave-progress section for the current share: A on the first
  /// wave, D on the last; it only ever moves forward.
  void _waveProgress(String reason) {
    final s = _song!, share = waveShare?.call();
    if (share == null) return;
    final waves = s.waveSections;
    if (waves.isEmpty) return;
    final index = (share.clamp(0.0, 1.0) * (waves.length - 1)).round();
    final want = waves[index];
    final target = _target;
    final have = target == null ? null : s.sections[target];
    if (have?.wave != null && have!.wave! >= want.wave!) return;
    if (have?.wave == null && target != 'arrival') return; // the clear
    if (target == 'arrival' && want.wave == 1) return; // the arrival hands over
    _request(want.id, reason: reason);
  }

  /// `bossHatchTier`: tier k of U upper tiers plays hatch section k, or (when
  /// the song has fewer) the nearest by depth; the core tier (U + 1) needs no
  /// move of its own (the transformation leads into it).
  String? _hatchSection(Map<String, Object?> data) {
    final k = (data['tier'] as num?)?.toInt();
    final tiers = (data['tiers'] as num?)?.toInt();
    if (k == null || k < 1) return null;
    final upper = tiers == null ? k : tiers - 1;
    if (k > upper) return null;
    final hatches = _song!.hatchSections;
    if (hatches.isEmpty) return null;
    final n = hatches.length;
    final index = upper <= n
        ? k
        : (1 + (k - 1) / math.max(1, upper - 1) * (n - 1)).round();
    return hatches[index.clamp(1, n) - 1].id;
  }

  /// The level and route of the playing song (diagnostics and the console).
  ({int level, int cycle}) get scene => (level: _level, cycle: _cycle);
}
