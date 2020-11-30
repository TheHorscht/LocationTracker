local entity_id = GetUpdatedEntityID()
local x, y = EntityGetTransform(entity_id)
controls_component = controls_component or EntityGetFirstComponentIncludingDisabled(entity_id, "ControlsComponent")
-- ComponentGetValue2(controls_component, "m")
