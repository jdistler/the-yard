-- Handcrafted art for Safari v2: 3 cached habitat backdrops, 8 distinct Pokémon-homage
-- creature sprites, detailed Trainer, Friend Orbs, Golden Berries, Gym Stadium, and Badges.

local P = {}

local C = {
  CREAM = 0xfff6ea, INK = 0x34243e, GOLD = 0xffd84a, RED = 0xe84855,
  BLUE = 0x4ca8f5, GREEN = 0x58c464, PURPLE = 0x7e4ce8, ORANGE = 0xf48430,
  PIKA = 0xffdc36, CYAN = 0x6ce4ff, ROSE = 0xf06898, WHITE = 0xfffcf8,
  SKIN = 0xf6c9a2, CAP = 0xe63e4c, TEAL = 0x48b8a8, SHELL = 0x9c5a2c,
  BROWN = 0x7a4824, DARK = 0x241a30, LEAF = 0x389c48, LIME = 0x92e468,
  MINT = 0x76d8b4, NAVY = 0x365c72, SILVER = 0xd8e0ec,
}
P.C = C

local ZONES = {
  {name = "Sunny Meadow", top = 0x7ed874, bot = 0x5ab858, path = 0xebd4aa, edge = 0xc8a876, accent = 0x429c46},
  {name = "Spark Cave",   top = 0x5c4c7a, bot = 0x3c3056, path = 0x86789c, edge = 0x625478, accent = 0x7ce8ff},
  {name = "Crystal Pond", top = 0x5cc0e8, bot = 0x3b96c8, path = 0xe8d8b0, edge = 0xc4b084, accent = 0x76e8c8},
}
P.ZONES = ZONES

-- Painted habitat backdrop cached on a single reusable layer (768 KB, repainted on zone change).
local bg_layer, bg_zone = nil, 0

