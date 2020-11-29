dofile_once("mods/LocationTracker/files/encode_coords.lua")

local w, h = 70, 48
BiomeMapSetSize(w, h)
BiomeMapLoadImage(0,0, "data/biome_impl/biome_map.png")

local function _BiomeMapGetPixel(x, y)
  local abgr = BiomeMapGetPixel(x, y)
  local b = bit.rshift(bit.band(abgr, 0xff0000), 2 * 8)
  local g = bit.rshift(bit.band(abgr, 0x00ff00), 1 * 8)
  local r = bit.band(abgr, 0x0000ff)
  return r, g, b
end

local content = "return {"
content = content .. "width = " .. w .. ","
content = content .. "height = " .. h .. ","
content = content .. "map = {"
for y=0,h-1 do
  for x=0,w-1 do
    local r, g, b = _BiomeMapGetPixel(x, y)
    content = content .. "["..encode_coords(x, y).."] = " .. string.format("{ r = %s, g = %s, b = %s },\n", r, g, b)
  end
end

content = content .. "}}\n"
ModTextFileSetContent("mods/LocationTracker/_virtual/map.lua", content)
