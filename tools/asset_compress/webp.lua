-- phone-performance §8 (openspec/changes/phone-performance): the opaque
-- painted backdrops ship as lossy WebP instead of PNG.
--
--   lua tools/asset_compress/webp.lua [--dry]     (from the repo root)
--
-- Converts each listed PNG under assets/images/ to WebP at QUALITY with
-- ImageMagick (libwebp, method 6, sharp RGB-to-YUV), prints the size and the PSNR against the
-- PNG, and removes the PNG (one format per asset; git keeps the lossless
-- original in history). --dry converts into a temp name and keeps the PNG.
-- Only opaque, painted (photographic) art belongs here: sprite atlases and
-- pixel art stay PNG (lossy blocks smear hard pixel edges and alpha).
local QUALITY = 88
local FILES = {
  'sector-1', 'sector-2', 'sector-3', 'sector-4', 'sector-5',
  'cosmic-sky', 'hint-scenes',
}

local dry = arg[1] == '--dry'

local function run(cmd)
  local p = assert(io.popen(cmd .. ' 2>&1'))
  local out = p:read('a')
  local ok, _, code = p:close()
  return out, ok or code == 1 -- compare exits 1 when the images differ
end

local function size(path)
  local f = io.open(path, 'rb')
  if not f then return nil end
  local n = f:seek('end'); f:close(); return n
end

local before, after = 0, 0
print(string.format('%-14s %10s %10s %6s %s', 'file', 'png', 'webp', 'ratio', 'psnr dB'))
for _, stem in ipairs(FILES) do
  local png = 'assets/images/' .. stem .. '.png'
  local webp = 'assets/images/' .. stem .. (dry and '.dry' or '') .. '.webp'
  local a = size(png)
  if not a then
    print(stem .. ': no PNG (already converted?)')
  else
    local out, ok = run(string.format(
      "magick '%s' -strip -quality %d -define webp:method=6 -define webp:use-sharp-yuv=true '%s'", png, QUALITY, webp))
    assert(ok, out)
    local psnr = run(string.format("magick compare -metric PSNR '%s' '%s' null:", png, webp))
    local b = size(webp)
    before, after = before + a, after + b
    print(string.format('%-14s %10d %10d %5.1f%% %s', stem, a, b, 100 * b / a,
      psnr:match('^[%d%.]+') or psnr))
    if dry then os.remove(webp) else os.remove(png) end
  end
end
print(string.format('%-14s %10d %10d %5.1f%%', 'total', before, after,
  before > 0 and 100 * after / before or 0))
