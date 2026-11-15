/// The cinematic flow's messages without cards (openspec/changes/
/// cinematic-flow design §2.2; macron.dev's lesson "keep the playfield
/// open": one message per phase, near an edge, short and temporary).
///
/// - [FlowCaption]: one tip sentence on a single line at the bottom edge,
///   0.5 s fades, shown for its reading time ([readSeconds]).
/// - [FlowCaption.title]: the sector title at the top edge during the
///   Descent (1.5 s).
library;

import 'package:flutter/material.dart';

import '../game/interlude.dart';

/// Opacity of a caption [elapsed] seconds into its [shown] seconds: 0.5 s
/// fades in and out (reduced motion: a cut on the same beats).
double captionOpacity(double elapsed, double shown, {bool reduce = false}) {
  if (elapsed < 0 || elapsed > shown) return 0;
  if (reduce) return 1;
  const f = InterludeTiming.fade;
  final a = Curves.easeOutCubic.transform((elapsed / f).clamp(0.0, 1.0));
  final b = Curves.easeInCubic.transform(
    ((shown - elapsed) / f).clamp(0.0, 1.0),
  );
  return a < b ? a : b;
}

/// Seconds a caption of [text] stays up, fades included.
double captionSeconds(String text) =>
    readSeconds(text) + 2 * InterludeTiming.fade;

class FlowCaption extends StatelessWidget {
  const FlowCaption({super.key, required this.text, required this.opacity})
    : title = false,
      subtitle = null;

  /// The sector title at the top edge: [text] is the sector, [subtitle] its
  /// route or tour.
  const FlowCaption.title({
    super.key,
    required this.text,
    required this.opacity,
    this.subtitle,
  }) : title = true;

  final String text;
  final String? subtitle;
  final double opacity;
  final bool title;

  static const _mint = Color(0xFF70F5D5);

  @override
  Widget build(BuildContext context) {
    if (opacity <= 0) return const SizedBox.shrink();
    final line = Text(
      text,
      key: ValueKey(title ? 'flow-title' : 'flow-caption'),
      maxLines: 1,
      softWrap: false,
      overflow: TextOverflow.fade,
      textAlign: TextAlign.center,
      style: TextStyle(
        color: title ? Colors.white : const Color(0xFFE3ECF5),
        fontSize: title ? 20 : 15,
        fontWeight: title ? FontWeight.bold : FontWeight.w600,
        letterSpacing: title ? 2.4 : .3,
        shadows: const [
          Shadow(color: Color(0xCC050811), blurRadius: 6),
          Shadow(color: Color(0x99050811), offset: Offset(0, 1)),
        ],
      ),
    );
    return IgnorePointer(
      child: Semantics(
        liveRegion: true,
        label: subtitle == null ? text : '$text. $subtitle',
        child: ExcludeSemantics(
          child: Opacity(
            opacity: opacity.clamp(0.0, 1.0),
            child: Align(
              alignment: title ? Alignment.topCenter : Alignment.bottomCenter,
              child: Padding(
                padding: EdgeInsets.fromLTRB(
                  12,
                  title ? 64 : 0,
                  12,
                  title ? 0 : 14,
                ),
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      line,
                      if (title && subtitle != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          subtitle!,
                          style: const TextStyle(
                            color: _mint,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.6,
                            shadows: [
                              Shadow(color: Color(0xCC050811), blurRadius: 5),
                            ],
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
      ),
    );
  }
}
