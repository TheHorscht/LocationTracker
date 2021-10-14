dofile_once("mods/LocationTracker/files/encode_coords.lua")

function does_png_exist(path)
  local exists = false
  xpcall(function()
    gui = GuiCreate()
    local a = GuiGetImageDimensions(gui, path)
    exists = a ~= 0
  end, function() end)
  return exists
end

function _BiomeMapGetPixel(x, y)
  local abgr = BiomeMapGetPixel(x, y)
  local b = bit.rshift(bit.band(abgr, 0xff0000), 2 * 8)
  local g = bit.rshift(bit.band(abgr, 0x00ff00), 1 * 8)
  local r = bit.band(abgr, 0x0000ff)
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
