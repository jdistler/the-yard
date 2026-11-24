-- Handcrafted art for Safari: three habitats and three gyms painted on ONE reusable scene layer (repainted in place
-- when the scene changes, so memory stays flat), eight friends (each with a shiny coat and a silhouette), Hoot the
-- owl ranger, the three gym leaders, the trainer, the Field Book pages, badges, the story, the HUD.
-- Nothing here uses rnd(): scenery is placed by integer hashes, motion by game.frame.

local P = {}
P.S = nil   -- main.lua hands over its state

local C = {
  CREAM = 0xfff6ea, INK = 0x34243e, GOLD = 0xffd84a, RED = 0xe84855,
  BLUE = 0x4ca8f5, GREEN = 0x58c464, PURPLE = 0x7e4ce8, ORANGE = 0xf48430,
  PIKA = 0xffdc36, CYAN = 0x6ce4ff, ROSE = 0xf06898, WHITE = 0xfffcf8,
  SKIN = 0xf6c9a2, CAP = 0xe63e4c, TEAL = 0x48b8a8, SHELL = 0x9c5a2c,
  BROWN = 0x7a4824, DARK = 0x241a30, LEAF = 0x389c48, LIME = 0x92e468,
  MINT = 0x76d8b4, NAVY = 0x365c72, SILVER = 0xd8e0ec, SIL = 0x4a3a62,
  PAPER = 0xf4e6c4, PAPER2 = 0xe8d4a4, OWL = 0x9a6a3c, OWL2 = 0xc89a64,
}
P.C = C

local ZONES = {
  {name = "Sunny Meadow", top = 0x7ed874, bot = 0x5ab858, path = 0xebd4aa, edge = 0xc8a876, accent = 0x429c46,
   gym = "CLOVER GYM", leader = "Captain Clover"},
  {name = "Spark Cave",   top = 0x5c4c7a, bot = 0x3c3056, path = 0x86789c, edge = 0x625478, accent = 0x7ce8ff,
   gym = "GLINT GYM", leader = "Miss Glint"},
  {name = "Crystal Pond", top = 0x5cc0e8, bot = 0x3b96c8, path = 0xe8d8b0, edge = 0xc4b084, accent = 0x76e8c8,
   gym = "RIPPLE GYM", leader = "Skipper Ripple"},
}
P.ZONES = ZONES
P.HOOT_X, P.HOOT_Y = 336, 404   -- Hoot's lookout post in every habitat (where the Field Book opens)

local function hash(i, m) return (i * 7919 + 104729) % m end   -- integer scatter, no rnd

-- ------------------------------------------------------------------ the one scene layer
local layer, layer_id = nil, ""
local PAINT = {}

local function post_and_arch(z)
  -- Hoot's lookout post
  gfx.ellipse(P.HOOT_X, P.HOOT_Y + 34, 20, 6, alpha(C.DARK, 70))
  gfx.rrect_o(P.HOOT_X - 6, P.HOOT_Y + 10, 12, 26, 3, C.BROWN, C.INK, 2)
  gfx.rrect_o(P.HOOT_X - 16, P.HOOT_Y + 6, 32, 9, 4, 0xa8703c, C.INK, 2)
  gfx.line(P.HOOT_X - 5, P.HOOT_Y + 28, P.HOOT_X + 5, P.HOOT_Y + 28, 1.5, alpha(C.INK, 90))
  -- the Gym arch
  gfx.rrect_o(126, 86, 132, 52, 12, C.CREAM, C.INK, 2.5)
  gfx.rrect(128, 88, 128, 18, 10, C.RED)
  gfx.rect(128, 103, 128, 3, C.INK)
  gfx.circle_o(192, 104, 6, C.WHITE, C.INK, 1.8)
  gfx.text(ZONES[z].gym, 192, 114, 15, C.GOLD, "center", C.INK)
end

local function paint_zone(z)
  local Z = ZONES[z]
  gfx.vgrad(0, 0, W, H - 32, Z.top, Z.bot)

  if z == 1 then
    -- far hills, clouds, and a sun
    gfx.ellipse(70, 140, 130, 40, 0x6ac864)
    gfx.ellipse(330, 144, 120, 36, 0x62c05c)
    gfx.circle(44, 74, 20, alpha(C.GOLD, 90))
    gfx.circle(44, 74, 13, 0xfff09a)
    for _, c in ipairs({{300, 80, 1.0}, {120, 96, 0.7}, {352, 112, 0.6}}) do
      gfx.ellipse(c[1], c[2], 28 * c[3], 9 * c[3], alpha(C.WHITE, 230))
      gfx.circle(c[1] - 10 * c[3], c[2] - 6 * c[3], 10 * c[3], alpha(C.WHITE, 230))
      gfx.circle(c[1] + 6 * c[3], c[2] - 9 * c[3], 12 * c[3], alpha(C.WHITE, 230))
    end
    gfx.rrect(164, 128, 56, 326, 20, Z.edge)
    gfx.rrect(170, 132, 44, 320, 16, Z.path)
    gfx.rrect(0, 260, W, 56, 0, Z.edge)
    gfx.rrect(0, 266, W, 44, 0, Z.path)
    -- path pebbles
    for i = 1, 16 do
      gfx.ellipse(176 + hash(i, 32), 150 + i * 17, 2.4, 1.6, alpha(C.BROWN, 100))
    end
    local tufts = {{56, 198}, {314, 198}, {68, 368}, {312, 376}}
    for _, t in ipairs(tufts) do
      gfx.ellipse(t[1], t[2] + 8, 42, 22, 0x4ca84c)
      for k = -2, 2 do
        local bx = t[1] + k * 14
        gfx.tri(bx - 5, t[2] + 10, bx, t[2] - 10 - (k % 2) * 5, bx + 5, t[2] + 10, 0x368c3c)
        gfx.tri(bx - 3, t[2] + 10, bx + 1, t[2] - 7 - (k % 2) * 4, bx + 4, t[2] + 10, 0x68cc5a)
      end
    end
    for _, fx in ipairs({30, 54, 78, 102, 282, 306, 330, 354}) do
      gfx.rrect_o(fx - 4, 126, 8, 22, 2, C.WHITE, C.INK, 1.4)
    end
    gfx.rect(24, 134, 86, 4, C.WHITE)
    gfx.rect(276, 134, 86, 4, C.WHITE)
    local fl = {{36, 232, C.GOLD}, {126, 200, C.ROSE}, {260, 194, C.WHITE}, {348, 240, C.GOLD},
                {70, 440, C.WHITE}, {132, 412, C.ROSE}, {258, 420, C.GOLD}, {268, 330, C.ROSE},
                {110, 330, C.WHITE}, {354, 330, C.GOLD}}
    for _, f in ipairs(fl) do
      gfx.line(f[1], f[2], f[1], f[2] + 9, 1.5, 0x368c3c)
      gfx.circle(f[1], f[2], 4.5, f[3])
      gfx.circle(f[1], f[2], 1.8, C.GOLD)
    end
    -- a tree in two corners
    for _, tr in ipairs({{20, 410}, {366, 170}}) do
      gfx.ellipse(tr[1], tr[2] + 32, 20, 5, alpha(C.DARK, 60))
      gfx.rrect_o(tr[1] - 5, tr[2] + 6, 10, 26, 3, C.BROWN, C.INK, 1.6)
      gfx.circle_o(tr[1], tr[2], 22, 0x3ea64a, C.INK, 2)
      gfx.circle(tr[1] - 7, tr[2] - 7, 7, 0x5cc860)
    end
  elseif z == 2 then
    -- cavern ceiling with stalactites
    for i = 0, 11 do
      local x = 16 + i * 34
      local h = 20 + hash(i + 3, 30)
      gfx.tri(x - 14, 60, x, 60 + h, x + 14, 60, 0x2c2240)
      gfx.tri(x - 8, 60, x, 60 + h - 6, x + 8, 60, 0x483864)
    end
    for _, cx in ipairs({28, 84, 300, 356}) do
      gfx.circle(cx, 124, 34, 0x34284a)
      gfx.circle(cx, 120, 26, 0x483864)
    end
    gfx.rrect(164, 128, 56, 326, 20, Z.edge)
    gfx.rrect(170, 132, 44, 320, 16, Z.path)
    gfx.rrect(0, 260, W, 56, 0, Z.edge)
    gfx.rrect(0, 266, W, 44, 0, Z.path)
    for i = 1, 8 do   -- stepping stones on the path
      gfx.ellipse(192, 150 + i * 36, 11, 5, alpha(C.WHITE, 40))
    end
    local crys = {{54, 198, C.CYAN}, {326, 196, C.GOLD}, {64, 376, C.ROSE}, {318, 374, C.CYAN}}
    for _, cr in ipairs(crys) do
      gfx.glow(cr[1], cr[2], 32, alpha(cr[3], 90))
      gfx.tri(cr[1] - 12, cr[2] + 12, cr[1] - 6, cr[2] - 14, cr[1], cr[2] + 12, cr[3])
      gfx.tri(cr[1] - 4, cr[2] + 12, cr[1] + 4, cr[2] - 20, cr[1] + 12, cr[2] + 12, cr[3])
      gfx.tri(cr[1] + 6, cr[2] + 12, cr[1] + 14, cr[2] - 10, cr[1] + 18, cr[2] + 12, C.WHITE)
    end
    for i = 1, 14 do
      local px, py = 24 + (i * 53) % (W - 48), 156 + (i * 71) % 280
      gfx.ellipse(px, py, 6, 3.5, 0x2c2240)
    end
    -- glow-mushrooms
    for _, m in ipairs({{30, 300}, {356, 296}, {120, 444}, {268, 440}}) do
      gfx.glow(m[1], m[2], 16, alpha(C.ROSE, 90))
      gfx.rrect(m[1] - 2, m[2], 4, 10, 2, 0xe8dcc8)
      gfx.ellipse_o(m[1], m[2], 9, 6, 0xc46ad8, C.INK, 1.4)
      gfx.circle(m[1] - 3, m[2] - 1, 1.6, C.WHITE)
    end
  else
    -- far shore, reeds, a little sun glitter
    gfx.ellipse(60, 138, 110, 30, 0x8cd8a0)
    gfx.ellipse(340, 142, 110, 28, 0x82d098)
    for _, c in ipairs({{110, 84, 0.8}, {300, 92, 1.0}}) do
      gfx.ellipse(c[1], c[2], 28 * c[3], 8 * c[3], alpha(C.WHITE, 220))
      gfx.circle(c[1] - 8 * c[3], c[2] - 6 * c[3], 10 * c[3], alpha(C.WHITE, 220))
    end
    gfx.rrect(162, 128, 60, 326, 14, Z.edge)
    gfx.rrect(168, 132, 48, 320, 10, Z.path)
    gfx.rrect(0, 260, W, 56, 0, Z.edge)
    gfx.rrect(0, 266, W, 44, 0, Z.path)
    for py = 148, 438, 18 do
      gfx.line(170, py, 214, py, 1.5, alpha(C.BROWN, 120))
    end
    local pads = {{62, 198}, {318, 202}, {66, 372}, {314, 378}, {114, 224}, {270, 344}}
    for i, lp in ipairs(pads) do
      gfx.circle_o(lp[1], lp[2], 18, 0x48b862, 0x2c7844, 1.8)
      gfx.tri(lp[1], lp[2], lp[1] + 19, lp[2] - 6, lp[1] + 19, lp[2] + 6, Z.bot)
      if i <= 4 then
        gfx.circle(lp[1] - 4, lp[2] - 4, 5, C.ROSE)
        gfx.circle(lp[1] - 4, lp[2] - 4, 2, C.GOLD)
      end
    end
    for _, rx in ipairs({26, 360, 100, 288}) do   -- reeds
      for k = 0, 2 do
        gfx.line(rx + k * 5, 456, rx + k * 5 + (k - 1) * 3, 420 - k * 6, 2.2, 0x3c8c58)
        gfx.ellipse(rx + k * 5 + (k - 1) * 3, 416 - k * 6, 2.6, 6, 0x7a4824)
      end
    end
  end
  post_and_arch(z)
