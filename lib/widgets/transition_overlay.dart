/// Transition presentation for the arcade page (openspec/changes/
/// cinematic-flow §2.2, built on fluid-transitions and ux-declutter).
///
/// - The run's opening arrival keeps its illustrated tip card (it teaches).
/// - A sector transition shows no card and no floating text: it schedules
///   one message *slot* on the flow clock, always a radio line on the comms
///   dock (playtest-fixes: no caption, no sector or tour title); the medal
///   glyph as a flourish beside the ship. Nothing here is a bar or a strip.
/// - Skip (tap, Space, Enter) closes the opening card, or sends a sector
///   transition to its Descent (the radio line finishes on the dock).
/// main.dart only feeds it the run state and mounts its overlay.
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../comms/comms_bank.dart';
import '../comms/comms_briefing.dart';
import '../comms/comms_director.dart';
import '../comms/comms_transition_chatter.dart';
import '../comms/comms_view.dart'
    show CommsHudStack, CommsLayout, TransitionChatterView;
import '../comms/squad_comms.dart';
import '../game/campaign_story.dart';
import '../game/interlude.dart';
import '../game/model.dart';
import 'interlude_card.dart';
import 'medal.dart';

class TransitionPresenter {
  TransitionPresenter({this.seed});

  /// Fixed interlude seed (tests); null draws one per run.
  final int? seed;
  int _runs = 0;
  late InterludePlanner planner = InterludePlanner(seed: seed);

  // --- the opening card ----------------------------------------------------
  /// The opening card's plan, if one is up.
  InterludePlan? plan;
  double _window = 0;
  bool _open = false, _skipped = false, _tipMuted = false;

  // --- the sector slot -------------------------------------------------------
  /// The message slot of the current sector transition, if one was planned.
  InterludePlan? slot;
  bool _slotPlanned = false;

  /// The radio slot's line: its own pick, or the squad channel's line.
  CommsMessage? _own, shown;

  /// Bank lines this presenter started on the speech player.
  final played = <String>[];

  // --- portrait-comms-lanes: the transition's radio chatter over the
  // clouds (portrait only; the landscape call tiles are unchanged).
  /// The current sector transition's chatter, while its slot is open.
  TransitionChatter? chatter;

  /// Lines an earlier chatter showed that are still on the channel: they
  /// never reappear on the dock.
  final _chatterDone = Set<CommsMessage>.identity();

  /// The second short line this presenter queued for the chatter.
  CommsMessage? _second;

  /// The last layout seen by [build] (the portrait dock, not side tiles).
  bool compact = false;

  /// A line must have this long before the Descent to join the chatter.
  static const chatterMinRead = 2.0;

  /// Lines the dock leaves to the chatter (shown, or shown and still on
  /// the channel).
  Set<CommsMessage> chatterHidden(SquadComms comms) {
    final d = comms.director;
    _chatterDone.removeWhere(
      (m) =>
          !d.active.any((a) => identical(a, m)) &&
          !d.queue.any((q) => identical(q, m)),
    );
    return {...?chatter?.hidden, ..._chatterDone};
  }

  // --- bonus briefing: the urgent-mission card of a bonus level ahead.
  /// The card of the current (or just finished) transition into a bonus
  /// level; null on every other transition.
  BonusBriefing? briefing;

  /// The urgent-mission card is up (it can be dismissed).
  bool briefingOpen(SquadComms comms) => briefing?.open ?? false;

  /// The card is drawn at the comms clock's now.
  bool briefingVisible(SquadComms comms) =>
      briefing?.visible(comms.now) ?? false;

  /// The radio turns the dock leaves to the card.
  Set<CommsMessage> briefingHidden(SquadComms comms) =>
      briefing?.hiddenAt(comms.now) ?? const {};

  /// mission-medals: the card holds the level's start (the model is not
  /// stepped) until it has been read or tapped; see [BonusBriefing.holds].
  bool briefingHolds(ArcadeModel model, SquadComms comms) {
    final b = briefing;
    if (b == null || model.mode == RunMode.paused) return false;
    final flying = slotted(model) && model.flow.active;
    return b.holds(
      comms.director,
      comms.now,
      flying: flying,
      flightLeft: flying ? model.flow.plan.seconds - model.flow.seconds : 0,
    );
  }

