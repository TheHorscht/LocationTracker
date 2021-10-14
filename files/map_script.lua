dofile_once("mods/LocationTracker/files/map_utils.lua")

local custom_map_file = "mods/LocationTracker/custom_map.png"
local w, h = 70, 48
BiomeMapSetSize(w, h)
if ModSettingGet("LocationTracker.use_custom_map_file") and does_png_exist(custom_map_file) then
  BiomeMapLoadImage(0,0, custom_map_file)
else
  BiomeMapLoadImage(0,0, "data/biome_impl/biome_map.png")
end
ModTextFileSetContent("mods/LocationTracker/_virtual/map.lua", make_string(w, h))
