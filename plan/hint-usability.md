# Illustrated arrival hints

Research checked 2026-10-22. First-wave arrivals replace the repeated destination story caption with one actionable illustrated gameplay hint. Travel, carrier collapse and recognition retain their story roles. This document separates published guidance from the project's concrete tuning choices.

## Source guidance

| Primary source | Relevant guidance, paraphrased | Application here |
| --- | --- | --- |
| [Microsoft Xbox Accessibility Guideline 116: Time limits](https://learn.microsoft.com/en-us/xbox/accessibility/xbox-accessibility-guidelines/116) | Disappearing tutorial windows are timed UI. Players may need more time to notice, interpret and act. Offer control over duration, including at least ten times the default or disabling the limit. | A short default cannot be the only opportunity to learn. Keep a pause/hold action and an untimed review path; the Field Guide also offers a persistent automatic-advance switch before play. |
| [W3C: Understanding Timing Adjustable](https://www.w3.org/WAI/WCAG22/Understanding/timing-adjustable) | Author-controlled timing can prevent understanding. An equivalent alternative that does not depend on a timer can remove that timing dependency. | Provide the same hints and meaningful illustrations in an untimed Field Guide available before play and during pause. |
| [W3C: Understanding Pause, Stop, Hide](https://www.w3.org/WAI/WCAG22/Understanding/pause-stop-hide.html) | Auto-updating messages need user control; the five-second threshold for some moving content does not exempt auto-updating information. Resuming from the paused point suits reading tasks. | Hold the current hint, its image and remaining time. Resume that same card rather than selecting another or jumping to combat. |
| [Apple Human Interface Guidelines: Onboarding](https://developer.apple.com/design/human-interface-guidelines/onboarding) | Context-specific instruction helps players concentrate on one current task. Keep teaching brief, optional where possible, and easy to revisit. Safe interaction can reinforce learning. | Show one relevant tactic, avoid premature enemy/power advice, and retain a discoverable Field Guide. Practice occurs in the next encounter rather than adding a compulsory tutorial. |
| [Microsoft Xbox Accessibility Guideline 114: UI context](https://learn.microsoft.com/en-us/xbox/accessibility/xbox-accessibility-guidelines/114) | Players need clear context, understandable labels near what they describe, and readable instruction language. | Pair an action-first sentence with the exact mechanic's picture. Label Hold, Resume and Field Guide clearly; do not bury the tactic in story prose. |
| [Microsoft Xbox Accessibility Guideline 101: Text display](https://learn.microsoft.com/en-us/xbox/accessibility/xbox-accessibility-guidelines/101) | Readability depends on actual rendered size, contrast, spacing and viewing conditions, including small screens; adjustable presentation is preferable. | Verify full-sized text and illustration at narrow phone and landscape dimensions rather than judging a desktop mockup or reducing text to fit. |

These sources do not prescribe a universally sufficient exposure time for a five-to-nine-word illustrated hint. They also do not establish that randomization improves comprehension. The exact word budget, 4.5-second interval and shuffled selection below are project decisions informed by their principles, to be checked in playtesting. This is design research, not a claim of full WCAG or Xbox guideline conformance.

## Content and timing contract

- Show one five-to-nine-word actionable sentence and one matching original pixel illustration. Prefer a concrete verb and consequence over a feature name or slogan. Keep destination identification separate and brief.
- Use a 4.5-second first-wave arrival interval, replacing the former approximately 2.633-second arrival for these cards. Keep both text and image readable throughout; no typewriter text, late image reveal, scrolling or attention-demanding background animation consumes that interval.
- Hold/Pause freezes the card, countdown and game state. The player can read indefinitely, then explicitly Resume with the same hint and remaining interval. Merely opening the Field Guide must never resume combat.
- Let players disable automatic advance in the Field Guide before play. Persist the choice; each arrival then waits for Continue indefinitely.
- Offer the untimed Field Guide from landing and pause. It contains the same actionable lines and illustrations; any explanatory detail belongs there, not in the short arrival card. Keep access available after a card disappears.
- Choose from an eligible shuffled bag and avoid repeating a hint until that eligible bag is exhausted. Do not repeat across a bag boundary when another eligible card exists. Select once at entrance, not on widget rebuild or every simulation tick.
- Filter by actual rules and current encounter: no heart-collection advice in Hard, no sentinel tactics before a boss victory in the current run, and no promise of unavailable powers or protections. A universally applicable movement/control hint is a safe fallback.
- Keep illustrations instructional: show the relevant ship, projectile, enemy or pickup and the useful relationship between them. One picture may show a compact before/after sequence, but avoid a collage of unrelated mechanics. Text remains real UI text rather than lettering baked into the image. Provide an equivalent semantic description when the image carries information beyond the sentence.

## Shield tactic: verify cause and effect

The implementation in `lib/game/model.dart` grants one second of invulnerability when an active shield absorbs a hit, consuming that shield. Collecting another shield during this interval restores a fresh nine-second shield without cancelling the remaining protection. The fresh shield is not consumed by a hit while invulnerability is active. An unused shield reaching the end of its timer grants no new invulnerability.

An accurate short hint is: **Absorb a hit, then grab another shield.** Its picture can show shield impact, the protected ship and a nearby fresh shield pickup. The Field Guide can explain that the hit provides a brief safe collection window if a pickup is reachable. Do not advise waiting for the shield timer to expire, imply guaranteed access to a replacement, or represent the grace interval as indefinite immunity. Validation must exercise the actual hit → grace → pickup sequence as well as expiry without a hit.

## Review

Review at narrow portrait and short landscape sizes: the sentence fits without clipping, the action is evident from the image, controls remain reachable, and the card does not overlap mandatory HUD information. Test the 4.5-second default with unfamiliar players; if they cannot identify the recommended action, simplify the picture/copy or increase exposure. Verify indefinite hold, unchanged card after resume, untimed review, contextual filtering, and non-repetition. Check shield claims against the simulation whenever mechanics change.
