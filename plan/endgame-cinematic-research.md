# End-game cinematic: craft and pipeline research

Change `endgame-cinematic` (operator round 3d, E1, `plan/operator-feedback-2026-11-16.md`). Research and planning
only: nothing was rendered, queued, downloaded or installed. Three researchers worked under the lead on 2026-11-16:
a detail inventory (`plan/endgame-reveal-ledger.md`), Part A (craft) and Part B (pipeline) below.

Provenance follows `CLAUDE.md` §8. A source marked `read 2026-11-16` was fetched that day. A source marked
`unread: snippet only` does not make its claim sourced. Claims with no read source carry
`[UNSOURCED: plan/provenance-audit.md#endgame-…]`; all 33 ids are listed in Part E of `plan/provenance-audit.md`.
The forge proxy blocked most film and animation sites and several licence hosts on that day. Nothing was routed
around it. Read the limits before relying on Part A: sections A1 to A9 rest mostly on course notes, small blogs and
answers read through the Stack Exchange API, and their main attributions (the Coats rules, the story spine,
Stanton, Thomas and Johnston, Murch) are unsourced until the blocked pages can be read. The rules drawn from them
are design decisions of this change and are labelled as such.

## 0. Answers to the operator's questions

| Question | Answer | Where |
|---|---|---|
| Does it need its own storyboard? | Yes, and it has one: eight boards, a shot list with timings, cameras, transitions and lines | `art/storyboards/endgame/` |
| Does it need its own guidelines? | Yes: look, cast, figures, colour script, tone, review gates | `docs/styleguide/endgame-cinematic.md` |
| Does it need its own ComfyUI pipeline? | No. It needs a new *family type* (a shot family) on the pipeline the project already has: one bpy layout script on rigkit, the committed Qwen-edit, BiRefNet and Fun VACE workflows, one packer verb in rigsheet, and a small player in the game | B1, B7 |
| Does it need new models? | Not for the baseline: every model it needs is on the studio's disk today. Three optional downloads raise quality, each behind a consent token | B2, B11 |
| Can it be "Pixar level"? | In design, light, lenses, colour and sound: that is the aim, and stills from open models can carry it. In character animation: no local route reaches it, so the scene is staged to need very little | B1, B4, B12 |
| How does it play in the game? | As an in-engine layered 2.5D scene, not a video file. That gives one scene for portrait and landscape, subtitles as text, a reduced-motion version, details that change with the run, and tests. A video cut stays a later option | B6 |
| How long? | 29 seconds in seven shots, plus a 3-second button after the credits. Skippable from the first frame | A5, A10; storyboard |
| What makes a second run pay off? | 167 ledger rows: each detail in the scene is something the game already shows or says. 18 first-run plant lines and 8 bolder ones that unlock after the ending. Seven details of the scene change with the run | `plan/endgame-reveal-ledger.md` |

### Where the lead departed from the researchers' rules

| Rule | Departure | Reason |
|---|---|---|
| R-A6.4: S2's pull-back is the only camera move | S7 rises too, S5 pushes in a little, S4 has one rack focus | S7 rhymes with S2 on purpose; the others stay under 3 percent of the frame |
| R-A5.4: camera on the sea side | Camera on the land side, the sea behind the table | The low sun behind the cast is the colour script; the building stays frame right |
| R-A10.1: hold to skip | A confirming second press on the first viewing, one press on replays | A hold is hard on a gamepad and for some players; a second press guards against a stray tap equally well |
| A-part S8 idea in the ledger: an arcade cabinet | The cabinet is set dressing in S5; S8 is the shelf of figures | One twist only |

## Part A. Craft research

Researched 2026-11-16 for the 20-30 s end-game reveal (shots S1-S8). Read this first, because it limits what the
sources below can carry.

**The forge proxy allows only a developer allowlist.** Wikipedia, ted.com, npr.org, tvtropes.org, pixar.com,
khanacademy.org, studiobinder.com, nofilmschool.com, gameaccessibilityguidelines.com, cinemetrics, arxiv.org,
archive.org and every film or animation trade site probed were reset at CONNECT ("blocked by the forge proxy").
Reachable: learn.microsoft.com, w3.org, developer.mozilla.org, flutter.dev, github.com, `*.github.io`,
`*.netlify.app`. I did not route around the proxy. The result: accessibility (A10) is well sourced from primary
guidelines; the craft topics (A1-A9) rest on course notes, student notes and small blogs, and the canonical sources
(Coats, Adams, Stanton, Thomas and Johnston, Murch, the Pixar colour-script artists) are cited as snippet-only or
marked unsourced. Treat A1-A9 rules as working craft conventions, not as verified scholarship.

Citation statuses used here:

- `read 2026-11-16`: fetched with WebFetch and the relevant content seen.
- `api-read 2026-11-16`: WebFetch refuses the stackexchange.com domains; the answers were read through the official
  Stack Exchange API (`api.stackexchange.com`, plain curl through the forge proxy). **Under the strict §8 rule this is
  not "read"**, so every claim resting only on these also carries an `[UNSOURCED: …]` id. The lead decides whether
  to accept them.
- `unread: snippet only`: seen only in a search result. Does not make a claim sourced.

### A1. Story craft for a micro-short

Findings.

