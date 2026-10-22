import 'dart:math';

import 'difficulty.dart';

/// A short entrance prompt and its matching, pre-generated field-guide picture.
class TacticalHint {
  const TacticalHint({
    required this.id,
    required this.title,
    required this.detail,
    required this.scene,
    this.requiresHearts = false,
    this.requiresLaterRoute = false,
  });

  final String id, title, detail, scene;
  final bool requiresHearts, requiresLaterRoute;

  /// The persistent guide can show future tactics, but hides impossible pickups.
  bool isEligible(Difficulty difficulty) =>
      !requiresHearts || difficulty != Difficulty.hard;
}

const List<TacticalHint> tacticalHints = [
  TacticalHint(
    id: 'carrier_field',
    title: 'Wear down the field. Expose the carrier.',
    detail: 'The force field catches shots until depleted; then target the open hatch.',
    scene: 'carrier_field',
  ),

  TacticalHint(
    id: 'stronger_swarm',
    title: 'Later waves grow stronger. Watch for shields.',
    detail:
        'Enemy shields and armor absorb hits before the creature takes damage.',
    scene: 'stronger_swarm',
  ),
  TacticalHint(
    id: 'boss_reward',
    title: 'Beat the boss. Earn another life.',
    detail: 'Every defeated carrier awards one medal and one extra life.',
    scene: 'boss_reward',
  ),
  TacticalHint(
    id: 'campaign_medals',
    title: 'Collect all five medals. Liberate the frontier.',
    detail: 'Defeat five carriers to earn all five campaign medals.',
    scene: 'campaign_medals',
  ),

  TacticalHint(
    id: 'heart_quarters',
    title: 'Fit four quarters. Earn another life.',
    detail: 'Fill one heart with four different quarters; duplicates use other slots.',
    scene: 'heart_quarters',
    requiresHearts: true,
  ),
  TacticalHint(
    id: 'carrier_hatch',
    title: 'Break the shield. Fire through the hatch.',
    detail: 'The core takes damage only while the central hatch is open.',
    scene: 'carrier_hatch',
  ),
  TacticalHint(
    id: 'ordinary_dodge',
    title: 'Watch the wings, then sidestep the dive.',
    detail: 'A creature signals before diving toward your earlier position.',
    scene: 'ordinary_dodge',
  ),
  TacticalHint(
    id: 'shield_refresh',
    title: 'Absorb a hit, then grab another shield.',
    detail:
        'One second of protection lets you collect fresh shields or weapons.',
    scene: 'shield_refresh',
  ),
  TacticalHint(
    id: 'powerful_choice',
    title: 'Choose heavier shots or faster fire.',
    detail: 'POWERFUL hits twice as hard and replaces RAPID.',
    scene: 'powerful_choice',
  ),
  TacticalHint(
    id: 'large_choice',
    title: 'Choose explosions or a wider spread.',
    detail: 'LARGE replaces SPREAD; explosions reach nearby enemies and open carrier hatches.',
    scene: 'large_choice',
  ),
  TacticalHint(
    id: 'giant_rush',
    title: 'Move aside when a giant commits.',
    detail: 'Its final rush follows one straight line; move after the warning.',
    scene: 'giant_rush',
    requiresLaterRoute: true,
  ),
];

/// Draw once at a sector entrance and retain the result while rendering/paused.
/// Each eligible hint is used once per shuffled round, including across mode or
/// route changes; an exhausted round cannot immediately repeat its last card.
class HintDeck {
  HintDeck({Random? random}) : _random = random ?? Random();

  final Random _random;
  final Set<String> _roundSeen = {}, _introduced = {};
  String? _lastId;

  TacticalHint next({
    required Difficulty difficulty,
    int level = 1,
    int route = 0,
  }) {
    final eligible = tacticalHints
        .where(
          (hint) =>
              hint.isEligible(difficulty) &&
              (!hint.requiresLaterRoute || route >= 1) &&
              (!{'carrier_hatch', 'carrier_field'}.contains(hint.id) ||
                  level >= 3 ||
                  route >= 1),
        )
        .toList();
    var candidates = eligible
        .where((hint) => !_roundSeen.contains(hint.id))
        .toList();
    if (candidates.isEmpty) {
      _roundSeen.clear();
      candidates = List.of(eligible);
    }
    if (candidates.length > 1) {
      candidates.removeWhere((hint) => hint.id == _lastId);
    }
    candidates.shuffle(_random);
    TacticalHint? preferred;
    if (_lastId == null && level == 1 && route == 0) {
      preferred = candidates
          .where(
            (hint) => const {
              'heart_quarters',
              'ordinary_dodge',
              'shield_refresh',
            }.contains(hint.id),
          )
          .firstOrNull;
    } else if (level == 5 && !_introduced.contains('carrier_hatch')) {
      preferred = candidates
          .where((hint) => hint.id == 'carrier_hatch')
          .firstOrNull;
    }
    final selected = preferred ?? candidates.first;
    _roundSeen.add(selected.id);
    _introduced.add(selected.id);
    _lastId = selected.id;
    return selected;
  }
}
