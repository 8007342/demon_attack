/// What the review studio can show: every animation in the game's sprite
/// atlases, the sector backgrounds, the gallery's staged scenes, the radio
/// bank and the music cues. Built from the generated atlas contracts and the
/// comms bank the game itself reads, so the studio never re-describes a
/// sheet by hand: if an atlas moves, the studio moves with it.
library;

import 'dart:ui';

import '../comms/comms_bank.dart';
import '../comms/comms_portraits.dart';
import '../comms/comms_types.dart';
import '../game/flyover_atlas.dart';
import '../game/ground_atlas.dart';
import '../game/ground_wildlife_atlas.dart';
import '../game/hatch_emergence_atlas.dart';
import '../game/insignia_atlas.dart';
import '../game/sentinel_silhouette_atlas.dart';
import '../game/sprite_atlas.dart';
import '../game/vegetation_atlas.dart';
import 'review_notes.dart';

/// One drawn piece of a frame: a source rect, placed at [at] (source px)
/// from the animation's shared anchor.
class AtlasLayer {
  const AtlasLayer(this.src, [this.at = Offset.zero]);
  final Rect src;
  final Offset at;
}

/// A frame-by-frame animation inside one atlas image.
class AtlasAnim {
  AtlasAnim({
    required this.group,
    required this.id,
    required this.title,
    required this.image,
    required this.frames,
    required this.fps,
    this.where = '',
  });
  final String group, id, title, image, where;
  final List<List<AtlasLayer>> frames;
  final double fps;

  String get path => 'assets/images/$image';

  /// Bounds of every layer of every frame, in source px from the anchor.
  Rect get bounds {
    Rect? box;
    for (final f in frames) {
      for (final l in f) {
        final r = l.at & l.src.size;
        box = box == null ? r : box.expandToInclude(r);
      }
    }
    return box ?? Rect.zero;
  }

  ReviewAsset asset() => ReviewAsset(
    kind: ReviewKind.atlas,
    id: '$group/$id',
    title: '$group · $title',
    source: where.isEmpty ? path : '$path › $where',
    detail:
        '${frames.length} frames · ${fps.toStringAsFixed(fps % 1 == 0 ? 0 : 1)} fps',
  );
}

List<AtlasLayer> _cell(double w, double h, int row, int col) => [
  AtlasLayer(Rect.fromLTWH(col * w, row * h, w, h)),
];

/// [count] cells of one row from [col].
List<List<AtlasLayer>> _run(double w, double h, int row, int col, int count) =>
    [for (var i = 0; i < count; i++) _cell(w, h, row, col + i)];

const _species = ['teal', 'violet', 'coral', 'gold'];
const _sectorNames = ['krybor', 'ringfall', 'ember', 'hollow', 'carrier'];

