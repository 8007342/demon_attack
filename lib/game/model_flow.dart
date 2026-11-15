part of 'model.dart';

// --- cinematic flow (openspec/changes/cinematic-flow, lib/game/flow_director.dart)
//
// The model owns the transition's gameplay clock (phase lengths, the pickup
// grace, skip) and feeds the director that clock; the pursued flock is a
// cosmetic list the scene draws. It is never in [ArcadeModel.demons]: no
// hitbox, no fire, no score, removed before carrier combat.

/// One cosmetic member of the flock a transition plays with: where it was
/// when the rout began, its order in the flock and its phase offset.
class FlowMember {
  FlowMember(this.demon, this.x0, this.y0, this.n0, this.index, this.seed);

  /// The body the scene draws (sprite, veil and shadow).
  final Demon demon;
  final double x0, y0, n0, seed;
  final int index;

  /// Hangar bay this member pours into (boss arrival): -1 left, 1 right.
  int get bay => index.isEven ? -1 : 1;
}

extension ArcadeFlow on ArcadeModel {
  /// The remnant fleeing in a rout is at most this many silhouettes.
  static const remnant = 18;

  /// The sector a transition flies to (transition-ascent design §4).
  int get flowDestination => nextLevel;

  /// The route the destination belongs to.
  int get flowDestinationRoute => level == 5 ? cycle + 1 : cycle;

  /// A plain sector change returning to a sector the squadron has already
  /// fought over in this run (a later tour, or a sector entered before):
  /// its radio slot is a front-line call from [flowDestination]. Boss
  /// arrivals and a carrier's fall are never revisits here (they keep their
  /// own calls).
  bool get flowRevisit {
    if (flow.kind != FlowKind.sectorChange) return false;
    final dest = flowDestination;
    if (dest == 5) return false;
    return flowDestinationRoute > 0 || visitedSectors.contains(dest);
  }

  /// Starts the plan of a sector change (the last kill) or a carrier's fall.
  void _flowBegin({required bool victory}) {
    final reduced = reducedMotion;
    _flowBase = 0;
    _skipPending = false;
    slotExtra = 0;
    if (victory && finalBoss) {
      flow.start(FlowPlan.campaignOutro(reduced: reduced));
    } else {
      flow.start(
        FlowPlan.sectorChange(
          reduced: reduced,
          victory: victory,
          boss: !victory && nextLevel == 5,
        ),
      );
    }
    flow.at(0);
  }

  /// The plan with the Pursuit length the model actually runs (a slot's
  /// reading time, decided before travel starts).
  void _flowReplan() {
    if (flow.kind == FlowKind.campaignOutro || !flow.active) return;
    flow.replan(
      FlowPlan.sectorChange(
        reduced: flow.plan.reduced,
        extra: slotExtra,
        victory: flow.kind == FlowKind.bossVictory,
        boss: flow.kind == FlowKind.bossArrival,
      ),
    );
  }

  /// The creatures that were fighting ([fighters]: a carrier's minions at
  /// its fall) flash-expand and flee toward [direction] (`stream.rout`).
  /// Cosmetic; at most [remnant] silhouettes. Nothing is topped up and
  /// nothing comes out of the fog for it (playtest-fixes): a sector's last
  /// kill leaves no flock at all, the fog stays empty.
  void _flowRout(Iterable<Demon> fighters, {int? direction}) {
    final dir =
        direction ??
        _preloadSide() ??
        (shipX <= ArcadeModel.width / 2 ? 1 : -1);
    final plan = stream.rout(dir);
    flowDirection = plan.direction;
    flowFlock.clear();
    final rng = stream.rngFor(sector: level, route: cycle, wave: 99, salt: 7);
    var i = 0;
    for (final f in fighters.take(remnant)) {
      final n0 = f.nearness > 0 ? f.nearness : .2;
      final d = Demon(f.x, f.y, f.kind, 1, rng.nextDouble() * 10)
        ..swarmState = SwarmState.approaching
        ..arrivesFromDistance = true
        ..entranceProgress = 1
        ..nearness = n0
        ..scale = Perspective.scaleOf(n0);
      flowFlock.add(FlowMember(d, f.x, f.y, n0, i, rng.nextDouble() * 6.28));
      i++;
    }
    // The reserve itself is gone: what remains is the cosmetic flock.
    _reserveGroups.clear();
    _pendingSkeins.clear();
    incoming.clear();
    stream.drain();
  }

  /// The side the next sector's first cohort will come out of the cloud
  /// (`stream.preload` with the very draws `_skeinsOf` will make: the
  /// skein count follows from the roster size, the gates from the seeded
  /// stream). The flock flies there, so the cohort leaves the cloud where
  /// the pursued flock went, and the cohort's own gates (gameplay) are
  /// untouched. Null for the carrier or an all-centre cohort.
  int? _preloadSide() {
    final next = nextLevel;
    if (next == 5) return null;
    final route = level == 5 ? cycle + 1 : cycle;
    final calibrated = policy.rosterCount(sector: next, wave: 1, route: route);
    // --- bonus levels: a bonus level ahead has its own first roster.
    final count = bonusAhead?.waves.roster(calibrated) ?? calibrated;
    final rng = stream.rngFor(sector: next, route: route, wave: 1);
    final plan = stream.preload(List<double>.filled(count, 180), rng);
    for (final s in plan.skeins) {
      if (s.gate.side != 0) return s.gate.side;
    }
    return null;
  }

  /// Advances the flow clock from the phase clock and places the flock.
  void _flowStep() {
    if (!flow.active) return;
    if (flow.kind == FlowKind.gameOverOutro) {
      flow.at(ArcadeModel.defeatDuration - defeatTimer);
    } else {
      flow.at(_flowBase + transitionDuration - transitionLeft);
    }
    _placeFlock();
  }

