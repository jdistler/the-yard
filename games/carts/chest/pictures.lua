-- Chest's pictures. main.lua owns the rules and fills P.S; everything here only draws.
local P = {}

local C = {
  CREAM = 0xfff6ea, INK = 0x3a2a44, CAPE = 0x3a6ea5, SKIN = 0xf4c7a1, GOLD = 0xf2c14e, WOOD = 0xc4844a,
  BROWN = 0x8a5a32, SPOON = 0xbabec8, BLUE = 0x6eb5ff, PURPLE = 0x7a5af5, ROSE = 0xe86b9a, WHITE = 0xfffcf8,
  HELM = 0xc8d0e0, FUR = 0xf2c14e, FUR_DARK = 0xd89a2a, CYAN = 0x7fe8ff, AQUA = 0x9fe6ff,
  PIKA = 0xffd838, PIKA_DARK = 0xe6b21a, CHEEK = 0xe84855,
}
P.C = C
local INK, GOLD = C.INK, C.GOLD
local BAND, PILE_SHOWN = 32, 15

local function fr() return game.frame end
-- 1 on the beat, fading to 0 across it (drawing only; 0 when no song plays).
local function beat(k) return 1 - ((music.step() + (k or 0)) % 4) / 4 end

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
    -- Electric shimmer inside the chest right before Pika leaps out!
    if S.phase == "zambow" and S.bow_t > 34 then
      local a = floor(80 + 120 * abs(sin(fr() * 0.45)))
      gfx.glow(ZX, 156, 38, alpha(C.PIKA, a))
    end
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

local function draw_fairy(x, y, c, full, puff, s)
  s = s or 1
  local wing = abs(sin(fr() * 0.5)) * 5 * s
  gfx.glow(x, y, (22 + (puff or 0) * 18) * s, alpha(c, 120 + floor((puff or 0) * 100)))
  gfx.ellipse(x - 10 * s, y - 4 * s, 7 * s, 4 * s + wing, alpha(0xffffff, 200))
  gfx.ellipse(x + 10 * s, y - 4 * s, 7 * s, 4 * s + wing, alpha(0xffffff, 200))
  gfx.circle_o(x, y, 8 * s, c, INK, 2)
  gfx.circle(x - 2.5 * s, y - 1 * s, 1.3 * s, INK)
  gfx.circle(x + 2.5 * s, y - 1 * s, 1.3 * s, INK)
  if full then gfx.star(x, y + 10, 5, fr() * 0.1, GOLD) end
  if puff and puff > 0 then soap(x, y + 12, 3 + puff * 10, C.PURPLE) end
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
  elseif kind == 8 then -- a golden lightning bolt, like Pika's
    toon(function()
      toon.poly({x + 2 * s, y - 8 * s, x - 5 * s, y + 1 * s, x, y + 1 * s, x - 2 * s, y + 8 * s, x + 6 * s, y - 1 * s, x + 1 * s, y - 1 * s}, C.PIKA)
    end, 1.4, INK)
  else -- a gem
    local c = GEMC[kind] or 0xe86b9a
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
    P.treasure(i % 9, x, y + (i == n - 1 and hopy or 0), 1)
  end
  if S.gems > PILE_SHOWN then
    gfx.glow(50, 8, 20, alpha(0xffe080, 150 + floor(sin(fr() * 0.1) * 60)))
    gfx.star(50, 8, 6, fr() * 0.05, GOLD)
  end
  if S.gems > 0 then gfx.text(tostring(S.gems), 96, 44, 16, C.CREAM, "left", INK) end
end

local function draw_marks_row(cx, y)
  local S = P.S
  local step = S.marks_win > 15 and 10 or 12
  for i = 0, S.marks_win - 1 do
    local x = cx - (S.marks_win - 1) * (step * 0.5) + i * step
    gfx.circle(x, y, 4.3, INK)
    gfx.circle(x, y, 3, i < S.marks and GOLD or 0x5a4a6a)
    if i < S.marks then gfx.glow(x, y, 8 + beat(i) * 3, alpha(0xffe080, 80 + floor(beat(i) * 50))) end
  end
end