/// Every atlas animation. [shipWeapons] is `assets/images/ship-weapons.json`
/// (its rows and column ranges), when loaded.
List<AtlasAnim> atlasAnimations({Map<String, Object?>? shipWeapons}) {
  final out = <AtlasAnim>[];
  void add(
    String group,
    String id,
    String title,
    String image,
    List<List<AtlasLayer>> frames,
    double fps,
    String where,
  ) {
    out.add(
      AtlasAnim(
        group: group,
        id: id,
        title: title,
        image: image,
        frames: frames,
        fps: fps,
        where: where,
      ),
    );
  }

  // --- combat.png: creatures (plan/sprite-atlas.md, CombatAtlas).
  const c = CombatAtlas.cell;
  for (var k = 0; k < 4; k++) {
    final base = CombatAtlas.base(k), name = _species[k];
    final g = 'creature-$name';
    const dirs = ['left', 'neutral', 'right'];
    for (var d = 0; d < 3; d++) {
      add(
        g,
        'flight-${dirs[d]}',
        'flight ${dirs[d]}',
        'combat.png',
        _run(c, c, base, d * 10, CombatAtlas.flightFrames),
        16,
        'row $base cols ${d * 10}-${d * 10 + 9}',
      );
    }
    for (var m = 1; m <= 4; m++) {
      final label = m == 4 ? 'angry' : 'molt-$m';
      add(
        g,
        label,
        '$label flight',
        'combat.png',
        _run(c, c, base + m, 10, CombatAtlas.flightFrames),
        16,
        'row ${base + m} cols 10-19',
      );
    }
    final action = CombatAtlas.actionRow(k);
    for (final (id, col, n, fps) in [
      ('anticipation', CombatAtlas.anticipationCol, 4, 8.0),
      ('fire', CombatAtlas.fireCol, 4, 14.0),
      ('angry-fire', CombatAtlas.angryFireCol, 4, 14.0),
      ('death', CombatAtlas.deathCol, 8, 12.0),
      ('dive', CombatAtlas.diveCol, 10, 8.0),
      ('dive-flash', CombatAtlas.diveFlashCol, 2, 8.0),
    ]) {
      add(
        g,
        id,
        id,
        'combat.png',
        _run(c, c, action, col, n),
        fps,
        'row $action cols $col-${col + n - 1}',
      );
    }
    final elite = CombatAtlas.eliteRow(k);
    add(
      g,
      'elite-armour',
      'elite armour levels',
      'combat.png',
      _run(c, c, elite, 4, 4),
      2,
      'row $elite cols 4-7',
    );
  }
  add(
    'combat-effects',
    'explosion',
    'explosion',
    'combat.png',
    _run(c, c, CombatAtlas.explosionRow, 0, 8),
    12,
    'row 36 cols 0-7',
  );
  add(
    'combat-effects',
    'splash',
    'powered splash',
    'combat.png',
    _run(c, c, CombatAtlas.explosionRow, 8, 8),
    12,
    'row 36 cols 8-15',
  );
  for (final (id, col) in [
    ('sparks', 0),
    ('impact', 4),
    ('muzzle', 8),
    ('mint-sparks', 12),
  ]) {
    add(
      'combat-effects',
      id,
      id,
      'combat.png',
      _run(c, c, CombatAtlas.effectRow, col, 4),
      12,
      'row 37 cols $col-${col + 3}',
    );
  }
  add(
    'combat-effects',
    'pickups',
    'pickup badges',
    'combat.png',
    _run(c, c, CombatAtlas.pickupRow, 0, 6),
    2,
    'row 38 cols 0-5',
  );

  // --- sentinel-effects.png (128 x 64 cells, 8 columns).
  const sw = 128.0, sh = 64.0;
  for (final (row, col, n, id, fps) in [
    (0, 0, 8, 'warden-stroke', 2.5),
    (1, 0, 8, 'colossus-stroke', 2.5),
    (2, 0, 4, 'shield-envelope', 2.0),
    (2, 4, 4, 'armour-layers', 2.0),
    (3, 0, 4, 'smoke', 8.0),
    (3, 4, 4, 'flames', 8.0),
    (4, 0, 8, 'breakup', 8 / 1.4),
    (5, 0, 4, 'sparks', 8.0),
    (5, 4, 4, 'plate-debris', 8.0),
    (6, 0, 4, 'warden-last-stand', 8.0),
    (6, 4, 4, 'warden-rush', 8.0),
    (7, 0, 4, 'colossus-last-stand', 8.0),
    (7, 4, 4, 'colossus-rush', 8.0),
    (8, 0, 4, 'warden-dive-warning', 8.0),
    (8, 4, 4, 'warden-stoop', 8.0),
    (9, 0, 4, 'colossus-dive-warning', 8.0),
    (9, 4, 4, 'colossus-stoop', 8.0),
    (10, 0, 8, 'warden-hit-flash', 8.0),
    (11, 0, 8, 'colossus-hit-flash', 8.0),
    (12, 0, 4, 'black-smoke', 8.0),
    (12, 4, 4, 'big-flames', 8.0),
    (13, 0, 4, 'warden-maw', 4 / .28),
    (13, 4, 4, 'colossus-maw', 4 / .28),
  ]) {
    add(
      'sentinel',
      id,
      id,
      'sentinel-effects.png',
      _run(sw, sh, row, col, n),
      fps,
      'row $row cols $col-${col + n - 1}',
    );
  }

  // --- ship-weapons.png: rows and column ranges from its JSON.
  final rows = shipWeapons?['rows'], columns = shipWeapons?['columns'];
  if (rows is Map && columns is Map) {
    for (final MapEntry(key: rowName, value: row) in rows.entries) {
      if (row is! int) continue;
      final group = switch (rowName) {
        'spread' || 'rapid' || 'powerful' || 'large' => 'module',
        _ => rowName,
      };
      final cols = columns[group];
      if (cols is! Map) continue;
      for (final MapEntry(key: id, value: range) in cols.entries) {
        if (range is! List || range.length != 2) continue;
        final (a, b) = (range[0] as int, range[1] as int);
        add(
          'ship',
          '$rowName-$id',
          '$rowName $id',
          'ship-weapons.png',
          _run(64, 64, row, a, b - a + 1),
          8,
          'row $row cols $a-$b',
        );
      }
    }
  }

  // --- dev-pages-overhaul: no frontal boss hulls (BossAtlas.classes). Every
  // tour draws a packed hero hull (BossPainter.heroForRun), so the frontal
  // sheets are never on screen; the carrier is reviewed live in the
  // gallery's carrier scenes instead.

  // --- ground-forces.png (GroundAtlas): its effects only. Vehicles and
  // allies are drawn from the per-sector ground blocks (ground-blocks-
  // runtime; the old unit rows are only a loading fallback), reviewed live
  // in the gallery's ground-war scenes.
  const gw = GroundAtlas.cellW * 1.0, gh = GroundAtlas.cellH * 1.0;
  for (final (row, col, n, id) in [
    (
      GroundAtlas.effectRow,
      GroundAtlas.explosionCol,
      GroundAtlas.explosionFrames,
      'explosion',
    ),
    (
      GroundAtlas.fxRow,
      GroundAtlas.shockCol,
      GroundAtlas.shockFrames,
      'shock-ring',
    ),
    (GroundAtlas.fxRow, GroundAtlas.dustCol, GroundAtlas.dustFrames, 'dust'),
    (
      GroundAtlas.fxRow,
      GroundAtlas.puffCol,
      GroundAtlas.puffFrames,
      'smoke-puff',
    ),
    (
      GroundAtlas.fxRow,
      GroundAtlas.sparkCol,
      GroundAtlas.sparkFrames,
      'sparks',
    ),
    (
      GroundAtlas.flameRow,
      GroundAtlas.flameCol,
      GroundAtlas.flameFrames,
      'flame',
    ),
    (
      GroundAtlas.flameRow,
      GroundAtlas.debrisCol,
      GroundAtlas.debrisFrames,
      'debris',
    ),
    (GroundAtlas.missileRow, GroundAtlas.missileCol, 2, 'missile'),
    (GroundAtlas.missileRow, GroundAtlas.smokeCol, 3, 'missile-smoke'),
  ]) {
    add(
      'ground-effects',
      id,
      id,
      'ground-forces.png',
      _run(gw, gh, row, col, n),
      10,
      'row $row cols $col-${col + n - 1}',
    );
  }

  // --- dev-pages-overhaul: ground-troops.png is no longer listed: troops
  // are drawn from the ground blocks (ground-blocks-runtime) and the sheet
  // is only their loading fallback.

  // --- insignia.png (gargoyle-insignia): each glyph's bone, angry and tell
  // states, and the rank cells.
  final glyphs = <String, List<Rect>>{};
  for (final MapEntry(key: id, value: r) in InsigniaAtlas.rects.entries) {
    glyphs.putIfAbsent(id.split('/').first, () => []).add(r);
  }
  for (final MapEntry(key: glyph, value: rects) in glyphs.entries) {
    add(
      'insignia',
      glyph,
      '$glyph states',
      InsigniaAtlas.file,
      [
        for (final r in rects) [AtlasLayer(r)],
      ],
      2,
      [
        for (final id in InsigniaAtlas.rects.keys)
          if (id.startsWith('$glyph/')) id,
      ].join(', '),
    );
  }

  // --- hatch-emergence.png: the climb-out poses, one row per species.
  const hw = HatchEmergenceAtlas.cellWidth * 1.0;
  const hh = HatchEmergenceAtlas.cellHeight * 1.0;
  for (final (row, species) in HatchEmergenceAtlas.rows.indexed) {
    add(
      'carrier-hatch-emergence',
      species,
      '$species climb-out (${HatchEmergenceAtlas.poses.first}..'
          '${HatchEmergenceAtlas.poses.last})',
      HatchEmergenceAtlas.asset.split('/').last,
      _run(hw, hh, row, 0, HatchEmergenceAtlas.poses.length),
      8,
      'row $row cols 0-${HatchEmergenceAtlas.poses.length - 1}',
    );
  }

  // --- sentinel-silhouettes.png: the foreshadowing silhouettes' banks.
  for (var species = 0; species < 2; species++) {
    for (var blur = 0; blur < 2; blur++) {
      add(
        'sentinel',
        'silhouette-${species == 0 ? 'warden' : 'colossus'}-'
            '${blur == 0 ? 'near' : 'far'}',
        'silhouette bank sweep, ${blur == 0 ? 'near' : 'far (blurred)'}',
        SentinelSilhouetteAtlas.file,
        [
          for (var f = 0; f < SentinelSilhouetteAtlas.frames; f++)
            [AtlasLayer(SentinelSilhouetteAtlas.cell(species, f, blur))],
        ],
        4,
        'row ${species * 2 + blur} cols 0-${SentinelSilhouetteAtlas.frames - 1}',
      );
    }
  }

  // --- ground-wildlife.png: each sector's flock flyer, flapping.
  for (var s = 0; s < GroundWildlifeAtlas.flockSpecies.length; s++) {
    add(
      'flyover-${_sectorNames[s]}',
      'flock-${GroundWildlifeAtlas.flockSpecies[s]}',
      '${GroundWildlifeAtlas.flockSpecies[s]} flock flap',
      GroundWildlifeAtlas.file,
      [
        for (var flap = 0; flap < 2; flap++)
          [AtlasLayer(GroundWildlifeAtlas.flock(s, flap))],
      ],
      6,
      'row $s',
    );
  }

  // --- flyover creatures and vegetation.
  for (final cr in FlyoverAtlas.creatures) {
    final w = cr.w * 1.0, h = cr.h * 1.0;
    List<List<AtlasLayer>> cols(int a, int n) => [
      for (var i = a; i < a + n; i++)
        [AtlasLayer(Rect.fromLTWH(i * w, cr.y * 1.0, w, h))],
    ];
    final g = 'flyover-${_sectorNames[cr.sector]}';
    add(
      g,
      '${cr.id}-${cr.gait}',
      '${cr.id} ${cr.gait}',
      'flyover-creatures.png',
      cols(0, 4),
      cr.gait == 'crawl' ? 5 : 8,
      'y ${cr.y} frames 0-3',
    );
    add(
      g,
      '${cr.id}-duck-burrow',
      '${cr.id} duck, burrow',
      'flyover-creatures.png',
      cols(4, 4),
      4,
      'y ${cr.y} frames 4-7',
    );
  }
  const vw = VegetationAtlas.cellW * 1.0, vh = VegetationAtlas.cellH * 1.0;
  for (final sp in VegetationAtlas.species) {
    final g = 'flyover-${_sectorNames[sp.sector]}';
    add(
      g,
      '${sp.id}-sway',
      '${sp.id} idle sway',
      'flyover-vegetation.png',
      _run(vw, vh, sp.row, VegetationAtlas.idleA, 2),
      2,
      'row ${sp.row} cols 0-1',
    );
    add(
      g,
      '${sp.id}-push',
      '${sp.id} bend and break',
      'flyover-vegetation.png',
      _run(vw, vh, sp.row, VegetationAtlas.bendA, 6),
      1 / .1,
      'row ${sp.row} cols 2-7',
    );
  }

  // --- comms portraits: every face of every caller.
  const pc = commsPortraitCell * 1.0;
  for (final MapEntry(key: id, value: row) in commsPortraitRows.entries) {
    add(
      'portraits',
      id,
      '${commsCast[id]?.name ?? id} faces',
      'comms-portraits.png',
      _run(pc, pc, row, 0, CommsFrame.count),
      4,
      'row $row cols 0-13',
    );
  }
  return out;
}

