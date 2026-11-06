-- Sweethearts: Valentine's Day, seven minutes (Feb 7-14 in AUTO):
--   0:00  STARLIGHT PRESENTS ... SWEETHEARTS                                       (Sweethearts)
--   0:08  They meet: Pac-Man and Ms. Pac-Man, each chased by a ghost, meet in the middle; the ghosts collide
--                                                                                   (Chase Me)
--   1:10  Candy hearts: conversation hearts filling a jar, arcade sayings on them   (Bubblegum)
--   2:20  A ghost's valentine: Blinky's card for Pinky                              (Serenade)
--   3:30  Date night: the diner, one milkshake, two straws, the others at the window (Doo-Wop)
--   4:50  A heart of dots: eaten from the top by both of them, meeting at the point, then fireworks
--                                                                                   (Our Waltz)
--   6:20  HAPPY VALENTINE'S DAY
local lg = love.graphics
local L = require("showlib")
local M = {}
local C, G
local W, H = 768, 1024
local LEN = 420
M.LEN = LEN
local sin, cos, floor, min, max, abs, pi = math.sin, math.cos, math.floor, math.min, math.max, math.abs, math.pi
local clamp, ease, lerp, mix = L.clamp, L.ease, L.lerp, L.mix
local function prog(lt, a, b) return ease((lt - a) / (b - a)) end
local function lin(lt, a, b) return clamp((lt - a) / (b - a), 0, 1) end

