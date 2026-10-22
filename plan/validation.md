# Playable checkpoint validation — 2026-10-20

Branch: `game`. No production deployment or main merge performed.

## Automated checks

- `flutter analyze`: no issues.
- `flutter test`: 17 passing tests. Covers lives, respawn grace, power expiry, movement bounds, fixed-step stability, armor/anger, all four waves, boss shield/door gating, actual final-shot collision and evolved restart, phone/desktop layouts, Enter/P input, visible star rendering, score serialization and errors, and three-wheel initials with failed-submit retry preserving B9A / 12345.
- `npm run test:worker`: 4 passing tests. Real SQLite Top10 ordering/eviction and ties; strict initials, body and score bounds; API routing and origin validation; MIDI gesture unlock, scheduling, cue transitions, mute, pause/resume, fourth boss intensity and victory cadence continuation.
- `npm run build`: release web build succeeds, including local renderer, original sprite atlas/sky, synth JavaScript and fifteen MIDI assets.
- `openspec validate --all --strict`: main specs and active change pass.
- Wrangler deployment dry run passes; recognizes HIGH_SCORES SQLite Durable Object and ASSETS bindings. No remote deployment.

## Browser and managed preview

`tools/browser-smoke.cjs` ran against the actual sibling Wrangler service on desktop 1280×900 and phone 390×844. Enter starts without a mouse fallback. Arrows, pointer/touch drag and P pause/resume work. Title emblem, player, demon wingbeats, explosion effects, stars, planetary layers and controller panel render correctly. MIDI requests return200. No console errors or browser runtime exceptions.

Screenshots were captured at `/tmp/demon-title.png`, `/tmp/demon-play.png` and the corresponding `-phone.png` files. These temporary captures are review evidence, not shipped assets.

Managed API smoke accepted TST / 0, returned it in subsequent GETs, and rejected malformed initials. The managed service was then recreated to refresh the final preview. Its ephemeral local SQLite state resets when that sibling container is replaced; a fresh board was observed after recreation. Production uses Cloudflare Durable Object storage, not this ephemeral local container. A local container replacement is different from ordinary score requests or a production Worker update.

The host-browser tool still fails HTTPS navigation with ERR_CONNECTION_CLOSED on this host. Standalone Playwright Chromium reached the sibling directly and provided the browser validation above. The user's existing host browser can use https://www.demon-attack.localhost:18443/.

## Playtest focus

Review touch sensitivity, projectile readability, wave pacing, boss door timing, and perceived music intensity on the actual device. Music generation and scheduling are tested; human listening remains the final check for musical taste and mix. Client-submitted scores are a casual honor board and remain forgeable. Native sound needs a separate adapter; the deployed web game has the MIDI synthesizer.


## Multiwave and cinematic update

The smooth-level-progression checkpoint passes flutter analyze, all21 Flutter tests, all4 backend/audio tests, strict OpenSpec validation, and a new release web build. A dedicated renderer test loads the shipping pixel atlas and sky, confirms different victory/travel frames, checks exact pixel equality during pause, and checks that departure-to-travel and travel-to-arrival black-fade boundaries match. Review images are in .cache/cinematics/ (ignored by Git).

The model tests traverse all14 waves before the carrier (3/3/4/4), verify same-level pickup preservation, protected cutscene power timers, 72 shield hits and24 gated core hits, 5.5-second carrier triumph, 4-second sector celebrations, 4-second travel, and retained score/lives on the next cycle. Immediate level-clear, continuing victory cadence, travel and next-level MIDI handoffs pass audio scheduler tests. The soundtrack now contains17 original MIDI files.

The rebuilt game was republished to the managed sibling Wrangler runtime at the usual HTTPS preview URL. Standalone Chromium verifies phone and desktop Enter start, arrows, controller drag, pause/resume, synthesizer presence and successful MIDI loading against the actual sibling service. The visible host Chromium tool continues to report ERR_CONNECTION_CLOSED; browser availability is reported separately from the running service.


