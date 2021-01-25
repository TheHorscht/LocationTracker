dofile_once("mods/LocationTracker/files/encode_coords.lua")
dofile_once("data/scripts/lib/utilities.lua")
local permutation_data = dofile_once("mods/LocationTracker/files/permutation_data.lua")
local nxml = dofile_once("mods/LocationTracker/lib/nxml.lua")

local EZMouse = dofile_once("mods/LocationTracker/lib/EZMouse/EZMouse.lua")
ModLuaFileAppend("data/scripts/gun/gun.lua", "mods/LocationTracker/lib/EZMouse/gun_append.lua")

function split_string(inputstr, sep)
  sep = sep or "%s"
  local t= {}
  for str in string.gmatch(inputstr, "([^"..sep.."]+)") do
    table.insert(t, str)
  end
  return t
end

local map_width = 70
local map_height = 48
-- local minimap_pos_x = 1009-- + 0.5
-- local minimap_pos_y = 65-- + 0.5
local minimap_pos_x = ModSettingGet("LocationTracker_minimap_pos_x") or 490-- + 0.5
local minimap_pos_y = ModSettingGet("LocationTracker_minimap_pos_y") or 65-- + 0.5
local biome_map_offset_y = 14
local seen_areas
local last_chunk_x, last_chunk_y = 0, 0
local map
local zoom = 1.5
local sprite_scale = 3
local color_data = {}
local size = {
	x = ModSettingGet("LocationTracker_minimap_size_x") or 11,
	y = ModSettingGet("LocationTracker_minimap_size_y") or 11
}
local block_size = { x = 3, y = 3 }
local total_size
local function calculate_total_size()
	total_size = { x = size.x * block_size.x * zoom, y = size.y * block_size.y * zoom }
end
calculate_total_size()
local screen_width, screen_height = nil, nil

local locked = true
local visible = true
local fog_of_war = false
local offx, offy = 0, 0

local biome_map_script_paths = {}
for i, mod_id in ipairs(ModGetActiveModIDs()) do
	local init_content = ModTextFileGetContent("mods/" .. mod_id .. "/init.lua")
	if init_content then
		-- Get the magic numbers file path if present
		local magic_numbers_file_path
		local lines = init_content:gmatch("([^\r\n]+)")
		for line in lines do
			-- Make sure to only get it if it's not commented out
			local match_start, match_end, capture = line:find("ModMagicNumbersFileAdd%s*%(%s*[\"\']%s*([^%)]*)%s*[\"\']%s*%)")
			if match_start then
				if not (line:sub(1, match_start-1):find("%-%-")) then
					magic_numbers_file_path = capture
				end
			end
		end
		-- Try to get the BIOME_MAP path
		local biome_map_script_path
		if magic_numbers_file_path then
			local magic_numbers_content = ModTextFileGetContent(magic_numbers_file_path)
			if magic_numbers_content then
				local xml = nxml.parse(magic_numbers_content)
				biome_map_script_path = xml.attr.BIOME_MAP
			end
		end

		if biome_map_script_path then
			table.insert(biome_map_script_paths, biome_map_script_path)
		end
	end
end

if #biome_map_script_paths == 0 then
	local temp_magic_numbers_filepath = "mods/LocationTracker/_virtual/magic_numbers.xml"
	ModTextFileSetContent(temp_magic_numbers_filepath, [[<MagicNumbers BIOME_MAP="mods/LocationTracker/files/map_script.lua" /> ]])
	ModMagicNumbersFileAdd(temp_magic_numbers_filepath)
end

-- Append to the already registered map script as late as possible when all other mods have added their appends already
-- this append needs to be the absolute last.
function OnMagicNumbersAndWorldSeedInitialized()
	ModLuaFileAppend("data/biome_impl/biome_map_newgame_plus.lua", "mods/LocationTracker/files/biome_map_append.lua")
	for i, script_path in ipairs(biome_map_script_paths) do
		ModLuaFileAppend(script_path, "mods/LocationTracker/files/biome_map_append.lua")
	end
end

local biomes_all_content = ModTextFileGetContent("data/biome/_biomes_all.xml")
if biomes_all_content then
	local xml = nxml.parse(biomes_all_content)
	biome_map_offset_y = xml.attr.biome_offset_y
end

local function get_chunk_coords(x, y)
	return math.floor(x / 512), math.floor(y / 512)
end

