/// Music volume is constant: speech never ducks it, effects never
/// side-chain it, and nothing but the player's music level changes it.
/// The behaviour itself is tested in test-worker/comms-audio.test.mjs (the
/// music gain while clips play); this guards the sources the Dart side
/// drives through lib/services/comms_audio_web.dart and audio_web.dart.
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final comms = File('web/audio/comms-audio.js').readAsStringSync();
  final music = File('web/audio/demon-audio.js').readAsStringSync();
  String code(String js) => js
      .replaceAll(RegExp(r'/\*[\s\S]*?\*/'), '')
      .replaceAll(RegExp(r'//[^\n]*'), '');

  test('speech playback never touches the music bus', () {
    final c = code(comms);
    expect(c, isNot(contains('duck')));
    expect(
      c,
      isNot(
        matches(
          RegExp(r'music\s*\.\s*gain\s*\.\s*(set|linear|exponential|cancel)'),
        ),
      ),
    );
    expect(c, isNot(contains('demonAudio.setLevel')));
    expect(c, isNot(contains('demonAudio.mute')));
  });

  test('no side-chain or life-loss dip on the music', () {
    final m = code(music);
    expect(m, isNot(contains('sidechainDip')));
    expect(m, isNot(contains('dropMusic')));
    expect(
      m,
      isNot(
        matches(
          RegExp(
            r'(drop|sidechain|music)\.gain\.(setTargetAtTime|linearRamp|exponentialRamp|setValueAtTime)',
          ),
        ),
      ),
    );
  });

  test('the speech toggle changes only the speech level', () {
    final setLevel = RegExp(
      r'function setLevel\(channel, value\) \{([\s\S]*?)\n  \}',
    ).firstMatch(code(music))!.group(1)!;
    // Speech is forwarded to the voice bus; applyLevels only reads the
    // music level for the music.
    expect(setLevel, contains("window.commsAudio?.setLevel?.(value)"));
    final apply = RegExp(r'function applyLevels\(\) \{([\s\S]*?)\n  \}')
        .firstMatch(code(music))!
        .group(1)!;
    expect(apply, contains('musicLevels[levels.music]'));
    expect(apply, isNot(contains('levels.speech]')));
  });
}
