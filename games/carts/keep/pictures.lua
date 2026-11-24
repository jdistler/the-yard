-- Keep's pictures. main.lua owns the rules and fills P.S; everything here only draws. No rnd() anywhere: the
-- scenery is placed with a small integer hash, so a repaint is the same picture on every runtime.
--
-- Memory: ONE scene layer (240x320) for ever. A season change (or the kitchen) repaints it in place, so playing
-- a hundred seasons costs what one costs. Everything else is live toon drawing with no tables made per frame.
--
-- Pip is the Tea cat (tea/pictures.lua): orange, a cream muzzle patch, pink nose, blush, whiskers. The other Tea
-- cats (Moth, Pearl, Nib) sit at the table in the pantry kitchen.
local P = {}

local GROUND = 292
P.GROUND = GROUND
local INK = 0x2a1630
local CREAM = 0xfff6ea
local GOLD = 0xf2c14e
local W, H = game.w, game.h
local function fr() return game.frame end

local function hs(i, k)   -- a hash, 0..1, the same everywhere
  local n = (i * 374761 + k * 668265 + 12345) % 2147483
  n = (n * 1103 + 7919) % 1000003
  return (n % 1000) / 1000
end

-- One entry per season: name, the special fruit, the jam, how many catches fill the jar, and the colours.
local SEA = {
  {name = "Blossom", fruit = "cherry", jam = "cherry jam", quota = 8, col = 0xe0305a, jar = 0xd0305a, tint = 0xff9ab8},
  {name = "Summer", fruit = "peach", jam = "peach jam", quota = 12, col = 0xffa060, jar = 0xff9a50, tint = 0xffe070},
  {name = "Harvest", fruit = "plum", jam = "plum jam", quota = 14, col = 0x8a4ac0, jar = 0x7a3ea8, tint = 0xffa040},
  {name = "Snow", fruit = "frostberry", jam = "frost jam", quota = 16, col = 0x8adcff, jar = 0x7ac8ff, tint = 0xe8f4ff},
}
P.SEA = SEA
P.TREE_X = {22, 44, 66, 90, 112, 134, 158, 180, 202, 220}

