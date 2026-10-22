import 'dart:math';

import 'package:demon_attack/game/hints.dart';
import 'package:demon_attack/game/difficulty.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('catalog has unique illustrated tactics with short readable copy', () {
    expect(
      tacticalHints.map((hint) => hint.id).toSet().length,
      tacticalHints.length,
    );
    expect(tacticalHints, hasLength(7));
    for (final hint in tacticalHints) {
      expect(hint.title.split(RegExp(r'\s+')).length, lessThanOrEqualTo(8));
      expect(hint.detail.split(RegExp(r'\s+')).length, lessThanOrEqualTo(12));
      expect(hint.scene, hint.id);
    }
    final shield = tacticalHints.singleWhere(
      (hint) => hint.id == 'shield_refresh',
    );
    expect(shield.title, contains('Absorb a hit'));
    expect(shield.title.toLowerCase(), isNot(contains('expir')));
  });

  test('seeded decks exhaust eligible rounds without boundary repeats', () {
    for (final difficulty in Difficulty.values) {
      final first = HintDeck(random: Random(82));
      final second = HintDeck(random: Random(82));
      final eligible = tacticalHints
          .where((hint) => hint.isEligible(difficulty))
          .map((h) => h.id)
          .toSet();
      String? previous;
      for (var round = 0; round < 5; round++) {
        final seen = <String>{};
        for (var card = 0; card < eligible.length; card++) {
          final hint = first.next(difficulty: difficulty, level: 2, route: 1);
          expect(
            hint.id,
            second.next(difficulty: difficulty, level: 2, route: 1).id,
          );
          expect(hint.id, isNot(previous));
          expect(seen.add(hint.id), isTrue);
          previous = hint.id;
        }
        expect(seen, eligible);
      }
    }
  });

  test('Hard never teaches hearts and first-route entrances hide giants', () {
    final deck = HintDeck(random: Random(1));
    for (var i = 0; i < 60; i++) {
      final hint = deck.next(difficulty: Difficulty.hard, level: 1 + i % 5);
      expect(hint.id, isNot('heart_quarters'));
      expect(hint.id, isNot('giant_rush'));
    }
    expect(
      tacticalHints
          .where((hint) => hint.isEligible(Difficulty.hard))
          .any((hint) => hint.id == 'heart_quarters'),
      isFalse,
    );
  });

  test(
    'new pilots see varied fundamentals and first carriers get hatch guidance',
    () {
      final openings = <String>{};
      for (var seed = 0; seed < 20; seed++) {
        final deck = HintDeck(random: Random(seed));
        final intro = deck.next(difficulty: Difficulty.normal);
        expect({
          'heart_quarters',
          'ordinary_dodge',
          'shield_refresh',
        }, contains(intro.id));
        openings.add(intro.id);
        expect(
          deck.next(difficulty: Difficulty.normal, level: 5).id,
          'carrier_hatch',
        );
      }
      expect(openings, hasLength(3));
    },
  );

  test(
    'changing eligible context preserves unseen cards and avoids repeats',
    () {
      final deck = HintDeck(random: Random(2));
      String? previous;
      for (var i = 0; i < 100; i++) {
        final hint = deck.next(
          difficulty: Difficulty.values[i % 3],
          level: 1 + i % 5,
          route: i % 2,
        );
        expect(hint.id, isNot(previous));
        previous = hint.id;
      }
    },
  );
}
