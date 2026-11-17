# Licences, round 2 (2026-11-17)

The operator asked, verbatim: "Which additional licenses do we need? See if they're friendly with our free open source
game, and create pull requests for me to accept them, those sound reasonable for our project, and we'll add them to
our credits page".

This file answers that question. It lists every licence that the planned pipelines need and that `main` has not
accepted yet: the voice stack, the music stack (ACE-Step and the #1103 extras), the CC0 sample libraries, and the image
models the committed workflows load. It also covers the second round of sample pins that fill the score's coverage
gaps (§5). It records what the texts say. It is not legal advice, and it approves nothing: the operator signs on the
host. Round 1 is `plan/licences-to-sign.md`.

**Already accepted on `main`** (PRs #4–#7, `licences/acknowledgements/`): Fish Audio Research License (S2-Pro), Boson
Higgs Audio 2 Community, Meta Llama 3 Community and its Acceptable Use Policy (bundled with Higgs), and the Demucs
weights (`demucs-weights-unstated`, use `non-sale`, expires 2027-11-14). They are not repeated here.

**Coordinator format (2026-11-17), followed throughout:**
- PRs keep the shape of #4–#7, one PR per licence text, and each acknowledgement record is named
  `<licence-id>--<artefact-slug>.yaml`.
- Every licence lists its pinned sha256.
- Anything gated or research-only is OUT, because nobody clicks through.
- CC0 needs no signature and no PR. Its register rows are coordinator bookkeeping, so CC0 gets a credits line and its
  pins only.
- Pins name a commit, never a branch or a moving tag.

**Method.**
- Each text was fetched raw through the forge proxy on 2026-11-17, at a commit (GitHub
  `raw.githubusercontent.com/<repo>/<commit>/…`) or a revision (Hugging Face `huggingface.co/<repo>/raw/<rev>/…`).
- Each was hashed with `sha256sum` over the exact bytes received. Revisions come from the Hugging Face model API
  (`/api/models/<repo>`, field `sha`), and GitHub commits from `git ls-remote`.
- When a Hugging Face repo has no licence file, its evidence is the model card (`README.md`) at the revision. The card's
  front matter carries the licence tag, and the hash given is the card's.
- No weights and no sample audio were downloaded. The only files fetched whole were licence files, readmes, model
  cards and SFZ maps, each under 100 KB.

## 1. Summary

Verdicts:
- **OSI** means an OSI-approved permissive licence (Apache-2.0, MIT).
- **CC0** is a public-domain dedication.
- **Use-restricted** means an OpenRAIL licence: its use-based restrictions bind us and pass downstream.
- **OUT** means gated, non-commercial or research-only, or unreadable through the proxy.

Unblock steps:
- **Register row:** the coordinator adds the pin to the Tillandsias open register, and the credits line goes in.
- **Signed PR:** the coordinator opens the licence PR of §4; the operator signs the acknowledgement on the host, and the
  merge admits the model.
- **Nothing:** already accepted, or out.

| # | Licence (SPDX) | Covers | Verdict for a free, open-source, non-commercial game | Signed acceptance? | Credits line | Unblock step |
|---|---|---|---|---|---|---|
| 1 | CreativeML Open RAIL++-M, 2023-07-26 (no SPDX id; HF `openrail++`) | `stabilityai/stable-diffusion-xl-base-1.0` | Use-restricted: friendly. Commercial use is allowed too; Attachment A forbids harmful uses that a game never needs | **Yes** | "SDXL Base 1.0 / Stability AI · CreativeML Open RAIL++-M" | Signed PR 1 |
| 2 | CreativeML Open RAIL++-M, 2023-07-26, ByteDance copy (no SPDX id) | `ByteDance/SDXL-Lightning` | Use-restricted: friendly. Same terms as row 1; the text adds one copyright line, so its bytes differ | **Yes** | "SDXL-Lightning / ByteDance · CreativeML Open RAIL++-M" | Signed PR 2 |
| 3 | CreativeML Open RAIL-M, 2022-08-22 (no SPDX id; HF `creativeml-openrail-m`) | `nerijs/pixel-art-xl`, `LayerDiffusion/layerdiffusion-v1` | Use-restricted: friendly. Neither repo ships the text, so the canonical CompVis text is pinned | **Yes** | "Pixel Art XL / nerijs · CreativeML Open RAIL-M"; "LayerDiffuse / lllyasviel · CreativeML Open RAIL-M (weights), Apache-2.0 (code)" | Signed PR 3 |
| 4 | Apache-2.0 (`Apache-2.0`) | VoxCPM2 (code + weights), Dia 1.6B-0626 (code + weights), `bosonai/hubert_base`, Qwen3-TTS (optional), Kokoro-82M | OSI: friendly | No (see §2.2 on the cards' conduct notes) | "VoxCPM2 / OpenBMB · Apache-2.0", "Dia 1.6B / Nari Labs · Apache-2.0", "HuBERT base / Boson AI · Apache-2.0" (VoxCPM2, Dia and Kokoro are already credited) | Register row |
| 5 | MIT (`MIT`) | Descript Audio Codec 44 kHz (Dia's codec), whisper.cpp code, Whisper weights (ggml conversion) | OSI: friendly | No | "Descript Audio Codec / Descript · MIT", "whisper.cpp / ggml authors · MIT", "Whisper / OpenAI · MIT" | Register row |
| 6 | MIT (`MIT`) | ACE-Step 1.5 code; XL turbo, XL base and **XL SFT** weights; its Qwen text encoders and VAE (`ACE-Step/Ace-Step1.5`) | OSI: friendly | No | "ACE-Step 1.5 XL / ACE-Step · MIT". **Fix:** the credits say Apache-2.0 today; the upstream card says MIT (design N4) | Register row; correct the credits licence |
| 7 | Apache-2.0 / MIT | #1103 extras and routes B/C (design N10): basic-pitch (Apache-2.0), ONNX Runtime (MIT), Anticipatory Music Transformer `music-large-800k` and its code (Apache-2.0) | OSI: friendly | No | "basic-pitch / Spotify · Apache-2.0", "ONNX Runtime / Microsoft · MIT", "Anticipatory Music Transformer / Stanford CRFM · Apache-2.0", each only once used | Register row when used. Clef-0.2B was not found under that name, so it is not pinned |
| 8 | Apache-2.0 / MIT | The image models in use: Qwen-Image-Edit-2511, its Lightning LoRA, Qwen2.5-VL-7B (text encoder), Wan2.2-VACE-Fun-A14B, Wan2.2-Lightning, umt5-xxl, IP-Adapter, ControlNet Union SDXL, OpenCLIP ViT-H/14 (MIT), BiRefNet (MIT) | OSI: friendly | No (see §2.2 on the Wan cards) | One line each (§6) | Register row |
| 9 | CC0-1.0 (`CC0-1.0`) | VSCO 2 CE, VCSL, Karoryfer Big Rusty Drums, Growlybass, Black And Green Guitars (the round-1 pins, plus the round-2 pins of §5) | CC0: friendly | No | The `credit` of each source in `art/music/bank/recipe.json`, e.g. "VSCO 2 Community Edition by Versilian Studios / Sam Gossner (CC0 1.0)" | Coordinator bookkeeping only (no PR) |
| 10 | Fish Audio Research License; Boson Higgs Audio 2 Community; Meta Llama 3 Community and its AUP; Demucs | S2-Pro, Higgs v2, its tokenizer | Accepted on `main` | Done | Already in the credits | Nothing |
| 11 | FLUX.1 [dev] Non-Commercial (gated); Stability AI Community (SD 3.5, gated); FLUX.1-schnell (Apache-2.0 but gated: `auto`); CC-BY-NC-4.0 (Depth-Anything-V2 Base/Large); FLUX Non-Commercial (FLUX.2-klein-9B) | — | **OUT** | — | — | Nothing. None is in a committed workflow |
| 12 | CC Sampling Plus 1.0 | Sonatina Symphonic Orchestra | **OUT** (the operator's rule) | — | — | Nothing |
| 13 | unread | Virtual Playing Orchestra, Philharmonia samples, FreePats | **OUT** until read: the forge proxy resets these sites | — | — | Nothing; not needed (§5) |

**In short:** three signed PRs (rows 1–3, all OpenRAIL, all friendly). Everything else needs either a register row and a
credits line, or nothing. No new licence is research-only. The sample gaps close entirely from libraries whose CC0
licence files are already pinned, so round 2 brings **no new sample licence**.

## 2. The texts

### 2.1 Use-restricted: signed acceptance (PRs 1–3)

| Licence id (proposed) | Text URL (pinned) | sha256 | Bytes |
|---|---|---|---:|
| `creativeml-openrail-plus-plus-m-sdxl` | https://huggingface.co/stabilityai/stable-diffusion-xl-base-1.0/raw/462165984030d82259a11f4367a4eed129e94a7b/LICENSE.md | `19b6998b569b53ac1fc2158a8a3202c8699a9a4605b47075715d9c96be7fb6d0` | 14,109 |
| `creativeml-openrail-plus-plus-m-sdxl-lightning` | https://huggingface.co/ByteDance/SDXL-Lightning/raw/c9a24f48e1c025556787b0c58dd67a091ece2e44/LICENSE.md | `58a5efadd5103ca0906bfc86817ad2d02ebd0856a79e5034756cadd02fa97066` | 14,143 |
| `creativeml-openrail-m` | https://raw.githubusercontent.com/CompVis/stable-diffusion/21f890f9da3cfbeaba8e2ac3c425ee9e998d5229/LICENSE | `be351ebe7ac01bcdbb018639aadcfd38f136b7dc3f2a3d4d3a24db51d1b210ef` | 14,385 |

The SDXL-Lightning text is the SDXL text with one extra first line, "Copyright (c) 2024 Bytedance Inc." (`diff`). That
is why its line numbers below are one higher. Neither `nerijs/pixel-art-xl` (rev `8bf4a4d9…`) nor
`LayerDiffusion/layerdiffusion-v1` (rev `e337e9d7…`) has a licence file. Their cards carry only `license:
creativeml-openrail-m` (pixel-art-xl card line 2; the LayerDiffusion card is 70 bytes: front matter and "model card
under construction"). So the pinned text is the canonical CreativeML Open RAIL-M from CompVis, whose own first line is
"Copyright (c) 2022 Robin Rombach and Patrick Esser and contributors".

Clauses that matter. Line numbers are given as SDXL / SDXL-Lightning / Open RAIL-M; the three wordings agree.

- **Use-based restrictions** (33 / 34 / 50): "Use-based restrictions. The restrictions set forth in Attachment A are
  considered Use-based restrictions. Therefore You cannot use the Model and the Derivatives of the Model for the
  specified restricted uses. You may use the Model subject to this License, including only for lawful purposes and in
  accordance with the License." The same paragraph says: "You shall require all of Your users who use the Model or a
  Derivative of the Model to comply with the terms of this paragraph (paragraph 5)."
- **Outputs** (34 / 35 / 51): "The Output You Generate. Except as set forth herein, Licensor claims no rights in the
  Output You generate using the Model. You are accountable for the Output you generate and its subsequent uses. No
  use of the output can contravene any provision as stated in the License."
- **Redistribution** (32 / 33 / 44–49): use-based restrictions "MUST be included as an enforceable provision by You in
  any type of legal agreement … governing the use and/or distribution of the Model or Derivatives of the Model", and
  "You must give any Third Party recipients of the Model or Derivatives of the Model a copy of this License". This
  binds only if we distribute the weights, which we never do.
- **Remote restriction** (37 / 38 / 55): "Licensor reserves the right to restrict (remotely or otherwise) usage of
  the Model in violation of this License". The Open RAIL-M version adds "update the Model through electronic means,
  or modify the Output of the Model based on updates. You shall undertake reasonable efforts to use the latest version
  of the Model."
- **Attachment A** (46–59 / 47–60 / 67–82): "You agree not to use the Model or Derivatives of the Model:" in breach of
  the law; to harm minors; to spread "verifiably false information … with the purpose of harming others"; to spread
  personal information that can harm; "To defame, disparage or otherwise harass others"; for fully automated
  decisions that harm legal rights; for discrimination; to exploit vulnerable groups; for medical advice; or for
  justice, law-enforcement, immigration or asylum uses.
- **Grant** (SDXL line 29): "a perpetual, worldwide, non-exclusive, no-charge, royalty-free, irrevocable copyright
  license". There is no non-commercial clause, so the game qualifies whether or not it is sold.

**Why friendly:** game art of fictional demons and ships touches none of Attachment A. The outputs are ours ("claims no
rights in the Output"), and the weights never leave the host studio. The only standing duty is not to use the
models, or their outputs, for the listed uses. The operator's standing approval of 2026-11-01
(`plan/asset-pipeline/licence-review.md`: "we'll not be selling any of those assets") already admitted these
licence ids. These PRs turn that approval into signed records under the current rule (use restrictions need a
signature).

### 2.2 Permissive: register row and credits line

| Artefact | Pin | Licence evidence (pinned) | sha256 of the evidence | Clause |
|---|---|---|---|---|
| VoxCPM2 weights | `openbmb/VoxCPM2` @ `7936080b41163874f38610f46f438e2c0757f9fd` | card README.md (7,903 B), line 33 `license: apache-2.0` | `feb850b390aa5051b81cbdc73b048361273552f003dd386b4da9c39ec9b6f055` | Line 226: "Released under the [Apache-2.0] license, free for commercial use." |
| VoxCPM code | `OpenBMB/VoxCPM` @ `300e4260b509066151d623dc9c0aa922cf82232b` | LICENSE (11,298 B) | `4f10acc209addacfad28293315c74c4cd648f771ee1263a748f1781d1e0265e4` (= round 1) | Apache-2.0 §2 line 66 grant; §4 line 89 (redistribution only) |
| Dia 1.6B-0626 weights | `nari-labs/Dia-1.6B-0626` @ `ef2795fcc29c5abe6ffc91fd33808588b49bbc66` | card README.md (8,545 B), line 2 `license: apache-2.0` | `f32e9386e5896961ac54bb7358d41737c13f0bc7025ab084a64923a1620e7707` | Line 160: "This project is licensed under the Apache License 2.0" |
| Dia code | `nari-labs/dia` @ `876125e461a03b157ec905b0fe8b57a0f8b9e7a0` | LICENSE (11,338 B) | `34c1659a3495220f85dffebd4d3a930bcbfd9f216f8a3c5f880a1d4a59a5358d` (= round 1) | Apache-2.0 §2 line 66 |
| Descript Audio Codec | `descriptinc/descript-audio-codec` tag `0.0.1` = commit `a436c61015ee2c8dd92a2ed121cf15e13fe38789` (lightweight tag) | LICENSE (1,074 B) | `5d7a5f644313f30aad5ef032669ada67efdacefecb2c7d7b875683698bd70e87` (identical at `main` = `c7cfc5d2…`) | MIT line 12: notice "shall be included in all copies or substantial portions of the Software". README at `c7cfc5d2647e26471dc394f95846a0830e7bec34` line 34: "Weights are released as part of this repo under MIT license." (The 0.0.1 README does not say so.) The `weights.pth` sha256 is still the coordinator's host step (`plan/model-pins-voice.md`) |
| HuBERT base (Higgs tokenizer's semantic model) | `bosonai/hubert_base` @ `d7a7039bd0d93005f6532853db1934722d9a5e02` | card README.md (1,753 B), line 2 `license: apache-2.0` | `1e2f8edc8fb708e53ddb788460831cefa5660cf3e65ff2fe961e659b4a608dfb` | Lines 55–57: "## License / Apache 2.0." |
| whisper.cpp code | `ggml-org/whisper.cpp` @ `d1be6fde11ac6e0407606b4e42fe72d34add8037` (v1.9.5) | LICENSE (1,078 B) | `94f29bbed6a22c35b992c5c6ebf0e7c92f13b836b90f36f461c9cf2f0f1d010d` | MIT line 12 |
| Whisper ggml weights | `ggerganov/whisper.cpp` @ `5359861c739e955e79d9a303bcbc70fb988958b1` | card README.md (3,196 B), line 2 `license: mit`; line 6: "OpenAI's Whisper models converted to ggml format" | `21fd967098804f33fc84e803fb0e5ab7666d71801f4027cf28a65e7af09c1758` | Upstream weights: `openai/whisper` @ `86098128c0b4f24f0e2aa2994de830614b474227` LICENSE (1,063 B) sha256 `b5d65a59060e68c4ff940e1eddfa6f94b2d68fdf58ed7f4dd57721c997e35e9d`, MIT line 12 |
| Qwen3-TTS (optional) | `Qwen/Qwen3-TTS-12Hz-1.7B-Base` @ `fd4b254389122332181a7c3db7f27e918eec64e3`; code `QwenLM/Qwen3-TTS` @ `022e286b98fbec7e1e916cb940cdf532cd9f488e` | card (57,817 B) line 2 `license: apache-2.0`; code LICENSE (11,343 B) | card `621b7e88f1867bc03d817176fc1f7f55f4b5a70654b2a07fdcda1e169efb024b`; LICENSE `a44a6081c73ad75f0255bb2bb5cab74ef1829565a895a24e53a4f11290ab7655` (= round 1) | Apache-2.0 §2 line 66 |
| Kokoro-82M (shipped bank) | `hexgrad/Kokoro-82M` @ `f3ff3571791e39611d31c381e3a41a3af07b4987` | card (6,348 B) line 2 `license: apache-2.0` | `91dcabced89db6f109b8786642f50402d3ee87450e8189589b6f85520e7f4d78` (= round 1) | — |
| ACE-Step 1.5 code | `ace-step/ACE-Step-1.5` @ `ca1e85fe9430179831e6bc6be790c332190a3866` | LICENSE (1,064 B), "Copyright (c) 2026 ACEStep" | `05a6bce42a62636d2cfb24139cc008b6b899754e244175814bb5dd2f4a485357` | MIT line 12 |
| ACE-Step XL SFT (#1103's "highest quality") | `ACE-Step/acestep-v15-xl-sft` @ `d06de46b4622f781cf07f4a013a67d591ca52819` | card (4,113 B) line 3 `license: mit` | `6cfd536f953f5171283d84baf223c68d88979d8215cac9209324d04c331988e2` | Line 54: "Safe Training Data: Licensed music, royalty-free/public domain, and synthetic (MIDI-to-Audio) data." |
| ACE-Step XL turbo (in use) | `ACE-Step/acestep-v15-xl-turbo` @ `d4a0b288b83ebb7e25a8c0b32c573c22e134e8ee` | card (4,106 B) line 3 `license: mit` | `9cd512227aa80bc7572d09c318d5e3acc584bad1a7b5230ea03fa07220dbb6db` | — |
| ACE-Step XL base (in use) | `ACE-Step/acestep-v15-xl-base` @ `220c1166efbdd9583eafcb12eb160594bbfcb241` | card (4,749 B) line 3 `license: mit` | `94ca4537e3b65fd9761e8e97ad07556c4a87c19176104dfeccb5fbe6ca0d6212` | — |
| ACE-Step text encoders and VAE (`qwen_0.6b_ace15`, `qwen_4b_ace15`, `ace_1.5_vae`) | `ACE-Step/Ace-Step1.5` @ `19671f406d603126926c1b7e2adc169acbcade22` | card (5,496 B) line 3 `license: mit`, line 48 "**License:** [MIT]" | `69d69b89e313706b93b420b13aa6232259b207a1cd19b0b70358d166e8e451a0` | The studio loads the Comfy-Org repack (listed as apache-2.0, design N4); the register should name MIT upstream |
| basic-pitch (route B) | `spotify/basic-pitch` @ `fa5997af0a8210982619003269994a1be25eddf3` | LICENSE (11,384 B) | `929c910bae2152fa87199a5d0660e09263419b7eee6d4b301d05ee2aaf211c37` | Apache-2.0 §2 line 68 |
| ONNX Runtime (route B) | `microsoft/onnxruntime` @ `63163cb01727a5ed0c954f970f942848e860e682` | LICENSE (1,073 B) | `2f07c72751aed99790b8a4869cf2311df85a860b22ded05fa22803587a48922c` | MIT line 12 |
| Anticipatory Music Transformer (route C) | `stanford-crfm/music-large-800k` @ `e206a88d4658661c2757573eae724d5b27213824`; code `jthickstun/anticipation` @ `af37397922665a0fb8d474d7988b0f3755a38d45` | card (1,054 B) line 2 `license: apache-2.0`; LICENSE.txt (11,348 B) | card `276146c810dc229fcac8cb23a32ae5038f4ced41f3d958237cf62715447b8bc8`; LICENSE.txt `eabd943e7fbb07420f3c63c87a3ffe0e350db4630df026c98af48be6ba76b7ad` | Card line 5: trained on Lakh MIDI, MetaMIDI, FMA transcripts "and 450k commercial music records". The weights' licence is Apache-2.0; the training data's provenance is the operator's call (route C is not started) |
| Qwen-Image-Edit-2511 | `Qwen/Qwen-Image-Edit-2511` @ `6f3ccc0b56e431dc6a0c2b2039706d7d26f22cb9` | card (7,179 B) line 2 `license: apache-2.0` | `9724c194bef2a6d821090f0cd65774962e8f77e3acbfb2a7cbbdd58c92049902` | — |
| Qwen-Image-Edit-2511 Lightning | `lightx2v/Qwen-Image-Edit-2511-Lightning` @ `107d238d68b8387e32843d0b4a2e24ceb0d3ad86` | card (2,679 B) line 2 `license: apache-2.0` | `737dfc674ee93902370a07722a4a06bae49a0a9c1ab579d3f7f9129210600b86` | — |
| Qwen2.5-VL-7B (Qwen-Image's text encoder) | `Qwen/Qwen2.5-VL-7B-Instruct` @ `cc594898137f460bfe9f0759e9844b3ce807cfb5` | card (18,574 B) line 3 `license: apache-2.0` | `1fa65dbb08bc9ffe0b020409c8686f08b23008c5a68554353305fd2de6f2b81e` | — |
| Wan2.2-VACE-Fun-A14B | `alibaba-pai/Wan2.2-VACE-Fun-A14B` @ `4438caabbfdd7437bbb0283d86cb200d1b7223ba` | card (18,813 B) line 2 `license: apache-2.0` | `b2c3a0426342044fb091dd02573ebc69a832bb159b0f306ba738b1f174b70142` | Line 405 (Chinese section): "本项目采用 [Apache License (Version 2.0)]" ("this project uses Apache License 2.0") |
| Wan2.2-Lightning LoRA | `lightx2v/Wan2.2-Lightning` @ `18bccf8884ec0a078eed79785eb4ef13ea16ce1e` | card (19,309 B) line 3 `license: apache-2.0` | `64b4ea3438f4712e9a58c31e1cde57bb5a0bf6dee825d7a4ef63f75dbb78303c` | Line 328, quoted below |
| umt5-xxl (Wan's text encoder) | `google/umt5-xxl` @ `66cb9e7e85526fe440a945569e42c72fb6cbc0ad` | card (3,348 B) line 108 `license: apache-2.0` | `5a3d9571271acaf4e83b1a7acdd1e7e1c11dfcfb8e5ff5c28e27c804d4c62429` | — |
| IP-Adapter (SDXL plus, ViT-H) | `h94/IP-Adapter` @ `018e402774aeeddd60609b4ecdb7e298259dc729` | card (3,091 B) line 5 `license: apache-2.0` | `ba3a50dc2093d0eb075890e9af7409382874669d83939e64323246d0c4403cf8` | — |
| OpenCLIP ViT-H/14 (IP-Adapter's image encoder) | `laion/CLIP-ViT-H-14-laion2B-s32B-b79K` @ `1c2b8495b28150b8a4922ee1c8edee224c284c0c` | card (8,209 B) line 2 `license: mit` | `14db420f00ddf78a07194dc4cdc57977d979e0f2c34994137679046defdf6577` | — |
| ControlNet Union SDXL (promax) | `xinsir/controlnet-union-sdxl-1.0` @ `801a4a3fa3d4c936f4feea95b98607bc6726f80c` | card (9,857 B) line 2 `license: apache-2.0` | `263366a14c599f908e4b9a4cad4521f679b1af1d68369872de0a9476ff6e0137` | It conditions SDXL, whose OpenRAIL terms (PR 1) apply to the pair |
| BiRefNet | `ZhengPeng7/BiRefNet` @ `e2bf8e4460fc8fa32bba5ea4d94b3233d367b0e4`; code @ `f7079632d681ecf12161fcea8905682934e59e51` | card (9,965 B) line 14 `license: mit`; code LICENSE (1,066 B) | card `ceac4a1bb69b807eac5510bff80ff5599f606ef7458bee3b54b68d866e868532`; LICENSE `92a7089e0915fc32bc40067560b398f1e6a7a5958abd7d04eda393629a5acefb` | MIT line 12 |
| LayerDiffuse code | `lllyasviel/LayerDiffuse` @ `a7221c06a7016646e04661f394927f5b46171748` | LICENSE (11,357 B) | `c71d239df91726fc519c6eb72d318ec65820627232b2f796219e87dcf35d0ab4` | Apache-2.0; the weights are row 3 (Open RAIL-M) |

**Card conduct notes: not licence terms, but the operator should know them.** Three permissive cards add a "forbidden"
list outside the licence text:
- Dia card lines 164–170: "This project offers a high-fidelity speech generation model intended for research and
  educational use. The following uses are **strictly forbidden**: … **Identity Misuse**: Do not produce audio
  resembling real individuals without permission. … **Deceptive Content** … **Illegal or Malicious Use** … By using
  this model, you agree to uphold relevant legal standards and ethical responsibilities."
- VoxCPM2 card line 202: "**Strictly forbidden** to use for impersonation, fraud, or disinformation. AI-generated
  content should be clearly labeled."
- Wan2.2-Lightning card line 328: "You are fully accountable for your use of the models, which must not involve sharing
  any content that violates applicable laws, causes harm to individuals or groups, disseminates personal information
  intended for harm, spreads misinformation, or targets vulnerable populations."

**Reading (the lead's, not legal advice):** the governing licence of each is Apache-2.0, which these notes do not
amend. Dia's "intended for research and educational use" describes the release; it is not a grant limited to research
(the card's line 160 and the LICENSE grant Apache-2.0). The game already complies:
- it clones only its own synthetic voices (`plan/licences-to-sign.md`, Dia row);
- its radio voices are credited as generated in the credits;
- it makes no content of real people.

So no signed PR is proposed for these. If the operator wants Dia's "you agree" on record, a fourth PR in the §4 shape
can be prepared from the card text at the pin.

### 2.3 OUT

| Artefact | Evidence (read 2026-11-17) | Why OUT |
|---|---|---|
| FLUX.1-dev | HF API `black-forest-labs/FLUX.1-dev` @ `3de623fc…`: `license: other`, `license_name: flux-1-dev-non-commercial-license`, `gated: auto` | Gated, non-commercial |
| Stable Diffusion 3.5 Large | HF API @ `ceddf0a7…`: `license_name: stabilityai-ai-community`, `gated: auto` | Gated |
| FLUX.1-schnell | HF API @ `741f7c3c…`: `apache-2.0`, `gated: auto` | Gated (the coordinator's rule), although the licence itself is Apache-2.0 |
| Depth-Anything-V2 Large (and Base) | HF API @ `cbbb86a3…`: `cc-by-nc-4.0` | Non-commercial |
| FLUX.2-klein-9B | round-1 review: `flux-non-commercial-license`, gated | Non-commercial, gated |
| IndexTTS-2 | HF API @ `740dcaff…`: no licence tag | Out by the operator's decision (round 1); no tag to assess |
| Sonatina Symphonic Orchestra | `peastman/sso` @ `32bbdb169aef636b8216029a2e056424ba7c2abb`, LICENSE (200 B, sha256 `30fc40ccc5a8a1e32e7220519b185c9a46d2c5094ff15bde64556fb7021d73b3`), lines 1–3: "Sonatina Symphonic Orchestra is a free library. It may be used and distributed under the terms of the Creative Commons Sampling Plus 1.0 license" | CC Sampling Plus is not acceptable. Its README (blob `4bb781b8…`) also quotes the author: "In the case of a few very old soundfonts I have no idea who the original authors were or what licensing might apply." |
| Virtual Playing Orchestra, Philharmonia samples, FreePats | `virtualplaying.com`, `philharmonia.co.uk/resources/sound-samples/` and `freepats.zenvoid.org` all reset the connection through the forge proxy | Unread, so unassessed. Not routed around (CLAUDE.md §8). Not needed: §5 closes every gap |

The lightx2v Wan card (line 335) mentions Movie Gen Bench prompts under CC BY-NC 4.0. Those prompts were used for the
publisher's evaluation; we neither use nor ship them, so the LoRA's Apache-2.0 grant is unaffected.

## 3. Credits

`tools/generate_credits.lua` builds the credits page. After the PRs merge, its `models` table should hold one line per
model actually used. The lines below are in the table's form, name then licence. This file does not edit the
generator, because the credits change belongs with the merge of the licences.

| Add or change | Name | Licence |
|---|---|---|
| change | ACE-Step 1.5 XL / ACE-Step | **MIT** (now Apache-2.0) |
| keep | SDXL Base 1.0 / Stability AI | CreativeML Open RAIL++-M |
| keep | SDXL-Lightning / ByteDance | CreativeML Open RAIL++-M |
| keep | Pixel Art XL / nerijs | CreativeML Open RAIL-M |
| add | LayerDiffuse / lllyasviel | CreativeML Open RAIL-M (weights); Apache-2.0 (code) |
| add | Wan2.2 VACE Fun / Alibaba PAI | Apache-2.0 |
| add | Wan2.2-Lightning / lightx2v | Apache-2.0 |
| add | UMT5-XXL / Google | Apache-2.0 |
| add | IP-Adapter / h94 | Apache-2.0 |
| add | OpenCLIP ViT-H/14 / LAION | MIT |
| add | ControlNet Union SDXL / xinsir | Apache-2.0 |
| add | BiRefNet / ZhengPeng7 | MIT |
| add | Qwen2.5-VL / Qwen | Apache-2.0 |
| add, when the voice stack ships | Descript Audio Codec / Descript; whisper.cpp / ggml authors; Whisper / OpenAI; HuBERT base / Boson AI | MIT; MIT; MIT; Apache-2.0 |
| add, when the bank ships | each `sources[*].credit` of `art/music/bank/recipe.json` (design §12.9.6 step 4) | CC0 1.0 |

## 4. PRs for the coordinator

Three PRs, one per licence text, in the shape of #4–#7. Each PR carries:
- the licence text (`licences/texts/<id>.md`, byte-identical to the pinned URL);
- its spec (`openspec/specs/third-party-licence-<id>/spec.md`, validated with `openspec validate <spec> --type spec
  --strict`);
- one acknowledgement per artefact, which the **operator signs on the host**. The forge prepares no yaml. The
  acknowledgement names below follow the coordinator's `<licence-id>--<artefact-slug>.yaml`, and their fields follow
  `licences/acknowledgements/fishaudio-s2-pro.yaml`, with `use: non-sale` and `scope: project:demon_attack`.

The text and spec files are committed on `work/licences-round-2`, so the coordinator can take them from that branch.

### PR 1: `licences/creativeml-openrail-plus-plus-m-sdxl`
- **Title:** Accept the CreativeML Open RAIL++-M licence for SDXL base 1.0
- **Body:** SDXL base 1.0 (`stabilityai/stable-diffusion-xl-base-1.0` @ `462165984030d82259a11f4367a4eed129e94a7b`) is
  the checkpoint of twelve committed image workflows (sprites, backgrounds, comms portraits and backdrops, widescreen).
  Its licence is CreativeML Open RAIL++-M (2023-07-26): royalty-free, commercial use allowed, with the use-based
  restrictions of Attachment A, which bind us and our outputs. Game art of fictional subjects touches none of them,
  and we never redistribute the weights. Text sha256 `19b6998b569b53ac1fc2158a8a3202c8699a9a4605b47075715d9c96be7fb6d0`
  (14,109 B, fetched 2026-11-17). Research: `plan/licences-round-2.md` §2.1.
- **Files:** `licences/texts/creativeml-openrail-plus-plus-m-sdxl.md`,
  `openspec/specs/third-party-licence-creativeml-openrail-plus-plus-m-sdxl/spec.md`, and (signed on the host)
  `licences/acknowledgements/creativeml-openrail-plus-plus-m-sdxl--stabilityai-stable-diffusion-xl-base-1-0.yaml`
  with `covers: [stabilityai/stable-diffusion-xl-base-1.0]`.

### PR 2: `licences/creativeml-openrail-plus-plus-m-sdxl-lightning`
- **Title:** Accept the CreativeML Open RAIL++-M licence for SDXL-Lightning
- **Body:** SDXL-Lightning (`ByteDance/SDXL-Lightning` @ `c9a24f48e1c025556787b0c58dd67a091ece2e44`) made the beach
  concept frames the credits already list. Its LICENSE.md is the SDXL Open RAIL++-M text plus the line "Copyright (c)
  2024 Bytedance Inc.", so it is a separate text with a separate hash. The terms and the reading are the same as PR 1.
  Text sha256 `58a5efadd5103ca0906bfc86817ad2d02ebd0856a79e5034756cadd02fa97066` (14,143 B, fetched 2026-11-17).
- **Files:** `licences/texts/creativeml-openrail-plus-plus-m-sdxl-lightning.md`,
  `openspec/specs/third-party-licence-creativeml-openrail-plus-plus-m-sdxl-lightning/spec.md`, and (signed on the host)
  `licences/acknowledgements/creativeml-openrail-plus-plus-m-sdxl-lightning--bytedance-sdxl-lightning.yaml` with
  `covers: [ByteDance/SDXL-Lightning]`.

### PR 3: `licences/creativeml-openrail-m`
- **Title:** Accept the CreativeML Open RAIL-M licence for Pixel Art XL and LayerDiffuse
- **Body:** Pixel Art XL (`nerijs/pixel-art-xl` @ `8bf4a4d9ea283e00a51fafda8e0539f8248ea037`), the LoRA of eleven
  committed workflows, and the LayerDiffuse weights (`LayerDiffusion/layerdiffusion-v1` @
  `e337e9d7a0f2a6fee6c3580374327380f88d065b`), which make the transparent sprites of `sprite-transparent.json`, are both
  tagged `creativeml-openrail-m`. Neither repo ships the text, so the canonical CreativeML Open RAIL-M (2022-08-22)
  from `CompVis/stable-diffusion` @ `21f890f9da3cfbeaba8e2ac3c425ee9e998d5229` is pinned. The terms are the same as
  PR 1, plus line 55's duty to make "reasonable efforts to use the latest version of the Model". Text sha256
  `be351ebe7ac01bcdbb018639aadcfd38f136b7dc3f2a3d4d3a24db51d1b210ef` (14,385 B, fetched 2026-11-17).
- **Files:** `licences/texts/creativeml-openrail-m.md`, `openspec/specs/third-party-licence-creativeml-openrail-m/spec.md`,
  and two acknowledgements, signed on the host:
  - `licences/acknowledgements/creativeml-openrail-m--nerijs-pixel-art-xl.yaml` (`covers: [nerijs/pixel-art-xl]`);
  - `licences/acknowledgements/creativeml-openrail-m--layerdiffusion-layerdiffusion-v1.yaml`
    (`covers: [LayerDiffusion/layerdiffusion-v1]`).

**No PR** for the permissive rows (§2.2, register rows only), for CC0 (§5, coordinator bookkeeping), or for OUT (§2.3).

## 5. Sample bank, round 2: filling the coverage gaps

The score gate on the score-sampler work (design §12.9.4, `lua tools/midi_stats.lua check`) reports these gaps:
- brass 63.4 % covered: the horns stop around F#4, and the fanfares sit higher;
- bells 82.1 %;
- clean guitar 76.3 %;
- organ 94.3 %.

A per-pitch count of the uncovered notes (the gate's own coverage test, one counter added; scientific pitch, C4 = 60)
gives the exact ranges to fill:

| Role | Uncovered notes | Range needed |
|---|---:|---|
| brass | 468 of 1,277 | G4–E6 (67–88) |
| bells | 70 of 392 | A#5–F#6 (82–90) |
| clean | 158 of 668 | F5–A6 (77–93) |
| organ | 128 of 2,231 | F1–F#1 (29–30, 32 notes) and A#4–A5 (70–81, 96 notes) |

**Finding: every gap closes from libraries already pinned, at the same commits, under the same CC0 licence files.**
- VSCO 2 CE at `1.1.0` = `28092772…` has a trumpet and a glockenspiel, with SFZ maps.
- VCSL at `c1ea7bc…` has the organ's upper pipes.
- Black And Green Guitars at `f3cf516…` goes up to `d7` (D6).

The licence files were fetched again at the pins on 2026-11-17 and reproduce the round-1 hashes:
- VSCO 2 CE `LICENSE`: blob `670154e3…`, sha256 `36ffd9dc085d529a7e60e1276d73ae5a030b020313e6c5408593a6ae2af39673`;
- VCSL and Karoryfer `LICENSE`: blob `0e259d42…`, sha256 `a2010f343487d3f7618affe54f789f5487602331c0a8d03f49e9a7c547cf0499`.

So no new sample licence is needed, and the sources CC0-first, CC-BY-second order never reached CC-BY.

### 5.1 The pins (12 rows appended to `plan/sample-bank-pins.manifest.tsv`)

| Source | Group | Path | Bytes | git blob sha1 | Root (map) |
|---|---|---|---:|---|---|
| `sgossner/VSCO-2-CE` @ `28092772094b2d9f1148d84cea97f4545b8c687d` | doc | `TrumpetSus.sfz` | 2,510 | `2b9be543a5179638788f8766dc1c181956975025` | sha256 `8dc5eca44087b0f0af782b3a54ee10a263520d7756f6ed497aa1e3111eea66a6` |
| ″ | doc | `Glockenspiel.sfz` | 790 | `c9b7f41492d6df5bf0534e579b7a82891771f24a` | sha256 `04fc6e8ed652d919288605139c8adf04b02da8f7101145921a2f0c2bba5f3907` |
| ″ | doc | `OrganLoud.sfz` (evidence for the organ octave, §5.3) | 2,352 | `adc6c67f31bd618d6cbe3c1c8be5db137c2482d9` | sha256 `cacb639e29eea3fe719057d44ef20d25b1542f4e20e225de9977b3e570485037` |
| ″ | trumpet-sus | `Brass/Trumpet/sus/Sum_SHTrumpet_sus_A#3_v3_rr1.wav` | 1,667,240 | `f6b2753da2ae19e4748a91b0ed412decf3973fda` | 70 (69–71) |
| ″ | trumpet-sus | `Brass/Trumpet/sus/Sum_SHTrumpet_sus_F4_v3_rr1.wav` | 1,269,372 | `cb508c5bf2e3c21dc3441194499fc6d0e7344f4b` | 77 (76–78) |
| ″ | trumpet-sus | `Brass/Trumpet/sus/Sum_SHTrumpet_sus_C5_v3_rr1.wav` | 1,339,832 | `9e43868b7c7e47a8ee107c68c6072756ef0f6bc1` | 84 (83–84) |
| ″ | glock | `Percussion/Glock/glock_medium_C6.wav` | 1,271,310 | `c02ff721d10eb3551372806653368f45ea5dc367` | 84 (82–87) |
| ″ | glock | `Percussion/Glock/glock_medium_G6.wav` | 843,122 | `e95738492bdc207b11ad32891a9a1ea090b6719e` | 91 (88–93) |
| `sgossner/VCSL` @ `c1ea7bcc3c7309650ab0da9d15c9cd1fbc4a4c7e` | organ-ext | `Aerophones/Edge-blown Aerophones/Pipe Organ/Loud/Rode_Man3Open_C5.wav` | 2,135,622 | `0acea8ad636b504e970fbe6df4c434ad24fce7f3` | name C5 = 72 |
| ″ | organ-ext | `Aerophones/Edge-blown Aerophones/Pipe Organ/Loud/Rode_Man3Open_F#5.wav` | 2,121,458 | `b945af66d23632766a9662204976a99e5234d5c4` | name F#5 = 78 |
| `sfzinstruments/karoryfer.black-and-green-guitars` @ `f3cf516cbe50b2d6019c7c8fafec4251e2fa29c9` | gtr-hi | `Samples/black/ord/twang_g6_f_rr1.wav` | 432,876 | `d65807785e86d41d48233272fe49dd62d58a6850` | 79 (`ord.sfz`, already pinned) |
| ″ | gtr-hi | `Samples/black/ord/twang_db7_f_rr1.wav` | 329,684 | `56c209071392c89ac2eca28d52cbe88b0d9bab71` | 85 |

That is 12 rows and 11,416,168 B raw. The manifest now has 196 rows, sha256
`6df0c9f2939fe10947c6a090db02efd3978ae3e426a19dbd6c8ed128d8de0cfb`.
- File sizes and blobs come from the GitHub tree API at each pin (none truncated).
- The three SFZ maps were fetched raw at the pin, and `git hash-object --no-filters` reproduces their blobs.
  `bank_build.lua --fetch-maps --sync-keys`, run into scratch, verified all 11 maps against the manifest.
- No sample audio was downloaded.

**Fallback organ pins** are not in the manifest; add them only if the f0 check of §5.3 sides with the VSCO map. They
are VCSL `…/Pipe Organ/Loud/Rode_Man3Open_C1.wav` (2,230,702 B, blob `0f3273e6fd11feafc1ac940a21a4e3758e2d44c9`) and
`…/Rode_Man3Open_F#1.wav` (2,234,062 B, blob `fca6a7ac9c081fd2ecb7eab6319bd0d4f6762877`), at the same commit.

### 5.2 Coverage and budget, measured

Measured with the score-sampler planner and gate (the local `game` commit `ea0a00b3`, not yet on `origin/game`). The
scratch recipe adds the entries of §5.4 and points at this manifest:

| Role | Before | After (desktop) | Phones | Still synth |
|---|---:|---:|---:|---|
| brass | 63.4 % | **99.9 %** | 13.6 % (unchanged) | E6 (1 note) |
| bells | 82.1 % | **100 %** | 0 % (unchanged) | — |
| clean | 76.3 % | **98.1 %** | 12.4 % (unchanged) | F#6–A6 (13 notes; above the guitar's top fret, D6) |
| organ | 94.3 % | **98.6 %** | 94.3 % (unchanged) | F1–F#1 (32 notes) |

- **Section tracks played whole from the bank:** 773 of 796, up from 653. Phones stay at 556.
- **Budgets** (`bank_build.lua --dry-run`):
  - Opus 1,633,224 B of 2,000,000 (was 1,519,392);
  - decoded on desktop 40,934,400 B of 41,000,000 (was 38,256,000), with 65,600 B of headroom;
  - decoded on phones 14,553,600 B of 16,000,000 (unchanged).
- Every new instrument is desktop-only (`phone: false`, and the guitar keeps `maxRoot` 58), which is why the phone tier
  does not change.
- Trims are 1.5 s for the trumpet, the glockenspiel and the organ extension. At 2 s the desktop goes over 41 MB.

What each source brings:
- **Trumpet** (VSCO 2 CE, 3 roots, top layer `v3`): brass G4–D#6. This is the fanfare range, 467 notes.
- **Glockenspiel** (VSCO 2 CE, 2 roots): bells A#5–F#6, 70 notes. Tubular bells stop at F5 in both libraries
  (VCSL `Tubular Bells 2` C4–F5; VSCO `TubularBells.sfz` the same files). Above that the glockenspiel is the right
  instrument anyway.
- **Black guitar, high `ord`** (2 roots): clean F5–E6, 145 notes.
- **Organ pipes C5 and F#5** (VCSL): organ A#4–A5, 96 notes.

The horn could also reach G#5: VSCO's `FHornSus.sfz` maps `MOHorn_sus_D4_v1_1.wav` (74) and `MOHorn_sus_F4_v1_1.wav`
(77), and round 1 did not pin them. The trumpet makes them unnecessary, and the decoded budget has no room for both.

### 5.3 Side finding: the organ files are named an octave apart in the two libraries

VCSL's `Pipe Organ/Loud` files are **byte-identical** to VSCO 2 CE's `Keys/Organ/Loud` files (same git blobs). For
example, VCSL `Rode_Man3Open_C2.wav` is blob `0d68a094…`, which is VSCO `Rode_Man3Open_13.wav`.
- VSCO's `OrganLoud.sfz` maps `_13` at `pitch_keycenter=48` (C3).
- The recipe reads VCSL's name `C2` as 36.

So the round-1 organ roots may sit an octave low. Design §12.9.6 already lists "the organ and bell names" as open, and
the builder's f0 check corrects a shared whole-octave offset. If the f0 check confirms the VSCO map:
- the six round-1 pipes play 48–78 (45–81 with stretch);
- the upper gap is already closed, and C5/F#5 are not needed;
- the low gap moves to F1–F2, and the fallback pins C1/F#1 fill it (98.6 % either way).

The tubular bells agree between the two libraries (`TB_hit_C4` at 60), so only the organ is in question.

### 5.4 What the merge must add (the recipe is on the score-sampler commit, not on this branch)

`tools/bank/bank.lua`'s planner refuses a manifest group that no instrument uses ("manifest group %s is in no
instrument", line 247). So the 12 rows need these recipe changes in the same squash. Without them, `midi_stats.lua
check`, `bank_build.lua` and `test:worker` fail. The changes:

```json
{"id":"gtr-sus", "groups":["gtr-sus","gtr-hi"], "...": "unchanged"}
{"id":"trumpet-sus","groups":["trumpet-sus"],"roles":["brass"],"art":"sus","parse":{"note":"_sus_(%u#?%d)_v"},"root":"map","verify":"strict","stretch":[3,3],"trim":1.5,"channels":1,"tier":2,"release":0.2,"loop":{"start":0.6,"xfade":0.3},"phone":false}
{"id":"glock","groups":["glock"],"roles":["bells"],"art":"hit","parse":{"note":"glock_medium_(%u#?%d)%.wav$"},"root":"map","verify":"report","stretch":[3,3],"trim":1.5,"channels":1,"tier":2,"phone":false}
{"id":"organ-ext","groups":["organ-ext"],"roles":["organ"],"art":"sus","parse":{"note":"_(%u#?%d)%.wav$"},"root":"name","names":"scientific","verify":"strict","stretch":[3,3],"trim":1.5,"channels":1,"tier":2,"release":0.25,"loop":{"start":0.6,"xfade":0.3},"phone":false}
```

- Append `trumpet-sus` after `tbn-sus`, and `glock` after `bells`. Instruments are tried in order.
- Add `organ-ext` after `organ`.
- Then regenerate `art/music/bank/sfz-keys.json` with `lua tools/bank/bank_build.lua --fetch-maps --sync-keys`. It is
  a generated file (CLAUDE.md §4). The new keys are additions only; the existing 8 maps' keys are unchanged.
- Run the gates.
- The trims and the trumpet's loop start are our judgement, to be tuned by ear (task 9.7).

**For the coordinator (CC0, no PR):** register these 12 rows with the round-1 pins. The repos, commits and licence
files are the same as round 1.

## 6. Sources

All read 2026-11-17 through the forge proxy, at the commit or revision named.
- [source: Stability AI, "CreativeML Open RAIL++-M License" (SDXL base 1.0 LICENSE.md), https://huggingface.co/stabilityai/stable-diffusion-xl-base-1.0/raw/462165984030d82259a11f4367a4eed129e94a7b/LICENSE.md, read 2026-11-17]
- [source: ByteDance, "CreativeML Open RAIL++-M License" (SDXL-Lightning LICENSE.md), https://huggingface.co/ByteDance/SDXL-Lightning/raw/c9a24f48e1c025556787b0c58dd67a091ece2e44/LICENSE.md, read 2026-11-17]
- [source: CompVis, "CreativeML Open RAIL-M" (stable-diffusion LICENSE), https://raw.githubusercontent.com/CompVis/stable-diffusion/21f890f9da3cfbeaba8e2ac3c425ee9e998d5229/LICENSE, read 2026-11-17]
- [source: nerijs, "pixel-art-xl README.md", https://huggingface.co/nerijs/pixel-art-xl/raw/8bf4a4d9ea283e00a51fafda8e0539f8248ea037/README.md, read 2026-11-17]
- [source: LayerDiffusion, "layerdiffusion-v1 README.md", https://huggingface.co/LayerDiffusion/layerdiffusion-v1/raw/e337e9d7a0f2a6fee6c3580374327380f88d065b/README.md, read 2026-11-17]
- [source: lllyasviel, "LayerDiffuse LICENSE", https://raw.githubusercontent.com/lllyasviel/LayerDiffuse/a7221c06a7016646e04661f394927f5b46171748/LICENSE, read 2026-11-17]
- [source: OpenBMB, "VoxCPM2 README.md", https://huggingface.co/openbmb/VoxCPM2/raw/7936080b41163874f38610f46f438e2c0757f9fd/README.md, read 2026-11-17]
- [source: OpenBMB, "VoxCPM LICENSE", https://raw.githubusercontent.com/OpenBMB/VoxCPM/300e4260b509066151d623dc9c0aa922cf82232b/LICENSE, read 2026-11-17]
- [source: Nari Labs, "Dia-1.6B-0626 README.md", https://huggingface.co/nari-labs/Dia-1.6B-0626/raw/ef2795fcc29c5abe6ffc91fd33808588b49bbc66/README.md, read 2026-11-17]
- [source: Nari Labs, "dia LICENSE", https://raw.githubusercontent.com/nari-labs/dia/876125e461a03b157ec905b0fe8b57a0f8b9e7a0/LICENSE, read 2026-11-17]
- [source: Descript, "descript-audio-codec LICENSE" at 0.0.1, https://raw.githubusercontent.com/descriptinc/descript-audio-codec/a436c61015ee2c8dd92a2ed121cf15e13fe38789/LICENSE, read 2026-11-17]
- [source: Descript, "descript-audio-codec README.md", https://raw.githubusercontent.com/descriptinc/descript-audio-codec/c7cfc5d2647e26471dc394f95846a0830e7bec34/README.md, read 2026-11-17]
- [source: Boson AI, "hubert_base README.md", https://huggingface.co/bosonai/hubert_base/raw/d7a7039bd0d93005f6532853db1934722d9a5e02/README.md, read 2026-11-17]
- [source: ggml authors, "whisper.cpp LICENSE" v1.9.5, https://raw.githubusercontent.com/ggml-org/whisper.cpp/d1be6fde11ac6e0407606b4e42fe72d34add8037/LICENSE, read 2026-11-17]
- [source: ggerganov, "whisper.cpp (models) README.md", https://huggingface.co/ggerganov/whisper.cpp/raw/5359861c739e955e79d9a303bcbc70fb988958b1/README.md, read 2026-11-17]
- [source: OpenAI, "whisper LICENSE", https://raw.githubusercontent.com/openai/whisper/86098128c0b4f24f0e2aa2994de830614b474227/LICENSE, read 2026-11-17]
- [source: Qwen, "Qwen3-TTS-12Hz-1.7B-Base README.md", https://huggingface.co/Qwen/Qwen3-TTS-12Hz-1.7B-Base/raw/fd4b254389122332181a7c3db7f27e918eec64e3/README.md, read 2026-11-17]
- [source: Qwen, "Qwen3-TTS LICENSE", https://raw.githubusercontent.com/QwenLM/Qwen3-TTS/022e286b98fbec7e1e916cb940cdf532cd9f488e/LICENSE, read 2026-11-17]
- [source: hexgrad, "Kokoro-82M README.md", https://huggingface.co/hexgrad/Kokoro-82M/raw/f3ff3571791e39611d31c381e3a41a3af07b4987/README.md, read 2026-11-17]
- [source: ACEStep, "ACE-Step-1.5 LICENSE", https://raw.githubusercontent.com/ace-step/ACE-Step-1.5/ca1e85fe9430179831e6bc6be790c332190a3866/LICENSE, read 2026-11-17]
- [source: ACE-Step, "acestep-v15-xl-sft README.md", https://huggingface.co/ACE-Step/acestep-v15-xl-sft/raw/d06de46b4622f781cf07f4a013a67d591ca52819/README.md, read 2026-11-17]
- [source: ACE-Step, "acestep-v15-xl-turbo README.md", https://huggingface.co/ACE-Step/acestep-v15-xl-turbo/raw/d4a0b288b83ebb7e25a8c0b32c573c22e134e8ee/README.md, read 2026-11-17]
- [source: ACE-Step, "acestep-v15-xl-base README.md", https://huggingface.co/ACE-Step/acestep-v15-xl-base/raw/220c1166efbdd9583eafcb12eb160594bbfcb241/README.md, read 2026-11-17]
- [source: ACE-Step, "Ace-Step1.5 README.md", https://huggingface.co/ACE-Step/Ace-Step1.5/raw/19671f406d603126926c1b7e2adc169acbcade22/README.md, read 2026-11-17]
- [source: Spotify, "basic-pitch LICENSE", https://raw.githubusercontent.com/spotify/basic-pitch/fa5997af0a8210982619003269994a1be25eddf3/LICENSE, read 2026-11-17]
- [source: Microsoft, "onnxruntime LICENSE", https://raw.githubusercontent.com/microsoft/onnxruntime/63163cb01727a5ed0c954f970f942848e860e682/LICENSE, read 2026-11-17]
- [source: Stanford CRFM, "music-large-800k README.md", https://huggingface.co/stanford-crfm/music-large-800k/raw/e206a88d4658661c2757573eae724d5b27213824/README.md, read 2026-11-17]
- [source: John Thickstun, "anticipation LICENSE.txt", https://raw.githubusercontent.com/jthickstun/anticipation/af37397922665a0fb8d474d7988b0f3755a38d45/LICENSE.txt, read 2026-11-17]
- [source: Qwen, "Qwen-Image-Edit-2511 README.md", https://huggingface.co/Qwen/Qwen-Image-Edit-2511/raw/6f3ccc0b56e431dc6a0c2b2039706d7d26f22cb9/README.md, read 2026-11-17]
- [source: lightx2v, "Qwen-Image-Edit-2511-Lightning README.md", https://huggingface.co/lightx2v/Qwen-Image-Edit-2511-Lightning/raw/107d238d68b8387e32843d0b4a2e24ceb0d3ad86/README.md, read 2026-11-17]
- [source: Qwen, "Qwen2.5-VL-7B-Instruct README.md", https://huggingface.co/Qwen/Qwen2.5-VL-7B-Instruct/raw/cc594898137f460bfe9f0759e9844b3ce807cfb5/README.md, read 2026-11-17]
- [source: Alibaba PAI, "Wan2.2-VACE-Fun-A14B README.md", https://huggingface.co/alibaba-pai/Wan2.2-VACE-Fun-A14B/raw/4438caabbfdd7437bbb0283d86cb200d1b7223ba/README.md, read 2026-11-17]
- [source: lightx2v, "Wan2.2-Lightning README.md", https://huggingface.co/lightx2v/Wan2.2-Lightning/raw/18bccf8884ec0a078eed79785eb4ef13ea16ce1e/README.md, read 2026-11-17]
- [source: Google, "umt5-xxl README.md", https://huggingface.co/google/umt5-xxl/raw/66cb9e7e85526fe440a945569e42c72fb6cbc0ad/README.md, read 2026-11-17]
- [source: h94, "IP-Adapter README.md", https://huggingface.co/h94/IP-Adapter/raw/018e402774aeeddd60609b4ecdb7e298259dc729/README.md, read 2026-11-17]
- [source: LAION, "CLIP-ViT-H-14-laion2B-s32B-b79K README.md", https://huggingface.co/laion/CLIP-ViT-H-14-laion2B-s32B-b79K/raw/1c2b8495b28150b8a4922ee1c8edee224c284c0c/README.md, read 2026-11-17]
- [source: xinsir, "controlnet-union-sdxl-1.0 README.md", https://huggingface.co/xinsir/controlnet-union-sdxl-1.0/raw/801a4a3fa3d4c936f4feea95b98607bc6726f80c/README.md, read 2026-11-17]
- [source: ZhengPeng7, "BiRefNet README.md", https://huggingface.co/ZhengPeng7/BiRefNet/raw/e2bf8e4460fc8fa32bba5ea4d94b3233d367b0e4/README.md, read 2026-11-17]
- [source: ZhengPeng7, "BiRefNet LICENSE", https://raw.githubusercontent.com/ZhengPeng7/BiRefNet/f7079632d681ecf12161fcea8905682934e59e51/LICENSE, read 2026-11-17]
- [source: Hugging Face, model API for FLUX.1-dev, FLUX.1-schnell, FLUX.2-klein-4B, stable-diffusion-3.5-large, Depth-Anything-V2-Large, IndexTTS-2 and every repo above, https://huggingface.co/api/models/<repo>, read 2026-11-17]
- [source: peastman, "Sonatina Symphonic Orchestra LICENSE" and "README.md", https://raw.githubusercontent.com/peastman/sso/32bbdb169aef636b8216029a2e056424ba7c2abb/LICENSE, read 2026-11-17]
- [source: sfzinstruments, organisation repository list with licence ids, https://api.github.com/orgs/sfzinstruments/repos?per_page=100, read 2026-11-17]
- [source: Versilian Studios/sgossner, "VSCO-2-CE" git tree API at 1.1.0, https://api.github.com/repos/sgossner/VSCO-2-CE/git/trees/28092772094b2d9f1148d84cea97f4545b8c687d?recursive=1, read 2026-11-17]
- [source: Versilian Studios/sgossner, "TrumpetSus.sfz", "Glockenspiel.sfz", "OrganLoud.sfz", "OrganLoudPedal.sfz", "TubularBells.sfz", "FHornSus.sfz" at 1.1.0, https://raw.githubusercontent.com/sgossner/VSCO-2-CE/28092772094b2d9f1148d84cea97f4545b8c687d/TrumpetSus.sfz, read 2026-11-17]
- [source: Versilian Studios/sgossner, "VSCO-2-CE LICENSE" at 1.1.0, https://raw.githubusercontent.com/sgossner/VSCO-2-CE/28092772094b2d9f1148d84cea97f4545b8c687d/LICENSE, read 2026-11-17]
- [source: Versilian Studios/sgossner, "VCSL" git tree API at c1ea7bc, https://api.github.com/repos/sgossner/VCSL/git/trees/c1ea7bcc3c7309650ab0da9d15c9cd1fbc4a4c7e?recursive=1, read 2026-11-17]
- [source: Versilian Studios/sgossner, "VCSL LICENSE" at c1ea7bc, https://raw.githubusercontent.com/sgossner/VCSL/c1ea7bcc3c7309650ab0da9d15c9cd1fbc4a4c7e/LICENSE, read 2026-11-17]
- [source: Karoryfer/sfzinstruments, "karoryfer.black-and-green-guitars" git tree API, "LICENSE" and "Programs/modules/maps_black/ord.sfz" at f3cf516, https://api.github.com/repos/sfzinstruments/karoryfer.black-and-green-guitars/git/trees/f3cf516cbe50b2d6019c7c8fafec4251e2fa29c9?recursive=1, read 2026-11-17]
- Unread (blocked by the forge proxy, connection reset; not routed around): Virtual Playing Orchestra (http://virtualplaying.com/virtual-playing-orchestra/), Philharmonia "Sound samples" (https://philharmonia.co.uk/resources/sound-samples/), FreePats (https://freepats.zenvoid.org/). No claim about them is made here.
