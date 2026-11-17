# Licences to sign (voice-stack, 2026-11-16)

Restricted licences are signed by the operator through `/accept-licence`, project by project; the signed record lands
in `licences/acknowledgements/` (format: `adefossez-htdemucs.yaml`). This list prepares one row per licence that the
voice stack needs signed. It is a record of what the texts say, not legal advice. Research and verdicts:
`plan/voice-stack-research.md` §10; spec: `openspec/changes/voice-stack/`.

**Pinning.** Each text was fetched raw through the forge proxy on 2026-11-16 at 23:39 UTC with
`curl -sS -L <URL>`, then hashed with `sha256sum` over the exact bytes received. If a later fetch hashes
differently, the licence text changed: re-read it before signing or renewing.

**Do not sign by any interim route.** Signing waits for the coordinator's proof-of-gate design (2026-11-17).

## Decide on the text itself (verbatim clauses, re-fetched and hash-checked 2026-11-17)

### 1. Fish Audio S2-Pro: is our use permitted? (sha256 `aa7d9206…c32d80`, unchanged)
The coordinator flagged this: a licence named "Research License" may be research-only, and our rules never accept
research-only. The text grants use for "any Research **or** Non-Commercial Purpose" and defines both:

> LICENSE.md line 15: "…to use, reproduce, distribute, and create Derivative Works of, and make modifications to, the
> Fish Audio Materials for any Research or Non-Commercial Purpose."

> Line 17: "\"Research Purpose\" means academic or scientific advancement, and in each case, is not primarily intended
> for commercial advantage or monetary compensation to You or others."

> Line 19: "\"Non-Commercial Purpose\" means any purpose other than a Research Purpose that is not primarily intended
> for commercial advantage or monetary compensation to You or others, such as personal use (i.e., hobbyist) or
> evaluation and testing."

> Line 25: "\"Commercial Purpose\" means any purpose other than a Research Purpose or Non-Commercial Purpose that is
> primarily intended for or directed toward commercial advantage or monetary compensation to You or others, including
> but not limited to: (i) creating, modifying, or distributing Your product or service, including via a hosted service
> or application programming interface, (ii) Your business's or organization's internal operations, and (iii) any use
> in connection with a product or service for which You charge a fee or generate revenue, whether directly or
> indirectly."

> Line 54: "**(iii) Ownership of Outputs.** As between You and Fish Audio, You own any outputs generated from the
> Models or Derivative Works to the extent permitted by applicable law."

**The point to decide (the lead's reading, not legal advice):** the licence is not research-only; it also covers
Non-Commercial Purpose, which names hobbyist use. But "Commercial Purpose" lists "(i) creating, modifying, or
distributing Your product or service" without any condition of revenue. A free, open-source game served to the public
could be read as "distributing Your product". The definition's first clause still requires the purpose to be
"primarily intended for or directed toward commercial advantage or monetary compensation", which a free hobby game is
not. The operator decides whether that reading is safe enough to accept.

### 2. Higgs Audio v2: the credit line, quoted exactly (sha256 `8b2e018e…dde9a0`, unchanged)
> LICENSE line 21: "(B) prominently display “Built with Higgs Materials licensed from Boson AI USA, Inc., Copyright
> Boson AI USA, Inc., All Rights Reserved and Meta Llama 3 licensed under the Meta Llama 3 Community License,
> Copyright Meta Platforms, Inc., All Right Reserved". based on Meta Llama 3” on a related website, user interface,
> blogpost, about page, or product documentation."

The quoted span opens with “ and closes once with a straight " (after "All Right Reserved") and once with ” (after
"based on Meta Llama 3"), so it is unclear whether ". based on Meta Llama 3" belongs to the required display text.
The credits currently show the sentence up to "All Right Reserved". To be safe, it could also show "based on Meta
Llama 3"; the operator decides.

**Operator decisions already made (2026-11-16, relayed by the coordinator):**
- Non-commercial use with a credit line is acceptable: the game is free and open source, and the credits page lists
  every model and licence. So Fish Audio S2-Pro and Higgs Audio v2 qualify as pilot challengers.
- Chatterbox is dropped. VoxCPM2 renders placeholders and final speech, Dia the non-verbals.
- IndexTTS-2.5 stays out (no row below). Revisit only if a need appears that the others cannot meet, such as exact
  duration control to fit a cue.

## Needs a signature

