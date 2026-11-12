-- Serialize the full Git transaction across CPU and GPU production runners.
local function q(s) return "'" .. s:gsub("'", "'\\''") .. "'" end
local function cmd(argv)
 local parts={};for _,v in ipairs(argv) do parts[#parts+1]=q(v) end;return table.concat(parts,' ')
end
local function read(argv)
 local p=assert(io.popen(cmd(argv)));local s=p:read('a');assert(p:close());return s:gsub('%s+$','')
end
if arg[1] ~= '--locked' then
 local lock=read({'git','rev-parse','--git-path','production-checkpoint.lock'})
 local argv={'flock','-w','1800',lock,'lua',arg[0],'--locked'}
 for _,v in ipairs(arg) do argv[#argv+1]=v end
 local ok,_,code=os.execute(cmd(argv));os.exit(ok and 0 or code or 1)
end
local message=assert(arg[2]);local paths={}
for i=3,#arg do paths[#paths+1]=arg[i] end
assert(#paths>0)
local branch=read({'git','branch','--show-current'})
assert(branch:match('^work/'),'production checkpoint requires a work branch')
local add={'git','add','--'};local diff={'git','diff','--cached','--quiet','--'}
local commit={'git','commit','--only','-m',message,'--'}
for _,p in ipairs(paths) do add[#add+1]=p;diff[#diff+1]=p;commit[#commit+1]=p end
assert(os.execute(cmd(add)))
if not os.execute(cmd(diff)) then assert(os.execute(cmd(commit))) end
for attempt=1,3 do
 if os.execute(cmd({'git','push','origin','HEAD:refs/heads/'..branch})) then os.exit(0) end
 if attempt<3 then assert(os.execute(cmd({'sleep',tostring(attempt*2)}))) end
end
error('remote checkpoint failed after three attempts; stop production and resume after repair')
