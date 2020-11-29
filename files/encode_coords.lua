function encode_coords(x, y)
  return x + y * 0x10000
end

function decode_coords(encoded)
  local x = bit.band(encoded, 0xFFFF)
  local y = bit.band(bit.rshift(encoded, 16), 0xFFFF)
  return x, y
end
