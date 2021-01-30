dofile_once("mods/LocationTracker/files/encode_coords.lua")
dofile_once("data/scripts/lib/utilities.lua")
local permutation_data = dofile_once("mods/LocationTracker/files/permutation_data.lua")
local nxml = dofile_once("mods/LocationTracker/lib/nxml.lua")

local EZMouse = dofile_once("mods/LocationTracker/lib/EZMouse/EZMouse.lua")
ModLuaFileAppend("data/scripts/gun/gun.lua", "mods/LocationTracker/lib/EZMouse/gun_append.lua")

local defaults = dofile_once("mods/LocationTracker/settings_defaults.lua")

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
local sprite_scale = 3
local color_data = {}
local size = {}
local block_size = { x = 3, y = 3 }
local total_size
local locked = true
local visible = true
local fog_of_war = true
local resize_mode = "resolution"

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

function get_color_data(x, y, offset_x, offset_y)
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
	local cx, cy = get_position()
	color_data = {}
	for y=0, size.y-1 do
		for x=0, size.x-1 do
			local idx = x+y*size.x
			color_data[idx] = get_color_data(cx, cy, x-math.floor(size.x/2), y-math.floor(size.y/2))
		end
	end
end

local function load_settings()
	minimap_pos_x = ModSettingGet("LocationTracker.pos_x")
	minimap_pos_y = ModSettingGet("LocationTracker.pos_y")
	size.x = truncate_float(ModSettingGet("LocationTracker.size_x"))
	size.y = truncate_float(ModSettingGet("LocationTracker.size_y"))
	zoom = ModSettingGet("LocationTracker.zoom")
	show_location = ModSettingGet("LocationTracker.show_location")
	fog_of_war = ModSettingGetNextValue("LocationTracker.fog_of_war")
	if fog_of_war == nil then
		fog_of_war = true
	end
	calculate_total_size()
	color_data = nil
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

local widget = EZMouse.Widget.new({
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
	color_data = nil
end)

-- Save information about when the game was done loading
local frame_world_initialized
function OnWorldInitialized()
	frame_world_initialized = GameGetFrameNum()
end

function OnWorldPreUpdate()
	-- dofile("mods/LocationTracker/files/gui.lua")
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
		local data = loadfile("mods/LocationTracker/_virtual/map.lua")()
		map_width = data.width
		map_height = data.height
		map = data.map
	end
	if GameHasFlagRun("locationtracker_reload_map") then
		GameRemoveFlagRun("locationtracker_reload_map")
		seen_areas = {}
		color_data = nil
		GlobalsSetValue("LocationTracker_seen_areas", "")
		local data = loadfile("mods/LocationTracker/_virtual/map.lua")()
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
	local current_chunk_bitmask = seen_areas[chunk_coords] or 0
	local new_value = bit.bor(current_chunk_bitmask, current_sub_value)
	-- Invalidate the cache when moving to a new chunk
	if chunk_x ~= previous_chunk_x or chunk_y ~= previous_chunk_y then
		color_data = nil
	end
	previous_chunk_x = chunk_x
	previous_chunk_y = chunk_y
	if current_chunk_bitmask ~= new_value then
		color_data = nil
		seen_areas[chunk_coords] = new_value
		local out = ""
		for k, v in pairs(seen_areas) do
			out = out .. k .. "_" .. v -- TODO: Is this possible to do without concatenation? Concatenation is super slow
			if next(seen_areas,k) then
				out = out .. ","
			end
		end
		GlobalsSetValue("LocationTracker_seen_areas", out)
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

	if map then
		if visible or not locked then
			if not color_data then
				generate_color_data()
			end
			-- Draw the map
			for y=0, size.y-1 do
				for x=0, size.x-1 do
					local idx = x+y*size.x
					GuiColorSetForNextWidget(gui, color_data[idx].color.r, color_data[idx].color.g, color_data[idx].color.b, 1)
					GuiOptionsAddForNextWidget(gui, GUI_OPTION.NonInteractive)
					GuiImage(
						gui,
						10010 + idx, -- id:int
						minimap_pos_x + (x + color_data[idx].offset.x) * zoom*block_size.x, -- x:number
						minimap_pos_y + (y + color_data[idx].offset.y) * zoom*block_size.y, -- y:number
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
			GuiOptionsAddForNextWidget(gui, GUI_OPTION.NonInteractive)
			GuiImageNinePiece(gui, 40000, minimap_pos_x, minimap_pos_y, math.floor(total_size.x), math.floor(total_size.y), 3, "mods/LocationTracker/files/border.png")
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
					"mods/LocationTracker/a.png", -- sprite_filename:string
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
				generate_color_data()
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
					widget.resize_uniform = true
				else
					widget.resize_granularity = block_size.x * zoom
					widget.resize_uniform = false
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

function OnModPostInit()
	local content = ModTextFileGetContent("mods/LocationTracker/_virtual/mod_colors.lua")
	if content then
		mod_colors = dofile("mods/LocationTracker/_virtual/mod_colors.lua")
	end
end

function OnPausedChanged(is_paused, is_inventory_pause)
	if not is_paused and ModSettingGet("LocationTracker.ui_needs_update") then
		ModSettingSet("LocationTracker.ui_needs_update", false)
		load_settings()
	end
end
