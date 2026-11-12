-- Copy a completed admitted host job, verify its audio, encode modern previews.
local result=assert(arg[1]);local id=assert(arg[2]);assert(id:match('^[%w_-]+$'))
local dest='assets/research/battle-metal-radio/batch-2026-11-12/music/'..id
local function q(s)return "'"..s:gsub("'","'\\''").."'"end
local function cmd(a)local p={};for _,v in ipairs(a)do p[#p+1]=q(v)end;return table.concat(p,' ')end
local function run(a)assert(os.execute(cmd(a)))end
local function read(a)local p=assert(io.popen(cmd(a)));local s=p:read('a');assert(p:close());return s:gsub('%s+$','')end
local path=read({'jq','-er','.outputs[0].path',result})
local provenance=read({'jq','-er','.outputs[0].provenance_path',result})
assert(path:match('^/work/tmp/imagegen/studio/'),'unexpected host output path')
run({'mkdir','-p',dest})
run({'cp','--',path,dest..'/master.flac'})
run({'cp','--',provenance,dest..'/provenance.json'})
run({'cp','--',result,dest..'/host-job.json'})
run({'/home/linuxbrew/.linuxbrew/bin/ffmpeg','-v','error','-y','-i',dest..'/master.flac',
 '-map_metadata','-1','-af','loudnorm=I=-18:TP=-3:LRA=11','-c:a','libopus','-b:a','160k','-vbr','on',dest..'/preview.ogg'})
local duration=assert(tonumber(read({'/home/linuxbrew/.linuxbrew/bin/ffprobe','-v','error','-show_entries','format=duration',
 '-of','default=noprint_wrappers=1:nokey=1',dest..'/master.flac'})))
assert(duration>20,'short music output')
local report=dest..'/measurement.txt'
local f=assert(io.open(report,'w'));f:write('Candidate '..id..'\nDecoded source duration: '..duration..' seconds\nReview: pending listening, guide alignment, continuity and source clipping review.\n');f:close()
local measure=cmd({'/home/linuxbrew/.linuxbrew/bin/ffmpeg','-hide_banner','-i',dest..'/master.flac','-af','volumedetect','-f','null','-'})
assert(os.execute(measure..' >> '..q(report)..' 2>&1'))