  /// Tap on the card, or Space / Enter with nothing else to skip.
  bool dismissBriefing(SquadComms comms) {
    final b = briefing;
    if (b == null || !b.open) return false;
    b.dismiss(comms.director, comms.now);
    return true;
  }

  void _updateBriefing(ArcadeModel model, SquadComms comms) {
    final b = briefing;
    if (b == null) return;
    final flying = slotted(model) && model.flow.active;
    b.update(
      comms.director,
      comms.now,
      flying: flying,
      flightLeft: flying ? model.flow.plan.seconds - model.flow.seconds : 0,
      combat: model.combat,
    );
    if (b.closedAt != null && !b.visible(comms.now)) {
      // Closed and faded: forget it (nothing of it is drawn any more).
      briefing = null;
    } else if (!b.offered && !slotted(model)) {
      // Its transition ended before the slot could offer it.
      briefing = null;
    }
  }

  /// A new run: fresh seeded planner (the opening card is a tip again).
  void newRun(SquadComms comms, {required bool voice}) {
    end(comms, voice: voice);
    _endSlot(comms);
    briefing?.close(comms.director, comms.now);
    briefing = null;
    _open = false;
    planner = InterludePlanner(seed: seed == null ? null : seed! + _runs++);
  }

  /// Seconds left of the opening card's window, or null: the run's opening
  /// arrival (a new run, a resumed run, a console start). Arrivals reached
  /// through a sector transition are its Descent and carry no card.
  static double? windowLeft(ArcadeModel m) {
    if (m.presentationMode == RunMode.transition &&
        m.wave == 1 &&
        !m.isBoss &&
        !m.flow.active) {
      return m.transitionLeft;
    }
    return null;
  }

  double _elapsed(ArcadeModel m) => _window - (windowLeft(m) ?? _window);

  /// The opening card is up.
  bool get showingCard =>
      plan != null && !_skipped && plan!.kind == InterludeKind.tip;

  /// A sector transition's slot plays (a flow with Pursuit).
  static bool slotted(ArcadeModel m) =>
      m.flow.active &&
      const [
        FlowKind.sectorChange,
        FlowKind.bossArrival,
        FlowKind.bossVictory,
      ].contains(m.flow.kind);

  /// The silent opening tip card holds the radio quiet.
  bool quiet(ArcadeModel m) => showingCard;

  /// Tap, Space or Enter has something to skip.
  bool canSkip(ArcadeModel m) =>
      showingCard ||
      (slotted(m) &&
          const [
            RunMode.salvage,
            RunMode.levelClear,
            RunMode.travel,
            RunMode.victory,
          ].contains(m.mode) &&
          !(m.mode == RunMode.victory && m.finalBoss) &&
          !m.skipPending);

  /// Called every frame after the comms tick.
  void update({
    required ArcadeModel model,
    required SquadComms comms,
    required bool voice,
    bool flawless = false,
  }) {
    _updateOpening(model, comms, voice);
    if (model.mode != RunMode.title && slotted(model)) {
      if (!_slotPlanned) _planSlot(model, comms, flawless: flawless);
      _updateSlot(model, comms, voice);
      _updateChatter(model, comms); // --- portrait-comms-lanes
    } else if (_slotPlanned) {
      _endSlot(comms);
    }
    if (model.mode == RunMode.title) {
      briefing?.close(comms.director, comms.now);
      briefing = null;
    }
    _updateBriefing(model, comms);
  }

  void _updateOpening(ArcadeModel model, SquadComms comms, bool voice) {
    final left = model.mode == RunMode.title ? null : windowLeft(model);
    if (left == null) {
      if (_open) end(comms, voice: voice);
      _open = false;
      return;
    }
    if (_open) return;
    _open = true;
    _skipped = false;
    _window = left;
    plan = planner.plan(
      InterludeContext(
        difficulty: model.difficulty,
        level: model.level,
        route: model.cycle,
        window: left,
        crew: comms.lineup?.members ?? const {},
        struggling: model.lives <= 1,
      ),
    );
    if (plan != null && plan!.kind != InterludeKind.tip) {
      // A resumed run's arrival between alternations: no card, the radio
      // carries on as usual.
      plan = null;
    }
    if (plan?.kind == InterludeKind.tip && voice) {
      // Music only: the director holds chatter while the tip is up
      // (urgent and must-play warnings still sound; held lines may play
      // right after). comms-middle-ground `hush`.
      comms.director.hush(left);
      _tipMuted = true;
    }
  }

