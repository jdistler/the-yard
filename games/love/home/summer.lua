-- Summer: a Central Texas summer, eight minutes (June to August in AUTO's rotation). Every scene a story with its
-- own camera (SHOWS_BLUEPRINT.md):
--   0:00  STARLIGHT PRESENTS ... SUMMER                                             (Lake Day)
--   0:08  Lake Travis: the cliff-jumping contest (Pac-Man on his float holding up the scores), Clyde on water skis,
--         then Pac-Man's own cannonball: ten, ten, ten
--   1:30  Barton Springs: 68 degrees (a toe in: frozen), a dive and a belly-flop, a race down the pool, the
--         ducklings through the middle                                              (Springs Bossa)
--   2:40  Snow cones: one at a time down the line as the thermometer climbs, a brain freeze, Pac-Man's rainbow
--         one melting at 104                                                        (Sno-Cone Shuffle)
--   3:40  Tubing the river: in one by one, linking up, a fish jumping, the cooler getting away, the turtle off
--         its log                                                                    (Lazy River)
--   5:00  The summer storm: the picnic, the clouds, the blanket over their heads, puddle jumping, the rainbow
--         (Pac-Man slides down it)                                                  (Thunderstorm)
--   6:00  Fireflies: jars filling, a net that misses, all of them let go at once, a heart of them
--                                                                                   (Firefly Night)
--   7:20  SUMMER IN TEXAS: off the end of the pier, one by one
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
local function prog(lt, a, b) return ease((lt - a) / (b - a)) end
local function lin(lt, a, b) return clamp((lt - a) / (b - a), 0, 1) end
local GH = {{1, 0.18, 0.2}, {1, 0.55, 0.85}, {0.25, 0.95, 1}, {1, 0.65, 0.2}}
local SUN = {1, 0.92, 0.5}
local FLAV = {{1, 0.15, 0.2}, {0.2, 0.4, 1}, {0.3, 0.9, 0.3}, {1, 0.8, 0.1}, {0.8, 0.3, 0.9}}

local function sun(x, y, r)
  C.fx.glow(x, y, r * 3.5, r * 3.5, 1, 0.85, 0.4, 0.5)
  rgba(SUN)
  lg.circle("fill", x, y, r, 40)
end

local function water_lines(y0, y1, t, a)
  lg.setColor(1, 1, 1, a)
  for i = 0, floor((y1 - y0) / 22) do
    local y = y0 + i * 22
    local x = ((i * 113 + t * (20 + i % 4 * 6)) % (W + 120)) - 60
    lg.rectangle("fill", x, y, 40 + (i % 5) * 16, 2)
  end
end

-- one of the cast: 0 Pac-Man, 1-4 the ghosts; shades on in the sun
local function guest(who, x, y, r, lx, ly, mood, shades, open)
  if who == 0 then
    L.pac(x, y, r, (lx or 1) >= 0 and 0 or pi, S.t, open)
    if shades then
      lg.setColor(0.05, 0.05, 0.08, 1)
      lg.rectangle("fill", x - r * 0.1, y - r * 0.62, r * 0.6, r * 0.22, 3, 3, 4)
    end
  else
    L.ghost(x, y, r, GH[who], S.t + who, lx, ly, mood)
    if shades and mood == nil then
      lg.setColor(0.05, 0.05, 0.08, 1)
      lg.rectangle("fill", x - r * 0.7, y - r * 0.35, r * 1.4, r * 0.32, 3, 3, 4)
    end
  end
end

-- someone in an inner tube (a ring, them in the middle)
local function tube(x, y, s, who, mood, spin)
  lg.push()
  lg.translate(x, y)
  lg.rotate(spin or 0)
  lg.setColor(0.15, 0.15, 0.17, 1)
  lg.ellipse("fill", 0, 0, 40 * s, 16 * s, 24)
  lg.setColor(0.25, 0.25, 0.28, 1)
  lg.ellipse("fill", 0, -3 * s, 34 * s, 12 * s, 24)
  lg.pop()
  guest(who, x, y - 24 * s, (who == 0 and 27 or 25) * s, 1, 0, mood, mood == nil)
  lg.setColor(0.15, 0.15, 0.17, 1)
  lg.ellipse("fill", x, y + 4 * s, 40 * s, 10 * s, 24)
end

-- a splash in the water: up, out, and a ring
local function splash(x, y, big)
  local n = big and 80 or 22
  for i = 1, n do
    G:spark(x + (G.R:random() - 0.5) * (big and 80 or 30), y, (G.R:random() - 0.5) * (big and 420 or 200),
            -150 - G.R:random() * (big and 520 or 260), big and 1.6 or 1, {0.88, 0.96, 1}, big and 8 or 6, 520)
  end
  C.sfx("splash", big and 1 or 0.5)
end

-- a scorecard held up (n), at x, y
local function card(x, y, n, a)
  lg.setColor(1, 1, 1, a)
  lg.rectangle("fill", x - 22, y - 30, 44, 36, 4, 4, 4)
  lg.setColor(0.5, 0.4, 0.3, a)
  lg.rectangle("fill", x - 2, y + 6, 4, 26)
  G:text(tostring(n), x - 22, y - 28, 28, {0.85, 0.1, 0.1}, a, "center", 44)
end

local D, CAM, CUES = {}, {}, {}

local function art(name, a)
  local img = S.art[name]
  if not img then return false end
  lg.setColor(1, 1, 1, a or 1)
  lg.draw(img, 0, 0)
  return true
end

function D.open(lt, len)
  if not art("open") then
    G:gradient(0, 0, W, H, {0.2, 0.55, 0.95}, {1, 0.85, 0.55})
    sun(384, 330, 90)
  end
  local a = L.window(lt, 0.4, 4, 0.7)
  G:brand(560, a)
  G:caption("PRESENTS", 632, 26, 0x6ef0c8, a)
  G:caption("SUMMER", 600, 96, 0xffd23f, L.window(lt, 4.2, 8, 0.7))
end

-- ------------------------------------------------------------------ Lake Travis: the cliff-jumping contest
local CLIFF = {640, 410}                    -- the jumping-off place
local JUMPS = {{12, 1, "dive", {7, 8, 7}}, {20, 2, "flop", {2, 1, 3}}, {28, 3, "spin", {9, 8, 9}}, {54, 0, "cannon", {10, 10, 10}}}
local JUDGE = {380, 880}                    -- Pac-Man's float, holding up the cards (the ghosts' turn), then the ghosts'
local function jumper(lt, j)
  local t0, who, kind = j[1], j[2], j[3]
  local climb = who == 0 and 6 or 2
  if lt < t0 - climb or lt > t0 + 2.4 then return nil end
  if lt < t0 then
    local f = prog(lt, t0 - climb, t0)
    return lerp(760, CLIFF[1], f), lerp(560, CLIFF[2], f) - L.hop(lt, 0.4, 6), 0
  end
  local f = lin(lt, t0, t0 + 1.6)
  local x = lerp(CLIFF[1], 520, f)
  local y = CLIFF[2] - sin(f * pi) * 90 + f * f * 300
  local rot = kind == "spin" and f * 6 * pi or (kind == "dive" and lerp(0, 2.2, f) or 0)
  return x, y, rot
