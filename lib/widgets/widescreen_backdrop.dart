import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Wide-screen scenery beside the centred game column on desktop.
///
/// Every scene is a 384 x 160 logical-pixel panorama (assets/images/
/// widescreen/, built by tools/widescreen_assets) drawn at an integer
/// nearest-neighbour scale, plus procedural pixel layers: a starfield, the
/// fleet-bridge frame for menus (viewport struts, a console bank with
/// blinking lights, holographic maps), the distant swarm and fleet, embers,
/// fireworks and medal glints, and the command-centre wall behind the squad
/// call slots. Everything is dimmed toward the screen edges so the centre
/// column stays the focus. Images load lazily, the first time a wide layout
/// asks for them; nothing is drawn on phone portrait.
enum BackdropScene {
  /// Title: the fleet facing the swarm, seen from the flagship bridge.
  vista,

  /// Top 10 and initials entry: the hall of heroes.
  hall,

  /// Game over: the horde triumphant, dark red.
  defeat,

  /// Boss victory and campaign complete: the fleet celebrating, gold.
  victory,

  /// Gameplay: the current sector's world, synced to the travel crossfade.
  sector,
}

/// The column the backdrop keeps clear (the 500-px cabinet).
const double backdropColumnWidth = 500;

/// Lazily loaded panoramas, shared by every backdrop instance.
class WidescreenArt extends ChangeNotifier {
  WidescreenArt._();
  static final instance = WidescreenArt._();
  final _images = <String, ui.Image>{};
  final _loading = <String>{};

  /// Asset ids: vista, hall, defeat, victory, sector-1..5, wall.
  ui.Image? operator [](String id) => _images[id];

  void want(Iterable<String> ids, [AssetBundle? bundle]) {
    for (final id in ids) {
      if (_images.containsKey(id) || !_loading.add(id)) continue;
      _load(id, bundle ?? rootBundle);
    }
  }

  Future<void> _load(String id, AssetBundle bundle) async {
    try {
      final data = await bundle.load('assets/images/widescreen/$id.png');
      final codec = await ui.instantiateImageCodec(data.buffer.asUint8List());
      _images[id] = (await codec.getNextFrame()).image;
      codec.dispose();
      notifyListeners();
    } catch (_) {
      // Missing art: the procedural layers still draw.
    }
  }

  /// Test hook: decode every asset now (call inside `tester.runAsync`).
  Future<void> loadAll([AssetBundle? bundle]) async {
    const ids = [
      'vista', 'hall', 'defeat', 'victory', 'wall', //
      'sector-1', 'sector-2', 'sector-3', 'sector-4', 'sector-5',
    ];
    await Future.wait([
      for (final id in ids)
        if (!_images.containsKey(id)) _load(id, bundle ?? rootBundle),
    ]);
  }
}

class WidescreenBackdrop extends StatelessWidget {
  const WidescreenBackdrop({
    super.key,
    required this.scene,
    this.environment = 0,
    this.time = 0,
    this.shipX = 180,
    this.slots = const [],
    this.paused = false,
    this.reduceMotion,
  });

  /// Narrowest margin beside the column that gets scenery.
  static const minSide = 48.0;

  /// True on landscape windows with room beside the column; never on phone
  /// portrait.
  static bool shows(Size size) =>
      size.width >= size.height &&
      size.width - backdropColumnWidth >= 2 * minSide;

  final BackdropScene scene;

  /// The scene's sector position (0..4, fractional during travel).
  final double environment;

  /// Seconds of ambient time (frozen while paused).
  final double time;

  /// Ship x in arena units (0..360): the sector scenery leans against it.
  final double shipX;

  /// Squad call tile rects (screen space) to set into the command wall.
  final List<Rect> slots;
  final bool paused;
  final bool? reduceMotion;

  static List<String> assetsFor(BackdropScene scene, double environment) =>
      switch (scene) {
        BackdropScene.sector => {
          'sector-${environment.floor().clamp(0, 4) + 1}',
          'sector-${environment.ceil().clamp(0, 4) + 1}',
        }.toList(),
        _ => [scene.name],
      };

