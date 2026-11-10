// Audio round: the Music and Speech toggles (Mute / Low / Full) on the menu
// and in the play HUD, and the power-up music layer events.
import 'dart:io';
import 'dart:ui' as ui;

import 'package:demon_attack/comms/squad_comms.dart';
import 'package:demon_attack/game/model.dart';
import 'package:demon_attack/game/music_director.dart';
import 'package:demon_attack/main.dart';
import 'package:demon_attack/services/run_storage.dart';
import 'package:demon_attack/services/scores.dart';
import 'package:demon_attack/widgets/level_toggle.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

/// Review frames: --dart-define=AUDIO_RENDER=/abs/dir (never the checkout),
/// with --dart-define=AUDIO_FONTS=/dir/with/Roboto-Regular.ttf,Roboto-Bold.ttf
/// for real glyphs.
const renderDir = String.fromEnvironment('AUDIO_RENDER');
const _fontDir = String.fromEnvironment('AUDIO_FONTS');
bool _fontsLoaded = false;

Future<void> _loadFonts() async {
  if (_fontsLoaded || _fontDir.isEmpty) return;
  _fontsLoaded = true;
  final roboto = FontLoader('Roboto');
  for (final name in ['Roboto-Regular.ttf', 'Roboto-Bold.ttf']) {
    final file = File('$_fontDir/$name');
    if (file.existsSync()) {
      roboto.addFont(
        Future.value(ByteData.sublistView(file.readAsBytesSync())),
      );
    }
  }
  await roboto.load();
  final icons = File('build/unit_test_assets/fonts/MaterialIcons-Regular.otf');
  if (icons.existsSync()) {
    final loader = FontLoader('MaterialIcons')
      ..addFont(Future.value(ByteData.sublistView(icons.readAsBytesSync())));
    await loader.load();
  }
}

Future<void> _snap(WidgetTester tester, String name) async {
  if (renderDir.isEmpty) return;
  final boundary = tester.renderObject(
    find.byKey(const ValueKey('page')),
  ) as RenderRepaintBoundary;
  await tester.runAsync(() async {
    final image = await boundary.toImage();
    final png = await image.toByteData(format: ui.ImageByteFormat.png);
    final file = File('$renderDir/$name.png');
    await file.parent.create(recursive: true);
    await file.writeAsBytes(png!.buffer.asUint8List());
    image.dispose();
  });
}

Future<void> _launch(WidgetTester tester, Size size) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  if (renderDir.isNotEmpty) await tester.runAsync(_loadFonts);
  await tester.pumpWidget(
    MediaQuery(
      data: MediaQueryData(size: size),
      child: MaterialApp(
        home: RepaintBoundary(
          key: const ValueKey('page'),
          child: ArcadePage(
            scoreService: ScoreService(
              client: MockClient(
                (_) async => http.Response('{"scores":[]}', 200),
              ),
            ),
            runStorage: RunStorage(store: MemoryLocalStore()),
            squadComms: SquadComms(playAudio: false, lineupSeed: 5),
          ),
        ),
      ),
    ),
  );
  await tester.pump();
}

LevelToggle _toggle(WidgetTester tester, String key) =>
    tester.widget<LevelToggle>(find.byKey(ValueKey(key)));

