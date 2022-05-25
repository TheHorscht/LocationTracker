dofile_once("mods/LocationTracker/files/encode_coords.lua")
dofile_once("mods/LocationTracker/files/map_utils.lua")
dofile_once("data/scripts/lib/utilities.lua")
local permutation_data = dofile_once("mods/LocationTracker/files/permutation_data.lua")
local nxml = dofile_once("mods/LocationTracker/lib/nxml.lua")
local EZMouse = dofile_once("mods/LocationTracker/lib/EZMouse/EZMouse.lua")("mods/LocationTracker/lib/EZMouse/")
-- ModLuaFileAppend("data/scripts/gun/gun.lua", "mods/LocationTracker/lib/EZMouse/gun_append.lua")

local function truncate_float(num)
  return num + (2^52 + 2^51) - (2^52 + 2^51)
end

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
local minimap_pos_x
local minimap_pos_y
local biome_map_offset_y = 14
local seen_areas
local map
local zoom
local show_location
local alpha
local compatibility_mode
local sprite_scale = 3
local color_data = {}
local size = {}
local block_size = { x = 3, y = 3 }
local total_size
local locked = true
local visible = true
local fog_of_war = true
local show_biome_name = "top"
local resize_mode = "resolution"

function is_inventory_open()
	local player = EntityGetWithTag("player_unit")[1]
	if player then
		local inventory_gui_component = EntityGetFirstComponentIncludingDisabled(player, "InventoryGuiComponent")
		if inventory_gui_component then
			return ComponentGetValue2(inventory_gui_component, "mActive")
		end
	end
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

local function get_chunk_coords(x, y)
	return math.floor(x / 512), math.floor(y / 512)
end

-- Used in get_color_data, moved out here for performance
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

local function get_chunk_bitmask(chunk_x, chunk_y)
	local chunk_bitmask = seen_areas[encode_coords(chunk_x, chunk_y)] or 0
	return seen_areas[encode_coords(chunk_x, chunk_y)] or 0
end

local function add_chunk_bitmask(chunk_x, chunk_y, bitmask)
	seen_areas[encode_coords(chunk_x, chunk_y)] = bitmask
end

function get_color_data(x, y, offset_x, offset_y)
	local biome_x, biome_y = get_biome_map_coords(map_width, map_height, x, y, offset_x, offset_y)
	local chunk_x, chunk_y = get_chunk_coords(x + 512 * offset_x, y + 512 * offset_y)
	local chunk_color = map[encode_coords(biome_x, biome_y)]
	local chunk_bitmask = get_chunk_bitmask(chunk_x, chunk_y)
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

	local quadrant = math.floor(rot / (math.pi * 2) * 4) + 4 * (scale_x == -1 and 1 or 0) % 8

	return {
		anim = "anim_" .. chunk_bitmask,
		scale_x = scale_x,
		rot = rot,
		offset = offsets[quadrant+1],
		is_fully_black = chunk_bitmask == 101,
		color = { r = chunk_color.r / 255, g = chunk_color.g / 255, b = chunk_color.b / 255 },
	}
end

local function calculate_total_size()
	total_size = { x = size.x * block_size.x * zoom, y = size.y * block_size.y * zoom }
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

local function generate_color_data()
	local halfsize_x = math.floor(size.x/2)
	local halfsize_y = math.floor(size.y/2)
	local cx, cy = get_position()
	color_data = {}
	for y=0, size.y-1 do
		for x=0, size.x-1 do
			local idx = x+y*size.x
			color_data[idx] = get_color_data(cx, cy, x - halfsize_x, y - halfsize_y)
		end
	end
end

