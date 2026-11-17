part of 'comms_view.dart';

// --- bonus briefing (openspec/changes/bonus-levels, design "Urgent-mission
// card"): the one radio card a transition may show, in the dock's toast
// style. It is a radio comm, not floating text: a speaker portrait, the
// level's rule, the run rule in play and the scripted chatter as it is
// spoken. Compact for phones (no dead padding), sized by the caller to end
// above the ship row, tappable to dismiss, still with reduced motion.

/// The "URGENT MISSION!" card of a bonus level's transition.
class BonusBriefingCard extends StatelessWidget {
  const BonusBriefingCard({
    super.key,
    required this.briefing,
    required this.now,
    this.maxHeight = double.infinity,
    this.onDismiss,
    this.holding = false,
  });
  final BonusBriefing briefing;
  final double now;

  /// mission-medals: the card is holding the level's start (it shows its
  /// tap prompt).
  final bool holding;

  /// mission-medals: a level's rule as a pictogram under its brief (what
  /// to do, drawn on the objects), keyed by level id.
  static const Map<String, CustomPainter> howTo = {
    'supplyRun': SupplyRunHowTo(),
    'stormfront': StormfrontHowTo(), // --- bonus-briefing-clarity
  };

  /// The most the card may take (the caller ends it above the ship row).
  final double maxHeight;
  final VoidCallback? onDismiss;

  /// The card's frame and title colours: an alert amber no squad accent
  /// uses, so the card reads as exceptional at a glance.
  static const frame = Color(0xFFFFA94D), titleColor = Color(0xFFFFD86B);

  /// Below these heights the card drops the older chatter, then the
  /// portrait shrinks to the dock's toast size.
  static const roomy = 200.0, tight = 150.0;

