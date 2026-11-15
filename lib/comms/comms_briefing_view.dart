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
  });
  final BonusBriefing briefing;
  final double now;

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
          '${BonusBriefing.title} ${b.level.label}. ${b.brief}'
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
              if (briefing.brief.isNotEmpty)
                Text(
                  briefing.brief,
                  key: const ValueKey('bonus-briefing-brief'),
                  maxLines: maxHeight >= tight ? 3 : 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: _text,
                    fontSize: 12.5,
                    height: 1.2,
                  ),
                ),
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
