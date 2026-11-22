-- Dig's pictures. main.lua owns the rules and fills P.S; everything here only draws.
local P = {}

local C = {
  CREAM = 0xfff6ea, INK = 0x3a2a44, SKY_TOP = 0x6ec6ff, SKY_BOT = 0xb8e6ff,
  GRASS = 0x68c860, GRASS_DARK = 0x4ca848,
  L1 = 0xe8b878, L2 = 0xd88848, L3 = 0xc06248, L4 = 0x7c485c,
  TUNNEL = 0x3b2434, TUNNEL_RIM = 0x523448,
  HAT = 0xe84855, SUIT = 0x4a82cc, SKIN = 0xf4c7a1, GOLD = 0xffd84a,
  AQUA = 0x7fe8ff, PURPLE = 0x8a5cf5, ROSE = 0xe86b9a, WHITE = 0xfffcf8,
  PUFF = 0xf46a3e, CHAR = 0xf28c38, FLAME = 0xffb830, ROCK = 0x9aa0ac, ROCK_DARK = 0x6c7280,
}
P.C = C
local INK, GOLD = C.INK, C.GOLD
local BAND = 32

local function fr() return game.frame end

-- Static sky, grass, and four earth strata: painted once per level into a backdrop.
local function paint_earth()
  local S = P.S
  local TOP, TILE = S.TOP, S.TILE
  -- Sunny sky.
  gfx.vgrad(0, 0, W, TOP, C.SKY_TOP, C.SKY_BOT)
  -- Distant rolling hills on the horizon.
  gfx.circle(64, TOP + 14, 56, 0x88d87a)
  gfx.circle(210, TOP + 18, 68, 0x7cc870)
  gfx.circle(344, TOP + 12, 54, 0x88d87a)
  -- Four colorful Dig Dug earth strata (3 rows each = 96 px each).
  local layers = {C.L1, C.L2, C.L3, C.L4}
  for i = 1, 4 do
    local y0 = TOP + (i - 1) * TILE * 3
    gfx.rect(0, y0, W, TILE * 3, layers[i])
    gfx.rect(0, y0, W, 4, shade(layers[i], 0.86))
    gfx.rect(0, y0 + 4, W, 2, shade(layers[i], 1.1))
  end
  -- Cozy pebbles and little fossils scattered in the dirt.
  for _, d in ipairs(S.pebbles) do
    local x, y, r, k = d[1], d[2], d[3], d[4]
    local col = k == 0 and alpha(0x3a2434, 48) or alpha(0xfff6ea, 42)
    gfx.ellipse(x, y, r, r * 0.65, col)
  end
  -- Lush green grass strip at the top of the earth.
  gfx.rect(0, TOP - 8, W, 14, C.GRASS)
  gfx.rect(0, TOP + 3, W, 4, C.GRASS_DARK)
  for x = 12, W - 12, 24 do
    gfx.circle(x, TOP - 6, 7, C.GRASS)
    if (x / 24) % 3 == 0 then
      gfx.circle(x, TOP - 8, 2.5, C.WHITE)
      gfx.circle(x, TOP - 8, 1.2, GOLD)
    end
  end
end

local function draw_clouds()
  for i = 0, 2 do
    local x = ((fr() * 0.18 + i * 150) % (W + 80)) - 40
    local y = 26 + (i % 2) * 18
    gfx.circle(x, y, 14, alpha(C.WHITE, 210))
    gfx.circle(x + 14, y - 4, 16, alpha(C.WHITE, 210))
    gfx.circle(x + 28, y + 1, 12, alpha(C.WHITE, 210))
  end
end

local function draw_tunnels()
  local S = P.S
  local COLS, ROWS, TILE, TOP = S.COLS, S.ROWS, S.TILE, S.TOP
  local dug = S.dug
  -- Rim pass first, then dark tunnel interior, so corridors merge seamlessly!
  for r = 1, ROWS do
    local cy = TOP + (r - 0.5) * TILE
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
    local cy = TOP + (r - 0.5) * TILE
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

local GEM_COLS = {0xe86b9a, 0x6eb5ff, 0x6fd38a, 0xffd84a}
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

