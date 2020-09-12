local temp_magic_numbers_filepath = "mods/LocationTracker/_virtual/magic_numbers.xml"
ModTextFileSetContent(temp_magic_numbers_filepath, [[<MagicNumbers BIOME_MAP="mods/LocationTracker/files/map_script.lua" /> ]])
ModMagicNumbersFileAdd(temp_magic_numbers_filepath)

local map_width = 3
local map_height = 48
local biome_map_offset_y = 14
local seen

function OnWorldPreUpdate()
	dofile("mods/LocationTracker/files/gui.lua")
end

local function get_biome_map_coords(x, y, offset_x, offset_y)
	offset_x = offset_x or 0
	offset_y = offset_y or 0
	local biome_x, biome_y = math.floor((x / 512) + map_width / 2), math.floor((y / 512) + biome_map_offset_y)
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
	local world_number = math.floor(x / (map_width * 512))
	return biome_x, biome_y, world_number
end

function OnWorldPostUpdate()
	if not seen then
		-- Initializing
		seen = {}
		local stored = GlobalsGetValue("LocationTracker_seen_areas", "")
		print(stored)
		if stored ~= "" then
			seen = {}
			-- local num_worlds_stored = stored:sub(1, 1)
			for y=0,map_width-1 do
				for x=0,map_height-1 do
					local string_offset = x+y*48
					seen[x + y * 0x1000] = stored:sub(string_offset, string_offset) == "1"
				end
			end			
		end
		GameSetPostFxParameter("uLocationTracker_alpha", HasFlagPersistent("locationtracker_hide_map") and 0 or 1, 0, 0, 0)
	end
	if GameGetFrameNum() % 10 == 0 then
		local map = dofile_once("mods/LocationTracker/_virtual/map.lua")
		if map then
			local output = { r = 0, g = 0, b = 0 }
			local function set_pixel_color(x, y, r, g, b, active)
				if not active and not HasFlagPersistent("locationtracker_fog_of_war_disabled") then
					r, g, b = 0, 0, 0
				end
				GameSetPostFxParameter("uLocationTracker_" .. x .. "_" .. y, r / 255, g / 255, b / 255, 0)
			end
			local cx, cy = GameGetCameraPos()
			local biome_x, biome_y, world = get_biome_map_coords(cx, cy)
			if not seen[biome_x + biome_y * 0x100 + world * 0x10000] then
				seen[biome_x + biome_y * 0x100 + world * 0x10000] = true
				local out = ""
				for y=0,map_width-1 do
					for x=0,map_height-1 do
						out = out .. (seen[x + y * 0x100 + world * 0x10000] and "1" or "0")
					end
				end
				GlobalsSetValue("LocationTracker_seen_areas", out)
			end

			for y=0,9 do
				for x=0,9 do
					local biome_x, biome_y, world = get_biome_map_coords(cx, cy, x-5, y-5)
					local chunk = map[biome_x + biome_y * 0x1000]
					if not chunk then
						print(biome_x, biome_y)
					end
					set_pixel_color(x, y, chunk.r, chunk.g, chunk.b, seen[biome_x + biome_y * 0x100 + world * 0x10000])
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