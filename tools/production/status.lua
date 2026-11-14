local spec=assert(loadfile(assert(arg[1]),'t',{}))()
local lfs=require('lfs')
local function q(s)return "'"..s:gsub("'","'\\''").."'"end
local function hash(path)
 if not lfs.attributes(path)then return nil end
 local p=assert(io.popen('sha256sum -- '..q(path)));local d=p:read('a'):match('^(%x+)');assert(p:close());return d
end
local inputs={['tools/production/run.lua']=hash('tools/production/run.lua'),[arg[1]]=hash(arg[1])}
for _,p in ipairs(spec.inputs or {})do inputs[p]=hash(p)end
local counts={done=0,stale=0,running=0,failed=0,pending=0}
for _,job in ipairs(spec.jobs)do
 local path='plan/render-runs/'..spec.id..'/'..job.id..'.lua'
 if not lfs.attributes(path)then counts.pending=counts.pending+1
 else
  local rec=assert(loadfile(path,'t',{}))()
  local status=rec.status
  if status=='done'then
   for p,d in pairs(inputs)do if rec.inputs[p]~=d then status='stale';break end end
  end
  counts[status]=(counts[status]or 0)+1
 end
end
print(string.format('%s: %d/%d current done; %d stale, %d running, %d failed, %d pending',
 spec.id,counts.done,#spec.jobs,counts.stale,counts.running,counts.failed,counts.pending))
