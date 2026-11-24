-- Tower's pictures. main.lua owns the rules and fills the state table it hands to P.bind(); everything here only
-- draws. Nothing here uses rnd() or reads the music clock (scenery is placed with small integer hashes, so it is
-- the same on every runtime). Figures are drawn live from a few shared upvalues (no closures made per frame); the
-- scenery is one reused layer that is repainted in place when the tower changes.
local P = {}
local S

local C = {
  CREAM = 0xfff6ea, INK = 0x3a2a44, GOLD = 0xffd84a, RED = 0xe84855, BLUE = 0x4a82cc, CYAN = 0x7fe8ff,
  BROWN = 0xa86438, FUR = 0x8c5a3a, FUR_DK = 0x6c4228, WOOD = 0xc8844c, PURPLE = 0x8a5cf5, ROSE = 0xe86b9a,
  SKIN = 0xf4c7a1, BELLY = 0xe8b98c, WHITE = 0xfffcf8, GREEN = 0x62cc6a, GREY = 0x9aa4b8,
}
local INK, GOLD, CREAM = C.INK, C.GOLD, C.CREAM
local function fr() return game.frame end
local function hs(i, k)
  local v = sin(i * 12.9898 + k * 78.233) * 43758.5453
  return v - floor(v)
end
local function seg(t, a, b) return clamp((t - a) / (b - a), 0, 1) end

-- 4 horizontal floors + the top rescue perch
local FLOORS = {442, 348, 254, 160}
local LADDERS = {{x = 304, bot = 1, top = 2}, {x = 84, bot = 2, top = 3}, {x = 296, bot = 3, top = 4}}
P.FLOORS, P.LADDERS = FLOORS, LADDERS

-- The three towers: their colours, their barrels, and their song's name.
local TH = {
  {name = "Girder Tower", sky1 = 0x1b1540, sky2 = 0x4a2f78, beam = 0xe84855, lad = 0x7fe8ff,
   bar = 0xc8844c, band = 0xe84855, glow = 0xff80b0},
  {name = "Vine Treehouse", sky1 = 0x16352c, sky2 = 0x3f7a58, beam = 0xc8844c, lad = 0xb9e87a,
   bar = 0x9c6a3c, band = 0x62cc6a, glow = 0xb9ff9a},
  {name = "Castle Sky Spire", sky1 = 0x32286a, sky2 = 0xf0a0b8, beam = 0xe8d8a8, lad = 0xfff6ea,
   bar = 0x8a5cf5, band = 0xffd84a, glow = 0xffe8a0},
}
P.TH = TH

-- The friends Big Grumble locked up, one per tower.
local FRIENDS = {
  {name = "Twinkle", col = 0xffd84a, dk = 0xe8a820},
  {name = "Buzzy", col = 0xffc83a, dk = 0xd89a20},
  {name = "Puff", col = 0xd8ecff, dk = 0xa8c8f0},
}
P.FRIENDS = FRIENDS
P.GIFTS = {5, 12, 25}      -- rescues that bring Big Grumble a nightcap, a teddy, a star blanket
P.GIFT_NAMES = {"a nightcap", "a teddy bear", "a star blanket"}

function P.bind(state) S = state end

-- ------------------------------------------------------------------ the scenery (one reused layer)

local bg, bg_key
local function scene(key, paint)
  if not bg then bg = gfx.layer(W, H) end
  if bg_key ~= key then
    bg_key = key
    bg:paint(paint)
  end
  gfx.blit(bg, 0, 0)
end

local function sky_stars(n, ymax, a)
  for i = 1, n do
    local x, y = hs(i, 1) * W, hs(i, 2) * ymax
    local r = 0.8 + hs(i, 3) * 1.4
    gfx.circle(x, y, r, alpha(CREAM, a or 200))
  end
end

local function paint_floor(ti, y)
  local th = TH[ti]
  if ti == 1 then          -- steel girders with rivets
    gfx.rrect_o(12, y, W - 24, 14, 4, th.beam, INK, 2)
    for x = 24, W - 36, 28 do gfx.line(x, y + 2, x + 14, y + 12, 1.5, alpha(INK, 120)) end
    for x = 22, W - 22, 56 do gfx.circle(x, y + 7, 2, 0xff9aa0) end
  elseif ti == 2 then      -- planks with knots, vines underneath
    gfx.rrect_o(12, y, W - 24, 14, 5, th.beam, INK, 2)
    for x = 52, W - 40, 44 do gfx.line(x, y + 2, x, y + 12, 1.5, alpha(INK, 110)) end
    for i = 1, 6 do gfx.ellipse(30 + hs(i, y) * (W - 60), y + 7, 3, 2, alpha(INK, 90)) end
    for i = 1, 9 do
      local vx = 24 + hs(i, y + 5) * (W - 48)
      local vl = 10 + hs(i, y + 9) * 22
      gfx.line(vx, y + 12, vx + sin(i) * 3, y + 12 + vl, 2, 0x3f9a4a)
      gfx.circle(vx + sin(i) * 3, y + 12 + vl, 3.2, 0x62cc6a)
    end
  else                     -- gold-trimmed stone with little arches and pennants
    gfx.rrect_o(12, y, W - 24, 14, 4, th.beam, INK, 2)
    gfx.line(18, y + 3, W - 18, y + 3, 2, 0xf2c14e)
    for x = 30, W - 30, 36 do gfx.ellipse(x, y + 14, 9, 6, alpha(INK, 120)) end
    for x = 40, W - 40, 72 do
      gfx.line(x, y + 14, x, y + 20, 1.5, INK)
      gfx.tri(x, y + 20, x + 12, y + 24, x, y + 29, hs(x, 3) > 0.5 and C.ROSE or 0x7fc4ff)
    end
  end
end

local function paint_ladder(ti, l)
  local th = TH[ti]
  local y1, y2 = FLOORS[l.top], FLOORS[l.bot]
  if ti == 2 then          -- rope ladder
    gfx.line(l.x - 10, y1, l.x - 10, y2, 3, 0xa88a58)
    gfx.line(l.x + 10, y1, l.x + 10, y2, 3, 0xa88a58)
    for y = y1 + 10, y2 - 6, 14 do gfx.line(l.x - 10, y, l.x + 10, y, 4, 0x8a5c34) gfx.line(l.x - 8, y - 1, l.x + 8, y - 1, 1.5, 0xc8956a) end
  else
    gfx.line(l.x - 10, y1, l.x - 10, y2, 3.5, th.lad)
    gfx.line(l.x + 10, y1, l.x + 10, y2, 3.5, th.lad)
    for y = y1 + 10, y2 - 6, 14 do
      gfx.line(l.x - 10, y, l.x + 10, y, 2.5, th.lad)
      if ti == 3 then gfx.circle(l.x, y, 2, 0xf2c14e) end
    end
  end
end

