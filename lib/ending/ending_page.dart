import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'credits_view.dart';

/// The battle pulls back into a board game among friends. This route owns no
/// game state: its caller preserves the run while the reveal/credits are open.
/// The credits never scroll by themselves (credits-page): the reader scrolls.
class EndingPage extends StatefulWidget {
  const EndingPage({super.key, this.creditsOnly = false, this.onAudioResume});
  final bool creditsOnly;
  final VoidCallback? onAudioResume;

  @override
  State<EndingPage> createState() => _EndingPageState();
}

class _EndingPageState extends State<EndingPage>
    with TickerProviderStateMixin, WidgetsBindingObserver {
  late final AnimationController _reveal = AnimationController(vsync: this)
    ..addStatusListener((status) {
      if (status == AnimationStatus.completed) _showCredits();
    });
  late final Future<Map<String, dynamic>> _data = rootBundle
      .loadString('assets/credits.json')
      .then((raw) => jsonDecode(raw) as Map<String, dynamic>);
  late bool _credits = widget.creditsOnly;
  bool _started = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    _reveal.duration = Duration(
      seconds: MediaQuery.disableAnimationsOf(context) ? 3 : 8,
    );
    if (!_credits) _reveal.forward();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) {
      _reveal.stop();
    } else {
      widget.onAudioResume?.call();
      if (!_credits) _reveal.forward();
    }
  }

  void _showCredits() {
    if (!mounted || _credits) return;
    _reveal.stop();
    setState(() => _credits = true);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _reveal.dispose();
    super.dispose();
  }

  void _close() => Navigator.of(context).maybePop();

  @override
  Widget build(BuildContext context) {
    final reduce = MediaQuery.disableAnimationsOf(context);
    return CallbackShortcuts(
      bindings: {const SingleActivator(LogicalKeyboardKey.escape): _close},
      child: Focus(
        autofocus: true,
        child: Scaffold(
          backgroundColor: const Color(0xFF090D18),
          body: SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 6,
                  ),
                  child: Row(
                    children: [
                      const Expanded(
                        child: Text(
                          'DEMON / ATTACK',
                          style: TextStyle(
                            color: Color(0xFF39DFCC),
                            fontSize: 11,
                            letterSpacing: 2,
                          ),
                        ),
                      ),
                      if (!_credits)
                        TextButton(
                          key: const ValueKey('ending-skip'),
                          onPressed: _showCredits,
                          child: const Text('SKIP REVEAL'),
                        ),
                      TextButton(
                        key: const ValueKey('ending-close'),
                        onPressed: _close,
                        child: Text(widget.creditsOnly ? 'CLOSE' : 'CONTINUE'),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: _credits ? CreditsView(data: _data) : _beach(reduce),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _beach(bool reduce) => AnimatedBuilder(
    animation: _reveal,
    builder: (context, _) {
      final t = _reveal.value;
      final pullback = reduce
          ? 1.0
          : Curves.easeInOutCubic.transform((t / .75).clamp(0.0, 1.0));
      return Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Expanded(
            child: Center(
              child: Semantics(
                label:
                    'Teenage human and demon friends share burgers, fries and sodas '
                    'while playing a space battle board game on a San Diego beach.',
                image: true,
                child: AspectRatio(
                  aspectRatio: 1.6,
                  child: ClipRect(
                    child: Transform.scale(
                      scale: 3.6 - 2.6 * pullback,
                      alignment: const Alignment(.02, .3),
                      child: Image.asset(
                        'assets/images/beach-ending.webp',
                        key: const ValueKey('beach-reveal-image'),
                        fit: BoxFit.cover,
                        filterQuality: FilterQuality.none,
                        excludeFromSemantics: true,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 24),
          Opacity(
            opacity: reduce ? 1 : ((t - .6) / .2).clamp(0.0, 1.0),
            child: const Padding(
              padding: EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                children: [
                  Text(
                    'SAN DIEGO · AFTER THE LAST TURN',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Color(0xFFFFD477),
                      fontSize: 12,
                      letterSpacing: 1.5,
                    ),
                  ),
                  SizedBox(height: 12),
                  Text(
                    'Same friends. Next round?',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Color(0xFFE6EEF6), fontSize: 16),
                  ),
                ],
              ),
            ),
          ),
        ],
      );
    },
  );
}
