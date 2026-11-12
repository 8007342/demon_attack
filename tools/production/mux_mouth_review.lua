-- Review artifacts only: never replaces runtime media or marks a take accepted.
local lfs=require('lfs')
local root=assert(arg[1],'usage: lua mux_mouth_review.lua FRAME-DIR CLIP-ID ...')
local function q(s)return "'"..s:gsub("'","'\\''").."'"end
local function run(argv)
 local words={};for _,word in ipairs(argv)do words[#words+1]=q(word)end
 assert(os.execute(table.concat(words,' ')))
end
local dest='assets/research/battle-metal-radio/mouth-review-2026-11-12'
run({'mkdir','-p',dest})
for index=2,#arg do
 local id=arg[index];assert(id:match('^[%w_.-]+$'))
 local frames={}
 for file in lfs.dir(root..'/'..id)do
  if file:match('^%d%d%d%d%.png$')then frames[#frames+1]=root..'/'..id..'/'..file end
 end
 table.sort(frames);assert(#frames>1,'missing rendered frames')
 run({'/home/linuxbrew/.linuxbrew/bin/ffmpeg','-v','error','-y',
  '-framerate','30','-i',root..'/'..id..'/%04d.png',
  '-i','assets/research/battle-metal-radio/batch-2026-11-12/voices/'..id..'/radio.ogg',
  '-c:v','libvpx-vp9','-crf','28','-b:v','0','-pix_fmt','yuv420p',
  '-c:a','libopus','-b:a','48k','-af','apad','-shortest',dest..'/'..id..'.webm'})
 local montage={'/home/linuxbrew/.linuxbrew/bin/magick','montage'}
 for sample=0,8 do montage[#montage+1]=frames[math.floor(sample*(#frames-1)/8)+1]end
 for _,word in ipairs({'-tile','3x3','-geometry','+2+2','-background','#090d18',dest..'/'..id..'.webp'})do
  montage[#montage+1]=word
 end
 run(montage)
 run({'cp',root..'/'..id..'/source.json',dest..'/'..id..'.json'})
 local provenance=assert(io.open(dest..'/'..id..'.provenance.lua','w'))
 provenance:write('return {schema="demon-attack.mouth-review/v1",review="pending audiovisual review",inputs={\n')
 for _,path in ipairs({
  'assets/research/battle-metal-radio/batch-2026-11-12/voices/'..id..'/metadata.json',
  'assets/research/battle-metal-radio/batch-2026-11-12/voices/'..id..'/radio.ogg',
  'assets/images/comms-portraits.png','assets/images/comms-portraits-small.png',
  'lib/comms/comms_mouth.dart','lib/comms/comms_view.dart',
  'test/comms_candidate_review_test.dart',arg[0]})do
  local p=assert(io.popen('sha256sum -- '..q(path)))
  local hash=assert(p:read('a'):match('^(%x+)'));assert(p:close())
  provenance:write(string.format('[%q]=%q,\n',path,hash))
 end
 provenance:write('}}\n');provenance:close()
end
