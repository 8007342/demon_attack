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
/// [silentBar] (nothing has played yet).
class FakePlayer {
  final moves = <SongMove>[];
  double silentBar = 10;
  double reply = 0;
  double call(SongMove move) {
    moves.add(move);
    if (reply < 0) return reply;
    return move.at >= 0 ? move.at : silentBar;
  }
}

typedef Landing = ({double at, String song, String section, String? then});

/// A model of the web player's grid (demon-score.js): what it plays at any
/// time, following tails and bridges into their successors (`next`, or a
/// move's `then`); a move without a time lands on the next line of what is
/// playing, a `now` move 30 ms ahead; the latest pending move wins.
class GridPlayer {
  GridPlayer(this.clock);
  final FakeClock clock;
  final landings = <Landing>[];
  final moves = <(SongMove, double)>[];

  static (String, String) successor(String song, String next) {
    final i = next.indexOf(':');
    return i < 0 ? (song, next) : (next.substring(0, i), next.substring(i + 1));
  }

  /// The section playing at [t] and its start.
  Landing? playing(double t) {
    Landing? seg;
    for (final l in landings) {
      if (l.at <= t + 1e-9) seg = l;
    }
    if (seg == null) return null;
    for (var guard = 0; guard < 32; guard++) {
      final song = scoreSongs[seg!.song]!, spec = song.sections[seg.section]!;
      final next = seg.then ?? spec.next;
      if (spec.kind == ScoreKind.loop || next == null) return seg;
      final end = seg.at + spec.bars * song.barSeconds;
      if (end > t + 1e-9) return seg;
      final (s, x) = successor(seg.song, next);
      seg = (at: end, song: s, section: x, then: null);
    }
    return seg;
  }

  double nextLine(double after, int beats) {
    final seg = playing(after);
    if (seg == null) return after;
    final unit = scoreSongs[seg.song]!.beatSeconds * beats;
    final k = ((after - seg.at) / unit - 1e-9).ceil();
    return seg.at + k * unit;
  }

