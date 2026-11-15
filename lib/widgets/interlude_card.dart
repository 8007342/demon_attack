/// The run's opening interlude: one illustrated tip card centred in the play
/// area (openspec/changes/fluid-transitions). cinematic-flow moved the radio
/// card to the comms dock and later tips to a caption (flow_caption.dart);
/// ux-declutter removed the progress strip that lived here.
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../game/hints.dart';
import '../game/interlude.dart';
import 'hint_art.dart';

const _ink = Color(0xF2080D18);
const _mint = Color(0xFF70F5D5);
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
