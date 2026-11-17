# Voice model pins for the Tillandsias licence register (2026-11-17)

These are the rows the coordinator asked for: repo, revision, and every file with its sha256. They let the Tillandsias
licence register admit the voice models the moment the release freeze lifts. Each list was fetched from the Hugging
Face tree API (`/api/models/<repo>/tree/<revision>?recursive=true`) at the pinned revision on 2026-11-17. LFS files
take the API's sha256. Small non-LFS files were downloaded at that revision and hashed with `sha256sum`. Recipe:
fetch the tree, then hash each non-LFS file.

- **Register:** VoxCPM2 and Dia are Apache-2.0, so they go in the open register with no signature. Fish S2-Pro and
  Higgs v2 (plus its tokenizer) go in the restricted register and wait for the merged-PR licence records (Tillandsias
  #1121, `plan/licences-to-sign.md`).
- **Renamed:** Higgs Audio v2's repo moved from `bosonai/higgs-audio-v2-generation-3B-base` to
  `bosonai/higgs-tts-2-3b-base`, and the old name redirects. Its LICENSE hashes the same as the copy in
  `plan/licences-to-sign.md`.
- **Duplicates:** Dia's 12.9 GB includes duplicate weight formats. The register may admit just the safetensors files.

| Repo | Revision | Total |
|---|---|---|
| openbmb/VoxCPM2 | `7936080b41163874f38610f46f438e2c0757f9fd` | 4.96 GB |
| nari-labs/Dia-1.6B | `257bc72f9b78182ccc6fa07675a9ae4c1a44e2cd` | 12.89 GB |
| fishaudio/s2-pro | `1de9996b6be38b745688de084d87a5633f714e4e` | 11.01 GB |
| bosonai/higgs-tts-2-3b-base | `d80c511612b3040ff2877ce3d408747df1739f11` | 11.58 GB |
| bosonai/higgs-audio-v2-tokenizer | `815a03f1b57dcb5ae918db415f22cd0c8a6f0f54` | 0.81 GB |

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

## nari-labs/Dia-1.6B
revision: 257bc72f9b78182ccc6fa07675a9ae4c1a44e2cd  gated: false
| path | bytes | sha256 |
|---|---:|---|
| `.gitattributes` | 1519 | `11ad7efa24975ee4b0c3c3a38ed18737f0658a5f75a0a96787b576a78a023361` |
| `README.md` | 6551 | `ba8921486a0a601d65b9445a449b799c338a1a80943c8c0669eaba9ea4404b21` |
| `config.json` | 941 | `9140e85fd15b82d7f268c5681a41fb1de68573ec206b87cb3a5862fe5c598d6e` |
| `dia-v0_1.pth` | 6444788896 | `d12004b2f3121af763bdf2a3b575586b00c02bdd00a315a23c7b7bdb2a8f9475` |
| `model.safetensors` | 6444682848 | `caba289b60f6d7d1e58fc744f4dc25aae88995fcca46be3d05e220b971486a26` |
| `preprocessor_config.json` | 172 | `1d47667309198c616ff39964928543718a180aaa0269ce38442418edc1f19f75` |

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

## bosonai/higgs-tts-2-3b-base
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

## bosonai/higgs-audio-v2-tokenizer
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