  @override
  Widget build(BuildContext context) {
    final art = WidescreenArt.instance;
    art.want([
      ...assetsFor(scene, environment),
      if (slots.isNotEmpty) 'wall',
    ]);
    final reduce =
        reduceMotion ?? MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    return RepaintBoundary(
      child: CustomPaint(
        key: const ValueKey('widescreen-backdrop'),
        size: Size.infinite,
        painter: WidescreenBackdropPainter(
          art: art,
          scene: scene,
          environment: environment,
          time: reduce ? 0 : time,
          reduceMotion: reduce,
          shipX: shipX,
          slots: slots,
          paused: paused,
        ),
      ),
    );
  }
}

class _Star {
  const _Star(this.x, this.y, this.depth, this.tint, this.phase);
  final double x, y, phase;
  final int depth, tint;
}

final _stars = () {
  final rng = math.Random(4093);
  return List.generate(
    320,
    (i) => _Star(
      rng.nextDouble(),
      rng.nextDouble(),
      i % 11 == 0 ? 2 : (i % 3 == 0 ? 1 : 0),
      i % 9 == 0 ? 1 : (i % 13 == 0 ? 2 : 0),
      rng.nextDouble() * 6.3,
    ),
  );
}();

int _hash(int a, [int b = 0]) {
  var h = a * 374761393 + b * 668265263;
  h = (h ^ (h >> 13)) * 1274126177;
  return (h ^ (h >> 16)) & 0x7fffffff;
}

const _ink = Color(0xFF080D18);
const _mint = Color(0xFF70F5D5);
const _gold = Color(0xFFF4CA79);
const _salmon = Color(0xFFF2828A);
const _hull = Color(0xFF070B15);
const _hullEdge = Color(0xFF1B2A40);

class WidescreenBackdropPainter extends CustomPainter {
  WidescreenBackdropPainter({
    required this.art,
    required this.scene,
    required this.environment,
    required this.time,
    required this.reduceMotion,
    required this.shipX,
    required this.slots,
    required this.paused,
  }) : super(repaint: art);

  final WidescreenArt art;
  final BackdropScene scene;
  final double environment, time, shipX;
  final bool reduceMotion, paused;
  final List<Rect> slots;

  final _paint = Paint()
    ..isAntiAlias = false
    ..filterQuality = FilterQuality.none;

  /// Screen pixels per logical pixel: the panorama is 160 logical rows tall
  /// and always covers the height at a whole-number scale.
  static double unit(Size size) => math.max(2, (size.height / 160).ceilToDouble());

  @override
  void paint(Canvas canvas, Size size) {
    if (!WidescreenBackdrop.shows(size)) return;
    final u = unit(size);
    final full = Offset.zero & size;
    final columnLeft = (size.width - backdropColumnWidth) / 2;
    if (scene == BackdropScene.sector) {
      // Only the margins: the arena column and the scene's own centred
      // painting stay as they are; the scenery fades out toward the column.
      final painted = size.height * 360 / 520;
      final fadeFrom = math.min((size.width - painted) / 2 + 12, columnLeft - 8);
      final sides = [
        Rect.fromLTRB(0, 0, columnLeft, size.height),
        Rect.fromLTRB(size.width - columnLeft, 0, size.width, size.height),
      ];
      for (final side in sides) {
        canvas.save();
        canvas.clipRect(side);
        canvas.saveLayer(side, Paint());
        _world(canvas, size, u);
        final left = side.left == 0;
        final a = left ? fadeFrom : size.width - fadeFrom;
        final b = left ? columnLeft : size.width - columnLeft;
        canvas.drawRect(
          side,
          Paint()
            ..blendMode = BlendMode.dstIn
            ..shader = ui.Gradient.linear(
              Offset(a, 0),
              Offset(b, 0),
              const [Color(0xFFFFFFFF), Color(0x00FFFFFF)],
            ),
        );
        canvas.restore();
        canvas.restore();
      }
      if (slots.isNotEmpty) _commandWall(canvas, size, u);
      return;
    }
    canvas.drawRect(full, Paint()..color = _ink);
    _starfield(canvas, size, u, .55);
    _panorama(canvas, size, u, scene.name, 1);
    switch (scene) {
      case BackdropScene.vista:
        _swarm(canvas, size, u, const Color(0xFF1A0F22), 34);
        _fleet(canvas, size, u);
        _veil(canvas, size, .18);
        _bridge(canvas, size, u, _mint, _gold);
      case BackdropScene.hall:
        _veil(canvas, size, .2);
        _glints(canvas, size, u);
      case BackdropScene.defeat:
        _swarm(canvas, size, u, const Color(0xFF12040A), 46, wide: true);
        _embers(canvas, size, u, rising: true);
        _veil(canvas, size, .22, tint: const Color(0xFF1A0408));
        _bridge(canvas, size, u, _salmon, const Color(0xFFB0303C));
      case BackdropScene.victory:
        _fireworks(canvas, size, u);
        _embers(canvas, size, u, rising: false);
        _veil(canvas, size, .16);
        _bridge(canvas, size, u, _gold, _mint);
      case BackdropScene.sector:
        break;
    }
    _edgeShade(canvas, size, .62);
  }

