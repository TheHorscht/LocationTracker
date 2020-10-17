function set_minimap_visible(visible)
  local location_tracker = EntityGetWithName("location_tracker")
  local border_sprite = EntityGetFirstComponentIncludingDisabled(location_tracker, "SpriteComponent")
  EntitySetComponentIsEnabled(location_tracker, border_sprite, visible)
  EntityRefreshSprite(location_tracker, border_sprite)
  local children = EntityGetAllChildren(location_tracker) or {}
  for i, child in ipairs(children) do
    local sprite_component = EntityGetFirstComponentIncludingDisabled(child, "SpriteComponent")
    EntitySetComponentIsEnabled(child, sprite_component, visible)
    EntityRefreshSprite(child, sprite_component)
  end
  local you_are_here = EntityGetWithName("location_tracker_you_are_here")
  local sprite_component = EntityGetFirstComponentIncludingDisabled(you_are_here, "SpriteComponent")
  EntitySetComponentIsEnabled(you_are_here, sprite_component, visible)
  EntityRefreshSprite(you_are_here, sprite_component)
  GlobalsSetValue("LocationTracker_needs_update", "1")
end
