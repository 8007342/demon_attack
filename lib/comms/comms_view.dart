/// Squad video call: four call tiles beside the centered arena on wide
/// screens, a compact stack inside the HUD band everywhere else.
library;

import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import '../game/bonus/challenge_badge.dart'; // --- bonus challenges
import 'comms_bank.dart';
import 'comms_briefing.dart';
import 'comms_director.dart';
import 'comms_lanes.dart';
import 'brood_script.dart';
import 'comms_portraits.dart';
import 'comms_transition_chatter.dart';
import 'comms_types.dart';
import 'comms_one_line.dart'
    show commsStripFont, commsStripTagFont, commsTileFont;

part 'comms_briefing_view.dart';

const _ink = Color(0xFF080D18);
const _line = Color(0xFF26394C);
const _muted = Color(0xFF7B91A8);
const _text = Color(0xFFE6EEF6);

/// Where the call is drawn for a given screen.
class CommsLayout {
  const CommsLayout._(this.side, this.sideWidth, this.tileWidth);

  /// Width of the centered cabinet (arena, HUD and trackpad).
  static const cabinetWidth = 500.0;

  /// Narrowest side margin that holds a call column.
  static const minSide = 150.0;
  static const panelPadding = 14.0;

  factory CommsLayout.of(Size size) {
    final side = (size.width - math.min(cabinetWidth, size.width)) / 2;
    if (side < minSide || size.height < 360) {
      return const CommsLayout._(false, 0, 0);
    }
    return CommsLayout._(
      true,
      side,
      math.min(side - 2 * panelPadding, 300).toDouble(),
    );
  }

  /// True: two tiles on each side of the arena. False: the compact dock at
  /// the top of the arena ([CommsHudStack]).
  final bool side;
  final double sideWidth, tileWidth;

  /// Rects of the four tiles (slot order) inside a screen of [size].
  List<Rect> tileRects(Size size) {
    if (!side) return const [];
    final subtitle = _subtitleHeight, tag = _tagHeight;
    final avail = size.height - 2 * 26 - 18;
    final video = math.min(tileWidth * .86, (avail - 2 * (tag + subtitle)) / 2);
    final tileH = tag + video + subtitle;
    final top = math.max(26.0, (size.height - (2 * tileH + 18)) / 2);
    final leftX = (sideWidth - tileWidth) / 2;
    final rightX = size.width - sideWidth + (sideWidth - tileWidth) / 2;
    return [
      for (final x in [leftX, rightX])
        for (var row = 0; row < 2; row++)
          Rect.fromLTWH(x, top + row * (tileH + 18), tileWidth, tileH),
    ];
  }

  static const _subtitleHeight = 76.0, _tagHeight = 18.0;
}

/// Loads the portrait atlases once and repaints listeners when ready.
class CommsPortraitAtlas extends ChangeNotifier {
  CommsPortraitAtlas._();
  static final instance = CommsPortraitAtlas._();
  ui.Image? large, small, backdrops;
  Future<void>? _loading;

  Future<void> load([AssetBundle? bundle]) =>
      _loading ??= _load(bundle ?? rootBundle);

  Future<void> _load(AssetBundle bundle) async {
    Future<ui.Image?> one(String path) async {
      try {
        final data = await bundle.load(path);
        final codec = await ui.instantiateImageCodec(data.buffer.asUint8List());
        return (await codec.getNextFrame()).image;
      } catch (_) {
        return null;
      }
    }

    large = await one(commsPortraitImage);
    small = await one(commsPortraitSmallImage);
    backdrops = await one(commsBackdropImage);
    notifyListeners();
  }
}

int _hash(int a, int b, int c) {
  var h = a * 374761393 + b * 668265263 + c * 2147483647;
  h = (h ^ (h >> 13)) * 1274126177;
  return (h ^ (h >> 16)) & 0x7fffffff;
}

/// Resting face between lines: the trigger's mood just after speaking, then
/// deterministic blinks and an occasional small head tilt.
int restFrame(double now, int seed, {CommsSlot? slot}) {
  if (slot != null && now < slot.moodUntil) {
    switch (slot.mood) {
      case CommsMood.happy:
        return CommsFrame.happy;
      case CommsMood.worried:
        return CommsFrame.worried;
      case CommsMood.stern:
        break;
    }
  }
  final period = 3.1 + (seed % 5) * .37;
  final t = (now + seed * .61) % period;
  if (t < .13) return CommsFrame.blink;
  final glance = (now + seed * 1.7) % (8.5 + seed % 4);
  if (glance < 1.1) {
    return seed.isEven ? CommsFrame.tiltLeft : CommsFrame.tiltRight;
  }
  if (glance > 4.2 && glance < 5.0) {
    return seed.isEven ? CommsFrame.tiltRight : CommsFrame.tiltLeft;
  }
  return CommsFrame.idle;
}

/// Breathing: one logical portrait pixel of vertical bob, stepped.
double idleBob(double now, int seed, {required bool reduceMotion}) =>
    reduceMotion ? 0 : (((now + seed * .37) / 1.7) % 1 < .5 ? 0 : -1);

/// Sampling for a portrait cell of [cell] px drawn [side] px wide: crisp
/// nearest-neighbour when magnified, filtered when shrunk (nearest would
/// drop whole rows of a 2-3 px mouth and make it jump around).
FilterQuality portraitFilter(double cell, double side) => side >= cell - .01
    ? FilterQuality.none
    : side >= cell * .5 - .01
    ? FilterQuality.low
    : FilterQuality.medium;

