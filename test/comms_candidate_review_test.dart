// Opt-in review renderer. Reads retained candidates without promoting a partial
// audio bank. Lua/ffmpeg can mux these exact 30 Hz frames with radio.ogg.
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:demon_attack/comms/comms_bank.dart';
import 'package:demon_attack/comms/comms_director.dart';
import 'package:demon_attack/comms/comms_types.dart';
import 'package:demon_attack/comms/comms_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

const output = String.fromEnvironment('COMMS_CANDIDATE_REVIEW');
const ids = String.fromEnvironment(
  'COMMS_CANDIDATES',
  defaultValue: 'reinforcements.h0,reinforcements.d0',
);
const font = String.fromEnvironment('COMMS_REVIEW_FONT');

void main() {
  testWidgets('render retained voices with actual portrait timing', (
    tester,
  ) async {
    await tester.runAsync(() async {
      await CommsPortraitAtlas.instance.load();
      if (font.isNotEmpty) {
        final data = File(font).readAsBytesSync();
        await (FontLoader(
          'Roboto',
        )..addFont(Future.value(ByteData.sublistView(data)))).load();
      }
      for (final id in ids.split(',')) {
        expect(RegExp(r'^[A-Za-z0-9_.-]+$').hasMatch(id), isTrue);
        final source =
            'assets/research/battle-metal-radio/batch-2026-11-12/voices/$id';
        final data = jsonDecode(
          File('$source/metadata.json').readAsStringSync(),
        ) as Map<String, dynamic>;
        final demon = data['kind'] == 'demon';
        final line = CommsLine(
          id: 'review:$id',
          speaker: data['speaker'],
          duration: (data['samples'] as int) / 24000,
          text: demon ? null : data['text'],
          grunt: demon ? 'order' : null,
          gloss: demon ? data['text'] : null,
          mouth: data['mouth'],
          open: data['open'],
          vis: data['vis'],
          emotion: data['emotion'],
        );
        final trigger = CommsTriggerSpec(
          name: 'review',
          priority: 1,
          cooldown: 0,
          ttl: 10,
          lines: [line],
        );
        final message = CommsMessage(
          trigger: trigger,
          line: line,
          character: commsCast[line.speaker]!,
          priority: 1,
          queuedAt: 0,
          readyAt: 0,
          expiresAt: 100,
          sequence: 0,
        )..startedAt = 1;
        final slot = CommsSlot(0)
          ..occupant = line.speaker
          ..since = 0;
        final dir = Directory('$output/$id')..createSync(recursive: true);
        final count = ((line.duration + .5) * 30).ceil();
        for (var frame = 0; frame < count; frame++) {
          final time = frame / 30;
          final recorder = ui.PictureRecorder();
          final canvas = Canvas(recorder);
          canvas.drawColor(const Color(0xFF090D18), BlendMode.src);
          for (final (x, y, side) in [
            (8.0, 45.0, 128.0),
            (264.0, 45.0, 48.0),
          ]) {
            canvas.save();
            canvas.translate(x, y);
            CommsTilePainter(
              slot: slot,
              message: message,
              now: 1 + time,
              reduceMotion: false,
              zoom: 1,
              cast: commsCast,
            ).paint(canvas, Size.square(side));
            canvas.restore();
          }
          void text(String value, Offset at, double size) {
            final p = TextPainter(
              text: TextSpan(
                text: value,
                style: TextStyle(
                  fontFamily: 'Roboto',
                  color: Colors.white,
                  fontSize: size,
                ),
              ),
              textDirection: TextDirection.ltr,
            )..layout(maxWidth: 344);
            p.paint(canvas, at);
          }

          text(
            '$id · ${line.speaker} · ${time.toStringAsFixed(2)} s',
            const Offset(8, 8),
            12,
          );
          text(data['text'], const Offset(8, 180), 12);
          final picture = recorder.endRecording();
          final image = await picture.toImage(360, 220);
          final png = await image.toByteData(format: ui.ImageByteFormat.png);
          File('${dir.path}/${frame.toString().padLeft(4, '0')}.png')
              .writeAsBytesSync(png!.buffer.asUint8List());
          image.dispose();
          picture.dispose();
        }
        File('${dir.path}/source.json').writeAsStringSync(
          jsonEncode({
            'candidate': '$source/metadata.json',
            'audio': '$source/radio.ogg',
            'fps': 30,
            'frames': count,
            'duration': line.duration,
            'scope': 'actual runtime painter at desktop 128px and phone 48px',
            'acceptance': 'pending audiovisual review',
          }),
        );
      }
    });
  }, skip: output.isEmpty);
}
