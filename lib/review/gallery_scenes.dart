// --- dev-pages-overhaul: the gallery's scenes (openspec/changes/
// dev-pages-overhaul, design §3).
//
// Every tile is the game's own DemonScene drawing a model started the way
// the game starts one (ArcadeModel.startAt, or the console's ConsoleStart),
// and every frame runs the scene's presentation pipeline: the backdrop and
// fog, the carrier's director and hero hull (BossPainter.sync), the ground
// blocks, the weather and the perf tier. A staged tile only freezes the
// simulation step (its creatures are placed by hand); it never draws from
// a frozen copy or a fallback atlas. A live tile runs the simulation too,
// with the ship kept alive, and restarts its run when the run moves on.
import 'dart:math' as math;

import 'package:flame/game.dart';
import 'package:flutter/material.dart';

import '../game/ground_painter.dart';
import '../game/insignia_rank.dart';
import '../game/model.dart';
import '../game/perf/frame_budget.dart';
import '../game/scene.dart';
import '../game/weather/rain_plan.dart';
import '../widgets/dev_console.dart' show ConsoleCarrier, ConsoleStart;
import '../widgets/mission_medal.dart';
import '../widgets/mission_medal_atlas.dart';

typedef Stage = void Function(ArcadeModel model, double dt, double t);

/// One gallery tile: a DemonScene, or (medals) a plain widget.
class GalleryScene extends DemonScene {
  GalleryScene(
    ArcadeModel model, {
    this.live = false,
    this.stage,
    this.restart,
    this.setup,
  }) : super(model, () {}) {
    setup?.call(this);
  }

  /// Runs the simulation (DemonScene.update) instead of a staged model.
  final bool live;
  final Stage? stage;

  /// A live run's start: called when the run has moved past what the tile
  /// shows ([shouldRestart]), so the tile loops.
  final void Function(ArcadeModel model)? restart;

  /// Applied once to the scene (a forced perf tier, a weather override).
  final void Function(GalleryScene scene)? setup;
  double t = 0, _runTime = 0;

  /// How long a live run plays before it starts over.
  static const loopSeconds = 75.0;

  /// The ship is never lost in a gallery tile.
  static void keepAlive(ArcadeModel m) {
    m.lives = math.max(m.lives, 3);
    m.invulnerable = math.max(m.invulnerable, .5);
  }

  bool shouldRestart(ArcadeModel m) =>
      _runTime > loopSeconds ||
      m.mode == RunMode.gameOver ||
      m.mode == RunMode.completed;

  @override
  void update(double dt) {
    t += dt;
    if (live) {
      _runTime += dt;
      if (restart != null && shouldRestart(model)) {
        restart!(model);
        _runTime = 0;
      }
      keepAlive(model);
      stage?.call(model, dt, t);
      super.update(dt);
      return;
    }
    // Staged: DemonScene.update without the simulation step. The model's
    // clock advances (the creatures' idle life), the hand-placed state is
    // re-applied, and the presentation runs exactly as in the game.
    model.clock += dt;
    stage?.call(model, dt, t);
    perf.frame(dt, moving: false);
    applyBudget();
    advancePresentation(dt);
    armada.sync(model, images.load, images.clear);
    if (GroundPainter.useBlocks) {
      groundForces.blocks.sync(model, images.load, images.clear);
    }
    creatures.update(model, dt);
  }

  @override
  void render(Canvas canvas) {
    super.render(canvas);
    paintArena(canvas, size);
  }
}

/// One tile of a scene page: a label and either a scene or a widget.
class GalleryTile {
  GalleryTile.scene(this.label, GalleryScene this.scene) : widget = null;
  GalleryTile.widget(this.label, Widget this.widget) : scene = null;
  final String label;
  final GalleryScene? scene;
  final Widget? widget;

  Widget build() => Stack(
    children: [
      Positioned.fill(child: widget ?? GameWidget(game: scene!)),
      Positioned(
        left: 6,
        top: 4,
        child: Text(
          label,
          style: const TextStyle(
            color: Color(0xFF70F5D5),
            fontSize: 11,
            fontFamily: 'monospace',
          ),
        ),
      ),
    ],
  );
}