/// Draws one portrait frame: nearest-neighbour when magnified. With
/// [from] and [amount] < 1 (the lip-sync cross-fade) the previous mouth
/// shape shows through; the frames differ only inside the mouth box.
void paintPortrait(
  Canvas canvas,
  Rect dst,
  String id,
  int frame, {
  bool small = false,
  Color accent = const Color(0xFF39DFCC),
  int? from,
  double amount = 1,
}) {
  final atlas = CommsPortraitAtlas.instance;
  final image = small ? (atlas.small ?? atlas.large) : atlas.large;
  final row = commsPortraitRows[id];
  if (image != null && row != null) {
    final cell =
        (image == atlas.small ? commsPortraitSmallCell : commsPortraitCell)
            .toDouble();
    final quality = portraitFilter(cell, dst.width);
    void draw(int f, double alpha) => canvas.drawImageRect(
      image,
      Rect.fromLTWH(f * cell, row * cell, cell, cell),
      dst,
      Paint()
        ..filterQuality = quality
        ..isAntiAlias = false
        ..color = Color.fromRGBO(255, 255, 255, alpha),
    );
    if (from != null && from != frame && amount < 1) {
      draw(from, 1);
      draw(frame, amount.clamp(0.0, 1.0));
    } else {
      draw(frame, 1);
    }
    return;
  }
  // Fallback silhouette on a 12-cell grid while the atlas is missing.
  final u = dst.width / 12;
  final paint = Paint()..color = accent.withValues(alpha: .55);
  for (var y = 0; y < 12; y++) {
    for (var x = 0; x < 12; x++) {
      final dx = (x - 5.5).abs(), head = y >= 2 && y <= 7 && dx < 3.2;
      final body = y >= 8 && dx < 5;
      if (head || body) {
        canvas.drawRect(
          Rect.fromLTWH(dst.left + x * u, dst.top + y * u, u + .5, u + .5),
          paint,
        );
      }
    }
  }
  if (frame >= CommsFrame.talkA) {
    canvas.drawRect(
      Rect.fromLTWH(dst.left + 5 * u, dst.top + 6 * u, 2 * u, u),
      Paint()..color = _ink,
    );
  }
}

/// The caller's room behind the portrait: a bridge or cockpit for the fleet,
/// a command tent or tank interior for the ground squad, an infernal
/// war-room for the brood. Drawn to cover [r] with a slow, slight parallax
/// and a dark veil so the face stays readable.
void paintBackdrop(
  Canvas canvas,
  Rect r,
  CommsCharacter who,
  double now, {
  required bool reduceMotion,
}) {
  final image = CommsPortraitAtlas.instance.backdrops;
  final index = commsBackdropOf[who.id];
  final base = who.isDemon
      ? const Color(0xFF2A0F1C)
      : who.side == CommsSide.ground
      ? const Color(0xFF1A2014)
      : const Color(0xFF0F2030);
  canvas.drawRect(r, Paint()..color = base);
  if (image != null && index != null) {
    final w = commsBackdropSize.w.toDouble(),
        h = commsBackdropSize.h.toDouble();
    final cols = math.max(1, image.width ~/ w);
    final src = Rect.fromLTWH((index % cols) * w, (index ~/ cols) * h, w, h);
    // Cover the area with 8% to spare for the parallax drift.
    final cover = math.max(r.width / w, r.height / h) * 1.08;
    final dw = w * cover, dh = h * cover;
    final drift = reduceMotion
        ? 0.0
        : math.sin(now * .23 + who.id.length) * (dw - r.width) / 2;
    final dst = Rect.fromCenter(
      center: r.center.translate(drift, 0),
      width: dw,
      height: dh,
    );
    canvas.drawImageRect(
      image,
      src,
      dst,
      Paint()
        ..filterQuality = FilterQuality.none
        ..isAntiAlias = false,
    );
    canvas.drawRect(r, Paint()..color = const Color(0x6B050912));
    return;
  }
  // Fallback until the backdrop atlas is packed: stepped console bands.
  final band = Paint()..color = Color.lerp(base, const Color(0xFF000000), .35)!;
  for (var y = r.top + r.height * .62; y < r.bottom; y += r.height * .09) {
    canvas.drawRect(Rect.fromLTWH(r.left, y, r.width, r.height * .04), band);
  }
}

/// Signal static: blocky deterministic noise.
void paintStatic(Canvas canvas, Rect r, double now, double amount, int seed) {
  if (amount <= 0) return;
  final block = math.max(2.0, (r.width / 40).floorToDouble());
  final tick = (now * 24).floor();
  final paint = Paint();
  for (var y = r.top; y < r.bottom; y += block) {
    final row = ((y - r.top) / block).floor();
    final tear = _hash(row, tick, seed) % 100 < 8;
    for (var x = r.left; x < r.right; x += block) {
      final h = _hash(((x - r.left) / block).floor(), row + tick * 131, seed);
      if ((h % 1000) / 1000 > amount * (tear ? 1.0 : .85)) continue;
      final v = 40 + h % 150;
      paint.color = Color.fromARGB(
        (200 * amount).round().clamp(0, 255),
        v,
        v + 10 > 255 ? 255 : v + 10,
        math.min(255, v + 30),
      );
      canvas.drawRect(
        Rect.fromLTWH(
          x,
          y,
          math.min(block, r.right - x),
          math.min(block, r.bottom - y),
        ),
        paint,
      );
    }
  }
}

void paintScanlines(Canvas canvas, Rect r, {double pitch = 3}) {
  final paint = Paint()..color = const Color(0x2E000000);
  for (var y = r.top + 1; y < r.bottom; y += pitch) {
    canvas.drawRect(Rect.fromLTWH(r.left, y, r.width, 1), paint);
  }
}

/// Brood glyph script: an original, stable 5 x 7 pixel alphabet.
class AlienGlyphPainter extends CustomPainter {
  AlienGlyphPainter(this.symbols, this.reveal, this.color, {this.rows = 1});
  final List<int> symbols;
  final int rows;
  final double reveal;
  final Color color;
  static const _w = 5, _h = 7;

  static List<List<bool>> glyph(int index) {
    const seed = 0xB00D;
    final cells = List.generate(_h, (_) => List.filled(_w, false));
    for (var y = 0; y < _h; y++) {
      for (var x = 0; x < 3; x++) {
        final on = _hash(seed, index * 31 + y * 7 + x, 17) % 100 < 42;
        cells[y][x] = on;
        cells[y][_w - 1 - x] = on; // bilateral, like carved runes
      }
    }
    // A spine keeps every glyph connected and readable as one sign.
    for (var y = 1; y < _h - 1; y++) {
      if (_hash(seed, index, y) % 3 != 0) cells[y][2] = true;
    }
    return cells;
  }

