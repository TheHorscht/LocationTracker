function encode_coords(x, y)
  return (x + 0x7FFF) + (y + 0x7FFF) * 0x10000
end

function decode_coords(encoded)
  local x = bit.band(encoded, 0xFFFF)
  local y = bit.band(bit.rshift(encoded, 16), 0xFFFF)
  return x - 0x7FFF, y - 0x7FFF
end

function test(x, y)
  local encoded = encode_coords(x, y)
  local decoded_x, decoded_y = decode_coords(encoded)
  assert(x == decoded_x, string.format("(%d, %d) => (%d, %d)", x, y, decoded_x, decoded_y))
  assert(y == decoded_y, string.format("(%d, %d) => (%d, %d)", x, y, decoded_x, decoded_y))
end
