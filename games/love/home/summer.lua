-- Summer: a Central Texas summer, eight minutes (June to August in AUTO's rotation):
--   0:00  PARTYCADE PRESENTS ... SUMMER                                             (Lake Day)
--   0:08  Lake Travis: limestone cliffs, boats and their wakes, a sailboat, Pac-Man on a float, the ghosts on a
--         pontoon, a cannonball off the cliff
--   1:30  Barton Springs: 68 degrees all year (one ghost shivering), the diving board, the hill  (Springs Bossa)
--   2:40  Snow cones: the stand, rainbow syrup, the thermometer at 104, melting       (Sno-Cone Shuffle)
--   3:40  Tubing the river: the cast in inner tubes floating by, cypress trees, a turtle on a log  (Lazy River)
--   5:00  The summer storm: clouds, rain, lightning; then the rainbow                 (Thunderstorm)
--   6:00  Fireflies: dusk on the porch, fireflies, the stars coming out               (Firefly Night)
--   7:20  SUMMER IN TEXAS
local lg = love.graphics
local L = require("showlib")
local M = {}
local C, G
local W, H = 768, 1024
local LEN = 480
M.LEN = LEN
local sin, cos, floor, min, max, abs, pi = math.sin, math.cos, math.floor, math.min, math.max, math.abs, math.pi
local clamp, ease, lerp, mix = L.clamp, L.ease, L.lerp, L.mix

local SCENES = {
  {0, "open", "su_lake"},
  {8, "lake", "su_lake", "LAKE TRAVIS", "LIMESTONE CLIFFS  ·  BOATS  ·  ONE CANNONBALL"},
  {90, "springs", "su_bossa", "BARTON SPRINGS", "68 DEGREES ALL YEAR ROUND"},
  {160, "snocone", "su_shuffle", "SNOW CONES", "FASTER, IT'S MELTING"},
  {220, "tubing", "su_lazy", "TUBING THE RIVER", "NOWHERE TO BE  ·  ALL AFTERNOON TO GET THERE"},
  {300, "storm", "su_storm", "SUMMER STORM", "FIFTEEN MINUTES OF RAIN  ·  THEN BACK TO 100"},
  {360, "fireflies", "su_fireflies", "FIREFLIES", "DUSK ON THE PORCH"},
  {440, "finale", "su_lake"},
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
local SUN = {1, 0.92, 0.5}

local function sun(x, y, r)
  C.fx.glow(x, y, r * 3.5, r * 3.5, 1, 0.85, 0.4, 0.5)
  rgba(SUN)
  lg.circle("fill", x, y, r, 40)
end

local function water_lines(y0, y1, t, a)
  lg.setColor(1, 1, 1, a or 0.3)
  for i = 0, floor((y1 - y0) / 22) do
    local y = y0 + i * 22
    local x = ((i * 113 + t * (20 + i % 4 * 6)) % (W + 120)) - 60
    lg.rectangle("fill", x, y, 40 + (i % 5) * 16, 2)
  end
end

-- someone in an inner tube (a ring, them in the middle)
local function tube(x, y, s, who, t)
  lg.setColor(0.15, 0.15, 0.18, 1)
  lg.ellipse("fill", x, y, 40 * s, 16 * s, 24)
  lg.setColor(0.3, 0.3, 0.34, 1)
  lg.ellipse("fill", x, y - 3 * s, 34 * s, 12 * s, 24)
  if who == 0 then C.fx.chomper(x, y - 18 * s, 20 * s, 1, t * 0.3, 1)
  else C.fx.ghost(x, y - 20 * s, 18 * s, GHOSTS[who], 1, t + who, false, false, 1) end
  lg.setColor(0.15, 0.15, 0.18, 1)
  lg.ellipse("fill", x, y + 4 * s, 40 * s, 10 * s, 24)
end

local D = {}

function D.open(lt, len)
  G:gradient(0, 0, W, H, {0.2, 0.55, 0.95}, {1, 0.85, 0.55})
  sun(384, 330, 90)
  local a = L.window(lt, 0.4, 4, 0.7)
  G:caption("PARTYCADE", 560, 54, 0xff4fd8, a)
  G:caption("PRESENTS", 632, 26, 0x6ef0c8, a)
  G:caption("SUMMER", 600, 96, 0xffd23f, L.window(lt, 4.2, 8, 0.7))
end

function D.lake(lt, len)
  G:gradient(0, 0, W, 520, {0.2, 0.5, 0.95}, {0.75, 0.9, 1})
  sun(620, 110, 46)
  -- the hills across the lake, the cliffs on the right
  lg.setColor(0.35, 0.5, 0.3, 1)
  lg.ellipse("fill", 200, 520, 300, 70, 32)
  lg.ellipse("fill", 560, 520, 260, 60, 32)
  G:gradient(0, 520, W, H, {0.15, 0.55, 0.6}, {0.05, 0.35, 0.45})
  lg.setColor(0.88, 0.84, 0.72, 1)
  lg.polygon("fill", 520, 520, 768, 400, 768, 760, 620, 760, 560, 640)
  lg.setColor(0.78, 0.74, 0.62, 1)
  for i = 0, 4 do lg.rectangle("fill", 560 + i * 30, 470 + i * 50, 208 - i * 30, 4) end
  lg.setColor(0.25, 0.42, 0.22, 1)
  lg.ellipse("fill", 690, 400, 90, 30, 20)
  water_lines(540, 1000, S.t, 0.25)
  -- the sailboat far off; a speedboat and its wake
  local sx = ((S.t * 8) % (W + 200)) - 100
  lg.setColor(0.95, 0.95, 0.95, 1)
  lg.polygon("fill", sx, 520, sx + 4, 440, sx + 40, 520)
  lg.polygon("fill", sx - 4, 520, sx - 4, 460, sx - 30, 520)
  lg.setColor(0.3, 0.25, 0.2, 1)
  lg.rectangle("fill", sx - 34, 520, 76, 8)
  local bx = W + 200 - ((S.t * 90) % (W + 500))
  lg.setLineWidth(3)
  for i = 0, 5 do
    lg.setColor(1, 1, 1, 0.5 - i * 0.08)
    local d = 60 + i * 40
    lg.line(bx + d, 642 - d * 0.12, bx + d + 36, 642 - (d + 36) * 0.12)
    lg.line(bx + d, 652 + d * 0.14, bx + d + 36, 652 + (d + 36) * 0.14)
  end
  lg.setColor(0.95, 0.95, 0.95, 1)
  lg.polygon("fill", bx - 50, 636, bx + 50, 630, bx + 46, 650, bx - 40, 652)
  lg.setColor(0.8, 0.15, 0.15, 1)
  lg.rectangle("fill", bx - 10, 620, 30, 12, 4, 4, 4)
  -- the pontoon with the ghosts; Pac-Man on his donut float
  local px = 120 + sin(S.t * 0.2) * 40
  lg.setColor(0.7, 0.7, 0.75, 1)
  lg.rectangle("fill", px - 110, 800, 220, 14)
  lg.rectangle("fill", px - 110, 816, 220, 10)
  lg.setColor(0.2, 0.5, 0.8, 1)
  lg.rectangle("fill", px - 100, 740, 200, 8)
  for i = 1, 3 do C.fx.ghost(px - 80 + i * 40, 780 + sin(S.t * 2 + i) * 3, 20, GHOSTS[i], 1, S.t + i, false, false, 1) end
  local fx, fy = 460 + sin(S.t * 0.3) * 60, 900 + sin(S.t * 1.2) * 6
  lg.setColor(1, 0.6, 0.75, 1)
  lg.ellipse("fill", fx, fy, 70, 26, 24)
  lg.setColor(0.98, 0.9, 0.7, 1)
  lg.ellipse("fill", fx, fy - 4, 66, 22, 24)
  for i = 0, 7 do
    rgba(({{1, 0.3, 0.3}, {0.3, 0.6, 1}, {1, 0.9, 0.2}})[i % 3 + 1])
    lg.rectangle("fill", fx - 50 + i * 13, fy - 10 + (i % 2) * 6, 6, 3)
  end
  lg.setColor(0.2, 0.4, 0.6, 1)
  lg.ellipse("fill", fx, fy - 2, 24, 8, 16)
  C.fx.chomper(fx, fy - 26, 24, 1, S.t * 0.2, 1)
  lg.setColor(0.1, 0.1, 0.12, 1)
  lg.rectangle("fill", fx - 16, fy - 40, 32, 7, 3, 3, 4)
  -- the cannonball off the cliff: Clyde, every twenty seconds
  local c = (lt % 20)
  if c < 3 then
    local k = c / 1.4
    local gx, gy = 640 + k * 60, 470 + k * k * 220 - k * 120
    if k < 1 then C.fx.ghost(gx, gy, 20, GHOSTS[4], 1, S.t, false, false, 1) end
  end
end

function D.springs(lt, len)
  G:gradient(0, 0, W, 460, {0.25, 0.55, 0.95}, {0.8, 0.92, 1})
  -- the pecans, the grassy hill with towels
  for i, x in ipairs({90, 330, 640}) do L.live_oak(x, 500, 2.2 - i * 0.2, S.t + i) end
  G:gradient(0, 480, W, 600, {0.4, 0.62, 0.3}, {0.32, 0.55, 0.25})
  for i = 0, 6 do
    rgba(({{1, 0.3, 0.3}, {0.3, 0.6, 1}, {1, 0.9, 0.2}, {0.5, 0.9, 0.5}})[i % 4 + 1])
    lg.rectangle("fill", 40 + i * 104, 540 + (i % 2) * 20, 60, 24, 4, 4, 4)
  end
  -- the pool: cold, clear, the limestone bottom showing
  G:gradient(0, 600, W, H, {0.35, 0.75, 0.8}, {0.15, 0.55, 0.65})
  lg.setColor(0.9, 0.95, 0.9, 0.2)
  for i = 0, 18 do
    local x = (i * 57 + sin(S.t + i) * 20) % W
    lg.ellipse("fill", x, 650 + (i * 41) % 340, 30, 6, 12)
  end
  water_lines(610, 1000, S.t, 0.3)
  -- the diving board, the dive
  lg.setColor(0.9, 0.9, 0.92, 1)
  lg.rectangle("fill", 520, 590, 200, 12)
  lg.rectangle("fill", 690, 590, 20, 60)
  local d = lt % 12
  if d < 2.4 then
    local k = d / 2.4
    local gx, gy = lerp(560, 430, k), 570 - sin(k * pi) * 180 + k * 220
    C.fx.ghost(gx, gy, 32, GHOSTS[2], -1, S.t, false, false, 1)
  elseif d < 3.2 then
    for i = 1, 6 do G:spark(430, 790, (G.R:random() - 0.5) * 200, -120 - G.R:random() * 160, 0.8, {0.9, 0.98, 1}, 5, 500) end
  end
  -- the swimmer shivering, Pac-Man floating on his back, Clyde doing laps
  local sh = sin(S.t * 40) * 4
  C.fx.ghost(200 + sh, 770, 40, GHOSTS[3], 1, S.t, false, false, 1)
  G:text("B R R R", 100, 680, 30, {0.85, 0.95, 1}, 0.6 + 0.4 * abs(sin(S.t * 6)), "center", 200)
  local px = 420 + sin(S.t * 0.15) * 120
  C.fx.chomper(px, 900, 34, 1, -pi / 2, 1)
  lg.setColor(0.1, 0.1, 0.12, 1)
  lg.rectangle("fill", px - 18, 878, 36, 8, 3, 3, 4)
  local lap = (S.t * 60) % (2 * W)
  local lx = lap < W and lap or 2 * W - lap
  C.fx.ghost(lx, 680, 26, GHOSTS[4], lap < W and 1 or -1, S.t, false, false, 1)
  lg.setColor(0.25, 0.55, 0.65, 0.6)
  lg.rectangle("fill", 0, 692, W, 16)
  lg.rectangle("fill", 0, 794, W, 26)
  lg.rectangle("fill", 0, 918, W, 22)
  G:plate("IT'S 68°. IT'S ALWAYS 68°.", 150, 30, 0x9fd8ff, L.window(lt, 12, 40, 1.5))
end

function D.snocone(lt, len)
  G:gradient(0, 0, W, 640, {0.35, 0.6, 0.98}, {0.95, 0.9, 0.75})
  sun(120, 120, 60)
  -- the heat: wavy air
  lg.setColor(1, 1, 1, 0.08)
  for i = 0, 8 do
    local y = 520 + i * 14
    lg.rectangle("fill", sin(S.t * 3 + i) * 10, y, W, 3)
  end
  G:gradient(0, 640, W, H, {0.8, 0.72, 0.58}, {0.62, 0.55, 0.42})
  -- the stand
  lg.setColor(0.95, 0.95, 0.92, 1)
  lg.rectangle("fill", 160, 360, 448, 360)
  lg.setColor(0.25, 0.2, 0.3, 1)
  lg.rectangle("fill", 200, 440, 368, 140)
  -- Pac-Man behind the counter, in his paper hat, shaving the ice
  C.fx.chomper(384, 500 + abs(sin(S.t * 6)) * 6, 44, 1, S.t * 0.5, 1)
  lg.setColor(1, 1, 1, 1)
  lg.polygon("fill", 350, 466, 418, 466, 410, 446, 358, 446)
  for i = 0, 7 do
    if i % 2 == 0 then lg.setColor(0.9, 0.2, 0.4, 1) else lg.setColor(1, 1, 1, 1) end
    lg.polygon("fill", 140 + i * 61, 360, 201 + i * 61, 360, 196 + i * 61, 400, 145 + i * 61, 400)
  end
  G:text("SNO-BALLS", 160, 300, 44, {0.9, 0.2, 0.4}, 1, "center", 448)
  -- the syrup bottles
  local flavours = {{1, 0.15, 0.2}, {0.2, 0.4, 1}, {0.3, 0.9, 0.3}, {1, 0.8, 0.1}, {0.8, 0.3, 0.9}}
  for i, c in ipairs(flavours) do
    rgba(c)
    lg.rectangle("fill", 210 + (i - 1) * 66, 540, 30, 40, 4, 4, 4)
    lg.rectangle("fill", 218 + (i - 1) * 66, 526, 14, 16)
  end
  -- the cone, its rainbow, melting
  local melt = clamp((lt - 20) / 40, 0, 1)
  local cx, cy = 384, 860
  lg.setColor(0.95, 0.95, 0.97, 1)
  lg.polygon("fill", cx - 50, cy - 10, cx + 50, cy - 10, cx + 30, cy + 110, cx - 30, cy + 110)
  local top = 1 - melt * 0.6
  for i, c in ipairs(flavours) do
    rgba(c)
    lg.arc("fill", "pie", cx, cy - 10, 70 * top, pi + (i - 1) * pi / 5, pi + i * pi / 5, 8)
  end
  for i = 1, 3 do
    if melt > 0.2 then
      local c = flavours[i]
      rgba(c)
      lg.ellipse("fill", cx - 40 + i * 24, cy + 120 + ((S.t * 30 + i * 20) % 40), 4, 7, 8)
    end
  end
  -- the thermometer
  lg.setColor(0.95, 0.95, 0.95, 1)
  lg.rectangle("fill", 660, 400, 50, 280, 20, 20, 8)
  local temp = floor(96 + clamp(lt / 30, 0, 1) * 8)
  lg.setColor(0.9, 0.1, 0.1, 1)
  lg.circle("fill", 685, 660, 20, 16)
  lg.rectangle("fill", 677, 680 - (temp - 60) * 6, 16, (temp - 60) * 6 - 20)
  G:text(temp .. "°", 640, 360, 30, {0.9, 0.1, 0.1}, 1, "center", 90)
  -- the line of customers
  for i, c in ipairs(GHOSTS) do
    C.fx.ghost(80 + (i - 1) * 70 + (i > 2 and 400 or 0), 820 + sin(S.t * 3 + i) * 3, 22, c, i <= 2 and 1 or -1, S.t + i, false, false, 1)
  end
end

function D.tubing(lt, len)
  G:gradient(0, 0, W, 420, {0.3, 0.55, 0.95}, {0.8, 0.9, 1})
  -- the cypress trees along the banks
  for i, x in ipairs({40, 160, 620, 730}) do
    lg.setColor(0.35, 0.25, 0.18, 1)
    lg.polygon("fill", x - 14, 520, x + 14, 520, x + 6, 260, x - 6, 260)
    lg.setColor(0.18, 0.4, 0.2, 1)
    lg.ellipse("fill", x, 260, 50, 90, 20)
    lg.ellipse("fill", x - 20, 320, 40, 60, 20)
  end
  G:gradient(0, 420, W, 520, {0.4, 0.55, 0.3}, {0.3, 0.45, 0.22})
  G:gradient(0, 500, W, H, {0.3, 0.6, 0.55}, {0.18, 0.45, 0.42})
  water_lines(520, 1000, S.t * 0.6, 0.3)
  -- the log, the turtle sunning
  lg.setColor(0.4, 0.3, 0.2, 1)
  lg.rectangle("fill", 520, 560, 200, 26, 12, 12, 6)
  lg.setColor(0.35, 0.45, 0.25, 1)
  lg.ellipse("fill", 620, 552, 28, 14, 16)
  lg.circle("fill", 650, 552 - (floor(S.t / 4) % 2) * 4, 7, 10)
  -- the flotilla: everyone in tubes, the cooler in its own
  local x0 = -260 + ((lt * 16) % (W + 600))
  for i = 0, 4 do
    local x = x0 - i * 120
    local y = 760 + sin(S.t * 0.8 + i) * 14 + (i % 2) * 70
    tube(x, y, 1.2, i, S.t)
  end
  local cx = x0 - 640
  lg.setColor(0.15, 0.15, 0.18, 1)
  lg.ellipse("fill", cx, 800, 40, 16, 24)
  lg.setColor(0.2, 0.45, 0.85, 1)
  lg.rectangle("fill", cx - 24, 768, 48, 30, 4, 4, 4)
  lg.setColor(1, 1, 1, 1)
  lg.rectangle("fill", cx - 24, 768, 48, 8, 4, 4, 4)
end

function D.storm(lt, len)
  local k = clamp(lt / 12, 0, 1) * clamp((len - 14 - lt) / 6, 0, 1)
  G:gradient(0, 0, W, 640, mix({0.3, 0.55, 0.95}, {0.2, 0.22, 0.28}, k), mix({0.8, 0.9, 1}, {0.4, 0.42, 0.45}, k))
  G:gradient(0, 640, W, H, mix({0.4, 0.62, 0.3}, {0.2, 0.3, 0.18}, k), mix({0.3, 0.5, 0.22}, {0.15, 0.22, 0.12}, k))
  -- the clouds rolling in
  lg.setColor(0.3, 0.32, 0.38, k)
  for i = 0, 6 do
    lg.ellipse("fill", i * 130 - 40 + sin(S.t * 0.2 + i) * 20, 120 + (i % 2) * 40, 140, 80, 24)
  end
  -- rain
  if k > 0.3 then
    lg.setColor(0.75, 0.8, 0.9, 0.5 * k)
    lg.setLineWidth(2)
    for i, d in ipairs(S.rain) do
      local y = (d[2] + S.t * 700) % 1100 - 60
      lg.line(d[1], y, d[1] - 6, y + 22)
    end
  end
  -- lightning now and then
  if k > 0.6 and (S.t % 7) < 0.12 then
    lg.setColor(1, 1, 1, 0.5)
    lg.rectangle("fill", 0, 0, W, H)
    lg.setColor(1, 1, 0.9, 1)
    lg.setLineWidth(4)
    local x, y = 300 + (floor(S.t / 7) % 3) * 120, 160
    local pts = {x, y}
    for i = 1, 7 do x = x + (G.R:random() - 0.5) * 50 y = y + 70 pts[#pts + 1] = x pts[#pts + 1] = y end
    lg.line(pts)
  end
  -- then the rainbow
  local rb = clamp((lt - (len - 16)) / 4, 0, 1)
  if rb > 0 then
    local cols = {{1, 0.2, 0.2}, {1, 0.55, 0.1}, {1, 0.9, 0.2}, {0.3, 0.8, 0.3}, {0.25, 0.5, 1}, {0.45, 0.25, 0.8}}
    lg.setLineWidth(16)
    for i, c in ipairs(cols) do
      lg.setColor(c[1], c[2], c[3], 0.6 * rb)
      lg.arc("line", "open", 384, 700, 420 - i * 16, pi, 2 * pi, 48)
    end
  end
  -- a ghost under an umbrella
  C.fx.ghost(384, 860, 30, GHOSTS[1], 1, S.t, false, false, 1)
  lg.setColor(0.2, 0.4, 0.9, 1)
  lg.arc("fill", "pie", 384, 800, 60, pi, 2 * pi, 20)
  lg.setColor(0.3, 0.3, 0.3, 1)
  lg.setLineWidth(3)
  lg.line(384, 800, 384, 840)
end

function D.fireflies(lt, len)
  local k = clamp(lt / 50, 0, 1)
  G:gradient(0, 0, W, 700, mix({0.4, 0.3, 0.6}, {0.03, 0.04, 0.12}, k), mix({1, 0.6, 0.35}, {0.1, 0.1, 0.25}, k))
  for i, s in ipairs(S.stars) do
    lg.setColor(1, 1, 0.9, k * (0.4 + 0.4 * sin(S.t + i)))
    lg.rectangle("fill", s[1], s[2], 2, 2)
  end
  G:gradient(0, 680, W, H, {0.12, 0.18, 0.1}, {0.06, 0.1, 0.05})
  L.live_oak(150, 720, 1.5, S.t)
  -- the porch and the swing
  lg.setColor(0.3, 0.22, 0.16, 1)
  lg.rectangle("fill", 420, 700, 348, 30)
  lg.rectangle("fill", 440, 480, 12, 220)
  lg.rectangle("fill", 740, 480, 12, 220)
  lg.rectangle("fill", 430, 470, 338, 16)
  local sw = sin(S.t * 0.8) * 10
  lg.setColor(0.45, 0.32, 0.22, 1)
  lg.setLineWidth(2)
  lg.line(520, 486, 520 + sw, 610)
  lg.line(680, 486, 680 + sw, 610)
  lg.rectangle("fill", 510 + sw, 610, 180, 14)
  C.fx.chomper(560 + sw, 588, 22, 1, 0, 1)
  C.fx.ghost(640 + sw, 590, 20, GHOSTS[2], -1, S.t, false, false, 1)
  lg.setColor(1, 0.85, 0.5, 0.8)
  lg.rectangle("fill", 600, 500, 40, 50)
  -- the fireflies
  lg.setBlendMode("add")
  for i, f in ipairs(S.flies) do
    local on = sin(S.t * f[3] + f[4])
    if on > 0.3 then
      local x = f[1] + sin(S.t * 0.3 + i) * 40
      local y = f[2] + cos(S.t * 0.4 + i) * 30
      local b = (on - 0.3) / 0.7 * k
      lg.setColor(0.6, 1, 0.2, 0.25 * b)
      lg.circle("fill", x, y, 22, 14)
      lg.setColor(0.8, 1, 0.3, 0.6 * b)
      lg.circle("fill", x, y, 9, 10)
      lg.setColor(1, 1, 0.75, b)
      lg.circle("fill", x, y, 4, 8)
    end
  end
  lg.setBlendMode("alpha")
end

function D.finale(lt, len)
  G:gradient(0, 0, W, H, {0.25, 0.4, 0.8}, {1, 0.6, 0.35})
  sun(384, 640, 140)
  G:gradient(0, 760, W, H, {0.1, 0.2, 0.3}, {0.05, 0.12, 0.2})
  water_lines(770, 1000, S.t, 0.3)
  lg.setColor(0.18, 0.12, 0.1, 1)
  lg.rectangle("fill", 0, 836, 520, 18)
  for i = 0, 5 do lg.rectangle("fill", 20 + i * 96, 850, 12, 80) end
  C.fx.chomper(110, 810, 26, 1, 0, 1)
  for i = 1, 4 do C.fx.ghost(150 + i * 66, 812 + sin(S.t * 2 + i) * 2, 24, GHOSTS[i], 1, S.t + i, false, false, 1) end
  G:caption("SUMMER", 260, 96, 0xffd23f, L.window(lt, 0.5, len, 1))
  G:caption("IN TEXAS", 380, 44, 0xffffff, L.window(lt, 1, len, 1))
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
  S.stars, S.rain, S.flies = {}, {}, {}
  for i = 1, 90 do S.stars[i] = {R:random() * W, R:random() * 640} end
  for i = 1, 140 do S.rain[i] = {R:random() * W, R:random() * 1100} end
  for i = 1, 40 do S.flies[i] = {R:random() * W, 300 + R:random() * 600, 1 + R:random() * 2, R:random() * 6} end
  for _, s in ipairs(SCENES) do if s[4] then G:label(s[4], 56, 0xffffff) end end
  for _, l in ipairs({{"PARTYCADE", 54, 0xff4fd8}, {"PRESENTS", 26, 0x6ef0c8}, {"SUMMER", 96, 0xffd23f},
                      {"IN TEXAS", 44, 0xffffff}, {"IT'S 68°. IT'S ALWAYS 68°.", 30, 0x9fd8ff}}) do
    G:label(l[1], l[2], l[3])
  end
end

function M.act() return S and scene_at(S.t)[2] or "open" end
function M.music() return S and scene_at(S.t)[3] or "su_lake" end

function M.update(dt)
  if not S then return false end
  G:step(dt)
  S.t = G.t
  local sc, lt = scene_at(S.t)
  if sc[2] == "lake" then
    local c = lt % 20
    if c - dt < 1.4 and c >= 1.4 then
      C.sfx("pop")
      for i = 1, 20 do G:spark(724, 600, (G.R:random() - 0.5) * 240, -150 - G.R:random() * 200, 1, {0.9, 0.98, 1}, 6, 500) end
    end
  end
  if sc[2] == "storm" and S.t % 7 < dt then C.sfx("thunder") end
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
    G:text(sc[5], 0, H - 38, 20, {1, 0.9, 0.6}, b)
  end
  local f = 1 - min(lt / 1.2, (len - lt) / 1.2, 1)
  if f > 0 then
    lg.setColor(0, 0, 0, f)
    lg.rectangle("fill", 0, 0, W, H)
  end
end

return M