/// The sector flyover backgrounds, one item per sector (routes are a
/// control inside the view, recorded in a note's section).
const sectorTitles = [
  'KRYBOR',
  'RINGFALL',
  'EMBER MOON',
  'THE HOLLOW',
  'THE CARRIER',
];

List<ReviewAsset> backgroundAssets() => [
  for (var s = 0; s < 5; s++)
    ReviewAsset(
      kind: ReviewKind.background,
      id: 'sector-${s + 1}',
      title: 'Sector ${s + 1} · ${sectorTitles[s]}',
      source:
          'assets/images/flyover-${_sectorNames[s]}.png, '
          'flyover-${_sectorNames[s]}-ground.png, sector-${s + 1}.webp',
      detail: 'flyover parallax, landmarks, critters, vegetation',
    ),
];

/// The image files a background hash covers, in order.
List<String> backgroundFiles(int sector) => [
  'assets/images/flyover-${_sectorNames[sector]}.png',
  'assets/images/flyover-${_sectorNames[sector]}-ground.png',
  'assets/images/sector-${sector + 1}.webp',
  'assets/images/flyover-props.png',
  'assets/images/flyover-creatures.png',
  'assets/images/flyover-vegetation.png',
];

/// One radio clip of the bank.
class RadioClip {
  RadioClip(this.trigger, this.line, this.character);
  final CommsTriggerSpec trigger;
  final CommsLine line;
  final CommsCharacter character;

