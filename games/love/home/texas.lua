-- Texas: A Day Across Texas. Home's homage to the state (sincere, not satire), twelve and a half minutes from sunrise
-- on the Gulf to the stars over Big Bend, a scene for each place. The cast make the trip in their van (TEXAS OR BUST),
-- doing the thing each place is for; every scene a story with its own camera (SHOWS_BLUEPRINT.md; reviewed with
-- tools/show_review.py, notebook in shows/texas.md):
--   0:00  the Lone Star flag at first light                                   (Lone Star Sunrise)
--   0:12  the Gulf Coast: Galveston at sunrise; the sandcastle built tower by tower, a pelican's dive, the wave
--   1:20  the Hill Country: the picture in the bluebonnets (an armadillo photobombs it), the monarchs lifting
--                                                                             (Bluebonnet Waltz)
--   2:20  Round Rock: across Brushy Creek on the stones (Inky in), up on the round rock; the donuts, one each
--   3:05  Austin: the taco truck (one too hot), the grackles drown out the busker, the band on a flatbed, the street
--         dances, up Congress Avenue                                          (Congress Avenue, with its stop-time)
--   4:10  Fort Worth: hats from the boot store, the cattle drive, Pac-Man roping a calf (it ropes him), the calf
--         follows the van                                                     (Stockyards Swing)
--   5:15  Dinosaur Valley: the tracks in the Paluxy, long ago (the sauropod, the meat-eater's sneeze), the
--         ghosts leave no prints, the hills roar back                         (Paluxy Stomp)
--   6:20  San Antonio: the Alamo; hats off, the doves                         (Remember)
--   6:45  the River Walk at dusk: the duck family crossing, the lights on over the water, the ducks get Pac-Man's
--         chips, the mariachis, cascarones                                    (River Walk Son)
--   7:45  Central Texas barbecue: the line, the pit room's smoke, the brisket sliced, a burnt end, the trays, the
--         sauce bottle, the food coma                                         (Conjunto)
--   8:35  the Panhandle: Cadillac Ranch spray-painted, the freight train, tumbleweeds, the storm, umbrellas, a
--         rainbow                                                             (Red River Valley)
--   9:55  dusk at the Congress Avenue Bridge: kayaks, the river of bats, phones flashing, the moon (Bat Flight)
--  10:45  Big Bend: the stars come out, the tent (on Clyde), the fire, the ghost story, the Marfa lights visit,
--         Saturn through the telescope, a wish on a shooting star             (Desert Night)
--  11:50  the day's scrapbook; the Lone Star flag under the stars             (Lone Star)
-- Drawn from shapes over painted places (tools/art/texas.py); the flag is showlib's cloth.
local lg = love.graphics
local L = require("showlib")
local T = {}
local C, G
local W, H = 768, 1024
local LEN                                   -- (the scenes' lengths added up, below)
local sin, cos, floor, min, max, abs, pi = math.sin, math.cos, math.floor, math.min, math.max, math.abs, math.pi
local clamp, ease, lerp, mix = L.clamp, L.ease, L.lerp, L.mix
local steer, live_oak = L.steer, L.live_oak

-- {length, name, song, title, place}; each scene's start (s[1]) is worked out below from the lengths
local SCENES = {
  {12, "open", "tx_sunrise"},
  {68, "coast", "tx_sunrise", "THE GULF COAST", "GALVESTON  ·  SUNRISE"},
  {60, "hills", "tx_waltz", "THE HILL COUNTRY", "BLUEBONNETS  ·  INDIAN PAINTBRUSH  ·  LIVE OAKS"},
  {45, "roundrock", "tx_waltz", "ROUND ROCK", "BRUSHY CREEK  ·  THE CHISHOLM TRAIL CROSSING"},
  {65, "austin", "tx_austin", "AUSTIN", "THE CAPITOL  ·  CONGRESS AVENUE"},
  {65, "stockyards", "tx_swing", "FORT WORTH", "THE STOCKYARDS  ·  THE CATTLE DRIVE"},
  {65, "dinovalley", "tx_dino", "DINOSAUR VALLEY", "GLEN ROSE  ·  TRACKS IN THE PALUXY RIVER"},
  {25, "alamo", "tx_alamo", "SAN ANTONIO", "THE ALAMO  ·  1836"},
  {60, "riverwalk", "tx_mariachi", "THE RIVER WALK", "SAN ANTONIO  ·  AT DUSK"},
  {50, "bbq", "tx_conjunto", "CENTRAL TEXAS BARBECUE", "POST OAK SMOKE  ·  LOW AND SLOW"},
  {80, "panhandle", "tx_redriver", "THE PANHANDLE", "CADILLAC RANCH  ·  PALO DURO CANYON  ·  THE HIGH PLAINS"},
  {50, "bats", "tx_bats", "CONGRESS AVENUE BRIDGE", "A MILLION AND A HALF BATS  ·  EVERY SUMMER NIGHT"},
  {65, "bigbend", "tx_desert", "BIG BEND", "THE CHISOS MOUNTAINS  ·  THE DARKEST SKIES IN TEXAS"},
  {35, "finale", "tx_lonestar", nil, nil, "THE LONE STAR"},
}
do
  local t = 0
  for _, s in ipairs(SCENES) do s.len, s[1] = s[1], t t = t + s.len end
  LEN = t
end
T.LEN = LEN
T.SEGMENTS = {}
for i, s in ipairs(SCENES) do
  if s[4] or s[6] then T.SEGMENTS[#T.SEGMENTS + 1] = {s[1], s[4] or s[6]} end
end
T.THUMB = 2

local S                                -- this showing
local art_for                          -- (below)
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

-- ------------------------------------------------------------------ Austin: a Saturday on Congress Avenue
-- The van parks; the taco truck (one taco too hot); the grackles land on the wire one by one and drown out the
-- busker; a band rolls up on a flatbed, the grackles burst away, the street fills and dances; up the avenue.
local TRUCK = {650, 850}
local function austin_van(lt)
  if lt < 8 then return 150, lerp(1140, 950, 1 - (1 - lin(lt, 1, 8)) ^ 2), 1, lt > 1 end
  if lt < 54 then return 150, 950, 1, false end
  local f = lin(lt, 54, 65)
  return lerp(150, 372, f), lerp(950, 712, f ^ 0.7), lerp(1, 0.18, f ^ 0.7), true
end
-- the wire over the avenue, and where on it grackle i sits
local WIRE = {{20, 330}, {748, 312}}
local function wire_y(x) local u = (x - WIRE[1][1]) / (WIRE[2][1] - WIRE[1][1]) return lerp(WIRE[1][2], WIRE[2][2], u) + sin(u * pi) * 34 end
local GRACKLES = 16
local function grackle_at(lt, i)
  -- in one by one (20-30), on the wire, then all away at once when the band hits (37)
  local x = 60 + (i - 1) * 42 + (i % 3) * 6
  local y = wire_y(x) - 2
  local t0 = 20 + (i - 1) * 0.6
  if lt < t0 then return nil end
  if lt < t0 + 1 then
    local f = lt - t0
    return lerp(x + (i % 2 == 0 and 260 or -260), x, f), y - (1 - f) * 160, true
  end
  if lt > 37 then
    local f = lt - 37 - (i % 4) * 0.08
    if f > 0 then
      return x + f * (90 + i * 7) * ((i % 2 == 0) and 1 or -1), y - f * 260 - f * f * 40, true
    end
  end
  return x, y, false
end
local function grackle(x, y, s, dir, t, flying, squawk)
  lg.push()
  lg.translate(x, y)
  lg.scale(s * dir, s)
  lg.setColor(0.06, 0.05, 0.1, 1)
  lg.ellipse("fill", 0, -6, 10, 7, 12)
  lg.polygon("fill", -6, -4, -26, -18, -24, -6)                 -- the long keel tail
  lg.circle("fill", 8, -13, 5, 10)
  lg.setColor(0.95, 0.9, 0.3, 1)
  lg.circle("fill", 9, -14, 1.6, 6)
  lg.setColor(0.06, 0.05, 0.1, 1)
  local o = squawk and 4 or 0.5
  lg.polygon("fill", 12, -14, 20, -13 - o, 12, -11)
  lg.polygon("fill", 12, -11, 20, -10 + o, 12, -10)
  if flying then
    local f = sin(t * 20) * 9
    lg.polygon("fill", -4, -8, 6, -8, 0, -22 - f)
  else
    lg.setLineWidth(1.5)
    lg.line(-2, 0, -2, 4)
    lg.line(3, 0, 3, 4)
  end
  lg.pop()
end
-- a person in the crowd: legs stepping, a shirt, arms up when dancing, a head with hair
local SKINS = {{0.93, 0.76, 0.62}, {0.78, 0.57, 0.42}, {0.55, 0.37, 0.26}, {0.97, 0.82, 0.7}, {0.42, 0.28, 0.2}}
local SHIRTS = {{0.9, 0.3, 0.25}, {0.25, 0.55, 0.85}, {0.95, 0.8, 0.25}, {0.3, 0.7, 0.4}, {0.95, 0.95, 0.92}, {0.75, 0.35, 0.8}}
local function person(x, y, s, k, t, dance)
  local sk, sh = SKINS[k % #SKINS + 1], SHIRTS[k % #SHIRTS + 1]
  local hop = dance and L.hop(t + k * 0.13, 0.46, 8 * s) or 0
  y = y - hop
  local step = dance and sin(t * 6.8 + k) * 4 * s or 0
  lg.setColor(0.22, 0.27, 0.42, 1)
  lg.rectangle("fill", x - 6 * s + step * 0.4, y - 16 * s, 5 * s, 16 * s)
  lg.rectangle("fill", x + 1 * s - step * 0.4, y - 16 * s, 5 * s, 16 * s)
  lg.setColor(sh[1], sh[2], sh[3], 1)
  lg.rectangle("fill", x - 9 * s, y - 38 * s, 18 * s, 23 * s, 4 * s, 4 * s, 6)
  lg.setColor(sk[1], sk[2], sk[3], 1)
  local up = dance and (floor(t * 2.2 + k) % 2 == 0) and -1 or 1
  lg.rectangle("fill", x - 13 * s, y - (up < 0 and 52 or 36) * s, 4 * s, 16 * s, 2 * s, 2 * s, 4)
  lg.rectangle("fill", x + 9 * s, y - (up < 0 and 36 or 52) * s, 4 * s, 16 * s, 2 * s, 2 * s, 4)
  lg.circle("fill", x, y - 45 * s, 7 * s, 14)
  local hr = SKINS[(k * 3) % #SKINS + 1]
  lg.setColor(hr[1] * 0.4, hr[2] * 0.35, hr[3] * 0.3, 1)
  lg.arc("fill", "pie", x, y - 46 * s, 7.4 * s, pi * 1.05, pi * 1.95, 10)
end
-- the band's flatbed: in from the left (34-37), parked, three players, lights strung over it
local function band_x(lt) return L.path(lt, {{33, -360, 0}, {37, 300, 0}}) end
local function flatbed(x, y, t, playing)
  lg.setColor(0, 0, 0, 0.25)
  lg.ellipse("fill", x, y + 4, 200, 12, 20)
  -- the cab
  lg.setColor(0.2, 0.45, 0.6, 1)
  lg.rectangle("fill", x + 110, y - 90, 80, 70, 10, 10, 8)
  lg.setColor(0.65, 0.85, 0.95, 1)
  lg.rectangle("fill", x + 140, y - 82, 40, 28, 4, 4, 4)
  -- the bed, the wheels
  lg.setColor(0.45, 0.3, 0.2, 1)
  lg.rectangle("fill", x - 190, y - 40, 300, 22)
  lg.setColor(0.12, 0.12, 0.14, 1)
  for _, wx in ipairs({-130, 40, 150}) do lg.circle("fill", x + wx, y - 14, 18, 16) end
  -- string lights over the bed
  for i = 0, 10 do
    local lx = x - 180 + i * 28
    local ly = y - 150 + sin(i / 10 * pi) * 18
    local c = ({{1, 0.4, 0.4}, {1, 0.85, 0.4}, {0.4, 0.8, 1}})[i % 3 + 1]
    lg.setColor(c[1], c[2], c[3], 1)
    lg.circle("fill", lx, ly, 4, 8)
  end
  -- the players: guitar, fiddle, a drum kit
  for k = 0, 2 do
    local px = x - 150 + k * 95
    local bob = playing and L.hop(t + k * 0.2, 0.54, 5) or 0
    person(px, y - 40 - bob * 0, 1.5, k + 2, t, false)
    if k == 0 then
      lg.setColor(0.75, 0.35, 0.12, 1)
      lg.ellipse("fill", px + 6, y - 82, 16, 12, 14)
      lg.setColor(0.35, 0.2, 0.1, 1)
      lg.polygon("fill", px + 14, y - 88, px + 18, y - 84, px + 48, y - 112, px + 44, y - 116)
    elseif k == 1 then
      lg.setColor(0.6, 0.3, 0.1, 1)
      lg.ellipse("fill", px + 14, y - 104, 12, 7, 12)
      local b = playing and sin(t * 9) * 12 or 0
      lg.setColor(0.9, 0.85, 0.75, 1)
      lg.setLineWidth(2)
      lg.line(px - 10 + b, y - 118, px + 34 + b, y - 92)
    else
      lg.setColor(0.85, 0.2, 0.2, 1)
      lg.ellipse("fill", px + 30, y - 66, 22, 14, 16)
      lg.setColor(1, 1, 1, 1)
      lg.ellipse("fill", px + 30, y - 72, 20, 6, 16)
      lg.setColor(0.9, 0.8, 0.3, 1)
      lg.ellipse("fill", px - 12, y - 92 + (playing and abs(sin(t * 7)) * 3 or 0), 14, 3, 12)
    end
  end
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
  -- the wire, its poles, the grackles
  lg.setColor(0.2, 0.18, 0.18, 1)
  lg.rectangle("fill", WIRE[1][1] - 6, WIRE[1][2] - 10, 12, 700)
  lg.rectangle("fill", WIRE[2][1] - 6, WIRE[2][2] - 10, 12, 700)
  lg.rectangle("fill", WIRE[1][1] - 20, WIRE[1][2] + 6, 40, 5)
  lg.rectangle("fill", WIRE[2][1] - 20, WIRE[2][2] + 6, 40, 5)
  local pts = {}
  for x = WIRE[1][1], WIRE[2][1], 24 do pts[#pts + 1] = x pts[#pts + 1] = wire_y(x) end
  lg.setLineWidth(2)
  lg.line(pts)
  for i = 1, GRACKLES do
    local x, y, flying = grackle_at(lt, i)
    if x and y > -40 then
      local squawk = not flying and lt > 26 and lt < 37 and floor(S.t * 3 + i * 0.7) % 3 == 0
      grackle(x, y, 1.6, (i % 2 == 0) and -1 or 1, S.t + i, flying, squawk)
    end
  end
  -- the busker's guitar and notes (drowned out by the grackles, 26-37)
  lg.setColor(0.55, 0.3, 0.15, 1)
  lg.setLineWidth(4)
  lg.line(112, 888, 150, 860 + sin(S.t * 8) * 1)
  if lt < 26 or lt > 37 then
    for i = 0, 2 do
      local ph = ((S.t * 0.6 + i / 3) % 1)
      note(130 + ph * 60 + sin(ph * 6 + i) * 10, 850 - ph * 90, 1.1, {1, 0.9, 0.5}, 1 - ph, i % 2 == 1)
    end
  end
  -- the band: notes pouring off the flatbed
  local fbx = band_x(lt)
  if lt > 33 and lt < 56 then
    flatbed(fbx, 960, S.t, lt > 37)
    if lt > 37 then
      for i = 0, 5 do
        local ph = ((S.t * 0.5 + i / 6) % 1)
        note(fbx - 160 + i * 50 + sin(ph * 6 + i) * 14, 800 - ph * 220, 1.4, {1, 0.85, 0.4}, 1 - ph, i % 2 == 1)
      end
    end
  end
  -- the crowd filling the street, dancing
  if lt > 37 then
    local n = floor(clamp((lt - 37) / 10, 0, 1) * 22)
    for k = 1, n do
      local side = k % 2 == 0 and 1 or -1
      local tx = 384 + side * (60 + (k * 37) % 300)
      local x = lerp(384 + side * 520, tx, prog(lt, 37 + k * 0.45, 39 + k * 0.45))
      local y = 880 + (k * 53) % 70
      person(x, y, 1.15 + (y - 880) / 300, k, S.t, lt > 39 + k * 0.45)
    end
  end
  -- the van
  local vx, vy, vs, rolling = austin_van(lt)
  if lt > 52 or lt < 33 then van(vx, vy, vs, 1, rolling, (lt < 9 or lt > 53) and ALL or nil) end
  -- the cast: the taco line, the tacos, then dancing in front of the band
  if lt > 8.5 and lt < 54 then
    for i, who in ipairs({0, 1, 2, 3, 4}) do
      local qx = 430 + (i - 1) * 46
      local x = lerp(vx, qx, prog(lt, 8.5 + i * 0.4, 10 + i * 0.4))
      local t0 = 12 + (i - 1) * 3
      if lt > t0 + 1.6 then x = lerp(qx, 250 + i * 70, prog(lt, t0 + 1.6, t0 + 3.4)) end
      local y = 940
      if lt > 37 then y = 1000 x = lerp(250 + i * 70, 180 + i * 100, prog(lt, 37, 39)) end
      local dance = (lt > 38) and L.hop(S.t + i * 0.2, 0.46, 22) or 0
      local hot = who == 4 and lt > 27 and lt < 31
      local cover = lt > 27 and lt < 37 and who ~= 4         -- (the grackles: hands over ears, wide-eyed)
      guest(who, x, y - 38 - dance, 38, (lt > t0 + 1.6) and -1 or 1, cover and -1 or 0,
            hot and "wide" or (cover and "wide" or (lt > 38 and "happy" or nil)), false,
            who == 0 and (lt > t0 + 1.6 and lt < t0 + 4 and 0.9 or nil) or nil)
      if lt > t0 and lt < t0 + 1.6 then
        local f = (lt - t0) / 1.6
        lg.setColor(0.95, 0.8, 0.4, 1)
        lg.arc("fill", "pie", lerp(TRUCK[1], x, f), lerp(TRUCK[2], 910, f) - sin(f * pi) * 60, 16, 0, pi, 12)
      end
      if hot then
        for k = 1, 3 do G:spark(x + 36, y - 42, 220 + G.R:random() * 100, (G.R:random() - 0.5) * 60, 0.4, {1, 0.4 + G.R:random() * 0.4, 0.1}, 12, 0, true) end
      end
    end
  end
  if lt > 12 and lt < 15 then G:say("ONE TACO, PLEASE!", 430, 860, 22, 1) end
  if lt > 27 and lt < 30.5 then G:say("HOT HOT HOT!", 250 + 5 * 70, 840, 24, 1) end
  if lt > 31 and lt < 35 then G:say("WHAT? I CAN'T HEAR YOU!", 330, 840, 20, 1) end
  G:plate("LIVE MUSIC CAPITAL OF THE WORLD", 200, 30, 0xffd23f, L.window(lt, 40, 52, 1))
end
CAM.austin = function(lt)
  return L.shot(lt, {{0, 384, 512, 1}, {2, 330, 860, 1.3}, {8, 380, 860, 1.35}, {12, 560, 860, 1.5}, {24, 460, 860, 1.4},
                     {27, 384, 480, 1.25}, {31, 320, 820, 1.4}, {35, 384, 600, 1.05}, {38, 384, 640, 1.05}, {44, 300, 880, 1.35},
                     {50, 384, 800, 1.15}, {54, 384, 820, 1.2}, {60, 384, 640, 1.15}, {65, 384, 512, 1}}, W, H)
end
CUES.austin = {{1, "jet", 0.3}, {8, "honk", 0.6}, {8.6, "clunk"}, {27, "boom", 0.3}, {33, "honk"}, {37, "whoosh"}, {37.2, "boom", 0.4},
               {40, "cheer"}, {54, "honk", 0.5}}
for i = 1, 5 do CUES.austin[#CUES.austin + 1] = {12 + (i - 1) * 3, "pop", 0.4} end
for i = 1, GRACKLES, 3 do CUES.austin[#CUES.austin + 1] = {20.5 + (i - 1) * 0.6, "screech", 0.18} end
for k = 0, 4 do CUES.austin[#CUES.austin + 1] = {27.5 + k * 2, "screech", 0.3} end

-- ------------------------------------------------------------------ Fort Worth: hats, the drive, the calf
local COATS = {{{0.5, 0.3, 0.16}, {0.95, 0.92, 0.85}}, {{0.15, 0.12, 0.1}, {0.9, 0.88, 0.82}}, {{0.75, 0.55, 0.32}},
               {{0.88, 0.85, 0.78}, {0.5, 0.3, 0.16}}, {{0.55, 0.22, 0.12}}, {{0.82, 0.7, 0.5}, {0.4, 0.25, 0.14}}}
local DRIVE0 = -1000
local function herd_x(lt) return DRIVE0 - 300 + (lt + 8) * 42 end
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
    if lt > t0 and not (who == 0 and lt > 36 and lt < 54) and lt < 59.5 then
      local x = lerp(285, 120 + i * 120, prog(lt, t0, t0 + 1.4))
      local y = 735 - (cheer and L.hop(S.t + i * 0.2, 0.45, 18) or 0)
      if lt > 57 then
        local f = prog(lt, 57 + i * 0.2, 58.8 + i * 0.2)
        x, y = lerp(x, 440 + i * 30, f), lerp(y, 930, f) - sin(f * pi) * 60
      end
      local chase = lt > 39 and lt < 48
      if chase then y = y - L.hop(S.t + i * 0.25, 0.4, 22) end
      local mood = (cheer or chase) and "happy" or ((lt > 38 and lt < 50) and "wide" or nil)
      if lt > 50 and lt < 56 then mood = "happy" y = y - L.hop(S.t + i, 0.4, 10) end
      guest(who, x, y - 30, 30, who == 0 and 1 or (x < 384 and 1 or -1), 0, mood, true)
    end
  end
  -- the drive: steers left to right, filling the street, two drovers; dust
  local x0 = herd_x(lt)
  for i = 1, 13 do
    local x = x0 + i * 104 + (i % 3) * 22
    if x > -170 and x < W + 170 then
      local y = 850 + (i % 3) * 46
      steer(x, y, 1.15 + (i % 3) * 0.14, S.t * 5 + i, COATS[i % #COATS + 1], {0.92, 0.88, 0.75})
      if S.R:random() < 0.06 then G:puff(x - 30, y + 36, {0.75, 0.6, 0.45}, 18, -14, 1.6, 9, 0.35) end
    end
  end
  for i, off in ipairs({-90, 1520}) do
    local x = x0 + off
    if x > -140 and x < W + 140 then rider(x, 820 + i * 60, 1.35, S.t * 5) end
  end
  -- the end: the van pulls up, the cast pile in, the calf trots after it
  if lt > 54 then
    local vx = L.path(lt, {{54, W + 220, 0}, {57, 520, 0}, {61, 520, 0}, {65, -260, 0}})
    van(vx, 990, 1, -1, lt < 57 or lt > 61, lt > 59.5 and ALL or nil)
    if lt > 60.5 then
      lg.push()
      lg.translate(vx + 200 + sin(S.t * 8) * 6, 960)
      lg.scale(-1, 1)
      steer(0, 0, 0.55, S.t * 10, COATS[3], {0.95, 0.9, 0.8})
      lg.pop()
    end
  end
  -- the calf: out of the herd, nose to nose with Pac-Man, then away with him on the rope
  if lt > CALF[1] and lt < CALF[2] then
    local cx, cy = calf_pos(lt)
    lg.push()
    lg.translate(cx, cy)
    if lt > 39 then lg.scale(-1, 1) end
    steer(0, 0, 0.8, S.t * (lt > 39 and 10 or 4), COATS[3], {0.95, 0.9, 0.8})
    lg.pop()
    -- Pac-Man: off the boardwalk with a lasso, then skiing along behind on the end of it
    local px, py
    if lt < 39 then px, py = lerp(600, 560, prog(lt, 36, 38)), lerp(705, 780, prog(lt, 36, 38))
    else px, py = cx + 120 - min(1, (lt - 39) / 1) * 20, cy - 10 end
    if lt > 36 then
      L.pac(px, py, 38, pi, S.t, lt > 39 and 0.8 or nil)
      hat(px - 2, py - 32, 26, lt > 39 and 0.5 or 0.1)
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
  if lt > 44 and lt < 47.5 then G:say("GO, PAC-MAN, GO!", 300, 640, 22, 1) end
  if lt > 49 and lt < 53 then G:say("...I MEANT TO DO THAT.", 160, 820, 20, 1) end
  if lt > 61 and lt < 64 then G:say("MOO!", 720, 880, 26, 1) end
end
CAM.stockyards = function(lt)
  if lt > 39 and lt < 47 then
    local cx = calf_pos(lt)
    return L.shot(0, {{0, cx + 60, 840, 1.45}}, W, H)
  end
  return L.shot(lt, {{0, 384, 512, 1}, {2, 300, 680, 1.45}, {9, 400, 680, 1.35}, {14, 384, 700, 1.1}, {20, 384, 760, 1.2},
                     {30, 384, 760, 1.2}, {34, 440, 760, 1.4}, {38, 520, 760, 1.5}, {39, 460, 840, 1.45}, {47, 200, 840, 1.45},
                     {54, 200, 840, 1.6}, {57, 450, 820, 1.25}, {61, 480, 860, 1.35}, {65, 300, 760, 1.15}}, W, H)
end
CUES.stockyards = {{2.4, "clunk", 0.4}, {3.8, "clunk", 0.4}, {5.2, "clunk", 0.4}, {6.6, "clunk", 0.4}, {8, "clunk", 0.4},
                   {20, "cheer"}, {36.5, "whoosh"}, {38.5, "boing"}, {48, "boing"}, {48.2, "pop"}, {55, "honk"}, {57, "clunk"},
                   {60.6, "moo"}, {61.5, "honk", 0.5}}
for k, t in ipairs({9, 14.5, 19, 24, 28.5, 33, 41}) do CUES.stockyards[#CUES.stockyards + 1] = {t, "moo", 0.45 + (k % 3) * 0.2} end

-- ------------------------------------------------------------------ Dinosaur Valley: the tracks in the Paluxy River
-- The van parks; the cast follow the footprints along the riverbed, each one found as they reach it (Pac-Man fits
-- in one); then long ago: a sauropod walks the far bank (the ground shakes), a big meat-eater follows the trail,
-- sniffs Pac-Man, sneezes, goes; back to today: Pac-Man's own little print beside a giant one, the ghosts leave
-- none; the cast's best roar, and the hills roar back.
local PRINTS = {}
do
  -- the sauropod's (round, in pairs) and the theropod's (three toes, one line) along the bed, left to right
  for i = 0, 6 do
    PRINTS[#PRINTS + 1] = {70 + i * 100, 950 + (i % 2) * 26, "s"}
    PRINTS[#PRINTS + 1] = {110 + i * 100, 882 + (i % 2) * 12, "t"}
  end
  table.sort(PRINTS, function(a, b) return a[1] < b[1] end)
end
local function print_found(lt, p) return lt > 6 and (p[1] < 60 + (lt - 6) * 46 or lt > 44) end
local function dino_print(x, y, kind, a, fresh)
  if kind == "s" then
    lg.setColor(0.45, 0.38, 0.26, 0.85 * a)
    lg.ellipse("fill", x, y, 30, 18, 20)
    lg.setColor(0.3, 0.55, 0.5, 0.6 * a)
    lg.ellipse("fill", x, y + 2, 22, 11, 16)
  else
    lg.setColor(0.45, 0.38, 0.26, 0.85 * a)
    lg.ellipse("fill", x, y, 11, 8, 12)
    for k = -1, 1 do
      lg.push()
      lg.translate(x, y)
      lg.rotate(k * 0.45)
      lg.ellipse("fill", 22, 0, 18, 5, 10)
      lg.pop()
    end
  end
  if fresh then
    lg.setBlendMode("add")
    C.fx.glow(x, y, 40, 26, 1, 0.9, 0.5, 0.6 * fresh)
    lg.setBlendMode("alpha")
  end
end
local DINO = {0.42, 0.52, 0.38}
local DINO_BELLY = {0.66, 0.7, 0.52}
local function sauropod(x, y, s, t)
  lg.push()
  lg.translate(x, y)
  lg.scale(s, s)
  -- the far legs, the tail, the body, the near legs (stepping), the long neck up, the head
  local st = sin(t * 2.2)
  lg.setColor(DINO[1] * 0.8, DINO[2] * 0.8, DINO[3] * 0.8, 1)
  lg.rectangle("fill", -140 - st * 12, -150, 46, 150 - abs(st) * 6, 16, 16, 6)
  lg.rectangle("fill", 90 + st * 12, -150, 46, 150 - abs(st) * 6, 16, 16, 6)
  lg.setColor(DINO[1], DINO[2], DINO[3], 1)
  lg.polygon("fill", -180, -230, -460, -150 + sin(t * 1.3) * 10, -470, -140 + sin(t * 1.3) * 10, -190, -170)
  lg.ellipse("fill", 0, -210, 230, 100, 40)
  lg.setColor(DINO_BELLY[1], DINO_BELLY[2], DINO_BELLY[3], 1)
  lg.ellipse("fill", 10, -160, 170, 40, 30)
  lg.setColor(DINO[1], DINO[2], DINO[3], 1)
  lg.rectangle("fill", -110 + st * 12, -160, 52, 162 - abs(st) * 6, 16, 16, 6)
  lg.rectangle("fill", 120 - st * 12, -160, 52, 162 - abs(st) * 6, 16, 16, 6)
  local nb = sin(t * 0.9) * 10
  lg.polygon("fill", 150, -260, 230, -430, 290, -560 + nb, 330, -556 + nb, 290, -420, 210, -200)
  lg.ellipse("fill", 320, -566 + nb, 46, 22, 20)
  lg.setColor(0.08, 0.08, 0.06, 1)
  lg.circle("fill", 336, -574 + nb, 5, 8)
  lg.pop()
end
local function theropod(x, y, s, t, dir, sniff)
  lg.push()
  lg.translate(x, y)
  lg.scale(s * dir, s)
  local st = sin(t * 3)
  local lean = sniff or 0
  lg.setColor(0.55, 0.38, 0.25, 1)
  -- the legs, stepping
  lg.rectangle("fill", -20 + st * 18, -150, 30, 150, 12, 12, 6)
  lg.setColor(0.5, 0.34, 0.22, 1)
  lg.rectangle("fill", 6 - st * 18, -150, 30, 150, 12, 12, 6)
  lg.setColor(0.55, 0.38, 0.25, 1)
  -- the tail, the body (the spine's ridge: Acrocanthosaurus), the arms
  lg.polygon("fill", -40, -230, -260, -200 + sin(t * 2) * 12, -262, -186 + sin(t * 2) * 12, -30, -170)
  lg.ellipse("fill", 10, -210, 90, 60, 30)
  lg.setColor(0.45, 0.3, 0.2, 1)
  lg.polygon("fill", -60, -250, -20, -290, 40, -280, 70, -250)
  lg.setColor(0.55, 0.38, 0.25, 1)
  lg.rectangle("fill", 60, -200, 30, 10, 4, 4, 4)
  -- the neck and the big head (down to sniff)
  lg.push()
  lg.translate(80, -240)
  lg.rotate(0.15 + lean * 0.7)
  lg.rectangle("fill", 0, -20, 50, 44, 10, 10, 6)
  lg.ellipse("fill", 70, -10, 70, 38, 24)
  lg.setColor(0.98, 0.95, 0.85, 1)
  for k = 0, 5 do lg.polygon("fill", 60 + k * 12, 14, 66 + k * 12, 14, 63 + k * 12, 22) end
  lg.setColor(1, 0.85, 0.2, 1)
  lg.circle("fill", 74, -26, 8, 10)
  lg.setColor(0.08, 0.06, 0.04, 1)
  lg.circle("fill", 76, -26, 4, 8)
  lg.pop()
  lg.pop()
end
local PAST = {21, 44}                                  -- long ago, then today
local function past_k(lt) return prog(lt, PAST[1], PAST[1] + 1.5) * (1 - prog(lt, PAST[2] - 1.5, PAST[2])) end
local function cast_x(lt, i)
  -- along the trail with the finding (6-20), at the far end by 21, back toward the middle after
  local x = lerp(-60 - i * 90, 60 + (lt - 6) * 46 - (i - 1) * 86, prog(lt, 1, 6))
  if lt > 6 then x = 60 + min(lt - 6, 14) * 46 - (i - 1) * 86 end
  if lt > 44 then x = lerp(60 + 14 * 46 - (i - 1) * 86, 120 + (i - 1) * 120, prog(lt, 44, 47)) end
  -- (the hills roar back: run!)
  if lt > 61 then x = x + (lt - 61) * (420 + i * 30) end
  return x
end
function D.dinovalley(lt, len)
  if not art("dinovalley") then G:gradient(0, 0, W, H, {0.3, 0.5, 0.85}, {0.8, 0.75, 0.6}) end
  -- the water's shimmer in the channel
  lg.setColor(0.8, 1, 0.95, 0.4)
  lg.setLineWidth(2)
  for i = 0, 14 do
    local x = ((i * 131 + S.t * (10 + i % 4 * 5)) % (W + 80)) - 40
    lg.line(x, 712 + (i * 29) % 70, x + 24, 712 + (i * 29) % 70)
  end
  local pk = past_k(lt)
  -- the sauropod along the far bank, long ago
  if lt > PAST[1] and lt < 38 then
    local sx = lerp(-520, W + 520, lin(lt, 22, 37.5))
    sauropod(sx, 712, 0.95, S.t)
  end
  -- the prints: found one by one; glowing as they're found
  for _, p in ipairs(PRINTS) do
    local found = print_found(lt, p)
    local t0 = 6 + (p[1] - 60) / 46
    local fresh = (lt > t0 and lt < t0 + 1.2) and (1 - (lt - t0) / 1.2) or nil
    dino_print(p[1], p[2], p[3], found and 1 or 0.25, fresh)
  end
  -- Pac-Man's own print, today (48): a little circle beside a big one
  if lt > 48 then
    lg.setColor(0.45, 0.38, 0.26, 0.85)
    lg.circle("fill", 150, 994, 12, 14)
  end
  -- the hills roar back: a head up over the bluff, looking at them, and down again
  if lt > 59.3 and lt < 63 then
    local up = prog(lt, 59.3, 59.8) * (1 - prog(lt, 62.2, 63))
    lg.push()
    lg.translate(560, 560 - up * 110)
    lg.setColor(0.55, 0.38, 0.25, 1)
    lg.rectangle("fill", -30, 0, 60, 120)
    lg.ellipse("fill", 30, -10, 80, 44, 24)
    lg.setColor(1, 0.85, 0.2, 1)
    lg.circle("fill", 40, -28, 10, 12)
    lg.setColor(0.08, 0.06, 0.04, 1)
    lg.circle("fill", 36, -28, 5, 8)
    lg.setColor(0.98, 0.95, 0.85, 1)
    for k = 0, 6 do lg.polygon("fill", 20 + k * 12, 18, 26 + k * 12, 18, 23 + k * 12, 28) end
    lg.pop()
    -- (the bluff's top again, in front of its neck)
    lg.setColor(0.85, 0.78, 0.62, 1)
    lg.rectangle("fill", 470, 562, 190, 30)
  end
  -- the theropod along the trail, long ago: in, a sniff at Pac-Man, a sneeze, away
  if lt > 30 and lt < 45 then
    local tx = L.path(lt, {{30, -320, 0}, {35, 330, 0}, {40.5, 330, 0}, {45, W + 400, 0}})
    local sniff = (lt > 35.5 and lt < 40) and prog(lt, 35.5, 36.5) or 0
    theropod(tx, 990, 1.25, (lt > 35 and lt < 40.5) and 0 or S.t, 1, sniff)
  end
  -- the cast
  for i, who in ipairs({0, 1, 2, 3, 4}) do
    local x = cast_x(lt, i)
    local y = 950
    local hop = (lt > 6 and lt < 21) and L.hop(S.t + i * 0.3, 0.9, 16) or 0
    local scared = lt > 33 and lt < 41
    local shake = (lt > 22 and lt < 37) and L.hop(S.t * 2.2, 0.5, 4) or 0
    local mood = scared and "wide" or ((lt > 44 and lt < 60) and "happy" or ((lt > 22 and lt < 33) and "wide" or nil))
    if who ~= 0 and lt > 49 and lt < 54 then mood = "wide" end
    if lt > 59.5 then mood = "wide" end
    local r = 38
    if who == 0 and lt > 15 and lt < 19 then y = 965 r = 30 end      -- (in a print: it fits)
    local ox = 0
    if who == 0 and lt > 36 and lt < 40.5 then ox = -8 end
    if lt > 61 then hop = L.hop(S.t * 2 + i, 0.3, 14) end
    guest(who, x + ox, y - r - hop - shake, r, 1, (lt > 22 and lt < 37) and -1 or (lt > 49 and lt < 54 and who ~= 0) and 1 or 0, mood, true,
          who == 0 and (scared and 0.05 or nil) or nil)
  end
  -- long ago: the world goes gold-green, a vignette
  if pk > 0 then
    lg.setColor(0.55, 0.7, 0.25, 0.22 * pk)
    lg.rectangle("fill", -50, -50, W + 100, H + 100)
    lg.setColor(0.1, 0.12, 0.05, 0.35 * pk)
    lg.setLineWidth(160)
    lg.rectangle("line", -60, -60, W + 120, H + 120)
  end
  G:plate("113 MILLION YEARS AGO...", 160, 32, 0xd8f080, L.window(lt, 21.5, 28, 1))
  G:plate("...AND TODAY", 160, 32, 0xffffff, L.window(lt, 44.5, 49, 0.8))
  if lt > 9 and lt < 12 then G:say("TRACKS!", cast_x(lt, 1), 860, 24, 1) end
  if lt > 15 and lt < 18.5 then G:say("IT FITS!", cast_x(lt, 1), 870, 24, 1) end
  if lt > 40.5 and lt < 43 then G:say("ACHOO!", 480, 640, 34, 1) end
  if lt > 49 and lt < 52.5 then G:say("WHERE ARE OURS?", cast_x(lt, 3), 870, 22, 1) end
  if lt > 52.5 and lt < 55 then G:say("WE'RE GHOSTS!", cast_x(lt, 4), 870, 22, 1) end
  if lt > 56 and lt < 59 then G:say("RAWR!", cast_x(lt, 3), 860, 30, 1) end
  if lt > 59.5 and lt < 62 then G:say("ROOOAAAR!", 600, 400, 34, 1) end
  if lt > 61.5 and lt < 64.5 then G:say("RUN!", 600, 860, 30, 1) end
end
CAM.dinovalley = function(lt)
  local shake = 0
  if lt > 22 and lt < 37.5 then shake = (floor(lt * 2.2) % 2 == 0 and (lt * 2.2) % 1 < 0.15) and 7 or 0 end
  if lt > 59.5 and lt < 61 then shake = 8 end
  local x, y, z = L.shot(lt, {{0, 384, 512, 1}, {4, 200, 820, 1.4}, {8, 200, 860, 1.5}, {12, 360, 860, 1.5}, {16, 470, 860, 1.6},
                              {19, 560, 860, 1.5}, {21, 384, 600, 1}, {29, 384, 560, 1}, {32, 384, 760, 1.2}, {36, 450, 800, 1.45},
                              {41, 480, 760, 1.35}, {44, 384, 640, 1.05}, {47, 200, 880, 1.6}, {52, 330, 860, 1.4},
                              {58, 384, 700, 1.1}, {59.3, 520, 560, 1.4}, {61.2, 520, 560, 1.4}, {62, 520, 800, 1.2},
                              {65, 640, 800, 1.2}}, W, H)
  return x, y, z, shake
end
CUES.dinovalley = {{1, "honk", 0.5}, {21.5, "chime"}, {35.4, "roar", 0.6}, {36.5, "whoosh", 0.4}, {40.5, "pop"},
                   {40.6, "boing"}, {44.5, "chime"}, {48, "pop", 0.4}, {56, "boing", 0.5}, {59.5, "roar"}, {61, "whoosh"}}
for k = 0, 13 do CUES.dinovalley[#CUES.dinovalley + 1] = {6 + (PRINTS[k + 1][1] - 60) / 46, "ding", 0.25} end
for k = 0, 6 do CUES.dinovalley[#CUES.dinovalley + 1] = {22.3 + k * 2.2, "boom", 0.35} end
for k = 0, 4 do CUES.dinovalley[#CUES.dinovalley + 1] = {30.5 + k * 1, "boom", 0.25} end
CUES.dinovalley[#CUES.dinovalley + 1] = {40.5, function()
  for i = 1, 24 do G:puff(560 + G.R:random() * 40, 760 + G.R:random() * 30, {1, 1, 1}, 30, 200 + G.R:random() * 120, 1.4, 10, 0.6) end
end}

-- ------------------------------------------------------------------ San Antonio: the Alamo (a quiet moment), then the
-- River Walk at dusk: the barge, the lights coming on over the water, the ducks after Pac-Man's chips, the mariachis,
-- cascarones for the finish
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
    local t0 = 9 + i * 0.3
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
  -- the cast in a row before it, hats off for a moment, then away to the river
  for i, who in ipairs({1, 2, 0, 3, 4}) do
    local x = lerp(-80 - i * 50, 160 + (i - 1) * 112, prog(lt, 1 + i * 0.4, 5.5 + i * 0.4))
    if lt > 20 then x = lerp(160 + (i - 1) * 112, W + 120 + i * 50, prog(lt, 20 + (5 - i) * 0.3, 24 + (5 - i) * 0.3)) end
    local y = 862
    local off = lt > 8 and lt < 18
    guest(who, x, y - 34, 32, lt > 20 and 1 or 0, off and 0 or -0.6, off and "sleep" or nil, not off)
    if off then hat(x + 28, y - 10, 20, 0.6) end
  end
  if lt > 17.5 and lt < 20.5 then G:say("1836.", 160, 820, 24, 1) end
  G:plate("REMEMBER", 220, 44, 0xffffff, L.window(lt, 9.5, 18.5, 1.2))
end
CAM.alamo = function(lt)
  return L.shot(lt, {{0, 384, 512, 1}, {5, 384, 760, 1.3}, {9, 384, 480, 1.15}, {16, 384, 430, 1.3},
                     {19, 300, 820, 1.4}, {25, 520, 700, 1.2}}, W, H)
end
CUES.alamo = {{9.2, "whoosh", 0.5}, {17.5, "chime", 0.5}}

-- the River Walk
local BARGE_Y = 735
local function barge_x(lt)
  return L.path(lt, {{0, -330, 0}, {11, 300, 0, "lin"}, {13, 330, 0}, {24, 330, 0}, {46, 440, 0, "lin"}, {60, W + 340, 0}})
end
-- the duck family crossing in front of the barge (14-24): the barge waits
local function duckling_x(lt, k) return lerp(W + 60 + k * 50, -160 + k * 50, lin(lt, 14 + k * 0.3, 24 + k * 0.3)) end
-- a mariachi in a charro suit and a sombrero: kind 1 trumpet, 2 violin, 3 guitarron; solo: the trumpet up
local function mariachi(x, y, s, kind, t, solo)
  local sway = sin(t * 2.6 * pi / 2) * 3 * s
  lg.push()
  lg.translate(x + sway, y)
  lg.scale(s, s)
  lg.setColor(0, 0, 0, 0.25)
  lg.ellipse("fill", 0, 2, 30, 6, 16)
  -- legs, the jacket, the silver buttons down the trousers
  lg.setColor(0.08, 0.07, 0.1, 1)
  lg.rectangle("fill", -14, -60, 12, 60, 3, 3, 4)
  lg.rectangle("fill", 2, -60, 12, 60, 3, 3, 4)
  lg.setColor(0.85, 0.85, 0.9, 1)
  for k = 0, 4 do lg.circle("fill", -12, -54 + k * 12, 2, 6) lg.circle("fill", 12, -54 + k * 12, 2, 6) end
  lg.setColor(0.08, 0.07, 0.1, 1)
  lg.rectangle("fill", -20, -112, 40, 56, 8, 8, 6)
  lg.setColor(1, 1, 1, 1)
  lg.polygon("fill", -6, -112, 6, -112, 0, -96)
  lg.setColor(0.75, 0.1, 0.12, 1)
  lg.polygon("fill", -10, -104, 10, -104, 0, -96)
  lg.setColor(0.85, 0.75, 0.4, 1)
  lg.rectangle("fill", -20, -76, 40, 4)
  -- the head, the moustache, the sombrero
  lg.setColor(0.78, 0.57, 0.42, 1)
  lg.circle("fill", 0, -126, 14, 16)
  lg.setColor(0.12, 0.08, 0.06, 1)
  lg.ellipse("fill", 0, -119, 9, 3, 10)
  lg.setColor(0.08, 0.07, 0.1, 1)
  lg.ellipse("fill", 0, -138, 46, 9, 24)
  lg.polygon("fill", -16, -138, 16, -138, 10, -166, -10, -166)
  lg.setColor(0.85, 0.75, 0.4, 1)
  lg.setLineWidth(2)
  lg.ellipse("line", 0, -138, 46, 9, 24)
  lg.rectangle("fill", -14, -144, 28, 4)
  if kind == 1 then
    -- the trumpet: up and out at the solo, else held low
    local up = solo and -0.5 or 0.35
    lg.push()
    lg.translate(0, -122)
    lg.rotate(up)
    lg.setColor(1, 0.82, 0.3, 1)
    lg.rectangle("fill", 8, -3, 36, 6)
    lg.polygon("fill", 44, -3, 58, -12, 58, 12, 44, 3)
    lg.pop()
  elseif kind == 2 then
    -- the violin under the chin, the bow going
    lg.setColor(0.6, 0.3, 0.1, 1)
    lg.push()
    lg.translate(16, -112)
    lg.rotate(-0.5)
    lg.ellipse("fill", 0, 0, 16, 9, 14)
    lg.setColor(0.2, 0.1, 0.05, 1)
    lg.rectangle("fill", -36, -2, 24, 4)
    lg.pop()
    local b = sin(t * 2.6 * pi) * 18
    lg.setColor(0.9, 0.85, 0.75, 1)
    lg.setLineWidth(2)
    lg.line(-14 + b, -128, 40 + b, -86)
  else
    -- the guitarron: a big round-backed bass guitar, strummed
    lg.setColor(0.65, 0.35, 0.12, 1)
    lg.ellipse("fill", 4, -84, 30, 28, 20)
    lg.setColor(0.2, 0.1, 0.05, 1)
    lg.circle("fill", 4, -84, 8, 12)
    lg.setColor(0.45, 0.25, 0.1, 1)
    lg.polygon("fill", 20, -100, 26, -96, -14, -150, -20, -146)
    lg.setColor(0.78, 0.57, 0.42, 1)
    lg.circle("fill", 10 + abs(sin(t * 2.6 * pi)) * 6, -82, 5, 8)
  end
  lg.pop()
end
local function duck(x, y, s, dir, t, flying, baby)
  lg.push()
  lg.translate(x, y)
  lg.scale(s * dir, s)
  local bob = flying and 0 or sin(t * 3) * 1.5
  if baby then lg.setColor(1, 0.85, 0.3, 1) else lg.setColor(0.45, 0.33, 0.22, 1) end
  lg.ellipse("fill", 0, bob, 16, 9, 14)
  lg.polygon("fill", -14, bob - 2, -24, bob - 8, -16, bob + 4)
  if baby then lg.setColor(1, 0.9, 0.4, 1) else lg.setColor(0.1, 0.45, 0.25, 1) end
  lg.circle("fill", 12, bob - 10, baby and 8 or 6, 12)
  lg.setColor(1, 1, 1, baby and 0 or 1)
  lg.rectangle("fill", 7, bob - 5, 9, 2)
  lg.setColor(0.95, 0.7, 0.1, 1)
  lg.polygon("fill", 17, bob - 11, 25, bob - 9, 17, bob - 7)
  lg.setColor(0.05, 0.05, 0.05, 1)
  lg.circle("fill", 13, bob - 12, 1.5, 6)
  if flying then
    lg.setColor(0.4, 0.3, 0.2, 1)
    local f = sin(t * 18) * 14
    lg.polygon("fill", -4, -4, 8, -4, 2, -16 - f)
  end
  lg.pop()
end
-- the strings of lights across the river: string k from (0, y) to (W, y - 30), sagging, lit at LIGHTS_ON[k]
-- (drawn all together: the wires, then every glow in one additive pass, then the bulbs; a blend switch per bulb
-- took the cabinet to 41 fps)
local LIGHTS_ON = {24, 26, 28, 30, 32}
local BULB_COL = {{1, 0.85, 0.5}, {1, 0.6, 0.4}, {0.7, 0.9, 1}, {1, 0.9, 0.6}}
local function light_strings(lt)
  local bulbs = {}
  lg.setColor(0.1, 0.08, 0.1, 1)
  lg.setLineWidth(1.5)
  for k = 1, #LIGHTS_ON do
    local y0 = 440 + k * 22
    local on = lt > LIGHTS_ON[k]
    local flick = on and lt < LIGHTS_ON[k] + 0.5 and floor(lt * 20) % 2 == 0
    local pts = {}
    for i = 0, 24 do
      local u = i / 24
      pts[#pts + 1] = u * W
      pts[#pts + 1] = y0 - u * 30 + sin(u * pi) * (40 + k * 6)
    end
    lg.line(pts)
    for i = 1, 23 do bulbs[#bulbs + 1] = {pts[i * 2 + 1], pts[i * 2 + 2] + 6, (on and not flick) and BULB_COL[(i + k) % 4 + 1] or nil} end
  end
  lg.setBlendMode("add")
  for _, b in ipairs(bulbs) do
    if b[3] then C.fx.glow(b[1], b[2], 14, 14, b[3][1], b[3][2], b[3][3], 0.45) end
  end
  lg.setBlendMode("alpha")
  for _, b in ipairs(bulbs) do
    if b[3] then lg.setColor(b[3][1], b[3][2], b[3][3], 1) else lg.setColor(0.35, 0.33, 0.3, 1) end
    lg.circle("fill", b[1], b[2], 3.5, 8)
  end
end
local PICADO = {{1, 0.3, 0.6}, {1, 0.6, 0.1}, {1, 0.9, 0.2}, {0.3, 0.8, 0.3}, {0.2, 0.6, 1}, {0.7, 0.35, 0.9}}
local function picado(y0, sag, t)
  for i = 0, 21 do
    local u, u2 = i / 22, (i + 0.8) / 22
    local x1, x2 = u * W + 4, u2 * W + 4
    local y1, y2 = y0 + sin(u * pi) * sag, y0 + sin(u2 * pi) * sag
    local f = sin(t * 3 + i * 0.9) * 4
    local c = PICADO[i % #PICADO + 1]
    lg.setColor(c[1], c[2], c[3], 0.95)
    lg.polygon("fill", x1, y1, x2, y2, x2 + f, y2 + 30, x1 + f, y1 + 30)
    lg.setColor(1, 1, 1, 0.35)
    lg.rectangle("fill", (x1 + x2) / 2 - 3 + f * 0.5, (y1 + y2) / 2 + 10, 6, 6)
  end
  lg.setColor(0.2, 0.15, 0.15, 1)
  lg.setLineWidth(1.5)
  local pts = {}
  for i = 0, 22 do pts[#pts + 1] = i / 22 * W pts[#pts + 1] = y0 + sin(i / 22 * pi) * sag end
  lg.line(pts)
end
local DUCKS = {{150, 660}, {600, 680}, {680, 650}, {90, 700}}
function D.riverwalk(lt, len)
  if not art("riverwalk") then G:gradient(0, 0, W, H, {0.12, 0.14, 0.32}, {0.15, 0.4, 0.35}) end
  -- the water moving
  lg.setColor(0.6, 0.9, 0.8, 0.25)
  lg.setLineWidth(2)
  for i = 0, 26 do
    local y = 630 + (i * 37) % 210
    local x = ((i * 113 + S.t * (14 + i % 5 * 4)) % (W + 120)) - 60
    lg.line(x, y, x + 30 + (i % 3) * 14, y)
  end
  -- the papel picado, high; the strings of lights coming on, string by string
  picado(150, 30, S.t)
  picado(250, 40, S.t + 2)
  light_strings(lt)
  -- the ducks: paddling about, then at Pac-Man's chips (34), one away with the basket (37)
  local bx = barge_x(lt)
  for i, d in ipairs(DUCKS) do
    local x, y = d[1] + sin(S.t * 0.4 + i) * 30, d[2]
    if lt > 30 and lt < 37 then
      local f = prog(lt, 30 + i * 0.4, 34 + i * 0.4)
      x, y = lerp(x, bx - 60 + i * 34, f), lerp(y, BARGE_Y - 26, f)
    end
    local flying = false
    if i == 1 and lt > 36 then
      -- the thief: up onto the barge, the basket, away
      x, y = L.path(lt, {{36, bx - 26, BARGE_Y - 26}, {36.6, bx - 10, BARGE_Y - 70}, {37.4, bx - 10, BARGE_Y - 70},
                         {41, -80, 360}})
      flying = lt > 37.4
    elseif lt > 37.4 and lt < 45 then
      x = x - (lt - 37.4) * 50
    end
    if y < 900 then
      duck(x, y, 1.6, (lt > 37 or x > bx) and -1 or 1, S.t + i, flying)
      if i == 1 and lt > 37 and lt < 41 then
        lg.setColor(0.8, 0.55, 0.25, 1)
        lg.rectangle("fill", x - 30, y + 6, 26, 16, 4, 4, 4)
      end
    end
  end
  -- the duck family: the mother, four ducklings behind her
  if lt > 13.5 and lt < 25.5 then
    for k = 0, 4 do
      local x = duckling_x(lt, k)
      if x > -60 and x < W + 60 then duck(x, BARGE_Y + 75 + (k % 2) * 4, k == 0 and 2.2 or 1.25, -1, S.t * 1.6 + k, false, k > 0) end
    end
  end
  -- the barge, the cast aboard, the guide at the back
  lg.push()
  lg.translate(bx, BARGE_Y)
  lg.setColor(0, 0, 0, 0.25)
  lg.ellipse("fill", 0, 34, 250, 14, 24)
  lg.setColor(0.12, 0.38, 0.28, 1)
  lg.polygon("fill", -240, -8, 240, -8, 220, 30, -220, 30)
  lg.setColor(0.95, 0.92, 0.85, 1)
  lg.rectangle("fill", -238, -10, 476, 8)
  lg.setColor(0.85, 0.3, 0.2, 1)
  lg.rectangle("fill", -230, 8, 460, 5)
  lg.pop()
  local stand = lt > 50 and lt < 58
  for i, who in ipairs({0, 1, 2, 3, 4}) do
    local x = bx - 170 + (i - 1) * 78
    local y = BARGE_Y - 34 - (stand and L.hop(S.t + i * 0.2, 0.45, 18) or 0)
    local mood = stand and "happy" or ((lt > 24 and lt < 33) and "wide" or ((lt > 15 and lt < 23) and "happy" or nil))
    if who == 0 and lt > 37 and lt < 41 then mood = "wide" end
    local open = who == 0 and (lt > 37 and lt < 41 and 0.9 or (lt > 26 and lt < 36 and nil or 0.25)) or nil
    guest(who, x, y, 32, 0, (lt > 24 and lt < 33) and -1 or ((lt > 14 and lt < 24) and 1 or 0), mood, false, open)
    -- Pac-Man's basket of chips
    if who == 0 and lt > 26 and lt < 37 then
      lg.setColor(0.8, 0.55, 0.25, 1)
      lg.rectangle("fill", x + 18, y - 4, 30, 20, 4, 4, 4)
      lg.setColor(1, 0.85, 0.4, 1)
      for k = 0, 3 do lg.polygon("fill", x + 20 + k * 7, y - 4, x + 26 + k * 7, y - 14, x + 30 + k * 7, y - 4) end
    end
  end
  -- the guide at the back with the pole
  local gx = bx + 215
  lg.setColor(0.2, 0.3, 0.55, 1)
  lg.rectangle("fill", gx - 10, BARGE_Y - 70, 20, 60, 5, 5, 4)
  lg.setColor(0.93, 0.76, 0.62, 1)
  lg.circle("fill", gx, BARGE_Y - 82, 11, 14)
  lg.setColor(1, 1, 1, 1)
  lg.rectangle("fill", gx - 12, BARGE_Y - 96, 24, 7, 3, 3, 4)
  lg.setColor(0.35, 0.25, 0.15, 1)
  lg.setLineWidth(3)
  lg.line(gx + 12, BARGE_Y - 100, gx + 30, BARGE_Y + 20)
  -- the cascarones: eggs cracked on heads, confetti
  -- the mariachis on the near bank
  local solo = lt > 44 and lt < 52
  mariachi(560, 1012, 1.0, 2, S.t, false)
  mariachi(640, 1004, 1.05, 1, S.t + 0.3, solo)
  mariachi(718, 1014, 1.0, 3, S.t + 0.6, false)
  if lt > 1 and lt < 6 then G:say("ALL ABOARD!", 520, 650, 22, 1) end
  if lt > 17 and lt < 20.5 then G:say("AWWW!", bx - 92, BARGE_Y - 80, 26, 1) end
  if lt > 21 and lt < 23.5 then G:say("WAIT FOR IT...", bx + 70, BARGE_Y - 80, 22, 1) end
  if lt > 33.5 and lt < 36 then G:say("UH-OH.", bx - 170, BARGE_Y - 80, 24, 1) end
  if lt > 37 and lt < 40 then G:say("HEY! MY CHIPS!", bx - 170, BARGE_Y - 80, 22, 1) end
  if lt > 52 and lt < 55.5 then G:say("AY-AY-AY!", 640, 830, 30, 1) end
end
CAM.riverwalk = function(lt)
  local bx = barge_x(lt)
  return L.shot(lt, {{0, 384, 512, 1}, {6, 300, 720, 1.4}, {12, 340, 720, 1.4}, {15, 420, 760, 1.35}, {22, 300, 760, 1.35},
                     {24, 384, 470, 1.05}, {33, 384, 540, 1.1}, {35, 260, 700, 1.6}, {41, 240, 640, 1.4}, {44, 640, 900, 1.6},
                     {50, 500, 780, 1.3}, {54, 420, 740, 1.25}, {60, 384, 600, 1.05}}, W, H)
end
CUES.riverwalk = {{1, "splash", 0.3}, {13, "honk", 0.4}, {14.5, "quack"}, {17, "quack", 0.7}, {20, "quack"}, {23.2, "quack", 0.7},
                  {31, "quack", 0.6}, {33.8, "quack"}, {36.6, "boing"}, {37.2, "quack"}, {38, "whoosh", 0.4}, {44, "sting", 0.5},
                  {52, "cheer"}}
for k, t in ipairs(LIGHTS_ON) do CUES.riverwalk[#CUES.riverwalk + 1] = {t, k == #LIGHTS_ON and "chime" or "ding", 0.6} end
for k = 0, 4 do
  CUES.riverwalk[#CUES.riverwalk + 1] = {50.5 + k * 0.7, function()
    -- a cascaron cracked over someone's head: a burst of confetti
    local x = barge_x(50.5 + k * 0.7) - 170 + k * 78
    for i = 1, 30 do
      local c = PICADO[G.R:random(1, #PICADO)]
      G:spark(x + (G.R:random() - 0.5) * 20, BARGE_Y - 80, (G.R:random() - 0.5) * 260, -100 - G.R:random() * 220, 1.6, c, 8, 300, false)
    end
    C.sfx("pop", 0.6)
  end}
end

-- ------------------------------------------------------------------ barbecue
-- The joint from the front: the cast in line at the counter; the pitmaster into the pit room (smoke rolls out the
-- door) and back with the brisket; sliced on the block, slice by slice, steaming; a tray each, slid down the counter;
-- the picnic table, the sauce bottle (it gets Blinky), the food coma.
local BLOCK = {340, 572}
local SLICE_T = 13
local SLICE_DT = 0.9
local LINE_X = {130, 230, 330, 430, 530}            -- the cast at the counter: Pac-Man, Blinky, Pinky, Inky, Clyde
local SEAT_X = {150, 270, 390, 510, 630}
local function pitmaster_x(lt)
  return L.path(lt, {{0, BLOCK[1], 0}, {3.5, BLOCK[1], 0}, {5.5, 620, 0}, {8, 620, 0}, {10, BLOCK[1] + 20, 0}})
end
local function pitmaster(x, t, carrying, cutting)
  local y = 600
  lg.setColor(0.25, 0.3, 0.45, 1)
  lg.rectangle("fill", x - 30, y - 120, 60, 120, 10, 10, 8)
  lg.setColor(0.95, 0.93, 0.88, 1)
  lg.rectangle("fill", x - 22, y - 100, 44, 100, 6, 6, 6)            -- the apron
  lg.setColor(0.6, 0.2, 0.15, 0.5)
  lg.ellipse("fill", x - 6, y - 40, 7, 5, 10)                       -- (a sauce stain)
  lg.setColor(0.85, 0.65, 0.5, 1)
  lg.circle("fill", x, y - 140, 22, 18)
  lg.setColor(0.35, 0.22, 0.12, 1)
  lg.ellipse("fill", x, y - 132, 14, 6, 12)                         -- the beard
  lg.setColor(0.1, 0.08, 0.06, 1)
  lg.circle("fill", x - 7, y - 146, 2.5, 6)
  lg.circle("fill", x + 7, y - 146, 2.5, 6)
  lg.setColor(0.5, 0.35, 0.2, 1)
  lg.ellipse("fill", x, y - 160, 38, 8, 20)
  lg.rectangle("fill", x - 18, y - 182, 36, 24, 6, 6, 4)
  -- arms: out holding the board, or the knife going
  lg.setColor(0.85, 0.65, 0.5, 1)
  if carrying then
    lg.rectangle("fill", x - 44, y - 92, 88, 14, 6, 6, 4)
    lg.setColor(0.7, 0.5, 0.3, 1)
    lg.rectangle("fill", x - 70, y - 104, 140, 12, 3, 3, 4)
    lg.setColor(0.12, 0.06, 0.03, 1)
    lg.rectangle("fill", x - 60, y - 132, 120, 30, 10, 10, 6)
  elseif cutting then
    local c = abs(sin(t * 10)) * 14
    lg.rectangle("fill", x - 70, y - 70 + c, 50, 12, 6, 6, 4)
  end
end
function D.bbq(lt, len)
  if not art("bbq") then G:gradient(0, 0, W, H, {0.32, 0.2, 0.14}, {0.16, 0.1, 0.08}) end
  -- the fire in the pit room
  C.fx.glow(560, 430, 70, 40, 1, 0.5, 0.1, 0.3 + 0.15 * sin(S.t * 7))
  -- the pitmaster
  local px = pitmaster_x(lt)
  local inside = lt > 5.5 and lt < 8
  if not inside then pitmaster(px, S.t, lt > 8 and lt < 11, lt > SLICE_T - 0.5 and lt < SLICE_T + 10 * SLICE_DT) end
  -- the brisket on the block: whole, then sliced from the end, the slices fanned out
  local sliced = floor(clamp((lt - SLICE_T) / SLICE_DT, 0, 10))
  if lt > 11 then
    local whole = 1 - sliced / 10
    if whole > 0 then
      lg.setColor(0.12, 0.06, 0.03, 1)
      lg.rectangle("fill", BLOCK[1] - 110, BLOCK[2] - 34, 220 * whole, 36, 10, 10, 6)
      lg.setColor(0.6, 0.22, 0.16, 1)
      lg.rectangle("fill", BLOCK[1] - 110 + 220 * whole - 6, BLOCK[2] - 30, 6, 28)
    end
    -- (the slices on the block, until the trays take them)
    local left = sliced - floor(clamp((lt - 25) / 1.0, 0, 5)) * 2
    for k = 1, max(0, left) do
      local sx = BLOCK[1] - 90 + k * 20
      lg.setColor(0.12, 0.06, 0.03, 1)
      lg.rectangle("fill", sx - 2, BLOCK[2] - 26, 18, 30, 4, 4, 4)
      lg.setColor(0.68, 0.26, 0.18, 1)
      lg.rectangle("fill", sx + 1, BLOCK[2] - 23, 12, 24, 3, 3, 4)
      lg.setColor(0.78, 0.45, 0.32, 1)
      lg.rectangle("fill", sx + 4, BLOCK[2] - 20, 6, 18, 2, 2, 4)
    end
  end
  -- the trays: red, along the counter to each in turn
  for i = 1, 5 do
    local t0 = 25 + (i - 1) * 1.0
    if lt > t0 and lt < 31 + i * 0.3 then
      local x = lerp(BLOCK[1] - 140, LINE_X[i], prog(lt, t0, t0 + 1.2))
      lg.setColor(0.85, 0.15, 0.12, 1)
      lg.rectangle("fill", x - 44, 590, 88, 14, 4, 4, 4)
      lg.setColor(0.92, 0.85, 0.7, 1)
      lg.rectangle("fill", x - 38, 584, 76, 8)
      lg.setColor(0.68, 0.26, 0.18, 1)
      for k = 0, 2 do lg.rectangle("fill", x - 30 + k * 16, 578, 12, 10, 3, 3, 4) end
      lg.setColor(1, 1, 0.96, 1)
      lg.rectangle("fill", x + 18, 576, 16, 14, 3, 3, 4)
    end
  end
  -- the cast: in line, then to the table with their trays, eating; the sauce; the food coma
  local at_table = lt > 31
  for i, who in ipairs({0, 1, 2, 3, 4}) do
    local x, y
    if not at_table then
      x = lerp(-80 - i * 60, LINE_X[i], prog(lt, 0.5 + i * 0.5, 3.5 + i * 0.5))
      y = 760
    else
      local f = prog(lt, 31 + i * 0.25, 33.5 + i * 0.25)
      x, y = lerp(LINE_X[i], SEAT_X[i], f), lerp(760, 890, f) - sin(f * pi) * 40
    end
    local got = lt > 25 + (i - 1) * 1.0 + 1.2
    local munch = (lt > 34 and lt < 42) or lt > 47.5
    local coma = lt > 42 and lt < 46
    local mood = coma and "sleep" or ((munch or (got and not at_table)) and "happy" or nil)
    if who == 1 and lt > 37.3 and lt < 40 then mood = "wide" end
    if lt > 3 and lt < 11 and not got then mood = (lt > 6 and lt < 9) and "wide" or nil end
    local bob = munch and abs(sin(S.t * 8 + i)) * 5 or 0
    -- (in line: a hop for every slice that falls, and one when their tray comes)
    if lt > SLICE_T and lt < SLICE_T + 10 * SLICE_DT then bob = L.hop((lt - SLICE_T) % SLICE_DT, SLICE_DT, 14) end
    local tt = 25 + (i - 1) * 1.0 + 1.2
    if lt > tt and lt < tt + 0.8 then bob = L.hop(lt - tt, 0.8, 30) end
    if who == 0 and lt > 23.6 and lt < 24.4 then bob = L.hop(lt - 23.6, 0.8, 50) end
    local r = (who == 0 and coma) and 46 or 40
    guest(who, x, y - r - bob, r, 0, (lt < 25) and -1 or 0.2, mood, false,
          who == 0 and (coma and 0.05 or (munch and nil or 0.3)) or nil)
    -- Blinky, sauced
    if who == 1 and lt > 37.3 then
      lg.setColor(0.6, 0.1, 0.06, 1)
      for d = 0, 4 do lg.circle("fill", x - 20 + d * 10, y - r - 6 + (d % 2) * 8, 5, 8) end
    end
  end
  -- the table's top again, in front of them (they sit behind it), their trays on it
  if at_table then
    lg.setColor(0.96, 0.94, 0.9, 1)
    lg.rectangle("fill", 40, 886, 688, 54)
    lg.setColor(0.83, 0.16, 0.14, 1)
    for i = 0, 21 do for j = 0, 1 do if (i + j) % 2 == 0 then lg.rectangle("fill", 40 + i * 31.3, 886 + j * 27, 31.3, 27) end end end
    lg.setColor(0.63, 0.1, 0.08, 1)
    lg.rectangle("fill", 40, 940, 688, 8)
    for i = 1, 5 do
      local f = prog(lt, 31 + i * 0.25, 33.5 + i * 0.25)
      if f > 0.9 then
        local x = SEAT_X[i]
        local eaten = lt > 47.5 and clamp((lt - 47.5) / 3, 0, 1) * 0.67 or clamp((lt - 34) / 8, 0, 1)
        lg.setColor(0.85, 0.15, 0.12, 1)
        lg.rectangle("fill", x - 44, 890, 88, 16, 4, 4, 4)
        lg.setColor(0.68, 0.26, 0.18, 1)
        for k = 0, 2 do if k / 3 >= eaten then lg.rectangle("fill", x - 30 + k * 16, 880, 12, 12, 3, 3, 4) end end
      end
    end
    -- the sauce bottle: Pac-Man squeezes, it gets Blinky
    if lt > 35.5 and lt < 40 then
      local bx0 = SEAT_X[1] + 46
      lg.setColor(0.6, 0.1, 0.06, 1)
      lg.push()
      lg.translate(bx0, 860)
      lg.rotate(lt > 37 and -1.2 or -0.3)
      lg.rectangle("fill", -9, -30, 18, 34, 4, 4, 4)
      lg.setColor(0.9, 0.85, 0.2, 1)
      lg.rectangle("fill", -4, -40, 8, 10)
      lg.pop()
      if lt > 37 and lt < 37.4 then
        lg.setColor(0.6, 0.1, 0.06, 1)
        lg.setLineWidth(6)
        lg.line(bx0 + 30, 830, SEAT_X[2], 840)
      end
    end
  end
  -- a burnt end, tossed to Pac-Man (22.6), caught (23.6)
  if lt > 22.6 and lt < 23.7 then
    local f = (lt - 22.6) / 1.1
    local x, y = lerp(BLOCK[1] - 40, LINE_X[1], f), lerp(BLOCK[2] - 40, 700, f) - sin(f * pi) * 180
    lg.push()
    lg.translate(x, y)
    lg.rotate(f * 9)
    lg.setColor(0.12, 0.06, 0.03, 1)
    lg.rectangle("fill", -12, -12, 24, 24, 5, 5, 4)
    lg.setColor(0.6, 0.22, 0.16, 1)
    lg.rectangle("fill", -6, -6, 12, 12, 3, 3, 4)
    lg.pop()
  end
  -- steam off the slices
  if lt > SLICE_T and lt < 25 then
    for k = 0, 2 do
      local ph = (S.t * 0.6 + k / 3) % 1
      lg.setColor(1, 1, 1, 0.3 * (1 - ph))
      lg.ellipse("fill", BLOCK[1] - 60 + k * 50, BLOCK[2] - 40 - ph * 100, 12 + ph * 10, 20 + ph * 16, 14)
    end
  end
  if lt > 3 and lt < 6 then G:say("ONE POUND OF BRISKET, PLEASE!", LINE_X[1] + 80, 660, 20, 1) end
  if lt > 11.5 and lt < 14 then G:say("SMOKE RING!", BLOCK[1] + 60, 470, 24, 1) end
  if lt > 22.4 and lt < 23.6 then G:say("BURNT END!", BLOCK[1], 430, 22, 1) end
  if lt > 24 and lt < 26.5 then G:say("MMM!", LINE_X[1] + 30, 660, 26, 1) end
  if lt > 37.5 and lt < 40 then G:say("HEY!", SEAT_X[2], 790, 28, 1) end
  if lt > 40 and lt < 42.5 then G:say("BEST. BRISKET. EVER.", SEAT_X[3], 790, 22, 1) end
  if lt > 42.5 and lt < 44.5 then G:say("BURP.", SEAT_X[1], 790, 24, 1) end
  if lt > 44.5 and lt < 47 then G:say("...SECONDS?", SEAT_X[1], 790, 24, 1) end
  -- seconds: one more tray, slid all the way from the counter to the table
  if lt > 46 and lt < 50 then
    local x, y = L.path(lt, {{46, BLOCK[1], 590}, {47.4, SEAT_X[1] + 10, 880}})
    lg.setColor(0.85, 0.15, 0.12, 1)
    lg.rectangle("fill", x - 44, y, 88, 16, 4, 4, 4)
    lg.setColor(0.68, 0.26, 0.18, 1)
    for k = 0, 4 do lg.rectangle("fill", x - 38 + k * 16, y - 10, 12, 12, 3, 3, 4) end
  end
  G:plate("LOCKHART  ·  TAYLOR  ·  LULING", 120, 30, 0xffd23f, L.window(lt, 16, 30, 1))
end
CAM.bbq = function(lt)
  return L.shot(lt, {{0, 384, 512, 1}, {3, 330, 640, 1.3}, {5.5, 560, 420, 1.5}, {9, 520, 470, 1.45}, {11.5, BLOCK[1], 560, 1.8},
                     {21.5, BLOCK[1] - 20, 600, 1.6}, {23, 250, 640, 1.4}, {25.5, 330, 660, 1.3}, {30, 330, 680, 1.25}, {33, 384, 820, 1.35},
                     {36, 250, 840, 1.6}, {40, 330, 830, 1.5}, {45, 300, 760, 1.2}, {50, 384, 700, 1.1}}, W, H)
end
CUES.bbq = {{3.5, "ding", 0.4}, {5.6, "clunk"}, {6, "whoosh"}, {8, "clunk"}, {11, "clunk", 0.6}, {11.2, "sizzle"},
            {22.6, "whoosh", 0.5}, {23.6, "power", 0.5}, {31, "whoosh", 0.4}, {37, "splash", 0.5}, {37.3, "boing"}, {40.5, "cheer", 0.6},
            {42.7, "pop", 0.5}, {46, "whoosh"}, {47.4, "clunk"}, {47.6, "cheer", 0.7}}
for k = 1, 10 do CUES.bbq[#CUES.bbq + 1] = {SLICE_T + k * SLICE_DT, "tick", 0.5} end
for i = 1, 5 do CUES.bbq[#CUES.bbq + 1] = {25 + (i - 1) * 1.0 + 1.2, "pop", 0.5} end
CUES.bbq[#CUES.bbq + 1] = {6, function()
  for i = 1, 26 do G:puff(560 + G.R:random() * 120, 300 + G.R:random() * 120, {0.85, 0.82, 0.8}, 60 + G.R:random() * 40, (G.R:random() - 0.7) * 60, 2.6, 16, 0.45) end
end}

-- ------------------------------------------------------------------ the Panhandle: Cadillac Ranch, a train, the storm
-- Golden hour on the High Plains: the cast spray-paint the half-buried cars (each car its painter's colours, stripe by
-- stripe; Pinky gets Clyde too), up on the van's roof for the freight train (it whistles back), tumbleweeds, the
-- storm's lightning coming closer, then the rainbow as it passes.
local function pan_van(lt)
  if lt < 8 then return lerp(-200, 140, 1 - (1 - lin(lt, 1, 8)) ^ 2), lt > 1 end
  if lt < 73 then return 140, false end
  return lerp(140, W + 220, lin(lt, 73, 80) ^ 1.5), true
end
local CARS = {260, 330, 400, 470, 540}               -- Cadillac Ranch: the fins in a row, nose down
local CAR_Y = 806
local CAR_PAINT = {{1, 0.86, 0.15}, {1, 0.18, 0.2}, {1, 0.55, 0.85}, {0.25, 0.95, 1}, {1, 0.65, 0.2}}   -- (by who: 0..4)
local CAR_WHO = {1, 2, 0, 3, 4}
local STROKE = 2.6
local function painted(lt, i) return floor(clamp((lt - 11 - (i - 1) * 0.5) / STROKE, 0, 5)) end
local function caddy(x, y, s, stripes, col)
  lg.push()
  lg.translate(x, y)
  lg.rotate(-0.95)
  lg.scale(s, s)
  -- the body (rust, then painted in stripes from the ground up), the fins, the tail lights
  lg.setColor(0.5, 0.3, 0.22, 1)
  lg.rectangle("fill", -10, -24, 110, 40, 8, 8, 6)
  for k = 1, stripes do
    local c = k % 2 == 1 and col or {1, 1, 1}
    lg.setColor(c[1], c[2], c[3], 1)
    lg.rectangle("fill", -10 + (k - 1) * 22, -24, 22, 40)
  end
  lg.setColor(0.35, 0.22, 0.16, 1)
  lg.polygon("fill", 96, -24, 112, -40, 112, -24)
  lg.polygon("fill", 96, 16, 112, 32, 112, 16)
  lg.setColor(0.9, 0.15, 0.1, 1)
  lg.rectangle("fill", 104, -22, 6, 10)
  lg.rectangle("fill", 104, 2, 6, 10)
  lg.pop()
  -- the dirt it's buried in
  lg.setColor(0.6, 0.45, 0.25, 1)
  lg.ellipse("fill", x, y + 2, 28 * s, 7 * s, 14)
end
local BOLTS = {50, 53.5, 56, 59.5, 62}
local function windmill_angle(lt) return S.t * 2.2 + 8 * max(0, lt - 48) - 4 * max(0, lt - 64) end
function D.panhandle(lt, len)
  if not art("panhandle") then G:gradient(0, 0, W, 640, {0.35, 0.3, 0.55}, {1, 0.72, 0.35}) end
  -- the light going
  lg.setColor(0.15, 0.05, 0.2, 0.3 * lt / len)
  lg.rectangle("fill", 0, 0, W, H)
  -- the rainbow, as the storm passes
  local rb = prog(lt, 64, 68) * (1 - prog(lt, 76, 80))
  if rb > 0 then
    for k, c in ipairs({{1, 0.2, 0.2}, {1, 0.55, 0.1}, {1, 0.9, 0.2}, {0.3, 0.85, 0.3}, {0.3, 0.5, 1}, {0.55, 0.3, 0.85}}) do
      lg.setColor(c[1], c[2], c[3], 0.45 * rb)
      lg.setLineWidth(9)
      lg.arc("line", "open", 560, 700, 300 - k * 9, pi, 2 * pi, 60)
    end
  end
  -- lightning: the storm getting closer, each strike nearer and brighter
  for k, b in ipairs(BOLTS) do
    -- (a strike flickers: on, off, on again, over 0.7 s)
    local ft = lt - b
    if ft > 0 and ft < 0.7 and not (ft > 0.12 and ft < 0.22) and not (ft > 0.4 and ft < 0.48) then
      local x, y = 660 - k * 70, 460
      local ground = 720 + k * 20
      local pts = {x, y}
      local n = 9
      for i = 1, n do
        x = x + (((b * 7919 + i * 104729) % 1000) / 1000 - 0.5) * 50
        y = y + (ground - 460) / n
        pts[#pts + 1] = x pts[#pts + 1] = y
      end
      lg.setBlendMode("add")
      C.fx.glow(x, ground, 90 + k * 20, 40, 0.8, 0.85, 1, 0.8)
      lg.setBlendMode("alpha")
      lg.setColor(1, 1, 1, 1)
      lg.setLineWidth(3 + k)
      lg.line(pts)
      lg.setColor(1, 1, 1, (0.18 + k * 0.05) * (1 - ft / 0.7))
      lg.rectangle("fill", -50, -50, W + 100, H + 100)
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
  -- Cadillac Ranch
  for i, x in ipairs(CARS) do caddy(x, CAR_Y, 1.15, painted(lt, i), CAR_PAINT[CAR_WHO[i] + 1]) end
  -- the freight train, close behind the van: the engine, its headlight, car after car, its smoke
  if lt > 31 and lt < 47 then
    local tx = lerp(W + 40, -3000, lin(lt, 31, 47))
    local by = 905
    lg.setColor(0.25, 0.22, 0.2, 1)
    lg.rectangle("fill", -50, by + 4, W + 100, 6)
    -- the engine: a long hood, the cab, the stripes
    lg.setColor(0.15, 0.25, 0.45, 1)
    lg.rectangle("fill", tx, by - 80, 190, 74, 8, 8, 6)
    lg.setColor(0.95, 0.8, 0.2, 1)
    lg.rectangle("fill", tx, by - 40, 190, 10)
    lg.setColor(0.15, 0.25, 0.45, 1)
    lg.rectangle("fill", tx + 4, by - 112, 60, 36, 6, 6, 4)
    lg.setColor(0.7, 0.85, 0.95, 1)
    lg.rectangle("fill", tx + 12, by - 104, 44, 18, 3, 3, 4)
    lg.setColor(1, 0.95, 0.6, 1)
    lg.circle("fill", tx + 6, by - 60, 7, 10)
    lg.setBlendMode("add")
    C.fx.glow(tx - 10, by - 60, 70, 34, 1, 0.9, 0.5, 0.7)
    lg.setBlendMode("alpha")
    lg.setColor(0.08, 0.08, 0.1, 1)
    for _, wx in ipairs({30, 60, 130, 160}) do lg.circle("fill", tx + wx, by - 2, 12, 12) end
    for c = 1, 20 do
      local cx = tx + 200 + (c - 1) * 140
      if cx < W + 40 and cx > -160 then
        local col = ({{0.6, 0.25, 0.15}, {0.25, 0.4, 0.5}, {0.65, 0.55, 0.25}, {0.4, 0.45, 0.3}})[c % 4 + 1]
        lg.setColor(col[1], col[2], col[3], 1)
        lg.rectangle("fill", cx, by - 70, 130, 62, 4, 4, 4)
        lg.setColor(0, 0, 0, 0.18)
        for r2 = 0, 5 do lg.rectangle("fill", cx + 8 + r2 * 20, by - 64, 3, 52) end
        lg.setColor(0.08, 0.08, 0.1, 1)
        lg.circle("fill", cx + 20, by - 2, 11, 12)
        lg.circle("fill", cx + 110, by - 2, 11, 12)
      end
    end
    if G.R:random() < 0.4 then G:puff(tx + 40, by - 120, {0.8, 0.78, 0.78}, 40, 60, 1.6, 12, 0.45) end
  end
  -- tumbleweeds
  if lt > 44 and lt < 60 then
    for k = 0, 2 do
      local f = lin(lt, 44 + k * 3.5, 50 + k * 3.5)
      if f > 0 and f < 1 then
        local x = lerp(-60, W + 60, f)
        local y = 960 - abs(sin(f * 12)) * 50
        lg.setColor(0.6, 0.45, 0.28, 1)
        lg.setLineWidth(3)
        for j = 1, 6 do lg.circle("line", x + cos(j + lt * 6) * 14, y + sin(j * 1.3 + lt * 6) * 14, 20, 10) end
      end
    end
  end
  -- the van
  local vx, rolling = pan_van(lt)
  van(vx, 960, 1, 1, rolling, (lt < 8 or lt > 72) and ALL or nil)
  -- the cast: out to the cars with their spray cans (9-28), then up on the van's roof
  if lt > 8.5 and lt < 72.5 then
    for i, who in ipairs({1, 2, 0, 3, 4}) do
      local car = 0
      for k, w in ipairs(CAR_WHO) do if w == who then car = k end end
      local ax, ay = CARS[car] + 34, CAR_Y + 28                        -- by its car
      local rx, ry = vx - 96 + (i - 1) * 48, 864                      -- on the roof
      local x, y = rx, ry
      if lt < 30 then
        x, y = lerp(vx, ax, prog(lt, 8.5 + i * 0.3, 10.5 + i * 0.3)), lerp(960, ay, prog(lt, 8.5 + i * 0.3, 10.5 + i * 0.3))
      else
        local f = prog(lt, 28 + i * 0.3, 31 + i * 0.3)
        x, y = lerp(ax, rx, f), lerp(ay, ry, f) - sin(f * pi) * 40
      end
      local r = (lt < 30) and 26 or 24
      local wave = (lt > 34 and lt < 46) and L.hop(S.t + i * 0.3, 0.6, 10) or 0
      local wow = false
      for _, b in ipairs(BOLTS) do if lt > b and lt < b + 1.4 then wow = true end end
      local splat = who == 4 and lt > 24.5 and lt < 27
      local mood = (wow or splat) and "wide" or (((lt > 34 and lt < 46) or (lt > 66 and lt < 72)) and "happy" or nil)
      guest(who, x, y - r - wave, r, lt < 30 and -1 or 1, (lt > 50 and lt < 66) and -0.6 or 0, mood, true)
      -- Clyde, polka-dotted pink from 24.5 on
      if who == 4 and lt > 24.5 then
        lg.setColor(1, 0.55, 0.85, 1)
        for d = 0, 5 do lg.circle("fill", x - r * 0.6 + (d % 3) * r * 0.55, y - r * 1.2 + floor(d / 3) * r * 0.7 - wave, r * 0.13, 8) end
      end
      -- the spray: a can, a mist in the painter's colour
      if lt > 11 and lt < 28 then
        local c = CAR_PAINT[who + 1]
        lg.setColor(0.8, 0.8, 0.85, 1)
        lg.rectangle("fill", x - r - 8, y - r - 6, 8, 14, 2, 2, 4)
        local tgt = (who == 2 and lt > 23.5 and lt < 25) and 1 or 0
        if floor(S.t * 3 + i) % 2 == 0 and G.R:random() < 0.5 then
          G:puff(x - r - 14 + tgt * 140, y - r - 2, c, 6, tgt == 1 and 140 or -70, 0.8, 7, 0.5)
        end
      end
    end
  end
  -- the rain: a grey sheet sweeping across the plain (52-68), umbrellas up while it passes over the van
  local rx = lerp(W + 60, -700, lin(lt, 52, 68))
  if lt > 52 and lt < 68 then
    lg.setColor(0.35, 0.35, 0.45, 0.28)
    lg.rectangle("fill", rx, 300, 520, H)
    lg.setColor(0.8, 0.85, 0.95, 0.55)
    lg.setLineWidth(1.5)
    for i = 0, 60 do
      local x = rx + (i * 53) % 520
      local y = 300 + ((i * 97 + S.t * 900) % 740)
      lg.line(x, y, x - 6, y + 24)
    end
  end
  if lt > 55 and lt < 66 and lt < 72.5 then
    for i = 0, 4 do
      local x = vx - 96 + i * 48
      local c = CAR_PAINT[({2, 3, 1, 4, 5})[i + 1]]
      local up = prog(lt, 55 + i * 0.15, 55.6 + i * 0.15) * (1 - prog(lt, 65, 65.6))
      if up > 0 then
        lg.setColor(0.2, 0.2, 0.2, 1)
        lg.setLineWidth(2)
        lg.line(x + 10, 864 - 20, x + 10, 864 - 20 - 50 * up)
        lg.setColor(c[1], c[2], c[3], 1)
        lg.arc("fill", "pie", x + 10, 864 - 20 - 50 * up, 30 * up, pi, 2 * pi, 16)
      end
    end
  end
  if lt > 17 and lt < 20.5 then G:say("ART!", CARS[3] + 34, CAR_Y - 60, 26, 1) end
  if lt > 25 and lt < 28 then G:say("HEY!", CARS[5] + 34, CAR_Y - 40, 26, 1) end
  if lt > 33 and lt < 37 then G:say("CHOO CHOO!", vx, 780, 24, 1) end
  if lt > 56 and lt < 59 then G:say("UMBRELLAS!", vx, 760, 22, 1) end
  if lt > 50.3 and lt < 53 then G:say("OOOOOH!", vx, 780, 26, 1) end
  if lt > 67 and lt < 71 then G:say("A RAINBOW!", vx, 780, 24, 1) end
end
CAM.panhandle = function(lt)
  return L.shot(lt, {{0, 384, 512, 1}, {2, 200, 820, 1.3}, {8, 200, 840, 1.35}, {11, 400, 800, 1.7}, {18, 330, 800, 1.8},
                     {23, 470, 800, 1.8}, {27, 400, 800, 1.6}, {31, 260, 820, 1.4}, {34, 300, 840, 1.6}, {44, 330, 840, 1.6},
                     {49, 440, 660, 1.15}, {55, 260, 760, 1.35}, {62, 300, 740, 1.25}, {66, 420, 620, 1.05}, {72, 260, 800, 1.3},
                     {80, 600, 760, 1.2}}, W, H)
end
CUES.panhandle = {{1, "jet", 0.3}, {8.5, "honk", 0.5}, {11, "tape", 0.5}, {17, "ding"}, {24.6, "splash", 0.5}, {25, "boing"},
                  {28, "chime"}, {31.5, "whistle"}, {34, "whistle", 0.7}, {44, "whoosh"}, {48, "whoosh", 0.5}, {55.2, "boing", 0.5},
                  {66, "chime"},
                  {73, "honk", 0.5}}
for _, b in ipairs(BOLTS) do CUES.panhandle[#CUES.panhandle + 1] = {b + 0.2, "thunder", 0.5} end
for i = 1, 5 do
  for k = 1, 5 do
    local t = 11 + (i - 1) * 0.5 + k * STROKE
    CUES.panhandle[#CUES.panhandle + 1] = {t, function()
      -- a stripe sprayed on: a burst of its colour off the car
      local c = CAR_PAINT[CAR_WHO[i] + 1]
      for j = 1, 10 do G:puff(CARS[i] + 10 + G.R:random() * 30, CAR_Y - 20 - G.R:random() * 40, c, 20, (G.R:random() - 0.5) * 60, 1, 9, 0.55) end
      C.sfx("tape", 0.25)
    end}
  end
end

-- ------------------------------------------------------------------ the bats
-- Dusk at the Congress Avenue Bridge: kayaks out on the lake, the crowd on the bridge waiting; the first bats, then
-- the river of them pouring out from under the arches and swaying away east (big ones swooping past close), the
-- phones flashing; a bat on Inky; the moon up, a few bats across it.
local function bat_ribbon(lt)
  local b = S.batb
  b:clear()
  if lt > 6 then
    local n = min(1300, floor((lt - 6) * 55))
    for i = 1, n do
      local age = ((lt - 6) - i / 55)
      local sway = sin(age * 1.1 - S.t * 0.7) * (24 + age * 14)
      local x = 150 + (i % 9) * 11 + age * 46 + sway
      local y = 700 - age * 88 + sin(age * 2 + i) * 7 - (i % 5) * 4
      if y > -20 and x < W + 20 then
        local fl = floor(S.t * 12 + i) % 2 + 1
        local s = 3.4 + (i % 3) * 0.6
        b:add(S.batq[fl], x + sin(i * 1.7) * age * 6, y, 0, s, s, 4, 2)
      end
    end
    -- the big ones, swooping past the camera
    for k = 0, 9 do
      local t0 = 11 + k * 3
      if lt > t0 and lt < t0 + 1.4 then
        local f = (lt - t0) / 1.4
        local x = lerp(k % 2 == 0 and -80 or W + 80, k % 2 == 0 and W + 80 or -80, f)
        local y = 900 - f * 520 + sin(f * pi) * -60 + (k % 3) * 60
        local fl = floor(S.t * 10) % 2 + 1
        b:add(S.batq[fl], x, y, 0, (k % 2 == 0 and 1 or -1) * 11, 11, 4, 2)
      end
    end
  end
  lg.draw(b)
end
-- a kayak on the lake with its paddler
local function kayak(x, y, s, col, t)
  lg.push()
  lg.translate(x, y)
  lg.scale(s, s)
  lg.setColor(0, 0, 0, 0.25)
  lg.ellipse("fill", 0, 6, 70, 6, 16)
  lg.setColor(col[1], col[2], col[3], 1)
  lg.polygon("fill", -70, 0, -40, -8, 40, -8, 70, 0, 40, 6, -40, 6)
  lg.setColor(0.2, 0.25, 0.4, 1)
  lg.rectangle("fill", -8, -30, 16, 24, 4, 4, 4)
  lg.setColor(0.9, 0.72, 0.58, 1)
  lg.circle("fill", 0, -38, 8, 12)
  local a = sin(t * 2.4) * 0.6
  lg.setColor(0.85, 0.85, 0.85, 1)
  lg.setLineWidth(3)
  lg.line(-cos(a) * 34, -18 - sin(a) * 14, cos(a) * 34, -18 + sin(a) * 14)
  lg.setColor(1, 0.85, 0.2, 1)
  lg.ellipse("fill", -cos(a) * 34, -18 - sin(a) * 14, 6, 3, 8)
  lg.ellipse("fill", cos(a) * 34, -18 + sin(a) * 14, 6, 3, 8)
  lg.pop()
end
function D.bats(lt, len)
  if S.art.bats_dusk and S.art.bats_night then
    art("bats_dusk")
    art("bats_night", prog(lt, 18, 44))
  else
    G:gradient(0, 0, W, 600, {0.3, 0.2, 0.45}, {1, 0.55, 0.35})
  end
  -- the moon coming up over downtown
  if lt > 30 then
    local my = lerp(560, 300, prog(lt, 30, 46))
    lg.setBlendMode("add")
    C.fx.glow(620, my, 140, 140, 1, 0.95, 0.8, 0.35)
    lg.setBlendMode("alpha")
    lg.setColor(1, 0.97, 0.88, 1)
    lg.circle("fill", 620, my, 54, 40)
    lg.setColor(0.85, 0.82, 0.75, 0.6)
    lg.circle("fill", 604, my - 12, 10, 12)
    lg.circle("fill", 636, my + 14, 7, 12)
  end
  -- the phones on the bridge, flashing as the bats come out
  if lt > 7 and lt < 34 then
    for i = 0, 40 do
      local ph = (S.t * 1.7 + i * 0.37) % 1
      if ph < 0.08 then
        local x = 12 + (i * 97) % 744
        lg.setBlendMode("add")
        C.fx.glow(x, 624, 14, 14, 1, 1, 1, 0.9)
        lg.setBlendMode("alpha")
      end
    end
  end
  -- the kayaks gliding across the lake
  for k, kc in ipairs({{0.95, 0.35, 0.2}, {0.2, 0.7, 0.4}, {1, 0.8, 0.2}}) do
    local x = ((S.t * (14 + k * 4) + k * 280) % (W + 300)) - 150
    kayak(x, 860 + k * 22, 0.9 + k * 0.1, kc, S.t + k)
  end
  lg.setColor(0.08, 0.06, 0.1, 1)
  bat_ribbon(lt)
  -- the cast on the bank, looking up; a bat on Inky
  for i, who in ipairs({1, 2, 0, 3, 4}) do
    local x = lerp(-80 - i * 40, 150 + (i - 1) * 120, prog(lt, 0.5 + i * 0.3, 4 + i * 0.3))
    local look = lt > 6 and -1 or 0
    local wow = lt > 6 and lt < 12
    local jump = (lt > 6.2 and lt < 8) and L.hop(lt - 6.2, 1.8, 30) or 0
    guest(who, x, 960 - 40 - jump, 40, 0, look, (wow or (who == 3 and lt > 20 and lt < 26)) and "wide" or (lt > 36 and "happy" or nil), true)
    if who == 3 and lt > 19.5 and lt < 27 then
      lg.setColor(0.08, 0.06, 0.1, 1)
      local hy = 960 - 40 - 58
      local flap = sin(S.t * 20) * 8
      lg.ellipse("fill", x, hy, 10, 7, 10)
      lg.polygon("fill", x, hy, x - 28, hy - 8 - flap, x - 14, hy + 5)
      lg.polygon("fill", x, hy, x + 28, hy - 8 - flap, x + 14, hy + 5)
    end
  end
  if lt > 1 and lt < 5 then G:say("ANY MINUTE NOW...", 384, 840, 22, 1) end
  if lt > 6 and lt < 9 then G:say("THERE!", 270, 840, 28, 1) end
  if lt > 21 and lt < 25 then G:say("EEK!", 150 + 3 * 120, 840, 26, 1) end
  if lt > 36 and lt < 42 then G:say("A MILLION AND A HALF!", 384, 840, 22, 1) end
end
CAM.bats = function(lt)
  return L.shot(lt, {{0, 384, 700, 1.2}, {5, 384, 820, 1.35}, {8, 300, 640, 1.25}, {16, 460, 380, 1.3}, {19, 520, 860, 1.5},
                     {26, 520, 860, 1.5}, {30, 420, 420, 1.15}, {38, 520, 420, 1.2}, {42, 384, 760, 1.2}, {50, 384, 512, 1}}, W, H)
end
CUES.bats = {{6, "whoosh"}, {6.2, "cheer", 0.6}, {20, "boing"}, {36, "cheer"}, {32, "chime", 0.5}}
for k = 0, 9 do CUES.bats[#CUES.bats + 1] = {11 + k * 3, "whoosh", 0.35} end

-- ------------------------------------------------------------------ Big Bend: a night at the camp
-- From dusk to deep night (the stars come out as the dusk goes): the tent (it falls on Clyde), the fire, the
-- marshmallows (Pac-Man's catches), Blinky's ghost story and the BOO, the Marfa lights come visiting (Inky
-- chases one round the fire), the telescope (Saturn; a Marfa light looks back), the shooting star, asleep.
local FIRE = {384, 985}                             -- (in front: the cast sit round it, behind)
local CAMP_R = 40                                   -- the cast, big enough to see from the couch
local SEATS = {{150, 930}, {262, 905}, {506, 905}, {618, 930}, [0] = {384, 895}}   -- Blinky, Pinky, Inky, Clyde; Pac-Man
local SCOPE = {52, 880}
local TENT = {655, 860}
local function marfa(lt, i)
  -- on the horizon, blinking; 33-47 they come down to the camp and circle it; light 4 is chased by Inky
  local x = 120 + i * 140 + sin(S.t * 0.2 + i) * 40
  local y = 752
  if lt > 33 and lt < 48 then
    local f = prog(lt, 33, 37) * (1 - prog(lt, 45, 48))
    local a = S.t * 1.3 + i * pi / 2
    local r = 230 + i * 12
    if i == 4 and lt > 38 and lt < 45 then a, r = (lt - 38) * 2.2 + pi, 300 end
    x = lerp(x, FIRE[1] + cos(a) * r, f)
    y = lerp(y, FIRE[2] - 190 + sin(a) * 80, f)
    -- the one Pinky catches in her jar (40-44), then lets go
    if i == 2 and lt > 40.5 and lt < 44.5 then x, y = SEATS[2][1] + 30, SEATS[2][2] - 30 end
  end
  return x, y
end
local function telescope(x, y, s, aim)
  lg.setColor(0.2, 0.2, 0.24, 1)
  lg.setLineWidth(3 * s)
  lg.line(x, y - 40 * s, x - 22 * s, y + 20 * s)
  lg.line(x, y - 40 * s, x + 22 * s, y + 20 * s)
  lg.line(x, y - 40 * s, x, y + 22 * s)
  lg.push()
  lg.translate(x, y - 44 * s)
  lg.rotate(aim)
  lg.setColor(0.85, 0.85, 0.9, 1)
  lg.rectangle("fill", -40 * s, -9 * s, 80 * s, 18 * s, 4 * s, 4 * s, 4)
  lg.setColor(0.25, 0.3, 0.55, 1)
  lg.rectangle("fill", 34 * s, -11 * s, 10 * s, 22 * s, 2 * s, 2 * s, 4)
  lg.pop()
end
-- the eyepiece's view: Saturn, its rings, two moons; a Marfa light drifting through and looking back
local function scope_view(lt)
  local a = prog(lt, 47.3, 48) * (1 - prog(lt, 55.5, 56))
  if a <= 0 then return end
  lg.setColor(0, 0, 0, a)
  lg.rectangle("fill", -50, -50, W + 100, H + 100)
  local cx, cy, r = 384, 500, 300
  lg.setColor(0.02, 0.02, 0.06, a)
  lg.circle("fill", cx, cy, r, 64)
  for i = 1, 40 do
    local s = S.bright[i]
    lg.setColor(1, 1, 1, a * 0.7)
    lg.circle("fill", cx + (s[1] / W - 0.5) * 2 * r * 0.9, cy + (s[2] / 640 - 0.5) * 2 * r * 0.9, 1.2, 6)
  end
  local drift = (lt - 48) * 4
  local px, py = cx - 20 + drift, cy + 10
  -- the rings behind, the planet, the rings in front
  lg.push()
  lg.translate(px, py)
  lg.rotate(-0.35)
  lg.scale(1, 0.28)
  lg.setLineWidth(18)
  lg.setColor(0.8, 0.7, 0.5, a)
  lg.arc("line", "open", 0, 0, 150, pi, 2 * pi, 40)
  lg.pop()
  lg.setColor(0.95, 0.82, 0.55, a)
  lg.circle("fill", px, py, 80, 40)
  lg.setColor(0.85, 0.65, 0.4, a)
  for k = -2, 2 do lg.rectangle("fill", px - 76 + abs(k) * 6, py + k * 24 - 4, 152 - abs(k) * 12, 8) end
  lg.push()
  lg.translate(px, py)
  lg.rotate(-0.35)
  lg.setColor(0.85, 0.75, 0.55, a)
  lg.push()
  lg.scale(1, 0.28)
  lg.setLineWidth(18)
  lg.arc("line", "open", 0, 0, 150, 0, pi, 40)
  lg.setColor(0.7, 0.6, 0.45, a)
  lg.setLineWidth(6)
  lg.arc("line", "open", 0, 0, 125, 0, pi, 40)
  lg.pop()
  lg.pop()
  lg.setColor(0.9, 0.9, 0.95, a)
  lg.circle("fill", px + 210, py - 60, 8, 12)
  lg.circle("fill", px - 230, py + 90, 6, 12)
  -- the Marfa light, peeking in from the edge: it has eyes
  if lt > 51 then
    local mx, my = L.path(lt, {{51, cx + r + 40, cy - 120}, {52.5, cx + 170, cy - 130}, {54, cx + 170, cy - 130}, {55.5, cx + 320, cy - 260}})
    C.fx.glow(mx, my, 70, 70, 1, 0.85, 0.6, 0.8 * a)
    lg.setColor(1, 0.97, 0.85, a)
    lg.circle("fill", mx, my, 18, 16)
    lg.setColor(0.1, 0.08, 0.1, a)
    lg.circle("fill", mx - 6, my - 2, 3, 6)
    lg.circle("fill", mx + 6, my - 2, 3, 6)
  end
  -- the eyepiece's rim
  lg.setColor(0.08, 0.08, 0.1, a)
  lg.setLineWidth(40)
  lg.circle("line", cx, cy, r + 20, 64)
end
function D.bigbend(lt, len)
  if not art("bigbend") then G:gradient(0, 0, W, 760, {0.01, 0.01, 0.05}, {0.06, 0.05, 0.14}) end
  -- dusk going: the last light along the ridge fading, the stars coming out
  local dusk = 1 - prog(lt, 2, 24)
  if dusk > 0 then art("bigbend_dusk", dusk) end
  for i, s in ipairs(S.bright) do
    if lt > 4 + i * 0.4 then
      local tw = 0.6 + 0.4 * sin(S.t * (1 + i % 4) + i)
      lg.setColor(1, 1, 0.95, tw * min(1, (lt - 4 - i * 0.4) / 2))
      lg.circle("fill", s[1], s[2], s[3], 6)
    end
  end
  -- shooting stars: a small one now and then, the big one at 57
  for k, t0 in ipairs({18, 29, 41}) do
    if lt > t0 and lt < t0 + 0.8 then
      local p = (lt - t0) / 0.8
      lg.setColor(1, 1, 1, 1 - p)
      lg.setLineWidth(2)
      lg.line(560 - p * 300 - k * 60, 90 + p * 120 + k * 40, 600 - p * 300 - k * 60, 70 + p * 120 + k * 40)
    end
  end
  if lt > 57 and lt < 60 then
    local p = (lt - 57) / 3
    local x, y = lerp(700, 60, p), lerp(60, 420, p)
    lg.setBlendMode("add")
    C.fx.glow(x, y, 60, 60, 1, 0.9, 0.7, 0.9 * (1 - p))
    lg.setBlendMode("alpha")
    lg.setColor(1, 1, 0.9, 1 - p * 0.6)
    lg.setLineWidth(5)
    lg.line(x, y, x + 160, y - 90)
    lg.setColor(1, 1, 0.9, 0.4 * (1 - p))
    lg.setLineWidth(10)
    lg.line(x + 40, y - 22, x + 220, y - 124)
  end
  -- the Marfa lights
  lg.setBlendMode("add")
  for i = 1, 4 do
    local a = (lt > 32 and lt < 49) and 1 or clamp(sin(S.t * (0.3 + i * 0.07) + i * 2) * 1.6, 0, 1) * clamp((lt - 6) / 4, 0, 1)
    local x, y = marfa(lt, i)
    local near = (lt > 33 and lt < 48) and prog(lt, 33, 37) * (1 - prog(lt, 45, 48)) or 0
    C.fx.glow(x, y, 30 + near * 40, 30 + near * 40, 1, 0.85, 0.6, 0.7 * a)
    lg.setColor(1, 0.95, 0.8, a)
    lg.circle("fill", x, y, 4 + near * 10, 12)
  end
  lg.setBlendMode("alpha")
  -- the coyote on the ridge, howling at the end
  if lt > 58 then
    local howl = (lt > 60.5 and lt < 64) and 1 or 0
    lg.setColor(0.05, 0.04, 0.06, 1)
    lg.ellipse("fill", 236, 556, 22, 9, 12)
    lg.polygon("fill", 252, 552, 262, 534 - howl * 10, 272, 538 - howl * 12, 262, 556)
    lg.polygon("fill", 214, 554, 196, 548, 214, 560)
    for i = 0, 3 do lg.rectangle("fill", 220 + i * 9, 560, 3, 14) end
  end
  -- the tent: Clyde pulls the cord, it pops up, falls on him, pops up again
  local tent = prog(lt, 4, 4.6) * (1 - prog(lt, 6.2, 6.6)) + prog(lt, 8.6, 9.2) * (lt > 8.6 and 1 or 0)
  local tx, ty = TENT[1], TENT[2]
  if tent > 0.01 then
    lg.setColor(0.75, 0.33, 0.05, 1)
    lg.polygon("fill", tx - 100 * tent, ty, tx + 100 * tent, ty, tx, ty - 150 * tent)
    lg.setColor(0.4, 0.15, 0.03, 1)
    lg.polygon("fill", tx - 16, ty, tx + 16, ty, tx, ty - 92 * tent)
  end
  if lt > 6.4 and lt < 8.8 then
    -- fallen: a heap with Clyde's eyes peeking out
    lg.setColor(0.75, 0.33, 0.05, 1)
    lg.ellipse("fill", tx, ty - 15, 100, 26, 20)
    lg.setColor(1, 1, 1, 1)
    lg.circle("fill", tx - 12, ty - 24, 6, 8)
    lg.circle("fill", tx + 12, ty - 24, 6, 8)
    lg.setColor(0.15, 0.25, 0.9, 1)
    lg.circle("fill", tx - 12, ty - 23, 3, 6)
    lg.circle("fill", tx + 12, ty - 23, 3, 6)
  end
  -- the telescope (behind the cast)
  telescope(SCOPE[1], SCOPE[2] + 40, 1.4, lt > 46 and -0.9 or -0.5)
  -- the cast: in with their gear, round the fire
  local scared = lt > 30 and lt < 32.5
  for i, who in ipairs({1, 2, 3, 4, 0}) do
    local sx, sy
    sx, sy = SEATS[who][1], SEATS[who][2]
    local x = lerp(-120 - i * 70, sx, prog(lt, 0.5 + i * 0.5, 4 + i * 0.5))
    local y = sy
    if who == 4 then
      -- Clyde: to the tent first, under it, out, then to his seat
      x = L.path(lt, {{0, -400, 0}, {3.6, TENT[1] - 40, 0}, {9.4, TENT[1] - 40, 0}, {11, sx, 0}})
      if lt < 11 then y = TENT[2] + 20 end
      if lt > 6.4 and lt < 8.8 then x = -999 end
    end
    if who == 3 and lt > 38 and lt < 45.5 then
      -- Inky: after the Marfa light round the fire, and back
      local mx, my = marfa(lt - 0.35, 4)
      x, y = mx + 30, my + 110
    end
    if who == 0 and lt > 46 and lt < 57 then
      -- Pac-Man: to the telescope and back
      x = L.path(lt, {{46, sx, 0}, {47.2, SCOPE[1] + 80, 0}, {56, SCOPE[1] + 80, 0}, {57, sx, 0}})
      if lt > 46.5 and lt < 56.5 then y = SCOPE[2] + 40 end
    end
    local jump = scared and L.hop(lt - 30, 2.5, 70) or 0
    local asleep = lt > 60
    local mood = asleep and "sleep" or (scared and "wide" or ((lt > 33 and lt < 48) and "wide" or ((lt > 57 and lt < 60) and "happy" or nil)))
    local look = (lt > 33 and lt < 48) and -0.6 or ((lt > 57 and lt < 60) and -1 or 0)
    if x > -900 then
      guest(who, x, y - CAMP_R - jump, CAMP_R, x < FIRE[1] and 1 or -1, look, mood, not (who == 0 and lt > 30.2 and lt < 40),
            who == 0 and (asleep and 0.05 or nil) or nil)
    end
    -- Pac-Man's hat, blown off by the BOO, and back on at 40
    if who == 0 and lt > 30.2 and lt < 40 then
      local hx, hy = L.path(lt, {{30.2, x, y - 80}, {31.2, x + 60, y - 260}, {33, x + 140, y - 10}})
      hat(hx, hy, CAMP_R * 0.7, (lt - 30.2) * 3)
    end
    -- the marshmallow sticks
    if lt > 13 and lt < 28 and who ~= 1 then
      local tx2, ty2 = lerp(x, FIRE[1], 0.55), FIRE[2] - 70
      lg.setColor(0.5, 0.35, 0.2, 1)
      lg.setLineWidth(3)
      lg.line(x + (x < FIRE[1] and 26 or -26), y - CAMP_R, tx2, ty2)
      local burnt = who == 0 and lt > 19
      lg.setColor(burnt and 0.15 or 1, burnt and 0.1 or 0.97, burnt and 0.08 or 0.9, 1)
      lg.rectangle("fill", tx2 - 10, ty2 - 8, 20, 16, 5, 5, 4)
      if who == 0 and lt > 19 and lt < 21 then C.fx.glow(tx2, ty2 - 14, 34, 42, 1, 0.6, 0.2, 0.9) end
    end
    -- Blinky's flashlight under his face
    if who == 1 and lt > 22 and lt < 32 then
      C.fx.glow(x, y - CAMP_R - 10, 60, 70, 1, 1, 0.8, 0.55)
    end
  end
  -- the fire: logs, lit at 11 (a spark, then FWOOMP), low at the end
  lg.setColor(0.35, 0.22, 0.12, 1)
  lg.setLineWidth(8)
  lg.line(FIRE[1] - 40, FIRE[2] + 18, FIRE[1] + 40, FIRE[2])
  lg.line(FIRE[1] - 40, FIRE[2], FIRE[1] + 40, FIRE[2] + 18)
  if lt > 11 then
    local f = min(1, (lt - 11) / 0.6) * ((lt > 58) and lerp(1, 0.4, prog(lt, 58, 62)) or 1)
    local roar = (lt > 11 and lt < 12.5) and 1.5 or 1
    C.fx.glow(FIRE[1], FIRE[2] - 30, 230 * f, 170 * f, 1, 0.55, 0.2, 0.5)
    lg.setColor(1, 0.45, 0.08, 0.95)
    lg.polygon("fill", FIRE[1] - 36, FIRE[2], FIRE[1] - 10, FIRE[2] - (70 + sin(S.t * 9) * 14) * f * roar, FIRE[1] + 4,
               FIRE[2] - (90 + sin(S.t * 7) * 16) * f * roar, FIRE[1] + 20, FIRE[2] - (60 + sin(S.t * 11) * 12) * f * roar,
               FIRE[1] + 36, FIRE[2])
    lg.setColor(1, 0.85, 0.3, 0.95)
    lg.polygon("fill", FIRE[1] - 16, FIRE[2], FIRE[1], FIRE[2] - (46 + sin(S.t * 11) * 10) * f * roar, FIRE[1] + 16, FIRE[2])
  end
  -- Pinky's jar: a Marfa light in it, glowing, then let go
  if lt > 39 and lt < 45 then
    local jx, jy = SEATS[2][1] + 30, SEATS[2][2] - 20
    lg.setColor(0.8, 0.9, 1, 0.5)
    lg.rectangle("fill", jx - 16, jy - 24, 32, 40, 6, 6, 4)
    lg.setColor(0.6, 0.6, 0.65, 1)
    lg.rectangle("fill", jx - 17, jy - 30, 34, 8, 2, 2, 4)
    if lt > 40.5 and lt < 44.5 then
      lg.setBlendMode("add")
      C.fx.glow(jx, jy - 4, 70, 70, 1, 0.85, 0.6, 0.9)
      lg.setBlendMode("alpha")
    end
  end
  -- asleep: the Z's
  if lt > 61 then
    for k = 0, 2 do
      local ph = ((S.t * 0.5 + k / 3) % 1)
      G:text("z", FIRE[1] + 40 + ph * 30, FIRE[2] - 20 - ph * 90, 22 + ph * 10, {1, 1, 1}, 1 - ph, "left", 40)
    end
  end
  if lt > 6.4 and lt < 8.6 then G:say("HELP!", TENT[1], TENT[2] - 50, 24, 1) end
  if lt > 41 and lt < 44 then G:say("OOOH...", SEATS[2][1], SEATS[2][2] - 90, 22, 1) end
  if lt > 19 and lt < 22 then G:say("FWOOSH!", FIRE[1] - 70, 820, 26, 1) end
  if lt > 23 and lt < 27 then G:say("ONCE, ON A NIGHT JUST LIKE THIS...", SEATS[1][1] + 60, 830, 20, 1) end
  if lt > 27 and lt < 30 then G:say("...AND THEN...", SEATS[1][1], 830, 22, 1) end
  if lt > 30 and lt < 32.5 then G:say("BOO!", SEATS[1][1], 830, 34, 1) end
  if lt > 34 and lt < 37.5 then G:say("THE MARFA LIGHTS!", FIRE[1], 780, 22, 1) end
  if lt > 38.5 and lt < 41 then G:say("TAG! YOU'RE IT!", SEATS[3][1], 700, 22, 1) end
  if lt > 57.4 and lt < 60 then G:say("MAKE A WISH!", FIRE[1], 800, 24, 1) end
  scope_view(lt)
end
CAM.bigbend = function(lt)
  if lt > 47.3 and lt < 56 then return 384, 512, 1, 0 end            -- (the eyepiece: on the screen itself)
  return L.shot(lt, {{0, 384, 400, 1}, {6, 600, 820, 1.55}, {9, 600, 820, 1.55}, {11.5, 384, 880, 1.6}, {14, 330, 880, 1.5},
                     {19, 384, 900, 1.8}, {22, 230, 880, 1.6}, {29, 200, 870, 1.9}, {32, 384, 860, 1.3}, {35, 384, 800, 1.2},
                     {38.5, 470, 820, 1.35}, {40.5, 300, 860, 1.6}, {44.5, 300, 860, 1.6}, {46.5, 180, 860, 1.6}, {56, 384, 800, 1.2},
                     {57, 384, 520, 1.05}, {60, 384, 860, 1.35}, {65, 384, 760, 1.15}}, W, H)
end
CUES.bigbend = {{4, "boing"}, {6.3, "clunk"}, {8.6, "boing"}, {10.8, "crackle", 0.5}, {11, "boom", 0.4}, {19, "whoosh"},
                {30, "boo"}, {30.2, "boing"}, {33, "chime"}, {38, "whoosh", 0.4}, {44.5, "ding"}, {47.3, "whoosh", 0.4},
                {40.5, "pop"}, {44.5, "chime", 0.6}, {48, "chime", 0.6}, {52.5, "boing", 0.5}, {57, "whoosh"}, {57.4, "chime"}, {60.5, "screech", 0.4}}
CUES.bigbend[#CUES.bigbend + 1] = {11, function()
  for i = 1, 26 do G:spark(FIRE[1] + (G.R:random() - 0.5) * 40, FIRE[2] - 20, (G.R:random() - 0.5) * 220, -150 - G.R:random() * 220, 1, {1, 0.7, 0.3}, 5, 120, true) end
end}

-- ------------------------------------------------------------------ the Lone Star
-- The day's scrapbook first: a polaroid from every stop lands on the pile, one by one; they blow away, and the
-- flag under the stars, the cast with their little flags, fireworks.
local SNAPS = {
  function(x, y, w, h)                                                  -- the sandcastle
    lg.setColor(0.95, 0.85, 0.6, 1) lg.rectangle("fill", x, y + h * 0.6, w, h * 0.4)
    lg.setColor(0.9, 0.76, 0.5, 1)
    for t = 0, 3 do lg.rectangle("fill", x + 30 + t * 34, y + h * 0.6 - (t % 3 == 0 and 34 or 50), 24, t % 3 == 0 and 34 or 50) end
    lg.setColor(0.75, 0.04, 0.19, 1) lg.polygon("fill", x + 98, y + 30, x + 120, y + 38, x + 98, y + 46)
  end,
  function(x, y, w, h)                                                  -- the bluebonnets, the armadillo
    lg.setColor(0.3, 0.55, 0.3, 1) lg.rectangle("fill", x, y + h * 0.55, w, h * 0.45)
    lg.setColor(0.25, 0.35, 0.85, 1)
    for k = 0, 30 do lg.circle("fill", x + (k * 37) % w, y + h * 0.6 + (k * 23) % (h * 0.38), 4, 6) end
    armadillo(x + w * 0.5, y + h * 0.82, 1.3, 0)
  end,
  function(x, y, w, h) donut(x + w / 2, y + h / 2, 0.85, true) end,     -- the donuts
  function(x, y, w, h)                                                  -- the tacos, the music
    lg.setColor(0.95, 0.8, 0.4, 1) lg.arc("fill", "pie", x + w / 2, y + h * 0.7, 52, pi, 2 * pi, 20)
    lg.setColor(0.3, 0.7, 0.3, 1) lg.rectangle("fill", x + w / 2 - 44, y + h * 0.7 - 10, 88, 8)
    note(x + 40, y + 60, 1.3, {0.2, 0.2, 0.3}, 1, true)
  end,
  function(x, y, w, h) steer(x + w / 2 - 10, y + h * 0.75, 0.75, 0, COATS[1], {0.92, 0.88, 0.75}) end,   -- the drive
  function(x, y, w, h)                                                  -- the tracks
    lg.setColor(0.8, 0.75, 0.6, 1) lg.rectangle("fill", x, y + h * 0.5, w, h * 0.5)
    sauropod(x + w * 0.45, y + h * 0.62, 0.13, 0)
    dino_print(x + 50, y + h * 0.82, "t", 1) dino_print(x + 120, y + h * 0.88, "s", 1)
  end,
  function(x, y, w, h)                                                  -- the River Walk: the picado, a duck
    lg.setColor(0.15, 0.42, 0.36, 1) lg.rectangle("fill", x, y + h * 0.55, w, h * 0.45)
    for i = 0, 7 do local c = PICADO[i % #PICADO + 1] lg.setColor(c[1], c[2], c[3], 1) lg.rectangle("fill", x + i * 22, y + 10, 18, 22) end
    duck(x + w / 2, y + h * 0.72, 2.2, 1, 0, false)
  end,
  function(x, y, w, h)                                                  -- the brisket
    lg.setColor(0.85, 0.15, 0.12, 1) lg.rectangle("fill", x + 20, y + h * 0.55, w - 40, 34, 6, 6, 4)
    for k = 0, 3 do
      lg.setColor(0.12, 0.06, 0.03, 1) lg.rectangle("fill", x + 34 + k * 30, y + h * 0.3, 24, 50, 5, 5, 4)
      lg.setColor(0.68, 0.26, 0.18, 1) lg.rectangle("fill", x + 38 + k * 30, y + h * 0.3 + 4, 16, 42, 4, 4, 4)
    end
  end,
  function(x, y, w, h)                                                  -- Cadillac Ranch
    lg.setColor(0.85, 0.65, 0.3, 1) lg.rectangle("fill", x, y + h * 0.65, w, h * 0.35)
    caddy(x + 60, y + h * 0.72, 0.85, 5, CAR_PAINT[3]) caddy(x + 120, y + h * 0.72, 0.85, 5, CAR_PAINT[4])
  end,
  function(x, y, w, h)                                                  -- the bats, the moon
    lg.setColor(0.2, 0.15, 0.35, 1) lg.rectangle("fill", x, y, w, h)
    lg.setColor(1, 0.97, 0.88, 1) lg.circle("fill", x + w * 0.65, y + h * 0.4, 34, 24)
    lg.setColor(0.06, 0.05, 0.08, 1)
    for k = 0, 9 do local bx, by = x + 20 + k * 15, y + h * 0.8 - k * 9 lg.polygon("fill", bx - 7, by - 3, bx, by, bx + 7, by - 3, bx, by + 2) end
  end,
  function(x, y, w, h)                                                  -- Saturn, through the telescope
    lg.setColor(0.02, 0.02, 0.06, 1) lg.rectangle("fill", x, y, w, h)
    lg.setColor(0.95, 0.82, 0.55, 1) lg.circle("fill", x + w / 2, y + h / 2, 30, 24)
    lg.push() lg.translate(x + w / 2, y + h / 2) lg.rotate(-0.35) lg.scale(1, 0.3)
    lg.setColor(0.85, 0.75, 0.55, 1) lg.setLineWidth(10) lg.ellipse("line", 0, 0, 60, 60, 30) lg.pop()
  end,
}
local SNAP_DT, SNAP_T0, SNAP_AWAY = 1.15, 2, 16
local function snap_pose(i)
  -- where each lands on the pile: scattered round the middle, tilted
  local a = i * 2.39996
  return 384 + cos(a) * (60 + (i % 4) * 46), 500 + sin(a) * (80 + (i % 3) * 60), ((i * 0.37) % 0.6) - 0.3
end
function D.finale(lt, len)
  if not art("finale") then G:gradient(0, 0, W, H, {0.01, 0.01, 0.06}, {0.08, 0.06, 0.2}) end
  G:draw_back()
  L.pole(150, 240, 1024)
  S.flag:draw(155, 260, 470, 313, S.t, 0.7 + 0.1 * sin(S.t * 0.4), {0.95, 0.95, 1})
  local a = L.window(lt, SNAP_AWAY + 1, len, 1.5)
  G:caption("TEXAS", 640, 110, 0xffb347, a)
  G:caption("THE LONE STAR STATE", 790, 34, 0xffffff, a)
  -- the cast, hats on, waving little flags
  for i, who in ipairs({1, 2, 0, 3, 4}) do
    local t0 = SNAP_AWAY + 1 + i * 0.5
    if lt > t0 then
      local x = 150 + (i - 1) * 117
      local y = lerp(H + 60, 960, prog(lt, t0, t0 + 0.6)) - L.hop(lt + i * 0.2, 0.5, 16)
      guest(who, x, y, 40, 0, -0.5, "happy", true)
      lg.setColor(0.6, 0.6, 0.6, 1)
      lg.setLineWidth(2)
      lg.line(x + 34, y, x + 38, y - 64)
      lg.setColor(0, 0.16, 0.41, 1)
      lg.rectangle("fill", x + 38, y - 64, 10, 20)
      lg.setColor(0.97, 0.97, 0.95, 1)
      lg.rectangle("fill", x + 48, y - 64 + sin(S.t * 6 + i), 20, 10)
      lg.setColor(0.75, 0.04, 0.19, 1)
      lg.rectangle("fill", x + 48, y - 54 + sin(S.t * 6 + i), 20, 10)
    end
  end
  G:caption("FRIENDSHIP", 850, 26, 0x9fd8ff, L.window(lt, SNAP_AWAY + 4, len, 1.5))
  -- the scrapbook: in one by one, then away on the wind
  for i, f in ipairs(SNAPS) do
    local t0 = SNAP_T0 + (i - 1) * SNAP_DT
    if lt > t0 and lt < SNAP_AWAY + 2.5 then
      local px, py, rot = snap_pose(i)
      local k = prog(lt, t0, t0 + 0.6)
      local x, y = lerp(px - 500, px, k), lerp(py + 700, py, k)
      rot = rot + (1 - k) * 2
      if lt > SNAP_AWAY then
        local g = (lt - SNAP_AWAY - (i % 4) * 0.12)
        if g > 0 then x, y, rot = x + g * g * 500 * (i % 2 == 0 and 1 or -0.6), y - g * g * 900, rot + g * 4 end
      end
      lg.push()
      lg.translate(x, y)
      lg.rotate(rot)
      polaroid(0, 0, 0.82, 1, f)
      lg.pop()
    end
  end
  if lt > SNAP_T0 and lt < SNAP_AWAY then
    G:plate("WHAT A DAY", 120, 40, 0xffd23f, L.window(lt, SNAP_T0 + 0.5, SNAP_AWAY, 0.8))
  end
end
CAM.finale = function(lt) return L.shot(lt, {{0, 384, 512, 1}, {SNAP_AWAY, 384, 512, 1.05}, {24, 384, 600, 1.1}, {35, 384, 512, 1}}, W, H) end
CUES.finale = {{SNAP_AWAY, "whoosh"}, {SNAP_AWAY + 0.4, "whoosh", 0.6}, {SNAP_AWAY + 1, "cheer"}}
for i = 1, #SNAPS do CUES.finale[#CUES.finale + 1] = {SNAP_T0 + (i - 1) * SNAP_DT + 0.55, "tick", 0.8} end
for i = 1, #SNAPS do CUES.finale[#CUES.finale + 1] = {SNAP_T0 + (i - 1) * SNAP_DT + 0.6, "chime", 0.25} end

-- ------------------------------------------------------------------ the pictures, a scene at a time
local ART_OF = {open = {"open"}, coast = {"coast_dawn", "coast_day"}, hills = {"hills"}, roundrock = {"creek", "donuts"},
                austin = {"austin"}, stockyards = {"stockyards"}, dinovalley = {"dinovalley"}, alamo = {"alamo"},
                riverwalk = {"riverwalk"}, bbq = {"bbq"}, panhandle = {"panhandle"}, bats = {"bats_dusk", "bats_night"},
                bigbend = {"bigbend_dusk", "bigbend"}, finale = {"finale"}}
-- keep scene k's pictures (and k + 1's, with_next), let the rest go
art_for = function(k, with_next)
  local want = {}
  for _, n in ipairs(ART_OF[SCENES[k][2]] or {}) do want[n] = true end
  if with_next and SCENES[k + 1] then for _, n in ipairs(ART_OF[SCENES[k + 1][2]] or {}) do want[n] = true end end
  for n, img in pairs(S.art) do
    if not want[n] then
      if img then img:release() end
      S.art[n] = nil
    end
  end
  for n in pairs(want) do
    if S.art[n] == nil then S.art[n] = G:art("texas", n) or false end
  end
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
  -- the painted pictures: only the scene's own (and the next one's, loaded in the fade to black between them);
  -- all nineteen at once came to 7 MB of the cabinet's memory, and with a TV fetch running it ran out
  S.art = {}
  S.has = {}
  for _, n in ipairs({"hills", "bigbend", "finale"}) do S.has[n] = G:has_art("texas", n) end
  S.art_k = select(4, scene_at(S.t))
  art_for(S.art_k, false)
  -- the flowers: bluebonnets (blue, a white tip) and paintbrush (red-orange), farther ones smaller
  local R = G.R
  -- (the made flowers and Milky Way only without the painted scenes)
  S.flowers = G:track(lg.newSpriteBatch(G.dot, 1600, "static"))
  for i = 1, S.has.hills and 0 or 1500 do
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
  S.milky = (S.has.bigbend and S.has.finale) and G.px or G:canvas(384, 380, function(w, h)
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
  S.batb = G:track(lg.newSpriteBatch(S.batimg, 1400, "stream"))
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
  local sc, lt, len, k = scene_at(S.t)
  cues(sc[2], lt, dt)
  -- the pictures: the next scene's loaded in the last moment of the fade to black, the last one's let go
  if k ~= S.art_k then S.art_k = k art_for(k, false) S.art_next = nil end
  if lt > len - 0.3 and not S.art_next then S.art_next = true art_for(k, true) end
  -- the finale's fireworks: Texas red, white and blue
  if sc[2] == "finale" and lt > 18 and lt < 33 then
    S.fw = (S.fw or 0) - dt
    if S.fw <= 0 then
      S.fw = 0.8 + G.R:random() * 0.8
      G:rocket(260 + G.R:random() * 440, 120 + G.R:random() * 200,
               {from = 1024, colours = {{0.75, 0.1, 0.2}, {1, 1, 1}, {0.2, 0.35, 0.9}}})
    end
  end
  -- smoke: the barbecue's stack, the meat steaming; the campfire's sparks
  if sc[2] == "bbq" and lt > 5.5 and lt < 12 and G.R:random() < dt * 6 then
    G:puff(540 + G.R:random() * 160, 260 + G.R:random() * 80, {0.8, 0.78, 0.76}, 50, -10, 2.4, 14, 0.35)
  end
  if sc[2] == "bigbend" and lt > 11 and G.R:random() < dt * 6 then
    G:spark(384 + (G.R:random() - 0.5) * 40, 890, (G.R:random() - 0.5) * 40, -80 - G.R:random() * 80, 1.4, {1, 0.7, 0.3}, 5, -10, true)
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
