# Proposal: spear-bearers (an armoured hunter with a buckler and a spear)

## Why
Operator, 2026-11-17 (verbatim): "perhaps we could also have them wielding a little shield and spear for the armored
ones later, wielding the spear as they dive, and throwing it mid dive ;) New enemy sprites :D !!"

Later tours add numbers and hit points, but no new *behaviour* a player can learn to read. The armoured ones (the
elites, R3 hunters: authored plates, the winged-fang mark) are the natural carriers: they already dive harder and
think (demon-intelligence's planner and thread dive).

## What Changes
- **A new variant, the spear-bearer** (`lib/game/spear_bearers.dart`, a `part of` the model, pure Dart): an elite that
  carries a round buckler and a spear. It appears from the third tour (route 2; Easy from route 3) in sectors 2–4
  (Easy 3–4), never on a bonus level or in the carrier sector, and it *replaces* half of the wave's hunters (the elite
  whose wave + elite ordinal is even); it adds none and draws nothing from the run's random.
- **The throw:** it dives with the spear levelled; a third of the way to the ship's row it winds up (the spear drawn
  back, a white glint on its head) for 0.55 hostile-rate seconds (0.52–0.61 s real), then throws one spear at where the
  ship is. The spear is an ordinary hostile shot (`ShotKind.spear`), so the crosswind drifts it like any other; a throw
  closer than 120 units to the ship row is withheld. It re-arms once back on its station, and it never fires the
  hunter's triple spread: the spear is its weapon.
- **The buckler is knocked away, it does not thin:** raised while diving, it blocks shots from the front (never a
  homing missile) one point per point of damage, 2 points for the creature's whole life, never refreshed; then it
  tumbles off and the bearer dives bare. It replaces the thermal dive shield while it lasts (no stacking); the dive it
  is lost in gets no thermal shield, later dives the hunter's own.
- **Lightning** (lightning-rework): a stunned bearer drops its guard (the buckler blocks nothing) and loses its wind-up.
- **Sprites** (`tools/spear_bearers`, Go, offline, byte-identical): idle, levelled, wind-up and release (empty claw)
  spear frames; carried, raised, hit and knocked-away buckler frames; the thrown spear at five leans; the glint.
  Overlays on the shipped gargoyles, like the elite armour. Picks in `plan/render-runs/spear-bearers.md`.
- **Hooks for parallel work:** the throw is the structured event `spearThrow` (the war cry hook for
  fang-and-wings-comms); the bearer wears the hunter's rank mark (`SpearBearerPainter.rankOf`, the insignia-ranks hook).
- **Gallery:** a `spear-bearers` scene page (every state on the four species, and one whole dive in a loop).

## Impact
- Code: new `lib/game/spear_bearers.dart`, `lib/game/spear_bearer_painter.dart`, generated
  `lib/game/spear_bearer_atlas.dart`; hooks (`// --- spear-bearers`) in `model.dart` (Demon field, birth flag, three
  birth sites, dive shield, the step, the triple spread, the hit), `scene.dart`, `shot_layer.dart`, `game_events.dart`,
  the gallery, `web/audio/demon-audio.js` (four synth sounds).
- Assets: `assets/images/spear-bearers.png` (3 KB); `art/contact/spear-bearers*.png`.
- Balance: unseeded calibration gates on routes 2–4 change (design §6, `plan/calibration-current.md`).
- Specs: new capability `spear-bearers`.
- Tests: `test/spear_bearers_test.dart`, `tools/spear_bearers` `go test`.