local function draw_rock(rk)
  local x, y = rk.x, rk.y
  if rk.state == "wiggle" then
    x = x + sin(fr() * 0.9) * 3.5
  end
  toon(function()
    toon.ellipse(x, y, 14, 12, C.ROCK)
    toon.ellipse(x - 4, y - 4, 8, 6, 0xb4bac6)
  end, 2.2, INK)
  gfx.line(x - 5, y + 3, x + 2, y + 6, 1.6, C.ROCK_DARK)
  gfx.line(x + 2, y - 3, x + 7, y + 1, 1.5, C.ROCK_DARK)
  if rk.state == "wiggle" then
    gfx.glow(x, y, 22, alpha(GOLD, 110))
  end
end

-- Puff (Pooka homage): round rosy-orange critter with big round goggles!
local function draw_puff(e)
  local sc = 1 + e.puff * 0.34
  local bob = e.puff == 0 and -abs(sin(fr() * 0.18 + e.ph)) * 3 or sin(fr() * 0.6) * 2
  local x, y = e.x, e.y + bob
  local r = 11 * sc
  if e.ghost then gfx.glow(x, y, 22, alpha(C.AQUA, 140)) end
  toon(function()
    toon.ellipse(x - 5 * sc, y + r * 0.85, 4.5, 3, GOLD)
    toon.ellipse(x + 5 * sc, y + r * 0.85, 4.5, 3, GOLD)
    toon.circle(x, y, r, e.puff >= 2 and 0xff9268 or C.PUFF)
  end, 2.2, INK)
  -- Big yellow-and-white goggles!
  local gy = y - 2 * sc
  gfx.rrect_o(x - 9 * sc, gy - 4.5 * sc, 18 * sc, 9 * sc, 4, GOLD, INK, 1.5)
  gfx.circle_o(x - 4 * sc, gy, 3.6 * sc, C.WHITE, INK, 1.2)
  gfx.circle_o(x + 4 * sc, gy, 3.6 * sc, C.WHITE, INK, 1.2)
  local pr = e.puff > 0 and 1.2 or 1.8
  gfx.circle(x - 4 * sc + e.dx * 1.2, gy, pr, INK)
  gfx.circle(x + 4 * sc + e.dx * 1.2, gy, pr, INK)
  if e.puff > 0 then
    -- Funny "O" mouth when inflated!
    gfx.circle_o(x, y + 5 * sc, 2.5 * sc, 0xffd0c0, INK, 1.2)
  end
end

-- Char (Fygar + Charmander homage): cute orange dragon with a glowing tail flame!
local function draw_char(e)
  local sc = 1 + e.puff * 0.34
  local bob = e.puff == 0 and -abs(sin(fr() * 0.15 + e.ph)) * 2.5 or sin(fr() * 0.6) * 2
  local x, y = e.x, e.y + bob
  local dir = e.dx < 0 and -1 or 1
  local r = 11 * sc
  -- Glowing tail flame behind him!
  local tx, ty = x - dir * (13 * sc), y + 4
  local fsize = e.fire_tele > 0 and 7.5 or 4.5
  gfx.glow(tx, ty - 4, e.fire_tele > 0 and 22 or 13, alpha(C.FLAME, e.fire_tele > 0 and 210 or 140))
  toon(function()
    toon.line(x - dir * 8, y + 6, tx, ty, 4.5, C.CHAR)
    toon.ellipse(x - 5 * sc, y + r * 0.85, 4.5, 3, C.CHAR)
    toon.ellipse(x + 5 * sc, y + r * 0.85, 4.5, 3, C.CHAR)
    toon.ellipse(x, y + 1, r * 1.05, r * 0.95, e.puff >= 2 and 0xffa858 or C.CHAR)
    toon.circle(x + dir * 4 * sc, y - 5 * sc, 7.5 * sc, e.puff >= 2 and 0xffa858 or C.CHAR)
  end, 2.2, INK)
  -- Tail flame teardrop.
  gfx.circle(tx, ty - 4, fsize, 0xff5a28)
  gfx.circle(tx, ty - 5, fsize * 0.6, GOLD)
  -- Cream belly.
  gfx.ellipse(x + dir * 2, y + 4 * sc, 6 * sc, 5 * sc, C.CREAM)
  -- Eyes.
  local hx, hy = x + dir * 5 * sc, y - 6 * sc
  gfx.circle(hx, hy, 2.6 * sc, C.WHITE)
  gfx.circle(hx + dir * 0.8, hy, 1.5, INK)
  if e.fire_tele > 0 then
    gfx.glow(x + dir * 13, y - 3, 16, alpha(C.PURPLE, 180))
    gfx.circle_o(x + dir * 11, y - 3, 3.5, C.PURPLE, INK, 1.2)
  elseif e.puff > 0 then
    gfx.circle_o(hx + dir * 2, hy + 4.5 * sc, 2.4 * sc, 0xffd8b0, INK, 1.2)
  end
