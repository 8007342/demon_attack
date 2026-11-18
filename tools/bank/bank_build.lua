#!/usr/bin/env lua
-- bank_build.lua: builds the CC0 sample bank of the MIDI-first score (adaptive-soundtrack design §11.4, §12.9;
-- task 8.5) from the pinned sources: web/audio/bank/bank.json plus one Opus sprite per load tier.
--
-- Run from the repo root (Lua 5.4 + ffmpeg with libopus + git; wrap a real build in `forge-guard run --`):
--   lua tools/bank/bank_build.lua --dry-run [--json]   plan the zones and estimate the bytes from the manifest and
--                                                     the trims (no audio, no network)
--   lua tools/bank/bank_build.lua --fetch-maps         fetch the pinned SFZ maps only (each < 100 KB) into --src
--   lua tools/bank/bank_build.lua --sync-keys          write art/music/bank/sfz-keys.json from the maps in --src
--   lua tools/bank/bank_build.lua [--src DIR] [--keep-pcm DIR]  build: verify every source, cut, check, encode, write
--   lua tools/bank/bank_build.lua --f0-report          verify and cut, then print every pitched zone's f0 against its
--                                                     root (the run ledger's table) and stop; nothing is written
--   lua tools/bank/bank_build.lua --fetch [--src DIR]  ONLY once the Tillandsias register has admitted the pins:
--                                                     fetch the manifest's files that --src lacks, then build
-- Options: --recipe FILE (art/music/bank/recipe.json), --manifest FILE (the recipe's), --keys FILE|none (the
-- recipe's), --src DIR (~/.cache/tillandsias-project/sample-bank/src, laid out as <owner>/<repo>/<path>),
-- --out DIR (the recipe's, web/audio/bank), --with ID (build an optional instrument, e.g. strings), --tmp DIR (scratch,
-- default ~/.cache/tillandsias-project/tmp/bank-build-*).
--
-- The build refuses (exit 1, nothing written) when a source is missing, its size or git blob sha1 differs from the
-- manifest, the pitch check of a `strict` instrument disagrees with its root by more than 0.6 semitone (a whole-octave
-- disagreement shared by the instrument is corrected and logged), or a budget is exceeded (the recipe's `budgets`:
-- Opus bytes, decoded bytes on desktop and on the phone tier). Each zone (design §12.11, measured step by step by
-- tools/bank/bank_audit.lua): decoded at the source's rate, declipped where the recipe says, one microphone of a
-- stereo pair for a mono zone, started 2 ms before its onset with a fade-in, resampled to 48 kHz by a 256-tap sinc,
-- trimmed to the recipe's seconds, normalised per instrument to -1 dBFS peak (so velocity layers keep their dynamics),
-- given the instrument's raised-cosine end fade (or an equal-power loop crossfade for looped sustains), packed with
-- 50 ms gaps into the sprite of its tier and Opus rate, encoded Opus at the instrument's `kbps` in Ogg with bit-exact
-- flags. Same sources, same ffmpeg: same bytes. --keep-pcm DIR keeps the pre-encode sprites for the audit.
local here = arg[0]:match('^(.*)/[^/]*$') or '.'
package.path = here .. '/?.lua;' .. package.path
local B = require 'bank'
local json = B.json

local opts = { with = {} }
do
  local i = 1
  while i <= #arg do
    local a = arg[i]
    if a == '--dry-run' or a == '--json' or a == '--sync-keys' or a == '--fetch' or a == '--fetch-maps' or a == '--f0-report' then opts[a:sub(3)] = true; i = i + 1
    elseif a == '--with' then opts.with[arg[i + 1]] = true; i = i + 2
    elseif a:match('^%-%-') and arg[i + 1] then opts[a:sub(3)] = arg[i + 1]; i = i + 2
    else io.stderr:write('unknown argument ' .. a .. '\n'); os.exit(2) end
  end
end
local home = os.getenv('HOME') or '.'
local recipePath = opts.recipe or 'art/music/bank/recipe.json'
local recipe, rows, keys = B.load(recipePath, opts.manifest, opts.keys)
-- --- demon-choir: a recipe may name its own source folder (`src`, `~/` is the home folder).
local src = opts.src or (recipe.src and recipe.src:gsub('^~/', home .. '/')) or (home .. '/.cache/tillandsias-project/sample-bank/src')
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
-- Scratch goes under the forge cache (or --tmp), never the checkout or /tmp.
math.randomseed(os.time())
local tmp = opts.tmp or ('%s/.cache/tillandsias-project/tmp/bank-build-%d-%d'):format(home, os.time(), math.random(1e6))
assert(os.execute('mkdir -p ' .. q(tmp)))

-- --- bank-fidelity (design §12.11): the cut, step by step, each one measured by tools/bank/bank_audit.lua.
-- 1. Decode at the source's own rate and channels (every pinned source is 44.1 kHz), only the head the zone needs.
-- 2. Declip (`declip: true`): Growlybass's staccatos and most `ff` sustains hit the converter's ceiling (1-71 samples
--    at full scale, runs up to 36 samples). Each run of 2+ samples at the file's peak is rebuilt by a cubic through
--    the two samples on either side, never below the clip level. ffmpeg's adeclip was tried and rejected: it changed
--    1 818 samples of a clean file by up to 0.34.
-- 3. Mono from a stereo source takes ONE channel (`pick`, default the left): the VCSL/VSCO pairs are spaced
--    microphones (L/R correlation -0.3 to 0.9), and their sum loses 0.2-4.6 dB to comb notches.
-- 4. The onset: the first sample within 40 dB of the file's peak; the zone starts PREROLL before it with a
--    raised-cosine fade-in (at least 1 ms, for sources that start inside their attack), so the attack is whole and
--    the first sample is silence (silenceremove's 20 ms RMS window started zones inside the attack: a click).
-- 5. Resample 44.1 -> 48 kHz with a 256-tap Kaiser (beta 12) sinc: images -119 dB (ffmpeg's default: -48 dB).
-- --- choir-real: `dc: true` subtracts each output channel's mean (over the decoded head) before the onset search:
--    epic-choir's hall sums carry -55 to -67 dB of DC (re full scale, after normalising) against the standard's
--    -58 (adaptive-soundtrack design §12.11). Off by default, so every other zone is byte for byte as before.
local PREROLL, ONSET_DB = 0.002, -40
local RESAMPLE = 'aresample=48000:filter_size=256:phase_shift=14:cutoff=0.97:kaiser_beta=12'
local function unpackFloats(bytes)
  local out, n, pos, batch = {}, #bytes // 4, 1, 64
  local fmt = '<' .. ('f'):rep(batch)
  local full = n - n % batch
  while #out < full do
    local values = { string.unpack(fmt, bytes, pos) }
    pos = values[batch + 1]
    for i = 1, batch do out[#out + 1] = values[i] end
  end
  while #out < n do local v; v, pos = string.unpack('<f', bytes, pos); out[#out + 1] = v end
  return out
end
local function packFloats(list)
  local parts = {}
  for k = 1, #list, 256 do local n = math.min(256, #list - k + 1); parts[#parts + 1] = string.pack('<' .. ('f'):rep(n), table.unpack(list, k, k + n - 1)) end
  return table.concat(parts)
end
local function sourceFormat(path)
  local text = sh(('ffmpeg -hide_banner -nostdin -i %s 2>&1'):format(q(path)))
  local line = text:match('Audio: ([^\n]*)') or ''
  local chs = line:match('Hz, (%w+)')
  return tonumber(line:match('(%d+) Hz')), chs == 'stereo' and 2 or chs == 'mono' and 1 or tonumber(chs)
end
-- Rebuilds clipped runs in place; returns the number of samples rebuilt.
local function declip(x)
  local peak = 0
  for i = 1, #x do local a = math.abs(x[i]); if a > peak then peak = a end end
  local level, fixed, i = peak * 0.9999, 0, 1
  while i <= #x do
    if math.abs(x[i]) >= level then
      local j = i
      while j + 1 <= #x and math.abs(x[j + 1]) >= level and (x[j + 1] > 0) == (x[i] > 0) do j = j + 1 end
      if j > i and i > 2 and j + 2 <= #x then
        local ts, ys = { i - 2, i - 1, j + 1, j + 2 }, { x[i - 2], x[i - 1], x[j + 1], x[j + 2] }
        local sign = x[i] > 0 and 1 or -1
        for t = i, j do
          local y = 0
          for a = 1, 4 do
            local l = 1
            for b2 = 1, 4 do if b2 ~= a then l = l * (t - ts[b2]) / (ts[a] - ts[b2]) end end
            y = y + ys[a] * l
          end
          x[t] = sign * math.max(math.abs(y), level)
          fixed = fixed + 1
        end
      end
      i = j + 1
    else i = i + 1 end
  end
  return fixed
end
-- Decoded PCM at 48 kHz: a flat list of floats, interleaved by channel.
local cutStats = {}
local function decode(z)
  local path = fileOf({ repo = z.source.repo, path = z.source.path })
  local srate, sch = sourceFormat(path)
  if not srate or not sch then die('ffmpeg cannot read the format of %s', z.source.path) end
  local bytes, ok = sh(('ffmpeg -v error -nostdin -i %s -t %.4f -f f32le -'):format(q(path), z.trim + 0.5))
  if not ok or #bytes < 4 * sch then die('ffmpeg could not decode %s', z.source.path) end
  local flat = unpackFloats(bytes)
  local frames = #flat // sch
  local ch = {}
  for c = 1, sch do local t = {}; for i = 0, frames - 1 do t[i + 1] = flat[i * sch + c] end; ch[c] = t end
  flat = nil
  local stat = { inst = z.inst, file = z.file, declipped = 0 }
  if z.declip then for c = 1, sch do stat.declipped = stat.declipped + declip(ch[c]) end end
  local outc
  if z.channels == 1 then
    if sch == 1 then outc = { ch[1] }
    elseif z.pick == 'sum' then local m = {}; for i = 1, frames do local v = 0; for c = 1, sch do v = v + ch[c][i] end; m[i] = v / sch end; outc = { m }
    else outc = { ch[z.pick == 'R' and 2 or 1] } end
  else outc = sch == 1 and { ch[1], ch[1] } or { ch[1], ch[2] } end
  if z.dc then
    for c = 1, #outc do
      local m, t = 0, {}
      for i = 1, frames do m = m + outc[c][i] end
      m = m / frames
      for i = 1, frames do t[i] = outc[c][i] - m end
      outc[c] = t
    end
  end
  local peak = 0
  for c = 1, #outc do for i = 1, frames do local a = math.abs(outc[c][i]); if a > peak then peak = a end end end
  local threshold, onset = peak * 10 ^ (ONSET_DB / 20), 1
  for i = 1, frames do
    local hit = false
    for c = 1, #outc do if math.abs(outc[c][i]) > threshold then hit = true end end
    if hit then onset = i; break end
  end
  local pre = math.floor(PREROLL * srate + 0.5)
  local start = math.max(1, onset - pre)
  local stop = math.min(frames, start + math.ceil((z.trim + 0.02) * srate))
  -- A source that starts inside its attack (no room for the pre-roll) still gets a 1 ms fade-in.
  local rise = math.max(onset, start + math.floor(0.001 * srate + 0.5))
  local inter, nch = {}, #outc
  for i = start, stop do
    local g = 1
    if i < rise then local u = (i - start) / (rise - start); g = 0.5 - 0.5 * math.cos(math.pi * u) end
    for c = 1, nch do inter[#inter + 1] = outc[c][i] * g end
  end
  stat.onsetMs = (onset - 1) / srate * 1000
  local raw = ('%s/zone-%s.f32'):format(tmp, z.file:gsub('[^%w]', '_'))
  local fh = assert(io.open(raw, 'wb')); fh:write(packFloats(inter)); fh:close()
  local out, ok2 = sh(('ffmpeg -v error -nostdin -f f32le -ar %d -ac %d -i %s -af %s -f f32le -'):format(srate, nch, q(raw), RESAMPLE))
  os.remove(raw)
  if not ok2 or #out < 4 * nch then die('ffmpeg could not resample %s', z.source.path) end
  local pcm = unpackFloats(out)
  local keep = math.min(#pcm // nch, math.floor(z.trim * rate + 0.5)) * nch
  for i = #pcm, keep + 1, -1 do pcm[i] = nil end
  cutStats[#cutStats + 1] = stat
  return pcm
end

-- The pitch check (sample-bank run, 2026-11-17: a blind YIN estimate failed on the distorted bass, the short
-- staccatos and the low brass, and read the open organ pipes' octave-first attack as the pitch). It verifies a
-- planned root instead of guessing one, on one spectrum per zone: the mono mix decimated to 16 kHz, from 80 ms after
-- the onset for up to 1 s, Hann-windowed and zero-padded to 2^16 points (0.24 Hz bins).
--   octave: periodicity at f shows as partials at odd multiples of f. odd(f) = the summed magnitude at (h - 1/2) f,
--     all(f) the summed magnitude at h f (h = 1..8), both relative to the spectrum's peak. Starting from the planned
--     root F: while odd(F) > OCT_DOWN * all(F) and odd(F) > OCT_MIN the zone sounds an octave lower (F/2); else
--     while odd(2F) < OCT_UP * all(2F) and all(2F) > OCT_MIN (2F's partials carry the sound, F's odd ones are
--     absent) an octave higher (2F); at most ±2. OCT_MIN keeps a zone with no energy near F from moving on noise.
--   note: the harmonic sum S(f) = sum of sqrt|X(h f)| (h = 1..8, below 7 kHz) is maximised within ±6.5 semitones of
--     the zone's octave-corrected root (10-cent steps taking each partial's peak within ±12 cents, then 1-cent steps
--     within ±15 cents); the residual is that f against the root.
local OCT_DOWN, OCT_UP, OCT_MIN, SPAN = 0.9, 0.02, 0.3, 6.5
local function fft(re, im, n)
  local j = 1
  for i = 1, n do
    if i < j then re[i], re[j] = re[j], re[i]; im[i], im[j] = im[j], im[i] end
    local m = n >> 1
    while m >= 1 and j > m do j = j - m; m = m >> 1 end
    j = j + m
  end
  local len = 2
  while len <= n do
    local ang = -2 * math.pi / len
    local wr, wi = math.cos(ang), math.sin(ang)
    for i = 1, n, len do
      local cr, ci = 1, 0
      for k = 0, len // 2 - 1 do
        local a, b = i + k, i + k + len // 2
        local tr, ti = re[b] * cr - im[b] * ci, re[b] * ci + im[b] * cr
        re[b], im[b] = re[a] - tr, im[a] - ti
        re[a], im[a] = re[a] + tr, im[a] + ti
        cr, ci = cr * wr - ci * wi, cr * wi + ci * wr
      end
    end
    len = len * 2
  end
end
local SR, NFFT = rate / 3, 65536
-- Decimation by 3 behind a 63-tap Hamming-windowed sinc low-pass at 7 kHz: a plain 3-sample average lets a bright
-- DI guitar's partials above 8 kHz alias into the band and outvote the real ones (twang_g6 read 3.9 semitones flat).
local FIR = {}
do
  local N, fc, sum = 63, 7000 / rate, 0
  for n = 0, N - 1 do
    local m = n - (N - 1) / 2
    local h = (m == 0 and 2 * fc or math.sin(2 * math.pi * fc * m) / (math.pi * m)) * (0.54 - 0.46 * math.cos(2 * math.pi * n / (N - 1)))
    FIR[n + 1] = h; sum = sum + h
  end
  for n = 1, N do FIR[n] = FIR[n] / sum end
end
local function spectrum(pcm, channels)
  local frames = #pcm // channels
  local mono = {}
  for i = 0, frames - 1 do
    local s = 0
    for c = 1, channels do s = s + pcm[i * channels + c] end
    mono[i + 1] = s / channels
  end
  local total = frames // 3
  local start = math.floor(0.08 * SR)
  local L = math.min(total - start, math.floor(SR))
  if L < math.floor(0.2 * SR) then start = 0; L = math.min(total, math.floor(SR)) end
  if L < 2048 then return nil end
  local x, N = {}, #FIR
  for k = start, start + L - 1 do
    local c, acc = 3 * k + 1, 0
    for n = 1, N do
      local v = mono[c + n - 1 - (N - 1) // 2]
      if v then acc = acc + FIR[n] * v end
    end
    x[k + 1] = acc
  end
  local re, im = {}, {}
  for i = 1, NFFT do re[i], im[i] = 0, 0 end
  for i = 0, L - 1 do re[i + 1] = x[start + i + 1] * (0.5 - 0.5 * math.cos(2 * math.pi * i / (L - 1))) end
  fft(re, im, NFFT)
  local mag, peak = {}, 0
  local lo, hi = math.floor(20 * NFFT / SR), math.floor(7000 * NFFT / SR)
  for i = 1, NFFT // 2 do mag[i] = math.sqrt(re[i] * re[i] + im[i] * im[i]); if i >= lo and i <= hi and mag[i] > peak then peak = mag[i] end end
  if peak <= 0 then return nil end
  for i = 1, #mag do mag[i] = mag[i] / peak end
  return mag
end
local function magAt(mag, hz)
  local b = hz * NFFT / SR
  local i = math.floor(b)
  if i < 1 or i + 1 >= #mag then return 0 end
  local t = b - i
  return mag[i + 1] * (1 - t) + mag[i + 2] * t
end
-- The strongest bin within ±cents of hz (real partials sit a few cents off exact multiples, and a 1 s window's
-- peaks are ~1 Hz wide).
local function peakNear(mag, hz, cents)
  local a, b = math.floor(hz * 2 ^ (-cents / 1200) * NFFT / SR), math.ceil(hz * 2 ^ (cents / 1200) * NFFT / SR)
  local m = 0
  for i = math.max(1, a), math.min(#mag - 1, b) do if mag[i + 1] > m then m = mag[i + 1] end end
  return m
end
-- The harmonic sum on compressed magnitudes (sqrt), so one loud partial cannot outvote the series (twang_g6: its 4th
-- partial is 17 dB over the fundamental, and 626 Hz x 5 landed on it). `cents` > 0: peak within that tolerance.
local function hsum(mag, f, cents)
  local s = 0
  for h = 1, 8 do if h * f < 7000 then s = s + math.sqrt(cents and peakNear(mag, h * f, cents) or magAt(mag, h * f)) end end
  return s
end
local function oddAll(mag, f)
  local odd, all = 0, 0
  for h = 1, 8 do if h * f < 7000 then all = all + magAt(mag, h * f); odd = odd + magAt(mag, (h - 0.5) * f) end end
  return odd, all
end
local function lower(mag, f) local odd, all = oddAll(mag, f); return odd > OCT_DOWN * all and odd > OCT_MIN end
local function higher(mag, f) local odd, all = oddAll(mag, 2 * f); return odd < OCT_UP * all and all > OCT_MIN end
local function ratio(mag, f) local odd, all = oddAll(mag, f); return all > 0 and odd / all or math.huge end
local function hzOf(m) return 440 * 2 ^ ((m - 69) / 12) end
-- Returns { octave = k, hz = f, odd = odd(F'), up = odd(2F') } for a planned root (MIDI), or nil (too short).
local function pitchCheck(pcm, channels, root)
  local mag = spectrum(pcm, channels)
  if not mag then return nil end
  local k = 0
  while k > -2 and lower(mag, hzOf(root + 12 * k)) do k = k - 1 end
  if k == 0 then while k < 2 and higher(mag, hzOf(root + 12 * k)) do k = k + 1 end end
  local F = hzOf(root + 12 * k)
  local best, bestHz = -1, F
  for c = -SPAN * 100, SPAN * 100, 10 do
    local hz = F * 2 ^ (c / 1200)
    local v = hsum(mag, hz, 12)
    if v > best then best, bestHz = v, hz end
  end
  local coarse = bestHz
  best = -1
  for c = -15, 15 do
    local hz = coarse * 2 ^ (c / 1200)
    local v = hsum(mag, hz)
    if v > best then best, bestHz = v, hz end
  end
  return { octave = k, hz = bestHz, odd = ratio(mag, F), up = ratio(mag, 2 * F) }
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
for _, id in ipairs(instOrder) do
  local inst, list = recipeInst[id], byInst[id]
  local peak = 0
  for _, z in ipairs(list) do
    local pcm = decode(z)
    for i = 1, #pcm do local a = math.abs(pcm[i]); if a > peak then peak = a end end
    z.pcm = pcm
  end
  -- The pitch check: each zone's octave and note against its planned root. The instrument's octave is the zones'
  -- majority (a shared whole-octave offset is corrected and logged); a zone voting another octave, or a note more
  -- than 0.6 semitone off, is refused (strict) or reported.
  if inst.verify and not inst.keys then
    local octaves = {}
    for _, z in ipairs(list) do
      local p = pitchCheck(z.pcm, z.channels, z.root)
      if p then
        z.f0 = math.floor(p.hz * 100 + 0.5) / 100
        z.f0Odd, z.f0Up = p.odd, p.up
        local residual = midiOf(p.hz) - (z.root + 12 * p.octave)
        z.f0Residual = math.floor(residual * 100 + 0.5) / 100
        z.f0Octave = p.octave
        octaves[p.octave] = (octaves[p.octave] or 0) + 1
        if math.abs(residual) > 0.6 then
          local msg = ('%s %s: f0 %.1f Hz is %.2f semitones off root %d'):format(id, z.file, p.hz, residual, z.root + 12 * p.octave)
          if inst.verify == 'strict' then refusals[#refusals + 1] = msg else notes[#notes + 1] = msg .. ' (reported)' end
        end
      elseif inst.verify == 'strict' then refusals[#refusals + 1] = ('%s %s: too short for the pitch check'):format(id, z.file)
      else notes[#notes + 1] = ('%s %s: too short for the pitch check (reported)'):format(id, z.file) end
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
      -- The end fade: the instrument's `fade` (a struck cymbal or bell decays over its last second or more, instead
      -- of the 20 ms cut that ended a ringing crash at -18 dB), raised-cosine, at most half the zone.
      local fade = math.min(math.floor(z.fade * rate + 0.5), frames // 2)
      for i = 0, fade - 1 do
        local g = 0.5 - 0.5 * math.cos(math.pi * i / fade)
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
if opts['f0-report'] then
  io.write('inst\tfile\troot\tf0_hz\tf0_midi\tresidual\toctave\todd_f\todd_2f\troot_source\n')
  for _, z in ipairs(plan.zones) do
    if z.root and recipeInst[z.inst].verify then
      io.write(('%s\t%s\t%d\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n'):format(z.inst, z.file, z.root, z.f0 or '-', z.f0 and ('%.2f'):format(midiOf(z.f0)) or '-',
        z.f0Residual and ('%+.2f'):format(z.f0Residual) or '-', z.f0Octave and ('%+d'):format(z.f0Octave) or '-',
        z.f0Odd and ('%.3f'):format(z.f0Odd) or '-', z.f0Up and ('%.3f'):format(z.f0Up) or '-', z.rootSource))
    end
  end
  for _, n in ipairs(notes) do say('note: %s', n) end
  for _, r in ipairs(refusals) do say('refusal: %s', r) end
  os.execute('rm -rf ' .. q(tmp))
  os.exit(#refusals > 0 and 1 or 0)
end
if #refusals > 0 then die('refused: %d f0 check(s) failed:\n  %s', #refusals, table.concat(refusals, '\n  ')) end
for _, n in ipairs(notes) do say('note: %s', n) end
do
  local fixed, files = 0, 0
  for _, st in ipairs(cutStats) do if st.declipped > 0 then fixed = fixed + st.declipped; files = files + 1 end end
  if fixed > 0 then say('declipped %d samples in %d zones', fixed, files) end
end

-- Sprites: zones in plan order with gaps; raw f32le to a temp dir, then Opus.
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
  local kbps = s.kbps
  local out = ('%s/%s'):format(tmp, s.file)
  local cmd = ('ffmpeg -v error -nostdin -y -f f32le -ar %d -ac %d -i %s -c:a libopus -b:a %dk -vbr on -application audio -frame_duration 20 -map_metadata -1 -fflags +bitexact -flags:a +bitexact %s')
    :format(rate, s.channels, q(raw), kbps, q(out))
  if not os.execute(cmd) then die('ffmpeg could not encode %s', s.file) end
  -- --keep-pcm DIR: keep the pre-encode sprite for tools/bank/bank_audit.lua (cut, encode, bitrate).
  if opts['keep-pcm'] then os.execute(('mkdir -p %s && mv %s %s/%s.f32'):format(q(opts['keep-pcm']), q(raw), q(opts['keep-pcm']), s.file:gsub('%.ogg$', '')))
  else os.remove(raw) end
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
  spritesOut[#spritesOut + 1] = { file = s.file, tier = s.tier, phone = s.phone, channels = s.channels, kbps = s.kbps, seconds = s.frames / rate,
    bytes = s.bytes, sha256 = s.sha256, decodedBytes = s.decodedBytes }
end
local bank = { schema = 'demon-attack.bank/v1',
  comment = recipe.generatedComment or 'GENERATED by lua tools/bank/bank_build.lua from art/music/bank/recipe.json and the pins in plan/sample-bank-pins.manifest.tsv; do not edit.',
  name = recipe.name,
  rate = rate, budgets = recipe.budgets, roles = recipe.roles, instruments = plan.instruments, sprites = spritesOut, zones = zonesOut,
  sources = sources, totals = totals }
os.execute('mkdir -p ' .. q(outDir))
-- Replace the previous build: stale sprites go (one format, no leftovers).
-- --- demon-choir: the recipe's `name` (default `bank`) names the JSON and prefixes the sprites; only its own are replaced.
local bankName = recipe.name or 'bank'
for name in sh('ls ' .. q(outDir) .. ' 2>/dev/null'):gmatch('[^\n]+') do if name:sub(1, #bankName + 1) == bankName .. '-' and name:match('%.ogg$') then os.remove(outDir .. '/' .. name) end end
for _, s in ipairs(plan.sprites) do
  if not os.execute(('mv %s %s'):format(q(s.path), q(outDir .. '/' .. s.file))) then die('cannot write %s', s.file) end
end
local f = assert(io.open(outDir .. '/' .. bankName .. '.json', 'wb')); f:write(json.encode(bank, { indent = ' ' }), '\n'); f:close()
os.execute('rm -rf ' .. q(tmp))
say('wrote %s/%s.json and %d sprites', outDir, bankName, #plan.sprites)