  @override
  void paint(Canvas canvas, Size size) {
    final px = math.max(1.0, (size.height / (rows * (_h + 1))).floorToDouble());
    final advance = px * (_w + 2);
    final shown = (symbols.length * reveal).ceil().clamp(0, symbols.length);
    final paint = Paint()..color = color;
    var x = 0.0;
    var row = 0;
    for (var i = 0; i < shown; i++) {
      if (x + _w * px > size.width) {
        row++;
        x = 0;
      }
      if (row >= rows) break;
      if (symbols[i] < 0) {
        x += px * 3;
        continue;
      }
      final g = glyph(symbols[i]);
      for (var y = 0; y < _h; y++) {
        for (var gx = 0; gx < _w; gx++) {
          if (g[y][gx]) {
            canvas.drawRect(
              Rect.fromLTWH(x + gx * px, (row * (_h + 1) + y) * px, px, px),
              paint,
            );
          }
        }
      }
      x += advance;
    }
  }

  @override
  bool shouldRepaint(AlienGlyphPainter old) =>
      old.reveal != reveal ||
      old.symbols != symbols ||
      old.rows != rows ||
      old.color != color;
}

/// Video area of one call tile.
class CommsTilePainter extends CustomPainter {
  CommsTilePainter({
    required this.slot,
    required this.message,
    required this.now,
    required this.reduceMotion,
    required this.zoom,
    required this.cast,
  });
  final CommsSlot slot;
  final CommsMessage? message;
  final double now, zoom;
  final bool reduceMotion;
  final Map<String, CommsCharacter> cast;

