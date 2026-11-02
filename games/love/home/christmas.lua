-- Christmas: Home's show for December (shows.lua's calendar), nine minutes, snow falling through most of it:
--   0:00  PARTYCADE PRESENTS ... CHRISTMAS                                         (Carol of the Bells)
--   0:10  Snow on the cul-de-sac: the house in its lights, the tree in the window, a snowman, the yard's
--         inflatables (Pac-Man in a Santa hat, a longhorn in one too)
--   1:40  Santa Pac-Man's sleigh: across the moon behind four ghost reindeer, the red one's nose glowing,
--         presents down the chimneys                                                (Jingle Bells)
--   3:00  A Texas Christmas: 72 and sunny, cowboy Santa, lights on the prickly pear, a tumbleweed snowman,
--         an armadillo in a Santa hat                                               (Deck the Halls, western swing)
--   4:20  Trimming the tree: the ghosts hang the ornaments, Pac-Man puts the star on; stockings by the fire
--                                                                                   (We Wish You a Merry Christmas)
--   5:40  Cookies for Santa: milk, gingerbread, and the ghosts sneaking them one by one   (Gingerbread Rag)
--   6:40  Silent night: the town asleep under the snow, the star over the steeple  (Silent Night)
--   8:20  MERRY CHRISTMAS, and a happy new year: fireworks in red, green and gold   (Jingle Bells, up a key)
-- The carols are public domain (Jingle Bells 1857, Deck the Halls, We Wish You a Merry Christmas, Silent Night
-- 1818, the Carol of the Bells' ostinato 1914); the Gingerbread Rag is ours.
local lg = love.graphics
local L = require("showlib")
local M = {}
local C, G
local W, H = 768, 1024
local LEN = 540
M.LEN = LEN
local sin, cos, floor, min, max, abs, pi = math.sin, math.cos, math.floor, math.min, math.max, math.abs, math.pi
local clamp, ease, lerp, mix = L.clamp, L.ease, L.lerp, L.mix

local SCENES = {
  {0, "open", "xm_bells"},
  {10, "street", "xm_bells", "SNOW ON THE CUL-DE-SAC", "THE LIGHTS ARE UP"},
  {100, "sleigh", "xm_jingle", "SANTA PAC-MAN'S SLEIGH", "ON BLINKY, ON PINKY, ON INKY AND CLYDE"},
  {180, "texas", "xm_deck", "A TEXAS CHRISTMAS", "72 AND SUNNY  ·  Y'ALL"},
  {260, "tree", "xm_wish", "TRIMMING THE TREE", "STOCKINGS BY THE FIRE"},
  {340, "cookies", "xm_rag", "COOKIES FOR SANTA", "NOBODY TOUCH THE GINGERBREAD"},
  {400, "silent", "xm_silent", "SILENT NIGHT", "ALL IS CALM  ·  ALL IS BRIGHT"},
  {500, "finale", "xm_finale"},
}
M.SEGMENTS = {}
for _, s in ipairs(SCENES) do if s[4] then M.SEGMENTS[#M.SEGMENTS + 1] = {s[1], s[4]} end end
table.insert(M.SEGMENTS, {500, "MERRY CHRISTMAS"})
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
local BULBS = {{1, 0.2, 0.2}, {0.2, 0.85, 0.3}, {0.3, 0.5, 1}, {1, 0.8, 0.2}, {1, 0.4, 0.8}}

-- ------------------------------------------------------------------ small things
local function santa_hat(x, y, r, tilt)
  lg.push()
  lg.translate(x, y)
  lg.rotate(tilt or -0.3)
  lg.setColor(0.85, 0.1, 0.12, 1)
  lg.polygon("fill", -r, 0, r, 0, r * 0.3, -r * 1.4)
  lg.setColor(1, 1, 1, 1)
  lg.rectangle("fill", -r * 1.1, -r * 0.15, r * 2.2, r * 0.35, r * 0.15, r * 0.15, 6)
  lg.circle("fill", r * 0.3, -r * 1.4, r * 0.22, 10)
  lg.pop()
end

-- a string of bulbs from (x0, y0) to (x1, y1), blinking in turn
local function lights(x0, y0, x1, y1, n, t, sag)
  lg.setColor(0.1, 0.15, 0.1, 1)
  lg.setLineWidth(2)
  local pts = {}
  for i = 0, n do
    local k = i / n
    pts[#pts + 1] = lerp(x0, x1, k)
    pts[#pts + 1] = lerp(y0, y1, k) + sin(k * pi) * (sag or 10)
  end
  lg.line(pts)
  lg.setBlendMode("add")
  for i = 0, n do
    local c = BULBS[i % #BULBS + 1]
    local on = (floor(t * 2) + i) % 3 ~= 0
    local x, y = pts[i * 2 + 1], pts[i * 2 + 2] + 5
    if on then
      lg.setColor(c[1], c[2], c[3], 0.35)
      lg.circle("fill", x, y, 9, 10)
    end
    lg.setColor(c[1], c[2], c[3], on and 1 or 0.35)
    lg.circle("fill", x, y, 3.5, 8)
  end
  lg.setBlendMode("alpha")
end

local function snowman(x, y, s, hat_brown)
  local body = hat_brown and {0.6, 0.45, 0.28} or {0.97, 0.97, 1}
  rgba(body)
  lg.circle("fill", x, y, 40 * s, 24)
  lg.circle("fill", x, y - 56 * s, 30 * s, 24)
  lg.circle("fill", x, y - 100 * s, 22 * s, 20)
  if hat_brown then
    lg.setColor(0.45, 0.32, 0.18, 1)
    lg.setLineWidth(2)
    for i = 1, 12 do
      local a = i * 0.9
      lg.circle("line", x + cos(a) * 18 * s, y - 50 * s + sin(a * 1.3) * 60 * s, 12 * s, 8)
    end
    lg.setColor(0.4, 0.26, 0.12, 1)
    lg.ellipse("fill", x, y - 120 * s, 30 * s, 6 * s, 16)
    lg.rectangle("fill", x - 16 * s, y - 140 * s, 32 * s, 20 * s, 4, 4, 4)
  else
    lg.setColor(0.1, 0.1, 0.12, 1)
    lg.rectangle("fill", x - 16 * s, y - 140 * s, 32 * s, 24 * s)
    lg.rectangle("fill", x - 24 * s, y - 118 * s, 48 * s, 6 * s)
    lg.setColor(1, 0.5, 0.1, 1)
    lg.polygon("fill", x, y - 100 * s, x + 22 * s, y - 96 * s, x, y - 94 * s)
  end
  lg.setColor(0.1, 0.1, 0.12, 1)
  lg.circle("fill", x - 8 * s, y - 106 * s, 3 * s, 6)
  lg.circle("fill", x + 8 * s, y - 106 * s, 3 * s, 6)
  for i = 0, 2 do lg.circle("fill", x, y - 66 * s + i * 14 * s, 3 * s, 6) end
  lg.setColor(0.8, 0.1, 0.12, 1)
  lg.rectangle("fill", x - 30 * s, y - 82 * s, 60 * s, 10 * s, 4, 4, 4)
  lg.rectangle("fill", x + 14 * s, y - 82 * s, 10 * s, 30 * s, 3, 3, 4)
end

local function present(x, y, w, h, c, ribbon)
  rgba(c)
  lg.rectangle("fill", x, y, w, h, 3, 3, 4)
  rgba(ribbon)
  lg.rectangle("fill", x + w / 2 - 4, y, 8, h)
  lg.rectangle("fill", x, y + h / 2 - 4, w, 8)
  lg.ellipse("fill", x + w / 2 - 8, y - 4, 9, 6, 10)
  lg.ellipse("fill", x + w / 2 + 8, y - 4, 9, 6, 10)
end

local function xmas_tree(x, base, s, t, lit, ornaments)
  lg.setColor(0.4, 0.25, 0.12, 1)
  lg.rectangle("fill", x - 14 * s, base - 40 * s, 28 * s, 40 * s)
  for i, w in ipairs({{150, 0}, {120, 90}, {90, 170}, {60, 240}}) do
    lg.setColor(0.1, 0.42 + i * 0.03, 0.2, 1)
    lg.polygon("fill", x - w[1] * s, base - 40 * s - w[2] * s, x + w[1] * s, base - 40 * s - w[2] * s, x, base - 40 * s - (w[2] + 130) * s)
  end
  if ornaments then
    for i, o in ipairs(S.ornaments) do
      if i <= ornaments then
        local c = BULBS[i % #BULBS + 1]
        rgba(c)
        lg.circle("fill", x + o[1] * s, base + o[2] * s, 8 * s, 10)
        lg.setColor(1, 1, 1, 0.6)
        lg.circle("fill", x + o[1] * s - 2 * s, base + o[2] * s - 3 * s, 2.5 * s, 6)
      end
    end
  end
  if lit then
    lg.setBlendMode("add")
    for i, o in ipairs(S.tlights) do
      local c = BULBS[i % #BULBS + 1]
      local on = (floor(t * 2.5) + i) % 4 ~= 0
      lg.setColor(c[1], c[2], c[3], on and 0.9 or 0.2)
      lg.circle("fill", x + o[1] * s, base + o[2] * s, 3 * s, 6)
    end
    lg.setBlendMode("alpha")
    C.fx.glow(x, base - 410 * s, 60 * s, 60 * s, 1, 0.9, 0.4, 0.6)
    lg.setColor(1, 0.85, 0.25, 1)
    L.star(x, base - 410 * s, 26 * s, sin(t) * 0.1)
  end
end

-- ------------------------------------------------------------------ the scenes
local D = {}

local function snowfall(dense)
  local b = S.snowb
  b:clear()
  for i, f in ipairs(S.snow) do
    if i <= (dense or #S.snow) then
      b:setColor(1, 1, 1, f[4])
      b:add(f[1], f[2], 0, f[3], f[3], 8, 8)
    end
  end
  lg.setColor(1, 1, 1, 1)
  lg.draw(b)
end

local street_live                     -- (below)
-- the painted picture for a scene, if the SD card has it: drawn, true
local function art(name, a)
  local img = S.art[name]
  if not img then return false end
  lg.setColor(1, 1, 1, a or 1)
  lg.draw(img, 0, 0)
  return true
end

function D.open(lt, len)
  if not art("open") then G:gradient(0, 0, W, H, {0.03, 0.05, 0.15}, {0.1, 0.15, 0.35}) end
  snowfall()
  local a = L.window(lt, 0.5, 4.5, 0.8)
  G:caption("PARTYCADE", 400, 54, 0xff4fd8, a)
  G:caption("PRESENTS", 472, 26, 0x6ef0c8, a)
  G:caption("CHRISTMAS", 430, 80, 0xff4040, L.window(lt, 4.8, 10, 0.8))
end

function D.street(lt, len)
  if art("street") then
    lights(130, 474, 640, 474, 26, S.t, 6)
    lights(250, 334, 520, 334, 14, S.t + 1, 4)
    for i = 0, 5 do
      local c = BULBS[i % #BULBS + 1]
      lg.setColor(c[1], c[2], c[3], (floor(S.t * 2) + i) % 2 == 0 and 1 or 0.4)
      lg.circle("fill", 250 + i * 10, 640 - (i % 3) * 25, 3, 6)
    end
    street_live()
    return
  end
  G:gradient(0, 0, W, 700, {0.03, 0.04, 0.14}, {0.12, 0.14, 0.32})
  for i, s in ipairs(S.stars) do
    lg.setColor(1, 1, 0.9, 0.4 + 0.4 * sin(S.t * 2 + i))
    lg.rectangle("fill", s[1], s[2], 2, 2)
  end
  lg.setColor(0.95, 0.93, 0.8, 1)
  lg.circle("fill", 640, 120, 36, 32)
  -- the house
  lg.setColor(0.35, 0.22, 0.18, 1)
  lg.rectangle("fill", 160, 470, 450, 260)
  lg.setColor(0.2, 0.14, 0.12, 1)
  lg.polygon("fill", 130, 480, 640, 480, 520, 330, 250, 330)
  lg.setColor(0.97, 0.97, 1, 1)
  lg.polygon("fill", 130, 480, 640, 480, 630, 466, 140, 466)
  lg.polygon("fill", 250, 330, 520, 330, 512, 340, 258, 340)
  lights(130, 474, 640, 474, 26, S.t, 6)
  lights(250, 334, 520, 334, 14, S.t + 1, 4)
  -- the window with the tree, the door with a wreath
  lg.setColor(1, 0.85, 0.5, 1)
  lg.rectangle("fill", 200, 540, 150, 120)
  lg.setColor(0.1, 0.35, 0.15, 1)
  lg.polygon("fill", 275, 548, 230, 655, 320, 655)
  for i = 0, 5 do
    local c = BULBS[i % #BULBS + 1]
    lg.setColor(c[1], c[2], c[3], (floor(S.t * 2) + i) % 2 == 0 and 1 or 0.4)
    lg.circle("fill", 250 + i * 10, 640 - (i % 3) * 25, 3, 6)
  end
  lg.setColor(0.25, 0.15, 0.1, 1)
  lg.setLineWidth(6)
  lg.rectangle("line", 200, 540, 150, 120)
  lg.line(275, 540, 275, 660)
  lg.setColor(0.45, 0.12, 0.1, 1)
  lg.rectangle("fill", 440, 580, 90, 150)
  lg.setColor(0.1, 0.4, 0.15, 1)
  lg.setLineWidth(10)
  lg.circle("line", 485, 620, 22, 20)
  lg.setColor(0.85, 0.1, 0.12, 1)
  lg.polygon("fill", 478, 640, 492, 640, 485, 650)
  -- the snowy yard
  G:gradient(0, 700, W, H, {0.85, 0.88, 0.98}, {0.7, 0.75, 0.9})
  lg.setColor(0.97, 0.97, 1, 1)
  lg.rectangle("fill", 0, 720, W, 8)
  snowman(110, 880, 1.1)
  street_live()
end

-- the yard's inflatables swaying, the snow
function street_live()
  local sw = sin(S.t * 1.4) * 0.06
  lg.push()
  lg.translate(560, 900)
  lg.rotate(sw)
  C.fx.chomper(0, -60, 54, -1, S.t * 0.3, 1)
  santa_hat(-6, -108, 30, 0.35)
  lg.pop()
  lg.push()
  lg.translate(380, 940)
  lg.rotate(-sw)
  L.longhorn_head(0, -40, 0.65, {0.75, 0.34, 0}, 1)
  santa_hat(4, -66, 18, -0.2)
  lg.pop()
  snowfall()
end

function D.sleigh(lt, len)
  local painted = art("sleigh")
  if not painted then
  G:gradient(0, 0, W, 800, {0.02, 0.03, 0.12}, {0.1, 0.12, 0.3})
  for i, s in ipairs(S.stars) do
    lg.setColor(1, 1, 0.9, 0.5 + 0.4 * sin(S.t * 2 + i))
    lg.rectangle("fill", s[1], s[2], 2, 2)
  end
  C.fx.glow(384, 330, 200, 200, 0.9, 0.9, 1, 0.25)
  lg.setColor(0.97, 0.95, 0.85, 1)
  lg.circle("fill", 384, 330, 130, 48)
  -- the rooftops below, the chimneys, the presents dropping
  for i = 0, 5 do
    local x = i * 140 - 20
    lg.setColor(0.08, 0.07, 0.14, 1)
    lg.rectangle("fill", x, 820 - (i % 2) * 30, 120, 260)
    lg.polygon("fill", x - 10, 820 - (i % 2) * 30, x + 130, 820 - (i % 2) * 30, x + 60, 760 - (i % 2) * 30)
    lg.rectangle("fill", x + 80, 760 - (i % 2) * 30, 18, 50)
    lg.setColor(0.95, 0.95, 1, 1)
    lg.polygon("fill", x - 10, 820 - (i % 2) * 30, x + 60, 760 - (i % 2) * 30, x + 130, 820 - (i % 2) * 30, x + 120, 826 - (i % 2) * 30, x + 60, 770 - (i % 2) * 30, x, 826 - (i % 2) * 30)
    lg.setColor(1, 0.85, 0.5, 0.9)
    lg.rectangle("fill", x + 20, 860, 24, 30)
    lg.rectangle("fill", x + 70, 860, 24, 30)
  end
  end
  -- the sleigh's path: across the moon, a long arc, twice
  local p = ((lt + 6) % 26) / 26
  local x = lerp(-300, W + 300, p)
  local y = 360 - sin(p * pi) * 120
  local tilt = cos(p * pi) * -0.15
  for i, c in ipairs(GHOSTS) do
    local gx = x + 90 + (4 - i) * 70
    local gy = y - 30 + sin(S.t * 6 + i) * 6 - (4 - i) * 16 * cos(p * pi)
    lg.setColor(0.55, 0.38, 0.2, 1)
    lg.setLineWidth(3)
    lg.line(gx - 8, gy - 26, gx - 16, gy - 46, gx - 24, gy - 40)
    lg.line(gx + 8, gy - 26, gx + 16, gy - 46, gx + 24, gy - 40)
    C.fx.ghost(gx, gy, 22, c, 1, S.t + i, false, false, 1)
    if i == 1 then
      C.fx.glow(gx + 24, gy - 2, 30, 30, 1, 0.1, 0.1, 0.8)
      lg.setColor(1, 0.25, 0.2, 1)
      lg.circle("fill", gx + 22, gy - 2, 7, 10)
    end
    lg.setColor(0.8, 0.7, 0.4, 0.7)
    lg.setLineWidth(1.5)
    lg.line(x + 40, y - 10, gx - 14, gy)
  end
  lg.push()
  lg.translate(x, y)
  lg.rotate(tilt)
  lg.setColor(0.75, 0.08, 0.1, 1)
  lg.polygon("fill", -60, -30, 40, -30, 60, 10, -50, 10)
  lg.setColor(1, 0.82, 0.3, 1)
  lg.setLineWidth(4)
  lg.line(-70, 22, 50, 22, 66, 8)
  lg.line(-40, 10, -40, 22)
  lg.line(20, 10, 20, 22)
  present(-50, -56, 30, 26, {0.2, 0.6, 0.3}, {1, 0.85, 0.2})
  C.fx.chomper(6, -46, 26, 1, S.t, 1)
  santa_hat(4, -70, 16, -0.25)
  lg.setColor(1, 1, 1, 1)
  lg.ellipse("fill", 10, -24, 16, 8, 12)
  lg.pop()
  if G.R:random() < 0.5 then G:spark(x - 60, y, -60, (G.R:random() - 0.5) * 30, 1.2, {1, 0.9, 0.6}, 5, 10, true) end
  snowfall(90)
end

function D.texas(lt, len)
  local painted = art("texas")
  if not painted then
  G:gradient(0, 0, W, 640, {0.3, 0.6, 0.95}, {0.85, 0.92, 1})
  C.fx.glow(620, 120, 140, 140, 1, 0.9, 0.5, 0.4)
  lg.setColor(1, 0.95, 0.7, 1)
  lg.circle("fill", 620, 120, 44, 32)
  G:gradient(0, 640, W, H, {0.75, 0.62, 0.38}, {0.6, 0.48, 0.28})
  -- the ranch gate and the sign
  lg.setColor(0.35, 0.22, 0.12, 1)
  lg.rectangle("fill", 40, 420, 18, 240)
  lg.rectangle("fill", 300, 420, 18, 240)
  lg.rectangle("fill", 30, 410, 300, 20)
  lg.setColor(0.97, 0.94, 0.85, 1)
  lg.rectangle("fill", 70, 470, 220, 70, 6, 6, 4)
  G:text("IT'S 72°", 70, 478, 28, {0.75, 0.15, 0.1}, 1, "center", 220)
  G:text("AND SUNNY", 70, 508, 22, {0.3, 0.3, 0.35}, 1, "center", 220)
  end
  -- the prickly pear in lights
  local px, py = 560, 760
  if not painted then
  lg.setColor(0.25, 0.5, 0.3, 1)
  for _, p in ipairs({{0, 0, 40, 54}, {-44, -64, 30, 40}, {40, -70, 32, 42}, {-10, -120, 26, 34}}) do
    lg.ellipse("fill", px + p[1], py + p[2], p[3], p[4], 20)
  end
  end
  lg.setBlendMode("add")
  for i = 0, 22 do
    local a = i * 0.7
    local c = BULBS[i % #BULBS + 1]
    local on = (floor(S.t * 2) + i) % 3 ~= 0
    lg.setColor(c[1], c[2], c[3], on and 1 or 0.3)
    lg.circle("fill", px + cos(a) * (20 + i * 2), py - 40 + sin(a) * 50 - i * 2, 3.5, 8)
  end
  lg.setBlendMode("alpha")
  -- the tumbleweed snowman, the armadillo, cowboy Santa riding through
  if not painted then snowman(420, 930, 0.9, true) end
  local ax = -60 + ((lt * 35) % (W + 120))
  lg.setColor(0.55, 0.48, 0.42, 1)
  lg.arc("fill", "pie", ax, 980, 26, pi, 2 * pi, 20)
  lg.polygon("fill", ax + 24, 976, ax + 40, 982, ax + 24, 982)
  santa_hat(ax + 6, 954, 12, -0.3)
  local rx = W + 100 - ((lt * 45) % (W + 300))
  lg.push()
  lg.translate(rx, 860)
  lg.scale(-1, 1)
  lg.setColor(0.45, 0.27, 0.15, 1)
  for i, lx in ipairs({-22, -12, 18, 28}) do
    lg.rectangle("fill", lx + sin(S.t * 8 + i * pi) * 3 - 3, 8, 6, 34)
  end
  lg.ellipse("fill", 0, 0, 36, 16, 20)
  lg.polygon("fill", 26, -8, 42, -34, 52, -30, 36, 4)
  lg.ellipse("fill", 52, -28, 12, 7, 12)
  lg.setColor(0.85, 0.1, 0.12, 1)
  lg.rectangle("fill", -12, -48, 26, 38, 6, 6, 4)
  lg.setColor(1, 1, 1, 1)
  lg.rectangle("fill", -12, -14, 26, 6)
  lg.ellipse("fill", 1, -56, 12, 10, 12)
  lg.setColor(0.95, 0.78, 0.62, 1)
  lg.circle("fill", 1, -64, 8, 12)
  lg.setColor(0.5, 0.32, 0.15, 1)
  lg.ellipse("fill", 1, -70, 20, 4, 12)
  lg.rectangle("fill", -8, -84, 18, 14, 3, 3, 4)
  lg.pop()
  local a = L.window(lt, 18, 40, 1.5)
  G:plate("MERRY CHRISTMAS, Y'ALL", 200, 34, 0xff4040, a)
end

function D.tree(lt, len)
  local painted = art("room")
  if not painted then
  G:gradient(0, 0, W, H, {0.25, 0.12, 0.1}, {0.15, 0.07, 0.06})
  lg.setColor(0.3, 0.16, 0.12, 1)
  for x = 0, W, 52 do lg.rectangle("fill", x, 0, 22, 760) end
  -- the fireplace and the stockings
  lg.setColor(0.55, 0.25, 0.18, 1)
  lg.rectangle("fill", 470, 520, 260, 260)
  lg.setColor(0.1, 0.06, 0.05, 1)
  lg.rectangle("fill", 520, 600, 160, 180)
  end
  C.fx.glow(600, 720, 120, 90, 1, 0.5, 0.15, 0.35 + 0.1 * sin(S.t * 8))
  lg.setColor(1, 0.5, 0.1, 0.7 + 0.3 * sin(S.t * 10))
  lg.polygon("fill", 560, 780, 600, 640 + sin(S.t * 7) * 10, 640, 780)
  lg.setColor(1, 0.85, 0.3, 0.8)
  lg.polygon("fill", 580, 780, 600, 690 + sin(S.t * 9) * 8, 620, 780)
  if not painted then
  lg.setColor(0.4, 0.2, 0.14, 1)
  lg.rectangle("fill", 450, 500, 300, 26)
  for i, name in ipairs({"PAC", "BLINKY", "PINKY", "INKY", "CLYDE"}) do
    local sx = 470 + (i - 1) * 56
    local c = i == 1 and {1, 0.86, 0.15} or GHOSTS[i - 1]
    lg.setColor(0.85, 0.1, 0.12, 1)
    lg.rectangle("fill", sx, 526, 34, 60)
    lg.polygon("fill", sx, 586, sx + 34, 586, sx + 50, 600, sx + 40, 612, sx, 600)
    lg.setColor(1, 1, 1, 1)
    lg.rectangle("fill", sx - 2, 526, 38, 14)
    rgba(c)
    lg.circle("fill", sx + 17, 560, 7, 10)
  end
  end
  -- the tree: ornaments hung one by one, then the lights, then the star
  local orn = floor(clamp((lt - 6) / 30, 0, 1) * #S.ornaments)
  xmas_tree(230, 900, 1.2, S.t, lt > 42, orn)
  if not painted then
  for i, p in ipairs({{80, 860, {0.2, 0.5, 0.9}}, {300, 880, {0.85, 0.15, 0.2}}, {170, 900, {0.3, 0.65, 0.3}}}) do
    present(p[1], p[2], 70, 50, p[3], {1, 0.85, 0.2})
  end
  end
  -- the ghosts hanging ornaments, Pac-Man with the star
  for i, c in ipairs(GHOSTS) do
    local gx = 230 + cos(S.t * 0.5 + i * 1.6) * 190
    local gy = 560 + sin(S.t * 0.7 + i) * 140
    C.fx.ghost(gx, gy, 24, c, gx < 230 and 1 or -1, S.t + i, false, false, 1)
  end
  if lt > 30 and lt < 44 then
    local k = clamp((lt - 30) / 12, 0, 1)
    local px, py = lerp(-60, 230, k), lerp(300, 380, k)
    C.fx.chomper(px, py, 30, 1, S.t, 1)
    lg.setColor(1, 0.85, 0.25, 1)
    L.star(px + 30, py - 40, 18)
  end
  G:draw_back()
  G:plate("O CHRISTMAS TREE", 120, 34, 0x5fd16a, L.window(lt, 46, 70, 1.5))
end

function D.cookies(lt, len)
  local painted = art("cookies")
  if not painted then
  G:gradient(0, 0, W, H, {0.95, 0.88, 0.75}, {0.85, 0.7, 0.55})
  lg.setColor(0.6, 0.4, 0.25, 1)
  lg.rectangle("fill", 0, 620, W, 404)
  -- the plate: the cookies going one by one, the gingerbread men, the milk
  lg.setColor(0.95, 0.95, 0.97, 1)
  lg.ellipse("fill", 300, 700, 200, 70, 40)
  end
  local left = 8 - floor(clamp((lt - 6) / 40, 0, 1) * 7)
  for i = 1, 8 do
    if i <= left then
      local a = i / 8 * 2 * pi
      local x, y = 300 + cos(a) * 110, 690 + sin(a) * 36
      lg.setColor(0.8, 0.55, 0.3, 1)
      lg.ellipse("fill", x, y, 34, 14, 16)
      lg.setColor(0.3, 0.18, 0.1, 1)
      for k = 0, 2 do lg.circle("fill", x - 12 + k * 12, y - 3 + (k % 2) * 5, 3, 6) end
    end
  end
  for i = 0, painted and -1 or 1 do
    local x = 250 + i * 100
    lg.setColor(0.7, 0.42, 0.2, 1)
    lg.circle("fill", x, 640, 18, 14)
    lg.rectangle("fill", x - 16, 652, 32, 40, 8, 8, 6)
    lg.rectangle("fill", x - 30, 656, 60, 12, 6, 6, 6)
    lg.setColor(1, 1, 1, 1)
    lg.setLineWidth(2)
    lg.line(x - 10, 676, x + 10, 676)
    lg.circle("fill", x - 6, 636, 2, 6)
    lg.circle("fill", x + 6, 636, 2, 6)
  end
  lg.setColor(0.95, 0.97, 1, painted and 0 or 0.9)
  lg.rectangle("fill", 560, 560, 90, 150, 8, 8, 6)
  lg.setColor(1, 1, 1, 1)
  lg.rectangle("fill", 566, 600 + clamp((lt - 20) * 2, 0, 60), 78, 104 - clamp((lt - 20) * 2, 0, 60))
  -- the note for Santa
  lg.setColor(1, 1, 0.94, painted and 0 or 1)
  lg.push()
  lg.translate(560, 800)
  lg.rotate(-0.1)
  lg.rectangle("fill", -10, -10, 190, 120)
  lg.pop()
  G:text("DEAR SANTA,", 556, 794, 20, {0.3, 0.2, 0.4}, 1, "left", 190)
  G:text("WE WERE GOOD.", 556, 820, 20, {0.3, 0.2, 0.4}, 1, "left", 190)
  G:text("MOSTLY.", 556, 846, 20, {0.3, 0.2, 0.4}, 1, "left", 190)
  -- a ghost sneaking in for one, now and then
  local cyc = lt % 8
  if cyc < 4 then
    local c = GHOSTS[floor(lt / 8) % 4 + 1]
    local k = sin(cyc / 4 * pi)
    C.fx.ghost(lerp(-40, 200, k), 560, 34, c, 1, S.t, false, false, 1)
  end
end

function D.silent(lt, len)
  local painted = art("silent")
  if not painted then
  G:gradient(0, 0, W, 760, {0.01, 0.02, 0.08}, {0.08, 0.1, 0.25})
  for i, s in ipairs(S.stars) do
    lg.setColor(1, 1, 0.9, 0.4 + 0.4 * sin(S.t + i))
    lg.rectangle("fill", s[1], s[2], 2, 2)
  end
  end
  C.fx.glow(560, 160, 120, 120, 1, 0.95, 0.7, 0.5)
  lg.setColor(1, 0.97, 0.8, 1)
  L.star(560, 160, 16, 0)
  -- the town asleep: snowy roofs, warm windows, the steeple
  if painted then snowfall(160) return end
  for i, h in ipairs({{20, 120, 640}, {150, 110, 660}, {270, 90, 620}, {380, 140, 650}, {540, 120, 670}, {670, 100, 640}}) do
    lg.setColor(0.08, 0.08, 0.16, 1)
    lg.rectangle("fill", h[1], h[3], h[2], 760 - h[3] + 100)
    lg.polygon("fill", h[1] - 8, h[3], h[1] + h[2] + 8, h[3], h[1] + h[2] / 2, h[3] - 50)
    lg.setColor(0.95, 0.95, 1, 1)
    lg.polygon("fill", h[1] - 8, h[3], h[1] + h[2] / 2, h[3] - 50, h[1] + h[2] + 8, h[3], h[1] + h[2], h[3] + 6, h[1] + h[2] / 2, h[3] - 40, h[1], h[3] + 6)
    if (i + floor(lt / 9)) % 3 ~= 0 then
      lg.setColor(1, 0.8, 0.45, 0.9)
      lg.rectangle("fill", h[1] + 20, h[3] + 40, 24, 30)
    end
  end
  lg.setColor(0.1, 0.09, 0.18, 1)
  lg.rectangle("fill", 440, 420, 60, 240)
  lg.polygon("fill", 430, 420, 510, 420, 470, 300)
  lg.setColor(1, 0.85, 0.5, 0.8)
  lg.rectangle("fill", 458, 470, 24, 40)
  G:gradient(0, 740, W, H, {0.8, 0.85, 0.97}, {0.6, 0.65, 0.85})
  snowfall(160)
end

function D.finale(lt, len)
  if not art("finale") then G:gradient(0, 0, W, H, {0.02, 0.03, 0.1}, {0.12, 0.05, 0.08}) end
  G:draw_back()
  G:caption("MERRY CHRISTMAS", 360, 70, 0xff4040, L.window(lt, 0.5, len, 1))
  G:caption("AND A HAPPY NEW YEAR", 460, 34, 0x5fd16a, L.window(lt, 2, len, 1))
  C.fx.chomper(260, 700, 40, 1, S.t, 1)
  santa_hat(256, 650, 22, -0.3)
  for i, c in ipairs(GHOSTS) do C.fx.ghost(340 + i * 60, 700 + sin(S.t * 4 + i) * 8, 26, c, -1, S.t + i, false, false, 1) end
  snowfall(120)
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
  S.art = {}
  for _, n in ipairs({"open", "street", "sleigh", "texas", "room", "cookies", "silent", "finale"}) do
    S.art[n] = G:art("christmas", n)
  end
  local R = G.R
  S.snow = {}
  for i = 1, 240 do
    S.snow[i] = {R:random() * W, R:random() * H, 0.25 + R:random() * 0.5, 0.5 + R:random() * 0.5, 30 + R:random() * 50}
  end
  S.snowb = G:track(lg.newSpriteBatch(G.dot, 260, "stream"))
  S.stars = {}
  for i = 1, 80 do S.stars[i] = {R:random() * W, R:random() * 600} end
  S.ornaments, S.tlights = {}, {}
  for i = 1, 24 do
    local h = R:random() * 360
    local w = (1 - h / 400) * 130
    S.ornaments[i] = {(R:random() * 2 - 1) * w * 0.85, -60 - h}
  end
  for i = 1, 60 do
    local h = R:random() * 380
    local w = (1 - h / 410) * 140
    S.tlights[i] = {(R:random() * 2 - 1) * w * 0.9, -50 - h}
  end
  for _, s in ipairs(SCENES) do if s[4] then G:label(s[4], 56, 0xffffff) end end
  for _, l in ipairs({{"PARTYCADE", 54, 0xff4fd8}, {"PRESENTS", 26, 0x6ef0c8}, {"CHRISTMAS", 80, 0xff4040},
                      {"MERRY CHRISTMAS", 70, 0xff4040}, {"AND A HAPPY NEW YEAR", 34, 0x5fd16a},
                      {"MERRY CHRISTMAS, Y'ALL", 34, 0xff4040}, {"O CHRISTMAS TREE", 34, 0x5fd16a}}) do
    G:label(l[1], l[2], l[3])
  end
end

function M.act() return S and scene_at(S.t)[2] or "open" end
function M.music() return S and scene_at(S.t)[3] or "xm_bells" end

function M.update(dt)
  if not S then return false end
  G:step(dt)
  S.t = G.t
  local sc, lt = scene_at(S.t)
  -- the snow: falling, drifting, round again from the top
  for _, f in ipairs(S.snow) do
    f[2] = f[2] + f[5] * dt
    f[1] = f[1] + sin(S.t * 0.8 + f[5]) * 12 * dt
    if f[2] > H + 10 then f[2] = -10 f[1] = G.R:random() * W end
  end
  if sc[2] == "sleigh" then
    -- a present down a chimney now and then
    if floor((lt - dt) / 5) ~= floor(lt / 5) then
      local p = ((lt + 6) % 26) / 26
      local x = lerp(-300, W + 300, p)
      if x > 0 and x < W then
        for i = 1, 10 do G:spark(x, 380, (G.R:random() - 0.5) * 40, 120 + G.R:random() * 60, 1.2, BULBS[i % #BULBS + 1], 6, 200, true) end
      end
    end
  end
  if sc[2] == "tree" and lt - dt < 42 and lt >= 42 then
    C.sfx("power")
    for i = 1, 40 do
      local a = i / 40 * 2 * pi
      G:spark(230, 900 - 410 * 1.2, cos(a) * 160, sin(a) * 160, 1, {1, 0.85, 0.3}, 6, 60, true)
    end
  end
  if sc[2] == "finale" then
    S.fw = (S.fw or 0) - dt
    if S.fw <= 0 then
      S.fw = 0.5 + G.R:random() * 0.6
      G:rocket(120 + G.R:random() * 520, 120 + G.R:random() * 200,
               {from = 1024, colours = {{1, 0.2, 0.2}, {0.2, 0.9, 0.3}, {1, 0.85, 0.3}, {1, 1, 1}}})
    end
  end
  return S.t >= LEN
end

function M.draw()
  if not S then return end
  local sc, lt, len = scene_at(S.t)
  D[sc[2]](lt, len)
  if sc[2] ~= "tree" and sc[2] ~= "finale" then G:draw_back() end
  G:draw_front()
  if sc[4] then
    G:plate(sc[4], 30, 56, 0xffffff, L.window(lt, 1.5, 9, 1))
    local b = L.window(lt, 2, len - 1.5, 1)
    lg.setColor(0.02, 0.02, 0.06, 0.55 * b)
    lg.rectangle("fill", 0, H - 50, W, 50)
    G:text(sc[5], 0, H - 38, 20, {1, 0.85, 0.85}, b)
  end
  local f = 1 - min(lt / 1.2, (len - lt) / 1.2, 1)
  if f > 0 then
    lg.setColor(0, 0, 0, f)
    lg.rectangle("fill", 0, 0, W, H)
  end
end

return M