end
for z = 1, 3 do PAINT["z" .. z] = function() paint_zone(z) end end

-- the three arenas: the same court, three moods
local function paint_gym(gi)
  if gi == 1 then
    gfx.vgrad(0, 0, W, H - 32, 0x72c4f2, 0xc2eaa8)
    gfx.ellipse(60, 104, 110, 34, 0x74cc6c)
    gfx.ellipse(330, 108, 110, 30, 0x6cc464)
    for i = 0, 9 do   -- bunting
      local x = 20 + i * 38
      gfx.tri(x, 62, x + 30, 62, x + 15, 86 - (i % 2) * 6, (i % 3 == 0) and C.RED or ((i % 3 == 1) and C.GOLD or C.WHITE))
    end
    gfx.line(0, 62, W, 62, 2, C.INK)
  elseif gi == 2 then
    gfx.vgrad(0, 0, W, H - 32, 0x241c3c, 0x3a2c58)
    for i = 0, 11 do
      local x = 14 + i * 34
      gfx.tri(x - 14, 60, x, 80 + hash(i + 5, 28), x + 14, 60, 0x4a3868)
    end
    for _, cr in ipairs({{40, 100, C.CYAN}, {344, 100, C.ROSE}, {192, 70, C.GOLD}}) do
      gfx.glow(cr[1], cr[2], 36, alpha(cr[3], 70))
      gfx.tri(cr[1] - 8, cr[2] + 14, cr[1], cr[2] - 18, cr[1] + 8, cr[2] + 14, cr[3])
    end
  else
    gfx.vgrad(0, 0, W, H - 32, 0x58b8e8, 0x2c7cb8)
    for i = 0, 10 do   -- far waves
      gfx.ellipse(10 + i * 36, 100 + (i % 2) * 6, 30, 8, alpha(C.WHITE, 90))
    end
    for _, lp in ipairs({{30, 88}, {354, 92}, {110, 74}, {280, 78}}) do
      gfx.circle_o(lp[1], lp[2], 14, 0x48b862, 0x2c7844, 1.6)
      gfx.circle(lp[1] - 3, lp[2] - 3, 4, C.ROSE)
    end
  end
  local court = (gi == 1) and 0x5c9668 or ((gi == 2) and 0x5a5878 or 0xb89860)
  local rim = (gi == 1) and 0x4a7e5a or ((gi == 2) and 0x4a4668 or 0x8a6c3c)
  gfx.rrect_o(18, 118, W - 36, 326, 20, rim, C.INK, 3)
  gfx.rrect(26, 126, W - 52, 310, 14, court)
  if gi == 3 then   -- dock planks
    for py = 134, 430, 20 do gfx.line(30, py, W - 30, py, 1.5, alpha(C.BROWN, 110)) end
  elseif gi == 2 then
    for i = 0, 9 do gfx.ellipse(40 + hash(i * 3 + 1, 300), 140 + hash(i * 5 + 2, 280), 14, 5, alpha(C.WHITE, 22)) end
  else
    for i = 0, 7 do gfx.line(26, 140 + i * 40, W - 26, 140 + i * 40, 18, alpha(C.WHITE, 12)) end
  end
  gfx.line(26, 280, W - 26, 280, 3, alpha(C.WHITE, 140))
  gfx.circle_o(W / 2, 280, 38, alpha(C.WHITE, 45), alpha(C.WHITE, 160), 3)
  gfx.circle_o(W / 2, 280, 12, alpha(C.GOLD, 120), alpha(C.WHITE, 180), 2.5)
  gfx.ellipse_o(192, 188, 92, 26, alpha(C.CREAM, 195), C.INK, 2.2)
  gfx.ellipse_o(192, 368, 102, 28, alpha(C.CREAM, 195), C.INK, 2.2)
  -- the stands, with a cheering row of empty seats (your friends sit here in the game)
  gfx.rrect(26, 108, W - 52, 12, 5, alpha(C.DARK, 90))
end
for g = 1, 3 do PAINT["g" .. g] = function() paint_gym(g) end end

PAINT.story = function()
  gfx.vgrad(0, 0, W, H - 32, 0x120c2c, 0x40306c)
  for i = 1, 46 do
    local x, y = hash(i * 3 + 1, W - 8) + 4, hash(i * 5 + 2, 300) + 8
    gfx.circle(x, y, (i % 4 == 0) and 1.8 or 1.1, alpha(C.WHITE, 150 + (i % 3) * 30))
  end
  gfx.circle(330, 70, 24, 0xfff2b8)
  gfx.glow(330, 70, 40, alpha(0xfff2b8, 60))
  -- the three lands along the bottom
  gfx.rect(0, 330, 128, 150, 0x5ab858)
  gfx.ellipse(64, 330, 80, 26, 0x6ed46a)
  gfx.rect(128, 330, 128, 150, 0x3c3056)
  gfx.ellipse(192, 330, 80, 26, 0x5c4c7a)
  gfx.rect(256, 330, 128, 150, 0x3b96c8)
  gfx.ellipse(320, 330, 80, 26, 0x5cc0e8)
  gfx.line(128, 330, 128, 480, 3, C.INK)
  gfx.line(256, 330, 256, 480, 3, C.INK)
  for _, cr in ipairs({{160, 360, C.CYAN}, {226, 372, C.ROSE}}) do
    gfx.glow(cr[1], cr[2], 20, alpha(cr[3], 80))
    gfx.tri(cr[1] - 6, cr[2] + 10, cr[1], cr[2] - 12, cr[1] + 6, cr[2] + 10, cr[3])
  end
  for _, f in ipairs({{20, 440, C.GOLD}, {104, 452, C.ROSE}, {50, 462, C.WHITE}}) do
    gfx.circle(f[1], f[2], 4, f[3])
  end
  for _, lp in ipairs({{290, 446}, {350, 458}}) do
    gfx.circle_o(lp[1], lp[2], 12, 0x48b862, 0x2c7844, 1.4)
  end
end

