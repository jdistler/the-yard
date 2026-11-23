-- Bake's pictures: the cast (drawn as in Tea, Band and Garden), the treats (four kinds, any flavour, any
-- frosting, any topping, one painter for the counter, the window and the wish bubble), the oven and bowl, the
-- tools, the tray of choices and the bakery itself.
-- main.lua owns the rules; everything here only draws. No rnd() in here: a hash of the frame instead.
local P = {}

local C = {
  CREAM = 0xfff6ea, GOLD = 0xf2c14e, MINT = 0x7ec8c3, LILAC = 0xb9a0e8, ROOF = 0xe86b9a, TEA = 0xc9865a,
  ORANGE = 0xf29a3a, GREY = 0x8a8f9c, INK = 0x3a2a44, WHITE = 0xfffcf8, SKY = 0x8ec6ff, CASTLE = 0xf4b6d0,
  BLUSH = alpha(0xff8fb0, 120), WOOD = 0xc88450, WOODL = 0xe4a46a, NIGHT = 0x2a1838,
  LINER = 0xffdce8, STEEL = 0xdfe6ee, RED = 0xe84855,
}
P.C = C
local INK = C.INK
local STRIPES = {0xf2c14e, 0xe86b9a, 0x7ec8c3, 0xb9a0e8}
P.STRIPES = STRIPES
local BODY = {C.ORANGE, C.GREY, C.WHITE, C.CREAM}
local DARK = {0xd87a20, 0x666a78, 0xe8dccc, C.ORANGE}
local RAINBOW = {0xe86b9a, 0xf29a3a, 0xf2c14e, 0x7ec8c3, 0xb9a0e8, 0x8ac8ff}
P.RAINBOW = RAINBOW

-- Garden's six flower colours and their words (the bouquet is a word of these joined by "-").
P.COLS = {0xf47eb2, 0xffc83a, 0x6ab8ff, 0xb998f0, 0x68d8b8, 0xff8a6a}
P.CNAME = {"rose", "gold", "sky", "lilac", "mint", "coral"}

-- The treat words: kind_flavour_frosting_topping. Kinds open at 0, 3, 8 and 15 treats served.
P.KIND = {"cupcake", "cookie", "layer", "castle"}
P.UNLOCK = {0, 3, 8, 15}
P.FLAV = {"berry", "honey", "cocoa", "cloud"}
P.FLAVC = {0xc9507a, 0xf6cf74, 0x9a6444, 0xfff1d6}
P.FROST = {"pink", "lemon", "sky", "lilac", "mint"}
P.FROSTC = {0xff8fbc, 0xffe36a, 0x7ec8ff, 0xb998f0, 0x6fe0b8}
P.TOP = {"cherry", "star", "heart", "strawberry"}
P.KS = {1.4, 1.5, 1.2, 1.05}          -- scale at the counter
P.SHS = {0.56, 0.58, 0.5, 0.42}      -- scale in the window
P.TOPY = {76, 22, 68, 118}            -- where the topping sits, at scale 1

local function fr() return game.frame end
local function fr() return game.frame end
-- A small deterministic scatter, so drawing never touches the game's random numbers.
local function hash(n)
  local v = sin(n * 12.9898) * 43758.5453
  return v - floor(v)
end
P.hash = hash
local function paw(x, y, col, r)
  gfx.circle_o(x, y, r or 5, col, INK, 1.5)
end

-- ------------------------------------------------------------------ the cats, as in Tea

