-- Halloween: the ghosts' own holiday. Home's show for the second half of October (shows.lua's calendar; on the
-- 31st it plays into the night), nine minutes. Every scene a story with its own camera (SHOWS_BLUEPRINT.md):
--   0:00  STARLIGHT PRESENTS ... HALLOWEEN, lightning                             (Toccata, Bach, 1704)
--   0:10  The haunted house on the hill: up the path on a dare, the door creaking open by itself, room by room
--         (the windows lighting), AAAAH!, out at a run: it was the cat
--   1:30  Pumpkin carving: each carver's own pumpkin, the goop flying (Clyde's caves in), candles lit one by one
--                                                                                  (Pumpkin Patch)
--   2:40  Trick or treat: Pac-Man went as a ghost, the ghosts went as Pac-Man, door to door  (In the Hall of the
--         Mountain King, Grieg, 1875: faster and faster): three doors (candy, a dog, a skeleton with full-size
--         bars), the bags filling, the trading on the curb
--   4:10  The graveyard dance: a hand out of the ground, the skeletons up one by one, Pac-Man's boombox, a head
--         that rolls off, the conga, the rooster: back in               (Skeleton Swing)
--   5:30  The witch lands at her cauldron: the ghosts bring the ingredients, the potion changes colour, BANG,
--         Pac-Man green for a moment; she flies off with him                    (Theremin Waltz)
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

-- A pumpkin; face: nil (plain), or carved: {kind, k (0..1 how far carved)}, lit (candle glow), dim (0..1 dark room)
local function pumpkin(x, y, r, face, lit, t, dim)
  local b = lit and 1 or (1 - 0.65 * (dim or 0))
  lg.setColor(0.85 * b, 0.4 * b, 0.05 * b, 1)
  lg.ellipse("fill", x - r * 0.45, y, r * 0.6, r * 0.85, 24)
  lg.ellipse("fill", x + r * 0.45, y, r * 0.6, r * 0.85, 24)
  lg.setColor(0.95 * b, 0.5 * b, 0.08 * b, 1)
  lg.ellipse("fill", x, y, r * 0.65, r * 0.9, 24)
  lg.setColor(0.3 * b, 0.45 * b, 0.15 * b, 1)
  lg.rectangle("fill", x - r * 0.08, y - r * 1.1, r * 0.16, r * 0.3, 3, 3, 4)
  if not face then return end
  local k = face[2]
  local glow = lit and (0.8 + 0.2 * sin(t * 12 + x)) or 0
  local col = lit and {1, 0.86 + 0.12 * glow, 0.35 + 0.35 * glow} or {0.35 * b, 0.15 * b, 0.02 * b}
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
    elseif kind == "angry" then
      lg.polygon("fill", x - r * 0.48, y - r * 0.38, x - r * 0.10, y - r * 0.18, x - r * 0.44, y - r * 0.10)
      lg.polygon("fill", x + r * 0.48, y - r * 0.38, x + r * 0.10, y - r * 0.18, x + r * 0.44, y - r * 0.10)
    elseif kind == "cat" then
      for d = -1, 1, 2 do
        lg.ellipse("fill", x + d * r * 0.32, y - r * 0.24, r * 0.16, r * 0.11, 12)
        lg.setLineWidth(max(1.5, r * 0.04))
        lg.line(x + d * r * 0.28, y + r * 0.04, x + d * r * 0.65, y - r * 0.02)
        lg.line(x + d * r * 0.28, y + r * 0.12, x + d * r * 0.65, y + r * 0.16)
      end
      lg.setLineWidth(1)
    elseif kind == "derp" then
      lg.circle("fill", x - r * 0.3, y - r * 0.26, r * 0.2, 14)
      lg.circle("fill", x + r * 0.32, y - r * 0.18, r * 0.12, 12)
    elseif kind == "star" then
      L.star(x - r * 0.32, y - r * 0.24, r * 0.2, 0)
      L.star(x + r * 0.32, y - r * 0.24, r * 0.2, 0)
    else
      for d = -1, 1, 2 do lg.polygon("fill", x + d * r * 0.3, y - r * 0.45, x + d * r * 0.12, y - r * 0.1, x + d * r * 0.48, y - r * 0.1) end
    end
  end
  if k > 0.45 then lg.polygon("fill", x, y - r * 0.05, x - r * 0.1, y + r * 0.12, x + r * 0.1, y + r * 0.12) end
  if k > 0.75 then
    if kind == "derp" then
      lg.arc("fill", "pie", x, y + r * 0.22, r * 0.36, 0.1, pi - 0.1, 14)
      lg.setColor(0.95 * b, 0.5 * b, 0.08 * b, 1)
      lg.rectangle("fill", x + r * 0.04, y + r * 0.22, r * 0.14, r * 0.16)
    else
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
end

-- A skeleton dancing (a jointed stick figure): phase t, optional headless
local function skeleton(x, y, s, t, headless)
  lg.setColor(0.92, 0.92, 0.88, 1)
  lg.setLineWidth(5 * s)
  local sw = sin(t * 4)
  local hx, hy = x + sw * 6 * s, y - 120 * s
  if not headless then
    lg.circle("fill", hx, hy, 16 * s, 16)
    lg.setColor(0.08, 0.05, 0.1, 1)
    lg.circle("fill", hx - 6 * s, hy - 2 * s, 4 * s, 8)
    lg.circle("fill", hx + 6 * s, hy - 2 * s, 4 * s, 8)
    lg.rectangle("fill", hx - 6 * s, hy + 7 * s, 12 * s, 3 * s)
    lg.setColor(0.92, 0.92, 0.88, 1)
  end
  lg.line(hx, hy + 16 * s, x, y - 50 * s)
  for i = 0, 3 do lg.line(x - 14 * s + sw * 3 * s, y - 92 * s + i * 10 * s, x + 14 * s + sw * 3 * s, y - 92 * s + i * 10 * s) end
  local a1, a2 = sin(t * 4) * 1.2, -sin(t * 4) * 1.2
  lg.line(x, y - 96 * s, x - 30 * s, y - 96 * s - a1 * 30 * s, x - 46 * s, y - 120 * s - a1 * 20 * s)
  lg.line(x, y - 96 * s, x + 30 * s, y - 96 * s - a2 * 30 * s, x + 46 * s, y - 120 * s - a2 * 20 * s)
  local k1, k2 = abs(sin(t * 4)), abs(cos(t * 4))
  lg.line(x, y - 50 * s, x - 18 * s, y - 24 * s - k1 * 14 * s, x - 22 * s, y)
  lg.line(x, y - 50 * s, x + 18 * s, y - 24 * s - k2 * 14 * s, x + 22 * s, y)
  lg.setLineWidth(1)
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

local function prog(lt, a, b) return ease((lt - a) / (b - a)) end
local function lin(lt, a, b) return clamp((lt - a) / (b - a), 0, 1) end

-- one of the cast: 0 Pac-Man, 1-4 the ghosts
local function guest(who, x, y, r, lx, ly, mood, open, al)
  if who == 0 then
    local f = (lx or 1) >= 0 and 1 or -1
    if mood == "scared" then
      L.pac(x, y, r, f > 0 and 0 or pi, S.t, 0.95, al)
      lg.setColor(1, 1, 1, al or 1)
      lg.circle("fill", x + r * 0.12 * f, y - r * 0.5, r * 0.18, 10)
      lg.setColor(0.1, 0.05, 0.1, al or 1)
      lg.circle("fill", x + r * 0.12 * f, y - r * 0.5, r * 0.08, 8)
    else
      L.pac(x, y, r, f > 0 and 0 or pi, S.t, open, al)
    end
  else
    L.ghost(x, y, r, GHOSTS[who], S.t + who, lx, ly, mood, al)
  end
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

local function bolt(x0)
  local pts = {x0, 0, x0 - 22, 110, x0 + 18, 130, x0 - 30, 270, x0 + 12, 290, x0 - 44, 460}
  lg.setColor(0.65, 0.7, 1, 0.45)
  lg.setLineWidth(12)
  lg.line(pts)
  lg.setColor(1, 1, 1, 0.95)
  lg.setLineWidth(4)
  lg.line(pts)
  lg.setLineWidth(1)
end

function D.open(lt, len)
  if not art("open") then G:gradient(0, 0, W, H, {0.04, 0.0, 0.08}, {0.15, 0.04, 0.12}) end
  local f1 = lt > 1.5 and lt < 1.72
  local f2 = lt > 6 and lt < 6.18
  if f1 or f2 then
    lg.setColor(0.8, 0.8, 1, 0.45)
    lg.rectangle("fill", 0, 0, W, H)
    bolt(f1 and 210 or 560)
  end
  lg.setColor(0.05, 0.02, 0.08, 1)
  for i = 1, 6 do bat(((S.t * 60 + i * 140) % (W + 120)) - 60, 200 + sin(S.t + i) * 60 + i * 40, 1.2, S.t + i) end
  local a = L.window(lt, 0.5, 4.5, 0.8)
  G:brand(400, a)
  G:caption("PRESENTS", 472, 26, 0x6ef0c8, a)
  G:caption("HALLOWEEN", 430, 84, 0xff8000, L.window(lt, 4.8, 10, 0.8))