local function paint_far(ti)
  local top, bot = 0, H - 32
  gfx.vgrad(0, top, W, bot, TH[ti].sky1, TH[ti].sky2)
  if ti == 1 then          -- night city, a crescent moon
    sky_stars(34, 300, 190)
    gfx.circle(318, 84, 28, 0xfff2c8)
    gfx.circle(329, 78, 24, mix(TH[1].sky1, TH[1].sky2, 0.25))
    for i = 0, 11 do
      local bw, bh = 34, 90 + hs(i, 7) * 170
      local bx, by = i * 33 - 6, bot - bh
      gfx.rrect(bx, by, bw, bh + 10, 3, i % 2 == 0 and 0x2a2058 or 0x35286a)
      for wy = by + 10, bot - 20, 18 do
        for wx = bx + 6, bx + bw - 12, 12 do
          if hs(wx + i, wy) > 0.45 then gfx.rect(wx, wy, 6, 8, alpha(0xffd870, 190)) end
        end
      end
    end
  elseif ti == 2 then      -- a moonlit forest of big trunks and leafy canopies
    gfx.circle(90, 96, 44, alpha(0xe8ffc8, 70))
    gfx.circle(90, 96, 32, 0xeaffd2)
    for i = 0, 4 do
      local tx = 10 + i * 88 + hs(i, 4) * 20
      gfx.rrect(tx, 0, 34, bot, 10, i % 2 == 0 and 0x1e3a2c or 0x274a36)
      for ly = 60, bot - 40, 90 do
        gfx.ellipse(tx + 17, ly + hs(i, ly) * 30, 38, 20, alpha(0x4cae5c, 150))
      end
    end
    for i = 1, 16 do gfx.circle(hs(i, 8) * W, 30 + hs(i, 9) * 340, 1.6, alpha(0xfff6ea, 150)) end
    for x = 20, W, 60 do gfx.ellipse(x, 8, 46, 24, 0x2c6a44) end
    for i = 1, 5 do
      local mx = 26 + hs(i, 12) * (W - 52)
      gfx.glow(mx, bot - 6, 22, alpha(0xffd870, 110))
      gfx.rrect(mx - 4, bot - 16, 8, 14, 3, 0xf4e8c4)
      gfx.ellipse(mx, bot - 16, 11, 7, C.RED)
    end
  else                     -- a castle sky: clouds under a pink dusk, two far castles
    sky_stars(26, 200, 220)
    gfx.glow(192, bot - 40, 200, alpha(0xffd8a0, 90))
    for i = 0, 6 do gfx.ellipse(i * 64, bot - 8 - hs(i, 1) * 30, 60, 26, alpha(0xfff0f4, 200)) end
    for _, cx in ipairs({0, 318}) do
      gfx.rect(cx + 6, 190, 54, bot - 190, 0x5a4a98)
      for k = 0, 2 do
        local tx = cx + 4 + k * 22
        gfx.rect(tx, 150 - k % 2 * 24, 18, 60 + k % 2 * 24, 0x6a58a8)
        gfx.tri(tx - 3, 150 - k % 2 * 24, tx + 9, 118 - k % 2 * 24, tx + 21, 150 - k % 2 * 24, 0xe86b9a)
      end
      for wy = 210, bot - 30, 34 do gfx.rrect(cx + 18, wy, 10, 16, 4, alpha(0xffd870, 220)) gfx.rrect(cx + 40, wy, 10, 16, 4, alpha(0xffd870, 220)) end
      gfx.line(cx + 22, 118 - 24, cx + 22, 96, 2, INK)
      gfx.tri(cx + 22, 96, cx + 44, 103, cx + 22, 110, C.GOLD)
    end
  end
end

local function paint_play(ti)
  paint_far(ti)
  for _, y in ipairs(FLOORS) do paint_floor(ti, y) end
  for _, l in ipairs(LADDERS) do paint_ladder(ti, l) end
end

-- the story's night: sky, moon, hills, three tower silhouettes
local function paint_story()
  gfx.vgrad(0, 0, W, H - 32, 0x120e34, 0x4a2f78)
  sky_stars(46, 300, 210)
  gfx.circle(318, 70, 36, alpha(0xfff2c8, 60))
  gfx.circle(318, 70, 26, 0xfff2c8)
  gfx.circle(327, 63, 22, 0x2c2260)
  for k, tx in ipairs({58, 192, 326}) do
    local th = 130 + (k == 2 and 40 or 0)
    gfx.rrect(tx - 30, th + 100, 60, 280, 4, 0x2a2058)
    gfx.rect(tx - 36, th + 96, 72, 10, 0x35286a)
    for wy = th + 124, 340, 34 do gfx.rrect(tx - 8, wy, 16, 20, 6, alpha(0xffd870, hs(k, wy) > 0.5 and 210 or 60)) end
  end
  gfx.ellipse(70, 420, 190, 90, 0x1d1747)
  gfx.ellipse(320, 430, 190, 90, 0x241b55)
  gfx.rect(0, 372, W, H - 372 - 32, 0x1a1442)
  gfx.rect(0, 372, W, 4, 0x35286a)
end

local SCENE_KEYS = {"t1", "t2", "t3"}
local cur_ti = 1
local function paint_cur() paint_play(cur_ti) end

-- ------------------------------------------------------------------ faces (shared by every friend)

local function eyes_open(cx, cy, e, s, lx, ly)
  for k = -1, 1, 2 do
    gfx.ellipse(cx + k * e + lx, cy + ly, 2.6 * s, 3.2 * s, INK)
    gfx.circle(cx + k * e + lx + 0.9 * s, cy + ly - 1.2 * s, 0.9 * s, C.WHITE)
  end
end
local function eyes_closed(cx, cy, e, s)
  for k = -1, 1, 2 do gfx.line(cx + k * e - 3 * s, cy, cx + k * e + 3 * s, cy, 1.8 * s, INK) end
end
local function eyes_happy(cx, cy, e, s)
  for k = -1, 1, 2 do
    local ex = cx + k * e
    gfx.line(ex - 3 * s, cy + 1.5 * s, ex, cy - 1.8 * s, 1.8 * s, INK)
    gfx.line(ex, cy - 1.8 * s, ex + 3 * s, cy + 1.5 * s, 1.8 * s, INK)
  end
end

local function friend_face(cx, cy, s, mood, lx)
  local e = 5.5 * s
  local blink = (fr() + cx) % 170 < 6
  if mood == "cheer" then
    eyes_happy(cx, cy, e, s)
    gfx.ellipse(cx, cy + 6 * s, 3.4 * s, 3 * s, INK)
    gfx.ellipse(cx, cy + 7.2 * s, 2 * s, 1.2 * s, C.ROSE)
  elseif mood == "sing" then
    eyes_closed(cx, cy, e, s)
    gfx.ellipse(cx, cy + 6 * s, 2.6 * s, (2.4 + abs(sin(fr() * 0.3)) * 1.6) * s, INK)
  elseif mood == "sleep" then
    eyes_closed(cx, cy, e, s)
  else
    if blink then eyes_closed(cx, cy, e, s) else eyes_open(cx, cy, e, s, lx * s, 0) end
    if mood == "worry" then
      gfx.line(cx - e - 3 * s, cy - 5 * s, cx - e + 3 * s, cy - 8 * s, 1.6 * s, INK)
      gfx.line(cx + e + 3 * s, cy - 5 * s, cx + e - 3 * s, cy - 8 * s, 1.6 * s, INK)
      gfx.line(cx - 3 * s, cy + 7 * s, cx, cy + 5 * s, 1.6 * s, INK)
      gfx.line(cx, cy + 5 * s, cx + 3 * s, cy + 7 * s, 1.6 * s, INK)
      gfx.circle(cx + e + 5 * s, cy + 3 * s + (fr() * 0.2) % 5, 1.8 * s, alpha(C.CYAN, 220))
    else
      gfx.line(cx - 3 * s, cy + 5 * s, cx, cy + 7 * s, 1.6 * s, INK)
      gfx.line(cx, cy + 7 * s, cx + 3 * s, cy + 5 * s, 1.6 * s, INK)
    end
  end
  gfx.circle(cx - e - 3 * s, cy + 4 * s, 2.6 * s, alpha(C.ROSE, 130))
  gfx.circle(cx + e + 3 * s, cy + 4 * s, 2.6 * s, alpha(C.ROSE, 130))
