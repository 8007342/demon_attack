import 'dart:math' as math;

/// boss-grandeur §7, on the v2 art (boss-carrier-wire): the composable boss
/// grammar of the Thornwake carriers (`art/families/alien-carriers.json`,
/// `openspec/changes/boss-hero-assets/design.md` §8). A carrier is a
/// carapace and a prow plus module slots; each tour adds slots (9 → 24
/// instances) and a little extent (×1.00 → ×1.32: escalation is density,
/// not extent). Each slot has interchangeable art **sets**; one set
/// combination per hull is baked (holdout occlusion makes every layer
/// specific to its neighbours, so combinations are never mixed at runtime),
/// and a run picks one of the baked combinations of its tour from the run
/// seed ([BossGrammar.forRun]).
///
/// Visual only: every assembly shares the carrier's simulation geometry
/// (core window, bays, turret pivots, solid body, force field, side
/// hatches), and no module changes health, shield or fire budgets (those
/// stay in `DifficultyPolicy`).
///
/// The superseded v1 frigate grammar (spine, bow, tower, engines …) is
/// retired with its art; its frontal atlases stay as the fallback and its
/// tools (`tools/boss_rig`, `tools/boss_sheet`) stay frozen for provenance.
enum BossSlot {
  carapace,
  prow,
  wing,
  spines,
  emitter,
  blister,
  maw,
  barrier,
  tendril,
  sac,
  crown,
}

enum BossMount { dorsal, ventral, lateral, bow, stern }

enum BossModuleSize { s, m, l }

/// What a module does in the fight: nothing (most), or it carries the
/// existing turret pivots and bays (the prow's hangar deck). Never anything
/// new.
enum BossModulePlay { none, turret, bay }

/// Visual-only escalation pieces (R8.4): guns, spikes and barriers.
enum BossOrnament { gun, spike, barrier }

/// A catalogue entry (one slot of the family).
class BossModuleSpec {
  const BossModuleSpec(
    this.slot, {
    required this.mount,
    this.pair = false,
    this.size = BossModuleSize.m,
    this.play = BossModulePlay.none,
    this.detach,
    this.core = false,
    this.area = 1,
    this.atlasCost = 1,
  });
  final BossSlot slot;
  final BossMount mount;

  /// Mirrored pair (two instances, left and right).
  final bool pair;
  final BossModuleSize size;
  final BossModulePlay play;

  /// Detach rank (form changes and the collapse tear modules away in rank
  /// order); null never detaches: the carapace sinks last, the prow holds
  /// the functional windows.
  final int? detach;

  /// Texel class `core` (2 px/unit, where the player aims) instead of
  /// `mass`.
  final bool core;

  /// Silhouette area and atlas cost in tour-1-module units (a budget
  /// measure; the real pack is measured by `tools/boss_sheet pack`).
  final double area, atlasCost;
}

/// One placed module: its spec, side (−1 left, 0 centre, 1 right), its
/// detach rank and the art set it is drawn from.
class BossModule {
  const BossModule(this.spec, this.side, {this.suffix = '', this.set = ''});
  final BossModuleSpec spec;
  final int side;

  /// A repeated slot's battery (`aft`, `far`, `fore`): `blister_aftL`.
  final String suffix;

  /// The slot's art set in this hull (`scythe`, `fan`, …).
  final String set;

  BossSlot get slot => spec.slot;
  int? get detachOrder => spec.detach;
  String get id {
    final base = suffix.isEmpty ? slot.name : '${slot.name}_$suffix';
    return side < 0 ? '${base}L' : (side > 0 ? '${base}R' : base);
  }
}

/// A boss's assembly for one run.
class BossAssembly {
  const BossAssembly({
    required this.tour,
    required this.hull,
    required this.modules,
    required this.extent,
    this.set = 0,
    this.ornaments = const [],
  });

  /// Zero-based route (tour) and the baked hull it is drawn from
  /// (`carrier<tour>-<set>`, a [BossHeroAtlas] key).
  final int tour;
  final String hull;
  final List<BossModule> modules;

  /// Visual extent scale (×1.00 … ×1.32).
  final double extent;

  /// Index of the picked combination among the tour's baked ones (R8.6).
  final int set;

