dofile_once("mods/LocationTracker/files/encode_coords.lua")
dofile_once("mods/LocationTracker/files/show_or_hide.lua")

local map_width = 70
local map_height = 48
local biome_map_offset_y = 14
local seen_areas
local map

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
	if GameGetFrameNum() % 30 == 0 then
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

			if not HasFlagPersistent("locationtracker_hide_map") then
				local location_tracker = EntityGetWithName("location_tracker")
				local sprite_components = EntityGetComponent(location_tracker, "SpriteComponent")
				if sprite_components then
					for y=0,10 do
						for x=0,10 do
							local biome_x, biome_y = get_biome_map_coords(map_width, map_height, cx, cy, x-5, y-5)
							local chunk_x, chunk_y = get_chunk_coords(cx + (512 * (x-5)), cy + (512 * (y-5)))
							local chunk = map[encode_coords(biome_x, biome_y)]
							local bla = "anim_" .. tostring(math.floor(chunk.r / 255 * 0xff0000) + math.floor(chunk.g / 255 * 0xff00) + math.floor(chunk.b / 255 * 0xff))
							local seen = seen_areas[encode_coords(chunk_x, chunk_y)]
							if not HasFlagPersistent("locationtracker_fog_of_war_disabled") and not seen then
								bla = "anim_0"
							end
							ComponentSetValue2(sprite_components[(x+1)+(y*11)], "rect_animation", bla)
						end
					end
				end
			end
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
	}
	local content = [[<Sprite
	filename="mods/LocationTracker/files/biome_colors.png"
	offset_x="0"
	offset_y="0" 
	default_animation="anim_0">
	<RectAnimation
		name="anim_0"
		pos_x="25"
		pos_y="25"
		frame_count="1"
		frame_width="1"
		frame_height="1"
		frame_wait="0.1"
		frames_per_row="1"
		loop="0">
	</RectAnimation>
]]

	for y=0,25-1 do
		for x=0,25-1 do
			local color = colors[x + y*25 + 1]
			if color then
				content = content .. [[
	<RectAnimation
		name="anim_]]..tostring(color)..[["
		pos_x="]]..(x*3+1)..[["
		pos_y="]]..(y*3+1)..[["
		frame_count="1"
		frame_width="1"
		frame_height="1"
		frame_wait="0.1"
		frames_per_row="1"
		loop="0">
	</RectAnimation>
	]]
			end
		end
	end
	content = content .. "</Sprite>"
	ModTextFileSetContent("mods/LocationTracker/_virtual/biome_map.xml", content)
end

function OnPlayerSpawned(player)
	if not GameHasFlagRun("locationtracker_minimap_added") then
		GameAddFlagRun("locationtracker_minimap_added")
		local minimap = EntityLoad("mods/LocationTracker/files/minimap.xml", 1007, 60)
		local you_are_here = EntityLoad("mods/LocationTracker/files/you_are_here.xml", 1040, 93)
		EntityAddChild(GameGetWorldStateEntity(), minimap)
		EntityAddChild(GameGetWorldStateEntity(), you_are_here)
	end
	set_minimap_visible(not HasFlagPersistent("locationtracker_hide_map"))
end