  // ------------------------------------------------------------ layers

  void _starfield(Canvas c, Size size, double u, double alpha) {
    final drift = time * .6;
    const tints = [Color(0xFFD8E6FF), _mint, _gold];
    for (var i = 0; i < _stars.length; i++) {
      final s = _stars[i];
      final px = s.depth == 2 ? u : math.max(1.0, (u / 2).floorToDouble());
      final x = ((s.x * size.width + drift * (s.depth + 1)) % size.width / px)
              .floorToDouble() *
          px;
      final y = (s.y * size.height / px).floorToDouble() * px;
      final twinkle = reduceMotion
          ? .7
          : .45 + .55 * math.sin(time * 1.3 + s.phase).abs();
      _paint.color = tints[s.tint].withValues(
        alpha: alpha * twinkle * (.35 + s.depth * .25),
      );
      c.drawRect(Rect.fromLTWH(x, y, px, px), _paint);
    }
  }

  /// Draws a panorama at the integer scale, centred, with a slow sway and
  /// soft ends when the screen is wider than the art (32:9).
  void _panorama(
    Canvas c,
    Size size,
    double u,
    String id,
    double opacity, {
    double lean = 0,
  }) {
    final img = art[id];
    if (img == null || opacity <= 0) return;
    final w = img.width * u, h = img.height * u;
    final sway = reduceMotion ? 0.0 : math.sin(time * .045) * 3;
    final dx = ((sway + lean) * u / 1).roundToDouble();
    final left = ((size.width - w) / 2 / u).roundToDouble() * u + dx;
    final top = ((size.height - h) / 2 / u).roundToDouble() * u;
    final dst = Rect.fromLTWH(left, top, w, h);
    _paint.color = Color.fromRGBO(255, 255, 255, opacity);
    c.drawImageRect(
      img,
      Rect.fromLTWH(0, 0, img.width.toDouble(), img.height.toDouble()),
      dst,
      _paint,
    );
    _paint.color = const Color(0xFFFFFFFF);
    if (w < size.width + 2 * u * 4) {
      // Feather the art's ends into the starfield.
      final feather = math.min(w * .12, 40 * u);
      for (final end in [
        Rect.fromLTWH(dst.left - 1, 0, feather, size.height),
        Rect.fromLTWH(dst.right - feather + 1, 0, feather, size.height),
      ]) {
        final leftEnd = end.left < size.width / 2;
        c.drawRect(
          end,
          Paint()
            ..shader = ui.Gradient.linear(
              Offset(leftEnd ? end.left : end.right, 0),
              Offset(leftEnd ? end.right : end.left, 0),
              [_ink.withValues(alpha: opacity), _ink.withValues(alpha: 0)],
            ),
        );
      }
      final gap = Paint()..color = _ink.withValues(alpha: opacity);
      if (dst.left > 0) c.drawRect(Rect.fromLTRB(0, 0, dst.left, size.height), gap);
      if (dst.right < size.width) {
        c.drawRect(Rect.fromLTRB(dst.right, 0, size.width, size.height), gap);
      }
      if (dst.left > 0 || dst.right < size.width) _starfield(c, size, u, .4);
    }
  }

