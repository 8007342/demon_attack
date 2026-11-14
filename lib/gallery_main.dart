// Visual QA harness for the sprite overhaul; not part of the shipped app.
//
//   flutter build web -t lib/gallery_main.dart -o build/gallery
//
// Pages (?page=...): creatures, elites, actions, weapons, sentinels, carrier.
// Every tile is the real DemonScene renderer drawing a staged ArcadeModel,
// so screenshots show exactly what the game draws.
//
// ?page=studio opens the asset review studio (lib/review/): backgrounds,
// atlas animations, these staged scenes, radio clips and music cues, each
// with targeted review notes (&tab=radio&item=<clip id> deep-links one).
import 'dart:math' as math;

import 'package:flame/game.dart';
import 'package:flutter/material.dart';

import 'game/model.dart';
import 'game/scene.dart';
import 'review/page_notes.dart';
import 'review/review_catalog.dart';
import 'review/review_studio.dart';
import 'services/audio.dart';

void main() {
  // The gallery loads the game's audio script (web/index.html is shared);
  // its menu music must not start here. The studio plays its own audio.
  audioMute(true);
  runApp(const GalleryApp());
}

/// Whether [path] is the studio's own address, /studio (the Worker serves
/// this app there; /gallery/?page=studio still works).
bool isStudioPath(String path) {
  var p = path.toLowerCase();
  while (p.length > 1 && p.endsWith('/')) {
    p = p.substring(0, p.length - 1);
  }
  return p == '/studio';
}

typedef Stage = void Function(ArcadeModel model, double dt, double t);

class GalleryScene extends DemonScene {
  GalleryScene(ArcadeModel model, {this.live = false, this.stage})
    : super(model, () {});
  final bool live;
  final Stage? stage;
  double t = 0;

  @override
  void update(double dt) {
    t += dt;
    if (live) {
      stage?.call(model, dt, t);
      super.update(dt);
    } else {
      model.clock += dt;
      stage?.call(model, dt, t);
      creatures.update(model, dt);
    }
  }

  @override
  void render(Canvas canvas) {
    super.render(canvas);
    paintArena(canvas, size);
  }
}

class GalleryApp extends StatelessWidget {
  const GalleryApp({super.key});

