-- Pictures for Chomp!: six maze worlds painted onto ONE reused scene layer (repainted in place whenever the world
-- changes: 768 KB for ever, however many mazes are played), the star map (the same layer, a different painting),
-- Chompy with his looks, four ghosts with faces and accessories, five fruits, the HUD, the story and the map.
-- No rnd() in here: scenery is placed with an integer hash, so a frame is the same on every runtime.

local P = {}

local C = {
  BG = 0x101024, CREAM = 0xfff6ea, INK = 0x201830, GOLD = 0xffdc36,
  DOT = 0xffe4b8, WHITE = 0xfffcf8, RED = 0xf03c4c, PINK = 0xff88cc,
  CYAN = 0x4ae8ff, ORANGE = 0xffa438, BLUE = 0x2e58ff, FRIGHT = 0x2a44f0,
  GREEN = 0x52dc78, PURPLE = 0x9c5cf8, ROSE = 0xf2588c,
}
P.C = C

-- kind: the animated scenery that drifts over the corridors (1 twinkles, 2 fireflies, 3 sparkles rising,
-- 4 sprinkles falling, 5 snow, 6 bubbles).
local THEMES = {
  {name = "Night Garden",   wall = 0x2e64ff, inner = 0x142266, bg = 0x0d0e22, acc = 0x9cc4ff, kind = 1},
  {name = "Firefly Meadow", wall = 0x2ee084, inner = 0x10442c, bg = 0x0b1816, acc = 0xd8ff7a, kind = 2},
  {name = "Plum Moonlight", wall = 0xe84cf0, inner = 0x481652, bg = 0x160c20, acc = 0xffb4ff, kind = 3},
  {name = "Candy Lane",     wall = 0xff7ab8, inner = 0x5a2048, bg = 0x1c0f22, acc = 0xffe066, kind = 4},
  {name = "Frost Cave",     wall = 0x7fe6ff, inner = 0x174a5c, bg = 0x08141f, acc = 0xffffff, kind = 5},
  {name = "Coral Reef",     wall = 0xff9a5c, inner = 0x5a2c30, bg = 0x061a30, acc = 0x6fe8ff, kind = 6},
}
P.THEMES = THEMES
P.NTHEMES = #THEMES

local function hs(i, k)   -- a hash in [0, 1): the same on every runtime
  local h = (i * 374761 + k * 668265 + 12345) % 1000003
  return (h * h) % 999983 / 999983
end

