import 'package:demon_attack/game/model.dart';
import 'package:demon_attack/game/music_director.dart';
import 'package:flutter_test/flutter_test.dart';

/// boss-grandeur (operator R8.5): every step of the carrier's decay goes
/// into the game event queue the music director and comms read, as named
/// events, for the future dynamic music engine.
void main() {
  List<GameEvent> named(ArcadeModel m, String name) =>
      [for (final e in m.takeGameEvents()) if (e.name == name) e];

  test('the rise is queued when the last loom wave is cleared', () {
    final m = ArcadeModel(seed: 2)..startAt(sector: 5, route: 0, wave: 1);
    m.takeGameEvents();
    while (m.boss == null) {
      m.invulnerable = 2;
      for (final d in List.of(m.demons)) {
        m.hitDemon(d, damage: 999);
      }
      m.update(1 / 60);
    }
    final rise = named(m, GameEventNames.bossRise);
    expect(rise, hasLength(1));
    expect(rise.single.data['route'], 0);
  });

  test('12 shield cells, the field, armour plates, modules, the collapse', () {
    final m = ArcadeModel(seed: 4)..startAt(sector: 5, route: 2);
    m.mode = RunMode.playing;
    final b = m.boss!;
    expect(b.fightReady, isTrue);
    m.takeGameEvents();
    final all = <GameEvent>[];
    while (b.shield > 0) {
      m.hitBoss(b.x);
      all.addAll(m.takeGameEvents());
    }
    final cells = [
      for (final e in all)
        if (e.name == GameEventNames.bossShieldCellLost) e.data['cellsLeft'],
    ];
    expect(cells, [for (var c = 11; c >= 0; c--) c]);
    expect(
      all.where((e) => e.name == GameEventNames.bossShieldDepleted),
      hasLength(1),
    );
    // Core: two armour steps per form; the odd ones are plates, the even
    // ones the form's module, the last the collapse.
    while (m.boss != null) {
      b.door = 1;
      m.hitBoss(b.x);
      all.addAll(m.takeGameEvents());
    }
    final plates = all.where((e) => e.name == GameEventNames.bossArmourLost);
    final modules = all.where((e) => e.name == GameEventNames.bossModuleLost);
    expect(plates, hasLength(b.formCount));
    expect(modules, hasLength(b.formCount - 1));
    expect(
      [for (final e in modules) e.data['form']],
      [for (var f = 1; f < b.formCount; f++) f],
    );
    expect(all.where((e) => e.name == GameEventNames.bossCollapse), hasLength(1));
    // Every decay event names the run's module set (visual variety).
    for (final e in all.where((e) => e.name.startsWith('boss'))) {
      expect(e.data['variant'], b.variant, reason: e.name);
    }
  });

  test('nothing is queued while the carrier rises (no hitbox)', () {
    final m = ArcadeModel(seed: 6)..startAt(sector: 5, route: 0);
    m.mode = RunMode.playing;
    final b = m.boss!..emerge = 0;
    m.takeGameEvents();
    expect(m.hitBoss(b.x), isFalse);
    expect(m.takeGameEvents().where((e) => e.name.startsWith('boss')), isEmpty);
  });

  test('music stingers: overflight, rise and collapse use existing accents', () {
    final accents = <String>[];
    final bridge = MusicBridge(
      onIntensity: (_) {},
      onAccent: accents.add,
      onFleetIntact: () {},
    );
    for (final name in [
      GameEventNames.bossOverflight,
      GameEventNames.bossRise,
      GameEventNames.bossCollapse,
    ]) {
      bridge(GameEvent(name));
    }
    expect(accents, ['gloat', 'laststand', 'respawn']);
    // The director publishes the overflight once, on the boss arrival.
    final events = <GameEvent>[];
    final director = MusicDirector(emit: events.add);
    final m = ArcadeModel(seed: 3)
      ..startAt(sector: 4, route: 0, wave: ArcadeModel.wavesFor(sector: 4, route: 0));
    for (var i = 0; i < 60 * 5; i++) {
      m.update(1 / 60);
    }
    m.endSector();
    for (var i = 0; i < 60 * 25 && !m.combat; i++) {
      m.update(1 / 60);
      director.observe(m, 1 / 60);
    }
    expect(
      events.where((e) => e.name == GameEventNames.bossOverflight),
      hasLength(1),
    );
  });
}
