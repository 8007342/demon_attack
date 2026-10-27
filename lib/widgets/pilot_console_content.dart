import 'package:flutter/material.dart';

import '../game/model.dart';
import 'power_status.dart';

/// Two bounded slots keep powers beside the guidance and inside the trackpad.
/// The empty power slot is retained so collecting powers never moves the label.
class PilotConsoleContent extends StatelessWidget {
  const PilotConsoleContent({
    super.key,
    required this.timers,
    required this.touching,
    required this.collecting,
    this.steering = 0.0,
    this.aimAngle = 0.0,
    this.tiltActive = false,
  });

  final Map<Power, double> timers;
  final bool touching;
  final bool collecting;
  final double steering;
  final double aimAngle;
  final bool tiltActive;

  @override
  Widget build(BuildContext context) => IgnorePointer(
    child: LayoutBuilder(
      builder: (context, bounds) {
        final edge = (bounds.maxWidth * .025).clamp(6.0, 16.0);
        final gap = (bounds.maxWidth * .025).clamp(6.0, 18.0);
        return Padding(
          padding: EdgeInsets.symmetric(horizontal: edge, vertical: 8),
          child: Row(
            children: [
              Expanded(
                flex: 46,
                child: Center(
                  key: const ValueKey('controller-power-slot'),
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: PowerStatus(timers: timers, compact: true),
                  ),
                ),
              ),
              SizedBox(width: gap),
              Expanded(
                flex: 54,
                child: Center(
                  key: const ValueKey('controller-guidance'),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          '◀     SLIDE TO PILOT     ▶',
                          style: TextStyle(
                            color: touching || tiltActive
                                ? const Color(0xFF70F5D5)
                                : const Color(0xFF99B4C7),
                            fontSize: 10,
                            letterSpacing: .6,
                            height: 1.4,
                          ),
                        ),
                      ),
                      const SizedBox(height: 9),
                      Text(
                        collecting
                            ? 'COLLECT POWERUPS\nWEAPONS SAFE'
                            : 'AUTO FIRE ENGAGED',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Color(0xFF536F82),
                          fontSize: 7,
                          letterSpacing: .6,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    ),
  );
}