-- Given x, y world position and a chunk offset, returns the wrapped biome map chunk
-- for instance at a biome map width of 10 at 512 pixels width per chunk, the entire map would be 5120 pixels wide,
-- if x == 4096+1, biome_x would be 8, with offset_x == 3, it would wrap around to 1
local function get_biome_map_coords(map_width, map_height, x, y, offset_x, offset_y)
	offset_x = offset_x or 0
	offset_y = offset_y or 0
	local biome_x, biome_y = math.floor((x / 512) + math.floor(map_width / 2)), math.floor((y / 512) + biome_map_offset_y)
	biome_x = biome_x + offset_x
	biome_y = biome_y + offset_y
	biome_x = biome_x % map_width
	if biome_x < 0 then
		biome_x = biome_x + map_width
	end
	if biome_y < 0 then
		biome_y = 0
	end
	if biome_y > map_height - 1 then
		biome_y = map_height - 1
	end
	return biome_x, biome_y
end

local function get_position()
	local x, y
	local players = EntityGetWithTag("player_unit")
	if #players > 0 then
		x, y = EntityGetTransform(players[1])
	else
		x, y = GameGetCameraPos()
	end
	return x, y
end

-- local draggables = {}
-- local function register_draggable(x, y, width, height, callbacks)
-- 	local draggable = { x = x, y = y, width = width, height = height,	_dragging = false,
-- 		callbacks = callbacks or {}
-- 	}
-- 	table.insert(draggables, draggable)
-- 	return draggable
-- end

-- local function mouse_loop(gui)
-- 	if not controls_component then
-- 		local entity_name = "LocationTracker_controls_entity"
-- 		local controls_entity = EntityGetWithName(entity_name)
-- 		if controls_entity == 0 then
-- 			controls_entity = EntityCreateNew(entity_name)
-- 		end
-- 		controls_component = EntityAddComponent2(controls_entity, "ControlsComponent")
-- 	end
	
-- 	local x, y, dx, dy, left_down
-- 	mouse_loop_last_x = mouse_loop_last_x or 0
-- 	mouse_loop_last_y = mouse_loop_last_y or 0
-- 	-- Get whatever state we can directly from the component
-- 	if controls_component then
-- 		x, y = ComponentGetValue2(controls_component, "mMousePosition")
-- 		left_down = ComponentGetValue2(controls_component, "mButtonDownFire")
-- 		left_pressed = ComponentGetValue2(controls_component, "mButtonFrameFire") == GameGetFrameNum()
-- 		-- right_down = ComponentGetValue2(controls_component, "mButtonDownRightClick")
-- 	end
-- 	local virt_x = MagicNumbersGetValue("VIRTUAL_RESOLUTION_X")
-- 	local virt_y = MagicNumbersGetValue("VIRTUAL_RESOLUTION_Y")
-- 	local screen_width, screen_height = GuiGetScreenDimensions(gui)
-- 	local scale_x = virt_x / screen_width
-- 	local scale_y = virt_y / screen_height
-- 	local cx, cy = GameGetCameraPos()
-- 	local sx, sy = (x - cx) / scale_x + screen_width / 2 + 1.5, (y - cy) / scale_y + screen_height / 2
-- 	-- Calculate mMouseDelta ourselves because the native one isn't consistent across all window sizes
-- 	dx, dy = math.floor(sx + 0.5) - math.floor(mouse_loop_last_x + 0.5), math.floor(sy + 0.5) - math.floor(mouse_loop_last_y + 0.5)
-- 	mouse_loop_last_x = sx
-- 	mouse_loop_last_y = sy
-- 	local gui_y = 250
-- 	local function new_line() gui_y = gui_y + 10 end
-- 	GuiText(gui, 40, gui_y, "msx: " .. tostring(math.floor(sx)))
-- 	GuiText(gui, 100, gui_y, "msy: " .. tostring(math.floor(sy)))
-- 	new_line()
-- 	GuiText(gui, 40, gui_y, "box_x: " .. tostring(box_x))
-- 	GuiText(gui, 100, gui_y, "box_y: " .. tostring(box_y))
-- 	new_line()
-- 	GuiText(gui, 40, gui_y, "dx: " .. tostring(dx))
-- 	GuiText(gui, 100, gui_y, "dy: " .. tostring(dy))
-- 	new_line()
-- 	GuiText(gui, 40, gui_y, "virt_x: " .. tostring(virt_x))
-- 	GuiText(gui, 130, gui_y, "virt_y: " .. tostring(virt_y))
-- 	new_line()
-- 	GuiText(gui, 40, gui_y, "screen_width: " .. tostring(screen_width))
-- 	GuiText(gui, 130, gui_y, "screen_height: " .. tostring(screen_height))
	
