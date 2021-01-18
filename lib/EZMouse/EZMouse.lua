local function is_inside_rect(x, y, rect_x, rect_y, width, height)
	return not ((x < rect_x) or (x > rect_x + width) or (y < rect_y) or (y > rect_y + height))
end

local draggables = {}
local function new_draggable(x, y, width, height, callbacks)
	local draggable = { x = x, y = y, width = width, height = height,	_dragging = false,
		callbacks = callbacks or {}
	}
	table.insert(draggables, draggable)
	return draggable
end

local sx, sy, dx, dy, left_down

local function update(gui)
	if not controls_component then
		local entity_name = "LocationTracker_controls_entity"
		local controls_entity = EntityGetWithName(entity_name)
		if controls_entity == 0 then
			controls_entity = EntityCreateNew(entity_name)
		end
		controls_component = EntityAddComponent2(controls_entity, "ControlsComponent")
	end
	
	mouse_loop_last_x = mouse_loop_last_x or 0
  mouse_loop_last_y = mouse_loop_last_y or 0
  local x, y
	-- Get whatever state we can directly from the component
	if controls_component then
		x, y = ComponentGetValue2(controls_component, "mMousePosition")
		left_down = ComponentGetValue2(controls_component, "mButtonDownFire")
		left_pressed = ComponentGetValue2(controls_component, "mButtonFrameFire") == GameGetFrameNum()
		-- right_down = ComponentGetValue2(controls_component, "mButtonDownRightClick")
	end
	local virt_x = MagicNumbersGetValue("VIRTUAL_RESOLUTION_X")
	local virt_y = MagicNumbersGetValue("VIRTUAL_RESOLUTION_Y")
	local screen_width, screen_height = GuiGetScreenDimensions(gui)
	local scale_x = virt_x / screen_width
	local scale_y = virt_y / screen_height
	local cx, cy = GameGetCameraPos()
	sx, sy = (x - cx) / scale_x + screen_width / 2 + 1.5, (y - cy) / scale_y + screen_height / 2
	-- Calculate mMouseDelta ourselves because the native one isn't consistent across all window sizes
	dx, dy = math.floor(sx + 0.5) - math.floor(mouse_loop_last_x + 0.5), math.floor(sy + 0.5) - math.floor(mouse_loop_last_y + 0.5)
	mouse_loop_last_x = sx
	mouse_loop_last_y = sy
	-- local gui_y = 250
	-- local function new_line() gui_y = gui_y + 10 end
	-- GuiText(gui, 40, gui_y, "msx: " .. tostring(math.floor(sx)))
	-- GuiText(gui, 100, gui_y, "msy: " .. tostring(math.floor(sy)))
	-- new_line()
	-- GuiText(gui, 40, gui_y, "dx: " .. tostring(dx))
	-- GuiText(gui, 100, gui_y, "dy: " .. tostring(dy))
	-- new_line()
	-- GuiText(gui, 40, gui_y, "virt_x: " .. tostring(virt_x))
	-- GuiText(gui, 130, gui_y, "virt_y: " .. tostring(virt_y))
	-- new_line()
	-- GuiText(gui, 40, gui_y, "screen_width: " .. tostring(screen_width))
	-- GuiText(gui, 130, gui_y, "screen_height: " .. tostring(screen_height))
	
	local prevent_wand_firing = false
	for i, draggable in ipairs(draggables) do
		if draggable._dragging and not left_down then
			draggable._dragging = false
		end
		draggable.is_hovered = is_inside_rect(sx, sy, draggable.x, draggable.y, draggable.width, draggable.height)
		local players = EntityGetWithTag("player_unit")

		if draggable.is_hovered or draggable._dragging then
			prevent_wand_firing = true
		end

		if draggable.is_hovered and left_pressed then
			draggable._dragging = true
		end

		if draggable._dragging and draggable.callbacks.on_drag then
			if dx ~= 0 or dy ~= 0 then
				draggable.callbacks.on_drag(draggable, dx, dy)
			end
		end
	end
	
	GlobalsSetValue("EZMouse_prevent_wand_firing", prevent_wand_firing and "1" or "0")
end

return setmetatable({
  new_draggable = new_draggable,
  update = update,
}, {
  __index = function(self, key)
    return ({
      x = sx,
      y = sy,
      dx = dx,
      dy = dy,
      left_down = left_down
    })[key]
  end
})
