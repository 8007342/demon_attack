-- Export the validated complete bank into an isolated Dart staging tree.
local source=assert(arg[1],'usage: stage_radio_bank.lua STAGED-AUDIO-DIR STAGED-TREE')
local dest=assert(arg[2])
local function q(s)return "'"..s:gsub("'","'\\''").."'"end
local function cmd(a)local p={};for _,v in ipairs(a)do p[#p+1]=q(v)end;return table.concat(p,' ')end
local function run(a)assert(os.execute(cmd(a)))end
local function read(a)local p=assert(io.popen(cmd(a)));local s=p:read('a');assert(p:close());return (s:gsub('%s+$',''))end
run({'jq','-e','.complete == true and .formats == ["ogg"]',source..'/manifest.json'})
for _,path in ipairs({'art/comms/cast.json','art/comms/lines.json','art/comms/audio.json','art/comms/demon-delivery.json'})do
 local wanted=read({'jq','-er','--arg','path',path,'.source_hashes[$path]',source..'/manifest.json'})
 local actual=read({'sha256sum','--',path}):match('^(%x+)')
 assert(wanted==actual,'staging input changed: '..path)
end
run({'mkdir','-p',dest..'/tools',dest..'/art/comms',dest..'/web/audio/comms',dest..'/lib/comms'})
run({'cp','--','tools/comms_pipeline.py',dest..'/tools/comms_pipeline.py'})
for _,name in ipairs({'cast.json','lines.json','audio.json','demon-delivery.json'})do
 run({'cp','--','art/comms/'..name,dest..'/art/comms/'..name})
end
run({'cp','--',source..'/manifest.json',dest..'/web/audio/comms/manifest.json'})
run({'cp','--','lib/comms/comms_types.dart',dest..'/lib/comms/comms_types.dart'})
run({'/home/forge/.cache/demon-attack/voice-trial/cb-venv/bin/python','-I',dest..'/tools/comms_pipeline.py','dart'})
print('Complete staged Dart bank: '..dest..'/lib/comms/comms_bank.dart')