function P.build_bgs()
  layer = gfx.layer(W, H)
  layer_id = ""
end

function P.scene(id)
  if not layer then layer = gfx.layer(W, H) end
  if layer_id ~= id then
    layer_id = id
    layer:paint(PAINT[id])
  end
  gfx.blit(layer, 0, 0)
end

-- live touches over the painted habitat: lanterns, zone arrows, and a little life
function P.draw_habitat(z)
  local f = game.frame
  local glow_a = 120 + floor(sin(f * 0.1) * 45)
  gfx.glow(128, 116, 18, alpha(C.GOLD, glow_a))
  gfx.glow(256, 116, 18, alpha(C.GOLD, glow_a))
  local bob = sin(f * 0.12) * 3
  gfx.rrect_o(6 + bob, 274, 24, 28, 8, alpha(C.CREAM, 210), C.INK, 1.8)
  gfx.text("<", 18 + bob, 278, 18, C.INK, "center")
  gfx.rrect_o(W - 30 - bob, 274, 24, 28, 8, alpha(C.CREAM, 210), C.INK, 1.8)
  gfx.text(">", W - 18 - bob, 278, 18, C.INK, "center")
  if z == 1 then   -- two butterflies
    for k = 0, 1 do
      local bx = 120 + k * 150 + sin(f * 0.021 + k * 2) * 60
      local by = 220 + k * 90 + sin(f * 0.043 + k) * 20
      local fl = abs(sin(f * 0.4 + k)) * 4
      gfx.ellipse(bx - 3, by, 3 + fl * 0.3, 4, k == 0 and C.ROSE or C.GOLD)
      gfx.ellipse(bx + 3, by, 3 + fl * 0.3, 4, k == 0 and C.ROSE or C.GOLD)
      gfx.line(bx, by - 3, bx, by + 3, 1.6, C.INK)
    end
  elseif z == 2 then   -- twinkling cave sparks
    for k = 0, 5 do
      local a = (f * 2 + k * 43) % 160
      if a < 80 then
        local sx = 40 + hash(k * 11 + 3, 300)
        local sy = 150 + hash(k * 17 + 5, 280)
        gfx.glow(sx, sy, 6 + a * 0.08, alpha(C.CYAN, 140 - a))
      end
    end
  else   -- ripples
    for k = 0, 2 do
      local r = ((f + k * 40) % 120) / 120
      local rx, ry = (k == 0) and 62 or ((k == 1) and 318 or 114), (k == 0) and 198 or ((k == 1) and 202 or 224)
      gfx.ring(rx, ry + 6, 18 + r * 22, 1.6, alpha(C.WHITE, floor(110 * (1 - r))))
    end
  end
end

function P.draw_gym_beams(foe_col)
  local sw = sin(game.frame * 0.04) * 28
  gfx.tri(24, 56, 150 + sw, 420, 230 + sw, 420, alpha(C.GOLD, 22))
  gfx.tri(W - 24, 56, W - 230 - sw, 420, W - 150 - sw, 420, alpha(foe_col or C.CYAN, 22))
end

-- ------------------------------------------------------------------ the friends
-- Normal and shiny coats. Each kind lists the colours its drawing uses, in order (see the branches).
local COAT = {
  elec  = {{C.PIKA, C.RED, C.GOLD, C.BROWN},        {0xc9a8ff, C.CYAN, C.ROSE, C.PURPLE}},
  leaf  = {{C.MINT, C.LEAF, C.GREEN, 0x2d8a78, C.LIME}, {0xffc0d8, 0xd8507e, 0xf88cb4, 0xc0407a, C.WHITE}},
  fire  = {{C.ORANGE, C.RED, C.GOLD, C.CREAM},      {0x4ec8bc, C.BLUE, 0xc0f4ff, C.WHITE}},
  psy   = {{0xf2c14e, C.GOLD, C.BROWN, C.SILVER},   {0xff9ab8, C.WHITE, C.PURPLE, C.GOLD}},
  water = {{C.BLUE, C.SHELL, C.CREAM, C.CYAN},      {0xb48cf0, C.GOLD, 0xfff0c0, C.ROSE}},
  bear  = {{C.NAVY, C.CREAM, C.BROWN},              {0x9c6cc4, 0xfff0d8, 0x6a3c8c}},
  ghost = {{C.PURPLE, C.RED, C.WHITE},              {0x34c8a0, C.GOLD, C.WHITE}},
  drag  = {{0xf2a43c, C.TEAL, C.CREAM, C.GOLD},     {0xff7ca8, C.PURPLE, 0xfff0f4, C.CYAN}},
}

-- Silhouette drawing: the same code with every colour replaced (and glows dropped).
local GS = {}
GS.circle = function(x, y, r) return gfx.circle(x, y, r, C.SIL) end
GS.ellipse = function(x, y, rx, ry) return gfx.ellipse(x, y, rx, ry, C.SIL) end
GS.tri = function(a, b, c, d, e, f) return gfx.tri(a, b, c, d, e, f, C.SIL) end
GS.rrect = function(x, y, w, h, r) return gfx.rrect(x, y, w, h, r, C.SIL) end
GS.star = function(x, y, r, rot) return gfx.star(x, y, r, rot, C.SIL) end
GS.line = function(a, b, c, d, t) return gfx.line(a, b, c, d, t, C.SIL) end
GS.ellipse_o = function(x, y, rx, ry) return gfx.ellipse(x, y, rx, ry, C.SIL) end
GS.circle_o = function(x, y, r) return gfx.circle(x, y, r, C.SIL) end
GS.glow = function() end
local TS = {}
TS.circle = function(x, y, r) return toon.circle(x, y, r, C.SIL) end
TS.ellipse = function(x, y, rx, ry) return toon.ellipse(x, y, rx, ry, C.SIL) end
TS.tri = function(a, b, c, d, e, f) return toon.tri(a, b, c, d, e, f, C.SIL) end
TS.rrect = function(x, y, w, h, r) return toon.rrect(x, y, w, h, r, C.SIL) end