  @override
  Widget build(BuildContext context) {
    final reduce = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    final b = briefing;
    final opacity = b.opacity(now, reduce: reduce);
    if (opacity <= 0) return const SizedBox.shrink();
    final current = b.current();
    final who = current?.character ?? commsCast[b.invite.speaker];
    final spoken = b.spoken();
    final keep = maxHeight >= roomy
        ? 3
        : maxHeight >= tight
        ? 2
        : 1;
    final chatter = spoken.length > keep
        ? spoken.sublist(spoken.length - keep)
        : spoken;
    final portrait = maxHeight >= tight ? 56.0 : CommsHudStack.portrait;
    // A slow glow on the frame while the card is up (none with reduced
    // motion: a steady frame).
    final glow = reduce || !b.open
        ? .55
        : .45 + .25 * (.5 + .5 * math.sin(now * math.pi * 1.2));
    final rule = b.rule;
    return Semantics(
      container: true,
      label:
          '${BonusBriefing.title} ${b.level.label}. ${b.brief} ${b.how}'
          '${rule == null ? '' : ' Run rule: $rule'}',
      child: Opacity(
        key: const ValueKey('bonus-briefing-card'),
        opacity: opacity,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onDismiss,
          child: ConstrainedBox(
            constraints: BoxConstraints(maxHeight: maxHeight),
            child: Container(
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0xF2201608), Color(0xEB0A1220)],
                ),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: frame.withValues(alpha: .6 + .4 * glow),
                  width: 1.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: frame.withValues(alpha: .35 * glow),
                    blurRadius: 10,
                  ),
                  const BoxShadow(
                    color: Color(0x8C000000),
                    blurRadius: 8,
                    offset: Offset(0, 2),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(7),
                child: Stack(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(9, 3, 9, 5),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _header(),
                          const SizedBox(height: 3),
                          _mission(who, current, portrait, reduce),
                          // --- mission-medals: the rule as a pictogram.
                          if (howTo[b.level.id] case final picture?
                              when maxHeight >= tight) ...[
                            const SizedBox(height: 4),
                            SizedBox(
                              key: const ValueKey('bonus-briefing-howto'),
                              height: 26,
                              child: CustomPaint(
                                painter: picture,
                                size: Size.infinite,
                              ),
                            ),
                          ],
                          if (chatter.isNotEmpty) ...[
                            const SizedBox(height: 4),
                            const SizedBox(
                              height: 1,
                              child: ColoredBox(color: Color(0x40FFA94D)),
                            ),
                            const SizedBox(height: 3),
                            // The newest turn stays in view: on a short
                            // screen the older ones scroll off the top
                            // (never past the card's bottom edge).
                            Flexible(
                              child: SingleChildScrollView(
                                reverse: true,
                                physics: const NeverScrollableScrollPhysics(),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                                    for (final m in chatter)
                                      _turn(m, identical(m, current)),
                                  ],
                                ),
                              ),
                            ),
                          ],
                          // --- mission-medals: the hold's prompt.
                          if (holding) ...[
                            const SizedBox(height: 3),
                            Align(
                              alignment: Alignment.centerRight,
                              child: Text(
                                'TAP TO START',
                                key: const ValueKey('bonus-briefing-start'),
                                style: TextStyle(
                                  color: titleColor.withValues(
                                    alpha: reduce
                                        ? 1
                                        : .65 +
                                              .35 * math.sin(now * math.pi * 2),
                                  ),
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 1.4,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    // The accent bars of a toast, both sides: the alert.
                    const Positioned(
                      top: 0,
                      bottom: 0,
                      left: 0,
                      width: 3,
                      child: ColoredBox(color: frame),
                    ),
                    const Positioned(
                      top: 0,
                      bottom: 0,
                      right: 0,
                      width: 3,
                      child: ColoredBox(color: frame),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _header() => Row(
    children: [
      const SizedBox(
        width: 14,
        height: 13,
        child: CustomPaint(painter: _AlertMark()),
      ),
      const SizedBox(width: 5),
      const Text(
        BonusBriefing.title,
        key: ValueKey('bonus-briefing-title'),
        maxLines: 1,
        style: TextStyle(
          color: titleColor,
          fontSize: 12.5,
          fontWeight: FontWeight.bold,
          letterSpacing: 1.4,
        ),
      ),
      const SizedBox(width: 8),
      Expanded(
        child: Text(
          briefing.level.label.toUpperCase(),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.right,
          style: const TextStyle(
            color: _text,
            fontSize: 10,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.2,
          ),
        ),
      ),
      Semantics(
        button: true,
        label: 'Dismiss the mission briefing',
        child: GestureDetector(
          key: const ValueKey('bonus-briefing-dismiss'),
          behavior: HitTestBehavior.opaque,
          onTap: onDismiss,
          child: const SizedBox(
            width: 28,
            height: 22,
            child: CustomPaint(painter: _CloseMark()),
          ),
        ),
      ),
    ],
  );

  Widget _mission(
    CommsCharacter? who,
    CommsMessage? current,
    double side,
    bool reduce,
  ) {
    final rule = briefing.rule;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (who != null)
          SizedBox(
            key: const ValueKey('bonus-briefing-portrait'),
            width: side,
            height: side,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(5),
              child: CustomPaint(
                painter: _BriefingPortrait(who, current, now, reduce),
              ),
            ),
          ),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // --- bonus-briefing-clarity: the goal, big and bold, then
              // how to do it in one plain line.
              if (briefing.brief.isNotEmpty)
                Text(
                  briefing.brief,
                  key: const ValueKey('bonus-briefing-brief'),
                  maxLines: maxHeight >= tight ? 2 : 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFFFFF4DC),
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    height: 1.15,
                  ),
                ),
              if (briefing.how.isNotEmpty) ...[
                const SizedBox(height: 2),
                Text(
                  briefing.how,
                  key: const ValueKey('bonus-briefing-how'),
                  maxLines: maxHeight >= tight ? 2 : 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: _text,
                    fontSize: 12.5,
                    height: 1.2,
                  ),
                ),
              ],
              if (rule != null) ...[
                const SizedBox(height: 3),
                Text.rich(
                  TextSpan(
                    children: [
                      const TextSpan(
                        text: 'RUN RULE  ',
                        style: TextStyle(
                          color: titleColor,
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1,
                        ),
                      ),
                      TextSpan(text: rule),
                    ],
                  ),
                  key: const ValueKey('bonus-briefing-rule'),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFFFFE2B0),
                    fontSize: 11,
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  /// One turn of the chatter: the speaker's tag in their colour and the
  /// line's own words (a brood turn: its glyphs and the SIGINT reading).
  Widget _turn(CommsMessage m, bool latest) {
    final c = m.character;
    final accent = Color(c.accent);
    final tag = c.isDemon ? c.name : c.callsign;
    final child = m.line.isGrunt
        ? Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '$tag  ',
                style: TextStyle(
                  color: accent,
                  fontSize: 9.5,
                  fontWeight: FontWeight.bold,
                  letterSpacing: .8,
                ),
              ),
              Expanded(
                child: CommsSubtitle(
                  message: m,
                  now: now,
                  fontSize: 13,
                  maxLines: 2,
                  glyphHeight: 9,
                ),
              ),
            ],
          )
        : Text.rich(
            TextSpan(
              children: [
                TextSpan(
                  text: '$tag  ',
                  style: TextStyle(
                    color: accent,
                    fontSize: 9.5,
                    fontWeight: FontWeight.bold,
                    letterSpacing: .8,
                  ),
                ),
                TextSpan(text: m.line.text ?? ''),
              ],
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: _text, fontSize: 12.5, height: 1.2),
          );
    return Padding(
      key: ValueKey('bonus-briefing-turn-${m.line.id}'),
      padding: const EdgeInsets.only(bottom: 2),
      child: Opacity(opacity: latest ? 1 : .62, child: child),
    );
  }
}

/// The card's portrait: the current speaker over their backdrop, lit while
/// their turn is on air. A silent written turn keeps the mouth closed.
class _BriefingPortrait extends CustomPainter {
  _BriefingPortrait(this.who, this.m, this.now, this.reduce);
  final CommsCharacter who;
  final CommsMessage? m;
  final double now;
  final bool reduce;

