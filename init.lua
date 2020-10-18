dofile_once("mods/LocationTracker/files/encode_coords.lua")
dofile_once("mods/LocationTracker/files/show_or_hide.lua")

local map_width = 70
local map_height = 48
local minimap_pos_x = 1009 + 0.5
local minimap_pos_y = 65 + 0.5
local biome_map_offset_y = 14
local seen_areas
local last_map_position = "0_0"
local dirty_areas = {}
local map_colors_last_update = {}
local map
local zoom = 3
local center = 5 * 3 * zoom

ModLuaFileAppend("data/biome_impl/biome_map_newgame_plus.lua", "mods/LocationTracker/files/biome_map_append.lua")
if ModIsEnabled("New Biomes + Secrets") then
	ModLuaFileAppend("data/scripts/biomes/biome_map_armory_biomes.lua", "mods/LocationTracker/files/biome_map_append.lua")
end
if ModIsEnabled("commonifier") then
	ModLuaFileAppend("data/scripts/biomes/biome_map_armory.lua", "mods/LocationTracker/files/biome_map_append.lua")
end
if ModIsEnabled("VolcanoBiome") then
	ModLuaFileAppend("mods/VolcanoBiome/files/scripts/map_loader.lua", "mods/LocationTracker/files/biome_map_append.lua")
end
if ModIsEnabled("VolcanoBiome") or ModIsEnabled("New Biomes + Secrets") or ModIsEnabled("commonifier") then
	biome_map_offset_y = 54
else
	local temp_magic_numbers_filepath = "mods/LocationTracker/_virtual/magic_numbers.xml"
	ModTextFileSetContent(temp_magic_numbers_filepath, [[<MagicNumbers BIOME_MAP="mods/LocationTracker/files/map_script.lua" /> ]])
	ModMagicNumbersFileAdd(temp_magic_numbers_filepath)
end

function OnWorldPreUpdate()
	dofile("mods/LocationTracker/files/gui.lua")
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

local function set_area_dirty(start_x, start_y, end_x, end_y)
	local dirty_string = ""
	for y=1, 11 do
		for x=1, 11 do
			if x >= start_x and x <= end_x and y >= start_y and y <= end_y then
				dirty_areas[x .. "_" .. y] = true
			end
		end
	end
end

local function has_dirty_areas()
	for k, v in pairs(dirty_areas) do
		return true
	end
	return false
end

function OnWorldPostUpdate()
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

	local cx, cy = get_position()
	local chunk_x, chunk_y = get_chunk_coords(cx, cy)
	local new_map_position = chunk_x .. "_" .. chunk_y

	-- Don't start tracking until after 20 frames have passed so it doesn't track the transition when the player spawns somewhere else and zooms into place
	if GameGetFrameNum() > 20 and new_map_position ~= last_map_position then
		last_map_position = new_map_position
		for y=1,11 do
			for x=1,11 do
				local color_data = get_color_data(cx, cy, x-6, y-6)
				local last_update = map_colors_last_update[encode_coords(x, y)] or { is_fully_black = false, anim = "", scale_x = 1, rot = 0 }
				if not (last_update.is_fully_black and color_data.is_fully_black) and (last_update.anim ~= color_data.anim or last_update.scale_x ~= color_data.scale_x or last_update.rot ~= color_data.rot) then
					dirty_areas[encode_coords(x, y)] = true
				end
				map_colors_last_update[encode_coords(x, y)] = color_data
			end
		end
	end
	if GlobalsGetValue("LocationTracker_force_update", "0") == "1" then
		GlobalsSetValue("LocationTracker_force_update", "0")
		set_area_dirty(1, 1, 11, 11)
	end

	local sub_x = cx - chunk_x * 512 
	local sub_y = cy - chunk_y * 512
	sub_x = math.floor(sub_x / (512/3))
	sub_y = math.floor(sub_y / (512/3))
	local you_are_here = EntityGetWithName("location_tracker_you_are_here")
	EntitySetTransform(you_are_here, minimap_pos_x + center - 1.5 + (sub_x - 1) * zoom, minimap_pos_y + center - 1.5 + (sub_y - 1) * zoom)
	local current_sub_value = bit.lshift(1, sub_x + sub_y * 3)
	local chunk_coords = encode_coords(chunk_x, chunk_y)
	local current_chunk_bitmask = seen_areas[chunk_coords] or 0
	local new_value = bit.bor(current_chunk_bitmask, current_sub_value)
	if GameGetFrameNum() > 20 and current_chunk_bitmask ~= new_value then
		set_area_dirty(6, 6, 6, 6)
		seen_areas[chunk_coords] = new_value
		local out = ""
		for k, v in pairs(seen_areas) do
			out = out .. k .. "_" .. v
			if next(seen_areas,k) then
				out = out .. ","
			end
		end
		GlobalsSetValue("LocationTracker_seen_areas", out)
	end

	if map and not HasFlagPersistent("locationtracker_hide_map") and has_dirty_areas() then
		local location_tracker = EntityGetWithName("location_tracker")
		local children = EntityGetAllChildren(location_tracker)
		if children then
			(function()
				local boop = 0
				for coords,_ in pairs(dirty_areas) do
					boop = boop + 1
					if boop > 11 then return end
					local xy = split_string(coords, "_")
					local x, y = xy[1]-1, xy[2]-1
					local child = children[(x+1)+(y*11)]
					local sprite_component = EntityGetFirstComponentIncludingDisabled(child, "SpriteComponent")
					local color_data = get_color_data(cx, cy, x-5, y-5)
					dirty_areas[coords] = nil
					EntitySetTransform(child, minimap_pos_x + x*(zoom*3), minimap_pos_y + y*(zoom*3), color_data.rot, color_data.scale_x * zoom, zoom)
					ComponentSetValue2(sprite_component, "rect_animation", color_data.anim)
				end
			end)()
		end
	end
end

function OnPlayerSpawned(player)
	if EntityGetWithName("location_tracker") == 0 then
		EntityLoad("mods/LocationTracker/files/minimap.xml", minimap_pos_x, minimap_pos_y)
		EntityLoad("mods/LocationTracker/files/you_are_here.xml", minimap_pos_x + center, minimap_pos_y + center)
		set_minimap_visible(not HasFlagPersistent("locationtracker_hide_map"))
	end
end

function get_color_data(x, y, offset_x, offset_y)
	local biome_x, biome_y = get_biome_map_coords(map_width, map_height, x, y, offset_x, offset_y)
	local chunk_x, chunk_y = get_chunk_coords(x + 512 * offset_x, y + 512 * offset_y)
	local chunk = map[encode_coords(biome_x, biome_y)]
	local chunk_bitmask = seen_areas[encode_coords(chunk_x, chunk_y)] or 0
	local permutation_data = dofile_once("mods/LocationTracker/files/permutation_data.lua")
	local rot, scale_x, scale_y = 0, 1, 1
	if HasFlagPersistent("locationtracker_fog_of_war_disabled") then
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
	return {
		anim = "anim_" .. tostring(math.floor(chunk.r / 255 * 0xff0000) + math.floor(chunk.g / 255 * 0xff00) + math.floor(chunk.b / 255 * 0xff)) .. "_" .. chunk_bitmask,
		scale_x = scale_x,
		rot = rot,
		is_fully_black = chunk_bitmask == 101
	}
end

function OnPausedChanged(is_paused, is_inventory_pause)
	set_minimap_visible(not (is_paused or is_inventory_pause or HasFlagPersistent("locationtracker_hide_map")))
end
