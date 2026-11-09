import '../services/audio.dart';
import 'model.dart';

/// Derives adaptive-music commands from the simulation, read-only.
///
/// The scene calls [observe] once per frame after the model has stepped. The
/// director never writes to the model: it reads wave progress, reinforcement
/// arrivals, elites and sentinels, dive and last-stand tells, the carrier's
/// form, shield and hatches, and the player's lives, and turns them into an
/// intensity tier (1 calm .. 4 peril) for the current level's music and into
/// short accents. The JS player quantizes both to the 120 BPM grid. A
/// `fleetIntact` event (whole allied fleet survived, emitted at level clear and
/// campaign victory) selects the bigger celebration; without it the normal
/// march plays.
class MusicDirector {
  MusicDirector({
    void Function(int)? onIntensity,
    void Function(String)? onAccent,
    void Function()? onFleetIntact,
  }) : onIntensity = onIntensity ?? audioIntensity,
       onAccent = onAccent ?? audioAccent,
       onFleetIntact = onFleetIntact ?? audioFleetIntact;

  final void Function(int) onIntensity;
  final void Function(String) onAccent;
  final void Function() onFleetIntact;

  /// Seconds a lower target must hold before the music steps down.
  static const calmDelay = 4.0;

  /// Seconds a reinforcement arrival keeps the music one tier up.
  static const reinforcementLift = 6.0;

  /// Minimum seconds between two accents of one kind (dive tells come often,
  /// the carrier's central hatch opens about every four seconds).
  static const accentSpacing = {
    'dive': 2.0,
    'hatch': 7.5,
    'laststand': 1.0,
    'reinforce': 1.0,
  };
  final Map<String, double> _lastAccent = {};

  int? sentTier;
  int target = 1;
  double _lowerFor = 0, _reinforced = 0, _clock = 0;
  final Set<Demon> _telling = {}, _lastStands = {};
  bool _hatchOpen = false;
  (int, int)? _scene;

  /// The intensity the current state asks for, before hysteresis.
  static int targetTier(ArcadeModel model, {bool reinforced = false}) {
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
      if (reinforced) tier++;
      if (model.demons.any((d) => d.lastStand || (d.isLarge && d.dive > 0))) {
        tier = 4;
      }
    }
    if (model.lives <= 1) tier++;
    return tier.clamp(1, 4);
  }

  void observe(ArcadeModel model, double dt) {
    final scene = (model.level, model.cycle);
    if (scene != _scene) {
      _scene = scene;
      _reset();
    }
    // Seen in any mode, before main.dart takes the events and cues the
    // celebration, so the player can choose the variant at its start.
    if (model.events.contains('fleetIntact')) onFleetIntact();
    if (model.mode != RunMode.playing) {
      // Wave transitions keep the current tier; any other phase belongs to
      // the cue events (clear, travel, victory, defeat) and resets the director.
      if (model.mode != RunMode.paused && !model.waveTransition) _reset();
      return;
    }
    _clock += dt;
    if (model.events.contains('reinforcements')) {
      _reinforced = reinforcementLift;
      _accent('reinforce');
    }
    _reinforced = (_reinforced - dt).clamp(0, reinforcementLift);
    _accents(model);
    final wanted = targetTier(model, reinforced: _reinforced > 0);
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
      onIntensity(target);
    }
  }

  void _accents(ArcadeModel model) {
    // A new dive tell (telegraph) warns; a new last stand gets its own tell.
    final telling = model.demons
        .where((d) => d.telegraph > 0 && !d.lastStand)
        .toSet();
    if (telling.difference(_telling).isNotEmpty) _accent('dive');
    _telling
      ..clear()
      ..addAll(telling);
    final stands = model.demons.where((d) => d.lastStand).toSet();
    if (stands.difference(_lastStands).isNotEmpty) _accent('laststand');
    _lastStands
      ..clear()
      ..addAll(stands);
    final carrier = model.boss;
    // The central hatch is the carrier's tell: its core is exposed.
    final open = carrier != null && carrier.door >= .6;
    if (open && !_hatchOpen) _accent('hatch');
    _hatchOpen = open;
  }

  void _accent(String name) {
    final last = _lastAccent[name];
    if (last != null && _clock - last < (accentSpacing[name] ?? 1)) return;
    _lastAccent[name] = _clock;
    onAccent(name);
  }

  void _reset() {
    sentTier = null;
    target = 1;
    _lowerFor = _reinforced = 0;
    _telling.clear();
    _lastStands.clear();
    _hatchOpen = false;
    _lastAccent.clear();
  }

  /// Seconds of playing time observed (diagnostics for tests).
  double get clock => _clock;
}