  @override
  void paint(Canvas canvas, Size size) {
    final r = Offset.zero & size;
    canvas.save();
    canvas.clipRect(r);
    paintBackdrop(canvas, r, who, now, reduceMotion: reduce);
    final message = m;
    final talking = message != null && message.speaking(now);
    final frame = talking ? message.frame(now) : restFrame(now, who.id.length);
    final (from, _, amount) = talking
        ? message.mouthBlend(now)
        : (CommsFrame.idle, CommsFrame.idle, 1.0);
    paintPortrait(
      canvas,
      r,
      who.id,
      frame,
      small: size.width < commsPortraitCell * .5,
      accent: Color(who.accent),
      from: reduce ? null : from,
      amount: amount,
    );
    // A short burst of static as a new caller connects (a plain fade from
    // ink with reduced motion).
    final age = message?.age(now) ?? 1;
    if (age < .3) {
      final amount = 1 - age / .3;
      if (reduce) {
        canvas.drawRect(r, Paint()..color = _ink.withValues(alpha: amount));
      } else {
        paintStatic(canvas, r, now, amount * .7, who.id.length);
      }
    }
    paintScanlines(canvas, r);
    canvas.restore();
    canvas.drawRect(
      r.deflate(.5),
      Paint()
        ..style = PaintingStyle.stroke
        ..color = talking ? Color(who.accent) : _line,
    );
  }

  @override
  bool shouldRepaint(_BriefingPortrait old) => true;
}

/// The card's dismiss mark: a small painted cross (no font glyph needed).
class _CloseMark extends CustomPainter {
  const _CloseMark();

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    const h = 4.0;
    final paint = Paint()
      ..color = _muted
      ..strokeWidth = 1.6
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(c.translate(-h, -h), c.translate(h, h), paint);
    canvas.drawLine(c.translate(h, -h), c.translate(-h, h), paint);
  }

  @override
  bool shouldRepaint(_CloseMark old) => false;
}