| # | Licence id (proposed) | Model(s) | Canonical URL of the text | sha256 of the text as fetched | Bytes | Fetched | Covers | What signing permits | What we must do in return |
|---|---|---|---|---|---:|---|---|---|---|
| 1 | `fish-audio-research-license-2026-03-07` | Fish Audio S2-Pro (`fishaudio/s2-pro`) | https://huggingface.co/fishaudio/s2-pro/raw/main/LICENSE.md | `aa7d9206e9d710590987a3636934f643529c00cd490323594e6206aaa0c32d80` | 10360 | 2026-11-16 | `project:demon_attack` | Running S2-Pro in the host studio for a Research or Non-Commercial Purpose ("personal use (i.e., hobbyist)") and shipping the audio it renders: "You own any outputs generated from the Models", and outputs are not Derivative Works. No commercial use of the model; no use of the model or its outputs to build or improve a foundation model. | Display "Built with Fish Audio" (credits, generated by `tools/generate_credits.lua`). If we ever distribute the model or a derivative: a copy of the agreement and a Notice file. Use, including outputs, complies with applicable law. |
| 2 | `boson-higgs-audio-2-community` | Higgs Audio v2 (`bosonai/higgs-audio-v2-generation-3B-base` and its audio tokenizer) | https://huggingface.co/bosonai/higgs-audio-v2-generation-3B-base/raw/main/LICENSE | `8b2e018eeb3967a4636ccc57528440b33c14dd6e02ad67571fc7759489dde9a0` | 9172 | 2026-11-16 | `project:demon_attack` | A royalty-free licence to use the Higgs Materials, including commercially, while the products using them have at most 100,000 annual active users. Outputs are not restricted except: no use of them to improve any other large language model. | Display the credit line (below). If we distribute the materials or "a product or service that uses any of them": a copy of this agreement and of the Llama 3 agreement. It incorporates the Llama 3 terms (row 3). |
| 3 | `meta-llama-3-community` (with its Acceptable Use Policy) | Bundled with Higgs Audio v2 ("based upon the Meta Llama 3 Community License Agreement as of April 18, 2024 … incorporated herein by reference") | https://raw.githubusercontent.com/meta-llama/llama3/main/LICENSE and https://raw.githubusercontent.com/meta-llama/llama3/main/USE_POLICY.md (the Higgs text names https://llama.meta.com/llama3/license/) | LICENSE `4fa551d4f938f68b8c1e6afa9d28befb70e3f33f75d0753248d530364aeea40f`; USE_POLICY `716a6b46e9bc75220c7b78f27382f7d0b8ca4c95818661a0936c081708f87f7c` | 12403; 4771 | 2026-11-16 | `project:demon_attack` | Using Llama-3-derived materials (Higgs v2) under Meta's terms: free below 700 million monthly active users, subject to the Acceptable Use Policy. | Attribution "Meta Llama 3 is licensed under the Meta Llama 3 Community License, Copyright © Meta Platforms, Inc. All Rights Reserved." in a Notice file if we distribute Llama materials; follow the Acceptable Use Policy (no prohibited uses). |

**Credit lines, as written in the texts.**
- Fish Audio: "Built with Fish Audio".
- Higgs Audio v2 (§1(b)(i) of row 2): "Built with Higgs Materials licensed from Boson AI USA, Inc., Copyright Boson AI USA,
  Inc., All Rights Reserved and Meta Llama 3 licensed under the Meta Llama 3 Community License, Copyright Meta
  Platforms, Inc., All Right Reserved". The text then continues `". based on Meta Llama 3”` with unbalanced quotes,
  so where the quoted line ends is ambiguous. The credits use the part inside the first pair of quotes; the operator
  may prefer to append "based on Meta Llama 3" as well.

**Points the operator may want to note when signing** (the text is the authority, not this summary):
- Fish's "Commercial Purpose" includes "creating, modifying, or distributing Your product or service". The operator
  has decided that a free, unsold, open-source game made as a hobby is a Non-Commercial Purpose. The signature records
  that decision, and `use: non-sale` (as in the Demucs record) matches it.
- The game ships only rendered audio, never weights. The "provide a copy of this agreement" duties in rows 2 and 3
  trigger when we "distribute or make available the Higgs Materials … or a product or service that uses any of
  them". Copying the three texts into `licences/` costs nothing and covers the reading where the game counts as such
  a product.
- None of the three restricts what third parties may do with the audio, so the clips can sit in the GPL-3.0 repo
  (research §10.1).

## No signature needed (for completeness)

| Licence | Model(s) | Canonical URL of the text | sha256 as fetched | Bytes | Fetched | Notes |
|---|---|---|---|---:|---|---|
| Apache-2.0 | VoxCPM2 (OpenBMB) | https://raw.githubusercontent.com/OpenBMB/VoxCPM/main/LICENSE | `4f10acc209addacfad28293315c74c4cd648f771ee1263a748f1781d1e0265e4` | 11298 | 2026-11-16 | Card: "Weights and code released under the Apache-2.0 license, free for commercial use" |
| Apache-2.0 | Dia 1.6B (Nari Labs) | https://raw.githubusercontent.com/nari-labs/dia/main/LICENSE | `34c1659a3495220f85dffebd4d3a930bcbfd9f216f8a3c5f880a1d4a59a5358d` | 11338 | 2026-11-16 | The card adds use rules (no imitating real people, no deception); we clone only our own synthetic voices |
| Apache-2.0 | Qwen3-TTS (optional fallback) | https://raw.githubusercontent.com/QwenLM/Qwen3-TTS/main/LICENSE | `a44a6081c73ad75f0255bb2bb5cab74ef1829565a895a24e53a4f11290ab7655` | 11343 | 2026-11-16 | |
| Apache-2.0 | Kokoro-82M (identity reference clips, shipped bank) | https://huggingface.co/hexgrad/Kokoro-82M/raw/main/README.md (licence in the card front matter; the repo has no LICENSE file) | `91dcabced89db6f109b8786642f50402d3ee87450e8189589b6f85520e7f4d78` | 6348 | 2026-11-16 | Hash is of the card, not a licence text |
| MIT | RVC (optional timbre lock) | not fetched for this list | — | — | — | Fetch and pin if RVC is ever admitted |

The three Apache-2.0 LICENSE files hash differently, but compared word by word their terms (up to "END OF TERMS AND
CONDITIONS") are identical; only whitespace and the appendix differ.

Not listed: Chatterbox (dropped; the shipped 2026-11-12 bank still credits it under MIT), IndexTTS-2.5 (out), and
the models judged "No" in research §10.2.
