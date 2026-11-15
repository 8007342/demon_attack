import 'dart:math' as math;

/// boss-grandeur §7: the composable boss grammar. A boss is a spine plus
/// module slots; each tour adds modules and scale; beyond tour 5 a seeded
/// assembly keeps later runs growing within the same budgets. Visual only:
/// every assembly shares the carrier's simulation geometry (core window,
/// bays, turret pivots, solid body, force field, side hatches), and no
/// module changes health, shield or fire budgets (those stay in
/// `DifficultyPolicy`). The art for each module comes from the hull's
/// packed view set (`BossHeroAtlas`, boss-hero-assets; the same catalogue
/// is `art/families/boss-hulls.json`).
///
/// Operator R8 (art redirection, 2026-11-15): the carrier is a GIANORMOUS
/// alien ship that may spill off-screen; per-run variety comes from module
/// **sets** picked per run (seeded, [BossGrammar.forRun]) and each tour
/// escalates with more guns, spikes and barriers ([BossAssembly.ornaments]).
enum BossSlot {
  spine,
  bow,
  tower,
  pylon,
  engine,
  turret,
  bayPod,
  sail,
  keel,
  broodSac,
}

enum BossMount { dorsal, ventral, lateral, bow, stern }

enum BossModuleSize { s, m, l }

/// What a module does in the fight: nothing (most), or it dresses one of the
/// existing turret pivots or bays. Never anything new.
enum BossModulePlay { none, turret, bay }

/// Visual-only escalation pieces (R8.4): guns, spikes and barriers.
enum BossOrnament { gun, spike, barrier }

/// A catalogue entry.
class BossModuleSpec {
  const BossModuleSpec(
    this.slot, {
    required this.mount,
    this.pair = false,
    this.size = BossModuleSize.m,
    this.play = BossModulePlay.none,
    this.area = 1,
    this.atlasCost = 1,
  });
  final BossSlot slot;
  final BossMount mount;

  /// Mirrored pair (two instances, left and right).
  final bool pair;
  final BossModuleSize size;
  final BossModulePlay play;

  /// Silhouette area and atlas cost in frigate-module units (a budget
  /// measure, checked against the real pack by tools/boss_sheet).
  final double area, atlasCost;
}

/// One placed module: its spec, side (−1 left, 0 centre, 1 right) and its
/// place in the detach order (null: never detaches; the spine and bow).
class BossModule {
  const BossModule(this.spec, this.side, this.detachOrder,
      {this.variant = 0, this.name});
  final BossModuleSpec spec;
  final int side;
  final int? detachOrder;

  /// Which of the hull's art sets this module is drawn from.
  final int variant;
  final String? name;

