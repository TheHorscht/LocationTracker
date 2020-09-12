dofile_once("mods/LocationTracker/files/encode_coords.lua")

local temp_magic_numbers_filepath = "mods/LocationTracker/_virtual/magic_numbers.xml"
ModTextFileSetContent(temp_magic_numbers_filepath, [[<MagicNumbers BIOME_MAP="mods/LocationTracker/files/map_script.lua" /> ]])
ModMagicNumbersFileAdd(temp_magic_numbers_filepath)

local map_width = 3
local map_height = 3
local biome_map_offset_y = 1
local seen_areas

function OnWorldPreUpdate()
	dofile("mods/LocationTracker/files/gui.lua")
end

local function get_chunk_coords(x, y)
	return math.floor(x / 512), math.floor(y / 512)
end

-- offset_x is in chunks
local function get_biome_map_coords(x, y, offset_x, offset_y)
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
		print(stored)
		if stored ~= "" then
			seen_areas = {}
			local areas = split_string(stored, ",")
			for i, area in ipairs(areas) do
				print(area)
				local xy = split_string(area, "_")
				seen_areas[encode_coords(xy[1], xy[2])] = true
			end
		end
		GameSetPostFxParameter("uLocationTracker_alpha", HasFlagPersistent("locationtracker_hide_map") and 0 or 1, 0, 0, 0)
	end
	if GameGetFrameNum() % 10 == 0 then
		local map = dofile_once("mods/LocationTracker/_virtual/map.lua")
		if map then
			local output = { r = 0, g = 0, b = 0 }
			local cx, cy = GameGetCameraPos()
			local chunk_x, chunk_y = get_chunk_coords(cx, cy)
			if not seen_areas[encode_coords(chunk_x, chunk_y)] then
				seen_areas[encode_coords(chunk_x, chunk_y)] = true
				local out = ""
				for k, v in pairs(seen_areas) do
					out = out .. k
					if next(seen_areas,k) then
						out = out .. ","
					end
				end
				print(out)
				GlobalsSetValue("LocationTracker_seen_areas", out)
			end

			for y=0,9 do
				for x=0,9 do
					local biome_x, biome_y = get_biome_map_coords(cx, cy, x-5, y-5)
					local chunk_x, chunk_y = get_chunk_coords(cx + (512 * (x-5)), cy + (512 * (y-5)))
					local chunk = map[encode_coords(biome_x, biome_y)]
					set_pixel_color(x, y, chunk.r, chunk.g, chunk.b, seen_areas[encode_coords(chunk_x, chunk_y)])
				end
			end
			-- GameSetPostFxParameter("uLocationTracker_player_pos", px, py)
		end
	end
end

--[[ 
  VIRTUAL_RESOLUTION_X="427" 
  VIRTUAL_RESOLUTION_Y="242" 

 ]]