end
CUES.open = {{1.5, "thunder"}, {6.0, "thunder"}}

-- ------------------------------------------------------------------ the haunted house: on a dare
local HX, HY = 384, 600
local DOOR = {384, 590}
local WINDOWS = {{-110, -110}, {-40, -110}, {40, -110}, {-110, -50}, {80, -50}, {95, -260}}
local INSIDE = {30, 52}                     -- in the house
local function walker(lt, i)
  -- up the path from the gate (bottom left) to the door, one after another; in; out running
  local t0 = 3 + i * 1.2
  local f = lin(lt, t0, t0 + 14)
  local x = lerp(-60, DOOR[1] - 60 + i * 30, f)
  local y = lerp(980, DOOR[2] + 30, f) - L.hop(lt + i, 0.5, 6) * (f < 1 and 1 or 0)
  if lt > INSIDE[1] - 4 + i * 0.6 then
    local g = prog(lt, INSIDE[1] - 4 + i * 0.6, INSIDE[1] - 3 + i * 0.6)
    x, y = lerp(x, DOOR[1], g), lerp(y, DOOR[2] + 10, g)
  end
  if lt > INSIDE[2] then
    -- out at a run, down the hill to the gate, huddled; then away for good when the cat comes too
    local g = prog(lt, INSIDE[2] + i * 0.25, INSIDE[2] + 4 + i * 0.25)
    x, y = lerp(DOOR[1], 180 + i * 70, g), lerp(DOOR[2] + 20, 930, g)
    if g < 1 then y = y - abs(sin(lt * 14 + i)) * 20 end
    if lt > 71 then
      local h = lin(lt, 71 + i * 0.15, 74 + i * 0.15)
      x = lerp(x, -120 - i * 40, h)
      y = y - abs(sin(lt * 14 + i)) * 20 * (h > 0 and h < 1 and 1 or 0)
    end
  end
  return x, y
end
function D.house(lt, len)
  local painted = art("house")
  if not painted then G:gradient(0, 0, W, 700, {0.05, 0.02, 0.12}, {0.3, 0.12, 0.3}) end
  -- the windows: dark, then lighting one by one as they go through the house, a shadow in each
  for i, w in ipairs(WINDOWS) do
    local t0 = INSIDE[1] + (i - 1) * 3.2
    local on = lt > t0 and lt < INSIDE[2] + 1
    if not on then
      local fl = (floor(S.t * (1 + i * 0.3)) + i) % 6 == 0
      lg.setColor(1, 0.8, 0.3, fl and 0.4 or 0.06)
    else
      lg.setColor(1, 0.75, 0.25, 0.95)
    end
    lg.rectangle("fill", HX + w[1], HY + w[2], 34, 44)
    if on then
      C.fx.glow(HX + w[1] + 17, HY + w[2] + 22, 40, 40, 1, 0.7, 0.3, 0.4)
      local who = (i - 1) % 5
      lg.setColor(0.05, 0.02, 0.05, 0.85)
      local sx = HX + w[1] + 17 + sin(S.t * 2 + i) * 6
      local jump = (lt > t0 + 1.6 and lt < t0 + 2.4) and 8 or 0
      if who == 0 then lg.arc("fill", "pie", sx, HY + w[2] + 30 - jump, 12, 0.5, 2 * pi - 0.5, 14)
      else lg.arc("fill", "pie", sx, HY + w[2] + 28 - jump, 11, pi, 2 * pi, 12) lg.rectangle("fill", sx - 11, HY + w[2] + 28 - jump, 22, 12) end
    end
  end
  -- what's in each room when they light it: out it comes (a bat, a ghost-sheet, a skull, a bat...) at the window
  for i, w in ipairs(WINDOWS) do
    local t0 = INSIDE[1] + (i - 1) * 3.2 + 1.4
    local f = (lt - t0) / 1.2
    if f > 0 and f < 1 then
      local cx, cy = HX + w[1] + 17 + f * (i % 2 == 0 and 60 or -60), HY + w[2] + 22 - f * 40
      local sc = 0.4 + f * 1.8
      lg.push()
      lg.translate(cx, cy)
      lg.scale(sc, sc)
      local kind = i % 3
      if kind == 1 then                            -- a bat
        local fl = sin(S.t * 30) * 10
        lg.setColor(0.05, 0.02, 0.06, 1)
        lg.ellipse("fill", 0, 0, 8, 6, 10)
        lg.polygon("fill", 0, 0, -26, -8 - fl, -14, 6)
        lg.polygon("fill", 0, 0, 26, -8 - fl, 14, 6)
        lg.setColor(1, 0.2, 0.2, 1)
        lg.circle("fill", -3, -2, 1.5, 6) lg.circle("fill", 3, -2, 1.5, 6)
      elseif kind == 2 then                        -- a sheet ghost, waving
        lg.setColor(0.95, 0.95, 1, 0.9)
        lg.arc("fill", "pie", 0, 0, 14, pi, 2 * pi, 12)
        lg.rectangle("fill", -14, 0, 28, 16)
        lg.setColor(0, 0, 0, 1)
        lg.circle("fill", -5, -3, 2.5, 6) lg.circle("fill", 5, -3, 2.5, 6)
      else                                         -- a grinning skull
        lg.setColor(0.95, 0.93, 0.85, 1)
        lg.circle("fill", 0, -2, 12, 14)
        lg.rectangle("fill", -6, 6, 12, 7, 2, 2, 4)
        lg.setColor(0, 0, 0, 1)
        lg.circle("fill", -4.5, -3, 3, 6) lg.circle("fill", 4.5, -3, 3, 6)
      end
      lg.pop()
    end
  end
  -- the scream: every window flashing at once
  if lt > 49 and lt < 52 then
    lg.setColor(1, 1, 1, (floor(S.t * 12) % 2) * 0.5)
    for _, w in ipairs(WINDOWS) do lg.rectangle("fill", HX + w[1], HY + w[2], 34, 44) end
  end
  -- the door, creaking open by itself
  local open = prog(lt, 22, 25) * (1 - prog(lt, 57, 58))
  lg.setColor(0.03, 0.01, 0.03, 1)
  lg.rectangle("fill", DOOR[1] - 20, DOOR[2] - 30, 40 * open, 50)
  -- bats out of the chimney
  lg.setColor(0.05, 0.02, 0.08, 1)
  for i = 1, 5 do bat(((S.t * (40 + i * 6) + i * 180) % (W + 160)) - 80, 300 + sin(S.t * 0.8 + i * 2) * 120, 0.9, S.t + i) end
  -- the cast: up the path, in, out at a run; and what scared them: a little black cat
  for i, who in ipairs({0, 1, 2, 3, 4}) do
    local x, y = walker(lt, i - 1)
    local nx = walker(lt + 0.05, i - 1)
    local dx = nx - x
    local lx = dx < -0.5 and -1 or (dx > 0.5 and 1 or 1)
    local inside = lt > INSIDE[1] - 3 + (i - 1) * 0.6 and lt < INSIDE[2]
    if not inside then
      local mood = lt > INSIDE[2] and "scared" or ((lt > 22 and lt < 26) and "wide" or nil)
      if lt > 60 and lt < 69 then mood = (lt > 64 and "happy" or "wide") end
      guest(who, x, y - 30, 26, lx, -0.4, mood, nil)
    end
  end
  if lt > 54 then
    local cx = lerp(DOOR[1], DOOR[1] + 40, prog(lt, 55, 57))
    local cy0 = 0
    if lt > 62 then
      cx = L.path(lt, {{62, DOOR[1] + 40, 0}, {69, 560, 0}, {80, 560, 0}})
      cy0 = lerp(0, 330, prog(lt, 62, 69))
    end
    local csc = lerp(1, 1.8, prog(lt, 62, 69))
    local hiss = lt > 68.5
    lg.push()
    lg.translate(cx, DOOR[2] + cy0)
    lg.scale(csc, csc)
    lg.translate(-cx, -DOOR[2])
    lg.setColor(0.04, 0.03, 0.05, 1)
    if hiss then
      lg.arc("fill", "pie", cx - 2, DOOR[2] + 12, 17, pi, 2 * pi, 14)
      lg.rectangle("fill", cx - 16, DOOR[2] + 10, 6, 8)
      lg.rectangle("fill", cx + 8, DOOR[2] + 10, 6, 8)
    else
      lg.ellipse("fill", cx, DOOR[2] + 10, 16, 10, 12)
    end
    lg.circle("fill", cx + 14, DOOR[2] - 2, 9, 12)
    lg.polygon("fill", cx + 8, DOOR[2] - 8, cx + 10, DOOR[2] - 18, cx + 14, DOOR[2] - 10)
    lg.polygon("fill", cx + 16, DOOR[2] - 10, cx + 20, DOOR[2] - 18, cx + 22, DOOR[2] - 8)
    lg.setLineWidth(hiss and 6 or 3)
    lg.line(cx - 14, DOOR[2] + 8, cx - 22, DOOR[2] - (hiss and 18 or 10) + sin(S.t * (hiss and 10 or 4)) * 4)
    lg.setLineWidth(1)
    if hiss then C.fx.glow(cx + 14, DOOR[2] - 3, 22, 16, 1, 0.9, 0.2, 0.55) end
    lg.setColor(1, 0.9, 0.2, 1)
    lg.circle("fill", cx + 11, DOOR[2] - 3, hiss and 2.5 or 2, 6)
    lg.circle("fill", cx + 17, DOOR[2] - 3, hiss and 2.5 or 2, 6)
    lg.pop()
  end
  -- lightning
  for _, t0 in ipairs({8, 21, 44}) do
    if lt > t0 and lt < t0 + 0.12 or (lt > t0 + 0.25 and lt < t0 + 0.33) then
      lg.setColor(0.85, 0.85, 1, 0.45)
      lg.rectangle("fill", 0, 0, W, H)
    end
  end
  if lt > 14 and lt < 18 then
    local cx4, cy4 = walker(lt, 4)
    G:say("I DARE YOU.", cx4, cy4 - 65, 24, 1)
  end
  if lt > 23 and lt < 26 then G:say("CREEEAK...", DOOR[1], DOOR[2] - 50, 24, 1) end
  if lt > 49 and lt < 52 then G:say("AAAAAH!", HX, HY - 300, 32, 1) end
  if lt > 57 and lt < 61 then G:say("MEOW.", DOOR[1] + 40, DOOR[2] - 40, 24, 1) end
  if lt > 63 and lt < 67 then G:say("...IT WAS JUST A CAT.", 330, 860, 22, 1) end
  if lt > 68.5 and lt < 70.8 then G:say("MEOW!", 560, 860, 26, 1) end
  if lt > 71 and lt < 74 then
    local fx2 = walker(lt, 2)
    G:say("AAAAH!", clamp(fx2, 100, W - 100), 860, 28, 1)
  end