The alternate host browser successfully opened a visible WebKit window at the managed HTTPS preview URL after a one-time91-second engine preparation. Its window ID is win-0d463d5e-34f1-4404-b311-08421870248d. This engine has no CDP controls in the current host tools, so automated browser verification used standalone Chromium. The managed score API returned valid JSON after republishing. Main remains at the previously approved release; the pacing update is on game.


## Sector campaign and continuous-run update

Flutter analysis and all32 tests pass, alongside the4 backend/audio tests and release web build. New tests exercise two complete carrier-defeat handoffs in one run, retained state, bounded growth through cycle100, elite HP up to7 and attacks, keyboard/touch piloting and collection in both recovery phases, initial/retried inline Top10 on phone/desktop, five materially distinct sector renderings with hostile/friendly overlays, background animation, exact pause identity, and black cinematic handoffs. The five generated worlds were visually reviewed at .cache/sectors/sector-{1..5}-play.png.

The old fixed first-creature HP expectation was replaced with mixed-species escalation assertions. A real fallback regression was fixed: stars now remain visible before any sector image is loaded, without brightening the shipped art behind combat. Recovery stops hostile damage/fire while retaining movement and falling items; powers freeze until combat resumes. Current tuning is documented in game-design.md and sector-style-guide.md.


The final actual-Wrangler browser pass succeeds on desktop 1280×900 and phone 390×844: initial Top10 GET returns200, inline scores and mobile scroll are checked, Enter starts, arrows/pointer/touch pilot, P pause/resume works, and all7 MIDI responses per viewport succeed. No runtime or console errors. The browser driver inspects the accessibility scoreboard and then reloads for an independent raw-keyboard test; this prevents its activated semantics DOM from stealing canvas focus. Score API smoke returned valid JSON. A fresh visible WebKit window was opened at the managed local preview URL.


## Combined temporary powers

Analysis, all38 Flutter tests, all4 backend/audio tests, strict OpenSpec validation and the release web build pass. New checks cover simultaneous spread/rapid volleys, independent nine-second expiry and type-only refresh, shield-only consumption, protected timer retention, and clearing powers for a new game. Widget checks verify all three colored glyph layers remain visible, expired/consumed layers disappear independently, and touching the combined badge still pilots the ship on a390×844 viewport. The rendered composite was visually reviewed at .cache/powers/combined-glyph.png.

The managed sibling Wrangler preview was refreshed and opened in a visible WebKit window at https://www.demon-attack.localhost:18443/.

Actual-Wrangler Chromium smoke passes on desktop and phone: inline Top10, Enter start, arrows, controller drag, pause/resume and seven successful MIDI responses per viewport; no runtime exceptions or console errors.

## Combat refinements and illustrated arrivals — 2026-10-22

- Flutter analysis: no issues; full Flutter suite: 105 passing tests. Worker suite: 8 passing tests. Strict OpenSpec validation: 11 items pass (existing archive advisory on the unrelated smooth-level-progression delta remains).
- Tests cover finite reinforcement flocks, protected sentinel escorts, real shields/armor, shot evasion, fast sentinel bolts, carrier starting-direction variation and damage acceleration, four-quarter heart migration/assembly, mutually replacing offensive powers, Powerful damage and Large splash with carrier gates, Hard-to-Easy unlock migration, contextual nonrepeating hints, shield-hit grace/refill, pause stability, untimed guide and persistent manual-advance choice.
- Release web build succeeds. Managed local Wrangler was stopped before build and recreated afterwards; no production deployment or main merge.
- Browser smoke passes desktop 1280×900 and phone 390×844 gameplay/keyboard/controller/audio; campaign smoke passes desktop, phone and landscape 844×390 with unlocked-mode boards, medal/time/life metadata, compatible checkpoint migration and reload. The browser harness now waits for the longer arrival hint before checking active piloting.
- Original hint illustrations reviewed at native size and in phone runtime captures. The separate 1254×1254 atlas uses explicit crop rectangles and nearest-neighbor drawing, with exact gameplay heart/power overlays. Combat supplemental atlas now 1024×640 with articulated flight/dive frames.
- Hint research and project timing choices are documented in plan/hint-usability.md. The 4.5-second default is adjustable through Hold and a persistent automatic-advance switch; the Field Guide is untimed. The taught shield strategy is hit consumption → one-second invulnerability → fresh pickup, not passive timer expiration.
- Dedicated hint browser smoke passes phone and landscape: manual cards remain after five seconds, the guide opens/closes without resuming, Continue starts play, illustration asset loads 200, and no runtime exceptions occur. Reviewed captures: /tmp/demon-hint-{phone,landscape}.png and /tmp/demon-guide-{phone,landscape}.png.