void main() {
  test('levels cycle Mute -> Low -> Full -> Mute and parse safely', () {
    expect(AudioLevel.mute.next, AudioLevel.low);
    expect(AudioLevel.low.next, AudioLevel.full);
    expect(AudioLevel.full.next, AudioLevel.mute);
    expect(AudioLevel.parse('low'), AudioLevel.low);
    expect(AudioLevel.parse(null), AudioLevel.full);
    expect(AudioLevel.parse('eleven'), AudioLevel.full);
  });

  for (final size in const [Size(360, 780), Size(1280, 800)]) {
    final name = '${size.width.toInt()}x${size.height.toInt()}';
    testWidgets('music and speech toggles on the menu and in the HUD ($name)', (
      tester,
    ) async {
      await _launch(tester, size);
      // Menu: both toggles in the top bar, starting at Full.
      expect(_toggle(tester, 'menu-music-level').level, AudioLevel.full);
      expect(_toggle(tester, 'menu-speech-level').level, AudioLevel.full);
      await _snap(tester, 'menu-$name');
      await tester.tap(find.text('START GAME  →'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      final music = find.byKey(const ValueKey('hud-music-level'));
      final speech = find.byKey(const ValueKey('hud-speech-level'));
      expect(music, findsOneWidget);
      expect(speech, findsOneWidget);
      final toggles = [tester.getRect(music), tester.getRect(speech)];
      final pause = tester.getRect(find.byTooltip('Pause game'));
      for (final key in ['hud-score', 'hud-lives', 'hud-hearts']) {
        final r = tester.getRect(find.byKey(ValueKey(key)));
        for (final t in toggles) {
          expect(t.overlaps(r), isFalse, reason: '$key $r vs toggle $t');
        }
      }
      expect(toggles[0].overlaps(toggles[1]), isFalse);
      expect(toggles[1].overlaps(pause), isFalse);
      for (final t in toggles) {
        expect(t.width, greaterThanOrEqualTo(36), reason: 'tap target');
        expect(t.height, greaterThanOrEqualTo(40), reason: 'tap target');
        expect(t.right, lessThanOrEqualTo(size.width));
        expect(t.top, greaterThanOrEqualTo(0));
      }
      expect(find.text('FULL'), findsNWidgets(2));
      await _snap(tester, 'hud-full-$name');
      // Each tap cycles one channel only.
      await tester.tap(music);
      await tester.pump();
      expect(_toggle(tester, 'hud-music-level').level, AudioLevel.mute);
      expect(_toggle(tester, 'hud-speech-level').level, AudioLevel.full);
      await tester.tap(speech);
      await tester.pump();
      await tester.tap(speech);
      await tester.pump();
      expect(_toggle(tester, 'hud-speech-level').level, AudioLevel.low);
      expect(find.text('OFF'), findsOneWidget);
      expect(find.text('LOW'), findsOneWidget);
      await _snap(tester, 'hud-off-low-$name');
      await tester.tap(music);
      await tester.pump();
      await tester.tap(music);
      await tester.pump();
      expect(_toggle(tester, 'hud-music-level').level, AudioLevel.full);
      // Speech muted turns the squad voices off (subtitles stay).
      await tester.tap(speech);
      await tester.pump();
      await tester.tap(speech);
      await tester.pump();
      expect(_toggle(tester, 'hud-speech-level').level, AudioLevel.mute);
      final page = tester.state(find.byType(ArcadePage)) as dynamic;
      expect(page.voiceOn, isFalse);
      expect(page.squadComms.voiceOn, isFalse);
    });
  }

  group('power-up music layer', () {
    test(
      'the director publishes active powers and falling pickups on change',
      () {
        final events = <GameEvent>[];
        final director = MusicDirector(emit: events.add);
        final m = ArcadeModel()..restoreCheckpoint({'level': 2, 'wave': 1});
        m.mode = RunMode.playing;
        List<GameEvent> power() => [
          for (final e in events)
            if (e.name == GameEventNames.musicPowerLayer) e,
        ];
        director.observe(m, 1 / 60);
        expect(power(), isEmpty, reason: 'nothing to report at rest');
        m.pickups.add(Pickup(100, 100, Power.spread));
        director.observe(m, 1 / 60);
        expect(power().last.data, {'active': 0, 'falling': true, 'level': 2});
        m.pickups.clear();
        m.powerTimers[Power.spread] = 8;
        director.observe(m, 1 / 60);
        director.observe(m, 1 / 60);
        expect(power().length, 2, reason: 'only changes are published');
        expect(power().last.data, {'active': 1, 'falling': false, 'level': 2});
        m.powerTimers[Power.rapid] = 8;
        director.observe(m, 1 / 60);
        expect(power().last.data['active'], 2);
        m.powerTimers.clear();
        director.observe(m, 1 / 60);
        expect(power().last.data['active'], 0);
        m.powerTimers[Power.shield] = 5;
        director.observe(m, 1 / 60);
        m.mode = RunMode.levelClear;
        director.observe(m, 1 / 60);
        expect(power().last.data, {'active': 0, 'falling': false});
      },
    );

    test('the bridge forwards the power layer to the audio engine', () {
      final calls = <(int, bool)>[];
      final bridge = MusicBridge(
        onIntensity: (_) {},
        onAccent: (_) {},
        onFleetIntact: () {},
        onPowerLayer: (active, falling) => calls.add((active, falling)),
      );
      bridge(
        const GameEvent(GameEventNames.musicPowerLayer, {
          'active': 2,
          'falling': true,
        }),
      );
      bridge(const GameEvent(GameEventNames.musicPowerLayer));
      expect(calls, [(2, true), (0, false)]);
    });
  });
}
