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

local release = 0
local files = {}
local i = 1
while i <= #arg do
  if arg[i] == '--release' then release = tonumber(arg[i + 1]); i = i + 2
  else files[#files + 1] = arg[i]; i = i + 1 end
end
if #files == 0 then io.stderr:write('usage: lua tools/midi_stats.lua [--release BEATS] FILE.mid …\n'); os.exit(2) end

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
          table.insert(open[key], tick)
          t.channels[ch] = true
        elseif kind == 0x80 or kind == 0x90 then
          local key = ch * 128 + d1
          local stack = open[key]
          if stack and #stack > 0 then
            local on = table.remove(stack, 1)
            t.notes[#t.notes + 1] = { on = on, off = tick, pitch = d1, ch = ch }
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
