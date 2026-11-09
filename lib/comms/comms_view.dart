/// Squad video call: four call tiles beside the centered arena on wide
/// screens, a compact stack inside the HUD band everywhere else.
library;

import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import 'comms_director.dart';
import 'comms_portraits.dart';
import 'comms_types.dart';

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

  static const _subtitleHeight = 62.0, _tagHeight = 18.0;
}

/// Loads the portrait atlases once and repaints listeners when ready.
class CommsPortraitAtlas extends ChangeNotifier {
  CommsPortraitAtlas._();
  static final instance = CommsPortraitAtlas._();
  ui.Image? large, small;
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

/// Draws one portrait frame with nearest-neighbour sampling.
void paintPortrait(
  Canvas canvas,
  Rect dst,
  String id,
  int frame, {
  bool small = false,
  Color accent = const Color(0xFF39DFCC),
}) {
  final atlas = CommsPortraitAtlas.instance;
  final image = small ? (atlas.small ?? atlas.large) : atlas.large;
  final row = commsPortraitRows[id];
  if (image != null && row != null) {
    final cell =
        (image == atlas.small ? commsPortraitSmallCell : commsPortraitCell)
            .toDouble();
    final src = Rect.fromLTWH(frame * cell, row * cell, cell, cell);
    canvas.drawImageRect(
      image,
      src,
      dst,
      Paint()
        ..filterQuality = FilterQuality.none
        ..isAntiAlias = false,
    );
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

/// Brood glyph script: original 5 x 7 pixel symbols seeded by the clip id.
class AlienGlyphPainter extends CustomPainter {
  AlienGlyphPainter(this.seed, this.count, this.reveal, this.color);
  final int seed, count;
  final double reveal;
  final Color color;
  static const _w = 5, _h = 7;

  static List<List<bool>> glyph(int seed, int index) {
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
    final px = math.max(1.0, (size.height / (_h + 1)).floorToDouble());
    final advance = px * (_w + 2);
    final shown = (count * reveal).ceil().clamp(0, count);
    final paint = Paint()..color = color;
    var x = 0.0;
    for (var i = 0; i < shown && x + _w * px <= size.width; i++) {
      final g = glyph(seed, i);
      for (var y = 0; y < _h; y++) {
        for (var gx = 0; gx < _w; gx++) {
          if (g[y][gx]) {
            canvas.drawRect(Rect.fromLTWH(x + gx * px, y * px, px, px), paint);
          }
        }
      }
      x += advance + (i % 3 == 2 ? px * 3 : 0);
    }
  }

  @override
  bool shouldRepaint(AlienGlyphPainter old) =>
      old.reveal != reveal || old.seed != seed || old.color != color;
}

int _seedOf(String text) {
  var h = 7;
  for (final c in text.codeUnits) {
    h = (h * 31 + c) & 0x7fffffff;
  }
  return h;
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
      // Backdrop: a dim accent wash keeps each caller identifiable.
      canvas.drawRect(
        r,
        Paint()
          ..color =
              (who.isDemon ? const Color(0xFF2A0F1C) : const Color(0xFF0F2030))
                  .withValues(alpha: 1),
      );
      final frame = m != null && m.speaking(now)
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
    // Live indicator and signal bars.
    if (who != null && state == CommsSlotState.live) {
      final dot = Paint()
        ..color = speaking ? const Color(0xFFFF5A5A) : const Color(0xFF3E8E6E);
      canvas.drawRect(Rect.fromLTWH(5, 5, 4, 4), dot);
      final bars = Paint()..color = accent.withValues(alpha: .8);
      for (var i = 0; i < 4; i++) {
        final h = 3.0 + i * 2;
        if (who.isDemon && i == 3 && (now * 3).floor().isEven) continue;
        canvas.drawRect(
          Rect.fromLTWH(size.width - 22 + i * 4, 13 - h, 3, h),
          bars,
        );
      }
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
    this.fontSize = 11,
    this.maxLines = 3,
    this.glyphHeight = 9,
  });
  final CommsMessage message;
  final double now, fontSize, glyphHeight;
  final int maxLines;

  @override
  Widget build(BuildContext context) {
    final c = message.character;
    final accent = Color(c.accent);
    final line = message.line;
    if (line.isGrunt) {
      final reveal = (message.age(now) / math.max(.3, line.duration)).clamp(
        .15,
        1.0,
      );
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            height: glyphHeight,
            width: double.infinity,
            child: CustomPaint(
              painter: AlienGlyphPainter(
                _seedOf(line.id),
                3 + (line.duration * 5).round(),
                reveal,
                accent,
              ),
            ),
          ),
          const SizedBox(height: 3),
          Text(
            'SIGINT · ${line.gloss ?? 'UNKNOWN'}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: const Color(0xFFFFB0A8),
              fontSize: fontSize * .8,
              letterSpacing: 1.2,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
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
  });
  final CommsDirector director;
  final double now;
  final CommsLayout layout;

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
          final m = director.messageOn(slot.index);
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
                        fontSize: 11 * math.min(scale, 1.2),
                        glyphHeight: 9 * math.min(scale, 1.3),
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
/// of the arena, just below the HUD band (the HUD stays readable). One
/// strip shows the most important active line; a second active line
/// collapses into a chip, and waiting lines show as `+n`. It dims while the
/// player is being hit ([dimmed]).
class CommsHudStack extends StatelessWidget {
  const CommsHudStack({
    super.key,
    required this.director,
    required this.now,
    this.dimmed = false,
  });
  final CommsDirector director;
  final double now;
  final bool dimmed;

  static const stripHeight = 36.0, chipHeight = 18.0, gap = 2.0;
  static const portrait = 34.0;

  /// Tallest the dock gets (strip + chip row).
  static const maxHeight = stripHeight + gap + chipHeight;

  @override
  Widget build(BuildContext context) {
    final reduce = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    // Spoken lines win the strip (their subtitle must be readable); a
    // demon grunt takes it only when nobody else is talking.
    final shown = [...director.active]
      ..sort(
        (a, b) => a.isDemon != b.isDemon
            ? (a.isDemon ? 1 : -1)
            : b.priority != a.priority
            ? b.priority.compareTo(a.priority)
            : a.startedAt.compareTo(b.startedAt),
      );
    if (shown.isEmpty) return const SizedBox.shrink();
    final waiting = director.queue.where((m) => now >= m.readyAt).length;
    final main = shown.first;
    final rest = shown.skip(1).toList();
    return IgnorePointer(
      child: AnimatedOpacity(
        opacity: dimmed ? .3 : 1,
        duration: Duration(milliseconds: reduce ? 0 : 120),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _strip(main, reduce),
            if (rest.isNotEmpty || waiting > 0) ...[
              const SizedBox(height: gap),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  for (final m in rest) _chip(m, reduce),
                  if (waiting > 0)
                    Container(
                      height: chipHeight,
                      margin: const EdgeInsets.only(left: 4),
                      padding: const EdgeInsets.symmetric(horizontal: 5),
                      alignment: Alignment.center,
                      color: const Color(0xA60A1220),
                      child: Text(
                        '+$waiting',
                        style: const TextStyle(color: _muted, fontSize: 9),
                      ),
                    ),
                ],
              ),
            ],
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

  double _fade(CommsMessage m, bool reduce) => reduce
      ? 1.0
      : (math.min(m.age(now), m.endsAt - now) / .18).clamp(0.0, 1.0);

  Widget _strip(CommsMessage m, bool reduce) {
    final c = m.character;
    final accent = Color(c.accent);
    final speaking = m.speaking(now);
    final tag = c.isDemon ? c.name : c.callsign;
    final celebrating = director.celebrating(now) && !c.isDemon;
    return Opacity(
      key: ValueKey('comms-strip-${m.line.id}'),
      opacity: _fade(m, reduce),
      child: Container(
        height: stripHeight,
        decoration: BoxDecoration(
          color: const Color(0xB30A1220),
          border: Border(
            left: BorderSide(color: accent, width: 2),
            bottom: BorderSide(
              color: speaking ? accent.withValues(alpha: .5) : _line,
            ),
          ),
        ),
        child: Row(
          children: [
            SizedBox(
              width: portrait,
              height: portrait,
              child: ClipRect(
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
            const SizedBox(width: 6),
            Expanded(
              child: m.line.isGrunt
                  ? Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          tag,
                          maxLines: 1,
                          style: TextStyle(
                            color: accent,
                            fontSize: 8,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1,
                          ),
                        ),
                        CommsSubtitle(
                          message: m,
                          now: now,
                          fontSize: 10,
                          maxLines: 1,
                          glyphHeight: 8,
                        ),
                      ],
                    )
                  : Align(
                      alignment: Alignment.centerLeft,
                      child: Text.rich(
                        TextSpan(
                          children: [
                            TextSpan(
                              text: '${celebrating ? '★ ' : ''}$tag  ',
                              style: TextStyle(
                                color: celebrating
                                    ? const Color(0xFFFFD86B)
                                    : accent,
                                fontSize: 8.5,
                                fontWeight: FontWeight.bold,
                                letterSpacing: .8,
                              ),
                            ),
                            TextSpan(text: m.line.text ?? ''),
                          ],
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: _text,
                          fontSize: 10.5,
                          height: 1.15,
                          shadows: [
                            Shadow(color: Color(0xFF000000), blurRadius: 2),
                          ],
                        ),
                      ),
                    ),
            ),
            const SizedBox(width: 4),
          ],
        ),
      ),
    );
  }

  /// A collapsed second line: tiny portrait and who is talking.
  Widget _chip(CommsMessage m, bool reduce) {
    final c = m.character;
    final accent = Color(c.accent);
    return Opacity(
      key: ValueKey('comms-chip-${m.line.id}'),
      opacity: _fade(m, reduce),
      child: Container(
        height: chipHeight,
        margin: const EdgeInsets.only(left: 4),
        padding: const EdgeInsets.only(right: 6),
        decoration: BoxDecoration(
          color: const Color(0xA60A1220),
          border: Border(left: BorderSide(color: accent, width: 2)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: chipHeight,
              height: chipHeight,
              child: ClipRect(
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
            const SizedBox(width: 4),
            Text(
              c.isDemon ? '${c.name} · ${m.line.gloss ?? ''}' : c.callsign,
              style: TextStyle(
                color: accent,
                fontSize: 8,
                fontWeight: FontWeight.bold,
                letterSpacing: .8,
              ),
            ),
          ],
        ),
      ),
    );
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
    canvas.drawRect(
      r,
      Paint()
        ..color = who.isDemon
            ? const Color(0xFF2A0F1C)
            : const Color(0xFF0F2030),
    );
    final side = commsPortraitSmallCell * zoom * (size.width < 30 ? .5 : 1);
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
