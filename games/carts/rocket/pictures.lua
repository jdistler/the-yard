-- Starship's pictures. main.lua owns the rules and fills the state table it hands to P.bind(); everything here
-- only draws. Nothing here uses rnd() or reads the music clock (scenery is placed with small integer hashes, so a
-- frame is the same on every runtime). The scenery is ONE reused 384x512 layer, repainted in place when the world
-- (or the landing) changes; figures are drawn live from a few shared upvalues (no closures made per frame).
local P = {}
local S

local C = {
  CREAM = 0xfff6ea, INK = 0x3a2a44, GOLD = 0xffd84a, ROSE = 0xf47eb2, CYAN = 0x7fe8ff, PURPLE = 0x8a5cf5,
  MINT = 0x78dcc8, WHITE = 0xfffcf8, ORANGE = 0xffa84c, PINK = 0xffb0cc, BLUE = 0x6aa8ff, LILAC = 0xc4a4ff,
}
P.C = C
local INK, CREAM, GOLD, WHITE, CYAN, ROSE = C.INK, C.CREAM, C.GOLD, C.WHITE, C.CYAN, C.ROSE

local function fr() return game.frame end
local function hs(i, k)
  local v = sin(i * 12.9898 + k * 78.233) * 43758.5453
  return v - floor(v)
end
local function seg(t, a, b) return clamp((t - a) / (b - a), 0, 1) end

-- The voyage: three worlds. Each lost creature waits in its world; a shy one comes out for kitties or a TEAM.
P.WORLDS = {
  {name = "Pastel Nebula", bg1 = 0x1c1444, bg2 = 0x48266c, planet = ROSE, rock = 0x8a5cf5, rock2 = 0xb88cff,
   lost = 1, shy = 2, px = 192},
  {name = "Candy Ring Planet", bg1 = 0x16244c, bg2 = 0x2e4a7c, planet = C.MINT, rock = 0xc47a5c, rock2 = 0xf0a888,
   lost = 3, shy = 4, px = 270},
  {name = "Starlight Moon", bg1 = 0x141838, bg2 = 0x2a245c, planet = GOLD, rock = 0x7c8ccc, rock2 = 0xb4c4f4,
   lost = 5, shy = 6, px = 110},
}
local WORLDS = P.WORLDS

-- The six star-creatures (our own): name, colours, and what they are.
P.CR = {
  {name = "Pim", what = "star-pup", col = 0xffd84a, dk = 0xe8a820},
  {name = "Mochi", what = "moon-bunny", col = 0xffb0cc, dk = 0xe879a4},
  {name = "Bloop", what = "comet-jelly", col = 0x78dcc8, dk = 0x42b8a0},
  {name = "Nova", what = "comet-fox", col = 0x6aa8ff, dk = 0x4278d8},
  {name = "Dot", what = "dust-moth", col = 0xc4a4ff, dk = 0x9a74e8},
  {name = "Zuzu", what = "sun-cub", col = 0xffa84c, dk = 0xe27a2c},
}
local CR = P.CR

function P.bind(state) S = state end

-- ------------------------------------------------------------------ the scenery (one reused layer)

local bg, bg_key
local PAINT = {}

local function sky_stars(n, ymax, a, seed)
  for i = 1, n do
    local x, y = hs(i, 1 + (seed or 0)) * W, hs(i, 2 + (seed or 0)) * ymax
    local r = 0.7 + hs(i, 3) * 1.3
    gfx.circle(x, y, r, alpha(CREAM, a or 190))
  end
end

