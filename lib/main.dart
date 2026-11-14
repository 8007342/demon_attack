import 'dart:math' as math;

import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_web_plugins/url_strategy.dart';

import 'game/model.dart';
import 'widgets/pilot_console_content.dart';
import 'game/campaign_story.dart';
import 'game/scene.dart';
import 'game/music_director.dart'; // --- music event hook
import 'services/audio.dart';
import 'services/scores.dart';
import 'services/run_storage.dart';
import 'services/tilt_control.dart';
import 'services/comms_audio.dart' show commsStopAll;
import 'ending/ending_page.dart';
import 'widgets/medal.dart';
import 'widgets/heart_parts.dart';
import 'widgets/widescreen_backdrop.dart'; // --- widescreen backdrop
// --- squad comms
import 'comms/comms_view.dart';
import 'comms/squad_comms.dart';
// --- console route
import 'widgets/dev_console.dart';
import 'widgets/transition_overlay.dart'; // --- fluid transitions
import 'widgets/level_toggle.dart'; // --- audio round: music / speech toggles
export 'widgets/dev_console.dart' show ConsoleStart, isConsoleRoute;
// --- end console route
export 'game/scene.dart' show DemonScene;

// Path URLs (not the default #/hash) so the browser path picks the route:
// /console opens the console. The Worker serves index.html for any path.
void main() {
  usePathUrlStrategy();
  runApp(const DemonAttackApp());
}

// --- console route: '/console' opens the dev console, any other path the
// arcade. A console launch pushes '/' (the address bar returns to /) with a
// ConsoleStart argument; browser back returns to the console.
MaterialPageRoute<void> _appRoute(RouteSettings settings) => MaterialPageRoute(
  settings: settings,
  builder: (_) => isConsoleRoute(settings.name)
      ? DevConsolePage(
          galleryUrl: '/gallery/',
          onStart: (context, start) =>
              Navigator.of(context).pushNamed('/', arguments: start),
        )
      : ArcadePage(
          consoleStart: settings.arguments is ConsoleStart
              ? settings.arguments as ConsoleStart
              : null,
        ),
);
// --- end console route

class DemonAttackApp extends StatelessWidget {
  const DemonAttackApp({super.key, this.initialRoute}); // --- console route
  /// Overrides the browser path (tests); null uses the platform route.
  final String? initialRoute; // --- console route
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
    // --- console route
    initialRoute: initialRoute,
    onGenerateInitialRoutes: (name) => [_appRoute(RouteSettings(name: name))],
    onGenerateRoute: _appRoute,
    // --- end console route
  );
}

class ArcadePage extends StatefulWidget {
  const ArcadePage({
    super.key,
    this.scoreService,
    this.runStorage,
    this.squadComms,
    this.consoleStart, // --- console route
    this.interludeSeed, // --- fluid transitions
  });
  final ScoreService? scoreService;
  final RunStorage? runStorage;
  final SquadComms? squadComms;

  /// --- console route: begin a run here instead of on the title screen.
  final ConsoleStart? consoleStart;

  /// --- fluid transitions: fixed interlude seed (tests); null: per run.
  final int? interludeSeed;
  @override
  State<ArcadePage> createState() => _ArcadePageState();
}

class _ArcadePageState extends State<ArcadePage> with WidgetsBindingObserver {
  final model = ArcadeModel();
  late final DemonScene scene;
  // --- squad comms: one shared GameEvent stream, read-only over the model.
  late final gameEvents = GameEventObserver(model);
  late final squadComms = widget.squadComms ?? SquadComms();
  bool voiceOn = true;
  // --- audio round: Music and Speech levels (Mute / Low / Full), read from
  // the audio engine, which remembers them per device. Both muted also mutes
  // the effects (the old sound switch).
  AudioLevel musicLevel = AudioLevel.full, speechLevel = AudioLevel.full;
  void _setMusicLevel(AudioLevel level) {
    setState(() => musicLevel = level);
    audioUnlock();
    audioSetLevel('music', level.name);
  }

  void _setSpeechLevel(AudioLevel level) {
    setState(() {
      speechLevel = level;
      voiceOn = level != AudioLevel.mute;
    });
    audioUnlock();
    audioSetLevel('speech', level.name);
    squadComms.setVoice(voiceOn);
  }

  // --- end audio round
  void _resetComms({bool resume = false}) {
    transitions.newRun(squadComms, voice: voiceOn); // --- fluid transitions
    gameEvents.reset(freshRun: !resume);
    squadComms.reset();
    squadComms.startRun(storage.store, resume: resume);
  }

