#!/usr/bin/env lua
-- bank_audit.lua: the sample bank's fidelity audit (adaptive-soundtrack design §12.11). Measures every step of the
-- pipeline that tools/bank/bank_build.lua runs, so a verdict rests on numbers, not on a guess.
--
-- Run from the repo root (Lua 5.4 + ffmpeg with libopus); every mode prints TSV on stdout and a summary on stderr:
--   lua tools/bank/bank_audit.lua sources  [--bank FILE]            1. each pinned source file: codec, rate, bits,
--                                                                   channels, peak, true peak, DC, noise floor
--   lua tools/bank/bank_audit.lua resample                          2. the resampler on test tones (44.1 -> 48 kHz)
--   lua tools/bank/bank_audit.lua cut      --pcm DIR [--bank FILE]  2-3. each zone as cut and normalised (before Opus):
--                                                                   onset step, level at the cut, loop seam, overs
--   lua tools/bank/bank_audit.lua encode   --pcm DIR [--bank FILE]  4. each zone after Opus against its cut: residual
--                                                                   SNR, -60 dB bandwidth before and after, pre-echo
--   lua tools/bank/bank_audit.lua bitrate  --pcm DIR [--bank FILE]  4. each instrument re-encoded at 48-160 kbps
-- --pcm DIR holds the pre-encode sprites that `bank_build.lua --keep-pcm DIR` writes (<sprite>.f32, float32 LE,
-- interleaved, 48 kHz). --bank defaults to web/audio/bank/bank.json; --src to the builder's source cache.
local here = arg[0]:match('^(.*)/[^/]*$') or '.'
package.path = here .. '/?.lua;' .. package.path
local B = require 'bank'
local json = B.json

local mode = arg[1]
local opts = {}
for i = 2, #arg, 2 do opts[(arg[i] or ''):gsub('^%-%-', '')] = arg[i + 1] end
local home = os.getenv('HOME') or '.'
local src = opts.src or (home .. '/.cache/tillandsias-project/sample-bank/src')
local bankPath = opts.bank or 'web/audio/bank/bank.json'
local function q(s) return "'" .. tostring(s):gsub("'", "'\\''") .. "'" end
local function sh(cmd) local p = assert(io.popen(cmd, 'r')); local out = p:read('a'); p:close(); return out end
local function say(...) io.stderr:write(string.format(...) .. '\n') end
local function db(x) return x > 0 and 20 * math.log(x, 10) or -math.huge end
local function fmt(x, n) if x == -math.huge then return '-inf' end; return ('%.' .. (n or 1) .. 'f'):format(x) end
local RATE = 48000