  /// The set combination's name (`thorn`, `lattice`, `shroud`).
  String get setName => hull.substring(hull.indexOf('-') + 1);

  /// Visual-only escalation (R8.4): guns, spikes and barriers.
  final List<BossOrnament> ornaments;

  int get count => modules.length;
  double get area => modules.fold(0.0, (a, m) => a + m.spec.area) * extent;
  double get atlasCost =>
      modules.fold(0.0, (a, m) => a + m.spec.atlasCost) * extent;

  /// Every pair has both sides and the centre modules are unpaired.
  bool get symmetric {
    final counts = <String, (int, int)>{};
    for (final m in modules) {
      final key = '${m.slot.name}_${m.suffix}';
      final (l, r) = counts[key] ?? (0, 0);
      counts[key] = m.side < 0
          ? (l + 1, r)
          : (m.side > 0 ? (l, r + 1) : (l, r));
      if (m.spec.pair == (m.side == 0)) return false;
    }
    return counts.values.every((c) => c.$1 == c.$2);
  }

  /// Module ids in detach order (the carapace and prow last): what breaks
  /// away at each form change and in the collapse.
  List<String> get detachOrder => [
    for (final m in [
      ...modules,
    ]..sort((a, b) => (a.detachOrder ?? 99).compareTo(b.detachOrder ?? 99)))
      m.id,
  ];

  /// The modules of detach rank [rank].
  Iterable<BossModule> ofRank(int rank) =>
      modules.where((m) => m.detachOrder == rank);

  /// The detach ranks present, in order.
  List<int> get ranks => {
    for (final m in modules)
      if (m.detachOrder != null) m.detachOrder!,
  }.toList()..sort();

  /// The slot that tears away at form change [form] (1-based; the n-th rank
  /// present), or null when the hull has fewer ranks.
  BossSlot? slotAtForm(int form) {
    final r = ranks;
    return form >= 1 && form <= r.length
        ? ofRank(r[form - 1]).first.slot
        : null;
  }

  bool get hasTurret =>
      modules.any((m) => m.spec.play == BossModulePlay.turret);
}

abstract final class BossGrammar {
  /// The catalogue (`art/families/alien-carriers.json` slots).
  static const catalogue = <BossSlot, BossModuleSpec>{
    BossSlot.carapace: BossModuleSpec(
      BossSlot.carapace,
      mount: BossMount.dorsal,
      size: BossModuleSize.l,
      area: 4,
      atlasCost: 3,
    ),
    BossSlot.prow: BossModuleSpec(
      BossSlot.prow,
      mount: BossMount.bow,
      size: BossModuleSize.l,
      play: BossModulePlay.turret,
      core: true,
      area: 2,
      atlasCost: 3,
    ),
    BossSlot.wing: BossModuleSpec(
      BossSlot.wing,
      mount: BossMount.lateral,
      pair: true,
      detach: 3,
      area: 1.2,
      atlasCost: .9,
    ),
    BossSlot.spines: BossModuleSpec(
      BossSlot.spines,
      mount: BossMount.dorsal,
      detach: 1,
      area: .8,
      atlasCost: .7,
    ),
    BossSlot.emitter: BossModuleSpec(
      BossSlot.emitter,
      mount: BossMount.dorsal,
      pair: true,
      size: BossModuleSize.s,
      detach: 4,
      area: .3,
      atlasCost: .3,
    ),
    BossSlot.blister: BossModuleSpec(
      BossSlot.blister,
      mount: BossMount.dorsal,
      pair: true,
      size: BossModuleSize.s,
      detach: 2,
      area: .2,
      atlasCost: .2,
    ),
    BossSlot.maw: BossModuleSpec(
      BossSlot.maw,
      mount: BossMount.lateral,
      pair: true,
      detach: 5,
      area: .5,
      atlasCost: .4,
    ),
    BossSlot.barrier: BossModuleSpec(
      BossSlot.barrier,
      mount: BossMount.bow,
      pair: true,
      detach: 6,
      area: .5,
      atlasCost: .4,
    ),
    BossSlot.tendril: BossModuleSpec(
      BossSlot.tendril,
      mount: BossMount.ventral,
      pair: true,
      detach: 7,
      area: .5,
      atlasCost: .4,
    ),
    BossSlot.sac: BossModuleSpec(
      BossSlot.sac,
      mount: BossMount.dorsal,
      pair: true,
      detach: 8,
      area: .4,
      atlasCost: .3,
    ),
    BossSlot.crown: BossModuleSpec(
      BossSlot.crown,
      mount: BossMount.dorsal,
      size: BossModuleSize.l,
      detach: 9,
      area: .8,
      atlasCost: .6,
    ),
  };