  /// Ends the flow (the Descent is over, or the run left the transition).
  void _flowEnd() {
    flow.stop();
    flowFlock.clear();
    _skipPending = false;
    slotExtra = 0;
  }

  /// Every member is a pure function of the flow clock, its origin and its
  /// phase offset (macron.dev: no per-actor timers).
  void _placeFlock() {
    if (flowFlock.isEmpty) return;
    final s = flow.seconds;
    final plan = flow.plan;
    final dir = flowDirection.toDouble();
    final rout = plan.beat('rout');
    final routEnd = rout == null ? 0.0 : rout.c;
    final pursue = flow.env('pursue');
    final wheel = flow.env('wheel');
    final mill = flow.env('mill');
    final vacuole = flow.env('vacuole');
    final pour = flow.env('pour');
    final p0 = plan.descentAt - plan.pursuitSeconds;
    final carrier = boss;
    final n = flowFlock.length;
    for (final m in flowFlock) {
      final d = m.demon;
      final (jx, jy) = flow.phase(m.index, m.seed);
      // Rout: a flash expansion from where it was, then a parallel stream
      // into the fog toward [dir] and up toward the far banks.
      final burst = Perspective.smoothstep(0, .4, s) * 26;
      final ax = m.x0 - 180, ay = m.y0 - 160;
      final al = math.max(1.0, math.sqrt(ax * ax + ay * ay));
      final flee = Perspective.smoothstep(.2, math.max(.6, routEnd + .6), s);
      var x = m.x0 + ax / al * burst + dir * 70 * flee + jx * 6;
      var y = m.y0 + ay / al * burst * .6 - 40 * flee + jy * 4;
      var nn = m.n0 + (.3 - m.n0) * flee;
      // Pursuit: ahead of the climbing ship, drifting toward [dir] the whole
      // time (direction is kept across the swap: the motivated cut).
      final pt = (s - p0).clamp(0.0, 20.0);
      final cx = 180 + dir * (-40 + 14 * pt);
      final px = cx + (m.index - (n - 1) / 2) * 13 + jx * 10;
      final py = 92 + (m.index % 3) * 9 + jy * 7;
      x += (px - x) * pursue;
      y += (py - y) * pursue;
      nn += (.36 - nn) * pursue;
      // Descent: the flock streams out at the [dir] side and down the far
      // fog, where the new sector's first cohort comes out of the cloud.
      if (wheel > 0) {
        x += (180 + dir * 230 - x) * wheel * .8;
        y += (130 - y) * wheel * .5;
      }
      // Boss arrival: ring the arrival point, part for the carrier, pour
      // into its bays (ordered by distance, 40 ms apart).
      if (carrier != null && mill > 0) {
        final a = m.index / n * 2 * math.pi + s * .5 * (reducedMotion ? 0 : 1);
        final r = 60 + 70 * vacuole;
        final rx = carrier.x + math.cos(a) * r;
        final ry = carrier.y + math.sin(a) * r * .45;
        x += (rx - x) * mill;
        y += (ry - y) * mill;
        nn += (.42 - nn) * mill;
      }
      if (carrier != null && pour > 0) {
        final order = (m.index * .04).clamp(0.0, .5);
        final k = Perspective.smoothstep(order, order + .5, pour);
        final bx = carrier.x + m.bay * Carrier.sideHatchOffset;
        final by = carrier.y + 14;
        x += (bx - x) * k;
        y += (by - y) * k;
      }
      final oldX = d.x;
      d
        ..x = x
        ..y = y
        ..vx = (x - oldX) * 60
        ..nearness = nn.clamp(.12, .6)
        ..altitude = 30 + 20 * (1 - pursue)
        ..scale = Perspective.scaleOf(nn.clamp(.12, .6));
    }
    if (carrier != null && pour >= 1) flowFlock.clear();
    if (wheel >= 1 && carrier == null) flowFlock.clear();
  }

  /// Seconds of flow opacity for member [m]: it fades into the hangar or
  /// out at the edge (scene).
  double flowOpacity(FlowMember m) {
    final carrier = boss;
    if (carrier != null && flow.on('pour')) {
      final order = (m.index * .04).clamp(0.0, .5);
      return 1 -
          Perspective.smoothstep(order + .3, order + .5, flow.env('pour'));
    }
    return 1 - Perspective.smoothstep(.5, 1, flow.env('wheel'));
  }

  /// Skip (tap, Space, Enter) during a sector transition: jumps to the
  /// Descent at once, or at the Rout's end so the pickup grace is never cut.
  /// Returns false when there is nothing to skip.
  bool _skipTransition() {
    final phase = mode;
    if (phase == RunMode.salvage) {
      _skipPending = true;
      return true;
    }
    if (phase == RunMode.levelClear ||
        phase == RunMode.travel ||
        (phase == RunMode.victory && !finalBoss)) {
      if (phase == RunMode.victory) _flowBase = flow.plan.descentAt;
      _finishTravel();
      return true;
    }
    return false;
  }

  /// The end of travel: the next sector (or the next route's first) begins
  /// and its arrival is the Descent.
  void _finishTravel() {
    if (level == 5) cycle++;
    level = nextLevel;
    shipX = targetX = 180;
    shipVx = shipBank = shipThrust = 0;
    steering = aimAngle = 0;
    _steeringActive = false;
    final base = flow.active ? flow.plan.descentAt : 0.0;
    _beginLevel();
    if (flow.active) {
      _flowBase = base;
      flow.at(base);
    }
  }
}