/// The tiles of scene page [id] (review_catalog.dart's [scenePages]);
/// an unknown id shows the creatures.
List<GalleryTile> galleryTiles(String id) => switch (id) {
  'elites' => [GalleryTile.scene('ELITES', _elites())],
  'actions' => [GalleryTile.scene('FIRE / DEATH', _actions())],
  // --- insignia-ranks: the rare-mark ladder and the dense swarm (most of
  // it now wears nothing); the live waves are their own (live) page.
  'insignia' => [
    GalleryTile.scene('RANK LADDER', _insigniaLadder()),
    GalleryTile.scene('DENSE SWARM', _insignia()),
  ],
  'insignia-waves' => [
    GalleryTile.scene('TOUR 1 SECTOR 4', sectorRun(4, wave: 2)),
    GalleryTile.scene('TOUR 3 SECTOR 3', sectorRun(3, route: 2, wave: 3)),
  ],
  'dive-shields' => _diveShields(),
  'spear-bearers' => _spearBearers(), // --- spear-bearers
  'weapons' => _weapons(),
  'sentinels' => [GalleryTile.scene('SENTINELS', _sentinels())],
  'carrier' => _carrier(),
  'carrier-tours' => _carrierTours(),
  'ground-war' => _groundWar(),
  'weather' => _weather(),
  'bonus' => _bonus(),
  'perf-tiers' => _perfTiers(),
  'medals' => [GalleryTile.widget('MISSION MEDALS', const MedalSheet())],
  _ => [GalleryTile.scene('CREATURES', _creatures())],
};

// ------------------------------------------------------------- staging

/// A playing model on sector 2, run 2 (the review sheets' base), its wave
/// cleared so a scene places its own creatures.
ArcadeModel stagedModel({int sector = 2, int route = 1}) {
  final m = ArcadeModel(seed: 11)..startAt(sector: sector, route: route);
  m
    ..mode = RunMode.playing
    ..invulnerable = 0
    ..clock = 3;
  m.demons.clear();
  m.incoming.clear();
  m.shots.clear();
  return m;
}

/// The ship parked off the arena, out of the staged scene.
void _noShip(ArcadeModel m) {
  m.shipX = -100;
  m.targetX = -100;
}

const _speciesY = [70.0, 170.0, 270.0, 370.0];

/// Rows: teal, violet, coral, gold. Columns: intact, molt 1-3, angry,
/// hit flash, dive warning (anticipation), dive.
GalleryScene _creatures() {
  final m = stagedModel();
  for (var k = 0; k < 4; k++) {
    for (var col = 0; col < 8; col++) {
      final d = Demon(24.0 + col * 44.6, _speciesY[k], k, 5, 0.0)..nearness = 1;
      switch (col) {
        case 1 || 2 || 3:
          d.hp = 5 - col;
        case 4:
          d.hp = 1;
        case 7:
          d.dive = 1;
      }
      m.demons.add(d);
    }
  }
  return GalleryScene(
    m,
    stage: (m, dt, t) {
      for (var k = 0; k < 4; k++) {
        m.demons[k * 8 + 5].flash = 0.1;
        m.demons[k * 8 + 6].telegraph = 0.5;
        m.demons[k * 8 + 7].dive = 1;
      }
      m.shots.clear();
      _noShip(m);
    },
  );
}

// --- spear-bearers (openspec/changes/spear-bearers design §7) -----------