  double call(SongMove m) {
    final now = clock.now;
    if (m.section == null) {
      moves.add((m, m.at));
      return m.at;
    }
    final at = m.quantum == 'now'
        ? now + .03
        : m.at >= 0
        ? m.at
        : nextLine(now + .3, m.quantum == 'beat' ? 1 : 4);
    landings.removeWhere((l) => l.at > now + 1e-9);
    landings.add((at: at, song: m.song, section: m.section!, then: m.then));
    moves.add((m, at));
    return at;
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

  test('the song map covers the whole run', () {
    expect(scoreSongFor(1, 0), 'k');
    expect(scoreSongFor(2, 3), 'r');
    expect(scoreSongFor(3, 4), 'e');
    expect(scoreSongFor(4, 1), 'h');
    expect(
      [for (var c = 0; c <= 5; c++) scoreSongFor(5, c)],
      ['c1', 'c2', 'c3', 'c4', 'c5', 'c5'],
    );
    // Every tour's upper tiers have their own hatch section
    // (lib/game/carrier_hatches.dart: 2, 2, 3, 3, 4).
    expect(
      [
        for (var c = 0; c < 5; c++)
          scoreSongs[scoreSongFor(5, c)]!.hatchSections
              .map((s) => s.id)
              .toList(),
      ],
      [
        ['H1', 'H2'],
        ['H1', 'H2'],
        ['H1', 'H2', 'H3'],
        ['H1', 'H2', 'H3'],
        ['H1', 'H2', 'H3', 'H4'],
      ],
    );
    for (final id in ['k', 'r', 'e', 'h']) {
      final s = scoreSongs[id]!;
      expect(s.form, 'sector');
      expect(s.waveSections.map((x) => x.id), ['A', 'B', 'C', 'D']);
      expect(s.sections['storm']!.bonus, 'stormfront', reason: id);
      expect(s.sections['clear']!.hold, 1);
    }
    for (final id in ['c1', 'c2', 'c3', 'c4']) {
      expect(scoreSongs[id]!.sections['victory']!.hold, 1, reason: id);
    }
    final last = scoreSongs['c5']!.sections;
    expect(last['victory']!.next, 'finale');
    expect(last['finale']!.next, 'worldized');
    expect(last['worldized']!.next, 'coda:ukulele');
    expect(scoreSongs['coda']!.barSamples, carrier.barSamples * 2);
    // Every successor resolves, and every bridge song leads into its pair.
    for (final MapEntry(key: id, value: song) in scoreSongs.entries) {
      for (final section in song.sections.values) {
        final next = section.next;
        if (next == null) continue;
        final (s, x) = GridPlayer.successor(id, next);
        expect(scoreSongs[s]?.sections[x], isNotNull, reason: '$id/$next');
      }
    }
    for (final MapEntry(key: pair, value: bridge) in scoreBridges.entries) {
      final to = pair.split('>')[1];
      final next = scoreSongs[bridge]!.sections['pivot']!.next!;
      expect(next.startsWith(to == 'c' ? 'c1:' : '$to:'), isTrue, reason: pair);
    }
    expect(scoreScenes, {
      'menu': 'menu:overture',
      'gameover': 'defeat:cackle',
      'ending': 'coda:ukulele',
    });
  });

  test(
    'a sector: arrival on the playing bar line, A at its end, wave progress '
    'and the clear on the score\'s own lines, the bridge after the clear',
    () {
      var share = 0.0;
      final r = rig(waveShare: () => share);
      final d = r.director, clock = r.clock;
      clock.now = 9.4;
      expect(d.cue('level', level: 1), isTrue);
      expect(d.log.single.section, 'arrival');
      expect(d.log.single.at, 10, reason: 'the playing music\'s next line');
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
      final clear = d.log.last;
      expect(clear.section, 'clear');
      expect(onLine(clear.at!, 10, kb / 4), isTrue);
      // The travel: Krybor's bridge into Ringfall from the clear's last
      // written bar line, then Ringfall's arrival on the bridge's last line.
      clock.now = clear.at! + 2;
      expect(d.cue('travel', level: 1), isTrue);
      final bridge = r.player.moves.last;
      expect(
        (bridge.song, bridge.section, bridge.then),
        ('k-r', 'pivot', 'r:arrival'),
      );
      expect(bridge.at, closeTo(clear.at! + 4 * kb, 1e-9));
      // The next level's cue while the bridge waits restarts nothing.
      clock.now += 2;
      final count = r.player.moves.length;
      expect(d.cue('level', level: 2), isTrue);
      expect(r.player.moves.length, count);
      clock.now = bridge.at + 2 * kb + .01;
      d.onGameEvent(const GameEvent(GameEventNames.waveStart));
      expect((d.song, d.section), ('r', 'arrival'));
      expect(d.start, closeTo(bridge.at + 2 * kb, 1e-9));
    },
  );

  test('a Stormfront bonus level plays its storm from the arrival\'s end and '
      'stays there through the waves', () {
    var share = 0.0;
    final r = rig(waveShare: () => share);
    final d = r.director, clock = r.clock;
    final eb = scoreSongs['e']!.barSeconds;
    d.cue('level', level: 3, cycle: 1);
    final origin = d.log.single.at!;
    clock.now = origin + 1.5 * eb;
    d.onGameEvent(const GameEvent(GameEventNames.waveStart));
    d.onGameEvent(
      const GameEvent(GameEventNames.bonusStart, {'variant': 'stormfront'}),
    );
    expect(d.log.last.section, 'storm');
    expect(d.log.last.at, closeTo(origin + 4 * eb, 1e-9));
    share = 1;
    clock.now = origin + 9 * eb;
    d.onGameEvent(const GameEvent(GameEventNames.waveStart));
    expect(d.section, 'storm');
    expect(d.log.last.section, 'storm');
    // Supply Run has no section of its own: the waves play.
    final r2 = rig(waveShare: () => share);
    r2.director.cue('level', level: 2);
    r2.director.onGameEvent(
      const GameEvent(GameEventNames.bonusStart, {'variant': 'supplyRun'}),
    );
    expect(r2.director.log.map((s) => s.section), ['arrival']);
  });

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
    // The travel into the next route: the carrier's bridge into Krybor.
    clock.now += 2;
    expect(d.cue('travel', level: 5), isTrue);
    expect(
      (r.player.moves.last.song, r.player.moves.last.then),
      ('c-k', 'k:arrival'),
    );
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

  test('every tour plays its own hatch tiers natively; a song with fewer '
      'sections maps by depth', () {
    for (final (cycle, want) in [
      (2, ['H1', 'H2', 'H3']),
      (4, ['H1', 'H2', 'H3', 'H4']),
    ]) {
      final r = rig();
      final d = r.director, clock = r.clock;
      d.cue('boss', level: 5, cycle: cycle);
      final seen = <String>[];
      for (var k = 1; k <= want.length; k++) {
        clock.now += 3 * cb;
        d.onGameEvent(
          GameEvent(GameEventNames.bossHatchTier, {
            'tier': k,
            'tiers': want.length + 1,
          }),
        );
        seen.add(d.pendingSection ?? d.section!);
      }
      expect(seen, want, reason: 'tour ${cycle + 1}');
      expect(d.song, 'c${cycle + 1}');
    }
    // Depth: tour 5's four tiers on tour 1's two hatch sections.
    final clock = FakeClock(), player = FakePlayer();
    final d = SongDirector(
      sendMove: player.call,
      clock: clock,
      songFor: (_, _) => 'c1',
    );
    d.cue('boss', level: 5, cycle: 4);
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

  test('the scenes: the overture, the bridge on START, the defeat at once, '
      'the overture after it', () {
    final r = rig();
    final d = r.director, clock = r.clock, player = r.player;
    expect(d.cue('menu'), isTrue);
    expect(
      (player.moves.last.song, player.moves.last.section),
      ('menu', 'overture'),
    );
    expect(d.cue('menu'), isTrue);
    expect(player.moves, hasLength(1), reason: 'already playing');
    final mb = scoreSongs['menu']!.barSeconds;
    clock.now = 10 + 3.4 * mb;
    expect(d.cue('level', level: 1), isTrue);
    final start = player.moves.last;
    expect(
      (start.song, start.section, start.then),
      ('menu-k', 'pivot', 'k:arrival'),
    );
    expect(start.at, -1, reason: 'the player picks the overture\'s bar line');
    // The defeat cuts in at once.
    clock.now += 30;
    expect(d.cue('gameover', level: 2), isTrue);
    final defeat = player.moves.last;
    expect(
      (defeat.song, defeat.section, defeat.quantum),
      ('defeat', 'cackle', 'now'),
    );
    expect(d.cue('gameover', level: 2), isTrue);
    expect(player.moves.last, same(defeat), reason: 'no second cackle');
    expect(d.cue('menu'), isTrue);
    expect(player.moves.last.song, 'menu');
  });

  test('the last carrier: the ending opens the worldized bridge on the next '
      'bar line, which hands over to the coda\'s ukulele', () {
    final r = rig();
    final d = r.director, clock = r.clock;
    d.cue('boss', level: 5, cycle: 4);
    expect(d.song, 'c5');
    clock.now = 60;
    d.cue('victory', level: 5, cycle: 4);
    d.onGameEvent(const GameEvent(GameEventNames.bossCollapseStart));
    final collapse = d.log.last.at!;
    clock.now = collapse + 4;
    expect(d.cue('ending', level: 5, cycle: 4), isTrue);
    final worldized = d.log.last;
    expect(worldized.section, 'worldized');
    expect(onLine(worldized.at!, collapse, cb), isTrue);
    expect(d.cue('completed', level: 5, cycle: 4), isTrue);
    expect(d.log.last, same(worldized), reason: 'completed moves nothing');
    clock.now = worldized.at! + 6 * cb + .01;
    d.onGameEvent(const GameEvent(GameEventNames.musicIntensity, {'tier': 2}));
    expect((d.song, d.section), ('coda', 'ukulele'));
    expect(d.start, closeTo(worldized.at! + 6 * cb, 1e-9));
    // Closing the ending during the run, or the credits from the title.
    expect(d.cue('victory', level: 5, cycle: 4), isTrue);
    expect(d.song, 'coda');
    final r2 = rig();
    r2.director.cue('menu');
    expect(r2.director.cue('ending'), isTrue);
    expect(r2.player.moves.last.song, 'coda');
  });

  test('a full five-route campaign plays as one song: every section move '
      'lands on a line of the music playing before it', () {
    final clock = FakeClock();
    final player = GridPlayer(clock);
    var share = 0.0;
    final d = SongDirector(
      sendMove: player.call,
      clock: clock,
      waveShare: () => share,
    );
    void at(double t) => clock.now = t;
    void event(String name, [Map<String, Object?> data = const {}]) =>
        d.onGameEvent(GameEvent(name, data));
    var t = 1.0;
    at(t);
    d.cue('menu');
    t += 14;
    for (var cycle = 0; cycle <= 4; cycle++) {
      for (var level = 1; level <= 5; level++) {
        at(t);
        if (level < 5) {
          d.cue('level', level: level, cycle: cycle);
          final bonus = cycle == 1 && level == 3;
          for (var w = 0; w < 4; w++) {
            at(t += 9 + w * 1.7);
            share = w / 3;
            event(GameEventNames.waveStart);
            if (bonus && w == 0) {
              event(GameEventNames.bonusStart, {'variant': 'stormfront'});
            }
            at(t += 3.1);
            event(GameEventNames.musicIntensity, {'tier': 1 + (w + cycle) % 4});
          }
          at(t += 11);
          d.cue('levelclear', level: level, cycle: cycle);
          event(GameEventNames.fleetIntact);
          at(t += 2);
          d.cue('travel', level: level, cycle: cycle);
          t += 4;
        } else {
          d.cue('boss', level: 5, cycle: cycle);
          final tiers =
              scoreSongs[scoreSongFor(5, cycle)]!.hatchSections.length;
          at(t += 9);
          event(GameEventNames.bossApproach, {'step': 1});
          for (var k = 1; k <= tiers; k++) {
            at(t += 6.3);
            event(GameEventNames.bossHatchTier, {
              'tier': k,
              'tiers': tiers + 1,
            });
            at(t += 4.1);
            event(GameEventNames.musicIntensity, {'tier': (k + 1).clamp(1, 4)});
          }
          at(t += 3);
          event(GameEventNames.bossShieldFailing);
          at(t += 2.2);
          event(GameEventNames.bossTransform, {'stage': 'start'});
          at(t += 3.5);
          event(GameEventNames.bossTransform, {'stage': 'end'});
          event(GameEventNames.bossCoreExposed);
          at(t += 7);
          event(GameEventNames.bossModuleLost);
          at(t += 9);
          d.cue('victory', level: 5, cycle: cycle);
          event(GameEventNames.bossCollapseStart);
          if (cycle < 4) {
            at(t += 5.5);
            event(GameEventNames.bossCollapseEnd);
            d.cue('travel', level: 5, cycle: cycle);
            t += 4;
          } else {
            at(t += 4);
            d.cue('ending', level: 5, cycle: 4);
            at(t += 1.5);
            event(GameEventNames.bossCollapseEnd);
            d.cue('completed', level: 5, cycle: 4);
          }
        }
      }
    }
    at(t += 40);
    d.onGameEvent(const GameEvent(GameEventNames.musicIntensity, {'tier': 1}));

    // The songs in the order they played (the player's own timeline).
    final songs = <String>[];
    final sections = <String>[];
    for (var x = 1.0; x <= t; x += .05) {
      final p = player.playing(x);
      if (p == null) continue;
      final id = '${p.song}/${p.section}';
      if (sections.isEmpty || sections.last != id) sections.add(id);
      if (songs.isEmpty || songs.last != p.song) songs.add(p.song);
    }
    final want = ['menu', 'menu-k'];
    for (var cycle = 0; cycle <= 4; cycle++) {
      if (cycle > 0) want.add('c-k');
      want.addAll(['k', 'k-r', 'r', 'r-e', 'e', 'e-h', 'h', 'h-c']);
      want.add('c${cycle + 1}');
    }
    want.add('coda');
    expect(songs, want);
    expect(sections, contains('e/storm'));
    expect(sections.where((s) => s == 'e/storm'), hasLength(1));
    for (var cycle = 0; cycle < 5; cycle++) {
      final id = 'c${cycle + 1}';
      final tiers = scoreSongs[id]!.hatchSections.length;
      for (var k = 1; k <= tiers; k++) {
        expect(sections, contains('$id/H$k'));
      }
      for (final s in ['approach', 'transform', 'core', 'collapse']) {
        expect(sections, contains('$id/$s'));
      }
    }
    expect(
      sections.sublist(sections.indexOf('c5/collapse')),
      containsAllInOrder([
        'c5/collapse',
        'c5/worldized',
        'coda/ukulele',
        'coda/reprise',
      ]),
    );
    // Every section move lands on a bar line of the music playing just before
    // it (the collapse and the clear on a beat line); the first move starts
    // from silence.
    for (final (move, landed) in player.moves.skip(1)) {
      if (move.section == null) continue;
      final before = player.playing(landed - 1e-6)!;
      final song = scoreSongs[before.song]!;
      final unit = move.quantum == 'beat' ? song.beatSeconds : song.barSeconds;
      expect(
        onLine(landed, before.at, unit),
        isTrue,
        reason:
            '${move.song}/${move.section} (${move.reason}) at $landed '
            'after ${before.song}/${before.section}@${before.at}',
      );
    }
    // The director's picture of the grid is the player's.
    final p = player.playing(t)!;
    expect((d.song, d.section), (p.song, p.section));
    expect(d.start, closeTo(p.at, 1e-9));
  });

  test('a deferred start syncs to the player; a score that failed to load '
      'stops the director', () {
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
    expect(d.cue('level', level: 1), isTrue);
    expect(d.song, isNull);
    final before = player.moves.length;
    d.onGameEvent(const GameEvent(GameEventNames.musicIntensity, {'tier': 4}));
    expect(player.moves.length, before, reason: 'no song, no moves');
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
      song: 'h-c',
      section: 'pivot',
      at: 12.5,
      tier: 2,
      variant: 'v1',
      fleet: false,
      then: 'c3:arrival',
      reason: 'travel',
    );
    expect(move.toJson(), {
      'song': 'h-c',
      'section': 'pivot',
      'at': 12.5,
      'quantum': 'bar',
      'enter': 'start',
      'tier': 2,
      'variant': 'v1',
      'fleet': false,
      'then': 'c3:arrival',
      'reason': 'travel',
    });
  });
}