end

-- ------------------------------------------------------------------ the friends

local POLY4 = {0, 0, 0, 0, 0, 0, 0, 0}
local function poly4(x1, y1, x2, y2, x3, y3, x4, y4, c, toonp)
  POLY4[1], POLY4[2], POLY4[3], POLY4[4], POLY4[5], POLY4[6], POLY4[7], POLY4[8] = x1, y1, x2, y2, x3, y3, x4, y4
  if toonp then toon.poly(POLY4, c) else gfx.poly(POLY4, c) end
end
local STARPOLY = {0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0}
local fx, fy, fs, fk, ft, fdim = 0, 0, 1, 1, 0, false
local function friend_body()
  local F = FRIENDS[fk]
  local col, dk = fdim and 0x6a5a82 or F.col, fdim and 0x5a4a72 or F.dk
  if fk == 1 then
    for i = 0, 9 do
      local r = (i % 2 == 0) and 21 or 11
      local a = -1.5708 + i * 0.6283 + sin(ft * 0.05) * 0.08
      STARPOLY[i * 2 + 1], STARPOLY[i * 2 + 2] = fx + cos(a) * r * fs, fy + sin(a) * r * fs
    end
    toon.poly(STARPOLY, col)
    toon.circle(fx, fy, 11 * fs, col)
  elseif fk == 2 then
    local flap = abs(sin(ft * 0.5)) * 4
    toon.ellipse(fx - 6 * fs, fy - 13 * fs, 8 * fs, (7 + flap) * fs, 0xe8f6ff)
    toon.ellipse(fx + 7 * fs, fy - 13 * fs, 8 * fs, (7 + flap) * fs, 0xe8f6ff)
    toon.ellipse(fx, fy, 18 * fs, 14 * fs, col)
    toon.line(fx - 6 * fs, fy - 14 * fs, fx - 11 * fs, fy - 22 * fs, 2 * fs, INK)
    toon.line(fx + 6 * fs, fy - 14 * fs, fx + 11 * fs, fy - 22 * fs, 2 * fs, INK)
    toon.tri(fx + 15 * fs, fy - 3 * fs, fx + 15 * fs, fy + 3 * fs, fx + 24 * fs, fy, INK)
    if toon.fill() then
      gfx.line(fx + 6 * fs, fy - 12 * fs, fx + 6 * fs, fy + 12 * fs, 4 * fs, dk)
      gfx.line(fx + 13 * fs, fy - 8 * fs, fx + 13 * fs, fy + 8 * fs, 3 * fs, dk)
      gfx.circle(fx - 11 * fs, fy - 22 * fs, 2 * fs, INK)
      gfx.circle(fx + 11 * fs, fy - 22 * fs, 2 * fs, INK)
    end
  else
    toon.tri(fx - 14 * fs, fy - 8 * fs, fx - 6 * fs, fy - 20 * fs, fx - 1 * fs, fy - 9 * fs, col)
    toon.tri(fx + 14 * fs, fy - 8 * fs, fx + 6 * fs, fy - 20 * fs, fx + 1 * fs, fy - 9 * fs, col)
    toon.circle(fx - 11 * fs, fy + 6 * fs, 9 * fs, col)
    toon.circle(fx + 11 * fs, fy + 6 * fs, 9 * fs, col)
    toon.circle(fx, fy + 8 * fs, 10 * fs, col)
    toon.ellipse(fx, fy - 1 * fs, 15 * fs, 13 * fs, col)
    toon.line(fx + 15 * fs, fy + 10 * fs, fx + 24 * fs, fy + 2 * fs + sin(ft * 0.12) * 3, 4 * fs, col)
    if toon.fill() then
      gfx.tri(fx - 11 * fs, fy - 9 * fs, fx - 6 * fs, fy - 16 * fs, fx - 4 * fs, fy - 9 * fs, C.ROSE)
      gfx.tri(fx + 11 * fs, fy - 9 * fs, fx + 6 * fs, fy - 16 * fs, fx + 4 * fs, fy - 9 * fs, C.ROSE)
    end
  end
end

-- kind 1..3 (Twinkle, Buzzy, Puff), centred at x, y, scale s, mood: worry hope cheer sing sleep
function P.friend(kind, x, y, s, mood, look, dim)
  fx, fy, fs, fk, ft, fdim = x, y, s, kind, fr(), dim or false
  if not dim then gfx.glow(x, y, 26 * s, alpha(FRIENDS[kind].col, 90)) end
  toon(friend_body, 2, INK)
  if dim then
    gfx.text("?", x, y - 12 * s, floor(22 * s), 0xc8bce8, "center", INK)
  else
    friend_face(x - (kind == 2 and 4 * s or 0), y + (kind == 3 and 0 or 0), s, mood, look or 0)
  end
end

-- ------------------------------------------------------------------ Big Grumble

local gx, gy, gs, gmood, gpose, gsoft, glx, gly, gcap, gteddy, gblanket = 0, 0, 1, "grumpy", "down", 0, 0, 0, false, false, false
local function grumble_body()
  local x, y, s = gx, gy, gs
  -- legs, body, belly
  toon.ellipse(x - 16 * s, y - 5 * s, 13 * s, 9 * s, C.FUR_DK)
  toon.ellipse(x + 16 * s, y - 5 * s, 13 * s, 9 * s, C.FUR_DK)
  toon.ellipse(x, y - 28 * s, 31 * s, 27 * s, C.FUR)
  -- arms
  local up = gpose == "throw" or gpose == "lift" or gpose == "up"
  toon.line(x - 27 * s, y - 40 * s, x - 42 * s, y - (gpose == "pound" and 30 or 14 + sin(fr() * 0.08) * 2) * s, 13 * s, C.FUR)
  if up then
    toon.line(x + 27 * s, y - 40 * s, x + 38 * s, y - 70 * s, 13 * s, C.FUR)
  elseif gpose == "hug" then
    toon.line(x + 27 * s, y - 40 * s, x + 44 * s, y - 26 * s, 13 * s, C.FUR)
  else
    toon.line(x + 27 * s, y - 40 * s, x + 42 * s, y - 14 * s, 13 * s, C.FUR)
  end
  if gblanket then
    poly4(x - 30 * s, y - 44 * s, x + 30 * s, y - 44 * s, x + 24 * s, y - 14 * s, x - 24 * s, y - 14 * s, 0x7a6ad8, true)
  end
  -- head and ears
  toon.circle(x - 19 * s, y - 66 * s, 7 * s, C.FUR)
  toon.circle(x + 19 * s, y - 66 * s, 7 * s, C.FUR)
  toon.circle(x, y - 64 * s, 20 * s, C.FUR)
  if toon.fill() then
    gfx.ellipse(x, y - 25 * s, 17 * s, 15 * s, C.BELLY)
    gfx.circle(x - 19 * s, y - 66 * s, 3.6 * s, C.BELLY)
    gfx.circle(x + 19 * s, y - 66 * s, 3.6 * s, C.BELLY)
    gfx.ellipse(x, y - 58 * s, 14 * s, 12 * s, C.BELLY)
    if gblanket then
      for i = 0, 2 do gfx.star(x - 14 * s + i * 14 * s, y - 28 * s, 4 * s, 0.3, GOLD) end
    end
  end
