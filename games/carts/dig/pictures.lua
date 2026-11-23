-- Dig's pictures. main.lua owns the rules and fills P.S; everything here only draws. Nothing here uses rnd()
-- or reads the music clock (scenery is placed with small integer hashes, so it is the same on every runtime).
local P = {}

local C = {
  CREAM = 0xfff6ea, INK = 0x3a2a44, SKY_TOP = 0x6ec6ff, SKY_BOT = 0xb8e6ff,
  GRASS = 0x68c860, GRASS_DARK = 0x4ca848,
  L1 = 0xe8b878, L2 = 0xd88848, L3 = 0xc06248, L4 = 0x7c485c,
  TUNNEL = 0x3b2434, TUNNEL_RIM = 0x523448,
  HAT = 0xe84855, SUIT = 0x4a82cc, SKIN = 0xf4c7a1, GOLD = 0xffd84a,
  AQUA = 0x7fe8ff, PURPLE = 0x8a5cf5, ROSE = 0xe86b9a, WHITE = 0xfffcf8,
  PUFF = 0xf46a3e, CHAR = 0xf28c38, FLAME = 0xffb830, ROCK = 0x9aa0ac, ROCK_DARK = 0x6c7280,
  WOOD = 0xb07a48, WOOD_DK = 0x7c5230, SOIL = 0x8a5a3c, SOIL_DK = 0x6c4430,
}
P.C = C
local INK, GOLD = C.INK, C.GOLD
local BAND = 32

local function fr() return game.frame end

-- The five cave worlds, one per garden plot: sky, hills, four earth strata, grass.
local WORLDS = {
  {sky1 = 0x6ec6ff, sky2 = 0xb8e6ff, h1 = 0x88d87a, h2 = 0x7cc870, grass = 0x68c860, grass2 = 0x4ca848,
   l = {0xe8b878, 0xd88848, 0xc06248, 0x7c485c}, cloud = 0xfffcf8},
  {sky1 = 0x3b3a8c, sky2 = 0x9a86d8, h1 = 0x5a4a9a, h2 = 0x4c4090, grass = 0x4cb8a8, grass2 = 0x389888,
   l = {0xa898c8, 0x8070b8, 0x5c4c98, 0x3a2e68}, cloud = 0xc8b8f0},
  {sky1 = 0x9fe0c8, sky2 = 0xeaf8d8, h1 = 0x78cfa4, h2 = 0x62bf94, grass = 0x58c870, grass2 = 0x3ea85a,
   l = {0xd8c088, 0xb89860, 0x98784c, 0x6c4c48}, cloud = 0xf4fff0},
  {sky1 = 0xff9a5a, sky2 = 0xffdca4, h1 = 0xd06c4c, h2 = 0xb85a44, grass = 0x9ab050, grass2 = 0x7c9440,
   l = {0xe89868, 0xd06a48, 0xb04840, 0x6c2c3c}, cloud = 0xfff0d8},
  {sky1 = 0x82ccff, sky2 = 0xffe9a8, h1 = 0x90d880, h2 = 0x7cc870, grass = 0x78d070, grass2 = 0x58b050,
   l = {0xe8c878, 0xd8a048, 0xb87840, 0x6c4458}, cloud = 0xffffff},
}
P.WORLDS = WORLDS
P.VEG = {"carrot", "turnip", "mushroom", "pineapple", "pumpkin"}
P.GEM_COLS = {0xe86b9a, 0x6eb5ff, 0x6fd38a, 0xffd84a}
local GEM_COLS = P.GEM_COLS
local FLOWER = {rose = 0xff7ca8, gold = 0xffd84a, sky = 0x7fc4ff, lilac = 0xc09cff, mint = 0x7fe8b8, coral = 0xff9078}
local HATS = {0xe84855, 0xffc83a, 0x5cc878, 0xa070f0, 0}
local HAT_AT = {0, 25, 80, 160, 300}
P.HAT_AT = HAT_AT
function P.look_for(gems)
  local k = 1
  for i = 2, 5 do if gems >= HAT_AT[i] then k = i end end
  return k
end
local function hat_col(look)
  if look >= 5 then return hsv((fr() * 0.012) % 1, 0.55, 1) end
  return HATS[look] or HATS[1]
end

-- Plots of the garden (also where the veggies stand on the garden screens).
local PX = {50, 108, 166, 224, 282}
local PY = 318
local HOLEX, HOLEY = 340, 322
P.PX, P.PY = PX, PY

-- small integer hash for placing scenery (same everywhere, no rnd)
local function hs(i, k) return (i * 7919 + k * 104729 + i * i * 31) % 1000 / 1000 end

-- ------------------------------------------------------------------ veggies

-- kind 1..5 = carrot turnip mushroom pineapple pumpkin; s scale; gold = the rare golden one; dim = a silhouette.
local vdim, vgold = false, false
local function K(c) return vdim and 0x9a88aa or (vgold and mix(c, GOLD, 0.65) or c) end
local function veg(kind, x, y, s, gold, dim, noglow)
  local th = max(1, 1.8 * s)
  vdim, vgold = dim, gold
  if gold and not noglow then
    gfx.glow(x, y, 24 * s, alpha(GOLD, 150))
  end
  if kind == 1 then
    toon(function() toon.tri(x - 6 * s, y - 4 * s, x + 6 * s, y - 4 * s, x, y + 11 * s, K(0xf47a28)) end, th, INK)
    gfx.line(x - 3 * s, y - 5 * s, x - 5 * s, y - 10 * s, max(1, 2.5 * s), K(C.GRASS))
    gfx.line(x, y - 5 * s, x, y - 12 * s, max(1, 2.5 * s), K(C.GRASS))
    gfx.line(x + 3 * s, y - 5 * s, x + 5 * s, y - 10 * s, max(1, 2.5 * s), K(C.GRASS))
  elseif kind == 2 then
    toon(function() toon.circle(x, y + 2 * s, 9 * s, K(C.WHITE)) end, th, INK)
    gfx.ellipse(x, y - 3 * s, 7 * s, 3 * s, K(C.PURPLE))
    gfx.line(x, y - 6 * s, x, y - 12 * s, max(1, 3 * s), K(C.GRASS))
  elseif kind == 3 then
    toon(function()
      toon.rrect(x - 4 * s, y, 8 * s, 9 * s, 2 * s, K(C.CREAM))
      toon.ellipse(x, y - 2 * s, 10 * s, 7 * s, K(C.HAT))
    end, th, INK)
    if not dim then
      gfx.circle(x - 4 * s, y - 3 * s, 2 * s, C.WHITE)
      gfx.circle(x + 4 * s, y - 2 * s, 2 * s, C.WHITE)
    end
  elseif kind == 4 then
    toon(function() toon.ellipse(x, y + 2 * s, 8 * s, 10 * s, K(GOLD)) end, th, INK)
    gfx.tri(x - 5 * s, y - 6 * s, x, y - 13 * s, x + 5 * s, y - 6 * s, K(C.GRASS))
    if not dim then
      gfx.line(x - 4 * s, y - 1 * s, x + 4 * s, y + 7 * s, max(1, 1.2 * s), 0xd8a020)
      gfx.line(x + 4 * s, y - 1 * s, x - 4 * s, y + 7 * s, max(1, 1.2 * s), 0xd8a020)
    end
  else
    toon(function()
      toon.ellipse(x, y + 2 * s, 11 * s, 9 * s, K(0xf48a28))
      toon.rrect(x - 1.5 * s, y - 10 * s, 3 * s, 5 * s, 1 * s, K(C.GRASS))
    end, th, INK)
    if not dim then
      gfx.line(x, y - 6 * s, x, y + 10 * s, max(1, 1.3 * s), 0xd06a18)
      gfx.line(x - 5 * s, y - 5 * s, x - 5 * s, y + 9 * s, max(1, 1.1 * s), 0xd06a18)
      gfx.line(x + 5 * s, y - 5 * s, x + 5 * s, y + 9 * s, max(1, 1.1 * s), 0xd06a18)
    end
  end
  if gold and not dim then
    local a = fr() * 0.07 + kind
    gfx.star(x + cos(a) * 11 * s, y - 4 * s + sin(a) * 6 * s, 3.2 * s + 1, a, C.WHITE)
  end
