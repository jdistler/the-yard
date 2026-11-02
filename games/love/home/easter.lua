-- Easter Egg Hunt: six minutes (Easter week in AUTO; the date from the Gregorian computus in shows.lua):
--   0:00  PARTYCADE PRESENTS ... THE EGG HUNT                                        (Egg Hunt)
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

local function ears(x, y, r, a)
  lg.setColor(0.97, 0.97, 0.97, a or 1)
  lg.ellipse("fill", x - r * 0.35, y - r * 1.4, r * 0.18, r * 0.55, 10)
  lg.ellipse("fill", x + r * 0.35, y - r * 1.4, r * 0.18, r * 0.55, 10)
  lg.setColor(1, 0.7, 0.8, a or 1)
  lg.ellipse("fill", x - r * 0.35, y - r * 1.38, r * 0.08, r * 0.4, 8)
  lg.ellipse("fill", x + r * 0.35, y - r * 1.38, r * 0.08, r * 0.4, 8)
end

local function meadow()
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
  G:caption("PARTYCADE", 340, 54, 0xff4fd8, a)
  G:caption("PRESENTS", 412, 26, 0x6ef0c8, a)
  G:caption("THE EGG HUNT", 360, 76, 0xffb6d9, L.window(lt, 4.2, 8, 0.7))
end

