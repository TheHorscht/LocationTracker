function set_minimap_visible(visible)
  local location_tracker = EntityGetWithName("location_tracker")
  local border_sprite = EntityGetFirstComponentIncludingDisabled(location_tracker, "SpriteComponent")
  ComponentSetValue2(border_sprite, "visible", visible)
  local children = EntityGetAllChildren(location_tracker) or {}
  for i, child in ipairs(children) do
    local sprite_component = EntityGetFirstComponentIncludingDisabled(child, "SpriteComponent")
    ComponentSetValue2(sprite_component, "visible", visible)
  end
  local you_are_here = EntityGetWithName("location_tracker_you_are_here")
  local sprite_component = EntityGetFirstComponent(you_are_here, "SpriteComponent")
  ComponentSetValue2(sprite_component, "visible", visible)
  GlobalsSetValue("LocationTracker_needs_update", "1")
end