  /// Gameplay margins: the sector's world, crossfading during travel.
  void _world(Canvas c, Size size, double u) {
    c.drawRect(Offset.zero & size, Paint()..color = _ink);
    final near = environment.floor().clamp(0, 4);
    final far = environment.ceil().clamp(0, 4);
    final blend = (environment - near).clamp(0.0, 1.0);
    final lean = -((shipX - 180) / 180) * 3;
    _starfield(c, size, u, .45);
    _panorama(c, size, u, 'sector-${near + 1}', 1, lean: lean);
    if (far != near && blend > .001) {
      _panorama(c, size, u, 'sector-${far + 1}', blend, lean: lean);
    }
    _veil(c, size, paused ? .62 : .44);
    _edgeShade(c, size, .7);
  }

  void _veil(Canvas c, Size size, double alpha, {Color tint = _ink}) {
    c.drawRect(
      Offset.zero & size,
      Paint()..color = tint.withValues(alpha: alpha),
    );
  }

  /// Darkens the outer edges and the top and bottom: low contrast where the
  /// eye should not go.
  void _edgeShade(Canvas c, Size size, double alpha) {
    final edge = math.min(size.width * .22, size.height * .9);
    for (final left in [true, false]) {
      final r = left
          ? Rect.fromLTWH(0, 0, edge, size.height)
          : Rect.fromLTWH(size.width - edge, 0, edge, size.height);
      c.drawRect(
        r,
        Paint()
          ..shader = ui.Gradient.linear(
            Offset(left ? 0 : size.width, 0),
            Offset(left ? edge : size.width - edge, 0),
            [_ink.withValues(alpha: alpha), _ink.withValues(alpha: 0)],
          ),
      );
    }
    c.drawRect(
      Offset.zero & size,
      Paint()
        ..shader = ui.Gradient.linear(
          Offset.zero,
          Offset(0, size.height),
          [
            _ink.withValues(alpha: alpha * .6),
            _ink.withValues(alpha: 0),
            _ink.withValues(alpha: 0),
            _ink.withValues(alpha: alpha * .7),
          ],
          const [0, .18, .78, 1],
        ),
    );
  }

  // ------------------------------------------------------------ pixel sprites

  static const _batUp = ['X.....X', 'XX.X.XX', '.XXXXX.', '...X...'];
  static const _batDown = ['...X...', '.XXXXX.', 'XX.X.XX', 'X.....X'];
  static const _fighter = ['..X..', '.XXX.', 'XX.XX'];

  void _bitmap(Canvas c, List<String> rows, double x, double y, double px, Color color) {
    _paint.color = color;
    for (var r = 0; r < rows.length; r++) {
      for (var k = 0; k < rows[r].length; k++) {
        if (rows[r].codeUnitAt(k) == 88) {
          c.drawRect(Rect.fromLTWH(x + k * px, y + r * px, px, px), _paint);
        }
      }
    }
  }

  double _snap(double v, double px) => (v / px).floorToDouble() * px;

  /// The demon swarm wheeling over the horizon (right side; both sides when
  /// [wide]).
  void _swarm(Canvas c, Size size, double u, Color color, int count, {bool wide = false}) {
    final px = math.max(1.0, (u / 2).floorToDouble());
    final horizon = size.height * .62;
    final content = math.min(960.0, size.width - 48) / 2;
    final from = size.width / 2 + content * .55;
    for (var i = 0; i < count; i++) {
      final h = _hash(i, 31);
      final rightSide = !wide || i.isEven;
      final span = size.width - from;
      final bx = from + (h % 1000) / 1000 * span * .95;
      final by = horizon - ((h >> 10) % 1000) / 1000 * size.height * (wide ? .45 : .22);
      final t = time * (.18 + (h % 7) * .02) + i;
      var x = bx + math.sin(t) * 6 * u;
      final y = by + math.cos(t * 1.3) * 2 * u;
      if (!rightSide) x = size.width - x;
      final scale = (h >> 20) % 3 == 0 ? px * 2 : px;
      final frame = reduceMotion
          ? _batUp
          : ((time * 5 + i * .37).floor().isEven ? _batUp : _batDown);
      _bitmap(c, frame, _snap(x, px), _snap(y, px), scale, color);
      if (h % 4 == 0) {
        _paint.color = _salmon.withValues(alpha: .55);
        c.drawRect(
          Rect.fromLTWH(_snap(x, px) + 3 * scale, _snap(y, px) + scale, scale, scale),
          _paint,
        );
      }
    }
  }

