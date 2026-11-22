-- New Year's Eve: Home's show for the end of December. On the night itself it is live: from the evening the
-- real time is on screen, and as midnight comes the show jumps so that its countdown ends exactly at 00:00:00,
-- when the fireworks go up with the new year's number. Otherwise (a demo, or the days around) it plays through.
-- (On the night the party and the resolutions go round for hours: their gags change with each round.) Every
-- scene a story with its own camera (SHOWS_BLUEPRINT.md):
--   0:00  STARLIGHT PRESENTS ... NEW YEAR'S EVE                                   (Midnight Disco)
--   0:08  The party: the guests arriving, Blinky at the turntables lighting the floor, a dance-off, the conga,
--         a balloon popped by a noisemaker, limbo, the confetti cannon fired too early   (Midnight Disco)
--   2:00  Resolutions: the chalk writing each one, its author acting it out below, a check mark (Clyde's
--         crossed out again)                                                     (Resolution Rag)
--   3:20  The ball: lit up, coming down all the way, the crowd growing, a hat blown off, an interview, the last
--         minute on the board and ten, nine, ... one, everybody jumping            (Countdown)
--   4:50  Midnight: HAPPY NEW YEAR; hugs, fireworks that draw a heart, Pac-Man, a ghost and the year; the toast
--                                                                                 (Midnight)
--   6:20  Auld Lang Syne: up on the roof one by one, sparklers lit one from the next, arm in arm, a shooting star
--         and their wishes, the sparklers burning down                           (Auld Lang Syne, public domain)
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
  {0, "open", "ny_disco"},
  {8, "party", "ny_disco", "THE PARTY", "PARTY HATS ON  ·  NOISEMAKERS READY"},
  {120, "resolutions", "ny_rag", "RESOLUTIONS", "THIS YEAR, FOR SURE"},
  {200, "ball", "ny_countdown", "THE BALL DROP", "EVERYBODY COUNT"},
  {290, "midnight", "ny_midnight", "MIDNIGHT", "HAPPY NEW YEAR"},
  {380, "auld", "ny_auld", "AULD LANG SYNE", "FOR OLD TIMES' SAKE"},
}
local BALL_LEN = 90                                -- the ball scene: midnight at its end
M.SEGMENTS = {}
for _, s in ipairs(SCENES) do if s[4] then M.SEGMENTS[#M.SEGMENTS + 1] = {s[1], s[4]} end end
M.THUMB = 4

local RESOLUTIONS = {
  {"PAC-MAN", "EAT FEWER GHOSTS"}, {"BLINKY", "STOP CHASING PEOPLE"}, {"PINKY", "LESS AMBUSHING"},
  {"INKY", "MAKE UP MY MIND"}, {"CLYDE", "GO LEFT FOR ONCE"}, {"THE CABINET", "60 FPS ALL YEAR"},
}

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
local GOLD = {1, 0.82, 0.3}
local PARTY = {{1, 0.3, 0.6}, {0.3, 0.7, 1}, {1, 0.85, 0.2}, {0.5, 1, 0.5}, {1, 1, 1}}

-- the time now (tests: HOME_NY_NOW=epoch pretends; it then runs on from there)
local function now()
  local fake = tonumber(os.getenv("HOME_NY_NOW") or "")
  if fake then return fake + (S and S.clock or 0) end
  return os.time()
end
-- The midnight this show is counting to, if it is the night itself (Dec 31 from 6 PM to Jan 1 1 AM): its epoch
local function live_midnight()
  local t = now()
  local d = os.date("*t", t)
  if d.month == 12 and d.day == 31 and d.hour >= 18 then
    return os.time({year = d.year + 1, month = 1, day = 1, hour = 0, min = 0, sec = 0})
  end
  if d.month == 1 and d.day == 1 and d.hour < 1 then
    return os.time({year = d.year, month = 1, day = 1, hour = 0, min = 0, sec = 0})
  end
  return nil
end

-- ------------------------------------------------------------------ small things
local function party_hat(x, y, r, c, tilt)
  lg.push()
  lg.translate(x, y)
  lg.rotate(tilt or 0)
  rgba(c)
  lg.polygon("fill", -r * 0.6, 0, r * 0.6, 0, 0, -r * 1.5)
  lg.setColor(1, 1, 1, 0.8)
  lg.setLineWidth(2)
  lg.line(-r * 0.3, -r * 0.75, r * 0.3, -r * 0.75)
  rgba(GOLD)
  lg.circle("fill", 0, -r * 1.5, r * 0.18, 8)
  lg.pop()
end

local function noisemaker(x, y, dir, k, c)
  rgba(c)
  lg.setLineWidth(4)
  lg.line(x, y, x + dir * (10 + k * 40), y - 4)
  if k > 0.8 then lg.circle("fill", x + dir * (12 + k * 40), y - 4, 4, 8) end
end

local function clock_face(x, y, r, tt)
  lg.setColor(0.95, 0.92, 0.85, 1)
  lg.circle("fill", x, y, r, 40)
  lg.setColor(0.4, 0.3, 0.2, 1)
  lg.setLineWidth(4)
  lg.circle("line", x, y, r, 40)
  for i = 0, 11 do
    local a = i / 12 * 2 * pi
    lg.rectangle("fill", x + sin(a) * r * 0.82 - 2, y - cos(a) * r * 0.82 - 2, 4, 4)
  end
  local d = os.date("*t", tt)
  local h = (d.hour % 12) + d.min / 60
  local mnt = d.min + d.sec / 60
  lg.setLineWidth(5)
  lg.line(x, y, x + sin(h / 12 * 2 * pi) * r * 0.5, y - cos(h / 12 * 2 * pi) * r * 0.5)
  lg.setLineWidth(3)
  lg.line(x, y, x + sin(mnt / 60 * 2 * pi) * r * 0.75, y - cos(mnt / 60 * 2 * pi) * r * 0.75)
  lg.setColor(0.8, 0.1, 0.1, 1)
  lg.setLineWidth(1.5)
  lg.line(x, y, x + sin(d.sec / 60 * 2 * pi) * r * 0.8, y - cos(d.sec / 60 * 2 * pi) * r * 0.8)
end

-- the time shown in the show: real on the night; in a demo, 11:58:30 PM running to midnight at the ball's end
local function show_time()
  if S.midnight then return now() end
  local base = os.time({year = 2026, month = 12, day = 31, hour = 23, min = 58, sec = 30})
  local sc, lt = scene_at(S.t)
  if sc[2] == "ball" then return base + 90 - (BALL_LEN - lt) end
  if S.t < 200 then return base - (200 - S.t) end
  return base + 90 + (S.t - 290)
end

local function year_next()
  if S.midnight then return os.date("%Y", S.midnight + 3600) end
  return tostring(tonumber(os.date("%Y", os.time())) + (tonumber(os.date("%m")) == 1 and 0 or 1))
end

-- one of the cast: 0 Pac-Man, 1-4 the ghosts; with a party hat (unless no_hat)
local function guest(who, x, y, r, t, lx, ly, mood, hat_c, open, no_hat)
  if who == 0 then
    L.pac(x, y, r, (lx or 1) >= 0 and 0 or pi, t, open)
    if not no_hat then party_hat(x - 2, y - r * 0.9, r * 0.6, hat_c or PARTY[3], 0.2) end
  else
    L.ghost(x, y, r, GH[who], t + who, lx, ly, mood)
    if not no_hat then party_hat(x, y - r * 0.85, r * 0.55, hat_c or PARTY[who], sin(t * 4 + who) * 0.15) end
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

function D.open(lt, len)
  if not art("open") then G:gradient(0, 0, W, H, {0.02, 0.02, 0.08}, {0.12, 0.06, 0.2}) end
  local a = L.window(lt, 0.5, 4, 0.7)
  G:brand(400, a)
  G:caption("PRESENTS", 472, 26, 0x6ef0c8, a)
  G:caption("NEW YEAR'S EVE", 430, 70, 0xffd23f, L.window(lt, 4.2, 8, 0.7))
end

-- ------------------------------------------------------------------ the party
local function disco_ball(x, y, r, t, spin)
  lg.setColor(0.6, 0.6, 0.65, 1)
  lg.rectangle("fill", x - 2, 0, 4, y - r)
  lg.setColor(0.75, 0.75, 0.82, 1)
  lg.circle("fill", x, y, r, 32)
  for row = -3, 3 do
    for col = -4, 4 do
      local u = col / 4.5 + (t * 0.15 * spin) % (1 / 4.5)
      if abs(u) < 1 then
        local yy = y + row / 3.5 * r
        local w = math.sqrt(max(0, 1 - (row / 3.5) ^ 2))
        local xx = x + sin(u * pi / 2) * r * w
        local sh = 0.6 + 0.4 * cos(u * 3 + t * 3 * spin + row)
        lg.setColor(sh, sh, sh * 1.05, 1)
        lg.rectangle("fill", xx - 5 * w, yy - 5, 10 * w * cos(u * pi / 2), 9)
      end
    end
  end
  if spin > 0.1 then
    lg.setBlendMode("add")
    for i = 1, 40 do
      local a = i * 2.4 + t * 0.6
      local px = x + cos(a) * (200 + (i % 7) * 50)
      local py = y + 300 + sin(a * 1.3) * (220 + (i % 5) * 40)
      local c = PARTY[i % #PARTY + 1]
      lg.setColor(c[1], c[2], c[3], 0.5 * spin)
      lg.circle("fill", px, py, 5, 8)
    end
    lg.setBlendMode("alpha")
  end
end

local DJ_ON = 15
local MOVES = {"spin", "hop", "moonwalk", "chomp"}
local DANCE = {16, 22, 28}                       -- the dance-off: one dancer every 4 s from 18
local CONGA = {36, 52}
local POP_AT = 56
local LIMBO = {64, 84}
local CANNON = 102
-- where each guest is (who 0-4): arriving, their spots, the conga, limbo
local SPOTS = {[0] = {384, 860}, {170, 840}, {290, 900}, {478, 900}, {598, 840}}
local function party_pos(lt, who)
  local sx, sy = SPOTS[who][1], SPOTS[who][2]
  local arrive = 2 + who * 2
  if lt < arrive then return nil end
  if lt < arrive + 2 then
    local f = prog(lt, arrive, arrive + 2)
    return lerp(-60, sx, f), sy - sin(f * pi) * 30
  end
  if lt > CONGA[1] and lt < CONGA[2] + 2 then
    -- the conga: round the floor, Pac-Man in front
    local f = lin(lt, CONGA[1], CONGA[2])
    local a = f * 2 * pi * 1.25 - who * 0.42 + pi / 2
    local cx, cy = 384 + cos(a) * 270, 870 + sin(a) * 80
    local back = prog(lt, CONGA[2], CONGA[2] + 2)
    local k = prog(lt, CONGA[1], CONGA[1] + 1.5)
    return lerp(lerp(sx, cx, k), sx, back), lerp(lerp(sy, cy, k), sy, back)
  end
  if lt > LIMBO[1] and lt < LIMBO[2] then
    -- limbo: Blinky and Clyde hold the bar; the others staggered in line, under it in turn
    local fin = prog(lt, LIMBO[1], LIMBO[1] + 1.2)
    local fout = 1 - prog(lt, LIMBO[2] - 1.2, LIMBO[2])
    local k = min(fin, fout)
    if who == 1 then return lerp(sx, 230, k), lerp(sy, 860, k) end
    if who == 4 then return lerp(sx, 540, k), lerp(sy, 860, k) end
    local order = ({[0] = 3, [2] = 1, [3] = 2})[who]
    local t0 = LIMBO[1] + 2 + (order - 1) * 6
    local f = lin(lt, t0, t0 + 4)
    local lx0 = 160 - (order - 1) * 52
    local lx1 = 620 + (order - 1) * 44
    return lerp(sx, lerp(lx0, lx1, f), k), lerp(sy, 880, k)
  end
  if who == 4 and lt > 99 and lt < 107 then
    -- Clyde walks over to the left and bumps into the confetti cannon at CANNON (102s)
    if lt < CANNON then
      local f = prog(lt, 99, CANNON)
      return lerp(sx, 118, f), lerp(sy, 790, f)
    elseif lt < CANNON + 0.5 then
      local f = prog(lt, CANNON, CANNON + 0.5)
      return lerp(118, 152, f), 790 - sin(f * pi) * 14
    elseif lt < 105 then
      return 152, 790
    else
      local f = prog(lt, 105, 107)
      return lerp(152, sx, f), lerp(790, sy, f)
    end
  end
  return sx, sy
end
local function limbo_bar(lt)
  local n = floor((lt - LIMBO[1] - 2) / 6)
  return 760 + clamp(n, 0, 2) * 34
end
function D.party(lt, len)
  if not art("party") then G:gradient(0, 0, W, H, {0.08, 0.04, 0.14}, {0.18, 0.08, 0.22}) end
  local on = lt > DJ_ON
  -- the dance floor: dark until the DJ starts
  for r = 0, 5 do
    for c = 0, 7 do
      local col = PARTY[(r + c + floor(S.t * 2)) % #PARTY + 1]
      lg.setColor(col[1], col[2], col[3], on and 0.4 or 0.06)
      lg.rectangle("fill", c * 96 + 2, 760 + r * 44 + 2, 92, 40)
    end
  end
  disco_ball(384, 180, 70, S.t, on and 1 or 0)
  clock_face(110, 380, 60, show_time())
  -- the DJ booth: Blinky at the turntables
  lg.setColor(0.15, 0.1, 0.2, 1)
  lg.rectangle("fill", 600, 640, 150, 110, 8, 8, 4)
  for k = 0, 1 do
    lg.setColor(0.08, 0.08, 0.1, 1)
    lg.circle("fill", 640 + k * 70, 652, 24, 20)
    lg.setColor(0.8, 0.2, 0.3, 1)
    lg.circle("fill", 640 + k * 70, 652, 6, 10)
    if on then
      lg.setColor(1, 1, 1, 0.5)
      local a = S.t * 6 + k
      lg.line(640 + k * 70, 652, 640 + k * 70 + cos(a) * 20, 652 + sin(a) * 7)
    end
  end
  if lt > 8 and not (lt > LIMBO[1] and lt < LIMBO[2]) and not (lt > CONGA[1] and lt < CONGA[2] + 2) then
    local dbob = on and abs(sin(S.t * 4.2)) * 10 or 0
    L.ghost(675, 610 - dbob, 32, GH[1], S.t, -0.5, 0.6, on and "happy" or nil)
    party_hat(675, 582 - dbob, 18, PARTY[1], 0.1)
    lg.setColor(0.1, 0.1, 0.1, 1)
    lg.setLineWidth(3)
    lg.arc("line", "open", 675, 604 - dbob, 34, pi + 0.3, 2 * pi - 0.3, 12)
    lg.setLineWidth(1)
  end
  -- balloons, rising (Balloon #5 drifts right to Clyde's noisemaker tip at POP_AT)
  for i = 1, 8 do
    local by = 900 - ((S.t * 30 + i * 140) % 1100)
    local bx = 60 + i * 85 + sin(S.t + i) * 12
    if i == 5 and lt > POP_AT - 4 and lt <= POP_AT then
      local f = prog(lt, POP_AT - 4, POP_AT)
      bx = lerp(bx, 678, f)
      by = lerp(by, 825, f)
    end
    if not (i == 5 and lt > POP_AT - 0.05 and lt < POP_AT + 8) then
      rgba(PARTY[i % #PARTY + 1])
      lg.ellipse("fill", bx, by, 22, 28, 16)
      lg.setColor(0.9, 0.9, 0.9, 0.6)
      lg.setLineWidth(1)
      lg.line(bx, by + 28, bx + sin(S.t * 2 + i) * 6, by + 80)
    end
  end
  -- the limbo bar
  if lt > LIMBO[1] and lt < LIMBO[2] then
    local y = limbo_bar(lt)
    lg.setColor(1, 0.85, 0.2, 1)
    lg.setLineWidth(6)
    lg.line(250, y, 520, y)
  end
  -- the guests
  local cheer = (lt > CANNON and lt < CANNON + 4) or (lt > POP_AT + 1.5 and lt < POP_AT + 4)
  for who = 0, 4 do
    local x, y = party_pos(lt, who)
    if x and not (who == 1 and lt > 8 and not (lt > LIMBO[1] and lt < LIMBO[2]) and not (lt > CONGA[1] and lt < CONGA[2] + 2)) then
      local dance = on and L.hop(S.t + who * 0.3, 0.48, 14) or 0
      local lx, mood, rot = 0, nil, 0
      -- the dance-off: each in turn takes the floor (and smoothly returns)
      local d_i = floor((lt - 18) / 4)
      if lt > 18 and lt < 34 and d_i >= 0 and d_i < 4 then
        local dancer = ({0, 2, 3, 4})[d_i + 1]
        if dancer == who then
          local t0 = 18 + d_i * 4
          local mv = MOVES[(d_i + (S.round or 0)) % 4 + 1]
          local dk = prog(lt, t0, t0 + 0.6) * (1 - prog(lt, t0 + 3.4, t0 + 4.0))
          x, y = lerp(x, 384, dk), lerp(y, 820, dk)
          if mv == "spin" then rot = ((lt - t0) * 8 * dk) % (2 * pi)
          elseif mv == "hop" then dance = L.hop(lt, 0.3, 50) * dk
          elseif mv == "moonwalk" then x = x + sin(lt * 2) * 90 * dk lx = -1
          else mood = "happy" end
        end
      end
      if lt > POP_AT and lt < POP_AT + 1.5 then mood = "wide" dance = 0 end
      if cheer then mood = "happy" dance = L.hop(S.t + who * 0.2, 0.4, 30) end
      -- limbo: bending under the bar
      local squash = 1
      if lt > LIMBO[1] and lt < LIMBO[2] and who ~= 1 and who ~= 4 then
        local bar = limbo_bar(lt)
        if x > 230 and x < 540 then squash = clamp((y - bar) / 70, 0.35, 1) end
        dance = 0
      end
      lg.push()
      lg.translate(x, y - dance)
      lg.rotate(rot)
      lg.scale(1 / squash ^ 0.3, squash)
      guest(who, 0, 0, who == 0 and 40 or 36, S.t, lx ~= 0 and lx or (x < 384 and 1 or -1), 0, mood, nil, who == 0 and (cheer and 0.9 or nil) or nil)
      lg.pop()
      if who == 4 and lt > POP_AT - 3 and lt < POP_AT + 1 then
        noisemaker(x + 30, y - dance, 1, prog(lt, POP_AT - 3, POP_AT - 0.2), GOLD)
      end
    end
  end
  -- the confetti cannon at the side, angled RIGHT (+0.8) into the room, fired too early
  lg.setColor(0.3, 0.3, 0.35, 1)
  lg.push()
  lg.translate(80, 760)
  lg.rotate(0.8)
  lg.rectangle("fill", -14, -60, 28, 70, 4, 4, 4)
  lg.pop()
  if lt > 2 and lt < 5 then G:say("COME ON IN!", 384, 720, 24, 1) end
  if lt > DJ_ON - 0.5 and lt < DJ_ON + 2.5 then G:say("DROP THE BEAT!", 675, 540, 24, 1) end
  if lt > POP_AT and lt < POP_AT + 2 then G:say("POP!", 678, 760, 32, 1) end
  if lt > 92 and lt < 97 then G:say("IS IT MIDNIGHT YET?", 384, 720, 22, 1) end
  if lt > 96 and lt < 100 then G:say("NOT YET!", 110, 290, 26, 1) end
  if lt > CANNON + 0.5 and lt < CANNON + 4 then G:say("OOPS!", 152, 710, 28, 1) end
  if lt > LIMBO[2] - 8 and lt < LIMBO[2] - 4 then G:say("HOW LOW?!", 384, 700, 24, 1) end
end
CAM.party = function(lt)
  local keys = {{0, 384, 512, 1}, {2, 260, 800, 1.3}, {12, 460, 820, 1.3}, {DJ_ON - 1, 650, 640, 1.7}, {DJ_ON + 1.5, 650, 640, 1.7},
                {17.5, 384, 700, 1.15}}
  for d = 0, 3 do
    keys[#keys + 1] = {18.6 + d * 4, 384, 780, 1.55}
    keys[#keys + 1] = {21.6 + d * 4, 384, 780, 1.55}
  end
  for _, k in ipairs({{34.5, 384, 700, 1.1}, {CONGA[2], 384, 700, 1.1}, {POP_AT - 3, 580, 800, 1.4}, {POP_AT + 0.5, 620, 780, 1.5},
                      {POP_AT + 3, 384, 640, 1.1}, {LIMBO[1] + 1, 384, 820, 1.4}, {LIMBO[2], 384, 840, 1.6}, {88, 384, 600, 1.1},
                      {92, 300, 700, 1.3}, {96, 110, 400, 1.8}, {100, 110, 400, 1.8}, {CANNON - 0.5, 200, 640, 1.3},
                      {CANNON + 1, 384, 512, 1}, {112, 384, 512, 1}}) do keys[#keys + 1] = k end
  return L.shot(lt, keys, W, H)
end
CUES.party = {{4.2, "pop", 0.4}, {6.2, "pop", 0.4}, {8.2, "pop", 0.4}, {10.2, "pop", 0.4}, {12.2, "pop", 0.4}, {DJ_ON, "clunk"},
              {DJ_ON + 0.2, "power"}, {POP_AT, "pop"}, {POP_AT + 0.1, "boing"}, {POP_AT + 2, "cheer"}, {CONGA[1], "chime"},
              {CANNON, "boom"}, {CANNON + 0.3, "cheer"}, {98, "tick"}, {99, "tick"},
              {CANNON, function()
                for i = 1, 140 do
                  local a = 0.8 - pi / 2 + (G.R:random() - 0.5) * 0.6
                  G:spark(80 + cos(a) * 60, 760 + sin(a) * 60, cos(a) * (300 + G.R:random() * 400), sin(a) * (300 + G.R:random() * 400), 3,
                          PARTY[i % #PARTY + 1], 7, 260)
                end
              end}}
for d = 0, 3 do CUES.party[#CUES.party + 1] = {18 + d * 4, "ding", 0.5} end
for k = 0, 2 do CUES.party[#CUES.party + 1] = {LIMBO[1] + 2 + k * 6 + 2, "boing", 0.6} end

-- ------------------------------------------------------------------ resolutions
local RES_T = 6                                   -- the first written at 6 s, one every 11 s
local function res_t(i) return RES_T + (i - 1) * 11 end
local function actor_say(txt, ax, ay, sz, a)
  G:say(txt, 384 + (ax - 384) * 1.45, 960 + (ay - 960) * 1.45, sz, a)
end
local function actor(i, lt)
  -- the author of resolution i, acting it out below the board
  local t0 = res_t(i) + 3
  local f = lt - t0
  if f < 0 or f > 8 then return end
  local x0 = 384
  local y = 930
  if i == 1 then
    -- Pac-Man, a blue ghost going by: mouth open... shut. No.
    local gx = lerp(W + 40, -40, f / 8)
    L.ghost(gx, y, 30, GH[1], S.t, -1, 0, "scared")
    local tempt = gx > 300 and gx < 500
    L.pac(x0 - 60, y, 36, 0, S.t, tempt and 0.9 or 0.05)
    if f > 3.5 and f < 6 then actor_say("NO. MUST NOT.", x0 - 60, y - 50, 22, 1) end
  elseif i == 2 then
    -- Blinky chasing Pac-Man, stopping, turning away
    local px = f < 4 and lerp(-40, 500, f / 4) or 500 + (f - 4) * 40
    local bx = f < 3 and lerp(-140, 340, f / 3) or 340 - max(0, f - 4) * 30
    L.pac(px, y, 30, 0, S.t, nil)
    L.ghost(bx, y, 32, GH[1], S.t, f < 3.5 and 1 or -1, 0, nil)
    if f > 3.5 and f < 6.5 then actor_say("I'M NOT CHASING. I'M WALKING.", bx, y - 50, 20, 1) end
  elseif i == 3 then
    -- Pinky: BOO! ...sorry
    local up = f > 2 and f < 3.5
    local sneak = f < 2 and sin(f * 8) * 6 or 0
    L.ghost(x0 + (f < 2 and lerp(-200, 0, f / 2) or 0), y - (up and L.hop(f - 2, 1.5, 90) or 0) - abs(sneak), 34, GH[2], S.t, 1, 0, (f > 3.5) and "happy" or nil)
    L.pac(x0 + 120, y, 30, pi, S.t, up and 0.9 or nil)
    if up then actor_say("BOO!", x0, y - 70, 28, 1) end
    if f > 3.6 and f < 6.5 then actor_say("SORRY! HABIT.", x0, y - 60, 22, 1) end
  elseif i == 4 then
    -- Inky: left? right? left? (facing synced to velocity derivative cos(...))
    local arg = f * (2 + f * 0.8)
    local look = cos(arg) >= 0 and 1 or -1
    -- a step one way, a step the other, faster and faster
    local dx = sin(arg) * 110
    L.ghost(x0 + dx, y - L.hop(f * (1 + f * 0.4), 0.5, 18), 34, GH[3], S.t, look, 0, f > 6 and "wide" or nil)
    actor_say(look < 0 and "LEFT?" or "RIGHT?", x0 + dx, y - 60, 24, 1)
  elseif i == 5 then
    -- Clyde: left... then right after all
    local x = f < 3 and lerp(x0, x0 - 140, f / 3) or (f < 4 and x0 - 140 or lerp(x0 - 140, W + 60, (f - 4) / 4))
    L.ghost(x, y, 34, GH[4], S.t, f < 4 and -1 or 1, 0, nil)
    if f > 3 and f < 5 then actor_say("NAH.", x, y - 60, 24, 1) end
  else
    -- the cabinet, very proud of itself
    lg.setColor(0.15, 0.2, 0.6, 1)
    lg.rectangle("fill", x0 - 40, y - 90, 80, 130, 6, 6, 4)
    lg.setColor(0.05, 0.05, 0.1, 1)
    lg.rectangle("fill", x0 - 30, y - 74, 60, 46)
    G:text("60", x0 - 30, y - 70, 30, {0.4, 1, 0.5}, 0.6 + 0.4 * abs(sin(S.t * 4)), "center", 60)
    lg.setColor(1, 0.85, 0.2, 1)
    lg.rectangle("fill", x0 - 40, y - 100, 80, 14, 4, 4, 4)
  end
end
function D.resolutions(lt, len)
  if not art("chalkboard") then
    G:gradient(0, 0, W, H, {0.15, 0.1, 0.08}, {0.1, 0.07, 0.05})
    lg.setColor(0.12, 0.2, 0.15, 1)
    lg.rectangle("fill", 60, 170, 648, 660)
  end
  G:text("RESOLUTIONS", 60, 190, 40, {0.95, 0.95, 0.9}, 1, "center", 648)
  local chalk_x, chalk_y
  for i, r in ipairs(RESOLUTIONS) do
    local t0 = res_t(i)
    if lt > t0 then
      local y = 260 + (i - 1) * 90
      G:text(r[1] .. ":", 90, y, 26, {1, 0.85, 0.4}, 1, "left", 600)
      -- written letter by letter
      local n = floor(clamp((lt - t0) / 2.4, 0, 1) * #r[2])
      local txt = r[2]:sub(1, n)
      G:text(txt, 110, y + 34, 28, {0.95, 0.95, 0.9}, 1, "left", 560)
      if n < #r[2] then
        chalk_x, chalk_y = 110 + C.font(28):getWidth(txt), y + 40
      end
      -- the check mark once it's been acted out (Clyde's crossed out)
      if lt > t0 + 9 then
        lg.setColor(0.5, 1, 0.5, 1)
        lg.setLineWidth(5)
        lg.line(640, y + 34, 656, y + 52, 686, y + 14)
        if i == 5 and lt > t0 + 9.8 then
          lg.setColor(1, 0.35, 0.35, 1)
          lg.line(630, y + 10, 696, y + 56)
          lg.line(696, y + 10, 630, y + 56)
        end
      end
    end
  end
  -- the chalk, writing (with tiny chalk-dust puffs)
  lg.setColor(1, 1, 1, 1)
  if chalk_x then
    lg.rectangle("fill", chalk_x, chalk_y + sin(S.t * 30) * 3, 30, 9, 3, 3, 4)
    for k = 1, 3 do
      local df = (S.t * 2.4 + k * 0.33) % 1
      lg.setColor(0.95, 0.95, 0.92, (1 - df) * 0.55)
      lg.circle("fill", chalk_x - 4 + sin(k * 2.1 + S.t * 6) * 8, chalk_y + 10 + df * 24, 2 + df * 2.5, 6)
    end
  else
    lg.rectangle("fill", 600, 822, 40, 10, 3, 3, 4)
  end
  -- (the acting, bigger: drawn scaled about the floor's middle)
  lg.push()
  lg.translate(384, 960)
  lg.scale(1.45, 1.45)
  lg.translate(-384, -960)
  for i = 1, #RESOLUTIONS do actor(i, lt) end
  lg.pop()
  G:plate("(RESULTS MAY VARY)", 900, 26, 0xffd23f, L.window(lt, 72, len, 1))
end
CAM.resolutions = function(lt)
  local keys = {{0, 384, 512, 1}, {RES_T - 0.5, 384, 512, 1}}
  for i = 1, #RESOLUTIONS do
    local t0 = res_t(i)
    local y = 260 + (i - 1) * 90
    keys[#keys + 1] = {t0 + 0.6, 320, y + 40, 1.45}
    keys[#keys + 1] = {t0 + 2.6, 345, y + 40, 1.45}
    keys[#keys + 1] = {t0 + 3.6, 384, 860, 1.5}
    keys[#keys + 1] = {t0 + 8.4, 384, 860, 1.5}
    keys[#keys + 1] = {t0 + 10.4, 600, y + 40, 1.7}
  end
  keys[#keys + 1] = {RES_T + 6 * 11 + 1, 384, 512, 1}
  keys[#keys + 1] = {80, 384, 540, 1.05}
  return L.shot(lt, keys, W, H)
end
CUES.resolutions = {}
for i = 1, #RESOLUTIONS do
  CUES.resolutions[#CUES.resolutions + 1] = {res_t(i), "tape", 0.5}
  CUES.resolutions[#CUES.resolutions + 1] = {res_t(i) + 9, "ding", 0.6}
end
CUES.resolutions[#CUES.resolutions + 1] = {res_t(5) + 9.8, "boing"}
CUES.resolutions[#CUES.resolutions + 1] = {res_t(3) + 5, "boo"}

-- ------------------------------------------------------------------ the ball drop
local TOWER = {384, 470}                          -- the pole's top, where the ball starts
local function ball_y(lt) return lerp(150, 430, prog(lt, 4, BALL_LEN)) end
local function crowd_n(lt) return floor(lerp(20, 70, lin(lt, 0, 60))) end
local function hat_xy(lt)
  local f = lin(lt, 24, 30)
  return lerp(470, 560, f) + sin(f * pi) * sin(f * 8) * 70, lerp(873, 790, f) - sin(f * pi) * 300
end
function D.ball(lt, len)
  local painted = art("square")
  if not painted then G:gradient(0, 0, W, 760, {0.01, 0.01, 0.06}, {0.08, 0.04, 0.16}) end
  -- the pole and the ball, coming down the whole scene (it reaches the bottom at midnight)
  lg.setColor(0.5, 0.5, 0.55, 1)
  lg.rectangle("fill", 378, 120, 12, 360)
  local by = ball_y(lt)
  local lit = prog(lt, 1, 4)
  C.fx.glow(384, by, 120, 120, 1, 0.9, 0.7, 0.5 * lit)
  lg.setColor(0.85 * (0.4 + 0.6 * lit), 0.85 * (0.4 + 0.6 * lit), 0.92 * (0.4 + 0.6 * lit), 1)
  lg.circle("fill", 384, by, 52, 32)
  lg.setBlendMode("add")
  for i = 1, 48 do
    local a = i * 2.4 + S.t * 0.3
    local rr = 46 * math.sqrt((i % 12) / 12)
    local c = PARTY[i % #PARTY + 1]
    local on = lt > 1 + i / 16 and (floor(S.t * 6) + i) % 3 ~= 0
    if on then
      lg.setColor(c[1], c[2], c[3], 0.9)
      lg.circle("fill", 384 + cos(a) * rr, by + sin(a) * rr, 4, 6)
    end
  end
  lg.setBlendMode("alpha")
  G:text(year_next(), 234, 480, 72, {1, 0.85, 0.3}, 1, "center", 300)
  -- the board on the tower: the minute counting down
  local left = BALL_LEN - lt
  if left <= 60 then
    lg.setColor(0, 0, 0, 0.75)
    lg.rectangle("fill", 334, 560, 100, 50, 6, 6, 4)
    G:text(tostring(math.ceil(left)), 334, 566, 36, {1, 0.4, 0.3}, 1, "center", 100)
  end
  -- the crowd: more and more of them, hats on, waving
  local n = crowd_n(lt)
  local jump = left <= 10 and left > 0
  for i = 0, n do
    local x = (i * 37 + (i % 3) * 11) % W
    local y = 790 + (i * 53) % 200
    local hop = jump and L.hop(lt, 1, 26) or abs(sin(S.t * 3 + i)) * 3
    if lt > 74 and lt < 77.5 then
      local wx = lerp(-100, W + 100, lin(lt, 74, 77))
      hop = hop + max(0, 1 - abs(x - wx) / 70) * 30
    end
    lg.setColor(0.15, 0.12, 0.2, 1)
    lg.circle("fill", x, y - hop, 14, 10)
    party_hat(x, y - 12 - hop, 9, PARTY[i % #PARTY + 1], sin(S.t * 3 + i) * 0.2)
  end
  -- the cast in the crowd: Pac-Man up on Blinky's... head; Pinky hatless while her hat flies; Clyde always in crowd
  local cx = 560
  local hop = jump and L.hop(lt, 1, 30) or 0
  local interviewing = lt > 40 and lt < 52
  guest(1, cx, 880 - hop, 36, S.t, -1, -1, jump and "happy" or nil)
  guest(0, cx, 820 - hop, 32, S.t, -1, -1, nil, nil, jump and 0.8 or nil)
  guest(2, cx - 90, 900 - hop, 32, S.t, 1, -1, jump and "happy" or nil, nil, nil, lt > 24 and lt < 31)
  guest(3, cx + 90, 900 - hop, 32, S.t, -1, -1, jump and "happy" or nil)
  guest(4, cx + 170, 900 - (interviewing and 0 or hop), 32, S.t, -1, interviewing and 0 or -1, jump and "happy" or nil)
  -- Clyde with the microphone: the interview (asking Inky) + blinking ON AIR tally dot
  if interviewing then
    lg.setColor(0.2, 0.2, 0.25, 1)
    lg.rectangle("fill", cx + 130, 880, 14, 30, 3, 3, 4)
    if floor(S.t * 3) % 2 == 0 then
      lg.setColor(1, 0.15, 0.15, 1)
      lg.circle("fill", cx + 137, 875, 5, 8)
    end
    if lt < 46 then G:say("ANY RESOLUTIONS?", cx + 170, 850, 20, 1)
    else G:say("TO GO LEFT. OR RIGHT.", cx + 90, 850, 20, 1) end
  end
  -- Pinky's hat blowing off, up and away, caught cleanly by Pac-Man at 30s
  if lt > 24 and lt < 31 then
    local f = lin(lt, 24, 30)
    local hx, hy = hat_xy(lt)
    party_hat(hx, hy, 22, PARTY[2], lt < 30 and f * 12 or 0.15)
    if lt > 26 and lt < 28.5 then G:say("MY HAT!", cx - 90, 850, 20, 1) end
  end
  if lt > 30 and lt < 33 then G:say("GOT IT!", cx, 760, 22, 1) end
  -- the blimp (52-64): across the sky, the year flashing on its side
  if lt > 52 and lt < 64 then
    local bx = lerp(W + 220, -260, lin(lt, 52, 64))
    local bob = sin(S.t * 1.5) * 6
    lg.setColor(0.75, 0.78, 0.85, 1)
    lg.ellipse("fill", bx, 230 + bob, 170, 56, 32)
    lg.setColor(0.6, 0.62, 0.7, 1)
    lg.polygon("fill", bx + 150, 230 + bob, bx + 200, 190 + bob, bx + 200, 270 + bob)
    lg.rectangle("fill", bx - 30, 280 + bob, 60, 20, 6, 6, 4)
    lg.setColor(0.05, 0.05, 0.1, 1)
    lg.rectangle("fill", bx - 120, 206 + bob, 240, 48, 8, 8, 4)
    local flash = floor(S.t * 3) % 2 == 0
    G:text(flash and year_next() or "HAPPY NEW YEAR", bx - 120, 214 + bob, flash and 34 or 22,
           flash and {1, 0.85, 0.3} or {0.4, 1, 0.8}, 1, "center", 240)
  end
  -- the dance cam (64-74): the big screen on the building, each of the cast dancing in turn
  if lt > 63.5 and lt < 74.5 then
    local sx, sy, sw, sh = 60, 250, 250, 190
    local on = prog(lt, 63.5, 64.2) * (1 - prog(lt, 74, 74.5))
    lg.setColor(0.05, 0.05, 0.08, on)
    lg.rectangle("fill", sx - 10, sy - 10, sw + 20, sh + 20, 8, 8, 4)
    lg.setColor(0.15, 0.1, 0.3, on)
    lg.rectangle("fill", sx, sy, sw, sh)
    local who = ({1, 2, 0, 3, 4})[clamp(floor((lt - 64) / 2) + 1, 1, 5)]
    local ph = (lt - 64) % 2
    local dx = sin(ph * pi * 2) * 30
    local dy = L.hop(ph, 0.5, 26)
    if on > 0.9 then
      guest(who, sx + sw / 2 + dx, sy + sh / 2 + 30 - dy, 56, S.t * 2, 0, 0, "happy", nil, who == 0 and 0.8 or nil)
      G:text("DANCE CAM!", sx, sy + 6, 22, {1, 0.85, 0.3}, 1, "center", sw)
      if floor(S.t * 3) % 2 == 0 then
        lg.setColor(1, 0.15, 0.15, 1)
        lg.circle("fill", sx + sw - 16, sy + 18, 6, 10)
      end
    end
  end
  -- the wave and the noisemakers (74-80)
  if lt > 74 and lt < 80 then
    local wx = lerp(-100, W + 100, lin(lt, 74, 77))
    lg.setColor(1, 1, 1, 0.12)
    lg.rectangle("fill", wx - 60, 760, 120, 260)
  end
  -- the time, and the last ten huge (spaced so 160px digits never overlap the digital clock)
  local tt = show_time()
  G:text(os.date("%I:%M:%S %p", tt):gsub("^0", ""), 0, 616, 36, {1, 1, 1}, 1)
  if left <= 10 and left > 0 then
    local nn = math.ceil(left)
    local beat = 1 - (nn - left)
    G:caption(tostring(nn), 748, 160, 0xffd23f, 1, 0.8 + 0.3 * beat)
  end
end
CAM.ball = function(lt)
  local by = ball_y(lt)
  if lt > 24.5 and lt < 29.5 then local hx, hy = hat_xy(lt) return L.shot(0, {{0, hx, hy + 60, 1.6}}, W, H) end
  if lt > 13 and lt < 16 then return L.shot(lt, {{13, 384, 420, 1.05}, {16, 384, 420, 1.05}}, W, H) end
  if lt > 33 and lt < 36.5 then return L.shot(lt, {{33, 384, 420, 1.05}, {36.5, 384, 420, 1.05}}, W, H) end
  return L.shot(lt, {{0, 384, 512, 1}, {4, 384, by, 1.8}, {12, 384, by + 40, 1.7}, {16, 470, 860, 1.4}, {23, 520, 860, 1.4},
                     {24, 470, 830, 1.6}, {31, 540, 830, 1.6}, {36, 384, by + 120, 1.3}, {40, 640, 860, 1.6}, {52, 640, 860, 1.6},
                     {53, 384, 300, 1.15}, {63, 384, 300, 1.15}, {64.2, 185, 345, 1.8}, {74, 185, 345, 1.8},
                     {75, 384, 820, 1.2}, {78, 384, 820, 1.2}, {80, 384, 512, 1}}, W, H)
end
CUES.ball = {{14, "boom", 0.5}, {14.6, "crackle"}, {34, "boom", 0.5}, {34.6, "crackle"}, {14.2, "cheer", 0.5}, {1, "clunk"}, {24, "whoosh"}, {30, "boing"}, {40, "ding", 0.5}, {52.5, "jet", 0.4}, {64, "clunk"}, {64.2, "chime"},
             {74, "cheer", 0.6}, {75, "whoosh"}}
for k = 1, 4 do CUES.ball[#CUES.ball + 1] = {64 + k * 2, "pop", 0.4} end
-- the confetti cannons on the rooftops, tested (14, 34): a burst from each side
for _, t in ipairs({14, 34}) do
  CUES.ball[#CUES.ball + 1] = {t, function()
    for side = -1, 1, 2 do
      local x = 384 + side * 300
      for i = 1, 70 do
        local c = PARTY[G.R:random(1, #PARTY)]
        G:spark(x, 380, -side * (60 + G.R:random() * 260), -200 - G.R:random() * 300, 2.6, c, 8, 160, false)
      end
    end
  end}
end

-- ------------------------------------------------------------------ midnight: fireworks that draw pictures
-- points along a shape (unit size, centred): heart, Pac-Man, a ghost
local function shape_points(kind, n)
  local pts = {}
  for i = 0, n - 1 do
    local f = i / n
    if kind == "heart" then
      local t = f * 2 * pi
      pts[#pts + 1] = {16 * sin(t) ^ 3 / 17, -(13 * cos(t) - 5 * cos(2 * t) - 2 * cos(3 * t) - cos(4 * t)) / 17}
    elseif kind == "pac" then
      if f < 0.8 then
        local a = 0.6 + f / 0.8 * (2 * pi - 1.2)
        pts[#pts + 1] = {cos(a), sin(a)}
      else
        local g = (f - 0.8) / 0.2
        local a = g < 0.5 and -0.6 or 0.6
        local d = g < 0.5 and 1 - g * 2 or (g - 0.5) * 2
        pts[#pts + 1] = {cos(a) * d, sin(a) * d}
      end
    else
      if f < 0.45 then
        local a = pi + f / 0.45 * pi
        pts[#pts + 1] = {cos(a), sin(a)}
      elseif f < 0.55 then
        pts[#pts + 1] = {1, (f - 0.45) / 0.1 * 0.8}
      elseif f < 0.9 then
        local g = (f - 0.55) / 0.35
        pts[#pts + 1] = {1 - g * 2, 0.8 + 0.18 * abs(sin(g * 3 * pi))}
      else
        pts[#pts + 1] = {-1, 0.8 - (f - 0.9) / 0.1 * 0.8}
      end
    end
  end
  return pts
end
local function shape_burst(kind, x, y, size, c)
  local pts = shape_points(kind, 90)
  for _, p in ipairs(pts) do
    G.glow[#G.glow + 1] = {x = x, y = y, vx = 0, vy = 0, tx = x + p[1] * size, ty = y + p[2] * size, life = 3.2, max = 3.2, c = c, size = 16}
    G.glow[#G.glow + 1] = {x = x, y = y, vx = 0, vy = 0, tx = x + p[1] * size, ty = y + p[2] * size, life = 3.2, max = 3.2, c = {1, 1, 1}, size = 6}
  end
  G:spark(x, y, 0, 0, 0.3, {1, 1, 1}, 60, 0, true)
  C.sfx("pop")
  G:later_sfx(G.t + 0.4, "crackle")
end
local SHAPES = {{14, "heart", 260, 300, {1, 0.3, 0.5}}, {22, "pac", 520, 280, {1, 0.85, 0.2}}, {30, "ghost", 300, 320, {0.3, 0.9, 1}},
                {38, "heart", 500, 300, {1, 0.4, 0.8}}}
function D.midnight(lt, len)
  if not art("midnight") then G:gradient(0, 0, W, H, {0.02, 0.02, 0.1}, {0.1, 0.04, 0.18}) end
  G:draw_back()
  local pulse = 1 + 0.06 * sin(S.t * 6)
  G:caption("HAPPY NEW YEAR", 330, 70, 0xffd23f, L.window(lt, 0, len, 0.5) * (1 - L.window(lt, 12, 44, 1) * 0.85), pulse)
  G:caption(year_next(), 440, 120, 0xff4fd8, L.window(lt, 0.3, len, 0.5) * (1 - L.window(lt, 12, 44, 1) * 0.85))
  -- the cast: a hug (all together), then the toast (stepping inward so glasses clink in hand), then dancing
  local toast_in = (lt > 44 and lt < 52) and prog(lt, 44, 46.5) * (1 - prog(lt, 49.5, 51.5)) or 0
  for who = 0, 4 do
    local hx = 384 + (who - 2) * 46
    local tx = 384 + (who - 2) * 56
    local sx = 150 + who * 117
    local x = lt < 10 and lerp(sx, hx, prog(lt, 0.5, 2)) or lerp(hx, sx, prog(lt, 10, 12))
    if toast_in > 0 then x = lerp(x, tx, toast_in) end
    local y = 860 - ((lt > 50) and L.hop(S.t + who * 0.25, 0.45, 24) or (lt < 10 and abs(sin(S.t * 3 + who)) * 6 or 0))
    guest(who, x, y, who == 0 and 40 or 36, S.t, x < 384 and 1 or -1, lt > 12 and lt < 44 and -1 or 0, (lt < 10 or lt > 50) and "happy" or nil,
          nil, who == 0 and (lt < 10 and 0.8 or nil) or nil)
    -- the toast: glasses raised, clinked cleanly in hand
    if lt > 44 and lt < 52 then
      local gx = x + (who < 2 and 30 or (who > 2 and -30 or 0))
      local raise = prog(lt, 44, 46)
      local gy = y - 20 - raise * 40
      if lt > 47 then gx = lerp(gx, 384 + (who - 2) * 14, prog(lt, 47, 47.6) * (1 - prog(lt, 49.5, 51))) end
      lg.setColor(0.9, 0.95, 1, 0.8)
      lg.polygon("fill", gx - 8, gy - 18, gx + 8, gy - 18, gx, gy)
      lg.rectangle("fill", gx - 1, gy, 2, 12)
      lg.setColor(1, 0.85, 0.4, 0.8)
      lg.polygon("fill", gx - 6, gy - 16, gx + 6, gy - 16, gx, gy - 4)
    end
  end
  -- streamers
  lg.setLineWidth(3)
  for i = 1, 8 do
    rgba(PARTY[i % #PARTY + 1], 0.8)
    local pts = {}
    for k = 0, 10 do
      pts[#pts + 1] = i * 90 - 40 + sin(S.t * 2 + k * 0.6 + i) * 20
      pts[#pts + 1] = min(lt * 120, 700) * k / 10
    end
    lg.line(pts)
  end
  if lt > 1 and lt < 5 then G:say("HAPPY NEW YEAR!!!", 384, 780, 28, 1) end
  if lt > 47 and lt < 50 then G:say("CLINK!", 384, 740, 28, 1) end
  if lt > 23 and lt < 27 then G:say("THAT'S ME!", 150, 790, 22, 1) end
end
CAM.midnight = function(lt)
  return L.shot(lt, {{0, 384, 700, 1.25}, {10, 384, 760, 1.35}, {12, 384, 512, 1}, {44, 384, 512, 1}, {46, 384, 780, 1.5}, {52, 384, 780, 1.5},
                     {56, 384, 600, 1.1}, {90, 384, 512, 1}}, W, H)
end
CUES.midnight = {{0.05, "cheer"}, {0.1, "boom"}, {47.2, "ding"}, {47.4, "chime"}, {52, "cheer"}}
for _, sh in ipairs(SHAPES) do
  CUES.midnight[#CUES.midnight + 1] = {sh[1] - 1.4, function()
    G:rocket(sh[3], sh[4], {from = 1024, burst = function(x, y) shape_burst(sh[2], x, y, 150, sh[5]) end})
  end}
end

-- ------------------------------------------------------------------ Auld Lang Syne: on the roof
local ROW = {110, 247, 384, 521, 658}
local CASTI = {0, 1, 2, 3, 4}
local function lit_at(i) return 14 + (i - 1) * 1.6 end
local NOD_T = 81                       -- Auld Lang Syne: the first to nod off; the rest, every 2 s
function D.auld(lt, len)
  if not art("rooftop") then G:gradient(0, 0, W, H, {0.02, 0.02, 0.08}, {0.08, 0.06, 0.16}) end
  G:draw_back()
  -- the towns around setting off their own (66-80): bursts along the skyline BEHIND the rooftop cast
  if lt > 66 and lt < 80 then
    lg.setBlendMode("add")
    for k = 0, 9 do
      local t0 = 66 + k * 1.35
      local a = lt - t0
      if a > 0 and a < 1.6 then
        local fx, fy = 120 + (k * 263) % 530, 380 + (k * 97) % 160
        local c = ({{1, 0.4, 0.4}, {0.4, 0.8, 1}, {1, 0.85, 0.3}, {0.6, 1, 0.5}, {1, 0.5, 0.9}})[k % 5 + 1]
        for d = 0, 23 do
          local ang = d / 24 * 2 * pi
          local r = a * 70 * (0.7 + (k % 3) * 0.2)
          lg.setColor(c[1], c[2], c[3], 1 - a / 1.6)
          lg.circle("fill", fx + cos(ang) * r * 2.2, fy + sin(ang) * r * 2.2 + a * a * 14, 8, 6)
        end
      end
    end
    lg.setBlendMode("alpha")
  end
  -- the hatch they come up through
  lg.setColor(0.25, 0.2, 0.28, 1)
  lg.rectangle("fill", 330, 880, 108, 40, 4, 4, 4)
  if lt < 14 then
    lg.setColor(0.05, 0.04, 0.06, 1)
    lg.rectangle("fill", 340, 884, 88, 32)
  end
  local sway = lt > 22 and sin(S.t * 1.2) * 14 * (1 - prog(lt, NOD_T - 2, NOD_T + 1)) or 0
  local burn = 1 - lin(lt, 70, 96)
  for i, who in ipairs(CASTI) do
    -- up through the hatch one by one, to their place in the row
    local t0 = 1 + (i - 1) * 2.2
    if lt > t0 then
      local f = prog(lt, t0, t0 + 1.8)
      local x = lerp(384, ROW[i], f) + sway
      local y = lerp(920, 770, prog(lt, t0, t0 + 0.6))
      -- nodding off one by one (80-90), each leaning on the next
      local nod = NOD_T + (i - 1) * 2
      local asleep = lt > nod
      local lean = asleep and prog(lt, nod, nod + 0.8) or 0
      -- lean slightly toward neighbor when passing the sparkler
      local pass_lean = 0
      if i < 5 then
        local pt = lit_at(i + 1)
        if lt > pt - 0.8 and lt < pt + 0.5 then
          pass_lean = 0.18 * sin(lin(lt, pt - 0.8, pt + 0.5) * pi)
        end
      end
      x = x + lean * 18
      y = y + lean * 14
      local mood = lt > 66 and (asleep and "sleep" or "happy") or nil
      if lt > 66 and lt < 80 then mood = "happy" end
      lg.push()
      lg.translate(x, y)
      lg.rotate(lean * 0.35 + pass_lean)
      guest(who, 0, 0, who == 0 and 40 or 38, S.t, 1, ((lt > 50 and lt < 62) or (lt > 66 and lt < 80)) and -1 or 0, mood, nil,
            who == 0 and (asleep and 0.05 or 0.1) or nil)
      if who == 0 and asleep then
        lg.setColor(1, 0.86, 0.15, 1)
        lg.circle("fill", 40 * 0.12, -40 * 0.5, 40 * 0.15, 10)
        lg.setColor(0.1, 0.05, 0.1, 1)
        lg.setLineWidth(3)
        lg.arc("line", "open", 40 * 0.12, -40 * 0.5, 5.5, 0.15 * pi, 0.85 * pi, 8)
        lg.setLineWidth(1)
      end
      lg.pop()
      if asleep and lt < len - 1 then
        local ph = (S.t * 0.6 + i * 0.2) % 1
        G:text("z", x + 20 + ph * 20, y - 50 - ph * 50, ph < 0.5 and 20 or 28, {1, 1, 1}, 1 - ph, "left", 30)
      end
      -- the sparkler: lit from the one before
      if lt > lit_at(i) - 0.5 then
        local sx, sy = x + 30 + pass_lean * 40, y - 10
        lg.setColor(0.6, 0.6, 0.6, 1)
        lg.setLineWidth(2)
        lg.line(sx, sy, sx + 14 + pass_lean * 45, sy - 70 * (0.3 + 0.7 * burn))
        if lt > lit_at(i) and burn > 0.02 and G.R:random() < 0.7 then
          for k = 1, 3 do
            local a = G.R:random() * 2 * pi
            G:spark(sx + 14 + pass_lean * 45, sy - 70 * (0.3 + 0.7 * burn), cos(a) * 60, sin(a) * 60, 0.4, {1, 0.9, 0.6}, 3, 80, true)
          end
        end
      end
      -- the wishes after the shooting star
      if lt > 52 and lt < 62 then
        local wi = i
        local bx, byy = x, y - 110 - sin(S.t * 2 + i) * 6
        lg.setColor(1, 1, 1, 0.9)
        lg.circle("fill", bx, byy, 30, 20)
        lg.circle("fill", x + 8, y - 64, 6, 8)
        lg.circle("fill", x + 4, y - 50, 4, 8)
        if wi == 1 then lg.setColor(1, 0.85, 0.7, 1) lg.circle("fill", bx, byy, 10, 12)
        elseif wi == 2 then
          lg.setColor(0.2, 0.72, 0.28, 1)
          lg.setLineWidth(2.5)
          lg.line(bx - 6, byy - 2, bx + 2, byy - 16, bx + 8, byy)
          lg.setLineWidth(1)
          lg.setColor(0.9, 0.1, 0.15, 1)
          lg.circle("fill", bx - 6, byy + 4, 8, 10)
          lg.circle("fill", bx + 8, byy + 6, 8, 10)
        elseif wi == 3 then lg.setColor(1, 0.85, 0.2, 1) L.star(bx, byy, 14)
        elseif wi == 4 then lg.setColor(1, 0.3, 0.5, 1) lg.circle("fill", bx - 5, byy - 2, 7, 10) lg.circle("fill", bx + 5, byy - 2, 7, 10) lg.polygon("fill", bx - 12, byy, bx + 12, byy, bx, byy + 13)
        else L.pac(bx, byy, 12, 0, S.t, nil) end
      end
    end
  end
  -- the shooting star
  if lt > 48 and lt < 50 then
    local f = lin(lt, 48, 50)
    lg.setColor(1, 1, 1, 1 - f)
    lg.setLineWidth(3)
    lg.line(lerp(600, 180, f), lerp(80, 260, f), lerp(600, 180, f) + 80, lerp(80, 260, f) - 34)
  end
  if lt > 14 and lt < 16.5 then G:say("PASS IT ON!", ROW[1] + 30, 690, 22, 1) end
  if lt > 49 and lt < 52 then G:say("MAKE A WISH!", ROW[3], 680, 24, 1) end
  if lt > NOD_T - 2 and lt < NOD_T then G:say("*YAWN*", ROW[1], 700, 24, 1) end
  if lt > 67 and lt < 70 then G:say("LOOK, ALL THE TOWNS!", ROW[3], 680, 22, 1) end
  for i = 1, 5 do
    local t0 = 24 + (i - 1) * 4
    if lt > t0 + 0.5 and lt < t0 + 3.5 then
      G:say(({"SHOULD AULD ACQUAINTANCE...", "...BE FORGOT...", "...AND NEVER...", "...BROUGHT TO MIND?", "LA LA LAAA!"})[i], ROW[i] + sway, 690, 22, 1)
    end
  end
  G:plate("THANKS FOR PLAYING THIS YEAR", 300, 32, 0xffd23f, L.window(lt, 64, len - 2, 2))
end
CAM.auld = function(lt)
  local keys = {{0, 384, 700, 1.3}, {12, 384, 760, 1.3}}
  for i = 1, 5 do
    keys[#keys + 1] = {lit_at(i), ROW[i] + 40, 740, 1.8}
  end
  keys[#keys + 1] = {22, 384, 640, 1.1}
  for i = 1, 5 do
    keys[#keys + 1] = {24 + (i - 1) * 4, ROW[i] + 20, 740, 1.6}
    keys[#keys + 1] = {26.5 + (i - 1) * 4, ROW[i] + 40, 730, 1.6}
  end
  for _, k in ipairs({{45, 384, 600, 1.05}, {47, 384, 420, 1.2}, {50, 384, 420, 1.2}, {53, 384, 700, 1.25},
                      {62, 384, 700, 1.25}, {66, 384, 560, 1.15}, {79, 384, 600, 1.15}, {81, ROW[1] + 60, 760, 1.6},
                      {90, ROW[5] - 60, 760, 1.6}, {96, 384, 740, 1.3}, {100, 384, 512, 1}}) do
    keys[#keys + 1] = k
  end
  return L.shot(lt, keys, W, H)
end
CUES.auld = {{48, "whoosh", 0.5}, {52, "chime"}}
for k = 0, 9 do CUES.auld[#CUES.auld + 1] = {66 + k * 1.35, k % 2 == 0 and "pop" or "crackle", 0.25} end
for i = 1, 5 do CUES.auld[#CUES.auld + 1] = {NOD_T + (i - 1) * 2, "chime", 0.18} end
for i = 1, 5 do
  CUES.auld[#CUES.auld + 1] = {1 + (i - 1) * 2.2, "pop", 0.4}
  CUES.auld[#CUES.auld + 1] = {lit_at(i), "crackle", 0.6}
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
  S = {t = at or 0, clock = 0, round = 0}
  S.midnight = (not at) and live_midnight() or nil
  G.t, G.prev = S.t, S.t - 0.001
  S.art = {}
  for _, n in ipairs({"open", "party", "chalkboard", "square", "midnight", "rooftop"}) do
    S.art[n] = G:art("newyear", n)
  end
  for _, s in ipairs(SCENES) do if s[4] then G:label(s[4], 56, 0xffffff, s[1]) end end
  for _, l in ipairs({{"PRESENTS", 26, 0x6ef0c8, 0}, {"NEW YEAR'S EVE", 70, 0xffd23f, 0},
                      {"HAPPY NEW YEAR", 70, 0xffd23f, 290}, {year_next(), 120, 0xff4fd8, 290},
                      {"(RESULTS MAY VARY)", 26, 0xffd23f, 120},
                      {"THANKS FOR PLAYING THIS YEAR", 32, 0xffd23f, 380}}) do
    G:label(l[1], l[2], l[3], l[4])
  end
  for i = 1, 10 do G:label(tostring(i), 160, 0xffd23f, 200) end
end

function M.act() return S and scene_at(S.t)[2] or "open" end
function M.music() return S and scene_at(S.t)[3] or "ny_disco" end

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
  S.clock = S.clock + dt
  -- the night itself: before the last minute and a half, the party (and the resolutions) go round; then the
  -- ball, timed so that its end is midnight exactly
  if S.midnight then
    local left = S.midnight - now()
    if left > 0 then
      if left <= BALL_LEN then
        local want = 200 + (BALL_LEN - left)
        if abs(G.t - want) > 1 then G.t = want G.prev = want - 0.001 end
      elseif G.t >= 195 then
        G.t, G.prev = 8, 7.999
        S.round = S.round + 1
      end
    end
  end
  G:step(dt)
  S.t = G.t
  local sc, lt = scene_at(S.t)
  cues(sc[2], lt, dt)
  if sc[2] == "midnight" or (sc[2] == "auld" and lt > 24 and lt < 46) then
    S.fw = (S.fw or 0) - dt
    if S.fw <= 0 then
      S.fw = sc[2] == "midnight" and (lt > 12 and lt < 44 and 0.9 or (0.25 + G.R:random() * 0.3)) or 1.6
      local far = sc[2] == "auld"
      G:rocket(80 + G.R:random() * 600, far and (300 + G.R:random() * 200) or (80 + G.R:random() * 260),
               {from = 1024, big = not far and G.R:random() < 0.3})
    end
    if sc[2] == "midnight" and lt < 30 then G:confetti(2, PARTY) end
  end
  if sc[2] == "ball" and BALL_LEN - lt <= 10 and floor(BALL_LEN - lt + dt) ~= floor(BALL_LEN - lt) then C.sfx("pop") end
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
  if sc[2] ~= "midnight" and sc[2] ~= "auld" then G:draw_back() end
  G:draw_front()
  G:unlook()
  if sc[4] and sc[2] ~= "midnight" then
    G:plate(sc[4], 30, 56, 0xffffff, L.window(lt, 1.5, 9, 1))
  end
  if sc[5] then
    local b = L.window(lt, 2, len - 1.5, 1)
    lg.setColor(0.02, 0.02, 0.06, 0.55 * b)
    lg.rectangle("fill", 0, H - 50, W, 50)
    G:text(sc[5], 0, H - 38, 20, {1, 0.9, 0.5}, b)
  end
  -- on the night, before the ball: the real time and how long to go
  if S.midnight and sc[2] ~= "ball" and sc[2] ~= "midnight" and sc[2] ~= "auld" then
    local left = S.midnight - now()
    if left > 0 then
      lg.setColor(0.02, 0.02, 0.06, 0.7)
      lg.rectangle("fill", 160, 110, 448, 56, 14, 14, 8)
      local hh, mm = floor(left / 3600), floor(left / 60) % 60
      local txt = hh > 0 and string.format("%d H %02d MIN TO MIDNIGHT", hh, mm) or string.format("%d:%02d TO MIDNIGHT", mm, left % 60)
      G:text(txt, 160, 124, 28, {1, 0.85, 0.3}, 1, "center", 448)
    end
  end
  local f = 1 - min(lt / 1.0, (len - lt) / 1.0, 1)
  if sc[2] == "ball" then f = 1 - min(lt / 1.0, (len - lt) / 0.25, 1) end
  if sc[2] == "midnight" then f = 1 - min((len - lt) / 1.0, 1) end
  if f > 0 then
    lg.setColor(0, 0, 0, f)
    lg.rectangle("fill", 0, 0, W, H)
  end
end

return M
