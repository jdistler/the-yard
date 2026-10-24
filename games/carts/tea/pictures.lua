-- Tea's pictures. main.lua owns the rules and fills P.st; everything here only draws.
local P = {}

local BAND, LANE_X = 32, 108
local C = {
  SKY = 0x8ec6ff, CREAM = 0xfff6ea, CASTLE = 0xf4b6d0, ROOF = 0xe86b9a, GOLD = 0xf2c14e, MINT = 0x7ec8c3,
  LILAC = 0xb9a0e8, TEA = 0xc9865a, ORANGE = 0xf29a3a, GREY = 0x8a8f9c, INK = 0x3a2a44, WHITE = 0xfffcf8,
  BLUSH = alpha(0xff8fb0, 120),
}
P.C = C
local INK = C.INK
local STRIPES = {0xf2c14e, 0xe86b9a, 0x7ec8c3, 0xb9a0e8}
local BALLOONS = {0xe86b9a, 0x7ec8c3, 0xb9a0e8, 0xf2c14e, 0x8ac8ff}
function P.balloon_col(i) return BALLOONS[i % 5 + 1] end

local function fr() return game.frame end

-- ------------------------------------------------------------------ small pictures, about 40 px at s = 1

function P.icon(what, cx, cy, s)
  if what == "sparkle" then
    gfx.glow(cx, cy, 28 * s, alpha(0xffe080, 140))
    gfx.star(cx, cy, 15 * s * (1 + 0.1 * sin(fr() * 0.2)), fr() * 0.03, C.GOLD)
    return
  end
  if what == "star" then
    gfx.star(cx, cy, 15 * s, 0, INK)
    gfx.star(cx, cy, 12 * s, 0, C.GOLD)
    gfx.circle(cx - 3 * s, cy - 3 * s, 2.5 * s, alpha(0xffffff, 200))
    return
  end
  if what == "hug" then
    gfx.heart(cx, cy, 15 * s, INK)
    gfx.heart(cx, cy, 12.5 * s, C.ROOF)
    gfx.circle(cx - 6 * s, cy - 6 * s, 3 * s, alpha(0xffffff, 200))
    return
  end
  toon(function()
    local fill = toon.fill()
    if what == "cup" then
      toon.ellipse(cx, cy + 12 * s, 18 * s, 4 * s, 0xffd0e6)
      toon.rrect(cx - 13 * s, cy - 8 * s, 26 * s, 20 * s, 7 * s, C.WHITE)
      toon.circle(cx + 15 * s, cy + 1 * s, 6 * s, C.WHITE)
      if fill then
        gfx.circle(cx + 15 * s, cy + 1 * s, 3 * s, C.SKY)
        gfx.ellipse(cx, cy - 6 * s, 11 * s, 3 * s, C.TEA)
        gfx.rect(cx - 12 * s, cy + 1 * s, 24 * s, 4 * s, C.ROOF)
      end
    elseif what == "yarn" then
      toon.circle(cx, cy, 15 * s, C.GOLD)
      if fill then
        gfx.line(cx - 12 * s, cy - 6 * s, cx + 8 * s, cy + 12 * s, 2 * s, 0xd89a2a)
        gfx.line(cx - 6 * s, cy - 13 * s, cx + 13 * s, cy + 6 * s, 2 * s, 0xd89a2a)
        gfx.line(cx - 14 * s, cy + 3 * s, cx + 2 * s, cy + 14 * s, 2 * s, 0xd89a2a)
        gfx.line(cx + 12 * s, cy + 8 * s, cx + 22 * s, cy + 14 * s, 2 * s, C.GOLD)
      end
    elseif what == "flower" then
      toon.line(cx, cy + 4 * s, cx, cy + 20 * s, 3 * s, 0x5ab05a)
      for k = 0, 4 do
        local a = k * 1.2566 + fr() * 0.01
        toon.circle(cx + cos(a) * 8 * s, cy + sin(a) * 8 * s, 7 * s, C.ROOF)
      end
      toon.circle(cx, cy, 6 * s, C.GOLD)
    elseif what == "cake" then
      toon.rrect(cx - 12 * s, cy, 24 * s, 14 * s, 3 * s, 0xf4b070)
      toon.ellipse(cx, cy - 1 * s, 15 * s, 9 * s, 0xffd0e6)
      toon.circle(cx, cy - 11 * s, 4.5 * s, 0xff4060)
      if fill then
        for k = 0, 3 do
          gfx.line(cx - 8 * s + k * 5.5 * s, cy + 2 * s, cx - 9 * s + k * 5.5 * s, cy + 12 * s, 1.5 * s, 0xd08a50)
        end
        gfx.circle(cx - 6 * s, cy - 3 * s, 1.5 * s, C.MINT)
        gfx.circle(cx + 5 * s, cy - 4 * s, 1.5 * s, C.GOLD)
        gfx.circle(cx + 1 * s, cy + 1 * s, 1.5 * s, C.LILAC)
      end
    elseif what == "note" then
      toon.ellipse(cx - 6 * s, cy + 10 * s, 7 * s, 5.5 * s, C.LILAC)
      toon.line(cx, cy + 9 * s, cx, cy - 14 * s, 3 * s, C.LILAC)
      toon.line(cx, cy - 14 * s, cx + 10 * s, cy - 8 * s, 4 * s, C.LILAC)
    elseif what == "balloon" then
      toon.ellipse(cx, cy - 4 * s, 12 * s, 15 * s, C.ROOF)
      toon.tri(cx - 3 * s, cy + 13 * s, cx + 3 * s, cy + 13 * s, cx, cy + 9 * s, C.ROOF)
      if fill then gfx.ellipse(cx - 4 * s, cy - 9 * s, 3 * s, 5 * s, alpha(0xffffff, 170)) end
    end
  end, 2 * s, INK)
