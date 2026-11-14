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
import '../game/boss_atlas.dart';
import '../game/flyover_atlas.dart';
import '../game/ground_atlas.dart';
import '../game/ground_troops_atlas.dart';
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

  // --- boss hulls: idle bow per form (patch frames over frame 0), plumes.
  for (final hull in BossAtlas.classes) {
    AtlasLayer layer(BossSprite s) => AtlasLayer(
      Rect.fromLTWH(s.x * 1.0, s.y * 1.0, s.w * 1.0, s.h * 1.0),
      Offset(s.dx * 2, s.dy * 2),
    );
    for (var form = 0; form < hull.forms; form++) {
      final frames = [
        for (var i = 0; i < hull.hull[form].length; i++)
          [
            if (i > 0 && hull.hullPatch[form][i]) layer(hull.hull[form][0]),
            layer(hull.hull[form][i]),
          ],
      ];
      add(
        'boss-${hull.key}',
        'hull-form-${form + 1}',
        '${hull.title} form ${form + 1}',
        hull.asset,
        frames,
        4,
        'hull[$form]',
      );
    }
    for (var stage = 0; stage < hull.damage.length; stage++) {
      add(
        'boss-${hull.key}',
        'damage-${stage + 1}',
        'damage stage ${stage + 1}',
        hull.asset,
        [
          for (final s in hull.damage[stage]) [layer(s)],
        ],
        5,
        'damage[$stage]',
      );
    }
    for (var size = 0; size < hull.plumes.length; size++) {
      add(
        'boss-${hull.key}',
        'plume-$size',
        'engine plume size $size (thrust 0-2)',
        hull.asset,
        [
          for (final thrust in hull.plumes[size])
            for (final s in thrust) [layer(s)],
        ],
        8,
        'plumes[$size]',
      );
    }
  }

  // --- ground-forces.png (GroundAtlas).
  const gw = GroundAtlas.cellW * 1.0, gh = GroundAtlas.cellH * 1.0;
  for (var s = 0; s < 4; s++) {
    final g = 'ground-${_sectorNames[s]}';
    final row = GroundAtlas.demonRow(s);
    add(
      g,
      'demon-move',
      'demon unit move',
      'ground-forces.png',
      _run(gw, gh, row, GroundAtlas.moveCol, GroundAtlas.moveFrames),
      6,
      'row $row cols 0-3',
    );
    add(
      g,
      'demon-fire',
      'demon telegraph and fire',
      'ground-forces.png',
      _run(gw, gh, row, GroundAtlas.telegraphCol, 4),
      6,
      'row $row cols 4-7',
    );
    add(
      g,
      'demon-wreck',
      'demon wreck',
      'ground-forces.png',
      _run(gw, gh, row, GroundAtlas.wreckCol, 2),
      4,
      'row $row cols 8-9',
    );
    for (var v = 0; v < GroundAtlas.allyVariants; v++) {
      final ally = GroundAtlas.allyRow(s, v);
      add(
        g,
        'ally-$v-move',
        'ally ${v + 1} move',
        'ground-forces.png',
        _run(gw, gh, ally, GroundAtlas.allyMoveCol, GroundAtlas.allyMoveFrames),
        6,
        'row $ally cols 0-3',
      );
      add(
        g,
        'ally-$v-hit',
        'ally ${v + 1} hit, totalled, pod',
        'ground-forces.png',
        _run(gw, gh, ally, GroundAtlas.allyHitCol, 4),
        4,
        'row $ally cols 4-7',
      );
      add(
        g,
        'ally-$v-turret',
        'ally ${v + 1} turret angles',
        'ground-forces.png',
        _run(
          gw,
          gh,
          ally,
          GroundAtlas.allyTurretCol,
          GroundAtlas.allyTurretFrames,
        ),
        4,
        'row $ally cols 8-12',
      );
    }
  }
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

  // --- ground-troops.png (GroundTroopsAtlas).
  const tw = GroundTroopsAtlas.cellW * 1.0, th = GroundTroopsAtlas.cellH * 1.0;
  for (final (row, name) in [
    (GroundTroopsAtlas.demonGruntRow, 'demon-grunt'),
    (GroundTroopsAtlas.demonRocketRow, 'demon-rocket'),
    (GroundTroopsAtlas.allyRifleRow, 'ally-rifle'),
    (GroundTroopsAtlas.allyRocketRow, 'ally-rocket'),
  ]) {
    add(
      'troops',
      '$name-walk',
      '$name walk',
      'ground-troops.png',
      _run(
        tw,
        th,
        row,
        GroundTroopsAtlas.walkCol,
        GroundTroopsAtlas.walkFrames,
      ),
      8,
      'row $row cols 0-3',
    );
    add(
      'troops',
      '$name-aim-fire-hit',
      '$name aim, fire, hit',
      'ground-troops.png',
      _run(tw, th, row, GroundTroopsAtlas.aimCol, 3),
      4,
      'row $row cols 4-6',
    );
    add(
      'troops',
      '$name-fall',
      name.startsWith('demon') ? '$name topple, rubble' : '$name run',
      'ground-troops.png',
      _run(tw, th, row, 7, 2),
      4,
      'row $row cols 7-8',
    );
  }
  const tank = GroundTroopsAtlas.demonTankRow;
  add(
    'troops',
    'tank-move',
    'demon tank move',
    'ground-troops.png',
    _run(
      tw,
      th,
      tank,
      GroundTroopsAtlas.tankMoveCol,
      GroundTroopsAtlas.tankMoveFrames,
    ),
    8,
    'row $tank cols 0-3',
  );
  add(
    'troops',
    'tank-fire',
    'demon tank fire, recoil',
    'ground-troops.png',
    _run(tw, th, tank, GroundTroopsAtlas.tankFireCol, 2),
    6,
    'row $tank cols 4-5',
  );
  add(
    'troops',
    'tank-wreck',
    'demon tank wreck',
    'ground-troops.png',
    _run(
      tw,
      th,
      tank,
      GroundTroopsAtlas.tankWreckCol,
      GroundTroopsAtlas.tankWreckFrames,
    ),
    4,
    'row $tank cols 6-7',
  );
  add(
    'troops',
    'crumble',
    'stone crumble',
    'ground-troops.png',
    _run(
      tw,
      th,
      GroundTroopsAtlas.fxRow,
      GroundTroopsAtlas.crumbleCol,
      GroundTroopsAtlas.crumbleFrames,
    ),
    8,
    'row ${GroundTroopsAtlas.fxRow} cols 5-7',
  );

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
          'flyover-${_sectorNames[s]}-ground.png, sector-${s + 1}.png',
      detail: 'flyover parallax, landmarks, critters, vegetation',
    ),
];

