-- L3 Ember Moon pilot: write the real-instrument render workflows (ComfyUI API format).
--
-- One source of truth: TillandsiasLoadMIDI reads full.mid once (bound as $midi, a copy under
-- /work/tmp/imagegen/), TillandsiasMIDITransform(channel = N) splits each part out, and
-- TillandsiasSFZRender renders it. Node signatures are from tillandsias#1103 (audio studio
-- batch 1), relayed by the host session.
--
--   l3-ember-moon-dry.json  every part rendered and summed flat: checks samples, timing, balance.
--   l3-ember-moon-mix.json  per-part chains (high-pass, guitar saturation and EQ standing in for
--                           amp/cab until NAM arrives in batch 2, compression, pan), four-input
--                           bus chain, master glue compressor, loudness to -18.5 LUFS, limiter,
--                           and the 96-bar grid in the saved mix's sidecar.
--
-- Run: lua tools/production/l3_pilot_workflow.lua [score.json] [out-dir]

local score_path = arg[1] or 'art/music/scores/l3-ember-moon/score.json'
local out_dir = arg[2] or 'art/workflows/music'

-- Part -> SFZ library id (sfz-libraries.tsv in #1103, all CC0), bus gain (dB), pan, chain.
-- `SFZ` holds the instrument paths (models/<id>/...sfz) as the live studio lists them; until
-- then they are emitted as "TBD:<id>" so a queue attempt is refused, never rendered with a
-- wrong patch.
local PARTS = {
  {part = 'drums',      lib = 'big-rusty-drums',         gain = 0,   pan = 0,     chain = 'drums'},
  {part = 'bass',       lib = 'meatbass',                gain = -2,  pan = 0,     chain = 'bass'},
  {part = 'gtrL',       lib = 'black-and-green-guitars', gain = -4,  pan = -0.9,  chain = 'rhythm'},
  {part = 'gtrL-pm',    lib = 'black-and-green-guitars', gain = -5,  pan = -0.9,  chain = 'rhythm'},
  {part = 'gtrR',       lib = 'shinyguitar',             gain = -4,  pan = 0.9,   chain = 'rhythm'},
  {part = 'gtrR-pm',    lib = 'shinyguitar',             gain = -5,  pan = 0.9,   chain = 'rhythm'},
  {part = 'lead',       lib = 'black-and-green-guitars', gain = -3,  pan = 0.15,  chain = 'lead'},
  {part = 'lead2',      lib = 'black-and-green-guitars', gain = -6,  pan = -0.35, chain = 'lead'},
  {part = 'lead-clean', lib = 'shinyguitar',             gain = -4,  pan = 0,     chain = 'clean'},
  {part = 'clean',      lib = 'shinyguitar',             gain = -8,  pan = -0.4,  chain = 'clean'},
  {part = 'choir',      lib = 'vcsl',                    gain = -8,  pan = 0,     chain = 'orch'},
  {part = 'organ',      lib = 'vcsl',                    gain = -10, pan = -0.25, chain = 'orch'},
  {part = 'brass',      lib = 'vcsl',                    gain = -7,  pan = 0.3,   chain = 'orch'},
  {part = 'strings',    lib = 'vcsl',                    gain = -10, pan = 0.2,   chain = 'orch'},
  {part = 'timpani',    lib = 'vcsl',                    gain = -6,  pan = -0.2,  chain = 'timp'},
}
local SFZ = {}  -- part -> 'models/<id>/...sfz', filled from studio_models after the relaunch

-- Per-part processing for the mix workflow, in order. Each step is {class, inputs}.
local HP = function(hz) return {'TillandsiasAudioEQ', {kind = 'highpass', frequency_hz = hz, q = 0.707, gain_db = 0.0}} end
local PEAK = function(hz, db, q) return {'TillandsiasAudioEQ', {kind = 'peak', frequency_hz = hz, q = q or 1.0, gain_db = db}} end
local LP = function(hz) return {'TillandsiasAudioEQ', {kind = 'lowpass', frequency_hz = hz, q = 0.707, gain_db = 0.0}} end
local SAT = function(db, mix) return {'TillandsiasAudioSaturate', {drive_db = db, mix = mix}} end
local COMP = function(th, ratio, att, rel, makeup)
  return {'TillandsiasAudioCompressor', {threshold_db = th, ratio = ratio, attack_ms = att, release_ms = rel, makeup_db = makeup or 0.0}}
end
local CHAINS = {
  -- Clean DI samples into a high-gain stand-in: tighten the lows, drive hard, scoop the
  -- boxy mids, add presence, and roll off like a 4x12 cab.
  rhythm = {HP(90), SAT(22, 1.0), PEAK(420, -4, 1.2), PEAK(2800, 2.5, 1.0), LP(8500), COMP(-16, 3, 8, 90)},
  lead   = {HP(140), SAT(16, 1.0), PEAK(1500, 2, 0.9), LP(9500), COMP(-18, 3, 12, 140)},
  clean  = {HP(110), SAT(3, 0.3), PEAK(3500, 1.5, 0.8)},
  bass   = {HP(32), SAT(8, 0.45), PEAK(800, 2, 1.0), COMP(-20, 4, 15, 150)},
  drums  = {HP(28), COMP(-14, 3, 10, 120), PEAK(4500, 1.5, 0.8)},
  orch   = {HP(150), PEAK(350, -2, 1.0)},  -- leave the low mids to the guitars and bass
  timp   = {HP(45), COMP(-16, 2.5, 15, 200)},
}
local MASTER = {
  COMP(-12, 2, 30, 150),
  {'TillandsiasAudioNormalizeLoudness', {target_lufs = -18.5, ceiling_db = -1.5}},
  {'TillandsiasAudioLimiter', {ceiling_db = -1.0, lookahead_ms = 5.0}},
}

-- Channels and grid from score.json (channels are 1-based there; MIDITransform takes 0-15).
local f = assert(io.open(score_path))
local score = f:read('a'); f:close()
local channel = {}
for part, ch in score:gmatch('"part": "([^"]+)",%s*"channel": (%d+)') do channel[part] = tonumber(ch) - 1 end
for _, p in ipairs(PARTS) do assert(channel[p.part], 'part missing from score.json: ' .. p.part) end
local bars = tonumber(score:match('"bars": (%d+)'))
local seconds = tonumber(score:match('"seconds": ([%d.]+)'))
local bpm = tonumber(score:match('"bpm": ([%d.]+)'))
local sr = tonumber(score:match('"sample_rate": (%d+)'))
assert(bars == 96 and seconds and bpm and sr, 'unexpected score.json')

-- Minimal deterministic JSON encoder (sorted keys, node ids in numeric order).
local function num(v)
  if math.type(v) == 'integer' then return tostring(v) end
  local s = string.format('%.6g', v)
  return s:find('[.e]') and s or s .. '.0'
end
local function enc(v, ind)
  ind = ind or ''
  local t = type(v)
  if t == 'string' then return (string.format('%q', v):gsub('\\\n', '\\n')) end
  if t == 'number' then return num(v) end
  if t == 'boolean' then return tostring(v) end
  if v[1] ~= nil then
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

local function build(mode)
  local graph, id = {}, 0
  local function node(class, title, inputs)
    id = id + 1
    graph[tostring(id)] = {class_type = class, _meta = {title = title}, inputs = inputs}
    return tostring(id)
  end
  local function step(src, s, title)
    local inputs = {audio = {src, 0}}
    for k, v in pairs(s[2]) do inputs[k] = (math.type(v) == 'integer') and (v + 0.0) or v end
    return node(s[1], title, inputs)
  end
  local prefix = 'music/l3-ember-moon-' .. mode .. '/'
  local midi = node('TillandsiasLoadMIDI', 'L3 Ember Moon full.mid (art/music/scores/l3-ember-moon)', {midi_file = '$midi'})
  local stems = {}
  for _, p in ipairs(PARTS) do
    local ch = channel[p.part]
    local split = node('TillandsiasMIDITransform', p.part .. ': channel ' .. ch, {
      midi = {midi, 0}, transpose = 0, velocity_scale = 1.0, time_scale = 1.0, quantize_s = 0.0,
      channel = ch, min_key = 0, max_key = 127})
    local out = node('TillandsiasSFZRender', p.part .. ': ' .. p.lib, {
      midi = {split, 0}, instrument = SFZ[p.part] or ('TBD:' .. p.lib), sample_rate = sr, tail_s = 2.0,
      gain_db = 0.0, seed = 0})
    if mode == 'mix' then
      for i, s in ipairs(CHAINS[p.chain]) do out = step(out, s, ('%s: %s %d'):format(p.part, p.chain, i)) end
      out = node('TillandsiasAudioPan', p.part .. ': pan', {audio = {out, 0}, position = p.pan + 0.0})
    end
    node('TillandsiasSaveLoopWAV', p.part .. ': ' .. mode .. ' stem', {
      audio = {out, 0}, filename_prefix = prefix .. p.part, loop_start_s = 0.0, loop_end_s = -1.0, bits = 24})
    stems[#stems + 1] = {out, p.gain}
  end
  -- Sum through four-input buses until one remains.
  local level, depth = stems, 0
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
  local mix = level[1][1]
  local save = {audio = {mix, 0}, filename_prefix = prefix .. 'mix', loop_start_s = 0.0, loop_end_s = -1.0, bits = 24}
  if mode == 'mix' then
    for i, s in ipairs(MASTER) do mix = step(mix, s, 'master ' .. i) end
    -- start_bar/end_bar assumed 1-based inclusive; check the grid_json of the first run.
    local grid = node('TillandsiasBarGrid', ('grid: %g BPM, 4/4, %d bars'):format(bpm, bars), {
      bpm = bpm + 0.0, beats_per_bar = 4, beat_unit = 4, bars = bars, sample_rate = sr,
      start_bar = 1, end_bar = bars, offset_s = 0.0})
    save.audio = {mix, 0}
    save.grid_json = {grid, 2}
  end
  node('TillandsiasSaveLoopWAV', ('%s render: %d bars, %.3f s + 2 s tail'):format(mode, bars, seconds), save)
  return graph, id
end

local todo = {}
for _, p in ipairs(PARTS) do if not SFZ[p.part] then todo[#todo + 1] = p.part .. ' (' .. p.lib .. ')' end end
for _, mode in ipairs({'dry', 'mix'}) do
  local graph, n = build(mode)
  local path = ('%s/l3-ember-moon-%s.json'):format(out_dir, mode)
  local o = assert(io.open(path, 'w'))
  o:write(enc(graph), '\n'); o:close()
  print(('%s: %d nodes, %d parts'):format(path, n, #PARTS))
end
if #todo > 0 then
  print('SFZ paths still TBD (fill SFZ{} from studio_models once #1103 is live): ' .. table.concat(todo, ', '))
end