  @override
  Widget build(BuildContext context) {
    final query = Uri.base.queryParameters;
    final page =
        query['page'] ?? (isStudioPath(Uri.base.path) ? 'studio' : 'creatures');
    if (page == 'studio' || page == 'review') {
      return MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'Demon Attack asset review',
        home: ReviewStudio(
          sceneBuilder: (page) => GalleryPage(page: page),
          initialTab: StudioTab.values
              .where((t) => t.name == query['tab'])
              .firstOrNull,
          initialItem: query['item'],
        ),
      );
    }
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        backgroundColor: const Color(0xFF0B0A1C),
        body: Stack(
          children: [
            Positioned.fill(
              child: GalleryPage(
                page: page,
                only: int.tryParse(query['tile'] ?? ''),
              ),
            ),
            Positioned(
              right: 12,
              bottom: 12,
              child: PageNotesButton(
                asset: sceneAsset(
                  page,
                  scenePages.where((p) => p.$1 == page).firstOrNull?.$2 ??
                      'Gallery page: $page',
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// One staged gallery page: a grid of live DemonScene tiles.
class GalleryPage extends StatelessWidget {
  const GalleryPage({super.key, required this.page, this.only});
  final String page;
  final int? only;

  @override
  Widget build(BuildContext context) {
    var tiles = switch (page) {
      'elites' => [_tile('ELITES', _elites())],
      'actions' => [_tile('FIRE / DEATH', _actions())],
      'weapons' => _weapons(),
      'sentinels' => [_tile('SENTINELS', _sentinels())],
      'carrier' => _carriers(),
      _ => [_tile('CREATURES', _creatures())],
    };
    final only = this.only;
    if (only != null && only < tiles.length) tiles = [tiles[only]];
    return LayoutBuilder(
      builder: (context, box) {
        final cols = tiles.length == 1
            ? 1
            : (box.maxWidth > 900 ? math.min(4, tiles.length) : 2);
        final rows = (tiles.length / cols).ceil();
        return Column(
          children: [
            for (var r = 0; r < rows; r++)
              Expanded(
                child: Row(
                  children: [
                    for (var c = 0; c < cols; c++)
                      Expanded(
                        child: r * cols + c < tiles.length
                            ? tiles[r * cols + c]
                            : const SizedBox(),
                      ),
                  ],
                ),
              ),
          ],
        );
      },
    );
  }
}

Widget _tile(String label, GalleryScene scene) => Stack(
  children: [
    Positioned.fill(child: GameWidget(game: scene)),
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

ArcadeModel _staged() {
  final m = ArcadeModel()
    ..mode = RunMode.playing
    ..shipX = 180;
  return m;
}

const _speciesY = [70.0, 170.0, 270.0, 370.0];

/// Rows: teal, violet, coral, gold. Columns: intact, molt 1-3, angry,
/// hit flash, dive warning (anticipation), dive.
GalleryScene _creatures() {
  final m = _staged();
  for (var k = 0; k < 4; k++) {
    for (var col = 0; col < 8; col++) {
      final d = Demon(24.0 + col * 44.6, _speciesY[k], k, 5, 0.0);
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
      m.shipX = -100;
    },
  );
}

/// Elite armour at each remaining health, plus an elite firing.
GalleryScene _elites() {
  final m = _staged();
  for (var k = 0; k < 4; k++) {
    for (var col = 0; col < 6; col++) {
      final d = Demon(
        30.0 + col * 60,
        _speciesY[k],
        k,
        5,
        0.3 * col,
        elite: true,
      );
      d.hp = col < 5 ? 5 - col : 2;
      m.demons.add(d);
    }
  }
  return GalleryScene(
    m,
    stage: (m, dt, t) {
      m.shipX = -100;
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
  final m = _staged();
  final shooters = <Demon>[];
  for (var k = 0; k < 4; k++) {
    final a = Demon(40, _speciesY[k], k, 1, 0);
    final b = Demon(110, _speciesY[k], k, 3, 0)..hp = 1;
    shooters.addAll([a, b]);
    m.demons.addAll([a, b]);
  }
  final dying = <int, Demon>{};
  var lastCycle = -1;
  return GalleryScene(
    m,
    stage: (m, dt, t) {
      m.shipX = -100;
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
          final fresh = Demon(250, _speciesY[k], k, 4, 0)..hp = 1;
          dying[k] = fresh;
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

GalleryScene _weaponScene(List<Power> powers, double sway) {
  final m = ArcadeModel()..start();
  m.mode = RunMode.playing;
  m.lives = 99;
  return GalleryScene(
    m,
    live: true,
    stage: (m, dt, t) {
      for (final p in powers) {
        // Hold just past the deploy transition; the last module of a combo
        // runs its full timer so wear/overheat states cycle.
        m.powerTimers[p] = p == powers.last && powers.length > 1
            ? 8.7 - (t % 8.5)
            : ArcadeModel.powerDuration - 1;
      }
      m.mode = RunMode.playing;
      m.lives = 99;
      m.invulnerable = 0;
      m.shots.removeWhere((s) => s.hostile);
      m.demons.removeWhere((d) => d.dive > 0);
      if (sway != 0) {
        m.targetX = 180 + math.sin(t * 1.3) * sway;
      }
    },
  );
}

List<Widget> _weapons() => [
  _tile('NOSE (NO MODULE)', _weaponScene(const [], 0)),
  _tile('RAPID WING CANNONS', _weaponScene(const [Power.rapid], 0)),
  _tile('POWERFUL WING CANNONS', _weaponScene(const [Power.powerful], 60)),
  _tile('SPREAD', _weaponScene(const [Power.spread], 0)),
  _tile('LARGE', _weaponScene(const [Power.large], 0)),
  _tile(
    'POWERFUL+LARGE+SHIELD',
    _weaponScene(const [Power.powerful, Power.large, Power.shield], 40),
  ),
  _tile('RAPID+SPREAD', _weaponScene(const [Power.rapid, Power.spread], 0)),
  _tile('SHIELD', _weaponScene(const [Power.shield], 70)),
];

/// Two sentinel archetypes through hover, warning, dive, last-stand tell and
/// rush, with shield/armour layers.
GalleryScene _sentinels() {
  final m = _staged();
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
      ),
    );
  }
  return GalleryScene(
    m,
    stage: (m, dt, t) {
      m.shipX = -100;
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

GalleryScene _carrierScene(int cycle, double damage, {double door = 0}) {
  final m = _staged()..cycle = cycle;
  final b = Carrier(cycle);
  b.core = (b.coreMax * (1 - damage)).round().clamp(1, b.coreMax);
  b.shield = damage > 0.3 ? 0 : b.shieldMax;
  m.boss = b;
  return GalleryScene(
    m,
    stage: (m, dt, t) {
      m.shipX = -100;
      b.x = 180;
      b.door = door < 0 ? (math.sin(t * 2) * .5 + .5) : door;
      b.sideDoorLeft = (math.sin(t * 1.6) * .5 + .5);
      b.sideDoorRight = (math.sin(t * 1.6 + 2) * .5 + .5);
    },
  );
}

/// The falling-wreck victory beat, looping its 4 s progress.
GalleryScene _wreckScene(int cycle) {
  final m = _staged()..cycle = cycle;
  m.wreckBoss = Carrier(cycle)..core = 1;
  m.mode = RunMode.victory;
  m.transitionDuration = 4;
  return GalleryScene(
    m,
    stage: (m, dt, t) {
      m.shipX = -100;
      m.transitionLeft = 4 - (t % 4);
    },
  );
}

List<Widget> _carriers() => [
  _tile('CARRIER FORM 1', _carrierScene(0, 0)),
  _tile('FORM 2 · HATCH CYCLE', _carrierScene(1, 0.3, door: -1)),
  _tile('FORM 3 · DAMAGED', _carrierScene(2, 0.6, door: -1)),
  _tile('FORM 4 · CRITICAL', _carrierScene(3, 0.85, door: -1)),
  _tile('WRECK · FORM 1', _wreckScene(0)),
  _tile('WRECK · FORM 4', _wreckScene(3)),
];
