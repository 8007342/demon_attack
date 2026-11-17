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

  test('the styleguide §6 order: cells, failing, down, armour, modules, '
      'core exposed, collapse, wrecks, collapse end', () {
    final m = ArcadeModel(seed: 4)..startAt(sector: 5, route: 2);
    m.mode = RunMode.playing;
    final b = m.boss!;
    expect(b.fightReady, isTrue);
    m.takeGameEvents();
    final all = <GameEvent>[];
    // carrier-hatches: the shield is the hatches' own fields and hulls;
    // the cell events are retired, each hatch reports its drop.
    for (var guard = 0; guard < 100000 && b.shield > 0; guard++) {
      m.hitBoss(b.x);
      all.addAll(m.takeGameEvents());
    }
    expect(all.where((e) => e.name == GameEventNames.bossShieldCellLost),
        isEmpty);
    expect(all.where((e) => e.name == GameEventNames.bossHatchDrop),
        hasLength(b.hatches.length));
    expect(all.where((e) => e.name == GameEventNames.bossCoreExposed),
        hasLength(1));
    expect(all.where((e) => e.name == GameEventNames.bossShieldFailing), hasLength(1));
    expect(all.where((e) => e.name == GameEventNames.bossShieldDown), hasLength(1));
    // Core: two armour steps per form; the odd ones shed plates, the even
    // ones tear the form's module away, the last is the collapse.
    for (var guard = 0; guard < 100000 && m.boss != null; guard++) {
      b.door = 1;
      m.hitBoss(b.x);
      all.addAll(m.takeGameEvents());
    }
    final plates = all.where((e) => e.name == GameEventNames.bossArmourShed);
    final modules = all.where((e) => e.name == GameEventNames.bossModuleLost);
    expect(plates, hasLength(b.formCount));
    expect(modules, hasLength(b.formCount - 1));
    expect(
      [for (final e in modules) e.data['form']],
      [for (var f = 1; f < b.formCount; f++) f],
    );
    // The slots tear away in the hull's detach order (tour 3: the lattice
    // Siege-Ark): spines, blisters, wings; the armour sheds from the module
    // that goes next.
    expect([for (final e in modules) e.data['slot']], ['spines', 'blister', 'wing']);
    expect([for (final e in modules) e.data['rank']], [1, 2, 3]);
    expect(plates.first.data['slot'], 'spines');
    expect(modules.first.data['set'], 'crown');
    expect(all.where((e) => e.name == GameEventNames.bossCollapseStart), hasLength(1));
    final wrecks = [
      for (final e in all)
        if (e.name == GameEventNames.bossWreckFalls) e.data['slot'],
    ];
    expect(wrecks.last, 'carapace', reason: 'the carapace sinks last');
    expect(wrecks, containsAllInOrder(['emitter', 'maw', 'barrier', 'tendril']));
    // The fixed order, step by step.
    final order = [
      for (final e in all)
        if (e.name != GameEventNames.bossShieldCellLost &&
            e.name != GameEventNames.bossWreckFalls &&
            e.name.startsWith('boss'))
          e.name,
    ];
    expect(order.indexOf(GameEventNames.bossShieldFailing),
        lessThan(order.indexOf(GameEventNames.bossShieldDown)));
    // carrier-hatches §A4: the transformation exposes the core before the
    // armour and forms.
    expect(order.indexOf(GameEventNames.bossShieldDown),
        lessThan(order.indexOf(GameEventNames.bossCoreExposed)));
    expect(order.indexOf(GameEventNames.bossCoreExposed),
        lessThan(order.indexOf(GameEventNames.bossArmourShed)));
    expect(order.last, GameEventNames.bossCollapseStart);
    // Every decay event names the run's module set (visual variety).
    for (final e in all.where((e) => e.name.startsWith('boss'))) {
      expect(e.data['variant'], b.variant, reason: e.name);
    }
    // The rout ends: the collapse is over.
    for (var i = 0; i < 60 * 30 && m.mode == RunMode.victory; i++) {
      m.update(1 / 60);
      all.addAll(m.takeGameEvents());
    }
    expect(all.where((e) => e.name == GameEventNames.bossCollapseEnd), hasLength(1));
  });

  test('the set pick follows the run seed; unseeded runs draw the first set', () {
    final a = ArcadeModel(seed: 4)..startAt(sector: 5, route: 0);
    expect(a.boss!.variant, 0);
    final sets = <int>{};
    for (var s = 1; s < 30; s++) {
      final m = ArcadeModel(seed: 4)..startAt(sector: 5, route: 0, runSeed: s);
      sets.add(m.bossVariant % 3);
      expect(m.boss!.variant, m.bossVariant);
      final again = ArcadeModel(seed: 4)..startAt(sector: 5, route: 0, runSeed: s);
      expect(again.bossVariant, m.bossVariant);
    }
    expect(sets, {0, 1, 2});
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
      GameEventNames.bossCollapseStart,
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
