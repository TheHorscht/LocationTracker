const canvas = document.querySelector('canvas');
// const ctx = canvas.getContext('2d');
const buttonGenerate = document.querySelector('#generate');
const inputPath = document.querySelector('#path');
const inputColors = document.querySelector('#colors');
const spanErrors = document.querySelector('#errors');
const spanInfo = document.querySelector('#info');
const codeElement = document.querySelector('code');

buttonGenerate.addEventListener('click', () => {
  let colors = inputColors.value;
  colors = colors.split(',');
  colors = colors.map(color => color.trim());
  const endIndex = colors.length-1;
  if(colors[endIndex] == '') {
    colors.splice(endIndex, endIndex);
  }
  const correctFormat = colors.reduce((acc, cur) => {
    acc &&= /^[0-9a-fA-F]{6}$/.test(cur);
    return acc;
  }, true);
  if(!correctFormat) {
    spanErrors.innerText = 'Error: Wrong color format, use 3 byte RGB: AABBCC!';
    return;
  } else {
    spanErrors.innerText = '';
  }
  colors = colors.map(color => parseInt(color, 16));
  // "ff00ff, f0f0f0".test(/([0-9a-fA-F]{6},?)+/)
  // console.log(colors);
  const columns = nearest_sqr(colors.length);
  const rows = nearest_sqr(colors.length);
  // This is just the total required unique bitmasks (102) factored out into 6 and 17 so it fills a grid completely
  const subColumns = 6;
  const subRows = 17;

  drawImage(canvas, colors, columns, rows, subColumns, subRows);
  let spritesheet = generateSpritesheet(colors, columns, rows, subColumns, subRows);

  const anchors = document.querySelectorAll('a');
  anchors[0].innerText = 'Download image';
  anchors[0].href = canvas.toDataURL();
  anchors[0].download = 'LocationTracker_colors.png';
  anchors[1].innerText = 'Download spritesheet';
  anchors[1].href = 'data:text/xml;base64,' + btoa(spritesheet);
  anchors[1].download = 'LocationTracker_spritesheet.xml';

  const rootPath = inputPath.value.trim().replace(/\/$/, '');
  spanInfo.innerText = `Download the generated files and place them in ${rootPath}/
Then in your init.lua, place the following code:`;
  codeElement.innerText = `if ModIsEnabled("LocationTracker") then
  local location_tracker = dofile_once("mods/LocationTracker/files/intermod_compat.lua")
  location_tracker.add_colors({
    ${colors.map(color => '0x' + color.toString(16).padStart(6, '0')).join(', ')}
  }, "${rootPath}/LocationTracker_spritesheet.xml")
end`;
  document.querySelectorAll('pre code').forEach((block) => {
    hljs.highlightBlock(block);
  });
})

const get_bit = (val, bit) => (val & (1 << bit)) >> bit;

function rotate(val) {
  const bits = [];
  const new_bits = Array(9).fill(0);
  for(let i = 0; i < 9; i++) {
    bits[i] = get_bit(val, i);
  }
  new_bits[0] = bits[6];
  new_bits[1] = bits[3];
  new_bits[2] = bits[0];
  new_bits[3] = bits[7];
  new_bits[4] = bits[4];
  new_bits[5] = bits[1];
  new_bits[6] = bits[8];
  new_bits[7] = bits[5];
  new_bits[8] = bits[2];

  let result = 0;
  for(let i = 0; i < 9; i++) {
    result += new_bits[i] << i;
  }
  return result;
}

function flip(val) {
  const bits = [];
  const new_bits = Array(9).fill(0);
  for(let i = 0; i < 9; i++) {
    bits[i] = get_bit(val, i);
    new_bits[i] = bits[i];
  }

  new_bits[0] = bits[2];
  new_bits[2] = bits[0];
  new_bits[3] = bits[5];
  new_bits[5] = bits[3];
  new_bits[6] = bits[8];
  new_bits[8] = bits[6];

  let result = 0;
  for(let i = 0; i < 9; i++) {
    result += new_bits[i] << i;
  }
  return result;
}

function f(val, x, y) {
  const bit = (x + y * 3);
  return (val & (1 << bit)) >> bit;
}

function extractRGB(val) {
  return {
    r: (val & 0xff0000) >> 16,
    g: (val & 0x00ff00) >> 8,
    b: (val & 0x0000ff),
  }
}