  /// A few distant fighters patrolling on the fleet side, engines lit.
  void _fleet(Canvas c, Size size, double u) {
    final px = math.max(1.0, (u / 2).floorToDouble());
    final content = math.min(960.0, size.width - 48) / 2;
    final right = size.width / 2 - content * .55;
    for (var i = 0; i < 9; i++) {
      final h = _hash(i, 77);
      final span = right;
      final bx = (h % 1000) / 1000 * span * .9 + span * .05;
      final by = size.height * (.3 + ((h >> 10) % 1000) / 1000 * .28);
      final x = bx + math.sin(time * .12 + i) * 4 * u;
      final y = by + math.sin(time * .2 + i * 2) * u;
      _bitmap(c, _fighter, _snap(x, px), _snap(y, px), px, const Color(0xFF55627E));
      final on = reduceMotion || (time * 3 + i).floor() % 3 != 0;
      _paint.color = _mint.withValues(alpha: on ? .8 : .35);
      c.drawRect(Rect.fromLTWH(_snap(x, px) + 2 * px, _snap(y, px) + 3 * px, px, px), _paint);
    }
  }

  /// Fleet-bridge framing: a hull lintel, viewport struts and a console bank
  /// with blinking pixel lights and two holographic maps.
  void _bridge(Canvas c, Size size, double u, Color light, Color alert) {
    final w = size.width, h = size.height;
    final content = math.min(960.0, w - 48) / 2;
    final lintel = 5 * u;
    final desk = 8 * u;
    final hull = Paint()..color = _hull;
    final edge = Paint()..color = _hullEdge;
    // Lintel with rivets.
    c.drawRect(Rect.fromLTWH(0, 0, w, lintel), hull);
    c.drawRect(Rect.fromLTWH(0, lintel - u, w, u), edge);
    _paint.color = const Color(0xFF243650);
    for (var x = 3 * u; x < w; x += 12 * u) {
      c.drawRect(Rect.fromLTWH(x, 2 * u, u, u), _paint);
    }
    // Struts: two per side, leaning outward toward the floor.
    final room = w / 2 - content;
    final struts = <double>[
      if (room > 60 * u) w / 2 - content - room * .52,
      if (room > 20 * u) w / 2 - content - room * .12,
    ];
    for (final x in struts) {
      for (final s in [-1.0, 1.0]) {
        final cx = w / 2 + s * (w / 2 - x);
        final top = _snap(cx, u);
        final bottom = _snap(cx + s * 10 * u, u);
        final path = Path()
          ..moveTo(top - 2 * u, lintel)
          ..lineTo(top + 2 * u, lintel)
          ..lineTo(bottom + 2 * u, h - desk)
          ..lineTo(bottom - 2 * u, h - desk)
          ..close();
        c.drawPath(path, hull);
        final rim = Path()
          ..moveTo(top - s * 2 * u, lintel)
          ..lineTo(top - s * u, lintel)
          ..lineTo(bottom - s * u, h - desk)
          ..lineTo(bottom - s * 2 * u, h - desk)
          ..close();
        c.drawPath(rim, edge);
      }
    }
    // Console bank.
    final top = h - desk;
    c.drawRect(Rect.fromLTWH(0, top, w, desk), hull);
    c.drawRect(Rect.fromLTWH(0, top, w, u), edge);
    const palette = [Color(0xFF70F5D5), Color(0xFFF4CA79), Color(0xFF6E8BB5)];
    var i = 0;
    for (var x = 2 * u; x < w - 2 * u; x += 3 * u, i++) {
      // Keep the centre quiet under the title content.
      if ((x - w / 2).abs() < content * .7) continue;
      final hsh = _hash(i, 5);
      if (hsh % 3 == 0) continue;
      final period = 1.2 + (hsh % 9) * .35;
      final on = reduceMotion ? hsh % 2 == 0 : ((time + hsh % 97 * .1) % period) < period * .6;
      final color = hsh % 11 == 0 ? alert : (hsh % 4 == 0 ? light : palette[hsh % 3]);
      _paint.color = color.withValues(alpha: on ? .62 : .14);
      c.drawRect(Rect.fromLTWH(x, top + 2 * u, u, u), _paint);
      if (hsh % 5 == 0) {
        _paint.color = color.withValues(alpha: on ? .18 : .45);
        c.drawRect(Rect.fromLTWH(x, top + 4 * u, u, u), _paint);
      }
    }
    // Holographic maps in the outer viewports.
    if (room > 34 * u) {
      final r = math.min(room * .28, 22 * u);
      final y = top - r * .55 - 3 * u;
      _hologram(c, u, Offset(w / 2 - content - room * .3, y), r, light, false);
      _hologram(c, u, Offset(w / 2 + content + room * .3, y), r, alert, true);
    }
  }