-- 	local prevent_wand_firing = false
-- 	for i, draggable in ipairs(draggables) do
-- 		if draggable._dragging and not left_down then
-- 			draggable._dragging = false
-- 		end
-- 		draggable.is_hovered = is_inside_rect(sx, sy, draggable.x, draggable.y, draggable.width, draggable.height)
-- 		local players = EntityGetWithTag("player_unit")

-- 		if draggable.is_hovered or draggable._dragging then
-- 			prevent_wand_firing = true
-- 		end

-- 		if draggable.is_hovered and left_pressed then
-- 			draggable._dragging = true
-- 		end

-- 		if draggable._dragging and draggable.callbacks.on_drag then
-- 			if dx ~= 0 or dy ~= 0 then
-- 				draggable.callbacks.on_drag(draggable, dx, dy)
-- 			end
-- 			box_x = box_x + dx
-- 			box_y = box_y + dy
-- 		end
-- 	end
	
-- 	GlobalsSetValue("LocationTracker_prevent_wand_firing", prevent_wand_firing and "1" or "0")
-- end

-- local box = EZMouse.Draggable.new(0, 0, 20, 20)
-- box:AddEventListener("drag", function(self, dx, dy)
-- 	self.x = self.x + dx
-- 	self.y = self.y + dy
-- end)

-- local resize_handle
local box2 = EZMouse.Draggable.new({
	x = 200,
	y = 100,
	width = 100,
	height = 60,
	resizable = true,
	resize_granularity = 10,
})
box2:AddEventListener("drag", function(self, dx, dy)
	-- self.x = self.x + dx
	-- self.y = self.y + dy
	-- resize_handle.x = resize_handle.x + dx
	-- resize_handle.y = resize_handle.y + dy
end)
box2:AddEventListener("drag_start", function(self, x, y)
	-- GamePrint(string.format("Starting drag at %d, %d", x, y))
end)
box2:AddEventListener("drag_end", function(self, x, y)
	-- GamePrint(string.format("Ending drag at %d, %d", x, y))
end)

-- resize_handle = EZMouse.Draggable.new(50, 150, 5, 5)
-- resize_handle:AddEventListener("drag", function(self, dx, dy)
-- 	self.x = self.x + dx
-- 	self.y = self.y + dy
-- 	box2.width = box2.width + dx
-- 	box2.height = box2.height + dy
-- end)

EZMouse.AddEventListener("mouse_down", function(e)
	-- GamePrint(tostring(e.button) .." down at " .. tostring(e.x) .. ", " .. tostring(e.y))
	-- GameCreateParticle("poo", e.world_x, e.world_y, 1, -50, 0, true)
end)

EZMouse.AddEventListener("mouse_up", function(e)
	-- GamePrint(tostring(e.button) .." up at " .. tostring(e.x) .. ", " .. tostring(e.y))
end)

EZMouse.AddEventListener("mouse_move", function(e)
	if EZMouse.left_down then
		-- GamePrint("Mouse move to " .. tostring(e.x) .. ", " .. tostring(e.y))
		-- GameCreateParticle("poo", e.world_x, e.world_y, 10, e.vx * 10, e.vy * 10, true)
	end
end)

