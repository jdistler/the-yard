-- Texas: A Day Across Texas. Home's homage to the state (sincere, not satire), ten minutes from sunrise on the
-- Gulf to the stars over Big Bend, a scene for each place. The cast make the trip in their van (TEXAS OR BUST),
-- doing the thing each place is for; every scene a story with its own camera (SHOWS_BLUEPRINT.md):
--   0:00  the Lone Star flag at first light                                   (Lone Star Sunrise)
--   0:12  the Gulf Coast: Galveston at sunrise; the sandcastle built tower by tower, a pelican's dive, the wave
--   1:20  the Hill Country: the picture in the bluebonnets (an armadillo photobombs it), the monarchs lifting
--                                                                             (Bluebonnet Waltz)
--   2:20  Round Rock: across Brushy Creek on the stones (Inky in), up on the round rock; the donuts, one each
--   3:05  Austin: the taco truck (one too hot), dancing to the busker, up Congress Avenue   (Congress Avenue)
--   4:10  Fort Worth: hats from the boot store, the cattle drive, Pac-Man roping a calf (it ropes him)
--                                                                             (Stockyards Swing)
--   5:15  San Antonio: the Alamo; hats off, the doves                         (Remember)
--   5:55  Central Texas barbecue: the smoker opened, the brisket sliced, a slice each   (Conjunto)
--   6:35  the Panhandle at golden hour: on the van's roof, a train, tumbleweeds, the storm's lightning
--                                                                             (Red River Valley)
--   7:40  dusk at the Congress Avenue Bridge: waiting, the bats (one on Inky)  (Bat Flight)
--   8:30  Big Bend at night: the camp, marshmallows, a ghost story, the Marfa lights come visiting   (Desert Night)
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

-- ------------------------------------------------------------------ the road trip: the van, the cast
local GH = {{1, 0.18, 0.2}, {1, 0.55, 0.85}, {0.25, 0.95, 1}, {1, 0.65, 0.2}}
local function prog(lt, a, b) return ease((lt - a) / (b - a)) end
local function lin(lt, a, b) return clamp((lt - a) / (b - a), 0, 1) end

-- a cowboy hat on whoever (x, y the top of the head)
local function hat(x, y, r, tilt)
  lg.push()
  lg.translate(x, y)
  lg.rotate(tilt or 0)
  lg.setColor(0.55, 0.38, 0.2, 1)
  lg.ellipse("fill", 0, 0, r * 1.25, r * 0.22, 16)
  lg.rectangle("fill", -r * 0.6, -r * 0.7, r * 1.2, r * 0.72, r * 0.2, r * 0.2, 4)
  lg.setColor(0.35, 0.22, 0.1, 1)
  lg.rectangle("fill", -r * 0.6, -r * 0.18, r * 1.2, r * 0.16)
  lg.pop()
end

-- one of the cast: 0 Pac-Man, 1-4 the ghosts (hats from Fort Worth on)
local function guest(who, x, y, r, lx, ly, mood, hatted, open)
  if who == 0 then
    L.pac(x, y, r, (lx or 1) >= 0 and 0 or pi, S.t, open)
    if hatted then hat(x - 2, y - r * 0.82, r * 0.7, 0.1) end
  else
    L.ghost(x, y, r, GH[who], S.t + who, lx, ly, mood)
    if hatted then hat(x, y - r * 0.88, r * 0.7, sin(S.t + who) * 0.06) end
  end
end

-- The van: a little camper in burnt orange, TEXAS OR BUST on its side, faces in its windows.
-- x its middle, y the ground, s scale, dir 1 right / -1 left, rolling: wheels turning, riders: who is aboard
local function van(x, y, s, dir, rolling, riders)
  lg.push()
  lg.translate(x, y)
  lg.scale(s * dir, s)
  local bob = rolling and abs(sin(S.t * 14)) * 2 or 0
  lg.setColor(0, 0, 0, 0.25)
  lg.ellipse("fill", 0, 2, 120, 10, 20)
  lg.translate(0, -bob)
  lg.setColor(0.85, 0.4, 0.08, 1)
  lg.rectangle("fill", -110, -96, 220, 76, 22, 22, 10)
  lg.setColor(0.98, 0.94, 0.85, 1)
  lg.rectangle("fill", -110, -96, 220, 34, 22, 22, 10)
  lg.rectangle("fill", -110, -74, 220, 12)
  -- windows, and whoever is riding
  for k = 0, 3 do
    local wx = -92 + k * 46
    lg.setColor(0.55, 0.78, 0.95, 1)
    lg.rectangle("fill", wx, -90, 36, 24, 5, 5, 4)
    local who = riders and riders[k + 1]
    if who then
      lg.push()
      lg.scale(dir, 1)
      local fx = (wx + 18) * dir
      if who == 0 then L.pac(fx, -74, 10, dir > 0 and 0 or pi, S.t, 0.3)
      else L.ghost(fx, -76, 10, GH[who], S.t + k, dir, 0, nil) end
      lg.pop()
    end
  end
  lg.setColor(0.55, 0.78, 0.95, 1)
  lg.polygon("fill", 96, -90, 110, -90, 110, -64, 96, -64)
  -- the stripe and the words (written the right way round whichever way it faces)
  lg.push()
  lg.scale(dir, 1)
  G:text("TEXAS OR BUST", -110, -54, 18, {1, 0.95, 0.85}, 1, "center", 220)
  lg.pop()
  lg.setColor(1, 0.9, 0.5, 1)
  lg.circle("fill", 108, -40, 6, 10)
  for _, wx in ipairs({-66, 66}) do
    lg.setColor(0.1, 0.1, 0.12, 1)
    lg.circle("fill", wx, -18, 18, 18)
    lg.setColor(0.7, 0.7, 0.72, 1)
    lg.circle("fill", wx, -18, 7, 10)
    lg.setColor(0.3, 0.3, 0.32, 1)
    lg.setLineWidth(3)
    local a = rolling and -S.t * 10 or 0
    lg.line(wx + cos(a) * 7, -18 + sin(a) * 7, wx - cos(a) * 7, -18 - sin(a) * 7)
  end
  lg.pop()
end
local ALL = {0, 1, 2, 3}                    -- (four windows: Clyde rides in the back)

-- a polaroid at (x, y) holding a little picture drawn by f(x, y, w, h)
local function polaroid(x, y, s, a, f)
  lg.push()
  lg.translate(x, y)
  lg.rotate(-0.08)
  lg.scale(s, s)
  lg.setColor(0, 0, 0, 0.3 * a)
  lg.rectangle("fill", -96, -86, 200, 220, 4, 4, 4)
  lg.setColor(1, 1, 1, a)
  lg.rectangle("fill", -100, -90, 200, 220, 4, 4, 4)
  lg.setColor(0.4, 0.6, 0.9, a)
  lg.rectangle("fill", -88, -78, 176, 160)
  if a > 0.5 then f(-88, -78, 176, 160) end
  lg.pop()
end

-- ------------------------------------------------------------------ the scenes
local D, CAM, CUES = {}, {}, {}

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
  end
  local a = L.window(lt, 0.5, 5, 0.8)
  G:brand(640, a)
  G:caption("PRESENTS", 712, 26, 0x6ef0c8, a)
  local b = L.window(lt, 5.2, 12, 0.8)
  G:caption("A DAY ACROSS", 650, 34, 0xffffff, b)
  G:caption("TEXAS", 700, 96, 0xffb347, b)
end

-- ------------------------------------------------------------------ the Gulf Coast: a sandcastle
local CASTLE = {300, 925}
local SAND = 932
local function coast_van(lt)
  if lt < 13 then return lerp(W + 160, 600, 1 - (1 - lin(lt, 6, 13)) ^ 2), lt > 6 and lt < 13 end
  if lt < 61 then return 600, false end
  return lerp(600, -200, lin(lt, 61, 68) ^ 1.6), true
end
local function castle_h(lt)
  -- built 16-36, washed away 49-52
  return prog(lt, 16, 36) * (1 - prog(lt, 49, 52) * 0.85)
