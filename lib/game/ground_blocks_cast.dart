import 'ground_blocks_atlas.dart';

/// What a game ground unit is drawn as, independent of the simulation types
/// (so the cast is testable without a model).
enum GroundCastRole {
  /// A threat-front demon vehicle (it can break through and fire).
  threat,

  /// A skirmish demon vehicle.
  skirmishVehicle,

  /// The demon heavy tank.
  heavyTank,

  /// A demon rifle squad trooper (member 0 may be the leader).
  demonRifle,

  /// A demon rocket trooper.
  demonRocket,

  /// An allied convoy vehicle.
  convoy,

  /// An allied rifle or rocket trooper.
  allyRifle,
  allyRocket,
}

/// Which block unit plays each game unit, per sector (openspec change
/// ground-blocks-runtime, design §3). Only units the sector's atlases hold
/// are cast; null means "draw with the old atlases".
abstract final class GroundBlocksCast {
  /// Sector index (0-4, `level − 1`) to the metadata's sector name.
  static String sectorName(int sector) =>
      GroundBlocks.sectors[sector.clamp(0, GroundBlocks.sectors.length - 1)];

  static bool _placed(String sector, String id) =>
      GroundBlocks.placement[sector]?.containsKey(id) ?? false;

  /// The sector's threat vehicle (the old atlas's demon row for the sector).
  static const List<String> _threat = [
    'spout-runner', 'scrapmason', 'kiln-ox', 'belfry', 'belfry',
  ];

  /// Skirmish vehicles: the sector's non-threat Host vehicles and walkers.
  static List<String> skirmishRoster(String sector) => [
        for (final id in const [
          'crocket', 'crocket-captured', 'reliquary', 'hodcrawler', 'carillon',
          'strider', 'chapterhouse',
        ])
          if (_placed(sector, id)) id,
      ];

  /// Convoy vehicles in variant order (two variants per sector).
  static List<String> convoyRoster(String sector) => [
        for (final MapEntry(:key) in GroundBlocks.placement[sector]!.entries)
          if (GroundBlocks.units[key]!.faction == 'fleet' &&
              GroundBlocks.units[key]!.block != 'I')
            key,
      ];

  /// The block unit for a game unit: [role] in [sector] (0-4), with the
  /// unit's [id], the squad [member] and squad size [members] (squads), and
  /// the convoy [variant].
  static String? unitFor(GroundCastRole role, int sector,
      {int id = 0, int member = 0, int members = 1, int variant = 0}) {
    final s = sectorName(sector);
    String? pick(String id) => _placed(s, id) ? id : null;
    switch (role) {
      case GroundCastRole.threat:
        return pick(_threat[sector.clamp(0, _threat.length - 1)]);
      case GroundCastRole.skirmishVehicle:
        final r = skirmishRoster(s);
        return r.isEmpty ? null : r[id % r.length];
      case GroundCastRole.heavyTank:
        return pick('tympanum');
      case GroundCastRole.demonRifle:
        if (member == 0 && members >= 3) {
          final lead = pick('prior') ?? pick('knell');
          if (lead != null) return lead;
        }
        final ranks = [
          for (final r in const ['rubbling', 'ashlar'])
            if (_placed(s, r)) r,
        ];
        return ranks.isEmpty ? null : ranks[id % ranks.length];
      case GroundCastRole.demonRocket:
        return pick('corbel') ?? pick('ashlar');
      case GroundCastRole.convoy:
        final r = convoyRoster(s);
        return r.isEmpty ? null : r[variant % r.length];
      case GroundCastRole.allyRifle:
        return pick('trooper-rifle');
      case GroundCastRole.allyRocket:
        return pick('trooper-rocket');
    }
  }

  /// Every block unit the cast can name in [sector] (contract tests).
  static Set<String> castable(int sector) {
    final s = sectorName(sector);
    return {
      for (final role in GroundCastRole.values)
        for (var id = 0; id < 12; id++)
          for (var m = 0; m < 3; m++)
            ?unitFor(role, sector, id: id, member: m, members: 4, variant: id),
      ...skirmishRoster(s),
    };
  }
}