end
P.veg = veg

-- ------------------------------------------------------------------ the earth (one per world)

local function stratum_edge(y, col, up)
  for x = 0, W + 12, 24 do
    gfx.circle(x, y, 12, col)
  end
end

local function paint_earth(wi, bq)
  local S = P.S
  local TOP, TILE = S.TOP, S.TILE
  local w = WORLDS[wi]
  gfx.vgrad(0, 0, W, TOP, w.sky1, w.sky2)
  -- the sky's own picture
  if wi == 2 then
    for i = 1, 22 do gfx.circle(hs(i, 1) * W, 6 + hs(i, 2) * (TOP - 40), 1.2 + hs(i, 3) * 1.2, alpha(C.WHITE, 200)) end
    gfx.glow(330, 38, 40, alpha(0xe8e0ff, 150))
    gfx.circle(330, 38, 17, 0xf4f0ff)
    gfx.circle(324, 34, 15, w.sky1)
  elseif wi == 4 then
    gfx.glow(70, TOP - 16, 90, alpha(0xff6a30, 150))
    gfx.circle(70, TOP - 10, 38, 0xffb050)
    gfx.circle(70, TOP - 10, 30, 0xffd078)
  else
    gfx.glow(336, 34, 50, alpha(0xfff2a0, 130))
    gfx.circle(336, 34, 20, 0xfff0a0)
  end
  gfx.circle(64, TOP + 14, 56, w.h1)
  gfx.circle(210, TOP + 18, 68, w.h2)
  gfx.circle(344, TOP + 12, 54, w.h1)
  if wi == 3 then   -- toadstool silhouettes on the hills
    for i = 1, 4 do
      local x = 40 + i * 78
      gfx.rect(x - 4, TOP - 34, 8, 30, 0x5ab08a)
      gfx.ellipse(x, TOP - 36, 20, 11, 0x4a9c7a)
    end
  elseif wi == 5 then   -- a far-off castle
    gfx.rect(150, TOP - 40, 70, 40, 0xb8a8d0)
    for i = 0, 3 do gfx.rect(150 + i * 20, TOP - 48, 10, 10, 0xb8a8d0) end
    gfx.rect(178, TOP - 20, 14, 20, 0x7c6a98)
  end
  -- the four strata, with scalloped edges
  for i = 1, 4 do
    local y0 = TOP + (i - 1) * TILE * 3
    gfx.rect(0, y0, W, TILE * 3, w.l[i])
    if i > 1 then stratum_edge(y0 + 1, shade(w.l[i - 1], 0.97)) end
    gfx.rect(0, y0 + (i > 1 and 6 or 0), W, 3, shade(w.l[i], 1.08))
  end
  for i = 2, 4 do
    local y0 = TOP + (i - 1) * TILE * 3
    for x = 0, W + 12, 24 do gfx.circle(x, y0 - 4, 11, w.l[i - 1]) end
    gfx.rect(0, y0 + 6, W, 3, shade(w.l[i], 0.84))
  end
  -- pebbles
  for _, d in ipairs(S.pebbles) do
    local x, y, r, k = d[1], d[2], d[3], d[4]
    local col = k == 0 and alpha(0x3a2434, 48) or alpha(0xfff6ea, 42)
    gfx.ellipse(x, y, r, r * 0.65, col)
  end
  -- what is buried in this world
  for i = 1, 34 do
    local x = 14 + hs(i, 4) * (W - 28)
    local y = TOP + 18 + hs(i, 5) * (TILE * 12 - 34)
    local k = hs(i, 6)
    if wi == 1 then
      if k < 0.5 then   -- a fossil bone
        gfx.line(x - 7, y, x + 7, y, 3, alpha(0xfff6e0, 150))
        gfx.circle(x - 8, y - 1.5, 2.4, alpha(0xfff6e0, 150))
        gfx.circle(x - 8, y + 1.5, 2.4, alpha(0xfff6e0, 150))
        gfx.circle(x + 8, y - 1.5, 2.4, alpha(0xfff6e0, 150))
        gfx.circle(x + 8, y + 1.5, 2.4, alpha(0xfff6e0, 150))
      else   -- a root
        gfx.line(x, y, x + 10, y + 7, 2, alpha(0x6a4028, 120))
        gfx.line(x + 10, y + 7, x + 18, y + 6, 1.4, alpha(0x6a4028, 120))
      end
    elseif wi == 2 then   -- little crystals, glowing
      local col = k < 0.5 and 0x9be8ff or 0xe0a8ff
      gfx.glow(x, y, 14, alpha(col, 80))
      gfx.tri(x - 4, y + 5, x, y - 7, x + 4, y + 5, alpha(col, 230))
      gfx.tri(x + 2, y + 5, x + 6, y - 2, x + 9, y + 5, alpha(shade(col, 0.85), 230))
    elseif wi == 3 then   -- buried toadstools
      gfx.rect(x - 2, y, 4, 6, alpha(C.CREAM, 190))
      gfx.ellipse(x, y, 7, 4.5, k < 0.5 and alpha(0xe8707a, 210) or alpha(0x9a78e0, 210))
      gfx.circle(x - 2, y - 1, 1.1, alpha(C.WHITE, 220))
    elseif wi == 4 then   -- embers and warm stones
      if y > TOP + 150 then
        gfx.glow(x, y, 16, alpha(0xff7a28, 100))
        gfx.circle(x, y, 3 + k * 2, 0xffa040)
      else
        gfx.ellipse(x, y, 7, 4.5, alpha(0x5a2a30, 110))
      end
    else   -- gold flecks and tiny crowns
      gfx.circle(x, y, 3, alpha(GOLD, 200))
      gfx.ring(x, y, 3, 1, alpha(0xb87820, 200))
      if k > 0.8 then gfx.glow(x, y, 12, alpha(GOLD, 80)) end
    end
  end
  if wi == 4 then   -- a glow in the deepest earth
    gfx.glow(96, TOP + 360, 90, alpha(0xff5a20, 60))
    gfx.glow(300, TOP + 372, 90, alpha(0xff5a20, 60))
  end
  -- the grass strip
  gfx.rect(0, TOP - 8, W, 14, w.grass)
  gfx.rect(0, TOP + 3, W, 4, w.grass2)
  for x = 12, W - 12, 24 do
    gfx.circle(x, TOP - 6, 7, w.grass)
    if (x / 24) % 3 == 0 then
      gfx.circle(x, TOP - 8, 2.5, C.WHITE)
      gfx.circle(x, TOP - 8, 1.2, GOLD)
    end
  end
  -- surface decoration
  if wi == 3 then
    for i = 1, 3 do
      local x = 70 + i * 90
      gfx.rect(x - 3, TOP - 22, 6, 16, C.CREAM)
      gfx.ellipse(x, TOP - 22, 14, 8, i == 2 and 0x9a78e0 or 0xe8707a)
      gfx.circle(x - 4, TOP - 24, 2, C.WHITE)
      gfx.circle(x + 4, TOP - 21, 1.6, C.WHITE)
    end
  elseif wi == 5 then
    for i = 1, 3 do
      local x = 56 + i * 96
      gfx.ellipse(x, TOP - 12, 12, 9, 0xf48a28)
      gfx.line(x, TOP - 20, x, TOP - 3, 1.2, 0xd06a18)
      gfx.rect(x - 1.5, TOP - 25, 3, 6, C.GRASS)
    end
  end
  -- Garden's bouquet (save.peek) grows on the grass: her flowers are in Dig's meadow too
  for i = 1, #bq do
    local x = 28 + i * 66 + (wi * 13) % 20
    local col = FLOWER[bq[i]] or C.ROSE
    gfx.line(x, TOP - 3, x, TOP - 14, 1.6, C.GRASS_DARK)
    for k = 0, 4 do
      local a = k * 1.2566
      gfx.circle(x + cos(a) * 4, TOP - 17 + sin(a) * 4, 3, col)
    end
    gfx.circle(x, TOP - 17, 2.2, C.WHITE)
  end