-- o (optional): shiny, sil (silhouette), look (-1..1 toward whom it watches), hop (it bounces), sleep, heart.
function P.draw_mon(m, x, y, s, happy, atk_t, o)
  local f = game.frame
  local sil = o and o.sil
  local sh = (o and o.shiny) and 2 or 1
  local g, t = gfx, toon
  if sil then g, t = GS, TS end
  local bob = sin(f * 0.11 + m.id * 1.3) * 3 * s
  local lunge = (atk_t and atk_t > 0) and (-sin(atk_t / 14 * math.pi) * 14 * s) or 0
  local hop = (o and o.hop) and -abs(sin(f * 0.22 + m.id)) * 9 * s or 0
  y = y + bob + lunge + hop
  local look = (o and o.look) and clamp(o.look, -1, 1) * 1.5 * s or 0
  local sleep = o and o.sleep

  g.ellipse(x, y + 19 * s - bob * 0.5 - hop * 0.5, 17 * s, 5.5 * s, alpha(C.DARK, 85))

  local k = m.kind
  local c = COAT[k][sh]
  if k == "elec" then
    local wag = sin(f * 0.16 + m.id) * 3 * s
    g.line(x + 10 * s, y + 6 * s, x + 19 * s, y - 1 * s + wag, 4 * s, c[4])
    g.line(x + 17 * s, y - 1 * s + wag, x + 23 * s, y - 8 * s + wag, 5.5 * s, c[1])
    g.line(x + 20 * s, y - 8 * s + wag, x + 27 * s, y - 18 * s + wag, 6.5 * s, c[3])
    toon(function()
      t.tri(x - 8 * s, y - 10 * s, x - 17 * s, y - 32 * s, x - 1 * s, y - 15 * s, c[1])
      t.tri(x + 8 * s, y - 10 * s, x + 17 * s, y - 32 * s, x + 1 * s, y - 15 * s, c[1])
      t.ellipse(x, y + 6 * s, 14 * s, 12 * s, c[1])
      t.circle(x, y - 5 * s, 13 * s, c[1])
      t.circle(x - 8 * s, y + 15 * s, 4 * s, c[1])
      t.circle(x + 8 * s, y + 15 * s, 4 * s, c[1])
    end, 2 * s, C.INK)
    g.tri(x - 13 * s, y - 22 * s, x - 17 * s, y - 32 * s, x - 8 * s, y - 24 * s, C.INK)
    g.tri(x + 13 * s, y - 22 * s, x + 17 * s, y - 32 * s, x + 8 * s, y - 24 * s, C.INK)
    g.circle(x - 8.5 * s, y - 1 * s, 3.6 * s, c[2])
    g.circle(x + 8.5 * s, y - 1 * s, 3.6 * s, c[2])
    if not sil and (f + m.id * 9) % 45 < 10 then
      gfx.star(x - 13 * s, y - 2 * s, 4 * s, f * 0.2, c[3])
      gfx.star(x + 13 * s, y - 2 * s, 4 * s, -f * 0.2, c[3])
    end

  elseif k == "leaf" then
    toon(function()
      t.ellipse(x, y - 13 * s, 13 * s, 10 * s, c[2])
      t.tri(x - 8 * s, y - 17 * s, x, y - 27 * s, x + 8 * s, y - 17 * s, c[3])
      t.ellipse(x, y + 4 * s, 16 * s, 12 * s, c[1])
      t.circle(x - 11 * s, y + 13 * s, 4.5 * s, c[1])
      t.circle(x + 11 * s, y + 13 * s, 4.5 * s, c[1])
      t.tri(x - 12 * s, y - 4 * s, x - 15 * s, y - 13 * s, x - 6 * s, y - 8 * s, c[1])
      t.tri(x + 12 * s, y - 4 * s, x + 15 * s, y - 13 * s, x + 6 * s, y - 8 * s, c[1])
    end, 2 * s, C.INK)
    g.circle(x - 9 * s, y - 7 * s, 2.5 * s, c[4])
    g.circle(x + 9 * s, y - 5 * s, 2.8 * s, c[4])
    g.line(x, y - 24 * s, x, y - 10 * s, 1.5 * s, c[5])

  elseif k == "fire" then
    local fl = sin(f * 0.35 + m.id) * 2.5 * s
    toon(function()
      t.ellipse(x + 15 * s, y + 8 * s, 9 * s, 4.5 * s, c[1])
      t.ellipse(x, y + 6 * s, 12 * s, 13 * s, c[1])
      t.circle(x, y - 8 * s, 11.5 * s, c[1])
      t.circle(x - 7 * s, y + 16 * s, 4.2 * s, c[1])
      t.circle(x + 7 * s, y + 16 * s, 4.2 * s, c[1])
    end, 2 * s, C.INK)
    g.ellipse(x, y + 8 * s, 7.5 * s, 8.5 * s, c[4])
    g.glow(x + 22 * s, y + 1 * s, 18 * s, alpha(c[3], 160))
    g.tri(x + 17 * s, y + 5 * s, x + 22 * s + fl * 0.4, y - 11 * s - abs(fl), x + 27 * s, y + 5 * s, c[2])
    g.tri(x + 19 * s, y + 4 * s, x + 22 * s, y - 5 * s - abs(fl * 0.5), x + 25 * s, y + 4 * s, c[3])

  elseif k == "psy" then
    local sp_bob = sin(f * 0.14) * 3 * s
    for _, side in ipairs({-1, 1}) do
      local sx, sy = x + side * 21 * s, y - 2 * s + sp_bob * side
      g.glow(sx, sy, 12 * s, alpha(C.CYAN, 110))
      g.line(sx, sy + 9 * s, sx, sy - 4 * s, 2.4 * s, c[4])
      g.ellipse_o(sx, sy - 7 * s, 4 * s, 5.5 * s, c[4], C.INK, 1.3 * s)
    end
    toon(function()
      t.tri(x - 7 * s, y - 11 * s, x - 18 * s, y - 29 * s, x - 1 * s, y - 15 * s, c[1])
      t.tri(x + 7 * s, y - 11 * s, x + 18 * s, y - 29 * s, x + 1 * s, y - 15 * s, c[1])
      t.ellipse(x, y + 7 * s, 11 * s, 12 * s, c[1])
      t.rrect(x - 8 * s, y + 2 * s, 16 * s, 9 * s, 3 * s, c[3])
      t.tri(x - 12 * s, y - 9 * s, x + 12 * s, y - 9 * s, x, y + 4 * s, c[1])
      t.circle(x, y - 8 * s, 10.5 * s, c[1])
    end, 2 * s, C.INK)
    g.tri(x - 2 * s, y - 1 * s, x - 16 * s, y + 4 * s, x - 11 * s, y + 9 * s, c[2])
    g.tri(x + 2 * s, y - 1 * s, x + 16 * s, y + 4 * s, x + 11 * s, y + 9 * s, c[2])

  elseif k == "water" then
    toon(function()
      t.circle(x + 15 * s, y + 6 * s, 6.5 * s, c[1])
      t.ellipse(x + 4 * s, y + 6 * s, 14 * s, 13 * s, c[2])
      t.ellipse(x - 2 * s, y + 7 * s, 11 * s, 12 * s, c[1])
      t.circle(x - 2 * s, y - 7 * s, 11.5 * s, c[1])
      t.circle(x - 9 * s, y + 16 * s, 4 * s, c[1])
      t.circle(x + 5 * s, y + 16 * s, 4 * s, c[1])
    end, 2 * s, C.INK)
    g.ellipse(x - 2 * s, y + 8 * s, 7.5 * s, 9 * s, c[3])
    g.line(x - 8 * s, y + 8 * s, x + 4 * s, y + 8 * s, 1.3 * s, C.INK)
    g.circle(x + 15 * s, y + 6 * s, 2.5 * s, c[4])

  elseif k == "bear" then
    toon(function()
      t.tri(x - 11 * s, y - 12 * s, x - 15 * s, y - 23 * s, x - 4 * s, y - 15 * s, c[1])
      t.tri(x + 11 * s, y - 12 * s, x + 15 * s, y - 23 * s, x + 4 * s, y - 15 * s, c[1])
      t.ellipse(x, y + 5 * s, 18 * s, 16 * s, c[1])
      t.circle(x, y - 8 * s, 13 * s, c[1])
      t.ellipse(x - 11 * s, y + 16 * s, 6.5 * s, 4.5 * s, c[2])
      t.ellipse(x + 11 * s, y + 16 * s, 6.5 * s, 4.5 * s, c[2])
    end, 2 * s, C.INK)
    g.ellipse(x, y + 7 * s, 13 * s, 11 * s, c[2])
    g.ellipse(x, y - 6 * s, 9.5 * s, 8 * s, c[2])
    g.circle(x - 11 * s, y + 16 * s, 2.2 * s, c[3])
    g.circle(x + 11 * s, y + 16 * s, 2.2 * s, c[3])

  elseif k == "ghost" then
    toon(function()
      t.tri(x - 12 * s, y - 6 * s, x - 19 * s, y - 24 * s, x - 3 * s, y - 14 * s, c[1])
      t.tri(x + 12 * s, y - 6 * s, x + 19 * s, y - 24 * s, x + 3 * s, y - 14 * s, c[1])
      t.tri(x - 5 * s, y - 13 * s, x, y - 22 * s, x + 5 * s, y - 13 * s, c[1])
      t.circle(x, y, 16 * s, c[1])
      t.circle(x - 10 * s, y + 13 * s, 5 * s, c[1])
      t.circle(x + 10 * s, y + 13 * s, 5 * s, c[1])
    end, 2 * s, C.INK)
    if not sil then
      gfx.rrect_o(x - 10 * s, y + 2 * s, 20 * s, 7.5 * s, 4 * s, C.WHITE, C.INK, 1.4 * s)
      for gx = -6, 6, 4 do
        gfx.line(x + gx * s, y + 2 * s, x + gx * s, y + 9.5 * s, 1.2 * s, C.INK)
      end
      if happy or sleep then
        gfx.line(x - 9 * s, y - 5 * s, x - 5 * s, y - 9 * s, 2.2 * s, C.WHITE)
        gfx.line(x - 5 * s, y - 9 * s, x - 1 * s, y - 5 * s, 2.2 * s, C.WHITE)
        gfx.line(x + 1 * s, y - 5 * s, x + 5 * s, y - 9 * s, 2.2 * s, C.WHITE)
        gfx.line(x + 5 * s, y - 9 * s, x + 9 * s, y - 5 * s, 2.2 * s, C.WHITE)
      else
        gfx.tri(x - 10 * s, y - 9 * s, x - 2 * s, y - 5 * s, x - 8 * s, y - 3 * s, c[2])
        gfx.tri(x + 10 * s, y - 9 * s, x + 2 * s, y - 5 * s, x + 8 * s, y - 3 * s, c[2])
        gfx.circle(x - 5 * s + look, y - 6 * s, 1.4 * s, C.WHITE)
        gfx.circle(x + 5 * s + look, y - 6 * s, 1.4 * s, C.WHITE)
      end
    end
    if o and o.shiny and not sil then
      for q = 0, 2 do
        local a = f * 0.07 + q * 2.1
        gfx.star(x + cos(a) * 24 * s, y - 4 * s + sin(a) * 14 * s, 4 * s, a, C.GOLD)
      end
    end
    return

  elseif k == "drag" then
    local flap = sin(f * 0.22 + m.id) * 5 * s
    toon(function()
      t.tri(x - 10 * s, y + 2 * s, x - 29 * s, y - 14 * s + flap, x - 16 * s, y + 10 * s, c[2])
      t.tri(x + 10 * s, y + 2 * s, x + 29 * s, y - 14 * s + flap, x + 16 * s, y + 10 * s, c[2])
      t.ellipse(x, y + 6 * s, 13 * s, 13 * s, c[1])
      t.circle(x, y - 8 * s, 11 * s, c[1])
      t.circle(x - 7 * s, y + 16 * s, 4.5 * s, c[1])
      t.circle(x + 7 * s, y + 16 * s, 4.5 * s, c[1])
    end, 2 * s, C.INK)
    g.ellipse(x, y + 7 * s, 8 * s, 9.5 * s, c[3])
    for ry = 3, 12, 4 do
      g.line(x - 6 * s, y + ry * s, x + 6 * s, y + ry * s, 1.2 * s, alpha(C.BROWN, 140))
    end
    g.line(x - 4 * s, y - 17 * s, x - 10 * s, y - 26 * s, 2 * s, c[4])
    g.line(x + 4 * s, y - 17 * s, x + 10 * s, y - 26 * s, 2 * s, c[4])
  end

  if not sil then
    local ey = (k == "leaf") and (y - 1 * s) or (y - 7 * s)
    if happy or sleep then
      if sleep then   -- a sleeper: flat lids and a "z"
        gfx.line(x - 8 * s, ey, x - 2 * s, ey, 2 * s, C.INK)
        gfx.line(x + 2 * s, ey, x + 8 * s, ey, 2 * s, C.INK)
        local zz = idiv(f, 30) % 3
        gfx.text("z", x + 14 * s + zz * 3, y - 26 * s - zz * 5, 11 + zz * 2, C.WHITE, "center", C.INK)
      else
        gfx.line(x - 8 * s, ey, x - 5 * s, ey - 4 * s, 2 * s, C.INK)
        gfx.line(x - 5 * s, ey - 4 * s, x - 2 * s, ey, 2 * s, C.INK)
        gfx.line(x + 2 * s, ey, x + 5 * s, ey - 4 * s, 2 * s, C.INK)
        gfx.line(x + 5 * s, ey - 4 * s, x + 8 * s, ey, 2 * s, C.INK)
      end
    else
      gfx.circle(x - 5 * s, ey, 2.8 * s, C.INK)
      gfx.circle(x + 5 * s, ey, 2.8 * s, C.INK)
      gfx.circle(x - 6 * s + look, ey - 1 * s, 1.1 * s, C.WHITE)
      gfx.circle(x + 4 * s + look, ey - 1 * s, 1.1 * s, C.WHITE)
    end
    if happy then   -- an open smile
      gfx.ellipse(x, ey + 6 * s, 2.6 * s, 2.2 * s, C.INK)
    else
      gfx.line(x - 3 * s, ey + 5 * s, x, ey + 6.5 * s, 1.6 * s, C.INK)
      gfx.line(x, ey + 6.5 * s, x + 3 * s, ey + 5 * s, 1.6 * s, C.INK)
    end
    if o and o.shiny then   -- three little stars circling a shiny friend
      for q = 0, 2 do
        local a = f * 0.07 + q * 2.1
        gfx.star(x + cos(a) * 24 * s, y - 4 * s + sin(a) * 14 * s, 4 * s, a, C.GOLD)
      end
    end
    if o and o.heart then
      local hy = y - 34 * s - abs(sin(f * 0.06 + m.id)) * 4
      gfx.heart(x, hy, 7 * s, C.ROSE)
    end
  end
