/// Transition presentation for the arcade page: decides the one primary
/// message a transition shows (an interlude card, a story card or the boss
/// alert) and the slim progress strip, and runs the interlude's radio line.
/// main.dart only feeds it the run state and mounts its overlay.
/// See openspec/changes/fluid-transitions.
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../comms/comms_bank.dart';
import '../comms/comms_director.dart';
import '../comms/squad_comms.dart';
import '../game/campaign_story.dart';
import '../game/interlude.dart';
import '../game/model.dart';
import '../game/scene.dart' show gold, mint;
import '../game/ship_painter.dart';
import '../services/comms_audio.dart' show commsPlay, commsStop;
import 'interlude_card.dart';
import 'medal.dart';
import 'storyboard_banner.dart';

class TransitionPresenter {
  TransitionPresenter({this.seed});

  /// Fixed interlude seed (tests); null draws one per run.
  final int? seed;
  int _runs = 0;
  late InterludePlanner planner = InterludePlanner(seed: seed);

  /// The interlude of the current window, if one was planned.
  InterludePlan? plan;
  double _window = 0;
  bool _open = false, _skipped = false, _tipMuted = false;

  /// The radio card's line: its own pick, or the squad channel's line.
  CommsMessage? _own, shown;
  double _cardStart = 0;

  /// Bank lines this presenter started on the speech player.
  final played = <String>[];

  /// A new run: fresh seeded planner (the opening card is a tip again).
  void newRun(SquadComms comms, {required bool voice}) {
    end(comms, voice: voice);
    _open = false;
    planner = InterludePlanner(seed: seed == null ? null : seed! + _runs++);
  }

  /// Seconds left of the interlude window, or null outside one: the travel
  /// leg plus the arrival that follows it, or an arrival alone (the opening,
  /// a resumed run, a new route). A travel leg into a new route keeps its
  /// story card; the carrier's arrival keeps its alert.
  static double? windowLeft(ArcadeModel m) {
    final phase = m.presentationMode;
    if (phase == RunMode.travel && m.level != 5) {
      return m.transitionLeft +
          (m.nextLevel == 5 ? 0 : ArcadeModel.arrivalHintDuration);
    }
    if (phase == RunMode.transition && m.wave == 1 && !m.isBoss) {
      return m.transitionLeft;
    }
    return null;
  }

  double _elapsed(ArcadeModel m) => _window - (windowLeft(m) ?? _window);

  /// The interlude card is up.
  bool get showingCard =>
      plan != null &&
      !_skipped &&
      (plan!.kind == InterludeKind.tip || shown != null);

  /// A silent tip holds the radio quiet.
  bool get quiet => showingCard && plan!.kind == InterludeKind.tip;

  /// Called every frame after the comms tick.
  void update({
    required ArcadeModel model,
    required SquadComms comms,
    required bool voice,
    bool flawless = false,
  }) {
    final left = model.mode == RunMode.title ? null : windowLeft(model);
    if (left == null) {
      if (_open) end(comms, voice: voice);
      _open = false;
      return;
    }
    if (!_open) {
      _open = true;
      _skipped = false;
      _window = left;
      final travel = model.presentationMode == RunMode.travel;
      final level = travel ? model.nextLevel : model.level;
      plan = planner.plan(
        InterludeContext(
          difficulty: model.difficulty,
          level: level,
          route: model.cycle,
          window: left,
          crew: comms.lineup?.members ?? const {},
          flawless: travel && flawless,
          struggling: model.lives <= 1,
          nextIsCarrier: level == 5,
        ),
      );
      _cardStart = 0;
      if (plan?.kind == InterludeKind.tip && voice) {
        // Music only: the squad stays off the air while the tip is up.
        comms.setVoice(false);
        _tipMuted = true;
      }
    }
    if (plan?.kind == InterludeKind.radio && !_skipped) {
      _updateRadio(model, comms, voice);
    }
  }

  void _updateRadio(ArcadeModel model, SquadComms comms, bool voice) {
    final now = comms.now;
    final elapsed = _elapsed(model);
    final own = _own;
    if (own != null && now < own.endsAt) return;
    final director = comms.director;
    final onAir = [
      for (final m in director.active)
        if (m.started && now < m.endsAt) m,
    ];
    // The squad's own transition line (the next-mission briefing) is the
    // card: never a second voice over it.
    final current = shown;
    if (current == null || now >= current.endsAt) {
      final next =
          onAir.where((m) => m.transmission).firstOrNull ??
          onAir.where((m) => !m.isDemon).firstOrNull ??
          onAir.firstOrNull;
      if (next != null && !identical(next, current)) {
        if (current == null) _cardStart = elapsed;
        shown = next;
        planner.shown(next.line.id);
        return;
      }
    }
    if (current != null || own != null) return;
    final pick = plan!.radio!;
    final waiting = director.queue.any((m) => m.transmission);
    final room = _window - elapsed - InterludeTiming.fade;
    if (onAir.isNotEmpty || waiting || elapsed < InterludeTiming.adoptWait) {
      return;
    }
    if (pick.needs > room) return;
    final who = commsCast[pick.line.speaker];
    if (who == null) return;
    final message = CommsMessage(
      trigger: pick.spec,
      line: pick.line,
      character: who,
      priority: 5,
      queuedAt: now,
      readyAt: now,
      expiresAt: now + room,
      sequence: -1,
    )..startedAt = now;
    _own = shown = message;
    _cardStart = elapsed;
    if (comms.playAudio && comms.voiceOn && voice) {
      commsPlay(pick.line.id, 5, who.isDemon);
      played.add(pick.line.id);
    }
  }

