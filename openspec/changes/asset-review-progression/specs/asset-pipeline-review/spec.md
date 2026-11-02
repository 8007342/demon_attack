# Asset pipeline review

## ADDED Requirements

### Requirement: Review progression and accepted parts
The asset review surface SHALL show, for each asset family, how many parts a person has accepted out of the total. Each part SHALL appear as its own section. An accepted part SHALL be marked accepted, collapsed by default and summarised by the accepted candidate, the reviewer and the date. Open parts SHALL be listed before accepted ones. The page SHALL offer a "hide accepted parts" switch that the viewer's browser remembers, and SHALL keep working when browser storage is unavailable.

#### Scenario: Partly accepted family
- **WHEN** three of the six ship parts have recorded acceptances
- **THEN** the page reports "3 of 6 parts accepted", the three accepted sections are collapsed and listed last, and each shows its accepted candidate

#### Scenario: Hide accepted parts
- **WHEN** the reviewer turns on "hide accepted parts" and reloads the page
- **THEN** only open parts are listed, and the switch is still on

### Requirement: Selected-ship previews
Every processed candidate SHALL be previewed on the selected ship: the accepted hull plus at most one accepted module per other slot group, with the candidate replacing the module that shares its slot group. The page SHALL show the selected ship on its own and name the parts each preview includes.

#### Scenario: Wing candidate on the selected ship
- **WHEN** the hull and a nose module are accepted and a wing-cannon candidate is reviewed
- **THEN** its preview shows that candidate docked on the accepted hull with the accepted nose module

### Requirement: Ship-mode previews for nose modules
The selected ship SHALL be shown in both play modes: the single shooter (hull only, as with no powerups) and the wing shooter (hull with the accepted wing cannons). Every nose-module candidate SHALL be previewed on both.

#### Scenario: Spread candidate on both ships
- **WHEN** a hull and a wing cannon are accepted and a spread candidate is reviewed
- **THEN** the card shows the candidate on the bare hull and on the hull with wing cannons

### Requirement: Withdrawn acceptances and rejected rounds
A person SHALL be able to withdraw a part's acceptance. The part then becomes open again, and the withdrawn choice, with its reason, SHALL stay in the selection history. A rejected prompt round SHALL be removable by its seeds without affecting other rounds.

#### Scenario: Withdraw a nose module
- **WHEN** the spread acceptance is withdrawn
- **THEN** spread shows as open again with a provisional pick, and the earlier choice is listed as withdrawn in selections.json

### Requirement: Tier retirement and alternative rounds
The pipeline SHALL be able to retire model tiers: their raws and candidates leave the review, and the retired tiers are listed on the page. It SHALL refuse to retire a tier that an accepted part comes from. Further alternative rounds SHALL use seeds no earlier round has used. Review SHALL offer QA-status and model-tier filters.

#### Scenario: Retire small-model candidates
- **WHEN** tiers I0 and I1 are retired and no accepted part comes from them
- **THEN** only I2/I3 candidates remain in the review, and the page lists I0 and I1 as retired

#### Scenario: Retire a tier in use
- **WHEN** retirement names a tier that an accepted part comes from
- **THEN** the command fails, names the accepted candidate, and removes nothing

### Requirement: Upright modules
For parts declared vertical, processing SHALL rotate a clearly elongated object so its long axis is vertical and its narrower end, the muzzle, faces up, and SHALL record the rotation on the candidate.

#### Scenario: Diagonal cannon
- **WHEN** the model draws a wing cannon at a diagonal
- **THEN** the processed layer shows it upright with the muzzle on top, and the card reports the rotation angle
