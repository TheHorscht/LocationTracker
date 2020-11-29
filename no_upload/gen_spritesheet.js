const fs = require('fs');

let content = `<Sprite
	filename="mods/LocationTracker/files/biome_colors_big.png"
	offset_x="0"
	offset_y="0" 
	default_animation="anim_0">
	<RectAnimation
		name="anim_999"
		pos_x="18"
    pos_y="36"
		frame_width="9"
		frame_height="9"
    frame_count="1"
    frame_wait="5"
    frames_per_row="1"
    loop="0" />
`;

      for(let vy=0; vy <= 12; vy++) {
        for(let vx=0; vx <= 7; vx++) {
          let v = vx + vy * 8
          if(v <= 101) {
            content += `
  <RectAnimation
    name="anim_${v}"
    pos_x="${vx*9}"
    pos_y="${vy*9}"
    frame_width="9"
    frame_height="9"
    frame_count="1"
    frame_wait="5"
    frames_per_row="1"
    loop="0"/>`
          }
        }
      }

content += '</Sprite>'
fs.writeFile('files/color_sprites.xml', content, () => {});