-- Zam: tall and gold, with long pointed ears, a long mustache, brown armor, and a spoon in
-- each hand. He hovers. Drawn as a tribute to Alakazam (Nintendo, Creatures and Game Freak).
local function draw_zam(cx, cy, flash, bow, show_marks)
  local S = P.S
  local FUR, BROWN = C.FUR, C.BROWN
  local b = bow and 12 or 0
  local bob = sin(fr() * 0.06) * 4
  local sway = sin(fr() * 0.05) * 2
  local tap = flash and sin(fr() * 0.8) * 4 or 0
  local sq = 1
  local fl = (S.boss == "zam" and S.flinch_t > 0) and sin(S.flinch_t * 1.4) * 4 or 0
  local bend = clamp(S.bend_t / 40, 0, 1)
  if S.boss == "zam" and S.tele_t > 0 then
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
  gfx.ellipse(cx, cy + 94, 38 * sq, 6, alpha(0x2a5a2a, 90))
  gfx.glow(cx, cy + 10, (S.surge and S.boss == "zam" and 76 or 64) * sq, alpha(0xc8a0ff, S.surge and 115 or 80))
  local function X(v) return cx + (v - cx) * sq end
  local hy = cy - 24 + b
  toon(function()
    toon.line(X(cx - 10), cy + 40, X(cx - 14), cy + 56, 7, FUR)
    toon.line(X(cx - 14), cy + 56, X(cx - 9), cy + 72, 6, FUR)
    toon.line(X(cx + 10), cy + 40, X(cx + 14), cy + 56, 7, FUR)
    toon.line(X(cx + 14), cy + 56, X(cx + 9), cy + 72, 6, FUR)
    toon.ellipse(X(cx - 14), cy + 56, 5 * sq + 1, 4, BROWN)
    toon.ellipse(X(cx + 14), cy + 56, 5 * sq + 1, 4, BROWN)
    toon.ellipse(X(cx - 7), cy + 74, 6 * sq + 1, 3, FUR)
    toon.ellipse(X(cx + 7), cy + 74, 6 * sq + 1, 3, FUR)
    toon.line(X(cx - 22), cy + 6 + b, X(cx - 36 + sway), cy + 14 + b, 6, FUR)
    toon.line(X(cx - 36 + sway), cy + 14 + b, X(cx - 44 + sway), cy - 10 + tap + b, 6, FUR)
    toon.line(X(cx + 22), cy + 6 + b, X(cx + 36 + sway), cy + 14 + b, 6, FUR)
    toon.line(X(cx + 36 + sway), cy + 14 + b, X(cx + 44 + sway), cy - 10 - tap + b, 6, FUR)
    toon.ellipse(X(cx - 36 + sway), cy + 14 + b, 5 * sq + 1, 4, BROWN)
    toon.ellipse(X(cx + 36 + sway), cy + 14 + b, 5 * sq + 1, 4, BROWN)
    toon.rrect(X(cx - 15), cy + b * 0.5, 30 * sq, 44, 12, FUR)
    toon.rrect(X(cx - 13), cy + 6 + b * 0.5, 26 * sq, 22, 7, BROWN)
    toon.ellipse(X(cx - 20), cy + 4 + b, 11 * sq + 1, 8, BROWN)
    toon.ellipse(X(cx + 20), cy + 4 + b, 11 * sq + 1, 8, BROWN)
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
    if bow or (S.boss == "zam" and S.dizzy_t > 0) then
      if S.boss == "zam" and S.dizzy_t > 0 then
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
    toon(function()
      toon.line(hx - 3, hy + 9, hx - 14, hy + 16, 5, BROWN)
      toon.line(hx - 14, hy + 16, hx - 22 + m1, hy + 40, 4, BROWN)
      toon.line(hx - 22 + m1, hy + 40, hx - 24 + m1 * 1.5, hy + 62, 3, BROWN)
      toon.line(hx + 3, hy + 9, hx + 14, hy + 16, 5, BROWN)
      toon.line(hx + 14, hy + 16, hx + 22 + m2, hy + 40, 4, BROWN)
      toon.line(hx + 22 + m2, hy + 40, hx + 24 + m2 * 1.5, hy + 62, 3, BROWN)
    end, 2, INK)
  end
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
    if flash or (S.boss == "zam" and S.telegraph > 0) then
      gfx.glow(tip_x, tip_y, 24, (S.boss == "zam" and S.telegraph > 0) and alpha(0xb070ff, 200) or alpha(0xffffff, 200))
    end
  end
  if S.boss == "zam" and S.flinch_t > 0 then gfx.glow(cx, cy, 60, alpha(0xffffff, S.flinch_t * 10)) end
  if show_marks then draw_marks_row(cx, 212) end
end

-- Pika: bright sunny yellow, long black-tipped ears, rosy electric cheeks, and a zig-zag
-- lightning-bolt tail! Drawn as a fan tribute to Pikachu (Nintendo, Creatures and Game Freak).
local function draw_pika(cx, cy, bow, show_marks)
  local S = P.S
  local PIKA = C.PIKA
  local charging = (S.boss == "pika") and (S.telegraph > 0 or (S.strike and S.strike.t > 0))
  local bounce = bow and -abs(sin(fr() * 0.16)) * 10 or sin(fr() * 0.1) * 3
  local wag = sin(fr() * (charging and 0.45 or 0.12)) * 5
  local fl = (S.boss == "pika" and S.flinch_t > 0) and sin(S.flinch_t * 1.4) * 4 or 0
  cx = cx + fl
  cy = cy + bounce
  -- Ground shadow + electric aura.
  gfx.ellipse(cx, S.PY + 42, 30, 6, alpha(0x2a5a2a, 95))
  if charging or (S.boss == "pika" and S.surge) or S.dash_t > 0 then
    gfx.glow(cx, cy, charging and 68 or 54, alpha(PIKA, charging and 155 or 95))
  end
  -- Zig-zag lightning tail behind body on the right.
  toon(function()
    toon.poly({
      cx + 16, cy + 18,
      cx + 28, cy + 8 + wag * 0.4,
      cx + 22, cy + 2 + wag * 0.5,
      cx + 40, cy - 10 + wag * 0.8,
      cx + 34, cy - 16 + wag * 0.9,
      cx + 52, cy - 28 + wag,
      cx + 42, cy - 8 + wag * 0.7,
      cx + 30, cy + 2 + wag * 0.5,
      cx + 34, cy + 10 + wag * 0.4,
      cx + 18, cy + 24,
    }, PIKA)
  end, 2.2, INK)
  -- Brown tail base.
  gfx.line(cx + 17, cy + 21, cx + 25, cy + 13 + wag * 0.3, 5, C.BROWN)
  -- Main body, head, ears, paws, feet.
  local hy = cy - 18
  local ear_w = sin(fr() * 0.09) * 2
  toon(function()
    -- Feet.
    toon.ellipse(cx - 12, cy + 32, 9, 5, PIKA)
    toon.ellipse(cx + 12, cy + 32, 9, 5, PIKA)
    -- Plump pear body.
    toon.ellipse(cx, cy + 12, 22, 23, PIKA)
    -- Cute little paws.
    toon.ellipse(cx - 18, cy + 6 + (bow and -6 or 0), 7, 5, PIKA)
    toon.ellipse(cx + 18, cy + 6 + (bow and -6 or 0), 7, 5, PIKA)
    -- Long pointed ears.
    toon.tri(cx - 18, hy - 8, cx - 34 + ear_w, hy - 42, cx - 5, hy - 16, PIKA)
    toon.tri(cx + 18, hy - 8, cx + 34 - ear_w, hy - 42, cx + 5, hy - 16, PIKA)
    -- Round head.
    toon.ellipse(cx, hy, 22, 19, PIKA)
  end, 2.5, INK)
  -- Dark ear tips.
  gfx.tri(cx - 25 + ear_w * 0.5, hy - 25, cx - 34 + ear_w, hy - 42, cx - 16 + ear_w * 0.3, hy - 26, INK)
  gfx.tri(cx + 25 - ear_w * 0.5, hy - 25, cx + 34 - ear_w, hy - 42, cx + 16 - ear_w * 0.3, hy - 26, INK)
  -- Soft belly highlight.
  gfx.ellipse(cx, cy + 16, 12, 12, alpha(0xfff4b0, 120))
  -- Face: eyes, rosy electric cheeks, nose, smile.
  if bow or (S.boss == "pika" and S.dizzy_t > 0) then
    if S.boss == "pika" and S.dizzy_t > 0 then
      for k = 0, 2 do
        local a = fr() * 0.16 + k * 2.09
        gfx.star(cx + cos(a) * 22, hy - 24 + sin(a) * 6, 4, a, GOLD)
      end
    end
    -- Happy arc eyes (^ ^).
    gfx.line(cx - 12, hy - 2, cx - 8, hy - 6, 2.5, INK)
    gfx.line(cx - 8, hy - 6, cx - 4, hy - 2, 2.5, INK)
    gfx.line(cx + 4, hy - 2, cx + 8, hy - 6, 2.5, INK)
    gfx.line(cx + 8, hy - 6, cx + 12, hy - 2, 2.5, INK)
  else
    local look = clamp((S.nx - cx) * 0.015, -2, 2)
    gfx.circle(cx - 9 + look, hy - 3, 4.2, INK)
    gfx.circle(cx + 9 + look, hy - 3, 4.2, INK)
    gfx.circle(cx - 10 + look, hy - 4.5, 1.6, C.WHITE)
    gfx.circle(cx + 8 + look, hy - 4.5, 1.6, C.WHITE)
  end
  -- Rosy red electric cheeks!
  gfx.circle_o(cx - 15, hy + 5, 5.2, C.CHEEK, INK, 1.4)
  gfx.circle_o(cx + 15, hy + 5, 5.2, C.CHEEK, INK, 1.4)
  if charging then
    local g = 150 + floor(sin(fr() * 0.6) * 80)
    gfx.glow(cx - 15, hy + 5, 18, alpha(PIKA, g))
    gfx.glow(cx + 15, hy + 5, 18, alpha(PIKA, g))
    if fr() % 4 == 0 then
      particles.spawn(cx + (fr() % 8 == 0 and -16 or 16), hy + 5, rnd(-1.8, 1.8), rnd(-1.5, 1.5), 14, 2.5, PIKA, "star")
    end
  end
  -- Tiny nose & "w" smile.
  gfx.tri(cx - 2, hy + 2, cx + 2, hy + 2, cx, hy + 4.5, INK)
  gfx.line(cx - 4, hy + 7, cx, hy + 9, 1.6, INK)
  gfx.line(cx, hy + 9, cx + 4, hy + 7, 1.6, INK)
  if S.boss == "pika" and S.flinch_t > 0 then gfx.glow(cx, cy, 56, alpha(0xffffff, S.flinch_t * 10)) end
  if show_marks then draw_marks_row(cx, 212) end
end

-- Reflect: a wall of light panels in front of Zam.
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

-- Pika's Lightning Strike: warning ring on the grass, then a bright bolt from the sky!
local function draw_strike()
  local st = P.S.strike
  if not st then return end
  if st.t > 0 then
    local k = 1 - st.t / 68
    local pulse = 0.6 + 0.4 * sin(fr() * 0.5)
    gfx.circle(st.x, st.y, 32, alpha(C.PURPLE, floor(30 + k * 65)))
    gfx.ring(st.x, st.y, 34, 3, alpha(C.PURPLE, floor(130 + 110 * pulse)))
    gfx.ring(st.x, st.y, 34 * (1 - k * 0.85), 2, alpha(C.PIKA, floor(140 + k * 100)))
    gfx.star(st.x, st.y, 6 + k * 5, fr() * 0.15, C.PIKA)
  elseif st.flash > 0 then
    local k = st.flash / 16
    local x, y = st.x, st.y
    -- Zig-zag bolt from top of screen down to the ring!
    local pts = {
      {x - 6, 0}, {x + 12, y * 0.28}, {x - 10, y * 0.52}, {x + 10, y * 0.78}, {x, y},
    }
    for i = 1, #pts - 1 do
      gfx.line(pts[i][1], pts[i][2], pts[i + 1][1], pts[i + 1][2], 14 * k + 3, alpha(C.PURPLE, floor(170 * k)))
      gfx.line(pts[i][1], pts[i][2], pts[i + 1][1], pts[i + 1][2], 7 * k + 2, alpha(C.PIKA, floor(240 * k)))
      gfx.line(pts[i][1], pts[i][2], pts[i + 1][1], pts[i + 1][2], 3 * k + 1, alpha(C.WHITE, floor(255 * k)))
    end
    gfx.glow(x, y, 48 * k + 10, alpha(C.PIKA, floor(220 * k)))
  end
end

local function draw_ned()
  local S = P.S
  local victory = S.phase == "winbow"
  local sword = S.has_sword and S.phase ~= "path" and S.phase ~= "pop"
  local step = S.moving and sin(S.walk_t * 0.35) or 0
  local hop_y = victory and -abs(sin(fr() * 0.14)) * 10 or 0
  local x, y = S.nx, S.ny + hop_y
  local fx, fy = S.face_x, (S.face_x == 0 and S.face_y == 0) and -1 or S.face_y
  if victory then fx, fy = 0, 1 end
  if S.hurt_cool > 0 and S.stuck == 0 and idiv(S.hurt_cool, 4) % 2 == 1 then return end
  if sword and not S.moving and not victory then fx, fy = 0, -1 end
  gfx.ellipse(S.nx, S.ny + 34, 16, 5, alpha(0x2a5a2a, 110))
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
    if victory or S.cheer > 0 then
      -- Big joyful eyes and open grin!
      gfx.line(x - 7, y - 7, x - 4, y - 10, 2, INK)
      gfx.line(x - 4, y - 10, x - 1, y - 7, 2, INK)
      gfx.line(x + 1, y - 7, x + 4, y - 10, 2, INK)
      gfx.line(x + 4, y - 10, x + 7, y - 7, 2, INK)
      gfx.ellipse(x - 8, y - 3, 3.5, 2, alpha(0xff8fa0, 160))
      gfx.ellipse(x + 8, y - 3, 3.5, 2, alpha(0xff8fa0, 160))
      gfx.ellipse(x, y - 1, 4, 3, INK)
    elseif fr() % 160 < 6 then
      gfx.line(x - 6 + ex, y - 8, x - 2 + ex, y - 8, 2, INK)
      gfx.line(x + 2 + ex, y - 8, x + 6 + ex, y - 8, 2, INK)
      gfx.ellipse(x - 8 + ex, y - 3, 3, 2, alpha(0xff8fa0, 120))
      gfx.ellipse(x + 8 + ex, y - 3, 3, 2, alpha(0xff8fa0, 120))
      gfx.line(x - 3 + ex, y - 2, x + 3 + ex, y - 2, 1.5, INK)
    else
      gfx.circle(x - 4 + ex, y - 8, 2.2, INK)
      gfx.circle(x + 4 + ex, y - 8, 2.2, INK)
      gfx.ellipse(x - 8 + ex, y - 3, 3, 2, alpha(0xff8fa0, 120))
      gfx.ellipse(x + 8 + ex, y - 3, 3, 2, alpha(0xff8fa0, 120))
      gfx.line(x - 3 + ex, y - 2, x + 3 + ex, y - 2, 1.5, INK)
    end
  end
  if not sword and (S.phase == "path" or S.phase == "pop") then
    -- The bubble wand, in his other hand.
    gfx.line(x - 14, y + 10, x - 18, y - 8, 5, INK)
    gfx.line(x - 14, y + 10, x - 18, y - 8, 2.5, 0xb07a50)
    gfx.ring(x - 19, y - 15, 7, 4.5, INK)
    gfx.ring(x - 19, y - 15, 7, 2, C.AQUA)
  end
  if S.has_key and not sword and S.phase == "path" then
    gfx.glow(x + 14, y + 4, 12, alpha(0xffe080, 120))
    gfx.rrect_o(x + 12, y - 2, 5, 14, 2, GOLD, INK, 1.5)
    gfx.circle_o(x + 14.5, y - 4, 4.5, GOLD, INK, 1.5)
  end
  if victory then
    -- Held high overhead in triumph!
    local sx, sy = x + 16, y - 16
    local tx, ty = sx + 4, sy - 34
    gfx.line(sx, sy, tx, ty, 9, INK)
    gfx.line(sx, sy, tx, ty, 5, GOLD)
    gfx.line(sx - 7, sy - 2, sx + 7, sy - 2, 6, INK)
    gfx.line(sx - 6, sy - 2, sx + 6, sy - 2, 3.5, C.BROWN)
    gfx.glow(tx, ty, 16, alpha(0xffe080, 170))
    gfx.star(tx, ty, 6, fr() * 0.1, GOLD)
  elseif sword or (S.phase == "pop" and S.pop_t > 30) then
    -- The sword points at the active boss by itself.
    local bx = S.boss == "pika" and S.px or S.zx
    local by = S.boss == "pika" and S.py or S.zy
    local dx, dy = bx - x, by - (y - 4)
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
  if S.phase ~= "pop" and S.phase ~= "pikapop" and S.phase ~= "zambow" and not victory then
    for i = 0, 2 do
      local px, py = x - 16 + i * 16, y - 46
      gfx.circle(px, py, 6, INK)
      gfx.circle(px, py, 4.5, i < S.pips and C.ROSE or alpha(0xfff6ea, 230))
      gfx.circle(px - 1.5, py - 1.5, 1.4, alpha(0xffffff, 200))
    end
  end
end

-- Kid-friendly accomplished victory banner!
local function draw_victory_banner()
  local S = P.S
  local k = ease.out_back(clamp(S.bow_t / 32, 0, 1))
  local by = lerp(-70, 224, k)
  local bw, bh = 316, 86
  local bx = (W - bw) / 2
  -- Soft glow + cream medal card.
  gfx.glow(W / 2, by + bh / 2, 130 * k, alpha(0xffe080, 95))
  gfx.rrect_o(bx, by, bw, bh, 14, C.CREAM, INK, 3)
  gfx.rrect(bx + 5, by + 5, bw - 10, bh - 10, 10, 0xfff0d0)
  -- Turning corner stars.
  gfx.star(bx + 18, by + 20, 8, fr() * 0.08, GOLD)
  gfx.star(bx + bw - 18, by + 20, 8, -fr() * 0.08, GOLD)
  gfx.text("YOU DID IT!", W / 2, by + 10, 30, GOLD, "center", INK)
  local sub = S.gems == 1 and "1 TREASURE WON!" or (S.gems .. " TREASURES WON!")
  gfx.text(sub, W / 2, by + 48, 16, C.PURPLE, "center", C.CREAM)
  -- Prompt after 2 seconds so he can soak in the win, then tap to play again.
  if S.bow_t >= S.WIN_MIN_FRAMES and blink(46, 30) then
    gfx.rrect_o(W / 2 - 114, 426, 228, 30, 12, C.GOLD, INK, 2)
    gfx.text("PRESS TO PLAY AGAIN!", W / 2, 432, 15, INK, "center")
  end
end

-- ------------------------------------------------------------------ the treasure room
-- A little gold fairy with no particles (the room draws it many times).
local function mini_fairy(x, y, s, c)
  local wing = abs(sin(fr() * 0.4 + x)) * 2 * s
  gfx.ellipse(x - 6 * s, y - 2 * s, 4 * s, 2.5 * s + wing, alpha(0xffffff, 230))
  gfx.ellipse(x + 6 * s, y - 2 * s, 4 * s, 2.5 * s + wing, alpha(0xffffff, 230))
  gfx.circle_o(x, y, 5 * s, c, INK, 1.5)
  gfx.circle(x - 1.6 * s, y - 0.6 * s, 0.9 * s, INK)
  gfx.circle(x + 1.6 * s, y - 0.6 * s, 0.9 * s, INK)
end

-- A music note: a head and a stem.
local function note_glyph(x, y, col, s)
  gfx.line(x + 4 * s, y, x + 4 * s, y - 14 * s, 2.2 * s + 1, INK)
  gfx.ellipse(x, y, 5 * s + 1.5, 3.5 * s + 1.5, INK)
  gfx.line(x + 4 * s, y, x + 4 * s, y - 14 * s, 2.2 * s, col)
  gfx.ellipse(x, y, 5 * s, 3.5 * s, col)
end

local PLATE, WOOD_D = 0xf3e2bc, 0x6e4426
local function draw_room()
  local S = P.S
  local t = S.room_t
  local k
  if S.room_out > 0 then k = 1 - clamp((t - S.room_out) / 18, 0, 1) else k = ease.out_back(clamp(t / 22, 0, 1)) end
  if k <= 0.01 then return end
  local y0 = 6 - (1 - k) * 132
  local fresh = S.fresh
  gfx.rrect_o(8, y0, 368, 118, 12, WOOD_D, INK, 3)
  gfx.rrect(14, y0 + 6, 356, 106, 9, PLATE)
  gfx.text(fresh and "ZAM'S TREASURE" or "NED'S TREASURE ROOM", W / 2, y0 + 8, 14, WOOD_D, "center")
  local latest = (S.gems - 1) % 9
  for i = 0, 8 do
    local cx, cy = 38 + i * 38.5, y0 + 46
    local own = S.gems > i
    gfx.rrect_o(cx - 17, cy - 17, 34, 34, 6, own and 0x7a4c2a or 0x9a7a58, INK, 2)
    gfx.rrect(cx - 14, cy - 14, 28, 28, 4, own and 0x5a3820 or 0x7e6444)
    if own then
      if i == latest then
        gfx.glow(cx, cy, 24, alpha(0xffe080, 110 + floor(beat() * 60)))
        gfx.star(cx + cos(fr() * 0.05) * 15, cy - 14 + sin(fr() * 0.05) * 3, 4, fr() * 0.1, GOLD)
      end
      P.treasure(i, cx, cy + sin(fr() * 0.06 + i) * 1.5, 1.5)
      local n = idiv(S.gems - 1 - i, 9) + 1
      if n > 1 then gfx.text("x" .. min(n, 99), cx + 15, cy + 8, 12, C.CREAM, "right", INK) end
    else
      gfx.text("?", cx, cy - 11, 22, alpha(0xf3e2bc, 90 + floor(sin(fr() * 0.07 + i) * 30)), "center")
    end
  end
  local ry = y0 + 84
  if fresh then
    -- The story, in three pictures: the key, the chest, the treasure.
    gfx.ring(60, ry - 2, 8, 3, INK) gfx.ring(60, ry - 2, 8, 1.8, GOLD)
    gfx.rrect_o(57, ry + 3, 6, 15, 2, GOLD, INK, 1.5)
    gfx.line(100, ry + 8, 140, ry + 8, 3, WOOD_D) gfx.tri(140, ry + 1, 150, ry + 8, 140, ry + 15, WOOD_D)
    gfx.rrect_o(170, ry + 4, 44, 18, 4, C.WOOD, INK, 2)
    gfx.rrect_o(167, ry - 6, 50, 12, 6, 0xd0904e, INK, 2)
    gfx.rect(188, ry + 6, 8, 8, GOLD)
    gfx.line(234, ry + 8, 274, ry + 8, 3, WOOD_D) gfx.tri(274, ry + 1, 284, ry + 8, 274, ry + 15, WOOD_D)
    P.treasure(0, 316, ry + 6 + sin(fr() * 0.1) * 2, 1.7)
    gfx.star(338, ry - 4, 5, fr() * 0.1, GOLD)
  else
    -- Fairies he has turned gold (a lantern each, up to eight), his best run of zaps as a stair of notes, and
    -- a rosette for each duel won without a hurt (up to five). Each is a faint frame until he has one.
    local fr_n, run_n, clean_n = min(S.rescued, 8), min(S.best_run, 7), min(S.clean, 5)
    for i = 0, 7 do
      local x, y = 28 + i * 17, ry + 4 + sin(fr() * 0.06 + i) * 2
      if i < fr_n then mini_fairy(x, y, 1.15, GOLD) else gfx.circle(x, y, 4, alpha(0x9a7a58, 110)) end
    end
    if S.rescued > 8 then gfx.text("+" .. min(S.rescued - 8, 999), 166, ry + 12, 11, WOOD_D, "left") end
    for i = 0, 6 do
      local x, h = 202 + i * 11, 6 + i * 3
      local lit = i < run_n
      gfx.rect(x - 4, ry + 24 - h, 9, h, lit and INK or alpha(0x9a7a58, 110))
      if lit then gfx.rect(x - 3, ry + 25 - h, 7, h - 2, hsv(i / 8, 0.55, 1)) end
    end
    for i = 0, 4 do
      local x = 296 + i * 15
      if i < clean_n then
        gfx.tri(x - 5, ry + 14, x - 1, ry + 14, x - 6, ry + 24, C.ROSE)
        gfx.tri(x + 5, ry + 14, x + 1, ry + 14, x + 6, ry + 24, C.BLUE)
        gfx.circle_o(x, ry + 8, 6, C.PIKA, INK, 1.5)
        gfx.star(x, ry + 8, 3, 0, C.WHITE)
      else
        gfx.circle(x, ry + 8, 4, alpha(0x9a7a58, 110))
      end
    end
  end
end

-- His run of zaps as a little rising stair at the top right: a note lit for each, round the seven.
local function draw_run()
  local S = P.S
  if S.run < 1 or (S.phase ~= "fight" and S.phase ~= "pika") then return end
  if S.run_left < 24 and fr() % 8 < 4 then return end
  local n = (S.run - 1) % 7 + 1
  for i = 0, 6 do
    local x, h = 296 + i * 11, 6 + i * 3
    gfx.rect(x - 4, 44 - h, 9, h, i < n and INK or alpha(0x2a1a34, 110))
    if i < n then gfx.rect(x - 3, 45 - h, 7, h - 2, hsv(i / 8, 0.55, 1)) end
  end
  if S.run >= 7 then gfx.glow(296 + (n - 1) * 11, 44 - (6 + (n - 1) * 3), 14, alpha(0xffe080, 160)) end
end

function P.draw()
  local S = P.S
  local ZX, ZY, PY = S.ZX, S.ZY, S.PY
  local flash = S.spoon_flash > 0
  backdrop("ground", paint_ground)
  draw_pile()
  local on_path = S.phase == "path" or S.phase == "pathback"
  draw_chest_box(not on_path)
  if not S.has_key then draw_key(S.key_x, S.key_y) end

  -- Boss rendering by phase.
  if S.phase == "pop" then
    local k = ease.out_back(clamp(S.pop_t / 40, 0, 1))
    draw_zam(ZX, 150 - 32 * k, flash, false, false)
    if S.pop_t > 4 and S.pop_t < 34 then
      local t = (S.pop_t - 4) / 30
      local sx, sy = lerp(ZX + 40, S.nx, t), lerp(ZY - 40, S.ny - 10, t) - sin(t * math.pi) * 80
      gfx.glow(sx, sy, 16, alpha(0xffe080, 200))
      gfx.star(sx, sy, 8, fr() * 0.4, GOLD)
    end
  elseif S.phase == "fight" or (S.phase == "restart" and S.boss == "zam") then
    draw_zam(S.zx, S.zy, flash, S.phase == "restart", S.phase == "fight")
  elseif S.phase == "zambow" then
    draw_zam(S.zx, S.zy, flash, true, false)
  elseif S.phase == "pikapop" then
    local k = ease.out_back(clamp(S.pop_t / 38, 0, 1))
    -- Zam drifts gently off to the left as Pika springs out!
    local zx = lerp(S.zx, 68, clamp(S.pop_t / 35, 0, 1))
    draw_zam(zx, S.zy - 8, false, true, false)
    local py = lerp(172, PY, k) - sin(clamp(S.pop_t / 38, 0, 1) * math.pi) * 34
    draw_pika(ZX, py, false, false)
  elseif S.phase == "pika" or (S.phase == "restart" and S.boss == "pika") then
    draw_pika(S.px, S.py, S.phase == "restart", S.phase == "pika")
  elseif S.phase == "winbow" then
    -- Both bosses bow and cheer together!
    draw_zam(S.zx, S.zy, false, true, false)
    draw_pika(S.px, S.py, true, false)
  end

  if S.shield_t > 0 and S.phase == "fight" then draw_shield(S.zx, S.zy) end
  if S.wrap > 0 then
    local bx = S.boss == "pika" and S.px or S.zx
    local by = S.boss == "pika" and S.py or S.zy
    soap(bx, by, (S.boss == "pika" and 56 or 76) + sin(fr() * 0.15) * 3, GOLD)
  end
  if S.strike then draw_strike() end
  if S.star then
    gfx.glow(S.star.x, S.star.y, 22, alpha(0xffe080, 160))
    gfx.star(S.star.x, S.star.y, 11, fr() * 0.05, INK)
    gfx.star(S.star.x, S.star.y, 9, fr() * 0.05, GOLD)
  end
  if S.telegraph > 0 and S.phase == "fight" then
    gfx.ring(S.nx, S.ny + 20, 30 + (30 - S.telegraph), 2, alpha(0x7a5af5, 60 + S.telegraph * 4))
  end
  -- His gold friends, following a little behind him (or dancing in a circle on victory).
  for k = 1, min(S.friends, 5) do
    local p = S.trail[k]
    local fx, fy = p and p[1] or S.nx, p and p[2] or S.ny
    draw_fairy(fx + sin(fr() * 0.05 + k) * 4, fy + sin(fr() * 0.07 + k * 2) * 4 - beat(k * 2) * 3, GOLD, false, nil, 1.2 + beat(k * 2) * 0.16)
  end
  draw_ned()
  if S.cheer > 0 and S.phase ~= "winbow" then
    local a = min(S.cheer, 30) / 30
    note_glyph(S.nx - 18, S.ny - 62 - sin(fr() * 0.15) * 4 - (1 - a) * 10, hsv((fr() * 0.01) % 1, 0.5, 1), 0.8)
    note_glyph(S.nx + 12, S.ny - 70 - sin(fr() * 0.15 + 2) * 4 - (1 - a) * 10, GOLD, 0.8)
  end
  if S.oops > 0 then
    for i = 0, 2 do
      local a = fr() * 0.2 + i * 2.1
      gfx.star(S.nx + cos(a) * 18, S.ny - 56 + sin(a) * 5, 4, a, C.PIKA)
    end
  end
  if S.stuck > 0 then soap(S.nx, S.ny, 34 + sin(fr() * 0.3) * 2, C.PURPLE) end
  -- The purple fairies on the path; one being rescued spins in his bubble and turns gold.
  for _, f in ipairs(S.foes) do
    if f.state == "saving" then
      local k = 1 - f.save_t / S.SAVE_FRAMES
      draw_fairy(f.x + sin(fr() * 0.6) * 3, f.y, k < 0.5 and C.PURPLE or GOLD, false, nil, 1.5)
      soap(f.x, f.y, 26 + k * 6, C.AQUA)
    else
      draw_fairy(f.x, f.y, C.PURPLE, false, f.tele > 0 and 1 - f.tele / S.PUFF_FRAMES or nil, 1.5)
    end
  end
  -- What the next wand bubble will go for: four little gold stars turning round it.
  local aim = S.aim
  if aim then
    for k = 0, 3 do
      local a = fr() * 0.08 + k * 1.571
      gfx.star(aim.x + cos(a) * 28, aim.y + sin(a) * 28, 6, a, INK)
      gfx.star(aim.x + cos(a) * 28, aim.y + sin(a) * 28, 4.5, a, GOLD)
    end
  end
  for _, s in ipairs(S.shots) do
    soap(s.x, s.y, 12, C.AQUA)
    gfx.circle(s.x + 3, s.y + 3, 1.6, alpha(0xffffff, 180))
  end
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
  for _, b in ipairs(S.bubbles) do
    if b.spark then
      gfx.glow(b.x, b.y, 20, alpha(C.PURPLE, 160))
      soap(b.x, b.y, 12, C.PURPLE)
      gfx.star(b.x, b.y, 7, fr() * 0.25, C.PIKA)
    else
      soap(b.x, b.y, 13, C.PURPLE)
    end
  end
  local beam = S.beam
  if beam and beam.t > 0 then
    local k = beam.t / 10
    local core = beam.blocked and C.CYAN or GOLD
    gfx.line(beam.x0, beam.y0, beam.x1, beam.y1, (S.has_sword and 10 or 6) * k + 2, alpha(core, floor(160 * k)))
    gfx.line(beam.x0, beam.y0, beam.x1, beam.y1, (S.has_sword and 4 or 2.5) * k + 1, alpha(C.WHITE, floor(255 * k)))
    gfx.glow(beam.x1, beam.y1, 18 * k + 4, beam.blocked and alpha(0x7fe8ff, 200) or alpha(0xffe080, 200))
    beam.t = beam.t - 1
  end
  draw_run()
  if S.phase == "winbow" then draw_victory_banner() end
  if S.prize_t > 0 then
    local t = clamp(S.prize_t / 60, 0, 1)
    local px, py = P.pile_slot(min(S.gems - 1, PILE_SHOWN - 1))
    local x, y = lerp(ZX, px, t), lerp(160, py, t) - sin(t * math.pi) * 70
    gfx.glow(x, y, 20, alpha(0xffe080, 200))
    P.treasure(S.prize_kind, x, y, 1 + (1 - t) * 1.5)
  end
  if S.room_t < 400 then draw_room() end
end

return P