end

-- ------------------------------------------------------------------ the garden (story, map, harvest)

local function paint_garden()
  gfx.vgrad(0, 0, W, 210, 0x7ed0ff, 0xdff4ff)
  gfx.glow(320, 50, 56, alpha(0xfff2a0, 120))
  gfx.circle(320, 50, 22, 0xfff0a0)
  gfx.circle(60, 190, 90, 0x88d87a)
  gfx.circle(230, 210, 120, 0x7cc870)
  gfx.circle(380, 195, 80, 0x88d87a)
  -- the barn
  gfx.rect(18, 138, 74, 54, 0xd8584c)
  gfx.tri(10, 140, 55, 100, 100, 140, 0xa83c3c)
  gfx.rect(42, 156, 26, 36, 0x8c2c2c)
  gfx.line(42, 156, 68, 192, 2, C.CREAM)
  gfx.line(68, 156, 42, 192, 2, C.CREAM)
  gfx.rect(18, 138, 74, 3, 0x9c3434)
  -- the field and its fence
  gfx.rect(0, 232, W, 280, 0x7cc870)
  gfx.rect(0, 232, W, 8, 0x68c860)
  for x = 8, W, 26 do
    gfx.rrect(x, 214, 9, 34, 3, 0xf4ead0)
    gfx.tri(x, 215, x + 4.5, 206, x + 9, 215, 0xf4ead0)
  end
  gfx.rect(0, 224, W, 5, 0xe8dcc0)
  gfx.rect(0, 236, W, 4, 0xe8dcc0)
  gfx.rrect(14, 262, W - 28, 130, 18, C.SOIL)
  gfx.rrect(14, 262, W - 28, 6, 3, shade(C.SOIL, 1.12))
  for i = 1, 5 do
    gfx.rrect(PX[i] - 25, PY - 22, 50, 52, 14, C.SOIL_DK)
    gfx.rrect(PX[i] - 21, PY - 18, 42, 44, 12, shade(C.SOIL, 0.92))
  end
  for y = 276, 384, 22 do gfx.rect(22, y, W - 44, 2, alpha(C.SOIL_DK, 90)) end
  -- the hole the critters went down
  gfx.ellipse(HOLEX, HOLEY + 2, 34, 17, C.SOIL_DK)
  gfx.ellipse(HOLEX, HOLEY + 4, 29, 13, 0x1c1020)
  gfx.ellipse(HOLEX, HOLEY + 6, 19, 8, 0x000000)
  -- the shelf, two boards
  for k = 0, 1 do
    local y = 420 + k * 38
    gfx.rrect(8, y, W - 16, 8, 3, C.WOOD)
    gfx.rect(8, y + 6, W - 16, 3, C.WOOD_DK)
  end
end

-- The scenery is one reused picture: when the scene changes it is repainted in place (so the picture memory
-- is one layer for ever, however many caves are played), and copied to the screen every frame.
local bg, bg_key = nil, nil
local cave_wi = 1
local function paint_cave() paint_earth(cave_wi, P.S.bq) end
local function scene(key, paint)
  if not bg then bg = gfx.layer(W, H) end
  if bg_key ~= key then
    bg_key = key
    bg:paint(paint)
  end
  gfx.blit(bg, 0, 0)
end

-- ------------------------------------------------------------------ the sky's moving things

local function draw_sky_life(wi)
  if wi == 2 then
    for i = 0, 5 do
      local tw = 0.5 + 0.5 * sin(fr() * 0.07 + i * 2.1)
      gfx.glow(30 + hs(i + 40, 1) * (W - 60), 12 + hs(i + 40, 2) * 60, 7 + tw * 5, alpha(0xfff0ff, floor(60 + tw * 110)))
    end
  elseif wi == 3 then
    for i = 0, 6 do   -- drifting spores
      local x = (hs(i + 50, 1) * W + fr() * (0.2 + hs(i, 2) * 0.2)) % W
      local y = 60 + (hs(i + 50, 2) * 80 + sin(fr() * 0.03 + i) * 12) % 120 - 30 + 30
      gfx.glow(x, min(y, 84), 6, alpha(0xfff6a0, 130))
    end
  elseif wi == 4 then
    for i = 0, 7 do   -- sparks rising off the hills
      local k = ((fr() * (0.35 + hs(i + 60, 1) * 0.3) + hs(i + 60, 2) * 90) % 90) / 90
      local x = 20 + hs(i + 60, 3) * (W - 40) + sin(k * 6 + i) * 8
      gfx.glow(x, P.S.TOP - k * 80, 5 + (1 - k) * 4, alpha(0xff9040, floor(190 * (1 - k))))
    end
  else
    for i = 0, 2 do
      local x = ((fr() * 0.18 + i * 150) % (W + 80)) - 40
      local y = 26 + (i % 2) * 18
      local c = alpha(WORLDS[wi].cloud, 210)
      gfx.circle(x, y, 14, c)
      gfx.circle(x + 14, y - 4, 16, c)
      gfx.circle(x + 28, y + 1, 12, c)
    end
    if wi == 1 or wi == 5 then   -- two little birds
      for i = 0, 1 do
        local x = ((fr() * 0.5 + i * 210) % (W + 60)) - 30
        local y = 64 + i * 12 + sin(fr() * 0.05 + i) * 4
        local fl = sin(fr() * 0.3 + i) * 3
        gfx.line(x - 6, y + fl, x, y, 1.6, INK)
        gfx.line(x + 6, y + fl, x, y, 1.6, INK)
      end
    end
  end
end

-- ------------------------------------------------------------------ tunnels

local tun_layer, tun_ver = nil, -1

local function draw_tunnels()
  local S = P.S
  local COLS, ROWS, TILE, TOPY = S.COLS, S.ROWS, S.TILE, S.TOP
  local dug = S.dug
  for r = 1, ROWS do
    local cy = TOPY + (r - 0.5) * TILE
    local row = dug[r]
    for c = 1, COLS do
      if row[c] then
        local cx = (c - 0.5) * TILE
        gfx.circle(cx, cy, TILE * 0.54, C.TUNNEL_RIM)
        if c < COLS and row[c + 1] then gfx.rect(cx, cy - TILE * 0.52, TILE, TILE * 1.04, C.TUNNEL_RIM) end
        if r < ROWS and dug[r + 1][c] then gfx.rect(cx - TILE * 0.52, cy, TILE * 1.04, TILE, C.TUNNEL_RIM) end
      end
    end
  end
  for r = 1, ROWS do
    local cy = TOPY + (r - 0.5) * TILE
    local row = dug[r]
    for c = 1, COLS do
      if row[c] then
        local cx = (c - 0.5) * TILE
        gfx.circle(cx, cy, TILE * 0.45, C.TUNNEL)
        if c < COLS and row[c + 1] then gfx.rect(cx, cy - TILE * 0.44, TILE, TILE * 0.88, C.TUNNEL) end
        if r < ROWS and dug[r + 1][c] then gfx.rect(cx - TILE * 0.44, cy, TILE * 0.88, TILE, C.TUNNEL) end
      end
    end
  end
end

-- ------------------------------------------------------------------ gems and rocks