end
CAM.house = function(lt)
  local x2, y2 = walker(lt, 2)
  if lt > 3 and lt < 18 then return L.shot(0, {{0, x2 + 40, y2 - 40, 1.45}}, W, H) end
  local keys = {{0, 384, 512, 1}, {18, walker(18, 2) + 40, 610, 1.45}, {22, DOOR[1], DOOR[2] - 20, 1.9}, {27, DOOR[1], DOOR[2] - 20, 1.9},
                {INSIDE[1], HX, HY - 120, 1.35}}
  for i, w in ipairs(WINDOWS) do
    keys[#keys + 1] = {INSIDE[1] + (i - 1) * 3.2 + 0.5, HX + w[1] + 17, HY + w[2] + 22, 2.4}
  end
  for _, k in ipairs({{49, HX, HY - 100, 1.15}, {52, HX, HY + 100, 1.1}, {54.5, DOOR[1] + 20, DOOR[2], 2.2}, {60, DOOR[1] + 20, DOOR[2], 2.2},
                      {62.5, 400, 820, 1.5}, {74, 360, 840, 1.5}, {80, 384, 640, 1.1}}) do keys[#keys + 1] = k end
  local x, y, z = L.shot(lt, keys, W, H)
  return x, y, z, (lt > 49 and lt < 50) and 7 or 0
end
CUES.house = {{8, "thunder"}, {21, "thunder"}, {44, "thunder"}, {23, "boo", 0.5}, {49, "boo"}, {49.2, "boom", 0.4}, {52, "whoosh"},
              {57, "boing", 0.5}, {69.5, "boing"}, {71, "boo"}, {71.2, "whoosh"}}
for i = 1, #WINDOWS do
  CUES.house[#CUES.house + 1] = {INSIDE[1] + (i - 1) * 3.2, "clunk", 0.4}
  CUES.house[#CUES.house + 1] = {INSIDE[1] + (i - 1) * 3.2 + 1.4, i % 3 == 1 and "screech" or (i % 3 == 2 and "boo" or "boing"), 0.35}
end

-- ------------------------------------------------------------------ pumpkin carving
local FACES = {"pac", "angry", "ghost", "cat", "derp", "star"}
local CARVER = {0, 1, 2, 3, 4, 0}
local function ppos(i) return 130 + ((i - 1) % 3) * 254, i <= 3 and 560 or 830 end
local function carve_t(i) return 3 + (i - 1) * 7 end
local LIGHT_T = 48
local LIGHT_PATH = {{LIGHT_T - 1.5, -60, 500}}
for i = 1, 6 do
  local x, y = ppos(i)
  LIGHT_PATH[#LIGHT_PATH + 1] = {LIGHT_T + (i - 1) * 1.2, x - 72, y - 50}
end
LIGHT_PATH[#LIGHT_PATH + 1] = {LIGHT_T + 7.5, W + 60, 780}
function D.pumpkins(lt, len)
  if not art("kitchen") then G:gradient(0, 0, W, H, {0.12, 0.06, 0.12}, {0.06, 0.03, 0.06}) end
  -- the room going dark for the candles
  local dark = prog(lt, LIGHT_T - 2, LIGHT_T)
  if dark > 0 then
    lg.setColor(0, 0, 0.02, 0.75 * dark)
    lg.rectangle("fill", 0, 0, W, H)
  end
  for i = 1, 6 do
    local x, y = ppos(i)
    local t0 = carve_t(i)
    local k = clamp((lt - t0 - 1.5) / 4.5, 0, 1)
    local lit = lt > LIGHT_T + (i - 1) * 1.2 and k >= 1
    -- Clyde's (the fifth) caves in when it's done... and gets a smooth lid-fix
    local squash = (i == 5) and (1 - 0.25 * prog(lt, t0 + 6, t0 + 6.35) * (1 - prog(lt, t0 + 8.4, t0 + 9.2))) or 1
    -- the reveal: each finished one spun 180 deg to face us, face revealed at 90 deg (t0 + 6.2) with a hop
    local spinning = lt > t0 + 5.6 and lt < t0 + 6.8
    local spin = spinning and max(0.06, abs(cos((lt - t0 - 5.6) / 1.2 * pi))) or 1
    local show_face = lt >= t0 + 6.2
    local reveal_hop = (lt > t0 + 6.2 and lt < t0 + 7) and L.hop(lt - t0 - 6.2, 0.8, 40) or 0
    lg.push()
    lg.translate(x, y + 90 * (1 - squash) - reveal_hop)
    lg.scale(spin, squash)
    lg.setColor(1, 0.5, 0.05, 1)
    pumpkin(0, 0, 90, show_face and {FACES[i], 1} or nil, lit, S.t, dark)
    lg.pop()
    -- the carver beside it: Carvers 3 & 6 on left so they aren't clipped; Clyde stays through UH-OH
    local who = CARVER[i]
    local side = (i % 3 == 0) and -1 or 1
    local cx = x + side * 110
    local tend = (i == 5) and (t0 + 9.5) or (t0 + 7)
    if lt > t0 - 1 and lt < tend then
      local proud = lt > t0 + 6 and (i ~= 5 or lt > t0 + 9)
      local mood = (i == 5 and lt > t0 + 6 and lt < t0 + 9) and "wide" or (proud and "happy" or nil)
      guest(who, cx, y + 40 - (proud and L.hop(lt, 0.4, 16) or 0), 38, -side, 0, mood, nil)
      if lt < t0 + 1.5 then
        lg.setColor(0.4, 0.25, 0.1, 1)
        lg.rectangle("fill", x - 10, y - 140 - (lt - t0) * 30, 20, 20)
      elseif k < 1 then
        local kx = x + sin(S.t * 20) * 30
        lg.setColor(0.85, 0.86, 0.9, 1)
        lg.polygon("fill", kx, y - 40, kx + 8, y - 120, kx + 14, y - 118, kx + 6, y - 38)
        lg.setColor(0.35, 0.2, 0.1, 1)
        lg.rectangle("fill", kx + 6, y - 150, 8, 32)
      end
    end
  end
  -- Pac-Man sliding along rows with a glowing matchstick
  if lt > LIGHT_T - 1.5 and lt < LIGHT_T + 7.5 then
    local mx, my, mdir = L.path(lt, LIGHT_PATH)
    guest(0, mx, my, 26, mdir < 0 and -1 or 1, 0, nil, nil)
    local fx = mx + (mdir < 0 and -34 or 34)
    local fy = my - 4
    lg.setColor(0.75, 0.55, 0.3, 1)
    lg.setLineWidth(3)
    lg.line(mx + (mdir < 0 and -18 or 18), my + 4, fx, fy)
    lg.setLineWidth(1)
    C.fx.glow(fx, fy - 4, 26, 26, 1, 0.7, 0.2, 0.85)
    lg.setColor(1, 0.85, 0.25, 1)
    lg.ellipse("fill", fx, fy - 5, 4, 7 + sin(S.t * 24) * 1.5, 10)
  end
  if lt > carve_t(5) + 6.2 and lt < carve_t(5) + 9 then G:say("UH-OH.", select(1, ppos(5)) + 110, 740, 24, 1) end
  if lt > LIGHT_T + 7.5 and lt < LIGHT_T + 12 then G:say("OOOOH!", 384, 420, 30, 1) end
  G:plate("THE CANDLES ARE LIT", 120, 34, 0xff8000, L.window(lt, LIGHT_T + 8, 68, 1))
end
CAM.pumpkins = function(lt)
  local keys = {{0, 384, 512, 1}}
  for i = 1, 6 do
    local x, y = ppos(i)
    keys[#keys + 1] = {carve_t(i) - 0.2, x + 90, y + 20, 1.5}
    keys[#keys + 1] = {carve_t(i) + 3, x + 30, y - 20, 2.0}
    keys[#keys + 1] = {carve_t(i) + 6.6, x + 50, y - 10, 1.7}
  end
  keys[#keys + 1] = {LIGHT_T - 1, 384, 700, 1.05}
  for i = 1, 6 do
    local x, y = ppos(i)
    keys[#keys + 1] = {LIGHT_T + (i - 1) * 1.2, x, y, 1.45}
  end
  keys[#keys + 1] = {LIGHT_T + 9, 384, 690, 1.05}
  keys[#keys + 1] = {70, 384, 680, 1.1}
  return L.shot(lt, keys, W, H)
end
CUES.pumpkins = {{carve_t(5) + 6, "boing"}, {LIGHT_T - 2, "clunk"}, {LIGHT_T + 8, "cheer"}}
for i = 1, 6 do CUES.pumpkins[#CUES.pumpkins + 1] = {carve_t(i) + 5.6, "whoosh", 0.4} end
for i = 1, 6 do
  CUES.pumpkins[#CUES.pumpkins + 1] = {carve_t(i) + 0.5, "pop", 0.4}
  CUES.pumpkins[#CUES.pumpkins + 1] = {carve_t(i) + 6, "ding", 0.5}
  CUES.pumpkins[#CUES.pumpkins + 1] = {LIGHT_T + (i - 1) * 1.2, "chime", 0.4}
  for k = 0, 8 do
    CUES.pumpkins[#CUES.pumpkins + 1] = {carve_t(i) + 1.5 + k * 0.5, function()
      local x, y = ppos(i)
      for j = 1, 5 do G:spark(x, y - 40, (G.R:random() - 0.5) * 220, -80 - G.R:random() * 140, 0.8, {1, 0.75, 0.3}, 6, 500) end
    end}
  end
end

-- ------------------------------------------------------------------ trick or treat: door to door
local DOORS = {{135, 685}, {385, 685}, {635, 685}}
local VISIT = {12, 38, 62}                  -- when they're at each door
local function group_x(lt)
  return L.path(lt, {{0, -260, 0}, {VISIT[1] - 1, DOORS[1][1], 0}, {VISIT[1] + 12, DOORS[1][1], 0},
                     {VISIT[2] - 1, DOORS[2][1], 0}, {VISIT[2] + 3.5, DOORS[2][1], 0},
                     {VISIT[2] + 7.5, DOORS[2][1] - 240, 0}, {VISIT[2] + 9.5, DOORS[2][1] - 240, 0},
                     {VISIT[3] - 1, DOORS[3][1], 0}, {VISIT[3] + 11, DOORS[3][1], 0},
                     {75.5, 460, 0}, {83, 460, 0}, {89.5, W + 400, 0, "lin"}})
end
local function bag(lt)
  local n = 0
  for i, v in ipairs(VISIT) do if i ~= 2 and lt > v + 5 then n = n + (i == 3 and 2 or 1) end end
  return n
end
function D.trick(lt, len)
  if not art("street") then G:gradient(0, 0, W, 700, {0.05, 0.03, 0.15}, {0.2, 0.1, 0.25}) end
  -- the porch pumpkins, the doors opening at each visit
  for i, d in ipairs(DOORS) do
    lg.setColor(1, 0.5, 0.05, 1)
    pumpkin(d[1] - 75, 735, 22, {"tri", 1}, true, S.t)
    local open = prog(lt, VISIT[i] + 2, VISIT[i] + 3) * (1 - prog(lt, VISIT[i] + 9, VISIT[i] + 10))
    if open > 0 then
      lg.setColor(1, 0.8, 0.45, 1)
      lg.rectangle("fill", d[1] - 25, 620, 50 * open, 130)
      C.fx.glow(d[1], 690, 60, 80, 1, 0.75, 0.35, 0.4 * open)
      -- who answers: a hand with candy; a dog; a skeleton
      if open > 0.6 then
        if i == 1 then
          lg.setColor(0.95, 0.8, 0.65, 1)
          lg.rectangle("fill", d[1] - 10, 690, 40, 14, 6, 6, 4)
          lg.setColor(0.8, 0.3, 0.9, 1)
          if lt < VISIT[i] + 5 then lg.rectangle("fill", d[1] + 18, 680, 18, 10, 3, 3, 4) end
        elseif i == 2 then
          local bark = abs(sin(S.t * 12)) * 6
          lg.setColor(0.45, 0.3, 0.18, 1)
          lg.ellipse("fill", d[1], 730, 22, 14, 14)
          lg.circle("fill", d[1] + 16, 712 - bark, 12, 12)
          lg.ellipse("fill", d[1] + 8, 704 - bark, 5, 10, 8)
        else
          skeleton(d[1], 750, 0.75, S.t * (lt < VISIT[3] + 6 and 0 or 1))
          if lt > VISIT[3] + 5 and lt < VISIT[3] + 7 then
            C.fx.glow(d[1] + 45, 698, 44, 24, 1, 0.88, 0.3, 0.55)
            lg.setColor(0.95, 0.78, 0.2, 1)
            lg.rectangle("fill", d[1] + 18, 688, 54, 20, 4, 4, 4)
            lg.setColor(0.55, 0.3, 0.12, 1)
            lg.rectangle("fill", d[1] + 22, 691, 46, 14, 2, 2, 4)
            local gl = ((S.t * 2.5) % 1) * 40
            lg.setColor(1, 1, 0.85, 0.85)
            lg.polygon("fill", d[1] + 20 + gl, 706, d[1] + 26 + gl, 689, d[1] + 32 + gl, 689, d[1] + 26 + gl, 706)
          end
        end
      end
    end
  end
  -- the trick-or-treaters: Pac-Man under a sheet in front, the ghosts as Pac-Men
  local x0, _, gdir = group_x(lt)
  local walking = gdir ~= 0
  local run = lt > VISIT[2] + 3.5 and lt < VISIT[2] + 7.5
  local scared = run or (lt > VISIT[3] + 3 and lt < VISIT[3] + 5)
  local px = x0
  local py = 880 + (walking and abs(sin(S.t * 6)) * -6 or 0) - (scared and L.hop(lt, 0.4, 40) or 0)
  -- the sheet
  lg.setColor(0.96, 0.96, 0.98, 1)
  lg.arc("fill", "pie", px, py, 44, pi, 2 * pi, 24)
  lg.rectangle("fill", px - 44, py, 88, 50)
  for i = 0, 3 do lg.circle("fill", px - 33 + i * 22, py + 50, 11, 10) end
  lg.setColor(0.05, 0.05, 0.08, 1)
  local eh = scared and 14 or 10
  lg.ellipse("fill", px - 14, py - 14, 7, eh, 10)
  lg.ellipse("fill", px + 14, py - 14, 7, eh, 10)
  lg.setColor(1, 0.86, 0.15, 1)
  lg.polygon("fill", px - 16, py + 62, px + 16, py + 62, px, py + 48)
  -- his candy bag, filling (flips to left when running left)
  local n = bag(lt)
  local pbag_x = (run or gdir < 0) and (px - 70 - n * 4) or (px + 40)
  lg.setColor(1, 0.5, 0.05, 1)
  lg.rectangle("fill", pbag_x, py + 10, 30 + n * 4, 30 + n * 6, 6, 6, 4)
  for k = 1, n do
    rgba(({{1, 0.2, 0.3}, {0.3, 0.6, 1}, {0.9, 0.9, 0.2}, {0.6, 0.3, 0.9}})[k % 4 + 1])
    lg.rectangle("fill", pbag_x + 2 + (k % 3) * 9, py + 6 - (k % 2) * 4, 10, 6, 2, 2, 4)
  end
  for i, c in ipairs(GHOSTS) do
    local gx = px - 100 - (i - 1) * 80
    local gy = 900 + (walking and abs(sin(S.t * 6 + i)) * -6 or 0) - (scared and L.hop(lt + i * 0.2, 0.4, 40) or 0)
    local left = run or gdir < 0
    L.pac(gx, gy, 32, left and pi or 0, S.t + i * 0.2, scared and 0.95 or nil)
    rgba(c)
    for k = 0, 2 do lg.circle("fill", gx - 18 + k * 18, gy + 30, 7, 8) end
    lg.setColor(0.4, 0.25, 0.6, 1)
    local gbag_x = left and (gx - 40 - n * 2) or (gx + 22)
    lg.rectangle("fill", gbag_x, gy + 4, 18 + n * 2, 22 + n * 3, 4, 4, 4)
  end
  -- at the end: the candy out on the curb, sorted, traded
  if lt > 75 and lt < 85 then
    local f = lin(lt, 75, 77)
    for k = 1, 14 do
      rgba(({{1, 0.2, 0.3}, {0.3, 0.6, 1}, {0.9, 0.9, 0.2}, {0.6, 0.3, 0.9}})[k % 4 + 1])
      lg.rectangle("fill", lerp(pbag_x, 340 + (k % 7) * 26, f), lerp(py + 10, 970 - floor(k / 7) * 14, f), 16, 9, 2, 2, 4)
    end
  end
  if lt > VISIT[1] + 0.5 and lt < VISIT[1] + 3 then G:say("KNOCK KNOCK!", px, 790, 22, 1) end
  if lt > VISIT[1] + 3 and lt < VISIT[1] + 5.5 then G:say("TRICK OR TREAT!", px - 100, 820, 22, 1) end
  if lt > VISIT[2] + 3 and lt < VISIT[2] + 6 then G:say("WOOF!", DOORS[2][1] + 30, 670, 30, 1) end
  if lt > VISIT[3] + 3 and lt < VISIT[3] + 5 then G:say("AAAH!", px, 790, 28, 1) end
  if lt > VISIT[3] + 5 and lt < VISIT[3] + 8 then G:say("FULL-SIZE BARS!", DOORS[3][1] - 60, 640, 22, 1) end
  if lt > 78 and lt < 82 then G:say("TRADE YOU!", 300, 820, 22, 1) end
  G:plate("NICE COSTUMES, EVERYONE", 200, 34, 0xff8000, L.window(lt, 22, 34, 1.2))
end
CAM.trick = function(lt)
  local x0 = group_x(lt)
  local cx = x0 - 140
  local z = 1.35
  for _, v in ipairs(VISIT) do if lt > v and lt < v + 9 then z = lerp(z, 1.65, prog(lt, v, v + 1) * (1 - prog(lt, v + 8, v + 9))) end end
  if lt > 75 and lt < 86 then cx, z = 384, 1.4 end
  return L.shot(0, {{0, cx + 60, 780, z}}, W, H)
end
CUES.trick = {{VISIT[2] + 3, "boing"}, {VISIT[2] + 3.5, "whoosh"}, {VISIT[3] + 3, "boo", 0.6}, {VISIT[3] + 5, "cheer"}, {78, "pop", 0.4}}
for i, v in ipairs(VISIT) do
  CUES.trick[#CUES.trick + 1] = {v + 0.5, "clunk", 0.5}
  CUES.trick[#CUES.trick + 1] = {v + 1, "clunk", 0.5}
  CUES.trick[#CUES.trick + 1] = {v + 2, "ding", 0.5}
  if i ~= 2 then CUES.trick[#CUES.trick + 1] = {v + 5, "pop", 0.5} end
end

-- ------------------------------------------------------------------ the graveyard dance
local GRAVES = {{140, 900}, {280, 920}, {440, 900}, {600, 920}}
local function rise(lt, i) return prog(lt, 6 + (i - 1) * 4, 9 + (i - 1) * 4) end
local HEAD = {34, 42}                        -- the third skeleton loses its head
local CONGA = {50, 68}
local DAWN = 72
function D.graveyard(lt, len)
  if not art("graveyard") then G:gradient(0, 0, W, 760, {0.03, 0.05, 0.12}, {0.12, 0.2, 0.25}) end
  -- the headstones & grave dirt mounds (live: the skeletons climb out from behind them)
  for i, g in ipairs(GRAVES) do
    lg.setColor(0.45, 0.45, 0.5, 1)
    tombstone(g[1], g[2] - 40, 70, 60, ({"R.I.P.", "BONES", "R.I.P.", "BACK SOON"})[i])
    lg.setColor(0.14, 0.11, 0.09, 0.9)
    lg.ellipse("fill", g[1], g[2] + 4, 46, 13, 18)
  end
  -- the hand out of the ground first
  if lt > 3 and lt < 6.5 then
    lg.setColor(0.92, 0.9, 0.82, 1)
    local up = prog(lt, 3, 4.5) * 40
    lg.rectangle("fill", GRAVES[1][1] - 3, GRAVES[1][2] - up, 6, up)
    for k = -1, 1 do lg.rectangle("fill", GRAVES[1][1] + k * 6 - 1, GRAVES[1][2] - up - 14 - abs(k) * -4 + sin(S.t * 8 + k) * 2, 3, 14) end
  end
  -- the skeletons up out of the ground, dancing; the head; the conga; back in at dawn
  local dancing = lt > 22
  local cf = prog(lt, CONGA[1], CONGA[1] + 1.5) * (1 - prog(lt, CONGA[2] - 1.5, CONGA[2]))
  local skull_x = nil
  for i, g in ipairs(GRAVES) do
    local r = rise(lt, i)
    if r > 0 then
      local x, y = g[1], g[2] + (1 - r) * 120
      if cf > 0 then
        local f = lin(lt, CONGA[1], CONGA[2])
        local a = f * 2 * pi * 1.4 - i * 0.5
        x, y = lerp(x, 384 + cos(a) * 250, cf), lerp(y, 880 + sin(a) * 60, cf)
      end
      if lt > DAWN then
        local g2 = prog(lt, DAWN + i * 0.3, DAWN + 1 + i * 0.3)
        x, y = lerp(x, g[1], prog(lt, DAWN - 1, DAWN)), g[2] + g2 * 140
      end
      local headless = i == 3 and lt > HEAD[1] and lt < HEAD[2]
      lg.setColor(0.92, 0.9, 0.82, 1)
      skeleton(x, y, 1.1, S.t * (dancing and 1.2 or 0.2) + i * 0.5, headless)
      -- the third's head: off, rolling, chased by Clyde, back on
      if headless then
        local hx = L.path(lt, {{HEAD[1], x, 0}, {HEAD[1] + 3, x + 200, 0}, {HEAD[1] + 6, x + 120, 0}, {HEAD[2], x, 0}})
        skull_x = hx
        local hy = (lt < HEAD[2] - 1) and g[2] - 10 or lerp(g[2] - 10, y - 132, prog(lt, HEAD[2] - 1, HEAD[2]))
        lg.setColor(0.92, 0.9, 0.82, 1)
        lg.push()
        lg.translate(hx, hy)
        lg.rotate(lt * 6 * (lt < HEAD[1] + 3 and 1 or 0))
        lg.circle("fill", 0, 0, 16, 16)
        lg.setColor(0.08, 0.1, 0.12, 1)
        lg.circle("fill", -6, -2, 4, 8)
        lg.circle("fill", 6, -2, 4, 8)
        lg.pop()
      end
    end
  end
  -- the ghosts: watching from the trees, then joining in (Clyde chases the rolling skull)
  for i = 1, 4 do
    local gx = 130 + (i - 1) * 170 + sin(S.t * 2 + i) * 40
    local gy = 640 + sin(S.t * 3 + i) * 30
    local lx, mood = 0, (lt > 22 and lt < DAWN) and "happy" or "wide"
    if lt < 22 then gx, gy = lerp(-60 + (i % 2) * (W + 120), gx, prog(lt, 14 + i, 18 + i)), gy end
    if i == 4 and skull_x then
      local hf = prog(lt, HEAD[1], HEAD[1] + 0.8) * (1 - prog(lt, HEAD[2] - 0.8, HEAD[2]))
      gx, gy = lerp(gx, skull_x - 42, hf), lerp(gy, GRAVES[3][2] - 26, hf)
      lx, mood = 1, "wide"
    end
    if cf > 0 then
      local f = lin(lt, CONGA[1], CONGA[2])
      local a = f * 2 * pi * 1.4 - (i + 4) * 0.5
      gx, gy = lerp(gx, 384 + cos(a) * 250, cf), lerp(gy, 760 + sin(a) * 60, cf)
    end
    if lt > DAWN then gx, gy = lerp(gx, W + 80, prog(lt, DAWN, DAWN + 3)), gy - 100 * prog(lt, DAWN, DAWN + 3) end
    L.ghost(gx, gy, 28, GHOSTS[i], S.t + i, lx, 0, mood)
  end
  -- Pac-Man on the wall with a boombox + floating musical notes
  local bx = 680
  L.pac(bx, 700, 28, pi, S.t, nil)
  lg.setColor(0.2, 0.2, 0.25, 1)
  lg.rectangle("fill", bx - 70, 690, 50, 30, 4, 4, 4)
  if dancing and lt < DAWN then
    lg.setColor(0.6, 0.6, 0.7, 1)
    local pulse = 1 + abs(sin(S.t * 6)) * 0.3
    lg.circle("fill", bx - 58, 705, 8 * pulse, 10)
    lg.circle("fill", bx - 32, 705, 8 * pulse, 10)
    for k = 0, 2 do
      local np = (S.t * 0.9 + k * 0.33) % 1
      local nx = bx - 52 + k * 14 + sin(S.t * 4 + k) * 10
      local ny = 682 - np * 64
      lg.setColor(1, 0.85, 0.3, (1 - np) * 0.9)
      lg.circle("fill", nx, ny, 4.5, 8)
      lg.setLineWidth(2)
      lg.line(nx + 4, ny, nx + 4, ny - 14, nx + 11, ny - 11)
      lg.setLineWidth(1)
    end
  end
  -- dawn: the sky going pink, the rooster silhouette on the fence
  if lt > DAWN - 2 then
    local da = prog(lt, DAWN - 2, DAWN + 2)
    lg.setColor(1, 0.55, 0.45, 0.3 * da)
    lg.rectangle("fill", 0, 0, W, 760)
    local rx, ry = 600, 578
    lg.setColor(0.06, 0.04, 0.08, prog(lt, DAWN - 1.8, DAWN - 1.2))
    lg.ellipse("fill", rx, ry, 20, 13, 14)
    lg.polygon("fill", rx - 14, ry - 4, rx - 34, ry - 26, rx - 24, ry - 6, rx - 36, ry - 12, rx - 16, ry + 4)
    lg.circle("fill", rx + 16, ry - 16, 9, 12)
    lg.polygon("fill", rx + 11, ry - 24, rx + 15, ry - 32, rx + 19, ry - 25, rx + 23, ry - 30, rx + 24, ry - 22)
    local crow = (lt > DAWN - 1 and lt < DAWN + 1.5) and abs(sin(S.t * 10)) * 4 or 0
    lg.polygon("fill", rx + 24, ry - 18, rx + 35, ry - 15 - crow, rx + 24, ry - 13)
    lg.polygon("fill", rx + 24, ry - 13, rx + 33, ry - 10 + crow, rx + 24, ry - 10)
    lg.setLineWidth(3)
    lg.line(rx - 4, ry + 12, rx - 6, ry + 26)
    lg.line(rx + 6, ry + 12, rx + 8, ry + 26)
    lg.setLineWidth(1)
  end
  if lt > 3.5 and lt < 6 then G:say("...", GRAVES[1][1], 820, 26, 1) end
  if lt > 20 and lt < 23 then G:say("HIT IT!", bx, 640, 26, 1) end
  if lt > HEAD[1] + 0.5 and lt < HEAD[1] + 3.5 then G:say("MY HEAD!", GRAVES[3][1], 720, 22, 1) end
  if lt > DAWN - 1 and lt < DAWN + 2 then G:say("COCK-A-DOODLE-DOO!", 600, 520, 22, 1) end
  if lt > CONGA[1] and lt < CONGA[1] + 3 then G:say("CONGA!", 384, 640, 28, 1) end
end
CAM.graveyard = function(lt)
  local keys = {{0, 384, 512, 1}, {3, GRAVES[1][1] + 40, 840, 1.9}, {6, GRAVES[1][1] + 40, 820, 1.6}}
  for i, g in ipairs(GRAVES) do
    keys[#keys + 1] = {6 + (i - 1) * 4 + 0.5, g[1], 800, 1.6}
  end
  for _, k in ipairs({{20, 384, 700, 1.05}, {24, 384, 760, 1.2}, {HEAD[1], GRAVES[3][1] + 80, 820, 1.6}, {HEAD[2], GRAVES[3][1] + 40, 800, 1.5},
                      {CONGA[1], 384, 760, 1.05}, {CONGA[1] + 4, 200, 800, 1.5}, {CONGA[1] + 9, 560, 800, 1.5}, {CONGA[1] + 14, 300, 780, 1.4},
                      {CONGA[2], 384, 760, 1.1}, {DAWN, 384, 600, 1.05}, {80, 384, 512, 1}}) do
    keys[#keys + 1] = k
  end
  return L.shot(lt, keys, W, H)
end
CUES.graveyard = {{20, "clunk"}, {HEAD[1], "boing"}, {HEAD[2], "pop"}, {CONGA[1], "cheer"}, {DAWN - 1, "screech", 0.5}}
for i = 1, 4 do CUES.graveyard[#CUES.graveyard + 1] = {6 + (i - 1) * 4 + 1, "boo", 0.35} end

-- ------------------------------------------------------------------ the witch: the potion
local POT = {384, 830}
local LANDED = {14, 58}
local INGREDIENTS = {{"FROG", {0.3, 0.8, 0.3}}, {"EYEBALL", {0.95, 0.95, 0.95}}, {"SPIDER", {0.15, 0.1, 0.15}}, {"POWER PELLET", {1, 0.85, 0.7}}}
local POTIONS = {{0.5, 1, 0.5}, {0.3, 0.9, 1}, {0.7, 0.3, 0.9}, {1, 0.4, 0.8}, {1, 0.85, 0.3}}
local function ing_t(i) return 18 + (i - 1) * 7 end
local BANG = 48
local function witch_pos(lt)
  if lt < LANDED[1] then
    local p = lin(lt, 0, LANDED[1])
    return lerp(-150, 560, p), 420 - sin(p * pi) * 160 + p * 300, -0.12
  end
  if lt < LANDED[2] then return 560, 720, 0 end
  local p = lin(lt, LANDED[2], 70)
  return lerp(560, W + 200, p), 720 - p * 600, -0.3
end
local function potion(lt)
  local n = 1
  for i = 1, #INGREDIENTS do if lt > ing_t(i) + 1 then n = i + 1 end end
  return POTIONS[n]
end
function D.witch(lt, len)
  if not art("witch") then G:gradient(0, 0, W, H, {0.04, 0.02, 0.1}, {0.25, 0.08, 0.25}) end
  -- the potion's colour in the cauldron, bubbling
  local pc = potion(lt)
  rgba(pc, 1)
  lg.ellipse("fill", POT[1], POT[2], 120, 22, 32)
  for i = 0, 5 do
    local b = (S.t * 0.8 + i * 0.17) % 1
    lg.setColor(pc[1], pc[2], pc[3], 1 - b)
    lg.circle("fill", 300 + i * 34, POT[2] - 2 - b * 20, 6 + b * 8, 10)
  end
  C.fx.glow(POT[1], POT[2] - 20, 150, 60, pc[1], pc[2], pc[3], 0.35)
  -- the witch on her broom: in across the moon, landed, stirring, then off with a passenger
  local wx, wy, tilt = witch_pos(lt)
  lg.push()
  lg.translate(wx, wy)
  lg.rotate(tilt + (lt > LANDED[1] and lt < LANDED[2] and 0 or sin(S.t * 2) * 0.04))
  lg.setColor(0.45, 0.3, 0.15, 1)
  lg.setLineWidth(5)
  lg.line(-80, 10, 70, 0)
  lg.polygon("fill", -80, 10, -120, -6, -126, 26)
  lg.setColor(0.1, 0.05, 0.15, 1)
  lg.polygon("fill", -10, 4, 12, -50, 30, 0)
  lg.setColor(0.5, 0.85, 0.4, 1)
  lg.circle("fill", 14, -58, 10, 12)
  lg.setColor(0.1, 0.05, 0.15, 1)
  lg.polygon("fill", -6, -60, 36, -62, 22, -110)
  lg.ellipse("fill", 14, -62, 26, 5, 12)
  local cape = sin(S.t * 8) * 6
  lg.polygon("fill", -6, -40, -50 + cape, -20, -40, 0)
  if lt > LANDED[2] then L.pac(-46, -26, 18, 0, S.t, 0.8) end
  lg.setLineWidth(1)
  lg.pop()
  -- stirring: the big spoon
  if lt > LANDED[1] + 1 and lt < LANDED[2] then
    local a = S.t * 3
    lg.setColor(0.5, 0.35, 0.2, 1)
    lg.setLineWidth(6)
    lg.line(POT[1] + cos(a) * 60, POT[2] - 4 + sin(a) * 10, POT[1] + 80 + cos(a) * 40, POT[2] - 140)
    lg.setLineWidth(1)
  end
  -- the ingredients: each brought by a ghost and dropped in (distinct frog, eyeball, 8-legged spider, glowing pellet)
  for i, ing in ipairs(INGREDIENTS) do
    local t0 = ing_t(i)
    if lt > t0 - 3 and lt < t0 + 2 then
      local who = i
      local f = prog(lt, t0 - 3, t0 - 1)
      local gx = lerp(i % 2 == 0 and W + 60 or -60, POT[1] + (i % 2 == 0 and 90 or -90), f)
      if lt > t0 then gx = lerp(POT[1] + (i % 2 == 0 and 90 or -90), i % 2 == 0 and W + 60 or -60, prog(lt, t0, t0 + 2)) end
      L.ghost(gx, 640, 30, GHOSTS[who], S.t, i % 2 == 0 and -1 or 1, 0.5, nil)
      if lt < t0 + 0.6 then
        local ix = lt < t0 - 0.4 and gx + (i % 2 == 0 and -30 or 30) or POT[1]
        local iy = lt < t0 - 0.4 and 660 or lerp(660, POT[2], (lt - (t0 - 0.4)) / 1)
        if i == 1 then
          lg.setColor(0.25, 0.78, 0.28, 1)
          lg.ellipse("fill", ix, iy + 2, 13, 9, 12)
          lg.ellipse("fill", ix - 9, iy + 8, 6, 4, 8)
          lg.ellipse("fill", ix + 9, iy + 8, 6, 4, 8)
          lg.circle("fill", ix - 5, iy - 7, 4.5, 8)
          lg.circle("fill", ix + 5, iy - 7, 4.5, 8)
          lg.setColor(0.08, 0.08, 0.08, 1)
          lg.circle("fill", ix - 5, iy - 7, 2, 6)
          lg.circle("fill", ix + 5, iy - 7, 2, 6)
        elseif i == 2 then
          rgba(ing[2])
          lg.circle("fill", ix, iy, 12, 12)
          lg.setColor(0.2, 0.4, 0.9, 1)
          lg.circle("fill", ix + 4, iy, 5, 8)
          lg.setColor(0.05, 0.05, 0.1, 1)
          lg.circle("fill", ix + 5, iy, 2.5, 6)
        elseif i == 3 then
          lg.setColor(0.12, 0.08, 0.14, 1)
          lg.setLineWidth(2)
          for leg = -1, 1, 2 do
            for k = -1.5, 1.5, 1 do
              lg.line(ix + leg * 6, iy + k * 3, ix + leg * 16, iy + k * 6 - 3, ix + leg * 20, iy + k * 8 + 4)
            end
          end
          lg.setLineWidth(1)
          lg.ellipse("fill", ix, iy, 9, 11, 12)
          lg.setColor(1, 0.2, 0.2, 1)
          lg.circle("fill", ix - 3, iy - 5, 2, 6)
          lg.circle("fill", ix + 3, iy - 5, 2, 6)
        else
          C.fx.glow(ix, iy, 32, 32, 1, 0.9, 0.55, 0.7)
          rgba(ing[2])
          lg.circle("fill", ix, iy, 12, 14)
        end
      end
    end
  end
  -- BANG: the potion goes off; whoever's closest (Pac-Man, peeking in) jumps and comes out... green
  local px = L.path(lt, {{0, -80, 0}, {40, -80, 0}, {44, POT[1] - 100, 0}, {BANG, POT[1] - 100, 0}, {BANG + 1, POT[1] - 160, 0},
                         {LANDED[2] - 1, POT[1] - 160, 0}, {LANDED[2], 560, 0}})
  if lt > 40 and lt < LANDED[2] then
    local green = lt > BANG and lt < 54
    local jump = (lt > BANG - 0.1 and lt < BANG + 1) and L.hop(lt - BANG + 0.1, 1.1, 60) or 0
    local fhop = (green and lt > BANG + 1) and L.hop(lt - BANG - 1, 0.7, 26) or 0
    local py = 790 - jump - fhop
    if green then
      lg.setColor(0.4, 0.95, 0.35, 1)
      lg.arc("fill", "pie", px, py, 34, 0.4, 2 * pi - 0.4, 24)
      lg.setColor(0.1, 0.05, 0.1, 1)
      lg.circle("fill", px + 4, py - 17, 4, 8)
    else
      guest(0, px, py, 34, 1, 0, nil, lt > 54 and 0.9 or nil)
    end
  end
  if lt > BANG and lt < BANG + 0.5 then
    lg.setColor(0.6, 1, 0.5, 0.6 * (1 - (lt - BANG) / 0.5))
    lg.rectangle("fill", 0, 0, W, H)
  end
  for i, ing in ipairs(INGREDIENTS) do
    local t0 = ing_t(i)
    if lt > t0 + 0.6 and lt < t0 + 3 then G:say(ing[1] .. "!", POT[1], POT[2] - 140, 24, 1) end
  end
  if lt > 41 and lt < 44 then G:say("WHAT'S IN THERE?", px, 720, 22, 1) end
  if lt > BANG + 1 and lt < BANG + 4 then G:say("...RIBBIT?", px, 720, 24, 1) end
  if lt > 54 and lt < 57 then G:say("PHEW!", px, 720, 24, 1) end
  if lt > 60 and lt < 64 then G:say("WHEEE!", wx, wy - 80, 24, 1) end
end
CAM.witch = function(lt)
  local wx, wy = witch_pos(lt)
  if lt < LANDED[1] then return L.shot(lt, {{0, 384, 512, 1}, {6, 384, 512, 1}, {LANDED[1], 520, 720, 1.4}}, W, H) end
  local keys = {{LANDED[1], 520, 720, 1.4}}
  for i = 1, #INGREDIENTS do
    local t0 = ing_t(i)
    keys[#keys + 1] = {t0 - 1.5, POT[1], 720, 1.5}
    keys[#keys + 1] = {t0 + 1, POT[1], 770, 1.8}
    keys[#keys + 1] = {t0 + 2.5, POT[1], 720, 1.45}
  end
  for _, k in ipairs({{41, 300, 760, 1.6}, {BANG, 320, 760, 1.6}, {BANG + 0.5, 384, 640, 1.1}, {BANG + 2, 280, 760, 1.8}, {56, 280, 760, 1.8},
                      {LANDED[2], 500, 700, 1.3}, {64, 600, 400, 1.1}, {70, 384, 512, 1}}) do keys[#keys + 1] = k end
  local x, y, z = L.shot(lt, keys, W, H)
  return x, y, z, (lt > BANG and lt < BANG + 0.6) and 9 or 0
end
CUES.witch = {{1, "whoosh"}, {BANG, "boom"}, {BANG + 1.2, "boing"}, {54, "chime"}, {LANDED[2], "whoosh"}}
for i = 1, #INGREDIENTS do
  CUES.witch[#CUES.witch + 1] = {ing_t(i) + 0.6, "splash", 0.5}
  CUES.witch[#CUES.witch + 1] = {ing_t(i) + 0.7, function()
    local c = POTIONS[i + 1]
    for k = 1, 12 do G:puff(POT[1] + (G.R:random() - 0.5) * 160, POT[2] - 10, c, 60, (G.R:random() - 0.5) * 40, 2.2, 14, 0.4) end
  end}
end
CUES.witch[#CUES.witch + 1] = {BANG, function()
  for k = 1, 30 do G:puff(POT[1] + (G.R:random() - 0.5) * 300, POT[2] - 40 - G.R:random() * 200, {0.5, 1, 0.4}, 40, (G.R:random() - 0.5) * 200, 2.2, 22, 0.5) end
end}

local DARK_GPOS = {{140, 420}, {305, 640}, {470, 420}, {635, 640}}
function D.dark(lt, len)
  lg.setColor(0, 0, 0, 1)
  lg.rectangle("fill", 0, 0, W, H)
  local beam = lt > 14 and lt < 52
  local bx = beam and (384 + sin((lt - 14) * 0.6) * 300) or -999
  local by = beam and (520 + cos((lt - 14) * 0.45) * 220) or -999
  -- eyes in the dark: 4 pairs tied to the 4 ghosts' real positions, plus ambient pairs
  if lt < 60 then
    for i, gp in ipairs(DARK_GPOS) do
      local d = math.sqrt((gp[1] - bx) ^ 2 + (gp[2] - by) ^ 2)
      if not beam or d >= 115 then
        local blink = (floor(S.t * 0.7 + i * 1.3) % 5 == 0) and 0.2 or 1
        local ey = gp[2] - 5
        lg.setColor(1, 1, 1, blink)
        lg.ellipse("fill", gp[1] - 12, ey, 7, 9 * blink + 1, 10)
        lg.ellipse("fill", gp[1] + 12, ey, 7, 9 * blink + 1, 10)
        lg.setColor(0.15, 0.25, 0.9, blink)
        lg.circle("fill", gp[1] - 12 + sin(S.t + i) * 2.5, ey + 1, 3.5, 8)
        lg.circle("fill", gp[1] + 12 + sin(S.t + i) * 2.5, ey + 1, 3.5, 8)
      end
    end
    for i = 1, 6 do
      local e = S.eyes[i]
      if e then
        local blink = (floor(S.t * 0.6 + i * 1.7) % 6 == 0) and 0.2 or 1
        lg.setColor(1, 1, 1, blink * 0.75)
        lg.ellipse("fill", e[1] - 8, e[2], 5, 7 * blink + 1, 10)
        lg.ellipse("fill", e[1] + 8, e[2], 5, 7 * blink + 1, 10)
        lg.setColor(0.15, 0.25, 0.9, blink * 0.75)
        lg.circle("fill", e[1] - 8 + sin(S.t + i) * 2, e[2] + 1, 2.5, 8)
        lg.circle("fill", e[1] + 8 + sin(S.t + i) * 2, e[2] + 1, 2.5, 8)
      end
    end
  end
  -- the flashlight's beam, sweeping; ghosts freeze wide-eyed, plus black cat & jack-o'-lantern
  if beam then
    lg.setBlendMode("add")
    lg.setColor(1, 0.95, 0.75, 0.22)
    lg.polygon("fill", 384, 1024, bx - 110, by, bx + 110, by)
    lg.circle("fill", bx, by, 110, 32)
    lg.setBlendMode("alpha")
    for i, c in ipairs(GHOSTS) do
      local gx, gy = DARK_GPOS[i][1], DARK_GPOS[i][2]
      local d = math.sqrt((gx - bx) ^ 2 + (gy - by) ^ 2)
      if d < 125 then
        local a = clamp(1 - d / 125, 0, 1)
        L.ghost(gx, gy, 34, c, S.t + i, (bx - gx) / 125, (by - gy) / 125, "wide", a)
      end
    end
    -- catch the black cat & jack-o'-lantern in the beam
    local dc = math.sqrt((220 - bx) ^ 2 + (740 - by) ^ 2)
    if dc < 125 then
      local a = clamp(1 - dc / 125, 0, 1)
      lg.setColor(0.12, 0.1, 0.16, a)
      lg.ellipse("fill", 220, 748, 22, 14, 12)
      lg.circle("fill", 238, 732, 12, 12)
      lg.polygon("fill", 230, 724, 232, 712, 238, 722)
      lg.polygon("fill", 240, 722, 245, 712, 248, 724)
      lg.setColor(1, 0.92, 0.2, a)
      lg.circle("fill", 234, 731, 3, 6)
      lg.circle("fill", 242, 731, 3, 6)
    end
    local dp = math.sqrt((560 - bx) ^ 2 + (720 - by) ^ 2)
    if dp < 125 then
      pumpkin(560, 720, 42, {"tri", 1}, true, S.t)
    end
  end
  -- BOO!
  if lt >= 54 and lt < 60 then
    local k = clamp((lt - 54) / 0.25, 0, 1)
    C.fx.ghost(384, 520, 60 + k * 200, GHOSTS[1], 1, S.t, false, false, 1)
    G:caption("BOO!", 820, 120, 0xffffff, 1, 0.6 + 0.4 * k)
  end
  -- brief room-lights-on laugh reveal after GOTCHA
  if lt >= 60 then
    local la = L.window(lt, 61, 69, 0.6)
    if la > 0 then
      lg.setColor(0.14, 0.10, 0.22, 0.85 * la)
      lg.rectangle("fill", 0, 0, W, H)
      for i, who in ipairs({1, 2, 0, 3, 4}) do
        local gx = 134 + (i - 1) * 125
        local gy = 740 - L.hop(lt + i * 0.18, 0.45, 16)
        guest(who, gx, gy, 32, 0, -0.3, "happy", nil, la)
      end
    end
    G:plate("GOTCHA", 460, 50, 0xff8000, L.window(lt, 60, 69, 1))
  end
end

CAM.dark = function(lt)
  if lt > 14 and lt < 52 then
    local bx = 384 + sin((lt - 14) * 0.6) * 300
    local by = 520 + cos((lt - 14) * 0.45) * 220
    return L.shot(0, {{0, lerp(384, bx, 0.45), lerp(512, by, 0.45), 1.3}}, W, H)
  end
  local x, y, z = L.shot(lt, {{0, 384, 512, 1}, {52, 384, 512, 1.1}, {54, 384, 520, 1}, {70, 384, 512, 1}}, W, H)
  return x, y, z, (lt > 54 and lt < 54.6) and 10 or 0
end
CUES.dark = {{54, "boo"}, {54.1, "boom", 0.5}}
for t = 4, 52, 6 do CUES.dark[#CUES.dark + 1] = {t, t % 12 == 4 and "boo" or "whoosh", 0.25} end

-- ------------------------------------------------------------------ HAPPY HALLOWEEN
function D.finale(lt, len)
  if not art("finale") then G:gradient(0, 0, W, H, {0.08, 0.02, 0.12}, {0.25, 0.08, 0.15}) end
  lg.setColor(0.05, 0.02, 0.08, 1)
  for i = 1, 6 do bat(((S.t * 50 + i * 130) % (W + 120)) - 60, 120 + sin(S.t + i) * 40 + i * 30, 1, S.t + i) end
  G:caption("HAPPY", 300, 56, 0xffffff, L.window(lt, 0.5, len, 1))
  G:caption("HALLOWEEN", 370, 84, 0xff8000, L.window(lt, 1, len, 1))
  -- the pumpkins lit one by one; the cast popping up behind them; then a ghost parade across
  local faces = {"pac", "tri", "ghost", "tri", "pac"}
  for i = 1, 5 do
    local x = 110 + (i - 1) * 137
    local lit = lt > 3 + i * 1.2
    local who = ({1, 2, 0, 3, 4})[i]
    if lt > 12 + i * 0.8 then
      local up = prog(lt, 12 + i * 0.8, 13 + i * 0.8)
      guest(who, x, 700 - up * 40 - (lt > 20 and L.hop(lt + i * 0.2, 0.5, 14) or 0), 28, 0, -0.5, "happy", nil)
    end
    lg.setColor(1, 0.5, 0.05, 1)
    pumpkin(x, 760, 56, {faces[i], 1}, lit, S.t)
  end
  -- the witch across the moon, flipped horizontally for right-to-left flight (black cat riding behind her)
  if lt > 44 and lt < 54 then
    local f = lin(lt, 44, 54)
    local wx, wy = lerp(W + 120, -120, f), 180 + sin(f * pi) * -40
    lg.push()
    lg.translate(wx, wy)
    lg.scale(-1, 1)
    lg.setColor(0.05, 0.02, 0.08, 1)
    lg.setLineWidth(4)
    lg.line(-60, 10, 60, 0)
    lg.polygon("fill", -60, 10, -90, -2, -94, 22)
    lg.polygon("fill", -10, 4, 8, -40, 22, 0)
    lg.polygon("fill", -4, -46, 26, -48, 14, -86)
    -- black cat perched on the back of the broom (no duplicate Pac-Man!)
    lg.ellipse("fill", -36, -6, 12, 8, 10)
    lg.circle("fill", -26, -15, 7, 10)
    lg.polygon("fill", -31, -20, -30, -28, -26, -21)
    lg.polygon("fill", -24, -21, -21, -28, -20, -20)
    lg.setColor(1, 0.9, 0.2, 1)
    lg.circle("fill", -24, -16, 1.8, 6)
    lg.setLineWidth(1)
    lg.pop()
  end
  if lt > 30 then
    for i = 1, 8 do
      local gx = lerp(-80, W + 80, lin(lt, 30 + i * 0.6 + (lt > 52 and 22 or 0), 44 + i * 0.6 + (lt > 52 and 22 or 0)))
      L.ghost(gx, 560 + sin(S.t * 3 + i) * 20, 18, GHOSTS[(i - 1) % 4 + 1], S.t + i, 1, 0, "happy", 0.8)
    end
  end
  if lt > 22 and lt < 26 then G:say("TRICK OR TREAT!", 384, 610, 24, 1) end
end
CAM.finale = function(lt)
  local keys = {{0, 384, 512, 1}, {3, 160, 760, 1.6}}
  for i = 1, 5 do keys[#keys + 1] = {3 + i * 1.2, 110 + (i - 1) * 137, 760, 1.6} end
  for _, k in ipairs({{12, 384, 700, 1.15}, {28, 384, 640, 1.05}, {32, 200, 600, 1.4}, {40, 560, 600, 1.4}, {44, 600, 300, 1.3},
                      {54, 200, 300, 1.3}, {57, 384, 700, 1.3}, {65, 384, 512, 1}}) do keys[#keys + 1] = k end
  return L.shot(lt, keys, W, H)
end
CUES.finale = {{22, "cheer"}, {30, "boo", 0.4}, {44, "whoosh"}, {48, "cheer", 0.5}, {52, "boo", 0.4}}
for i = 1, 5 do CUES.finale[#CUES.finale + 1] = {3 + i * 1.2, "chime", 0.4} end

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
  for _, l in ipairs({{"PRESENTS", 26, 0x6ef0c8}, {"HALLOWEEN", 84, 0xff8000},
                      {"HAPPY", 56, 0xffffff}, {"BOO!", 120, 0xffffff}, {"GOTCHA", 50, 0xff8000},
                      {"THE CANDLES ARE LIT", 34, 0xff8000}, {"NICE COSTUMES, EVERYONE", 34, 0xff8000}}) do
    G:label(l[1], l[2], l[3])
  end
end

function M.act() return S and scene_at(S.t)[2] or "open" end
function M.music() return S and scene_at(S.t)[3] or "hw_toccata" end

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
  if sc[2] == "graveyard" and G.R:random() < dt * 6 then G:puff(G.R:random() * W, 960, {0.7, 0.75, 0.8}, 6, 20, 4, 22, 0.14) end
  if sc[2] == "witch" and G.R:random() < dt * 8 then G:puff(330 + G.R:random() * 110, 820, potion(lt), 40, 0, 2, 10, 0.2) end
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