end

local function grumble_face()
  local x, y, s, m = gx, gy, gs, gmood
  local ey, e = y - 68 * s, 7.5 * s
  local sl = (5 - gsoft * 1.6) * s
  if m == "sleep" or m == "asleep" then
    for k = -1, 1, 2 do
      gfx.line(x + k * e - 4 * s, ey, x + k * e, ey + 2 * s, 2 * s, INK)
      gfx.line(x + k * e, ey + 2 * s, x + k * e + 4 * s, ey, 2 * s, INK)
    end
  elseif m == "laugh" then
    for k = -1, 1, 2 do
      gfx.line(x + k * e - 4 * s, ey + 2 * s, x + k * e, ey - 2 * s, 2.2 * s, INK)
      gfx.line(x + k * e, ey - 2 * s, x + k * e + 4 * s, ey + 2 * s, 2.2 * s, INK)
    end
  elseif m == "yawn" then
    for k = -1, 1, 2 do gfx.line(x + k * e - 4 * s, ey, x + k * e + 4 * s, ey, 2.4 * s, INK) end
  elseif m == "soft" then
    for k = -1, 1, 2 do
      gfx.ellipse(x + k * e, ey, 3.6 * s, 4 * s, INK)
      gfx.circle(x + k * e + 1.1 * s, ey - 1.5 * s, 1.3 * s, C.WHITE)
    end
  else
    local big = (m == "shock") and 1.35 or 1
    for k = -1, 1, 2 do
      gfx.ellipse(x + k * e, ey, 4.4 * s * big, 5 * s * big, C.WHITE)
      gfx.circle(x + k * e + glx * 1.2 * s, ey + gly * s, 2.3 * s, INK)
    end
    if m == "sleepy" then
      for k = -1, 1, 2 do gfx.rect(x + k * e - 5 * s, ey - 6 * s, 10 * s, 7 * s, C.FUR) end
    end
  end
  -- brows
  if m == "grumpy" or m == "throw" then
    gfx.line(x - 15 * s, ey - 9 * s, x - 3 * s, ey - 9 * s + sl, 3 * s, C.FUR_DK)
    gfx.line(x + 15 * s, ey - 9 * s, x + 3 * s, ey - 9 * s + sl, 3 * s, C.FUR_DK)
  elseif m == "shock" then
    gfx.line(x - 14 * s, ey - 11 * s, x - 3 * s, ey - 14 * s, 3 * s, C.FUR_DK)
    gfx.line(x + 14 * s, ey - 11 * s, x + 3 * s, ey - 14 * s, 3 * s, C.FUR_DK)
  elseif m == "sleepy" or m == "soft" then
    gfx.line(x - 14 * s, ey - 9 * s, x - 3 * s, ey - 9 * s, 2.4 * s, C.FUR_DK)
    gfx.line(x + 14 * s, ey - 9 * s, x + 3 * s, ey - 9 * s, 2.4 * s, C.FUR_DK)
  end
  -- mouth
  local my = y - 51 * s
  if m == "throw" or m == "laugh" then
    gfx.ellipse(x, my, 9 * s, (6 + abs(sin(fr() * 0.5)) * 3) * s, INK)
    gfx.ellipse(x, my + 3 * s, 5 * s, 3 * s, C.ROSE)
  elseif m == "shock" then
    gfx.ellipse(x, my, 4 * s, 5 * s, INK)
  elseif m == "yawn" then
    gfx.ellipse(x, my, 8 * s, 8 * s, INK)
    gfx.ellipse(x, my + 3 * s, 5 * s, 3.4 * s, C.ROSE)
  elseif m == "soft" or m == "asleep" then
    gfx.line(x - 7 * s, my - 1 * s, x, my + 3 * s, 2.2 * s, INK)
    gfx.line(x, my + 3 * s, x + 7 * s, my - 1 * s, 2.2 * s, INK)
    gfx.circle(x - 13 * s, my - 4 * s, 3.4 * s, alpha(C.ROSE, 150))
    gfx.circle(x + 13 * s, my - 4 * s, 3.4 * s, alpha(C.ROSE, 150))
  elseif m == "sleep" or m == "sleepy" then
    gfx.line(x - 5 * s, my + 1 * s, x + 5 * s, my + 1 * s, 2.2 * s, INK)
  else
    local d = (4 - gsoft * 1.3) * s
    gfx.line(x - 8 * s, my + 2 * s, x, my - d + 2 * s, 2.4 * s, INK)
    gfx.line(x, my - d + 2 * s, x + 8 * s, my + 2 * s, 2.4 * s, INK)
  end
  if m == "shock" then gfx.circle(x + 24 * s, y - 80 * s + (fr() * 0.25) % 6, 2.4 * s, alpha(C.CYAN, 230)) end
  -- keepsakes
  if gcap then
    local sw = sin(fr() * 0.05) * 3
    poly4(x - 15 * s, y - 80 * s, x + 15 * s, y - 80 * s, x + 30 * s, y - 100 * s + sw, x + 6 * s, y - 108 * s, INK)
    poly4(x - 13 * s, y - 81 * s, x + 13 * s, y - 81 * s, x + 27 * s, y - 99 * s + sw, x + 6 * s, y - 106 * s, 0x7fa8ff)
    gfx.circle(x + 28 * s, y - 100 * s + sw, 5 * s, C.WHITE)
    gfx.rrect_o(x - 18 * s, y - 83 * s, 36 * s, 7 * s, 3, C.WHITE, INK, 1.5)
  end
  if gteddy then
    local tx, ty = x - 40 * s, y - 16 * s
    gfx.circle_o(tx, ty, 8 * s, 0xd8a060, INK, 1.8)
    gfx.circle_o(tx - 6 * s, ty - 8 * s, 3.4 * s, 0xd8a060, INK, 1.5)
    gfx.circle_o(tx + 6 * s, ty - 8 * s, 3.4 * s, 0xd8a060, INK, 1.5)
    gfx.circle(tx - 3 * s, ty - 1 * s, 1 * s, INK)
    gfx.circle(tx + 3 * s, ty - 1 * s, 1 * s, INK)
  end
end

-- x, y: where his feet are. mood: grumpy throw laugh shock sleepy yawn soft sleep asleep. pose: down lift
-- throw pound up hug. soft: 0..2, how much he has softened over the visits. look: where the pupils go.
function P.grumble(x, y, s, mood, pose, soft, lookx, looky, hat, teddy, blanket)
  gx, gy, gs, gmood, gpose, gsoft = x, y, s, mood, pose or "down", soft or 0
  glx, gly = clamp(lookx or 0, -2, 2), clamp(looky or 0, -2, 2)
  gcap, gteddy, gblanket = hat or false, teddy or false, blanket or false
  toon(grumble_body, 2.4, INK)
  grumble_face()
  if mood == "sleep" or mood == "asleep" or mood == "sleepy" then
    for i = 0, 2 do
      local k = ((fr() * 0.015 + i * 0.33) % 1)
      gfx.text("z", x + (26 + k * 22) * s, y - (88 + k * 36) * s, floor((10 + i * 3) * s), alpha(C.WHITE, floor(255 * (1 - k))), "center", INK)
    end
  end