-- Purely an optimization function, transforms the table of pixels into rectangles to draw
-- by consolidating neighboring pixels with the same colors into rects, also analyses which
-- rects appear most and consolidates them even more into one "most_prevalent_color" rect
-- which gets drawn first in the background over the whole area of the map
local function regenerate_drawables()
	if not map then return end
	generate_color_data()
	local pixels = {}
	local drawables = {}
	for y=0, size.y-1 do
		for x=0, size.x-1 do
			local idx = x+y*size.x
			local cdata = color_data[idx]
			if cdata.anim == "anim_0" then -- 0 is fully explored
				pixels[idx] = cdata
			elseif cdata.anim == "anim_101" then -- 101 is fully black
				cdata.color = { r = 0, g = 0, b = 0 }
				pixels[idx] = cdata
			else
				cdata.x = x
				cdata.y = y
				cdata.width = 1
				cdata.height = 1
				table.insert(drawables, cdata)
			end
		end
	end

	local function isSameColor(c1, c2)
		if not c1 or not c2 then return false end
		return c1.r == c2.r and c1.g == c2.g and c1.b == c2.b
	end

	local function getColorAt(x, y)
		if x < 0 or x > size.x-1 or y < 0 or y > size.y-1 then
			return nil
		end
		local idx = x+y*size.x
		return pixels[idx] and pixels[idx].color
	end

	local completed_rects = {}
	local color_count = {}
	local most_prevalent_color
	for y=0, size.y-1 do
		local x = 0
		-- Using a while loop because we can't modify for-loop variables from within the loop
		while x <= size.x-1 do
			local width, height = 1, 1
			local startX, startY = x, y
			local color = getColorAt(x, y)
			if completed_rects[encode_coords(x, y)] then
				x = x + 1
				-- and continue to the next iteration
			else
				-- Try to find all rectangles that can be made from this starting position
				-- Row by row, walk to the right until the color doesn't match the starting color anymore
				local maxX = size.x-1
				local rects = {}
				for tempY=y, size.y-1 do
					x = startX
					width = 1
					-- Check current color
					if not isSameColor(color, getColorAt(x, tempY)) then
						break
					end
					-- Expand as far to the right as we can, stop if we meet a pixel that is already part of a completed big rect or has a different color
					while x+1 <= maxX and isSameColor(color, getColorAt(x+1, tempY)) and not completed_rects[encode_coords(x+1, tempY)] do
						width = width + 1
						x = x + 1
					end
					maxX = startX + width - 1
					table.insert(rects, { x = startX, y = startY, width = width, height = height, area = width * height, color = color, scale_x = 1, anim = "anim_0" })
					height = height + 1
				end

				local biggest
				for i, v in ipairs(rects) do
					if not biggest or biggest.area < v.area then
						biggest = v
					end						
				end

				if biggest then
					x = startX + biggest.width
					local alreadyFound = false
					local y2 = biggest.y
					while y2 < biggest.y + biggest.height and not alreadyFound do
						local x2 = biggest.x
						while x2 < biggest.x + biggest.width and not alreadyFound do
							if completed_rects[encode_coords(x2, y2)] then
								alreadyFound = true
							else
								completed_rects[encode_coords(x2, y2)] = true
							end
							x2 = x2 + 1
						end
						y2 = y2 + 1
					end

					if not alreadyFound then
						biggest.offset = { x = 0, y = 0 }
						local color_hex = color_to_hex(biggest.color)
						color_count[color_hex] = (color_count[color_hex] or 0) + 1
						if (not most_prevalent_color) or (color_count[color_hex] > most_prevalent_color.count) then
							most_prevalent_color = { color_hex = color_hex, color = biggest.color, count = color_count[color_hex] }
						end
						table.insert(drawables, biggest)
					end
				else
					x = x + 1
				end
			end
		end	
	end	

	if alpha > 0.98 then
		g_most_prevalent_color = most_prevalent_color and most_prevalent_color.color
		g_drawables = {}
		-- This scenario only happens if there are no fully black or fully revealed squares
		if most_prevalent_color then
			for i, v in ipairs(drawables) do
				if not (v.anim == "anim_0" or v.anim == "anim_101") or color_to_hex(v.color) ~= most_prevalent_color.color_hex then
					table.insert(g_drawables, v)
				end
			end
		else
			g_drawables = drawables
		end
	else
		g_drawables = drawables
	end
