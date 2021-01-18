dofile_once("data/scripts/lib/utilities.lua")

local old_draw_action = draw_action
function draw_action(arg1)
  local world_state = GameGetWorldStateEntity()
  if is_valid_entity(world_state) then
    -- Replace this function with my own
    draw_action = LocationTracker_draw_action
    draw_action(arg1)
  else
    old_draw_action(arg1)
  end
end

function LocationTracker_draw_action(arg1)
  local entity_id = GetUpdatedEntityID()
  if EntityHasTag(entity_id, "player_unit") and GlobalsGetValue("EZMouse_prevent_wand_firing", "0") ~= "1" then
    old_draw_action(arg1)
  end
end