-- ------------------------------------------------------------------ the cats (Tea's, small)

local BODY = {0xf29a3a, 0x8a8f9c, 0xfffcf8, 0xfff6ea}
local DARK = {0xd87a20, 0x666a78, 0xe8dccc, 0xf29a3a}
local PIP, MOTH, PEARL, NIB = 1, 2, 3, 4
P.PIP, P.MOTH, P.PEARL, P.NIB = PIP, MOTH, PEARL, NIB
local BLUSH = alpha(0xff8fb0, 120)

-- the shapes of one cat, from upvalues (so no closure is made per cat per frame)
local g_x, g_y, g_r, g_body, g_dark, g_who, g_head, g_ear, g_dr, g_tw, g_tail
local function cat_shapes()
  local cx, cy, r, body = g_x, g_y, g_r, g_body
  if not g_head then
    toon.line(cx + r * 0.7, cy + r * 1.95, cx + r * 1.4, cy + r * 1.95, r * 0.3, body)
    toon.line(cx + r * 1.4, cy + r * 1.95, cx + r * 1.62 + g_tail * r * 0.15, cy + r * 1.62, r * 0.3, body)
    toon.circle(cx + r * 1.62 + g_tail * r * 0.15, cy + r * 1.58, r * 0.17, g_who == PEARL and 0xfffcf8 or g_dark)
    toon.ellipse(cx, cy + r * 1.35, r * 1.05, r * 0.9, body)
  end
  toon.tri(cx - r * 0.95, cy - r * 0.2, cx - r * 0.75, cy - r * g_ear + g_dr + g_tw, cx - r * 0.2, cy - r * 0.8, body)
  toon.tri(cx + r * 0.95, cy - r * 0.2, cx + r * 0.75, cy - r * g_ear + g_dr, cx + r * 0.2, cy - r * 0.8, body)
  toon.ellipse(cx, cy, r, r * 0.92, body)
end

local PARTY = {0xe86b9a, 0x7ec8c3, 0xb9a0e8, 0xf2c14e}
P.PARTYCOL = PARTY

-- o: mood ("", happy, cheer, oh, ouch, sleepy, asleep, yawn, sulk), look_x, look_y (pixels, small), head (head
-- only: Pip over a basket), tail_speed, droop, twitch (ears), season (a seasonal accessory), party (a party hat)
function P.cat(who, cx, cy, s, o)
  local body, dark = BODY[who], DARK[who]
  local r = (who == NIB and 20 or 27) * s
  local mood = o.mood
  local blink = ((fr() + (who - 1) * 47) % 200) < 7
  g_x, g_y, g_r, g_body, g_dark, g_who, g_head = cx, cy, r, body, dark, who, o.head
  g_ear = who == MOTH and 1.45 or 1.25
  g_dr = (o.droop or 0) * r * 0.3
  g_tw = (o.twitch or 0) * r * 0.25
  g_tail = sin(fr() * (o.tail_speed or 0.07) + who - 1) * 0.6
  toon(cat_shapes, 1.8, INK)
  gfx.tri(cx - r * 0.78, cy - r * 0.35, cx - r * 0.7, cy - r * 1.0 + g_dr + g_tw, cx - r * 0.38, cy - r * 0.68, 0xffb8c8)
  gfx.tri(cx + r * 0.78, cy - r * 0.35, cx + r * 0.7, cy - r * 1.0 + g_dr, cx + r * 0.38, cy - r * 0.68, 0xffb8c8)
  if who == MOTH then
    for k = -1, 1 do gfx.line(cx + k * r * 0.25, cy - r * 0.85, cx + k * r * 0.2, cy - r * 0.5, 2 * s + 0.6, dark) end
  end
  if who == PIP then gfx.ellipse(cx, cy + r * 0.38, r * 0.55, r * 0.4, CREAM) end
  if who == NIB then
    gfx.ellipse(cx - r * 0.45, cy - r * 0.35, r * 0.3, r * 0.35, 0xf29a3a)
    gfx.circle(cx + r * 0.3, cy + r * 1.3, r * 0.35, 0xf29a3a)
  end
  -- Eyes
  local ex, ey = r * 0.38, cy - r * 0.08
  local lw = 1.6 + s
  if mood == "happy" or mood == "cheer" then
    for k = -1, 1, 2 do
      gfx.line(cx + k * ex - 3 * s * 2, ey + 1.5, cx + k * ex, ey - 2.2 * s * 2, lw, INK)
      gfx.line(cx + k * ex, ey - 2.2 * s * 2, cx + k * ex + 3 * s * 2, ey + 1.5, lw, INK)
    end
  elseif mood == "ouch" then
    for k = -1, 1, 2 do
      gfx.line(cx + k * ex - 2.5 * k, ey - 2.4, cx + k * ex + 2.5 * k, ey, lw, INK)
      gfx.line(cx + k * ex - 2.5 * k, ey + 2.4, cx + k * ex + 2.5 * k, ey, lw, INK)
    end
  elseif mood == "asleep" or mood == "yawn" or blink then
    for k = -1, 1, 2 do gfx.line(cx + k * ex - 3 * s * 2, ey + 0.5, cx + k * ex + 3 * s * 2, ey + 0.5, lw, INK) end
  elseif mood == "oh" then
    for k = -1, 1, 2 do
      gfx.ellipse(cx + k * ex + (o.look_x or 0) * 0.5, ey, 5.2 * s * 1.7, 6.6 * s * 1.7, INK)
      gfx.circle(cx + k * ex + 1 + (o.look_x or 0) * 0.5, ey - 2, 1.5, 0xffffff)
    end
  else
    local lx, ly = o.look_x or 0, o.look_y or 0
    for k = -1, 1, 2 do
      gfx.ellipse(cx + k * ex + lx, ey + ly, 5 * s * 1.6, 6.5 * s * 1.6, INK)
      gfx.circle(cx + k * ex + lx + 1.2, ey + ly - 2, 1.3, 0xffffff)
      if mood == "sleepy" then   -- heavy lids
        gfx.rect(cx + k * ex + lx - 5 * s * 1.6, ey + ly - 6.6 * s * 1.6, 10 * s * 1.6, 6.6 * s * 1.6 - 0.2, body)
        gfx.line(cx + k * ex + lx - 4.5 * s * 1.6, ey + ly - 0.2, cx + k * ex + lx + 4.5 * s * 1.6, ey + ly - 0.2, lw, INK)
      end
    end
  end
  gfx.ellipse(cx - r * 0.6, cy + r * 0.3, 3.2 * s * 1.5, 2 * s * 1.5, BLUSH)
  gfx.ellipse(cx + r * 0.6, cy + r * 0.3, 3.2 * s * 1.5, 2 * s * 1.5, BLUSH)
  gfx.tri(cx - 2.2, cy + r * 0.2, cx + 2.2, cy + r * 0.2, cx, cy + r * 0.32, 0xe86b9a)
  -- Mouth
  local my = cy + r * 0.36
  if mood == "oh" or mood == "yawn" then
    local big = mood == "yawn" and 1.4 or 1
    gfx.ellipse(cx, my + 2.5 * big, 2.4 * big, 2.8 * big, INK)
    gfx.ellipse(cx, my + 3.4 * big, 1.5 * big, 1.2 * big, 0xff8fa8)
  elseif mood == "sulk" or mood == "ouch" then
    gfx.line(cx - 3, my + 3, cx, my + 0.8, 1.3, INK)
    gfx.line(cx + 3, my + 3, cx, my + 0.8, 1.3, INK)
  else
    local happy = mood == "happy" or mood == "cheer"
    local mw, dip = happy and 3.4 or 2.8, happy and 2.6 or 2
    gfx.line(cx, my, cx - mw * 0.5, my + dip, 1.2, INK)
    gfx.line(cx - mw * 0.5, my + dip, cx - mw, my + dip * 0.2, 1.2, INK)
    gfx.line(cx, my, cx + mw * 0.5, my + dip, 1.2, INK)
    gfx.line(cx + mw * 0.5, my + dip, cx + mw, my + dip * 0.2, 1.2, INK)
    if mood == "cheer" then gfx.ellipse(cx, my + dip * 1.1, 1.6, 1.3, 0xff8fa8) end
  end
  for k = -1, 1, 2 do
    gfx.line(cx + k * r * 0.4, cy + r * 0.3, cx + k * r * 1.05, cy + r * 0.2, 1, alpha(INK, 150))
    gfx.line(cx + k * r * 0.4, cy + r * 0.36, cx + k * r * 1.05, cy + r * 0.42, 1, alpha(INK, 150))
  end
  if who == PEARL then
    gfx.tri(cx + r * 0.35, cy - r * 0.75, cx + r * 0.75, cy - r * 0.95, cx + r * 0.7, cy - r * 0.5, GOLD)
    gfx.tri(cx + r * 0.35, cy - r * 0.75, cx + r * 0.05, cy - r * 1.0, cx + r * 0.1, cy - r * 0.55, GOLD)
    gfx.circle_o(cx + r * 0.38, cy - r * 0.75, 2.2, GOLD, INK, 1.2)
  end
  -- A hat or a flower for the season (Pip), a cone for the party (all of us)
  local se = o.season
  if se == 1 then
    for k = 0, 4 do
      local a = k * 1.2566 + 0.3
      gfx.circle(cx - r * 0.55 + cos(a) * r * 0.2, cy - r * 0.85 + sin(a) * r * 0.2, r * 0.15, 0xffb8d0)
    end
    gfx.circle(cx - r * 0.55, cy - r * 0.85, r * 0.12, GOLD)
  elseif se == 2 then
    gfx.ellipse_o(cx, cy - r * 0.78, r * 0.98, r * 0.2, 0xf0d080, INK, 1.2)
    gfx.ellipse_o(cx, cy - r * 0.93, r * 0.5, r * 0.3, 0xf0d080, INK, 1.2)
    gfx.rect(cx - r * 0.48, cy - r * 0.86, r * 0.96, r * 0.1, 0xe86b6b)
  elseif se == 3 then
    gfx.ellipse_o(cx + r * 0.55, cy - r * 0.85, r * 0.26, r * 0.14, 0xe0602a, INK, 1)
    gfx.ellipse(cx + r * 0.62, cy - r * 0.88, r * 0.13, r * 0.07, 0xf2a43c)
    gfx.line(cx + r * 0.35, cy - r * 0.8, cx + r * 0.7, cy - r * 0.9, 1, INK)
  elseif se == 4 then
    gfx.rrect_o(cx - r * 0.55, cy - r * 1.02, r * 1.1, r * 0.42, 4, 0xc8423a, INK, 1.2)
    gfx.rect(cx - r * 0.5, cy - r * 0.8, r * 1.0, r * 0.1, 0xfff6ea)
    gfx.circle_o(cx, cy - r * 1.08, r * 0.18, 0xfff6ea, INK, 1.1)
    gfx.rrect_o(cx - r * 0.95, cy + r * 0.72, r * 1.9, r * 0.3, 3, 0xe86b6b, INK, 1.2)
    gfx.rect(cx - r * 0.7, cy + r * 0.82, r * 0.35, r * 0.08, 0xfff6ea)
    gfx.rect(cx + r * 0.1, cy + r * 0.82, r * 0.35, r * 0.08, 0xfff6ea)
  end
  if o.party then
    local pc = PARTY[who]
    gfx.tri(cx - r * 0.3, cy - r * 0.8, cx + r * 0.3, cy - r * 0.8, cx + r * 0.05, cy - r * 1.7, pc)
    gfx.line(cx - r * 0.18, cy - r * 1.1, cx + r * 0.2, cy - r * 1.2, 1.5, 0xffffff)
    gfx.circle(cx + r * 0.05, cy - r * 1.72, r * 0.12, GOLD)
  end
end

-- ------------------------------------------------------------------ Pip and the basket

-- o is main's reused table: x look, mood, lean, squash, tail speed, season, heap (0..3 fruit on the rim)
local HEAPCOL = {0xe0305a, 0xffa060, 0x8a4ac0, 0x8adcff}
function P.pip(x, y, bw, bh, o)
  local rimy = y - bh
  local side = -(o.facing or 1)
  -- the tail curls up behind the basket, quicker as the streak grows
  local sw = sin(fr() * (o.tail_speed or 0.07))
  local tx0, ty0 = x + side * bw * 0.45, y - bh * 0.4
  local tx1, ty1 = tx0 + side * 10, ty0 - 8 + sw * 2
  local tx2, ty2 = tx1 + side * 1 + sw * 3, ty1 - 11
  gfx.line(tx0, ty0, tx1, ty1, 6.4, INK)
  gfx.line(tx1, ty1, tx2, ty2, 6.4, INK)
  gfx.line(tx0, ty0, tx1, ty1, 4.2, BODY[PIP])
  gfx.line(tx1, ty1, tx2, ty2, 4.2, BODY[PIP])
  gfx.circle(tx2, ty2, 2.4, DARK[PIP])
  -- the head
  o.head = true
  P.cat(PIP, x + (o.lean or 0) * 3, rimy - 7 + (o.sq or 0) * 6, 0.48, o)
  -- the basket
  gfx.rrect_o(x - bw / 2, rimy, bw, bh, 5, 0xc98a4b, INK, 1.5)
  for k = 1, 3 do gfx.rect(x - bw / 2 + 2, rimy + k * bh / 4, bw - 4, 1, 0x9a6430) end
  gfx.rrect(x - bw / 2 - 2, rimy - 2, bw + 4, 5, 2, 0xdba060)
  -- fruit heaped on the rim as the jar fills, and Pip's paws over it
  local heap = o.heap or 0
  local hc = HEAPCOL[o.season or 1] or HEAPCOL[1]
  if heap >= 1 then gfx.circle_o(x - bw * 0.38, rimy - 3, 4, hc, INK, 1) end
  if heap >= 2 then gfx.circle_o(x + bw * 0.38, rimy - 3, 4, hc, INK, 1) end
  if heap >= 3 then gfx.circle_o(x - bw * 0.2, rimy - 5, 3.6, hc, INK, 1) end
  gfx.ellipse_o(x - 8 + (o.lean or 0) * 2, rimy - 1.5, 4.2, 2.8, CREAM, INK, 1.1)
  gfx.ellipse_o(x + 8 + (o.lean or 0) * 2, rimy - 1.5, 4.2, 2.8, CREAM, INK, 1.1)
end

-- ------------------------------------------------------------------ fruit, with faces

-- fm: 0 asleep on the branch, 1 awake and shaking, 2 falling, 3 hopeful (the basket is under it)
local function face(x, y, fm, gap, ey)
  local e = y + ey
  if fm == 0 then
    gfx.line(x - gap - 1, e, x - gap + 1, e, 1, INK)
    gfx.line(x + gap - 1, e, x + gap + 1, e, 1, INK)
    gfx.line(x - 1.2, e + 3, x + 1.2, e + 3, 1, INK)
  elseif fm == 3 then
    gfx.line(x - gap - 1, e + 0.6, x - gap, e - 0.6, 1, INK)
    gfx.line(x - gap, e - 0.6, x - gap + 1, e + 0.6, 1, INK)
    gfx.line(x + gap - 1, e + 0.6, x + gap, e - 0.6, 1, INK)
    gfx.line(x + gap, e - 0.6, x + gap + 1, e + 0.6, 1, INK)
    gfx.line(x - 1.6, e + 2.6, x, e + 4, 1, INK)
    gfx.line(x, e + 4, x + 1.6, e + 2.6, 1, INK)
  else
    gfx.circle(x - gap, e, 1.35, INK)
    gfx.circle(x + gap, e, 1.35, INK)
    gfx.pixel(x - gap + 0.5, e - 0.5, 0xffffff)
    gfx.pixel(x + gap + 0.5, e - 0.5, 0xffffff)
    gfx.ellipse(x, e + 3.6, 1.3, fm == 2 and 1.9 or 1.2, INK)
  end
end

local function leaf(x, y) gfx.ellipse(x, y, 2.8, 1.5, 0x6fd36f) end

-- f: {type, hang, vx, mood, phase}; (x, y) the centre; wob the branch shake; px the basket's x
function P.fruit(f, x, y, wob, px)
  local t = f.type
  local fm
  if f.hang > 0 then fm = f.hang > 22 and 0 or 1
  elseif abs(f.x - px) < 30 and y > GROUND - 120 then fm = 3
  else fm = 2 end
  if t == "bee" then
    P.bee(f, x, y)
  elseif t == "pear" then
    gfx.circle_o(x, y + 2, 7, 0xc8e05a, INK, 1.2)
    gfx.circle_o(x, y - 4, 4.5, 0xc8e05a, INK, 1.2)
    gfx.circle(x, y + 2, 6.8, 0xc8e05a)
    gfx.circle(x - 3, y, 1.8, alpha(0xffffff, 150))
    gfx.line(x, y - 8, x + 1 + wob, y - 11, 1.2, 0x5a3a20)
    face(x, y, fm, 2.6, 1)
  elseif t == "gold" then
    gfx.glow(x, y, 17, alpha(0xffd060, 160))
    gfx.star(x, y, 9, fr() * 0.08, INK)
    gfx.star(x, y, 7.5, fr() * 0.08, GOLD)
    gfx.circle(x, y, 4.6, GOLD)
    face(x, y, fm, 1.9, -0.4)
  elseif t == "special" then
    local si = f.si
    if si == 1 then   -- cherries
      gfx.line(x - 3, y - 2, x, y - 10 + wob * 0.5, 1.2, 0x5a3a20)
      gfx.line(x + 4, y - 2, x, y - 10 + wob * 0.5, 1.2, 0x5a3a20)
      leaf(x + 3, y - 10)
      gfx.circle_o(x - 4, y + 2, 4.8, 0xe0305a, INK, 1.1)
      gfx.circle_o(x + 4, y + 3, 4.8, 0xc8203e, INK, 1.1)
      gfx.pixel(x - 5.5, y, 0xffffff)
      gfx.pixel(x + 2.5, y + 1, 0xffffff)
      face(x - 4, y + 2, fm, 1.6, -0.4)
      if fm ~= 0 then gfx.circle(x + 2.6, y + 2.4, 1, INK) gfx.circle(x + 5.4, y + 2.4, 1, INK) end
    elseif si == 2 then   -- peach
      gfx.circle_o(x, y, 7.2, 0xffa060, INK, 1.2)
      gfx.ellipse(x + 2, y + 1, 4.8, 5, alpha(0xff6a70, 150))
      gfx.line(x, y - 6, x, y - 1, 1, alpha(0xc85a3a, 160))
      gfx.line(x, y - 7, x + 1 + wob, y - 10, 1.2, 0x5a3a20)
      leaf(x + 3 + wob, y - 9)
      gfx.circle(x - 3, y - 2, 1.6, alpha(0xffffff, 150))
      face(x, y, fm, 2.6, 0.8)
    elseif si == 3 then   -- plum
      gfx.ellipse_o(x, y, 6.5, 7.2, 0x8a4ac0, INK, 1.2)
      gfx.ellipse(x - 2.4, y - 2.4, 2.6, 1.6, alpha(0xd8c0f0, 170))
      gfx.line(x, y - 7, x + 1 + wob, y - 10, 1.2, 0x5a3a20)
      leaf(x + 3 + wob, y - 9)
      face(x, y, fm, 2.5, 1)
    else   -- frostberry: icy, with a snowflake
      gfx.glow(x, y, 14, alpha(0x9ae0ff, 120))
      gfx.circle_o(x, y, 7, 0x8adcff, INK, 1.2)
      for k = 0, 2 do
        local a = k * 1.0472 + fr() * 0.01
        gfx.line(x - cos(a) * 5.5, y - 1 - sin(a) * 5.5, x + cos(a) * 5.5, y - 1 + sin(a) * 5.5, 0.8, alpha(0xffffff, 190))
      end
      gfx.circle(x - 3, y - 3, 1.5, 0xffffff)
      face(x, y, fm, 2.5, 1)
    end
  else   -- apple
    gfx.circle_o(x, y, 7, 0xff5a4a, INK, 1.2)
    gfx.circle(x - 2.5, y - 2.5, 2, alpha(0xffffff, 140))
    gfx.line(x, y - 6, x + wob, y - 10, 1.2, 0x5a3a20)
    gfx.ellipse(x + 3 + wob, y - 9, 2.8, 1.5, 0x6fd36f)
    face(x, y, fm, 2.6, 0.8)
  end
end

-- Bees with a personality: 1 dozy (sleepy lids, a drifting z), 2 grump (a scowl), 3 cheery (a grin and a wave),
-- 4 scarf (a woolly bee in the snow, breath puffs).
function P.bee(f, x, y)
  local m = f.mood
  local dir = f.vx >= 0 and 1 or -1
  local wing = sin(fr() * (m == 1 and 0.6 or 1.2) + f.phase) * 2.6
  gfx.ellipse(x - 3, y - 6 - wing, 4, 2.6, alpha(0xe0f4ff, 210))
  gfx.ellipse(x + 3, y - 6 + wing, 4, 2.6, alpha(0xe0f4ff, 210))
  gfx.ellipse_o(x, y, 8, 5.8, 0xffd02a, INK, 1.2)
  gfx.rect(x - 3, y - 5.4, 2, 10.8, INK)
  gfx.rect(x + 1, y - 5.4, 2, 10.8, INK)
  gfx.tri(x - dir * 8, y, x - dir * 11, y - 1.5, x - dir * 11, y + 1.5, INK)   -- the stinger, behind
  local fx = x + dir * 4.6   -- the face is at the front end
  if m == 1 then
    gfx.line(fx - 2.4, y - 1.4, fx - 0.4, y - 1.4, 1.1, INK)
    gfx.line(fx + 0.8, y - 1.4, fx + 2.8, y - 1.4, 1.1, INK)
    gfx.ellipse(fx + 0.2, y + 1.8, 1, 0.8, INK)
    local zt = (fr() + f.phase * 10) % 50
    gfx.text("z", x - dir * 6, y - 14 - zt * 0.14, 10, alpha(0xdfe8ff, floor(230 - zt * 4)), "center")
  elseif m == 2 then
    gfx.circle(fx - 1.6, y - 1, 1.2, INK)
    gfx.circle(fx + 1.8, y - 1, 1.2, INK)
    gfx.line(fx - 3.2, y - 3.4, fx - 0.4, y - 2.2, 1.2, INK)
    gfx.line(fx + 3.4, y - 3.4, fx + 0.6, y - 2.2, 1.2, INK)
    gfx.line(fx - 1.6, y + 2.6, fx, y + 1.6, 1, INK)
    gfx.line(fx + 1.6, y + 2.6, fx, y + 1.6, 1, INK)
  elseif m == 3 then
    gfx.circle(fx - 1.6, y - 1, 1.2, INK)
    gfx.circle(fx + 1.8, y - 1, 1.2, INK)
    gfx.pixel(fx - 1.2, y - 1.4, 0xffffff)
    gfx.pixel(fx + 2.2, y - 1.4, 0xffffff)
    gfx.line(fx - 1.8, y + 1.4, fx, y + 2.8, 1, INK)
    gfx.line(fx, y + 2.8, fx + 1.8, y + 1.4, 1, INK)
    gfx.circle(x, y - 8, 1.2, 0xff6a8a)   -- a tiny flower on its head
    gfx.circle(x + 1.6, y - 9.4, 1, 0xffffff)
  else
    gfx.circle(fx - 1.6, y - 1, 1.2, INK)
    gfx.circle(fx + 1.8, y - 1, 1.2, INK)
    gfx.ellipse(fx - 3.4, y + 1.2, 1.6, 1, alpha(0xff6a8a, 170))
    gfx.line(fx - 1, y + 2.6, fx + 1, y + 2.6, 1, INK)
    gfx.rrect_o(x - dir * 1 - 3, y + 2.6, 6.4, 3, 1.4, 0xe86b6b, INK, 0.9)   -- the scarf
    gfx.rect(x - dir * 4.2, y + 3.4, 1.6, 4, 0xe86b6b)
    gfx.glow(fx + dir * 5, y + 1, 4 + sin(fr() * 0.2) * 1.4, alpha(0xffffff, 90))
  end
end

-- ------------------------------------------------------------------ jars

-- A jar of jam: cx the middle, base the bottom. fill 0..1 (a glass jar part full), ribbon for a perfect season.
function P.jar(cx, base, w, h, col, fill, ribbon, glow)
  if glow and glow > 0 then gfx.glow(cx, base - h / 2, w * 1.3, alpha(0xfff0b0, floor(60 + 90 * glow))) end
  gfx.rrect_o(cx - w / 2, base - h * 0.82, w, h * 0.82, w * 0.22, alpha(0xdff4ff, 150), INK, 1.2)
  if fill > 0 then
    local fh = (h * 0.74) * fill
    gfx.rrect(cx - w / 2 + 1.5, base - 1.5 - fh, w - 3, fh, w * 0.18, col)
    gfx.rect(cx - w / 2 + 2.5, base - fh, 1.6, max(0, fh - 3), alpha(0xffffff, 110))
  end
  gfx.rrect_o(cx - w * 0.38, base - h, w * 0.76, h * 0.2, 2, 0xe8c070, INK, 1)
  if fill >= 1 then gfx.rect(cx - w * 0.3, base - h * 0.5, w * 0.6, h * 0.22, CREAM) end
  if ribbon then
    gfx.rect(cx - w * 0.5 - 0.5, base - h * 0.78, w + 1, 2.2, 0xe8486a)
    gfx.circle(cx - 2, base - h * 0.84, 2.2, 0xe8486a)
    gfx.circle(cx + 2, base - h * 0.84, 2.2, 0xe8486a)
    gfx.circle(cx, base - h * 0.82, 1.2, GOLD)
  end
end

function P.fruit_icon(si, x, y, s)
  local c = SEA[si].col
  if si == 1 then
    gfx.circle_o(x - 3 * s, y + 2 * s, 4 * s, 0xe0305a, INK, 1)
    gfx.circle_o(x + 3 * s, y + 3 * s, 4 * s, 0xc8203e, INK, 1)
    gfx.line(x - 3 * s, y - 1 * s, x, y - 7 * s, 1, 0x5a3a20)
    gfx.line(x + 3 * s, y, x, y - 7 * s, 1, 0x5a3a20)
  elseif si == 2 then
    gfx.circle_o(x, y, 6 * s, c, INK, 1)
    gfx.ellipse(x + 1.5 * s, y + 1 * s, 3.6 * s, 4 * s, alpha(0xff6a70, 150))
    leaf(x + 2 * s, y - 7 * s)
  elseif si == 3 then
    gfx.ellipse_o(x, y, 5.5 * s, 6.2 * s, c, INK, 1)
    gfx.ellipse(x - 2 * s, y - 2 * s, 2 * s, 1.3 * s, alpha(0xd8c0f0, 170))
    leaf(x + 2 * s, y - 7 * s)
  else
    gfx.circle_o(x, y, 6 * s, c, INK, 1)
    gfx.line(x - 4 * s, y, x + 4 * s, y, 0.9, 0xffffff)
    gfx.line(x, y - 4 * s, x, y + 4 * s, 0.9, 0xffffff)
  end
end

-- ------------------------------------------------------------------ the scene layer (repainted in place)

local layer, layer_key = nil, nil

local SKY = {{0x7ec8ff, 0xcfe8ff, 0xffe9f0}, {0x2f98ff, 0x8fd0ff, 0xdff4ff},
             {0x3b2a6e, 0xff9a6a, 0xffc98a}, {0x1c2658, 0x4a62a8, 0x9ab0e0}}
local HILL1 = {0xa6dc90, 0x58b05a, 0xb06a8a, 0xc8d8f2}
local HILL2 = {0x7cc47e, 0x3a944a, 0x7a4a7a, 0xa0b4de}
local GRND = {{0x7ed06c, 0x4aa850}, {0x4cb04c, 0x2a7a34}, {0x8aa850, 0x5a7a38}, {0xf4f8ff, 0xc4d4ee}}
local TUFT = {0x8ae07a, 0x62c060, 0xa0b858, 0xffffff}

local function castle(x, y, haze, lit)   -- Starlight Castle, far away on the hill
  local wall, roof = mix(0xf4b6d0, haze, 0.35), mix(0xe86b9a, haze, 0.35)
  gfx.rect(x - 12, y - 14, 24, 14, wall)
  gfx.rect(x - 18, y - 22, 8, 22, wall)
  gfx.rect(x + 10, y - 22, 8, 22, wall)
  gfx.rect(x - 4, y - 24, 8, 24, wall)
  gfx.tri(x - 20, y - 22, x - 8, y - 22, x - 14, y - 34, roof)
  gfx.tri(x + 8, y - 22, x + 20, y - 22, x + 14, y - 34, roof)
  gfx.tri(x - 6, y - 24, x + 6, y - 24, x, y - 38, roof)
  gfx.circle(x, y - 17, 1.6, lit)
  gfx.rect(x - 15, y - 15, 2, 3, lit)
  gfx.rect(x + 13, y - 15, 2, 3, lit)
  gfx.line(x, y - 38, x, y - 44, 1, 0x7a5a6a)
  gfx.tri(x, y - 44, x + 6, y - 42, x, y - 40, 0xe8486a)
end

local function paint_orchard(si)
  local sk = SKY[si]
  gfx.vgrad(0, 0, W, 200, sk[1], sk[2])
  gfx.vgrad(0, 200, W, GROUND - 200, sk[2], sk[3])
  if si == 4 then
    for i = 0, 30 do   -- stars
      gfx.pixel(hs(i, 1) * W, hs(i, 2) * 190, alpha(0xffffff, 140 + floor(hs(i, 3) * 100)))
    end
    gfx.glow(172, 132, 44, alpha(0xdfe8ff, 100))
    gfx.circle(172, 132, 16, 0xf4f8ff)
    gfx.circle(177, 129, 14, sk[2])   -- a crescent
  elseif si == 3 then
    gfx.glow(120, 196, 70, alpha(0xffe0a0, 120))
    gfx.circle(120, 200, 22, 0xfff0c4)
  elseif si == 2 then
    gfx.glow(62, 150, 80, alpha(0xfff6b0, 130))
    gfx.circle(62, 150, 22, 0xfff4a0)
    for i = 0, 3 do   -- clouds
      local cx, cy = 100 + i * 40 + hs(i, 4) * 20, 120 + hs(i, 5) * 40
      gfx.circle(cx, cy, 9, alpha(0xffffff, 200))
      gfx.circle(cx + 9, cy + 2, 7, alpha(0xffffff, 200))
      gfx.circle(cx - 8, cy + 3, 6, alpha(0xffffff, 200))
    end
  else
    gfx.glow(176, 168, 60, alpha(0xfff0c8, 110))
    gfx.circle(176, 168, 17, 0xfff6d0)
    for i = 0, 2 do   -- clouds, pink
      local cx, cy = 30 + i * 70 + hs(i, 6) * 20, 100 + hs(i, 7) * 40
      gfx.circle(cx, cy, 8, alpha(0xfff0f4, 190))
      gfx.circle(cx + 8, cy + 2, 6, alpha(0xfff0f4, 190))
      gfx.circle(cx - 7, cy + 3, 5, alpha(0xfff0f4, 190))
    end
  end
  gfx.poly({-20, 236, 50, 214, 100, 230, 150, 210, 200, 226, 260, 212, 260, 300, -20, 300}, HILL1[si])
  castle(196, 222, HILL1[si], si == 4 and 0xffe9a0 or 0xfff0c8)
  gfx.poly({-20, 262, 60, 244, 130, 258, 190, 240, 260, 254, 260, 300, -20, 300}, HILL2[si])
  local g = GRND[si]
  gfx.vgrad(0, GROUND - 14, W, H - GROUND + 14, g[1], g[2])
  for i = 0, 23 do
    local gx = (i * 37) % W
    gfx.tri(gx, GROUND - 13, gx + 3, GROUND - 19, gx + 6, GROUND - 13, TUFT[si])
  end
  -- what the season puts on the grass
  if si == 1 then
    for i = 0, 15 do
      local fx, fy = hs(i, 8) * (W - 10) + 5, GROUND - 10 + hs(i, 9) * 22
      gfx.circle(fx, fy, 2.2, i % 3 == 0 and 0xffffff or 0xffb8d0)
      gfx.circle(fx, fy, 0.9, GOLD)
    end
  elseif si == 2 then
    for i = 0, 17 do
      local fx, fy = hs(i, 8) * (W - 10) + 5, GROUND - 10 + hs(i, 9) * 22
      gfx.circle(fx, fy, 2.4, i % 2 == 0 and 0xffe060 or 0xffffff)
      gfx.circle(fx, fy, 1, i % 2 == 0 and 0xe08a20 or 0xffd040)
    end
  elseif si == 3 then
    for k = 0, 2 do   -- pumpkins
      local px, py = 16 + k * 100 + hs(k, 10) * 14, GROUND + 6
      gfx.ellipse_o(px, py, 11, 8, 0xe8802a, INK, 1.2)
      gfx.ellipse(px - 4, py, 3.4, 7, 0xd06a1c)
      gfx.ellipse(px + 4, py, 3.4, 7, 0xd06a1c)
      gfx.rect(px - 1.2, py - 11, 2.4, 4, 0x5a7a30)
    end
    gfx.rrect_o(160, GROUND - 4, 26, 14, 3, 0xe8c860, INK, 1.2)   -- a hay bale
    gfx.line(166, GROUND - 3, 166, GROUND + 9, 1, 0xa88a30)
    gfx.line(180, GROUND - 3, 180, GROUND + 9, 1, 0xa88a30)
    for i = 0, 11 do gfx.ellipse(hs(i, 11) * W, GROUND + 4 + hs(i, 12) * 22, 2.4, 1.3, i % 2 == 0 and 0xe0602a or 0xf2a43c) end
  else
    for i = 0, 6 do gfx.ellipse(hs(i, 13) * W, GROUND + 6 + hs(i, 14) * 18, 14 + hs(i, 15) * 10, 3, alpha(0xffffff, 200)) end
    -- a snowman at the edge
    gfx.circle_o(216, GROUND + 6, 9, 0xffffff, INK, 1.2)
    gfx.circle_o(216, GROUND - 6, 6.4, 0xffffff, INK, 1.2)
    gfx.circle(214.5, GROUND - 7, 0.9, INK)
    gfx.circle(218, GROUND - 7, 0.9, INK)
    gfx.tri(216, GROUND - 5.5, 223, GROUND - 4.5, 216, GROUND - 3.6, 0xff8a3a)
    gfx.rect(210, GROUND - 14, 12, 2, INK)
    gfx.rect(212, GROUND - 20, 8, 7, INK)
  end
  -- the orchard canopy across the top
  gfx.rect(8, 0, 10, 60, 0x5a3a28)
  gfx.rect(222, 0, 10, 60, 0x5a3a28)
  if si == 4 then
    gfx.rect(0, 0, W, 30, alpha(0x101a40, 140))
    for k = 0, 2 do
      local by = 28 + k * 13
      gfx.line(-4, by + 6, 120, by - 4, 5, 0x4a3426)
      gfx.line(120, by - 4, 244, by + 6, 5, 0x4a3426)
      gfx.line(40, by + 2, 56, by - 12, 3, 0x4a3426)
      gfx.line(180, by + 1, 200, by - 12, 3, 0x4a3426)
    end
    for i = 0, 17 do
      local sx = i * 14 + hs(i, 16) * 8
      gfx.ellipse(sx, 22 + (i % 4) * 11 + hs(i, 17) * 6, 9, 4.5, alpha(0xf4f8ff, 235))
    end
  else
    local c1, c2, c3 = 0x24603a, 0x2f7a44, 0x3f9452
    if si == 1 then c1, c2, c3 = 0x3f9a58, 0x5cb870, 0x80d08a
    elseif si == 2 then c1, c2, c3 = 0x1a5a30, 0x2a8040, 0x4aa856
    elseif si == 3 then c1, c2, c3 = 0x9a3a22, 0xc8602a, 0xe8a040 end
    for i = 0, 12 do
      local cx, cy = i * 20, 26 + (i % 3) * 7
      gfx.circle(cx, cy + 4, 20, c1)
      gfx.circle(cx + 4, cy - 2, 16, c2)
      gfx.circle(cx + 6, cy - 6, 8, c3)
    end
    if si == 1 then   -- blossom
      for i = 0, 40 do
        local bx, by = hs(i, 18) * W, 4 + hs(i, 19) * 50
        gfx.circle(bx, by, 3.2, i % 3 == 0 and 0xffe0ec or 0xffb8d0)
        gfx.circle(bx, by, 1.1, 0xff8fb4)
      end
    elseif si == 3 then   -- a few leaves still on, a few already gold
      for i = 0, 30 do
        gfx.ellipse(hs(i, 20) * W, 4 + hs(i, 21) * 54, 3.4, 1.9, i % 3 == 0 and 0xffd060 or 0xd8442a)
      end
    elseif si == 2 then   -- sun spots through the leaves
      for i = 0, 18 do gfx.glow(hs(i, 22) * W, 6 + hs(i, 23) * 46, 5, alpha(0xfff6b0, 90)) end
    end
  end
end

local function paint_kitchen()
  gfx.vgrad(0, 0, W, 266, 0xfde8ee, 0xf6d0dc)
  for i = 0, 11 do gfx.rect(i * 20 + 6, 0, 8, 266, alpha(0xffffff, 55)) end
  gfx.vgrad(0, 266, W, H - 266, 0xc98a5a, 0x9a6236)
  for i = 0, 6 do gfx.rect(0, 266 + i * 9, W, 1, alpha(0x5a3a20, 120)) end
  for i = 0, 11 do gfx.rect((i * 29 + 7) % W, 266 + (i % 6) * 9, 1, 9, alpha(0x5a3a20, 110)) end
  gfx.rect(0, 262, W, 5, 0xd0709a)
  -- the pantry cabinet: four shelves, one for each season's jam
  gfx.rrect(10, 52, 220, 156, 8, 0x8a5430)
  gfx.rrect(14, 56, 212, 148, 5, 0xf0d6b0)
  gfx.vgrad(14, 56, 212, 20, alpha(0x8a5430, 90), alpha(0x8a5430, 0))
  for k = 0, 3 do
    local py = 58 + k * 36 + 30
    gfx.rrect(14, py, 212, 6, 2, 0xb9783f)
    gfx.rect(14, py + 4, 212, 2, 0x8a5430)
  end
end

-- Draw the scene for a key: "s1".."s4" the orchard in a season, "kitchen" the pantry. One layer, repainted in place.
function P.scene(key)
  if not layer then layer = gfx.layer(W, H) end
  if layer_key ~= key then
    layer_key = key
    if key == "kitchen" then layer:paint(paint_kitchen)
    else
      local si = tonumber(key:sub(2))
      layer:paint(function() paint_orchard(si) end)
    end
  end
  gfx.blit(layer, 0, 0)
end

-- ------------------------------------------------------------------ the season's weather (live, a few shapes)

local NFL = 22
local FX, FY, FS = {}, {}, {}
for i = 1, NFL do FX[i], FY[i], FS[i] = hs(i, 30) * W, hs(i, 31) * H, 0.4 + hs(i, 32) * 0.7 end

function P.weather(si)
  local f = fr()
  if si == 1 then   -- petals
    for i = 1, 14 do
      local x = (FX[i] + f * 0.25 * FS[i] + sin(f * 0.03 + i) * 9) % W
      local y = (FY[i] + f * 0.55 * FS[i]) % (GROUND - 20)
      gfx.ellipse(x, y, 2.6, 1.5, alpha(0xffc8dc, 220))
    end
  elseif si == 2 then   -- two butterflies and bright motes
    for k = 1, 2 do
      local bx = 120 + sin(f * 0.012 * k + k * 2) * 90
      local by = 150 + sin(f * 0.02 * k + k) * 36 + k * 20
      local fl = sin(f * 0.5 + k) * 3
      gfx.ellipse(bx - 2.4, by - fl * 0.4, 3.4, 2.4 + fl * 0.3, k == 1 and 0xffb04a or 0x9ad0ff)
      gfx.ellipse(bx + 2.4, by - fl * 0.4, 3.4, 2.4 + fl * 0.3, k == 1 and 0xffb04a or 0x9ad0ff)
      gfx.rect(bx - 0.5, by - 2, 1, 4, INK)
    end
    for i = 1, 6 do
      local tw = 0.5 + 0.5 * sin(f * 0.05 + i * 2)
      gfx.glow(FX[i], 120 + FY[i] * 0.4, 5 + tw * 3, alpha(0xfff6b0, floor(40 + tw * 90)))
    end
  elseif si == 3 then   -- leaves
    for i = 1, 11 do
      local x = (FX[i] + f * 0.3 * FS[i] + sin(f * 0.04 + i * 1.3) * 14) % W
      local y = (FY[i] + f * 0.7 * FS[i]) % (GROUND - 10)
      gfx.ellipse(x, y, 3.2, 1.8 + 0.8 * sin(f * 0.1 + i), i % 3 == 0 and 0xffd060 or (i % 3 == 1 and 0xe0602a or 0xc83a2a))
    end
  else   -- snow
    for i = 1, NFL do
      local x = (FX[i] + sin(f * 0.025 + i) * 8 + f * 0.1 * FS[i]) % W
      local y = (FY[i] + f * 0.6 * FS[i]) % (GROUND - 6)
      gfx.circle(x, y, 1 + FS[i] * 0.9, alpha(0xffffff, 230))
    end
    for i = 1, 4 do
      local tw = 0.5 + 0.5 * sin(f * 0.06 + i * 2.3)
      gfx.glow(30 + FX[i + 4] * 0.8, 140 + FY[i + 4] * 0.2, 4 + tw * 4, alpha(0xdfe8ff, floor(60 + tw * 100)))
    end
  end
end

-- ------------------------------------------------------------------ the kitchen: shelf, table, cats, Pip

local SLOT_X0, SLOT_DX = 44, 21.5
local VASE = {rose = 0xe86b9a, gold = 0xf2c14e, sky = 0x8ac8ff, lilac = 0xb9a0e8, mint = 0x7ec8c3, coral = 0xff8a7a}

local cat_o = {mood = "", look_x = 0, look_y = 0, tail_speed = 0.07}
local pip_o = {mood = "", look_x = 0, look_y = 0, facing = 1, lean = 0, sq = 0, tail_speed = 0.07, season = 1,
               heap = 0, droop = 0, twitch = 0}
local CATX = {98, 142, 190}
local CATW = {MOTH, PEARL, NIB}

local function bunting(y0, t)
  for i = 0, 8 do
    local x = i * 30 - 6
    local sag = sin(i / 8 * 3.1416) * 8
    gfx.line(x, y0 + sag, x + 30, y0 + sin((i + 1) / 8 * 3.1416) * 8, 1, 0x8a5a4a)
  end
  for i = 0, 7 do
    local x = i * 30 + 9
    local sag = sin((i + 0.5) / 8 * 3.1416) * 8
    local sw = sin(t * 0.06 + i) * 1.5
    gfx.tri(x - 6, y0 + sag, x + 6, y0 + sag, x + sw, y0 + sag + 12, PARTY[i % 4 + 1])
  end
end

-- mode "title": the story and then the pantry; mode "party": the Tea party that ends a year
function P.kitchen(mode)
  local S = P.S
  local t = S.title_t
  local f = fr()
  local party = mode == "party"
  if party then t = 900 end
  -- the shelves
  for k = 1, 4 do
    local py = 58 + (k - 1) * 36 + 30
    P.fruit_icon(k, 27, py - 20, 0.85)
    local n = S.jars[k]
    if n > 0 then gfx.text("x" .. n, 27, py - 12, 11, 0x6a4020, "center") end
    for j = 1, 8 do
      local jx = SLOT_X0 + (j - 1) * SLOT_DX + 8.5
      if j <= min(n, 8) then
        local glow = (S.new_s == k and j == min(n, 8) and S.new_t > 0) and (S.new_t / 90) or 0
        P.jar(jx, py, 17, 24, SEA[k].jar, 1, j <= S.lids[k], party and (0.35 + 0.35 * sin(f * 0.1 + j + k)) or glow)
      else
        gfx.rrect(jx - 7, py - 20, 14, 19, 4, alpha(0x8a5430, 38))
      end
    end
  end
  -- the story's first jar pops onto the shelf
  if S.story and t >= 340 and t < 520 and S.jars[1] == 0 then
    local k = ease.out_back(clamp((t - 340) / 30, 0, 1))
    P.jar(SLOT_X0 + 8.5, 88, 17 * k, 24 * k, SEA[1].jar, 1, false, 1)
    if t < 372 then gfx.glow(SLOT_X0 + 8.5, 76, 22, alpha(0xfff0b0, 140)) end
  end
  bunting(48, f)
  gfx.text(party and "Tea party!" or "Keep", W / 2, party and -2 or -4, party and 32 or 34, pal.sun, "center", INK)
  -- the cats at the table
  local pipx, pipshow, pm = 38, true, ""
  local facing, heap = 1, S.jars[1] + S.jars[2] + S.jars[3] + S.jars[4] > 0 and 1 or 0
  if S.story and not party then
    if t < 110 then pm = "asleep"
    elseif t < 230 then
      local k = ease.in_out(clamp((t - 110) / 120, 0, 1))
      pipx, pm = 38 + 250 * k, "happy"
    elseif t < 300 then pipshow = false
    elseif t < 370 then
      local k = ease.out_cubic(clamp((t - 300) / 70, 0, 1))
      pipx, pm, facing, heap = 290 - 252 * k, "cheer", -1, 3
    else pm = (t % 400 > 300) and "yawn" or "" end
  elseif party then
    pm = "cheer"
    pipx = 38 + sin(f * 0.1) * 4
  else
    local c = (t - 400) % 1200
    pm = c > 900 and "asleep" or (c > 760 and "sleepy") or (c > 700 and "yawn") or (c > 560 and "happy") or ""
  end
  for i = 1, 3 do
    local who = CATW[i]
    local m = ""
    if S.story and not party then
      if t < 110 then m = "sulk" elseif t < 300 then m = "" else m = "cheer" end
    elseif party then m = "cheer"
    else
      m = ((idiv(t, 150) + i) % 3 == 0 and t % 150 < 50) and "happy" or ""
    end
    local hop = party and abs(sin(f * 0.12 + i * 1.7)) * 6 or (m == "cheer" and abs(sin(f * 0.14 + i)) * 4 or 0)
    cat_o.mood = m
    cat_o.look_x = clamp((pipx - CATX[i]) * 0.025, -2, 2)
    cat_o.look_y = 0
    cat_o.party = party
    cat_o.head = false
    cat_o.tail_speed = 0.07
    P.cat(who, CATX[i], (who == NIB and 236 or 228) - hop, 0.5, cat_o)
  end
  cat_o.party = false
  -- the table: cloth, teapot, cups, a scone plate, her bouquet
  gfx.rrect_o(64, 242, 172, 26, 4, 0xfffcf8, INK, 1.6)
  for i = 0, 10 do gfx.circle(70 + i * 16, 268, 6, 0xf4b6d0) end
  gfx.rect(66, 246, 168, 2, 0xf4b6d0)
  gfx.ellipse_o(128, 241, 7, 5, 0xb9a0e8, INK, 1.2)
  gfx.rect(124, 234, 8, 3, 0xb9a0e8)
  gfx.line(135, 240, 141, 236, 1.8, 0xb9a0e8)
  for i = 1, 3 do gfx.ellipse_o(CATX[i] + (i == 3 and 10 or 12), 243, 4.6, 2.2, 0xffffff, INK, 1) end
  gfx.ellipse_o(160, 243, 8, 2.6, 0xfffcf8, INK, 1)
  gfx.circle(157, 240, 2.6, 0xe8b070)
  gfx.circle(163, 240, 2.6, 0xe8b070)
  if S.vase then
    gfx.rect(76, 232, 6, 9, 0x8ac8ff)
    for k = 1, S.vase_n do
      gfx.circle(73 + k * 4.5, 228 + (k % 2) * 3, 3, S.vase[k])
    end
  end
  if party then   -- a cake with candles
    gfx.rrect_o(196, 232, 26, 12, 3, 0xf4b6d0, INK, 1.2)
    gfx.rect(197, 236, 24, 2, 0xffffff)
    for k = 0, 2 do
      gfx.rect(202 + k * 7, 225, 1.6, 7, 0xffd060)
      gfx.glow(202.8 + k * 7, 224, 3 + sin(f * 0.3 + k) * 1, alpha(0xffe080, 200))
    end
  end
  -- balloons: one for each year she has finished (five at the most)
  for k = 1, min(S.years, 5) do
    local bx = 222 - (k - 1) * 9 + sin(f * 0.04 + k) * 3
    local by = 206 - ((k * 7) % 14)
    gfx.line(228, 240, bx, by + 7, 1, alpha(INK, 160))
    gfx.ellipse_o(bx, by, 5.5, 6.6, PARTY[k % 4 + 1], INK, 1.2)
    gfx.circle(bx - 2, by - 2.4, 1.3, alpha(0xffffff, 180))
  end
  -- Pip in the foreground
  if pipshow then
    pip_o.mood = pm
    pip_o.season = 0
    pip_o.facing = facing
    pip_o.lean = facing * 0.3
    pip_o.look_x, pip_o.look_y = facing * 1.2, 0
    pip_o.tail_speed = party and 0.2 or 0.07
    pip_o.heap = heap
    pip_o.sq = 0
    pip_o.party = party
    local hop = (party or (S.story and t >= 110 and t < 230) or (S.story and t >= 300 and t < 370)) and abs(sin(f * 0.2)) * 5 or 0
    P.pip(pipx, 270 - hop, 40, 18, pip_o)
    pip_o.party = false
    if pm == "asleep" then
      local zt = f % 60
      gfx.text("z", pipx + 14, 224 - zt * 0.2, 12, alpha(0xffffff, floor(255 - zt * 3.5)), "center", INK)
    end
  end
  -- a thought bubble while she sleeps and everyone is hungry (the story's first beat)
  if S.story and not party and t < 230 and t >= 0 then
    local bx, by = 142, 205
    gfx.rrect_o(bx - 17, by - 12, 34, 24, 10, 0xffffff, INK, 1.4)
    gfx.circle_o(bx - 22, by + 14, 2.6, 0xffffff, INK, 1)
    gfx.circle_o(bx - 26, by + 19, 1.6, 0xffffff, INK, 1)
    P.jar(bx, by + 9, 13, 17, SEA[1].jar, 1, false, 0)
    gfx.text("?", bx + 9, by - 11, 14, INK, "center")
  end
end

return P