end

-- ------------------------------------------------------------------ Hoot, the owl ranger
function P.draw_hoot(x, y, s, lookx, mood, flap)
  local f = game.frame
  local fl = (mood == "cheer" or flap) and sin(f * 0.4) * 7 * s or sin(f * 0.05) * 1.2 * s
  gfx.ellipse(x, y + 17 * s, 14 * s, 4 * s, alpha(C.DARK, 80))
  toon(function()
    toon.tri(x - 14 * s, y - 2 * s, x - 22 * s, y + 8 * s - fl, x - 9 * s, y + 12 * s, C.OWL)    -- wings
    toon.tri(x + 14 * s, y - 2 * s, x + 22 * s, y + 8 * s - fl, x + 9 * s, y + 12 * s, C.OWL)
    toon.ellipse(x, y + 6 * s, 14 * s, 15 * s, C.OWL)
    toon.tri(x - 10 * s, y - 12 * s, x - 14 * s, y - 24 * s, x - 3 * s, y - 15 * s, C.OWL)    -- ear tufts
    toon.tri(x + 10 * s, y - 12 * s, x + 14 * s, y - 24 * s, x + 3 * s, y - 15 * s, C.OWL)
    toon.circle(x, y - 6 * s, 13 * s, C.OWL)
    toon.tri(x - 4 * s, y + 20 * s, x - 7 * s, y + 24 * s, x - 1 * s, y + 21 * s, C.ORANGE)  -- feet
    toon.tri(x + 4 * s, y + 20 * s, x + 7 * s, y + 24 * s, x + 1 * s, y + 21 * s, C.ORANGE)
  end, 2 * s, C.INK)
  gfx.ellipse(x, y + 9 * s, 9 * s, 10 * s, C.OWL2)
  for q = 0, 2 do gfx.line(x - 5 * s, y + (4 + q * 4) * s, x + 5 * s, y + (4 + q * 4) * s, 1 * s, alpha(C.OWL, 140)) end
  gfx.star(x, y + 6 * s, 4 * s, 0, C.GOLD)   -- the ranger's star
  -- face: two big round eyes that follow you
  local lx = clamp(lookx or 0, -1, 1) * 1.8 * s
  local blink = f % 190 < 6
  for side = -1, 1, 2 do
    local ex = x + side * 6 * s
    gfx.circle_o(ex, y - 7 * s, 5.6 * s, C.WHITE, C.INK, 1.4 * s)
    if mood == "cheer" then
      gfx.line(ex - 3 * s, y - 6 * s, ex, y - 10 * s, 1.8 * s, C.INK)
      gfx.line(ex, y - 10 * s, ex + 3 * s, y - 6 * s, 1.8 * s, C.INK)
    elseif blink then
      gfx.line(ex - 3.5 * s, y - 7 * s, ex + 3.5 * s, y - 7 * s, 1.8 * s, C.INK)
    else
      gfx.circle(ex + lx, y - 7 * s, 2.6 * s, C.INK)
      gfx.circle(ex + lx - 0.8 * s, y - 8 * s, 0.9 * s, C.WHITE)
    end
  end
  gfx.tri(x - 2.5 * s, y - 3 * s, x + 2.5 * s, y - 3 * s, x, y + 2 * s, C.ORANGE)
  -- the ranger hat: a green brim, a dome, and a red feather
  toon(function()
    toon.ellipse(x, y - 15 * s, 16 * s, 4.5 * s, C.LEAF)
    toon.rrect(x - 9 * s, y - 25 * s, 18 * s, 11 * s, 5 * s, C.GREEN)
  end, 1.8 * s, C.INK)
  gfx.rect(x - 9 * s, y - 17 * s, 18 * s, 2.6 * s, C.GOLD)
  gfx.tri(x + 7 * s, y - 24 * s, x + 17 * s, y - 33 * s, x + 11 * s, y - 20 * s, C.RED)
end

-- ------------------------------------------------------------------ the gym leaders
local LEAD = {
  {body = 0x58c464, hat = 0x389c48, skin = 0xf6c9a2, name = "Captain Clover"},
  {body = 0xe8963c, hat = 0x7e4ce8, skin = 0xd9a47a, name = "Miss Glint"},
  {body = 0x4ca8f5, hat = 0xfff6ea, skin = 0xf0bc94, name = "Skipper Ripple"},
}
function P.leader_name(gi) return LEAD[gi].name end

