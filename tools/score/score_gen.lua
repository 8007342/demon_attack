#!/usr/bin/env lua
-- score_gen.lua: the MIDI-first score generator (adaptive-soundtrack design §11.3, §11.6 route A, §11.9 gates).
--
-- Reads the song map (art/music/soundtrack/song-map.json), composes every listed section with the song's
-- composer (tools/score/songs/*.lua, original writing from the game's motifs), gates each section, and writes:
--   web/audio/score/<song>/<section>.mid   SMF type 1, PPQ from the map: a conductor track (tempo, 4/4, key,
--                                          section marker, a `hold` marker where a tail's hold bars begin) and
--                                          one track per part, named by its song-map track id
--   web/audio/score/score.json             the map as the web player reads it (songs, sections, masks, layers,
--                                          stingers, accents, file sizes and sha256)
--   lib/game/song_map.dart                 the same sections as const data for SongDirector (pure Dart)
-- Gates (exit 1 on failure): whole bars, onsets on the 1/16 or triplet grid, out-of-scale share <= 3 % (songs
-- marked `chromatic` only report it), every track known to the map, peak voices <= 32 with a 0.5-beat release
-- with every track sounding. Deterministic: the same map gives byte-identical outputs.
--
-- Run from the repo root:  lua tools/score/score_gen.lua            (write and gate)
--                          lua tools/score/score_gen.lua --check    (gate and compare with the committed files)
local here = arg[0]:match('^(.*)/[^/]*$') or '.'
package.path = here .. '/?.lua;' .. package.path
local json = require 'json'
local A = require 'arrange'

local check = arg[1] == '--check'
local function read(path) local f = assert(io.open(path, 'rb')); local s = f:read('a'); f:close(); return s end
local function write(path, data)
  if check then
    local f = io.open(path, 'rb')
    local old = f and f:read('a'); if f then f:close() end
    if old ~= data then io.stderr:write('differs: ' .. path .. '\n'); return false end
    return true
  end
  os.execute(('mkdir -p %q'):format(path:match('^(.*)/[^/]*$')))
  local f = assert(io.open(path, 'wb')); f:write(data); f:close()
  return true
end
local function sha256(data)
  local tmp = os.tmpname()
  local f = assert(io.open(tmp, 'wb')); f:write(data); f:close()
  local p = assert(io.popen(('sha256sum %q'):format(tmp)))
  local out = p:read('a'); p:close(); os.remove(tmp)
  return out:match('^(%x+)')
end

local map = json.decode(read('art/music/soundtrack/song-map.json'))
local composers = { k = 'songs.krybor', c1 = 'songs.carrier' }
local trackOrder = { 'drums', 'cymbals', 'drums2', 'bass', 'gtrL', 'gtrR', 'clean', 'lead', 'lead2', 'organ',
  'strings', 'brass', 'choir', 'timpani', 'bells', 'fanfare' }
for _, name in ipairs(trackOrder) do assert(map.tracks[name], 'track order names an unknown track ' .. name) end

local failures, report, same = {}, {}, true
local function fail(msg) failures[#failures + 1] = msg end

-- Gates -------------------------------------------------------------------------------------------------------
local function gate(songId, song, id, spec, section)
  local total = (spec.bars + (spec.hold or 0)) * 4
  local key = A.key(spec.key or song.key)
  local inScale = A.scaleSet(key)
  local pitched, outside, notes = 0, 0, 0
  local events = {}
  for name, list in pairs(section.tracks) do
    if not map.tracks[name] then fail(('%s/%s: unknown track %s'):format(songId, id, name)) end
    local drums = map.tracks[name] and map.tracks[name].channel == 9
    local ends = A.soundingEnds(list, map.tracks[name] and map.tracks[name].role)
    for i, n in ipairs(list) do
      notes = notes + 1
      if n.t < -1e-9 or n.t + n.len > total + 1e-9 then fail(('%s/%s: %s note at %.3f beyond the whole bars'):format(songId, id, name, n.t)) end
      local q16, q3 = n.t * 4, n.t * 3
      if math.abs(q16 - math.floor(q16 + 0.5)) > 1e-6 and math.abs(q3 - math.floor(q3 + 0.5)) > 1e-6 then
        fail(('%s/%s: %s onset %.4f off the grid'):format(songId, id, name, n.t))
      end
      if not drums then
        pitched = pitched + 1
        if not inScale[n.p % 12] then outside = outside + 1 end
      end
      events[#events + 1] = { n.t, 1 }
      events[#events + 1] = { ends[i], -1 }
    end
  end
  table.sort(events, function(a, b) if a[1] ~= b[1] then return a[1] < b[1] end; return a[2] < b[2] end)
  local voices, peak, peakAt = 0, 0, 0
  for _, e in ipairs(events) do
    voices = voices + e[2]
    if voices > peak then peak, peakAt = voices, e[1] end
  end
  local share = pitched > 0 and outside / pitched or 0
  if share > 0.03 and not (song.chromatic or spec.chromatic) then fail(('%s/%s: %.1f %% of the notes are out of %s'):format(songId, id, share * 100, spec.key or song.key)) end
  if peak > 32 then fail(('%s/%s: peak %d voices at bar %d (limit 32 with a 0.5-beat release)'):format(songId, id, peak, peakAt // 4 + 1)) end
  return { notes = notes, peak = peak, peakBar = peakAt // 4 + 1, outside = share }
end

-- Compose and write -------------------------------------------------------------------------------------------
local out = { schema = 'demon-attack.score/v1', comment = 'GENERATED by tools/score/score_gen.lua from art/music/soundtrack/song-map.json; do not edit.',
  ppq = map.ppq, dwellBars = map.dwellBars, tracks = map.tracks, masks = map.masks, layers = map.layers, plays = map.plays,
  stingers = {}, accents = map.accents, songs = {} }
for name, st in pairs(map.stingers) do if name ~= 'comment' then out.stingers[name] = st end end

local songIds = {}
for id in pairs(map.songs) do songIds[#songIds + 1] = id end
table.sort(songIds)
local totalBytes = 0
for _, songId in ipairs(songIds) do
  local song = map.songs[songId]
  local compose = require(assert(composers[songId], 'no composer for song ' .. songId))
  local sections = compose(A, song, map.seed)
  local key = A.key(song.key)
  local songOut = { name = song.name, form = song.form, key = song.key, tonic = key.tonic, mode = key.mode, bpm = song.bpm,
    barSamples = song.barSamples, sections = {} }
  if song.masks then songOut.masks = song.masks end
  local ids = {}
  for id in pairs(song.sections) do ids[#ids + 1] = id end
  table.sort(ids)
  for _, id in ipairs(ids) do
    local spec = song.sections[id]
    local section = assert(sections[id], ('%s: composer wrote no section %s'):format(songId, id))
    section:tidy((spec.bars + (spec.hold or 0)) * 4)
    section:articulate(map.tracks)
    local stats = gate(songId, song, id, spec, section)
    local sk = A.key(spec.key or song.key)
    local bytes, names = A.smf(section, { ppq = map.ppq, total = (spec.bars + (spec.hold or 0)) * 4, barSamples = song.barSamples,
      key = sk, title = ('%s %s'):format(song.name, id), hold = spec.hold, order = trackOrder, tracks = map.tracks })
    local file = ('%s/%s.mid'):format(songId, id)
    same = write('web/audio/score/' .. file, bytes) and same
    totalBytes = totalBytes + #bytes
    local entry = { file = file, kind = spec.kind, bars = spec.bars, hold = spec.hold or 0, next = spec.next, mask = spec.mask,
      masks = spec.masks, wave = spec.wave, hatch = spec.hatch, tracks = names, bytes = #bytes, sha256 = sha256(bytes) }
    if spec.key then entry.tonic, entry.mode = sk.tonic, sk.mode end
    songOut.sections[id] = entry
    for _, name in ipairs(names) do
      local known = false
      for _, list in pairs(map.masks) do for _, t in ipairs(list) do if t == name then known = true end end end
      for _, list in pairs(map.layers) do for _, t in ipairs(list) do if t == name then known = true end end end
      if not known then fail(('%s/%s: track %s is in no mask or layer'):format(songId, id, name)) end
    end
    report[#report + 1] = ('%-4s %-10s %-6s %2d+%d bars  %5d notes  peak %2d voices (bar %d)  out-of-key %4.1f %%  %6d B'):format(
      songId, id, spec.kind, spec.bars, spec.hold or 0, stats.notes, stats.peak, stats.peakBar, stats.outside * 100, #bytes)
  end
  for id, spec in pairs(song.sections) do
    if spec.next and not song.sections[spec.next] then fail(('%s/%s: next %s does not exist'):format(songId, id, spec.next)) end
    if spec.kind == 'bridge' and not spec.next then fail(('%s/%s: a bridge needs next'):format(songId, id)) end
  end
  out.songs[songId] = songOut
end
same = write('web/audio/score/score.json', json.encode(out, { indent = ' ' }) .. '\n') and same

-- Dart const data for SongDirector ------------------------------------------------------------------------------
local dart = { [[
// GENERATED by tools/score/score_gen.lua from art/music/soundtrack/song-map.json.
// Do not edit: change the song map and rerun `lua tools/score/score_gen.lua`.
//
// The score's section graph as const data for SongDirector (pure Dart, no
// dart:ui). The web player reads the same map from web/audio/score/score.json.

/// How a section plays: [loop] repeats until a move, [tail] plays once and
/// then repeats its hold bars (or hands over to its next section), [bridge]
/// plays once and always hands over to its next section.
enum ScoreKind { loop, tail, bridge }

class ScoreSection {
  const ScoreSection(
    this.id,
    this.kind,
    this.bars, {
    this.hold = 0,
    this.next,
    this.wave,
    this.hatch,
  });
  final String id;
  final ScoreKind kind;
  final int bars;

  /// Bars after [bars] that repeat while a tail waits (a held pad).
  final int hold;
  final String? next;

  /// Order of a sector's wave-progress section (1 = A).
  final int? wave;

  /// Number of a carrier hatch section (1 = H1).
  final int? hatch;
}

class ScoreSong {
  const ScoreSong(
    this.id,
    this.name,
    this.form,
    this.barSamples,
    this.sections,
  );
  final String id;
  final String name;

  /// 'sector' or 'carrier'.
  final String form;

  /// Samples per 4/4 bar at 48 kHz (the song's grid).
  final int barSamples;
  final Map<String, ScoreSection> sections;

  double get barSeconds => barSamples / 48000;
  double get beatSeconds => barSeconds / 4;

  /// The wave-progress sections in order (A, B, C, D).
  List<ScoreSection> get waveSections =>
      sections.values.where((s) => s.wave != null).toList()
        ..sort((a, b) => a.wave!.compareTo(b.wave!));

  /// The hatch sections in order (H1, H2, ...).
  List<ScoreSection> get hatchSections =>
      sections.values.where((s) => s.hatch != null).toList()
        ..sort((a, b) => a.hatch!.compareTo(b.hatch!));
}
]] }
dart[#dart + 1] = ('\n/// A request inside %d bars of the last section start waits for them.\nconst scoreDwellBars = %d;\n'):format(map.dwellBars, map.dwellBars)
local plays = {}
for _, p in ipairs(map.plays) do plays[#plays + 1] = ("%d: '%s'"):format(p.level, p.song) end
local playsLine = 'const scorePlays = <int, String>{' .. table.concat(plays, ', ') .. '};'
if #playsLine > 80 then playsLine = 'const scorePlays = <int, String>{\n  ' .. table.concat(plays, ',\n  ') .. ',\n};' end
dart[#dart + 1] = '\n/// Which song a sector plays (sectors not listed play the recorded cues).\n' .. playsLine .. '\n'
dart[#dart + 1] = '\nconst scoreSongs = <String, ScoreSong>{\n'
for _, songId in ipairs(songIds) do
  local song = map.songs[songId]
  dart[#dart + 1] = ('  %q: ScoreSong(%q, %q, %q, %d, {\n'):format(songId, songId, song.name, song.form, song.barSamples)
  local ids = {}
  for id in pairs(song.sections) do ids[#ids + 1] = id end
  table.sort(ids)
  for _, id in ipairs(ids) do
    local s = song.sections[id]
    local named = {}
    if (s.hold or 0) > 0 then named[#named + 1] = ('hold: %d'):format(s.hold) end
    if s.next then named[#named + 1] = ('next: %q'):format(s.next) end
    if s.wave then named[#named + 1] = ('wave: %d'):format(s.wave) end
    if s.hatch then named[#named + 1] = ('hatch: %d'):format(s.hatch) end
    -- dart format's layout: one line when it fits in 80 columns, else one argument per line.
    local args = { ("'%s'"):format(id), 'ScoreKind.' .. s.kind, tostring(s.bars) }
    for _, n in ipairs(named) do args[#args + 1] = (n:gsub('"', "'")) end
    local line = ("    '%s': ScoreSection(%s),"):format(id, table.concat(args, ', '))
    if #line > 80 then line = ("    '%s': ScoreSection(\n      %s,\n    ),"):format(id, table.concat(args, ',\n      ')) end
    dart[#dart + 1] = line .. '\n'
  end
  dart[#dart + 1] = '  }),\n'
end
dart[#dart + 1] = '};\n'
same = write('lib/game/song_map.dart', (table.concat(dart):gsub('"', "'"))) and same

for _, line in ipairs(report) do print(line) end
print(('total %d B of MIDI in %d sections'):format(totalBytes, #report))
if #failures > 0 then
  for _, f in ipairs(failures) do io.stderr:write('GATE: ' .. f .. '\n') end
  os.exit(1)
end
if check and not same then io.stderr:write('outputs differ from the committed files\n'); os.exit(1) end
