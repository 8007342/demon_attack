-- L3 Ember Moon pilot: write the DRY real-instrument render workflow (ComfyUI API format).
--
-- One source of truth: TillandsiasLoadMIDI reads full.mid once (bound as $midi, a copy under
-- /work/tmp/imagegen/), TillandsiasMIDITransform(channel = N) splits each part out, and
-- TillandsiasSFZRender renders it. Every stem is saved, and a chain of four-input
-- TillandsiasAudioMixBus nodes sums them into one dry mix. Node signatures are from
-- tillandsias#1103 (audio studio batch 1, not yet live).
--
-- Dry means no pan, saturation, EQ, bus compression or loudness yet: those nodes come in
-- once their inputs are confirmed against the live studio's object_info. This pass checks
-- sample choice, timing and balance.
--
-- Run: lua tools/production/l3_pilot_workflow.lua [score.json] [out.json]

local score_path = arg[1] or 'art/music/scores/l3-ember-moon/score.json'
local out_path = arg[2] or 'art/workflows/music/l3-ember-moon-dry.json'

-- Part -> SFZ library (CC0, admitted in #1103) and dry gain in dB. `sfz` is the path the
-- SFZRender instrument list shows; nil until the live studio lists the files, emitted as
-- "TBD:<library>" so a queue attempt is refused rather than rendered with a wrong patch.
local PARTS = {
  {part = 'drums',      lib = 'karoryfer-big-rusty-drums', gain = 0},
  {part = 'bass',       lib = 'karoryfer-meatbass',        gain = -2},
  {part = 'gtrL',       lib = 'karoryfer-black-and-green', gain = -4},
  {part = 'gtrL-pm',    lib = 'karoryfer-black-and-green', gain = -5},
  {part = 'gtrR',       lib = 'karoryfer-shiny',           gain = -4},
  {part = 'gtrR-pm',    lib = 'karoryfer-shiny',           gain = -5},
  {part = 'lead',       lib = 'karoryfer-black-and-green', gain = -3},
  {part = 'lead2',      lib = 'karoryfer-black-and-green', gain = -6},
  {part = 'lead-clean', lib = 'karoryfer-shiny',           gain = -4},
  {part = 'clean',      lib = 'karoryfer-shiny',           gain = -8},
  {part = 'choir',      lib = 'vcsl',                      gain = -8},
  {part = 'organ',      lib = 'vcsl',                      gain = -10},
  {part = 'brass',      lib = 'vcsl',                      gain = -7},
  {part = 'strings',    lib = 'vcsl',                      gain = -10},
  {part = 'timpani',    lib = 'vcsl',                      gain = -6},
}
local SFZ = {}  -- part -> 'models/<lib>/...sfz', filled once studio_models lists them

-- Channels come from score.json (1-based there; MIDITransform takes 0-15).
local f = assert(io.open(score_path))
local score = f:read('a'); f:close()
local channel = {}
for part, ch in score:gmatch('"part": "([^"]+)",%s*"channel": (%d+)') do channel[part] = tonumber(ch) - 1 end
for _, p in ipairs(PARTS) do assert(channel[p.part], 'part missing from score.json: ' .. p.part) end
local bars = tonumber(score:match('"bars": (%d+)'))
local seconds = tonumber(score:match('"seconds": ([%d.]+)'))
assert(bars == 96 and seconds, 'unexpected score.json')

-- Minimal deterministic JSON encoder (sorted keys, ids in numeric order).
local function enc(v, ind)
  ind = ind or ''
  local t = type(v)
  if t == 'string' then return (string.format('%q', v):gsub('\\\n', '\\n')) end
  if t == 'number' then
    if math.type(v) == 'integer' then return tostring(v) end
    return (string.format('%.6g', v):find('[.e]') and string.format('%.6g', v)) or string.format('%.1f', v)
  end
  if t == 'boolean' then return tostring(v) end
  if v[1] ~= nil or next(v) == nil then
    local out = {}
    for _, x in ipairs(v) do out[#out + 1] = enc(x, ind) end
    return '[' .. table.concat(out, ', ') .. ']'
  end
  local keys = {}
  for k in pairs(v) do keys[#keys + 1] = k end
  table.sort(keys, function(a, b)
    local na, nb = tonumber(a), tonumber(b)
    if na and nb then return na < nb end
    return tostring(a) < tostring(b)
  end)
  local inner, out = ind .. '  ', {}
  for _, k in ipairs(keys) do out[#out + 1] = inner .. enc(tostring(k)) .. ': ' .. enc(v[k], inner) end
  return '{\n' .. table.concat(out, ',\n') .. '\n' .. ind .. '}'
end

local graph, id = {}, 0
local function node(class, title, inputs)
  id = id + 1
  graph[tostring(id)] = {class_type = class, _meta = {title = title}, inputs = inputs}
  return tostring(id)
end

local midi = node('TillandsiasLoadMIDI', 'L3 Ember Moon full.mid (art/music/scores/l3-ember-moon)', {midi_file = '$midi'})
local unresolved, stems = {}, {}
for _, p in ipairs(PARTS) do
  local ch = channel[p.part]
  local split = node('TillandsiasMIDITransform', p.part .. ': channel ' .. ch, {
    midi = {midi, 0}, transpose = 0, velocity_scale = 1.0, time_scale = 1.0, quantize_s = 0.0,
    channel = ch, min_key = 0, max_key = 127})
  local sfz = SFZ[p.part]
  if not sfz then sfz = 'TBD:' .. p.lib; unresolved[#unresolved + 1] = p.part .. ' (' .. p.lib .. ')' end
  local render = node('TillandsiasSFZRender', p.part .. ': ' .. p.lib, {
    midi = {split, 0}, instrument = sfz, sample_rate = 48000, tail_s = 2.0, gain_db = 0.0, seed = 0})
  node('TillandsiasSaveLoopWAV', p.part .. ': dry stem', {
    audio = {render, 0}, filename_prefix = 'music/l3-ember-moon-dry/' .. p.part,
    loop_start_s = 0.0, loop_end_s = -1.0, bits = 24})
  stems[#stems + 1] = {render, p.gain}
end

-- Sum through four-input buses until one remains.
local level = stems
local depth = 0
while #level > 1 do
  depth = depth + 1
  local nxt = {}
  for i = 1, #level, 4 do
    local inputs = {}
    for j, slot in ipairs({'a', 'b', 'c', 'd'}) do
      local s = level[i + j - 1]
      if s then inputs[slot] = {s[1], 0}; inputs['gain_' .. slot .. '_db'] = s[2] + 0.0 end
    end
    nxt[#nxt + 1] = {node('TillandsiasAudioMixBus', ('bus %d.%d'):format(depth, (i + 3) // 4), inputs), 0}
  end
  level = nxt
end
node('TillandsiasSaveLoopWAV', ('dry mix: %d bars, %.3f s + 2 s tail'):format(bars, seconds), {
  audio = {level[1][1], 0}, filename_prefix = 'music/l3-ember-moon-dry/mix',
  loop_start_s = 0.0, loop_end_s = -1.0, bits = 24})

local o = assert(io.open(out_path, 'w'))
o:write(enc(graph), '\n'); o:close()
print(('%s: %d nodes, %d parts'):format(out_path, id, #PARTS))
if #unresolved > 0 then
  print('SFZ paths still TBD (fill SFZ{} from studio_models once #1103 is live): ' .. table.concat(unresolved, ', '))
end