-- mood: nil (grin), "ouch", "worry", "cheer", "bow"
function P.draw_leader(gi, x, y, s, mood)
  local L = LEAD[gi]
  local f = game.frame
  local bounce = (mood == "cheer") and -abs(sin(f * 0.25)) * 6 * s or 0
  local lean = (mood == "bow") and 5 * s or 0
  y = y + bounce
  gfx.ellipse(x, y + 24 * s, 15 * s, 4.5 * s, alpha(C.DARK, 85))
  toon(function()
    toon.circle(x - 5 * s, y + 21 * s, 4.4 * s, C.BROWN)
    toon.circle(x + 5 * s, y + 21 * s, 4.4 * s, C.BROWN)
    if mood == "cheer" then
      toon.line(x - 11 * s, y + 4 * s, x - 17 * s, y - 8 * s, 4 * s, L.skin)
      toon.line(x + 11 * s, y + 4 * s, x + 17 * s, y - 8 * s, 4 * s, L.skin)
    else
      toon.line(x - 11 * s, y + 4 * s, x - 15 * s, y + 14 * s, 4 * s, L.skin)
      toon.line(x + 11 * s, y + 4 * s, x + 15 * s, y + 14 * s, 4 * s, L.skin)
    end
    toon.rrect(x - 11 * s, y - 2 * s + lean, 22 * s, 24 * s, 7 * s, L.body)
    toon.circle(x, y - 12 * s + lean, 12 * s, L.skin)
  end, 2 * s, C.INK)
  local hy = y - 12 * s + lean
  if gi == 1 then   -- overalls and a sun hat with a clover
    gfx.rrect(x - 8 * s, y + 6 * s, 16 * s, 14 * s, 3 * s, 0x7a4824)
    gfx.ellipse_o(x, hy - 8 * s, 17 * s, 5 * s, 0xf2d27a, C.INK, 1.6 * s)
    gfx.rrect_o(x - 9 * s, hy - 17 * s, 18 * s, 10 * s, 5 * s, 0xf2d27a, C.INK, 1.6 * s)
    for q = 0, 3 do
      gfx.circle(x + cos(q * 1.57) * 3 * s, hy - 12 * s + sin(q * 1.57) * 3 * s, 2.4 * s, C.GREEN)
    end
  elseif gi == 2 then   -- a mining helmet with a lamp, and a gem pendant
    gfx.rrect_o(x - 12 * s, hy - 16 * s, 24 * s, 12 * s, 6 * s, L.hat, C.INK, 1.6 * s)
    gfx.circle_o(x, hy - 12 * s, 4 * s, C.GOLD, C.INK, 1.3 * s)
    gfx.glow(x, hy - 12 * s, 14 * s, alpha(C.GOLD, 110 + floor(sin(f * 0.15) * 30)))
    gfx.tri(x - 3 * s, y + 4 * s, x + 3 * s, y + 4 * s, x, y + 11 * s, C.CYAN)
  else   -- a sailor cap and a striped shirt
    for q = 0, 3 do gfx.rect(x - 11 * s, y + (1 + q * 5) * s, 22 * s, 2.4 * s, C.WHITE) end
    gfx.rrect_o(x - 12 * s, hy - 17 * s, 24 * s, 11 * s, 5 * s, L.hat, C.INK, 1.6 * s)
    gfx.rect(x - 12 * s, hy - 9 * s, 24 * s, 3 * s, C.BLUE)
    gfx.circle(x, hy - 13 * s, 2.2 * s, C.RED)
  end
  -- face
  local ex = 4.2 * s
  if mood == "ouch" then
    for side = -1, 1, 2 do
      gfx.line(x + side * ex - 2 * s, hy - 3 * s, x + side * ex + 2 * s, hy, 1.6 * s, C.INK)
      gfx.line(x + side * ex + 2 * s, hy - 3 * s, x + side * ex - 2 * s, hy, 1.6 * s, C.INK)
    end
    gfx.ellipse(x, hy + 6 * s, 2.6 * s, 3 * s, C.INK)
    gfx.ellipse(x + 11 * s, hy - 6 * s, 1.8 * s, 3 * s, C.CYAN)   -- a sweat drop
  elseif mood == "cheer" then
    for side = -1, 1, 2 do
      gfx.line(x + side * ex - 2.4 * s, hy, x + side * ex, hy - 3 * s, 1.8 * s, C.INK)
      gfx.line(x + side * ex, hy - 3 * s, x + side * ex + 2.4 * s, hy, 1.8 * s, C.INK)
    end
    gfx.ellipse(x, hy + 5 * s, 3.4 * s, 2.6 * s, C.INK)
  else
    for side = -1, 1, 2 do
      gfx.circle(x + side * ex, hy, 2.1 * s, C.INK)
      gfx.circle(x + side * ex - 0.7 * s, hy - 0.8 * s, 0.8 * s, C.WHITE)
      if mood == "worry" then gfx.line(x + side * ex - 3 * s, hy - 4 * s + side * 1.2 * s, x + side * ex + 3 * s, hy - 5 * s - side * 1.2 * s, 1.3 * s, C.INK) end
    end
    if mood == "worry" then
      gfx.line(x - 3 * s, hy + 6 * s, x, hy + 5 * s, 1.4 * s, C.INK)
      gfx.line(x, hy + 5 * s, x + 3 * s, hy + 6 * s, 1.4 * s, C.INK)
    else
      gfx.line(x - 3.5 * s, hy + 4.5 * s, x, hy + 7 * s, 1.6 * s, C.INK)
      gfx.line(x, hy + 7 * s, x + 3.5 * s, hy + 4.5 * s, 1.6 * s, C.INK)
    end
  end
  gfx.circle(x - 8 * s, hy + 4 * s, 2.4 * s, alpha(C.ROSE, 130))
  gfx.circle(x + 8 * s, hy + 4 * s, 2.4 * s, alpha(C.ROSE, 130))
end

-- ------------------------------------------------------------------ the trainer (a Junior Ranger)
local CAPS = {0xe63e4c, 0x4ca8f5, 0x58c464, 0xffd84a}
function P.cap_col(rank) return CAPS[clamp(rank + 1, 1, 4)] end

function P.draw_trainer(x, y, fx, fy, walk_t, moving, cap, cheer)
  cap = cap or C.CAP
  local step = moving and sin(walk_t * 0.35) * 3.5 or 0
  local hop = cheer and -abs(sin(game.frame * 0.3)) * 5 or 0
  y = y + hop
  gfx.ellipse(x, y + 18 - hop, 12, 4.5, alpha(C.DARK, 85))
  toon(function()
    toon.circle(x - 5, y + 15 + step, 4.2, C.RED)
    toon.circle(x + 5, y + 15 - step, 4.2, C.RED)
    toon.rrect(x - 12, y - 1, 24, 14, 5, C.GREEN)
    toon.rrect(x - 9, y, 18, 15, 5, C.BLUE)
    toon.circle(x, y - 8, 11, C.SKIN)
    toon.ellipse(x, y - 15, 13, 7, cap)
    toon.rrect(x + (fx >= 0 and -2 or -14), y - 15, 16, 4.5, 2, cap)
  end, 2.2, C.INK)
  gfx.rrect(x - 5, y - 19, 10, 5, 2.5, C.WHITE)
  gfx.tri(x - 4, y, x + 4, y, x, y + 5, C.WHITE)
  local ex = clamp(fx * 2, -2, 2)
  if cheer then
    gfx.line(x - 6 + ex, y - 7, x - 3.5 + ex, y - 10, 1.8, C.INK)
    gfx.line(x - 3.5 + ex, y - 10, x - 1 + ex, y - 7, 1.8, C.INK)
    gfx.line(x + 1 + ex, y - 7, x + 3.5 + ex, y - 10, 1.8, C.INK)
    gfx.line(x + 3.5 + ex, y - 10, x + 6 + ex, y - 7, 1.8, C.INK)
  else
    gfx.circle(x - 3.5 + ex, y - 8, 1.9, C.INK)
    gfx.circle(x + 3.5 + ex, y - 8, 1.9, C.INK)
    gfx.circle(x - 4 + ex, y - 9, 0.8, C.WHITE)
    gfx.circle(x + 3 + ex, y - 9, 0.8, C.WHITE)
  end
  if cap == CAPS[4] then gfx.star(x, y - 22, 4, game.frame * 0.04, C.WHITE) end
end

-- ------------------------------------------------------------------ orb and berry
function P.draw_orb(x, y, r, super_orb, wob)
  wob = wob or 0
  if super_orb then gfx.glow(x + wob, y, r * 2.4, alpha(C.GOLD, 160)) end
  gfx.circle_o(x + wob, y, r, C.WHITE, C.INK, 2)
  gfx.rrect(x - r + 1 + wob, y - r + 1, (r - 1) * 2, r, r * 0.75, super_orb and C.GOLD or C.RED)
  gfx.rect(x - r + 1 + wob, y - 1, (r - 1) * 2, 2.6, C.INK)
  gfx.circle_o(x + wob, y, r * 0.3, C.WHITE, C.INK, 1.4)
  gfx.circle(x - r * 0.35 + wob, y - r * 0.45, r * 0.16, alpha(C.WHITE, 210))
end

function P.draw_berry(x, y)
  gfx.glow(x, y, 18, alpha(C.GOLD, 140))
  gfx.circle_o(x, y, 8, C.GOLD, C.INK, 1.8)
  gfx.tri(x - 4, y - 7, x, y - 13, x + 4, y - 7, C.GREEN)
  gfx.circle(x - 2.5, y - 2.5, 2, C.WHITE)
end

-- ------------------------------------------------------------------ badges and stamps
local BADGE_COLS = {0x58c464, 0xb26cf0, 0x4ca8f5}
local BADGE_NAMES = {"CLOVER", "GLINT", "RIPPLE"}
function P.badge_name(gi) return BADGE_NAMES[gi] end
function P.badge_col(gi) return BADGE_COLS[gi] end

-- have: earned; stars 0..3 shine below it.
function P.draw_badge(x, y, gi, sc, have, stars)
  local col = have and BADGE_COLS[gi] or 0xb8aec4
  if have then gfx.glow(x, y, 30 * sc, alpha(col, 120)) end
  gfx.circle_o(x, y, 15 * sc, have and C.CREAM or 0xd8d0e0, C.INK, 2 * sc)
  if gi == 1 then
    for q = 0, 3 do gfx.circle(x + cos(q * 1.571 + 0.785) * 5.5 * sc, y + sin(q * 1.571 + 0.785) * 5.5 * sc, 5.2 * sc, col) end
    gfx.circle(x, y, 2.4 * sc, have and C.GOLD or 0xc8c0d0)
  elseif gi == 2 then
    gfx.poly({x, y - 11 * sc, x + 9 * sc, y - 2 * sc, x, y + 11 * sc, x - 9 * sc, y - 2 * sc}, col)
    gfx.poly({x - 5 * sc, y - 3 * sc, x, y - 11 * sc, x + 5 * sc, y - 3 * sc}, have and C.WHITE or 0xc8c0d0)
  else
    gfx.circle(x, y, 8 * sc, col)
    gfx.ring(x, y, 11.5 * sc, 1.6 * sc, col)
    gfx.circle(x - 2.5 * sc, y - 2.5 * sc, 2.2 * sc, have and C.WHITE or 0xc8c0d0)
  end
  if stars and stars > 0 then
    for q = 1, 3 do
      gfx.star(x + (q - 2) * 10 * sc, y + 22 * sc, 4.6 * sc, 0, q <= stars and C.GOLD or 0xc8c0d0)
    end
  end
