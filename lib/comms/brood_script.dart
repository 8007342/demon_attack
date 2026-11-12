/// Original 26-sign brood alphabet. A sign depends on its letter, never on
/// the clip id, frame clock, or position in a message. Spaces retain words.
library;

class BroodScript {
  static List<int> encode(String meaning) => [
    for (final code in meaning.toUpperCase().codeUnits)
      if (code >= 65 && code <= 90)
        code - 65
      else if (code == 32 || code == 45)
        -1,
  ];

  /// Translation starts a quarter second after the glyphs. Reduced motion
  /// exposes the full meaning immediately, as does the retained opener.
  static String translation(
    String meaning,
    double age,
    double duration, {
    required bool reduceMotion,
  }) {
    if (reduceMotion || age >= duration) return meaning;
    final progress = ((age - .25) / (duration - .25).clamp(.3, 1000.0)).clamp(
      0.0,
      1.0,
    );
    return String.fromCharCodes(
      meaning.runes.take((meaning.runes.length * progress).floor()),
    );
  }
}
