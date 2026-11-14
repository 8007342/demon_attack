/// The transition presentation: one primary interlude card centred in the
/// play area (a silent illustrated tip or a full-size radio transmission),
/// and the slim progress strip at the top of the arena.
/// See openspec/changes/fluid-transitions.
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../comms/comms_director.dart';
import '../comms/comms_portraits.dart';
import '../comms/comms_types.dart';
import '../comms/comms_view.dart';
import '../game/hints.dart';
import '../game/interlude.dart';
import 'hint_art.dart';

const _ink = Color(0xF2080D18);
const _mint = Color(0xFF70F5D5);
const _gold = Color(0xFFFFD594);
const _muted = Color(0xFF8AA3BA);
const _body = Color(0xFFCCD9E6);

/// Opacity of a card [elapsed] seconds into a [window]: one-beat fades in and
/// out, never a hard cut.
double interludeOpacity(double elapsed, double window, {bool reduce = false}) {
  if (reduce) return elapsed < 0 || elapsed > window ? 0 : 1;
  const f = InterludeTiming.fade;
  final fadeIn = Curves.easeOutCubic.transform((elapsed / f).clamp(0.0, 1.0));
  final fadeOut = Curves.easeInCubic.transform(
    ((window - elapsed) / f).clamp(0.0, 1.0),
  );
  return math.min(fadeIn, fadeOut);
}

/// Width of the card: desktop-sized inside the cabinet, full width (with a
/// 12 px gutter) on phones.
double interludeWidth(double available) =>
    math.max(0, math.min(460, available - 24));

/// Centres [child] in the play area, fades it and makes it skippable.
class InterludeFrame extends StatelessWidget {
  const InterludeFrame({
    super.key,
    required this.opacity,
    required this.child,
    this.onSkip,
    this.accent = _mint,
  });

