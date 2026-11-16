# Audio studio

- `voice-batch-pending.md` is **generated** ("do not edit"). Its entries come from `art/comms/lines.json`. Add or change
  a line there, then run `python3 -I tools/comms_pipeline.py dart`, which rewrites both this file and
  `lib/comms/comms_bank.dart`.
- `music-requirements.md`: the music production requirements and constraints. Music and voice rendering are blocked
  on tillandsias#1103. Until it lands, a new line either borrows a recorded placeholder clip or, with
  `"pending": "text"` on its trigger, shows its own words and speaker with no audio (`lines.json` `comment`).
- Cast rule: the ground crew (Mensah, Kessler, Voss) are on the channel in every sector and may comment on the air
  fight and the weather, not only on the ground war. Keep the line bank's tone rule: allies never die; a downed ship or
  squad is "totalled" and heads back to base.
