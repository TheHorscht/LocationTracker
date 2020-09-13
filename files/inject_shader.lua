local content = ModTextFileGetContent("data/shaders/post_final.frag")

function string.insert(str1, str2, pos)
	return str1:sub(1,pos)..str2..str1:sub(pos+1)
end

-- Insert uniforms at the end of the existing uniforms
local string_to_look_for = "varying vec2 tex_coord_fogofwar;"
local insertion_point = string.find(content, string_to_look_for)
local code_to_insert = ""
for y=0,9 do
  for x=0,9 do
    code_to_insert = code_to_insert .. "uniform vec4 uLocationTracker_" .. x .. "_" .. y .. ";\n"
  end
end
code_to_insert = code_to_insert .. "uniform vec4 uLocationTracker_player_pos;\n"
code_to_insert = code_to_insert .. "uniform vec4 uLocationTracker_sizes;\n"
code_to_insert = code_to_insert .. "uniform vec4 uLocationTracker_minimap_position;\n"
content = string.insert(content, code_to_insert .. "\n\n", insertion_point + string.len(string_to_look_for))

-- Insert the draw_rect function before void main()
string_to_look_for = "void main()"
insertion_point = string.find(content, string_to_look_for)
code_to_insert = [[
vec3 draw_rect(vec4 start_and_end_pixels, vec3 draw_color, vec3 color, vec2 screen_size, vec2 tex_coord) {
  // Flip the coordinates so we start off in the top left corner
  tex_coord.y = 1.0 - tex_coord.y;
  // vec4 rect = vec4(start_and_end_pixels.xy / screen_size, start_and_end_pixels.zw / screen_size);
  vec4 rect = start_and_end_pixels / screen_size.xyxy;
  vec2 hv = step(rect.xy, tex_coord) * step(tex_coord, rect.zw);
  float onOff = hv.x * hv.y;

  return mix(color, draw_color, onOff);
}
]]
content = string.insert(content, code_to_insert .. "\n", insertion_point + string.len(string_to_look_for) - 115)

-- Disable liquid refraction at minimap location
string_to_look_for = "liquid_distortion_offset *= step( SHADING_LIQUID_BITS_ALPHA, extra_data_at_liquid_offset.a );"
insertion_point = string.find(content, string_to_look_for, 1, true)
code_to_insert = [[
vec2 tc = tex_coord;
tc.y = 1.0 - tc.y;
vec4 rect = vec4(uLocationTracker_minimap_position.xy - vec2(5.0), uLocationTracker_minimap_position.xy + 11.0 * uLocationTracker_sizes.zw) / uLocationTracker_sizes.xyxy;
vec2 hv = step(rect.xy, tc) * step(tc, rect.zw);
float onOff = hv.x * hv.y;
liquid_distortion_offset *= 1.0 - onOff;
]]
content = string.insert(content, code_to_insert .. "\n", insertion_point + string.len(string_to_look_for) + 1)

-- Location tracker drawing
string_to_look_for = "color += LOW_HEALTH_INDICATOR_COLOR * a * low_health_indicator_alpha;\r\n}"
insertion_point = string.find(content, string_to_look_for, 1, true)
code_to_insert = [[
	vec2 pos;
	vec4 start_and_end_pixels;
	vec3 draw_color;
]]
for y=0,9 do
  for x=0,9 do
    code_to_insert = code_to_insert .. [[
  pos = vec2(]]..x..[[.0, ]]..y..[[.0);
  start_and_end_pixels = vec4(uLocationTracker_minimap_position.xy + pos * uLocationTracker_sizes.zw, uLocationTracker_minimap_position.xy + (pos + 1.0) * uLocationTracker_sizes.zw);
  draw_color = uLocationTracker_]]..x..[[_]]..y..[[.rgb;
  color = draw_rect(start_and_end_pixels, draw_color, color, uLocationTracker_sizes.xy, tex_coord);

]]
  end
end
-- Little position indicator dot
code_to_insert = code_to_insert .. [[

	pos = vec2(5.3, 5.3);	
	pos *= uLocationTracker_sizes.zw;
	pos += uLocationTracker_minimap_position.xy;
	start_and_end_pixels = vec4(pos, pos + 0.33 * uLocationTracker_sizes.zw);
	draw_color = vec3(1.0, 0.0, 0.0);
	color = draw_rect(start_and_end_pixels, draw_color, color, uLocationTracker_sizes.xy, tex_coord);
]]

content = string.insert(content, code_to_insert .. "\n", insertion_point + string.len(string_to_look_for) + 1)

ModTextFileSetContent("data/shaders/post_final.frag", content)