end

-- the barrel Big Grumble holds up before a throw
local function held_barrel(x, y, s, ti)
  gfx.circle_o(x, y, 11 * s, TH[ti].bar, INK, 2)
  gfx.line(x - 9 * s, y - 3 * s, x + 9 * s, y - 3 * s, 2.4 * s, TH[ti].band)
  gfx.line(x - 9 * s, y + 4 * s, x + 9 * s, y + 4 * s, 2.4 * s, TH[ti].band)
end

-- ------------------------------------------------------------------ barrels with faces

local function draw_barrel(b, ti)
  local th = TH[ti]
  local cx, cy = b.x, b.y - 12
  gfx.circle_o(cx, cy, 12, th.bar, INK, 2)
  local a = fr() * 0.22 * b.dir
  gfx.line(cx - cos(a) * 9, cy - sin(a) * 9, cx + cos(a) * 9, cy + sin(a) * 9, 2.4, alpha(th.band, 220))
  gfx.circle(cx + cos(a + 1.57) * 8, cy + sin(a + 1.57) * 8, 1.8, GOLD)
  local d = b.dir
  if b.jumped then            -- hopped over: cheering
    gfx.line(cx - 7, cy - 1, cx - 4, cy - 4, 1.8, INK) gfx.line(cx - 4, cy - 4, cx - 1, cy - 1, 1.8, INK)
    gfx.line(cx + 1, cy - 1, cx + 4, cy - 4, 1.8, INK) gfx.line(cx + 4, cy - 4, cx + 7, cy - 1, 1.8, INK)
    gfx.ellipse(cx, cy + 4, 3, 2.4, INK)
  elseif S.swat_t > 0 then    -- scared of the Star Swatter
    gfx.circle(cx - 4, cy - 2, 3, C.WHITE) gfx.circle(cx + 4, cy - 2, 3, C.WHITE)
    gfx.circle(cx - 4 + d * 0.5, cy - 2, 1.3, INK) gfx.circle(cx + 4 + d * 0.5, cy - 2, 1.3, INK)
    gfx.ellipse(cx, cy + 5, 2.4, 3, INK)
  else                        -- a grump, rolling along
    gfx.circle(cx - 4, cy - 2, 2.6, C.WHITE) gfx.circle(cx + 4, cy - 2, 2.6, C.WHITE)
    gfx.circle(cx - 4 + d * 1.1, cy - 2, 1.4, INK) gfx.circle(cx + 4 + d * 1.1, cy - 2, 1.4, INK)
    gfx.line(cx - 7, cy - 6, cx - 2, cy - 4, 1.8, INK)
    gfx.line(cx + 7, cy - 6, cx + 2, cy - 4, 1.8, INK)
    gfx.line(cx - 3, cy + 5, cx + 3, cy + 5, 1.8, INK)
  end
end

-- ------------------------------------------------------------------ the hero

local hx, hy, hface, hwalk, hmode, hmood, hswat, hhurt
local function hero_body()
  local x, y = hx, hy
  local sw = sin(hwalk * 0.55) * 5
  if hmode == "walk" then
    toon.line(x - 4, y - 9, x - 4 + sw, y, 5, C.BLUE)
    toon.line(x + 4, y - 9, x + 4 - sw, y, 5, C.BLUE)
  elseif hmode == "climb" then
    local c = sin(hwalk * 0.5) * 4
    toon.line(x - 4, y - 9, x - 4, y - 2 + c, 5, C.BLUE)
    toon.line(x + 4, y - 9, x + 4, y - 2 - c, 5, C.BLUE)
  else
    toon.line(x - 4, y - 9, x - 7, y - 1, 5, C.BLUE)
    toon.line(x + 4, y - 9, x + 7, y - 3, 5, C.BLUE)
  end
  toon.rrect(x - 8, y - 23, 16, 15, 6, C.BLUE)
  -- arms
  if hmode == "climb" then
    local c = sin(hwalk * 0.5) * 5
    toon.line(x - 8, y - 20, x - 10, y - 33 + c, 4, C.SKIN)
    toon.line(x + 8, y - 20, x + 10, y - 33 - c, 4, C.SKIN)
  elseif hmode == "air" then
    toon.line(x - 8, y - 20, x - 14, y - 33, 4, C.SKIN)
    toon.line(x + 8, y - 20, x + 14, y - 33, 4, C.SKIN)
  elseif hmood == "cheer" then
    toon.line(x - 8, y - 20, x - 14, y - 34 + sin(fr() * 0.3) * 3, 4, C.SKIN)
    toon.line(x + 8, y - 20, x + 14, y - 34 - sin(fr() * 0.3) * 3, 4, C.SKIN)
  else
    toon.line(x - 8, y - 20, x - 11, y - 12 - sw * 0.3, 4, C.SKIN)
    toon.line(x + 8, y - 20, x + 11, y - 12 + sw * 0.3, 4, C.SKIN)
  end
  toon.circle(x, y - 31, 10, C.SKIN)
  toon.ellipse(x, y - 38, 12, 6, C.RED)
  toon.circle(x + hface * 7, y - 44, 3.4, GOLD)
end

-- feet at (x, y); face is -1/+1; mode "walk" "climb" "air"; mood "ok" "ouch" "cheer" "yawn" "whew"
function P.hero(x, y, face, walk_t, mode, mood, swat)
  hx, hy, hface, hwalk, hmode, hmood, hswat = x, y, face, walk_t, mode, mood, swat
  if swat then gfx.glow(x, y - 14, 38 + sin(fr() * 0.3) * 4, alpha(GOLD, 100)) end
  toon(hero_body, 2.2, INK)
  local ex = hface
  local ey = y - 31
  if mood == "ouch" then
    gfx.line(x - 6, ey - 3, x - 2, ey + 1, 1.8, INK) gfx.line(x - 2, ey - 3, x - 6, ey + 1, 1.8, INK)
    gfx.line(x + 2, ey - 3, x + 6, ey + 1, 1.8, INK) gfx.line(x + 6, ey - 3, x + 2, ey + 1, 1.8, INK)
    gfx.ellipse(x, ey + 6, 2.4, 3, INK)
  elseif mood == "yawn" then
    gfx.line(x - 6, ey, x - 2, ey, 2, INK) gfx.line(x + 2, ey, x + 6, ey, 2, INK)
    gfx.ellipse(x, ey + 6, 3.2, 3.6, INK)
    gfx.text("z", x + 14, y - 58 - (fr() * 0.2) % 8, 12, C.WHITE, "center", INK)
  elseif mood == "cheer" then
    gfx.line(x - 6, ey + 1, x - 4, ey - 2, 1.8, INK) gfx.line(x - 4, ey - 2, x - 2, ey + 1, 1.8, INK)
    gfx.line(x + 2, ey + 1, x + 4, ey - 2, 1.8, INK) gfx.line(x + 4, ey - 2, x + 6, ey + 1, 1.8, INK)
    gfx.ellipse(x, ey + 6, 3.4, 2.8, INK)
  else
    gfx.circle(x - 3.5 + ex * 1.5, ey, 1.9, INK)
    gfx.circle(x + 3.5 + ex * 1.5, ey, 1.9, INK)
    if mood == "whew" then
      gfx.ellipse(x + ex * 1.5, ey + 6, 2.2, 2.6, INK)
      gfx.circle(x + 12, ey - 6 + (fr() * 0.3) % 6, 1.8, alpha(C.CYAN, 230))
    else
      gfx.line(x - 3 + ex, ey + 5, x + ex, ey + 6.5, 1.6, INK)
      gfx.line(x + ex, ey + 6.5, x + 3 + ex, ey + 5, 1.6, INK)
    end
  end
  gfx.circle(x - 6, ey + 4, 2.2, alpha(C.ROSE, 120))
  gfx.circle(x + 6, ey + 4, 2.2, alpha(C.ROSE, 120))
  if swat then
    local sw = sin(fr() * 0.5) * 12
    local sx, sy = x + face * 20, y - 36 + sw
    gfx.line(x + face * 11, y - 18, sx, sy + 8, 4, C.WOOD)
    gfx.star(sx, sy, 13, fr() * 0.1, INK)
    gfx.star(sx, sy, 10.5, fr() * 0.1, GOLD)
  end