/// The alert triangle before the title (painted: no font glyph needed).
class _AlertMark extends CustomPainter {
  const _AlertMark();

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    final tri = Path()
      ..moveTo(w / 2, .5)
      ..lineTo(w - .5, h - .5)
      ..lineTo(.5, h - .5)
      ..close();
    canvas.drawPath(tri, Paint()..color = BonusBriefingCard.titleColor);
    final ink = Paint()
      ..color = const Color(0xFF201608)
      ..strokeWidth = 1.6
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(Offset(w / 2, h * .38), Offset(w / 2, h * .66), ink);
    canvas.drawCircle(Offset(w / 2, h * .82), .9, ink);
  }

  @override
  bool shouldRepaint(_AlertMark old) => false;
}

/// mission-medals: Supply Run's rule as a strip of five small pictures,
/// in the colours of the level's own cues: a crate in gold target
/// brackets, three shots, the crate bursting, the cargo falling on its
/// dotted line, the ship under it on its landing marker.
class SupplyRunHowTo extends CustomPainter {
  const SupplyRunHowTo();

  static const _gold = Color(0xFFFFD27A), _mint = Color(0xFF70F5D5);
  static const _crate = Color(0xFF23364A), _edge = Color(0xFF5B7894);

  @override
  void paint(Canvas canvas, Size size) {
    final cy = size.height / 2;
    const step = 34.0;
    var x = 12.0;
    final stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;
    void crate(Offset c, {bool cracked = false}) {
      final r = Rect.fromCenter(center: c, width: 12, height: 10);
      canvas.drawRect(r, Paint()..color = _crate);
      canvas.drawRect(r, stroke..color = _edge);
      if (cracked) {
        canvas.drawLine(
          c.translate(-6, -3),
          c.translate(1, 5),
          stroke..color = _gold,
        );
      }
    }

    void arrow(double ax) {
      final p = Path()
        ..moveTo(ax - 2, cy - 3)
        ..lineTo(ax + 1, cy)
        ..lineTo(ax - 2, cy + 3);
      canvas.drawPath(p, stroke..color = const Color(0x99FFE2B0));
    }

    // 1. The crate on its parachute, in target brackets.
    final c1 = Offset(x, cy + 3);
    canvas.drawArc(
      Rect.fromCenter(center: c1.translate(0, -9), width: 16, height: 10),
      math.pi,
      math.pi,
      true,
      Paint()..color = const Color(0xFFF0F5FA),
    );
    crate(c1);
    final box = Rect.fromCenter(center: c1, width: 18, height: 16);
    stroke.color = _gold;
    for (final (corner, dx, dy) in [
      (box.topLeft, 1.0, 1.0),
      (box.topRight, -1.0, 1.0),
      (box.bottomLeft, 1.0, -1.0),
      (box.bottomRight, -1.0, -1.0),
    ]) {
      canvas.drawLine(corner, corner + Offset(3 * dx, 0), stroke);
      canvas.drawLine(corner, corner + Offset(0, 3 * dy), stroke);
    }
    arrow(x + step / 2);
    x += step;
    // 2. Three shots.
    for (var i = 0; i < 3; i++) {
      final sx = x - 5 + i * 5.0;
      canvas.drawLine(
        Offset(sx, cy + 6 - i * 2.0),
        Offset(sx, cy - 2 - i * 2.0),
        Paint()
          ..color = _mint
          ..strokeWidth = 1.6,
      );
    }
    arrow(x + step / 2);
    x += step;
    // 3. The crate bursts.
    crate(Offset(x, cy), cracked: true);
    canvas.drawCircle(
      Offset(x, cy),
      10,
      Paint()
        ..color = _gold.withValues(alpha: .8)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.4,
    );
    arrow(x + step / 2);
    x += step;
    // 4. The cargo falls on its dotted line.
    canvas.drawCircle(
      Offset(x, cy - 6),
      4,
      Paint()..color = _mint.withValues(alpha: .9),
    );
    for (var y = cy - 1; y < cy + 10; y += 3.5) {
      canvas.drawCircle(Offset(x, y), .8, Paint()..color = _mint);
    }
    arrow(x + step / 2);
    x += step;
    // 5. The ship catches it on its marker.
    final ship = Path()
      ..moveTo(x, cy - 7)
      ..lineTo(x + 6, cy + 5)
      ..lineTo(x, cy + 2)
      ..lineTo(x - 6, cy + 5)
      ..close();
    canvas.drawPath(ship, Paint()..color = const Color(0xFF8FE6FF));
    canvas.drawOval(
      Rect.fromCenter(center: Offset(x, cy + 9), width: 16, height: 5),
      stroke..color = _mint,
    );
  }

