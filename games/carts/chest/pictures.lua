-- Chest's pictures. main.lua owns the rules and fills P.S; everything here only draws.
local P = {}

local C = {
  CREAM = 0xfff6ea, INK = 0x3a2a44, CAPE = 0x3a6ea5, SKIN = 0xf4c7a1, GOLD = 0xf2c14e, WOOD = 0xc4844a,
  BROWN = 0x8a5a32, SPOON = 0xbabec8, BLUE = 0x6eb5ff, PURPLE = 0x7a5af5, ROSE = 0xe86b9a, WHITE = 0xfffcf8,
  HELM = 0xc8d0e0, FUR = 0xf2c14e, FUR_DARK = 0xd89a2a, CYAN = 0x7fe8ff,
}
P.C = C
local INK, GOLD = C.INK, C.GOLD
local BAND, PILE_SHOWN = 32, 15

local function fr() return game.frame end

local function paint_ground()
  local S = P.S
  gfx.vgrad(0, 0, W, H - BAND, 0x86d683, 0x6cc06a)
  for i, d in ipairs(S.deco) do
    local x, y, k = d[1], d[2], d[3]
    if k < 3 then
      gfx.tri(x - 4, y, x - 1, y - 8, x + 1, y, 0x5cb05a)
      gfx.tri(x, y, x + 3, y - 7, x + 5, y, 0x5cb05a)
    elseif k == 3 then
      for j = 0, 4 do gfx.circle(x + cos(j * 1.257) * 3, y + sin(j * 1.257) * 3, 2.5, i % 2 == 0 and 0xffffff or 0xffb0d0) end
      gfx.circle(x, y, 2, GOLD)
    else
      gfx.ellipse_o(x, y, 8, 5, 0xa8b0b8, INK, 1.5)
      gfx.ellipse(x - 2, y - 2, 4, 2, 0xc8d0d8)
    end
  end
  -- Bushes along the sides.
  for i = 0, 6 do
    local y = 60 + i * 64
    gfx.circle_o(-6, y, 26, 0x4aa04e, INK, 2)
    gfx.circle(-2, y - 6, 12, 0x5cb860)
    gfx.circle_o(W + 6, y + 30, 26, 0x4aa04e, INK, 2)
    gfx.circle(W + 2, y + 24, 12, 0x5cb860)
  end
  -- The path up to the chest.
  gfx.rrect(140, 188, 104, H - BAND - 188 + 10, 30, 0xead6b8)
  gfx.rrect(146, 192, 92, H - BAND - 192 + 10, 26, C.CREAM)
  for i = 0, 8 do gfx.ellipse(160 + (i % 2) * 50, 210 + i * 30, 10, 5, alpha(0xd8c4a4, 140)) end
end

local function draw_chest_box(open)
  local S = P.S
  local ZX = S.ZX
  local lift = open and 22 or S.hop
  local pulse = 0.5 + 0.5 * sin(fr() * 0.12)
  if open then gfx.glow(ZX, 160, 56, alpha(0xffd060, 150)) end
  toon(function()
    toon.rrect(152, 164, 80, 36, 5, C.WOOD)
    if not open then toon.rrect(146, 144 - lift, 92, 26, 12, 0xd0904e) else toon.rrect(146, 132, 92, 34, 10, 0xd0904e) end
  end, 2.5, INK)
  gfx.rect(152, 172, 80, 6, GOLD)
  gfx.rect(152, 188, 80, 4, alpha(0x8a5a2a, 160))
  gfx.rect(164, 164, 6, 36, GOLD)
  gfx.rect(214, 164, 6, 36, GOLD)
  if not open then
    gfx.rect(146, 158 - lift, 92, 5, GOLD)
    gfx.rrect_o(182, 160 - lift, 20, 20, 4, GOLD, INK, 2)
    if not S.has_key or fr() % 40 < 20 then gfx.glow(ZX, 170 - lift, 12 + pulse * 6, alpha(0xffe080, floor(80 + pulse * 100))) end
    gfx.circle(ZX, 167 - lift, 3, INK)
    gfx.tri(ZX - 2, 168 - lift, ZX + 2, 168 - lift, ZX, 175 - lift, INK)
  else
    -- The lid stands open behind the box: its dark inside faces us.
    gfx.rrect(152, 138, 80, 24, 7, 0x6a3a18)
    gfx.rect(146, 132, 92, 4, GOLD)
    gfx.rect(152, 160, 80, 6, 0x5a3010)
  end
