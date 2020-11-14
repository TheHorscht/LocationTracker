return {
--[[ 
Format of the virtual file:
return {
  0xFFAABBC1 = "mods/whatevermod/files/locationtracker/spritesheet.xml",
  0xFFAABBC2 = "mods/whatevermod/files/locationtracker/spritesheet2.xml",
}
]]
  add_colors = function(colors, sprite_sheet)
    local virtual_file_path = "mods/LocationTracker/_virtual/mod_colors.lua"
    local content = ModTextFileGetContent(virtual_file_path) or [[return {
}]]
    local content_to_add = ""
    for i, color in ipairs(colors) do
      content_to_add = content_to_add .. "  [" .. tostring(color) .. string.format([[] = "%s",]] .. "\n", sprite_sheet)
    end
    content = content:gsub("\n}", "\n" .. content_to_add .. "}")
    ModTextFileSetContent(virtual_file_path, content)
  end
}