/// The image files a background hash covers, in order.
List<String> backgroundFiles(int sector) => [
  'assets/images/flyover-${_sectorNames[sector]}.png',
  'assets/images/flyover-${_sectorNames[sector]}-ground.png',
  'assets/images/sector-${sector + 1}.png',
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

/// One music cue of `web/audio/music/manifest.json`.
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

  /// Level 1-5 for the level cues, else 0.
  int get level =>
      RegExp(r'^l([1-5])-').firstMatch(name) == null ? 0 : int.parse(name[1]);

  /// Stems: the per-level layer and power slices of the tier masters.
  bool get stem => meta['mode'] == 'stems' || name.endsWith('-accents');
  String get url => 'audio/music/$name.ogg';

  /// The original MIDI score of the cue (web/audio/midi/), when it has one.
  String? get score =>
      RegExp(
        r'^(l[1-5]-(intro|outro|t[1-4])|menu|victory|alienwin|cackle|'
        r'(levelclear|finale)(-fleet)?)$',
      ).hasMatch(name)
      ? 'web/audio/midi/$name.mid'
      : null;
  String? get hash => switch (meta['sha256']) {
    {'ogg': final String h} => h,
    _ => null,
  };

  ReviewAsset asset() => ReviewAsset(
    kind: ReviewKind.music,
    id: name,
    title: name,
    source: 'web/audio/music/$name.ogg',
    hash: hash,
    detail:
        '$kind · ${seconds.toStringAsFixed(1)} s · ${bpm.toStringAsFixed(0)} BPM',
  );
}

List<MusicCue> musicCues(Map<String, Object?> manifest) {
  final cues = manifest['cues'];
  if (cues is! Map) return const [];
  final list = [
    for (final MapEntry(:key, :value) in cues.entries)
      if (value is Map) MusicCue('$key', value.cast<String, Object?>()),
  ];
  list.sort((a, b) {
    final l = (a.level == 0 ? 9 : a.level).compareTo(
      b.level == 0 ? 9 : b.level,
    );
    return l != 0 ? l : a.name.compareTo(b.name);
  });
  return list;
}

/// The gallery's staged DemonScene pages (lib/gallery_main.dart).
const scenePages = <(String, String)>[
  ('creatures', 'Creatures: damage, hit flash, dive warning'),
  ('elites', 'Elite armour and fire'),
  ('actions', 'Fire and death loops'),
  ('weapons', 'Ship weapons and combos'),
  ('sentinels', 'Sentinels: hover, warning, last stand'),
  ('carrier', 'Carrier forms and wrecks'),
];

ReviewAsset sceneAsset(String page, String title) => ReviewAsset(
  kind: ReviewKind.scene,
  id: page,
  title: title,
  source:
      'lib/gallery_main.dart ?page=$page (combat.png, sentinel-effects.png, '
      'ship-weapons.png, boss-*.png)',
);
