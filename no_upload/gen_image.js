const fs = require('fs');
const PNG = require('pngjs').PNG;
const assert = require('assert');
const { type } = require('os');
const colors = require('./colors.js');

function print_value(value) {
  console.log(value + ":");
  for(let y = 0; y < 3; y++) {
    let v = '';
    for(let x = 0; x < 3; x++) {
      if(value & (1 << (y*3+x))) {
        v += ' X ';
      } else {
        v += ' _ ';
      }
    }
    console.log(v);
  }
}


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

function setPixel(png, x, y, r, g, b) {
  if(x > png.width) { throw new Error("x > width"); }
  if(y > png.height) { throw new Error("y > height"); }
  const idx = (png.width * y + x) << 2;
  png.data[idx  ] = r;
  png.data[idx+1] = g;
  png.data[idx+2] = b;
  png.data[idx+3] = 255;
}

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

// const base_values = Array.from(operations).filter(v => typeof v[1] === 'number').map(v => v[1]);
const base_values = Array.from(operations).filter(v => typeof v[1] === 'number').map((v, i) => [v[1], i]);
// console.log(base_values);

let data = 'return {\n\tindexes = {' + base_values.map(v => `[${v[0]}]=${v[1]}`).join(',') + '},\n';
for(let [i, op] of operations) {
  if(typeof op == 'object') {
    const requiredOps = [0, 0];
    for(let v in op.op) {
      if(op.op[v] == flip) {
        requiredOps[0]++;
      } else {
        requiredOps[1]++;
      }
    }
    data += `\t[${i}]={op={${requiredOps[0]},${requiredOps[1]}},from=${op.i}},\n`;
    // data += `\t[${i}]={op={${requiredOps[0]},${requiredOps[1]}},from=${base_values[op.i]}},\n`;
  }
}
data += `}\n`;
fs.writeFile("files/permutation_data.lua", data, () => {});

const columns = 8;
const rows = 14;
const subColumns = 2;
const subRows = 4;
const gap = 2;
const subGap = 1;

const png = new PNG({
  width: 20 * 8 * 3,
  height: 15 * 13 * 3,
  filterType: -1,
});

png.data = png.data.map((val, i) => {
  return i % 4 == 3 && 255 || i % 4 == 0 && 255 || i % 4 == 1 && 0 || i % 4 == 2 && 255 || 0;
});

for(let yyy = 0; yyy < 15; yyy++) {
  for(let xxx = 0; xxx < 20; xxx++) {
    for(let yy = 0; yy < 13; yy++) {
      for(let xx = 0; xx < 8; xx++) {
        
        let base_value = base_values[xx+yy*8];
        if(!base_value) { continue; }
        base_value = base_value[0];

        for(let y = 0; y < 3; y++) {
          for(let x = 0; x < 3; x++) {
            const mult = (1-f(base_value, x, y));
            const color = extractRGB(colors[xxx + yyy * 20]);
            color.r = color.r * mult;
            color.g = color.g * mult;
            color.b = color.b * mult;
            // const color = (1-f(base_value, x, y)) * colors[xxx + yyy * 20];
            setPixel(png, xxx * 8 * 3 + xx * 3 + x,
                          yyy * 13 * 3 + yy * 3 + y, color.r, color.g, color.b);
          }
        }
      }
    }
  }
}

png.pack().pipe(fs.createWriteStream('files/biome_colors.png'));
