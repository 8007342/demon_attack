# Proposal

## Why
The route into demon territory needs distinct worlds and narrative progression, while repeated carrier victories must meaningfully expand the same run. Recovery windows should let players collect earned powers, and the landing page should present the shared score chase immediately.

## What Changes
- Five original sector backdrops with different terrain, planetary systems, satellites and escalating demonic occupation; cinematic captions tell the journey and later-cycle escalation.
- Inline Top10 on the title, automatic loading and retry, retaining only the constrained initials entry overlay.
- Piloting and falling pickups during wave entrances, plus protected two-second final-wave salvage before celebration.
- Later cycles add waves, species diversity, roster density, multi-molt elite creatures and aggressive telegraphed attacks while preserving score/lives/powers.
- Verify two carrier victories in one run, generate/review sector artwork, reload local Wrangler, and merge the validated game branch into main as explicitly requested.

## Capabilities
### New Capabilities
None.
### Modified Capabilities
- `arcade-combat`: richer bounded repeat-cycle progression and elite behavior.
- `arcade-presentation`: distinct complex sector worlds and inline title scores.
- `arcade-progression`: collectible/pilotable recovery phases and added later-cycle waves.
- `high-scores`: Top10 embedded in the landing page with independent network status.
- `demon-attack`: title identity with Start and immediately visible scores.

## Impact
Dart model, Flame world rendering and original PNGs, Flutter title/score flow, progression and widget/browser tests, OpenSpec and plan guides. No new storage format, personal data, or backend API. Main push triggers the existing automatic production deployment after checks pass.
