#!/usr/bin/env lua
-- brood.lua: the brood choir's sources (openspec/changes/demon-choir design §3, §4). Pure Lua 5.4 + ffmpeg.
--
-- Run from the repo root:
--   lua tools/brood_choir/brood.lua render [--src DIR]   render the formant-synth choir zones (vowel x pitch) from
--                                                       art/music/choir/brood.json into DIR/local/brood-synth/
--   lua tools/brood_choir/brood.lua cut [--raw DIR] [--src DIR]
--                                                       cut the picked ACE-Step takes (brood.json `picks`) from the
--                                                       raw FLACs in --raw into DIR/local/acestep-picks/
--   lua tools/brood_choir/brood.lua manifest [--src DIR] write art/music/bank/choir.manifest.tsv (size and git blob
--                                                       sha1 of every source) for tools/bank/bank_build.lua
--   lua tools/brood_choir/brood.lua all                 render, cut, manifest
-- Defaults: --src ~/.cache/tillandsias-project/demon-choir/src, --raw ~/.cache/tillandsias-project/demon-choir/raw.
--
-- The synth (a Klatt-style cascade formant synthesizer driven by an ensemble of Rosenberg glottal pulses):
-- - every voice of the ensemble has its own detune, vibrato (rate, depth, phase, onset), slow jitter and per-period
--   shimmer, from one seeded LCG, so the same recipe gives the same bytes;
-- - the "demon" colour is period doubling: alternate glottal periods are shortened/lengthened by `growl.period`
--   and attenuated by `growl.amp`, which puts energy at f0/2 (the false-fold growl of kargyraa and death-metal
--   vocals) without changing the sung note;
-- - the voices are split in two formant groups (two vocal-tract lengths) and pass a 5-formant cascade of two-pole
--   resonators (vowel table in brood.json); aspiration noise rides the open phase;
-- - rendered at 2x the output rate and decimated through a windowed-sinc low-pass, then written as 32-bit float
--   mono WAV at a -3 dBFS peak. The bank builder trims, loops and normalises per instrument.
local here = arg[0]:match('^(.*)/[^/]*$') or '.'
package.path = here .. '/../score/?.lua;' .. package.path
local json = require 'json'

local cmd = arg[1] or 'all'
local opts = {}
do
  local i = 2
  while i <= #arg do
    if arg[i]:match('^%-%-') and arg[i + 1] then opts[arg[i]:sub(3)] = arg[i + 1]; i = i + 2
    else io.stderr:write('unknown argument ' .. arg[i] .. '\n'); os.exit(2) end
  end
end
local home = os.getenv('HOME') or '.'
local src = opts.src or (home .. '/.cache/tillandsias-project/demon-choir/src')
local raw = opts.raw or (home .. '/.cache/tillandsias-project/demon-choir/raw')
local recipePath = opts.recipe or 'art/music/choir/brood.json'
local function read(path) local f = assert(io.open(path, 'rb')); local s = f:read('a'); f:close(); return s end
local recipe = json.decode(read(recipePath))
local function q(s) return "'" .. tostring(s):gsub("'", "'\\''") .. "'" end
local function say(...) io.stderr:write(string.format(...) .. '\n') end
local function sh(c) local p = assert(io.popen(c, 'r')); local out = p:read('a'); local ok = p:close(); return out, ok end

-- --- deterministic noise: Park-Miller LCG ------------------------------------------------------------------------
local function rng(seed)
  local s = seed % 2147483646 + 1
  return function() s = (s * 16807) % 2147483647; return s / 2147483647 end
end

