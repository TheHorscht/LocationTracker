-- ====================
-- || EZMouse v0.2.0 ||
-- ====================

dofile_once("data/scripts/lib/utilities.lua")

local path, x, y, sx, sy, dx, dy, left_down, left_pressed, right_down, right_pressed,
  left_down_last_frame, right_down_last_frame
local drag_start_sx, drag_start_sy = 0, 0
local resize_start_sx, resize_start_sy = 0, 0
local resize_start_width, resize_start_height = 0, 0
local current_widget_id = 1
local do_draw_resize_cursor = false
local resize_handle_size = 8

local function are_floats_equal(f1, f2)
  return math.abs(f1 - f2) < 0.0001
end

local function is_inside_rect(x, y, rect_x, rect_y, width, height)
	return not ((x < rect_x) or (x > rect_x + width) or (y < rect_y) or (y > rect_y + height))
end

local dragging_widget = {
  last_frame_ran = 0,
}
-- Renders a widget at the mouse potion and returns the change in position from being dragged
local function render_dragging_widget_at_mouse_pos(current_x, current_y)
  local pos_x, pos_y = sx - 50/2, sy - 50/2
  if dragging_widget.last_frame_ran >= GameGetFrameNum() then
    -- We only need to render it once, it it has already been rendered this frame, return the last result
    return dragging_widget.result
  end
  dragging_widget.last_frame_ran = GameGetFrameNum()
  dragging_widget.result = dragging_widget.result or {}
  dragging_widget.result.dx = 0
  dragging_widget.result.dy = 0
  dragging_widget.result.was_dragged = false
  dragging_widget.result.drag_start = false
  dragging_widget.result.drag_end = false
  GuiIdPushString(EZMouse_gui, "boo")
  GuiOptionsAddForNextWidget(EZMouse_gui, GUI_OPTION.NoPositionTween)
  GuiOptionsAddForNextWidget(EZMouse_gui, GUI_OPTION.ClickCancelsDoubleClick)
  GuiOptionsAddForNextWidget(EZMouse_gui, GUI_OPTION.DrawNoHoverAnimation)
  GuiOptionsAddForNextWidget(EZMouse_gui, GUI_OPTION.NoSound)
  GuiOptionsAddForNextWidget(EZMouse_gui, GUI_OPTION.IsExtraDraggable)
  GuiZSetForNextWidget(EZMouse_gui, -999999)
  -- Draw an invisible image button that catches the native dragging
  GuiImageButton(EZMouse_gui, 3, pos_x, pos_y, "", path .. "invis.png")
  local _, _, _, _, _, _, _, dx, dy = GuiGetPreviousWidgetInfo(EZMouse_gui)
  if (not are_floats_equal(dx, pos_x) or not are_floats_equal(dy, pos_y)) and dx ~= 0 and dy ~= 0 then
    if not dragging_widget.last_x then
      dragging_widget.last_x = dx
      dragging_widget.last_y = dy
      dragging_widget.result.drag_start = true
      dragging_widget.result.start_x = current_x
      dragging_widget.result.start_y = current_y
      dragging_widget.result.drag_offset_x = sx - current_x
      dragging_widget.result.drag_offset_y = sy - current_y
      dragging_widget.result.drag_start_x = sx
      dragging_widget.result.drag_start_y = sy
    end
    dragging_widget.result.dx = dx - dragging_widget.last_x
    dragging_widget.result.dy = dy - dragging_widget.last_y
    dragging_widget.last_x = dx
    dragging_widget.last_y = dy
    if dragging_widget.result.dx ~= 0 or dragging_widget.result.dy ~= 0 then
      dragging_widget.result.was_dragged = true
    end
  elseif dragging_widget.last_x then
    dragging_widget.last_x = nil
    dragging_widget.last_y = nil
    dragging_widget.result.drag_end = true
  end
  GuiIdPop(EZMouse_gui)
  return dragging_widget.result
end