  @override
  void paint(Canvas canvas, Size size) {
    final r = Offset.zero & size;
    canvas.drawRect(r, Paint()..color = const Color(0xFF0B1424));
    final state = slot.state(now);
    final who = cast[slot.occupant ?? slot.leaving ?? ''];
    final accent = Color(who?.accent ?? 0xFF39DFCC);
    final m = message;
    canvas.save();
    canvas.clipRect(r);
    if (who != null && state != CommsSlotState.empty) {
      paintBackdrop(canvas, r, who, now, reduceMotion: reduceMotion);
      final talking = m != null && m.speaking(now);
      final (from, _, amount) = talking
          ? m.mouthBlend(now)
          : (CommsFrame.idle, CommsFrame.idle, 1.0);
      final frame = talking
          ? m.frame(now)
          : restFrame(now, slot.index * 7 + who.id.length, slot: slot);
      final cell = math.min(size.width, size.height);
      final scale = cell >= commsPortraitCell
          ? (cell / commsPortraitCell).floorToDouble()
          : cell / commsPortraitCell;
      // A grunt zooms the camera onto the face, in whole-pixel steps.
      final px = zoom > 1
          ? math.max(scale, (scale * zoom).roundToDouble())
          : scale;
      final side = commsPortraitCell * px;
      var center = r.center.translate(
        0,
        idleBob(now, slot.index + who.id.length, reduceMotion: reduceMotion) *
            scale,
      );
      if (zoom > 1 && !reduceMotion && m != null && frame == CommsFrame.grunt) {
        final t = now * 43;
        center += Offset(math.sin(t) * 2, math.cos(t * 1.3) * 1.5);
      }
      paintPortrait(
        canvas,
        Rect.fromCenter(
          center: center.translate(
            0,
            side * .04 + (px - scale) * commsPortraitCell * .08,
          ),
          width: side,
          height: side,
        ),
        who.id,
        frame,
        accent: accent,
        from: reduceMotion ? null : from,
        amount: amount,
      );
    } else {
      final label = TextPainter(
        text: const TextSpan(
          text: 'NO SIGNAL',
          style: TextStyle(
            color: Color(0xFF3B5168),
            fontSize: 9,
            letterSpacing: 2,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      label.paint(canvas, r.center - Offset(label.width / 2, label.height / 2));
    }
    // Connect / disconnect: static that clears (or swallows the picture).
    final t = slot.transition(now);
    if (state == CommsSlotState.connecting ||
        state == CommsSlotState.disconnecting) {
      final amount = state == CommsSlotState.connecting ? 1 - t : t;
      if (reduceMotion) {
        canvas.drawRect(r, Paint()..color = _ink.withValues(alpha: amount));
      } else {
        paintStatic(canvas, r, now, amount, slot.index + 3);
      }
    } else if (state == CommsSlotState.empty && !reduceMotion) {
      paintStatic(canvas, r, now, .12, slot.index + 11);
    }
    paintScanlines(
      canvas,
      r,
      pitch: math.max(2, size.height / 64).floorToDouble(),
    );
    canvas.restore();
    // Speaking glow: a stepped accent border that pulses with the mouth.
    final speaking = m != null && m.speaking(now);
    final open = speaking ? (m.frame(now) >= CommsFrame.talkB ? 1.0 : .6) : 0.0;
    canvas.drawRect(
      r.deflate(.5),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = speaking ? accent : _line,
    );
    if (speaking) {
      for (var i = 1; i <= 2; i++) {
        canvas.drawRect(
          r.inflate(i * 1.5),
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.5
            ..color = accent.withValues(alpha: (.45 - i * .15) * open + .1),
        );
      }
    }
    // Live indicator (no signal-strength bars: ux-declutter).
    if (who != null && state == CommsSlotState.live) {
      final dot = Paint()
        ..color = speaking ? const Color(0xFFFF5A5A) : const Color(0xFF3E8E6E);
      canvas.drawRect(Rect.fromLTWH(5, 5, 4, 4), dot);
    }
  }

  @override
  bool shouldRepaint(CommsTilePainter old) => true;
}

String _tag(CommsCharacter c) =>
    c.isDemon ? '${c.rank} ${c.name}' : '${c.rank} ${c.name} · ${c.callsign}';

/// Subtitle of a message: spoken text, or brood glyphs with a SIGINT gloss.
class CommsSubtitle extends StatelessWidget {
  const CommsSubtitle({
    super.key,
    required this.message,
    required this.now,
    this.fontSize = 13,
    this.maxLines = 3,
    this.glyphHeight = 9,
    this.glyphRows = 1,
  });
  final CommsMessage message;
  final double now, fontSize, glyphHeight;
  final int maxLines;
  final int glyphRows;

  @override
  Widget build(BuildContext context) {
    final c = message.character;
    final accent = Color(c.accent);
    final line = message.line;
    if (line.isGrunt) {
      final reduce = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
      final meaning = line.gloss ?? 'UNKNOWN';
      final reveal = (message.age(now) / math.max(.3, line.duration)).clamp(
        0.0,
        1.0,
      );
      final translation = BroodScript.translation(
        meaning,
        message.age(now),
        line.duration,
        reduceMotion: reduce,
      );
      return Semantics(
        label: '${c.name}. $meaning',
        liveRegion: true,
        child: ExcludeSemantics(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                height: glyphHeight,
                width: double.infinity,
                child: CustomPaint(
                  painter: AlienGlyphPainter(
                    BroodScript.encode(meaning),
                    reduce ? 1 : reveal,
                    accent,
                    rows: glyphRows,
                  ),
                ),
              ),
              const SizedBox(height: 3),
              Text(
                'SIGINT · $translation',
                maxLines: maxLines,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: const Color(0xFFFFB0A8),
                  fontSize: fontSize * .85,
                  letterSpacing: 1.2,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      );
    }
    return Text(
      line.text ?? '',
      maxLines: maxLines,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(color: _text, fontSize: fontSize, height: 1.2),
    );
  }
}

/// Wide screens: the four call tiles around the shared arena.
class CommsSidePanels extends StatelessWidget {
  const CommsSidePanels({
    super.key,
    required this.director,
    required this.now,
    required this.layout,
    this.hide = const {},
  });
  final CommsDirector director;
  final double now;
  final CommsLayout layout;

  /// Messages another view is showing (the urgent-mission card's turns).
  final Set<CommsMessage> hide;

  @override
  Widget build(BuildContext context) {
    final reduce = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    return LayoutBuilder(
      builder: (context, bounds) {
        final size = bounds.biggest;
        final rects = layout.tileRects(size);
        final tiles = <(double, Widget)>[];
        for (final slot in director.slots) {
          final rect = rects[slot.index];
          final on = director.messageOn(slot.index);
          final m = on != null && hide.contains(on) ? null : on;
          var zoom = 1.0;
          if (m != null && m.isDemon && m.speaking(now)) {
            final t = m.age(now), out = m.line.duration - t;
            final ease = Curves.easeOutBack.transform(
              (math.min(t, out) / .22).clamp(0.0, 1.0),
            );
            zoom = 1 + .55 * (reduce ? (t < m.line.duration ? 1 : 0) : ease);
          }
          tiles.add((zoom, _tile(context, slot, m, rect, size, zoom, reduce)));
        }
        tiles.sort((a, b) => a.$1.compareTo(b.$1));
        final celebrating = director.celebrating(now);
        return Stack(
          clipBehavior: Clip.none,
          children: [
            for (final side in [true, false])
              Positioned(
                left: side ? 0 : size.width - layout.sideWidth,
                width: layout.sideWidth,
                top: math.max(4, rects[side ? 0 : 2].top - 22),
                child: Center(
                  child: Text(
                    celebrating
                        ? (side
                              ? '★ FLEET INTACT · ALL SHIPS HOME ★'
                              : '◌ BROOD NET · SIGNAL COLLAPSING')
                        : side
                        ? '◉ SQUAD CHANNEL · SHARING ARENA'
                        : '◌ GROUND LINK · BROOD INTERCEPT',
                    maxLines: 1,
                    overflow: TextOverflow.fade,
                    softWrap: false,
                    style: TextStyle(
                      color: celebrating && side
                          ? ((now * 3).floor().isEven
                                ? const Color(0xFFFFD86B)
                                : const Color(0xFFFFF1C2))
                          : side
                          ? const Color(0xFF6FE7D2)
                          : const Color(0xFFE07A8A),
                      fontSize: celebrating && side ? 9.5 : 8,
                      letterSpacing: 1.6,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            for (final t in tiles) t.$2,
          ],
        );
      },
    );
  }

  Widget _tile(
    BuildContext context,
    CommsSlot slot,
    CommsMessage? m,
    Rect rect,
    Size size,
    double zoom,
    bool reduce,
  ) {
    final who = director.cast[slot.occupant ?? ''];
    final accent = Color(who?.accent ?? 0xFF39DFCC);
    // A grunting officer's tile grows toward the arena edge but never past
    // its own side margin.
    final maxScale = (layout.sideWidth - 8) / rect.width;
    final scale = math.min(zoom, math.max(1.0, maxScale));
    // Height grows with the full zoom, over the neighbouring tile.
    final grown = Rect.fromCenter(
      center: rect.center,
      width: rect.width * scale,
      height: rect.height * zoom,
    );
    final sideLeft = slot.left ? 0.0 : size.width - layout.sideWidth;
    final dx = grown.left < sideLeft + 4
        ? sideLeft + 4 - grown.left
        : grown.right > sideLeft + layout.sideWidth - 4
        ? sideLeft + layout.sideWidth - 4 - grown.right
        : 0.0;
    final dy = grown.top < 2
        ? 2 - grown.top
        : grown.bottom > size.height - 2
        ? size.height - 2 - grown.bottom
        : 0.0;
    final box = grown.shift(Offset(dx, dy));
    final video =
        box.height -
        CommsLayout._tagHeight -
        CommsLayout._subtitleHeight * scale;
    return Positioned.fromRect(
      key: ValueKey('comms-tile-${slot.index}'),
      rect: box,
      child: Container(
        decoration: BoxDecoration(
          color: zoom > 1 ? const Color(0xFF080D18) : const Color(0xF2080D18),
          border: Border.all(
            color: m != null ? accent.withValues(alpha: .7) : _line,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              height: CommsLayout._tagHeight,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        who == null
                            ? 'CH ${slot.index + 1} · STANDBY'
                            : _tag(who),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: who == null ? _muted : accent,
                          fontSize: 8.5,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            SizedBox(
              height: math.max(0, video),
              child: CustomPaint(
                painter: CommsTilePainter(
                  slot: slot,
                  message: m,
                  now: now,
                  reduceMotion: reduce,
                  zoom: zoom,
                  cast: director.cast,
                ),
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(7, 5, 7, 4),
                child: m == null
                    ? const SizedBox.shrink()
                    : CommsSubtitle(
                        message: m,
                        now: now,
                        fontSize: commsTileFont * math.min(scale, 1.2),
                        glyphHeight: 11 * math.min(scale, 1.3),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Phones and narrow windows: a compact, translucent call dock at the top
/// of the arena, just below the HUD band. It dims while the player is being
/// hit ([dimmed]).
///
/// portrait-comms-lanes: the dock is TWO independent lanes ([CommsLanes]):
/// the squad and the ground link on the left, the brood on the right. Each
/// lane has its own queue, timeout and persistence; a toast stays where it
/// appeared until it expires, then closes in place. Every toast has one
/// fixed size ([stripHeight] tall, half the dock wide): it never collapses
/// to its text or grows to match its neighbour; a line longer than the box
/// scrolls inside it, in time with its reading time. Linked dialogue (an
/// exchange and its comeback) shares one full-width toast with portraits at
/// either end.
class CommsHudStack extends StatelessWidget {
  const CommsHudStack({
    super.key,
    required this.director,
    required this.now,
    this.dimmed = false,
    this.hideTransmission = false,
    this.hide = const {},
    this.banner,
  });
  final CommsDirector director;
  final double now;
  final bool dimmed;

  /// A full-size transmission card is showing the transmission line.
  final bool hideTransmission;

  /// bonus-briefing: messages another card shows (the urgent-mission
  /// card's turns), left out of the dock. portrait-comms-lanes: also the
  /// lines the transition chatter shows over the clouds.
  final Set<CommsMessage> hide;

  /// bonus-briefing: a card at the top of the dock (the urgent-mission
  /// card); the dock's toasts stack under it. It takes taps; the toasts
  /// never do.
  final Widget? banner;

  /// portrait-comms-lanes: the one toast height (four lines of radio text
  /// at [commsStripFont], or a brood grunt's glyphs and three SIGINT lines,
  /// plus the frame). carrier-hatches §A12 sized it (was 76).
  static const stripHeight = 84.0, chipHeight = 18.0, gap = 2.0;

  /// The toast's portrait side, and the half-scale face (narrow boxes).
  static const portrait = 40.0, minPortrait = 26.0;

  /// Tallest the dock gets (the toasts plus the exchange/queue label).
  static const maxHeight = stripHeight + gap + chipHeight;

  bool _hidden(CommsMessage m) =>
      (hideTransmission && m.transmission) || hide.contains(m);

  @override
  Widget build(BuildContext context) {
    final reduce = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    final lanes = director.lanes
      ..sync(now, director.active, queue: director.queue, hidden: _hidden);
    final left = lanes.toast(CommsLane.human);
    final right = lanes.toast(CommsLane.demon);
    final top = banner;
    if (left == null && right == null) return top ?? const SizedBox.shrink();
    final dock = _dock(left, right, reduce);
    if (top == null) return dock;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        top,
        const SizedBox(height: gap * 2),
        dock,
      ],
    );
  }

  Widget _dock(CommsToast? left, CommsToast? right, bool reduce) {
    final pair = left != null && identical(left, right) ? left : null;
    final lanes = director.lanes;
    final waiting = [
      for (final lane in CommsLane.values)
        pair != null || lanes.pairWaiting ? 0 : lanes.waiting(lane),
    ];
    Widget label(String text, {TextAlign align = TextAlign.center}) => Text(
      text,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      textAlign: align,
      style: const TextStyle(color: _muted, fontSize: 9),
    );
    return IgnorePointer(
      child: AnimatedOpacity(
        opacity: dimmed ? .3 : 1,
        duration: Duration(milliseconds: reduce ? 0 : 120),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              key: const ValueKey('comms-lanes'),
              height: stripHeight,
              child: pair != null
                  ? _pairToast(pair, reduce)
                  : Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Expanded(
                          child: left == null
                              ? const SizedBox.shrink()
                              : _single(left, reduce),
                        ),
                        const SizedBox(width: gap * 2),
                        Expanded(
                          child: right == null
                              ? const SizedBox.shrink()
                              : _single(right, reduce, right: true),
                        ),
                      ],
                    ),
            ),
            if (pair != null)
              SizedBox(
                height: chipHeight,
                child: label(
                  '${pair.messages.first.character.callsign} → '
                  '${pair.messages.last.character.callsign}',
                ),
              )
            else if (waiting.any((n) => n > 0))
              SizedBox(
                height: chipHeight,
                child: Row(
                  children: [
                    for (final (i, n) in waiting.indexed) ...[
                      if (i > 0) const SizedBox(width: gap * 2),
                      Expanded(
                        child: n > 0
                            ? label(
                                '+$n',
                                align: i == 0
                                    ? TextAlign.left
                                    : TextAlign.right,
                              )
                            : const SizedBox.shrink(),
                      ),
                    ],
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  /// One lane's toast: framed, the speaker's portrait on the lane's outer
  /// edge.
  Widget _single(CommsToast t, bool reduce, {bool right = false}) {
    final m = t.messages.single;
    return Opacity(
      key: ValueKey('comms-strip-${m.line.id}'),
      alwaysIncludeSemantics: true,
      opacity: t.opacity(now, queue: director.queue, reduce: reduce),
      child: _maybeFramed(
        framed: true,
        leading: Color(m.character.accent),
        barOnRight: right,
        lit: m.speaking(now),
        height: stripHeight,
        child: _strip(m, t, reduce, right: right, keyed: false),
      ),
    );
  }

  /// An exchange and its comeback: one toast across both lanes.
  Widget _pairToast(CommsToast t, bool reduce) {
    final a = t.half(CommsLane.human), b = t.half(CommsLane.demon);
    return Opacity(
      alwaysIncludeSemantics: true,
      opacity: t.opacity(now, queue: director.queue, reduce: reduce),
      child: _maybeFramed(
        key: const ValueKey('comms-conversation'),
        framed: true,
        leading: Color(a.character.accent),
        trailing: Color(b.character.accent),
        lit: a.speaking(now) || b.speaking(now),
        height: stripHeight,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(child: _strip(a, t, reduce)),
            Expanded(child: _strip(b, t, reduce, right: true)),
          ],
        ),
      ),
    );
  }

  /// Vertical room the toast frame takes (padding plus border, both edges):
  /// just enough to keep the text off the rounded border.
  static const _frameInset = 4.0;

  /// A radio toast: rounded, fully bordered card with a soft drop shadow and
  /// an accent bar on the speaker's side ([trailing]: a second bar on the
  /// right for a two-speaker exchange). The border lights in the speaker's
  /// colour while they talk. Unframed, it is a plain box of [height].
  Widget _maybeFramed({
    Key? key,
    required bool framed,
    required Color leading,
    required Widget child,
    Color? trailing,
    bool barOnRight = false,
    bool lit = false,
    double? height,
  }) {
    if (!framed) return SizedBox(key: key, height: height, child: child);
    const radius = 8.0, bar = 3.0;
    final edge = lit
        ? (trailing == null ? leading : Color.lerp(leading, trailing, .5)!)
              .withValues(alpha: .7)
        : const Color(0x6694A3B8);
    Widget accentBar(Color color, {required bool right}) => Positioned(
      top: 0,
      bottom: 0,
      left: right ? null : 0,
      right: right ? 0 : null,
      width: bar,
      child: ColoredBox(color: color),
    );
    return Container(
      key: key,
      height: height,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xE6121D2E), Color(0xD90A1220)],
        ),
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: edge),
        boxShadow: const [
          BoxShadow(
            color: Color(0x8C000000),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(radius - 1),
        child: Stack(
          fit: StackFit.expand,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                bar + 3,
                _frameInset / 2 - 1,
                bar + 3,
                _frameInset / 2 - 1,
              ),
              child: child,
            ),
            if (trailing != null) ...[
              accentBar(leading, right: false),
              accentBar(trailing, right: true),
            ] else
              accentBar(leading, right: barOnRight),
          ],
        ),
      ),
    );
  }

  int _frame(CommsMessage m) => m.speaking(now)
      ? m.frame(now)
      : restFrame(
          now,
          m.character.id.length,
          slot: m.slot < 0 ? null : director.slots[m.slot],
        );

  double _zoom(CommsMessage m, bool reduce) => m.isDemon && m.speaking(now)
      ? 1 +
            .22 *
                (reduce
                    ? 1
                    : Curves.easeOut.transform(
                        (m.age(now) / .2).clamp(0.0, 1.0),
                      ))
      : 1.0;

  /// How far a line that overflows its box has scrolled: it holds its
  /// first lines for the first 30 % of the toast's reading window, glides
  /// to its last lines by 80 %, and holds them.
  double _scroll(CommsMessage m, CommsToast t) {
    if (!m.started) return 0;
    final from = math.max(t.shownAt, m.startedAt);
    final span = math.max(
      .5,
      t.endsAt(now, queue: director.queue) - CommsLanes.fade - from,
    );
    final u = ((now - from) / span - .3) / .5;
    return Curves.easeInOut.transform(u.clamp(0.0, 1.0));
  }

  /// One speaker's half of a toast, at the fixed size: the portrait on the
  /// lane's outer edge, the words beside it. An answer that has not started
  /// yet shows its speaker waiting.
  Widget _strip(
    CommsMessage m,
    CommsToast t,
    bool reduce, {
    bool right = false,
    bool keyed = true,
  }) {
    final c = m.character;
    final accent = Color(c.accent);
    final tag = c.isDemon ? c.name : c.callsign;
    final celebrating = director.celebrating(now) && !c.isDemon;
    final face = SizedBox.square(
      dimension: portrait,
      child: KeyedSubtree(
        key: ValueKey('comms-portrait-${m.line.id}'),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(5),
          child: CustomPaint(
            painter: _MiniPortrait(
              c,
              _frame(m),
              _zoom(m, reduce),
              now,
              m,
              reduce,
            ),
          ),
        ),
      ),
    );
    final Widget words;
    if (!m.started) {
      words = Align(
        alignment: Alignment.centerLeft,
        child: Text(
          '$tag  …',
          maxLines: 1,
          style: TextStyle(
            color: accent.withValues(alpha: .6),
            fontSize: commsStripTagFont,
            fontWeight: FontWeight.bold,
            letterSpacing: .8,
          ),
        ),
      );
    } else if (m.line.isGrunt) {
      words = CommsScrollBox(
        progress: _scroll(m, t),
        stepped: reduce,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              tag,
              maxLines: 1,
              style: TextStyle(
                color: accent,
                fontSize: 9,
                fontWeight: FontWeight.bold,
                letterSpacing: 1,
              ),
            ),
            CommsSubtitle(
              message: m,
              now: now,
              fontSize: 12.5,
              maxLines: 6,
              glyphHeight: 16,
              glyphRows: 2,
            ),
          ],
        ),
      );
    } else {
      words = CommsScrollBox(
        progress: _scroll(m, t),
        stepped: reduce,
        child: Text.rich(
          TextSpan(
            children: [
              TextSpan(
                text: '${celebrating ? '★ ' : ''}$tag  ',
                style: TextStyle(
                  color: celebrating ? const Color(0xFFFFD86B) : accent,
                  fontSize: commsStripTagFont,
                  fontWeight: FontWeight.bold,
                  letterSpacing: .8,
                ),
              ),
              TextSpan(text: m.line.text ?? ''),
            ],
          ),
          style: const TextStyle(
            color: _text,
            fontSize: commsStripFont,
            height: 1.15,
            shadows: [Shadow(color: Color(0xFF000000), blurRadius: 2)],
          ),
        ),
      );
    }
    return KeyedSubtree(
      key: keyed ? ValueKey('comms-strip-${m.line.id}') : null,
      child: Row(
        children: [
          if (!right) ...[face, const SizedBox(width: 6)],
          Expanded(child: words),
          if (right) ...[const SizedBox(width: 6), face],
        ],
      ),
    );
  }
}

/// portrait-comms-lanes: a fixed box for a toast's words. Text that fits
/// is centred vertically; text taller than the box scrolls up by
/// [progress] (0: its first lines, 1: its last lines), or jumps a page at a
/// time when [stepped] (reduced motion). The box never changes size.
class CommsScrollBox extends SingleChildRenderObjectWidget {
  const CommsScrollBox({
    super.key,
    required this.progress,
    this.stepped = false,
    required super.child,
  });
  final double progress;
  final bool stepped;

  @override
  RenderCommsScrollBox createRenderObject(BuildContext context) =>
      RenderCommsScrollBox(progress, stepped);

  @override
  void updateRenderObject(
    BuildContext context,
    RenderCommsScrollBox renderObject,
  ) {
    renderObject
      ..progress = progress
      ..stepped = stepped;
  }
}

class RenderCommsScrollBox extends RenderShiftedBox {
  RenderCommsScrollBox(this._progress, this._stepped) : super(null);

  double _progress;
  set progress(double v) {
    if (v == _progress) return;
    _progress = v;
    markNeedsLayout();
  }

  bool _stepped;
  set stepped(bool v) {
    if (v == _stepped) return;
    _stepped = v;
    markNeedsLayout();
  }

  /// How much taller than the box the words are (0 when they fit).
  double overflow = 0;

  @override
  void performLayout() {
    size = constraints.biggest;
    final c = child;
    if (c == null) return;
    c.layout(BoxConstraints(maxWidth: size.width), parentUsesSize: true);
    overflow = math.max(0, c.size.height - size.height);
    final data = c.parentData! as BoxParentData;
    if (overflow <= 0) {
      data.offset = Offset(0, (size.height - c.size.height) / 2);
      return;
    }
    var p = _progress.clamp(0.0, 1.0);
    if (_stepped) {
      final pages = (c.size.height / size.height).ceil();
      p = (p * pages).floorToDouble().clamp(0, pages - 1) / (pages - 1);
    }
    data.offset = Offset(0, -overflow * p);
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    if (child == null) return;
    if (overflow <= 0) {
      _clip.layer = null;
      super.paint(context, offset);
      return;
    }
    _clip.layer = context.pushClipRect(
      needsCompositing,
      offset,
      Offset.zero & size,
      super.paint,
      oldLayer: _clip.layer,
    );
  }

  final _clip = LayerHandle<ClipRectLayer>();

  @override
  void dispose() {
    _clip.layer = null;
    super.dispose();
  }
}

class _MiniPortrait extends CustomPainter {
  _MiniPortrait(this.who, this.frame, this.zoom, this.now, this.m, this.reduce);
  final CommsCharacter who;
  final int frame;
  final double zoom, now;
  final CommsMessage m;
  final bool reduce;

  @override
  void paint(Canvas canvas, Size size) {
    final r = Offset.zero & size;
    paintBackdrop(canvas, r, who, now, reduceMotion: reduce);
    final side = commsPortraitSmallCell * zoom * (size.width < 40 ? .5 : 1);
    paintPortrait(
      canvas,
      Rect.fromCenter(
        center: r.center.translate(0, side * .1),
        width: side,
        height: side,
      ),
      who.id,
      frame,
      small: true,
      accent: Color(who.accent),
      from: !reduce && m.speaking(now) ? m.mouthBlend(now).$1 : null,
      amount: m.speaking(now) ? m.mouthBlend(now).$3 : 1,
    );
    final age = m.age(now);
    if (!reduce && age < .25) {
      paintStatic(canvas, r, now, 1 - age / .25, who.id.length);
    }
    paintScanlines(canvas, r, pitch: 2);
  }

  @override
  bool shouldRepaint(_MiniPortrait old) => true;
}

/// Phones and narrow windows: a full-size transmission shown in place of a
/// transition (travel, wave entrance): a big portrait with the smoothed
/// lip-sync, the caller's backdrop, name and rank, and the subtitle.
class CommsTransmission extends StatelessWidget {
  const CommsTransmission({
    super.key,
    required this.message,
    required this.now,
  });
  final CommsMessage message;
  final double now;

  @override
  Widget build(BuildContext context) {
    final reduce = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    final m = message;
    final c = m.character;
    final accent = Color(c.accent);
    final mission = m.trigger.name.startsWith('transmissionMission');
    final age = m.age(now), left = m.endsAt - now;
    final fade = reduce ? 1.0 : (math.min(age, left) / .25).clamp(0.0, 1.0);
    return IgnorePointer(
      child: Opacity(
        key: ValueKey('comms-transmission-${m.line.id}'),
        opacity: fade,
        child: ColoredBox(
          color: const Color(0xE6050912),
          child: LayoutBuilder(
            builder: (context, box) {
              final width = math.min(box.maxWidth - 24, 340.0);
              // Integer scale of the 128 px portrait that fits.
              final room = math.min(width - 24, box.maxHeight - 150);
              final scale = math.max(1, (room / commsPortraitCell).floor());
              final side = (commsPortraitCell * scale).toDouble();
              return Center(
                child: Container(
                  width: width,
                  padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
                  decoration: BoxDecoration(
                    color: const Color(0xF20A1220),
                    border: Border.all(color: accent.withValues(alpha: .8)),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        mission
                            ? '◉ PRIORITY TRANSMISSION · FLEET COMMAND'
                            : '◌ OPEN CHANNEL · SQUAD',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: mission
                              ? const Color(0xFFFFD86B)
                              : const Color(0xFF6FE7D2),
                          fontSize: 9,
                          letterSpacing: 1.6,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Center(
                        child: SizedBox(
                          width: side,
                          height: side,
                          child: CustomPaint(
                            painter: _TransmissionPortrait(m, now, reduce),
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _tag(c),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: accent,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.2,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        m.line.text ?? '',
                        style: const TextStyle(
                          color: _text,
                          fontSize: 17,
                          height: 1.3,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

/// portrait-comms-lanes: a level transition's radio chatter, at the
/// landscape call tiles' size, in the middle of the arena over the clouds:
/// one long line as one wide card; two short lines, or a line and its
/// comeback, as two cards side by side (humans left, the brood right). A
/// comeback's two cards share one frame. Cards never move: a short line's
/// card holds its half from the start, so a second line fills the other.
class TransitionChatterView extends StatelessWidget {
  const TransitionChatterView({
    super.key,
    required this.chatter,
    required this.now,
    required this.maxWidth,
    required this.maxHeight,
  });
  final TransitionChatter chatter;
  final double now, maxWidth, maxHeight;

  /// The landscape tiles' widest card, the gap between two cards, the
  /// subtitle box and the tag row (as [CommsLayout]).
  static const maxCard = 300.0, gap = 8.0, subtitle = 76.0, tagRow = 18.0;

  /// The comeback frame's label row.
  static const labelRow = 16.0;

  @override
  Widget build(BuildContext context) {
    final reduce = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    final shape = chatter.shape;
    if (shape == ChatterShape.none) return const SizedBox.shrink();
    final comeback = shape == ChatterShape.comeback;
    final wide = shape == ChatterShape.long;
    final width = wide
        ? math.min(maxCard, maxWidth)
        : math.min(maxCard, (maxWidth - gap - (comeback ? 8 : 0)) / 2);
    final room =
        maxHeight - tagRow - subtitle - 2 - (comeback ? labelRow + 8 : 0);
    final video = math.max(48.0, math.min(width - 2, room)).floorToDouble();
    final messages = [...chatter.shown, ?chatter.pendingReply];
    Widget card(CommsMessage? m) =>
        m == null ? SizedBox(width: width) : _card(m, width, video, reduce);
    final Widget body;
    if (wide) {
      body = card(messages.single);
    } else {
      // Humans left, the brood right; two of one side: in start order.
      CommsMessage? left, right;
      if (messages.length == 2 &&
          messages.first.isDemon == messages.last.isDemon) {
        (left, right) = (messages.first, messages.last);
      } else {
        for (final m in messages) {
          if (m.isDemon) {
            right = m;
          } else {
            left = m;
          }
        }
      }
      body = Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          card(left),
          const SizedBox(width: gap),
          card(right),
        ],
      );
    }
    final framed = comeback
        ? Container(
            key: const ValueKey('transition-chatter-comeback'),
            padding: const EdgeInsets.fromLTRB(4, 0, 4, 4),
            decoration: BoxDecoration(
              color: const Color(0xB3050912),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: _line),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  height: labelRow,
                  child: Center(
                    child: Text(
                      '${messages.first.character.callsign} → '
                      '${messages.last.character.callsign}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: _muted, fontSize: 9),
                    ),
                  ),
                ),
                body,
              ],
            ),
          )
        : body;
    return FittedBox(
      key: const ValueKey('transition-chatter'),
      fit: BoxFit.scaleDown,
      child: framed,
    );
  }

  Widget _card(CommsMessage m, double width, double video, bool reduce) {
    final c = m.character;
    final accent = Color(c.accent);
    return Container(
      key: ValueKey('transition-chatter-${m.line.id}'),
      width: width,
      decoration: BoxDecoration(
        color: const Color(0xF2080D18),
        border: Border.all(
          color: m.speaking(now) ? accent : accent.withValues(alpha: .6),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            height: tagRow,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  _tag(c),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: accent,
                    fontSize: 8.5,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1,
                  ),
                ),
              ),
            ),
          ),
          Center(
            child: SizedBox.square(
              dimension: video,
              child: CustomPaint(
                painter: _TransmissionPortrait(m, now, reduce),
              ),
            ),
          ),
          SizedBox(
            height: subtitle,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(7, 5, 7, 4),
              child: m.started
                  ? CommsScrollBox(
                      // Longer subtitles scroll in the fixed box over the
                      // line's reading time, as the dock's toasts do.
                      progress: Curves.easeInOut.transform(
                        ((m.age(now) /
                                        math.max(
                                          .5,
                                          CommsMessage.readingTime(m.line),
                                        ) -
                                    .3) /
                                .5)
                            .clamp(0.0, 1.0),
                      ),
                      stepped: reduce,
                      child: CommsSubtitle(
                        message: m,
                        now: now,
                        fontSize: commsTileFont,
                        maxLines: 8,
                        glyphHeight: 11,
                      ),
                    )
                  : Text(
                      '…',
                      style: TextStyle(color: accent, fontSize: commsTileFont),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TransmissionPortrait extends CustomPainter {
  _TransmissionPortrait(this.m, this.now, this.reduce);
  final CommsMessage m;
  final double now;
  final bool reduce;

  @override
  void paint(Canvas canvas, Size size) {
    final r = Offset.zero & size;
    final who = m.character;
    canvas.save();
    canvas.clipRect(r);
    paintBackdrop(canvas, r, who, now, reduceMotion: reduce);
    final scale = size.width / commsPortraitCell;
    final talking = m.speaking(now);
    final frame = talking ? m.frame(now) : restFrame(now, who.id.length);
    final (from, _, amount) = talking
        ? m.mouthBlend(now)
        : (CommsFrame.idle, CommsFrame.idle, 1.0);
    final bob = idleBob(now, who.id.length, reduceMotion: reduce) * scale;
    paintPortrait(
      canvas,
      r.translate(0, bob),
      who.id,
      frame,
      accent: Color(who.accent),
      from: reduce ? null : from,
      amount: amount,
    );
    final age = m.age(now);
    if (age < .35) {
      final amount = 1 - age / .35;
      if (reduce) {
        canvas.drawRect(r, Paint()..color = _ink.withValues(alpha: amount));
      } else {
        paintStatic(canvas, r, now, amount * .8, who.id.length);
      }
    }
    paintScanlines(canvas, r, pitch: math.max(2, scale).toDouble() + 1);
    canvas.restore();
    final speaking = m.speaking(now);
    canvas.drawRect(
      r.deflate(.5),
      Paint()
        ..style = PaintingStyle.stroke
        ..color = speaking ? Color(who.accent) : _line,
    );
  }

  @override
  bool shouldRepaint(_TransmissionPortrait old) => true;
}

/// Keeps a widget repainting when the portrait atlas finishes loading.
class CommsAtlasScope extends StatefulWidget {
  const CommsAtlasScope({super.key, required this.child});
  final Widget child;
  @override
  State<CommsAtlasScope> createState() => _CommsAtlasScopeState();
}

class _CommsAtlasScopeState extends State<CommsAtlasScope> {
  @override
  void initState() {
    super.initState();
    CommsPortraitAtlas.instance
      ..addListener(_changed)
      ..load();
  }

  void _changed() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    CommsPortraitAtlas.instance.removeListener(_changed);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

/// Unawaited helper for callers that only want to start the load.
void preloadCommsPortraits() => unawaited(CommsPortraitAtlas.instance.load());