end

-- ------------------------------------------------------------------ the little things

local function star_pickup(x, y, k)
  local bob = sin(fr() * 0.1 + k) * 3
  gfx.glow(x, y + bob, 17, alpha(GOLD, 120))
  gfx.star(x, y + bob, 10.5, fr() * 0.03 + k, INK)
  gfx.star(x, y + bob, 8.2, fr() * 0.03 + k, GOLD)
end

local function swatter_pickup(x, y)
  local hy2 = y + sin(fr() * 0.12) * 3
  gfx.glow(x, hy2, 24, alpha(GOLD, 150))
  gfx.line(x, hy2 + 14, x, hy2 - 2, 4.5, C.WOOD)
  gfx.star(x, hy2 - 8, 15, 0.2, INK)
  gfx.star(x, hy2 - 8, 12, 0.2, GOLD)
  gfx.circle(x - 2, hy2 - 9, 1.4, INK) gfx.circle(x + 3, hy2 - 9, 1.4, INK)
end

-- the hanging cage with a friend in it (or, once the cage is open, the friend free)
local function cage(x, y, kind, mood, open_t)
  gfx.line(x, 0, x, y - 30, 2, INK)
  if open_t > 0 then
    local k = clamp(open_t / 20, 0, 1)
    gfx.line(x - 20, y + 24, x - 20 - 14 * k, y + 10 - 6 * k, 3, GOLD)
    gfx.line(x + 20, y + 24, x + 20 + 14 * k, y + 10 - 6 * k, 3, GOLD)
    gfx.rrect_o(x - 24, y + 22, 48, 8, 3, C.WOOD, INK, 2)
    return
  end
  gfx.ellipse(x, y - 28, 24, 10, GOLD)
  gfx.ring(x, y - 28, 24, 2, INK)
  for k = -2, 2 do gfx.line(x + k * 10, y - 22, x + k * 10, y + 24, 2.4, 0xf2c14e) end
  gfx.rrect_o(x - 26, y + 22, 52, 9, 3, C.WOOD, INK, 2)
end

function P.cage_friend(x, y, kind, mood, open_t, look)
  P.friend(kind, x, y, 1, mood, look)
  cage(x, y, kind, mood, open_t)
end

-- ------------------------------------------------------------------ gifts and the gallery

local function gift_icon(k, x, y, s, lit)
  if not lit then
    gfx.circle_o(x, y, 9 * s, 0x6a5a82, INK, 1.5)
    gfx.text("?", x, y - 8 * s, floor(13 * s), 0xc8bce8, "center", INK)
    return
  end
  if k == 1 then
    poly4(x - 9 * s, y + 6 * s, x + 9 * s, y + 6 * s, x + 6 * s, y - 8 * s, x - 3 * s, y - 10 * s, INK)
    poly4(x - 7 * s, y + 5 * s, x + 7 * s, y + 5 * s, x + 4 * s, y - 6 * s, x - 3 * s, y - 8 * s, 0x7fa8ff)
    gfx.circle(x + 5 * s, y - 8 * s, 3.4 * s, C.WHITE)
    gfx.rrect_o(x - 10 * s, y + 3 * s, 20 * s, 5 * s, 2, C.WHITE, INK, 1.4)
  elseif k == 2 then
    gfx.circle_o(x, y + 1 * s, 8 * s, 0xd8a060, INK, 1.6)
    gfx.circle_o(x - 6 * s, y - 7 * s, 3.2 * s, 0xd8a060, INK, 1.4)
    gfx.circle_o(x + 6 * s, y - 7 * s, 3.2 * s, 0xd8a060, INK, 1.4)
    gfx.circle(x - 3 * s, y, 1.1 * s, INK) gfx.circle(x + 3 * s, y, 1.1 * s, INK)
    gfx.ellipse(x, y + 4 * s, 3 * s, 2 * s, C.BELLY)
  else
    gfx.rrect_o(x - 10 * s, y - 7 * s, 20 * s, 15 * s, 3, 0x7a6ad8, INK, 1.6)
    gfx.star(x - 4 * s, y - 1 * s, 3.6 * s, 0.3, GOLD)
    gfx.star(x + 4 * s, y + 3 * s, 3 * s, 0.1, GOLD)
  end
end

-- The picture gallery: a frame for each friend (a portrait once rescued, a "?" until then, a gold rim for a
-- tower where every star was caught), and below it the three gifts Big Grumble has been given.
function P.gallery(x, y, w, h, small)
  local fw = (w - 16) / 3
  for k = 1, 3 do
    local fx0 = x + (k - 1) * (fw + 8)
    local n = S.g[k]
    gfx.rrect_o(fx0, y, fw, h, 10, 0x2a2058, S.pf[k] > 0 and GOLD or INK, S.pf[k] > 0 and 3.2 or 2)
    gfx.rrect(fx0 + 5, y + 5, fw - 10, h - 10, 7, n > 0 and mix(FRIENDS[k].col, 0x2a2058, 0.7) or 0x3a2e68)
    local s = small and 0.85 or 1.15
    P.friend(k, fx0 + fw / 2, y + h * 0.46, s, n > 0 and "cheer" or "hope", 0, n == 0)
    if n > 0 then
      gfx.text("x" .. n, fx0 + fw - 7, y + h - (small and 17 or 21), small and 12 or 14, C.WHITE, "right", INK)
      if S.pf[k] > 0 then gfx.star(fx0 + 12, y + 13, 7, 0.3, GOLD) end
    end
  end
  local gy0 = y + h + (small and 14 or 20)
  for k = 1, 3 do
    local ix = x + w / 2 + (k - 2) * 62
    gift_icon(k, ix, gy0, small and 0.9 or 1.15, S.rescues >= P.GIFTS[k])
    if S.rescues < P.GIFTS[k] then
      gfx.text(tostring(P.GIFTS[k] - S.rescues), ix + 14, gy0 - 3, 10, 0xc8bce8, "left", INK)
    end
  end
end

-- ------------------------------------------------------------------ the play scene

