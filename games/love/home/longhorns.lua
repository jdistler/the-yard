-- Longhorns: game day on the Forty Acres. Home's show for the University of Texas (our own drawings, no
-- official marks), thirteen minutes:
--   0:00  STARLIGHT PRESENTS ... TEXAS LONGHORNS                                  (Game Day)
--   0:10  Game day on the Forty Acres: the Tower at sunrise, live oaks, tailgates, Bevo, fans with Hook 'em
--   1:20  The season on the video board: every game, the results, the record, the next kickoff (utgame.season)
--                                                                                  (Scoreboard)
--   2:20  The Longhorn Band: marching in, Big Bertha rolling past; then from above, the band spells TEXAS
--                                                                                  (Burnt Orange March)
--   3:30  Smokey and the flag: the cannon, the flag run, the Hook 'Em Herd, the team out of the tunnel (Drumline)
--   4:40  Hook 'em: the stands, a card stunt (TEXAS), the hand sign, TEXAS! FIGHT!    (Hook 'Em)
--   5:40  The drive: a drive down the field from above, play by play, to a touchdown   (The Drive)
--   7:05  Legends: the national titles and the Heismans on the stadium; then the Rose Bowl, Jan 4, 2006, from
--         above: fourth and five from the 8, the run to the right pylon, 41-38         (Legends)
--   8:40  The Red River Rivalry: the State Fair, Big Tex, the Texas Star, the Golden Hat stays in Austin
--                                                                                  (State Fair)
--  10:10  The Hex Rally: 1941's fortune teller, red candles on the Main Mall the week of the A&M game (The Hex)
--  11:20  The Tower lit orange: an orange top for a win (the real one, when there is one); all orange with
--         the "1" for a national title; fireworks                                   (Tower Glow)
-- On game days (utgame.lua) a scorebug rides along: the countdown, the live score, the final; when Texas
-- scores during the game, the show stops for it: TOUCHDOWN TEXAS, Smokey, fireworks.
local lg = love.graphics
local L = require("showlib")
local ut = require("utgame")
local M = {}
local C, G
local W, H = 768, 1024
local LEN = 770
M.LEN = LEN
local sin, cos, floor, min, max, abs, pi = math.sin, math.cos, math.floor, math.min, math.max, math.abs, math.pi
local clamp, ease, lerp, mix = L.clamp, L.ease, L.lerp, L.mix
local function prog(lt, a, b) return ease((lt - a) / (b - a)) end
local function lin(lt, a, b) return clamp((lt - a) / (b - a), 0, 1) end
local ORANGE = {0.75, 0.34, 0.0}
local ORANGE_HI = {1.0, 0.5, 0.1}
local WHITE = {0.97, 0.97, 0.95}
local STONE = {0.9, 0.84, 0.7}