-- who: 1 Pip, 2 Moth, 3 Pearl, 4 Nib. mood: "sleep", "happy" or nil (awake). lx: where the eyes look.
function P.cat(who, cx, cy, s, mood, lx)
  local body, dark = BODY[who], DARK[who]
  local r = (who == 4 and 20 or 27) * s
  local blink = ((fr() + (who - 1) * 47) % 200) < 7
  local tail = sin(fr() * 0.07 + who - 1) * 0.6
  local ear = who == 2 and 1.45 or 1.25
  toon(function()
    toon.line(cx + r * 0.7, cy + r * 1.95, cx + r * 1.4, cy + r * 1.95, 8 * s, body)
    toon.line(cx + r * 1.4, cy + r * 1.95, cx + r * 1.62 + tail * r * 0.15, cy + r * 1.62, 8 * s, body)
    toon.circle(cx + r * 1.62 + tail * r * 0.15, cy + r * 1.58, 4.5 * s, who == 3 and C.WHITE or dark)
    toon.ellipse(cx, cy + r * 1.35, r * 1.05, r * 0.9, body)
    toon.tri(cx - r * 0.95, cy - r * 0.2, cx - r * 0.75, cy - r * ear, cx - r * 0.2, cy - r * 0.8, body)
    toon.tri(cx + r * 0.95, cy - r * 0.2, cx + r * 0.75, cy - r * ear, cx + r * 0.2, cy - r * 0.8, body)
    toon.ellipse(cx, cy, r, r * 0.92, body)
  end, 2.5, INK)
  gfx.tri(cx - r * 0.78, cy - r * 0.35, cx - r * 0.7, cy - r * 1.0, cx - r * 0.38, cy - r * 0.68, 0xffb8c8)
  gfx.tri(cx + r * 0.78, cy - r * 0.35, cx + r * 0.7, cy - r * 1.0, cx + r * 0.38, cy - r * 0.68, 0xffb8c8)
  if who == 2 then
    for k = -1, 1 do gfx.line(cx + k * r * 0.25, cy - r * 0.85, cx + k * r * 0.2, cy - r * 0.5, 3 * s, dark) end
  end
  if who == 1 then gfx.ellipse(cx, cy + r * 0.38, r * 0.55, r * 0.4, C.CREAM) end
  if who == 4 then
    gfx.ellipse(cx - r * 0.45, cy - r * 0.35, r * 0.3, r * 0.35, C.ORANGE)
    gfx.circle(cx + r * 0.3, cy + r * 1.3, r * 0.35, C.ORANGE)
  end
  local ex, ey = r * 0.38, cy - r * 0.08
  if mood == "happy" then
    for k = -1, 1, 2 do
      gfx.line(cx + k * ex - 5 * s, ey + 2, cx + k * ex, ey - 3 * s, 2.5 * s, INK)
      gfx.line(cx + k * ex, ey - 3 * s, cx + k * ex + 5 * s, ey + 2, 2.5 * s, INK)
    end
  elseif mood == "sleep" then
    for k = -1, 1, 2 do
      gfx.line(cx + k * ex - 5 * s, ey - 1, cx + k * ex, ey + 2.5 * s, 2.2 * s, INK)
      gfx.line(cx + k * ex, ey + 2.5 * s, cx + k * ex + 5 * s, ey - 1, 2.2 * s, INK)
    end
  elseif blink then
    gfx.line(cx - ex - 5 * s, ey, cx - ex + 5 * s, ey, 2.5 * s, INK)
    gfx.line(cx + ex - 5 * s, ey, cx + ex + 5 * s, ey, 2.5 * s, INK)
  else
    local look = clamp(((lx or cx) - cx) * 0.02, -2.5, 2.5)
    for k = -1, 1, 2 do
      gfx.ellipse(cx + k * ex + look, ey, 5 * s, 6.5 * s, INK)
      gfx.circle(cx + k * ex + look + 1.5 * s, ey - 2.5 * s, 1.8 * s, C.WHITE)
    end
  end
  gfx.ellipse(cx - r * 0.6, cy + r * 0.3, 5 * s, 3 * s, C.BLUSH)
  gfx.ellipse(cx + r * 0.6, cy + r * 0.3, 5 * s, 3 * s, C.BLUSH)
  gfx.tri(cx - 3.5 * s, cy + r * 0.2, cx + 3.5 * s, cy + r * 0.2, cx, cy + r * 0.32, C.ROOF)
  local happy = mood == "happy"
  local my, mw, dip = cy + r * 0.36, (happy and 5.5 or 4.5) * s, (happy and 4 or 3) * s
  gfx.line(cx, my, cx - mw * 0.5, my + dip, 1.6 * s, INK)
  gfx.line(cx - mw * 0.5, my + dip, cx - mw, my + dip * 0.2, 1.6 * s, INK)
  gfx.line(cx, my, cx + mw * 0.5, my + dip, 1.6 * s, INK)
  gfx.line(cx + mw * 0.5, my + dip, cx + mw, my + dip * 0.2, 1.6 * s, INK)
  if happy then gfx.ellipse(cx, my + dip * 0.9, 2.2 * s, 1.6 * s, 0xff8fa8) end
  for k = -1, 1, 2 do
    gfx.line(cx + k * r * 0.35, cy + r * 0.3, cx + k * r * 1.05, cy + r * 0.2, 1, alpha(INK, 160))
    gfx.line(cx + k * r * 0.35, cy + r * 0.36, cx + k * r * 1.05, cy + r * 0.42, 1, alpha(INK, 160))
  end
  if who == 3 then
    gfx.tri(cx + r * 0.35, cy - r * 0.75, cx + r * 0.75, cy - r * 0.95, cx + r * 0.7, cy - r * 0.5, C.GOLD)
    gfx.tri(cx + r * 0.35, cy - r * 0.75, cx + r * 0.05, cy - r * 1.0, cx + r * 0.1, cy - r * 0.55, C.GOLD)
    gfx.circle_o(cx + r * 0.38, cy - r * 0.75, 3.5 * s, C.GOLD, INK, 1.5)
  end
end

-- The Unicorn from the front, same white, gold horn and four-stripe mane as Tea's. x, y: the head's middle.
function P.unicorn(x, y, s, mood, lx)
  local blink = (fr() % 210) < 7
  toon(function()
    -- Wings, tucked behind the shoulders.
    for side = -1, 1, 2 do
      for k = 0, 2 do
        toon.circle(x + side * (38 + k * 9) * s, y + (30 - k * 9) * s, (11 - k * 2) * s, k == 2 and C.LILAC or C.WHITE)
      end
    end
    -- Mane falls down both sides, one stripe each.
    for side = -1, 1, 2 do
      for k = 0, 3 do
        local sx = x + side * (20 + k * 4) * s
        toon.line(sx, y - 14 * s, sx + side * (3 + k) * s, y + 46 * s, 6 * s, STRIPES[k + 1])
      end
    end
    -- Tail swish behind.
    toon.ellipse(x, y + 52 * s, 34 * s, 30 * s, C.WHITE)
    toon.ellipse(x, y, 24 * s, 26 * s, C.WHITE)
    toon.tri(x - 20 * s, y - 14 * s, x - 17 * s, y - 38 * s, x - 6 * s, y - 22 * s, C.WHITE)
    toon.tri(x + 20 * s, y - 14 * s, x + 17 * s, y - 38 * s, x + 6 * s, y - 22 * s, C.WHITE)
    toon.tri(x - 6 * s, y - 22 * s, x, y - 62 * s, x + 6 * s, y - 22 * s, C.GOLD)
  end, 2.5 * s, INK)
  gfx.line(x - 3.5 * s, y - 34 * s, x + 2.5 * s, y - 38 * s, 1.6 * s, 0xd8a03a)
  gfx.line(x - 3 * s, y - 44 * s, x + 2 * s, y - 48 * s, 1.6 * s, 0xd8a03a)
  gfx.tri(x - 16 * s, y - 20 * s, x - 15 * s, y - 33 * s, x - 9 * s, y - 23 * s, 0xffb8c8)
  gfx.tri(x + 16 * s, y - 20 * s, x + 15 * s, y - 33 * s, x + 9 * s, y - 23 * s, 0xffb8c8)
  -- Forelock: the four mane colours across the forehead.
  for k = 0, 3 do gfx.circle_o(x - 12 * s + k * 8 * s, y - 20 * s + (k % 2) * 3 * s, 5 * s, STRIPES[k + 1], INK, 1.5) end
  local ex, ey = 9 * s, y - 2 * s
  if mood == "happy" then
    for k = -1, 1, 2 do
      gfx.line(x + k * ex - 5 * s, ey + 2, x + k * ex, ey - 3 * s, 2.5 * s, INK)
      gfx.line(x + k * ex, ey - 3 * s, x + k * ex + 5 * s, ey + 2, 2.5 * s, INK)
    end
  elseif mood == "sleep" then
    for k = -1, 1, 2 do
      gfx.line(x + k * ex - 5 * s, ey - 1, x + k * ex, ey + 2.5 * s, 2.2 * s, INK)
      gfx.line(x + k * ex, ey + 2.5 * s, x + k * ex + 5 * s, ey - 1, 2.2 * s, INK)
    end
  elseif blink then
    gfx.line(x - ex - 5 * s, ey, x - ex + 5 * s, ey, 2.5 * s, INK)
    gfx.line(x + ex - 5 * s, ey, x + ex + 5 * s, ey, 2.5 * s, INK)
  else
    local look = clamp(((lx or x) - x) * 0.02, -2.5, 2.5)
    for k = -1, 1, 2 do
      gfx.ellipse(x + k * ex + look, ey, 5 * s, 6.5 * s, INK)
      gfx.circle(x + k * ex + look + 1.5 * s, ey - 2.5 * s, 1.8 * s, C.WHITE)
    end
  end
  gfx.ellipse(x - 15 * s, y + 8 * s, 5 * s, 3 * s, C.BLUSH)
  gfx.ellipse(x + 15 * s, y + 8 * s, 5 * s, 3 * s, C.BLUSH)
  gfx.ellipse(x, y + 14 * s, 11 * s, 8 * s, 0xffe4ee)
  gfx.circle(x - 4 * s, y + 13 * s, 1.4 * s, alpha(INK, 190))
  gfx.circle(x + 4 * s, y + 13 * s, 1.4 * s, alpha(INK, 190))
  local happy = mood == "happy"
  local my = y + 18 * s
  gfx.line(x - 4 * s, my, x, my + (happy and 4 or 2.5) * s, 1.6 * s, INK)
  gfx.line(x, my + (happy and 4 or 2.5) * s, x + 4 * s, my, 1.6 * s, INK)
