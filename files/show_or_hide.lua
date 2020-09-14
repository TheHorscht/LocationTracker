function set_minimap_visible(visible)
  local location_tracker = EntityGetWithName("location_tracker")
  local sprite_components = EntityGetComponent(location_tracker, "SpriteComponent")
  if sprite_components then
    for y=0,10 do
      for x=0,10 do
        ComponentSetValue2(sprite_components[(x+1)+(y*11)], "visible", visible)
      end
    end
  end
  local you_are_here = EntityGetWithName("location_tracker_you_are_here")
  local sprite_component = EntityGetFirstComponent(you_are_here, "SpriteComponent")
  ComponentSetValue2(sprite_component, "visible", visible)
end