  /// `web/audio/comms/manifest.json` entry (engine, lufs, peak, sha256).
  Map<String, Object?> meta = const {};

  bool get demon => character.isDemon;

  /// The event that fires it: the trigger without its sector suffix.
  String get event => trigger.name.split('.').first;

  /// Emotion for humans, vocal gesture for demon grunts.
  String get emotion => line.emotion ?? line.grunt ?? '';
  String get subtitle => line.text ?? line.gloss ?? '';
  String get url => 'audio/comms/${Uri.encodeComponent(line.id)}.ogg';

  String? get hash => switch (meta['sha256']) {
    {'ogg': final String h} => h,
    _ => null,
  };

  ReviewAsset asset() => ReviewAsset(
    kind: ReviewKind.radio,
    id: line.id,
    title: '${character.name} · ${trigger.name}',
    source: 'web/audio/comms/${line.id}.ogg',
    hash: hash,
    detail: subtitle,
  );
}

List<RadioClip> radioClips() => [
  for (final table in [commsHumanTriggers, commsDemonTriggers])
    for (final trigger in table.values)
      for (final line in trigger.lines)
        if (commsCast[line.speaker] case final who?)
          RadioClip(trigger, line, who),
];

/// One music cue: a section of the MIDI-first score
/// (`web/audio/score/score.json`), named `song/section`.
class MusicCue {
  MusicCue(this.name, this.meta);
  final String name;
  final Map<String, Object?> meta;