end

local function draw_key(x, y)
  y = y + sin(fr() * 0.08) * 3
  gfx.glow(x, y - 10, 34, alpha(0xffe080, 120 + floor(sin(fr() * 0.1) * 50)))
  toon(function()
    toon.rrect(x - 4, y - 16, 8, 30, 3, GOLD)
    toon.circle(x, y - 26, 12, GOLD)
    toon.rrect(x + 2, y + 2, 11, 5, 2, GOLD)
    toon.rrect(x + 2, y + 9, 8, 5, 2, GOLD)
  end, 2.5, INK)
  gfx.circle(x, y - 26, 5, 0x86d683)
  gfx.circle(x - 5, y - 31, 2.5, alpha(0xffffff, 200))
  if fr() % 20 == 0 then particles.spawn(x + rnd(-12, 12), y - 26 + rnd(-12, 12), 0, -0.4, 30, 3, GOLD, "star") end
end

local function draw_fairy(x, y, c, full)
  local wing = abs(sin(fr() * 0.5)) * 5
  gfx.glow(x, y, 22, alpha(c, 120))
  gfx.ellipse(x - 10, y - 4, 7, 4 + wing, alpha(0xffffff, 200))
  gfx.ellipse(x + 10, y - 4, 7, 4 + wing, alpha(0xffffff, 200))
  gfx.circle_o(x, y, 8, c, INK, 2)
  gfx.circle(x - 2.5, y - 1, 1.3, INK)
  gfx.circle(x + 2.5, y - 1, 1.3, INK)
  if full then gfx.star(x, y + 10, 5, fr() * 0.1, GOLD) end
  if fr() % 3 == 0 then particles.spawn(x, y + 6, rnd(-0.3, 0.3), 0.5, 20, 2, alpha(c, 200), "glow") end
end

-- The treasure: a different thing for each win, in this order, then round again.
local GEMC = {[0] = 0xe86b9a, 0x6eb5ff, 0, 0x6fd38a, 0xa98bff}
function P.treasure(kind, x, y, s)
  if kind == 2 then -- a gold coin
    gfx.circle_o(x, y, 7 * s, GOLD, INK, 1.5)
    gfx.circle(x, y, 4.5 * s, 0xffd86a)
    gfx.rect(x - 1 * s, y - 3 * s, 2 * s + 1, 6 * s, 0xd89a2a)
  elseif kind == 5 then -- a ring
    gfx.ring(x, y + 2 * s, 5.5 * s, 3 * s, INK)
    gfx.ring(x, y + 2 * s, 5.5 * s, 1.8 * s, GOLD)
    gfx.circle_o(x, y - 4 * s, 3 * s, C.CYAN, INK, 1.2)
  elseif kind == 6 then -- a crown
    toon(function() toon.poly({x - 8 * s, y + 5 * s, x - 8 * s, y - 4 * s, x - 4 * s, y, x, y - 7 * s, x + 4 * s, y, x + 8 * s, y - 4 * s, x + 8 * s, y + 5 * s}, GOLD) end, 1.5, INK)
    gfx.circle(x, y + 1 * s, 1.6 * s, C.ROSE)
  elseif kind == 7 then -- a golden spoon, like Zam's
    gfx.line(x - 5 * s, y + 7 * s, x + 2 * s, y - 1 * s, 3.5 * s, INK)
    gfx.line(x - 5 * s, y + 7 * s, x + 2 * s, y - 1 * s, 2 * s, GOLD)
    gfx.ellipse_o(x + 4 * s, y - 4 * s, 4 * s, 5 * s, GOLD, INK, 1.2)
  else -- a gem
    local c = GEMC[kind]
    toon(function() toon.poly({x - 7 * s, y - 2 * s, x - 4 * s, y - 7 * s, x + 4 * s, y - 7 * s, x + 7 * s, y - 2 * s, x, y + 8 * s}, c) end, 1.5, INK)
    gfx.tri(x - 4 * s, y - 7 * s, x, y - 2 * s, x - 7 * s, y - 2 * s, shade(c, 1.25))
    gfx.line(x - 7 * s, y - 2 * s, x + 7 * s, y - 2 * s, 1, shade(c, 0.7))
    gfx.circle(x - 2 * s, y - 4 * s, 1.2 * s, alpha(0xffffff, 220))
  end