end

-- a habitat stamp: have it (all its friends found) or an empty ring
function P.draw_stamp(x, y, z, sc, have)
  local Z = ZONES[z]
  gfx.circle_o(x, y, 15 * sc, have and Z.top or 0xd8d0e0, have and C.INK or 0x9a90a8, 2 * sc)
  if not have then return end
  gfx.ring(x, y, 11 * sc, 1.2 * sc, alpha(C.WHITE, 200))
  if z == 1 then
    gfx.circle(x, y - 2 * sc, 3.2 * sc, C.GOLD)
    for q = 0, 4 do gfx.circle(x + cos(q * 1.257) * 6 * sc, y - 2 * sc + sin(q * 1.257) * 6 * sc, 2.8 * sc, C.WHITE) end
    gfx.line(x, y + 2 * sc, x, y + 9 * sc, 1.6 * sc, C.LEAF)
  elseif z == 2 then
    gfx.tri(x - 6 * sc, y + 8 * sc, x - 2 * sc, y - 9 * sc, x + 2 * sc, y + 8 * sc, C.CYAN)
    gfx.tri(x, y + 8 * sc, x + 4 * sc, y - 4 * sc, x + 8 * sc, y + 8 * sc, C.ROSE)
  else
    gfx.circle(x, y + 3 * sc, 6 * sc, C.WHITE)
    gfx.tri(x - 5 * sc, y + 1 * sc, x, y - 10 * sc, x + 5 * sc, y + 1 * sc, C.WHITE)
  end
end

-- ------------------------------------------------------------------ the goal, in pictures
-- w: the height available. Draws Hoot's current goal as a few small pictures ending near x + 120.
function P.draw_goal(x, y)
  local S = P.S
  local k = S.g_kind
  local f = game.frame
  if k == "orb" then
    P.draw_orb(x + 14, y, 9, false, 0)
    gfx.text(">", x + 38, y - 9, 18, C.INK, "center")
    P.draw_mon(S.g_mon or S.MONS[1], x + 78, y + 2, 0.62, false, 0, {sil = true})
    gfx.text("?", x + 78, y - 14, 18, C.PURPLE, "center", C.CREAM)
  elseif k == "mons" then
    P.draw_stamp(x + 14, y, S.g_zone, 0.8, true)
    P.draw_mon(S.g_mon, x + 58, y + 2, 0.62, false, 0, {sil = true})
    gfx.text("?", x + 58, y - 14, 18, C.PURPLE, "center", C.CREAM)
    gfx.text(S.g_have .. "/" .. S.g_need, x + 100, y - 9, 16, C.INK, "center")
  elseif k == "gym" then
    P.draw_badge(x + 16, y - 2, S.g_zone, 0.8, false, 0)
    gfx.text("!", x + 16, y - 12, 18, C.RED, "center", C.CREAM)
    P.draw_leader(S.g_zone, x + 62, y + 2, 0.5, nil)
  elseif k == "shiny" or k == "shiny_mon" then
    local m = S.g_mon
    if m then P.draw_mon(m, x + 22, y + 2, 0.62, false, 0, {sil = true}) end
    for q = 0, 2 do
      local a = f * 0.07 + q * 2.1
      gfx.star(x + 22 + cos(a) * 20, y - 2 + sin(a) * 12, 4, a, C.GOLD)
    end
    gfx.star(x + 70, y, 11, f * 0.03, C.GOLD)
    gfx.text("?", x + 70, y - 9, 16, C.INK, "center")
  elseif k == "stars" then
    P.draw_badge(x + 16, y - 4, S.g_zone, 0.7, true, S.stars[S.g_zone])
    gfx.text(">", x + 52, y - 9, 18, C.INK, "center")
    gfx.star(x + 78, y - 2, 11, f * 0.03, C.GOLD)
  else   -- done
    gfx.glow(x + 40, y, 26, alpha(C.GOLD, 120))
    gfx.poly({x + 22, y + 8, x + 24, y - 8, x + 32, y, x + 40, y - 12, x + 48, y, x + 56, y - 8, x + 58, y + 8}, C.GOLD)
    gfx.rect(x + 22, y + 6, 36, 4, C.ORANGE)
  end
  -- an arrow toward the habitat that has it
  if S.g_dir and S.g_dir ~= 0 then
    local bob = sin(f * 0.15) * 3
    gfx.text(S.g_dir < 0 and "<" or ">", S.g_dir < 0 and (x - 12 - bob) or (x + 118 + bob), y - 10, 18, C.RED, "center")
  end
end

-- ------------------------------------------------------------------ the HUD: dots, badges, Hoot's goal
function P.draw_hud()
  local S = P.S
  gfx.rrect_o(8, 6, W - 16, 52, 12, C.CREAM, C.INK, 2)
  -- Hoot and the goal
  P.draw_hoot(30, 30, 0.62, S.hud_look or 0, S.hud_mood, false)
  P.draw_goal(62, 33)
  gfx.line(194, 14, 194, 50, 1.4, alpha(C.INK, 60))
  -- the eight friend dots (their own colours, a ring for the active buddy, a star when shiny)
  for i = 1, 8 do
    local cx = 207 + ((i - 1) % 4) * 22
    local cy = 22 + idiv(i - 1, 4) * 22
    local m = S.MONS[i]
    local active = S.buddy and S.buddy.id == i
    if active then gfx.circle(cx, cy, 10, alpha(C.GOLD, 190)) end
    gfx.circle_o(cx, cy, 7.5, S.dex[i] and m.col or 0xc8c0d0, C.INK, active and 2.2 or 1.4)
    if S.shiny[i] then gfx.star(cx + 6, cy - 6, 4, 0, C.GOLD) end
  end
  for g = 1, 3 do
    P.draw_badge(305 + (g - 1) * 22, 26, g, 0.5, S.gym_done[g], 0)
  end
  gfx.text(tostring(S.caught) .. "/8", 336, 40, 11, C.PURPLE, "center")
end

-- ------------------------------------------------------------------ the Field Book
local VOICE_TEXT = {"Sings sparkly zaps", "Hums a woody tune", "Plays the slow drum", "Plays stabs of fire",
                    "Rings tiny bells", "Giggles on the beat", "Blows bubble notes", "Sings the high sky"}
-- (ids in MONS order: Sparky Sprout Ember Mystic Splash Snooze Giggle Skywing)
local VOICE_BY_ID = {[1] = 1, [2] = 2, [3] = 4, [4] = 5, [5] = 7, [6] = 3, [7] = 6, [8] = 8}

local function card(x, y, w, h)
  gfx.rrect_o(x, y, w, h, 16, C.PAPER, C.INK, 3)
  gfx.rrect(x + 6, y + 6, w - 12, h - 12, 12, C.PAPER2)
  gfx.rrect(x + 10, y + 10, w - 20, h - 20, 9, C.PAPER)
end

local function sticker(m, x, y, s, know, shiny, name_y)
  -- know: 2 caught, 1 seen only, 0 never met
  local ring = (know == 2) and ZONES[m.zone].top or 0xd8d0e0
  gfx.circle_o(x, y, 34 * s, alpha(C.WHITE, 230), C.INK, 1.6)
  if know == 2 then
    gfx.circle(x, y, 31 * s, alpha(ring, 120))
    P.draw_mon(m, x, y + 2, 0.85 * s, false, 0, {shiny = shiny})
  elseif know == 1 then
    P.draw_mon(m, x, y + 2, 0.85 * s, false, 0, {sil = true})
  else
    gfx.text("?", x, y - 14 * s, floor(34 * s), 0x9a90a8, "center")
  end
  if name_y then
    gfx.text(know == 2 and m.name or (know == 1 and "???" or "?"), x, y + name_y, 11, C.INK, "center")
  end
  if shiny and know == 2 then gfx.star(x + 28 * s, y - 26 * s, 7 * s, game.frame * 0.03, C.GOLD) end
end