  // The music bridge sees the derived events too (GameEvents.listen),
  // including flawlessVictory / flawlessRun for a fleet-intact cue.
  final _commsListeners = <void Function()>[];
  void _attachComms() {
    _commsListeners.add(GameEvents.listen(gameEvents.onGameEvent));
    squadComms.attach();
  }

  void _detachComms() {
    for (final remove in _commsListeners) {
      remove();
    }
    _commsListeners.clear();
    squadComms.detach();
  }

  // --- end squad comms
  final focus = FocusNode();
  late final scores = widget.scoreService ?? ScoreService();
  late final storage = widget.runStorage ?? RunStorage();
  late final RunHistory history;
  Map<String, dynamic>? savedCheckpoint;
  Difficulty boardDifficulty = Difficulty.normal;
  bool handledRunEnd = false;
  bool _endingShown = false, _endingOpen = false, _endingScheduled = false;
  // --- fluid transitions: the one primary transition message and the slim
  // progress strip (widgets/transition_overlay.dart).
  late final transitions = TransitionPresenter(seed: widget.interludeSeed);
  void _skipTransition() {
    if (transitions.skip(model, squadComms, voice: voiceOn)) _tick();
  }

  // --- end fluid transitions
  bool hintArtPrecached = false;
  ScoreEntry? finalResult;
  bool showFinalResult = false;

