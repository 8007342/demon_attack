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
  static const routeDetails = [
    [
      'A lost signal flickers beyond the frontier outpost. Follow it inward.',
      'Crowded roofs shelter the last frontier families. Hold their sky.',
      'Cargo cranes line the dark piers. Reopen the fleet supply route.',
      'Relay lights climb the mountain ridges. Trace their hidden signal.',
      'Uplink arrays surround frontier command. Break the brood blockade.',
    ],
    [
      'Abandoned satellites mark the route through the planetary rings.',
      'Patrol relays sweep the belt. Slip between their watch stations.',
      'Broken hulls drift among the rocks. The brood left no survivors.',
      'Orbital gantries cradle unfinished warships. Cut their supply line.',
      'Fortress pylons seal the rings. Open a path for the fleet.',
    ],
    [
      'Ember light reveals a foundry signal beneath the volcanic crust.',
      'Ash drifts over buried settlements. The foundries are still awake.',
      'Furnace stacks feed the brood engines. Silence their production.',
      'Lava channels converge at the crucible. Push through the heat.',
      'The brood heart burns beneath the forges. Extinguish its beacon.',
    ],
    [
      'Ancient towers answer one command. Follow it into the hollow.',
      'Ruined arches mark the outskirts. Something watches from within.',
      'Tiered towers relay the command signal. Break their chain.',
      'Buried vaults pulse beneath the ruins. Their defenses are waking.',
      'The throne beacon calls the last carrier. Sever its command.',
    ],
    [
      'The carrier guards the inward route. Break its field; time the hatch.',
      'The ark carries a new brood. Strike before it reaches the frontier.',
      'Siege armor shields the next carrier. Watch for its opening.',
      'The citadel commands the shipyards. Bring its fortress hull down.',
      'The flagship guards their base. This is the final stand.',
    ],
  ];
  static String briefing(int level, int cycle) =>
      routeDetails[(level - 1).clamp(0, 4)][cycle.clamp(0, 4)];
  static String arrival(int level, int cycle) =>
      '${name(level, cycle)}. ${briefing(level, cycle)}';
  static String departure(int level, int cycle) =>
      '${name(level, cycle)} is secure. The fleet follows your signal inward.';
  static String tourEscalation(int nextCycle) => switch (nextCycle) {
    1 => 'EMERGENCY BEACON DETECTED: The falling Carrier broadcasted distress coordinates into uncharted Krybor depths. Mutated brood swarms awaken across Tour II!',
    2 => 'BROOD MUTATION INTENSIFIES: Ancient volcanic foundries beneath Ember Moon ignite under hive command. Heavier armor and thermal shields detected across Tour III!',
    3 => 'CITADEL COUNTER-ATTACK: Siege dreadnoughts mobilize from the Hollow catacombs. Severe atmospheric storm fronts and apex predators awaken across Tour IV!',
    4 => 'FINAL CONVERGENCE: The Brood Flagship locks orbit over the planetary heart. Total fleet victory or extinction across Tour V!',
    _ => 'DEEP SECTOR RE-ENTRY: Brood reinforcements detected across the star system.',
  };

  static String travel(int level, int cycle) {
    if (level == 5 && cycle >= 4) {
      return 'The frontier is free. Return home, fleet champion.';
    }
    if (level == 5) {
      final nextLevel = 1;
      final nextCycle = cycle + 1;
      return '${tourEscalation(nextCycle)} Set course for ${name(nextLevel, nextCycle)}. ${briefing(nextLevel, nextCycle)}';
    }
    final nextLevel = level + 1;
    return 'Set course for ${name(nextLevel, cycle)}. ${briefing(nextLevel, cycle)}';
  }
}