  double _num(String key, double fallback) =>
      (meta[key] as num?)?.toDouble() ?? fallback;
  String get kind => meta['kind'] as String? ?? 'loop';
  double get seconds => _num('seconds', 0);
  double get bpm => _num('bpm', 120);
  double get barSeconds => (meta['barSamples'] as num?) != null
      ? _num('barSamples', 96000) / 48000
      : 240 / bpm;
  double? get loopStart => (meta['loopStart'] as num?)?.toDouble();
  double? get loopEnd => (meta['loopEnd'] as num?)?.toDouble();

  /// Named slots of a sprite cue (accents, stem layers), each [slotSeconds].
  List<String> get slots => [
    for (final s in meta['slots'] is List ? meta['slots'] as List : const [])
      '$s',
  ];
  double get slotSeconds => _num('slotSeconds', 1.5);

  /// The sector the cue's song plays in (1-4 the worlds, 5 the carriers),
  /// else 0 (the overture, the bridges, the defeat, the coda).
  int get level => (meta['level'] as num?)?.toInt() ?? 0;

  /// Stems: the score has none (its layers are track masks).
  bool get stem => false;
  String get file => meta['file'] as String? ?? '$name.mid';
  String get url => 'audio/score/$file';

  /// The section's MIDI file in the repository.
  String? get score => 'web/audio/score/$file';
  String? get hash => meta['sha256'] as String?;