  BossSlot get slot => spec.slot;
  String get id => name ?? baseId;
  String get baseId {
    final base = switch (slot) {
      BossSlot.bayPod => 'bayPod',
      BossSlot.broodSac => 'broodSac',
      _ => slot.name,
    };
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

  /// Zero-based route (tour) and the hull family it is drawn from.
  final int tour;
  final String hull;
  final List<BossModule> modules;

  /// Visual extent scale (×1.0 frigate … ×1.6 dreadnought).
  final double extent;

  /// The module set picked for this run (R8.6).
  final int set;

  /// Visual-only escalation (R8.4): guns, spikes and barriers.
  final List<BossOrnament> ornaments;

  int get count => modules.length;
  double get area => modules.fold(0.0, (a, m) => a + m.spec.area) * extent;
  double get atlasCost =>
      modules.fold(0.0, (a, m) => a + m.spec.atlasCost) * extent;

  /// Every pair has both sides and the centre modules are unpaired.
  bool get symmetric {
    final counts = <BossSlot, (int, int)>{};
    for (final m in modules) {
      final (l, r) = counts[m.slot] ?? (0, 0);
      counts[m.slot] = m.side < 0 ? (l + 1, r) : (m.side > 0 ? (l, r + 1) : (l, r));
      if (m.spec.pair == (m.side == 0)) return false;
    }
    return counts.values.every((c) => c.$1 == c.$2);
  }

  /// Module ids in detach order (the spine last): what breaks away at each
  /// form change and in the collapse.
  List<String> get detachOrder => [
    for (final m in [...modules]
      ..sort((a, b) => (a.detachOrder ?? 99).compareTo(b.detachOrder ?? 99)))
      m.id,
  ];

  bool get hasTurret =>
      modules.any((m) => m.spec.play == BossModulePlay.turret);
}

abstract final class BossGrammar {
  /// The catalogue (design §7).
  static const catalogue = <BossSlot, BossModuleSpec>{
    BossSlot.spine: BossModuleSpec(BossSlot.spine,
        mount: BossMount.dorsal, size: BossModuleSize.l, area: 3, atlasCost: 3),
    BossSlot.bow: BossModuleSpec(BossSlot.bow,
        mount: BossMount.bow, size: BossModuleSize.l, play: BossModulePlay.turret,
        area: 2.5, atlasCost: 3),
    BossSlot.tower: BossModuleSpec(BossSlot.tower, mount: BossMount.dorsal),
    BossSlot.pylon: BossModuleSpec(BossSlot.pylon,
        mount: BossMount.lateral, pair: true, area: .9, atlasCost: .9),
    BossSlot.engine: BossModuleSpec(BossSlot.engine,
        mount: BossMount.stern, pair: true, area: .8, atlasCost: .8),
    BossSlot.turret: BossModuleSpec(BossSlot.turret,
        mount: BossMount.dorsal, size: BossModuleSize.s,
        play: BossModulePlay.turret, area: .4, atlasCost: .5),
    BossSlot.bayPod: BossModuleSpec(BossSlot.bayPod,
        mount: BossMount.ventral, pair: true, play: BossModulePlay.bay,
        area: .7, atlasCost: .7),
    BossSlot.sail: BossModuleSpec(BossSlot.sail, mount: BossMount.dorsal),
    BossSlot.keel: BossModuleSpec(BossSlot.keel,
        mount: BossMount.ventral, area: .8, atlasCost: .8),
    BossSlot.broodSac: BossModuleSpec(BossSlot.broodSac,
        mount: BossMount.lateral, pair: true, area: .8, atlasCost: .8),
  };

  static const hulls = [
    'frigate',
    'cruiser',
    'battlecruiser',
    'battleship',
    'dreadnought',
  ];

  /// Extent per tour (×1.0 … ×1.6).
  static const extents = [1.0, 1.15, 1.3, 1.45, 1.6];

  /// Module counts per tour (5 / 8 / 11 / 14 / 17).
  static const counts = [5, 8, 11, 14, 17];

  /// Budgets of every assembly, the seeded ones included.
  static const maxModules = 19;
  /// Silhouette bound: at most the extent of a ×1.7 hull (the dreadnought's
  /// area scaled from ×1.6 to ×1.7).
  static const maxArea = 1.7;

  /// Atlas budget in module cost units: the dreadnought's cost plus the
  /// same ±12 % headroom tools/boss_sheet budgets measured (≤ 16 MB).
  static double get maxAtlasCost => tour(4).atlasCost * 1.12;

  /// What each tour adds (design §7, table).
  static const _adds = <List<(BossSlot, int)>>[
    [(BossSlot.spine, 0), (BossSlot.bow, 0), (BossSlot.tower, 0), (BossSlot.engine, 2)],
    [(BossSlot.pylon, 2), (BossSlot.turret, 0)],
    [(BossSlot.bayPod, 2), (BossSlot.sail, 0)],
    [(BossSlot.turret, 0), (BossSlot.turret, 0), (BossSlot.keel, 0)],
    [(BossSlot.broodSac, 2), (BossSlot.tower, 0)],
  ];

  static List<BossModule> _place(List<(BossSlot, int)> adds, int set) {
    final out = <BossModule>[];
    var order = 0;
    for (final (slot, n) in adds) {
      final spec = catalogue[slot]!;
      // The spine and the bow (it holds the functional windows) never
      // detach; everything else in the order it was added, outer first.
      final keep = slot == BossSlot.spine || slot == BossSlot.bow;
      final d = keep ? null : ++order;
      if (n == 2) {
        out.add(BossModule(spec, -1, d, variant: set));
        out.add(BossModule(spec, 1, d, variant: set));
      } else {
        out.add(BossModule(spec, 0, d, variant: set));
      }
    }
    // Repeated slots (a second tower, more turrets) get numbered ids.
    final seen = <String, int>{};
    return [
      for (final m in out)
        BossModule(m.spec, m.side, m.detachOrder,
            variant: m.variant,
            name: switch (seen[m.id] = (seen[m.id] ?? 0) + 1) {
              1 => null,
              final n => '${m.id}$n',
            }),
    ];
  }

