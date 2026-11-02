-- Halloween: the ghosts' own holiday. Home's show for the second half of October (shows.lua's calendar; on the
-- 31st it plays into the night), nine minutes:
--   0:00  PARTYCADE PRESENTS ... HALLOWEEN, lightning                             (Toccata, Bach, 1704)
--   0:10  The haunted house on the hill: the moon, the dead oak, bats, flickering windows, fog, the graveyard
--   1:30  Pumpkin carving: faces cut one by one (one of them Pac-Man, one a ghost), candles lit  (Pumpkin Patch)
--   2:40  Trick or treat: Pac-Man went as a ghost, the ghosts went as Pac-Man, door to door  (In the Hall of the
--         Mountain King, Grieg, 1875: faster and faster)
--   4:10  The graveyard dance: skeletons and ghosts under the moon                  (Skeleton Swing)
--   5:30  The witch's flight across the moon; the cauldron bubbling                 (Theremin Waltz)
--   6:40  Lights out: only eyes in the dark, a flashlight, and BOO!                  (Lights Out)
--   7:50  HAPPY HALLOWEEN: a row of jack-o'-lanterns                                 (Happy Haunting)
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
  {0, "open", "hw_toccata"},
  {10, "house", "hw_toccata", "THE HAUNTED HOUSE", "UP ON THE HILL  ·  NOBODY LIVES THERE  ·  ALLEGEDLY"},
  {90, "pumpkins", "hw_pumpkin", "PUMPKIN CARVING", "SIX PUMPKINS  ·  SIX FACES"},
  {160, "trick", "hw_mountain1", "TRICK OR TREAT", "PAC-MAN WENT AS A GHOST  ·  THE GHOSTS WENT AS PAC-MAN"},
  {250, "graveyard", "hw_skeleton", "THE GRAVEYARD DANCE", "EVERYBODY OUT OF THE GROUND"},
  {330, "witch", "hw_witch", "THE WITCH'S FLIGHT", "DOUBLE, DOUBLE, TOIL AND TROUBLE"},
  {400, "dark", "hw_dark", "LIGHTS OUT", "WHO TURNED OFF THE POWER PELLETS?"},
  {470, "finale", "hw_finale"},
}
M.SEGMENTS = {}
for _, s in ipairs(SCENES) do if s[4] then M.SEGMENTS[#M.SEGMENTS + 1] = {s[1], s[4]} end end
table.insert(M.SEGMENTS, {470, "HAPPY HALLOWEEN"})
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
local ORANGE = {1, 0.5, 0.05}
local PURPLE = {0.35, 0.12, 0.5}

-- ------------------------------------------------------------------ small things
local function bat(x, y, s, t)
  local f = sin(t * 14) * 0.8
  lg.setColor(0.05, 0.03, 0.08, 1)
  lg.push()
  lg.translate(x, y)
  lg.scale(s, s)
  lg.ellipse("fill", 0, 0, 6, 8, 10)
  for d = -1, 1, 2 do
    lg.polygon("fill", d * 4, -2, d * 26, -10 - f * 10, d * 20, 0, d * 30, 2 - f * 8, d * 14, 8, d * 4, 4)
  end
  lg.polygon("fill", -4, -6, -6, -14, -1, -8)
  lg.polygon("fill", 4, -6, 6, -14, 1, -8)
  lg.pop()
end

-- A pumpkin; face: nil (plain), or carved: {kind, k (0..1 how far carved)}, lit (candle glow)
local function pumpkin(x, y, r, face, lit, t)
  lg.setColor(0.85, 0.4, 0.05, 1)
  lg.ellipse("fill", x - r * 0.45, y, r * 0.6, r * 0.85, 24)
  lg.ellipse("fill", x + r * 0.45, y, r * 0.6, r * 0.85, 24)
  lg.setColor(0.95, 0.5, 0.08, 1)
  lg.ellipse("fill", x, y, r * 0.65, r * 0.9, 24)
  lg.setColor(0.3, 0.45, 0.15, 1)
  lg.rectangle("fill", x - r * 0.08, y - r * 1.1, r * 0.16, r * 0.3, 3, 3, 4)
  if not face then return end
  local k = face[2]
  local glow = lit and (0.8 + 0.2 * sin(t * 12 + x)) or 0
  local col = lit and {1, 0.86 + 0.12 * glow, 0.35 + 0.35 * glow} or {0.35, 0.15, 0.02}
  if lit then C.fx.glow(x, y, r * 1.6, r * 1.4, 1, 0.6, 0.15, 0.35 * glow) end
  rgba(col)
  local kind = face[1]
  if k > 0.15 then
    if kind == "pac" then
      lg.arc("fill", "pie", x - r * 0.3, y - r * 0.25, r * 0.22, 0.6, 2 * pi - 0.6, 16)
      lg.arc("fill", "pie", x + r * 0.3, y - r * 0.25, r * 0.22, 0.6, 2 * pi - 0.6, 16)
    elseif kind == "ghost" then
      for d = -1, 1, 2 do
        lg.arc("fill", "pie", x + d * r * 0.3, y - r * 0.2, r * 0.18, pi, 2 * pi, 12)
        lg.rectangle("fill", x + d * r * 0.3 - r * 0.18, y - r * 0.2, r * 0.36, r * 0.18)
      end
    else
      for d = -1, 1, 2 do lg.polygon("fill", x + d * r * 0.3, y - r * 0.45, x + d * r * 0.12, y - r * 0.1, x + d * r * 0.48, y - r * 0.1) end
    end
  end
  if k > 0.45 then lg.polygon("fill", x, y - r * 0.05, x - r * 0.1, y + r * 0.12, x + r * 0.1, y + r * 0.12) end
  if k > 0.75 then
    -- the grin, with teeth
    local pts = {x - r * 0.5, y + r * 0.25}
    for i = 0, 8 do
      local u = i / 8
      pts[#pts + 1] = x - r * 0.5 + u * r
      pts[#pts + 1] = y + r * 0.25 + sin(u * pi) * r * 0.35 + ((i % 2 == 1) and -r * 0.1 or 0)
    end
    pts[#pts + 1] = x + r * 0.5
    pts[#pts + 1] = y + r * 0.25
    for i = 1, #pts - 4, 2 do
      lg.polygon("fill", pts[i], pts[i + 1], pts[i + 2], pts[i + 3], x, y + r * 0.3)
    end
  end
end

-- A skeleton dancing (a jointed stick figure): phase t
local function skeleton(x, y, s, t)
  lg.setColor(0.92, 0.92, 0.88, 1)
  lg.setLineWidth(5 * s)
  local sw = sin(t * 4)
  local hx, hy = x + sw * 6 * s, y - 120 * s
  lg.circle("fill", hx, hy, 16 * s, 16)
  lg.setColor(0.08, 0.05, 0.1, 1)
  lg.circle("fill", hx - 6 * s, hy - 2 * s, 4 * s, 8)
  lg.circle("fill", hx + 6 * s, hy - 2 * s, 4 * s, 8)
  lg.rectangle("fill", hx - 6 * s, hy + 7 * s, 12 * s, 3 * s)
  lg.setColor(0.92, 0.92, 0.88, 1)
  lg.line(hx, hy + 16 * s, x, y - 50 * s)
  for i = 0, 3 do lg.line(x - 14 * s + sw * 3 * s, y - 92 * s + i * 10 * s, x + 14 * s + sw * 3 * s, y - 92 * s + i * 10 * s) end
  local a1, a2 = sin(t * 4) * 1.2, -sin(t * 4) * 1.2
  lg.line(x, y - 96 * s, x - 30 * s, y - 96 * s - a1 * 30 * s, x - 46 * s, y - 120 * s - a1 * 20 * s)
  lg.line(x, y - 96 * s, x + 30 * s, y - 96 * s - a2 * 30 * s, x + 46 * s, y - 120 * s - a2 * 20 * s)
  local k1, k2 = abs(sin(t * 4)), abs(cos(t * 4))
  lg.line(x, y - 50 * s, x - 18 * s, y - 24 * s - k1 * 14 * s, x - 22 * s, y)
  lg.line(x, y - 50 * s, x + 18 * s, y - 24 * s - k2 * 14 * s, x + 22 * s, y)
end

local function tombstone(x, y, w, h, text)
  lg.setColor(0.45, 0.45, 0.5, 1)
  lg.rectangle("fill", x - w / 2, y - h, w, h)
  lg.arc("fill", "pie", x, y - h, w / 2, pi, 2 * pi, 20)
  lg.setColor(0.3, 0.3, 0.35, 1)
  lg.rectangle("fill", x - w / 2, y - 4, w, 4)
  if text then G:text(text, x - w / 2, y - h + 4, 14, {0.15, 0.15, 0.2}, 1, "center", w) end
end

local function dead_tree(x, y, s)
  lg.setColor(0.04, 0.03, 0.06, 1)
  lg.setLineWidth(14 * s)
  lg.line(x, y, x - 6 * s, y - 160 * s)
  lg.setLineWidth(8 * s)
  lg.line(x - 4 * s, y - 120 * s, x - 70 * s, y - 190 * s, x - 90 * s, y - 230 * s)
  lg.line(x - 6 * s, y - 150 * s, x + 50 * s, y - 220 * s, x + 90 * s, y - 230 * s)
  lg.setLineWidth(4 * s)
  lg.line(x - 70 * s, y - 190 * s, x - 110 * s, y - 196 * s)
  lg.line(x + 50 * s, y - 220 * s, x + 40 * s, y - 270 * s)
  lg.line(x - 6 * s, y - 160 * s, x + 4 * s, y - 250 * s)
end

local function moon(x, y, r, a)
  C.fx.glow(x, y, r * 2.6, r * 2.6, 1, 0.9, 0.6, 0.25 * (a or 1))
  lg.setColor(1, 0.95, 0.8, a or 1)
  lg.circle("fill", x, y, r, 48)
  lg.setColor(0.85, 0.82, 0.68, 0.6 * (a or 1))
  lg.circle("fill", x - r * 0.3, y - r * 0.2, r * 0.18, 16)
  lg.circle("fill", x + r * 0.25, y + r * 0.3, r * 0.12, 16)
end

-- ------------------------------------------------------------------ the scenes
local D = {}

-- the painted picture for a scene, if the SD card has it: drawn, true
local function art(name, a)
  local img = S.art[name]
  if not img then return false end
  lg.setColor(1, 1, 1, a or 1)
  lg.draw(img, 0, 0)
  return true
end

function D.open(lt, len)
  if not art("open") then G:gradient(0, 0, W, H, {0.04, 0.0, 0.08}, {0.15, 0.04, 0.12}) end
  local flash = (lt > 1.5 and lt < 1.7) or (lt > 6 and lt < 6.15)
  if flash then lg.setColor(0.8, 0.8, 1, 0.5) lg.rectangle("fill", 0, 0, W, H) end
  for i = 1, 6 do bat(((S.t * 60 + i * 140) % (W + 120)) - 60, 200 + sin(S.t + i) * 60 + i * 40, 1.2, S.t + i) end
  local a = L.window(lt, 0.5, 4.5, 0.8)
  G:caption("PARTYCADE", 400, 54, 0xff4fd8, a)
  G:caption("PRESENTS", 472, 26, 0x6ef0c8, a)
  G:caption("HALLOWEEN", 430, 84, 0xff8000, L.window(lt, 4.8, 10, 0.8))
end

function D.house(lt, len)
  local painted = art("house")
  local hx, hy = 384, 600
  if not painted then
  G:gradient(0, 0, W, 700, {0.05, 0.02, 0.12}, {0.3, 0.12, 0.3})
  for i, s in ipairs(S.stars) do
    lg.setColor(1, 1, 0.9, 0.3 + 0.4 * sin(S.t + i))
    lg.rectangle("fill", s[1], s[2], 2, 2)
  end
  moon(560, 200, 110)
  -- the hill, the house on it
  lg.setColor(0.06, 0.04, 0.1, 1)
  lg.ellipse("fill", 384, 760, 520, 200, 48)
  lg.setColor(0.1, 0.07, 0.13, 1)
  lg.rectangle("fill", hx - 150, hy - 140, 300, 160)
  lg.polygon("fill", hx - 170, hy - 140, hx + 170, hy - 140, hx, hy - 260)
  lg.rectangle("fill", hx + 70, hy - 300, 50, 170)
  lg.polygon("fill", hx + 60, hy - 300, hx + 130, hy - 300, hx + 95, hy - 360)
  lg.rectangle("fill", hx - 140, hy - 210, 14, 70)
  end
  -- the windows, flickering
  for i, w in ipairs({{-110, -110}, {-40, -110}, {40, -110}, {-110, -50}, {80, -50}, {95, -260}}) do
    local on = (floor(S.t * (1 + i * 0.3)) + i) % 4 ~= 0
    lg.setColor(1, 0.75, 0.25, on and (0.75 + 0.25 * sin(S.t * 9 + i)) or 0.1)
    lg.rectangle("fill", hx + w[1], hy + w[2], 34, 44)
  end
  -- a ghost at the attic window, now and then
  if floor(S.t / 6) % 2 == 0 then C.fx.ghost(hx + 95, hy - 230, 14, GHOSTS[3], 1, S.t, false, false, 0.8) end
  if not painted then
  lg.setColor(0.04, 0.03, 0.06, 1)
  lg.rectangle("fill", hx - 20, hy - 30, 40, 50)
  dead_tree(120, 760, 1.3)
  -- the graveyard and its fence
  G:gradient(0, 760, W, H, {0.07, 0.05, 0.1}, {0.03, 0.02, 0.05})
  for i, t in ipairs({{120, 880, "R.I.P."}, {260, 900, "HIGH SCORE"}, {420, 870, "PAC'S DIET"}, {580, 900, "R.I.P."}, {690, 880, nil}}) do
    tombstone(t[1], t[2], 80, 70, t[3])
  end
  lg.setColor(0.02, 0.02, 0.04, 1)
  for x = 0, W, 24 do lg.polygon("fill", x, 950, x + 6, 930, x + 12, 950, x + 12, 1024, x, 1024) end
  lg.rectangle("fill", 0, 960, W, 6)
  end
  for i = 1, 5 do bat(((S.t * (40 + i * 6) + i * 180) % (W + 160)) - 80, 300 + sin(S.t * 0.8 + i * 2) * 120, 0.9, S.t + i) end
  -- lightning now and then
  local fl = (S.t % 13)
  if fl < 0.12 or (fl > 0.25 and fl < 0.33) then
    lg.setColor(0.8, 0.8, 1, 0.35)
    lg.rectangle("fill", 0, 0, W, H)
  end
end

function D.pumpkins(lt, len)
  if not art("kitchen") then
    G:gradient(0, 0, W, H, {0.12, 0.06, 0.12}, {0.06, 0.03, 0.06})
    lg.setColor(0.35, 0.22, 0.14, 1)
    lg.rectangle("fill", 0, 620, W, 404)
    lg.setColor(0.28, 0.17, 0.1, 1)
    for y = 640, 1024, 46 do lg.rectangle("fill", 0, y, W, 3) end
  end
  local faces = {"pac", "tri", "ghost", "tri", "tri", "pac"}
  local lit = lt > 50
  if lit then
    -- the room dark, the candles bright
    lg.setColor(0, 0, 0, 0.55 * clamp((lt - 48) / 3, 0, 1))
    lg.rectangle("fill", 0, 0, W, H)
  end
  for i = 1, 6 do
    local x = 130 + ((i - 1) % 3) * 254
    local y = i <= 3 and 560 or 830
    local k = clamp((lt - 4 - (i - 1) * 7) / 6, 0, 1)
    pumpkin(x, y, 90, k > 0 and {faces[i], k} or nil, lit and k >= 1, S.t)
    if k > 0 and k < 1 then
      -- the knife at work
      local kx = x + sin(S.t * 20) * 30
      lg.setColor(0.8, 0.82, 0.86, 1)
      lg.polygon("fill", kx, y - 40, kx + 8, y - 120, kx + 14, y - 118, kx + 6, y - 38)
      lg.setColor(0.35, 0.2, 0.1, 1)
      lg.rectangle("fill", kx + 6, y - 150, 8, 32)
      if G.R:random() < 0.3 then G:spark(x, y, (G.R:random() - 0.5) * 120, -60 - G.R:random() * 60, 0.6, {1, 0.75, 0.3}, 4, 400) end
    end
  end
  if lit then G:plate("THE CANDLES ARE LIT", 120, 34, 0xff8000, L.window(lt, 52, 66, 1)) end
end

function D.trick(lt, len)
  local painted = art("street")
  if not painted then
  G:gradient(0, 0, W, 700, {0.05, 0.03, 0.15}, {0.2, 0.1, 0.25})
  moon(120, 140, 60)
  end
  -- the street: three houses, porch lights, doors that open
  for i = 0, 2 do
    local x = 30 + i * 250
    local door = ((lt + i * 9) % 27) < 5
    if not painted then
      lg.setColor(0.14 + i * 0.03, 0.1, 0.16, 1)
      lg.rectangle("fill", x, 420, 210, 330)
      lg.polygon("fill", x - 10, 420, x + 220, 420, x + 105, 330)
    end
    if door or not painted then
      lg.setColor(door and 1 or 0.3, door and 0.8 or 0.2, door and 0.4 or 0.1, 1)
      lg.rectangle("fill", x + 80, 620, 50, 130)
    end
    lg.setColor(1, 0.85, 0.4, 0.9)
    lg.circle("fill", x + 145, 640, 6, 10)
    C.fx.glow(x + 145, 640, 50, 50, 1, 0.8, 0.3, 0.3)
    pumpkin(x + 30, 735, 22, {"tri", 1}, true, S.t)
    if door then
      lg.setColor(0.95, 0.5, 0.1, 1)
      lg.ellipse("fill", x + 105, 690, 28, 12, 16)
    end
  end
  if not painted then G:gradient(0, 750, W, H, {0.18, 0.18, 0.2}, {0.12, 0.12, 0.14}) end
  -- the trick-or-treaters walking the street: Pac-Man under a sheet, the ghosts as Pac-Men
  local x0 = -200 + ((lt * 32) % (W + 500))
  -- Pac-Man as a ghost: a white sheet with eye holes (and the mouth wedge peeking at the bottom)
  local px, py = x0, 880 + abs(sin(S.t * 6)) * -6
  lg.setColor(0.97, 0.97, 1, 1)
  lg.arc("fill", "pie", px, py, 44, pi, 2 * pi, 24)
  lg.rectangle("fill", px - 44, py, 88, 50)
  for i = 0, 3 do lg.circle("fill", px - 33 + i * 22, py + 50, 11, 10) end
  lg.setColor(0.05, 0.05, 0.08, 1)
  lg.ellipse("fill", px - 14, py - 14, 7, 10, 10)
  lg.ellipse("fill", px + 14, py - 14, 7, 10, 10)
  lg.setColor(1, 0.86, 0.15, 1)
  lg.polygon("fill", px - 16, py + 62, px + 16, py + 62, px, py + 48)
  -- the ghosts in yellow, each a little Pac-Man with a wedge mouth and their own little feet
  for i, c in ipairs(GHOSTS) do
    local gx = x0 - 100 - (i - 1) * 90
    local gy = 900 + abs(sin(S.t * 6 + i)) * -6
    C.fx.chomper(gx, gy, 32, 1, S.t + i * 0.2, 1)
    rgba(c)
    for k = 0, 2 do lg.circle("fill", gx - 18 + k * 18, gy + 30, 7, 8) end
    -- the candy bag
    lg.setColor(0.95, 0.5, 0.1, 1)
    lg.rectangle("fill", gx + 22, gy + 4, 18, 22, 4, 4, 4)
  end
  local a = L.window(lt, 40, 60, 1.5)
  G:plate("NICE COSTUMES, EVERYONE", 200, 34, 0xff8000, a)
end

function D.graveyard(lt, len)
  if not art("graveyard") then
    G:gradient(0, 0, W, 760, {0.03, 0.05, 0.12}, {0.12, 0.2, 0.25})
    moon(384, 260, 150)
    for i, t in ipairs({{80, 860}, {200, 880}, {560, 880}, {690, 860}}) do tombstone(t[1], t[2], 70, 60, nil) end
    G:gradient(0, 760, W, H, {0.08, 0.12, 0.1}, {0.04, 0.06, 0.05})
  end
  -- the dancers: skeletons and ghosts in a line, in step
  for i = 0, 3 do
    skeleton(160 + i * 150, 900, 1.1, S.t * 1.0 + i * 0.5)
  end
  for i, c in ipairs(GHOSTS) do
    local gx = 130 + (i - 1) * 170 + sin(S.t * 2 + i) * 40
    C.fx.ghost(gx, 640 + sin(S.t * 3 + i) * 30, 28, c, sin(S.t + i) > 0 and 1 or -1, S.t + i, false, false, 1)
  end
  -- fog drifting
  if G.R:random() < 0.4 then G:puff(G.R:random() * W, 960, {0.7, 0.75, 0.8}, 6, 20, 5, 30, 0.12) end
end

function D.witch(lt, len)
  local painted = art("witch")
  if not painted then
    G:gradient(0, 0, W, H, {0.04, 0.02, 0.1}, {0.25, 0.08, 0.25})
    moon(384, 380, 220)
  end
  -- the witch on her broom, across the moon
  local p = (lt % 24) / 24
  local x, y = lerp(-150, W + 150, p), 420 - sin(p * pi) * 160
  lg.push()
  lg.translate(x, y)
  lg.rotate(-0.12 + sin(S.t * 2) * 0.04)
  lg.setColor(0.03, 0.02, 0.05, 1)
  lg.setLineWidth(5)
  lg.line(-80, 10, 70, 0)
  lg.polygon("fill", -80, 10, -120, -6, -126, 26)
  lg.polygon("fill", -10, 4, 12, -50, 30, 0)
  lg.circle("fill", 14, -58, 10, 12)
  lg.polygon("fill", -6, -60, 36, -62, 22, -110)
  lg.ellipse("fill", 14, -62, 26, 5, 12)
  local cape = sin(S.t * 8) * 6
  lg.polygon("fill", -6, -40, -50 + cape, -20, -40, 0)
  lg.pop()
  for i = 1, 3 do
    if G.R:random() < 0.3 then G:spark(x - 110, y + 10, -40, (G.R:random() - 0.5) * 30, 1, {0.6, 1, 0.4}, 5, 30, true) end
  end
  -- the cauldron, bubbling
  if not painted then
    lg.setColor(0.08, 0.08, 0.1, 1)
    lg.ellipse("fill", 384, 880, 140, 90, 32)
    lg.rectangle("fill", 250, 820, 268, 30, 10, 10, 6)
  end
  lg.setColor(0.35, 0.9, 0.3, 1)
  lg.ellipse("fill", 384, 830, 120, 22, 32)
  for i = 0, 5 do
    local b = (S.t * 0.8 + i * 0.17) % 1
    lg.setColor(0.5, 1, 0.4, 1 - b)
    lg.circle("fill", 300 + i * 34, 828 - b * 20, 6 + b * 8, 10)
  end
  if G.R:random() < 0.4 then G:puff(330 + G.R:random() * 110, 820, {0.5, 1, 0.5}, 40, 0, 2.5, 12, 0.25) end
  lg.setColor(1, 0.45, 0.1, 0.6 + 0.3 * sin(S.t * 10))
  lg.polygon("fill", 320, 970, 384, 920, 448, 970)
end

function D.dark(lt, len)
  lg.setColor(0, 0, 0, 1)
  lg.rectangle("fill", 0, 0, W, H)
  -- eyes in the dark, blinking
  for i, e in ipairs(S.eyes) do
    local blink = (floor(S.t * 0.7 + i * 1.3) % 5 == 0) and 0.2 or 1
    lg.setColor(1, 1, 1, blink)
    lg.ellipse("fill", e[1] - 9, e[2], 6, 8 * blink + 1, 10)
    lg.ellipse("fill", e[1] + 9, e[2], 6, 8 * blink + 1, 10)
    lg.setColor(0.15, 0.25, 0.9, blink)
    lg.circle("fill", e[1] - 9 + sin(S.t + i) * 2, e[2] + 1, 3, 8)
    lg.circle("fill", e[1] + 9 + sin(S.t + i) * 2, e[2] + 1, 3, 8)
  end
  -- the flashlight's beam, sweeping; what it finds
  if lt > 14 and lt < 52 then
    local bx = 384 + sin((lt - 14) * 0.6) * 300
    local by = 520 + cos((lt - 14) * 0.45) * 220
    lg.setBlendMode("add")
    lg.setColor(1, 0.95, 0.75, 0.22)
    lg.polygon("fill", 384, 1024, bx - 110, by, bx + 110, by)
    lg.circle("fill", bx, by, 110, 32)
    lg.setBlendMode("alpha")
    for i, c in ipairs(GHOSTS) do
      local gx, gy = 140 + (i - 1) * 165, 420 + (i % 2) * 220
      local d = math.sqrt((gx - bx) ^ 2 + (gy - by) ^ 2)
      if d < 120 then C.fx.ghost(gx, gy, 34, c, 1, S.t, true, false, clamp(1 - d / 120, 0, 1)) end
    end
  end
  -- BOO!
  if lt >= 54 and lt < 60 then
    local k = clamp((lt - 54) / 0.25, 0, 1)
    C.fx.ghost(384, 520, 60 + k * 200, GHOSTS[1], 1, S.t, false, false, 1)
    G:caption("BOO!", 820, 120, 0xffffff, 1, 0.6 + 0.4 * k)
  end
  if lt >= 60 then
    G:plate("GOTCHA", 460, 50, 0xff8000, L.window(lt, 60, 69, 1))
  end
end

function D.finale(lt, len)
  local painted = art("finale")
  if not painted then
    G:gradient(0, 0, W, H, {0.08, 0.02, 0.12}, {0.25, 0.08, 0.15})
    moon(600, 160, 70)
  end
  for i = 1, 6 do bat(((S.t * 50 + i * 130) % (W + 120)) - 60, 120 + sin(S.t + i) * 40 + i * 30, 1, S.t + i) end
  G:caption("HAPPY", 300, 56, 0xffffff, L.window(lt, 0.5, len, 1))
  G:caption("HALLOWEEN", 370, 84, 0xff8000, L.window(lt, 1, len, 1))
  local faces = {"pac", "tri", "ghost", "tri", "pac"}
  for i = 1, 5 do pumpkin(110 + (i - 1) * 137, 760, 56, {faces[i], 1}, true, S.t) end
  if not painted then G:gradient(0, 840, W, H, {0.08, 0.05, 0.08}, {0.03, 0.02, 0.04}) end
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
  for _, n in ipairs({"open", "house", "kitchen", "street", "graveyard", "witch", "finale"}) do
    S.art[n] = G:art("halloween", n)
  end
  local R = G.R
  S.stars = {}
  for i = 1, 80 do S.stars[i] = {R:random() * W, R:random() * 600} end
  S.eyes = {}
  for i = 1, 12 do S.eyes[i] = {60 + R:random() * (W - 120), 120 + R:random() * 760} end
  for _, s in ipairs(SCENES) do if s[4] then G:label(s[4], 56, 0xffffff) end end
  for _, l in ipairs({{"PARTYCADE", 54, 0xff4fd8}, {"PRESENTS", 26, 0x6ef0c8}, {"HALLOWEEN", 84, 0xff8000},
                      {"HAPPY", 56, 0xffffff}, {"BOO!", 120, 0xffffff}, {"GOTCHA", 50, 0xff8000},
                      {"THE CANDLES ARE LIT", 34, 0xff8000}, {"NICE COSTUMES, EVERYONE", 34, 0xff8000}}) do
    G:label(l[1], l[2], l[3])
  end
end

function M.act() return S and scene_at(S.t)[2] or "open" end
function M.music() return S and scene_at(S.t)[3] or "hw_toccata" end

function M.update(dt)
  if not S then return false end
  G:step(dt)
  S.t = G.t
  local sc, lt = scene_at(S.t)
  if sc[2] == "house" and floor((S.t - dt) / 13) ~= floor(S.t / 13) then C.sfx("thunder") end
  if sc[2] == "dark" and lt - dt < 54 and lt >= 54 then C.sfx("boo") end
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
    lg.setColor(0.02, 0.0, 0.04, 0.6 * b)
    lg.rectangle("fill", 0, H - 50, W, 50)
    G:text(sc[5], 0, H - 38, 20, {1, 0.65, 0.3}, b)
  end
  local f = 1 - min(lt / 1.2, (len - lt) / 1.2, 1)
  if f > 0 then
    lg.setColor(0, 0, 0, f)
    lg.rectangle("fill", 0, 0, W, H)
  end
end

return M