  /// Plan seconds the slot may start, and how long it has without growing
  /// Pursuit.
  static (double, double) slotWindow(FlowPlan p) {
    final s = p.beat('slot')!;
    return (s.a, p.descentAt - s.a);
  }

  void _planSlot(ArcadeModel model, SquadComms comms, {bool flawless = false}) {
    _slotPlanned = true;
    final (_, room) = slotWindow(model.flow.plan);
    final victory = model.flow.kind == FlowKind.bossVictory;
    final level = model.nextLevel;
    slot = planner.planRadio(
      InterludeContext(
        difficulty: model.difficulty,
        level: level,
        route: victory ? model.cycle + 1 : model.cycle,
        window: room + FlowPlan.maxExtra,
        crew: comms.lineup?.members ?? const {},
        flawless: flawless,
        struggling: model.lives <= 1,
        nextIsCarrier: level == 5,
        revisit: model.flowRevisit, // --- transition ascent
        bonus: model.bonusAhead?.id, // --- bonus levels
      ),
    );
    final s = slot;
    if (s == null) return;
    // --- bonus briefing: the entry call opens the urgent-mission card.
    final ahead = model.bonusAhead;
    final pick = s.radio!;
    briefing?.close(comms.director, comms.now);
    briefing = null;
    if (ahead != null && pick.category == RadioCategory.bonusEntry) {
      briefing = BonusBriefing(
        level: ahead,
        sector: level,
        invite: pick.line,
        inviteSpec: pick.spec,
        modifier: model.bonusPlan.modifier,
      );
    }
    final b = briefing;
    final needs = b != null
        // The card's line or its reading time, whichever is longer (it
        // starts at the slot, no adoption wait).
        ? b.needs(gap: comms.director.lineGap) + InterludeTiming.fade
        : s.radio!.needs + InterludeTiming.adoptWait + 2 * InterludeTiming.fade;
    // The model rounds it up to whole beats before travel starts.
    model.slotExtra = math.max(0, needs - room);
  }

  void _updateSlot(ArcadeModel model, SquadComms comms, bool voice) {
    final s = slot;
    if (s == null) return;
    final (start, _) = slotWindow(model.flow.plan);
    final elapsed = model.flow.seconds - start;
    if (elapsed < 0) return;
    final b = briefing;
    if (b != null && !b.offered) {
      // The card opens at the slot's start and its one line goes on the
      // channel (no adoption of a line already on air: the director queues
      // it behind, and the card is the slot). bonus-briefing-clarity: the
      // card opens even if the line cannot queue.
      final room =
          model.flow.plan.descentAt - model.flow.seconds + FlowPlan.maxExtra;
      b.offer(comms.director, now: comms.now, ttl: room);
      played.add(b.script().first.$1.id);
      planner.shown(b.invite.id);
      return;
    }
    if (b != null && b.offered) return;
    _updateRadio(model, comms, elapsed);
  }

  /// portrait-comms-lanes: when Pursuit starts (plan seconds), the chatter's
  /// window opens; it closes at the Descent.
  static double pursuitAt(FlowPlan p) => p.descentAt - p.pursuitSeconds;

  /// The chatter's opacity on the flow clock: in over [chatterFade] from
  /// Pursuit's start, out over the slot's last half second before the
  /// Descent (the slot beat's own fade-out).
  static double chatterOpacity(FlowPlan p, double s) {
    final a = ((s - pursuitAt(p)) / chatterFade).clamp(0.0, 1.0);
    final b = ((p.descentAt - s) / InterludeTiming.fade).clamp(0.0, 1.0);
    return math.min(a, b);
  }

  static const chatterFade = .3;