end

-- A mound: five along the bottom, then four, three, two, one.
function P.pile_slot(i)
  local rows, r, k = {5, 4, 3, 2, 1}, 0, i
  while r < 4 and k >= rows[r + 1] do
    k = k - rows[r + 1]
    r = r + 1
  end
  return 22 + r * 7 + k * 14, 56 - r * 10
end

local function draw_pile()
  local S = P.S
  local n = min(S.gems, PILE_SHOWN)
  local hopy = S.pile_hop > 0 and -abs(sin(S.pile_hop * 0.3)) * 6 or 0
  gfx.ellipse_o(50, 62, 42, 9, 0xd8a850, INK, 2)
  for i = 0, n - 1 do
    if S.prize_t > 0 and i == n - 1 then break end
    local x, y = P.pile_slot(i)
    P.treasure(i % 8, x, y + (i == n - 1 and hopy or 0), 1)
  end
  if S.gems > PILE_SHOWN then
    gfx.glow(50, 8, 20, alpha(0xffe080, 150 + floor(sin(fr() * 0.1) * 60)))
    gfx.star(50, 8, 6, fr() * 0.05, GOLD)
  end
  if S.gems > 0 then gfx.text(tostring(S.gems), 96, 44, 16, C.CREAM, "left", INK) end
end