end
local function pontoon_x(lt) return lerp(-160, 230, prog(lt, 0, 8)) + sin(S.t * 0.2) * 20 end
local function ski_x(lt) return lerp(-260, W + 260, lin(lt, 32, 46)) end
function D.lake(lt, len)
  local painted = art("lake")
  if not painted then
    G:gradient(0, 0, W, 520, {0.2, 0.5, 0.95}, {0.75, 0.9, 1})
    G:gradient(0, 520, W, H, {0.15, 0.55, 0.6}, {0.05, 0.35, 0.45})
  end
  water_lines(540, 1000, S.t, 0.25)
  -- the sailboat far off
  local sx = ((S.t * 8) % (W + 200)) - 100
  lg.setColor(1, 1, 1, 0.9)
  lg.polygon("fill", sx, 520, sx + 4, 440, sx + 40, 520)
  lg.polygon("fill", sx - 4, 520, sx - 4, 460, sx - 30, 520)
  lg.setColor(0.9, 0.3, 0.2, 1)
  lg.rectangle("fill", sx - 34, 520, 76, 8)
  -- the speedboat towing Clyde on skis; the wipe-out
  if lt > 31 and lt < 47 then
    local bx = ski_x(lt)
    lg.setColor(1, 1, 1, 0.7)
    lg.setLineWidth(3)
    for i = 0, 5 do
      local d = 60 + i * 40
      lg.line(bx - d, 642 - d * 0.12, bx - d - 36, 642 - (d + 36) * 0.12)
      lg.line(bx - d, 652 + d * 0.14, bx - d - 36, 652 + (d + 36) * 0.14)
    end
    lg.setColor(0.95, 0.95, 0.97, 1)
    lg.polygon("fill", bx + 50, 636, bx - 50, 630, bx - 46, 650, bx + 40, 652)
    lg.setColor(0.2, 0.4, 0.8, 1)
    lg.rectangle("fill", bx - 20, 620, 30, 12, 4, 4, 4)
    local kx = bx - 200
    local wob = sin(S.t * 6) * 8
    local wiped = lt > 44
    lg.setColor(0.8, 0.8, 0.8, 1)
    lg.setLineWidth(1.5)
    if not wiped then lg.line(bx - 50, 640, kx + 20, 660) end
    if not wiped then
      guest(4, kx + wob, 642, 34, 1, 0, lt > 42 and "wide" or nil, true)
      lg.setColor(0.9, 0.85, 0.2, 1)
      lg.rectangle("fill", kx - 30, 678, 60, 6, 3, 3, 4)
    end
  end
  if lt > 44 and lt < 50 then
    guest(4, 560 + (lt - 44) * 4, 684 - min(1, (lt - 46) / 2) * 20, 34, 1, 0, "wide", false)
  end
  -- the pontoon with whoever isn't jumping
  local px = pontoon_x(lt)
  lg.setColor(0.6, 0.6, 0.65, 1)
  lg.rectangle("fill", px - 110, 800, 220, 14)
  lg.rectangle("fill", px - 110, 816, 220, 10)
  lg.setColor(0.95, 0.95, 0.95, 1)
  lg.rectangle("fill", px - 100, 740, 200, 8)
  local cheer = false
  for _, j in ipairs(JUMPS) do if lt > j[1] + 1.6 and lt < j[1] + 4 then cheer = true end end
  for i = 1, 3 do
    local busy = false
    for _, j in ipairs(JUMPS) do if j[2] == i and lt > j[1] - 2 and lt < j[1] + 2.4 then busy = true end end
    if not busy then
      local gx, gy = px - 80 + i * 40, 780 + sin(S.t * 2 + i) * 3 - (cheer and L.hop(S.t + i, 0.4, 10) or 0)
      -- off the pontoon onto their own floats round Pac-Man's, at the end
      local t0 = 63 + i * 1.5
      if lt > t0 then
        local f = lin(lt, t0, t0 + 1)
        local ex, ey = JUDGE[1] + (i - 2) * 110 + sin(S.t * 0.3) * 30, JUDGE[2] - 80 + (i % 2) * 40 + sin(S.t * 1.2 + i) * 6
        if f >= 1 then
          rgba(({{1, 0.4, 0.3}, {0.4, 0.8, 1}, {1, 0.85, 0.3}})[i])
          lg.ellipse("fill", ex, ey + 22, 44, 16, 20)
          gx, gy = ex, ey
        else
          gx, gy = lerp(gx, ex, f), lerp(gy, ey, f) - sin(f * pi) * 80
        end
      end
      guest(i, gx, gy, 27, 1, 0, cheer and "happy" or nil, not cheer)
    end
  end
  -- Pac-Man on his donut float, the judge (until his own turn)
  local fx, fy = JUDGE[1] + sin(S.t * 0.3) * 30, JUDGE[2] + sin(S.t * 1.2) * 6
  local big_wave = lt > 55.6 and lt < 60
  if big_wave then fy = fy - sin((lt - 55.6) * 4) * 40 * (1 - (lt - 55.6) / 4.4) end
  lg.setColor(1, 0.5, 0.65, 1)
  lg.ellipse("fill", fx, fy, 70, 26, 24)
  lg.setColor(1, 0.65, 0.78, 1)
  lg.ellipse("fill", fx, fy - 4, 66, 22, 24)
  for i = 0, 7 do
    rgba(({{1, 0.3, 0.3}, {0.3, 0.6, 1}, {1, 0.9, 0.2}})[i % 3 + 1])
    lg.rectangle("fill", fx - 50 + i * 13, fy - 10 + (i % 2) * 6, 6, 3)
  end
  lg.setColor(0.15, 0.4, 0.5, 1)
  lg.ellipse("fill", fx, fy - 2, 24, 8, 16)
  local pac_on = lt < 47 or lt > 62
  if pac_on then guest(0, fx, fy - 30, 30, 1, lt > 72 and lt < 78 and -1 or 0, nil, lt < 75.3, lt > 75.3 and lt < 79 and 0.9 or nil) end
  -- the seagull: down, the sunglasses, away
  if lt > 72 and lt < 80 then
    local gx, gy = L.path(lt, {{72, -60, 260}, {75.3, fx + 10, fy - 70}, {80, W + 80, 160}})
    local flap = sin(S.t * 14) * 10
    lg.setColor(1, 1, 1, 1)
    lg.ellipse("fill", gx, gy, 18, 8, 12)
    lg.polygon("fill", gx - 4, gy, gx - 34, gy - 10 - flap, gx + 4, gy - 4)
    lg.polygon("fill", gx + 4, gy, gx + 34, gy - 10 - flap, gx - 4, gy - 4)
    lg.setColor(1, 0.7, 0.1, 1)
    lg.polygon("fill", gx + 16, gy - 2, gx + 28, gy, gx + 16, gy + 3)
    if lt > 75.3 then
      lg.setColor(0.05, 0.05, 0.08, 1)
      lg.rectangle("fill", gx - 8, gy + 8, 18, 6, 2, 2, 4)
    end
  end
  if lt > 75.5 and lt < 78.5 then G:say("HEY! MY SHADES!", fx, fy - 80, 22, 1) end
  -- the scores: Pac-Man's card for the ghosts' jumps; three ghosts' cards for his
  for _, j in ipairs(JUMPS) do
    if lt > j[1] + 1.8 and lt < j[1] + 5 then
      local a = L.window(lt, j[1] + 1.8, j[1] + 5, 0.2)
      if j[2] == 0 then
        for i = 1, 3 do card(px - 80 + i * 40, 720, j[4][i], a) end
      else
        card(fx + 40, fy - 70, j[4][2], a)
      end
    end
  end
  -- the jumpers, off the cliff
  for _, j in ipairs(JUMPS) do
    local x, y, rot = jumper(lt, j)
    if x then
      lg.push()
      lg.translate(x, y)
      lg.rotate(rot)
      local flop = j[3] == "flop" and lt > j[1]
      if flop then lg.scale(1.3, 0.8) end
      if j[2] == 0 then
        L.pac(0, 0, lt > j[1] and 34 or 26, 0, S.t, lt > j[1] and 0.05 or nil)
        if lt > j[1] then
          lg.setColor(1, 0.86, 0.15, 1)
          lg.circle("fill", 0, 0, 34, 24)
        end
      else
        L.ghost(0, 0, 24, GH[j[2]], S.t, flop and 0 or 1, flop and 1 or 0, flop and "wide" or nil)
      end
      lg.pop()
    end
  end
  if lt > 55.6 and lt < 58 then
    lg.setColor(1, 1, 1, 0.6 * (1 - (lt - 55.6) / 2.4))
    lg.rectangle("fill", 0, 0, W, H)
  end
  if lt > 20.2 and lt < 22.5 then G:say("OUCH!", 520, 640, 26, 1) end
  if lt > 47 and lt < 50 then G:say("MY TURN!", 700, 520, 24, 1) end
  if lt > 52.5 and lt < 54.2 then G:say("CANNONBALL!!!", CLIFF[1], CLIFF[2] - 70, 26, 1) end
  if lt > 44.5 and lt < 47.5 then G:say("BLUB!", 560, 640, 24, 1) end
