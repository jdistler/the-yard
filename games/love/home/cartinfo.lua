-- The Yard games' cards, from each cart's own info.lua (bundled into home.love as carts/<id>.lua by
-- `cart` home_pack). Home used to keep its own copy of every title, tint, blurb and stat line, and they drifted
-- from the carts (SYSTEM_AUDIT.md D). Now a cart's label says it once, for The Yard and for Home alike.
--
-- An info.lua is a cart's code: its stat() and icon() call the cart library (plural, gfx, pal...). Here it runs
-- in a small sandbox with just enough of that library for stat(); icon() is never called. A label that fails to
-- load is skipped (and logged), so one broken cart can't take Home down.
local M = {}

local function noop() end
local stub = setmetatable({}, {__index = function() return noop end})
local function sandbox()
  return {
    plural = function(n, one, many) return n .. " " .. (n == 1 and one or (many or one .. "s")) end,
    gfx = stub, toon = stub, pal = setmetatable({}, {__index = function() return 0 end}),
    alpha = function(c) return c end,
    sin = math.sin, cos = math.cos, floor = math.floor, abs = math.abs, min = math.min, max = math.max,
    sqrt = math.sqrt, pi = math.pi, math = math, string = string, table = table,
    tostring = tostring, tonumber = tonumber, pairs = pairs, ipairs = ipairs, type = type,
  }
end

local function sentence(s)
  s = tostring(s or "")
  if s == "" then return s end
  s = s:sub(1, 1):upper() .. s:sub(2)
  if not s:match("[%.!?]$") then s = s .. "." end
  return s
end

-- Every non-system cart, in the carts' own order: {id, title, tint, blurb, band, native, save, stat}.
function M.list(log)
  local out = {}
  local ok_dir, names = pcall(love.filesystem.getDirectoryItems, "carts")
  for _, f in ipairs(ok_dir and names or {}) do
    local id = f:match("^([a-z0-9_-]+)%.lua$")
    if id then
      local src = love.filesystem.read("carts/" .. f)
      local fn = src and loadstring(src, "=carts/" .. f)
      local ok, info = false, nil
      if fn then
        setfenv(fn, sandbox())
        ok, info = pcall(fn)
      end
      if ok and type(info) == "table" and not info.system and info.title then
        out[#out + 1] = {id = id, title = tostring(info.title):upper(), tint = info.tint or 0xffffff,
                         blurb = sentence(info.blurb), band = info.band, native = info.native,
                         save = type(info.save) == "string" and info.save or id, order = info.order or 999,
                         stat = info.stat}
      elseif log and not (ok and type(info) == "table" and info.system) then
        log("cart label " .. f .. " skipped: " .. tostring(info))
      end
    end
  end
  table.sort(out, function(a, b) if a.order ~= b.order then return a.order < b.order end return a.id < b.id end)
  return out
end

-- The card's stat line from the cart's save file text, as The Yard shows it (upper case), or nil.
function M.stat(g, sav_text)
  if not g.stat or not sav_text then return nil end
  local s = {}
  for k, v in sav_text:gmatch("([%w_-]+) ([%w_%.%-]+)") do s[k] = tonumber(v) or v end
  local ok, line = pcall(g.stat, s)
  if ok and type(line) == "string" and line ~= "" then return line:upper() end
  return nil
end

return M
