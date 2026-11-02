-- Mission Control: Houston's space show (Texas is where the missions were flown from), nine minutes:
--   0:00  PARTYCADE PRESENTS ... MISSION CONTROL, HOUSTON                          (Countdown Hum)
--   0:08  Houston: the Saturn V lying in Rocket Park, the live oaks, the morning
--   1:20  Mission Control: the consoles, the big screens, Pac-Man as flight director; the go/no-go poll
--   2:30  Launch: the count from ten, ignition, liftoff, the smoke    (Also sprach Zarathustra's sunrise, 1896)
--   4:00  Orbit: the station over the Earth (Texas going by), a spacewalk, sunrise over the edge
--                                                                       (The Blue Danube, 1866)
--   5:30  The Moon: the lander, a hop in low gravity, two flags, Earthrise   (Tranquility)
--   7:00  Splashdown: three parachutes, the ocean, the helicopter     (Homecoming)
--   8:20  Houston, we've had a party: the room celebrates
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
local function rgba(c, a) lg.setColor(c[1], c[2], c[3], a or 1) end
local GHOSTS = {{1, 0.18, 0.2}, {1, 0.55, 0.85}, {0.25, 0.95, 1}, {1, 0.65, 0.2}}

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
  lg.setColor(0.8, 0.1, 0.12, 1)
  G:text("USA", x - w, y - 230 * s, floor(18 * s + 0.5), {0.15, 0.15, 0.2}, 1, "center", w * 2)
  lg.setColor(0.25, 0.25, 0.28, 1)
  for i = -1, 1 do lg.polygon("fill", x + i * 22 * s - 12 * s, y, x + i * 22 * s + 12 * s, y, x + i * 22 * s + 16 * s, y + 24 * s, x + i * 22 * s - 16 * s, y + 24 * s) end
  lg.polygon("fill", x - w, y - 20 * s, x - w - 20 * s, y + 10 * s, x - w, y + 10 * s)
  lg.polygon("fill", x + w, y - 20 * s, x + w + 20 * s, y + 10 * s, x + w, y + 10 * s)
end

-- An astronaut: Pac-Man in a suit and helmet (facing dir)
local function astronaut(x, y, s, dir, t)
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
  C.fx.chomper(x, y - 44 * s, 15 * s, dir, t, 1)
  lg.setColor(1, 1, 1, 0.35)
  lg.ellipse("fill", x - 8 * s, y - 54 * s, 8 * s, 4 * s, 10)
  lg.setColor(0.8, 0.1, 0.12, 1)
  lg.rectangle("fill", x - 10 * s, y - 6 * s, 8 * s, 5 * s)
  lg.setColor(0.15, 0.2, 0.55, 1)
  lg.rectangle("fill", x - 10 * s, y - 6 * s, 3 * s, 3 * s)
end

local function console(x, y, w, t, i)
  lg.setColor(0.45, 0.45, 0.48, 1)
  lg.rectangle("fill", x, y, w, 60)
  lg.setColor(0.35, 0.35, 0.38, 1)
  lg.polygon("fill", x, y, x + w, y, x + w - 10, y - 30, x + 10, y - 30)
  for k = 0, floor(w / 60) - 1 do
    local sx = x + 12 + k * 60
    lg.setColor(0.03, 0.12, 0.05, 1)
    lg.rectangle("fill", sx, y - 26, 44, 22)
    lg.setColor(0.3, 1, 0.4, 0.9)
    for r = 0, 2 do
      local len = 10 + ((floor(t * 3) + k * 7 + r * 3 + i) % 5) * 6
      lg.rectangle("fill", sx + 4, y - 22 + r * 6, len, 2)
    end
  end
  lg.setColor(1, 0.3, 0.2, (floor(t * 2) + i) % 2 == 0 and 1 or 0.3)
  lg.circle("fill", x + w - 16, y + 14, 4, 8)
end

-- ------------------------------------------------------------------ the scenes
local D = {}

function D.open(lt, len)
  G:gradient(0, 0, W, H, {0.0, 0.0, 0.03}, {0.03, 0.04, 0.12})
  stars()
  local a = L.window(lt, 0.5, 4, 0.7)
  G:caption("PARTYCADE", 400, 54, 0xff4fd8, a)
  G:caption("PRESENTS", 472, 26, 0x6ef0c8, a)
  local b = L.window(lt, 4.2, 8, 0.7)
  G:caption("MISSION CONTROL", 420, 64, 0x8ab4ff, b)
  G:caption("HOUSTON", 500, 34, 0xffffff, b)
end

function D.houston(lt, len)
  G:gradient(0, 0, W, 640, {0.3, 0.55, 0.9}, {0.85, 0.9, 1})
  L.live_oak(90, 640, 1.2, S.t)
  L.live_oak(690, 640, 1.0, S.t + 1)
  -- the shelter, the Saturn V on its side
  lg.setColor(0.75, 0.75, 0.78, 1)
  lg.rectangle("fill", 20, 340, 728, 20)
  for x = 40, 740, 100 do lg.rectangle("fill", x, 360, 10, 300) end
  local y = 520
  lg.setColor(0.25, 0.25, 0.28, 1)
  for i = 0, 4 do lg.polygon("fill", 30, y - 50 + i * 22, 70, y - 40 + i * 20, 70, y - 30 + i * 20, 30, y - 30 + i * 22) end
  lg.setColor(0.95, 0.95, 0.95, 1)
  lg.rectangle("fill", 70, y - 56, 300, 112)
  lg.rectangle("fill", 370, y - 46, 200, 92)
  lg.rectangle("fill", 570, y - 34, 110, 68)
  lg.polygon("fill", 680, y - 34, 730, y - 16, 730, y + 16, 680, y + 34)
  lg.setColor(0.1, 0.1, 0.12, 1)
  for _, x in ipairs({70, 150, 240, 370, 470, 570}) do lg.rectangle("fill", x, y - 56, 14, 112) end
  lg.rectangle("fill", 200, y - 56, 60, 36)
  lg.setColor(0.6, 0.6, 0.65, 1)
  for _, x in ipairs({120, 320, 520, 640}) do lg.rectangle("fill", x, y + 56, 12, 100) end
  G:gradient(0, 640, W, H, {0.35, 0.6, 0.3}, {0.25, 0.48, 0.2})
  -- visitors, small, for the scale
  for i = 0, 6 do
    local x = 120 + i * 80 + sin(S.t * 0.3 + i) * 20
    lg.setColor(({{0.8, 0.2, 0.2}, {0.2, 0.4, 0.8}, {0.9, 0.8, 0.3}})[i % 3 + 1])
    lg.rectangle("fill", x - 5, 680, 10, 18, 3, 3, 4)
    lg.setColor(0.9, 0.72, 0.58, 1)
    lg.circle("fill", x, 675, 5, 8)
  end
  G:plate("363 FEET  ·  THE MOON ROCKET", 240, 28, 0xffffff, L.window(lt, 14, 40, 1.5))
end

function D.control(lt, len)
  G:gradient(0, 0, W, H, {0.12, 0.13, 0.16}, {0.06, 0.07, 0.09})
  -- the big screens: the world map with the track, the clock
  lg.setColor(0.03, 0.06, 0.1, 1)
  lg.rectangle("fill", 40, 120, 688, 280)
  lg.setColor(0.2, 0.5, 0.8, 0.5)
  for i = 0, 8 do lg.rectangle("fill", 40 + i * 86, 120, 1, 280) end
  for i = 0, 4 do lg.rectangle("fill", 40, 120 + i * 70, 688, 1) end
  lg.setColor(0.4, 0.75, 0.45, 0.5)
  for _, b in ipairs({{120, 200, 90, 50}, {240, 260, 60, 80}, {400, 190, 120, 60}, {560, 240, 80, 50}}) do
    lg.ellipse("fill", b[1], b[2], b[3], b[4], 16)
  end
  lg.setColor(1, 0.85, 0.3, 1)
  lg.setLineWidth(2)
  local pts = {}
  for x = 40, 728, 8 do pts[#pts + 1] = x pts[#pts + 1] = 260 + sin((x - 40) / 688 * 4 * pi + S.t * 0.2) * 90 end
  lg.line(pts)
  local px = 40 + ((S.t * 30) % 688)
  lg.circle("fill", px, 260 + sin((px - 40) / 688 * 4 * pi + S.t * 0.2) * 90, 6, 10)
  -- the consoles in tiers, the flight controllers
  for tier = 0, 2 do
    local y = 560 + tier * 150
    for c = 0, 1 do console(60 + c * 340, y, 300, S.t, tier * 2 + c) end
  end
  for i, c in ipairs(GHOSTS) do
    local x = 120 + ((i - 1) % 2) * 340 + 120
    local y = 540 + floor((i - 1) / 2) * 150
    C.fx.ghost(x, y, 26, c, 1, S.t + i, false, false, 1)
    lg.setColor(0.1, 0.1, 0.1, 1)
    lg.setLineWidth(3)
    lg.arc("line", "open", x, y - 6, 28, pi + 0.3, 2 * pi - 0.3, 12)
  end
  -- the flight director: Pac-Man with his headset, at the back
  C.fx.chomper(384, 840, 36, 1, S.t * 0.4, 1)
  lg.setColor(0.1, 0.1, 0.1, 1)
  lg.setLineWidth(3)
  lg.arc("line", "open", 384, 836, 38, pi + 0.2, 2 * pi - 0.2, 14)
  lg.line(420, 840, 440, 856)
  -- the poll
  local poll = {"BOOSTER", "RETRO", "FIDO", "GUIDANCE", "SURGEON", "EECOM", "CAPCOM"}
  local n = floor(clamp((lt - 14) / 5, 0, #poll))
  lg.setColor(0, 0, 0, 0.7)
  lg.rectangle("fill", 466, 130, 254, 26 * #poll + 16, 8, 8, 6)
  for i = 1, n do
    G:text(poll[i] .. ":  GO", 478, 136 + (i - 1) * 26, 20, {0.4, 1, 0.5}, 1, "left", 240)
  end
  if n >= #poll then
    G:plate("FLIGHT: WE ARE GO FOR LAUNCH", 960, 26, 0x7dff8a, L.window(lt, 14 + #poll * 5, len - 1, 1))
  end
end

function D.launch(lt, len)
  if lt > 52 then
    -- high up: the sky gone dark, the Earth curving away, the first stage falling off
    local k2 = clamp((lt - 52) / 10, 0, 1)
    G:gradient(0, 0, W, H, {0.0, 0.0, 0.04}, mix({0.2, 0.35, 0.7}, {0.05, 0.08, 0.25}, k2))
    for i, s in ipairs(S.stars) do
      lg.setColor(1, 1, 1, s[3] * k2)
      lg.rectangle("fill", s[1], s[2], 2, 2)
    end
    C.fx.glow(384, 1500, 1100, 600, 0.3, 0.6, 1, 0.4)
    lg.setColor(0.1, 0.3, 0.7, 1)
    lg.circle("fill", 384, 1900, 1050, 96)
    local sep = lt > 62
    local ry = 520 + sin(lt * 0.5) * 6
    if sep then
      local f = lt - 62
      lg.push()
      lg.translate(384 + f * 6, ry + 120 + f * f * 6)
      lg.rotate(f * 0.3)
      lg.setColor(0.9, 0.9, 0.9, 1)
      lg.rectangle("fill", -20, -60, 40, 120)
      lg.setColor(0.1, 0.1, 0.12, 1)
      lg.rectangle("fill", -20, -10, 40, 6)
      lg.pop()
      lg.push()
      lg.translate(384, ry)
      lg.scale(0.45, 0.45)
      lg.translate(-384, -870)
      lg.setColor(0.95, 0.95, 0.95, 1)
      lg.rectangle("fill", 384 - 32, 870 - 420, 64, 120)
      lg.polygon("fill", 384 - 32, 450, 384 + 32, 450, 384 + 16, 400, 384 - 16, 400)
      lg.polygon("fill", 384 - 16, 400, 384 + 16, 400, 384, 350)
      lg.pop()
      C.fx.glow(384, ry - 120, 24, 50, 1, 0.7, 0.3, 0.8)
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
    return
  end
  local up = clamp(lt - 22, 0, 100)
  local k = clamp(up / 40, 0, 1)
  G:gradient(0, 0, W, H, mix({0.35, 0.6, 0.95}, {0.05, 0.08, 0.25}, k), mix({0.9, 0.85, 0.75}, {0.3, 0.35, 0.6}, k))
  -- the tower
  lg.setColor(0.7, 0.15, 0.1, 1)
  lg.rectangle("fill", 520, 230, 50, 640)
  lg.setColor(0.5, 0.1, 0.07, 1)
  lg.setLineWidth(3)
  for y = 240, 860, 40 do lg.line(520, y, 570, y + 40) lg.line(570, y, 520, y + 40) end
  local arm = up > 0 and 0 or 1
  lg.rectangle("fill", 470, 420, 50 * arm + 2, 10)
  -- the rocket: rising, faster and faster
  local ry = 870 - (up > 0 and (up ^ 2) * 1.6 or 0)
  if ry > -600 then rocket(384, ry, 1.15) end
  -- the pad, the smoke
  lg.setColor(0.45, 0.45, 0.48, 1)
  lg.rectangle("fill", 200, 870, 368, 40)
  G:gradient(0, 910, W, H, {0.5, 0.48, 0.4}, {0.4, 0.38, 0.3})
  -- the count
  if lt > 8 and lt < 22 then
    local n = floor(22 - lt)
    G:caption(n > 0 and ("T MINUS " .. n) or "IGNITION", 160, 56, 0xffffff, 1)
  end
  if up > 0 and up < 8 then G:caption("LIFTOFF!", 160, 72, 0xffd23f, clamp((8 - up) / 2, 0, 1)) end
end

-- the Earth from orbit: a big arc at the bottom, its land, clouds, the air glowing at the edge
local function earth(cx, cy, r, turn)
  C.fx.glow(cx, cy, r + 60, r + 60, 0.4, 0.7, 1, 0.5)
  lg.setColor(0.08, 0.3, 0.7, 1)
  lg.circle("fill", cx, cy, r, 96)
  -- land: blobs that move with the turn (Texas among them: the shape on the Gulf)
  for i, b in ipairs(S.land) do
    local a = b[1] + turn
    local x = cx + sin(a) * r * b[2]
    local y = cy - cos(a * 0.3) * r * b[3]
    if (x - cx) ^ 2 + (y - cy) ^ 2 < (r - 10) ^ 2 then
      lg.setColor(0.25 + (i % 3) * 0.05, 0.5, 0.2, 1)
      lg.ellipse("fill", x, y, b[4], b[5], 20)
    end
  end
  lg.setColor(1, 1, 1, 0.45)
  for i, c in ipairs(S.clouds) do
    local a = c[1] + turn * 1.2
    local x = cx + sin(a) * r * c[2]
    local y = cy - cos(a * 0.3) * r * c[3]
    if (x - cx) ^ 2 + (y - cy) ^ 2 < (r - 10) ^ 2 then lg.ellipse("fill", x, y, c[4], c[5], 16) end
  end
end

function D.orbit(lt, len)
  lg.setColor(0, 0, 0.02, 1)
  lg.rectangle("fill", 0, 0, W, H)
  stars()
  earth(384, 1700, 1100, S.t * 0.02)
  -- sunrise over the edge
  local sr = clamp((lt - 40) / 10, 0, 1) * clamp((80 - lt) / 10, 0, 1)
  if sr > 0 then
    C.fx.glow(560, 610, 300, 120, 1, 0.85, 0.6, 0.6 * sr)
    C.fx.glow(560, 610, 80, 80, 1, 1, 0.9, sr)
  end
  -- the station drifting across: truss, modules, the solar wings
  local sx = lerp(-200, W + 200, lt / len)
  local sy = 330 + sin(lt * 0.1) * 20
  lg.push()
  lg.translate(sx, sy)
  lg.rotate(0.08)
  lg.setColor(0.7, 0.7, 0.72, 1)
  lg.rectangle("fill", -180, -6, 360, 12)
  lg.setColor(0.85, 0.85, 0.88, 1)
  lg.rectangle("fill", -30, -20, 60, 40, 8, 8, 6)
  lg.rectangle("fill", 30, -14, 50, 28, 8, 8, 6)
  for _, wx in ipairs({-170, -120, 120, 170}) do
    lg.setColor(0.15, 0.2, 0.5, 1)
    lg.rectangle("fill", wx - 18, -80, 36, 66)
    lg.rectangle("fill", wx - 18, 14, 36, 66)
    lg.setColor(0.8, 0.65, 0.2, 0.6)
    for k = 0, 5 do lg.rectangle("fill", wx - 18, -80 + k * 11, 36, 1) lg.rectangle("fill", wx - 18, 14 + k * 11, 36, 1) end
  end
  lg.pop()
  -- the spacewalk: Pac-Man on his tether, turning slowly
  local ax, ay = sx + 60 + sin(lt * 0.4) * 50, sy + 120 + cos(lt * 0.3) * 30
  lg.setColor(0.9, 0.9, 0.9, 0.8)
  lg.setLineWidth(2)
  lg.line(sx + 40, sy + 10, (sx + ax) / 2 + 20, (sy + ay) / 2 + 30, ax, ay - 20)
  lg.push()
  lg.translate(ax, ay)
  lg.rotate(sin(lt * 0.2) * 0.6)
  astronaut(0, 0, 0.9, 1, S.t * 0.3)
  lg.pop()
  local tx = L.window(lt, 20, 34, 1.5)
  G:plate("THAT'S TEXAS DOWN THERE", 160, 28, 0xffffff, tx)
end

function D.moon(lt, len)
  lg.setColor(0, 0, 0.01, 1)
  lg.rectangle("fill", 0, 0, W, H)
  stars()
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
  -- the ground: grey, with craters
  G:gradient(0, 640, W, H, {0.55, 0.55, 0.57}, {0.4, 0.4, 0.42})
  for i, c in ipairs(S.craters) do
    lg.setColor(0.38, 0.38, 0.4, 1)
    lg.ellipse("fill", c[1], c[2], c[3], c[3] * 0.3, 20)
    lg.setColor(0.65, 0.65, 0.67, 1)
    lg.ellipse("fill", c[1], c[2] - c[3] * 0.08, c[3] * 0.85, c[3] * 0.2, 20)
  end
  -- the lander
  local lx, ly = 200, 760
  lg.setColor(0.85, 0.7, 0.25, 1)
  lg.polygon("fill", lx - 60, ly - 40, lx + 60, ly - 40, lx + 70, ly, lx - 70, ly)
  lg.setLineWidth(5)
  lg.line(lx - 60, ly - 10, lx - 100, ly + 50)
  lg.line(lx + 60, ly - 10, lx + 100, ly + 50)
  lg.setColor(0.75, 0.75, 0.78, 1)
  lg.polygon("fill", lx - 44, ly - 40, lx + 44, ly - 40, lx + 30, ly - 110, lx - 30, ly - 110)
  lg.setColor(0.1, 0.1, 0.15, 1)
  lg.polygon("fill", lx - 14, ly - 90, lx + 14, ly - 90, lx + 10, ly - 70, lx - 10, ly - 70)
  -- the flags (US and Texas), planted after the hop
  local planted = lt > 40
  if planted then
    for i, fx in ipairs({460, 540}) do
      lg.setColor(0.8, 0.8, 0.82, 1)
      lg.rectangle("fill", fx - 2, 700, 4, 120)
      if i == 1 then
        for k = 0, 6 do
          if k % 2 == 0 then lg.setColor(0.8, 0.11, 0.17, 1) else lg.setColor(0.97, 0.97, 0.95, 1) end
          lg.rectangle("fill", fx + 2, 702 + k * 6, 60, 6)
        end
        lg.setColor(0.14, 0.2, 0.52, 1)
        lg.rectangle("fill", fx + 2, 702, 24, 24)
      else
        lg.setColor(0.0, 0.16, 0.41, 1)
        lg.rectangle("fill", fx + 2, 702, 20, 42)
        lg.setColor(0.97, 0.97, 0.95, 1)
        lg.rectangle("fill", fx + 22, 702, 40, 21)
        lg.setColor(0.75, 0.04, 0.19, 1)
        lg.rectangle("fill", fx + 22, 723, 40, 21)
        lg.setColor(1, 1, 1, 1)
        L.star(fx + 12, 723, 7)
      end
    end
  end
  -- the astronaut hopping (slowly: a sixth of the gravity), footprints behind
  local hx = lerp(260, 600, clamp(lt / 60, 0, 1))
  local hop = abs(sin(lt * 1.2)) * 60
  lg.setColor(0.35, 0.35, 0.37, 1)
  for i = 0, floor((hx - 260) / 30) do lg.ellipse("fill", 270 + i * 30, 880 + (i % 2) * 8, 8, 3, 8) end
  astronaut(hx, 820 - hop, 1, 1, S.t * 0.4)
  G:plate("ONE SMALL HOP FOR PAC-MAN", 160, 30, 0xffffff, L.window(lt, 46, 62, 1.5))
end

function D.splash(lt, len)
  local k = clamp(lt / 50, 0, 1)
  G:gradient(0, 0, W, 640, {0.3, 0.55, 0.9}, {0.8, 0.9, 1})
  G:gradient(0, 640, W, H, {0.15, 0.4, 0.6}, {0.05, 0.25, 0.45})
  for i = 0, 12 do
    lg.setColor(1, 1, 1, 0.25)
    local y = 660 + i * 28
    local x = ((i * 97 + S.t * 20) % (W + 100)) - 50
    lg.rectangle("fill", x, y, 60 + i * 4, 2)
  end
  -- the capsule under its three parachutes, coming down
  local cy = lerp(-200, 680, ease(k))
  local cx = 384 + sin(S.t * 0.5) * 20 * (1 - k)
  for i = -1, 1 do
    local px, py = cx + i * 110, cy - 260 - abs(i) * 30
    for s = 0, 5 do
      if s % 2 == 0 then lg.setColor(0.9, 0.2, 0.2, 1) else lg.setColor(0.97, 0.97, 0.95, 1) end
      lg.arc("fill", "pie", px, py, 80, pi + s * pi / 6, pi + (s + 1) * pi / 6, 6)
    end
    lg.setColor(0.8, 0.8, 0.8, 0.8)
    lg.setLineWidth(1.5)
    lg.line(px - 78, py, cx - 10, cy - 50)
    lg.line(px + 78, py, cx + 10, cy - 50)
  end
  lg.setColor(0.25, 0.25, 0.3, 1)
  lg.polygon("fill", cx - 50, cy, cx + 50, cy, cx + 20, cy - 60, cx - 20, cy - 60)
  lg.setColor(0.85, 0.85, 0.88, 1)
  lg.rectangle("fill", cx - 10, cy - 50, 20, 14)
  if k >= 1 then
    lg.setColor(1, 0.85, 0.2, 1)
    lg.ellipse("fill", cx, cy + 4, 70, 14, 24)
    if lt < 54 then for i = 1, 20 do G:spark(cx, cy, (G.R:random() - 0.5) * 300, -100 - G.R:random() * 200, 1, {0.9, 0.95, 1}, 5, 500) end end
  end
  -- the helicopter
  if lt > 56 then
    local hx = lerp(W + 150, 520, clamp((lt - 56) / 12, 0, 1))
    lg.setColor(0.3, 0.35, 0.3, 1)
    lg.ellipse("fill", hx, 300, 60, 26, 20)
    lg.rectangle("fill", hx + 40, 292, 100, 10)
    lg.setColor(0.2, 0.2, 0.2, 1)
    lg.setLineWidth(3)
    local b = sin(S.t * 40) * 90
    lg.line(hx - b, 270, hx + b, 270)
    lg.line(hx, 270, hx, 280)
    lg.setColor(0.4, 0.6, 0.9, 1)
    lg.ellipse("fill", hx - 30, 296, 20, 14, 12)
  end
end

function D.party(lt, len)
  D.control(len, len)
  -- the screens say it, the room celebrates
  lg.setColor(0.03, 0.06, 0.1, 0.9)
  lg.rectangle("fill", 40, 120, 688, 280)
  G:text("SPLASHDOWN", 40, 180, 72, {0.4, 1, 0.5}, 1, "center", 688)
  G:text("WELCOME HOME", 40, 280, 40, {1, 0.85, 0.3}, 1, "center", 688)
  G:confetti(1, {{1, 0.3, 0.3}, {1, 1, 1}, {0.3, 0.5, 1}, {1, 0.85, 0.2}})
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
  S.stars = {}
  for i = 1, 140 do S.stars[i] = {R:random() * W, R:random() * H, 0.3 + R:random() * 0.7} end
  S.land, S.clouds = {}, {}
  for i = 1, 14 do S.land[i] = {R:random() * 2 * pi, R:random(), 0.6 + R:random() * 0.4, 60 + R:random() * 140, 30 + R:random() * 60} end
  -- (one of them a little Texas-shaped: wide, with its point down)
  S.land[15] = {0.3, 0.2, 0.95, 120, 70}
  for i = 1, 22 do S.clouds[i] = {R:random() * 2 * pi, R:random(), 0.6 + R:random() * 0.4, 40 + R:random() * 90, 10 + R:random() * 20} end
  S.craters = {}
  for i = 1, 16 do S.craters[i] = {R:random() * W, 680 + R:random() * 320, 20 + R:random() * 60} end
  for _, s in ipairs(SCENES) do if s[4] then G:label(s[4], 56, 0xffffff) end end
  for _, l in ipairs({{"PARTYCADE", 54, 0xff4fd8}, {"PRESENTS", 26, 0x6ef0c8}, {"MISSION CONTROL", 64, 0x8ab4ff},
                      {"HOUSTON", 34, 0xffffff}, {"LIFTOFF!", 72, 0xffd23f}, {"IGNITION", 56, 0xffffff},
                      {"363 FEET  ·  THE MOON ROCKET", 28, 0xffffff}, {"FLIGHT: WE ARE GO FOR LAUNCH", 26, 0x7dff8a},
                      {"THAT'S TEXAS DOWN THERE", 28, 0xffffff}, {"STAGING", 56, 0x8ab4ff}, {"ONE SMALL HOP FOR PAC-MAN", 30, 0xffffff}}) do
    G:label(l[1], l[2], l[3])
  end
  for i = 1, 10 do G:label("T MINUS " .. i, 56, 0xffffff) end
end

function M.act() return S and scene_at(S.t)[2] or "open" end
function M.music() return S and scene_at(S.t)[3] or "mc_hum" end

function M.update(dt)
  if not S then return false end
  G:step(dt)
  S.t = G.t
  local sc, lt = scene_at(S.t)
  if sc[2] == "launch" then
    if lt > 20 and lt < 52 then
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
    if lt - dt < 21 and lt >= 21 then C.sfx("boom") C.sfx("jet") end
  end
  if sc[2] == "control" and floor((lt - dt - 14) / 5) ~= floor((lt - 14) / 5) and lt > 14 and lt < 50 then C.sfx("pew", 0.3) end
  if sc[2] == "party" and floor((lt - dt) / 4) ~= floor(lt / 4) then C.sfx("cheer") end
  return S.t >= LEN
end

function M.draw()
  if not S then return end
  local sc, lt, len = scene_at(S.t)
  D[sc[2]](lt, len)
  G:draw_back()
  G:draw_front()
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
