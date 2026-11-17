import 'package:demon_attack/game/game_events.dart';
import 'package:demon_attack/game/music_director.dart';
import 'package:demon_attack/game/song_director.dart';
import 'package:demon_attack/game/song_map.dart';
import 'package:flutter_test/flutter_test.dart';

/// A music clock the test moves by hand; the player reports nothing.
class FakeClock implements SongClock {
  @override
  double now = 0;
  @override
  ({String song, String section, double start})? position;
}

/// The player's contract (demon-score.js move()): a move with a time lands on
/// it; a move without one lands on the playing music's next bar line, here
/// [recordedBar] (a recorded cue's bar line).
class FakePlayer {
  final moves = <SongMove>[];
  double recordedBar = 10;
  double reply = 0;
  double call(SongMove move) {
    moves.add(move);
    if (reply < 0) return reply;
    return move.at >= 0 ? move.at : recordedBar;
  }
}

void main() {
  final carrier = scoreSongs['c1']!, krybor = scoreSongs['k']!;
  final cb = carrier.barSeconds, kb = krybor.barSeconds;

  // Whether [t] is on a [unit] line counted from [origin].
  bool onLine(double t, double origin, double unit) {
    final k = (t - origin) / unit;
    return (k - k.roundToDouble()).abs() < 1e-6;
  }

  ({SongDirector director, FakeClock clock, FakePlayer player}) rig({
    double share = 0,
    double Function()? waveShare,
  }) {
    final clock = FakeClock(), player = FakePlayer();
    final director = SongDirector(
      sendMove: player.call,
      clock: clock,
      waveShare: waveShare ?? () => share,
    );
    return (director: director, clock: clock, player: player);
  }

  test('the song map has the sector song and the carrier fight graph', () {
    expect(scorePlays, {1: 'k', 5: 'c1'});
    expect(krybor.waveSections.map((s) => s.id), ['A', 'B', 'C', 'D']);
    expect(carrier.hatchSections.map((s) => s.id), ['H1', 'H2']);
    expect(carrier.sections['transform']!.kind, ScoreKind.bridge);
    expect(carrier.sections['transform']!.next, 'core');
    expect(carrier.sections['arrival']!.next, 'approach');
    expect(carrier.sections['collapse']!.next, 'victory');
    expect(krybor.sections['clear']!.hold, 1);
  });

  test(
    'a sector: arrival on the recorded bar line, A at its end, wave progress '
    'and the clear on the score\'s own lines',
    () {
      var share = 0.0;
      final r = rig(waveShare: () => share);
      final d = r.director, clock = r.clock;
      clock.now = 9.4;
      expect(d.cue('level', level: 1), isTrue);
      expect(d.log.single.section, 'arrival');
      expect(d.log.single.at, 10, reason: 'the recorded cue\'s next bar line');
      expect(r.player.moves.single.fallback?['mode'], 'level');
      // The arrival hands over to A on its last bar line.
      clock.now = 10 + 4 * kb + .05;
      d.onGameEvent(const GameEvent(GameEventNames.waveStart));
      expect(d.section, 'A');
      expect(d.log.last.at, closeTo(10 + 4 * kb, 1e-9));
      // Wave 2 of 4: B on the next bar line.
      share = 1 / 3;
      clock.now += 3.3 * kb;
      d.onGameEvent(const GameEvent(GameEventNames.cohortMerged));
      d.onGameEvent(const GameEvent(GameEventNames.waveStart));
      expect(d.log.map((s) => s.section), ['arrival', 'A', 'B']);
      final b = d.log.last.at!;
      expect(onLine(b, 10, kb), isTrue);
      expect(b - clock.now, inInclusiveRange(SongDirector.margin, kb + .3));
      // Intensity: a mask on the next bar, the section keeps playing.
      clock.now = b + 1.2 * kb;
      d.onGameEvent(
        const GameEvent(GameEventNames.musicIntensity, {'tier': 3}),
      );
      final mask = r.player.moves.last;
      expect(mask.section, isNull);
      expect(mask.tier, 3);
      expect(onLine(mask.at, 10, kb), isTrue);
      // Wave share never moves backwards; the last wave is D.
      share = 1;
      clock.now = b + 4 * kb;
      d.onGameEvent(const GameEvent(GameEventNames.waveStart));
      expect(d.log.last.section, 'D');
      share = 0;
      d.onGameEvent(const GameEvent(GameEventNames.waveStart));
      expect(d.log.last.section, 'D');
      // The clear lands on the next beat line.
      clock.now = d.log.last.at! + 2.3 * kb;
      expect(d.cue('levelclear', level: 1), isTrue);
      expect(d.log.last.section, 'clear');
      expect(onLine(d.log.last.at!, 10, kb / 4), isTrue);
      // The travel rides the clear's hold; the next sector has no score.
      expect(d.cue('travel', level: 1), isTrue);
      expect(d.cue('level', level: 2), isFalse);
      expect(d.song, isNull);
    },
  );

  test('the carrier fight: approach, hatch tiers, transform, core, collapse, '
      'victory, each on a bar line (the collapse on a beat)', () {
    final r = rig();
    final d = r.director, clock = r.clock;
    clock.now = 9.6;
    expect(d.cue('level', level: 5), isTrue);
    final origin = d.log.single.at!;
    // The approach follows the 4-bar arrival.
    clock.now = origin + 4 * cb + .1;
    d.onGameEvent(const GameEvent(GameEventNames.bossApproach, {'step': 1}));
    expect(d.section, 'approach');
    final approach = origin + 4 * cb;
    // Two hatch tiers in quick succession: only the later one plays, after
    // the minimum dwell (two bars of the approach).
    clock.now = approach + .5 * cb;
    d.onGameEvent(
      const GameEvent(GameEventNames.bossHatchTier, {'tier': 1, 'tiers': 3}),
    );
    clock.now = approach + 1.1 * cb;
    d.onGameEvent(
      const GameEvent(GameEventNames.bossHatchTier, {'tier': 2, 'tiers': 3}),
    );
    expect(d.log.map((s) => s.section), ['arrival', 'approach', 'H2']);
    expect(d.log.last.at, closeTo(approach + 2 * cb, 1e-9));
    // The rise and the transformation re-send `boss`: no restart.
    expect(d.cue('boss', level: 5), isTrue);
    expect(d.log.length, 3);
    // The shield fails: the v2 layer on the next bar, same section.
    clock.now = approach + 3.2 * cb;
    d.onGameEvent(const GameEvent(GameEventNames.bossShieldFailing));
    expect(r.player.moves.last.variant, 'v2');
    expect(r.player.moves.last.section, isNull);
    // The transformation: the 3-bar bridge on the next bar line, then the
    // core on its last bar line; the core tier and the core door move
    // nothing.
    clock.now = approach + 4.4 * cb;
    d.onGameEvent(
      const GameEvent(GameEventNames.bossTransform, {'stage': 'start'}),
    );
    final transform = d.log.last.at!;
    expect(d.log.last.section, 'transform');
    expect(transform, closeTo(approach + 5 * cb, 1e-9));
    clock.now = transform + 2.77 * cb;
    d.onGameEvent(
      const GameEvent(GameEventNames.bossTransform, {'stage': 'end'}),
    );
    d.onGameEvent(const GameEvent(GameEventNames.bossCoreExposed));
    d.onGameEvent(
      const GameEvent(GameEventNames.bossHatchTier, {'tier': 3, 'tiers': 3}),
    );
    clock.now = transform + 3 * cb + .05;
    d.onGameEvent(const GameEvent(GameEventNames.bossModuleLost));
    expect(d.section, 'core');
    expect(d.log.last.at, closeTo(transform + 3 * cb, 1e-9));
    expect(r.player.moves.last.variant, 'v2', reason: 'a module lost');
    // The collapse on the next beat line, the victory on the collapse's
    // next bar line after its end event.
    clock.now = transform + 3 * cb + 5.3 * cb;
    expect(d.cue('victory', level: 5), isTrue);
    d.onGameEvent(const GameEvent(GameEventNames.bossCollapseStart));
    final collapse = d.log.last;
    expect(collapse.section, 'collapse');
    expect(onLine(collapse.at!, origin, cb / 4), isTrue);
    clock.now = collapse.at! + 5.5;
    d.onGameEvent(const GameEvent(GameEventNames.bossCollapseEnd));
    expect(d.log.last.section, 'victory');
    expect(onLine(d.log.last.at!, collapse.at!, cb), isTrue);
    expect(d.cue('travel', level: 5), isTrue, reason: 'the victory holds');
    expect(d.log.map((s) => s.section), [
      'arrival',
      'approach',
      'H2',
      'transform',
      'core',
      'collapse',
      'victory',
    ]);
    for (final step in d.log.where((s) => s.section != 'victory')) {
      expect(
        onLine(step.at!, origin, step.section == 'collapse' ? cb / 4 : cb),
        isTrue,
        reason: '$step',
      );
    }
  });

  test('the latest waiting request wins; a request after the dwell is not '
      'delayed', () {
    final r = rig();
    final d = r.director, clock = r.clock;
    clock.now = 9.9;
    d.cue('boss', level: 5);
    final origin = d.log.single.at!;
    clock.now = origin + 4 * cb + 3.5 * cb;
    d.onGameEvent(
      const GameEvent(GameEventNames.bossHatchTier, {'tier': 1, 'tiers': 3}),
    );
    // Past the dwell: the very next bar line.
    expect(d.log.last.section, 'H1');
    expect(d.log.last.at, closeTo(origin + 8 * cb, 1e-9));
    // A transformation requested before H1 has started replaces it.
    clock.now += .1;
    d.onGameEvent(
      const GameEvent(GameEventNames.bossTransform, {'stage': 'start'}),
    );
    expect(d.log.map((s) => s.section), ['arrival', 'approach', 'transform']);
    expect(d.pendingSection, 'transform');
  });

  test('more upper tiers than hatch sections map by depth', () {
    final r = rig();
    final d = r.director, clock = r.clock;
    d.cue('boss', level: 5);
    final seen = <String>[];
    for (var k = 1; k <= 4; k++) {
      clock.now += 3 * cb;
      d.onGameEvent(
        GameEvent(GameEventNames.bossHatchTier, {'tier': k, 'tiers': 5}),
      );
      seen.add(d.pendingSection ?? d.section!);
    }
    expect(seen, ['H1', 'H1', 'H2', 'H2']);
  });

  test('recorded cues: defeat, the finale, the menu and unscored sectors '
      'stop the score', () {
    final r = rig();
    final d = r.director;
    expect(d.cue('level', level: 3), isFalse);
    expect(d.cue('level', level: 5), isTrue);
    expect(d.cue('gameover', level: 5), isFalse);
    expect(d.song, isNull);
    expect(d.cue('level', level: 5), isTrue);
    expect(d.cue('completed', level: 5, cycle: 4), isFalse);
    expect(d.cue('menu'), isFalse);
    expect(d.cue('travel'), isFalse, reason: 'no score playing');
    final before = r.player.moves.length;
    d.onGameEvent(const GameEvent(GameEventNames.musicIntensity, {'tier': 4}));
    expect(r.player.moves.length, before, reason: 'no song, no moves');
  });

  test('a deferred start syncs to the player; a score that is off yields '
      'to the recorded cue', () {
    final r = rig();
    final d = r.director, clock = r.clock, player = r.player;
    player.reply = -1;
    d.cue('level', level: 5);
    expect(d.section, 'arrival');
    expect(d.start, isNull);
    player.reply = 0;
    clock.now = 30;
    clock.position = (song: 'c1', section: 'approach', start: 28.0);
    d.onGameEvent(
      const GameEvent(GameEventNames.bossHatchTier, {'tier': 1, 'tiers': 3}),
    );
    expect(d.log.last.section, 'H1');
    expect(d.log.last.at, closeTo(28 + 2 * cb, 1e-9));
    player.reply = -2;
    clock.position = null;
    expect(d.cue('level', level: 1), isTrue, reason: 'the fallback plays');
    expect(d.song, isNull);
  });

  test('the fleet layer and the bridge accents', () {
    final r = rig();
    final d = r.director;
    d.cue('level', level: 1);
    d.onGameEvent(const GameEvent(GameEventNames.fleetIntact));
    d.onGameEvent(const GameEvent(GameEventNames.fleetIntact));
    expect(
      r.player.moves.where((m) => m.fleet == true && m.section == null),
      hasLength(1),
    );
    final accents = <String>[];
    final bridge = MusicBridge(
      onIntensity: (_) {},
      onAccent: accents.add,
      onFleetIntact: () {},
      onPowerLayer: (_, _) {},
    );
    for (final name in [
      GameEventNames.bossHatchTelegraph,
      GameEventNames.bossLaunch,
      GameEventNames.bossHatchFieldDown,
      GameEventNames.bossHatchDrop,
      GameEventNames.bossWreckFalls,
      GameEventNames.bossApproach,
    ]) {
      bridge(GameEvent(name));
    }
    expect(accents, ['riser', 'stab', 'glass', 'impact', 'impact', 'toll']);
  });

  test('moves serialise for the web player', () {
    const move = SongMove(
      song: 'c1',
      section: 'H1',
      at: 12.5,
      tier: 2,
      variant: 'v1',
      fleet: false,
      reason: 'bossHatchTier',
    );
    expect(move.toJson(), {
      'song': 'c1',
      'section': 'H1',
      'at': 12.5,
      'quantum': 'bar',
      'enter': 'start',
      'tier': 2,
      'variant': 'v1',
      'fleet': false,
      'reason': 'bossHatchTier',
    });
  });
}