function D.hunt(lt, len)
  meadow()
  L.live_oak(110, 600, 1.6, S.t)
  -- the eggs, hidden; Pac-Man goes from one to the next and takes it
  local per = (len - 6) / #S.eggs
  local k = clamp((lt - 2) / per, 0, #S.eggs)
  local found = floor(k)
  for i, e in ipairs(S.eggs) do
    if i > found then egg(e[1], e[2], 22, e[3], e[4]) end
  end
  local i = min(found + 1, #S.eggs)
  local prev = S.eggs[max(found, 1)]
  local cur = S.eggs[i]
  local f = ease((k - found) * 1.4)
  local px = found == 0 and lerp(-40, cur[1], f) or lerp(prev[1], cur[1], f)
  local py = found == 0 and lerp(900, cur[2], f) or lerp(prev[2], cur[2], f)
  local dir = (cur[1] >= (found == 0 and -40 or prev[1])) and 1 or -1
  C.fx.chomper(px, py - 20, 26, dir, S.t, 1)
  -- the basket in the corner with its count
  lg.setColor(0.7, 0.5, 0.25, 1)
  lg.rectangle("fill", 560, 880, 160, 80, 10, 10, 6)
  lg.setLineWidth(6)
  lg.arc("line", "open", 640, 880, 70, pi, 2 * pi, 20)
  for j = 1, min(found, 12) do
    local e = S.eggs[j]
    egg(578 + ((j - 1) % 6) * 25, 876 - floor((j - 1) / 6) * 16, 14, e[3], e[4])
  end
  G:text(found .. " / " .. #S.eggs, 560, 968, 24, {1, 1, 1}, 1, "center", 160)
  -- a ghost hides the last one again, now and then
  local g = lt % 15
  if g < 4 then
    local gx = 680 - g * 20
    C.fx.ghost(gx, 640, 24, GHOSTS[4], -1, S.t, false, false, 0.7)
  end
end

function D.dye(lt, len)
  G:gradient(0, 0, W, H, {1, 0.96, 0.88}, {0.95, 0.85, 0.75})
  -- the table, six cups
  lg.setColor(0.85, 0.65, 0.45, 1)
  lg.rectangle("fill", 0, 640, W, 384)
  local cols = {{1, 0.3, 0.45}, {0.3, 0.6, 1}, {1, 0.85, 0.2}, {0.3, 0.85, 0.4}, {0.65, 0.4, 0.95}, {1, 0.55, 0.2}}
  for i, c in ipairs(cols) do
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
  egg(x, y, 40, c, k > 0.5 and {1, 1, 1} or nil)
  -- the done ones, drying
  for j = 1, min(floor(lt / per), 12) do
    local cc = cols[(j - 1) % 6 + 1]
    egg(80 + (j - 1) * 56, 860 + (j % 2) * 30, 26, cc, PASTEL[j % 6 + 1])
  end
  -- Inky, every half minute, dips himself
  local g = lt % 30
  if g > 18 and g < 28 then
    local gk = (g - 18) / 10
    local gy = gk < 0.3 and lerp(300, 600, ease(gk / 0.3)) or gk < 0.5 and 600 or lerp(600, 380, ease((gk - 0.5) / 0.5))
    local gc = gk < 0.4 and GHOSTS[3] or {0.65, 0.4, 0.95}
    C.fx.ghost(684, gy, 34, gc, -1, S.t, false, false, 1)
    if gk > 0.6 then G:text("...PURPLE NOW", 470, gy - 90, 26, {0.5, 0.3, 0.8}, 1, "center", 300) end
  end
end

function D.bunny(lt, len)
  meadow()
  -- the bunny hops across, the ghosts in ears behind it, copying every hop; a 30 s loop
  local c = lt % 30
  local x0 = lerp(-120, W + 600, c / 30)
  local hop = c * pi * 1.6
  bunny(x0, 820, 1.2, hop)
  for i, col in ipairs(GHOSTS) do
    local gx = x0 - 150 - (i - 1) * 110
    local gy = 820 - abs(sin(hop - i * 0.6)) * 60
    C.fx.ghost(gx, gy, 30, col, 1, S.t, false, false, 1)
    ears(gx, gy, 30, 1)
  end
  local px = x0 - 150 - 4 * 110
  C.fx.chomper(px, 830 - abs(sin(hop - 3)) * 60, 30, 1, S.t, 1)
  ears(px, 830 - abs(sin(hop - 3)) * 60, 30, 1)
  -- eggs left behind where the bunny's been
  for i, e in ipairs(S.trail) do
    if e[1] < x0 - 60 then egg(e[1], e[2], 18, e[3], e[4]) end
  end
end

function D.cascarones(lt, len)
  G:gradient(0, 0, W, H, {0.55, 0.8, 1}, {1, 0.9, 0.7})
  -- the papel picado overhead
  local cols = {{1, 0.3, 0.5}, {0.3, 0.7, 1}, {1, 0.85, 0.2}, {0.4, 0.85, 0.4}, {0.75, 0.45, 1}, {1, 0.55, 0.2}}
  for row = 0, 1 do
    lg.setColor(0.4, 0.4, 0.4, 1)
    lg.setLineWidth(2)
    lg.line(0, 80 + row * 120, W, 100 + row * 120)
    for i = 0, 9 do
      rgba(cols[(i + row) % 6 + 1])
      local x = i * 80 + row * 40
      local y = 82 + row * 120 + i * 2 + sin(S.t * 2 + i) * 3
      lg.rectangle("fill", x, y, 64, 70)
      lg.setColor(1, 1, 1, 0.5)
      lg.circle("fill", x + 32, y + 30, 10, 10)
      lg.rectangle("fill", x + 12, y + 52, 40, 6)
    end
  end
  G:gradient(0, 720, W, H, {0.5, 0.7, 0.35}, {0.38, 0.58, 0.28})
  -- the table with the cartons, a sign
  lg.setColor(0.55, 0.35, 0.2, 1)
  lg.rectangle("fill", 200, 560, 368, 22, 4, 4, 4)
  lg.rectangle("fill", 220, 582, 16, 120)
  lg.rectangle("fill", 532, 582, 16, 120)
  for c = 0, 1 do
    lg.setColor(0.8, 0.75, 0.65, 1)
    lg.rectangle("fill", 222 + c * 170, 520, 156, 44, 6, 6, 4)
    for j = 0, 5 do
      local e = S.carton[c * 6 + j + 1]
      if not e[3] or lt < e[3] then egg(240 + c * 170 + j * 24, 522, 15, e[1], e[2]) end
    end
  end
  G:text("CASCARONES  50¢", 200, 470, 30, {0.85, 0.2, 0.45}, 1, "center", 368)
  -- the cast, standing about; every few seconds someone gets one on the head
  local who = {
    {130, 720, "pac"}, {300, 740, 1}, {470, 720, 2}, {640, 740, 3}, {384, 900, 4},
  }
  for i, p in ipairs(who) do
    if p[3] == "pac" then C.fx.chomper(p[1], p[2], 56, 1, 0, 1)
    else C.fx.ghost(p[1], p[2], 54, GHOSTS[p[3]], i % 2 == 0 and 1 or -1, S.t + i, false, false, 1) end
  end
  for _, h in ipairs(S.cracks) do
    local k = lt - h.t
    if k > -1.2 and k < 2.5 then
      local p = who[h.who]
      -- the egg coming down
      if k < 0 then egg(p[1] + k * 60, p[2] - 70 + k * k * 100, 30, h.c, {1, 1, 1}) end
      -- the confetti on and around them after
      if k >= 0 then
        for j = 1, 60 do
          local an = j * 2.4
          local r = (20 + k * 90) * (0.4 + (j % 7) / 7)
          rgba(cols[j % 6 + 1], clamp(2.5 - k, 0, 1))
          lg.rectangle("fill", p[1] + cos(an) * r, p[2] - 60 + sin(an) * r * 0.7 + k * k * 30 * (j % 3), 9, 9)
        end
        if k < 1 then
          lg.setColor(1, 1, 1, 1 - k)
          G:text("CRACK!", p[1] - 80, p[2] - 150, 30, {1, 0.95, 0.9}, 1 - k, "center", 160)
        end
      end
    end
  end
end

function D.secret(lt, len)
  -- the glitch: stripes and noise, then the hidden room
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
  local reveal = clamp((lt - 28) / 2, 0, 1)
  lg.setColor(1, 1, 1, 1)
  lg.rectangle("fill", mx - 8, 560 - 8, 16, 16)
  G:text("YOU FOUND", 0, 340, 54, {1, 0.85, 0.3}, reveal, "center", W)
  G:text("THE EASTER EGG", 0, 410, 54, {1, 0.85, 0.3}, reveal, "center", W)
  G:text("CREATED BY", 0, 640, 30, {0.85, 0.85, 1}, clamp((lt - 32) / 2, 0, 1), "center", W)
  G:text("BLINKY  PINKY  INKY  CLYDE", 0, 690, 30, {0.85, 0.85, 1}, clamp((lt - 33) / 2, 0, 1), "center", W)
  local g = clamp((lt - 36) / 2, 0, 1)
  for i, col in ipairs(GHOSTS) do C.fx.ghost(150 + (i - 1) * 156, 790, 30, col, 1, S.t + i, false, false, g) end
  egg(384, 560, 60 * clamp((lt - 40) / 2, 0, 1) + 0.01, {1, 0.85, 0.3}, {1, 0.5, 0.7}, clamp((lt - 40) / 2, 0, 1))
end

function D.finale(lt, len)
  meadow()
  for i = 1, 7 do egg(84 + (i - 1) * 100, 900 + sin(S.t * 2 + i) * 6, 40, PASTEL[(i - 1) % 6 + 1], PASTEL[i % 6 + 1]) end
  bunny(140, 790, 1, S.t * 3)
  C.fx.chomper(580, 780, 34, -1, 0, 1)
  ears(580, 780, 34, 1)
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
  for _, s in ipairs(SCENES) do if s[4] then G:label(s[4], 56, 0xffffff) end end
  for _, l in ipairs({{"PARTYCADE", 54, 0xff4fd8}, {"PRESENTS", 26, 0x6ef0c8}, {"THE EGG HUNT", 76, 0xffb6d9},
                      {"HAPPY EASTER", 80, 0xff6fb5}}) do
    G:label(l[1], l[2], l[3])
  end
end

function M.act() return S and scene_at(S.t)[2] or "open" end
function M.music() return S and scene_at(S.t)[3] or "eg_hunt" end

function M.update(dt)
  if not S then return false end
  G:step(dt)
  S.t = G.t
  local sc, lt, len = scene_at(S.t)
  if sc[2] == "hunt" then
    local per = (len - 6) / #S.eggs
    local k = (lt - 2) / per
    if k >= 1 and k <= #S.eggs and floor(k) ~= floor((lt - dt - 2) / per) then C.sfx("pop") end
  elseif sc[2] == "cascarones" then
    for _, h in ipairs(S.cracks) do
      if lt >= h.t and lt - dt < h.t then C.sfx("crackle", 0.5) end
    end
  elseif sc[2] == "secret" then
    if lt >= 28 and lt - dt < 28 then C.sfx("power") end
    if lt < 6 and (lt * 10) % 1 < dt * 10 then C.sfx("zap", 0.2) end
  end
  return S.t >= LEN
end

function M.draw()
  if not S then return end
  local sc, lt, len = scene_at(S.t)
  D[sc[2]](lt, len)
  G:draw_back()
  G:draw_front()
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
