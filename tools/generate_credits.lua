#!/usr/bin/env lua
-- Credits come from this project's dependency graph, author records, licence records and pins.
-- Run from the repo root:
--   flutter pub deps --json | sed -n '/^{/,$p' > <scratch>/graph.json
--   lua tools/generate_credits.lua <scratch>/graph.json        (writes assets/credits.json)
-- The credits page (lib/ending/ending_page.dart) renders every row; openspec/changes/credits-page has the design.
local graph=assert(arg[1],'usage: lua tools/generate_credits.lua PACKAGE-GRAPH.json')
local function q(s)return "'"..s:gsub("'","'\\''").."'"end
local function read(argv)
 local parts={};for _,v in ipairs(argv)do parts[#parts+1]=q(v)end
 local p=assert(io.popen(table.concat(parts,' ')));local s=p:read('a');assert(p:close());return (s:gsub('%s+$',''))
end
local function lines(s)local out={};for line in s:gmatch('[^\n]+')do out[#out+1]=line end;return out end
local function json(v)
 if type(v)=='string'then return '"'..v:gsub('[%z\1-\31\\"]',function(c)
  if c=='"'then return '\\"'elseif c=='\\'then return '\\\\'else return string.format('\\u%04x',c:byte())end
 end)..'"'end
 if type(v)=='number'or type(v)=='boolean'then return tostring(v)end
 assert(type(v)=='table')
 local out={}
 if #v>0 then for _,item in ipairs(v)do out[#out+1]=json(item)end;return '['..table.concat(out,',')..']'end
 local keys={};for k in pairs(v)do keys[#keys+1]=k end;table.sort(keys)
 for _,k in ipairs(keys)do out[#out+1]=json(k)..':'..json(v[k])end;return '{'..table.concat(out,',')..'}'
end
local packages={}
for _,row in ipairs(lines(read({'jq','-r','.packages[] | [.name,.version,(.dependencies|join(","))]|@tsv',graph})))do
 local name,version,deps=(row..'\t'):match('^([^\t]+)\t([^\t]+)\t([^\t]*)');assert(name,row)
 packages[name]={name=name,version=version,deps=lines((deps:gsub(',','\n')))}
end
local direct=lines(read({'jq','-r','.root as $root | .packages[] | select(.name==$root) | .directDependencies[]',graph}))
local is_direct={};local queue={};for _,name in ipairs(direct)do is_direct[name]=true;queue[#queue+1]=name end
local visited={};local used={};local at=1
while queue[at]do
 local name=queue[at];at=at+1
 if not visited[name]then
  visited[name]=true;local p=assert(packages[name],name);used[#used+1]=p
  for _,dep in ipairs(p.deps)do queue[#queue+1]=dep end
 end
end
table.sort(used,function(a,b)return a.name<b.name end)
local direct_rows,indirect_rows={},{}
for _,p in ipairs(used)do
 if p.name~='flutter'and p.name~='sky_engine'then
  local row={name=p.name,version=p.version=='0.0.0'and 'Flutter SDK'or p.version}
  local rows=is_direct[p.name]and direct_rows or indirect_rows;rows[#rows+1]=row
 end
end
local authors={};local author_seen={}
for _,name in ipairs(lines(read({'git','log','--format=%aN','origin/game'})))do
 name=name:gsub('%s*%b()','')
 if not author_seen[name]then authors[#authors+1]={name=name};author_seen[name]=true end
end
table.sort(authors,function(a,b)return a.name<b.name end)
-- Home pages linked from the credit line.
local author_urls={['Tlatoāni']='https://tlatoani.net/'}
for _,a in ipairs(authors)do a.url=author_urls[a.name]end
local sdk_urls={Dart='https://dart.dev/',Flutter='https://flutter.dev/'}
local sdks={}
for _,row in ipairs(lines(read({'jq','-r','.sdks[]|[.name,.version]|@tsv',graph})))do
 local name,version=row:match('^([^\t]+)\t(.+)$');sdks[#sdks+1]={name=name,version=version,url=sdk_urls[name]}
end
-- Every package row links to its pub.dev page.
for _,rows in ipairs({direct_rows,indirect_rows})do
 for _,row in ipairs(rows)do row.url='https://pub.dev/packages/'..row.name end
end
-- The models used in production (credits-page design §4: each licence below is the one the model's own card or
-- licence file states, read 2026-11-17; the Hugging Face card's `license` field where nothing else is cited).
local models={
 {name='ACE-Step 1.5 XL',license='MIT',url='https://huggingface.co/ACE-Step/acestep-v15-xl-turbo',source='Soundtrack pilot (art/workflows/music); the shipped score is MIDI written by tools/score'},
 {name='Kokoro-82M / hexgrad',license='Apache-2.0',url='https://huggingface.co/hexgrad/Kokoro-82M',revision=read({'jq','-r','.kokoro.revision','art/comms/audio.json'})},
 -- The 2026-11-12 radio bank still ships Chatterbox takes. Chatterbox was dropped from the
 -- voice stack on 2026-11-16 and its pin left art/comms/audio.json, so the revision those
 -- takes used is kept here. Remove this row when the last Chatterbox clip is re-rendered.
 {name='Chatterbox / Resemble AI',license='MIT',url='https://huggingface.co/ResembleAI/chatterbox',revision='5bb1f6ee58e50c3b8d408bc82a6d3740c2db6e18'},
 -- Voice-stack engines (openspec/changes/voice-stack). Fish Audio and Boson AI require
 -- these exact credit lines wherever their audio is used (plan/licences-to-sign.md).
 {name='VoxCPM2 / OpenBMB',license='Apache-2.0',url='https://huggingface.co/openbmb/VoxCPM2',source='Voice stack: speech'},
 {name='Dia 1.6B / Nari Labs',license='Apache-2.0',url='https://huggingface.co/nari-labs/Dia-1.6B-0626',source='Voice stack: non-verbals'},
 {name='Fish Audio S2-Pro · Built with Fish Audio',license='Fish Audio Research License',url='https://huggingface.co/fishaudio/s2-pro',source='Voice stack: pilot challenger'},
 {name='Higgs Audio v2 · Built with Higgs Materials licensed from Boson AI USA, Inc., Copyright Boson AI USA, Inc., All Rights Reserved and Meta Llama 3 licensed under the Meta Llama 3 Community License, Copyright Meta Platforms, Inc., All Right Reserved',license='Boson Higgs Audio 2 Community License; Meta Llama 3 Community License',url='https://huggingface.co/bosonai/higgs-tts-2-3b-base',source='Voice stack: pilot challenger'},
 -- Signed licence records: licences/acknowledgements/ (PRs #4-#7, 2026-11-17).
 {name='Built with Meta Llama 3 · Meta Llama 3 is licensed under the Meta Llama 3 Community License, Copyright © Meta Platforms, Inc. All Rights Reserved.',license='Meta Llama 3 Community License; Meta Llama 3 Acceptable Use Policy',source='Voice stack: bundled with Higgs Audio v2 (bosonai/higgs-tts-2-3b-base)'},
 {name='whisper.cpp models / ggerganov',license='MIT',url='https://huggingface.co/ggerganov/whisper.cpp',source='Voice stack: speech recogniser (plan/model-pins-voice.md)'},
 -- openspec/specs/third-party-licence-demucs-weights-unstated: this exact name, marked analysis and reference only.
 {name='Demucs, Alexandre Défossez',license='Weights licence unstated (likely CC BY-NC)',url='https://github.com/adefossez/demucs',source='Analysis and reference only: no separated audio ships'},
 {name='SDXL-Lightning / ByteDance',license='OpenRAIL++',url='https://huggingface.co/ByteDance/SDXL-Lightning',source='Beach concept provenance'},
 {name='SDXL Base 1.0',license='OpenRAIL++',url='https://huggingface.co/stabilityai/stable-diffusion-xl-base-1.0',source='Project asset provenance register'},
 {name='Pixel Art XL / nerijs',license='CreativeML OpenRAIL-M',url='https://huggingface.co/nerijs/pixel-art-xl',source='Beach concept provenance'},
 {name='LayerDiffuse / LayerDiffusion',license='CreativeML OpenRAIL-M',url='https://huggingface.co/LayerDiffusion/layerdiffusion-v1',source='Transparent sprite renders (art/workflows)'},
 {name='IP-Adapter Plus SDXL / h94',license='Apache-2.0',url='https://huggingface.co/h94/IP-Adapter',source='Comms portrait workflow (art/workflows/comms)'},
 {name='ControlNet Union SDXL ProMax / xinsir',license='Apache-2.0',url='https://huggingface.co/xinsir/controlnet-union-sdxl-1.0',source='Boss hero workflow (art/workflows/sprites)'},
 {name='Wan 2.2 VACE Fun / alibaba-pai',license='Apache-2.0',url='https://huggingface.co/alibaba-pai/Wan2.2-VACE-Fun-A14B',source='Sprite in-between workflow (art/workflows/sprites)'},
 {name='Qwen Image Edit / Comfy-Org',license='Apache-2.0',url='https://huggingface.co/Qwen/Qwen-Image-Edit-2511',source='Beach refinement provenance'},
 {name='Qwen Image Edit Lightning / lightx2v',license='Apache-2.0',url='https://huggingface.co/lightx2v/Qwen-Image-Edit-2511-Lightning',source='Beach refinement provenance'},
}
-- Third-party licences: one row per signed acknowledgement in licences/acknowledgements/, titled from its licence
-- text's own heading (licences/texts/) and linked to that text in the source repository.
local repo='https://github.com/8007342/demon_attack'
local licence_titles={
 ['boson-higgs-audio-2-community']='Boson Higgs Audio 2 Community License Agreement',
 ['fish-audio-research-license-2026-03-07']='Fish Audio Research License Agreement (March 7, 2026)',
 ['meta-llama-3-acceptable-use-policy']='Meta Llama 3 Acceptable Use Policy',
 ['meta-llama-3-community']='Meta Llama 3 Community License Agreement',
 ['demucs-weights-unstated']='Demucs weights: licence unstated (analysis and reference only)',
 ['creativeml-openrail-m']='CreativeML Open RAIL-M (August 22, 2022)',
 ['creativeml-openrail-plus-plus-m-sdxl']='CreativeML Open RAIL++-M License (July 26, 2023): Stability AI',
 ['creativeml-openrail-plus-plus-m-sdxl-lightning']='CreativeML Open RAIL++-M License (July 26, 2023): ByteDance SDXL-Lightning',
}
local licences={};local licence_seen={}
for _,path in ipairs(lines(read({'sh','-c','ls licences/acknowledgements/*.yaml'})))do
 local f=assert(io.open(path));local text=f:read('a');f:close()
 local id=assert(text:match('\nlicence: ([%w%-%.]+)'),path)
 local covers=assert(text:match('\ncovers: %[([^%]]*)%]'),path)
 if not licence_seen[id]then
  licence_seen[id]=true
  local textfile='licences/texts/'..id..'.md'
  local has=io.open(textfile);if has then has:close()end
  licences[#licences+1]={name=assert(licence_titles[id],'no title for licence '..id),source='Covers '..covers,
   url=has and(repo..'/blob/main/'..textfile)or(repo..'/blob/main/openspec/specs/third-party-licence-'..id..'/spec.md')}
 end
end
table.sort(licences,function(a,b)return a.name<b.name end)
-- The CC0 sample libraries the score's sample bank is cut from (plan/sample-bank-pins.md). The bank has not shipped:
-- the score still plays its synth voices, so these rows say "coming" until it does.
local samples={}
for _,row in ipairs({
 {'Big Rusty Drums / Karoryfer','https://github.com/sfzinstruments/karoryfer.big-rusty-drums'},
 {'Growlybass / Karoryfer','https://github.com/sfzinstruments/karoryfer.growlybass'},
 {'Black And Green Guitars / Karoryfer','https://github.com/sfzinstruments/karoryfer.black-and-green-guitars'},
 {'Versilian Community Sample Library (VCSL)','https://github.com/sgossner/VCSL'},
 {'VSCO 2 Community Edition','https://github.com/sgossner/VSCO-2-CE'},
})do samples[#samples+1]={name=row[1],license='CC0 1.0',url=row[2],source='Coming with the score\'s sample bank'}end
-- The open-source projects the game, its asset pipelines and its delivery are built on (credits-page design §5).
local function group(title,rows)
 local out={};for _,r in ipairs(rows)do out[#out+1]={name=r[1],url=r[2],license=r[3]}end
 return {title=title,degree='projects',entries=out}
end
-- A licence shows only where it was confirmed on 2026-11-17 (the GitHub repository API's SPDX id, or the npm registry
-- for wrangler 4.151.2); the others link to their home page, which states their terms.
local projects={
 group('Engine and languages',{
  {'Flutter','https://flutter.dev/','BSD-3-Clause'},{'Dart','https://dart.dev/','BSD-3-Clause'},
  {'Flame','https://flame-engine.org/','MIT'},{'Lua','https://www.lua.org/'},{'Go','https://go.dev/','BSD-3-Clause'},
  {'Rust','https://www.rust-lang.org/'},{'Python','https://www.python.org/'},{'Node.js','https://nodejs.org/'}}),
 group('Art, music and voice pipelines',{
  {'Blender','https://www.blender.org/'},{'ComfyUI','https://github.com/Comfy-Org/ComfyUI'},
  {'PyTorch','https://pytorch.org/'},{'NumPy','https://numpy.org/'},{'SciPy','https://scipy.org/','BSD-3-Clause'},
  {'Pillow','https://python-pillow.org/'},{'python-soundfile','https://github.com/bastibe/python-soundfile','BSD-3-Clause'},
  {'whisper.cpp','https://github.com/ggml-org/whisper.cpp','MIT'},{'FFmpeg','https://ffmpeg.org/'},
  {'Opus','https://opus-codec.org/'},{'libwebp','https://developers.google.com/speed/webp','BSD-3-Clause'},
  {'ImageMagick','https://imagemagick.org/'}}),
 group('Planning, delivery and hosting',{
  {'OpenSpec','https://openspec.dev/','MIT'},{'Git','https://git-scm.com/'},
  {'Cloudflare Workers','https://workers.cloudflare.com/'},
  {'Wrangler','https://developers.cloudflare.com/workers/wrangler/','MIT OR Apache-2.0'}}),
}
-- The three projects the forge stands on, shown as cards at the top (credits-page design §2). Only Tillandsias shows
-- its own icon (its site's favicon, GPL-3.0 like this game); Fedora and Podman get neutral glyphs, not their marks.
local built_on={
 {name='Tillandsias',url='https://tillandsias.org/',icon='assets/images/credits/tillandsias.webp',
  blurb='The forge this game is made in: private, ephemeral dev environments with local AI tools.'},
 {name='Fedora',url='https://fedoraproject.org/',glyph='desktop',
  blurb='The Linux distribution the forge and its toolchains run on.'},
 {name='Podman',url='https://podman.io/',glyph='container',
  blurb='The containers that hold every forge, toolchain and studio.'},
}
local sections={
 -- The creator line reads "By <names>, with love"; then the models, the licences, the samples to come, the
 -- open-source projects, and the code foundations.
 {title='',degree='creator',lead='By ',tail=', with love',entries=authors,
  alongside={lead='Made alongside ',name='Claude',url='https://claude.ai/',tail=' by Anthropic'}},
 {title='Models used to make the art, music and voices',degree='models',entries=models},
 {title='Third-party licences',degree='licences',entries=licences},
 {title='CC0 sample libraries (coming)',degree='samples',entries=samples},
}
for _,g in ipairs(projects)do sections[#sections+1]=g end
for _,s in ipairs({
 {title='Built with',degree='direct',entries=sdks},
 {title='Game and app packages',degree='direct',entries=direct_rows},
 {title='Their foundations',degree='indirect',entries=indirect_rows},
})do sections[#sections+1]=s end
local result={schema='demon-attack.credits/v2',title='Demon Attack',platform='Tillandsias.org',
 platform_url='https://tillandsias.org/',built_on=built_on,
 trademark_note='Fedora and Podman are named here only to credit the software this game is built with. This game is not affiliated with or endorsed by the Fedora Project, Red Hat or the Podman project.',
 source_url=repo,source_label='github.com/8007342/demon_attack',source_license='GPLv3 · see source LICENSE',
 sections=sections,
 sources={dependency_graph='flutter pub deps --json',lockfile='pubspec.lock',
  authors_ref='origin/game',authors_commit=read({'git','rev-parse','origin/game'}),
  lockfile_sha256=read({'sha256sum','pubspec.lock'}):match('^(%x+)'),
  model_pins='art/comms/audio.json',asset_provenance='plan/asset-provenance.md',
  licences='licences/acknowledgements',sample_pins='plan/sample-bank-pins.md',
  beach_provenance='assets/research/battle-metal-radio/ending/beach-qwen-v1.provenance.json'},
 note='All game artwork, performances and musical themes are original project work. Package notices are available through the bundled license registry.'}
local file=assert(io.open('assets/credits.json','w'));file:write(json(result),'\n');file:close()
local project_count=0;for _,g in ipairs(projects)do project_count=project_count+#g.entries end
print('credits: '..#authors..' contributor name(s), '..#direct_rows..' direct packages, '..#indirect_rows..' runtime foundations, '..#models..' model credits, '..#licences..' licences, '..#samples..' sample libraries (coming), '..project_count..' open-source projects')
