-- Assemble outgoing and incoming composed passages around an unmetered pivot.
local cache='/work/tmp/imagegen/campaign-guides/'
local dest='assets/research/battle-metal-radio/batch-2026-11-12/guides/'
local frequencies={164.813778,123.470825,97.998859,130.812783}
local function q(s)return "'"..s:gsub("'","'\\''").."'"end
local function cmd(a)local p={};for _,v in ipairs(a)do p[#p+1]=q(v)end;return table.concat(p,' ')end
local function run(a)assert(os.execute(cmd(a)))end
local function read(a)local p=assert(io.popen(cmd(a)));local s=p:read('a');assert(p:close());return (s:gsub('%s+$',''))end
run({'mkdir','-p',dest})
for from=1,4 do
 local to=from+1
 local src=cache..'level-'..from..'.json';local dst=cache..'level-'..to..'.json'
 local bar1=assert(tonumber(read({'jq','-r','.bar_samples',src})))
 local bar2=assert(tonumber(read({'jq','-r','.bar_samples',dst})))
 local all1=assert(tonumber(read({'jq','-r','.samples',src})))
 local n1,n2=bar1*8,bar2*8;local pivot=32*48000-n1-n2;assert(pivot>0)
 local filter=string.format('[0:a]atrim=start_sample=%d,asetpts=PTS-STARTPTS,afade=t=out:st=%.9f:d=0.25[a];'..
 '[1:a]atrim=end_sample=%d,asetpts=PTS-STARTPTS,afade=t=in:d=0.25[b];'..
 '[2:a]atrim=end_sample=%d,pan=stereo|c0=c0|c1=c0,volume=0.12,afade=t=in:d=0.25,afade=t=out:st=%.9f:d=0.25[p];'..
 '[a][p][b]concat=n=3:v=0:a=1[out]',all1-n1,n1/48000-.25,n2,pivot,pivot/48000-.25)
 local name='bridge-'..from..'-'..to
 run({'/home/linuxbrew/.linuxbrew/bin/ffmpeg','-v','error','-y','-i',cache..'level-'..from..'.flac',
 '-i',cache..'level-'..to..'.flac','-f','lavfi','-i',string.format('sine=frequency=%.9f:sample_rate=48000:duration=%.9f',frequencies[from],pivot/48000),
 '-filter_complex',filter,'-map','[out]','-c:a','flac',cache..name..'.flac'})
 local f=assert(io.open(dest..name..'.json','w'))
 f:write(string.format('{"schema":"demon-attack.bridge-guide/v1","from":%d,"to":%d,"seconds":32,"source_samples":%d,"pivot_samples":%d,"arrival_samples":%d,"pivot_hz":%.9f,"review":"pending transition audition"}\n',from,to,n1,pivot,n2,frequencies[from]));f:close()
 print(name..': 32 seconds, explicit outgoing/pivot/incoming guide')
end