local function arc_line(x, y, rx, ry, a0, a1, n, thick, col)   -- an elliptical arc (a ring's half)
  local px, py = x + cos(a0) * rx, y + sin(a0) * ry
  for i = 1, n do
    local a = a0 + (a1 - a0) * i / n
    local qx, qy = x + cos(a) * rx, y + sin(a) * ry
    gfx.line(px, py, qx, qy, thick, col)
    px, py = qx, qy
  end
end

local function sky(i)
  local w = WORLDS[i]
  gfx.vgrad(0, 0, W, H - 32, w.bg1, w.bg2)
  if i == 1 then       -- soft nebula clouds, a far ringed planet
    local cols = {0xf47eb2, 0x8a5cf5, 0x7fe8ff, 0xc4a4ff}
    for k = 1, 9 do
      gfx.circle(hs(k, 11) * W, 60 + hs(k, 12) * 380, 50 + hs(k, 13) * 60, alpha(cols[k % 4 + 1], 22))
    end
    sky_stars(46, H - 40, 190)
    gfx.circle_o(60, 150, 22, 0xf0a0c8, INK, 2)
    arc_line(60, 150, 40, 9, 0.1, 3.0, 10, 3, alpha(0xfff0c8, 220))
  elseif i == 2 then   -- a candy ringed planet, sprinkles and gumdrop clouds
    sky_stars(34, H - 40, 170, 5)
    for k = 1, 5 do
      gfx.circle(hs(k, 21) * W, 100 + hs(k, 22) * 340, 40 + hs(k, 23) * 40, alpha(0xff9ad0, 20))
    end
    arc_line(300, 150, 96, 20, 3.4, 6.0, 14, 7, 0xffd0e8)           -- the ring's back half
    gfx.circle_o(300, 150, 54, 0x78dcc8, INK, 2.5)
    for k = -3, 3 do
      local yy = k * 14
      gfx.ellipse(300, 150 + yy, sqrt(max(54 * 54 - yy * yy, 0)) - 3, 5, k % 2 == 0 and 0xffd0e8 or 0xb4f4e4)
    end
    gfx.circle(284, 134, 8, alpha(WHITE, 90))
    arc_line(300, 150, 96, 20, 0.2, 3.0, 14, 7, 0xffd0e8)           -- the front half
    arc_line(300, 150, 96, 20, 0.2, 3.0, 14, 2, alpha(INK, 160))
    local sp = {0xff9ad0, 0xffe27a, 0x9ae8ff, 0xb8f09a}
    for k = 1, 34 do
      local x, y = hs(k, 31) * W, 60 + hs(k, 32) * 400
      local a = hs(k, 33) * 3.14
      gfx.line(x, y, x + cos(a) * 5, y + sin(a) * 5, 2.4, alpha(sp[k % 4 + 1], 200))
    end
  else                 -- a crescent moon, ribbons of aurora, big twinkles
    sky_stars(64, H - 40, 200, 9)
    local ac = {0x78dcc8, 0xf47eb2, 0x7fe8ff}
    for k = 1, 3 do
      local ph = k * 1.7
      local px0, py0 = -10, 90 + k * 60
      for s = 1, 18 do
        local x = s * 24 - 10
        local y = 90 + k * 60 + sin(s * 0.5 + ph) * 26
        gfx.line(px0, py0, x, y, 12 + k * 3, alpha(ac[k], 26))
        px0, py0 = x, y
      end
    end
    gfx.circle_o(96, 190, 62, 0xfff0b8, INK, 2.5)
    gfx.circle(122, 176, 54, mix(w.bg1, w.bg2, 190 / 480))        -- bites the crescent
    gfx.circle(60, 214, 6, alpha(0xe8d890, 160))
    gfx.circle(78, 238, 4, alpha(0xe8d890, 160))
    for k = 1, 6 do
      local x, y = hs(k, 41) * W, 60 + hs(k, 42) * 380
      gfx.line(x - 5, y, x + 5, y, 1.6, alpha(CREAM, 210))
      gfx.line(x, y - 5, x, y + 5, 1.6, alpha(CREAM, 210))
    end
  end
end

-- The planet's ground for the landing: a big curved hill plus things growing on it. gy(x) is the hill's top.
local function gy(x) return 540 - sqrt(max(210 * 210 - (x - W / 2) * (x - W / 2), 0)) end
P.gy = gy

local function ground(i)
  local w = WORLDS[i]
  gfx.circle_o(W / 2, 540, 210, w.planet, INK, 3)
  if i == 1 then       -- rose hills, craters, pastel crystals
    gfx.circle_o(52, 470, 74, 0xe86ca2, INK, 2.5)
    gfx.circle_o(344, 480, 80, 0xe86ca2, INK, 2.5)
    for k = 1, 5 do gfx.ellipse(W / 2 - 100 + k * 40, 380 + hs(k, 51) * 70, 11, 4, alpha(INK, 70)) end
    for k = 1, 5 do
      local x = 40 + hs(k, 52) * (W - 80)
      local y = gy(x) + 6
      gfx.tri(x - 5, y + 12, x + 5, y + 12, x, y - 12, 0xfff0f8)
      gfx.tri(x - 5, y + 12, x + 5, y + 12, x, y - 12, alpha(0xc4a4ff, 120))
    end
  elseif i == 2 then   -- mint candy ground with swirls and lollipops
    gfx.circle_o(46, 474, 70, 0x56c4a8, INK, 2.5)
    gfx.circle_o(348, 478, 78, 0x56c4a8, INK, 2.5)
    for k = 0, 3 do arc_line(W / 2, 540, 176 - k * 22, 176 - k * 22, 3.7, 5.7, 18, 4, alpha(WHITE, 90)) end
    for k = 1, 4 do
      local x = 36 + hs(k, 61) * (W - 72)
      local y = gy(x)
      gfx.line(x, y + 6, x, y - 22, 3, 0xfff6ea)
      gfx.circle_o(x, y - 28, 11, k % 2 == 0 and 0xff9ad0 or 0xffe27a, INK, 2)
      gfx.circle(x, y - 28, 5, alpha(WHITE, 190))
    end
  else                 -- golden moon-dust, craters, little glowing spires
    gfx.circle_o(50, 472, 72, 0xe8b838, INK, 2.5)
    gfx.circle_o(346, 480, 78, 0xe8b838, INK, 2.5)
    for k = 1, 7 do
      local x = 30 + hs(k, 71) * (W - 60)
      gfx.ellipse(x, gy(x) + 22 + hs(k, 72) * 30, 14, 5, alpha(INK, 60))
    end
    for k = 1, 4 do
      local x = 40 + hs(k, 73) * (W - 80)
      local y = gy(x) + 8
      gfx.tri(x - 6, y, x + 6, y, x, y - 28, 0x9ae8ff)
      gfx.glow(x, y - 18, 16, alpha(0x9ae8ff, 90))
    end
  end
end

PAINT.w1 = function() sky(1) end
PAINT.w2 = function() sky(2) end
PAINT.w3 = function() sky(3) end
PAINT.l1 = function() sky(1) ground(1) end
PAINT.l2 = function() sky(2) ground(2) end
PAINT.l3 = function() sky(3) ground(3) end

local function scene(key)
  if not bg then bg = gfx.layer(W, H) end
  if bg_key ~= key then
    bg_key = key
    bg:paint(PAINT[key])
  end
  gfx.blit(bg, 0, 0)
end

-- ------------------------------------------------------------------ faces

-- Eyes and mouth in the house style. mood: nil, "happy", "sleep", "wow", "x", "worry", "grump", "blink".
local function eyes(x, y, gap, r, lx, ly, mood)
  if mood == "happy" then
    for _, sx in ipairs({-1, 1}) do
      local ex = x + sx * gap
      gfx.line(ex - r, y + r * 0.6, ex, y - r * 0.8, 1.6, INK)
      gfx.line(ex, y - r * 0.8, ex + r, y + r * 0.6, 1.6, INK)
    end
  elseif mood == "sleep" or mood == "blink" then
    gfx.line(x - gap - r, y, x - gap + r, y, 1.6, INK)
    gfx.line(x + gap - r, y, x + gap + r, y, 1.6, INK)
  elseif mood == "x" then
    for _, sx in ipairs({-1, 1}) do
      local ex = x + sx * gap
      gfx.line(ex - r, y - r, ex + r, y + r, 1.6, INK)
      gfx.line(ex - r, y + r, ex + r, y - r, 1.6, INK)
    end
  else
    local rr = mood == "wow" and r * 1.35 or r
    local pr = mood == "wow" and r * 0.7 or r * 0.85
    gfx.circle(x - gap, y, rr, mood == "wow" and WHITE or INK)
    gfx.circle(x + gap, y, rr, mood == "wow" and WHITE or INK)
    if mood == "wow" then
      gfx.circle(x - gap + lx * 0.8, y + ly * 0.8, pr, INK)
      gfx.circle(x + gap + lx * 0.8, y + ly * 0.8, pr, INK)
    else
      gfx.circle(x - gap + lx * 0.6 - r * 0.25, y + ly * 0.6 - r * 0.3, r * 0.32, alpha(WHITE, 230))
      gfx.circle(x + gap + lx * 0.6 - r * 0.25, y + ly * 0.6 - r * 0.3, r * 0.32, alpha(WHITE, 230))
    end
    if mood == "worry" then
      gfx.line(x - gap - r, y - r * 1.9, x - gap + r, y - r * 1.4, 1.4, INK)
      gfx.line(x + gap + r, y - r * 1.9, x + gap - r, y - r * 1.4, 1.4, INK)
    elseif mood == "grump" then
      gfx.line(x - gap - r, y - r * 1.4, x - gap + r, y - r * 1.9, 1.8, INK)
      gfx.line(x + gap + r, y - r * 1.4, x + gap - r, y - r * 1.9, 1.8, INK)
    end
  end
end

-- kind: "smile", "big" (open), "o", "flat", "frown"
local function mouth(x, y, w, kind)
  if kind == "smile" then
    gfx.line(x - w, y, x, y + w * 0.55, 1.5, INK)
    gfx.line(x, y + w * 0.55, x + w, y, 1.5, INK)
  elseif kind == "big" then
    gfx.ellipse(x, y + w * 0.3, w * 0.8, w * 0.7, INK)
    gfx.ellipse(x, y + w * 0.55, w * 0.45, w * 0.3, 0xf47e8a)
  elseif kind == "o" then
    gfx.circle(x, y + w * 0.3, w * 0.45, INK)
  elseif kind == "frown" then
    gfx.line(x - w, y + w * 0.4, x, y, 1.5, INK)
    gfx.line(x, y, x + w, y + w * 0.4, 1.5, INK)
  else
    gfx.line(x - w * 0.7, y, x + w * 0.7, y, 1.5, INK)
  end
end
P.eyes, P.mouth = eyes, mouth

-- ------------------------------------------------------------------ the creatures

local cx, cy, cs, ck = 0, 0, 1, 1
local SIL = false
local function cc(c) return SIL and 0x5a4a88 or c end

local BODY = {}
BODY[1] = function()   -- Pim, the star-pup: floppy ears
  local c = CR[1]
  toon.ellipse(cx - 16 * cs, cy - 3 * cs, 6 * cs, 11 * cs, cc(c.dk))
  toon.ellipse(cx + 16 * cs, cy - 3 * cs, 6 * cs, 11 * cs, cc(c.dk))
  toon.circle(cx, cy, 17 * cs, cc(c.col))
  if toon.fill() and not SIL then
    gfx.ellipse(cx, cy + 7 * cs, 8 * cs, 5 * cs, CREAM)
    gfx.star(cx, cy - 12 * cs, 4.5 * cs, 0, CREAM)
  end
end
BODY[2] = function()   -- Mochi, the moon-bunny: tall ears
  local c = CR[2]
  toon.ellipse(cx - 8 * cs, cy - 22 * cs, 5 * cs, 14 * cs, cc(c.col))
  toon.ellipse(cx + 8 * cs, cy - 22 * cs, 5 * cs, 14 * cs, cc(c.col))
  toon.circle(cx, cy, 17 * cs, cc(c.col))
  if toon.fill() and not SIL then
    gfx.ellipse(cx - 8 * cs, cy - 22 * cs, 2.4 * cs, 9 * cs, 0xfff0f6)
    gfx.ellipse(cx + 8 * cs, cy - 22 * cs, 2.4 * cs, 9 * cs, 0xfff0f6)
  end
end
BODY[3] = function()   -- Bloop, the comet-jelly: a dome, tentacles, an antenna
  local c = CR[3]
  toon.line(cx, cy - 16 * cs, cx + 4 * cs, cy - 25 * cs, 2 * cs, cc(c.dk))
  toon.circle(cx - 11 * cs, cy + 14 * cs, 4.5 * cs, cc(c.dk))
  toon.circle(cx, cy + 16 * cs, 4.5 * cs, cc(c.dk))
  toon.circle(cx + 11 * cs, cy + 14 * cs, 4.5 * cs, cc(c.dk))
  toon.circle(cx, cy - 1 * cs, 17 * cs, cc(c.col))
  toon.rrect(cx - 17 * cs, cy - 1 * cs, 34 * cs, 11 * cs, 5 * cs, cc(c.col))
  if toon.fill() and not SIL then gfx.star(cx + 4 * cs, cy - 26 * cs, 4.5 * cs, fr() * 0.05, GOLD) end
end
BODY[4] = function()   -- Nova, the comet-fox: pointed ears, a fluffy tail
  local c = CR[4]
  toon.ellipse(cx + 19 * cs, cy + 9 * cs, 10 * cs, 6 * cs, cc(c.dk))
  toon.tri(cx - 17 * cs, cy - 5 * cs, cx - 11 * cs, cy - 25 * cs, cx - 1 * cs, cy - 13 * cs, cc(c.col))
  toon.tri(cx + 17 * cs, cy - 5 * cs, cx + 11 * cs, cy - 25 * cs, cx + 1 * cs, cy - 13 * cs, cc(c.col))
  toon.circle(cx, cy, 17 * cs, cc(c.col))
  if toon.fill() and not SIL then
    gfx.circle(cx + 26 * cs, cy + 9 * cs, 4 * cs, CREAM)
    gfx.ellipse(cx, cy + 8 * cs, 9 * cs, 5.5 * cs, CREAM)
  end
end
BODY[5] = function()   -- Dot, the dust-moth: big soft wings, feathery antennae
  local c = CR[5]
  toon.ellipse(cx - 20 * cs, cy - 2 * cs, 11 * cs, 15 * cs, cc(c.dk))
  toon.ellipse(cx + 20 * cs, cy - 2 * cs, 11 * cs, 15 * cs, cc(c.dk))
  toon.line(cx - 5 * cs, cy - 14 * cs, cx - 10 * cs, cy - 24 * cs, 2 * cs, cc(c.dk))
  toon.line(cx + 5 * cs, cy - 14 * cs, cx + 10 * cs, cy - 24 * cs, 2 * cs, cc(c.dk))
  toon.circle(cx, cy, 15 * cs, cc(c.col))
  if toon.fill() and not SIL then
    gfx.circle(cx - 21 * cs, cy - 3 * cs, 3.4 * cs, CREAM)
    gfx.circle(cx + 21 * cs, cy - 3 * cs, 3.4 * cs, CREAM)
  end
end
BODY[6] = function()   -- Zuzu, the sun-cub: a mane of little suns
  local c = CR[6]
  for k = 0, 5 do
    local a = k * 1.0472 + 0.3
    toon.circle(cx + cos(a) * 16 * cs, cy + sin(a) * 16 * cs, 7 * cs, cc(c.dk))
  end
  toon.circle(cx, cy, 15 * cs, cc(c.col))
  if toon.fill() and not SIL then gfx.ellipse(cx, cy + 7 * cs, 7 * cs, 4.5 * cs, CREAM) end
end

local FACE_Y = {0, 0, -1, 0, 0, 0}
-- A creature at x, y (its middle) at scale s. mood: nil "happy" "sleep" "wow" "worry" "x" "wave" "shy".
function P.creature(kind, x, y, s, mood, lx, ly)
  cx, cy, cs, ck, SIL = x, y, s, kind, false
  toon(BODY[kind], 2, INK)
  local fy = y + FACE_Y[kind] * s
  local m = (mood == "wave" or mood == "shy") and nil or mood
  eyes(x, fy - 1 * s, 6 * s, 2.2 * s, (lx or 0), (ly or 0), m)
  if mood == "happy" or mood == "wave" then
    mouth(x, fy + 6 * s, 3.4 * s, "smile")
    gfx.circle(x - 11 * s, fy + 4 * s, 2.6 * s, alpha(ROSE, 140))
    gfx.circle(x + 11 * s, fy + 4 * s, 2.6 * s, alpha(ROSE, 140))
  elseif mood == "wow" then mouth(x, fy + 6 * s, 3.4 * s, "o")
  elseif mood == "sleep" then mouth(x, fy + 6 * s, 2.6 * s, "smile")
  elseif mood == "worry" or mood == "x" then mouth(x, fy + 7 * s, 3 * s, "frown")
  elseif mood == "shy" then
    mouth(x, fy + 6 * s, 2.6 * s, "smile")
    gfx.circle(x - 11 * s, fy + 4 * s, 3 * s, alpha(ROSE, 190))
    gfx.circle(x + 11 * s, fy + 4 * s, 3 * s, alpha(ROSE, 190))
  else mouth(x, fy + 6 * s, 3 * s, "smile") end
end

-- A dark shape with a "?" for a creature not yet found.
function P.silhouette(kind, x, y, s)
  cx, cy, cs, ck, SIL = x, y, s, kind, true
  toon(BODY[kind], 2, 0x2a1f50)
  SIL = false
  gfx.text("?", x, y - 9 * s, floor(18 * s + 2), 0xe8e0ff, "center")
end

-- ------------------------------------------------------------------ the ship

local SLOTS = {{-36, 6}, {36, 6}, {-42, -16}, {42, -16}, {-28, 30}, {28, 30}}
P.SLOTS = SLOTS
local sx0, sy0 = 0, 0
local function fin_fn()
  local fc = S.distinct >= 4 and GOLD or ROSE
  toon.tri(sx0 - 16, sy0 + 14, sx0 - 28, sy0 + 24, sx0 - 12, sy0 - 4, fc)
  toon.tri(sx0 + 16, sy0 + 14, sx0 + 28, sy0 + 24, sx0 + 12, sy0 - 4, fc)
  toon.ellipse(sx0, sy0, 17, 24, CREAM)
  toon.tri(sx0 - 14, sy0 - 10, sx0 + 14, sy0 - 10, sx0, sy0 - 34, CYAN)
end

local function draw_ship(x, y, flying)
  sx0, sy0 = x, y
  local team = S.team_t > 0
  if flying then
    local fl = sin(fr() * 0.6) * 5
    gfx.glow(x, y + 26, 26, alpha(C.ORANGE, 160))
    if S.distinct >= 2 then      -- a rainbow flame once two friends are known
      gfx.tri(x - 9, y + 18, x + 9, y + 18, x, y + 38 + fl, ROSE)
      gfx.tri(x - 6, y + 18, x + 6, y + 18, x, y + 34 + fl, GOLD)
      gfx.tri(x - 3, y + 18, x + 3, y + 18, x, y + 28 + fl, CYAN)
    else
      gfx.tri(x - 8, y + 18, x + 8, y + 18, x, y + 32 + fl, GOLD)
    end
  end
  if team then
    gfx.glow(x, y, 54 + sin(fr() * 0.2) * 5, alpha(GOLD, 120))
    for k = 0, 3 do
      local a = fr() * 0.06 + k * 1.5708
      gfx.star(x + cos(a) * 44, y - 4 + sin(a) * 30, 5, a * 2, GOLD)
    end
  end
  toon(fin_fn, 2.2, INK)
  -- the Pilot in the window
  gfx.circle_o(x, y - 2, 9, CYAN, INK, 1.8)
  local mood = "none"
  if S.wobble > 0 then mood = "x"
  elseif S.idle_t > 500 then mood = "sleep"
  elseif S.cheer_t > 0 or team then mood = "happy"
  elseif S.near_t > 0 then mood = "wow" end
  if mood == "none" then
    eyes(x, y - 3, 3, 1.5, S.look_x, S.look_y, nil)
    mouth(x, y + 2, 2, "smile")
  else
    eyes(x, y - 3, 3, 1.5, 0, 0, mood)
    mouth(x, y + 2.5, 2, mood == "x" and "frown" or mood == "wow" and "o" or mood == "sleep" and "flat" or "smile")
  end
  gfx.circle(x - 5, y - 6, 2.2, alpha(WHITE, 200))
  if S.near_t > 20 then gfx.circle(x + 12, y - 14, 2.6, alpha(CYAN, 220)) end      -- a whew drop
  if S.idle_t > 500 then gfx.text("z", x + 18, y - 22 - (fr() % 40) * 0.3, 14, CREAM, "center", INK) end
  -- the Co-Pilot's bubble cannon on the nose
  local f = S.fire_t
  gfx.circle_o(x, y - 36, f > 0 and 5 + f * 0.25 or 4.5, f > 0 and CYAN or CREAM, INK, 1.6)
  if f > 0 then gfx.glow(x, y - 38, 12 + f, alpha(CYAN, 190)) end
  -- the crown star when all six are friends
  if S.distinct >= 6 then gfx.star(x, y - 44 - (f > 0 and 2 or 0), 6, fr() * 0.04, GOLD) end
  -- the crew riding along
  for i, k in ipairs(S.crew_now) do
    local sl = SLOTS[i]
    local bob = sin(fr() * 0.1 + i * 1.3) * 2.5
    local jump = S.cheer_t > 0 and -abs(sin(fr() * 0.35 + i)) * 7 or 0
    local mood2 = S.wobble > 0 and "worry" or (S.cheer_t > 0 or team) and "happy" or nil
    P.creature(k, x + sl[1], y + sl[2] + bob + jump, 0.46, mood2, S.look_x * 0.5, S.look_y * 0.5)
  end
end

-- ------------------------------------------------------------------ things in the sky

local function draw_star(st)
  if st.kitty then
    gfx.glow(st.x, st.y, 24, alpha(ROSE, 150))
    soap(st.x, st.y, 18, CYAN)
    gfx.tri(st.x - 9, st.y - 4, st.x - 4, st.y - 10, st.x - 3, st.y - 2, CREAM)      -- ears
    gfx.tri(st.x + 9, st.y - 4, st.x + 4, st.y - 10, st.x + 3, st.y - 2, CREAM)
    gfx.circle_o(st.x, st.y, 10, CREAM, INK, 1.8)
    local near = st.near
    eyes(st.x, st.y - 1, 3.2, near and 1.8 or 1.5, st.lx, st.ly, near and "happy" or nil)
    mouth(st.x, st.y + 3.5, 2.2, "smile")
    gfx.line(st.x - 10, st.y + 2, st.x - 15, st.y + 1, 1, INK)                         -- whiskers
    gfx.line(st.x + 10, st.y + 2, st.x + 15, st.y + 1, 1, INK)
  else
    gfx.glow(st.x, st.y, st.road and 24 or 18, alpha(GOLD, st.road and 190 or 140))
    gfx.star(st.x, st.y, 11, fr() * 0.08, GOLD)
    gfx.circle(st.x, st.y, 6.5, 0xfff0a0)
    eyes(st.x, st.y - 1, 2.6, st.near and 1.9 or 1.4, st.lx, st.ly, st.near and "wow" or nil)
    mouth(st.x, st.y + 3, 1.8, st.near and "o" or "smile")
  end
end

local function draw_rock(rk)
  local W2 = WORLDS[S.world]
  local x, y, r = rk.x, rk.y, rk.r
  gfx.circle_o(x, y, r, W2.rock, INK, 2.2)
  gfx.circle(x - r * 0.28, y - r * 0.3, r * 0.26, alpha(WHITE, 90))
  local a = rk.spin
  gfx.circle(x + cos(a) * r * 0.55, y + sin(a) * r * 0.55 + 2, r * 0.17, alpha(INK, 70))
  gfx.circle(x + cos(a + 2.4) * r * 0.6, y + sin(a + 2.4) * r * 0.6, r * 0.12, alpha(INK, 70))
  local look_x = clamp((S.px - x) / 40, -1, 1) * 1.2
  local m = "grump"
  if rk.hit > 0 then m = "x" elseif rk.scared then m = "wow" end
  if m == "x" then
    eyes(x, y + 1, r * 0.27, 2, 0, 0, "x")
  else
    eyes(x, y + 1, r * 0.27, m == "wow" and 2 or 2.2, look_x, 1, m == "wow" and "wow" or "grump")
  end
  mouth(x, y + r * 0.45, 3, m == "wow" and "o" or m == "x" and "frown" or "flat")
  if rk.scared then gfx.circle(x + r * 0.7, y - r * 0.5, 2.4, alpha(CYAN, 230)) end
end

local function draw_boulder(b)
  local W2 = WORLDS[S.world]
  local x, y, r = b.x, b.y, b.r
  gfx.glow(x, y, r + 16, alpha(W2.rock2, 70))
  gfx.circle_o(x, y, r, W2.rock, INK, 3)
  gfx.circle(x - r * 0.3, y - r * 0.32, r * 0.24, alpha(WHITE, 80))
  gfx.circle(x + r * 0.45, y + r * 0.3, r * 0.14, alpha(INK, 60))
  gfx.circle(x - r * 0.5, y + r * 0.35, r * 0.1, alpha(INK, 60))
  local lost = b.need - b.hp
  for k = 1, lost do      -- a crack for each hit
    local a = k * 2.1
    gfx.line(x + cos(a) * 4, y + sin(a) * 4, x + cos(a) * r * 0.9, y + sin(a + 0.3) * r * 0.9, 2, alpha(INK, 190))
  end
  local awake = b.awake > 0 or lost > 0
  local m
  if b.hit_t > 0 then m = "wow" elseif lost > 0 then m = "grump" elseif awake then m = "worry" else m = "sleep" end
  eyes(x, y - 2, r * 0.3, 3, clamp((S.px - x) / 50, -1, 1) * 1.6, 1.4, m)
  mouth(x, y + r * 0.4, 5, (m == "wow" and "big") or (m == "grump" and "frown") or (m == "sleep" and "smile") or "o")
  if m == "sleep" then gfx.text("z", x + r * 0.7, y - r - 6 - (fr() % 50) * 0.2, 16, CREAM, "center", INK) end
end

-- ------------------------------------------------------------------ flying

local function draw_dest()
  -- the world we are flying to, growing as we near it
  local p = clamp(S.dist / S.goal, 0, 1)
  local w = WORLDS[S.world]
  local r = 7 + p * p * 40
  local x = w.px
  gfx.glow(x, 104, r + 14, alpha(w.planet, 90))
  gfx.circle_o(x, 104, r, w.planet, INK, 2)
  gfx.circle(x - r * 0.3, 104 - r * 0.3, r * 0.22, alpha(WHITE, 90))
  if S.world == 2 then arc_line(x, 104, r * 1.7, r * 0.34, 0.2, 3.0, 8, 3, 0xffd0e8) end
  if S.shy_in > 0 then       -- the shy friend peeks out from behind it
    local k = WORLDS[S.world].shy
    local u = ease.out_back(clamp(S.shy_in / 60, 0, 1))
    P.creature(k, x + r * 0.95 + 4, 104 + r * 0.4 - (1 - u) * 20, 0.62 * u + 0.1, "shy", -1, 0)
  end
end

function P.fly()
  scene("w" .. S.world)
  for _, bs in ipairs(S.bg_stars) do gfx.circle(bs[1], bs[2], bs[3], alpha(WHITE, 180)) end
  draw_dest()
  for _, st in ipairs(S.stars) do draw_star(st) end
  if S.boulder then draw_boulder(S.boulder) end
  for _, rk in ipairs(S.rocks) do draw_rock(rk) end
  for _, b in ipairs(S.beams) do
    gfx.glow(b.x, b.y, 16, alpha(CYAN, 170))
    soap(b.x, b.y, 10, CYAN)
    gfx.star(b.x, b.y, 6, fr() * 0.2, GOLD)
  end
  local wx = S.wobble > 0 and sin(S.wobble * 0.8) * 6 or 0
  draw_ship(S.px + wx, S.py, true)
end

-- ------------------------------------------------------------------ the HUD

local c_pil, s_pil, c_cop, s_cop, c_sc, s_sc, c_sv, s_sv = -1, "", -1, "", -1, "", -1, ""
local DOT_X = {318, 340, 362}
function P.hud()
  if S.wp ~= c_pil then c_pil, s_pil = S.wp, "PILOT " .. S.wp end
  if S.wc ~= c_cop then c_cop, s_cop = S.wc, "CO-PILOT " .. S.wc end
  if S.score ~= c_sc then c_sc, s_sc = S.score, "PTS " .. S.score end
  if S.saved ~= c_sv then c_sv, s_sv = S.saved, "SAVED " .. S.saved end
  gfx.rrect_o(8, 6, 118, 24, 9, CREAM, INK, 2)
  gfx.circle(20, 18, 5, CYAN)
  gfx.text(s_pil, 74, 9, 12, INK, "center")
  gfx.rrect_o(W - 126, 6, 118, 24, 9, CREAM, INK, 2)
  gfx.circle(W - 114, 18, 5, ROSE)
  gfx.text(s_cop, W - 62, 9, 12, INK, "center")
  gfx.rrect_o(134, 4, 116, 28, 10, CREAM, INK, 2)
  gfx.text(s_sc, 192, 6, 14, INK, "center")
  gfx.text(s_sv, 192, 20, 10, C.PURPLE, "center")
  meter(96, 40, W - 192, 10, clamp(S.dist / S.goal, 0, 1), GOLD)
  -- TEAM link pips (pilot, co-pilot, pilot...) and the voyage's three worlds
  for i = 1, 3 do
    local on = S.chain >= i or S.team_t > 0
    gfx.circle_o(14 + (i - 1) * 15, 45, 4.5, on and GOLD or alpha(CREAM, 90), INK, 1.5)
  end
  gfx.text("TEAM", 90, 38, 9, alpha(CREAM, 200), "right")
  for i = 1, 3 do
    local done = i < S.world or (i == S.world and S.phase == "land")
    gfx.circle_o(DOT_X[i], 45, i == S.world and 6.5 or 5, done and WORLDS[i].planet or alpha(WORLDS[i].planet, 70), INK, 1.5)
  end
end

-- The TEAM! moment: the two instruments linked by a gold line, the word swelling in.
function P.banner()
  local t = S.team_banner
  if t <= 0 then return end
  local k = ease.out_back(clamp((90 - t) / 18, 0, 1))
  local fade = clamp(t / 20, 0, 1)
  local y = 132
  gfx.glow(W / 2, y + 16, 90 * k, alpha(GOLD, floor(110 * fade)))
  gfx.line(W / 2 - 96, y + 18, W / 2 + 96, y + 18, 3, alpha(GOLD, floor(230 * fade)))
  gfx.tri(W / 2 - 112, y + 26, W / 2 - 96, y + 26, W / 2 - 104, y + 8, CYAN)       -- the pilot's ship
  gfx.circle_o(W / 2 + 104, y + 18, 9, CYAN, INK, 1.8)                              -- the co-pilot's bubble
  gfx.star(W / 2 + 104, y + 18, 5, fr() * 0.1, GOLD)
  gfx.text("TEAM!", W / 2, y - 22 + (1 - k) * 16, floor(30 + 18 * k), GOLD, "center", INK)
  gfx.text("+300", W / 2, y + 36, 16, CREAM, "center", INK)
end

-- ------------------------------------------------------------------ landing

local function lantern(x, y, r, glow, mood)
  gfx.glow(x, y, r * 2.2 * glow + 6, alpha(GOLD, floor(90 * glow + 20)))
  gfx.star(x, y, r, fr() * 0.01, glow > 0.4 and GOLD or 0xc8a860)
  gfx.circle(x, y, r * 0.62, glow > 0.4 and 0xfff0a0 or 0xe0cc90)
  eyes(x, y - r * 0.08, r * 0.22, r * 0.09, 0, 0, mood)
  mouth(x, y + r * 0.2, r * 0.18, (mood == "sleep" or mood == "happy") and "smile" or "frown")
end

local function flag(x, y)
  gfx.line(x, y + 40, x, y - 24, 4, CREAM)
  gfx.rrect_o(x, y - 24, 44, 26, 4, GOLD, INK, 2)
  gfx.star(x + 22 + sin(fr() * 0.1) * 2, y - 11, 8, fr() * 0.06, ROSE)
end

-- where creature j stands when it reaches the ship
local function stand_x(j) return W / 2 - 96 + (j - 1) * 28 end
local function arrival(j)
  local t0 = S.land_starts[j]
  if not t0 then return nil end
  return S.land_t - t0, S.land_kinds[j]
end

local function draw_arrivals()
  for j = 1, 2 do
    local u, k = arrival(j)
    if u and u >= 0 and u < 90 then
      local sx = stand_x(j)
      local sy = gy(sx) - 15
      local slot = SLOTS[#S.crew_now + 1] or SLOTS[6]
      local ex, ey = S.px + slot[1], S.py + slot[2]
      if u < 22 then      -- a bubble drifts in from the side, the creature waving inside
        local bx = lerp(W - 50, W - 150, u / 22)
        local by = 300 + sin(u * 0.4) * 6
        P.creature(k, bx, by, 0.9, "wave", -1, 0)
        soap(bx, by, 26, CYAN)
      elseif u < 62 then  -- pop! then hops to the ship, a little arc
        local q = (u - 22) / 40
        local x0, y0 = W - 150, 300
        local x = lerp(x0, sx, q)
        local y = lerp(y0, sy, q) - sin(q * 3.14159) * 30
        P.creature(k, x, y, 0.9, "happy", 1, 0)
      elseif u < 82 then  -- then into the crew
        local q = (u - 62) / 20
        P.creature(k, lerp(sx, ex, q), lerp(sy, ey, q) - sin(q * 3.14159) * 20, lerp(0.9, 0.46, q), "happy", 0, 0)
      end
      if u >= 22 and u < 62 and u % 8 == 0 then gfx.glow(sx, sy, 20, alpha(GOLD, 60)) end
      if u >= 62 and u < 100 and S.land_new[j] then
        gfx.text("NEW FRIEND!", sx, sy - 44 - (u - 62) * 0.3, 14, GOLD, "center", INK)
      end
    end
  end
end

local function card_rect(h) gfx.rrect_o(24, 62, W - 48, h, 14, CREAM, INK, 3) end

local NODE_X = {72, 192, 312}
function P.land()
  scene("l" .. S.world)
  for _, bs in ipairs(S.bg_stars) do gfx.circle(bs[1], bs[2], bs[3], alpha(WHITE, 180)) end
  flag(W / 2 + 70, gy(W / 2 + 70) - 14)
  draw_ship(S.px, S.py, false)
  draw_arrivals()
  local t = S.land_t
  if t < 12 then return end
  local final = S.world == #WORLDS
  local a = ease.out_back(clamp((t - 12) / 24, 0, 1))
  if a < 0.05 then return end
  card_rect(final and 176 or 188)
  gfx.text(final and "VOYAGE COMPLETE!" or "MISSION COMPLETE!", W / 2, 70, 24, GOLD, "center", INK)
  if final then
    -- the Star Lantern, lit a little brighter for each friend aboard, and the whole crew's gallery
    local glow = clamp(0.25 + #S.crew_now * 0.25, 0, 1)
    lantern(66, 136, 26, glow, S.lantern_mood)
    for i = 1, 6 do
      local x = 138 + (i - 1) * 38
      if S.c[i] > 0 then
        local on = false
        for _, k in ipairs(S.crew_now) do if k == i then on = true end end
        P.creature(i, x, 134, 0.62, on and "happy" or nil, 0, 0)
        gfx.text("x" .. S.c[i], x, 152, 10, INK, "center")
      else
        P.silhouette(i, x, 134, 0.62)
      end
    end
    gfx.text("The Star Lantern glows again!", W / 2, 172, 13, C.PURPLE, "center")
  else
    -- the voyage map: three worlds, the friends found so far, the ship on its way to the next
    gfx.line(NODE_X[1], 122, NODE_X[3], 122, 3, alpha(INK, 70))
    local prog = S.world + clamp((t - 130) / 60, 0, 1) * (t > 130 and 1 or 0)
    for i = 1, 3 do
      local w = WORLDS[i]
      local x = NODE_X[i]
      local done = i <= S.world
      gfx.circle_o(x, 122, 15, done and w.planet or alpha(w.planet, 90), INK, 2)
      if i == S.world then gfx.ring(x, 122, 18 + sin(fr() * 0.15) * 2, 2, GOLD) end
      -- the friends of this world
      if done then
        local n = #S.crew_by_world[i]
        local px2 = x - (n - 1) * 11
        for _, k in ipairs(S.crew_by_world[i]) do
          P.creature(k, px2, 166, 0.42, "happy", 0, 0)
          px2 = px2 + 22
        end
        if n == 0 then P.silhouette(w.lost, x, 166, 0.42) end
      else
        P.silhouette(w.lost, x, 166, 0.42)
      end
      gfx.text(w.name, x, 140, 10, INK, "center")
    end
    -- the ship travels to the next world
    local q = clamp(prog - 1, 0, 1)
    local mx = lerp(NODE_X[S.world], NODE_X[S.world + 1], q)
    local my = 100 - sin(q * 3.14159) * 4
    gfx.tri(mx - 6, my + 10, mx + 6, my + 10, mx, my - 6, CYAN)
    gfx.circle_o(mx, my + 3, 3.2, CREAM, INK, 1.2)
  end
  gfx.text(S.tally_line, W / 2, 190, 12, INK, "center")
  gfx.text(S.score_line, W / 2, 206, 14, C.PURPLE, "center")
  if t >= S.land_ready and blink(40, 26) then
    gfx.text(final and "Press: a new crew starts a new voyage!" or "Press to fly on!", W / 2, 226, 12, INK, "center")
  end
end

-- ------------------------------------------------------------------ the story

local RING = {{-70, -64}, {70, -64}, {-110, 8}, {110, 8}, {-62, 80}, {62, 80}}
function P.story_line(t)
  local known = S.distinct
  if t < 110 then return "Moon-Mama's Star Lantern keeps six baby stars warm." end
  if t < 215 then return "WHOOSH! The wind blew them across the sky!" end
  if known >= 6 then return "The whole crew is home! Let's go visit them." end
  if known > 0 then return "Welcome back, crew! Stick flies, button pops." end
  return "Stick flies. Button pops. Bring them home!"
end

function P.story(t)
  scene("w1")
  for _, bs in ipairs(S.bg_stars) do gfx.circle(bs[1], bs[2], bs[3], alpha(WHITE, 180)) end
  local a = seg(t, 100, 130)        -- wind
  local b = seg(t, 205, 240)        -- the map
  if t < 215 then
    local lx, ly = 192, 190
    local glow = 1 - 0.7 * seg(t, 122, 175)
    gfx.line(lx, 20, lx, ly - 46, 3, alpha(CREAM, 160))
    lantern(lx, ly, 42, glow, t < 122 and "sleep" or (t < 175 and "wow" or "worry"))
    for i = 1, 6 do
      local r = RING[i]
      local x, y = lx + r[1], ly + r[2]
      if t >= 122 then       -- the wind takes them: out to the sides, small and far
        local q = ease.in_quad(seg(t, 128 + i * 4, 205))
        local ang = atan2(r[2] + 0.1, r[1] + 0.1)
        x = x + cos(ang) * q * 300 + sin(t * 0.3 + i) * 3 * q
        y = y + sin(ang) * q * 260 - q * 40
      end
      local s = lerp(0.8, 0.45, seg(t, 128 + i * 4, 205))
      local mood = t < 122 and "sleep" or (t < 160 and "wow" or "worry")
      if t < 122 and t % 60 > 30 then y = y + 1 end
      P.creature(i, x, y, s, mood, 0, 0)
      if t < 122 and (t + i * 9) % 70 < 24 then
        gfx.text("z", x + 14, y - 22 - ((t + i * 9) % 70) * 0.5, 13, CREAM, "center", INK)
      end
    end
    if a > 0 and t < 215 then       -- streaks of wind
      for k = 1, 9 do
        local yy = 60 + hs(k, 81) * 380
        local xx = ((t * 14 + k * 97) % (W + 160)) - 80
        gfx.line(xx, yy, xx + 60, yy - 12, 2.4, alpha(WHITE, floor(150 * a * (1 - seg(t, 190, 215)))))
      end
    end
  end
  if b > 0 then
    -- the map: the dim lantern, three worlds with the lost friends' shapes, and the ship with its two hands
    local lx, ly = 192, 96
    lantern(lx, ly, 26, clamp(0.15 + S.distinct * 0.14, 0.15, 1), S.distinct >= 6 and "happy" or "worry")
    for i = 1, 3 do
      local w = WORLDS[i]
      local x = 80 + (i - 1) * 112
      local y = 190 + (i == 2 and -22 or 0)
      gfx.glow(x, y, 44, alpha(w.planet, floor(70 * b)))
      gfx.circle_o(x, y, 26 * b, w.planet, INK, 2.5)
      gfx.text(w.name, x, y + 32, 11, CREAM, "center", INK)
      local k1, k2 = w.lost, w.shy
      for j, k in ipairs({k1, k2}) do
        local ox = x + (j == 1 and -22 or 22)
        if S.c[k] > 0 then P.creature(k, ox, y + 68, 0.62 * b, "happy", 0, 0)
        else P.silhouette(k, ox, y + 68, 0.62 * b) end
      end
    end
    -- the ship, and the two hands: the stick flies, the button pops
    local sx = 192
    local sy = lerp(520, 372, ease.out_cubic(seg(t, 225, 275))) + sin(t * 0.08) * 3
    draw_ship(sx, sy, true)
    if t > 260 then
      local u = seg(t, 262, 285)
      gfx.circle_o(70, 410, 22 * u, 0x6a5a88, INK, 2)
      gfx.circle(70 + sin(t * 0.12) * 7 * u, 400 + cos(t * 0.12) * 5 * u, 11 * u, ROSE)
      gfx.text("STICK flies", 70, 440, 13, CREAM, "center", INK)
      gfx.circle_o(314, 410, 22 * u, CYAN, INK, 2)
      gfx.star(314, 410, 10 * u * (1 + 0.12 * sin(t * 0.25)), fr() * 0.03, GOLD)
      gfx.text("BUTTON pops", 314, 440, 13, CREAM, "center", INK)
    end
  end
end

return P