local SCENES = {
  {0, "open", "lh_gameday"},
  {10, "campus", "lh_gameday", "GAME DAY", "THE FORTY ACRES  ·  AUSTIN"},
  {80, "season", "lh_board", "THE SEASON", "EVERY GAME  ·  ON THE BIG BOARD"},
  {140, "band", "lh_march", "THE LONGHORN BAND", "THE SHOWBAND OF THE SOUTHWEST  ·  BIG BERTHA"},
  {210, "smokey", "lh_drumline", "SMOKEY AND THE FLAG", "THE CANNON  ·  THE FLAG RUN  ·  THE HOOK 'EM HERD"},
  {280, "hookem", "lh_hookem", "HOOK 'EM", "TEXAS!  FIGHT!"},
  {340, "drive", "lh_drive", "THE DRIVE", "FIRST AND TEN  ·  THE LONGHORNS' BALL"},
  {425, "legends", "lh_legends", "LEGENDS", "FOUR TITLES  ·  TWO HEISMANS  ·  ONE RUN TO THE RIGHT PYLON"},
  {520, "redriver", "lh_fair", "RED RIVER RIVALRY", "THE COTTON BOWL  ·  THE STATE FAIR OF TEXAS"},
  {610, "hex", "lh_hex", "THE HEX RALLY", "RED CANDLES  ·  THE MAIN MALL  ·  SINCE 1941"},
  {680, "tower", "lh_tower", "THE TOWER LIT ORANGE", "HOOK 'EM HORNS"},
}
M.SEGMENTS = {}
for _, s in ipairs(SCENES) do if s[4] then M.SEGMENTS[#M.SEGMENTS + 1] = {s[1], s[4]} end end
M.THUMB = 6

local S
local art_for                      -- (below: the pictures, a scene at a time)
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
-- mode: nil (by day), "dark" (at night, unlit), "win" (an orange top over a white shaft: a football win), "one"
-- (all orange, a "1" in the windows: a national title)
local function tower(x, base, s, mode)
  local lit = mode == "win" or mode == "one"
  local LIT_WHITE = {1, 0.97, 0.9}
  local top, shaft, sh
  if mode == "one" then top, shaft, sh = mix(STONE, ORANGE_HI, 0.85), mix(STONE, ORANGE_HI, 0.85), mix(STONE, ORANGE, 0.9)
  elseif mode == "win" then top, shaft, sh = mix(STONE, ORANGE_HI, 0.85), LIT_WHITE, mix(STONE, ORANGE, 0.9)
  elseif mode == "dark" then top, shaft, sh = mix(STONE, {0.1, 0.1, 0.16}, 0.75), mix(STONE, {0.1, 0.1, 0.16}, 0.75), {0.12, 0.12, 0.17}
  else top, shaft, sh = STONE, STONE, {0.75, 0.68, 0.55} end
  -- the Main Building in front
  rgba(sh)
  lg.rectangle("fill", x - 190 * s, base - 70 * s, 380 * s, 70 * s)
  if mode == "dark" then lg.setColor(0.2, 0.12, 0.12, 1) else lg.setColor(0.62, 0.28, 0.2, 1) end
  lg.polygon("fill", x - 200 * s, base - 70 * s, x + 200 * s, base - 70 * s, x + 180 * s, base - 92 * s, x - 180 * s, base - 92 * s)
  -- the shaft
  rgba(shaft)
  lg.rectangle("fill", x - 34 * s, base - 380 * s, 68 * s, 300 * s)
  if mode == "win" then lg.setColor(0.85, 0.8, 0.7, 1) else rgba(sh) end
  for i = 0, 3 do lg.rectangle("fill", x - 26 * s + i * 16 * s, base - 370 * s, 4 * s, 270 * s) end
  -- the clock stage, the colonnade, the cupola
  rgba(top)
  lg.rectangle("fill", x - 40 * s, base - 430 * s, 80 * s, 50 * s)
  if mode == "dark" then lg.setColor(0.5, 0.48, 0.4, 1)
  else lg.setColor(lit and 1 or 0.95, lit and 0.9 or 0.92, lit and 0.7 or 0.85, 1) end
  lg.circle("fill", x, base - 405 * s, 15 * s, 20)
  lg.setColor(0.2, 0.18, 0.15, 1)
  lg.setLineWidth(2 * s)
  local tt = os.time()
  local hh, mm = tonumber(os.date("%I", tt)), tonumber(os.date("%M", tt))
  lg.line(x, base - 405 * s, x + sin((hh + mm / 60) / 12 * 2 * pi) * 8 * s, base - 405 * s - cos((hh + mm / 60) / 12 * 2 * pi) * 8 * s)
  lg.line(x, base - 405 * s, x + sin(mm / 60 * 2 * pi) * 12 * s, base - 405 * s - cos(mm / 60 * 2 * pi) * 12 * s)
  rgba(top)
  lg.rectangle("fill", x - 44 * s, base - 440 * s, 88 * s, 10 * s)
  rgba(lit and mix(STONE, ORANGE, 0.9) or sh)
  for i = 0, 5 do lg.rectangle("fill", x - 38 * s + i * 15 * s, base - 476 * s, 6 * s, 36 * s) end
  rgba(top)
  lg.rectangle("fill", x - 44 * s, base - 484 * s, 88 * s, 10 * s)
  lg.rectangle("fill", x - 22 * s, base - 512 * s, 44 * s, 28 * s)
  lg.arc("fill", "pie", x, base - 512 * s, 22 * s, pi, 2 * pi, 16)
  lg.rectangle("fill", x - 2 * s, base - 548 * s, 4 * s, 16 * s)
  if mode == "one" then
    -- the "1" in the windows
    lg.setColor(1, 1, 0.85, 1)
    lg.rectangle("fill", x - 4 * s, base - 360 * s, 10 * s, 220 * s)
    lg.rectangle("fill", x - 16 * s, base - 350 * s, 14 * s, 12 * s)
    lg.rectangle("fill", x - 14 * s, base - 148 * s, 30 * s, 10 * s)
    C.fx.glow(x, base - 300 * s, 160 * s, 300 * s, 1, 0.5, 0.1, 0.35)
  elseif mode == "win" then
    C.fx.glow(x, base - 460 * s, 130 * s, 110 * s, 1, 0.5, 0.1, 0.4)
    C.fx.glow(x, base - 240 * s, 90 * s, 200 * s, 1, 0.95, 0.85, 0.12)
  elseif mode == "dark" then
    -- a few late windows
    lg.setColor(1, 0.85, 0.5, 0.7)
    for i = 0, 5 do lg.rectangle("fill", x - 150 * s + i * 58 * s, base - 46 * s, 10 * s, 14 * s) end
  end
end

-- A fan: walking legs, a torso in the shirt, arms swinging (or a Hook 'em hand up), a head with hair. who picks
-- the skin and hair (else from the shirt and t); y is the ground.
local SKIN = {{0.93, 0.76, 0.62}, {0.78, 0.57, 0.42}, {0.55, 0.37, 0.26}, {0.97, 0.82, 0.7}, {0.42, 0.28, 0.2}}
local HAIR = {{0.15, 0.1, 0.08}, {0.4, 0.26, 0.14}, {0.75, 0.6, 0.35}, {0.08, 0.07, 0.07}, {0.55, 0.3, 0.15}}
local function fan(x, y, s, shirt, t, hook, who)
  who = who or 1                        -- (who must be fixed per person: from the clock, they changed every frame)
  local sk, hr = SKIN[who], HAIR[(who * 3) % 5 + 1]
  local step = sin(t * 8) * 5 * s
  local dark = shirt[1] + shirt[2] + shirt[3] < 0.5            -- (a silhouette in the dark)
  -- legs: jeans, a stride
  if dark then rgba(shirt) else lg.setColor(0.22, 0.27, 0.42, 1) end
  lg.polygon("fill", x - 5 * s, y - 13 * s, x - 1 * s, y - 13 * s, x - 2 * s + step * 0.5, y + 1 * s, x - 6 * s + step * 0.5, y + 1 * s)
  lg.polygon("fill", x + 1 * s, y - 13 * s, x + 5 * s, y - 13 * s, x + 6 * s - step * 0.5, y + 1 * s, x + 2 * s - step * 0.5, y + 1 * s)
  -- the torso, the shirt's shading
  rgba(shirt)
  lg.rectangle("fill", x - 8 * s, y - 32 * s, 16 * s, 21 * s, 4 * s, 4 * s, 6)
  if not dark then
    lg.setColor(0, 0, 0, 0.12)
    lg.rectangle("fill", x + 2 * s, y - 32 * s, 6 * s, 21 * s, 3 * s, 3 * s, 4)
  end
  -- arms: one swinging; the other swinging too, or up in a Hook 'em
  local skin = dark and shirt or sk
  rgba(skin)
  lg.push()
  lg.translate(x - 8 * s, y - 29 * s)
  lg.rotate(step * 0.05 / s)
  lg.rectangle("fill", -3 * s, 0, 4 * s, 15 * s, 2 * s, 2 * s, 4)
  lg.pop()
  if hook then
    local up = abs(sin(t * 3)) * 4 * s
    lg.rectangle("fill", x + 6 * s, y - 50 * s - up, 4 * s, 22 * s, 2 * s, 2 * s, 4)
    lg.rectangle("fill", x + 5 * s, y - 52 * s - up, 6 * s, 6 * s, 2 * s, 2 * s, 4)
    lg.rectangle("fill", x + 5 * s, y - 60 * s - up, 2 * s, 9 * s)
    lg.rectangle("fill", x + 9 * s, y - 59 * s - up, 2 * s, 8 * s)
  else
    lg.push()
    lg.translate(x + 8 * s, y - 29 * s)
    lg.rotate(-step * 0.05 / s)
    lg.rectangle("fill", -1 * s, 0, 4 * s, 15 * s, 2 * s, 2 * s, 4)
    lg.pop()
  end
  -- the head and the hair
  rgba(skin)
  lg.circle("fill", x, y - 38 * s, 6.5 * s, 14)
  if not dark then
    rgba(hr)
    lg.arc("fill", "pie", x, y - 39 * s, 6.8 * s, pi * 1.05, pi * 1.95, 10)
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

-- The cast, Longhorns fans in burnt-orange caps (who: 0 Pac-Man, 1-4 the ghosts); hook: a Hook 'em hand up
local GH = {{1, 0.18, 0.2}, {1, 0.55, 0.85}, {0.25, 0.95, 1}, {1, 0.65, 0.2}}
local function cap(x, y, r)
  rgba(ORANGE)
  lg.arc("fill", "pie", x, y + r * 0.1, r * 0.66, pi, 2 * pi, 18)
  lg.rectangle("fill", x - r * 0.1, y + r * 0.02, r * 0.85, r * 0.15, r * 0.06, r * 0.06, 4)
  lg.setColor(1, 1, 1, 1)
  lg.circle("fill", x, y - r * 0.2, r * 0.13, 8)
end
local function cast(who, x, y, r, lx, ly, mood, open, hook)
  if who == 0 then L.pac(x, y, r, 0, S.t, open) else L.ghost(x, y, r, GH[who], S.t + who, lx, ly, mood) end
  cap(x - (who == 0 and 4 or 0), y - r * 0.86, r)
  if hook then hookem_hand(x + r * 0.95, y - r * 0.5 - abs(sin(S.t * 3 + who)) * 6, r / 120, ORANGE_HI, 1) end
end
-- ------------------------------------------------------------------ the scenes
local D = {}

-- a few stars twinkling over a painted night sky
local function twinkle(n, ymax)
  for i = 1, n do
    local s = S.stars[i]
    if s[2] < ymax then
      lg.setColor(1, 1, 0.9, 0.5 + 0.5 * sin(S.t * (1.3 + i % 3) + i))
      lg.rectangle("fill", s[1], s[2], 2, 2)
    end
  end
end

function D.open(lt, len)
  if S.art.open then
    lg.setColor(1, 1, 1, 1)
    lg.draw(S.art.open, 0, 0)
    C.fx.glow(384, 380, 300, 200, 1, 0.45, 0.05, 0.12 + 0.06 * sin(S.t * 2))
  else
    G:gradient(0, 0, W, H, {0.12, 0.05, 0.02}, {0.45, 0.18, 0.02})
    C.fx.glow(384, 420, 320, 260, 1, 0.45, 0.05, 0.35)
    L.longhorn_head(384, 420, 2.1, ORANGE_HI, 1)
  end
  local a = L.window(lt, 0.5, 4.5, 0.8)
  G:brand(640, a)
  G:caption("PRESENTS", 712, 26, 0x6ef0c8, a)
  local b = L.window(lt, 4.8, 10, 0.8)
  G:caption("TEXAS", 640, 96, 0xff8c1a, b)
  G:caption("LONGHORNS", 750, 54, 0xffffff, b)
end

-- A tailgate: a pop-up canopy (scalloped), its legs, a table and a grill, folks around it.
local function tailgate(x, y, s, col, t, seed)
  local hi = mix(col, {1, 1, 1}, 0.25)
  lg.setColor(0, 0, 0, 0.22)
  lg.ellipse("fill", x, y + 4 * s, 78 * s, 9 * s, 20)
  lg.setColor(0.25, 0.25, 0.28, 1)
  for _, lx in ipairs({-60, 60}) do lg.rectangle("fill", x + lx * s - 2 * s, y - 70 * s, 4 * s, 72 * s) end
  -- the table, a cooler, the grill
  lg.setColor(0.92, 0.9, 0.86, 1)
  lg.rectangle("fill", x - 40 * s, y - 26 * s, 50 * s, 5 * s)
  lg.setColor(0.55, 0.55, 0.58, 1)
  lg.rectangle("fill", x - 36 * s, y - 21 * s, 3 * s, 21 * s)
  lg.rectangle("fill", x + 3 * s, y - 21 * s, 3 * s, 21 * s)
  rgba(ORANGE)
  lg.rectangle("fill", x - 30 * s, y - 40 * s, 22 * s, 14 * s, 2 * s, 2 * s, 4)
  lg.setColor(1, 1, 1, 1)
  lg.rectangle("fill", x - 30 * s, y - 40 * s, 22 * s, 4 * s, 2 * s, 2 * s, 4)
  lg.setColor(0.12, 0.12, 0.13, 1)
  lg.ellipse("fill", x + 34 * s, y - 24 * s, 16 * s, 8 * s, 16)
  lg.rectangle("fill", x + 33 * s, y - 20 * s, 2 * s, 20 * s)
  lg.setColor(1, 0.45, 0.1, 0.5 + 0.3 * sin(t * 9 + seed))
  lg.ellipse("fill", x + 34 * s, y - 27 * s, 10 * s, 3 * s, 12)
  -- the canopy: a peak, a sloped top, the valance's scallops
  local top = y - 72 * s
  rgba(col)
  lg.polygon("fill", x - 66 * s, top, x + 66 * s, top, x + 40 * s, top - 22 * s, x - 40 * s, top - 22 * s)
  rgba(hi)
  lg.polygon("fill", x, top - 22 * s, x + 40 * s, top - 22 * s, x + 66 * s, top, x + 6 * s, top)
  rgba(col)
  lg.rectangle("fill", x - 66 * s, top, 132 * s, 9 * s)
  for i = 0, 10 do lg.circle("fill", x - 60 * s + i * 12 * s, top + 9 * s, 6 * s, 10) end
  lg.setColor(1, 1, 1, 0.9)
  lg.rectangle("fill", x - 66 * s, top + 2 * s, 132 * s, 2 * s)
  -- the folks
  for i = 0, 2 do
    local fx = x - 50 * s + i * 42 * s + sin(t * 0.7 + i + seed) * 6 * s
    fan(fx, y, 1.05 * s, (i + seed) % 2 == 0 and ORANGE_HI or WHITE, t + i * 1.7 + seed, (i + seed) % 3 == 0, (i + seed * 2) % 5 + 1)
  end
end

-- Game day, the cast's tailgate: the canopy up (12), the grill (15), burgers flipped; catch across the lawn (26-40:
-- Inky misses, it bonks Clyde, Clyde's spiral into Pac-Man's mouth); Bevo through (42-56), Hook 'em; to the stadium
local TG = {190, 905}
local function football(x, y, rot, s)
  lg.push()
  lg.translate(x, y)
  lg.rotate(rot)
  lg.scale(s or 1, s or 1)
  lg.setColor(0.55, 0.3, 0.12, 1)
  lg.ellipse("fill", 0, 0, 14, 8, 14)
  lg.setColor(1, 1, 1, 1)
  lg.rectangle("fill", -5, -1, 10, 2)
  lg.pop()
end
local function bevo_x(lt) return lerp(W + 180, -260, lin(lt, 41, 58)) end
local function ball_at(lt)
  -- {from x, y, to x, y, t0, t1}: Blinky to Inky (over his head: he misses, it bonks Clyde), Clyde to Pac-Man
  local throws = {{120, 860, 610, 900, 27, 29.6}, {610, 900, 560, 930, 29.6, 30.4}, {560, 900, 300, 880, 34, 36.4}}
  for _, th in ipairs(throws) do
    if lt >= th[5] and lt < th[6] then
      local f = (lt - th[5]) / (th[6] - th[5])
      local h = th == throws[2] and 30 or 220
      return lerp(th[1], th[3], f), lerp(th[2], th[4], f) - sin(f * pi) * h, (lt - th[5]) * 14
    end
  end
end
local function campus_cast(lt)
  local up = prog(lt, 11, 12)
  -- the cast's canopy and grill
  if up > 0 then
    lg.setColor(0.25, 0.25, 0.28, 1)
    for _, lx in ipairs({-60, 60}) do lg.rectangle("fill", TG[1] + lx - 2, TG[2] - 70 * up, 4, 72 * up) end
    rgba(ORANGE)
    lg.polygon("fill", TG[1] - 66, TG[2] - 72 * up, TG[1] + 66, TG[2] - 72 * up, TG[1] + 40, TG[2] - 94 * up, TG[1] - 40, TG[2] - 94 * up)
    lg.setColor(1, 1, 1, 1)
    L.longhorn_head(TG[1], TG[2] - 82 * up, 0.12 * up, WHITE, 1)
  end
  lg.setColor(0.12, 0.12, 0.13, 1)
  lg.ellipse("fill", TG[1] + 30, TG[2] - 24, 22, 10, 16)
  lg.rectangle("fill", TG[1] + 29, TG[2] - 20, 3, 20)
  if lt > 15 then
    lg.setColor(1, 0.45, 0.1, 0.6 + 0.3 * sin(S.t * 9))
    lg.ellipse("fill", TG[1] + 30, TG[2] - 28, 16, 4, 12)
    -- the burgers, flipped one after another
    for k = 0, 2 do
      local ft = 17 + k * 2.5
      local fy = (lt > ft and lt < ft + 0.7) and sin((lt - ft) / 0.7 * pi) * 40 or 0
      lg.setColor(0.45, 0.25, 0.12, 1)
      lg.ellipse("fill", TG[1] + 18 + k * 12, TG[2] - 32 - fy, 6, 3, 10)
    end
  end
  -- Pac-Man at the grill, then catching; the ghosts about the lawn
  local spots = {[0] = {TG[1] + 70, TG[2] - 36}, {120, 900}, {300, 930}, {610, 940}, {560, 965}}
  for i, who in ipairs({0, 1, 2, 3, 4}) do
    local sx, sy = spots[who][1], spots[who][2]
    local x = lerp(-120 - i * 80, sx, prog(lt, 8 + i * 0.4, 11 + i * 0.4))
    local y = sy
    if who == 0 and lt > 33 then x = lerp(sx, 300, prog(lt, 33, 34.5)) y = lerp(sy, 900, prog(lt, 33, 34.5)) end
    if lt > 56 then x = x + (lt - 56) * 70 y = y - (lt - 56) * 8 end
    local bonk = who == 4 and lt > 30.3 and lt < 33
    local jump = (who == 3 and lt > 28.6 and lt < 29.8) and L.hop(lt - 28.6, 1.2, 50) or 0
    local cheer = lt > 44 and lt < 56
    if cheer then jump = L.hop(S.t + i * 0.3, 0.55, 14) end
    local mood = bonk and "wide" or ((cheer or (who == 0 and lt > 36.4 and lt < 39)) and "happy" or nil)
    cast(who, x, y - 40 - jump, 40, who == 3 and -1 or 1, bonk and -1 or 0, mood, who == 0 and lt > 35.6 and lt < 36.6 and 0.9 or nil, cheer)
    if bonk then
      lg.setColor(1, 0.9, 0.3, 1)
      for k = 0, 2 do local a = S.t * 5 + k * 2.1 L.star(x + cos(a) * 30, y - 80 + sin(a) * 8, 6) end
    end
  end
  local bx, by, br = ball_at(lt)
  if bx then football(bx, by, br, 2.2) end
  -- Bevo through, with his handlers
  if lt > 40 then
    local bvx = bevo_x(lt)
    L.steer(bvx, 985, 1.7, S.t * 4, {{0.82, 0.48, 0.18}, {0.97, 0.95, 0.9}}, {0.95, 0.92, 0.8})
    fan(bvx + 120, 995, 1.8, ORANGE, S.t, false, 2)
    fan(bvx - 130, 995, 1.8, ORANGE, S.t + 1, false, 4)
  end
  if lt > 29.6 and lt < 32 then G:say("BONK!", 560, 840, 26, 1) end
  if lt > 36.5 and lt < 39 then G:say("GOT IT!", 300, 800, 24, 1) end
  if lt > 44 and lt < 47.5 then G:say("BEVO!", 384, 860, 28, 1) end
  if lt > 56 and lt < 60 then G:say("TO THE STADIUM!", 384, 820, 22, 1) end
end
function D.campus(lt, len)
  local A = S.art
  if A.campus_day then
    -- the painted Forty Acres (tools/art/longhorns.py): dawn, and the day coming up over half a minute
    local k = clamp(lt / 30, 0, 1)
    lg.setColor(1, 1, 1, 1)
    if k < 1 and A.campus_dawn then lg.draw(A.campus_dawn, 0, 0) end
    if k > 0 or not A.campus_dawn then lg.setColor(1, 1, 1, A.campus_dawn and k or 1) lg.draw(A.campus_day, 0, 0) end
    tailgate(590, 908, 0.95, WHITE, S.t, 2)
    -- (the walkers and the crowd behind the cast: few while the tailgate's going, then the river to the stadium)
    for i = 0, (lt < 40 and 2 or 6) do
      local x = ((S.t * 22 + i * 130) % (W + 120)) - 60
      fan(x, 962 - (i % 2) * 12, 1.2, i % 3 == 0 and WHITE or ORANGE, S.t + i, i % 2 == 0, i % 5 + 1)
    end
    -- more and more of them up the mall toward the Tower as the morning goes on
    local n = floor(clamp((lt - 30) / 25, 0, 1) * 30)
    for i = 1, n do
      local f = ((S.t * 0.05 + i * 0.137) % 1)
      local x = 384 + ((i * 53) % 120 - 60) * (1 - f * 0.6)
      local y = lerp(1000, 760, f)
      fan(x, y, 1.1 - f * 0.6, i % 3 == 0 and WHITE or ORANGE, S.t + i, i % 4 == 0, i % 5 + 1)
    end
    campus_cast(lt)
    G:plate("THE MAIN BUILDING  ·  THE TOWER", 96, 28, 0xffffff, L.window(lt, 4, 10, 1))
    return
  end
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
    fan(x, 1000 - (i % 2) * 18, 1.1, i % 3 == 0 and WHITE or ORANGE, S.t + i, i % 2 == 0, i % 5 + 1)
  end
  local a = L.window(lt, 22, 40, 1.5)
  G:plate("THE MAIN BUILDING  ·  THE TOWER", 170, 28, 0xffffff, a)
end

-- A strip of the crowd at y: from the painted close crowd (its front rows), else the made one.
local function crowd_strip(y)
  if S.art.crowd_close then
    S.crowd_q = S.crowd_q or lg.newQuad(0, 420, W, 256, W, H)
    lg.draw(S.art.crowd_close, S.crowd_q, 0, y)
  elseif S.crowd then
    lg.draw(S.crowd, 0, y)
  end
end

-- The stadium across the field from the sideline: painted (tools/art), else the sky, the stands, the field.
local function stadium_back()
  if S.art.stadium_day then
    lg.setColor(1, 1, 1, 1)
    lg.draw(S.art.stadium_day, 0, 0)
    return
  end
  G:gradient(0, 0, W, 520, {0.25, 0.5, 0.9}, {0.75, 0.85, 1})
  lg.setColor(1, 1, 1, 1)
  lg.draw(S.stands, 0, 300)
  G:gradient(0, 600, W, H, {0.25, 0.55, 0.22}, {0.2, 0.48, 0.18})
  lg.setColor(1, 1, 1, 0.8)
  for i = 0, 6 do lg.rectangle("fill", 0, 640 + i * 60, W, 3) end
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
    stadium_back()
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
    if S.art.field_long then
      lg.setColor(1, 1, 1, 1)
      lg.draw(S.art.field_long, 0, 830 - (110 - 50) * 14 - 400)      -- (midfield low, under the letters)
    else
      G:gradient(0, 0, W, H, {0.22, 0.52, 0.2}, {0.18, 0.45, 0.16})
      lg.setColor(1, 1, 1, 0.7)
      for i = 0, 10 do lg.rectangle("fill", 0, 60 + i * 86, W, 3) end
    end
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
  stadium_back()
  -- Bevo watches from the south end zone the whole time
  L.steer(660, 720, 0.8, 0, {{0.82, 0.48, 0.18}, {0.97, 0.95, 0.9}}, {0.95, 0.92, 0.8})
  if lt < 24 then
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
    local rec = ((lt - 3) % 6) < 0.4 and lt > 3 and (1 - ((lt - 3) % 6) / 0.4) or 0
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
    -- the cast on the sideline: ears covered just before each shot, a jump at the boom
    local ph = (lt - 3) % 6
    for i, who in ipairs({1, 2, 0, 3, 4}) do
      local cx = 520 + (i - 1) * 56
      local covering = lt > 2 and ph > 4.6
      local jump = (lt > 3 and ph < 0.6) and L.hop(ph, 1.2, 40) or 0
      local r = 30
      cast(who, cx, 1000 - r - jump, r, -1, 0, (covering or jump > 0) and "wide" or "happy")
      if covering then
        lg.setColor(0.95, 0.85, 0.7, 1)
        lg.circle("fill", cx - r * 0.95, 1000 - r * 1.2, 7, 10)
        lg.circle("fill", cx + r * 0.95, 1000 - r * 1.2, 7, 10)
      end
    end
  elseif lt < 50 then
    -- the flag run: the giant Lone Star flag across the field
    local fx = lerp(-660, W + 80, clamp((lt - 24) / 24, 0, 1))
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
    -- the Hook 'Em Herd: the kids, right behind it
    local kx = fx - 120
    for i = 0, 13 do
      local x = kx - (i % 7) * 46 - floor(i / 7) * 20
      local y = 900 + floor(i / 7) * 50 + sin(S.t * 9 + i) * 4
      if x > -30 and x < W + 30 then
        fan(x, y, 0.85, i % 3 == 0 and WHITE or ORANGE_HI, S.t * 2 + i, i % 2 == 0, (i * 3) % 5 + 1)
      end
    end
  else
    -- the team out of the tunnel, through the smoke
    local k = lt - 50
    -- the tunnel: a big orange arch at the left, the dark inside
    rgba(ORANGE)
    lg.rectangle("fill", 0, 720, 190, 260, 90, 90, 16)
    rgba(WHITE)
    lg.rectangle("fill", 18, 744, 154, 236, 74, 74, 16)
    lg.setColor(0.06, 0.04, 0.04, 1)
    lg.rectangle("fill", 30, 760, 130, 220, 64, 64, 16)
    G:text("TEXAS", 0, 724, 18, WHITE, 1, "center", 190)
    for i = 0, 23 do
      local x = 80 + (k * 140) - i * 46 - (i % 3) * 16
      local y = 800 + (i % 4) * 52 + sin(S.t * 11 + i) * 4
      if x > 95 and x < W + 40 then
        local sc2 = 1.45
        local st = sin(S.t * 14 + i) * 8
        lg.setColor(0.97, 0.97, 0.97, 1)
        lg.rectangle("fill", x - 10 * sc2, y + 22 * sc2, 8 * sc2, (16 + st * 0.6) * sc2)
        lg.rectangle("fill", x + 2 * sc2, y + 22 * sc2, 8 * sc2, (16 - st * 0.6) * sc2)
        lg.rectangle("fill", x - 11 * sc2, y + 6 * sc2, 22 * sc2, 18 * sc2, 3, 3, 4)
        rgba(ORANGE_HI)
        lg.rectangle("fill", x - 15 * sc2, y - 22 * sc2, 30 * sc2, 30 * sc2, 6, 6, 4)
        lg.setColor(1, 1, 1, 1)
        G:text(tostring((i * 7) % 99 + 1), x - 15 * sc2, y - 16 * sc2, 16, WHITE, 1, "center", 30 * sc2)
        lg.circle("fill", x, y - 33 * sc2, 12 * sc2, 12)
        rgba(ORANGE)
        lg.rectangle("fill", x - 2 * sc2, y - 45 * sc2, 4 * sc2, 24 * sc2)
        lg.setColor(0.2, 0.2, 0.22, 1)
        lg.rectangle("fill", x + 4 * sc2, y - 34 * sc2, 9 * sc2, 3 * sc2)
      end
    end
    G:plate("HERE COME THE LONGHORNS", 170, 34, 0xff8c1a, L.window(k, 0.5, len - 50 - 1, 0.6))
  end
  if lt > 34 and lt < 50 then G:plate("THE HOOK 'EM HERD", 170, 30, 0xffffff, L.window(lt, 35, 48, 0.6)) end
end

function D.hookem(lt, len)
  -- the stands, the wave rolling through them
  lg.setColor(1, 1, 1, 1)
  if S.art.crowd_close then
    lg.draw(S.art.crowd_close, 0, 0)
  else
    G:gradient(0, 0, W, H, {0.08, 0.06, 0.12}, {0.2, 0.12, 0.08})
    lg.draw(S.crowd, 0, 150)
  end
  -- the wave rolling through: a soft warm light (a hard-edged bar read as a glitch)
  local wave = (S.t * 0.35) % 1.4 - 0.2
  C.fx.glow(wave * W, 410, 90, 280, 1, 0.7, 0.3, 0.3)
  -- the card stunt: TEXAS in white on orange, card by card
  local k = clamp((lt - 4) / 6, 0, 1)
  if lt > 4 then
    local cell = 13
    local n = 0
    -- the section's own seats behind the cards (over the painted crowd the cards read as holes)
    local c1, cN = S.stunt[1], S.stunt[#S.stunt]
    lg.setColor(0.12, 0.06, 0.04, 0.9 * k)
    lg.rectangle("fill", c1[1] - 6, c1[2] - 6, cN[1] - c1[1] + cell + 10, cN[2] - c1[2] + cell + 10, 6, 6, 4)
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
    C.fx.glow(384, 880 - pump, 220, 200, 1, 0.5, 0.1, 0.35 * a)
    hookem_hand(384, 900 - pump, 1.3, ORANGE_HI, a)
  end
  if lt > 22 then
    local beat = floor((lt - 22) / 1.1) % 2
    G:caption(beat == 0 and "TEXAS!" or "FIGHT!", 600, 80, beat == 0 and 0xff8c1a or 0xffffff, clamp((lt - 22) * 2, 0, 1))
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
  if S.art.field_long then
    -- the painted field (tools/art: 14 px a yard, the far end zone's back line 400 px from its top)
    lg.setColor(1, 1, 1, 1)
    lg.draw(S.art.field_long, 0, sy(110) - 400)
  else
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
    -- the cast into the end zone, a ring dance, horns up
    local tt = lt - (#PLAYS * PLAY_T + 4)
    if tt > 1.5 then
      for i, who in ipairs({0, 1, 2, 3, 4}) do
        local ang = tt * 1.4 + i * 1.2566
        local tx, ty = 384 + cos(ang) * 170, 600 + sin(ang) * 60
        local side = i % 2 == 0 and 1 or -1
        local f = prog(tt, 1.5 + i * 0.2, 3.5 + i * 0.2)
        local x, y = lerp(384 + side * 560, tx, f), lerp(900, ty, f)
        cast(who, x, y - L.hop(S.t + i * 0.25, 0.45, 16), 36, 0, -0.5, "happy", nil, f >= 1)
      end
    end
    G:caption("TOUCHDOWN TEXAS!", 420, 64, 0xff8c1a, a)
  end
end

local redriver_score                -- (below)
local GAME_T, HAT_T
-- The stands' halves jumping when their side scores: Texas (orange, left) at each quarter it scored, OU (right)
local function half_jump(lt, side)
  -- scores change at GAME_T + 7 k; who scored: from the table in redriver_score
  local hits = side == 1 and {1, 2, 3, 4} or {2, 3, 4}
  for _, k in ipairs(hits) do
    local t0 = 46 + 7 * k
    if lt > t0 and lt < t0 + 2 then return L.hop(lt - t0, 0.5, 14) end
  end
  return 0
end
local CORNY = {150, 905}           -- the corny dog counter, by the field
local function corny(lt)
  -- six corny dogs on the counter; Pac-Man eats along them like dots (38-42)
  if lt < 33 or lt > 46 then return end
  local cx, cy = CORNY[1], CORNY[2]
  lg.setColor(0.85, 0.15, 0.12, 1)
  lg.rectangle("fill", cx - 120, cy, 300, 70, 6, 6, 4)
  lg.setColor(1, 1, 1, 1)
  for k = 0, 9 do if k % 2 == 0 then lg.rectangle("fill", cx - 120 + k * 30, cy - 36, 30, 36) end end
  lg.setColor(0.85, 0.15, 0.12, 1)
  for k = 0, 9 do if k % 2 == 1 then lg.rectangle("fill", cx - 120 + k * 30, cy - 36, 30, 36) end end
  G:text("CORNY DOGS", cx - 120, cy + 18, 22, {1, 0.95, 0.6}, 1, "center", 300)
  local px = L.path(lt, {{36, cx - 160, 0}, {38, cx - 120, 0}, {42, cx + 190, 0, "lin"}, {44, cx + 260, 0}})
  for k = 0, 5 do
    local dx = cx - 90 + k * 50
    if px < dx - 10 then
      lg.setColor(0.9, 0.85, 0.7, 1)
      lg.rectangle("fill", dx - 2, cy - 20, 4, 22)
      lg.setColor(0.8, 0.55, 0.25, 1)
      lg.ellipse("fill", dx, cy - 34, 9, 20, 12)
      lg.setColor(1, 0.85, 0.2, 1)
      lg.rectangle("fill", dx - 1, cy - 50, 2, 26)
    end
  end
  if lt > 36 then
    local full = lt > 42
    L.pac(px, cy - 42, full and 40 or 32, 0, S.t, nil)
    cap(px - 4, cy - 42 - (full and 40 or 32) * 0.86, full and 40 or 32)
  end
end
-- the Red River scene over its painting: the Texas Star's wheel, Big Tex's waving arm, his "howdy"
local RIDE = {12, 34}                 -- the cast's ride on the Texas Star
local function star_angle(lt) return S.t * 0.15 + 2 * pi * prog(lt, RIDE[1], RIDE[2]) end
local function gondola_at(lt)
  local a = star_angle(lt) + pi / 2                 -- (theirs starts at the bottom)
  return 600 + cos(a) * 170, 300 + sin(a) * 170
end
local function redriver_live(lt)
  local wx, wy, wr = 600, 300, 170
  lg.setColor(0.88, 0.9, 0.95, 1)
  lg.setLineWidth(3)
  lg.circle("line", wx, wy, wr, 64)
  lg.circle("line", wx, wy, wr - 10, 64)
  for i = 0, 15 do
    local a = i / 16 * 2 * pi + star_angle(lt)
    lg.setLineWidth(2)
    lg.setColor(0.88, 0.9, 0.95, 1)
    lg.line(wx + cos(a) * 14, wy + sin(a) * 14, wx + cos(a) * wr, wy + sin(a) * wr)
    local c = ({{1, 0.3, 0.3}, {1, 0.85, 0.2}, {0.3, 0.6, 1}, {0.4, 0.85, 0.4}})[i % 4 + 1]
    local gx, gy = wx + cos(a) * wr, wy + sin(a) * wr
    lg.setColor(0.3, 0.3, 0.34, 1)
    lg.rectangle("fill", gx - 1, gy, 2, 6)
    rgba(c)
    lg.rectangle("fill", gx - 9, gy + 5, 18, 14, 4, 4, 4)
    lg.setColor(1, 1, 1, 0.6)
    lg.rectangle("fill", gx - 6, gy + 8, 12, 5)
  end
  lg.setColor(0.88, 0.9, 0.95, 1)
  lg.circle("fill", wx, wy, 14, 16)
  -- the cast's gondola: bigger, the five of them waving
  if lt > RIDE[1] - 4 and lt < RIDE[2] + 4 then
    local gx, gy = gondola_at(lt)
    lg.setColor(0.3, 0.3, 0.34, 1)
    lg.rectangle("fill", gx - 1.5, gy, 3, 10)
    rgba(ORANGE_HI)
    lg.rectangle("fill", gx - 34, gy + 26, 68, 22, 6, 6, 4)
    for k = 0, 4 do
      local hx = gx - 26 + k * 13
      local up = L.hop(S.t * 1.5 + k * 0.3, 0.5, 4)
      if k == 2 then L.pac(hx, gy + 20 - up, 8, 0, S.t, nil)
      else L.ghost(hx, gy + 20 - up, 8, GH[k < 2 and k + 1 or k], S.t + k, 0, 0.5, "happy") end
    end
  end
  -- Big Tex's right arm, waving: plaid sleeve, the hand
  local wave = sin(S.t * 2) * 0.3
  lg.push()
  lg.translate(222, 240)
  lg.rotate(-1.9 + wave)
  lg.setColor(0.77, 0.19, 0.16, 1)
  lg.rectangle("fill", 0, -14, 120, 28, 12, 12, 6)
  lg.setColor(1, 1, 1, 0.22)
  for i = 0, 7 do lg.rectangle("fill", 6 + i * 14, -14, 4, 28) end
  lg.setColor(0.91, 0.72, 0.57, 1)
  lg.circle("fill", 128, 0, 16, 14)
  lg.rectangle("fill", 128, -26, 8, 18, 4, 4, 4)
  lg.pop()
  if L.window(lt, 5, 11.5, 0.5) > 0 then
    lg.setColor(1, 1, 1, 0.95)
    lg.rectangle("fill", 240, 70, 210, 50, 14, 14, 8)
    lg.polygon("fill", 250, 120, 270, 120, 236, 140)
    G:text("HOWDY, FOLKS!", 240, 82, 26, {0.6, 0.15, 0.1}, 1, "center", 210)
  end
end

function D.redriver(lt, len)
  if S.art.fair then
    lg.setColor(1, 1, 1, 1)
    lg.draw(S.art.fair, 0, 0)
    -- the stands' halves, jumping when their side scores
    S.fq = S.fq or {lg.newQuad(0, 606, 384, 160, W, H), lg.newQuad(384, 606, 384, 160, W, H)}
    for side = 1, 2 do
      local j = half_jump(lt, side)
      if j > 0 then
        lg.setColor(0.25, 0.45, 0.2, 1)
        lg.rectangle("fill", (side - 1) * 384, 750, 384, 20)
        lg.setColor(1, 1, 1, 1)
        lg.draw(S.art.fair, S.fq[side], (side - 1) * 384, 606 - j)
      end
    end
    redriver_live(lt)
    corny(lt)
    -- the rest of the cast at the counter, then on the field's edge for the game, then carrying the hat
    for i, who in ipairs({1, 2, 3, 4}) do
      local x = lerp(-80 - i * 60, CORNY[1] + 200 + i * 70, prog(lt, 34 + i * 0.3, 36 + i * 0.3))
      local y = CORNY[2] - 36
      if lt > 45 then x, y = lerp(x, 120 + i * 120, prog(lt, 45, 47)), lerp(y, 980, prog(lt, 45, 47)) end
      if lt > 33 then
        local jump = lt > GAME_T and half_jump(lt, 1) * 2 or 0
        cast(who, x, y - jump, 32, 0, lt > 45 and -0.6 or 0, (jump > 0 or lt > HAT_T) and "happy" or ((lt > 38 and lt < 43) and "wide" or nil), nil, lt > HAT_T + 2)
      end
    end
    if lt > 45 then
      local jump = half_jump(lt, 1) * 2
      cast(0, 60, 980 - jump, 32, 0, 0, nil, nil, lt > HAT_T + 2)
    end
    redriver_score(lt)
    if lt > 38 and lt < 41.5 then G:say("WAKA WAKA WAKA!", CORNY[1] + 60, 820, 22, 1) end
    if lt > 42 and lt < 44.5 then G:say("...ANY MORE?", CORNY[1] + 200, 820, 22, 1) end
    if lt > RIDE[1] + 6 and lt < RIDE[1] + 10 then
      local gx, gy = gondola_at(lt)
      G:say("WHEEEE!", gx, gy + 10, 22, 1)
    end
    return
  end
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
  redriver_score(lt)
end

-- the score, quarter by quarter; the Golden Hat at the end
GAME_T, HAT_T = 46, 74
function redriver_score(lt)
  local scores = {{0, 0, "KICKOFF"}, {7, 0, "1ST QUARTER"}, {14, 10, "2ND QUARTER"}, {21, 17, "3RD QUARTER"}, {31, 24, "FINAL"}}
  if lt < GAME_T - 1 then return end
  local q = clamp(floor((lt - GAME_T) / 7) + 1, 1, #scores)
  local s = scores[q]
  lg.setColor(0.02, 0.02, 0.06, 0.8)
  lg.rectangle("fill", 134, 790, 500, 110, 12, 12, 8)
  G:text(s[3], 134, 800, 22, {1, 0.85, 0.4}, 1, "center", 500)
  G:text(string.format("TEXAS  %d", s[1]), 150, 838, 40, ORANGE_HI, 1, "left", 240)
  G:text(string.format("OU  %d", s[2]), 380, 838, 40, {0.85, 0.2, 0.25}, 1, "right", 240)
  if q == #scores then
    local k = clamp((lt - HAT_T) / 2, 0, 1)
    local hy = 700 - k * 90 - (lt > HAT_T + 3 and L.hop(S.t, 0.6, 14) or 0)
    C.fx.glow(384, hy, 140, 90, 1, 0.85, 0.3, 0.5 * k)
    lg.setColor(1, 0.82, 0.25, k)
    lg.ellipse("fill", 384, hy, 90, 18, 24)
    lg.rectangle("fill", 334, hy - 50, 100, 50, 20, 20, 8)
    lg.setColor(0.6, 0.45, 0.2, k)
    lg.rectangle("fill", 334, hy - 16, 100, 8)
    G:plate("THE GOLDEN HAT STAYS IN AUSTIN", 940, 26, 0xffd23f, k)
  end
end

local TOWER_UP, TOWER_STEP, TOWER_FLOORS = 10, 1, 12       -- lit from 10 s, a floor a second
local TOWER_BASE, TOWER_TOP = 800, 140                     -- (where the Tower stands in the painting)
local SPARKLE_T = 27                                       -- the sparkler wave across the crowd

function D.tower(lt, len)
  -- the Tower dark; lit floor by floor from the bottom (10-22), its top orange (a win: the real one, when there's one
  -- this week); then the sweep to all orange with the 1 (46-48.5); the crowd and the cast on the South Mall
  local function reveal(img, top)
    S.tq = S.tq or lg.newQuad(0, 0, W, H, W, H)
    top = clamp(floor(top), 0, H)
    S.tq:setViewport(0, top, W, H - top, W, H)
    lg.draw(img, S.tq, 0, top)
  end
  local floors = floor(clamp((lt - TOWER_UP) / TOWER_STEP, 0, TOWER_FLOORS))
  local one_k = prog(lt, 46, 48.5)
  if S.art.tower_win and S.art.tower_one and S.art.tower_dark then
    lg.setColor(1, 1, 1, 1)
    lg.draw(S.art.tower_dark, 0, 0)
    if floors > 0 then reveal(S.art.tower_win, lerp(TOWER_BASE, TOWER_TOP, floors / TOWER_FLOORS)) end
    if floors >= TOWER_FLOORS then lg.setColor(1, 1, 1, 1) lg.draw(S.art.tower_win, 0, 0) end
    if one_k > 0 then lg.setColor(1, 1, 1, 1) reveal(S.art.tower_one, lerp(H, 0, one_k)) end
    twinkle(50, 560)
  else
    G:gradient(0, 0, W, 800, {0.02, 0.02, 0.08}, {0.12, 0.06, 0.16})
    for i, s in ipairs(S.stars) do
      lg.setColor(1, 1, 0.9, 0.5 + 0.5 * sin(S.t * (1 + i % 3) + i))
      lg.rectangle("fill", s[1], s[2], 2, 2)
    end
    tower(384, 800, 1.2, one_k > 0.5 and "one" or (floors > 0 and "win" or "dark"))
  end
  -- the pulse when the top goes orange, the flash at the 1
  local lit_t = TOWER_UP + TOWER_FLOORS * TOWER_STEP
  if lt > lit_t and lt < lit_t + 1.2 then
    lg.setBlendMode("add")
    C.fx.glow(384, 200, 300, 200, 1, 0.5, 0.1, 0.8 * (1 - (lt - lit_t) / 1.2))
    lg.setBlendMode("alpha")
  end
  if lt > 47.6 and lt < 48.6 then
    lg.setBlendMode("add")
    lg.setColor(1, 0.6, 0.2, 1 - abs(lt - 48.1) * 2)
    lg.rectangle("fill", 0, 0, W, 800)
    lg.setBlendMode("alpha")
  end
  if not S.art.tower_win then
    L.live_oak(90, 820, 1.2, S.t)
    L.live_oak(680, 820, 1.1, S.t + 1)
    G:gradient(0, 800, W, H, {0.06, 0.08, 0.05}, {0.03, 0.04, 0.03})
  end
  -- the crowd on the South Mall, filling in, horns up, against the Tower's glow on the lawn
  local glow = floors >= TOWER_FLOORS and (one_k > 0 and 0.5 or 0.38) or 0.1 + 0.25 * floors / TOWER_FLOORS
  C.fx.glow(384, 900, 520, 110, 1, 0.45, 0.1, glow)
  local nfans = floor(clamp(lt / 9, 0, 1) * 16)
  local sparklers = {}
  for i = 0, nfans - 1 do
    local cheer = floors >= TOWER_FLOORS and L.hop(S.t + i * 0.3, 0.55, 10) or 0
    fan(30 + i * 48, 972 - (i % 2) * 20 - cheer, 1.8, {0.07, 0.04, 0.03}, S.t + i, floors >= TOWER_FLOORS, i % 5 + 1)
    -- the sparkler wave: lit one after another across the Mall, held up and waved
    local lit_at = SPARKLE_T + i * 0.55
    if lt > lit_at and lt < len - 4 then
      local sx = 30 + i * 48 + 14 + sin(S.t * 5 + i) * 10
      local sy = 972 - (i % 2) * 20 - cheer - 108
      sparklers[#sparklers + 1] = {sx, sy}
      if G.R:random() < 0.5 then
        G:spark(sx, sy, (G.R:random() - 0.5) * 160, -40 - G.R:random() * 100, 0.5, {1, 0.85, 0.5}, 3, 200, true)
      end
    end
  end
  -- (their glows in one additive pass: a blend switch each costs the cabinet frames)
  lg.setBlendMode("add")
  for _, p in ipairs(sparklers) do C.fx.glow(p[1], p[2], 34, 34, 1, 0.8, 0.4, 0.8) end
  lg.setBlendMode("alpha")
  -- the cast, in their caps, in front: in at 2, hook 'em when it's lit
  for i, who in ipairs({1, 2, 0, 3, 4}) do
    local x = lerp(-100 - i * 80, 200 + (i - 1) * 92, prog(lt, 2 + i * 0.4, 6 + i * 0.4))
    local lit = floors >= TOWER_FLOORS
    local y = 1000 - 36 - (lit and L.hop(S.t * 1.2 + i * 0.2, 0.5, 18) or 0)
    local look = lt > TOWER_UP and lt < 50 and -1 or 0
    cast(who, x, y, 36, 0, look, lit and "happy" or ((lt > TOWER_UP) and "wide" or nil), nil, lit and lt > lit_t + 1)
  end
  local last = S.last
  if one_k <= 0 then
    local a = L.window(lt, lit_t + 1, 46, 1.2)
    if last and last.won and S.last_days and S.last_days <= 6 then
      G:plate(string.format("TEXAS %d, %s %d", last.us or 0, string.upper(last.opp or last.opp_abbr or ""), last.them or 0), 760, 32, 0xffd23f, a)
      G:plate("THE TOWER IS ORANGE TONIGHT", 820, 26, 0xffffff, L.window(lt, lit_t + 3, 46, 1.2))
    else
      G:plate("AFTER EVERY WIN: AN ORANGE TOP", 780, 30, 0xffd23f, a)
    end
  else
    G:plate("A NATIONAL TITLE: ALL ORANGE, WITH A 1", 780, 28, 0xffd23f, L.window(lt, 49, 66, 1.2))
    G:plate("THE EYES OF TEXAS ARE UPON YOU", 780, 30, 0xffffff, L.window(lt, 68, len - 2, 1.2))
  end
  if lt > lit_t + 0.5 and lt < lit_t + 3.5 then G:say("HOOK 'EM!", 384, 900, 30, 1) end
end

-- ------------------------------------------------------------------ the season on the video board
local MON = {"JAN", "FEB", "MAR", "APR", "MAY", "JUN", "JUL", "AUG", "SEP", "OCT", "NOV", "DEC"}
local DOW = {"SUN", "MON", "TUE", "WED", "THU", "FRI", "SAT"}
local function day_label(day)
  local y, m, d = day:match("^(%d+)-(%d+)-(%d+)")
  if not y then return "" end
  return MON[tonumber(m)] .. " " .. tonumber(d)
end
local function kick_label(g)
  if g.tbd or not g.kickoff then return "TBD" end
  return (os.date("%I:%M %p", g.kickoff):gsub("^0", ""))
end
local function opp_name(g)
  local n = string.upper(g.opp or g.opp_abbr or "")
  if g.opp_rank then n = "NO. " .. g.opp_rank .. " " .. n end
  return n
end

local BOARD_W, BOARD_H, BOARD_TOP = 700, 724, 126
local ROW_DT, REPLAY_DT = 0.8, 3.2            -- the board's rows in, a row at a time; then each result replayed
-- the played games, and when each one's replay starts (after the rows are in); the faceoff for the next one after
local function replays(n)
  local played = {}
  for i, g in ipairs(S.games or {}) do
    if g.state == "post" and g.us and g.them then played[#played + 1] = i end
  end
  local t0 = 2.5 + n * ROW_DT + 1.2
  return played, t0, t0 + #played * REPLAY_DT
end
local function opp_col(g)
  local hex = g and TEAM_COLOURS[g.opp_abbr]
  local col = hex and L.hex(hex) or {0.8, 0.8, 0.85}
  if col[1] + col[2] + col[3] < 0.5 then col = mix(col, {1, 1, 1}, 0.35) end
  return col
end
-- a football helmet facing dir (1 right, -1 left): the shell, the facemask, a stripe; Texas: the longhorn on it
local function helmet(x, y, s, col, dir, texas, abbr)
  lg.push()
  lg.translate(x, y)
  lg.scale(s * dir, s)
  lg.setColor(col[1], col[2], col[3], 1)
  lg.arc("fill", "pie", 0, 0, 70, pi * 0.95, pi * 2.15, 30)
  lg.ellipse("fill", -6, 4, 66, 50, 30)
  lg.setColor(1, 1, 1, 0.25)
  lg.ellipse("fill", -24, -34, 26, 10, 14)
  lg.setColor(0.9, 0.9, 0.92, 1)
  lg.setLineWidth(7)
  lg.line(40, 0, 86, 4, 86, 44, 50, 52)
  lg.line(58, 4, 58, 50)
  lg.line(40, 24, 86, 24)
  lg.setColor(0.15, 0.15, 0.18, 1)
  lg.circle("fill", 8, 14, 10, 12)
  if texas then
    lg.push()
    lg.scale(dir, 1)
    L.longhorn_head(-12 * dir, -6, 0.32, WHITE, 1)
    lg.pop()
  elseif abbr then
    lg.push()
    lg.scale(dir, 1)
    G:text(abbr, -60, -26, 26, {1, 1, 1}, 1, "center", 104)
    lg.pop()
  end
  lg.pop()
end
-- the replay of game i (k: seconds into it): the helmets in, the clash, the score stamped
local function replay(g, k, bx, by, bw)
  local cx, cy = bx + bw / 2, by + 380
  lg.setColor(0.02, 0.02, 0.05, 0.97)
  lg.rectangle("fill", bx + 16, by + 140, bw - 32, 470, 12, 12, 8)
  G:text(day_label(g.day) .. "  ·  " .. ((g.neutral or g.home) and "VS " or "AT ") .. opp_name(g), bx, by + 168, 26, {0.8, 0.8, 0.85}, 1, "center", bw)
  local inn = ease(clamp(k / 0.8, 0, 1))
  local bump = (k > 0.8 and k < 1.2) and (1.2 - k) * 40 or 0
  local lost = not g.won
  local back = (lost and k > 1.2) and ease(clamp((k - 1.2) / 0.6, 0, 1)) * 60 or 0
  helmet(lerp(bx - 120, cx - 92, inn) - back + (k > 0.8 and -bump or 0), cy + (lost and back * 0.3 or 0), 1.15, ORANGE_HI, 1, true)
  helmet(lerp(bx + bw + 120, cx + 92, inn) + (k > 0.8 and bump or 0), cy, 1.15, opp_col(g), -1, false, g.opp_abbr)
  if k > 0.8 and k < 1.1 then
    lg.setBlendMode("add")
    C.fx.glow(cx, cy, 120, 120, 1, 0.9, 0.6, 1 - (k - 0.8) / 0.3)
    lg.setBlendMode("alpha")
  end
  if k > 1.2 then
    local pop = 1 + 0.4 * (1 - clamp((k - 1.2) / 0.3, 0, 1))
    local res = (g.won and "W  " or "L  ") .. g.us .. "-" .. g.them
    G:caption(res, by + 470, 64, g.won and 0xff8c1a or 0x9a9aa6, clamp((k - 1.2) * 4, 0, 1), pop)
  end
end
function D.season(lt, len)
  local bx, by, bw, bh = 34, 96, BOARD_W, BOARD_H
  local games = S.games or {}
  local bd = S.board
  if #games == 0 or not bd or bd.n ~= #games then
    -- no schedule (no network yet, or never): the season, coming
    lg.clear(0.05, 0.03, 0.06, 1)
    lg.setColor(1, 1, 1, 0.9)
    crowd_strip(840)
    lg.setColor(0.02, 0.02, 0.04, 1)
    lg.rectangle("fill", bx, by, bw, bh)
    lg.setLineWidth(8)
    rgba(ORANGE)
    lg.rectangle("line", bx - 4, by - 4, bw + 8, bh + 8, 8, 8, 6)
    G:text("LONGHORNS FOOTBALL", bx, by + 24, 40, ORANGE_HI, 1, "center", bw)
    -- the countdown to the season (the last Saturday of August), counting up to it as the scene opens
    local now = os.date("*t")
    local ky = now.year
    local kick = os.time({year = ky, month = 8, day = 30, hour = 12})
    if kick < os.time() then kick = os.time({year = ky + 1, month = 8, day = 30, hour = 12}) end
    local days = floor((kick - os.time()) / 86400)
    local shown = floor(days * clamp((lt - 1) / 4, 0, 1))
    G:text("KICKOFF IN", bx, by + 76, 26, WHITE, 1, "center", bw)
    G:text(shown .. " DAYS", bx, by + 104, 48, ORANGE_HI, 0.75 + 0.25 * abs(sin(S.t * 3)), "center", bw)
    -- the chalkboard: a play drawn up, then run, every 12 s (three of them)
    local fx, fy, fw, fh = bx + 30, by + 180, bw - 60, 470
    lg.setColor(0.08, 0.22, 0.12, 1)
    lg.rectangle("fill", fx, fy, fw, fh, 8, 8, 4)
    lg.setColor(1, 1, 1, 0.25)
    for k = 1, 4 do lg.rectangle("fill", fx + 10, fy + k * fh / 5, fw - 20, 2) end
    lg.setColor(0.75, 0.34, 0, 0.6)
    lg.rectangle("fill", fx + 10, fy + 8, fw - 20, 50)
    G:text("END ZONE", fx, fy + 18, 24, WHITE, 0.8, "center", fw)
    local p = floor(math.max(0, lt - 6) / 12) % 3 + 1
    local pt = math.max(0, lt - 6) % 12
    local los = fy + fh - 120
    local cxp = fx + fw / 2
    local O = {{cxp, los + 50}, {cxp - 90, los + 6}, {cxp + 90, los + 6}, {cxp - 200, los + 6}, {cxp + 200, los + 6}}
    local routes = ({
      {{4, {{cxp - 200, los - 200}, {cxp - 120, fy + 40}}}},                         -- the long pass left
      {{1, {{cxp, los - 80}, {cxp + 60, los - 200}, {cxp + 40, fy + 40}}}},           -- the run up the middle
      {{5, {{cxp + 200, los - 160}, {cxp + 60, los - 260}, {cxp + 20, fy + 40}}}},    -- the post route right
    })[p]
    -- the players: O's (Texas) and X's
    G:text(({"PLAY 1: THE BOMB", "PLAY 2: UP THE GUT", "PLAY 3: THE POST"})[p], fx, fy + fh - 40, 22, {1, 1, 1}, 0.8, "center", fw)
    -- (where the ball carrier is, for the X's to chase)
    local who0 = routes[1][1]
    local cx_, cy_ = O[who0][1], O[who0][2]
    if pt > 5.5 then
      local rp = {O[who0][1], O[who0][2]}
      for _, q in ipairs(routes[1][2]) do rp[#rp + 1] = q[1] rp[#rp + 1] = q[2] end
      local sg = #routes[1][2]
      local f = clamp((pt - 5.5) / 3.5, 0, 1)
      local k = min(sg, floor(f * sg) + 1)
      local g = min(f * sg - (k - 1), 1)
      cx_, cy_ = lerp(rp[k * 2 - 1], rp[k * 2 + 1], g), lerp(rp[k * 2], rp[k * 2 + 2], g)
    end
    lg.setLineWidth(4)
    for i, o in ipairs(O) do
      -- the O's: the cast in chalk-board miniature (Pac-Man at quarterback)
      local a = clamp(pt * 3 - i * 0.3, 0, 1)
      if a > 0 and not (i == who0 and pt > 5.5) then
        if i == 1 then L.pac(o[1], o[2], 15, -pi / 2, S.t, nil, a)
        else L.ghost(o[1], o[2], 15, GH[i - 1], S.t + i, 0, -1, nil, a) end
      end
      -- the X's, chasing the ball when it's run
      local xx, xy = o[1] + (i % 2 == 0 and 20 or -20), los - 46
      if pt > 5.5 then
        local f = clamp((pt - 5.5) / 3.5, 0, 1) * 0.75
        xx, xy = lerp(xx, cx_ + (i - 3) * 22, f), lerp(xy, cy_ - 20, f)
      end
      lg.setColor(1, 1, 1, clamp(pt * 3 - i * 0.3 - 0.5, 0, 1))
      lg.line(xx - 10, xy - 10, xx + 10, xy + 10)
      lg.line(xx + 10, xy - 10, xx - 10, xy + 10)
    end
    -- the route chalked in, then run
    local who, path = routes[1][1], routes[1][2]
    local pts = {O[who][1], O[who][2]}
    for _, q in ipairs(path) do pts[#pts + 1] = q[1] pts[#pts + 1] = q[2] end
    local draw = clamp((pt - 2) / 3, 0, 1)
    local seg = #path
    lg.setColor(1, 1, 0.85, 0.9)
    lg.setLineWidth(3)
    for k = 1, seg do
      local a0 = (k - 1) / seg
      if draw > a0 then
        local f = clamp((draw - a0) * seg, 0, 1)
        local x1, y1, x2, y2 = pts[k * 2 - 1], pts[k * 2], pts[k * 2 + 1], pts[k * 2 + 2]
        lg.line(x1, y1, lerp(x1, x2, f), lerp(y1, y2, f))
      end
    end
    -- running it: the carrier along the route with the ball (a pass: thrown from the QB)
    if pt > 5.5 then
      local f = clamp((pt - 5.5) / 3.5, 0, 1)
      local k = min(seg, floor(f * seg) + 1)
      local g = f * seg - (k - 1)
      local x = lerp(pts[k * 2 - 1], pts[k * 2 + 1], min(g, 1))
      local y = lerp(pts[k * 2], pts[k * 2 + 2], min(g, 1))
      if who == 1 then L.pac(x, y, 15, -pi / 2, S.t, nil)
      else L.ghost(x, y, 15, GH[who - 1], S.t + who, 0, -1, "happy") end
      if who ~= 1 and f < 0.6 then
        local bf = f / 0.6
        lg.setColor(0.6, 0.35, 0.15, 1)
        lg.ellipse("fill", lerp(O[1][1], x, bf), lerp(O[1][2], y, bf) - sin(bf * pi) * 80, 9, 6, 10)
      end
    end
    if pt > 9 then
      local a = min(1, (pt - 9) * 3) * (1 - clamp((pt - 11.5) * 2, 0, 1))
      G:text("TOUCHDOWN!", fx, fy + 170, 56, ORANGE_HI, a, "center", fw)
    end
    -- Coach Clyde on the sideline: cap, whistle, pointing at the board
    local blow = pt > 5.2 and pt < 5.8
    local hop = (pt > 9 and pt < 11) and L.hop(pt - 9, 0.5, 20) or 0
    cast(4, 650, 950 - hop, 46, -1, -0.6, (pt > 9 and pt < 11.5) and "happy" or nil, nil, pt > 9 and pt < 11.5)
    lg.setColor(0.85, 0.85, 0.9, 1)
    lg.rectangle("fill", 650 - 46 - 18, 950 - 20 - hop, 18, 10, 4, 4, 4)
    if blow then G:say("TWEET!", 600, 860, 22, 1) end
    S.chalk = {fx, fy, fw, fh, pt}
    return
  end
  -- (one layer where it can be: a clear, the crowd below, the frame as lines, the board's picture)
  lg.clear(0.05, 0.03, 0.06, 1)
  -- the board's post first, behind the crowd
  lg.setColor(0.18, 0.18, 0.2, 1)
  lg.rectangle("fill", 360, by + bh + 16, 48, 60)
  lg.setColor(1, 1, 1, 1)
  crowd_strip(840)
  lg.setLineWidth(12)
  lg.rectangle("line", bx - 10, by - 10, bw + 20, bh + 20, 10, 10, 6)
  rgba(ORANGE)
  lg.setLineWidth(6)
  lg.rectangle("line", bx - 3, by - 3, bw + 6, bh + 6, 8, 8, 6)
  local n = bd.n
  local rh = bd.rh
  local all_in = lt > 2.5 + n * ROW_DT + 0.4
  lg.setColor(1, 1, 1, 1)
  lg.setBlendMode("replace")
  if all_in then
    lg.draw(bd.cv, bx, by)
  else
    lg.draw(bd.cv, bd.head, bx, by)
    lg.setColor(0.02, 0.02, 0.04, 1)
    lg.rectangle("fill", bx, by + BOARD_TOP, bw, bh - BOARD_TOP)
    lg.setColor(1, 1, 1, 1)
    for i = 1, n do
      local a = clamp((lt - 2.5 - i * ROW_DT) * 3, 0, 1)
      if a > 0 then
        local y = by + BOARD_TOP + (i - 1) * rh
        lg.draw(bd.cv, bd.quads[i], bx, y + rh / 2, 0, 1, a, 0, rh / 2)
      end
    end
  end
  lg.setBlendMode("alpha")
  -- the next game's row glowing; then the next kickoff, big
  local nx = ut.next()
  if nx then
    for i, g in ipairs(games) do
      if g.day == nx.day and lt > 2.5 + i * ROW_DT + 0.3 then
        lg.setColor(1, 0.5, 0.1, 0.18 + 0.12 * abs(sin(S.t * 4)))
        lg.rectangle("fill", bx + 10, by + BOARD_TOP + (i - 1) * rh, bw - 20, rh - 4, 6, 6, 4)
      end
    end
  end
  local played, rt0, rt1 = replays(n)
  if lt > rt0 and lt < rt1 then
    local j = floor((lt - rt0) / REPLAY_DT) + 1
    local g = games[played[j]]
    if g then replay(g, (lt - rt0) % REPLAY_DT, bx, by, bw) end
  end
  -- the next game, face to face; Bevo pawing the ground in front, the cast cheering
  if nx and lt > rt1 then
    local k = lt - rt1
    local cx, cy = bx + bw / 2, by + 380
    lg.setColor(0.02, 0.02, 0.05, 0.97 * clamp(k * 3, 0, 1))
    lg.rectangle("fill", bx + 16, by + 140, bw - 32, 470, 12, 12, 8)
    G:text("NEXT: " .. ((nx.neutral or nx.home) and "VS " or "AT ") .. opp_name(nx), bx, by + 168, 28, ORANGE_HI, clamp(k * 3, 0, 1), "center", bw)
    local inn = ease(clamp(k / 1, 0, 1))
    -- (a bump every two seconds: they can't wait)
    local ph = (k % 2) / 2
    local nudge = ph < 0.15 and -ph / 0.15 * 30 or (ph < 0.3 and -(0.3 - ph) / 0.15 * 30 or 0)
    helmet(lerp(bx - 120, cx - 112, inn) - nudge, cy, 1.4, ORANGE_HI, 1, true)
    helmet(lerp(bx + bw + 120, cx + 112, inn) + nudge, cy, 1.4, opp_col(nx), -1, false, nx.opp_abbr)
    local wd = nx.day and DOW[tonumber(os.date("%w", os.time({year = tonumber(nx.day:sub(1, 4)), month = tonumber(nx.day:sub(6, 7)),
                                                        day = tonumber(nx.day:sub(9, 10)), hour = 12}))) + 1] or ""
    G:text(wd .. " " .. day_label(nx.day) .. "  ·  " .. kick_label(nx) .. (nx.net and ("  ·  " .. nx.net) or ""),
           bx, cy + 110, 28, WHITE, clamp((k - 1) * 2, 0, 1), "center", bw)
  end
  if lt > rt1 + 2 then
    local bvx = lerp(-200, 560, prog(lt, rt1 + 2, rt1 + 5))
    local paw = (lt > rt1 + 5) and abs(sin(S.t * 6)) * 6 or 0
    L.steer(bvx, 1000, 1.5, (lt < rt1 + 5) and S.t * 4 or 0, {{0.82, 0.48, 0.18}, {0.97, 0.95, 0.9}}, {0.95, 0.92, 0.8})
    if paw > 5 and G.R:random() < 0.3 then G:puff(bvx + 80, 990, {0.75, 0.6, 0.45}, 20, 30, 1, 8, 0.4) end
    for i, who in ipairs({1, 2, 0, 3}) do
      local x = lerp(-100 - i * 70, 60 + (i - 1) * 100, prog(lt, rt1 + 3 + i * 0.3, rt1 + 5 + i * 0.3))
      cast(who, x, 990 - 30 - L.hop(S.t + i * 0.3, 0.5, 16), 30, 1, -0.6, "happy", nil, true)
    end
  end
  local done = rt1 + 1
  if false and nx and lt > done then
    local a = clamp((lt - done) * 2, 0, 1)
    local where = nx.neutral and "VS " or (nx.home and "VS " or "AT ")
    local wd = nx.day and DOW[tonumber(os.date("%w", os.time({year = tonumber(nx.day:sub(1, 4)), month = tonumber(nx.day:sub(6, 7)),
                                                        day = tonumber(nx.day:sub(9, 10)), hour = 12}))) + 1] or ""
    lg.setColor(0.02, 0.02, 0.04, 0.85 * a)
    lg.rectangle("fill", bx + 20, by + bh - 96, bw - 40, 84, 10, 10, 6)
    G:text("NEXT: " .. where .. string.upper(nx.opp or ""), bx, by + bh - 88, 30, ORANGE_HI, a, "center", bw)
    G:text(wd .. " " .. day_label(nx.day) .. "  ·  " .. kick_label(nx) .. (nx.net and ("  ·  " .. nx.net) or ""),
           bx, by + bh - 50, 24, WHITE, a, "center", bw)
  end
end

-- The board, painted into one picture when the season changes (its background, scanlines, header and rows):
-- the cabinet is fill-bound here, and five big layers a frame (gradient, panels, scanlines, rows) ran at 47 fps.
local function board_paint()
  local games = S.games or {}
  local n = #games
  if n == 0 then return end
  local rh = min(40, (BOARD_H - 240) / n)
  local nx = ut.next()
  local season = ut.season
  local sig = n .. "|" .. (nx and nx.day or "") .. "|" .. tostring(season and season.rank) .. "|"
  for _, g in ipairs(games) do sig = sig .. (g.state or "") .. (g.us or "") .. (g.them or "") .. (g.tbd and "t" or "") end
  if S.board and S.board.sig == sig then return end
  local cv = S.board and S.board.cv
  if not cv then cv = G:track(lg.newCanvas(BOARD_W, BOARD_H)) end
  lg.push("all")
  lg.setCanvas(cv)
  lg.origin()
  lg.clear(0.02, 0.02, 0.04, 1)
  lg.setColor(1, 1, 1, 0.025)
  for y = 0, BOARD_H, 6 do lg.rectangle("fill", 0, y, BOARD_W, 2) end
  local wins, losses = 0, 0
  for _, g in ipairs(games) do
    if g.state == "post" then if g.won then wins = wins + 1 else losses = losses + 1 end end
  end
  local rank = season and season.rank
  G:text(games[n].day:sub(1, 4) .. " LONGHORNS", 0, 18, 42, ORANGE_HI, 1, "center", BOARD_W)
  G:text((rank and ("NO. " .. rank .. "  ·  ") or "") .. wins .. "-" .. losses, 0, 66, 30, WHITE, 1, "center", BOARD_W)
  lg.setColor(ORANGE[1], ORANGE[2], ORANGE[3], 0.8)
  lg.rectangle("fill", 20, 108, BOARD_W - 40, 3)
  local quads = {}
  for i, g in ipairs(games) do
    local y = BOARD_TOP + (i - 1) * rh
    local px = min(24, rh * 0.55)
    local ty = y + (rh - px) / 2 - 2
    local next_one = nx and g.day == nx.day
    G:text(day_label(g.day), 20, ty, px, {0.75, 0.75, 0.8}, 1, "left", 110)
    local where = g.neutral and "VS" or (g.home and "VS" or "AT")
    local name = opp_name(g)
    if g.note and g.post then name = string.upper(g.note:gsub(" Presented.*", "")) .. ": " .. string.upper(g.opp_abbr or "") end
    G:text(where .. "  " .. name, 128, ty, px, WHITE, 1, "left", 400)
    local res, col
    if g.state == "post" and g.us and g.them then
      res = (g.won and "W " or "L ") .. g.us .. "-" .. g.them
      col = g.won and ORANGE_HI or {0.6, 0.6, 0.65}
    elseif g.state == "in" then
      res, col = "LIVE " .. (g.us or 0) .. "-" .. (g.them or 0), {1, 0.3, 0.3}
    elseif next_one then
      res, col = "NEXT  " .. kick_label(g), {1, 0.85, 0.3}
    else
      res, col = kick_label(g), {0.6, 0.6, 0.65}
    end
    G:text(res, BOARD_W - 200, ty, px, col, 1, "right", 180)
    quads[i] = lg.newQuad(0, y, BOARD_W, rh, BOARD_W, BOARD_H)
  end
  lg.pop()
  S.board = {cv = cv, quads = quads, n = n, sig = sig, rh = rh,
             head = lg.newQuad(0, 0, BOARD_W, BOARD_TOP, BOARD_W, BOARD_H)}
end

-- ------------------------------------------------------------------ legends
local CARDINAL, GOLD = {0.62, 0.1, 0.16}, {1, 0.8, 0.2}
local function banner(x, y, w, h, col, a, big, small)
  rgba(col, a)
  lg.rectangle("fill", x, y, w, h)
  lg.polygon("fill", x, y + h, x + w, y + h, x + w / 2, y + h + 26)
  lg.setColor(0.25, 0.2, 0.15, a)
  lg.rectangle("fill", x - 6, y - 8, w + 12, 8)
  local tc = col == WHITE and ORANGE or WHITE
  G:text(big, x, y + 18, 42, tc, a, "center", w)
  if small then G:text(small, x, y + h - 40, 15, tc, a, "center", w) end
end

-- the Rose Bowl replay: yards from the goal line (y, downfield is up) and across (x, -26.6 .. 26.6)
local RB_YD, RB_GOAL = 24, 300
local function rb_xy(x, y) return 384 + x * 13, RB_GOAL + y * RB_YD end
local function rb_path(k)
  -- the quarterback: the drop, a look, then out to the right and up to the pylon
  local pts = {{0, 13}, {-1, 15.5}, {1, 15}, {9, 12}, {19, 6}, {23, 1}, {24, -2.5}}
  local f = k * (#pts - 1)
  local i = min(floor(f) + 1, #pts - 1)
  local u = f - (i - 1)
  return lerp(pts[i][1], pts[i + 1][1], u), lerp(pts[i][2], pts[i + 1][2], u)
end

function D.legends(lt, len)
  if lt < 34 then
    -- the stadium's upper deck, the banners coming down
    if S.art.legends_wall then
      lg.setColor(1, 1, 1, 1)
      lg.draw(S.art.legends_wall, 0, 0)
    else
      G:gradient(0, 0, W, 300, {0.25, 0.5, 0.9}, {0.75, 0.85, 1})
      rgba(STONE)
      lg.rectangle("fill", 0, 160, W, 520)
      lg.setColor(0.8, 0.74, 0.6, 1)
      for i = 0, 7 do lg.rectangle("fill", 10 + i * 96, 180, 70, 60, 35, 35, 10) end
    end
    lg.setColor(1, 1, 1, 1)
    crowd_strip(680)
    local a0 = clamp((lt - 1.5) * 2, 0, 1)
    G:text("NATIONAL CHAMPIONS", 0, 262, 34, ORANGE, a0, "center", W)
    for i, yr in ipairs({"1963", "1969", "1970", "2005"}) do
      local k = ease(clamp((lt - 2 - i * 1.6) / 0.8, 0, 1))
      if k > 0 then banner(40 + (i - 1) * 176, lerp(120, 310, k), 160, 120, ORANGE, k, yr) end
    end
    local h1 = ease(clamp((lt - 13) / 0.8, 0, 1))
    local h2 = ease(clamp((lt - 16) / 0.8, 0, 1))
    if h1 > 0 or h2 > 0 then G:text("THE HEISMAN TROPHY", 0, 470, 30, {0.35, 0.25, 0.15}, max(h1, h2), "center", W) end
    if h1 > 0 then banner(100, lerp(400, 510, h1), 260, 130, WHITE, h1, "20", "EARL CAMPBELL  ·  1977") end
    if h2 > 0 then banner(408, lerp(400, 510, h2), 260, 130, WHITE, h2, "34", "RICKY WILLIAMS  ·  1998") end
    local f = clamp((lt - 31) / 3, 0, 1)
    if f > 0 then lg.setColor(0, 0, 0, f) lg.rectangle("fill", 0, 0, W, H) end
    return
  end
  -- the Rose Bowl: January 4, 2006, from above
  local r = lt - 34
  if S.art.rosebowl then
    lg.setColor(1, 1, 1, 1)
    lg.draw(S.art.rosebowl, 0, 0)
  else
  G:gradient(0, 0, W, H, {0.2, 0.5, 0.2}, {0.17, 0.44, 0.17})
  rgba(ORANGE)
  local gx, gy = rb_xy(0, 0)
  lg.setColor(0.45, 0.12, 0.15, 1)
  lg.rectangle("fill", 10, gy - 10 * RB_YD, W - 20, 10 * RB_YD)
  G:text("ROSE BOWL", 0, gy - 6.5 * RB_YD, 56, {1, 0.85, 0.3}, 0.8, "center", W)
  for yd = 0, 30, 5 do
    local _, y = rb_xy(0, yd)
    lg.setColor(1, 1, 1, yd % 10 == 0 and 0.9 or 0.55)
    lg.rectangle("fill", 10, y - 1, W - 20, 3)
    if yd % 10 == 0 and yd > 0 then G:text(tostring(yd), 24, y - 14, 26, WHITE, 0.8, "left", 60) end
  end
  -- the pylons
  rgba(ORANGE_HI)
  lg.rectangle("fill", 10, gy - 8, 10, 10)
  lg.rectangle("fill", W - 20, gy - 8, 10, 10)
  end
  local _, los = rb_xy(0, 8)
  local _, ftd = rb_xy(0, 3)
  local snap, run_t = 8, 6.5
  local k = clamp((r - snap) / run_t, 0, 1)
  local two = r > 17 and r < 26
  if not two then
    lg.setColor(0.2, 0.5, 1, 0.8)
    lg.rectangle("fill", 10, los - 2, W - 20, 4)
    lg.setColor(1, 0.85, 0.1, 0.8)
    lg.rectangle("fill", 10, ftd - 2, W - 20, 4)
  end
  -- the players
  local qx, qy
  if two then
    -- the two-point try: from the 3, the same quarterback, the same corner
    local k2 = clamp((r - 19.5) / 2.5, 0, 1)
    qx, qy = lerp(0, 18, ease(k2)), lerp(8, -2, k2)
  elseif r < snap then qx, qy = 0, 13
  elseif r < snap + run_t + 0.01 then qx, qy = rb_path(k)
  else qx, qy = 24, -2.5 end
  local base = two and 3 or 8
  local off = {{-6, 0.5}, {-3, 0.5}, {0, 0.5}, {3, 0.5}, {6, 0.5}, {-20, 0.5}, {20, 0.5}, {-14, 1}, {14, 1}, {3, base == 3 and 5 or 5}}
  local def = {{-4.5, -1}, {-1.5, -1}, {1.5, -1}, {4.5, -1}, {-8, -4}, {0, -4}, {8, -4}, {-20, -2}, {20, -2}, {-10, -8}, {10, -8}}
  local moving = (two and r > 19.5) or (not two and r > snap)
  for i, p in ipairs(def) do
    local dx, dy = p[1], base + p[2]
    if moving then
      -- the defence chases him toward the right, a step late
      local f = two and clamp((r - 19.5) / 2.5, 0, 1) or k
      local tx, ty = qx - 3 - (i % 3), qy + 1 + (i % 4) * 0.8
      dx, dy = lerp(dx, tx, f * 0.75), lerp(dy, ty, f * 0.75)
    end
    local x, y = rb_xy(dx, dy)
    rgba(CARDINAL)
    lg.circle("fill", x, y, 12, 14)
    rgba(GOLD)
    lg.circle("fill", x, y, 4.5, 8)
  end
  for i, p in ipairs(off) do
    local x, y = rb_xy(p[1], base + p[2] + (moving and -0.8 or 0))
    if i >= 6 and i <= 9 and moving then x, y = rb_xy(p[1] * 0.7, base - 3 - (i % 2) * 2) end
    rgba(ORANGE_HI)
    lg.circle("fill", x, y, 12, 14)
    lg.setColor(1, 1, 1, 1)
    lg.circle("fill", x, y, 4.5, 8)
  end
  local x, y = rb_xy(qx, qy)
  S.rb_x, S.rb_y = x, y
  C.fx.glow(x, y, 50, 50, 1, 0.6, 0.2, 0.5)
  rgba(ORANGE_HI)
  lg.circle("fill", x, y, 15, 16)
  G:text("10", x - 20, y - 10, 18, WHITE, 1, "center", 40)
  -- the scoreboard
  local us = (r > snap + run_t) and 39 or 33
  if r > 22.5 then us = 41 end
  lg.setColor(0.02, 0.02, 0.06, 0.82)
  lg.rectangle("fill", 0, 0, W, 64)
  G:text("TEXAS  " .. us, 18, 16, 30, ORANGE_HI, 1, "left", 300)
  G:text("USC  38", W - 318, 16, 30, {1, 0.75, 0.3}, 1, "right", 300)
  local mid = r < snap + run_t and "4TH & 5  ·  THE 8" or (us == 39 and "0:19 LEFT" or "0:19 LEFT")
  G:text(mid, 0, 20, 22, WHITE, 0.9)
  -- the words
  if r < snap then
    G:plate("JAN 4, 2006  ·  PASADENA", 760, 30, 0xffffff, L.window(r, 0.3, snap - 0.3, 0.6))
    G:plate("FOURTH AND FIVE. DOWN BY FIVE.", 820, 30, 0xffb347, L.window(r, 2, snap - 0.3, 0.6))
  end
  if r > snap + run_t and r < 19 then
    G:caption("TOUCHDOWN TEXAS!", 520, 64, 0xff8c1a, clamp((r - snap - run_t) * 2, 0, 1), 1 + 0.06 * abs(sin(r * 5)))
  end
  if two and r < 22.5 then G:plate("THE TWO-POINT TRY", 160, 30, 0xffffff, L.window(r, 17.5, 22.5, 0.4)) end
  if r > 24 then
    local a = clamp((r - 24) * 1.5, 0, 1)
    lg.setColor(0.75, 0.34, 0, 0.35 * a)
    lg.rectangle("fill", 0, 0, W, H)
    G:caption("NATIONAL CHAMPIONS", 420, 64, 0xff8c1a, a, 1 + 0.05 * abs(sin(r * 4)))
    G:plate("TEXAS 41  ·  USC 38", 520, 34, 0xffffff, a)
  end
  -- the team running in from everywhere to a dogpile, then the crystal trophy raised over it
  if r > 30 then
    local px, py = 384, 880
    for i = 1, 22 do
      local a0 = i * 2.4
      local f = clamp((r - 30 - (i % 7) * 0.15) / 2.5, 0, 1)
      local sx, sy = 384 + cos(a0) * 520, 780 + sin(a0) * 420
      local tx, ty = px + cos(a0) * (10 + (i % 5) * 14), py - floor(i / 6) * 22 + sin(a0) * 10
      local x, y = lerp(sx, tx, f), lerp(sy, ty, f) - (f < 1 and abs(sin(r * 10 + i)) * 10 or 0)
      rgba(i % 4 == 0 and WHITE or ORANGE_HI)
      lg.circle("fill", x, y, 13, 12)
    end
    -- the cast storm the field from both sides, onto the pile one by one; Pac-Man up on top
    if r > 37 then
      for i, who in ipairs({1, 2, 3, 4, 0}) do
        local side = i % 2 == 0 and 1 or -1
        local t0 = 37 + i * 0.8
        local f = prog(r, t0, t0 + 1.4)
        local tx, ty = px + (i - 2.5) * 46, py - 60 + abs(i - 2.5) * 8
        if who == 0 then tx, ty = px, py - 120 end
        local x = lerp(px + side * 560, tx, f)
        local y = lerp(980, ty, f) - sin(f * pi) * 140
        local bounce = r > 46 and L.hop(S.t + i * 0.2, 0.5, 10) or 0
        cast(who, x, y - bounce, 36, 0, -0.6, "happy", nil, r > 46 and who ~= 0)
      end
    end
    if r > 35 then
      local up = clamp((r - 35) / 2, 0, 1)
      local ty = lerp(880, 800, up) - abs(sin(r * 3)) * 6
      if r > 41 then ty = lerp(800, 690, prog(r, 41, 42.5)) - abs(sin(r * 3)) * 8 end    -- (up in Pac-Man's hands)
      C.fx.glow(px, ty - 40, 70, 90, 0.75, 0.9, 1, 0.5 * up)
      lg.setColor(0.8, 0.92, 1, 0.9)
      lg.ellipse("fill", px, ty - 50, 26, 40, 20)
      lg.setColor(1, 1, 1, 0.7)
      lg.ellipse("fill", px - 8, ty - 62, 6, 14, 10)
      lg.setColor(0.25, 0.2, 0.15, 1)
      lg.rectangle("fill", px - 18, ty - 12, 36, 20, 3, 3, 4)
      rgba(ORANGE_HI)
      lg.circle("fill", px - 24, ty + 10, 12, 12)
      lg.circle("fill", px + 24, ty + 10, 12, 12)
    end
  end
end

-- ------------------------------------------------------------------ the Hex Rally
local HEX_LINES = {
  {3, 15, "1941: STUDENTS ASKED A FORTUNE TELLER", "HOW TO BEAT THE AGGIES"},
  {15, 27, "SHE TOLD THEM: BURN RED CANDLES", "THE WEEK BEFORE THE GAME"},
  {27, 38, "THEY DID. TEXAS WON, 23-0.", "THE HEX HAS BEEN BURNING SINCE"},
}
-- the fortune teller's crystal ball over the Mall (3-39): her mist, then a red candle in it, then 23-0; at 39 it
-- bursts and every candle flares
local function crystal(lt)
  local a = prog(lt, 3, 5) * (1 - prog(lt, 38.6, 39.2))
  if a <= 0 then return end
  local x, y, r = 384, 400, 120
  lg.setBlendMode("add")
  C.fx.glow(x, y, r * 2.2, r * 2.2, 0.6, 0.3, 0.9, 0.5 * a)
  lg.setBlendMode("alpha")
  lg.setColor(0.18, 0.1, 0.3, 0.85 * a)
  lg.circle("fill", x, y, r, 48)
  -- the mist swirling inside
  for k = 0, 7 do
    local ang = S.t * (0.6 + k * 0.1) + k
    lg.setColor(0.7, 0.55, 1, 0.18 * a)
    lg.ellipse("fill", x + cos(ang) * r * 0.45, y + sin(ang * 1.3) * r * 0.35, r * 0.5, r * 0.22, 20)
  end
  -- what it shows: a red candle lit (15-27), then the score (27-38)
  local c = L.window(lt, 15, 27, 0.6) * a
  if c > 0 then
    lg.setColor(0.75, 0.08, 0.1, c)
    lg.rectangle("fill", x - 14, y - 10, 28, 70, 4, 4, 4)
    if lt > 16.5 then
      lg.setBlendMode("add")
      C.fx.glow(x, y - 26, 40, 50, 1, 0.6, 0.2, c)
      lg.setBlendMode("alpha")
      lg.setColor(1, 0.85, 0.4, c)
      lg.ellipse("fill", x, y - 24 + sin(S.t * 9) * 2, 7, 13, 12)
    end
  end
  local sc = L.window(lt, 27, 38.5, 0.6) * a
  if sc > 0 then G:text("23-0", x - r, y - 34, 60, {1, 0.75, 0.35}, sc, "center", r * 2) end
  -- the glass: a rim of light, a shine; the fortune teller's hands under it
  lg.setColor(0.85, 0.75, 1, 0.6 * a)
  lg.setLineWidth(4)
  lg.circle("line", x, y, r, 48)
  lg.setColor(1, 1, 1, 0.35 * a)
  lg.ellipse("fill", x - r * 0.4, y - r * 0.5, r * 0.25, r * 0.12, 16)
  lg.setColor(0.45, 0.2, 0.5, a)
  lg.polygon("fill", x - r * 0.7, y + r * 0.85, x + r * 0.7, y + r * 0.85, x + r, y + r * 1.25, x - r, y + r * 1.25)
  lg.setColor(0.9, 0.72, 0.58, a)
  lg.ellipse("fill", x - r * 0.95, y + r * 0.55, 24, 14, 14)
  lg.ellipse("fill", x + r * 0.95, y + r * 0.55, 24, 14, 14)
end
function D.hex(lt, len)
  local warm = clamp((lt - 52) / 4, 0, 1)
  if S.art.tower_dark then
    lg.setColor(1, 1, 1, 1)
    lg.draw(S.art.tower_dark, 0, 0)
    if warm > 0 and S.art.tower_win then lg.setColor(1, 1, 1, warm) lg.draw(S.art.tower_win, 0, 0) end
    twinkle(40, 560)
  else
    G:gradient(0, 0, W, 760, {0.02, 0.02, 0.07}, {0.1, 0.04, 0.1})
    for i, s in ipairs(S.stars) do
      lg.setColor(1, 1, 0.9, 0.3 + 0.4 * abs(sin(S.t * 0.6 + i)))
      lg.rectangle("fill", s[1], s[2], 2, 2)
    end
    tower(384, 700, 1.0, warm > 0.5 and "win" or "dark")
    G:gradient(0, 700, W, H, {0.05, 0.04, 0.05}, {0.02, 0.02, 0.03})
  end
  crystal(lt)
  -- the crowd on the Main Mall, a candle each, lit from the front out
  for _, c in ipairs(S.candles) do
    lg.setColor(0.04, 0.03, 0.05, 1)
    lg.circle("fill", c[1], c[2] - 16 * c[4], 7 * c[4], 8)
    lg.rectangle("fill", c[1] - 7 * c[4], c[2] - 10 * c[4], 14 * c[4], 26 * c[4])
    lg.setColor(0.75, 0.08, 0.1, 1)
    lg.rectangle("fill", c[1] + 6 * c[4], c[2] - 6 * c[4], 4 * c[4], 12 * c[4])
  end
  -- the flames, all in one additive pass
  lg.setBlendMode("add")
  local flare = (lt > 39 and lt < 40.5) and 1.6 or 1
  for _, c in ipairs(S.candles) do
    if lt > 19 + c[3] * 19 then
      local fl = (0.8 + 0.2 * sin(S.t * 12 + c[5])) * flare
      lg.setColor(1, 0.45, 0.1, 0.25 * fl)
      lg.circle("fill", c[1] + 8 * c[4], c[2] - 10 * c[4], 14 * c[4], 10)
      lg.setColor(1, 0.85, 0.4, fl)
      lg.ellipse("fill", c[1] + 8 * c[4], c[2] - 9 * c[4], 2.5 * c[4], 4 * c[4], 8)
    end
  end
  lg.setBlendMode("alpha")
  -- the cast in front, a red candle each: Pac-Man's match first (17.5), passed along
  for i, who in ipairs({1, 2, 0, 3, 4}) do
    local x = lerp(-100 - i * 70, 220 + (i - 1) * 82, prog(lt, 1 + i * 0.4, 5 + i * 0.4))
    local y = 1010 - 34
    cast(who, x, y, 34, 0, (lt > 3 and lt < 39) and -1 or 0, (lt > 39) and "happy" or nil)
    lg.setColor(0.75, 0.08, 0.1, 1)
    lg.rectangle("fill", x + 30, y - 6, 9, 30, 2, 2, 4)
    local lit = 17.5 + abs(i - 3) * 0.6
    if lt > lit then
      lg.setBlendMode("add")
      C.fx.glow(x + 34, y - 14, 26, 30, 1, 0.55, 0.15, 0.7 * flare)
      lg.setBlendMode("alpha")
      lg.setColor(1, 0.85, 0.4, 1)
      lg.ellipse("fill", x + 34, y - 14 + sin(S.t * 10 + i), 4, 8 * flare, 10)
    end
  end
  if lt > 16.6 and lt < 17.6 then
    for k = 1, 2 do G:spark(384 - 10, 960, (G.R:random() - 0.5) * 120, -60 - G.R:random() * 80, 0.4, {1, 0.7, 0.3}, 4, 200, true) end
  end
  -- the warm glow of all of them over the Mall
  local n = clamp((lt - 18) / 20, 0, 1)
  C.fx.glow(384, 900, 420, 160, 1, 0.3, 0.05, 0.35 * n)
  for _, l in ipairs(HEX_LINES) do
    local a = L.window(lt, l[1], l[2], 0.8)
    if a > 0 then
      G:text(l[3], 0, 130, 26, {1, 0.85, 0.7}, a, "center", W)
      G:text(l[4], 0, 166, 26, {1, 0.85, 0.7}, a, "center", W)
    end
  end
  if lt > 39 then
    G:caption("THE HEX IS ON", 150, 72, 0xff3b3b, clamp((lt - 39) * 1.5, 0, 1), 1 + 0.04 * sin(S.t * 3))
    local st = S.status or {}
    local g = ut.next()
    local line = "EVERY YEAR, THE WEEK OF THE A&M GAME"
    if st.week == "lonestar" and g then
      line = "THIS WEEK: " .. ((g.home and "VS ") or "AT ") .. "TEXAS A&M  ·  " .. day_label(g.day)
    end
    G:plate(line, 240, 26, 0xffd0a0, clamp((lt - 42) * 1.5, 0, 1) * L.window(lt, 42, len - 1, 1))
  end
end

-- ------------------------------------------------------------------ the camera (SHOWS_BLUEPRINT.md)
local CAM = {}
-- CUES[scene] = {{t, sfx[, gain]} or {t, function}}: timed sounds and happenings (as the other shows)
local CUES = {}
CUES.redriver = {{5, "chime", 0.5}, {12, "whoosh", 0.5}, {20, "boing", 0.4}, {34, "honk", 0.5}, {36.5, "power", 0.5},
                 {42, "pop", 0.6}, {46, "whistle", 0.6}, {74, "chime"}, {74.2, "cheer"}}
for k = 0, 5 do CUES.redriver[#CUES.redriver + 1] = {38.3 + k * 0.67, "pew", 0.3} end
for k = 1, 4 do CUES.redriver[#CUES.redriver + 1] = {46 + 7 * k, "cheer", 0.7} CUES.redriver[#CUES.redriver + 1] = {46 + 7 * k, "boom", 0.3} end
CUES.campus = {{1, "ding", 0.4}, {2.2, "ding", 0.4}, {3.4, "ding", 0.5}, {11, "boing"}, {15, "crackle", 0.5}, {15.2, "sizzle"},
               {17.3, "pop", 0.4}, {19.8, "pop", 0.4}, {22.3, "pop", 0.4}, {27, "whoosh", 0.5}, {29.6, "boing"}, {34, "whoosh", 0.5},
               {36.4, "power", 0.6}, {42, "moo"}, {44, "cheer"}, {56, "cheer", 0.6}}
CUES.hex = {{3.2, "chime", 0.5}, {15, "chime", 0.4}, {16.6, "crackle", 0.5}, {17.5, "whoosh", 0.3}, {27, "ding"}, {38.7, "boom", 0.5},
            {39.2, "cheer", 0.6}, {52, "chime"}}
-- the band: the drum major's whistle, Big Bertha's beat as she rolls by, the formation's final note
CUES.band = {{3, "whistle", 0.6}, {36, "whoosh", 0.4}, {40, "whistle", 0.5}, {54, "chime"}, {54.2, "cheer"}}
for t = 6, 34, 2 do CUES.band[#CUES.band + 1] = {t, "boom", 0.22} end
-- Smokey: the flag run, the Herd, the team through the smoke
CUES.smokey = {{24, "whoosh"}, {26, "cheer", 0.5}, {35, "cheer", 0.4}, {49.6, "boom", 0.6}, {50, "cheer"}, {56, "whistle", 0.5},
               {62, "cheer", 0.5}}
-- Hook 'em: the cards turned up, the hand, the chant's beat
CUES.hookem = {{4, "whoosh", 0.4}, {10, "ding"}, {14, "whoosh"}, {22, "cheer"}}
for t = 4.4, 9.6, 0.4 do CUES.hookem[#CUES.hookem + 1] = {t, "tape", 0.15} end
for k = 0, 30 do CUES.hookem[#CUES.hookem + 1] = {22 + k * 1.1, "boom", 0.2} end
-- the drive: each snap, each tackle, a first down
CUES.drive = {}
for k = 1, 6 do
  local t0 = 4 + (k - 1) * 9.5
  CUES.drive[#CUES.drive + 1] = {t0 + 1.0, "whistle", 0.25}
  CUES.drive[#CUES.drive + 1] = {t0 + 1.2, "pop", 0.4}
  if k < 6 then
    CUES.drive[#CUES.drive + 1] = {t0 + 4.5, "boom", 0.3}
    CUES.drive[#CUES.drive + 1] = {t0 + 4.7, "cheer", 0.35}
  end
end
-- Legends: the replay's snap and the run
CUES.legends = {{34, "whoosh"}, {39.5, "whistle", 0.5}, {40, "pop", 0.5}, {44, "whoosh", 0.5}, {71, "cheer"}, {75, "chime"},
                {75.2, "cheer", 0.7}, {80, "cheer", 0.5}}
for i = 1, 5 do CUES.legends[#CUES.legends + 1] = {34 + 37 + i * 0.8 + 1.4, "boing", 0.4} end
CUES.tower = {{4, "ding", 0.4}, {22.2, "boom", 0.5}, {22.4, "cheer"}, {46, "whoosh"}, {48, "chime"}, {48.1, "cheer"}}
for k = 1, 12 do CUES.tower[#CUES.tower + 1] = {10 + k, "chime", 0.18 + k * 0.02} end
local function cues(name, lt, dt)
  for _, c in ipairs(CUES[name] or {}) do
    if lt - dt < c[1] and lt >= c[1] then
      if type(c[2]) == "function" then c[2]() else C.sfx(c[2], c[3]) end
    end
  end
end
CAM.campus = function(lt)
  -- with the ball in the air, and with Bevo as he goes by
  local bx, by = ball_at(lt)
  if bx and lt > 27.4 then return L.shot(0, {{0, bx, by + 40, 1.5}}, W, H) end
  if lt > 42.5 and lt < 55 then return L.shot(0, {{0, clamp(bevo_x(lt) + 40, 260, 508), 880, 1.5}}, W, H) end
  return L.shot(lt, {{0, 384, 512, 1}, {5, 384, 300, 1.35}, {9, 384, 300, 1.35}, {12, 230, 860, 1.8}, {24, 230, 860, 1.8},
                     {27, 160, 860, 1.5}, {29.6, 560, 880, 1.6}, {33.5, 560, 880, 1.6}, {36.4, 300, 860, 1.5}, {40, 300, 860, 1.6},
                     {42.5, 440, 880, 1.5}, {55, 220, 880, 1.5}, {58, 384, 760, 1.15}, {64, 384, 600, 1.05}, {70, 384, 512, 1}}, W, H)
end
CAM.season = function(lt)
  if (S.games and #S.games > 0) and S.board then
    local n = S.board.n
    local t_end = 2.5 + n * ROW_DT
    if lt < t_end then
      local i = clamp(floor((lt - 2.5) / ROW_DT) + 1, 1, n)
      return L.shot(0, {{0, 384, 96 + BOARD_TOP + (i - 1) * S.board.rh, lerp(1, 1.5, clamp((lt - 1) / 2, 0, 1))}}, W, H)
    end
    local _, rt0, rt1 = replays(n)
    return L.shot(lt, {{t_end, 384, 512, 1}, {rt0, 384, 480, 1.15}, {rt1, 384, 480, 1.15}, {rt1 + 1.5, 384, 512, 1},
                       {rt1 + 5, 384, 760, 1.25}, {rt1 + 12, 330, 800, 1.3}, {rt1 + 17, 384, 512, 1}}, W, H)
  end
  -- the chalkboard: in on the play as it is drawn and run, out for each touchdown
  if lt < 6 then return L.shot(lt, {{0, 384, 512, 1}, {3, 384, 200, 1.6}, {6, 384, 200, 1.6}}, W, H) end
  local pt = (lt - 6) % 12
  return L.shot(pt, {{0, 384, 600, 1.05}, {2, 384, 640, 1.45}, {5.5, 384, 600, 1.5}, {9, 384, 420, 1.35}, {11.5, 384, 512, 1.05}}, W, H)
end
CAM.hookem = function(lt)
  local c1, cN = S.stunt[1], S.stunt[#S.stunt]
  local sx, sy = (c1[1] + cN[1]) / 2, (c1[2] + cN[2]) / 2
  return L.shot(lt, {{0, 384, 512, 1}, {4, c1[1] + 60, sy, 2.0}, {10, cN[1] - 60, sy, 2.0}, {13, sx, sy, 1.3}, {16, 384, 860, 1.5},
                     {24, 384, 860, 1.5}, {28, 384, 512, 1}, {36, sx, sy, 1.4}, {44, 384, 760, 1.2}, {52, 384, 512, 1}}, W, H)
end
CAM.redriver = function(lt)
  if lt > RIDE[1] + 1 and lt < RIDE[2] - 1 then
    local gx, gy = gondola_at(lt)
    local x, y, z = L.shot(lt, {{RIDE[1] + 1, 600, 360, 1.6}, {RIDE[1] + 3, gx, gy + 30, 1.9}, {RIDE[2] - 3, gx, gy + 30, 1.9},
                                {RIDE[2] - 1, 600, 360, 1.5}}, W, H)
    if lt > RIDE[1] + 3 and lt < RIDE[2] - 3 then return L.shot(0, {{0, gx, gy + 30, 1.9}}, W, H) end
    return x, y, z
  end
  return L.shot(lt, {{0, 384, 512, 1}, {4, 180, 300, 1.5}, {11, 180, 300, 1.5}, {13, 600, 360, 1.6}, {33, 600, 360, 1.5},
                     {35, 260, 860, 1.5}, {44, 300, 860, 1.5}, {46, 384, 760, 1.15}, {52, 200, 820, 1.4}, {60, 560, 760, 1.4},
                     {68, 384, 760, 1.1}, {74, 384, 700, 1.3}, {82, 384, 800, 1.4}, {90, 384, 512, 1}}, W, H)
end
CAM.drive = function(lt)
  local los, play, pt = drive_state(lt)
  if not play then
    local t = lt - (#PLAYS * PLAY_T + 4)
    return L.shot(t, {{0, 384, 512, 1}, {4, 384, 400, 1.4}, {10, 384, 640, 1.3}, {16, 384, 400, 1.3}, {22, 384, 512, 1}}, W, H)
  end
  -- in on the line before the snap, following the play upfield, out for the next huddle
  local gain = play[2]
  local k = clamp((pt - 1.2) / 3.2, 0, 1)
  local y = 640 - ease(k) * gain * YD * 0.8
  local z = pt < 1 and lerp(1, 1.6, pt) or (pt < 6 and 1.6 or lerp(1.6, 1.05, clamp((pt - 6) / 2, 0, 1)))
  return L.shot(0, {{0, 384 + (play[3] or 0) * YD * 0.5 * k, y, z}}, W, H)
end
CAM.legends = function(lt)
  if lt < 34 then
    return L.shot(lt, {{0, 384, 512, 1}, {3, 200, 400, 1.6}, {8, 560, 400, 1.6}, {12, 384, 400, 1.3}, {18, 384, 640, 1.5},
                       {26, 384, 640, 1.5}, {30, 384, 512, 1}}, W, H)
  end
  local r = lt - 34
  if r > 6 and r < 22 and S.rb_x then return L.shot(0, {{0, S.rb_x, S.rb_y - 40, 1.6}}, W, H) end
  return L.shot(r, {{0, 384, 512, 1}, {4, 384, 560, 1.3}, {6, 384, 560, 1.5}, {22, 384, 512, 1.1}, {29, 384, 512, 1}, {33, 384, 820, 1.4},
                     {37, 384, 800, 1.15}, {41, 384, 760, 1.4}, {47, 384, 720, 1.7}, {53, 384, 760, 1.4}, {58, 384, 512, 1}}, W, H)
end
CAM.smokey = function(lt)
  return L.shot(lt, {{0, 384, 512, 1}, {2, 480, 760, 1.6}, {10, 480, 760, 1.6}, {14, 384, 640, 1.1}, {24, 200, 700, 1.4}, {34, 560, 700, 1.4},
                     {44, 384, 760, 1.3}, {50, 100, 880, 1.6}, {58, 384, 800, 1.3}, {66, 384, 512, 1}}, W, H)
end
CAM.band = function(lt)
  return L.shot(lt, {{0, 384, 512, 1}, {6, 150, 820, 1.5}, {16, 500, 820, 1.5}, {26, 384, 700, 1.1}, {32, 384, 512, 1}, {40, 384, 420, 1.3},
                     {50, 384, 560, 1.2}, {60, 384, 512, 1}}, W, H)
end
CAM.hex = function(lt)
  return L.shot(lt, {{0, 384, 512, 1}, {5, 384, 420, 1.3}, {14, 384, 420, 1.35}, {16.5, 384, 900, 1.6}, {20, 384, 900, 1.6},
                     {24, 384, 760, 1.2}, {27, 384, 440, 1.3}, {35, 384, 512, 1.05}, {39, 384, 512, 1}, {48, 384, 512, 1},
                     {52, 384, 360, 1.5}, {60, 384, 360, 1.5}, {66, 384, 512, 1}}, W, H)
end
CAM.tower = function(lt)
  return L.shot(lt, {{0, 384, 512, 1}, {5, 384, 860, 1.5}, {9, 384, 820, 1.2}, {22, 384, 512, 1}, {27, 200, 860, 1.5}, {33, 560, 860, 1.5},
                     {38, 384, 512, 1},
                     {46, 384, 400, 1.3}, {48, 384, 400, 1.6}, {49, 384, 512, 1, "cut"}, {58, 384, 512, 1}, {64, 384, 320, 1.4}, {70, 384, 880, 1.5},
                     {76, 200, 880, 1.5}, {80, 560, 880, 1.5}, {85, 384, 512, 1}}, W, H)
end

-- ------------------------------------------------------------------ the pictures, a scene at a time
local ART_OF = {open = {"open"}, campus = {"campus_dawn", "campus_day"}, season = {"crowd_close"},
                band = {"stadium_day", "field_long"}, smokey = {"stadium_day"}, hookem = {"crowd_close"}, drive = {"field_long"},
                legends = {"legends_wall", "rosebowl", "crowd_close"}, redriver = {"fair"}, hex = {"tower_dark", "tower_win"},
                tower = {"tower_dark", "tower_win", "tower_one"}}
art_for = function(k, with_next)
  local want = {}
  for _, n in ipairs(ART_OF[SCENES[k][2]] or {}) do want[n] = true end
  if with_next and SCENES[k + 1] then for _, n in ipairs(ART_OF[SCENES[k + 1][2]] or {}) do want[n] = true end end
  for n, img in pairs(S.art) do
    if not want[n] then
      if img then img:release() end
      S.art[n] = nil
    end
  end
  for n in pairs(want) do
    if S.art[n] == nil then S.art[n] = G:art("longhorns", n) or false end
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
  -- the painted pictures, when the SD card has them (else each scene draws itself live)
  S.art = {}
  -- (the pictures a scene at a time, the next scene's in the fade between: all twelve at once came to 14 MB)
  S.has = {stadium_day = G:has_art("longhorns", "stadium_day"), crowd_close = G:has_art("longhorns", "crowd_close")}
  S.art_k = select(4, scene_at(S.t))
  art_for(S.art_k, false)
  -- (the made crowds, only without the painted ones: 7400 rectangles painted at the start)
  if not S.has.stadium_day or not S.has.crowd_close then
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
  end
  -- the stands (a band of crowd: orange and white dots), painted once
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
  -- the Hex Rally's crowd: rows back from the front, lit from the middle of the front row out
  S.candles = {}
  for row = 0, 6 do
    local sc = 1.3 - row * 0.1
    local y = 1000 - row * 42
    local n = 12 + row
    for c = 0, n - 1 do
      local x = 20 + (c + (row % 2) * 0.5) * (W - 40) / n + (R:random() - 0.5) * 10
      local d = (abs(x - 384) / 384 * 0.6 + row / 6 * 0.4) * (0.85 + R:random() * 0.3)
      S.candles[#S.candles + 1] = {x, y, clamp(d, 0, 1), sc, R:random() * 6}
    end
  end
  table.sort(S.candles, function(a, b) return a[2] < b[2] end)
  for _, s in ipairs(SCENES) do if s[4] then G:label(s[4], 56, 0xffffff, s[1]) end end
  local at = {}
  for _, s in ipairs(SCENES) do at[s[2]] = s[1] end
  for _, l in ipairs({{"PRESENTS", 26, 0x6ef0c8, 0}, {"TEXAS", 96, 0xff8c1a, 0},
                      {"LONGHORNS", 54, 0xffffff, 0}, {"TEXAS!", 80, 0xff8c1a, at.hookem}, {"FIGHT!", 80, 0xffffff, at.hookem},
                      {"TOUCHDOWN TEXAS!", 64, 0xff8c1a}, {"THE GOLDEN HAT STAYS IN AUSTIN", 26, 0xffd23f, at.redriver},
                      {"THE EYES OF TEXAS ARE UPON YOU", 30, 0xffffff, at.tower + 68},
                      {"THE MAIN BUILDING  ·  THE TOWER", 28, 0xffffff, at.campus},
                      {"NATIONAL CHAMPIONS", 64, 0xff8c1a, at.legends + 34}, {"THE HEX IS ON", 72, 0xff3b3b, at.hex},
                      {"HERE COME THE LONGHORNS", 34, 0xff8c1a, at.smokey + 30}, {"THE HOOK 'EM HERD", 30, 0xffffff, at.smokey + 20},
                      {"JAN 4, 2006  ·  PASADENA", 30, 0xffffff, at.legends + 20},
                      {"FOURTH AND FIVE. DOWN BY FIVE.", 30, 0xffb347, at.legends + 20},
                      {"THE TWO-POINT TRY", 30, 0xffffff, at.legends + 40}, {"TEXAS 41  ·  USC 38", 34, 0xffffff, at.legends + 40},
                      {"AFTER EVERY WIN: AN ORANGE TOP", 30, 0xffd23f, at.tower}, {"THE TOWER IS ORANGE TONIGHT", 26, 0xffffff, at.tower},
                      {"A NATIONAL TITLE: ALL ORANGE, WITH A 1", 28, 0xffd23f, at.tower + 40}}) do
    G:label(l[1], l[2], l[3], l[4])
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
  local sc, lt, len, k = scene_at(S.t)
  cues(sc[2], lt, dt)
  -- the pictures: the next scene's loaded in the last moment of the fade to black, the last one's let go
  if k ~= S.art_k then S.art_k = k art_for(k, false) S.art_next = nil end
  if lt > len - 0.3 and not S.art_next then S.art_next = true art_for(k, true) end
  -- Smokey fires every ten seconds in its scene; the drive's touchdown; the tower's fireworks
  -- what the season knows, every two seconds (for the board, the hex, the tower)
  S.refresh = (S.refresh or 0) - dt
  if S.refresh <= 0 then
    S.refresh = 2
    S.games = ut.games()
    S.status = ut.status()
    if (sc[2] == "campus" and lt > 60) or sc[2] == "season" or not S.board then board_paint() end
    S.last = ut.last()
    if S.last and S.last.day then
      local y, m, d = S.last.day:match("^(%d+)-(%d+)-(%d+)")
      S.last_days = floor((os.time() - os.time({year = tonumber(y), month = tonumber(m), day = tonumber(d), hour = 12})) / 86400 + 0.5)
    end
  end
  if sc[2] == "season" and not (S.games and #S.games > 0) and lt > 6 then
    local pt, p0 = (lt - 6) % 12, (lt - dt - 6) % 12
    if pt >= 9 and p0 < 9 then C.sfx("cheer", 0.6) end
    if pt >= 5.2 and p0 < 5.2 then C.sfx("whistle", 0.5) end
    if pt >= 5.5 and p0 < 5.5 then C.sfx("whoosh", 0.4) end
    if pt >= 9 and p0 < 9 then
      local c = S.chalk
      if c then for i = 1, 30 do G:puff(c[1] + c[3] / 2 + (G.R:random() - 0.5) * 300, c[2] + 60, {1, 1, 1}, 40, (G.R:random() - 0.5) * 80, 1.4, 10, 0.5) end end
    end
  end
  if sc[2] == "season" and S.board and S.games and #S.games > 0 then
    -- the replays: a clash for each, a cheer for a win; the faceoff's horns
    local played, rt0, rt1 = replays(S.board.n)
    if lt > rt0 and lt < rt1 then
      local k, k0 = (lt - rt0) % REPLAY_DT, (lt - dt - rt0) % REPLAY_DT
      local g = S.games[played[floor((lt - rt0) / REPLAY_DT) + 1]]
      if k >= 0.8 and k0 < 0.8 then C.sfx("boom", 0.4) end
      if k >= 1.2 and k0 < 1.2 and g then C.sfx(g.won and "cheer" or "boing", g.won and 0.6 or 0.4) end
    end
    if lt >= rt1 and lt - dt < rt1 then C.sfx("whoosh") end
    if lt >= rt1 + 1 and lt - dt < rt1 + 1 then C.sfx("boom", 0.5) end
    if lt >= rt1 + 5 and lt - dt < rt1 + 5 then C.sfx("moo") end
  end
  if sc[2] == "season" and lt > 2.5 then
    local i = floor((lt - 2.5) / ROW_DT)
    if i >= 1 and i <= #(S.games or {}) and floor((lt - dt - 2.5) / ROW_DT) ~= i then C.sfx("tape", 0.25) end
  end
  if sc[2] == "legends" then
    if lt < 34 then
      for i = 1, 4 do if G:at(SCENES[8][1] + 2 + i * 1.6) then C.sfx("boom", 0.4) end end
    else
      if G:at(SCENES[8][1] + 34 + 14.5) or G:at(SCENES[8][1] + 34 + 22) then
        C.sfx("cheer") C.sfx("boom")
        for i = 1, 6 do G:rocket(100 + i * 95, 160 + G.R:random() * 200, {from = 1024, colours = {ORANGE_HI, WHITE}}) end
      end
      if G:at(SCENES[8][1] + 34 + 24) then G:confetti(160, {ORANGE_HI, WHITE, {1, 0.8, 0.3}}) end
    end
  end
  if sc[2] == "hex" and G:at(SCENES[10][1] + 39) then C.sfx("thunder", 0.6) end
  if sc[2] == "smokey" and lt < 24 and lt > 3 and floor((lt - dt - 3) / 6) ~= floor((lt - 3) / 6) then
    C.sfx("boom")
    for i = 1, 30 do G:puff(450 + G.R:random() * 60, 760 + G.R:random() * 30, {0.92, 0.92, 0.95}, 20 + G.R:random() * 30,
                            40 + G.R:random() * 60, 3, 14, 0.6) end
    -- the smoke ring, drifting up and away
    for k = 0, 15 do
      local a = k / 16 * 2 * pi
      G:puff(500 + cos(a) * 36, 640 + sin(a) * 18, {0.95, 0.95, 0.97}, 60 + sin(a) * 10, 50 + cos(a) * 26, 4, 10, 0.55)
    end
  end
  if sc[2] == "drive" then
    local k = #PLAYS * PLAY_T + 4
    if lt - dt < k and lt >= k then
      C.sfx("cheer") C.sfx("boom")
      for i = 1, 5 do G:rocket(150 + i * 100, 200 + G.R:random() * 150, {from = 1024, colours = {ORANGE_HI, WHITE}}) end
    end
  end
  if (sc[2] == "tower" and lt > 23) or (sc[2] == "redriver" and lt > HAT_T and lt < 88)
     or (sc[2] == "drive" and lt > #PLAYS * PLAY_T + 5) or (sc[2] == "legends" and lt > 34 + 25) then
    if (sc[2] == "drive" or sc[2] == "legends") and G.R:random() < dt * 3 then G:confetti(6, {ORANGE_HI, WHITE}) end
    S.fw = (S.fw or 0) - dt
    if S.fw <= 0 then
      S.fw = 0.7 + G.R:random() * 0.9
      G:rocket(150 + G.R:random() * 470, 100 + G.R:random() * 220, {from = 820, colours = {ORANGE_HI, WHITE, {1, 0.75, 0.3}}})
    end
  end
  if sc[2] == "smokey" and lt > 49 and G.R:random() < dt * 14 then
    G:puff(70 + G.R:random() * 60, 880 + G.R:random() * 60, {0.9, 0.9, 0.93}, 30 + G.R:random() * 30, 60 + G.R:random() * 60, 2.5, 22, 0.55)
  end
  if sc[2] == "campus" and G.R:random() < dt * 4 then
    local a = S.art.campus_day
    local gx = a and (G.R:random() > 0.5 and 230 or 625) or (70 + (G.R:random() > 0.5 and 570 or 0))
    G:puff(gx, a and (G.R:random() > 0.5 and 900 or 915) or 920, {0.85, 0.85, 0.88}, 40, 8, 2.5, 8, 0.35)
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
  local cam = (not S.celebrate) and CAM[sc[2]]
  local x, y, z = 384, 512, 1
  if cam then x, y, z = cam(lt, len) end
  G:look(x, y, z)
  D[sc[2]](lt, len)
  G:draw_back()
  G:draw_front()
  G:unlook()
  if sc[4] and sc[2] ~= "drive" then
    local hide_bug = sc[2] == "season" or sc[2] == "legends"
    G:plate(sc[4], (bug_lines() and not hide_bug) and 150 or 30, 56, 0xffffff, L.window(lt, 1.5, 9, 1))
  end
  if sc[5] then
    local b = L.window(lt, 2, len - 1.5, 1)
    lg.setColor(0.02, 0.02, 0.06, 0.55 * b)
    lg.rectangle("fill", 0, H - 50, W, 50)
    G:text(sc[5], 0, H - 38, 20, {1, 0.8, 0.55}, b)
  end
  if sc[2] ~= "open" and sc[2] ~= "season" and sc[2] ~= "legends" then scorebug() end
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
