dofile_once("mods/LocationTracker/files/encode_coords.lua")

local map_width = 70
local map_height = 48
local biome_map_offset_y = 14
local seen_areas
local screen_width, screen_height = 427, 242 -- Maybe read it from MagicNumbers:VIRTUAL_RESOLUTION_X and Y instead
local map

dofile_once("mods/LocationTracker/files/inject_shader.lua")

ModLuaFileAppend("data/biome_impl/biome_map_newgame_plus.lua", "mods/LocationTracker/files/biome_map_append.lua")
if ModIsEnabled("VolcanoBiome") or ModIsEnabled("New Biomes + Secrets") then
	biome_map_offset_y = 54
	ModLuaFileAppend("mods/VolcanoBiome/files/scripts/map_loader.lua", "mods/LocationTracker/files/biome_map_append.lua")
	ModLuaFileAppend("data/scripts/biomes/biome_map_armory_biomes.lua", "mods/LocationTracker/files/biome_map_append.lua")
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

-- offset_ is in chunks
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

local function set_pixel_color(x, y, r, g, b, active)
	if not active and not HasFlagPersistent("locationtracker_fog_of_war_disabled") then
		r, g, b = 0, 0, 0
	end
	GameSetPostFxParameter("uLocationTracker_" .. x .. "_" .. y, r / 255, g / 255, b / 255, 0)
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
				local xy = split_string(area, "_")
				seen_areas[encode_coords(xy[1], xy[2])] = true
			end
		end
		local data = loadfile("mods/LocationTracker/_virtual/map.lua")()
		map_width = data.width
		map_height = data.height
		map = data.map
		GameSetPostFxParameter("uLocationTracker_sizes", screen_width, screen_height, 3, 3)
		GameSetPostFxParameter("uLocationTracker_minimap_position", screen_width - 90, 20, 0, 0)
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
	if GameGetFrameNum() % 10 == 0 then
		if map then
			local output = { r = 0, g = 0, b = 0 }
			local cx, cy = GameGetCameraPos()
			local dirs = {{-1,-1},{0,-1},{1,-1},{-1,0},{0,0},{1,0},{-1,1},{0,1},{1,1}}
			local chunk_x, chunk_y = get_chunk_coords(cx, cy)
			for i, dir in ipairs(dirs) do
				-- Do a lookahead and if we hit something in our current chunk, continue
				local lookat_x, lookat_y = cx + 400 * dir[1], cy + 400 * dir[2]
				local did_hit, hit_x, hit_y = RaytraceSurfaces(cx, cy, lookat_x, lookat_y)
				local hit_chunk_x, hit_chunk_y = get_chunk_coords(hit_x or lookat_x, hit_y or lookat_y)
				if not seen_areas[encode_coords(hit_chunk_x, hit_chunk_y)] then
					seen_areas[encode_coords(hit_chunk_x, hit_chunk_y)] = true
					local out = ""
					for k, v in pairs(seen_areas) do
						out = out .. k
						if next(seen_areas,k) then
							out = out .. ","
						end
					end
					GlobalsSetValue("LocationTracker_seen_areas", out)
				end
			end

			for y=0,9 do
				for x=0,9 do
					local biome_x, biome_y = get_biome_map_coords(map_width, map_height, cx, cy, x-5, y-5)
					local chunk_x, chunk_y = get_chunk_coords(cx + (512 * (x-5)), cy + (512 * (y-5)))
					local chunk = map[encode_coords(biome_x, biome_y)]
					set_pixel_color(x, y, chunk.r, chunk.g, chunk.b, seen_areas[encode_coords(chunk_x, chunk_y)])
				end
			end
			-- GameSetPostFxParameter("uLocationTracker_player_pos", px, py)
		end
	end
end
