const fs = require('fs');
const PNG = require('pngjs').PNG;
const assert = require('assert');
const { type } = require('os');

const colors = [
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

  0x24888a,  0x18a0d6,  0x0da899,  0x42244d,  0x99cb4c,  0x99cb4d,  0x99cb4e,  0x99cb4f,
  0x99cb5a,  0x1133F3,  0x89a04b,  0xbaa345,  0x57cace,  0x57dace,

  0x3f55d1, 0x2e99d1, 0x9d99d1, 0x18d6d6, 0x9e4302
]

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
console.log(base_values);

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

png.pack().pipe(fs.createWriteStream('newOut3.png'));
