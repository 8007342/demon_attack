# Battle Metal and radio research

## Halo source and decision — 2026-11-12
Primary testimony: Marty O'Donnell, 9 April 2016, [Ask Marty Anything](https://destiny.bungie.org/forum/index.php?id=109418&mode=thread), reply “Question 3” at 23:26. O'Donnell explains that Elite placeholders used Sergeant Johnson performances with lowered pitch and reversal, and that this treatment shipped. He separately describes higher-pitched marine placeholders for Grunts, later replaced by Joe Staten performances with upward pitch treatment. This supports the Elite technique specifically, not a universal claim about all Halo alien voices. The account provides no definitive pitch interval or DSP settings for Elites.

Decision for Demon Attack: generate our own expressive performances, then audition per-character downward pitch and reversal; retain the playfulness and cadence of taunts. Do not sample Halo or clone its actors. Keep original clean and transformed lossless masters. Derive lip motion from transformed output rather than unreversed speech or radio noise. Select pitch, formant handling and processing by listening; do not represent untested numeric settings as established facts. Final pitch presets and listening results remain pending rendering/review.

## Musical references
User references Through the Fire and Flames and Dawn Over a New World for long-form build, power-metal arrangement and fluid development. These are creative references supplied by the user, not analyzed recordings. Preserve approved metal identity of levels 1/3/4, strengthen 2/5, permit a quiet early opening, and develop toward the final boss. Original themes, no melodic copying; wordless vocals approved.

## Recovery checkpoint
Scope/specs are in openspec/changes/battle-metal-radio-rework. Implemented changes and review status must be recorded there before remote checkpoints. Large local assets are not crash-safe merely because their manifest is committed. Establish durable master storage before rendering the complete bank.

## Credits reference access
Access resolved after the user made the repository public. Inspected [credits_page.dart](https://github.com/8007342/kumbia-kombat/blob/a922b434b280bd4db15d9933da23250d9083f4d2/lib/credits/credits_page.dart), credits_data.dart, assets/credits.json, and the credits change design/spec at the same commit. The credits lead with Tillandsias.org; list platforms, tools, models and packages from actual records; distinguish direct from deeper dependencies by text size/columns; scroll with touch hold and close; and follow final campaign completion. Browser audio can be resumed by gesture. Its manifest explicitly marks current credits music as a stand-in, so it is not evidence of a finished dedicated reprise.

Decision: use this organization with Demon Attack's own verified records and a Lua generator. Follow our beach cinematic with a warm original reprise, readable mobile credits, reduced-motion/manual scrolling, close/skip, and replay access. Do not copy the sibling dependency list, versions, music or contributor names. Reading this reference is complete; building and validating our credits remains pending.