-- Zam: tall and gold, with long pointed ears, a long mustache, brown armor, and a spoon in
-- each hand. He hovers. Drawn as a tribute to the psychic he is based on (Alakazam, by
-- Nintendo, Creatures and Game Freak; see the README).
local function draw_zam(cx, cy, flash, bow)
  local S = P.S
  local FUR, BROWN = C.FUR, C.BROWN
  local b = bow and 12 or 0
  local bob = sin(fr() * 0.06) * 4
  local sway = sin(fr() * 0.05) * 2
  local tap = flash and sin(fr() * 0.8) * 4 or 0
  local sq = 1
  local fl = S.flinch_t > 0 and sin(S.flinch_t * 1.4) * 4 or 0
  local bend = clamp(S.bend_t / 40, 0, 1)
  if S.tele_t > 0 then
    -- Teleport: he narrows to a line and back.
    local half = idiv(S.TELE_FRAMES, 2)
    local k = S.tele_t > half and (S.TELE_FRAMES - S.tele_t) / half or S.tele_t / half
    sq = 1 - clamp(k, 0, 1)
    if sq < 0.08 then
      gfx.glow(cx, cy, 40, alpha(0xc8a8ff, 200))
      return
    end
  end
  cy = cy + bob
  cx = cx + fl
  -- His shadow on the grass, and the psychic glow around him.
  gfx.ellipse(cx, 212, 40 * sq, 6, alpha(0x2a5a2a, 90))
  gfx.glow(cx, cy + 10, 66 * sq, alpha(0xc8a0ff, 80))
  local function X(v) return cx + (v - cx) * sq end
  local hy = cy - 24 + b
  toon(function()
    -- Thin legs dangling, knees a little bent, brown at the knee.
    toon.line(X(cx - 10), cy + 40, X(cx - 14), cy + 56, 7, FUR)
    toon.line(X(cx - 14), cy + 56, X(cx - 9), cy + 72, 6, FUR)
    toon.line(X(cx + 10), cy + 40, X(cx + 14), cy + 56, 7, FUR)
    toon.line(X(cx + 14), cy + 56, X(cx + 9), cy + 72, 6, FUR)
    toon.ellipse(X(cx - 14), cy + 56, 5 * sq + 1, 4, BROWN)
    toon.ellipse(X(cx + 14), cy + 56, 5 * sq + 1, 4, BROWN)
    toon.ellipse(X(cx - 7), cy + 74, 6 * sq + 1, 3, FUR)
    toon.ellipse(X(cx + 7), cy + 74, 6 * sq + 1, 3, FUR)
    -- Thin arms out to the spoons.
    toon.line(X(cx - 22), cy + 6 + b, X(cx - 36 + sway), cy + 14 + b, 6, FUR)
    toon.line(X(cx - 36 + sway), cy + 14 + b, X(cx - 44 + sway), cy - 10 + tap + b, 6, FUR)
    toon.line(X(cx + 22), cy + 6 + b, X(cx + 36 + sway), cy + 14 + b, 6, FUR)
    toon.line(X(cx + 36 + sway), cy + 14 + b, X(cx + 44 + sway), cy - 10 - tap + b, 6, FUR)
    toon.ellipse(X(cx - 36 + sway), cy + 14 + b, 5 * sq + 1, 4, BROWN)
    toon.ellipse(X(cx + 36 + sway), cy + 14 + b, 5 * sq + 1, 4, BROWN)
    -- A slim body with a brown chest plate and big brown shoulders.
    toon.rrect(X(cx - 15), cy + b * 0.5, 30 * sq, 44, 12, FUR)
    toon.rrect(X(cx - 13), cy + 6 + b * 0.5, 26 * sq, 22, 7, BROWN)
    toon.ellipse(X(cx - 20), cy + 4 + b, 11 * sq + 1, 8, BROWN)
    toon.ellipse(X(cx + 20), cy + 4 + b, 11 * sq + 1, 8, BROWN)
    -- Long ears, swept up and out. The head: wide at the brow, a fox's snout.
    toon.tri(X(cx - 15), hy - 8, X(cx - 34), hy - 58, X(cx - 3), hy - 18, FUR)
    toon.tri(X(cx + 15), hy - 8, X(cx + 34), hy - 58, X(cx + 3), hy - 18, FUR)
    toon.ellipse(cx + sway * 0.3, hy - 2, 23 * sq + 1, 20, FUR)
    toon.ellipse(cx + sway * 0.3, hy + 10, 12 * sq + 1, 11, 0xf6d27a)
  end, 2.5, INK)
  local hx = cx + sway * 0.3
  local m1, m2 = sin(fr() * 0.07) * 3, sin(fr() * 0.07 + 1) * 3
  gfx.tri(X(cx - 13), hy - 12, X(cx - 28), hy - 48, X(cx - 6), hy - 18, C.FUR_DARK)
  gfx.tri(X(cx + 13), hy - 12, X(cx + 28), hy - 48, X(cx + 6), hy - 18, C.FUR_DARK)
  if sq > 0.5 then
    -- Narrow eyes, mostly closed: he is concentrating.
    if bow or S.dizzy_t > 0 then
      if S.dizzy_t > 0 then
        for k = 0, 2 do
          local a = fr() * 0.15 + k * 2.09
          gfx.star(hx + cos(a) * 22, hy - 26 + sin(a) * 6, 4, a, GOLD)
        end
      end
      gfx.line(hx - 14, hy - 4, hx - 5, hy - 2, 2.5, INK)
      gfx.line(hx + 5, hy - 2, hx + 14, hy - 4, 2.5, INK)
    else
      local look = clamp((S.nx - cx) * 0.02, -2, 2)
      gfx.line(hx - 15, hy - 6, hx - 4, hy - 2, 4.5, INK)
      gfx.line(hx + 4, hy - 2, hx + 15, hy - 6, 4.5, INK)
      gfx.circle(hx - 9 + look, hy - 4, 1.6, 0xfff6d0)
      gfx.circle(hx + 9 + look, hy - 4, 1.6, 0xfff6d0)
    end
    gfx.ellipse(hx, hy + 5, 3.5, 2.5, INK)
    -- The mustache: two long strands from under the nose, hanging past his chest.
    toon(function()
      toon.line(hx - 3, hy + 9, hx - 14, hy + 16, 5, BROWN)
      toon.line(hx - 14, hy + 16, hx - 22 + m1, hy + 40, 4, BROWN)
      toon.line(hx - 22 + m1, hy + 40, hx - 24 + m1 * 1.5, hy + 62, 3, BROWN)
      toon.line(hx + 3, hy + 9, hx + 14, hy + 16, 5, BROWN)
      toon.line(hx + 14, hy + 16, hx + 22 + m2, hy + 40, 4, BROWN)
      toon.line(hx + 22 + m2, hy + 40, hx + 24 + m2 * 1.5, hy + 62, 3, BROWN)
    end, 2, INK)
  end
  -- Spoons: bent at the end of a win, the trick he is proud of.
  local steel = flash and C.WHITE or C.SPOON
  for side = 0, 1 do
    local x = side == 1 and X(cx + 44 + sway) or X(cx - 44 + sway)
    local y = side == 1 and cy - 10 - tap + b or cy - 10 + tap + b
    local tip_x, tip_y = x + (side == 1 and 1 or -1) * 14 * bend, y - 30 + 10 * bend
    gfx.line(x, y + 6, x, y - 14, 6, INK)
    gfx.line(x, y + 6, x, y - 14, 3, steel)
    gfx.line(x, y - 14, tip_x, tip_y + 8, 6, INK)
    gfx.line(x, y - 14, tip_x, tip_y + 8, 3, steel)
    gfx.ellipse_o(tip_x, tip_y, 8, 10, steel, INK, 2)
    gfx.ellipse(tip_x - 2, tip_y - 3, 2.5, 4.5, alpha(0xffffff, flash and 255 or 170))
    if flash or S.telegraph > 0 then gfx.glow(tip_x, tip_y, 24, S.telegraph > 0 and alpha(0xb070ff, 200) or alpha(0xffffff, 200)) end
  end
  if S.flinch_t > 0 then gfx.glow(cx, cy, 60, alpha(0xffffff, S.flinch_t * 10)) end
  -- Marks so far: little lights over his head.
  if S.phase == "fight" or S.phase == "winbow" then
    for i = 0, S.marks_win - 1 do
      local x, y = cx - (S.marks_win - 1) * 6 + i * 12, 212
      gfx.circle(x, y, 4.5, INK)
      gfx.circle(x, y, 3.2, i < S.marks and GOLD or 0x5a4a6a)
      if i < S.marks then gfx.glow(x, y, 8, alpha(0xffe080, 100)) end
    end
  end