  /// A projected star map: dotted rings, a rotating sweep and contacts.
  void _hologram(Canvas c, double u, Offset o, double r, Color color, bool hostile) {
    final px = math.max(1.0, (u / 2).floorToDouble());
    // Projector beam.
    c.drawRect(
      Rect.fromLTRB(o.dx - r, o.dy - r * 1.2, o.dx + r, o.dy + r * .5),
      Paint()
        ..shader = ui.Gradient.linear(
          Offset(o.dx, o.dy + r * .5),
          Offset(o.dx, o.dy - r * 1.2),
          [color.withValues(alpha: .07), color.withValues(alpha: 0)],
        ),
    );
    for (final k in [1.0, .66, .33]) {
      final n = (40 * k).round() + 8;
      for (var j = 0; j < n; j++) {
        final a = j / n * math.pi * 2;
        final p = Offset(o.dx + math.cos(a) * r * k, o.dy + math.sin(a) * r * k * .42);
        _paint.color = color.withValues(alpha: .28);
        c.drawRect(Rect.fromLTWH(_snap(p.dx, px), _snap(p.dy, px), px, px), _paint);
      }
    }
    final sweep = reduceMotion ? .8 : time * .7;
    for (var s = 0; s < 8; s++) {
      final p = Offset(
        o.dx + math.cos(sweep) * r * s / 8,
        o.dy + math.sin(sweep) * r * .42 * s / 8,
      );
      _paint.color = color.withValues(alpha: .45);
      c.drawRect(Rect.fromLTWH(_snap(p.dx, px), _snap(p.dy, px), px, px), _paint);
    }
    for (var j = 0; j < (hostile ? 9 : 6); j++) {
      final h = _hash(j, hostile ? 911 : 313);
      final a = (h % 628) / 100;
      final d = ((h >> 10) % 100) / 100 * .9;
      final p = Offset(o.dx + math.cos(a) * r * d, o.dy + math.sin(a) * r * d * .42 - px * 2);
      final blink = reduceMotion || ((time * 2 + j) % 3) > .6;
      _paint.color = (hostile ? _salmon : _mint).withValues(alpha: blink ? .7 : .25);
      c.drawRect(Rect.fromLTWH(_snap(p.dx, px), _snap(p.dy, px), px * 2, px * 2), _paint);
    }
  }

