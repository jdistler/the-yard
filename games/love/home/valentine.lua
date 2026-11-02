-- Sweethearts: Valentine's Day, seven minutes (Feb 7-14 in AUTO):
--   0:00  PARTYCADE PRESENTS ... SWEETHEARTS                                       (Sweethearts)
--   0:08  They meet: Pac-Man and Ms. Pac-Man, each chased by a ghost, meet in the middle; the ghosts collide
--                                                                                   (Chase Me)
--   1:10  Candy hearts: conversation hearts filling a jar, arcade sayings on them   (Bubblegum)
--   2:20  A ghost's valentine: Blinky's card for Pinky                              (Serenade)
--   3:30  Date night: the diner, one milkshake, two straws, the others at the window (Doo-Wop)
--   4:50  A heart of dots: eaten from the top by both of them, meeting at the point, then fireworks
--                                                                                   (Our Waltz)
--   6:20  HAPPY VALENTINE'S DAY
local lg = love.graphics
local L = require("showlib")
local M = {}
local C, G
local W, H = 768, 1024
local LEN = 420
M.LEN = LEN
local sin, cos, floor, min, max, abs, pi = math.sin, math.cos, math.floor, math.min, math.max, math.abs, math.pi
local clamp, ease, lerp, mix = L.clamp, L.ease, L.lerp, L.mix