function setPixel(imageData, x, y, r, g, b) {
  if(x > imageData.width) { throw new Error("x > width"); }
  if(y > imageData.height) { throw new Error("y > height"); }
  const idx = (imageData.width * y + x) * 4;

  imageData.data[idx  ] = r;
  imageData.data[idx+1] = g;
  imageData.data[idx+2] = b;
  imageData.data[idx+3] = 255;
}

function generate_base_values() {
  const operations = new Map();
  
  // Generate all possible values
  for(let i = 0; i < 512; i++) {
    if(!operations.has(i)) { operations.set(i, i); }
    let v = rotate(i);
    if(!operations.has(v)) { operations.set(v, { op: [rotate], i }); }
    v = rotate(v);
    if(!operations.has(v)) { operations.set(v, { op: [rotate,rotate], i }); }
    v = rotate(v);
    if(!operations.has(v)) { operations.set(v, { op: [rotate,rotate,rotate], i }); }
  
    v = flip(i);
    if(!operations.has(v)) { operations.set(v, { op: [flip], i }); }
    v = rotate(v);
    if(!operations.has(v)) { operations.set(v, { op: [flip,rotate], i }); }
    v = rotate(v);
    if(!operations.has(v)) { operations.set(v, { op: [flip,rotate,rotate], i }); }
    v = rotate(v);
    if(!operations.has(v)) { operations.set(v, { op: [flip,rotate,rotate,rotate], i }); }
  }

  const base_values = Array.from(operations).filter(v => typeof v[1] === 'number').map((v, i) => [v[1], i]);
  return base_values;
}

// Returns the smallest square needed to fit n elements in a square grid
const nearest_sqr = n => {
  let l = Math.pow(Math.floor(Math.sqrt(n)), 2);
  l = Math.sqrt(l);
  if(l != Math.sqrt(n) && l < n) {
    l++;
  }
  return l;
}

// const colors = [ 0x7c00ff, 0xff00f0, 0xff0000 ];
// 7c00ff, ff00f0, ff0000

function drawImage(canvas, colors, columns, rows, subColumns, subRows) {
  const base_values = generate_base_values();
  canvas.width = columns * subColumns * 3;
  canvas.height = rows * subRows * 3;
  const ctx = canvas.getContext('2d');
  ctx.fillStyle = '#FF00FF';
  ctx.fillRect(0, 0, canvas.width, canvas.height);
  const imageData = ctx.getImageData(0, 0, canvas.width, canvas.height);
  for(let yyy = 0; yyy < rows; yyy++) {
    for(let xxx = 0; xxx < columns; xxx++) {
      for(let yy = 0; yy < subRows; yy++) {
        for(let xx = 0; xx < subColumns; xx++) {
          
          let base_value = base_values[xx+yy*subColumns];
          if(!base_value) { continue; }
          base_value = base_value[0];
  
          for(let y = 0; y < 3; y++) {
            for(let x = 0; x < 3; x++) {
              const mult = (1-f(base_value, x, y));
              const color = extractRGB(colors[xxx + yyy * columns]);
              color.r = color.r * mult;
              color.g = color.g * mult;
              color.b = color.b * mult;
              setPixel(imageData,
                       xxx * subColumns * 3 + xx * 3 + x,
                       yyy *    subRows * 3 + yy * 3 + y,
                       color.r, color.g, color.b);
            }
          }
        }
      }
    }
  }
  ctx.putImageData(imageData, 0, 0);
}

function generateSpritesheet(colors, columns, rows, subColumns, subRows) {
  let content = `<Sprite
	filename="${inputPath.value.trim().replace(/\/$/, '')}/LocationTracker_colors.png"
	offset_x="0"
	offset_y="0" 
	default_animation="anim_0">
	<RectAnimation
		name="anim_0"
		pos_x="0"
		pos_y="0"
		frame_width="3"
		frame_height="3" />
`;

  for(let y=0; y < rows; y++) {
    for(let x=0; x < columns; x++) {
      let color = colors[x + y * columns]
      if(color) {
        for(let vy=0; vy < subRows; vy++) {
          for(let vx=0; vx < subColumns; vx++) {
            let v = vx + vy * subColumns
            if(v <= 101) {
              content += `
  <RectAnimation
    name="anim_${color}_${v}"
    pos_x="${x*subColumns*3+vx*3}"
    pos_y="${y*subRows*3+vy*3}"
    frame_width="3"
    frame_height="3"/>`
            }
          }
        }
      }
    }   
  }

  content += '</Sprite>';
  return content;
}