local hud_lvl, hud_lvl_txt, hud_sc, hud_sc_txt = -1, "", -1, ""
function P.hud()
  gfx.rrect_o(8, 8, 106, 26, 9, CREAM, INK, 2)
  P.friend(S.fi, 24, 22, 0.42, S.floor_i >= 4 and "cheer" or "hope", 0)
  if hud_lvl ~= S.level then hud_lvl, hud_lvl_txt = S.level, "TOWER " .. S.level end
  gfx.text(hud_lvl_txt, 74, 12, 14, INK, "center")
  for i = 1, 3 do
    local x = W / 2 - 26 + (i - 1) * 26
    gfx.heart(x, 22, 10, INK)
    gfx.heart(x, 22, 8, i <= (3 - S.hurts) and C.ROSE or C.GREY)
  end
  gfx.rrect_o(W - 110, 8, 102, 26, 9, CREAM, INK, 2)
  if hud_sc ~= S.score then hud_sc, hud_sc_txt = S.score, tostring(S.score) end
  gfx.text(hud_sc_txt, W - 59, 12, 14, INK, "center")
  -- this tower's stars, and the run of hops (the song's notes)
  for i = 1, S.nstars do
    local got = S.stars[i].got
    gfx.star(14 + (i - 1) * 15, 46, got and 6.5 or 5, 0, got and INK or alpha(INK, 160))
    gfx.star(14 + (i - 1) * 15, 46, got and 5 or 3.4, 0, got and GOLD or alpha(C.GREY, 200))
  end
  if S.swat_t > 0 then
    gfx.rrect_o(W - 110, 38, 102, 9, 4, CREAM, INK, 1.5)
    gfx.rrect(W - 107, 41, 96 * S.swat_t / 360, 3, 1, GOLD)
  end
end

local function grumble_mood()
  local m, pose = "grumpy", "down"
  if S.barrel_cool <= 46 and S.barrel_cool > 0 and S.phase == "play" then m, pose = "throw", "lift" end
  if S.throw_t > 0 then m, pose = "throw", "throw" end
  if S.hurt_cool > 40 or S.laugh_t > 0 then m, pose = "laugh", "pound" end
  if S.swat_t > 0 or S.cheer_t > 0 then m = "shock" end
  if S.floor_i >= 4 and S.phase == "play" then m = (S.hurt_cool > 40) and "laugh" or "shock" end
  if S.idle_t > 600 and m == "grumpy" then m = "sleepy" end
  if S.soft >= 2 and m == "grumpy" and S.floor_i < 3 then m = "soft" end
  return m, pose
end

-- the sleepy win: Big Grumble is won over by the friend's lullaby
local function win_mood(t)
  local m, pose = "shock", "up"
  if t > 40 then m, pose = "grumpy", "down" end
  if t > 62 then m = "soft" end
  if t > 150 then m = "yawn" end
  if t > 185 then m, pose = "asleep", "hug" end
  return m, pose
end

local GRUMBLE_X, GRUMBLE_Y = 64, FLOORS[4]
P.GRUMBLE_X = GRUMBLE_X
local CAGE_X, CAGE_Y = 128, FLOORS[4] - 66

function P.draw_play()
  local ti = S.tw
  cur_ti = ti
  scene(SCENE_KEYS[ti], paint_cur)
  -- live sparkle in the sky (a few dots, cheap)
  for i = 1, 8 do
    local a = 90 + sin(fr() * 0.06 + i * 1.7) * 90
    gfx.circle(hs(i, 31) * W, 40 + hs(i, 32) * 360, 1.4, alpha(CREAM, floor(clamp(a, 0, 255))))
  end
  if ti == 2 then
    for i = 1, 5 do
      local fxp = 40 + hs(i, 41) * (W - 80) + sin(fr() * 0.02 + i) * 24
      local fyp = 120 + hs(i, 42) * 280 + cos(fr() * 0.025 + i * 2) * 20
      gfx.glow(fxp, fyp, 9, alpha(0xfff2a0, 150))
    end
  elseif ti == 3 then
    local cx = (fr() * 0.3) % (W + 120) - 60
    gfx.ellipse(cx, 70, 46, 12, alpha(CREAM, 110))
    gfx.ellipse(cx + 20, 62, 30, 10, alpha(CREAM, 110))
  end

  -- Big Grumble
  local gm, gp, hat, ted, blk = "grumpy", "down", false, false, false
  hat, ted, blk = S.rescues >= P.GIFTS[1], S.rescues >= P.GIFTS[2], S.rescues >= P.GIFTS[3]
  if S.phase == "win" then
    gm, gp = win_mood(S.win_t)
    if S.win_t > 190 and S.gift_new == 1 then hat = true end
    if S.win_t > 190 and S.gift_new == 2 then ted = true end
    if S.win_t > 190 and S.gift_new == 3 then blk = true end
  else
    gm, gp = grumble_mood()
  end
  local lx = clamp((S.px - GRUMBLE_X) / 70, -1, 1) * 1.6
  local ly = clamp((S.py - FLOORS[4]) / 160, -1, 1) * 1.5
  local bob = (gm == "asleep" or gm == "yawn") and sin(fr() * 0.05) * 1.5 or sin(fr() * 0.1) * 1.2
  local shake = (gm == "throw" or gm == "laugh") and sin(fr() * 0.9) * 1.2 or 0
  P.grumble(GRUMBLE_X + shake, GRUMBLE_Y + bob, 1.0, gm, gp, S.soft, lx, ly, hat, ted, blk)
  if gp == "lift" then held_barrel(GRUMBLE_X + 38, GRUMBLE_Y - 84, 1, ti) end
  if S.phase == "win" and S.win_t > 190 then   -- the dream bubble: the friends all together
    local k = ease.out_back(seg(S.win_t, 190, 215))
    local bx, by = 184, 50
    gfx.circle_o(GRUMBLE_X + 36, FLOORS[4] - 96, 3 * k, CREAM, INK, 1.2)
    gfx.circle_o(GRUMBLE_X + 62, FLOORS[4] - 104, 5 * k, CREAM, INK, 1.2)
    gfx.rrect_o(bx - 30 * k, by - 4 * k, 96 * k, 48 * k, 18, CREAM, INK, 2)
    if k > 0.9 then
      if S.level >= 3 then
        for j = 1, 3 do P.friend(j, bx - 8 + (j - 1) * 28, by + 20, 0.42, "cheer", 0) end
      else
        P.friend(S.fi, bx + 18, by + 20, 0.55, "cheer", 0)
      end
      gfx.heart(bx + 54, by + 8, 7, C.ROSE)
    end
  end

  -- the friend in the cage, watching the hero climb
  local fmood = "hope"
  if S.floor_i <= 1 or S.hurt_cool > 60 then fmood = "worry" elseif S.floor_i >= 3 then fmood = "cheer" end
  local flx = clamp((S.px - CAGE_X) / 120, -1, 1) * 1.6
  if S.phase == "win" then
    local open_t = S.win_t
    local k = seg(S.win_t, 0, 30)
    local fyy = CAGE_Y + (S.win_t < 60 and -sin(k * 3.14) * 24 or 0)
    local fxx = CAGE_X
    if S.win_t > 60 then   -- flies to Big Grumble's shoulder and sings
      local m2 = seg(S.win_t, 60, 100)
      fxx = lerp(CAGE_X, GRUMBLE_X + 36, ease.in_out(m2))
      fyy = lerp(CAGE_Y, GRUMBLE_Y - 96, ease.in_out(m2)) + sin(fr() * 0.15) * 3
    end
    P.friend(S.fi, fxx, fyy, 1, S.win_t > 60 and "sing" or "cheer", 0)
    cage(CAGE_X, CAGE_Y, S.fi, "cheer", open_t)
    if S.win_t > 100 and S.win_t < 240 and S.win_t % 14 < 7 then
      local nk = (S.win_t - 100) / 14
      gfx.text("~", fxx + 14 + nk % 3 * 8, fyy - 22 - nk % 4 * 6, 18, C.WHITE, "center", INK)
    end
  else
    P.cage_friend(CAGE_X, CAGE_Y, S.fi, fmood, 0, flx)
  end

  -- pick-ups
  for i = 1, S.nstars do
    local st = S.stars[i]
    if not st.got then star_pickup(st.x, st.y, i) end
  end
  if S.swatter and not S.swatter.gone then swatter_pickup(S.swatter.x, S.swatter.y) end

  -- barrels
  for i = 1, #S.barrels do draw_barrel(S.barrels[i], ti) end

  -- the hero
  if not (S.hurt_cool > 0 and idiv(S.hurt_cool, 4) % 2 == 1) then
    local mode = S.climbing and "climb" or (S.on_ground and "walk" or "air")
    local mood = "ok"
    if S.hurt_cool > 50 then mood = "ouch"
    elseif S.phase == "win" then mood = "cheer"
    elseif S.whew_t > 0 then mood = "whew"
    elseif S.idle_t > 480 then mood = "yawn"
    elseif S.cheer_t > 0 then mood = "cheer" end
    P.hero(S.px, S.py, S.face, S.walk_t, mode, mood, S.swat_t > 0)
  end
  if S.whew_t > 0 and S.phase == "play" then
    gfx.text("whew!", S.px, S.py - 62 - (30 - min(S.whew_t, 30)) * 0.4, 14, C.WHITE, "center", INK)
  end
  P.hud()
