dofile_once("data/scripts/lib/utilities.lua")

color_data = color_data or {}
local zoom = 1.5
size = size or { x = 11, y = 11 }
local block_size = { x = 3, y = 3 }
local total_size = { x = size.x * block_size.x * zoom, y = size.y * block_size.y * zoom }

local screen_width, screen_height = GuiGetScreenDimensions(gui)
local scr_half_w = screen_width/2
local scr_half_h = screen_height/2
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
-- if not screen_width then
-- end





if GlobalsGetValue("LocationTracker_show_full_map", "0") == "1" and map then

  offx = offx or 0
  offy = offy or 0
  locked = locked == nil and true or locked
  if visible == nil then visible = true end
  if fog_of_war == nil then fog_of_war = true end
  -- Drag handle
  if not locked then
    GuiOptionsAddForNextWidget(gui, GUI_OPTION.IsDraggable)
    local tw, th = GuiGetTextDimensions(gui, "DRAG")
    local start_x = offx + screen_width/2 - math.floor(tw/2)
    local start_y = offy + screen_height/2 - tot_size_half_y - th - 2
    GuiButton(gui, 9999, start_x, start_y, "DRAG")
    local clicked, right_clicked, hovered, xx, yy, width, height, draw_x, draw_y = GuiGetPreviousWidgetInfo(gui)
    offx = math.floor(offx + (draw_x - start_x))
    offy = math.floor(offy + (draw_y - start_y))

    -- GuiTooltip(gui, "Resize", "Drag to resize the minimap size")

    local start_x = math.floor(offx + scr_half_w + tot_size_half_x) - 2
    local start_y = math.floor(offy + scr_half_h + tot_size_half_y) - 2
    GuiOptionsAddForNextWidget(gui, GUI_OPTION.NoPositionTween)
    GuiOptionsAddForNextWidget(gui, GUI_OPTION.IsDraggable)
    -- GuiImageButton(gui, 10005, start_x, start_y, "", "mods/LocationTracker/files/resize_handle.png")
    GuiButton(gui, 10005, start_x, start_y, "  ")
    local clicked, right_clicked, hovered, xx, yy, width, height, draw_x, draw_y = GuiGetPreviousWidgetInfo(gui)
    GuiImage(gui, 10006, xx, yy, "mods/LocationTracker/files/resize_handle.png", 1, 1, 0)
    local dx = math.floor((xx - start_x) / zoom / 10)
    local dy = math.floor((yy - start_y) / zoom / 10)
    size.x = math.max(3, size.x + dx)
    size.y = math.max(3, size.y + dy)
    color_data = {}
  end
  -- Lock button
  GuiOptionsAddForNextWidget(gui, GUI_OPTION.NoPositionTween)
  if GuiImageButton(gui, 10000, math.floor(offx + scr_half_w + tot_size_half_x + 5), math.floor(offy + scr_half_h - tot_size_half_y - 2), "", "mods/LocationTracker/files/lock_"..(locked and "closed" or "open") ..".png") then
    locked = not locked
  end
  -- Show/hide button
  GuiOptionsAddForNextWidget(gui, GUI_OPTION.NoPositionTween)
  if GuiImageButton(gui, 10002, math.floor(offx + scr_half_w + tot_size_half_x + 5), math.floor(offy + scr_half_h - tot_size_half_y + 10), "", "mods/LocationTracker/files/eye_"..(visible and "closed" or "open") ..".png") then
    visible = not visible
  end
  -- -- Config icon
  -- GuiOptionsAddForNextWidget(gui, GUI_OPTION.NoPositionTween)
  -- if GuiImageButton(gui, 10001, math.floor(offx + scr_half_w + tot_size_half_x + 4), math.floor(offy + scr_half_h - tot_size_half_y + 21), "", "mods/LocationTracker/files/icon_config.png") then
  --   -- locked = not locked
  -- end
  -- Fog of war button
  GuiOptionsAddForNextWidget(gui, GUI_OPTION.NoPositionTween)
  if GuiImageButton(gui, 10003, math.floor(offx + scr_half_w + tot_size_half_x + 5), math.floor(offy + scr_half_h - tot_size_half_y + 21), "", "mods/LocationTracker/files/fog_of_war_"..(fog_of_war and "on" or "off") ..".png") then
    fog_of_war = not fog_of_war
  end
  -- Border
  GuiImageNinePiece(gui, 10004, math.floor(offx + screen_width/2 - total_size.x/2), math.floor(offy + screen_height/2 - total_size.y/2), total_size.x, total_size.y, 1, "mods/LocationTracker/files/border.png")
  for y=0, size.y-1 do
    for x=0, size.x-1 do
      local idx = x+y*size.x
      color_data[idx] = color_data[idx] or get_color_data(0, 0, x-math.floor(size.x/2), y-math.floor(size.y/2))
      local color = color_data[idx]
      GuiColorSetForNextWidget(gui, color.color.r, color.color.g, color.color.b, 1)
      GuiImage(gui, 10010 + idx+1, math.floor(offx) + math.floor(scr_half_w - tot_size_half_x) + x*zoom_block_x, math.floor(offy) + math.floor(scr_half_h - tot_size_half_y) + y*zoom_block_y, "mods/LocationTracker/a.png", 1, zoom, 0)
    end
  end
end








GuiLayoutBeginVertical(gui, 87, 14)
local open_or_close = HasFlagPersistent("locationtracker_hide_map") and "+" or "-"
if GuiButton(gui, 2, 0, "["..open_or_close.."]", create_id()) then
  if HasFlagPersistent("locationtracker_hide_map") then
    RemoveFlagPersistent("locationtracker_hide_map")
  else
    AddFlagPersistent("locationtracker_hide_map")
  end
end
if not HasFlagPersistent("locationtracker_hide_map") then
  if GuiButton(gui, 2, 0, "[FOW]", create_id()) then
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
