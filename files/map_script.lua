BiomeMapSetSize(3, 48)
BiomeMapLoadImage(0,0, "data/biome_impl/biome_map.png")

local function _BiomeMapGetPixel(x, y)
  local abgr = BiomeMapGetPixel(x, y)
  local b = bit.rshift(bit.band(abgr, 0xff0000), 2 * 8)
  local g = bit.rshift(bit.band(abgr, 0x00ff00), 1 * 8)
  local r = bit.band(abgr, 0x0000ff)
  return r, g, b
end

local function encode_coords(x, y)
  return x + y * 0x1000
end

local content = "return {"

for y=0,48-1 do
  for x=0,3-1 do
    local r, g, b = _BiomeMapGetPixel(x, y)
    content = content .. "["..encode_coords(x, y).."] = " .. string.format("{ r = %s, g = %s, b = %s },", r, g, b)
  end
end

content = content .. "}\n"
ModTextFileSetContent("mods/LocationTracker/_virtual/map.lua", content)
