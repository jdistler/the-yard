-- Handcrafted retro-arcade visuals for Chomp! (Pac-Man homage):
-- 3 cached neon double-line maze themes, glowing Power Pellets, Chompy with directional mouth
-- & golden turbo/power aura, 4 expressive ghosts (normal / frightened-blue / floating eyes),
-- 5 handcrafted bonus fruits, and arcade HUD.

local P = {}

local C = {
  BG = 0x101024, CREAM = 0xfff6ea, INK = 0x201830, GOLD = 0xffdc36,
  DOT = 0xffe4b8, WHITE = 0xfffcf8, RED = 0xf03c4c, PINK = 0xff88cc,
  CYAN = 0x4ae8ff, ORANGE = 0xffa438, BLUE = 0x2e58ff, FRIGHT = 0x2a44f0,
  GREEN = 0x52dc78, PURPLE = 0x9c5cf8, ROSE = 0xf2588c,
}
P.C = C

-- 3 classic neon maze color palettes (re-painted onto a single reusable 768 KB layer).
local THEMES = {
  {name = "Neon Blue",     wall = 0x2e64ff, inner = 0x142266, glow = 0x5c96ff, bg = 0x0d0e22},
  {name = "Emerald Maze",  wall = 0x2ee084, inner = 0x10442c, glow = 0x74ffba, bg = 0x0b1816},
  {name = "Starlight Plum",wall = 0xe84cf0, inner = 0x481652, glow = 0xff94ff, bg = 0x160c20},
}
P.THEMES = THEMES

local bg_layer, bg_key = nil, ""

local function paint_maze(S, theme_idx, flash_white)
  local T = THEMES[theme_idx]
  gfx.rect(0, 0, W, H, T.bg)
  local ox, oy, ts = S.OX, S.OY, S.TS
  local wcol = flash_white and C.WHITE or T.wall
  local icol = flash_white and 0x8cb8ff or T.inner

  -- Outer glowing arcade border
  gfx.rrect_o(ox - 5, oy - 5, S.COLS * ts + 10, S.ROWS * ts + 10, 10, T.bg, wcol, 3)

  -- Neon double-line maze walls!
  for r = 1, S.ROWS do
    for c = 1, S.COLS do
      if S.grid[r][c] == "#" then
        local x, y = ox + (c - 1) * ts, oy + (r - 1) * ts
        gfx.rrect_o(x + 2, y + 2, ts - 4, ts - 4, 6, icol, wcol, 2.2)
        gfx.rrect(x + 6, y + 6, ts - 12, ts - 12, 3, T.bg)
      elseif S.grid[r][c] == "=" then
        -- Iconic pink Ghost House gate!
        local x, y = ox + (c - 1) * ts, oy + (r - 1) * ts
        gfx.rect(x, y + ts * 0.4, ts, 5, C.PINK)
      end
    end
  end

  -- Side warp tunnel glow chevrons
  local wy = oy + (S.WARP_ROW - 0.5) * ts
  gfx.rrect(0, wy - ts * 0.45, ox + 2, ts * 0.9, 2, T.bg)
  gfx.rrect(W - ox - 2, wy - ts * 0.45, ox + 2, ts * 0.9, 2, T.bg)
end

