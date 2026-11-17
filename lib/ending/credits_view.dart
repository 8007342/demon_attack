import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

// --- credits-page: a calm, still credits page the reader scrolls. It renders
// every row of assets/credits.json (tools/generate_credits.lua): the creator,
// the "built on" cards (Tillandsias, Fedora, Podman), the source link, then
// the models, licences, sample libraries, open-source projects and packages.

const _ink = Color(0xFFE6EEF6);
const _muted = Color(0xFF9AADC0);
const _faint = Color(0xFF8DA0B5);
const _gold = Color(0xFFFFD477);
const _teal = Color(0xFF39DFCC);
const _card = Color(0xFF111A2B);
const _edge = Color(0xFF223450);

/// The credits body. Nothing moves on its own: no auto-scroll, no ticker.
class CreditsView extends StatefulWidget {
  const CreditsView({super.key, required this.data});
  final Future<Map<String, dynamic>> data;

  @override
  State<CreditsView> createState() => _CreditsViewState();
}

class _CreditsViewState extends State<CreditsView> {
  final _scroll = ScrollController();
  final _focus = FocusNode(debugLabel: 'credits');
  bool _focused = false;

  @override
  void dispose() {
    _focus.dispose();
    _scroll.dispose();
    super.dispose();
  }

  /// Keyboard reading: arrows step a line, Page Up/Down a screen, Home/End.
  void _by(double delta) {
    if (!_scroll.hasClients) return;
    final p = _scroll.position;
    final to = (p.pixels + delta).clamp(p.minScrollExtent, p.maxScrollExtent);
    if (MediaQuery.disableAnimationsOf(context)) {
      _scroll.jumpTo(to);
    } else {
      _scroll.animateTo(
        to,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
      );
    }
  }

  double get _page =>
      _scroll.hasClients ? _scroll.position.viewportDimension * .85 : 400;

