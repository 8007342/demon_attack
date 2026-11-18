#!/usr/bin/env lua
-- pins.lua: fetches and verifies the brood choir's pinned sample libraries (plan/choir-pins.md,
-- plan/choir-pins.manifest.tsv; openspec/changes/demon-choir design §11). Pure Lua 5.4 + curl + unzip + git + sha256sum.
--
-- Run from the repo root:
--   lua tools/brood_choir/pins.lua fetch [--src DIR] [--zips DIR]   fetch what --src lacks, verify everything
--   lua tools/brood_choir/pins.lua verify [--src DIR] [--zips DIR]  verify only (exit 1 on any mismatch)
-- Defaults: --src ~/.cache/tillandsias-project/demon-choir/src (laid out as <owner>/<repo>/<path>, beside the
-- choir's local/ sources), --zips ~/.cache/tillandsias-project/choir-src (the release zips, never the checkout).
--
-- Refuses (deletes the file, exit 1) on any mismatch:
-- - a git blob (docs, maps, the Merry Orks samples): size and `git hash-object` against the manifest;
-- - a release zip (epic-choir's B part): size and sha256 of the WHOLE file against `container_sha256` (the API
--   digest), checked before any member is extracted;
-- - a zip member: extracted alone by name (`unzip -p`, so no path from the zip touches the disk), then its size and
--   CRC32 against the manifest's `crc32` (computed here, independently of unzip's own check).
-- It prints each extracted member's git blob sha1, which art/music/bank/choir-*.manifest.tsv pins for the builder.
local cmd = arg[1]
local opts = {}
do
  local i = 2
  while i <= #arg do
    if arg[i]:match('^%-%-') and arg[i + 1] then opts[arg[i]:sub(3)] = arg[i + 1]; i = i + 2
    else io.stderr:write('unknown argument ' .. arg[i] .. '\n'); os.exit(2) end
  end
end
if cmd ~= 'fetch' and cmd ~= 'verify' then
  io.stderr:write('usage: lua tools/brood_choir/pins.lua fetch|verify [--src DIR] [--zips DIR] [--manifest FILE]\n'); os.exit(2)
end
local home = os.getenv('HOME') or '.'
local src = opts.src or (home .. '/.cache/tillandsias-project/demon-choir/src')
local zips = opts.zips or (home .. '/.cache/tillandsias-project/choir-src')
local manifestPath = opts.manifest or 'plan/choir-pins.manifest.tsv'
local function q(s) return "'" .. tostring(s):gsub("'", "'\\''") .. "'" end
local function sh(c) local p = assert(io.popen(c, 'r')); local out = p:read('a'); local ok = p:close(); return out, ok end
local function say(...) io.stderr:write(string.format(...) .. '\n') end
local function size(path) local f = io.open(path, 'rb'); if not f then return nil end; local n = f:seek('end'); f:close(); return n end
local function blob(path) return (sh('git hash-object --no-filters ' .. q(path))):match('^(%x+)') end
local function sha256(path) return (sh('sha256sum ' .. q(path))):match('^(%x+)') end
local function dir(path) return path:match('^(.*)/[^/]*$') end

local CRC = {}
for i = 0, 255 do
  local c = i
  for _ = 1, 8 do if c & 1 == 1 then c = 0xEDB88320 ~ (c >> 1) else c = c >> 1 end end
  CRC[i] = c