- The "22 rules" are a list of story tips that circulates under Pixar's name. A third-party summary of the "Pixar
  in a Box" storytelling course reproduces about 22 of them, among them: write for what interests an audience, not
  what is fun for the writer; simplify and combine, cut detours; settle the ending before the middle; coincidence may
  get characters into trouble but not out of it; find the essence of the story and tell it as economically as
  possible. That page attributes them to nobody.
  [source: gomesfernanda (GitHub), "PixarStorytelling" (README, summary of Khan Academy "Pixar in a Box"),
  https://github.com/gomesfernanda/PixarStorytelling, read 2026-11-16]
- Attribution: search snippets say the list was tweeted in 2011 by Emma Coats, then a Pixar story artist, as lessons
  picked up from colleagues, that she did not present it as official Pixar rules, and that bloggers gave it the
  "Pixar's rules" label. None of those pages could be fetched.
  [source: Prolost, "Pixar's 22 Rules of Story, Analyzed",
  https://prolost.com/blog/2013/12/4/pixars-22-rules-of-story-analyzed.html, unread: snippet only]
  [source: Tubefilter, "Pixar's 22 Rules of Storytelling",
  https://www.tubefilter.com/2012/06/12/pixar-rules-of-storytelling/, unread: snippet only]
  [UNSOURCED: plan/provenance-audit.md#endgame-coats]
- The story spine is a fill-in template: a once-upon-a-time setup, an every-day routine, a one-day disruption, two
  "because of that" consequences, an "until finally" resolution. The same summary pairs it with a three-act reading
  (world and inciting incident; escalation to a low point; resolution and moral).
  [source: gomesfernanda (GitHub), "PixarStorytelling", https://github.com/gomesfernanda/PixarStorytelling, read 2026-11-16]
- Origin: snippets say Kenn Adams created the spine in 1991 as an improv teaching exercise and that it reached Pixar
  through a workshop attendee, not the other way round. Not fetched.
  [source: NPR, "Meet the creator of the Story Spine…" (transcript), https://www.npr.org/transcripts/nx-s1-5750619,
  unread: snippet only] [UNSOURCED: plan/provenance-audit.md#endgame-spine]
- Stanton's "2+2": the idea, as I recall it from his TED talk "The clues to a great story", is to hand the audience
  the parts and let them do the sum, because people enjoy working out the answer more than being told it. The TED
  page is blocked and the search snippets did **not** show the passage, so this is from memory only.
  [source: Andrew Stanton, "The clues to a great story" (TED2012),
  https://www.ted.com/talks/andrew_stanton_the_clues_to_a_great_story/transcript, unread: snippet only]
  [UNSOURCED: plan/provenance-audit.md#endgame-stanton]
- Character wants versus needs, and stakes that are small but matter deeply to the character, are how the same course
  summary says an audience is made to care.
  [source: gomesfernanda (GitHub), "PixarStorytelling", https://github.com/gomesfernanda/PixarStorytelling, read 2026-11-16]

How it maps: the game itself is "once upon a time / every day / one day"; the final boss is "until finally"; the
cinematic is only the last line, "and ever since then", which the spine uses to state what the story meant.

**Rules for this cinematic**

- R-A1.1 One sentence must state the essence before any shot is drawn: "the war was the kids' game, and everyone who
  spoke on the radio was someone who loves them". Any shot that does not serve that sentence is cut.
- R-A1.2 The cinematic is the coda of the spine, not a new story. It introduces no new conflict and no new character
  trait; every person in it was already heard on the radio.
- R-A1.3 The ending was decided first (the table), so the game must be rewritten toward it: plants go into the game
  (A4), not explanations into the cinematic.
- R-A1.4 Show parts, not the sum. Never caption or narrate "it was a game". Show the toy tipping, the board, the
  faces, and let the player add them up. The only spoken lines are in-world ones (refills, time to go home).
- R-A1.5 The stake is small and real: the game is ending because it is time to go home. That, not the destroyed
  carrier, is the emotional beat of S6.
- R-A1.6 No coincidence resolves anything. The mom calls time because it is sunset, which the colour arc (A7) has
  been showing since S2.

### A2. Animation principles for a few seconds of limited animation

Findings. The twelve principles are credited to Frank Thomas and Ollie Johnston's "The Illusion of Life" (1981); the
book and its Wikipedia summary could not be fetched, so the definitions below come from two fetched secondary pages
that list the same principles (neither names the book).
[source: Wikipedia, "Twelve basic principles of animation",
https://en.wikipedia.org/wiki/Twelve_basic_principles_of_animation, unread: snippet only]
[UNSOURCED: plan/provenance-audit.md#endgame-illusion]

- Staging: arrange the scene so the eye goes to the one thing that matters and drop unnecessary detail. Background,
  props, costume, lighting, viewing angle and the other characters present all count as staging.
  [source: UCBUGG Open Course Ware, "Basic Animation", https://ucbugg.github.io/learn.ucbugg/basic-animation/,
  read 2026-11-16] [source: Microsoft, "Animation Principles - Win32 apps",
  https://learn.microsoft.com/en-us/windows/win32/lwef/animation-principles, read 2026-11-16]
- Anticipation: a small move the other way before the action. It prepares the audience and shows that the action is
  intended, which is what makes a character read as alive. [source: Microsoft, "Animation Principles - Win32 apps",
  https://learn.microsoft.com/en-us/windows/win32/lwef/animation-principles, read 2026-11-16]
- Timing: speed defines what an action means (a slow head turn is looking around, a fast one is "no") and conveys
  weight. Fast motion draws the eye in a calm frame; in a busy frame a still or slow element draws it instead.
  [source: Microsoft, "Animation Principles - Win32 apps",
  https://learn.microsoft.com/en-us/windows/win32/lwef/animation-principles, read 2026-11-16]
- Secondary action: supports the main action and must never compete with it; a facial expression is the usual
  secondary action to a body move. [source: Microsoft, "Animation Principles - Win32 apps",
  https://learn.microsoft.com/en-us/windows/win32/lwef/animation-principles, read 2026-11-16]
- Appeal: something the audience wants to watch, like an actor's charisma. Simple shapes often beat complex ones,
  personality comes from gesture and posture, and mirrored "twin" poses look wooden.
  [source: Microsoft, "Animation Principles - Win32 apps",
  https://learn.microsoft.com/en-us/windows/win32/lwef/animation-principles, read 2026-11-16]
  [source: UCBUGG, "Basic Animation", https://ucbugg.github.io/learn.ucbugg/basic-animation/, read 2026-11-16]
- Slow in and slow out, and follow-through: actions ease in and out and do not stop dead; parts keep moving after
  the body stops. Exaggeration must be chosen and consistent, or it reads as a mistake.
  [source: UCBUGG, "Basic Animation", https://ucbugg.github.io/learn.ucbugg/basic-animation/, read 2026-11-16]

**Rules for this cinematic**

- R-A2.1 Each shot has one primary action and at most one secondary action. Everything else in frame holds still
  or loops slowly, so the one fast thing owns the eye.
- R-A2.2 Every primary action gets an anticipation pose of 4-8 frames: the toy rocks back before it tips, the kid's
  hand lifts before it comes down, the mom's hand reaches before it lands on a shoulder.
- R-A2.3 Limited animation budget: 2-3 key poses per character per shot, eased, held with a slow "moving hold"
  (breathing, hair, a straw). Spend drawings on poses and timing, not on in-betweens.
- R-A2.4 No twins: every pose is asymmetric (weight on one hip, one arm higher, head tilted).
- R-A2.5 Follow-through sells life cheaply: the tipped toy wobbles and settles, the soda fizzes after the pour, the
  apron string swings after the waitress stops.
- R-A2.6 The plastic figures use rigid timing (no squash, a hard rattle); the people use soft, eased timing. The
  contrast in timing is itself the "toy versus alive" cue.

### A3. Reveal structure: making "it was imagined" earned

Findings.

- Why the device has a bad name: it is used as a lazy exit, and the audience feels cheated into having cared about
  events that turn out unreal and without consequence. The repair offered: make the inner sequence complete in itself
  (the quest is finished before the return), make it carry real insight about the characters, and do not spring it as
  a cheap "gotcha". [source: Chris Sunami, answer to "Why use the 'It Was All Just a Dream' Trope?",
  https://writing.stackexchange.com/questions/40251, api-read 2026-11-16]
  [source: TV Tropes, "Analysis: All Just a Dream", https://tvtropes.org/pmwiki/pmwiki.php/Analysis/AllJustADream,
  unread: snippet only] [UNSOURCED: plan/provenance-audit.md#endgame-dream]
- It suits stories where the only thing meant to change is the person: the frame works when the experience was the
  dreamer's own growth. [source: Amadeus, answer to "Why use the 'It Was All Just a Dream' Trope?",
  https://writing.stackexchange.com/questions/40251, api-read 2026-11-16]
  [UNSOURCED: plan/provenance-audit.md#endgame-dream]
- A good twist improves the story it changes: earlier elements take a new shape in hindsight and the result is a
  better story than before, not a different one. A twist that does not fit organically reads as a deus ex machina.
  The truth has to have been there from the start, lying innocuously among other details; the audience is surprised
  by realising it, not by a change of facts. [source: Kate S. and Feralthinker, answers to "When having a plot
  twist, does there have to be foreshadowing of it?", https://writing.stackexchange.com/questions/18835,
  api-read 2026-11-16] [UNSOURCED: plan/provenance-audit.md#endgame-twist]
- Chekhov's gun in practice: a planted object can pay off as itself, as a symbol or as a relationship marker, and
  not every detail needs to "fire" or the world goes bare. [source: Sora Tamashii and Phil H, answers to "How do I
  hide Chekhov's Gun?", https://writing.stackexchange.com/questions/43486, api-read 2026-11-16]
  [UNSOURCED: plan/provenance-audit.md#endgame-plants]
- Precedents, described from memory and search snippets only. The LEGO Movie ends by showing its brick world to be
  a boy's play in his father's basement, with the villain modelled on the father; snippets record both praise (the
  conflict gains a real-world emotional anchor) and dissent (the frame ripples back over the story). Toy Story 3
  opens on a full-scale western adventure that turns out to be a child's play session. Games such as Costume Quest
  and South Park: The Stick of Truth run their whole fiction as children's pretend play, visibly, from the start.
  [source: TV Tropes, "The LEGO Movie", https://tvtropes.org/pmwiki/pmwiki.php/WesternAnimation/TheLegoMovie,
  unread: snippet only] [source: Pixar, "Toy Story 3", https://www.pixar.com/feature-films/toy-story-3,
  unread: snippet only] [source: museumofplay.org, "Pretend Play in Video Game Worlds",
  https://www.museumofplay.org/blog/pretend-play-in-video-game-worlds/, unread: snippet only]
  [UNSOURCED: plan/provenance-audit.md#endgame-precedents]

Synthesis (mine, from the above): the frame is earned when (1) the inner story finished on its own terms first,
(2) the feelings carry over because the people are the same people, (3) the clues were fair, and (4) the frame adds
a meaning (who these voices are to the kids) instead of deleting one (the victory).

**Rules for this cinematic**

- R-A3.1 The victory completes first. The boss dies, the win is acknowledged and scored in game terms, and only then
  does S1 begin. The reveal never replaces or interrupts the payoff the player earned.
- R-A3.2 Nothing is taken back. The kids celebrate the same victory at the table (a fist pump, the toy carrier
  knocked flat). The win happened; it happened on a board.
- R-A3.3 Emotional truth carries over one-to-one: each radio voice keeps its relationship to the player. The Admiral
  commanded and now calls the kids home; the General grumbled and is the owner who lets them stay; the cadet cheered
  and brings refills. Same voice actor line reads, unfiltered.
- R-A3.4 The reveal is a recognition, not a correction: every fact in S1-S7 must be compatible with what the game
  already showed. If a shot needs the game to have lied, change the shot.
- R-A3.5 Fair play is a gate: at least three plants per bystander and per prop must exist in the game before the
  cinematic ships (list in A4), each visible or audible on an ordinary first run.
- R-A3.6 No "gotcha" tone: no record scratch, no wink to camera, no character explaining. The mood is warm, the same
  warmth the radio cast already had.
- R-A3.7 The frame adds one new meaning per shot (S3: these pilots are children; S4: the cadet's cheer was a
  refill; S5: the grump was smiling all along; S6: orders were bedtime). A shot that only repeats "it was toys" is
  cut.

### A4. Replay value from foreshadowing

Findings.

- Writers call it a "rewatch bonus": a detail that grows in significance once the ending is known. One working
  method is to finish the draft, then go back and tweak dialogue and small observed actions so they read two ways.
  Games are named as doing this with harmless-seeming early dialogue.
  [source: Amadeus and Liquid, answers to "What's a moment that's more impactful on a reread called?",
  https://writing.stackexchange.com/questions/46565, api-read 2026-11-16]
  [UNSOURCED: plan/provenance-audit.md#endgame-plants]
- Hiding in plain sight: (a) give the detail another job in its scene so it is read as doing that job; (b) put it
  among two to four similar details; (c) let the viewpoint notice it and dismiss it at once, then leave it alone long
  enough to be forgotten; (d) imply it through something normally associated with it instead of showing it.
  [source: Ville Niemi, Sora Tamashii and Rasdashan, answers to "How do I hide Chekhov's Gun?",
  https://writing.stackexchange.com/questions/43486, api-read 2026-11-16]
  [UNSOURCED: plan/provenance-audit.md#endgame-plants]
- Research on knowing the ending: a 2011 Psychological Science study by Leavitt and Christenfeld is reported as
  finding that readers rated short stories, including twist stories, as more enjoyable when the outcome was given
  beforehand, with easier processing offered as the explanation. If that holds, a second run that knows the reveal
  is not a spoiled run. I could not fetch the paper or the press release.
  [source: Association for Psychological Science, "Spoiler Alert: Stories Are Not Spoiled by 'Spoilers'",
  https://www.psychologicalscience.org/news/releases/spoiler-alert-stories-are-not-spoiled-byspoilers.html,
  unread: snippet only] [UNSOURCED: plan/provenance-audit.md#endgame-spoiler]
- Density: no source read gives a number. The guidance above implies a ceiling (a plant must not stop doing its
  first job) and a floor (the truth must have been present from the start).
  [UNSOURCED: plan/provenance-audit.md#endgame-density]

**Rules for this cinematic**

- R-A4.1 Every plant has a first-run job. A radio line must work as a military line and as a restaurant line ("top
  them up", "last round", "kitchen's closing", "home before dark"); a HUD mark must work as a HUD mark.
- R-A4.2 Three channels, so each replay finds something new: audio (word choice, a clink or a till bell under the
  radio filter), visual (mould seams, a base disc under a tank, a dice-pip pattern in a formation, a board-grid
  line in the starfield), structural (waves that arrive in "turns", bonus rounds that feel like refills).
- R-A4.3 Density budget: about one plant per mission that a first-time player could notice, plus two or three per
  mission that only a returning player will. Never two plants in the same five seconds.
- R-A4.4 Camouflage each plant among two to four neighbours of the same kind (one odd radio line among routine
  ones; one seam among panel lines).
- R-A4.5 The cinematic pays off by repetition, not explanation: S4-S6 reuse an exact phrase, gesture or sound from
  the game, so the second run supplies the "oh".
- R-A4.6 Keep a plant ledger (plant, mission, channel, payoff shot). A plant without a payoff shot, or a payoff
  without three plants, is removed.
- R-A4.7 S8 (post-credits) plants forward: one small unexplained detail that only makes sense after a second run.

### A5. Shot grammar for 25 seconds

Findings.

- Continuity editing exists to present action as clear and uninterrupted. Its parts: an establishing shot showing
  the whole space and where everyone is; the 180-degree rule (stay on one side of the line so left and right stay
  consistent); shot/reverse shot; the eyeline match (cut from someone looking to what they see, which only works if
  the line was kept); and the match on action (cut in mid-move, so the viewer watching the move does not notice the
  cut). [source: mmdlow, "Film Art & Human Concerns: notes, Lecture 4 - His Girl Friday",
  https://mmdlow.github.io/film-art-notes/2019/09/11/Lecture-4-His-Girl-Friday/, read 2026-11-16]
- Shot sizes and their jobs: the extreme wide is about the place and is usually held longer so the viewer can take
  it in; the long shot shows a whole figure in its surroundings; the medium shows body language; the medium close-up
  and close-up are for facial expression and emotional involvement; the extreme close-up isolates one feature or
  object. [source: Rahul Somani, "AI for Filmmaking: Recognising Shot Types with ResNets",
  https://rsomani95.github.io/ai-film-1.html, read 2026-11-16]
- "Cut like to like" (a dark frame to a dark frame) and match the subject's velocity across the cut; treat each clip
  as in, land, out. [source: lim, "Demystifying Vidding", https://vidders.github.io/articles/vidding/demystifying.html,
  read 2026-11-16]
- Shot length: snippets put modern features at roughly four seconds per shot on average and action films near four.
  Murch's "rule of six" is reported as ranking emotion and story above rhythm, eye-trace and spatial continuity.
  Neither was fetched. [source: Stephen Follows, "How many shots are in the average movie?",
  https://stephenfollows.com/many-shots-average-movie/, unread: snippet only]
  [UNSOURCED: plan/provenance-audit.md#endgame-asl] [UNSOURCED: plan/provenance-audit.md#endgame-eyetrace]
- Blocking a table of three or four children with three adults passing: no source read covers it; the rules below
  apply the 180-degree rule and staging to that case and are my inference.
  [UNSOURCED: plan/provenance-audit.md#endgame-table]

**Rules for this cinematic**

- R-A5.1 Seven story shots in about 25 s, average 3.5 s. Budget: S1 2.5 s, S2 5 s (the reveal needs time), S3 3 s,
  S4 3 s, S5 2.5 s, S6 4 s, S7 5 s (held wide). S8 is separate, after the credits.
- R-A5.2 One idea per shot, written as one sentence in the shot list. If the sentence needs "and", split or cut.
- R-A5.3 Sizes run insert to wide, with faces in the middle: S1 extreme close-up (toy), S2 wide over the board,
  S3-S5 medium close-ups, S6 medium two-shot (mom and kids), S7 extreme wide. Never two consecutive shots of the
  same size and angle.
- R-A5.4 One line for the whole scene, drawn along the long edge of the table. The camera stays on the sea side; the
  kids keep their left-to-right order in every shot; the window and sunset are always behind them.
- R-A5.5 The adults enter one at a time, each from a fixed side: waitress from screen right (kitchen), owner behind
  the counter in the background centre, mom from screen left (the door). Entry side never changes, so a 2.5 s shot
  needs no re-orientation.
- R-A5.6 Eye-trace: the point of interest at the end of each shot sits within about a sixth of the frame width of
  the point of interest at the start of the next. S1's toy lands where S2's board centre is; S3's kid looks
  screen right and S4's waitress enters from screen right.
- R-A5.7 Motivate cuts with looks: a kid looks up (S3 out), cut to what they see (S4 in). Three of the six cuts
  should be eyeline or action matches.
- R-A5.8 Children seated, adults standing: the height difference separates the two groups in silhouette and lets a
  low camera at the kids' eye level keep adults readable from the chest up.

### A6. Transitions from game space to table space

Findings.

- The best-known match cut joins a thrown bone to an orbiting craft: the same shape and motion, a new world, and the
  cut itself states the link between the two objects. [source: mmdlow, "Film Art & Human Concerns: notes, Lecture 9 -
  2001: A Space Odyssey", https://mmdlow.github.io/film-art-notes/2019/10/23/Lecture-9-2001-A-Space-Odyssey/,
  read 2026-11-16]
- Graphic matches link similar shapes across a cut; scale and lightness can change across it; velocity should match.
  [source: lim, "Demystifying Vidding", https://vidders.github.io/articles/vidding/demystifying.html,
  read 2026-11-16]
- A match on action hides a cut inside a movement. [source: mmdlow, "Lecture 4 - His Girl Friday",
  https://mmdlow.github.io/film-art-notes/2019/09/11/Lecture-4-His-Girl-Friday/, read 2026-11-16]
- The miniature look: a scene reads as small when both foreground and background are out of focus, because that only
  happens at close focus on small things; looking down at an angle strengthens it, and so does the loss of fine
  detail. [source: MikeW, Jerry Coffin and Robert, answers to "Why does using a tilt-shift lens make things look
  miniature?", https://photo.stackexchange.com/questions/20990, api-read 2026-11-16]
  [UNSOURCED: plan/provenance-audit.md#endgame-tiltshift]
- Rack focus, the dolly-out or crane-up reveal, the whip pan and the comic "pull back to reveal": no source could be
  read. The rules below use them as commonly practised. [UNSOURCED: plan/provenance-audit.md#endgame-transitions]

**Rules for this cinematic**

- R-A6.1 S1 is one cut, a match on action and a graphic match together: the falling carrier and the tipping toy
  share screen position, silhouette, angle and angular velocity at the cut frame. Cut in mid-fall, not after impact.
- R-A6.2 Across that cut exactly three things change: material (emissive neon to matte plastic with a mould seam),
  light (black space to warm key) and sound (A9). Shape, position and motion do not.
- R-A6.3 The scale cue arrives in the first 12 frames after the cut: shallow focus with blur both in front of and
  behind the toy, a slightly high angle, and one object of known size in the blur (a fingertip, a die, a straw).
- R-A6.4 S2 is the only camera move in the piece: a single eased pull-back and rise from the toy to the whole board,
  with depth of field deepening as it goes, so "miniature" becomes "table" in one continuous take.
- R-A6.5 No whip pans, no second trick transition. One match cut and one pull-back; every other cut is a plain cut
  motivated by a look (R-A5.7). Two gags dilute the first.
- R-A6.6 One rack focus at most, in S6 or S7: from a foreground toy to the mom, or from the box lid to the sign.
- R-A6.7 The reduced-motion variant (A10) replaces the S2 move with two static frames and a cross-fade.

### A7. Colour script

Findings.

- A colour script condenses a film into a row of small images, one per scene, showing only colour and light, so the
  director sees the emotional arc at a glance; the book calls it a roadmap for how colour, and so emotion, is applied
  through a film. Named practitioners: Ralph Eggleston (pastel; Toy Story, Finding Nemo, WALL-E), Bill Cone, Lou
  Romano (gouache then digital; The Incredibles, Up), Dice Tsutsumi (Toy Story 3). Examples given: Toy Story moves
  from warm light into darkness as jealousy grows and returns to warm light at the end; Up withholds magenta until
  the destination is reached; in Toy Story 3 blue stands for home and safety.
  [source: comicfrenzy blog, reproducing text from Amid Amidi, "The Art of Pixar: 25th Anniversary: The Complete
  Color Scripts…",
  https://comicfrenzy.github.io/post/artbook/art-of-pixar-25th-anniversary-complete-color-scripts-select-art-from-25-years-of-animation,
  read 2026-11-16]
- Film colour takes its meaning from the film's own logic, by being tied to particular objects, characters and
  places; a change of dominant colour marks a change of mood, place or character; colour also separates foreground
  from background and steers attention. [source: Nick Redfern, "Computational Film Analysis with R", ch. 5
  "Analysing film colour", https://cfa-with-r.netlify.app/colour, read 2026-11-16]
- A film's sections can each hold a distinct palette that is visible as bands when frames are laid end to end.
  [source: Pio Calderon, "The Color Dynamics of La La Land",
  https://piocalderon.github.io/color-dynamics-of-la-la-land/, read 2026-11-16]

**Rules for this cinematic**

- R-A7.1 Paint the colour script before any shot: eight thumbnails (S1-S8) at about 160 px wide, colour and light
  only, no detail. It is approved as a strip, not shot by shot.
- R-A7.2 The arc is one move from the game's saturated neon on near-black to golden hour: S1 neon on black; first
  frame after the cut, warm key on the same shape; S2 warmth spreads as the frame widens; S3-S5 warm skin and amber
  window light with teal shadow; S6 the warmest frame; S7 dusk, with the sign's neon coming on.
- R-A7.3 Withhold one colour: the full sunset orange appears in the game nowhere and in the cinematic only from S6.
- R-A7.4 Neon returns once, as a real object: the restaurant sign in S7 uses the game's HUD hue. The game's palette
  was the sign's light all along.
- R-A7.5 One accent colour per bystander, identical to their radio portrait: the cadet's purple is the waitress's
  hair or apron trim; the Admiral's colour is the mom's cardigan; the General's is the owner's cap. Each accent
  appears on exactly one person and on that person's plastic counterpart on the board, nowhere else in frame.
- R-A7.6 Value before hue: every shot must read in greyscale, with the point of interest as the highest-contrast
  area (this also serves A10).

### A8. Bystanders who read in two seconds

Findings.

- A character should be identifiable as a solid black shape (the "squint test"), through outline, height, posture
  and bulk; shape carries temperament by convention (round reads friendly, blocky reads strong and immovable, angular
  reads fast or dangerous); identity should not depend on colour alone, which also fails colour-blind viewers. The
  page is anonymous and cites nothing, so this is weak support for a widely repeated convention.
  [source: salivity.github.io (no author named), "Importance of Character Silhouettes in Game Design",
  https://salivity.github.io/game-development/article/importance-of-character-silhouettes-in-game-design,
  read 2026-11-16]
- Costume, props, lighting, viewing angle and the other characters present are all staging and all carry mood and
  purpose; personality reads from gesture and posture even on a very simple shape; simple shapes often work better
  than complex ones. [source: Microsoft, "Animation Principles - Win32 apps",
  https://learn.microsoft.com/en-us/windows/win32/lwef/animation-principles, read 2026-11-16]
- Colour used to tell speakers apart should be backed by a second cue such as a name.
  [source: Microsoft, "Xbox Accessibility Guideline 104",
  https://learn.microsoft.com/en-us/xbox/accessibility/xbox-accessibility-guidelines/104, read 2026-11-16]

**Rules for this cinematic**

- R-A8.1 Each bystander is four things and no more: one silhouette, one prop, one colour, one gesture. Waitress:
  ponytail and tray outline, soda jug, purple, a hip-cocked pour. Owner: broad and round, spatula or towel over the
  shoulder, his accent colour, a smile under a frown-shaped moustache. Mom: tall, bag on the shoulder with car keys
  in hand, her accent colour, a hand on a kid's shoulder.
- R-A8.2 Each must pass the black-fill test at 64 px high against the other two and against the kids.
- R-A8.3 The gesture is the radio character's gesture from the portrait (the cadet's salute becomes the tray lift;
  the Admiral's pointing hand becomes pointing at the door). Costume echoes a rank mark as an ordinary object: a
  name badge where the insignia sat, an apron stripe for a sleeve stripe.
- R-A8.4 The first frame of each bystander shot already holds the identifying pose; the gesture then plays. Never
  make the viewer wait for the turn-around.
- R-A8.5 The voice does half the work: each bystander's first sound is their radio voice, so the picture only has to
  confirm it. The owner's joke (grumpy voice, always smiling) needs the face and the voice in the same shot.
- R-A8.6 Background patrons are flat two-value shapes with no accent colour and no motion faster than a slow loop.

### A9. Sound: from radio and metal to a restaurant

Findings.

- A J-cut lets the next scene's sound start while the previous picture is still up; an L-cut lets the current sound
  run on over the next picture. No fixed overlap length is given. The page is a promotional blog post that cites
  nothing, so it supports the definitions only. [source: "linkswebliquids-web", "J Cut and L Cut Editing…" (issue
  #407 in digoal/blog), https://github.com/digoal/blog/issues/407, read 2026-11-16]
- Sound may sit ambiguously between the story world and the score, and off-screen sound can establish life that is
  not seen. [source: mmdlow, "Lecture 9 - 2001: A Space Odyssey",
  https://mmdlow.github.io/film-art-notes/2019/10/23/Lecture-9-2001-A-Space-Odyssey/, read 2026-11-16]
- "Worldizing" is described in snippets as Walter Murch's term for playing a recording back in a real space and
  re-recording it, so that it takes on the acoustics of the world in the picture, used for the radio music of
  American Graffiti. Not fetched. [source: Nerdwriter, "How Walter Murch Worldized Film Sound" (transcript page),
  https://rosetta.to/u/nerdwriter1/how-walter-murch-worldized-film-sound, unread: snippet only]
  [UNSOURCED: plan/provenance-audit.md#endgame-worldizing]
- A caption can state that a voice is on the radio, e.g. "Baird (on radio): …", so that players who cannot hear the
  filter still get the information. [source: Microsoft, "Xbox Accessibility Guideline 104",
  https://learn.microsoft.com/en-us/xbox/accessibility/xbox-accessibility-guidelines/104, read 2026-11-16]

**Rules for this cinematic**

- R-A9.1 J-cut into the reveal: 12-20 frames before the S1 cut, restaurant sound (cutlery, surf, a ceiling fan)
  fades up under the explosion. The ear arrives at the table before the eye.
- R-A9.2 L-cut out of the game: the metal track does not stop at the cut. Over S1-S2 it is "worldized" in the mix:
  band-limited, mono, with a small-room reverb, panned to a visible source (a phone on the table or the jukebox).
  The soundtrack was playing in the restaurant.
- R-A9.3 The radio filter comes off on screen, once per voice: each bystander's first line starts filtered for two
  or three words and opens to the natural voice as the face appears. Same actor, same take if possible.
- R-A9.4 Three sound plants pay off here and must exist in the game mix first (A4): a glass clink, the till or door
  bell, surf under "static".
- R-A9.5 The plastic rattle of the tipped toy is the first fully dry, close sound in the whole game: the loudest
  cue that this is real. The half second before it is the quietest moment of the piece.
- R-A9.6 Music and new voice lines are blocked on tillandsias#1103 (project rule). Until it lands, the cinematic
  uses existing clips re-filtered, and any new line ships as text (`"pending": "text"`), not a placeholder voice.

### A10. Accessibility and comfort

Findings.

- Skipping: players should be able to skip a cutscene, including after it has started, and skipping must not block
  progress. (The guideline says this about emotionally hard content; applying it to all cutscenes is my extension.)
  [source: Microsoft, "Xbox Accessibility Guideline 123",
  https://learn.microsoft.com/en-us/xbox/accessibility/xbox-accessibility-guidelines/123, read 2026-11-16]
- A shipped pattern shown as good practice is an on-screen "Hold to skip" prompt, with an option to stop cutscene
  dialogue auto-advancing; timed text should be adjustable or dismissible by input.
  [source: Microsoft, "Xbox Accessibility Guideline 116",
  https://learn.microsoft.com/en-us/xbox/accessibility/xbox-accessibility-guidelines/116, read 2026-11-16]
- Subtitles: cover all speech; on by default or settable before the first cinematic; name the speaker at each change
  of speaker; colour may mark speakers only alongside text; at most about 40 characters a line and two lines; mixed
  case; a sans-serif face; a solid background the player can turn on; placed low. Captions cover meaningful
  non-speech sound. [source: Microsoft, "Xbox Accessibility Guideline 104",
  https://learn.microsoft.com/en-us/xbox/accessibility/xbox-accessibility-guidelines/104, read 2026-11-16]
  [source: W3C, "Understanding SC 1.2.2: Captions (Prerecorded)",
  https://www.w3.org/WAI/WCAG22/Understanding/captions-prerecorded.html, read 2026-11-16]
- Flashing: no more than three flashes in any second unless small and dim. A general flash is a pair of opposing
  luminance changes of 10 % or more with the darker state below 0.80; saturated red has a stricter test. Xbox gives
  about 20 % of the screen as the area limit, WCAG 25 % of a 10-degree field (341 x 256 px at 1024 x 768). About 1 in
  4 000 people are photosensitive and many do not know it, so removing the trigger is preferred to a warning; test
  even when no flashing is intended. [source: W3C, "Understanding SC 2.3.1: Three Flashes or Below Threshold",
  https://www.w3.org/WAI/WCAG22/Understanding/three-flashes-or-below-threshold.html, read 2026-11-16]
  [source: Microsoft, "Xbox Accessibility Guideline 118",
  https://learn.microsoft.com/en-us/xbox/accessibility/xbox-accessibility-guidelines/118, read 2026-11-16]
- Motion: scaling or panning large objects and parallax can trigger dizziness, nausea and headaches in people with
  vestibular disorders; a cross-fade is given as the non-triggering substitute; camera shake and motion blur should
  be avoided or switchable. [source: MDN, "prefers-reduced-motion",
  https://developer.mozilla.org/en-US/docs/Web/CSS/@media/prefers-reduced-motion, read 2026-11-16]
  [source: W3C, "Understanding SC 2.3.3: Animation from Interactions",
  https://www.w3.org/WAI/WCAG22/Understanding/animation-from-interactions.html, read 2026-11-16]
  [source: Microsoft, "Xbox Accessibility Guideline 117",
  https://learn.microsoft.com/en-us/xbox/accessibility/xbox-accessibility-guidelines/117, read 2026-11-16]
- Auto-starting motion longer than five seconds needs a pause, stop or hide control unless it is essential.
  [source: W3C, "Understanding SC 2.2.2: Pause, Stop, Hide",
  https://www.w3.org/WAI/WCAG22/Understanding/pause-stop-hide.html, read 2026-11-16]
- Flutter exposes the platform's reduce-motion request as `MediaQueryData.disableAnimations` (Android "Remove
  animations"; iOS reports it through `AccessibilityFeatures.reduceMotion`). The page does not say how Flutter web
  maps the browser's `prefers-reduced-motion`, so that needs a test.
  [source: Flutter, "disableAnimations property (MediaQueryData)",
  https://api.flutter.dev/flutter/widgets/MediaQueryData/disableAnimations.html, read 2026-11-16]
  [UNSOURCED: plan/provenance-audit.md#endgame-flutterweb]
- Text contrast of at least 4.5:1, and layouts that survive large text scales.
  [source: Flutter, "Accessibility", https://docs.flutter.dev/ui/accessibility-and-internationalization/accessibility,
  read 2026-11-16]

**Rules for this cinematic**

- R-A10.1 Skippable from the first frame, every time including the first, by a visible "Hold to skip" (about 0.6 s
  hold; any key, tap-and-hold, or gamepad button) and by Escape. Skipping lands on the same end screen with the same
  score, unlocks and S8 access. Pause works during the cinematic.
- R-A10.2 Subtitles on by default: at most two lines of 40 characters, mixed case, sans-serif, on a solid panel at
  4.5:1 or better, low in frame, and shot composition keeps that band free of faces and plants.
- R-A10.3 Speaker labels do the reveal for players who cannot hear it: the label carries both identities at the
  moment the filter lifts, e.g. "Mom (the Admiral's voice): Time to go home." Accent colour (R-A7.5) may tint the
  label but never replaces the name.
- R-A10.4 Caption the three sounds that carry meaning: [plastic clatter], [music, now from a small speaker],
  [surf, cutlery].
- R-A10.5 No flash at the S1 cut. Neon-on-black to a warm frame is one large luminance step over most of the screen,
  so it must be a single transition, not a strobe: no white frame, no explosion flicker within one second either
  side, and the saturated red of the explosion never alternates. Check the last second of the boss death and the
  first second of S1 frame by frame against the three-per-second rule.
- R-A10.6 Reduced-motion variant, used when `disableAnimations` or the game's own setting is on: the S2 pull-back
  becomes two stills with a 400 ms cross-fade, parallax and any camera drift are off, character animation stays.
  No camera shake or motion blur in either variant.
- R-A10.7 The cinematic is replayable from the menu after first view, so a skipped or missed reveal is never lost.
- R-A10.8 Nothing essential is carried by one sense or by colour alone: the reveal must be complete with sound off
  (picture plus subtitles) and legible in greyscale (R-A7.6).

### A11. Source list

| Source | URL | Status |
|---|---|---|
| Microsoft, "Animation Principles - Win32 apps" | https://learn.microsoft.com/en-us/windows/win32/lwef/animation-principles | read |
| UCBUGG, "Basic Animation" | https://ucbugg.github.io/learn.ucbugg/basic-animation/ | read |
| gomesfernanda (GitHub), "PixarStorytelling" README | https://github.com/gomesfernanda/PixarStorytelling | read |
| mmdlow, "Lecture 4 - His Girl Friday" | https://mmdlow.github.io/film-art-notes/2019/09/11/Lecture-4-His-Girl-Friday/ | read |
| mmdlow, "Lecture 9 - 2001: A Space Odyssey" | https://mmdlow.github.io/film-art-notes/2019/10/23/Lecture-9-2001-A-Space-Odyssey/ | read |
| lim, "Demystifying Vidding" | https://vidders.github.io/articles/vidding/demystifying.html | read |
| R. Somani, "AI for Filmmaking" | https://rsomani95.github.io/ai-film-1.html | read |
| N. Redfern, "Computational Film Analysis with R", ch. 5 | https://cfa-with-r.netlify.app/colour | read |
| comicfrenzy blog (text of Amidi, "The Art of Pixar") | https://comicfrenzy.github.io/post/artbook/art-of-pixar-25th-anniversary-complete-color-scripts-select-art-from-25-years-of-animation | read (secondary; book is the origin) |
| P. Calderon, "The Color Dynamics of La La Land" | https://piocalderon.github.io/color-dynamics-of-la-la-land/ | read |
| salivity.github.io, "Importance of Character Silhouettes…" | https://salivity.github.io/game-development/article/importance-of-character-silhouettes-in-game-design | read (anonymous, uncited) |
| "J Cut and L Cut Editing…", digoal/blog issue 407 | https://github.com/digoal/blog/issues/407 | read (promotional, uncited) |
| Microsoft, "Xbox Accessibility Guideline 104" (subtitles, captions) | https://learn.microsoft.com/en-us/xbox/accessibility/xbox-accessibility-guidelines/104 | read |
| Microsoft, "Xbox Accessibility Guideline 116" (time limits) | https://learn.microsoft.com/en-us/xbox/accessibility/xbox-accessibility-guidelines/116 | read |
| Microsoft, "Xbox Accessibility Guideline 117" (moving content, motion) | https://learn.microsoft.com/en-us/xbox/accessibility/xbox-accessibility-guidelines/117 | read |
| Microsoft, "Xbox Accessibility Guideline 118" (photosensitivity) | https://learn.microsoft.com/en-us/xbox/accessibility/xbox-accessibility-guidelines/118 | read |
| Microsoft, "Xbox Accessibility Guideline 123" (mental health) | https://learn.microsoft.com/en-us/xbox/accessibility/xbox-accessibility-guidelines/123 | read |
| W3C, Understanding SC 2.3.1 | https://www.w3.org/WAI/WCAG22/Understanding/three-flashes-or-below-threshold.html | read |
| W3C, Understanding SC 2.3.3 | https://www.w3.org/WAI/WCAG22/Understanding/animation-from-interactions.html | read |
| W3C, Understanding SC 2.2.2 | https://www.w3.org/WAI/WCAG22/Understanding/pause-stop-hide.html | read |
| W3C, Understanding SC 1.2.2 | https://www.w3.org/WAI/WCAG22/Understanding/captions-prerecorded.html | read |
| MDN, "prefers-reduced-motion" | https://developer.mozilla.org/en-US/docs/Web/CSS/@media/prefers-reduced-motion | read |
| Flutter, `MediaQueryData.disableAnimations` | https://api.flutter.dev/flutter/widgets/MediaQueryData/disableAnimations.html | read |
| Flutter, "Accessibility" | https://docs.flutter.dev/ui/accessibility-and-internationalization/accessibility | read |
| BFI, "Apocalypse Now: Final Cut" programme notes | https://bfidatadigipres.github.io/big%20screen%20classics/2024/06/01/apocalypse-now-the-final-cut/ | read; nothing on sound craft, not used |
| DSU, "Historical Context of Film Sound" | https://dsu-digital-sound-design.github.io/f-24-DAD-422-Audio-Production-III/lectures/week-1/historical-context/ | read; nothing relevant, not used |
| "DCMP Terminology Drill" | https://dcmp-terms.netlify.app/ | read; no definitions on the page, not used |
| scivis, "Sound design, audiovisual narrative" handout (PDF) | https://scivis.github.io/courses/visualstorytelling/sounds_and_music_handouts.pdf | fetched, PDF text not decoded, not used |
| X. Shi et al., "Piet" (CHI 2024, PDF) | https://xinyu-shi.github.io/uploads/piet_chi24_compressed.pdf | fetched, PDF text not decoded, not used |
| Writing SE 40251, "Why use the 'It Was All Just a Dream' Trope?" | https://writing.stackexchange.com/questions/40251 | api-read (WebFetch refuses the domain) |
| Writing SE 43486, "How do I hide Chekhov's Gun?" | https://writing.stackexchange.com/questions/43486 | api-read |
| Writing SE 18835, twist and foreshadowing | https://writing.stackexchange.com/questions/18835 | api-read |
| Writing SE 46565, moment more impactful on a reread | https://writing.stackexchange.com/questions/46565 | api-read |
| Photography SE 20990, tilt-shift miniature | https://photo.stackexchange.com/questions/20990 | api-read |
| Prolost, "Pixar's 22 Rules of Story, Analyzed" | https://prolost.com/blog/2013/12/4/pixars-22-rules-of-story-analyzed.html | snippet; blocked by the forge proxy |
| Tubefilter, "Pixar's 22 Rules of Storytelling" | https://www.tubefilter.com/2012/06/12/pixar-rules-of-storytelling/ | snippet; blocked |
| NPR, Story Spine interview transcript | https://www.npr.org/transcripts/nx-s1-5750619 | snippet; blocked |
| A. Stanton, "The clues to a great story" (TED) | https://www.ted.com/talks/andrew_stanton_the_clues_to_a_great_story/transcript | snippet (passage not shown); blocked |
| Wikipedia, "Twelve basic principles of animation" | https://en.wikipedia.org/wiki/Twelve_basic_principles_of_animation | snippet; blocked |
| TV Tropes, "Analysis: All Just a Dream" | https://tvtropes.org/pmwiki/pmwiki.php/Analysis/AllJustADream | snippet; blocked |
| TV Tropes, "The LEGO Movie" | https://tvtropes.org/pmwiki/pmwiki.php/WesternAnimation/TheLegoMovie | snippet; blocked |
| Pixar, "Toy Story 3" | https://www.pixar.com/feature-films/toy-story-3 | snippet; blocked |
| museumofplay.org, "Pretend Play in Video Game Worlds" | https://www.museumofplay.org/blog/pretend-play-in-video-game-worlds/ | snippet; not probed |
| APS, "Spoiler Alert: Stories Are Not Spoiled by 'Spoilers'" | https://www.psychologicalscience.org/news/releases/spoiler-alert-stories-are-not-spoiled-byspoilers.html | snippet; blocked |
| S. Follows, "How many shots are in the average movie?" | https://stephenfollows.com/many-shots-average-movie/ | snippet; not probed |
| Nerdwriter, "How Walter Murch Worldized Film Sound" | https://rosetta.to/u/nerdwriter1/how-walter-murch-worldized-film-sound | snippet; not probed |

Also blocked at the proxy when probed, with no page cited from them: khanacademy.org, studiobinder.com,
nofilmschool.com, gameaccessibilityguidelines.com, cartoonbrew.com, awn.com, filmsound.org, gdcvault.com,
gamedeveloper.com, arxiv.org, archive.org, bbc.co.uk, youtube.com. Google Books answered with a captcha redirect.

### A12. Unsourced claims

These ids are listed in Part E of `plan/provenance-audit.md`.

| Id | Claim | Why unsourced |
|---|---|---|
| endgame-coats | The 22 rules are Emma Coats's personal 2011 tweets, not an official Pixar document | snippets only |
| endgame-spine | Kenn Adams created the story spine in 1991 for improv; Pixar adopted it later | snippet only |
| endgame-stanton | Stanton's "2+2": give the audience the parts, not the sum | from memory; snippet did not show it |
| endgame-illusion | The twelve principles originate in Thomas and Johnston, "The Illusion of Life" (1981) | snippet only; definitions themselves are read |
| endgame-dream | Why "all a dream" feels cheap, and when it works | api-read and snippet only |
| endgame-twist | A twist must improve the story and its truth must be present from the start | api-read only |
| endgame-plants | Rewatch bonus; techniques for hiding a plant in plain sight | api-read only |
| endgame-precedents | The LEGO Movie, Toy Story 3 opening, Costume Quest, Stick of Truth as described | memory and snippets |
| endgame-spoiler | Leavitt and Christenfeld (2011): knowing the ending did not reduce enjoyment | snippet only |
| endgame-density | Any number for plant density (R-A4.3 is a design choice) | no source found |
| endgame-asl | Average shot length figures; the 3.5 s average in R-A5.1 is a design choice | snippet only |
| endgame-eyetrace | Murch's rule of six and eye-trace (R-A5.6's one-sixth figure is a design choice) | snippet only |
| endgame-table | Blocking a table scene with seated children and passing adults (R-A5.4, 5.5, 5.8) | inference, no source |
| endgame-tiltshift | Shallow focus front and back reads as miniature | api-read only |
| endgame-transitions | Rack focus, dolly-out and crane-up reveals, whip pan, pull-back-to-reveal gag | no source read |
| endgame-worldizing | Murch's worldizing; the sound-bridge practice in R-A9.1 to R-A9.3 beyond the J/L definitions | snippet only |
| endgame-flutterweb | How Flutter web maps the browser's `prefers-reduced-motion` to `disableAnimations` | not stated on the page read |

Frame counts, durations and pixel sizes in the rules (4-8 frame anticipation, 12-20 frame J-cut, 0.6 s hold, 400 ms
cross-fade, 64 px silhouette test, 160 px thumbnails) are my design proposals, not sourced figures. Tune them in
review.

## Part B. Pipeline research

Question: how do we make the end-game cinematic (20–30 s, about 7 shots, stylised 3D look) locally at the highest
quality we can reach, how does it play in a Flutter web game on phones, and does it need its own pipeline?
Research only: nothing was rendered, queued, downloaded or installed for this part.

Provenance (CLAUDE.md §8). `[source: …, read 2026-11-16]` means the page was fetched with WebFetch on that day; the
fetch tool answers through a summarising model, so re-check a quote on the live page before it reaches user-facing
text. `[source: …, unread: snippet only]` does not make a claim sourced. `[UNSOURCED: plan/provenance-audit.md#endgame-…]`
marks our own reasoning, an estimate or a claim whose source was blocked; the ids are listed in B-unsourced and in
Part E of `plan/provenance-audit.md`. Repo facts cite a path. This is not legal advice.

**Hosts blocked by the forge proxy today (ECONNRESET, one attempt each, not routed around):** `docs.comfy.org`,
`www.blender.org`, `docs.blender.org`, `projects.blender.org`, `static.makehumancommunity.org`, `www.gnu.org`,
`webkit.org`, `www.videolan.org`, `www.copyright.gov`. Reached: `huggingface.co`, `github.com`,
`raw.githubusercontent.com`, `comfyanonymous.github.io`, `julianeisel.github.io`, `pypi.org`, `pub.dev`,
`api.flutter.dev`, `docs.flutter.dev`, `developer.mozilla.org`.

### B1. Recommendation in short

1. **Route: hybrid, played in-engine.** Blender (the existing headless bpy route) builds the layout of every shot:
   set blockout, cameras, timing, and clay, depth, normal and id passes. ComfyUI turns each layout into a styled
   keyframe still and into separate layer plates. The game plays the shots as a layered 2.5D scene: parallax,
   camera moves, rack focus, light animation, a few baked sprite animations, subtitles as text, audio as clips.
2. **Motion where motion is the point** comes from two sources: rigid toy motion from the projection bake that
   rigkit already has (the tipping carrier), and two or three short generated inserts (the soda pour, a wave)
   from Wan 2.2 Fun VACE driven by the layout's depth clip, shipped as small frame strips, not as `<video>`.
3. **Every model the baseline needs is already on disk** in the studio (B2). The baseline is the zero-download
   fallback. Three optional downloads raise quality (B11); each needs the operator's consent token.
4. **It does not need its own pipeline or container.** It needs one new family type (a "shot family"), one new bpy
   layout script built on `rigkit.py`, one packer verb, and a runtime player. Everything else is reused: bpy venv,
   studio workflows, the production runner, collect, contact sheets, run ledgers.
5. **A single pre-rendered video is a later, optional upgrade**, lazy-loaded, royalty-free codecs only, with the
   in-engine scene as the fallback on browsers that cannot play it. It is not the base because it costs
   localisation, testability and reduced-motion support, and because full generated video is where consistency
   fails (B4, B6).

The operator's bar is "Pixar-level". Honest reading of the evidence: no local route reaches feature-film character
animation. Open image models do reach a convincing stylised-3D *still*. The plan therefore spends the quality where
the models are strong (stills, light, lenses) and keeps what they are weak at (acting, lips, hands, moving text)
off the screen or under deterministic control. [UNSOURCED: plan/provenance-audit.md#endgame-quality-judgement]

### B2. What exists on this machine (checked 2026-11-16)

- GPU: `gpu.status` reports no holders and 23.29 GB free. `studio.status`: running
  (`tillandsias-demon_attack-studio`). It was not started or restarted by this research.
- `studio.models` (tray `56.11.15.5+868dbff5dc303c4f`, models.tsv `23a145c91d6f`) lists **on disk**:

| Use | Files on disk | Licence tag in the tray table |
|---|---|---|
| Edit and restyle (keyframes from clay, new poses, layer clean-up) | `qwen_image_edit_2511_fp8mixed`, `qwen_2.5_vl_7b_fp8_scaled`, `qwen_image_vae`, Lightning 4-step LoRAs (2509, 2511) | apache-2.0 |
| Fast text-to-image and multi-reference edit | `flux-2-klein-4b`, `qwen_3_4b`, `flux2-vae` | apache-2.0 |
| SDXL family | `sd_xl_base_1.0`, `animagine-xl-4.0`, `sdxl_lightning_4step`, `sdxl_vae`, `pixel-art-xl` LoRA | openrail++ (LoRA: creativeml-openrail-m) |
| Structure control for SDXL | ControlNet union promax, ControlNet openpose | apache-2.0 |
| Identity reference for SDXL | IP-Adapter plus SDXL ViT-H, CLIP vision | apache-2.0 |
| Transparent layers | LayerDiffuse (`layer_xl_transparent_attn`/`conv`, transparent VAE decoder) | creativeml-openrail-m |
| Matting | BiRefNet | mit |
| Video with control clip and reference | `wan2.2_fun_vace_high_noise_14B_fp8_scaled`, `…low_noise…`, `umt5_xxl_fp8_e4m3fn_scaled`, `wan_2.1_vae`, Wan2.2-Lightning `high_noise_model`/`low_noise_model` LoRAs | apache-2.0 |
| Music | ACE-Step 1.5 XL turbo and base, encoders, VAE | apache-2.0 |

- **Pinned but not on disk** (a first use is a download and needs consent): `qwen_image_2512_fp8_e4m3fn`
  (apache-2.0) and `RealESRGAN_x4plus` (bsd-3-clause).
- Not installed at all: any image-to-video or first-last-frame checkpoint other than Fun VACE, any frame
  interpolator, any depth estimator, any segmentation model other than BiRefNet, any TTS, any lip-sync model.
- Forge: bpy 5.3.0 venv present at `~/.cache/tillandsias-project/bpy-venv`; no `blender` binary; ffmpeg 9.0.2 built
  with libx264, libvpx-vp9, libsvtav1, libopus and the native AAC encoder (`ffmpeg -encoders`); no `cwebp`.
- Committed workflows that this plan reuses (`art/workflows/`): `sprites/carrier-hero-qwen.json` and
  `-fast` (clay to styled hero, 1.6 MP), `sprites/carrier-refine-qwen.json`, `sprites/variant-qwen-edit.json`,
  `sprites/inbetween-wan-vace.json` and `-33` (Fun VACE, reference image plus control strip, 4 steps),
  `sprites/matte-birefnet-batch.json`, `comms/portrait-sdxl-ipadapter.json`, `backgrounds/sprite-transparent.json`.
- Prior art for exactly this hybrid: macron.dev's "48-frame Blender + Wan VACE loop" used procedural bpy blockouts,
  packed depth frames as `control_video`, one `reference_image`, 81 frames, and needed no custom nodes
  (`plan/round2-research.md` §1.1). Its recorded failures apply here: splicing separate runs does not match, the
  first Wan use downloaded about 41 GB although listed as on disk, and two studios sharing the GPU failed with
  `VRAM grow failed` (`plan/round2-research.md` §1.3).

### B3. Route B: everything in Blender

**What the repo can already do** (`tools/rigkit/`, `tools/boss_rig/`, `openspec/changes/boss-hero-assets/design.md`
§8.5):
- headless bpy 5.3.0 on the CPU inside the forge, set up by `tools/boss_rig/setup_bpy.lua` (about 1 min and 430 MB
  when the venv is missing); bpy is "Blender as a Python module", GPL-3.0, Python 3.13 only
  [source: Blender Foundation via PyPI, "bpy", https://pypi.org/project/bpy/, read 2026-11-16];
- procedural hard-surface geometry from a family JSON: box, loft, shell, cyl, lathe, ell, horn, shard, prism, web;
  arrays, drops onto surfaces, subsurf and noise displacement (`tools/rigkit/rigkit.py`);
- passes per view and stage: clay (Workbench), hint colours, depth, camera-space normal, flat id mattes, 16-bit z
  (`tools/rigkit/rig.py`);
- the projection bake: one picked image is camera-projected onto the mesh and re-rendered from other views and
  poses with Cycles on the CPU at 6 samples (`tools/rigkit/bake.py`); `--poses 1` moves rigid parts with their
  projected paint (`tools/rigkit/bake_poses.lua`, family `art/families/flight-joystick.json` `articulation`);
- no-GPU rebuilds from committed picks (`bake_family.lua`, `bake_layers.lua`), review sheets (`tools/rigsheet`).
- Measured cost: 18 clay and depth renders at 384² in 47 s on 20 cores (`plan/round2-research.md` §2.2); one
  Blender process at 8 threads peaks near 1.6 GB (`plan/render-runs/carrier-v3.md` §4). Vulkan does not initialise;
  EEVEE runs on software GL at about 1.5 GB (`tools/rigkit/rigkit.py:674`). There is no GPU Blender anywhere on the
  host (`plan/round2-research.md` §2.1).

**What is missing for a character film:** organic character modelling, skinning, a face rig, hair and cloth,
hand-keyed acting, lip sync, a lighting and material library for skin, food and liquids, and any way for an agent
to look at an animation while it works. None of it exists in the repo. Everything rigkit builds is rigid and
hard-surface; its "poses" are rigid tilts about a pivot.

**Options for humans without sculpting:**

| Option | What it gives | Licence | Verdict |
|---|---|---|---|
| MPFB2 (MakeHuman for Blender) | Parametric adult and child bodies; needs Blender 4.2 or later [source: MakeHuman Community, "mpfb2 README", https://raw.githubusercontent.com/makehumancommunity/mpfb2/master/README.md, read 2026-11-16]. Rigs, face shapes and clothes are not confirmed from a read page [UNSOURCED: plan/provenance-audit.md#endgame-mpfb-features] | Code GPLv3 (`LICENSE.CODE.md`), assets CC0 1.0 (`LICENSE.ASSETS.md`) [source: MakeHuman Community, "LICENSE.CODE.md" and "LICENSE.ASSETS.md", https://raw.githubusercontent.com/makehumancommunity/mpfb2/master/LICENSE.ASSETS.md, read 2026-11-16]. MakeHuman states it makes no claim over exports and that "there is no limitation on what you can do with this combined output" for its own CC0 assets [source: MakeHuman Community, "LICENSE.md" section D, https://github.com/makehumancommunity/makehuman/blob/master/LICENSE.md, read 2026-11-16] | Usable as **blockout mannequins** (proportions, pose, depth). The look is realistic, not stylised; a new add-on install and asset pack download. Not needed for the baseline |
| Blender Human Base Meshes bundle | Static sculpt bases with quad topology, face sets and UVs; rigging is not mentioned [source: Blender wiki dump, "Reference/Release Notes/3.6/Asset Bundles", https://julianeisel.github.io/wiki.blender.org-dump/wiki/Reference/Release_Notes/3.6/Asset_Bundles.html, read 2026-11-16] | CC0, 49 MB, v1.4.1, includes stylised meshes [source: blender.org, "Asset Bundles", https://www.blender.org/download/demo-files/, unread: snippet only] [UNSOURCED: plan/provenance-audit.md#endgame-hbm-cc0] | Unrigged; a starting point for a human sculptor, not for a script |
| Rigify | Blender's bundled auto-rig generator from a meta-rig [UNSOURCED: plan/provenance-audit.md#endgame-rigify] (docs.blender.org blocked) | ships with Blender (GPL) | Solves bones, not weights, faces or acting |
| Procedural mannequins in rigkit | Capsule-and-ellipsoid figures from the existing primitives, posed per shot | ours | **Chosen for layout.** Enough for depth, silhouette, eyelines and id mattes |

**Realistic effort and verdict.** Five speaking or featured humans with faces, a dressed restaurant set and 600
frames of final-quality Cycles on a CPU is weeks of work for a human character team, and an agent cannot judge
acting from numbers. The output would be the weakest element on screen. Blender output itself raises no licence
problem [UNSOURCED: plan/provenance-audit.md#endgame-blender-output] (blender.org blocked). **Route B alone is
rejected. Blender is kept for what it is provably good at here: layout, cameras, control passes, mattes, and exact
rigid motion of the plastic pieces.** The toy carrier is the same rigkit mesh as the in-game carrier
(`art/families/alien-carriers.json`), so the match cut can be geometrically exact.

### B4. Route C: everything generated in ComfyUI

**Video models (open weights), licence and fit on one 24 GB A5000.** "Outputs" is what the licence or card says
about generated content. VRAM figures are the sources' own unless a repo path is cited.

| Model | Licence and outputs | Ships in a GPL-3.0 repo others reuse commercially? | VRAM / size | ComfyUI | Notes |
|---|---|---|---|---|---|
| **Wan 2.2** T2V/I2V A14B, TI2V-5B | Apache 2.0; "We claim no rights over the your generated contents" [source: Wan-Video, "Wan2.2 README", https://github.com/Wan-Video/Wan2.2, read 2026-11-16] | Yes | Reference code: A14B "at least 80GB", TI2V-5B "at least 24GB" with offload options (same source). ComfyUI repack: fp8 14B experts 14.3 GB each, 5B fp16 10 GB [source: Comfy-Org, "Wan_2.2_ComfyUI_Repackaged file list", https://huggingface.co/Comfy-Org/Wan_2.2_ComfyUI_Repackaged/tree/main/split_files/diffusion_models, read 2026-11-16] | Native 5B and 14B T2V/I2V examples [source: comfyanonymous, "Wan 2.2 Models examples", https://comfyanonymous.github.io/ComfyUI_examples/wan22/, read 2026-11-16] | 5B: 720p at 24 fps, "5-second 720P video in under 9 minutes" on an unnamed consumer GPU [source: Wan-AI, "Wan2.2-TI2V-5B card", https://huggingface.co/Wan-AI/Wan2.2-TI2V-5B, read 2026-11-16] |
| **Wan 2.2 Fun VACE A14B** (installed) | Apache 2.0 [source: alibaba-pai, "Wan2.2-VACE-Fun-A14B card", https://huggingface.co/alibaba-pai/Wan2.2-VACE-Fun-A14B, read 2026-11-16] | Yes | fp8 experts 17.3 GB each (Comfy-Org file list above); runs here at 480² (`plan/render-runs/ground-forces-rework.md` §8) | Core node `WanVaceToVideo`: `control_video`, `control_masks`, `reference_image`, length default 81 [source: comfyanonymous, "ComfyUI comfy_extras/nodes_wan.py", https://github.com/comfyanonymous/ComfyUI/blob/master/comfy_extras/nodes_wan.py, read 2026-11-16] | Control by canny, depth, pose, MLSD, trajectory; subject reference; 512/768/1024; trained on 81 frames at 16 fps (card above) |
| Wan 2.2 Fun InP A14B (first and last frame) | Apache 2.0; supports first-and-last-frame prediction [source: alibaba-pai, "Wan2.2-Fun-A14B-InP card", https://huggingface.co/alibaba-pai/Wan2.2-Fun-A14B-InP, read 2026-11-16] | Yes | fp8 experts 14.3 GB each (file list above) | Core ComfyUI has `WanFunInpaintToVideo` and `WanFirstLastFrameToVideo` (nodes_wan.py above); which one this checkpoint takes is to confirm | Not installed: 28.6 GB download |
| Wan2.2-Lightning LoRA (installed) | Apache 2.0; "only 4 steps without the need of CFG" [source: lightx2v, "Wan2.2-Lightning card", https://huggingface.co/lightx2v/Wan2.2-Lightning, read 2026-11-16] | Yes | small | LoraLoaderModelOnly (`tools/production/inbetween_vace_workflow.lua`) | Trained for T2V and I2V A14B; used here on Fun VACE with on-model results (`plan/render-runs/RESUME.md`, update 2026-11-15) |
| LTX-Video / LTX-2 | Card tag "other" (LTX-Video Open Weights License) and `ltx-2-community-license-agreement`; the terms were not read [source: Lightricks, "LTX-Video card", https://huggingface.co/Lightricks/LTX-Video, read 2026-11-16] [source: Lightricks, "LTX-2 card", https://huggingface.co/Lightricks/LTX-2, read 2026-11-16] | **Unknown** until the licence text is read [UNSOURCED: plan/provenance-audit.md#endgame-ltx-terms] | 2B/13B; LTX-2 is 19B; no VRAM figure on the cards | Own node pack via ComfyUI Manager (LTX-2 card) | Fast; multi-frame conditioning. A new node pack means an upstream request |
| HunyuanVideo | Tencent Hunyuan Community License; Territory excludes "the European Union, United Kingdom and South Korea"; "Tencent claims no rights in Outputs" [source: Tencent, "HunyuanVideo LICENSE", https://huggingface.co/tencent/HunyuanVideo/blob/main/LICENSE, read 2026-11-16] | **No**: use outside the Territory is unlicensed, and outputs may not train other models; a GPL repo cannot pass those limits on | not checked | not checked | Excluded |
| FramePack | Code Apache-2.0; downloads "more than 30GB" of 13B model weights whose licence the page does not state; 6 GB minimum; 30 fps [source: lllyasviel, "FramePack README", https://github.com/lllyasviel/FramePack, read 2026-11-16] | Unknown (weights licence unread) | 6 GB | own app | Excluded: unknown weights licence |
| CogVideoX-5B | CogVideoX LICENSE: commercial users "must register"; at most "1 million visits per month"; generated content belongs to the user [source: Zhipu AI, "CogVideoX-5b LICENSE", https://huggingface.co/zai-org/CogVideoX-5b/blob/main/LICENSE, read 2026-11-16] | No: registration and a traffic cap cannot be passed on | diffusers from 5 GB; 720×480, 8 fps, 6 s [source: Zhipu AI, "CogVideoX-5b card", https://huggingface.co/zai-org/CogVideoX-5b, read 2026-11-16] | not checked | Excluded; also the lowest resolution |
| Stable Video Diffusion XT | `stable-video-diffusion-community`; commercial terms at stability.ai, not read [source: Stability AI, "stable-video-diffusion-img2vid-xt card", https://huggingface.co/stabilityai/stable-video-diffusion-img2vid-xt, read 2026-11-16] [UNSOURCED: plan/provenance-audit.md#endgame-svd-terms] | Unknown | 25 frames at 576×1024 | native (not checked) | Card lists: at most about 4 s, little motion, no text control, "Faces and people … may not be generated properly". Excluded |
| AnimateDiff | Code Apache-2.0; SDXL beta needs about 13 GB, 1024×1024×16 frames, "Small fickering is noticable" [source: Guo et al., "AnimateDiff README", https://github.com/guoyww/AnimateDiff, read 2026-11-16] | Yes (with an OpenRAIL base) | ~13 GB | custom nodes | 16-frame clips with flicker: below the bar |

**Still-image models for keyframes.**

| Model | Licence and outputs | Ship? | Size / VRAM | Here |
|---|---|---|---|---|
| Qwen-Image-Edit-2511 | Apache 2.0; reduced drift, better character consistency incl. groups, several input images [source: Qwen, "Qwen-Image-Edit-2511 card", https://huggingface.co/Qwen/Qwen-Image-Edit-2511, read 2026-11-16] | Yes | fp8 on disk; 21 s/image with Lightning at 1.6 MP, 5.3 min at 40 steps (`plan/render-runs/carrier-v3.md` §4) | **Installed; the workhorse** |
| Qwen-Image / 2512 | Apache 2.0, 20B, strong text rendering [source: Qwen, "Qwen-Image card", https://huggingface.co/Qwen/Qwen-Image, read 2026-11-16] | Yes | `qwen_image_2512_fp8_e4m3fn` 20.4 GB [source: Comfy-Org, "Qwen-Image_ComfyUI file list", https://huggingface.co/Comfy-Org/Qwen-Image_ComfyUI/tree/main/split_files/diffusion_models, read 2026-11-16] | Pinned, not on disk |
| Qwen-Image-Layered | Apache 2.0; "decomposing an image into multiple RGBA layers", 3 to 8 layers in the examples, 640 px recommended [source: Qwen, "Qwen-Image-Layered card", https://huggingface.co/Qwen/Qwen-Image-Layered, read 2026-11-16] | Yes | fp8mixed 20.5 GB [source: Comfy-Org, "Qwen-Image-Layered_ComfyUI file list", https://huggingface.co/Comfy-Org/Qwen-Image-Layered_ComfyUI/tree/main/split_files/diffusion_models, read 2026-11-16] | Not installed; node support unverified [UNSOURCED: plan/provenance-audit.md#endgame-layered-comfy] |
| FLUX.2 klein 4B | Apache 2.0, "available for commercial use"; text-to-image and multi-reference editing; "~13GB VRAM" [source: Black Forest Labs, "FLUX.2-klein-4B card", https://huggingface.co/black-forest-labs/FLUX.2-klein-4B, read 2026-11-16] | Yes | on disk; about 6 s/image (`plan/render-runs/ground-forces-rework.md` §5) | **Installed**; fast exploration |
| SDXL base 1.0 (+ ControlNet union, IP-Adapter, LayerDiffuse) | CreativeML Open RAIL++-M: "Licensor claims no rights in the Output"; use restrictions only [source: Stability AI, "SDXL base 1.0 LICENSE.md", https://huggingface.co/stabilityai/stable-diffusion-xl-base-1.0/blob/main/LICENSE.md, read 2026-11-16] | Yes | on disk | **Installed**; depth/canny control and transparent layers |
| FLUX.1 schnell | Apache 2.0, "personal, scientific, and commercial purposes", 12B, 1–4 steps [source: Black Forest Labs, "FLUX.1-schnell card", https://huggingface.co/black-forest-labs/FLUX.1-schnell, read 2026-11-16] | Yes | host `image.generate` tier I3 (`plan/asset-provenance.md`, QR poster) | Available on the host engine, no control inputs there |
| Z-Image-Turbo | Apache 2.0, 6B, 8 NFE, "16G VRAM consumer devices"; Z-Image-Edit "To be released" [source: Tongyi-MAI, "Z-Image-Turbo card", https://huggingface.co/Tongyi-MAI/Z-Image-Turbo, read 2026-11-16] | Yes | not installed | No edit model; no gain over what is installed |
| HiDream-I1 | MIT, 17B, but pulls `meta-llama/Llama-3.1-8B-Instruct` under its own licence [source: HiDream-ai, "HiDream-I1 README", https://github.com/HiDream-ai/HiDream-I1, read 2026-11-16] | With the Llama terms attached | not installed | Not worth a second licence |
| FLUX.1 dev, FLUX.1 Kontext dev | FLUX.1 [dev] Non-Commercial License v1.1.1. §2(d) lets outputs be used "for any purpose (including for commercial purposes)", while the model may only be run for non-commercial purposes and §4(a) restricts data it produces for commercial or production purposes [source: Black Forest Labs, "FLUX.1-dev LICENSE.md", https://huggingface.co/black-forest-labs/FLUX.1-dev/blob/main/LICENSE.md, read 2026-11-16] [source: Black Forest Labs, "FLUX.1-Kontext-dev card", https://huggingface.co/black-forest-labs/FLUX.1-Kontext-dev, read 2026-11-16] | **No**: conflicting text, and nothing we may rely on for downstream commercial reuse | – | Excluded, as in `plan/asset-pipeline/models-24gb.md` §1 |

**Support models.**

| Job | Model | Licence | Here |
|---|---|---|---|
| Matting | BiRefNet | MIT (tray table) | installed |
| Depth from a still | Depth Anything V2 **Small** is Apache-2.0; Base, Large and Giant are CC-BY-NC-4.0 [source: Yang et al., "Depth-Anything-V2 README", https://github.com/DepthAnything/Depth-Anything-V2, read 2026-11-16] | Small only | **not needed**: the Blender layout already renders true depth |
| Segmentation | SAM 2.1, code and checkpoints Apache 2.0, 39–224 M [source: Meta, "sam2 README", https://github.com/facebookresearch/sam2, read 2026-11-16] | Apache 2.0 | not needed: the layout renders id mattes; BiRefNet covers the rest |
| Frame interpolation | RIFE (Practical-RIFE), MIT incl. the trained models; v4.24+ "suitable for post-processing some diffusion-model-generated videos" [source: hzwer, "Practical-RIFE README", https://github.com/hzwer/Practical-RIFE, read 2026-11-16]. FILM: Apache-2.0, repository archived 2025-10-14 [source: Google Research, "frame-interpolation README", https://github.com/google-research/frame-interpolation, read 2026-11-16]. ComfyUI pack with both: MIT [source: Fannovel16, "ComfyUI-Frame-Interpolation README", https://github.com/Fannovel16/ComfyUI-Frame-Interpolation, read 2026-11-16] | MIT / Apache | not installed; only the video upgrade needs it (16 to 24 or 32 fps) |
| Upscale | Real-ESRGAN x4plus, BSD-3-Clause, 66.9 MB [source: Xinntao, "Real-ESRGAN README", https://github.com/xinntao/Real-ESRGAN, read 2026-11-16] [source: Comfy-Org, "Real-ESRGAN_repackaged file list", https://huggingface.co/Comfy-Org/Real-ESRGAN_repackaged/tree/main, read 2026-11-16] | BSD-3 | pinned, not on disk; optional |

**Outputs in a GPL-3.0 repository.** The Apache-2.0 and OpenRAIL++ models above claim no rights in outputs (quotes
above), so the model licences put no condition on shipping the images under the repo's terms. Two separate
questions stay open and are not settled by this research: whether a tool's licence ever reaches its output
[UNSOURCED: plan/provenance-audit.md#endgame-gpl-output] (gnu.org blocked), and how much copyright exists in
generated images at all [UNSOURCED: plan/provenance-audit.md#endgame-ai-copyright] (copyright.gov blocked). The
plan's answer is practical: commit the human-authored parts (layout, family JSON, prompts, picks, compositing) and
record every model in `plan/asset-provenance.md`, as the repo already does.

**Honest consistency problems of a fully generated film** [UNSOURCED: plan/provenance-audit.md#endgame-quality-judgement],
with the repo's own evidence where it exists:
- *Identity across shots.* Seven shots need the same four people from different angles. Text-only generation "could
  not draw the characters" in the macron.dev job (`plan/round2-research.md` §1.1). Reference editing helps, but
  per-view generation drifts (`plan/round2-research.md` §1.4).
- *Things that must not move do.* Board pieces, dice pips and cards re-form between frames of a video model. In a
  layered still they cannot.
- *Text.* "Krybor's" on a sign will not survive a moving shot letter-perfect. SVD's card states it "cannot render
  legible text"; Qwen-Image is the only family here that claims reliable text, and only in stills.
- *Hands and liquid.* Pouring soda is hands plus fluid plus a glass edge: the hardest content in the film.
- *Lips.* No installed model syncs lips to audio. Wan 2.2 S2V exists (16.4 GB fp8, file list above) but is one more
  download and untested here.
- *Length and joins.* Clips are 81 frames at 16 fps, about 5 s; separate runs do not splice
  (`plan/round2-research.md` §1.2 item 7), so every cut must be a real cut.
- *Flicker and resolution.* 480p–720p at 16 fps needs interpolation and upscaling to look clean full-screen.

**Verdict.** Route C alone is rejected as the base. Its stills are the strongest asset we can make; its video is
used only in short, controlled, single-subject inserts.

### B5. Route H: the hybrid, in two variants

- **H1, control video.** Blender renders a depth clip per shot; Fun VACE turns clip plus a styled reference still
  into video; interpolate, upscale, composite, ship as video. Proven end to end by macron.dev on this studio image
  with no custom nodes (`plan/round2-research.md` §1.1). It inherits Route C's problems for multi-character shots.
- **H2, layered stills.** Blender renders clay, depth and id for a shot's key pose; ComfyUI makes the styled still
  from the clay (the `carrier-hero-qwen` recipe); layers are produced **by generation, not by cutting**: an empty
  back plate, then each character or prop group on a key colour with the back plate as reference, matted with
  BiRefNet. The id pass tells the tools where each layer sits and the depth pass gives each layer its parallax
  distance, so no depth estimator and no segmentation model is needed. The engine animates the layers.

**Chosen: H2 as the base, H1 for inserts, the projection bake for rigid toys.** Reasons: static things stay static;
text is a layer we can check and fix; identity is solved once per character on a reference sheet and reused by
edit; reduced motion, subtitles, skip and tests are ordinary Flutter; nothing needs a download.

### B6. Runtime form in Flutter web

What the repo does today:
- The ending is `lib/ending/ending_page.dart`: a Flutter route (not Flame), one `AnimationController` of 8 s (3 s
  with `MediaQuery.disableAnimationsOf`), `Transform.scale` pulling back from `assets/images/beach-ending.webp`
  (239 KB), a skip button (`ValueKey('ending-skip')`), then credits. `lib/main.dart:545` pushes it;
  `creditsOnly` already gives a menu entry point.
- `pubspec.yaml` has no `video_player`; dependencies are flame, url_launcher, http. Assets are listed per directory.
- Audio plays through one shared `AudioContext` in `web/audio/*.js` (`decodeAudioData`, `.ogg` plus `.m4a` pairs).
- `web/sw.js` is deliberately cache-free: there is no PWA precache, so nothing is downloaded before it is used
  (`openspec/changes/pwa-install/proposal.md`). `assets/images` is 29 MB on disk. No asset size budget is documented.
- `cinematic-flow` set the house rules for transitions: one beat clock, motivated cuts, no all-black frame, skip
  at once, reduced motion keeps the same beats (`openspec/changes/cinematic-flow/proposal.md`).

| | (1) Video file | (2) In-engine 2.5D | (3) In-engine plus inserts |
|---|---|---|---|
| Look ceiling | Highest if the footage is good; fails whole if it flickers | Limited animation, but every frame is a picked still | Same as (2) with real motion in 2–3 places |
| Player | `video_player` 2.14.1, BSD-3-Clause, web supported [source: flutter.dev, "video_player", https://pub.dev/packages/video_player, read 2026-11-16] | Flutter `CustomPainter` on the existing route | same as (2) |
| Platform view | HTML `<video>` embedded in the canvas: "a potentially expensive operation"; each split is an overlay with memory and execution cost; it can swallow pointer events (the skip tap) [source: Flutter, "HtmlElementView class", https://api.flutter.dev/flutter/widgets/HtmlElementView-class.html, read 2026-11-16] | none | none |
| Sound start | Unmuted video without a user interaction is blocked and "can cause runtime errors" [source: flutter.dev, "video_player_web", https://pub.dev/packages/video_player_web, read 2026-11-16]; autoplay is allowed once "the user has interacted with the site" [source: MDN, "Autoplay guide for media and Web Audio APIs", https://developer.mozilla.org/en-US/docs/Web/Media/Guides/Autoplay, read 2026-11-16]. iOS rules and `playsinline` could not be read [UNSOURCED: plan/provenance-audit.md#endgame-ios-gesture] | the game's `AudioContext` is already running when the last boss dies | same as (2) |
| Codecs | H.264 plays in every browser; AV1 on Safari only on "M3 MacBooks and later, iPhone 15 Pro, and iPhone 16 and later"; MDN recommends WebM AV1+Opus first with MP4 H.264+AAC as fallback [source: MDN, "Web video codec guide", https://developer.mozilla.org/en-US/docs/Web/Media/Guides/Formats/Video_codecs, read 2026-11-16]. WebM is full in Safari 16 and iOS Safari 17.4 and later [source: caniuse, "webm.json", https://raw.githubusercontent.com/Fyrd/caniuse/main/features-json/webm.json, read 2026-11-16] | WebP stills, already used | WebP stills and frame strips |
| Seeking | needs HTTP range requests on the host (video_player_web above) | n/a | n/a |
| Subtitles, localisation | burned in, or Flutter text over a platform view | Flutter text | Flutter text |
| Voices | baked into the file: one file per language; or muted video plus clips with drift risk | separate clips, replaceable when `voice-stack` re-renders | same as (2) |
| Reduced motion | needs a second, still version anyway | same data, moves off, cuts become fades | same; inserts hold a frame |
| Tests | cannot assert pixels or timing in `flutter test` | pure function of time: golden frames, beat checks | same |
| Determinism | decoder-dependent | deterministic | deterministic |

Reduced motion is a requirement, not polish: the preference asks pages to "remove, reduce or replace" motion such
as "scaling or panning large objects" [source: MDN, "prefers-reduced-motion", https://developer.mozilla.org/en-US/docs/Web/CSS/Reference/At-rules/@media/prefers-reduced-motion, read 2026-11-16],
which is exactly what a parallax pull-back is. The repo already reads it through `MediaQuery.disableAnimationsOf`.

H.264 in a GPL project: x264 is GPLv2 [source: VideoLAN x264 mirror, "COPYING", https://github.com/mirror/x264/blob/master/COPYING, read 2026-11-16]
and the forge's ffmpeg is a GPL build with it. An encoder's licence is not expected to reach the encoded file
[UNSOURCED: plan/provenance-audit.md#endgame-gpl-output]. The patents are the real question: "Commercial use of AVC
media requires a license, though the Via LA patent pool does not require license fees for streaming internet video
in AVC format as long as the video is free for end users" (MDN codec guide above). That covers this free game but
not every downstream commercial reuser. **Decision: if a video is ever shipped, ship only royalty-free codecs**
(WebM with AV1 or VP9 and Opus; both encoders are in the forge's ffmpeg) and let browsers that cannot play it keep
the in-engine scene. No H.264 file enters the repo.

**Chosen: (3).** The player is a data-driven widget (working name `CinematicPlayer`) that replaces the `_beach`
reveal in `EndingPage`: a shot list (JSON asset) with per-shot layers, camera keys, focus keys, strips, subtitle
cues and audio cues on one clock, in the style of `cinematic-flow`. Skip stays the existing button. Replay from the
menu reuses the existing `creditsOnly`-style entry, gated on having finished once.

### B7. The pipeline, stage by stage

Working names; paths are proposals. Committed artefacts follow CLAUDE.md §5 (picked raws and the recipe in the
repo). "Approval" is an operator checkpoint; picks are made by the agent and logged, per the autonomy rule.

| # | Stage | Input | Tool | Output | Committed under | GPU | Approval |
|---|---|---|---|---|---|---|---|
| 0 | Storyboard and shot list | Part A | by hand | shot family `art/cinematic/endgame/shots.json`: per shot the duration, lens, camera keys, cast, props, layer list, subtitle and audio cues | `art/cinematic/endgame/` | no | **CP0** storyboard |
| 1 | Layout | shot family; `art/families/alien-carriers.json` for the toy | new `tools/cinematic/layout.py` on `rigkit.py` (bpy, CPU): set blockout, mannequins, cameras | per shot: clay, depth, normal, id at the key pose; a depth clip for insert shots; `layout.json` (cameras, layer depths, id colours) | passes in `~/.cache`; contact sheet `art/contact/endgame-layout.png` | no | **CP1** animatic: the layout played in-engine with grey plates |
| 2 | Character and prop sheets | cast descriptions from Part A; radio portraits as loose reference | `variant-qwen-edit.json`, FLUX.2 klein for exploration | one model sheet per person (front, three-quarter, expression set), one for the board pieces | `art/cinematic/endgame/selected/sheets/` | yes | **CP2** the look of the cast |
| 3 | Keyframe stills | clay and depth per shot, sheets as references | `carrier-hero-qwen-fast.json` for exploration, `carrier-hero-qwen.json` for the pick (clay to styled image; reference images beside the clay) | one approved still per shot, 1.6 MP | `…/selected/keys/` | yes | **CP3** seven stills |
| 4 | Layer plates | the still, the id pass | Qwen edit: remove the cast for the back plate; each cast or prop group re-rendered on a key colour; `matte-birefnet-batch.json`; LayerDiffuse as an alternative | 3–5 RGBA plates per shot, registered to the layout frame | `…/selected/plates/` | yes | sheet only |
| 5 | Rigid toy motion | the toy still, the carrier mesh | `rigkit/bake.py --poses 1` (projection bake, CPU) | 6–8 pose frames of the tipping toy with its shadow | pose atlas | no | sheet only |
| 6 | Motion inserts | depth clip, the shot's still as reference | `inbetween-wan-vace.json` scaled to the insert's crop; matte | 16–33 frames per insert, cropped to the moving region | `…/selected/inserts/` | yes | **CP4** inserts in context |
| 7 | Finish and pack | plates, strips, `layout.json` | new `rigsheet` verb (Go): registration check, edge despill, grain match, WebP encode, strip atlases, the shot JSON for the game | `assets/images/cinematic/*.webp`, `assets/cinematic/endgame.json` | the assets | no | – |
| 8 | Voices and sound | Part A's script | the `voice-stack` change (B8); ambience and music from the #1103 audio studio | 8–10 line clips, one ambience bed, one sting | `web/audio/cinematic/` | yes | **blocked on tillandsias#1103** |
| 9 | Runtime | the packed assets | `lib/ending/` player, widget tests, golden frames | the playable cinematic | code | no | **CP5** on a phone |
| 10 | Optional video cut | the same shots through H1, RIFE, upscale, ffmpeg (AV1/VP9) | new downloads | `web/video/endgame-720.webm`, lazy-loaded | recipe and picks | yes | later, separate decision |

Run stages 2–6 through `lua tools/production/run.lua <job.lua>` so each job is fingerprinted, resumable and
ledgered in `plan/render-runs/endgame-cinematic/` (`tools/production/README.md`). One studio job at a time; free
VRAM with `gpu.unload_model`; never `studio.restart`.

### B8. Voices

The cinematic depends on `openspec/changes/voice-stack` and does not redesign it. What it needs from it:
- about 8–10 short lines for four speakers (two kids, waitress, owner, mom), as `final`-tier clips in the existing
  `.ogg` plus `.m4a` pair format;
- the **same committed voice identities** as the Admiral, the General and the purple cadet, because the reveal is
  that these are the same people (`plan/operator-feedback-2026-11-16.md` E1);
- two new child identities by voice design, frozen as identity clips (`plan/voice-stack-research.md` §8 item 1);
- a **room chain instead of the radio chain**: no band-pass, no squelch, no saturation; a short restaurant
  reverb, light compression, the same loudness target. This is one new named chain in `art/comms/audio.json` terms,
  not a new engine;
- direction fields (`emotion`, `intensity`, `direction`) used as designed there.

Until tillandsias#1103 lands, the cinematic ships with `"pending": "text"` lines: subtitles only, with ambience
if any exists. Nothing here works around #1103 (CLAUDE.md §5).

Lip sync is avoided by staging, not solved: speakers are off-screen, small in frame, turned away, or shown with
two or three swapped mouth poses timed from the clip's loudness envelope at build time. Rhubarb Lip Sync (MIT,
command-line, mouth shapes from audio) is the next step up if the envelope reads badly
[source: Daniel S. Wolf, "rhubarb-lip-sync README" and "LICENSE.md", https://github.com/DanielSWolf/rhubarb-lip-sync, read 2026-11-16];
it would be a new forge tool, so an upstream request [UNSOURCED: plan/provenance-audit.md#endgame-lipsync].

### B9. Per-shot technique

Shot numbering follows the brief; Part A's storyboard is authoritative for content and timing.

| # | Shot | Seconds | Technique | Layers | Motion source | Hard part |
|---|---|---|---|---|---|---|
| 1 | The carrier falls (game look) | 2–3 | The in-game carrier art, then a cross-dissolve to the styled toy at the same silhouette | game sprite; toy plate | in-engine; the toy still comes from the same rigkit mesh and camera, so the outlines register | the match of silhouette and angle |
| 2 | The toy tips over on the board | 2–3 | Projection-baked pose frames of the rigid toy over a board plate; a hand enters as one more plate | board, toy poses, shadow, hand | stage 5 (CPU, exact) | the contact shadow; the hand |
| 3 | Pull-back over the board | 4–5 | One large still (2.4 MP refine), slow dolly-out with 4-layer parallax and a rack focus from pieces to faces | near pieces (blurred), board, far pieces and dice, table edge and room | in-engine camera | piece count and identity vs the game; dice and cards must stay sharp and fixed |
| 4 | Kids at the table | 3–4 | Still with separate kid plates; blink and head-turn as 2–3 swapped pose plates; first lines | room, table, kid A, kid B, foreground cups | pose swaps; optional VACE insert for a laugh | two children consistent with their sheets; hands on pieces |
| 5 | Waitress pours soda | 3–4 | Still plus a cropped **insert** of the pour (glass, stream, fizz); her line plays over it | room, waitress, arm and jug, glass insert | stage 6 (Fun VACE, depth clip, about 2 s) | liquid and hand: the riskiest insert; fallback is a 4-frame fizz loop with the jug already tilted |
| 6 | Owner at the grill | 2–3 | Still; flame flicker and smoke as procedural layers in the painter; smile is a pose swap | kitchen, owner, grill glow, smoke | in-engine effects | keeping him recognisable as the General |
| 7 | Mom: "time to go" | 3 | Still, slow push-in; kids' reaction as a pose swap | doorway light, mom, table foreground | in-engine camera | keeping her recognisable as the Admiral |
| 8 | Exterior, golden hour, "Krybor's" | 4–5 | Widest still; sky, sea shimmer and string lights animated in the painter; sign as its own checked layer; title and credits roll over it | sky, sea, building, sign, foreground palms | in-engine effects; optional VACE insert for waves | the sign text: generate with Qwen, verify letter by letter, repaint if wrong |

The brief counts "about 7 shots"; rows 1 and 2 are one shot across a match cut.

### B10. Budgets

**GPU time on the A5000** (one job at a time). Rates are the repo's measurements; totals are our arithmetic.

| Work | Jobs | Rate (source) | Time |
|---|---|---|---|
| Sheets: 5 people + pieces, 8 candidates, 3 views | ~150 | 21 s, Qwen Lightning 1.6 MP (`plan/render-runs/carrier-v3.md` §4) | ~0.9 h |
| Keyframes, exploration: 8 shots × 8 seeds × 2 rounds | ~130 | 21 s | ~0.8 h |
| Keyframes, picks: 8 shots × 4 seeds at 40 steps | 32 | 5.3 min (same source) | ~2.8 h |
| Refine the two widest stills | 2–4 | 4.5 min (same source) | ~0.3 h |
| Layer plates: 8 shots × ~4 layers × 4 candidates, plus mattes | ~130 + mattes | 21 s; BiRefNet 4 s (`plan/render-runs/ground-forces-rework.md` §5) | ~1.0 h |
| Inserts: 3 inserts × 6 candidates, 33 frames | 18 | 34 s per 17 frames at 480² with Lightning (same file, §8); larger crops scale up | ~0.5 h |
| Rerolls, 30 % | | | ~1.9 h |
| **Total** | | | **about 8 h**, lean (Lightning picks only) about 3.5 h |

- VRAM: every job above uses checkpoints that already run on this card. The two Fun VACE experts are 17.3 GB each
  and are loaded in turn. A full-frame 832×480×81 or 720p VACE clip has **not** been run here; its time and whether
  720p fits are unknown [UNSOURCED: plan/provenance-audit.md#endgame-vace-720]. Keep inserts cropped and at most
  33 frames until a pilot measures it.
- The studio shares the card with the host LLM; `gpu.status` must show room before a batch, and other projects'
  studios take turns through the coordinator (`plan/round2-research.md` §1.3).
- CPU (Blender in the forge): 8 shots × 4 passes at about 1280×720, plus three 33-frame depth clips, plus the toy
  bake. At the measured 2.6 s per 384² Workbench render this is minutes, not hours; one process, 8 threads, under
  2 GB, never beside `flutter test` or `npm run build` [UNSOURCED: plan/provenance-audit.md#endgame-cycles-cpu].

**Web build size** (targets; WebP sizes are estimates until the first pack
[UNSOURCED: plan/provenance-audit.md#endgame-webp-size]):

| Item | Count | Each | Total |
|---|---|---|---|
| Back plates, 1600×900 lossy WebP | 8 | ~200 KB | ~1.6 MB |
| Cast and prop plates with alpha | ~24 | ~90 KB | ~2.2 MB |
| Toy pose atlas, insert strips | 4 | ~350 KB | ~1.4 MB |
| Shot JSON | 1 | < 30 KB | – |
| Voice clips, both codecs | 10 × 2 | ~25 KB | ~0.5 MB |
| Ambience bed and sting, both codecs | 2 × 2 | ~250 KB | ~1.0 MB |
| **Budget** | | | **≤ 7 MB, hard cap 10 MB** |

For scale: `assets/images` is 29 MB today and the current ending image is 239 KB. Nothing is fetched until the
player asks for it, because the service worker caches nothing; precache the cinematic's images during the final
carrier fight (`precacheImage`, as `lib/main.dart:378` does for hints) and evict them when the route closes.

**Phone GPU memory** (our arithmetic: width × height × 4 bytes). A 1600×900 plate decodes to 5.8 MB; a shot with
four plates is 23 MB, and holding the current and the next shot is 46 MB. On small screens decode at 1024×576
(2.4 MB per plate, 19 MB for two shots) with `ResizeImage`, which exists "to reduce the memory footprint of
ImageCache" [source: Flutter, "ResizeImage class", https://api.flutter.dev/flutter/painting/ResizeImage-class.html, read 2026-11-16].
A 6×6 strip of 320×320 frames is 1920×1920, 14.7 MB decoded; allow one at a time. Rack-focus blur is drawn on at
most two layers at once; reduced motion and a low-end switch turn it into a cross-fade between a sharp and a
pre-blurred plate.

**If the video upgrade is ever made** (arithmetic: bitrate × 25 s; bitrates are assumptions
[UNSOURCED: plan/provenance-audit.md#endgame-video-bitrate]): 720p at 2.5 Mbit/s is 7.8 MB, 1080p at 5 Mbit/s is
15.6 MB, plus about 0.3 MB of audio. Host it under `web/video/`, outside the Flutter asset bundle, fetched only
when the cinematic starts on a browser that reports it can play the codec.

### B11. What we need

**Nothing new (the zero-download baseline).** Stages 0–7 and 9 run on what is installed: bpy 5.3.0 venv; Qwen-Image-
Edit-2511 with Lightning; FLUX.2 klein 4B; SDXL with ControlNet union, IP-Adapter and LayerDiffuse; BiRefNet; Wan
2.2 Fun VACE 14B with the Lightning LoRAs; core ComfyUI nodes only; ffmpeg; Go and Lua. No consent token, no
upstream request. Voices are the one exception (below).

**Optional models, each a consent-token download** (show the studio's `ask` sentence to the operator word for word;
never start a download ourselves):

| Model | Size | Licence | Why | Needed for |
|---|---|---|---|---|
| `RealESRGAN_x4plus` (pinned) | 66.9 MB | BSD-3-Clause | sharper widest stills and insert frames | quality step, cheap |
| `qwen_image_2512_fp8_e4m3fn` (pinned) | 20.4 GB | Apache 2.0 | text-to-image for sets and the sign when edit-from-clay is too literal; best open text rendering | stage 3 alternative |
| Wan 2.2 Fun InP A14B, high and low, fp8 | 2 × 14.3 GB | Apache 2.0 | first-and-last-frame inserts between two approved stills | stage 6 alternative |
| Qwen-Image-Layered fp8mixed | 20.5 GB | Apache 2.0 | automatic RGBA layer decomposition of a still; replaces part of stage 4 | only if generated plates misregister |
| Wan 2.2 I2V A14B, high and low, fp8 | 2 × 14.3 GB | Apache 2.0 | free image-to-video for the stage 10 video cut | stage 10 only |
| RIFE 4.x weights | not checked | MIT | 16 fps to 24 or 32 fps | stage 10 only |

**ComfyUI nodes.** Baseline: none beyond core (`WanVaceToVideo`, `TextEncodeQwenImageEditPlus`, BiRefNet and
LayerDiffuse nodes already present). Stage 10 would need a frame-interpolation node pack (MIT, B4): request it
upstream through a tillandsias issue; do not build it in-forge. Qwen-Image-Layered needs its node support
confirmed first.

**Tools to write (in the repo):** `tools/cinematic/layout.py` (bpy, on `rigkit.py`; Python only because bpy forces
it); a `rigsheet` verb for plate registration and packing (Go); production job files (Lua); the runtime player and
its tests (Dart). A Lua or Go WebP encoder path is needed because the forge has no `cwebp`: use ffmpeg's encoder
if this build has one (check at implementation), else Go.

**Operator approvals:** CP0 storyboard, CP1 animatic, CP2 cast look, CP3 stills, CP4 inserts, CP5 on a phone; a
consent token per optional model; and one decision now: confirm that the open, royalty-free-only rule for any
future video file is wanted.

**Upstream requests (none blocks the baseline):** voices and ambience wait on tillandsias#1103 and the
`voice-stack` admissions (`plan/voice-stack-research.md` §9.1); a reset-proof bpy toolchain image is already asked
for (`plan/round2-research.md` §2.3); a frame-interpolation node pack and Rhubarb only if stage 10 or mouth shapes
are wanted.

**Provenance records to add when work starts:** one `plan/asset-provenance.md` paragraph per asset group (models,
revisions, workflows, seeds), the run ledger, and `assets/credits.json` entries. `licences/acknowledgements/` holds
operator-signed acknowledgements for restricted licences (today only `adefossez-htdemucs.yaml`); nothing in the
baseline needs one, because every baseline model is Apache-2.0, MIT or OpenRAIL.

### B12. Risks

| Risk | Likelihood | Effect | Mitigation |
|---|---|---|---|
| The cast drifts between shots | high | the reveal (same people as the radio cast) fails | sheets first (CP2); every still is an edit *from* the sheet; one costume and one hair shape per person; reject by side-by-side sheet |
| Stills look like "AI 3D", not a designed film | medium | misses the bar | a written look guide in Part A (lens, key light, palette per shot); the layout fixes composition; 40-step picks; grain and a shared grade in the packer |
| Layers misregister or show halos under parallax | medium | cheap motion-comic feel | small parallax amplitudes; generated back plates behind every cut-out; despill in the packer; registration gate against the id pass |
| The soda pour insert is unusable | high | shot 5 loses its motion | cropped insert only; fallback fizz loop; the shot reads from pose and line alone |
| "Krybor's" is misspelt | medium | visible error on the last frame | the sign is its own layer; letter check at CP3; Qwen-Image 2512 if the edit model fails |
| Children in generated images | low | policy and taste | stylised, fully clothed, family-restaurant staging only; no likeness of any real person; prompts name no studio, film or artist; the OpenRAIL use restrictions are respected |
| A "Pixar-like" look copies a studio's style too closely | low | originality complaint | describe traits (soft subsurface skin, large eyes, warm bounce light), never a name, as the repo already does for music |
| Phones run out of image memory | medium | a crash at the emotional peak | decode at 1024 wide on small screens; two shots resident at most; strips one at a time; test on the operator's phone at CP5 |
| Voices are late (#1103) | high | no dialogue | subtitles-only cut ships first; clips drop in by name later |
| A host reset wipes raws and the venv | medium | lost picks | commit picked raws and recipes at every checkpoint (CLAUDE.md §5); `setup_bpy.lua` rebuilds the venv |
| The studio and another GPU user collide | medium | failed jobs | check `gpu.status`; one job at a time; never `studio.restart` |
| "Installed" Wan files trigger a re-download on first use | low | a surprise 41 GB fetch (`plan/round2-research.md` §1.3) | the VACE graphs have run on this studio since (2026-11-15); if a job answers `consent_required`, stop and ask |
| Scope creep toward full animation | medium | weeks lost | stage 10 is a separate, later decision with its own change |

### B-sources

| Source | URL | Status |
|---|---|---|
| Wan-Video, Wan2.2 README | https://github.com/Wan-Video/Wan2.2 | read |
| Wan-AI, Wan2.2-TI2V-5B card | https://huggingface.co/Wan-AI/Wan2.2-TI2V-5B | read |
| alibaba-pai, Wan2.2-VACE-Fun-A14B card | https://huggingface.co/alibaba-pai/Wan2.2-VACE-Fun-A14B | read |
| alibaba-pai, Wan2.2-Fun-A14B-InP card | https://huggingface.co/alibaba-pai/Wan2.2-Fun-A14B-InP | read |
| lightx2v, Wan2.2-Lightning card | https://huggingface.co/lightx2v/Wan2.2-Lightning | read |
| Comfy-Org, Wan 2.2 repackaged file list | https://huggingface.co/Comfy-Org/Wan_2.2_ComfyUI_Repackaged/tree/main/split_files/diffusion_models | read |
| comfyanonymous, Wan 2.2 examples | https://comfyanonymous.github.io/ComfyUI_examples/wan22/ | read |
| comfyanonymous, Wan 2.1 examples | https://github.com/comfyanonymous/ComfyUI_examples/tree/master/wan | read |
| comfyanonymous, ComfyUI `nodes_wan.py` (page truncated after `WanSoundImageToVideoExtend`) | https://github.com/comfyanonymous/ComfyUI/blob/master/comfy_extras/nodes_wan.py | read (partly) |
| Lightricks, LTX-Video card; LTX-2 card (licence texts not read) | https://huggingface.co/Lightricks/LTX-Video ; https://huggingface.co/Lightricks/LTX-2 | read (cards only) |
| Tencent, HunyuanVideo LICENSE | https://huggingface.co/tencent/HunyuanVideo/blob/main/LICENSE | read |
| Zhipu AI, CogVideoX-5b card and LICENSE | https://huggingface.co/zai-org/CogVideoX-5b | read |
| Stability AI, SVD XT card | https://huggingface.co/stabilityai/stable-video-diffusion-img2vid-xt | read (card only) |
| lllyasviel, FramePack README | https://github.com/lllyasviel/FramePack | read |
| Guo et al., AnimateDiff README | https://github.com/guoyww/AnimateDiff | read |
| Black Forest Labs, FLUX.1-dev LICENSE.md | https://huggingface.co/black-forest-labs/FLUX.1-dev/blob/main/LICENSE.md | read |
| Black Forest Labs, FLUX.1-schnell, FLUX.1-Kontext-dev, FLUX.2-klein-4B cards | https://huggingface.co/black-forest-labs | read |
| Qwen, Qwen-Image, Qwen-Image-Edit-2511, Qwen-Image-Layered cards | https://huggingface.co/Qwen | read |
| Comfy-Org, Qwen-Image and Qwen-Image-Layered file lists | https://huggingface.co/Comfy-Org/Qwen-Image_ComfyUI ; https://huggingface.co/Comfy-Org/Qwen-Image-Layered_ComfyUI | read |
| Stability AI, SDXL base 1.0 LICENSE.md | https://huggingface.co/stabilityai/stable-diffusion-xl-base-1.0/blob/main/LICENSE.md | read |
| Tongyi-MAI, Z-Image-Turbo card | https://huggingface.co/Tongyi-MAI/Z-Image-Turbo | read |
| HiDream-ai, HiDream-I1 README | https://github.com/HiDream-ai/HiDream-I1 | read |
| Depth-Anything-V2 README | https://github.com/DepthAnything/Depth-Anything-V2 | read |
| Meta, sam2 README | https://github.com/facebookresearch/sam2 | read |
| hzwer, Practical-RIFE README | https://github.com/hzwer/Practical-RIFE | read |
| Google Research, frame-interpolation README | https://github.com/google-research/frame-interpolation | read |
| Fannovel16, ComfyUI-Frame-Interpolation README | https://github.com/Fannovel16/ComfyUI-Frame-Interpolation | read |
| Xinntao, Real-ESRGAN README; Comfy-Org repack | https://github.com/xinntao/Real-ESRGAN ; https://huggingface.co/Comfy-Org/Real-ESRGAN_repackaged/tree/main | read |
| MakeHuman Community, mpfb2 README, LICENSE.CODE.md, LICENSE.ASSETS.md | https://github.com/makehumancommunity/mpfb2 | read |
| MakeHuman Community, makehuman LICENSE.md | https://github.com/makehumancommunity/makehuman/blob/master/LICENSE.md | read |
| Blender Foundation, bpy on PyPI | https://pypi.org/project/bpy/ | read |
| Blender wiki dump, 3.6 Asset Bundles | https://julianeisel.github.io/wiki.blender.org-dump/wiki/Reference/Release_Notes/3.6/Asset_Bundles.html | read |
| Daniel S. Wolf, rhubarb-lip-sync README and LICENSE.md | https://github.com/DanielSWolf/rhubarb-lip-sync | read |
| flutter.dev, video_player; video_player_web | https://pub.dev/packages/video_player ; https://pub.dev/packages/video_player_web | read |
| Flutter, HtmlElementView class; ResizeImage class | https://api.flutter.dev/flutter/widgets/HtmlElementView-class.html | read |
| Flutter, Web renderers; Web content in Flutter (nothing used) | https://docs.flutter.dev/platform-integration/web/renderers | read |
| MDN, Autoplay guide; Web video codec guide; prefers-reduced-motion | https://developer.mozilla.org/en-US/docs/Web/Media/Guides/Autoplay | read |
| caniuse, webm.json | https://raw.githubusercontent.com/Fyrd/caniuse/main/features-json/webm.json | read |
| x264 mirror, COPYING | https://github.com/mirror/x264/blob/master/COPYING | read |
| blender.org, Asset Bundles (Human Base Meshes: CC0, 49 MB, v1.4.1) | https://www.blender.org/download/demo-files/ | snippet only; page blocked |
| ComfyUI docs, Wan 2.2 and VACE tutorials | https://docs.comfy.org/tutorials/video/wan/wan2_2 | blocked |
| Blender, licence page; Rigify manual | https://www.blender.org/about/license/ ; https://docs.blender.org/manual/en/latest/addons/rigging/rigify/introduction.html | blocked |
| MakeHuman Community, MPFB home and licence FAQ | https://static.makehumancommunity.org/mpfb.html | blocked |
| GNU, GPL FAQ | https://www.gnu.org/licenses/gpl-faq.html | blocked |
| WebKit, "New video policies for iOS" | https://webkit.org/blog/6784/new-video-policies-for-ios/ | blocked |
| VideoLAN, x264 | https://www.videolan.org/developers/x264.html | blocked |
| US Copyright Office, Copyright and AI | https://www.copyright.gov/ai/ | blocked |

### B-unsourced

These ids are listed in Part E of `plan/provenance-audit.md`.

| Id | Claim | Why unsourced |
|---|---|---|
| endgame-quality-judgement | No local route reaches feature-film character animation; the list of consistency problems of generated video | our judgement, backed in part by repo evidence cited in place |
| endgame-mpfb-features | MPFB2 offers rigs, face shapes, clothes and child phenotypes | its documentation site is blocked; the README does not list features |
| endgame-hbm-cc0 | Human Base Meshes is CC0, 49 MB, v1.4.1, with stylised meshes | search snippet only; blender.org blocked |
| endgame-rigify | Rigify is bundled with Blender and generates a control rig from a meta-rig | docs.blender.org blocked |
| endgame-blender-output | Blender's licence does not cover renders made with it | blender.org blocked |
| endgame-gpl-output | A GPL tool's licence (Blender, x264, ffmpeg) does not reach its output | gnu.org blocked |
| endgame-ai-copyright | How far generated images are protected by copyright | copyright.gov blocked; a legal question |
| endgame-ltx-terms | The commercial terms of the LTX-Video and LTX-2 licences | only the cards were read |
| endgame-svd-terms | The commercial terms of the Stability community licence | stability.ai not fetched (blocked in `plan/voice-stack-research.md`) |
| endgame-layered-comfy | Qwen-Image-Layered runs with core ComfyUI nodes | inferred from the Comfy-Org repack; docs.comfy.org blocked |
| endgame-ios-gesture | iOS needs `playsinline` and a user gesture for video with sound | webkit.org blocked |
| endgame-lipsync | Envelope-timed mouth poses are good enough at this shot size | untested |
| endgame-vace-720 | Time and VRAM of a full-frame 81-frame or 720p Fun VACE clip on the A5000 | never run here |
| endgame-cycles-cpu | The layout's CPU cost is minutes | extrapolated from one 384² measurement |
| endgame-webp-size | WebP sizes per plate and the 7 MB total | estimates until the first pack |
| endgame-video-bitrate | 2.5 and 5 Mbit/s as adequate bitrates for 720p and 1080p | assumption |
