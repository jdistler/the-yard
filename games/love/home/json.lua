-- A small JSON reader (objects, arrays, strings with escapes, numbers, true/false/null -> nil): enough for
-- ESPN's public team endpoint (utgame.lua). json.decode(s) -> value, or nil and an error.
local J = {}
local sub, byte, find, char = string.sub, string.byte, string.find, string.char

local function skip(s, i)
  local _, e = find(s, "^[ \n\r\t]*", i)
  return e + 1
end

local decode_value
local ESC = {['"'] = '"', ["\\"] = "\\", ["/"] = "/", b = "\b", f = "\f", n = "\n", r = "\r", t = "\t"}

local function decode_string(s, i)
  local out, j = {}, i + 1
  while true do
    local k = find(s, '["\\]', j)
    if not k then error("unterminated string") end
    out[#out + 1] = sub(s, j, k - 1)
    if sub(s, k, k) == '"' then return table.concat(out), k + 1 end
    local e = sub(s, k + 1, k + 1)
    if e == "u" then
      local cp = tonumber(sub(s, k + 2, k + 5), 16) or 63
      if cp < 0x80 then out[#out + 1] = char(cp)
      elseif cp < 0x800 then out[#out + 1] = char(0xC0 + math.floor(cp / 64), 0x80 + cp % 64)
      else out[#out + 1] = char(0xE0 + math.floor(cp / 4096), 0x80 + math.floor(cp / 64) % 64, 0x80 + cp % 64) end
      j = k + 6
    else
      out[#out + 1] = ESC[e] or e
      j = k + 2
    end
  end
end

decode_value = function(s, i)
  i = skip(s, i)
  local c = sub(s, i, i)
  if c == "{" then
    local t = {}
    i = skip(s, i + 1)
    if sub(s, i, i) == "}" then return t, i + 1 end
    while true do
      local k
      k, i = decode_string(s, skip(s, i))
      i = skip(s, i)
      if sub(s, i, i) ~= ":" then error("expected : at " .. i) end
      t[k], i = decode_value(s, i + 1)
      i = skip(s, i)
      local d = sub(s, i, i)
      if d == "}" then return t, i + 1 end
      if d ~= "," then error("expected , at " .. i) end
      i = i + 1
    end
  elseif c == "[" then
    local t = {}
    i = skip(s, i + 1)
    if sub(s, i, i) == "]" then return t, i + 1 end
    while true do
      local v
      v, i = decode_value(s, i)
      t[#t + 1] = v
      i = skip(s, i)
      local d = sub(s, i, i)
      if d == "]" then return t, i + 1 end
      if d ~= "," then error("expected , at " .. i) end
      i = i + 1
    end
  elseif c == '"' then
    return decode_string(s, i)
  elseif find(s, "^true", i) then return true, i + 4
  elseif find(s, "^false", i) then return false, i + 5
  elseif find(s, "^null", i) then return nil, i + 4
  else
    local _, e = find(s, "^-?[%d%.eE%+%-]+", i)
    if not e then error("unexpected '" .. c .. "' at " .. i) end
    return tonumber(sub(s, i, e)), e + 1
  end
end

function J.decode(s)
  local ok, v = pcall(decode_value, s, 1)
  if ok then return v end
  return nil, v
end

return J