  ReviewAsset asset() => ReviewAsset(
    kind: ReviewKind.music,
    id: name,
    title: name,
    source: 'web/audio/score/$file',
    hash: hash,
    detail:
        '$kind · ${seconds.toStringAsFixed(1)} s · ${bpm.toStringAsFixed(0)} BPM',
  );
}

/// The score's sections as cues, from `web/audio/score/score.json`.
List<MusicCue> musicCues(Map<String, Object?> manifest) {
  final songs = manifest['songs'];
  if (songs is! Map) return const [];
  final levels = <String, int>{
    for (final p in manifest['plays'] is List ? manifest['plays'] as List : [])
      if (p is Map) '${p['song']}': (p['level'] as num).toInt(),
  };
  final list = [
    for (final MapEntry(key: id, value: song) in songs.entries)
      if (song is Map && song['sections'] is Map)
        for (final MapEntry(key: sid, value: s)
            in (song['sections'] as Map).entries)
          if (s is Map)
            MusicCue('$id/$sid', {
              'kind': s['kind'],
              'file': s['file'],
              'sha256': s['sha256'],
              'barSamples': song['barSamples'],
              'bpm': song['bpm'],
              'level': levels['$id'] ?? 0,
              'seconds':
                  ((s['bars'] as num) + ((s['hold'] as num?) ?? 0)) *
                  (song['barSamples'] as num) /
                  48000,
            }),
  ];
  list.sort((a, b) {
    final l = (a.level == 0 ? 9 : a.level).compareTo(
      b.level == 0 ? 9 : b.level,
    );
    return l != 0 ? l : a.name.compareTo(b.name);
  });
  return list;
}

/// --- dev-pages-overhaul: the game areas the gallery's scenes are grouped
/// by, in the order the gallery and the studio list them.
enum GameArea {
  swarm('SWARM'),
  ship('SHIP'),
  sentinels('SENTINELS'),
  carrier('CARRIER'),
  ground('GROUND WAR'),
  weather('WEATHER'),
  bonus('BONUS LEVELS'),
  performance('PERFORMANCE'),
  medals('MEDALS');

  const GameArea(this.label);
  final String label;
}

/// One gallery scene page: its address (`?page=<id>`), title, game area,
/// the OpenSpec changes or specs it shows ([sources]: a change id under
/// `openspec/changes/` or its archive, or a capability under
/// `openspec/specs/`), and the image files its painters read by name.
class ScenePage {
  const ScenePage(
    this.id,
    this.title,
    this.area,
    this.sources, {
    this.assets = const [],
    this.live = false,
  });
  final String id, title;
  final GameArea area;
  final List<String> sources;

  /// `assets/images/` files the scene draws (named literally in the game).
  final List<String> assets;

  /// Whether the scene runs the game's own simulation (a console-style run)
  /// rather than a staged, frozen model.
  final bool live;

  /// "carrier-v3 · carrier-hatches", for the scene's label.
  String get sourceLabel => sources.join(' · ');
}

