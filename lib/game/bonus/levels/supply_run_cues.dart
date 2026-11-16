// --- mission-medals: Supply Run clarity (openspec/changes/mission-medals,
// specs/bonus-supply-run-clarity)
//
// The level's rule of play is data (crates, rules, scoring in
// `supply_run.dart`). This mechanic adds no rule: it only watches the
// crates and the cargo so the painter can show what the player did
// (`supply_run_painter.dart`) and the radio can answer it. It draws no
// random numbers, awards nothing and never touches a creature, so the
// bonus-balance gate is unchanged (plan/calibration-current.md).
//
// What it records, per visit:
// - a pop where a crate was shot open (a burst ring, then the cargo);
// - a catch where cargo reached the ship (a flash at the ship);
// - the crates opened and the cargo caught (the tally in the corner);
// - a crate that fell past unopened queues `bonusCrateMissed` (banter).
import '../../model.dart' show ArcadeBonus, ArcadeModel, Pickup, SupplyCrate;
import '../../game_events.dart' show GameEventNames;
import '../bonus_mechanic.dart';

/// One presentation mark: where and how long ago (seconds).
class SupplyCue {
  SupplyCue(this.x, this.y, {this.bonus = false});
  final double x, y;

  /// The crate or the cargo was a bonus-only power.
  final bool bonus;
  double age = 0;
}

class SupplyRunCues extends BonusMechanic {
  SupplyRunCues(BonusMechanicContext context);

  /// How long a pop or a catch mark stays drawn.
  static const life = .7;

  /// The cargo counts as caught when it vanished this close to the ship.
  static const catchReach = 34.0;

  final pops = <SupplyCue>[];
  final catches = <SupplyCue>[];

  /// Crates shot open and cargo caught in this visit.
  int opened = 0, caught = 0;

  /// Seconds since the tally last grew (the painter pulses it).
  double tallyAge = 99;

  final _crates = <SupplyCrate, (double, double)>{};
  final _cargo = <Pickup, (double, double, bool)>{};

  @override
  void step(ArcadeModel model, double dt) => _watch(model, dt);

  @override
  void idle(ArcadeModel model, double dt) => _watch(model, dt);

  void _watch(ArcadeModel model, double dt) {
    for (final c in [...pops, ...catches]) {
      c.age += dt;
    }
    pops.removeWhere((c) => c.age > life);
    catches.removeWhere((c) => c.age > life);
    tallyAge += dt;

    final crates = model.supplyCrates.toSet();
    for (final MapEntry(key: crate, value: (x, y)) in _crates.entries) {
      if (crates.contains(crate)) continue;
      if (crate.destroyed) {
        pops.add(SupplyCue(x, y, bonus: crate.bonus != null));
        opened++;
        tallyAge = 0;
      } else if (y > ArcadeModel.shipY && model.combat) {
        // Fell past the ship unopened (not the clear's burst).
        model.bonusEvent(GameEventNames.bonusCrateMissed, {
          'variant': model.bonus?.id ?? '',
        });
      }
    }
    _crates
      ..clear()
      ..addEntries([for (final c in crates) MapEntry(c, (c.x, c.y))]);

    final cargo = model.pickups.toSet();
    for (final MapEntry(key: p, value: (x, y, bonus)) in _cargo.entries) {
      if (cargo.contains(p)) continue;
      // A collected pickup is moved below the arena and then dropped, so
      // its last seen place is the test: next to the ship, or not.
      final near =
          (x - model.shipX).abs() < catchReach &&
          (y - ArcadeModel.shipY).abs() < catchReach;
      if (near) {
        catches.add(SupplyCue(model.shipX, ArcadeModel.shipY, bonus: bonus));
        caught++;
        tallyAge = 0;
      }
    }
    _cargo
      ..clear()
      ..addEntries([
        for (final p in cargo) MapEntry(p, (p.x, p.y, p.bonus != null)),
      ]);
  }
}