local function draw_resize_cursor(gui, handle_index, x, y)
  local sprite = handle_index % 2 == 0 and "horizontal" or "diagonal"
  local rotations = {
    { x = -(25 / 2) + 0.5, y = (25 / 2) + 0.5, rot = math.rad(90), },
    { x = -(25 / 2) + 0.5, y = (25 / 2) + 0.5, rot = math.rad(90), },
    { x = (25 / 2) + 0.5, y = (25 / 2) + 0.5, rot = 0, },
    { x = (25 / 2) + 0.5, y = (25 / 2) + 0.5, rot = 0, },
    { x = -(25 / 2) + 0.5, y = (25 / 2) + 0.5, rot = math.rad(90), },
    { x = -(25 / 2) + 0.5, y = (25 / 2) + 0.5, rot = math.rad(90), },
    { x = (25 / 2) + 0.5, y = (25 / 2) + 0.5, rot = 0, },
    { x = (25 / 2) + 0.5, y = (25 / 2) + 0.5, rot = 0, }
  }
  GuiImage(gui, 87878, sx - rotations[handle_index].x, sy - rotations[handle_index].y, path .. "cursor_resize_" .. sprite .. ".png", 1, 1, 1, rotations[handle_index].rot)
end

local function calculate_handle_props(self, resize_handle_size)
  return {
    { x = self.x - (resize_handle_size/2),              y = self.y - (resize_handle_size/2),               width = resize_handle_size,              height = resize_handle_size,               move = {-1,-1} }, -- top left
    { x = self.x + (resize_handle_size/2),              y = self.y - (resize_handle_size/2),               width = self.width - resize_handle_size, height = resize_handle_size,               move = {0,-1}  }, -- top
    { x = self.x + self.width - (resize_handle_size/2), y = self.y - (resize_handle_size/2),               width = resize_handle_size,              height = resize_handle_size,               move = {1,-1}  }, -- top right
    { x = self.x + self.width - (resize_handle_size/2), y = self.y + (resize_handle_size/2),               width = resize_handle_size,              height = self.height - resize_handle_size, move = {1,0}   }, -- right
    { x = self.x + self.width - (resize_handle_size/2), y = self.y + self.height - (resize_handle_size/2), width = resize_handle_size,              height = resize_handle_size,               move = {1,1}   }, -- bottom right
    { x = self.x + (resize_handle_size/2),              y = self.y + self.height - (resize_handle_size/2), width = self.width - resize_handle_size, height = resize_handle_size,               move = {0,1}   }, -- bottom
    { x = self.x - (resize_handle_size/2),              y = self.y + self.height - (resize_handle_size/2), width = resize_handle_size,              height = resize_handle_size,               move = {-1,1}  }, -- bottom left
    { x = self.x - (resize_handle_size/2),              y = self.y + (resize_handle_size/2),               width = resize_handle_size,              height = self.height - resize_handle_size, move = {-1,0}  }, -- left
  }
end

local function fire_event(self, name, ...)
  for i, listener in ipairs(self.event_listeners[name]) do
    listener(self, ...)
  end
end

local widget_instances = setmetatable({}, { __mode = "v" })
-- The privates should be read-only from outside
local widget_privates = setmetatable({}, { __mode = "k" })
local Widget = {}
function Widget:__index(key)
  if key == "_members" then
    error("Don't touch the internals :)", 2)
  end
  -- Private getter (read-only)
  if widget_privates[self][key] ~= nil then
    return widget_privates[self][key]
  end
  -- Static getter
  if rawget(Widget, key) ~= nil then
    return rawget(Widget, key)
  end
  -- Public getter
  return self._members[key]
end
function Widget:__newindex(key, value)
  if widget_privates[self][key] ~= nil then
    error("'"..key.."' is read-only.", 2)
  end
  self._members[key] = value
end
local function validate_constraints(c)
  c = c or {}
  if type(c) ~= "table" then
    error("'constraints' must be a table", 3)
  end
  for k, v in pairs(c) do
    if k ~= "left" and k~= "top" and k ~= "right" and k~= "bottom" then
      error(("'%s' is not a valid constraint type"):format(k), 3)
    end
    if type(v) ~= "number" then
      error(("Value for constraints.'%s' must be of type 'number'."):format(k), 3)
    end
  end
  return c
