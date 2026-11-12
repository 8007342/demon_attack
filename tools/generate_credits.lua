#!/usr/bin/env lua
-- Credits come from this project's dependency graph, author records and pins.
-- Generate a fresh graph with `flutter pub deps --json` before invoking.
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
local sdks={}
for _,row in ipairs(lines(read({'jq','-r','.sdks[]|[.name,.version]|@tsv',graph})))do
 local name,version=row:match('^([^\t]+)\t(.+)$');sdks[#sdks+1]={name=name,version=version}
end
local models={
 {name='ACE-Step 1.5 XL',license='Apache-2.0',source='Host model inventory; art/workflows/music'},
 {name='Kokoro-82M / hexgrad',license='Apache-2.0',revision=read({'jq','-r','.kokoro.revision','art/comms/audio.json'})},
 {name='Chatterbox / Resemble AI',license='MIT',revision=read({'jq','-r','.chatterbox.revision','art/comms/audio.json'})},
 {name='SDXL-Lightning / ByteDance',license='OpenRAIL++',source='Beach concept provenance'},
 {name='SDXL Base 1.0',license='OpenRAIL++',source='Project asset provenance register'},
 {name='Pixel Art XL / nerijs',license='CreativeML OpenRAIL-M',source='Beach concept provenance'},
 {name='Qwen Image Edit / Comfy-Org',license='Apache-2.0',source='Beach refinement provenance'},
 {name='Qwen Image Edit Lightning / lightx2v',license='Apache-2.0',source='Beach refinement provenance'},
}
local result={schema='demon-attack.credits/v1',title='Demon Attack',platform='Tillandsias.org',
 source_url='https://github.com/8007342/demon_attack',source_license='GPLv3 · see source LICENSE',
 sections={
  {title='Created by',degree='creator',entries=authors},
  {title='Built with',degree='direct',entries=sdks},
  {title='Game and app packages',degree='direct',entries=direct_rows},
  {title='Their foundations',degree='indirect',entries=indirect_rows},
  {title='Original art, score and voices',degree='models',entries=models},
  {title='Production tools',degree='tools',entries={{name='ComfyUI studio'},{name='Lua orchestration · Go verification'},{name='Python model adapters · PyTorch · NumPy · SciPy · SoundFile'},{name='FFmpeg · Opus · WebP'}}},
 },
 sources={dependency_graph='flutter pub deps --json',lockfile='pubspec.lock',
  authors_ref='origin/game',authors_commit=read({'git','rev-parse','origin/game'}),
  lockfile_sha256=read({'sha256sum','pubspec.lock'}):match('^(%x+)'),
  model_pins='art/comms/audio.json',asset_provenance='plan/asset-provenance.md',
  beach_provenance='assets/research/battle-metal-radio/ending/beach-qwen-v1.provenance.json'},
 note='All game artwork, performances and musical themes are original project work. Package notices are available through the bundled license registry.'}
local file=assert(io.open('assets/credits.json','w'));file:write(json(result),'\n');file:close()
print('credits: '..#authors..' contributor name(s), '..#direct_rows..' direct packages, '..#indirect_rows..' runtime foundations, '..#models..' model credits')