## Final session polish — 2026-10-22

The final user decision replaces guide/hold/menu/manual settings with automatic loading-only hints. Ten contextual hints now include stronger later enemies, boss extra lives and five-medal completion. Initial swarm entrances wait offscreen for the hint to clear. Final scores load the matching board and open initials directly when qualifying; full-board ties remain below the board as a personal result, matching the server's older-first ties. Ranking unavailability preserves submission access and failed submissions retain initials. Heart interiors use color without dark seams. The controller reserves proportional left/right slots so all combined powers/timers stay inside beside stable pilot guidance.

Flutter:115 tests pass, analysis clean. Worker:8 tests pass. Strict OpenSpec: 11 items pass. Added checks cover score thresholds90/100/101 against tenth-place100, automatic loading despite legacy manual preferences, offscreen/frozen/deferred swarm arrival, and power-console containment/drag input across widths240–1100. Original art scene checks cover all ten illustrated hints.

Final release build succeeded. Refreshed managed Wrangler browser checks pass: desktop/phone gameplay and keyboard/controller/audio, desktop/phone/landscape campaign boards and checkpoint migration/reload, and phone/landscape automatic hints without extra controls. Reviewed phone hint/swarm runtime captures. No browser runtime exceptions or console errors. Preview remains available at https://www.demon-attack.localhost:18443/.

Merged game into main with merge 88d2630 and pushed both branches; upstream confirmed durable acceptance. All 43 tracked campaign tasks are complete.

## Reinforcement pressure and carrier field — 2026-10-22

Normal now replenishes from the first route with two to three finite flocks; Hard has two to four and later Easy has two. The first casualty brings replenishment within about 0.6 seconds, with successive groups larger and tougher. Every sentinel receives a separate fresh 12–20-enemy escort larger than ordinary reinforcement groups, independent of previous arrivals, reserving capacity within a 61-enemy cap. Regression tests verify first-casualty timing, multiple stronger groups, fresh escort identity after earlier reinforcements, capacity, and protected sentinel staging. Complete real-shot simulated campaigns finish in all difficulties; the heavier Hard campaign requires a larger simulation ceiling.

The carrier field stays 220 units wide outside its 184-unit hull and contracts in depth from 75 toward 43 as it depletes. Rendering, flank projectile interception and hit flashes share the model's surface. Tests verify symmetry, full width at low strength, pre-damage impact positions, and continued closed-hatch protection after the field breaks. Native full/low-field captures in .cache/cinematics were reviewed; the illustrated carrier_field hint was added and reviewed.

Full Flutter suite: 119 tests pass. Flutter analysis: clean. Worker suite: 8 tests pass. Strict OpenSpec: 11 items pass. Release web build succeeds.

Refreshed managed local Wrangler and passed desktop/phone gameplay controls/audio, desktop/phone/landscape campaign boards and compatible checkpoint reload, plus phone/landscape automatic illustrated hints and delayed initial entrances. No browser runtime exceptions or console errors. The local preview is ready to reload.
