-- Thanksgiving: Home's show for the week of it (shows.lua's calendar), eight minutes:
--   0:00  PARTYCADE PRESENTS ... THANKSGIVING, leaves falling                    (Harvest Moon)
--   0:08  The parade: giant balloons down the avenue (Pac-Man, a ghost, a turkey) with their handlers,
--         a float, the crowd, confetti                                              (Parade Day)
--   1:50  The Great Turkey Chase: Pac-Man after the turkey round the farmyard; the turkey hides, doubles back,
--         and is pardoned                                                           (Turkey Trot)
--   3:20  Autumn: an old oak dropping its leaves on the porch, pumpkins, hay bales, a warm sunset  (Grateful)
--   4:20  The table: Pac-Man carves, the ghosts pass the dishes                    (Grateful)
--   5:50  Football on TV: Texas and A&M on Thanksgiving, everyone too full to move  (Football Sunday)
--   6:50  Pie: pecan, pumpkin, apple, one slice at a time                           (Pie Polka)
--   7:40  HAPPY THANKSGIVING
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
  {0, "open", "tg_harvest"},
  {8, "parade", "tg_parade", "THE PARADE", "BALLOONS DOWN THE AVENUE"},
  {110, "chase", "tg_trot", "THE GREAT TURKEY CHASE", "ON THE FARM  ·  NOBODY CATCHES THIS TURKEY"},
  {200, "autumn", "tg_grateful", "AUTUMN", "THE OLD OAK  ·  THE PORCH  ·  THE HARVEST"},
  {260, "table", "tg_grateful", "THE TABLE", "GIVE THANKS"},
  {350, "football", "tg_football", "FOOTBALL ON TV", "TOO FULL TO MOVE"},
  {410, "pie", "tg_pie", "SAVE ROOM FOR PIE", "PECAN  ·  PUMPKIN  ·  APPLE"},
  {460, "finale", "tg_harvest"},
}
M.SEGMENTS = {}
for _, s in ipairs(SCENES) do if s[4] then M.SEGMENTS[#M.SEGMENTS + 1] = {s[1], s[4]} end end
M.THUMB = 4

local S
local function scene_at(t)
  local k = 1
  for i, s in ipairs(SCENES) do if t >= s[1] then k = i end end
  local s = SCENES[k]
  local e = SCENES[k + 1] and SCENES[k + 1][1] or LEN
  return s, t - s[1], e - s[1], k
end
local function rgba(c, a) lg.setColor(c[1], c[2], c[3], a or 1) end
local LEAF = {{0.85, 0.3, 0.1}, {0.95, 0.55, 0.1}, {0.8, 0.15, 0.1}, {0.95, 0.75, 0.2}, {0.6, 0.3, 0.1}}
local GHOSTS = {{1, 0.18, 0.2}, {1, 0.55, 0.85}, {0.25, 0.95, 1}, {1, 0.65, 0.2}}

-- ------------------------------------------------------------------ the cast
-- A turkey (facing dir), running or standing; fan spread k (0..1)
local function turkey(x, y, s, dir, t, run, fan)
  lg.push()
  lg.translate(x, y)
  lg.scale(s * dir, s)
  fan = fan or 1
  for i = -3, 3 do
    local a = -pi / 2 + i * 0.32 * fan - 0.4
    local c = LEAF[(i + 4) % #LEAF + 1]
    rgba(c)
    lg.ellipse("fill", -18 + cos(a) * 40, -24 + sin(a) * 40, 12, 26, 12)
  end
  lg.setColor(0.42, 0.26, 0.15, 1)
  lg.ellipse("fill", 0, 0, 34, 28, 20)
  lg.setColor(0.32, 0.2, 0.12, 1)
  lg.ellipse("fill", -6, 4, 22, 16, 16)
  local step = run and sin(t * 18) * 8 or 0
  lg.setColor(0.95, 0.7, 0.2, 1)
  lg.setLineWidth(4)
  lg.line(-6, 24, -6 + step, 44)
  lg.line(8, 24, 8 - step, 44)
  -- neck and head
  lg.setColor(0.5, 0.36, 0.3, 1)
  lg.polygon("fill", 22, -6, 30, -40, 40, -38, 32, -2)
  lg.circle("fill", 38, -44, 9, 12)
  lg.setColor(1, 0.8, 0.15, 1)
  lg.polygon("fill", 45, -46, 56, -42, 45, -40)
  lg.setColor(0.85, 0.1, 0.1, 1)
  lg.ellipse("fill", 46, -34, 4, 9, 10)
  lg.setColor(0, 0, 0, 1)
  lg.circle("fill", 40, -47, 2, 6)
  lg.pop()
end

-- A pie, whole or with slices gone (0..8), seen at a slant
local function pie(x, y, r, kind, gone)
  local crust, fill = {0.82, 0.6, 0.32}, ({pecan = {0.42, 0.22, 0.1}, pumpkin = {0.88, 0.5, 0.15}, apple = {0.86, 0.66, 0.3}})[kind]
  lg.setColor(0.92, 0.92, 0.95, 1)
  lg.ellipse("fill", x, y + 10, r + 16, (r + 16) * 0.4, 32)
  rgba(crust)
  lg.ellipse("fill", x, y + 6, r, r * 0.38, 32)
  rgba(fill)
  lg.ellipse("fill", x, y, r - 8, (r - 8) * 0.36, 32)
  if kind == "pecan" then
    lg.setColor(0.55, 0.32, 0.15, 1)
    for i = 0, 11 do
      local a = i / 12 * 2 * pi
      lg.ellipse("fill", x + cos(a) * (r - 22), y + sin(a) * (r - 22) * 0.36, 7, 4, 10)
    end
  elseif kind == "apple" then
    rgba(crust)
    lg.setLineWidth(5)
    for i = -2, 2 do lg.line(x + i * 18 - 10, y - 14, x + i * 18 + 10, y + 14) lg.line(x + i * 18 + 10, y - 14, x + i * 18 - 10, y + 14) end
  else
    lg.setColor(1, 1, 1, 0.95)
    lg.ellipse("fill", x, y - 2, 14, 7, 12)
  end
  -- slices gone: dark wedges (the plate shows)
  if gone and gone > 0 then
    -- (the plate shows where slices have gone: a wedge, squashed like the pie)
    lg.push()
    lg.translate(x, y + 2)
    lg.scale(1, 0.37)
    lg.setColor(0.92, 0.92, 0.95, 1)
    lg.arc("fill", "pie", 0, 0, r + 1, -pi / 2, -pi / 2 + gone / 8 * 2 * pi, 24)
    lg.pop()
  end
end

-- a cartoon roast turkey on its platter
local function roast(x, y, s)
  lg.setColor(0.92, 0.92, 0.95, 1)
  lg.ellipse("fill", x, y + 34 * s, 130 * s, 36 * s, 32)
  lg.setColor(0.7, 0.4, 0.15, 1)
  lg.ellipse("fill", x, y, 96 * s, 60 * s, 32)
  lg.setColor(0.85, 0.55, 0.22, 1)
  lg.ellipse("fill", x - 16 * s, y - 14 * s, 60 * s, 30 * s, 24)
  for i = -1, 1, 2 do
    lg.setColor(0.7, 0.4, 0.15, 1)
    lg.ellipse("fill", x + i * 84 * s, y + 6 * s, 30 * s, 20 * s, 16)
    lg.setColor(1, 1, 1, 1)
    lg.circle("fill", x + i * 112 * s, y + 2 * s, 9 * s, 10)
  end
  lg.setColor(0.35, 0.6, 0.2, 1)
  for i = 0, 5 do lg.circle("fill", x - 110 * s + i * 44 * s, y + 46 * s, 9 * s, 10) end
end

-- ------------------------------------------------------------------ the scenes
local D = {}

local function leaves_back()
  lg.setColor(1, 1, 1, 1)
end

function D.open(lt, len)
  G:gradient(0, 0, W, H, {0.3, 0.12, 0.08}, {0.75, 0.38, 0.12})
  C.fx.glow(384, 460, 300, 260, 1, 0.6, 0.2, 0.3)
  local a = L.window(lt, 0.4, 4, 0.7)
  G:caption("PARTYCADE", 400, 54, 0xff4fd8, a)
  G:caption("PRESENTS", 472, 26, 0x6ef0c8, a)
  G:caption("THANKSGIVING", 430, 72, 0xffb347, L.window(lt, 4.2, 8, 0.7))
end

function D.parade(lt, len)
  G:gradient(0, 0, W, 560, {0.45, 0.62, 0.9}, {0.86, 0.9, 0.98})
  -- buildings both sides
  for i, b in ipairs({{0, 120, 380, {0.55, 0.45, 0.42}}, {120, 100, 300, {0.62, 0.55, 0.5}}, {548, 110, 340, {0.5, 0.48, 0.55}},
                      {658, 110, 400, {0.6, 0.5, 0.45}}}) do
    rgba(b[4])
    lg.rectangle("fill", b[1], 620 - b[3], b[2], b[3])
    lg.setColor(0.95, 0.9, 0.7, 0.8)
    for wy = 620 - b[3] + 20, 600, 40 do for wx = b[1] + 12, b[1] + b[2] - 24, 28 do lg.rectangle("fill", wx, wy, 14, 20) end end
  end
  -- the avenue, the crowd behind the barriers
  G:gradient(0, 620, W, H, {0.5, 0.5, 0.52}, {0.4, 0.4, 0.42})
  for i = 0, 30 do
    local c = ({{0.8, 0.2, 0.2}, {0.2, 0.4, 0.8}, {0.9, 0.7, 0.2}, {0.3, 0.6, 0.3}, {0.6, 0.3, 0.6}})[i % 5 + 1]
    rgba(c)
    local hop = abs(sin(S.t * 3 + i)) * 4
    lg.rectangle("fill", i * 26, 612 - hop, 18, 26, 6, 6, 4)
    lg.setColor(0.9, 0.72, 0.58, 1)
    lg.circle("fill", i * 26 + 9, 604 - hop, 7, 10)
  end
  lg.setColor(0.6, 0.6, 0.65, 1)
  lg.rectangle("fill", 0, 636, W, 8)
  -- the balloons, one after another, with their handlers and ropes
  local order = {"pac", "ghost", "turkey"}
  for i, kind in ipairs(order) do
    local x = -260 + ((lt - (i - 1) * 28) * 24)
    if x > -300 and x < W + 300 then
      local bob = sin(S.t * 1.3 + i) * 10
      local by = 330 + bob
      -- the handlers and ropes
      for h = -2, 2 do
        local hx = x + h * 40
        lg.setColor(0.85, 0.85, 0.88, 0.8)
        lg.setLineWidth(2)
        lg.line(hx, 860, x + h * 30, by + 120)
        lg.setColor(0.2, 0.35, 0.7, 1)
        lg.rectangle("fill", hx - 8, 860, 16, 30, 4, 4, 4)
        lg.setColor(0.9, 0.72, 0.58, 1)
        lg.circle("fill", hx, 852, 7, 10)
      end
      if kind == "pac" then
        C.fx.chomper(x, by, 130, 1, S.t * 0.2, 1)
        lg.setColor(1, 1, 1, 0.25)
        lg.ellipse("fill", x - 40, by - 70, 40, 18, 16)
      elseif kind == "ghost" then
        C.fx.ghost(x, by, 120, GHOSTS[1], 1, S.t, false, false, 1)
      else
        turkey(x, by + 40, 3.2, 1, S.t, false, 0.9 + 0.1 * sin(S.t))
      end
    end
  end
  -- the float: a horn of plenty
  local fx = -400 + (lt - 70) * 40
  if fx > -400 and fx < W + 200 then
    lg.setColor(0.6, 0.35, 0.15, 1)
    lg.rectangle("fill", fx, 780, 360, 70, 10, 10, 6)
    lg.setColor(0.2, 0.2, 0.22, 1)
    for i = 0, 3 do lg.circle("fill", fx + 40 + i * 90, 852, 16, 12) end
    lg.setColor(0.85, 0.6, 0.25, 1)
    lg.polygon("fill", fx + 40, 780, fx + 220, 700, fx + 240, 780)
    for i, c in ipairs({{1, 0.5, 0.1}, {0.8, 0.15, 0.15}, {0.95, 0.85, 0.2}, {0.5, 0.25, 0.6}, {0.3, 0.6, 0.2}}) do
      rgba(c)
      lg.circle("fill", fx + 240 + i * 18, 760 - (i % 2) * 14, 16, 14)
    end
  end
  if G.R:random() < 0.3 then G:confetti(1, {{1, 0.5, 0.1}, {0.95, 0.8, 0.2}, {0.8, 0.2, 0.15}, {1, 1, 1}}) end
end

function D.chase(lt, len)
  G:gradient(0, 0, W, 600, {0.5, 0.7, 0.95}, {0.95, 0.85, 0.7})
  -- the barn, the fence, the field
  lg.setColor(0.65, 0.15, 0.12, 1)
  lg.rectangle("fill", 480, 380, 240, 220)
  lg.polygon("fill", 470, 380, 600, 290, 730, 380)
  lg.setColor(0.95, 0.92, 0.85, 1)
  lg.rectangle("fill", 560, 470, 80, 130)
  lg.setLineWidth(4)
  lg.line(560, 470, 640, 600)
  lg.line(640, 470, 560, 600)
  G:gradient(0, 600, W, H, {0.75, 0.62, 0.3}, {0.55, 0.45, 0.2})
  lg.setColor(0.5, 0.35, 0.2, 1)
  lg.rectangle("fill", 0, 640, W, 8)
  lg.rectangle("fill", 0, 680, W, 8)
  for x = 10, W, 80 do lg.rectangle("fill", x, 620, 10, 90) end
  -- hay bales, a pumpkin patch
  for i, hb in ipairs({{120, 840}, {300, 900}}) do
    lg.setColor(0.92, 0.78, 0.35, 1)
    lg.rectangle("fill", hb[1] - 60, hb[2] - 50, 120, 60, 8, 8, 6)
    lg.setColor(0.75, 0.6, 0.25, 1)
    lg.rectangle("fill", hb[1] - 60, hb[2] - 30, 120, 4)
  end
  for i = 0, 4 do
    lg.setColor(0.95, 0.5, 0.1, 1)
    lg.ellipse("fill", 480 + i * 60, 960 - (i % 2) * 20, 26, 20, 16)
    lg.setColor(0.3, 0.5, 0.2, 1)
    lg.rectangle("fill", 478 + i * 60, 936 - (i % 2) * 20, 4, 8)
  end
  -- the chase: laps of the yard; the turkey hides behind the bale, Pac-Man runs past, the turkey goes the other way
  local p = (lt % 30) / 30
  local tx, ty, tdir, px, pdir
  if p < 0.5 then
    local k = p / 0.5
    tx, tdir = lerp(-80, W + 120, k), 1
    px, pdir = tx - 170, 1
  else
    local k = (p - 0.5) / 0.5
    tx, tdir = lerp(W + 120, -80, k), -1
    px, pdir = tx + 170, -1
  end
  ty = 800 + sin(lt * 9) * 6
  if lt > 60 and lt < 80 then
    -- hiding behind the bale; Pac-Man looks around
    tx, ty, tdir = 120, 790, 1
    px, pdir = 380 + sin(lt * 1.5) * 160, sin(lt * 1.5) > 0 and 1 or -1
  end
  if lt >= 80 then
    -- pardoned: the turkey with its medal, Pac-Man with pie
    tx, ty, tdir = 260, 800, 1
    px, pdir = 520, -1
  end
  turkey(tx, ty, 1.5, tdir, S.t, lt < 60 or (lt > 60 and lt < 62), lt >= 80 and 1 or 0.8)
  C.fx.chomper(px, 820, 34, pdir, S.t, 1)
  if lt > 60 and lt < 80 then
    lg.setColor(0.92, 0.78, 0.35, 1)
    lg.rectangle("fill", 60, 790, 120, 60, 8, 8, 6)
  end
  if lt >= 80 then
    lg.setColor(1, 0.82, 0.25, 1)
    lg.circle("fill", 300, 790, 12, 16)
    lg.setColor(0.2, 0.3, 0.8, 1)
    lg.polygon("fill", 292, 770, 308, 770, 304, 780, 296, 780)
    G:plate("PARDONED!", 640, 56, 0xffd23f, clamp((lt - 80) * 2, 0, 1))
  end
end

function D.autumn(lt, len)
  local k = lt / len
  G:gradient(0, 0, W, 700, mix({0.4, 0.5, 0.85}, {0.3, 0.2, 0.45}, k), mix({1, 0.75, 0.45}, {1, 0.5, 0.3}, k))
  C.fx.glow(560, 560, 260, 160, 1, 0.6, 0.3, 0.45)
  -- the hills, the oak in its colours
  G:gradient(0, 640, W, H, {0.55, 0.45, 0.2}, {0.4, 0.3, 0.15})
  lg.setColor(0.3, 0.2, 0.12, 1)
  lg.polygon("fill", 170, 900, 210, 900, 200, 600, 180, 600)
  lg.setLineWidth(10)
  lg.line(190, 640, 90, 520)
  lg.line(190, 620, 310, 500)
  for i, c in ipairs({{100, 480, 90}, {200, 430, 110}, {320, 470, 90}, {150, 540, 80}, {260, 540, 80}}) do
    rgba(LEAF[i])
    lg.circle("fill", c[1], c[2], c[3], 24)
  end
  -- the porch: steps, the rail, pumpkins, a hay bale, a rocking chair
  lg.setColor(0.55, 0.38, 0.25, 1)
  lg.rectangle("fill", 400, 760, 368, 200)
  lg.setColor(0.45, 0.3, 0.2, 1)
  for y = 780, 940, 40 do lg.rectangle("fill", 400, y, 368, 4) end
  lg.setColor(0.95, 0.92, 0.85, 1)
  lg.rectangle("fill", 400, 700, 368, 10)
  for x = 410, 768, 30 do lg.rectangle("fill", x, 700, 8, 60) end
  for i, p in ipairs({{460, 760, 34}, {520, 770, 24}, {700, 760, 30}}) do
    lg.setColor(0.95, 0.5, 0.1, 1)
    lg.ellipse("fill", p[1], p[2] - p[3] * 0.6, p[3], p[3] * 0.75, 20)
    lg.setColor(0.3, 0.5, 0.2, 1)
    lg.rectangle("fill", p[1] - 2, p[2] - p[3] * 1.4, 4, 10)
  end
  local rock = sin(S.t * 1.2) * 0.08
  lg.push()
  lg.translate(620, 760)
  lg.rotate(rock)
  lg.setColor(0.4, 0.25, 0.15, 1)
  lg.rectangle("fill", -30, -100, 8, 100)
  lg.rectangle("fill", -30, -40, 60, 8)
  lg.rectangle("fill", 22, -40, 8, 40)
  lg.setLineWidth(6)
  lg.arc("line", "open", 0, -10, 40, 0.2, pi - 0.2, 16)
  lg.pop()
  local a = L.window(lt, 14, 40, 2)
  G:plate("GRATEFUL FOR YOU", 200, 40, 0xffd23f, a)
end

function D.table(lt, len)
  G:gradient(0, 0, W, H, {0.35, 0.2, 0.12}, {0.2, 0.1, 0.06})
  -- the window, the wallpaper stripes
  lg.setColor(0.4, 0.25, 0.15, 1)
  for x = 0, W, 48 do lg.rectangle("fill", x, 0, 20, 560) end
  lg.setColor(0.15, 0.2, 0.35, 1)
  lg.rectangle("fill", 280, 120, 208, 260)
  lg.setColor(0.95, 0.9, 0.75, 1)
  lg.setLineWidth(8)
  lg.rectangle("line", 280, 120, 208, 260)
  lg.line(384, 120, 384, 380)
  lg.line(280, 250, 488, 250)
  -- the table and the cloth
  lg.setColor(0.8, 0.25, 0.15, 1)
  lg.rectangle("fill", 40, 600, 688, 340, 12, 12, 6)
  lg.setColor(0.95, 0.92, 0.85, 1)
  lg.rectangle("fill", 70, 620, 628, 290, 10, 10, 6)
  -- the guests: ghosts left and right, Pac-Man at the head
  for i, c in ipairs(GHOSTS) do
    local side = i <= 2 and -1 or 1
    local x = 384 + side * (250 + (i % 2) * 70)
    local y = 560 + (i % 2) * 20
    C.fx.ghost(x, y, 40, c, -side, S.t + i, false, false, 1)
  end
  C.fx.chomper(384, 520, 50, 1, S.t * 0.3, 1)
  -- the feast
  roast(384, 720, 1)
  pie(170, 820, 50, "pumpkin", 0)
  pie(600, 820, 50, "pecan", 0)
  lg.setColor(0.95, 0.95, 0.9, 1)
  lg.ellipse("fill", 190, 680, 44, 20, 20)
  lg.setColor(0.7, 0.1, 0.2, 1)
  lg.ellipse("fill", 190, 676, 32, 13, 20)
  lg.setColor(0.95, 0.92, 0.82, 1)
  lg.ellipse("fill", 580, 680, 50, 22, 20)
  lg.setColor(0.98, 0.95, 0.85, 1)
  lg.ellipse("fill", 580, 668, 34, 18, 20)
  lg.setColor(0.6, 0.4, 0.2, 1)
  lg.ellipse("fill", 580, 660, 14, 6, 12)
  -- the carving: a knife going up and down at Pac-Man's place
  local cut = abs(sin(S.t * 3)) * 18
  lg.setColor(0.8, 0.82, 0.86, 1)
  lg.polygon("fill", 430, 640 + cut, 470, 600 + cut, 476, 606 + cut, 436, 646 + cut)
  -- steam
  if G.R:random() < 0.3 then G:puff(330 + G.R:random() * 110, 680, {1, 1, 1}, 30, 4, 2, 6, 0.3) end
  local a = L.window(lt, 30, 60, 2)
  G:plate("WHAT ARE YOU THANKFUL FOR?", 860, 32, 0xffffff, a)
end

function D.football(lt, len)
  G:gradient(0, 0, W, H, {0.18, 0.14, 0.2}, {0.1, 0.08, 0.12})
  -- the TV with a game on: Texas and A&M
  lg.setColor(0.08, 0.08, 0.1, 1)
  lg.rectangle("fill", 134, 140, 500, 320, 12, 12, 6)
  G:gradient(150, 156, 618, 444, {0.2, 0.55, 0.2}, {0.15, 0.45, 0.15})
  lg.setColor(1, 1, 1, 0.8)
  for i = 0, 6 do lg.rectangle("fill", 150 + i * 78, 156, 3, 288) end
  for i = 0, 10 do
    local x = 150 + ((S.t * 30 + i * 47) % 460)
    lg.setColor(i % 2 == 0 and 0.95 or 0.4, i % 2 == 0 and 0.45 or 0.05, i % 2 == 0 and 0.05 or 0.05, 1)
    lg.circle("fill", x, 240 + (i * 37) % 160, 6, 10)
  end
  lg.setColor(0, 0, 0, 0.7)
  lg.rectangle("fill", 150, 410, 468, 34)
  G:text("TEX 24   TA&M 17   4TH 2:00", 150, 416, 22, {1, 1, 1}, 1, "center", 468)
  lg.setColor(0.25, 0.2, 0.18, 1)
  lg.rectangle("fill", 360, 460, 48, 40)
  -- the couch, everyone on it
  lg.setColor(0.45, 0.25, 0.18, 1)
  lg.rectangle("fill", 60, 760, 648, 180, 30, 30, 8)
  lg.rectangle("fill", 40, 700, 688, 90, 30, 30, 8)
  lg.setColor(0.55, 0.32, 0.22, 1)
  lg.rectangle("fill", 80, 800, 608, 80, 20, 20, 8)
  for i, c in ipairs(GHOSTS) do
    local x = 130 + (i - 1) * 110 + (i > 2 and 140 or 0)
    C.fx.ghost(x, 760 + (i == 3 and abs(sin(S.t * 6)) * -14 or 0), 38, c, 1, S.t + i, false, false, 1)
  end
  -- Pac-Man in the middle, asleep, full
  lg.setColor(1, 0.86, 0.15, 1)
  lg.circle("fill", 384, 760, 52, 32)
  lg.setColor(0.1, 0.05, 0.1, 1)
  lg.setLineWidth(3)
  lg.line(370, 744, 386, 744)
  for i = 0, 2 do
    local k = ((S.t * 0.5 + i / 3) % 1)
    G:text("z", 420 + k * 50, 700 - k * 90, floor(22 + k * 20), {0.85, 0.85, 1}, 1 - k, "left", 40)
  end
  if floor(lt / 6) % 3 == 1 then
    G:plate("TOUCHDOWN!", 520, 40, 0xff8c1a, L.window(lt % 6, 0, 3, 0.3))
  end
end

function D.pie(lt, len)
  G:gradient(0, 0, W, H, {0.98, 0.9, 0.78}, {0.92, 0.75, 0.55})
  lg.setColor(0.85, 0.65, 0.45, 1)
  lg.rectangle("fill", 0, 700, W, 324)
  local gone = floor(lt / 6) % 6
  pie(200, 520, 100, "pecan", gone)
  pie(570, 520, 100, "pumpkin", (gone + 2) % 6)
  pie(384, 820, 110, "apple", (gone + 4) % 6)
  G:text("PECAN", 100, 640, 26, {0.45, 0.22, 0.1}, 1, "center", 200)
  G:text("PUMPKIN", 470, 640, 26, {0.6, 0.3, 0.1}, 1, "center", 200)
  G:text("APPLE", 284, 950, 26, {0.6, 0.35, 0.15}, 1, "center", 200)
  local a = L.window(lt, 20, 45, 1.5)
  G:plate("PECAN: THE OFFICIAL STATE PIE OF TEXAS", 220, 26, 0xffd23f, a)
end

function D.finale(lt, len)
  G:gradient(0, 0, W, H, {0.35, 0.15, 0.08}, {0.8, 0.42, 0.15})
  C.fx.glow(384, 460, 340, 260, 1, 0.65, 0.25, 0.35)
  turkey(384, 640, 2.2, 1, S.t, false, 1)
  G:caption("HAPPY", 300, 56, 0xffffff, L.window(lt, 0.5, len, 1))
  G:caption("THANKSGIVING", 370, 72, 0xffb347, L.window(lt, 1, len, 1))
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
  for _, s in ipairs(SCENES) do if s[4] then G:label(s[4], 56, 0xffffff) end end
  for _, l in ipairs({{"PARTYCADE", 54, 0xff4fd8}, {"PRESENTS", 26, 0x6ef0c8}, {"THANKSGIVING", 72, 0xffb347},
                      {"HAPPY", 56, 0xffffff}, {"PARDONED!", 56, 0xffd23f}, {"GRATEFUL FOR YOU", 40, 0xffd23f},
                      {"WHAT ARE YOU THANKFUL FOR?", 32, 0xffffff}, {"TOUCHDOWN!", 40, 0xff8c1a},
                      {"PECAN: THE OFFICIAL STATE PIE OF TEXAS", 26, 0xffd23f}}) do G:label(l[1], l[2], l[3]) end
end

function M.act() return S and scene_at(S.t)[2] or "open" end
function M.music() return S and scene_at(S.t)[3] or "tg_harvest" end

function M.update(dt)
  if not S then return false end
  G:step(dt)
  S.t = G.t
  local sc, lt = scene_at(S.t)
  -- leaves drifting down (not indoors)
  if sc[2] ~= "table" and sc[2] ~= "football" and sc[2] ~= "pie" and G.R:random() < dt * 10 and #G.debris < 200 then
    local c = LEAF[G.R:random(1, #LEAF)]
    G.debris[#G.debris + 1] = {x = G.R:random() * W, y = -10, vx = 20 + G.R:random() * 30, vy = 40 + G.R:random() * 40,
                               life = 30, max = 30, c = c, size = 10 + G.R:random() * 6, g = 0, rot = G.R:random() * 6,
                               spin = (G.R:random() - 0.5) * 3, confetti = true}
  end
  if sc[2] == "chase" and floor((lt - dt) * 0.5) ~= floor(lt * 0.5) and lt < 60 then C.sfx("power", 0.4) end
  if sc[2] == "football" and floor((lt - dt) / 6) ~= floor(lt / 6) and floor(lt / 6) % 3 == 1 then C.sfx("cheer") end
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
    lg.setColor(0.02, 0.02, 0.06, 0.55 * b)
    lg.rectangle("fill", 0, H - 50, W, 50)
    G:text(sc[5], 0, H - 38, 20, {1, 0.85, 0.6}, b)
  end
  local f = 1 - min(lt / 1.2, (len - lt) / 1.2, 1)
  if f > 0 then
    lg.setColor(0, 0, 0, f)
    lg.rectangle("fill", 0, 0, W, H)
  end
end

return M
