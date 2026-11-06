-- Thanksgiving: Home's show for the week of it (shows.lua's calendar), eight minutes. Every scene a story with
-- its own camera (SHOWS_BLUEPRINT.md):
--   0:00  STARLIGHT PRESENTS ... THANKSGIVING, leaves falling                    (Harvest Moon)
--   0:08  The parade: the balloons down the avenue, the camera riding along with each. Pac-Man's balloon eats
--         a kid's balloon, a gust lifts the ghost's handlers off their feet, the turkey breaks loose and Pac-Man
--         jumps for its rope; the crowd at the curb cheering                        (Parade Day)
--   1:50  The Great Turkey Chase: round the farmyard. The turkey hides under a pumpkin (that walks off), in the
--         barn (feathers out of the windows), behind the bale (Pac-Man sits on it); then it stands its ground,
--         and the ghosts bring its pardon                                           (Turkey Trot)
--   3:20  Autumn: raking the leaves into a pile (a gust takes it), Pac-Man's run and jump into it, everyone in;
--         dusk on the porch, the geese going over                                   (Grateful)
--   4:20  The table: the dishes brought in one by one, the turkey, carving a slice to every plate, what
--         everyone is thankful for, eating down to the bones, the last roll       (Grateful)
--   5:50  Football on TV: Texas and A&M; a drive, a touchdown nobody can get up for, an interception everyone
--         can, the final, Pac-Man waking up to ask                                  (Football Sunday)
--   6:50  Pie: three pies served a slice at a time to the line; Pac-Man eats the rest of the pecan pie whole
--                                                                                   (Pie Polka)
--   7:40  HAPPY THANKSGIVING, the cast arriving to say it
local lg = love.graphics
local L = require("showlib")
local M = {}
local C, G
local W, H = 768, 1024
local LEN = 480
M.LEN = LEN
local sin, cos, floor, min, max, abs, pi = math.sin, math.cos, math.floor, math.min, math.max, math.abs, math.pi
local clamp, ease, lerp, mix = L.clamp, L.ease, L.lerp, L.mix

-- {start, name, song, title, subtitle}
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
local function prog(lt, a, b) return ease((lt - a) / (b - a)) end
local function lin(lt, a, b) return clamp((lt - a) / (b - a), 0, 1) end
local LEAF = {{0.85, 0.3, 0.1}, {0.95, 0.55, 0.1}, {0.8, 0.15, 0.1}, {0.95, 0.75, 0.2}, {0.6, 0.3, 0.1}}
local GH = {{1, 0.18, 0.2}, {1, 0.55, 0.85}, {0.25, 0.95, 1}, {1, 0.65, 0.2}, {0.72, 0.42, 1}}

