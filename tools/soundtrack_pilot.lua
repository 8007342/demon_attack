-- Soundtrack pilot helper (openspec adaptive-soundtrack, plan/render-runs/soundtrack-pilot.md).
--
-- Raw takes live outside the repo (default ~/.cache/tillandsias-project/soundtrack-pilot); only the
-- picked, encoded sections are committed (art/music/soundtrack/pilot/).
--
--   lua tools/soundtrack_pilot.lua ingest <studio job dir> <section> <model> <first seed>
--   lua tools/soundtrack_pilot.lua analyze [section]        -- writes <work>/analysis/<take>.json, prints a table
--   lua tools/soundtrack_pilot.lua cut <take> <kind> <bars> <out name> [start bar]
--   lua tools/soundtrack_pilot.lua encode <out name>        -- -19 LUFS, Opus 160 kbps into art/music/soundtrack/pilot/
--
-- Needs ffmpeg (libopus, ebur128, loudnorm), jq, and the Go checker:
--   cd tools/soundtrack_check && go build -o ~/.cache/tillandsias-project/bin/soundtrack_check .
local HOME = os.getenv("HOME")
local WORK = os.getenv("SOUNDTRACK_WORK") or (HOME .. "/.cache/tillandsias-project/soundtrack-pilot")
local CHECK = os.getenv("SOUNDTRACK_CHECK") or (HOME .. "/.cache/tillandsias-project/bin/soundtrack_check")
local OUT = "art/music/soundtrack/pilot"
local RECIPE = "art/music/soundtrack/pilot-carrier-t1.json"
local BAR = 60632
local LUFS = -19
local KBPS = 160

local function sh(cmd)
  local ok = os.execute(cmd)
  if not ok then error("failed: " .. cmd) end
end

local function read(cmd)
  local p = assert(io.popen(cmd))
  local s = p:read("a")
  p:close()
  return s
end

local function q(s) return "'" .. tostring(s):gsub("'", "'\\''") .. "'" end

local cmd = arg[1]

if cmd == "ingest" then
  local dir, section, model, seed = arg[2], arg[3], arg[4], tonumber(arg[5])
  sh("mkdir -p " .. q(WORK .. "/raw"))
  local files = read("ls " .. q(dir) .. " | grep -E '^[0-9]+_[0-9]+\\.flac$' | sort")
  local i = 0
  for f in files:gmatch("[^\n]+") do
    local name = string.format("%s-%s-%d", section, model, seed + i)
    sh(string.format("cp %s %s", q(dir .. "/" .. f), q(WORK .. "/raw/" .. name .. ".flac")))
    sh(string.format("cp %s %s", q(dir .. "/" .. f .. ".provenance.json"), q(WORK .. "/raw/" .. name .. ".provenance.json")))
    print(name)
    i = i + 1
  end
elseif cmd == "analyze" then
  local only = arg[2]
  sh("mkdir -p " .. q(WORK .. "/analysis"))
  local files = read("ls " .. q(WORK .. "/raw") .. " | grep '\\.flac$' | sort")
  print(string.format("%-26s %8s %7s %-9s %5s %5s %6s %6s %6s %5s  %s", "take", "bpm", "err%", "key", "r", "rank",
    ">12k", ">16k", "LUFS", "peak", "gate"))
  for f in files:gmatch("[^\n]+") do
    local take = f:gsub("%.flac$", "")
    if not only or take:find(only, 1, true) == 1 then
      local key = "F minor"
      if take:find("^victory") then key = "F major" end
      local json = WORK .. "/analysis/" .. take .. ".json"
      sh(string.format("%s analyze -bar %d -key %s %s > %s", CHECK, BAR, q(key), q(WORK .. "/raw/" .. f), q(json)))
      print((read(string.format(
        "jq -r '[%q, .measuredBpm, .tempoErrPct, .key, .keyR, .targetKeyRank, .above12kDb, .above16kDb, .lufs, .peakDbfs, ((.gate // []) | join(\"; \"))] | @tsv' %s",
        take, q(json))):gsub("\n$", "")))
    end
  end
elseif cmd == "cut" then
  local take, kind, bars, name, start = arg[2], arg[3], tonumber(arg[4]), arg[5], arg[6]
  sh("mkdir -p " .. q(WORK .. "/cut"))
  local extra = start and (" -start " .. tonumber(start)) or ""
  local res = read(string.format("%s cut -bar %d -bars %d -kind %s%s -out %s %s", CHECK, BAR, bars, kind, extra,
    q(WORK .. "/cut/" .. name .. ".wav"), q(WORK .. "/raw/" .. take .. ".flac")))
  local f = assert(io.open(WORK .. "/cut/" .. name .. ".cut.json", "w"))
  f:write(res)
  f:close()
  io.write(res)
elseif cmd == "encode" then
  local name = arg[2]
  sh("mkdir -p " .. OUT)
  local src = WORK .. "/cut/" .. name .. ".wav"
  local norm = WORK .. "/cut/" .. name .. ".norm.wav"
  -- two-pass loudnorm in linear mode keeps the waveform shape (a fixed gain)
  local m = read(string.format(
    "ffmpeg -hide_banner -nostats -i %s -af loudnorm=I=%d:TP=-1.5:LRA=11:print_format=json -f null - 2>&1 | sed -n '/^{/,/^}/p'",
    q(src), LUFS))
  local function field(k) return m:match('"' .. k .. '"%s*:%s*"([^"]+)"') end
  sh(string.format(
    "ffmpeg -v error -y -i %s -af loudnorm=I=%d:TP=-1.5:LRA=11:linear=true:measured_I=%s:measured_TP=%s:measured_LRA=%s:measured_thresh=%s:offset=%s,aresample=48000 -c:a pcm_s16le %s",
    q(src), LUFS, field("input_i"), field("input_tp"), field("input_lra"), field("input_thresh"), field("target_offset"), q(norm)))
  sh(string.format("ffmpeg -v error -y -i %s -c:a libopus -b:a %dk -vbr on -application audio %s", q(norm),
    KBPS, q(OUT .. "/" .. name .. ".opus")))
  print(read("ls -l " .. q(OUT .. "/" .. name .. ".opus")))
else
  io.stderr:write("usage: lua tools/soundtrack_pilot.lua ingest|analyze|cut|encode … (see the header; recipe " .. RECIPE .. ")\n")
  os.exit(2)
end