/// The spear-bearer: every gear state on the four species (rows: idle,
/// tell, dive, wind-up with its glint, release, buckler hit, bare dive),
/// and one bearer's whole dive in a 4 s loop: the levelled spear, the
/// wind-up, the throw (a spear that drifts), a buckler hit and the knock-off.
List<GalleryTile> _spearBearers() {
  GalleryScene states() {
    final m = stagedModel(sector: 3, route: 2);
    for (var k = 0; k < 4; k++) {
      for (var col = 0; col < 7; col++) {
        m.demons.add(
          Demon(30.0 + col * 50, _speciesY[k], k, 3, 0.3 * col, elite: true)
            ..nearness = 1
            ..spear = SpearKit(),
        );
      }
    }
    return GalleryScene(
      m,
      stage: (m, dt, t) {
        _noShip(m);
        final now = m.clock;
        for (var k = 0; k < 4; k++) {
          for (var col = 0; col < 7; col++) {
            final d = m.demons[k * 7 + col];
            final kit = d.spear!;
            d
              ..dive = col >= 2 ? 1 : 0
              ..telegraph = col == 1 ? .4 : 0
              ..vy = 0
              ..y = _speciesY[k];
            kit
              ..armed = col != 4 && col != 6
              ..windup = col == 3 ? SpearTuning.windup * (1 - t % 1) : 0
              ..releasedAt = col == 4 ? now : -1e9
              ..hitAt = col == 5 && (t * 2).floor().isEven ? now : -1e9
              ..buckler = col == 6 ? 0 : SpearTuning.buckler;
            if (col == 5) kit.armed = false;
          }
        }
      },
    );
  }

  GalleryScene dive() {
    final m = stagedModel(sector: 3, route: 2);
    final d = Demon(140, 90, 1, 3, 1.1, elite: true)
      ..nearness = 1
      ..spear = SpearKit();
    m.demons.add(d);
    var loop = -1;
    Shot? spear;
    return GalleryScene(
      m,
      stage: (m, dt, t) {
        _noShip(m);
        const period = 4.0;
        final p = t % period;
        final kit = d.spear!;
        if ((t / period).floor() != loop) {
          loop = (t / period).floor();
          kit
            ..armed = true
            ..buckler = SpearTuning.buckler
            ..windup = 0;
          m.shots.clear();
          m.spearRun.fallen.clear();
          spear = null;
        }
        // Dive from y 90 at 130 u/s; the wind-up at 0.9-1.45 s, the throw.
        d
          ..dive = p < 3.2 ? 1 : 0
          ..y = p < 3.2 ? 90 + 130 * p : 90
          ..vy = 0;
        kit.windup = p >= .9 && p < 1.45 ? 1.45 - p : 0;
        if (p >= 1.45 && kit.armed) {
          kit
            ..armed = false
            ..releasedAt = m.clock;
          spear = Shot(
            d.x + SpearTuning.releaseDx,
            d.y + SpearTuning.releaseDy,
            20,
            255,
            hostile: true,
            kind: ShotKind.spear,
          );
          m.shots.add(spear!);
        }
        final s = spear;
        if (s != null) {
          // A crosswind from the left bends it as it falls.
          s
            ..windVx = math.min(30, s.windVx + 40 * dt)
            ..x += (s.vx + s.windVx) * dt
            ..y += s.vy * dt;
        }
        if (p >= 1.9 && kit.buckler == SpearTuning.buckler) {
          kit
            ..buckler = 1
            ..hitAt = m.clock;
        }
        if (p >= 2.5 && kit.buckler == 1) {
          kit
            ..buckler = 0
            ..hitAt = m.clock;
          m.spearRun.fallen.add(
            FallenBuckler(d.x - 6, d.y + 8, -50, -70, 9, 1),
          );
        }
        for (final b in m.spearRun.fallen) {
          b
            ..vy += SpearTuning.fallGravity * dt
            ..x += b.vx * dt
            ..y += b.vy * dt
            ..rotation += b.spin * dt
            ..age += dt;
        }
      },
    );
  }

  return [
    GalleryTile.scene('SPEAR-BEARER STATES', states()),
    GalleryTile.scene('SPEAR-BEARER DIVE', dive()),
  ];
}

/// Elite armour at each remaining health, plus an elite firing.
GalleryScene _elites() {
  final m = stagedModel();
  for (var k = 0; k < 4; k++) {
    for (var col = 0; col < 6; col++) {
      final d = Demon(
        30.0 + col * 60,
        _speciesY[k],
        k,
        5,
        0.3 * col,
        elite: true,
      )..nearness = 1;
      d.hp = col < 5 ? 5 - col : 2;
      m.demons.add(d);
    }
  }
  return GalleryScene(
    m,
    stage: (m, dt, t) {
      _noShip(m);
      // Column 5 fires every 0.9 s so its mounts and muzzle animate.
      if ((t * 10).floor() % 9 == 0 && m.shots.isEmpty) {
        for (var k = 0; k < 4; k++) {
          final d = m.demons[k * 6 + 5];
          m.shots.add(Shot(d.x, d.y + 12, 0, 120, hostile: true));
        }
      }
      for (final s in m.shots) {
        s.y += 120 * dt;
      }
      m.shots.removeWhere((s) => s.y > m.demons[0].y + 300);
    },
  );
}

