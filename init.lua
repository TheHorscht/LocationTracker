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

function OnMagicNumbersAndWorldSeedInitialized()
	local colors = {
		0x632b4b, 0x6d3656,	0x78375c,	0x712f55,	0x873665,
		0xd13b3b,	0xa62b2b,	0xc03535,	0x36d517,	0x21A6AD,
		0x489fa4,	0x3d3e40,	0x2DC010,	0x33e311,	0x48E311,
		0xad8111,	0x7be311,	0x008040,	0xd57917,	0xD56517,
		0x124445,	0x1775d5,	0xe861f0,	0x008000,	0x0080a8,
		0xC00020,	0x50eed7,	0x14EED7,	0x14E1D7,	0x786C42,
		0x006C42,	0x0046FF,	0xFFA717,	0x0000ff,	0xFFFF00,
		0x808000,	0xA08400,	0x3d3d3d,	0xB3D01A,	0x788E07,
		0x684C4C,	0xff007f,	0xb33976,	0xB8A928,	0x3f3d3e,
		0x3d3e37,	0x3d3e38,	0x3d3e39,	0x3d3e3a,	0x3d3e3b,
		0x3d3e3c,	0x3d3e3d,	0x3d3e3e,	0x3d3e3f,	0x3d3e41,
		0x3C0F0A,	0xD3E6F0,	0x9C6C42,	0xC02020,	0x00F344,
		0x008080,	0x018080,	0x028080,	0x208080,	0x608080,
		0x204060,	0x224060,	0x214060,	0x224060,	0x234060,
		0x408080,	0x418080,	0x428080,	0x438080,	0xE08080,
		0xC08080,	0xC08082,	0xFF8080,	0xFF00FF,	0x3d5a3d,
		0x3d5a4f,	0x3D5AB2,	0x9b1818,	0x93cb5c,	0x3d5a5b,
		0xE1CD32,	0xFF6A02,	0x6dcba2,	0x6dcb28,	0x93cb4c,
		0x93cb4d,	0x93cb4e,	0x93cb4f,	0x93cb5a,	0x3D5A52,
		0x3D5A51,	0x3D5A50,	0x752ACF,	0x681EC1,	0x550DAD,
		0x410687,	0xf0d517,	0x5a9628,	0x5A9629,	0xcc9944,
		0xf7cf8d,	0xf6cfad,	0x968f5f,	0x968f96,	0xc88f5f,
		0x967F11,	0x967f5f,	0x167f5f,	0x1C9B9B,	0x933db2,
		0xED6868,	0xB67070,	0xD11A1A,	0xE43838,	0xB62323,
		0x6D2121,	0xAD6464,	0x800404,	0x490606,	0xAD8C8C,
		0x9B2323,	0x400202,	0x9B0B0B,	0xAD3D3D,	0x643333,
		0x3A2828,	0x8B2222, 0x680000,	0xFF9494,	0x978282,
		0x680D0D,	0x462020,	0xFF8686,	0x5D1818,	0x805C5C,
		0x686363,	0xA20606,	0xB90303,	0xD12525,	0x8B6969,
		0x2E0C0C,	0x807272,	0xD6D8E3,	0x77A5BD,	0x1133F1,
		0x11A3FC,	0x006B1E,	0x3046c1,	0x775ddb,	0x6ba04b,
		0xffd100,	0xffd101,	0xffd102,	0xffd103,	0xffd104,
		0xffd105,	0xffd106,	0xffd107,	0xffd108,	0xffd109,
		0xffd110,	0xffd111,	0x364d24,	0x085b77,	0x39401a,
		0x39401b,	0x39401c,	0x39401d,	0x157cb0,	0x157cb5,
		0x157cb6,	0x157cb7,	0x157cb8,	0xD17612,	0xAE8383,
		0xB9772E,	0x124ED1,	0x12D1C7,	0x36d5c9,	0xd57125,
		0x004611,	0x004777,	0x555fAE,	0x2B3380,	0x065774,
		0x6C72A2,	0x2289AE,	0x8C16B6,	0x0C1774,	0x393B46,
		0x5C98AE,

		0x24888a,  0x18a0d6,  0x0da899,  0x42244d,  0x99cb4c,  0x99cb4d,  0x99cb4e,  0x99cb4f,
		0x99cb5a,  0x1133F3,  0x89a04b,  0xbaa345,  0x57cace,  0x57dace,

		0x3f55d1, 0x2e99d1, 0x9d99d1,
	}
	local content = [[<Sprite
	filename="mods/LocationTracker/files/biome_colors.png"
	offset_x="0"
	offset_y="0" 
	default_animation="anim_0">
	<RectAnimation
		name="anim_0"
		pos_x="456"
		pos_y="546"
		frame_width="3"
		frame_height="3" />
]]

	for y=0,15-1 do
		for x=0,20-1 do
			local color = colors[x + y*20 + 1]
			if color then
				for vy=0,12 do
					for vx=0,7 do
						local v = vx + vy * 8
						if v <= 101 then
							content = content .. [[
							<RectAnimation
								name="anim_]]..tostring(color).."_"..tostring(v)..[["
								pos_x="]]..(x*8*3+vx*3)..[["
								pos_y="]]..(y*13*3+vy*3)..[["
								frame_width="3"
								frame_height="3"/>
							]]
						end
					end
				end
			end
		end
	end
	content = content .. "</Sprite>"
	ModTextFileSetContent("mods/LocationTracker/_virtual/biome_map.xml", content)
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
