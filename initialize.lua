local entity_id = GetUpdatedEntityID()
local x, y = EntityGetTransform(entity_id)
for y=0,9 do
  for x=0,9 do
    EntityAddComponent2(entity_id, "SpriteComponent", {
      image_file="mods/LocationTracker/_virtual/biome_map.xml",
      offset_x=-x,
      offset_y=-y,
      -- has_special_scale=true,
      -- special_scale_x=1.1,
      -- special_scale_y=50,
      smooth_filtering=false,
      -- z_index=-999,
      ui_is_parent=true,
    })
  end
end