  /// The v1 tour class each tour's carriers replace (the frontal atlas key
  /// in `BossAtlas.classes`, the fallback while a hull is not packed).
  static const classes = [
    'frigate',
    'cruiser',
    'battlecruiser',
    'battleship',
    'dreadnought',
  ];

  /// The baked set combinations of each tour (`art/families/alien-carriers
  /// .json` hulls). Tour 1 has three; tours 2–5 one each so far.
  static const baked = <List<String>>[
    ['carrier1-thorn', 'carrier1-lattice', 'carrier1-shroud'],
    ['carrier2-thorn'],
    ['carrier3-lattice'],
    ['carrier4-shroud'],
    ['carrier5-thorn'],
  ];

  /// The art set of every slot in each set combination (family `sets`;
  /// the prow's set is the combination's own name).
  static const setsOf = <String, Map<BossSlot, String>>{
    'thorn': {
      BossSlot.carapace: 'ridged',
      BossSlot.wing: 'scythe',
      BossSlot.spines: 'ridge',
      BossSlot.emitter: 'spire',
      BossSlot.blister: 'thorn',
      BossSlot.maw: 'slit',
    },
    'lattice': {
      BossSlot.carapace: 'lobed',
      BossSlot.wing: 'fan',
      BossSlot.spines: 'crown',
      BossSlot.emitter: 'lattice',
      BossSlot.blister: 'crystal',
      BossSlot.maw: 'iris',
      BossSlot.barrier: 'palisade',
      BossSlot.tendril: 'barbed',
    },
    'shroud': {
      BossSlot.carapace: 'shroud',
      BossSlot.wing: 'lobe',
      BossSlot.spines: 'forest',
      BossSlot.emitter: 'veil',
      BossSlot.blister: 'hive',
      BossSlot.maw: 'slit',
      BossSlot.barrier: 'wall',
      BossSlot.tendril: 'barbed',
      BossSlot.sac: 'cluster',
    },
  };

  /// Tour-5 overrides of the thorn sets (the hive-crown escalation).
  static const _tour5 = <BossSlot, String>{
    BossSlot.spines: 'forest',
    BossSlot.maw: 'iris',
    BossSlot.barrier: 'wall',
    BossSlot.tendril: 'barbed',
    BossSlot.sac: 'cluster',
    BossSlot.crown: 'blaze',
  };

  /// Extent per tour (×1.00 … ×1.32).
  static const extents = [1.0, 1.08, 1.16, 1.24, 1.32];

  /// Module instances per tour (9 / 13 / 17 / 21 / 24).
  static const counts = [9, 13, 17, 21, 24];

  /// Budgets of every assembly, the seeded ones included.
  static const maxModules = 24;

  /// Silhouette bound: the tour-5 hull's area.
  static const maxArea = 1.0;

  /// Atlas budget in module cost units: tour 5's cost plus the ±12 %
  /// headroom of the measured packs (≤ 16 MB each).
  static double get maxAtlasCost => tour(4).atlasCost * 1.12;

  /// What each tour adds: (slot, battery suffix).
  static const _adds = <List<(BossSlot, String)>>[
    [
      (BossSlot.carapace, ''),
      (BossSlot.prow, ''),
      (BossSlot.wing, ''),
      (BossSlot.spines, ''),
      (BossSlot.emitter, ''),
      (BossSlot.blister, ''),
    ],
    [(BossSlot.blister, 'aft'), (BossSlot.maw, '')],
    [(BossSlot.barrier, ''), (BossSlot.tendril, '')],
    [(BossSlot.blister, 'far'), (BossSlot.sac, '')],
    [(BossSlot.emitter, 'fore'), (BossSlot.crown, '')],
  ];

