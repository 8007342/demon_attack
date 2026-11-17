# Voice model pins for the Tillandsias licence register (2026-11-17)

These are the rows the coordinator asked for: repo, revision, and every file with its sha256, plus (second pass,
2026-11-17) the runtime code commit that loads each set of weights. They let the Tillandsias licence register admit
the voice models when the studio voice capability is built (queued by the coordinator after the cut, with
`openspec/changes/voice-stack` and `openspec/changes/voice-direction` as its requirements). **No TTS node is admitted
today.**

**Method.** Each file list was fetched from the Hugging Face tree API (`/api/models/<repo>/tree/<revision>?recursive=true`)
at the pinned revision. LFS files take the API's sha256. Small non-LFS files were downloaded at that revision and
hashed with `sha256sum`; their sizes match the API's. No weight file was downloaded. Code commits come from the GitHub
commits and compare APIs and from the source files at the pinned commit, read raw.

- **Register:** VoxCPM2, Dia 1.6B-0626, the DAC codec, bosonai/hubert_base and the whisper.cpp models are permissive
  (Apache-2.0 or MIT), so they go in the open register with no signature. Fish S2-Pro and Higgs v2 (with its tokenizer)
  go in the restricted register; their licence records are signed (PRs #4–#7, `licences/acknowledgements/`), and each
  record covers the repo, not a revision.
- **Renamed:** Higgs Audio v2's repo moved from `bosonai/higgs-audio-v2-generation-3B-base` to
  `bosonai/higgs-tts-2-3b-base`; the old name redirects, and the code's default still uses the old name.
- **Duplicates:** Dia's repos include duplicate weight formats. The register may admit just the safetensors files and
  the JSON configs.

## Summary

| Role | Repo | Revision | Total | Licence | Change on 2026-11-17 (second pass) |
|---|---|---|---|---|---|
| Speech | openbmb/VoxCPM2 | `7936080b41163874f38610f46f438e2c0757f9fd` | 4.96 GB | Apache-2.0 | none |
| Non-verbals | nari-labs/Dia-1.6B-0626 | `ef2795fcc29c5abe6ffc91fd33808588b49bbc66` | 19.33 GB (6.44 GB safetensors + JSON) | Apache-2.0 | **re-pinned** from Dia-1.6B (newer, same licence; the code loads it by default) |
| Dia codec | descriptinc/descript-audio-codec release `0.0.1` `weights.pth` | GitHub release asset | 306,717,287 B | MIT | **added**; sha256 **not verified** (see the Dia section) |
| Challenger | fishaudio/s2-pro | `1de9996b6be38b745688de084d87a5633f714e4e` | 11.01 GB | Fish Audio Research License | none; runs 4-bit (NF4) on the A5000 |
| Challenger | bosonai/higgs-tts-2-3b-base | `10840182ca4ad5d9d9113b60b9bb3c1ef1ba3f84` | 11.58 GB | Boson Higgs Audio 2 Community | **re-pinned** to the last revision the boson-ai code can load (see the Higgs section) |
| Higgs tokenizer | bosonai/higgs-audio-v2-tokenizer | `9d4988fbd4ad07b4cac3a5fa462741a41810dbec` | 0.81 GB | Boson Higgs Audio 2 Community | **re-pinned**, same reason |
| Higgs semantic model | bosonai/hubert_base | `d7a7039bd0d93005f6532853db1934722d9a5e02` | 0.38 GB | Apache-2.0 (card tag) | **added**: the tokenizer loads it |
| Speech recogniser | ggerganov/whisper.cpp | `5359861c739e955e79d9a303bcbc70fb988958b1` | 0.72 GB (two files) | MIT | **added** |

## Runtime code pins

Each commit is the one that loads the weights above. **Every row: verify by smoke run when the capability is built**
(load the pinned weights from the register, render one line, check the output rate and length).

| Engine | Repo | Commit | Code licence | Evidence |
|---|---|---|---|---|
| VoxCPM2 | OpenBMB/VoxCPM | `300e4260b509066151d623dc9c0aa922cf82232b` (main, 2026-11-09) | Apache-2.0 (LICENSE sha256 `4f10acc2…0265e4`) | Same day as the weights' last commit (`7936080`, "update docs link", 2026-11-09); the weights' only change since 2026-04-16 is README text. It is 40 commits after `9f1548b` "feat: add seed support for reproducible generation in v1 and v2" (2026-06-01), which the capability needs; tag 2.0.3 (`19b6bf7`, 2026-04-28) predates seeds. `src/voxcpm/core.py` `_generate(text, prompt_wav_path, prompt_text, reference_wav_path, …, seed)` at this commit: "`prompt_wav_path`: Path to prompt audio for continuation mode. Must be paired with `prompt_text`", "`reference_wav_path`: … Can be used alone or combined with `prompt_wav_path` + `prompt_text`" |
| Dia 1.6B-0626 | nari-labs/dia | `876125e461a03b157ec905b0fe8b57a0f8b9e7a0` (main, 2025-11-19) | Apache-2.0 (LICENSE sha256 `34c1659a…5358d`) | `65028e0` "New weights & transformers support (#243)" (2025-06-27) moved the loaders to 0626; `dia/model.py` at this commit: `from_pretrained(model_name: str = "nari-labs/Dia-1.6B-0626", …)`. The only file changed after `998fc25` (the last code fix, 2025-06-28) is `README.md` (compare API) |
| Fish S2-Pro | fishaudio/fish-speech | `bdd39477922a89b904c6f2c7397f2a9bbcc60a0c` (2026-10-10) | Fish Audio Research License (LICENSE sha256 `aa7d9206…c32d80`, identical to the signed S2-Pro text) | The parent of `1ff3c3e` "Update for Drama-3 (#1350)" (2026-10-13, tag v3.0.0-beta). Its README describes "Fish Audio S2 Pro" and links `fishaudio/s2-pro`; tag v2.0.0-beta (`3578e4e`, "S2 beta", 2026-03-10) is the release that came out the day after the weights. `tools/llama/quantize.py` (int8, int4 groupwise) and the int4 loader in `fish_speech/models/text2semantic/llama.py` are present |
| Higgs v2 | boson-ai/higgs-audio | `8b1539a02d5764317724a904a344a0f1be8a736e` (2026-01-18) | Apache-2.0 (LICENSE sha256 `c8858a5a…02e5b`) | The parent of `05a145b` "docs: point README to Higgs Audio v3 … archive v2/v2.5 guide" (2026-06-05). Both of those commits touch only `README.md`/`README_V2.md`; the last code change is `f04f5df` (2025-08-04). `examples/generation.py` defaults: `bosonai/higgs-audio-v2-generation-3B-base`, `bosonai/higgs-audio-v2-tokenizer`; `load_higgs_audio_tokenizer` reads `model.pth` and the config's `semantic_techer` |
| Speech recogniser | ggml-org/whisper.cpp | `d1be6fde11ac6e0407606b4e42fe72d34add8037` (tag v1.9.5, 2026-10-06) | MIT (LICENSE sha256 `94f29bbe…f1010d`) | Latest release. `models/download-ggml-model.sh` at this commit lists `base.en` and `large-v3-turbo-q5_0` from `https://huggingface.co/ggerganov/whisper.cpp`; README "Word-level timestamp (experimental)": `-ml 1` |

**Capability notes that follow from the code:**
- **VoxCPM:** `from_pretrained(…, load_denoiser=True, zipenhancer_model_id="iic/speech_zipenhancer_ans_multiloss_16k_base")`
  fetches an unpinned ModelScope denoiser by default. The capability passes `load_denoiser=False` and `denoise=False`.
- **Dia:** `_load_dac_model()` calls `dac.utils.download()`, which fetches
  `https://github.com/descriptinc/descript-audio-codec/releases/download/0.0.1/weights.pth` (44 kHz, 8 kbps; the
  package's `__MODEL_LATEST_TAGS__`). The codec repo says "Weights are released as part of this repo under MIT license"
  (README) and the package is MIT (PyPI 1.0.0). The GitHub releases API gives the asset's size (306,717,287 bytes) but
  no digest, so its sha256 is **not verified here**; the register hashes it on its first, consented fetch and records
  it in this file. The Hugging Face copy `descript/dac_44khz` (rev `c1bc521685adf9cfe247bc39a5ca58917eda1ac4`,
  `model.safetensors` sha256 `6128ebff483a41422b0164d079a3773b0d8d82e64c4293d775994cbf8baf913a`) is the transformers
  path the 0626 repo's `audio_tokenizer_config.json` names, but its card says "License: [More Information Needed]", so
  it is not the pick.
- **Higgs:** both bosonai repos were converted to the transformers format in 2026 (`trfms-support`, 2026-04-04; on
  2026-05-31 the tokenizer's `model.pth` was deleted for a `model.safetensors` "aligned with eustlb", and the model's
  three shards were deleted for one `model.safetensors`). The boson-ai code reads `model.pth` and the original config
  keys, so the first-pass pins (`d80c511…`, `815a03f…`) cannot run under it. They are kept below as the
  **transformers route**: transformers has `models/higgs_audio_v2` since `1618d44` "Add Higgs Audio V2 Model (#40294)"
  (2026-02-19), with multi-speaker voice cloning in its model doc, but that doc loads `eustlb/higgs-audio-v2-generation-3B-base`,
  and nobody has checked that it loads the bosonai repos. The boson-ai route is the pick because its
  `generation.py` has the chunked dialogue with context (`--generation_chunk_buffer_size`) that the banter threads need.
  The pre-conversion LICENSE hashes the same as the signed text (`8b2e018e…dde9a0`).
- **Higgs tokenizer:** its pinned `config.json` sets `"semantic_techer": "hubert_base_general"`, which loads
  `AutoModel.from_pretrained("bosonai/hubert_base", trust_remote_code=True)`. That repo's config has
  `"architectures": ["HubertModel"]` and no `auto_map`, so no remote code runs; the capability passes the pinned
  revision below and sets `trust_remote_code=False` if the loader allows it.
- **Fish:** runs as 4-bit NF4 on the A5000 (`openspec/changes/voice-direction` design §7.5). Two 4-bit routes need no
  new weights: bitsandbytes NF4 on the fly (bitsandbytes is MIT; the ComfyUI-FishAudioS2 README: "BNB INT8 and BNB NF4
  options use the s2-pro (bf16) model and quantize on-the-fly via bitsandbytes", about 16 GB, and "They work on any
  NVIDIA GPU without special hardware requirements"), or fish-speech's own `tools/llama/quantize.py --mode int4`, which
  writes a derived checkpoint the register would then hash. FP8 (`drbaph/s2-pro-fp8`) is out: the same README says it
  "requires RTX 4090/5090 or Ada/Blackwell GPU".

Sources for this section, all read 2026-11-17: the GitHub commits, compare and tags APIs and the raw files at the
commits named above (OpenBMB/VoxCPM, nari-labs/dia, fishaudio/fish-speech, boson-ai/higgs-audio, ggml-org/whisper.cpp,
descriptinc/descript-audio-codec, huggingface/transformers, bitsandbytes-foundation/bitsandbytes); the Hugging Face
model, tree and commits APIs for every repo below; [source: Saganaki22, "ComfyUI-FishAudioS2 README",
https://raw.githubusercontent.com/Saganaki22/ComfyUI-FishAudioS2/main/README.md, read 2026-11-17].

## openbmb/VoxCPM2
revision: 7936080b41163874f38610f46f438e2c0757f9fd  gated: false
| path | bytes | sha256 |
|---|---:|---|
| `.gitattributes` | 1519 | `11ad7efa24975ee4b0c3c3a38ed18737f0658a5f75a0a96787b576a78a023361` |
| `README.md` | 7903 | `feb850b390aa5051b81cbdc73b048361273552f003dd386b4da9c39ec9b6f055` |
| `audiovae.pth` | 376951122 | `94b5d51e107e0507d4acc976cfdadb64edd6fd06d1f751dadbf2fd1594274bf1` |
| `config.json` | 4336 | `405f0dcd92f7feba6011ed4eac5c8d4f74cba9712f07fd5cfa3063bbdd95402c` |
| `model.safetensors` | 4580080592 | `f7f964cfa9da23653baec6e6f7750719977ad944ed9f95fe52fe3a620506891d` |
| `special_tokens_map.json` | 1632 | `068594063e37662c02b21acf42ebb334ef6a74fb810e68a2368f88f08351de76` |
| `tokenization_voxcpm2.py` | 2895 | `84489ea32b6ee0cae22ed5480cacb6df85c46624c3119be9a2021c3649a12729` |
| `tokenizer.json` | 3676772 | `f8984687e4a92a3503d521396d454b7d68e9fdaab2a0288eb3536c7c1aa4bc20` |
| `tokenizer_config.json` | 5059 | `e78a3ebb48a0b9437efd1823b6b726c823da89e49dd8bcc90c02419d9baa772b` |

## nari-labs/Dia-1.6B-0626 (current)
revision: ef2795fcc29c5abe6ffc91fd33808588b49bbc66  gated: false  card licence: apache-2.0 (no LICENSE file in the repo; the README's License and Disclaimer sections are byte-identical to the pinned 1.6B card apart from a trailing newline; the README points to the GitHub LICENSE, sha256 `34c1659a3495220f85dffebd4d3a930bcbfd9f216f8a3c5f880a1d4a59a5358d` at the code pin)
| path | bytes | sha256 |
|---|---:|---|
| `.gitattributes` | 1519 | `11ad7efa24975ee4b0c3c3a38ed18737f0658a5f75a0a96787b576a78a023361` |
| `README.md` | 8545 | `f32e9386e5896961ac54bb7358d41737c13f0bc7025ab084a64923a1620e7707` |
| `audio_tokenizer_config.json` | 98 | `1552f8bdccdfe0a98a8e93f9eb369de315e66a07b1530eba0be41513e2ee8f5e` |
| `config.json` | 1396 | `4f4e9c50e6898fa79d6fe16e9991bebef07a4d3dd6926eee5eb7f7e39c88e04f` |
| `dia-v1.pth` | 6444787333 | `8a5106c06899aeea013a7f6ef32e84a15a30f965be676b97996b3ddaf1eb55b9` |
| `generation_config.json` | 238 | `df7c1f7e4dc1c3e35811b7b2e49abd89d8a8b9599ec732eb6b0d17d678548ac4` |
| `model-00001-of-00002.safetensors` | 4993046400 | `9cf8f82d9f87d408f5da9cc0d73a3e9c4d9ca3633a4df3be4d283277b7ff1b1a` |
| `model-00002-of-00002.safetensors` | 1451637544 | `54bf3a47ac13e28ba6193659d57bc63a46875685b211b071f782c32efc834343` |
| `model.safetensors.index.json` | 30833 | `89664ffd667582a41e71c9aa1a4ba9de8187ec9dcd1e7711d97ec57d6e32dec5` |
| `preprocessor_config.json` | 243 | `7dfa85b765a7c5b3fb3907abf43ece88cd9edcbf39402e3e32e056b3275e5433` |
| `pytorch_model.bin` | 6444787333 | `8a5106c06899aeea013a7f6ef32e84a15a30f965be676b97996b3ddaf1eb55b9` |
| `special_tokens_map.json` | 277 | `4373f3b7455d5a34196fca520de10a0af2af9d7cc05f6177b4be73a8bcfb3f74` |
| `tokenizer_config.json` | 803 | `6c84315ff3c5214a5846bc3c08cb23fe01146906e4abf395519316732d602e64` |

## bosonai/hubert_base
revision: d7a7039bd0d93005f6532853db1934722d9a5e02  gated: false  card licence: apache-2.0
| path | bytes | sha256 |
|---|---:|---|
| `.gitattributes` | 1519 | `11ad7efa24975ee4b0c3c3a38ed18737f0658a5f75a0a96787b576a78a023361` |
| `README.md` | 1753 | `1e2f8edc8fb708e53ddb788460831cefa5660cf3e65ff2fe961e659b4a608dfb` |
| `config.json` | 1375 | `dfbbabe04cc00ce28acd7c878961eb25af88301c5e3f14a61c168479236f365f` |
| `model.safetensors` | 377510632 | `37a33094dbd080a2b5dcfcb0a9f98db5434fd78aa597d89fb972fbd19de196cc` |

## fishaudio/s2-pro
revision: 1de9996b6be38b745688de084d87a5633f714e4e  gated: false
| path | bytes | sha256 |
|---|---:|---|
| `.gitattributes` | 1619 | `523e75f7f8918d29534b97117ba651253f26fa702686b9295fc09d6abe0fede9` |
| `LICENSE.md` | 10360 | `aa7d9206e9d710590987a3636934f643529c00cd490323594e6206aaa0c32d80` |
| `README.md` | 5117 | `3c2d78af0f3991ef6047272d4df18f204b4340e1e5fcc975d0e720d4312c4b29` |
| `chat_template.jinja` | 4116 | `87a2728cb8dc9fe424d624542f6060ec05a1d285ebbec578bb078900e33396b5` |
| `codec.pth` | 1871099728 | `74fc41c5a7151c6f350af8bd7e5d6e3accfcc7f3dfbfac23afd35af07052bb2f` |
| `config.json` | 1863 | `261b519a2a9576710fc8533a77297fae007f0e7b3aa28a217f8352b7f32fe993` |
| `model-00001-of-00002.safetensors` | 4986872984 | `c4218e8ac93be83b35eee30b4f94cb2e9b5ecff40f3e21611438d2f4f8804aad` |
| `model-00002-of-00002.safetensors` | 4136876104 | `76738d23465deaac431433232c0762908cc99a6eddc3d49f67307d92680827be` |
| `model.safetensors.index.json` | 32686 | `c8cb9974d3d17663a95dba1d6c3ea531fc42d377c0dff946f3a01a0ec48d45a3` |
| `overview.png` | 3544504 | `f77da18e7d3cf59182fb714fc6c1bc526e7877b538e6380d8f002e84e8c56ea9` |
| `special_tokens_map.json` | 101864 | `c2ff18fde6e43b7408435bc8ed079af74531befba549358a97cbc59ce606bc6b` |
| `tokenizer.json` | 12217872 | `f24e08099d45a8adf3f52f5f0b03276e433bb9d689bb15fcbcc48ce58744588b` |
| `tokenizer_config.json` | 860832 | `b8d149343ae425b0da67e6708686aceb51be7815d9792f265fc12ff04d5e9856` |

## bosonai/higgs-tts-2-3b-base (current: last revision before the transformers conversion)
revision: 10840182ca4ad5d9d9113b60b9bb3c1ef1ba3f84  gated: false  (2025-07-28, "Correct hyper-link to Architecture Blog (#17)"; `config.json` `model_type` `higgs_audio`)
| path | bytes | sha256 |
|---|---:|---|
| `.gitattributes` | 2062 | `66cbd400b0700b312e3cc4285dd135d36cded7a6c84f086de123300092496589` |
| `LICENSE` | 9172 | `8b2e018eeb3967a4636ccc57528440b33c14dd6e02ad67571fc7759489dde9a0` |
| `README.md` | 12557 | `012dfeb797480b9429c4601e36bbe371f2610b9208721d3fd2db7e34fbfba1a3` |
| `config.json` | 6264 | `d9fba363d906384f54b229096f6d913eb118c6d57bd7159fd5f6aaa1224cbcbe` |
| `emergent-tts-emotions-win-rate.png` | 838024 | `63bc6a63f3e3217ff05b5e5e0adb8ce89cdbb9da086e74d0c469c6465e611221` |
| `generation_config.json` | 147 | `aafa84b3fba4961c011d94904b0c77215202d6f6d4bfe93b44d4de18af251701` |
| `higgs_audio_tokenizer_architecture.png` | 117208 | `f7c0177e38dd9c873acf8ac55c159ce65ba50970cbeba9663582da4698037447` |
| `higgs_audio_v2_architecture_combined.png` | 438316 | `6260cd2e98235c9e181316db9fd6f716fbca1e314ef367ff338b988dcb54a76c` |
| `higgs_audio_v2_open_source_delay_pattern.png` | 33002 | `6b9fd532820b7f1c194bd263a681f1cf08082c92d3022465a5f00d5501ca646b` |
| `model-00001-of-00003.safetensors` | 4965820232 | `46b461c6658985869a757453a6ba5199d7767c9d3b98b443c154c0771b1b56db` |
| `model-00002-of-00003.safetensors` | 4983224272 | `6f6654fe31eb9de990bd2734b1cbf85e79966945fa0c9923b15c5c06b073e35e` |
| `model-00003-of-00003.safetensors` | 1593566728 | `02a36e0c47281184ecbee3b9329fc4546a57674d9faca89cb2d3110c4c6bb56b` |
| `model.safetensors.index.json` | 31095 | `2767708b88fc90c12bacbdbeac35d49e41ad2e5d146a3e93a82659fe835c8c86` |
| `open_source_repo_demo.mp4` | 13975450 | `6dd765d355fffb62861e627373857c01d15fbf95ddaf7a6f5e7dff1d933ceb14` |
| `special_tokens_map.json` | 301 | `cc2e013b7545f183ef03e079a3c91c6f364fa37e4068c512d7dd843e59024535` |
| `tokenizer.json` | 17209675 | `1a222563314bf6ffe3471622bff017ff5bb0630f2924faf44216195ebfef2af3` |
| `tokenizer_config.json` | 50279 | `3decafa60de639f2829350a2521a0c28a5622bd5b402c4c2ce54a1022d05bcc7` |

## bosonai/higgs-audio-v2-tokenizer (current: last revision before the transformers conversion)
revision: 9d4988fbd4ad07b4cac3a5fa462741a41810dbec  gated: false  (2025-07-22; `config.json` has `"semantic_techer": "hubert_base_general"`)
| path | bytes | sha256 |
|---|---:|---|
| `.gitattributes` | 1640 | `9d825302ccba6bb38bcad246e5d6a854c7c1b1e5ce087d85a3f1a96dd99e997a` |
| `LICENSE` | 9172 | `8b2e018eeb3967a4636ccc57528440b33c14dd6e02ad67571fc7759489dde9a0` |
| `README.md` | 14538 | `00b72e157b7f61844952cc2fcbe3e75e292990bd7fca780d3c65bc7c9426182f` |
| `config.json` | 226 | `70d56b57f26d8de9058582a7f6179504936dd950eceb4076f6ea0e866fa72382` |
| `higgs_audio_tokenizer_architecture.png` | 117208 | `f7c0177e38dd9c873acf8ac55c159ce65ba50970cbeba9663582da4698037447` |
| `model.pth` | 805947058 | `e64349910124c5e615bae9e373f45d0ed346056910844ae1a5ac44c92dc24c92` |

## ggerganov/whisper.cpp (two files only)
revision: 5359861c739e955e79d9a303bcbc70fb988958b1  gated: false  card licence: mit. The register admits only the files below; the repo holds every ggml conversion.
| path | bytes | sha256 |
|---|---:|---|
| `.gitattributes` | 1477 | `db7c0371f46f0840b8f25794c1e3321c9b5820a8cb6ba9694a46fc64b8fae5a6` |
| `README.md` | 3196 | `21fd967098804f33fc84e803fb0e5ab7666d71801f4027cf28a65e7af09c1758` |
| `ggml-base.en.bin` | 147964211 | `a03779c86df3323075f5e796cb2ce5029f00ec8869eee3fdfb897afe36c6d002` |
| `ggml-large-v3-turbo-q5_0.bin` | 574041195 | `394221709cd5ad1f40c46e6031ca61bce88931e6e088c188294c6d5a55ffa7e2` |

`ggml-large-v3-turbo-q5_0` is the quality pick (take rejection, word timestamps for cutting reels); `ggml-base.en` is the fast pre-check.

## Superseded first-pass pins (kept for the record)

Not admitted. Dia-1.6B is replaced by Dia-1.6B-0626 (newer, same licence). The two Higgs rows are the transformers-format revisions; the boson-ai code cannot load them (see Runtime code pins), and they are the fallback only if the capability takes the transformers route.

### nari-labs/Dia-1.6B
revision: 257bc72f9b78182ccc6fa07675a9ae4c1a44e2cd  gated: false
| path | bytes | sha256 |
|---|---:|---|
| `.gitattributes` | 1519 | `11ad7efa24975ee4b0c3c3a38ed18737f0658a5f75a0a96787b576a78a023361` |
| `README.md` | 6551 | `ba8921486a0a601d65b9445a449b799c338a1a80943c8c0669eaba9ea4404b21` |
| `config.json` | 941 | `9140e85fd15b82d7f268c5681a41fb1de68573ec206b87cb3a5862fe5c598d6e` |
| `dia-v0_1.pth` | 6444788896 | `d12004b2f3121af763bdf2a3b575586b00c02bdd00a315a23c7b7bdb2a8f9475` |
| `model.safetensors` | 6444682848 | `caba289b60f6d7d1e58fc744f4dc25aae88995fcca46be3d05e220b971486a26` |
| `preprocessor_config.json` | 172 | `1d47667309198c616ff39964928543718a180aaa0269ce38442418edc1f19f75` |

### bosonai/higgs-tts-2-3b-base
revision: d80c511612b3040ff2877ce3d408747df1739f11  gated: false
| path | bytes | sha256 |
|---|---:|---|
| `.gitattributes` | 2062 | `66cbd400b0700b312e3cc4285dd135d36cded7a6c84f086de123300092496589` |
| `LICENSE` | 9172 | `8b2e018eeb3967a4636ccc57528440b33c14dd6e02ad67571fc7759489dde9a0` |
| `README.md` | 25825 | `2512230c742f614e715d36cd461807c5af09dd5234752bc5d223027f55db4fc9` |
| `chat_template.jinja` | 3047 | `8b03097b6cc0cbf7783d7a7d5680da31e330fccfd38eb2d903590d8872dc7c9b` |
| `config.json` | 1096 | `6fdc349a035995e338a29350a367e27d131bf2995206f1e7879c687106aae187` |
| `emergent-tts-emotions-win-rate.png` | 838024 | `63bc6a63f3e3217ff05b5e5e0adb8ce89cdbb9da086e74d0c469c6465e611221` |
| `generation_config.json` | 351 | `5c4b0a8031f48b364398c2a5f949d6023c90e45a7a656c1b66a7999d075a6180` |
| `higgs_audio_tokenizer_architecture.png` | 117208 | `f7c0177e38dd9c873acf8ac55c159ce65ba50970cbeba9663582da4698037447` |
| `higgs_audio_v2_architecture_combined.png` | 438316 | `6260cd2e98235c9e181316db9fd6f716fbca1e314ef367ff338b988dcb54a76c` |
| `higgs_audio_v2_open_source_delay_pattern.png` | 33002 | `6b9fd532820b7f1c194bd263a681f1cf08082c92d3022465a5f00d5501ca646b` |
| `model.safetensors` | 11542613696 | `9c896b019ec1a4fc950218e32797c30870d36ce1cd76f45b35de46495764a204` |
| `open_source_repo_demo.mp4` | 13975450 | `6dd765d355fffb62861e627373857c01d15fbf95ddaf7a6f5e7dff1d933ceb14` |
| `processor_config.json` | 682 | `eabdc6aeb20301410ffeb570486d162329c0d1d0d70e1befb8bdb964782de220` |
| `special_tokens_map.json` | 301 | `cc2e013b7545f183ef03e079a3c91c6f364fa37e4068c512d7dd843e59024535` |
| `tokenizer.json` | 17209675 | `1a222563314bf6ffe3471622bff017ff5bb0630f2924faf44216195ebfef2af3` |
| `tokenizer_config.json` | 405 | `e8994ea64453989c8781bb673c93948da0c877a6c449c150526fe2de4d5e100f` |

### bosonai/higgs-audio-v2-tokenizer
revision: 815a03f1b57dcb5ae918db415f22cd0c8a6f0f54  gated: false
| path | bytes | sha256 |
|---|---:|---|
| `.gitattributes` | 1640 | `9d825302ccba6bb38bcad246e5d6a854c7c1b1e5ce087d85a3f1a96dd99e997a` |
| `LICENSE` | 9172 | `8b2e018eeb3967a4636ccc57528440b33c14dd6e02ad67571fc7759489dde9a0` |
| `README.md` | 15746 | `5b6f7bb45b04e04352be7f28f40d1233f15fd11b97b66db0165cc8e0115294fd` |
| `config.json` | 2531 | `eefb20806f7104e77c9a5277c9df0f9bb8826b08eb1d4e8ab2b9829b6ef9fac1` |
| `higgs_audio_tokenizer_architecture.png` | 117208 | `f7c0177e38dd9c873acf8ac55c159ce65ba50970cbeba9663582da4698037447` |
| `model.safetensors` | 805665628 | `fe7c5e8785e0a05833e1bfc3e002ec7f55af21e306b2e7154a448c1f54ccfb0d` |
| `preprocessor_config.json` | 206 | `ae61eea88558608ee2fa86d2aec9fce8d99a5ff75d09cb7651ccce21ae1d9084` |