-- ------------------------------------------------------------------ the cast
-- A turkey (facing dir), running or standing; fan spread (0..1, past 1: puffed up); pumpkin: one on its head
local function turkey(x, y, s, dir, t, run, fan, pumpkin, medal)
  lg.push()
  lg.translate(x, y)
  lg.scale(s * dir, s)
  fan = fan or 1
  local big = max(1, fan)
  for i = -3, 3 do
    local a = -pi / 2 + i * 0.32 * min(fan, 1.4) - 0.4
    rgba(LEAF[(i + 4) % #LEAF + 1])
    lg.ellipse("fill", -18 + cos(a) * 40 * big, -24 + sin(a) * 40 * big, 12 * big, 26 * big, 12)
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
  if pumpkin then
    lg.setColor(0.95, 0.5, 0.1, 1)
    lg.ellipse("fill", 0, -8, 52, 40, 20)
    lg.setColor(0.8, 0.38, 0.08, 1)
    lg.ellipse("fill", -18, -8, 12, 38, 12)
    lg.ellipse("fill", 18, -8, 12, 38, 12)
    lg.setColor(0.3, 0.5, 0.2, 1)
    lg.rectangle("fill", -3, -56, 6, 12)
    lg.pop()
    return
  end
  lg.setColor(0.5, 0.36, 0.3, 1)
  lg.polygon("fill", 22, -6, 30, -40, 40, -38, 32, -2)
  lg.circle("fill", 38, -44, 9, 12)
  lg.setColor(1, 0.8, 0.15, 1)
  lg.polygon("fill", 45, -46, 56, -42, 45, -40)
  lg.setColor(0.85, 0.1, 0.1, 1)
  lg.ellipse("fill", 46, -34, 4, 9, 10)
  lg.setColor(0, 0, 0, 1)
  lg.circle("fill", 40, -47, 2, 6)
  if medal then
    lg.setColor(0.2, 0.3, 0.8, 1)
    lg.polygon("fill", 22, -14, 34, -14, 30, 0, 26, 0)
    lg.setColor(1, 0.82, 0.25, 1)
    lg.circle("fill", 28, 6, 9, 14)
  end
  lg.pop()
end

-- Pac-Man on his feet (the farm, the parade): a chomper; feathers stuck on him after the barn
local function pac(x, y, r, dir, t, open, feathers)
  L.pac(x, y, r, dir > 0 and 0 or pi, t, open)
  if feathers then
    for i = 0, 5 do
      rgba(LEAF[i % #LEAF + 1])
      local a = i * 1.1
      lg.ellipse("fill", x + cos(a) * r * 0.7, y + sin(a) * r * 0.6, 5, 10, 8)
    end
  end
end

-- A pie, whole or with slices gone (0..8), seen at a slant
local PIE_FILL = {pecan = {0.42, 0.22, 0.1}, pumpkin = {0.88, 0.5, 0.15}, apple = {0.86, 0.66, 0.3}}
local function pie(x, y, r, kind, gone)
  local crust, fill = {0.82, 0.6, 0.32}, PIE_FILL[kind]
  lg.setColor(0.92, 0.92, 0.95, 1)
  lg.ellipse("fill", x, y + 10, r + 16, (r + 16) * 0.4, 32)
  if (gone or 0) >= 8 then
    lg.setColor(0.82, 0.6, 0.32, 0.5)
    for i = 0, 7 do lg.circle("fill", x + cos(i * 2.3) * r * 0.5, y + 6 + sin(i * 1.7) * r * 0.15, 3, 6) end
    return
  end
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
  if gone and gone > 0 then
    lg.push()
    lg.translate(x, y + 2)
    lg.scale(1, 0.37)
    lg.setColor(0.92, 0.92, 0.95, 1)
    lg.arc("fill", "pie", 0, 0, r + 1, -pi / 2, -pi / 2 + gone / 8 * 2 * pi, 24)
    lg.pop()
  end
end
-- one slice, flying (a wedge of the pie's colour)
local function slice(x, y, kind, s)
  s = s or 1
  lg.setColor(0.82, 0.6, 0.32, 1)
  lg.polygon("fill", x - 22 * s, y + 8 * s, x + 22 * s, y + 8 * s, x, y - 14 * s)
  rgba(PIE_FILL[kind])
  lg.polygon("fill", x - 16 * s, y + 4 * s, x + 16 * s, y + 4 * s, x, y - 9 * s)
end

-- the roast on its platter: meat 1 (whole) to 0 (the bones)
local function roast(x, y, s, meat)
  meat = meat or 1
  lg.setColor(0.92, 0.92, 0.95, 1)
  lg.ellipse("fill", x, y + 34 * s, 130 * s, 36 * s, 32)
  if meat <= 0.05 then
    lg.setColor(0.95, 0.92, 0.85, 1)
    lg.setLineWidth(6 * s)
    for i = -3, 3 do lg.arc("line", "open", x + i * 18 * s, y + 10 * s, 26 * s, pi + 0.4, 2 * pi - 0.4, 10) end
    lg.line(x - 70 * s, y + 10 * s, x + 70 * s, y + 10 * s)
    return
  end
  local m = 0.45 + 0.55 * meat
  lg.setColor(0.7, 0.4, 0.15, 1)
  lg.ellipse("fill", x, y + 10 * s * (1 - m), 96 * s * m, 60 * s * m, 32)
  lg.setColor(0.85, 0.55, 0.22, 1)
  lg.ellipse("fill", x - 16 * s, y - 14 * s * m, 60 * s * m, 30 * s * m, 24)
  for i = -1, 1, 2 do
    lg.setColor(0.7, 0.4, 0.15, 1)
    lg.ellipse("fill", x + i * 84 * s * m, y + 6 * s, 30 * s * m, 20 * s * m, 16)
    lg.setColor(1, 1, 1, 1)
    lg.circle("fill", x + i * 112 * s * m, y + 2 * s, 9 * s, 10)
  end
  lg.setColor(0.35, 0.6, 0.2, 1)
  for i = 0, 5 do lg.circle("fill", x - 110 * s + i * 44 * s, y + 46 * s, 9 * s, 10) end
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
  if not art("open") then G:gradient(0, 0, W, H, {0.3, 0.12, 0.08}, {0.75, 0.38, 0.12}) end
  C.fx.glow(384, 460, 300, 260, 1, 0.6, 0.2, 0.3)
  local a = L.window(lt, 0.4, 4, 0.7)
  G:brand(400, a)
  G:caption("PRESENTS", 472, 26, 0x6ef0c8, a)
  G:caption("THANKSGIVING", 430, 72, 0xffb347, L.window(lt, 4.2, 8, 0.7))
end

-- ------------------------------------------------------------------ the parade
local BALLOON_T = {2, 26, 50}               -- when each balloon starts across (30 s each, in the middle at +15)
local LOOSE = 64                            -- the turkey breaks loose
local function balloon_x(i, lt)
  if i == 3 and lt > LOOSE then
    return lerp(-300, W + 300, (LOOSE - BALLOON_T[3]) / 30) + max(0, lt - 77) * 45
  end
  return lerp(-300, W + 300, (lt - BALLOON_T[i]) / 30)
end
local function balloon_y(i, lt)
  local y = 330 + sin(S.t * 1.3 + i) * 10
  if i == 3 then y = y - 120 * prog(lt, LOOSE, LOOSE + 4) * (1 - prog(lt, 72, 76)) end
  return y
end
local function pac_rescue(lt)
  return L.path(lt, {{66, -60, 900}, {69.5, 360, 900, "lin"}, {71, 420, 720}, {72, 430, 780}, {76, 430, 880}, {84, 900, 880, "lin"}})
end
local function band_x(lt) return lerp(-460, W + 60, lin(lt, 82, 100)) end
local CROWD = 26
function D.parade(lt, len)
  if not art("parade") then
    G:gradient(0, 0, W, 560, {0.45, 0.62, 0.9}, {0.86, 0.9, 0.98})
    G:gradient(0, 620, W, H, {0.5, 0.5, 0.52}, {0.4, 0.4, 0.42})
  end
  -- the kid's balloon, let go: up to Pac-Man's mouth (and gone)
  if lt > 11 and lt < 17.2 then
    local f = lin(lt, 11, 17.2)
    local bx, by = lerp(240, balloon_x(1, 17.2) + 90, f), lerp(900, balloon_y(1, 17.2), f)
    lg.setColor(0.6, 0.6, 0.6, 1)
    lg.setLineWidth(1)
    lg.line(bx, by + 22, bx + sin(lt * 4) * 6, by + 70)
    lg.setColor(0.95, 0.15, 0.2, 1)
    lg.ellipse("fill", bx, by, 18, 22, 16)
  end
  -- the balloons, their handlers and ropes
  for i, kind in ipairs({"pac", "ghost", "turkey"}) do
    local x = balloon_x(i, lt)
    if x > -320 and x < W + 320 then
      local by = balloon_y(i, lt)
      local lifted = (i == 2 and lt > 39 and lt < 45) and 70 * sin(lin(lt, 39, 45) * pi) or 0
      local loose_now = i == 3 and lt > LOOSE and lt < 76
      for h = -2, 2 do
        local hx = x + h * 40
        local hy = 860 - lifted * (1 - abs(h) * 0.2)
        local loose = loose_now and h == 2
        if not loose then
          lg.setColor(0.85, 0.85, 0.88, 0.8)
          lg.setLineWidth(2)
          lg.line(hx, hy, x + h * 30, by + 120)
          lg.setColor(0.2, 0.35, 0.7, 1)
          lg.rectangle("fill", hx - 8, hy, 16, 30, 4, 4, 4)
          lg.setColor(0.9, 0.72, 0.58, 1)
          lg.circle("fill", hx, hy - 8, 7, 10)
          if lifted > 0 then
            lg.setColor(0.2, 0.35, 0.7, 1)
            lg.setLineWidth(3)
            local kick = sin(S.t * 14 + h) * 6
            lg.line(hx - 4, hy + 30, hx - 6 + kick, hy + 44)
            lg.line(hx + 4, hy + 30, hx + 6 - kick, hy + 44)
          end
        end
      end
      if loose_now then
        -- the loose rope, trailing; Pac-Man on the end of it once he has it
        local rx, ry = x + 60, by + 120
        local ex, ey = x + 40 + sin(lt * 2) * 20, by + 330
        if lt > 71 then
          local px, py = pac_rescue(lt)
          ex, ey = px, py - 30
        end
        lg.setColor(0.85, 0.85, 0.88, 0.9)
        lg.setLineWidth(2)
        lg.line(rx, ry, (rx + ex) / 2 + sin(lt * 3) * 14, (ry + ey) / 2, ex, ey)
      end
      if kind == "pac" then
        local open = (lt > 15.8 and lt < 18) and (0.2 + 0.8 * abs(sin((lt - 15.8) * 5))) or nil
        L.pac(x, by, 130, 0, S.t * 0.2, open)
        lg.setColor(1, 1, 1, 0.25)
        lg.ellipse("fill", x - 40, by - 70, 40, 18, 16)
      elseif kind == "ghost" then
        local blown = lt > 39 and lt < 46
        L.ghost(x, by, 120, GH[1], S.t, blown and 0 or 1, blown and 1 or 0, blown and "wide" or nil)
      else
        turkey(x, by + 40, 3.2, 1, S.t, false, 0.9 + 0.1 * sin(S.t))
      end
    end
  end
  -- the float under the turkey: a horn of plenty
  local fx = lerp(-300, W + 300, (lt - BALLOON_T[3]) / 30) - 180
  if lt > 46 and fx < W + 200 then
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
  -- Pac-Man to the rescue: in at a run, the jump, the rope, hauling the turkey back down
  if lt > 66 and lt < 84 then
    local px, py = pac_rescue(lt)
    py = py - (lt > 76 and L.hop(lt, 0.4, 20) or 0)
    pac(px, py, 34, 1, S.t, (lt > 70.5 and lt < 76) and 0.3 or nil)
  end
  -- the marching band to close the parade: hats, tubas, a big drum
  if lt > 82 then
    local x0 = band_x(lt)
    for i = 0, 7 do
      local x = x0 + i * 62
      local step = abs(sin(S.t * 6 + i)) * 6
      lg.setColor(0.75, 0.33, 0.05, 1)
      lg.rectangle("fill", x - 14, 818 - step, 28, 44, 6, 6, 4)
      lg.setColor(1, 1, 1, 1)
      lg.rectangle("fill", x - 12, 790 - step, 24, 16, 3, 3, 4)
      lg.setColor(0.9, 0.72, 0.58, 1)
      lg.circle("fill", x, 810 - step, 9, 10)
      if i % 3 == 1 then
        lg.setColor(1, 0.85, 0.3, 1)
        lg.circle("fill", x + 16, 812 - step, 16, 16)
        lg.setColor(0.6, 0.45, 0.1, 1)
        lg.circle("fill", x + 16, 812 - step, 9, 12)
      elseif i % 3 == 2 then
        lg.setColor(0.95, 0.95, 0.95, 1)
        lg.circle("fill", x, 846 - step, 16, 16)
        lg.setColor(0.8, 0.2, 0.15, 1)
        lg.setLineWidth(3)
        lg.circle("line", x, 846 - step, 16, 16)
      end
      lg.setColor(0.2, 0.2, 0.25, 1)
      lg.setLineWidth(4)
      lg.line(x - 6, 862 - step, x - 6 - step, 878)
      lg.line(x + 6, 862 - step, x + 6 + step, 878)
    end
  end
  -- the crowd at the curb, from behind: bobbing, arms up for the big moments
  local cheer = (lt > 17 and lt < 21) or (lt > 44 and lt < 47) or (lt > 76 and lt < 102)
  for i = 0, CROWD - 1 do
    local x = i * (W / (CROWD - 1))
    local hop = cheer and L.hop(S.t + i * 0.13, 0.35, 16) or abs(sin(S.t * 2 + i)) * 3
    local c = ({{0.8, 0.2, 0.2}, {0.2, 0.4, 0.8}, {0.9, 0.7, 0.2}, {0.3, 0.6, 0.3}, {0.6, 0.3, 0.6}})[i % 5 + 1]
    rgba(c)
    lg.rectangle("fill", x - 16, 950 - hop, 32, 80, 12, 12, 6)
    lg.setColor(({0.25, 0.4, 0.15, 0.55})[i % 4 + 1], 0.18, 0.1, 1)
    lg.circle("fill", x, 936 - hop, 14, 12)
    if cheer then
      rgba(c)
      lg.setLineWidth(6)
      lg.line(x - 12, 960 - hop, x - 22, 914 - hop)
      lg.line(x + 12, 960 - hop, x + 22, 914 - hop)
    end
  end
  if lt > 16.5 and lt < 19.5 then G:say("WAKA!", balloon_x(1, lt), balloon_y(1, lt) - 150, 30, 1) end
  if lt > 40 and lt < 44 then G:say("WHOA!", balloon_x(2, lt) - 80, 760, 26, 1) end
  if lt > LOOSE + 0.5 and lt < LOOSE + 4 then G:say("IT'S LOOSE!", balloon_x(3, lt) - 60, 780, 26, 1) end
  if lt > 72 and lt < 76 then
    local px, py = pac_rescue(lt)
    G:say("GOT IT!", px, py - 70, 26, 1)
  end
end
CAM.parade = function(lt)
  local function on(i) return balloon_x(i, lt), 560, 1.25 end
  local x, y, z
  if lt < 4 then x, y, z = 384, 512, 1
  elseif lt < 26 then
    local bx = balloon_x(1, lt)
    local k = prog(lt, 4, 7)
    x, y, z = lerp(384, bx, k), lerp(512, 560, k), lerp(1, 1.25, k)
  elseif lt < 30 then
    x, y, z = lerp(balloon_x(1, lt), balloon_x(2, lt), prog(lt, 26, 30)), 560, 1.25
  elseif lt < 50 then
    x, y, z = on(2)
    if lt > 38 and lt < 47 then y = lerp(560, 640, prog(lt, 38, 40) * (1 - prog(lt, 45, 47))) end
  elseif lt < 54 then
    x, y, z = lerp(balloon_x(2, lt), balloon_x(3, lt), prog(lt, 50, 54)), 560, 1.25
  elseif lt < 64 then x, y, z = on(3)
  elseif lt < 80 then
    local k = prog(lt, 64, 67)
    x, y, z = lerp(balloon_x(3, 64), 420, k), lerp(560, 600, k), lerp(1.25, 1.1, k)
  elseif lt < 96 then
    local k = prog(lt, 80, 84)
    x, y, z = lerp(420, band_x(lt) + 220, k), lerp(600, 700, k), lerp(1.1, 1.3, k)
  else
    local k = prog(lt, 96, 100)
    x, y, z = lerp(band_x(96) + 220, 384, k), lerp(700, 512, k), lerp(1.3, 1, k)
  end
  return L.shot(0, {{0, x, y, z}}, W, H)
end
CUES.parade = {{3, "cheer"}, {17.2, "pop"}, {17.4, "power", 0.5}, {18, "cheer"}, {39, "whoosh"}, {44.5, "cheer"},
               {LOOSE, "pop"}, {LOOSE + 0.2, "whoosh"}, {70.6, "boing"}, {76, "cheer"}, {90, "cheer"},
               {76.2, function() G:confetti(60, {{1, 0.5, 0.1}, {0.95, 0.8, 0.2}, {0.8, 0.2, 0.15}, {1, 1, 1}}) end}}

-- ------------------------------------------------------------------ the turkey chase
local FEET = 830
local TURKEY = {{0, 384, FEET}, {8.2, 384, FEET}, {12, 600, 880}, {15, 610, 940}, {24, 610, 940}, {28, 380, 950, "lin"},
                {29, 380, 950}, {34, 600, 640, "lin"}, {35.5, 600, 600}, {46, 600, 600}, {47, 580, 660}, {54, 140, 820, "lin"},
                {56, 120, 800}, {66, 120, 800}, {68, 250, 830}, {90, 250, 830}}
local PAC = {{0, -80, FEET}, {7, 220, FEET, "lin"}, {8.6, 230, FEET}, {12.5, 450, 880, "lin"}, {16, 520, 930, "lin"}, {28, 520, 930},
             {29.2, 480, 950}, {35, 560, 640, "lin"}, {36.5, 600, 600}, {46.5, 600, 600}, {48, 600, 690}, {55, 260, 830, "lin"},
             {57, 300, 830}, {60, 520, 830, "lin"}, {62, 200, 800}, {64, 210, 760}, {65.5, 300, 830}, {68, 430, 830}, {90, 430, 830}}
local BALE_Q
local function in_barn(lt) return lt > 35.5 and lt < 46.5 end
function D.chase(lt, len)
  local painted = art("farm")
  if not painted then
    G:gradient(0, 0, W, 600, {0.5, 0.7, 0.95}, {0.95, 0.85, 0.7})
    lg.setColor(0.65, 0.15, 0.12, 1)
    lg.rectangle("fill", 480, 380, 240, 220)
    G:gradient(0, 600, W, H, {0.75, 0.62, 0.3}, {0.55, 0.45, 0.2})
  end
  -- the barn shaking while they are in it, feathers out of its door and windows
  if in_barn(lt) and painted then
    S.barn_q = S.barn_q or lg.newQuad(400, 280, 330, 330, W, H)
    local j = 4 * sin(S.t * 40)
    lg.setColor(1, 1, 1, 1)
    lg.draw(S.art.farm, S.barn_q, 400 + j, 280 + abs(j) * 0.5)
  end
  local tx, ty, tdir = L.path(lt, TURKEY)
  local px, py, pdir = L.path(lt, PAC)
  S.tdir = tdir ~= 0 and tdir or (S.tdir or 1)
  S.pdir = pdir ~= 0 and pdir or (S.pdir or 1)
  -- standoff: the turkey turns to face him and puffs up
  if lt > 66 then S.tdir, S.pdir = 1, -1 end
  local fan = lt > 66 and lerp(0.8, 1.7, prog(lt, 67, 69)) * (1 - 0.35 * prog(lt, 76, 78)) or 0.8
  local hiding_bale = lt > 56 and lt < 66.5
  local running = (lt > 8 and lt < 15) or (lt > 24 and lt < 35) or (lt > 46 and lt < 56)
  local pumpkin = lt > 15 and lt < 29
  if not in_barn(lt) then
    turkey(tx, ty - (hiding_bale and 10 or 0), 1.5, S.tdir, S.t, running, fan, pumpkin, lt > 78)
  end
  -- the bale in front of the hiding turkey
  if hiding_bale then
    if painted then
      BALE_Q = BALE_Q or lg.newQuad(56, 786, 128, 68, W, H)
      lg.setColor(1, 1, 1, 1)
      lg.draw(S.art.farm, BALE_Q, 56, 786)
    else
      lg.setColor(0.92, 0.78, 0.35, 1)
      lg.rectangle("fill", 60, 790, 120, 60, 8, 8, 6)
    end
  end
  if not in_barn(lt) or lt > 46.4 then
    local scared = lt > 63.8 and lt < 65.5
    local hop = scared and L.hop(lt, 0.6, 60) or ((lt > 76 and lt < 90) and L.hop(lt, 0.45, 18) or 0)
    -- the sniffing look-around in the pumpkin patch, the look-around at the bale
    local look = ((lt > 17 and lt < 27) or (lt > 57 and lt < 60)) and (sin(lt * 2) > 0 and 1 or -1) or S.pdir
    pac(px, py - 40 - hop, 34, look, S.t, (scared or lt > 76) and 0.8 or nil, lt > 46 and lt < 70)
  end
  -- the ghosts with the pardon: in from the right, the scroll held up between them
  if lt > 70 then
    local gx = lerp(W + 120, 560, prog(lt, 70, 75))
    for k = 0, 1 do
      L.ghost(gx + k * 110, 770 - L.hop(lt + k, 0.5, 8), 34, GH[k + 1], S.t + k, -1, 0, lt > 78 and "happy" or nil)
    end
    lg.setColor(0.98, 0.94, 0.8, 1)
    lg.rectangle("fill", gx + 4, 690, 102, 56, 4, 4, 4)
    lg.setColor(0.85, 0.75, 0.55, 1)
    lg.circle("fill", gx, 718, 10, 10)
    lg.circle("fill", gx + 110, 718, 10, 10)
    G:text("PARDON", gx + 4, 708, 20, {0.4, 0.15, 0.1}, 1, "center", 102)
  end
  if lt > 8.2 and lt < 11 then G:say("GOBBLE?!", tx, ty - 110, 26, 1) end
  if lt > 27.5 and lt < 30 then G:say("?!", px, py - 100, 30, 1) end
  if in_barn(lt) and lt > 38 then
    local n = floor((lt - 38) / 2.4) % 3
    G:say(({"CRASH!", "BONK!", "GOBBLE!"})[n + 1], 600, 470, 28, 1)
  end
  if lt > 62.5 and lt < 64.6 then G:say("GOBBLE!", 120, 720, 26, 1) end
  if lt > 69 and lt < 72 then G:say("...!", px, py - 100, 28, 1) end
  G:plate("PARDONED!", 150, 56, 0xffd23f, clamp((lt - 78) * 2, 0, 1) * L.window(lt, 78, 90, 0.4))
end
local function chase_cam(lt)
  local tx, ty = L.path(lt, TURKEY)
  local px, py = L.path(lt, PAC)
  if lt < 4 then return 384, 512, 1 end
  if lt > 34 and lt < 47 then return 600, 540, 1.7 end
  if lt > 56 and lt < 67 then return 200, 780, 1.6 end
  if lt > 67 then return lerp(300, 440, prog(lt, 69, 76)), 740, lerp(1.5, 1.15, prog(lt, 69, 76)) end
  return (tx + px) / 2, (ty + py) / 2 - 40, 1.45
end
CAM.chase = function(lt)
  local x, y, z = chase_cam(lt)
  -- (the moves between the set pieces eased over a second)
  for _, edge in ipairs({4, 34, 47, 56, 67}) do
    if lt > edge and lt < edge + 1 then
      local ox, oy, oz = chase_cam(edge - 0.01)
      local k = prog(lt, edge, edge + 1)
      x, y, z = lerp(ox, x, k), lerp(oy, y, k), lerp(oz, z, k)
    end
  end
  return L.shot(0, {{0, x, y, z}}, W, H)
end
CUES.chase = {{8.2, "boing"}, {15, "pop"}, {28, "boing"}, {35.6, "clunk"}, {38, "boom", 0.5}, {40.4, "boing"}, {42.8, "boom", 0.4},
              {46.4, "clunk"}, {62.5, "boing"}, {67, "whoosh"}, {75, "ding"}, {78, "power"}, {78.2, "cheer"}}
for t = 380, 460, 6 do
  CUES.chase[#CUES.chase + 1] = {t / 10, function()
    for i = 1, 6 do
      local c = LEAF[G.R:random(1, #LEAF)]
      local fx, fy = ({{520, 420}, {680, 420}, {600, 560}})[G.R:random(1, 3)][1], 420
      G:spark(fx + (G.R:random() - 0.5) * 40, fy + G.R:random() * 140, (G.R:random() - 0.5) * 200, -100 - G.R:random() * 150, 1.6, c, 8, 180)
    end
  end}
end

-- ------------------------------------------------------------------ autumn: the leaf pile
local PILE = {270, 910}
local function pile_size(lt)
  local s = prog(lt, 8, 20) * 0.75 - 0.35 * prog(lt, 20.5, 21.5) + 0.6 * prog(lt, 23, 31)
  if lt > 35.5 then s = s * (1 - 0.6 * prog(lt, 35.5, 36.2)) end
  return clamp(s, 0, 1)
end
local function rakers(lt, k)
  -- Blinky and Inky with their rakes, raking toward the pile
  local x0 = ({130, 410})[k]
  local x = lt < 8 and lerp(k == 1 and -60 or W + 60, x0, prog(lt, 2, 8)) or x0 + sin(lt * 2.4 + k) * 24
  return x, 860
end
function D.autumn(lt, len)
  local k = lin(lt, 40, 56)
  if S.art.autumn_day and S.art.autumn_dusk then
    art("autumn_day")
    art("autumn_dusk", ease(k))
  else
    G:gradient(0, 0, W, 700, mix({0.4, 0.5, 0.85}, {0.3, 0.2, 0.45}, k), mix({1, 0.75, 0.45}, {1, 0.5, 0.3}, k))
    G:gradient(0, 640, W, H, {0.55, 0.45, 0.2}, {0.4, 0.3, 0.15})
  end
  -- the geese going over at dusk, in their V
  if lt > 47 and lt < 59 then
    local f = lin(lt, 47, 59)
    lg.setColor(0.15, 0.12, 0.15, 1)
    lg.setLineWidth(2.5)
    for i = -3, 3 do
      local gx, gy = lerp(W + 100, -200, f) + abs(i) * 30, 180 + i * 18
      local w = sin(S.t * 6 + i) * 6
      lg.line(gx - 10, gy - 4 - w, gx, gy, gx + 10, gy - 4 - w)
    end
  end
  -- the pile: leaves heaped, growing as they rake
  local ps = pile_size(lt)
  if ps > 0.02 then
    local n = floor(ps * 90)
    for i = 1, n do
      local a = i * 2.39996
      local r = math.sqrt(i / 90) * 110 * ps
      rgba(LEAF[i % #LEAF + 1])
      lg.ellipse("fill", PILE[1] + cos(a) * r * 1.2, PILE[2] - abs(sin(a)) * r * 0.6 - (1 - i / 90) * 90 * ps, 16, 9, 8)
    end
  end
  -- the rakers (raking until Pac-Man lands; then in the pile)
  for k2 = 1, 2 do
    local rx, ry = rakers(lt, k2)
    if lt < 38 then
      local mood = (lt > 20.5 and lt < 23) and "wide" or nil
      local gi = k2 == 1 and 1 or 3
      L.ghost(rx, ry, 34, GH[gi], S.t + k2, k2 == 1 and 1 or -1, 0.3, mood)
      local sw = sin(lt * 2.4 + k2) * 0.4
      lg.setColor(0.55, 0.38, 0.2, 1)
      lg.setLineWidth(5)
      local hx, hy = rx + (k2 == 1 and 30 or -30), ry - 10
      local ex, ey = hx + (k2 == 1 and 1 or -1) * 70 * cos(sw), ry + 40 + sin(sw) * 10
      lg.line(hx, hy, ex, ey)
      lg.setColor(0.4, 0.4, 0.42, 1)
      lg.rectangle("fill", ex - 14, ey, 28, 6)
    end
  end
  -- Pac-Man's run and jump, then heads popping up out of the pile
  if lt > 30 and lt < 36 then
    local px, py = L.path(lt, {{30, W + 80, 860}, {33.2, 560, 860, "lin"}, {35.5, PILE[1], 860}})
    if lt > 33.2 then py = py - sin(lin(lt, 33.2, 35.5) * pi) * 220 end
    pac(px, py, 36, -1, S.t, lt > 33 and 0.9 or nil)
  end
  if lt > 36.5 and lt < 44 then
    for i, who in ipairs({0, 1, 3}) do
      local up = prog(lt, 36.5 + i * 0.8, 37.3 + i * 0.8) * 30
      local x = PILE[1] + (i - 2) * 70
      if who == 0 then pac(x, PILE[2] - 30 - up + 30, 30, 1, S.t, 0.8)
      else L.ghost(x, PILE[2] - up, 28, GH[who], S.t + i, 0, -0.5, "happy") end
    end
  end
  -- the porch at dusk: everyone up there, the rocking chair going
  if lt > 44 then
    local a = prog(lt, 44, 46)
    lg.push()
    local rock = sin(S.t * 1.2) * 0.08
    lg.translate(640, 900)
    lg.rotate(rock)
    lg.setColor(0.4, 0.25, 0.15, 1)
    lg.rectangle("fill", -30, -100, 8, 100)
    lg.rectangle("fill", -30, -40, 60, 8)
    lg.rectangle("fill", 22, -40, 8, 40)
    lg.setLineWidth(6)
    lg.arc("line", "open", 0, -10, 40, 0.2, pi - 0.2, 16)
    L.pac(0, -64, 32, pi, S.t * 0.2, 0.2, a)
    lg.pop()
    for i, gi in ipairs({1, 3, 2}) do
      local gx = ({450, 525, 735})[i]
      L.ghost(gx, 860 - L.hop(lt + i, 3, 4), 30, GH[gi], S.t + i, 1, 0, "happy", a)
      -- a mug of cider, steaming
      lg.setColor(0.9, 0.85, 0.75, a)
      lg.rectangle("fill", gx + 20, 856, 12, 14, 2, 2, 4)
    end
  end
  if lt > 21 and lt < 24 then G:say("NOOO!", 330, 780, 26, 1) end
  if lt > 32.5 and lt < 35 then G:say("CANNONBALL!", 600, 760, 26, 1) end
  G:plate("GRATEFUL FOR YOU", 200, 40, 0xffd23f, L.window(lt, 47, 58, 1.5))
end
CAM.autumn = function(lt)
  return L.shot(lt, {{0, 384, 512, 1}, {8, 300, 840, 1.45}, {20, 290, 850, 1.55}, {28, 380, 840, 1.3}, {33, 450, 780, 1.3},
                     {36, 330, 840, 1.6}, {42, 330, 840, 1.6}, {46, 560, 820, 1.5}, {54, 540, 760, 1.35}, {58, 384, 512, 1}}, W, H)
end
CUES.autumn = {{20.5, "whoosh"}, {33.2, "boing"}, {35.5, "splash"}, {37.3, "pop"}, {38.1, "pop"}, {38.9, "pop"}, {47, "chime"},
               {20.6, function()
                 for i = 1, 40 do
                   G:spark(PILE[1] + (G.R:random() - 0.5) * 120, PILE[2] - 30, 120 + G.R:random() * 260, -120 - G.R:random() * 200, 2.2,
                           LEAF[G.R:random(1, #LEAF)], 9, 120)
                 end
               end},
               {35.5, function()
                 for i = 1, 90 do
                   G:spark(PILE[1] + (G.R:random() - 0.5) * 140, PILE[2] - 30, (G.R:random() - 0.5) * 420, -200 - G.R:random() * 380, 2.6,
                           LEAF[G.R:random(1, #LEAF)], 10, 260)
                 end
               end}}
for t = 90, 300, 15 do
  CUES.autumn[#CUES.autumn + 1] = {t / 10, function()
    for k = 1, 2 do
      local rx, ry = rakers(t / 10, k)
      G:spark(rx + (k == 1 and 90 or -90), ry + 40, (k == 1 and -1 or 1) * (40 + G.R:random() * 60), -60, 0.8, LEAF[G.R:random(1, #LEAF)], 8, 200)
    end
  end}
end

-- ------------------------------------------------------------------ the table
local SEATS = {{150, 1}, {270, 2}, {384, 0}, {498, 3}, {618, 4}}   -- x, who (0: Pac-Man)
local DISHES = {                                                     -- brought in by Sue, the cook, one by one
  {"cranberry", 180, 770, 6}, {"potatoes", 588, 770, 8.2}, {"beans", 230, 870, 10.4}, {"rolls", 540, 870, 12.6},
  {"gravy", 384, 900, 14.8},
}
local TURKEY_IN = 18
local THANKS = {{"MY FRIENDS!", 1}, {"POWER PELLETS!", 2}, {"ALL OF YOU!", 3}, {"THIS TURKEY!", 4}, {"PIE!!!", 5}}
local function dish(kind, x, y, full)
  lg.setColor(0.96, 0.96, 0.98, 1)
  lg.ellipse("fill", x, y + 6, 54, 22, 24)
  if full <= 0.02 then return end
  if kind == "cranberry" then
    lg.setColor(0.6, 0.05, 0.12, 1)
    lg.ellipse("fill", x, y, 36 * full, 14 * full, 20)
  elseif kind == "potatoes" then
    lg.setColor(0.98, 0.95, 0.85, 1)
    lg.ellipse("fill", x, y - 6 * full, 38 * full, 20 * full, 20)
    lg.setColor(0.95, 0.8, 0.3, 1)
    lg.ellipse("fill", x, y - 14 * full, 12 * full, 5 * full, 12)
  elseif kind == "beans" then
    lg.setColor(0.3, 0.6, 0.2, 1)
    for i = 0, floor(full * 9) do lg.ellipse("fill", x - 30 + (i % 5) * 15, y - 4 + floor(i / 5) * 8, 9, 3, 8) end
  elseif kind == "rolls" then
    lg.setColor(0.6, 0.4, 0.2, 1)
    lg.ellipse("fill", x, y, 48, 18, 20)
    lg.setColor(0.9, 0.7, 0.4, 1)
    for i = 0, floor(full * 4.99) - 1 do lg.circle("fill", x - 24 + i * 16, y - 6, 10, 12) end
  else
    lg.setColor(0.98, 0.95, 0.85, 1)
    lg.ellipse("fill", x, y - 4, 30, 14, 16)
    lg.setColor(0.5, 0.3, 0.12, 1)
    lg.ellipse("fill", x, y - 8, 22 * full, 8 * full, 16)
  end
end
-- how much food is on a guest's plate (0..1): slices from the carving, eaten down
local function plate_food(lt, i) return prog(lt, 28 + i * 2, 29 + i * 2) * (1 - prog(lt, 52 + i, 68 + i)) end
function D.table(lt, len)
  local painted = art("table")
  if not painted then
    G:gradient(0, 0, W, H, {0.35, 0.2, 0.12}, {0.2, 0.1, 0.06})
    lg.setColor(0.95, 0.92, 0.85, 1)
    lg.rectangle("fill", 70, 620, 628, 290, 10, 10, 6)
  end
  -- night coming on in the window
  lg.setColor(0.05, 0.05, 0.15, 0.6 * prog(lt, 50, 85))
  lg.rectangle("fill", 280, 120, 208, 260)
  -- the candles' flames
  for _, x in ipairs({96, 672}) do
    local f = 1 + sin(S.t * 13 + x) * 0.15
    lg.setColor(1, 0.8, 0.3, 1)
    lg.ellipse("fill", x, 692, 5 * f, 11 * f, 10)
    C.fx.glow(x, 690, 40, 40, 1, 0.75, 0.4, 0.45)
  end
  -- the guests behind their plates
  local eating = lt > 52 and lt < 70
  for i, s in ipairs(SEATS) do
    local x, who = s[1], s[2]
    local bob = eating and abs(sin(S.t * 5 + i)) * 6 or 0
    local full_lean = lt > 72 and 10 or 0
    local looking = (lt > 4 and lt < 18) and 1 or 0
    local wide = lt > TURKEY_IN and lt < TURKEY_IN + 4
    if who == 0 then
      local stand = (lt > 25 and lt < 40) and 30 or 0
      L.pac(x, 582 - stand - bob + full_lean, 38, pi / 2 * 0, S.t * (eating and 1 or 0.2), eating and nil or (lt > 72 and 0.15 or 0.3))
    else
      local mood = wide and "wide" or (lt > 72 and "happy" or nil)
      L.ghost(x, 590 - bob + full_lean, 34, GH[who], S.t + i, (lt > 38 and lt < 52) and 0 or looking * (x < 384 and 1 or -1),
              (lt > 4 and lt < 26) and 0.7 or 0, mood)
    end
    -- the food on the plate
    local f = plate_food(lt, i)
    if f > 0.02 then
      lg.setColor(0.85, 0.55, 0.25, 1)
      lg.ellipse("fill", x - 8, 652, 18 * f, 8 * f, 12)
      lg.setColor(0.98, 0.95, 0.85, 1)
      lg.ellipse("fill", x + 12, 652, 12 * f, 6 * f, 12)
      lg.setColor(0.6, 0.05, 0.12, 1)
      lg.circle("fill", x + 2, 660, 5 * f, 8)
    end
  end
  -- the dishes on the table, emptying as they eat
  for i, d in ipairs(DISHES) do
    if lt > d[4] + 2 then dish(d[1], d[2], d[3], 1 - 0.85 * prog(lt, 50, 70)) end
  end
  -- the turkey: carried in, carved, eaten to the bones
  local meat = 1 - 0.3 * prog(lt, 27, 38) - 0.7 * prog(lt, 52, 70)
  if lt > TURKEY_IN + 4 then roast(384, 760, 0.9, meat) end
  -- Sue the cook: in from the kitchen (the right) with each dish, and with the turkey
  local trips = {}
  for i, d in ipairs(DISHES) do trips[#trips + 1] = {d[4], d[2], d[3] - 60, d[1]} end
  trips[#trips + 1] = {TURKEY_IN, 384, 700, "turkey"}
  for _, tr in ipairs(trips) do
    local t0 = tr[1]
    local dur = tr[4] == "turkey" and 4 or 2.2
    if lt > t0 and lt < t0 + dur + 1.4 then
      local half = dur * 0.6
      local cx, cy
      if lt < t0 + half then
        local f = prog(lt, t0, t0 + half)
        cx, cy = lerp(W + 60, tr[2], f), lerp(560, tr[3], f)
      else
        local f = prog(lt, t0 + half + 0.3, t0 + dur + 1.4)
        cx, cy = lerp(tr[2], W + 60, f), lerp(tr[3], 560, f)
      end
      L.ghost(cx, cy, 36, GH[5], S.t, -1, 0.5, "happy")
      -- the chef's hat
      lg.setColor(1, 1, 1, 1)
      lg.rectangle("fill", cx - 18, cy - 54, 36, 22, 4, 4, 4)
      lg.circle("fill", cx - 14, cy - 56, 12, 12)
      lg.circle("fill", cx + 6, cy - 60, 14, 12)
      lg.circle("fill", cx + 18, cy - 54, 10, 12)
      -- what she carries (until it is set down)
      if lt < t0 + half then
        if tr[4] == "turkey" then roast(cx, cy + 30, 0.6, 1)
        else dish(tr[4], cx, cy + 34, 1) end
      end
    end
  end
  -- the carving: the knife, a slice flying to each plate
  if lt > 26 and lt < 39 then
    local cut = abs(sin(S.t * 6)) * 18
    lg.setColor(0.8, 0.82, 0.86, 1)
    lg.polygon("fill", 430, 720 + cut, 470, 680 + cut, 476, 686 + cut, 436, 726 + cut)
    for i, s in ipairs(SEATS) do
      local t0 = 27 + i * 2
      if lt > t0 and lt < t0 + 1 then
        local f = lt - t0
        lg.setColor(0.85, 0.55, 0.25, 1)
        lg.ellipse("fill", lerp(384, s[1], f), lerp(740, 650, f) - sin(f * pi) * 120, 16, 8, 12)
      end
    end
  end
  -- the last roll: two of them want it; it splits
  if lt > 62 and lt < 69 then
    local split = lt > 66
    local x = lerp(540, 384, prog(lt, 62, 63)) + (split and 0 or sin(S.t * 10) * 30)
    lg.setColor(0.9, 0.7, 0.4, 1)
    if split then
      local f = prog(lt, 66, 67)
      lg.circle("fill", lerp(x, 270, f), lerp(800, 650, f), 9, 12)
      lg.circle("fill", lerp(x, 498, f), lerp(800, 650, f), 9, 12)
    else
      lg.circle("fill", x, 800, 12, 14)
    end
  end
  -- what everyone is thankful for, in turn
  for i, th in ipairs(THANKS) do
    local t0 = 38 + (i - 1) * 2.8
    if lt > t0 and lt < t0 + 2.6 then
      local x = SEATS[th[2]][1]
      G:say(th[1], x, 540, 24, L.window(lt, t0, t0 + 2.6, 0.2))
    end
  end
  if lt > TURKEY_IN + 2 and lt < TURKEY_IN + 5 then G:say("OOOOH!", 270, 540, 28, 1) end
  if lt > 63 and lt < 66 then G:say("MINE!", 270, 540, 24, 1) end
  if lt > 63.5 and lt < 66 then G:say("MINE!", 498, 540, 24, 1) end
  if lt > 80 and lt < 85 then G:say("PIE LATER?", W - 120, 520, 24, 1) end
  if lt > 79 and lt < 86 then
    L.ghost(lerp(W + 60, W - 80, prog(lt, 79, 80)) + (lt > 85 and (lt - 85) * 200 or 0), 600, 36, GH[5], S.t, -1, 0, "happy")
    pie(lerp(W + 60, W - 80, prog(lt, 79, 80)) + (lt > 85 and (lt - 85) * 200 or 0), 650, 40, "pumpkin", 0)
  end
  if lt > 85 and lt < 88 then G:say("OOF!", 384, 520, 28, 1) end
  G:plate("WHAT ARE YOU THANKFUL FOR?", 860, 32, 0xffffff, L.window(lt, 37, 52.5, 1))
end
CAM.table = function(lt)
  local keys = {{0, 384, 512, 1}, {5, 384, 640, 1.2}, {17, 460, 680, 1.25}, {20, 384, 680, 1.3}, {26, 384, 700, 1.5}, {37, 384, 680, 1.4}}
  for i, th in ipairs(THANKS) do
    local x = SEATS[th[2]][1]
    keys[#keys + 1] = {38.6 + (i - 1) * 2.8, x, 600, 1.7}
    keys[#keys + 1] = {40.4 + (i - 1) * 2.8, x, 600, 1.7}
  end
  for _, k in ipairs({{53, 384, 640, 1.1}, {61, 384, 660, 1.15}, {63, 384, 700, 1.6}, {68, 384, 700, 1.6}, {72, 384, 640, 1.3},
                      {79, 560, 620, 1.4}, {86, 384, 620, 1.2}}) do keys[#keys + 1] = k end
  return L.shot(lt, keys, W, H)
end
CUES.table = {{TURKEY_IN + 2, "cheer"}, {66, "pop"}, {66.2, "boing"}, {85, "boing"}}
for _, d in ipairs(DISHES) do CUES.table[#CUES.table + 1] = {d[4] + 1.3, "clunk", 0.5} end
for i = 1, 5 do CUES.table[#CUES.table + 1] = {28 + i * 2, "pop", 0.5} end
for i = 1, #THANKS do CUES.table[#CUES.table + 1] = {38 + (i - 1) * 2.8, "ding", 0.6} end

-- ------------------------------------------------------------------ football on TV
local TV = {150, 156, 468, 288}
local function tv_game(lt)
  local x0, y0, w, h = TV[1], TV[2], TV[3], TV[4]
  -- the field, scrolled to follow the ball
  local ball = L.path(lt, {{0, 30, 0}, {8, 30, 0}, {11, 42, 0}, {14, 55, 0}, {17, 68, 0}, {20, 82, 0}, {22, 100, 0}, {30, 100, 0},
                           {30.1, 75, 0}, {33, 68, 0}, {36, 60, 0}, {39, 55, 0}, {42, 52, 0}, {44, 52, 0}})
  local scroll = (ball - 50) * 9
  G:gradient(x0, y0, x0 + w, y0 + h, {0.2, 0.55, 0.2}, {0.15, 0.45, 0.15})
  -- (everything on the screen kept inside its edges)
  local function span(a, b)
    a, b = max(a, x0), min(b, x0 + w)
    return a, b - a
  end
  lg.setColor(1, 1, 1, 0.8)
  for yd = 0, 100, 10 do
    local x = x0 + w / 2 + (yd - 50) * 9 - scroll
    local a, sw = span(x, x + 3)
    if sw > 0 then lg.rectangle("fill", a, y0, sw, h) end
  end
  -- the end zone (Texas's way: the right)
  lg.setColor(0.75, 0.33, 0.05, 1)
  local ez = x0 + w / 2 + 50 * 9 - scroll
  local a, ew = span(ez, ez + 90)
  if ew > 0 then lg.rectangle("fill", a, y0, ew, h) end
  -- the players: orange and maroon, around the ball
  local bx = x0 + w / 2 + (ball - 50) * 9 - scroll
  local by = y0 + h * 0.55
  for i = 0, 9 do
    local side = i % 2
    local ox = (i - 5) * 16 + sin(S.t * 4 + i) * 6
    local oy = ((i * 37) % 120) - 60
    lg.setColor(side == 0 and 0.95 or 0.45, side == 0 and 0.45 or 0.05, side == 0 and 0.05 or 0.1, 1)
    if bx + ox > x0 + 8 and bx + ox < x0 + w - 8 then lg.circle("fill", bx + ox, by + oy, 7, 10) end
  end
  lg.setColor(0.5, 0.3, 0.1, 1)
  if bx > x0 + 8 and bx < x0 + w - 8 then lg.ellipse("fill", bx, by, 6, 4, 10) end
  local tex = lt < 22 and 17 or 24
  lg.setColor(0, 0, 0, 0.75)
  lg.rectangle("fill", x0, y0 + h - 34, w, 34)
  local clock = lt < 44 and string.format("4TH %d:%02d", floor((240 - lt * 5) / 60), floor(240 - lt * 5) % 60) or "FINAL"
  G:text(string.format("TEX %d   TA&M 17   %s", tex, clock), x0, y0 + h - 28, 20, {1, 1, 1}, 1, "center", w)
  if lt > 22 and lt < 28 then
    G:text("TOUCHDOWN", x0, y0 + 60, 48, {1, 0.6, 0.15}, 1, "center", w)
    G:text("TEXAS!", x0, y0 + 116, 48, {1, 1, 1}, 1, "center", w)
  end
  if lt > 42 and lt < 47 then G:text("INTERCEPTED!", x0, y0 + 90, 44, {1, 0.6, 0.15}, 1, "center", w) end
  if lt > 47 then G:text("FINAL", x0, y0 + 70, 56, {1, 1, 1}, 1, "center", w) G:text("TEXAS WINS", x0, y0 + 140, 40, {1, 0.6, 0.15}, 1, "center", w) end
end
function D.football(lt, len)
  if not art("football") then
    G:gradient(0, 0, W, H, {0.18, 0.14, 0.2}, {0.1, 0.08, 0.12})
    lg.setColor(0.45, 0.25, 0.18, 1)
    lg.rectangle("fill", 60, 760, 648, 180, 30, 30, 8)
  end
  tv_game(lt)
  -- the couch: the ghosts (too full, then not) and Pac-Man asleep in the middle
  local try = lt > 22 and lt < 26
  local leap = lt > 42 and lt < 47
  for i = 1, 4 do
    local x = 130 + (i - 1) * 110 + (i > 2 and 140 or 0)
    local lift = try and abs(sin((lt - 22) * 6)) * 10 or (leap and L.hop(lt + i * 0.2, 0.55, 90) or 0)
    local mood = try and "wide" or (leap and "happy" or ((lt > 30 and lt < 42 and i == 3) and "sleep" or nil))
    if lt > 54 then mood = "sleep" end
    L.ghost(x, 760 - lift, 38, GH[i], S.t + i, 0, -0.6, mood)
  end
  -- the popcorn bowl on Inky's lap
  lg.setColor(0.85, 0.2, 0.2, 1)
  lg.ellipse("fill", 460, 800, 34, 14, 16)
  lg.setColor(1, 0.95, 0.8, 1)
  for i = 0, 6 do lg.circle("fill", 440 + i * 7, 790 - (i % 2) * 5, 6, 8) end
  local awake = lt > 49 and lt < 56
  if awake then
    L.pac(384, 760 - L.hop(lt, 0.5, 20), 52, 0, S.t, 0.7)
  else
    lg.setColor(1, 0.86, 0.15, 1)
    lg.circle("fill", 384, 760, 52, 32)
    lg.setColor(0.1, 0.05, 0.1, 1)
    lg.setLineWidth(3)
    lg.line(370, 744, 386, 744)
    for i = 0, 2 do
      local k = ((S.t * 0.5 + i / 3) % 1)
      G:text("z", 420 + k * 50, 700 - k * 90, floor(22 + k * 20), {0.85, 0.85, 1}, 1 - k, "left", 40)
    end
  end
  if try then G:say("UGH... TOO FULL", 240, 700, 24, 1) end
  if lt > 49.5 and lt < 52.5 then G:say("DID WE WIN?", 384, 690, 26, 1) end
  if lt > 52.5 and lt < 55.5 then G:say("YES!!!", 240, 700, 30, 1) end
end
CAM.football = function(lt)
  return L.shot(lt, {{0, 384, 512, 1}, {6, 384, 512, 1}, {9, 384, 300, 1.55}, {21.5, 384, 300, 1.55}, {22.5, 384, 640, 1.2, "cut"},
                     {28, 384, 640, 1.2}, {30, 384, 300, 1.55}, {41.5, 384, 300, 1.55}, {42.5, 384, 560, 1.05, "cut"},
                     {48, 384, 560, 1.05}, {49, 384, 700, 1.4}, {56, 384, 700, 1.4}, {59, 384, 512, 1}}, W, H)
end
CUES.football = {{4, "pew", 0.4}, {22, "cheer"}, {22.3, "boing"}, {42, "cheer"}, {42.2, "boing"}, {47, "power"}, {52.5, "cheer"},
                 {42.3, function()
                   for i = 1, 50 do G:spark(460, 790, (G.R:random() - 0.5) * 400, -200 - G.R:random() * 300, 2, {1, 0.95, 0.8}, 7, 500) end
                 end},
                 {48, function() for i = 1, 3 do G:firework(200 + i * 120, 230, false) end end}}
for t = 11, 20, 3 do CUES.football[#CUES.football + 1] = {t, "tick", 0.5} end

-- ------------------------------------------------------------------ pie
local PIES = {{"pecan", 140, 540}, {"pumpkin", 384, 540}, {"apple", 628, 540}}
local LINE = {{120, 1}, {260, 2}, {384, 0}, {508, 3}, {648, 4}}     -- the line with their plates (0: Pac-Man)
-- slice n (from 0): which pie, to whom, when
local function slice_plan(n) return ((n % 3) + 1), ((n % 5) + 1), 4 + n * 2 end
local NSLICE = 17
local function gone(p, lt)
  local g = 0
  for n = 0, NSLICE - 1 do
    local pi_, _, t0 = slice_plan(n)
    if pi_ == p and lt > t0 then g = g + 1 end
  end
  return g
end
function D.pie(lt, len)
  if not art("pie") then
    G:gradient(0, 0, W, H, {0.98, 0.9, 0.78}, {0.92, 0.75, 0.55})
  end
  -- the counter the pies cool on
  lg.setColor(0.55, 0.34, 0.18, 1)
  lg.rectangle("fill", 10, 572, W - 20, 30, 6, 6, 4)
  lg.setColor(0.42, 0.25, 0.12, 1)
  lg.rectangle("fill", 10, 598, W - 20, 12)
  for _, x in ipairs({40, W - 56}) do lg.rectangle("fill", x, 610, 16, 120) end
  for i, p in ipairs(PIES) do
    local g = gone(i, lt)
    if i == 1 and lt > 42.5 then g = 8 end
    local bob = (i == 1 and lt > 41 and lt < 42.5) and sin(S.t * 30) * 3 or 0
    pie(p[2], p[3] + bob, 100, p[1], g)
    G:text(p[1]:upper(), p[2] - 100, p[3] + 60, 24, {0.45, 0.22, 0.1}, 1, "center", 200)
    -- steam off the pies
    if floor(S.t * 3 + i) % 4 == 0 then end
  end
  -- the line, plates up
  for i, l in ipairs(LINE) do
    local x, who = l[1], l[2]
    local y = 860
    local munch = false
    for n = 0, NSLICE - 1 do
      local _, to, t0 = slice_plan(n)
      if to == i and lt > t0 + 1 and lt < t0 + 2.6 then munch = true end
    end
    local hop = munch and abs(sin(S.t * 8)) * 6 or 0
    if who == 0 then
      local px, py = x, y
      local r = 44 + 18 * prog(lt, 42.5, 44)
      if lt > 40 and lt < 44 then px, py = L.path(lt, {{40, 384, 860}, {41.5, 140, 600}, {43, 140, 600}, {44, 384, 860}}) end
      L.pac(px, py - hop, r, (lt > 40 and lt < 42.6) and pi * 0.75 or -pi / 2 * 0, S.t, munch and nil or ((lt > 41 and lt < 43) and 0.95 or 0.25))
    else
      local mood = (lt > 42.5 and lt < 46) and "wide" or (munch and "happy" or nil)
      L.ghost(x, y - hop, 40, GH[who], S.t + i, 0, -0.8, mood)
    end
    -- the plate held up
    lg.setColor(0.96, 0.96, 0.98, 1)
    lg.ellipse("fill", x, y + 54, 36, 10, 16)
  end
  -- the slices in the air, and on the plates being eaten
  for n = 0, NSLICE - 1 do
    local p, to, t0 = slice_plan(n)
    local P, Lx = PIES[p], LINE[to][1]
    if lt > t0 and lt < t0 + 1 then
      local f = lt - t0
      slice(lerp(P[2], Lx, f), lerp(P[3], 900, f) - sin(f * pi) * 140, P[1], 1.2)
    elseif lt >= t0 + 1 and lt < t0 + 2.6 then
      slice(Lx, 904, P[1], 1.2 * (1 - (lt - t0 - 1) / 1.6))
    end
  end
  if lt > 43 and lt < 46 then G:say("HEY!", 260, 780, 28, 1) end
  if lt > 46 and lt < 49 then G:say("...BURP.", 384, 790, 26, 1) end
  G:plate("PECAN: THE OFFICIAL STATE PIE OF TEXAS", 220, 26, 0xffd23f, L.window(lt, 18, 30, 1.5))
end
CAM.pie = function(lt)
  return L.shot(lt, {{0, 384, 512, 1}, {6, 384, 600, 1.15}, {14, 260, 640, 1.3}, {22, 520, 640, 1.3}, {30, 384, 640, 1.2},
                     {39, 384, 640, 1.2}, {41, 180, 600, 1.5}, {44, 260, 700, 1.4}, {48, 384, 760, 1.4}, {50, 384, 600, 1.1}}, W, H)
end
CUES.pie = {{42.5, "power"}, {44, "boing"}, {46.5, "boing", 0.6}}
for n = 0, NSLICE - 1 do
  local _, _, t0 = slice_plan(n)
  CUES.pie[#CUES.pie + 1] = {t0, "whoosh", 0.4}
  CUES.pie[#CUES.pie + 1] = {t0 + 1, "pop", 0.4}
end

-- ------------------------------------------------------------------ HAPPY THANKSGIVING
function D.finale(lt, len)
  if not art("finale") then G:gradient(0, 0, W, H, {0.35, 0.15, 0.08}, {0.8, 0.42, 0.15}) end
  C.fx.glow(384, 460, 340, 260, 1, 0.65, 0.25, 0.35)
  turkey(384, 640, 2.2, 1, S.t, false, 1, false, true)
  -- the cast hopping in, one by one, along the bottom
  for i, who in ipairs({1, 2, 0, 3, 4}) do
    local t0 = 2 + i * 1.4
    if lt > t0 then
      local x = 120 + (i - 1) * 132
      local y = lerp(H + 60, 800, prog(lt, t0, t0 + 0.6)) - L.hop(lt + i * 0.2, 0.45, 20)
      if who == 0 then L.pac(x, y, 40, 0, S.t, nil) else L.ghost(x, y, 38, GH[who], S.t + i, 0, -0.4, "happy") end
    end
  end
  G:caption("HAPPY", 300, 56, 0xffffff, L.window(lt, 0.5, len, 1))
  G:caption("THANKSGIVING", 370, 72, 0xffb347, L.window(lt, 1, len, 1))
end
CAM.finale = function(lt) return L.shot(lt, {{0, 384, 512, 1}, {12, 384, 560, 1.12}, {20, 384, 512, 1}}, W, H) end
CUES.finale = {{3.4, "pop"}, {4.8, "pop"}, {6.2, "pop"}, {7.6, "pop"}, {9, "pop"}, {10, "cheer"}}

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
  for _, n in ipairs({"open", "parade", "farm", "autumn_day", "autumn_dusk", "table", "football", "pie", "finale"}) do
    S.art[n] = G:art("thanksgiving", n)
  end
  for _, s in ipairs(SCENES) do if s[4] then G:label(s[4], 56, 0xffffff) end end
  for _, l in ipairs({{"PRESENTS", 26, 0x6ef0c8}, {"THANKSGIVING", 72, 0xffb347},
                      {"HAPPY", 56, 0xffffff}, {"PARDONED!", 56, 0xffd23f}, {"GRATEFUL FOR YOU", 40, 0xffd23f},
                      {"WHAT ARE YOU THANKFUL FOR?", 32, 0xffffff},
                      {"PECAN: THE OFFICIAL STATE PIE OF TEXAS", 26, 0xffd23f}}) do G:label(l[1], l[2], l[3]) end
end

function M.act() return S and scene_at(S.t)[2] or "open" end
function M.music() return S and scene_at(S.t)[3] or "tg_harvest" end

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
  -- leaves drifting down (not indoors)
  if sc[2] ~= "table" and sc[2] ~= "football" and sc[2] ~= "pie" and G.R:random() < dt * 10 and #G.debris < 200 then
    local c = LEAF[G.R:random(1, #LEAF)]
    G.debris[#G.debris + 1] = {x = G.R:random() * W, y = -10, vx = 20 + G.R:random() * 30, vy = 40 + G.R:random() * 40,
                               life = 30, max = 30, c = c, size = 10 + G.R:random() * 6, g = 0, rot = G.R:random() * 6,
                               spin = (G.R:random() - 0.5) * 3, confetti = true}
  end
  -- the steam off the turkey and the pies
  if sc[2] == "table" and lt > 22 and lt < 60 and G.R:random() < dt * 8 then
    G:puff(330 + G.R:random() * 110, 720, {1, 1, 1}, 30, 4, 2, 6, 0.3)
  end
  if sc[2] == "pie" and G.R:random() < dt * 6 then
    local p = PIES[G.R:random(1, 3)]
    G:puff(p[2] + (G.R:random() - 0.5) * 80, p[3] - 10, {1, 1, 1}, 30, 4, 2, 6, 0.25)
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
    G:text(sc[5], 0, H - 38, 20, {1, 0.85, 0.6}, b)
  end
  local f = 1 - min(lt / 1.2, (len - lt) / 1.2, 1)
  if f > 0 then
    lg.setColor(0, 0, 0, f)
    lg.rectangle("fill", 0, 0, W, H)
  end
end

return M