  @override
  bool shouldRepaint(SupplyRunHowTo old) => false;
}

/// bonus-briefing-clarity: Stormfront's rule as a strip of four small
/// pictures, in the level's own colours: a demon over the ship, the amber
/// mark blinking under the ship, the ship sliding away, the bolt striking
/// the demon where the ship was.
class StormfrontHowTo extends CustomPainter {
  const StormfrontHowTo();

  static const _amber = Color(0xFFFFB45A), _bolt = Color(0xFFFFFFFF);
  static const _halo = Color(0xFFCFC4FF), _demon = Color(0xFFB07CFF);
  static const _ship = Color(0xFF8FE6FF);

  @override
  void paint(Canvas canvas, Size size) {
    final h = size.height;
    const step = 42.0;
    final stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;
    void demon(double x, {bool hit = false}) {
      final c = Offset(x, 5);
      final body = Path()
        ..moveTo(c.dx - 7, c.dy - 1)
        ..lineTo(c.dx - 3, c.dy - 4)
        ..lineTo(c.dx + 3, c.dy - 4)
        ..lineTo(c.dx + 7, c.dy - 1)
        ..lineTo(c.dx + 3, c.dy + 3)
        ..lineTo(c.dx - 3, c.dy + 3)
        ..close();
      canvas.drawPath(
        body,
        Paint()..color = hit ? _halo.withValues(alpha: .7) : _demon,
      );
    }

    void ship(double x) {
      final p = Path()
        ..moveTo(x, h - 12)
        ..lineTo(x + 5, h - 3)
        ..lineTo(x, h - 5)
        ..lineTo(x - 5, h - 3)
        ..close();
      canvas.drawPath(p, Paint()..color = _ship);
    }

    void mark(double x) {
      final y = h - 1.5;
      stroke.color = _amber;
      canvas
        ..drawLine(Offset(x - 6, y), Offset(x + 6, y), stroke)
        ..drawLine(Offset(x - 6, y), Offset(x - 6, y - 3), stroke)
        ..drawLine(Offset(x + 6, y), Offset(x + 6, y - 3), stroke);
    }

    void arrow(double ax) {
      final cy = h / 2;
      final p = Path()
        ..moveTo(ax - 2, cy - 3)
        ..lineTo(ax + 1, cy)
        ..lineTo(ax - 2, cy + 3);
      canvas.drawPath(p, stroke..color = const Color(0x99FFE2B0));
    }

    var x = 14.0;
    // 1. The ship sits under a demon.
    demon(x);
    ship(x);
    arrow(x + step / 2);
    x += step;
    // 2. The amber mark blinks under the ship.
    demon(x);
    ship(x);
    mark(x);
    arrow(x + step / 2);
    x += step;
    // 3. The ship slides away; the mark stays.
    demon(x - 6);
    mark(x - 6);
    ship(x + 8);
    stroke.color = _ship.withValues(alpha: .6);
    canvas.drawLine(Offset(x - 3, h - 7), Offset(x + 2, h - 7), stroke);
    arrow(x + step / 2);
    x += step;
    // 4. The bolt strikes the demon where the ship was.
    final bolt = Path()
      ..moveTo(x, 0)
      ..lineTo(x - 3, h * .35)
      ..lineTo(x + 2, h * .5)
      ..lineTo(x - 1, h - 2);
    canvas.drawPath(
      bolt,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..color = _halo.withValues(alpha: .5),
    );
    canvas.drawPath(
      bolt,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2
        ..color = _bolt,
    );
    demon(x, hit: true);
    ship(x + 14);
  }

  @override
  bool shouldRepaint(StormfrontHowTo old) => false;
}