local function ensure_bg(S, flash_white)
  local tidx = ((S.stage - 1) % #THEMES) + 1
  local key = tidx .. ":" .. (flash_white and "1" or "0") .. ":" .. S.maze_id
  if not bg_layer then bg_layer = gfx.layer(W, H) end
  if bg_key ~= key then
    bg_key = key
    bg_layer:paint(function() paint_maze(S, tidx, flash_white) end)
  end
end

-- ------------------------------------------------------------------ Chompy (Pac-Man homage)
local function draw_chompy(S)
  local x, y = S.px, S.py
  local r = 11.5
  local power = S.power_t > 0
  local dash = S.dash_t > 0
  if power or dash then
    gfx.glow(x, y, 26, alpha(power and C.CYAN or C.GOLD, 130))
  end
  if S.hurt_cool > 0 and game.frame % 6 < 3 then
    gfx.circle_o(x, y, r + 4, alpha(C.CYAN, 60), C.WHITE, 1.5)
  end
  local chomp = (S.moving or power) and (0.12 + abs(sin(S.walk_t * 0.45)) * 0.52) or 0.22
  local dx, dy = S.fx, S.fy
  if dx == 0 and dy == 0 then dx = 1 end

  gfx.circle_o(x, y, r, C.GOLD, C.INK, 1.8)
  -- Directional chomping mouth wedge!
  local m = r * 1.15
  local w = r * chomp * 1.15
  local T = THEMES[((S.stage - 1) % #THEMES) + 1]
  if dx > 0 then
    gfx.tri(x, y, x + m, y - w, x + m, y + w, T.bg)
    gfx.circle(x - 1, y - 5.5, 2, C.INK)
    gfx.circle(x - 1.5, y - 6, 0.7, C.WHITE)
  elseif dx < 0 then
    gfx.tri(x, y, x - m, y - w, x - m, y + w, T.bg)
    gfx.circle(x + 1, y - 5.5, 2, C.INK)
    gfx.circle(x + 0.5, y - 6, 0.7, C.WHITE)
  elseif dy < 0 then
    gfx.tri(x, y, x - w, y - m, x + w, y - m, T.bg)
    gfx.circle(x - 5.5, y + 1, 2, C.INK)
    gfx.circle(x - 6, y + 0.5, 0.7, C.WHITE)
  else
    gfx.tri(x, y, x - w, y + m, x + w, y + m, T.bg)
    gfx.circle(x + 5.5, y - 1, 2, C.INK)
    gfx.circle(x + 5, y - 1.5, 0.7, C.WHITE)
  end
end

-- ------------------------------------------------------------------ Classic Arcade Ghosts!
local function draw_ghost(g, power_t)
  local x, y = g.x, g.y
  local r = 11
  local wob = sin(game.frame * 0.3 + g.id * 1.5) * 1.2

  -- Floating eyes returning to Ghost House!
  if g.state == "eyes" then
    for _, sx in ipairs({-3.8, 3.8}) do
      gfx.ellipse_o(x + sx, y - 2, 3.6, 4.4, C.WHITE, C.INK, 1)
      gfx.circle(x + sx + g.dx * 1.6, y - 2 + g.dy * 1.6, 1.8, C.BLUE)
    end
    return
  end

  local fright = (g.state == "fright")
  local blink = fright and power_t < 110 and (floor(power_t / 8) % 2 == 0)
  local body = fright and (blink and C.WHITE or C.FRIGHT) or g.col

  -- Rounded dome + scalloped waving skirt
  gfx.circle(x, y - 2, r, body)
  gfx.rect(x - r, y - 2, r * 2, r * 0.95, body)
  for k = -1, 1 do
    local sx = x + k * (r * 0.66)
    local sy = y + r * 0.72 + ((k % 2 == 0) and wob or -wob)
    gfx.circle(sx, sy, r * 0.37, body)
  end

  if fright then
    local fcol = blink and C.RED or C.CREAM
    gfx.circle(x - 3.6, y - 3, 2, fcol)
    gfx.circle(x + 3.6, y - 3, 2, fcol)
    -- Classic wavy frightened mouth!
    for i = -2, 1 do
      local x0 = x + i * 3.2
      local y0 = y + 3 + (i % 2 == 0 and 0 or -2)
      local y1 = y + 3 + ((i + 1) % 2 == 0 and 0 or -2)
      gfx.line(x0, y0, x0 + 3.2, y1, 1.6, fcol)
    end
  else
    -- Expressive directional eyes!
    for _, sx in ipairs({-3.8, 3.8}) do
      gfx.ellipse(x + sx, y - 2.5, 3.4, 4.2, C.WHITE)
      gfx.circle(x + sx + g.dx * 1.6, y - 2.5 + g.dy * 1.6, 1.8, C.BLUE)
    end
  end
end

-- ------------------------------------------------------------------ Bonus Fruits!
local function draw_fruit(kind, x, y, sc)
  sc = sc or 1
  if kind == 1 then
    -- Cherry!
    gfx.line(x - 4 * sc, y + 2 * sc, x, y - 9 * sc, 1.8 * sc, C.GREEN)
    gfx.line(x + 4 * sc, y + 3 * sc, x, y - 9 * sc, 1.8 * sc, C.GREEN)
    gfx.circle_o(x - 4.5 * sc, y + 3 * sc, 4.5 * sc, C.RED, C.INK, 1.3 * sc)
    gfx.circle_o(x + 4.5 * sc, y + 4 * sc, 4.5 * sc, C.RED, C.INK, 1.3 * sc)
    gfx.circle(x - 6 * sc, y + 1.5 * sc, 1.3 * sc, C.WHITE)
    gfx.circle(x + 3 * sc, y + 2.5 * sc, 1.3 * sc, C.WHITE)
  elseif kind == 2 then
    -- Strawberry!
    gfx.tri(x - 7 * sc, y - 4 * sc, x + 7 * sc, y - 4 * sc, x, y + 9 * sc, C.RED)
    gfx.circle(x, y - 2 * sc, 6.5 * sc, C.RED)
    gfx.ellipse(x, y - 7 * sc, 6 * sc, 2.8 * sc, C.GREEN)
    gfx.circle(x - 2 * sc, y - 1 * sc, 1 * sc, C.GOLD)
    gfx.circle(x + 2 * sc, y + 1 * sc, 1 * sc, C.GOLD)
    gfx.circle(x, y + 4 * sc, 1 * sc, C.GOLD)
  elseif kind == 3 then
    -- Peach!
    gfx.circle_o(x, y + 1 * sc, 7.5 * sc, C.ORANGE, C.INK, 1.4 * sc)
    gfx.ellipse(x + 3 * sc, y - 7 * sc, 4.5 * sc, 2.2 * sc, C.GREEN)
    gfx.circle(x - 2.5 * sc, y - 1.5 * sc, 1.8 * sc, alpha(C.WHITE, 180))
  elseif kind == 4 then
    -- Golden Apple!
    gfx.glow(x, y, 14 * sc, alpha(C.GOLD, 120))
    gfx.circle_o(x, y + 1 * sc, 7.5 * sc, C.GOLD, C.INK, 1.4 * sc)
    gfx.line(x, y - 6 * sc, x + 2 * sc, y - 10 * sc, 2 * sc, 0x8a5828)
    gfx.ellipse(x + 4 * sc, y - 8 * sc, 3.5 * sc, 1.8 * sc, C.GREEN)
  else
    -- Star Melon!
    gfx.glow(x, y, 16 * sc, alpha(C.CYAN, 130))
    gfx.circle_o(x, y, 8 * sc, C.GREEN, C.INK, 1.5 * sc)
    gfx.star(x, y, 4.5 * sc, game.frame * 0.08, C.GOLD)
  end
end

-- ------------------------------------------------------------------ Full Frame Draw
function P.draw()
  local S = P.S
  local flash = (S.phase == "clear") and (floor(S.clear_t / 8) % 2 == 0)
  ensure_bg(S, flash)
  gfx.draw(bg_layer, 0, 0)

  -- Dots & pulsing Power Pellets!
  local ox, oy, ts = S.OX, S.OY, S.TS
  local pulse = 5.2 + sin(game.frame * 0.18) * 1.6
  for r = 1, S.ROWS do
    for c = 1, S.COLS do
      local v = S.dots[r][c]
      if v == 1 then
        gfx.circle(ox + (c - 0.5) * ts, oy + (r - 0.5) * ts, 2.5, C.DOT)
      elseif v == 2 then
        local px, py = ox + (c - 0.5) * ts, oy + (r - 0.5) * ts
        gfx.glow(px, py, 16, alpha(C.GOLD, 120))
        gfx.circle(px, py, pulse, C.GOLD)
        gfx.circle(px, py, pulse * 0.5, C.WHITE)
      end
    end
  end

  -- Bonus Fruit!
  if S.fruit then
    local fy = S.fruit.y + sin(game.frame * 0.14) * 2
    draw_fruit(S.fruit.kind, S.fruit.x, fy, 1.15)
  end

  -- Chompy & Ghosts!
  draw_chompy(S)
  for _, g in ipairs(S.ghosts) do
    draw_ghost(g, S.power_t)
  end

  -- Arcade Top HUD!
  gfx.rrect_o(8, 8, W - 16, 48, 12, 0x1a1834, C.GOLD, 2)
  gfx.text("STAGE " .. S.stage, 20, 13, 13, C.GOLD, "left")
  -- 3 Cozy Hearts!
  for i = 1, 3 do
    local hx = 26 + (i - 1) * 18
    local col = i <= (3 - S.hurts) and C.ROSE or 0x483c5c
    gfx.circle(hx - 3, 38, 3.8, col)
    gfx.circle(hx + 3, 38, 3.8, col)
    gfx.tri(hx - 6.8, 39, hx + 6.8, 39, hx, 46, col)
  end
  -- Turbo Dash Pip (center)!
  local ready = S.dash_cool == 0
  gfx.rrect_o(136, 15, 112, 34, 9, ready and 0x2c2458 or 0x16142a, ready and C.GOLD or 0x585078, 1.6)
  gfx.text(S.dash_t > 0 and "TURBO!" or (ready and "DASH READY" or "CHARGING"), 192, 24, 11,
           ready and C.GOLD or 0x9c92b8, "center")
  -- Score & High Score (right)!
  gfx.text("PTS " .. S.score, W - 18, 13, 13, C.WHITE, "right")
  gfx.text("HI " .. S.hi, W - 18, 32, 12, C.CYAN, "right")

  -- Ready / Stage Clear Banners!
  if S.phase == "ready" then
    gfx.rrect_o(112, 244, 160, 40, 12, alpha(0x14122c, 230), C.GOLD, 2.5)
    gfx.text("READY!", W / 2, 252, 22, C.GOLD, "center", C.INK)
  elseif S.phase == "clear" then
    gfx.rrect_o(46, 212, W - 92, 96, 16, C.CREAM, C.INK, 3)
    gfx.text("MAZE " .. S.stage .. " CLEAR!", W / 2, 226, 22, C.GOLD, "center", C.INK)
    gfx.text("SCORE: " .. S.score, W / 2, 260, 15, C.PURPLE, "center")
    gfx.text("NEXT MAZE COMING UP!", W / 2, 282, 12, C.INK, "center")
  end
end

return P
