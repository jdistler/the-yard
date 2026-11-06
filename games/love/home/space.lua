-- Mission Control: Houston's space show (Texas is where the missions were flown from), nine minutes. Every
-- scene a story with its own camera (SHOWS_BLUEPRINT.md):
--   0:00  STARLIGHT PRESENTS ... MISSION CONTROL, HOUSTON                          (Countdown Hum)
--   0:08  Houston: the field trip. The school bus, the cast measuring the Saturn V nose to tail with a tape
--         (363 feet), Clyde hiding in an engine, BOO!, a jet over, back on the bus
--   1:20  Mission Control: the room wakes (the lights bank by bank, the consoles boot, the map draws), the team
--         comes in with coffee (one spills), the go/no-go poll station by station (Clyde asleep at GUIDANCE until a
--         paper ball wakes him), WE ARE GO, the clock running into the launch
--   2:30  Launch: the vapour, the arm swinging back, the count, ignition, liftoff, staging, the room cheering,
--         the tower jettisoned, on to orbit                    (Also sprach Zarathustra's sunrise, 1896)
--   4:00  Orbit: the station; Pac-Man out on his tether to fix a folded solar wing, the wrench floats off and is
--         caught, sunrise over the edge, Texas going by, a cargo ship docks         (The Blue Danube, 1866)
--   5:30  The Moon: the lander coming down, the ladder, the first step, the hops and the footprints, two flags,
--         the rover, a golf shot that comes down on a helmet, lift-off       (Tranquility)
--   7:00  Splashdown: re-entry glowing, the drogues, three mains blooming, the splash, the dye, the raft, the
--         collar, the helicopter lifting the crew, the carrier's fireworks       (Homecoming)
--   8:20  Houston, we've had a party: the room celebrates, balloons, the replays on the big screen
local lg = love.graphics
local L = require("showlib")
local M = {}
local C, G
local W, H = 768, 1024
local LEN = 540
M.LEN = LEN
local sin, cos, floor, min, max, abs, pi, sqrt = math.sin, math.cos, math.floor, math.min, math.max, math.abs, math.pi, math.sqrt
local clamp, ease, lerp, mix = L.clamp, L.ease, L.lerp, L.mix

local SCENES = {
  {0, "open", "mc_hum"},
  {8, "houston", "mc_hum", "HOUSTON", "THE SATURN V  ·  ROCKET PARK"},
  {80, "control", "mc_hum", "MISSION CONTROL", "FLIGHT, WE ARE GO"},
  {150, "launch", "mc_sunrise", "LAUNCH", "T MINUS TEN"},
  {240, "orbit", "mc_danube", "ORBIT", "SEVENTEEN THOUSAND MILES AN HOUR"},
  {330, "moon", "mc_tranquil", "THE MOON", "THE EAGLE HAS LANDED"},
  {420, "splash", "mc_home", "SPLASHDOWN", "WELCOME HOME"},
  {500, "party", "mc_home", "HOUSTON, WE'VE HAD A PARTY", "MISSION ACCOMPLISHED. FOR REAL THIS TIME."},
}
M.SEGMENTS = {}
for _, s in ipairs(SCENES) do if s[4] then M.SEGMENTS[#M.SEGMENTS + 1] = {s[1], s[4]} end end
M.THUMB = 3

local S
local function scene_at(t)
  local k = 1
  for i, s in ipairs(SCENES) do if t >= s[1] then k = i end end
  local s = SCENES[k]
  local e = SCENES[k + 1] and SCENES[k + 1][1] or LEN
  return s, t - s[1], e - s[1], k
end
-- 0 before a, 1 after b, eased between
local function prog(lt, a, b) return ease((lt - a) / (b - a)) end
local function lin(lt, a, b) return clamp((lt - a) / (b - a), 0, 1) end

-- the cast: Pac-Man and the ghosts (Blinky, Pinky, Inky, Clyde, and two more for the room: Sue and Funky)
local GH = {{1, 0.18, 0.2}, {1, 0.55, 0.85}, {0.25, 0.95, 1}, {1, 0.65, 0.2}, {0.72, 0.42, 1}, {0.35, 0.92, 0.45}}

-- ------------------------------------------------------------------ small things
local function stars()
  for i, s in ipairs(S.stars) do
    lg.setColor(1, 1, 0.95, s[3] * (0.7 + 0.3 * sin(S.t * (1 + i % 3) + i)))
    lg.rectangle("fill", s[1], s[2], 2, 2)
  end
end

-- The rocket, standing (bottom centre at x, y), s scale
local function rocket(x, y, s)
  local w = 40 * s
  lg.setColor(0.95, 0.95, 0.95, 1)
  lg.rectangle("fill", x - w, y - 300 * s, w * 2, 300 * s)
  lg.rectangle("fill", x - w * 0.8, y - 420 * s, w * 1.6, 120 * s)
  lg.polygon("fill", x - w * 0.8, y - 420 * s, x + w * 0.8, y - 420 * s, x + w * 0.4, y - 470 * s, x - w * 0.4, y - 470 * s)
  lg.polygon("fill", x - w * 0.4, y - 470 * s, x + w * 0.4, y - 470 * s, x, y - 520 * s)
  lg.setColor(0.1, 0.1, 0.12, 1)
  for _, yy in ipairs({-40, -150, -260, -330}) do lg.rectangle("fill", x - w, y + yy * s, w * 2, 10 * s) end
  lg.rectangle("fill", x - w, y - 300 * s, w * 0.6, 60 * s)
  G:text("USA", x - w, y - 230 * s, floor(18 * s + 0.5), {0.15, 0.15, 0.2}, 1, "center", w * 2)
  lg.setColor(0.25, 0.25, 0.28, 1)
  for i = -1, 1 do lg.polygon("fill", x + i * 22 * s - 12 * s, y, x + i * 22 * s + 12 * s, y, x + i * 22 * s + 16 * s, y + 24 * s, x + i * 22 * s - 16 * s, y + 24 * s) end
  lg.polygon("fill", x - w, y - 20 * s, x - w - 20 * s, y + 10 * s, x - w, y + 10 * s)
  lg.polygon("fill", x + w, y - 20 * s, x + w + 20 * s, y + 10 * s, x + w, y + 10 * s)
end

-- An astronaut: Pac-Man in a suit and helmet (facing dir); y is the suit's middle, the boots end at y + 48 s
local function astronaut(x, y, s, dir, t, open)
  lg.setColor(0.95, 0.95, 0.95, 1)
  lg.rectangle("fill", x - 18 * s, y - 20 * s, 36 * s, 44 * s, 10 * s, 10 * s, 6)
  lg.rectangle("fill", x - 30 * s, y - 14 * s, 14 * s, 30 * s, 6 * s, 6 * s, 6)
  lg.rectangle("fill", x + 16 * s, y - 14 * s, 14 * s, 30 * s, 6 * s, 6 * s, 6)
  lg.rectangle("fill", x - 16 * s, y + 22 * s, 14 * s, 26 * s, 6 * s, 6 * s, 6)
  lg.rectangle("fill", x + 2 * s, y + 22 * s, 14 * s, 26 * s, 6 * s, 6 * s, 6)
  lg.setColor(0.75, 0.75, 0.78, 1)
  lg.rectangle("fill", x - dir * 30 * s - 10 * s, y - 16 * s, 20 * s, 36 * s, 4 * s, 4 * s, 4)
  lg.setColor(0.85, 0.85, 0.9, 1)
  lg.circle("fill", x, y - 44 * s, 28 * s, 24)
  lg.setColor(0.15, 0.2, 0.35, 1)
  lg.circle("fill", x, y - 44 * s, 22 * s, 24)
  L.pac(x, y - 44 * s, 15 * s, dir > 0 and 0 or pi, t, open)
  lg.setColor(1, 1, 1, 0.35)
  lg.ellipse("fill", x - 8 * s, y - 54 * s, 8 * s, 4 * s, 10)
  lg.setColor(0.8, 0.1, 0.12, 1)
  lg.rectangle("fill", x - 10 * s, y - 6 * s, 8 * s, 5 * s)
  lg.setColor(0.15, 0.2, 0.55, 1)
  lg.rectangle("fill", x - 10 * s, y - 6 * s, 3 * s, 3 * s)
end

-- A ghost in a fishbowl helmet (the Moon): its middle at x, y
local function space_ghost(x, y, r, c, t, lx, ly, mood)
  L.ghost(x, y, r, c, t, lx, ly, mood)
  lg.setColor(0.8, 0.9, 1, 0.22)
  lg.circle("fill", x, y - r * 0.1, r * 1.35, 28)
  lg.setColor(0.9, 0.95, 1, 0.7)
  lg.setLineWidth(2)
  lg.circle("line", x, y - r * 0.1, r * 1.35, 28)
  lg.setColor(1, 1, 1, 0.5)
  lg.ellipse("fill", x - r * 0.6, y - r * 0.9, r * 0.3, r * 0.14, 10)
end

-- Three little stars going round a head (a bonk)
local function dizzy(x, y, r, t)
  lg.setColor(1, 0.9, 0.3, 1)
  for i = 0, 2 do
    local a = t * 5 + i * 2 * pi / 3
    L.star(x + cos(a) * r, y + sin(a) * r * 0.35, 7)
  end
end

-- ------------------------------------------------------------------ the scenes
local D, CAM, CUES = {}, {}, {}

-- the painted picture for a scene, if the SD card has it: drawn, true
local function art(name, a)
  local img = S.art[name]
  if not img then return false end
  lg.setColor(1, 1, 1, a or 1)
  lg.draw(img, 0, 0)
  return true
end

function D.open(lt, len)
  if not art("open") then
    G:gradient(0, 0, W, H, {0.0, 0.0, 0.03}, {0.03, 0.04, 0.12})
    stars()
  end
  local a = L.window(lt, 0.5, 4, 0.7)
  G:brand(400, a)
  G:caption("PRESENTS", 472, 26, 0x6ef0c8, a)
  local b = L.window(lt, 4.2, 8, 0.7)
  G:caption("MISSION CONTROL", 420, 64, 0x8ab4ff, b)
  G:caption("HOUSTON", 500, 34, 0xffffff, b)
end

-- ------------------------------------------------------------------ Houston: the field trip
local GROUND = 712                         -- the path's line, where feet and wheels are
local ENGINE_X, NOSE_X = 40, 732

-- The school bus, facing right (its door at the front, by x + 96); x its middle
local function bus(x, t, door, rolling)
  local y = GROUND
  local bob = rolling and sin(t * 20) * 1.5 or 0
  lg.push()
  lg.translate(0, bob)
  lg.setColor(0, 0, 0, 0.25)
  lg.ellipse("fill", x, y + 4, 140, 10, 20)
  lg.setColor(1, 0.76, 0.08, 1)
  lg.rectangle("fill", x - 130, y - 118, 230, 100, 12, 12, 8)
  lg.rectangle("fill", x + 96, y - 76, 42, 58, 8, 8, 6)
  lg.setColor(0.12, 0.1, 0.08, 1)
  lg.rectangle("fill", x - 130, y - 58, 268, 6)
  lg.rectangle("fill", x - 130, y - 40, 268, 3)
  for i = 0, 4 do
    lg.setColor(0.55, 0.78, 0.95, 1)
    lg.rectangle("fill", x - 118 + i * 38, y - 108, 30, 34, 4, 4, 4)
  end
  -- the door: folding, dark when open
  if door > 0 then lg.setColor(0.12, 0.12, 0.16, 1) else lg.setColor(0.55, 0.78, 0.95, 1) end
  lg.rectangle("fill", x + 72, y - 108, 22, 86, 3, 3, 4)
  lg.setColor(1, 0.95, 0.6, 1)
  lg.circle("fill", x + 134, y - 40, 6, 10)
  lg.setColor(0.9, 0.2, 0.15, 1)
  lg.circle("fill", x - 126, y - 40, 5, 8)
  G:text("FIELD TRIP", x - 130, y - 42, 15, {0.15, 0.1, 0.05}, 1, "center", 200)
  -- the stop sign swings out when the door opens
  if door > 0 then
    lg.setColor(0.85, 0.1, 0.1, 1)
    lg.circle("fill", x - 136 - 14 * door, y - 80, 11, 8)
  end
  for _, wx in ipairs({x - 88, x + 70}) do
    lg.setColor(0.1, 0.1, 0.12, 1)
    lg.circle("fill", wx, y - 14, 19, 20)
    lg.setColor(0.6, 0.6, 0.64, 1)
    lg.circle("fill", wx, y - 14, 8, 12)
    lg.setColor(0.3, 0.3, 0.32, 1)
    local a = -t * (rolling and 12 or 0)
    lg.setLineWidth(3)
    lg.line(wx + cos(a) * 8, y - 14 + sin(a) * 8, wx - cos(a) * 8, y - 14 - sin(a) * 8)
  end
  lg.pop()
end

local BUS_IN, BUS_OUT = 160, 1000
local function bus_x(lt)
  if lt < 66 then return lerp(-220, BUS_IN, 1 - (1 - lin(lt, 2, 10)) ^ 2) end
  return lerp(BUS_IN, BUS_OUT, lin(lt, 66, 72) ^ 2)
end
-- Pac-Man's walk: out of the door, left to the engines to hook the tape, right along to the nose, back to the
-- engines when Clyde is missed, then to the bus
local function pac_x(lt)
  if lt < 11.5 then return BUS_IN + 96 end
  if lt < 14 then return lerp(BUS_IN + 96, 300, prog(lt, 11.5, 13)) end
  if lt < 20 then return lerp(300, ENGINE_X + 30, prog(lt, 16, 19)) end
  if lt < 41 then return lerp(ENGINE_X + 30, NOSE_X, lin(lt, 20.5, 40)) end
  if lt < 51 then return lerp(NOSE_X, 200, prog(lt, 46, 50)) end
  if lt < 62.5 then return 200 end
  return lerp(200, BUS_IN + 96, prog(lt, 62.5, 64))
end

local VISIT = {1, 2, 3, 4}                 -- the ghosts on the trip: Blinky, Pinky, Inky, Clyde (the hider)
-- the ghosts' places in the line: each where Pac-Man was a moment ago, never closer than a body to the one ahead
local function line_x(lt)
  local px = pac_x(lt)
  local side = 1
  for back = 0.3, 6, 0.3 do
    local d = pac_x(max(lt - back, 0)) - px
    if abs(d) > 1 then side = d > 0 and 1 or -1 break end
  end
  local xs, prev = {}, px
  for k = 1, #VISIT do
    local x = pac_x(max(lt - k * 0.9, 0))
    if (x - prev) * side < 46 then x = prev + side * 46 end
    xs[k], prev = x, x
  end
  return xs
end
function D.houston(lt, len)
  if not art("houston") then
    G:gradient(0, 0, W, 640, {0.3, 0.55, 0.9}, {0.85, 0.9, 1})
    G:gradient(0, 640, W, H, {0.35, 0.6, 0.3}, {0.25, 0.48, 0.2})
    lg.setColor(0.95, 0.95, 0.95, 1)
    lg.rectangle("fill", 70, 464, 660, 112)
  end
  -- clouds drifting, a flock going over
  for i = 0, 2 do
    local cx = (i * 300 + S.t * (8 + i * 3)) % (W + 300) - 150
    lg.setColor(1, 1, 1, 0.8)
    lg.ellipse("fill", cx, 200 + i * 60, 70, 20, 20)
    lg.ellipse("fill", cx + 40, 190 + i * 60, 50, 24, 20)
  end
  if lt > 22 and lt < 40 then
    local fx = lerp(-60, W + 60, lin(lt, 22, 40))
    lg.setColor(0.15, 0.15, 0.2, 1)
    lg.setLineWidth(2)
    for i = 0, 4 do
      local bx, by = fx - i * 26, 120 + abs(i - 2) * 14 + sin(S.t * 8 + i) * 3
      lg.line(bx - 8, by - 4, bx, by, bx + 8, by - 4)
    end
  end
  -- the jet and its contrail
  if lt > 54 then
    local jx = lerp(W + 120, -200, lin(lt, 55, 60))
    lg.setColor(1, 1, 1, 0.75 * clamp((72 - lt) / 8, 0, 1))
    lg.setLineWidth(6)
    lg.line(max(jx + 30, -10), 150, W + 120, 150)
    if lt < 60 then
      lg.setColor(0.75, 0.78, 0.85, 1)
      lg.polygon("fill", jx - 34, 150, jx + 30, 144, jx + 30, 156)
      lg.polygon("fill", jx - 4, 150, jx + 16, 128, jx + 22, 150)
      lg.polygon("fill", jx - 4, 150, jx + 16, 172, jx + 22, 150)
    end
  end
  -- Clyde's hiding place: the engine bell (dark inside, his eyes)
  local hide_in, hide_out = 17.5, 50
  if lt > hide_in + 1 and lt < hide_out then
    lg.setColor(0.02, 0.02, 0.04, 1)
    lg.ellipse("fill", 38, 522, 12, 28, 16)
    local look = sin(S.t * 1.7) > 0 and 1 or -1
    local blink = (S.t % 3.1) < 0.15
    for s = -1, 1, 2 do
      lg.setColor(1, 1, 1, 1)
      lg.ellipse("fill", 38 + s * 5, 518, 4, blink and 1 or 6, 10)
      lg.setColor(0.15, 0.25, 0.9, 1)
      if not blink then lg.circle("fill", 38 + s * 5 + look * 1.5, 519, 2.5, 8) end
    end
  end
  -- the tape: from its stake at the engines to Pac-Man's hand, feet marked as it runs out
  local px = pac_x(lt)
  if lt > 19 and lt < 64 then
    local tip = lt < 41 and px or NOSE_X
    if lt > 41 then tip = lerp(NOSE_X, ENGINE_X, lin(lt, 46, 48)) end      -- (reeled back in)
    lg.setColor(0.4, 0.4, 0.42, 1)
    lg.rectangle("fill", ENGINE_X - 3, GROUND - 26, 6, 26)
    lg.setColor(1, 0.85, 0.15, 1)
    lg.rectangle("fill", ENGINE_X, GROUND - 4, tip - ENGINE_X, 6)
    lg.setColor(0.2, 0.15, 0.05, 1)
    for f = 50, 350, 50 do
      local fx = ENGINE_X + f / 363 * (NOSE_X - ENGINE_X)
      if fx < tip then
        lg.rectangle("fill", fx - 1, GROUND - 6, 2, 10)
        G:text(tostring(f), fx - 20, GROUND + 8, 15, {1, 1, 1}, 1, "center", 40)
      end
    end
  end
  -- the bus
  local bx = bus_x(lt)
  local door = (lt > 10.5 and lt < 65) and 1 or 0
  bus(bx, S.t, door, (lt > 2 and lt < 10) or lt > 66)
  -- the cast: Pac-Man in front with his guide's flag, the ghosts in a line behind
  local shown = lt > 11.5 and lt < 64.5
  local face = 0
  if (lt > 15.8 and lt < 19) or (lt > 44.5 and lt < 50) then face = pi end
  if lt > 43 and lt < 45 then face = pi end
  local bob = (lt > 11.5 and lt < 50) and L.hop(S.t, 0.3, 4) or 0
  local scared = lt > 50 and lt < 51.6
  local happy = lt > 51.6 and lt < 55
  local up = lt > 55 and lt < 61
  -- the ghosts first (behind him)
  local xs = line_x(lt)
  if lt < hide_in then S.clyde_from = lt < 16 and lerp(BUS_IN + 96, 300 + 4 * 46, prog(lt, 15.2, 16.4)) or xs[4] end
  for k, gi in ipairs(VISIT) do
    local out_t = 12 + k * 0.8
    local gx, gy = nil, GROUND - 26
    if lt > out_t and lt < 64 + k * 0.35 then
      gx = xs[k]
      if lt < 16 then gx = lerp(BUS_IN + 96, 300 + k * 46, prog(lt, out_t, out_t + 1.2)) end
      if lt > 62.5 then gx = lerp(gx, BUS_IN + 96, prog(lt, 62.5 + k * 0.35, 63.5 + k * 0.35)) end
    end
    -- Clyde: sneaks into the engine while the others look at the rocket; back out at BOO!
    if gi == 4 then
      if lt > hide_in and lt < hide_out then
        local k2 = prog(lt, hide_in, hide_in + 1.2)
        gx = lerp(S.clyde_from or 480, 40, k2)
        gy = lerp(GROUND - 26, 520, k2)
        if k2 >= 1 then gx = nil end
      elseif lt >= hide_out and lt < 64 then
        local k2 = prog(lt, hide_out, hide_out + 0.6)
        gx = lerp(40, 160, k2)
        gy = lerp(520, GROUND - 26, k2) - (lt < 51.6 and L.hop(lt, 0.4, 20) or 0)
      end
    end
    if gx then
      local mood = scared and gi ~= 4 and "scared" or (happy and "happy" or nil)
      if gi == 4 and lt >= hide_out and lt < 51.6 then mood = "wide" end
      local hop = (scared and gi ~= 4) and L.hop(lt, 0.5, 30) or (happy and L.hop(lt + k, 0.35, 10) or bob)
      local lx = face == 0 and 1 or -1
      local ly = 0
      if lt > 44 and lt < 46 then lx = sin(S.t * 3 + k) end
      if up then lx, ly = -0.4, -1 end
      L.ghost(gx, gy - hop, 26, GH[gi], S.t + k, lx, ly, mood)
    end
  end
  if shown then
    local hop = scared and L.hop(lt, 0.5, 30) or (happy and L.hop(lt, 0.35, 12) or bob)
    local py = GROUND - 30 - hop
    -- the guide's flag
    lg.setColor(0.5, 0.5, 0.55, 1)
    lg.setLineWidth(3)
    lg.line(px - 8, py, px - 8, py - 70)
    lg.setColor(1, 0.45, 0.1, 1)
    lg.polygon("fill", px - 8, py - 70, px + 24, py - 62, px - 8, py - 54)
    L.pac(px, py, 30, face, S.t, (scared or happy) and 0.9 or nil)
  end
  -- the words
  if lt > 40 and lt < 43.5 then G:say("363 FEET!", px, GROUND - 74, 22, L.window(lt, 40, 43.5, 0.3)) end
  if lt > 43.5 and lt < 46 then
    local n = clamp(floor((lt - 43.5) / 0.5) + 1, 1, 4)
    local words = {"ONE...", "TWO...", "THREE...", "WHERE'S CLYDE?"}
    G:say(words[n], px, GROUND - 74, 22, 1)
  end
  if lt > 50 and lt < 51.8 then G:say("BOO!", 160, GROUND - 74, 30, 1) end
  if lt > 59 and lt < 63 then G:say("TO MISSION CONTROL!", px, GROUND - 74, 22, L.window(lt, 59, 63, 0.3)) end
  G:plate("363 FEET  ·  THE MOON ROCKET", 240, 28, 0xffffff, L.window(lt, 40.5, 46, 0.8))
end
CAM.houston = function(lt)
  if lt > 22 and lt < 40 then return L.shot(0, {{0, pac_x(lt) + 80, 600, 1.5}}, W, H) end
  return L.shot(lt, {{0, 384, 512, 1}, {3, 160, 600, 1.4}, {10, 230, 620, 1.5}, {16, 230, 620, 1.5}, {20, pac_x(20) + 80, 600, 1.5},
                     {40, NOSE_X - 60, 600, 1.5}, {46, NOSE_X - 60, 600, 1.5}, {49, 120, 560, 2.1}, {52, 150, 600, 1.7},
                     {55, 384, 420, 1.0}, {61, 384, 512, 1}, {64, 230, 620, 1.3}, {72, 600, 600, 1.2}}, W, H)
end
CUES.houston = {
  {2, "jet", 0.3}, {10.5, "pop"}, {12.8, "pop"}, {13.6, "pop"}, {14.4, "pop"}, {15.2, "pop"}, {19.2, "clunk"},
  {40, "ding"}, {44, "boing"}, {50, "boo"}, {55, "jet"}, {66, "whoosh"},
  {10, function() for i = 1, 6 do G:puff(BUS_IN - 140, GROUND - 14, {0.6, 0.6, 0.62}, 20, -40 - i * 10, 1.5, 10, 0.4) end end},
}
for t = 660, 720, 3 do CUES.houston[#CUES.houston + 1] = {t / 10, function()
  G:puff(bus_x(t / 10) - 140, GROUND - 14, {0.6, 0.6, 0.62}, 20, -60, 1.5, 12, 0.45) end} end

-- ------------------------------------------------------------------ Mission Control: the room wakes, the poll
local POLL = {"BOOSTER", "RETRO", "FIDO", "GUIDANCE", "SURGEON", "CAPCOM"}
local SLEEPER = 4                           -- Clyde, at GUIDANCE
local POLL_T = {}
do
  local t = 26
  for i = 1, #POLL do
    POLL_T[i] = t
    t = t + (i == SLEEPER and 7 or 4.6)
  end
  POLL_T[#POLL + 1] = t                     -- (the end of the poll: 56.0)
end
local function station(i)
  local tier, col = floor((i - 1) / 2), (i - 1) % 2
  local x0, y = 60 + col * 340, 560 + tier * 150
  return x0, y, x0 + 150
end
-- when station i says GO
local function go_at(i) return POLL_T[i] + (i == SLEEPER and 4.4 or 1.6) end

local function console(x, y, w, t, i, on)
  lg.setColor(0.45, 0.45, 0.48, 1)
  lg.rectangle("fill", x, y, w, 60)
  lg.setColor(0.35, 0.35, 0.38, 1)
  lg.polygon("fill", x, y, x + w, y, x + w - 10, y - 30, x + 10, y - 30)
  for k = 0, floor(w / 60) - 1 do
    local sx = x + 12 + k * 60
    lg.setColor(0.03, 0.12, 0.05, 1)
    lg.rectangle("fill", sx, y - 26, 44, 22)
    -- booting: the screens light left to right, flickering first
    local s_on = on - k * 0.15
    if s_on > 0 and not (s_on < 0.2 and floor(t * 20) % 2 == 0) then
      lg.setColor(0.3, 1, 0.4, 0.9)
      for r = 0, 2 do
        local len = 10 + ((floor(t * 3) + k * 7 + r * 3 + i) % 5) * 6
        lg.rectangle("fill", sx + 4, y - 22 + r * 6, len, 2)
      end
    end
  end
  if on > 0.5 then
    lg.setColor(1, 0.3, 0.2, (floor(t * 2) + i) % 2 == 0 and 1 or 0.3)
    lg.circle("fill", x + w - 16, y + 14, 4, 8)
  end
end

-- The room at a moment of its story. st: {dark, boot, map, seated, go (per station: true), cheer, screen}
local function room(lt, st)
  if not art("control") then
    G:gradient(0, 0, W, H, {0.12, 0.13, 0.16}, {0.06, 0.07, 0.09})
    lg.setColor(0.03, 0.06, 0.1, 1)
    lg.rectangle("fill", 40, 120, 688, 280)
  end
  -- the ceiling's lights: three banks
  for b = 1, 3 do
    local on = st.banks >= b
    lg.setColor(on and 1 or 0.25, on and 0.97 or 0.25, on and 0.85 or 0.28, 1)
    lg.rectangle("fill", 40 + (b - 1) * 240, 10, 208, 10, 4, 4, 4)
    if on then C.fx.glow(144 + (b - 1) * 240, 30, 150, 40, 1, 0.95, 0.8, 0.25) end
  end
  -- the big screen: the map drawing itself (a curtain going off it), the track, the board
  if st.screen == "map" or st.screen == nil then
    local wipe = st.map or 1
    if wipe < 1 then
      lg.setColor(0.02, 0.03, 0.05, 1)
      lg.rectangle("fill", 40 + 688 * wipe, 120, 688 * (1 - wipe), 280)
      lg.setColor(0.4, 1, 0.6, 0.9)
      lg.rectangle("fill", 40 + 688 * wipe - 2, 120, 3, 280)
    end
    if wipe > 0.3 then
      lg.setColor(1, 0.85, 0.3, 1)
      lg.setLineWidth(2)
      local pts = {}
      local tl = 40 + 688 * clamp(st.track or 1, 0, 1)
      for x = 40, tl, 8 do pts[#pts + 1] = x pts[#pts + 1] = 260 + sin((x - 40) / 688 * 4 * pi + S.t * 0.2) * 90 end
      if #pts >= 4 then lg.line(pts) end
      if (st.track or 1) >= 1 then
        local px = 40 + ((S.t * 30) % 688)
        lg.circle("fill", px, 260 + sin((px - 40) / 688 * 4 * pi + S.t * 0.2) * 90, 6, 10)
      end
    end
    -- the GO / NO-GO board
    if (st.board or 0) > 0 then
      lg.setColor(0, 0, 0, 0.72)
      lg.rectangle("fill", 486, 130, 234, 26 * #POLL + 16, 8, 8, 6)
      for i, name in ipairs(POLL) do
        local y = 138 + (i - 1) * 26
        local g = st.go[i]
        G:text(name, 500, y, 18, g and {0.4, 1, 0.5} or {0.6, 0.65, 0.7}, 1, "left", 150)
        lg.setColor(g and 0.3 or 0.25, g and 1 or 0.25, g and 0.4 or 0.28, 1)
        lg.circle("fill", 690, y + 10, 8, 12)
        if g then C.fx.glow(690, y + 10, 18, 18, 0.3, 1, 0.4, 0.5) end
      end
    end
  elseif st.screen == "pad" then
    lg.setColor(0.03, 0.05, 0.12, 1)
    lg.rectangle("fill", 40, 120, 688, 280)
    G:gradient(40, 120, 728, 400, {0.25, 0.45, 0.8}, {0.8, 0.75, 0.65})
    lg.setColor(0.7, 0.15, 0.1, 1)
    lg.rectangle("fill", 400, 170, 16, 210)
    lg.push()
    lg.translate(384, 380)
    lg.scale(0.38, 0.38)
    rocket(0, 0, 1)
    lg.pop()
    G:text(st.clock or "", 40, 136, 34, {1, 0.75, 0.3}, 1, "right", 670)
  elseif st.screen == "replay" then
    lg.setColor(0.02, 0.04, 0.1, 1)
    lg.rectangle("fill", 40, 120, 688, 280)
    st.replay()
  end
  -- the controllers at their consoles: seated behind them (the console hides their hems)
  for i = 1, #POLL do
    local x0, y, cx = station(i)
    local seat = st.seat and st.seat[i]
    if seat then
      local gx, gy = seat[1], seat[2]
      L.ghost(gx, gy, 30, GH[i], S.t + i, seat[3] or 0, seat[4] or 0, seat[5])
      if seat[6] then
        -- the coffee mug
        lg.setColor(1, 1, 1, 1)
        lg.rectangle("fill", gx + 26, gy - 6, 14, 16, 2, 2, 4)
        lg.setLineWidth(2)
        lg.circle("line", gx + 42, gy + 2, 5, 8)
        lg.setColor(1, 1, 1, 0.35)
        local wv = sin(S.t * 3 + i) * 3
        lg.line(gx + 30 + wv, gy - 10, gx + 33 - wv, gy - 22, gx + 30 + wv, gy - 32)
      end
      -- the headset
      lg.setColor(0.1, 0.1, 0.1, 1)
      lg.setLineWidth(3)
      lg.arc("line", "open", gx, gy - 6, 32, pi + 0.3, 2 * pi - 0.3, 12)
    end
    console(x0, y, 300, S.t, i, st.boot and clamp(st.boot * 6 - (i - 1) * 0.6, 0, 1.2) or 1)
    -- the station's GO lamp
    local g = st.go[i]
    local warn = st.warn and st.warn[i]
    lg.setColor(g and 0.3 or (warn and 1 or 0.3), g and 1 or (warn and 0.25 or 0.3), g and 0.4 or (warn and 0.2 or 0.32), 1)
    lg.circle("fill", x0 + 272, y - 44, 10, 14)
    if g then C.fx.glow(x0 + 272, y - 44, 30, 30, 0.3, 1, 0.4, 0.6) end
    if warn and floor(S.t * 3) % 2 == 0 then C.fx.glow(x0 + 272, y - 44, 26, 26, 1, 0.2, 0.1, 0.5) end
  end
  -- the flight director, at the front: Pac-Man with his headset
  if st.director then
    local d = st.director
    L.pac(d[1], d[2], 44, d[3] or 0, S.t * 0.6, d[4])
    lg.setColor(0.1, 0.1, 0.1, 1)
    lg.setLineWidth(4)
    lg.arc("line", "open", d[1], d[2] - 4, 46, pi + 0.2, 2 * pi - 0.2, 14)
    lg.line(d[1] + 44, d[2], d[1] + 58, d[2] + 20)
  end
  -- the dark before the lights
  if (st.dark or 0) > 0 then
    lg.setColor(0, 0, 0.02, st.dark)
    lg.rectangle("fill", 0, 0, W, H)
  end
end

local DIRECTOR = {384, 930}
local function seat_pos(i)
  local x0, y, cx = station(i)
  return cx, y - 58
end
function D.control(lt, len)
  local st = {go = {}, warn = {}, seat = {}}
  st.banks = (lt > 2.5 and 1 or 0) + (lt > 4.5 and 1 or 0) + (lt > 6.5 and 1 or 0)
  st.dark = ({0.9, 0.62, 0.34, 0})[st.banks + 1]
  st.boot = lin(lt, 7, 15)
  st.map = lin(lt, 9, 14)
  st.track = lin(lt, 14, 18)
  st.board = lt > 25 and 1 or 0
  for i = 1, #POLL do
    st.go[i] = lt >= go_at(i)
    if i == SLEEPER and lt > POLL_T[i] + 0.5 and lt < go_at(i) then st.warn[i] = true end
    -- coming in: from the door at the left, with coffee, to the seat
    local arrive = 14 + i * 1.4
    local sx, sy = seat_pos(i)
    if lt > arrive - 2.4 then
      local k = prog(lt, arrive - 2.4, arrive)
      local gx = lerp(-50, sx, k)
      local gy = lerp(500, sy, k) - (k < 1 and L.hop(lt, 0.35, 10) or 0)
      local lx, ly, mood = (k < 1) and 1 or 0, 0, nil
      -- the poll: turned to the director to answer
      if lt > POLL_T[i] and lt < POLL_T[i + 1] then lx, ly = 0, 0.6 end
      if i == SLEEPER and lt > arrive + 6 and lt < go_at(i) - 1.4 then mood = "sleep" end
      if i == SLEEPER and lt >= go_at(i) - 1.4 and lt < go_at(i) + 0.5 then mood = "wide" end
      if lt > 58 and lt < 66 then mood = "happy" gy = gy - L.hop(lt + i * 0.3, 0.35, 26) end
      -- Inky's coffee goes everywhere (and he looks at it)
      local coffee = lt < arrive + 9 and not (i == 3 and lt > arrive - 0.4)
      if i == 3 and lt > arrive - 0.4 and lt < arrive + 2 then mood, lx, ly = "wide", 0, 1 end
      st.seat[i] = {gx, gy, lx, ly, mood, coffee}
    end
  end
  -- the director walks in last, to the front
  if lt > 21 then
    local k = prog(lt, 21, 25)
    local hop = (lt > 56.5 and lt < 66) and L.hop(lt, 0.4, 36) or 0
    st.director = {lerp(-60, DIRECTOR[1], k), DIRECTOR[2] - hop, 0, (lt > 56.5 and lt < 66) and 0.9 or nil}
  end
  if lt > 62 then
    st.screen = "pad"
    st.clock = string.format("T-00:%02d", floor(22 + (len - lt)))
  end
  room(lt, st)
  -- the sleeper's Zzz, the paper ball, the words
  if lt > 22 then
    local P = POLL_T[SLEEPER]
    local sx, sy = seat_pos(SLEEPER)
    if lt < go_at(SLEEPER) - 1.4 then
      for k = 0, 2 do
        local f = (S.t * 0.5 + k / 3) % 1
        G:text("z", sx + 20 + f * 30, sy - 40 - f * 50, floor(18 + f * 16), {1, 1, 1}, 1 - f, "left", 40)
      end
    end
    if lt > P + 2 and lt < P + 3 then
      -- Inky throws: from his seat across to Clyde's
      local ix, iy = seat_pos(3)
      local f = lt - (P + 2)
      lg.setColor(0.95, 0.95, 0.92, 1)
      lg.circle("fill", lerp(ix, sx, f), lerp(iy, sy, f) - sin(f * pi) * 90, 8, 10)
    end
  end
  for i = 1, #POLL do
    local sx, sy = seat_pos(i)
    local g = go_at(i)
    if lt > g and lt < g + 2.4 then G:say(POLL[i] .. ": GO!", sx, sy - 40, 30, L.window(lt, g, g + 2.4, 0.2)) end
    if lt > POLL_T[i] + 0.2 and lt < g then G:say(POLL[i] .. "?", DIRECTOR[1], DIRECTOR[2] - 56, 20, L.window(lt, POLL_T[i] + 0.2, g, 0.2)) end
  end
  local sx, sy = seat_pos(3)
  if lt > 14 + 3 * 1.4 - 0.4 and lt < 14 + 3 * 1.4 + 2 then G:say("OOPS!", sx, sy - 40, 22, 1) end
  if lt > 56.5 and lt < 62 then G:say("WE ARE GO FOR LAUNCH!", DIRECTOR[1], DIRECTOR[2] - 60, 26, L.window(lt, 56.5, 62, 0.3)) end
end
CAM.control = function(lt, len)
  local keys = {{0, 384, 512, 1}, {16, 384, 512, 1}, {20, 200, 560, 1.5}, {24, 384, 820, 1.3}, {26, 384, 820, 1.3}}
  for i = 1, #POLL do
    local sx, sy = seat_pos(i)
    local t0 = POLL_T[i]
    keys[#keys + 1] = {t0 + 0.9, sx + 50, sy - 10, 2.0}
    keys[#keys + 1] = {POLL_T[i + 1] - 0.1, sx + 50, sy - 10, 2.0}
  end
  keys[#keys + 1] = {57.5, 384, 512, 1}
  keys[#keys + 1] = {62, 384, 512, 1}
  keys[#keys + 1] = {66, 384, 300, 1.1}
  keys[#keys + 1] = {70, 384, 290, 1.12}
  return L.shot(lt, keys, W, H)
end
CUES.control = {{2.5, "clunk"}, {4.5, "clunk"}, {6.5, "clunk"}, {9, "chime"}, {56.5, "cheer"}, {58, "power"}}
for i = 1, #POLL do
  CUES.control[#CUES.control + 1] = {go_at(i), "ding"}
  CUES.control[#CUES.control + 1] = {14 + i * 1.4, "pop", 0.4}
end
CUES.control[#CUES.control + 1] = {POLL_T[SLEEPER] + 3, "boing"}
CUES.control[#CUES.control + 1] = {14 + 3 * 1.4 - 0.4, function()
  local x, y = seat_pos(3)
  for i = 1, 30 do G:spark(x + 30, y, (G.R:random() - 0.5) * 260, -120 - G.R:random() * 200, 0.9, {0.45, 0.28, 0.12}, 5, 600) end
  C.sfx("splash", 0.6)
end}

-- ------------------------------------------------------------------ Launch
local function launch_room_cut(lt)
  -- the room, cheering, the big screen following the rocket up
  local st = {go = {}, seat = {}, banks = 3, dark = 0}
  for i = 1, #POLL do
    st.go[i] = true
    local sx, sy = seat_pos(i)
    st.seat[i] = {sx, sy - L.hop(lt + i * 0.3, 0.35, 26), 0, -1, "happy"}
  end
  st.director = {DIRECTOR[1], DIRECTOR[2] - L.hop(lt, 0.4, 36), 0, 0.9}
  st.screen = "replay"
  st.replay = function()
    G:gradient(40, 120, 728, 400, {0.02, 0.03, 0.12}, {0.15, 0.25, 0.55})
    local ry = 360 - ((lt * 40) % 260)
    lg.push()
    lg.translate(384, ry)
    lg.scale(0.2, 0.2)
    rocket(0, 0, 1)
    lg.pop()
    C.fx.glow(384, ry + 20, 20, 40, 1, 0.7, 0.3, 0.9)
  end
  room(lt, st)
  G:say("GO, BABY, GO!", 210, 500, 24, 1)
end

function D.launch(lt, len)
  if lt > 72 and lt < 78 then
    launch_room_cut(lt)
    return
  end
  if lt > 44 and lt < 56 then
    -- riding along: the rocket in the middle, the clouds streaming down past it, the sky going dark
    local k = lin(lt, 44, 56)
    G:gradient(0, 0, W, H, mix({0.3, 0.5, 0.9}, {0.02, 0.03, 0.1}, k), mix({0.6, 0.75, 1}, {0.1, 0.15, 0.4}, k))
    for i, s in ipairs(S.stars) do
      lg.setColor(1, 1, 1, s[3] * clamp(k * 2 - 1, 0, 1))
      lg.rectangle("fill", s[1], s[2], 2, 2)
    end
    for i, c in ipairs(S.streak) do
      local y = (c[2] + lt * c[3]) % (H + 400) - 200
      lg.setColor(1, 1, 1, 0.85 * (1 - k))
      lg.ellipse("fill", c[1], y, c[4], c[4] * 0.35, 20)
      lg.ellipse("fill", c[1] + c[4] * 0.5, y - c[4] * 0.15, c[4] * 0.6, c[4] * 0.3, 20)
    end
    local ry = 640 + sin(lt * 3) * 4
    for i = 1, 3 do C.fx.glow(384, ry + 60 + i * 30, 30 - i * 5, 60, 1, 0.6 + i * 0.1, 0.25, 0.9) end
    lg.push()
    lg.translate(384, ry)
    lg.scale(0.6, 0.6)
    rocket(0, 0, 1)
    lg.pop()
    G:plate("MACH 1", 160, 30, 0xffffff, L.window(lt, 47, 52, 0.6))
    return
  end
  if lt >= 56 then
    -- high up: the sky gone dark, the Earth curving away, the first stage falling off
    local k2 = clamp((lt - 56) / 6, 0, 1)
    if not art("high") then
      G:gradient(0, 0, W, H, {0.0, 0.0, 0.04}, mix({0.2, 0.35, 0.7}, {0.05, 0.08, 0.25}, k2))
      for i, s in ipairs(S.stars) do
        lg.setColor(1, 1, 1, s[3] * k2)
        lg.rectangle("fill", s[1], s[2], 2, 2)
      end
      lg.setColor(0.1, 0.3, 0.7, 1)
      lg.circle("fill", 384, 1900, 1050, 96)
    end
    local sep = lt > 62
    local climb = lin(lt, 78, 90)
    local ry = 520 + sin(lt * 0.5) * 6 - climb ^ 1.5 * 520
    local sc = 0.45 * (1 - climb * 0.6)
    if sep then
      local f = lt - 62
      if f < 14 then
        lg.push()
        lg.translate(384 + f * 6, 520 + 120 + f * f * 6)
        lg.rotate(f * 0.3)
        lg.setColor(0.9, 0.9, 0.9, 1)
        lg.rectangle("fill", -20, -60, 40, 120)
        lg.setColor(0.1, 0.1, 0.12, 1)
        lg.rectangle("fill", -20, -10, 40, 6)
        lg.pop()
      end
      lg.push()
      lg.translate(384, ry)
      lg.scale(sc, sc)
      lg.translate(-384, -870)
      lg.setColor(0.95, 0.95, 0.95, 1)
      lg.rectangle("fill", 384 - 32, 870 - 420, 64, 120)
      lg.polygon("fill", 384 - 32, 450, 384 + 32, 450, 384 + 16, 400, 384 - 16, 400)
      if lt < 80 then
        lg.polygon("fill", 384 - 16, 400, 384 + 16, 400, 384, 350)
        lg.setColor(0.8, 0.15, 0.12, 1)
        lg.rectangle("fill", 384 - 3, 290, 6, 60)
      end
      lg.pop()
      -- the second stage's fire: lit at 64, roaring
      local fire = lin(lt, 63.5, 65)
      C.fx.glow(384, ry - 120 * sc / 0.45, 24 + 20 * fire, 50 + 60 * fire, 1, 0.7, 0.3, 0.8)
      -- the escape tower going off on its own
      if lt > 80 and lt < 88 then
        local f2 = lt - 80
        local tx, ty = 384 + f2 * 40, ry - 230 * sc / 0.45 - f2 * 90
        lg.setColor(0.8, 0.15, 0.12, 1)
        lg.rectangle("fill", tx - 3, ty - 30, 6, 30)
        C.fx.glow(tx, ty + 6, 10, 20, 1, 0.8, 0.4, 0.8)
      end
    else
      lg.push()
      lg.translate(384, ry)
      lg.scale(0.45, 0.45)
      lg.translate(-384, -870 + 300)
      rocket(384, 870, 1.15)
      lg.pop()
      C.fx.glow(384, ry + 160, 40, 90, 1, 0.65, 0.25, 0.9)
    end
    if sep then G:caption("STAGING", 160, 56, 0x8ab4ff, L.window(lt, 62.5, 70, 0.8)) end
    G:plate("TOWER JETTISON", 200, 28, 0xffffff, L.window(lt, 80.2, 85, 0.6))
    return
  end
  local up = clamp(lt - 22, 0, 100)
  local k = clamp(up / 40, 0, 1)
  local painted = art("pad")
  if painted then
    -- the sky darkening as it climbs
    lg.setColor(0.04, 0.06, 0.2, k * 0.85)
    lg.rectangle("fill", 0, 0, W, H)
    lg.setColor(0.5, 0.1, 0.07, 1)
  else
    G:gradient(0, 0, W, H, mix({0.35, 0.6, 0.95}, {0.05, 0.08, 0.25}, k), mix({0.9, 0.85, 0.75}, {0.3, 0.35, 0.6}, k))
    lg.setColor(0.7, 0.15, 0.1, 1)
    lg.rectangle("fill", 520, 230, 50, 640)
    lg.setColor(0.5, 0.1, 0.07, 1)
  end
  -- the access arm: swinging back from the rocket before the count
  local arm = 1 - prog(lt, 3, 7)
  lg.rectangle("fill", 520 - 50 * arm, 420, 50 * arm + 2, 10)
  -- the rocket: rising, faster and faster
  local ry = 870 - (up > 0 and (up ^ 2) * 1.6 or 0)
  if ry > -600 then rocket(384, ry, 1.15) end
  if not painted then
    lg.setColor(0.45, 0.45, 0.48, 1)
    lg.rectangle("fill", 200, 870, 368, 40)
  end
  -- the count
  if lt > 8 and lt < 22 then
    local n = floor(22 - lt)
    G:caption(n > 0 and ("T MINUS " .. n) or "IGNITION", 160, 56, 0xffffff, 1)
  end
  if up > 0 and up < 8 then G:caption("LIFTOFF!", 160, 72, 0xffd23f, clamp((8 - up) / 2, 0, 1)) end
end
CAM.launch = function(lt)
  if lt > 44 and lt < 56 then return 384, 512, 1, 2.5 end
  if lt >= 56 then
    -- in close on the rocket, a cut back out for staging, closing in again as the second stage burns
    local x, y, z = L.shot(lt, {{56, 384, 512, 1}, {61.8, 384, 560, 1.7}, {62, 384, 512, 1, "cut"}, {66, 384, 512, 1},
                                {71, 384, 470, 1.5}, {78, 384, 512, 1}}, W, H)
    return x, y, z, (lt > 62 and lt < 63) and 6 or ((lt > 64 and lt < 70) and 2 or 0)
  end
  local x, y, z = L.shot(lt, {{0, 384, 512, 1}, {8, 384, 560, 1.15}, {20, 384, 780, 1.8}, {21, 384, 512, 1, "cut"}}, W, H)
  local shake = (lt > 21 and lt < 36) and 9 * (1 - (lt - 21) / 15) or 0
  return x, y, z, shake
end
CUES.launch = {{3, "clunk"}, {21, "boom"}, {21, "jet"}, {28, "jet", 0.6}, {34, "boom", 0.35}, {38, "cheer", 0.5}, {44, "whoosh"},
               {50, "whoosh", 0.5}, {56, "chime", 0.5}, {62, "boom", 0.5}, {64, "jet", 0.6}, {72, "cheer"}, {80, "pop"}}
for t = 9, 21 do CUES.launch[#CUES.launch + 1] = {t, "tick", 0.5} end

-- ------------------------------------------------------------------ Orbit: the job outside
local SC = 1.3                              -- the station's size
local function station_xy(lt)
  local sx
  if lt < 14 then sx = lerp(-260, 384, 1 - (1 - lin(lt, 0, 14)) ^ 2)
  elseif lt < 80 then sx = 384 + sin((lt - 14) * 0.06) * 10
  else sx = lerp(384 + sin(66 * 0.06) * 10, 1100, lin(lt, 80, 90) ^ 2) end
  return sx, 330 + sin(lt * 0.1) * 12
end
-- the folded wing's hinge, where Pac-Man works (in the station's own coordinates, then the picture's)
local WING = {170, -14}
local function wing_xy(lt)
  local sx, sy = station_xy(lt)
  return sx + WING[1] * SC, sy + WING[2] * SC
end
local function hatch_xy(lt)
  local sx, sy = station_xy(lt)
  return sx + 80 * SC, sy
end

-- the station: truss, modules, the solar wings (the outer right one unfolding: k 0 to 1), its lights
local function iss(lt, unfold, lights, window_mood)
  local sx, sy = station_xy(lt)
  lg.push()
  lg.translate(sx, sy)
  lg.scale(SC, SC)
  lg.rotate(0.03)
  lg.setColor(0.7, 0.7, 0.72, 1)
  lg.rectangle("fill", -190, -6, 380, 12)
  lg.setColor(0.85, 0.85, 0.88, 1)
  lg.rectangle("fill", -40, -24, 80, 48, 10, 10, 6)
  lg.rectangle("fill", 40, -16, 46, 32, 8, 8, 6)
  lg.rectangle("fill", -84, -14, 44, 28, 8, 8, 6)
  -- the docking port at the left end
  lg.setColor(0.6, 0.6, 0.64, 1)
  lg.rectangle("fill", -200, -10, 12, 20, 3, 3, 4)
  -- the hatch (where Pac-Man comes out)
  local open = lt > 16 and lt < 58
  lg.setColor(open and 0.1 or 0.6, open and 0.1 or 0.6, open and 0.14 or 0.64, 1)
  lg.circle("fill", 86, 0, 9, 14)
  -- the window: a ghost looking out
  lg.setColor(0.08, 0.1, 0.2, 1)
  lg.circle("fill", 0, -2, 14, 18)
  L.ghost(0, 0, 9, GH[2], S.t, sin(S.t * 0.7), 0.3, window_mood)
  lg.setColor(0.75, 0.75, 0.8, 1)
  lg.setLineWidth(3)
  lg.circle("line", 0, -2, 14, 18)
  for _, wx in ipairs({-170, -120, 120, 170}) do
    local k = wx == 170 and unfold or 1
    for side = -1, 1, 2 do
      local n = floor(k * 6 + 0.001)
      if n == 0 then
        lg.setColor(0.5, 0.5, 0.55, 1)
        lg.rectangle("fill", wx - 18, side < 0 and -24 or 14, 36, 10)
      end
      for j = 0, n - 1 do
        local py = side < 0 and (-14 - (j + 1) * 11) or (14 + j * 11)
        lg.setColor(0.15, 0.2, 0.5, 1)
        lg.rectangle("fill", wx - 18, py, 36, 11)
        lg.setColor(0.8, 0.65, 0.2, 0.6)
        lg.rectangle("fill", wx - 18, py, 36, 1)
      end
    end
  end
  -- the lights: on once the wing is fixed
  if lights then
    for i, p in ipairs({{-60, -20}, {60, -12}, {-150, 0}, {150, 0}, {20, 20}}) do
      if floor(S.t * 2 + i) % 3 ~= 0 then
        lg.setColor(i % 2 == 0 and 1 or 0.3, i % 2 == 0 and 0.3 or 1, 0.3, 1)
        lg.circle("fill", p[1], p[2], 3, 8)
      end
    end
  end
  lg.pop()
end

-- where Pac-Man is, outside: out of the hatch, to the wing, after the wrench, back
local WRENCH_V = {5, -13}
local function wrench_xy(lt)
  local wx, wy = wing_xy(40)
  if lt < 40 then return wing_xy(lt) end
  local f = min(lt, 49) - 40
  return wx + 20 + WRENCH_V[1] * f, wy - 30 + WRENCH_V[2] * f
end
local function spacewalker(lt)
  if lt < 17 or lt > 58 then return nil end
  local hx, hy = hatch_xy(lt)
  local wx, wy = wing_xy(lt)
  wx, wy = wx + 52, wy - 30
  if lt < 26 then
    local k = prog(lt, 17, 26)
    return lerp(hx, wx, k) + sin(lt) * 6, lerp(hy, wy, k) - sin(k * pi) * 40
  elseif lt < 43 then
    return wx + sin(lt * 1.3) * 4, wy + cos(lt) * 3
  elseif lt < 52 then
    local ex, ey = wrench_xy(49)
    local k = prog(lt, 43, 49)
    return lerp(wx, ex - 10, k), lerp(wy, ey + 20, k)
  else
    local ex, ey = wrench_xy(49)
    local k = prog(lt, 52, 58)
    return lerp(ex - 10, hx, k), lerp(ey + 20, hy, k)
  end
end

function D.orbit(lt, len)
  if not art("orbit") then
    lg.setColor(0, 0, 0.02, 1)
    lg.rectangle("fill", 0, 0, W, H)
    stars()
  end
  -- sunrise over the edge
  local sr = clamp((lt - 54) / 6, 0, 1) * clamp((76 - lt) / 8, 0, 1)
  if sr > 0 then
    C.fx.glow(560, 610, 340, 130, 1, 0.85, 0.6, 0.65 * sr)
    C.fx.glow(560, 610, 90, 90, 1, 1, 0.9, sr)
  end
  -- Houston, down there: a beacon on the coast
  if lt > 58 and lt < 74 then
    local p = (S.t * 0.8) % 1
    lg.setColor(1, 0.85, 0.3, (1 - p) * L.window(lt, 58, 74, 1))
    lg.setLineWidth(3)
    lg.circle("line", 430, 790, 10 + p * 50, 24)
    lg.setColor(1, 0.85, 0.3, L.window(lt, 58, 74, 1))
    lg.circle("fill", 430, 790, 6, 10)
    -- Houston answers the wave: three big flashes from the ground
    for _, ft in ipairs({63.5, 65, 66.5}) do
      if lt > ft and lt < ft + 1 then
        lg.setBlendMode("add")
        C.fx.glow(430, 790, 280, 200, 1, 0.85, 0.4, 1 - (lt - ft))
        lg.setBlendMode("alpha")
      end
    end
  end
  local unfold = lin(lt, 29, 39)
  local happy = (lt > 41 and lt < 50) or (lt > 62 and lt < 67) or (lt > 78 and lt < 82)
  iss(lt, unfold, lt > 39, happy and "happy" or nil)
  -- the cargo ship coming in to dock, thrusters puffing
  if lt > 66 then
    local sx, sy = station_xy(lt)
    local px, py = sx - 200 * SC, sy
    local k = 1 - (1 - lin(lt, 66, 78)) ^ 2
    local cx = lt < 78 and lerp(-120, px - 34, k) or px - 34
    lg.push()
    lg.translate(cx, py)
    lg.scale(1.6, 1.6)
    lg.translate(-cx, -py)
    lg.setColor(0.9, 0.9, 0.92, 1)
    lg.rectangle("fill", cx - 34, py - 18, 56, 36, 8, 8, 6)
    lg.polygon("fill", cx + 22, py - 12, cx + 34, py - 6, cx + 34, py + 6, cx + 22, py + 12)
    lg.setColor(0.15, 0.2, 0.5, 1)
    lg.rectangle("fill", cx - 70, py - 8, 34, 16)
    lg.rectangle("fill", cx - 28, py - 26, 30, 8)
    lg.pop()
    if lt > 78 and lt < 79 then C.fx.glow(px - 6, py, 50, 50, 1, 1, 0.8, 1 - (lt - 78)) end
  end
  -- the tether and the spacewalker
  local ax, ay = spacewalker(lt)
  if ax then
    local hx, hy = hatch_xy(lt)
    lg.setColor(0.9, 0.9, 0.9, 0.8)
    lg.setLineWidth(2)
    lg.line(hx, hy, (hx + ax) / 2 + 20, (hy + ay) / 2 + 30, ax, ay - 10)
    lg.push()
    lg.translate(ax, ay)
    lg.rotate(sin(lt * 0.2) * 0.4)
    astronaut(0, 0, 0.9, 1, S.t * 0.3)
    lg.pop()
    -- his wrench, until it gets away; then floating, turning, until he catches it
    if lt < 40 or lt > 49 then
      lg.setColor(0.7, 0.7, 0.75, 1)
      lg.setLineWidth(4)
      lg.line(ax + 26, ay - 4, ax + 44, ay - 18)
    end
  end
  if lt >= 40 and lt <= 49 then
    local ex, ey = wrench_xy(lt)
    lg.push()
    lg.translate(ex, ey)
    lg.rotate(lt * 4)
    lg.setColor(0.7, 0.7, 0.75, 1)
    lg.rectangle("fill", -14, -3, 28, 6, 2, 2, 4)
    lg.circle("line", 16, 0, 6, 10)
    lg.pop()
  end
  if lt > 40.5 and lt < 43 then G:say("MY WRENCH!", ax, ay - 70, 22, 1) end
  if lt > 49 and lt < 52 then G:say("GOT IT!", ax, ay - 70, 24, 1) end
  if lt > 38.5 and lt < 41 then G:say("FIXED!", ax, ay - 70, 24, 1) end
  local sx, sy = station_xy(lt)
  if lt > 62 and lt < 67 then G:say("HI, HOUSTON!", sx, sy - 40, 22, L.window(lt, 62, 67, 0.3)) end
  if lt > 78 and lt < 81.5 then G:say("DOCKED!", sx, sy - 40, 22, 1) end
  G:plate("THAT'S TEXAS DOWN THERE", 160, 28, 0xffffff, L.window(lt, 59, 70, 1.2))
end
CAM.orbit = function(lt)
  local sx, sy = station_xy(lt)
  if lt < 14 then return L.shot(lt, {{0, 384, 400, 1}, {14, sx, sy + 40, 1.2}}, W, H) end
  if lt > 80 then return L.shot(lt, {{80, 384, 512, 1.1}, {86, 384, 512, 1}}, W, H) end
  local wx, wy = wing_xy(lt)
  local ex, ey = wrench_xy(49)
  return L.shot(lt, {{14, sx, sy + 40, 1.2}, {18, sx + 100, sy + 10, 1.6}, {26, wx + 30, wy - 30, 1.7}, {33, wx + 30, wy - 20, 2.0}, {40, wx + 50, wy - 40, 2.4},
                     {44, ex - 60, ey, 1.6}, {50, ex - 40, ey + 20, 1.9}, {54, sx + 120, sy - 40, 1.5}, {57, sx, sy + 80, 1.3}, {60, 384, 512, 1}, {68, 384, 512, 1},
                     {70, sx - 200 * SC - 80, sy, 1.7}, {78, sx - 200 * SC - 30, sy, 2.1}, {80, 384, 512, 1.1}}, W, H)
end
CUES.orbit = {{63.5, "chime", 0.4}, {65, "chime", 0.45}, {66.5, "chime", 0.5}, {16.5, "clunk"}, {39, "chime"}, {39, "ding"}, {40, "boing"}, {49, "ding"}, {78, "clunk"}, {78.2, "chime"}, {79, "cheer", 0.6}}
-- the cargo ship's thrusters, nudging it in to dock
for k, t in ipairs({67, 69.5, 72, 74, 75.8, 77.2}) do
  CUES.orbit[#CUES.orbit + 1] = {t, "pop", 0.25 + k * 0.03}
  CUES.orbit[#CUES.orbit + 1] = {t, function()
    local sx, sy = station_xy(t)
    local px = sx - 200 * SC
    local k2 = 1 - (1 - lin(t, 66, 78)) ^ 2
    local cx = lerp(-120, px - 34, k2)
    for i = 1, 8 do G:puff(cx - 72, sy + (G.R:random() - 0.5) * 14, {1, 1, 1}, 0, -120 - G.R:random() * 80, 0.8, 9, 0.6) end
  end}
end
for t = 290, 385, 4 do
  CUES.orbit[#CUES.orbit + 1] = {t / 10, function()
    local x, y = wing_xy(t / 10)
    for i = 1, 6 do G:spark(x + 10, y - 20, (G.R:random() - 0.5) * 160, (G.R:random() - 0.5) * 160, 0.4, {1, 0.9, 0.5}, 5, 0, true) end
  end}
end
for t = 660, 770, 7 do
  CUES.orbit[#CUES.orbit + 1] = {t / 10, function()
    local sx, sy = station_xy(t / 10)
    local k = 1 - (1 - lin(t / 10, 66, 78)) ^ 2
    local cx = lerp(-120, sx - 200 * SC - 34, k)
    G:puff(cx - 40, sy + (G.R:random() - 0.5) * 20, {0.9, 0.9, 1}, 0, -60, 0.8, 6, 0.5)
  end}
end

-- ------------------------------------------------------------------ The Moon: landing, walking, driving, golf
local LX, LY = 200, 760                     -- the lander once down
local FEET = 860                            -- where boots touch
local function lander_y(lt)
  return lerp(-180, LY, 1 - (1 - lin(lt, 0, 16)) ^ 2.2)
end
local function ascent_y(lt) return lt < 84 and 0 or -((lt - 84) ^ 2) * 26 end
local function lander(x, y, lift, hatch)
  -- the descent stage, legs and pads
  lg.setColor(0.94, 0.78, 0.29, 1)
  lg.polygon("fill", x - 60, y - 40, x + 60, y - 40, x + 70, y, x - 70, y)
  lg.setColor(0.42, 0.29, 0.06, 0.35)
  for i = 0, 9 do lg.line(x - 60 + i * 12, y - 38, x - 62 + i * 13, y - 2) end
  lg.setColor(0.78, 0.78, 0.8, 1)
  lg.setLineWidth(5)
  for d = -1, 1, 2 do
    lg.line(x + d * 60, y - 10, x + d * 100, y + 50)
    lg.ellipse("fill", x + d * 100, y + 52, 14, 4, 10)
  end
  -- the ladder on the left leg
  lg.setLineWidth(2)
  for i = 0, 5 do
    local f = i / 5
    lg.line(x - 60 - f * 40 - 6, y - 10 + f * 60, x - 60 - f * 40 + 6, y - 10 + f * 60)
  end
  -- the ascent stage (it leaves)
  local ay = y + lift
  lg.setColor(0.8, 0.8, 0.84, 1)
  lg.polygon("fill", x - 44, ay - 40, x + 44, ay - 40, x + 30, ay - 110, x - 30, ay - 110)
  lg.setColor(hatch and 0.02 or 0.1, hatch and 0.02 or 0.1, hatch and 0.04 or 0.15, 1)
  lg.polygon("fill", x - 14, ay - 90, x + 14, ay - 90, x + 10, ay - 70, x - 10, ay - 70)
  lg.setColor(0.78, 0.78, 0.8, 1)
  lg.rectangle("fill", x - 2, ay - 140, 4, 32)
  lg.ellipse("fill", x, ay - 140, 16, 5, 10)
end

-- Pac-Man's walk, as (x, y of the suit's middle, facing)
local HOP0, HOPP = 28, 2.4                  -- the hops: from 28 s, one every 2.4 s
local function pac_moon(lt)
  if lt < 21 then return nil end
  if lt < 23 then return lerp(LX, LX - 60, prog(lt, 21, 23)), lerp(LY - 90, LY - 70, prog(lt, 21, 23)), -1 end
  if lt < 27.5 then return lerp(LX - 66, LX - 110, prog(lt, 23, 27.5)), lerp(LY - 70, FEET - 48, prog(lt, 23, 27.5)), -1 end
  if lt < HOP0 then return LX - 110, FEET - 48, 1 end
  if lt < 48 then
    local x = lerp(LX - 110, 440, lin(lt, HOP0, 48))
    return x, FEET - 66 - L.hop(lt - HOP0, HOPP, 170), 1
  end
  if lt < 56 then return 440, FEET - 48, 1 end
  if lt < 66 then return nil end            -- (on the rover)
  if lt < 80 then return 400, FEET - 48, 1 end
  if lt < 83 then return lerp(400, LX, prog(lt, 80, 83)), FEET - 48 - L.hop(lt, 0.8, 50), -1 end
  return nil
end
local function ghost_moon(lt)
  if lt < 30 then return nil end
  if lt < 34 then return lerp(LX - 60, LX - 120, prog(lt, 30, 34)), lerp(LY - 70, FEET - 30, prog(lt, 30, 34)) end
  if lt < 50 then
    local x = lerp(LX - 120, 520, lin(lt, 34, 50))
    return x, FEET - 44 - L.hop(lt - 34, HOPP, 140)
  end
  if lt < 56 then return 520, FEET - 30 end
  if lt < 66 then return nil end
  if lt < 80 then return 470, FEET - 30 end
  if lt < 83.5 then return lerp(470, LX, prog(lt, 80, 83.5)), FEET - 30 - L.hop(lt, 0.7, 40) end
  return nil
end
local function rover_x(lt)
  if lt < 58 then return LX + 120 end
  if lt < 62 then return lerp(LX + 120, 680, prog(lt, 58, 62)) end
  if lt < 66 then return lerp(680, 520, prog(lt, 62, 66)) end
  return 520
end

function D.moon(lt, len)
  local painted = art("moon")
  if not painted then
    lg.setColor(0, 0, 0.01, 1)
    lg.rectangle("fill", 0, 0, W, H)
    stars()
  end
  -- Earthrise
  local er = clamp((lt - 4) / 30, 0, 1)
  local ey = lerp(640, 300, ease(er))
  C.fx.glow(560, ey, 120, 120, 0.4, 0.7, 1, 0.4)
  lg.setColor(0.15, 0.4, 0.85, 1)
  lg.circle("fill", 560, ey, 70, 40)
  lg.setColor(0.3, 0.6, 0.3, 1)
  lg.ellipse("fill", 540, ey - 10, 24, 18, 12)
  lg.setColor(1, 1, 1, 0.6)
  lg.ellipse("fill", 580, ey + 20, 26, 8, 12)
  lg.setColor(0, 0, 0.01, 0.6)
  lg.arc("fill", "pie", 560, ey, 71, -pi / 2, pi / 2, 20)
  -- the ground in front of the rising Earth
  if painted then
    S.ground_q = S.ground_q or lg.newQuad(0, 640, W, H - 640, W, H)
    lg.setColor(1, 1, 1, 1)
    lg.draw(S.art.moon, S.ground_q, 0, 640)
  else
    G:gradient(0, 640, W, H, {0.55, 0.55, 0.57}, {0.4, 0.4, 0.42})
  end
  -- the footprints: one at every landing, his and the ghost's
  lg.setColor(0.32, 0.32, 0.35, 1)
  if lt > 27.5 then lg.ellipse("fill", LX - 104, FEET + 4, 12, 4, 10) end
  for n = 1, 9 do
    local t = HOP0 + n * HOPP
    if t < lt and t < 48 then
      local x = lerp(LX - 110, 440, lin(t, HOP0, 48))
      lg.ellipse("fill", x - 6, FEET + 4, 10, 3.5, 10)
      lg.ellipse("fill", x + 8, FEET + 8, 10, 3.5, 10)
    end
    local tg = 34 + n * HOPP
    if tg < lt and tg < 50 then
      local x = lerp(LX - 120, 520, lin(tg, 34, 50))
      lg.ellipse("fill", x, FEET + 18, 9, 3, 10)
    end
  end
  -- the rover's tracks
  if lt > 58 then
    local far = rover_x(min(lt, 62))
    lg.setColor(0.36, 0.36, 0.4, 1)
    lg.rectangle("fill", LX + 120, FEET + 36, far - LX - 120, 3)
    lg.rectangle("fill", LX + 120, FEET + 50, far - LX - 120, 3)
  end
  -- the lander: coming down on its fire, then standing
  local ly = lander_y(lt)
  if lt < 16.2 then C.fx.glow(LX, ly + 20, 30, 70, 1, 0.75, 0.35, 0.9) end
  if lt > 84 and lt < 90 then C.fx.glow(LX, ly + ascent_y(lt) - 30, 24, 60, 1, 0.75, 0.35, 0.9) end
  lander(LX, ly, ascent_y(lt), lt > 20 and lt < 84)
  -- the flags: planted, with a puff
  for i, f in ipairs({{440, 48}, {520, 52}}) do
    if lt > f[2] then
      local fx = f[1] + 30
      local g = prog(lt, f[2], f[2] + 0.6)
      local top = lerp(FEET, 720, g)
      lg.setColor(0.8, 0.8, 0.82, 1)
      lg.rectangle("fill", fx - 2, top, 4, FEET - top)
      if g >= 1 then
        if i == 1 then
          for k = 0, 6 do
            if k % 2 == 0 then lg.setColor(0.8, 0.11, 0.17, 1) else lg.setColor(0.97, 0.97, 0.95, 1) end
            lg.rectangle("fill", fx + 2, 722 + k * 6, 60, 6)
          end
          lg.setColor(0.14, 0.2, 0.52, 1)
          lg.rectangle("fill", fx + 2, 722, 24, 24)
        else
          lg.setColor(0.0, 0.16, 0.41, 1)
          lg.rectangle("fill", fx + 2, 722, 20, 42)
          lg.setColor(0.97, 0.97, 0.95, 1)
          lg.rectangle("fill", fx + 22, 722, 40, 21)
          lg.setColor(0.75, 0.04, 0.19, 1)
          lg.rectangle("fill", fx + 22, 743, 40, 21)
          lg.setColor(1, 1, 1, 1)
          L.star(fx + 12, 743, 7)
        end
      end
    end
  end
  -- the rover: unfolding from the lander's side, driving with the two of them aboard, bouncing
  if lt > 54 then
    local rx = rover_x(lt)
    local unf = prog(lt, 54, 56)
    local bounce = (lt > 58 and lt < 66) and abs(sin(lt * 7)) * 10 or 0
    local ry = FEET + 20 - bounce
    lg.push()
    lg.translate(rx, ry)
    lg.scale(1.5, 1.5)
    lg.translate(-rx, -ry)
    lg.setColor(0.75, 0.75, 0.78, 1)
    lg.rectangle("fill", rx - 60 * unf, ry - 24, 120 * unf, 14, 4, 4, 4)
    lg.setColor(0.25, 0.25, 0.28, 1)
    for _, wx in ipairs({-46, 46}) do lg.circle("fill", rx + wx * unf, ry, 14 * unf + 2, 14) end
    lg.setColor(0.8, 0.8, 0.82, 1)
    lg.rectangle("fill", rx + 30 * unf, ry - 70 * unf, 3, 46 * unf)
    lg.ellipse("fill", rx + 31 * unf, ry - 72 * unf, 16 * unf, 5 * unf, 12)
    if lt > 56 and lt < 66 then
      astronaut(rx - 24, ry - 60, 0.7, rx > 600 and -1 or 1, S.t * 0.3)
      space_ghost(rx + 6, ry - 46, 18, GH[1], S.t, 1, 0, "happy")
    end
    lg.pop()
    -- moon dust off the wheels
    if lt > 58 and lt < 66 and G.R:random() < 0.6 then
      G:puff(rx - 70, FEET + 30, {0.72, 0.72, 0.74}, 30, (rx > 600 and 1 or -1) * -90, 1.4, 14, 0.5)
    end
  end
  -- the golf shot: the swing, the ball gone up, and up... and down on Blinky's helmet
  local px, py, pd = pac_moon(lt)
  local gx, gy = ghost_moon(lt)
  if lt > 66 and lt < 70 then
    local a = lt < 68 and lerp(-0.4, -2.2, prog(lt, 66, 67.6)) or lerp(-2.2, 1.4, prog(lt, 68, 68.3))
    lg.setColor(0.8, 0.8, 0.85, 1)
    lg.setLineWidth(4)
    lg.line(px + 20, py, px + 20 + cos(a) * 50, py + 20 + sin(a) * 50)
    if lt < 68 then
      lg.setColor(1, 1, 1, 1)
      lg.circle("fill", px + 50, FEET - 4, 5, 10)
    end
  end
  if lt > 68 and lt < 71.5 then
    local f = lt - 68
    lg.setColor(1, 1, 1, 1)
    lg.circle("fill", px + 50 + f * 30, FEET - 4 - f * 300, 5, 10)
  end
  if lt > 76.5 and lt < 78 and gx then
    local f = (lt - 76.5) / 1.5
    lg.setColor(1, 1, 1, 1)
    lg.circle("fill", gx, lerp(-20, gy - 30, f * f), 5, 10)
  end
  -- the two of them
  local looking_up = lt > 68.5 and lt < 78
  if gx then
    local mood = (lt > 78 and lt < 82) and "wide" or ((lt > 48 and lt < 56) and "happy" or nil)
    space_ghost(gx, gy, 34, GH[1], S.t, looking_up and 0.3 or 1, looking_up and -1 or 0, mood)
    if lt > 78 and lt < 82 then dizzy(gx, gy - 46, 30, S.t) end
  end
  if px then
    local open = (lt > 78 and lt < 82) and 0.9 or nil
    astronaut(px, py, 1.4, pd, S.t * 0.4, open)
  end
  if lt > 72 and lt < 76 then G:say("...?", px, py - 90, 26, 1) end
  if lt > 78 and lt < 81 and gx then G:say("BONK!", gx, gy - 70, 26, 1) end
  if lt > 52.5 and lt < 55 then G:say("TEXAS, TOO!", 520, FEET - 90, 22, 1) end
  G:plate("THE EAGLE HAS LANDED", 160, 30, 0xffffff, L.window(lt, 16.6, 22, 0.8))
  G:plate("ONE SMALL HOP FOR PAC-MAN", 160, 30, 0xffffff, L.window(lt, 28, 35, 1))
  G:plate("SEE YOU, MOON", 160, 30, 0xffffff, L.window(lt, 85, 89.5, 0.8))
end
CAM.moon = function(lt)
  local shake = (lt > 16 and lt < 16.6) and 8 or ((lt > 84 and lt < 85) and 5 or 0)
  if lt > 57 and lt < 65 then
    local x, y, z = L.shot(0, {{0, rover_x(lt), 790, 1.4}}, W, H)
    return x, y, z, shake
  end
  local x, y, z = L.shot(lt, {{0, 384, 512, 1}, {16, 384, 560, 1}, {18.5, 230, 790, 1.6}, {27, 170, 800, 1.7}, {30, 260, 790, 1.4},
                              {40, 380, 760, 1.5}, {48, 470, 760, 1.5}, {54, 420, 780, 1.35}, {57, rover_x(57), 790, 1.4}, {65, rover_x(65), 790, 1.4},
                              {68, 430, 790, 1.5}, {70, 440, 620, 1.3}, {76, 440, 620, 1.3}, {77.5, 450, 800, 1.6}, {81, 450, 800, 1.6},
                              {84, 384, 512, 1}}, W, H)
  return x, y, z, shake
end
CUES.moon = {{16, "clunk"}, {16, "boom", 0.4}, {20.5, "clunk"}, {27.6, "boing"}, {48, "pop"}, {52, "pop"}, {54, "clunk"},
             {68.1, "pew", 0.6}, {77.9, "boing"}, {84, "jet"}, {84, "boom", 0.5}}
for n = 1, 8 do
  CUES.moon[#CUES.moon + 1] = {HOP0 + n * HOPP, "boing", 0.3}
  CUES.moon[#CUES.moon + 1] = {HOP0 + n * HOPP, function()
    local x = lerp(LX - 110, 440, lin(HOP0 + n * HOPP, HOP0, 48))
    for i = 1, 8 do G:puff(x + (G.R:random() - 0.5) * 40, FEET + 6, {0.72, 0.72, 0.74}, 14, (G.R:random() - 0.5) * 160, 1.6, 12, 0.5) end
  end}
end
for t = 100, 160, 5 do
  CUES.moon[#CUES.moon + 1] = {t / 10, function()
    for i = 1, 3 do
      local s = G.R:random() < 0.5 and -1 or 1
      G:puff(LX + s * G.R:random() * 80, FEET + 10, {0.7, 0.7, 0.72}, 10, s * (80 + G.R:random() * 120), 1.6, 14, 0.5)
    end
  end}
end
for t = 580, 655, 5 do
  CUES.moon[#CUES.moon + 1] = {t / 10, function()
    local rx = rover_x(t / 10)
    G:puff(rx - 50, FEET + 20, {0.7, 0.7, 0.72}, 20, (G.R:random() - 0.5) * 60, 1.2, 10, 0.5)
  end}
end
for _, f in ipairs({{470, 48}, {550, 52}}) do
  CUES.moon[#CUES.moon + 1] = {f[2] + 0.6, function()
    for i = 1, 5 do G:puff(f[1], FEET, {0.7, 0.7, 0.72}, 10, (G.R:random() - 0.5) * 120, 1.2, 10, 0.5) end
  end}
end

-- ------------------------------------------------------------------ Splashdown
local function capsule_xy(lt)
  if lt < 14 then
    local k = 1 - (1 - lin(lt, 0, 14)) ^ 2
    return lerp(860, 420, k), lerp(-120, 260, k)
  end
  if lt < 44 then
    local k = lin(lt, 14, 44)
    return 420 + sin(lt * 0.6) * 18 * (1 - k), lerp(260, 680, k ^ 0.9)
  end
  return 420, 680 + sin(lt * 1.5) * 4
end
local function chute(px, py, s, cx, cy)
  for k = 0, 5 do
    if k % 2 == 0 then lg.setColor(0.9, 0.2, 0.2, 1) else lg.setColor(0.97, 0.97, 0.95, 1) end
    lg.arc("fill", "pie", px, py, 80 * s, pi + k * pi / 6, pi + (k + 1) * pi / 6, 6)
  end
  lg.setColor(0.8, 0.8, 0.8, 0.8)
  lg.setLineWidth(1.5)
  lg.line(px - 78 * s, py, cx - 10, cy - 50)
  lg.line(px + 78 * s, py, cx + 10, cy - 50)
end
local function heli_xy(lt)
  if lt < 56 then return W + 200, 300 end
  if lt < 62 then return lerp(W + 200, 470, 1 - (1 - lin(lt, 56, 62)) ^ 2), 300 + sin(lt) * 6 end
  if lt < 72 then return 470 + sin(lt * 0.8) * 6, 300 + sin(lt) * 6 end
  local k = lin(lt, 72, 79)
  return lerp(470, 150, k), lerp(300, 560, k)
end
function D.splash(lt, len)
  if not art("ocean") then
    G:gradient(0, 0, W, 640, {0.3, 0.55, 0.9}, {0.8, 0.9, 1})
    G:gradient(0, 640, W, H, {0.15, 0.4, 0.6}, {0.05, 0.25, 0.45})
  end
  for i = 0, 12 do
    lg.setColor(1, 1, 1, 0.25)
    local y = 660 + i * 28
    local x = ((i * 97 + S.t * 20) % (W + 100)) - 50
    lg.rectangle("fill", x, y, 60 + i * 4, 2)
  end
  local cx, cy = capsule_xy(lt)
  -- coming down: clouds going up past, gulls, the helicopter circling far off, waiting
  if lt > 18 and lt < 46 then
    for i, c in ipairs(S.streak) do
      local y = (c[2] - lt * c[3] * 0.25) % (H + 400) - 200
      if y < 600 then
        lg.setColor(1, 1, 1, 0.75 * L.window(lt, 18, 44, 2))
        lg.ellipse("fill", c[1], y, c[4], c[4] * 0.32, 20)
        lg.ellipse("fill", c[1] + c[4] * 0.45, y - c[4] * 0.14, c[4] * 0.55, c[4] * 0.28, 20)
      end
    end
  end
  if lt > 26 and lt < 40 then
    local fx = lerp(-80, W + 80, lin(lt, 26, 40))
    lg.setColor(0.95, 0.95, 0.98, 1)
    lg.setLineWidth(3)
    for i = 0, 4 do
      local bx, by = fx - i * 30, 520 + abs(i - 2) * 16 + sin(S.t * 7 + i) * 4
      local w = sin(S.t * 9 + i) * 6
      lg.line(bx - 12, by - 4 - w, bx, by, bx + 12, by - 4 - w)
    end
  end
  if lt > 22 and lt < 54 then
    local a = (lt - 22) * 0.35
    local hx, hy = 560 + cos(a) * 140, 520 + sin(a) * 30
    local sc = 0.3 + 0.08 * sin(a)
    lg.setColor(0.3, 0.35, 0.3, 1)
    lg.ellipse("fill", hx, hy, 60 * sc, 26 * sc, 14)
    lg.rectangle("fill", hx + 40 * sc * (cos(a + pi / 2) > 0 and 1 or -2.5), hy - 4 * sc, 100 * sc, 8 * sc)
    lg.setColor(0.2, 0.2, 0.2, 1)
    lg.setLineWidth(1.5)
    local b = sin(S.t * 40) * 90 * sc
    lg.line(hx - b, hy - 30 * sc, hx + b, hy - 30 * sc)
  end
  -- in the water: the dye, the rings, the collar
  if lt > 44 then
    local d = lin(lt, 44, 60)
    lg.setColor(0.3, 0.95, 0.5, 0.35 * d)
    lg.ellipse("fill", cx + 30, cy + 10, 60 + 200 * d, 16 + 40 * d, 30)
    for r = 0, 2 do
      local f = lin(lt, 44 + r * 0.6, 50 + r * 0.6)
      if f > 0 and f < 1 then
        lg.setColor(1, 1, 1, 0.6 * (1 - f))
        lg.setLineWidth(3)
        lg.ellipse("line", cx, cy + 6, 40 + f * 260, 8 + f * 50, 32)
      end
    end
    -- the chutes, collapsed on the water, sinking
    local f = lin(lt, 44, 50)
    for i = -1, 1 do
      lg.setColor(0.9, 0.2, 0.2, 0.8 * (1 - lin(lt, 50, 60)))
      lg.ellipse("fill", cx + 120 + i * 70, cy + 14, 40, 8 * (1 - f) + 4, 16)
    end
  end
  -- the re-entry fire
  if lt < 14 then
    local a = 1 - lin(lt, 10, 14)
    C.fx.glow(cx + 30, cy - 30, 80, 120, 1, 0.5, 0.15, 0.8 * a)
    C.fx.glow(cx, cy - 10, 50, 50, 1, 0.9, 0.6, a)
  end
  -- the parachutes: two drogues first, then the three mains blooming one, two, three
  if lt > 14 and lt < 44 then
    if lt < 19 then
      for i = -1, 1, 2 do chute(cx + i * 30, cy - 130, 0.35 * prog(lt, 14, 15), cx, cy) end
    end
    for i = -1, 1 do
      local bloom = prog(lt, 18.5 + (i + 1) * 0.9, 19.5 + (i + 1) * 0.9)
      if bloom > 0 then chute(cx + i * 110 * bloom, cy - 260 * bloom - abs(i) * 30, bloom, cx, cy) end
    end
  end
  -- the capsule (scorched from the fire, a window, the crew looking out once down)
  lg.setColor(0.25, 0.25, 0.3, 1)
  lg.polygon("fill", cx - 56, cy, cx + 56, cy, cx + 22, cy - 66, cx - 22, cy - 66)
  lg.setColor(0.4, 0.3, 0.22, 0.8)
  lg.polygon("fill", cx - 56, cy, cx + 56, cy, cx + 50, cy - 10, cx - 50, cy - 10)
  lg.setColor(0.6, 0.8, 0.95, 1)
  lg.circle("fill", cx, cy - 34, 12, 16)
  if lt > 44 then L.pac(cx, cy - 34, 9, 0, S.t, 0.6) end
  if lt > 52 then
    local k = prog(lt, 52, 54)
    lg.setColor(1, 0.85, 0.2, 1)
    lg.ellipse("fill", cx, cy + 4, 70 * k + 2, 14 * k + 1, 24)
  end
  -- the frogmen's raft
  if lt > 48 then
    local rx = lerp(W + 100, cx + 110, 1 - (1 - lin(lt, 48, 54)) ^ 2)
    lg.setColor(1, 0.5, 0.1, 1)
    lg.ellipse("fill", rx, cy + 12, 70, 18, 18)
    -- the frogmen: Clyde and Inky in their masks
    for k, who in ipairs({4, 3}) do
      L.ghost(rx - 26 + (k - 1) * 52, cy - 10, 18, GH[who], S.t + k, -1, 0, nil)
      lg.setColor(0.1, 0.12, 0.15, 0.7)
      lg.rectangle("fill", rx - 26 + (k - 1) * 52 - 15, cy - 18, 30, 10, 4, 4, 4)
    end
  end
  -- the helicopter: in, the basket down and up three times (one of the crew each time), away to the carrier
  local hx, hy = heli_xy(lt)
  if lt > 56 and lt < 80 then
    local s = lt > 72 and lerp(1, 0.45, lin(lt, 72, 79)) or 1
    if lt > 62 and lt < 72 then
      local cyc = (lt - 62) % 3.33 / 3.33
      local n = floor((lt - 62) / 3.33) + 1
      local depth = cyc < 0.5 and cyc * 2 or (1 - cyc) * 2
      local by = lerp(hy + 30, cy - 70, depth)
      lg.setColor(0.2, 0.2, 0.2, 1)
      lg.setLineWidth(2)
      lg.line(hx, hy + 20, hx, by)
      lg.setColor(0.85, 0.8, 0.2, 1)
      lg.rectangle("fill", hx - 26, by, 52, 24, 4, 4, 4)
      lg.setColor(0.6, 0.55, 0.1, 1)
      lg.setLineWidth(2)
      lg.line(hx - 26, by, hx, by - 30, hx + 26, by)
      if cyc > 0.5 then
        local wave = sin(S.t * 8) * 0.3
        if n == 1 then L.pac(hx, by - 14, 22, 0, S.t, 0.5)
        else L.ghost(hx, by - 16, 20, GH[n], S.t, 0, 0, "happy") end
        lg.setColor(1, 1, 1, 1)
        lg.circle("fill", hx + 24, by - 30 + wave * 20, 6, 8)
      end
    end
    lg.push()
    lg.translate(hx, hy)
    lg.scale(s * 1.4, s * 1.4)
    lg.setColor(0.3, 0.35, 0.3, 1)
    lg.ellipse("fill", 0, 0, 60, 26, 20)
    lg.rectangle("fill", 40, -8, 100, 10)
    lg.setColor(0.2, 0.2, 0.2, 1)
    lg.setLineWidth(3)
    local b = sin(S.t * 40) * 90
    lg.line(-b, -30, b, -30)
    lg.line(0, -30, 0, -20)
    lg.setColor(0.4, 0.6, 0.9, 1)
    lg.ellipse("fill", -30, -4, 20, 14, 12)
    lg.pop()
  end
  if lt > 54 and lt < 58 then G:say("WE'RE HOME!", cx, cy - 70, 24, 1) end
end
CAM.splash = function(lt)
  local cx, cy = capsule_xy(lt)
  if lt > 14 and lt < 44 then return L.shot(0, {{0, cx, cy - 100, 1.4}}, W, H) end
  local x, y, z = L.shot(lt, {{0, 600, 300, 1.3}, {14, cx, cy - 100, 1.4}, {44, cx, 580, 1.4}, {48, cx, 640, 1.8}, {54, cx, 640, 1.8},
                              {57, 440, 520, 1.25}, {62, 450, 480, 1.4}, {72, 450, 480, 1.4}, {76, 300, 520, 1.15}, {80, 384, 512, 1}}, W, H)
  local shake = (lt > 44 and lt < 44.6) and 7 or 0
  return x, y, z, shake
end
CUES.splash = {{2, "jet"}, {14.2, "pop"}, {18.6, "pop"}, {19.5, "pop"}, {20.4, "pop"}, {44, "splash"}, {52, "tape"},
               {56, "jet", 0.5}, {65, "ding"}, {68.3, "ding"}, {71.6, "ding"}, {75, "cheer"},
               {44, function()
                 local cx, cy = capsule_xy(44)
                 for i = 1, 70 do G:spark(cx + (G.R:random() - 0.5) * 80, cy, (G.R:random() - 0.5) * 320, -150 - G.R:random() * 380, 1.4, {0.85, 0.93, 1}, 6, 520) end
               end}}
for t = 760, 790, 10 do
  CUES.splash[#CUES.splash + 1] = {t / 10, function() G:firework(100 + G.R:random() * 80, 420 + G.R:random() * 80, false) end}
end
for t = 0, 130, 2 do
  CUES.splash[#CUES.splash + 1] = {t / 10, function()
    local cx, cy = capsule_xy(t / 10)
    for i = 1, 3 do G:spark(cx + 20, cy - 40, 60 + G.R:random() * 100, -120 - G.R:random() * 80, 0.6, {1, 0.55 + G.R:random() * 0.3, 0.2}, 9, 0, true) end
  end}
end

-- ------------------------------------------------------------------ the party
local REPLAYS = {
  function(lt)                              -- the launch again
    G:gradient(40, 120, 728, 400, {0.3, 0.55, 0.9}, {0.85, 0.85, 0.8})
    local ry = 380 - ((lt * 60) % 300)
    lg.push() lg.translate(384, ry) lg.scale(0.22, 0.22) rocket(0, 0, 1) lg.pop()
    C.fx.glow(384, ry + 20, 20, 40, 1, 0.7, 0.3, 0.9)
  end,
  function(lt)                              -- the flags on the Moon
    G:gradient(40, 120, 728, 400, {0, 0, 0.02}, {0.05, 0.05, 0.1})
    lg.setColor(0.6, 0.6, 0.62, 1)
    lg.rectangle("fill", 40, 330, 688, 70)
    lg.setColor(0.15, 0.4, 0.85, 1)
    lg.circle("fill", 600, 200, 40, 30)
    lg.setColor(0.8, 0.8, 0.82, 1)
    lg.rectangle("fill", 300, 250, 3, 80)
    lg.setColor(0.8, 0.11, 0.17, 1)
    lg.rectangle("fill", 303, 252, 44, 28)
    L.pac(380, 310 - L.hop(lt, 0.8, 30), 16, 0, lt, nil)
  end,
  function(lt)                              -- the parachutes
    G:gradient(40, 120, 728, 400, {0.3, 0.55, 0.9}, {0.6, 0.8, 1})
    local y = 200 + (lt * 20) % 120
    for i = -1, 1 do
      for k = 0, 5 do
        if k % 2 == 0 then lg.setColor(0.9, 0.2, 0.2, 1) else lg.setColor(0.97, 0.97, 0.95, 1) end
        lg.arc("fill", "pie", 384 + i * 50, y - 60, 34, pi + k * pi / 6, pi + (k + 1) * pi / 6, 6)
      end
    end
    lg.setColor(0.25, 0.25, 0.3, 1)
    lg.polygon("fill", 364, y + 20, 404, y + 20, 394, y, 374, y)
  end,
  function(lt)                              -- SPLASHDOWN, WELCOME HOME
    G:text("SPLASHDOWN", 40, 180, 72, {0.4, 1, 0.5}, 1, "center", 688)
    G:text("WELCOME HOME", 40, 280, 40, {1, 0.85, 0.3}, 1, "center", 688)
  end,
}
function D.party(lt, len)
  local st = {go = {}, seat = {}, banks = 3, dark = 0, screen = "replay"}
  for i = 1, #POLL do
    st.go[i] = true
    local sx, sy = seat_pos(i)
    st.seat[i] = {sx, sy - L.hop(lt + i * 0.3, 0.4, 30), sin(S.t * 2 + i), -0.5, "happy"}
  end
  st.director = {DIRECTOR[1] + sin(lt * 0.8) * 160, DIRECTOR[2] - L.hop(lt, 0.45, 40), lt % 4 < 2 and 0 or pi, 0.9}
  local n = floor(lt / 6) % #REPLAYS + 1
  st.replay = function() REPLAYS[n](lt) end
  room(lt, st)
  -- balloons going up
  for i, b in ipairs(S.balloons) do
    local y = H + 80 - (lt - b[3]) * b[4]
    if lt > b[3] and y > -100 then
      local x = b[1] + sin(lt * 1.3 + i) * 14
      lg.setColor(0.8, 0.8, 0.8, 0.6)
      lg.setLineWidth(1)
      lg.line(x, y + 40, x + sin(lt + i) * 6, y + 100)
      lg.setColor(b[2][1], b[2][2], b[2][3], 1)
      lg.ellipse("fill", x, y, 30, 38, 20)
      lg.setColor(1, 1, 1, 0.35)
      lg.ellipse("fill", x - 10, y - 14, 7, 11, 10)
    end
  end
  G:confetti(1, {{1, 0.3, 0.3}, {1, 1, 1}, {0.3, 0.5, 1}, {1, 0.85, 0.2}})
  if lt > 3 and lt < 7 then G:say("WE DID IT!", DIRECTOR[1] + sin(lt * 0.8) * 160, DIRECTOR[2] - 60, 26, 1) end
end
CAM.party = function(lt)
  return L.shot(lt, {{0, 384, 512, 1}, {8, 384, 512, 1}, {14, 384, 280, 1.5}, {20, 384, 280, 1.5}, {26, 384, 760, 1.3}, {32, 384, 512, 1}}, W, H)
end
CUES.party = {{0.5, "cheer"}, {4, "power"}, {12, "cheer"}, {24, "cheer"}}

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
  S.stars = {}
  for i = 1, 140 do S.stars[i] = {R:random() * W, R:random() * H, 0.3 + R:random() * 0.7} end
  S.streak = {}
  for i = 1, 9 do S.streak[i] = {R:random() * W, R:random() * (H + 400), 500 + R:random() * 500, 60 + R:random() * 90} end
  S.balloons = {}
  local cols = {{1, 0.3, 0.3}, {1, 0.85, 0.2}, {0.3, 0.6, 1}, {1, 0.5, 0.85}, {0.4, 0.9, 0.5}, {1, 1, 1}}
  for i = 1, 22 do S.balloons[i] = {40 + R:random() * (W - 80), cols[i % #cols + 1], i * 1.5 + R:random(), 70 + R:random() * 60} end
  S.art = {}
  for _, n in ipairs({"open", "houston", "control", "pad", "high", "orbit", "moon", "ocean"}) do
    S.art[n] = G:art("space", n)
  end
  for _, s in ipairs(SCENES) do if s[4] then G:label(s[4], 56, 0xffffff) end end
  for _, l in ipairs({{"PRESENTS", 26, 0x6ef0c8}, {"MISSION CONTROL", 64, 0x8ab4ff},
                      {"HOUSTON", 34, 0xffffff}, {"LIFTOFF!", 72, 0xffd23f}, {"IGNITION", 56, 0xffffff},
                      {"363 FEET  ·  THE MOON ROCKET", 28, 0xffffff}, {"TOWER JETTISON", 28, 0xffffff},
                      {"THAT'S TEXAS DOWN THERE", 28, 0xffffff}, {"STAGING", 56, 0x8ab4ff}, {"ONE SMALL HOP FOR PAC-MAN", 30, 0xffffff},
                      {"THE EAGLE HAS LANDED", 30, 0xffffff}, {"MACH 1", 30, 0xffffff}, {"SEE YOU, MOON", 30, 0xffffff}}) do
    G:label(l[1], l[2], l[3])
  end
  for i = 1, 10 do G:label("T MINUS " .. i, 56, 0xffffff) end
end

function M.act() return S and scene_at(S.t)[2] or "open" end
function M.music() return S and scene_at(S.t)[3] or "mc_hum" end

-- a scene's cues (sounds, bursts) when its clock passes their time
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
  if sc[2] == "launch" then
    -- the vapour off the rocket before the count
    if lt < 21 and floor(lt * 5) ~= floor((lt - dt) * 5) then
      local side = G.R:random() < 0.5 and -1 or 1
      G:puff(384 + side * 46, 500 + G.R:random() * 300, {0.95, 0.95, 1}, 10, side * (30 + G.R:random() * 40), 2.2, 10, 0.5)
    end
    if lt > 20 and lt < 44 then
      -- the fire and the smoke: billowing out from the pad, then a trail behind the rocket
      local up = clamp(lt - 22, 0, 100)
      local ry = 870 - (up > 0 and (up ^ 2) * 1.6 or 0)
      local n = lt < 40 and 6 or 2
      for i = 1, n do
        local side = G.R:random() < 0.5 and -1 or 1
        G:puff(384 + side * G.R:random() * (60 + up * 4), 900 - G.R:random() * 20, {0.85, 0.85, 0.88}, 20 + G.R:random() * 30,
               side * (60 + G.R:random() * 120), 4 + G.R:random() * 2, 18 + G.R:random() * 14, 0.6)
      end
      if ry > -100 then
        for i = 1, 4 do G:spark(384 + (G.R:random() - 0.5) * 40, ry + 30, (G.R:random() - 0.5) * 60, 200 + G.R:random() * 200, 0.4,
                                {1, 0.6 + G.R:random() * 0.3, 0.2}, 14, 0, true) end
      end
    end
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
    G:plate(sc[4], 30, sc[2] == "party" and 40 or 56, 0xffffff, L.window(lt, 1.5, 9, 1))
    local b = L.window(lt, 2, len - 1.5, 1)
    lg.setColor(0.02, 0.02, 0.06, 0.55 * b)
    lg.rectangle("fill", 0, H - 50, W, 50)
    G:text(sc[5], 0, H - 38, 20, {0.75, 0.85, 1}, b)
  end
  local f = 1 - min(lt / 1.2, (len - lt) / 1.2, 1)
  if f > 0 then
    lg.setColor(0, 0, 0, f)
    lg.rectangle("fill", 0, 0, W, H)
  end
end

return M