local function paint_zone(z)
  local Z = ZONES[z]
  gfx.vgrad(0, 0, W, H - 32, Z.top, Z.bot)

  if z == 1 then
    -- Sunny Meadow: winding dirt path, trees, wildflowers, white fence, tall grass patches!
    gfx.rrect(164, 128, 56, 326, 20, Z.edge)
    gfx.rrect(170, 132, 44, 320, 16, Z.path)
    gfx.rrect(0, 260, W, 56, 0, Z.edge)
    gfx.rrect(0, 266, W, 44, 0, Z.path)
    -- Tall grass tufts (rustle patches)
    local tufts = {{56, 198}, {314, 198}, {68, 368}, {312, 376}}
    for _, t in ipairs(tufts) do
      gfx.ellipse(t[1], t[2] + 8, 42, 22, 0x4ca84c)
      for k = -2, 2 do
        local bx = t[1] + k * 14
        gfx.tri(bx - 5, t[2] + 10, bx, t[2] - 10 - (k % 2) * 5, bx + 5, t[2] + 10, 0x368c3c)
        gfx.tri(bx - 3, t[2] + 10, bx + 1, t[2] - 7 - (k % 2) * 4, bx + 4, t[2] + 10, 0x68cc5a)
      end
    end
    -- White picket fence flanking the Gym path
    for _, fx in ipairs({30, 54, 78, 102, 282, 306, 330, 354}) do
      gfx.rrect_o(fx - 4, 126, 8, 22, 2, C.WHITE, C.INK, 1.4)
    end
    gfx.rect(24, 134, 86, 4, C.WHITE)
    gfx.rect(276, 134, 86, 4, C.WHITE)
    -- Wildflowers
    local fl = {{36, 232, C.GOLD}, {126, 200, C.ROSE}, {260, 194, C.WHITE}, {348, 240, C.GOLD},
                {40, 424, C.WHITE}, {132, 412, C.ROSE}, {258, 420, C.GOLD}, {344, 428, C.ROSE}}
    for _, f in ipairs(fl) do
      gfx.circle(f[1], f[2], 4.5, f[3])
      gfx.circle(f[1], f[2], 1.8, C.GOLD)
    end
  elseif z == 2 then
    -- Spark Cave: rocky cavern walls, glowing crystal clusters, stepping-stone trail!
    for _, cx in ipairs({28, 84, 300, 356}) do
      gfx.circle(cx, 124, 34, 0x34284a)
      gfx.circle(cx, 120, 26, 0x483864)
    end
    gfx.rrect(164, 128, 56, 326, 20, Z.edge)
    gfx.rrect(170, 132, 44, 320, 16, Z.path)
    gfx.rrect(0, 260, W, 56, 0, Z.edge)
    gfx.rrect(0, 266, W, 44, 0, Z.path)
    -- Glowing crystal clusters (amethyst / cyan / gold)
    local crys = {{54, 198, C.CYAN}, {326, 196, C.GOLD}, {64, 376, C.ROSE}, {318, 374, C.CYAN}}
    for _, cr in ipairs(crys) do
      gfx.glow(cr[1], cr[2], 32, alpha(cr[3], 90))
      gfx.tri(cr[1] - 12, cr[2] + 12, cr[1] - 6, cr[2] - 14, cr[1], cr[2] + 12, cr[3])
      gfx.tri(cr[1] - 4, cr[2] + 12, cr[1] + 4, cr[2] - 20, cr[1] + 12, cr[2] + 12, cr[3])
      gfx.tri(cr[1] + 6, cr[2] + 12, cr[1] + 14, cr[2] - 10, cr[1] + 18, cr[2] + 12, C.WHITE)
    end
    -- Cave pebbles
    for i = 1, 14 do
      local px, py = 24 + (i * 53) % (W - 48), 156 + (i * 71) % 280
      gfx.ellipse(px, py, 6, 3.5, 0x2c2240)
    end
  else
    -- Crystal Pond: shimmering turquoise water, sandy boardwalk, lily pads!
    gfx.rrect(162, 128, 60, 326, 14, Z.edge)
    gfx.rrect(168, 132, 48, 320, 10, Z.path)
    gfx.rrect(0, 260, W, 56, 0, Z.edge)
    gfx.rrect(0, 266, W, 44, 0, Z.path)
    -- Wooden dock planks along center path
    for py = 148, 438, 18 do
      gfx.line(170, py, 214, py, 1.5, alpha(C.BROWN, 120))
    end
    -- Lily pads with pink water-lilies
    local pads = {{62, 198}, {318, 202}, {66, 372}, {314, 378}, {114, 224}, {270, 344}}
    for i, lp in ipairs(pads) do
      gfx.circle_o(lp[1], lp[2], 18, 0x48b862, 0x2c7844, 1.8)
      gfx.tri(lp[1], lp[2], lp[1] + 19, lp[2] - 6, lp[1] + 19, lp[2] + 6, Z.bot)
      if i <= 4 then
        gfx.circle(lp[1] - 4, lp[2] - 4, 5, C.ROSE)
        gfx.circle(lp[1] - 4, lp[2] - 4, 2, C.GOLD)
      end
    end
  end
end

function P.build_bgs()
  bg_layer = gfx.layer(W, H)
  bg_zone = 0
end

local function ensure_bg(z)
  if not bg_layer then bg_layer = gfx.layer(W, H) end
  if bg_zone ~= z then
    bg_zone = z
    bg_layer:paint(function() paint_zone(z) end)
  end
end