end

local function load_settings()
	minimap_pos_x = ModSettingGet("LocationTracker.pos_x")
	minimap_pos_y = ModSettingGet("LocationTracker.pos_y")
	size.x = truncate_float(ModSettingGet("LocationTracker.size_x"))
	size.y = truncate_float(ModSettingGet("LocationTracker.size_y"))
	zoom = ModSettingGet("LocationTracker.zoom")
	show_location = ModSettingGet("LocationTracker.show_location")
	alpha = ModSettingGet("LocationTracker.alpha")
	compatibility_mode = ModSettingGet("LocationTracker.compatibility_mode")
	fog_of_war = ModSettingGetNextValue("LocationTracker.fog_of_war")
	show_biome_name = ModSettingGet("LocationTracker.show_biome_name")
	if fog_of_war == nil then
		fog_of_war = true
	end
	calculate_total_size()
	regenerate_drawables()
end
load_settings()

-- Try to find other mods' map script for appending to it
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

-- If no other mod modifies the map, this mod can safely register it's own map script to read out map data
if (not compatibility_mode) and #biome_map_script_paths == 0 then
	local temp_magic_numbers_filepath = "mods/LocationTracker/_virtual/magic_numbers.xml"
	ModTextFileSetContent(temp_magic_numbers_filepath, [[<MagicNumbers BIOME_MAP="mods/LocationTracker/files/map_script.lua" />]])
	ModMagicNumbersFileAdd(temp_magic_numbers_filepath)
end

-- Append to the already registered map script as late as possible when all other mods have added their appends already
-- this append needs to be the absolute last.
function OnMagicNumbersAndWorldSeedInitialized()
	if not compatibility_mode then
		ModLuaFileAppend("data/biome_impl/biome_map_newgame_plus.lua", "mods/LocationTracker/files/biome_map_append.lua")
		for i, script_path in ipairs(biome_map_script_paths) do
			ModLuaFileAppend(script_path, "mods/LocationTracker/files/biome_map_append.lua")
		end
	end
end

local biomes_all_content = ModTextFileGetContent("data/biome/_biomes_all.xml")
if biomes_all_content then
	local xml = nxml.parse(biomes_all_content)
	biome_map_offset_y = xml.attr.biome_offset_y
end

local widget = EZMouse.Widget({
	x = 200,
	y = 100,
	width = 100,
	height = 60,
	resizable = true,
	enabled = false,
	resize_granularity = block_size.x * zoom,
})
widget:AddEventListener("drag", function(self, dx, dy)
	minimap_pos_x = self.x
	minimap_pos_y = self.y
end)
widget:AddEventListener("resize", function(self, move_x, move_y)
	minimap_pos_x = self.x
	minimap_pos_y = self.y
	if resize_mode == "zoom" then
		local min_size = 5
		self.min_width = min_size
		self.min_height = min_size
		zoom = self.width / block_size.x / size.x
	else
		size.x = math.floor(self.width / block_size.x / zoom + 0.5)
		size.y = math.floor(self.height / block_size.y / zoom + 0.5)
		local min_size = block_size.x * zoom
		self.min_width = min_size
		self.min_height = min_size
	end
	calculate_total_size()
	regenerate_drawables()
end)

-- Save information about when the game was done loading
local frame_world_initialized
function OnWorldInitialized()
	frame_world_initialized = GameGetFrameNum()
end

function color_to_hex(c)
	return string.format("%02X%02X%02X", c.r * 255, c.g * 255, c.b * 255)
end

local function get_map_data()
	if compatibility_mode then
		return get_map_data_by_biome_filename()
	else
		return dofile_once("mods/LocationTracker/_virtual/map.lua")
	end
end

