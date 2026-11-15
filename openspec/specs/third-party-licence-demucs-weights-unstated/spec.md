# Third-party licence: demucs-weights-unstated

@trace spec:third-party-licence-demucs-weights-unstated

## Purpose
This project depends on adefossez/HTDemucs and adefossez/HTDemucs-6s and must now adhere to attribution, non-commercial and review, the obligations its licence `demucs-weights-unstated` carries. The operator acknowledged this licence for `project:demon_attack`, use `non-sale`, until 2027-11-14T00:00:00Z; the signed record is `licences/acknowledgements/adefossez-htdemucs.yaml`. Demucs separation serves internal analysis and reference only: separated audio never ships and the weights are never redistributed (see `plan/audio-studio/music-requirements.md`, Constraints).

## Requirements

### Requirement: Attribution
The project SHALL credit Demucs as "Demucs, Alexandre Défossez" wherever it credits the models used in its production.

The licence says, verbatim: "The 6 source variant of htdemucs was trained only on Meta internal dataset, which likely means CC-NC-BY license is applicable, as it was the case for all models released by FAIR."

How this project honours it: the credits show "Demucs, Alexandre Défossez" among the production models, marked as used for analysis and reference only.

#### Scenario: Credits name Demucs
- **WHEN** a player or reviewer opens the game's credits
- **THEN** they find "Demucs, Alexandre Défossez" listed as a production model used for analysis and reference

### Requirement: Non-commercial
The project SHALL use HTDemucs and HTDemucs-6s only for non-commercial, internal analysis and reference, and SHALL NOT ship any audio separated by them or redistribute their weights.

The licence says, verbatim: "The 6 source variant of htdemucs was trained only on Meta internal dataset, which likely means CC-NC-BY license is applicable, as it was the case for all models released by FAIR."

How this project honours it: Demucs stems are used only to analyse and to serve as listening and measurement references; every shipped sound is rendered from the project's own sources by tools whose licences allow commercial use; the weights stay in the user's model cache and are never bundled in the repo, an image or a release.

#### Scenario: Separated stems stay internal
- **WHEN** a Demucs-separated stem exists in the production workspace
- **THEN** it lives outside the repo's shipped assets, and no shipped audio file is derived from it

#### Scenario: Weights are not redistributed
- **WHEN** a build, image or release is assembled
- **THEN** it contains no HTDemucs or HTDemucs-6s weights

### Requirement: Review
The project SHALL treat the licence of the Demucs weights as unresolved and SHALL re-review this acknowledgement before it expires or before any use beyond internal analysis and reference.

The licence says, verbatim: "The license of the weights is not clear: MusDB contains some data that were only usable for research purpose. I sadly cannot help granting a license, both coming from Meta custom data, or from the original MusDB data."

How this project honours it: the acknowledgement expires on 2027-11-14 and is renewed only by a fresh signed review; any proposal to ship Demucs-derived audio is refused and needs a separator whose weights allow commercial use instead.

#### Scenario: Expiry forces a review
- **WHEN** the date passes 2027-11-14T00:00:00Z
- **THEN** the acknowledgement no longer admits the weights until the operator signs a new one after reviewing the licence

#### Scenario: Wider use is refused
- **WHEN** someone proposes shipping audio separated by Demucs
- **THEN** the proposal is declined under this spec and a commercially licensed separator or native stem rendering is used instead