  static List<BossModule> _place(int tour, String setName) {
    final sets = {...?setsOf[setName], if (tour >= 4) ..._tour5};
    return [
      for (var t = 0; t <= tour; t++)
        for (final (slot, suffix) in _adds[t])
          for (final side in catalogue[slot]!.pair ? const [-1, 1] : const [0])
            BossModule(
              catalogue[slot]!,
              side,
              suffix: suffix,
              set: slot == BossSlot.prow ? setName : (sets[slot] ?? setName),
            ),
    ];
  }

  /// The authored assembly of tour [route] (0..4) for its baked combination
  /// [set] (an index into [baked]).
  static BossAssembly tour(int route, {int set = 0}) {
    final t = route.clamp(0, 4);
    final combos = baked[t];
    final hull = combos[set.clamp(0, combos.length - 1)];
    return BossAssembly(
      tour: t,
      hull: hull,
      modules: _place(t, hull.substring(hull.indexOf('-') + 1)),
      extent: extents[t],
      set: set.clamp(0, combos.length - 1),
      ornaments: ornamentsFor(t),
    );
  }

  /// R8.4: each tour escalates with more guns, spikes and barriers.
  static List<BossOrnament> ornamentsFor(int route) {
    final n = 2 + 3 * route;
    return [for (var i = 0; i < n; i++) BossOrnament.values[i % 3]];
  }

  /// A run's set pick: a 32-bit mix of the run seed and the route, so one
  /// seed gives each tour its own deterministic pick. An unseeded run
  /// (tests, the calibrated campaign) is variant 0: the first combination.
  static int variantFor(int? runSeed, int route) {
    if (runSeed == null) return 0;
    var h = (runSeed ^ 0xB055) * 0x9E3779B1 + route * 0x85EBCA77;
    h &= 0xFFFFFFFF;
    h ^= h >> 15;
    h = (h * 0x2C1B3C6D) & 0xFFFFFFFF;
    h ^= h >> 12;
    return h & 0xFFFF;
  }

  /// The assembly of a run: tour [route]'s (or a seeded one beyond tour 5)
  /// with the run's set combination picked from [variant] among the baked
  /// ones (R8.6). [packed]: the hull keys whose art is in the game; a
  /// combination not packed is never picked while another one is.
  static BossAssembly forRun({
    required int route,
    required int variant,
    Set<String>? packed,
    int seed = 1982,
  }) {
    if (route > 4) {
      return assemble(route: route, seed: seed ^ variant, packed: packed);
    }
    final combos = baked[route];
    final usable = [
      for (final (i, k) in combos.indexed)
        if (packed == null || packed.contains(k)) i,
    ];
    final pick = usable.isEmpty
        ? variant % combos.length
        : usable[variant % usable.length];
    return tour(route, set: pick);
  }

  /// Seeded assembly beyond tour 5: the art is baked per combination, so a
  /// repeat cycle draws one of the largest baked hulls (tours 3–5, all
  /// ≥ 17 modules) picked from the seed, and its ornaments keep growing.
  /// Every pick is a baked, budget-checked hull; the functional windows
  /// stay on the prow.
  static BossAssembly assemble({
    required int route,
    required int seed,
    Set<String>? packed,
  }) {
    final rng = math.Random(seed * 31 + route);
    final pool = [
      for (var t = 2; t <= 4; t++)
        for (final (i, k) in baked[t].indexed)
          if (packed == null || packed.contains(k)) (t, i),
    ];
    final (t, i) = pool.isEmpty ? (4, 0) : pool[rng.nextInt(pool.length)];
    final a = tour(t, set: i);
    return BossAssembly(
      tour: route,
      hull: a.hull,
      modules: a.modules,
      extent: a.extent,
      set: a.set,
      ornaments: ornamentsFor(math.min(route, 8)),
    );
  }

  static bool withinBudgets(BossAssembly a) =>
      a.count <= maxModules &&
      a.symmetric &&
      a.area <= tour(4).area * maxArea + 1e-9 &&
      a.atlasCost <= maxAtlasCost + 1e-9 &&
      a.modules.where((m) => m.slot == BossSlot.prow).length == 1;
}