  final double opacity;
  final Widget child;
  final VoidCallback? onSkip;
  final Color accent;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, bounds) {
      final width = interludeWidth(bounds.maxWidth);
      return Center(
        child: IgnorePointer(
          ignoring: opacity < .05,
          child: Opacity(
            opacity: opacity.clamp(0.0, 1.0),
            child: Transform.translate(
              offset: Offset(0, (1 - opacity) * 10),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: math.max(0, bounds.maxHeight - 16),
                ),
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: GestureDetector(
                    key: const ValueKey('interlude-card'),
                    behavior: HitTestBehavior.opaque,
                    onTap: onSkip,
                    child: Container(
                      width: width,
                      padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
                      decoration: BoxDecoration(
                        color: _ink,
                        border: Border.all(color: accent.withValues(alpha: .6)),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          child,
                          if (onSkip != null)
                            Align(
                              alignment: Alignment.centerRight,
                              child: Padding(
                                padding: const EdgeInsets.only(top: 6),
                                child: Semantics(
                                  button: true,
                                  label: 'Skip',
                                  child: const Text(
                                    'TAP TO SKIP ▸',
                                    key: ValueKey('interlude-skip'),
                                    style: TextStyle(
                                      color: _muted,
                                      fontSize: 9,
                                      letterSpacing: 1.2,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
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

Widget _header(String left, String right, Color color) => Row(
  children: [
    Expanded(
      child: Text(
        left,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: color,
          fontSize: 11,
          letterSpacing: 1.4,
          fontWeight: FontWeight.bold,
        ),
      ),
    ),
    const SizedBox(width: 8),
    Flexible(
      child: Text(
        right,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        textAlign: TextAlign.right,
        style: const TextStyle(
          color: _muted,
          fontSize: 9,
          letterSpacing: 1,
          fontWeight: FontWeight.bold,
        ),
      ),
    ),
  ],
);

/// Silent tip: one actionable sentence over a staged still of the game. No
/// voice plays while it is up; the score carries the moment.
class TipInterludeCard extends StatelessWidget {
  const TipInterludeCard({
    super.key,
    required this.tip,
    required this.destination,
    this.showDetail = true,
    this.compact = false,
  });

  final TacticalHint tip;

  /// Where the player is heading, e.g. `SECTOR 2 · RINGFALL`.
  final String destination;
  final bool showDetail, compact;

  @override
  Widget build(BuildContext context) => Semantics(
    container: true,
    label:
        'Tactical briefing. ${tip.title}${showDetail ? ' ${tip.detail}' : ''}',
    child: ExcludeSemantics(
      child: Column(
        key: ValueKey('interlude-tip-${tip.id}'),
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _header('TACTICAL BRIEFING', destination, _mint),
          const SizedBox(height: 10),
          HintArt(scene: tip.scene, height: compact ? 96 : 150),
          const SizedBox(height: 10),
          Text(
            tip.title,
            key: ValueKey('hint-${tip.id}'),
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white,
              fontSize: compact ? 18 : 21,
              fontWeight: FontWeight.bold,
              height: 1.15,
            ),
          ),
          if (showDetail) ...[
            const SizedBox(height: 6),
            Text(
              tip.detail,
              textAlign: TextAlign.center,
              style: const TextStyle(color: _body, fontSize: 13, height: 1.3),
            ),
          ],
        ],
      ),
    ),
  );
}

/// Full-size radio transmission: portrait, speaker and the line as it plays.
class RadioInterludeCard extends StatelessWidget {
  const RadioInterludeCard({
    super.key,
    required this.message,
    required this.now,
    required this.destination,
    this.compact = false,
  });

  final CommsMessage message;
  final double now;
  final String destination;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final m = message;
    final c = m.character;
    final accent = Color(c.accent);
    final reduce = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    final mission = m.trigger.name.startsWith('transmissionMission');
    final heading = c.isDemon
        ? '◆ BROOD SIGNAL'
        : mission
        ? '◉ FLEET COMMAND'
        : '◌ SQUAD CHANNEL';
    final tag = c.isDemon
        ? '${c.rank} ${c.name}'
        : '${c.rank} ${c.name} · ${c.callsign}';
    return LayoutBuilder(
      builder: (context, box) {
        // Whole-number scale of the portrait cell that fits the card.
        final room = math.min(box.maxWidth, compact ? 128.0 : 256.0);
        final scale = math.max(1, (room / commsPortraitCell).floor());
        final side = (commsPortraitCell * scale).toDouble();
        return Column(
          key: ValueKey('comms-transmission-${m.line.id}'),
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _header(heading, destination, c.isDemon ? accent : _gold),
            const SizedBox(height: 10),
            Center(
              child: SizedBox(
                width: side,
                height: side,
                child: CustomPaint(painter: _RadioPortrait(m, now, reduce)),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              tag,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: accent,
                fontSize: 11,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.2,
              ),
            ),
            const SizedBox(height: 6),
            CommsSubtitle(
              message: m,
              now: now,
              fontSize: compact ? 16 : 18,
              maxLines: 4,
              glyphHeight: 12,
            ),
          ],
        );
      },
    );
  }
}

class _RadioPortrait extends CustomPainter {
  _RadioPortrait(this.m, this.now, this.reduce);
  final CommsMessage m;
  final double now;
  final bool reduce;

  @override
  void paint(Canvas canvas, Size size) {
    final r = Offset.zero & size;
    final who = m.character;
    canvas.save();
    canvas.clipRect(r);
    paintBackdrop(canvas, r, who, now, reduceMotion: reduce);
    final scale = size.width / commsPortraitCell;
    final talking = m.speaking(now);
    final frame = talking ? m.frame(now) : restFrame(now, who.id.length);
    final (from, _, amount) = talking
        ? m.mouthBlend(now)
        : (CommsFrame.idle, CommsFrame.idle, 1.0);
    paintPortrait(
      canvas,
      r.translate(0, idleBob(now, who.id.length, reduceMotion: reduce) * scale),
      who.id,
      frame,
      accent: Color(who.accent),
      from: reduce ? null : from,
      amount: amount,
    );
    final age = m.age(now);
    if (age < .35 && !reduce) {
      paintStatic(canvas, r, now, (1 - age / .35) * .8, who.id.length);
    }
    paintScanlines(canvas, r, pitch: math.max(2, scale).toDouble() + 1);
    canvas.restore();
    canvas.drawRect(
      r.deflate(.5),
      Paint()
        ..style = PaintingStyle.stroke
        ..color = talking ? Color(who.accent) : const Color(0xFF26394C),
    );
  }

  @override
  bool shouldRepaint(_RadioPortrait old) => true;
}

/// The slim progress element: sector pips, one line of where the run is, and
/// a hairline of the phase's progress. It replaces the per-card progress bars
/// and the wave-change banner.
class TransitionStrip extends StatelessWidget {
  const TransitionStrip({
    super.key,
    required this.label,
    required this.sector,
    required this.progress,
    this.wave,
    this.waves,
    this.opacity = 1,
    this.accent = _mint,
  });

  final String label;

  /// Current sector 1-5 (pips).
  final int sector;
  final double progress, opacity;
  final int? wave, waves;
  final Color accent;

  static const height = 26.0;

  @override
  Widget build(BuildContext context) => IgnorePointer(
    child: Opacity(
      opacity: opacity.clamp(0.0, 1.0),
      child: Center(
        child: Container(
          key: const ValueKey('transition-strip'),
          height: height,
          constraints: const BoxConstraints(maxWidth: 460),
          margin: const EdgeInsets.symmetric(horizontal: 12),
          padding: const EdgeInsets.symmetric(horizontal: 10),
          decoration: BoxDecoration(
            color: const Color(0xCC080D18),
            border: Border(
              bottom: BorderSide(color: accent.withValues(alpha: .5)),
            ),
          ),
          child: Stack(
            children: [
              Row(
                children: [
                  for (var i = 1; i <= 5; i++)
                    Container(
                      width: 6,
                      height: 6,
                      margin: const EdgeInsets.only(right: 3),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: i < sector
                            ? _mint
                            : i == sector
                            ? _gold
                            : const Color(0xFF34485B),
                      ),
                    ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        letterSpacing: 1.1,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  if (wave != null && waves != null) ...[
                    const SizedBox(width: 6),
                    for (var i = 1; i <= waves!; i++)
                      Container(
                        width: 8,
                        height: 3,
                        margin: const EdgeInsets.only(left: 2),
                        color: i < wave!
                            ? _mint
                            : i == wave!
                            ? _gold
                            : const Color(0xFF34485B),
                      ),
                  ],
                ],
              ),
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: FractionallySizedBox(
                  alignment: Alignment.centerLeft,
                  widthFactor: progress.clamp(0.0, 1.0),
                  child: Container(height: 2, color: accent),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
