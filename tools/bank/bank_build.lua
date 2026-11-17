#!/usr/bin/env lua
-- bank_build.lua: builds the CC0 sample bank of the MIDI-first score (adaptive-soundtrack design §11.4, §12.9;
-- task 8.5) from the pinned sources: web/audio/bank/bank.json plus one Opus sprite per load tier.
--
-- Run from the repo root (Lua 5.4 + ffmpeg with libopus + git; wrap a real build in `forge-guard run --`):
--   lua tools/bank/bank_build.lua --dry-run [--json]   plan the zones and estimate the bytes from the manifest and
--                                                     the trims (no audio, no network)
--   lua tools/bank/bank_build.lua --fetch-maps         fetch the pinned SFZ maps only (each < 100 KB) into --src
--   lua tools/bank/bank_build.lua --sync-keys          write art/music/bank/sfz-keys.json from the maps in --src
--   lua tools/bank/bank_build.lua [--src DIR]          build: verify every source, cut, check, encode, write
--   lua tools/bank/bank_build.lua --fetch [--src DIR]  ONLY once the Tillandsias register has admitted the pins:
--                                                     fetch the manifest's files that --src lacks, then build
-- Options: --recipe FILE (art/music/bank/recipe.json), --manifest FILE (the recipe's), --keys FILE|none (the
-- recipe's), --src DIR (~/.cache/tillandsias-project/sample-bank/src, laid out as <owner>/<repo>/<path>),
-- --out DIR (the recipe's, web/audio/bank), --with ID (build an optional instrument, e.g. strings), --tmp DIR (scratch,
-- default ~/.cache/tillandsias-project/tmp/bank-build-*).
--
-- The build refuses (exit 1, nothing written) when a source is missing, its size or git blob sha1 differs from the
-- manifest, an f0 check of a `strict` instrument disagrees with its root by more than 0.6 semitone (a whole-octave
-- disagreement shared by the instrument is corrected and logged), or a budget is exceeded (≤ 2 MB Opus, ≤ 41 MB
-- decoded, ≤ 16 MB decoded for the phone tier). Each zone: leading silence below -60 dB removed, trimmed to the
-- recipe's seconds, normalised per instrument to -1 dBFS peak (so velocity layers keep their dynamics), a 20 ms fade
-- (or an equal-power loop crossfade for looped sustains), packed with 50 ms gaps into its tier's sprite at 48 kHz,
-- encoded Opus (64 kbps mono, 96 kbps stereo) in Ogg with bit-exact flags. Same sources, same ffmpeg: same bytes.
local here = arg[0]:match('^(.*)/[^/]*$') or '.'
package.path = here .. '/?.lua;' .. package.path
local B = require 'bank'
local json = B.json

local opts = { with = {} }
do
  local i = 1
  while i <= #arg do
    local a = arg[i]
    if a == '--dry-run' or a == '--json' or a == '--sync-keys' or a == '--fetch' or a == '--fetch-maps' then opts[a:sub(3)] = true; i = i + 1
    elseif a == '--with' then opts.with[arg[i + 1]] = true; i = i + 2
    elseif a:match('^%-%-') and arg[i + 1] then opts[a:sub(3)] = arg[i + 1]; i = i + 2
    else io.stderr:write('unknown argument ' .. a .. '\n'); os.exit(2) end
  end
end
local home = os.getenv('HOME') or '.'
local recipePath = opts.recipe or 'art/music/bank/recipe.json'
local recipe, rows, keys = B.load(recipePath, opts.manifest, opts.keys)
local src = opts.src or (home .. '/.cache/tillandsias-project/sample-bank/src')
local outDir = opts.out or recipe.out
local function q(s) return "'" .. tostring(s):gsub("'", "'\\''") .. "'" end
local function sh(cmd) local p = assert(io.popen(cmd, 'r')); local out = p:read('a'); local ok = p:close(); return out, ok end
local function say(...) io.stderr:write(string.format(...) .. '\n') end
local function die(...) say(...); os.exit(1) end
local function fileOf(row) return ('%s/%s/%s'):format(src, row.repo, row.path) end
local function exists(path) local f = io.open(path, 'rb'); if f then f:close(); return true end; return false end
local function size(path) local f = io.open(path, 'rb'); if not f then return nil end; local n = f:seek('end'); f:close(); return n end
local function blob(path) local out = sh('git hash-object --no-filters ' .. q(path)); return out:match('^(%x+)') end
local function sha256(path) local out = sh('sha256sum ' .. q(path)); return out:match('^(%x+)') end

-- Verifies one manifest row's file: present, its size and git blob sha1 as pinned. Returns nil or the reason.
local function verify(row)
  local path = fileOf(row)
  if not exists(path) then return 'missing ' .. path end
  if row.bytes and size(path) ~= row.bytes then return ('size %d, pinned %d: %s'):format(size(path), row.bytes, path) end
  local b = blob(path)
  if b ~= row.git_blob_sha1 then return ('git blob sha1 %s, pinned %s: %s'):format(tostring(b), row.git_blob_sha1, path) end
  return nil
end

local function fetch(row)
  local path = fileOf(row)
  if exists(path) and not verify(row) then return end
  os.execute('mkdir -p ' .. q(path:match('^(.*)/[^/]*$')))
  local tmp = path .. '.part'
  local ok = os.execute(('curl -sSfL --max-time 120 -o %s %s'):format(q(tmp), q(row.raw_url)))
  if not ok then os.remove(tmp); die('fetch failed: %s', row.raw_url) end
  os.rename(tmp, path)
  local bad = verify(row)
  if bad then os.remove(path); die('refused: %s', bad) end
  say('fetched %s/%s', row.repo, row.path)
end

-- --- the SFZ maps: fetch (only rows ending in .sfz), then sync their keycenters ---------------------------------
if opts['fetch-maps'] then
  for _, row in ipairs(rows) do if row.path:match('%.sfz$') then fetch(row) end end
end
if opts['sync-keys'] then
  local maps, record = {}, {}
  for _, row in ipairs(rows) do
    if row.path:match('%.sfz$') then
      local bad = verify(row)
      if bad then die('refused map: %s', bad) end
      maps[#maps + 1] = { repo = row.repo, path = row.path, text = assert(B.read(fileOf(row))) }
      record[row.repo .. '/' .. row.path] = row.git_blob_sha1
    end
  end
  local k, errors = B.keysFromMaps(rows, maps)
  if #errors > 0 then die('map conflicts:\n  %s', table.concat(errors, '\n  ')) end
  local text = json.encode({ comment = 'GENERATED by lua tools/bank/bank_build.lua --sync-keys from the pinned SFZ maps (plan/sample-bank-pins.manifest.tsv); do not edit. keys[repo][path] = the pitch_keycenter and the widest lokey/hikey of the regions that play that file.',
    maps = record, keys = k }, { indent = ' ' }) .. '\n'
  local path = opts.keys or recipe.keys
  local f = assert(io.open(path, 'wb')); f:write(text); f:close()
  say('wrote %s (%d maps)', path, #maps)
  os.exit(0)
end
if opts['fetch-maps'] then os.exit(0) end

local plan, errors = B.plan(recipe, rows, keys, { with = opts.with })
if #errors > 0 then die('the plan has errors:\n  %s', table.concat(errors, '\n  ')) end

local function report(totals, over, measured)
  local word = measured and 'measured' or 'estimated'
  say('%d zones in %d sprites, %.1f s of audio (%s)', totals.zones, #plan.sprites, totals.seconds, word)
  for _, s in ipairs(plan.sprites) do
    say('  %-16s tier %d %-7s %d ch %3d zones %6.1f s  %8d B Opus  %9d B decoded', s.file, s.tier, s.phone and 'phone' or 'desktop',
      s.channels, #s.zones, s.seconds, s.bytes or s.estOpusBytes, s.decodedBytes)
  end
  say('Opus %d B (budget %d), decoded %d B desktop (budget %d), %d B phone tier (budget %d); sources %d B raw',
    totals.opusBytes, recipe.budgets.opusBytes, totals.decodedDesktop, recipe.budgets.decodedDesktop, totals.decodedPhone,
    recipe.budgets.decodedPhone, totals.rawBytes)
  for _, o in ipairs(over) do say('OVER: %s', o) end
end

-- --- dry run: the plan and its estimate from the trims --------------------------------------------------------
if opts['dry-run'] then
  local totals, over = B.estimate(recipe, plan, function(z) return z.trim end)
  report(totals, over, false)
  if opts.json then
    io.write(json.encode({ schema = 'demon-attack.bank-plan/v1', roles = recipe.roles, instruments = plan.instruments,
      sprites = plan.sprites, zones = plan.zones, totals = totals, over = over }, { indent = ' ' }), '\n')
  end
  os.exit(#over > 0 and 1 or 0)
end

-- --- build ------------------------------------------------------------------------------------------------------
if opts.fetch then for _, z in ipairs(plan.zones) do fetch({ repo = z.source.repo, path = z.source.path, bytes = z.source.bytes,
  git_blob_sha1 = z.source.blob, raw_url = (function() for _, r in ipairs(rows) do if r.repo == z.source.repo and r.path == z.source.path then return r.raw_url end end end)() }) end end
do
  local bad = {}
  for _, z in ipairs(plan.zones) do
    local reason = verify({ repo = z.source.repo, path = z.source.path, bytes = z.source.bytes, git_blob_sha1 = z.source.blob })
    if reason then bad[#bad + 1] = reason end
  end
  if #bad > 0 then die('refused: %d source(s) do not match the pins:\n  %s', #bad, table.concat(bad, '\n  ')) end
end

local rate = recipe.rate
-- Decoded PCM: a flat list of floats, interleaved by channel.
local function decode(z)
  local filters = ('silenceremove=start_periods=1:start_threshold=-60dB,atrim=end=%.4f'):format(z.trim)
  local cmd = ('ffmpeg -v error -nostdin -i %s -af %s -ac %d -ar %d -f f32le -'):format(q(fileOf({ repo = z.source.repo, path = z.source.path })), q(filters), z.channels, rate)
  local bytes, ok = sh(cmd)
  if not ok or #bytes < 4 * z.channels then die('ffmpeg could not decode %s', z.source.path) end
  local pcm, n, pos, batch = {}, #bytes // 4, 1, 64
  local fmt = '<' .. ('f'):rep(batch)
  local full = n - n % batch
  while #pcm < full do
    local values = { string.unpack(fmt, bytes, pos) }
    pos = values[batch + 1]
    for i = 1, batch do pcm[#pcm + 1] = values[i] end
  end
  while #pcm < n do local v; v, pos = string.unpack('<f', bytes, pos); pcm[#pcm + 1] = v end
  return pcm
end

-- f0 by YIN (de Cheveigné and Kawahara's cumulative mean normalised difference, threshold 0.15) on the mono mix,
-- decimated to 16 kHz, 80 ms after the onset; 25 Hz to 2 kHz. Returns Hz or nil.
local function f0(pcm, channels)
  local x, step = {}, 3 * channels
  for i = 1, #pcm - step + 1, step do
    local s = 0
    for j = 0, step - 1 do s = s + pcm[i + j] end
    x[#x + 1] = s / step
  end
  local sr, W, minLag, maxLag = rate / 3, 1400, 8, 640
  local start = math.floor(0.08 * sr)
  if #x < start + W + maxLag then start = math.max(0, #x - W - maxLag) end
  if #x < W + maxLag then return nil end
  local d, cum = {}, 0
  for tau = 1, maxLag do
    local s = 0
    for j = start + 1, start + W do local e = x[j] - x[j + tau]; s = s + e * e end
    cum = cum + s
    d[tau] = cum > 0 and s * tau / cum or 1
  end
  for tau = minLag, maxLag - 1 do
    if d[tau] < 0.15 then
      while tau + 1 < maxLag and d[tau + 1] < d[tau] do tau = tau + 1 end
      local a, b, c = d[tau - 1], d[tau], d[tau + 1]
      local den = a - 2 * b + c
      local shift = den ~= 0 and 0.5 * (a - c) / den or 0
      return sr / (tau + shift)
    end
  end
  return nil
end
local function midiOf(hz) return 69 + 12 * math.log(hz / 440, 2) end

local byInst, instOrder = {}, {}
for _, z in ipairs(plan.zones) do
  if not byInst[z.inst] then byInst[z.inst] = {}; instOrder[#instOrder + 1] = z.inst end
  table.insert(byInst[z.inst], z)
end
local recipeInst = {}
for _, inst in ipairs(recipe.instruments) do recipeInst[inst.id] = inst end

local refusals, notes = {}, {}
local fade = math.floor(recipe.fadeSeconds * rate + 0.5)
for _, id in ipairs(instOrder) do
  local inst, list = recipeInst[id], byInst[id]
  local peak = 0
  for _, z in ipairs(list) do
    local pcm = decode(z)
    for i = 1, #pcm do local a = math.abs(pcm[i]); if a > peak then peak = a end end
    z.pcm = pcm
  end
  -- f0: one estimate per distinct source note; a shared whole-octave offset is corrected, anything else refused
  -- (strict) or reported.
  if inst.verify and not inst.keys then
    local octaves, checked = {}, 0
    for _, z in ipairs(list) do
      local hz = f0(z.pcm, z.channels)
      z.f0 = hz and math.floor(hz * 100 + 0.5) / 100 or nil
      if hz then
        local diff = midiOf(hz) - z.root
        local k = math.floor(diff / 12 + 0.5)
        local residual = diff - 12 * k
        z.f0Residual = math.floor(residual * 100 + 0.5) / 100
        if math.abs(residual) <= 0.6 then octaves[k] = (octaves[k] or 0) + 1; z.f0Octave = k; checked = checked + 1
        elseif inst.verify == 'strict' then refusals[#refusals + 1] = ('%s %s: f0 %.1f Hz is %.2f semitones off root %d'):format(id, z.file, hz, residual, z.root)
        else notes[#notes + 1] = ('%s %s: f0 %.1f Hz, %.2f semitones off root %d (reported)'):format(id, z.file, hz, residual, z.root) end
      elseif inst.verify == 'strict' then refusals[#refusals + 1] = ('%s %s: no f0 found'):format(id, z.file)
      else notes[#notes + 1] = ('%s %s: no f0 found (reported)'):format(id, z.file) end
    end
    local best, votes = 0, -1
    for k, n in pairs(octaves) do if n > votes or (n == votes and math.abs(k) < math.abs(best)) then best, votes = k, n end end
    for _, z in ipairs(list) do
      if z.f0Octave and z.f0Octave ~= best then
        local msg = ('%s %s: f0 says octave %+d, the instrument %+d'):format(id, z.file, z.f0Octave, best)
        if inst.verify == 'strict' then refusals[#refusals + 1] = msg else notes[#notes + 1] = msg end
      end
    end
    if best ~= 0 then
      notes[#notes + 1] = ('%s: f0 puts every zone %+d semitones from its planned root; corrected'):format(id, 12 * best)
      for _, z in ipairs(list) do z.root, z.lo, z.hi = z.root + 12 * best, z.lo + 12 * best, z.hi + 12 * best; z.rootSource = z.rootSource .. (' %+d by f0'):format(12 * best) end
    end
  end
  -- Normalise the instrument to the recipe's peak; fade the end, or crossfade the loop of a looped sustain.
  local gain = peak > 0 and 10 ^ (recipe.peakDb / 20) / peak or 1
  for _, z in ipairs(list) do
    local pcm, ch = z.pcm, z.channels
    for i = 1, #pcm do pcm[i] = pcm[i] * gain end
    local frames = #pcm // ch
    local L0 = z.loop and math.floor(z.loop.start * rate + 0.5)
    local X = z.loop and math.floor(z.loop.xfade * rate + 0.5)
    if z.loop and L0 >= X and frames > L0 + X then
      for i = 0, X - 1 do
        local a = (i + 0.5) / X
        local wOut, wIn = math.cos(a * math.pi / 2), math.sin(a * math.pi / 2)
        for c = 1, ch do
          local dst, from = (frames - X + i) * ch + c, (L0 - X + i) * ch + c
          pcm[dst] = pcm[dst] * wOut + pcm[from] * wIn
        end
      end
      z.loopFrames = { L0, frames }
    else
      for i = 0, math.min(fade, frames) - 1 do
        local g = i / fade
        for c = 1, ch do local k = (frames - 1 - i) * ch + c; pcm[k] = pcm[k] * g end
      end
    end
    z.frames = frames
    -- Pack now: a Lua number list costs ~16 B a sample, the packed float 4 B.
    local packed = {}
    for k = 1, #pcm, 256 do
      local n = math.min(256, #pcm - k + 1)
      packed[#packed + 1] = string.pack('<' .. ('f'):rep(n), table.unpack(pcm, k, k + n - 1))
    end
    z.bin, z.pcm = table.concat(packed), nil
  end
  collectgarbage()
end
if #refusals > 0 then die('refused: %d f0 check(s) failed:\n  %s', #refusals, table.concat(refusals, '\n  ')) end
for _, n in ipairs(notes) do say('note: %s', n) end

-- Sprites: zones in plan order with gaps; raw f32le to a temp dir, then Opus.
-- Scratch goes under the forge cache (or --tmp), never the checkout or /tmp.
math.randomseed(os.time())
local tmp = opts.tmp or ('%s/.cache/tillandsias-project/tmp/bank-build-%d-%d'):format(home, os.time(), math.random(1e6))
assert(os.execute('mkdir -p ' .. q(tmp)))
local gapFrames = math.floor(recipe.gapSeconds * rate + 0.5)
for _, s in ipairs(plan.sprites) do
  local parts, cursor = {}, 0
  local silence = string.rep('\0', 4 * s.channels * gapFrames)
  for _, i in ipairs(s.zones) do
    local z = plan.zones[i]
    z.offsetFrames = cursor
    parts[#parts + 1] = z.bin
    parts[#parts + 1] = silence
    cursor = cursor + z.frames + gapFrames
    z.bin = nil
  end
  local raw = ('%s/%s.f32'):format(tmp, s.key)
  local f = assert(io.open(raw, 'wb')); f:write(table.concat(parts)); f:close()
  s.frames = cursor
  local kbps = recipe.kbps[tostring(s.channels)]
  local out = ('%s/%s'):format(tmp, s.file)
  local cmd = ('ffmpeg -v error -nostdin -y -f f32le -ar %d -ac %d -i %s -c:a libopus -b:a %dk -vbr on -application audio -frame_duration 20 -map_metadata -1 -fflags +bitexact -flags:a +bitexact %s')
    :format(rate, s.channels, q(raw), kbps, q(out))
  if not os.execute(cmd) then die('ffmpeg could not encode %s', s.file) end
  os.remove(raw)
  s.bytes, s.sha256, s.path = size(out), sha256(out), out
end

local totals, over = B.estimate(recipe, plan, function(z) return z.frames / rate end)
report(totals, over, true)
if #over > 0 then os.execute('rm -rf ' .. q(tmp)); die('refused: over budget') end

-- bank.json: what the sampler (web/audio/demon-score.js) reads.
local sources = {}
for repo, s in pairs(recipe.sources) do sources[repo] = { spdx = s.spdx, licenceBlob = s.licenceBlob, credit = s.credit } end
local zonesOut = {}
for _, z in ipairs(plan.zones) do
  if z.source and sources[z.source.repo] then sources[z.source.repo].commit = z.source.commit end
  local loop = z.loopFrames and { z.loopFrames[1] / rate, z.loopFrames[2] / rate } or nil
  zonesOut[#zonesOut + 1] = { id = z.id, inst = z.inst, art = z.art, sprite = z.sprite, offset = z.offsetFrames / rate,
    length = z.frames / rate, root = z.root, lo = z.lo, hi = z.hi, keys = z.keys, vlo = z.vlo, vhi = z.vhi, rr = z.rr,
    loop = loop, release = z.release, gainDb = z.gainDb, tier = z.tier, phone = z.phone, f0 = z.f0, rootSource = z.rootSource,
    source = { repo = z.source.repo, path = z.source.path, blob = z.source.blob, sha256 = sha256(fileOf({ repo = z.source.repo, path = z.source.path })) } }
end
local spritesOut = {}
for _, s in ipairs(plan.sprites) do
  spritesOut[#spritesOut + 1] = { file = s.file, tier = s.tier, phone = s.phone, channels = s.channels, seconds = s.frames / rate,
    bytes = s.bytes, sha256 = s.sha256, decodedBytes = s.decodedBytes }
end
local bank = { schema = 'demon-attack.bank/v1',
  comment = 'GENERATED by lua tools/bank/bank_build.lua from art/music/bank/recipe.json and the pins in plan/sample-bank-pins.manifest.tsv; do not edit.',
  rate = rate, budgets = recipe.budgets, roles = recipe.roles, instruments = plan.instruments, sprites = spritesOut, zones = zonesOut,
  sources = sources, totals = totals }
os.execute('mkdir -p ' .. q(outDir))
-- Replace the previous build: stale sprites go (one format, no leftovers).
for name in sh('ls ' .. q(outDir) .. ' 2>/dev/null'):gmatch('[^\n]+') do if name:match('^bank%-.*%.ogg$') then os.remove(outDir .. '/' .. name) end end
for _, s in ipairs(plan.sprites) do
  if not os.execute(('mv %s %s'):format(q(s.path), q(outDir .. '/' .. s.file))) then die('cannot write %s', s.file) end
end
local f = assert(io.open(outDir .. '/bank.json', 'wb')); f:write(json.encode(bank, { indent = ' ' }), '\n'); f:close()
os.execute('rm -rf ' .. q(tmp))
say('wrote %s/bank.json and %d sprites', outDir, #plan.sprites)
