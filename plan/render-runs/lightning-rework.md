# Render ledger: lightning rework (rod armour, stun, zap)

Direction: operator, 2026-11-17: "higher ranking gargoyles should avoid lightning much better, or even wear armor with
lightning rods that will empower them ;)" and "stun them for a moment, and have them drop of the sky".
Change: `openspec/changes/lightning-rework` (design §5). Style guide: `docs/styleguide/alien-troops.md` §5.4, §5.5.
The operator delegated the picks (project memory "autonomy"); made 2026-11-17 on `work/lightning-rework`.

## Pipeline and why
A procedural painter, `lib/game/weather/lightning_painter.dart` (`LightningPainter.rods`, `stunSparks`, `ship`). The
gear is an overlay drawn in each creature's own transform, so it scales with perspective, fades with the fog reveal
and tumbles with the stun, on every species and tour, without a new row in `combat.png`. The troop atlas pipeline
(`tools/generate_sprites.py`, Pillow) has no venv in this forge, and a painter needs no GPU, no model download and no
committed raws: the code is the recipe, and every frame is a pure function of the model and the clock.

## How to rebuild
```sh
flock ~/.cache/tillandsias-project/flutter-test.lock \
  flutter test --concurrency=1 --run-skipped --tags review test/lightning_rework_review_test.dart
# art/contact/lightning-rework-rods.png   the three candidates, phone size and 3x, cold and charged
# art/contact/lightning-rework-storm.png  tell + static, bolt + stun, zap + shards + modules, climb back; reduced motion
```

## Picks
| Item | Candidates | Pick | Why | Rejected because |
|---|---|---|---|---|
| Rod layout | shoulders, crest, crown (`RodStyle`) | **shoulders** | Two rods frame the head and leave the head anchor to the rank glyph (§4); a pair of spikes still reads at phone size on a drone-sized hunter; on the sentinel the two tips and the arc between them read as "antenna" at once | **crest**: one rod rises straight out of the skull, exactly where the glyph sits, and at 1x it reads as a single stray pixel line. **crown**: three tips merge into one blob at 1x and echo the R4 winged-crown glyph (three rising fangs), which would confuse rank |
| Rod colour | brood iron + bone tip | iron `#2E2A33`, edge `#5A5262`, bone `#E9DFC8` | the brood's own metal and the insignia's bone; no cyan or teal | — |
| Charged look | tint, halo, arc | white tips + violet-white halo + one arc | reads as light (Stormfront's palette), never a hue change on the body, so rank tones keep meaning | a body tint fought the wound warm-up (§6) |
| Stun | ring, stars, arcs | four short white arcs with a violet glow + a tumble | "dazed and open"; no ring, so it never reads as a shield | a ring read as a force shield (§5.1) |
| Ship zap | — | burst, three arcs, 20 Hz flicker for 0.45 s, shield ring in eight shards, modules tumbling | the loss is visible on the ship itself, without text over the play area (Stormfront's rule) | — |

Note: the review harness does not load the insignia atlas, so the glyphs are absent from the sheets; the anchor rule
(the glyph sits on the head, `CombatAtlas.headAnchor`) is what the pick is judged against. Operator override welcome.
