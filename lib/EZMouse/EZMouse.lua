local function is_inside_rect(x, y, rect_x, rect_y, width, height)
	return not ((x < rect_x) or (x > rect_x + width) or (y < rect_y) or (y > rect_y + height))
end

-- local draggables = setmetatable({}, { __mode = "v" })
local Draggable = {
  instances = setmetatable({}, { __mode = "v" }),
}

function Draggable.new(x, y, width, height)
  local protected = {
    dragging = false,
    is_hovered = false,
  }
  local o = setmetatable({
    _protected = protected,
    x = x,
    y = y,
    width = width,
    height = height,
    event_listeners = {
      drag = {},
      drag_start = {},
      drag_end = {},
    }
  }, {
    __index = function(self, key)
      if protected[key] ~= nil then
        return protected[key]
      end
      return rawget(self, key)
    end,
    __newindex = function(self, key, value)
      if protected[key] ~= nil then
        error("'"..key.."' is read-only.")
      end
      rawset(self, key, value)
    end
  })
  table.insert(Draggable.instances, o)
  
  local function fire_event(self, name, ...)
    for i, listener in ipairs(self.event_listeners[name]) do
      listener(self, ...)
    end
  end

  o.Update = function(self, sx, sy, dx, dy, left_down, left_pressed)
    local prevent_wand_firing = false

		if protected.dragging and not left_down then
      protected.dragging = false
      fire_event(self, "drag_end", self.x, self.y)
    end
    
    protected.is_hovered = is_inside_rect(sx, sy, self.x, self.y, self.width, self.height)
		if protected.is_hovered or protected.dragging then
			prevent_wand_firing = true
		end

		protected.is_hovered = is_inside_rect(sx, sy, self.x, self.y, self.width, self.height)
		if protected.is_hovered or protected.dragging then
			prevent_wand_firing = true
		end

		if protected.is_hovered and left_pressed then
      protected.dragging = true
      fire_event(self, "drag_start", self.x, self.y)
		end

		if protected.dragging then
      if dx ~= 0 or dy ~= 0 then
        fire_event(self, "drag", dx, dy)
			end
    end

    return prevent_wand_firing
  end

  o.AddEventListener = function(self, event_name, listener)
    local event_listeners = rawget(self, "event_listeners")
    if not event_listeners[event_name] then
      error("No event by the name of '"..event_name.."'", 2)
    end
    table.insert(event_listeners[event_name], listener)
    return listener
  end

  o.RemoveEventListener = function(self, event_name, listener)
    local event_listeners = rawget(self, "event_listeners")
    if not event_listeners[event_name] then
      error("No event by the name of '"..event_name.."'", 2)
    end
    for i, v in ipairs(event_listeners[event_name]) do
      if v == listener then
        table.remove(event_listeners[event_name], i)
        return
      end
    end
    error("Cannot remove a listener that was never registered.", 2)
  end

	return o
end

local event_listeners = {
  mouse_down = {},
  mouse_up = {},
  mouse_move = {},
}

local function fire_event(name, ...)
  for i, listener in ipairs(event_listeners[name]) do
    listener(...)
  end
end

local function AddEventListener(event_name, listener)
  if not event_listeners[event_name] then
    error("No event by the name of '"..event_name.."'", 2)
  end
  table.insert(event_listeners[event_name], listener)
  return listener
end

local function RemoveEventListener(event_name, listener)
  if not event_listeners[event_name] then
    error("No event by the name of '"..event_name.."'", 2)
  end
  for i, v in ipairs(event_listeners[event_name]) do
    if v == listener then
      table.remove(event_listeners[event_name], i)
      return
    end
  end
  error("Cannot remove a listener that was never registered.", 2)
end

local x, y, sx, sy, dx, dy, left_down, left_pressed, right_down, right_pressed,
  left_down_last_frame, right_down_last_frame

--[[ 
  TODO:
  -- Z-Index so we can use resize handles ON TOP of a draggable?
 ]]

