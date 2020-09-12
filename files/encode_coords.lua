function split_string(inputstr, sep)
  sep = sep or "%s"
  local t= {}
  for str in string.gmatch(inputstr, "([^"..sep.."]+)") do
    table.insert(t, str)
  end
  return t
end

function encode_coords(x, y)
  return x .. "_" .. y
end

function decode_coords(encoded)
  return split_string(encoded, "_")
end