end

-- Reflect: a wall of light panels in front of him.
local function draw_shield(cx, cy)
  local S = P.S
  local k = clamp((S.SHIELD_FRAMES - S.shield_t) / 12, 0, 1) * clamp(S.shield_t / 12, 0, 1)
  for i = -3, 3 do
    local x, y = cx + i * 18, cy + 62 + abs(i) * 3
    local sh = 0.6 + 0.4 * sin(fr() * 0.2 + i)
    gfx.rrect(x - 8, y - 12 * k, 16, 24 * k + 1, 3, alpha(C.CYAN, floor(120 * sh)))
    gfx.rrect(x - 8, y - 12 * k, 16, 3, 1, alpha(C.WHITE, floor(200 * k)))
  end
  gfx.glow(cx, cy + 62, 70 * k, alpha(0x7fe8ff, 70))
end

local function draw_ned()
  local S = P.S
  local sword = S.has_sword and S.phase ~= "path" and S.phase ~= "pop"
  local step = S.moving and sin(S.walk_t * 0.35) or 0
  local x, y = S.nx, S.ny
  local fx, fy = S.face_x, (S.face_x == 0 and S.face_y == 0) and -1 or S.face_y
  if S.hurt_cool > 0 and idiv(S.hurt_cool, 4) % 2 == 1 then return end
  if sword and not S.moving then fx, fy = 0, -1 end
  gfx.ellipse(x, y + 34, 16, 5, alpha(0x2a5a2a, 110))
  toon(function()
    toon.poly({x - 13, y + 2, x + 13, y + 2, x + 17 - fx * 6, y + 30 + abs(step) * 2, x - 17 - fx * 6, y + 30 + abs(step) * 2}, C.CAPE)
    toon.rrect(x - 9 + step * 2, y + 20, 7, 14, 3, 0x5a4a6a)
    toon.rrect(x + 2 - step * 2, y + 20, 7, 14, 3, 0x5a4a6a)
    toon.rrect(x - 10, y + 2, 20, 22, 7, 0x5a8ac8)
    toon.circle(x, y - 10, 15, C.SKIN)
    toon.ellipse(x, y - 18, 17, 11, C.HELM)
  end, 2.5, INK)
  gfx.rect(x - 17, y - 17, 34, 3, 0x9aa4b8)
  gfx.ellipse(x - 6, y - 22, 5, 3, alpha(0xffffff, 200))
  gfx.circle(x, y - 30, 3, C.ROSE)
  if fy < 0 and fx == 0 then
    gfx.ellipse(x, y - 6, 12, 7, 0xb07a50)
  else
    local ex = fx * 4
    if fr() % 160 < 6 then
      gfx.line(x - 6 + ex, y - 8, x - 2 + ex, y - 8, 2, INK)
      gfx.line(x + 2 + ex, y - 8, x + 6 + ex, y - 8, 2, INK)
    else
      gfx.circle(x - 4 + ex, y - 8, 2.2, INK)
      gfx.circle(x + 4 + ex, y - 8, 2.2, INK)
    end
    gfx.ellipse(x - 8 + ex, y - 3, 3, 2, alpha(0xff8fa0, 120))
    gfx.ellipse(x + 8 + ex, y - 3, 3, 2, alpha(0xff8fa0, 120))
    gfx.line(x - 3 + ex, y - 2, x + 3 + ex, y - 2, 1.5, INK)
  end
  if S.has_key and not sword and S.phase == "path" then
    gfx.glow(x + 14, y + 4, 12, alpha(0xffe080, 120))
    gfx.rrect_o(x + 12, y - 2, 5, 14, 2, GOLD, INK, 1.5)
    gfx.circle_o(x + 14.5, y - 4, 4.5, GOLD, INK, 1.5)
  end
  if sword or (S.phase == "pop" and S.pop_t > 30) then
    -- The sword points at Zam by itself.
    local dx, dy = S.zx - x, S.zy - (y - 4)
    local d = sqrt(dx * dx + dy * dy)
    local ux, uy = d > 1 and dx / d or 0, d > 1 and dy / d or -1
    local sx, sy = x + ux * 16 + 10, y - 4 + uy * 10
    local tx, ty = sx + ux * 28, sy + uy * 28
    gfx.line(sx, sy, tx, ty, 9, INK)
    gfx.line(sx, sy, tx, ty, 5, GOLD)
    gfx.line(sx - uy * 7, sy + ux * 7, sx + uy * 7, sy - ux * 7, 6, INK)
    gfx.line(sx - uy * 6, sy + ux * 6, sx + uy * 6, sy - ux * 6, 3.5, C.BROWN)
    gfx.glow(tx, ty, 10, alpha(0xffe080, 120))
  end
  if S.phase == "fight" or S.phase == "restart" or S.phase == "winbow" then
    for i = 0, 2 do
      local px, py = x - 16 + i * 16, y - 46
      gfx.circle(px, py, 6, INK)
      gfx.circle(px, py, 4.5, i < S.pips and C.ROSE or alpha(0xfff6ea, 230))
      gfx.circle(px - 1.5, py - 1.5, 1.4, alpha(0xffffff, 200))
    end
  end
