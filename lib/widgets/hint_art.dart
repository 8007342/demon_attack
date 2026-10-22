import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../game/model.dart';
import 'heart_parts.dart';
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
      'shield_refresh' || 'shield_weapon_combo' => Row(
        mainAxisSize: MainAxisSize.min,
        children: [power(Power.shield), plus, power(Power.powerful)],
      ),
      _ => null,
    };
  }
}

const _descriptions = <String, String>{
  'heart_quarters': 'Four different heart quarters assemble one extra life.',
  'carrier_hatch':
      'Shoot the exposed gold carrier core when its hatch is open.',
  'ordinary_dodge':
      'The monster draws back its wings; the ship sidesteps its shot.',
  'shield_refresh':
      'An enemy hit breaks the shield. During brief protection, '
      'the ghostly ship moves a short distance to a fresh shield and weapon.',
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
    'ordinary_dodge': Rect.fromLTWH(0, 284, 626, 222),
    'shield_refresh': Rect.fromLTWH(628, 284, 626, 222),
    'powerful_choice': Rect.fromLTWH(0, 568, 626, 219),
    'large_choice': Rect.fromLTWH(628, 568, 626, 219),
    'giant_rush': Rect.fromLTWH(0, 852, 626, 287),
    'shield_weapon_combo': Rect.fromLTWH(628, 852, 626, 287),
  };

  @override
  void paint(Canvas canvas, Size size) {
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
  }

  @override
  bool shouldRepaint(_HintScenePainter oldDelegate) =>
      image != oldDelegate.image || scene != oldDelegate.scene;
}