end

function P.balloon(x, y, s, c)
  toon(function()
    toon.ellipse(x, y, 13 * s, 16 * s, c)
    toon.tri(x - 3 * s, y + 18 * s, x + 3 * s, y + 18 * s, x, y + 14 * s, c)
  end, 2 * s, INK)
  gfx.ellipse(x - 4 * s, y - 6 * s, 3 * s, 5 * s, alpha(0xffffff, 170))
end

local function cloud(x, y, s, squish)
  local sq = 1 - squish * 0.3
  gfx.ellipse(x, y + 8 * s, 34 * s, 10 * s * sq, alpha(0xc8d8f8, 160))
  gfx.circle(x - 18 * s, y, 15 * s * sq, C.CREAM)
  gfx.circle(x + 16 * s, y + 1 * s, 17 * s * sq, C.CREAM)
  gfx.circle(x, y - 8 * s * sq, 20 * s * sq, C.CREAM)
  gfx.ellipse(x, y + 6 * s, 30 * s, 9 * s * sq, C.CREAM)
  gfx.circle(x - 6 * s, y - 14 * s * sq, 7 * s, C.WHITE)
end

function P.castle(cx, base, s, door)
  local ww, wh = 200 * s, 110 * s
  local flag = sin(fr() * 0.12) * 4 * s
  toon(function()
    -- Side towers, the wall, the middle tower.
    toon.rrect(cx - ww / 2 - 18 * s, base - wh - 40 * s, 44 * s, wh + 40 * s, 4 * s, C.CASTLE)
    toon.rrect(cx + ww / 2 - 26 * s, base - wh - 40 * s, 44 * s, wh + 40 * s, 4 * s, C.CASTLE)
    toon.rrect(cx - ww / 2, base - wh, ww, wh, 4 * s, C.CASTLE)
    toon.rrect(cx - 34 * s, base - wh - 70 * s, 68 * s, wh + 70 * s, 4 * s, C.CASTLE)
    toon.tri(cx - ww / 2 - 24 * s, base - wh - 40 * s, cx - ww / 2 + 4 * s, base - wh - 96 * s, cx - ww / 2 + 32 * s, base - wh - 40 * s, C.ROOF)
    toon.tri(cx + ww / 2 - 32 * s, base - wh - 40 * s, cx + ww / 2 - 4 * s, base - wh - 96 * s, cx + ww / 2 + 24 * s, base - wh - 40 * s, C.ROOF)
    toon.tri(cx - 42 * s, base - wh - 70 * s, cx, base - wh - 140 * s, cx + 42 * s, base - wh - 70 * s, C.ROOF)
    toon.line(cx, base - wh - 140 * s, cx, base - wh - 164 * s, 2 * s, INK)
    toon.tri(cx, base - wh - 164 * s, cx + 22 * s, base - wh - 158 * s + flag, cx, base - wh - 150 * s, C.GOLD)
    -- The door: an arch. Open, it is warm light.
    toon.rrect(cx - 20 * s, base - 50 * s, 40 * s, 50 * s, 18 * s, door > 0 and 0xffe7a8 or C.GOLD)
  end, max(1, 2.5 * s), INK)
  if s > 0.25 then
    for k = 0, 5 do
      gfx.rect(cx - ww / 2 + 6 * s + k * 34 * s, base - wh - 8 * s, 16 * s, 8 * s, shade(C.CASTLE, 0.92))
    end
    local t = max(1, 2 * s)
    gfx.rrect_o(cx - 12 * s, base - wh - 40 * s, 24 * s, 28 * s, 10 * s, C.MINT, INK, t)
    gfx.star(cx, base - wh - 26 * s, 7 * s, 0, C.GOLD)
    gfx.rrect_o(cx - ww / 2 - 6 * s, base - wh - 10 * s, 20 * s, 24 * s, 8 * s, C.MINT, INK, t)
    gfx.rrect_o(cx + ww / 2 - 14 * s, base - wh - 10 * s, 20 * s, 24 * s, 8 * s, C.MINT, INK, t)
  end
  if door > 0 then
    -- Two leaves swing open, light spills out.
    local lw = 20 * s * (1 - door)
    gfx.glow(cx, base - 22 * s, 70 * s * door, alpha(0xffd070, 160))
    if lw >= 2 then
      gfx.rrect_o(cx - 20 * s, base - 50 * s, lw, 50 * s, 4 * s, C.GOLD, INK, max(1, 2 * s))
      gfx.rrect_o(cx + 20 * s - lw, base - 50 * s, lw, 50 * s, 4 * s, C.GOLD, INK, max(1, 2 * s))
    end
  end