/// Each species firing (left two columns, normal and angry) and dying in a
/// loop (right).
GalleryScene _actions() {
  final m = stagedModel();
  final shooters = <Demon>[];
  for (var k = 0; k < 4; k++) {
    final a = Demon(40, _speciesY[k], k, 1, 0)..nearness = 1;
    final b = Demon(110, _speciesY[k], k, 3, 0)
      ..hp = 1
      ..nearness = 1;
    shooters.addAll([a, b]);
    m.demons.addAll([a, b]);
  }
  final dying = <int, Demon>{};
  var lastCycle = -1;
  return GalleryScene(
    m,
    stage: (m, dt, t) {
      _noShip(m);
      final cycle = (t / 1.1).floor();
      if (cycle != lastCycle) {
        lastCycle = cycle;
        m.shots.removeWhere((s) => s.y > 470);
        for (final d in shooters) {
          m.shots.add(Shot(d.x, d.y + 12, 0, 110, hostile: true));
        }
        for (var k = 0; k < 4; k++) {
          final old = dying[k];
          if (old != null) {
            old.hp = 0;
            m.demons.remove(old);
            m.blasts.add(Blast(old.x, old.y));
          }
          dying[k] = Demon(250, _speciesY[k], k, 4, 0)
            ..hp = 1
            ..nearness = 1;
        }
      } else if ((t / 1.1) - cycle > 0.65) {
        // Re-show the creature shortly before it dies again.
        for (final d in dying.values) {
          if (!m.demons.contains(d)) m.demons.add(d);
        }
      }
      for (final s in m.shots) {
        s.y += s.vy * dt;
      }
      for (final b in m.blasts) {
        b.age += dt;
      }
      m.blasts.removeWhere((b) => b.age > .6);
    },
  );
}

/// insignia-ranks: the mark ladder, one row per mark, one column per
/// species (the elite-grunt rows use the tough species 2-3, the only ones
/// that can be picked): grunts (none), the elite grunt's winglet, the
/// escort's crownlet, the hunter's Fang and Wings, and a sentinel's winged
/// crown on top.
GalleryScene _insigniaLadder() {
  final m = stagedModel();
  // Seeds whose elite-grunt roll is under (pick) or over (skip) the pick,
  // from a bounded search.
  double seed(bool picked) {
    for (var i = 0; i < 200; i++) {
      final d = Demon(0, 0, 2, 2, i * .25);
      if (InsigniaRanks.eliteGrunt(d) == picked) return i * .25;
    }
    return 0;
  }

  final pick = seed(true), skip = seed(false);
  const rows = [150.0, 210.0, 270.0, 330.0];
  for (var col = 0; col < 4; col++) {
    final x = 60.0 + col * 80;
    final tough = 2 + col % 2;
    m.demons.addAll([
      Demon(x, rows[0], col, 2, skip)..nearness = 1,
      Demon(x, rows[1], tough, 2, pick)..nearness = 1,
      Demon(x, rows[2], tough, 2, pick, isEscort: true)..nearness = 1,
      Demon(x, rows[3], col, 3, skip, elite: true)..nearness = 1,
    ]);
  }
  m.demons.add(
    Demon(
      180,
      70,
      0,
      9,
      0,
      archetype: EnemyArchetype.shieldSentinel,
      shieldMax: 3,
    )..nearness = 1,
  );
  return GalleryScene(
    m,
    stage: (m, dt, t) {
      _noShip(m);
      for (final d in m.demons) {
        d.nearness = 1;
      }
    },
  );
}

