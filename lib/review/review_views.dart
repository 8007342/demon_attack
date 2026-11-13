/// Visual viewers of the review studio: the live sector flyover and the
/// frame-by-frame atlas player. Both draw with the game's own renderers
/// (DemonScene's SectorBackground, the generated atlas contracts).
library;

import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flame/game.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:flutter/material.dart';

import '../game/model.dart';
import '../game/scene.dart';
import 'notes_panel.dart';
import 'review_catalog.dart';

/// DemonScene reduced to its background: the sector flyover (strips, ground
/// plane, landmarks, critters, vegetation, atmosphere) flying at [speed].
class BackgroundScene extends DemonScene {
  BackgroundScene(int sector) : super(ArcadeModel(), () {}) {
    this.sector = sector;
  }

  int get sector => _sector;
  set sector(int value) {
    _sector = value.clamp(0, 4);
    model.level = _sector + 1;
  }

  int _sector = 0;
  int get route => model.cycle;
  set route(int value) => model.cycle = value.clamp(0, 4);
  double speed = 1;

  /// 0..1 toward the next sector's world (the travel crossfade).
  double blend = 0;

  /// Seconds of flight shown, at [speed].
  double time = 0;

  /// Flies the background only: no simulation step (DemonScene.update would
  /// run the model), like the gallery's staged scenes.
  @override
  // ignore: must_call_super
  void update(double dt) {
    final step = dt * speed;
    time += step;
    ambient += step;
    environment = math.min(4.0, _sector + blend);
    if (step > 0) sectors.advance(step, model, environment);
  }

  // render: DemonScene's own; with the model on the title screen its arena
  // is the sector background alone.
}

class BackgroundView extends StatefulWidget {
  const BackgroundView({super.key, required this.sector, required this.link});
  final int sector;
  final PlayheadLink link;
  @override
  State<BackgroundView> createState() => _BackgroundViewState();
}

class _BackgroundViewState extends State<BackgroundView> {
  late final scene = BackgroundScene(widget.sector);
  static const speeds = [0.0, .25, .5, 1.0, 2.0, 4.0];

  @override
  void initState() {
    super.initState();
    _bind();
  }

  void _bind() {
    widget.link
      ..position = (() => scene.time)
      ..section = (() =>
          'run ${scene.route + 1} · ${scene.speed}x'
          '${scene.blend > 0 ? ' · blend ${(scene.blend * 100).round()}%' : ''}')
      ..seek = null;
  }

  @override
  void didUpdateWidget(BackgroundView old) {
    super.didUpdateWidget(old);
    scene.sector = widget.sector;
    _bind();
  }

  @override
  Widget build(BuildContext context) => Column(
    children: [
      Expanded(
        child: ColoredBox(
          color: Colors.black,
          child: GameWidget(game: scene),
        ),
      ),
      Padding(
        padding: const EdgeInsets.all(8),
        child: Wrap(
          spacing: 6,
          runSpacing: 6,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            const Text('RUN', style: TextStyle(color: studioDim, fontSize: 11)),
            for (var r = 0; r < 5; r++)
              ChoiceChip(
                label: Text('${r + 1}'),
                selected: scene.route == r,
                visualDensity: VisualDensity.compact,
                onSelected: (_) => setState(() => scene.route = r),
              ),
            const SizedBox(width: 12),
            const Text(
              'SPEED',
              style: TextStyle(color: studioDim, fontSize: 11),
            ),
            for (final s in speeds)
              ChoiceChip(
                key: ValueKey('bg-speed-$s'),
                label: Text(s == 0 ? 'pause' : '${s}x'),
                selected: scene.speed == s,
                visualDensity: VisualDensity.compact,
                onSelected: (_) => setState(() => scene.speed = s),
              ),
            if (widget.sector < 4) ...[
              const SizedBox(width: 12),
              const Text(
                'TRAVEL BLEND',
                style: TextStyle(color: studioDim, fontSize: 11),
              ),
              SizedBox(
                width: 140,
                child: Slider(
                  value: scene.blend,
                  onChanged: (v) => setState(() => scene.blend = v),
                ),
              ),
            ],
          ],
        ),
      ),
    ],
  );
}

/// Loads and caches atlas images by asset path.
class AtlasImages {
  AtlasImages._();
  static final instance = AtlasImages._();
  final _cache = <String, Future<ui.Image>>{};

