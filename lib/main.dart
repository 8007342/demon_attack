import 'dart:math' as math;

import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'game/model.dart';
import 'game/hints.dart';
import 'widgets/hint_art.dart';
import 'widgets/pilot_console_content.dart';
import 'widgets/storyboard_banner.dart';
import 'game/campaign_story.dart';
import 'game/scene.dart';
import 'services/audio.dart';
import 'services/scores.dart';
import 'services/run_storage.dart';
import 'services/tilt_control.dart';
import 'widgets/medal.dart';
import 'widgets/heart_parts.dart';
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
  const ArcadePage({super.key, this.scoreService, this.runStorage});
  final ScoreService? scoreService;
  final RunStorage? runStorage;
  @override
  State<ArcadePage> createState() => _ArcadePageState();
}

class _ArcadePageState extends State<ArcadePage> with WidgetsBindingObserver {
  final model = ArcadeModel();
  late final DemonScene scene;
  final focus = FocusNode();
  late final scores = widget.scoreService ?? ScoreService();
  late final storage = widget.runStorage ?? RunStorage();
  late final RunHistory history;
  Map<String, dynamic>? savedCheckpoint;
  Difficulty boardDifficulty = Difficulty.normal;
  bool handledRunEnd = false;
  final hintDeck = HintDeck();
  TacticalHint? arrivalHint;
  bool hintArtPrecached = false;
  ScoreEntry? finalResult;
  bool showFinalResult = false;
  String? heartNotice;
  double heartNoticeUntil = 0;
  bool muted = false, loading = false, submitted = false;
  String? screen, error, boardError;
  bool boardLoading = true;
  int boardRequest = 0;
  List<ScoreEntry> board = [];
  final initials = [0, 0, 0];
  final wheels = List.generate(
    3,
    (_) => FixedExtentScrollController(initialItem: 3600),
  );
  final alphabet = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
  final keys = <LogicalKeyboardKey>{};
  final tilt = TiltController();
  bool touchInputEnabled = true;
  int? touch;
  double touchPosition = .5;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    history = storage.loadHistory();
    final saved = storage.loadCheckpoint();
    if (saved != null) {
      final candidate = ArcadeModel();
      if (candidate.restoreCheckpoint(saved)) {
        savedCheckpoint = candidate.checkpoint();
      }
    }
    scene = DemonScene(model, _tick);
    scene.topScores = board;
    audioCue('menu', 1, 1, 0);
    _refreshBoard();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!hintArtPrecached) {
      hintArtPrecached = true;
      precacheImage(const AssetImage('assets/images/hint-scenes.png'), context);
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    focus.dispose();
    scores.close();
    tilt.disable();
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
    if (tilt.isActive && model.canPilot) {
      model.setSteering(tilt.steeringValue);
    }
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
        case 'salvage':
          audioSfx('wave');
        case 'levelclear':
          audioCue('levelclear', model.level, 1, model.cycle);
        case 'travel':
          audioCue('travel', model.level, 1, model.cycle);
        case 'victory':
          audioCue('victory', model.level, 1, model.cycle);
        case 'defeat':
          audioCue('gameover', model.level, 1, model.cycle);
        case 'heart':
          heartNotice = 'HEART PIECE COLLECTED';
          heartNoticeUntil = model.clock + 1.25;
          audioSfx('heart');
        case 'extraLife':
          heartNotice = 'HEART ASSEMBLED · +1UP';
          heartNoticeUntil = model.clock + 1.6;
          audioSfx('extraLife');
        case 'checkpoint':
          if (model.wave == 1) {
            arrivalHint = hintDeck.next(
              difficulty: model.difficulty,
              level: model.level,
              route: model.cycle,
            );
          }
          savedCheckpoint = model.checkpoint();
          storage.saveCheckpoint(savedCheckpoint!);
        case 'bossDefeated':
          history.recordBoss(model.difficulty);
          storage.saveHistory(history);
        case 'gameover':
          if (!model.defeatActive) {
            _finishRun(failed: true);
            audioCue('gameover', model.level, 1, model.cycle);
          }
        case 'completed':
          _finishRun(failed: false);
          audioCue('victory', model.level, 1, model.cycle);
        case 'pause':
          audioPause();
        case 'resume':
          audioResume();
        default:
          audioSfx(event);
      }
    }
    if (!handledRunEnd &&
        !model.defeatActive &&
        (model.mode == RunMode.gameOver || model.mode == RunMode.completed)) {
      _finishRun(failed: model.mode == RunMode.gameOver);
    }
    setState(() {});
  }

  void _finishRun({required bool failed}) {
    if (handledRunEnd) return;
    handledRunEnd = true;
    if (failed) {
      history.recordFailure();
      storage.saveHistory(history);
    }
    storage.clearCheckpoint();
    savedCheckpoint = null;
    finalResult = ScoreEntry(
      'YOU',
      model.score,
      difficulty: model.difficulty,
      medals: model.medals,
      activeMilliseconds: model.activeMilliseconds,
      remainingLives: model.medals == 5 ? model.lives : null,
    );
    boardDifficulty = model.difficulty;
    screen = 'ranking';
    _title(keepScreen: true);
    _routeFinalScore();
  }

  Future<void> _routeFinalScore() async {
    final result = finalResult!;
    final request = ++boardRequest;
    boardLoading = true;
    boardError = null;
    try {
      final entries = await scores.load(difficulty: result.difficulty);
      if (!mounted || request != boardRequest) return;
      setState(() {
        board = entries;
        boardLoading = false;
        scene.topScores = entries;
        final qualifies =
            entries.length < 10 || result.score > entries.last.score;
        showFinalResult = !qualifies;
        screen = qualifies ? 'entry' : null;
        error = null;
        loading = false;
      });
    } catch (_) {
      if (!mounted || request != boardRequest) return;
      // Preserve a chance to submit when the ranking relay is unavailable.
      setState(() {
        boardLoading = false;
        boardError = 'The score relay is unavailable.';
        screen = 'entry';
        error = null;
        loading = false;
      });
    }
  }

  void _resumeGame() {
    final saved = savedCheckpoint;
    if (saved == null) return;
    audioUnlock();
    audioResume();
    if (!model.restoreCheckpoint(saved)) {
      setState(() => savedCheckpoint = null);
      storage.clearCheckpoint();
      return;
    }
    setState(() {
      screen = null;
      submitted = false;
      handledRunEnd = false;
      showFinalResult = false;
      heartNotice = null;
    });
    _tick();
    focus.requestFocus();
  }

  void _start([Difficulty difficulty = Difficulty.normal]) {
    audioUnlock();
    audioResume();
    setState(() {
      screen = null;
      submitted = false;
      handledRunEnd = false;
      showFinalResult = false;
      heartNotice = null;
      model.start(difficulty: difficulty);
    });
    _tick();
    focus.requestFocus();
  }

  void _title({bool keepScreen = false}) {
    setState(() {
      if (!keepScreen) screen = null;
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
        key == LogicalKeyboardKey.arrowRight ||
        key == LogicalKeyboardKey.keyA ||
        key == LogicalKeyboardKey.keyD) {
      if (event is KeyUpEvent) {
        keys.remove(key);
      } else {
        keys.add(key);
      }
      final right = keys.contains(LogicalKeyboardKey.arrowRight) ||
          keys.contains(LogicalKeyboardKey.keyD);
      final left = keys.contains(LogicalKeyboardKey.arrowLeft) ||
          keys.contains(LogicalKeyboardKey.keyA);
      final dir = (right ? 1 : 0) - (left ? 1 : 0).toDouble();
      scene.keyboardDirection = dir;
      model.setSteering(dir);
      return KeyEventResult.handled;
    }
    if (event is KeyDownEvent && model.defeatActive) {
      model.defeatTimer = 0;
      _tick();
      return KeyEventResult.handled;
    }
    if (event is KeyDownEvent &&
        _showingArrivalHint &&
        (key == LogicalKeyboardKey.space || key == LogicalKeyboardKey.enter)) {
      model.transitionLeft = 0;
      _tick();
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

  Future<void> _refreshBoard() async {
    final request = ++boardRequest;
    setState(() {
      boardLoading = true;
      boardError = null;
    });
    try {
      final result = await scores.load(difficulty: boardDifficulty);
      if (mounted && request == boardRequest) {
        setState(() {
          board = result;
          boardLoading = false;
          scene.topScores = result;
        });
      }
    } catch (_) {
      if (mounted && request == boardRequest) {
        setState(() {
          boardLoading = false;
          boardError = 'The score relay is unavailable.';
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
        difficulty: model.difficulty,
        medals: model.medals,
        activeMilliseconds: model.activeMilliseconds,
        remainingLives: model.medals == 5 ? model.lives : null,
      );
      if (mounted) {
        setState(() {
          board = result;
          boardDifficulty = model.difficulty;
          scene.topScores = result;
          loading = false;
          submitted = true;
          screen = null;
          boardRequest++;
          boardLoading = false;
          boardError = null;
          model.mode = RunMode.title;
          model.events.clear();
          keys.clear();
          scene.keyboardDirection = 0;
        });
        audioResume();
        audioCue('menu', 1, 1, 0);
        focus.requestFocus();
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
                  if (screen != null)
                    Positioned.fill(
                      child: screen == 'ranking'
                          ? const ColoredBox(
                              color: Color(0xEE080D18),
                              child: Center(child: CircularProgressIndicator()),
                            )
                          : _scoreOverlay(),
                    ),
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
      Center(
        child: SingleChildScrollView(
          key: const ValueKey('landing-scroll'),
          padding: const EdgeInsets.fromLTRB(24, 84, 24, 70),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 960),
            child: bounds.maxWidth > 820
                ? Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Expanded(child: _titleHero()),
                      const SizedBox(width: 64),
                      Expanded(child: _landingScores()),
                    ],
                  )
                : Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 420),
                        child: _titleHero(),
                      ),
                      const SizedBox(height: 36),
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 380),
                        child: _landingScores(),
                      ),
                    ],
                  ),
          ),
        ),
      ),
      Positioned(
        top: 22,
        left: 24,
        right: 24,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: _label(
                  'KRYBOR / DEFENSE SYSTEM',
                  const Color(0xFF94A6B8),
                  size: 9,
                ),
              ),
            ),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  key: const ValueKey('title-touch-toggle-button'),
                  tooltip: touchInputEnabled
                      ? 'Touch Controls: On (Tap for Desktop mode)'
                      : 'Desktop Mode: On (Tap for Touch mode)',
                  onPressed: () =>
                      setState(() => touchInputEnabled = !touchInputEnabled),
                  icon: Icon(
                    touchInputEnabled ? Icons.touch_app : Icons.keyboard,
                    color: touchInputEnabled ? mint : const Color(0xFF95A9BB),
                    size: 19,
                  ),
                ),
                _muteButton(),
              ],
            ),
          ],
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
  Widget _titleHero() => Column(
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
      _label('THE SWARM IS ALIVE.', const Color(0xFFA7B6C8), size: 10),
      const SizedBox(height: 34),
      SizedBox(
        width: 280,
        child: FilledButton(
          onPressed: _start,
          child: const Text('START GAME  →'),
        ),
      ),
      if (savedCheckpoint != null) ...[
        const SizedBox(height: 12),
        SizedBox(
          width: 280,
          child: OutlinedButton(
            onPressed: _resumeGame,
            child: const Text('RESUME GAME'),
          ),
        ),
        const SizedBox(height: 6),
        _label(
          'RESTART THE SAVED WAVE · NO POWERUPS',
          const Color(0xFF8D9EB3),
          size: 8,
        ),
      ],
      for (final difficulty in [Difficulty.easy, Difficulty.hard])
        if (history.unlocked(difficulty)) ...[
          const SizedBox(height: 12),
          SizedBox(
            width: 280,
            child: OutlinedButton(
              onPressed: () => _start(difficulty),
              child: Text('${difficulty.name.toUpperCase()} MODE'),
            ),
          ),
        ],
      const SizedBox(height: 30),
      Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.swipe, size: 16, color: Color(0xFF6F8296)),
          const SizedBox(width: 10),
          _label('DRAG TO MOVE  /  ← →', const Color(0xFF8D9EB3), size: 9),
        ],
      ),
      const SizedBox(height: 10),
      _label('FIVE CARRIERS · ONE FRONTIER', const Color(0xFF60758C), size: 8),
    ],
  );

  Widget _landingScores() => Container(
    key: const ValueKey('landing-top10'),
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(
      color: const Color(0xC9081220),
      border: Border.all(color: const Color(0xFF2B4254)),
    ),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            const Icon(Icons.emoji_events_outlined, color: gold, size: 18),
            const SizedBox(width: 10),
            const Text(
              'TOP 10',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                letterSpacing: 3,
              ),
            ),
            const Spacer(),
            IconButton(
              tooltip: 'Refresh scores',
              onPressed: boardLoading ? null : _refreshBoard,
              icon: const Icon(Icons.refresh, size: 17, color: mint),
            ),
          ],
        ),
        Align(
          alignment: Alignment.centerLeft,
          child: _label(
            'KRYBOR HALL OF FAME',
            const Color(0xFF8AA1B8),
            size: 8,
          ),
        ),
        const SizedBox(height: 12),
        if (history.easyUnlocked || history.hardUnlocked)
          Wrap(
            spacing: 4,
            children: [
              for (final difficulty in [
                Difficulty.normal,
                Difficulty.easy,
                Difficulty.hard,
              ])
                if (history.unlocked(difficulty))
                  TextButton(
                    key: ValueKey('board-${difficulty.name}'),
                    style: TextButton.styleFrom(
                      foregroundColor: boardDifficulty == difficulty
                          ? mint
                          : const Color(0xFF8AA1B8),
                      backgroundColor: boardDifficulty == difficulty
                          ? const Color(0xFF1A3040)
                          : Colors.transparent,
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                    ),
                    onPressed: () {
                      if (difficulty == boardDifficulty) return;
                      setState(() {
                        boardDifficulty = difficulty;
                        submitted = false;
                        board = [];
                      });
                      _refreshBoard();
                    },
                    child: Text(
                      difficulty.name.toUpperCase(),
                      style: const TextStyle(fontSize: 11),
                    ),
                  ),
            ],
          ),
        const SizedBox(height: 12),
        if (boardLoading)
          const Padding(
            padding: EdgeInsets.all(24),
            child: SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          ),
        if (!boardLoading && boardError != null) ...[
          Text(
            boardError!,
            textAlign: TextAlign.center,
            style: const TextStyle(color: gold, fontSize: 11),
          ),
          TextButton(onPressed: _refreshBoard, child: const Text('RETRY')),
        ],
        if (!boardLoading && boardError == null && board.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 20),
            child: _label(
              'NO SIGNALS YET. BE THE FIRST.',
              const Color(0xFF8AA1B8),
              size: 9,
            ),
          ),
        if (!boardLoading && boardError == null)
          ...List.generate(board.length, (i) => _scoreRow(i, board[i])),
        if (showFinalResult && finalResult?.difficulty == boardDifficulty) ...[
          const SizedBox(height: 18),
          _label('YOUR FINAL SCORE', gold, size: 11),
          _scoreRow(-1, finalResult!),
        ],
        if (submitted)
          Padding(
            padding: const EdgeInsets.only(top: 16),
            child: _label('SIGNAL RECEIVED', mint, size: 9),
          ),
      ],
    ),
  );

  String _playingTime(int? milliseconds) {
    if (milliseconds == null) return '—';
    final seconds = milliseconds ~/ 1000;
    final minutes = seconds ~/ 60;
    return '${minutes.toString().padLeft(2, '0')}:${(seconds % 60).toString().padLeft(2, '0')}';
  }

  Widget _medals(Difficulty difficulty, int count, {double size = 18}) => Row(
    mainAxisSize: MainAxisSize.min,
    children: List.generate(
      5,
      (index) => Medal(
        difficulty: difficulty,
        ordinal: index,
        earned: index < count,
        size: size,
      ),
    ),
  );

  Widget _scoreRow(int index, ScoreEntry entry) => Container(
    padding: const EdgeInsets.symmetric(vertical: 10),
    decoration: const BoxDecoration(
      border: Border(bottom: BorderSide(color: Color(0xFF1E3043))),
    ),
    child: LayoutBuilder(
      builder: (context, bounds) {
        final compact = bounds.maxWidth < 320;
        return Row(
          children: [
            SizedBox(
              width: 22,
              child: Text(
                index < 0 ? '—' : '${index + 1}'.padLeft(2, '0'),
                style: TextStyle(
                  fontSize: 10,
                  color: index == 0 ? gold : const Color(0xFF647D94),
                ),
              ),
            ),
            Text(
              entry.initials,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: index == 0 ? gold : Colors.white,
              ),
            ),
            const SizedBox(width: 7),
            _medals(entry.difficulty, entry.medals, size: compact ? 14 : 18),
            const Spacer(),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6),
              child: Text(
                _playingTime(entry.activeMilliseconds),
                style: const TextStyle(color: Color(0xFF9AAEC3), fontSize: 10),
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  entry.score.toString().padLeft(6, '0'),
                  style: const TextStyle(color: mint, fontSize: 11),
                ),
                if (entry.medals == 5 && entry.remainingLives != null)
                  Text(
                    '♥ ×${entry.remainingLives}',
                    style: const TextStyle(
                      color: Color(0xFFFF8C89),
                      fontSize: 10,
                    ),
                  ),
              ],
            ),
          ],
        );
      },
    ),
  );

  Widget _hud() => Row(
    children: [
      Expanded(
        flex: 4,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _label('SCORE', const Color(0xFF7B91A8), size: 8),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                model.score.toString().padLeft(6, '0'),
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            _label(
              _playingTime(model.activeMilliseconds),
              const Color(0xFF9AAEC3),
              size: 9,
            ),
          ],
        ),
      ),
      Expanded(
        flex: 8,
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                CampaignStory.name(model.level, model.cycle).toUpperCase(),
                textAlign: TextAlign.center,
                maxLines: 2,
                style: const TextStyle(
                  color: mint,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                '${model.difficulty.name.toUpperCase()} · ${model.level == 5 ? 'CARRIER CONTACT' : 'WAVE ${model.wave} / ${model.wavesPerLevel}'}',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Color(0xFF839DB5), fontSize: 8),
              ),
              const SizedBox(height: 3),
              Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    '♥ ×${model.lives}',
                    style: const TextStyle(
                      color: Color(0xFFFF8C89),
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  if (model.difficulty != Difficulty.hard) ...[
                    const SizedBox(width: 7),
                    HeartInventory(
                      slots: model.heartSlots,
                      completedSlot: model.heartAssemblyLeft > 0
                          ? model.lastCompletedHeartSlot
                          : null,
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
      SizedBox(
        width: 38,
        child: IconButton(
          key: const ValueKey('touch-toggle-button'),
          tooltip: touchInputEnabled
              ? 'Switch to Desktop Mode'
              : 'Switch to Touch Mode',
          onPressed: () => setState(() {
            touchInputEnabled = !touchInputEnabled;
            touch = null;
          }),
          icon: Icon(
            touchInputEnabled ? Icons.touch_app : Icons.keyboard,
            color: touchInputEnabled ? mint : const Color(0xFF95A9BB),
            size: 19,
          ),
        ),
      ),
      SizedBox(width: 38, child: _muteButton()),
      SizedBox(
        width: 38,
        child: IconButton(
          tooltip: 'Pause game',
          onPressed: _pause,
          icon: const Icon(Icons.pause, size: 20),
        ),
      ),
    ],
  );

  Widget _cabinet(BoxConstraints bounds) {
    // Flame is rendered once behind this transparent arena; overlays stay in logical alignment.
    return Column(
      children: [
        Container(
          height: 94,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: const BoxDecoration(
            color: Color(0xF0080D18),
            border: Border(bottom: BorderSide(color: Color(0xFF26394C))),
          ),
          child: _hud(),
        ),
        Expanded(
          child: LayoutBuilder(
            builder: (context, area) => GestureDetector(
              behavior: HitTestBehavior.translucent,
              onTap: () {
                if (model.defeatActive) {
                  model.defeatTimer = 0;
                  _tick();
                } else if (_showingArrivalHint &&
                    model.level == 1 &&
                    model.wave == 1 &&
                    model.cycle == 0) {
                  model.transitionLeft = 0;
                  _tick();
                }
              },
              child: Stack(
                children: [
                  Positioned.fill(
                    child: ColoredBox(
                      color: ink,
                      child: GameWidget(game: _arenaProxy, autofocus: false),
                    ),
                  ),
                  if (heartNotice != null &&
                      model.clock < heartNoticeUntil &&
                      model.mode != RunMode.paused)
                    Positioned(
                      top: 8,
                      left: 8,
                      right: 8,
                      child: IgnorePointer(
                        child: Center(
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                            color: const Color(0xE8080D18),
                            child: Text(
                              heartNotice!,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                color: Color(0xFFFFD594),
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  if (model.cinematic &&
                      (model.mode != RunMode.paused || _showingArrivalHint))
                    Positioned.fill(child: _interlude()),
                  if (model.mode == RunMode.paused && !_showingArrivalHint)
                    Positioned.fill(
                      child: _gameOverlay('SIGNAL PAUSED', 'TAKE A BREATH.', [
                        FilledButton(
                          onPressed: _pause,
                          child: const Text('RESUME'),
                        ),
                        const SizedBox(height: 12),
                        OutlinedButton(
                          onPressed: () => setState(() {
                            touchInputEnabled = !touchInputEnabled;
                            touch = null;
                          }),
                          child: Text(
                            touchInputEnabled
                                ? 'CONTROLS: TOUCH (ON)'
                                : 'CONTROLS: DESKTOP (TOUCH OFF)',
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextButton(
                          onPressed: _title,
                          child: const Text('RETURN TO TITLE'),
                        ),
                      ]),
                    ),
                ],
              ),
            ),
          ),
        ),
        if (touchInputEnabled) _controller() else _desktopController(),
      ],
    );
  }

  Widget _desktopController() => Container(
    height: 44,
    width: double.infinity,
    margin: const EdgeInsets.fromLTRB(10, 0, 10, 8),
    padding: const EdgeInsets.symmetric(horizontal: 14),
    decoration: BoxDecoration(
      color: const Color(0xFF0F1A26),
      border: Border.all(color: const Color(0xFF2B3F52)),
    ),
    child: Row(
      children: [
        const Icon(Icons.keyboard, size: 16, color: mint),
        const SizedBox(width: 8),
        Expanded(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: _label(
              'DESKTOP MODE · ← / A  → / D TO STEER · AUTO-FIRING',
              const Color(0xFF8AA3BA),
              size: 9,
            ),
          ),
        ),
        const SizedBox(width: 8),
        TextButton(
          key: const ValueKey('enable-touch-bottom'),
          style: TextButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            minimumSize: Size.zero,
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
          onPressed: () => setState(() => touchInputEnabled = true),
          child: const Text(
            'ENABLE TOUCH',
            style: TextStyle(fontSize: 10, color: mint),
          ),
        ),
      ],
    ),
  );

  // A render-only view avoids updating the simulation twice when the full-screen sky is mounted.
  late final _ArenaView _arenaProxy = _ArenaView(scene);
  bool get _showingArrivalHint =>
      arrivalHint != null &&
      model.presentationMode == RunMode.transition &&
      model.wave == 1 &&
      !model.isBoss;

  Widget _hintInterlude(TacticalHint hint) => LayoutBuilder(
    builder: (context, bounds) {
      final paused = model.mode == RunMode.paused;
      final compact = bounds.maxHeight < 400;
      final p = model.transitionProgress;

      return Center(
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: SizedBox(
            width: math.min(460, bounds.maxWidth),
            child: Container(
              key: const ValueKey('arrival-hint'),
              margin: const EdgeInsets.symmetric(horizontal: 12),
              padding: EdgeInsets.all(compact ? 10 : 16),
              decoration: BoxDecoration(
                color: const Color(0xF2080D18),
                border: Border.all(color: mint.withValues(alpha: 0.6)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: FittedBox(
                          alignment: Alignment.centerLeft,
                          fit: BoxFit.scaleDown,
                          child: _label(
                            paused ? 'SIGNAL PAUSED' : 'TACTICAL BRIEFING',
                            mint,
                            size: 11,
                          ),
                        ),
                      ),
                      _label(
                        'SECTOR ${model.level} · WAVE ${model.wave}',
                        const Color(0xFF8AA3BA),
                        size: 9,
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  // Illustrated Tactical Pixel Art
                  HintArt(scene: hint.scene, height: compact ? 88 : 124),
                  const SizedBox(height: 10),
                  Text(
                    hint.title,
                    key: ValueKey('hint-${hint.id}'),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: compact ? 17 : 21,
                      fontWeight: FontWeight.bold,
                      height: 1.15,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    hint.detail,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Color(0xFFB0C4D8),
                      fontSize: 11,
                      height: 1.3,
                    ),
                  ),
                  const SizedBox(height: 12),
                  LinearProgressIndicator(
                    value: p,
                    minHeight: 5,
                    color: mint,
                    backgroundColor: const Color(0xFF24374B),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    },
  );

  /// Unobstructed Boss Arrival Overlay: keeps the central viewport 100% open
  /// so the Brood Dreadnought Carrier's orbital descent is seen in full glory!
  Widget _bossArrivalInterlude(double p) => LayoutBuilder(
    builder: (context, bounds) {
      final compact = bounds.maxHeight < 450;
      final fadeIn = Curves.easeOutCubic.transform((p / .10).clamp(0, 1));
      final fadeOut =
          Curves.easeInCubic.transform(((1 - p) / .10).clamp(0, 1));
      final opacity = math.min(fadeIn, fadeOut);
      final pulse = (math.sin(model.visualClock * 8.0) * 0.5 + 0.5);

      return IgnorePointer(
        child: Opacity(
          opacity: opacity,
          child: Stack(
            children: [
              // Top warning banner: Dreadnought signature alert
              Positioned(
                top: compact ? 6 : 14,
                left: 10,
                right: 10,
                child: Center(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: SizedBox(
                      width: math.min(440, bounds.maxWidth - 20),
                      child: Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: compact ? 6 : 10,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xEB16050A),
                          border: Border.all(
                            color: Color.lerp(
                              const Color(0xFFFF3D68),
                              const Color(0xFFFF8A80),
                              pulse,
                            )!,
                            width: 1.5,
                          ),
                          borderRadius: BorderRadius.circular(4),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFFFF3D68)
                                  .withValues(alpha: 0.25 + pulse * 0.25),
                              blurRadius: 12,
                              spreadRadius: 1,
                            ),
                          ],
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.warning_amber_rounded,
                                  color: const Color(0xFFFF5252),
                                  size: compact ? 14 : 16,
                                ),
                                const SizedBox(width: 8),
                                Flexible(
                                  child: Text(
                                    'WARNING: BROOD DREADNOUGHT SIGNATURE',
                                    textAlign: TextAlign.center,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      color: const Color(0xFFFF5252),
                                      fontSize: compact ? 10 : 12,
                                      fontWeight: FontWeight.bold,
                                      letterSpacing: 1.4,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Icon(
                                  Icons.warning_amber_rounded,
                                  color: const Color(0xFFFF5252),
                                  size: compact ? 14 : 16,
                                ),
                              ],
                            ),
                            const SizedBox(height: 3),
                            Text(
                              'KRYBOR CARRIER ENTERS ORBIT',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: compact ? 15 : 19,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 1.8,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),

              // Middle: ZERO obstruction! The Carrier descends in full glory!

              // Bottom tactical objective dock, mounted right above the pilot console
              Positioned(
                bottom: compact ? 6 : 14,
                left: 10,
                right: 10,
                child: Center(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: SizedBox(
                      width: math.min(440, bounds.maxWidth - 20),
                      child: Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: compact ? 6 : 10,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xEB080D18),
                          border: Border.all(
                            color: mint.withValues(alpha: 0.65),
                            width: 1.2,
                          ),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'TACTICAL OBJECTIVE',
                                  style: TextStyle(
                                    color: mint,
                                    fontSize: compact ? 9 : 10.5,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 1.1,
                                  ),
                                ),
                                Text(
                                  'INTERCEPT LOCK ${(p * 100).toInt()}%',
                                  style: TextStyle(
                                    color: const Color(0xFF8AA3BA),
                                    fontSize: compact ? 9 : 10,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'BREAK DEFLECTOR SHIELD · FIRE DIRECTLY INTO OPEN VENT HATCH',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: const Color(0xFFD6E2EE),
                                fontSize: compact ? 10.5 : 12,
                                fontWeight: FontWeight.w600,
                                letterSpacing: 0.5,
                              ),
                            ),
                            const SizedBox(height: 6),
                            LinearProgressIndicator(
                              value: p,
                              minHeight: 4,
                              color: const Color(0xFFFF5252),
                              backgroundColor: const Color(0xFF24374B),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    },
  );

  /// Sleek upper banner for wave transitions: keeps the playfield completely clear for piloting
  Widget _waveTransitionInterlude(double p) => LayoutBuilder(
    builder: (context, bounds) {
      final compact = bounds.maxHeight < 500;
      final fadeIn = Curves.easeOutCubic.transform((p / .12).clamp(0, 1));
      final fadeOut =
          Curves.easeInCubic.transform(((1 - p) / .12).clamp(0, 1));
      final opacity = math.min(fadeIn, fadeOut);

      return IgnorePointer(
        child: Align(
          alignment: const Alignment(0, -0.68),
          child: Opacity(
            opacity: opacity,
            child: Transform.translate(
              offset: Offset(0, (1 - fadeIn) * 12),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: SizedBox(
                  width: math.min(360, bounds.maxWidth - 20),
                  child: Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: compact ? 8 : 12,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xE6080D18),
                      border: Border.all(
                        color: mint.withValues(alpha: 0.5),
                        width: 1.2,
                      ),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'SWARM REINFORCEMENTS',
                          style: TextStyle(
                            color: mint,
                            fontSize: compact ? 12 : 14,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.2,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            for (var i = 1; i <= model.wavesPerLevel; i++)
                              Padding(
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 3),
                                child: Icon(
                                  i < model.wave
                                      ? Icons.check_circle_outline_rounded
                                      : (i == model.wave
                                          ? Icons.radio_button_checked_rounded
                                          : Icons.radio_button_unchecked_rounded),
                                  size: compact ? 12 : 14,
                                  color: i < model.wave
                                      ? const Color(0xFF70F5D5)
                                      : (i == model.wave
                                          ? const Color(0xFFFFD54F)
                                          : const Color(0xFF4B6584)),
                                ),
                              ),
                            const SizedBox(width: 8),
                            Text(
                              'WAVE ${model.wave} OF ${model.wavesPerLevel}',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: compact ? 13 : 15,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 0.8,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'HOSTILE FORMATIONS INBOUND · STAY SHARP',
                          style: TextStyle(
                            color: const Color(0xFF9AAEC3),
                            fontSize: compact ? 9.5 : 11,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    },
  );

  /// Salvage window interlude: docked at top to leave central playfield free to catch items
  Widget _salvageInterlude(double p) => LayoutBuilder(
    builder: (context, bounds) {
      final compact = bounds.maxHeight < 500;
      final fadeIn = Curves.easeOutCubic.transform((p / .12).clamp(0, 1));
      final fadeOut =
          Curves.easeInCubic.transform(((1 - p) / .12).clamp(0, 1));
      final opacity = math.min(fadeIn, fadeOut);

      return IgnorePointer(
        child: Align(
          alignment: const Alignment(0, -0.74),
          child: Opacity(
            opacity: opacity,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: SizedBox(
                width: math.min(360, bounds.maxWidth - 20),
                child: Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: compact ? 8 : 10,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xE6080D18),
                    border: Border.all(
                      color: mint.withValues(alpha: 0.6),
                      width: 1.2,
                    ),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              'RECOVERY WINDOW ACTIVE',
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: mint,
                                fontSize: compact ? 11 : 12.5,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 1.1,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '${model.transitionLeft.ceil()}s LEFT',
                            style: const TextStyle(
                              color: Color(0xFFFFD54F),
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'PILOT SHIP TO COLLECT CARGO',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: const Color(0xFFD6E2EE),
                          fontSize: compact ? 10 : 11,
                        ),
                      ),
                      const SizedBox(height: 6),
                      LinearProgressIndicator(
                        value: p,
                        minHeight: 3.5,
                        color: mint,
                        backgroundColor: const Color(0xFF24374B),
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

  Widget _interlude() {
    if (_showingArrivalHint) return _hintInterlude(arrivalHint!);
    final phase = model.presentationMode;
    final p = model.transitionProgress;
    if (phase == RunMode.transition && model.isBoss) {
      return _bossArrivalInterlude(p);
    }
    if (model.waveTransition) {
      return _waveTransitionInterlude(p);
    }
    if (phase == RunMode.salvage) {
      return _salvageInterlude(p);
    }

    final fadeIn = Curves.easeOutCubic.transform((p / .12).clamp(0, 1));
    final fadeOut = Curves.easeInCubic.transform(((1 - p) / .12).clamp(0, 1));
    final bossVictory = phase == RunMode.victory;
    final recognition = bossVictory && p >= .32;
    final clear = phase == RunMode.levelClear;
    final travel = phase == RunMode.travel;
    final color = clear || bossVictory ? gold : mint;
    final heading = bossVictory
        ? recognition
            ? 'THE FLEET RECOGNIZES YOUR SERVICE'
            : 'THE CARRIER IS FALLING'
        : clear
        ? 'SECTOR SECURED'
        : travel
        ? 'JUMP DRIVE ACTIVE'
        : 'INCOMING TRANSMISSION';
    final destination = travel
        ? CampaignStory.name(
            model.nextLevel,
            model.level == 5 ? model.cycle + 1 : model.cycle,
          )
        : CampaignStory.name(model.level, model.cycle);
    final story = bossVictory
        ? model.medals == 5
            ? 'Five carriers fallen. Brood command is broken. The frontier is free.'
            : 'A medal for your courage. A life for the journey. Keep flying, defender.'
        : clear
        ? CampaignStory.departure(model.level, model.cycle)
        : travel
        ? CampaignStory.travel(model.level, model.cycle)
        : CampaignStory.briefing(model.level, model.cycle);
    return IgnorePointer(
      child: LayoutBuilder(
        builder: (context, bounds) {
          final compact = bounds.maxHeight < 500;
          return Align(
            alignment: const Alignment(0, 0.08),
            child: Opacity(
              opacity: math.min(fadeIn, fadeOut),
              child: Transform.translate(
                offset: Offset(0, (1 - fadeIn) * 20),
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: SizedBox(
                    width: math.min(460, bounds.maxWidth),
                    child: Container(
                      constraints: const BoxConstraints(maxWidth: 460),
                      margin: const EdgeInsets.symmetric(horizontal: 14),
                      padding: EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: compact ? 10 : 20,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xD9080D18),
                        border: Border.symmetric(
                          horizontal: BorderSide(
                            color: color.withValues(alpha: .4),
                          ),
                        ),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            heading,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: color,
                              fontSize: compact ? 16 : 19,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1.2,
                            ),
                          ),
                          SizedBox(height: compact ? 6 : 14),
                          Text(
                            destination.toUpperCase(),
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: compact ? 28 : 36,
                              height: 1.15,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1.5,
                            ),
                          ),
                          SizedBox(height: compact ? 6 : 10),
                          StoryboardBanner(
                            level: model.level,
                            cycle: model.cycle,
                            phase: phase,
                            progress: p,
                            steering: model.steering,
                            compact: compact,
                          ),
                          if (recognition) ...[
                            const SizedBox(height: 12),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Transform.scale(
                                  scale:
                                      .8 +
                                      .2 *
                                          Curves.easeOutBack.transform(
                                            ((p - .32) / .2).clamp(0, 1),
                                          ),
                                  child: Medal(
                                    difficulty: model.difficulty,
                                    ordinal: (model.medals - 1).clamp(0, 4),
                                    size: compact ? 40 : 64,
                                  ),
                                ),
                                const SizedBox(width: 20),
                                const Text(
                                  '♥ +1UP',
                                  style: TextStyle(
                                    color: Color(0xFFFF8C89),
                                    fontSize: 24,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ],
                          if (!(bossVictory && !recognition)) ...[
                            SizedBox(height: compact ? 8 : 18),
                            Text(
                              story,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: compact ? 18 : 22,
                                height: 1.5,
                                color: const Color(0xFFCCD9E6),
                              ),
                            ),
                          ],
                          SizedBox(height: compact ? 8 : 18),
                          SizedBox(
                            height: compact ? 6 : 10,
                            width: double.infinity,
                            child: LinearProgressIndicator(
                              value: p,
                              color: color,
                              backgroundColor: const Color(0xFF24374B),
                            ),
                          ),
                          if (travel && !compact) ...[
                            const SizedBox(height: 10),
                            _label(
                              'DESTINATION LOCK ${(p * 100).floor()}%',
                              const Color(0xFF9AAEC3),
                              size: 11,
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _controller() => LayoutBuilder(
    builder: (context, bounds) => Listener(
      onPointerDown: (e) {
        if (!touchInputEnabled) return;
        if (touch != null) return;
        touch = e.pointer;
        touchPosition = (e.localPosition.dx / bounds.maxWidth).clamp(0, 1);
        final steerNorm = ((touchPosition - 0.5) * 2.0).clamp(-1.0, 1.0);
        model.setSteering(steerNorm);
        audioUnlock();
        focus.requestFocus();
        setState(() {});
      },
      onPointerMove: (e) {
        if (!touchInputEnabled || touch != e.pointer) return;
        touchPosition = (e.localPosition.dx / bounds.maxWidth).clamp(0, 1);
        final steerNorm = ((touchPosition - 0.5) * 2.0).clamp(-1.0, 1.0);
        model.setSteering(steerNorm);
        if (model.canPilot) {
          model.moveBy(e.delta.dx / bounds.maxWidth * 360 * 1.3);
        }
        setState(() {});
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
              painter: ConsolePainter(
                touch == null ? null : touchPosition,
                steering: model.steering,
                defeatActive: model.defeatActive,
                tiltActive: tilt.isActive,
                hasPowers: model.powerTimers.isNotEmpty,
                combat: model.combat,
              ),
              child: PilotConsoleContent(
                timers: Map.of(model.powerTimers),
                touching: touch != null,
                collecting: model.canPilot && !model.combat,
                tiltActive: tilt.isActive,
                steering: model.steering,
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
                'LEAVE YOUR MARK',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 3,
                ),
              ),
              const SizedBox(height: 20),

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
                            border: Border.all(color: const Color(0xFF405A6D)),
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
                          icon: const Icon(Icons.arrow_drop_down, color: mint),
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
  const ConsolePainter(
    this.touch, {
    this.steering = 0.0,
    this.defeatActive = false,
    this.tiltActive = false,
    this.hasPowers = false,
    this.combat = true,
  });

  final double? touch;
  final double steering;
  final bool defeatActive;
  final bool tiltActive;
  final bool hasPowers;
  final bool combat;

  @override
  void paint(Canvas c, Size s) {
    if (defeatActive) {
      // Offline emergency scanlines and warning flicker
      final pLine = Paint()
        ..color = const Color(0x33FF4444)
        ..strokeWidth = 1;
      for (var y = 2.0; y < s.height; y += 4) {
        c.drawLine(Offset(0, y), Offset(s.width, y), pLine);
      }
      final pStatic = Paint()
        ..color = const Color(0x22FFAA33)
        ..strokeWidth = 2;
      c.drawLine(
        Offset(8, s.height * 0.5),
        Offset(s.width - 8, s.height * 0.5),
        pStatic,
      );
      return;
    }

    final pGrid = Paint()
      ..color = const Color(0xFF1B2D3E)
      ..strokeWidth = 1;
    for (var x = 8.0; x < s.width; x += 14) {
      c.drawLine(Offset(x, 8), Offset(x, s.height - 8), pGrid);
    }
    for (var y = 8.0; y < s.height; y += 14) {
      c.drawLine(Offset(8, y), Offset(s.width - 8, y), pGrid);
    }

    // Inner console display housing
    c.drawRect(
      Rect.fromLTWH(s.width * .18, 16, s.width * .64, s.height - 32),
      Paint()..color = const Color(0xF20B1522),
    );

    // Tactical corner framing brackets
    for (final x in [6.0, s.width - 9]) {
      for (final y in [6.0, s.height - 9]) {
        c.drawRect(
          Rect.fromLTWH(x, y, 3, 3),
          Paint()..color = const Color(0xFF4C6B82),
        );
      }
    }

    // Discreet diegetic LED status indicators along top rail
    const ledSpacing = 16.0;
    final ledStartX = s.width * 0.5 - ledSpacing * 1.5;
    const ledY = 9.0;

    // LED 1: PWR
    c.drawRect(
      Rect.fromLTWH(ledStartX, ledY, 3, 3),
      Paint()
        ..color = hasPowers ? const Color(0xFF70F5D5) : const Color(0xFF223647),
    );
    // LED 2: AUTO
    c.drawRect(
      Rect.fromLTWH(ledStartX + ledSpacing, ledY, 3, 3),
      Paint()
        ..color = combat ? const Color(0xFFFFD594) : const Color(0xFF223647),
    );
    // LED 3: GYRO
    c.drawRect(
      Rect.fromLTWH(ledStartX + ledSpacing * 2, ledY, 3, 3),
      Paint()
        ..color = tiltActive ? const Color(0xFF39DFCC) : const Color(0xFF223647),
    );
    // LED 4: SYS
    c.drawRect(
      Rect.fromLTWH(ledStartX + ledSpacing * 3, ledY, 3, 3),
      Paint()..color = const Color(0xFF70F5D5).withValues(alpha: 0.6),
    );

    // Recessed sliding track rail
    final railStartX = s.width * 0.22;
    final railEndX = s.width * 0.78;
    final railY = s.height - 10;
    c.drawLine(
      Offset(railStartX, railY),
      Offset(railEndX, railY),
      Paint()
        ..color = const Color(0xFF243B4E)
        ..strokeWidth = 2,
    );
    // Center notch
    c.drawLine(
      Offset(s.width * 0.5, railY - 3),
      Offset(s.width * 0.5, railY + 3),
      Paint()
        ..color = const Color(0xFF4C6B82)
        ..strokeWidth = 1.5,
    );
    // Quarter ticks
    for (final frac in [0.36, 0.64]) {
      c.drawLine(
        Offset(s.width * frac, railY - 2),
        Offset(s.width * frac, railY + 2),
        Paint()
          ..color = const Color(0xFF334F66)
          ..strokeWidth = 1,
      );
    }

    // Active pilot reticle indicator
    final activeX = touch != null
        ? touch! * s.width
        : (steering != 0.0 ? s.width * 0.5 + steering * (s.width * 0.26) : null);

    if (activeX != null) {
      // Glowing carriage indicator on rail
      c.drawRect(
        Rect.fromCenter(
          center: Offset(activeX, railY),
          width: 14,
          height: 4,
        ),
        Paint()..color = mint,
      );
      // Soft tracking pillar
      c.drawRect(
        Rect.fromCenter(
          center: Offset(activeX, s.height * 0.5),
          width: 38,
          height: s.height - 14,
        ),
        Paint()..color = mint.withValues(alpha: .10),
      );
    }
  }

  @override
  bool shouldRepaint(ConsolePainter oldDelegate) =>
      touch != oldDelegate.touch ||
      steering != oldDelegate.steering ||
      defeatActive != oldDelegate.defeatActive ||
      tiltActive != oldDelegate.tiltActive ||
      hasPowers != oldDelegate.hasPowers ||
      combat != oldDelegate.combat;
}