  /// Ends the window's card and gives the radio back.
  void end(SquadComms comms, {required bool voice}) {
    if (_tipMuted) {
      _tipMuted = false;
      comms.setVoice(voice);
    }
    plan = null;
    _own = shown = null;
  }

  /// Skips the card (tap, Space or Enter). An arrival also starts the fight,
  /// as the opening briefing always did. Returns false when nothing was up.
  bool skip(ArcadeModel model, SquadComms comms, {required bool voice}) {
    if (!showingCard) return false;
    final own = _own;
    if (own != null && comms.playAudio) commsStop(own.line.id);
    _skipped = true;
    end(comms, voice: voice);
    if (model.presentationMode == RunMode.transition) model.transitionLeft = 0;
    return true;
  }

  /// Seconds the card has been readable so far and its whole window (tests).
  (double, double) cardTime(ArcadeModel model) =>
      (_elapsed(model) - _cardStart, _window - _cardStart);

  /// Height the strip takes at the top of the arena, 0 when hidden.
  double stripInset(ArcadeModel model) =>
      model.cinematic && _stripLabel(model) != null
      ? TransitionStrip.height + 8
      : 0;

  static String _roman(int cycle) =>
      const ['I', 'II', 'III', 'IV', 'V'][cycle.clamp(0, 4)];

  String? _stripLabel(ArcadeModel m) {
    final phase = m.presentationMode;
    return switch (phase) {
      RunMode.salvage =>
        'RECOVERY WINDOW · COLLECT CARGO · ${m.transitionLeft.ceil()}s',
      RunMode.levelClear =>
        'SECTOR ${m.level}/5 CLEAR · ROUTE ${_roman(m.cycle)}',
      RunMode.travel =>
        'JUMP → ${CampaignStory.name(m.nextLevel, m.level == 5 ? m.cycle + 1 : m.cycle).toUpperCase()} · ${(m.transitionProgress * 100).floor()}%',
      RunMode.transition when !m.isBoss =>
        m.wave > 1
            ? 'WAVE ${m.wave}/${m.wavesPerLevel} · REINFORCEMENTS'
            : '${CampaignStory.name(m.level, m.cycle).toUpperCase()} · WAVE 1/${m.wavesPerLevel}',
      _ => null,
    };
  }