local function get_current_biome_name()
	local cx, cy = GameGetCameraPos()
	local px, py = GetParallelWorldPosition(cx, cy)
	local biome_name = GameTextGetTranslatedOrNot(BiomeMapGetName(cx, cy)) -- GameTextGet
	if biome_name == "_EMPTY_" then
		return ""
	end
	-- Capitalize every word
	biome_name = biome_name:gsub("(%a)([%w_']*)", function(first, rest)
		return first:upper()..rest:lower()
	end)
	if px > 0 then
		biome_name = GameTextGet("$biome_east", biome_name) .. ("(%d)"):format(math.abs(px))
	elseif px < 0 then
		biome_name = GameTextGet("$biome_west", biome_name) .. ("(%d)"):format(math.abs(px))
	end
	return biome_name
end

function OnWorldPreUpdate()
	gui = gui or GuiCreate()
	GuiStartFrame(gui)
	GuiOptionsAdd(gui, GUI_OPTION.NoPositionTween)

	EZMouse.update()

	if not seen_areas then
		-- Initializing
		seen_areas = {}
		local stored = GlobalsGetValue("LocationTracker_seen_areas", "")
		if stored ~= "" then
			seen_areas = {}
			local areas = split_string(stored, ",")
			for i, area in ipairs(areas) do
				local xy_v = split_string(area, "_")
				seen_areas[tonumber(xy_v[1])] = tonumber(xy_v[2])
			end
		end
		-- FOR DEBUGGING
		-- for y=0, 500 do
		-- 	for x=0, 500 do
		-- 		-- add_chunk_bitmask(x-50, y-50, 511)
		-- 		add_chunk_bitmask(x-50, y-50, 127)
		-- 	end
		-- end
		local data = get_map_data()
		map_width = data.width
		map_height = data.height
		map = data.map
	end
	if GameHasFlagRun("locationtracker_reload_map") then
		GameRemoveFlagRun("locationtracker_reload_map")
		seen_areas = {}
		regenerate_drawables()
		GlobalsSetValue("LocationTracker_seen_areas", "")
		local data = get_map_data()
		map_width = data.width
		map_height = data.height
		map = data.map
	end
	-- Only start the map logic once the game is actually loaded and the camera/player is at the correct location
	-- The game starts of without the player and the camera being somewhere at the -1, -1 chunk
	if not frame_world_initialized or GameGetFrameNum() - frame_world_initialized < 20 then return end

	local cx, cy = get_position()
	local chunk_x, chunk_y = get_chunk_coords(cx, cy)
	local sub_x = cx - chunk_x * 512 
	local sub_y = cy - chunk_y * 512
	sub_x = math.floor(sub_x / (512 / block_size.x))
	sub_y = math.floor(sub_y / (512 / block_size.y))
	local current_sub_value = bit.lshift(1, sub_x + sub_y * block_size.x)
	local chunk_coords = encode_coords(chunk_x, chunk_y)
	local current_chunk_bitmask = get_chunk_bitmask(chunk_x, chunk_y)
	local new_value = bit.bor(current_chunk_bitmask, current_sub_value)
	-- Invalidate the cache when moving to a new chunk
	if chunk_x ~= previous_chunk_x or chunk_y ~= previous_chunk_y then
		regenerate_drawables()
	end
	previous_chunk_x = chunk_x
	previous_chunk_y = chunk_y
	if current_chunk_bitmask ~= new_value then
		seen_areas[chunk_coords] = new_value
		regenerate_drawables()
		-- TODO: Do this without strings at all? ModSettings perhaps?
		local coord_bitmask_pair_strings = {}
		for k, v in pairs(seen_areas) do
			table.insert(coord_bitmask_pair_strings, k .. "_" .. v)
		end
		GlobalsSetValue("LocationTracker_seen_areas", table.concat(coord_bitmask_pair_strings, ","))
	end

	-- Make buttons non-interactive
	-- Stolen from goki's things ( ͡° ͜ʖ ͡°)
	local player = EntityGetWithTag("player_unit")[1]
	if player then
		local platform_shooter_player = EntityGetFirstComponentIncludingDisabled(player, "PlatformShooterPlayerComponent")
		if platform_shooter_player then
			local is_gamepad = ComponentGetValue2(platform_shooter_player, "mHasGamepadControlsPrev")
			if is_gamepad then
				GuiOptionsAdd(gui, GUI_OPTION.NonInteractive)
				GuiOptionsAdd(gui, GUI_OPTION.AlwaysClickable)
			end
		end
	end

	if map and not is_inventory_open() then
		if visible or not locked then
			-- Draw the map
			-- Draw a rect spanning the entire map area behind all the other rects which then get rendered on top
			if alpha > 0.98 and g_most_prevalent_color then
				GuiZSetForNextWidget(gui, 2)
				GuiColorSetForNextWidget(gui, g_most_prevalent_color.r, g_most_prevalent_color.g, g_most_prevalent_color.b, 1)
				GuiOptionsAddForNextWidget(gui, GUI_OPTION.NonInteractive)
				GuiImage(gui, 10010,
					minimap_pos_x, minimap_pos_y, "mods/LocationTracker/files/white_3x3.png",
					1,
					zoom / sprite_scale * 3 * size.x,
					zoom / sprite_scale * 3 * size.y,
					0
				)
			end
			for i, drawable in ipairs(g_drawables) do
				GuiZSetForNextWidget(gui, 1)
				GuiColorSetForNextWidget(gui, drawable.color.r, drawable.color.g, drawable.color.b, 1)
				GuiOptionsAddForNextWidget(gui, GUI_OPTION.NonInteractive)
				GuiImage(gui,
					10010 + i, -- id:int
					minimap_pos_x + (drawable.x + drawable.offset.x) * zoom * block_size.x, -- x:number
					minimap_pos_y + (drawable.y + drawable.offset.y) * zoom * block_size.y, -- y:number
					"mods/LocationTracker/files/color_sprites.xml", -- sprite_filename:string
					-- "mods/LocationTracker/files/white_3x3.png", --color_sprites.xml", -- sprite_filename:string
					alpha, -- alpha:number
					drawable.scale_x * zoom / sprite_scale * 1 * drawable.width, -- scale:number
					zoom / sprite_scale * 1 * drawable.height, --color_data[idx].rot -- rotation:number
					drawable.rot, -- scale_y:number
					GUI_RECT_ANIMATION_PLAYBACK.PlayToEndAndPause, -- rect_animation_playback_type:int = GUI_RECT_ANIMATION_PLAYBACK.PlayToEndAndHide
					drawable.anim -- rect_animation_name:string = ""
				)
			end
			-- Border
			GuiZSetForNextWidget(gui, -999)
			GuiOptionsAddForNextWidget(gui, GUI_OPTION.NonInteractive)
			GuiImageNinePiece(gui, 40000, minimap_pos_x, minimap_pos_y, total_size.x, total_size.y, 3, "mods/LocationTracker/files/border.png")
			-- Region Text + PW Counter
			if show_biome_name ~= "off" then
				local map_name = get_current_biome_name()
				local text_width = GuiGetTextDimensions(gui, map_name)
				local y = minimap_pos_y - 12
				if show_biome_name == "bottom" then
					y = minimap_pos_y + total_size.y + 2
				end
				GuiText(gui, minimap_pos_x + total_size.x / 2 - text_width / 2, y, map_name)
			end
			-- Draw the dot in the center
			local blink_delay = 30
			if (show_location == "blink" and GameGetFrameNum() % (blink_delay * 2) >= blink_delay)
				or show_location == "static" then
				GuiZSetForNextWidget(gui, -999)
				GuiOptionsAddForNextWidget(gui, GUI_OPTION.NonInteractive)
				GuiColorSetForNextWidget(gui, 1, 0, 0, 1)
				GuiImage(
					gui,
					25000, -- id:int
					minimap_pos_x + math.floor(size.x/2) * block_size.x * zoom + (sub_x)*zoom, -- x:number
					minimap_pos_y + math.floor(size.y/2) * block_size.x * zoom + (sub_y)*zoom, -- y:number
					"mods/LocationTracker/files/white_3x3.png", -- sprite_filename:string
					1, -- alpha:number
					block_size.x * zoom / 9 -- scale:number
				)
			end
		end
		-- Lock button
		if GuiImageButton(gui, 30001, math.floor(minimap_pos_x + total_size.x + 5), math.floor(minimap_pos_y - 1), "", "mods/LocationTracker/files/lock_"..(locked and "closed" or "open") ..".png") then
			locked = not locked
			widget.x = minimap_pos_x
			widget.y = minimap_pos_y
			widget.width = total_size.x
			widget.height = total_size.y
			widget.enabled = not locked
			-- Save settings when locking
			if locked then
				ModSettingSetNextValue("LocationTracker.pos_x", minimap_pos_x, false)
				ModSettingSetNextValue("LocationTracker.pos_x", minimap_pos_x, false)
				ModSettingSetNextValue("LocationTracker.pos_y", minimap_pos_y, false)
				ModSettingSetNextValue("LocationTracker.size_x", size.x, false)
				ModSettingSetNextValue("LocationTracker.size_y", size.y, false)
				ModSettingSetNextValue("LocationTracker.zoom", zoom, false)
			end
		end
		if locked then
			GuiTooltip(gui, "Unlock", "Unlock the minimap so you can resize it at the corners and move it around by dragging it.")
		else
			GuiTooltip(gui, "Lock", "Lock the minimap in place, prevent movement and resizing and save settings.")
		end
		if locked then
			-- Show/hide button
			if GuiImageButton(gui, 30002, math.floor(minimap_pos_x + total_size.x + 5), math.floor(minimap_pos_y + 11), "", "mods/LocationTracker/files/eye_"..(visible and "open" or "closed") ..".png") then
				visible = not visible
			end
			if visible then
				GuiTooltip(gui, "Hide minimap", "")
			else
				GuiTooltip(gui, "Show minimap", "")
			end
			-- Fog of war button
			if GuiImageButton(gui, 30003, math.floor(minimap_pos_x + total_size.x + 5), math.floor(minimap_pos_y + 22), "", "mods/LocationTracker/files/fog_of_war_"..(fog_of_war and "on" or "off") ..".png") then
				fog_of_war = not fog_of_war
				regenerate_drawables()
				ModSettingSetNextValue("LocationTracker.fog_of_war", fog_of_war, false)
			end
			if fog_of_war then
				GuiTooltip(gui, "Hide fog of war", "")
			else
				GuiTooltip(gui, "Show fog of war", "")
			end
		else
			local icon = "resize_mode"
			if resize_mode == "zoom" then
				icon = "magnifying_glass"
			end
			if GuiImageButton(gui, 30004, math.floor(minimap_pos_x + total_size.x + 5), math.floor(minimap_pos_y + 11), "", "mods/LocationTracker/files/" .. icon .. ".png") then
				resize_mode = resize_mode == "zoom" and "resolution" or "zoom"
				if resize_mode == "zoom" then
					widget.resize_granularity = 0.1
					widget.resize_keep_aspect_ratio = true
				else
					widget.resize_granularity = block_size.x * zoom
					widget.resize_keep_aspect_ratio = false
				end
			end
			if resize_mode == "zoom" then
				GuiTooltip(gui, "Switch to resolution mode", "")
			else
				GuiTooltip(gui, "Switch to zoom mode", "")
			end
		end
	end
end

function OnPausedChanged(is_paused, is_inventory_pause)
	if not is_paused and ModSettingGet("LocationTracker.ui_needs_update") then
		ModSettingSet("LocationTracker.ui_needs_update", false)
		load_settings()
	end
end