end

-- ------------------------------------------------------------------ party hat and reaction overlays

-- A paper party hat on the Unicorn (x, y: her head's middle, as in P.unicorn).
function P.hat(x, y, s)
  toon(function()
    toon.tri(x - 24 * s, y - 20 * s, x - 6 * s, y - 28 * s, x - 17 * s, y - 56 * s, C.ROOF)
  end, 2 * s, INK)
  gfx.line(x - 21 * s, y - 28 * s, x - 11 * s, y - 33 * s, 3 * s, C.GOLD)
  gfx.line(x - 19 * s, y - 38 * s, x - 13 * s, y - 41 * s, 3 * s, C.GOLD)
  gfx.circle_o(x - 17 * s, y - 57 * s, 4.5 * s, C.GOLD, INK, 1.5)
end

-- Pip licks his lips: a pink tongue sweeping side to side under the nose. cx, cy: head middle, r: head radius.
function P.tongue(cx, cy, r, t)
  local tx = cx + sin(t * 0.35) * r * 0.45
  gfx.ellipse_o(tx, cy + r * 0.66, r * 0.17, r * 0.24, 0xff7a9a, INK, 1.6)
end

-- Moth's whiskers wobble big and slow.
function P.whiskers(cx, cy, r, t)
  for k = -1, 1, 2 do
    for j = 0, 1 do
      local a = sin(t * 0.45 + j * 1.3) * 0.55
      local x0, y0 = cx + k * r * 0.32, cy + r * 0.32 + j * r * 0.16
      gfx.line(x0, y0, x0 + k * r * 1.5 * cos(a), y0 + r * 1.5 * sin(a) - j * 2, 2.6, INK)
    end
  end
end

-- ------------------------------------------------------------------ toppings

local function bloom(x, y, r, col)
  gfx.circle_o(x, y, r * 1.5, col, INK, 1.4)
  for k = 0, 4 do
    local a = k * 1.2566 - 1.5708
    gfx.circle_o(x + cos(a) * r, y + sin(a) * r, r * 0.72, col, INK, 1.3)
  end
  gfx.circle_o(x, y, r * 0.62, 0xffe36a, INK, 1.2)
end

-- A topping sitting on a surface at x, y (its bottom). id 1..5: cherry, star, heart, strawberry, flower.
function P.topping(id, x, y, s, fc)
  local o = max(1.1, 1.7 * s)
  if id == 1 then
    gfx.line(x + 1 * s, y - 12 * s, x + 6 * s, y - 24 * s, 2.2 * s, 0x4a9a4a)
    gfx.circle_o(x, y - 7 * s, 8 * s, C.RED, INK, o)
    gfx.circle(x - 3 * s, y - 10 * s, 2.4 * s, alpha(C.WHITE, 200))
  elseif id == 2 then
    gfx.star(x, y - 10 * s, 13 * s, 0, INK)
    gfx.star(x, y - 10 * s, 10.5 * s, 0, C.GOLD)
  elseif id == 3 then
    gfx.heart(x, y - 9 * s, 17 * s, INK)
    gfx.heart(x, y - 9 * s, 13.5 * s, 0xff5a8a)
    gfx.circle(x - 4 * s, y - 12 * s, 2 * s, alpha(C.WHITE, 190))
  elseif id == 4 then
    gfx.ellipse_o(x, y - 8 * s, 8 * s, 9.5 * s, C.RED, INK, o)
    gfx.tri(x - 6 * s, y - 15 * s, x + 6 * s, y - 15 * s, x, y - 19 * s, 0x4aa84a)
    for k = -1, 1 do gfx.circle(x + k * 3.2 * s, y - 8 * s + (k % 2) * 3 * s, 1 * s, C.CREAM) end
  else
    bloom(x, y - 9 * s, 5 * s, P.COLS[fc > 0 and fc or 1])
  end
end

-- ------------------------------------------------------------------ the treats

-- Every kind is drawn from its bottom middle (x, y) at scale s. sy squashes the height while it rises in the oven.
-- The shapes are one toon figure (one outline); the details are drawn on top. Parameters travel in these locals
-- so nothing is allocated per frame (toon takes a function).
local tk, tx, ty, ts, tsy, tfl, tfc, tfk = 1, 0, 0, 1, 1, 0, 0, 0

local function c01(v) return v < 0 and 0 or (v > 1 and 1 or v) end

local function shapes_cupcake()
  local x, y, s, sy = tx, ty, ts, tsy
  toon.poly({x - 27 * s, y - 27 * sy, x + 27 * s, y - 27 * sy, x + 19 * s, y, x - 19 * s, y}, C.LINER)
  toon.ellipse(x, y - 29 * sy, 30 * s, 15 * sy, tfl)
  local t1, t2, t3 = c01(tfk * 3), c01(tfk * 3 - 1), c01(tfk * 3 - 2)
  if t1 > 0 then toon.ellipse(x, y - 40 * sy, 33 * s * t1, 12 * sy * t1, tfc) end
  if t2 > 0 then toon.ellipse(x, y - 52 * sy, 25 * s * t2, 10 * sy * t2, tfc) end
  if t3 > 0 then
    toon.ellipse(x, y - 62 * sy, 16 * s * t3, 8 * sy * t3, tfc)
    toon.tri(x - 8 * s * t3, y - 63 * sy, x + 8 * s * t3, y - 63 * sy, x + 3 * s, y - (63 + 16 * t3) * sy, tfc)
  end
end

local function shapes_cookie()
  local x, y, s, sy = tx, ty, ts, tsy
  toon.ellipse(x, y - 8 * sy, 46 * s, 18 * sy, shade(tfl, 0.82))
  toon.ellipse(x, y - 13 * sy, 46 * s, 18 * sy, tfl)
  if tfk > 0 then
    local t = c01(tfk)
    toon.ellipse(x, y - 15 * sy, 36 * s * t, 13 * sy * t, tfc)
    for k = 0, 9 do
      local a = k * 0.6283
      toon.circle(x + cos(a) * 35 * s * t, y - 15 * sy + sin(a) * 12.5 * sy * t, 5.5 * s * t, tfc)
    end
  end
end

local function shapes_layer()
  local x, y, s, sy = tx, ty, ts, tsy
  toon.rrect(x - 46 * s, y - 32 * sy, 92 * s, 32 * sy, 7 * s, tfl)
  toon.rrect(x - 33 * s, y - 60 * sy, 66 * s, 29 * sy, 7 * s, tfl)
  if tfk > 0 then
    local t = c01(tfk)
    toon.ellipse(x, y - 61 * sy, 34 * s * t, 9 * sy * t, tfc)
    for k = -3, 3 do
      toon.circle(x + k * 10.5 * s, y - 58 * sy, 5.5 * s * t, tfc)
      toon.rrect(x + k * 10.5 * s - 3.6 * s, y - 58 * sy, 7.2 * s, (6 + (k % 2 == 0 and 7 or 2)) * sy * t, 3 * s, tfc)
    end
    if tfk > 0.5 then
      local u = c01((tfk - 0.5) * 2)
      for k = -4, 4 do
        toon.circle(x + k * 10.5 * s, y - 31 * sy, 5.2 * s * u, tfc)
      end
    end
  end
end

local function shapes_castle()
  local x, y, s, sy = tx, ty, ts, tsy
  local roof = mix(shade(tfl, 0.78), tfc, c01(tfk * 2))
  toon.rrect(x - 54 * s, y - 30 * sy, 108 * s, 30 * sy, 5 * s, tfl)
  toon.rrect(x - 58 * s, y - 62 * sy, 26 * s, 58 * sy, 4 * s, tfl)
  toon.rrect(x + 32 * s, y - 62 * sy, 26 * s, 58 * sy, 4 * s, tfl)
  toon.rrect(x - 22 * s, y - 80 * sy, 44 * s, 70 * sy, 4 * s, tfl)
  toon.tri(x - 63 * s, y - 62 * sy, x - 27 * s, y - 62 * sy, x - 45 * s, y - 90 * sy, roof)
  toon.tri(x + 27 * s, y - 62 * sy, x + 63 * s, y - 62 * sy, x + 45 * s, y - 90 * sy, roof)
  toon.tri(x - 27 * s, y - 80 * sy, x + 27 * s, y - 80 * sy, x, y - 114 * sy, roof)
  if tfk > 0.4 then
    local t = c01((tfk - 0.4) * 1.7)
    for k = -4, 4 do toon.circle(x + k * 12 * s, y - 29 * sy, 5.5 * s * t, tfc) end
  end
end

local SHAPES = {shapes_cupcake, shapes_cookie, shapes_layer, shapes_castle}

-- Sprinkles: 24 fixed places, scattered over a region of each kind (cx, cy, rx, ry at scale 1).
local SPX, SPY, SPA = {}, {}, {}
for i = 1, 24 do
  local a, r = hash(i * 3.1) * 6.2832, sqrt(hash(i * 5.7 + 1))
  SPX[i], SPY[i], SPA[i] = cos(a) * r, sin(a) * r, hash(i * 7.3 + 2) * 3.1416
end
local SPCOL = {0xff7aa8, 0xffd23a, 0x6ab8ff, 0x68d8b8, 0xfffcf8, 0xb998f0}
local SPREG = {{0, -45, 26, 10}, {0, -17, 30, 9}, {0, -59, 28, 6}, {0, -52, 40, 20}}

-- A treat from its bottom middle. kind 1..4, rise 0..1 (0 = flat batter, 1 = baked), fl flavour colour, fc frosting
-- colour, fk 0..1 how much frosting is on, spr 0..3 rounds of sprinkles. Toppings are separate (P.topping).
function P.treat(kind, x, y, s, rise, fl, fc, fk, spr)
  tk, tx, ty, ts, tsy, tfl, tfc, tfk = kind, x, y, s, s * (0.7 + 0.3 * rise), fl, fc or fl, fk or 0
  toon(SHAPES[kind], max(1.4, 2.3 * min(1, s)), INK)
  local sy = tsy
  if kind == 1 then
    for k = -2, 2 do gfx.line(x + k * 9 * s, y - 25 * sy, x + k * 6.5 * s, y - 2 * sy, max(1, 1.4 * s), alpha(INK, 60)) end
    if tfk > 0 then
      gfx.ellipse(x - 12 * s, y - 41 * sy, 9 * s * c01(tfk * 3), 2.5 * sy, alpha(C.WHITE, 120))
      gfx.ellipse(x - 8 * s, y - 53 * sy, 7 * s * c01(tfk * 3 - 1), 2 * sy, alpha(C.WHITE, 120))
    else
      gfx.ellipse(x - 12 * s, y - 33 * sy, 9 * s, 3 * sy, alpha(C.WHITE, 90))
    end
  elseif kind == 2 then
    local a0 = tfk > 0.2 and 0.78 or 0.9
    for k = 0, 6 do
      local a = k * 0.9 + 0.4
      gfx.ellipse_o(x + cos(a) * 46 * s * a0, y - 12 * sy + sin(a) * 18 * sy * a0, 4.3 * s, 3 * sy, 0x5a3a28, INK, 1)
    end
    if tfk > 0 then gfx.ellipse(x - 12 * s, y - 20 * sy, 10 * s, 2.6 * sy, alpha(C.WHITE, 120)) end
  elseif kind == 3 then
    gfx.rect(x - 45 * s, y - 34 * sy, 90 * s, 3.5 * sy, C.CREAM)
    gfx.rect(x - 32 * s, y - 62 * sy, 64 * s, 3.5 * sy, C.CREAM)
    if tfk <= 0 then gfx.ellipse(x - 14 * s, y - 45 * sy, 12 * s, 3 * sy, alpha(C.WHITE, 90)) end
  else
    for k = -1, 1 do
      gfx.rrect_o(x + k * 33 * s - 4 * s, y - 52 * sy, 8 * s, 14 * sy, 4 * s, 0x5a3a48, INK, 1)
    end
    gfx.rrect_o(x - 8 * s, y - 24 * sy, 16 * s, 24 * sy, 8 * s, 0x5a3a48, INK, 1.2)
    gfx.line(x, y - 114 * sy, x, y - 128 * sy, max(1.2, 2 * s), INK)
    gfx.tri(x, y - 128 * sy, x + 14 * s, y - 123 * sy, x, y - 118 * sy, C.RED)
  end
  if spr and spr > 0 then
    local g = SPREG[kind]
    for i = 1, spr * 8 do
      local px, py = x + (g[1] + SPX[i] * g[3]) * s, y + (g[2] + SPY[i] * g[4]) * sy
      local a = SPA[i]
      gfx.line(px, py, px + cos(a) * 3.4 * s, py + sin(a) * 3.4 * s, max(1.2, 2.2 * s), SPCOL[i % 6 + 1])
    end
  end
end

-- The topping's place on a kind, with a lift for hovering and dropping.
function P.treat_top(kind, id, x, y, s, rise, fc, lift)
  P.topping(id, x, y - P.TOPY[kind] * s * (0.7 + 0.3 * rise) - (lift or 0), s * 0.95, fc)
end

-- A finished treat painted once per key (window, wish bubble). Scale s, drawn with its bottom middle at x, y.
local sk, ss, sfl, sfc, stp, sfcol, sspr, sw, sh = 1, 1, 0, 0, 0, 0, 0, 0, 0
local function stamp_paint()
  P.treat(sk, sw / 2, sh - 4, ss, 1, sfl, sfc, 1, sspr)
  if stp > 0 then P.treat_top(sk, stp, sw / 2, sh - 4, ss, 1, sfcol, 0) end
end
-- fl/fc are colours, tp 0..5 (0 none), tcol a garden colour index for the flower.
function P.treat_stamp(key, x, y, kind, s, fl, fc, tp, tcol, spr)
  sk, ss, sfl, sfc, stp, sfcol, sspr = kind, s, fl, fc, tp, tcol, spr or 0
  sw, sh = floor(142 * s) + 10, floor(150 * s) + 12
  -- bake() paints the layer once under the key and costs nothing after (no closure made per frame).
  gfx.blit_key(bake(key, sw, sh, stamp_paint), floor(x - sw / 2), floor(y - (sh - 4)))
end

-- ------------------------------------------------------------------ props

local function disc(x, y, r, col, lit)
  gfx.circle_o(x, y, r, col, INK, 2.5)
  if lit then gfx.ring(x, y, r + 4, 3, C.GOLD) end
end

-- A choice on the tray: what 1 kind 2 flavour 3 frosting 4 topping, which item i, at x, y, big when chosen.
function P.choice(what, i, x, y, k, fcol)
  local r = 24 * k
  if what == 1 then
    gfx.circle_o(x, y, r, 0xfff3f8, INK, 2.5)
    P.treat(i, x, y + 18 * k, P.SHS[i] * 0.78 * k, 1, P.FLAVC[1], P.FROSTC[1], 1, 0)
  elseif what == 2 then
    disc(x, y, r, P.FLAVC[i])
    local c = shade(P.FLAVC[i], 0.78)
    for a = 0, 5 do
      local u = a / 5
      gfx.line(x + cos(u * 5.5) * (4 + u * 14) * k, y + sin(u * 5.5) * (3 + u * 10) * k,
        x + cos((u + 0.2) * 5.5) * (4 + (u + 0.2) * 14) * k, y + sin((u + 0.2) * 5.5) * (3 + (u + 0.2) * 10) * k, 3 * k, c)
    end
    gfx.ellipse(x - 9 * k, y - 11 * k, 6 * k, 3 * k, alpha(C.WHITE, 140))
  elseif what == 3 then
    disc(x, y, r, P.FROSTC[i])
    gfx.ellipse_o(x, y + 7 * k, 14 * k, 5 * k, shade(P.FROSTC[i], 1.1), INK, 1.2)
    gfx.ellipse_o(x, y + 1 * k, 10 * k, 4.5 * k, shade(P.FROSTC[i], 1.1), INK, 1.2)
    gfx.ellipse_o(x, y - 5 * k, 6 * k, 4 * k, shade(P.FROSTC[i], 1.1), INK, 1.2)
    gfx.ellipse(x - 9 * k, y - 13 * k, 6 * k, 2.6 * k, alpha(C.WHITE, 150))
  else
    gfx.circle_o(x, y, r, 0xfff3f8, INK, 2.5)
    P.topping(i, x, y + 11 * k, 1.25 * k, fcol or 1)
  end
end

-- A padlock over a dark disc, for a kind not open yet.
function P.locked(x, y)
  gfx.circle_o(x, y, 21, 0xb8a8b8, INK, 2.5)
  gfx.ring(x, y - 3, 6.5, 3, INK)
  gfx.rrect_o(x - 8, y - 2, 16, 12, 3, C.GOLD, INK, 1.6)
  gfx.circle(x, y + 3, 1.8, INK)
end

-- The pictures in a bubble: what to do next. what = spoon flame mitt bag shaker bell kind (topping goes with P.topping).
function P.want(what, x, y, r, tx, ty, arg)
  gfx.circle_o(x - r * 0.85, y + r * 1.15, r * 0.18, C.WHITE, INK, 1.8)
  gfx.circle_o(x - r * 1.05, y + r * 1.45, r * 0.1, C.WHITE, INK, 1.6)
  gfx.circle_o(x, y, r, C.WHITE, INK, 2.5)
  local s = r / 24
  if what == "spoon" then
    gfx.line(x - 10 * s, y + 12 * s, x + 8 * s, y - 10 * s, 6 * s, INK)
    gfx.line(x - 10 * s, y + 12 * s, x + 8 * s, y - 10 * s, 3.4 * s, 0xd8a060)
    gfx.ellipse_o(x + 11 * s, y - 13 * s, 7 * s, 5 * s, 0xd8a060, INK, 1.5)
    for k = 0, 2 do gfx.circle(x - 8 * s + k * 8 * s, y + 14 * s - k * 3 * s, 2.5 * s, alpha(0xf0829c, 210)) end
  elseif what == "flame" then
    gfx.poly({x, y - 16 * s, x + 11 * s, y + 2 * s, x + 7 * s, y + 14 * s, x - 7 * s, y + 14 * s, x - 11 * s, y + 2 * s}, INK)
    gfx.poly({x, y - 13 * s, x + 8.5 * s, y + 2 * s, x + 5 * s, y + 12 * s, x - 5 * s, y + 12 * s, x - 8.5 * s, y + 2 * s}, 0xff8a3a)
    gfx.poly({x, y - 3 * s, x + 4 * s, y + 6 * s, x + 2.5 * s, y + 11 * s, x - 2.5 * s, y + 11 * s, x - 4 * s, y + 6 * s}, 0xffe36a)
  elseif what == "mitt" then
    gfx.rrect_o(x - 11 * s, y - 4 * s, 22 * s, 17 * s, 6 * s, 0xff7aa8, INK, 1.8)
    gfx.rrect_o(x + 7 * s, y - 2 * s, 8 * s, 10 * s, 4 * s, 0xff7aa8, INK, 1.6)
    gfx.rrect_o(x - 8 * s, y - 15 * s, 16 * s, 13 * s, 5 * s, 0xff7aa8, INK, 1.8)
    gfx.line(x - 9 * s, y + 5 * s, x + 7 * s, y + 5 * s, 2 * s, C.WHITE)
  elseif what == "bag" then
    local c = arg or 0xff8fbc
    gfx.poly({x - 12 * s, y - 14 * s, x + 12 * s, y - 14 * s, x + 2 * s, y + 10 * s, x - 2 * s, y + 10 * s}, INK)
    gfx.poly({x - 10 * s, y - 12 * s, x + 10 * s, y - 12 * s, x + 1.5 * s, y + 9 * s, x - 1.5 * s, y + 9 * s}, c)
    gfx.star(x, y + 14 * s, 6 * s, fr() * 0.04, c)
  elseif what == "shaker" then
    gfx.rrect_o(x - 8 * s, y - 8 * s, 16 * s, 22 * s, 4 * s, 0xfff3f8, INK, 1.8)
    gfx.rrect_o(x - 9 * s, y - 13 * s, 18 * s, 7 * s, 3 * s, 0xb998f0, INK, 1.6)
    for k = 0, 4 do gfx.circle(x - 4 * s + (k % 3) * 4 * s, y - 1 * s + idiv(k, 3) * 7 * s, 1.8 * s, SPCOL[k + 1]) end
    for k = 0, 3 do
      gfx.line(x - 12 * s + k * 8 * s, y + 18 * s + (k % 2) * 3 * s, x - 10 * s + k * 8 * s, y + 21 * s + (k % 2) * 3 * s, 2.2 * s, SPCOL[k + 1])
    end
  elseif what == "bell" then
    gfx.ellipse_o(x, y + 6 * s, 15 * s, 4.5 * s, C.GOLD, INK, 1.6)
    toon(function()
      toon.ellipse(x, y + 1 * s, 12 * s, 11 * s, C.GOLD)
      toon.rrect(x - 12 * s, y, 24 * s, 6 * s, 2 * s, C.GOLD)
    end, 1.6, INK)
    gfx.circle_o(x, y - 11 * s, 3.2 * s, C.GOLD, INK, 1.4)
    gfx.ellipse(x - 5 * s, y - 2 * s, 2 * s, 4.5 * s, alpha(C.WHITE, 170))
  elseif what == "kind" then
    P.treat(1, x, y + 14 * s, 0.5 * s, 1, P.FLAVC[1], P.FROSTC[1], 1, 0)
  end
end

-- Little progress icons for the rail: 1 bowl 2 oven 3 bag 4 shaker 5 topping star 6 bell.
function P.rail_icon(i, x, y, k, on)
  local r = 17 * k
  gfx.circle_o(x, y, r, on and C.WHITE or 0xf0dce6, INK, 2)
  local s = r / 24 * 1.15
  if i == 1 then
    gfx.ellipse_o(x, y + 3 * s, 14 * s, 9 * s, C.CREAM, INK, 1.4)
    gfx.ellipse(x, y - 1 * s, 11 * s, 4 * s, 0xf0829c)
  elseif i == 2 then
    gfx.rrect_o(x - 11 * s, y - 9 * s, 22 * s, 19 * s, 3 * s, 0xffc4d8, INK, 1.4)
    gfx.rrect(x - 7 * s, y - 3 * s, 14 * s, 9 * s, 2 * s, 0xffa850)
  elseif i == 3 then
    gfx.poly({x - 8 * s, y - 9 * s, x + 8 * s, y - 9 * s, x + 1 * s, y + 8 * s, x - 1 * s, y + 8 * s}, INK)
    gfx.poly({x - 6 * s, y - 7 * s, x + 6 * s, y - 7 * s, x + 0.8 * s, y + 7 * s, x - 0.8 * s, y + 7 * s}, 0xff8fbc)
  elseif i == 4 then
    for k = 0, 5 do gfx.circle(x - 8 * s + (k % 3) * 8 * s, y - 7 * s + idiv(k, 3) * 10 * s, 2.4 * s, SPCOL[k + 1]) end
  elseif i == 5 then
    gfx.star(x, y, 11 * s, 0, INK)
    gfx.star(x, y, 8.5 * s, 0, C.GOLD)
  else
    gfx.ellipse_o(x, y + 3 * s, 11 * s, 7 * s, C.GOLD, INK, 1.4)
    gfx.ellipse(x - 3 * s, y + 1 * s, 3 * s, 2.5 * s, alpha(C.WHITE, 170))
    gfx.circle_o(x, y - 6 * s, 2.6 * s, C.GOLD, INK, 1.2)
  end
end

-- The mixing bowl at x, y (the rim's middle). a: where the spoon is round the bowl. lvl 0..1 batter, col batter colour.
function P.bowl(x, y, a, lvl, col, stir)
  gfx.ellipse_o(x, y + 26, 54, 30, C.CREAM, INK, 3)
  gfx.ellipse_o(x, y, 64, 22, 0xfff9f0, INK, 3)
  gfx.ellipse(x, y + 2, 56, 17, 0xe9d8cc)
  gfx.ellipse(x, y + 1 - lvl * 2, 53, 14 + lvl * 3, col)
  local c = shade(col, 0.82)
  for k = 0, 10 do
    local u = k / 10
    local a0, a1 = a + u * 5.2, a + (u + 0.1) * 5.2
    gfx.line(x + cos(a0) * (6 + u * 38), y + sin(a0) * (2 + u * 9), x + cos(a1) * (6 + (u + 0.1) * 38),
      y + sin(a1) * (2 + (u + 0.1) * 9), 3, c)
  end
  local sx, sy = x + cos(a) * 20, y + sin(a) * 6
  gfx.line(sx, sy, sx + 26 + stir * 2, sy - 62, 9, INK)
  gfx.line(sx, sy, sx + 26 + stir * 2, sy - 62, 5.4, 0xd8a060)
  gfx.ellipse_o(sx, sy, 9, 6, 0xd8a060, INK, 1.6)
  gfx.ellipse(x - 24, y + 22, 8, 14, alpha(C.WHITE, 120))
end

-- The oven. door 0..1 (1 shut), glow 0..1 the heat, prog 0..1 the clock hand. The treat is drawn in the window
-- by main.lua between oven_back and oven_front.
function P.oven_back(x, y, glow, prog)
  gfx.rrect_o(x - 40, y + 124, 16, 10, 3, INK, INK, 1)
  gfx.rrect_o(x + 24, y + 124, 16, 10, 3, INK, INK, 1)
  gfx.rrect_o(x - 84, y, 168, 130, 16, 0xffc4d8, INK, 3)
  gfx.rrect(x - 76, y + 6, 152, 22, 8, 0xfff0f6)
  gfx.circle_o(x - 56, y + 17, 6.5, C.STEEL, INK, 1.6)
  gfx.circle_o(x - 34, y + 17, 6.5, C.STEEL, INK, 1.6)
  gfx.circle_o(x + 56, y + 17, 11, C.WHITE, INK, 1.8)
  local a = prog * 6.2832 - 1.5708
  gfx.line(x + 56, y + 17, x + 56 + cos(a) * 8, y + 17 + sin(a) * 8, 2.2, C.RED)
  gfx.rrect_o(x - 66, y + 34, 132, 86, 10, mix(0x4a2c3c, 0xffa850, glow), INK, 3)
  if glow > 0.05 then gfx.glow(x, y + 80, 70, alpha(0xffb060, floor(110 * glow))) end
end
function P.oven_front(x, y, door, glow)
  if door > 0.5 then
    gfx.rrect(x - 62, y + 38, 124, 78, 8, alpha(0xbfe8ff, 40 + floor(40 * glow)))
    gfx.line(x - 50, y + 46, x - 30, y + 46, 3, alpha(C.WHITE, 120))
    gfx.line(x - 50, y + 54, x - 42, y + 54, 3, alpha(C.WHITE, 120))
    gfx.rrect_o(x - 38, y + 30, 76, 8, 4, C.STEEL, INK, 1.8)
  else
    gfx.poly({x - 66, y + 120, x + 66, y + 120, x + 80, y + 150, x - 80, y + 150}, INK)
    gfx.poly({x - 63, y + 123, x + 63, y + 123, x + 75, y + 147, x - 75, y + 147}, C.STEEL)
    gfx.rrect(x - 40, y + 130, 80, 6, 3, 0xb8c4d0)
  end
end

-- The cake stand under a treat on the counter.
function P.plate(x, y, w)
  gfx.ellipse_o(x, y + 6, w, 13, 0xfff3f8, INK, 2.5)
  gfx.ellipse(x, y + 5, w - 8, 8, 0xffe0ec)
  gfx.ellipse(x - w * 0.4, y + 3, w * 0.2, 2, alpha(C.WHITE, 200))
end

-- The tool hovering over the treat: the piping bag (frosting), the sprinkle jar.
function P.tool(what, x, y, t, col)
  if what == "bag" then
    gfx.poly({x - 15, y - 46, x + 17, y - 46, x + 3, y + 2, x - 3, y + 2}, INK)
    gfx.poly({x - 12, y - 43, x + 14, y - 43, x + 2, y, x - 2, y}, col)
    gfx.line(x - 8, y - 38, x - 1, y - 8, 2, alpha(C.WHITE, 130))
    gfx.rrect_o(x - 16, y - 54, 34, 14, 6, col, INK, 2)
    gfx.star(x + 0.5, y + 5, 7 + t * 4, 0, col)
  else
    gfx.rrect_o(x - 14, y - 34, 28, 38, 7, 0xfff3f8, INK, 2.2)
    gfx.rrect_o(x - 16, y - 44, 32, 13, 5, 0xb998f0, INK, 2)
    for k = 0, 5 do gfx.circle(x - 8 + (k % 3) * 8, y - 22 + idiv(k, 3) * 11, 2.6, SPCOL[k + 1]) end
  end
end

-- ------------------------------------------------------------------ the bakery (painted once)

function P.paint()
  gfx.vgrad(0, 0, W, 206, 0xffe8f0, 0xffd2e4)
  for i = 1, 46 do
    local x, y = hash(i * 2.3) * W, 50 + hash(i * 2.3 + 1) * 150
    gfx.heart(x, y, 5 + hash(i) * 3, alpha(0xff9ec2, 60))
  end
  -- Pennants along the wall and a little picture of the castle.
  for k = 0, 9 do
    local px = 20 + k * 38
    gfx.tri(px - 9, 76 + sin(k * 0.9) * 4, px + 9, 76 + sin(k * 0.9) * 4, px, 92 + sin(k * 0.9) * 4, RAINBOW[k % 6 + 1])
  end
  gfx.line(0, 74, W, 74, 2, alpha(INK, 90))
  gfx.rrect_o(334, 122, 44, 38, 5, 0xfff3f8, INK, 2.5)
  gfx.rect(342, 140, 28, 14, 0xf4b6d0)
  gfx.tri(340, 140, 352, 140, 346, 130, C.ROOF)
  gfx.tri(360, 140, 372, 140, 366, 130, C.ROOF)
  gfx.rect(348, 134, 16, 20, 0xf4b6d0)
  gfx.tri(346, 134, 366, 134, 356, 124, C.ROOF)
  -- Awning with scallops and a sign.
  for i = 0, 7 do gfx.rect(i * 48, 0, 48, 36, i % 2 == 0 and C.ROOF or C.CREAM) end
  for i = 0, 7 do gfx.ellipse_o(i * 48 + 24, 36, 24, 11, i % 2 == 0 and C.ROOF or C.CREAM, INK, 2.5) end
  gfx.rect(0, 0, W, 4, alpha(INK, 40))
  gfx.rrect_o(146, 54, 92, 24, 9, C.CREAM, INK, 2.5)
  gfx.text("BAKERY", 192, 58, 16, C.ROOF, "center")
  -- The counter: top, lip, front.
  gfx.vgrad(0, 205, W, 136, 0xf4cc9c, 0xe0a470)
  for i = 0, 5 do gfx.line(0, 232 + i * 22, W, 232 + i * 22, 1.5, alpha(0xa86a3c, 50)) end
  gfx.rect(0, 205, W, 5, 0xfff0d8)
  gfx.line(0, 205, W, 205, 3, INK)
  gfx.rect(0, 340, W, 66, 0xc9884e)
  gfx.rect(0, 340, W, 8, 0xe4a46a)
  gfx.line(0, 340, W, 340, 3, INK)
  gfx.line(0, 405, W, 405, 3, INK)
  for i = 0, 5 do gfx.rrect(10 + i * 62, 352, 52, 44, 6, alpha(0x000000, 18)) end
  -- The window: her last six treats on a doily shelf behind glass.
  gfx.rrect_o(6, 409, 372, 70, 12, 0xfff3e6, INK, 3)
  gfx.rrect(13, 416, 358, 56, 8, 0xffeaf2)
  gfx.vgrad(13, 416, 358, 56, 0xfff3f8, 0xffd8e8)
  for i = 0, 5 do
    local x = 14 + 29.6 + i * 59.3
    gfx.ellipse_o(x, 466, 25, 6, C.WHITE, alpha(INK, 110), 1.4)
  end
  gfx.rect(13, 468, 358, 6, C.WOOD)
  gfx.rect(13, 468, 358, 2, C.WOODL)
end

-- The glass over the window, drawn on top of the treats in it.
function P.glass()
  gfx.tri(60, 416, 100, 416, 40, 472, alpha(C.WHITE, 40))
  gfx.tri(210, 416, 250, 416, 190, 472, alpha(C.WHITE, 34))
  gfx.tri(330, 416, 360, 416, 310, 472, alpha(C.WHITE, 40))
end

return P