  /// The overlay over the arena during a cinematic phase.
  Widget build(
    BuildContext context, {
    required ArcadeModel model,
    required SquadComms comms,
    ShipPainter? ship,
    VoidCallback? onSkip,
  }) {
    final phase = model.presentationMode;
    final p = model.transitionProgress;
    final reduce = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    if (phase == RunMode.transition && model.isBoss) {
      return _bossAlert(model, p);
    }
    final label = _stripLabel(model);
    final fadeIn = Curves.easeOutCubic.transform((p / .12).clamp(0, 1));
    final fadeOut = Curves.easeInCubic.transform(((1 - p) / .12).clamp(0, 1));
    final stripOpacity = reduce
        ? 1.0
        : switch (phase) {
            RunMode.salvage => fadeIn,
            RunMode.transition =>
              model.wave > 1 ? math.min(fadeIn, fadeOut) : fadeOut,
            _ => 1.0,
          };
    Widget? primary;
    if (showingCard) {
      primary = _card(context, model, comms, onSkip, reduce);
    } else if (phase == RunMode.levelClear ||
        phase == RunMode.victory ||
        (phase == RunMode.travel &&
            (model.level == 5 || plan == null) &&
            !_skipped)) {
      primary = _storyCard(model, ship);
    }
    return LayoutBuilder(
      builder: (context, bounds) {
        final inset = label == null ? 0.0 : TransitionStrip.height + 8;
        return Stack(
          children: [
            if (primary != null) Positioned.fill(top: inset, child: primary),
            if (label != null)
              Positioned(
                top: 6,
                left: 0,
                right: 0,
                child: TransitionStrip(
                  label: label,
                  sector: model.level,
                  progress: p,
                  wave: phase == RunMode.transition ? model.wave : null,
                  waves: phase == RunMode.transition
                      ? model.wavesPerLevel
                      : null,
                  opacity: stripOpacity,
                  accent: phase == RunMode.levelClear ? gold : mint,
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _card(
    BuildContext context,
    ArcadeModel model,
    SquadComms comms,
    VoidCallback? onSkip,
    bool reduce,
  ) {
    final (elapsed, window) = cardTime(model);
    final opacity = interludeOpacity(elapsed, window, reduce: reduce);
    final travel = model.presentationMode == RunMode.travel;
    final level = travel ? model.nextLevel : model.level;
    final destination =
        'SECTOR $level · ${CampaignStory.name(level, model.cycle).toUpperCase()}';
    return LayoutBuilder(
      builder: (context, bounds) {
        final compact = bounds.maxHeight < 520;
        final current = plan!;
        if (current.kind == InterludeKind.tip) {
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
        }
        final message = shown!;
        return InterludeFrame(
          opacity: opacity,
          onSkip: onSkip,
          accent: Color(message.character.accent),
          child: RadioInterludeCard(
            message: message,
            now: comms.now,
            destination: destination,
            compact: compact,
          ),
        );
      },
    );
  }

  /// Level clear, carrier victory and the jump into a new route: the story
  /// beat with its storyboard (and the medal on a carrier victory).
  Widget _storyCard(ArcadeModel model, ShipPainter? ship) {
    final phase = model.presentationMode;
    final p = model.transitionProgress;
    final fadeIn = Curves.easeOutCubic.transform((p / .12).clamp(0, 1));
    final fadeOut = Curves.easeInCubic.transform(((1 - p) / .12).clamp(0, 1));
    final bossVictory = phase == RunMode.victory;
    final recognition = bossVictory && p >= .32;
    final clear = phase == RunMode.levelClear;
    final travel = phase == RunMode.travel;
    final color = clear || bossVictory ? gold : mint;
    final heading = bossVictory
        ? recognition
              ? 'THE FLEET RECOGNIZES YOUR SERVICE'
              : 'THE CARRIER IS FALLING'
        : clear
        ? 'SECTOR SECURED'
        : 'JUMP DRIVE ACTIVE';
    final destination = travel
        ? CampaignStory.name(
            model.nextLevel,
            model.level == 5 ? model.cycle + 1 : model.cycle,
          )
        : CampaignStory.name(model.level, model.cycle);
    // The clear card carries the next leg's briefing: the travel leg that
    // follows belongs to the interlude.
    final story = bossVictory
        ? model.medals == 5
              ? 'Five carriers fallen. Brood command is broken. The frontier is free.'
              : 'A medal for your courage. A life for the journey. Keep flying, defender.'
        : CampaignStory.travel(model.level, model.cycle);
    return IgnorePointer(
      child: LayoutBuilder(
        builder: (context, bounds) {
          final compact = bounds.maxHeight < 500;
          return Align(
            alignment: const Alignment(0, 0.08),
            child: Opacity(
              key: const ValueKey('story-card'),
              opacity: math.min(fadeIn, fadeOut),
              child: Transform.translate(
                offset: Offset(0, (1 - fadeIn) * 20),
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: SizedBox(
                    width: math.min(460, bounds.maxWidth),
                    child: Container(
                      margin: const EdgeInsets.symmetric(horizontal: 14),
                      padding: EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: compact ? 10 : 18,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xD9080D18),
                        border: Border.symmetric(
                          horizontal: BorderSide(
                            color: color.withValues(alpha: .4),
                          ),
                        ),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            heading,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: color,
                              fontSize: compact ? 16 : 19,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1.2,
                            ),
                          ),
                          SizedBox(height: compact ? 6 : 12),
                          Text(
                            destination.toUpperCase(),
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: compact ? 26 : 34,
                              height: 1.15,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1.5,
                            ),
                          ),
                          SizedBox(height: compact ? 6 : 10),
                          StoryboardBanner(
                            level: model.level,
                            cycle: model.cycle,
                            phase: phase,
                            progress: p,
                            steering: model.steering,
                            compact: compact,
                            ship: ship,
                            pilot: model,
                          ),
                          if (recognition) ...[
                            const SizedBox(height: 12),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Transform.scale(
                                  scale:
                                      .8 +
                                      .2 *
                                          Curves.easeOutBack.transform(
                                            ((p - .32) / .2).clamp(0, 1),
                                          ),
                                  child: Medal(
                                    difficulty: model.difficulty,
                                    ordinal: (model.medals - 1).clamp(0, 4),
                                    size: compact ? 40 : 64,
                                  ),
                                ),
                                const SizedBox(width: 20),
                                const Text(
                                  '♥ +1UP',
                                  style: TextStyle(
                                    color: Color(0xFFFF8C89),
                                    fontSize: 24,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ],
                          if (!(bossVictory && !recognition)) ...[
                            SizedBox(height: compact ? 8 : 16),
                            Text(
                              story,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: compact ? 16 : 19,
                                height: 1.45,
                                color: const Color(0xFFCCD9E6),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
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
                      const SizedBox(height: 6),
                      LinearProgressIndicator(
                        value: p,
                        minHeight: 3,
                        color: red,
                        backgroundColor: const Color(0xFF24374B),
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