local function draw_gem(g)
  local x, y = g.x, g.y + sin(fr() * 0.1 + g.ph) * 2
  local col = GEM_COLS[g.kind] or GOLD
  local s = g.bonus and 1.35 or 1.0
  gfx.glow(x, y, 16 * s, alpha(col, 120 + floor(sin(fr() * 0.12 + g.ph) * 45)))
  toon(function()
    toon.poly({x - 8 * s, y - 2 * s, x - 4 * s, y - 8 * s, x + 4 * s, y - 8 * s, x + 8 * s, y - 2 * s, x, y + 9 * s}, col)
  end, 1.8, INK)
  gfx.tri(x - 4 * s, y - 8 * s, x, y - 2 * s, x - 8 * s, y - 2 * s, shade(col, 1.25))
  gfx.circle(x - 2 * s, y - 4 * s, 1.6 * s, alpha(C.WHITE, 230))
end
P.gem = function(x, y, kind, s)
  local col = GEM_COLS[kind] or GOLD
  toon(function()
    toon.poly({x - 8 * s, y - 2 * s, x - 4 * s, y - 8 * s, x + 4 * s, y - 8 * s, x + 8 * s, y - 2 * s, x, y + 9 * s}, col)
  end, max(1, 1.8 * s), INK)
  gfx.tri(x - 4 * s, y - 8 * s, x, y - 2 * s, x - 8 * s, y - 2 * s, shade(col, 1.25))
  gfx.circle(x - 2 * s, y - 4 * s, 1.6 * s, alpha(C.WHITE, 230))
end

local function draw_rock(rk)
  local x, y = rk.x, rk.y
  if rk.state == "wiggle" then x = x + sin(fr() * 0.9) * 3.5 end
  toon(function()
    toon.ellipse(x, y, 14, 12, C.ROCK)
    toon.ellipse(x - 4, y - 4, 8, 6, 0xb4bac6)
  end, 2.2, INK)
  gfx.line(x - 5, y + 3, x + 2, y + 6, 1.6, C.ROCK_DARK)
  gfx.line(x + 2, y - 3, x + 7, y + 1, 1.5, C.ROCK_DARK)
  if rk.state == "wiggle" then gfx.glow(x, y, 22, alpha(GOLD, 110)) end
  -- a rock with a face: it looks worried while it wobbles and glad when it has dropped a way
  if rk.state == "wiggle" then
    gfx.circle(x - 4, y + 1, 2, C.WHITE)
    gfx.circle(x + 4, y + 1, 2, C.WHITE)
    gfx.circle(x - 4, y + 2, 1, INK)
    gfx.circle(x + 4, y + 2, 1, INK)
  elseif rk.state == "fall" then
    gfx.circle(x - 4, y, 1.5, INK)
    gfx.circle(x + 4, y, 1.5, INK)
    gfx.ellipse(x, y + 5, 2.4, 3, INK)
  end
end

-- ------------------------------------------------------------------ the critters

local function look_of(e)
  local S = P.S
  local dx, dy = S.px - e.x, S.py - e.y
  local d = max(1, sqrt(dx * dx + dy * dy))
  return dx / d * 1.6, dy / d * 1.3
end

local function mood_of(e) return (e.id or 1) % 3 end   -- 0 brave, 1 sleepy, 2 sneaky

-- Puff (Pooka homage): round rosy-orange critter with big round goggles, and a face that reacts.
local function draw_puff(e, o)
  local S = P.S
  local sc = (1 + e.puff * 0.34) * (o and o.sc or 1)
  local cheer = (e.cheer or 0) > 0
  local bob = (e.puff == 0 and not cheer) and -abs(sin(fr() * 0.18 + e.ph)) * 3 or (cheer and -abs(sin(fr() * 0.4)) * 5 or sin(fr() * 0.6) * 2)
  local x, y = e.x, e.y + bob
  local r = 11 * sc
  local scared = e.puff > 0 or (S.last_rush and S.phase == "play")
  if e.ghost then gfx.glow(x, y, 22, alpha(C.AQUA, 140)) end
  if cheer then   -- arms up
    gfx.line(x - r * 0.9, y, x - r * 1.3, y - 10, 3, INK)
    gfx.line(x + r * 0.9, y, x + r * 1.3, y - 10, 3, INK)
    gfx.line(x - r * 0.9, y, x - r * 1.3, y - 10, 1.6, C.PUFF)
    gfx.line(x + r * 0.9, y, x + r * 1.3, y - 10, 1.6, C.PUFF)
  end
  toon(function()
    toon.ellipse(x - 5 * sc, y + r * 0.85, 4.5, 3, GOLD)
    toon.ellipse(x + 5 * sc, y + r * 0.85, 4.5, 3, GOLD)
    toon.circle(x, y, r, e.puff >= 2 and 0xff9268 or C.PUFF)
  end, 2.2, INK)
  local gy = y - 2 * sc
  gfx.rrect_o(x - 9 * sc, gy - 4.5 * sc, 18 * sc, 9 * sc, 4, GOLD, INK, 1.5)
  gfx.circle_o(x - 4 * sc, gy, 3.6 * sc, C.WHITE, INK, 1.2)
  gfx.circle_o(x + 4 * sc, gy, 3.6 * sc, C.WHITE, INK, 1.2)
  local lx, ly
  if o then lx, ly = o.lx or 0, o.ly or 0 else lx, ly = look_of(e) end
  local pr = scared and 2.4 or 1.8
  local m = mood_of(e)
  if m == 1 and not scared and not cheer then ly = ly + 1.2 end
  gfx.circle(x - 4 * sc + lx, gy + ly, pr, INK)
  gfx.circle(x + 4 * sc + lx, gy + ly, pr, INK)
  if m == 1 and not scared and not cheer then   -- sleepy lids
    gfx.rect(x - 7.6 * sc, gy - 3.6 * sc, 7.2 * sc, 3 * sc, GOLD)
    gfx.rect(x + 0.4 * sc, gy - 3.6 * sc, 7.2 * sc, 3 * sc, GOLD)
  end
  if m == 0 and not scared then   -- brave brows
    gfx.line(x - 8 * sc, gy - 6.5 * sc, x - 2 * sc, gy - 4.5 * sc, 1.8, INK)
    gfx.line(x + 8 * sc, gy - 6.5 * sc, x + 2 * sc, gy - 4.5 * sc, 1.8, INK)
  elseif scared then   -- brows up and worried
    gfx.line(x - 8 * sc, gy - 4.5 * sc - 2, x - 2 * sc, gy - 6.5 * sc - 2, 1.6, INK)
    gfx.line(x + 8 * sc, gy - 4.5 * sc - 2, x + 2 * sc, gy - 6.5 * sc - 2, 1.6, INK)
    if e.puff == 0 and fr() % 40 < 20 then gfx.circle(x + r * 0.9, y - r * 0.8, 1.8, C.AQUA) end
  end
  if e.puff > 0 then
    gfx.circle_o(x, y + 5 * sc, 2.5 * sc, 0xffd0c0, INK, 1.2)
  elseif cheer then
    gfx.ellipse(x, y + 5 * sc, 3.6, 2.6, INK)
  elseif m == 2 then   -- sneaky smirk
    gfx.line(x - 3, y + 6 * sc, x + 4, y + 4.4 * sc, 1.4, INK)
  elseif m == 1 then
    gfx.circle(x, y + 6 * sc, 1.3, INK)
    if fr() % 120 < 60 and dist(e.x, e.y, S.px, S.py) > 150 then gfx.text("z", x + r, y - r - 6, 12, C.WHITE, "center", INK) end
  else
    gfx.line(x - 3, y + 5.5 * sc, x + 3, y + 5.5 * sc, 1.4, INK)
  end
end