local SCENES = {
  {0, "open", "ve_open"},
  {8, "meet", "ve_chase", "THEY MEET", "PLAYER 1  ·  PLAYER 2  ·  TWO GHOSTS WHO DIDN'T LOOK"},
  {70, "candy", "ve_bubble", "CANDY HEARTS", "ARCADE SAYINGS  ·  ONE JAR"},
  {140, "card", "ve_serenade", "A GHOST'S VALENTINE", "BLINKY HAS SOMETHING TO ASK"},
  {210, "diner", "ve_doowop", "DATE NIGHT", "ONE MILKSHAKE  ·  TWO STRAWS"},
  {290, "dots", "ve_heart", "A HEART OF DOTS", "FROM THE TOP, BOTH WAYS"},
  {380, "finale", "ve_open"},
}
M.SEGMENTS = {}
for _, s in ipairs(SCENES) do if s[4] then M.SEGMENTS[#M.SEGMENTS + 1] = {s[1], s[4]} end end
M.THUMB = 1

local S
local function scene_at(t)
  local k = 1
  for i, s in ipairs(SCENES) do if t >= s[1] then k = i end end
  local s = SCENES[k]
  local e = SCENES[k + 1] and SCENES[k + 1][1] or LEN
  return s, t - s[1], e - s[1], k
end
local function rgba(c, a) lg.setColor(c[1], c[2], c[3], a or 1) end
local GHOSTS = {{1, 0.18, 0.2}, {1, 0.55, 0.85}, {0.25, 0.95, 1}, {1, 0.65, 0.2}}
local PINK, RED = {1, 0.45, 0.7}, {0.95, 0.15, 0.3}
local SAYINGS = {"BE MINE", "PLAYER 2?", "INSERT COIN", "HIGH SCORE", "1UP", "CO-OP?", "GAME ON", "WAKA WAKA",
                 "XOXO", "U R A 10", "READY!", "HOLD ME", "NO CONTINUES", "BONUS!", "TRUE LOVE", "LEVEL UP"}
local CANDY = {{1, 0.75, 0.82}, {0.8, 0.95, 0.75}, {1, 0.95, 0.65}, {0.8, 0.85, 1}, {1, 0.85, 0.7}, {0.95, 0.95, 0.95}}

-- A heart: two circles and a point; s is half its width.
local function heart(x, y, s)
  lg.circle("fill", x - s * 0.5, y, s * 0.54, 20)
  lg.circle("fill", x + s * 0.5, y, s * 0.54, 20)
  lg.polygon("fill", x - s * 1.02, y + s * 0.14, x + s * 1.02, y + s * 0.14, x, y + s * 1.25)
end

-- Ms. Pac-Man: the chomper, a bow, a beauty mark, lipstick.
local function ms(x, y, r, dir, t, al)
  al = al or 1
  C.fx.chomper(x, y, r, dir, t, al)
  local d = dir > 0 and 1 or -1
  lg.setColor(0.95, 0.1, 0.25, al)
  local bx, by = x + r * 0.15 * d, y - r * 0.92
  lg.polygon("fill", bx, by, bx - r * 0.5, by - r * 0.32, bx - r * 0.5, by + r * 0.28)
  lg.polygon("fill", bx, by, bx + r * 0.5, by - r * 0.32, bx + r * 0.5, by + r * 0.28)
  lg.setColor(0.3, 0.4, 1, al)
  lg.circle("fill", bx, by, r * 0.14, 10)
  lg.setColor(0.95, 0.1, 0.25, al)
  lg.circle("fill", x + r * 0.62 * d, y + r * 0.08, r * 0.1, 8)
  lg.setColor(0.1, 0.05, 0.1, al)
  lg.circle("fill", x - r * 0.25 * d, y + r * 0.35, r * 0.05, 6)
  lg.setLineWidth(max(1, r * 0.06))
  lg.line(x + r * 0.1 * d, y - r * 0.62, x + r * 0.25 * d, y - r * 0.78)
end

local function blush(x, y, r, a)
  lg.setColor(1, 0.4, 0.55, 0.6 * (a or 1))
  lg.ellipse("fill", x - r * 0.55, y + r * 0.25, r * 0.18, r * 0.1, 10)
  lg.ellipse("fill", x + r * 0.55, y + r * 0.25, r * 0.18, r * 0.1, 10)
end

local function sky_night()
  G:gradient(0, 0, W, H, {0.08, 0.03, 0.16}, {0.3, 0.06, 0.25})
  for i, s in ipairs(S.stars) do
    lg.setColor(1, 0.9, 1, 0.3 + 0.4 * abs(sin(S.t * 0.7 + i)))
    lg.rectangle("fill", s[1], s[2], 2, 2)
  end
end

local function floaters(a)
  -- little hearts drifting up the screen
  for i, f in ipairs(S.floaters) do
    local y = H + 40 - ((S.t * f[3] + f[2]) % (H + 80))
    local x = f[1] + sin(S.t * 0.8 + i) * 20
    lg.setColor(f[4][1], f[4][2], f[4][3], 0.35 * (a or 1))
    heart(x, y, f[5])
  end
end

local D = {}

function D.open(lt, len)
  sky_night()
  floaters(1)
  local k = ease(lt / 3)
  lg.setColor(RED[1], RED[2], RED[3], 1)
  heart(384, 330, 120 * k * (1 + 0.04 * sin(S.t * 6)))
  local a = L.window(lt, 0.4, 4, 0.7)
  G:caption("PARTYCADE", 620, 54, 0xff4fd8, a)
  G:caption("PRESENTS", 690, 26, 0x6ef0c8, a)
  G:caption("SWEETHEARTS", 650, 80, 0xff6fa8, L.window(lt, 4.2, 8, 0.7))
end

-- the maze corridor; a 24 s loop
function D.meet(lt, len)
  lg.setColor(0, 0, 0, 1)
  lg.rectangle("fill", 0, 0, W, H)
  lg.setColor(0.13, 0.2, 1, 1)
  lg.setLineWidth(5)
  lg.rectangle("line", 20, 380, W - 40, 100, 18, 18, 8)
  lg.rectangle("line", 20, 640, W - 40, 100, 18, 18, 8)
  lg.rectangle("line", 300, 120, 168, 200, 18, 18, 8)
  lg.rectangle("line", 300, 800, 168, 150, 18, 18, 8)
  local c = lt % 24
  local y = 560
  -- the dots ahead of them
  lg.setColor(1, 0.8, 0.7, 1)
  for i = 0, 22 do
    local x = 40 + i * 31
    local px = lerp(-40, 330, clamp(c / 8, 0, 1))
    local mx = lerp(W + 40, 438, clamp(c / 8, 0, 1))
    if x > px + 10 and x < mx - 10 then lg.rectangle("fill", x - 3, y - 3, 6, 6) end
  end
  if c < 8 then
    local k = c / 8
    C.fx.chomper(lerp(-40, 330, k), y, 30, 1, S.t, 1)
    ms(lerp(W + 40, 438, k), y, 30, -1, S.t, 1)
    C.fx.ghost(lerp(-200, 220, k), y, 30, GHOSTS[3], 1, S.t, false, false, 1)
    C.fx.ghost(lerp(W + 200, 548, k), y, 30, GHOSTS[2], -1, S.t, false, false, 1)
  else
    -- they hop up out of the way; the ghosts run into each other
    local j = clamp((c - 8) / 1.2, 0, 1)
    local py = y - sin(j * pi / 2) * 230
    C.fx.chomper(330 + j * 20, py, 30, 1, c < 9.2 and S.t or 0, 1)
    ms(438 - j * 20, py, 30, -1, c < 9.2 and S.t or 0, 1)
    local g = clamp((c - 8) / 1.6, 0, 1)
    local gx = lerp(220, 352, g)
    if c < 9.6 then
      C.fx.ghost(gx, y, 30, GHOSTS[3], 1, S.t, false, false, 1)
      C.fx.ghost(W - gx, y, 30, GHOSTS[2], -1, S.t, false, false, 1)
    else
      local b = min((c - 9.6) * 2, 1)
      C.fx.ghost(352 - b * 40, y + b * 20, 30, GHOSTS[3], 1, S.t, true, false, 1)
      C.fx.ghost(416 + b * 40, y + b * 20, 30, GHOSTS[2], -1, S.t, true, false, 1)
      for i = 0, 3 do
        local an = S.t * 4 + i * pi / 2
        lg.setColor(1, 1, 0.4, 1)
        L.star(384 + cos(an) * 60, y - 50 + sin(an) * 14, 7, an)
      end
    end
    if c > 10 then
      local hk = ease((c - 10) / 1)
      lg.setColor(RED[1], RED[2], RED[3], 1)
      heart(384, py - 90, 40 * hk * (1 + 0.08 * sin(S.t * 8)))
    end
  end
  local f = clamp((c - 22) / 2, 0, 1)
  if f > 0 then
    lg.setColor(0, 0, 0, f)
    lg.rectangle("fill", 0, 0, W, H)
  end
end

function D.candy(lt, len)
  G:gradient(0, 0, W, H, {1, 0.8, 0.86}, {0.95, 0.55, 0.7})
  floaters(0.6)
  -- the table
  lg.setColor(0.6, 0.3, 0.35, 1)
  lg.rectangle("fill", 0, 900, W, 124)
  -- the hearts, one a second, into the jar (a pile in rows)
  local n = min(#S.candy, floor(lt / 1.0) + 1)
  for i = 1, n do
    local h = S.candy[i]
    local born = (i - 1) * 1.0
    local k = clamp((lt - born) / 1.1, 0, 1)
    local y = lerp(-60, h.y, k * k)
    if k >= 1 then y = h.y - abs(sin(min((lt - born - 1.1) * 8, pi))) * 10 * max(0, 1 - (lt - born - 1.1)) end
    lg.push()
    lg.translate(h.x, y)
    lg.rotate(h.rot * k + (1 - k) * sin(S.t * 3 + i))
    rgba(h.c)
    heart(0, -14, 34)
    G:text(h.say, -44, -8, 13, {0.8, 0.2, 0.35}, 1, "center", 88)
    lg.pop()
  end
  -- the jar's glass over them
  lg.setColor(0.85, 0.95, 1, 0.22)
  lg.rectangle("fill", 170, 420, 428, 480, 30, 30, 12)
  lg.setColor(1, 1, 1, 0.5)
  lg.setLineWidth(4)
  lg.rectangle("line", 170, 420, 428, 480, 30, 30, 12)
  lg.rectangle("fill", 196, 450, 14, 380, 6, 6, 4)
  lg.setColor(0.85, 0.3, 0.45, 1)
  lg.rectangle("fill", 200, 396, 368, 30, 8, 8, 4)
  -- the newest one, close up
  local i = min(floor(lt / 4) + 1, n)
  local h = S.candy[i]
  local a = min(clamp((lt % 4) * 3, 0, 1), clamp((4 - lt % 4) * 3, 0, 1))
  rgba(h.c, a)
  heart(384, 190, 110)
  G:text(h.say, 234, 210, 36, {0.8, 0.2, 0.35}, a, "center", 300)
end

function D.card(lt, len)
  sky_night()
  floaters(0.5)
  -- Pinky's door: a little house in the maze
  lg.setColor(0.2, 0.12, 0.3, 1)
  lg.rectangle("fill", 420, 420, 300, 500)
  lg.setColor(0.13, 0.2, 1, 1)
  lg.setLineWidth(5)
  lg.rectangle("line", 420, 420, 300, 500, 12, 12, 6)
  lg.setColor(1, 0.55, 0.85, 1)
  lg.rectangle("fill", 520, 380, 100, 8)
  lg.setColor(0.04, 0.02, 0.08, 1)
  lg.rectangle("fill", 500, 660, 140, 260, 70, 70, 16)
  G:gradient(0, 920, W, H, {0.2, 0.08, 0.2}, {0.1, 0.04, 0.1})
  -- Blinky comes along with his card, trembling
  local bx = lerp(-80, 360, ease(lt / 16))
  local tremble = lt < 30 and sin(S.t * 30) * 2 or 0
  local by = 800 + sin(S.t * 2) * 6
  local open = clamp((lt - 22) / 3, 0, 1)
  local px = lerp(570, 520, open)
  C.fx.ghost(bx + tremble, by, 44, GHOSTS[1], 1, S.t, false, false, 1)
  if open > 0 then C.fx.ghost(px, 800 + sin(S.t * 2 + 1) * 6, 44, GHOSTS[2], -1, S.t, false, false, 1) end
  -- the card: offered, then read
  local read = clamp((lt - 30) / 2, 0, 1)
  local cx, cy = lerp(bx + 60, 384, read), lerp(by - 10, 360, read)
  local cw = lerp(60, 380, read)
  lg.setColor(1, 0.95, 0.97, 1)
  lg.rectangle("fill", cx - cw / 2, cy - cw * 0.35, cw, cw * 0.7, 6, 6, 4)
  lg.setColor(RED[1], RED[2], RED[3], 1)
  heart(cx, cy - cw * 0.18, cw * 0.12)
  if read > 0.9 then
    G:text("ROSES ARE RED", cx - 180, cy - 30, 22, {0.8, 0.2, 0.35}, 1, "center", 360)
    G:text("PINKY, YOU'RE PINK", cx - 180, cy, 22, {0.8, 0.2, 0.35}, 1, "center", 360)
    G:text("WILL YOU BE MY PLAYER 2?", cx - 180, cy + 30, 22, {0.8, 0.2, 0.35}, 1, "center", 360)
    G:text("- B.", cx - 180, cy + 70, 18, {0.5, 0.3, 0.4}, 1, "right", 340)
  end
  if lt > 42 then
    local a = clamp((lt - 42) / 2, 0, 1)
    blush(bx, by, 44, a)
    blush(px, 800, 44, a)
    G:plate("SHE SAID YES", 160, 34, 0xff6fa8, L.window(lt, 44, len - 2, 1))
    for i = 1, 6 do
      local k = ((S.t * 0.4 + i / 6) % 1)
      lg.setColor(1, 0.3, 0.5, 1 - k)
      heart((bx + px) / 2 + sin(i * 2 + S.t) * 50, 720 - k * 200, 14 + i % 3 * 4)
    end
  end
end

function D.diner(lt, len)
  sky_night()
  -- the diner window, the neon, the booth
  lg.setColor(0.12, 0.06, 0.15, 1)
  lg.rectangle("fill", 0, 300, W, 724)
  local on = (floor(S.t * 2) % 7 ~= 0) and 1 or 0.3
  G:text("PAC'S DINER", 0, 150, 64, {1, 0.3, 0.55}, on, "center", W)
  C.fx.glow(384, 190, 300, 80, 1, 0.3, 0.6, 0.25 * on)
  lg.setColor(0.25, 0.75, 0.75, 1)
  lg.rectangle("fill", 0, 300, W, 26)
  for i = 0, 15 do
    if i % 2 == 0 then lg.setColor(1, 1, 1, 1) else lg.setColor(0.05, 0.05, 0.05, 1) end
    lg.rectangle("fill", i * 48, 900, 48, 24)
  end
  -- the window behind the booth: Inky and Clyde peeking in
  lg.setColor(0.03, 0.03, 0.1, 1)
  lg.rectangle("fill", 80, 360, 608, 260, 10, 10, 4)
  local peek = lt % 20
  local pk = peek < 3 and ease(peek / 1) or peek < 6 and 1 or ease(1 - (peek - 6) / 1)
  C.fx.ghost(180, 640 - 120 * pk, 40, GHOSTS[3], 1, S.t, false, false, 1)
  C.fx.ghost(590, 640 - 110 * clamp(pk * 1.3 - 0.3, 0, 1), 40, GHOSTS[4], -1, S.t, false, false, 1)
  lg.setColor(0.12, 0.06, 0.15, 1)
  lg.rectangle("fill", 80, 620, 608, 40)
  lg.setColor(0.9, 0.9, 1, 0.12)
  lg.polygon("fill", 120, 360, 200, 360, 120, 470)
  -- the booth and the table
  lg.setColor(0.8, 0.12, 0.2, 1)
  lg.rectangle("fill", 20, 640, 160, 260, 20, 20, 8)
  lg.rectangle("fill", 588, 640, 160, 260, 20, 20, 8)
  C.fx.chomper(220, 740, 46, 1, 0, 1)
  ms(548, 740, 46, -1, 0, 1)
  lg.setColor(0.85, 0.85, 0.9, 1)
  lg.rectangle("fill", 160, 790, 448, 24, 6, 6, 4)
  lg.rectangle("fill", 370, 814, 28, 90)
  -- the milkshake, two straws
  local level = 1 - clamp(lt / (len - 10), 0, 0.85)
  lg.setColor(0.9, 0.9, 0.95, 0.6)
  lg.polygon("fill", 344, 680, 424, 680, 410, 790, 358, 790)
  lg.setColor(1, 0.7, 0.8, 1)
  local top = 790 - 110 * level
  lg.polygon("fill", 358 - (790 - top) * 0.13 + 0, top, 410 + (790 - top) * 0.13, top, 410, 790, 358, 790)
  lg.setColor(1, 1, 1, 1)
  lg.circle("fill", 384, top - 4, 22, 16)
  lg.setColor(0.9, 0.1, 0.2, 1)
  lg.circle("fill", 384, top - 26, 8, 10)
  lg.setLineWidth(5)
  lg.setColor(1, 0.4, 0.6, 1)
  lg.line(372, top, 330, 640, 272, 700)
  lg.setColor(0.4, 0.8, 1, 1)
  lg.line(396, top, 440, 640, 500, 700)
  -- the jukebox's notes, hearts over the table
  for i = 1, 5 do
    local k = (S.t * 0.25 + i / 5) % 1
    lg.setColor(1, 0.5, 0.7, (1 - k) * 0.9)
    heart(384 + sin(i * 3 + S.t) * 80, 660 - k * 260, 10 + (i % 3) * 4)
  end
  if peek > 1 and peek < 6 then
    G:text("AWWW", 80, 450, 30, {0.85, 0.95, 1}, 0.8, "center", 200)
  end
end

local function heart_pt(u, cx, cy, sc)
  local x = 16 * sin(u) ^ 3
  local y = 13 * cos(u) - 5 * cos(2 * u) - 2 * cos(3 * u) - cos(4 * u)
  return cx + x * sc, cy - y * sc
end

function D.dots(lt, len)
  lg.setColor(0, 0, 0, 1)
  lg.rectangle("fill", 0, 0, W, H)
  local cx, cy, sc = 384, 470, 19
  local eat = clamp((lt - 3) / 40, 0, 1)
  local done = lt - 43
  -- the big heart filling once they meet
  if done > 0 then
    local k = ease(done / 2)
    lg.setColor(RED[1], RED[2], RED[3], 1)
    lg.push()
    lg.translate(cx, cy + 20)
    lg.scale(k)
    heart(0, -60, 250 * (1 + 0.03 * sin(S.t * 5)))
    lg.pop()
    G:text("PLAYER 1", cx - 200, cy - 80, 34, {1, 1, 1}, k, "center", 400)
    G:text("+", cx - 200, cy - 30, 34, {1, 1, 1}, k, "center", 400)
    G:text("PLAYER 2", cx - 200, cy + 20, 34, {1, 1, 1}, k, "center", 400)
  end
  -- the dots: the right half for him, the left for her
  local N = 36
  for i = 0, N do
    local u = i / N * pi
    if u > eat * pi + 0.02 then
      local x, y = heart_pt(u, cx, cy, sc)
      local x2 = 2 * cx - x
      lg.setColor(1, 0.8, 0.7, 1)
      local big = (i % 12 == 6)
      local r = big and 9 * (0.6 + 0.4 * abs(sin(S.t * 5))) or 4
      lg.circle("fill", x, y, r, 10)
      lg.circle("fill", x2, y, r, 10)
    end
  end
  if done < 0.5 then
    local u = eat * pi
    local x, y = heart_pt(u, cx, cy, sc)
    local xa = heart_pt(max(u - 0.05, 0), cx, cy, sc)
    local dir = x >= xa and 1 or -1
    C.fx.chomper(x, y, 26, dir, S.t, 1)
    ms(2 * cx - x, y, 26, -dir, S.t, 1)
  else
    local x, y = heart_pt(pi, cx, cy, sc)
    C.fx.chomper(x - 34, y + 30, 26, 1, 0, 1)
    ms(x + 34, y + 30, 26, -1, 0, 1)
  end
end

function D.finale(lt, len)
  sky_night()
  floaters(1)
  lg.setColor(RED[1], RED[2], RED[3], 1)
  heart(384, 300, 110 * (1 + 0.05 * sin(S.t * 6)))
  C.fx.chomper(300, 730, 40, 1, 0, 1)
  ms(468, 730, 40, -1, 0, 1)
  for i = 1, 4 do C.fx.ghost(120 + (i - 1) * 176, 880 + sin(S.t * 2 + i) * 4, 30, GHOSTS[i], i <= 2 and 1 or -1, S.t + i, false, false, 1) end
  G:caption("HAPPY", 480, 50, 0xffffff, L.window(lt, 0.5, len, 1))
  G:caption("VALENTINE'S DAY", 560, 64, 0xff6fa8, L.window(lt, 1, len, 1))
end

-- ------------------------------------------------------------------ the show
function M.load(ctx)
  C = ctx
  W, H = ctx.W, ctx.H
  G = L.new(ctx)
end

function M.stop()
  if G then G:finish() end
  S = nil
end

function M.start(seed, at)
  M.stop()
  G:begin(seed)
  S = {t = at or 0}
  G.t, G.prev = S.t, S.t - 0.001
  local R = G.R
  S.stars, S.floaters, S.candy = {}, {}, {}
  for i = 1, 80 do S.stars[i] = {R:random() * W, R:random() * H * 0.7} end
  for i = 1, 16 do
    S.floaters[i] = {R:random() * W, R:random() * H, 20 + R:random() * 40,
                     ({PINK, RED, {1, 0.8, 0.9}})[R:random(3)], 8 + R:random() * 14}
  end
  -- the pile in the jar: rows from the bottom, a little ragged
  for i = 1, 60 do
    local row, col = floor((i - 1) / 5), (i - 1) % 5
    S.candy[i] = {x = 220 + col * 82 + (row % 2) * 30 + (R:random() - 0.5) * 16, y = 860 - row * 42 + (R:random() - 0.5) * 10,
                  rot = (R:random() - 0.5) * 1.2, c = CANDY[R:random(#CANDY)], say = SAYINGS[(i * 7) % #SAYINGS + 1]}
  end
  for _, s in ipairs(SCENES) do if s[4] then G:label(s[4], 56, 0xffffff) end end
  for _, l in ipairs({{"PARTYCADE", 54, 0xff4fd8}, {"PRESENTS", 26, 0x6ef0c8}, {"SWEETHEARTS", 80, 0xff6fa8},
                      {"HAPPY", 50, 0xffffff}, {"VALENTINE'S DAY", 64, 0xff6fa8}, {"SHE SAID YES", 34, 0xff6fa8}}) do
    G:label(l[1], l[2], l[3])
  end
end

function M.act() return S and scene_at(S.t)[2] or "open" end
function M.music() return S and scene_at(S.t)[3] or "ve_open" end

function M.update(dt)
  if not S then return false end
  G:step(dt)
  S.t = G.t
  local sc, lt = scene_at(S.t)
  if sc[2] == "meet" then
    local c = lt % 24
    if c >= 9.6 and c - dt < 9.6 then C.sfx("boom", 0.5) end
    if c >= 10 and c - dt < 10 then C.sfx("pop") end
  elseif sc[2] == "candy" then
    if lt % 1 < dt and lt > 1 then C.sfx("pop", 0.3) end
  elseif sc[2] == "card" then
    if G:at(SCENES[4][1] + 44) then C.sfx("cheer", 0.6) end
  elseif sc[2] == "dots" then
    local done = lt - 43
    if done >= 0 and done - dt < 0 then C.sfx("power") end
    if done > 3 and (lt * 2) % 3 < dt * 2 then
      G:firework(120 + G.R:random() * 528, 160 + G.R:random() * 300, false, {PINK, RED, {1, 1, 1}})
      C.sfx("crackle", 0.4)
    end
  end
  return S.t >= LEN
end

function M.draw()
  if not S then return end
  local sc, lt, len = scene_at(S.t)
  D[sc[2]](lt, len)
  G:draw_back()
  G:draw_front()
  if sc[4] then
    G:plate(sc[4], 30, 56, 0xffffff, L.window(lt, 1.5, 9, 1))
    local b = L.window(lt, 2, len - 1.5, 1)
    lg.setColor(0.02, 0.02, 0.06, 0.55 * b)
    lg.rectangle("fill", 0, H - 50, W, 50)
    G:text(sc[5], 0, H - 38, 20, {1, 0.75, 0.85}, b)
  end
  local f = 1 - min(lt / 1.2, (len - lt) / 1.2, 1)
  if f > 0 then
    lg.setColor(0, 0, 0, f)
    lg.rectangle("fill", 0, 0, W, H)
  end
end

return M