local SCENES = {
  {0, "open", "ve_open"},
  {8, "meet", "ve_chase", "THEY MEET", "PLAYER 1  ·  PLAYER 2  ·  TWO GHOSTS WHO DIDN'T LOOK"},
  {70, "candy", "ve_bubble", "CANDY HEARTS", "ARCADE SAYINGS  ·  ONE JAR"},
  {140, "card", "ve_serenade", "A GHOST'S VALENTINE", "BLINKY HAS SOMETHING TO ASK"},
  {210, "diner", "ve_doowop", "DATE NIGHT", "ONE MILKSHAKE  ·  TWO STRAWS"},
  {290, "dots", "ve_heart", "A HEART OF DOTS", "FROM THE TOP, BOTH WAYS"},
  {380, "finale", "ve_open"},
}
M.SEGMENTS = {}
for _, s in ipairs(SCENES) do if s[4] then M.SEGMENTS[#M.SEGMENTS + 1] = {s[1], s[4]} end end
M.THUMB = 1

local S
local CUES = {}
local function scene_at(t)
  local k = 1
  for i, s in ipairs(SCENES) do if t >= s[1] then k = i end end
  local s = SCENES[k]
  local e = SCENES[k + 1] and SCENES[k + 1][1] or LEN
  return s, t - s[1], e - s[1], k
end
local function rgba(c, a) lg.setColor(c[1], c[2], c[3], a or 1) end
local GHOSTS = {{1, 0.18, 0.2}, {1, 0.55, 0.85}, {0.25, 0.95, 1}, {1, 0.65, 0.2}}
local PINK, RED = {1, 0.45, 0.7}, {0.95, 0.15, 0.3}
local SAYINGS = {"BE MINE", "PLAYER 2?", "INSERT COIN", "HIGH SCORE", "1UP", "CO-OP?", "GAME ON", "WAKA WAKA",
                 "XOXO", "U R A 10", "READY!", "HOLD ME", "NO CONTINUES", "BONUS!", "TRUE LOVE", "LEVEL UP"}
local CANDY = {{1, 0.75, 0.82}, {0.8, 0.95, 0.75}, {1, 0.95, 0.65}, {0.8, 0.85, 1}, {1, 0.85, 0.7}, {0.95, 0.95, 0.95}}

-- A heart: two circles and a point; s is half its width.
local function heart(x, y, s)
  lg.circle("fill", x - s * 0.5, y, s * 0.54, 20)
  lg.circle("fill", x + s * 0.5, y, s * 0.54, 20)
  lg.polygon("fill", x - s * 1.02, y + s * 0.14, x + s * 1.02, y + s * 0.14, x, y + s * 1.25)
end

-- Ms. Pac-Man: the chomper, a bow, a beauty mark, lipstick.
local function ms(x, y, r, dir, t, al)
  al = al or 1
  C.fx.chomper(x, y, r, dir, t, al)
  local d = dir > 0 and 1 or -1
  lg.setColor(0.95, 0.1, 0.25, al)
  local bx, by = x + r * 0.15 * d, y - r * 0.92
  lg.polygon("fill", bx, by, bx - r * 0.5, by - r * 0.32, bx - r * 0.5, by + r * 0.28)
  lg.polygon("fill", bx, by, bx + r * 0.5, by - r * 0.32, bx + r * 0.5, by + r * 0.28)
  lg.setColor(0.3, 0.4, 1, al)
  lg.circle("fill", bx, by, r * 0.14, 10)
  lg.setColor(0.95, 0.1, 0.25, al)
  lg.circle("fill", x + r * 0.62 * d, y + r * 0.08, r * 0.1, 8)
  lg.setColor(0.1, 0.05, 0.1, al)
  lg.circle("fill", x - r * 0.25 * d, y + r * 0.35, r * 0.05, 6)
  lg.setLineWidth(max(1, r * 0.06))
  lg.line(x + r * 0.1 * d, y - r * 0.62, x + r * 0.25 * d, y - r * 0.78)
end

local function blush(x, y, r, a)
  lg.setColor(1, 0.4, 0.55, 0.6 * (a or 1))
  lg.ellipse("fill", x - r * 0.55, y + r * 0.25, r * 0.18, r * 0.1, 10)
  lg.ellipse("fill", x + r * 0.55, y + r * 0.25, r * 0.18, r * 0.1, 10)
end

local function sky_night()
  if S.art.night then
    lg.setColor(1, 1, 1, 1)
    lg.draw(S.art.night, 0, 0)
    return
  end
  G:gradient(0, 0, W, H, {0.08, 0.03, 0.16}, {0.3, 0.06, 0.25})
  for i, s in ipairs(S.stars) do
    lg.setColor(1, 0.9, 1, 0.3 + 0.4 * abs(sin(S.t * 0.7 + i)))
    lg.rectangle("fill", s[1], s[2], 2, 2)
  end
end

local function floaters(a)
  -- little hearts drifting up the screen
  for i, f in ipairs(S.floaters) do
    local y = H + 40 - ((S.t * f[3] + f[2]) % (H + 80))
    local x = f[1] + sin(S.t * 0.8 + i) * 20
    lg.setColor(f[4][1], f[4][2], f[4][3], 0.35 * (a or 1))
    heart(x, y, f[5])
  end
end

local D = {}

function D.open(lt, len)
  sky_night()
  floaters(1)
  local k = ease(lt / 3)
  lg.setColor(RED[1], RED[2], RED[3], 1)
  heart(384, 330, 120 * k * (1 + 0.04 * sin(S.t * 6)))
  local a = L.window(lt, 0.4, 4, 0.7)
  G:brand(620, a)
  G:caption("PRESENTS", 690, 26, 0x6ef0c8, a)
  G:caption("SWEETHEARTS", 650, 80, 0xff6fa8, L.window(lt, 4.2, 8, 0.7))
end

-- the maze corridor; a 24 s loop
function D.meet(lt, len)
  lg.setColor(0, 0, 0, 1)
  lg.rectangle("fill", 0, 0, W, H)
  lg.setColor(0.13, 0.2, 1, 1)
  lg.setLineWidth(5)
  lg.rectangle("line", 20, 380, W - 40, 100, 18, 18, 8)
  lg.rectangle("line", 20, 640, W - 40, 100, 18, 18, 8)
  lg.rectangle("line", 300, 120, 168, 200, 18, 18, 8)
  lg.rectangle("line", 300, 800, 168, 150, 18, 18, 8)
  local c = lt % 24
  local y = 560
  -- the dots ahead of them
  lg.setColor(1, 0.8, 0.7, 1)
  for i = 0, 22 do
    local x = 40 + i * 31
    local px = lerp(-40, 330, clamp(c / 8, 0, 1))
    local mx = lerp(W + 40, 438, clamp(c / 8, 0, 1))
    if x > px + 10 and x < mx - 10 then lg.rectangle("fill", x - 3, y - 3, 6, 6) end
  end
  if c < 8 then
    local k = c / 8
    C.fx.chomper(lerp(-40, 330, k), y, 30, 1, S.t, 1)
    ms(lerp(W + 40, 438, k), y, 30, -1, S.t, 1)
    C.fx.ghost(lerp(-200, 220, k), y, 30, GHOSTS[3], 1, S.t, false, false, 1)
    C.fx.ghost(lerp(W + 200, 548, k), y, 30, GHOSTS[2], -1, S.t, false, false, 1)
  else
    -- they hop up out of the way; the ghosts run into each other
    local j = clamp((c - 8) / 1.2, 0, 1)
    local py = y - sin(j * pi / 2) * 230
    C.fx.chomper(330 + j * 20, py, 30, 1, c < 9.2 and S.t or 0, 1)
    ms(438 - j * 20, py, 30, -1, c < 9.2 and S.t or 0, 1)
    local g = clamp((c - 8) / 1.6, 0, 1)
    local gx = lerp(220, 352, g)
    if c < 9.6 then
      C.fx.ghost(gx, y, 30, GHOSTS[3], 1, S.t, false, false, 1)
      C.fx.ghost(W - gx, y, 30, GHOSTS[2], -1, S.t, false, false, 1)
    else
      local b = min((c - 9.6) * 2, 1)
      C.fx.ghost(352 - b * 40, y + b * 20, 30, GHOSTS[3], 1, S.t, true, false, 1)
      C.fx.ghost(416 + b * 40, y + b * 20, 30, GHOSTS[2], -1, S.t, true, false, 1)
      for i = 0, 3 do
        local an = S.t * 4 + i * pi / 2
        lg.setColor(1, 1, 0.4, 1)
        L.star(384 + cos(an) * 60, y - 50 + sin(an) * 14, 7, an)
      end
    end
    if c > 10 then
      local hk = ease((c - 10) / 1)
      lg.setColor(RED[1], RED[2], RED[3], 1)
      heart(384, py - 90, 40 * hk * (1 + 0.08 * sin(S.t * 8)))
    end
  end
  local f = clamp((c - 22) / 2, 0, 1)
  if f > 0 then
    lg.setColor(0, 0, 0, f)
    lg.rectangle("fill", 0, 0, W, H)
  end
end

function D.candy(lt, len)
  if S.art.candy then
    lg.setColor(1, 1, 1, 1)
    lg.draw(S.art.candy, 0, 0)
  else
    G:gradient(0, 0, W, H, {1, 0.8, 0.86}, {0.95, 0.55, 0.7})
    floaters(0.6)
    -- the table
    lg.setColor(0.6, 0.3, 0.35, 1)
    lg.rectangle("fill", 0, 900, W, 124)
  end
  -- the hearts, one a second, into the jar (a pile in rows)
  local n = min(#S.candy, floor(lt / 1.0) + 1)
  for i = 1, n do
    local h = S.candy[i]
    local born = (i - 1) * 1.0
    local k = clamp((lt - born) / 1.1, 0, 1)
    local y = lerp(-60, h.y, k * k)
    if k >= 1 then y = h.y - abs(sin(min((lt - born - 1.1) * 8, pi))) * 10 * max(0, 1 - (lt - born - 1.1)) end
    lg.push()
    lg.translate(h.x, y)
    lg.rotate(h.rot * k + (1 - k) * sin(S.t * 3 + i))
    rgba(h.c)
    heart(0, -14, 34)
    if k < 1 then
      G:text(h.say, -44, -8, 13, {0.8, 0.2, 0.35}, 1, "center", 88)
    else
      -- settled in the pile: the printing as two short lines (a print each was 120 a frame: 54 fps on the cabinet)
      lg.setColor(0.8, 0.2, 0.35, 0.75)
      lg.rectangle("fill", -18, -4, 36, 3)
      lg.rectangle("fill", -12, 3, 24, 3)
    end
    lg.pop()
  end
  -- the jar's glass over them
  lg.setColor(0.85, 0.95, 1, 0.22)
  lg.rectangle("fill", 170, 420, 428, 480, 30, 30, 12)
  lg.setColor(1, 1, 1, 0.5)
  lg.setLineWidth(4)
  lg.rectangle("line", 170, 420, 428, 480, 30, 30, 12)
  lg.rectangle("fill", 196, 450, 14, 380, 6, 6, 4)
  lg.setColor(0.85, 0.3, 0.45, 1)
  lg.rectangle("fill", 200, 396, 368, 30, 8, 8, 4)
  local sn = lt % 16
  if sn > 9 and sn < 14 then
    local f = (sn - 9) / 5
    local px = lerp(-60, 300, math.min(f * 2, 1))
    if f > 0.6 then px = lerp(300, -60, (f - 0.6) / 0.4) end
    C.fx.chomper(px, 820, 40, f > 0.6 and -1 or 1, S.t, 1)
    if f > 0.45 and f < 0.6 then G:say("JUST ONE...", px, 760, 22, 1) end
  end
  -- the newest one, close up
  local i = min(floor(lt / 4) + 1, n)
  local h = S.candy[i]
  local a = min(clamp((lt % 4) * 3, 0, 1), clamp((4 - lt % 4) * 3, 0, 1))
  rgba(h.c, a)
  heart(384, 190, 110)
  G:text(h.say, 234, 210, 36, {0.8, 0.2, 0.35}, a, "center", 300)
end

function D.card(lt, len)
  local painted = S.art.door
  if painted then
    lg.setColor(1, 1, 1, 1)
    lg.draw(S.art.door, 0, 0)
    floaters(0.4)
  else
  sky_night()
  floaters(0.5)
  -- Pinky's door: a little house in the maze
  lg.setColor(0.2, 0.12, 0.3, 1)
  lg.rectangle("fill", 420, 420, 300, 500)
  lg.setColor(0.13, 0.2, 1, 1)
  lg.setLineWidth(5)
  lg.rectangle("line", 420, 420, 300, 500, 12, 12, 6)
  lg.setColor(1, 0.55, 0.85, 1)
  lg.rectangle("fill", 520, 380, 100, 8)
  lg.setColor(0.04, 0.02, 0.08, 1)
  lg.rectangle("fill", 500, 660, 140, 260, 70, 70, 16)
  G:gradient(0, 920, W, H, {0.2, 0.08, 0.2}, {0.1, 0.04, 0.1})
  end
  -- Blinky comes along with his card, trembling
  local bx = lerp(-80, 360, ease(lt / 16))
  local tremble = lt < 30 and sin(S.t * 30) * 2 or 0
  local by = 800 + sin(S.t * 2) * 6
  local trip = lt > 7 and lt < 10.5
  if trip then by = 800 + sin(clamp((lt - 7) / 0.5, 0, 1) * pi / 2) * 24 * (1 - clamp((lt - 9.5), 0, 1)) end
  S.card_bx, S.card_by = bx, by
  local open = clamp((lt - 22) / 3, 0, 1)
  local px = lerp(570, 520, open)
  -- after the YES (42): Pinky jumps; then the two twirl up round each other (46-56) and come down
  local py = 800 + sin(S.t * 2 + 1) * 6
  if lt > 42 and lt < 43.4 then py = py - L.hop(lt - 42, 1.4, 110) end
  local tw = (lt > 46 and lt < 57) and prog(lt, 46, 48) * (1 - prog(lt, 55, 57)) or 0
  if tw > 0 then
    local a = (lt - 46) * 3
    local mx, my = (bx + px) / 2, 760 - tw * 260
    bx, by = lerp(bx, mx + cos(a) * 80, tw), lerp(by, my + sin(a) * 30, tw)
    px, py = lerp(px, mx - cos(a) * 80, tw), lerp(py, my - sin(a) * 30, tw)
  end
  local sweat = lt > 38.5 and lt < 42
  C.fx.ghost(bx + tremble, by, 44, GHOSTS[1], 1, S.t, false, false, 1)
  if sweat then
    lg.setColor(0.6, 0.85, 1, 1)
    local d = ((S.t * 1.5) % 1)
    lg.ellipse("fill", bx + 30, by - 40 + d * 40, 5, 8, 8)
  end
  if open > 0 then C.fx.ghost(px, py, 44, GHOSTS[2], -1, S.t, false, false, 1) end
  -- Inky and Clyde out of the bushes (57-66) with confetti
  if lt > 57 then
    local k = prog(lt, 57, 58.2)
    C.fx.ghost(lerp(-60, 110, k), 860 - L.hop(S.t, 0.5, 14), 40, GHOSTS[3], 1, S.t, false, false, 1)
    C.fx.ghost(lerp(W + 60, 660, k), 860 - L.hop(S.t + 0.2, 0.5, 14), 40, GHOSTS[4], -1, S.t, false, false, 1)
  end
  -- the card: offered, then read
  local read = clamp((lt - 30) / 2, 0, 1)
  local cx, cy = lerp(bx + 60, 384, read), lerp(by - 10, 360, read)
  if trip then
    local f = clamp((lt - 7.2) / 2.3, 0, 1)
    cx, cy = lerp(bx + 60, bx + 70, f), by - 10 - sin(f * pi) * 260
  end
  local cw = lerp(60, 380, read)
  lg.setColor(1, 0.95, 0.97, 1)
  lg.rectangle("fill", cx - cw / 2, cy - cw * 0.35, cw, cw * 0.7, 6, 6, 4)
  lg.setColor(RED[1], RED[2], RED[3], 1)
  heart(cx, cy - cw * 0.18, cw * 0.12)
  if read > 0.9 then
    -- the lines, one at a time
    if lt > 32 then G:text("ROSES ARE RED", cx - 180, cy - 30, 22, {0.8, 0.2, 0.35}, 1, "center", 360) end
    if lt > 34.5 then G:text("PINKY, YOU'RE PINK", cx - 180, cy, 22, {0.8, 0.2, 0.35}, 1, "center", 360) end
    if lt > 37 then G:text("WILL YOU BE MY PLAYER 2?", cx - 180, cy + 30, 22, {0.8, 0.2, 0.35}, 1, "center", 360) end
    if lt > 37 then G:text("- B.", cx - 180, cy + 70, 18, {0.5, 0.3, 0.4}, 1, "right", 340) end
  end
  if trip and lt > 7.3 and lt < 9.5 then G:say("WHOA!", bx, by - 70, 24, 1) end
  if lt > 17 and lt < 21.5 then
    G:say(lt < 19.2 and "KNOCK KNOCK..." or "AHEM.", lt < 19.2 and 570 or bx, (lt < 19.2 and 600 or by - 70), 22, 1)
  end
  if lt > 25 and lt < 29 then G:say("FOR ME?", px, 730, 24, 1) end
  if lt > 39 and lt < 42 then G:say("...", px, 730, 28, 1) end
  if lt > 42 and lt < 45 then G:say("YES!!", px, 680, 34, 1) end
  if lt > 58 and lt < 62 then G:say("WOO-HOO!", 384, 760, 26, 1) end
  if lt > 42 then
    local a = clamp((lt - 42) / 2, 0, 1)
    blush(bx, by, 44, a)
    blush(px, 800, 44, a)
    G:plate("SHE SAID YES", 900, 34, 0xff6fa8, L.window(lt, 44, len - 2, 1))
    for i = 1, 6 do
      local k = ((S.t * 0.4 + i / 6) % 1)
      lg.setColor(1, 0.3, 0.5, 1 - k)
      heart((bx + px) / 2 + sin(i * 2 + S.t) * 50, 720 - k * 200, 14 + i % 3 * 4)
    end
  end
end

function D.diner(lt, len)
  local painted = S.art.diner
  if painted then
    lg.setColor(1, 1, 1, 1)
    lg.draw(S.art.diner, 0, 0)
  else
    sky_night()
    -- the diner window, the neon, the booth
    lg.setColor(0.12, 0.06, 0.15, 1)
    lg.rectangle("fill", 0, 300, W, 724)
  end
  local on = (floor(S.t * 2) % 7 ~= 0) and 1 or 0.3
  G:text("PAC'S DINER", 0, 150, 64, {1, 0.3, 0.55}, on, "center", W)
  C.fx.glow(384, 190, 300, 80, 1, 0.3, 0.6, 0.25 * on)
  if not painted then
  lg.setColor(0.25, 0.75, 0.75, 1)
  lg.rectangle("fill", 0, 300, W, 26)
  for i = 0, 15 do
    if i % 2 == 0 then lg.setColor(1, 1, 1, 1) else lg.setColor(0.05, 0.05, 0.05, 1) end
    lg.rectangle("fill", i * 48, 900, 48, 24)
  end
  -- the window behind the booth: Inky and Clyde peeking in
  lg.setColor(0.03, 0.03, 0.1, 1)
  lg.rectangle("fill", 80, 360, 608, 260, 10, 10, 4)
  end
  -- the others at the window: up (46), spotted (50: they duck), up again with a sign (52-56)
  local peek = lt - 46
  local pk = 0
  if peek > 0 and peek < 4 then pk = ease(min(1, peek)) elseif peek >= 4 and peek < 5.5 then pk = 1 - ease((peek - 4) / 0.3)
  elseif peek >= 5.5 and peek < 10 then pk = ease(min(1, (peek - 5.5) / 0.6)) elseif peek >= 10 then pk = 1 - ease(min(1, (peek - 10) / 0.6)) end
  if peek > 6 and peek < 10 then
    lg.setColor(1, 1, 1, 1)
    lg.rectangle("fill", 260, 640 - 130 * pk - 40, 250, 60, 8, 8, 4)
    G:text("GO PAC GO!", 260, 640 - 130 * pk - 26, 28, {0.9, 0.2, 0.4}, 1, "center", 250)
  end
  C.fx.ghost(180, 640 - 120 * pk, 40, GHOSTS[3], 1, S.t, false, false, 1)
  C.fx.ghost(590, 640 - 110 * clamp(pk * 1.3 - 0.3, 0, 1), 40, GHOSTS[4], -1, S.t, false, false, 1)
  if painted then
    -- the sill again, in front of the peeking ghosts
    S.sill_q = S.sill_q or lg.newQuad(80, 600, 608, 60, W, H)
    lg.setColor(1, 1, 1, 1)
    lg.draw(S.art.diner, S.sill_q, 80, 600)
  else
  lg.setColor(0.12, 0.06, 0.15, 1)
  lg.rectangle("fill", 80, 620, 608, 40)
  lg.setColor(0.9, 0.9, 1, 0.12)
  lg.polygon("fill", 120, 360, 200, 360, 120, 470)
  end
  -- the booth and the table
  if not painted then
  lg.setColor(0.8, 0.12, 0.2, 1)
  lg.rectangle("fill", 20, 640, 160, 260, 20, 20, 8)
  lg.rectangle("fill", 588, 640, 160, 260, 20, 20, 8)
  end
  local dance = (lt > 36 and lt < 45) and L.hop(S.t, 0.45, 26) or 0
  local spotted = lt > 50 and lt < 51.5
  -- leaving together (66-74): out of the booth, to the middle, off to the left, hearts behind
  local leave = prog(lt, 66, 74)
  local lx = lerp(0, -560, prog(lt, 69, 74))
  local pxx, pyy = lerp(220, 340, prog(lt, 66, 68)) + lx, 740 + 120 * prog(lt, 66, 68)
  local mxx = lerp(548, 428, prog(lt, 66, 68)) + lx
  -- each sip (every 3 s from 16): the sipper puffs up a moment; Pac-Man's brain freeze (28-31): blue, shivering
  local sip_t = (lt - 16) % 3
  local sipper = floor((lt - 16) / 3) % 2
  local puff = (lt > 16 and lt < 46 and sip_t < 0.6) and sin(sip_t / 0.6 * pi) * 0.18 or 0
  local freeze = lt > 28 and lt < 31
  if freeze then
    lg.push()
    lg.translate(pxx + sin(S.t * 50) * 4, pyy)
    lg.setColor(0.4, 0.6, 1, 0.5)
    lg.circle("fill", 0, 0, 56, 24)
    lg.pop()
  end
  lg.push()
  lg.translate(pxx + (freeze and sin(S.t * 50) * 4 or 0), pyy)
  if sipper == 0 then lg.scale(1 + puff, 1 + puff) end
  lg.translate(-pxx, -pyy)
  C.fx.chomper(pxx, pyy - dance - (leave > 0 and L.hop(S.t, 0.5, 10) or 0), 46, lt > 69 and -1 or 1, lt > 69 and S.t or 0, 1)
  lg.pop()
  if sipper == 1 and puff > 0 then
    lg.push() lg.translate(mxx, pyy) lg.scale(1 + puff, 1 + puff) lg.translate(-mxx, -pyy)
  end
  ms(mxx, pyy - dance - (leave > 0 and L.hop(S.t + 0.25, 0.5, 10) or 0), 46, -1, lt > 69 and S.t or 0, 1)
  if sipper == 1 and puff > 0 then lg.pop() end
  -- a heart out of the shake with every sip
  if lt > 16 and lt < 46 and sip_t < 1.2 then
    local f = sip_t / 1.2
    lg.setColor(1, 0.35, 0.6, 1 - f)
    heart(384 + (sipper == 0 and -1 or 1) * f * 60, 660 - f * 140, 16 + f * 10)
  end
  if freeze then G:say("BRAIN FREEZE!", pxx, 640, 22, 1) end
  if lt > 69 then
    for k = 1, 5 do
      local f = (S.t * 0.8 + k / 5) % 1
      lg.setColor(1, 0.45, 0.65, 1 - f)
      heart((pxx + mxx) / 2 + f * 80, 760 - f * 160, 10 + k % 3 * 4)
    end
  end
  -- Blinky skates back in to clear up (72-79), a wink
  if lt > 72 then
    local bx = L.path(lt, {{72, W + 100, 0}, {74.5, 450, 0}, {76.5, 450, 0}, {79, -120, 0}})
    C.fx.ghost(bx, 700, 44, GHOSTS[1], -1, S.t, false, false, 1)
    if lt > 74.5 and lt < 77 then G:say("TABLE FOR TWO? ANYTIME!", bx, 620, 20, 1) end
  end
  if spotted then G:say("HEY!", 384, 600, 28, 1) end
  if not painted then
  lg.setColor(0.85, 0.85, 0.9, 1)
  lg.rectangle("fill", 160, 790, 448, 24, 6, 6, 4)
  lg.rectangle("fill", 370, 814, 28, 90)
  end
  -- Blinky the waiter on roller skates (10-15): in from the right, a wobble, the shake set down
  if lt > 9 and lt < 18 then
    local bx = L.path(lt, {{9, W + 100, 0}, {12.5, 470, 0}, {13, 450, 0}, {14.5, 450, 0}, {18, W + 120, 0}})
    local wob = (lt > 12 and lt < 13.5) and sin(lt * 30) * 0.3 or 0
    lg.push()
    lg.translate(bx, 700)
    lg.rotate(wob)
    C.fx.ghost(0, 0, 44, GHOSTS[1], -1, S.t, false, false, 1)
    lg.setColor(1, 1, 1, 1)
    lg.rectangle("fill", -30, -60, 60, 14, 4, 4, 4)
    lg.setColor(0.3, 0.3, 0.35, 1)
    for k = -1, 1, 2 do lg.circle("fill", k * 20, 52, 8, 10) end
    if lt < 13 then
      lg.setColor(1, 0.7, 0.8, 1)
      lg.polygon("fill", -50, -60, -16, -60, -22, -110, -44, -110)
      lg.setColor(1, 1, 1, 1)
      lg.circle("fill", -33, -112, 14, 12)
    end
    lg.pop()
  end
  if lt < 13 then return end
  -- the milkshake, two straws: sipped down in steps (a sip each 3 s, 16-46), the last together (58)
  local sips = floor(clamp((lt - 16) / 3, 0, 10))
  local level = lt < 58 and (1 - sips * 0.08) or (1 - 0.8 - 0.12 * prog(lt, 58, 61))
  local turn = floor(lt / 3) % 2
  lg.setColor(0.9, 0.9, 0.95, 0.6)
  lg.polygon("fill", 344, 680, 424, 680, 410, 790, 358, 790)
  lg.setColor(1, 0.7, 0.8, 1)
  local top = 790 - 110 * level
  lg.polygon("fill", 358 - (790 - top) * 0.13 + 0, top, 410 + (790 - top) * 0.13, top, 410, 790, 358, 790)
  lg.setColor(1, 1, 1, 1)
  lg.circle("fill", 384, top - 4, 22, 16)
  lg.setColor(0.9, 0.1, 0.2, 1)
  if lt < len - 12 then
    lg.circle("fill", 384, top - 26, 8, 10)
  else
    local f = clamp((lt - (len - 12)) / 1.2, 0, 1)
    lg.arc("fill", "pie", lerp(384, 250, f), lerp(top - 26, 720, f), 8, pi / 2, 3 * pi / 2, 8)
    lg.arc("fill", "pie", lerp(384, 518, f), lerp(top - 26, 720, f), 8, -pi / 2, pi / 2, 8)
  end
  for k = 0, 2 do
    local f = (S.t * 2 + k / 3) % 1
    lg.setColor(1, 0.85, 0.9, 0.8)
    if turn == 0 then lg.circle("fill", lerp(372, 300, f), lerp(top, 660, f), 4, 6)
    else lg.circle("fill", lerp(396, 470, f), lerp(top, 660, f), 4, 6) end
  end
  lg.setColor(1, 1, 1, 1)
  lg.setLineWidth(5)
  lg.setColor(1, 0.4, 0.6, 1)
  lg.line(372, top, 330, 640, 272, 700)
  lg.setColor(0.4, 0.8, 1, 1)
  lg.line(396, top, 440, 640, 500, 700)
  -- the jukebox's notes, hearts over the table
  for i = 1, 5 do
    local k = (S.t * 0.25 + i / 5) % 1
    lg.setColor(1, 0.5, 0.7, (1 - k) * 0.9)
    heart(384 + sin(i * 3 + S.t) * 80, 660 - k * 260, 10 + (i % 3) * 4)
  end
  if peek > 0.5 and peek < 4 then G:say("AWWW!", 180, 470, 24, 1) end
  if lt > len - 11 and lt < len - 7 then G:say("HALF FOR YOU.", 548, 650, 22, 1) end
  if lt > 12.5 and lt < 15 then G:say("ONE SHAKE, TWO STRAWS!", 450, 560, 22, 1) end
  if lt > 22 and lt < 25 then G:say("SLUUURP!", turn == 0 and 220 or 548, 650, 22, 1) end
  if lt > 36 and lt < 39 then G:say("OUR SONG!", 548, 650, 24, 1) end
  -- the jukebox's notes burst out while they dance
  if lt > 35 and lt < 45 then
    for i = 1, 8 do
      local k = (S.t * 0.6 + i / 8) % 1
      local c = ({{1, 0.4, 0.7}, {0.4, 0.8, 1}, {1, 0.85, 0.3}})[i % 3 + 1]
      lg.setColor(c[1], c[2], c[3], 1 - k)
      local nx, ny = 384 + sin(i * 2.1 + S.t) * (120 + k * 160), 720 - k * 380
      lg.ellipse("fill", nx, ny, 12, 9, 10)
      lg.rectangle("fill", nx + 9, ny - 34, 4, 34)
    end
  end
end

local function heart_pt(u, cx, cy, sc)
  local x = 16 * sin(u) ^ 3
  local y = 13 * cos(u) - 5 * cos(2 * u) - 2 * cos(3 * u) - cos(4 * u)
  return cx + x * sc, cy - y * sc
end

-- the dots go round twice: the second time the ghosts chase them round (59 s later)
-- (each round: eaten from 3 s to 27 s, the meeting at 27; the second round starts at 46)
local function dots_t(lt) if lt < 46 then return lt, 1 end return lt - 43, 2 end
function D.dots(lt, len)
  lg.setColor(0, 0, 0, 1)
  lg.rectangle("fill", 0, 0, W, H)
  local round
  lt, round = dots_t(lt)
  local cx, cy, sc = 384, 470, 19
  -- round two: in a maze, its walls drawing themselves in
  if round == 2 then
    local m = clamp(lt / 4, 0, 1)
    lg.setColor(0.2, 0.3, 1, 1)
    lg.setLineWidth(6)
    for k, r in ipairs({{40, 90, 688, 780}, {90, 160, 120, 90}, {558, 160, 120, 90}, {90, 820, 180, 60}, {498, 820, 180, 60}}) do
      if m * 5 >= k - 1 then lg.rectangle("line", r[1], r[2], r[3] * min(1, m * 5 - (k - 1)), r[4], 16, 16, 8) end
    end
  end
  local eat = clamp((lt - 3) / 24, 0, 1)
  local done = lt - 27
  -- the big heart filling once they meet
  if done > 0 then
    local k = ease(done / 2)
    lg.setColor(RED[1], RED[2], RED[3], 1)
    lg.push()
    lg.translate(cx, cy + 20)
    lg.scale(k)
    heart(0, -60, 250 * (1 + 0.03 * sin(S.t * 5)))
    lg.pop()
    G:text("PLAYER 1", cx - 200, cy - 80, 34, {1, 1, 1}, k, "center", 400)
    G:text("+", cx - 200, cy - 30, 34, {1, 1, 1}, k, "center", 400)
    G:text("PLAYER 2", cx - 200, cy + 20, 34, {1, 1, 1}, k, "center", 400)
  end
  -- the heart filling in behind them as they eat, from the top down
  if done <= 0 and eat > 0 then
    lg.setColor(RED[1], RED[2], RED[3], 0.12 + 0.5 * eat)
    lg.push()
    lg.translate(cx, cy + 20)
    lg.scale(0.2 + 0.8 * eat)
    heart(0, -60, 250)
    lg.pop()
  end
  -- the dots: the right half for him, the left for her
  local N = 36
  for i = 0, N do
    local u = i / N * pi
    if u > eat * pi + 0.02 then
      local x, y = heart_pt(u, cx, cy, sc)
      local x2 = 2 * cx - x
      lg.setColor(1, 0.8, 0.7, 1)
      local big = (i % 12 == 6)
      local r = big and 9 * (0.6 + 0.4 * abs(sin(S.t * 5))) or 4
      lg.circle("fill", x, y, r, 10)
      lg.circle("fill", x2, y, r, 10)
    end
  end
  if done < 0.5 then
    local u = eat * pi
    local x, y = heart_pt(u, cx, cy, sc)
    local xa = heart_pt(max(u - 0.05, 0), cx, cy, sc)
    local dir = x >= xa and 1 or -1
    C.fx.chomper(x, y, 26, dir, S.t, 1)
    ms(2 * cx - x, y, 26, -dir, S.t, 1)
    if round == 2 and u > 0.35 then
      -- the ghosts chasing; at the power pellet (half way) they turn blue and run back the other way
      local scared = u > pi / 2
      local gu = scared and max(0, u - 0.3 - (u - pi / 2) * 2) or u - 0.3
      local gx, gy = heart_pt(gu, cx, cy, sc)
      local blink = scared and u > 2.6 and floor(S.t * 6) % 2 == 0
      C.fx.ghost(gx, gy, 24, GHOSTS[1], scared and -dir or dir, S.t, scared, blink, 1)
      C.fx.ghost(2 * cx - gx, gy, 24, GHOSTS[2], scared and dir or -dir, S.t, scared, blink, 1)
      if not scared and u > 1.1 then G:say("GOTCHA SOON!", gx, gy - 50, 20, 1) end
      if scared and u < 2 then G:say("EEK!", gx, gy - 50, 22, 1) end
    end
  else
    local x, y = heart_pt(pi, cx, cy, sc)
    local hop = done > 3 and abs(sin(S.t * 4)) * 20 or 0
    C.fx.chomper(x - 34, y + 30 - hop, 26, 1, done > 3 and S.t or 0, 1)
    ms(x + 34, y + 30 - hop, 26, -1, done > 3 and S.t or 0, 1)
    -- everyone round them
    local a = clamp(done / 3, 0, 1)
    for i = 1, 4 do
      C.fx.ghost(x + (i <= 2 and -1 or 1) * (60 + (i % 2) * 70), y + 40 - abs(sin(S.t * 4 + i)) * 16, 24, GHOSTS[i], i <= 2 and 1 or -1, S.t + i, false, false, a)
    end
  end
end

local CAM = {}
CAM.meet = function(lt)
  local c = lt % 24
  return L.shot(c, {{0, 384, 560, 1.15}, {7, 384, 560, 1.5}, {9, 384, 470, 1.7}, {14, 384, 470, 1.6}, {20, 384, 540, 1.2}}, W, H)
end
CAM.candy = function(lt)
  local c = lt % 8
  return L.shot(c, {{0, 384, 300, 1.4}, {3, 384, 260, 1.5}, {4, 384, 640, 1.2}, {7, 384, 700, 1.4}, {8, 384, 300, 1.4}}, W, H)
end
CAM.card = function(lt)
  local bx, by = S.card_bx or 0, S.card_by or 800
  if lt < 16 then return L.shot(0, {{0, bx + 60, by - 80, 1.5}}, W, H) end
  return L.shot(lt, {{16, 420, 720, 1.4}, {22, 520, 720, 1.5}, {28, 470, 740, 1.3}, {30, 384, 520, 1.1}, {32, 384, 420, 1.45},
                     {38, 384, 420, 1.45}, {39, 440, 760, 1.6}, {42, 460, 740, 1.4}, {46, 440, 640, 1.2}, {56, 440, 600, 1.2},
                     {58, 384, 760, 1.1}, {66, 384, 700, 1.1}, {70, 384, 512, 1}}, W, H)
end
CAM.diner = function(lt)
  local turn = floor(lt / 3) % 2
  if lt < 9.5 then return L.shot(0, {{0, 384, 512, 1}}, W, H) end
  if lt < 16 then return L.shot(lt, {{9.5, 520, 680, 1.4}, {13, 430, 700, 1.5}, {16, 384, 720, 1.4}}, W, H) end
  if lt > 27.5 and lt < 31.5 then return L.shot(0, {{0, 260, 720, 1.8}}, W, H) end
  if lt > 35 and lt < 45 then return L.shot(lt, {{35, 384, 700, 1.35}, {45, 384, 700, 1.35}}, W, H) end
  if lt > 45.5 and lt < 57 then return L.shot(lt, {{45.5, 384, 560, 1.2}, {49.5, 384, 560, 1.2}, {50, 384, 640, 1.35}, {52, 384, 560, 1.2}, {57, 384, 560, 1.2}}, W, H) end
  if lt > 57 then return L.shot(lt, {{57, 384, 700, 1.6}, {64, 384, 700, 1.6}, {67, 384, 760, 1.3}, {71, 260, 780, 1.4}, {74, 430, 700, 1.4}, {80, 384, 560, 1.1}}, W, H) end
  return L.shot(0, {{0, turn == 0 and 300 or 468, 720, 1.55}}, W, H)
end
CUES.card = {{32, "ding", 0.5}, {34.5, "ding", 0.5}, {37, "chime"}, {39, "tick", 0.5}, {40, "tick", 0.5}, {41, "tick", 0.5},
             {42, "power"}, {42.1, "cheer", 0.6}, {46, "whoosh", 0.5}, {51, "whoosh", 0.4}, {55, "chime", 0.5}, {57, "boom", 0.4},
             {57.3, "cheer"}}
CUES.card[#CUES.card + 1] = {42, function()
  for i = 1, 30 do
    local a = G.R:random() * 2 * pi
    G:spark(540, 740, cos(a) * 240, sin(a) * 240 - 100, 1.4, {1, 0.4 + G.R:random() * 0.4, 0.6}, 8, 120, true)
  end
end}
CUES.card[#CUES.card + 1] = {57.2, function()
  for side = -1, 1, 2 do
    for i = 1, 50 do
      local c = ({{1, 0.4, 0.7}, {1, 1, 1}, {1, 0.2, 0.3}})[G.R:random(1, 3)]
      G:spark(384 + side * 270, 820, -side * (40 + G.R:random() * 220), -220 - G.R:random() * 260, 2.4, c, 8, 160, false)
    end
  end
end}
CUES.finale = {{1, "chime"}, {6, "pop", 0.5}, {7, "pop", 0.5}, {8, "pop", 0.5}, {9, "pop", 0.5}, {10, "cheer", 0.5}, {14, "whoosh", 0.4},
               {19, "whoosh", 0.4}, {24, "ding"}, {26, "boing", 0.4}, {30, "chime"}, {36, "chime", 0.5}}
CUES.diner = {{28, "boing"}, {28.2, "boo", 0.4}, {9.5, "whoosh"}, {12.5, "boing"}, {13, "ding"}, {35, "clunk"}, {35.3, "chime"}, {46, "pop", 0.4}, {50, "boing"},
              {52, "pop", 0.4}, {58, "pop", 0.6}, {61, "ding"}, {66, "chime"}, {69, "whoosh", 0.4}, {72, "whoosh"}, {74.5, "ding"}}
for k = 1, 10 do CUES.diner[#CUES.diner + 1] = {16 + k * 3, "pop", 0.3} end
CAM.dots = function(lt)
  lt = dots_t(lt)
  if lt > 3 and lt < 27 then
    local u = clamp((lt - 3) / 24, 0, 1) * pi
    local x, y = heart_pt(u, 384, 470, 19)
    -- following him, then her, in turns (eased across)
    local side = sin((lt - 3) / 6 * pi)
    local fx = 384 + (x - 384) * clamp(side * 3, -1, 1)
    return L.shot(0, {{0, lerp(384, fx, 0.8), lerp(470, y, 0.8), 1.8}}, W, H)
  end
  return L.shot(lt, {{0, 384, 512, 1}, {27, 384, 512, 1.2}, {30, 384, 500, 1}, {38, 384, 700, 1.5}, {46, 384, 512, 1},
                     {60, 384, 512, 1}, {66, 384, 720, 1.6}, {72, 384, 400, 1.2}, {78, 384, 720, 1.5}, {84, 384, 512, 1}}, W, H)
end
CAM.finale = function(lt) return L.shot(lt, {{0, 384, 512, 1}, {6, 384, 540, 1.08}, {24, 384, 540, 1.08}, {28, 440, 530, 1.06}, {36, 384, 512, 1}}, W, H) end

function D.finale(lt, len)
  sky_night()
  floaters(1)
  lg.setColor(RED[1], RED[2], RED[3], 1)
  heart(384, 300, 110 * (1 + 0.05 * sin(S.t * 6)))
  -- the two of them: a little dance (round each other), then off together, the hearts trailing
  local px, mx, py = 300, 468, 760
  if lt > 14 and lt < 24 then
    local a2 = (lt - 14) * 2
    px, mx = 384 - cos(a2) * 84, 384 + cos(a2) * 84
    py = 760 + sin(a2) * 30
  end
  if lt > 26 then
    local f = clamp((lt - 26) / 10, 0, 1)
    px, mx = lerp(300, W + 120, f), lerp(468, W + 200, f)
  end
  C.fx.chomper(px, py, 40, 1, lt > 26 and S.t or 0, 1)
  ms(mx, lt > 14 and lt < 24 and 760 - sin((lt - 14) * 2) * 30 or 760, 40, lt > 26 and 1 or -1, lt > 26 and S.t or 0, 1)
  if lt > 26 then
    for k = 1, 6 do
      local f = (S.t * 0.8 + k / 6) % 1
      lg.setColor(PINK[1], PINK[2], PINK[3], 1 - f)
      heart((px + mx) / 2 - f * 160, 700 - f * 120, 10 + k % 3 * 4)
    end
  end
  for i = 1, 4 do
    local throw = lt > 6 and lt < 12
    C.fx.ghost(120 + (i - 1) * 176, 880 + sin(S.t * 2 + i) * 4 - (throw and abs(sin(S.t * 8 + i)) * 24 or 0), 30, GHOSTS[i], i <= 2 and 1 or -1, S.t + i, false, false, 1)
  end
  if lt > 6 and lt < 12 then G:confetti(2, {PINK, RED, {1, 1, 1}}) end
  if lt > 30 and lt < 34 then G:say("PLAYER 2, READY!", 600, 660, 22, 1) end
  G:caption("HAPPY", 480, 50, 0xffffff, L.window(lt, 0.5, len, 1))
  G:caption("VALENTINE'S DAY", 560, 64, 0xff6fa8, L.window(lt, 1, len, 1))
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
  for _, n in ipairs({"night", "candy", "door", "diner"}) do S.art[n] = G:art("valentine", n) end
  S.stars, S.floaters, S.candy = {}, {}, {}
  for i = 1, 80 do S.stars[i] = {R:random() * W, R:random() * H * 0.7} end
  for i = 1, 16 do
    S.floaters[i] = {R:random() * W, R:random() * H, 20 + R:random() * 40,
                     ({PINK, RED, {1, 0.8, 0.9}})[R:random(3)], 8 + R:random() * 14}
  end
  -- the pile in the jar: rows from the bottom, a little ragged
  for i = 1, 60 do
    local row, col = floor((i - 1) / 5), (i - 1) % 5
    S.candy[i] = {x = 220 + col * 82 + (row % 2) * 30 + (R:random() - 0.5) * 16, y = 860 - row * 42 + (R:random() - 0.5) * 10,
                  rot = (R:random() - 0.5) * 1.2, c = CANDY[R:random(#CANDY)], say = SAYINGS[(i * 7) % #SAYINGS + 1]}
  end
  for _, s in ipairs(SCENES) do if s[4] then G:label(s[4], 56, 0xffffff) end end
  for _, l in ipairs({{"PRESENTS", 26, 0x6ef0c8}, {"SWEETHEARTS", 80, 0xff6fa8},
                      {"HAPPY", 50, 0xffffff}, {"VALENTINE'S DAY", 64, 0xff6fa8}, {"SHE SAID YES", 34, 0xff6fa8}}) do
    G:label(l[1], l[2], l[3])
  end
end

function M.act() return S and scene_at(S.t)[2] or "open" end
function M.music() return S and scene_at(S.t)[3] or "ve_open" end

function M.update(dt)
  if not S then return false end
  G:step(dt)
  S.t = G.t
  local sc, lt = scene_at(S.t)
  for _, c in ipairs(CUES[sc[2]] or {}) do
    if lt - dt < c[1] and lt >= c[1] then
      if type(c[2]) == "function" then c[2]() else C.sfx(c[2], c[3]) end
    end
  end
  if sc[2] == "meet" then
    local c = lt % 24
    if c >= 9.6 and c - dt < 9.6 then C.sfx("boom", 0.5) end
    if c >= 10 and c - dt < 10 then C.sfx("pop") end
  elseif sc[2] == "candy" then
    if lt % 1 < dt and lt > 1 then C.sfx("pop", 0.3) end
  elseif sc[2] == "card" then
    if G:at(SCENES[4][1] + 44) then C.sfx("cheer", 0.6) end
  elseif sc[2] == "dots" then
    lt = dots_t(lt)
    local done = lt - 27
    -- a little heart up out of each dot as it goes
    local N = 36
    local e0, e1 = clamp((lt - dt - 3) / 24, 0, 1), clamp((lt - 3) / 24, 0, 1)
    if floor(e1 * N) ~= floor(e0 * N) and e1 < 1 then
      local x, y = heart_pt(e1 * pi, 384, 470, 19)
      for _, xx in ipairs({x, 768 - x}) do
        G:spark(xx, y, (G.R:random() - 0.5) * 60, -120, 0.9, PINK, 10, 0, true)
      end
      C.sfx("tick", 0.3)
    end
    if done >= 0 and done - dt < 0 then C.sfx("power") end
    if done > 3 and (lt * 2) % 3 < dt * 2 then
      G:firework(120 + G.R:random() * 528, 160 + G.R:random() * 300, S.t > 290 + 75, {PINK, RED, {1, 1, 1}})
      C.sfx("crackle", 0.4)
    end
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
  if sc[4] then
    G:plate(sc[4], 30, 56, 0xffffff, L.window(lt, 1.5, 9, 1))
    local b = L.window(lt, 2, len - 1.5, 1)
    lg.setColor(0.02, 0.02, 0.06, 0.55 * b)
    lg.rectangle("fill", 0, H - 50, W, 50)
    G:text(sc[5], 0, H - 38, 20, {1, 0.75, 0.85}, b)
  end
  local f = 1 - min(lt / 1.2, (len - lt) / 1.2, 1)
  if f > 0 then
    lg.setColor(0, 0, 0, f)
    lg.rectangle("fill", 0, 0, W, H)
  end
end

return M
