dofile_once("mods/LocationTracker/files/encode_coords.lua")
dofile_once("data/scripts/lib/utilities.lua")
local permutation_data = dofile_once("mods/LocationTracker/files/permutation_data.lua")
local nxml = dofile_once("mods/LocationTracker/lib/nxml.lua")

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
local minimap_pos_x = 490-- + 0.5
local minimap_pos_y = 65-- + 0.5
local biome_map_offset_y = 14
local seen_areas
local last_chunk_x, last_chunk_y = 0, 0
local map
local zoom = 1.5
local sprite_scale = 3
local color_data = {}
local size = { x = 11, y = 11 }
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

function OnWorldPreUpdate()
	-- dofile("mods/LocationTracker/files/gui.lua")
	gui = gui or GuiCreate()
	GuiStartFrame(gui)
	GuiOptionsAdd(gui, GUI_OPTION.NoPositionTween)
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
			GuiImageNinePiece(gui, 40000, offx + minimap_pos_x, offy + minimap_pos_y, math.floor(total_size.x), math.floor(total_size.y), 3, "mods/LocationTracker/files/border.png")
			-- Draw the dot in the center
			GuiZSetForNextWidget(gui, -999)
			GuiImage(
				gui,
				25000, -- id:int
				offx + minimap_pos_x + math.floor(total_size.x/2) + (sub_x-1)*zoom, -- x:number
				offy + minimap_pos_y + math.floor(total_size.y/2) + (sub_y-1)*zoom, -- y:number
				-- minimap_pos_x + math.floor(total_size.x/2 + 0.5+(sub_x-2)*zoom), -- x:number
				-- minimap_pos_y + math.floor(total_size.y/2 + 0.5+(sub_y-2)*zoom), -- y:number
				"mods/LocationTracker/files/you_are_here.png", -- sprite_filename:string
				1, -- alpha:number
				0.5 -- scale:number
			)
		end
		if not locked then
			GuiOptionsAddForNextWidget(gui, GUI_OPTION.IsDraggable)
			local tw, th = GuiGetTextDimensions(gui, "DRAG")
			local start_x = offx + minimap_pos_x + total_size.x/2 - math.floor(tw/2)
			local start_y = offy + minimap_pos_y - th - 2
			GuiButton(gui, 4999, start_x, start_y, "DRAG")
			local clicked, right_clicked, hovered, xx, yy, width, height, draw_x, draw_y = GuiGetPreviousWidgetInfo(gui)
			offx = math.floor(offx + (draw_x - start_x))
			offy = math.floor(offy + (draw_y - start_y))
			offx = math.max(5 - minimap_pos_x, math.min(screen_width - (total_size.x + 5) - minimap_pos_x, offx))
			offy = math.max(5 - minimap_pos_y, math.min(screen_height - (total_size.y + 5) - minimap_pos_y, offy))
	
			local start_x = offx + minimap_pos_x + total_size.x
			local start_y = offy + minimap_pos_y + total_size.y
			GuiOptionsAddForNextWidget(gui, GUI_OPTION.IsDraggable)
			GuiButton(gui, 5000, start_x, start_y, "  ")
			local clicked, right_clicked, hovered, xx, yy, width, height, draw_x, draw_y = GuiGetPreviousWidgetInfo(gui)
			GuiImage(gui, 5001, xx, yy, "mods/LocationTracker/files/resize_handle.png", 1, 1, 0)
			local dx = math.floor((xx - start_x) / zoom / 10)
			local dy = math.floor((yy - start_y) / zoom / 10)
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
			-- if not locked then
			-- 	EntityLoad("mods/LocationTracker/files/controls_watcher.xml")
			-- end
		end
		if locked then
			-- Show/hide button
			if GuiImageButton(gui, 30002, math.floor(offx + minimap_pos_x + total_size.x + 5), math.floor(offy + minimap_pos_y + 11), "", "mods/LocationTracker/files/eye_"..(visible and "open" or "closed") ..".png") then
				visible = not visible
			end
			-- Fog of war button
			if GuiImageButton(gui, 30003, math.floor(offx + minimap_pos_x + total_size.x + 5), math.floor(offy + minimap_pos_y + 22), "", "mods/LocationTracker/files/fog_of_war_"..(fog_of_war and "on" or "off") ..".png") then
				fog_of_war = not fog_of_war
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