  /// False when [finalResult] came from a /console run (shown, never ranked).
  bool finalRanked = true;
  String? heartNotice;
  double heartNoticeUntil = 0;
  bool loading = false, submitted = false;
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
  int? touch;
  double touchPosition = .5;
  List<void Function()> _music = const []; // --- music event hook
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
    // --- audio round: the remembered levels
    musicLevel = AudioLevel.parse(audioLevel('music'));
    speechLevel = AudioLevel.parse(audioLevel('speech'));
    voiceOn = speechLevel != AudioLevel.mute;
    if (!voiceOn) squadComms.setVoice(false);
    // --- music event hook: adaptive music listens on the shared event bridge
    _music = [
      GameEvents.listen(MusicBridge().call),
      GameEvents.listen(scene.music.onGameEvent),
    ];
    scene.topScores = board;
    audioCue('menu', 1, 1, 0);
    _refreshBoard();
    _attachComms(); // --- squad comms
    // --- console route: the run begins before the first frame (no title).
    final consoleStart = widget.consoleStart;
    if (consoleStart != null) {
      _startConsole(consoleStart);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _tick();
        if (mounted) focus.requestFocus();
      });
    }
    // --- end console route
  }

  // --- console route: mirrors _start() bookkeeping, via ArcadeModel.startAt.
  void _startConsole(ConsoleStart start) {
    _endingShown = false;
    audioUnlock();
    audioResume();
    screen = null;
    submitted = false;
    handledRunEnd = false;
    showFinalResult = false;
    heartNotice = null;
    _resetComms();
    start.applyTo(model);
  }
  // --- end console route

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
    for (final remove in _music) {
      remove();
    } // --- music event hook
    WidgetsBinding.instance.removeObserver(this);
    _detachComms(); // --- squad comms
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
    final rawEvents = model.takeEvents();
    // --- squad comms: derived events go out through dispatchGameEvent.
    gameEvents.observe(rawEvents);
    for (final event in rawEvents) {
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
          if (!_endingShown && model.finalBoss) {
            precacheImage(
              const AssetImage('assets/images/beach-ending.webp'),
              context,
            );
          }
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
          // A console run never replaces the player's saved run.
          if (model.ranked) {
            savedCheckpoint = model.checkpoint();
            storage.saveCheckpoint(savedCheckpoint!);
          }
        case 'bossDefeated':
          // Console runs unlock nothing.
          if (model.ranked) {
            history.recordBoss(model.difficulty);
            if (model.finalBoss) history.recordFinale();
            storage.saveHistory(history);
          }
        case 'gameover':
          if (!model.defeatActive) {
            _finishRun(failed: true);
            audioCue('gameover', model.level, 1, model.cycle);
          }
        case 'completed':
          _finishRun(failed: false);
          audioCue('victory', model.level, 1, model.cycle);
        case 'pause':
          if (!_endingOpen) audioPause();
        case 'resume':
          audioResume();
        default:
          audioSfx(event);
      }
    }
    // --- ground war events: one no-op-safe dispatcher (game_events.dart) ---
    // The music bridge (`// --- music event hook`) and the commander comms
    // panel subscribe with GameEvents.listen; nothing is registered yet.
    for (final event in model.takeGameEvents()) {
      dispatchGameEvent(event);
    }
    // --- squad comms: play this frame's callouts.
    squadComms.tick(
      paused: model.mode == RunMode.paused || model.mode == RunMode.title,
      combat: model.combat,
    );
    transitions.update(
      model: model,
      comms: squadComms,
      voice: voiceOn,
      flawless: gameEvents.tally.sectorShips == 0,
    ); // --- fluid transitions
    if (!handledRunEnd &&
        !model.defeatActive &&
        (model.mode == RunMode.gameOver || model.mode == RunMode.completed)) {
      _finishRun(failed: model.mode == RunMode.gameOver);
    }
    // The beach ending belongs to the campaign's last carrier only (sector 5
    // of the fifth route); the four earlier carriers keep their normal
    // victory → travel flow into the next route.
    if (!_endingShown &&
        !_endingOpen &&
        !_endingScheduled &&
        model.mode == RunMode.victory &&
        model.finalBoss &&
        model.transitionProgress >= .72) {
      _endingScheduled = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _endingScheduled = false;
        if (mounted &&
            model.mode == RunMode.victory &&
            model.finalBoss &&
            !_endingOpen) {
          _endingShown = true;
          _showEnding();
        }
      });
    }
    setState(() {});
  }

  Future<void> _showEnding({bool creditsOnly = false}) async {
    if (_endingOpen) return;
    _endingOpen = true;
    final holdRun = model.mode == RunMode.playing || model.cinematic;
    if (holdRun) model.pause();
    commsStopAll();
    audioUnlock();
    audioResume();
    audioCue('ending', 5, 1, model.cycle);
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) =>
            EndingPage(creditsOnly: creditsOnly, onAudioResume: audioResume),
      ),
    );
    if (!mounted) return;
    if (holdRun && model.mode == RunMode.paused) model.resume();
    // Consume the preserved pause/resume notifications while the ending still
    // owns audio. Closing never advances the simulation or alters run results.
    _tick();
    _endingOpen = false;
    audioResume();
    audioCue(
      model.mode == RunMode.title ? 'menu' : 'victory',
      model.level,
      1,
      model.cycle,
    );
    focus.requestFocus();
  }

  void _finishRun({required bool failed}) {
    if (handledRunEnd) return;
    handledRunEnd = true;
    // --- console route: a console run is never ranked. It shows its result
    // beside the board, tagged, with no initials entry and no POST; the
    // player's own saved run and unlock history are left untouched.
    if (!model.ranked) {
      finalResult = ScoreEntry(
        'YOU',
        model.score,
        difficulty: model.difficulty,
        medals: model.medals,
        activeMilliseconds: model.activeMilliseconds,
      );
      finalRanked = false;
      boardDifficulty = model.difficulty;
      showFinalResult = true;
      _title();
      _refreshBoard();
      return;
    }
    // --- end console route
    finalRanked = true;
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
    _resetComms(resume: true);
    if (!model.restoreCheckpoint(saved)) {
      setState(() => savedCheckpoint = null);
      storage.clearCheckpoint();
      return;
    }
    // Checkpoints sit at wave entrances, before any carrier falls, so a
    // resumed run has never shown the ending (even on the fifth carrier).
    _endingShown = false;
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
    _endingShown = false;
    audioUnlock();
    audioResume();
    setState(() {
      screen = null;
      submitted = false;
      handledRunEnd = false;
      showFinalResult = false;
      heartNotice = null;
      _resetComms();
      model.start(difficulty: difficulty);
    });
    _tick();
    focus.requestFocus();
  }

  void _title({bool keepScreen = false}) {
    setState(() {
      if (!keepScreen) screen = null;
      squadComms.reset(); // --- squad comms
      transitions.end(squadComms, voice: voiceOn); // --- fluid transitions
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
      final right =
          keys.contains(LogicalKeyboardKey.arrowRight) ||
          keys.contains(LogicalKeyboardKey.keyD);
      final left =
          keys.contains(LogicalKeyboardKey.arrowLeft) ||
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
        transitions.showingCard &&
        model.mode != RunMode.paused &&
        (key == LogicalKeyboardKey.space || key == LogicalKeyboardKey.enter)) {
      _skipTransition(); // --- fluid transitions
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
    if (!model.ranked || !finalRanked) return; // console runs never POST
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
              final commsLayout = CommsLayout.of(bounds.biggest);
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
                  // --- widescreen backdrop: scenery beside the column on
                  // wide landscape screens; the comms panels stay on top.
                  if (WidescreenBackdrop.shows(bounds.biggest))
                    Positioned.fill(
                      child: IgnorePointer(
                        child: WidescreenBackdrop(
                          scene: _backdropScene(title),
                          environment: scene.environment,
                          time: scene.ambient,
                          shipX: model.shipX,
                          paused: model.mode == RunMode.paused,
                          slots: commsLayout.side && !title
                              ? commsLayout.tileRects(bounds.biggest)
                              : const [],
                        ),
                      ),
                    ),
                  // --- end widescreen backdrop
                  if (title)
                    Positioned.fill(
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            // --- widescreen backdrop: a lighter scrim keeps
                            // the bridge console visible on wide screens.
                            colors: WidescreenBackdrop.shows(bounds.biggest)
                                ? const [
                                    Color(0x00080D18),
                                    Color(0x55080D18),
                                    Color(0x66080D18),
                                  ]
                                : const [
                                    Color(0x33080D18),
                                    Color(0xAA080D18),
                                    Color(0xF5080D18),
                                  ],
                          ),
                        ),
                      ),
                    ),
                  // --- widescreen backdrop: under a score overlay the hall
                  // shows in the margins, so the landing steps aside there.
                  if (title &&
                      !(screen != null &&
                          WidescreenBackdrop.shows(bounds.biggest)))
                    _titleScreen(bounds),
                  if (!title)
                    Center(
                      child: SizedBox(
                        width: math.min(500, bounds.maxWidth),
                        child: _cabinet(bounds),
                      ),
                    ),
                  // --- squad comms: the call uses the empty side margins.
                  if (commsLayout.side && !title)
                    Positioned.fill(
                      child: IgnorePointer(
                        child: CommsAtlasScope(
                          // --- fluid transitions: a silent tip holds the
                          // call quiet (dimmed) while the music plays.
                          child: AnimatedOpacity(
                            opacity: transitions.quiet ? .35 : 1,
                            duration: const Duration(milliseconds: 500),
                            child: CommsSidePanels(
                              director: squadComms.director,
                              now: squadComms.now,
                              layout: commsLayout,
                            ),
                          ),
                        ),
                      ),
                    ),
                  if (wide && !title && !commsLayout.side)
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
                      // --- widescreen backdrop: the hall shows through the
                      // overlay's margins.
                      child: _backdropMargins(
                        bounds,
                        screen == 'ranking'
                            ? const ColoredBox(
                                color: Color(0xEE080D18),
                                child: Center(
                                  child: CircularProgressIndicator(),
                                ),
                              )
                            : _scoreOverlay(),
                      ),
                    ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  // --- widescreen backdrop: which scene stands beside the column.
  BackdropScene _backdropScene(bool title) {
    if (title) {
      return screen != null || showFinalResult
          ? BackdropScene.hall
          : BackdropScene.vista;
    }
    return switch (model.presentationMode) {
      RunMode.gameOver => BackdropScene.defeat,
      RunMode.victory || RunMode.completed => BackdropScene.victory,
      _ => BackdropScene.sector,
    };
  }

  /// Fades a full-screen overlay toward the screen edges on wide screens,
  /// keeping the centre (and everything drawn there) fully opaque.
  Widget _backdropMargins(BoxConstraints bounds, Widget overlay) {
    if (!WidescreenBackdrop.shows(bounds.biggest)) return overlay;
    final w = bounds.maxWidth;
    final inner = (math.min(w, 600) / 2) / w;
    return ShaderMask(
      blendMode: BlendMode.dstIn,
      shaderCallback: (rect) => LinearGradient(
        colors: const [
          Color(0x2EFFFFFF),
          Color(0xFFFFFFFF),
          Color(0xFFFFFFFF),
          Color(0x2EFFFFFF),
        ],
        stops: [0, .5 - inner, .5 + inner, 1],
      ).createShader(rect),
      child: overlay,
    );
  }
  // --- end widescreen backdrop

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
            _musicToggle('menu'),
            _speechToggle('menu'),
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
            TextButton(
              key: const ValueKey('menu-credits'),
              onPressed: () => _showEnding(creditsOnly: true),
              child: const Text('CREDITS', style: TextStyle(fontSize: 10)),
            ),
            if (history.everFinished)
              IconButton(
                key: const ValueKey('menu-ending-replay'),
                tooltip: 'Replay beach ending',
                onPressed: _showEnding,
                icon: const Icon(Icons.replay, size: 18),
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
      _sprite(0, 2, 84),
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
      // --- console route: a console run returns to the console from title.
      if (widget.consoleStart != null) ...[
        const SizedBox(height: 12),
        SizedBox(
          width: 280,
          child: OutlinedButton(
            key: const ValueKey('back-to-console'),
            onPressed: () => Navigator.of(context).maybePop(),
            child: const Text('◀  BACK TO CONSOLE'),
          ),
        ),
      ],
      // --- end console route
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
          if (!finalRanked) ...[
            const SizedBox(height: 6),
            _unrankedTag(key: const ValueKey('result-unranked')),
          ],
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
          key: const ValueKey('hud-score'),
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
            if (!model.ranked) ...[
              const SizedBox(height: 2),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: _unrankedTag(key: const ValueKey('hud-unranked')),
              ),
            ],
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
                    key: const ValueKey('hud-lives'),
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
                      key: const ValueKey('hud-hearts'),
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
      _musicToggle('hud'),
      _speechToggle('hud'),
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
                } else if (transitions.showingCard &&
                    model.mode != RunMode.paused) {
                  _skipTransition(); // --- fluid transitions
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
                      top: 8 + transitions.stripInset(model),
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
                  // --- fluid transitions: one primary message (interlude
                  // card, story card or carrier alert) and the slim strip.
                  if (model.cinematic && model.mode != RunMode.paused)
                    Positioned.fill(
                      child: CommsAtlasScope(
                        child: transitions.build(
                          context,
                          model: model,
                          comms: squadComms,
                          ship: scene.ship,
                          onSkip: _skipTransition,
                        ),
                      ),
                    ),
                  // --- end fluid transitions
                  // --- squad comms: compact dock at the top of the arena,
                  // below the HUD band so score, lives and hearts stay
                  // readable; it dims while the player is being hit.
                  // The interlude card is the radio while it is up.
                  if (!CommsLayout.of(bounds.biggest).side &&
                      model.mode != RunMode.paused &&
                      !transitions.showingCard)
                    Positioned(
                      key: const ValueKey('comms-hud-stack'),
                      left: 4,
                      right: 4,
                      top:
                          transitions.stripInset(model) +
                          (heartNotice != null && model.clock < heartNoticeUntil
                              ? 44
                              : 4),
                      child: CommsAtlasScope(
                        child: CommsHudStack(
                          director: squadComms.director,
                          now: squadComms.now,
                          dimmed:
                              model.combat &&
                              model.invulnerable > .4 &&
                              model.levelClock > 2.5,
                          hideTransmission: false,
                        ),
                      ),
                    ),
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
                ],
              ),
            ),
          ),
        ),
        _controller(),
      ],
    );
  }

  // A render-only view avoids updating the simulation twice when the full-screen sky is mounted.
  late final _ArenaView _arenaProxy = _ArenaView(scene);
  Widget _controller() => LayoutBuilder(
    builder: (context, bounds) => Listener(
      onPointerDown: (e) {
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
        if (touch != e.pointer) return;
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
                homingMissiles:
                    model
                        .ground
                        .salvo
                        .busy // --- ground war HUD
                    ? model.ground.salvo.loaded +
                          (model.ground.salvo.active != null ? 1 : 0)
                    : 0,
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
                _sprite(0, 10, 58),
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
  // --- audio round: Music and Speech toggles (subtitles stay on).
  Widget _musicToggle(String where) => LevelToggle(
    key: ValueKey('$where-music-level'),
    channel: 'Music',
    level: musicLevel,
    icon: Icons.music_note,
    mutedIcon: Icons.music_off,
    onChanged: _setMusicLevel,
  );
  Widget _speechToggle(String where) => LevelToggle(
    key: ValueKey('$where-speech-level'),
    channel: 'Speech',
    level: speechLevel,
    icon: Icons.record_voice_over_outlined,
    mutedIcon: Icons.voice_over_off,
    onChanged: _setSpeechLevel,
  );
  Widget _sprite(int row, int col, double size) => SizedBox(
    width: size,
    height: size,
    child: CustomPaint(painter: _SpritePainter(scene, row, col)),
  );
  // --- console route: the mark of a /console run (HUD and result).
  Widget _unrankedTag({Key? key}) => Container(
    key: key,
    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
    decoration: BoxDecoration(
      border: Border.all(color: const Color(0xFF6B5A33)),
    ),
    child: const Text(
      'CONSOLE RUN · NOT RANKED',
      style: TextStyle(fontSize: 7, letterSpacing: 1.2, color: gold),
    ),
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
        ..color = tiltActive
            ? const Color(0xFF39DFCC)
            : const Color(0xFF223647),
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
        : (steering != 0.0
              ? s.width * 0.5 + steering * (s.width * 0.26)
              : null);

    if (activeX != null) {
      // Glowing carriage indicator on rail
      c.drawRect(
        Rect.fromCenter(center: Offset(activeX, railY), width: 14, height: 4),
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
