-- New Year's Eve: Home's show for the end of December. On the night itself it is live: from the evening the
-- real time is on screen, and as midnight comes the show jumps so that its countdown ends exactly at 00:00:00,
-- when the fireworks go up with the new year's number. Otherwise (a demo, or the days around) it plays through:
--   0:00  STARLIGHT PRESENTS ... NEW YEAR'S EVE                                   (Midnight Disco)
--   0:08  The party: a disco ball, party hats, noisemakers, balloons, the clock on the wall
--   2:00  Resolutions: the cast's list, one by one                                (Resolution Rag)
--   3:20  The ball: lit up on its pole over the crowd, coming down; ten, nine, ... one   (Countdown)
--   4:50  Midnight: HAPPY NEW YEAR, fireworks, confetti, streamers                 (Midnight)
--   6:20  Auld Lang Syne: sparklers, arm in arm                                    (Auld Lang Syne, public domain)
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
local GHOSTS = {{1, 0.18, 0.2}, {1, 0.55, 0.85}, {0.25, 0.95, 1}, {1, 0.65, 0.2}}
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

local function noisemaker(x, y, dir, t, c)
  local k = (sin(t * 3) * 0.5 + 0.5)
  rgba(c)
  lg.setLineWidth(4)
  lg.line(x, y, x + dir * (10 + k * 40), y - 4)
  if k > 0.8 then lg.circle("fill", x + dir * (12 + k * 40), y - 4, 4, 8) end
end

local function clock_face(x, y, r, tt, real)
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
  if not art("open") then G:gradient(0, 0, W, H, {0.02, 0.02, 0.08}, {0.12, 0.06, 0.2}) end
  local a = L.window(lt, 0.5, 4, 0.7)
  G:brand(400, a)
  G:caption("PRESENTS", 472, 26, 0x6ef0c8, a)
  G:caption("NEW YEAR'S EVE", 430, 70, 0xffd23f, L.window(lt, 4.2, 8, 0.7))
end