  /// portrait-comms-lanes: opens the chatter when Pursuit starts (portrait
  /// only; not on the way into a bonus level, whose card is the slot),
  /// takes the lines the rules allow and, when one short line stands
  /// alone, queues a second short one if it fits the transition's clock.
  void _updateChatter(ArcadeModel model, SquadComms comms) {
    if (chatter == null &&
        (!compact ||
            slot == null ||
            briefing != null ||
            model.flow.seconds < pursuitAt(model.flow.plan) ||
            model.flow.seconds >= model.flow.plan.descentAt)) {
      return;
    }
    if (briefing != null) return;
    final now = comms.now;
    final left = model.flow.plan.descentAt - model.flow.seconds;
    final c = chatter ??= TransitionChatter(
      // A line the Pursuit's own event started this frame counts.
      openedAt: now - (model.flow.seconds - pursuitAt(model.flow.plan)) - .1,
      lastStart: now + left - chatterMinRead,
    );
    final director = comms.director;
    c.consider(director.active, now);
    if (!c.wantsSecond || _second != null || director.queue.isNotEmpty) {
      return;
    }
    final first = c.shown.single;
    final room = left - InterludeTiming.fade;
    final start = math.max(0.0, first.speechEndsAt + director.lineGap - now);
    final crew = comms.lineup?.members ?? const <String>{};
    final picks = [
      for (final category in RadioCategory.drawn)
        for (final p in radioPool(category, level: model.nextLevel, crew: crew))
          if (p.text.length <= TransitionChatter.shortMax &&
              p.spec.exchange == null &&
              p.line.id != first.line.id &&
              !played.contains(p.line.id) &&
              commsCast[p.line.speaker] != null &&
              start + p.needs <= room)
            p,
    ];
    if (picks.isEmpty) return;
    // The other side first (a human line gets a brood answer in spirit,
    // never a linked one), then the shortest.
    picks.sort((a, b) {
      final sa = (commsCast[a.line.speaker]!.isDemon == first.isDemon) ? 1 : 0;
      final sb = (commsCast[b.line.speaker]!.isDemon == first.isDemon) ? 1 : 0;
      return sa != sb ? sa - sb : a.needs.compareTo(b.needs);
    });
    final pick = picks.first;
    final message = director.offer(
      pick.line,
      spec: pick.spec,
      ttl: math.max(.1, room - pick.needs),
    );
    _second = message ?? first; // one try per transition
    if (message == null) return;
    played.add(pick.line.id);
    planner.shown(pick.line.id);
  }

  void _updateRadio(ArcadeModel model, SquadComms comms, double elapsed) {
    final now = comms.now;
    final own = _own;
    final director = comms.director;
    final onAir = [
      for (final m in director.active)
        if (m.started && now < m.endsAt) m,
    ];
    // The squad's own transition line (the next-mission briefing) is the
    // slot: never a second voice over it.
    final current = shown;
    if (current == null || now >= current.endsAt) {
      final next =
          onAir.where((m) => m.transmission).firstOrNull ??
          onAir.where((m) => !m.isDemon).firstOrNull ??
          onAir.firstOrNull;
      if (next != null && !identical(next, current)) {
        shown = next;
        planner.shown(next.line.id);
        return;
      }
    }
    if (current != null || own != null) return;
    final pick = slot!.radio!;
    final waiting = director.queue.any((m) => m.transmission);
    final room =
        model.flow.plan.descentAt - model.flow.seconds - InterludeTiming.fade;
    if (onAir.isNotEmpty || waiting || elapsed < InterludeTiming.adoptWait) {
      return;
    }
    if (pick.needs > room) return;
    if (commsCast[pick.line.speaker] == null) return;
    // The slot's own pick goes through the director's pacing (after the
    // line on air and the grace gap), so it can never talk over the squad;
    // once it starts, the adoption above records it as shown.
    final message = director.offer(pick.line, spec: pick.spec, ttl: room);
    if (message == null) return;
    _own = message;
    played.add(pick.line.id);
  }

  void _endSlot(SquadComms comms) {
    if (_tipMuted && !showingCard) {
      _tipMuted = false;
      comms.director.hush(0);
    }
    final own = _own;
    if (own != null && !own.started) comms.director.queue.remove(own);
    // --- portrait-comms-lanes: the chatter closes with the slot; its
    // lines never move to the dock afterwards.
    final second = _second;
    if (second != null && !second.started) {
      comms.director.queue.remove(second);
    }
    final c = chatter;
    if (c != null) _chatterDone.addAll(c.hidden);
    chatter = null;
    _second = null;
    slot = null;
    _own = shown = null;
    _slotPlanned = false;
  }

  /// Ends the opening card and gives the radio back.
  void end(SquadComms comms, {required bool voice}) {
    if (_tipMuted) {
      _tipMuted = false;
      comms.director.hush(0);
    }
    plan = null;
  }

