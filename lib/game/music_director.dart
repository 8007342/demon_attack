import '../services/audio.dart';
import 'model.dart';

/// Derives adaptive-music events from the simulation, read-only.
///
/// The scene calls [observe] once per frame after the model has stepped
/// (`// --- music event hook`). The director never writes to the model: it
/// reads wave progress, reinforcement arrivals, elites and sentinels, dive and
/// last-stand tells, the carrier's form, shield and hatch, and the player's
/// lives. It publishes what it finds on the shared game-event bridge
/// (`dispatchGameEvent`, lib/game/game_events.dart): `musicIntensity` (tier
/// 1 calm .. 4 peril), `diveTell`, `lastStandTell`, `carrierHatchOpen` and
/// `reinforcementsArrived`. It also listens there ([onGameEvent]): allies under
/// attack and demon ground units in range lift the tier like reinforcements.
/// [MusicBridge] turns the events, and `fleetIntact`, into music.
class MusicDirector {
  MusicDirector({void Function(GameEvent)? emit})
    : emit = emit ?? dispatchGameEvent;

  final void Function(GameEvent) emit;

  /// Seconds a lower target must hold before the music steps down.
  static const calmDelay = 4.0;

  /// Seconds a reinforcement arrival (or ground threat) keeps the music one tier up.
  static const reinforcementLift = 6.0;

  /// Minimum seconds between two tells of one kind (dive tells come often,
  /// the carrier's central hatch opens about every four seconds).
  static const tellSpacing = {
    GameEventNames.diveTell: 2.0,
    GameEventNames.carrierHatchOpen: 7.5,
    GameEventNames.lastStandTell: 1.0,
    GameEventNames.reinforcementsArrived: 1.0,
  };

  /// Ground-war pressure (the `groundPressure` event's 0..1 level) adds a
  /// tier at 0.4 and two at 0.8.
  static const pressureSteps = [0.4, 0.8];

  /// Ground-war events (from the shared bridge) that raise the tension.
  static const groundThreats = {
    GameEventNames.allyUnderAttack,
    GameEventNames.groundForceInRange,
  };

  final Map<String, double> _lastTell = {};
  int? sentTier;
  int target = 1;
  double _lowerFor = 0, _lifted = 0, _clock = 0, _pressure = 0;
  final Set<Demon> _telling = {}, _lastStands = {};
  bool _hatchOpen = false;
  (int, int)? _scene;

  /// The intensity the current state asks for, before hysteresis.
  static int targetTier(
    ArcadeModel model, {
    bool lifted = false,
    double pressure = 0,
  }) {
    final carrier = model.boss;
    int tier;
    if (carrier != null) {
      // Later forms start higher; the final form is always tier 4.
      tier = 4 - (carrier.formCount - 1 - carrier.phase);
      if (carrier.shield == 0) tier++;
    } else {
      final planned = model.flocksPlanned;
      final waveShare = planned > 0 ? model.flocksSpawned / planned : 0.0;
      final progress = ((model.wave - 1) + waveShare) / model.wavesPerLevel;
      tier = 1 + (progress * 3).floor().clamp(0, 2);
      final live = model.demons.where((d) => !d.entering);
      if (live.any((d) => d.elite)) tier = tier < 2 ? 2 : tier;
      if (live.any((d) => d.isLarge)) tier = tier < 3 ? 3 : tier;
      if (lifted) tier++;
      if (model.demons.any((d) => d.lastStand || (d.isLarge && d.dive > 0))) {
        tier = 4;
      }
    }
    tier += pressureSteps.where((step) => pressure >= step).length;
    if (model.lives <= 1) tier++;
    return tier.clamp(1, 4);
  }

  /// Listener for the shared bridge: ground threats lift the tier.
  void onGameEvent(GameEvent event) {
    if (groundThreats.contains(event.name)) _lifted = reinforcementLift;
    if (event.name == groundPressure) {
      final value =
          event.data['level'] ?? event.data['pressure'] ?? event.data['value'];
      if (value is num) _pressure = value.toDouble().clamp(0.0, 1.0);
    }
  }