-- ------------------------------------------------------------------ 8 Pokémon-homage sprites!
function P.draw_mon(m, x, y, s, happy, atk_t)
  local f = game.frame
  local bob = sin(f * 0.11 + m.id * 1.3) * 3 * s
  local lunge = (atk_t and atk_t > 0) and (-sin(atk_t / 14 * math.pi) * 14 * s) or 0
  y = y + bob + lunge

  -- Ground shadow
  gfx.ellipse(x, y + 19 * s - bob * 0.5, 17 * s, 5.5 * s, alpha(C.DARK, 85))

  local k = m.kind
  if k == "elec" then
    -- SPARKY (Pikachu homage): zigzag lightning tail, black-tipped tall ears, sparking red cheeks!
    local wag = sin(f * 0.16 + m.id) * 3 * s
    gfx.line(x + 10 * s, y + 6 * s, x + 19 * s, y - 1 * s + wag, 4 * s, C.BROWN)
    gfx.line(x + 17 * s, y - 1 * s + wag, x + 23 * s, y - 8 * s + wag, 5.5 * s, C.PIKA)
    gfx.line(x + 20 * s, y - 8 * s + wag, x + 27 * s, y - 18 * s + wag, 6.5 * s, C.GOLD)
    toon(function()
      -- Tall pointed ears
      toon.tri(x - 8 * s, y - 10 * s, x - 17 * s, y - 32 * s, x - 1 * s, y - 15 * s, C.PIKA)
      toon.tri(x + 8 * s, y - 10 * s, x + 17 * s, y - 32 * s, x + 1 * s, y - 15 * s, C.PIKA)
      -- Chubby body & head
      toon.ellipse(x, y + 6 * s, 14 * s, 12 * s, C.PIKA)
      toon.circle(x, y - 5 * s, 13 * s, C.PIKA)
      -- Little paws
      toon.circle(x - 8 * s, y + 15 * s, 4 * s, C.PIKA)
      toon.circle(x + 8 * s, y + 15 * s, 4 * s, C.PIKA)
    end, 2 * s, C.INK)
    -- Black ear tips
    gfx.tri(x - 13 * s, y - 22 * s, x - 17 * s, y - 32 * s, x - 8 * s, y - 24 * s, C.INK)
    gfx.tri(x + 13 * s, y - 22 * s, x + 17 * s, y - 32 * s, x + 8 * s, y - 24 * s, C.INK)
    -- Rosy electric cheeks (sparkle periodically!)
    gfx.circle(x - 8.5 * s, y - 1 * s, 3.6 * s, C.RED)
    gfx.circle(x + 8.5 * s, y - 1 * s, 3.6 * s, C.RED)
    if (f + m.id * 9) % 45 < 10 then
      gfx.star(x - 13 * s, y - 2 * s, 4 * s, f * 0.2, C.GOLD)
      gfx.star(x + 13 * s, y - 2 * s, 4 * s, -f * 0.2, C.GOLD)
    end

  elseif k == "leaf" then
    -- SPROUT (Bulbasaur homage): mint-teal frog-dino with layered green leaf bulb on back!
    toon(function()
      -- Layered leaf bulb on back
      toon.ellipse(x, y - 13 * s, 13 * s, 10 * s, C.LEAF)
      toon.tri(x - 8 * s, y - 17 * s, x, y - 27 * s, x + 8 * s, y - 17 * s, C.GREEN)
      -- Squat body & wide head
      toon.ellipse(x, y + 4 * s, 16 * s, 12 * s, C.MINT)
      toon.circle(x - 11 * s, y + 13 * s, 4.5 * s, C.MINT)
      toon.circle(x + 11 * s, y + 13 * s, 4.5 * s, C.MINT)
      -- Little pointed ears
      toon.tri(x - 12 * s, y - 4 * s, x - 15 * s, y - 13 * s, x - 6 * s, y - 8 * s, C.MINT)
      toon.tri(x + 12 * s, y - 4 * s, x + 15 * s, y - 13 * s, x + 6 * s, y - 8 * s, C.MINT)
    end, 2 * s, C.INK)
    -- Dark teal spots & leaf veins
    gfx.circle(x - 9 * s, y - 7 * s, 2.5 * s, 0x2d8a78)
    gfx.circle(x + 9 * s, y - 5 * s, 2.8 * s, 0x2d8a78)
    gfx.line(x, y - 24 * s, x, y - 10 * s, 1.5 * s, C.LIME)

  elseif k == "fire" then
    -- EMBER (Charmander homage): orange fire lizard with cream belly & flickering tail flame!
    local fl = sin(f * 0.35 + m.id) * 2.5 * s
    toon(function()
      -- Curved tail
      toon.ellipse(x + 15 * s, y + 8 * s, 9 * s, 4.5 * s, C.ORANGE)
      -- Body & round dino head
      toon.ellipse(x, y + 6 * s, 12 * s, 13 * s, C.ORANGE)
      toon.circle(x, y - 8 * s, 11.5 * s, C.ORANGE)
      toon.circle(x - 7 * s, y + 16 * s, 4.2 * s, C.ORANGE)
      toon.circle(x + 7 * s, y + 16 * s, 4.2 * s, C.ORANGE)
    end, 2 * s, C.INK)
    -- Cream belly
    gfx.ellipse(x, y + 8 * s, 7.5 * s, 8.5 * s, C.CREAM)
    -- Flickering tail flame!
    gfx.glow(x + 22 * s, y + 1 * s, 18 * s, alpha(C.GOLD, 160))
    gfx.tri(x + 17 * s, y + 5 * s, x + 22 * s + fl * 0.4, y - 11 * s - abs(fl), x + 27 * s, y + 5 * s, C.RED)
    gfx.tri(x + 19 * s, y + 4 * s, x + 22 * s, y - 5 * s - abs(fl * 0.5), x + 25 * s, y + 4 * s, C.GOLD)

  elseif k == "psy" then
    -- MYSTIC (Alakazam homage): golden psychic fox sage with mustache & levitating bent spoons!
    local sp_bob = sin(f * 0.14) * 3 * s
    -- Levitating silver spoons!
    for _, side in ipairs({-1, 1}) do
      local sx, sy = x + side * 21 * s, y - 2 * s + sp_bob * side
      gfx.glow(sx, sy, 12 * s, alpha(C.CYAN, 110))
      gfx.line(sx, sy + 9 * s, sx, sy - 4 * s, 2.4 * s, C.SILVER)
      gfx.ellipse_o(sx, sy - 7 * s, 4 * s, 5.5 * s, C.SILVER, C.INK, 1.3 * s)
    end
    toon(function()
      -- Long pointed fox ears
      toon.tri(x - 7 * s, y - 11 * s, x - 18 * s, y - 29 * s, x - 1 * s, y - 15 * s, 0xf2c14e)
      toon.tri(x + 7 * s, y - 11 * s, x + 18 * s, y - 29 * s, x + 1 * s, y - 15 * s, 0xf2c14e)
      -- Body + brown chest armor + fox head
      toon.ellipse(x, y + 7 * s, 11 * s, 12 * s, 0xf2c14e)
      toon.rrect(x - 8 * s, y + 2 * s, 16 * s, 9 * s, 3 * s, C.BROWN)
      toon.tri(x - 12 * s, y - 9 * s, x + 12 * s, y - 9 * s, x, y + 4 * s, 0xf2c14e)
      toon.circle(x, y - 8 * s, 10.5 * s, 0xf2c14e)
    end, 2 * s, C.INK)
    -- Iconic flowing golden mustache!
    gfx.tri(x - 2 * s, y - 1 * s, x - 16 * s, y + 4 * s, x - 11 * s, y + 9 * s, C.GOLD)
    gfx.tri(x + 2 * s, y - 1 * s, x + 16 * s, y + 4 * s, x + 11 * s, y + 9 * s, C.GOLD)

  elseif k == "water" then
    -- SPLASH (Squirtle homage): sky-blue turtle with brown shell, cream belly & curled tail!
    toon(function()
      -- Curled tail
      toon.circle(x + 15 * s, y + 6 * s, 6.5 * s, C.BLUE)
      -- Brown shell peeking behind body
      toon.ellipse(x + 4 * s, y + 6 * s, 14 * s, 13 * s, C.SHELL)
      -- Blue turtle body & round head
      toon.ellipse(x - 2 * s, y + 7 * s, 11 * s, 12 * s, C.BLUE)
      toon.circle(x - 2 * s, y - 7 * s, 11.5 * s, C.BLUE)
      toon.circle(x - 9 * s, y + 16 * s, 4 * s, C.BLUE)
      toon.circle(x + 5 * s, y + 16 * s, 4 * s, C.BLUE)
    end, 2 * s, C.INK)
    -- Cream belly & shell rim
    gfx.ellipse(x - 2 * s, y + 8 * s, 7.5 * s, 9 * s, C.CREAM)
    gfx.line(x - 8 * s, y + 8 * s, x + 4 * s, y + 8 * s, 1.3 * s, C.INK)
    gfx.circle(x + 15 * s, y + 6 * s, 2.5 * s, C.CYAN)

  elseif k == "bear" then
    -- SNOOZE (Snorlax homage): big cozy teal-navy sleeper with cream face, huge belly & padded feet!
    toon(function()
      toon.tri(x - 11 * s, y - 12 * s, x - 15 * s, y - 23 * s, x - 4 * s, y - 15 * s, C.NAVY)
      toon.tri(x + 11 * s, y - 12 * s, x + 15 * s, y - 23 * s, x + 4 * s, y - 15 * s, C.NAVY)
      toon.ellipse(x, y + 5 * s, 18 * s, 16 * s, C.NAVY)
      toon.circle(x, y - 8 * s, 13 * s, C.NAVY)
      toon.ellipse(x - 11 * s, y + 16 * s, 6.5 * s, 4.5 * s, C.CREAM)
      toon.ellipse(x + 11 * s, y + 16 * s, 6.5 * s, 4.5 * s, C.CREAM)
    end, 2 * s, C.INK)
    -- Big cream belly + cream face mask
    gfx.ellipse(x, y + 7 * s, 13 * s, 11 * s, C.CREAM)
    gfx.ellipse(x, y - 6 * s, 9.5 * s, 8 * s, C.CREAM)
    -- Cute sleepy paws
    gfx.circle(x - 11 * s, y + 16 * s, 2.2 * s, C.BROWN)
    gfx.circle(x + 11 * s, y + 16 * s, 2.2 * s, C.BROWN)

  elseif k == "ghost" then
    -- GIGGLE (Gengar homage): spiky royal-purple phantom with glowing red eyes & wide white grin!
    toon(function()
      toon.tri(x - 12 * s, y - 6 * s, x - 19 * s, y - 24 * s, x - 3 * s, y - 14 * s, C.PURPLE)
      toon.tri(x + 12 * s, y - 6 * s, x + 19 * s, y - 24 * s, x + 3 * s, y - 14 * s, C.PURPLE)
      -- Head spikes
      toon.tri(x - 5 * s, y - 13 * s, x, y - 22 * s, x + 5 * s, y - 13 * s, C.PURPLE)
      toon.circle(x, y, 16 * s, C.PURPLE)
      toon.circle(x - 10 * s, y + 13 * s, 5 * s, C.PURPLE)
      toon.circle(x + 10 * s, y + 13 * s, 5 * s, C.PURPLE)
    end, 2 * s, C.INK)
    -- Wide mischievous toothy white grin!
    gfx.rrect_o(x - 10 * s, y + 2 * s, 20 * s, 7.5 * s, 4 * s, C.WHITE, C.INK, 1.4 * s)
    for gx = -6, 6, 4 do
      gfx.line(x + gx * s, y + 2 * s, x + gx * s, y + 9.5 * s, 1.2 * s, C.INK)
    end
    -- Glowing crimson eyes (or happy ^ ^)
    if happy then
      gfx.line(x - 9 * s, y - 5 * s, x - 5 * s, y - 9 * s, 2.2 * s, C.WHITE)
      gfx.line(x - 5 * s, y - 9 * s, x - 1 * s, y - 5 * s, 2.2 * s, C.WHITE)
      gfx.line(x + 1 * s, y - 5 * s, x + 5 * s, y - 9 * s, 2.2 * s, C.WHITE)
      gfx.line(x + 5 * s, y - 9 * s, x + 9 * s, y - 5 * s, 2.2 * s, C.WHITE)
    else
      gfx.tri(x - 10 * s, y - 9 * s, x - 2 * s, y - 5 * s, x - 8 * s, y - 3 * s, C.RED)
      gfx.tri(x + 10 * s, y - 9 * s, x + 2 * s, y - 5 * s, x + 8 * s, y - 3 * s, C.RED)
      gfx.circle(x - 5 * s, y - 6 * s, 1.4 * s, C.WHITE)
      gfx.circle(x + 5 * s, y - 6 * s, 1.4 * s, C.WHITE)
    end
    return

  elseif k == "drag" then
    -- SKYWING (Dragonite homage): golden-orange friendly dragon with flapping teal wings & antennae!
    local flap = sin(f * 0.22 + m.id) * 5 * s
    toon(function()
      -- Dragon wings (orange outer, teal inner)
      toon.tri(x - 10 * s, y + 2 * s, x - 29 * s, y - 14 * s + flap, x - 16 * s, y + 10 * s, C.TEAL)
      toon.tri(x + 10 * s, y + 2 * s, x + 29 * s, y - 14 * s + flap, x + 16 * s, y + 10 * s, C.TEAL)
      -- Chubby dragon body & snout
      toon.ellipse(x, y + 6 * s, 13 * s, 13 * s, 0xf2a43c)
      toon.circle(x, y - 8 * s, 11 * s, 0xf2a43c)
      toon.circle(x - 7 * s, y + 16 * s, 4.5 * s, 0xf2a43c)
      toon.circle(x + 7 * s, y + 16 * s, 4.5 * s, 0xf2a43c)
    end, 2 * s, C.INK)
    -- Ribbed cream dragon belly
    gfx.ellipse(x, y + 7 * s, 8 * s, 9.5 * s, C.CREAM)
    for ry = 3, 12, 4 do
      gfx.line(x - 6 * s, y + ry * s, x + 6 * s, y + ry * s, 1.2 * s, alpha(C.BROWN, 140))
    end
    -- Cute curved antennae
    gfx.line(x - 4 * s, y - 17 * s, x - 10 * s, y - 26 * s, 2 * s, C.GOLD)
    gfx.line(x + 4 * s, y - 17 * s, x + 10 * s, y - 26 * s, 2 * s, C.GOLD)
  end

  -- Shared expressive face (for non-Giggle monsters)
  local ey = (k == "leaf") and (y - 1 * s) or (y - 7 * s)
  if happy or (k == "bear" and not (atk_t and atk_t > 0)) then
    gfx.line(x - 8 * s, ey, x - 5 * s, ey - 4 * s, 2 * s, C.INK)
    gfx.line(x - 5 * s, ey - 4 * s, x - 2 * s, ey, 2 * s, C.INK)
    gfx.line(x + 2 * s, ey, x + 5 * s, ey - 4 * s, 2 * s, C.INK)
    gfx.line(x + 5 * s, ey - 4 * s, x + 8 * s, ey, 2 * s, C.INK)
  else
    gfx.circle(x - 5 * s, ey, 2.8 * s, C.INK)
    gfx.circle(x + 5 * s, ey, 2.8 * s, C.INK)
    gfx.circle(x - 6 * s, ey - 1 * s, 1.1 * s, C.WHITE)
    gfx.circle(x + 4 * s, ey - 1 * s, 1.1 * s, C.WHITE)
  end
  -- Cute smile
  gfx.line(x - 3 * s, ey + 5 * s, x, ey + 6.5 * s, 1.6 * s, C.INK)
  gfx.line(x, ey + 6.5 * s, x + 3 * s, ey + 5 * s, 1.6 * s, C.INK)
