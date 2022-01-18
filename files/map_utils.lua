dofile_once("mods/LocationTracker/files/encode_coords.lua")
local nxml = dofile_once("mods/LocationTracker/lib/nxml.lua")
local ModTextFileGetContent = ModTextFileGetContent

function does_png_exist(path)
  local exists = false
  xpcall(function()
    gui = GuiCreate()
    local a = GuiGetImageDimensions(gui, path)
    exists = a ~= 0
  end, function() end)
  return exists
end

local function seperate_color_channels(color, reverse_rgb)
  local r = bit.rshift(bit.band(color, 0xff0000), 2 * 8)
  local g = bit.rshift(bit.band(color, 0x00ff00), 1 * 8)
  local b = bit.band(color, 0x0000ff)
  if reverse_rgb then
    return b, g, r
  else
    return r, g, b
  end
end

function _BiomeMapGetPixel(x, y)
  local abgr = BiomeMapGetPixel(x, y)
  local r, g, b = seperate_color_channels(abgr, true)
  return r, g, b
end

function make_string(w, h)
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
  return content
end

local function biome_map_get_color_and_name(x, y)
  -- First build filename lookup if it doesn't exist yet
  -- lookup translates from filename to color
  if not lookup then
    lookup = {}
    local content = ModTextFileGetContent("data/biome/_biomes_all.xml")
    local xml = nxml.parse(content)
    lookup.biome_offset_y = xml.attr.biome_offset_y
    for biome in xml:each_child("Biome") do
      local color = tonumber(biome.attr.color, 16) 
      lookup[biome.attr.biome_filename] = color
    end
  end
  local w, h = BiomeMapGetSize()
  local filename = DebugBiomeMapGetFilename((x + w/2) * 512 + 256, (y - lookup.biome_offset_y) * 512 + 256)
  local r, g, b = seperate_color_channels(lookup[filename])
  return unpack({ r, g, b, "Hanswurst"})
end

function get_map_data_by_biome_filename()
  local map = {}
  local w, h = BiomeMapGetSize()
  for y=0,h-1 do
    for x=0,w-1 do
      local r, g, b, name = biome_map_get_color_and_name(x, y)
      local coords = encode_coords(x, y)
      map[coords] = { r = r, g = g, b = b } -- 0-255
      map[coords].name = name
    end
  end

  return {
    width = w,
    height = h,
    map = map
  }
end
