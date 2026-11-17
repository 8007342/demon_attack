/// The music mix (mix-balance): speech ducks the music only through
/// demonAudio.duck / unduck, on its own stage; effects never side-chain it,
/// the life loss never dips it, and the speech toggle changes only speech.
/// The behaviour itself is tested in test-worker/mix-balance.test.mjs (levels
/// metered end to end, the duck's depth and ramps); this guards the sources
/// the Dart side drives through lib/services/comms_audio_web.dart and
/// audio_web.dart.
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final comms = File('web/audio/comms-audio.js').readAsStringSync();
  final music = File('web/audio/demon-audio.js').readAsStringSync();
  String code(String js) => js
      .replaceAll(RegExp(r'/\*[\s\S]*?\*/'), '')
      .replaceAll(RegExp(r'//[^\n]*'), '');
  String body(String js, String name) =>
      RegExp('function $name\\(([^)]*)\\) \\{([\\s\\S]*?)\\n  \\}')
          .firstMatch(code(js))!
          .group(2)!;

  test('speech reaches the music only through the duck', () {
    final c = code(comms);
    expect(c, contains('demonAudio?.duck?.('));
    expect(c, contains('demonAudio?.unduck?.('));
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

  test('effects and the life loss never dip the music', () {
    final m = code(music);
    expect(m, isNot(contains('sidechainDip')));
    expect(m, isNot(contains('dropMusic')));
    expect(
      m,
      isNot(
        matches(
          RegExp(
            r'(drop|music)\.gain\.(setTargetAtTime|linearRamp|exponentialRamp|setValueAtTime)',
          ),
        ),
      ),
    );
    for (final name in ['sfx', 'accent', 'groundSfx']) {
      expect(body(music, name), isNot(contains('duck')), reason: name);
    }
    // The duck stage is automated in one place.
    expect(RegExp(r'sidechain\.gain').allMatches(m).length, 1);
    expect(body(music, 'planDuck'), contains('const gain = sidechain.gain'));
  });

  test('the speech toggle changes only the speech level', () {
    final setLevel = body(music, 'setLevel');
    // Speech is forwarded to the voice bus; applyLevels only reads the
    // music level for the music.
    expect(setLevel, contains("window.commsAudio?.setLevel?.(value)"));
    final apply = body(music, 'applyLevels');
    expect(apply, contains('musicLevels[levels.music]'));
    expect(apply, isNot(contains('levels.speech]')));
  });
}