  /// Skip (tap, Space or Enter). The opening card closes and the fight
  /// starts; a sector transition goes to its Descent on the next frame (or
  /// when the pickup grace ends) and a radio line finishes on the dock. Returns false when nothing was skipped.
  bool skip(ArcadeModel model, SquadComms comms, {required bool voice}) {
    if (showingCard) {
      _skipped = true;
      end(comms, voice: voice);
      if (model.presentationMode == RunMode.transition) {
        model.transitionLeft = 0;
      }
      return true;
    }
    if (!canSkip(model) || !model.skipTransition()) return false;
    if (_tipMuted) {
      _tipMuted = false;
      comms.director.hush(0);
    }
    return true;
  }

  /// Seconds the opening card has been readable so far and its whole
  /// window (tests).
  (double, double) cardTime(ArcadeModel model) => (_elapsed(model), _window);

  /// The overlay over the arena during a cinematic phase.
  Widget build(
    BuildContext context, {
    required ArcadeModel model,
    required SquadComms comms,
    VoidCallback? onSkip,
  }) {
    final phase = model.presentationMode;
    final reduce = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    compact = !CommsLayout.of(MediaQuery.sizeOf(context)).side;
    final children = <Widget>[];
    if (phase == RunMode.transition && model.isBoss) {
      children.add(_bossAlert(model, model.transitionProgress));
    }
    if (showingCard) {
      children.add(_card(context, model, onSkip, reduce));
    }
    final flourish = _flourish(model);
    if (flourish != null) children.add(flourish);
    final talk = _chatter(model, comms);
    if (talk != null) children.add(talk);
    if (children.isEmpty) return const SizedBox.shrink();
    return Stack(
      children: [for (final c in children) Positioned.fill(child: c)],
    );
  }

  Widget _card(
    BuildContext context,
    ArcadeModel model,
    VoidCallback? onSkip,
    bool reduce,
  ) {
    final (elapsed, window) = cardTime(model);
    final opacity = interludeOpacity(elapsed, window, reduce: reduce);
    final level = model.level;
    final destination =
        'SECTOR $level · ${CampaignStory.name(level, model.cycle).toUpperCase()}';
    return LayoutBuilder(
      builder: (context, bounds) {
        final compact = bounds.maxHeight < 520;
        final current = plan!;
        return InterludeFrame(
          opacity: opacity,
          onSkip: onSkip,
          child: TipInterludeCard(
            tip: current.tip!,
            destination: destination,
            showDetail: current.showDetail,
            compact: compact,
          ),
        );
      },
    );
  }