function OnWorldPreUpdate()
	-- dofile("mods/LocationTracker/files/gui.lua")
	gui = gui or GuiCreate()
	GuiStartFrame(gui)
	GuiOptionsAdd(gui, GUI_OPTION.NoPositionTween)

	EZMouse.update()

	-- GuiOptionsAddForNextWidget(gui, GUI_OPTION.NonInteractive)
	-- GuiImage(gui, 9999, box.x, box.y, "mods/LocationTracker/" .. (box.is_hovered and "green_square_10x10.png" or "red_square_10x10.png"), 1, 2, 2)
	GuiOptionsAddForNextWidget(gui, GUI_OPTION.NonInteractive)
	GuiImage(gui, 10000, math.floor(box2.x + 0.5), math.floor(box2.y + 0.5), "mods/LocationTracker/" .. (box2.is_hovered and "green_square_10x10.png" or "red_square_10x10.png"), 1, box2.width / 10, box2.height / 10)

	if box2.resize_handle_hovered or box2.resizing then
		GuiOptionsAddForNextWidget(gui, GUI_OPTION.NonInteractive)
		GuiImage(gui, 10001, box2.resize_handle.x, box2.resize_handle.y, "mods/LocationTracker/green_square_10x10.png", 1, box2.resize_handle.width / 10, box2.resize_handle.height / 10)
	end

	if screen_width == nil then
		screen_width, screen_height = GuiGetScreenDimensions(gui)
	end
	if not seen_areas then
		-- Initializing
		seen_areas = {}
		local stored = GlobalsGetValue("LocationTracker_seen_areas", "")
		if stored ~= "" then
			seen_areas = {}
			local areas = split_string(stored, ",")
			for i, area in ipairs(areas) do
				local xyv = split_string(area, "_")
				seen_areas[encode_coords(xyv[1], xyv[2])] = xyv[3]
			end
		end
		local data = loadfile("mods/LocationTracker/_virtual/map.lua")()
		map_width = data.width
		map_height = data.height
		map = data.map
	end
	if GameHasFlagRun("locationtracker_reload_map") then
		GameRemoveFlagRun("locationtracker_reload_map")
		seen_areas = {}
		GlobalsSetValue("LocationTracker_seen_areas", "")
		local data = loadfile("mods/LocationTracker/_virtual/map.lua")()
		map_width = data.width
		map_height = data.height
		map = data.map
	end

	if GameGetFrameNum() < 20 then return end

	local cx, cy = get_position()
	local chunk_x, chunk_y = get_chunk_coords(cx, cy)
	local sub_x = cx - chunk_x * 512 
	local sub_y = cy - chunk_y * 512
	sub_x = math.floor(sub_x / (512 / block_size.x))
	sub_y = math.floor(sub_y / (512 / block_size.y))
	local current_sub_value = bit.lshift(1, sub_x + sub_y * block_size.x)
	local chunk_coords = encode_coords(chunk_x, chunk_y)
	local current_chunk_bitmask = seen_areas[chunk_coords] or 0
	local new_value = bit.bor(current_chunk_bitmask, current_sub_value)
	if current_chunk_bitmask ~= new_value then
		-- color_data = {}
		seen_areas[chunk_coords] = new_value
		local out = ""
		for k, v in pairs(seen_areas) do
			out = out .. k .. "_" .. v -- TODO: Is this possible to do without concatenation?
			if next(seen_areas,k) then
				out = out .. ","
			end
		end
		GlobalsSetValue("LocationTracker_seen_areas", out)
	end

	if map then
		if visible or not locked then
			-- Draw the map
			for y=0, size.y-1 do
				for x=0, size.x-1 do
					local idx = x+y*size.x
					color_data[idx] = get_color_data(cx, cy, x-math.floor(size.x/2), y-math.floor(size.y/2))
					GuiColorSetForNextWidget(gui, color_data[idx].color.r, color_data[idx].color.g, color_data[idx].color.b, 1)
					-- GuiImage(gui, 10010 + idx+1, math.floor(offx) + math.floor(scr_half_w - tot_size_half_x) + x*zoom_block_x, math.floor(offy) + math.floor(scr_half_h - tot_size_half_y) + y*zoom_block_y, "mods/LocationTracker/a.png", 1, zoom, 0)
					-- GuiImage( gui, id:int, x:number, y:number, sprite_filename:string, alpha:number, scale:number, rotation:number, scale_y:number = 0.0, rect_animation_playback_type:int = GUI_RECT_ANIMATION_PLAYBACK.PlayToEndAndHide, rect_animation_name:string = "" ) ['scale' will be used for 'scale_y' if 'scale_y' equals 0.]
					GuiImage(
						gui,
						10010 + idx, -- id:int
						offx + minimap_pos_x + (x + color_data[idx].offset.x) * zoom*block_size.x, -- x:number
						offy + minimap_pos_y + (y + color_data[idx].offset.y) * zoom*block_size.y, -- y:number
						-- math.floor(screen_width/2 - total_size.x/2) + (x+color_data[idx].offset.x)*zoom*block_size.x, -- x:number
						-- math.floor(screen_height/2 - total_size.y/2) + (y+color_data[idx].offset.y)*zoom*block_size.y, -- y:number
						"mods/LocationTracker/files/color_sprites.xml", -- sprite_filename:string
						1, -- alpha:number
						color_data[idx].scale_x * zoom / sprite_scale, -- scale:number
						zoom / sprite_scale, --color_data[idx].rot -- rotation:number
						color_data[idx].rot, -- scale_y:number
						GUI_RECT_ANIMATION_PLAYBACK.PlayToEndAndPause, -- rect_animation_playback_type:int = GUI_RECT_ANIMATION_PLAYBACK.PlayToEndAndHide
						color_data[idx].anim -- rect_animation_name:string = ""
					)
				end
			end
			-- Border
			GuiZSetForNextWidget(gui, -999)
			GuiImageNinePiece(gui, 40000, offx + minimap_pos_x, offy + minimap_pos_y, math.floor(total_size.x), math.floor(total_size.y), 3, "mods/LocationTracker/files/border.png")
			-- Draw the dot in the center
			local dot_scale = 0.5
			GuiZSetForNextWidget(gui, -999)
			GuiImage(
				gui,
				25000, -- id:int
				offx + minimap_pos_x + math.floor(total_size.x/2) + (sub_x-1)*zoom, -- x:number
				offy + minimap_pos_y + math.floor(total_size.y/2) + (sub_y-1)*zoom, -- y:number
				"mods/LocationTracker/files/you_are_here.png", -- sprite_filename:string
				1, -- alpha:number
				dot_scale -- scale:number
			)
		end
		-- GuiSlider( gui, id:int, x:number, y:number, text:string, value:number, value_min:number, value_max:number, value_default:number, value_display_multiplier:number, value_formatting:string, width:number ) -> new_value:number [This is not intended to be outside mod settings menu, and might bug elsewhere.]
		if not locked then
			GuiOptionsAddForNextWidget(gui, GUI_OPTION.IsDraggable)
			local tw, th = GuiGetTextDimensions(gui, "DRAG")
			local start_x = offx + minimap_pos_x + total_size.x/2 - math.floor(tw/2)
			local start_y = offy + minimap_pos_y - th - 2
			GuiButton(gui, 4999, start_x, start_y, "DRAG")
			local clicked, right_clicked, hovered, xx, yy, width, height, draw_x, draw_y = GuiGetPreviousWidgetInfo(gui)
			if draw_x ~= start_x or draw_y ~= start_y then
				offx = math.floor(offx + (draw_x - start_x))
				offy = math.floor(offy + (draw_y - start_y))
				offx = math.max(5 - minimap_pos_x, math.min(screen_width - (total_size.x + 5) - minimap_pos_x, offx))
				offy = math.max(5 - minimap_pos_y, math.min(screen_height - (total_size.y + 5) - minimap_pos_y, offy))
			end
	
			local start_x = offx + minimap_pos_x + total_size.x
			local start_y = offy + minimap_pos_y + total_size.y
			GuiOptionsAddForNextWidget(gui, GUI_OPTION.IsDraggable)
			GuiButton(gui, 5000, start_x, start_y, "  ")
			local clicked, right_clicked, hovered, xx, yy, width, height, draw_x, draw_y = GuiGetPreviousWidgetInfo(gui)
			GuiImage(gui, 5001, xx, yy, "mods/LocationTracker/files/resize_handle.png", 1, 1, 0)
			local dx = math.floor((xx - start_x) / zoom / 5)
			local dy = math.floor((yy - start_y) / zoom / 5)
			local old_x = size.x
			local old_y = size.y
			size.x = math.max(3, size.x + dx)
			size.y = math.max(3, size.y + dy)
			if size.x ~= old_x or size.y ~= old_y then
				calculate_total_size()
			end
		end
		-- Lock button
		if GuiImageButton(gui, 30001, math.floor(offx + minimap_pos_x + total_size.x + 5), math.floor(offy + minimap_pos_y - 1), "", "mods/LocationTracker/files/lock_"..(locked and "closed" or "open") ..".png") then
			locked = not locked
			-- Save settings when locking
			if locked then
				minimap_pos_x = minimap_pos_x + offx
				minimap_pos_y = minimap_pos_y + offy
				offx, offy = 0, 0
				ModSettingSet("LocationTracker_minimap_pos_x", minimap_pos_x)
				ModSettingSet("LocationTracker_minimap_pos_y", minimap_pos_y)
				ModSettingSet("LocationTracker_minimap_size_x", size.x)
				ModSettingSet("LocationTracker_minimap_size_y", size.y)
			end
		end
		if locked then
			GuiTooltip(gui, "Unlock", "Unlock the minimap so you can resize it at the corners and move it around by dragging it.")
		else
			GuiTooltip(gui, "Lock", "Lock the minimap in place, prevent movement and resizing.")
		end
		if locked then
			-- Show/hide button
			if GuiImageButton(gui, 30002, math.floor(offx + minimap_pos_x + total_size.x + 5), math.floor(offy + minimap_pos_y + 11), "", "mods/LocationTracker/files/eye_"..(visible and "open" or "closed") ..".png") then
				visible = not visible
			end
			if visible then
				GuiTooltip(gui, "Hide minimap", "")
			else
				GuiTooltip(gui, "Show minimap", "")
			end
			-- Fog of war button
			if GuiImageButton(gui, 30003, math.floor(offx + minimap_pos_x + total_size.x + 5), math.floor(offy + minimap_pos_y + 22), "", "mods/LocationTracker/files/fog_of_war_"..(fog_of_war and "on" or "off") ..".png") then
				fog_of_war = not fog_of_war
			end
			if fog_of_war then
				GuiTooltip(gui, "Hide fog of war", "")
			else
				GuiTooltip(gui, "Show fog of war", "")
			end
		end
	end
	if not locked then
		GuiBeginAutoBox(gui)
		-- GuiEndAutoBoxNinePiece(gui, margin:number = 5, size_min_x:number = 0, size_min_y:number = 0, mirrorize_over_x_axis:bool = false, x_axis:number = 0, sprite_filename:string = "data/ui_gfx/decorations/9piece0_gray.png", sprite_highlight_filename:string = "data/ui_gfx/decorations/9piece0_gray.png" )
		local old_zoom = zoom
		zoom = GuiSlider(gui, 666, 50, 200, "Zoom", zoom, 0.5, 5, 1, 1, " $0", 300)
		-- zoom = math.floor(GuiSlider(gui, 666, 50, 200, "Zoom", zoom, 0.5, 5, 1, 1, " ", 300) * 2) / 2
		if zoom ~= old_zoom then
			calculate_total_size()
		end
		GuiEndAutoBoxNinePiece(gui)
	end