end

-- ------------------------------------------------------------------ the unicorn, seen from behind

local function unicorn(x, y, s, flying, flap, pose, t)
  local wa = flying and flap or -0.3
  local head_t = pose == 2 and 8 * s or 0
  toon(function()
    -- Wings: puffs along an arm from each shoulder.
    for side = -1, 1, 2 do
      local ang = flying and 0.45 + wa * 0.75 or -0.35
      local len = flying and 1 or 0.45
      for k = 3, 0, -1 do
        local d = (14 + k * 13) * s * len
        toon.circle(x + side * (20 * s + cos(ang) * d), y - 10 * s - sin(ang) * d, (13 - k * 2) * s * (flying and 1 or 0.7), k == 3 and C.LILAC or C.WHITE)
      end
    end
    -- Tail: four stripes.
    for k = 0, 3 do
      local sw = sin(t * 0.08 + k * 0.4) * 5 * s
      toon.line(x - 6 * s + k * 4 * s, y + 24 * s, x - 10 * s + k * 7 * s + sw, y + 52 * s, 6 * s, STRIPES[k + 1])
    end
    -- Legs: tucked in the air, standing on the floor.
    if flying then
      toon.rrect(x - 22 * s, y + 22 * s, 12 * s, 12 * s, 5 * s, C.WHITE)
      toon.rrect(x + 10 * s, y + 22 * s, 12 * s, 12 * s, 5 * s, C.WHITE)
    else
      toon.rrect(x - 24 * s, y + 18 * s, 13 * s, 34 * s, 5 * s, C.WHITE)
      toon.rrect(x + 11 * s, y + 18 * s, 13 * s, 34 * s, 5 * s, C.WHITE)
      toon.rrect(x - 25 * s, y + 46 * s, 15 * s, 8 * s, 3 * s, C.LILAC)
      toon.rrect(x + 10 * s, y + 46 * s, 15 * s, 8 * s, 3 * s, C.LILAC)
    end
    toon.ellipse(x, y + 8 * s, 32 * s, 27 * s, C.WHITE)
    -- Head from behind, the horn up, ears, the mane falling down the back.
    toon.ellipse(x + head_t, y - 28 * s, 17 * s, 19 * s, C.WHITE)
    toon.tri(x - 14 * s + head_t, y - 38 * s, x - 9 * s + head_t, y - 56 * s, x - 3 * s + head_t, y - 42 * s, C.WHITE)
    toon.tri(x + 14 * s + head_t, y - 38 * s, x + 9 * s + head_t, y - 56 * s, x + 3 * s + head_t, y - 42 * s, C.WHITE)
    toon.tri(x - 4.5 * s + head_t, y - 44 * s, x + head_t, y - 76 * s, x + 4.5 * s + head_t, y - 44 * s, C.GOLD)
    for k = 0, 3 do
      local sx = x + head_t + (-9 + k * 6) * s
      toon.line(sx, y - 40 * s, sx - head_t * 0.5 + (k - 1.5) * 2 * s, y - 2 * s, 6 * s, STRIPES[k + 1])
    end
  end, 2.5 * s, INK)
  gfx.line(x - 2 * s + head_t, y - 52 * s, x + 2 * s + head_t, y - 54 * s, 1.5 * s, 0xd8a03a)
  gfx.line(x - 3 * s + head_t, y - 60 * s, x + 1.5 * s + head_t, y - 62 * s, 1.5 * s, 0xd8a03a)
  gfx.ellipse(x - 8 * s + head_t, y - 48 * s, 2 * s, 4 * s, alpha(0xffb0c8, 200))
  gfx.ellipse(x + 8 * s + head_t, y - 48 * s, 2 * s, 4 * s, alpha(0xffb0c8, 200))
end

-- She is the most drawn thing in the game. Her wing beat and tail sway are cut into eight
-- steps, and each step is painted once into a layer, per pose and size.
local STEPS = 8
function P.unicorn_at(x, y, s, flying, flap, pose)
  local st = P.st
  local step = floor((flap / 0.7 + 1) * 0.5 * (STEPS - 1) + 0.5) % STEPS
  local hop = pose == 3 and -abs(sin(fr() * 0.25)) * 16 * s or 0
  local head_t = pose == 2 and 8 * s or 0
  local cw, ch = floor(170 * s), floor(170 * s)
  local ox, oy = idiv(cw, 2), floor(90 * s)
  local p = pose == 3 and 0 or pose
  if flying then gfx.ellipse(x, y + 70 * s, 34 * s, 7 * s, alpha(0x5a7ab0, 60)) end
  stamp(fmt("uni:%s:%d:%d:%.2f", flying and "f" or "s", p, step, s), cw, ch, ox, oy, x, y + hop, function()
    unicorn(0, 0, s, flying, -0.7 + 1.4 * step / (STEPS - 1), p, step * 10)
  end)
  if pose == 2 or pose == 3 or st.hurry then
    gfx.glow(x + head_t, y + hop - 76 * s, 18 * s, alpha(0xffe080, 200))
    if fr() % 3 == 0 then
      particles.spawn(x + head_t + rnd(-6, 6), y + hop - 76 * s, rnd(-1, 1), rnd(-1.5, -0.3), 30, rnd(2, 4), hsv(rnd(), 0.35, 1), "star")
    end
  end
