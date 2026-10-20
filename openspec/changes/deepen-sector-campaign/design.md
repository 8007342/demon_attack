# Design

## Context
The deployed prototype has a single illustrated sky with hue changes, frozen interwave pickups, one fixed wave count per cycle and a modal Top10. Existing cutscenes and MIDI transitions are retained. Main specs were synchronized from the two completed implementation changes before this proposal.

## Goals / Non-Goals
Goals: distinct sector geography, visible deep-territory progression, recoverable pickup windows, accessible inline scores and meaningful repeated-loop complexity.
Non-goals: changing score storage, personal information, new control gestures, or resetting runs after the carrier.

## Decisions
- Separate canPilot from combat. Shared ship/pickup stepping runs during interwave entrance and salvage, while enemy simulation, damage and fire stay disabled. Two seconds of salvage uses144 units/s pickup descent; normal descent remains64. Power timers only decrease during combat.
- Preserve same-run score, lives, kill count and powers. Add min(cycle,3) waves, bounded roster bonuses and mixed species. Selected elites gain two HP up to7, visible extra plates/horns and fan/diving attacks with readable warnings. Cap roster24 and hostile shots120.
- Load five generated original PNG worlds and crossfade complete world compositions during travel. Draw independently moving moons, orbital satellites and territory structures with density tied to level/cycle. Keep the central playfield dark.
- Embed a shared board widget in the landing page; desktop uses two columns and mobile a single scroll. Fetch state is separate from score entry and gameplay. Request generations prevent stale GETs overwriting accepted POST results. A submit failure keeps the three wheels and value; success returns the updated landing board.
- Narrative captions describe outpost, patrol belt, spawning moons, brood ruins and carrier territory, with later-cycle language reflecting adaptation.

## Risks / Trade-offs
- Art may obscure threats → dark center, limited moving decorations, inspect all5 sectors with live bullet/sprite overlays.
- Endless complexity can become unreadable → cap speed1.8, waves+3, roster24, eliteHP7 and projectiles120; keep attack telegraphs.
- Title data can stall start → independent fetch/error state and always enabled Start.
- A high pickup may not reach the player in2seconds → accelerate salvage descent and retain movement throughout the grace window.

## Migration Plan
No backend migration. Verify model loops, pickup controls, inline scores, all sector imagery, release build and local browser. Push game checkpoints, then merge validated game into main and push the production trigger, returning checkout to game.