-- --- WAV (IEEE float 32, mono) ------------------------------------------------------------------------------------
local function writeWav(path, samples, rate)
  local n = #samples
  local parts = {}
  for k = 1, n, 512 do
    local m = math.min(512, n - k + 1)
    parts[#parts + 1] = string.pack('<' .. ('f'):rep(m), table.unpack(samples, k, k + m - 1))
  end
  local data = table.concat(parts)
  local header = 'RIFF' .. string.pack('<I4', 36 + #data) .. 'WAVE' .. 'fmt ' ..
    string.pack('<I4I2I2I4I4I2I2', 16, 3, 1, rate, rate * 4, 4, 32) .. 'data' .. string.pack('<I4', #data)
  local f = assert(io.open(path, 'wb')); f:write(header, data); f:close()
end

local function hz(midi) return 440 * 2 ^ ((midi - 69) / 12) end

-- Rosenberg glottal flow (opening tp, closing tn, as fractions of the period); the source is its derivative.
local function flow(phi, tp, tn)
  if phi < tp then return 0.5 * (1 - math.cos(math.pi * phi / tp)) end
  if phi < tp + tn then return math.cos(0.5 * math.pi * (phi - tp) / tn) end
  return 0
end

-- One zone: an ensemble singing `vowel` at MIDI `note` for `seconds`.
local function renderZone(z, synth)
  local out = recipe.rate
  local rate = out * 2
  local T = 1 / rate
  local n = math.floor(synth.seconds * rate + 0.5)
  local vowel = assert(synth.vowels[z.vowel], 'unknown vowel ' .. z.vowel)
  local growl = synth.growl[z.vowel] or synth.growl.default
  local rand = rng(z.seed)
  local f0 = hz(z.note)
  -- The ensemble.
  local voices = {}
  for v = 1, synth.voices do
    local cents = (rand() * 2 - 1) * synth.detuneCents
    voices[v] = {
      f = f0 * 2 ^ (cents / 1200), phase = rand(), period = 0, group = (v % 2) + 1,
      vibRate = synth.vibrato.rate[1] + rand() * (synth.vibrato.rate[2] - synth.vibrato.rate[1]),
      vibDepth = synth.vibrato.cents[1] + rand() * (synth.vibrato.cents[2] - synth.vibrato.cents[1]),
      vibPhase = rand() * 2 * math.pi, onset = rand() * synth.onsetSpread,
      jitter = 0, jitterTarget = 0, amp = 1, prev = 0, gain = 0.8 + 0.4 * rand(),
    }
  end
  -- Two formant groups (vocal-tract lengths), each a cascade of two-pole resonators.
  local groups = {}
  for g = 1, 2 do
    local scale = synth.tractScale[g]
    local res = {}
    for i, F in ipairs(vowel.f) do
      local fr, bw = F * scale, vowel.bw[i]
      local C = -math.exp(-2 * math.pi * bw * T)
      local B = 2 * math.exp(-math.pi * bw * T) * math.cos(2 * math.pi * fr * T)
      res[i] = { a = 1 - B - C, b = B, c = C, y1 = 0, y2 = 0 }
    end
    groups[g] = { res = res, input = 0 }
  end
  local attack, release = synth.attack, synth.release
  local samples = {}
  local jitterStep = math.floor(rate / synth.jitter.rateHz)
  for i = 0, n - 1 do
    local t = i * T
    groups[1].input, groups[2].input = 0, 0
    for _, v in ipairs(voices) do
      local tt = t - v.onset
      if tt >= 0 then
        if i % jitterStep == 0 then v.jitterTarget = (rand() * 2 - 1) * synth.jitter.cents end
        v.jitter = v.jitter + (v.jitterTarget - v.jitter) * 0.002
        local vib = v.vibDepth * math.min(1, tt / synth.vibrato.fadeIn) * math.sin(2 * math.pi * v.vibRate * tt + v.vibPhase)
        local f = v.f * 2 ^ ((vib + v.jitter) / 1200)
        -- Period doubling: odd periods run long, even short; odd periods are quieter.
        local odd = v.period % 2 == 1
        local stretch = odd and (1 + growl.period) or (1 - growl.period)
        v.phase = v.phase + f * T / stretch
        if v.phase >= 1 then
          v.phase = v.phase - 1
          v.period = v.period + 1
          v.amp = (1 + (rand() * 2 - 1) * synth.shimmer) * ((v.period % 2 == 1) and (1 - growl.amp) or 1)
        end
        local g = flow(v.phase, synth.glottis.open, synth.glottis.close)
        local d = (g - v.prev) * rate / f   -- the flow derivative, normalised per period
        v.prev = g
        local env = math.min(1, tt / attack)
        local breath = (rand() * 2 - 1) * synth.breath * g
        local s = (d + breath) * v.amp * env * v.gain
        local grp = groups[v.group]
        grp.input = grp.input + s
      end
    end
    local sum = 0
    for _, grp in ipairs(groups) do
      local x = grp.input
      for _, r in ipairs(grp.res) do
        local y = r.a * x + r.b * r.y1 + r.c * r.y2
        r.y2, r.y1 = r.y1, y
        x = y
      end
      sum = sum + x
    end
    local tail = synth.seconds - t
    if tail < release then sum = sum * tail / release end
    samples[i + 1] = sum
  end
  -- Decimate by 2 through a 95-tap windowed-sinc low-pass at 0.42 of the output rate.
  local taps, fc, h, hs = 95, 0.42 * out / rate, {}, 0
  for k = 0, taps - 1 do
    local m = k - (taps - 1) / 2
    local v = (m == 0 and 2 * fc or math.sin(2 * math.pi * fc * m) / (math.pi * m)) * (0.42 - 0.5 * math.cos(2 * math.pi * k / (taps - 1)) + 0.08 * math.cos(4 * math.pi * k / (taps - 1)))
    h[k + 1] = v; hs = hs + v
  end
  for k = 1, taps do h[k] = h[k] / hs end
  local half, outS, peak, dc = (taps - 1) // 2, {}, 0, 0
  for j = 0, n // 2 - 1 do
    local c, acc = 2 * j + 1, 0
    for k = 1, taps do
      local s = samples[c + k - 1 - half]
      if s then acc = acc + h[k] * s end
    end
    outS[j + 1] = acc
    dc = dc + acc
  end
  dc = dc / #outS
  -- Presence: a first-order high shelf (x + k (x - lowpass(x))) restores the 2-4 kHz energy the all-pole cascade
  -- rolls off (the "singer's formant" region), so the ensemble does not sound behind a wall.
  local shelf = synth.presence
  local a1 = math.exp(-2 * math.pi * shelf.hz / out)
  local lp = 0
  for j = 1, #outS do
    local x = outS[j] - dc
    lp = (1 - a1) * x + a1 * lp
    outS[j] = x + shelf.gain * (x - lp)
  end
  for j = 1, #outS do local a = math.abs(outS[j]); if a > peak then peak = a end end
  local g = 10 ^ (-3 / 20) / peak
  for j = 1, #outS do outS[j] = outS[j] * g end
  return outS
end

local function render()
  local synth = recipe.synth
  local dir = ('%s/local/brood-synth'):format(src)
  assert(os.execute('mkdir -p ' .. q(dir)))
  for _, z in ipairs(synth.zones) do
    local name = ('brood_%s_%s.wav'):format(z.vowel, z.name)
    local t0 = os.clock()
    writeWav(dir .. '/' .. name, renderZone(z, synth), recipe.rate)
    say('rendered %s (%.1f s cpu)', name, os.clock() - t0)
  end
end

local function cut()
  local dir = ('%s/local/acestep-picks'):format(src)
  assert(os.execute('mkdir -p ' .. q(dir)))
  for _, p in ipairs(recipe.picks) do
    local input = ('%s/%s'):format(raw, p.take)
    local f = io.open(input, 'rb')
    if not f then say('missing raw take %s: skipped (the ACE-Step picks need the raws, see the run ledger)', input) else
      f:close()
      local fadeOut = p.fadeOut or 0.06
      -- `highpass` (Hz) removes the low drone some takes keep under the shouts.
      local af = ('atrim=start=%.3f:end=%.3f,asetpts=PTS-STARTPTS,%safade=t=in:d=0.004,afade=t=out:st=%.3f:d=%.3f')
        :format(p.start, p['end'], p.highpass and ('highpass=f=%d:poles=2,highpass=f=%d:poles=2,'):format(p.highpass, p.highpass) or '',
          p['end'] - p.start - fadeOut, fadeOut)
      local out = ('%s/%s.wav'):format(dir, p.name)
      local c = ('ffmpeg -v error -nostdin -y -i %s -af %s -ac 1 -ar %d -c:a pcm_f32le -map_metadata -1 -fflags +bitexact -flags:a +bitexact %s')
        :format(q(input), q(af), recipe.rate, q(out))
      if not os.execute(c) then error('ffmpeg could not cut ' .. p.name) end
      say('cut %s from %s %.2f-%.2f s', p.name, p.take, p.start, p['end'])
    end
  end
end

local function manifest()
  local rows = { 'repo\tcommit\tgroup\tpath\tbytes\tgit_blob_sha1\traw_url' }
  local function add(repo, group, path)
    local file = ('%s/%s/%s'):format(src, repo, path)
    local f = io.open(file, 'rb')
    if not f then say('missing %s: not in the manifest', file); return end
    local bytes = f:seek('end'); f:close()
    local blob = sh('git hash-object --no-filters ' .. q(file)):match('^(%x+)')
    rows[#rows + 1] = table.concat({ repo, recipe.commit or '-', group, path, tostring(bytes), blob, '' }, '\t')
  end
  for _, z in ipairs(recipe.synth.zones) do add('local/brood-synth', 'brood', ('brood_%s_%s.wav'):format(z.vowel, z.name)) end
  for _, p in ipairs(recipe.picks) do add('local/acestep-picks', p.group, p.name .. '.wav') end
  local path = opts.manifest or 'art/music/bank/choir.manifest.tsv'
  local f = assert(io.open(path, 'wb')); f:write(table.concat(rows, '\n'), '\n'); f:close()
  say('wrote %s (%d rows)', path, #rows - 1)
end

if cmd == 'render' then render()
elseif cmd == 'cut' then cut()
elseif cmd == 'manifest' then manifest()
elseif cmd == 'all' then render(); cut(); manifest()
else io.stderr:write('usage: lua tools/brood_choir/brood.lua render|cut|manifest|all [--src DIR] [--raw DIR]\n'); os.exit(2) end