-- Char (Fygar + Charmander homage): cute orange dragon with a glowing tail flame, with a face that reacts.
local function draw_char(e, o)
  local S = P.S
  local sc = (1 + e.puff * 0.34) * (o and o.sc or 1)
  local cheer = (e.cheer or 0) > 0
  local bob = (e.puff == 0 and not cheer) and -abs(sin(fr() * 0.15 + e.ph)) * 2.5 or (cheer and -abs(sin(fr() * 0.4)) * 5 or sin(fr() * 0.6) * 2)
  local x, y = e.x, e.y + bob
  local dir = e.dx < 0 and -1 or 1
  local r = 11 * sc
  local scared = e.puff > 0 or (S.last_rush and S.phase == "play")
  local tx, ty = x - dir * (13 * sc), y + 4
  local fsize = e.fire_tele > 0 and 7.5 or (scared and 3.4 or 4.5)
  gfx.glow(tx, ty - 4, e.fire_tele > 0 and 22 or 13, alpha(C.FLAME, e.fire_tele > 0 and 210 or 140))
  if cheer then
    gfx.line(x, y - 2, x + dir * 5, y - 13, 3, INK)
    gfx.line(x, y - 2, x + dir * 5, y - 13, 1.6, C.CHAR)
  end
  toon(function()
    toon.line(x - dir * 8, y + 6, tx, ty, 4.5, C.CHAR)
    toon.ellipse(x - 5 * sc, y + r * 0.85, 4.5, 3, C.CHAR)
    toon.ellipse(x + 5 * sc, y + r * 0.85, 4.5, 3, C.CHAR)
    toon.ellipse(x, y + 1, r * 1.05, r * 0.95, e.puff >= 2 and 0xffa858 or C.CHAR)
    toon.circle(x + dir * 4 * sc, y - 5 * sc, 7.5 * sc, e.puff >= 2 and 0xffa858 or C.CHAR)
  end, 2.2, INK)
  gfx.circle(tx, ty - 4, fsize, 0xff5a28)
  gfx.circle(tx, ty - 5, fsize * 0.6, GOLD)
  gfx.ellipse(x + dir * 2, y + 4 * sc, 6 * sc, 5 * sc, C.CREAM)
  local hx, hy = x + dir * 5 * sc, y - 6 * sc
  local lx, ly
  if o then lx, ly = o.lx or 0, o.ly or 0 else lx, ly = look_of(e) end
  gfx.circle(hx, hy, (scared and 3.2 or 2.6) * sc, C.WHITE)
  gfx.circle(hx + lx * 0.6, hy + ly * 0.6, scared and 1.8 or 1.5, INK)
  local m = mood_of(e)
  if m == 1 and not scared and not cheer then gfx.rect(hx - 2.8 * sc, hy - 2.8 * sc, 5.6 * sc, 2.4 * sc, C.CHAR) end
  if m == 0 and not scared then gfx.line(hx - 3, hy - 4 * sc, hx + 3, hy - 2.6 * sc, 1.5, INK) end
  if scared and e.puff == 0 and fr() % 40 < 20 then gfx.circle(hx + dir * 6, hy - 5, 1.6, C.AQUA) end
  if e.fire_tele > 0 then
    gfx.glow(x + dir * 13, y - 3, 16, alpha(C.PURPLE, 180))
    gfx.circle_o(x + dir * 11, y - 3, 3.5, C.PURPLE, INK, 1.2)
  elseif e.puff > 0 then
    gfx.circle_o(hx + dir * 2, hy + 4.5 * sc, 2.4 * sc, 0xffd8b0, INK, 1.2)
  elseif cheer then
    gfx.ellipse(hx + dir * 2, hy + 4 * sc, 3, 2.2, INK)
  end
end
local function draw_critter(e, o)
  if e.kind == "char" then draw_char(e, o) else draw_puff(e, o) end
end
P.critter = draw_critter

-- ------------------------------------------------------------------ Diggy

-- The mood: cheer, ouch, whew, worry, pump, yawn, sleep or nil. Chosen from the game state each frame.
local function mood_now()
  local S = P.S
  if S.phase == "clear" or S.phase == "garden" or S.phase == "harvest" then return "cheer" end
  if S.hurt_cool > 60 then return "ouch" end
  if S.whew_t > 0 then return "whew" end
  if S.pump_t > 0 then return "pump" end
  if S.near < 70 then return "worry" end
  if S.still_t > 720 then return "sleep" end
  if S.still_t > 330 then return "yawn" end
  return nil
end

-- Diggy at x, y facing (fx, fy). look is 1..5 (the hat he has earned), mood as above.
local function draw_diggy(x, y, fx, fy, moving, walk_t, mood, look, shown_hat)
  local hop = mood == "cheer" and -abs(sin(fr() * 0.16)) * 10 or (moving and -abs(sin(walk_t * 0.4)) * 2 or 0)
  if mood == "sleep" then y = y + 3 end
  y = y + hop
  local idle = mood == "yawn" or mood == "sleep"
  local lamp = idle and (0.5 + 0.5 * sin(fr() * 0.05)) or 1
  gfx.glow(x + fx * 18, y + fy * 18, 28, alpha(GOLD, floor(75 * lamp)))
  local hc = hat_col(look)
  toon(function()
    local step = moving and sin(walk_t * 0.45) * 3 or 0
    toon.ellipse(x - 5 + step, y + 12, 4.5, 3, INK)
    toon.ellipse(x + 5 - step, y + 12, 4.5, 3, INK)
    toon.rrect(x - 9, y - 1, 18, 13, 6, C.SUIT)
    toon.circle(x, y - 6, 10, C.SKIN)
    toon.ellipse(x, y - 12, 11.5, 7.5, hc)
    toon.rrect(x - 13, y - 11, 26, 4, 2, C.WHITE)
  end, 2.2, INK)
  if look >= 4 then gfx.star(x - fx * 5, y - 19, 4, fr() * 0.03, C.WHITE) end
  gfx.circle_o(x + fx * 3, y - 14, 3.4, GOLD, INK, 1.2)
  gfx.circle(x + fx * 3, y - 14, 1.4, C.WHITE)
  -- the face
  local ex = fx * 2.5
  local ey = 0
  if mood == "cheer" then
    gfx.line(x - 6, y - 5, x - 3.5, y - 7.5, 1.8, INK)
    gfx.line(x - 3.5, y - 7.5, x - 1, y - 5, 1.8, INK)
    gfx.line(x + 1, y - 5, x + 3.5, y - 7.5, 1.8, INK)
    gfx.line(x + 3.5, y - 7.5, x + 6, y - 5, 1.8, INK)
    gfx.ellipse(x, y - 1, 3, 2.2, INK)
  elseif mood == "ouch" then
    gfx.line(x - 5.5, y - 8, x - 1.5, y - 6, 1.8, INK)
    gfx.line(x - 5.5, y - 4, x - 1.5, y - 6, 1.8, INK)
    gfx.line(x + 5.5, y - 8, x + 1.5, y - 6, 1.8, INK)
    gfx.line(x + 5.5, y - 4, x + 1.5, y - 6, 1.8, INK)
    gfx.ellipse(x, y - 1, 2.4, 2, INK)
    local a = fr() * 0.2
    gfx.star(x + cos(a) * 13, y - 20 + sin(a) * 3, 3.5, a, GOLD)
    gfx.star(x - cos(a) * 13, y - 20 - sin(a) * 3, 3.5, -a, GOLD)
  elseif mood == "whew" then
    gfx.line(x - 5, y - 5.5, x - 2, y - 6.5, 1.7, INK)
    gfx.line(x + 2, y - 6.5, x + 5, y - 5.5, 1.7, INK)
    gfx.ellipse(x, y - 1.4, 2.2, 1.8, INK)
    gfx.circle(x + 9, y - 9, 1.8, C.AQUA)
    gfx.tri(x + 7.4, y - 9, x + 10.6, y - 9, x + 9, y - 13, C.AQUA)
  elseif mood == "worry" then
    gfx.circle(x - 3.5 + ex, y - 6, 2.6, C.WHITE)
    gfx.circle(x + 3.5 + ex, y - 6, 2.6, C.WHITE)
    gfx.circle(x - 3.5 + ex * 1.4, y - 6, 1.4, INK)
    gfx.circle(x + 3.5 + ex * 1.4, y - 6, 1.4, INK)
    gfx.line(x - 6, y - 10, x - 2, y - 9, 1.4, INK)
    gfx.line(x + 6, y - 10, x + 2, y - 9, 1.4, INK)
    gfx.line(x - 2, y - 1.4, x - 0.5, y - 2.4, 1.3, INK)
    gfx.line(x - 0.5, y - 2.4, x + 1, y - 1.4, 1.3, INK)
    gfx.line(x + 1, y - 1.4, x + 2.4, y - 2.4, 1.3, INK)
  elseif mood == "pump" then
    gfx.line(x - 5.5 + ex, y - 6, x - 2 + ex, y - 6, 1.8, INK)
    gfx.line(x + 2 + ex, y - 6, x + 5.5 + ex, y - 6, 1.8, INK)
    gfx.circle(x, y - 1, 2.6, 0xffb0a0)
    gfx.circle(x, y - 1, 1.2, INK)
    gfx.ellipse(x - 7, y - 3, 2.8, 2, alpha(C.ROSE, 190))
    gfx.ellipse(x + 7, y - 3, 2.8, 2, alpha(C.ROSE, 190))
  elseif mood == "yawn" then
    local ls = sin(fr() * 0.04) * 2
    gfx.line(x - 5 + ls, y - 6, x - 2 + ls, y - 5.4, 1.6, INK)
    gfx.line(x + 2 + ls, y - 5.4, x + 5 + ls, y - 6, 1.6, INK)
    gfx.ellipse(x, y - 0.5, 2.6, 3 + 1.2 * sin(fr() * 0.08), INK)
  elseif mood == "sleep" then
    gfx.line(x - 5.5, y - 5.6, x - 2, y - 5.6, 1.6, INK)
    gfx.line(x + 2, y - 5.6, x + 5.5, y - 5.6, 1.6, INK)
    gfx.line(x - 2, y - 1.8, x + 2, y - 1.8, 1.3, INK)
    local k = (fr() % 120) / 120
    gfx.text("z", x + 10 + k * 8, y - 14 - k * 18, floor(12 + k * 4), C.WHITE, "center", INK)
  else
    if fr() % 150 < 6 then
      gfx.line(x - 5 + ex, y - 6, x - 2 + ex, y - 6, 1.6, INK)
      gfx.line(x + 2 + ex, y - 6, x + 5 + ex, y - 6, 1.6, INK)
    else
      gfx.circle(x - 3.5 + ex, y - 6, 1.8, INK)
      gfx.circle(x + 3.5 + ex, y - 6, 1.8, INK)
    end
    gfx.ellipse(x - 6 + ex, y - 3, 2.2, 1.4, alpha(C.ROSE, 140))
    gfx.ellipse(x + 6 + ex, y - 3, 2.2, 1.4, alpha(C.ROSE, 140))
    gfx.line(x - 2 + ex, y - 2, x + 2 + ex, y - 2, 1.4, INK)
  end