-- ------------------------------------------------------------------ the constellation (22 stars: Chompy's face)
local NSTARS = 22
P.NSTARS = NSTARS
local SX, SY = {}, {}
local LA, LB = {}, {}   -- the lines between stars (each one lights when both its ends are lit)
do
  local cx, cy, R = 176, 192, 84
  SX[1], SY[1] = cx + 16, cy - 40          -- the eye
  SX[2], SY[2] = cx, cy                     -- the corner of the mouth
  for k = 0, 16 do   -- the outline, from the top of the mouth round the back to its bottom
    local a = (32 + k * 18.5) * 3.14159265 / 180
    SX[3 + k], SY[3 + k] = cx + cos(a) * R, cy - sin(a) * R
  end
  for k = 1, 3 do SX[19 + k], SY[19 + k] = cx + R + 24 + (k - 1) * 28, cy end   -- the dots he will eat
  local function line(a, b) LA[#LA + 1], LB[#LB + 1] = a, b end
  line(2, 3)
  for k = 3, 18 do line(k, k + 1) end
  line(19, 2) line(2, 20) line(20, 21) line(21, 22)
end
-- Stars are lit in this order: the eye, the mouth, the outline, then the dots.
P.SX, P.SY = SX, SY

-- the shelf's cells
local PANEL_Y = 300
local FRX = {112, 160, 208, 256, 304}

-- ------------------------------------------------------------------ the one scene layer
local bg = nil
local bg_a, bg_b = -1, -1

local function paint_sky()
  gfx.vgrad(0, 0, W, 300, 0x070a22, 0x1e1c58)
  gfx.rect(0, 300, W, H - 300, 0x1e1c58)
  for i = 1, 70 do   -- far stars, fixed
    local x, y = hs(i, 1) * W, hs(i, 2) * 296
    gfx.circle(x, y, 0.8 + hs(i, 3) * 1.1, alpha(0xdfe4ff, floor(50 + hs(i, 4) * 130)))
  end
  gfx.glow(336, 52, 48, alpha(0xfff0c8, 40))       -- the moon
  gfx.circle(336, 52, 24, 0xfff0c8)
  gfx.circle(328, 46, 5, 0xf0dca8)
  gfx.circle(344, 60, 3.4, 0xf0dca8)
  gfx.circle(346, 42, 2.4, 0xf0dca8)
  gfx.rrect_o(10, PANEL_Y, W - 20, 150, 16, 0x15163e, 0xffdc36, 2.5)
end

local function paint_maze(S, tidx)
  local T = THEMES[tidx]
  gfx.rect(0, 0, W, H, T.bg)
  local ox, oy, ts = S.OX, S.OY, S.TS
  local wcol, icol = T.wall, T.inner

  gfx.rrect_o(ox - 5, oy - 5, S.COLS * ts + 10, S.ROWS * ts + 10, 10, T.bg, wcol, 3)

  -- the floor's own little details (corridor cells only), by the world
  local kind = T.kind
  for r = 1, S.ROWS do
    for c = 1, S.COLS do
      if S.grid[r][c] ~= "#" then
        local h = hs(r * 31 + c, tidx)
        if h < 0.4 then
          local x = ox + (c - 0.5) * ts + (hs(r, c + tidx) - 0.5) * 14
          local y = oy + (r - 0.5) * ts + (hs(c, r + tidx) - 0.5) * 14
          if kind == 1 then
            gfx.circle(x, y, 1.1, alpha(T.acc, 60))
          elseif kind == 2 then
            gfx.line(x, y + 3, x - 2, y - 2, 1.2, alpha(0x4ac86a, 110))
            gfx.line(x, y + 3, x + 2, y - 3, 1.2, alpha(0x4ac86a, 110))
          elseif kind == 3 then
            gfx.circle(x, y, 1.6, alpha(T.acc, 45))
            gfx.circle(x, y, 0.7, alpha(C.WHITE, 90))
          elseif kind == 4 then
            local col = ({0xffe066, 0xff7ab8, 0x7ae8ff, 0xb08cff})[floor(h * 10) % 4 + 1]
            gfx.line(x - 2, y - 1, x + 2, y + 1, 2, alpha(col, 120))
          elseif kind == 5 then
            gfx.line(x - 2.5, y, x + 2.5, y, 1, alpha(C.WHITE, 70))
            gfx.line(x, y - 2.5, x, y + 2.5, 1, alpha(C.WHITE, 70))
          else
            gfx.ring(x, y, 2.6, 1, alpha(T.acc, 70))
          end
        end
      end
    end
  end

  -- neon double-line walls, with a touch of the world on each
  for r = 1, S.ROWS do
    for c = 1, S.COLS do
      local ch = S.grid[r][c]
      local x, y = ox + (c - 1) * ts, oy + (r - 1) * ts
      if ch == "#" then
        gfx.rrect_o(x + 2, y + 2, ts - 4, ts - 4, 6, icol, wcol, 2.2)
        gfx.rrect(x + 6, y + 6, ts - 12, ts - 12, 3, T.bg)
        local h = hs(r * 17 + c, tidx + 9)
        if kind == 2 and h < 0.5 then
          gfx.ellipse(x + 12, y + 12, 3.6, 1.8, alpha(0x74ffba, 150))
        elseif kind == 3 and h < 0.5 then
          gfx.circle(x + 12, y + 12, 1.6, alpha(0xffd0ff, 190))
        elseif kind == 4 then
          gfx.line(x + 7, y + 17, x + 17, y + 7, 2, alpha(0xfff0f8, 150))
        elseif kind == 5 and h < 0.6 then
          gfx.tri(x + 12, y + 7, x + 8, y + 15, x + 16, y + 15, alpha(0xffffff, 130))
        elseif kind == 6 and h < 0.6 then
          gfx.ring(x + 12, y + 12, 2.6, 1.1, alpha(0x6fe8ff, 170))
        elseif kind == 1 and h < 0.3 then
          gfx.circle(x + 12, y + 12, 1.3, alpha(0xdfe8ff, 190))
        end
      elseif ch == "=" then
        gfx.rect(x, y + ts * 0.4, ts, 5, C.PINK)
      end
    end
  end

  -- side warp tunnel
  local wy = oy + (S.WARP_ROW - 0.5) * ts
  gfx.rrect(0, wy - ts * 0.45, ox + 2, ts * 0.9, 2, T.bg)
  gfx.rrect(W - ox - 2, wy - ts * 0.45, ox + 2, ts * 0.9, 2, T.bg)
end

-- Repainted in place when the picture changes (a = 0 for the sky, else the world; b = the maze).
local function scene(a, b, S)
  if not bg then bg = gfx.layer(W, H) end
  if bg_a ~= a or bg_b ~= b then
    bg_a, bg_b = a, b
    if a == 0 then bg:paint(paint_sky) else bg:paint(function() paint_maze(S, a) end) end
  end
  gfx.blit(bg, 0, 0)
end

-- the scenery that moves over the corridors (a few glows and circles, no tables)
local function draw_decor(tidx)
  local f = game.frame
  local kind = THEMES[tidx].kind
  for i = 1, 7 do
    local bx, by = 30 + hs(i, 11 + tidx) * (W - 60), 84 + hs(i, 12 + tidx) * 360
    if kind == 1 then
      local tw = 0.5 + 0.5 * sin(f * 0.06 + i * 2.3)
      gfx.glow(bx, by, 5 + tw * 5, alpha(0xbcd4ff, floor(30 + tw * 70)))
    elseif kind == 2 then
      local x, y = bx + sin(f * 0.012 + i) * 16, by + cos(f * 0.016 + i * 1.7) * 12
      local tw = 0.5 + 0.5 * sin(f * 0.07 + i * 3)
      gfx.glow(x, y, 7 + tw * 4, alpha(0xe4ff70, floor(40 + tw * 90)))
    elseif kind == 3 then
      local y = 456 - (f * 0.25 + hs(i, 3) * 380) % 380
      gfx.glow(bx + sin(f * 0.02 + i) * 8, y, 5, alpha(0xffb4ff, 80))
    elseif kind == 4 then
      local y = 72 + (f * 0.5 + hs(i, 3) * 384) % 384
      local col = i % 3 == 0 and 0xffe066 or (i % 3 == 1 and 0x7ae8ff or 0xff9ed0)
      gfx.circle(bx, y, 2, alpha(col, 150))
    elseif kind == 5 then
      local y = 72 + (f * 0.45 + hs(i, 3) * 384) % 384
      gfx.circle(bx + sin(f * 0.03 + i) * 10, y, 1.8, alpha(0xffffff, 150))
    else
      local y = 456 - (f * 0.35 + hs(i, 3) * 384) % 384
      gfx.ring(bx + sin(f * 0.04 + i) * 6, y, 3 + hs(i, 5) * 2.5, 1, alpha(0x9ff0ff, 120))
    end
  end
end

-- ------------------------------------------------------------------ Chompy
-- x, y; dx, dy his way; chomp 0.1..0.6 the mouth; mood: 0 plain, 1 power (brave brows), 2 ouch, 3 happy (closed
-- eyes); look 0..3 what he has earned: a bow, a cap with a star, a crown; bgc the colour of the mouth's hole.
local CROWN = {0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0}
local function draw_chompy_at(x, y, dx, dy, chomp, mood, look, bgc, glowc)
  local r = 11.5
  if glowc then gfx.glow(x, y, 26, alpha(glowc, 130)) end
  gfx.circle_o(x, y, r, C.GOLD, C.INK, 1.8)
  if dx == 0 and dy == 0 then dx = 1 end
  local m, w = r * 1.15, r * chomp * 1.15
  local ex, ey
  if dx > 0 then
    gfx.tri(x, y, x + m, y - w, x + m, y + w, bgc); ex, ey = x - 1, y - 5.5
  elseif dx < 0 then
    gfx.tri(x, y, x - m, y - w, x - m, y + w, bgc); ex, ey = x + 1, y - 5.5
  elseif dy < 0 then
    gfx.tri(x, y, x - w, y - m, x + w, y - m, bgc); ex, ey = x - 5.5, y + 1
  else
    gfx.tri(x, y, x - w, y + m, x + w, y + m, bgc); ex, ey = x + 5.5, y - 1
  end
  -- cheek
  gfx.circle(x - dx * 4 + (dy ~= 0 and 5 or 0), y + (dx ~= 0 and 3.5 or -dy * 4), 2.6, alpha(C.ROSE, 120))
  -- the eye
  if mood == 3 then
    gfx.line(ex - 2.4, ey + 0.8, ex, ey - 1, 1.4, C.INK)
    gfx.line(ex, ey - 1, ex + 2.4, ey + 0.8, 1.4, C.INK)
  elseif mood == 2 then
    gfx.line(ex - 2, ey - 2, ex + 2, ey + 2, 1.5, C.INK)
    gfx.line(ex - 2, ey + 2, ex + 2, ey - 2, 1.5, C.INK)
  else
    gfx.circle(ex, ey, 2, C.INK)
    gfx.circle(ex - 0.5, ey - 0.5, 0.7, C.WHITE)
    if mood == 1 then gfx.line(ex - 3, ey - 3.6 + (dx > 0 and -0.4 or 0.8), ex + 2.6, ey - 3.6 + (dx > 0 and 1.2 or -0.4), 1.5, C.INK) end
  end
  -- what he has earned, on top
  if look >= 1 then
    if look == 1 then       -- a red bow
      gfx.tri(x, y - 11.5, x - 6, y - 16, x - 6, y - 8, C.RED)
      gfx.tri(x, y - 11.5, x + 6, y - 16, x + 6, y - 8, C.RED)
      gfx.circle(x, y - 11.5, 2, 0xffb0b8)
    elseif look == 2 then   -- a blue cap with a star
      gfx.circle_o(x, y - 9, 8, 0x3c6cff, C.INK, 1.4)
      gfx.rect(x - 9, y - 10, 18, 3, 0x2a4ac8)
      gfx.star(x, y - 14, 3.6, 0, C.GOLD)
    else                    -- a golden crown
      local cp = CROWN
      cp[1], cp[2], cp[3], cp[4], cp[5], cp[6], cp[7] = x - 8, y - 9, x - 8, y - 18, x - 4, y - 13, x
      cp[8], cp[9], cp[10], cp[11], cp[12], cp[13], cp[14] = y - 19, x + 4, y - 13, x + 8, y - 18, x + 8, y - 9
      gfx.poly(cp, C.GOLD)
      gfx.circle(x, y - 12, 1.3, C.ROSE)
    end
  end
end

local function draw_chompy(S)
  local power, dash = S.power_t > 0, S.dash_t > 0
  local glowc = power and C.CYAN or (dash and C.GOLD or nil)
  if S.hurt_cool > 0 and game.frame % 6 < 3 then
    gfx.circle_o(S.px, S.py, 15.5, alpha(C.CYAN, 60), C.WHITE, 1.5)
  end
  local chomp = (S.moving or power) and (0.12 + abs(sin(S.walk_t * 0.45)) * 0.52) or 0.22
  local mood = 0
  if S.hurt_cool > 60 then mood = 2 elseif S.whew_t > 0 or S.phase == "clear" then mood = 3 elseif power then mood = 1 end
  draw_chompy_at(S.px, S.py, S.fx, S.fy, chomp, mood, S.look, THEMES[S.theme].bg, glowc)
  if mood == 2 then   -- ouch: three stars go round his head
    for i = 0, 2 do
      local a = game.frame * 0.2 + i * 2.1
      gfx.star(S.px + cos(a) * 14, S.py - 15 + sin(a) * 4, 2.4, a, C.GOLD)
    end
  end
  if S.whew_t > 0 then gfx.text("whew!", S.px, S.py - 30, 12, C.WHITE, "center", C.INK) end
end

-- ------------------------------------------------------------------ the ghosts
-- id 1 Reddy: bold, brows down, steams when close.   2 Rosie: sly, lashes, a bow, winks.
-- id 3 Zippy: giddy, big eyes, a sparking antenna.   4 Goofy: shy, small eyes, a propeller cap, sweats when he runs.
local function draw_ghost_at(g, S, small)
  local x, y = g.x, g.y
  local r = 11
  local id = g.id
  local f = game.frame
  local wob = sin(f * 0.3 + id * 1.5) * (id == 3 and 1.9 or 1.2)

  if g.state == "eyes" then
    gfx.ellipse_o(x - 3.8, y - 2, 3.6, 4.4, C.WHITE, C.INK, 1)
    gfx.circle(x - 3.8 + g.dx * 1.6, y - 2 + g.dy * 1.6, 1.8, C.BLUE)
    gfx.ellipse_o(x + 3.8, y - 2, 3.6, 4.4, C.WHITE, C.INK, 1)
    gfx.circle(x + 3.8 + g.dx * 1.6, y - 2 + g.dy * 1.6, 1.8, C.BLUE)
    return
  end

  local fright = (g.state == "fright")
  local pt = S.power_t
  local blink = fright and pt < 110 and (floor(pt / 8) % 2 == 0)
  local body = fright and (blink and C.WHITE or C.FRIGHT) or g.col
  if fright then x = x + sin(f * 0.9 + id) * 0.8 end   -- trembling

  gfx.circle(x, y - 2, r, body)
  gfx.rect(x - r, y - 2, r * 2, r * 0.95, body)
  for k = -1, 1 do
    gfx.circle(x + k * (r * 0.66), y + r * 0.72 + ((k % 2 == 0) and wob or -wob), r * 0.37, body)
  end

  -- accessories (they stay on when the ghost is blue)
  if id == 1 then
    gfx.tri(x - 6, y - 11, x - 3, y - 19, x - 1, y - 11, body)
    gfx.tri(x - 2, y - 12, x + 1, y - 21, x + 4, y - 12, body)
    gfx.tri(x + 2, y - 11, x + 6, y - 18, x + 8, y - 9, body)
  elseif id == 2 then
    local bc = fright and 0x8aa0ff or 0xff3a9a
    gfx.tri(x + 5, y - 12, x + 11, y - 17, x + 11, y - 8, bc)
    gfx.tri(x + 5, y - 12, x - 1, y - 17, x - 1, y - 8, bc)
    gfx.circle(x + 5, y - 12, 2, fright and C.WHITE or 0xffd0ec)
  elseif id == 3 then
    local tip = sin(f * 0.5) * 2
    gfx.line(x, y - 12, x + 2 + tip * 0.4, y - 17, 1.4, C.INK)
    gfx.line(x + 2 + tip * 0.4, y - 17, x - 1, y - 20, 1.4, C.INK)
    gfx.glow(x - 1, y - 20, 6 + abs(tip), alpha(0xfff060, 150))
    gfx.circle(x - 1, y - 20, 2, 0xfff060)
  else
    gfx.circle_o(x, y - 11, 7.5, fright and 0x6a7cff or 0xffd24a, C.INK, 1.2)
    local pr = cos(f * 0.45) * 6
    gfx.line(x, y - 18, x - pr, y - 19, 1.5, C.INK)
    gfx.line(x, y - 18, x + pr, y - 19, 1.5, C.INK)
    gfx.circle(x, y - 18, 1.3, C.ROSE)
  end

  local dx, dy = g.dx, g.dy
  local close = (not small) and (dist(g.x, g.y, S.px, S.py) < 70)
  local taunt = g.taunt and g.taunt > 0

  if fright then
    local fcol = blink and C.RED or C.CREAM
    gfx.circle(x - 3.6, y - 3, 2, fcol)
    gfx.circle(x + 3.6, y - 3, 2, fcol)
    if id == 1 then   -- even Reddy's brows are worried now
      gfx.line(x - 6, y - 7.5, x - 2, y - 6, 1.4, fcol)
      gfx.line(x + 6, y - 7.5, x + 2, y - 6, 1.4, fcol)
    elseif id == 4 then
      gfx.ellipse(x + 8, y - 4, 1.4, 2.2, 0x9ae8ff)
    end
    for i = -2, 1 do
      local x0 = x + i * 3.2
      local y0 = y + 3 + (i % 2 == 0 and 0 or -2)
      local y1 = y + 3 + ((i + 1) % 2 == 0 and 0 or -2)
      gfx.line(x0, y0, x0 + 3.2, y1, 1.6, fcol)
    end
    return
  end

  if g.state == "house" then   -- waiting in the house: sleepy
    gfx.line(x - 6.5, y - 2.5, x - 1.5, y - 2.5, 1.6, C.INK)
    gfx.line(x + 1.5, y - 2.5, x + 6.5, y - 2.5, 1.6, C.INK)
    gfx.ellipse(x, y + 4, 1.8, 1.4 + abs(sin(f * 0.05 + id)), alpha(C.INK, 200))
    if g.release > 20 then gfx.text("z", x + 10, y - 16 - abs(sin(f * 0.05 + id)) * 3, 11, C.CYAN, "center") end
    return
  end

  -- the eyes, by character
  if id == 1 then          -- narrow and set
    gfx.ellipse(x - 3.8, y - 2.5, 3.4, 3.4, C.WHITE)
    gfx.ellipse(x + 3.8, y - 2.5, 3.4, 3.4, C.WHITE)
    gfx.circle(x - 3.8 + dx * 1.7, y - 2.5 + dy * 1.7, 1.8, C.BLUE)
    gfx.circle(x + 3.8 + dx * 1.7, y - 2.5 + dy * 1.7, 1.8, C.BLUE)
    gfx.line(x - 7.5, y - 8.2, x - 1.5, y - 5.6, 1.7, C.INK)
    gfx.line(x + 7.5, y - 8.2, x + 1.5, y - 5.6, 1.7, C.INK)
  elseif id == 2 then      -- lashes, and now and then a wink
    local wink = (f + 40) % 260 < 14
    gfx.ellipse(x - 3.8, y - 2.5, 3.4, 4.2, C.WHITE)
    gfx.circle(x - 3.8 + dx * 1.6, y - 2.5 + dy * 1.6, 1.8, C.BLUE)
    if wink then
      gfx.line(x + 1.2, y - 2.5, x + 6.5, y - 2.5, 1.6, C.INK)
    else
      gfx.ellipse(x + 3.8, y - 2.5, 3.4, 4.2, C.WHITE)
      gfx.circle(x + 3.8 + dx * 1.6, y - 2.5 + dy * 1.6, 1.8, C.BLUE)
    end
    gfx.line(x - 7.2, y - 5.4, x - 9, y - 7, 1.2, C.INK)
    gfx.line(x + 7.2, y - 5.4, x + 9, y - 7, 1.2, C.INK)
  elseif id == 3 then      -- wide, wandering
    local jx, jy = sin(f * 0.21) * 0.9, cos(f * 0.17) * 0.7
    gfx.ellipse(x - 3.9, y - 2.5, 3.9, 5, C.WHITE)
    gfx.ellipse(x + 3.9, y - 2.5, 3.9, 5, C.WHITE)
    gfx.circle(x - 3.9 + dx * 1.6 + jx, y - 2.5 + dy * 1.6 + jy, 2.3, C.BLUE)
    gfx.circle(x + 3.9 + dx * 1.6 + jx, y - 2.5 + dy * 1.6 + jy, 2.3, C.BLUE)
  else                     -- small and shy, looking down and away
    local sx = g.shy and -dx * 1.2 or dx * 1.2
    gfx.ellipse(x - 3.7, y - 1.5, 2.9, 3.4, C.WHITE)
    gfx.ellipse(x + 3.7, y - 1.5, 2.9, 3.4, C.WHITE)
    gfx.circle(x - 3.7 + sx, y - 0.2, 1.6, C.BLUE)
    gfx.circle(x + 3.7 + sx, y - 0.2, 1.6, C.BLUE)
    gfx.circle(x - 7.8, y + 2.2, 2.4, alpha(C.ROSE, 140))
    gfx.circle(x + 7.8, y + 2.2, 2.4, alpha(C.ROSE, 140))
    if g.shy then gfx.ellipse(x + 9, y - 6.5, 1.4, 2.2, 0x9ae8ff) end
  end

  -- the mouth, by character and by what is happening
  if taunt then            -- teehee: tongue out
    gfx.ellipse(x, y + 4.6, 3.4, 1.8, C.INK)
    gfx.ellipse(x + 1.4, y + 6.8, 2.1, 2.6, C.ROSE)
  elseif id == 1 then
    if close then
      gfx.rect(x - 3.6, y + 3.2, 7.2, 3.4, C.WHITE)
      gfx.line(x - 3.6, y + 4.9, x + 3.6, y + 4.9, 0.8, C.INK)
      if f % 20 < 10 then gfx.circle(x - 9 + (f % 20) * 0.3, y - 15 - (f % 20) * 0.5, 2.2, alpha(C.WHITE, 150)) end   -- steam
    else
      gfx.line(x - 3.5, y + 5, x + 3.5, y + 4, 1.6, C.INK)
    end
  elseif id == 2 then
    gfx.line(x - 3.6, y + 3.4, x - 1, y + 5.2, 1.5, C.INK)
    gfx.line(x - 1, y + 5.2, x + 3.6, y + 3.2, 1.5, C.INK)
  elseif id == 3 then
    gfx.ellipse(x, y + 4.8, 3.2, 2.6 + (close and 0.8 or 0), C.INK)
    gfx.ellipse(x + 1, y + 6, 1.8, 1.1, C.ROSE)
  else
    gfx.line(x - 3, y + 5, x - 1.5, y + 4, 1.3, C.INK)
    gfx.line(x - 1.5, y + 4, x + 0.5, y + 5.2, 1.3, C.INK)
    gfx.line(x + 0.5, y + 5.2, x + 2, y + 4, 1.3, C.INK)
    gfx.line(x + 2, y + 4, x + 3.4, y + 5, 1.3, C.INK)
  end
  if id == 2 and (close or taunt) then gfx.heart(x + 13, y - 10 - sin(f * 0.1) * 2, 5, alpha(C.ROSE, 220)) end
end

-- ------------------------------------------------------------------ the fruits
local function draw_fruit(kind, x, y, sc)
  sc = sc or 1
  if kind == 1 then
    gfx.line(x - 4 * sc, y + 2 * sc, x, y - 9 * sc, 1.8 * sc, C.GREEN)
    gfx.line(x + 4 * sc, y + 3 * sc, x, y - 9 * sc, 1.8 * sc, C.GREEN)
    gfx.circle_o(x - 4.5 * sc, y + 3 * sc, 4.5 * sc, C.RED, C.INK, 1.3 * sc)
    gfx.circle_o(x + 4.5 * sc, y + 4 * sc, 4.5 * sc, C.RED, C.INK, 1.3 * sc)
    gfx.circle(x - 6 * sc, y + 1.5 * sc, 1.3 * sc, C.WHITE)
    gfx.circle(x + 3 * sc, y + 2.5 * sc, 1.3 * sc, C.WHITE)
  elseif kind == 2 then
    gfx.tri(x - 7 * sc, y - 4 * sc, x + 7 * sc, y - 4 * sc, x, y + 9 * sc, C.RED)
    gfx.circle(x, y - 2 * sc, 6.5 * sc, C.RED)
    gfx.ellipse(x, y - 7 * sc, 6 * sc, 2.8 * sc, C.GREEN)
    gfx.circle(x - 2 * sc, y - 1 * sc, 1 * sc, C.GOLD)
    gfx.circle(x + 2 * sc, y + 1 * sc, 1 * sc, C.GOLD)
    gfx.circle(x, y + 4 * sc, 1 * sc, C.GOLD)
  elseif kind == 3 then
    gfx.circle_o(x, y + 1 * sc, 7.5 * sc, C.ORANGE, C.INK, 1.4 * sc)
    gfx.ellipse(x + 3 * sc, y - 7 * sc, 4.5 * sc, 2.2 * sc, C.GREEN)
    gfx.circle(x - 2.5 * sc, y - 1.5 * sc, 1.8 * sc, alpha(C.WHITE, 180))
  elseif kind == 4 then
    gfx.glow(x, y, 14 * sc, alpha(C.GOLD, 120))
    gfx.circle_o(x, y + 1 * sc, 7.5 * sc, C.GOLD, C.INK, 1.4 * sc)
    gfx.line(x, y - 6 * sc, x + 2 * sc, y - 10 * sc, 2 * sc, 0x8a5828)
    gfx.ellipse(x + 4 * sc, y - 8 * sc, 3.5 * sc, 1.8 * sc, C.GREEN)
  else
    gfx.glow(x, y, 16 * sc, alpha(C.CYAN, 130))
    gfx.circle_o(x, y, 8 * sc, C.GREEN, C.INK, 1.5 * sc)
    gfx.star(x, y, 4.5 * sc, game.frame * 0.08, C.GOLD)
  end
end

-- ------------------------------------------------------------------ the sky: the constellation
-- n stars are lit (1..n); in the story, a star is lit until the ghost takes it (story_t > 0).
local function star_lit(k, n, story_t)
  if story_t then return story_t < 70 + k * 5 end
  return k <= n
end

local function draw_constellation(n, story_t, pop_k, pop_age, all_glow)
  local f = game.frame
  for i = 1, #LA do
    local a, b = LA[i], LB[i]
    local la, lb = star_lit(a, n, story_t), star_lit(b, n, story_t)
    if pop_k and (a == pop_k or b == pop_k) and pop_age < 0 then la = false end
    if la and lb then
      gfx.line(SX[a], SY[a], SX[b], SY[b], 2, alpha(C.GOLD, all_glow and 200 or 120))
    else
      gfx.line(SX[a], SY[a], SX[b], SY[b], 1, alpha(0x8890d8, 45))
    end
  end
  for k = 1, NSTARS do
    local x, y = SX[k], SY[k]
    local lit = star_lit(k, n, story_t)
    if pop_k == k and pop_age < 0 then lit = false end
    if lit then
      local tw = 0.5 + 0.5 * sin(f * 0.08 + k * 1.7)
      local r = (k >= 20 and 5.5 or 7) + tw * 1.6
      gfx.glow(x, y, r * 2.4, alpha(C.GOLD, floor(60 + tw * 60)))
      gfx.star(x, y, r, f * 0.01 + k, C.GOLD)
      gfx.circle(x, y, 1.6, C.WHITE)
    else
      gfx.circle(x, y, 3, 0x3a3e78)
      gfx.ring(x, y, 5.5, 1, alpha(0x9098e8, 70))
    end
  end
  if pop_k and pop_age >= 0 and pop_age < 26 then   -- the new star pops
    local x, y = SX[pop_k], SY[pop_k]
    gfx.ring(x, y, 6 + pop_age * 1.5, 2, alpha(C.GOLD, floor(220 - pop_age * 8)))
    gfx.glow(x, y, 20 + (26 - pop_age), alpha(C.WHITE, floor(180 - pop_age * 6)))
  end
end

-- the shelf: fruit he has gobbled, ghosts he has chased, the four-ghost chain trophy
local function draw_shelf()
  local S = P.S
  gfx.rrect(18, PANEL_Y + 8, 72, 134, 12, 0x20204e)
  draw_chompy_at(54, PANEL_Y + 76, 1, 0, 0.18 + abs(sin(game.frame * 0.12)) * 0.32, 3, S.look, 0x15163e, nil)
  gfx.text("FRUIT", 110, PANEL_Y + 10, 11, 0x9aa4e8, "left")
  for i = 1, 5 do
    local x, y = FRX[i], PANEL_Y + 44
    if S.fr[i] > 0 then
      draw_fruit(i, x, y + sin(game.frame * 0.06 + i) * 1.5, 1.2)
      gfx.text(S.fr_txt[i], x, y + 16, 11, C.CREAM, "center")
    else
      gfx.circle(x, y, 10, 0x25285c)
      gfx.text("?", x, y - 8, 15, 0x6068b0, "center")
    end
  end
  gfx.text("GHOSTS", 110, PANEL_Y + 82, 11, 0x9aa4e8, "left")
  for i = 1, 4 do
    local x, y = FRX[i], PANEL_Y + 116
    if S.gh[i] > 0 then
      local g = S.gal[i]
      g.x, g.y, g.dx, g.dy, g.state, g.taunt = x, y, 0, 1, "chase", 0
      draw_ghost_at(g, S, true)
      gfx.text(S.gh_txt[i], x, y + 14, 11, C.CREAM, "center")
    else
      gfx.circle(x, y - 2, 10, 0x25285c)
      gfx.text("?", x, y - 10, 15, 0x6068b0, "center")
    end
  end
  -- the trophy: all four ghosts in one power-up
  local x, y = FRX[5], PANEL_Y + 116
  if S.grand > 0 then
    gfx.glow(x, y - 2, 18, alpha(C.GOLD, 90))
    gfx.star(x, y - 2, 12, game.frame * 0.02, C.GOLD)
    gfx.text("4", x, y - 9, 12, C.INK, "center")
    gfx.text(S.grand_txt, x, y + 14, 11, C.CREAM, "center")
  else
    gfx.star(x, y - 2, 10, 0, 0x25285c)
    gfx.text("4", x, y - 9, 12, 0x6068b0, "center")
  end
end

-- ------------------------------------------------------------------ the story and the star map
local function seg(t, a, b) return clamp((t - a) / (b - a), 0, 1) end
local STORY_SPLIT = 230
P.STORY_SPLIT = STORY_SPLIT

local THX = {}
for i = 1, 6 do THX[i] = 38 + (i - 1) * 61 end
local THY = PANEL_Y + 78

local function draw_thumb(i, glint)
  local T = THEMES[i]
  local x = THX[i]
  gfx.rrect_o(x - 25, THY - 36, 50, 72, 10, T.bg, T.wall, 2)
  gfx.rrect_o(x - 16, THY - 26, 32, 40, 6, T.inner, T.wall, 1.5)
  gfx.rrect(x - 8, THY - 18, 16, 24, 3, T.bg)
  gfx.text(tostring(i), x, THY + 17, 11, T.acc, "center")
  if glint > 0 then gfx.glow(x, THY - 4, 22, alpha(C.GOLD, floor(glint * 12))) end
end

function P.story(t)
  local S = P.S
  scene(0, 0, S)
  local f = game.frame
  if t < STORY_SPLIT then
    draw_constellation(0, t)
    -- the ghosts float in over the stars, grab and toss them down onto the mazes
    local gx0 = 64
    for i = 1, 4 do
      local g = S.gal[i]
      local lift = seg(t, 0, 50)
      local leave = seg(t, 196, 226)
      g.x = gx0 + (i - 1) * 85 + sin(f * 0.07 + i) * 5
      g.y = -26 + lift * 96 + sin(f * 0.09 + i * 1.3) * 4 - leave * 130
      g.dx, g.dy, g.state, g.taunt = 0, 1, "chase", (t > 70 and t < 190) and 1 or 0
      draw_ghost_at(g, S, true)
    end
    local landed = 0
    for i = 1, 6 do
      local glint = 0
      for k = i, NSTARS, 6 do
        local tk = 70 + k * 5
        local u = (t - tk) / 40
        if u > 0 and u < 1 then
          local x = SX[k] + (THX[i] - SX[k]) * u
          local y = SY[k] + (THY - SY[k]) * u - sin(u * 3.1416) * 70
          gfx.glow(x, y, 12, alpha(C.GOLD, 130))
          gfx.star(x, y, 6, f * 0.2 + k, C.GOLD)
        elseif u >= 1 and u < 1.4 then
          glint = max(glint, (1.4 - u) * 10)
        end
      end
      draw_thumb(i, glint)
    end
    gfx.text("THE MAZES", W / 2, PANEL_Y + 8, 11, 0x9aa4e8, "center")
    -- Chompy rolls in underneath
    if t > 160 then
      local cx = -30 + 84 * ease.out_cubic(seg(t, 160, 215))
      draw_chompy_at(cx, 292 + 84 * seg(t, 205, 230), 1, 0, 0.12 + abs(sin(f * 0.45)) * 0.5, 0, S.look, 0x1e1c58, nil)
    end
  else
    draw_constellation(S.stars, nil, nil, 0, S.stars >= NSTARS)
    draw_shelf()
    gfx.text(S.sky_title, W / 2, 16, 20, C.GOLD, "center", C.INK)
  end
end

local function story_line_for(t)
  if t < 70 then return "The night sky was full of stars!"
  elseif t < 160 then return "Uh-oh! The ghosts tossed the stars away!"
  else return "Chompy will gobble them back!" end
end
function P.story_line(t)
  if t >= STORY_SPLIT then return P.S.sky_line end
  return story_line_for(t)
end

-- the star map after a maze: the new star flies from Chompy to its place in the sky
function P.map(t)
  local S = P.S
  scene(0, 0, S)
  local f = game.frame
  local k = S.stars   -- the one just won (S.stars already counts it)
  local nshow = S.stars
  local flying = S.new_star and k <= NSTARS
  draw_constellation(nshow, nil, flying and k or nil, flying and (t - 60) or 99, S.stars >= NSTARS)
  draw_shelf()
  gfx.text(S.sky_title, W / 2, 16, 20, C.GOLD, "center", C.INK)
  if flying and t < 60 then
    local u = ease.out_quad(seg(t, 4, 60))
    local sx, sy = 54, PANEL_Y + 76
    local x = sx + (SX[k] - sx) * u
    local y = sy + (SY[k] - sy) * u - sin(u * 3.1416) * 60
    gfx.glow(x, y, 16, alpha(C.GOLD, 150))
    gfx.star(x, y, 8, f * 0.2, C.GOLD)
  end
  if S.stars >= NSTARS and t > 60 then gfx.glow(176, 192, 120, alpha(C.GOLD, floor(24 + sin(f * 0.05) * 12))) end
end

-- ------------------------------------------------------------------ the HUD and the maze screen
function P.draw()
  local S = P.S
  local tidx = S.theme
  scene(tidx, S.maze_id, S)
  draw_decor(tidx)

  local ox, oy, ts = S.OX, S.OY, S.TS
  local pulse = 5.4 + sin(game.frame * 0.18) * 1.2
  local dots = S.dots
  for r = 1, S.ROWS do
    local row = dots[r]
    for c = 1, S.COLS do
      local v = row[c]
      if v == 1 then
        gfx.circle(ox + (c - 0.5) * ts, oy + (r - 0.5) * ts, 2.5, C.DOT)
      elseif v == 2 then   -- a big star the ghosts dropped
        local px, py = ox + (c - 0.5) * ts, oy + (r - 0.5) * ts
        gfx.glow(px, py, 17, alpha(C.GOLD, 120))
        gfx.star(px, py, pulse * 1.5, game.frame * 0.03, C.GOLD)
        gfx.circle(px, py, pulse * 0.4, C.WHITE)
      end
    end
  end

  if S.fruit then
    draw_fruit(S.fruit.kind, S.fruit.x, S.fruit.y + sin(game.frame * 0.14) * 2, 1.15)
  end

  draw_chompy(S)
  for _, g in ipairs(S.ghosts) do draw_ghost_at(g, S, false) end

  -- the HUD
  gfx.rrect_o(8, 8, W - 16, 48, 12, 0x1a1834, C.GOLD, 2)
  gfx.text(S.stage_txt, 20, 13, 13, C.GOLD, "left")
  for i = 1, 3 do
    local hx = 26 + (i - 1) * 18
    local col = i <= (3 - S.hurts) and C.ROSE or 0x483c5c
    gfx.circle(hx - 3, 38, 3.8, col)
    gfx.circle(hx + 3, 38, 3.8, col)
    gfx.tri(hx - 6.8, 39, hx + 6.8, 39, hx, 46, col)
  end
  for i = 1, 4 do   -- the four big stars of this maze
    local sx = 82 + (i - 1) * 13
    if S.pel[i] then gfx.star(sx, 32, 5, 0, C.GOLD) else gfx.star(sx, 32, 3.8, 0, 0x483c5c) end
  end
  local ready = S.dash_cool == 0
  gfx.rrect_o(136, 15, 112, 34, 9, ready and 0x2c2458 or 0x16142a, ready and C.GOLD or 0x585078, 1.6)
  gfx.text(S.dash_t > 0 and "TURBO!" or (ready and "DASH READY" or "CHARGING"), 192, 24, 11,
           ready and C.GOLD or 0x9c92b8, "center")
  gfx.text(S.score_txt, W - 18, 13, 13, C.WHITE, "right")
  gfx.text(S.hi_txt, W - 18, 32, 12, C.CYAN, "right")
  -- how much star dust is left to gather
  local pg = S.dots_total > 0 and (1 - S.dots_left / S.dots_total) or 0
  gfx.rrect(20, 51, W - 40, 3, 1.5, 0x2a2850)
  if pg > 0.01 then gfx.rrect(20, 51, (W - 40) * pg, 3, 1.5, THEMES[tidx].wall) end

  if S.phase == "ready" then
    gfx.rrect_o(86, 232, 212, 62, 14, alpha(0x14122c, 235), C.GOLD, 2.5)
    gfx.text("READY!", W / 2, 238, 22, C.GOLD, "center", C.INK)
    gfx.text(THEMES[tidx].name, W / 2, 268, 14, THEMES[tidx].acc, "center")
  elseif S.phase == "clear" then
    gfx.rrect_o(46, 212, W - 92, 96, 16, C.CREAM, C.INK, 3)
    gfx.text(S.clear_txt, W / 2, 226, 22, C.GOLD, "center", C.INK)
    gfx.text(S.clear_score_txt, W / 2, 260, 15, C.PURPLE, "center")
    gfx.text("A STAR GOES HOME!", W / 2, 282, 12, C.INK, "center")
  end
end

return P
