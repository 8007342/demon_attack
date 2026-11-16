import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

import '../game/model.dart';
import 'flight_joystick_atlas.dart';

/// flight-joystick: the stick's target tilt from the ship's motion, in the
/// pad's frame: x right, y forward (screen up), each in [-1, 1].
///
/// x is the ship's lateral velocity over its top speed (`shipVx` / 360). y is
/// the forward surge: how far the world's flight speed is above cruise, the
/// factor the flyover scrolls by (the flow's `speed` ramp on a sector climb,
/// the level-clear run-out) times [boost], the boss director's `flowBoost`
/// while the ship climbs with a carrier (up to ×2.2). A ×2.2 surge is a full
/// push. At cruise with the ship still, the target is zero and the stick
/// rests.
Offset flightJoystickTarget(ArcadeModel model, {double boost = 1}) {
  const maxVx = 360.0;
  final x = (model.shipVx / maxVx).clamp(-1.0, 1.0);
  final flow = model.flow;
  double factor;
  if (flow.active && flow.plan.beat('speed') != null) {
    factor = flow.plan.speedFactor(flow.env('speed'));
  } else {
    final p = model.transitionProgress;
    factor = switch (model.presentationMode) {
      RunMode.levelClear || RunMode.victory => 1 + 2.5 * p * p,
      _ => 1.0,
    };
  }
  final y = ((factor * boost - 1) / 1.2).clamp(0.0, 1.0);
  return Offset(x, y);
}

/// The atlas cell of a tilt vector (x right, y forward; length 1 = full
/// tilt): 0 is the rest pose; then tilt-major, direction-minor, as
/// [FlightJoystickAtlas] lays them out. [maxTilt] caps the tilt step
/// (1-based; reduced motion uses 1).
int flightJoystickCell(Offset v, {double deadZone = 0.06, int? maxTilt}) {
  final tilts = FlightJoystickAtlas.tiltDegrees.length;
  final m = math.min(1.0, v.distance);
  if (m < deadZone) return 0;
  final step = (m * tilts).round().clamp(1, maxTilt ?? tilts);
  final dirs = FlightJoystickAtlas.directions;
  final a = math.atan2(v.dy, v.dx);
  final k = ((a / (2 * math.pi) * dirs).round() % dirs + dirs) % dirs;
  return 1 + (step - 1) * dirs + k;
}

/// The hero flight stick in the control pad. It tilts toward [target] with
/// an eased follow (snappier on the way out than back to rest), and rests
/// when the target is zero. Under reduced motion it snaps (no easing) and
/// leans by the first tilt step only.
///
/// Pixel art: the cell is drawn with nearest sampling at a whole number of
/// device pixels per texel, the largest that fits the box.
class FlightJoystick extends StatefulWidget {
  const FlightJoystick({
    super.key,
    required this.target,
    this.active = false,
    this.reduceMotion,
  });

  /// x right, y forward; see [flightJoystickTarget].
  final Offset target;

  /// The pilot is touching the pad: the stick's under-glow brightens.
  final bool active;

  /// Overrides the platform's reduced-motion setting (tests, review sheets).
  final bool? reduceMotion;

  @override
  State<FlightJoystick> createState() => FlightJoystickState();
}

class FlightJoystickState extends State<FlightJoystick>
    with SingleTickerProviderStateMixin {
  ImageStream? _stream;
  ImageInfo? _info;
  late final ImageStreamListener _listener = ImageStreamListener((info, _) {
    if (!mounted) {
      info.dispose();
      return;
    }
    setState(() {
      _info?.dispose();
      _info = info;
    });
  });
  late final Ticker _ticker = createTicker(_tick);
  Duration _last = Duration.zero;
  Offset _shown = Offset.zero;

  /// The eased tilt vector on screen (tests).
  Offset get shown => _shown;

  /// The atlas cell on screen (tests).
  int get cell => flightJoystickCell(_shown, maxTilt: _reduce ? 1 : null);

  bool get _reduce =>
      widget.reduceMotion ??
      MediaQuery.maybeDisableAnimationsOf(context) ??
      false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final next = const AssetImage(FlightJoystickAtlas.asset)
        .resolve(createLocalImageConfiguration(context));
    if (next.key != _stream?.key) {
      _stream?.removeListener(_listener);
      _stream = next..addListener(_listener);
    }
    _follow();
  }

  @override
  void didUpdateWidget(FlightJoystick oldWidget) {
    super.didUpdateWidget(oldWidget);
    _follow();
  }

  void _follow() {
    if (_reduce) {
      _ticker.stop();
      _shown = widget.target;
      return;
    }
    if ((widget.target - _shown).distance > 1e-3 && !_ticker.isActive) {
      _last = Duration.zero;
      _ticker.start();
    }
  }

  void _tick(Duration now) {
    final dt = _last == Duration.zero
        ? 1 / 60
        : ((now - _last).inMicroseconds / 1e6).clamp(0.0, 0.1);
    _last = now;
    final target = widget.target;
    // Out to a lean fast (the stick answers the hand), back to rest a little
    // slower (a spring-loaded gimbal settling).
    final rate = target.distance >= _shown.distance ? 14.0 : 9.0;
    final before = cell;
    _shown = Offset.lerp(_shown, target, 1 - math.exp(-rate * dt))!;
    if ((target - _shown).distance < 1e-3) {
      _shown = target;
      _ticker.stop();
    }
    if (cell != before) setState(() {});
  }

  @override
  void dispose() {
    _ticker.dispose();
    _stream?.removeListener(_listener);
    _info?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => CustomPaint(
    key: const ValueKey('flight-joystick'),
    painter: _StickPainter(
      _info?.image,
      cell,
      widget.active,
      MediaQuery.maybeDevicePixelRatioOf(context) ?? 1.0,
    ),
    size: Size.infinite,
  );
}

class _StickPainter extends CustomPainter {
  const _StickPainter(this.image, this.cell, this.active, this.dpr);

  final ui.Image? image;
  final int cell;
  final bool active;
  final double dpr;

  @override
  void paint(Canvas canvas, Size size) {
    const cw = FlightJoystickAtlas.cellWidth;
    const ch = FlightJoystickAtlas.cellHeight;
    // whole device pixels per texel, at least one
    final k = math.max(
      1,
      math.min(size.width * dpr / cw, size.height * dpr / ch).floor(),
    );
    final w = cw * k / dpr, h = ch * k / dpr;
    // snap the top-left to the device pixel grid so texels stay square
    final left = ((size.width - w) / 2 * dpr).roundToDouble() / dpr;
    final top = ((size.height - h) / 2 * dpr).roundToDouble() / dpr;
    // the touch target's under-glow: a flat mint ellipse under the base
    final glow = Rect.fromCenter(
      center: Offset(left + w / 2, top + h * .80),
      width: w * 1.04,
      height: h * .36,
    );
    canvas.drawOval(
      glow,
      Paint()
        ..color = const Color(0xFF70F5D5).withValues(alpha: active ? .22 : .09),
    );
    final img = image;
    if (img == null) return;
    const cols = FlightJoystickAtlas.columns;
    final src = Rect.fromLTWH(
      (cell % cols) * cw.toDouble(),
      (cell ~/ cols) * ch.toDouble(),
      cw.toDouble(),
      ch.toDouble(),
    );
    canvas.drawImageRect(
      img,
      src,
      Rect.fromLTWH(left, top, w, h),
      Paint()..filterQuality = FilterQuality.none,
    );
  }

  @override
  bool shouldRepaint(_StickPainter old) =>
      old.image != image ||
      old.cell != cell ||
      old.active != active ||
      old.dpr != dpr;
}