  /// Rising embers (defeat) or drifting gold dust (victory).
  void _embers(Canvas c, Size size, double u, {required bool rising}) {
    final px = math.max(1.0, (u / 2).floorToDouble());
    for (var i = 0; i < 60; i++) {
      final h = _hash(i, rising ? 41 : 43);
      final speed = (12 + h % 20) * px;
      var y = (h >> 8) % 1000 / 1000 * size.height;
      y = rising ? (y - time * speed) % size.height : (y + time * speed * .4) % size.height;
      final x = (h % 1000) / 1000 * size.width + math.sin(time * .8 + i) * 3 * px;
      final color = rising
          ? (i % 3 == 0 ? const Color(0xFFF08A4B) : const Color(0xFFB0303C))
          : (i % 3 == 0 ? _mint : _gold);
      _paint.color = color.withValues(alpha: .25 + (h % 5) * .08);
      c.drawRect(Rect.fromLTWH(_snap(x, px), _snap(y, px), px, px), _paint);
    }
  }

  /// Pixel firework bursts in the outer sky, a new one every few seconds.
  void _fireworks(Canvas c, Size size, double u) {
    final px = math.max(1.0, (u / 2).floorToDouble());
    final content = math.min(960.0, size.width - 48) / 2;
    const colors = [_gold, _mint, Color(0xFFBDA7FF)];
    for (var k = 0; k < 5; k++) {
      final cycle = 3.4 + k * .7;
      final age = reduceMotion ? .5 : ((time + k * 1.3) % cycle) / 1.6;
      if (age > 1) continue;
      final round = reduceMotion ? 0 : ((time + k * 1.3) / cycle).floor();
      final h = _hash(k, round);
      final left = h.isEven;
      final room = size.width / 2 - content * .8;
      final x = left
          ? (h % 1000) / 1000 * room
          : size.width - (h % 1000) / 1000 * room;
      final y = size.height * (.12 + ((h >> 10) % 100) / 100 * .3);
      final color = colors[h % 3];
      final radius = (6 + 10 * age) * u;
      for (var j = 0; j < 16; j++) {
        final a = j / 16 * math.pi * 2;
        final p = Offset(x + math.cos(a) * radius, y + math.sin(a) * radius + age * age * 4 * u);
        _paint.color = color.withValues(alpha: (1 - age) * .75);
        c.drawRect(Rect.fromLTWH(_snap(p.dx, px), _snap(p.dy, px), px * 2, px * 2), _paint);
      }
    }
  }

  /// Slow glints over the medal wall.
  void _glints(Canvas c, Size size, double u) {
    final px = math.max(1.0, (u / 2).floorToDouble());
    for (var i = 0; i < 14; i++) {
      final h = _hash(i, 1203);
      final period = 2.5 + (h % 7) * .5;
      final t = reduceMotion ? .5 : ((time + (h % 100) / 10) % period) / .6;
      if (t > 1) continue;
      final x = (h % 1000) / 1000 * size.width;
      final y = size.height * (.2 + ((h >> 10) % 1000) / 1000 * .5);
      final a = math.sin(t * math.pi) * .8;
      _paint.color = const Color(0xFFFFF0C8).withValues(alpha: a);
      final cx = _snap(x, px), cy = _snap(y, px);
      c.drawRect(Rect.fromLTWH(cx, cy, px, px), _paint);
      _paint.color = _gold.withValues(alpha: a * .5);
      for (final d in const [Offset(-1, 0), Offset(1, 0), Offset(0, -1), Offset(0, 1)]) {
        c.drawRect(Rect.fromLTWH(cx + d.dx * px, cy + d.dy * px, px, px), _paint);
      }
    }
  }