  /// The authored assembly of tour [route] (0..4).
  static BossAssembly tour(int route, {int set = 0}) {
    final t = route.clamp(0, 4);
    final adds = [for (var i = 0; i <= t; i++) ..._adds[i]];
    return BossAssembly(
      tour: t,
      hull: hulls[t],
      modules: _place(adds, set),
      extent: extents[t],
      set: set,
      ornaments: ornamentsFor(t),
    );
  }

  /// R8.4: each tour escalates with more guns, spikes and barriers.
  static List<BossOrnament> ornamentsFor(int route) {
    final n = 2 + 3 * route;
    return [for (var i = 0; i < n; i++) BossOrnament.values[i % 3]];
  }

  /// The assembly of a run: tour [route]'s (or a seeded one beyond tour 5)
  /// with the run's module set picked from [variant] among [sets] the
  /// hull's art provides (R8.6).
  static BossAssembly forRun({
    required int route,
    required int variant,
    int sets = 1,
    int seed = 1982,
  }) {
    final set = sets <= 1 ? 0 : variant % sets;
    if (route <= 4) return tour(route, set: set);
    return assemble(route: route, seed: seed ^ variant, set: set);
  }

  /// Seeded assembly beyond tour 5: start from the dreadnought set and swap
  /// or add catalogue modules under symmetry, area, count and atlas
  /// budgets; the functional windows stay unobstructed (nothing new is
  /// mounted on the bow).
  static BossAssembly assemble({required int route, required int seed, int set = 0}) {
    final rng = math.Random(seed * 31 + route);
    final adds = [for (final a in _adds) ...a];
    final extra = <BossSlot>[
      BossSlot.turret,
      BossSlot.pylon,
      BossSlot.sail,
      BossSlot.broodSac,
      BossSlot.bayPod,
      BossSlot.keel,
      BossSlot.engine,
      BossSlot.tower,
    ];
    // Swap one non-structural module, then add while the budgets hold.
    final swappable = [
      for (final (i, a) in adds.indexed)
        if (a.$1 != BossSlot.spine && a.$1 != BossSlot.bow) i,
    ];
    final at = swappable[rng.nextInt(swappable.length)];
    final swapTo = extra[rng.nextInt(extra.length)];
    final swapSpec = catalogue[swapTo]!;
    adds[at] = (swapTo, swapSpec.pair ? 2 : 0);
    var best = BossAssembly(
      tour: route,
      hull: hulls.last,
      modules: _place(adds, set),
      extent: extents.last,
      set: set,
      ornaments: ornamentsFor(math.min(route, 8)),
    );
    if (!withinBudgets(best)) {
      adds[at] = (BossSlot.turret, 0);
      best = BossAssembly(
        tour: route,
        hull: hulls.last,
        modules: _place(adds, set),
        extent: extents.last,
        set: set,
        ornaments: ornamentsFor(math.min(route, 8)),
      );
    }
    for (var tries = 0; tries < 6; tries++) {
      final slot = extra[rng.nextInt(extra.length)];
      final spec = catalogue[slot]!;
      final next = [...adds, (slot, spec.pair ? 2 : 0)];
      final candidate = BossAssembly(
        tour: route,
        hull: hulls.last,
        modules: _place(next, set),
        extent: extents.last,
        set: set,
        ornaments: ornamentsFor(math.min(route, 8)),
      );
      if (!withinBudgets(candidate)) continue;
      adds
        ..clear()
        ..addAll(next);
      best = candidate;
    }
    return best;
  }

  static bool withinBudgets(BossAssembly a) =>
      a.count <= maxModules &&
      a.symmetric &&
      a.area <= tour(4).area * maxArea / extents.last + 1e-9 &&
      a.atlasCost <= maxAtlasCost + 1e-9 &&
      a.modules.where((m) => m.spec.mount == BossMount.bow).length == 1;
}
