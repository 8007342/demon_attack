-- json.lua: a small strict JSON decoder and a deterministic encoder (the forge's Lua has no JSON module).
-- decode(text) -> value (objects are tables with string keys, arrays are sequences; null is json.null).
-- encode(value, opts) -> text; object keys are sorted so output is byte-stable. opts.indent = '  ' pretty-prints.
local json = { null = setmetatable({}, { __tostring = function() return 'null' end }) }

local function fail(text, pos, what) error(('json: %s at byte %d near %q'):format(what, pos, text:sub(pos, pos + 12)), 0) end

function json.decode(text)
  local pos = 1
  local function skip() pos = text:find('[^ \t\r\n]', pos) or #text + 1 end
  local value
  local function str()
    local out, i = {}, pos + 1
    while true do
      local c = text:sub(i, i)
      if c == '' then fail(text, pos, 'unterminated string') end
      if c == '"' then pos = i + 1; return table.concat(out) end
      if c == '\\' then
        local e = text:sub(i + 1, i + 1)
        local map = { ['"'] = '"', ['\\'] = '\\', ['/'] = '/', b = '\b', f = '\f', n = '\n', r = '\r', t = '\t' }
        if map[e] then out[#out + 1] = map[e]; i = i + 2
        elseif e == 'u' then
          local code = tonumber(text:sub(i + 2, i + 5), 16) or fail(text, i, 'bad \\u escape')
          out[#out + 1] = utf8.char(code); i = i + 6
        else fail(text, i, 'bad escape') end
      else out[#out + 1] = c; i = i + 1 end
    end
  end
  function value()
    skip()
    local c = text:sub(pos, pos)
    if c == '{' then
      local obj = {}; pos = pos + 1; skip()
      if text:sub(pos, pos) == '}' then pos = pos + 1; return obj end
      while true do
        skip(); if text:sub(pos, pos) ~= '"' then fail(text, pos, 'expected key') end
        local key = str(); skip()
        if text:sub(pos, pos) ~= ':' then fail(text, pos, 'expected :') end
        pos = pos + 1; obj[key] = value(); skip()
        local d = text:sub(pos, pos); pos = pos + 1
        if d == '}' then return obj end
        if d ~= ',' then fail(text, pos - 1, 'expected , or }') end
      end
    elseif c == '[' then
      local arr = {}; pos = pos + 1; skip()
      if text:sub(pos, pos) == ']' then pos = pos + 1; return arr end
      while true do
        arr[#arr + 1] = value(); skip()
        local d = text:sub(pos, pos); pos = pos + 1
        if d == ']' then return arr end
        if d ~= ',' then fail(text, pos - 1, 'expected , or ]') end
      end
    elseif c == '"' then return str()
    elseif text:sub(pos, pos + 3) == 'true' then pos = pos + 4; return true
    elseif text:sub(pos, pos + 4) == 'false' then pos = pos + 5; return false
    elseif text:sub(pos, pos + 3) == 'null' then pos = pos + 4; return json.null
    else
      local num = text:match('^-?%d+%.?%d*[eE]?[-+]?%d*', pos)
      if not num or num == '' then fail(text, pos, 'unexpected character') end
      pos = pos + #num; return tonumber(num)
    end
  end
  local result = value(); skip()
  if pos <= #text then fail(text, pos, 'trailing data') end
  return result
end

local function isArray(t)
  if next(t) == nil then return getmetatable(t) ~= json.object end
  local n = 0
  for k in pairs(t) do if type(k) ~= 'number' then return false end; n = n + 1 end
  return n == #t
end
json.object = {}  -- setmetatable({}, json.object) encodes an empty table as {}

local function num(n)
  if math.type(n) == 'integer' then return tostring(n) end
  if n == math.floor(n) and math.abs(n) < 2^53 then return ('%d'):format(n) end
  local s = ('%.6f'):format(n):gsub('0+$', ''):gsub('%.$', '')
  return s
end

function json.encode(v, opts, depth)
  opts = opts or {}; depth = depth or 0
  local t = type(v)
  if v == json.null or v == nil then return 'null' end
  if t == 'boolean' then return tostring(v) end
  if t == 'number' then return num(v) end
  if t == 'string' then
    return '"' .. v:gsub('[%c"\\]', function(c)
      local m = { ['"'] = '\\"', ['\\'] = '\\\\', ['\n'] = '\\n', ['\t'] = '\\t', ['\r'] = '\\r' }
      return m[c] or ('\\u%04x'):format(c:byte())
    end) .. '"'
  end
  local ind = opts.indent
  local nl = ind and '\n' or ''
  local pad = ind and ind:rep(depth + 1) or ''
  local close = ind and ind:rep(depth) or ''
  local parts = {}
  if isArray(v) then
    -- Arrays of scalars stay on one line.
    local flat = true
    for _, x in ipairs(v) do if type(x) == 'table' then flat = false end end
    for _, x in ipairs(v) do parts[#parts + 1] = json.encode(x, opts, depth + 1) end
    if flat or not ind then return '[' .. table.concat(parts, ',') .. ']' end
    return '[' .. nl .. pad .. table.concat(parts, ',' .. nl .. pad) .. nl .. close .. ']'
  end
  local keys = {}
  for k in pairs(v) do keys[#keys + 1] = tostring(k) end
  table.sort(keys)
  for _, k in ipairs(keys) do
    parts[#parts + 1] = json.encode(k) .. (ind and ': ' or ':') .. json.encode(v[k], opts, depth + 1)
  end
  if #parts == 0 then return '{}' end
  return '{' .. nl .. pad .. table.concat(parts, ',' .. nl .. pad) .. nl .. close .. '}'
end

return json