end
CAM.lake = function(lt)
  local keys = {{0, 384, 600, 1.05}, {7, 300, 720, 1.3}, {9.5, 600, 520, 1.4}}
  for k, j in ipairs(JUMPS) do
    if k <= 3 then
      keys[#keys + 1] = {j[1] - 0.5, 600, 480, 1.5}
      keys[#keys + 1] = {j[1] + 1.4, 540, 620, 1.5}
      keys[#keys + 1] = {j[1] + 2.6, 340, 780, 1.45}
      keys[#keys + 1] = {j[1] + 5, 400, 760, 1.35}
    end
  end
  for _, k in ipairs({{31, 384, 640, 1.1}, {33, 200, 640, 1.4}, {38, 384, 640, 1.4}, {43, 560, 640, 1.4}, {47, 600, 640, 1.3},
                      {50, 680, 480, 1.6}, {53.5, 640, 440, 1.7}, {55.6, 520, 620, 1.3}, {58, 384, 600, 1.05},
                      {62, 330, 760, 1.3}, {69, 380, 780, 1.35}, {72, 384, 700, 1.2}, {75, JUDGE[1], 780, 1.6}, {79, JUDGE[1], 760, 1.4}, {82, 384, 600, 1.05}}) do
    keys[#keys + 1] = k
  end
  local x, y, z = L.shot(lt, keys, W, H)
  return x, y, z, (lt > 55.6 and lt < 56.4) and 8 or 0
end
CUES.lake = {{31, "jet", 0.4}, {50, "boing", 0.5}, {52, "boing", 0.5}, {58, "cheer"}}
for _, j in ipairs(JUMPS) do
  CUES.lake[#CUES.lake + 1] = {j[1], "whoosh", 0.5}
  CUES.lake[#CUES.lake + 1] = {j[1] + 1.6, function() splash(520, 700, j[2] == 0 or j[3] == "flop") end}
  CUES.lake[#CUES.lake + 1] = {j[1] + 1.8, "ding", 0.5}
end
CUES.lake[#CUES.lake + 1] = {44, function() splash(560, 680, false) end}
CUES.lake[#CUES.lake + 1] = {20, "cheer"}

-- ------------------------------------------------------------------ Barton Springs: cold
local BOARD = {700, 588}
function D.springs(lt, len)
  if not art("springs") then
    G:gradient(0, 0, W, 460, {0.25, 0.55, 0.95}, {0.8, 0.92, 1})
    G:gradient(0, 600, W, H, {0.35, 0.75, 0.8}, {0.15, 0.55, 0.65})
  end
  water_lines(610, 1000, S.t, 0.3)
  -- the lanes
  lg.setColor(1, 0.5, 0.2, 0.7)
  for _, y in ipairs({700, 800, 900}) do
    for x = 0, W, 30 do lg.circle("fill", x + 15, y, 5, 8) end
  end
  -- the cast on their towels, Inky's toe, the dives
  for i, who in ipairs({0, 1, 2, 3, 4}) do
    local tx = 60 + (i - 1) * 104
    local x, y = tx + 30, 548
    local mood = nil
    local shades = true
    if who == 3 and lt > 8 and lt < 18 then
      -- the toe in: frozen solid
      x, y = lerp(tx + 30, 240, prog(lt, 8, 10)), lerp(548, 600, prog(lt, 8, 10))
      if lt > 10.5 then mood = "wide" shades = false end
    end
    local dive = (who == 1 and lt > 18 and lt < 26) or (who == 2 and lt > 26 and lt < 34)
    local racing = lt > 34 and lt < 50 and who ~= 0
    local floating = lt > 50
    if not dive and not racing and not floating then
      guest(who, x, y - 38, 36, 1, 0, mood, shades)
      if who == 3 and lt > 10.5 and lt < 18 then
        lg.setColor(0.8, 0.95, 1, 0.55)
        lg.rectangle("fill", x - 34, y - 64, 68, 70, 8, 8, 4)
        local sh = sin(S.t * 40) * 3
        G:text("B R R R", x - 80 + sh, y - 110, 26, {0.85, 0.95, 1}, 1, "center", 160)
      end
    end
    -- off the board: Blinky's dive, Pinky's belly-flop
    if dive then
      local t0 = who == 1 and 18 or 26
      local f = lin(lt, t0 + 2, t0 + 3.4)
      local gx, gy
      if lt < t0 + 2 then gx, gy = lerp(tx + 30, BOARD[1] - 40, prog(lt, t0, t0 + 2)), lerp(548, BOARD[2] - 30, prog(lt, t0, t0 + 2)) - L.hop(lt, 0.4, 8)
      elseif lt < t0 + 3.4 then gx, gy = lerp(BOARD[1] - 60, 470, f), BOARD[2] - 30 - sin(f * pi) * 160 + f * 260
      else gx, gy = 470 + (lt - t0 - 3.4) * 30, 840 - L.hop(lt, 1, 4) end
      lg.push()
      lg.translate(gx, gy)
      if who == 1 and lt > t0 + 2 and lt < t0 + 3.4 then lg.rotate(-f * 2.6) end
      if who == 2 and lt > t0 + 2 and lt < t0 + 3.4 then lg.scale(1.3, 0.75) end
      guest(who, 0, 0, 38, -1, who == 2 and 1 or 0, (who == 2 and lt > t0 + 2) and "wide" or nil, false)
      lg.pop()
    end
    -- the race: three lanes, Clyde ahead at the end
    if racing then
      local lane = ({[1] = 750, [2] = 850, [3] = 650, [4] = 950})[who]
      local speed = ({[1] = 0.9, [2] = 0.85, [3] = 0.92, [4] = 1})[who]
      local f = clamp((lt - 36) / 12 * speed, 0, 1)
      local gx = lerp(40, 720, f)
      if lt < 36 then gx = lerp(x, 40, prog(lt, 34, 36)) end
      local stroke = sin(S.t * 10 + who) * 4
      guest(who, gx, lane - 14 + stroke, 34, 1, 0, (f >= 1 and who == 4) and "happy" or nil, false)
      lg.setColor(0.9, 0.97, 1, 0.8)
      for k = 1, 4 do lg.circle("fill", gx - 40 - k * 14, lane + 8 + sin(S.t * 12 + k) * 4, 5 + k, 8) end
    end
    if floating then
      local a = (i - 1) / 5 * 2 * pi + S.t * 0.15
      local gx, gy = 384 + cos(a) * 180, 830 + sin(a) * 70
      if lt > 58 and lt < 66 then gx = gx + (gx < 384 and -60 or 60) * prog(lt, 58, 60) * (1 - prog(lt, 64, 66)) end
      guest(who, gx, gy, 34, 0, -1, nil, true)
    end
  end
  -- the ducklings, through the middle of the ring
  if lt > 56 and lt < 70 then
    for k = 0, 3 do
      local dx = lerp(-80, W + 80, lin(lt, 56 + k * 0.4, 69 + k * 0.4))
      local s = k == 0 and 1.4 or 0.8
      local dy = 830 + sin(S.t * 2 + k) * 3
      lg.setColor(k == 0 and 0.55 or 1, k == 0 and 0.45 or 0.9, k == 0 and 0.3 or 0.3, 1)
      lg.ellipse("fill", dx - k * 50, dy, 18 * s, 10 * s, 14)
      lg.circle("fill", dx - k * 50 + 14 * s, dy - 10 * s, 8 * s, 12)
      lg.setColor(1, 0.6, 0.1, 1)
      lg.polygon("fill", dx - k * 50 + 20 * s, dy - 11 * s, dx - k * 50 + 30 * s, dy - 9 * s, dx - k * 50 + 20 * s, dy - 7 * s)
    end
  end
  if lt > 10 and lt < 13 then G:say("NOPE!", 240, 470, 26, 1) end
  if lt > 30.2 and lt < 32.5 then G:say("OOF!", 480, 760, 26, 1) end
  if lt > 47.5 and lt < 50.5 then G:say("WINNER!", 720, 880, 24, 1) end
  if lt > 60 and lt < 63.5 then G:say("QUACK!", 384, 760, 24, 1) end
  G:plate("IT'S 68°. IT'S ALWAYS 68°.", 150, 30, 0x9fd8ff, L.window(lt, 12, 26, 1.5))
end
CAM.springs = function(lt)
  return L.shot(lt, {{0, 384, 512, 1}, {4, 300, 560, 1.4}, {9, 240, 560, 1.6}, {15, 240, 560, 1.6}, {18, 400, 620, 1.2},
                     {20, 600, 600, 1.5}, {22.5, 480, 760, 1.35}, {26, 500, 620, 1.2}, {28, 600, 600, 1.5}, {30.5, 480, 760, 1.4},
                     {34, 384, 760, 1.1}, {37, 200, 800, 1.6}, {48, 620, 800, 1.6}, {51, 384, 800, 1.1}, {56, 384, 820, 1.4},
                     {66, 384, 820, 1.25}, {70, 384, 600, 1.05}}, W, H)
end
CUES.springs = {{10.5, "boing"}, {20, "whoosh"}, {21.4, function() splash(470, 820, false) end}, {28, "whoosh"},
                {29.4, function() splash(470, 820, true) end}, {36, "pew", 0.4}, {48, "cheer"}, {60, "boing", 0.4}}

-- ------------------------------------------------------------------ snow cones
local CUST = {1, 2, 3, 4}
local function serve_t(k) return 6 + (k - 1) * 5.5 end
local function temp_at(lt) return floor(96 + clamp(lt / 44, 0, 1) * 8) end
local function cone(x, y, s, flavours, ice, melt)
  lg.setColor(0.95, 0.95, 0.9, 1)
  lg.polygon("fill", x - 30 * s, y, x + 30 * s, y, x + 18 * s, y + 70 * s, x - 18 * s, y + 70 * s)
  if ice <= 0 then return end
  local top = ice * (1 - (melt or 0) * 0.7)
  local n = #flavours
  for i, c in ipairs(flavours) do
    rgba(c)
    lg.arc("fill", "pie", x, y, 44 * s * top, pi + (i - 1) * pi / n, pi + i * pi / n, 8)
  end
  if n == 0 then
    lg.setColor(1, 1, 1, 1)
    lg.arc("fill", "pie", x, y, 44 * s * top, pi, 2 * pi, 16)
  end
  if (melt or 0) > 0.1 then
    for i = 1, min(3, n) do
      rgba(flavours[i])
      lg.ellipse("fill", x - 14 * s + i * 8 * s, y + 70 * s + ((S.t * 30 + i * 20) % 40), 3, 6, 8)
    end
  end
end
function D.snocone(lt, len)
  if not art("snocone") then
    G:gradient(0, 0, W, 640, {0.35, 0.6, 0.98}, {0.95, 0.9, 0.75})
    sun(120, 120, 60)
  end
  -- the heat: wavy air
  lg.setColor(1, 1, 1, 0.04 + 0.04 * lin(lt, 0, 44))
  for i = 0, 8 do lg.rectangle("fill", sin(S.t * 3 + i) * 10, 520 + i * 14, W, 3) end
  -- the thermometer's red going up
  local temp = temp_at(lt)
  lg.setColor(0.9, 0.1, 0.1, 1)
  lg.circle("fill", 685, 660, 16, 16)
  lg.rectangle("fill", 679, 676 - (temp - 60) * 6, 12, (temp - 60) * 6 - 20)
  G:text(temp .. "°", 640, 360, 30, {0.9, 0.1, 0.1}, 1, "center", 90)
  -- Pac-Man behind the counter in his paper hat, shaving ice
  local busy = false
  for k = 1, 4 do if lt > serve_t(k) and lt < serve_t(k) + 4 then busy = true end end
  local px = 384
  local catch = lt > 49.4 and lt < 50.6
  local full = lt > 50.6 and lt < 58
  guest(0, px, 500 + (busy and abs(sin(S.t * 10)) * 5 or 0), full and 52 or 44, 1, catch and -1 or 0, nil, false,
        catch and 1 or (full and 0.05 or (busy and 0.3 or nil)))
  lg.setColor(1, 1, 1, 1)
  lg.polygon("fill", px - 34, 466, px + 34, 466, px + 26, 446, px - 26, 446)
  -- the syrup bottles on the counter
  for i, c in ipairs(FLAV) do
    rgba(c)
    lg.rectangle("fill", 210 + (i - 1) * 66, 540, 30, 40, 4, 4, 4)
    lg.rectangle("fill", 218 + (i - 1) * 66, 526, 14, 16)
  end
  -- the line: each one up to the window, their cone made (ice, then syrup), away to the shade to eat it
  for k, who in ipairs(CUST) do
    local t0 = serve_t(k)
    local qx = 120 + (k - 1) * 90
    local x, y = qx, 790
    if lt > t0 - 1.5 then x = lerp(qx, 330, prog(lt, t0 - 1.5, t0)) end
    if lt > t0 + 4 then x = lerp(330, 120 + (k - 1) * 150, prog(lt, t0 + 4, t0 + 6)) y = lerp(790, 860, prog(lt, t0 + 4, t0 + 6)) end
    if k > 1 and lt < serve_t(k - 1) + 4 then x = qx + 0 end
    local freeze = who == 1 and lt > 22 and lt < 27
    local got = lt > t0 + 3.2 and lt < t0 + 4.2
    guest(who, x, y - 40 - (got and L.hop(lt - t0 - 3.2, 1, 24) or 0), 40, 1, 0, freeze and "wide" or (got and "happy" or nil), not freeze)
    if freeze then
      lg.setColor(0.8, 0.95, 1, 0.6)
      lg.rectangle("fill", x - 20, y - 64, 40, 18, 4, 4, 4)
      G:text("BRAIN FREEZE!", x - 90, y - 110, 22, {0.4, 0.7, 1}, 1, "center", 180)
    end
    if lt > t0 then
      local ice = prog(lt, t0, t0 + 2)
      local fl = lt > t0 + 2.5 and {FLAV[k]} or {}
      local cx, cy = x + 44, y - 40
      local making = lt < t0 + 4
      if making then cx, cy = 384, 430 end
      local eaten = clamp((lt - (t0 + 6)) / 8, 0, 1)
      if eaten < 1 then cone(cx, cy, making and 1.1 or 0.7, fl, ice * (1 - eaten), 0) end
      -- the ice shaved: flakes flying off; the syrup pouring, a thick stream
      if lt > t0 and lt < t0 + 2 and G.R:random() < 0.7 then
        G:spark(cx + (G.R:random() - 0.5) * 30, cy - 50, (G.R:random() - 0.5) * 160, -80 - G.R:random() * 80, 0.6, {1, 1, 1}, 5, 300, false)
      end
      if lt > t0 + 2 and lt < t0 + 3 then
        rgba(FLAV[k])
        lg.setLineWidth(9)
        lg.line(cx + 50, cy - 90, cx + 30, cy - 60, cx + 8, cy - 20)
        lg.ellipse("fill", cx + 54, cy - 96, 14, 9, 10)
      end
    end
  end
  -- Pac-Man's own: a tower of every flavour, scoop on scoop (32-44), the ghosts gathering; the heat: drips, a
  -- wobble, the lean (48), the fall, and he catches the lot in his mouth (50)
  if lt > 31.5 and lt < 51.2 then
    local n = min(#FLAV + 2, floor((lt - 32) / 1.6) + 1)
    local bx, by = 450, 470
    -- (it leans over toward Pac-Man, then goes down into his open mouth, shrinking as it goes)
    local lean = lt > 47 and -min(1.2, (lt - 47) * 0.5) or (lt > 44 and sin(S.t * 6) * 0.06 * (lt - 44) / 3 or 0)
    local fall = lt > 49.4 and prog(lt, 49.4, 50.5) or 0
    lg.push()
    lg.translate(lerp(bx, 384 + 30, fall), lerp(by, 500, fall))
    lg.rotate(lean - fall * 0.4)
    lg.scale(1 - fall * 0.9, 1 - fall * 0.9)
    lg.setColor(0.95, 0.95, 0.9, 1)
    lg.polygon("fill", -34, 0, 34, 0, 20, 80, -20, 80)
    for k = 1, max(0, n) do
      local c = FLAV[(k - 1) % #FLAV + 1]
      local y = -k * 46
      local sq = (k == n and (lt - 32) % 1.6 < 0.25) and 1.25 or 1
      lg.setColor(1, 1, 1, 1)
      lg.ellipse("fill", 0, y + 20, 46 * sq, 30 / sq, 20)
      if lt > 32 + (k - 1) * 1.6 + 0.6 then
        rgba(c)
        lg.ellipse("fill", 0, y + 16, 44 * sq, 26 / sq, 20)
        lg.setColor(1, 1, 1, 0.35)
        lg.ellipse("fill", -14, y + 8, 12, 6, 10)
      end
      -- the drips, in the heat
      if lt > 44 then
        rgba(c)
        lg.ellipse("fill", -30 + (k * 23) % 60, y + 40 + ((S.t * 40 + k * 17) % 50), 4, 8, 8)
      end
    end
    lg.pop()
  end
  -- the ghosts gathered round to watch, a hop at every scoop
  if lt > 32 and lt < 56 then
    for i, who in ipairs({1, 2, 3, 4}) do
      local gx = lerp(120 + (i - 1) * 150, 120 + (i - 1) * 60 + (i > 2 and 420 or 0), prog(lt, 32, 34))
      local hop = (lt < 44 and ((lt - 32) % 1.6) < 0.5) and L.hop((lt - 32) % 1.6, 1, 22) or 0
      local wide = lt > 47 and lt < 51
      guest(who, gx, 790 - 40 - hop, 40, 1, -1, wide and "wide" or ((lt > 50.5) and "happy" or nil), not wide)
    end
  end
  if lt > 43 and lt < 46.5 then G:say("IT'S 104!", 685, 300, 26, 1) end
  if lt > 47.5 and lt < 49.5 then G:say("TIMBERRR!", 300, 300, 26, 1) end
  if lt > 50.4 and lt < 54 then G:say("GULP!", 384, 380, 30, 1) end
  if lt > 54 and lt < 57 then G:say("...BRAIN FREEZE.", 384, 380, 22, 1) end
  if lt > 6 and lt < 9 then G:say("CHERRY, PLEASE!", 330, 720, 22, 1) end
end
CAM.snocone = function(lt)
  local keys = {{0, 384, 512, 1}, {4, 300, 700, 1.25}}
  for k = 1, 4 do
    local t0 = serve_t(k)
    keys[#keys + 1] = {t0 + 0.3, 384, 520, 1.6}
    keys[#keys + 1] = {t0 + 3.6, 384, 520, 1.6}
    keys[#keys + 1] = {t0 + 5.5, 280, 760, 1.35}
  end
  for _, k in ipairs({{24, 140, 760, 1.6}, {29, 140, 760, 1.6}, {32, 420, 520, 1.25}, {38, 430, 470, 1.1}, {44, 440, 440, 1.1},
                      {47, 450, 400, 1.2}, {49.4, 420, 420, 1.3}, {50.6, 384, 480, 1.6}, {56, 384, 520, 1.5}, {60, 384, 512, 1}}) do
    keys[#keys + 1] = k
  end
  return L.shot(lt, keys, W, H)
end
CUES.snocone = {{22, "boing"}, {43, "ding"}, {47.5, "whoosh"}, {50.4, "power"}, {54.2, "boing", 0.5}}
for k = 1, 9 do CUES.snocone[#CUES.snocone + 1] = {32 + (k - 1) * 1.6 + 0.6, "pop", 0.3 + k * 0.03} end
for k = 1, 4 do
  CUES.snocone[#CUES.snocone + 1] = {serve_t(k), "tape", 0.35}
  CUES.snocone[#CUES.snocone + 1] = {serve_t(k) + 2, "splash", 0.25}
  CUES.snocone[#CUES.snocone + 1] = {serve_t(k) + 3.2, "ding", 0.5}
end
for k = 1, 4 do
  CUES.snocone[#CUES.snocone + 1] = {serve_t(k), "tape", 0.5}
  CUES.snocone[#CUES.snocone + 1] = {serve_t(k) + 2.5, "pop", 0.4}
end
for i = 1, 5 do CUES.snocone[#CUES.snocone + 1] = {38 + (i - 1) * 1.2, "ding", 0.4} end

-- ------------------------------------------------------------------ tubing the river
local function tube_pos(lt, i)
  -- in one by one from the left, linking up, round the bend; the cooler away (Inky after it)
  local x0 = lerp(-120, 520, lin(lt, 2, 30)) + max(0, lt - 30) * 6 - max(0, lt - 66) * 30
  local x = x0 - i * 100
  local y = 760 + sin(S.t * 0.8 + i) * 14 + (i % 2) * 60
  if lt < 2 + i * 2 then x = -200 end
  return x, y
end
local RAPIDS = {32, 40}
local SWING0, SWING_DT = 55, 4.4            -- the rope swing at the take-out: the first off at 55, one each 4.4 s
function D.tubing(lt, len)
  if not art("tubing") then
    G:gradient(0, 0, W, 420, {0.3, 0.55, 0.95}, {0.8, 0.9, 1})
    G:gradient(0, 500, W, H, {0.3, 0.6, 0.55}, {0.18, 0.45, 0.42})
  end
  -- the light getting golden at the end
  lg.setColor(1, 0.6, 0.2, 0.25 * lin(lt, 60, 80))
  lg.rectangle("fill", 0, 0, W, H)
  water_lines(520, 1000, S.t * (lt > RAPIDS[1] and lt < RAPIDS[2] and 2 or 0.6), 0.3)
  -- the rapids: white water
  if lt > RAPIDS[1] - 2 and lt < RAPIDS[2] + 2 then
    local a = L.window(lt, RAPIDS[1] - 2, RAPIDS[2] + 2, 1)
    lg.setColor(1, 1, 1, 0.6 * a)
    for i = 0, 20 do
      local x = (i * 61 + S.t * 160) % (W + 60) - 30
      lg.ellipse("fill", x, 700 + (i * 37) % 200, 22, 6, 10)
    end
  end
  -- the log and the turtle (off at 50)
  lg.setColor(0.45, 0.32, 0.2, 1)
  lg.rectangle("fill", 520, 560, 200, 26, 12, 12, 6)
  local tx, ty = 620, 552
  if lt > 50 then tx, ty = lerp(620, 560, prog(lt, 50, 51)), lerp(552, 610, prog(lt, 50, 51)) end
  if lt < 52 then
    lg.setColor(0.3, 0.45, 0.25, 1)
    lg.ellipse("fill", tx, ty, 28, 14, 16)
    lg.setColor(0.4, 0.55, 0.3, 1)
    lg.circle("fill", tx + 30, ty - (floor(S.t / 4) % 2) * 4, 7, 10)
  end
  -- a dragonfly darting along the river, landing on heads in turn
  if lt > 2 and lt < 30 then
    local hop = floor((lt - 2) / 3.5)
    local f = ((lt - 2) % 3.5) / 3.5
    local tx0, ty0 = tube_pos(lt, hop % 5)
    local tx1, ty1 = tube_pos(lt, (hop + 1) % 5)
    local dx, dy = lerp(tx0, tx1, ease(f)), lerp(ty0 - 60, ty1 - 60, ease(f)) - sin(f * pi) * 80
    if tx0 < -80 then dx, dy = 200 + sin(lt * 2) * 120, 640 + cos(lt * 3) * 30 end
    lg.setColor(0.2, 0.75, 0.85, 1)
    lg.ellipse("fill", dx, dy, 14, 3, 8)
    lg.setColor(1, 1, 1, 0.6)
    local w = abs(sin(S.t * 40)) * 10
    lg.ellipse("fill", dx - 2, dy - 4, 6, w, 8)
    lg.ellipse("fill", dx + 4, dy - 4, 6, w, 8)
  end
  -- a fish jumping
  if lt > 18 and lt < 20 then
    local f = lt - 18
    local fx, fy = lerp(300, 420, f / 2), 720 - sin(f / 2 * pi) * 140
    lg.setColor(0.7, 0.75, 0.8, 1)
    lg.push()
    lg.translate(fx, fy)
    lg.rotate(-0.8 + f * 0.8)
    lg.ellipse("fill", 0, 0, 20, 8, 12)
    lg.polygon("fill", -18, 0, -30, -8, -30, 8)
    lg.pop()
  end
  -- the take-out (53): the rope swing off the big oak, one after another, Pac-Man's cannonball last
  if lt > 52 then
    L.live_oak(120, 660, 1.6, S.t)
    local PIV = {230, 420}
    -- the limb the rope hangs from
    lg.setColor(0.35, 0.25, 0.16, 1)
    lg.setLineWidth(14)
    lg.line(110, 560, 170, 470, PIV[1] + 10, PIV[2] - 4)
    for k, who in ipairs({1, 2, 3, 4, 0}) do
      local t0 = SWING0 + (k - 1) * SWING_DT
      local ph = lt - t0
      local x, y, rot = nil, nil, 0
      if ph > -1.5 and ph < 0 then
        x, y = lerp(-60, 130, prog(ph, -1.5, -0.2)), 640
      elseif ph >= 0 and ph < 1.6 then
        local a = lerp(-0.7, 0.95, ease(ph / 1.6))
        x, y = PIV[1] + sin(a) * 240, PIV[2] + cos(a) * 240
        lg.setColor(0.75, 0.65, 0.45, 1)
        lg.setLineWidth(3)
        lg.line(PIV[1], PIV[2], x, y - 30)
      elseif ph >= 1.6 and ph < 2.5 then
        local f = (ph - 1.6) / 0.9
        x, y = lerp(PIV[1] + sin(0.95) * 240, 470, f), lerp(PIV[2] + cos(0.95) * 240, 760, f) - sin(f * pi) * 120
        rot = (who == 2 and f * 2 * pi) or (who == 1 and f * 1.8) or 0
      elseif ph >= 2.5 then
        x, y = 400 + (k - 1) * 78 + (ph - 2.5) * 4, 790 + (k % 2) * 30 + sin(S.t * 2 + k) * 4
      end
      if x then
        lg.push()
        lg.translate(x, y)
        lg.rotate(rot)
        if who == 3 and ph > 1.6 and ph < 2.5 then lg.scale(1.3, 0.8) end
        if who == 4 and ph > 1.6 and ph < 2.5 then lg.scale(cos((ph - 1.6) * 4 * pi), 1) end
        guest(who, 0, 0, (who == 0 and ph > 1.6 and ph < 2.5) and 40 or 32, 1, 0,
              ph >= 2.5 and "happy" or ((ph > 0.6 and ph < 2.5) and "wide" or nil), false, (who == 0 and ph > 1.6 and ph < 2.5) and 0.05 or nil)
        lg.pop()
      end
    end
    -- (the rope, hanging when no one's on it)
    lg.setColor(0.75, 0.65, 0.45, 1)
    lg.setLineWidth(3)
    local idle = true
    for k = 1, 5 do local ph = lt - SWING0 - (k - 1) * SWING_DT if ph >= 0 and ph < 1.6 then idle = false end end
    if idle then lg.line(PIV[1], PIV[2], PIV[1] + sin(S.t) * 20, PIV[2] + 230) end
    if lt > SWING0 + 4 * SWING_DT - 0.4 and lt < SWING0 + 4 * SWING_DT + 1.6 then G:say("CANNONBALL!", 300, 520, 26, 1) end
    return
  end
  -- the flotilla, everyone in their tubes; holding hands once linked
  local spin = (lt > RAPIDS[1] and lt < RAPIDS[2]) and S.t * 3 or 0
  for i = 0, 4 do
    local x, y = tube_pos(lt, i)
    if who ~= nil then end
    local mood = (lt > RAPIDS[1] and lt < RAPIDS[2]) and "wide" or ((lt > 46 and i == 0) and "sleep" or nil)
    if i == 3 and lt > 40 and lt < 48 then
      x = lerp(x, 640, prog(lt, 40, 44)) - lerp(0, 120, prog(lt, 44, 48))
      y = lerp(y, 880, prog(lt, 40, 44))
    end
    if x > -100 then tube(x, y, 1.2, i, mood, sin(spin + i) * 0.5) end
    if lt > 14 and lt < RAPIDS[1] and i > 0 then
      local px, py = tube_pos(lt, i - 1)
      lg.setColor(1, 1, 1, 0.5)
      lg.setLineWidth(3)
      lg.line(x + 30, y - 10, px - 30, py - 10)
    end
  end
  -- the cooler: tied on behind, then loose in the rapids, then fetched
  local cx, cy = tube_pos(lt, 5)
  if lt > RAPIDS[1] then cx, cy = lerp(cx, 700, prog(lt, RAPIDS[1], 40)), lerp(cy, 880, prog(lt, RAPIDS[1], 40)) end
  if lt > 44 then local tx3, ty3 = tube_pos(lt, 3) cx, cy = tx3 + 60, ty3 + 20 end
  if cx > -80 then
    lg.setColor(0.15, 0.15, 0.17, 1)
    lg.ellipse("fill", cx, cy + 40, 40, 16, 24)
    lg.setColor(0.2, 0.5, 0.85, 1)
    lg.rectangle("fill", cx - 24, cy + 8, 48, 30, 4, 4, 4)
    lg.setColor(1, 1, 1, 1)
    lg.rectangle("fill", cx - 24, cy + 8, 48, 8, 4, 4, 4)
  end
  if lt > RAPIDS[1] + 1 and lt < RAPIDS[1] + 4 then G:say("WHEEEE!", 300, 640, 26, 1) end
  if lt > RAPIDS[2] - 1 and lt < RAPIDS[2] + 2 then G:say("THE COOLER!", 500, 640, 24, 1) end
  if lt > 44 and lt < 47 then G:say("GOT IT!", 560, 760, 24, 1) end
  if lt > 50.5 and lt < 53 then G:say("PLOP.", 580, 520, 22, 1) end
  if lt > 12 and lt < 15 then G:say("HOLD HANDS!", 300, 660, 22, 1) end
end
CAM.tubing = function(lt)
  if lt > 52 then return L.shot(lt, {{52, 384, 700, 1.1}, {54, 300, 620, 1.4}, {74, 330, 640, 1.4}, {80, 384, 640, 1.15}}, W, H) end
  local x2 = tube_pos(lt, 2)
  if lt > 8 and lt < 30 then return L.shot(0, {{0, x2 + 60, 740, 1.4 + 0.25 * sin((lt - 8) * 0.5)}}, W, H) end
  return L.shot(lt, {{0, 384, 512, 1}, {8, tube_pos(8, 2) + 60, 740, 1.4}, {30, tube_pos(30, 2) + 60, 740, 1.4}, {32, 384, 760, 1.1},
                     {40, 520, 800, 1.35}, {46, 520, 800, 1.35}, {49, 600, 600, 1.5}, {53, 600, 600, 1.5}, {56, 300, 760, 1.3},
                     {66, 384, 740, 1.15}, {80, 600, 700, 1.2}}, W, H)
end
CUES.tubing = {{18, "splash", 0.5}, {RAPIDS[1], "whoosh"}, {9, "boing", 0.3}, {16, "boing", 0.3}, {23, "boing", 0.3}, {RAPIDS[1] + 0.5, "cheer"}, {44, "ding"}, {50.5, "splash", 0.5}}
for k = 1, 5 do
  local t0 = SWING0 + (k - 1) * SWING_DT
  CUES.tubing[#CUES.tubing + 1] = {t0, "whoosh", 0.5}
  CUES.tubing[#CUES.tubing + 1] = {t0 + 2.5, function() splash(470 + (k - 1) * 30, 780, k == 5 or k == 3) end}
end
CUES.tubing[#CUES.tubing + 1] = {SWING0 + 4 * SWING_DT + 3, "cheer"}

-- ------------------------------------------------------------------ the storm
local BOLTS = {22, 27, 31.5}
local function storm_k(lt) return clamp((lt - 8) / 8, 0, 1) * clamp((44 - lt) / 4, 0, 1) end
function D.storm(lt, len)
  local k = storm_k(lt)
  if S.art.storm_clear and S.art.storm_dark then
    art("storm_clear")
    art("storm_dark", k)
  else
    G:gradient(0, 0, W, 640, mix({0.3, 0.55, 0.95}, {0.2, 0.22, 0.28}, k), mix({0.8, 0.9, 1}, {0.4, 0.42, 0.45}, k))
    G:gradient(0, 640, W, H, {0.4, 0.62, 0.3}, {0.3, 0.5, 0.22})
  end
  -- the clouds rolling in from the left
  for i = 0, 6 do
    local cx = lerp(-300, i * 130 - 40, prog(lt, 6 + i * 0.4, 14 + i * 0.4)) + sin(S.t * 0.2 + i) * 20
    lg.setColor(0.35, 0.36, 0.42, 0.9 * min(1, k * 1.5))
    lg.ellipse("fill", cx, 120 + (i % 2) * 40, 140, 80, 24)
  end
  -- puddles growing on the grass
  for i = 1, 4 do
    local p = prog(lt, 20 + i * 2, 30 + i * 2) * (1 - prog(lt, 50, 58))
    if p > 0 then
      lg.setColor(0.35, 0.45, 0.6, 0.7)
      lg.ellipse("fill", 120 + i * 140, 900 + (i % 2) * 30, 70 * p, 16 * p, 20)
    end
  end
  -- the rainbow, and Pac-Man sliding down it
  local rb = prog(lt, 44, 48)
  if rb > 0 then
    local cols = {{1, 0.2, 0.2}, {1, 0.55, 0.1}, {1, 0.9, 0.2}, {0.3, 0.8, 0.3}, {0.25, 0.5, 1}, {0.45, 0.25, 0.8}}
    lg.setLineWidth(16)
    for i, c in ipairs(cols) do
      lg.setColor(c[1], c[2], c[3], 0.75 * rb)
      lg.arc("line", "open", 384, 760, 420 - i * 16, pi, pi + pi * rb, 48)
    end
  end
  -- rain
  if k > 0.3 then
    lg.setColor(0.75, 0.82, 0.95, 0.6 * k)
    lg.setLineWidth(2)
    for i, d in ipairs(S.rain) do
      local y = (d[2] + S.t * 700) % 1100 - 60
      lg.line(d[1], y, d[1] - 6, y + 22)
    end
  end
  -- the picnic blanket: on the grass, then held up over their heads, running
  local bx, by = 384, 880
  local run = lt > 16 and lt < 36
  if run then bx, by = 384 + sin((lt - 16) * 0.6) * 200, 780 end
  if lt < 16 or lt > 36 then
    lg.setColor(0.9, 0.2, 0.2, 1)
    lg.rectangle("fill", bx - 150, by - 10, 300, 70, 6, 6, 4)
    lg.setColor(1, 1, 1, 0.8)
    for gx = 0, 5 do for gy = 0, 1 do if (gx + gy) % 2 == 0 then lg.rectangle("fill", bx - 150 + gx * 50, by - 10 + gy * 35, 50, 35) end end end
    -- the basket, the sandwiches
    lg.setColor(0.65, 0.45, 0.2, 1)
    lg.rectangle("fill", bx + 80, by - 40, 60, 40, 6, 6, 4)
  end
  -- the cast
  for i, who in ipairs({1, 2, 0, 3, 4}) do
    local x, y = bx - 150 + (i - 1) * 75, by - 30
    local mood = nil
    if run then
      x, y = bx - 120 + (i - 1) * 60, by + 40 - abs(sin(S.t * 10 + i)) * 10
      mood = "wide"
    end
    if lt > 22 and lt < 36 and (i == 2 or i == 4) and floor(lt) % 4 < 2 then
      -- puddle jumping instead
      x, y = 120 + i * 140, 870 - L.hop(lt, 0.6, 60)
      mood = "happy"
    end
    if lt > 36 and lt < 44 then mood = "happy" end
    if who == 0 and lt > 48 and lt < 56 then
      -- up the rainbow's end and down the slide
      local f = lin(lt, 49, 55)
      local a = pi + f * pi
      x, y = 384 + cos(a) * 340, 760 + sin(a) * 340 - 24
      if lt < 49 then x, y = lerp(x, 44, prog(lt, 48, 49)), lerp(by - 30, 736, prog(lt, 48, 49)) end
    end
    if who == 0 and lt > 56 then x, y = 724, 870 end
    guest(who, x, y - 6, 36, 1, (lt > 44) and -0.8 or 0, mood, lt < 8 or lt > 46)
  end
  -- lightning
  for _, b in ipairs(BOLTS) do
    if lt > b and lt < b + 0.25 then
      lg.setColor(1, 1, 1, 0.5)
      lg.rectangle("fill", 0, 0, W, H)
      lg.setColor(1, 1, 1, 1)
      lg.setLineWidth(5)
      local x, y = 260 + (b * 41) % 260, 160
      local pts = {x, y}
      for i = 1, 7 do x = x + (((floor(b) * 7919 + i * 104729) % 1000) / 1000 - 0.5) * 50 y = y + 70 pts[#pts + 1] = x pts[#pts + 1] = y end
      lg.line(pts)
    end
  end
  if lt > 15 and lt < 18 then G:say("UH-OH.", 384, 760, 26, 1) end
  if lt > 49 and lt < 52 then G:say("WHEEEEE!", 200, 420, 26, 1) end
  if lt > 40 and lt < 43.5 then G:say("BACK TO 100!", 384, 760, 24, 1) end
end
CAM.storm = function(lt)
  if lt > 48.5 and lt < 56 then
    local f = lin(lt, 49, 55)
    local a = pi + f * pi
    return L.shot(0, {{0, 384 + cos(a) * 300, 760 + sin(a) * 300, 1.35}}, W, H)
  end
  return L.shot(lt, {{0, 384, 512, 1}, {3, 384, 820, 1.35}, {8, 384, 820, 1.35}, {14, 384, 560, 1.05}, {16, 384, 760, 1.3},
                     {22, 384, 700, 1.05}, {28, 384, 760, 1.25}, {36, 384, 640, 1.05}, {44, 384, 600, 1}, {48, 160, 700, 1.3},
                     {56, 700, 820, 1.4}, {60, 384, 600, 1.05}}, W, H)
end
CUES.storm = {{15, "boing", 0.4}, {16, "whoosh"}, {44, "chime"}, {49, "boing"}, {55, "cheer"}}
for _, b in ipairs(BOLTS) do CUES.storm[#CUES.storm + 1] = {b, "thunder"} end
for t = 230, 350, 20 do CUES.storm[#CUES.storm + 1] = {t / 10, function()
  local i = floor(t / 20) % 4 + 1
  splash(120 + i * 140, 900, false)
end} end

-- ------------------------------------------------------------------ fireflies
local JARS = {{1, 470}, {2, 560}, {3, 650}}           -- who, x on the porch
local RELEASE = 42
function D.fireflies(lt, len)
  local k = clamp(lt / 40, 0, 1)
  if S.art.porch_dusk and S.art.porch_night then
    art("porch_dusk")
    art("porch_night", k)
  else
    G:gradient(0, 0, W, 700, mix({0.4, 0.3, 0.6}, {0.03, 0.04, 0.12}, k), mix({1, 0.6, 0.35}, {0.1, 0.1, 0.25}, k))
  end
  -- the fireflies: free ones blinking; the caught ones in the jars; all of them let go; the heart
  lg.setBlendMode("add")
  local caught = floor(clamp((lt - 8) / 30, 0, 1) * 30)
  for i, f in ipairs(S.flies) do
    local on = sin(S.t * f[3] + f[4])
    local x = f[1] + sin(S.t * 0.3 + i) * 40
    local y = f[2] + cos(S.t * 0.4 + i) * 30
    local free = i > caught or lt > RELEASE
    if lt > RELEASE then
      -- up out of the jars, spreading
      local j = JARS[i % 3 + 1]
      local g = lin(lt, RELEASE, RELEASE + 6)
      if i <= caught then x, y = lerp(j[2], x, g), lerp(800, y - 100, g) end
      -- the heart, for a moment
      local h = prog(lt, 56, 59) * (1 - prog(lt, 66, 69))
      if h > 0 then
        local t = i / #S.flies * 2 * pi
        local hx = 384 + 16 * sin(t) ^ 3 * 9
        local hy = 330 - (13 * cos(t) - 5 * cos(2 * t) - 2 * cos(3 * t) - cos(4 * t)) * 9
        x, y = lerp(x, hx, h), lerp(y, hy, h)
        on = 1
      end
    end
    if free and on > 0.3 then
      local b = (on - 0.3) / 0.7 * max(k, 0.3)
      lg.setColor(1, 0.95, 0.4, 0.25 * b)
      lg.circle("fill", x, y, 22, 14)
      lg.setColor(1, 0.95, 0.5, 0.6 * b)
      lg.circle("fill", x, y, 9, 10)
      lg.setColor(1, 1, 0.8, b)
      lg.circle("fill", x, y, 4, 8)
    end
  end
  lg.setBlendMode("alpha")
  -- the porch swing: Pac-Man and Pinky at first, then Pac-Man with the net
  local sw = sin(S.t * 0.8) * 10
  lg.setColor(0.3, 0.2, 0.15, 1)
  lg.setLineWidth(2)
  lg.line(520, 486, 520 + sw, 610)
  lg.line(680, 486, 680 + sw, 610)
  lg.rectangle("fill", 510 + sw, 610, 180, 14)
  -- the jar-carriers out in the yard, their jars filling with light
  for _, j in ipairs(JARS) do
    local who, jx = j[1], j[2]
    local x, y
    if lt < 8 then x, y = jx, 690
    elseif lt < RELEASE - 4 then
      x = 120 + ((S.t * 40 + who * 160) % 420) + sin(S.t * 2 + who) * 30
      y = 820 - abs(sin(S.t * 3 + who)) * 40
    else x, y = lerp(x or jx - 300, jx - 300, 1), 820 end
    guest(who, x, y - 6, 36, 1, -0.6, lt > RELEASE and "happy" or nil, false)
    -- the jar
    local glow = clamp(caught / 30, 0, 1) * (lt > RELEASE and 1 - lin(lt, RELEASE, RELEASE + 2) or 1)
    lg.setColor(0.8, 0.9, 1, 0.35)
    lg.rectangle("fill", x + 22, y - 10, 22, 30, 4, 4, 4)
    if glow > 0 then C.fx.glow(x + 33, y + 4, 26, 26, 1, 0.95, 0.4, 0.8 * glow) end
  end
  -- Pac-Man: the swing, then the net (missing), the firefly on his nose
  local px = lt < 10 and 560 + sw or (lt < 38 and 300 + sin(S.t * 0.7) * 160 or 560 + sw)
  local py = lt < 10 and 588 or (lt < 38 and 860 or 588)
  guest(0, px, py - 6, 34, 1, 0, nil, false, (lt > 24 and lt < 28) and 0.9 or nil)
  if lt > 10 and lt < 38 then
    local swing = sin(S.t * 5) * 1.2
    lg.setColor(0.55, 0.4, 0.25, 1)
    lg.setLineWidth(3)
    lg.line(px + 20, py, px + 20 + cos(swing - 1.2) * 70, py + sin(swing - 1.2) * 70)
    lg.setColor(1, 1, 1, 0.6)
    lg.circle("line", px + 20 + cos(swing - 1.2) * 84, py + sin(swing - 1.2) * 84, 16, 14)
  end
  if lt > 30 and lt < 36 then
    lg.setBlendMode("add")
    C.fx.glow(px + 26, py - 4, 20, 20, 1, 0.95, 0.4, 0.9 * (0.5 + 0.5 * sin(S.t * 6)))
    lg.setBlendMode("alpha")
  end
  -- the porch light going off at the end, the window warm
  if lt > 72 then
    lg.setColor(0, 0, 0.02, 0.3 * lin(lt, 72, 76))
    lg.rectangle("fill", 0, 0, W, H)
  end
  if lt > 26 and lt < 29 then G:say("MISSED!", px, py - 60, 24, 1) end
  if lt > 31 and lt < 35 then G:say("HI.", px, py - 60, 24, 1) end
  if lt > RELEASE - 2 and lt < RELEASE + 1 then G:say("READY? GO!", 470, 740, 24, 1) end
  if lt > 58 and lt < 64 then G:say("AWWW!", 384, 740, 26, 1) end
end
CAM.fireflies = function(lt)
  return L.shot(lt, {{0, 384, 512, 1}, {6, 560, 640, 1.4}, {10, 384, 760, 1.2}, {20, 300, 800, 1.35}, {24, 340, 800, 1.6},
                     {29, 340, 800, 1.6}, {36, 384, 700, 1.15}, {RELEASE, 470, 760, 1.3}, {RELEASE + 6, 384, 500, 1.05},
                     {56, 384, 400, 1.2}, {66, 384, 400, 1.2}, {72, 600, 560, 1.4}, {80, 384, 512, 1}}, W, H)
end
CUES.fireflies = {{26, "boing"}, {31, "chime", 0.5}, {RELEASE, "chime"}, {RELEASE + 0.2, "cheer"}, {57, "power", 0.6}}

-- ------------------------------------------------------------------ SUMMER IN TEXAS
local PIER_END = 500
function D.finale(lt, len)
  if not art("finale") then
    G:gradient(0, 0, W, H, {0.25, 0.4, 0.8}, {1, 0.6, 0.35})
    sun(384, 640, 140)
  end
  water_lines(770, 1000, S.t, 0.3)
  -- the cast along the pier, off the end one by one
  for i, who in ipairs({0, 1, 2, 3, 4}) do
    local t0 = 6 + (i - 1) * 3.5
    local x, y = 90 + (i - 1) * 70, 812
    if lt > t0 then
      local f = lin(lt, t0, t0 + 1.4)
      if lt < t0 + 1.4 then
        x = lerp(x, PIER_END + 40, f) y = 812 - sin(f * pi) * 120 + f * 60
      else
        x, y = PIER_END + 60 + (i - 1) * 40, 880 + sin(S.t * 2 + i) * 4
      end
    elseif lt > t0 - 2 then
      x = lerp(x, PIER_END - 10, prog(lt, t0 - 2, t0))
    end
    -- each one's own jump: Blinky dives, Pinky flips, Inky belly-flops, Clyde twirls, Pac-Man's cannonball last
    local style = ({[0] = "ball", "dive", "flip", "flop", "twirl"})[who]
    local inair = lt > t0 and lt < t0 + 1.4
    lg.push()
    lg.translate(x, y - 4)
    if inair then
      local f = lin(lt, t0, t0 + 1.4)
      if style == "dive" then lg.rotate(f * 2.2)
      elseif style == "flip" then lg.rotate(f * 2 * pi)
      elseif style == "flop" then lg.scale(1.3, 0.8)
      elseif style == "twirl" then lg.scale(cos(f * 4 * pi), 1) end
    end
    guest(who, 0, 0, (who == 0 and inair) and 40 or 32, 1, 0, lt > t0 + 1.4 and "happy" or (inair and style == "flop" and "wide" or nil), false,
          (who == 0 and inair) and 0.05 or nil)
    lg.pop()
  end
  G:caption("SUMMER", 260, 96, 0xffd23f, L.window(lt, 0.5, len, 1))
  G:caption("IN TEXAS", 380, 44, 0xffffff, L.window(lt, 1, len, 1))
end
CAM.finale = function(lt)
  return L.shot(lt, {{0, 384, 512, 1}, {4, 384, 700, 1.2}, {24, 500, 760, 1.3}, {34, 384, 600, 1.1}, {40, 384, 512, 1}}, W, H)
end
CUES.finale = {}
for i = 1, 5 do CUES.finale[#CUES.finale + 1] = {6 + (i - 1) * 3.5 + 1.4, function() splash(PIER_END + 60, 880, i == 1 or i == 4) end} end
for i = 1, 5 do CUES.finale[#CUES.finale + 1] = {6 + (i - 1) * 3.5, "whoosh", 0.4} end
-- fireworks over the lake to end the summer
for k = 0, 11 do
  CUES.finale[#CUES.finale + 1] = {24 + k * 1.2, function()
    G:rocket(140 + (k * 211) % 500, 140 + (k * 97) % 200, {from = 760, colours = {{1, 0.4, 0.3}, {1, 0.85, 0.3}, {0.4, 0.8, 1}, {1, 1, 1}}})
  end}
end
CUES.finale[#CUES.finale + 1] = {24, "cheer"}

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
  S.art = {}
  for _, n in ipairs({"open", "lake", "springs", "snocone", "tubing", "storm_clear", "storm_dark", "porch_dusk",
                      "porch_night", "finale"}) do
    S.art[n] = G:art("summer", n)
  end
  S.rain, S.flies = {}, {}
  for i = 1, 140 do S.rain[i] = {R:random() * W, R:random() * 1100} end
  for i = 1, 60 do S.flies[i] = {R:random() * W, 300 + R:random() * 600, 1 + R:random() * 2, R:random() * 6} end
  for _, s in ipairs(SCENES) do if s[4] then G:label(s[4], 56, 0xffffff) end end
  for _, l in ipairs({{"PRESENTS", 26, 0x6ef0c8}, {"SUMMER", 96, 0xffd23f},
                      {"IN TEXAS", 44, 0xffffff}, {"IT'S 68°. IT'S ALWAYS 68°.", 30, 0x9fd8ff}}) do
    G:label(l[1], l[2], l[3])
  end
end

function M.act() return S and scene_at(S.t)[2] or "open" end
function M.music() return S and scene_at(S.t)[3] or "su_lake" end

local function cues(name, lt, dt)
  local list = CUES[name]
  if not list then return end
  for _, c in ipairs(list) do
    if lt - dt < c[1] and lt >= c[1] then
      if type(c[2]) == "function" then c[2]() else C.sfx(c[2], c[3]) end
    end
  end
end

function M.update(dt)
  if not S then return false end
  G:step(dt)
  S.t = G.t
  local sc, lt = scene_at(S.t)
  cues(sc[2], lt, dt)
  if sc[2] == "storm" and lt > 40 and lt < 48 and G.R:random() < dt * 6 then
    G:puff(G.R:random() * W, 960, {1, 1, 1}, 40, 0, 2.4, 10, 0.25)
  end
  return S.t >= LEN
end

function M.draw()
  if not S then return end
  local sc, lt, len = scene_at(S.t)
  local cam = CAM[sc[2]]
  local x, y, z, shake = 384, 512, 1, 0
  if cam then x, y, z, shake = cam(lt, len) end
  G:look(x, y, z, shake)
  D[sc[2]](lt, len)
  G:draw_back()
  G:draw_front()
  G:unlook()
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
