dofile_once("mods/LocationTracker/files/show_or_hide.lua")
dofile_once("data/scripts/lib/utilities.lua")

color_data = color_data or {}
local screen_width, screen_height
local zoom = 1.5
local size = { x = 100, y = 50 }
local block_size = { x = 3, y = 3 }
local total_size = { x = size.x * block_size.x * zoom, y = size.y * block_size.y * zoom }

local scr_half_w
local scr_half_h
local tot_size_half_x = total_size.x/2
local tot_size_half_y = total_size.y/2
local zoom_block_x = zoom*block_size.x
local zoom_block_y = zoom*block_size.y


gui = gui or GuiCreate()

local id = 0
function create_id()
  id = id + 1
  return id
end

GuiStartFrame(gui)
if not screen_width then
  screen_width, screen_height = GuiGetScreenDimensions(gui)
  scr_half_w = screen_width/2
  scr_half_h = screen_height/2
end





if GlobalsGetValue("LocationTracker_show_full_map", "0") == "1" and map then

  offx = offx or 0
  offy = offy or 0
  locked = locked == nil and true or locked
  if visible == nil then visible = true end

  -- Drag handle
  if not locked then
    GuiOptionsAddForNextWidget(gui, GUI_OPTION.IsDraggable)
    local tw, th = GuiGetTextDimensions(gui, "DRAG")
    local start_x = offx + screen_width/2 - math.floor(tw/2)
    local start_y = offy + screen_height/2 - tot_size_half_y - th - 2
    GuiButton(gui, create_id(), start_x, start_y, "DRAG")
    local clicked, right_clicked, hovered, xx, yy, width, height, draw_x, draw_y = GuiGetPreviousWidgetInfo(gui)
    offx = offx + (draw_x - start_x)
    offy = offy + (draw_y - start_y)	
  end
  -- Lock button
  GuiOptionsAddForNextWidget(gui, GUI_OPTION.NoPositionTween)
  if GuiImageButton(gui, create_id(), scr_half_w - tot_size_half_x - 30, scr_half_h - tot_size_half_y, "", "mods/LocationTracker/files/lock_"..(locked and "closed" or "open") ..".png") then
    locked = not locked
  end
  -- Config icon
  GuiOptionsAddForNextWidget(gui, GUI_OPTION.NoPositionTween)
  if GuiImageButton(gui, create_id(), scr_half_w - tot_size_half_x - 31, scr_half_h - tot_size_half_y + 12, "", "mods/LocationTracker/files/icon_config.png") then
    -- locked = not locked
  end
  -- Show/hide button
  GuiOptionsAddForNextWidget(gui, GUI_OPTION.NoPositionTween)
  if GuiImageButton(gui, create_id(), scr_half_w - tot_size_half_x - 30, scr_half_h - tot_size_half_y + 23, "", "mods/LocationTracker/files/eye_"..(visible and "closed" or "open") ..".png") then
    visible = not visible
  end
  -- Border
  GuiImageNinePiece(gui, create_id(), offx + screen_width/2 - total_size.x/2, offy + screen_height/2 - total_size.y/2, total_size.x, total_size.y, 1, "mods/LocationTracker/files/border.png")
  for y=0, size.y-1 do
    for x=0, size.x-1 do
      local idx = x+y*size.x
      color_data[idx] = color_data[idx] or get_color_data(0, 0, x-math.floor(size.x/2), y-math.floor(size.y/2))
      local color = color_data[idx]
      GuiColorSetForNextWidget(gui, color.color.r, color.color.g, color.color.b, 1)
      GuiImage(gui, create_id() + idx+1, offx + scr_half_w - tot_size_half_x + x*zoom_block_x, offy + scr_half_h - tot_size_half_y + y*zoom_block_y, "mods/LocationTracker/a.png", 1, zoom, 0)
    end
  end
end








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
if GuiButton(gui, 2, 0, "[EXPAND DONG]", create_id()) then
  local full_map = GlobalsGetValue("LocationTracker_show_full_map", "0")
  GlobalsSetValue("LocationTracker_show_full_map", tostring(1 - tonumber(full_map)))
  print(tostring(1 - tonumber(full_map)))
end
GuiLayoutEnd(gui)
