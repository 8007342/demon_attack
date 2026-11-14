local level=assert(tonumber(arg[1]));assert(level>=1 and level<=5)
local cache='/work/tmp/imagegen/campaign-guides/level-'..level..'.flac'
local dest='assets/research/battle-metal-radio/batch-2026-11-12/guides/level-'..level..'.json'
local function q(s) return "'"..s:gsub("'","'\\''").."'" end
local function run(a) local p={};for _,v in ipairs(a) do p[#p+1]=q(v) end;assert(os.execute(table.concat(p,' '))) end
run({'/home/forge/.cache/tillandsias-project/bin/forge-guard','run','--need','2','--threads','4','--timeout','600','--',
 '/home/forge/.cache/demon-attack/voice-trial/cb-venv/bin/python','-I','tools/campaign_guide.py','--level',tostring(level),'--out',cache})
run({'mkdir','-p','assets/research/battle-metal-radio/batch-2026-11-12/guides'})
run({'cp','--',cache:gsub('%.flac$','.json'),dest})
