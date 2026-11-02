-- Longhorns: game day on the Forty Acres. Home's show for the University of Texas (our own drawings, no
-- official marks), nine minutes:
--   0:00  PARTYCADE PRESENTS ... TEXAS LONGHORNS                                  (Game Day)
--   0:10  Game day on the Forty Acres: the Tower at sunrise, live oaks, tailgates, Bevo, fans with Hook 'em
--   1:20  The Longhorn Band: marching in, Big Bertha rolling past; then from above, the band spells TEXAS
--                                                                                  (Burnt Orange March)
--   2:30  Smokey and the flag: the cannon fires, the giant Lone Star flag runs the field   (Drumline)
--   3:35  Hook 'em: the stands, a card stunt (TEXAS), the hand sign, TEXAS! FIGHT!    (Hook 'Em)
--   4:35  The drive: a drive down the field from above, play by play, to a touchdown   (The Drive)
--   6:00  The Red River Rivalry: the State Fair, Big Tex, the Texas Star, the Golden Hat stays in Austin
--                                                                                  (State Fair)
--   7:30  The Tower lit orange: the night, the "1", fireworks                        (Tower Glow)
-- On game days (utgame.lua) a scorebug rides along: the countdown, the live score, the final; when Texas
-- scores during the game, the show stops for it: TOUCHDOWN TEXAS, Smokey, fireworks.
local lg = love.graphics
local L = require("showlib")
local ut = require("utgame")
local M = {}
local C, G
local W, H = 768, 1024
local LEN = 540
M.LEN = LEN
local sin, cos, floor, min, max, abs, pi = math.sin, math.cos, math.floor, math.min, math.max, math.abs, math.pi
local clamp, ease, lerp, mix = L.clamp, L.ease, L.lerp, L.mix
local ORANGE = {0.75, 0.34, 0.0}
local ORANGE_HI = {1.0, 0.5, 0.1}
local WHITE = {0.97, 0.97, 0.95}
local STONE = {0.9, 0.84, 0.7}

local SCENES = {
  {0, "open", "lh_gameday"},
  {10, "campus", "lh_gameday", "GAME DAY", "THE FORTY ACRES  ·  AUSTIN"},
  {80, "band", "lh_march", "THE LONGHORN BAND", "THE SHOWBAND OF THE SOUTHWEST  ·  BIG BERTHA"},
  {150, "smokey", "lh_drumline", "SMOKEY AND THE FLAG", "THE CANNON  ·  THE FLAG RUN"},
  {215, "hookem", "lh_hookem", "HOOK 'EM", "TEXAS!  FIGHT!"},
  {275, "drive", "lh_drive", "THE DRIVE", "FIRST AND TEN  ·  THE LONGHORNS' BALL"},
  {360, "redriver", "lh_fair", "RED RIVER RIVALRY", "THE COTTON BOWL  ·  THE STATE FAIR OF TEXAS"},
  {450, "tower", "lh_tower", "THE TOWER LIT ORANGE", "HOOK 'EM HORNS"},
}
M.SEGMENTS = {}
for _, s in ipairs(SCENES) do if s[4] then M.SEGMENTS[#M.SEGMENTS + 1] = {s[1], s[4]} end end
M.THUMB = 5

local S
local function scene_at(t)
  local k = 1
  for i, s in ipairs(SCENES) do if t >= s[1] then k = i end end
  local s = SCENES[k]
  local e = SCENES[k + 1] and SCENES[k + 1][1] or LEN
  return s, t - s[1], e - s[1], k
end
local function rgba(c, a) lg.setColor(c[1], c[2], c[3], a or 1) end

-- Opponents' colours (ESPN's team data leaves them out): the SEC and the usual others
local TEAM_COLOURS = {ALA = 0x9e1b32, ARK = 0x9d2235, AUB = 0xe87722, FLA = 0x0021a5, UGA = 0xba0c2f, UK = 0x0033a0,
                      LSU = 0x461d7c, MISS = 0xce1126, MSST = 0x660000, MIZ = 0xf1b82d, OU = 0x841617, SC = 0x73000a,
                      TENN = 0xffffff, ["TA&M"] = 0x500000, VAN = 0x866d4b, BAY = 0x154734, TTU = 0xcc0000, TCU = 0x4d1979,
                      OSU = 0xbb0000, MICH = 0x00274c, ND = 0x0c2340, USC = 0x990000, COLO = 0xcfb87c}
-- The opponent (from the game data, else a generic visitor)
local function opp()
  local g = ut.game
  if g then
    local hex = TEAM_COLOURS[g.opp_abbr]
    local col = hex and L.hex(hex) or {0.85, 0.85, 0.85}
    if col[1] + col[2] + col[3] < 0.5 then col = mix(col, {1, 1, 1}, 0.35) end
    return g.opp_abbr, col
  end
  return "VISITORS", {0.85, 0.85, 0.85}
end

