-- Lua schedules one clip; the local worker owns only model/numeric adapters.
local id=assert(arg[1]);assert(id:match('^[%w_.-]+$'))
local base='/home/forge/.cache/demon-attack/voice-trial/work/candidates/'..id
local dest='assets/research/battle-metal-radio/batch-2026-11-12/voices/'..id
local function q(s)return "'"..s:gsub("'","'\\''").."'" end
local function run(a)local p={};for _,v in ipairs(a)do p[#p+1]=q(v)end;assert(os.execute(table.concat(p,' ')))end
run({'curl','--fail-with-body','--silent','--show-error','--max-time','900','-H','Content-Type: application/json',
 '--data','{"mode":"produce","id":"'..id..'"}','http://127.0.0.1:18851/render'})
run({'mkdir','-p',dest})
for _,name in ipairs({'baseline.flac','expressive.flac','voice.flac','radio.ogg','metadata.json'}) do
 run({'cp','--',base..'/'..name,dest..'/'..name})
end
