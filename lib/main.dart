import 'dart:math' as math;

import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'game/model.dart';
import 'widgets/power_status.dart';
import 'game/campaign_story.dart';
import 'game/scene.dart';
import 'services/audio.dart';
import 'services/scores.dart';
import 'services/run_storage.dart';
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
    audioCue('menu', 1, 1, 0);
    _refreshBoard();
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
        case 'salvage':
          audioSfx('wave');
        case 'levelclear':
          audioCue('levelclear', model.level, 1, model.cycle);
        case 'travel':
          audioCue('travel', model.level, 1, model.cycle);
        case 'victory':
          audioCue('victory', model.level, 1, model.cycle);
        case 'heart':
          heartNotice = 'HEART PIECE COLLECTED';
          heartNoticeUntil = model.clock + 1.25;
          audioSfx('heart');
        case 'extraLife':
          heartNotice = 'HEART ASSEMBLED · +1UP';
          heartNoticeUntil = model.clock + 1.6;
          audioSfx('extraLife');
        case 'checkpoint':
          savedCheckpoint = model.checkpoint();
          storage.saveCheckpoint(savedCheckpoint!);
        case 'bossDefeated':
          history.recordBoss(model.difficulty);
          storage.saveHistory(history);
        case 'gameover':
          _finishRun(failed: true);
          audioCue('gameover', model.level, 1, model.cycle);
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
      heartNotice = null;
      model.start(difficulty: difficulty);
    });
    _tick();
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

  void _enterInitials() {
    setState(() {
      screen = 'entry';
      error = null;
      loading = false;
    });
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
            _muteButton(),
          ],
        ),
      ),
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
                '${index + 1}'.padLeft(2, '0'),
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
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Row(
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
            ),
          ],
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
            builder: (context, area) => Stack(
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
                if (model.mode == RunMode.gameOver ||
                    model.mode == RunMode.completed)
                  Positioned.fill(
                    child: _gameOverlay(
                      model.mode == RunMode.completed
                          ? 'FRONTIER LIBERATED'
                          : 'SIGNAL LOST',
                      model.score.toString().padLeft(6, '0'),
                      [
                        _medals(model.difficulty, model.medals, size: 36),
                        const SizedBox(height: 12),
                        Text(
                          '${_playingTime(model.activeMilliseconds)} ACTIVE PLAY${model.medals == 5 ? ' · ♥ ×${model.lives}' : ''}',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Color(0xFF9AAEC3),
                            fontSize: 13,
                          ),
                        ),
                        const SizedBox(height: 24),
                        if (!submitted)
                          FilledButton(
                            onPressed: _enterInitials,
                            child: const Text('RECORD SCORE'),
                          ),
                        const SizedBox(height: 12),
                        OutlinedButton(
                          onPressed: () => _start(model.difficulty),
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
    final fadeIn = Curves.easeOutCubic.transform((p / .12).clamp(0, 1));
    final fadeOut = Curves.easeInCubic.transform(((1 - p) / .12).clamp(0, 1));
    final bossVictory = phase == RunMode.victory;
    final recognition = bossVictory && p >= .32;
    final clear = phase == RunMode.levelClear;
    final salvage = phase == RunMode.salvage;
    final travel = phase == RunMode.travel;
    final wave = model.waveTransition;
    final color = clear || bossVictory ? gold : mint;
    final heading = bossVictory
        ? recognition
              ? 'THE FLEET RECOGNIZES YOUR SERVICE'
              : 'THE CARRIER IS FALLING'
        : salvage
        ? 'RECOVERY WINDOW'
        : clear
        ? 'SECTOR SECURED'
        : travel
        ? 'JUMP DRIVE ACTIVE'
        : wave
        ? 'SWARM REINFORCEMENTS'
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
            alignment: Alignment(0, wave || salvage ? -.25 : .15),
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
                          if (!wave &&
                              !salvage &&
                              !(bossVictory && !recognition)) ...[
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
                          if (salvage)
                            Text(
                              'PILOT TO COLLECT · ${model.transitionLeft.ceil()}s LEFT',
                              style: const TextStyle(color: mint, fontSize: 14),
                            ),
                          if (wave)
                            Text(
                              'WAVE ${model.wave} / ${model.wavesPerLevel} · STAY ALIVE',
                              style: const TextStyle(color: mint, fontSize: 14),
                            ),
                          if (!salvage && !wave)
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
        if (touch != null) return;
        touch = e.pointer;
        touchPosition = (e.localPosition.dx / bounds.maxWidth).clamp(0, 1);
        audioUnlock();
        focus.requestFocus();
        setState(() {});
      },
      onPointerMove: (e) {
        if (touch != e.pointer) return;
        if (model.canPilot) {
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
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Center(
                    key: const ValueKey('controller-guidance'),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _label(
                          '◀     SLIDE TO PILOT     ▶',
                          touch != null ? mint : const Color(0xFF99B4C7),
                          size: 10,
                        ),
                        const SizedBox(height: 9),
                        _label(
                          model.canPilot && !model.combat
                              ? 'COLLECT POWERUPS · WEAPONS SAFE'
                              : 'AUTO FIRE ENGAGED',
                          const Color(0xFF536F82),
                          size: 7,
                        ),
                      ],
                    ),
                  ),
                  if (model.activePowers.isNotEmpty)
                    Positioned(
                      left: 8,
                      bottom: 70,
                      child: IgnorePointer(
                        child: DecoratedBox(
                          decoration: const BoxDecoration(
                            color: Color(0xED101F2D),
                          ),
                          child: PowerStatus(timers: Map.of(model.powerTimers)),
                        ),
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