  /// The command-centre wall: a bulkhead per side with the call slots set
  /// into recessed bezels, status lights and conduits. The panels themselves
  /// are drawn by the comms widgets on top.
  void _commandWall(Canvas c, Size size, double u) {
    final wall = art['wall'];
    final px = math.max(2.0, (u / 2).floorToDouble());
    for (final leftSide in [true, false]) {
      final mine = slots.where((r) => (r.center.dx < size.width / 2) == leftSide).toList();
      if (mine.isEmpty) continue;
      var bound = mine.first;
      for (final r in mine.skip(1)) {
        bound = bound.expandToInclude(r);
      }
      final panel = Rect.fromLTRB(
        _snap(bound.left - 5 * px, px),
        _snap(bound.top - 6 * px, px),
        _snap(bound.right + 5 * px, px) + px,
        _snap(bound.bottom + 8 * px, px) + px,
      );
      final chamfer = 4 * px;
      final shape = Path()
        ..moveTo(panel.left + chamfer, panel.top)
        ..lineTo(panel.right - chamfer, panel.top)
        ..lineTo(panel.right, panel.top + chamfer)
        ..lineTo(panel.right, panel.bottom - chamfer)
        ..lineTo(panel.right - chamfer, panel.bottom)
        ..lineTo(panel.left + chamfer, panel.bottom)
        ..lineTo(panel.left, panel.bottom - chamfer)
        ..lineTo(panel.left, panel.top + chamfer)
        ..close();
      // Drop shadow, then the plate.
      c.drawPath(
        shape.shift(Offset(px, px * 2)),
        Paint()..color = const Color(0xAA02040A),
      );
      c.save();
      c.clipPath(shape);
      c.drawRect(panel, Paint()..color = const Color(0xF00B1220));
      if (wall != null) {
        final paint = Paint()
          ..filterQuality = FilterQuality.none
          ..color = const Color(0x8CFFFFFF)
          ..shader = ImageShader(
            wall,
            TileMode.repeated,
            TileMode.repeated,
            Matrix4.diagonal3Values(px, px, 1).storage,
            filterQuality: FilterQuality.none,
          );
        c.drawRect(panel, paint);
      }
      // Vertical conduit between the slots.
      final conduitX = _snap(bound.center.dx, px);
      for (var k = 0; k + 1 < mine.length; k++) {
        final a = mine[k], b = mine[k + 1];
        final r = Rect.fromLTRB(conduitX - 3 * px, a.bottom, conduitX + 3 * px, b.top);
        c.drawRect(r, Paint()..color = const Color(0xFF0F1828));
        c.drawRect(Rect.fromLTWH(r.left + px, r.top, px, r.height), Paint()..color = _hullEdge);
        final pulse = reduceMotion ? .5 : (time * .9 + k) % 1;
        _paint.color = _mint.withValues(alpha: .5);
        c.drawRect(
          Rect.fromLTWH(r.left + 3 * px, _snap(r.top + r.height * pulse, px), px, px * 2),
          _paint,
        );
      }
      c.restore();
      // Rim light on the plate.
      c.drawPath(
        shape,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = px
          ..color = const Color(0xFF1E3048),
      );
      // Recessed bezel around each slot, with status lights below it.
      for (var k = 0; k < mine.length; k++) {
        final r = mine[k];
        final bezel = Rect.fromLTRB(
          _snap(r.left - 2 * px, px),
          _snap(r.top - 2 * px, px),
          _snap(r.right + 2 * px, px) + px,
          _snap(r.bottom + 2 * px, px) + px,
        );
        c.drawRect(bezel, Paint()..color = const Color(0xFF03060C));
        c.drawRect(
          Rect.fromLTWH(bezel.left, bezel.bottom - px, bezel.width, px),
          Paint()..color = const Color(0xFF22344C),
        );
        c.drawRect(
          Rect.fromLTWH(bezel.right - px, bezel.top, px, bezel.height),
          Paint()..color = const Color(0xFF1A2A3E),
        );
        final ly = bezel.bottom + 2 * px;
        for (var j = 0; j < 5; j++) {
          final h = _hash(j + k * 7, leftSide ? 3 : 4);
          final on = reduceMotion ? j < 3 : ((time * (.6 + j * .17) + h % 10) % 2) < 1.3;
          final color = j == 4 ? _gold : _mint;
          _paint.color = color.withValues(alpha: on ? .65 : .15);
          c.drawRect(Rect.fromLTWH(bezel.left + (2 + j * 3) * px, ly, px, px), _paint);
        }
      }
    }
  }

  @override
  bool shouldRepaint(WidescreenBackdropPainter old) =>
      old.scene != scene ||
      old.environment != environment ||
      old.time != time ||
      old.shipX != shipX ||
      old.paused != paused ||
      old.reduceMotion != reduceMotion ||
      old.slots.length != slots.length ||
      (slots.isNotEmpty && old.slots.first != slots.first);
}
