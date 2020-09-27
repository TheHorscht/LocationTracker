local entity_id = GetUpdatedEntityID()
local x, y = EntityGetTransform(entity_id)

for y=0,10 do
  for x=0,10 do
    local child = EntityCreateNew()
    EntityAddChild(entity_id, child)
    EntityAddComponent2(child, "SpriteComponent", {
      image_file="mods/LocationTracker/_virtual/biome_map.xml",
      offset_x=1.5,
      offset_y=1.5,
      smooth_filtering=false,
      ui_is_parent=true,
      alpha=1,
    })
  end
end