  /// portrait-comms-lanes: the chatter in the middle of the arena, over
  /// the clouds, between the dock's room and the ship's highest climb. It
  /// follows Pursuit on the flow clock (gone by the Descent) and takes no
  /// input.
  Widget? _chatter(ArcadeModel model, SquadComms comms) {
    final c = chatter;
    if (c == null || c.shown.isEmpty || !compact) return null;
    final opacity = chatterOpacity(model.flow.plan, model.flow.seconds);
    if (opacity <= 0) return null;
    final plan = model.flow.plan;
    return IgnorePointer(
      child: LayoutBuilder(
        builder: (context, bounds) {
          final scale = math.min(
            bounds.maxWidth / ArcadeModel.width,
            bounds.maxHeight / ArcadeModel.height,
          );
          final oy = bounds.maxHeight - ArcadeModel.height * scale;
          // The ship's top at its highest climb, with a margin.
          final shipTop =
              oy + (ArcadeModel.shipY - plan.climb - shipClearance) * scale;
          final top = chatterTop;
          final height = math.max(0.0, shipTop - top);
          return Stack(
            children: [
              Positioned(
                key: const ValueKey('transition-chatter-band'),
                left: 8,
                right: 8,
                top: top,
                height: height,
                child: Center(
                  child: Opacity(
                    opacity: opacity,
                    child: TransitionChatterView(
                      chatter: c,
                      now: comms.now,
                      maxWidth: bounds.maxWidth - 16,
                      maxHeight: height,
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  /// Room left at the top of the arena for the dock (its tallest).
  static const chatterTop = CommsHudStack.maxHeight + 4;

  /// Arena units kept clear above the ship's sprite at its highest climb.
  static const shipClearance = 40.0;

  /// The medal of a carrier's fall: a short flourish beside the ship (the
  /// existing medal glyph, no panel and no text: the HUD counts the extra
  /// life, the radio says it), from the fall's first third to the climb.
  Widget? _flourish(ArcadeModel model) {
    final flow = model.flow;
    if (flow.kind != FlowKind.bossVictory &&
        flow.kind != FlowKind.campaignOutro) {
      return null;
    }
    final s = flow.seconds;
    final a = Curves.easeOutBack.transform(((s - 1.8) / .5).clamp(0.0, 1.0));
    final end = math.min(flow.plan.descentAt - .4, 9.0);
    final b = ((end - s) / .5).clamp(0.0, 1.0);
    final o = math.min(((s - 1.8) / .3).clamp(0.0, 1.0), b);
    if (o <= 0) return null;
    final shipY = ArcadeModel.shipY - flow.plan.climb * flow.env('climb');
    return IgnorePointer(
      child: LayoutBuilder(
        builder: (context, bounds) {
          final scale = math.min(
            bounds.maxWidth / ArcadeModel.width,
            bounds.maxHeight / ArcadeModel.height,
          );
          final ox = (bounds.maxWidth - ArcadeModel.width * scale) / 2;
          // The cabinet arena is bottom-aligned (mobile-top-trim).
          final oy = bounds.maxHeight - ArcadeModel.height * scale;
          final right = model.shipX < ArcadeModel.width / 2;
          final x = ox + (model.shipX + (right ? 30 : -30)) * scale;
          final y = oy + (shipY - 34) * scale;
          final medal = Medal(
            difficulty: model.difficulty,
            ordinal: (model.medals - 1).clamp(0, 4),
            size: 34,
          );
          return Stack(
            children: [
              Positioned(
                key: const ValueKey('flow-flourish'),
                left: right ? x : null,
                right: right ? null : bounds.maxWidth - x,
                top: y,
                child: Opacity(
                  opacity: o,
                  child: Transform.scale(
                    scale: .8 + .2 * a,
                    child: medal,
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  /// The carrier's arrival: one alert docked at the top (signature, target
  /// and objective), leaving the descent in the centre unobstructed.
  Widget _bossAlert(ArcadeModel model, double p) => LayoutBuilder(
    builder: (context, bounds) {
      final compact = bounds.maxHeight < 450;
      // Phones and narrow windows (the comms dock layout): the alert hugs
      // its text at the very top of the arena (mobile-top-trim).
      final tight = !CommsLayout.of(MediaQuery.sizeOf(context)).side;
      final fadeIn = Curves.easeOutCubic.transform((p / .10).clamp(0, 1));
      final fadeOut = Curves.easeInCubic.transform(((1 - p) / .10).clamp(0, 1));
      final pulse = math.sin(model.visualClock * 8.0) * 0.5 + 0.5;
      const red = Color(0xFFFF5252);
      return IgnorePointer(
        child: Opacity(
          opacity: math.min(fadeIn, fadeOut),
          child: Align(
            alignment: Alignment.topCenter,
            child: Padding(
              padding: EdgeInsets.only(
                top: tight
                    ? 2
                    : compact
                    ? 6
                    : 14,
              ),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Container(
                  key: const ValueKey('boss-alert'),
                  width: math.min(440, bounds.maxWidth - 20),
                  padding: EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: tight
                        ? 3
                        : compact
                        ? 6
                        : 10,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xEB16050A),
                    border: Border.all(
                      color: Color.lerp(
                        const Color(0xFFFF3D68),
                        const Color(0xFFFF8A80),
                        pulse,
                      )!,
                      width: 1.5,
                    ),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '⚠ BROOD DREADNOUGHT SIGNATURE',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: red,
                          fontSize: compact ? 10 : 12,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.4,
                        ),
                      ),
                      SizedBox(height: tight ? 1 : 3),
                      Text(
                        '${CampaignStory.name(5, model.cycle).toUpperCase()} ENTERS ORBIT',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: compact ? 15 : 19,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.8,
                        ),
                      ),
                      SizedBox(height: tight ? 2 : 4),
                      Text(
                        'BREAK THE SHIELD · FIRE INTO THE OPEN HATCH',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: const Color(0xFFD6E2EE),
                          fontSize: compact ? 10.5 : 12,
                          fontWeight: FontWeight.w600,
                          letterSpacing: .5,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    },
  );
}
