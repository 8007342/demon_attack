import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../game/model.dart';
import 'heart_parts.dart';
import 'medal.dart';
import 'power_status.dart';

/// Rich instructional illustrations are separate from the combat sprite atlas.
/// Exact heart quarters and weapon choices reuse the real gameplay glyphs.
class HintArt extends StatefulWidget {
  const HintArt({super.key, required this.scene, this.height = 180});

  static const assetPath = 'assets/images/hint-scenes.png';
  final String scene;
  final double height;

  @override
  State<HintArt> createState() => _HintArtState();
}

class _HintArtState extends State<HintArt> {
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

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final next = const AssetImage(HintArt.assetPath)
        .resolve(createLocalImageConfiguration(context));
    if (next.key == _stream?.key) return;
    _stream?.removeListener(_listener);
    _stream = next..addListener(_listener);
  }

  @override
  void dispose() {
    _stream?.removeListener(_listener);
    _info?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scene = switch (widget.scene) {
      'hearts' => 'heart_quarters',
      'carrier' => 'carrier_hatch',
      'dodge' => 'ordinary_dodge',
      'weapons' => 'shield_weapon_combo',
      _ => widget.scene,
    };
    final footer = _footer(scene);
    return Semantics(
      image: true,
      label: _descriptions[scene] ?? _descriptions['shield_weapon_combo'],
      child: ExcludeSemantics(
        child: SizedBox(
          height: widget.height,
          width: double.infinity,
          child: ColoredBox(
            color: const Color(0xFF080F20),
            child: Column(
              children: [
                Expanded(
                  child: SizedBox.expand(
                    child: CustomPaint(
                      painter: _HintScenePainter(_info?.image, scene),
                    ),
                  ),
                ),
                if (footer != null)
                  SizedBox(
                    height: math.min(42, math.max(30, widget.height * .24)),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: FittedBox(fit: BoxFit.scaleDown, child: footer),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget? _footer(String scene) {
    const plus = Padding(
      padding: EdgeInsets.symmetric(horizontal: 5),
      child: Text(
        '+',
        style: TextStyle(color: Color(0xFFB8C7D8), fontSize: 18),
      ),
    );
    const arrow = Padding(
      padding: EdgeInsets.symmetric(horizontal: 10),
      child: Icon(
        Icons.arrow_forward_rounded,
        size: 20,
        color: Color(0xFF70F5D5),
      ),
    );
    Widget power(Power p) => Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        CustomPaint(size: const Size(28, 28), painter: PowerGlyphPainter({p})),
        const SizedBox(width: 4),
        Text(
          powerNames[p]!,
          style: const TextStyle(
            color: Color(0xFFE1EBF4),
            fontSize: 12,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );

    return switch (scene) {
      'heart_quarters' => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < 4; i++) ...[
            if (i > 0) plus,
            HeartParts(mask: [1, 2, 4, 8][i], size: 28),
          ],
          arrow,
          const HeartParts(mask: 15, size: 32),
          const SizedBox(width: 5),
          const Text(
            '+1',
            style: TextStyle(
              color: Color(0xFFFFD594),
              fontSize: 17,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
      'powerful_choice' => Row(
        mainAxisSize: MainAxisSize.min,
        children: [power(Power.rapid), arrow, power(Power.powerful)],
      ),
      'large_choice' => Row(
        mainAxisSize: MainAxisSize.min,
        children: [power(Power.spread), arrow, power(Power.large)],
      ),
      'carrier_field' => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          power(Power.shield),
          arrow,
          const Text(
            'CORE',
            style: TextStyle(
              color: Color(0xFFFFD594),
              fontSize: 15,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
      'shield_refresh' || 'shield_weapon_combo' => Row(
        mainAxisSize: MainAxisSize.min,
        children: [power(Power.shield), plus, power(Power.powerful)],
      ),
      'stronger_swarm' => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          power(Power.shield),
          plus,
          const Text(
            'ARMOR',
            style: TextStyle(
              color: Color(0xFFF4CA79),
              fontSize: 15,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
      'boss_reward' => const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          HeartParts(mask: 15, size: 32),
          SizedBox(width: 10),
          Text(
            '+1UP',
            style: TextStyle(
              color: Color(0xFFFFD594),
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
      'campaign_medals' => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var ordinal = 0; ordinal < 5; ordinal++)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 5),
              child: Medal(
                difficulty: Difficulty.normal,
                ordinal: ordinal,
                size: 32,
              ),
            ),
        ],
      ),
      'ground_missiles' => const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'GLOW',
            style: TextStyle(
              color: Color(0xFFFF8676),
              fontSize: 13,
              fontWeight: FontWeight.bold,
            ),
          ),
          arrow,
          Text(
            'SIDESTEP',
            style: TextStyle(
              color: Color(0xFF70F5D5),
              fontSize: 13,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
      'homing_missiles' => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          CustomPaint(
            size: const Size(28, 28),
            painter: PowerGlyphPainter(const {}, homingMissiles: 3),
          ),
          const SizedBox(width: 4),
          const Text(
            homingName,
            style: TextStyle(
              color: homingColor,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
          arrow,
          const Text(
            'x3 AUTO',
            style: TextStyle(
              color: Color(0xFFE1EBF4),
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
      'sling_shot' => const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'SLIDE',
            style: TextStyle(
              color: Color(0xFF70F5D5),
              fontSize: 13,
              fontWeight: FontWeight.bold,
            ),
          ),
          plus,
          Text(
            'FIRE',
            style: TextStyle(
              color: Color(0xFFE1EBF4),
              fontSize: 13,
              fontWeight: FontWeight.bold,
            ),
          ),
          arrow,
          Text(
            'ANGLED SHOT',
            style: TextStyle(
              color: Color(0xFFFFD594),
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
      _ => null,
    };
  }
}

const _descriptions = <String, String>{
  'heart_quarters': 'Four different heart quarters assemble one extra life.',
  'carrier_hatch':
      'Shoot the exposed gold carrier core when its hatch is open.',
  'carrier_field':
      'A broad force field protects the carrier from below. '
      'Wear down the field to expose the carrier core.',
  'ordinary_dodge':
      'The monster draws back its wings; the ship sidesteps its shot.',
  'shield_refresh':
      'An enemy hit breaks the shield. During brief protection, '
      'the ghostly ship moves a short distance to a fresh shield and weapon.',
  'sling_shot':
      'A banking ship slides sideways and slings an angled shot into an open hatch and moving giant.',
  'powerful_choice':
      'A rapid chain of thin shots is replaced by a slower heavy shot.',
  'large_choice':
      'One large projectile bursts against a nearby enemy cluster. '
      'Large replaces spread.',
  'giant_rush':
      'The giant dives along a locked straight path. '
      'The player moves sideways away from the old position.',
  'shield_weapon_combo':
      'The ship uses a shield and a powerful weapon together.',
  'stronger_swarm':
      'Later enemies have stronger shields and armor. '
      'A large armored bird is enclosed by its protective shield.',
  'boss_reward':
      'Defeat a carrier to earn one extra life, shown by a full heart.',
  'campaign_medals':
      'Five distinct campaign medals, one for each carrier victory.',
  'ground_missiles':
      'A launcher on the ground glows, then fires a large missile toward '
      'where the ship was; the ship slides aside and it misses.',
  'homing_missiles':
      'Three homing missiles leave the ship one after another and lock on '
      'to a ground launcher.',
};

class _HintScenePainter extends CustomPainter {
  const _HintScenePainter(this.image, this.scene);
  final ui.Image? image;
  final String scene;

  // The generated 1254px square contact sheet has hand-composed row heights.
  // Measured art-only bounds exclude its quiet footer bands and separator lines;
  // using quarter-height tiles would cut birds and show the adjacent scene.
  static const _tiles = <String, Rect>{
    'heart_quarters': Rect.fromLTWH(0, 0, 626, 222),
    'carrier_hatch': Rect.fromLTWH(628, 0, 626, 222),
    'carrier_field': Rect.fromLTWH(628, 0, 626, 222),
    'ordinary_dodge': Rect.fromLTWH(0, 284, 626, 222),
    'shield_refresh': Rect.fromLTWH(628, 284, 626, 222),
    'sling_shot': Rect.fromLTWH(628, 0, 626, 222),
    'powerful_choice': Rect.fromLTWH(0, 568, 626, 219),
    'large_choice': Rect.fromLTWH(628, 568, 626, 219),
    'giant_rush': Rect.fromLTWH(0, 852, 626, 287),
    'shield_weapon_combo': Rect.fromLTWH(628, 852, 626, 287),
    'stronger_swarm': Rect.fromLTWH(628, 852, 626, 170),
    'boss_reward': Rect.fromLTWH(628, 0, 626, 222),
    'campaign_medals': Rect.fromLTWH(628, 0, 626, 222),
  };

  @override
  void paint(Canvas canvas, Size size) {
    if (scene == 'ground_missiles' || scene == 'homing_missiles') {
      _groundScene(canvas, size, homing: scene == 'homing_missiles');
      return;
    }
    final atlas = image;
    if (atlas == null) return;
    final measured = _tiles[scene] ?? _tiles['shield_weapon_combo']!;
    final source = Rect.fromLTRB(
      measured.left * atlas.width / 1254,
      measured.top * atlas.height / 1254,
      measured.right * atlas.width / 1254,
      measured.bottom * atlas.height / 1254,
    );
    final fit = applyBoxFit(BoxFit.contain, source.size, size);
    final destination = Alignment.center.inscribe(
      fit.destination,
      Offset.zero & size,
    );
    canvas.drawImageRect(
      atlas,
      source,
      destination,
      Paint()
        ..filterQuality = FilterQuality.none
        ..isAntiAlias = false,
    );
    if (scene == 'carrier_field') {
      // A stepped egg-shaped lower envelope spans the whole carrier, rather
      // than marking only its hatch. It uses the combat field's cyan palette.
      final radiusX = destination.width * .48;
      final radiusY = destination.height * .72;
      final top = destination.top + destination.height * .13;
      final paint = Paint()..isAntiAlias = false;
      for (var x = 0.0; x <= radiusX; x += 3) {
        final y = (top + radiusY * math.sqrt(1 - x * x / (radiusX * radiusX)))
            .roundToDouble();
        for (final side in [-1, 1]) {
          final left = (destination.center.dx + side * x - 1).roundToDouble();
          paint.color = const Color(0x5539DFCC);
          canvas.drawRect(Rect.fromLTWH(left - 1, y - 1, 5, 5), paint);
          paint.color = const Color(0xFF70F5D5);
          canvas.drawRect(Rect.fromLTWH(left, y, 3, 2), paint);
        }
      }
    }
    if (scene == 'stronger_swarm') {
      // Crop out the player's shield from the source and place the real shield
      // glyph around the bird, so the illustration teaches enemy defenses.
      final shieldSize = destination.height * .92;
      canvas.save();
      canvas.translate(
        destination.center.dx - shieldSize / 2,
        destination.center.dy - shieldSize / 2,
      );
      const PowerGlyphPainter({Power.shield})
          .paint(canvas, Size.square(shieldSize));
      canvas.restore();
      final plate = math.max(3.0, (shieldSize / 20).floorToDouble());
      for (final side in [-1, 1]) {
        final x = (destination.center.dx + side * plate * 3 - plate)
            .roundToDouble();
        final y = (destination.center.dy + plate).roundToDouble();
        canvas.drawRect(
          Rect.fromLTWH(x, y, plate * 2, plate * 2),
          Paint()
            ..color = const Color(0xFFF4CA79)
            ..isAntiAlias = false,
        );
        canvas.drawRect(
          Rect.fromLTWH(x, y, plate * 2, 2),
          Paint()
            ..color = const Color(0xFFFFF5C9)
            ..isAntiAlias = false,
        );
      }
    }
    if (scene == 'sling_shot') {
      final paint = Paint()..isAntiAlias = false;
      final shipX = (destination.left + destination.width * .28).roundToDouble();
      final shipY = (destination.bottom - destination.height * .16).roundToDouble();
      // Lateral slide indicator & banked ship silhouette with angled thruster vector.
      paint.color = const Color(0x6670F5D5);
      canvas.drawRect(Rect.fromLTWH(shipX - 18, shipY + 2, 14, 3), paint);
      paint.color = const Color(0xFF70F5D5);
      canvas.drawRect(Rect.fromLTWH(shipX - 8, shipY, 16, 4), paint);
      canvas.drawRect(Rect.fromLTWH(shipX - 3, shipY - 5, 7, 5), paint);
      paint.color = const Color(0xFFFFD594);
      canvas.drawRect(Rect.fromLTWH(shipX + 3, shipY - 2, 6, 2), paint);
      // Angled thruster vector opposite the bank.
      paint.color = const Color(0xFFFF8676);
      canvas.drawRect(Rect.fromLTWH(shipX - 6, shipY + 4, 4, 4), paint);
      // Stepped pixel curved/angled trajectory slinging into the side hatch / target.
      final targetX = (destination.center.dx + destination.width * .12).roundToDouble();
      final targetY = (destination.top + destination.height * .46).roundToDouble();
      for (var step = 0; step <= 14; step++) {
        final t = step / 14.0;
        final curve = math.sin(t * math.pi) * destination.width * .05;
        final px = (shipX + (targetX - shipX) * t + curve).roundToDouble();
        final py = (shipY - 8 + (targetY - (shipY - 8)) * t).roundToDouble();
        paint.color = step.isEven
            ? const Color(0xFF70F5D5)
            : const Color(0xFFFFD594);
        canvas.drawRect(
          Rect.fromLTWH(px, py, step > 11 ? 4 : 3, step > 11 ? 4 : 3),
          paint,
        );
      }
      // Target hatch highlight on the boss flank.
      paint.color = const Color(0xFFFFD594);
      canvas.drawRect(Rect.fromLTWH(targetX - 5, targetY - 4, 10, 8), paint);
      paint.color = const Color(0xFFFFF5C9);
      canvas.drawRect(Rect.fromLTWH(targetX - 3, targetY - 2, 6, 4), paint);
    }
  }

  /// Ground-war lessons drawn on the logical pixel grid: horizon, ground,
  /// a launcher with its glow, the missile's fixed path, the ship.
  void _groundScene(Canvas canvas, Size size, {required bool homing}) {
    final u = math.max(2.0, (math.min(size.width / 120, size.height / 60)).floorToDouble());
    final w = (size.width / u).floor(), h = (size.height / u).floor();
    final ox = ((size.width - w * u) / 2).roundToDouble();
    final oy = ((size.height - h * u) / 2).roundToDouble();
    final paint = Paint()..isAntiAlias = false;
    void px(num x, num y, num pw, num ph, Color c) {
      paint.color = c;
      canvas.drawRect(Rect.fromLTWH(ox + x * u, oy + y * u, pw * u, ph * u), paint);
    }

    final horizon = (h * .28).floor();
    px(0, 0, w, horizon, const Color(0xFF0A1226));
    for (var y = horizon; y < h; y++) {
      final t = (y - horizon) / (h - horizon);
      px(0, y, w, 1, Color.lerp(const Color(0xFF0B1522), const Color(0xFF1B2A3C), t)!);
      if ((y - horizon) % 5 == 2) px(0, y, w, 1, const Color(0x2246617A));
    }
    for (var i = 0; i < 9; i++) {
      px((i * 37) % w, (i * 11) % (horizon - 2), 1, 1, const Color(0xFF46617A));
    }
    // Launcher on the ground, left: a dark hull with a raised, glowing tube.
    final lx = (w * .14).floor(), ly = (h * .62).floor();
    px(lx, ly, 18, 5, const Color(0xFF34364F));
    px(lx + 1, ly + 5, 4, 2, const Color(0xFF15142A));
    px(lx + 12, ly + 5, 4, 2, const Color(0xFF15142A));
    px(lx + 4, ly - 4, 6, 4, const Color(0xFF4A4C6A));
    px(lx + 9, ly - 8, 3, 6, const Color(0xFF4A4C6A));
    px(lx + 9, ly - 9, 3, 2, homing ? const Color(0xFF6B2C2C) : const Color(0xFFFFD594));
    px(lx + 2, ly + 1, 2, 1, const Color(0xFFFF355F));
    final shipX = (w * (homing ? .5 : .72)).floor(), shipY = h - 9;
    if (!homing) {
      // Warm warning brackets, the fixed path to the old position, the
      // growing warhead, and the ship already aside.
      px(lx - 1, ly + 8, 3, 1, const Color(0xFFFF8676));
      px(lx + 16, ly + 8, 3, 1, const Color(0xFFFF8676));
      final oldX = (w * .5).floor();
      for (var k = 0; k <= 10; k++) {
        final t = k / 10;
        final x = (lx + 10 + (oldX - lx - 10) * t).round();
        final y = (ly - 9 + (shipY - ly + 9) * t - 14 * math.sin(math.pi * t)).round();
        final s = 1 + (t * 3).floor();
        px(x, y, s, s, k == 10 ? const Color(0xFFFF8676) : const Color(0xFF7A7290));
      }
      px(oldX - 4, shipY + 5, 2, 1, const Color(0xFFFF8676));
      px(oldX + 4, shipY + 5, 2, 1, const Color(0xFFFF8676));
      for (var k = 1; k <= 3; k++) {
        px(shipX - 3 - k * 4, shipY + 2, 2, 1, const Color(0x6670F5D5));
      }
    } else {
      // Three missiles in sequence, the reticle locked on the launcher.
      for (final (dx, dy) in const [(0, -6), (-6, -18), (-12, -30)]) {
        final x = shipX + dx - (dy * .7).round(), y = shipY + dy;
        px(x, y, 1, 3, const Color(0xFFD8E2FF));
        px(x, y + 3, 1, 2, homingColor);
      }
      const m = Color(0xFF70F5D5);
      for (final (cx, cy) in [(lx - 2, ly - 11), (lx + 17, ly - 11), (lx - 2, ly + 7), (lx + 17, ly + 7)]) {
        px(cx, cy, 3, 1, m);
        px(cx + (cx < lx ? 0 : 2), cy + (cy < ly ? 0 : -2), 1, 3, m);
      }
      for (var k = 0; k < 12; k++) {
        final t = k / 12;
        px((shipX - 12 + (lx + 9 - shipX + 12) * t).round(),
            (shipY - 30 + (ly - shipY + 30) * t).round(), 1, 1, const Color(0x886EDCFF));
      }
    }
    // The ship.
    px(shipX - 1, shipY - 3, 2, 3, const Color(0xFF6EDCFF));
    px(shipX - 4, shipY, 8, 2, const Color(0xFF3C4C70));
    px(shipX - 1, shipY, 2, 4, const Color(0xFF6C80A8));
    px(shipX - 1, shipY + 4, 2, 1, const Color(0xFF70F5D5));
  }

  @override
  bool shouldRepaint(_HintScenePainter oldDelegate) =>
      image != oldDelegate.image || scene != oldDelegate.scene;
}