end

-- ------------------------------------------------------------------ Trainer sprite
function P.draw_trainer(x, y, fx, fy, walk_t, moving)
  local step = moving and sin(walk_t * 0.35) * 3.5 or 0
  gfx.ellipse(x, y + 18, 12, 4.5, alpha(C.DARK, 85))
  toon(function()
    -- Stepping shoes
    toon.circle(x - 5, y + 15 + step, 4.2, C.RED)
    toon.circle(x + 5, y + 15 - step, 4.2, C.RED)
    -- Backpack peeking behind
    toon.rrect(x - 12, y - 1, 24, 14, 5, C.GREEN)
    -- Blue trainer jacket
    toon.rrect(x - 9, y, 18, 15, 5, C.BLUE)
    -- Head
    toon.circle(x, y - 8, 11, C.SKIN)
    -- Iconic Red & White Trainer Cap!
    toon.ellipse(x, y - 15, 13, 7, C.CAP)
    toon.rrect(x + (fx >= 0 and -2 or -14), y - 15, 16, 4.5, 2, C.CAP)
  end, 2.2, C.INK)
  -- White cap front patch + white jacket collar
  gfx.rrect(x - 5, y - 19, 10, 5, 2.5, C.WHITE)
  gfx.tri(x - 4, y, x + 4, y, x, y + 5, C.WHITE)
  -- Eyes looking in travel direction
  local ex = clamp(fx * 2, -2, 2)
  gfx.circle(x - 3.5 + ex, y - 8, 1.9, C.INK)
  gfx.circle(x + 3.5 + ex, y - 8, 1.9, C.INK)
  gfx.circle(x - 4 + ex, y - 9, 0.8, C.WHITE)
  gfx.circle(x + 3 + ex, y - 9, 0.8, C.WHITE)