end

-- ------------------------------------------------------------------ the cats

local BODY = {C.ORANGE, C.GREY, C.WHITE, C.CREAM}
local DARK = {0xd87a20, 0x666a78, 0xe8dccc, C.ORANGE}
local PIP, MOTH, PEARL, NIB = 1, 2, 3, 4

function P.cat(who, cx, cy, s, happy)
  local st = P.st
  local body, dark = BODY[who], DARK[who]
  local r = (who == NIB and 20 or 27) * s
  local blink = ((fr() + (who - 1) * 47) % 200) < 7
  local twirl = 1
  local tail = sin(fr() * 0.07 + who - 1) * 0.6
  if happy and st.care_kind[who] == "flower" and st.delight[who] > 0 then
    twirl = 0.75 + 0.25 * abs(cos(st.delight[who] * 0.2))
  end
  local ear = who == MOTH and 1.45 or 1.25
  toon(function()
    -- Tail: curls out from behind the hip.
    toon.line(cx + r * 0.7, cy + r * 1.95, cx + r * 1.4, cy + r * 1.95, 8 * s, body)
    toon.line(cx + r * 1.4, cy + r * 1.95, cx + r * 1.62 + tail * r * 0.15, cy + r * 1.62, 8 * s, body)
    toon.circle(cx + r * 1.62 + tail * r * 0.15, cy + r * 1.58, 4.5 * s, who == PEARL and C.WHITE or dark)
    toon.ellipse(cx, cy + r * 1.35, r * 1.05 * twirl, r * 0.9, body)
    toon.tri(cx - r * 0.95 * twirl, cy - r * 0.2, cx - r * 0.75 * twirl, cy - r * ear, cx - r * 0.2 * twirl, cy - r * 0.8, body)
    toon.tri(cx + r * 0.95 * twirl, cy - r * 0.2, cx + r * 0.75 * twirl, cy - r * ear, cx + r * 0.2 * twirl, cy - r * 0.8, body)
    toon.ellipse(cx, cy, r * twirl, r * 0.92, body)
  end, 2.5, INK)
  gfx.tri(cx - r * 0.78 * twirl, cy - r * 0.35, cx - r * 0.7 * twirl, cy - r * 1.0, cx - r * 0.38 * twirl, cy - r * 0.68, 0xffb8c8)
  gfx.tri(cx + r * 0.78 * twirl, cy - r * 0.35, cx + r * 0.7 * twirl, cy - r * 1.0, cx + r * 0.38 * twirl, cy - r * 0.68, 0xffb8c8)
  -- Markings.
  if who == MOTH then
    for k = -1, 1 do gfx.line(cx + k * r * 0.25, cy - r * 0.85, cx + k * r * 0.2, cy - r * 0.5, 3 * s, dark) end
  end
  if who == PIP then gfx.ellipse(cx, cy + r * 0.38, r * 0.55 * twirl, r * 0.4, C.CREAM) end
  if who == NIB then
    gfx.ellipse(cx - r * 0.45, cy - r * 0.35, r * 0.3, r * 0.35, C.ORANGE)
    gfx.circle(cx + r * 0.3, cy + r * 1.3, r * 0.35, C.ORANGE)
  end
  -- Eyes: open, blinking, or happy arcs.
  local ex, ey = r * 0.38 * twirl, cy - r * 0.08
  if happy then
    for k = -1, 1, 2 do
      gfx.line(cx + k * ex - 5 * s, ey + 2, cx + k * ex, ey - 3 * s, 2.5 * s, INK)
      gfx.line(cx + k * ex, ey - 3 * s, cx + k * ex + 5 * s, ey + 2, 2.5 * s, INK)
    end
  elseif blink then
    gfx.line(cx - ex - 5 * s, ey, cx - ex + 5 * s, ey, 2.5 * s, INK)
    gfx.line(cx + ex - 5 * s, ey, cx + ex + 5 * s, ey, 2.5 * s, INK)
  else
    local look = (st.uni_x - cx) * 0.01
    for k = -1, 1, 2 do
      gfx.ellipse(cx + k * ex + look, ey, 5 * s, 6.5 * s, INK)
      gfx.circle(cx + k * ex + look + 1.5 * s, ey - 2.5 * s, 1.8 * s, C.WHITE)
    end
  end
  gfx.ellipse(cx - r * 0.6 * twirl, cy + r * 0.3, 5 * s, 3 * s, C.BLUSH)
  gfx.ellipse(cx + r * 0.6 * twirl, cy + r * 0.3, 5 * s, 3 * s, C.BLUSH)
  gfx.tri(cx - 3.5 * s, cy + r * 0.2, cx + 3.5 * s, cy + r * 0.2, cx, cy + r * 0.32, C.ROOF)
  -- A cat smile: a small w under the nose, wider when happy.
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
  if who == PEARL then
    gfx.tri(cx + r * 0.35, cy - r * 0.75, cx + r * 0.75, cy - r * 0.95, cx + r * 0.7, cy - r * 0.5, C.GOLD)
    gfx.tri(cx + r * 0.35, cy - r * 0.75, cx + r * 0.05, cy - r * 1.0, cx + r * 0.1, cy - r * 0.55, C.GOLD)
    gfx.circle_o(cx + r * 0.38, cy - r * 0.75, 3.5 * s, C.GOLD, INK, 1.5)
  end
  -- Gifts she gave last time, worn from the first frame.
  if st.gift[who] == "flower" then
    for k = 0, 4 do
      local a = k * 1.2566
      gfx.circle(cx - r * 0.5 + cos(a) * 5 * s, cy - r * 0.8 + sin(a) * 5 * s, 4 * s, C.ROOF)
    end
    gfx.circle(cx - r * 0.5, cy - r * 0.8, 3 * s, C.GOLD)
  end
  if st.gift[who] == "teacup" then
    gfx.rect(cx - r * 0.6, cy + r * 0.82, r * 1.2, 4 * s, C.ROOF)
    gfx.rrect_o(cx - 6 * s, cy + r * 0.9, 12 * s, 9 * s, 3 * s, C.WHITE, INK, 1.5)
  end
  -- A sip, a bite: the cup or the cupcake at the mouth, then a milk mustache or crumbs.
  local kind, d = st.care_kind[who], st.delight[who]
  if d > 0 and (kind == "cup" or kind == "cake") then
    if d > 24 then
      P.icon(kind, cx + 4 * s, cy + r * 0.55, 0.5 * s)
    elseif kind == "cup" then
      gfx.ellipse(cx, cy + r * 0.42, r * 0.4, 3 * s, C.WHITE)
    else
      for k = 0, 3 do gfx.circle(cx - 6 * s + k * 4 * s, cy + r * 0.5 + (k % 2) * 2 * s, 1.5 * s, 0xe8b070) end
    end
  end