/// Cell names of one block unit (plan/ground-unit-animation.md §3) and
/// their resolution through the unit's layout. The painter asks only
/// through these, so every name it can request is enumerable.
class GroundBlockCells {
  GroundBlockCells(this.id) : unit = GroundBlocks.units[id]!;
  final String id;
  final GroundBlockUnit unit;

  Map<String, (int, int)> get layout => GroundBlocks.layouts[unit.layout];

  /// Three-digit heading or angle code.
  static String code(double a) => a.abs().floor().toString().padLeft(3, '0');

  bool has(String name) => layout.containsKey(name.substring(id.length + 1));

  /// Frames of `hull.<state>` stored at authored heading [k] (0: none).
  int frames(String state, int k) {
    final h = code(unit.headings[k]);
    var n = 0;
    while (layout.containsKey('hull.$state.h$h.f$n')) {
      n++;
    }
    if (n == 0 && layout.containsKey('hull.$state.h$h')) n = 1;
    return n;
  }

  /// The authored heading index that holds `hull.<state>`, preferring
  /// [prefer]; null when the unit has no such state.
  int? headingOf(String state, [int prefer = -1]) {
    if (prefer >= 0 && frames(state, prefer) > 0) return prefer;
    for (var k = unit.headings.length - 1; k >= 0; k--) {
      if (frames(state, k) > 0) return k;
    }
    return null;
  }

  String _hull(String state, int k, int f) {
    final h = code(unit.headings[k]);
    final n = frames(state, k);
    if (n == 0) return '$id.hull.${unit.block == 'I' ? 'walk' : 'move'}.h$h.f0';
    final base = '$id.hull.$state.h$h';
    return layout.containsKey('hull.$state.h$h.f0')
        ? '$base.f${f % n}'
        : base;
  }

  /// A hull cell: [state] at heading [k] frame [f] (wrapping); a state the
  /// heading lacks falls back to `move` frame 0 (base cells always exist).
  String hull(String state, int k, int f) => _hull(state, k, f);

  /// A whole-unit state cell stored at one heading (special, wreck, arrive,
  /// idle, infantry actions): the heading that holds it, else [k]'s move.
  /// Returns the cell and the heading index it was drawn at.
  (String, int) state(String state, int k, int f) {
    final at = headingOf(state, k);
    if (at == null) return (_hull('move', k, 0), k);
    return (_hull(state, at, f), at);
  }

  /// Move-cycle length at heading [k] (4 vehicles and infantry, 6 walkers).
  int moveFrames(int k) =>
      frames(unit.block == 'I' ? 'walk' : 'move', k);

  /// The articulated layer at angle [a] (aim, fire, or a Sextant elevation).
  String art(int a, {bool fire = false, int elevation = 0}) {
    final c = code(unit.angles[a]);
    if (fire && layout.containsKey('art.fire.a$c')) return '$id.art.fire.a$c';
    if (elevation > 0 && layout.containsKey('art.aim.a$c.f$elevation')) {
      return '$id.art.aim.a$c.f$elevation';
    }
    return '$id.art.aim.a$c';
  }

  bool get hasArt => unit.angles.isNotEmpty;

  /// An overlay on the hull at heading [k] (`lights`, `dmg1`, `dmg2`, and
  /// `fill1–3` for a unit without a layer); null when not stored.
  String? hullOverlay(String state, int k) {
    final name = 'fx.$state.h${code(unit.headings[k])}';
    return layout.containsKey(name) ? '$id.$name' : null;
  }

  /// An overlay on the layer at angle [a] (`fill1–3`, Fleet `dent`).
  String? artOverlay(String state, int a) {
    if (!hasArt) return null;
    final name = 'fx.$state.a${code(unit.angles[a])}';
    return layout.containsKey(name) ? '$id.$name' : null;
  }

  /// Debris sheet [s] (Host) or the Fleet shard sheet.
  String? debris(int s) {
    for (final n in ['debris.sheet.f$s', if (s == 0) 'debris.shards.f0']) {
      if (layout.containsKey(n)) return '$id.$n';
    }
    return null;
  }
}