-- Float32 LE bytes -> per-channel arrays.
local function unpackF32(bytes, channels)
  local ch = {}
  for c = 1, channels do ch[c] = {} end
  local n, pos, batch = #bytes // 4, 1, 256
  local fmt256 = '<' .. ('f'):rep(batch)
  local k = 0
  while k + batch <= n do
    local v = { string.unpack(fmt256, bytes, pos) }
    pos = v[batch + 1]
    for i = 1, batch do local c = (k + i - 1) % channels + 1; local t = ch[c]; t[#t + 1] = v[i] end
    k = k + batch
  end
  while k < n do local v; v, pos = string.unpack('<f', bytes, pos); local c = k % channels + 1; ch[c][#ch[c] + 1] = v; k = k + 1 end
  return ch
end
local function decode(path, extra)
  return sh(('ffmpeg -v error -nostdin -i %s %s -f f32le -'):format(q(path), extra or ''))
end
local function info(path)
  local text = sh(('ffmpeg -hide_banner -nostdin -i %s 2>&1'):format(q(path)))
  local line = text:match('Audio: ([^\n]*)') or ''
  local codec = line:match('^(%w+)')
  local rate = tonumber(line:match('(%d+) Hz'))
  local chs = line:match('Hz, (%w+)')
  -- --- round8: float WAVs (the choir's local sources, pcm_f32le, "flt") read as 32 bits.
  local bits = tonumber(line:match('%((%d+) bit%)')) or tonumber(line:match('[su](%d+)')) or tonumber(line:match('^pcm_f(%d+)'))
  return { codec = codec, rate = rate, channels = chs == 'stereo' and 2 or chs == 'mono' and 1 or tonumber(chs), bits = bits }
end
local function truePeak(path, extra)
  local text = sh(('ffmpeg -hide_banner -nostdin %s -i %s -af ebur128=peak=true+sample -f null - 2>&1'):format(extra or '', q(path)))
  local tp = text:match('True peak:%s*Peak:%s*(%-?[%d%.inf]+)')
  return tonumber(tp) or -math.huge
end

-- --- FFT and spectra ------------------------------------------------------------------------------------------------
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
    local half = len // 2
    for i = 1, n, len do
      local cr, ci = 1, 0
      for k = 0, half - 1 do
        local a, b = i + k, i + k + half
        local tr, ti = re[b] * cr - im[b] * ci, re[b] * ci + im[b] * cr
        re[b], im[b] = re[a] - tr, im[a] - ti
        re[a], im[a] = re[a] + tr, im[a] + ti
        cr, ci = cr * wr - ci * wi, cr * wi + ci * wr
      end
    end
    len = len * 2
  end
end
local N = 4096
local HANN = {}
for i = 0, N - 1 do HANN[i + 1] = 0.5 - 0.5 * math.cos(2 * math.pi * i / (N - 1)) end
-- Welch power spectrum of x[from..to] (N-point Hann, half overlap): power per bin (1..N/2).
local function welch(x, from, to)
  local P, frames = {}, 0
  for i = 1, N // 2 do P[i] = 0 end
  -- At least one frame (zero-padded past `to`), then every half frame that fits.
  local start = from
  repeat
    local re, im = {}, {}
    for i = 1, N do local k = start + i - 1; re[i] = (k <= to and x[k] or 0) * HANN[i]; im[i] = 0 end
    fft(re, im, N)
    for i = 1, N // 2 do P[i] = P[i] + re[i] * re[i] + im[i] * im[i] end
    frames = frames + 1
    start = start + N // 2
  until start + N - 1 > to
  if frames == 0 then return nil end
  for i = 1, N // 2 do P[i] = P[i] / frames end
  return P
end
-- The -60 dB bandwidth: the highest frequency whose 1/6-octave-smoothed level is within 60 dB of the spectrum's peak.
local function bandwidth(P, rate, floorDb)
  floorDb = floorDb or 60
  local peak = 0
  for i = 2, #P do if P[i] > peak then peak = P[i] end end
  if peak <= 0 then return 0 end
  local top = 0
  for i = 2, #P do
    local lo, hi = math.max(2, math.floor(i * 2 ^ (-1 / 12))), math.min(#P, math.ceil(i * 2 ^ (1 / 12)))
    local s = 0
    for k = lo, hi do s = s + P[k] end
    s = s / (hi - lo + 1)
    if 10 * math.log(s / peak, 10) > -floorDb then top = i end
  end
  return (top - 1) * rate / N
end

local function rms(x, a, b)
  local s, n = 0, 0
  for i = math.max(1, a), math.min(#x, b) do s = s + x[i] * x[i]; n = n + 1 end
  return n > 0 and math.sqrt(s / n) or 0
end
local function mono(ch)
  if #ch == 1 then return ch[1] end
  local m = {}
  for i = 1, #ch[1] do local s = 0; for c = 1, #ch do s = s + ch[c][i] end; m[i] = s / #ch end
  return m
end

local bank = json.decode(assert(B.read(bankPath), 'no bank ' .. bankPath))
local function srcPath(z) return ('%s/%s/%s'):format(src, z.source.repo, z.source.path) end

-- Per-instrument summary rows: min / median / max of each numeric column.
local function summarise(rows, cols)
  local by, order = {}, {}
  for _, r in ipairs(rows) do if not by[r.inst] then by[r.inst] = {}; order[#order + 1] = r.inst end; table.insert(by[r.inst], r) end
  io.stderr:write('inst\tn\t' .. table.concat(cols, '\t') .. '   (min / median / max)\n')
  for _, inst in ipairs(order) do
    local out = { inst, tostring(#by[inst]) }
    for _, c in ipairs(cols) do
      local v = {}
      for _, r in ipairs(by[inst]) do if type(r[c]) == 'number' and r[c] == r[c] then v[#v + 1] = r[c] end end
      table.sort(v)
      if #v == 0 then out[#out + 1] = '-'
      else out[#out + 1] = ('%s/%s/%s'):format(fmt(v[1]), fmt(v[(#v + 1) // 2]), fmt(v[#v])) end
    end
    io.stderr:write(table.concat(out, '\t') .. '\n')
  end
end

-- ===== 1. sources ===================================================================================================
if mode == 'sources' then
  local rows, seen = {}, {}
  io.write('inst\tfile\tcodec\trate\tbits\tch\tseconds\tpeak_dbfs\ttrue_peak_dbfs\tdc_db\thead_db\ttail_db\tfloor_db\tsnr_db\tbw60_hz\tlr_corr\tfold_db\tclipped\n')
  for _, z in ipairs(bank.zones) do
    local path = srcPath(z)
    if not seen[path] then
      seen[path] = true
      local inf = info(path)
      local ch = unpackF32(decode(path, '-ac ' .. inf.channels), inf.channels)
      local x = mono(ch)
      local peak, dc = 0, 0
      -- Clipped: samples within 0.0003 dB of full scale (a recording that hit the converter's ceiling).
      local clipped = 0
      for c = 1, #ch do for _, v in ipairs(ch[c]) do local a = math.abs(v); if a > peak then peak = a end; if a >= 0.99997 then clipped = clipped + 1 end end end
      for _, v in ipairs(x) do dc = dc + v end
      dc = dc / math.max(1, #x)
      -- Head: before the first sample within 40 dB of the peak (at least 2 ms, else none). Tail: the last 50 ms.
      local onset = 1
      for i, v in ipairs(x) do if math.abs(v) > peak * 0.01 then onset = i; break end end
      local w = math.floor(0.05 * inf.rate)
      local head = onset > 0.002 * inf.rate and db(rms(x, 1, onset - 1)) or nil
      local tail = db(rms(x, #x - w + 1, #x))
      -- Floor: the quietest 50 ms window (hop 25 ms) after the onset: room noise, hiss, dither.
      local floor = math.huge
      for a = onset, #x - w, w // 2 do local r = rms(x, a, a + w - 1); if r > 0 then floor = math.min(floor, db(r)) end end
      if floor == math.huge then floor = -math.huge end
      -- Signal: the loudest 50 ms window.
      local loud = 0
      for a = onset, #x - w, w // 2 do loud = math.max(loud, rms(x, a, a + w - 1)) end
      local corr, fold
      if #ch == 2 then
        local sxy, sxx, syy = 0, 0, 0
        for i = 1, #ch[1] do local a, b = ch[1][i], ch[2][i]; sxy = sxy + a * b; sxx = sxx + a * a; syy = syy + b * b end
        corr = sxy / math.sqrt(sxx * syy + 1e-30)
        -- The mono fold's loss: the power of (L+R)/2 re the channels' mean power (0 dB: identical; -3 dB: uncorrelated,
        -- and on a spaced pair the loss is comb notches, not a flat 3 dB).
        fold = 10 * math.log((sxx + syy + 2 * sxy) / 4 / ((sxx + syy) / 2) + 1e-30, 10)
      end
      local P = welch(x, onset, math.min(#x, onset + math.floor(1.5 * inf.rate)))
      local r = { inst = z.inst, file = z.source.path:match('[^/]+$'), codec = inf.codec, rate = inf.rate, bits = inf.bits, ch = inf.channels,
        seconds = #x / inf.rate, peak = db(peak), tp = truePeak(path), dc = db(math.abs(dc)), head = head, tail = tail, floor = floor,
        snr = db(loud) - floor, bw = P and bandwidth(P, inf.rate) or 0, corr = corr, fold = fold, clipped = clipped }
      rows[#rows + 1] = r
      io.write(table.concat({ r.inst, r.file, r.codec, r.rate, r.bits, r.ch, fmt(r.seconds, 2), fmt(r.peak, 2), fmt(r.tp, 2), fmt(r.dc),
        head and fmt(head) or '-', fmt(tail), fmt(floor), fmt(r.snr), fmt(r.bw, 0), corr and fmt(corr, 3) or '-', fold and fmt(fold, 2) or '-', clipped }, '\t') .. '\n')
      io.stdout:flush()
    end
  end
  summarise(rows, { 'seconds', 'peak', 'tp', 'dc', 'head', 'tail', 'floor', 'snr', 'bw', 'corr', 'fold', 'clipped' })
  os.exit(0)
end

-- ===== 2. resample: the 44.1 -> 48 kHz converter on two tones (1 kHz and 19 kHz at -1 dBFS each / 2) ===============
if mode == 'resample' then
  local tmp = opts.tmp or (home .. '/.cache/tillandsias-project/tmp/bank-audit')
  os.execute('mkdir -p ' .. q(tmp))
  local wav = tmp .. '/tones-44k1.wav'
  os.execute(('ffmpeg -v error -nostdin -y -f lavfi -i "aevalsrc=0.445*sin(2*PI*1000*t)+0.445*sin(2*PI*19000*t):s=44100:d=2" -c:a pcm_f32le %s'):format(q(wav)))
  io.write('resampler\tsettings\tresidual_db\talias_db\tpassband_19k_db\n')
  local tests = {
    { 'swr default', '-ar 48000' },
    { 'swr high', '-af aresample=48000:filter_size=256:phase_shift=14:cutoff=0.97:kaiser_beta=12' },
    { 'swr short', '-af aresample=48000:filter_size=16:phase_shift=6' },
  }
  for _, t in ipairs(tests) do
    local x = unpackF32(decode(wav, t[2] .. ' -ac 1'), 1)[1]
    local P = welch(x, 4801, #x - 4800)
    -- Tone bins +/- 12 bins (the Hann leakage) carry the tones; everything else is the converter's noise, images and aliases.
    local function near(f, i) return math.abs((i - 1) * RATE / N - f) <= 12 * RATE / N end
    local tone, rest, alias, at19 = 0, 0, 0, 0
    for i = 2, #P do
      local f = (i - 1) * RATE / N
      if near(1000, i) or near(19000, i) then tone = tone + P[i]; if near(19000, i) then at19 = at19 + P[i] end
      else rest = rest + P[i]; if f > 20000 then alias = alias + P[i] end end
    end
    io.write(('%s\t%s\t%s\t%s\t%s\n'):format(t[1], t[2], fmt(10 * math.log(rest / tone, 10)), fmt(10 * math.log((alias + 1e-30) / tone, 10)),
      fmt(10 * math.log(at19 / (tone / 2), 10), 2)))
  end
  os.exit(0)
end

-- The pre-encode sprites (bank_build.lua --keep-pcm) and the shipped Opus sprites, decoded per zone.
local pcmDir = opts.pcm
local spriteCache = {}
local function sprite(name, which)
  local key = name .. which
  if not spriteCache[key] then
    local s
    for _, sp in ipairs(bank.sprites) do if sp.file == name then s = sp end end
    local bytes
    if which == 'pcm' then bytes = assert(B.read(('%s/%s.f32'):format(pcmDir, name:gsub('%.ogg$', ''))), 'no pre-encode PCM for ' .. name .. ' (bank_build.lua --keep-pcm)')
    else bytes = decode(opts.sprites and (opts.sprites .. '/' .. name) or ('web/audio/bank/' .. name), '-ac ' .. s.channels .. ' -ar 48000') end
    spriteCache = { [key] = unpackF32(bytes, s.channels) }   -- one sprite at a time: zones come in sprite order below
    spriteCache[key].channels = s.channels
  end
  return spriteCache[key]
end
local function zonesBySprite()
  local list = {}
  for _, z in ipairs(bank.zones) do list[#list + 1] = z end
  table.sort(list, function(a, b) if a.sprite ~= b.sprite then return a.sprite < b.sprite end; return a.offset < b.offset end)
  return list
end
local function slice(ch, z, pad)
  pad = pad or 0
  local a = math.floor(z.offset * RATE + 0.5) + 1 - pad
  local n = math.floor(z.length * RATE + 0.5) + pad
  local out = {}
  for c = 1, #ch do local t = {}; for i = 0, n - 1 do t[i + 1] = ch[c][a + i] or 0 end; out[c] = t end
  return out
end

-- ===== 2-3. cut: each zone as cut and normalised =====================================================================
if mode == 'cut' then
  assert(pcmDir, '--pcm DIR')
  io.write('inst\tzone\tseconds\tpeak_dbfs\tovers\tonset_step_db\tcut_level_db\tseam_jump_db\tdc_db\n')
  local rows = {}
  for _, z in ipairs(zonesBySprite()) do
    local ch = slice(sprite(z.sprite, 'pcm'), z)
    local x = mono(ch)
    local peak, overs = 0, 0
    for c = 1, #ch do for _, v in ipairs(ch[c]) do local a = math.abs(v); if a > peak then peak = a end; if a > 1 then overs = overs + 1 end end end
    -- Onset step: the first sample's level re the peak (a click when the cut starts inside the attack).
    local step = db(math.abs(x[1]) / peak)
    -- Level at the cut: the RMS of the 50 ms before the end fade (or the loop end) re the loudest 50 ms.
    local w, fadeN = math.floor(0.05 * RATE), math.floor((z.fade or 0.02) * RATE)
    local loud = 0
    for a = 1, #x - w, w // 2 do loud = math.max(loud, rms(x, a, a + w - 1)) end
    local cut = db(rms(x, #x - fadeN - w, #x - fadeN) / loud)
    -- Loop seam: the jump from the loop's last sample to its first, re the median step of the loop.
    local seam
    if z.loop then
      local a, b = math.floor(z.loop[1] * RATE + 0.5) + 1, math.floor(z.loop[2] * RATE + 0.5)
      local steps = {}
      for i = a + 1, b, 7 do steps[#steps + 1] = math.abs(x[i] - x[i - 1]) end
      table.sort(steps)
      seam = db(math.abs(x[a] - x[b]) / math.max(1e-9, steps[#steps * 9 // 10] or 1e-9))
    end
    local dc = 0
    for _, v in ipairs(x) do dc = dc + v end
    local r = { inst = z.inst, zone = z.id, seconds = z.length, peak = db(peak), overs = overs, step = step, cut = cut, seam = seam, dc = db(math.abs(dc / #x)) }
    rows[#rows + 1] = r
    io.write(table.concat({ r.inst, r.zone, fmt(r.seconds, 2), fmt(r.peak, 2), r.overs, fmt(step), fmt(cut), seam and fmt(seam) or '-', fmt(r.dc) }, '\t') .. '\n')
  end
  summarise(rows, { 'seconds', 'peak', 'overs', 'step', 'cut', 'seam', 'dc' })
  os.exit(0)
end

-- Residual SNR, bandwidths and pre-echo of encoded `e` against its cut `s` (mono arrays, the same length).
-- The magnitude SNR: STFT magnitudes (1024-point Hann, half overlap) of the encoded zone against its cut,
-- 10 log10(sum |S|^2 / sum (|E| - |S|)^2). Phase-blind on purpose: the kick's waveform SNR stays at 23-24 dB from 64 to
-- 160 kbps while its magnitude SNR rises, so its residual is a phase shift of the low partials, not coding noise.
local M = 1024
local MHANN = {}
for i = 0, M - 1 do MHANN[i + 1] = 0.5 - 0.5 * math.cos(2 * math.pi * i / (M - 1)) end
local function magSnr(s, e)
  local sig, err = 0, 0
  for start = 1, math.max(1, #s - M + 1), M // 2 do
    local r1, i1, r2, i2 = {}, {}, {}, {}
    for i = 1, M do local k = start + i - 1; r1[i] = (s[k] or 0) * MHANN[i]; i1[i] = 0; r2[i] = (e[k] or 0) * MHANN[i]; i2[i] = 0 end
    fft(r1, i1, M); fft(r2, i2, M)
    for i = 2, M // 2 do
      local a, b = math.sqrt(r1[i] * r1[i] + i1[i] * i1[i]), math.sqrt(r2[i] * r2[i] + i2[i] * i2[i])
      sig = sig + a * a; err = err + (b - a) * (b - a)
    end
  end
  return 10 * math.log(sig / math.max(err, 1e-30), 10)
end
-- Waveform SNR, magnitude SNR, the -60 dB bandwidths and pre-echo of encoded `e` against its cut `s` (mono arrays,
-- the same length). Pre-echo: the residual (e - s) in the 1-12 ms before the attack (the first sample within 40 dB of
-- the peak), in dB re the peak.
local function compare(s, e, hit)
  local ss, rr = 0, 0
  for i = 1, #s do local d = (e[i] or 0) - s[i]; ss = ss + s[i] * s[i]; rr = rr + d * d end
  local Ps, Pe = welch(s, 1, math.min(#s, math.floor(1.5 * RATE))), welch(e, 1, math.min(#e, math.floor(1.5 * RATE)))
  local pre
  if hit then
    local peak = 0
    for _, v in ipairs(s) do peak = math.max(peak, math.abs(v)) end
    local onset
    for i, v in ipairs(s) do if math.abs(v) > 0.01 * peak then onset = i; break end end
    if onset then
      local a, b, acc, n = onset - math.floor(0.012 * RATE), onset - math.floor(0.001 * RATE), 0, 0
      for i = math.max(1, a), b do local d = (e[i] or 0) - (s[i] or 0); acc = acc + d * d; n = n + 1 end
      if n > 0 then pre = db(math.sqrt(acc / n) / peak) end
    end
  end
  return 10 * math.log(ss / math.max(rr, 1e-30), 10), Ps and bandwidth(Ps, RATE) or 0, Pe and bandwidth(Pe, RATE) or 0, pre, magSnr(s, e)
end

-- ===== 4. encode: each zone after Opus against its cut ==============================================================
if mode == 'encode' then
  assert(pcmDir, '--pcm DIR')
  io.write('inst\tzone\tsprite\tkbps\tsnr_db\tmag_snr_db\tbw60_cut_hz\tbw60_opus_hz\tpre_echo_db\n')
  local rows = {}
  local list = zonesBySprite()
  for _, z in ipairs(list) do
    local pad = math.floor(0.012 * RATE)
    local s = mono(slice(sprite(z.sprite, 'pcm'), z, pad))
    local e = mono(slice(sprite(z.sprite, 'opus'), z, pad))
    local snr, bws, bwe, pre, msnr = compare(s, e, z.art == 'hit' or z.art == 'stac')
    local sp
    for _, x in ipairs(bank.sprites) do if x.file == z.sprite then sp = x end end
    local kbps = sp.kbps or (sp.bytes * 8 / sp.seconds / 1000)
    local r = { inst = z.inst, zone = z.id, snr = snr, msnr = msnr, bws = bws, bwe = bwe, pre = pre, kbps = kbps }
    rows[#rows + 1] = r
    io.write(table.concat({ z.inst, z.id, z.sprite, fmt(kbps, 0), fmt(snr), fmt(msnr), fmt(bws, 0), fmt(bwe, 0), pre and fmt(pre) or '-' }, '\t') .. '\n')
  end
  summarise(rows, { 'kbps', 'snr', 'msnr', 'bws', 'bwe', 'pre' })
  os.exit(0)
end

-- ===== 4. bitrate: each instrument's cut zones re-encoded alone at several rates ====================================
if mode == 'bitrate' then
  assert(pcmDir, '--pcm DIR')
  local tmp = opts.tmp or (home .. '/.cache/tillandsias-project/tmp/bank-audit')
  os.execute('mkdir -p ' .. q(tmp))
  local rates = {}
  for r in (opts.rates or '48,64,96,128,160'):gmatch('%d+') do rates[#rates + 1] = tonumber(r) end
  local byInst, order = {}, {}
  for _, z in ipairs(zonesBySprite()) do if not byInst[z.inst] then byInst[z.inst] = {}; order[#order + 1] = z.inst end; table.insert(byInst[z.inst], z) end
  io.write('inst\tch\tkbps\tsnr_median_db\tmag_snr_median_db\tmag_snr_min_db\tbw60_cut_hz\tbw60_opus_hz\tpre_echo_max_db\n')
  for _, inst in ipairs(order) do
    -- The instrument's zones back to back (50 ms gaps), as one stream: what a sprite of only this instrument would be.
    local zones = byInst[inst]
    local channels = 1
    for _, s in ipairs(bank.sprites) do if s.file == zones[1].sprite then channels = s.channels end end
    local parts, spans, cursor, gap = {}, {}, 0, math.floor(0.05 * RATE)
    for _, z in ipairs(zones) do
      local ch = slice(sprite(z.sprite, 'pcm'), z)
      local n = #ch[1]
      local buf = {}
      for i = 1, n do for c = 1, channels do buf[#buf + 1] = ch[c][i] end end
      for _ = 1, gap * channels do buf[#buf + 1] = 0 end
      local packed = {}
      for k = 1, #buf, 256 do local m = math.min(256, #buf - k + 1); packed[#packed + 1] = string.pack('<' .. ('f'):rep(m), table.unpack(buf, k, k + m - 1)) end
      parts[#parts + 1] = table.concat(packed)
      spans[#spans + 1] = { z = z, a = cursor, n = n }
      cursor = cursor + n + gap
    end
    local raw = tmp .. '/' .. inst .. '.f32'
    local f = assert(io.open(raw, 'wb')); f:write(table.concat(parts)); f:close()
    local cut = unpackF32(table.concat(parts), channels)
    for _, kbps in ipairs(rates) do
      local ogg = ('%s/%s-%d.ogg'):format(tmp, inst, kbps)
      os.execute(('ffmpeg -v error -nostdin -y -f f32le -ar 48000 -ac %d -i %s -c:a libopus -b:a %dk -vbr on -application audio -frame_duration 20 %s'):format(channels, q(raw), kbps, q(ogg)))
      local enc = unpackF32(decode(ogg, '-ac ' .. channels .. ' -ar 48000'), channels)
      local snrs, msnrs, bws, bwe, pre = {}, {}, {}, {}, -math.huge
      for _, sp in ipairs(spans) do
        local pad = math.floor(0.012 * RATE)
        local s, e = {}, {}
        for i = 1, sp.n + pad do
          local k = sp.a + i - pad
          local a, b = 0, 0
          for c = 1, channels do a = a + (cut[c][k] or 0); b = b + (enc[c][k] or 0) end
          s[i], e[i] = a / channels, b / channels
        end
        local snr, b1, b2, p, ms = compare(s, e, sp.z.art == 'hit' or sp.z.art == 'stac')
        snrs[#snrs + 1] = snr; msnrs[#msnrs + 1] = ms; bws[#bws + 1] = b1; bwe[#bwe + 1] = b2
        if p and p > pre then pre = p end
      end
      table.sort(snrs); table.sort(msnrs); table.sort(bws); table.sort(bwe)
      io.write(('%s\t%d\t%d\t%s\t%s\t%s\t%s\t%s\t%s\n'):format(inst, channels, kbps, fmt(snrs[(#snrs + 1) // 2]), fmt(msnrs[(#msnrs + 1) // 2]), fmt(msnrs[1]), fmt(bws[(#bws + 1) // 2], 0),
        fmt(bwe[(#bwe + 1) // 2], 0), fmt(pre)))
      io.stdout:flush()
      os.remove(ogg)
    end
    os.remove(raw)
  end
  os.exit(0)
end

-- ===== 5. shift: the runtime's pitch shift, linear interpolation (the offline renderer's AudioBufferSourceNode)
-- against a high-quality resample of the same zone, at the semitone shifts the score plays (--shifts -7,-5,-3,-1,1,3).
if mode == 'shift' then
  assert(pcmDir, '--pcm DIR')
  local tmp = opts.tmp or (home .. '/.cache/tillandsias-project/tmp/bank-audit')
  os.execute('mkdir -p ' .. q(tmp))
  local shifts = {}
  for v in (opts.shifts or '-7,-5,-3,-1.5,1.5,3'):gmatch('[-%d.]+') do shifts[#shifts + 1] = tonumber(v) end
  local want = {}
  for id in (opts.inst or ''):gmatch('[^,]+') do want[id] = true end
  io.write('inst\tzone\tsemitones\tmag_snr_db\n')
  local rows = {}
  for _, z in ipairs(zonesBySprite()) do
    if want[z.inst] and z.root and z.rr == 1 then
      local x = mono(slice(sprite(z.sprite, 'pcm'), z))
      local raw = tmp .. '/zone.f32'
      local packed = {}
      for k = 1, #x, 256 do local m = math.min(256, #x - k + 1); packed[#packed + 1] = string.pack('<' .. ('f'):rep(m), table.unpack(x, k, k + m - 1)) end
      local fh = assert(io.open(raw, 'wb')); fh:write(table.concat(packed)); fh:close()
      for _, st in ipairs(shifts) do
        local r = 2 ^ (st / 12)
        -- Linear: y[k] = x(k r), as offline-audio.mjs's BufferSource.
        local lin, pos = {}, 0
        while pos < #x - 1 do local k = math.floor(pos); local fr = pos - k; lin[#lin + 1] = x[k + 1] + (x[k + 2] - x[k + 1]) * fr; pos = pos + r end
        -- Reference: the zone declared at 48 kHz x r and resampled to 48 kHz by the high-quality converter.
        local ref = unpackF32(sh(('ffmpeg -v error -nostdin -f f32le -ar %d -ac 1 -i %s -af aresample=48000:filter_size=256:phase_shift=14:cutoff=0.97:kaiser_beta=12 -f f32le -'):format(
          math.floor(RATE * r + 0.5), q(raw))), 1)[1]
        local n = math.min(#lin, #ref)
        local a1, b1 = {}, {}
        for i = 1, n do a1[i] = ref[i]; b1[i] = lin[i] end
        local _, _, _, _, ms = compare(a1, b1, false)
        rows[#rows + 1] = { inst = z.inst .. ' ' .. st, ms = ms }
        io.write(('%s\t%s\t%s\t%s\n'):format(z.inst, z.id, st, fmt(ms)))
      end
    end
  end
  summarise(rows, { 'ms' })
  os.exit(0)
end

say('usage: lua tools/bank/bank_audit.lua sources|resample|cut|encode|bitrate [--bank FILE] [--pcm DIR] [--src DIR]')
os.exit(2)