end

local function hearts_row(who, cx, y)
  local st = P.st
  for i = 1, 3 do
    local x = cx - 32 + (i - 1) * 32
    local pop = (i == st.hearts[who] and st.heart_pop[who] > 0) and 1 + 0.6 * sin(st.heart_pop[who] * 0.18) or 1
    gfx.heart(x, y, 12.5 * pop, INK)
    gfx.heart(x, y, 10 * pop, i <= st.hearts[who] and C.ROOF or C.CREAM)
    if i <= st.hearts[who] then gfx.circle(x - 4.5 * pop, y - 4.5 * pop, 2.2 * pop, alpha(0xffffff, 190)) end
  end
end

-- ------------------------------------------------------------------ the flight

local function treat_s(t) return 0.35 + t.z * 1.35 end

local function draw_treat(t)
  local st = P.st
  local s, x, y = treat_s(t), P.treat_x(t), P.treat_y(t) + sin(fr() * 0.1 + t.color) * 4 * t.z
  if t.on == 2 then
    -- Into the basket: an arc down to its slot, shrinking.
    local k = ease.in_out(t.fly_t / 26)
    local bx, by = 22 + (t.slot - 1) * 26, H - BAND - 18
    s = lerp(1.2, 0.5, k)
    x = lerp(t.fx, bx, k)
    y = lerp(t.fy, by, k) - sin(k * math.pi) * 50
  end
  if t.z > 0.2 then gfx.glow(x, y, 26 * s, alpha(0xfff0b0, 110)) end
  if t.kind == "balloon" then P.balloon(x, y, s, P.balloon_col(t.color)) else P.icon(t.kind, x, y, s) end
end