/// gargoyle-insignia: a mid-wave swarm about 40 units apart (every rank,
/// two angry, a dive tell, elites, an armoured sentinel and two packed
/// pairs where the lower rank's glyph yields), as the review sheet stages
/// it (test/gargoyle_insignia_review_test.dart).
GalleryScene _insignia() {
  final m = stagedModel();
  Demon f(
    double x,
    double y,
    int kind,
    int maxHp, {
    int? hp,
    bool elite = false,
    double seed = 0,
  }) {
    final d = Demon(x, y, kind, maxHp, seed, elite: elite)..nearness = 1;
    if (hp != null) d.hp = hp;
    return d;
  }

  m.demons.addAll([
    f(40, 120, 0, 1, seed: 1),
    f(85, 112, 2, 2, seed: 2),
    f(130, 124, 1, 4, seed: 3),
    f(230, 124, 3, 3, seed: 4),
    f(275, 112, 0, 3, elite: true, seed: 5),
    f(320, 120, 1, 2, seed: 6),
    f(50, 170, 3, 5, seed: 7),
    f(95, 178, 0, 2, seed: 8),
    f(140, 168, 2, 3, hp: 1, seed: 9),
    f(185, 176, 3, 4, elite: true, seed: 10),
    f(230, 168, 1, 3, seed: 11),
    f(275, 176, 2, 5, hp: 1, seed: 12),
    f(320, 168, 0, 3, seed: 13),
    f(70, 222, 1, 4, elite: true, seed: 14),
    f(118, 226, 0, 1, seed: 15),
    f(162, 220, 2, 4, seed: 16),
    f(250, 224, 3, 5, seed: 17),
    f(258, 214, 2, 2, seed: 18),
    f(310, 226, 1, 3, elite: true, seed: 19),
    f(316, 216, 0, 4, seed: 20),
    Demon(
      185,
      70,
      1,
      12,
      0,
      archetype: EnemyArchetype.armoredSentinel,
      shieldMax: 4,
      armorMax: 4,
    )..nearness = 1,
  ]);
  final tell = m.demons[12];
  return GalleryScene(
    m,
    stage: (m, dt, t) {
      _noShip(m);
      tell.telegraph = .5;
      for (final d in m.demons) {
        d.nearness = 1;
      }
    },
  );
}

/// dive-shield-thinning: one diving creature per row at full, middle and
/// last shield point; the arc keeps its span and thins to its floor.
List<GalleryTile> _diveShields() {
  GalleryScene row(List<Demon> Function() make) {
    final m = stagedModel();
    final ds = make();
    for (final (i, d) in ds.indexed) {
      d
        ..x = 60.0 + i * 120
        ..y = 230
        ..nearness = 1;
    }
    m.demons.addAll(ds);
    return GalleryScene(
      m,
      stage: (m, dt, t) {
        _noShip(m);
        for (final d in m.demons) {
          d
            ..vy = 0
            ..y = 230;
          if (d.rushing) {
            d.rushPhase = RushPhase.rush;
          } else {
            d.dive = 1;
          }
        }
      },
    );
  }

  Demon diver(int kind, int hp, int pts, int max, {bool elite = false}) =>
      Demon(180, 230, kind, hp, 1.3, elite: elite)
        ..dive = 1
        ..vy = 0
        ..diveShieldMax = max
        ..diveShield = pts;
  Demon sentinel(int pts, int max) =>
      Demon(
          180,
          230,
          0,
          9,
          .7,
          archetype: EnemyArchetype.shieldSentinel,
          shieldMax: 4,
        )
        ..dive = 1
        ..diveShieldMax = max
        ..diveShield = pts;
  Demon rush(int pts, int max) =>
      Demon(
          180,
          230,
          0,
          9,
          .7,
          archetype: EnemyArchetype.shieldSentinel,
          shieldMax: 4,
        )
        ..lastStand = true
        ..rushing = true
        ..rushPhase = RushPhase.rush
        ..rushShieldMax = max
        ..rushShield = pts;
  return [
    GalleryTile.scene(
      'MEDIUM 2/2 · 1/2 · SMALL 1/1',
      row(() => [diver(2, 3, 2, 2), diver(2, 3, 1, 2), diver(0, 1, 1, 1)]),
    ),
    GalleryTile.scene(
      'ELITE 3/3 · 2/3 · 1/3',
      row(
        () => [
          diver(3, 4, 3, 3, elite: true),
          diver(3, 4, 2, 3, elite: true),
          diver(3, 4, 1, 3, elite: true),
        ],
      ),
    ),
    GalleryTile.scene(
      'SENTINEL DIVE 5/5 · 3/5 · 1/5',
      row(() => [sentinel(5, 5), sentinel(3, 5), sentinel(1, 5)]),
    ),
    GalleryTile.scene(
      'SENTINEL RUSH 8/8 · 4/8 · 1/8',
      row(() => [rush(8, 8), rush(4, 8), rush(1, 8)]),
    ),
  ];
}

GalleryScene _weaponScene(List<Power> powers, double sway) {
  void begin(ArcadeModel m) {
    m.startAt(sector: 1, console: true);
  }

  final m = ArcadeModel(seed: 11);
  begin(m);
  return GalleryScene(
    m,
    live: true,
    restart: begin,
    stage: (m, dt, t) {
      for (final p in powers) {
        // Hold just past the deploy transition; the last module of a combo
        // runs its full timer so wear/overheat states cycle.
        m.powerTimers[p] = p == powers.last && powers.length > 1
            ? 8.7 - (t % 8.5)
            : ArcadeModel.powerDuration - 1;
      }
      m.shots.removeWhere((s) => s.hostile);
      m.demons.removeWhere((d) => d.dive > 0);
      if (sway != 0) {
        m.targetX = 180 + math.sin(t * 1.3) * sway;
      }
    },
  );
}

