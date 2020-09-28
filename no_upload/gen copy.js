const fs = require('fs');
const PNG = require('pngjs').PNG;
const assert = require('assert');

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

function setPixel(png, x, y, r, g, b) {
  if(x > png.width) { throw new Error("x > width"); }
  if(y > png.height) { throw new Error("y > height"); }
  const idx = (png.width * y + x) << 2;
  png.data[idx  ] = r;
  png.data[idx+1] = g;
  png.data[idx+2] = b;
  png.data[idx+3] = 255;
}

const columns = 8;
const rows = 14;
const subColumns = 2;
const subRows = 4;
const gap = 2;
const subGap = 1;

const png = new PNG({
  width: columns * subColumns * 3 + ((columns-1) * gap) + ((columns*(subColumns-1)) * subGap),
  height: rows * subRows * 3      + ((rows-1) * gap)    + ((rows*(subRows-1)) * subGap),
  filterType: -1,
});

png.data = png.data.map((val, i) => {
  return i % 4 == 3 && 255 || i % 4 == 0 && 155 || i % 4 == 1 && 122 || 0;
});
// setPixel(png, 0, 0, 255, 0, 0);
// setPixel(png, 1, 0, 255, 0, 255);
// setPixel(png, 2, 0, 255, 0, 0);
// setPixel(png, 0, 1, 255, 0, 0);
// setPixel(png, 1, 1, 255, 0, 255);
// setPixel(png, 2, 1, 255, 0, 0);
// setPixel(png, 0, 2, 255, 0, 0);
// setPixel(png, 1, 2, 255, 0, 255);
// setPixel(png, 2, 2, 255, 0, 0);

const operations = new Map();

function log(func, value) {
  const from_value = value;
  const v = func(value);
  const alread_found = operations.has(v);
  if(alread_found) {
    return { found: true, new_value: v} ;
  } else {
    operations[v] = [{ op: func.name, from_value }];
    return { found: false, new_value: v} ;
  }
}

function flip_log(value) {
  return log(flip, value);
}

function rotate_log(value) {
  return log(rotate, value);
}

let v = 0;

for (let row = 0; row < rows; row++) {
  for (let column = 0; column < columns; column++) {
    v++;
    // let v = row * columns + column;
    operations[v] = [];
    for (let subRow = 0; subRow < subRows; subRow++) {
      if(subRow == subRows / 2) {
        const result = flip_log(v);
        v = result.new_value;
        if(result.found) {
          continue;
        }
      }
      for (let subColumn = 0; subColumn < subColumns; subColumn++) {
        if((subColumn + subRow ) > 0) {
          const result = rotate_log(v);
          v = result.new_value;
          if(result.found) {
            continue;
          }
        }
        for(let y = 0; y < 3; y++) {
          for(let x = 0; x < 3; x++) {
            const yy = row * (subRows * 3 + (subRows-1) * subGap + gap) + subRow * (3 + subGap) + y;
            const xx = column * (subColumns * 3 + (subColumns-1) * subGap + gap) + subColumn * (3 + subGap) + x;

            // const col = (x+y)*(255/4) * f(v++, x, y);
            let col = 200;
            if((x + y) % 2 == 0) {
              col = 255;
            }
            col *= 1-f(v, x, y);
            setPixel(png, xx, yy, col, col, col);
          }
        }
      }
    }
  }
}

console.log(operations[256]);

png.pack().pipe(fs.createWriteStream('newOut2.png'));