-- ------------------------------------------------------------------ the Tower (the Main Building's)
local function tower(x, base, s, lit)
  local st = lit and mix(STONE, ORANGE_HI, 0.85) or STONE
  local sh = lit and mix(STONE, ORANGE, 0.9) or {0.75, 0.68, 0.55}
  -- the Main Building in front
  rgba(sh)
  lg.rectangle("fill", x - 190 * s, base - 70 * s, 380 * s, 70 * s)
  lg.setColor(0.62, 0.28, 0.2, 1)
  lg.polygon("fill", x - 200 * s, base - 70 * s, x + 200 * s, base - 70 * s, x + 180 * s, base - 92 * s, x - 180 * s, base - 92 * s)
  -- the shaft
  rgba(st)
  lg.rectangle("fill", x - 34 * s, base - 380 * s, 68 * s, 300 * s)
  rgba(sh)
  for i = 0, 3 do lg.rectangle("fill", x - 26 * s + i * 16 * s, base - 370 * s, 4 * s, 270 * s) end
  -- the clock stage, the colonnade, the cupola
  rgba(st)
  lg.rectangle("fill", x - 40 * s, base - 430 * s, 80 * s, 50 * s)
  lg.setColor(lit and 1 or 0.95, lit and 0.9 or 0.92, lit and 0.7 or 0.85, 1)
  lg.circle("fill", x, base - 405 * s, 15 * s, 20)
  lg.setColor(0.2, 0.18, 0.15, 1)
  lg.setLineWidth(2 * s)
  local tt = os.time()
  local hh, mm = tonumber(os.date("%I", tt)), tonumber(os.date("%M", tt))
  lg.line(x, base - 405 * s, x + sin((hh + mm / 60) / 12 * 2 * pi) * 8 * s, base - 405 * s - cos((hh + mm / 60) / 12 * 2 * pi) * 8 * s)
  lg.line(x, base - 405 * s, x + sin(mm / 60 * 2 * pi) * 12 * s, base - 405 * s - cos(mm / 60 * 2 * pi) * 12 * s)
  rgba(st)
  lg.rectangle("fill", x - 44 * s, base - 440 * s, 88 * s, 10 * s)
  rgba(sh)
  for i = 0, 5 do lg.rectangle("fill", x - 38 * s + i * 15 * s, base - 476 * s, 6 * s, 36 * s) end
  rgba(st)
  lg.rectangle("fill", x - 44 * s, base - 484 * s, 88 * s, 10 * s)
  lg.rectangle("fill", x - 22 * s, base - 512 * s, 44 * s, 28 * s)
  lg.arc("fill", "pie", x, base - 512 * s, 22 * s, pi, 2 * pi, 16)
  lg.rectangle("fill", x - 2 * s, base - 548 * s, 4 * s, 16 * s)
  if lit then
    -- the "1" in the windows
    lg.setColor(1, 1, 0.85, 1)
    lg.rectangle("fill", x - 4 * s, base - 360 * s, 10 * s, 220 * s)
    lg.rectangle("fill", x - 16 * s, base - 350 * s, 14 * s, 12 * s)
    lg.rectangle("fill", x - 14 * s, base - 148 * s, 30 * s, 10 * s)
    C.fx.glow(x, base - 300 * s, 160 * s, 300 * s, 1, 0.5, 0.1, 0.35)
  end
end

-- A fan, from behind or in front, a Hook 'em hand up now and then
local function fan(x, y, s, shirt, t, hook)
  rgba(shirt)
  lg.rectangle("fill", x - 9 * s, y - 24 * s, 18 * s, 26 * s, 4 * s, 4 * s, 4)
  lg.setColor(0.9, 0.72, 0.58, 1)
  lg.circle("fill", x, y - 30 * s, 7 * s, 10)
  if hook then
    lg.setColor(0.9, 0.72, 0.58, 1)
    local up = abs(sin(t * 3)) * 6 * s
    lg.rectangle("fill", x + 8 * s, y - 50 * s - up, 4 * s, 26 * s)
    lg.rectangle("fill", x + 6 * s, y - 60 * s - up, 3 * s, 10 * s)
    lg.rectangle("fill", x + 12 * s, y - 60 * s - up, 3 * s, 10 * s)
  end
end

-- The Hook 'em hand: index and little finger up, the others folded under the thumb.
local function hookem_hand(x, y, s, col, a)
  rgba(col, a)
  lg.rectangle("fill", x - 40 * s, y - 20 * s, 80 * s, 90 * s, 22 * s, 22 * s, 10)
  lg.rectangle("fill", x - 40 * s, y - 120 * s, 22 * s, 110 * s, 11 * s, 11 * s, 8)
  lg.rectangle("fill", x + 20 * s, y - 100 * s, 20 * s, 90 * s, 10 * s, 10 * s, 8)
  lg.rectangle("fill", x - 18 * s, y - 34 * s, 19 * s, 30 * s, 9 * s, 9 * s, 6)
  lg.rectangle("fill", x + 1 * s, y - 34 * s, 19 * s, 30 * s, 9 * s, 9 * s, 6)
  lg.rectangle("fill", x - 30 * s, y + 4 * s, 64 * s, 22 * s, 11 * s, 11 * s, 8)
  lg.rectangle("fill", x - 30 * s, y + 70 * s, 60 * s, 60 * s, 8 * s, 8 * s, 4)
  lg.setColor(0, 0, 0, 0.18 * a)
  lg.setLineWidth(2 * s)
  lg.line(x - 18 * s, y - 4 * s, x + 20 * s, y - 4 * s)
end

-- ------------------------------------------------------------------ the scenes
local D = {}

function D.open(lt, len)
  G:gradient(0, 0, W, H, {0.12, 0.05, 0.02}, {0.45, 0.18, 0.02})
  C.fx.glow(384, 420, 320, 260, 1, 0.45, 0.05, 0.35)
  L.longhorn_head(384, 420, 2.1, ORANGE_HI, 1)
  local a = L.window(lt, 0.5, 4.5, 0.8)
  G:caption("PARTYCADE", 640, 54, 0xff4fd8, a)
  G:caption("PRESENTS", 712, 26, 0x6ef0c8, a)
  local b = L.window(lt, 4.8, 10, 0.8)
  G:caption("TEXAS", 640, 96, 0xff8c1a, b)
  G:caption("LONGHORNS", 750, 54, 0xffffff, b)
end

function D.campus(lt, len)
  local k = clamp(lt / 30, 0, 1)
  G:gradient(0, 0, W, 760, mix({0.25, 0.2, 0.45}, {0.25, 0.5, 0.9}, k), mix({1, 0.6, 0.35}, {0.8, 0.9, 1}, k))
  C.fx.glow(640, lerp(700, 200, k), 200, 160, 1, 0.75, 0.45, 0.4 * (1 - k * 0.5))
  tower(384, 760, 1.05, false)
  L.live_oak(110, 770, 1.3, S.t)
  L.live_oak(660, 770, 1.2, S.t + 1)
  -- the South Mall
  G:gradient(0, 760, W, H, {0.35, 0.6, 0.25}, {0.25, 0.48, 0.18})
  lg.setColor(0.85, 0.82, 0.72, 1)
  lg.polygon("fill", 330, 760, 438, 760, 520, H, 248, H)
  -- tailgate tents, smoke
  for i, x in ipairs({70, 640}) do
    rgba(i == 1 and ORANGE or WHITE)
    lg.polygon("fill", x - 70, 880, x + 70, 880, x + 52, 840, x - 52, 840)
    lg.setColor(0.4, 0.4, 0.45, 1)
    lg.rectangle("fill", x - 66, 880, 4, 70)
    lg.rectangle("fill", x + 62, 880, 4, 70)
    lg.setColor(0.12, 0.12, 0.13, 1)
    lg.ellipse("fill", x, 930, 26, 12, 16)
  end
  -- Bevo, grazing on the lawn
  L.steer(560, 980, 1.0, S.t * 0.5, {{0.82, 0.48, 0.18}, {0.97, 0.95, 0.9}}, {0.95, 0.92, 0.8})
  -- fans walking to the stadium
  for i = 0, 7 do
    local x = ((S.t * 24 + i * 120) % (W + 100)) - 50
    fan(x, 1000 - (i % 2) * 18, 1.1, i % 3 == 0 and WHITE or ORANGE, S.t + i, i % 2 == 0)
  end
  local a = L.window(lt, 22, 40, 1.5)
  G:plate("THE MAIN BUILDING  ·  THE TOWER", 170, 28, 0xffffff, a)
end

-- the band, side view: rows marching, instruments shining; Big Bertha rolling through
local function bandsman(x, y, s, t, inst)
  local step = sin(t * 8) * 4 * s
  lg.setColor(0.95, 0.95, 0.95, 1)
  lg.rectangle("fill", x - 3 * s, y - 2 * s + step, 5 * s, 18 * s)
  lg.rectangle("fill", x + 2 * s, y - 2 * s - step, 5 * s, 18 * s)
  rgba(ORANGE)
  lg.rectangle("fill", x - 8 * s, y - 34 * s, 16 * s, 32 * s, 3 * s, 3 * s, 4)
  lg.setColor(0.9, 0.72, 0.58, 1)
  lg.circle("fill", x, y - 40 * s, 6 * s, 10)
  lg.setColor(1, 1, 1, 1)
  lg.rectangle("fill", x - 7 * s, y - 56 * s, 14 * s, 12 * s)
  lg.setColor(1, 1, 1, 1)
  lg.rectangle("fill", x - 9 * s, y - 46 * s, 18 * s, 3 * s)
  if inst == 1 then
    lg.setColor(1, 0.85, 0.35, 1)
    lg.circle("fill", x + 10 * s, y - 52 * s, 9 * s, 14)
    lg.rectangle("fill", x + 4 * s, y - 48 * s, 4 * s, 24 * s)
  elseif inst == 2 then
    lg.setColor(1, 0.85, 0.35, 1)
    lg.rectangle("fill", x + 4 * s, y - 40 * s, 18 * s, 4 * s)
    lg.polygon("fill", x + 22 * s, y - 44 * s, x + 28 * s, y - 48 * s, x + 28 * s, y - 32 * s, x + 22 * s, y - 36 * s)
  else
    lg.setColor(0.95, 0.95, 0.95, 1)
    lg.ellipse("fill", x + 2 * s, y - 20 * s, 10 * s, 6 * s, 12)
  end
end

function D.band(lt, len)
  if lt < 36 then
    G:gradient(0, 0, W, 520, {0.25, 0.5, 0.9}, {0.75, 0.85, 1})
    -- the stands across the field
    lg.setColor(1, 1, 1, 1)
    lg.draw(S.stands, 0, 300)
    G:gradient(0, 600, W, H, {0.25, 0.55, 0.22}, {0.2, 0.48, 0.18})
    lg.setColor(1, 1, 1, 0.8)
    for i = 0, 6 do lg.rectangle("fill", 0, 640 + i * 60, W, 3) end
    -- the band marching right, three rows
    local x0 = -900 + lt * 42
    for r = 0, 2 do
      for i = 0, 11 do
        local x = x0 + i * 60 + r * 20
        if x > -30 and x < W + 30 then bandsman(x, 760 + r * 70, 1.4 + r * 0.15, S.t + i * 0.1, (i + r) % 3) end
      end
    end
    -- the drum major out front
    local dm = x0 + 780
    if dm > -30 and dm < W + 30 then
      bandsman(dm, 740, 1.6, S.t * 1.2, 3)
      lg.setColor(0.85, 0.85, 0.9, 1)
      lg.setLineWidth(3)
      local m = sin(S.t * 4) * 30
      lg.line(dm + 14, 680, dm + 40, 630 - m)
      lg.setColor(1, 0.85, 0.35, 1)
      lg.circle("fill", dm + 40, 630 - m, 6, 10)
    end
    -- Big Bertha rolling through
    local bx = -300 + lt * 30
    if bx > -200 and bx < W + 200 then
      lg.setColor(0.25, 0.25, 0.28, 1)
      lg.circle("fill", bx - 60, 980, 26, 16)
      lg.circle("fill", bx + 60, 980, 26, 16)
      rgba(ORANGE)
      lg.ellipse("fill", bx, 860, 80, 120, 40)
      lg.setColor(0.97, 0.95, 0.88, 1)
      lg.ellipse("fill", bx + 6, 860, 66, 106, 40)
      L.longhorn_head(bx + 6, 860, 0.5, ORANGE, 1)
      lg.setColor(0.6, 0.45, 0.25, 1)
      lg.setLineWidth(4)
      for i = -2, 2 do lg.line(bx - 40, 860 + i * 40, bx - 70, 860 + i * 36) end
      if floor(S.t * 2) % 2 == 0 then C.fx.glow(bx, 860, 140, 140, 1, 0.6, 0.2, 0.15) end
      G:text("BIG BERTHA", bx - 100, 720, 22, {1, 0.85, 0.5}, 1, "center", 200)
    end
  else
    -- from above: the band forms TEXAS on the field
    G:gradient(0, 0, W, H, {0.22, 0.52, 0.2}, {0.18, 0.45, 0.16})
    lg.setColor(1, 1, 1, 0.7)
    for i = 0, 10 do lg.rectangle("fill", 0, 60 + i * 86, W, 3) end
    local k = ease((lt - 40) / 14)
    for i, p in ipairs(S.form) do
      local x, y = lerp(p[1], p[3], k), lerp(p[2], p[4], k)
      x = x + sin(S.t * 6 + i) * 1.5 * (1 - k)
      rgba(ORANGE)
      lg.circle("fill", x, y, 9, 10)
      lg.setColor(1, 1, 1, 1)
      lg.circle("fill", x, y, 4, 8)
    end
    if k >= 1 then C.fx.glow(384, 500, 380, 160, 1, 0.55, 0.15, 0.12 + 0.06 * sin(S.t * 4)) end
  end
end

function D.smokey(lt, len)
  G:gradient(0, 0, W, 520, {0.25, 0.5, 0.9}, {0.75, 0.85, 1})
  lg.setColor(1, 1, 1, 1)
  lg.draw(S.stands, 0, 300)
  G:gradient(0, 600, W, H, {0.25, 0.55, 0.22}, {0.2, 0.48, 0.18})
  lg.setColor(1, 1, 1, 0.8)
  for i = 0, 6 do lg.rectangle("fill", 0, 640 + i * 60, W, 3) end
  if lt < 30 then
    -- Smokey: the cannon on its carriage, the Texas Cowboys beside it
    local x, y = 300, 860
    lg.setColor(0.35, 0.22, 0.12, 1)
    lg.circle("fill", x - 50, y + 40, 46, 24)
    lg.setColor(0.55, 0.38, 0.2, 1)
    lg.setLineWidth(5)
    for i = 0, 7 do
      local a = i * pi / 4 + S.t * 0.1
      lg.line(x - 50, y + 40, x - 50 + cos(a) * 44, y + 40 + sin(a) * 44)
    end
    local rec = (lt % 10) < 0.4 and (1 - (lt % 10) / 0.4) or 0
    lg.push()
    lg.translate(x - 30, y + 10)
    lg.rotate(-0.45 - rec * 0.1)
    lg.setColor(0.18, 0.18, 0.2, 1)
    lg.rectangle("fill", -30, -16, 190, 32, 12, 12, 8)
    rgba(ORANGE)
    lg.rectangle("fill", -10, -18, 40, 36)
    lg.pop()
    lg.setColor(0.97, 0.95, 0.88, 1)
    lg.rectangle("fill", x - 90, y + 80, 140, 26, 4, 4, 4)
    G:text("SMOKEY", x - 90, y + 82, 20, {0.6, 0.25, 0.05}, 1, "center", 140)
    for i = 0, 2 do
      local cx = x + 130 + i * 50
      lg.setColor(0.97, 0.95, 0.9, 1)
      lg.rectangle("fill", cx - 10, y - 10, 20, 40, 4, 4, 4)
      lg.setColor(0.4, 0.25, 0.12, 1)
      lg.rectangle("fill", cx - 9, y + 30, 8, 34)
      lg.rectangle("fill", cx + 1, y + 30, 8, 34)
      lg.setColor(0.9, 0.72, 0.58, 1)
      lg.circle("fill", cx, y - 18, 8, 10)
      lg.setColor(0.35, 0.22, 0.12, 1)
      lg.ellipse("fill", cx, y - 24, 16, 4, 12)
      lg.rectangle("fill", cx - 7, y - 36, 14, 12, 3, 3, 4)
    end
    if rec > 0.9 then C.fx.glow(x + 150, y - 70, 120, 120, 1, 0.9, 0.6, 0.8) end
  else
    -- the flag run: the giant Lone Star flag across the field
    local fx = lerp(-700, W + 80, clamp((lt - 31) / 30, 0, 1))
    S.flag:draw(fx, 620, 640, 300, S.t, 0.85, {1, 1, 1})
    for i = 0, 15 do
      local px = fx + 30 + i * 40
      if px > -20 and px < W + 20 then
        local st = sin(S.t * 10 + i) * 5
        lg.setColor(0.97, 0.97, 0.95, 1)
        lg.rectangle("fill", px - 4, 940 + st, 8, 40)
        lg.setColor(0.2, 0.2, 0.25, 1)
        lg.rectangle("fill", px - 4, 980, 3, 30 + st)
        lg.rectangle("fill", px + 1, 980, 3, 30 - st)
      end
    end
  end
end

function D.hookem(lt, len)
  G:gradient(0, 0, W, H, {0.08, 0.06, 0.12}, {0.2, 0.12, 0.08})
  -- the stands, the wave rolling through them
  lg.setColor(1, 1, 1, 1)
  lg.draw(S.crowd, 0, 150)
  local wave = (S.t * 0.35) % 1.4 - 0.2
  lg.setBlendMode("add")
  lg.setColor(1, 0.7, 0.3, 0.25)
  lg.rectangle("fill", wave * W - 50, 150, 100, 520)
  lg.setBlendMode("alpha")
  -- the card stunt: TEXAS in white on orange, card by card
  local k = clamp((lt - 4) / 6, 0, 1)
  if lt > 4 then
    local cell = 13
    local n = 0
    for _, c in ipairs(S.stunt) do
      n = n + 1
      if n / #S.stunt <= k then
        if c[3] then rgba(WHITE) else rgba(ORANGE_HI) end
        lg.rectangle("fill", c[1], c[2], cell - 2, cell - 2)
      end
    end
  end
  -- the hand and the chant
  if lt > 14 then
    local a = clamp((lt - 14) / 1.5, 0, 1)
    local pump = abs(sin(S.t * 3.2)) * 18
    C.fx.glow(384, 820 - pump, 220, 200, 1, 0.5, 0.1, 0.35 * a)
    hookem_hand(384, 840 - pump, 1.3, ORANGE_HI, a)
  end
  if lt > 22 then
    local beat = floor((lt - 22) / 1.1) % 2
    G:caption(beat == 0 and "TEXAS!" or "FIGHT!", 560, 80, beat == 0 and 0xff8c1a or 0xffffff, clamp((lt - 22) * 2, 0, 1))
  end
end

-- ------------------------------------------------------------------ the drive, from above
-- A play: {kind, gain (yards)}. 25 + 9 + 18 + 4 + 15 + 7 = 78: the last one, 22 yards, is the touchdown.
local PLAYS = {{"run", 9}, {"pass", 18, -18}, {"run", 4}, {"pass", 15, 16}, {"run", 7}, {"pass", 22, -6}}
local PLAY_T = 9.5
local YD = 14                                      -- pixels a yard

local function drive_state(lt)
  local los, i = 25, 1
  local t = lt - 4
  for k, p in ipairs(PLAYS) do
    if t < PLAY_T then return los, p, t, k end
    los = los + p[2]
    t = t - PLAY_T
    i = k
  end
  return los, nil, t, #PLAYS + 1
end

function D.drive(lt, len)
  local los, play, pt, idx = drive_state(lt)
  local abbr, ocol = opp()
  -- the camera keeps the line about two thirds down
  local cam = (play and los or 100) + 12
  local function sy(yd) return 640 - (yd - (cam - 12)) * YD end
  local function sx(xyd) return 384 + xyd * YD end
  G:gradient(0, 0, W, H, {0.2, 0.5, 0.2}, {0.17, 0.44, 0.17})
  -- stripes, yard lines, numbers, the end zone
  for yd = 0, 100, 5 do
    local y = sy(yd)
    if y > -20 and y < H + 20 then
      lg.setColor(1, 1, 1, yd % 10 == 0 and 0.85 or 0.5)
      lg.rectangle("fill", 10, y - 1, W - 20, 3)
      if yd % 10 == 0 and yd > 0 and yd < 100 then
        G:text(tostring(yd <= 50 and yd or 100 - yd), 20, y - 14, 26, {1, 1, 1}, 0.8, "left", 60)
        G:text(tostring(yd <= 50 and yd or 100 - yd), W - 80, y - 14, 26, {1, 1, 1}, 0.8, "right", 60)
      end
    end
  end
  local ez = sy(100)
  if ez > -200 then
    rgba(ORANGE)
    lg.rectangle("fill", 10, ez - 140, W - 20, 140)
    G:text("TEXAS", 0, ez - 100, 64, {1, 1, 1}, 1)
  end
  -- the first-down line
  if play then
    lg.setColor(1, 0.85, 0.1, 0.8)
    lg.rectangle("fill", 10, sy(los + 10) - 2, W - 20, 4)
    lg.setColor(0.2, 0.5, 1, 0.8)
    lg.rectangle("fill", 10, sy(los) - 2, W - 20, 4)
  end
  -- the players: 11 a side, where this play has them
  local snap = 1.2
  local k = clamp((pt - snap) / 3.2, 0, 1)
  local kind, gain, wx = play and play[1], play and play[2] or 0, play and play[3] or 0
  local carrier
  local off, def = {}, {}
  local lines = {-6, -3, 0, 3, 6}
  for _, x in ipairs(lines) do off[#off + 1] = {x * 0.5, -0.5} end
  off[#off + 1] = {0, -5}
  off[#off + 1] = {0, -7.5}
  off[#off + 1] = {-18, -1}
  off[#off + 1] = {18, -1}
  off[#off + 1] = {6, -1}
  off[#off + 1] = {-12, -1.5}
  for _, x in ipairs({-4.5, -1.5, 1.5, 4.5}) do def[#def + 1] = {x, 1} end
  for _, x in ipairs({-6, 0, 6}) do def[#def + 1] = {x, 5} end
  def[#def + 1] = {-18, 6}
  def[#def + 1] = {18, 6}
  def[#def + 1] = {-8, 13}
  def[#def + 1] = {8, 13}
  local cx, cy = 0, -7.5
  if play and k > 0 then
    if kind == "run" then
      carrier = 7
      cx, cy = sin(k * 3) * 2, lerp(-7.5, gain, ease(k))
      off[7] = {cx, cy}
    else
      carrier = wx > 0 and 9 or 8
      off[6] = {0, -5 - min(1, k * 3) * 3}
      local wr = off[carrier]
      local catch = 0.55
      local ry = lerp(-1, gain, ease(k))
      local rx = wr[1] + (k > 0.3 and (wx - wr[1]) * ease((k - 0.3) / 0.7) or 0)
      off[carrier] = {rx, ry}
      cx, cy = rx, ry
      if k < catch then
        -- the ball in the air, from the quarterback to where the catch will be
        local f = clamp((k - 0.15) / (catch - 0.15), 0, 1)
        local bx = lerp(0, lerp(-1, gain, ease(catch)), f)
        local bxx = lerp(0, wr[1] + (wx - wr[1]) * ease(clamp((catch - 0.3) / 0.7, 0, 1)), f)
        S.ball = {bxx, bx, 1 + sin(f * pi) * 0.8}
      else
        S.ball = nil
      end
    end
    -- the line pushes, the defence goes to the ball
    for i = 1, 5 do off[i][2] = off[i][2] + k * 1.2 end
    for i, d in ipairs(def) do
      local kk = clamp(k * (1.1 + (i % 4) * 0.15), 0, 1)
      def[i] = {lerp(d[1], cx + sin(i) * 1.5, kk * 0.8), lerp(d[2], cy + 1 + cos(i) * 1.2, kk * 0.8)}
    end
  end
  for i, p in ipairs(def) do
    rgba(ocol)
    lg.circle("fill", sx(p[1]), sy(los + p[2]), 11, 14)
    lg.setColor(0.15, 0.15, 0.18, 1)
    lg.circle("fill", sx(p[1]), sy(los + p[2]), 4, 8)
  end
  for i, p in ipairs(off) do
    rgba(ORANGE_HI)
    lg.circle("fill", sx(p[1]), sy(los + p[2]), 11, 14)
    lg.setColor(1, 1, 1, 1)
    lg.circle("fill", sx(p[1]), sy(los + p[2]), 4.5, 8)
  end
  -- the ball
  local bx, by, bs
  if S.ball and play and kind == "pass" and k < 0.55 then
    bx, by, bs = S.ball[1], S.ball[2], S.ball[3]
  elseif play then
    local c = off[carrier or 6]
    bx, by, bs = c[1] + 0.6, c[2] + 0.4, 1
  end
  if bx then
    lg.setColor(0, 0, 0, 0.25)
    lg.ellipse("fill", sx(bx), sy(los + by) + 4 * bs, 6, 3, 10)
    lg.setColor(0.5, 0.28, 0.12, 1)
    lg.ellipse("fill", sx(bx), sy(los + by) - (bs - 1) * 16, 6 * bs, 4 * bs, 10)
  end
  -- down and distance, the score
  local downs = {"1ST", "1ST", "1ST", "1ST", "1ST", "1ST"}
  lg.setColor(0.02, 0.02, 0.06, 0.75)
  lg.rectangle("fill", 0, 0, W, 52)
  local us = idx > #PLAYS and (lt > (#PLAYS * PLAY_T + 10) and 7 or 6) or 0
  G:text(string.format("TEXAS  %d", us), 18, 12, 28, ORANGE_HI, 1, "left", 300)
  G:text(string.format("%s  0", abbr), W - 318, 12, 28, ocol, 1, "right", 300)
  if play then
    local spot = los <= 50 and ("TEX " .. los) or (abbr .. " " .. (100 - los))
    G:text(downs[idx] .. " & 10  ·  " .. spot, 0, 12, 24, {1, 1, 1}, 0.9)
  else
    local a = clamp((lt - (#PLAYS * PLAY_T + 4)) * 2, 0, 1)
    G:caption("TOUCHDOWN TEXAS!", 420, 64, 0xff8c1a, a)
  end
end

function D.redriver(lt, len)
  G:gradient(0, 0, W, 600, {0.2, 0.42, 0.85}, {0.85, 0.85, 0.95})
  -- the Texas Star turning, Big Tex waving
  local wx, wy, wr = 600, 300, 170
  lg.setColor(0.85, 0.85, 0.9, 1)
  lg.setLineWidth(3)
  lg.circle("line", wx, wy, wr, 48)
  for i = 0, 15 do
    local a = i / 16 * 2 * pi + S.t * 0.15
    lg.line(wx, wy, wx + cos(a) * wr, wy + sin(a) * wr)
    local c = ({{1, 0.3, 0.3}, {1, 0.85, 0.2}, {0.3, 0.6, 1}, {0.4, 0.85, 0.4}})[i % 4 + 1]
    rgba(c)
    lg.rectangle("fill", wx + cos(a) * wr - 8, wy + sin(a) * wr, 16, 14, 3, 3, 4)
    lg.setColor(0.85, 0.85, 0.9, 1)
  end
  lg.polygon("fill", wx - 8, wy, wx + 8, wy, wx + 60, 600, wx - 60, 600)
  -- Big Tex: hat, plaid shirt, jeans, boots, a hand up
  local bx = 170
  lg.setColor(0.2, 0.3, 0.6, 1)
  lg.rectangle("fill", bx - 40, 400, 34, 200)
  lg.rectangle("fill", bx + 6, 400, 34, 200)
  lg.setColor(0.55, 0.3, 0.15, 1)
  lg.rectangle("fill", bx - 44, 580, 42, 20, 6, 6, 4)
  lg.rectangle("fill", bx + 2, 580, 42, 20, 6, 6, 4)
  lg.setColor(0.8, 0.2, 0.2, 1)
  lg.rectangle("fill", bx - 50, 250, 100, 160, 10, 10, 6)
  lg.setColor(1, 0.9, 0.85, 0.5)
  for i = 0, 4 do lg.rectangle("fill", bx - 50 + i * 22, 250, 4, 160) lg.rectangle("fill", bx - 50, 262 + i * 30, 100, 4) end
  local wave = sin(S.t * 2) * 0.3
  lg.setColor(0.8, 0.2, 0.2, 1)
  lg.push()
  lg.translate(bx + 46, 262)
  lg.rotate(-1.9 + wave)
  lg.rectangle("fill", 0, -12, 90, 24, 8, 8, 6)
  lg.setColor(0.95, 0.78, 0.62, 1)
  lg.circle("fill", 96, 0, 14, 12)
  lg.pop()
  lg.setColor(0.8, 0.2, 0.2, 1)
  lg.rectangle("fill", bx - 76, 262, 30, 90, 8, 8, 6)
  lg.setColor(0.95, 0.78, 0.62, 1)
  lg.circle("fill", bx, 220, 34, 20)
  lg.setColor(0.2, 0.15, 0.1, 1)
  lg.circle("fill", bx - 12, 214, 4, 8)
  lg.circle("fill", bx + 12, 214, 4, 8)
  lg.setLineWidth(3)
  lg.arc("line", "open", bx, 226, 14, 0.3, pi - 0.3, 12)
  lg.setColor(0.97, 0.95, 0.88, 1)
  lg.ellipse("fill", bx, 190, 80, 14, 24)
  lg.rectangle("fill", bx - 40, 140, 80, 50, 14, 14, 8)
  if L.window(lt, 6, 16, 0.5) > 0 then
    lg.setColor(1, 1, 1, 0.95)
    lg.rectangle("fill", bx + 40, 110, 210, 50, 14, 14, 8)
    lg.polygon("fill", bx + 50, 160, bx + 70, 160, bx + 40, 180)
    G:text("HOWDY, FOLKS!", bx + 40, 122, 26, {0.6, 0.15, 0.1}, 1, "center", 210)
  end
  -- the stands: half burnt orange, half crimson
  G:gradient(0, 600, W / 2, 760, ORANGE, {0.55, 0.25, 0.0})
  G:gradient(W / 2, 600, W, 760, {0.6, 0.08, 0.12}, {0.4, 0.05, 0.08})
  lg.setColor(1, 1, 1, 0.12)
  for i = 0, 40 do lg.rectangle("fill", (i * 37) % W, 610 + (i * 23) % 140, 6, 6) end
  G:gradient(0, 760, W, H, {0.25, 0.55, 0.22}, {0.2, 0.48, 0.18})
  -- the score, quarter by quarter; the Golden Hat at the end
  local scores = {{0, 0, "KICKOFF"}, {7, 0, "1ST QUARTER"}, {14, 10, "2ND QUARTER"}, {21, 17, "3RD QUARTER"}, {31, 24, "FINAL"}}
  local q = clamp(floor((lt - 4) / 12) + 1, 1, #scores)
  local s = scores[q]
  lg.setColor(0.02, 0.02, 0.06, 0.8)
  lg.rectangle("fill", 134, 790, 500, 110, 12, 12, 8)
  G:text(s[3], 134, 800, 22, {1, 0.85, 0.4}, 1, "center", 500)
  G:text(string.format("TEXAS  %d", s[1]), 150, 838, 40, ORANGE_HI, 1, "left", 240)
  G:text(string.format("OU  %d", s[2]), 380, 838, 40, {0.85, 0.2, 0.25}, 1, "right", 240)
  if q == #scores then
    local k = clamp((lt - 54) / 2, 0, 1)
    local hy = 700 - k * 90
    C.fx.glow(384, hy, 140, 90, 1, 0.85, 0.3, 0.5 * k)
    lg.setColor(1, 0.82, 0.25, k)
    lg.ellipse("fill", 384, hy, 90, 18, 24)
    lg.rectangle("fill", 334, hy - 50, 100, 50, 20, 20, 8)
    lg.setColor(0.6, 0.45, 0.2, k)
    lg.rectangle("fill", 334, hy - 16, 100, 8)
    G:plate("THE GOLDEN HAT STAYS IN AUSTIN", 940, 26, 0xffd23f, k)
  end
end

function D.tower(lt, len)
  G:gradient(0, 0, W, 800, {0.02, 0.02, 0.08}, {0.12, 0.06, 0.16})
  for i, s in ipairs(S.stars) do
    lg.setColor(1, 1, 0.9, 0.5 + 0.5 * sin(S.t * (1 + i % 3) + i))
    lg.rectangle("fill", s[1], s[2], 2, 2)
  end
  tower(384, 800, 1.2, true)
  L.live_oak(90, 820, 1.2, S.t)
  L.live_oak(680, 820, 1.1, S.t + 1)
  G:gradient(0, 800, W, H, {0.06, 0.08, 0.05}, {0.03, 0.04, 0.03})
  -- the crowd on the South Mall, horns up
  for i = 0, 15 do
    fan(30 + i * 48, 1000 - (i % 2) * 14, 1.1, {0.08, 0.06, 0.06}, S.t + i, true)
  end
  local a = L.window(lt, 6, len - 2, 1.5)
  local g = ut.game
  if g and g.state == "post" and g.us and g.them and g.us > g.them then
    G:plate(string.format("TODAY: TEXAS %d, %s %d", g.us, g.opp_abbr, g.them), 150, 32, 0xffd23f, a)
  else
    G:plate("THE EYES OF TEXAS ARE UPON YOU", 150, 30, 0xffffff, a)
  end
end

-- ------------------------------------------------------------------ the scorebug (game days)
local function bug_lines()
  local g = ut.game
  if not g or not g.kickoff then return nil end
  local now = ut.now()
  local line, line2
  local where = (g.home and "VS " or "AT ") .. string.upper(g.opp_loc ~= "" and g.opp_loc or g.opp)
  if g.state == "in" then
    line = string.format("TEXAS %d   %s %d", g.us or 0, g.opp_abbr, g.them or 0)
    line2 = string.upper(g.detail) .. (g.net and ("  ·  ON " .. g.net) or "")
  elseif g.state == "post" and now - g.kickoff < 8 * 3600 then
    line = string.format("FINAL: TEXAS %d   %s %d", g.us or 0, g.opp_abbr, g.them or 0)
    line2 = (g.us or 0) > (g.them or 0) and "HOOK 'EM!" or "NEXT WEEK"
  elseif g.state == "pre" and g.kickoff - now < 7 * 86400 then
    line = "NEXT: " .. where
    line2 = (ut.countdown(now) or string.upper(os.date("%a %b %d  %I:%M %p", g.kickoff)):gsub(" 0", " ")) ..
            (g.net and ("  ·  " .. g.net) or "")
  else
    return nil
  end
  return line, line2
end

local function scorebug()
  local line, line2 = bug_lines()
  if not line then return end
  local y = 62
  local sc, _, _ = scene_at(S.t)
  if sc[2] == "drive" then y = H - 130 end
  lg.setColor(0.02, 0.02, 0.06, 0.78)
  lg.rectangle("fill", 40, y, W - 80, 66, 14, 14, 8)
  rgba(ORANGE)
  lg.rectangle("fill", 40, y, 10, 66, 4, 4, 4)
  G:text(line, 50, y + 6, 26, {1, 1, 1}, 1, "center", W - 100)
  G:text(line2, 50, y + 38, 20, {1, 0.75, 0.4}, 1, "center", W - 100)
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

local function letter_points(word, cell, x0, y0)
  local GL = {
    T = {"XXXXX", "..X..", "..X..", "..X..", "..X..", "..X..", "..X.."},
    E = {"XXXXX", "X....", "X....", "XXXX.", "X....", "X....", "XXXXX"},
    X = {"X...X", "X...X", ".X.X.", "..X..", ".X.X.", "X...X", "X...X"},
    A = {".XXX.", "X...X", "X...X", "XXXXX", "X...X", "X...X", "X...X"},
    S = {".XXXX", "X....", "X....", ".XXX.", "....X", "....X", "XXXX."},
  }
  local pts = {}
  for i = 1, #word do
    local g = GL[word:sub(i, i)]
    for r = 1, 7 do
      for c = 1, 5 do
        if g[r]:sub(c, c) == "X" then pts[#pts + 1] = {x0 + ((i - 1) * 6 + c - 1) * cell, y0 + (r - 1) * cell} end
      end
    end
  end
  return pts
end

function M.start(seed, at)
  M.stop()
  G:begin(seed)
  S = {t = at or 0}
  G.t, G.prev = S.t, S.t - 0.001
  local R = G.R
  S.flag = G:cloth(L.paint_texas, 600, 400)
  -- the stands (a band of crowd: orange and white dots), painted once
  S.stands = G:canvas(W, 300, function(w, h)
    lg.setColor(0.35, 0.33, 0.38, 1)
    lg.rectangle("fill", 0, 0, w, h)
    for i = 1, 2400 do
      local c = R:random() < 0.75 and ORANGE_HI or WHITE
      lg.setColor(c[1], c[2], c[3], 0.6 + R:random() * 0.4)
      lg.rectangle("fill", R:random() * w, R:random() * h, 4, 5)
    end
  end)
  S.crowd = G:canvas(W, 520, function(w, h)
    lg.setColor(0.25, 0.2, 0.22, 1)
    lg.rectangle("fill", 0, 0, w, h)
    for i = 1, 5000 do
      local c = R:random() < 0.8 and ORANGE_HI or WHITE
      lg.setColor(c[1] * 0.8, c[2] * 0.8, c[3] * 0.8, 0.7 + R:random() * 0.3)
      lg.rectangle("fill", R:random() * w, R:random() * h, 5, 6)
    end
  end)
  -- the card stunt: a grid over the stands, TEXAS in white
  S.stunt = {}
  local word = letter_points("TEXAS", 13, 0, 0)
  local on = {}
  for _, p in ipairs(word) do on[floor(p[1] / 13) .. ":" .. floor(p[2] / 13)] = true end
  local gx0, gy0 = 384 - 29 * 13 / 2 - 26, 300
  for r = -2, 8 do
    for c = -2, 30 do
      S.stunt[#S.stunt + 1] = {gx0 + c * 13, gy0 + r * 13, on[c .. ":" .. r] and true or false}
    end
  end
  -- the band's formation: from a block to TEXAS
  S.form = {}
  local tp = letter_points("TEXAS", 24, 384 - 29 * 24 / 2, 420)
  for i, p in ipairs(tp) do
    local bx, by = 160 + ((i - 1) % 12) * 38, 220 + floor((i - 1) / 12) * 40
    S.form[i] = {bx, by, p[1], p[2]}
  end
  S.stars = {}
  for i = 1, 90 do S.stars[i] = {R:random() * W, R:random() * 700} end
  for _, s in ipairs(SCENES) do if s[4] then G:label(s[4], 56, 0xffffff) end end
  for _, l in ipairs({{"PARTYCADE", 54, 0xff4fd8}, {"PRESENTS", 26, 0x6ef0c8}, {"TEXAS", 96, 0xff8c1a},
                      {"LONGHORNS", 54, 0xffffff}, {"TEXAS!", 80, 0xff8c1a}, {"FIGHT!", 80, 0xffffff},
                      {"TOUCHDOWN TEXAS!", 64, 0xff8c1a}, {"THE GOLDEN HAT STAYS IN AUSTIN", 26, 0xffd23f},
                      {"THE EYES OF TEXAS ARE UPON YOU", 30, 0xffffff}, {"THE MAIN BUILDING  ·  THE TOWER", 28, 0xffffff}}) do
    G:label(l[1], l[2], l[3])
  end
end

function M.act() return S and scene_at(S.t)[2] or "open" end

function M.music()
  if S and S.celebrate then return "lh_drive" end
  return S and scene_at(S.t)[3] or "lh_gameday"
end

local function celebrate(points)
  S.celebrate = {t = 0, pts = points}
  C.sfx("boom")
  C.sfx("cheer")
  S.celebrate.next_fw = 0
end

function M.update(dt)
  if not S then return false end
  G:step(dt)
  S.t = G.t
  local sc, lt = scene_at(S.t)
  -- Smokey fires every ten seconds in its scene; the drive's touchdown; the tower's fireworks
  if sc[2] == "smokey" and lt < 30 and floor((lt - dt) / 10) ~= floor(lt / 10) then
    C.sfx("boom")
    for i = 1, 30 do G:puff(450 + G.R:random() * 60, 760 + G.R:random() * 30, {0.92, 0.92, 0.95}, 20 + G.R:random() * 30,
                            40 + G.R:random() * 60, 3, 14, 0.6) end
  end
  if sc[2] == "drive" then
    local k = #PLAYS * PLAY_T + 4
    if lt - dt < k and lt >= k then
      C.sfx("cheer") C.sfx("boom")
      for i = 1, 5 do G:rocket(150 + i * 100, 200 + G.R:random() * 150, {from = 1024, colours = {ORANGE_HI, WHITE}}) end
    end
  end
  if (sc[2] == "tower" and lt > 4) or (sc[2] == "redriver" and lt > 54 and lt < 80) then
    S.fw = (S.fw or 0) - dt
    if S.fw <= 0 then
      S.fw = 0.7 + G.R:random() * 0.9
      G:rocket(150 + G.R:random() * 470, 100 + G.R:random() * 220, {from = 820, colours = {ORANGE_HI, WHITE, {1, 0.75, 0.3}}})
    end
  end
  if sc[2] == "campus" and G.R:random() < dt * 4 then
    G:puff(70 + (G.R:random() > 0.5 and 570 or 0), 920, {0.85, 0.85, 0.88}, 40, 8, 2.5, 8, 0.35)
  end
  -- the real game: our score went up
  if ut.scored then
    celebrate(ut.scored)
    ut.scored = nil
  end
  local c = S.celebrate
  if c then
    c.t = c.t + dt
    c.next_fw = c.next_fw - dt
    if c.next_fw <= 0 and c.t < 8 then
      c.next_fw = 0.4
      G:rocket(120 + G.R:random() * 520, 120 + G.R:random() * 260, {from = 1024, colours = {ORANGE_HI, WHITE}})
    end
    if c.t > 12 then S.celebrate = nil end
  end
  return S.t >= LEN
end

function M.draw()
  if not S then return end
  local sc, lt, len = scene_at(S.t)
  D[sc[2]](lt, len)
  G:draw_back()
  G:draw_front()
  if sc[4] and sc[2] ~= "drive" then
    G:plate(sc[4], bug_lines() and 150 or 30, 56, 0xffffff, L.window(lt, 1.5, 9, 1))
  end
  if sc[5] then
    local b = L.window(lt, 2, len - 1.5, 1)
    lg.setColor(0.02, 0.02, 0.06, 0.55 * b)
    lg.rectangle("fill", 0, H - 50, W, 50)
    G:text(sc[5], 0, H - 38, 20, {1, 0.8, 0.55}, b)
  end
  if sc[2] ~= "open" then scorebug() end
  local c = S.celebrate
  if c then
    local a = min(1, c.t * 3, (12 - c.t) / 1.5)
    lg.setColor(0.75, 0.34, 0, 0.35 * a)
    lg.rectangle("fill", 0, 0, W, H)
    G:caption(c.pts >= 6 and "TOUCHDOWN TEXAS!" or (c.pts == 3 and "FIELD GOAL TEXAS!" or "TEXAS SCORES!"), 440, 64, 0xff8c1a, a,
              1 + 0.08 * abs(sin(c.t * 5)))
  end
  local f = 1 - min(lt / 1.2, (len - lt) / 1.2, 1)
  if f > 0 then
    lg.setColor(0, 0, 0, f)
    lg.rectangle("fill", 0, 0, W, H)
  end
end

return M
