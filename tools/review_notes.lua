#!/usr/bin/env lua
-- Turns asset review notes (the studio's "Export JSON" download, or the body
-- of GET /api/notes) into a markdown worklist grouped by tag.
--
--   lua tools/review_notes.lua notes.json > worklist.md
--   lua tools/review_notes.lua --tag needs-growl --kind radio notes.json
--   curl -sH "authorization: Bearer $NOTES_TOKEN" \
--     https://demonattack.tlatoani.net/api/notes | lua tools/review_notes.lua -
--
-- A note with several tags is listed under each of them; notes without tags
-- go under "untagged". Plain Lua 5.4, no modules.

local usage = [[
usage: lua tools/review_notes.lua [--tag TAG]... [--kind KIND]... [FILE|-]
  FILE  notes JSON ({"notes": [...]} or a bare array); "-" or nothing reads stdin
  --tag   only these tags (repeatable)
  --kind  only these asset kinds: background, atlas, radio, music, scene, page]]

-- Worklist order: what to redo first, what to keep last.
local tag_order = {
  'regenerate', 'refine', 'needs-growl', 'flat-emotion', 'uncompressed-sound',
  'clipping', 'too-loud', 'too-quiet', 'timing',
}
local last_tags = { keep = 1, untagged = 2 }

---------------------------------------------------------------- JSON decoding
local function decode(text)
  local pos = 1
  local function fail(msg) error(('JSON error at byte %d: %s'):format(pos, msg), 0) end
  local function ws() pos = text:find('[^ \t\r\n]', pos) or #text + 1 end
  local function utf8char(code) return utf8.char(code) end
  local value
  local function str()
    pos = pos + 1
    local out = {}
    while true do
      local stop = text:find('["\\]', pos)
      if not stop then fail('unterminated string') end
      out[#out + 1] = text:sub(pos, stop - 1)
      pos = stop + 1
      if text:sub(stop, stop) == '"' then return table.concat(out) end
      local esc = text:sub(pos, pos)
      pos = pos + 1
      local simple = { b = '\b', f = '\f', n = '\n', r = '\r', t = '\t', ['"'] = '"', ['\\'] = '\\', ['/'] = '/' }
      if simple[esc] then
        out[#out + 1] = simple[esc]
      elseif esc == 'u' then
        local code = tonumber(text:sub(pos, pos + 3), 16) or fail('bad \\u escape')
        pos = pos + 4
        if code >= 0xD800 and code <= 0xDBFF and text:sub(pos, pos + 1) == '\\u' then
          local low = tonumber(text:sub(pos + 2, pos + 5), 16)
          if low and low >= 0xDC00 and low <= 0xDFFF then
            code = 0x10000 + (code - 0xD800) * 0x400 + (low - 0xDC00)
            pos = pos + 6
          end
        end
        out[#out + 1] = utf8char(code)
      else
        fail('bad escape')
      end
    end
  end
  function value()
    ws()
    local c = text:sub(pos, pos)
    if c == '{' then
      pos = pos + 1
      local obj = {}
      ws()
      if text:sub(pos, pos) == '}' then pos = pos + 1; return obj end
      while true do
        ws()
        if text:sub(pos, pos) ~= '"' then fail('expected key') end
        local key = str()
        ws()
        if text:sub(pos, pos) ~= ':' then fail("expected ':'") end
        pos = pos + 1
        obj[key] = value()
        ws()
        local sep = text:sub(pos, pos)
        pos = pos + 1
        if sep == '}' then return obj end
        if sep ~= ',' then fail("expected ',' or '}'") end
      end
    elseif c == '[' then
      pos = pos + 1
      local arr = {}
      ws()
      if text:sub(pos, pos) == ']' then pos = pos + 1; return arr end
      while true do
        arr[#arr + 1] = value()
        ws()
        local sep = text:sub(pos, pos)
        pos = pos + 1
        if sep == ']' then return arr end
        if sep ~= ',' then fail("expected ',' or ']'") end
      end
    elseif c == '"' then
      return str()
    elseif text:find('^true', pos) then pos = pos + 4; return true
    elseif text:find('^false', pos) then pos = pos + 5; return false
    elseif text:find('^null', pos) then pos = pos + 4; return nil
    else
      local num = text:match('^-?%d+%.?%d*[eE]?[-+]?%d*', pos)
      if not num or num == '' then fail('unexpected character') end
      pos = pos + #num
      return tonumber(num)
    end
  end
  local result = value()
  ws()
  if pos <= #text then fail('trailing data') end
  return result
end

---------------------------------------------------------------- arguments
local tags_wanted, kinds_wanted, path = {}, {}, nil
local i = 1
while i <= #arg do
  local a = arg[i]
  if a == '--tag' or a == '--kind' then
    local v = arg[i + 1] or (io.stderr:write(usage, '\n') and os.exit(2))
    if a == '--tag' then tags_wanted[v] = true else kinds_wanted[v] = true end
    i = i + 2
  elseif a == '-h' or a == '--help' then
    print(usage); os.exit(0)
  else
    path = a; i = i + 1
  end
end

local raw
if not path or path == '-' then
  raw = io.read('a')
else
  local f, err = io.open(path, 'rb')
  if not f then io.stderr:write(err, '\n'); os.exit(1) end
  raw = f:read('a'); f:close()
end
local ok, data = pcall(decode, raw)
if not ok then io.stderr:write(data, '\n'); os.exit(1) end
local notes = (type(data) == 'table' and data.notes) or data
if type(notes) ~= 'table' then io.stderr:write('no notes array found\n'); os.exit(1) end

---------------------------------------------------------------- grouping
local function filtered(n)
  if next(kinds_wanted) and not kinds_wanted[n.kind or ''] then return false end
  return true
end
local groups, counts, assets, total = {}, {}, {}, 0
for _, n in ipairs(notes) do
  if type(n) == 'table' and filtered(n) then
    local tags = (type(n.tags) == 'table' and #n.tags > 0) and n.tags or { 'untagged' }
    local listed = false
    for _, t in ipairs(tags) do
      if not next(tags_wanted) or tags_wanted[t] then
        groups[t] = groups[t] or {}
        table.insert(groups[t], n)
        listed = true
      end
    end
    if listed then
      total = total + 1
      assets[n.ref or ((n.kind or '?') .. ' / ' .. (n.asset or '?'))] = true
    end
  end
end

local rank = {}
for k, t in ipairs(tag_order) do rank[t] = k end
local names = {}
for t in pairs(groups) do names[#names + 1] = t end
table.sort(names, function(a, b)
  local la, lb = last_tags[a] or 0, last_tags[b] or 0
  if la ~= lb then return la < lb end
  local ra, rb = rank[a] or 100, rank[b] or 100
  if ra ~= rb then return ra < rb end
  return a < b
end)

local function clock(seconds)
  if type(seconds) ~= 'number' then return nil end
  local m = math.floor(seconds / 60)
  return ('%d:%04.1f'):format(m, seconds - m * 60)
end
local function oneline(s) return ((s or ''):gsub('%s*\n%s*', ' / ')) end
local function ref_of(n) return n.ref or ((n.kind or '?') .. ' / ' .. (n.asset or '?')) end

---------------------------------------------------------------- output
local out = {}
local function put(s) out[#out + 1] = s end
local asset_count = 0
for _ in pairs(assets) do asset_count = asset_count + 1 end
put('# Asset review worklist')
put('')
put(('%d notes on %d assets%s%s.'):format(total, asset_count,
  data.exportedAt and (' · exported ' .. data.exportedAt) or '',
  path and path ~= '-' and (' · from `' .. path .. '`') or ''))
put('')
if #names > 0 then
  put('| Tag | Notes |')
  put('| --- | ---: |')
  for _, t in ipairs(names) do put(('| %s | %d |'):format(t, #groups[t])) end
end
for _, t in ipairs(names) do
  local list = groups[t]
  table.sort(list, function(a, b)
    if ref_of(a) ~= ref_of(b) then return ref_of(a) < ref_of(b) end
    return (a.offset or -1) < (b.offset or -1)
  end)
  put('')
  put(('## %s (%d)'):format(t, #list))
  put('')
  for _, n in ipairs(list) do
    local head = { '`' .. ref_of(n) .. '`' }
    local at = clock(n.offset)
    local where = {}
    if at then where[#where + 1] = '@ ' .. at end
    if n.section and n.section ~= '' then where[#where + 1] = n.section end
    if #where > 0 then head[#head + 1] = table.concat(where, ' · ') end
    local others = {}
    for _, o in ipairs(type(n.tags) == 'table' and n.tags or {}) do
      if o ~= t then others[#others + 1] = o end
    end
    if #others > 0 then head[#head + 1] = '(+' .. table.concat(others, ', ') .. ')' end
    local text = oneline(n.text)
    put('- [ ] ' .. table.concat(head, ' ') .. (text ~= '' and (' — ' .. text) or ''))
    local meta = {}
    if n.source then meta[#meta + 1] = n.source end
    if n.hash then meta[#meta + 1] = 'hash ' .. n.hash:sub(1, 12) end
    if n.build then meta[#meta + 1] = 'build ' .. n.build end
    if n.createdAt then meta[#meta + 1] = n.createdAt:sub(1, 10) end
    if #meta > 0 then put('  <sub>' .. table.concat(meta, ' · ') .. '</sub>') end
  end
end
io.write(table.concat(out, '\n'), '\n')