end

-- Diggy: cheerful explorer in a red-and-white hard hat with glowing headlamp!
local function draw_diggy()
  local S = P.S
  if S.hurt_cool > 0 and idiv(S.hurt_cool, 4) % 2 == 1 then return end
  local clear = S.phase == "clear"
  local hop = clear and -abs(sin(fr() * 0.16)) * 10 or (S.moving and -abs(sin(S.walk_t * 0.4)) * 2 or 0)
  local x, y = S.px, S.py + hop
  local fx, fy = S.face_x, S.face_y
  -- Soft headlamp glow ahead of Diggy!
  gfx.glow(x + fx * 18, y + fy * 18, 28, alpha(GOLD, 75))
  toon(function()
    -- Little boots.
    local step = S.moving and sin(S.walk_t * 0.45) * 3 or 0
    toon.ellipse(x - 5 + step, y + 12, 4.5, 3, C.INK)
    toon.ellipse(x + 5 - step, y + 12, 4.5, 3, C.INK)
    -- Cozy blue suit body.
    toon.rrect(x - 9, y - 1, 18, 13, 6, C.SUIT)
    -- Round face.
    toon.circle(x, y - 6, 10, C.SKIN)
    -- Red-and-white hard hat!
    toon.ellipse(x, y - 12, 11.5, 7.5, C.HAT)
    toon.rrect(x - 13, y - 11, 26, 4, 2, C.WHITE)
  end, 2.2, INK)
  -- Glowing yellow headlamp on hat!
  gfx.circle_o(x + fx * 3, y - 14, 3.4, GOLD, INK, 1.2)
  gfx.circle(x + fx * 3, y - 14, 1.4, C.WHITE)
  -- Face expression.
  if clear then
    gfx.line(x - 6, y - 5, x - 3.5, y - 7.5, 1.8, INK)
    gfx.line(x - 3.5, y - 7.5, x - 1, y - 5, 1.8, INK)
    gfx.line(x + 1, y - 5, x + 3.5, y - 7.5, 1.8, INK)
    gfx.line(x + 3.5, y - 7.5, x + 6, y - 5, 1.8, INK)
    gfx.ellipse(x, y - 1, 3, 2.2, INK)
  else
    local ex = fx * 2.5
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

local function draw_veggie(v)
  if not v then return end
  local x, y = v.x, v.y + sin(fr() * 0.14) * 2.5
  gfx.glow(x, y, 22, alpha(GOLD, 160))
  if v.kind == 1 then -- Carrot
    toon(function() toon.tri(x - 6, y - 4, x + 6, y - 4, x, y + 11, 0xf47a28) end, 1.8, INK)
    gfx.line(x - 3, y - 5, x - 5, y - 10, 2.5, C.GRASS)
    gfx.line(x + 3, y - 5, x + 5, y - 10, 2.5, C.GRASS)
  elseif v.kind == 2 then -- Turnip
    toon(function() toon.circle(x, y + 2, 9, C.WHITE) end, 1.8, INK)
    gfx.ellipse(x, y - 3, 7, 3, C.PURPLE)
    gfx.line(x, y - 6, x, y - 12, 3, C.GRASS)
  elseif v.kind == 3 then -- Mushroom
    toon(function()
      toon.rrect(x - 4, y, 8, 9, 2, C.CREAM)
      toon.ellipse(x, y - 2, 10, 7, C.HAT)
    end, 1.8, INK)
    gfx.circle(x - 4, y - 3, 2, C.WHITE)
    gfx.circle(x + 4, y - 2, 2, C.WHITE)
  elseif v.kind == 4 then -- Pineapple
    toon(function() toon.ellipse(x, y + 2, 8, 10, GOLD) end, 1.8, INK)
    gfx.tri(x - 5, y - 6, x, y - 13, x + 5, y - 6, C.GRASS)
  else -- Golden Crown
    toon(function() toon.poly({x - 9, y + 6, x - 9, y - 4, x - 4, y, x, y - 8, x + 4, y, x + 9, y - 4, x + 9, y + 6}, GOLD) end, 1.8, INK)
  end