  /// Ground-war retune names (matched as strings; owned by game_events.dart).
  static const groundPressure = 'groundPressure';
  static const groundBreakthrough = 'groundBreakthrough';

  void observe(ArcadeModel model, double dt) {
    final scene = (model.level, model.cycle);
    if (scene != _scene) {
      _scene = scene;
      _reset();
    }
    if (model.mode != RunMode.playing) {
      // Wave transitions keep the current tier; any other phase belongs to
      // the cue events (clear, travel, victory, defeat) and resets the director.
      if (model.mode != RunMode.paused && !model.waveTransition) _reset();
      return;
    }
    _clock += dt;
    if (model.events.contains('reinforcements')) {
      _lifted = reinforcementLift;
      _tell(GameEventNames.reinforcementsArrived);
    }
    _lifted = (_lifted - dt).clamp(0, reinforcementLift);
    _tells(model);
    final wanted = targetTier(model, lifted: _lifted > 0, pressure: _pressure);
    if (sentTier == null || wanted > target) {
      target = wanted;
      _lowerFor = 0;
    } else if (wanted < target) {
      _lowerFor += dt;
      if (_lowerFor >= calmDelay) {
        target = wanted;
        _lowerFor = 0;
      }
    } else {
      _lowerFor = 0;
    }
    if (target != sentTier) {
      sentTier = target;
      emit(
        GameEvent(GameEventNames.musicIntensity, {
          'tier': target,
          'level': model.level,
        }),
      );
    }
  }

  void _tells(ArcadeModel model) {
    // A new dive tell (telegraph) warns; a new last stand gets its own tell.
    final telling = model.demons
        .where((d) => d.telegraph > 0 && !d.lastStand)
        .toSet();
    if (telling.difference(_telling).isNotEmpty) _tell(GameEventNames.diveTell);
    _telling
      ..clear()
      ..addAll(telling);
    final stands = model.demons.where((d) => d.lastStand).toSet();
    if (stands.difference(_lastStands).isNotEmpty) {
      _tell(GameEventNames.lastStandTell);
    }
    _lastStands
      ..clear()
      ..addAll(stands);
    // The central hatch is the carrier's tell: its core is exposed.
    final carrier = model.boss;
    final open = carrier != null && carrier.door >= .6;
    if (open && !_hatchOpen) _tell(GameEventNames.carrierHatchOpen);
    _hatchOpen = open;
  }

  void _tell(String name) {
    final last = _lastTell[name];
    if (last != null && _clock - last < (tellSpacing[name] ?? 1)) return;
    _lastTell[name] = _clock;
    emit(GameEvent(name));
  }

  void _reset() {
    sentTier = null;
    target = 1;
    _lowerFor = _lifted = _pressure = 0;
    _telling.clear();
    _lastStands.clear();
    _hatchOpen = false;
    _lastTell.clear();
  }
}

/// Shared-bridge listener that plays the music events (registered once in
/// main.dart with `GameEvents.listen`). Tells become accents in the level's
/// motif; `fleetIntact` picks the bigger fleet celebration (without it the
/// normal march plays).
class MusicBridge {
  MusicBridge({
    void Function(int)? onIntensity,
    void Function(String)? onAccent,
    void Function()? onFleetIntact,
  }) : onIntensity = onIntensity ?? audioIntensity,
       onAccent = onAccent ?? audioAccent,
       onFleetIntact = onFleetIntact ?? audioFleetIntact;

  final void Function(int) onIntensity;
  final void Function(String) onAccent;
  final void Function() onFleetIntact;

  static const accents = {
    GameEventNames.diveTell: 'dive',
    GameEventNames.lastStandTell: 'laststand',
    GameEventNames.carrierHatchOpen: 'hatch',
    GameEventNames.reinforcementsArrived: 'reinforce',
    MusicDirector.groundBreakthrough: 'breakthrough',
  };

  void call(GameEvent event) {
    final accent = accents[event.name];
    if (accent != null) {
      onAccent(accent);
    } else if (event.name == GameEventNames.musicIntensity) {
      onIntensity((event.data['tier'] as int?) ?? 1);
    } else if (event.name == GameEventNames.fleetIntact) {
      onFleetIntact();
    }
  }
}
