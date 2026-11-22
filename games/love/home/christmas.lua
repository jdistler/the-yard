-- Christmas: Home's show for December (shows.lua's calendar), nine minutes, snow falling through most of it.
-- Every scene a story with its own camera (SHOWS_BLUEPRINT.md):
--   0:00  STARLIGHT PRESENTS ... CHRISTMAS                                         (Carol of the Bells)
--   0:10  Putting up the lights: Pac-Man along the eaves stringing them bulb by bulb, Inky up on the ridge, the
--         inflatables pumped up (the longhorn goes PFFT), the plug... nothing... Clyde finds the other plug: ON.
--         A snowball fight, carols on the walk, a sleigh across the moon
--   1:40  Santa Pac-Man's sleigh: across the moon, down onto a roof, presents down the chimney, Pac-Man stuck in
--         it (too many cookies) until the reindeer pull him out, the flyby, away  (Jingle Bells)
--   3:00  A Texas Christmas: 72 and sunny. A tumbleweed snowman built ball by ball, cowboy Santa lassoing a star
--         onto the prickly pear (its lights come on), Inky's snow machine, the Christmas card photo
--                                                                                   (Deck the Halls, western swing)
--   4:20  Trimming the tree: the ghosts hanging the ornaments one by one, the lights spiralled up, Pac-Man lifted
--         up to put the star on, presents under the tree, the stockings filled, by the fire
--                                                                                   (We Wish You a Merry Christmas)
--   5:40  Cookies for Santa: the ghosts sneaking them one by one (one drinks the milk), Pac-Man following the
--         crumbs to them, a new batch and "P.S. SORRY"                               (Gingerbread Rag)
--   6:40  Silent night: carolers down the street, the windows going out one by one, the church bell, Santa
--         across the sky, the star over the steeple                                   (Silent Night)
--   8:20  MERRY CHRISTMAS, and a happy new year: fireworks, the cast, presents opening   (Jingle Bells, up a key)
-- The carols are public domain (Jingle Bells 1857, Deck the Halls, We Wish You a Merry Christmas, Silent Night
-- 1818, the Carol of the Bells' ostinato 1914); the Gingerbread Rag is ours.
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
  {0, "open", "xm_bells"},
  {10, "street", "xm_bells", "SNOW ON THE CUL-DE-SAC", "THE LIGHTS ARE UP"},
  {100, "sleigh", "xm_jingle", "SANTA PAC-MAN'S SLEIGH", "ON BLINKY, ON PINKY, ON INKY AND CLYDE"},
  {180, "texas", "xm_deck", "A TEXAS CHRISTMAS", "72 AND SUNNY  ·  Y'ALL"},
  {260, "tree", "xm_wish", "TRIMMING THE TREE", "STOCKINGS BY THE FIRE"},
  {340, "cookies", "xm_rag", "COOKIES FOR SANTA", "NOBODY TOUCH THE GINGERBREAD"},
  {400, "silent", "xm_silent", "SILENT NIGHT", "ALL IS CALM  ·  ALL IS BRIGHT"},
  {500, "finale", "xm_finale"},
}
M.SEGMENTS = {}
for _, s in ipairs(SCENES) do if s[4] then M.SEGMENTS[#M.SEGMENTS + 1] = {s[1], s[4]} end end
table.insert(M.SEGMENTS, {500, "MERRY CHRISTMAS"})
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
local function prog(lt, a, b) return ease((lt - a) / (b - a)) end
local function lin(lt, a, b) return clamp((lt - a) / (b - a), 0, 1) end
local GH = {{1, 0.18, 0.2}, {1, 0.55, 0.85}, {0.25, 0.95, 1}, {1, 0.65, 0.2}}
local BULBS = {{1, 0.2, 0.2}, {0.2, 0.85, 0.3}, {0.3, 0.5, 1}, {1, 0.8, 0.2}, {1, 0.4, 0.8}}

-- ------------------------------------------------------------------ small things
local function santa_hat(x, y, r, tilt)
  lg.push()
  lg.translate(x, y)
  lg.rotate(tilt or -0.3)
  lg.setColor(0.85, 0.1, 0.12, 1)
  lg.polygon("fill", -r, 0, r, 0, r * 0.3, -r * 1.4)
  lg.setColor(1, 1, 1, 1)
  lg.rectangle("fill", -r * 1.1, -r * 0.15, r * 2.2, r * 0.35, r * 0.15, r * 0.15, 6)
  lg.circle("fill", r * 0.3, -r * 1.4, r * 0.22, 10)
  lg.pop()
end

-- a string of bulbs from (x0, y0) to (x1, y1): the first `count` of n+1 strung (all if nil), lit or dark,
-- blinking in turn (chase: running along)
local function lights(x0, y0, x1, y1, n, t, sag, count, on, chase)
  count = count or n + 1
  if count <= 0 then return end
  local pts = {}
  for i = 0, n do
    local k = i / n
    pts[#pts + 1] = lerp(x0, x1, k)
    pts[#pts + 1] = lerp(y0, y1, k) + sin(k * pi) * (sag or 10)
  end
  lg.setColor(0.1, 0.15, 0.1, 1)
  lg.setLineWidth(2)
  local wire = {}
  for i = 1, min(#pts, count * 2) do wire[i] = pts[i] end
  if #wire >= 4 then lg.line(wire) end
  if on then lg.setBlendMode("add") end
  for i = 0, min(n, count - 1) do
    local c = BULBS[i % #BULBS + 1]
    local lit = on and (chase and ((floor(t * 8) - i) % 6 < 3) or ((floor(t * 2) + i) % 3 ~= 0))
    local x, y = pts[i * 2 + 1], pts[i * 2 + 2] + 5
    if lit then
      lg.setColor(c[1], c[2], c[3], 0.4)
      lg.circle("fill", x, y, 15, 12)
    end
    lg.setColor(c[1] * (on and 1 or 0.45), c[2] * (on and 1 or 0.45), c[3] * (on and 1 or 0.45), on and (lit and 1 or 0.4) or 1)
    lg.circle("fill", x, y, 5.5, 8)
  end
  lg.setBlendMode("alpha")
end

local function snowman(x, y, s, tumble, balls, hat)
  balls = balls or 3
  local body = tumble and {0.6, 0.45, 0.28} or {0.97, 0.97, 1}
  local ys = {y, y - 56 * s, y - 100 * s}
  local rs = {40 * s, 30 * s, 22 * s}
  for i = 1, balls do
    rgba(body)
    lg.circle("fill", x, ys[i], rs[i], 24)
    if tumble then
      lg.setColor(0.42, 0.3, 0.16, 1)
      lg.setLineWidth(2)
      for k = 1, 7 do
        local a = k * 0.9 + i
        lg.circle("line", x + cos(a) * rs[i] * 0.45, ys[i] + sin(a * 1.3) * rs[i] * 0.45, rs[i] * 0.4, 8)
      end
    end
  end
  if balls >= 3 then
    lg.setColor(0.1, 0.1, 0.12, 1)
    lg.circle("fill", x - 8 * s, y - 106 * s, 3 * s, 6)
    lg.circle("fill", x + 8 * s, y - 106 * s, 3 * s, 6)
  end
  if hat then
    lg.setColor(0.45, 0.3, 0.14, 1)
    lg.ellipse("fill", x, y - 120 * s, 34 * s, 7 * s, 16)
    lg.rectangle("fill", x - 18 * s, y - 142 * s, 36 * s, 22 * s, 4, 4, 4)
    lg.setColor(0.8, 0.1, 0.12, 1)
    lg.rectangle("fill", x - 18 * s, y - 126 * s, 36 * s, 5 * s)
  end
end

local function present(x, y, w, h, c, ribbon, open)
  rgba(c)
  lg.rectangle("fill", x, y, w, h, 3, 3, 4)
  rgba(ribbon)
  lg.rectangle("fill", x + w / 2 - 4, y, 8, h)
  lg.rectangle("fill", x, y + h / 2 - 4, w, 8)
  if open then
    rgba(c)
    lg.push()
    lg.translate(x, y)
    lg.rotate(-0.9 * open)
    lg.rectangle("fill", -4, -10, w + 8, 12, 3, 3, 4)
    lg.pop()
  else
    lg.ellipse("fill", x + w / 2 - 8, y - 4, 9, 6, 10)
    lg.ellipse("fill", x + w / 2 + 8, y - 4, 9, 6, 10)
  end
end

-- the tree: ornaments hung (how many), its lights strung up to a height (0..1 of the tree), lit, the star
local function xmas_tree(x, base, s, t, ornaments, strung, lit, star)
  lg.setColor(0.4, 0.25, 0.12, 1)
  lg.rectangle("fill", x - 14 * s, base - 40 * s, 28 * s, 40 * s)
  for i, w in ipairs({{150, 0}, {120, 90}, {90, 170}, {60, 240}}) do
    lg.setColor(0.1, 0.42 + i * 0.03, 0.2, 1)
    lg.polygon("fill", x - w[1] * s, base - 40 * s - w[2] * s, x + w[1] * s, base - 40 * s - w[2] * s, x, base - 40 * s - (w[2] + 130) * s)
  end
  for i, o in ipairs(S.ornaments) do
    if i <= (ornaments or 0) then
      local c = BULBS[i % #BULBS + 1]
      rgba(c)
      lg.circle("fill", x + o[1] * s, base + o[2] * s, 8 * s, 10)
      lg.setColor(1, 1, 1, 0.6)
      lg.circle("fill", x + o[1] * s - 2 * s, base + o[2] * s - 3 * s, 2.5 * s, 6)
    end
  end
  if (strung or 0) > 0 then
    if lit then lg.setBlendMode("add") end
    for i, o in ipairs(S.tlights) do
      if -o[2] - 50 < strung * 380 then
        local c = BULBS[i % #BULBS + 1]
        local on = lit and (floor(t * 2.5) + i) % 4 ~= 0
        lg.setColor(c[1], c[2], c[3], lit and (on and 0.9 or 0.25) or 0.55)
        lg.circle("fill", x + o[1] * s, base + o[2] * s, 3.4 * s, 6)
      end
    end
    lg.setBlendMode("alpha")
  end
  if star then
    if lit then C.fx.glow(x, base - 410 * s, 70 * s, 70 * s, 1, 0.9, 0.4, 0.7) end
    lg.setColor(1, 0.85, 0.25, 1)
    L.star(x, base - 410 * s, 26 * s, sin(t) * 0.1)
  end
end

local function snowfall(dense)
  local b = S.snowb
  b:clear()
  for i, f in ipairs(S.snow) do
    if i <= (dense or #S.snow) then
      b:setColor(1, 1, 1, f[4])
      b:add(f[1], f[2], 0, f[3], f[3], 8, 8)
    end
  end
  lg.setColor(1, 1, 1, 1)
  lg.draw(b)
end

-- notes floating up from carolers
local function notes(x, y, t, a)
  for k = 0, 2 do
    local f = (t * 0.6 + k / 3) % 1
    local nx, ny = x + sin(f * 6 + k) * 20, y - f * 90
    lg.setColor(1, 1, 0.85, (1 - f) * (a or 1))
    lg.ellipse("fill", nx, ny, 6, 4.5, 10)
    lg.setLineWidth(2)
    lg.line(nx + 5, ny, nx + 5, ny - 18)
    if k % 2 == 1 then lg.line(nx + 5, ny - 18, nx + 12, ny - 12) end
  end
end

-- the sleigh at x, y (scale s): Santa Pac-Man, a present, its runners
local function sleigh_draw(x, y, s, tilt, pac_in)
  lg.push()
  lg.translate(x, y)
  lg.rotate(tilt or 0)
  lg.scale(s, s)
  lg.setColor(0.75, 0.08, 0.1, 1)
  lg.polygon("fill", -60, -30, 40, -30, 60, 10, -50, 10)
  lg.setColor(1, 0.82, 0.3, 1)
  lg.setLineWidth(4)
  lg.line(-70, 22, 50, 22, 66, 8)
  lg.line(-40, 10, -40, 22)
  lg.line(20, 10, 20, 22)
  present(-50, -56, 30, 26, {0.2, 0.6, 0.3}, {1, 0.85, 0.2})
  if pac_in ~= false then
    L.pac(6, -46, 26, 0, S.t, nil)
    santa_hat(4, -70, 16, -0.25)
    lg.setColor(1, 1, 1, 1)
    lg.ellipse("fill", 10, -24, 16, 8, 12)
  end
  lg.pop()
end
-- the four ghost reindeer, harnessed ahead of the sleigh at (x, y); flat: standing on a roof, not flying
local function reindeer(x, y, s, t, nose)
  for i, c in ipairs(GH) do
    local gx = x + (90 + (4 - i) * 70) * s
    local gy = y + (-30 + sin(t * 6 + i) * 6) * s
    lg.setColor(0.55, 0.38, 0.2, 1)
    lg.setLineWidth(3 * s)
    lg.line(gx - 8 * s, gy - 26 * s, gx - 16 * s, gy - 46 * s, gx - 24 * s, gy - 40 * s)
    lg.line(gx + 8 * s, gy - 26 * s, gx + 16 * s, gy - 46 * s, gx + 24 * s, gy - 40 * s)
    L.ghost(gx, gy, 22 * s, c, t + i, 1, 0, nil)
    if i == 1 then
      C.fx.glow(gx + 24 * s, gy - 2 * s, 30 * s, 30 * s, 1, 0.1, 0.1, 0.8 * (nose or 1))
      lg.setColor(1, 0.25, 0.2, 1)
      lg.circle("fill", gx + 22 * s, gy - 2 * s, 7 * s, 10)
    end
    lg.setColor(0.8, 0.7, 0.4, 0.7)
    lg.setLineWidth(1.5)
    lg.line(x + 40 * s, y - 10 * s, gx - 14 * s, gy)
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
  if not art("open") then G:gradient(0, 0, W, H, {0.03, 0.05, 0.15}, {0.1, 0.15, 0.35}) end
  snowfall()
  local a = L.window(lt, 0.5, 4.5, 0.8)
  G:brand(400, a)
  G:caption("PRESENTS", 472, 26, 0x6ef0c8, a)
  G:caption("CHRISTMAS", 430, 80, 0xff4040, L.window(lt, 4.8, 10, 0.8))
end

-- ------------------------------------------------------------------ the cul-de-sac: putting up the lights
local EAVE = {130, 474, 640, 474, 26}       -- x0, y0, x1, y1, bulbs
local RIDGE = {250, 334, 520, 334, 14}
local ON_AT = 51                            -- the lights come on
local function pac_street(lt)
  return L.path(lt, {{0, 700, 900}, {4, 600, 730}, {7, 610, 452}, {8, 620, 452}, {26, 140, 452, "lin"}, {28, 120, 730},
                     {30, 240, 760}, {42, 520, 730}, {44, 548, 720}, {54, 548, 720}, {56, 400, 860}, {72, 420, 860},
                     {76, 300, 900}, {90, 300, 900}})
end
local function inflate(lt, which)
  if which == 1 then return prog(lt, 30, 34) end
  -- the longhorn: up, PFFT, up again
  return prog(lt, 35, 38) * (1 - prog(lt, 39, 40)) + prog(lt, 41.5, 43.5)
end
function D.street(lt, len)
  if not art("street") then
    G:gradient(0, 0, W, 700, {0.03, 0.04, 0.14}, {0.12, 0.14, 0.32})
    lg.setColor(0.35, 0.22, 0.18, 1)
    lg.rectangle("fill", 160, 470, 450, 260)
    G:gradient(0, 700, W, H, {0.85, 0.88, 0.98}, {0.7, 0.75, 0.9})
  end
  local on = lt > ON_AT
  -- the strings: strung as Pac-Man (eaves) and Inky (the ridge) go along them
  local eave_n = floor(lin(lt, 8, 26) * (EAVE[5] + 1) + 0.001)
  local ridge_n = floor(lin(lt, 14, 25) * (RIDGE[5] + 1) + 0.001)
  if lt > 26 then eave_n = EAVE[5] + 1 end
  if lt > 25 then ridge_n = RIDGE[5] + 1 end
  -- (Pac-Man and Inky both string right-to-left: bulbs count from x1)
  lights(EAVE[3], EAVE[4], EAVE[1], EAVE[2], EAVE[5], S.t, 6, eave_n, on, lt > 60 and lt < 72)
  lights(RIDGE[3], RIDGE[4], RIDGE[1], RIDGE[2], RIDGE[5], S.t + 1, 4, ridge_n, on, lt > 60 and lt < 72)
  -- the tree's bulbs in the window
  for i = 0, 5 do
    local c = BULBS[i % #BULBS + 1]
    lg.setColor(c[1], c[2], c[3], on and ((floor(S.t * 2) + i) % 2 == 0 and 1 or 0.4) or 0.25)
    lg.circle("fill", 250 + i * 10, 640 - (i % 3) * 25, 3, 6)
  end
  if lt > ON_AT and lt < ON_AT + 1 then
    lg.setColor(1, 1, 0.85, 0.5 * (1 - (lt - ON_AT)))
    lg.rectangle("fill", 0, 0, W, H)
  end
  -- the ladder against the right end of the house
  if lt < 30 then
    lg.setColor(0.6, 0.45, 0.25, 1)
    lg.setLineWidth(5)
    lg.line(590, 736, 616, 470)
    lg.line(626, 736, 652, 470)
    lg.setLineWidth(3)
    for k = 1, 8 do
      local f = k / 9
      lg.line(lerp(590, 616, f), lerp(736, 470, f), lerp(626, 652, f), lerp(736, 470, f))
    end
  end
  -- the inflatables: flat on the snow, pumped up
  local k1, k2 = inflate(lt, 1), inflate(lt, 2)
  local sw = sin(S.t * 1.4) * 0.06
  lg.push()
  lg.translate(620, 900)
  lg.rotate(sw * k1)
  lg.scale(lerp(1.3, 1, k1), lerp(0.12, 1, k1))
  L.pac(0, -60, 54, pi, S.t * 0.3 * k1, 0.4)
  santa_hat(-6, -108, 30, 0.35)
  lg.pop()
  lg.push()
  lg.translate(380, 940)
  lg.rotate(-sw * k2)
  lg.scale(lerp(1.3, 1, k2), lerp(0.12, 1, k2))
  L.longhorn_head(0, -40, 0.65, {0.75, 0.34, 0}, 1)
  santa_hat(4, -66, 18, -0.2)
  lg.pop()
  -- the pump, worked by Blinky (Pac-Man inflatable) then Clyde (Longhorn inflatable)
  if lt > 29 and lt < 45 then
    local is_blinky = lt < 34.5
    local px = is_blinky and 690 or 460
    local pumping = (lt > 30 and lt < 34) or (lt > 35 and lt < 38) or (lt > 41.5 and lt < 43.5)
    local h = pumping and abs(sin(S.t * 6)) * 20 or 0
    lg.setColor(0.3, 0.3, 0.35, 1)
    lg.rectangle("fill", px - 8, 900 - 50, 16, 50)
    lg.rectangle("fill", px - 2, 850 - 30 + h, 4, 30)
    lg.rectangle("fill", px - 18, 820 + h, 36, 6)
    L.ghost(px + 30, 860 - (is_blinky and h * 0.5 or h), 30, GH[is_blinky and 1 or 4], S.t, -1, 0.4, nil)
  end
  -- Inky up on the ridge with the second string
  if lt > 12 and lt < 28 then
    local ix = L.path(lt, {{12, 560, 0}, {14, 520, 0}, {25, 250, 0, "lin"}, {28, 120, 0}})
    local iy = lt < 14 and lerp(600, 300, prog(lt, 12, 14)) or (lt > 25 and lerp(300, 760, prog(lt, 25, 28)) or 300 + sin(S.t * 3) * 4)
    L.ghost(ix, iy, 26, GH[3], S.t, -1, 0.3, nil)
  end
  -- the extension cord: from the plug at the porch, round the yard to Clyde's end
  if lt > 42 then
    lg.setColor(0.15, 0.4, 0.15, 1)
    lg.setLineWidth(4)
    lg.line(560, 730, 580, 780, 680, 800, 720, 880, 700, 940)
  end
  -- Clyde at the far end of the cord, finding the other plug
  if lt > 45 and lt < 53 then
    L.ghost(700, 900 - (lt > 49 and lt < 51 and L.hop(lt, 0.5, 20) or 0), 30, GH[4], S.t, -1, lt < 49 and 1 or 0, lt > 49 and "happy" or nil)
    lg.setColor(0.9, 0.9, 0.92, 1)
    lg.rectangle("fill", 676, 930, 16, 10)
    if lt > ON_AT - 0.05 and lt < ON_AT + 0.6 then
      local sf = 1 - lin(lt, ON_AT - 0.05, ON_AT + 0.6)
      C.fx.glow(684, 935, 48 * sf + 12, 48 * sf + 12, 1, 0.95, 0.55, 0.9 * sf)
    end
  end
  -- the snowball fight (throwers first; snowballs & splats drawn after cast for clean z-order)
  if lt > 56 and lt < 72 then
    for k, gi in ipairs({1, 2}) do
      local hit = false
      for j = 0, 5 do
        local t0 = 57 + j * 2.4
        if (j % 2 == 0) == (k == 2) and j ~= 4 and lt > t0 + 1.2 and lt < t0 + 2.2 then hit = true end
      end
      -- the wind-up before each throw
      local wind = 0
      for j = 0, 5 do
        local t0 = 57 + j * 2.4
        if (j % 2 == 0) == (k == 1) and lt > t0 - 0.5 and lt < t0 then wind = (lt - t0 + 0.5) * 40 end
      end
      local gx = (k == 1 and 150 or 735) + (k == 1 and -wind or wind)
      L.ghost(gx, 860 - L.hop(lt + k, 0.6, 14), 40, GH[gi], S.t + k, k == 1 and 1 or -1, 0, hit and "wide" or nil)
      if hit then
        lg.setColor(1, 1, 1, 1)
        lg.circle("fill", gx, 830, 22, 12)
      end
    end
  end
  -- carolers on the walk: everyone in a row, singing
  if lt > 72 then
    for k, gi in ipairs({1, 2, 3, 4}) do
      local gx = lerp(-80 - k * 60, 140 + k * 90, prog(lt, 72, 76))
      local gy = 880 - L.hop(lt + k * 0.4, 1, 6)
      L.ghost(gx, gy, 30, GH[gi], S.t + k, 0, -0.6, "happy")
      -- warm breath puff in the cold air
      local bf = (S.t * 0.85 + k * 0.27) % 1
      lg.setColor(0.95, 0.98, 1, (1 - bf) * 0.35)
      lg.ellipse("fill", gx + 10 + bf * 14, gy - 12 - bf * 22, 6 + bf * 8, 4 + bf * 5, 10)
      notes(gx, 830, S.t + k)
    end
  end
  -- Pac-Man: up the ladder, along the eaves, down, the plug, the snowballs, the carols
  local px, py = pac_street(lt)
  local snowy = lt > 67.8 and lt < 72
  local phop = (lt > 8 and lt < 26) and -L.hop(S.t, 0.5, 6) or 0
  L.pac(px, py - 30 + phop, 30, (lt > 8 and lt < 30) and pi or 0, S.t, snowy and 0.2 or nil)
  santa_hat(px - 4, py - 66 + phop, 16, -0.25)
  if snowy then
    lg.setColor(1, 1, 1, 0.95)
    lg.circle("fill", px + 6, py - 36, 22, 16)
  end
  -- flying snowballs & splats in front of cast
  if lt > 56 and lt < 72 then
    for k = 0, 5 do
      local t0 = 57 + k * 2.4
      if lt > t0 and lt < t0 + 1.2 then
        local f = (lt - t0) / 1.2
        local from = k % 2 == 0 and {150, 860} or {735, 860}
        local to = k == 4 and {420, 820} or (k % 2 == 0 and {715, 840} or {170, 840})
        lg.setColor(0.7, 0.75, 0.85, 0.5)
        lg.ellipse("fill", lerp(from[1], to[1], f), 880, 14, 4, 10)
        lg.setColor(1, 1, 1, 1)
        lg.circle("fill", lerp(from[1], to[1], f), lerp(from[2], to[2], f) - sin(f * pi) * 160, 18, 14)
      end
      if lt > t0 + 1.2 and lt < t0 + 2 then
        local to = k == 4 and {420, 820} or (k % 2 == 0 and {715, 840} or {170, 840})
        local g = (lt - t0 - 1.2) / 0.8
        lg.setColor(1, 1, 1, 1 - g)
        for d = 0, 5 do
          local a = d / 6 * 2 * pi
          lg.circle("fill", to[1] + cos(a) * 30 * g, to[2] - 20 + sin(a) * 20 * g, 10 * (1 - g) + 3, 8)
        end
      end
    end
  end
  -- a sleigh across the moon, far off
  if lt > 82 and lt < 89 then
    local f = lin(lt, 82, 89)
    lg.setColor(0.05, 0.05, 0.1, 1)
    local sx, sy = lerp(560, 740, f), 125 - sin(f * pi) * 20
    lg.ellipse("fill", sx, sy, 12, 4, 10)
    for k = 1, 4 do lg.circle("fill", sx + k * 11, sy - 2, 3, 6) end
  end
  if lt > 44 and lt < 47.5 then
    local n = floor((lt - 44) / 1.1)
    G:say(({"3...", "2...", "1..."})[n + 1] or "1...", px, py - 80, 26, 1)
  end
  if lt > 47.5 and lt < 50.5 then G:say("...?", px, py - 80, 28, 1) end
  if lt > 49 and lt < 51.5 then G:say("FOUND IT!", 700, 820, 24, 1) end
  if lt > 39 and lt < 41.5 then G:say("PFFFT!", 380, 860, 26, 1) end
  if lt > ON_AT + 0.5 and lt < ON_AT + 4 then G:say("OOOOH!", px, py - 80, 30, 1) end
  if snowy then G:say("BRRR!", px, py - 80, 24, 1) end
  snowfall()
end
CAM.street = function(lt)
  local px, py = pac_street(lt)
  if lt > 8 and lt < 26 then return L.shot(0, {{0, px - 40, 520, 1.6}}, W, H) end
  local x, y, z = L.shot(lt, {{0, 384, 512, 1}, {4, 520, 600, 1.3}, {8, 580, 520, 1.6}, {26, 160, 520, 1.6}, {29, 300, 800, 1.4},
                              {34, 560, 840, 1.45}, {38, 420, 860, 1.5}, {43, 470, 840, 1.45}, {45, 540, 700, 1.8}, {48.6, 560, 720, 1.9}, {49.6, 640, 820, 1.6}, {ON_AT - 0.02, 640, 820, 1.6},
                              {ON_AT, 384, 560, 1.2, "cut"}, {56, 384, 560, 1.15}, {58, 260, 820, 1.4}, {60.4, 600, 820, 1.4}, {62.8, 260, 820, 1.4},
                              {65.2, 600, 820, 1.4}, {67.6, 420, 800, 1.6}, {72, 420, 800, 1.5},
                              {78, 384, 640, 1.1}, {82, 384, 512, 1}, {86, 560, 300, 1.5}, {90, 560, 300, 1.5}}, W, H)
  return x, y, z, (lt > ON_AT and lt < ON_AT + 0.4) and 6 or 0
end
CUES.street = {{4, "pop", 0.4}, {28, "boing"}, {30, "pop", 0.4}, {34, "ding"}, {38, "ding"}, {39, "boo"}, {43.5, "ding"},
               {47.5, "clunk"}, {49, "boing"}, {ON_AT, "clunk"}, {ON_AT + 0.1, "power"}, {ON_AT + 0.3, "cheer"}, {67.8, "pop"}, {72, "chime"},
               {82, "chime"},
               {ON_AT, function()
                 for i = 1, 10 do G:spark(684, 935, (G.R:random() - 0.5) * 160, -40 - G.R:random() * 100, 0.5, {1, 0.92, 0.45}, 5, 220, true) end
               end}}
for n = 0, 26, 2 do CUES.street[#CUES.street + 1] = {8 + n / 27 * 18, "tick", 0.35} end
for k = 0, 5 do
  CUES.street[#CUES.street + 1] = {57 + k * 2.4, "whoosh", 0.35}
  CUES.street[#CUES.street + 1] = {57 + k * 2.4 + 1.2, "splash", 0.4}
end

-- ------------------------------------------------------------------ the sleigh: the roof, the chimney
local CHIM = {120, 700}                     -- the chimney on the roof (live, over the painted one), its top
local LAND = {250, 744}
local function sleigh_pos(lt)
  return L.path(lt, {{0, -300, 430}, {14, W + 300, 300, "lin"}, {15, W + 220, 470}, {27, LAND[1], LAND[2]}, {48, LAND[1], LAND[2]},
                     {52, 500, 560}, {58, -400, 1100, "lin"}, {60, -200, 640}, {73, W + 200, 580, "lin"}, {73.5, -260, 330},
                     {80, W + 200, 250, "lin"}})
end
local function sleigh_scale(lt)
  if lt > 52 and lt < 58 then return lerp(1, 3.2, prog(lt, 52, 58)) end
  if lt > 59 and lt < 73.3 then return 0.8 end
  if lt > 59 then return 0.4 end
  return 1
end
local function pac_chimney(lt)
  -- out of the sleigh to the chimney, the presents, in, stuck, pulled out, back
  return L.path(lt, {{29, LAND[1] + 6, LAND[2] - 46}, {31, CHIM[1], CHIM[2] - 40}, {41, CHIM[1], CHIM[2] - 40}, {42.5, CHIM[1], CHIM[2] - 6},
                     {46.6, CHIM[1], CHIM[2] - 6}, {47.2, CHIM[1] + 30, CHIM[2] - 140}, {48, LAND[1] + 6, LAND[2] - 46}})
end
function D.sleigh(lt, len)
  if not art("sleigh") then
    G:gradient(0, 0, W, 800, {0.02, 0.03, 0.12}, {0.1, 0.12, 0.3})
    lg.setColor(0.97, 0.95, 0.85, 1)
    lg.circle("fill", 384, 330, 130, 48)
  end
  -- the chimney (bigger than the painted one: Pac-Man has to fit... nearly)
  lg.setColor(0.42, 0.18, 0.14, 1)
  lg.rectangle("fill", CHIM[1] - 24, CHIM[2], 48, 70)
  lg.setColor(0.3, 0.12, 0.1, 1)
  for k = 0, 3 do lg.rectangle("fill", CHIM[1] - 24, CHIM[2] + 8 + k * 16, 48, 2) end
  local sx, sy = sleigh_pos(lt)
  local s = sleigh_scale(lt)
  local tilt = (lt < 14 and -0.12) or (lt > 15 and lt < 27 and 0.12) or ((lt > 48 and lt < 52) and -0.2) or 0
  local dir = ((lt > 15 and lt < 27) or (lt > 52 and lt < 58)) and -1 or 1
  local pac_out = lt > 29 and lt < 48
  if lt < 59 or lt > 60 then
    lg.push()
    lg.translate(sx, sy)
    lg.scale(dir, 1)
    reindeer(0, 0, s, S.t, 1)
    sleigh_draw(0, 0, s, tilt, not pac_out)
    lg.pop()
  end
  -- Pac-Man and the presents
  if pac_out then
    local px, py = pac_chimney(lt)
    L.pac(px, py, 26, 0, S.t, (lt > 42.5 and lt < 46.6) and 0.9 or nil)
    santa_hat(px - 2, py - 24, 16, -0.25)
    -- (in the chimney: its top, drawn again over him)
    if lt > 42 and lt < 46.8 then
      lg.setColor(0.42, 0.18, 0.14, 1)
      lg.rectangle("fill", CHIM[1] - 24, CHIM[2] + 4, 48, 30)
    end
    for k = 0, 2 do
      local t0 = 32 + k * 3
      if lt > t0 and lt < t0 + 1.5 then
        local f = (lt - t0) / 1.5
        present(CHIM[1] - 14, lerp(CHIM[2] - 46, CHIM[2] + 6, f * f), 28, 24, BULBS[k + 1], {1, 0.9, 0.3})
      end
    end
    -- the reindeer pulling him out: a rope, the tug
    if lt > 43.5 and lt < 47 then
      lg.setColor(0.8, 0.7, 0.4, 1)
      lg.setLineWidth(3)
      local tug = sin(S.t * 10) * 6
      lg.line(px + 20, py - 10, sx + 160 * s + tug, sy - 30 * s)
    end
  end
  -- the chimney's top always over what goes in
  lg.setColor(0.96, 0.97, 1, 1)
  lg.rectangle("fill", CHIM[1] - 28, CHIM[2] - 4, 56, 10, 4, 4, 4)
  -- the trail of sparkles behind (clamped per flight segment so it never bridges teleport cuts)
  if lt > 60 and lt < 80 then
    for k = 1, 10 do
      local ts = lt - k * 0.25
      if (lt < 73.25 and ts > 60) or (lt >= 73.5 and ts > 73.5) then
        local tx, ty = sleigh_pos(ts)
        lg.setColor(1, 0.9, 0.5, (1 - k / 10) * 0.9)
        L.star(tx - 30, ty, 4 + (k % 3), S.t + k)
      end
    end
  end
  -- presents down the chimneys along the street, one every three seconds (61-73)
  for k = 0, 4 do
    local t0 = 61.5 + k * 2.5
    if lt > t0 and lt < t0 + 2.4 then
      local dx, dy = sleigh_pos(t0)
      local f = lin(lt, t0, t0 + 1.2)
      local px2, py2 = dx + f * 40, lerp(dy + 20, 900, f * f)
      if f < 1 then
        rgba(BULBS[k % #BULBS + 1])
        lg.rectangle("fill", px2 - 14, py2 - 14, 28, 28, 3, 3, 4)
        lg.setColor(1, 0.9, 0.3, 1)
        lg.rectangle("fill", px2 - 3, py2 - 14, 6, 28)
      else
        lg.setBlendMode("add")
        C.fx.glow(px2, 890, 60, 50, 1, 0.85, 0.5, 1 - (lt - t0 - 1.2) / 1.2)
        lg.setBlendMode("alpha")
      end
    end
  end
  if lt > 41.5 and lt < 44 then
    local px, py = pac_chimney(lt)
    G:say("I'M STUCK!", px, py - 50, 26, 1)
  end
  if lt > 44 and lt < 46.6 then G:say("PULL!", sx + 200, sy - 80, 26, 1) end
  if lt > 46.6 and lt < 48.5 then G:say("POP!", CHIM[1], CHIM[2] - 120, 32, 1) end
  if lt > 30 and lt < 32 then G:say("HO HO HO!", CHIM[1], CHIM[2] - 90, 24, 1) end
  if lt > 66 and lt < 71 then
    G:say("MERRY CHRISTMAS!", sx, sy - 40, 22, 1)
  end
  snowfall(90)
end
CAM.sleigh = function(lt)
  local sx, sy = sleigh_pos(lt)
  if lt > 15 and lt < 27 then return L.shot(0, {{0, sx + 120, sy - 20, 1.4}}, W, H) end
  if lt > 60 and lt < 73 then return L.shot(0, {{0, sx + 80, sy + 120, 1.3}}, W, H) end
  return L.shot(lt, {{0, 384, 512, 1}, {14, 384, 512, 1}, {15, 600, 520, 1.4}, {27, LAND[1] + 120, LAND[2] - 40, 1.4},
                     {30, CHIM[1] + 60, CHIM[2] - 30, 1.9}, {41, CHIM[1] + 60, CHIM[2] - 30, 1.9}, {43, CHIM[1] + 160, CHIM[2] - 50, 1.5},
                     {48, CHIM[1] + 160, CHIM[2] - 50, 1.5}, {52, 384, 560, 1.15}, {54, 384, 512, 1}, {62, 384, 512, 1},
                     {78, 384, 380, 1.25}, {80, 384, 380, 1.25}}, W, H)
end
CUES.sleigh = {{60.5, "whoosh", 0.4}, {62.7, "chime", 0.5}, {65.2, "chime", 0.5}, {67.7, "chime", 0.5}, {70.2, "chime", 0.5},
               {72.7, "chime", 0.6}, {74, "whoosh", 0.3}, {1, "whoosh"}, {28, "clunk"}, {29.5, "boing"}, {33.5, "clunk"}, {36.5, "clunk"}, {39.5, "clunk"},
               {42.5, "boing"}, {44, "whoosh", 0.4}, {46.6, "pop"}, {47, "boing"}, {52, "whoosh"}, {55, "jet", 0.5}, {66, "chime"}}
for k = 0, 2 do
  CUES.sleigh[#CUES.sleigh + 1] = {33.5 + k * 3, function()
    for i = 1, 14 do G:spark(CHIM[1], CHIM[2], (G.R:random() - 0.5) * 160, -60 - G.R:random() * 140, 0.9, BULBS[i % #BULBS + 1], 6, 200, true) end
  end}
end
for _, st in ipairs({42.8, 44.2, 45.6, 46.6}) do
  CUES.sleigh[#CUES.sleigh + 1] = {st, function()
    for i = 1, 3 do
      G:puff(CHIM[1] + (G.R:random() - 0.5) * 26, CHIM[2] - 8, {0.18, 0.16, 0.16}, 14 + G.R:random() * 8, (G.R:random() - 0.5) * 24, -40 - G.R:random() * 20, 0.9, 0.55)
    end
  end}
end

-- ------------------------------------------------------------------ a Texas Christmas
local SNOWMAN_X = 220
local function tumble_in(lt, k)
  -- tumbleweed k rolled in from the left, to its place on the snowman
  local t0 = 10 + (k - 1) * 6
  local ys = {930, 874, 830}
  local x = lerp(-80, SNOWMAN_X, prog(lt, t0, t0 + 3))
  local y = lerp(ys[1], ys[k], prog(lt, t0 + 3, t0 + 4)) - (lt < t0 + 3 and abs(sin(lt * 6)) * 20 or 0)
  return x, y, lt > t0
end
local CACTUS = {560, 760}
local function santa_x(lt) return L.path(lt, {{30, W + 120, 0}, {36, 640, 0}, {44, 640, 0}, {50, 690, 0}, {90, 690, 0}}) end
function D.texas(lt, len)
  if not art("texas") then
    G:gradient(0, 0, W, 640, {0.3, 0.6, 0.95}, {0.85, 0.92, 1})
    G:gradient(0, 640, W, H, {0.75, 0.62, 0.38}, {0.6, 0.48, 0.28})
  end
  -- the prickly pear's lights: dark until the star lands on top
  local lit = lt > 40.5
  lg.setBlendMode(lit and "add" or "alpha")
  for i = 0, 22 do
    local a = i * 0.7
    local c = BULBS[i % #BULBS + 1]
    local on = lit and (floor(S.t * 2) + i) % 3 ~= 0
    lg.setColor(c[1] * (lit and 1 or 0.5), c[2] * (lit and 1 or 0.5), c[3] * (lit and 1 or 0.5), lit and (on and 1 or 0.3) or 1)
    lg.circle("fill", CACTUS[1] + cos(a) * (20 + i * 2), CACTUS[2] - 40 + sin(a) * 50 - i * 2, 3.5, 8)
  end
  lg.setBlendMode("alpha")
  -- 72 deg sunny-day thermometer prop on the left post
  lg.setColor(0.45, 0.3, 0.16, 1)
  lg.rectangle("fill", 56, 770, 8, 120)
  lg.setColor(0.96, 0.95, 0.92, 1)
  lg.rectangle("fill", 40, 742, 40, 96, 8, 8, 6)
  lg.setColor(0.25, 0.25, 0.3, 1)
  lg.rectangle("fill", 56, 754, 8, 60, 4, 4, 4)
  lg.setColor(0.9, 0.16, 0.16, 1)
  lg.rectangle("fill", 57, 774, 6, 40, 3, 3, 4)
  lg.circle("fill", 60, 818, 10, 14)
  G:text("72°", 36, 720, 18, {0.9, 0.18, 0.14}, 1, "center", 48)
  -- the star on the cactus: lassoed up there
  local star_x, star_y
  if lt > 38 then
    local f = prog(lt, 38, 40.5)
    star_x, star_y = lerp(640, CACTUS[1] - 10, f), lerp(800, CACTUS[2] - 150, f) - sin(f * pi) * 120
    if lit then C.fx.glow(star_x, star_y, 40, 40, 1, 0.9, 0.4, 0.6) end
    lg.setColor(1, 0.85, 0.25, 1)
    L.star(star_x, star_y, 20, lt * (lt < 40.5 and 6 or 0))
  end
  -- the tumbleweed snowman, ball by ball
  for k = 1, 3 do
    local x, y, show = tumble_in(lt, k)
    if show then
      lg.push()
      lg.translate(x, y)
      lg.rotate(lt < 10 + (k - 1) * 6 + 3 and lt * 5 or 0)
      local r = ({40, 30, 22})[k]
      lg.setColor(0.6, 0.45, 0.28, 1)
      lg.circle("fill", 0, 0, r, 20)
      lg.setColor(0.42, 0.3, 0.16, 1)
      lg.setLineWidth(2)
      for j = 1, 7 do lg.circle("line", cos(j) * r * 0.45, sin(j * 1.3) * r * 0.45, r * 0.4, 8) end
      lg.pop()
    end
  end
  if lt > 28 then
    -- the hat and the eyes: done
    snowman(SNOWMAN_X, 930, 1, true, 0, true)
    lg.setColor(0.1, 0.1, 0.12, 1)
    lg.circle("fill", SNOWMAN_X - 8, 830 - 6, 3, 6)
    lg.circle("fill", SNOWMAN_X + 8, 830 - 6, 3, 6)
  end
  -- the armadillo in a Santa hat, crossing
  if lt < 14 then
    local ax = lerp(-60, W + 60, lt / 14)
    lg.setColor(0.55, 0.48, 0.42, 1)
    lg.arc("fill", "pie", ax, 990, 30, pi, 2 * pi, 20)
    lg.polygon("fill", ax + 28, 984, ax + 46, 990, ax + 28, 990)
    santa_hat(ax + 6, 960, 13, -0.3)
  end
  -- Inky's snow machine
  if lt > 44 then
    lg.setColor(0.6, 0.6, 0.65, 1)
    lg.rectangle("fill", 640, 900, 60, 50, 6, 6, 4)
    lg.setColor(0.3, 0.3, 0.35, 1)
    lg.rectangle("fill", 660, 880, 20, 22)
    G:text("SNOW", 640, 916, 16, {0.2, 0.3, 0.7}, 1, "center", 60)
  end
  -- cowboy Santa on his horse: in, the lasso, then to one side
  local rx = santa_x(lt)
  if lt > 30 then
    lg.push()
    lg.translate(rx, 860)
    lg.scale(-1.3, 1.3)
    lg.setColor(0.45, 0.27, 0.15, 1)
    local trot = (lt < 36 or (lt > 44 and lt < 50)) and 1 or 0
    for i, lx in ipairs({-22, -12, 18, 28}) do
      lg.rectangle("fill", lx + sin(S.t * 8 + i * pi) * 3 * trot - 3, 8, 6, 34)
    end
    lg.ellipse("fill", 0, 0, 36, 16, 20)
    lg.polygon("fill", 26, -8, 42, -34, 52, -30, 36, 4)
    lg.ellipse("fill", 52, -28, 12, 7, 12)
    lg.setColor(0.85, 0.1, 0.12, 1)
    lg.rectangle("fill", -12, -48, 26, 38, 6, 6, 4)
    lg.setColor(1, 1, 1, 1)
    lg.rectangle("fill", -12, -14, 26, 6)
    lg.ellipse("fill", 1, -56, 12, 10, 12)
    lg.setColor(0.95, 0.78, 0.62, 1)
    lg.circle("fill", 1, -64, 8, 12)
    lg.setColor(0.5, 0.32, 0.15, 1)
    lg.ellipse("fill", 1, -70, 20, 4, 12)
    lg.rectangle("fill", -8, -84, 18, 14, 3, 3, 4)
    -- the lasso, swung over his head
    if lt > 36 and lt < 38.5 then
      lg.setColor(0.8, 0.65, 0.35, 1)
      lg.setLineWidth(2)
      lg.ellipse("line", 0 + cos(S.t * 12) * 10, -110, 40, 12, 20)
      lg.line(8, -50, 0, -100)
    end
    lg.pop()
    -- lasso rope connecting Cowboy Santa to the star in flight
    if lt > 38 and lt < 41.2 and star_x then
      lg.setColor(0.82, 0.66, 0.36, 1 - lin(lt, 40.6, 41.2))
      lg.setLineWidth(2.5)
      lg.line(rx - 10, 795, star_x, star_y)
      lg.ellipse("line", star_x, star_y, 20, 10, 14)
      lg.setLineWidth(1)
    end
  end
  -- the cast: rolling the tumbleweeds, dancing in the fake snow, then lined up for the photo
  for k, gi in ipairs({1, 2, 3, 4}) do
    local gx, gy
    local rest_x = k == 4 and 500 or (100 + k * 70)
    local dance_x = 120 + k * 110
    if lt < 30 then
      local x, y, show = tumble_in(lt, min(k, 3))
      local t_end = 10 + (min(k, 3) - 1) * 6 + 4
      if k < 4 and show and lt < t_end then
        gx = x - 60
      elseif k < 4 and lt >= t_end then
        gx = lerp(SNOWMAN_X - 60, rest_x, prog(lt, t_end, t_end + 1.2))
      else
        gx = rest_x
      end
      gy = 900
    elseif lt < 60 then
      gx = lerp(rest_x, dance_x, prog(lt, 30, 31.8))
      if k == 3 and lt > 42.5 then gx = lerp(dance_x, 600, prog(lt, 42.5, 44)) end
      gy = 900 - ((lt > 46) and L.hop(lt + k * 0.3, 0.45, 30) or 0)
    else
      local from_x = k == 3 and 600 or dance_x
      gx = lerp(from_x, ({130, 300, 450, 520})[k], prog(lt, 60, 63))
      gy = 900 - (lt > 72 and L.hop(lt + k * 0.3, 0.5, 20) or 0)
    end
    L.ghost(gx, gy, 32, GH[gi], S.t + k, 0, lt > 46 and lt < 58 and -1 or 0, (lt > 46 and lt < 60) and "happy" or nil)
  end
  local px = lt < 26 and -80 or (lt < 30 and lerp(-60, SNOWMAN_X + 40, prog(lt, 26, 28)) or
             (lt < 60 and lerp(SNOWMAN_X + 40, 330, prog(lt, 30, 31.5)) or lerp(330, 380, prog(lt, 60, 63))))
  local py = 890 - ((lt > 27.5 and lt < 28.5) and sin(lin(lt, 27.5, 28.5) * pi) * 60 or 0)
                 - ((lt > 46 and lt < 60) and L.hop(lt, 0.4, 30) or 0)
  L.pac(px, py, 34, 0, S.t, nil)
  santa_hat(px - 4, py - 38, 18, -0.25)
  -- the photo: the flash, then the picture held, with its white Polaroid border in screen space
  if lt > 67 then
    local f = 1 - lin(lt, 67, 68.2)
    if f > 0 then
      G:after_cam(function()
        lg.setColor(1, 1, 1, f)
        lg.rectangle("fill", 0, 0, W, H)
      end)
    end
  end
  if lt > 64 and lt < 67 then G:say("SAY \"Y'ALL\"!", 384, 760, 28, 1) end
  -- the Polaroid white border & bottom-chin caption drawn in screen space via after_cam
  if lt > 67 then
    G:after_cam(function()
      local b = 26
      lg.setColor(1, 1, 1, 0.94 * lin(lt, 67, 67.6))
      lg.rectangle("fill", 0, 0, W, b)
      lg.rectangle("fill", 0, 0, b, H)
      lg.rectangle("fill", W - b, 0, b, H)
      lg.rectangle("fill", 0, H - b * 5, W, b * 5)
      G:plate("MERRY CHRISTMAS, Y'ALL", H - 114, 34, 0xff4040, L.window(lt, 68, 80, 1))
    end)
  end
  if lt > 38.5 and lt < 41.5 then G:say("YEE-HAW!", rx, 720, 28, 1) end
  if lt > 28 and lt < 31 then G:say("HOWDY!", SNOWMAN_X, 760, 24, 1) end
  if lt > 50 and lt < 54 then G:say("IT'S SNOWING!", 300, 800, 24, 1) end
end
CAM.texas = function(lt)
  local x, y, z = L.shot(lt, {{0, 384, 512, 1}, {8, 384, 760, 1.25}, {11, 120, 860, 1.55}, {13.5, 250, 860, 1.5}, {17, 120, 860, 1.55}, {19.5, 250, 860, 1.5},
                              {23, 120, 860, 1.55}, {25.5, 250, 860, 1.5}, {28, 260, 860, 1.5}, {31, 500, 800, 1.3},
                              {37, 600, 720, 1.4}, {41, 560, 700, 1.4}, {45, 460, 840, 1.3}, {58, 460, 840, 1.3}, {62, 384, 700, 1.1},
                              {67, 384, 700, 1.1}, {80, 384, 760, 1.25}}, W, H)
  return x, y, z, 0
end
CUES.texas = {{3, "whoosh", 0.4}, {13, "clunk", 0.5}, {19, "clunk", 0.5}, {25, "clunk", 0.5}, {28, "pop"}, {30, "jet", 0.3},
              {36.5, "whoosh"}, {40.5, "chime"}, {40.6, "power"}, {46, "pop"}, {50, "cheer"}, {67, "clunk"}, {67.1, "chime"}}
for t = 460, 580, 2 do
  CUES.texas[#CUES.texas + 1] = {t / 10, function()
    for i = 1, 6 do G:spark(670 + (G.R:random() - 0.5) * 10, 880, (G.R:random() - 0.5) * 300, -300 - G.R:random() * 200, 3, {1, 1, 1}, 7, 160) end
  end}
end

-- ------------------------------------------------------------------ trimming the tree
local TREE = {230, 900, 1.2}
local BOX = {110, 960}
local function orn_job(n)                    -- ornament n: its ghost, when it is hung
  return (n - 1) % 4 + 1, 8 + (n - 1) * 1.0
end
local function ghost_tree(lt, i)
  -- each ghost's round: fly to its next ornament's spot, hang it, back to the box
  for n = i, #S.ornaments, 4 do
    local _, t0 = orn_job(n)
    if lt >= t0 - 1.5 and lt < t0 + 1.5 then
      local o = S.ornaments[n]
      local ox, oy = TREE[1] + o[1] * TREE[3] + (o[1] < 0 and -26 or 26), TREE[2] + o[2] * TREE[3]
      if lt < t0 then
        local f = prog(lt, t0 - 1.5, t0)
        return lerp(BOX[1], ox, f), lerp(BOX[2] - 60, oy, f) - sin(f * pi) * 60, n
      end
      local f = prog(lt, t0, t0 + 1.5)
      return lerp(ox, BOX[1], f), lerp(oy, BOX[2] - 60, f) - sin(f * pi) * 60, nil
    end
  end
  return nil
end
local STRING_T = {32, 42}
local STAR_T = 49
local GIFTS = {{330, 880, {0.85, 0.15, 0.2}}, {380, 900, {0.3, 0.5, 0.95}}, {60, 900, {0.95, 0.75, 0.2}}, {420, 860, {0.3, 0.7, 0.35}},
               {300, 920, {0.7, 0.3, 0.85}}}
function D.tree(lt, len)
  local painted = art("room")
  if not painted then G:gradient(0, 0, W, H, {0.25, 0.12, 0.1}, {0.15, 0.07, 0.06}) end
  -- the fire, brighter as the evening goes on
  local warm = 0.35 + 0.25 * prog(lt, 50, 60)
  C.fx.glow(600, 720, 120, 90, 1, 0.5, 0.15, warm + 0.1 * sin(S.t * 8))
  lg.setColor(1, 0.5, 0.1, 0.7 + 0.3 * sin(S.t * 10))
  lg.polygon("fill", 560, 780, 600, 640 + sin(S.t * 7) * 10, 640, 780)
  lg.setColor(1, 0.85, 0.3, 0.8)
  lg.polygon("fill", 580, 780, 600, 690 + sin(S.t * 9) * 8, 620, 780)
  -- rising fireplace embers
  lg.setBlendMode("add")
  for k = 1, 6 do
    local ef = (S.t * (0.45 + k * 0.07) + k * 0.19) % 1
    local ex = 576 + ((k * 17) % 48) + sin(S.t * 3 + k * 2) * 8
    local ey = 768 - ef * 125
    lg.setColor(1, 0.65, 0.18, (1 - ef) * 0.85)
    lg.circle("fill", ex, ey, 2.5 * (1 - ef * 0.5), 6)
  end
  lg.setBlendMode("alpha")
  -- the stockings filling: a lump in each as a present goes in
  for i = 1, 5 do
    local t0 = 54 + (i - 1) * 1.6
    if lt > t0 then
      local sx = 470 + (i - 1) * 56
      rgba(BULBS[i])
      lg.rectangle("fill", sx + 4, 518 - 14 * prog(lt, t0, t0 + 0.4), 26, 16, 3, 3, 4)
    end
  end
  -- the tree
  local orn = 0
  for n = 1, #S.ornaments do
    local _, t0 = orn_job(n)
    if lt >= t0 then orn = n end
  end
  local strung = lin(lt, STRING_T[1], STRING_T[2])
  xmas_tree(TREE[1], TREE[2], TREE[3], S.t, orn, strung, lt > STAR_T, lt > STAR_T)
  -- the presents under it: brought in one by one
  for i, g in ipairs(GIFTS) do
    local t0 = 52 + (i - 1) * 1.6
    if lt > t0 then
      local y = lerp(g[2] - 80, g[2], prog(lt, t0, t0 + 0.5))
      present(g[1] - 30, y, 60, 44, g[3], {1, 0.85, 0.2})
    end
  end
  -- the box of ornaments
  if lt < 34 then
    lg.setColor(0.75, 0.15, 0.15, 1)
    lg.rectangle("fill", BOX[1] - 40, BOX[2] - 30, 80, 40, 4, 4, 4)
    for k = 0, 3 do
      rgba(BULBS[k + 1])
      if k + 1 > orn - 20 then lg.circle("fill", BOX[1] - 24 + k * 16, BOX[2] - 32, 7, 10) end
    end
  end
  -- the ghosts: hanging ornaments in turn; then Pinky with the string of lights spiralling up; then lifting Pac-Man
  for i, c in ipairs(GH) do
    local gx, gy, carrying
    local box_x, box_y = BOX[1] + (i - 2.5) * 50, BOX[2] - 70 - (i % 2) * 30
    local watch_x, watch_y = 420 + i * 60, 700 + sin(S.t + i) * 20
    if lt < 6 then
      gx, gy = lerp(-60 - i * 50, box_x, prog(lt, 1, 6)), lerp(700, box_y, prog(lt, 4.5, 6))
    elseif lt < STRING_T[1] then
      gx, gy, carrying = ghost_tree(lt, i)
      if not gx then gx, gy = box_x, box_y end
    elseif lt < STRING_T[2] + 1 then
      if i == 2 then
        local h = strung * 380 * TREE[3]
        local a = lt * 4
        local w = (1 - strung) * 150 * TREE[3] + 20
        gx, gy = TREE[1] + cos(a) * w, TREE[2] - 40 - h
      else
        local f = prog(lt, STRING_T[1], STRING_T[1] + 1.4)
        gx, gy = lerp(box_x, watch_x, f), lerp(box_y, watch_y, f)
      end
    elseif lt < STAR_T + 2 then
      -- holding Pac-Man up between them
      local gather = prog(lt, STRING_T[2] + 1, STRING_T[2] + 2.2)
      local up = prog(lt, STRING_T[2] + 2.2, STAR_T - 1)
      local px0, py0 = TREE[1] + 70, lerp(820, 450, up)
      local tx, ty = px0 + (i - 2.5) * 46, py0 + 60 + abs(i - 2.5) * 10
      local sx0 = i == 2 and (TREE[1] + 20) or watch_x
      local sy0 = i == 2 and (TREE[2] - 40 - 380 * TREE[3]) or watch_y
      gx, gy = lerp(sx0, tx, gather), lerp(sy0, ty, gather)
    else
      gx, gy = lerp(TREE[1] + 70 + (i - 2.5) * 46, 470 + i * 56, prog(lt, STAR_T + 2, STAR_T + 6)), lerp(510, 900, prog(lt, STAR_T + 2, STAR_T + 6))
      if lt > 62 then gy = 900 - L.hop(lt + i, 2.5, 6) end
    end
    local mood = (lt > STAR_T and lt < STAR_T + 4) and "happy" or (lt > 62 and "happy" or nil)
    L.ghost(gx, gy, 28, c, S.t + i, gx < TREE[1] and 1 or -1, 0, mood)
    if carrying then
      rgba(BULBS[carrying % #BULBS + 1])
      lg.circle("fill", gx + 20, gy + 10, 8, 10)
    end
  end
  -- Pac-Man: the box first, then up with the star
  local px, py
  if lt < STRING_T[2] + 1 then
    px, py = lerp(-60, BOX[1] + 70, prog(lt, 0.5, 5)), 930
  elseif lt < STAR_T + 2 then
    local gather = prog(lt, STRING_T[2] + 1, STRING_T[2] + 2.2)
    local up = prog(lt, STRING_T[2] + 2.2, STAR_T - 1)
    px = lerp(BOX[1] + 70, TREE[1] + 70, gather) - 60 * prog(lt, STAR_T - 1, STAR_T)
    py = lerp(930, 820, gather) + (lerp(820, 450, up) - 820) + sin(S.t * 9) * 4 * (up < 1 and 0 or 1)
  else
    px, py = lerp(TREE[1] + 10, 640, prog(lt, STAR_T + 2, STAR_T + 6)), lerp(450, 880, prog(lt, STAR_T + 2, STAR_T + 6))
  end
  -- cocoa (58-64): Pac-Man round with the mugs, one each
  if lt > 58 and lt < 64.5 then
    px = L.path(lt, {{58, 640, 0}, {59.3, 470 + 56, 0}, {60.6, 470 + 112, 0}, {61.9, 470 + 168, 0}, {63.2, 470 + 224, 0}, {64.5, 640, 0}})
    py = 880
  end
  for i = 1, 4 do
    if lt > 58 + i * 1.3 then
      local gx = 470 + i * 56
      lg.setColor(0.85, 0.2, 0.2, 1)
      lg.rectangle("fill", gx + 14, 890, 16, 18, 3, 3, 4)
      lg.setColor(1, 1, 1, 0.35)
      local ph = (S.t * 0.8 + i * 0.3) % 1
      lg.ellipse("fill", gx + 22, 880 - ph * 30, 4 + ph * 4, 7 + ph * 5, 8)
    end
  end
  -- the light show (64-78): the tree's lights chasing round in waves of colour
  if lt > 64 then
    lg.setBlendMode("add")
    for k = 1, 48 do
      local h = k / 48
      local x = TREE[1] + sin(k * 2.4) * (1 - h) * 150 * TREE[3]
      local y = TREE[2] - 40 - h * 380 * TREE[3]
      local wave = (k - (lt - 64) * 14) % 12
      local c = BULBS[floor(k / 4 + (lt - 64) * 3) % #BULBS + 1]
      local a = wave < 4 and (1 - wave / 4) or 0.15
      C.fx.glow(x, y, 22, 22, c[1], c[2], c[3], a)
    end
    lg.setBlendMode("alpha")
  end
  local pdir = ((lt > 58 and lt < 59.3) or (lt > 63.2 and lt < 64.5)) and pi or 0
  L.pac(px, py, 30, pdir, S.t, (lt > 74 and lt < 77) and 0.9 or nil)
  santa_hat(px - 4, py - 32, 16, -0.25)
  if lt > STRING_T[2] + 1 and lt < STAR_T then
    lg.setColor(1, 0.85, 0.25, 1)
    L.star(px + 34, py - 30, 18, sin(S.t * 3) * 0.2)
  end
  if lt > STAR_T - 3 and lt < STAR_T then G:say("A LITTLE HIGHER...", px, py - 50, 22, 1) end
  if lt > 74 and lt < 77 then G:say("*YAWN*", px, py - 50, 24, 1) end
  if lt > 59 and lt < 61.5 then G:say("COCOA!", px, py - 50, 24, 1) end
  if lt > 66 and lt < 69 then G:say("OOOOH!", 470 + 112, 860, 24, 1) end
  G:plate("O CHRISTMAS TREE", 120, 34, 0x5fd16a, L.window(lt, STAR_T + 1, 72, 1.5))
end
CAM.tree = function(lt)
  if lt > STRING_T[1] and lt < STRING_T[2] then
    local h = lin(lt, STRING_T[1], STRING_T[2]) * 380 * TREE[3]
    return L.shot(0, {{0, TREE[1] + 20, TREE[2] - 40 - h, 1.6}}, W, H)
  end
  return L.shot(lt, {{0, 384, 512, 1}, {6, 300, 640, 1.35}, {31, 260, 600, 1.35}, {32, TREE[1] + 20, TREE[2] - 40, 1.6},
                     {42, TREE[1] + 20, TREE[2] - 40 - 456, 1.6}, {STAR_T - 1, TREE[1] + 40, 440, 1.6}, {STAR_T + 1.5, TREE[1] + 40, 440, 1.6},
                     {STAR_T + 4, 384, 512, 1}, {54, 384, 512, 1}, {58, 560, 820, 1.5}, {64.5, 620, 800, 1.45},
                     {66.5, 400, 700, 1.2}, {71, TREE[1] + 60, 600, 1.3}, {76, 384, 600, 1.1}, {80, 384, 600, 1.05}}, W, H)
end
CUES.tree = {{STAR_T, "power"}, {STAR_T + 0.2, "cheer"}, {STAR_T + 0.1, "chime"}, {STRING_T[1], "whoosh", 0.4}, {74, "boing", 0.4},
             {64.2, "clunk"}, {64.5, "chime"}, {67, "chime", 0.6}, {70, "chime", 0.7}}
for i = 1, 4 do CUES.tree[#CUES.tree + 1] = {58 + i * 1.3, "pop", 0.35} end
for n = 1, 24 do
  local _, t0 = orn_job(n)
  CUES.tree[#CUES.tree + 1] = {t0, "ding", 0.35}
end
for i = 1, 5 do
  CUES.tree[#CUES.tree + 1] = {52 + (i - 1) * 1.6, "pop", 0.4}
  CUES.tree[#CUES.tree + 1] = {54 + (i - 1) * 1.6, "tick", 0.4}
end
CUES.tree[#CUES.tree + 1] = {STAR_T, function()
  for i = 1, 50 do
    local a = i / 50 * 2 * pi
    G:spark(TREE[1], TREE[2] - 410 * TREE[3], cos(a) * 200, sin(a) * 200, 1.1, {1, 0.85, 0.3}, 7, 60, true)
  end
end}

-- ------------------------------------------------------------------ cookies for Santa
local PLATE = {300, 690}
local SNEAK = {{6, 1, 1}, {14, 2, 1}, {22, 3, 3}, {30, 4, 3}}          -- when, who, how many
local function cookies_left(lt)
  local n = 8
  for _, s in ipairs(SNEAK) do if lt > s[1] + 3.5 then n = n - s[3] end end
  if lt > 49 then n = min(8, floor((lt - 49) / 0.7) + 1) end
  return max(0, n)
end
local function milk(lt)
  local m = 1 - 0.6 * prog(lt, 17.5, 19)
  if lt > 54 then m = lerp(m, 1, prog(lt, 54, 55)) end
  return m
end
function D.cookies(lt, len)
  local painted = art("cookies")
  if not painted then
    G:gradient(0, 0, W, H, {0.95, 0.88, 0.75}, {0.85, 0.7, 0.55})
    lg.setColor(0.95, 0.95, 0.97, 1)
    lg.ellipse("fill", PLATE[1], PLATE[2], 200, 70, 40)
  end
  -- the milk in the glass
  lg.setColor(1, 1, 1, 1)
  local m = milk(lt)
  lg.rectangle("fill", 566, 600 + 100 * (1 - m), 78, 100 * m)
  -- the cookies on the plate
  local left = cookies_left(lt)
  for i = 1, 8 do
    if i <= left then
      local a = i / 8 * 2 * pi
      local x, y = PLATE[1] + cos(a) * 110, PLATE[2] + sin(a) * 36
      lg.setColor(0.8, 0.55, 0.3, 1)
      lg.ellipse("fill", x, y, 34, 14, 16)
      lg.setColor(0.3, 0.18, 0.1, 1)
      for k = 0, 2 do lg.circle("fill", x - 12 + k * 12, y - 3 + (k % 2) * 5, 3, 6) end
    end
  end
  -- the crumbs: a trail from the plate to the curtain, more with every cookie gone
  local gone = 8 - (lt < 49 and left or 0)
  lg.setColor(0.65, 0.42, 0.22, 1)
  for k = 1, gone * 3 do
    local f = k / 24
    lg.circle("fill", lerp(PLATE[1] - 160, 20, f) + sin(k * 3.1) * 8, lerp(740, 600, f) + cos(k * 2.3) * 10, 3, 6)
  end
  -- the note, and the P.S.
  G:text("DEAR SANTA,", 556, 794, 20, {0.3, 0.2, 0.4}, 1, "left", 190)
  G:text("WE WERE GOOD.", 556, 820, 20, {0.3, 0.2, 0.4}, 1, "left", 190)
  G:text("MOSTLY.", 556, 846, 20, {0.3, 0.2, 0.4}, 1, "left", 190)
  if lt > 55 then G:text("P.S. SORRY!", 556, 872, 20, {0.8, 0.15, 0.2}, lin(lt, 55, 56), "left", 190) end
  -- the sneaks: in from the left on tiptoe, looking round, the grab, away
  for _, sn in ipairs(SNEAK) do
    local t0, who, n = sn[1], sn[2], sn[3]
    local dur = who == 2 and 7.2 or 6.5
    if lt > t0 and lt < t0 + dur then
      local x, look, happy
      if who == 2 then
        -- Pinky walks to plate, then walks smoothly to the milk glass (540), drinks (17.5..19.2), then walks out
        if lt < t0 + 2.5 then
          x = lerp(-60, PLATE[1] - 140, prog(lt, t0, t0 + 2.5))
          look = sin(lt * 5) > 0 and 1 or -1
        elseif lt < t0 + 3.5 then
          x = lerp(PLATE[1] - 140, 540, prog(lt, t0 + 2.5, t0 + 3.5))
          look = 1
        elseif lt < t0 + 5.2 then
          x = 540
          look = 1
          happy = true
        else
          x = lerp(540, -80, prog(lt, t0 + 5.2, t0 + dur))
          look = -1
        end
      else
        if lt < t0 + 2.5 then
          x = lerp(-60, PLATE[1] - 140, prog(lt, t0, t0 + 2.5))
          look = sin(lt * 5) > 0 and 1 or -1
        elseif lt < t0 + 4.2 then
          x = PLATE[1] - 140
          look = 1
          happy = lt > t0 + 3
        else
          x = lerp(PLATE[1] - 140, -80, prog(lt, t0 + 4.2, t0 + 6.5))
          look = -1
        end
      end
      local tip = lt < t0 + 2.5 and abs(sin(lt * 7)) * 8 or 0
      L.ghost(x, 620 - tip, 34, GH[who], S.t, look, 0, happy and "happy" or nil)
      -- Pinky's white milk mustache after sipping
      if who == 2 and lt > 18.2 then
        lg.setColor(1, 1, 1, 0.95)
        lg.ellipse("fill", x - 6, 628 - tip, 7, 3.5, 10)
        lg.ellipse("fill", x + 6, 628 - tip, 7, 3.5, 10)
      end
      if lt > t0 + 3.5 and lt < t0 + dur then
        for k = 1, n do
          lg.setColor(0.8, 0.55, 0.3, 1)
          lg.ellipse("fill", x + look * 30, 640 - k * 12, 20, 9, 12)
        end
      end
    end
  end
  -- Pac-Man: in from the right, the empty plate, the trail, the curtain
  if lt > 37 then
    local px = L.path(lt, {{37, W + 60, 0}, {40, 420, 0}, {43, 420, 0}, {46, 160, 0}, {50, 160, 0}, {53, 300, 0}, {60, 300, 0}})
    L.pac(px, 600 - ((lt > 40 and lt < 42) and L.hop(lt, 0.4, 30) or 0), 36, (lt > 43 and lt < 50) and pi or (lt < 40 and pi or 0), S.t,
          (lt > 40 and lt < 42) and 0.9 or nil)
    santa_hat(px - 4, 562, 18, -0.25)
  end
  -- the four of them, caught behind the curtain at the left once Pac-Man arrives (46s), crumbs on their faces
  if lt > 46 then
    for k = 1, 4 do
      local out = lt < 50 and prog(lt, 46 + (k - 1) * 0.35, 46.5 + (k - 1) * 0.35) or 1
      local gx = lerp(-40, 40, out)
      local gy = 480 + k * 70
      if lt > 50 then gx, gy = lerp(40, 380 + (k - 2.5) * 110, prog(lt, 50, 52)), lerp(gy, 520, prog(lt, 50, 52)) - (lt > 56 and L.hop(lt + k, 0.4, 20) or 0) end
      L.ghost(gx, gy, 30, GH[k], S.t + k, 1, 0, lt < 50 and "wide" or "happy")
      if lt < 52 then
        lg.setColor(0.65, 0.42, 0.22, 1)
        lg.circle("fill", gx + 10, gy + 12, 3, 6)
        lg.circle("fill", gx - 6, gy + 16, 2.5, 6)
        if k == 2 then
          lg.setColor(1, 1, 1, 0.95)
          lg.ellipse("fill", gx - 5, gy + 8, 6, 3, 10)
          lg.ellipse("fill", gx + 5, gy + 8, 6, 3, 10)
        end
      end
    end
  end
  if lt > 40 and lt < 43 then G:say("?!", 420, 540, 32, 1) end
  if lt > 47 and lt < 50 then G:say("WASN'T US!", 60, 500, 24, 1) end
  if lt > 17.5 and lt < 19.2 then G:say("GLUG GLUG", 540, 560, 22, 1) end
end
CAM.cookies = function(lt)
  local keys = {{0, 384, 512, 1}, {5, 300, 650, 1.3}}
  for _, sn in ipairs(SNEAK) do
    local t0 = sn[1]
    local tx = sn[2] == 2 and 540 or PLATE[1] - 120
    keys[#keys + 1] = {t0 + 0.3, 120, 620, 1.75}
    keys[#keys + 1] = {t0 + 2.5, PLATE[1] - 120, 640, 1.75}
    if sn[2] == 2 then
      keys[#keys + 1] = {t0 + 3.6, tx, 640, 1.85}
      keys[#keys + 1] = {t0 + 5.2, tx, 650, 1.85}
      keys[#keys + 1] = {t0 + 7.0, 260, 650, 1.35}
    else
      keys[#keys + 1] = {t0 + 4.2, tx, 650, 1.9}
      keys[#keys + 1] = {t0 + 6.3, 260, 650, 1.35}
    end
  end
  for _, k in ipairs({{37, 300, 650, 1.35}, {39, 420, 640, 1.3}, {43, 420, 640, 1.3},
                     {46, 170, 620, 1.6}, {50, 170, 620, 1.6}, {52, 330, 640, 1.3}, {54, 620, 800, 1.6}, {57, 620, 800, 1.6},
                     {60, 384, 512, 1}}) do keys[#keys + 1] = k end
  return L.shot(lt, keys, W, H)
end
CUES.cookies = {{40, "boing"}, {46.0, "pop", 0.4}, {46.35, "pop", 0.4}, {46.7, "pop", 0.4}, {47.05, "pop", 0.4}, {55, "chime"}, {56, "cheer"}}
for _, sn in ipairs(SNEAK) do CUES.cookies[#CUES.cookies + 1] = {sn[1] + 3.5, "pop"} end
for k = 0, 7 do CUES.cookies[#CUES.cookies + 1] = {49 + k * 0.7, "tick", 0.5} end

-- ------------------------------------------------------------------ silent night
local HOUSES = {{20, 120, 640}, {150, 110, 660}, {270, 90, 620}, {380, 140, 650}, {540, 120, 670}, {670, 100, 640}}
local WINDOWS = {}
for _, h in ipairs(HOUSES) do
  for k = 0, 1 do WINDOWS[#WINDOWS + 1] = {h[1] + 18 + k * (h[2] - 60), h[3] + 40} end
end
local OUT_ORDER = {3, 9, 1, 12, 6, 4, 10, 2, 11, 5, 8}      -- (window 7, Pac-Man's, goes last)
-- the windows light up one by one as the carolers sing (people coming to listen), then go out at bedtime
local function window_on(i)
  if i == 7 then return 20 end
  for k, n in ipairs(OUT_ORDER) do if n == i then return 8 + (#OUT_ORDER - k) * 1.6 end end
  return 8
end
local function window_out(i)
  for k, n in ipairs(OUT_ORDER) do if n == i then return 31 + k * 1.6 end end
  return 82
end
local function santa_xy(lt)
  local f = lin(lt, 70, 82)
  return lerp(-160, W + 160, f), 300 - sin(f * pi) * 90
end
function D.silent(lt, len)
  if not art("silent") then G:gradient(0, 0, W, 760, {0.01, 0.02, 0.08}, {0.08, 0.1, 0.25}) end
  -- the star over the steeple, brightening at the end
  local glow = 0.5 + 0.5 * prog(lt, 84, 92)
  C.fx.glow(560, 160, 120 + 80 * glow, 120 + 80 * glow, 1, 0.95, 0.7, 0.5 * glow + 0.2)
  lg.setColor(1, 0.97, 0.8, 1)
  L.star(560, 160, 16 + 6 * glow, 0)
  -- the windows: lit, going out one by one
  for i, w in ipairs(WINDOWS) do
    if lt < window_out(i) and lt > window_on(i) then
      local fl = ((lt > window_out(i) - 0.4) or (lt < window_on(i) + 0.3)) and (floor(S.t * 20) % 2) or 1
      lg.setColor(1, 0.82, 0.54, 0.95 * fl)
      lg.rectangle("fill", w[1], w[2], 24, 30)
      lg.setColor(0.06, 0.06, 0.12, 1)
      lg.rectangle("fill", w[1] + 11, w[2], 2, 30)
      C.fx.glow(w[1] + 12, w[2] + 15, 30, 30, 1, 0.75, 0.38, 0.25 * fl)
    end
  end
  -- Pac-Man at his window, waving goodnight
  local pw = WINDOWS[7]
  if lt > 22 and lt < window_out(7) then
    L.pac(pw[1] + 12, pw[2] + 18, 9, pi, S.t, 0.3)
  end
  -- the church bell: the steeple's window pulsing as it rings
  if lt > 60 and lt < 70 then
    local ring = abs(sin((lt - 60) * pi / 2))
    C.fx.glow(470, 490, 60, 60, 1, 0.85, 0.5, 0.6 * ring)
  end
  -- the carolers, lanterns lit, along the street; stopping to sing; going home
  if lt < 50 then
    local x0 = L.path(lt, {{0, -200, 0}, {18, 330, 0, "lin"}, {30, 330, 0}, {50, W + 280, 0, "lin"}})
    for k = 1, 4 do
      local gx = x0 - (k - 1) * 70
      local gy = 880 - abs(sin(S.t * 3 + k)) * 6
      local sway = sin(S.t * 2 + k) * 0.3
      L.ghost(gx, gy, 38, GH[k], S.t + k, 0, -0.5, (lt > 18 and lt < 30) and "happy" or nil)
      local lx, ly = gx + 36 + sin(sway) * 10, gy + 8
      C.fx.glow(lx, ly, 34, 34, 1, 0.8, 0.4, 0.6)
      lg.setColor(1, 0.85, 0.4, 1)
      lg.rectangle("fill", lx - 5, ly - 8, 10, 16, 2, 2, 4)
      if lt > 4 and lt < 32 then notes(gx, gy - 40, S.t + k) end
    end
  end
  -- snow angels in the new snow (50-60): down on their backs, wings swept, up again; the angels stay
  if lt >= 50 then
    for k = 1, 4 do
      local ax = 150 + (k - 1) * 150
      local ay = 935
      local made = lt > 52 + k * 0.4
      local sweep = (lt > 52 + k * 0.4 and lt < 58) and abs(sin((lt - 52) * 3 + k)) or (lt >= 58 and 1 or 0)
      if made then
        lg.setColor(0.6, 0.7, 0.9, 0.9)
        lg.ellipse("fill", ax, ay, 26, 40, 16)
        lg.ellipse("fill", ax, ay + 34, 30 + 10 * sweep, 18, 16)
        lg.polygon("fill", ax, ay - 10, ax - 40 - 30 * sweep, ay - 40 + 10 * sweep, ax - 30, ay + 10)
        lg.polygon("fill", ax, ay - 10, ax + 40 + 30 * sweep, ay - 40 + 10 * sweep, ax + 30, ay + 10)
      end
      if lt < 61 then
        local x = lerp(-80 - k * 60, ax, prog(lt, 50 + k * 0.25, 51.8 + k * 0.25))
        if lt > 58.5 then x = lerp(ax, W + 100 + k * 60, prog(lt, 58.5 + k * 0.2, 61)) end
        lg.push()
        lg.translate(x, ay)
        if lt > 52 + k * 0.4 and lt < 58.5 then lg.rotate(-pi / 2) lg.scale(1, 0.85) end
        L.ghost(0, (lt > 52 + k * 0.4 and lt < 58.5) and 0 or -24, 30, GH[k], S.t + k, 0, -1, "happy")
        lg.pop()
      end
    end
  end
  -- Santa across the sky with Ghost Reindeer for continuity, a present dropped into a chimney
  if lt > 70 and lt < 82 then
    local sx, sy = santa_xy(lt)
    reindeer(sx, sy, 0.72, S.t, 1)
    sleigh_draw(sx, sy, 0.72, -0.08, true)
  end
  if lt > 76 and lt < 79 then
    local f = lin(lt, 76, 79)
    local dx0, dy0 = santa_xy(76)
    C.fx.glow(lerp(dx0, 455, f), lerp(dy0, 610, f), 14, 14, 1, 0.9, 0.5, 1)
  end
  -- a shooting star
  if lt > 88 and lt < 89.5 then
    local f = lin(lt, 88, 89.5)
    lg.setColor(1, 1, 1, 1 - f)
    lg.setLineWidth(3)
    lg.line(lerp(120, 420, f), lerp(80, 220, f), lerp(120, 420, f) - 60, lerp(80, 220, f) - 28)
  end
  if lt > 23 and lt < 27 then G:say("GOODNIGHT!", pw[1] + 12, pw[2] - 6, 22, 1) end
  if lt > 72 and lt < 76 then local sx, sy = santa_xy(lt) G:say("HO HO HO!", sx, sy - 70, 24, 1) end
  snowfall(160)
end
CAM.silent = function(lt)
  if lt < 18 then
    local x0 = L.path(lt, {{0, -200, 0}, {18, 330, 0, "lin"}})
    return L.shot(0, {{0, lerp(240, x0 - 60, prog(lt, 0, 4)), 720, lerp(1.1, 1.25, prog(lt, 0, 4))}}, W, H)
  end
  local keys = {{18, 230, 780, 1.45}, {22, 420, 730, 1.5}, {28, 420, 730, 1.5}}
  for k, n in ipairs(OUT_ORDER) do
    local w = WINDOWS[n]
    keys[#keys + 1] = {31 + k * 1.6 - 0.6, w[1] + 12, w[2] + 60, 1.7}
    keys[#keys + 1] = {31 + k * 1.6 + 0.5, w[1] + 12, w[2] + 60, 1.7}
  end
  if lt > 70.5 and lt < 81 then
    local sx, sy = santa_xy(lt)
    return L.shot(0, {{0, sx, sy + 60, 1.4}}, W, H)
  end
  for _, k in ipairs({{50, 384, 860, 1.3}, {53, 384, 880, 1.4}, {58, 384, 880, 1.4}, {60, 384, 620, 1.15},
                     {61, 470, 470, 1.7}, {69, 470, 470, 1.7}, {70.5, 160, 380, 1.4}, {81, 600, 380, 1.4}, {82, 384, 400, 1.15}, {86, 560, 260, 1.4},
                     {95, 560, 260, 1.4}, {100, 384, 512, 1}}) do keys[#keys + 1] = k end
  return L.shot(lt, keys, W, H)
end
CUES.silent = {{52.5, "whoosh", 0.3}, {53, "whoosh", 0.3}, {53.4, "whoosh", 0.3}, {58.5, "boing", 0.4}, {72, "chime", 0.5},
               {60.2, "chime"}, {62.2, "chime"}, {64.2, "chime"}, {66.2, "chime"}, {70, "whoosh", 0.4}, {79, "ding", 0.5}, {88, "whoosh", 0.3},
               {23, "chime", 0.5}}
for i = 1, #WINDOWS do
  CUES.silent[#CUES.silent + 1] = {window_out(i), "tick", 0.4}
  CUES.silent[#CUES.silent + 1] = {window_on(i), "ding", 0.15}
end

-- ------------------------------------------------------------------ MERRY CHRISTMAS
-- what came in each present (a: seconds since it opened), playing on to the end of the show
local function toy(i, x, a)
  local y = 820
  if i == 1 then                                       -- a bouncy ball, bouncing about
    local bx = x + sin(a * 1.3) * 60
    local by = y - L.hop(a, 0.8, 140)
    lg.setColor(1, 0.25, 0.3, 1) lg.circle("fill", bx, by, 22, 20)
    lg.setColor(1, 1, 1, 0.9) lg.rectangle("fill", bx - 22, by - 3, 44, 6)
  elseif i == 2 then                                   -- a toy rocket, up on its sparks and down on a parachute
    local up = a < 1.6 and ease(a / 1.6) * 520 or 520 - min(520, (a - 1.6) * 60)
    local rx, ry = x, y - up
    if a > 1.6 then lg.setColor(1, 1, 1, 1) lg.arc("fill", "pie", rx, ry - 50, 34, pi, 2 * pi, 14) lg.setLineWidth(1) lg.line(rx - 34, ry - 50, rx, ry - 20, rx + 34, ry - 50) end
    lg.setColor(0.9, 0.9, 0.95, 1) lg.rectangle("fill", rx - 9, ry - 30, 18, 46, 8, 8, 6)
    lg.setColor(1, 0.3, 0.3, 1) lg.polygon("fill", rx - 9, ry - 26, rx + 9, ry - 26, rx, ry - 44)
  elseif i == 3 then                                   -- a jack-in-the-box, boing
    local pop = min(1, a * 3)
    local bob = sin(a * 6) * 10 * max(0, 1 - a / 6)
    lg.setColor(0.2, 0.5, 0.95, 1) lg.rectangle("fill", x - 30, y - 50, 60, 50, 6, 6, 4)
    lg.setColor(0.7, 0.7, 0.75, 1) lg.setLineWidth(3)
    for k = 0, 5 do lg.circle("line", x, y - 50 - k * 12 * pop - bob * k / 5, 10, 10) end
    lg.setColor(1, 0.85, 0.7, 1) lg.circle("fill", x, y - 50 - 72 * pop - bob, 18, 16)
    lg.setColor(1, 0.2, 0.3, 1) lg.polygon("fill", x - 18, y - 62 - 72 * pop - bob, x + 18, y - 62 - 72 * pop - bob, x, y - 96 - 72 * pop - bob)
  elseif i == 4 then                                   -- a toy train, round and round the presents
    local tx = 384 + cos(a * 0.9) * 300
    local ty = 930 + sin(a * 0.9) * 30
    local dir = -sin(a * 0.9) >= 0 and 1 or -1
    for c = 0, 2 do
      local cx = tx - dir * c * 40
      lg.setColor(({{0.9, 0.2, 0.2}, {0.2, 0.6, 0.3}, {0.2, 0.4, 0.9}})[c + 1]) lg.rectangle("fill", cx - 16, ty - 22, 32, 20, 4, 4, 4)
      lg.setColor(0.1, 0.1, 0.1, 1) lg.circle("fill", cx - 8, ty, 5, 8) lg.circle("fill", cx + 8, ty, 5, 8)
    end
  elseif i == 5 then                                   -- a balloon, up and away
    local bx, by = x + sin(a * 1.5) * 20, y - 40 - a * 40
    if by > -60 then
      lg.setColor(0.6, 0.6, 0.6, 1) lg.setLineWidth(1) lg.line(bx, by + 30, bx + sin(a * 3) * 6, by + 80)
      lg.setColor(1, 0.85, 0.2, 1) lg.ellipse("fill", bx, by, 26, 32, 18)
    end
  else                                                 -- a puppy, wagging, hopping
    local px, py = x + sin(a * 0.7) * 40, y - L.hop(a, 0.6, 16)
    local pdir = cos(a * 0.7) >= 0 and 1 or -1
    lg.push()
    lg.translate(px, py)
    lg.scale(pdir, 1)
    lg.setColor(0.75, 0.55, 0.35, 1) lg.ellipse("fill", 0, -20, 30, 20, 16) lg.circle("fill", 26, -40, 16, 14)
    lg.setColor(0.55, 0.38, 0.22, 1) lg.ellipse("fill", 34, -50, 7, 12, 8)
    lg.setLineWidth(5) lg.line(-28, -26, -44, -40 + sin(a * 20) * 8)
    lg.setColor(0.1, 0.1, 0.1, 1) lg.circle("fill", 30, -44, 3, 6) lg.circle("fill", 40, -38, 4, 6)
    lg.setLineWidth(1)
    lg.pop()
  end
end
function D.finale(lt, len)
  if not art("finale") then G:gradient(0, 0, W, H, {0.02, 0.03, 0.1}, {0.12, 0.05, 0.08}) end
  G:draw_back()
  G:caption("MERRY CHRISTMAS", 360, 70, 0xff4040, L.window(lt, 0.5, len, 1))
  G:caption("AND A HAPPY NEW YEAR", 460, 34, 0x5fd16a, L.window(lt, 2, len, 1))
  -- the cast hopping in, presents raining down and opening one by one
  for i = 1, 5 do
    local t0 = 1.5 + i * 1.2
    if lt > t0 then
      local x = 130 + (i - 1) * 127
      local y = lerp(H + 60, 700, prog(lt, t0, t0 + 0.6)) - L.hop(lt + i * 0.2, 0.5, 18)
      if i == 3 then
        L.pac(x, y, 40, 0, S.t, nil)
        santa_hat(x - 4, y - 40, 22, -0.3)
      else
        L.ghost(x, y, 36, GH[i < 3 and i or i - 1], S.t + i, 0, -0.4, "happy")
        santa_hat(x, y - 34, 18, -0.2)
      end
    end
  end
  -- draw all 6 gift boxes first, then all opened toys in a second pass so toy train passes cleanly in front
  for i = 1, 6 do
    local t0 = 10 + i * 3.6
    if lt > t0 - 1.2 then
      local x = 100 + (i - 1) * 113
      local y = lerp(-60, 820, prog(lt, t0 - 1.2, t0))
      present(x - 40, y, 80, 60, BULBS[i % #BULBS + 1], {1, 0.9, 0.3}, lt > t0 + 0.4 and prog(lt, t0 + 0.4, t0 + 0.9) or nil)
    end
  end
  for i = 1, 6 do
    local t0 = 10 + i * 3.6
    if lt > t0 + 0.6 then
      toy(i, 100 + (i - 1) * 113, lt - t0 - 0.6)
    end
  end
  snowfall(120)
end
CAM.finale = function(lt)
  local keys = {{0, 384, 512, 1}, {10, 384, 560, 1.1}}
  for i = 1, 6 do
    local t0 = 10 + i * 3.6
    keys[#keys + 1] = {t0 - 0.8, 100 + (i - 1) * 113, 700, 1.45}
    keys[#keys + 1] = {t0 + 1.6, 100 + (i - 1) * 113, 700, 1.45}
  end
  keys[#keys + 1] = {36, 384, 512, 1}
  return L.shot(lt, keys, W, H)
end
CUES.finale = {{2.7, "pop"}, {3.9, "pop"}, {5.1, "pop"}, {6.3, "pop"}, {7.5, "pop"}, {8, "cheer"}}
for i = 1, 6 do
  CUES.finale[#CUES.finale + 1] = {10 + i * 3.6 + 0.4, function()
    local x = 100 + (i - 1) * 113
    for k = 1, 30 do G:spark(x, 840, (G.R:random() - 0.5) * 260, -150 - G.R:random() * 260, 1.6, BULBS[k % #BULBS + 1], 7, 300) end
    C.sfx("pop")
  end}
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
  S.art = {}
  for _, n in ipairs({"open", "street", "sleigh", "texas", "room", "cookies", "silent", "finale"}) do
    S.art[n] = G:art("christmas", n)
  end
  local R = G.R
  S.snow = {}
  for i = 1, 240 do
    S.snow[i] = {R:random() * W, R:random() * H, 0.25 + R:random() * 0.5, 0.5 + R:random() * 0.5, 30 + R:random() * 50}
  end
  S.snowb = G:track(lg.newSpriteBatch(G.dot, 260, "stream"))
  S.ornaments, S.tlights = {}, {}
  for i = 1, 24 do
    local h = R:random() * 360
    local w = (1 - h / 400) * 130
    S.ornaments[i] = {(R:random() * 2 - 1) * w * 0.85, -60 - h}
  end
  table.sort(S.ornaments, function(a, b) return a[2] > b[2] end)          -- (hung from the bottom up)
  for i = 1, 60 do
    local h = R:random() * 380
    local w = (1 - h / 410) * 140
    S.tlights[i] = {(R:random() * 2 - 1) * w * 0.9, -50 - h}
  end
  for _, s in ipairs(SCENES) do if s[4] then G:label(s[4], 56, 0xffffff, s[1]) end end
  for _, l in ipairs({{"PRESENTS", 26, 0x6ef0c8, 0}, {"CHRISTMAS", 80, 0xff4040, 0},
                      {"MERRY CHRISTMAS", 70, 0xff4040, 500}, {"AND A HAPPY NEW YEAR", 34, 0x5fd16a, 500},
                      {"MERRY CHRISTMAS, Y'ALL", 34, 0xff4040, 180},
                      {"O CHRISTMAS TREE", 34, 0x5fd16a, 260}}) do
    G:label(l[1], l[2], l[3], l[4])
  end
end

function M.act() return S and scene_at(S.t)[2] or "open" end
function M.music() return S and scene_at(S.t)[3] or "xm_bells" end

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
  -- the snow: falling, drifting, round again from the top
  for _, f in ipairs(S.snow) do
    f[2] = f[2] + f[5] * dt
    f[1] = f[1] + sin(S.t * 0.8 + f[5]) * 12 * dt
    if f[2] > H + 10 then f[2] = -10 f[1] = G.R:random() * W end
  end
  if sc[2] == "finale" then
    S.fw = (S.fw or 0) - dt
    if S.fw <= 0 then
      S.fw = 0.5 + G.R:random() * 0.6
      G:rocket(120 + G.R:random() * 520, 120 + G.R:random() * 200,
               {from = 1024, colours = {{1, 0.2, 0.2}, {0.2, 0.9, 0.3}, {1, 0.85, 0.3}, {1, 1, 1}}})
    end
    -- toy rocket sparks (gift #2, opens at 17.8, ascends 1.6s)
    local ra = lt - (10 + 2 * 3.6 + 0.6)
    if ra > 0 and ra < 1.6 then
      S.rspark = (S.rspark or 0) - dt
      if S.rspark <= 0 then
        S.rspark = 0.04
        local rx = 100 + 113
        local ry = 820 - ease(ra / 1.6) * 520
        G:spark(rx, ry + 30, (G.R:random() - 0.5) * 40, 120, 0.4, {1, 0.7, 0.2}, 5, 0, true)
      end
    end
    -- toy train steam puffs (gift #4, opens at 25.0)
    local ta = lt - (10 + 4 * 3.6 + 0.6)
    if ta > 0 then
      S.tpuff = (S.tpuff or 0) - dt
      if S.tpuff <= 0 then
        S.tpuff = 0.14
        local tx = 384 + cos(ta * 0.9) * 300
        local ty = 930 + sin(ta * 0.9) * 30
        G:puff(tx, ty - 34, {0.9, 0.9, 0.95}, 18, 0, -24, 0.7, 0.35)
      end
    end
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
  if sc[2] ~= "finale" then G:draw_back() end
  G:draw_front()
  G:unlook()
  if sc[4] then
    G:plate(sc[4], 30, 56, 0xffffff, L.window(lt, 1.5, 9, 1))
    local b = L.window(lt, 2, len - 1.5, 1)
    lg.setColor(0.02, 0.02, 0.06, 0.55 * b)
    lg.rectangle("fill", 0, H - 50, W, 50)
    G:text(sc[5], 0, H - 38, 20, {1, 0.85, 0.85}, b)
  end
  local f = 1 - min(lt / 1.2, (len - lt) / 1.2, 1)
  if f > 0 then
    lg.setColor(0, 0, 0, f)
    lg.rectangle("fill", 0, 0, W, H)
  end
end

return M