end
function D.coast(lt, len)
  local k = lt / len
  local sy = lerp(590, 360, ease(k * 1.2))
  if S.art.coast_dawn and S.art.coast_day then
    art("coast_dawn")
    art("coast_day", clamp(k * 1.4, 0, 1))
  else
    G:gradient(0, 0, W, 560, mix({0.08, 0.1, 0.32}, {0.22, 0.45, 0.85}, k), mix({1, 0.55, 0.35}, {0.95, 0.8, 0.7}, k))
    G:gradient(0, 560, W, 880, {0.15, 0.3, 0.45}, {0.1, 0.45, 0.55})
    G:gradient(0, 880, W, H, {0.86, 0.76, 0.58}, {0.92, 0.84, 0.66})
  end
  -- the sun, above the horizon only (a scissor would follow the screen, not the camera: clipped by hand)
  if sy < 560 then
    C.fx.glow(560, sy, 260, min(200, 560 - sy + 60), 1, 0.65, 0.35, 0.5)
    lg.setColor(1, 0.85, 0.55, 1)
    if sy < 516 then lg.circle("fill", 560, sy, 44, 40)
    else lg.arc("fill", "pie", 560, sy, 44, pi + math.asin(clamp((sy - 560) / 44, -1, 1)), 2 * pi - math.asin(clamp((sy - 560) / 44, -1, 1)), 30) end
  end
  lg.setBlendMode("add")
  for i = 0, 18 do
    local y = 566 + i * 15
    local w = (30 + i * 6) * (0.6 + 0.4 * sin(S.t * 2 + i * 1.3))
    lg.setColor(1, 0.7, 0.4, 0.35 * (1 - i / 22))
    lg.rectangle("fill", 560 - w / 2, y, w, 3)
  end
  lg.setBlendMode("alpha")
  -- the shrimp boat on the horizon
  local bx = -120 + ((S.t - 12) * 9) % (W + 240)
  lg.setColor(0.12, 0.1, 0.14, 1)
  lg.polygon("fill", bx - 40, 556, bx + 42, 556, bx + 34, 568, bx - 32, 568)
  lg.rectangle("fill", bx - 6, 536, 22, 20)
  lg.rectangle("fill", bx + 2, 510, 3, 46)
  lg.setLineWidth(2)
  lg.line(bx + 3, 512, bx - 46, 540, bx - 50, 556)
  lg.line(bx + 3, 512, bx + 52, 540, bx + 56, 556)
  -- the waves coming in; the big one at 48 up over the sandcastle
  local big = lin(lt, 47, 50) * (1 - lin(lt, 51, 55))
  for i = 0, 2 do
    local y = 820 + i * 22 + big * 130
    local pts = {}
    for x = 0, W, 16 do
      pts[#pts + 1] = x
      pts[#pts + 1] = y + sin(x * 0.02 + S.t * (1.6 + i * 0.3) + i) * 5
    end
    lg.setColor(0.85, 0.95, 1, 0.55 - i * 0.12 + big * 0.3)
    lg.setLineWidth(3 + big * 6)
    lg.line(pts)
  end
  if big > 0 then
    lg.setColor(0.3, 0.6, 0.75, 0.5 * big)
    lg.rectangle("fill", 0, 880, W, big * 110)
  end
  -- pelicans in a line, low over the water; one diving for a fish
  for i = 0, 4 do
    local px = -200 + ((S.t - 20) * 55) % (W + 500) - i * 70
    pelican(px, 650 + i * 10 + sin(S.t * 0.8 + i) * 6, 0.9, S.t * 1.6 + i * 0.7)
  end
  if lt > 38 and lt < 47 then
    local px, py = L.path(lt, {{38, 200, 300}, {40.5, 480, 820, "lin"}, {41.5, 480, 840}, {43, 520, 760}, {47, 900, 400, "lin"}})
    lg.push()
    lg.translate(px, py)
    if lt < 40.5 then lg.rotate(1.1) end
    pelican(0, 0, 1.6, S.t * 3)
    if lt > 41.5 then
      lg.setColor(0.75, 0.8, 0.85, 1)
      lg.ellipse("fill", 70, -6, 12, 5, 10)
    end
    lg.pop()
  end
  -- the sandcastle: the mound, four towers, the flag
  local ch = castle_h(lt)
  if lt > 16 then
    lg.setColor(0.86, 0.72, 0.48, 1)
    lg.ellipse("fill", CASTLE[1], CASTLE[2], 110, 26, 24)
    for t = 1, 4 do
      local th = clamp((ch * 5 - (t - 1)) , 0, 1) * (1 - prog(lt, 49, 52))
      if th > 0.02 then
        local tx = CASTLE[1] - 75 + (t - 1) * 50
        local hgt = (t == 2 or t == 3) and 90 or 64
        lg.setColor(0.9, 0.76, 0.5, 1)
        lg.rectangle("fill", tx - 18, CASTLE[2] - hgt * th, 36, hgt * th)
        for c = 0, 2 do lg.rectangle("fill", tx - 18 + c * 13, CASTLE[2] - hgt * th - 8, 10, 8) end
      end
    end
    if lt > 36 and lt < 49 then
      lg.setColor(0.4, 0.3, 0.2, 1)
      lg.rectangle("fill", CASTLE[1] - 27, CASTLE[2] - 140, 3, 50)
      lg.setColor(0.75, 0.04, 0.19, 1)
      lg.polygon("fill", CASTLE[1] - 24, CASTLE[2] - 140, CASTLE[1] + 6, CASTLE[2] - 132, CASTLE[1] - 24, CASTLE[2] - 124)
    end
  end
  -- the van, the cast
  local vx, rolling = coast_van(lt)
  local aboard = (lt < 13 or lt > 61) and ALL or nil
  van(vx, SAND + 24, 0.9, -1, rolling, aboard)
  if lt > 13 and lt < 61.5 then
    for who = 0, 4 do
      local out = 13 + who * 0.5
      local tx = CASTLE[1] - 160 + who * 80
      if who == 3 then tx = CASTLE[1] + 140 end
      local x = lerp(vx - 60, tx, prog(lt, out, out + 1.5))
      local y = SAND
      if lt > 56 then x = lerp(tx, vx - 60, prog(lt, 56 + who * 0.6, 57.5 + who * 0.6)) end
      -- Inky's trips to the water with the bucket
      if who == 3 and lt > 20 and lt < 36 then
        local f = ((lt - 20) % 8) / 8
        y = SAND - sin(f * pi) * 100
        x = tx + sin(f * pi) * 60
      end
      local dig = (lt > 16 and lt < 36) and abs(sin(S.t * 6 + who)) * 6 or 0
      local mood = (lt > 52 and lt < 56) and "wide" or ((lt > 41 and lt < 44) and "wide" or nil)
      if lt > 54 and lt < 56 then mood = "happy" end
      guest(who, x, y - 34 - dig, 30, who < 2 and 1 or -1, (lt > 39 and lt < 45) and -1 or 0, mood, false)
      if who == 3 and lt > 20 and lt < 36 then
        lg.setColor(0.2, 0.5, 0.9, 1)
        lg.rectangle("fill", x + 22, y - 40, 18, 20, 3, 3, 4)
      end
    end
  end
  if lt > 36 and lt < 39 then G:say("DONE!", CASTLE[1], CASTLE[2] - 160, 26, 1) end
  if lt > 41.5 and lt < 44 then G:say("WHOA!", 300, 860, 26, 1) end
  if lt > 51.5 and lt < 54.5 then G:say("NOOOO!", CASTLE[1], CASTLE[2] - 90, 28, 1) end
end
CAM.coast = function(lt)
  local vx = coast_van(lt)
  return L.shot(lt, {{0, 384, 512, 1}, {6, 520, 760, 1.25}, {13, 560, 820, 1.4}, {16, 320, 860, 1.5}, {26, 280, 870, 1.65},
                     {36, 300, 860, 1.6}, {38, 400, 700, 1.15}, {44, 400, 700, 1.15}, {47, 320, 860, 1.45}, {55, 320, 880, 1.5},
                     {61, 520, 840, 1.3}, {68, 300, 820, 1.2}}, W, H)
end
CUES.coast = {{6, "jet", 0.25}, {13, "clunk"}, {16, "pop", 0.4}, {20, "pop", 0.4}, {24, "pop", 0.4}, {28, "pop", 0.4}, {32, "pop", 0.4},
              {36, "ding"}, {40.5, "splash"}, {47, "whoosh"}, {49, "splash"}, {52, "boing"}, {61, "jet", 0.3}}
for t = 24, 32, 8 do CUES.coast[#CUES.coast + 1] = {t, "splash", 0.4} end

-- ------------------------------------------------------------------ the Hill Country: the picture in the bluebonnets
local TRIPOD = {640, 900}
local GROUP = {170, 260, 350, 440}
local SHOTS = {24, 38}                      -- the flashes
function D.hills(lt, len)
  if not art("hills") then
    G:gradient(0, 0, W, 620, {0.25, 0.5, 0.9}, {0.75, 0.88, 1})
    G:gradient(0, 620, W, H, {0.3, 0.5, 0.3}, {0.25, 0.45, 0.6})
  end
  -- the mockingbird on its post, singing
  mockingbird(657, 752, 1.4, S.t)
  for i = 0, 1 do
    local ph = (S.t * 0.7 + i / 2) % 1
    note(684 + ph * 30 + sin(ph * 6) * 6, 730 - ph * 70, 1, {1, 1, 1}, 0.85 * (1 - ph), i == 1)
  end
  -- the tripod and its blinking timer
  if lt > 14 then
    lg.setColor(0.25, 0.25, 0.28, 1)
    lg.setLineWidth(4)
    lg.line(TRIPOD[1], TRIPOD[2] - 70, TRIPOD[1] - 30, TRIPOD[2] + 10)
    lg.line(TRIPOD[1], TRIPOD[2] - 70, TRIPOD[1] + 30, TRIPOD[2] + 10)
    lg.line(TRIPOD[1], TRIPOD[2] - 70, TRIPOD[1], TRIPOD[2] + 14)
    lg.setColor(0.15, 0.15, 0.18, 1)
    lg.rectangle("fill", TRIPOD[1] - 28, TRIPOD[2] - 104, 56, 36, 5, 5, 4)
    lg.setColor(0.3, 0.3, 0.4, 1)
    lg.circle("fill", TRIPOD[1] - 28, TRIPOD[2] - 86, 12, 14)
    for _, s0 in ipairs(SHOTS) do
      if lt > s0 - 4 and lt < s0 then
        local rate = lt > s0 - 1.5 and 8 or 3
        if floor(lt * rate) % 2 == 0 then
          lg.setColor(1, 0.2, 0.2, 1)
          lg.circle("fill", TRIPOD[1] + 18, TRIPOD[2] - 98, 5, 8)
        end
      end
    end
  end
  -- the armadillo: walking across in front of the lens just as the first one goes off, then posing with them
  if lt > 21 and lt < 46 then
    local ax, ay, s = 0, 0, 3.4
    if lt < 27 then ax, ay = lerp(W + 60, 380, lin(lt, 21, 27)), 945
    elseif lt < 32 then ax, ay, s = lerp(380, 530, prog(lt, 28, 32)), lerp(945, 900, prog(lt, 28, 32)), lerp(3.4, 1.4, prog(lt, 28, 32))
    else ax, ay, s = 530, 900, 1.4 end
    lg.push()
    lg.translate(ax, ay)
    lg.scale(lt < 27 and -1 or 1, 1)
    armadillo(0, 0, s, S.t)
    lg.pop()
  end
  -- the cast: in through the flowers, posing, Pac-Man running back from the timer
  for i, who in ipairs({1, 2, 0, 3, 4}) do
    local gx = GROUP[math.min(i, 4)] + (i == 5 and 80 or 0)
    local x = lerp(-80 - i * 60, gx, prog(lt, 4 + i * 0.6, 10 + i * 0.6))
    local y = 900
    if who == 0 then
      x = L.path(lt, {{0, -80, 0}, {11, GROUP[3], 0}, {14, TRIPOD[1] - 50, 0}, {20, TRIPOD[1] - 50, 0}, {22, GROUP[3], 0},
                      {31, GROUP[3], 0}, {32, TRIPOD[1] - 50, 0}, {34, TRIPOD[1] - 50, 0}, {36, GROUP[3], 0}})
    end
    if lt > 46 then x = lerp(gx, W + 120 + i * 40, prog(lt, 47 + i * 0.4, 54 + i * 0.4)) end
    local pose = (lt > SHOTS[1] - 1 and lt < SHOTS[1] + 0.3) or (lt > SHOTS[2] - 1 and lt < SHOTS[2] + 0.3)
    local mood = pose and "happy" or ((lt > 24.5 and lt < 28) and "wide" or nil)
    local wade = (lt < 11 or lt > 46) and abs(sin(S.t * 5 + i)) * 8 or 0
    guest(who, x, y - 36 - wade, 32, (lt < 46) and 1 or 1, 0, mood, false, (who == 0 and pose) and 0.9 or nil)
  end
  -- the polaroids, floating up
  if lt > 25 and lt < 31 then
    polaroid(560, 300, 1, lin(lt, 25, 26), function(x, y, w, h)
      lg.setColor(0.3, 0.45, 0.85, 1)
      lg.rectangle("fill", x, y + h * 0.6, w, h * 0.4)
      lg.push() lg.translate(x + w / 2, y + h * 0.8) lg.scale(-1, 1) armadillo(0, 0, 2.4, 0) lg.pop()
    end)
  end
  if lt > 39 and lt < 46 then
    polaroid(560, 300, 1, lin(lt, 39, 40), function(x, y, w, h)
      lg.setColor(0.3, 0.45, 0.85, 1)
      lg.rectangle("fill", x, y + h * 0.6, w, h * 0.4)
      for k = 0, 4 do
        if k == 2 then L.pac(x + 22 + k * 30, y + h * 0.72, 11, 0, 0, 0.8)
        else L.ghost(x + 22 + k * 30, y + h * 0.72, 11, GH[k < 2 and k + 1 or k], 0, 0, 0, "happy") end
      end
      armadillo(x + w - 22, y + h * 0.9, 0.6, 0)
    end)
  end
  -- the flashes
  for _, s0 in ipairs(SHOTS) do
    if lt > s0 and lt < s0 + 0.6 then
      lg.setColor(1, 1, 1, 0.8 * (1 - (lt - s0) / 0.6))
      lg.rectangle("fill", 0, 0, W, H)
    end
  end
  -- the monarchs, lifting out of the flowers as everyone walks through
  local n = lt > 46 and 26 or 3
  for i = 1, n do
    local t0 = 46 + i * 0.25
    local x = 100 + ((S.t * 30 + i * 250) % (W + 100)) - 50
    local y = 520 + sin(S.t * 1.3 + i) * 60 + i * 30
    if i > 3 then
      local f = lin(lt, t0, t0 + 6)
      x = 120 + (i * 97) % 560 + sin(S.t * 2 + i) * 30
      y = lerp(900, 300 + (i * 53) % 300, f) + sin(S.t * 3 + i) * 10
    end
    if i <= 3 or lt > t0 then monarch(x, y, 1.6, S.t + i) end
  end
  if lt > 20 and lt < 23 then G:say("SAY \"BLUEBONNETS\"!", GROUP[3], 800, 22, 1) end
  if lt > 26 and lt < 29 then G:say("...HEY!", GROUP[2], 800, 24, 1) end
  if lt > 41 and lt < 45 then G:say("PERFECT!", GROUP[3], 800, 26, 1) end
end
CAM.hills = function(lt)
  return L.shot(lt, {{0, 384, 512, 1}, {4, 300, 800, 1.35}, {12, 330, 820, 1.35}, {15, 560, 820, 1.4}, {19, 520, 820, 1.3},
                     {23, 400, 840, 1.25}, {25, 450, 600, 1.15}, {30, 450, 640, 1.15}, {33, 480, 840, 1.35}, {38, 400, 840, 1.25},
                     {40, 450, 600, 1.15}, {46, 384, 600, 1.05}, {50, 600, 700, 1.6}, {55, 600, 700, 1.6}, {60, 384, 512, 1}}, W, H)
end
CUES.hills = {{SHOTS[1], "chime"}, {SHOTS[2], "chime"}, {SHOTS[1] - 0.05, "clunk", 0.5}, {SHOTS[2] - 0.05, "clunk", 0.5},
              {26, "boing"}, {41, "ding"}, {47, "whoosh", 0.4}}
for _, s0 in ipairs(SHOTS) do for k = 1, 4 do CUES.hills[#CUES.hills + 1] = {s0 - k, "tick", 0.5} end end

-- ------------------------------------------------------------------ Round Rock: the crossing, the donuts
local STONES = {{110, 820}, {220, 800}, {384, 735}, {540, 800}, {660, 820}}
local function crosser(lt, who)
  -- hop from stone to stone, one after another; Inky (3) slips in at the third
  local t0 = 3 + who * 2.2
  local n = clamp((lt - t0) / 0.9, 0, #STONES - 1)
  local i0 = floor(n)
  local f = n - i0
  local a, b = STONES[i0 + 1], STONES[min(i0 + 2, #STONES)]
  local x = lerp(a[1], b[1], f)
  local y = lerp(a[2], b[2], f) - sin(f * pi) * 50
  if who == 3 and n >= 2 and lt < t0 + 7 then
    -- in the creek!
    local s = lin(lt, t0 + 1.9, t0 + 2.2)
    x, y = 470, lerp(STONES[3][2], 860, s)
    if lt > t0 + 4.5 then
      local g = prog(lt, t0 + 4.5, t0 + 7)
      x, y = lerp(470, STONES[4][1], g), lerp(860, STONES[4][2], g) - sin(g * pi) * 40
    end
  end
  if who == 0 and lt > 17 then x, y = STONES[3][1], STONES[3][2] - 46 end
  return x, y - 36
end
local DONUTS = {}
for r = 0, 1 do for c = 0, 2 do DONUTS[#DONUTS + 1] = {210 + c * 174, 520 + r * 160} end end
local DONUT_T = {29, 31.5, 34, 36.5, 39}        -- one each, then Pac-Man has the last
local function donut(x, y, s, bite)
  lg.setColor(0.66, 0.36, 0.13, 1)
  lg.ellipse("fill", x, y, 72 * s, 62 * s, 32)
  lg.setColor(1, 0.72, 0.3, 1)
  lg.ellipse("fill", x, y - 4 * s, 66 * s, 54 * s, 32)
  lg.setColor(1, 1, 0.85, 0.5)
  lg.ellipse("fill", x - 24 * s, y - 26 * s, 20 * s, 8 * s, 12)
  lg.setColor(0.97, 0.94, 0.88, 1)
  lg.ellipse("fill", x, y - 2 * s, 18 * s, 14 * s, 16)
  if bite then
    lg.circle("fill", x + 60 * s, y - 30 * s, 26 * s, 16)
  end
end
function D.roundrock(lt, len)
  if lt < 26 then
    if not art("creek") then
      G:gradient(0, 0, W, 520, {0.3, 0.55, 0.9}, {0.8, 0.9, 1})
      G:gradient(0, 600, W, 880, {0.25, 0.5, 0.55}, {0.15, 0.38, 0.45})
    end
    lg.setColor(0.8, 0.95, 1, 0.5)
    lg.setLineWidth(2)
    for i = 0, 14 do
      local y = 650 + i * 17
      local x = ((i * 97 + S.t * (40 + i * 3)) % (W + 120)) - 60
      if abs(y - 760) > 60 or abs(x - 384) > 140 then lg.line(x, y, x + 40 + (i % 3) * 20, y) end
    end
    -- the stepping stones
    for i, st in ipairs(STONES) do
      if i ~= 3 then
        lg.setColor(0.62, 0.6, 0.55, 1)
        lg.ellipse("fill", st[1], st[2] + 8, 46, 16, 20)
        lg.setColor(0.75, 0.72, 0.66, 1)
        lg.ellipse("fill", st[1], st[2], 42, 12, 20)
      end
    end
    for who = 0, 4 do
      local x, y = crosser(lt, who)
      local wet = who == 3 and lt > 3 + 3 * 2.2 + 1.9 and lt < 3 + 3 * 2.2 + 9
      guest(who, x, y, 30, 1, 0, wet and "wide" or ((who == 0 and lt > 17) and "happy" or nil), false)
      if wet then
        lg.setColor(0.6, 0.85, 1, 0.8)
        for d = 0, 2 do lg.circle("fill", x - 20 + d * 20, y + 30 + ((S.t * 60 + d * 13) % 30), 3, 6) end
      end
    end
    if lt > 3 + 3 * 2.2 + 2 and lt < 3 + 3 * 2.2 + 4.5 then G:say("SPLOOSH!", 470, 760, 26, 1) end
    if lt > 18 and lt < 23 then G:say("THE ROUND ROCK!", STONES[3][1], STONES[3][2] - 110, 24, 1) end
    return
  end
  if not art("donuts") then
    G:gradient(0, 0, W, H, {0.98, 0.88, 0.7}, {0.95, 0.72, 0.45})
    lg.setColor(0.98, 0.98, 0.96, 1)
    lg.rectangle("fill", 104, 420, 560, 360, 14, 14, 8)
  end
  -- the donuts: going one at a time
  for i, d in ipairs(DONUTS) do
    local t0 = DONUT_T[i] or 42
    if lt < t0 then donut(d[1], d[2], 1, false) end
  end
  -- the steam
  for i = 1, 3 do
    local k = ((S.t * 0.4 + i / 3) % 1)
    lg.setColor(1, 1, 1, 0.25 * (1 - k))
    lg.ellipse("fill", 210 + i * 110, 430 - k * 120, 16 + k * 10, 26 + k * 20, 16)
  end
  -- the cast along the counter, a donut each flying to them; Pac-Man and the last one
  for i, who in ipairs({1, 2, 3, 4, 0}) do
    local x = 110 + (i - 1) * 137
    local y = 900 - (lt > 26 and lt < 28 and 0 or 0)
    local t0 = DONUT_T[i] or 42
    local munch = lt > t0 + 0.8 and lt < t0 + 3
    guest(who, x, y - L.hop(lt + i, 0.5, munch and 6 or 0), 36, 0, -0.6, munch and "happy" or nil, false,
          who == 0 and (lt > 41 and lt < 43 and 0.95 or nil) or nil)
    local d = DONUTS[i == 5 and 6 or i]
    if lt > t0 and lt < t0 + 0.8 then
      local f = (lt - t0) / 0.8
      donut(lerp(d[1], x, f), lerp(d[2], y - 60, f) - sin(f * pi) * 80, 0.45, false)
    elseif munch then
      donut(x + 30, y - 10, 0.35 * (1 - (lt - t0 - 0.8) / 2.2), true)
    end
  end
  if lt > 42.5 and lt < 45 then G:say("GULP!", 110 + 4 * 137, 820, 26, 1) end
end
CAM.roundrock = function(lt)
  if lt < 26 then
    local x = crosser(lt, min(4, floor(clamp((lt - 3) / 2.2, 0, 4))))
    if lt > 8 and lt < 15 then return L.shot(0, {{0, 470, 780, 1.6}}, W, H) end
    if lt > 17 then return L.shot(lt, {{17, 384, 700, 1.7}, {26, 384, 700, 1.9}}, W, H) end
    return L.shot(lt, {{0, 384, 512, 1}, {3, 220, 760, 1.4}, {8, 384, 760, 1.4}}, W, H)
  end
  return L.shot(lt, {{26, 384, 512, 1}, {28, 384, 640, 1.15}, {29, 220, 760, 1.4}, {31.5, 330, 760, 1.4}, {34, 400, 760, 1.4},
                     {36.5, 520, 760, 1.4}, {39, 600, 760, 1.4}, {41.5, 640, 800, 1.5}, {45, 640, 800, 1.5}}, W, H)
end
CUES.roundrock = {{3 + 3 * 2.2 + 2, "splash"}, {18, "ding"}, {42, "power"}}
for who = 0, 4 do for n = 0, 3 do CUES.roundrock[#CUES.roundrock + 1] = {3 + who * 2.2 + n * 0.9 + 0.9, "boing", 0.2} end end
for _, t0 in ipairs(DONUT_T) do CUES.roundrock[#CUES.roundrock + 1] = {t0 + 0.8, "pop", 0.4} end

-- ------------------------------------------------------------------ Austin: tacos and live music
local TRUCK = {650, 850}
local function austin_van(lt)
  if lt < 8 then return 150, lerp(1140, 950, 1 - (1 - lin(lt, 1, 8)) ^ 2), 1, lt > 1 end
  if lt < 52 then return 150, 950, 1, false end
  local f = lin(lt, 52, 64)
  return lerp(150, 372, f), lerp(950, 712, f ^ 0.7), lerp(1, 0.18, f ^ 0.7), true
end
function D.austin(lt, len)
  local painted = art("austin")
  if not painted then G:gradient(0, 0, W, 700, {0.2, 0.48, 0.9}, {0.7, 0.85, 1}) end
  -- the lane's dashes, the cars up and down
  lg.setColor(1, 0.85, 0.3, 1)
  for i = 0, 8 do
    local k = ((i / 9) + S.t * 0.15) % 1
    lg.rectangle("fill", 382, 700 + k * k * 330, 4 + k * 6, 10 + k * 26)
  end
  for i = 0, 5 do
    local up = i % 2 == 0
    local k = ((S.t * 0.12 + i * 0.17) % 1)
    if not up then k = 1 - k end
    local y = 700 + k * k * 320
    local x = up and (370 - k * 200) or (398 + k * 200)
    local s = 0.3 + k * 1.2
    rgba(({{0.8, 0.2, 0.2}, {0.2, 0.4, 0.8}, {0.9, 0.9, 0.9}, {0.95, 0.75, 0.2}})[i % 4 + 1])
    lg.rectangle("fill", x - 16 * s, y - 10 * s, 32 * s, 14 * s, 3 * s, 3 * s, 4)
    lg.setColor(0.1, 0.1, 0.12, 1)
    lg.circle("fill", x - 10 * s, y + 4 * s, 4 * s, 8)
    lg.circle("fill", x + 10 * s, y + 4 * s, 4 * s, 8)
  end
  -- the busker's guitar and notes (louder while they dance)
  lg.setColor(0.55, 0.3, 0.15, 1)
  lg.setLineWidth(4)
  lg.line(112, 888, 150, 860 + sin(S.t * 8) * 1)
  local loud = (lt > 34 and lt < 52) and 3 or 1
  for i = 0, loud * 2 do
    local ph = ((S.t * 0.6 + i / (loud * 3)) % 1)
    note(130 + ph * 60 + sin(ph * 6 + i) * 10, 850 - ph * 90, 1.1, {1, 0.9, 0.5}, 1 - ph, i % 2 == 1)
  end
  -- the van
  local vx, vy, vs, rolling = austin_van(lt)
  van(vx, vy, vs, 1, rolling, (lt < 9 or lt > 51) and ALL or nil)
  -- the taco line, the tacos, the dancing
  if lt > 8.5 and lt < 52 then
    for i, who in ipairs({0, 1, 2, 3, 4}) do
      local qx = 430 + (i - 1) * 46
      local x = lerp(vx, qx, prog(lt, 8.5 + i * 0.4, 10 + i * 0.4))
      local t0 = 12 + (i - 1) * 4
      if lt > t0 + 1.6 then x = lerp(qx, 250 + i * 70, prog(lt, t0 + 1.6, t0 + 3.4)) end
      local dance = (lt > 34) and L.hop(S.t + i * 0.2, 0.42, 22) or 0
      local hot = who == 4 and lt > 30 and lt < 34
      guest(who, x, 940 - 34 - dance, 30, (lt > t0 + 1.6) and -1 or 1, 0, hot and "wide" or (lt > 34 and "happy" or nil), false,
            who == 0 and (lt > t0 + 1.6 and lt < t0 + 4 and 0.9 or nil) or nil)
      -- the taco: from the window to them, then held
      if lt > t0 and lt < t0 + 1.6 then
        local f = (lt - t0) / 1.6
        lg.setColor(0.95, 0.8, 0.4, 1)
        lg.arc("fill", "pie", lerp(TRUCK[1], x, f), lerp(TRUCK[2], 910, f) - sin(f * pi) * 60, 14, 0, pi, 12)
      end
      if hot then
        for k = 1, 3 do G:spark(x + 30, 906, 200 + G.R:random() * 100, (G.R:random() - 0.5) * 60, 0.4, {1, 0.4 + G.R:random() * 0.4, 0.1}, 10, 0, true) end
      end
    end
  end
  if lt > 30 and lt < 33.5 then G:say("HOT HOT HOT!", 250 + 5 * 70, 840, 24, 1) end
  if lt > 12 and lt < 15 then G:say("ONE TACO, PLEASE!", 430, 860, 22, 1) end
  G:plate("LIVE MUSIC CAPITAL OF THE WORLD", 200, 30, 0xffd23f, L.window(lt, 36, 50, 1))
end
CAM.austin = function(lt)
  local vx, vy = austin_van(lt)
  return L.shot(lt, {{0, 384, 512, 1}, {2, 330, 860, 1.3}, {8, 380, 860, 1.35}, {12, 560, 860, 1.5}, {30, 480, 860, 1.5},
                     {34, 300, 860, 1.4}, {44, 260, 860, 1.4}, {50, 384, 700, 1.1}, {52, 384, 820, 1.2}, {60, 384, 640, 1.15},
                     {65, 384, 512, 1}}, W, H)
end
CUES.austin = {{1, "jet", 0.3}, {8, "clunk"}, {30, "boom", 0.3}, {34, "cheer"}, {52, "jet", 0.3}}
for i = 1, 5 do CUES.austin[#CUES.austin + 1] = {12 + (i - 1) * 4, "pop", 0.4} end

-- ------------------------------------------------------------------ Fort Worth: hats, the drive, the calf
local COATS = {{{0.5, 0.3, 0.16}, {0.95, 0.92, 0.85}}, {{0.15, 0.12, 0.1}, {0.9, 0.88, 0.82}}, {{0.75, 0.55, 0.32}},
               {{0.88, 0.85, 0.78}, {0.5, 0.3, 0.16}}, {{0.55, 0.22, 0.12}}, {{0.82, 0.7, 0.5}, {0.4, 0.25, 0.14}}}
local DRIVE0 = -1000
local function herd_x(lt) return DRIVE0 + (lt + 8) * 30 end
local CALF = {34, 50}
local function calf_pos(lt)
  return L.path(lt, {{CALF[1], 300, 900}, {37, 420, 800}, {39, 470, 790}, {44, 120, 900, "lin"}, {48, -60, 880, "lin"}})
end
function D.stockyards(lt, len)
  if not art("stockyards") then
    G:gradient(0, 0, W, 520, {0.35, 0.55, 0.85}, {0.98, 0.85, 0.6})
    G:gradient(0, 750, W, H, {0.62, 0.3, 0.22}, {0.5, 0.24, 0.18})
  end
  -- the cast on the boardwalk: out of the BOOTS store one by one, in hats
  local cheer = (lt > 20 and lt < 30)
  for i, who in ipairs({1, 2, 3, 4, 0}) do
    local t0 = 1 + i * 1.4
    if lt > t0 and not (who == 0 and lt > 36 and lt < 54) then
      local x = lerp(285, 120 + i * 120, prog(lt, t0, t0 + 1.4))
      local y = 735 - (cheer and L.hop(S.t + i * 0.2, 0.45, 18) or 0)
      local mood = cheer and "happy" or ((lt > 38 and lt < 50) and "wide" or nil)
      if lt > 50 and lt < 56 then mood = "happy" y = y - L.hop(S.t + i, 0.4, 10) end
      guest(who, x, y - 30, 30, who == 0 and 1 or (x < 384 and 1 or -1), 0, mood, true)
    end
  end
  -- the drive: steers left to right, two drovers
  local x0 = herd_x(lt)
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
  -- the calf: out of the herd, nose to nose with Pac-Man, then away with him on the rope
  if lt > CALF[1] and lt < CALF[2] then
    local cx, cy = calf_pos(lt)
    lg.push()
    lg.translate(cx, cy)
    if lt > 39 then lg.scale(-1, 1) end
    steer(0, 0, 0.55, S.t * (lt > 39 and 10 or 4), COATS[3], {0.95, 0.9, 0.8})
    lg.pop()
    -- Pac-Man: off the boardwalk with a lasso, then skiing along behind on the end of it
    local px, py
    if lt < 39 then px, py = lerp(600, 560, prog(lt, 36, 38)), lerp(705, 780, prog(lt, 36, 38))
    else px, py = cx + 120 - min(1, (lt - 39) / 1) * 20, cy - 10 end
    if lt > 36 then
      L.pac(px, py, 30, pi, S.t, lt > 39 and 0.8 or nil)
      hat(px - 2, py - 25, 21, lt > 39 and 0.5 or 0.1)
      lg.setColor(0.8, 0.65, 0.35, 1)
      lg.setLineWidth(2)
      if lt < 38.5 then
        lg.ellipse("line", px, py - 60, 34, 10, 20)
      else
        lg.line(px - 20, py, cx + 20, cy - 16)
      end
      if lt > 39 and S.R:random() < 0.6 then G:puff(px + 20, py + 26, {0.75, 0.6, 0.45}, 10, 60, 1, 8, 0.4) end
    end
  end
  -- after: Pac-Man dizzy in the street, the stars
  if lt > 48 and lt < 54 then
    local px, py = 120, 900
    L.pac(px, py, 30, 0, S.t, 0.3)
    hat(px + 20, py + 10, 21, 1.2)
    lg.setColor(1, 0.9, 0.3, 1)
    for k = 0, 2 do
      local a = S.t * 5 + k * 2.1
      L.star(px + cos(a) * 34, py - 40 + sin(a) * 10, 7)
    end
  end
  if lt > 35 and lt < 37.5 then G:say("YEE-HAW!", 600, 640, 24, 1) end
  if lt > 40 and lt < 44 then G:say("WHOA-OA-OA!", calf_pos(lt) + 120, 760, 24, 1) end
  if lt > 49 and lt < 53 then G:say("...I MEANT TO DO THAT.", 160, 820, 20, 1) end
end
CAM.stockyards = function(lt)
  if lt > 39 and lt < 47 then
    local cx = calf_pos(lt)
    return L.shot(0, {{0, cx + 60, 840, 1.45}}, W, H)
  end
  return L.shot(lt, {{0, 384, 512, 1}, {2, 300, 680, 1.45}, {9, 400, 680, 1.35}, {14, 384, 700, 1.1}, {20, 384, 760, 1.2},
                     {30, 384, 760, 1.2}, {34, 440, 760, 1.4}, {38, 520, 760, 1.5}, {39, 460, 840, 1.45}, {47, 200, 840, 1.45},
                     {54, 200, 840, 1.6}, {58, 384, 600, 1.05}, {65, 384, 512, 1}}, W, H)
end
CUES.stockyards = {{2.4, "clunk", 0.4}, {3.8, "clunk", 0.4}, {5.2, "clunk", 0.4}, {6.6, "clunk", 0.4}, {8, "clunk", 0.4},
                   {20, "cheer"}, {36.5, "whoosh"}, {38.5, "boing"}, {48, "boing"}, {48.2, "pop"}}

-- ------------------------------------------------------------------ San Antonio: the Alamo
local DOVES = 14
function D.alamo(lt, len)
  if not art("alamo") then G:gradient(0, 0, W, 760, {0.25, 0.5, 0.88}, {0.82, 0.88, 0.95}) end
  -- the flags, either side
  for i, fx in ipairs({120, 660}) do
    local w = sin(S.t * 3 + i) * 3
    if i == 1 then
      lg.setColor(0, 0.16, 0.41, 1)
      lg.rectangle("fill", fx + 2, 304, 22, 44)
      lg.setColor(0.97, 0.97, 0.95, 1)
      lg.polygon("fill", fx + 24, 304, fx + 68, 304 + w, fx + 68, 326 + w, fx + 24, 326)
      lg.setColor(0.75, 0.04, 0.19, 1)
      lg.polygon("fill", fx + 24, 326, fx + 68, 326 + w, fx + 68, 348 + w, fx + 24, 348)
      lg.setColor(1, 1, 1, 1)
      L.star(fx + 13, 326, 7)
    else
      for k = 0, 6 do
        if k % 2 == 0 then lg.setColor(0.8, 0.11, 0.17, 1) else lg.setColor(0.97, 0.97, 0.95, 1) end
        lg.polygon("fill", fx + 2, 304 + k * 6.3, fx + 66, 304 + k * 6.3 + w, fx + 66, 310.3 + k * 6.3 + w, fx + 2, 310.3 + k * 6.3)
      end
      lg.setColor(0.14, 0.2, 0.52, 1)
      lg.rectangle("fill", fx + 2, 304, 26, 22)
    end
  end
  -- the doves, up off the roof and away
  for i = 1, DOVES do
    local t0 = 14 + i * 0.35
    local x0, y0 = 250 + (i * 37) % 270, 420 + (i % 3) * 8
    local x, y = x0, y0
    if lt > t0 then
      local f = lt - t0
      x, y = x0 + f * (30 + (i % 5) * 12) * ((i % 2 == 0) and 1 or -1), y0 - f * 60 - f * f * 4
    end
    if y > -30 then
      local flap = lt > t0 and sin(S.t * 14 + i) or 0
      lg.setColor(1, 1, 1, 1)
      lg.ellipse("fill", x, y, 8, 5, 10)
      lg.polygon("fill", x - 2, y, x - 14, y - 8 * flap - 2, x + 2, y - 2)
      lg.polygon("fill", x + 2, y, x + 14, y - 8 * flap - 2, x - 2, y - 2)
    end
  end
  -- the cast in a row before it, hats off for a moment
  for i, who in ipairs({1, 2, 0, 3, 4}) do
    local x = lerp(-80 - i * 50, 160 + (i - 1) * 112, prog(lt, 1 + i * 0.5, 6 + i * 0.5))
    local y = 862
    local off = lt > 10 and lt < 26
    guest(who, x, y - 34, 32, 0, off and 0 or -0.6, off and "sleep" or nil, not off)
    if off then hat(x + 28, y - 10, 20, 0.6) end
  end
  if lt > 28 and lt < 33 then G:say("1836.", 160, 820, 24, 1) end
  G:plate("REMEMBER", 220, 44, 0xffffff, L.window(lt, 12, 30, 1.5))
end
CAM.alamo = function(lt)
  return L.shot(lt, {{0, 384, 512, 1}, {6, 384, 760, 1.3}, {10, 384, 820, 1.4}, {14, 384, 480, 1.15}, {24, 384, 420, 1.3},
                     {28, 300, 820, 1.4}, {33, 384, 600, 1.05}, {40, 384, 512, 1}}, W, H)
end
CUES.alamo = {{14.2, "whoosh", 0.5}, {26, "chime", 0.5}}

-- ------------------------------------------------------------------ barbecue
local SLAB = {420, 700}
function D.bbq(lt, len)
  if not art("bbq") then G:gradient(0, 0, W, H, {0.32, 0.2, 0.14}, {0.16, 0.1, 0.08}) end
  -- the firebox's glow
  lg.setColor(0.6, 0.15, 0.05, 1)
  lg.rectangle("fill", 98, 400, 54, 34)
  C.fx.glow(125, 418, 70, 40, 1, 0.5, 0.1, 0.3 + 0.15 * sin(S.t * 7))
  -- the lid lifting
  local open = prog(lt, 5, 7) * (1 - prog(lt, 12, 13))
  if open > 0 then
    lg.setColor(0.08, 0.08, 0.09, 1)
    lg.rectangle("fill", 160, 312, 380, 52 * open)
    lg.setColor(0.25, 0.25, 0.28, 1)
    lg.push()
    lg.translate(350, 300)
    lg.rotate(-0.5 * open)
    lg.rectangle("fill", -200, -50 * open, 400, 18 + 30 * (1 - open), 20, 20, 8)
    lg.pop()
  end
  -- Clyde the pitmaster: the brisket out of the smoker and onto the paper
  local cx, cy = L.path(lt, {{0, -60, 640}, {4, 300, 520}, {8, 300, 520}, {11, SLAB[1] + 150, 620}, {30, SLAB[1] + 150, 620},
                             {40, SLAB[1] + 150, 620}})
  guest(4, cx, cy, 34, -1, 0.4, lt > 34 and "happy" or nil, false)
  lg.setColor(1, 1, 1, 1)
  lg.rectangle("fill", cx - 18, cy + 4, 36, 20, 3, 3, 4)
  -- the brisket: carried, then on the paper, sliced from the end
  local sliced = floor(clamp((lt - 14) / 1.6, 0, 9))
  local bx, by = SLAB[1], SLAB[2]
  if lt < 11 then bx, by = cx - 10, cy + 40 end
  if lt > 8 then
    local whole = 1 - sliced / 10
    lg.setColor(0.12, 0.06, 0.03, 1)
    lg.rectangle("fill", bx - 110, by - 34, 220 * whole, 68, 16, 16, 6)
    lg.setColor(0.55, 0.18, 0.12, 1)
    lg.rectangle("fill", bx - 110 + 220 * whole - 8, by - 28, 8, 56)
    -- the slices, fanned out below
    for k = 1, sliced do
      local sx, sy = bx - 160 + k * 34, by + 110 + (k % 2) * 6
      lg.setColor(0.12, 0.06, 0.03, 1)
      lg.rectangle("fill", sx - 2, sy - 2, 30, 74, 5, 5, 4)
      lg.setColor(0.62, 0.22, 0.16, 1)
      lg.rectangle("fill", sx + 2, sy + 2, 22, 66, 4, 4, 4)
      lg.setColor(0.72, 0.38, 0.26, 1)
      lg.rectangle("fill", sx + 5, sy + 6, 16, 58, 3, 3, 4)
    end
    -- the knife
    if lt > 14 and lt < 29 then
      local kx = bx - 110 + 220 * whole
      local cut = abs(sin(S.t * 8)) * 16
      lg.setColor(0.85, 0.86, 0.9, 1)
      lg.polygon("fill", kx - 4, by - 70 + cut, kx + 4, by - 70 + cut, kx + 4, by + 20 + cut, kx - 4, by + 20 + cut)
      lg.setColor(0.25, 0.15, 0.1, 1)
      lg.rectangle("fill", kx - 6, by - 110 + cut, 12, 40, 3, 3, 4)
    end
  end
  -- the cast coming for a slice each, the sauce
  for i, who in ipairs({0, 1, 2, 3}) do
    local t0 = 22 + (i - 1) * 3
    if lt > t0 - 2 then
      local x = lerp(-60, 120 + (i - 1) * 90, prog(lt, t0 - 2, t0))
      local munch = lt > t0 and lt < t0 + 6
      guest(who, x, 860 - (munch and abs(sin(S.t * 8)) * 6 or 0), 34, 1, -0.4, (munch or lt > 34) and "happy" or nil, false,
            who == 0 and (munch and nil or 0.3) or nil)
      if who == 0 and lt > 31 then
        lg.setColor(0.55, 0.12, 0.06, 1)
        lg.ellipse("fill", x + 8, 860 + 12, 20, 6, 12)
      end
    end
  end
  if lt > 5.5 and lt < 8 then G:say("SMOKE RING!", 300, 450, 24, 1) end
  if lt > 32 and lt < 36.5 then G:say("BEST. BRISKET. EVER.", 120, 820, 22, 1) end
  G:plate("LOCKHART  ·  TAYLOR  ·  LULING", 120, 30, 0xffd23f, L.window(lt, 16, 30, 1))
end
CAM.bbq = function(lt)
  return L.shot(lt, {{0, 384, 512, 1}, {3, 320, 420, 1.5}, {9, 330, 460, 1.4}, {12, SLAB[1], 700, 1.35}, {22, SLAB[1] - 20, 740, 1.35},
                     {24, 260, 820, 1.4}, {32, 200, 830, 1.5}, {36, 384, 600, 1.05}, {40, 384, 512, 1}}, W, H)
end
CUES.bbq = {{5, "clunk"}, {6, "whoosh"}, {12.5, "clunk"}, {34, "cheer"}}
for k = 1, 9 do CUES.bbq[#CUES.bbq + 1] = {14 + k * 1.6, "tick", 0.4} end
CUES.bbq[#CUES.bbq + 1] = {5.2, function()
  for i = 1, 30 do G:puff(200 + G.R:random() * 300, 340, {0.85, 0.82, 0.8}, 60 + G.R:random() * 60, (G.R:random() - 0.5) * 60, 2.6, 18, 0.5) end
end}

-- ------------------------------------------------------------------ the Panhandle: a train, the wind, the storm
local function pan_van(lt)
  if lt < 8 then return lerp(-200, 360, 1 - (1 - lin(lt, 1, 8)) ^ 2), lt > 1 end
  if lt < 58 then return 360, false end
  return lerp(360, W + 220, lin(lt, 58, 65) ^ 1.5), true
end
local BOLTS = {42, 45.5, 48, 51.5, 54}
local function windmill_angle(lt) return S.t * 2.2 + 8 * max(0, lt - 30) - 4 * max(0, lt - 42) end
function D.panhandle(lt, len)
  if not art("panhandle") then G:gradient(0, 0, W, 640, {0.35, 0.3, 0.55}, {1, 0.72, 0.35}) end
  -- the light going
  lg.setColor(0.15, 0.05, 0.2, 0.3 * lt / len)
  lg.rectangle("fill", 0, 0, W, H)
  -- the train across the plain, far off, its smoke
  if lt > 10 and lt < 32 then
    local tx = lerp(W + 60, -820, lin(lt, 10, 32))
    lg.setColor(0.15, 0.1, 0.12, 1)
    lg.rectangle("fill", tx, 636, 44, 18, 3, 3, 4)
    lg.rectangle("fill", tx + 6, 624, 12, 12)
    lg.rectangle("fill", tx + 30, 628, 12, 8)
    for c = 1, 14 do
      local cx = tx + 30 + c * 50
      lg.setColor(({0.45, 0.3, 0.2})[c % 3 + 1], 0.2, 0.15, 1)
      lg.rectangle("fill", cx, 638, 44, 16, 2, 2, 4)
    end
  end
  -- lightning: the storm getting closer
  for _, b in ipairs(BOLTS) do
    if lt > b and lt < b + 0.3 then
      lg.setColor(1, 1, 1, 0.9)
      lg.setLineWidth(4)
      local x, y = 600 + (b * 37) % 120, 460
      local pts = {x, y}
      for i = 1, 7 do x = x + (((b * 7919 + i * 104729) % 1000) / 1000 - 0.5) * 40 y = y + 30 pts[#pts + 1] = x pts[#pts + 1] = y end
      lg.line(pts)
      lg.setColor(1, 1, 1, 0.25 * (1 - (lt - b) / 0.3))
      lg.rectangle("fill", 0, 0, W, H)
    end
  end
  -- the windmill (faster as the wind gets up), the pump jack
  lg.setColor(0.12, 0.1, 0.12, 1)
  lg.push()
  lg.translate(160, 590)
  lg.rotate(windmill_angle(lt))
  for i = 0, 11 do
    lg.rotate(pi / 6)
    lg.polygon("fill", 10, -1.5, 44, -4, 44, 4, 10, 1.5)
  end
  lg.setLineWidth(2)
  lg.circle("line", 0, 0, 44, 24)
  lg.pop()
  lg.circle("fill", 160, 590, 7, 12)
  local nod = sin(S.t * 1.4) * 0.25
  lg.push()
  lg.translate(610, 790)
  lg.rotate(nod)
  lg.rectangle("fill", -80, -8, 160, 16)
  lg.polygon("fill", 80, -26, 100, -10, 100, 26, 80, 14)
  lg.pop()
  lg.setLineWidth(3)
  lg.line(610 + cos(nod) * 96, 790 + sin(nod) * 96 + 20, 706, 880)
  -- tumbleweeds
  if lt > 30 and lt < 44 then
    for k = 0, 2 do
      local f = lin(lt, 30 + k * 3, 36 + k * 3)
      if f > 0 and f < 1 then
        local x = lerp(-60, W + 60, f)
        local y = 940 - abs(sin(f * 12)) * 40
        lg.setColor(0.6, 0.45, 0.28, 1)
        lg.setLineWidth(2)
        for j = 1, 6 do lg.circle("line", x + cos(j + lt * 6) * 10, y + sin(j * 1.3 + lt * 6) * 10, 14, 10) end
      end
    end
  end
  -- the van, the cast up on its roof watching
  local vx, rolling = pan_van(lt)
  van(vx, 960, 1, 1, rolling, (lt < 8 or lt > 57) and ALL or nil)
  if lt > 8.5 and lt < 57.5 then
    for i, who in ipairs({1, 2, 0, 3, 4}) do
      local x = vx - 96 + (i - 1) * 48
      local up = prog(lt, 8.5 + i * 0.4, 9.5 + i * 0.4)
      local y = lerp(960, 864, up)
      local wave = (lt > 14 and lt < 30) and L.hop(S.t + i * 0.3, 0.6, 10) or 0
      local wow = false
      for _, b in ipairs(BOLTS) do if lt > b and lt < b + 1.4 then wow = true end end
      local bonk = who == 3 and lt > 36 and lt < 38.5
      guest(who, x, y - 28 - wave, 24, 1, (lt > 40) and -0.6 or 0, (wow or bonk) and "wide" or ((lt > 14 and lt < 30) and "happy" or nil), true)
    end
  end
  if lt > 14 and lt < 18 then G:say("CHOO CHOO!", 340, 780, 24, 1) end
  if lt > 42.3 and lt < 45 then G:say("OOOOOH!", 380, 780, 26, 1) end
end
CAM.panhandle = function(lt)
  local vx = pan_van(lt)
  return L.shot(lt, {{0, 384, 512, 1}, {2, 200, 820, 1.3}, {8, 360, 840, 1.4}, {12, 384, 700, 1.15}, {20, 300, 680, 1.3},
                     {30, 384, 700, 1.1}, {33, 384, 860, 1.3}, {40, 384, 700, 1.05}, {44, 560, 560, 1.3}, {50, 520, 600, 1.2},
                     {56, 384, 700, 1.1}, {65, 600, 760, 1.2}}, W, H)
end
CUES.panhandle = {{1, "jet", 0.3}, {14, "whoosh"}, {16, "whoosh", 0.5}, {30, "whoosh"}, {37, "boing"}, {58, "jet", 0.3}}
for _, b in ipairs(BOLTS) do CUES.panhandle[#CUES.panhandle + 1] = {b + 0.2, "thunder", 0.5} end

-- ------------------------------------------------------------------ the bats
local function bat_ribbon(lt)
  local b = S.batb
  b:clear()
  if lt > 6 then
    local n = min(700, floor((lt - 6) * 40))
    for i = 1, n do
      local age = ((lt - 6) - i / 40)
      local x = 300 + i % 7 * 10 + age * 30 + sin(age * 1.5 + i * 0.3) * (20 + age * 6)
      local y = 670 - age * 70 + sin(age * 2 + i) * 6
      if y > -20 then
        local fl = floor(S.t * 12 + i) % 2 + 1
        b:add(S.batq[fl], x + sin(i * 1.7) * age * 4, y, 0, 3, 3, 4, 2)
      end
    end
  end
  lg.draw(b)
end
function D.bats(lt, len)
  local k = lt / len
  if S.art.bats_dusk and S.art.bats_night then
    art("bats_dusk")
    art("bats_night", clamp(k * 1.3, 0, 1))
  else
    G:gradient(0, 0, W, 600, {0.3, 0.2, 0.45}, {1, 0.55, 0.35})
  end
  lg.setColor(0.08, 0.06, 0.1, 1)
  bat_ribbon(lt)
  -- the cast on the bank, looking up; a bat on Inky
  for i, who in ipairs({1, 2, 0, 3, 4}) do
    local x = lerp(-80 - i * 40, 150 + (i - 1) * 120, prog(lt, 0.5 + i * 0.3, 4 + i * 0.3))
    local look = lt > 6 and -1 or 0
    local wow = lt > 6 and lt < 10
    guest(who, x, 960 - 36, 34, 0, look, (wow or (who == 3 and lt > 20 and lt < 26)) and "wide" or (lt > 36 and "happy" or nil), true)
    if who == 3 and lt > 19.5 and lt < 27 then
      lg.setColor(0.08, 0.06, 0.1, 1)
      local hy = 960 - 36 - 50
      local flap = sin(S.t * 20) * 6
      lg.ellipse("fill", x, hy, 8, 6, 10)
      lg.polygon("fill", x, hy, x - 22, hy - 6 - flap, x - 12, hy + 4)
      lg.polygon("fill", x, hy, x + 22, hy - 6 - flap, x + 12, hy + 4)
    end
  end
  if lt > 1 and lt < 5 then G:say("ANY MINUTE NOW...", 384, 840, 22, 1) end
  if lt > 6 and lt < 9 then G:say("THERE!", 270, 840, 28, 1) end
  if lt > 21 and lt < 25 then G:say("EEK!", 150 + 3 * 120, 840, 26, 1) end
  if lt > 36 and lt < 42 then G:say("A MILLION AND A HALF!", 384, 840, 22, 1) end
end
CAM.bats = function(lt)
  return L.shot(lt, {{0, 384, 700, 1.2}, {5, 384, 820, 1.35}, {8, 384, 560, 1.15}, {16, 460, 380, 1.3}, {19, 520, 860, 1.5},
                     {26, 520, 860, 1.5}, {30, 420, 400, 1.2}, {36, 384, 512, 1}, {42, 384, 760, 1.2}, {50, 384, 512, 1}}, W, H)
end
CUES.bats = {{6, "whoosh"}, {20, "boing"}, {36, "cheer"}}

-- ------------------------------------------------------------------ Big Bend: the campfire
local FIRE = {384, 930}
local function marfa(lt, i)
  -- the lights on the horizon; between 36 and 50 they come down to the camp, round it, and away
  local x = 120 + i * 140 + sin(S.t * 0.2 + i) * 40
  local y = 752
  if lt > 36 and lt < 50 then
    local f = prog(lt, 36, 40) * (1 - prog(lt, 47, 50))
    local a = S.t * 1.5 + i * pi / 2
    x = lerp(x, FIRE[1] + cos(a) * (140 + i * 10), f)
    y = lerp(y, FIRE[2] - 90 + sin(a) * 40, f)
  end
  return x, y
end
function D.bigbend(lt, len)
  if not art("bigbend") then G:gradient(0, 0, W, 760, {0.01, 0.01, 0.05}, {0.06, 0.05, 0.14}) end
  for i, s in ipairs(S.bright) do
    local tw = 0.6 + 0.4 * sin(S.t * (1 + i % 4) + i)
    lg.setColor(1, 1, 0.95, tw)
    lg.circle("fill", s[1], s[2], s[3], 6)
  end
  -- shooting stars at the end
  for k, t0 in ipairs({56, 60, 63}) do
    if lt > t0 and lt < t0 + 0.8 then
      local p = (lt - t0) / 0.8
      lg.setColor(1, 1, 1, 1 - p)
      lg.setLineWidth(2)
      lg.line(500 - p * 300 - k * 40, 120 + p * 120, 540 - p * 300 - k * 40, 100 + p * 120)
    end
  end
  -- the Marfa lights
  lg.setBlendMode("add")
  for i = 1, 4 do
    local a = (lt > 34 and lt < 51) and 1 or clamp(sin(S.t * (0.3 + i * 0.07) + i * 2) * 1.6, 0, 1)
    local x, y = marfa(lt, i)
    C.fx.glow(x, y, 26, 26, 1, 0.85, 0.6, 0.6 * a)
    lg.setColor(1, 0.95, 0.8, a)
    lg.circle("fill", x, y, 4, 8)
  end
  lg.setBlendMode("alpha")
  -- the coyote on the ridge, howling
  if lt > 50 then
    local howl = (lt > 51 and lt < 56) and 1 or 0
    lg.setColor(0.05, 0.04, 0.06, 1)
    lg.ellipse("fill", 236, 556, 22, 9, 12)
    lg.polygon("fill", 252, 552, 262, 534 - howl * 10, 272, 538 - howl * 12, 262, 556)
    lg.polygon("fill", 214, 554, 196, 548, 214, 560)
    for i = 0, 3 do lg.rectangle("fill", 220 + i * 9, 560, 3, 14) end
  end
  -- the camp: the tent popping up, the fire
  local tent = prog(lt, 3, 5)
  if tent > 0 then
    lg.setColor(0.75, 0.33, 0.05, 1)
    lg.polygon("fill", 560 - 90 * tent, 960, 560 + 90 * tent, 960, 560, 960 - 130 * tent)
    lg.setColor(0.4, 0.15, 0.03, 1)
    lg.polygon("fill", 545, 960, 575, 960, 560, 960 - 80 * tent)
  end
  lg.setColor(0.35, 0.22, 0.12, 1)
  lg.setLineWidth(6)
  lg.line(FIRE[1] - 30, FIRE[2] + 14, FIRE[1] + 30, FIRE[2])
  lg.line(FIRE[1] - 30, FIRE[2], FIRE[1] + 30, FIRE[2] + 14)
  if lt > 8 then
    local f = (lt > 56) and 0.5 or 1
    C.fx.glow(FIRE[1], FIRE[2] - 20, 160 * f, 120 * f, 1, 0.55, 0.2, 0.45)
    lg.setColor(1, 0.5, 0.1, 0.9)
    lg.polygon("fill", FIRE[1] - 26, FIRE[2], FIRE[1], FIRE[2] - (60 + sin(S.t * 9) * 12) * f, FIRE[1] + 26, FIRE[2])
    lg.setColor(1, 0.85, 0.3, 0.9)
    lg.polygon("fill", FIRE[1] - 12, FIRE[2], FIRE[1], FIRE[2] - (34 + sin(S.t * 11) * 8) * f, FIRE[1] + 12, FIRE[2])
  end
  -- round the fire: marshmallows, the ghost story, then asleep
  for i, who in ipairs({1, 2, 0, 3, 4}) do
    local a = pi + (i - 1) / 4 * pi
    local x = FIRE[1] + cos(a) * 200
    local y = FIRE[2] + 10 - abs(sin(a)) * 40
    if lt < 6 then x = lerp(-80 - i * 40, x, prog(lt, 1 + i * 0.3, 5 + i * 0.3)) end
    local asleep = lt > 56
    local scared = lt > 30 and lt < 33 and who ~= 1
    local mood = asleep and "sleep" or (scared and "scared" or ((lt > 36 and lt < 50) and "wide" or nil))
    guest(who, x, y - 30, 28, x < FIRE[1] and 1 or -1, (lt > 36 and lt < 50) and -0.5 or 0, mood, true,
          who == 0 and (asleep and 0.05 or nil) or nil)
    -- the marshmallow sticks
    if lt > 12 and lt < 26 and who ~= 1 then
      local tx, ty = lerp(x, FIRE[1], 0.62), FIRE[2] - 50
      lg.setColor(0.5, 0.35, 0.2, 1)
      lg.setLineWidth(2)
      lg.line(x + (x < FIRE[1] and 20 or -20), y - 20, tx, ty)
      local burnt = who == 0 and lt > 19
      lg.setColor(burnt and 0.15 or 1, burnt and 0.1 or 0.97, burnt and 0.08 or 0.9, 1)
      lg.rectangle("fill", tx - 7, ty - 6, 14, 12, 4, 4, 4)
      if who == 0 and lt > 19 and lt < 21 then C.fx.glow(tx, ty - 10, 24, 30, 1, 0.6, 0.2, 0.9) end
    end
    -- Blinky's flashlight under his face
    if who == 1 and lt > 26 and lt < 34 then
      C.fx.glow(x, y - 40, 40, 50, 1, 1, 0.8, 0.5)
    end
  end
  if lt > 19 and lt < 22 then G:say("FWOOSH!", FIRE[1] - 70, 820, 26, 1) end
  if lt > 26 and lt < 30 then G:say("...AND THEN...", FIRE[1] - 200, 820, 22, 1) end
  if lt > 30 and lt < 32.5 then G:say("BOO!", FIRE[1] - 200, 820, 30, 1) end
  if lt > 38 and lt < 42 then G:say("THE MARFA LIGHTS!", FIRE[1], 780, 22, 1) end
end
CAM.bigbend = function(lt)
  return L.shot(lt, {{0, 384, 512, 1}, {4, 420, 840, 1.3}, {9, 384, 860, 1.4}, {13, 330, 860, 1.6}, {19, 300, 860, 1.7},
                     {24, 384, 860, 1.4}, {27, 220, 860, 1.6}, {33, 384, 840, 1.3}, {36, 384, 700, 1.05}, {50, 384, 700, 1.05},
                     {52, 240, 560, 1.6}, {56, 384, 860, 1.35}, {60, 384, 400, 1.1}, {65, 384, 512, 1}}, W, H)
end
CUES.bigbend = {{3, "pop"}, {8, "whoosh", 0.4}, {19, "boom", 0.3}, {30, "boo"}, {36, "chime"}, {47, "whoosh"}, {51, "screech", 0.5},
                {56, "chime", 0.4}}

-- ------------------------------------------------------------------ the Lone Star
function D.finale(lt, len)
  if not art("finale") then G:gradient(0, 0, W, H, {0.01, 0.01, 0.06}, {0.08, 0.06, 0.2}) end
  G:draw_back()
  L.pole(150, 240, 1024)
  S.flag:draw(155, 260, 470, 313, S.t, 0.7 + 0.1 * sin(S.t * 0.4), {0.95, 0.95, 1})
  local a = L.window(lt, 1, 25, 1.5)
  G:caption("TEXAS", 640, 110, 0xffb347, a)
  G:caption("THE LONE STAR STATE", 790, 34, 0xffffff, a)
  -- the cast, hats on, waving little flags
  for i, who in ipairs({1, 2, 0, 3, 4}) do
    local t0 = 2 + i * 0.8
    if lt > t0 then
      local x = 200 + (i - 1) * 120
      local y = lerp(H + 60, 968, prog(lt, t0, t0 + 0.6)) - L.hop(lt + i * 0.2, 0.5, 14)
      guest(who, x, y, 30, 0, -0.5, "happy", true)
      lg.setColor(0.6, 0.6, 0.6, 1)
      lg.setLineWidth(2)
      lg.line(x + 26, y, x + 30, y - 50)
      lg.setColor(0, 0.16, 0.41, 1)
      lg.rectangle("fill", x + 30, y - 50, 8, 16)
      lg.setColor(0.97, 0.97, 0.95, 1)
      lg.rectangle("fill", x + 38, y - 50 + sin(S.t * 6 + i), 16, 8)
      lg.setColor(0.75, 0.04, 0.19, 1)
      lg.rectangle("fill", x + 38, y - 42 + sin(S.t * 6 + i), 16, 8)
    end
  end
  G:caption("FRIENDSHIP", 850, 26, 0x9fd8ff, L.window(lt, 6, 25, 1.5))
end
CAM.finale = function(lt) return L.shot(lt, {{0, 384, 512, 1}, {14, 384, 600, 1.1}, {25, 384, 512, 1}}, W, H) end
CUES.finale = {}

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
                      {"FRIENDSHIP", 26, 0x9fd8ff}, {"REMEMBER", 44, 0xffffff},
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

local function cues(name, lt, dt)
  local list = CUES[name]
  if not list then return end
  for _, c in ipairs(list) do
    if lt - dt < c[1] and lt >= c[1] then
      if type(c[2]) == "function" then c[2]() else C.sfx(c[2], c[3]) end
    end
  end
end

function T.update(dt)
  if not S then return false end
  G:step(dt)
  S.t = G.t
  local sc, lt, len = scene_at(S.t)
  cues(sc[2], lt, dt)
  -- the finale's fireworks: Texas red, white and blue
  if sc[2] == "finale" and lt > 3 and lt < 22 then
    S.fw = (S.fw or 0) - dt
    if S.fw <= 0 then
      S.fw = 0.8 + G.R:random() * 0.8
      G:rocket(260 + G.R:random() * 440, 120 + G.R:random() * 200,
               {from = 1024, colours = {{0.75, 0.1, 0.2}, {1, 1, 1}, {0.2, 0.35, 0.9}}})
    end
  end
  -- smoke: the barbecue's stack, the meat steaming; the campfire's sparks
  if sc[2] == "bbq" and G.R:random() < dt * 8 then
    G:puff(533 + (G.R:random() - 0.5) * 10, 160, {0.75, 0.72, 0.7}, 50 + G.R:random() * 20, 12, 3, 10, 0.4)
  end
  if sc[2] == "bbq" and lt > 14 and G.R:random() < dt * 3 then
    G:puff(260 + G.R:random() * 260, 780, {1, 1, 1}, 30, 0, 1.6, 6, 0.25)
  end
  if sc[2] == "bigbend" and lt > 8 and G.R:random() < dt * 6 then
    G:spark(384 + (G.R:random() - 0.5) * 30, 900, (G.R:random() - 0.5) * 40, -80 - G.R:random() * 80, 1.4, {1, 0.7, 0.3}, 4, -10, true)
  end
  return S.t >= LEN
end

function T.draw()
  if not S then return end
  local sc, lt, len = scene_at(S.t)
  local cam = CAM[sc[2]]
  local x, y, z, shake = 384, 512, 1, 0
  if cam then x, y, z, shake = cam(lt, len) end
  G:look(x, y, z, shake)
  D[sc[2]](lt, len)
  if sc[2] ~= "finale" then G:draw_back() end
  G:draw_front()
  G:unlook()
  -- the scene's title, and its place line at the bottom
  if sc[4] then
    local a = L.window(lt, 1.5, 9, 1)
    G:plate(sc[4], sc[2] == "bbq" and 60 or 70, 56, 0xffffff, a)
    local b = L.window(lt, 2, len - 1.5, 1)
    lg.setColor(0.02, 0.02, 0.06, 0.55 * b)
    lg.rectangle("fill", 0, H - 50, W, 50)
    G:text(sc[5], 0, H - 38, 20, {1, 0.92, 0.75}, b)
  end
  local f = 1 - min(lt / 1.2, (len - lt) / 1.2, 1)
  if f > 0 then
    lg.setColor(0, 0, 0, f)
    lg.rectangle("fill", 0, 0, W, H)
  end
end

return T
