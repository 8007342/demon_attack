/// "Fang and Wings!": the brood's battle cry and creed on the radio
/// (openspec/changes/fang-and-wings-comms design §1-§4).
///
/// - Dive war cries (`diveCry.<rank>`): each species has a voice on the
///   brood net, so a teal grunt's cry is Skritch's channel, a violet's
///   Grunnok's, a coral's Blatch's and a gold's Morth's; lines by any other
///   brood speaker fit every species.
/// - The creed stands in for some brood chatter (`fangChatter`, or the
///   `fangBanter` exchange: a brood cry, then a squad comeback) and for
///   some elite sightings (`fangTease`: a squad tease about the marks,
///   then a brood retort).
/// - Banter threads: an exchange's answer prefers the lines written for
///   its opening, so the comeback answers what was said.
///
/// All lines are written text (`"pending": "text"`) until voices land
/// (tillandsias#1103); the recorded `divePrep` cries join the grunt and
/// veteran pools with their own voices.
library;

import '../game/dive_cry.dart';
import '../game/game_events.dart';
import 'comms_types.dart';

/// The species voices on the brood net, by `Demon.kind` (teal, violet,
/// coral, gold).
const commsSpeciesVoice = ['skritch', 'grunnok', 'blatch', 'morth'];

/// A dive cry may still start this long after the dive itself starts,
/// when the squad's dive call held the channel up to it: the cry then
/// rides the plunge.
const commsCryAfter = .7;

/// The lines of a `diveCry` trigger that fit a creature of species [kind]:
/// its species voice and every voice that belongs to no species.
List<CommsLine> commsCryLines(CommsTriggerSpec spec, int kind) {
  final own = commsSpeciesVoice[kind.clamp(0, 3)];
  return [
    for (final l in spec.lines)
      if (l.speaker == own || !commsSpeciesVoice.contains(l.speaker)) l,
  ];
}

/// Recorded `divePrep` cries (by their SIGINT gloss) folded into the
/// written cry pools: the small squeaks for grunts, the wing calls for
/// veterans.
const _recordedCries = {
  'grunt': {'Watch this!', 'My turn!'},
  'veteran': {'Wings in!', 'Down we go!'},
};

/// The demon bank's cry triggers with the recorded `divePrep` cries added
/// (they keep their own clips and voices).
Map<String, CommsTriggerSpec> commsCryBank(
  Map<String, CommsTriggerSpec> demon,
) {
  final recorded = demon[GameEventNames.divePrep]?.lines ?? const [];
  return {
    for (final rank in BroodRank.values)
      if (demon['${GameEventNames.diveCry}.${rank.name}'] case final spec?)
        spec.name: spec.copyWith(
          lines: [
            ...spec.lines,
            for (final l in recorded)
              if (_recordedCries[rank.name]?.contains(l.gloss) ?? false) l,
          ],
        ),
  };
}

/// Banter threads: an opening line's id and the answers written for it.
/// An answer outside the list still fits (every comeback answers the
/// creed); the list only says which ones answer this line best.
const commsCreedThreads = <String, List<String>>{
  // Brood cry, squad comeback.
  'fangBanter.d0': ['fangBanter.h0', 'fangBanter.h7'],
  'fangBanter.d1': ['fangBanter.h1', 'fangBanter.h3'],
  'fangBanter.d2': ['fangBanter.h2', 'fangBanter.h10'],
  'fangBanter.d3': ['fangBanter.h3', 'fangBanter.h5'],
  'fangBanter.d4': ['fangBanter.h4', 'fangBanter.h9'],
  'fangBanter.d5': ['fangBanter.h6', 'fangBanter.h8'],
  'fangBanter.d6': ['fangBanter.h11', 'fangBanter.h0'],
  'fangBanter.d7': ['fangBanter.h4', 'fangBanter.h1'],
  'fangBanter.d8': ['fangBanter.h2', 'fangBanter.h5'],
  // Squad tease, brood retort.
  'fangTease.h0': ['fangTease.d5', 'fangTease.d1'],
  'fangTease.h1': ['fangTease.d3'],
  'fangTease.h2': ['fangTease.d7', 'fangTease.d6'],
  'fangTease.h3': ['fangTease.d3', 'fangTease.d2'],
  'fangTease.h4': ['fangTease.d2', 'fangTease.d0'],
  'fangTease.h5': ['fangTease.d4', 'fangTease.d0'],
  'fangTease.h6': ['fangTease.d6', 'fangTease.d7'],
};

/// Events the creed may stand in for, with the chance of each stand-in
/// (tried in order, one draw). A stand-in plays only when its own cooldown
/// allows it; otherwise the event plays as usual.
const commsCreedSwaps = <String, List<(String, double)>>{
  GameEventNames.broodChatter: [
    (GameEventNames.fangBanter, .3),
    (GameEventNames.fangChatter, .25),
  ],
  GameEventNames.eliteSighted: [(GameEventNames.fangTease, .45)],
};