end
local function crc32(path)
  local f = assert(io.open(path, 'rb'))
  local c = 0xFFFFFFFF
  while true do
    local chunk = f:read(65536)
    if not chunk then break end
    for k = 1, #chunk, 16 do
      local b = { chunk:byte(k, math.min(#chunk, k + 15)) }
      for j = 1, #b do c = CRC[(c ~ b[j]) & 0xFF] ~ (c >> 8) end
    end
  end
  f:close()
  return ('%08x'):format(c ~ 0xFFFFFFFF)
end

-- The manifest: the sample-bank manifest's 7 columns, then crc32, zip_offset, zip_csize, container_sha256.
local rows = {}
do
  local f = assert(io.open(manifestPath, 'rb'))
  local header
  for line in f:lines() do
    local cols = {}
    for c in (line .. '\t'):gmatch('([^\t]*)\t') do cols[#cols + 1] = c end
    if not header then header = cols else
      local r = {}
      for k, name in ipairs(header) do r[name] = cols[k] end
      r.bytes = tonumber(r.bytes)
      rows[#rows + 1] = r
    end
  end
  f:close()
end

local failures = 0
local function refuse(path, why)
  failures = failures + 1
  say('REFUSED %s: %s', path, why)
  os.remove(path)
end
local function curl(url, path)
  assert(os.execute('mkdir -p ' .. q(dir(path))))
  local tmp = path .. '.part'
  local ok = os.execute(('curl -sSfL --max-time 900 -o %s %s'):format(q(tmp), q(url)))
  if not ok then os.remove(tmp); return false end
  return os.rename(tmp, path)
end

-- 1. Git blobs.
for _, r in ipairs(rows) do
  if r.git_blob_sha1 ~= '-' then
    local path = ('%s/%s/%s'):format(src, r.repo, r.path)
    if not size(path) and cmd == 'fetch' then
      if not curl(r.raw_url, path) then failures = failures + 1; say('fetch failed: %s', r.raw_url) end
    end
    if not size(path) then failures = failures + 1; say('missing %s', path)
    elseif size(path) ~= r.bytes then refuse(path, ('size %d, pinned %d'):format(size(path), r.bytes))
    else
      local b = blob(path)
      if b ~= r.git_blob_sha1 then refuse(path, ('git blob sha1 %s, pinned %s'):format(b, r.git_blob_sha1))
      else say('ok blob   %s %s/%s', b, r.repo, r.path) end
    end
  end
end

-- 2. Release zips: the whole file's size and sha256, before any member is read.
local zipOk = {}
for _, r in ipairs(rows) do
  if r.group == 'release' then
    local path = ('%s/%s'):format(zips, r.path)
    if not size(path) and cmd == 'fetch' then
      say('fetching %s (%d B)', r.raw_url, r.bytes)
      if not curl(r.raw_url, path) then failures = failures + 1; say('fetch failed: %s', r.raw_url) end
    end
    if not size(path) then failures = failures + 1; say('missing %s', path)
    elseif size(path) ~= r.bytes then refuse(path, ('size %d, pinned %d'):format(size(path), r.bytes))
    else
      local s = sha256(path)
      if s ~= r.container_sha256 then refuse(path, ('sha256 %s, pinned %s'):format(s, r.container_sha256))
      else zipOk[r.container_sha256] = path; say('ok sha256 %s %s (%d B)', s, r.path, r.bytes) end
    end
  end
end

-- 3. Zip members: extracted by name from a verified zip, then size and CRC32.
for _, r in ipairs(rows) do
  if r.crc32 ~= '-' and r.crc32 then
    local path = ('%s/%s/%s'):format(src, r.repo, r.path)
    local zip = zipOk[r.container_sha256]
    if not size(path) and cmd == 'fetch' and zip then
      assert(os.execute('mkdir -p ' .. q(dir(path))))
      if not os.execute(('unzip -p %s %s > %s'):format(q(zip), q(r.path), q(path .. '.part'))) then
        failures = failures + 1; say('unzip failed: %s', r.path); os.remove(path .. '.part')
      else os.rename(path .. '.part', path) end
    end
    if not size(path) then failures = failures + 1; say('missing %s%s', path, zip and '' or ' (its zip is not verified)')
    elseif size(path) ~= r.bytes then refuse(path, ('size %d, pinned %d'):format(size(path), r.bytes))
    else
      local c = crc32(path)
      if c ~= r.crc32 then refuse(path, ('crc32 %s, pinned %s'):format(c, r.crc32))
      else say('ok crc32  %s %s/%s (git blob %s)', c, r.repo, r.path, blob(path)) end
    end
  end
end

if failures > 0 then say('%d failure(s)', failures); os.exit(1) end
say('all %d rows verified', #rows)