end
-- Constructor
function Widget:__call(props)
  if type(props) ~= "table" then
    error("'props' needs to be a table.", 2)
  end

  -- This could probably be done better
  local instance = setmetatable({ _members = {
    x = props.x or 0,
    y = props.y or 0,
    z = props.z or 0,
    width = props.width or 100,
    height = props.height or 100,
    min_width = props.min_width or 1,
    min_height = props.min_height or 1,
    draggable = props.draggable == nil and true or not not props.draggable,
    drag_anchor = props.drag_anchor or nil, -- either "center" or nil
    drag_granularity = props.drag_granularity or 0.1,
    resizable = not not props.resizable,
    resize_granularity = props.resize_granularity or 0.1,
    resize_symmetrical = not not props.resize_symmetrical,
    resize_uniform = not not props.resize_uniform,
    enabled = props.enabled == nil and true or not not props.enabled,
    hoverable = props.hoverable == nil and true or not not props.hoverable,
    constraints = validate_constraints(props.constraints),
    event_listeners = {
      mouse_down = {},
      drag = {},
      drag_start = {},
      drag_end = {},
      resize = {},
      resize_start = {},
      resize_end = {},
    }
  }}, Widget)
  widget_privates[instance] = {
    resizing = false,
    dragging = false,
    hovered = false,
    id = current_widget_id,
  }
  current_widget_id = current_widget_id + 1

  if instance.min_width > instance.width then
    error(string.format("min_width(%d) needs to be smaller than width(%d).", instance.min_width, instance.width), 2)
  end
  if instance.min_height > instance.height then
    error(string.format("min_height(%d) needs to be smaller than height(%d).", instance.min_height, instance.height), 2)
  end

  table.insert(widget_instances, instance)
  table.sort(widget_instances, function(a, b)
    return a.z < b.z
  end)

  return instance
end

function Widget:AddEventListener(event_name, listener)
  if not self.event_listeners[event_name] then
    error("No event by the name of '"..event_name.."'", 2)
  end
  table.insert(self.event_listeners[event_name], listener)
  return listener
end

function Widget:RemoveEventListener(event_name, listener)
  if not self.event_listeners[event_name] then
    error("No event by the name of '"..event_name.."'", 2)
  end
  for i, v in ipairs(self.event_listeners[event_name]) do
    if v == listener then
      table.remove(self.event_listeners[event_name], i)
      return
    end
  end
  error("Cannot remove a listener that was never registered.", 2)
end

function Widget:DebugDraw(gui, sprite)
  GuiIdPushString(EZMouse_gui, "EZMouse_debug_draw_" .. tostring(widget_privates[self].id))
  GuiOptionsAddForNextWidget(gui, GUI_OPTION.NonInteractive)
  GuiZSetForNextWidget(gui, self.z)
  GuiImage(gui, 2, self.x, self.y, path .. (widget_privates[self].hovered and "green_square_10x10.png" or (sprite or "red") .. "_square_10x10.png"), 1, self.width / 10, self.height / 10)
  if widget_privates[self].resize_handle_hovered or widget_privates[self].resize_handle_index then
    GuiOptionsAddForNextWidget(gui, GUI_OPTION.NonInteractive)
    GuiZSetForNextWidget(gui, self.z - 0.5)
    GuiImage(gui, 3, widget_privates[self].resize_handle.x, widget_privates[self].resize_handle.y, path .. "green_square_10x10.png", 1, widget_privates[self].resize_handle.width / 10, widget_privates[self].resize_handle.height / 10)
  end
  GuiIdPop(EZMouse_gui)
end

setmetatable(Widget, Widget)

-- These are for global events
local event_listeners = {
  mouse_down = {},
  mouse_up = {},
  mouse_move = {},
}

local function fire_global_event(name, ...)
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