local function disco_ball(x, y, r, t)
  lg.setColor(0.6, 0.6, 0.65, 1)
  lg.rectangle("fill", x - 2, 0, 4, y - r)
  lg.setColor(0.75, 0.75, 0.82, 1)
  lg.circle("fill", x, y, r, 32)
  for row = -3, 3 do
    for col = -4, 4 do
      local u = col / 4.5 + (t * 0.15) % (1 / 4.5)
      if abs(u) < 1 then
        local yy = y + row / 3.5 * r
        local w = math.sqrt(max(0, 1 - (row / 3.5) ^ 2))
        local xx = x + sin(u * pi / 2) * r * w
        local sh = 0.6 + 0.4 * cos(u * 3 + t * 3 + row)
        lg.setColor(sh, sh, sh * 1.05, 1)
        lg.rectangle("fill", xx - 5 * w, yy - 5, 10 * w * cos(u * pi / 2), 9)
      end
    end
  end
  -- the light specks sweeping the room
  lg.setBlendMode("add")
  for i = 1, 40 do
    local a = i * 2.4 + t * 0.6
    local px = x + cos(a) * (200 + (i % 7) * 50)
    local py = y + 300 + sin(a * 1.3) * (220 + (i % 5) * 40)
    local c = PARTY[i % #PARTY + 1]
    lg.setColor(c[1], c[2], c[3], 0.5)
    lg.circle("fill", px, py, 5, 8)
  end
  lg.setBlendMode("alpha")
end

function D.party(lt, len)
  if not art("party") then G:gradient(0, 0, W, H, {0.08, 0.04, 0.14}, {0.18, 0.08, 0.22}) end
  -- the dance floor
  for r = 0, 5 do
    for c = 0, 7 do
      local col = PARTY[(r + c + floor(S.t * 2)) % #PARTY + 1]
      lg.setColor(col[1], col[2], col[3], 0.35)
      lg.rectangle("fill", c * 96 + 2, 760 + r * 44 + 2, 92, 40)
    end
  end
  disco_ball(384, 180, 70, S.t)
  -- the clock on the wall
  clock_face(110, 360, 60, show_time())
  -- balloons rising
  for i = 1, 8 do
    local by = 900 - ((S.t * 30 + i * 140) % 1100)
    local bx = 60 + i * 85 + sin(S.t + i) * 12
    local c = PARTY[i % #PARTY + 1]
    rgba(c)
    lg.ellipse("fill", bx, by, 22, 28, 16)
    lg.setColor(0.9, 0.9, 0.9, 0.6)
    lg.setLineWidth(1)
    lg.line(bx, by + 28, bx + sin(S.t * 2 + i) * 6, by + 80)
  end
  -- the dancers
  for i, c in ipairs(GHOSTS) do
    local x = 150 + (i - 1) * 150 + (i > 2 and 80 or 0)
    local hop = abs(sin(S.t * 4.2 + i)) * 18
    C.fx.ghost(x, 700 - hop, 34, c, i % 2 == 0 and -1 or 1, S.t + i, false, false, 1)
    party_hat(x, 668 - hop, 20, PARTY[i], sin(S.t * 4 + i) * 0.2)
    noisemaker(x + 30, 700 - hop, 1, S.t + i, GOLD)
  end
  local hop = abs(sin(S.t * 4.2)) * 18
  C.fx.chomper(384, 690 - hop, 40, 1, S.t, 1)
  party_hat(384, 650 - hop, 24, PARTY[3], 0.2)
end

function D.resolutions(lt, len)
  if not art("chalkboard") then
    G:gradient(0, 0, W, H, {0.15, 0.1, 0.08}, {0.1, 0.07, 0.05})
    -- the chalkboard
    lg.setColor(0.4, 0.25, 0.15, 1)
    lg.rectangle("fill", 40, 150, 688, 700, 10, 10, 6)
    lg.setColor(0.12, 0.2, 0.15, 1)
    lg.rectangle("fill", 60, 170, 648, 660)
  end
  G:text("RESOLUTIONS", 60, 190, 40, {0.95, 0.95, 0.9}, 1, "center", 648)
  local n = floor(clamp((lt - 6) / 10, 0, #RESOLUTIONS))
  for i, r in ipairs(RESOLUTIONS) do
    if i <= n then
      local y = 270 + (i - 1) * 90
      G:text(r[1] .. ":", 90, y, 26, {1, 0.85, 0.4}, 1, "left", 600)
      G:text(r[2], 110, y + 34, 28, {0.95, 0.95, 0.9}, 1, "left", 560)
      -- the check mark, after a beat
      if lt > 6 + i * 10 + 3 then
        lg.setColor(0.5, 1, 0.5, 1)
        lg.setLineWidth(5)
        lg.line(640, y + 34, 656, y + 52, 686, y + 14)
      end
    end
  end
  -- the chalk
  local cx = 120 + ((lt * 60) % 500)
  lg.setColor(1, 1, 1, 1)
  lg.rectangle("fill", cx, 870, 40, 10, 3, 3, 4)
  if lt > 66 then G:plate("(RESULTS MAY VARY)", 900, 26, 0xffd23f, L.window(lt, 66, len, 1)) end
end

function D.ball(lt, len)
  local painted = art("square")
  if not painted then
  G:gradient(0, 0, W, 760, {0.01, 0.01, 0.06}, {0.08, 0.04, 0.16})
  -- the buildings round the square, lit
  for i = 0, 7 do
    local x, h = i * 100 - 10, 300 + (i % 3) * 120
    lg.setColor(0.07, 0.06, 0.12, 1)
    lg.rectangle("fill", x, 760 - h, 92, h)
    for wy = 760 - h + 20, 740, 30 do
      for wx = x + 10, x + 80, 22 do
        local on = ((wx * 7 + wy * 3 + i) % 5) ~= 0
        if on then lg.setColor(1, 0.85, 0.5, 0.7) lg.rectangle("fill", wx, wy, 10, 14) end
      end
    end
  end
  end
  -- the pole and the ball, coming down over the last minute
  lg.setColor(0.5, 0.5, 0.55, 1)
  lg.rectangle("fill", 378, 120, 12, 360)
  local k = clamp((lt - (len - 60)) / 60, 0, 1)
  local by = lerp(150, 430, k)
  C.fx.glow(384, by, 120, 120, 1, 0.9, 0.7, 0.5)
  lg.setColor(0.85, 0.85, 0.92, 1)
  lg.circle("fill", 384, by, 52, 32)
  lg.setBlendMode("add")
  for i = 1, 48 do
    local a = i * 2.4
    local rr = 46 * math.sqrt((i % 12) / 12)
    local c = PARTY[i % #PARTY + 1]
    local on = (floor(S.t * 6) + i) % 3 ~= 0
    lg.setColor(c[1], c[2], c[3], on and 0.9 or 0.3)
    lg.circle("fill", 384 + cos(a) * rr, by + sin(a) * rr, 4, 6)
  end
  lg.setBlendMode("alpha")
  -- the year's numbers under the pole
  local yr = year_next()
  G:text(yr, 234, 480, 72, {1, 0.85, 0.3}, 1, "center", 300)
  -- the crowd in the square: hats and waving
  if not painted then G:gradient(0, 760, W, H, {0.1, 0.08, 0.14}, {0.05, 0.04, 0.08}) end
  for i = 0, 40 do
    local x = (i * 37) % W
    local y = 790 + (i * 53) % 200
    local c = PARTY[i % #PARTY + 1]
    lg.setColor(0.15, 0.12, 0.2, 1)
    lg.circle("fill", x, y, 12, 10)
    party_hat(x, y - 10, 8, c, sin(S.t * 3 + i) * 0.2)
  end
  -- the clock: the real time on the night; the count from ten
  local left = BALL_LEN - lt
  local tt = show_time()
  G:text(os.date("%I:%M:%S %p", tt):gsub("^0", ""), 0, 610, 48, {1, 1, 1}, 1)
  if left <= 10 and left > 0 then
    local n = math.ceil(left)
    local beat = 1 - (n - left)
    G:caption(tostring(n), 760, 160, 0xffd23f, 1, 0.8 + 0.3 * beat)
  end
end

function D.midnight(lt, len)
  if not art("midnight") then G:gradient(0, 0, W, H, {0.02, 0.02, 0.1}, {0.1, 0.04, 0.18}) end
  G:draw_back()
  local pulse = 1 + 0.06 * sin(S.t * 6)
  G:caption("HAPPY NEW YEAR", 330, 70, 0xffd23f, L.window(lt, 0, len, 0.5), pulse)
  G:caption(year_next(), 440, 120, 0xff4fd8, L.window(lt, 0.3, len, 0.5))
  -- the cast below, hugging
  for i, c in ipairs(GHOSTS) do
    local x = 150 + (i - 1) * 150 + (i > 2 and 80 or 0)
    C.fx.ghost(x, 860 + sin(S.t * 3 + i) * 6, 34, c, i <= 2 and 1 or -1, S.t + i, false, false, 1)
    party_hat(x, 828, 20, PARTY[i], 0.15)
  end
  C.fx.chomper(384, 850, 40, 1, S.t, 1)
  party_hat(384, 810, 24, PARTY[3], 0.2)
  -- streamers
  lg.setLineWidth(3)
  for i = 1, 8 do
    local c = PARTY[i % #PARTY + 1]
    rgba(c, 0.8)
    local pts = {}
    for k = 0, 10 do
      pts[#pts + 1] = i * 90 - 40 + sin(S.t * 2 + k * 0.6 + i) * 20
      pts[#pts + 1] = min(lt * 120, 700) * k / 10
    end
    lg.line(pts)
  end
end

function D.auld(lt, len)
  if not art("rooftop") then
    G:gradient(0, 0, W, H, {0.02, 0.02, 0.08}, {0.08, 0.06, 0.16})
    for i, s in ipairs(S.stars) do
      lg.setColor(1, 1, 0.9, 0.4 + 0.4 * sin(S.t + i))
      lg.rectangle("fill", s[1], s[2], 2, 2)
    end
  end
  -- arm in arm, swaying; sparklers
  local sway = sin(S.t * 1.2) * 14
  local cast = {{1, 0.86, 0.15}, GHOSTS[1], GHOSTS[2], GHOSTS[3], GHOSTS[4]}
  for i, c in ipairs(cast) do
    local x = 110 + (i - 1) * 137 + sway
    if i == 1 then C.fx.chomper(x, 760, 40, 1, 0, 1) else C.fx.ghost(x, 770, 38, c, 1, S.t + i, false, false, 1) end
    -- the sparkler, held up
    lg.setColor(0.6, 0.6, 0.6, 1)
    lg.setLineWidth(2)
    lg.line(x + 30, 760, x + 44, 690)
    if G.R:random() < 0.6 then
      for k = 1, 3 do
        local a = G.R:random() * 2 * pi
        G:spark(x + 44, 690, cos(a) * 60, sin(a) * 60, 0.4, {1, 0.9, 0.6}, 3, 80, true)
      end
    end
  end
  G:draw_back()
  G:plate("SHOULD AULD ACQUAINTANCE BE FORGOT", 300, 26, 0xffffff, L.window(lt, 6, 40, 2))
  G:plate("THANKS FOR PLAYING THIS YEAR", 300, 32, 0xffd23f, L.window(lt, 44, len - 2, 2))
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
  S = {t = at or 0, clock = 0}
  S.midnight = (not at) and live_midnight() or nil
  G.t, G.prev = S.t, S.t - 0.001
  S.art = {}
  for _, n in ipairs({"open", "party", "chalkboard", "square", "midnight", "rooftop"}) do
    S.art[n] = G:art("newyear", n)
  end
  local R = G.R
  S.stars = {}
  for i = 1, 80 do S.stars[i] = {R:random() * W, R:random() * 700} end
  for _, s in ipairs(SCENES) do if s[4] then G:label(s[4], 56, 0xffffff) end end
  for _, l in ipairs({{"PRESENTS", 26, 0x6ef0c8}, {"NEW YEAR'S EVE", 70, 0xffd23f},
                      {"HAPPY NEW YEAR", 70, 0xffd23f}, {"(RESULTS MAY VARY)", 26, 0xffd23f},
                      {"SHOULD AULD ACQUAINTANCE BE FORGOT", 26, 0xffffff}, {"THANKS FOR PLAYING THIS YEAR", 32, 0xffd23f}}) do
    G:label(l[1], l[2], l[3])
  end
  for i = 1, 10 do G:label(tostring(i), 160, 0xffd23f) end
end

function M.act() return S and scene_at(S.t)[2] or "open" end
function M.music() return S and scene_at(S.t)[3] or "ny_disco" end

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
      end
    end
  end
  G:step(dt)
  S.t = G.t
  local sc, lt = scene_at(S.t)
  if sc[2] == "midnight" or (sc[2] == "auld" and lt < 20) then
    S.fw = (S.fw or 0) - dt
    if S.fw <= 0 then
      S.fw = sc[2] == "midnight" and (0.2 + G.R:random() * 0.3) or 1.2
      G:rocket(80 + G.R:random() * 600, 80 + G.R:random() * 260, {from = 1024, big = G.R:random() < 0.3})
    end
    if sc[2] == "midnight" and lt < 30 then G:confetti(2, PARTY) end
  end
  if sc[2] == "midnight" and not S.cheered then
    S.cheered = true
    C.sfx("cheer") C.sfx("boom")
  end
  if sc[2] == "ball" and BALL_LEN - lt <= 10 and floor(BALL_LEN - lt + dt) ~= floor(BALL_LEN - lt) then C.sfx("pop") end
  return S.t >= LEN
end

function M.draw()
  if not S then return end
  local sc, lt, len = scene_at(S.t)
  D[sc[2]](lt, len)
  if sc[2] ~= "midnight" and sc[2] ~= "auld" then G:draw_back() end
  G:draw_front()
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
  if sc[2] == "midnight" or sc[2] == "ball" then f = 1 - min((len - lt) / 0.25, 1) end
  if sc[2] == "midnight" then f = 0 end
  if f > 0 then
    lg.setColor(0, 0, 0, f)
    lg.rectangle("fill", 0, 0, W, H)
  end
end

return M