  Future<ui.Image> load(String path, [AssetBundle? bundle]) =>
      _cache[path] ??= () async {
        final data = await (bundle ?? rootBundle).load(path);
        final codec = await ui.instantiateImageCodec(data.buffer.asUint8List());
        return (await codec.getNextFrame()).image;
      }();
}

enum LoopMode { loop, pingPong, once }

/// Plays one [AtlasAnim] frame by frame: loop, ping-pong or once, a speed
/// multiplier, single steps and a clickable filmstrip.
class AtlasView extends StatefulWidget {
  const AtlasView({super.key, required this.anim, required this.link});
  final AtlasAnim anim;
  final PlayheadLink link;
  @override
  State<AtlasView> createState() => _AtlasViewState();
}

class _AtlasViewState extends State<AtlasView>
    with SingleTickerProviderStateMixin {
  ui.Image? image;
  Object? error;
  late final Ticker _ticker = createTicker(_tick);
  Duration _last = Duration.zero;
  double _clock = 0, speed = 1;
  bool playing = true;
  LoopMode mode = LoopMode.loop;
  int frame = 0;
  bool light = false;

  AtlasAnim get anim => widget.anim;

  @override
  void initState() {
    super.initState();
    _load();
    _bind();
    _ticker.start();
  }

  void _bind() {
    widget.link
      ..position = (() => frame / anim.fps)
      ..section = (() => 'frame ${frame + 1}/${anim.frames.length}')
      ..seek = (seconds) => setState(() {
        playing = false;
        _show((seconds * anim.fps).round());
      });
  }

  Future<void> _load() async {
    try {
      final img = await AtlasImages.instance.load(anim.path);
      if (mounted) setState(() => image = img);
    } catch (e) {
      if (mounted) setState(() => error = e);
    }
  }

  @override
  void didUpdateWidget(AtlasView old) {
    super.didUpdateWidget(old);
    if (old.anim != anim) {
      image = null;
      frame = 0;
      _clock = 0;
      playing = true;
      _load();
    }
    _bind();
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  int get _cycle => mode == LoopMode.pingPong && anim.frames.length > 1
      ? anim.frames.length * 2 - 2
      : anim.frames.length;

  void _tick(Duration elapsed) {
    final dt = (elapsed - _last).inMicroseconds / 1e6;
    _last = elapsed;
    if (!playing || anim.frames.isEmpty) return;
    _clock += dt * speed * anim.fps;
    var step = _clock.floor();
    if (mode == LoopMode.once && step >= anim.frames.length - 1) {
      step = anim.frames.length - 1;
      playing = false;
    }
    final next = _frameAt(step);
    if (next != frame || !playing) setState(() => frame = next);
  }

  int _frameAt(int step) {
    final n = anim.frames.length;
    if (mode == LoopMode.once) return step.clamp(0, n - 1);
    final s = step % _cycle;
    return s < n ? s : _cycle - s;
  }

  void _show(int f) {
    frame = f.clamp(0, anim.frames.length - 1);
    _clock = frame.toDouble();
  }

  @override
  Widget build(BuildContext context) {
    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.space): () =>
            setState(() => playing = !playing),
        const SingleActivator(LogicalKeyboardKey.arrowRight): () =>
            setState(() {
              playing = false;
              _show((frame + 1) % anim.frames.length);
            }),
        const SingleActivator(LogicalKeyboardKey.arrowLeft): () => setState(() {
          playing = false;
          _show((frame - 1 + anim.frames.length) % anim.frames.length);
        }),
      },
      child: Focus(
        autofocus: true,
        child: Column(
          children: [
            Expanded(
              child: Container(
                color: light
                    ? const Color(0xFFD8D4E8)
                    : const Color(0xFF05050C),
                width: double.infinity,
                child: image == null
                    ? Center(
                        child: Text(
                          error == null
                              ? 'Loading ${anim.image}…'
                              : 'Missing ${anim.image}: $error',
                          style: const TextStyle(color: studioDim),
                        ),
                      )
                    : CustomPaint(
                        painter: AtlasFramePainter(image!, anim, frame),
                      ),
              ),
            ),
            SizedBox(
              height: 64,
              child: image == null
                  ? null
                  : ListView.builder(
                      scrollDirection: Axis.horizontal,
                      itemCount: anim.frames.length,
                      itemBuilder: (context, i) => GestureDetector(
                        onTap: () => setState(() {
                          playing = false;
                          _show(i);
                        }),
                        child: Container(
                          width: 60,
                          margin: const EdgeInsets.all(2),
                          decoration: BoxDecoration(
                            color: const Color(0xFF05050C),
                            border: Border.all(
                              color: i == frame ? studioMint : studioLine,
                            ),
                          ),
                          child: CustomPaint(
                            painter: AtlasFramePainter(image!, anim, i),
                          ),
                        ),
                      ),
                    ),
            ),
            Padding(
              padding: const EdgeInsets.all(6),
              child: Wrap(
                spacing: 4,
                runSpacing: 4,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  IconButton(
                    tooltip: 'Previous frame (←)',
                    icon: const Icon(Icons.skip_previous),
                    onPressed: () => setState(() {
                      playing = false;
                      _show(
                        (frame - 1 + anim.frames.length) % anim.frames.length,
                      );
                    }),
                  ),
                  IconButton(
                    key: const ValueKey('atlas-play'),
                    tooltip: 'Play / pause (space)',
                    icon: Icon(playing ? Icons.pause : Icons.play_arrow),
                    onPressed: () => setState(() {
                      if (!playing &&
                          mode == LoopMode.once &&
                          frame == anim.frames.length - 1) {
                        _show(0);
                      }
                      playing = !playing;
                    }),
                  ),
                  IconButton(
                    tooltip: 'Next frame (→)',
                    icon: const Icon(Icons.skip_next),
                    onPressed: () => setState(() {
                      playing = false;
                      _show((frame + 1) % anim.frames.length);
                    }),
                  ),
                  Text(
                    'frame ${frame + 1}/${anim.frames.length} · '
                    '${(anim.fps * speed).toStringAsFixed(1)} fps',
                    style: const TextStyle(color: Colors.white, fontSize: 12),
                  ),
                  SizedBox(
                    width: 150,
                    child: Slider(
                      value: math.log(speed) / math.ln2,
                      min: -3,
                      max: 2,
                      divisions: 10,
                      label: '${speed}x',
                      onChanged: (v) => setState(() {
                        speed = math.pow(2, v).toDouble();
                      }),
                    ),
                  ),
                  Text(
                    '${speed}x',
                    style: const TextStyle(color: studioDim, fontSize: 11),
                  ),
                  for (final m in LoopMode.values)
                    ChoiceChip(
                      label: Text(m.name),
                      selected: mode == m,
                      visualDensity: VisualDensity.compact,
                      onSelected: (_) => setState(() {
                        mode = m;
                        _show(frame);
                        playing = true;
                      }),
                    ),
                  IconButton(
                    tooltip: 'Light / dark backdrop',
                    icon: Icon(
                      light ? Icons.dark_mode : Icons.light_mode,
                      size: 18,
                    ),
                    onPressed: () => setState(() => light = !light),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// One frame, nearest-neighbour, at the largest integer scale that fits
/// (or shrunk smoothly when even 1x does not).
class AtlasFramePainter extends CustomPainter {
  AtlasFramePainter(this.image, this.anim, this.frame);
  final ui.Image image;
  final AtlasAnim anim;
  final int frame;

  @override
  void paint(Canvas canvas, Size size) {
    if (anim.frames.isEmpty) return;
    final box = anim.bounds;
    if (box.isEmpty) return;
    var scale =
        math.min(size.width / box.width, size.height / box.height) * .92;
    scale = scale >= 1 ? scale.floorToDouble() : scale;
    final origin = Offset(
      (size.width - box.width * scale) / 2 - box.left * scale,
      (size.height - box.height * scale) / 2 - box.top * scale,
    );
    final paint = Paint()
      ..filterQuality = scale >= 1 ? FilterQuality.none : FilterQuality.medium
      ..isAntiAlias = false;
    for (final layer in anim.frames[frame.clamp(0, anim.frames.length - 1)]) {
      final dst = Rect.fromLTWH(
        origin.dx + layer.at.dx * scale,
        origin.dy + layer.at.dy * scale,
        layer.src.width * scale,
        layer.src.height * scale,
      );
      canvas.drawImageRect(image, layer.src, dst, paint);
    }
  }

  @override
  bool shouldRepaint(AtlasFramePainter old) =>
      old.frame != frame || old.anim != anim || old.image != image;
}
