// --- reduced-effects (openspec/changes/reduced-effects): the menu rows of
// the Reduced effects setting, and the scope that hands it to every widget's
// reduced-motion path.
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../game/reduced_effects.dart';

/// Above every route (the MaterialApp's builder): the player's Reduced
/// effects setting resolves `MediaQuery.disableAnimations`, so each widget
/// that already honours the system's reduced motion (the comms page-jumps,
/// the badges, the transitions, the ending) honours the setting too. Auto
/// passes the system's value through unchanged.
class ReducedEffectsScope extends StatefulWidget {
  const ReducedEffectsScope({super.key, required this.child});
  final Widget child;

  @override
  State<ReducedEffectsScope> createState() => _ReducedEffectsScopeState();
}

class _ReducedEffectsScopeState extends State<ReducedEffectsScope> {
  /// A page may restore the remembered choice while it builds (below this
  /// scope): the rebuild then waits for the frame's end.
  void _changed() {
    if (!mounted) return;
    final phase = SchedulerBinding.instance.schedulerPhase;
    if (phase == SchedulerPhase.persistentCallbacks) {
      SchedulerBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() {});
      });
    } else {
      setState(() {});
    }
  }

  @override
  void initState() {
    super.initState();
    ReducedEffects.listeners.add(_changed);
  }

  @override
  void dispose() {
    ReducedEffects.listeners.remove(_changed);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.maybeOf(context);
    if (media == null) return widget.child;
    final calm = ReducedEffects.calm(media.disableAnimations);
    if (calm == media.disableAnimations) return widget.child;
    return MediaQuery(
      data: media.copyWith(disableAnimations: calm),
      child: widget.child,
    );
  }
}

/// The pause menu's row: `REDUCED EFFECTS: AUTO (LOW-POWER)`; a tap cycles
/// Auto -> On -> Off. [compact] is the title's 38 px icon toggle beside
/// Music and Speech.
class ReducedEffectsToggle extends StatelessWidget {
  const ReducedEffectsToggle({
    super.key,
    required this.system,
    required this.lowPower,
    required this.onChanged,
    this.compact = false,
  });

  /// The system's reduced motion (what Auto follows).
  final bool system;

  /// The frame budget adapted down to LITE by itself.
  final bool lowPower;
  final ValueChanged<ReducedEffectsMode> onChanged;
  final bool compact;

  static const _on = Color(0xFF7FE0C2), _text = Color(0xFF95A9BB);

  @override
  Widget build(BuildContext context) {
    final mode = ReducedEffects.mode;
    final next = mode.next;
    final spoken = ReducedEffects.spoken(system: system, lowPower: lowPower);
    final label = ReducedEffects.menuLabel(system: system, lowPower: lowPower);
    void tap() => onChanged(next);
    if (!compact) {
      return Semantics(
        button: true,
        label: spoken,
        hint: 'Switches to ${next.label.toLowerCase()}',
        excludeSemantics: true,
        child: TextButton(onPressed: tap, child: Text(label)),
      );
    }
    final calm = ReducedEffects.calm(system);
    return Semantics(
      button: true,
      label: spoken,
      hint: 'Switches to ${next.label.toLowerCase()}',
      excludeSemantics: true,
      child: Tooltip(
        message: '$label (tap for ${next.label})',
        child: InkResponse(
          onTap: tap,
          radius: 22,
          child: SizedBox(
            width: 38,
            height: 44,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  calm ? Icons.flash_off : Icons.flash_on,
                  size: 18,
                  color: calm ? _on : _text,
                ),
                const SizedBox(height: 3),
                Text(
                  mode.label,
                  style: TextStyle(
                    fontSize: 8,
                    height: 1,
                    letterSpacing: .5,
                    fontWeight: FontWeight.bold,
                    color: mode == ReducedEffectsMode.on ? _on : _text,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