end
P.diggy = draw_diggy

-- ------------------------------------------------------------------ HUD

-- The garden tray: five plots, the planted ones show their veggie, the next one pulses.
-- (the tray's tiny veggies are stamped once each: 5 kinds x silhouette, plain, golden)
local TRAYKEY, TRAYPAINT = {}, {}
for kind = 1, 5 do
  TRAYKEY[kind], TRAYPAINT[kind] = {}, {}
  for v = 0, 2 do
    TRAYKEY[kind][v] = "dig:tray:" .. kind .. ":" .. v
    TRAYPAINT[kind][v] = function()
      veg(kind, 0, 0, 0.62, v == 2, v == 0, true)
      if v == 2 then gfx.ring(0, 1, 11, 2, alpha(GOLD, 230)) end
    end
  end
end

local function draw_tray()
  local S = P.S
  gfx.rrect_o(136, 38, 140, 28, 9, alpha(C.CREAM, 235), INK, 1.8)
  for i = 1, 5 do
    local x, y = 136 + 14 + (i - 1) * 28, 52
    local done = S.rowq[i] > 0 or i < S.slot or (i == S.slot and S.planted)
    if done then
      local v = S.rowq[i] == 2 and 2 or 1
      stamp(TRAYKEY[i][v], 40, 44, 20, 24, x, y, TRAYPAINT[i][v])
    else
      stamp(TRAYKEY[i][0], 40, 44, 20, 24, x, y, TRAYPAINT[i][0])
      if i == S.slot then
        gfx.ring(x, y, 11 + sin(fr() * 0.12) * 1.5, 1.5, alpha(GOLD, 220))
      end
    end
  end
end

local function draw_hud()
  local S = P.S
  gfx.rrect_o(8, 10, 96, 26, 9, C.CREAM, INK, 2)
  gfx.text("CAVE " .. S.level, 56, 14, 14, INK, "center")
  gfx.rrect_o(8, 40, 118, 22, 8, alpha(C.CREAM, 230), INK, 1.6)
  gfx.text("SCORE " .. S.score, 67, 43, 12, INK, "center")
  for i = 1, 3 do
    local hx = W / 2 - 26 + (i - 1) * 26
    local full = i <= (3 - S.hurts)
    gfx.heart(hx, 24, 10, INK)
    gfx.heart(hx, 24, 8, full and C.ROSE or 0x9aa4b8)
  end
  gfx.rrect_o(W - 102, 10, 94, 26, 9, C.CREAM, INK, 2)
  toon(function()
    toon.poly({W - 88, 22, W - 84, 17, W - 78, 17, W - 74, 22, W - 81, 30}, GOLD)
  end, 1.4, INK)
  gfx.text(tostring(S.gems), W - 64, 14, 14, INK, "left")
  draw_tray()
  -- the song's run: little notes light up as the pumps climb the scale
  if S.run > 0 then
    for i = 1, min(S.run, 7) do
      gfx.circle(W - 94 + (i - 1) * 11, 48, 3.6, INK)
      gfx.circle(W - 94 + (i - 1) * 11, 48, 2.6, hsv(i / 8, 0.55, 1))
    end
  end
end

-- ------------------------------------------------------------------ the shelf: what has grown across visits

local function draw_jar(x, y, k, n)
  gfx.rrect_o(x - 15, y - 20, 30, 34, 8, alpha(0xe8f8ff, 150), INK, 1.5)
  gfx.rect(x - 11, y - 24, 22, 6, C.WOOD)
  veg(k, x, y - 3, 0.9, false, n == 0)
  gfx.text(n > 0 and ("x" .. n) or "?", x, y + 14, 12, INK, "center", C.CREAM)
end

local function draw_rosette(x, y, n)
  local pulse = 1 + sin(fr() * 0.1) * 0.04
  gfx.tri(x - 8, y + 8, x - 4, y + 22, x, y + 8, C.PURPLE)
  gfx.tri(x + 8, y + 8, x + 4, y + 22, x, y + 8, C.ROSE)
  for k = 0, 9 do
    local a = k * 0.6283
    gfx.circle(x + cos(a) * 10 * pulse, y + sin(a) * 10 * pulse, 4.6, n > 0 and GOLD or 0xb8aab8)
  end
  gfx.circle_o(x, y, 8, n > 0 and C.ROSE or 0xc8bcc8, INK, 1.4)
  gfx.text(tostring(n), x, y - 6, 13, INK, "center")
end

local function draw_shelf()
  local S = P.S
  for i = 1, 5 do draw_jar(28 + (i - 1) * 40, 391, i, S.veg[i]) end
  draw_rosette(278, 385, S.harvests)
  if S.goldveg > 0 then
    veg(2, 330, 388, 0.9, true, false)
    gfx.text("x" .. S.goldveg, 346, 380, 12, INK, "left", C.CREAM)
  end
  -- second shelf: gems by colour, and the hat that comes next
  for i = 1, 4 do
    P.gem(26 + (i - 1) * 46, 438, i, 0.9)
    gfx.text(tostring(S.gk[i]), 40 + (i - 1) * 46, 430, 12, INK, "left", C.CREAM)
  end
  local look = S.look
  local nxt = HAT_AT[look + 1]
  gfx.rrect_o(214, 422, 162, 36, 10, alpha(C.CREAM, 235), INK, 1.6)
  draw_diggy(236, 442, 1, 0, false, 0, nil, look)
  if nxt then
    gfx.text("new hat: " .. S.gems .. "/" .. nxt, 300, 428, 12, INK, "center")
    gfx.rect(262, 446, 76, 5, alpha(INK, 90))
    gfx.rect(262, 446, 76 * clamp((S.gems - HAT_AT[look]) / (nxt - HAT_AT[look]), 0, 1), 5, GOLD)
  else
    gfx.text("every hat found!", 300, 432, 12, INK, "center")
  end
end

-- ------------------------------------------------------------------ the garden scenes

local function plot_veg(i, s, grade, bounce)
  local x, y = PX[i], PY - 2 - (bounce or 0)
  local sway = sin(fr() * 0.05 + i) * 1.5
  veg(i, x + sway, y, s, grade == 2)
  if grade == 1 then
    gfx.star(x + 14 * s, y - 12 * s + sin(fr() * 0.1 + i) * 2, 3.5, fr() * 0.05, C.WHITE)
  end
end

local function seg(t, a, b) return clamp((t - a) / (b - a), 0, 1) end

-- the five critters of the story, reused every frame
local CR = {
  {kind = "puff", x = 0, y = 0, dx = 1, dy = 0, puff = 0, ph = 0.3, id = 1, fire_tele = 0},
  {kind = "char", x = 0, y = 0, dx = 1, dy = 0, puff = 0, ph = 1.5, id = 2, fire_tele = 0},
  {kind = "puff", x = 0, y = 0, dx = 1, dy = 0, puff = 0, ph = 2.7, id = 3, fire_tele = 0},
}
local LO = {lx = 1, ly = 0, sc = 1.3}

local function bag(x, y, dir)
  toon(function() toon.ellipse(x - dir * 12, y - 4, 9, 11, 0xc8a070) end, 1.8, INK)
  gfx.line(x - dir * 12, y - 14, x - dir * 12, y - 10, 2, 0x8a6a3c)
end

-- Story: the critters carry the veggies off, Diggy follows. t counts frames from the start (or from 170
-- for someone who has seen it before).
local STEAL = {70, 88, 106, 124, 142}
local TAKER = {1, 1, 2, 2, 3}
function P.story(t)
  local S = P.S
  scene("dig:garden", paint_garden)
  gfx.text("THE VEGGIE GARDEN", W / 2, 14, 22, C.CREAM, "center", INK)
  for i = 1, 5 do
    if t < STEAL[i] then plot_veg(i, 1.35, 0, 0)
    elseif t < STEAL[i] + 14 then   -- floating up into the sack
      local c = CR[TAKER[i]]
      local k = (t - STEAL[i]) / 14
      veg(i, lerp(PX[i], c.x, k), lerp(PY - 2, c.y - 10, k) - sin(k * 3.14) * 14, 1.35 * (1 - k * 0.5))
    elseif t < 230 then
      gfx.ellipse(PX[i], PY - 4, 14, 8, alpha(0x000000, 40))
      if blink(60, 36) then gfx.text("?", PX[i], PY - 22, 22, C.CREAM, "center", INK) end
    else
      gfx.text("?", PX[i], PY - 22, 22, C.CREAM, "center", INK)
    end
  end
  -- the thieves
  for k = 1, 3 do
    local c = CR[k]
    local tx = PX[k == 1 and 1 or k == 2 and 3 or 5] + 12
    local arrive = seg(t, 10 + k * 8, 66 + k * 8)
    local run = seg(t, 176 + k * 12, 236 + k * 12)
    if run >= 1 then
      c.x = -999
    else
      c.x = lerp(-30, tx, ease.out_quad(arrive))
      c.y = PY + 34 + (k - 2) * 7
      if run > 0 then
        c.x = lerp(tx, HOLEX, run)
        c.y = lerp(c.y, HOLEY, run) - sin(run * 3.14) * 22
      end
      c.dx = 1
      local stolen = t >= STEAL[k == 1 and 2 or k == 2 and 4 or 5]
      if stolen then bag(c.x, c.y, 1) end
      LO.lx, LO.ly = 1.4, 0
      draw_critter(c, LO)
    end
  end
  -- hole: critters' eyes watch from it after
  if t > 250 then
    local b = fr() % 140 < 130
    gfx.circle(HOLEX - 7, HOLEY + 4, b and 3 or 0.6, C.WHITE)
    gfx.circle(HOLEX + 7, HOLEY + 4, b and 3 or 0.6, C.WHITE)
    gfx.circle(HOLEX - 7, HOLEY + 4, 1.4, INK)
    gfx.circle(HOLEX + 7, HOLEY + 4, 1.4, INK)
  end
  -- Diggy comes in, looks, and hops after them
  if t > 250 then
    local k = seg(t, 250, 310)
    local dx = lerp(-20, 250, ease.out_quad(k))
    local dy = PY + 40
    local hop = seg(t, 330, 362)
    if hop > 0 then
      dx = lerp(250, HOLEX, hop)
      dy = lerp(dy, HOLEY, hop) - sin(hop * 3.14) * 30
    end
    if hop < 1 then
      draw_diggy(dx, dy, 1, 0, k < 1, t, (k >= 1 and hop == 0) and (t > 300 and "worry" or nil) or (hop > 0 and "cheer" or nil), S.look)
      if k >= 1 and hop == 0 and t > 300 and blink(30, 22) then
        gfx.glow(dx + 12, dy - 14, 24, alpha(GOLD, 180))
      end
    end
  end
  draw_shelf()
end

function P.story_line(t)
  if t < 66 then return "The veggie garden is full!" end
  if t < 236 then return "Oh no! The critters took the veggies!" end
  return "Dig after them, Diggy!"
end

-- The garden map between caves. t counts frames since the clear banner went away; slot is the plot just
-- planted; the new veggie arcs from Diggy into it.
function P.garden(t)
  local S = P.S
  scene("dig:garden", paint_garden)
  gfx.text("ROW " .. (idiv(S.level - 1, 5) + 1) .. " OF THE GARDEN", W / 2, 14, 20, C.CREAM, "center", INK)
  local slot = S.slot
  local fly = seg(t, 18, 62)
  for i = 1, 5 do
    if i < slot or (i == slot and fly >= 1) then
      local b = (i == slot) and abs(sin(clamp(t - 62, 0, 20) * 0.157)) * 12 * max(0, 1 - (t - 62) / 20) or 0
      plot_veg(i, 1.35, S.rowq[i], b)
    elseif i == slot then
      -- the veggie in the air
      local x = lerp(max(26, PX[i] - 40), PX[i], fly)
      local y = lerp(PY + 36, PY - 2, fly) - sin(fly * 3.14) * 50
      veg(i, x, y, 1.35, S.rowq[i] == 2)
    else
      gfx.ellipse(PX[i], PY - 4, 14, 8, alpha(0x000000, 40))
      if i == slot + 1 then
        veg(i, PX[i], PY - 4 + sin(fr() * 0.08) * 2, 1.1, false, true)
        gfx.text("?", PX[i], PY - 30, 18, C.CREAM, "center", INK)
      end
    end
  end
  -- critters peeking out of the hole
  local b = fr() % 150 < 138
  gfx.circle(HOLEX - 7, HOLEY + 4, b and 3 or 0.6, C.WHITE)
  gfx.circle(HOLEX + 7, HOLEY + 4, b and 3 or 0.6, C.WHITE)
  gfx.circle(HOLEX - 7 + sin(fr() * 0.03) * 1.2, HOLEY + 4, 1.4, INK)
  gfx.circle(HOLEX + 7 + sin(fr() * 0.03) * 1.2, HOLEY + 4, 1.4, INK)
  draw_diggy(max(26, PX[slot] - 40), PY + 44, 1, 0, false, 0, "cheer", S.look)
  -- Diggy's hands up
  
  draw_shelf()
end

-- The harvest party: every plot at once, the critters bring the basket back.
function P.harvest(t)
  local S = P.S
  scene("dig:garden", paint_garden)
  -- bunting
  for i = 0, 11 do
    local x = i * 34 + 8
    local y = 34 + sin(i * 0.6) * 6
    gfx.tri(x, y, x + 24, y, x + 12, y + 20, ({C.ROSE, GOLD, C.AQUA, 0x9fe08a})[i % 4 + 1])
  end
  gfx.line(0, 34, W, 34, 2, INK)
  local k = ease.out_back(seg(t, 0, 36))
  gfx.glow(W / 2, 90, 130 * k, alpha(GOLD, 90))
  gfx.text("HARVEST PARTY!", W / 2, 58 - (1 - k) * 60, floor(32 + sin(fr() * 0.1) * 1.5), GOLD, "center", INK)
  gfx.text("The veggies are home!", W / 2, 100, 16, C.PURPLE, "center", C.CREAM)
  for i = 1, 5 do
    local b = abs(sin(fr() * 0.12 + i * 0.9)) * 6
    plot_veg(i, 1.5, S.rowq[i], b)
  end
  -- the critters come out of the hole with the basket, party hats on, smiling
  local arrive = seg(t, 40, 130)
  local bx = lerp(HOLEX, 192, ease.out_quad(arrive))
  local by = lerp(HOLEY, 372, arrive) - sin(arrive * 3.14) * 24
  for c = 1, 3 do
    local e = CR[c]
    e.x = bx + (c - 2) * 34 + (c == 2 and 0 or (c == 1 and -4 or 4))
    e.y = by + (c == 2 and -6 or 4)
    e.dx = c == 1 and 1 or -1
    e.cheer = arrive >= 1 and 1 or 0
    e.puff = 0
    LO.lx, LO.ly = 0, 1
    draw_critter(e, LO)
    local hx = e.x
    gfx.tri(hx - 6, e.y - 13, hx + 6, e.y - 13, hx, e.y - 28, c == 2 and GOLD or C.ROSE)
    gfx.circle(hx, e.y - 29, 2.4, C.WHITE)
    e.cheer = 0
  end
  -- the basket of veggies
  gfx.ellipse(bx, by + 22, 32, 8, alpha(0x000000, 40))
  veg(1, bx - 14, by + 6, 1.1, false)
  veg(2, bx + 2, by + 3, 1.1, false)
  veg(5, bx + 17, by + 6, 1.1, false)
  toon(function() toon.rrect(bx - 28, by + 8, 56, 22, 8, 0xc8904c) end, 2.2, INK)
  for i = -2, 2 do gfx.line(bx + i * 11, by + 10, bx + i * 11, by + 28, 1.4, 0x9a6a30) end
  -- Diggy dances to the left
  draw_diggy(64, 372, 1, 0, false, 0, "cheer", S.look)
  draw_diggy(320, 372, -1, 0, false, 0, "cheer", S.look)
  draw_shelf()
end

-- ------------------------------------------------------------------ the cave

function P.world_key()
  local S = P.S
  return "dig:earth:" .. S.world .. ":" .. S.bq_key
end

function P.draw_cave()
  local S = P.S
  local wi = S.world
  cave_wi = wi
  scene(P.world_key(), paint_cave)
  draw_sky_life(wi)
  if not tun_layer then tun_layer = gfx.layer(W, H) end
  if tun_ver ~= S.dug_ver then
    tun_ver = S.dug_ver
    tun_layer:paint(draw_tunnels)
  end
  gfx.blit_key(tun_layer, 0, 0)
  for _, g in ipairs(S.gems_list) do draw_gem(g) end
  if S.veggie then
    local v = S.veggie
    local vy = v.y + sin(fr() * 0.14) * 2.5
    gfx.glow(v.x, vy, v.gold and 30 or 22, alpha(GOLD, v.gold and 220 or 160))
    veg(v.kind, v.x, vy, v.gold and 1.25 or 1, v.gold)
  end
  for _, rk in ipairs(S.rocks) do draw_rock(rk) end
  for _, f in ipairs(S.flames) do
    gfx.glow(f.x, f.y, 18, alpha(C.PURPLE, 170))
    soap(f.x, f.y, 10, C.PURPLE)
    gfx.circle(f.x, f.y, 5, C.FLAME)
  end
  if S.aim and S.phase == "play" then
    for k = 0, 3 do
      local a = fr() * 0.09 + k * 1.571
      gfx.star(S.aim.x + cos(a) * 20, S.aim.y + sin(a) * 20, 5.5, a, INK)
      gfx.star(S.aim.x + cos(a) * 20, S.aim.y + sin(a) * 20, 4, a, GOLD)
    end
  end
  for _, e in ipairs(S.foes) do draw_critter(e) end
  if S.pump and S.pump.t > 0 then
    local p = S.pump
    local k = p.t / 12
    gfx.line(p.x0, p.y0, p.x1, p.y1, 7 * k + 2, alpha(C.AQUA, floor(180 * k)))
    gfx.line(p.x0, p.y0, p.x1, p.y1, 3 * k + 1, alpha(C.WHITE, floor(255 * k)))
    soap(p.x1, p.y1, 10 + (1 - k) * 8, C.AQUA)
    p.t = p.t - 1
  end
  if S.hurt_cool == 0 or idiv(S.hurt_cool, 4) % 2 == 0 then
    draw_diggy(S.px, S.py, S.face_x, S.face_y, S.moving, S.walk_t, mood_now(), S.look)
  end
  if S.whew_t > 0 then
    gfx.text("whew!", S.px, S.py - 36 - (30 - min(S.whew_t, 30)) * 0.4, 14, C.WHITE, "center", INK)
  end
  -- the veggie Diggy found, held high
  if S.phase == "clear" then
    local hy = S.py - 34 - abs(sin(fr() * 0.16)) * 8
    veg(S.slot, S.px, hy, 1.3, S.rowq[S.slot] == 2)
  end
  draw_hud()
end

function P.draw_clear_banner()
  local S = P.S
  local k = ease.out_back(clamp(S.clear_t / 30, 0, 1))
  local by = lerp(-80, 194, k)
  local bw, bh = 312, 96
  local bx = (W - bw) / 2
  gfx.glow(W / 2, by + bh / 2, 130 * k, alpha(GOLD, 100))
  gfx.rrect_o(bx, by, bw, bh, 14, C.CREAM, INK, 3)
  gfx.rrect(bx + 5, by + 5, bw - 10, bh - 10, 10, 0xfff0d0)
  gfx.star(bx + 18, by + 22, 8, fr() * 0.08, GOLD)
  gfx.star(bx + bw - 18, by + 22, 8, -fr() * 0.08, GOLD)
  gfx.text("CAVE " .. S.level .. " CLEAR!", W / 2, by + 12, 28, GOLD, "center", INK)
  veg(S.slot, bx + 40, by + 66, 1.2, S.rowq[S.slot] == 2)
  local sub = "The " .. P.VEG[S.slot] .. " is saved!"
  gfx.text(sub, W / 2 + 14, by + 54, 16, C.PURPLE, "center", C.CREAM)
  if S.clear_t >= 90 and blink(46, 30) then
    gfx.rrect_o(W / 2 - 118, 396, 236, 30, 12, GOLD, INK, 2)
    gfx.text("PRESS FOR THE GARDEN!", W / 2, 402, 15, INK, "center")
  end
end

return P
