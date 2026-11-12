import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/scheduler.dart';

/// The battle pulls back into a board game among friends. This route owns no
/// game state: its caller preserves the run while the reveal/credits are open.
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
  late final Ticker _roll = createTicker(_scroll);
  final _scrollController = ScrollController();
  late final Future<Map<String, dynamic>> _data = rootBundle
      .loadString('assets/credits.json')
      .then((raw) => jsonDecode(raw) as Map<String, dynamic>);
  late bool _credits = widget.creditsOnly;
  bool _started = false, _holding = false, _background = false, _auto = true;
  Duration? _lastFrame;

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
    if (_credits) {
      if (_auto && !MediaQuery.disableAnimationsOf(context)) _roll.start();
    } else {
      _reveal.forward();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _background = state != AppLifecycleState.resumed;
    _lastFrame = null;
    if (_background) {
      _reveal.stop();
      if (_roll.isActive) _roll.stop();
    } else {
      widget.onAudioResume?.call();
      if (_credits) {
        if (_auto &&
            !MediaQuery.disableAnimationsOf(context) &&
            !_roll.isActive) {
          _roll.start();
        }
      } else {
        _reveal.forward();
      }
    }
  }

  void _showCredits() {
    if (!mounted || _credits) return;
    _reveal.stop();
    setState(() => _credits = true);
    if (_auto && !MediaQuery.disableAnimationsOf(context) && !_roll.isActive) {
      _roll.start();
    }
  }

  void _scroll(Duration elapsed) {
    final previous = _lastFrame;
    _lastFrame = elapsed;
    if (previous == null ||
        !_credits ||
        !_auto ||
        _holding ||
        _background ||
        MediaQuery.disableAnimationsOf(context) ||
        !_scrollController.hasClients) {
      return;
    }
    final dt = ((elapsed - previous).inMicroseconds / 1e6).clamp(0.0, .05);
    final position = _scrollController.position;
    final next = math.min(position.maxScrollExtent, position.pixels + dt * 20);
    if (next > position.pixels) _scrollController.jumpTo(next);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _reveal.dispose();
    _roll.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _close() => Navigator.of(context).maybePop();

  void _toggleAuto() {
    setState(() => _auto = !_auto);
    _lastFrame = null;
    if (_auto && !_background && !MediaQuery.disableAnimationsOf(context)) {
      if (!_roll.isActive) _roll.start();
    } else if (_roll.isActive) {
      _roll.stop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final reduce = MediaQuery.disableAnimationsOf(context);
    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.escape): _close,
        const SingleActivator(LogicalKeyboardKey.space): _toggleAuto,
      },
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
                  child: _credits ? _creditsBody(reduce) : _beach(reduce),
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

  Widget _creditsBody(bool reduce) => FutureBuilder<Map<String, dynamic>>(
    future: _data,
    builder: (context, snapshot) {
      if (snapshot.hasError) {
        return const Center(child: Text('Credits could not be loaded.'));
      }
      if (!snapshot.hasData) {
        return const Center(child: CircularProgressIndicator());
      }
      final data = snapshot.data!;
      final sections = data['sections'] as List;
      return Column(
        children: [
          Expanded(
            child: Listener(
              onPointerDown: (_) => _holding = true,
              onPointerUp: (_) => _holding = false,
              onPointerCancel: (_) => _holding = false,
              child: Scrollbar(
                controller: _scrollController,
                child: SingleChildScrollView(
                  key: const ValueKey('credits-scroll'),
                  controller: _scrollController,
                  padding: const EdgeInsets.fromLTRB(24, 40, 24, 80),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 600),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const Text(
                            'BUILT USING',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 12,
                              color: Color(0xFF8DA0B5),
                              letterSpacing: 3,
                            ),
                          ),
                          const SizedBox(height: 10),
                          Text(
                            data['platform'] as String,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 30,
                              color: Color(0xFF39DFCC),
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 50),
                          for (final raw in sections)
                            _creditSection(raw as Map<String, dynamic>),
                          const SizedBox(height: 38),
                          Text(
                            data['source_license'] as String,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: Color(0xFF8DA0B5),
                              fontSize: 11,
                            ),
                          ),
                          const SizedBox(height: 24),
                          const Text(
                            'Thanks for keeping the sky interesting.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Color(0xFFFFD477),
                              fontSize: 17,
                            ),
                          ),
                          const SizedBox(height: 24),
                          TextButton(
                            onPressed: () => showLicensePage(
                              context: context,
                              applicationName: 'Demon Attack',
                            ),
                            child: const Text('PACKAGE LICENSES'),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          if (!reduce)
            TextButton(
              key: const ValueKey('credits-auto-scroll'),
              onPressed: _toggleAuto,
              child: Text(_auto ? 'PAUSE SCROLL' : 'RESUME SCROLL'),
            ),
        ],
      );
    },
  );

  Widget _creditSection(Map<String, dynamic> section) {
    final indirect = section['degree'] == 'indirect';
    return Padding(
      padding: const EdgeInsets.only(bottom: 34),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            (section['title'] as String).toUpperCase(),
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Color(0xFFFFD477),
              letterSpacing: 1.5,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 16),
          for (final raw in section['entries'] as List)
            Padding(
              padding: const EdgeInsets.only(bottom: 9),
              child: Text(
                [
                  raw['name'],
                  raw['version'],
                  raw['license'],
                ].whereType<String>().join(' · '),
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: indirect
                      ? const Color(0xFF9AADC0)
                      : const Color(0xFFE6EEF6),
                  fontSize: indirect ? 12 : 15,
                  height: 1.35,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
