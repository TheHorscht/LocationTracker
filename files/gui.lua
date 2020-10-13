dofile_once("mods/LocationTracker/files/show_or_hide.lua")

gui = gui or GuiCreate()

local id = 0
function create_id()
  id = id + 1
  return id
end

GuiStartFrame(gui)
GuiLayoutBeginVertical(gui, 87, 14)
local open_or_close = HasFlagPersistent("locationtracker_hide_map") and "+" or "-"
if GuiButton(gui, 2, 0, "["..open_or_close.."]", create_id()) then
  if HasFlagPersistent("locationtracker_hide_map") then
    RemoveFlagPersistent("locationtracker_hide_map")
    set_minimap_visible(true)
  else
    AddFlagPersistent("locationtracker_hide_map")
    set_minimap_visible(false)
  end
end
if not HasFlagPersistent("locationtracker_hide_map") then
  if GuiButton(gui, 2, 0, "[FOW]", create_id()) then
    GlobalsSetValue("LocationTracker_force_update", "1")
    if HasFlagPersistent("locationtracker_fog_of_war_disabled") then
      RemoveFlagPersistent("locationtracker_fog_of_war_disabled")
    else
      AddFlagPersistent("locationtracker_fog_of_war_disabled")
    end
  end
end
GuiLayoutEnd(gui)