local function draw_basket()
  local st = P.st
  if #st.basket == 0 then return end
  gfx.rrect(6, H - BAND - 36, 18 + #st.basket * 26, 34, 12, alpha(0xfff6ea, 210))
  for i, kind in ipairs(st.basket) do
    local x, y = 22 + (i - 1) * 26, H - BAND - 18
    local flying = false
    if st.phase == "sky" then
      for _, t in ipairs(st.treats) do if t.on == 2 and t.slot == i then flying = true end end
    end
    if not flying then
      if kind == "balloon" then P.balloon(x, y - 1, 0.5, P.balloon_col(i - 1)) else P.icon(kind, x, y, 0.5) end
    end
  end
end

local castle_key
function P.draw_sky()
  local st = P.st
  local prog = st.fly / (480 * 900)
  backdrop("sky", function()
    gfx.vgrad(0, 0, W, H - BAND, 0x7ab8ff, 0xd8ecff)
    gfx.glow(W / 2, 120, 160, alpha(0xfff0d0, 90))
  end)
  local RB = {0xff8a8a, 0xffc070, 0xfff08a, 0x9ae6a0, 0x8ac8ff, 0xc0a0f0}
  local top, far_w = 150 + prog * 40, 4 + prog * 10
  for k = 0, 5 do
    local a0, a1 = (k - 3) / 3, (k - 2) / 3
    gfx.poly({W / 2 + a0 * far_w, top, W / 2 + a1 * far_w, top, W / 2 + a1 * 150, H - BAND, W / 2 + a0 * 150, H - BAND}, alpha(RB[k + 1], 150))
  end
  for i = 1, 5 do
    local t = i / 6
    local y = lerp(H - BAND - 20, top + 10, t)
    local lit = prog > t
    if lit then gfx.glow(W / 2, y, 16, alpha(0xffe080, 200)) end
    gfx.star(W / 2, y, 7 - t * 3, 0, lit and C.GOLD or alpha(C.WHITE, 160))
  end
  -- The castle grows as she nears. It is painted once per size step.
  local q = floor((0.22 + prog * 0.55) * 100) / 100
  local cw = floor(300 * q) + 8
  local key = "castle:" .. q
  if castle_key and castle_key ~= key then unbake(castle_key) end
  castle_key = key
  gfx.blit_key(bake(key, cw, cw, function() P.castle(cw / 2, cw - 4, q, 0) end), floor(W / 2 - cw / 2), floor(150 + prog * 40 - cw + 4))
  for pass = 0, 1 do
    for _, c in ipairs(st.clouds) do
      local z = c.z
      if (pass == 0) == (z < 0.6) then
        local d = z * z * 340
        cloud(W / 2 + cos(c.a) * d * 1.2, 140 + sin(c.a) * d * 0.7 + z * 60, 0.25 + z * 1.3, c.squish)
      end
    end
  end
  -- Far treats behind her, near ones in front.
  for _, t in ipairs(st.treats) do if t.on == 1 and t.z <= 0.6 then draw_treat(t) end end
  if st.sparkle_t > 0 then gfx.glow(st.uni_x, 320, 90, alpha(0xffe8a0, floor(st.sparkle_t * 2.5))) end
  P.unicorn_at(st.uni_x, 330 - abs(st.tilt) * 10, 1.15, true, st.wing, st.sparkle_t > 0 and 2 or 0)
  draw_basket()
  for _, t in ipairs(st.treats) do if (t.on == 1 and t.z > 0.6) or t.on == 2 then draw_treat(t) end end
end

-- ------------------------------------------------------------------ the door

local function runner()
  local st = P.st
  for i = 1, st.ncats do if st.gift[i] ~= "none" then return i end end
end

function P.draw_door()
  local st = P.st
  local k = clamp(st.door_t / 30, 0, 1)
  local who = runner()
  backdrop("door", function()
    gfx.vgrad(0, 0, W, H - BAND, 0x7ab8ff, 0xd8ecff)
    gfx.vgrad(0, 300, W, H - BAND - 300, 0x9ae0a0, 0x6ac080)
  end)
  P.castle(W / 2, 300, 1.4, ease.out_cubic(k))
  for i = 1, st.ncats do
    local peek = clamp((st.door_t - 24 - (i - 1) * 6) / 14, 0, 1)
    local x = W / 2 + ((i - 1) - (st.ncats - 1) / 2) * 26
    if peek > 0 then
      if i == who then
        local run = clamp((st.door_t - 40) / 40, 0, 1)
        P.cat(i, lerp(x, W / 2 - 60, run), lerp(300 - 18 * peek, 360, run) - abs(sin(st.door_t * 0.4)) * 8 * run, lerp(0.5, 1, run), run > 0.6)
      else
        P.cat(i, x, 300 - 16 * peek, 0.5, st.door_t > 70)
      end
    end
  end
  P.unicorn_at(W / 2 + 40, 400, 1, false, sin(fr() * 0.05) * 0.7, (who and st.door_t > 60) and 2 or 0)
  draw_basket()
end

-- ------------------------------------------------------------------ the party

-- A photo of an earlier party, in a gold frame on the castle wall.
local function photo(x, y, seed)
  gfx.rrect_o(x, y, 26, 22, 2, 0xfff6ea, 0xd8a03a, 2)
  gfx.rect(x + 3, y + 3, 20, 13, 0xbfe2ff)
  gfx.circle(x + 8, y + 12, 3.5, seed % 2 == 1 and C.ORANGE or C.GREY)
  gfx.circle(x + 14, y + 11, 3.5, C.WHITE)
  gfx.circle(x + 20, y + 12, 3.5, seed % 3 ~= 0 and C.GREY or C.ORANGE)
  gfx.heart(x + 13, y + 5, 2.5, C.ROOF)
end

-- Two columns each side of the middle tower, three high.
local function photo_slot(i)
  local side, row, col = i % 2, idiv(i, 2) % 3, idiv(i, 6) % 2
  return side == 1 and 246 + col * 30 or 110 - col * 30, 96 + row * 26
end

local function paint_party()
  local st = P.st
  gfx.vgrad(0, 0, W, 200, 0x8ec6ff, 0xd8ecff)
  P.castle(W / 2, 200, 1.15, 1)
  for i = 0, min(st.photos, 12) - 1 do
    local x, y = photo_slot(i)
    photo(x, y, i)
  end
  for i = 0, 11 do
    local x, y = 12 + i * 32, 168 + sin(i * 0.9) * 3
    gfx.tri(x, y, x + 24, y, x + 12, y + 16, i % 3 == 0 and C.ROOF or i % 3 == 1 and C.MINT or C.GOLD)
  end
  gfx.line(0, 168, W, 168, 1.5, INK)
  gfx.rect(0, 200, W, H - BAND - 200, 0xf6d8e8)
  for y = 0, 5 do
    for x = 0, 7 do
      if (x + y) % 2 == 1 then gfx.rect(x * 48, 330 + y * 26, 48, 26, 0xecc4dc) end
    end
  end
  gfx.rect(0, 200, W, 4, alpha(INK, 50))
end

local function draw_decor(hop)
  local st = P.st
  -- What she caught on the way: balloons by the chairs, cupcakes on the cloth,
  -- flowers in a vase, stars along the bunting.
  local BX = {20, 364, 132, 252, 192, 46, 338}
  for i = 1, min(st.got.balloon, 7) do
    local x, y = BX[i], 128 + ((i - 1) % 3) * 10 + sin(fr() * 0.04 + i - 1) * 4
    gfx.line(x, y + 18, x + sin(i - 1) * 6, 284, 1, alpha(INK, 160))
    P.balloon(x, y, 0.95, P.balloon_col(i - 1))
  end
  for i = 1, min(st.got.star, 10) do
    local x, y = 26 + (i - 1) * 36, 182 + sin((i - 1) * 0.9) * 3
    local tw = 0.7 + 0.3 * sin(fr() * 0.12 + (i - 1) * 1.7)
    gfx.line(x, 170, x, y - 6, 1, alpha(INK, 140))
    gfx.glow(x, y, 12, alpha(0xffe080, floor(tw * 150)))
    gfx.star(x, y, 6, 0, C.GOLD)
  end
  if st.got.flower > 0 then
    local vx, vy = st.ncats == 4 and W - 26 or 30, 274
    for i = 0, min(st.got.flower, 6) - 1 do
      local a = -1.9 + i * 0.35
      local fx, fy = vx + cos(a) * 18, vy - 14 + sin(a) * 18
      gfx.line(vx, vy - 6, fx, fy, 2, 0x5ab05a)
      gfx.circle_o(fx, fy, 5, i % 2 == 1 and 0xff9ac8 or 0xfff09a, INK, 1.5)
    end
    gfx.rrect_o(vx - 8, vy - 8, 16, 18, 5, C.MINT, INK, 2)
  end
  local CX3, CX4 = {132, 252, 30, 354}, {104, 192, 280, 16}
  for i = 1, min(st.got.cake, 4) do
    P.icon("cake", st.ncats == 4 and CX4[i] or CX3[i], 286 - hop * ((i - 1) % 2), 0.55)
  end
end

function P.draw_party()
  local st = P.st
  local hop = st.cheer_left > 0 and abs(sin(fr() * 0.3)) * 8 or 0
  local beat = st.song_mode and sin(fr() * 0.2) or 0
  local waving = input.quitting() > 0
  backdrop("party:" .. st.photos, paint_party)
  draw_decor(hop)
  local f = st.focus
  local fx, pulse = P.seat_x(f), 1 + 0.06 * sin(fr() * 0.12)
  gfx.glow(fx, P.head_y(f) + 10, 70 * pulse, alpha(0xfff0a0, 150))
  gfx.ring(fx, P.head_y(f) + 6, 44 * pulse, 4, alpha(0xffe070, 230))
  for i = 1, st.ncats do
    local lean = st.cat_lean[i]
    local happy = st.cheer_left > 0 or st.delight[i] > 0 or waving
    local bob = st.song_mode and ((i - 1) % 2 == 1 and beat or -beat) * 5 or 0
    local tiltx = (i == st.idle_who and st.idle_t > 0) and sin(st.idle_t * 0.25) * 4 or 0
    local nib_bump = (i == NIB and st.delight[i] > 25) and 10 or 0
    if i == NIB then gfx.ellipse_o(P.seat_x(i), 276, 30, 10, C.LILAC, INK, 2) end
    P.cat(i, P.seat_x(i) + tiltx + bob * 0.5, P.head_y(i) - lean * 6 - (st.cheer_left > 0 and hop or 0) + nib_bump * 0.3 + bob, 1 + lean * 0.12, happy)
  end
  toon(function()
    toon.rrect(16, 280, W - 32, 22, 8, C.WHITE)
    toon.rrect(16, 296, W - 32, 50, 4, C.CREAM)
  end, 2.5, INK)
  for i = 0, 15 do gfx.circle(26 + i * 22.2, 346, 11, C.CREAM) end
  for i = 0, 15 do gfx.circle(26 + i * 22.2, 344, 4, alpha(0xe86b9a, 120)) end
  gfx.rect(16, 316, W - 32, 6, alpha(0xe86b9a, 90))
  for i = 1, st.ncats do
    local x, y = P.seat_x(i), 284 + (i == f and 2 or 0)
    local wave = waving and -abs(sin(fr() * 0.3 + i - 1)) * 22 or 0
    gfx.ellipse_o(x - 14, y, 9, 6, BODY[i], INK, 2)
    gfx.ellipse_o(x + 14, y + wave, 9, 6, BODY[i], INK, 2)
  end
  -- The teapot, steaming.
  local tx, ty = st.ncats == 4 and W / 2 or W / 2 - 60, 268 - hop
  local cx2 = st.ncats == 4 and 104 or W / 2 + 60
  toon(function()
    toon.line(tx + 14, ty, tx + 26, ty - 10, 4, 0xffd0e6)
    toon.ellipse(tx, ty, 16, 13, 0xffd0e6)
    toon.circle(tx, ty - 14, 4, C.GOLD)
  end, 2, INK)
  if st.ncats == 3 and st.got.cake == 0 then P.icon("cake", cx2, 270 - hop, 0.6) end
  for k = 0, 2 do
    local sy = (fr() * 0.6 + k * 12) % 36
    gfx.circle(tx + 24 + sin(fr() * 0.05 + k) * 3, ty - 14 - sy, 4 - sy * 0.08, alpha(C.WHITE, 220 - floor(sy * 6)))
  end
  if st.cheer_left > 0 then
    for k = 0, 7 do
      local a = fr() * 0.15 + k * 0.785
      gfx.star(tx + 24 + cos(a) * 22, ty - 40 + sin(a) * 10, 4, a, C.GOLD)
    end
  end
  -- Moth's yarn ball: it rolls away and comes back, and bounces when she plays.
  local moth_yarn = st.care_kind[MOTH] == "yarn" and st.delight[MOTH] > 0
  local t = moth_yarn and (50 - st.delight[MOTH]) / 50 or 0
  local roll = moth_yarn and sin(t * math.pi) * 46 or sin(fr() * 0.05) * 3
  local up = moth_yarn and abs(sin(t * 9.42)) * 14 * (1 - t) or 0
  local yx = P.seat_x(MOTH) + 34 + roll
  gfx.circle_o(yx, 290 - up, 9, C.GOLD, INK, 2)
  gfx.line(yx - 6, 286 - up, yx + 5, 295 - up, 1.5, 0xd89a2a)
  if st.gift[MOTH] == "ribbon" then
    gfx.tri(yx, 282 - up, yx - 9, 277 - up, yx - 8, 287 - up, C.ROOF)
    gfx.tri(yx, 282 - up, yx + 9, 277 - up, yx + 8, 287 - up, C.ROOF)
  end
  -- The ask: a picture in a bubble over the focused cat, then her hearts.
  local hy = P.head_y(f)
  local bob = sin(fr() * 0.08) * 3
  local grow = st.care_wait > 30 - 8 and 0.85 + 0.15 * (30 - st.care_wait) / 8 or 1
  gfx.circle_o(fx, hy - 118 + bob, 32 * grow, C.WHITE, INK, 2.5)
  gfx.tri(fx - 8, hy - 90 + bob, fx + 8, hy - 90 + bob, fx, hy - 78 + bob, INK)
  gfx.tri(fx - 6, hy - 91 + bob, fx + 6, hy - 91 + bob, fx, hy - 82 + bob, C.WHITE)
  P.icon(P.ask_of(f), fx, hy - 118 + bob, 1.1 * grow)
  hearts_row(f, fx, hy - 58)
  -- The unicorn trots to the cat she is visiting; a hug brings her right up close.
  local moving = abs(P.seat_x(f) - st.uni_x) > 3
  local hug = st.care_kind[f] == "hug" and st.delight[f] > 10
  local trot = moving and abs(sin(fr() * 0.45)) * 8 or 0
  local pose = st.cheer_left > 0 and 3 or ((st.react_left > 120 - 30 or hug) and 2 or 0)
  P.unicorn_at(st.uni_x, 420 - trot - (hug and 22 + 10 * sin(st.delight[f] * 0.3) or 0), 1, false, sin(fr() * 0.05) * 0.7, pose)
  if hug then
    for k = 0, 1 do
      if (fr() + k * 7) % 14 == 0 then particles.spawn(st.uni_x + rnd(-20, 20), 300, rnd(-0.5, 0.5), -1.2, 50, 6, C.ROOF, "heart") end
    end
  end
  if st.toss_t > 0 and st.toss_kind ~= "hug" then
    local k = 1 - st.toss_t / 18
    local ex, ey = P.seat_x(st.toss_who), P.head_y(st.toss_who) + 10
    P.icon(st.toss_kind, lerp(st.uni_x, ex, k), lerp(350, ey, k) - sin(k * math.pi) * 60, 0.6)
  end
  if st.photo_t > 0 then
    -- The photo floats up to its place on the wall.
    local px, py = photo_slot(st.photos)
    local k = ease.in_out(clamp(st.photo_t / 80, 0, 1))
    gfx.glow(lerp(W / 2, px + 13, k), lerp(260, py + 11, k), 30, alpha(0xffffff, 160))
    photo(lerp(W / 2 - 13, px, k), lerp(250, py, k), st.photos)
  end
end

return P