  @override
  Widget build(BuildContext context) => FutureBuilder<Map<String, dynamic>>(
    future: widget.data,
    builder: (context, snapshot) {
      if (snapshot.hasError) {
        return const Center(child: Text('Credits could not be loaded.'));
      }
      if (!snapshot.hasData) {
        return const Center(child: Text('LOADING CREDITS…'));
      }
      final data = snapshot.data!;
      final sections = (data['sections'] as List).cast<Map<String, dynamic>>();
      final cards = (data['built_on'] as List? ?? const [])
          .cast<Map<String, dynamic>>();
      final wide = MediaQuery.sizeOf(context).width >= 600;
      // The keys read the credits once they are on screen (Escape still
      // reaches the page around them).
      if (!_focused) {
        _focused = true;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _focus.requestFocus();
        });
      }
      return CallbackShortcuts(
        bindings: {
          const SingleActivator(LogicalKeyboardKey.arrowDown): () => _by(48),
          const SingleActivator(LogicalKeyboardKey.arrowUp): () => _by(-48),
          const SingleActivator(LogicalKeyboardKey.pageDown): () => _by(_page),
          const SingleActivator(LogicalKeyboardKey.pageUp): () => _by(-_page),
          const SingleActivator(LogicalKeyboardKey.space): () => _by(_page),
          const SingleActivator(LogicalKeyboardKey.home): () => _by(-1e9),
          const SingleActivator(LogicalKeyboardKey.end): () => _by(1e9),
        },
        child: Focus(
          focusNode: _focus,
          child: Scrollbar(
            controller: _scroll,
            thumbVisibility: wide,
            child: SingleChildScrollView(
              key: const ValueKey('credits-scroll'),
              controller: _scroll,
              padding: EdgeInsets.fromLTRB(
                wide ? 32 : 16,
                wide ? 32 : 20,
                wide ? 32 : 16,
                64,
              ),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 720),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Text(
                        'CREDITS',
                        key: ValueKey('credits-title'),
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 13,
                          color: _faint,
                          letterSpacing: 4,
                        ),
                      ),
                      SizedBox(height: wide ? 18 : 10),
                      for (final s in sections)
                        if (s['degree'] == 'creator') _creatorLine(s, wide),
                      SizedBox(height: wide ? 28 : 18),
                      if (cards.isNotEmpty) ...[
                        const _Heading('Built on'),
                        SizedBox(height: wide ? 14 : 10),
                        _BuiltOnCards(cards: cards, wide: wide),
                        SizedBox(height: wide ? 18 : 12),
                      ],
                      if (data['source_url'] case final String url)
                        Center(
                          child: _SourceLink(
                            url: url,
                            label: data['source_label'] as String? ?? url,
                          ),
                        ),
                      if (data['trademark_note'] case final String note) ...[
                        const SizedBox(height: 12),
                        Text(
                          note,
                          key: const ValueKey('credits-trademark-note'),
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: _faint,
                            fontSize: 11,
                            height: 1.4,
                          ),
                        ),
                      ],
                      const SizedBox(height: 44),
                      for (final (i, s) in sections.indexed)
                        if (s['degree'] != 'creator') _section(i, s),
                      const SizedBox(height: 18),
                      Text(
                        data['source_license'] as String,
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: _faint, fontSize: 11),
                      ),
                      const SizedBox(height: 24),
                      const Text(
                        'Thanks for keeping the sky interesting.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: _gold, fontSize: 17),
                      ),
                      const SizedBox(height: 24),
                      Center(
                        child: TextButton(
                          onPressed: () => showLicensePage(
                            context: context,
                            applicationName: 'Demon Attack',
                          ),
                          child: const Text('PACKAGE LICENSES'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    },
  );

  /// One section: a heading, then each entry as its name (a link when it has
  /// a page) over a quieter line of version, licence and where it was used.
  Widget _section(int index, Map<String, dynamic> section) {
    final quiet = section['degree'] == 'indirect';
    final entries = (section['entries'] as List).cast<Map<String, dynamic>>();
    return Padding(
      key: ValueKey('credits-section-$index'),
      padding: const EdgeInsets.only(bottom: 36),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _Heading(section['title'] as String),
          const SizedBox(height: 14),
          for (final (j, e) in entries.indexed)
            Padding(
              key: ValueKey('credits-row-$index-$j'),
              padding: const EdgeInsets.only(bottom: 10),
              child: Column(
                children: [
                  _CreditLink(
                    label: e['name'] as String,
                    url: e['url'] as String?,
                    style: TextStyle(
                      color: quiet ? _muted : _ink,
                      fontSize: quiet ? 13 : 15,
                      height: 1.35,
                    ),
                  ),
                  if (_detail(e) case final String detail)
                    Text(
                      detail,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: _faint,
                        fontSize: 11.5,
                        height: 1.35,
                      ),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  static String? _detail(Map<String, dynamic> e) {
    final parts = [
      e['version'],
      e['license'],
      e['source'],
    ].whereType<String>().where((s) => s.isNotEmpty).toList();
    return parts.isEmpty ? null : parts.join(' · ');
  }

  /// The creator line: "By `names`, with love", each name a link when it has
  /// a home page.
  Widget _creatorLine(Map<String, dynamic> section, bool wide) {
    final style = TextStyle(color: _ink, fontSize: wide ? 22 : 19, height: 1.3);
    final entries = (section['entries'] as List).cast<Map<String, dynamic>>();
    return Column(
      key: const ValueKey('credits-creator'),
      children: [
        Wrap(
          alignment: WrapAlignment.center,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Text(section['lead'] as String? ?? '', style: style),
            for (final (i, e) in entries.indexed) ...[
              if (i > 0) Text(' & ', style: style),
              _CreditLink(
                key: ValueKey('credits-link-${e['name']}'),
                label: e['name'] as String,
                url: e['url'] as String?,
                style: style.copyWith(
                  color: _gold,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
            Text(section['tail'] as String? ?? '', style: style),
          ],
        ),
        if (section['alongside'] case final Map<String, dynamic> alongside)
          Padding(
            key: const ValueKey('credits-alongside'),
            padding: const EdgeInsets.only(top: 10),
            child: Wrap(
              alignment: WrapAlignment.center,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text(
                  alongside['lead'] as String? ?? '',
                  style: const TextStyle(color: _muted, fontSize: 14),
                ),
                _CreditLink(
                  key: const ValueKey('credits-link-alongside'),
                  label: alongside['name'] as String,
                  url: alongside['url'] as String?,
                  style: const TextStyle(color: _teal, fontSize: 14),
                ),
                Text(
                  alongside['tail'] as String? ?? '',
                  style: const TextStyle(color: _muted, fontSize: 14),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _Heading extends StatelessWidget {
  const _Heading(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Text(
    text.toUpperCase(),
    textAlign: TextAlign.center,
    style: const TextStyle(color: _gold, letterSpacing: 1.5, fontSize: 12),
  );
}

/// Tillandsias, Fedora and Podman: three cards in a row on wide screens, a
/// stack on phones. Each opens its project's website.
class _BuiltOnCards extends StatelessWidget {
  const _BuiltOnCards({required this.cards, required this.wide});
  final List<Map<String, dynamic>> cards;
  final bool wide;

  @override
  Widget build(BuildContext context) {
    final tiles = [for (final c in cards) _BuiltOnCard(card: c, wide: wide)];
    if (!wide) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final (i, t) in tiles.indexed) ...[
            if (i > 0) const SizedBox(height: 8),
            t,
          ],
        ],
      );
    }
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final (i, t) in tiles.indexed) ...[
            if (i > 0) const SizedBox(width: 12),
            Expanded(child: t),
          ],
        ],
      ),
    );
  }
}

class _BuiltOnCard extends StatelessWidget {
  const _BuiltOnCard({required this.card, required this.wide});
  final Map<String, dynamic> card;
  final bool wide;

  @override
  Widget build(BuildContext context) {
    final name = card['name'] as String;
    final url = card['url'] as String;
    final icon = _icon(card);
    final text = Column(
      crossAxisAlignment: wide
          ? CrossAxisAlignment.center
          : CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          name,
          style: TextStyle(
            color: _ink,
            fontSize: wide ? 18 : 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        SizedBox(height: wide ? 4 : 2),
        Text(
          card['blurb'] as String? ?? '',
          textAlign: wide ? TextAlign.center : TextAlign.start,
          style: const TextStyle(color: _muted, fontSize: 12.5, height: 1.4),
        ),
        SizedBox(height: wide ? 6 : 3),
        Text(
          Uri.parse(url).host,
          style: const TextStyle(
            color: _teal,
            fontSize: 12,
            decoration: TextDecoration.underline,
            decorationColor: Color(0x9939DFCC),
          ),
        ),
      ],
    );
    return Semantics(
      link: true,
      label: '$name website',
      child: Material(
        color: _card,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: _edge),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          key: ValueKey('credits-card-$name'),
          onTap: () => launchUrl(Uri.parse(url), webOnlyWindowName: '_blank'),
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: 14,
              vertical: wide ? 14 : 9,
            ),
            child: wide
                ? Column(children: [icon, const SizedBox(height: 10), text])
                : Row(
                    children: [
                      icon,
                      const SizedBox(width: 14),
                      Expanded(child: text),
                    ],
                  ),
          ),
        ),
      ),
    );
  }

  /// The project's own icon where its rules allow it (Tillandsias), else a
  /// neutral glyph that does not imitate any mark (credits-page design §2).
  static Widget _icon(Map<String, dynamic> card) {
    const size = 44.0;
    if (card['icon'] case final String asset) {
      return Image.asset(
        asset,
        key: ValueKey('credits-icon-${card['name']}'),
        width: size,
        height: size,
        filterQuality: FilterQuality.medium,
        excludeFromSemantics: true,
      );
    }
    final glyph = switch (card['glyph']) {
      'desktop' => Icons.desktop_windows_outlined,
      'container' => Icons.inventory_2_outlined,
      _ => Icons.extension_outlined,
    };
    return SizedBox(
      width: size,
      height: size,
      child: Icon(
        glyph,
        key: ValueKey('credits-icon-${card['name']}'),
        size: 34,
        color: _teal,
      ),
    );
  }
}

class _SourceLink extends StatelessWidget {
  const _SourceLink({required this.url, required this.label});
  final String url;
  final String label;

  @override
  Widget build(BuildContext context) => Semantics(
    link: true,
    label: 'Source code on GitHub',
    child: OutlinedButton.icon(
      key: const ValueKey('credits-source-link'),
      onPressed: () => launchUrl(Uri.parse(url), webOnlyWindowName: '_blank'),
      icon: const Icon(Icons.code, size: 18, color: _teal),
      label: Text(
        'Source code · $label',
        style: const TextStyle(color: _ink, fontSize: 13),
      ),
      style: OutlinedButton.styleFrom(
        side: const BorderSide(color: _edge),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      ),
    ),
  );
}

/// A credit that opens its page in a new tab; plain text without a [url].
class _CreditLink extends StatelessWidget {
  const _CreditLink({
    super.key,
    required this.label,
    required this.url,
    required this.style,
  });
  final String label;
  final String? url;
  final TextStyle style;

  @override
  Widget build(BuildContext context) {
    final target = url == null ? null : Uri.tryParse(url!);
    if (target == null) {
      return Text(label, textAlign: TextAlign.center, style: style);
    }
    return Semantics(
      link: true,
      child: InkWell(
        borderRadius: BorderRadius.circular(6),
        onTap: () => launchUrl(target, webOnlyWindowName: '_blank'),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 2),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: style.copyWith(
              decoration: TextDecoration.underline,
              decorationColor: style.color?.withValues(alpha: .5),
            ),
          ),
        ),
      ),
    );
  }
}