end

function OnModPostInit()
	local content = ModTextFileGetContent("mods/LocationTracker/_virtual/mod_colors.lua")
	if content then
		mod_colors = dofile("mods/LocationTracker/_virtual/mod_colors.lua")
	end
end

function get_color_data(x, y, offset_x, offset_y)
	-- print("getting color data")
	local biome_x, biome_y = get_biome_map_coords(map_width, map_height, x, y, offset_x, offset_y)
	local chunk_x, chunk_y = get_chunk_coords(x + 512 * offset_x, y + 512 * offset_y)
	local chunk = map[encode_coords(biome_x, biome_y)]
	local chunk_bitmask = seen_areas[encode_coords(chunk_x, chunk_y)] or 0
	local rot, scale_x, scale_y = 0, 1, 1
	if not fog_of_war then
		chunk_bitmask = 0
	else
		if not permutation_data.indexes[511 - chunk_bitmask] then
			local data = permutation_data[511 - chunk_bitmask]
			chunk_bitmask = data.from
			chunk_bitmask = permutation_data.indexes[chunk_bitmask]
			local flips = data.op[1]
			local rotations = data.op[2]
			if flips == 1 then
				scale_x = -1
			end
			for i=1,rotations do
				rot = rot + math.rad(90)
			end
		else
			chunk_bitmask = permutation_data.indexes[511 - chunk_bitmask]
		end
	end

	local offsets = {
    { x = 0, y = 0 },
    { x = 1, y = 0 },
    { x = 1, y = 1 },
		{ x = 0, y = 1 },
		-- These are for when scale_x == -1
    { x = 1, y = 0 },
    { x = 1, y = 1 },
    { x = 0, y = 1 },
    { x = 0, y = 0 },
  }
	local quadrant = math.floor(rot / (math.pi * 2) * 4) + 4 * (scale_x == -1 and 1 or 0) % 8
	-- local quadrant = (math.floor(rot / (math.pi * 2) * 4) + (scale_x == -1 and 3 or 0)) % 4

	return {
		anim = "anim_" .. chunk_bitmask,
		scale_x = scale_x,
		rot = rot,
		offset = offsets[quadrant+1],
		is_fully_black = chunk_bitmask == 101,
		color = { r = chunk.r / 255, g = chunk.g / 255, b = chunk.b / 255 },
	}
end

function OnPausedChanged(is_paused, is_inventory_pause)
	-- set_minimap_visible(not (is_paused or is_inventory_pause or HasFlagPersistent("locationtracker_hide_map")))
end
