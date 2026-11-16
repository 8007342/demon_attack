import 'package:flutter/material.dart';

import '../game/model.dart';
import 'flight_joystick.dart';
import 'flight_joystick_atlas.dart';
import 'power_status.dart';

/// Powers on the left, the hero flight stick centred under the arena (flight-joystick:
/// it tilts with the ship and invites the drag), the guidance on the right,
/// all inside the trackpad. The empty power slot is retained so collecting
/// powers never moves the label.
class PilotConsoleContent extends StatelessWidget {
  const PilotConsoleContent({
    super.key,
    required this.timers,
    this.homingMissiles = 0,
    required this.touching,
    required this.collecting,
    this.steering = 0.0,
    this.aimAngle = 0.0,
    this.tiltActive = false,
    this.joystick = Offset.zero,
    this.reduceMotion,
  });

  final Map<Power, double> timers;

  /// Homing missiles still to fire (loaded plus the one in flight).
  final int homingMissiles;
  final bool touching;
  final bool collecting;
  final double steering;
  final double aimAngle;
  final bool tiltActive;

  /// The stick's target tilt (x right, y forward); see [flightJoystickTarget].
  final Offset joystick;

  /// Overrides the platform's reduced-motion setting for the stick.
  final bool? reduceMotion;

  /// The guidance label (the stick's base carries the left / right arrows).
  static const guidance = 'DRAG TO PILOT';

  @override
  Widget build(BuildContext context) => IgnorePointer(
    child: LayoutBuilder(
      builder: (context, bounds) {
        final edge = (bounds.maxWidth * .025).clamp(6.0, 16.0);
        final gap = (bounds.maxWidth * .025).clamp(6.0, 18.0);
        const aspect =
            FlightJoystickAtlas.cellWidth / FlightJoystickAtlas.cellHeight;
        final stickW = ((bounds.maxHeight - 16) * aspect).clamp(40.0, 84.0);
        return Padding(
          padding: EdgeInsets.symmetric(horizontal: edge, vertical: 8),
          child: Row(
            children: [
              Expanded(
                flex: 1,
                child: Center(
                  key: const ValueKey('controller-power-slot'),
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: PowerStatus(
                      timers: timers,
                      homingMissiles: homingMissiles,
                      compact: true,
                    ),
                  ),
                ),
              ),
              SizedBox(width: gap),
              SizedBox(
                key: const ValueKey('controller-stick'),
                width: stickW,
                child: FlightJoystick(
                  target: joystick,
                  active: touching || tiltActive,
                  reduceMotion: reduceMotion,
                ),
              ),
              SizedBox(width: gap),
              Expanded(
                flex: 1,
                child: Center(
                  key: const ValueKey('controller-guidance'),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          guidance,
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
