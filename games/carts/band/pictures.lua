-- Band's pictures: the cast (drawn as in Tea), their instruments, the audience, the stage and the setlist.
-- main.lua owns the rules; everything here only draws. No rnd() in here: a hash of the frame instead.
local P = {}

local C = {
  CREAM = 0xfff6ea, GOLD = 0xf2c14e, MINT = 0x7ec8c3, LILAC = 0xb9a0e8, ROOF = 0xe86b9a, TEA = 0xc9865a,
  ORANGE = 0xf29a3a, GREY = 0x8a8f9c, INK = 0x3a2a44, WHITE = 0xfffcf8, SKY = 0x8ec6ff, CASTLE = 0xf4b6d0,
  BLUSH = alpha(0xff8fb0, 120), WOOD = 0xc88450, WOODL = 0xe4a46a, NIGHT = 0x2a1838,
}
P.C = C
local INK = C.INK
local STRIPES = {0xf2c14e, 0xe86b9a, 0x7ec8c3, 0xb9a0e8}
P.STRIPES = STRIPES
local BODY = {C.ORANGE, C.GREY, C.WHITE, C.CREAM}
local DARK = {0xd87a20, 0x666a78, 0xe8dccc, C.ORANGE}
local RAINBOW = {0xe86b9a, 0xf29a3a, 0xf2c14e, 0x7ec8c3, 0xb9a0e8, 0x8ac8ff}

local function fr() return game.frame end
-- A small deterministic scatter, so drawing never touches the game's random numbers.
local function hash(n)
  local v = sin(n * 12.9898) * 43758.5453
  return v - floor(v)
end
P.hash = hash

