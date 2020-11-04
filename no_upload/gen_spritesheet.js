const fs = require('fs');
const colors = require('./colors.js');

let content = `<Sprite
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
`;

for(let y=0; y < 15; y++) {
  for(let x=0; x < 20; x++) {
    let color = colors[x + y*20]
    if(color) {
      for(let vy=0; vy <= 12; vy++) {
        for(let vx=0; vx <= 7; vx++) {
          let v = vx + vy * 8
          if(v <= 101) {
            content += `
  <RectAnimation
    name="anim_${color}_${v}"
    pos_x="${x*8*3+vx*3}"
    pos_y="${y*13*3+vy*3}"
    frame_width="3"
    frame_height="3"/>`
          }
        }
      }
    }
  }   
}

content += '</Sprite>'
fs.writeFile('files/color_sprites.xml', content, () => {});
