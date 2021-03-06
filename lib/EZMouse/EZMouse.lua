--[[ EZMouse v0.1.0

v0.1.0:
- Added mouse_down(self, x, y) event to widget

]]

local function is_inside_rect(x, y, rect_x, rect_y, width, height)
	return not ((x < rect_x) or (x > rect_x + width) or (y < rect_y) or (y > rect_y + height))
end

-- local draggables = setmetatable({}, { __mode = "v" })
local Widget = {
  instances = setmetatable({}, { __mode = "v" }),
}

-- function Widget.new(x, y, width, height, resizable)
function Widget.new(props)
  if type(props) ~= "table" then
    error("'props' needs to be a table.", 2)
  end

  local resize_start_sx, resize_start_sy = 0, 0
  local resize_start_width, resize_start_height = 0, 0
  local drag_start_sx, drag_start_sy = 0, 0
  local protected = {
    resizing = false,
    dragging = false,
    is_hovered = false,
  }

  local o = setmetatable({
    _protected = protected,
    x = props.x or 0,
    y = props.y or 0,
    width = props.width or 100,
    height = props.height or 100,
    min_width = props.min_width or 10,
    min_height = props.min_height or 10,
    draggable = props.draggable == nil and true or not not props.draggable,
    drag_granularity = props.drag_granularity or 0.1,
    resizable = not not props.resizable,
    resize_granularity = props.resize_granularity or 0.1,
    resize_symmetrical = not not props.resize_symmetrical,
    resize_uniform = not not props.resize_uniform,
    enabled = props.enabled == nil and true or not not props.enabled,
    event_listeners = {
      mouse_down = {},
      drag = {},
      drag_start = {},
      drag_end = {},
      resize = {},
      resize_start = {},
      resize_end = {},
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
        error("'"..key.."' is read-only.", 2)
      end
      rawset(self, key, value)
    end
  })

  if o.min_width > o.width then
    error(string.format("min_width(%d) needs to be smaller than width(%d).", o.min_width, o.width), 2)
  end
  if o.min_height > o.height then
    error(string.format("min_height(%d) needs to be smaller than height(%d).", o.min_height, o.height), 2)
  end

  table.insert(Widget.instances, o)
  
  local function fire_event(self, name, ...)
    for i, listener in ipairs(self.event_listeners[name]) do
      listener(self, ...)
    end
  end

  o.Update = function(self, sx, sy, dx, dy, left_down, left_pressed)
    if not self.enabled then return false end
    local prevent_wand_firing = false
    
    if protected.resizing and not left_down then
      protected.resizing = false
    end
    protected.resize_handle_hovered = false

    local handle_size = 6

    local function calculate_handle_props()
      return {
        { x = self.x - (handle_size/2),              y = self.y - (handle_size/2),               width = handle_size,              height = handle_size,               move = {-1,-1} }, -- top left
        { x = self.x + (handle_size/2),              y = self.y - (handle_size/2),               width = self.width - handle_size, height = handle_size,               move = {0,-1}  }, -- top
        { x = self.x + self.width - (handle_size/2), y = self.y - (handle_size/2),               width = handle_size,              height = handle_size,               move = {1,-1}  }, -- top right
        { x = self.x + self.width - (handle_size/2), y = self.y + (handle_size/2),               width = handle_size,              height = self.height - handle_size, move = {1,0}   }, -- right
        { x = self.x + self.width - (handle_size/2), y = self.y + self.height - (handle_size/2), width = handle_size,              height = handle_size,               move = {1,1}   }, -- bottom right
        { x = self.x + (handle_size/2),              y = self.y + self.height - (handle_size/2), width = self.width - handle_size, height = handle_size,               move = {0,1}   }, -- bottom
        { x = self.x - (handle_size/2),              y = self.y + self.height - (handle_size/2), width = handle_size,              height = handle_size,               move = {-1,1}  }, -- bottom left
        { x = self.x - (handle_size/2),              y = self.y + (handle_size/2),               width = handle_size,              height = self.height - handle_size, move = {-1,0}  }, -- left
      }
    end

    local resize_handles = calculate_handle_props()
    
    if not (protected.resizing or protected.dragging) then
      for i, handle in ipairs(resize_handles) do
        if self.resizable and is_inside_rect(sx, sy, handle.x, handle.y, handle.width, handle.height) then
          protected.resize_handle_hovered = i
          protected.resize_handle = resize_handles[i]
          if left_pressed then
            protected.resizing = i
            fire_event(self, "resize_start", i)
            resize_start_sx = sx
            resize_start_sy = sy
            resize_start_x = self.x
            resize_start_y = self.y
            resize_start_width = self.width
            resize_start_height = self.height
            aspect_ratio = self.width / self.height
          end
          break
        end
      end
    end

    local move_x, move_y = dx, dy
    local start_x, start_y = self.x, self.y
    local start_width, start_height = self.width, self.height

    if protected.resizing then
      local width_change = math.floor((resize_start_sx - sx) * -protected.resize_handle.move[1] * (self.resize_symmetrical and 2 or 1) + self.resize_granularity / 2 + 0.5)
      local new_width = resize_start_width + width_change
      new_width = math.floor(new_width / self.resize_granularity) * self.resize_granularity
      
      local height_change = math.floor((resize_start_sy - sy) * -protected.resize_handle.move[2] * (self.resize_symmetrical and 2 or 1) + self.resize_granularity / 2 + 0.5)
      local new_height = resize_start_height + height_change
      new_height = math.floor(new_height / self.resize_granularity) * self.resize_granularity
      -- move_ will be positive if moving outwards and negative when moving inwards
      local has_moved = math.abs(width_change) > 0.5 or math.abs(height_change) > 0.5
      if self.resize_uniform then
        local scale_x = (resize_start_x + resize_start_width * math.max(0, -protected.resize_handle.move[1]) - sx) * -protected.resize_handle.move[1] / resize_start_width
        local scale_y = (resize_start_y + resize_start_height * math.max(0, -protected.resize_handle.move[2]) - sy) * -protected.resize_handle.move[2] / resize_start_height
        local scale = math.max(scale_x, scale_y)
        -- local scale_granularity = self.resize_granularity
        -- scale = math.floor(scale / scale_granularity) * scale_granularity
        local scale_min_x = self.min_width / resize_start_width
        local scale_min_y = self.min_height / resize_start_height
        local scale_min = math.max(scale_min_x, scale_min_y)
        scale = math.max(scale_min, scale)
        new_width = resize_start_width * scale
        new_height = resize_start_height * scale
      end
      self.width = math.max(self.min_width, new_width)
      self.height = math.max(self.min_height, new_height)
      move_x = (self.width - start_width) * (self.resize_symmetrical and 0.5 or 1)
      move_y = (self.height - start_height) * (self.resize_symmetrical and 0.5 or 1)
      self.x = self.x + move_x * math.min(self.resize_symmetrical and -1 or 0, protected.resize_handle.move[1])
      self.y = self.y + move_y * math.min(self.resize_symmetrical and -1 or 0, protected.resize_handle.move[2])
      resize_handles = calculate_handle_props()
      protected.resize_handle = resize_handles[protected.resizing]
      if has_moved then
        fire_event(self, "resize", move_x, move_y)
      end
    end

    if protected.resize_handle_hovered or protected.resizing then
      prevent_wand_firing = true
    end

    protected.is_hovered = false
    if not (protected.resize_handle_hovered or protected.resizing) then
      if protected.dragging and not left_down then
        protected.dragging = false
        fire_event(self, "drag_end", self.x, self.y, drag_start_sx, drag_start_sy)
      end
  
      protected.is_hovered = is_inside_rect(sx, sy, self.x, self.y, self.width, self.height)
      if protected.is_hovered or protected.dragging then
        prevent_wand_firing = true
      end
  
      if self.draggable and protected.is_hovered and left_pressed then
        protected.dragging = true
        drag_start_sx = self.x
        drag_start_sy = self.y
        fire_event(self, "drag_start", self.x, self.y)
      end
  
      if not self.draggable and protected.is_hovered and left_pressed then
        fire_event(self, "mouse_down", sx, sy)
      end

      if protected.dragging then
        if dx ~= 0 or dy ~= 0 then
          self.x = self.x + dx
	        self.y = self.y + dy
          fire_event(self, "drag", dx, dy)
        end
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

  o.DebugDraw = function(self, gui)
    GuiOptionsAddForNextWidget(gui, GUI_OPTION.NonInteractive)
    GuiImage(gui, 10000, self.x, self.y, "mods/LocationTracker/lib/EZMouse/" .. (self.is_hovered and "green_square_10x10.png" or "red_square_10x10.png"), 1, self.width / 10, self.height / 10)

    if self.resize_handle_hovered or self.resizing then
      GuiOptionsAddForNextWidget(gui, GUI_OPTION.NonInteractive)
      GuiImage(gui, 10001, self.resize_handle.x, self.resize_handle.y, "mods/LocationTracker/lib/EZMouse/green_square_10x10.png", 1, self.resize_handle.width / 10, self.resize_handle.height / 10)
    end
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
  if not gui then GuiStartFrame(EZMouse_gui) end
  
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
    for i, draggable in ipairs(Widget.instances) do
      if draggable.enabled then
        prevent_wand_firing = draggable:Update(sx, sy, dx, dy, left_down, left_pressed) or prevent_wand_firing
      end
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
  Widget = Widget,
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
