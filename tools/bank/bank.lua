-- bank.lua: the CC0 sample bank's plan (adaptive-soundtrack design §11.4, §12.9; task 8.5), shared by
-- tools/bank/bank_build.lua (the builder) and tools/midi_stats.lua check (the zone-range gate).
--
-- Pure Lua 5.4 (json from tools/score/json.lua). It reads the pin manifest (TSV), the recipe (JSON) and the SFZ
-- keycenters (JSON, made from the pinned SFZ maps by `bank_build.lua --sync-keys`), and plans one zone per manifest
-- file: instrument, roles, articulation, root, key range, velocity range, round robin, load tier, phone tier and its
-- sprite. Nothing here reads audio; the builder adds the measured lengths, offsets, f0 checks and hashes.
local here = (debug.getinfo(1, 'S').source:match('^@(.*)/[^/]*$')) or '.'
package.path = here .. '/../score/?.lua;' .. package.path
local json = require 'json'

local B = { json = json }

function B.read(path)
  local f, err = io.open(path, 'rb')
  if not f then return nil, err end
  local s = f:read('a'); f:close(); return s
end

-- The pin manifest: repo, commit, group, path, bytes, git_blob_sha1, raw_url (tab-separated, one header row).
function B.manifest(text)
  local rows, header = {}, nil
  for line in text:gmatch('[^\n]+') do
    local cols = {}
    for col in (line .. '\t'):gmatch('([^\t]*)\t') do cols[#cols + 1] = col end
    if not header then header = cols
    else
      local row = {}
      for i, name in ipairs(header) do row[name] = cols[i] end
      row.bytes = tonumber(row.bytes)
      rows[#rows + 1] = row
    end
  end
  return rows
end

-- Note names: a letter, an optional accidental (# or b), an octave. `scientific` is C4 = 60, `yamaha` C3 = 60.
local pcs = { c = 0, d = 2, e = 4, f = 5, g = 7, a = 9, b = 11 }
function B.noteNumber(name, convention)
  local letter, acc, oct = name:match('^(%a)([#b]?)(%-?%d+)$')
  if not letter then return nil end
  local pc = pcs[letter:lower()]
  if acc == '#' then pc = pc + 1 elseif acc == 'b' then pc = pc - 1 end
  return 12 * (tonumber(oct) + (convention == 'yamaha' and 2 or 1)) + pc
end

-- SFZ: headers <control> <global> <master> <group> <region>, opcodes key=value (a value runs to the next opcode on
-- its line, so sample paths keep their spaces), `//` comments. Returns the regions, each merged over the
-- control/global/master/group opcodes in force where it is declared, with `path` resolved (default_path + sample).
function B.sfz(text)
  local levels = { control = {}, global = {}, master = {}, group = {} }
  local order = { 'control', 'global', 'master', 'group' }
  local out, region, target = {}, nil, nil
  local function flush() if region then out[#out + 1] = region; region = nil end end
  local function startRegion()
    flush()
    region = {}
    for _, name in ipairs(order) do for k, v in pairs(levels[name]) do region[k] = v end end
    target = region
  end
  for line in (text .. '\n'):gmatch('([^\n]*)\n') do
    line = line:gsub('\r', ''):gsub('//.*$', '')
    local pos = 1
    while pos <= #line do
      local hs, he, header = line:find('<(%w+)>', pos)
      local os_, _, key = line:find('([%w_]+)=', pos)
      if hs and (not os_ or hs < os_) then
        if header == 'region' then startRegion()
        else
          flush()
          local on = false
          for _, name in ipairs(order) do if name == header then on = true end; if on then levels[name] = {} end end
          target = levels[header] or {}
        end
        pos = he + 1
      elseif os_ then
        local vstart = os_ + #key + 1
        local stop = #line
        local n1 = line:find('%s[%w_]+=', vstart)
        local n2 = line:find('<%w+>', vstart)
        if n1 and n1 - 1 < stop then stop = n1 - 1 end
        if n2 and n2 - 1 < stop then stop = n2 - 1 end
        local value = line:sub(vstart, stop):match('^%s*(.-)%s*$')
        if target then target[key] = value end
        pos = stop + 1
      else break end
    end
  end
  flush()
  -- Resolve each region's sample path: default_path + sample, backslashes to slashes, no leading ./ or ../.
  for _, r in ipairs(out) do
    if r.sample then
      local p = ((r.default_path or '') .. r.sample):gsub('\\', '/')
      repeat local before = p; p = p:gsub('^%./', ''):gsub('^%.%./', '') until p == before
      r.path = p
    end
  end
  return out
end

-- The keycenters of the manifest's files from the SFZ maps: { [repo] = { [path] = { keycenter, lokey, hikey, map } } }.
-- `maps` is a list of { repo, path, text }. A file mapped twice must agree on its keycenter.
function B.keysFromMaps(rows, maps)
  local byRepo = {}
  for _, row in ipairs(rows) do byRepo[row.repo] = byRepo[row.repo] or {}; byRepo[row.repo][row.path] = row end
  local keys, errors = {}, {}
  for _, m in ipairs(maps) do
    for _, r in ipairs(B.sfz(m.text)) do
      local files = byRepo[m.repo] or {}
      local row = r.path and files[r.path]
      -- A region without pitch_keycenter plays at the SFZ default, 60 (Growlybass's c4 regions set none; their
      -- lokey/hikey 59-61 agree). The builder's f0 check confirms every root anyway.
      if row then
        keys[m.repo] = keys[m.repo] or {}
        local k = { keycenter = tonumber(r.pitch_keycenter) or 60, lokey = tonumber(r.lokey), hikey = tonumber(r.hikey), map = m.path,
          default = not r.pitch_keycenter or nil }
        local old = keys[m.repo][r.path]
        if old and old.keycenter ~= k.keycenter then
          errors[#errors + 1] = ('%s %s: keycenter %d in %s, %d in %s'):format(m.repo, r.path, old.keycenter, old.map, k.keycenter, m.path)
        elseif old then
          if k.lokey and (not old.lokey or k.lokey < old.lokey) then old.lokey = k.lokey end
          if k.hikey and (not old.hikey or k.hikey > old.hikey) then old.hikey = k.hikey end
        else keys[m.repo][r.path] = k end
      end
    end
  end
  return keys, errors
end

local function basename(p) return p:match('([^/]+)$') end

-- The plan: zones, instruments and sprites. opts.with = { [instrumentId] = true } builds optional instruments.
-- Returns plan, errors (a list of strings: an empty list means the plan is sound).
function B.plan(recipe, rows, keys, opts)
  opts = opts or {}
  local errors, zones, instruments = {}, {}, {}
  local byGroup = {}
  for _, row in ipairs(rows) do
    if row.group ~= 'doc' then byGroup[row.group] = byGroup[row.group] or {}; table.insert(byGroup[row.group], row) end
  end
  local used = {}
  for index, inst in ipairs(recipe.instruments) do
    for _, g in ipairs(inst.groups) do used[g] = true end
    local build = not inst.skip and (not inst.optional or (opts.with and opts.with[inst.id]))
    if build then
      local list = {}
      for _, g in ipairs(inst.groups) do
        if not byGroup[g] then errors[#errors + 1] = ('%s: no manifest rows in group %s'):format(inst.id, g) end
        for _, row in ipairs(byGroup[g] or {}) do list[#list + 1] = row end
      end
      local parse = inst.parse or {}
      local izones = {}
      for _, row in ipairs(list) do
        local name = basename(row.path)
        local note = parse.note and name:match(parse.note)
        local layer = parse.layer and name:match(parse.layer)
        local rr = tonumber(parse.rr and name:match(parse.rr) or '1')
        if parse.note and not note then errors[#errors + 1] = ('%s: cannot read the note of %s'):format(inst.id, name) end
        if parse.layer and not layer then errors[#errors + 1] = ('%s: cannot read the layer of %s'):format(inst.id, name) end
        local z = { inst = inst.id, roles = inst.roles, art = inst.art, file = name, note = note, layer = layer, rr = rr,
          source = { repo = row.repo, commit = row.commit, path = row.path, bytes = row.bytes, blob = row.git_blob_sha1 },
          channels = inst.channels or 1, trim = inst.trim, order = index,
          -- --- bank-fidelity (design §12.11): the encode rate, end fade, declip and stereo-to-mono pick per instrument.
          kbps = inst.kbps or recipe.kbps[tostring(inst.channels or 1)], fade = inst.fade or recipe.fadeSeconds,
          declip = inst.declip, pick = inst.pick, dc = inst.dc }
        -- Velocity range from the recipe's layer split; one layer covers 1..127.
        if inst.layers then
          local v = inst.layers[layer or '']
          if not v then errors[#errors + 1] = ('%s: layer %s of %s is not in the recipe'):format(inst.id, tostring(layer), name); v = { 1, 127 } end
          z.vlo, z.vhi = v[1], v[2]
        else z.vlo, z.vhi = 1, 127 end
        -- Root: drums keep their keys; pitched zones from the SFZ map, a table in the recipe or the file name.
        if inst.keys then
          z.keys = inst.keys
        else
          local root, rootSource
          if inst.root == 'map' then
            local k = keys and keys[row.repo] and keys[row.repo][row.path]
            if k then root, rootSource = k.keycenter, ('sfz %s pitch_keycenter=%d'):format(k.map, k.keycenter); z.mapLo, z.mapHi = k.lokey, k.hikey
            else errors[#errors + 1] = ('%s: %s has no SFZ keycenter (run bank_build.lua --sync-keys)'):format(inst.id, row.path) end
          elseif inst.root == 'name' then
            root = note and B.noteNumber(note, inst.names)
            rootSource = ('file name %s (%s)'):format(tostring(note), inst.names or 'scientific')
            if not root then errors[#errors + 1] = ('%s: cannot read a pitch from %s'):format(inst.id, name) end
          elseif type(inst.root) == 'table' then
            root = note and inst.root[note]
            rootSource = ('recipe table %s'):format(tostring(note))
            if not root then errors[#errors + 1] = ('%s: no root for %s in the recipe'):format(inst.id, tostring(note)) end
          end
          if root then
            z.root = root + (inst.shift or 0)
            z.rootSource = rootSource .. ((inst.shift or 0) ~= 0 and (' %+d'):format(inst.shift) or '')
          end
        end
        -- Load tier: the instrument's tier for its top layer's first round robin, else 3 (extra layers and round robins).
        local extra = (inst.top and layer ~= inst.top) or rr > 1
        z.tier = extra and 3 or inst.tier
        local phone = inst.phone
        if phone == nil then phone = true end
        if type(phone) == 'table' then
          if phone.maxRoot then phone = (z.root or 0) - (inst.shift or 0) <= phone.maxRoot end
          if type(phone) == 'table' and phone.notes then
            local ok = false
            for _, n in ipairs(phone.notes) do if n == note then ok = true end end
            phone = ok
          end
        end
        z.phone = phone and z.tier < 3
        z.loop = inst.loop
        z.release = inst.release
        z.gainDb = inst.gainDb or 0
        izones[#izones + 1] = z
      end
      -- Key ranges for pitched zones: split halfway between neighbouring roots; the ends reach the recipe's stretch or
      -- the SFZ map's own lokey/hikey, whichever is wider.
      if not inst.keys then
        local roots, seen = {}, {}
        for _, z in ipairs(izones) do if z.root and not seen[z.root] then seen[z.root] = true; roots[#roots + 1] = z.root end end
        table.sort(roots)
        local down, up = (inst.stretch or { 3, 3 })[1], (inst.stretch or { 3, 3 })[2]
        local range = {}
        for i, r in ipairs(roots) do
          local lo = i == 1 and r - down or math.floor((roots[i - 1] + r) / 2) + 1
          local hi = i == #roots and r + up or math.floor((r + roots[i + 1]) / 2)
          range[r] = { lo, hi }
        end
        for _, z in ipairs(izones) do
          if z.root then
            local lo, hi = range[z.root][1], range[z.root][2]
            local shift = inst.shift or 0
            if z.root == roots[1] and z.mapLo then lo = math.min(lo, z.mapLo + shift) end
            if z.root == roots[#roots] and z.mapHi then hi = math.max(hi, z.mapHi + shift) end
            z.lo, z.hi = lo, hi
          end
          z.mapLo, z.mapHi = nil, nil
        end
      end
      table.sort(izones, function(a, b)
        local ka, kb = a.root or (a.keys and a.keys[1]) or 0, b.root or (b.keys and b.keys[1]) or 0
        if ka ~= kb then return ka < kb end
        if a.vlo ~= b.vlo then return a.vlo < b.vlo end
        return a.rr < b.rr
      end)
      for _, z in ipairs(izones) do zones[#zones + 1] = z end
      instruments[#instruments + 1] = { id = inst.id, roles = inst.roles, art = inst.art, when = inst.when, zones = #izones,
        verify = inst.verify, why = inst.why }
    end
  end
  for g in pairs(byGroup) do
    if not used[g] then errors[#errors + 1] = ('manifest group %s is in no instrument'):format(g) end
  end
  -- Sprites: one per (tier, phone, Opus rate, channels), loaded in that order (tier 1 first; phone sprites before
  -- desktop-only). The file name ends in the channel letter (m|s), which tools/mix_meter/page.mjs reads.
  -- --- demon-choir: a recipe's `name` (default `bank`) prefixes its sprites, so a second bank (choir.json) shares the folder.
  local sprites, byKey, prefix = {}, {}, recipe.name or 'bank'
  for i, z in ipairs(zones) do
    z.id = ('%s-%s%s-rr%d'):format(z.inst, tostring(z.root or (z.keys and z.keys[1])), z.layer and ('-' .. z.layer) or '', z.rr)
    local key = ('%d%s%d%s'):format(z.tier, z.phone and 'p' or 'd', z.kbps, z.channels == 2 and 's' or 'm')
    local s = byKey[key]
    if not s then
      s = { key = key, file = ('%s-%s.ogg'):format(prefix, key), tier = z.tier, phone = z.phone, channels = z.channels, kbps = z.kbps, zones = {} }
      byKey[key] = s; sprites[#sprites + 1] = s
    end
    z.sprite = s.file
    s.zones[#s.zones + 1] = i
  end
  table.sort(sprites, function(a, b)
    if a.tier ~= b.tier then return a.tier < b.tier end
    if a.phone ~= b.phone then return a.phone end
    if a.channels ~= b.channels then return a.channels < b.channels end
    return a.kbps < b.kbps
  end)
  return { zones = zones, instruments = instruments, sprites = sprites }, errors
end

-- Sizes from seconds (planned trims in a dry run, measured lengths after a build): Opus at the recipe's rates plus
-- the Ogg overhead, decoded Float32 at 48 kHz, per sprite and per load tier (desktop: every sprite; phone: phone sprites).
function B.estimate(recipe, plan, secondsOf)
  local rate, gap = recipe.rate, recipe.gapSeconds
  local totals = { opusBytes = 0, decodedDesktop = 0, decodedPhone = 0, seconds = 0, zones = #plan.zones, rawBytes = 0 }
  for _, s in ipairs(plan.sprites) do
    local seconds = 0
    for _, i in ipairs(s.zones) do
      local z = plan.zones[i]
      seconds = seconds + secondsOf(z) + gap
      totals.rawBytes = totals.rawBytes + (z.source.bytes or 0)
    end
    s.seconds = seconds
    s.estOpusBytes = math.floor(seconds * (s.kbps or recipe.kbps[tostring(s.channels)]) * 1000 / 8 * (1 + recipe.oggOverhead) + 0.5)
    s.decodedBytes = math.floor(seconds * rate + 0.5) * 4 * s.channels
    totals.opusBytes = totals.opusBytes + (s.bytes or s.estOpusBytes)
    totals.decodedDesktop = totals.decodedDesktop + s.decodedBytes
    if s.phone then totals.decodedPhone = totals.decodedPhone + s.decodedBytes end
    totals.seconds = totals.seconds + seconds
  end
  local over = {}
  for _, k in ipairs({ 'opusBytes', 'decodedDesktop', 'decodedPhone' }) do
    if totals[k] > recipe.budgets[k] then over[#over + 1] = ('%s %d over the budget %d'):format(k, totals[k], recipe.budgets[k]) end
  end
  return totals, over
end

-- Which instrument (and zones) can play a note: the first instrument, in recipe order, whose roles include `role`,
-- whose `when` matches (velMax, durMax in seconds) and which has a zone covering the pitch. Pitched roles test every
-- chord tone (roles[role].chord). Drums match by key. Returns the instrument id or nil.
function B.covering(recipe, plan, role, pitch, vel, seconds)
  local tones = (recipe.roles[role] and recipe.roles[role].chord) or { 0 }
  for _, inst in ipairs(plan.instruments) do
    local fits = false
    for _, r in ipairs(inst.roles) do if r == role then fits = true end end
    local w = inst.when
    if fits and w then
      if w.velMax and vel > w.velMax then fits = false end
      if w.durMax and seconds > w.durMax then fits = false end
    end
    if fits then
      local all = true
      for _, t in ipairs(tones) do
        local p, found = pitch + (role == 'drums' and 0 or t), false
        for _, z in ipairs(plan.zones) do
          if z.inst == inst.id then
            if z.keys then for _, k in ipairs(z.keys) do if k == pitch then found = true end end
            elseif p >= z.lo and p <= z.hi then found = true end
          end
          if found then break end
        end
        if not found then all = false; break end
        if role == 'drums' then break end
      end
      if all then return inst.id end
    end
  end
  return nil
end

-- Loads everything a plan needs from the repo root: recipe, manifest rows, keys. Returns recipe, rows, keys.
function B.load(recipePath, manifestPath, keysPath)
  local recipe = json.decode(assert(B.read(recipePath), 'no recipe ' .. recipePath))
  local rows = B.manifest(assert(B.read(manifestPath or recipe.manifest), 'no manifest ' .. tostring(manifestPath or recipe.manifest)))
  local keys = nil
  local kp = keysPath or recipe.keys
  if kp and kp ~= 'none' then
    local text = B.read(kp)
    if text then keys = json.decode(text).keys end
  end
  return recipe, rows, keys
end

return B