local function update(gui)
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
    -- If a widget is being hovered, saves a reference to the instance, otherwise stays nil
    local hovered_draggable
    -- If one of a widget's resize handle is being hovered, saves a reference to the widget instance and the hovered resize handle, otherwise stays nil
    local resize_handle_hovered_draggable
    if not dragging_draggable and not resizing_draggable then
      -- Reset hover status of all widgets at the beginning of every loop
      for i, draggable in ipairs(widget_instances) do
        widget_privates[draggable].hovered = false
        widget_privates[draggable].resize_handle_hovered = nil
      end
      -- Check current hover status of all widgets, main area and resize handles
      for i, draggable in ipairs(widget_instances) do
        if draggable.enabled then
          local resize_handle_size_ = draggable.resizable and resize_handle_size or 0
          widget_privates[draggable].hovered = is_inside_rect(sx, sy, draggable.x + resize_handle_size_/2, draggable.y + resize_handle_size_/2, draggable.width - resize_handle_size_, draggable.height - resize_handle_size_)
          widget_privates[draggable].hovered = draggable.hoverable and widget_privates[draggable].hovered
          if widget_privates[draggable].hovered then
            hovered_draggable = draggable
            -- Only one should be able to be hovered at a time, so no need to continue
            break
          else
            local resize_handles = calculate_handle_props(draggable, resize_handle_size_)
            for i, handle in ipairs(resize_handles) do
              if is_inside_rect(sx, sy, handle.x, handle.y, handle.width, handle.height) then
                widget_privates[draggable].resize_handle_hovered = i
                widget_privates[draggable].resize_handle = resize_handles[i]
                resize_handle_hovered_draggable = { draggable = draggable, hovered_handle = resize_handles[i], handle_index = i }
                break
              end
            end
            if resize_handle_hovered_draggable then
              break
            end
          end
        end
      end
    end

    if hovered_draggable and hovered_draggable.draggable then
      local draggable = hovered_draggable
      local result = render_dragging_widget_at_mouse_pos(draggable.x, draggable.y)
      if result.drag_start then
        widget_privates[draggable].dragging = true
        dragging_draggable = draggable
        fire_event(draggable, "drag_start")
        drag_start_sx = sx
        drag_start_sy = sy
      end
    end
    if resize_handle_hovered_draggable then
      local draggable = resize_handle_hovered_draggable.draggable
      local result = render_dragging_widget_at_mouse_pos(draggable.x, draggable.y)
      if do_draw_resize_cursor then
        draw_resize_cursor(gui, resize_handle_hovered_draggable.handle_index, sx, sy)
      end
      if result.drag_start then
        resizing_draggable = draggable
        widget_privates[draggable].resize_handle_index = resize_handle_hovered_draggable.handle_index
        widget_privates[draggable].resize_handle = resize_handle_hovered_draggable.hovered_handle
        fire_event(draggable, "resize_start", { handle_index = resize_handle_hovered_draggable.handle_index })
        resize_start_sx = resize_handle_hovered_draggable.hovered_handle.x + (resize_handle_size / 2)
        resize_start_sy = resize_handle_hovered_draggable.hovered_handle.y + (resize_handle_size / 2)
        resize_start_x = draggable.x
        resize_start_y = draggable.y
        resize_start_width = draggable.width
        resize_start_height = draggable.height
        aspect_ratio = draggable.width / draggable.height
      end
    end

    if dragging_draggable then
      -- Here happens the dragging
      local draggable = dragging_draggable
      local result = render_dragging_widget_at_mouse_pos(draggable.x, draggable.y)
      if result.was_dragged then
        fire_event(draggable, "drag", { dx = result.dx, dy = result.dy })
        local drag_offset_x = result.drag_offset_x
        local drag_offset_y = result.drag_offset_y
        if draggable.drag_anchor == "center" then
          drag_offset_x = draggable.width / 2
          drag_offset_y = draggable.height / 2
        end
        draggable.x = math.min((draggable.constraints.right or 99999) - draggable.width, math.max(draggable.constraints.left or 0, sx - drag_offset_x))
        draggable.y = math.min((draggable.constraints.bottom or 99999) - draggable.height, math.max(draggable.constraints.top or 0, sy - drag_offset_y))
      end
      if result.drag_end then
        widget_privates[draggable].dragging = false
        dragging_draggable = nil
        fire_event(draggable, "drag_end", { start_x = result.start_x, start_y = result.start_y })
      end
    elseif resizing_draggable then
      -- Here happens the resizing
      local draggable = resizing_draggable
      local result = render_dragging_widget_at_mouse_pos(draggable.x, draggable.y)
      if do_draw_resize_cursor then
        draw_resize_cursor(gui, widget_privates[draggable].resize_handle_index, sx, sy)
      end
      if result.was_dragged then
        local dx = sx - resize_start_sx
        local dy = sy - resize_start_sy
        local change_left = dx * -math.min(widget_privates[draggable].resize_handle.move[1], 0)
        local change_right = dx * math.max(widget_privates[draggable].resize_handle.move[1], 0)
        local change_top = dy * -math.min(widget_privates[draggable].resize_handle.move[2], 0)
        local change_bottom = dy * math.max(widget_privates[draggable].resize_handle.move[2], 0)
        if draggable.resize_symmetrical then
          local old_right = change_right
          change_right = change_right - change_left
          change_left = change_left - old_right
          local old_bottom = change_bottom
          change_bottom = change_bottom - change_top
          change_top = change_top - old_bottom
        end

        -- if draggable.resize_uniform then
        --   local scale_x = (resize_start_x + resize_start_width * math.max(0, -widget_privates[draggable].resize_handle.move[1]) - sx) * -widget_privates[draggable].resize_handle.move[1] / resize_start_width
        --   local scale_y = (resize_start_y + resize_start_height * math.max(0, -widget_privates[draggable].resize_handle.move[2]) - sy) * -widget_privates[draggable].resize_handle.move[2] / resize_start_height
        --   local scale = math.max(scale_x, scale_y)
        --   -- local scale_granularity = draggable.resize_granularity
        --   -- scale = math.floor(scale / scale_granularity) * scale_granularity
        --   local scale_min_x = draggable.min_width / resize_start_width
        --   local scale_min_y = draggable.min_height / resize_start_height
        --   local scale_min = math.max(scale_min_x, scale_min_y)
        --   scale = math.max(scale_min, scale)
        --   new_width = resize_start_width * scale
        --   new_height = resize_start_height * scale
        -- end

        local change_left_max = resize_start_width - draggable.min_width
        change_left = math.max(change_left, (draggable.constraints.left or -999999) - resize_start_x)
        change_left = math.min(change_left, change_left_max)
        -- change_right = math.min(change_right, (draggable.constraints.right or 999999) - resize_start_x - resize_start_width)
        local change_top_max = resize_start_height - draggable.min_height
        change_top = math.max(change_top, (draggable.constraints.top or -999999) - resize_start_y)
        change_top = math.min(change_top, change_top_max)
        -- change_bottom = math.min(change_bottom, (draggable.constraints.bottom or 999999) - resize_start_y - resize_start_height)
        if draggable.resize_symmetrical then
          local change_left_max = (resize_start_width - draggable.min_width) / 2
          local change_right_min = -(resize_start_width - draggable.min_width) / 2
          change_left = math.min(change_left, change_left_max)
          change_right = math.max(change_right, change_right_min)
          if math.abs(change_left) > math.abs(change_right) then
            change_left = change_right * -1
          else
            change_right = change_left * -1
          end

          local change_top_max = (resize_start_height - draggable.min_height) / 2
          local change_bottom_min = -(resize_start_height - draggable.min_height) / 2
          change_top = math.min(change_top, change_top_max)
          change_bottom = math.max(change_bottom, change_bottom_min)
          if math.abs(change_top) > math.abs(change_bottom) then
            change_top = change_bottom * -1
          else
            change_bottom = change_top * -1
          end
        end

        if draggable.resize_uniform then
          local scale_x = (resize_start_width + change_right) / resize_start_width
          local scale_y = (resize_start_height + change_bottom) / resize_start_height
          -- local scale = math.max(scale_x, scale_y)
          local aspect_ratio = resize_start_width / resize_start_height
          print(("scale_x(%s)"):format(scale_x - 1 * resize_start_width))
          print(("scale_y(%s)"):format((scale_y - 1) * aspect_ratio * resize_start_height))
          -- print(("scale_x(%s)"):format(math.abs(scale_x - 1) * resize_start_width))
          -- print(("scale_y(%s)"):format(math.abs((scale_y - 1) * aspect_ratio) * resize_start_height))
          local scale = 1
            -- if math.abs(resize_start_width - new_width_) > math.abs(resize_start_height - new_height_) then
          -- if math.max(0, sx - resize_start_sx) > math.max(0, sy - resize_start_sy) then
          -- if math.max(0, math.abs(resize_start_sx - sx)) > math.max(0, math.abs(resize_start_sy - sy)) then
          if (scale_x - 1) * resize_start_width > (scale_y - 1) * resize_start_width then
          -- if (scale_x - 1) * resize_start_width > (scale_y - 1) * resize_start_width then
          -- if math.abs(scale_x - 1) * resize_start_width > math.abs((scale_y - 1) * aspect_ratio) * resize_start_height then
            scale = scale_x
          else
            scale = scale_y
          end

          local scale_min_x = draggable.min_width / resize_start_width
          local scale_min_y = draggable.min_height / resize_start_height
          local scale_min = math.max(scale_min_x, scale_min_y)

          local scale_max_x = ((draggable.constraints.right or 999999) - resize_start_x) / resize_start_width
          local scale_max_y = ((draggable.constraints.bottom or 999999) - resize_start_y) / resize_start_height
          local scale_max = math.min(scale_max_x, scale_max_y)

          -- scale = math.min(scale_max, scale)
          -- scale = math.max(scale_min, scale)
          change_right = resize_start_width * scale - resize_start_width--change_right * scale
          change_bottom = resize_start_height * scale - resize_start_height-- change_bottom * scale
          -- new_width = resize_start_width * scale
          -- new_height = resize_start_height * scale
        end

        local new_width = math.max(draggable.min_width, resize_start_width + change_right - change_left)
        local new_height = math.max(draggable.min_height, resize_start_height + change_bottom - change_top)

        draggable.x = resize_start_x + change_left
        draggable.y = resize_start_y + change_top
        draggable.width = new_width
        draggable.height = new_height

        -- Recalculate the values
        local resize_handles = calculate_handle_props(draggable, resize_handle_size)
        widget_privates[draggable].resize_handle = resize_handles[widget_privates[draggable].resize_handle_index]
        local has_moved = false --math.abs(width_change) > 0.5 or math.abs(height_change) > 0.5
        if has_moved then
          fire_event(draggable, "resize", { handle_index = widget_privates[draggable].resize_handle_index })
        end
      end
      if result.drag_end then
        fire_event(draggable, "resize_end", { handle_index = widget_privates[draggable].resize_handle_index })
        widget_privates[draggable].resize_handle_index = nil
        resizing_draggable = nil
      end
    end

    if left_pressed then fire_global_event("mouse_down", { button = "left", screen_x = sx, screen_y = sy, world_x = x, world_y = y }) end
    if right_pressed then fire_global_event("mouse_down", { button = "right", screen_x = sx, screen_y = sy, world_x = x, world_y = y }) end
    if not left_down and left_down_last_frame then fire_global_event("mouse_up", { button = "left", screen_x = sx, screen_y = sy, world_x = x, world_y = y }) end
    if not right_down and right_down_last_frame then fire_global_event("mouse_up", { button = "right", screen_x = sx, screen_y = sy, world_x = x, world_y = y }) end

    local movement_tolerance = 0.5
    local vx = sx - mouse_loop_last_sx
    local vy = sy - mouse_loop_last_sy
    if math.abs(vx) >= movement_tolerance or math.abs(vy) >= movement_tolerance then
      fire_global_event("mouse_move", { screen_x = sx, screen_y = sy, world_x = x, world_y = y, dx = vx, dy = vy })
    end

    mouse_loop_last_sx = sx
    mouse_loop_last_sy = sy
    left_down_last_frame = left_down
    right_down_last_frame = right_down
	end
end

return function(lib_path)
  path = lib_path
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
end

