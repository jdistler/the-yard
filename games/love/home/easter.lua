-- Easter Egg Hunt: six minutes (Easter week in AUTO; the date from the Gregorian computus in shows.lua):
--   0:00  STARLIGHT PRESENTS ... THE EGG HUNT                                        (Egg Hunt)
--   0:08  The hunt: a bluebonnet field, eggs in the grass, Pac-Man's basket filling  (Egg Hunt)
--   1:10  Dyeing eggs: the cups of dye, eggs dipped; Inky dips himself               (Dye Job)
--   2:10  The Easter Bunny hops through; the ghosts follow in ears                   (Bunny Hop)
--   3:10  Cascarones: confetti eggs, cracked on heads, the Texas way                 (Cascarones)
--   4:30  The secret level: a glitch, a hidden room, the game's own easter egg       (Secret Level)
--   5:30  HAPPY EASTER
local lg = love.graphics
local L = require("showlib")
local M = {}
local C, G
local W, H = 768, 1024
local LEN = 360
M.LEN = LEN
local sin, cos, floor, min, max, abs, pi = math.sin, math.cos, math.floor, math.min, math.max, math.abs, math.pi
local clamp, ease, lerp, mix = L.clamp, L.ease, L.lerp, L.mix
local function prog(lt, a, b) return ease((lt - a) / (b - a)) end
local function lin(lt, a, b) return clamp((lt - a) / (b - a), 0, 1) end

