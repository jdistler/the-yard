-- Texas: A Day Across Texas. Home's homage to the state (sincere, not satire), ten minutes from sunrise on the
-- Gulf to the stars over Big Bend, a scene for each place, with a fade between:
--   0:00  the Lone Star flag at first light                                   (Lone Star Sunrise)
--   0:12  the Gulf Coast: Galveston at sunrise, pelicans, a shrimp boat, the pier
--   1:20  the Hill Country: bluebonnets and paintbrush, live oaks, a mockingbird, monarchs, an armadillo
--                                                                             (Bluebonnet Waltz)
--   2:20  Round Rock: the round rock in Brushy Creek (the Chisholm Trail's crossing), and the donuts
--   3:05  Austin: the Capitol up Congress Avenue, the Tower, live music, a taco truck   (Congress Avenue)
--   4:10  Fort Worth: the Stockyards' cattle drive, longhorns down the brick street  (Stockyards Swing)
--   5:15  San Antonio: the Alamo                                              (Remember)
--   5:55  Central Texas barbecue: post oak smoke, brisket on butcher paper     (Conjunto)
--   6:35  the Panhandle at golden hour: Palo Duro Canyon, a windmill, a pump jack, a supercell far off
--                                                                             (Red River Valley)
--   7:40  dusk at the Congress Avenue Bridge: the bats                        (Bat Flight)
--   8:30  Big Bend at night: the Chisos, the Milky Way, the Marfa lights      (Desert Night)
--   9:35  the Lone Star flag under the stars                                  (Lone Star)
-- Drawn from shapes; the flag is showlib's cloth.
local lg = love.graphics
local L = require("showlib")
local T = {}
local C, G
local W, H = 768, 1024
local LEN = 600
T.LEN = LEN
local sin, cos, floor, min, max, abs, pi = math.sin, math.cos, math.floor, math.min, math.max, math.abs, math.pi
local clamp, ease, lerp, mix = L.clamp, L.ease, L.lerp, L.mix
local steer, live_oak = L.steer, L.live_oak

-- {start, name, song, title, place}
local SCENES = {
  {0, "open", "tx_sunrise"},
  {12, "coast", "tx_sunrise", "THE GULF COAST", "GALVESTON  ·  SUNRISE"},
  {80, "hills", "tx_waltz", "THE HILL COUNTRY", "BLUEBONNETS  ·  INDIAN PAINTBRUSH  ·  LIVE OAKS"},
  {140, "roundrock", "tx_waltz", "ROUND ROCK", "BRUSHY CREEK  ·  THE CHISHOLM TRAIL CROSSING"},
  {185, "austin", "tx_austin", "AUSTIN", "THE CAPITOL  ·  CONGRESS AVENUE"},
  {250, "stockyards", "tx_swing", "FORT WORTH", "THE STOCKYARDS  ·  THE CATTLE DRIVE"},
  {315, "alamo", "tx_alamo", "SAN ANTONIO", "THE ALAMO  ·  1836"},
  {355, "bbq", "tx_conjunto", "CENTRAL TEXAS BARBECUE", "POST OAK SMOKE  ·  LOW AND SLOW"},
  {395, "panhandle", "tx_redriver", "THE PANHANDLE", "PALO DURO CANYON  ·  THE HIGH PLAINS"},
  {460, "bats", "tx_bats", "CONGRESS AVENUE BRIDGE", "A MILLION AND A HALF BATS  ·  EVERY SUMMER NIGHT"},
  {510, "bigbend", "tx_desert", "BIG BEND", "THE CHISOS MOUNTAINS  ·  THE DARKEST SKIES IN TEXAS"},
  {575, "finale", "tx_lonestar"},
}
T.SEGMENTS = {}
for i, s in ipairs(SCENES) do
  if s[4] then T.SEGMENTS[#T.SEGMENTS + 1] = {s[1], s[4]} end
end
table.insert(T.SEGMENTS, {575, "THE LONE STAR"})
T.THUMB = 2

local S                                -- this showing
local function scene_at(t)
  local k = 1
  for i, s in ipairs(SCENES) do if t >= s[1] then k = i end end
  local s = SCENES[k]
  local e = SCENES[k + 1] and SCENES[k + 1][1] or LEN
  return s, t - s[1], e - s[1], k
end

-- ------------------------------------------------------------------ small things, drawn
local function rgba(c, a) lg.setColor(c[1], c[2], c[3], a or 1) end

local function hills_poly(y0, amp, freq, phase, col, a, ybot)
  local pts = {0, ybot or H}
  for x = 0, W, 24 do
    pts[#pts + 1] = x
    pts[#pts + 1] = y0 + sin(x * freq + phase) * amp + sin(x * freq * 2.3 + phase * 1.7) * amp * 0.35
  end
  pts[#pts + 1] = W
  pts[#pts + 1] = ybot or H
  rgba(col, a)
  -- (concave: drawn as strips)
  for i = 3, #pts - 4, 2 do
    lg.polygon("fill", pts[i], pts[i + 1], pts[i + 2], pts[i + 3], pts[i + 2], ybot or H, pts[i], ybot or H)
  end
end

local function bird_v(x, y, s, flap, c, a)
  rgba(c, a)
  lg.setLineWidth(2)
  local f = sin(flap) * 4 * s
  lg.line(x - 8 * s, y - f, x - 3 * s, y, x, y + 1 * s, x + 3 * s, y, x + 8 * s, y - f)
end

-- A brown pelican gliding (facing right), wings beating slowly.
local function pelican(x, y, s, flap)
  local wing = sin(flap) * 0.6
  lg.setColor(0.35, 0.28, 0.22, 1)
  lg.push()
  lg.translate(x, y)
  lg.scale(s, s)
  lg.polygon("fill", -6, -2, 10, -40 * (0.5 + wing), 26, -36 * (0.5 + wing), 14, -2)
  lg.ellipse("fill", 0, 0, 22, 7, 16)
  lg.setColor(0.92, 0.88, 0.78, 1)
  lg.circle("fill", 22, -6, 6, 12)
  lg.setColor(0.75, 0.55, 0.3, 1)
  lg.polygon("fill", 26, -8, 52, -2, 26, 0)
  lg.setColor(0.3, 0.24, 0.18, 1)
  lg.polygon("fill", -6, 0, 12, 34 * (0.5 - wing), 28, 30 * (0.5 - wing), 14, 2)
  lg.polygon("fill", -20, -2, -32, -6, -30, 4)
  lg.pop()
end

-- A cowboy on a horse (facing right), walking.
local function rider(x, y, s, step)
  lg.push()
  lg.translate(x, y)
  lg.scale(s, s)
  lg.setColor(0.45, 0.27, 0.15, 1)
  for i, lx in ipairs({-22, -12, 18, 28}) do
    local sw = sin(step + (i % 2) * pi) * 7
    lg.rectangle("fill", lx + sw * 0.5 - 3, 8, 6, 34)
  end
  lg.ellipse("fill", 0, 0, 36, 16, 20)
  lg.polygon("fill", 26, -8, 42, -34, 52, -30, 36, 4)
  lg.ellipse("fill", 52, -28, 12, 7, 12)
  lg.setColor(0.2, 0.12, 0.08, 1)
  lg.polygon("fill", -34, -4, -48, 16, -40, 18)
  -- the cowboy
  lg.setColor(0.25, 0.35, 0.6, 1)
  lg.rectangle("fill", -6, -40, 14, 30)
  lg.setColor(0.35, 0.3, 0.25, 1)
  lg.rectangle("fill", -2, -12, 8, 22)
  lg.setColor(0.95, 0.78, 0.62, 1)
  lg.circle("fill", 1, -48, 7, 12)
  lg.setColor(0.55, 0.38, 0.2, 1)
  lg.ellipse("fill", 1, -53, 16, 3, 12)
  lg.rectangle("fill", -6, -64, 14, 11, 3, 3, 4)
  lg.pop()
end

-- A monarch butterfly.
local function monarch(x, y, s, t)
  local w = abs(sin(t * 14))
  lg.setColor(0.95, 0.45, 0.05, 1)
  lg.ellipse("fill", x - 6 * s * w, y - 2 * s, 6 * s * w, 5 * s, 10)
  lg.ellipse("fill", x + 6 * s * w, y - 2 * s, 6 * s * w, 5 * s, 10)
  lg.ellipse("fill", x - 4 * s * w, y + 4 * s, 4 * s * w, 3.5 * s, 10)
  lg.ellipse("fill", x + 4 * s * w, y + 4 * s, 4 * s * w, 3.5 * s, 10)
  lg.setColor(0.1, 0.05, 0.05, 1)
  lg.rectangle("fill", x - 1, y - 4 * s, 2, 9 * s)
end

-- An armadillo trundling (facing right).
local function armadillo(x, y, s, t)
  local bob = abs(sin(t * 10)) * 1.5
  lg.setColor(0.55, 0.48, 0.42, 1)
  lg.arc("fill", "pie", x, y - bob, 22 * s, pi, 2 * pi, 20)
  lg.setColor(0.45, 0.38, 0.33, 1)
  lg.setLineWidth(2)
  for i = -2, 2 do lg.line(x + i * 6 * s, y - bob, x + i * 5 * s, y - bob - 19 * s + abs(i) * 3 * s) end
  lg.setColor(0.6, 0.52, 0.46, 1)
  lg.polygon("fill", x + 20 * s, y - bob - 4 * s, x + 34 * s, y - bob + 2 * s, x + 20 * s, y - bob + 2 * s)
  lg.ellipse("fill", x + 22 * s, y - bob - 9 * s, 3 * s, 5 * s, 8)
  lg.polygon("fill", x - 22 * s, y - bob - 2 * s, x - 38 * s, y - bob + 3 * s, x - 22 * s, y - bob + 2 * s)
  for i = 0, 1 do lg.rectangle("fill", x - 12 * s + i * 20 * s + sin(t * 10 + i * pi) * 2, y - bob, 4 * s, 5 * s) end
end

-- A music note (two, beamed, if double), drawn.
local function note(x, y, s, c, a, double)
  rgba(c, a)
  lg.ellipse("fill", x, y, 6 * s, 4.5 * s, 10)
  lg.rectangle("fill", x + 4 * s, y - 22 * s, 2 * s, 22 * s)
  if double then
    lg.ellipse("fill", x + 16 * s, y - 4 * s, 6 * s, 4.5 * s, 10)
    lg.rectangle("fill", x + 20 * s, y - 26 * s, 2 * s, 22 * s)
    lg.polygon("fill", x + 4 * s, y - 22 * s, x + 22 * s, y - 26 * s, x + 22 * s, y - 21 * s, x + 4 * s, y - 17 * s)
  else
    lg.polygon("fill", x + 6 * s, y - 22 * s, x + 14 * s, y - 14 * s, x + 6 * s, y - 16 * s)
  end
end

-- A mockingbird on a post, singing.
local function mockingbird(x, y, s, t)
  lg.setColor(0.55, 0.55, 0.55, 1)
  lg.ellipse("fill", x, y, 12 * s, 7 * s, 14)
  lg.circle("fill", x + 10 * s, y - 6 * s, 5 * s, 10)
  lg.setColor(0.35, 0.35, 0.37, 1)
  lg.polygon("fill", x - 8 * s, y - 2 * s, x - 26 * s, y - 10 * s + sin(t * 3) * 2, x - 22 * s, y + 2 * s)
  lg.setColor(0.95, 0.95, 0.95, 1)
  lg.rectangle("fill", x - 6 * s, y - 2 * s, 8 * s, 2 * s)
  lg.setColor(0.15, 0.15, 0.15, 1)
  local open = floor(t * 4) % 2 == 0 and 2 or 0
  lg.polygon("fill", x + 14 * s, y - 8 * s, x + 22 * s, y - 7 * s - open, x + 14 * s, y - 5 * s)
  lg.polygon("fill", x + 14 * s, y - 5 * s, x + 22 * s, y - 5 * s + open, x + 14 * s, y - 4 * s)
end

-- ------------------------------------------------------------------ the scenes
local D = {}                                  -- drawing, by scene name

-- The Lone Star at first light (the opening; the finale has its own sky)
local hills_live, austin_live                   -- (below)
-- the painted picture for a scene, if the SD card has it: drawn, true
local function art(name, a)
  local img = S.art[name]
  if not img then return false end
  lg.setColor(1, 1, 1, a or 1)
  lg.draw(img, 0, 0)
  return true
end

function D.open(lt, len)
  if art("open") then
    L.pole(150, 260, 905)
    S.flag:draw(155, 280, 470, 313, S.t, 0.55 + 0.1 * sin(S.t * 0.4), {0.95, 0.85, 0.82})
  else
    G:gradient(0, 0, W, H, {0.05, 0.05, 0.2}, {0.75, 0.4, 0.35})
    L.pole(150, 260, 900)
    S.flag:draw(155, 280, 470, 313, S.t, 0.55 + 0.1 * sin(S.t * 0.4), {0.95, 0.85, 0.82})
    hills_poly(900, 10, 0.006, 1, {0.05, 0.04, 0.08}, 1)
  end
  local a = L.window(lt, 0.5, 5, 0.8)
  G:brand(640, a)
  G:caption("PRESENTS", 712, 26, 0x6ef0c8, a)
  local b = L.window(lt, 5.2, 12, 0.8)
  G:caption("A DAY ACROSS", 650, 34, 0xffffff, b)
  G:caption("TEXAS", 700, 96, 0xffb347, b)
end

function D.coast(lt, len)
  local k = lt / len
  local painted = S.art.coast_dawn and S.art.coast_day
  local sy = lerp(590, 360, ease(k * 1.2))
  if painted then
    art("coast_dawn")
    art("coast_day", clamp(k * 1.4, 0, 1))
    -- the sun comes up over the painted sea: above the horizon only
    lg.setScissor(0, 0, W, 560)
    C.fx.glow(560, sy, 260, 200, 1, 0.65, 0.35, 0.5)
    lg.setColor(1, 0.85, 0.55, 1)
    lg.circle("fill", 560, sy, 44, 40)
    lg.setScissor()
  else
  local top, hor = mix({0.08, 0.1, 0.32}, {0.22, 0.45, 0.85}, k), mix({1, 0.55, 0.35}, {0.95, 0.8, 0.7}, k)
  G:gradient(0, 0, W, 560, top, hor)
  C.fx.glow(560, sy, 260, 200, 1, 0.65, 0.35, 0.5)
  lg.setColor(1, 0.85, 0.55, 1)
  lg.circle("fill", 560, sy, 44, 40)
  -- the sea, the sun's path on it
  G:gradient(0, 560, W, 860, mix({0.15, 0.25, 0.4}, {0.1, 0.35, 0.55}, k), {0.1, 0.45, 0.55})
  end
  lg.setBlendMode("add")
  for i = 0, 18 do
    local y = 566 + i * 15
    local w = (30 + i * 6) * (0.6 + 0.4 * sin(S.t * 2 + i * 1.3))
    lg.setColor(1, 0.7, 0.4, 0.35 * (1 - i / 22))
    lg.rectangle("fill", 560 - w / 2, y, w, 3)
  end
  lg.setBlendMode("alpha")
  -- the shrimp boat on the horizon, its outriggers out
  local bx = -120 + ((S.t - 12) * 9) % (W + 240)
  lg.setColor(0.12, 0.1, 0.14, 1)
  lg.polygon("fill", bx - 40, 556, bx + 42, 556, bx + 34, 568, bx - 32, 568)
  lg.rectangle("fill", bx - 6, 536, 22, 20)
  lg.rectangle("fill", bx + 2, 510, 3, 46)
  lg.setLineWidth(2)
  lg.line(bx + 3, 512, bx - 46, 540, bx - 50, 556)
  lg.line(bx + 3, 512, bx + 52, 540, bx + 56, 556)
  -- the pier, on the right
  if not painted then
  lg.setColor(0.25, 0.18, 0.14, 1)
  lg.rectangle("fill", 470, 742, 298, 10)
  for x = 480, 768, 34 do lg.rectangle("fill", x, 752, 6, 70) end
  lg.setColor(0.18, 0.13, 0.1, 1)
  for x = 480, 768, 68 do lg.rectangle("fill", x + 1, 718, 3, 24) end
  end
  -- waves coming in, the beach
  for i = 0, 2 do
    local y = 820 + i * 22
    local pts = {}
    for x = 0, W, 16 do
      pts[#pts + 1] = x
      pts[#pts + 1] = y + sin(x * 0.02 + S.t * (1.6 + i * 0.3) + i) * 5
    end
    lg.setColor(0.85, 0.95, 1, 0.55 - i * 0.12)
    lg.setLineWidth(3)
    lg.line(pts)
  end
  if not painted then
  G:gradient(0, 880, W, H, {0.86, 0.76, 0.58}, {0.92, 0.84, 0.66})
  lg.setColor(0.7, 0.6, 0.45, 0.5)
  lg.rectangle("fill", 0, 880, W, 12)
  -- the palm, left
  lg.setColor(0.35, 0.26, 0.18, 1)
  lg.setLineWidth(12)
  lg.line(60, 1024, 70, 900, 92, 780, 120, 690)
  for i = 0, 6 do
    local a = -pi + i * pi / 6 + sin(S.t * 1.2 + i) * 0.05
    lg.setColor(0.12, 0.35 + i * 0.02, 0.15, 1)
    lg.polygon("fill", 120, 690, 120 + cos(a) * 110, 690 + sin(a) * 50 + 30, 120 + cos(a + 0.12) * 70, 690 + sin(a + 0.12) * 30 + 14)
  end
  end
  -- pelicans gliding in a line, low over the water
  for i = 0, 4 do
    local px = -200 + ((S.t - 20) * 55) % (W + 500) - i * 70
    pelican(px, 650 + i * 10 + sin(S.t * 0.8 + i) * 6, 0.9, S.t * 1.6 + i * 0.7)
  end
  for i = 1, 4 do
    bird_v(200 + sin(S.t * 0.4 + i) * 160 + i * 70, 300 + cos(S.t * 0.5 + i * 2) * 50, 1, S.t * 6 + i, {0.2, 0.2, 0.25}, 0.8)
  end
end

function D.hills(lt, len)
  if art("hills") then
    hills_live(lt)
    return
  end
  G:gradient(0, 0, W, 620, {0.25, 0.5, 0.9}, {0.75, 0.88, 1})
  lg.setColor(1, 1, 1, 0.85)
  for i = 0, 2 do
    local x = (i * 300 + S.t * 8) % (W + 300) - 150
    lg.ellipse("fill", x, 140 + i * 50, 70, 24, 24)
    lg.ellipse("fill", x + 50, 130 + i * 50, 50, 30, 24)
    lg.ellipse("fill", x - 50, 145 + i * 50, 40, 18, 24)
  end
  hills_poly(560, 30, 0.007, 0.5, {0.45, 0.6, 0.65}, 1, 760)
  hills_poly(620, 26, 0.009, 2.1, {0.3, 0.52, 0.35}, 1, 800)
  hills_poly(690, 20, 0.011, 4.0, {0.25, 0.5, 0.22}, 1)
  live_oak(150, 700, 1.3, S.t)
  live_oak(610, 680, 1.0, S.t + 2)
  -- the bluebonnets and paintbrush (one batch, painted at the scene's start)
  lg.setColor(1, 1, 1, 1)
  lg.draw(S.flowers)
  -- a fence post, the mockingbird
  lg.setColor(0.4, 0.3, 0.2, 1)
  lg.rectangle("fill", 650, 760, 14, 90)
  hills_live(lt)
end

-- the Hill Country's live things: the mockingbird and its song, the monarchs, the armadillo
function hills_live(lt)
  mockingbird(657, 752, 1.4, S.t)
  for i = 0, 1 do
    local ph = (S.t * 0.7 + i / 2) % 1
    note(684 + ph * 30 + sin(ph * 6) * 6, 730 - ph * 70, 1, {1, 1, 1}, 0.85 * (1 - ph), i == 1)
  end
  for i = 1, 3 do
    monarch(100 + ((S.t * 30 + i * 250) % (W + 100)) - 50, 520 + sin(S.t * 1.3 + i) * 60 + i * 30, 1.6, S.t + i)
  end
  local ax = -60 + ((lt - 20) * 28)
  if ax > -60 and ax < W + 60 then armadillo(ax, 930, 1.2, S.t) end
end

function D.roundrock(lt, len)
  if lt < 26 and art("creek") then
    lg.setColor(0.8, 0.95, 1, 0.5)
    lg.setLineWidth(2)
    for i = 0, 14 do
      local y = 650 + i * 17
      local x = ((i * 97 + S.t * (40 + i * 3)) % (W + 120)) - 60
      if abs(y - 760) > 60 or abs(x - 384) > 140 then lg.line(x, y, x + 40 + (i % 3) * 20, y) end
    end
    lg.setColor(0.9, 0.97, 1, 0.7)
    for i = 0, 3 do
      local w = 120 + i * 18 + sin(S.t * 3 + i) * 4
      lg.ellipse("line", 384, 815, w, 14 + i * 4, 40)
    end
    return
  elseif lt >= 26 and art("donuts") then
    for i = 1, 3 do
      local k = ((S.t * 0.4 + i / 3) % 1)
      lg.setColor(1, 1, 1, 0.25 * (1 - k))
      lg.ellipse("fill", 210 + i * 110, 430 - k * 120, 16 + k * 10, 26 + k * 20, 16)
    end
    return
  end
  if lt < 26 then
    -- Brushy Creek: the round rock in the low-water crossing
    G:gradient(0, 0, W, 520, {0.3, 0.55, 0.9}, {0.8, 0.9, 1})
    hills_poly(470, 12, 0.008, 1.3, {0.22, 0.42, 0.2}, 1, 600)
    live_oak(90, 560, 1.1, S.t)
    live_oak(680, 540, 0.9, S.t + 1)
    G:gradient(0, 560, W, 640, {0.85, 0.82, 0.72}, {0.75, 0.72, 0.6})
    G:gradient(0, 640, W, 900, {0.25, 0.5, 0.55}, {0.15, 0.38, 0.45})
    lg.setColor(0.8, 0.95, 1, 0.5)
    lg.setLineWidth(2)
    for i = 0, 14 do
      local y = 650 + i * 17
      local x = ((i * 97 + S.t * (40 + i * 3)) % (W + 120)) - 60
      lg.line(x, y, x + 40 + (i % 3) * 20, y)
    end
    -- the rock, the water going round it
    lg.setColor(0.72, 0.68, 0.6, 1)
    lg.ellipse("fill", 384, 760, 110, 70, 40)
    lg.setColor(0.85, 0.82, 0.74, 1)
    lg.ellipse("fill", 360, 735, 70, 38, 30)
    lg.setColor(0.9, 0.97, 1, 0.7)
    for i = 0, 3 do
      local w = 120 + i * 18 + sin(S.t * 3 + i) * 4
      lg.ellipse("line", 384, 815, w, 14 + i * 4, 40)
    end
    G:gradient(0, 900, W, H, {0.78, 0.74, 0.62}, {0.65, 0.6, 0.48})
  else
    -- the donuts: a box of glazed ones, warm
    G:gradient(0, 0, W, H, {0.98, 0.88, 0.7}, {0.95, 0.72, 0.45})
    lg.setColor(0.98, 0.98, 0.96, 1)
    lg.rectangle("fill", 104, 420, 560, 360, 14, 14, 8)
    lg.setColor(0.85, 0.82, 0.78, 1)
    lg.polygon("fill", 104, 420, 664, 420, 620, 300, 148, 300)
    for r = 0, 1 do
      for c = 0, 2 do
        local x, y = 210 + c * 174, 520 + r * 160
        local sh = sin(S.t * 2 + r + c) * 0.08
        lg.setColor(0.86, 0.52, 0.18, 1)
        lg.ellipse("fill", x, y, 72, 62, 32)
        lg.setColor(1, 0.72 + sh, 0.3, 1)
        lg.ellipse("fill", x, y - 4, 66, 54, 32)
        lg.setColor(1, 1, 0.85, 0.5)
        lg.ellipse("fill", x - 24, y - 26, 20, 8, 12)
        lg.setColor(0.98, 0.98, 0.96, 1)
        lg.ellipse("fill", x, y - 2, 18, 14, 16)
      end
    end
    for i = 1, 3 do
      local k = ((S.t * 0.4 + i / 3) % 1)
      lg.setColor(1, 1, 1, 0.25 * (1 - k))
      lg.ellipse("fill", 210 + i * 110, 430 - k * 120, 16 + k * 10, 26 + k * 20, 16)
    end
  end
end

local function capitol(x, base)
  local stone = {0.86, 0.66, 0.6}
  local shade = {0.72, 0.52, 0.48}
  rgba(stone)
  lg.rectangle("fill", x - 300, base - 120, 600, 120)
  rgba(shade)
  for i = 0, 11 do lg.rectangle("fill", x - 280 + i * 48, base - 100, 18, 30) lg.rectangle("fill", x - 280 + i * 48, base - 54, 18, 30) end
  rgba(stone)
  lg.polygon("fill", x - 80, base - 120, x + 80, base - 120, x, base - 160)
  lg.rectangle("fill", x - 90, base - 250, 180, 130)
  rgba(shade)
  for i = 0, 7 do lg.rectangle("fill", x - 82 + i * 23, base - 240, 8, 110) end
  rgba(stone)
  lg.rectangle("fill", x - 100, base - 262, 200, 14)
  lg.arc("fill", "pie", x, base - 262, 98, pi, 2 * pi, 40)
  rgba(shade)
  lg.setLineWidth(2)
  for i = -3, 3 do lg.line(x + i * 26, base - 264, x + i * 12, base - 352 + abs(i) * 6) end
  rgba(stone)
  lg.rectangle("fill", x - 16, base - 390, 32, 34)
  lg.arc("fill", "pie", x, base - 390, 17, pi, 2 * pi, 16)
  lg.setColor(0.85, 0.75, 0.45, 1)
  lg.rectangle("fill", x - 3, base - 424, 6, 18)
  lg.circle("fill", x, base - 428, 4, 8)
end

function D.austin(lt, len)
  if art("austin") then
    austin_live(lt)
    return
  end
  G:gradient(0, 0, W, 700, {0.2, 0.48, 0.9}, {0.7, 0.85, 1})
  -- the skyline behind, the Tower to the right
  lg.setColor(0.55, 0.65, 0.8, 1)
  for i, b in ipairs({{20, 300}, {90, 360}, {150, 260}, {560, 380}, {640, 320}, {700, 410}}) do
    lg.rectangle("fill", b[1], 700 - b[2], 56, b[2])
  end
  lg.setColor(0.86, 0.8, 0.68, 1)
  lg.rectangle("fill", 480, 330, 44, 370)
  lg.rectangle("fill", 474, 300, 56, 40)
  lg.polygon("fill", 474, 300, 530, 300, 502, 270)
  lg.setColor(0.6, 0.55, 0.45, 1)
  lg.circle("fill", 502, 322, 9, 16)
  capitol(384, 700)
  -- Congress Avenue, coming toward us
  lg.setColor(0.32, 0.32, 0.36, 1)
  lg.polygon("fill", 330, 700, 438, 700, 768, H, 0, H)
  lg.setColor(0.6, 0.62, 0.5, 1)
  lg.polygon("fill", 0, 700, 330, 700, 0, 820)
  lg.polygon("fill", 768, 700, 438, 700, 768, 820)
  austin_live(lt, true)
end

-- Congress Avenue's live things: the lane's dashes, the cars, the busker's music (and, unpainted, the truck)
function austin_live(lt, unpainted)
  lg.setColor(1, 0.85, 0.3, 1)
  for i = 0, 8 do
    local k = ((i / 9) + S.t * 0.15) % 1
    local y = 700 + k * k * 330
    lg.rectangle("fill", 382, y, 4 + k * 6, 10 + k * 26)
  end
  -- cars, up and down
  for i = 0, 5 do
    local up = i % 2 == 0
    local k = ((S.t * 0.12 + i * 0.17) % 1)
    if not up then k = 1 - k end
    local y = 700 + k * k * 320
    local x = up and (370 - k * 200) or (398 + k * 200)
    local s = 0.3 + k * 1.2
    local c = ({{0.8, 0.2, 0.2}, {0.2, 0.4, 0.8}, {0.9, 0.9, 0.9}, {0.95, 0.75, 0.2}})[i % 4 + 1]
    rgba(c)
    lg.rectangle("fill", x - 16 * s, y - 10 * s, 32 * s, 14 * s, 3 * s, 3 * s, 4)
    lg.setColor(0.1, 0.1, 0.12, 1)
    lg.circle("fill", x - 10 * s, y + 4 * s, 4 * s, 8)
    lg.circle("fill", x + 10 * s, y + 4 * s, 4 * s, 8)
  end
  -- the taco truck, the busker
  if unpainted then
  lg.setColor(0.95, 0.95, 0.92, 1)
  lg.rectangle("fill", 600, 830, 150, 80, 8, 8, 6)
  lg.setColor(0.2, 0.6, 0.55, 1)
  lg.rectangle("fill", 600, 830, 150, 22, 8, 8, 6)
  lg.setColor(0.15, 0.15, 0.18, 1)
  lg.rectangle("fill", 618, 862, 70, 30)
  lg.circle("fill", 626, 912, 12, 12)
  lg.circle("fill", 724, 912, 12, 12)
  G:text("TACOS", 600, 832, 18, {1, 1, 1}, 1, "center", 150)
  -- the guitar player
  lg.setColor(0.2, 0.2, 0.25, 1)
  lg.rectangle("fill", 92, 860, 20, 50)
  lg.setColor(0.95, 0.78, 0.62, 1)
  lg.circle("fill", 102, 848, 9, 12)
  lg.setColor(0.55, 0.3, 0.15, 1)
  lg.ellipse("fill", 112, 888, 16, 12, 14)
  end
  lg.setColor(0.55, 0.3, 0.15, 1)
  lg.setLineWidth(4)
  lg.line(112, 888, 150, 860 + sin(S.t * 8) * 1)
  for i = 0, 2 do
    local ph = ((S.t * 0.6 + i / 3) % 1)
    note(130 + ph * 60 + sin(ph * 6 + i) * 10, 850 - ph * 90, 1.1, {1, 0.9, 0.5}, 1 - ph, i % 2 == 1)
  end
  local a = L.window(lt, 30, 44, 1)
  G:plate("LIVE MUSIC CAPITAL OF THE WORLD", 200, 30, 0xffd23f, a)
end

local COATS = {{{0.5, 0.3, 0.16}, {0.95, 0.92, 0.85}}, {{0.15, 0.12, 0.1}, {0.9, 0.88, 0.82}}, {{0.75, 0.55, 0.32}},
               {{0.88, 0.85, 0.78}, {0.5, 0.3, 0.16}}, {{0.55, 0.22, 0.12}}, {{0.82, 0.7, 0.5}, {0.4, 0.25, 0.14}}}
function D.stockyards(lt, len)
  if not art("stockyards") then
  G:gradient(0, 0, W, 520, {0.35, 0.55, 0.85}, {0.98, 0.85, 0.6})
  -- the storefronts
  local fronts = {{0, 200, {0.6, 0.35, 0.25}, "SALOON"}, {200, 170, {0.75, 0.62, 0.45}, "BOOTS"},
                  {370, 200, {0.55, 0.4, 0.3}, "HOTEL"}, {570, 198, {0.68, 0.38, 0.28}, "GENERAL STORE"}}
  for _, f in ipairs(fronts) do
    rgba(f[3])
    lg.rectangle("fill", f[1], 420, f[2], 330)
    lg.rectangle("fill", f[1] + 10, 380, f[2] - 20, 40)
    lg.setColor(0.2, 0.15, 0.12, 1)
    lg.rectangle("fill", f[1] + 30, 640, 40, 110)
    for i = 0, 1 do lg.rectangle("fill", f[1] + 30 + i * 80, 480, 50, 60) end
    lg.setColor(0.95, 0.9, 0.75, 1)
    lg.rectangle("fill", f[1] + 14, 390, f[2] - 28, 24)
    G:text(f[4], f[1], 392, 18, {0.35, 0.18, 0.1}, 1, "center", f[2])
    lg.setColor(0.4, 0.28, 0.18, 1)
    lg.rectangle("fill", f[1], 600, f[2], 10)
    for x = f[1] + 4, f[1] + f[2] - 4, 46 do lg.rectangle("fill", x, 610, 6, 140) end
  end
  -- the arch over the street
  lg.setColor(0.18, 0.18, 0.2, 1)
  lg.rectangle("fill", 120, 230, 12, 520)
  lg.rectangle("fill", 636, 230, 12, 520)
  lg.setLineWidth(10)
  lg.arc("line", "open", 384, 380, 260, pi + 0.55, 2 * pi - 0.55, 40)
  lg.setColor(0.95, 0.92, 0.85, 1)
  lg.rectangle("fill", 200, 192, 368, 46, 6, 6, 6)
  G:text("FORT WORTH STOCKYARDS", 200, 200, 26, {0.6, 0.15, 0.12}, 1, "center", 368)
  -- the brick street
  G:gradient(0, 750, W, H, {0.62, 0.3, 0.22}, {0.5, 0.24, 0.18})
  lg.setColor(0.4, 0.18, 0.14, 0.6)
  for r = 0, 13 do
    local y = 760 + r * 19
    lg.rectangle("fill", 0, y, W, 2)
    for x = (r % 2) * 22, W, 44 do lg.rectangle("fill", x, y, 2, 19) end
  end
  end
  -- the drive: steers left to right, two drovers
  local x0 = -1000 + (lt - 1) * 30
  for i = 1, 9 do
    local x = x0 + i * 92 + (i % 3) * 18
    if x > -150 and x < W + 150 then
      local y = 860 + (i % 3) * 34
      steer(x, y, 0.9 + (i % 3) * 0.08, S.t * 5 + i, COATS[i % #COATS + 1], {0.92, 0.88, 0.75})
      if S.R:random() < 0.05 then G:puff(x - 20, y + 30, {0.75, 0.6, 0.45}, 15, -10, 1.4, 6, 0.35) end
    end
  end
  for i, off in ipairs({-70, 1010}) do
    local x = x0 + off
    if x > -120 and x < W + 120 then rider(x, 830 + i * 50, 1.1, S.t * 5) end
  end
end

function D.alamo(lt, len)
  local painted = art("alamo")
  if not painted then
  G:gradient(0, 0, W, 760, {0.25, 0.5, 0.88}, {0.82, 0.88, 0.95})
  live_oak(80, 760, 1.4, S.t)
  local stone, sh = {0.9, 0.84, 0.7}, {0.72, 0.66, 0.54}
  local x0, x1, top, base = 170, 598, 360, 760
  -- the facade, with its curved parapet (the "hump")
  rgba(stone)
  lg.rectangle("fill", x0, top + 80, x1 - x0, base - top - 80)
  local pts = {}
  for i = 0, 24 do
    local u = i / 24
    local b = 1 - (2 * u - 1) ^ 2
    pts[#pts + 1] = x0 + 110 + u * (x1 - x0 - 220)
    pts[#pts + 1] = top + 80 - b * b * 86 - (abs(u - 0.5) < 0.08 and 8 or 0)
  end
  for i = 1, #pts - 2, 2 do
    lg.polygon("fill", pts[i], pts[i + 1], pts[i + 2], pts[i + 3], pts[i + 2], top + 82, pts[i], top + 82)
  end
  lg.rectangle("fill", x0, top + 60, 70, 22)
  lg.rectangle("fill", x1 - 70, top + 60, 70, 22)
  -- pilasters, niches, the door
  rgba(sh)
  for _, px in ipairs({x0 + 30, x0 + 90, x1 - 110, x1 - 50}) do lg.rectangle("fill", px, top + 150, 20, base - top - 150) end
  for _, nx in ipairs({x0 + 62, x1 - 82}) do
    lg.rectangle("fill", nx - 10, 520, 20, 50)
    lg.arc("fill", "pie", nx, 520, 10, pi, 2 * pi, 12)
    lg.rectangle("fill", nx - 10, 640, 20, 50)
    lg.arc("fill", "pie", nx, 640, 10, pi, 2 * pi, 12)
  end
  lg.setColor(0.25, 0.2, 0.17, 1)
  lg.rectangle("fill", 344, 600, 80, 160)
  lg.arc("fill", "pie", 384, 600, 40, pi, 2 * pi, 20)
  lg.rectangle("fill", 370, 470, 28, 40)
  lg.arc("fill", "pie", 384, 470, 14, pi, 2 * pi, 12)
  rgba(sh)
  lg.rectangle("fill", x0, 580, x1 - x0, 6)
  end
  -- the flags: Texas and the United States, either side
  for i, fx in ipairs({120, 660}) do
    lg.setColor(0.7, 0.7, 0.74, 1)
    if not painted then lg.rectangle("fill", fx - 2, 300, 4, 460) end
    local w = sin(S.t * 3 + i) * 3
    if i == 1 then
      lg.setColor(0, 0.16, 0.41, 1)
      lg.rectangle("fill", fx + 2, 304, 22, 44)
      lg.setColor(0.97, 0.97, 0.95, 1)
      lg.polygon("fill", fx + 24, 304, fx + 68, 304 + w, fx + 68, 326 + w, fx + 24, 326)
      lg.setColor(0.75, 0.04, 0.19, 1)
      lg.polygon("fill", fx + 24, 326, fx + 68, 326 + w, fx + 68, 348 + w, fx + 24, 348)
    else
      for k = 0, 6 do
        if k % 2 == 0 then lg.setColor(0.8, 0.11, 0.17, 1) else lg.setColor(0.97, 0.97, 0.95, 1) end
        lg.polygon("fill", fx + 2, 304 + k * 6.3, fx + 66, 304 + k * 6.3 + w, fx + 66, 310.3 + k * 6.3 + w, fx + 2, 310.3 + k * 6.3)
      end
      lg.setColor(0.14, 0.2, 0.52, 1)
      lg.rectangle("fill", fx + 2, 304, 26, 22)
    end
  end
  if not painted then G:gradient(0, 760, W, H, {0.78, 0.72, 0.6}, {0.62, 0.56, 0.45}) end
  for i = 1, 3 do bird_v(300 + i * 90 + sin(S.t * 0.6 + i) * 60, 220 + cos(S.t * 0.7 + i) * 30, 1.1, S.t * 7 + i, {1, 1, 1}, 0.9) end
  local a = L.window(lt, 14, 34, 1.5)
  G:plate("REMEMBER", 220, 44, 0xffffff, a)
end

function D.bbq(lt, len)
  if art("bbq") then
    lg.setColor(1, 0.45, 0.1, 0.5 + 0.3 * sin(S.t * 9))
    lg.rectangle("fill", 98, 400, 54, 34)
    C.fx.glow(125, 418, 70, 40, 1, 0.5, 0.1, 0.3 + 0.15 * sin(S.t * 7))
    G:plate("LOCKHART  ·  TAYLOR  ·  LULING", 120, 30, 0xffd23f, L.window(lt, 16, 32, 1))
    return
  end
  G:gradient(0, 0, W, H, {0.32, 0.2, 0.14}, {0.16, 0.1, 0.08})
  -- the smoker: a barrel on its firebox, a stack, post oak smoke
  lg.setColor(0.1, 0.1, 0.11, 1)
  lg.rectangle("fill", 140, 300, 420, 130, 60, 60, 16)
  lg.rectangle("fill", 80, 340, 90, 110, 6, 6, 4)
  lg.rectangle("fill", 520, 160, 26, 160)
  lg.setColor(0.25, 0.25, 0.27, 1)
  lg.rectangle("fill", 160, 362, 380, 6)
  lg.setColor(1, 0.45, 0.1, 0.5 + 0.3 * sin(S.t * 9))
  lg.rectangle("fill", 96, 400, 58, 34)
  lg.setColor(0.08, 0.08, 0.09, 1)
  lg.circle("fill", 190, 450, 22, 16)
  lg.circle("fill", 500, 450, 22, 16)
  -- butcher paper, brisket, sausage, bread, pickles
  lg.setColor(0.86, 0.72, 0.52, 1)
  lg.polygon("fill", 70, 560, 700, 520, 720, 920, 60, 960)
  for i = 0, 5 do
    local x, y = 140 + i * 58, 640 + i * 4
    lg.setColor(0.18, 0.1, 0.06, 1)
    lg.rectangle("fill", x, y, 50, 120, 6, 6, 4)
    lg.setColor(0.78, 0.36, 0.32, 1)
    lg.rectangle("fill", x + 5, y + 6, 40, 108, 4, 4, 4)
    lg.setColor(0.62, 0.38, 0.26, 1)
    lg.rectangle("fill", x + 10, y + 12, 30, 96, 4, 4, 4)
    lg.setColor(1, 0.85, 0.7, 0.4)
    lg.rectangle("fill", x + 12, y + 30, 26, 4)
  end
  for i = 0, 2 do
    lg.setColor(0.55, 0.18, 0.12, 1)
    lg.rectangle("fill", 500 + i * 16, 600 + i * 26, 150, 34, 17, 17, 8)
    lg.setColor(0.8, 0.4, 0.3, 0.6)
    lg.rectangle("fill", 512 + i * 16, 606 + i * 26, 120, 6, 3, 3, 4)
  end
  lg.setColor(0.97, 0.95, 0.88, 1)
  lg.rectangle("fill", 120, 800, 110, 96, 10, 10, 6)
  lg.rectangle("fill", 140, 790, 110, 96, 10, 10, 6)
  lg.setColor(0.35, 0.55, 0.2, 1)
  for i = 0, 3 do lg.ellipse("fill", 330 + i * 40, 840 + (i % 2) * 14, 16, 10, 12) end
  lg.setColor(0.95, 0.92, 0.85, 1)
  lg.setLineWidth(3)
  for i = 0, 2 do lg.ellipse("line", 540 + i * 30, 820, 22 - i * 5, 12 - i * 3, 16) end
  local a = L.window(lt, 16, 32, 1)
  G:plate("LOCKHART  ·  TAYLOR  ·  LULING", 120, 30, 0xffd23f, a)
end

function D.panhandle(lt, len)
  local k = lt / len
  local painted = art("panhandle")
  if painted then
    -- the light going: the painted golden hour deepening
    lg.setColor(0.25, 0.1, 0.25, 0.3 * k)
    lg.rectangle("fill", 0, 0, W, H)
  else
  G:gradient(0, 0, W, 640, mix({0.35, 0.3, 0.55}, {0.25, 0.15, 0.35}, k), mix({1, 0.72, 0.35}, {1, 0.5, 0.25}, k))
  C.fx.glow(250, 600, 300, 160, 1, 0.6, 0.25, 0.5)
  -- the supercell, far off on the right, lightning now and then
  -- (the anvil spreading flat at the top, the tower under it, a dark flat base, rain slanting down)
  lg.setColor(0.3, 0.27, 0.38, 0.95)
  lg.polygon("fill", 330, 250, 768, 210, 768, 270, 600, 292, 420, 280)
  end
  if not painted then
  lg.setColor(0.26, 0.24, 0.34, 1)
  for _, c in ipairs({{600, 330, 60}, {660, 350, 70}, {720, 330, 66}, {640, 400, 70}, {710, 410, 64}, {580, 410, 50}}) do
    lg.ellipse("fill", c[1], c[2], c[3] * 1.2, c[3], 28)
  end
  lg.setColor(0.18, 0.17, 0.24, 1)
  lg.rectangle("fill", 520, 440, 248, 34, 14, 14, 8)
  lg.setColor(0.55, 0.55, 0.65, 0.35)
  lg.setLineWidth(2)
  for i = 0, 22 do
    local x = 530 + i * 11
    lg.line(x, 474, x - 40, 640)
  end
  end
  local strike = (S.t * 0.35) % 1
  if strike < 0.04 then
    lg.setColor(1, 1, 0.95, 1)
    lg.setLineWidth(3)
    local x, y = 620 + (floor(S.t) % 4) * 20, 460
    local pts = {x, y}
    -- (the bolt's shape from the strike's number: the same bolt every frame of its flash)
    local bolt = floor(S.t * 0.35)
    for i = 1, 6 do x = x + (((bolt * 7919 + i * 104729) % 1000) / 1000 - 0.5) * 30 y = y + 30 pts[#pts + 1] = x pts[#pts + 1] = y end
    lg.line(pts)
    C.fx.glow(640, 440, 200, 160, 1, 1, 1, 0.25)
  end
  if not painted then
  -- Palo Duro: layered red mesas
  local strata = {{0.72, 0.28, 0.16}, {0.85, 0.5, 0.3}, {0.95, 0.85, 0.7}, {0.7, 0.3, 0.2}, {0.55, 0.22, 0.15}}
  for m, mesa in ipairs({{-40, 340, 520}, {300, 280, 560}, {520, 300, 600}}) do
    local x, w, y = mesa[1], mesa[2], mesa[3]
    for j, c in ipairs(strata) do
      local yy = y + (j - 1) * 22
      local inset = (j - 1) * -6
      rgba(c)
      lg.polygon("fill", x + 40 + inset, yy, x + w - 40 - inset, yy, x + w - 30 - inset, yy + 22, x + 30 + inset, yy + 22)
    end
    lg.setColor(0.5, 0.2, 0.14, 1)
    lg.rectangle("fill", x + 20, y + 110, w - 40, 60)
  end
  -- the plains: wheat, waving
  G:gradient(0, 700, W, H, {0.85, 0.65, 0.3}, {0.6, 0.45, 0.2})
  lg.setColor(0.95, 0.8, 0.45, 0.8)
  lg.setLineWidth(2)
  for i = 0, 70 do
    local x = (i * 37) % W
    local y = 720 + (i * 53) % 290
    local sw = sin(S.t * 1.5 + x * 0.02) * 4
    lg.line(x, y, x + sw, y - 14)
  end
  -- the windmill
  lg.setColor(0.15, 0.13, 0.12, 1)
  lg.setLineWidth(3)
  lg.line(130, 900, 160, 600)
  lg.line(190, 900, 160, 600)
  for y = 640, 880, 60 do lg.line(130 + (900 - y) * 0.1, y, 190 - (900 - y) * 0.1, y) end
  end
  lg.setColor(0.12, 0.09, 0.08, 1)
  lg.push()
  lg.translate(160, 590)
  lg.rotate(S.t * 2.2)
  for i = 0, 15 do
    lg.rotate(pi / 8)
    lg.polygon("fill", 6, -3, 46, -6, 46, 6, 6, 3)
  end
  lg.pop()
  lg.circle("fill", 160, 590, 7, 12)
  if not painted then lg.polygon("fill", 160, 586, 230, 576, 236, 600, 160, 594) end
  -- the pump jack, nodding
  local nod = sin(S.t * 1.4) * 0.25
  lg.setColor(0.12, 0.12, 0.14, 1)
  if not painted then
    lg.rectangle("fill", 520, 880, 180, 14)
    lg.polygon("fill", 590, 880, 610, 790, 630, 880)
  end
  lg.push()
  lg.translate(610, 790)
  lg.rotate(nod)
  lg.rectangle("fill", -80, -8, 160, 16)
  lg.polygon("fill", 80, -26, 100, -10, 100, 26, 80, 14)
  lg.pop()
  lg.setLineWidth(3)
  lg.line(610 + cos(nod) * 96, 790 + sin(nod) * 96 + 20, 706, 880)
  lg.circle("fill", 540, 860, 18 + 0 * nod, 16)
end

function D.bats(lt, len)
  local k = lt / len
  local painted = S.art.bats_dusk and S.art.bats_night
  if painted then
    art("bats_dusk")
    art("bats_night", clamp(k * 1.3, 0, 1))
  else
  G:gradient(0, 0, W, 600, mix({0.3, 0.2, 0.45}, {0.1, 0.08, 0.25}, k), mix({1, 0.55, 0.35}, {0.6, 0.3, 0.4}, k))
  -- the skyline
  lg.setColor(0.1, 0.08, 0.16, 1)
  for i, b in ipairs({{0, 120}, {60, 200}, {130, 160}, {190, 260}, {260, 180}, {330, 300}, {400, 220}, {470, 340}, {550, 200},
                      {620, 260}, {690, 170}}) do
    lg.rectangle("fill", b[1], 600 - b[2], 66, b[2])
  end
  lg.setColor(1, 0.85, 0.5, 0.7)
  for i = 0, 40 do
    if floor(S.t * 0.5 + i * 7) % 5 ~= 0 then lg.rectangle("fill", (i * 53) % 740 + 8, 600 - 20 - (i * 37) % 260, 4, 5) end
  end
  -- Lady Bird Lake, the bridge
  G:gradient(0, 600, W, H, {0.25, 0.18, 0.35}, {0.08, 0.06, 0.16})
  lg.setColor(1, 0.7, 0.5, 0.25)
  for i = 0, 20 do
    local y = 640 + i * 18
    lg.rectangle("fill", 100 + sin(S.t + i) * 30 + (i * 71) % 400, y, 60 + (i % 4) * 20, 2)
  end
  lg.setColor(0.08, 0.06, 0.12, 1)
  lg.rectangle("fill", 0, 640, W, 22)
  for i = 0, 6 do
    local cx = 55 + i * 110
    lg.rectangle("fill", cx - 50, 662, 100, 8)
    lg.arc("fill", "pie", cx, 720, 48, pi, 2 * pi, 16)
    lg.rectangle("fill", cx - 50, 662, 10, 110)
  end
  lg.setColor(0.12, 0.1, 0.16, 1)
  for i = 0, 5 do
    lg.rectangle("fill", 40 + i * 140, 614, 4, 26)
    lg.setColor(1, 0.85, 0.5, 0.9)
    lg.circle("fill", 42 + i * 140, 612, 4, 8)
    lg.setColor(0.12, 0.1, 0.16, 1)
  end
  end
  -- the bats: a ribbon rising from under the bridge, drifting east
  local b = S.batb
  b:clear()
  if lt > 6 then
    local n = min(700, floor((lt - 6) * 40))
    for i = 1, n do
      local age = ((lt - 6) - i / 40)
      local u = age * 0.12
      local x = 300 + i % 7 * 10 + age * 30 + sin(age * 1.5 + i * 0.3) * (20 + age * 6)
      local y = 670 - age * 70 + sin(age * 2 + i) * 6
      if y > -20 then
        local fl = floor(S.t * 12 + i) % 2 + 1
        b:add(S.batq[fl], x + sin(i * 1.7) * age * 4, y, 0, 2, 2, 4, 2)
      end
    end
  end
  lg.setColor(0.05, 0.03, 0.08, 1)
  lg.draw(b)
  if painted then return end
  -- the crowd on the bank, watching
  lg.setColor(0.06, 0.05, 0.1, 1)
  for i = 0, 18 do
    local x = 20 + i * 40
    lg.circle("fill", x, 990 - (i % 3) * 4, 9, 10)
    lg.rectangle("fill", x - 10, 998 - (i % 3) * 4, 20, 30, 6, 6, 4)
  end
end

function D.bigbend(lt, len)
  local painted = art("bigbend")
  if not painted then
  G:gradient(0, 0, W, 760, {0.01, 0.01, 0.05}, {0.06, 0.05, 0.14})
  lg.setColor(1, 1, 1, 1)
  lg.draw(S.milky, 0, 0, 0, 2, 2)
  end
  for i, s in ipairs(S.bright) do
    local tw = 0.6 + 0.4 * sin(S.t * (1 + i % 4) + i)
    lg.setColor(1, 1, 0.92, tw)
    lg.circle("fill", s[1], s[2], s[3], 6)
  end
  -- a shooting star now and then
  local sh = (S.t * 0.13) % 1
  if sh < 0.06 then
    local p = sh / 0.06
    lg.setColor(1, 1, 1, 1 - p)
    lg.setLineWidth(2)
    lg.line(500 - p * 300, 120 + p * 120, 540 - p * 300, 100 + p * 120)
  end
  -- the Chisos
  if not painted then
  lg.setColor(0.04, 0.03, 0.07, 1)
  local ridge = {0, 700, 80, 640, 140, 660, 210, 560, 260, 600, 330, 520, 380, 580, 450, 540, 520, 610, 600, 590, 680, 640, 768, 620}
  for i = 1, #ridge - 2, 2 do
    lg.polygon("fill", ridge[i], ridge[i + 1], ridge[i + 2], ridge[i + 3], ridge[i + 2], 780, ridge[i], 780)
  end
  end
  -- the Marfa lights, on the horizon
  lg.setBlendMode("add")
  for i = 1, 4 do
    local a = clamp(sin(S.t * (0.3 + i * 0.07) + i * 2) * 1.6, 0, 1)
    local x = 120 + i * 140 + sin(S.t * 0.2 + i) * 40
    C.fx.glow(x, 752, 22, 22, 1, 0.85, 0.6, 0.55 * a)
    lg.setColor(1, 0.95, 0.8, 0.8 * a)
    lg.circle("fill", x, 752, 3, 8)
  end
  lg.setBlendMode("alpha")
  -- the desert floor, ocotillo and prickly pear
  if not painted then
  G:gradient(0, 770, W, H, {0.06, 0.05, 0.08}, {0.02, 0.02, 0.03})
  lg.setColor(0.02, 0.02, 0.03, 1)
  lg.setLineWidth(3)
  for _, o in ipairs({{120, 980}, {640, 960}}) do
    for i = -3, 3 do
      local sw = sin(S.t * 0.8 + i) * 2
      lg.line(o[1], o[2], o[1] + i * 18 + sw, o[2] - 150 + abs(i) * 20)
    end
  end
  for _, p in ipairs({{330, 990}, {470, 1000}}) do
    lg.ellipse("fill", p[1], p[2] - 20, 22, 30, 16)
    lg.ellipse("fill", p[1] - 22, p[2] - 64, 16, 22, 16)
    lg.ellipse("fill", p[1] + 20, p[2] - 60, 15, 20, 16)
  end
  end
  -- the coyote on the ridge, howling at the end
  if lt > 30 then
    local howl = lt > 40 and 1 or 0
    lg.setColor(0.04, 0.03, 0.07, 1)
    lg.ellipse("fill", 236, 556, 22, 9, 12)
    lg.polygon("fill", 252, 552, 262, 534 - howl * 10, 272, 538 - howl * 12, 262, 556)
    lg.polygon("fill", 214, 554, 196, 548, 214, 560)
    for i = 0, 3 do lg.rectangle("fill", 220 + i * 9, 560, 3, 14) end
  end
  local a = L.window(lt, 26, 40, 1.5)
  G:caption("THE MARFA LIGHTS", 820, 34, 0xffe0a0, a)
end

function D.finale(lt, len)
  if not art("finale") then
    G:gradient(0, 0, W, H, {0.01, 0.01, 0.06}, {0.08, 0.06, 0.2})
    lg.setColor(1, 1, 1, 1)
    lg.draw(S.milky, 0, 0, 0, 2, 2)
  end
  L.pole(150, 240, 1024)
  S.flag:draw(155, 260, 470, 313, S.t, 0.7 + 0.1 * sin(S.t * 0.4), {0.95, 0.95, 1})
  G:draw_back()
  local a = L.window(lt, 1, 25, 1.5)
  G:caption("TEXAS", 640, 110, 0xffb347, a)
  G:caption("THE LONE STAR STATE", 790, 34, 0xffffff, a)
  G:caption("FRIENDSHIP", 850, 26, 0x9fd8ff, L.window(lt, 6, 25, 1.5))
end

-- ------------------------------------------------------------------ the show
function T.load(ctx)
  C = ctx
  W, H = ctx.W, ctx.H
  G = L.new(ctx)
end

function T.stop()
  if G then G:finish() end
  S = nil
end

function T.start(seed, at)
  T.stop()
  G:begin(seed)
  S = {t = at or 0}
  G.t, G.prev = S.t, S.t - 0.001
  S.R = G.R
  S.flag = G:cloth(L.paint_texas, 600, 400)
  S.art = {}
  for _, n in ipairs({"open", "coast_dawn", "coast_day", "hills", "creek", "donuts", "austin", "stockyards", "alamo", "bbq",
                      "panhandle", "bats_dusk", "bats_night", "bigbend", "finale"}) do
    S.art[n] = G:art("texas", n)
  end
  -- the flowers: bluebonnets (blue, a white tip) and paintbrush (red-orange), farther ones smaller
  local R = G.R
  -- (the made flowers and Milky Way only without the painted scenes)
  S.flowers = G:track(lg.newSpriteBatch(G.dot, 1600, "static"))
  for i = 1, S.art.hills and 0 or 1500 do
    local y = 700 + (R:random() ^ 1.6) * 324
    local k = (y - 700) / 324
    local x = R:random() * W
    local s = (0.25 + k * 0.6)
    if R:random() < 0.78 then
      S.flowers:setColor(0.2 + R:random() * 0.1, 0.32 + R:random() * 0.1, 0.85, 1)
      S.flowers:add(x, y, 0, s, s * 1.6, 8, 8)
      S.flowers:setColor(1, 1, 1, 0.9)
      S.flowers:add(x, y - 7 * s, 0, s * 0.45, s * 0.45, 8, 8)
    else
      S.flowers:setColor(0.95, 0.35 + R:random() * 0.15, 0.15, 1)
      S.flowers:add(x, y, 0, s * 0.9, s * 1.4, 8, 8)
    end
  end
  -- the Milky Way: painted once, at half size
  S.milky = (S.art.bigbend and S.art.finale) and G.px or G:canvas(384, 380, function(w, h)
    for i = 1, 2600 do
      local u = R:random()
      local band = (R:random() - 0.5) * (R:random() < 0.7 and 70 or 260)
      local x = u * w
      local y = h * 0.85 - u * h * 0.7 + band
      local b = 0.4 + R:random() * 0.6
      lg.setColor(1, 1, 0.95, b * (abs(band) < 60 and 1 or 0.6))
      lg.rectangle("fill", x, y, 1, 1)
    end
    for i = 1, 40 do
      local u = R:random()
      lg.setColor(0.7, 0.65, 0.9, 0.05)
      lg.circle("fill", u * w, h * 0.85 - u * h * 0.7 + (R:random() - 0.5) * 50, 20 + R:random() * 20, 16)
    end
  end)
  S.bright = {}
  for i = 1, 40 do S.bright[i] = {R:random() * W, R:random() * 640, 1 + R:random() * 1.4} end
  -- the bats
  local bat = love.image.newImageData(16, 4)
  for _, p in ipairs({{0, 1}, {1, 2}, {2, 2}, {3, 3}, {4, 2}, {5, 1}, {6, 2}, {7, 2}, {8, 0}, {9, 1}, {10, 2}, {11, 2},
                      {12, 3}, {13, 2}, {14, 1}, {15, 0}}) do bat:setPixel(p[1], p[2], 1, 1, 1, 1) end
  S.batimg = G:track(lg.newImage(bat))
  S.batimg:setFilter("nearest", "nearest")
  S.batq = {lg.newQuad(0, 0, 8, 4, 16, 4), lg.newQuad(8, 0, 8, 4, 16, 4)}
  S.batb = G:track(lg.newSpriteBatch(S.batimg, 800, "stream"))
  -- the labels ahead
  for _, s in ipairs(SCENES) do if s[4] then G:label(s[4], 56, 0xffffff) end end
  for _, l in ipairs({{"PRESENTS", 26, 0x6ef0c8}, {"A DAY ACROSS", 34, 0xffffff},
                      {"TEXAS", 96, 0xffb347}, {"TEXAS", 110, 0xffb347}, {"THE LONE STAR STATE", 34, 0xffffff},
                      {"FRIENDSHIP", 26, 0x9fd8ff}, {"REMEMBER", 44, 0xffffff}, {"THE MARFA LIGHTS", 34, 0xffe0a0},
                      {"LIVE MUSIC CAPITAL OF THE WORLD", 30, 0xffd23f}, {"LOCKHART  ·  TAYLOR  ·  LULING", 30, 0xffd23f}}) do
    G:label(l[1], l[2], l[3])
  end
end

function T.act()
  return S and scene_at(S.t)[2] or "open"
end

function T.music()
  return S and scene_at(S.t)[3] or "tx_sunrise"
end

function T.update(dt)
  if not S then return false end
  G:step(dt)
  S.t = G.t
  local sc, lt, len = scene_at(S.t)
  -- the finale's fireworks: Texas red, white and blue
  if sc[2] == "finale" and lt > 3 and lt < 22 then
    S.fw = (S.fw or 0) - dt
    if S.fw <= 0 then
      S.fw = 0.8 + G.R:random() * 0.8
      G:rocket(260 + G.R:random() * 440, 120 + G.R:random() * 200,
               {from = 1024, colours = {{0.75, 0.1, 0.2}, {1, 1, 1}, {0.2, 0.35, 0.9}}})
    end
  end
  -- smoke: the barbecue's stack, wisps over the coast's boat
  if sc[2] == "bbq" and G.R:random() < dt * 8 then
    G:puff(533 + (G.R:random() - 0.5) * 10, 160, {0.75, 0.72, 0.7}, 50 + G.R:random() * 20, 12, 3, 10, 0.4)
  end
  if sc[2] == "bbq" and G.R:random() < dt * 3 then
    G:puff(200 + G.R:random() * 300, 640, {1, 1, 1}, 30, 0, 1.6, 6, 0.25)
  end
  if sc[2] == "panhandle" and S.t > 395 and floor(S.prev_t or 0) ~= floor(S.t) and floor(S.t) % 9 == 4 then
    C.sfx("boom", 0.4)
  end
  S.prev_t = S.t
  return S.t >= LEN
end

function T.draw()
  if not S then return end
  local sc, lt, len = scene_at(S.t)
  D[sc[2]](lt, len)
  if sc[2] ~= "finale" then G:draw_back() end
  G:draw_front()
  -- the scene's title, and its place line at the bottom
  if sc[4] then
    local a = L.window(lt, 1.5, 9, 1)
    G:plate(sc[4], sc[2] == "bbq" and 60 or 70, 56, 0xffffff, a)
    local b = L.window(lt, 2, len - 1.5, 1)
    lg.setColor(0.02, 0.02, 0.06, 0.55 * b)
    lg.rectangle("fill", 0, H - 50, W, 50)
    G:text(sc[5], 0, H - 38, 20, {1, 0.92, 0.75}, b)
  end
  -- a fade at each scene change
  local f = 1 - min(lt / 1.2, (len - lt) / 1.2, 1)
  if f > 0 then
    lg.setColor(0, 0, 0, f)
    lg.rectangle("fill", 0, 0, W, H)
  end
end

return T
