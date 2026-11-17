import 'dart:convert';
import 'dart:io';

import 'package:demon_attack/comms/comms_one_line.dart';
import 'package:flutter/painting.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// carrier-hatches §A12: radio subtitles that must fit one line at the
/// dock's larger size. The flagged triggers (the carrier hints at least)
/// are at most [commsOneLineMax] characters, and laid out at 14.5 px in a
/// 360-px phone's full-width strip they take one line.
void main() {
  final bank = jsonDecode(
    File('art/comms/lines.json').readAsStringSync(),
  ) as Map<String, dynamic>;
  final triggers = bank['triggers'] as Map<String, dynamic>;

  Iterable<(String, String)> textsOf(String trigger) sync* {
    final t = triggers[trigger] as Map<String, dynamic>;
    for (final l in (t['lines'] as List? ?? const [])) {
      final m = l as Map<String, dynamic>;
      yield (m['speaker'] as String, (m['text'] ?? m['gloss']) as String);
    }
    final demon = t['demon'] as Map<String, dynamic>?;
    for (final l in (demon?['lines'] as List? ?? const [])) {
      final m = l as Map<String, dynamic>;
      yield (m['speaker'] as String, m['gloss'] as String);
    }
  }

  test('flagged one-line lines are at most 28 characters', () {
    for (final trigger in commsOneLineTriggers) {
      expect(triggers.containsKey(trigger), isTrue, reason: trigger);
      final texts = textsOf(trigger).toList();
      expect(texts, isNotEmpty, reason: trigger);
      for (final (speaker, text) in texts) {
        expect(
          text.length,
          lessThanOrEqualTo(commsOneLineMax),
          reason: '$trigger ($speaker): "$text" is ${text.length} characters',
        );
      }
    }
  });

  test('the carrier hints are written lines with their own words', () {
    for (final trigger in const [
      'bossHintHatches',
      'bossHintTiming',
      'bossHintLead',
    ]) {
      final t = triggers[trigger] as Map<String, dynamic>;
      expect(t['pending'], 'text', reason: trigger);
      expect((t['lines'] as List), hasLength(1), reason: 'one line each');
    }
    expect(textsOf('bossHintHatches').single.$2, 'Destroy the hatches!');
    expect(textsOf('bossHintTiming').single.$2, 'Time the open hatch!');
    expect(textsOf('bossHintLead').single.$2, 'Fire ahead of its position!');
  });

  test('census: the bank against the one-line limit (printed)', () {
    var all = 0, over = 0, longest = 0;
    for (final trigger in triggers.keys) {
      for (final (_, text) in textsOf(trigger)) {
        all++;
        if (text.length > commsOneLineMax) over++;
        if (text.length > longest) longest = text.length;
      }
    }
    // ignore: avoid_print
    print(
      'COMMS_LINES $all lines, $over over $commsOneLineMax, longest $longest',
    );
    expect(all, greaterThan(600));
  });

  // The phone strip, full width on a 360-px arena: 360 − 2 × 8 (margins)
  // − 40 (portrait) − 8 (gap) = 296 px for the tag and the text.
  const stripText = 296.0;
  const monoFont =
      '/home/forge/.cache/tillandsias-project/dart/dart-sdk/bin/resources/'
      'devtools/assets/fonts/Roboto_Mono/RobotoMono-Regular.ttf';
  final hasFont = File(monoFont).existsSync();

  testWidgets('the hints lay out on one line at 14.5 px on a 360-px phone', (
    tester,
  ) async {
    await tester.runAsync(() async {
      final loader = FontLoader('monospace')
        ..addFont(
          Future.value(ByteData.sublistView(File(monoFont).readAsBytesSync())),
        );
      await loader.load();
    });
    for (final trigger in commsOneLineTriggers) {
      for (final (speaker, text) in textsOf(trigger)) {
        final p = TextPainter(
          text: TextSpan(
            style: const TextStyle(
              fontFamily: 'monospace',
              fontSize: commsStripFont,
              height: 1.15,
            ),
            children: [
              TextSpan(
                text: '${speaker.toUpperCase()}  ',
                style: const TextStyle(
                  fontSize: commsStripTagFont,
                  fontWeight: FontWeight.bold,
                  letterSpacing: .8,
                ),
              ),
              TextSpan(text: text),
            ],
          ),
          maxLines: 1,
          textDirection: TextDirection.ltr,
        )..layout(maxWidth: stripText);
        // ignore: avoid_print
        print('COMMS_ONE_LINE $trigger ${p.width.toStringAsFixed(1)} px');
        expect(p.didExceedMaxLines, isFalse, reason: '$trigger: "$text"');
        p.dispose();
      }
    }
  }, skip: !hasFont);
}