List<GalleryTile> _weapons() => [
  GalleryTile.scene('NOSE (NO MODULE)', _weaponScene(const [], 0)),
  GalleryTile.scene('RAPID WING CANNONS', _weaponScene(const [Power.rapid], 0)),
  GalleryTile.scene(
    'POWERFUL WING CANNONS',
    _weaponScene(const [Power.powerful], 60),
  ),
  GalleryTile.scene('SPREAD', _weaponScene(const [Power.spread], 0)),
  GalleryTile.scene('LARGE', _weaponScene(const [Power.large], 0)),
  GalleryTile.scene(
    'POWERFUL+LARGE+SHIELD',
    _weaponScene(const [Power.powerful, Power.large, Power.shield], 40),
  ),
  GalleryTile.scene(
    'RAPID+SPREAD',
    _weaponScene(const [Power.rapid, Power.spread], 0),
  ),
  GalleryTile.scene('SHIELD', _weaponScene(const [Power.shield], 70)),
];

/// Two sentinel archetypes through hover, damage, dive warning and the
/// last-stand tell and rush, with shield and armour layers.
GalleryScene _sentinels() {
  final m = stagedModel();
  final specs = <(EnemyArchetype, double, double)>[
    (EnemyArchetype.shieldSentinel, 90, 80),
    (EnemyArchetype.armoredSentinel, 270, 80),
    (EnemyArchetype.shieldSentinel, 90, 200),
    (EnemyArchetype.armoredSentinel, 270, 200),
    (EnemyArchetype.shieldSentinel, 90, 320),
    (EnemyArchetype.armoredSentinel, 270, 320),
    (EnemyArchetype.shieldSentinel, 90, 430),
    (EnemyArchetype.armoredSentinel, 270, 430),
  ];
  for (final (arch, x, y) in specs) {
    m.demons.add(
      Demon(
        x,
        y,
        0,
        8,
        0,
        archetype: arch,
        shieldMax: 3,
        armorMax: 3,
        lastStandEligible: true,
      )..nearness = 1,
    );
  }
  return GalleryScene(
    m,
    stage: (m, dt, t) {
      _noShip(m);
      final ds = m.demons;
      // Row 2: damaged (shield gone, armour cracked), Row 3: dive warning,
      // Row 4: last-stand tell / rush alternating.
      for (final d in ds.sublist(2, 4)) {
        d.shield = 0;
        d.armor = 1;
        d.hp = 3;
      }
      for (final d in ds.sublist(4, 6)) {
        d.telegraph = 0.5;
      }
      final rush = (t % 2) > 1;
      for (final d in ds.sublist(6, 8)) {
        d.hp = 2;
        d.shield = 0;
        d.armor = 0;
        d.lastStand = true;
        d.rushing = rush;
        d.telegraph = rush ? 0 : 0.9 - (t % 1) * 0.9;
      }
    },
  );
}

/// A live carrier run from the console's launcher: the fight (its hatches
/// and the emergence), the approach (the loom), or the fast decay (shield,
/// armour, modules, the collapse and the wreck).
GalleryScene carrierRun(int route, ConsoleCarrier carrier) {
  final start = ConsoleStart.boss(route: route, carrier: carrier);
  void begin(ArcadeModel m) => start.applyTo(m);
  final m = ArcadeModel(seed: 11);
  begin(m);
  return GalleryScene(m, live: true, restart: begin);
}

List<GalleryTile> _carrier() => [
  GalleryTile.scene('RUN 1 · FIGHT', carrierRun(0, ConsoleCarrier.fight)),
  GalleryTile.scene('RUN 1 · FAST DECAY', carrierRun(0, ConsoleCarrier.decay)),
  GalleryTile.scene('RUN 1 · APPROACH', carrierRun(0, ConsoleCarrier.approach)),
];

List<GalleryTile> _carrierTours() => [
  for (var route = 1; route < 5; route++)
    GalleryTile.scene(
      'RUN ${route + 1} · FIGHT',
      carrierRun(route, ConsoleCarrier.fight),
    ),
];

