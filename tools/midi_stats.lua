#!/usr/bin/env lua
-- midi_stats.lua: measure a Standard MIDI File for the MIDI-first soundtrack (adaptive-soundtrack design §11).
--
-- Reports, per track and in total: notes, channels, pitch range, peak simultaneous notes (the sampler's voice
-- demand), and length in beats and bars, plus the file size. Pure Lua 5.4, no libraries; reads SMF type 0 and 1.
--
-- Run:  lua tools/midi_stats.lua FILE.mid [FILE.mid …]
--       lua tools/midi_stats.lua --release 0.25 FILE.mid   (count a note as sounding 0.25 beats past its note-off,
--                                                            a rough stand-in for sample release tails)
-- Out:  one block per file; the last line of each block is `total …` with the peak voices.
--
-- Gate (task 8.10, design §11.9): `lua tools/midi_stats.lua check [--score DIR] [--map FILE] [--bank FILE]
-- [--strict-zones]` checks every section of the committed score (DIR/score.json, default web/audio/score):
--   - whole bars: the file ends exactly on (bars + hold) bars and no note sounds past it;
--   - grid: every onset within 12 ms (at the song's tempo) of the 1/16 or the triplet grid;
--   - key: out-of-scale notes <= 3 % (songs or sections marked `chromatic` in the song map only report it);
--   - zone ranges: every note against the sample bank (DIR/../bank/bank.json once built, else the planned zones of
--     art/music/bank/recipe.json): roles the recipe marks `cover: full` must be covered note for note (all of them
--     with --strict-zones); the rest report their coverage, and a section's track the bank cannot cover whole plays
--     through the synth voice (the sampler's own rule);
--   - peak voices <= 32 with a 0.5-beat release and the score's voice rules (a key struck again chokes, lead and
--     bass are monophonic), every track sounding;
--   - sizes recorded (the file against score.json's bytes).
-- Exit 1 with the failures listed; the last line is `check: ok …` or `check: FAILED …`.

local release = 0
local files = {}
local i = 1
local mode = arg[1] == 'check' and 'check' or 'stats'
local copts = {}
if mode == 'check' then i = 2 end
while i <= #arg do
  if arg[i] == '--release' then release = tonumber(arg[i + 1]); i = i + 2
  elseif mode == 'check' and arg[i] == '--strict-zones' then copts.strict = true; i = i + 1
  elseif mode == 'check' and arg[i]:match('^%-%-') then copts[arg[i]:sub(3)] = arg[i + 1]; i = i + 2
  else files[#files + 1] = arg[i]; i = i + 1 end
end
if mode == 'stats' and #files == 0 then
  io.stderr:write('usage: lua tools/midi_stats.lua [--release BEATS] FILE.mid …\n       lua tools/midi_stats.lua check [--score DIR] [--map FILE] [--bank FILE] [--strict-zones]\n')
  os.exit(2)
end

local function u16(s, p) return (s:byte(p) << 8) | s:byte(p + 1) end
local function u32(s, p) return (s:byte(p) << 24) | (s:byte(p + 1) << 16) | (s:byte(p + 2) << 8) | s:byte(p + 3) end

local function parse(data)
  assert(data:sub(1, 4) == 'MThd', 'not a MIDI file')
  local format, ntracks, division = u16(data, 9), u16(data, 11), u16(data, 13)
  assert(division & 0x8000 == 0, 'SMPTE time division not supported')
  local pos, tracks = 9 + u32(data, 5), {}
  for _ = 1, ntracks do
    assert(data:sub(pos, pos + 3) == 'MTrk', 'missing track chunk')
    local len = u32(data, pos + 4)
    local p, stop, tick, status = pos + 8, pos + 8 + len, 0, 0
    local t = { name = nil, notes = {}, channels = {}, tempo = nil }
    local open = {}
    local function vlq()
      local n = 0
      repeat local b = data:byte(p); p = p + 1; n = (n << 7) | (b & 127) until b < 128
      return n
    end
    while p < stop do
      tick = tick + vlq()
      local b = data:byte(p)
      if b >= 0x80 then status = b; p = p + 1 end
      if status == 0xff then
        local kind = data:byte(p); p = p + 1
        local size = vlq()
        if kind == 0x03 then t.name = data:sub(p, p + size - 1) end
        if kind == 0x51 then t.tempo = (data:byte(p) << 16) | (data:byte(p + 1) << 8) | data:byte(p + 2) end
        p = p + size
        if kind == 0x2f then break end
      elseif status == 0xf0 or status == 0xf7 then
        p = p + vlq()
      else
        local kind, ch = status & 0xf0, status & 0x0f
        local two = not (kind == 0xc0 or kind == 0xd0)
        local d1 = data:byte(p); local d2 = two and data:byte(p + 1) or 0
        p = p + (two and 2 or 1)
        if kind == 0x90 and d2 > 0 then
          local key = ch * 128 + d1
          open[key] = open[key] or {}
          table.insert(open[key], { tick, d2 })
          t.channels[ch] = true
        elseif kind == 0x80 or kind == 0x90 then
          local key = ch * 128 + d1
          local stack = open[key]
          if stack and #stack > 0 then
            local on = table.remove(stack, 1)
            t.notes[#t.notes + 1] = { on = on[1], off = tick, pitch = d1, ch = ch, vel = on[2] }
          end
        end
      end
    end
    t.ticks = tick
    tracks[#tracks + 1] = t
    pos = stop
  end
  return { format = format, division = division, tracks = tracks }
end

-- Peak overlap of [on, off + tail) intervals.
local function peak(notes, tail)
  local ev = {}
  for _, n in ipairs(notes) do
    ev[#ev + 1] = { n.on, 1 }
    ev[#ev + 1] = { n.off + tail, -1 }
  end
  table.sort(ev, function(a, b) if a[1] ~= b[1] then return a[1] < b[1] end return a[2] < b[2] end)
  local cur, best = 0, 0
  for _, e in ipairs(ev) do cur = cur + e[2]; if cur > best then best = cur end end
  return best
end

if mode == 'check' then
  local here = (arg[0]:match('^(.*)/[^/]*$')) or '.'
  package.path = here .. '/score/?.lua;' .. here .. '/bank/?.lua;' .. package.path
  local json = require 'json'
  local A = require 'arrange'
  local B = require 'bank'
  local scoreDir = copts.score or 'web/audio/score'
  local function readFile(path) local f = io.open(path, 'rb'); if not f then return nil end; local d = f:read('a'); f:close(); return d end
  local score = json.decode(assert(readFile(scoreDir .. '/score.json'), 'no ' .. scoreDir .. '/score.json'))
  local map = json.decode(assert(readFile(copts.map or 'art/music/soundtrack/song-map.json'), 'no song map'))
  -- The bank: the built bank.json, else the recipe's plan.
  local bankPath = copts.bank or (scoreDir .. '/../bank/bank.json')
  local bankText = readFile(bankPath)
  local roles, plan, bankWhat
  if bankText then
    local bank = json.decode(bankText)
    roles, plan, bankWhat = bank.roles, { instruments = bank.instruments, zones = bank.zones }, bankPath
  else
    local recipe, rows, keys = B.load('art/music/bank/recipe.json')
    local errors
    plan, errors = B.plan(recipe, rows, keys)
    assert(#errors == 0, 'bank plan: ' .. table.concat(errors, '; '))
    roles, bankWhat = recipe.roles, 'art/music/bank/recipe.json (planned; no bank built)'
  end
  local phonePlan = { instruments = plan.instruments, zones = {} }
  for _, z in ipairs(plan.zones) do if z.phone then phonePlan.zones[#phonePlan.zones + 1] = z end end
  local recipeLike = { roles = roles }
  local failures, cover, pairs_ = {}, {}, { sampled = 0, synth = 0, phoneSampled = 0 }
  local sections, bytes, peakMax = 0, 0, 0
  local function fail(msg) failures[#failures + 1] = msg end
  local songIds = {}
  for id in pairs(score.songs) do songIds[#songIds + 1] = id end
  table.sort(songIds)
  for _, songId in ipairs(songIds) do
    local song, mapSong = score.songs[songId], map.songs[songId] or { sections = {} }
    local beatSec = song.barSamples / 48000 / 4
    local ids = {}
    for id in pairs(song.sections) do ids[#ids + 1] = id end
    table.sort(ids)
    for _, id in ipairs(ids) do
      local spec, mspec = song.sections[id], mapSong.sections[id] or {}
      local where = songId .. '/' .. id
      local data = readFile(scoreDir .. '/' .. spec.file)
      if not data then fail(where .. ': missing ' .. spec.file) else
        sections = sections + 1
        bytes = bytes + #data
        if spec.bytes and spec.bytes ~= #data then fail(('%s: %d bytes, score.json says %d'):format(where, #data, spec.bytes)) end
        local smf = parse(data)
        local ppq = smf.division
        local total = (spec.bars + (spec.hold or 0)) * 4 * ppq
        local last = 0
        for _, t in ipairs(smf.tracks) do if t.ticks > last then last = t.ticks end end
        if last ~= total then fail(('%s: ends at beat %.3f, not on its %d whole bars'):format(where, last / ppq, spec.bars + (spec.hold or 0))) end
        local key = A.key(mspec.key or mapSong.key or song.key)
        local inScale = A.scaleSet(key)
        local pitched, outside, events = 0, 0, {}
        for _, t in ipairs(smf.tracks) do
          if #t.notes > 0 then
            local role = score.tracks[t.name] and score.tracks[t.name].role
            if not role then fail(('%s: track %s is not in score.json'):format(where, tostring(t.name))) end
            local list = {}
            for _, n in ipairs(t.notes) do list[#list + 1] = { t = n.on / ppq, len = (n.off - n.on) / ppq, p = n.pitch, v = n.vel or 100, ch = n.ch } end
            table.sort(list, function(a, b) if a.t ~= b.t then return a.t < b.t end; return a.p < b.p end)
            local ends = A.soundingEnds(list, role)
            local all, allPhone = true, true
            local c = cover[role or '?'] or { notes = 0, covered = 0, phone = 0 }
            cover[role or '?'] = c
            for k, n in ipairs(list) do
              if n.t * ppq + n.len * ppq > total + 1e-6 then fail(('%s: %s note at beat %.3f sounds past the whole bars'):format(where, t.name, n.t)) end
              local g16, g3 = math.floor(n.t * 4 + 0.5) / 4, math.floor(n.t * 3 + 0.5) / 3
              local err = math.min(math.abs(n.t - g16), math.abs(n.t - g3)) * beatSec
              if err > 0.012 then fail(('%s: %s onset at beat %.4f is %.1f ms off the grid'):format(where, t.name, n.t, err * 1000)) end
              if n.ch ~= 9 then pitched = pitched + 1; if not inScale[n.p % 12] then outside = outside + 1 end end
              events[#events + 1] = { n.t, 1 }; events[#events + 1] = { ends[k], -1 }
              if role and roles[role] then
                c.notes = c.notes + 1
                local covered = B.covering(recipeLike, plan, role, n.p, n.v, n.len * beatSec)
                if covered then c.covered = c.covered + 1 else
                  all = false
                  if roles[role].cover == 'full' or copts.strict then fail(('%s: %s %s note %d (vel %d) has no bank zone'):format(where, t.name, role, n.p, n.v)) end
                end
                if B.covering(recipeLike, phonePlan, role, n.p, n.v, n.len * beatSec) then c.phone = c.phone + 1 else allPhone = false end
              end
            end
            if role and roles[role] then
              if all then pairs_.sampled = pairs_.sampled + 1 else pairs_.synth = pairs_.synth + 1 end
              if allPhone then pairs_.phoneSampled = pairs_.phoneSampled + 1 end
            end
          end
        end
        table.sort(events, function(a, b) if a[1] ~= b[1] then return a[1] < b[1] end; return a[2] < b[2] end)
        local voices, peakV, peakAt = 0, 0, 0
        for _, e in ipairs(events) do voices = voices + e[2]; if voices > peakV then peakV, peakAt = voices, e[1] end end
        if peakV > peakMax then peakMax = peakV end
        if peakV > 32 then fail(('%s: peak %d voices at bar %d (limit 32 with a 0.5-beat release)'):format(where, peakV, peakAt // 4 + 1)) end
        local share = pitched > 0 and outside / pitched or 0
        local chromatic = mapSong.chromatic or mspec.chromatic
        if share > 0.03 and not chromatic then fail(('%s: %.1f %% of the notes are out of %s'):format(where, share * 100, mspec.key or mapSong.key)) end
        print(string.format('  %-18s %3d bars  %6d B  peak %2d  out of key %4.1f %%%s', where, spec.bars + (spec.hold or 0), #data, peakV, share * 100,
          chromatic and ' (chromatic)' or ''))
      end
    end
  end
  print(('bank: %s'):format(bankWhat))
  local roleNames = {}
  for r in pairs(cover) do if roles[r] then roleNames[#roleNames + 1] = r end end
  table.sort(roleNames)
  for _, r in ipairs(roleNames) do
    local c = cover[r]
    print(string.format('  zones %-8s %5d notes  %5.1f %% covered (%5.1f %% on phones)%s', r, c.notes, 100 * c.covered / math.max(1, c.notes),
      100 * c.phone / math.max(1, c.notes), roles[r].cover == 'full' and '  [full]' or ''))
  end
  print(string.format('  section tracks the bank plays whole: %d of %d (%d on phones); the rest play the synth voice', pairs_.sampled,
    pairs_.sampled + pairs_.synth, pairs_.phoneSampled))
  for _, f in ipairs(failures) do print('FAIL ' .. f) end
  print(string.format('check: %s  %d sections, %d B of MIDI, peak %d voices, %d failure(s)', #failures == 0 and 'ok' or 'FAILED',
    sections, bytes, peakMax, #failures))
  os.exit(#failures == 0 and 0 or 1)
end

for _, file in ipairs(files) do
  local fh = assert(io.open(file, 'rb'))
  local data = fh:read('a'); fh:close()
  local smf = parse(data)
  local tail = math.floor(release * smf.division + 0.5)
  local all, ticks, tempo = {}, 0, nil
  print(string.format('%s  (%d bytes, SMF type %d, %d tracks, PPQ %d)', file, #data, smf.format, #smf.tracks, smf.division))
  for idx, t in ipairs(smf.tracks) do
    tempo = tempo or t.tempo
    if t.ticks > ticks then ticks = t.ticks end
    if #t.notes > 0 then
      local lo, hi, chs = 127, 0, {}
      for _, n in ipairs(t.notes) do
        if n.pitch < lo then lo = n.pitch end
        if n.pitch > hi then hi = n.pitch end
        all[#all + 1] = n
      end
      for ch in pairs(t.channels) do chs[#chs + 1] = ch + 1 end
      table.sort(chs)
      print(string.format('  track %2d %-12s ch %-6s notes %5d  range %3d-%3d  peak voices %3d', idx - 1,
        t.name or '-', table.concat(chs, ','), #t.notes, lo, hi, peak(t.notes, tail)))
    end
  end
  local beats = ticks / smf.division
  local bpm = tempo and 60e6 / tempo or 120
  print(string.format('  total notes %d  beats %.1f  bars(4/4) %.1f  bpm %.2f  seconds %.1f  bytes/s %.0f  peak voices %d',
    #all, beats, beats / 4, bpm, beats * 60 / bpm, #data / math.max(1e-9, beats * 60 / bpm), peak(all, tail)))
end