-- Where each friend stands (the head's middle), and the id of its cast member in Tea's drawing.
-- 1 Unicorn, 2 Pip, 3 Moth, 4 Pearl, 5 Nib.
P.X = {192, 78, 96, 306, 288}
P.Y = {198, 222, 338, 222, 346}
P.NAME = {"Unicorn", "Pip", "Moth", "Pearl", "Nib"}
P.COL = {0xf4a6d0, 0xf29a3a, 0xa8b8d8, 0xfff6ea, 0xffd84a}   -- the friend's colour: lamp, halo, ring
P.WHO = {[2] = 1, [3] = 2, [4] = 3, [5] = 4}

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

-- ------------------------------------------------------------------ instruments

-- Pip's drum kit. y is Pip's head. k, sn, hh, cr: how hard the kick, snare, hat and crash just sounded (0..1).
function P.kit_back(x, y, cr, hh)
  gfx.line(x - 54, y + 8, x - 54, y + 72, 3, INK)
  gfx.line(x + 56, y + 20, x + 56, y + 72, 3, INK)
  local sh = sin(fr() * 1.7) * 2 * cr
  gfx.ellipse_o(x - 54 + sh, y + 6, 21, 5.5, C.GOLD, INK, 2)
  gfx.ellipse_o(x + 56, y + 16 - hh * 3, 17, 4.5, C.GOLD, INK, 2)
  gfx.ellipse_o(x + 56, y + 21, 17, 4.5, 0xe0a838, INK, 2)
  if cr > 0.2 then gfx.glow(x - 54, y + 6, 26, alpha(0xffe080, floor(150 * cr))) end
end

function P.kit_front(x, y, k, sn, lit)
  local pk = 1 + 0.1 * k
  gfx.circle_o(x, y + 64, 31 * pk, C.ROOF, INK, 2.5)
  gfx.circle(x, y + 64, 24 * pk, C.CREAM)
  gfx.star(x, y + 64, 12 * pk, 0, C.GOLD)
  gfx.ring(x, y + 64, 24 * pk, 1.5, INK)
  gfx.ellipse_o(x - 32, y + 40, 15, 11 + sn * 1.5, C.LILAC, INK, 2.5)
  gfx.ellipse(x - 32, y + 37, 12, 6, sn > 0.3 and 0xffffff or C.CREAM)
  gfx.ellipse_o(x + 32, y + 40, 15, 11, C.LILAC, INK, 2.5)
  gfx.ellipse(x + 32, y + 37, 12, 6, C.CREAM)
end

-- Sticks: paws at the cat's chest, tips come down onto the drums. l, r: the hit just made (0..1).
function P.sticks(x, y, col, l, r)
  paw(x - 15, y + 30, col)
  paw(x + 15, y + 30, col)
  gfx.line(x - 15, y + 30, x - 34, y + 14 + l * 20, 3, 0xf4d8a0)
  gfx.circle_o(x - 34, y + 14 + l * 20, 3.2, C.CREAM, INK, 1.2)
  gfx.line(x + 15, y + 30, x + 34, y + 14 + r * 20, 3, 0xf4d8a0)
  gfx.circle_o(x + 34, y + 14 + r * 20, 3.2, C.CREAM, INK, 1.2)
end

-- Moth's upright bass, standing at its side. a: how hard the last pluck was; string: which of four.
function P.bass(x, y, a, string)
  local bx = x + 50
  gfx.rrect_o(bx - 4.5, y - 54, 9, 70, 3, 0x6a4030, INK, 2)
  gfx.circle_o(bx, y - 58, 6, 0x6a4030, INK, 2)
  gfx.ellipse_o(bx, y + 52, 26, 34, C.TEA, INK, 2.5)
  gfx.ellipse_o(bx, y + 18, 18, 22, C.TEA, INK, 2.5)
  gfx.ellipse(bx, y + 40, 20, 14, C.TEA)
  gfx.ellipse(bx - 10, y + 52, 3, 8, alpha(INK, 170))
  gfx.ellipse(bx + 10, y + 52, 3, 8, alpha(INK, 170))
  gfx.rect(bx - 8, y + 64, 16, 3, 0x6a4030)
  for k = 0, 3 do
    local sx = bx - 4.5 + k * 3
    local w = (k + 1 == string) and sin(fr() * 2.1) * 3.5 * a or 0
    gfx.line(sx, y - 54, sx + w, y + 6, 1.2, 0xfff6ea)
    gfx.line(sx + w, y + 6, sx, y + 64, 1.2, 0xfff6ea)
  end
  if a > 0.3 then gfx.glow(bx, y + 28, 30, alpha(0xffd080, floor(110 * a))) end
end

-- Pearl's bell bars, in front of her. hit: 1..5 the bar struck, a: how recently.
function P.bars(x, y, col, hit, a)
  local hs = {40, 35, 30, 25, 21}
  gfx.rrect(x - 50, y + 62, 100, 5, 2, 0x6a4030)
  for k = 1, 5 do
    local bx = x - 40 + (k - 1) * 20
    local lit = k == hit and a > 0.05
    local top = y + 64 - hs[k] - (lit and a * 5 or 0)
    gfx.rrect_o(bx - 8, top, 16, hs[k] - 2 + (lit and a * 5 or 0), 4, lit and 0xffffff or RAINBOW[k], INK, 2)
    gfx.circle(bx, top + 6, 2, alpha(INK, 150))
    if lit then gfx.glow(bx, top + 10, 22, alpha(RAINBOW[k], floor(190 * a))) end
  end
  local mx = hit and (x - 40 + (hit - 1) * 20) or x + 10
  paw(x - 14, y + 34, col)
  paw(x + 14, y + 34, col)
  gfx.line(x - 14, y + 34, x - 28, y + 22, 3, 0xf4d8a0)
  gfx.circle_o(x - 28, y + 22, 3.5, C.GOLD, INK, 1.2)
  local hy = y + 64 - (hit and hs[hit] or 30) - 6 - (1 - a) * 14
  gfx.line(x + 14, y + 34, mx, hy, 3, 0xf4d8a0)
  gfx.circle_o(mx, hy, 3.5, C.GOLD, INK, 1.2)
end

-- Nib's tambourine, shaken on the clap and the shaker. a: how recently.
function P.tambourine(x, y, col, a)
  local tx, ty = x + 31 + sin(fr() * 1.3) * 3 * a, y + 12 - a * 5
  gfx.circle_o(tx, ty, 16, C.GOLD, INK, 2.5)
  gfx.circle(tx, ty, 11, C.CREAM)
  gfx.star(tx, ty, 6, fr() * 0.05, C.ROOF)
  for k = 0, 5 do
    local an = k * 1.0472 + fr() * 0.02 * (1 + 8 * a)
    gfx.circle_o(tx + cos(an) * 16, ty + sin(an) * 16, 3, 0xfff0a0, INK, 1)
  end
  paw(x + 14, y + 30, col, 4.5)
  paw(tx - 12, ty + 8, col, 4.5)
  if a > 0.3 then gfx.glow(tx, ty, 26, alpha(0xffe080, floor(120 * a))) end
end

-- The Unicorn's harp. x, y: her head. a: how recently she plucked; k: which of seven strings.
function P.harp(x, y, a, k)
  local hx, hy = x + 18, y + 44
  -- Hooves on the strings.
  gfx.rrect_o(hx - 40, hy + 52, 80, 8, 4, 0xe0a838, INK, 2)
  gfx.poly({hx - 32, hy + 52, hx + 34, hy + 52, hx + 34, hy + 34, hx - 32, hy + 8}, 0xf2c14e)
  for i = 0, 6 do
    local sx = hx - 28 + i * 9
    local top = hy + 8 + i * 3.7
    local w = (i + 1 == k) and sin(fr() * 2.3) * 3.5 * a or 0
    gfx.line(sx, top, sx + w, (top + hy + 52) / 2, 1.5, RAINBOW[i % 6 + 1])
    gfx.line(sx + w, (top + hy + 52) / 2, sx, hy + 52, 1.5, RAINBOW[i % 6 + 1])
  end
  gfx.line(hx - 34, hy + 6, hx - 34, hy + 56, 6, INK)
  gfx.line(hx - 34, hy + 6, hx - 34, hy + 56, 3.5, C.GOLD)
  gfx.line(hx - 34, hy + 6, hx + 36, hy + 34, 6, INK)
  gfx.line(hx - 34, hy + 6, hx + 36, hy + 34, 3.5, C.GOLD)
  gfx.line(hx + 36, hy + 34, hx + 36, hy + 52, 6, INK)
  gfx.line(hx + 36, hy + 34, hx + 36, hy + 52, 3.5, C.GOLD)
  gfx.circle_o(hx - 34, hy + 4, 4.5, C.ROOF, INK, 1.5)
  local py = hy + 30 - a * 8
  gfx.circle_o(hx - 6, py, 6, C.WHITE, INK, 1.8)
  gfx.circle_o(hx + 16, py + 6 + a * 3, 6, C.WHITE, INK, 1.8)
  if a > 0.3 then gfx.glow(hx, hy + 30, 40, alpha(0xffe8a0, floor(110 * a))) end
end

-- ------------------------------------------------------------------ the audience

-- kind 1 bunny, 2 bird, 3 firefly, 4 hedgehog, 5 frog. x, y: its middle; up: a hop.
function P.fan(kind, x, y, up, glad)
  y = y - up
  if kind == 1 then
    gfx.ellipse_o(x - 4, y - 12, 2.8, 7, C.WHITE, INK, 1.2)
    gfx.ellipse_o(x + 4, y - 12, 2.8, 7, C.WHITE, INK, 1.2)
    gfx.ellipse(x - 4, y - 12, 1.2, 4.5, 0xffb8c8)
    gfx.ellipse(x + 4, y - 12, 1.2, 4.5, 0xffb8c8)
    gfx.circle_o(x, y, 8, C.WHITE, INK, 1.5)
  elseif kind == 2 then
    gfx.circle_o(x, y, 8, C.SKY, INK, 1.5)
    gfx.tri(x - 2, y + 1, x + 2, y + 1, x, y + 5, C.ORANGE)
    gfx.ellipse(x - 7, y + 2, 3, 5, 0x5a9ee0)
    gfx.ellipse(x + 7, y + 2, 3, 5, 0x5a9ee0)
  elseif kind == 3 then
    local g = 0.6 + 0.4 * sin(fr() * 0.15 + x)
    gfx.glow(x, y, 15, alpha(0xfff080, floor(120 * g)))
    gfx.ellipse(x - 5, y - 4, 4, 2, alpha(0xffffff, 170))
    gfx.ellipse(x + 5, y - 4, 4, 2, alpha(0xffffff, 170))
    gfx.circle_o(x, y, 6, 0xffe860, INK, 1.4)
  elseif kind == 4 then
    for k = -2, 2 do gfx.tri(x + k * 3.5 - 3, y - 3, x + k * 3.5 + 3, y - 3, x + k * 3.5, y - 12 + abs(k) * 2, 0x8a5a40) end
    gfx.circle_o(x, y, 8, 0xb07850, INK, 1.5)
    gfx.ellipse(x, y + 2, 5.5, 4.5, 0xf4d8b8)
  else
    gfx.circle_o(x - 4.5, y - 6, 3.5, 0x78d878, INK, 1.2)
    gfx.circle_o(x + 4.5, y - 6, 3.5, 0x78d878, INK, 1.2)
    gfx.circle_o(x, y, 8, 0x78d878, INK, 1.5)
  end
  if glad then
    gfx.line(x - 4.5, y - 1, x - 3, y - 3, 1.5, INK)
    gfx.line(x - 3, y - 3, x - 1.5, y - 1, 1.5, INK)
    gfx.line(x + 1.5, y - 1, x + 3, y - 3, 1.5, INK)
    gfx.line(x + 3, y - 3, x + 4.5, y - 1, 1.5, INK)
  else
    gfx.circle(x - 3, y - 2, 1.5, INK)
    gfx.circle(x + 3, y - 2, 1.5, INK)
  end
end

-- ------------------------------------------------------------------ the stage

local function flower(x, y, s, c)
  for k = 0, 4 do
    local a = k * 1.2566
    gfx.circle_o(x + cos(a) * 5 * s, y + sin(a) * 5 * s, 4.2 * s, c, INK, 1)
  end
  gfx.circle(x, y, 3 * s, C.GOLD)
end

-- The whole static room, painted once into the backdrop.
function P.paint_stage(sg, photos, arch)
  gfx.vgrad(0, 0, W, 262, sg.sky1, sg.sky2)
  for i = 1, 40 do
    gfx.circle(hash(i) * W, 30 + hash(i + 50) * 190, 0.8 + hash(i + 99) * 1.4, alpha(C.GOLD, 150))
  end
  -- The window: a tall arch onto the night, with the moon and the castle far away.
  gfx.rrect_o(110, 60, 164, 220, 80, mix(sg.sky1, 0x000000, 0.25), C.GOLD, 4)
  gfx.circle(228, 104, 19, 0xfff0c0)
  gfx.circle(236, 98, 16, mix(sg.sky1, sg.sky2, 0.4))
  for i = 1, 14 do gfx.circle(122 + hash(i + 7) * 140, 90 + hash(i + 30) * 90, 1.2, alpha(C.WHITE, 200)) end
  gfx.rect(124, 176, 136, 90, mix(sg.sky1, 0x000000, 0.45))
  gfx.rect(138, 150, 16, 30, mix(sg.sky1, 0x000000, 0.45))
  gfx.tri(134, 152, 146, 128, 158, 152, mix(sg.sky1, 0x000000, 0.45))
  gfx.rect(226, 140, 18, 40, mix(sg.sky1, 0x000000, 0.45))
  gfx.tri(222, 142, 235, 116, 248, 142, mix(sg.sky1, 0x000000, 0.45))
  -- Pictures on the wall: the party photos Tea took.
  for i = 1, photos do
    local px = i <= 2 and 34 or 292
    local py = 68 + ((i - 1) % 2) * 66
    gfx.rrect_o(px, py, 62, 52, 5, C.GOLD, INK, 2.5)
    gfx.rect(px + 5, py + 5, 52, 42, RAINBOW[i])
    gfx.tri(px + 5, py + 47, px + 31, py + 22, px + 57, py + 47, alpha(0xffffff, 120))
    gfx.star(px + 31, py + 26, 9, 0, C.GOLD)
    gfx.circle(px + 31, py + 26, 3, C.WHITE)
  end
  -- A flower arch round the window, once she has grown three gardens.
  if arch then
    for i = 0, 18 do
      local a = math.pi + i * math.pi / 18
      local fx, fy = 192 + cos(a) * 92, 142 + sin(a) * 92
      gfx.circle(fx + 5, fy + 4, 5, 0x5ab05a)
      flower(fx, fy, 1.05, RAINBOW[i % 6 + 1])
    end
    for i = 0, 3 do
      for side = -1, 1, 2 do
        gfx.circle(192 + side * 92 + side * 2, 150 + i * 16, 5, 0x5ab05a)
        flower(192 + side * 92, 150 + i * 16 + 3, 1.0, RAINBOW[(i + 2 + (side > 0 and 3 or 0)) % 6 + 1])
      end
    end
  end
  -- Floor: the stage, then the carpet the audience sits on.
  gfx.rect(0, 262, W, 158, C.WOOD)
  gfx.rect(0, 262, W, 6, 0x9a6038)
  for i = 1, 7 do gfx.rect(0, 262 + i * 20, W, 2, alpha(0x6a4030, 120)) end
  for i = 0, 10 do
    local sx = ((i * 71 + 30) % W)
    for r = 0, 6 do gfx.rect(sx + (r % 2) * 37, 268 + r * 20, 2, 18, alpha(0x6a4030, 90)) end
  end
  gfx.rect(0, 404, W, 16, C.WOODL)
  gfx.rect(0, 420, W, 4, INK)
  gfx.rect(0, 424, W, 56, 0x3a2050)
  gfx.rect(0, 424, W, 6, 0x4e2e68)
  -- Curtains and the lamp rail.
  for side = 0, 1 do
    local cx0 = side == 0 and 0 or W - 36
    gfx.rect(cx0, 0, 36, 262, 0xb8365e)
    for k = 0, 3 do gfx.rect(cx0 + 4 + k * 9, 20, 3, 242, 0x8a2446) end
    gfx.rect(side == 0 and 34 or W - 38, 0, 4, 262, 0x6a1c38)
  end
  gfx.rect(0, 0, W, 24, 0x2a1838)
  gfx.rect(0, 24, W, 3, 0x14081c)
  for i = 0, 11 do gfx.circle_o(18 + i * 32, 30, 11, 0xd04a78, INK, 1.5) end
end

-- ------------------------------------------------------------------ lamps and the song board

function P.lamp(x, lit, col)
  gfx.tri(x - 8, 24, x + 8, 24, x + 12, 40, 0x555566)
  gfx.ellipse_o(x, 41, 12, 4, lit and col or 0x777788, INK, 1.5)
  gfx.rrect(x - 8, 20, 16, 8, 3, 0x3a3a48)
  if lit then gfx.glow(x, 42, 22, alpha(col, 190)) end
end

-- A song card's picture, about 80 px wide, middle at cx, cy. which: 1 moon, 2 drum, 3 ball, 4 twirl.
function P.song_icon(which, cx, cy, s, col, t)
  if which == 1 then
    gfx.circle_o(cx, cy, 26 * s, 0xfff0c0, INK, 2.5)
    gfx.circle(cx + 10 * s, cy - 6 * s, 22 * s, mix(col, 0x000000, 0.3))
    gfx.star(cx + 28 * s, cy - 16 * s, 8 * s, t * 0.5, C.GOLD)
    gfx.star(cx - 26 * s, cy + 22 * s, 6 * s, t * 0.4, C.GOLD)
  elseif which == 2 then
    gfx.rrect_o(cx - 22 * s, cy - 8 * s, 44 * s, 30 * s, 6 * s, C.ROOF, INK, 2.5)
    gfx.rect(cx - 19 * s, cy - 2 * s, 38 * s, 4 * s, C.CREAM)
    gfx.ellipse_o(cx, cy - 8 * s, 22 * s, 7 * s, C.CREAM, INK, 2.5)
    gfx.line(cx + 6 * s, cy - 16 * s, cx + 26 * s, cy - 34 * s, 3 * s, 0xf4d8a0)
    gfx.line(cx - 6 * s, cy - 16 * s, cx - 26 * s, cy - 34 * s, 3 * s, 0xf4d8a0)
  elseif which == 3 then
    gfx.line(cx, cy - 34 * s, cx, cy - 22 * s, 2.5 * s, INK)
    gfx.circle_o(cx, cy, 22 * s, 0xd8d8f0, INK, 2.5)
    for k = -2, 2 do gfx.line(cx + k * 8 * s, cy - 20 * s, cx + k * 8 * s, cy + 20 * s, 1.2, alpha(INK, 90)) end
    for k = -2, 2 do gfx.line(cx - 20 * s, cy + k * 8 * s, cx + 20 * s, cy + k * 8 * s, 1.2, alpha(INK, 90)) end
    gfx.rect(cx - 10 * s, cy - 14 * s, 8 * s, 8 * s, 0xff98c8)
    gfx.rect(cx + 2 * s, cy + 2 * s, 8 * s, 8 * s, 0x7fe8ff)
    gfx.rect(cx - 16 * s, cy + 4 * s, 8 * s, 8 * s, C.GOLD)
    gfx.glow(cx + 8 * s, cy - 8 * s, 14 * s, alpha(0xffffff, 130))
  else
    gfx.circle_o(cx, cy - 20 * s, 8 * s, 0xffe0c8, INK, 2)
    gfx.poly({cx - 6 * s, cy - 14 * s, cx + 6 * s, cy - 14 * s, cx + 26 * s, cy + 22 * s, cx - 26 * s, cy + 22 * s}, col)
    gfx.ellipse_o(cx, cy + 22 * s, 28 * s, 6 * s, mix(col, 0xffffff, 0.4), INK, 2)
    for k = 0, 2 do gfx.line(cx - 12 * s + k * 12 * s, cy - 6 * s, cx - 16 * s + k * 16 * s, cy + 18 * s, 1.5, alpha(0xffffff, 150)) end
  end
end

return P
