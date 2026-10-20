import 'dart:math' as math;
import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'game/model.dart';
import 'game/scene.dart';
import 'services/audio.dart';
import 'services/scores.dart';
export 'game/scene.dart' show DemonScene;

void main() => runApp(const DemonAttackApp());

class DemonAttackApp extends StatelessWidget {
  const DemonAttackApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'Demon Attack',
    debugShowCheckedModeBanner: false,
    theme: ThemeData(
      brightness: Brightness.dark,
      scaffoldBackgroundColor: ink,
      fontFamily: 'monospace',
      colorScheme: const ColorScheme.dark(
        primary: mint,
        secondary: gold,
        surface: Color(0xFF101A29),
      ),
      textTheme: const TextTheme(
        bodyMedium: TextStyle(color: Color(0xFFD7E5EF)),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: mint,
          foregroundColor: ink,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 21),
          shape: const RoundedRectangleBorder(),
          textStyle: const TextStyle(
            fontFamily: 'monospace',
            fontWeight: FontWeight.bold,
            fontSize: 12,
            letterSpacing: 2,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: const Color(0xFFD7E5EF),
          side: const BorderSide(color: Color(0xFF33485A)),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          shape: const RoundedRectangleBorder(),
          textStyle: const TextStyle(
            fontFamily: 'monospace',
            fontSize: 11,
            letterSpacing: 2,
          ),
        ),
      ),
    ),
    home: const ArcadePage(),
  );
}

class ArcadePage extends StatefulWidget {
  const ArcadePage({super.key, this.scoreService});
  final ScoreService? scoreService;
  @override
  State<ArcadePage> createState() => _ArcadePageState();
}