end

-- ------------------------------------------------------------------ Friend Orb & Golden Super Orb
function P.draw_orb(x, y, r, super_orb, wob)
  wob = wob or 0
  if super_orb then gfx.glow(x + wob, y, r * 2.4, alpha(C.GOLD, 160)) end
  gfx.circle_o(x + wob, y, r, C.WHITE, C.INK, 2)
  gfx.rrect(x - r + 1 + wob, y - r + 1, (r - 1) * 2, r, r * 0.75, super_orb and C.GOLD or C.RED)
  gfx.rect(x - r + 1 + wob, y - 1, (r - 1) * 2, 2.6, C.INK)
  gfx.circle_o(x + wob, y, r * 0.3, C.WHITE, C.INK, 1.4)
  gfx.circle(x - r * 0.35 + wob, y - r * 0.45, r * 0.16, alpha(C.WHITE, 210))
end

-- ------------------------------------------------------------------ Gym Stadium Arena
local function paint_gym()
  gfx.vgrad(0, 0, W, H - 32, 0x262044, 0x3c2e64)
  -- Stadium floor court with a ring in the center
  gfx.rrect_o(18, 118, W - 36, 326, 20, 0x4a7e5a, C.INK, 3)
  gfx.rrect(26, 126, W - 52, 310, 14, 0x5c9668)
  gfx.line(26, 280, W - 26, 280, 3, alpha(C.WHITE, 140))
  gfx.circle_o(W / 2, 280, 38, alpha(C.WHITE, 45), alpha(C.WHITE, 160), 3)
  gfx.circle_o(W / 2, 280, 12, alpha(C.GOLD, 120), alpha(C.WHITE, 180), 2.5)
  -- Opponent & Player battle platforms
  gfx.ellipse_o(192, 188, 92, 26, alpha(C.CREAM, 195), C.INK, 2.2)
  gfx.ellipse_o(192, 368, 102, 28, alpha(C.CREAM, 195), C.INK, 2.2)