local SCENES = {
  {0, "open", "eg_hunt"},
  {8, "hunt", "eg_hunt", "THE EGG HUNT", "BLUEBONNETS  ·  TWELVE EGGS  ·  ONE BASKET"},
  {70, "dye", "eg_dye", "DYEING EGGS", "SIX CUPS  ·  ONE VOLUNTEER"},
  {130, "bunny", "eg_hop", "THE EASTER BUNNY", "FOLLOW THE LEADER"},
  {190, "cascarones", "eg_cascarones", "CASCARONES", "CONFETTI EGGS  ·  CRACKED ON HEADS  ·  THE TEXAS WAY"},
  {270, "secret", "eg_secret", "THE SECRET LEVEL", "EVERY GOOD GAME HAS ONE"},
  {330, "finale", "eg_hunt"},
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
local PASTEL = {{1, 0.7, 0.8}, {0.7, 0.85, 1}, {1, 0.95, 0.6}, {0.75, 1, 0.75}, {0.85, 0.75, 1}, {1, 0.8, 0.6}}

-- An egg: r tall; two bands of the second colour, as wide as the egg at their height.
local function egg(x, y, r, c1, c2, a)
  a = a or 1
  rgba(c1, a)
  lg.ellipse("fill", x, y, r * 0.76, r, 20)
  if c2 then
    rgba(c2, a)
    for _, dy in ipairs({-0.3, 0.22}) do
      local yy = dy * r
      local w = r * 0.76 * math.sqrt(max(0, 1 - (yy / r) ^ 2))
      lg.rectangle("fill", x - w, y + yy - r * 0.08, w * 2, r * 0.16)
    end
  end
  lg.setColor(1, 1, 1, 0.35 * a)
  lg.ellipse("fill", x - r * 0.3, y - r * 0.4, r * 0.14, r * 0.24, 10)
end

local function bunny(x, y, s, hop, a)
  a = a or 1
  local yy = y - abs(sin(hop)) * 60 * s
  -- woven backpack basket with peeking pastel eggs
  lg.setColor(0.72, 0.52, 0.26, a)
  lg.rectangle("fill", x - 34 * s, yy - 46 * s, 30 * s, 26 * s, 5 * s, 5 * s, 4)
  lg.setColor(0.54, 0.36, 0.16, a)
  lg.setLineWidth(max(1, 2 * s))
  lg.line(x - 34 * s, yy - 33 * s, x - 4 * s, yy - 33 * s)
  lg.line(x - 19 * s, yy - 46 * s, x - 19 * s, yy - 20 * s)
  lg.setLineWidth(1)
  for k = 0, 2 do
    rgba(PASTEL[k + 1], a)
    lg.ellipse("fill", x - 27 * s + k * 8 * s, yy - 48 * s, 5 * s, 7 * s, 10)
  end
  lg.setColor(0.97, 0.97, 0.97, a)
  lg.ellipse("fill", x, yy, 46 * s, 38 * s, 20)
  lg.circle("fill", x + 40 * s, yy - 36 * s, 26 * s, 18)
  lg.ellipse("fill", x + 30 * s, yy - 86 * s, 9 * s, 32 * s, 12)
  lg.ellipse("fill", x + 50 * s, yy - 84 * s, 9 * s, 30 * s, 12)
  lg.circle("fill", x - 46 * s, yy - 6 * s, 12 * s, 10)
  lg.setColor(1, 0.7, 0.8, a)
  lg.ellipse("fill", x + 30 * s, yy - 84 * s, 4 * s, 22 * s, 10)
  lg.ellipse("fill", x + 50 * s, yy - 82 * s, 4 * s, 20 * s, 10)
  lg.circle("fill", x + 64 * s, yy - 34 * s, 4 * s, 8)
  lg.setColor(0.1, 0.1, 0.15, a)
  lg.circle("fill", x + 48 * s, yy - 42 * s, 4 * s, 8)
end

local CAM
local CUES = {}
local function ears(x, y, r, a)
  lg.setColor(0.97, 0.97, 0.97, a or 1)
  lg.ellipse("fill", x - r * 0.35, y - r * 1.4, r * 0.18, r * 0.55, 10)
  lg.ellipse("fill", x + r * 0.35, y - r * 1.4, r * 0.18, r * 0.55, 10)
  lg.setColor(1, 0.7, 0.8, a or 1)
  lg.ellipse("fill", x - r * 0.35, y - r * 1.38, r * 0.08, r * 0.4, 8)
  lg.ellipse("fill", x + r * 0.35, y - r * 1.38, r * 0.08, r * 0.4, 8)
end

local function meadow(with_oak)
  local img = with_oak and S.art.meadow_oak or S.art.meadow
  if img then
    lg.setColor(1, 1, 1, 1)
    lg.draw(img, 0, 0)
    return true
  end
  G:gradient(0, 0, W, 560, {0.4, 0.65, 1}, {0.85, 0.93, 1})
  lg.setColor(1, 1, 1, 0.9)
  for i = 0, 2 do
    local x = ((i * 300 + S.t * 10) % (W + 300)) - 150
    lg.ellipse("fill", x, 140 + i * 50, 80, 26, 20)
    lg.ellipse("fill", x + 50, 128 + i * 50, 50, 24, 20)
  end
  lg.setColor(0.45, 0.6, 0.35, 1)
  lg.ellipse("fill", 200, 560, 340, 80, 32)
  lg.ellipse("fill", 620, 560, 300, 70, 32)
  G:gradient(0, 540, W, H, {0.4, 0.62, 0.3}, {0.3, 0.5, 0.22})
  for i, f in ipairs(S.flowers) do
    if f[3] == 1 then lg.setColor(0.3, 0.4, 0.9, 1) elseif f[3] == 2 then lg.setColor(0.95, 0.35, 0.2, 1)
    else lg.setColor(1, 1, 1, 1) end
    lg.rectangle("fill", f[1], f[2], 5, 10)
  end
end

local D = {}

function D.open(lt, len)
  meadow()
  for i = 1, 5 do egg(160 + (i - 1) * 112, 760 + sin(S.t * 2 + i) * 6, 46, PASTEL[i], PASTEL[i % 6 + 1]) end
  local a = L.window(lt, 0.4, 4, 0.7)
  G:brand(340, a)
  G:caption("PRESENTS", 412, 26, 0x6ef0c8, a)
  G:caption("THE EGG HUNT", 360, 76, 0xffb6d9, L.window(lt, 4.2, 8, 0.7))
end

function D.hunt(lt, len)
  if not meadow(true) or not S.art.meadow_oak then L.live_oak(110, 600, 1.6, S.t) end
  -- the eggs, hidden; Pac-Man goes from one to the next and takes it
  local per = (len - 6) / #S.eggs
  local k = clamp((lt - 2) / per, 0, #S.eggs)
  local found = floor(k)
  for i, e in ipairs(S.eggs) do
    if i > found then
      if i == 5 then
        lg.setColor(0.6, 0.58, 0.55, 1)
        lg.ellipse("fill", e[1], e[2], 20, 16, 14)
      elseif i == #S.eggs then
        C.fx.glow(e[1], e[2], 40, 40, 1, 0.85, 0.3, 0.5 + 0.3 * sin(S.t * 5))
        egg(e[1], e[2], 26, {1, 0.82, 0.25}, {1, 1, 0.8})
      else egg(e[1], e[2], 26, e[3], e[4]) end
    end
  end
  local i = min(found + 1, #S.eggs)
  local prev = S.eggs[max(found, 1)]
  local cur = S.eggs[i]
  local f = ease((k - found) * 1.4)
  local px = found == 0 and lerp(-40, cur[1], f) or lerp(prev[1], cur[1], f)
  local py = found == 0 and lerp(900, cur[2], f) or lerp(prev[2], cur[2], f)
  local dir = (cur[1] >= (found == 0 and -40 or prev[1])) and 1 or -1
  S.hunt_px, S.hunt_py = px, py
  C.fx.chomper(px, py - 30, 36, dir, S.t, 1)
  local per2 = (len - 6) / #S.eggs
  if found >= 5 and lt < 2 + 5 * per2 + 2.5 then G:say("...A ROCK.", px, py - 80, 22, 1) end
  if found >= #S.eggs and lt > 2 + #S.eggs * per2 then G:say("THE GOLDEN EGG!", px, py - 80, 24, 1) end
  -- the HUD basket in the corner drawn in screen space via after_cam so camera tracking never clips it
  G:after_cam(function()
    lg.setColor(0.7, 0.5, 0.25, 1)
    lg.rectangle("fill", 560, 850, 160, 80, 10, 10, 6)
    lg.setLineWidth(6)
    lg.arc("line", "open", 640, 850, 70, pi, 2 * pi, 20)
    lg.setLineWidth(1)
    for j = 1, min(found, 12) do
      local e = S.eggs[j]
      local bx = 578 + ((j - 1) % 6) * 25
      local by = 846 - floor((j - 1) / 6) * 16
      if j == 5 then
        lg.setColor(0.6, 0.58, 0.55, 1)
        lg.ellipse("fill", bx, by, 12, 9, 12)
      elseif j == 12 then
        C.fx.glow(bx, by, 26, 26, 1, 0.85, 0.3, 0.55 + 0.25 * sin(S.t * 5))
        egg(bx, by, 14, {1, 0.82, 0.25}, {1, 1, 0.8})
      else
        egg(bx, by, 14, e[3], e[4])
      end
    end
    G:text(found .. " / " .. #S.eggs, 560, 936, 24, {1, 1, 1}, 1, "center", 160)
  end)
  -- Clyde sneaking across with a visible decoy egg to hide
  local g = lt % 15
  if g < 4 then
    local gx = 680 - g * 20
    C.fx.ghost(gx, 640, 24, GHOSTS[4], -1, S.t, false, false, 0.85)
    egg(gx - 22, 646, 12, PASTEL[3], PASTEL[1], 0.9)
  end
end

CAM = {}
CAM.hunt = function(lt)
  if lt < 3 or not S.hunt_px then return L.shot(lt, {{0, 384, 512, 1}, {3, 384, 760, 1.2}}, W, H) end
  local z = (lt > 56) and lerp(1.5, 1.05, clamp((lt - 56) / 3, 0, 1)) or 1.5
  return L.shot(0, {{0, lerp(S.hunt_px, 560, clamp((lt - 56) / 3, 0, 1)), lerp(S.hunt_py - 60, 760, clamp((lt - 56) / 3, 0, 1)), z}}, W, H)
end
function D.dye(lt, len)
  local painted = S.art.kitchen
  if painted then
    lg.setColor(1, 1, 1, 1)
    lg.draw(S.art.kitchen, 0, 0)
  else
    G:gradient(0, 0, W, H, {1, 0.96, 0.88}, {0.95, 0.85, 0.75})
    -- the table, six cups
    lg.setColor(0.85, 0.65, 0.45, 1)
    lg.rectangle("fill", 0, 640, W, 384)
  end
  local cols = {{1, 0.3, 0.45}, {0.3, 0.6, 1}, {1, 0.85, 0.2}, {0.3, 0.85, 0.4}, {0.65, 0.4, 0.95}, {1, 0.55, 0.2}}
  for i, c in ipairs(painted and {} or cols) do
    local x = 84 + (i - 1) * 120
    lg.setColor(0.95, 0.95, 1, 0.7)
    lg.rectangle("fill", x - 44, 560, 88, 110, 6, 6, 4)
    rgba(c, 0.9)
    lg.rectangle("fill", x - 40, 590, 80, 76, 4, 4, 4)
  end
  -- an egg dipped in each in turn, on a wire spoon, coming out that colour
  local per = 7
  local i = floor(lt / per) % 6 + 1
  local k = (lt % per) / per
  local x = 84 + (i - 1) * 120
  local dip = k < 0.3 and ease(k / 0.3) or k < 0.7 and 1 or ease(1 - (k - 0.7) / 0.3)
  local y = lerp(400, 610, dip)
  local c = k > 0.5 and cols[i] or {0.98, 0.97, 0.92}
  lg.setColor(0.6, 0.6, 0.65, 1)
  lg.setLineWidth(3)
  lg.line(x, y - 120, x, y + 20)
  lg.setLineWidth(1)
  egg(x, y, 40, c, k > 0.5 and {1, 1, 1} or nil)
  -- translucent cup front layer so the dipped egg visibly submerges inside the dye
  rgba(cols[i], 0.36)
  lg.rectangle("fill", x - 40, 590, 80, 76, 4, 4, 4)
  lg.setColor(1, 1, 1, 0.28)
  lg.rectangle("fill", x - 34, 570, 10, 86, 4, 4, 4)
  -- dripping dye droplets as the egg lifts out
  if k > 0.72 then
    rgba(cols[i], 0.9)
    for d = 0, 2 do
      local df = ((k - 0.72) * 5 + d * 0.33) % 1
      lg.circle("fill", x - 10 + d * 10, y + 36 + df * max(10, 600 - (y + 36)), 3.5, 6)
    end
  end
  -- Pinky beside the cup (flips to x - 90 on Cup 5/6 so she isn't clipped off right edge)
  local cheer = k > 0.5 and k < 0.75
  local pside = i >= 5 and -1 or 1
  local px = x + pside * 90
  C.fx.ghost(px, 520 - (cheer and abs(sin(S.t * 12)) * 20 or 0), 30, GHOSTS[2], -pside, S.t, false, false, 1)
  if cheer then G:say(({"PINK!", "BLUE!", "YELLOW!", "GREEN!", "PURPLE!", "ORANGE!"})[i], px, 470, 22, 1) end
  -- the done ones, drying
  for j = 1, min(floor(lt / per), 12) do
    local cc = cols[(j - 1) % 6 + 1]
    egg(80 + (j - 1) * 56, 860 + (j % 2) * 30, 26, cc, PASTEL[j % 6 + 1])
  end
  -- Pinky's purple slip (30.5-36s, during Cup #5 Purple!): a spatter up the wall
  if lt > 30.5 and lt < 36 then
    local f = clamp((lt - 30.5) / 0.6, 0, 1)
    rgba({0.65, 0.4, 0.95}, 0.85 * (1 - lin(lt, 35, 36)))
    for j = 1, 14 do
      local a = -pi / 2 + (j - 7) * 0.18
      lg.circle("fill", 564 + cos(a) * 160 * f, 600 + sin(a) * 220 * f, 8 + (j % 3) * 4, 10)
    end
    if lt < 33.5 then G:say("OOPS!", 474, 470, 26, 1) end
  end
  -- Inky, every half minute, dips himself into Cup #6 Orange (x = 684) and turns orange!
  local g = lt % 30
  if g > 18 and g < 28 then
    local gk = (g - 18) / 10
    local gy = gk < 0.3 and lerp(300, 600, ease(gk / 0.3)) or gk < 0.5 and 600 or lerp(600, 380, ease((gk - 0.5) / 0.5))
    local gc = gk < 0.4 and GHOSTS[3] or cols[6]
    C.fx.ghost(684, gy, 34, gc, -1, S.t, false, false, 1)
    rgba(cols[6], 0.36)
    lg.rectangle("fill", 684 - 40, 590, 80, 76, 4, 4, 4)
    if gk > 0.6 then G:text("...CLYDE?!", 470, gy - 90, 26, {0.95, 0.48, 0.12}, 1, "center", 300) end
  end
end

CAM.dye = function(lt)
  local g = lt % 30
  if g > 18 and g < 28 then return L.shot(0, {{0, 600, 520, 1.5}}, W, H) end
  local i = floor(lt / 7) % 6 + 1
  local k = (lt % 7) / 7
  local x = 84 + (i - 1) * 120
  if k < 0.8 then return L.shot(0, {{0, x + lerp(-40, 40, k / 0.8), lerp(600, 520, k / 0.8), lerp(1.45, 1.95, k / 0.8)}}, W, H) end
  return L.shot(0, {{0, lerp(x, 384, (k - 0.8) / 0.2), lerp(560, 760, (k - 0.8) / 0.2), lerp(1.7, 1.2, (k - 0.8) / 0.2)}}, W, H)
end
function D.bunny(lt, len)
  meadow()
  -- the bunny hops across, the ghosts in ears behind it, copying every hop; a 30 s loop
  local c = lt % 30
  local x0 = lerp(-120, W + 600, c / 30)
  local hop = c * pi * 1.6
  local stop = c > 12 and c < 17
  if stop then x0 = lerp(-120, W + 600, 12 / 30) hop = 0 end
  if c >= 17 then x0 = lerp(-120, W + 600, (c - 5) / 30) end
  S.bun_x = x0
  -- trail eggs on the grass BEHIND the hopping cast
  for i, e in ipairs(S.trail) do
    if e[1] < x0 - 60 then egg(e[1], e[2], 18, e[3], e[4]) end
  end
  bunny(x0, 820, 1.2, hop)
  local unbunch = (c >= 17 and c < 18.5) and (1 - prog(c, 17, 18.5)) or 0
  for i, col in ipairs(GHOSTS) do
    local gx = x0 - 150 - (i - 1) * 110
    local gy = 820 - abs(sin(hop - i * 0.6)) * 60
    if stop or unbunch > 0 then
      local f = stop and clamp((c - 12 - i * 0.25) / 0.4, 0, 1) or unbunch
      gx = lerp(gx, x0 - 90 - (i - 1) * 50, f)
      if stop then gy = 820 - (c < 15 and f * 30 * (i % 2) or 0) end
    end
    C.fx.ghost(gx, gy, 30, col, 1, S.t, false, false, 1)
    ears(gx, gy, 30, 1)
  end
  local px = x0 - 150 - 4 * 110
  if stop or unbunch > 0 then
    local pf = stop and clamp((c - 13.2) / 0.4, 0, 1) or unbunch
    px = lerp(px, x0 - 300, pf)
  end
  local py = 830 - abs(sin(hop - 3)) * 60
  C.fx.chomper(px, py, 30, 1, S.t, 1)
  ears(px, py, 30, 1)
  if stop and c > 13.5 and c < 16 then G:say("BONK! BONK! BONK!", x0 - 200, 700, 22, 1) end
end

CAM.bunny = function(lt)
  local x0 = S.bun_x or 384
  return L.shot(0, {{0, x0 - 220, 760, 1.4}}, W, H)
end
-- Cascarones, a story: Pac-Man buys a carton (50 cents), sneaks up and cracks one on each ghost in turn (each
-- jumps: HEY!), the ghosts arm themselves and chase him round the yard cracking theirs on him, the confetti
-- piles up on him until he's buried, he pops out, and all five throw the last of them up together.
local CA_SPOTS = {{300, 760}, {470, 740}, {640, 760}, {384, 900}}      -- the ghosts, standing about
local SNEAK = {11, 18, 25, 32}                                         -- Pac-Man's cracks on ghost k
local CHASE0, CHASE1 = 40, 58                                          -- the ghosts' revenge, round the yard
local CA_COLS = {{1, 0.3, 0.5}, {0.3, 0.7, 1}, {1, 0.85, 0.2}, {0.4, 0.85, 0.4}, {0.75, 0.45, 1}, {1, 0.55, 0.2}}
local function chase_pos(lt, k)
  -- round an oval, Pac-Man in front, the ghosts behind in a line
  local a = (lt - CHASE0) * 1.1 - k * 0.55
  return 384 + cos(a) * 250, 820 + sin(a) * 110
end
local function pac_pos(lt)
  if lt < 8 then return L.path(lt, {{0, -80, 900}, {3, 384, 640}, {6, 384, 640}, {8, 150, 760}}) end
  for k, t0 in ipairs(SNEAK) do
    if lt < t0 + 4.5 then
      local sx, sy = CA_SPOTS[k][1] - 80, CA_SPOTS[k][2]
      local from = k == 1 and {150, 760} or {CA_SPOTS[k - 1][1] - 80, CA_SPOTS[k - 1][2]}
      return L.path(lt, {{t0 - 3, from[1], from[2]}, {t0 - 0.6, sx, sy}, {t0 + 1.4, sx, sy}, {t0 + 2.6, sx - 40, sy + 20}})
    end
  end
  if lt < CHASE0 then return L.path(lt, {{SNEAK[4] + 4.5, CA_SPOTS[4][1] - 80, CA_SPOTS[4][2]}, {CHASE0, 384 + 250, 820}}) end
  if lt < CHASE1 then return chase_pos(lt, 0) end
  local cx, cy = chase_pos(CHASE1, 0)
  local f = prog(lt, CHASE1, CHASE1 + 1.0)
  return lerp(cx, 384, f), lerp(cy, 860, f)
end
-- every crack: {time, target (0 Pac-Man, 1-4 a ghost), colour}
local function ca_cracks()
  local list = {}
  for k, t0 in ipairs(SNEAK) do list[#list + 1] = {t0, k, CA_COLS[k]} end
  for n = 0, 5 do list[#list + 1] = {CHASE0 + 2 + n * 2.6, 0, CA_COLS[n % 6 + 1]} end
  for k = 0, 4 do list[#list + 1] = {70 + k * 0.4, k, CA_COLS[k + 1]} end
  return list
end
local CA_CRACKS = ca_cracks()
local function target_pos(lt, who)
  if who == 0 then return pac_pos(lt) end
  if lt > CHASE0 and lt < CHASE1 then
    local cx, cy = chase_pos(lt, who)
    local fin = prog(lt, CHASE0, CHASE0 + 1.2)
    return lerp(CA_SPOTS[who][1], cx, fin), lerp(CA_SPOTS[who][2], cy, fin)
  end
  if lt >= CHASE1 then
    local cx, cy = chase_pos(CHASE1, who)
    local fout = prog(lt, CHASE1, CHASE1 + 1.4)
    return lerp(cx, 384 + (who - 2.5) * 150, fout), lerp(cy, 880, fout)
  end
  return CA_SPOTS[who][1], CA_SPOTS[who][2]
end
function D.cascarones(lt, len)
  local painted = S.art.fiesta
  if painted then
    lg.setColor(1, 1, 1, 1)
    lg.draw(S.art.fiesta, 0, 0)
  else
    G:gradient(0, 0, W, H, {0.55, 0.8, 1}, {1, 0.9, 0.7})
    G:gradient(0, 720, W, H, {0.5, 0.7, 0.35}, {0.38, 0.58, 0.28})
    lg.setColor(0.55, 0.35, 0.2, 1)
    lg.rectangle("fill", 200, 560, 368, 22, 4, 4, 4)
    G:text("CASCARONES  50¢", 200, 470, 30, {0.85, 0.2, 0.45}, 1, "center", 368)
  end
  -- the carton on the table until it's bought (5), the coin
  if lt < 5.5 then
    lg.setColor(0.8, 0.75, 0.65, 1)
    lg.rectangle("fill", 306, 520, 156, 44, 6, 6, 4)
    for j = 0, 5 do egg(324 + j * 24, 522, 15, CA_COLS[j + 1], {1, 1, 1}) end
  end
  if lt > 4 and lt < 5.2 then
    lg.setColor(1, 0.85, 0.2, 1)
    lg.circle("fill", 384, 560 - (lt - 4) * 60, 10, 12)
  end
  -- the confetti on the grass, more with every crack
  local n = 0
  for _, c in ipairs(CA_CRACKS) do if lt > c[1] then n = n + 1 end end
  for j = 1, n * 24 do
    local x = (j * 97.3) % W
    local y = 740 + (j * 53.7) % 270
    rgba(CA_COLS[j % 6 + 1], 0.9)
    lg.rectangle("fill", x, y, 7, 7)
  end
  -- the ghosts
  for k = 1, 4 do
    local x, y = target_pos(lt, k)
    local t0 = SNEAK[k]
    local jump = (lt > t0 and lt < t0 + 1) and L.hop(lt - t0, 1, 70) or 0
    local turned = lt > t0 + 0.4
    local happy = lt > CHASE1
    local chasing = lt > CHASE0 and lt < CHASE1
    local hop = (chasing or happy) and L.hop(S.t + k * 0.3, 0.4, 14) or 0
    local ga = (lt - CHASE0) * 1.1 - k * 0.55
    local gdir = chasing and (sin(ga) > 0 and -1 or 1) or (turned and -1 or 1)
    C.fx.ghost(x, y - 50 - jump - hop, 54, GHOSTS[k], gdir, S.t + k, false, false, 1)
    -- armed: an egg held up
    if chasing then egg(x + gdir * 30, y - 120 - hop, 18, CA_COLS[k], {1, 1, 1}) end
  end
  -- Pac-Man: the carton under his arm, sneaking (slow), the egg up; or buried in confetti, then out
  local px, py = pac_pos(lt)
  local buried = lt > CHASE1 + 0.2 and lt < 64
  if buried then
    local mound = clamp((lt - (CHASE1 + 0.2)) / 1.5, 0, 1)
    for j = 1, 90 do
      local a = j * 2.4
      local r = (j % 30) * 2.4 * mound
      rgba(CA_COLS[j % 6 + 1], 1)
      lg.rectangle("fill", px + cos(a) * r * 1.6, py - 20 - abs(sin(a)) * r * 1.2, 9, 9)
    end
    lg.setColor(1, 1, 1, 1)
    lg.circle("fill", px - 12, py - 40, 6, 8)
    lg.circle("fill", px + 12, py - 40, 6, 8)
  else
    local pop = (lt > 64 and lt < 65) and L.hop(lt - 64, 1, 120) or 0
    C.fx.chomper(px, py - 50 - pop, 56, (lt > CHASE0 and lt < CHASE1) and (sin((lt - CHASE0) * 1.1) > 0 and -1 or 1) or 1, S.t, 1)
    if lt > 5 and lt < CHASE0 then
      lg.setColor(0.8, 0.75, 0.65, 1)
      lg.rectangle("fill", px - 80, py - 40, 60, 24, 4, 4, 4)
    end
    for k, t0 in ipairs(SNEAK) do
      if lt > t0 - 1 and lt < t0 then egg(px + 40, py - 140, 22, CA_COLS[k], {1, 1, 1}) end
    end
  end
  -- the cracks: normal eggs drop onto heads; finale eggs (70..72) arc UP into an overhead rainbow confetti shower!
  for _, c in ipairs(CA_CRACKS) do
    local k = lt - c[1]
    local is_finale = c[1] >= 70
    if k > -0.5 and k < 2 then
      local x, y = target_pos(c[1], c[2])
      if is_finale then
        local peak_y = y - 360
        if k < 0 then
          local f = (k + 0.5) / 0.5
          egg(x, lerp(y - 90, peak_y, ease(f)), 24, c[3], {1, 1, 1})
        else
          for j = 1, 50 do
            local an = j * 2.4
            local r = (24 + k * 140) * (0.4 + (j % 7) / 7)
            rgba(CA_COLS[j % 6 + 1], clamp(2 - k, 0, 1))
            lg.rectangle("fill", x + cos(an) * r, peak_y + sin(an) * r * 0.7 + k * k * 80 * (0.5 + (j % 3) * 0.4), 10, 10)
          end
          if k < 0.8 then G:text("POP!", x - 80, peak_y - 60, 30, {1, 0.95, 0.9}, 1 - k / 0.8, "center", 160) end
        end
      else
        if k < 0 then egg(x, y - 130 + k * 40, 24, c[3], {1, 1, 1})
        else
          for j = 1, 50 do
            local an = j * 2.4
            local r = (20 + k * 110) * (0.4 + (j % 7) / 7)
            rgba(CA_COLS[j % 6 + 1], clamp(2 - k, 0, 1))
            lg.rectangle("fill", x + cos(an) * r, y - 90 + sin(an) * r * 0.7 + k * k * 40 * (j % 3), 10, 10)
          end
          if k < 0.8 then G:text("CRACK!", x - 80, y - 200, 30, {1, 0.95, 0.9}, 1 - k / 0.8, "center", 160) end
        end
      end
    end
  end
  if lt > 3 and lt < 5.5 then G:say("ONE CARTON, PLEASE!", 384, 560, 20, 1) end
  for k, t0 in ipairs(SNEAK) do
    local x, y = target_pos(t0, k)
    if lt > t0 + 0.2 and lt < t0 + 2.2 then G:say("HEY!", x, y - 140, 26, 1) end
    if lt > t0 - 2.5 and lt < t0 - 1 then G:say("SHHH...", px, py - 130, 20, 1) end
  end
  if lt > CHASE0 - 1 and lt < CHASE0 + 2 then G:say("GET HIM!", CA_SPOTS[1][1], 620, 26, 1) end
  if lt > 62 and lt < 64 then G:say("MMPH!", px, py - 120, 24, 1) end
  if lt > 66 and lt < 69 then G:say("ALL TOGETHER!", 384, 700, 24, 1) end
end

CAM.cascarones = function(lt)
  -- single continuous keyframe list: zero 0.5s camera snap-back gaps between sneaks
  local keys = {{0, 384, 640, 1.1}, {3, 384, 640, 1.4}, {7.5, 260, 740, 1.4}}
  for k, t0 in ipairs(SNEAK) do
    local x, y = CA_SPOTS[k][1], CA_SPOTS[k][2]
    keys[#keys + 1] = {t0 - 3.0, x - 60, y - 60, 1.4}
    keys[#keys + 1] = {t0 - 0.5, x - 40, y - 80, 1.8}
    keys[#keys + 1] = {t0 + 2.8, x - 40, y - 60, 1.5}
  end
  for _, p in ipairs({{SNEAK[4] + 4.5, 384, 760, 1.2}, {CHASE0, 384, 780, 1.15}, {CHASE1, 384, 800, 1.2},
                      {CHASE1 + 1.2, 384, 820, 1.6}, {64, 384, 820, 1.6}, {67, 384, 680, 1.15}, {80, 384, 620, 1.05}}) do
    keys[#keys + 1] = p
  end
  return L.shot(lt, keys, W, H)
end
CUES.secret = {{8, "chime", 0.5}, {32, "ding", 0.5}, {33, "ding", 0.5}, {36, "pop", 0.4}, {40, "chime"}, {44, "tick", 0.5},
               {45, "tick", 0.5}, {46, "crackle"}, {46.2, "pop"}, {48, "whoosh", 0.4}, {53, "power"}, {59, "chime"}}
for k = 0, 9 do CUES.secret[#CUES.secret + 1] = {9 + k * 2, "tick", 0.3} end
for k = 0, 3 do CUES.secret[#CUES.secret + 1] = {8 + k * 5, "zap", 0.3} end
CUES.dye = {{30.5, "splash"}, {30.7, "boing", 0.5}}
for n = 0, 7 do
  CUES.dye[#CUES.dye + 1] = {n * 7 + 2.1, "splash", 0.35}
  CUES.dye[#CUES.dye + 1] = {n * 7 + 3.6, "ding", 0.45}
end
CUES.dye[#CUES.dye + 1] = {21, "splash"}
CUES.dye[#CUES.dye + 1] = {21.2, "boing"}
CUES.dye[#CUES.dye + 1] = {51, "splash"}
CUES.dye[#CUES.dye + 1] = {51.2, "boing"}
CUES.bunny = {}
for t = 1, 58, 1.25 do
  local c = t % 30
  if not (c > 12 and c < 17) then CUES.bunny[#CUES.bunny + 1] = {t, "boing", 0.15} end
end
for _, t in ipairs({13, 43}) do CUES.bunny[#CUES.bunny + 1] = {t, "pop", 0.5} CUES.bunny[#CUES.bunny + 1] = {t + 0.3, "pop", 0.5} CUES.bunny[#CUES.bunny + 1] = {t + 0.6, "pop", 0.5} end
CUES.finale = {{2.2, "pop", 0.4}, {3.4, "pop", 0.4}, {4.6, "pop", 0.4}, {5.8, "pop", 0.4}, {8, "chime"}, {14, "whoosh", 0.4}, {20, "cheer"}}
CUES.cascarones = {{4.2, "ding"}, {CHASE0, "whoosh"}, {CHASE1, "boing"}, {64, "boing"}, {64.2, "cheer"}, {70, "cheer"}}
for _, c in ipairs(CA_CRACKS) do CUES.cascarones[#CUES.cascarones + 1] = {c[1], "crackle", 0.5} CUES.cascarones[#CUES.cascarones + 1] = {c[1], "pop", 0.5} end
for k, t0 in ipairs(SNEAK) do CUES.cascarones[#CUES.cascarones + 1] = {t0 + 0.2, "boing", 0.5} end

function D.secret(lt, len)
  -- the glitch: stripes and noise, then the hidden room
  if lt > 44.5 and lt < 47 then G:say("IT'S HATCHING!", 384, 440, 24, 1) end
  if lt < 6 then
    local g = lt / 6
    for i = 0, 40 do
      local c = PASTEL[(i + floor(S.t * 20)) % 6 + 1]
      rgba(c, 1)
      lg.rectangle("fill", 0, i * 26, W, 26)
    end
    lg.setColor(0, 0, 0, g)
    lg.rectangle("fill", 0, 0, W, H)
    for i = 1, 40 do
      lg.setColor(1, 1, 1, 1 - g)
      lg.rectangle("fill", G.R:random() * W, G.R:random() * H, 40 + G.R:random() * 200, 6)
    end
    return
  end
  lg.setColor(0, 0, 0, 1)
  lg.rectangle("fill", 0, 0, W, H)
  -- the room: an old blocky screen, one dot that walks up to a hidden message
  lg.setColor(0.9, 0.45, 0.85, 1)
  for i = 0, 11 do
    lg.rectangle("fill", 40 + i * 58, 120, 50, 24)
    lg.rectangle("fill", 40 + i * 58, 860, 50, 24)
  end
  for i = 0, 11 do
    lg.rectangle("fill", 40, 150 + i * 59, 24, 50)
    lg.rectangle("fill", 704, 150 + i * 59, 24, 50)
  end
  local k = clamp((lt - 8) / 20, 0, 1)
  local mx = lerp(120, 384, k)
  C.fx.chomper(mx - 60 + sin(S.t * 3) * 6, 560, 26, 1, S.t, k < 1 and 1 or 0)
  -- all 10 dots eaten cleanly as Pac-Man arrives
  for d = 0, 9 do
    local dx = 140 + d * 24
    if dx > mx - 12 and k < 1 then lg.setColor(1, 0.85, 0.9, 1) lg.rectangle("fill", dx - 5, 555, 10, 10) end
  end
  local gl = (lt - 8) % 5
  if lt > 8 and lt < 28 and gl < 0.35 then
    for i = 1, 6 do
      rgba(PASTEL[i], 0.8)
      lg.rectangle("fill", 0, 120 + ((i * 131 + floor(lt)) % 760), W, 18 + (i % 3) * 14)
    end
  end
  local reveal = clamp((lt - 28) / 2, 0, 1)
  lg.setColor(1, 1, 1, 1)
  lg.rectangle("fill", mx - 8, 560 - 8, 16, 16)
  G:text("YOU FOUND", 0, 340, 54, {1, 0.85, 0.3}, reveal, "center", W)
  G:text("THE EASTER EGG", 0, 410, 54, {1, 0.85, 0.3}, reveal, "center", W)
  G:text("CREATED BY", 0, 640, 30, {0.85, 0.85, 1}, clamp((lt - 32) / 2, 0, 1), "center", W)
  G:text("BLINKY  PINKY  INKY  CLYDE", 0, 690, 30, {0.85, 0.85, 1}, clamp((lt - 33) / 2, 0, 1), "center", W)
  local g = clamp((lt - 36) / 2, 0, 1)
  -- standing ghosts only drawn while lt <= 47.5 (after 47.5 they smoothly peel off into the chase — no 8 duplicate ghosts!)
  if lt <= 47.5 then
    for i, col in ipairs(GHOSTS) do C.fx.ghost(150 + (i - 1) * 156, 790, 30, col, 1, S.t + i, false, false, g) end
  end
  -- the golden egg: in (40), wobbles (44), hatches (46): a chick, round the room, the ghosts after it, a
  -- power pellet (53), the ghosts blue and running in reverse (zero teleport!), the chick after them
  local ga = clamp((lt - 40) / 2, 0, 1)
  local wob = (lt > 44 and lt < 46) and sin(lt * 30) * 0.2 or 0
  if lt < 46 then
    lg.push() lg.translate(384, 560) lg.rotate(wob) lg.translate(-384, -560)
    egg(384, 560, 60 * ga + 0.01, {1, 0.85, 0.3}, {1, 0.5, 0.7}, ga)
    lg.pop()
  else
    -- the shell halves
    lg.setColor(1, 0.85, 0.3, 1)
    lg.arc("fill", "pie", 384, 600, 46, 0, pi, 16)
    lg.arc("fill", "pie", 384 + 40, 520 - min(1, (lt - 46) * 2) * 30, 40, pi, 2 * pi, 16)
    local function round(u) local a = u * 2 * pi return 384 + cos(a) * 250, 560 + sin(a) * 250 end
    local pellet = lt > 53
    local u_peak = (53 - 46.5) * 0.18
    local u = pellet and (u_peak - (lt - 53) * 0.18) or ((lt - 46.5) * 0.18)
    local cx, cy
    if lt < 46.5 then
      cx, cy = 384, 560 - (lt - 46) * 80
    else
      local rx, ry = round(u)
      local fin = prog(lt, 46.5, 47.6)
      cx, cy = lerp(384, rx, fin), lerp(520, ry, fin)
    end
    local move_s = pellet and 1 or -1
    local cdir = lt < 46.5 and 1 or ((sin(u * 2 * pi) * move_s) >= 0 and 1 or -1)
    local hop = abs(sin(S.t * 10)) * 6
    lg.push()
    lg.translate(cx, cy - hop)
    lg.scale(cdir, 1)
    lg.setColor(1, 0.95, 0.3, 1)
    lg.circle("fill", 0, 0, 22, 16)
    lg.circle("fill", 14, -20, 13, 12)
    lg.setColor(1, 0.55, 0.1, 1)
    lg.polygon("fill", 25, -22, 36, -18, 25, -15)
    lg.setColor(0, 0, 0, 1)
    lg.circle("fill", 17, -24, 3, 6)
    lg.pop()
    if lt > 53 and lt < 56 then G:say("CHEEP! CHEEP!", cx, cy - 50, 26, 1) end
    if lt > 47.5 then
      local peel = prog(lt, 47.5, 48.8)
      for i, col in ipairs(GHOSTS) do
        local gu = u - 0.08 - i * 0.06
        local rx, ry = round(gu)
        local gx = lerp(150 + (i - 1) * 156, rx, peel)
        local gy = lerp(790, ry, peel)
        local gdir = (sin(gu * 2 * pi) * move_s) >= 0 and 1 or -1
        local blue = pellet and lt < 59
        C.fx.ghost(gx, gy, 30, blue and {0.2, 0.3, 1} or col, gdir, S.t + i, blue, false, 1)
      end
    end
    -- the power pellet in the corner, blinking until the chick gets it
    if lt < 53 then
      local px, py = round(u_peak)
      if floor(S.t * 4) % 2 == 0 then lg.setColor(1, 0.85, 0.9, 1) lg.circle("fill", px, py, 14, 12) end
    end
  end
end

CAM.secret = function(lt)
  return L.shot(lt, {{0, 384, 512, 1}, {8, 160, 560, 1.6}, {28, 384, 500, 1.3}, {32, 384, 512, 1}, {38, 384, 760, 1.4}, {44, 384, 560, 1.5},
                     {52, 384, 512, 1}}, W, H)
end
CAM.finale = function(lt) return L.shot(lt, {{0, 384, 512, 1}, {10, 384, 760, 1.25}, {22, 384, 680, 1.05}}, W, H) end
function D.finale(lt, len)
  meadow()
  -- checkered finish line across the lawn for the egg-rolling race
  if lt > 7 then
    for r = 0, 11 do
      for c = 0, 1 do
        if (r + c) % 2 == 0 then lg.setColor(1, 1, 1, 0.9) else lg.setColor(0.08, 0.08, 0.12, 0.9) end
        lg.rectangle("fill", 666 + c * 14, 774 + r * 16, 14, 16)
      end
    end
  end
  bunny(70, 740, 0.9, S.t * 3)
  -- the egg-rolling race (8-22): all 5 cast members actually lined up behind the 5 eggs pushing them!
  -- lane 3 = Pac-Man (fastest, wins!); lanes 1, 2, 4, 5 = Blinky, Pinky, Inky, Clyde
  local speeds = {0.92, 0.88, 1.15, 0.84, 0.96}
  local pac_win_x, pac_win_y = 640, 860
  for i = 1, 5 do
    local t0 = 1 + i * 1.1
    local f = clamp((lt - 8) / 14 * speeds[i], 0, 1)
    local ex = lerp(140, 700, f)
    local ey = 800 + (i - 1) * 34
    local push_hop = (lt > 8 and f < 1) and abs(sin(S.t * 9 + i)) * 10 or abs(sin(S.t * 4 + i)) * 8
    if lt > t0 then
      local enter = prog(lt, t0, t0 + 0.7)
      local cx = lerp(-50, ex - 48, enter)
      local cy = ey - 8 - push_hop
      if i == 3 then
        pac_win_x, pac_win_y = cx, cy
        C.fx.chomper(cx, cy, 30, 1, S.t, 1)
        ears(cx, cy, 30, 1)
      else
        local gi = i < 3 and i or i - 1
        C.fx.ghost(cx, cy, 28, GHOSTS[gi], 1, S.t + i, false, false, 1)
        ears(cx, cy, 28, 1)
      end
    end
    lg.push()
    lg.translate(ex, ey)
    lg.rotate(f * 30)
    egg(0, 0, 26, PASTEL[i], PASTEL[(i + 2) % 6 + 1])
    lg.pop()
  end
  if lt > 20.5 and lt < 25 then G:say("WINNER!", pac_win_x, pac_win_y - 54, 26, 1) end
  G:plate("HAPPY EASTER", 330, 80, 0xff6fb5, L.window(lt, 0.5, len, 1))
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
  S.art = {}
  for _, n in ipairs({"meadow", "meadow_oak", "kitchen", "fiesta"}) do S.art[n] = G:art("easter", n) end
  S.flowers, S.eggs, S.trail, S.cracks = {}, {}, {}, {}
  for i = 1, 260 do
    local y = 580 + R:random() * 440
    S.flowers[i] = {R:random() * W, y, R:random() < 0.75 and 1 or (R:random() < 0.6 and 2 or 3)}
  end
  -- the hiding places: left to right and back, so Pac-Man has a walk
  for i = 1, 12 do
    S.eggs[i] = {80 + ((i - 1) % 6) * 110 + R:random() * 40, (i <= 6 and 660 or 790) + R:random() * 60,
                 PASTEL[R:random(6)], PASTEL[R:random(6)]}
  end
  for i = 7, 12 do S.eggs[i][1] = W - S.eggs[i][1] end
  for i = 1, 14 do S.trail[i] = {i * 60, 870 + R:random() * 80, PASTEL[R:random(6)], PASTEL[R:random(6)]} end
  S.carton = {}
  for i = 1, 12 do S.carton[i] = {PASTEL[R:random(6)], {1, 1, 1}} end
  local t = 3
  local cols = {{1, 0.3, 0.5}, {0.3, 0.7, 1}, {1, 0.85, 0.2}, {0.4, 0.85, 0.4}}
  while t < 78 do
    S.cracks[#S.cracks + 1] = {t = t, who = R:random(5), c = cols[R:random(4)]}
    local n = #S.cracks
    if n <= 12 then S.carton[n][3] = t - 1.2 end
    t = t + 2.5 + R:random() * 2.5
  end
  for _, s in ipairs(SCENES) do if s[4] then G:label(s[4], 56, 0xffffff, s[1]) end end
  for _, l in ipairs({{"PRESENTS", 26, 0x6ef0c8, 0}, {"THE EGG HUNT", 76, 0xffb6d9, 0},
                      {"HAPPY EASTER", 80, 0xff6fb5, 330}}) do
    G:label(l[1], l[2], l[3], l[4])
  end
end

function M.act() return S and scene_at(S.t)[2] or "open" end
function M.music() return S and scene_at(S.t)[3] or "eg_hunt" end

function M.update(dt)
  if not S then return false end
  G:step(dt)
  S.t = G.t
  local sc, lt, len = scene_at(S.t)
  for _, c in ipairs(CUES[sc[2]] or {}) do
    if lt - dt < c[1] and lt >= c[1] then
      if type(c[2]) == "function" then c[2]() else C.sfx(c[2], c[3]) end
    end
  end
  if sc[2] == "hunt" then
    local per = (len - 6) / #S.eggs
    local k = (lt - 2) / per
    if k >= 1 and k <= #S.eggs and floor(k) ~= floor((lt - dt - 2) / per) then C.sfx("pop") end
  elseif sc[2] == "secret" then
    if lt >= 28 and lt - dt < 28 then C.sfx("power") end
    if lt < 6 and (lt * 10) % 1 < dt * 10 then C.sfx("zap", 0.2) end
  end
  return S.t >= LEN
end

function M.draw()
  if not S then return end
  local sc, lt, len = scene_at(S.t)
  local cam = CAM[sc[2]]
  local x, y, z = 384, 512, 1
  if cam then x, y, z = cam(lt, len) end
  G:look(x, y, z)
  D[sc[2]](lt, len)
  G:draw_back()
  G:draw_front()
  G:unlook()
  if sc[4] and not (sc[2] == "secret" and lt < 6) then
    G:plate(sc[4], 30, 56, 0xffffff, L.window(lt, 1.5, 9, 1))
    local b = L.window(lt, 2, len - 1.5, 1)
    lg.setColor(0.02, 0.02, 0.06, 0.55 * b)
    lg.rectangle("fill", 0, H - 50, W, 50)
    G:text(sc[5], 0, H - 38, 20, {1, 0.9, 0.95}, b)
  end
  local f = 1 - min(lt / 1.2, (len - lt) / 1.2, 1)
  if f > 0 then
    lg.setColor(0, 0, 0, f)
    lg.rectangle("fill", 0, 0, W, H)
  end
end

return M