end

-- the card that rolls up when a tower is won
function P.win_panel()
  local last = S.level >= 3
  if S.win_t < 200 then return end
  local k = ease.out_back(seg(S.win_t, 200, 226))
  local y0 = 214 + (1 - k) * 260
  gfx.rrect_o(24, y0, W - 48, 204, 16, CREAM, INK, 3)
  gfx.text(last and "ALL CLEAR!" or "TOWER CLEAR!", W / 2, y0 + 8, 26, GOLD, "center", INK)
  gfx.text(FRIENDS[S.fi].name .. " is free!", W / 2, y0 + 42, 15, C.PURPLE, "center")
  gfx.text("SCORE " .. S.score .. "   BEST " .. S.best, W / 2, y0 + 62, 13, INK, "center")
  P.gallery(38, y0 + 86, W - 76, 62, true)
  if S.perfect_now then
    gfx.text("EVERY STAR! Gold frame!", W / 2, y0 + 178, 12, C.RED, "center")
  end
  if S.gift_new > 0 then
    gfx.text("Big Grumble got " .. P.GIFT_NAMES[S.gift_new] .. "!", W / 2, y0 + 178, 12, C.PURPLE, "center")
  elseif last then
    gfx.text("Next hero starts a new run!", W / 2, y0 + 178, 12, INK, "center")
  end
end

-- ------------------------------------------------------------------ the story

local STORY_LINES = {
  {0, "Big Grumble is so very sleepy."},
  {95, "But his little friends are SO giggly!"},
  {172, "Grumble got grumpy and locked them up!"},
  {262, "Climb up, hop the barrels, sing him to sleep!"},
}
function P.story_line(t)
  local l = STORY_LINES[1][2]
  for i = 1, #STORY_LINES do if t >= STORY_LINES[i][1] then l = STORY_LINES[i][2] end end
  return l
end

local STORY_CAGE_X = {58, 192, 326}
local function sprite_orbit(k, t, cx, cy, r, sp)
  local a = t * sp + k * 2.094
  return cx + cos(a) * r, cy + sin(a) * r * 0.55
end

function P.story(t)
  scene("story", paint_story)
  for i = 1, 6 do
    local a = 90 + sin(fr() * 0.06 + i * 1.7) * 90
    gfx.circle(hs(i, 51) * W, 30 + hs(i, 52) * 250, 1.5, alpha(CREAM, floor(clamp(a, 0, 255))))
  end
  local ti = 1
  local woke = t >= 95
  local locked = seg(t, 172, 235)
  -- Big Grumble, big in the middle
  local gm, gp = "sleep", "down"
  if t >= 95 and t < 130 then gm = "shock" end
  if t >= 130 then gm = "grumpy" end
  if t >= 172 and t < 240 then gm, gp = "throw", "up" end
  if t >= 240 then gm, gp = "grumpy", "pound" end
  if t >= 270 then gm = (t % 120 < 14) and "shock" or "grumpy" end
  local shake = (t >= 100 and t < 130 or t >= 172 and t < 240) and sin(t * 0.9) * 2 or 0
  local gy0 = 372
  if t < 172 then   -- he sleeps on a big pillow
    gfx.ellipse(192, gy0 + 4, 92, 17, 0xf4e8f8)
    gfx.ellipse(192, gy0 + 4, 92, 17, alpha(0xc8a8e8, 90))
    gfx.ellipse(192, gy0 - 2, 78, 10, 0xfff6ff)
  end
  if t >= 172 then   -- the barrels he is going to roll
    for i = 0, 2 do held_barrel(310 + i * 26 - (i == 2 and 13 or 0), gy0 - 12 - (i == 2 and 24 or 0), 1.15, 1) end
  end
  P.grumble(192 + shake, gy0 + (gm == "sleep" and sin(t * 0.05) * 2 or 0), 1.7, gm, gp, 0, 0, 0)
  if t >= 172 and t < 240 and t % 24 < 12 then
    gfx.text("GRRR!", 86, 236, 28, C.RED, "center", INK)
  end
  -- three giggly friends
  local giggle = seg(t, 40, 95)
  for k = 1, 3 do
    if t < 172 then
      local x, y = sprite_orbit(k, t, 192, 230, lerp(120, 150, giggle), lerp(0.012, 0.05, giggle))
      if t >= 40 and t % 30 < 10 and k == 2 then gfx.text("ha!", x + 16, y - 30, 14, C.WHITE, "center", INK) end
      if t >= 95 and t % 24 < 8 then gfx.text("ha ha", x, y - 32, 13, C.WHITE, "center", INK) end
      P.friend(k, x, y, 1, t < 95 and "hope" or "cheer", clamp((192 - x) / 100, -1, 1))
    else
      local ox, oy = sprite_orbit(k, 172, 192, 230, 150, 0.05)
      local m = ease.in_out(clamp(locked * 1.5, 0, 1))
      local x = lerp(ox, STORY_CAGE_X[k], m)
      local y = lerp(oy, 140 + (k == 2 and 22 or 0), m)
      P.friend(k, x, y, 1, "worry", 0)
      if locked > 0.45 then cage(x, y, k, "worry", 0) end
    end
  end
  if t >= 262 then   -- the hero walks in with the Star Swatter
    local k = ease.out_cubic(seg(t, 258, 310))
    local hx2 = lerp(-20, 78, k)
    P.hero(hx2, 372, 1, t * 0.9, "walk", "ok", t >= 300)
    if k >= 1 then gfx.text("!", 100, 300, 20, GOLD, "center", INK) end
    local a = seg(t, 290, 320)
    gfx.rrect_o(10, 390, W - 20, 90, 14, alpha(0x2a2058, floor(230 * a)), alpha(INK, floor(255 * a)), 2)
    if a > 0.7 then
      P.gallery(20, 398, W - 40, 56, true)
    end
  end
end

return P