end

local function draw_hud()
  local S = P.S
  -- Level pill on top-left.
  gfx.rrect_o(8, 10, 96, 26, 9, C.CREAM, INK, 2)
  gfx.text("CAVE " .. S.level, 56, 14, 14, INK, "center")
  -- Score pill right below or beside.
  gfx.rrect_o(8, 40, 118, 22, 8, alpha(C.CREAM, 230), INK, 1.6)
  gfx.text("SCORE " .. S.score, 67, 43, 12, INK, "center")
  -- Three hearts in the top center.
  for i = 1, 3 do
    local hx = W / 2 - 26 + (i - 1) * 26
    local full = i <= (3 - S.hurts)
    gfx.heart(hx, 24, 10, INK)
    gfx.heart(hx, 24, 8, full and C.ROSE or 0x9aa4b8)
  end
  -- Gem counter on top-right.
  gfx.rrect_o(W - 102, 10, 94, 26, 9, C.CREAM, INK, 2)
  toon(function()
    toon.poly({W - 88, 22, W - 84, 17, W - 78, 17, W - 74, 22, W - 81, 30}, GOLD)
  end, 1.4, INK)
  gfx.text(tostring(S.gems), W - 64, 14, 14, INK, "left")
end

local function draw_clear_banner()
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
  local sub = S.gems == 1 and "1 GEM FOUND!" or (S.gems .. " GEMS FOUND!")
  gfx.text(sub, W / 2, by + 54, 16, C.PURPLE, "center", C.CREAM)
  if S.clear_t >= 90 and blink(46, 30) then
    gfx.rrect_o(W / 2 - 118, 396, 236, 30, 12, GOLD, INK, 2)
    gfx.text("PRESS FOR NEXT CAVE!", W / 2, 402, 15, INK, "center")
  end
end

function P.draw()
  local S = P.S
  backdrop("earth", paint_earth)
  draw_clouds()
  draw_tunnels()
  -- Buried & dropped gems + classic center bonus veggie.
  for _, g in ipairs(S.gems_list) do draw_gem(g) end
  draw_veggie(S.veggie)
  -- Boulders.
  for _, rk in ipairs(S.rocks) do draw_rock(rk) end
  -- Dragon fire puffs.
  for _, f in ipairs(S.flames) do
    gfx.glow(f.x, f.y, 18, alpha(C.PURPLE, 170))
    soap(f.x, f.y, 10, C.PURPLE)
    gfx.circle(f.x, f.y, 5, C.FLAME)
  end
  -- Auto-aim target stars on the critter the pump will puff!
  if S.aim and S.phase == "play" then
    for k = 0, 3 do
      local a = fr() * 0.09 + k * 1.571
      gfx.star(S.aim.x + cos(a) * 20, S.aim.y + sin(a) * 20, 5.5, a, INK)
      gfx.star(S.aim.x + cos(a) * 20, S.aim.y + sin(a) * 20, 4, a, GOLD)
    end
  end
  -- Critters.
  for _, e in ipairs(S.foes) do
    if e.kind == "char" then draw_char(e) else draw_puff(e) end
  end
  -- Active air pump hose!
  if S.pump and S.pump.t > 0 then
    local p = S.pump
    local k = p.t / 12
    gfx.line(p.x0, p.y0, p.x1, p.y1, 7 * k + 2, alpha(C.AQUA, floor(180 * k)))
    gfx.line(p.x0, p.y0, p.x1, p.y1, 3 * k + 1, alpha(C.WHITE, floor(255 * k)))
    soap(p.x1, p.y1, 10 + (1 - k) * 8, C.AQUA)
    p.t = p.t - 1
  end
  draw_diggy()
  draw_hud()
  if S.phase == "clear" then draw_clear_banner() end
end

return P