-- The overview page: the sticker grid, habitats with stamps and badges, and Hoot's goal.
function P.draw_book_cover()
  local S = P.S
  card(10, 10, W - 20, 462)
  P.draw_hoot(46, 44, 0.8, 0, nil, false)
  gfx.text("MY FIELD BOOK", W / 2 + 20, 26, 22, C.BROWN, "center")
  gfx.text(S.caught .. "/8 friends   " .. S.nshiny .. " sparkly", W / 2 + 20, 52, 13, C.PURPLE, "center")
  for i = 1, 8 do
    local cx, cy = 62 + ((i - 1) % 4) * 87, 118 + idiv(i - 1, 4) * 100
    local know = S.dex[i] and 2 or (S.seen[i] and 1 or 0)
    sticker(S.MONS[i], cx, cy, 0.95, know, S.shiny[i], 40)
  end
  -- three habitats: stamp, friends found, gym badge and its stars
  for z = 1, 3 do
    local cx = 66 + (z - 1) * 126
    gfx.rrect_o(cx - 56, 322, 112, 82, 12, C.CREAM, C.INK, 1.6)
    P.draw_stamp(cx - 30, 348, z, 0.9, S.zone_done[z])
    gfx.text(S.zone_have[z] .. "/" .. S.zone_need[z], cx - 30, 366, 12, C.INK, "center")
    P.draw_badge(cx + 22, 346, z, 0.9, S.gym_done[z], S.stars[z])
    gfx.text(ZONES[z].name, cx, 384, 11, C.BROWN, "center")
  end
  -- Hoot's next goal
  gfx.rrect_o(26, 412, W - 52, 48, 12, C.CREAM, C.INK, 1.6)
  P.draw_goal(48, 438)
  gfx.text(S.g_text, 190, 424, 12, C.INK, "left")
end

-- One friend's page. mode "book" or "new" (a fresh sticker: the banner is the band's job, the sparkles are ours).
function P.draw_friend_page(id, mode)
  local S = P.S
  local m = S.MONS[id]
  local know = S.dex[id] and 2 or (S.seen[id] and 1 or 0)
  card(10, 10, W - 20, 462)
  gfx.rrect_o(28, 44, W - 56, 214, 14, C.WHITE, C.INK, 2)
  gfx.rect(W / 2 - 1, 52, 2, 198, alpha(C.INK, 40))
  gfx.text(know == 2 and m.name or "???", W / 2, 16, 26, C.BROWN, "center")
  if know == 2 then
    gfx.circle(W / 4 + 14, 156, 60, alpha(ZONES[m.zone].top, 110))
    P.draw_mon(m, W / 4 + 14, 160, 2.1, mode == "new", 0, nil)
    gfx.text("FRIEND", W / 4 + 14, 60, 11, C.INK, "center")
    if S.shiny[id] then
      gfx.circle(W * 3 / 4 - 14, 156, 60, alpha(C.GOLD, 90))
      P.draw_mon(m, W * 3 / 4 - 14, 160, 2.1, mode == "new", 0, {shiny = true})
    else
      P.draw_mon(m, W * 3 / 4 - 14, 160, 2.1, false, 0, {sil = true})
      gfx.star(W * 3 / 4 - 14, 100, 14, game.frame * 0.03, alpha(C.GOLD, 200))
      gfx.text("?", W * 3 / 4 - 14, 126, 40, C.GOLD, "center", C.INK)
    end
    gfx.text("SPARKLY", W * 3 / 4 - 14, 60, 11, 0xb07a10, "center")
    P.draw_stamp(56, 290, m.zone, 0.9, true)
    gfx.text("Lives in " .. ZONES[m.zone].name, 80, 276, 15, C.INK, "left")
    gfx.text("Move: " .. m.move, 44, 312, 15, C.PURPLE, "left")
    gfx.text(VOICE_TEXT[VOICE_BY_ID[id]], 44, 340, 14, C.BROWN, "left")
    gfx.text(m.bio, 44, 372, 13, C.INK, "left")
    gfx.text(S.shiny[id] and "A sparkly one found!" or "A sparkly one may visit...", 44, 400, 13, 0xb07a10, "left")
  else
    P.draw_mon(m, W / 2, 168, 2.4, false, 0, {sil = true})
    gfx.text("?", W / 2, 90, 44, C.PURPLE, "center", C.CREAM)
    gfx.text(know == 1 and "Seen it! Not a friend yet." or "Not met yet.", W / 2, 284, 16, C.INK, "center")
    P.draw_stamp(70, 330, m.zone, 0.9, true)
    gfx.text("Look in " .. ZONES[m.zone].name, 96, 322, 15, C.BROWN, "left")
    gfx.text("Walk close and toss an orb!", 44, 360, 14, C.INK, "left")
  end
  gfx.text(id .. "/8", W / 2, 442, 13, C.BROWN, "center")
  if mode == "book" then
    local bob = sin(game.frame * 0.15) * 3
    gfx.text("<", 22 - bob, 238, 24, C.RED, "center")
    gfx.text(">", W - 22 + bob, 238, 24, C.RED, "center")
  end
end

-- ------------------------------------------------------------------ the story
local STORY_LINES = {
  {0, "A star fell on the land..."},
  {120, "Three Star Orbs! The monsters woke up!"},
  {250, "Hoot the ranger needs a helper!"},
  {320, "Be friends with them all! Fill the book!"},
}
function P.story_line(t)
  local line = STORY_LINES[1][2]
  for i = 1, #STORY_LINES do if t >= STORY_LINES[i][1] then line = STORY_LINES[i][2] end end
  return line
end

function P.draw_story(t)
  local S = P.S
  P.scene("story")
  local f = game.frame
  -- the shooting star
  if t > 8 and t < 46 then
    local k = (t - 8) / 38
    local sx, sy = lerp(20, 210, k), lerp(30, 150, k)
    gfx.line(sx - 40 * k, sy - 22 * k, sx, sy, 3, alpha(C.WHITE, 160))
    gfx.glow(sx, sy, 14, alpha(C.GOLD, 200))
    gfx.star(sx, sy, 7, f * 0.2, C.GOLD)
  end
  -- three Star Orbs fall, one on each land
  for i = 1, 3 do
    local t0 = 40 + i * 26
    local k = clamp((t - t0) / 48, 0, 1)
    local ox = 64 + (i - 1) * 128
    if k > 0 and k < 1 then
      local oy = lerp(-10, 392, k * k)
      gfx.line(ox, oy - 40, ox, oy, 4, alpha(C.GOLD, 120))
      gfx.glow(ox, oy, 20, alpha(C.GOLD, 190))
      gfx.star(ox, oy, 11, f * 0.25, C.GOLD)
    elseif k >= 1 then
      local r = clamp((t - t0 - 48) / 30, 0, 1)
      if r < 1 then gfx.ring(ox, 392, 10 + r * 50, 3, alpha(C.GOLD, floor(220 * (1 - r)))) end
      gfx.glow(ox, 392, 16 + sin(f * 0.1) * 3, alpha(C.GOLD, 120))
      gfx.star(ox, 394, 7, f * 0.05, C.GOLD)
    end
  end
  -- the monsters wake up, land by land
  local waking = {{1, 36, 392}, {2, 64, 372}, {6, 98, 394}, {3, 146, 392}, {4, 190, 376}, {7, 236, 394}, {5, 292, 392}, {8, 342, 380}}
  for i, w in ipairs(waking) do
    local k = clamp((t - 130 - i * 9) / 14, 0, 1)
    if k > 0 then
      local m = S.MONS[w[1]]
      P.draw_mon(m, w[2], w[3], 0.62 * k, k >= 1, 0, {hop = k >= 1 and (t % 40 < 24), look = 0})
    end
  end
  -- Hoot glides in with the book; the trainer walks on
  if t > 230 then
    local k = clamp((t - 230) / 60, 0, 1)
    local hy = lerp(-30, 176, ease.out_cubic(k))
    local hx = 192 + sin(t * 0.08) * (1 - k) * 40
    P.draw_hoot(hx, hy, 1.5, S.px and clamp((S.story_tx - hx) / 80, -1, 1) or 0, t > 330 and "cheer" or nil, k < 1)
  end
  if t > 270 then
    local k = clamp((t - 270) / 70, 0, 1)
    local tx = lerp(-24, 150, k)
    local moving = k < 1
    P.draw_trainer(tx, 312, 1, 0, t, moving, P.cap_col(S.rank), t > 345)
    S.story_tx = tx
  end
  -- Hoot's picture: orb, then a friend, then a sticker in the book
  if t > 318 then
    local k = clamp((t - 318) / 14, 0, 1)
    local bx, by, bw, bh = 62, 238, 260, 44
    gfx.rrect_o(bx, by, bw * k, bh, 14, C.CREAM, C.INK, 2)
    if k >= 1 then
      P.draw_orb(bx + 36, by + 22, 10, false, 0)
      gfx.text(">", bx + 78, by + 10, 20, C.INK, "center")
      P.draw_mon(S.MONS[1], bx + 124, by + 26, 0.6, true, 0, {hop = true})
      gfx.text(">", bx + 170, by + 10, 20, C.INK, "center")
      gfx.rrect_o(bx + 190, by + 6, 44, 32, 5, C.PAPER, C.BROWN, 2)
      gfx.star(bx + 212, by + 22, 10, f * 0.03, C.GOLD)
    end
  end
end

return P