end

function P.draw()
  local S = P.S
  local ZX, ZY = S.ZX, S.ZY
  local flash = S.spoon_flash > 0
  backdrop("ground", paint_ground)
  draw_pile()
  draw_chest_box(S.phase ~= "path")
  if not S.has_key then draw_key(S.key_x, S.key_y) end
  if S.phase == "pop" then
    local k = ease.out_back(clamp(S.pop_t / 40, 0, 1))
    draw_zam(ZX, 150 - 32 * k, flash, false)
    if S.pop_t > 4 and S.pop_t < 34 then
      local t = (S.pop_t - 4) / 30
      local sx, sy = lerp(ZX + 40, S.nx, t), lerp(ZY - 40, S.ny - 10, t) - sin(t * math.pi) * 80
      gfx.glow(sx, sy, 16, alpha(0xffe080, 200))
      gfx.star(sx, sy, 8, fr() * 0.4, GOLD)
    end
  elseif S.phase ~= "path" then
    draw_zam(S.zx, S.zy, flash, S.phase == "winbow" or S.phase == "restart")
  end
  if S.shield_t > 0 and S.phase == "fight" then draw_shield(S.zx, S.zy) end
  if S.wrap > 0 then soap(S.zx, S.zy, 76 + sin(fr() * 0.15) * 3, GOLD) end
  if S.star then
    gfx.glow(S.star.x, S.star.y, 22, alpha(0xffe080, 160))
    gfx.star(S.star.x, S.star.y, 11, fr() * 0.05, INK)
    gfx.star(S.star.x, S.star.y, 9, fr() * 0.05, GOLD)
  end
  if S.telegraph > 0 then
    -- Where the bubble will go: a faint purple ring under him.
    gfx.ring(S.nx, S.ny + 20, 30 + (30 - S.telegraph), 2, alpha(0x7a5af5, 60 + S.telegraph * 4))
  end
  draw_ned()
  local ring = S.ring
  if ring then
    soap(ring.x, ring.y, ring.r + 14, ring.safe and C.BLUE or C.PURPLE)
    if ring.safe then
      gfx.star(ring.x, ring.y - 4, 7, fr() * 0.1, GOLD)
    else
      local k = clamp((ring.r - 8) / 18, 0, 1)
      gfx.ring(ring.x, ring.y, 40, 2, alpha(C.PURPLE, floor(60 + k * 160)))
    end
  end
  if S.fairy then
    draw_fairy(S.fairy_x, S.fairy_y, S.fairy == "gold" and GOLD or S.fairy == "blue" and C.BLUE or C.PURPLE, S.fairy == "blue")
  end
  for _, b in ipairs(S.bubbles) do soap(b.x, b.y, 13, C.PURPLE) end
  local beam = S.beam
  if beam and beam.t > 0 then
    local k = beam.t / 10
    local core = beam.blocked and C.CYAN or GOLD
    gfx.line(beam.x0, beam.y0, beam.x1, beam.y1, (S.has_sword and 10 or 6) * k + 2, alpha(core, floor(160 * k)))
    gfx.line(beam.x0, beam.y0, beam.x1, beam.y1, (S.has_sword and 4 or 2.5) * k + 1, alpha(C.WHITE, floor(255 * k)))
    gfx.glow(beam.x1, beam.y1, 18 * k + 4, beam.blocked and alpha(0x7fe8ff, 200) or alpha(0xffe080, 200))
    beam.t = beam.t - 1
  end
  if S.prize_t > 0 then
    -- The treasure arcs from Zam to the pile.
    local t = clamp(S.prize_t / 60, 0, 1)
    local px, py = P.pile_slot(min(S.gems - 1, PILE_SHOWN - 1))
    local x, y = lerp(S.zx, px, t), lerp(S.zy, py, t) - sin(t * math.pi) * 70
    gfx.glow(x, y, 20, alpha(0xffe080, 200))
    P.treasure(S.prize_kind, x, y, 1 + (1 - t) * 1.5)
  end
end

return P
