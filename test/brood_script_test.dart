import 'package:demon_attack/comms/brood_script.dart';
import 'package:demon_attack/comms/comms_view.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('repeated words retain the same original signs across messages', () {
    final word = BroodScript.encode('SKY');
    expect(BroodScript.encode('sky'), word);
    expect(BroodScript.encode('MY SKY').skip(3), word);
    expect(BroodScript.encode('SKY, SKY!'), [...word, -1, ...word]);
    final shapes = {
      for (var letter = 0; letter < 26; letter++)
        AlienGlyphPainter.glyph(letter)
            .map((row) => row.map((on) => on ? '1' : '0').join())
            .join(),
    };
    expect(shapes.length, 26, reason: 'all alphabet signs must be distinct');
  });

  test('translation follows glyphs and completes before the line retires', () {
    String at(double age, {bool reduce = false}) =>
        BroodScript.translation('Our sky!', age, 2, reduceMotion: reduce);
    expect(at(0), '');
    expect(at(.24), '');
    expect(at(.5), isNotEmpty);
    expect(at(1).length, lessThan('Our sky!'.length ~/ 2 + 1));
    expect(at(2), 'Our sky!');
    expect(at(5), 'Our sky!', reason: 'retained opener stays readable');
    expect(at(0, reduce: true), 'Our sky!');
    expect(BroodScript.translation('Hi!', 1, .15, reduceMotion: false), 'Hi!');
  });
}