class _ArcadePageState extends State<ArcadePage> with WidgetsBindingObserver {
  final model = ArcadeModel();
  late final DemonScene scene;
  final focus = FocusNode();
  late final scores = widget.scoreService ?? ScoreService();
  bool muted = false, loading = false, submitted = false;
  String? screen, error;
  List<ScoreEntry> board = [];
  final initials = [0, 0, 0];
  final wheels = List.generate(
    3,
    (_) => FixedExtentScrollController(initialItem: 3600),
  );
  final alphabet = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
  final keys = <LogicalKeyboardKey>{};
  int? touch;
  double touchPosition = .5;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    scene = DemonScene(model, _tick);
    audioCue('menu', 1, 1, 0);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    focus.dispose();
    scores.close();
    for (final wheel in wheels) {
      wheel.dispose();
    }
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) {
      model.pause();
      keys.clear();
      scene.keyboardDirection = 0;
      audioPause();
    }
  }

  void _tick() {
    if (!mounted) return;
    for (final event in model.takeEvents()) {
      switch (event) {
        case 'level':
          audioCue('level', model.level, 1, model.cycle);
        case 'boss':
          audioCue(
            'boss',
            model.level,
            (model.boss?.phase ?? 0) + 1,
            model.cycle,
          );
        case 'levelclear':
          audioCue('levelclear', model.level, 1, model.cycle);
        case 'travel':
          audioCue('travel', model.level, 1, model.cycle);
        case 'victory':
          audioCue('victory', model.level, 1, model.cycle);
        case 'gameover':
          audioCue('gameover', model.level, 1, model.cycle);
        case 'pause':
          audioPause();
        case 'resume':
          audioResume();
        default:
          audioSfx(event);
      }
    }
    setState(() {});
  }

  void _start() {
    audioUnlock();
    audioResume();
    setState(() {
      screen = null;
      submitted = false;
      model.start();
    });
    focus.requestFocus();
  }

  void _title() {
    setState(() {
      screen = null;
      model.mode = RunMode.title;
      model.events.clear();
      keys.clear();
      scene.keyboardDirection = 0;
    });
    audioResume();
    audioCue('menu', 1, 1, 0);
    focus.requestFocus();
  }

  void _pause() {
    setState(() {
      if (model.mode == RunMode.paused) {
        model.resume();
      } else {
        model.pause();
      }
    });
    focus.requestFocus();
  }

  KeyEventResult _key(FocusNode node, KeyEvent event) {
    final key = event.logicalKey;
    if (key == LogicalKeyboardKey.arrowLeft ||
        key == LogicalKeyboardKey.arrowRight) {
      if (event is KeyUpEvent) {
        keys.remove(key);
      } else {
        keys.add(key);
      }
      scene.keyboardDirection =
          (keys.contains(LogicalKeyboardKey.arrowRight) ? 1 : 0) -
          (keys.contains(LogicalKeyboardKey.arrowLeft) ? 1 : 0).toDouble();
      return KeyEventResult.handled;
    }
    if (event is KeyDownEvent &&
        (key == LogicalKeyboardKey.escape || key == LogicalKeyboardKey.keyP)) {
      _pause();
      return KeyEventResult.handled;
    }
    if (event is KeyDownEvent &&
        key == LogicalKeyboardKey.enter &&
        model.mode == RunMode.title &&
        screen == null) {
      _start();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  Future<void> _loadScores({bool enter = false}) async {
    setState(() {
      screen = enter ? 'entry' : 'scores';
      loading = true;
      error = null;
    });
    try {
      final result = await scores.load();
      if (mounted) {
        setState(() {
          board = result;
          loading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          loading = false;
          error = 'The score relay is unavailable.';
        });
      }
    }
  }

  Future<void> _submit() async {
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final result = await scores.submit(
        initials.map((i) => alphabet[i]).join(),
        model.score,
      );
      if (mounted) {
        setState(() {
          board = result;
          loading = false;
          submitted = true;
          screen = 'scores';
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          loading = false;
          error = 'Transmission failed. Your score is ready to retry.';
        });
      }
    }
  }

  void _rotateInitial(int index, int delta) {
    final wheel = wheels[index];
    if (wheel.hasClients) {
      wheel.animateToItem(
        wheel.selectedItem + delta,
        duration: const Duration(milliseconds: 140),
        curve: Curves.easeOut,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final title = model.mode == RunMode.title;
    return Focus(
      focusNode: focus,
      autofocus: true,
      onKeyEvent: _key,
      onFocusChange: (hasFocus) {
        if (!hasFocus) {
          keys.clear();
          scene.keyboardDirection = 0;
        }
      },
      child: Scaffold(
        body: SafeArea(
          child: LayoutBuilder(
            builder: (context, bounds) {
              final wide = bounds.maxWidth > 760;
              return Stack(
                children: [
                  Positioned.fill(
                    child: ColoredBox(
                      color: ink,
                      child: Opacity(
                        opacity: title ? 1 : .38,
                        child: GameWidget(game: scene, autofocus: false),
                      ),
                    ),
                  ),
                  if (title)
                    Positioned.fill(
                      child: Container(
                        decoration: const BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Color(0x33080D18),
                              Color(0xAA080D18),
                              Color(0xF5080D18),
                            ],
                          ),
                        ),
                      ),
                    ),
                  if (title) _titleScreen(bounds),
                  if (!title)
                    Center(
                      child: SizedBox(
                        width: math.min(500, bounds.maxWidth),
                        child: _cabinet(bounds),
                      ),
                    ),
                  if (wide && !title)
                    Positioned(
                      left: 28,
                      top: 30,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _label('DEMON / ATTACK', mint),
                          const SizedBox(height: 12),
                          _label(
                            'KRYBOR DEFENSE SYSTEM',
                            const Color(0xFF6D8197),
                            size: 8,
                          ),
                          const SizedBox(height: 40),
                          _label('←  →   MOVE', const Color(0xFF8D9EB3)),
                          const SizedBox(height: 12),
                          _label('P / ESC   PAUSE', const Color(0xFF8D9EB3)),
                        ],
                      ),
                    ),
                  if (screen != null) Positioned.fill(child: _scoreOverlay()),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _titleScreen(BoxConstraints bounds) => Stack(
    children: [
      Positioned(
        top: 22,
        left: 24,
        right: 24,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _label('KRYBOR / DEFENSE SYSTEM', const Color(0xFF94A6B8), size: 9),
            _muteButton(),
          ],
        ),
      ),
      Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(30, 75, 30, 65),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _label('TRANSMISSION 001 · KRYBOR', mint, size: 9),
                const SizedBox(height: 24),
                _sprite(0, 0, 84),
                const SizedBox(height: 18),
                const FittedBox(
                  child: Text(
                    'DEMON',
                    style: TextStyle(
                      fontSize: 74,
                      height: .95,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 10,
                      color: Color(0xFFE9F2F2),
                    ),
                  ),
                ),
                const FittedBox(
                  child: Text(
                    'ATTACK',
                    style: TextStyle(
                      fontSize: 66,
                      height: 1.05,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 10,
                      color: mint,
                    ),
                  ),
                ),
                const SizedBox(height: 23),
                _label(
                  'THE SWARM IS ALIVE.',
                  const Color(0xFFA7B6C8),
                  size: 10,
                ),
                const SizedBox(height: 34),
                SizedBox(
                  width: 280,
                  child: FilledButton(
                    onPressed: _start,
                    child: const Text('START GAME  →'),
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: 280,
                  child: OutlinedButton(
                    onPressed: () => _loadScores(),
                    child: const Text('TOP 10 SCORES'),
                  ),
                ),
                const SizedBox(height: 30),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.swipe, size: 16, color: Color(0xFF6F8296)),
                    const SizedBox(width: 10),
                    _label(
                      'DRAG TO MOVE  /  ← →',
                      const Color(0xFF8D9EB3),
                      size: 9,
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                _label(
                  'AUTO FIRE · THREE LIVES · NO MERCY',
                  const Color(0xFF60758C),
                  size: 8,
                ),
              ],
            ),
          ),
        ),
      ),
      Positioned(
        bottom: 18,
        left: 24,
        right: 24,
        child: Row(
          children: [
            Expanded(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: _label(
                  'AN ARCADE REBORN',
                  const Color(0xFF52677E),
                  size: 8,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerRight,
                child: _label(
                  'PIXELS. INSTINCT. SURVIVAL.',
                  const Color(0xFF52677E),
                  size: 8,
                ),
              ),
            ),
          ],
        ),
      ),
    ],
  );
  Widget _cabinet(BoxConstraints bounds) {
    // Flame is rendered once behind this transparent arena; overlays stay in logical alignment.
    return Column(
      children: [
        Container(
          height: 62,
          padding: const EdgeInsets.symmetric(horizontal: 18),
          decoration: const BoxDecoration(
            color: Color(0xF0080D18),
            border: Border(bottom: BorderSide(color: Color(0xFF26394C))),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _label('SCORE', const Color(0xFF7B91A8), size: 8),
                    const SizedBox(height: 4),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(
                        model.score.toString().padLeft(6, '0'),
                        maxLines: 1,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 2,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _label(
                    'LV ${model.level.toString().padLeft(2, '0')} / RUN ${model.cycle + 1}',
                    mint,
                    size: 9,
                  ),
                  const SizedBox(height: 3),
                  _label(
                    model.level == 5
                        ? 'CARRIER'
                        : 'WAVE ${model.wave} / ${model.wavesPerLevel}',
                    const Color(0xFF839DB5),
                    size: 7,
                  ),
                  const SizedBox(height: 3),
                  Row(
                    children: List.generate(
                      3,
                      (i) => Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 2),
                        child: Icon(
                          Icons.favorite,
                          size: 12,
                          color: i < model.lives
                              ? const Color(0xFFFF8C89)
                              : const Color(0xFF29354A),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 12),
              _muteButton(),
              IconButton(
                tooltip: 'Pause game',
                onPressed: _pause,
                icon: const Icon(Icons.pause, size: 20),
              ),
            ],
          ),
        ),
        Expanded(
          child: LayoutBuilder(
            builder: (context, area) => Stack(
              children: [
                Positioned.fill(
                  child: ColoredBox(
                    color: ink,
                    child: GameWidget(game: _arenaProxy, autofocus: false),
                  ),
                ),
                if (model.power != null)
                  Positioned(
                    left: 16,
                    bottom: 12,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      color: const Color(0xDD14283A),
                      child: _label(
                        '${model.power!.name.toUpperCase()}  ${model.powerLeft.ceil()}s',
                        mint,
                        size: 9,
                      ),
                    ),
                  ),
                if (model.cinematic && model.mode != RunMode.paused)
                  Positioned.fill(child: _interlude()),
                if (model.mode == RunMode.paused)
                  Positioned.fill(
                    child: _gameOverlay('SIGNAL PAUSED', 'TAKE A BREATH.', [
                      FilledButton(
                        onPressed: _pause,
                        child: const Text('RESUME'),
                      ),
                      const SizedBox(height: 12),
                      TextButton(
                        onPressed: _title,
                        child: const Text('RETURN TO TITLE'),
                      ),
                    ]),
                  ),
                if (model.mode == RunMode.gameOver)
                  Positioned.fill(
                    child: _gameOverlay(
                      'SIGNAL LOST',
                      model.score.toString().padLeft(6, '0'),
                      [
                        if (!submitted)
                          FilledButton(
                            onPressed: () => _loadScores(enter: true),
                            child: const Text('RECORD SCORE'),
                          ),
                        const SizedBox(height: 12),
                        OutlinedButton(
                          onPressed: _start,
                          child: const Text('TRY AGAIN'),
                        ),
                        TextButton(
                          onPressed: _title,
                          child: const Text('RETURN TO TITLE'),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ),
        _controller(),
      ],
    );
  }

  // A render-only view avoids updating the simulation twice when the full-screen sky is mounted.
  late final _ArenaView _arenaProxy = _ArenaView(scene);
  Widget _interlude() {
    final phase = model.presentationMode;
    final p = model.transitionProgress;
    final fadeIn = Curves.easeOutCubic.transform((p / .14).clamp(0, 1));
    final fadeOut = Curves.easeInCubic.transform(((1 - p) / .18).clamp(0, 1));
    final opacity = math.min(fadeIn, fadeOut);
    final clear = phase == RunMode.levelClear || phase == RunMode.victory;
    final travel = phase == RunMode.travel;
    final heading = clear
        ? 'SECTOR SECURED'
        : travel
        ? 'JUMP DRIVE ACTIVE'
        : model.waveTransition
        ? 'SWARM REINFORCEMENTS'
        : 'INCOMING TRANSMISSION';
    final detail = clear
        ? 'ALL WAVES CLEARED · ${model.score.toString().padLeft(6, '0')} PTS'
        : travel
        ? 'NEXT: LV ${model.nextLevel.toString().padLeft(2, '0')} · ${model.nextLevelName}'
        : model.level == 5
        ? 'SHIELD CONTACT · WEAPONS READY'
        : 'WAVE ${model.wave} / ${model.wavesPerLevel} · STAY ALIVE';
    return IgnorePointer(
      child: Align(
        alignment: Alignment(0, model.waveTransition ? -.25 : .25),
        child: Opacity(
          opacity: opacity,
          child: Transform.translate(
            offset: Offset(0, (1 - fadeIn) * 24 - (1 - fadeOut) * 14),
            child: Container(
              constraints: const BoxConstraints(maxWidth: 340),
              margin: const EdgeInsets.symmetric(horizontal: 18),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 22),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [
                    Color(0x00080D18),
                    Color(0xCA080D18),
                    Color(0x00080D18),
                  ],
                ),
                border: Border.symmetric(
                  horizontal: BorderSide(
                    color: (clear ? gold : mint).withValues(alpha: .24),
                  ),
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _label(heading, clear ? gold : mint, size: 8),
                  const SizedBox(height: 12),
                  Text(
                    model.banner,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 19,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 2,
                    ),
                  ),
                  const SizedBox(height: 12),
                  _label(detail, const Color(0xFFAABCD0), size: 8),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: 124,
                    height: 2,
                    child: LinearProgressIndicator(
                      value: p,
                      color: clear ? gold : mint,
                      backgroundColor: const Color(0xFF24374B),
                    ),
                  ),
                  if (travel) ...[
                    const SizedBox(height: 12),
                    _label(
                      'SIGNAL LOCK  ${(p * 100).floor()}%',
                      const Color(0xFF7896AB),
                      size: 7,
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _controller() => LayoutBuilder(
    builder: (context, bounds) => Listener(
      onPointerDown: (e) {
        if (touch != null) return;
        touch = e.pointer;
        touchPosition = (e.localPosition.dx / bounds.maxWidth).clamp(0, 1);
        audioUnlock();
        focus.requestFocus();
        setState(() {});
      },
      onPointerMove: (e) {
        if (touch != e.pointer) return;
        if (model.combat) {
          model.moveBy(e.delta.dx / bounds.maxWidth * 360 * 1.3);
        }
        setState(() {
          touchPosition = (e.localPosition.dx / bounds.maxWidth).clamp(0, 1);
        });
      },
      onPointerUp: (e) {
        if (touch == e.pointer) setState(() => touch = null);
      },
      onPointerCancel: (e) {
        if (touch == e.pointer) setState(() => touch = null);
      },
      child: MouseRegion(
        cursor: SystemMouseCursors.grab,
        child: Semantics(
          label:
              'Ship controller. Drag left or right to move. Automatic firing.',
          child: Container(
            height: 108,
            width: double.infinity,
            margin: const EdgeInsets.fromLTRB(10, 0, 10, 10),
            decoration: BoxDecoration(
              color: const Color(0xFF101F2D),
              border: Border.all(color: const Color(0xFF34485B), width: 2),
            ),
            child: CustomPaint(
              painter: ConsolePainter(touch == null ? null : touchPosition),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _label(
                    '◀     SLIDE TO PILOT     ▶',
                    touch != null ? mint : const Color(0xFF99B4C7),
                    size: 10,
                  ),
                  const SizedBox(height: 9),
                  _label('AUTO FIRE ENGAGED', const Color(0xFF536F82), size: 7),
                ],
              ),
            ),
          ),
        ),
      ),
    ),
  );
  Widget _gameOverlay(String heading, String sub, List<Widget> actions) =>
      ColoredBox(
        color: const Color(0xEC080D18),
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _sprite(0, 4, 58),
                const SizedBox(height: 16),
                Text(
                  heading,
                  style: const TextStyle(
                    fontSize: 23,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 2,
                  ),
                ),
                const SizedBox(height: 12),
                _label(sub, gold, size: 14),
                const SizedBox(height: 30),
                ...actions,
              ],
            ),
          ),
        ),
      );
  Widget _muteButton() => IconButton(
    tooltip: muted ? 'Enable sound' : 'Mute sound',
    onPressed: () {
      setState(() => muted = !muted);
      audioUnlock();
      audioMute(muted);
    },
    icon: Icon(
      muted ? Icons.volume_off_outlined : Icons.volume_up_outlined,
      color: const Color(0xFF95A9BB),
      size: 19,
    ),
  );
  Widget _sprite(int row, int col, double size) => SizedBox(
    width: size,
    height: size,
    child: CustomPaint(painter: _SpritePainter(scene, row, col)),
  );
  Widget _label(String value, Color color, {double size = 10}) => Text(
    value,
    textAlign: TextAlign.center,
    style: TextStyle(
      fontSize: size,
      letterSpacing: 1.5,
      color: color,
      height: 1.4,
    ),
  );
  Widget _scoreOverlay() => ColoredBox(
    color: const Color(0xF5080D18),
    child: Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 440),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _label('KRYBOR HALL OF FAME', mint, size: 9),
              const SizedBox(height: 14),
              Text(
                screen == 'entry' ? 'LEAVE YOUR MARK' : 'TOP 10',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 3,
                ),
              ),
              const SizedBox(height: 20),
              if (screen == 'entry') ...[
                _label(
                  'SCORE ${model.score.toString().padLeft(6, '0')}',
                  gold,
                  size: 17,
                ),
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(
                    3,
                    (index) => Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 9),
                      child: Column(
                        children: [
                          IconButton(
                            tooltip: 'Previous character ${index + 1}',
                            onPressed: loading
                                ? null
                                : () => _rotateInitial(index, -1),
                            icon: const Icon(Icons.arrow_drop_up, color: mint),
                          ),
                          Container(
                            width: 58,
                            height: 105,
                            decoration: BoxDecoration(
                              color: const Color(0xFF122232),
                              border: Border.all(
                                color: const Color(0xFF405A6D),
                              ),
                            ),
                            child: ListWheelScrollView.useDelegate(
                              key: ValueKey('wheel-$index'),
                              controller: wheels[index],
                              physics: loading
                                  ? const NeverScrollableScrollPhysics()
                                  : const FixedExtentScrollPhysics(),
                              itemExtent: 36,
                              perspective: .004,
                              onSelectedItemChanged: (value) =>
                                  initials[index] = value % 36,
                              childDelegate: ListWheelChildLoopingListDelegate(
                                children: List.generate(
                                  36,
                                  (i) => Center(
                                    child: Text(
                                      alphabet[i],
                                      style: const TextStyle(
                                        fontSize: 28,
                                        fontWeight: FontWeight.bold,
                                        color: mint,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                          IconButton(
                            tooltip: 'Next character ${index + 1}',
                            onPressed: loading
                                ? null
                                : () => _rotateInitial(index, 1),
                            icon: const Icon(
                              Icons.arrow_drop_down,
                              color: mint,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                _label(
                  'THREE CHARACTERS. THAT’S YOUR LEGEND.',
                  const Color(0xFF7C91A6),
                  size: 8,
                ),
                const SizedBox(height: 24),
                FilledButton(
                  onPressed: loading ? null : _submit,
                  child: Text(loading ? 'TRANSMITTING…' : 'SAVE SCORE'),
                ),
              ] else ...[
                if (loading)
                  const Padding(
                    padding: EdgeInsets.all(20),
                    child: CircularProgressIndicator(),
                  ),
                if (!loading && error == null && board.isEmpty)
                  Padding(
                    padding: const EdgeInsets.all(26),
                    child: _label(
                      'NO SIGNALS YET. BE THE FIRST.',
                      const Color(0xFF8B9EB3),
                    ),
                  ),
                if (!loading && error == null)
                  ...List.generate(
                    board.length,
                    (i) => Container(
                      padding: const EdgeInsets.symmetric(
                        vertical: 12,
                        horizontal: 10,
                      ),
                      decoration: const BoxDecoration(
                        border: Border(
                          bottom: BorderSide(color: Color(0xFF223447)),
                        ),
                      ),
                      child: Row(
                        children: [
                          SizedBox(
                            width: 38,
                            child: _label(
                              '${i + 1}'.padLeft(2, '0'),
                              i == 0 ? gold : const Color(0xFF6A8198),
                            ),
                          ),
                          Text(
                            board[i].initials,
                            style: TextStyle(
                              letterSpacing: 5,
                              fontWeight: FontWeight.bold,
                              color: i == 0 ? gold : Colors.white,
                            ),
                          ),
                          const Spacer(),
                          Text(
                            board[i].score.toString().padLeft(6, '0'),
                            style: const TextStyle(
                              color: mint,
                              letterSpacing: 2,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                if (submitted)
                  Padding(
                    padding: const EdgeInsets.only(top: 16),
                    child: _label('SIGNAL RECEIVED', mint, size: 9),
                  ),
              ],
              if (error != null) ...[
                const SizedBox(height: 18),
                Text(
                  error!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: gold,
                    fontSize: 11,
                    height: 1.7,
                  ),
                ),
                if (screen == 'scores')
                  TextButton(
                    onPressed: () => _loadScores(),
                    child: const Text('RETRY'),
                  ),
              ],
              const SizedBox(height: 24),
              TextButton(
                onPressed: loading ? null : () => setState(() => screen = null),
                child: const Text('← BACK'),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

class _ArenaView extends FlameGame {
  _ArenaView(this.scene);
  final DemonScene scene;
  @override
  Color backgroundColor() => ink;
  @override
  void render(Canvas canvas) {
    super.render(canvas);
    scene.paintArena(canvas, size);
  }
}

class _SpritePainter extends CustomPainter {
  const _SpritePainter(this.scene, this.row, this.column);
  final DemonScene scene;
  final int row, column;
  @override
  void paint(Canvas canvas, Size size) {
    scene.sprite(canvas, row, column, size.center(Offset.zero), size.width);
  }

  @override
  bool shouldRepaint(_SpritePainter oldDelegate) => true;
}

class ConsolePainter extends CustomPainter {
  const ConsolePainter(this.touch);
  final double? touch;
  @override
  void paint(Canvas c, Size s) {
    final p = Paint()
      ..color = const Color(0xFF203547)
      ..strokeWidth = 1;
    for (var x = 8.0; x < s.width; x += 12) {
      c.drawLine(Offset(x, 8), Offset(x, s.height - 8), p);
    }
    for (var y = 8.0; y < s.height; y += 12) {
      c.drawLine(Offset(8, y), Offset(s.width - 8, y), p);
    }
    c.drawRect(
      Rect.fromLTWH(s.width * .2, 20, s.width * .6, s.height - 40),
      Paint()..color = const Color(0xEE101F2D),
    );
    for (final x in [5.0, s.width - 8]) {
      for (final y in [5.0, s.height - 8]) {
        c.drawRect(
          Rect.fromLTWH(x, y, 3, 3),
          Paint()..color = const Color(0xFF668094),
        );
      }
    }
    c.drawLine(
      Offset(s.width * .3, s.height - 11),
      Offset(s.width * .7, s.height - 11),
      Paint()
        ..color = mint.withValues(alpha: .25)
        ..strokeWidth = 2,
    );
    if (touch != null) {
      c.drawRect(
        Rect.fromCenter(
          center: Offset(touch! * s.width, s.height / 2),
          width: 40,
          height: s.height - 12,
        ),
        Paint()..color = mint.withValues(alpha: .12),
      );
    }
  }

  @override
  bool shouldRepaint(ConsolePainter oldDelegate) => touch != oldDelegate.touch;
}
