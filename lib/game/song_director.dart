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
    this.then,
    required this.reason,
  });
  final String song;

  /// The section to move to; null for a mask change only.
  final String? section;

  /// The landing time on the music clock (a bar or beat line of the playing
  /// section); -1 lets the player pick the next [quantum] line itself.
  final double at;

  /// 'bar', 'beat' or 'now' (30 ms ahead, cancelling what was scheduled).
  final String quantum;

  /// 'start' (the section's first bar) or 'same' (the same bar position).
  final String enter;
  final int? tier;

  /// 'v1' or 'v2' (the v2 layer: harmony lead and choir).
  final String? variant;

  /// The fleet layer (the brass fanfare of an intact fleet).
  final bool? fleet;

  /// `song:section` the section hands over to at its end, in place of its
  /// own `next` (the bridge into the tour's carrier).
  final String? then;

  /// The event that asked for it (diagnostics).
  final String reason;

  Map<String, Object?> toJson() => {
    'song': song,
    'section': ?section,
    'at': at,
    'quantum': quantum,
    'enter': enter,
    'tier': ?tier,
    'variant': ?variant,
    'fleet': ?fleet,
    'then': ?then,
    'reason': reason,
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
/// design §4.3, §11.7, §12). Pure Dart: no dart:ui, no audio; [send] and
/// [clock] are injected (main.dart wires them to the web audio engine).
///
/// It owns the song graph of the whole run: the overture, which song each
/// sector plays (`scoreSongFor`: the four worlds, each tour's carrier), the
/// bridge songs between them (`scoreBridges`), the sector's arrival,
/// wave-progress, bonus-level and clear sections, the carrier's hatch tiers,
/// transformation, core, collapse and victory, the last carrier's finale into
/// the coda, and the defeat. It keeps its own picture of the bar grid
/// (section starts on the music clock), so every move it sends lands on a bar
/// line (or a beat line for the collapse and the clear), and it applies the
/// rules of design §4.3: a section requested within [scoreDwellBars] bars of
/// the last start waits until they have played, and the latest waiting
/// request wins (two hatch tiers in quick succession play only the later
/// one). The player re-checks each time against what it has already
/// scheduled. There is no recorded music: every scene plays the score.
class SongDirector {
  SongDirector({
    double Function(SongMove move)? sendMove,
    SongClock? clock,
    this.waveShare,
    String? Function(int level, int cycle)? songFor,
    Map<String, ScoreSong>? songs,
  }) : _send = sendMove ?? ((m) => audioSong(m.toJson())),
       clock = clock ?? const AudioSongClock(),
       songFor = songFor ?? scoreSongFor,
       songs = songs ?? scoreSongs;

  final double Function(SongMove move) _send;
  final SongClock clock;
  final String? Function(int level, int cycle) songFor;
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

  /// `song:section` the playing (or the pending) section hands over to in
  /// place of its own `next`.
  String? then, pendingThen;
  int tier = 1;
  bool fleet = false;
  bool _shieldFailing = false, _moduleLost = false;
  int _level = 1, _cycle = 0;
  final List<SongStep> log = [];

  ScoreSong? get _song => song == null ? null : songs[song];
  bool get _carrier => _song?.form == 'carrier';
  bool get _sector => _song?.form == 'sector';

  /// A scene cue from the game (main.dart's raw events). Returns whether the
  /// score plays it; false means the cue has no score (nothing new plays).
  bool cue(String mode, {int level = 1, int phase = 1, int cycle = 0}) {
    _advance(clock.now);
    switch (mode) {
      case 'menu':
        return _scene('menu', mode);
      case 'gameover':
        return _scene('gameover', mode, quantum: 'now');
      case 'level' || 'boss':
        final id = songFor(level, cycle);
        _level = level;
        _cycle = cycle;
        if (id == null || !songs.containsKey(id)) return _stop();
        // The carrier's repeated cues (the rise, a form change, the
        // transformation) never restart its song.
        if (mode == 'boss' && song == id && _carrier) return true;
        // Already arriving: the travel's bridge leads into it, or it is in
        // its arrival.
        if (_heading(id) || (song == id && _target == 'arrival')) return true;
        final bridge = _bridgeTo(id);
        if (bridge != null) {
          _startSong(bridge, 'pivot', reason: mode, then: '$id:arrival');
        } else {
          _startSong(id, 'arrival', reason: mode);
        }
        return true;
      case 'levelclear':
        if (!_sector) return false;
        _request('clear', quantum: 'beat', dwell: 0, reason: 'levelClear');
        return true;
      case 'travel':
        // The clear's (or the victory's) written bars play out; then the
        // bridge into the next sector's song. Its hold bars carry the travel
        // where no bridge is needed.
        if (song == null) return false;
        _travel(level, cycle);
        return true;
      case 'victory':
        if (_song?.form == 'coda') return true;
        if (!_carrier) return false;
        if (!_collapsing) {
          _request('collapse', quantum: 'beat', dwell: 0, reason: 'victory');
        }
        return true;
      case 'completed':
        // The last carrier's collapse and victory run on into its finale and
        // the coda by themselves.
        if (_carrier || _song?.form == 'coda') return true;
        return _scene('ending', mode);
      case 'ending':
        return _ending();
      default:
        return false;
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
      case GameEventNames.bonusStart:
        if (_sector) _bonus(event.data['variant'] as String?, event.name);
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
        if (_carrier && !_collapsing) {
          _request('collapse', quantum: 'beat', dwell: 0, reason: event.name);
        }
      case GameEventNames.bossCollapseEnd:
        if (_carrier && _target == 'collapse') {
          _request('victory', dwell: 0, reason: event.name);
        }
    }
  }

  /// The collapse, the victory and (the last carrier) its finale and the
  /// worldized bridge: the fight is over.
  bool get _collapsing =>
      {'collapse', 'victory', 'finale', 'worldized'}.contains(_target);

  // --- the bar grid ---------------------------------------------------------

  /// `song:section` (or a section of the same song) that [id] hands over to.
  (String, String)? _successor(String id, String? override) {
    final next = override ?? _song?.sections[id]?.next;
    if (next == null) return null;
    final i = next.indexOf(':');
    return i < 0
        ? (song!, next)
        : (next.substring(0, i), next.substring(i + 1));
  }

  /// Rolls the planned timeline forward to [now]: a pending move that has
  /// landed becomes the section, and a tail or bridge hands over to its next
  /// section (of this song or the next) at its end.
  void _advance(double now) {
    for (var guard = 0; guard < 16; guard++) {
      final s = _song;
      if (s == null) return;
      final current = section == null ? null : s.sections[section];
      final successor = current == null ? null : _successor(current.id, then);
      final edge = (current != null && start != null && successor != null)
          ? start! + current.bars * s.barSeconds
          : double.infinity;
      final pending = pendingAt;
      if (pending != null && pending <= now && pending <= edge) {
        section = pendingSection;
        start = pending;
        then = pendingThen;
        pendingSection = pendingAt = pendingThen = null;
        _pendingStep = null;
      } else if (edge <= now) {
        final (nextSong, nextSection) = successor!;
        if (nextSong != song) _enteredSong(nextSong);
        section = nextSection;
        start = edge;
        then = null;
        _log(SongStep(song!, section!, edge, 'end'));
      } else {
        return;
      }
    }
  }

  /// A new song begins: its layers start over (the tier carries on).
  void _enteredSong(String id) {
    song = id;
    _shieldFailing = _moduleLost = fleet = false;
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

  /// The song a bridge (playing or pending) leads into.
  String? get _bridgeDestination {
    if (_song?.form != 'bridge') return null;
    final id = _target;
    if (id == null) return null;
    return _successor(id, pendingSection != null ? pendingThen : then)?.$1;
  }

  bool _heading(String id) => _bridgeDestination == id;

  /// The bridge song from the playing song into [id], if the map has one.
  String? _bridgeTo(String id) {
    final from = song;
    if (from == null || from == id) return null;
    String family(String s) => songs[s]?.form == 'carrier' ? 'c' : s;
    final bridge = scoreBridges['${family(from)}>${family(id)}'];
    return bridge != null && songs.containsKey(bridge) ? bridge : null;
  }

  /// The first [beats]-line of the playing section at least [margin] ahead.
  double? _nextLine(double now, int beats) {
    final s = _song, origin = start;
    if (s == null || origin == null || now < 0) return null;
    final unit = s.beatSeconds * beats;
    final k = ((now + margin - origin) / unit - 1e-9).ceil();
    return origin + math.max(0, k) * unit;
  }

  /// The end of the written bars of the tail or bridge the music is in or
  /// heading to (the clear's flourish before its hold), when still ahead.
  double? _writtenEnd(double now) {
    final s = _song, id = _target;
    final origin = pendingAt ?? start;
    final sec = id == null ? null : s?.sections[id];
    if (s == null || sec == null || origin == null) return null;
    if (sec.kind == ScoreKind.loop) return null;
    final end = origin + sec.bars * s.barSeconds;
    return end >= now + margin ? end : null;
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
    bool afterTail = false,
    required String reason,
  }) {
    final s = _song;
    if (s == null || !s.sections.containsKey(id)) return;
    final now = clock.now;
    _sync(now);
    var at =
        (afterTail ? _writtenEnd(now) : null) ??
        _nextLine(now, quantum == 'beat' ? 1 : 4);
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

  void _landed(String id, double landed, String reason, {String? then}) {
    if (landed == -2) {
      _stop();
      return;
    }
    if (landed < 0) {
      // The player starts it once it is ready; its grid is unknown till then.
      section = id;
      start = null;
      this.then = then;
      pendingSection = pendingAt = pendingThen = null;
      _log(SongStep(song!, id, null, reason));
      return;
    }
    // The latest request replaces a waiting one.
    if (_pendingStep != null) log.remove(_pendingStep);
    pendingSection = id;
    pendingAt = landed;
    pendingThen = then;
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

  /// Starts section [first] of song [id]: from the same song on its next bar
  /// line, at [at] when given (the end of a written tail), else on the
  /// playing music's next line (the player knows that grid).
  void _startSong(
    String id,
    String first, {
    required String reason,
    String quantum = 'bar',
    double at = -1,
    String? then,
  }) {
    final previous = song;
    final now = clock.now;
    if (previous == id && at < 0 && quantum != 'now') {
      _sync(now);
      at = _nextLine(now, 4) ?? -1;
    }
    _enteredSong(id);
    pendingSection = pendingAt = pendingThen = null;
    _pendingStep = null;
    section = null;
    start = null;
    this.then = null;
    final landed = _send(
      SongMove(
        song: id,
        section: first,
        at: at,
        quantum: quantum,
        tier: tier,
        variant: 'v1',
        fleet: false,
        then: then,
        reason: reason,
      ),
    );
    if (landed >= 0) {
      section = first;
      start = landed;
      this.then = then;
      _log(SongStep(id, first, landed, reason));
    } else {
      _landed(first, landed, reason, then: then);
    }
  }

  /// The overture, the defeat or the coda (`scoreScenes`).
  bool _scene(String name, String reason, {String quantum = 'bar'}) {
    final entry = scoreScenes[name];
    if (entry == null) return _stop();
    final i = entry.indexOf(':');
    final id = entry.substring(0, i), first = entry.substring(i + 1);
    if (!songs.containsKey(id)) return _stop();
    if (song == id) return true;
    _startSong(id, first, reason: reason, quantum: quantum);
    return true;
  }

  /// The ending opens: the last carrier's music thins into the worldized
  /// bridge on its next bar line and hands over to the coda's ukulele; from
  /// anywhere else (the credits from the title) the coda starts on the next
  /// bar line.
  bool _ending() {
    if (_song?.form == 'coda') return true;
    if (_carrier && _song!.sections.containsKey('worldized')) {
      if (_target != 'worldized') {
        _request('worldized', dwell: 0, reason: 'ending');
      }
      return true;
    }
    return _scene('ending', 'ending');
  }

  /// The travel after a clear or a carrier's victory: the bridge song into
  /// the next sector's song, from the end of the written tail.
  void _travel(int level, int cycle) {
    final next = level < 5 ? songFor(level + 1, cycle) : songFor(1, cycle + 1);
    if (next == null || next == song || _heading(next)) return;
    final bridge = _bridgeTo(next);
    if (bridge == null) return;
    final now = clock.now;
    _sync(now);
    final at = _writtenEnd(now) ?? _nextLine(now, 4) ?? -1;
    _startSong(
      bridge,
      'pivot',
      reason: 'travel',
      at: at,
      then: '$next:arrival',
    );
  }

  bool _stop() {
    song = section = start = pendingSection = pendingAt = null;
    then = pendingThen = null;
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
    // The clear and a bonus level's section stay.
    if (have?.wave == null && target != 'arrival') return;
    if (target == 'arrival' && want.wave == 1) return; // the arrival hands over
    _request(want.id, reason: reason);
  }

  /// A bonus level (`bonusStart`, its id in `variant`) plays its section of
  /// the sector's song for the whole level, from the end of the arrival.
  void _bonus(String? variant, String reason) {
    if (variant == null) return;
    final s = _song!;
    final section = s.sections.values.where((x) => x.bonus == variant);
    if (section.isEmpty || _target == section.first.id) return;
    _request(section.first.id, afterTail: true, reason: reason);
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
