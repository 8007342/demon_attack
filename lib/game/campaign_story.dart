/// Route descriptions are shared by arrivals, victories and later-cycle travel.
abstract final class CampaignStory {
  static const arrivals = [
    'The frontier outpost is falling silent. Follow the signal beyond Krybor.',
    'Patrol satellites watch the rings. The swarms are guarding a route inward.',
    'The eclipsed moons are spawning grounds. Something below is waking.',
    'Brood towers fill the hollow. Every signal points to the carrier.',
    'The fortress guards the brood heart. Break the shield. Time the hatch.',
  ];
  static const victories = [
    'Krybor survives. The signal leads into the orbital patrol belt.',
    'The patrol is broken. Follow the brood toward the burning moons.',
    'The hatcheries fall quiet. Ancient towers answer from the hollow.',
    'The towers lose their signal. The carrier is exposed at last.',
    'The carrier falls, but the brood remembers. The frontier is changing.',
  ];
  static String arrival(int level, int cycle) => cycle == 0
      ? arrivals[level - 1]
      : '${arrivals[level - 1]} The brood has adapted: cycle ${cycle + 1}.';
  static String travel(int level, int cycle) => level == 5
      ? 'A new brood rises. Return to Krybor: cycle ${cycle + 2}, faster and more evolved.'
      : victories[level - 1];
}