end

-- The arena is painted once (the dithered gradient is the costly part); only the beams move.
function P.draw_gym_bg(zone, foe_col)
  backdrop("gym", paint_gym)
  local sw = sin(game.frame * 0.04) * 28
  gfx.tri(24, 56, 150 + sw, 420, 230 + sw, 420, alpha(C.GOLD, 22))
  gfx.tri(W - 24, 56, W - 230 - sw, 420, W - 150 - sw, 420, alpha(foe_col or C.CYAN, 22))
end

-- ------------------------------------------------------------------ Zone Backdrop & Gym Arch
function P.draw_explore_bg(zone)
  ensure_bg(zone)
  gfx.draw(bg_layer, 0, 0)
  -- Grand Starlight Gym Arch at top center!
  gfx.rrect_o(126, 86, 132, 52, 12, C.CREAM, C.INK, 2.5)
  gfx.rrect(128, 88, 128, 18, 10, C.RED)
  gfx.rect(128, 103, 128, 3, C.INK)
  gfx.circle_o(192, 104, 6, C.WHITE, C.INK, 1.8)
  gfx.text("STARLIGHT GYM", 192, 114, 15, C.GOLD, "center", C.INK)
  -- Pulsing lantern globes flanking the arch
  local glow_a = 120 + floor(sin(game.frame * 0.1) * 45)
  gfx.glow(128, 116, 18, alpha(C.GOLD, glow_a))
  gfx.glow(256, 116, 18, alpha(C.GOLD, glow_a))
  -- Zone arrows left/right
  local bob = sin(game.frame * 0.12) * 3
  gfx.rrect_o(6 + bob, 274, 24, 28, 8, alpha(C.CREAM, 210), C.INK, 1.8)
  gfx.text("<", 18 + bob, 278, 18, C.INK, "center")
  gfx.rrect_o(W - 30 - bob, 274, 24, 28, 8, alpha(C.CREAM, 210), C.INK, 1.8)
  gfx.text(">", W - 18 - bob, 278, 18, C.INK, "center")
end

-- ------------------------------------------------------------------ Badge Ceremony Emblem
local BADGE_COLS = {C.GOLD, C.BLUE, C.RED, C.GREEN, C.PURPLE, C.CYAN}
local BADGE_NAMES = {"ZAP", "SPLASH", "FLAME", "MEADOW", "MYSTIC", "STARLIGHT"}
function P.badge_info(n)
  local idx = ((n - 1) % #BADGE_COLS) + 1
  return BADGE_COLS[idx], BADGE_NAMES[idx]
end

function P.draw_badge(x, y, n, sc)
  local col = P.badge_info(n)
  gfx.glow(x, y, 36 * sc, alpha(col, 150))
  gfx.star(x, y, 22 * sc, game.frame * 0.03, C.INK)
  gfx.star(x, y, 18 * sc, game.frame * 0.03, col)
  gfx.circle_o(x, y, 8 * sc, C.WHITE, C.INK, 1.5 * sc)
end

return P
