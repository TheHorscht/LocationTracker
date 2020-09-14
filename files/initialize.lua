local entity_id = GetUpdatedEntityID()
local x, y = EntityGetTransform(entity_id)
for y=0,10 do
  for x=0,10 do
    EntityAddComponent2(entity_id, "SpriteComponent", {
      image_file="mods/LocationTracker/_virtual/biome_map.xml",
      offset_x=-x,
      offset_y=-y,
      smooth_filtering=false,
      ui_is_parent=true,
      alpha=0.8,
    })
  end
end