/// A live regular sector (the ground war plays under it).
GalleryScene sectorRun(
  int sector, {
  int route = 0,
  int wave = 2,
  int? runSeed,
  String? bonus,
  WindTier? wind,
  void Function(GalleryScene scene)? setup,
}) {
  void begin(ArcadeModel m) {
    // --- crosswind: a forced wind on the tile's sector.
    m.windRun.force = wind == null
        ? null
        : (r, s) => WindPlan.draw(77 + s, tier: wind);
    m.startAt(
      sector: sector,
      route: route,
      wave: wave,
      runSeed: runSeed,
      bonus: bonus,
      console: true,
    );
  }

  final m = ArcadeModel(seed: 11);
  begin(m);
  return GalleryScene(
    m,
    live: true,
    restart: begin,
    setup: setup,
    stage: (m, dt, t) {
      // The ship sweeps the arena so the swarm and the ground answer it.
      m.targetX = 180 + math.sin(t * .7) * 110;
    },
  );
}

const _sectorTitles = ['KRYBOR', 'RINGFALL', 'EMBER MOON', 'THE HOLLOW'];

List<GalleryTile> _groundWar() => [
  for (var s = 1; s <= 4; s++)
    GalleryTile.scene('SECTOR $s · ${_sectorTitles[s - 1]}', sectorRun(s)),
];

/// The review sheet's three rain strengths (test/dynamic_weather_review).
const weatherSpecs = <(String, int, RainSpec)>[
  ('DRIZZLE', 1, RainSpec(tier: RainTier.drizzle, peak: .26, wind: -.08)),
  ('RAIN', 2, RainSpec(tier: RainTier.rain, peak: .56, wind: .16)),
  ('DOWNPOUR', 4, RainSpec(tier: RainTier.downpour, peak: .95, wind: .3)),
];

List<GalleryTile> _weather() => [
  for (final (label, sector, spec) in weatherSpecs)
    GalleryTile.scene(
      '$label · SECTOR $sector',
      sectorRun(sector, setup: (s) => s.rain.override = spec),
    ),
  // --- crosswind: the wind, alone and with a shower.
  GalleryTile.scene('BREEZE · SECTOR 3', sectorRun(3, wind: WindTier.breeze)),
  GalleryTile.scene('GALE · SECTOR 2', sectorRun(2, wind: WindTier.gale)),
  GalleryTile.scene(
    'GALE + RAIN · SECTOR 4',
    sectorRun(
      4,
      wind: WindTier.gale,
      setup: (s) => s.rain.override = weatherSpecs[1].$3,
    ),
  ),
];

List<GalleryTile> _bonus() => [
  for (final level in bonusLevels)
    GalleryTile.scene(
      level.label.toUpperCase(),
      sectorRun(2, wave: 1, bonus: level.id),
    ),
];

/// One heavy scene (sector 4 in a downpour) at each forced tier.
List<GalleryTile> _perfTiers() => [
  for (final tier in PerfTier.values)
    GalleryTile.scene(
      tier.name.toUpperCase(),
      sectorRun(
        4,
        route: 4,
        setup: (s) => s
          ..perf.forced = tier
          ..rain.override = weatherSpecs.last.$3,
      ),
    ),
];

/// Every mission medal the atlas composes, from the game's MissionMedal.
class MedalSheet extends StatelessWidget {
  const MedalSheet({super.key});

  /// The mission ids the medal atlas has a ribbon for.
  static List<String> get ids => [
    for (final k in MissionMedalAtlas.cells.keys)
      if (k.startsWith('ribbon.') && k != 'ribbon.generic')
        k.substring('ribbon.'.length),
  ];

  @override
  Widget build(BuildContext context) => FutureBuilder<void>(
    future: MissionMedalSheet.load(),
    builder: (context, _) => Padding(
      padding: const EdgeInsets.fromLTRB(16, 32, 16, 16),
      child: Wrap(
        spacing: 24,
        runSpacing: 24,
        children: [
          for (final id in [...ids, 'unknown-mission'])
            SizedBox(
              width: 96,
              child: Column(
                children: [
                  MissionMedal(id: id, size: 64),
                  const SizedBox(height: 6),
                  Text(
                    id,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Color(0xFF8D9EB3),
                      fontSize: 10,
                      fontFamily: 'monospace',
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    ),
  );
}