local function update(gui) -- EZMouse_gui
  EZMouse_gui = EZMouse_gui or gui or GuiCreate()
	if not controls_component then
		local entity_name = "EZMouse_controls_entity"
		local controls_entity = EntityGetWithName(entity_name)
		if controls_entity == 0 then
			controls_entity = EntityCreateNew(entity_name)
		end
		controls_component = EntityAddComponent2(controls_entity, "ControlsComponent")
	end
	
	mouse_loop_last_sx = mouse_loop_last_sx or 0
  mouse_loop_last_sy = mouse_loop_last_sy or 0
	-- Get whatever state we can directly from the component
	if controls_component and GameGetFrameNum() > 10 then
    x, y = ComponentGetValue2(controls_component, "mMousePosition")
    
    left_down = ComponentGetValue2(controls_component, "mButtonDownFire")
    left_pressed = ComponentGetValue2(controls_component, "mButtonFrameFire") == GameGetFrameNum()

    right_down = ComponentGetValue2(controls_component, "mButtonDownRightClick")
    right_pressed = ComponentGetValue2(controls_component, "mButtonFrameRightClick") == GameGetFrameNum()

    local virt_x = MagicNumbersGetValue("VIRTUAL_RESOLUTION_X")
    local virt_y = MagicNumbersGetValue("VIRTUAL_RESOLUTION_Y")
    local screen_width, screen_height = GuiGetScreenDimensions(EZMouse_gui)
    local scale_x = virt_x / screen_width
    local scale_y = virt_y / screen_height
    local cx, cy = GameGetCameraPos()
    sx, sy = (x - cx) / scale_x + screen_width / 2 + 1.5, (y - cy) / scale_y + screen_height / 2
    -- Calculate mMouseDelta ourselves because the native one isn't consistent across all window sizes
    dx, dy = math.floor(sx + 0.5) - math.floor(mouse_loop_last_sx + 0.5), math.floor(sy + 0.5) - math.floor(mouse_loop_last_sy + 0.5)
    
    local prevent_wand_firing = false
    for i, draggable in ipairs(Draggable.instances) do
      prevent_wand_firing = draggable:Update(sx, sy, dx, dy, left_down, left_pressed) or prevent_wand_firing
    end
    
    GlobalsSetValue("EZMouse_prevent_wand_firing", prevent_wand_firing and "1" or "0")
    
    if left_pressed then fire_event("mouse_down", { button = "left", screen_x = sx, screen_y = sy, world_x = x, world_y = y }) end
    if right_pressed then fire_event("mouse_down", { button = "right", screen_x = sx, screen_y = sy, world_x = x, world_y = y }) end
    if not left_down and left_down_last_frame then fire_event("mouse_up", { button = "left", screen_x = sx, screen_y = sy, world_x = x, world_y = y }) end
    if not right_down and right_down_last_frame then fire_event("mouse_up", { button = "right", screen_x = sx, screen_y = sy, world_x = x, world_y = y }) end
    
    local movement_tolerance = 0.5
    local vx = sx - mouse_loop_last_sx
    local vy = sy - mouse_loop_last_sy
    if math.abs(vx) >= movement_tolerance or math.abs(vy) >= movement_tolerance then
      fire_event("mouse_move", { screen_x = sx, screen_y = sy, world_x = x, world_y = y, vx = vx, vy = vy })
    end

    mouse_loop_last_sx = sx
    mouse_loop_last_sy = sy
    left_down_last_frame = left_down
    right_down_last_frame = right_down
	end
end

return setmetatable({
  Draggable = Draggable,
  update = update,
  AddEventListener = AddEventListener,
  RemoveEventListener = RemoveEventListener,
}, {
  __index = function(self, key)
    return ({
      screen_x = sx,
      screen_y = sy,
      world_x = x,
      world_y = y,
      dx = dx,
      dy = dy,
      left_down = left_down,
      right_down = right_down
    })[key]
  end,
})