/// The gallery's scene pages (lib/review/gallery_scenes.dart builds them).
/// Every scene draws with the game's own DemonScene and its presentation
/// pipeline (atlases, hero hulls, ground blocks, weather, the perf tier),
/// on a model started the way the game starts one.
const scenePages = <ScenePage>[
  ScenePage(
    'creatures',
    'Creatures: molt, angry, hit flash, dive tell, dive',
    GameArea.swarm,
    ['sprite-64-grid-overhaul', 'continuous-swarm'],
    assets: ['combat.png'],
  ),
  ScenePage(
    'elites',
    'Elite armour and fire',
    GameArea.swarm,
    ['sprite-64-grid-overhaul'],
    assets: ['combat.png'],
  ),
  ScenePage(
    'actions',
    'Fire and death loops',
    GameArea.swarm,
    ['sprite-64-grid-overhaul'],
    assets: ['combat.png'],
  ),
  ScenePage(
    'insignia',
    'Rank insignia: the rare-mark ladder over a dense swarm',
    GameArea.swarm,
    ['insignia-ranks', 'gargoyle-insignia', 'alien-insignia'],
    assets: ['combat.png', 'insignia.png'],
  ),
  ScenePage(
    'insignia-waves',
    'Rank insignia in live waves: most of the swarm wears no mark',
    GameArea.swarm,
    ['insignia-ranks'],
    assets: ['combat.png', 'insignia.png'],
    live: true,
  ),
  ScenePage(
    'dive-shields',
    'Dive shields: one arc thinning to its 40 % floor',
    GameArea.swarm,
    ['dive-shield-thinning'],
    assets: ['combat.png', 'sentinel-effects.png'],
  ),
  ScenePage(
    'weapons',
    'Ship weapons and combos',
    GameArea.ship,
    ['combine-powerups', 'asset-review-progression'],
    assets: ['ship-weapons.png', 'ship-weapons.json'],
    live: true,
  ),
  ScenePage(
    'sentinels',
    'Sentinels: hover, damage, dive warning, last stand and rush',
    GameArea.sentinels,
    ['arcade-combat', 'atmosphere-and-swarms'],
    assets: ['sentinel-effects.png', 'sentinel-silhouettes.png'],
  ),
  ScenePage(
    'carrier',
    'Carrier fight: hatches, emergence, approach and decay',
    GameArea.carrier,
    ['carrier-v3', 'carrier-hatches', 'hatch-emergence', 'boss-grandeur'],
    assets: ['hatch-emergence.png'],
    live: true,
  ),
  ScenePage(
    'carrier-tours',
    'Carrier tours: the hero hull of runs 2 to 5',
    GameArea.carrier,
    ['boss-hero-assets', 'carrier-render-engine'],
    assets: ['hatch-emergence.png'],
    live: true,
  ),
  ScenePage(
    'ground-war',
    'Ground war under sectors 1 to 4',
    GameArea.ground,
    ['ground-war-v4', 'ground-blocks-runtime', 'gargoyle-ground-army'],
    assets: ['ground-forces.png', 'ground-atmosphere.png'],
    live: true,
  ),
  ScenePage(
    'weather',
    'Weather: drizzle, rain and downpour',
    GameArea.weather,
    ['dynamic-weather', 'fog-restoration'],
    live: true,
  ),
  ScenePage('bonus', 'Bonus levels', GameArea.bonus, [
    'bonus-levels',
    'bonus-balance',
  ], live: true),
  ScenePage(
    'perf-tiers',
    'Perf tiers: full, lean and lite',
    GameArea.performance,
    ['phone-performance'],
    live: true,
  ),
  ScenePage(
    'medals',
    'Mission medals',
    GameArea.medals,
    ['mission-medals'],
    assets: ['mission-medals.png'],
  ),
];

/// The scene page [id], or null.
ScenePage? scenePage(String id) =>
    scenePages.where((p) => p.id == id).firstOrNull;

ReviewAsset sceneAsset(String page, [String? title]) {
  final p = scenePage(page);
  return ReviewAsset(
    kind: ReviewKind.scene,
    id: page,
    title: title ?? p?.title ?? 'Gallery page: $page',
    source: p == null
        ? 'lib/review/gallery_scenes.dart ?page=$page'
        : 'lib/review/gallery_scenes.dart ?page=$page (${p.sourceLabel})',
  );
}
