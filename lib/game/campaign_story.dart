/// Named destinations share a world theme while approaching the brood base.
abstract final class CampaignStory {
  static const destinations = [
    [
      'Krybor',
      'Krybor Slums',
      'Krybor Docks',
      'Krybor Mountains',
      'Krybor Command',
    ],
    [
      'Ringfall',
      'Ringfall Patrol Belt',
      'Ringfall Wreckfields',
      'Ringfall Shipyards',
      'Ringfall Blockade',
    ],
    [
      'Ember Moon',
      'Ember Ashlands',
      'Ember Forges',
      'Ember Crucible',
      'Ember Brood Heart',
    ],
    [
      'The Hollow',
      'Hollow Outskirts',
      'Hollow Towers',
      'Hollow Catacombs',
      'Hollow Throne',
    ],
    [
      'The Carrier',
      'Brood Ark',
      'Siege Carrier',
      'Brood Citadel',
      'Brood Flagship',
    ],
  ];
  static const arrivals = [
    'Follow the lost frontier signal. Rescue the outpost and chart the route inward.',
    'Patrol satellites mark the enemy supply route. Break through their watch.',
    'Heat signatures rise beneath the ash. Silence the brood foundries.',
    'The towers answer a single command. Trace it through the ancient hollow.',
    'The carrier guards the brood heart. Break its field and strike through the hatch.',
  ];
  static const victories = [
    'The frontier signal is restored. The fleet has recognized your service.',
    'The patrol is broken. The fleet has recognized your courage.',
    'The foundries fall silent. The fleet has recognized your resolve.',
    'The command towers are dark. The fleet has recognized your valor.',
    'The carrier falls. The fleet has recognized your labor.',
  ];
  static String name(int level, int cycle) =>
      destinations[(level - 1).clamp(0, 4)][cycle.clamp(0, 4)];
  static String arrival(int level, int cycle) =>
      '${name(level, cycle)}. ${arrivals[(level - 1).clamp(0, 4)]}';
  static String travel(int level, int cycle) {
    if (level == 5 && cycle >= 4) {
      return 'The Brood Flagship is falling. The frontier is free. Return home, fleet champion.';
    }
    final nextLevel = level == 5 ? 1 : level + 1;
    final nextCycle = level == 5 ? cycle + 1 : cycle;
    return '${victories[(level - 1).clamp(0, 4)]} Set course for ${name(nextLevel, nextCycle)}. ${level == 5 ? 'The recovered charts reveal a deeper route toward their base.' : 'Follow the signal before the brood regroups.'}';
  }
}
