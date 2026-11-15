/// Transition presentation for the arcade page (openspec/changes/
/// cinematic-flow §2.2, built on fluid-transitions and ux-declutter).
///
/// - The run's opening arrival keeps its illustrated tip card (it teaches).
/// - A sector transition shows no card: it schedules one message *slot* on
///   the flow clock, a radio line on the comms dock or a caption line at the
///   bottom edge, alternating (seeded), never both; a sector title at the
///   top edge in the Descent; the medal and +1UP as a flourish beside the
///   ship. Nothing here is a bar or a strip.
/// - Skip (tap, Space, Enter) closes the opening card, or sends a sector
///   transition to its Descent (the radio line finishes on the dock).
/// main.dart only feeds it the run state and mounts its overlay.
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../comms/comms_bank.dart';
import '../comms/comms_director.dart';
import '../comms/squad_comms.dart';
import '../game/campaign_story.dart';
import '../game/interlude.dart';
import '../game/model.dart';
import 'flow_caption.dart';
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
  bool _slotPlanned = false, _captionSkipped = false;

  /// The radio slot's line: its own pick, or the squad channel's line.
  CommsMessage? _own, shown;

  /// Bank lines this presenter started on the speech player.
  final played = <String>[];

  /// A new run: fresh seeded planner (the opening card is a tip again).
  void newRun(SquadComms comms, {required bool voice}) {
    end(comms, voice: voice);
    _endSlot(comms);
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

  /// The caption is on screen now.
  bool captionOn(ArcadeModel m) => captionOpacityOf(m) > 0;

  /// A silent tip (card or caption) holds the radio quiet.
  bool quiet(ArcadeModel m) =>
      showingCard || (slot?.kind == InterludeKind.tip && captionOn(m));

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
    } else if (_slotPlanned) {
      _endSlot(comms);
    }
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
    _captionSkipped = false;
    final (_, room) = slotWindow(model.flow.plan);
    final victory = model.flow.kind == FlowKind.bossVictory;
    final level = model.nextLevel;
    slot = planner.plan(
      InterludeContext(
        difficulty: model.difficulty,
        level: level,
        route: victory ? model.cycle + 1 : model.cycle,
        window: room + FlowPlan.maxExtra,
        crew: comms.lineup?.members ?? const {},
        flawless: flawless,
        struggling: model.lives <= 1,
        nextIsCarrier: level == 5,
      ),
    );
    final s = slot;
    if (s == null) return;
    final needs = s.kind == InterludeKind.tip
        ? captionSeconds(captionText(s))
        : s.radio!.needs + InterludeTiming.adoptWait + 2 * InterludeTiming.fade;
    // The model rounds it up to whole beats before travel starts.
    model.slotExtra = math.max(0, needs - room);
  }

  /// A caption is the tip's one sentence (no illustration, no detail).
  static String captionText(InterludePlan p) => p.tip!.title;

  void _updateSlot(ArcadeModel model, SquadComms comms, bool voice) {
    final s = slot;
    if (s == null) return;
    final (start, _) = slotWindow(model.flow.plan);
    final elapsed = model.flow.seconds - start;
    if (elapsed < 0) return;
    if (s.kind == InterludeKind.tip) {
      final on = captionOn(model);
      if (on && !_tipMuted && voice) {
        comms.director.hush(captionSeconds(captionText(s)) - elapsed);
        _tipMuted = true;
      } else if (!on && _tipMuted && !showingCard) {
        _tipMuted = false;
        comms.director.hush(0);
      }
      return;
    }
    _updateRadio(model, comms, elapsed);
  }

  /// The caption's opacity now (0 when none).
  double captionOpacityOf(ArcadeModel m, {bool reduce = false}) {
    final s = slot;
    if (s == null || s.kind != InterludeKind.tip || _captionSkipped) return 0;
    if (!slotted(m)) return 0;
    final (start, _) = slotWindow(m.flow.plan);
    return captionOpacity(
      m.flow.seconds - start,
      captionSeconds(captionText(s)),
      reduce: reduce,
    );
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
    slot = null;
    _own = shown = null;
    _slotPlanned = false;
    _captionSkipped = false;
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
  /// when the pickup grace ends), the caption closes and a radio line
  /// finishes on the dock. Returns false when nothing was skipped.
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
    _captionSkipped = true;
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
    final children = <Widget>[];
    if (phase == RunMode.transition && model.isBoss) {
      children.add(_bossAlert(model, model.transitionProgress));
    }
    if (showingCard) {
      children.add(_card(context, model, onSkip, reduce));
    }
    final caption = captionOpacityOf(model, reduce: reduce);
    if (caption > 0) {
      children.add(FlowCaption(text: captionText(slot!), opacity: caption));
    }
    final title = model.flow.env('title');
    if (title > 0 && phase == RunMode.transition) {
      final tour = model.wave == 1 && model.level == 1 && model.cycle > 0;
      children.add(
        FlowCaption.title(
          text:
              'SECTOR ${model.level} · ${CampaignStory.name(model.level, model.cycle).toUpperCase()}',
          subtitle: tour ? 'TOUR ${model.cycle + 1}' : null,
          opacity: reduce ? (title > .5 ? 1 : 0) : title,
        ),
      );
    }
    final flourish = _flourish(model);
    if (flourish != null) children.add(flourish);
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

  /// The medal and +1UP of a carrier's fall: a short flourish beside the
  /// ship (the existing glyphs, no panel), from the fall's first third to
  /// the climb into the cloud.
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
          final oy = (bounds.maxHeight - ArcadeModel.height * scale) / 2;
          final right = model.shipX < ArcadeModel.width / 2;
          final x = ox + (model.shipX + (right ? 30 : -30)) * scale;
          final y = oy + (shipY - 34) * scale;
          final medal = Medal(
            difficulty: model.difficulty,
            ordinal: (model.medals - 1).clamp(0, 4),
            size: 34,
          );
          const up = Text(
            '♥ +1UP',
            style: TextStyle(
              color: Color(0xFFFF8C89),
              fontSize: 14,
              fontWeight: FontWeight.bold,
              shadows: [Shadow(color: Color(0xCC050811), blurRadius: 4)],
            ),
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
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: right
                          ? [medal, const SizedBox(width: 4), up]
                          : [up, const SizedBox(width: 4), medal],
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

  /// The carrier's arrival: one alert docked at the top (signature, target
  /// and objective), leaving the descent in the centre unobstructed.
  Widget _bossAlert(ArcadeModel model, double p) => LayoutBuilder(
    builder: (context, bounds) {
      final compact = bounds.maxHeight < 450;
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
              padding: EdgeInsets.only(top: compact ? 6 : 14),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Container(
                  key: const ValueKey('boss-alert'),
                  width: math.min(440, bounds.maxWidth - 20),
                  padding: EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: compact ? 6 : 10,
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
                      const SizedBox(height: 3),
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
                      const SizedBox(height: 4),
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
