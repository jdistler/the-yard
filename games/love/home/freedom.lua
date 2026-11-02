-- The Freedom Show: Home's other idle show (besides the night, night.lua). A satirical, very patriotic nine and a
-- half minutes, then it plays again with a new roll of the dice:
--   0:00  PARTYCADE PRESENTS ... THE FREEDOM SHOW                                     (fanfare)
--   0:06  I    Morning in America: dawn, the flag goes up the pole, the bald eagle lands on it, a Pac-Man parade
--              in Uncle Sam's hat, jets over in red, white and blue smoke, fireworks in broad daylight  (march)
--   2:10  II   Red Alert: the sky goes red, klaxon, searchlights, BREAKING NEWS, the invaders descend  (alert)
--   2:50  III  The Battle of the Backyard: they shoot holes in the flag (the holes ripple with the cloth); a
--              star-spangled laser cannon fights back, the eagle dives through a column, the jets strafe a row,
--              Pac-Man eats the FREEDOM PELLET and the scared invaders drop onto the lawn to be eaten, and the
--              mothership comes down                                                        (battle)
--   5:30  IV   Mission Accomplished: the flag patched with duct tape, fireworks, confetti, celebratory hot dogs,
--              U! S! A!, the eagle sheds a single tear, the victory parade                    (victory)
--   7:30  V    Sunset: the patched flag in the evening light, a firework now and then         (anthem)
-- Everything is drawn here from shapes and little pixel sprites; the flag is a cloth mesh with its stripes and
-- stars painted once into a texture (and holes and tape painted into it as they happen, before the frame).
--
--   freedom.load(ctx)    ctx: W, H, font, neon_draw, neon_img, fx, sfx(name), log
--   freedom.start(seed, at)   a new show (at: seconds in, for tests)
--   freedom.update(dt)   true when the show has ended
--   freedom.draw()
--   freedom.music()      the song for this moment (songs.lua)
--   freedom.act()        the act's name (logs, tests)
local lg = love.graphics
local ffi = require("ffi")
local F = {}
local C
local W, H = 768, 1024
local LEN = 570
F.LEN = LEN

local sin, cos, floor, min, max, abs, sqrt, pi = math.sin, math.cos, math.floor, math.min, math.max, math.abs, math.sqrt, math.pi
local function clamp(x, a, b) return x < a and a or x > b and b or x end
local function ease(x) x = clamp(x, 0, 1) return x * x * (3 - 2 * x) end
local function lerp(a, b, k) return a + (b - a) * k end
local function rgb(c) return floor(c / 65536) % 256 / 255, floor(c / 256) % 256 / 255, c % 256 / 255 end

local RED = {0.80, 0.11, 0.17}
local WHITE = {0.97, 0.97, 0.95}
local BLUE = {0.14, 0.20, 0.52}
local GOLD = {1, 0.82, 0.3}

-- ------------------------------------------------------------------ the stage
local GROUND = 836
local POLE_X, POLE_TOP = 92, 300
local FLAG_X, FLAG_Y, FW, FH = POLE_X + 5, POLE_TOP + 20, 540, 284
local TW, TH = 608, 320                        -- the flag's texture

-- The barbecue on the lawn (morning, and the victory): Clyde at a kettle grill.
local GRILL_X, GRILL_Y = 640, 930
local function grill_on(t) return (t > 32 and t < 128) or (t > 342 and t < 446) end

local ACTS = {{0, "open"}, {6, "morning"}, {130, "alert"}, {170, "battle"}, {330, "victory"}, {450, "sunset"}}
local MUSIC = {open = "fanfare", morning = "fanfare", alert = "alert", battle = "battle", victory = "victory",
               sunset = "anthem"}

-- The sky through the show: {time, top colour, horizon colour, darkness of the stars' sky 0..1}
local SKY = {
  {0, {0.02, 0.02, 0.10}, {0.08, 0.05, 0.20}, 1},
  {6, {0.05, 0.05, 0.22}, {0.55, 0.30, 0.40}, 0.8},
  {22, {0.16, 0.40, 0.86}, {0.95, 0.70, 0.55}, 0.1},
  {40, {0.14, 0.42, 0.88}, {0.66, 0.86, 1.00}, 0},
  {128, {0.14, 0.42, 0.88}, {0.66, 0.86, 1.00}, 0},
  {140, {0.22, 0.02, 0.06}, {0.70, 0.12, 0.10}, 0.5},
  {172, {0.04, 0.01, 0.10}, {0.30, 0.06, 0.18}, 0.9},
  {330, {0.04, 0.01, 0.10}, {0.30, 0.06, 0.18}, 0.9},
  {340, {0.02, 0.02, 0.12}, {0.12, 0.10, 0.36}, 1},
  {445, {0.02, 0.02, 0.12}, {0.12, 0.10, 0.36}, 1},
  {470, {0.22, 0.10, 0.36}, {1.00, 0.52, 0.26}, 0.35},
  {560, {0.10, 0.05, 0.22}, {0.70, 0.28, 0.30}, 0.7},
  {LEN, {0.02, 0.02, 0.10}, {0.08, 0.05, 0.20}, 1},
}

-- The news crawl, by act.
local TICKER = {
  morning = "FREEDOM NEWS  ·  LOCAL EAGLE NAMED EMPLOYEE OF THE MONTH FOR 248TH YEAR RUNNING  ·  HOT DOG FUTURES UP 1776%  ·" ..
            "  SCIENTISTS CONFIRM FIREWORKS ARE \"VERY COOL\"  ·  WEATHER: 100% CHANCE OF LIBERTY  ·  PAC-MAN WINS PIE-EATING CONTEST, AGAIN  ·",
  alert = "BREAKING  ·  UNIDENTIFIED FLYING OBJECTS OVER THE PARTYCADE  ·  INVADERS DEMAND METRIC SYSTEM  ·" ..
          "  EAGLE UNAVAILABLE FOR COMMENT  ·  RESIDENTS URGED TO REMAIN CALM AND KEEP GRILLING  ·",
  battle = "LIVE  ·  THE BATTLE OF THE BACKYARD  ·  INVADERS FIRE ON FLAG; FLAG \"NOT IMPRESSED\"  ·  CANNON PAINTED IN RECORD TIME  ·" ..
           "  PENTAGON: \"WE HAVE A GUY\"  ·  EXPERTS: INVADERS \"PROBABLY FRENCH\", LATER RETRACTED  ·",
  victory = "VICTORY  ·  ALIENS AGREE TO USE INCHES  ·  FLAG REPAIRED WITH 100% AMERICAN DUCT TAPE  ·  EAGLE SHEDS SINGLE TEAR  ·" ..
            "  FREE REFILLS FOR EVERYONE  ·  HOT DOGS DECLARED A VEGETABLE  ·",
  sunset = "GOOD NIGHT, AMERICA  ·  THE PARTYCADE THANKS YOU FOR YOUR SERVICE  ·  INSERT COIN TO CONTINUE FREEDOM  ·" ..
           "  TOMORROW: MORE OF THIS  ·",
}

-- Captions in the sky: {from, to, text, size, colour}
local CAPTIONS = {
  {26, 34, "LAND OF THE FREE", 50, 0xffffff}, {36, 44, "HOME OF THE HIGH SCORE", 44, 0xffd23f},
  {50, 58, "NOW WITH 50% MORE FREEDOM", 38, 0xffffff}, {64, 72, "BALD EAGLE: CERTIFIED ORGANIC", 34, 0xffd23f},
  {78, 86, "LIBERTY, JUSTICE, UNLIMITED CONTINUES", 30, 0xffffff}, {108, 116, "WE THE PLAYERS", 50, 0xff4a5a},
  {134, 142, "RED ALERT", 72, 0xff3344}, {144, 152, "THIS IS NOT A DRILL", 44, 0xffffff},
  {156, 166, "THEY'RE HERE", 50, 0x7dff8a},
  {286, 292, "FREEDOM PELLET!", 48, 0xffd23f}, {300, 306, "FREEDOM INTENSIFIES", 42, 0xff4a5a},
  {356, 364, "CELEBRATORY HOT DOGS INBOUND", 32, 0xffd23f},
  {412, 420, "TOO MUCH FREEDOM?", 46, 0xffffff}, {421, 428, "NO SUCH THING", 50, 0xff4a5a},
  {476, 486, "GOD BLESS THE PARTYCADE", 40, 0xffd23f}, {500, 510, "THIS SCREEN SAVER WAS PAID FOR", 30, 0xffffff},
  {510, 518, "BY FREEDOM", 50, 0xff4a5a}, {534, 546, "PRESS ANY BUTTON TO PLAY", 34, 0xffffff},
  {556, 569, "FREEDOM WILL RETURN", 44, 0xffffff},
}
-- What the invaders say (speech bubbles, battle): {from, to, text}
local TAUNTS = {{186, 192, "TAKE US TO YOUR LEADERBOARD"}, {214, 219, "WE COME IN PEACE (NOT REALLY)"},
                {248, 254, "THIS PLANET HAS TOO MUCH FREEDOM"}, {274, 279, "IS THAT A PELLET?"}}
-- The letters the last fireworks write
local LETTERS = {
  U = {"X...X", "X...X", "X...X", "X...X", "X...X", "X...X", ".XXX."},
  S = {".XXXX", "X....", "X....", ".XXX.", "....X", "....X", "XXXX."},
  A = {".XXX.", "X...X", "X...X", "XXXXX", "X...X", "X...X", "X...X"},
}
local CHANTS = {346, 368, 404}

-- ------------------------------------------------------------------ state of one showing
local S                                          -- the show's state (F.start)
local R                                          -- its random numbers

-- ------------------------------------------------------------------ pictures, made once
local atlas, Q = nil, {}
local pix                                        -- the sprite batch: invaders, saucer, bullets, debris, confetti
local glowb                                      -- additive soft dots: fireworks, sparks
local dot
local flagcv, mesh, vdata, vp, NU, NV
local cloud_img, dog_img, fence_img, hat_img, mini_img
local smokeb, dogb
local sky_mesh, lawn_mesh
local stars_pts = {}

local SPR = {
  squid1 = {"...XX...", "..XXXX..", ".XXXXXX.", "XX.XX.XX", "XXXXXXXX", "..X..X..", ".X.XX.X.", "X.X..X.X"},
  squid2 = {"...XX...", "..XXXX..", ".XXXXXX.", "XX.XX.XX", "XXXXXXXX", ".X.XX.X.", "X......X", ".X....X."},
  crab1 = {"..X.....X..", "...X...X...", "..XXXXXXX..", ".XX.XXX.XX.", "XXXXXXXXXXX", "X.XXXXXXX.X", "X.X.....X.X", "...XX.XX..."},
  crab2 = {"..X.....X..", "X..X...X..X", "X.XXXXXXX.X", "XXX.XXX.XXX", "XXXXXXXXXXX", ".XXXXXXXXX.", "..X.....X..", ".X.......X."},
  octo1 = {"....XXXX....", ".XXXXXXXXXX.", "XXXXXXXXXXXX", "XXX..XX..XXX", "XXXXXXXXXXXX", "...XX..XX...", "..XX.XX.XX..", "XX........XX"},
  octo2 = {"....XXXX....", ".XXXXXXXXXX.", "XXXXXXXXXXXX", "XXX..XX..XXX", "XXXXXXXXXXXX", "..XXX..XXX..", ".XX..XX..XX.", "..XX....XX.."},
  saucer = {"......XXXX......", "...XXXXXXXXXX...", "..XXXXXXXXXXXX..", ".XX.XX.XX.XX.XX.", "XXXXXXXXXXXXXXXX",
            "..XXX..XX..XXX..", "...X........X..."},
  pop = {"X...X...X", ".X..X..X.", "..X...X..", "XX.....XX", "..X...X..", ".X..X..X.", "X...X...X"},
  px = {"X"},
}

local function make_atlas()
  local d = love.image.newImageData(128, 16)
  local x = 0
  for name, rows in pairs(SPR) do
    local w, h = #rows[1], #rows
    for yy = 1, h do
      for xx = 1, w do
        if rows[yy]:sub(xx, xx) == "X" then d:setPixel(x + xx - 1, yy - 1, 1, 1, 1, 1) end
      end
    end
    SPR[name].x, SPR[name].w, SPR[name].h = x, w, h
    x = x + w + 1
  end
  atlas = lg.newImage(d)
  atlas:setFilter("nearest", "nearest")
  for name, rows in pairs(SPR) do Q[name] = lg.newQuad(rows.x, 0, rows.w, rows.h, 128, 16) end
end

-- A five-pointed star polygon (points up).
local function draw_star(x, y, r, rot)
  -- (concave: the inner pentagon and five tips)
  local ox, oy, ix, iy = {}, {}, {}, {}
  for i = 0, 4 do
    local a = -pi / 2 + i * 2 * pi / 5 + (rot or 0)
    ox[i], oy[i] = x + cos(a) * r, y + sin(a) * r
    ix[i], iy[i] = x + cos(a + pi / 5) * r * 0.382, y + sin(a + pi / 5) * r * 0.382
  end
  lg.polygon("fill", ix[0], iy[0], ix[1], iy[1], ix[2], iy[2], ix[3], iy[3], ix[4], iy[4])
  for i = 0, 4 do
    local j = (i + 4) % 5
    lg.polygon("fill", ox[i], oy[i], ix[i], iy[i], ix[j], iy[j])
  end
end

local function paint_flag()
  lg.push("all")
  lg.origin()
  lg.setCanvas(flagcv)
  lg.clear(0, 0, 0, 0)
  local sh = TH / 13
  for i = 0, 12 do
    local c = i % 2 == 0 and RED or WHITE
    lg.setColor(c[1], c[2], c[3], 1)
    lg.rectangle("fill", 0, floor(i * sh), TW, floor((i + 1) * sh) - floor(i * sh))
  end
  local cw, ch = TW * 0.4, sh * 7
  lg.setColor(BLUE[1], BLUE[2], BLUE[3], 1)
  lg.rectangle("fill", 0, 0, cw, ch)
  lg.setColor(WHITE[1], WHITE[2], WHITE[3], 1)
  local r = TH * 0.0616 / 2 * 1.05
  for row = 0, 8 do
    local y = (row + 1) * ch / 10
    local n = row % 2 == 0 and 6 or 5
    for c = 0, n - 1 do
      local x = row % 2 == 0 and (2 * c + 1) * cw / 12 or (2 * c + 2) * cw / 12
      draw_star(x, y, r)
    end
  end
  -- the weave: faint vertical threads
  lg.setColor(0, 0, 0, 0.035)
  for x = 0, TW, 4 do lg.rectangle("fill", x, 0, 1, TH) end
  lg.setCanvas()
  lg.pop()
end

-- A hole burnt into the flag at (u, v): a scorched ring, then the cloth gone.
local function burn_hole(u, v, r)
  lg.push("all")
  lg.origin()
  lg.setCanvas(flagcv)
  local x, y = u * TW, v * TH
  local ring, hole = {}, {}
  for i = 0, 11 do
    local a = i / 12 * 2 * pi
    local k = 0.75 + R:random() * 0.5
    ring[#ring + 1] = x + cos(a) * (r + 7) * k
    ring[#ring + 1] = y + sin(a) * (r + 7) * k
    hole[#hole + 1] = x + cos(a) * r * k
    hole[#hole + 1] = y + sin(a) * r * k
  end
  lg.setColor(0.18, 0.09, 0.03, 0.85)
  lg.polygon("fill", ring)
  lg.setBlendMode("replace")
  lg.setColor(0, 0, 0, 0)
  lg.polygon("fill", hole)
  lg.setCanvas()
  lg.pop()
end

-- Duct tape over a hole: two strips, crossed.
local function tape_hole(u, v, r)
  lg.push("all")
  lg.origin()
  lg.setCanvas(flagcv)
  local x, y = u * TW, v * TH
  for k = -1, 1, 2 do
    lg.push()
    lg.translate(x, y)
    lg.rotate(k * 0.55 + (R:random() - 0.5) * 0.2)
    lg.setColor(0.70, 0.71, 0.70, 1)
    lg.rectangle("fill", -r * 1.9, -r * 0.55, r * 3.8, r * 1.1)
    lg.setColor(0.55, 0.56, 0.55, 1)
    for i = -3, 3 do lg.rectangle("fill", -r * 1.9, i * r * 0.15, r * 3.8, 1) end
    lg.setColor(0.85, 0.86, 0.85, 1)
    lg.rectangle("fill", -r * 1.9, -r * 0.55, r * 3.8, 2)
    lg.pop()
  end
  lg.setCanvas()
  lg.pop()
end

local paint_hat, paint_mini
local function make_pictures()
  make_atlas()
  pix = lg.newSpriteBatch(atlas, 900, "stream")
  local n = 16
  local d = love.image.newImageData(n, n)
  d:mapPixel(function(x, y)
    local dx, dy = (x + 0.5) / n * 2 - 1, (y + 0.5) / n * 2 - 1
    local v = max(0, 1 - sqrt(dx * dx + dy * dy))
    return 1, 1, 1, v ^ 1.5
  end)
  dot = lg.newImage(d)
  glowb = lg.newSpriteBatch(dot, 1200, "stream")

  flagcv = lg.newCanvas(TW, TH)
  flagcv:setFilter("linear", "linear")
  -- the cloth: (NU+1) x (NV+1) vertices, updated every frame through the FFI
  NU, NV = 30, 14
  pcall(ffi.cdef, "typedef struct { float x, y, u, v; uint8_t r, g, b, a; } freedom_vert;")
  local nverts = (NU + 1) * (NV + 1)
  vdata = love.data.newByteData(nverts * ffi.sizeof("freedom_vert"))
  vp = ffi.cast("freedom_vert*", vdata:getFFIPointer())
  mesh = lg.newMesh(nverts, "triangles", "stream")
  local map = {}
  for j = 0, NV - 1 do
    for i = 0, NU - 1 do
      local a = j * (NU + 1) + i + 1
      local b, c, e = a + 1, a + NU + 1, a + NU + 2
      map[#map + 1] = a map[#map + 1] = b map[#map + 1] = c
      map[#map + 1] = b map[#map + 1] = e map[#map + 1] = c
    end
  end
  mesh:setVertexMap(map)
  mesh:setTexture(flagcv)

  -- a cloud, a hot dog, the fence: painted once
  lg.push("all")
  lg.origin()
  cloud_img = lg.newCanvas(220, 90)
  lg.setCanvas(cloud_img)
  lg.clear(0, 0, 0, 0)
  for _, c in ipairs({{60, 58, 34}, {100, 44, 42}, {148, 54, 36}, {180, 64, 24}, {36, 66, 22}, {120, 66, 30}}) do
    lg.setColor(1, 1, 1, 0.9)
    lg.circle("fill", c[1], c[2], c[3], 32)
  end
  lg.setColor(0.82, 0.86, 0.95, 0.6)
  lg.rectangle("fill", 30, 70, 170, 14, 7, 7, 8)
  dog_img = lg.newCanvas(80, 36)
  lg.setCanvas(dog_img)
  lg.clear(0, 0, 0, 0)
  lg.setColor(0.93, 0.72, 0.40, 1)
  lg.ellipse("fill", 40, 22, 34, 12, 24)
  lg.setColor(0.72, 0.28, 0.18, 1)
  lg.ellipse("fill", 40, 15, 38, 8, 24)
  lg.setColor(1, 0.85, 0.15, 1)
  lg.setLineWidth(3)
  lg.line(10, 14, 20, 11, 30, 15, 40, 11, 50, 15, 60, 11, 70, 14)
  fence_img = lg.newCanvas(W, 70)
  lg.setCanvas(fence_img)
  lg.clear(0, 0, 0, 0)
  lg.setColor(0.92, 0.92, 0.9, 1)
  lg.rectangle("fill", 0, 22, W, 8)
  lg.rectangle("fill", 0, 48, W, 8)
  for x = 4, W, 26 do
    lg.polygon("fill", x, 12, x + 8, 2, x + 16, 12, x + 16, 70, x, 70)
  end
  lg.setColor(0.7, 0.7, 0.68, 1)
  for x = 4, W, 26 do lg.rectangle("fill", x + 13, 12, 3, 58) end
  hat_img = lg.newCanvas(64, 64)
  lg.setCanvas(hat_img)
  lg.clear(0, 0, 0, 0)
  paint_hat(22)
  mini_img = lg.newCanvas(30, 50)
  lg.setCanvas(mini_img)
  lg.clear(0, 0, 0, 0)
  paint_mini()
  lg.setCanvas()
  lg.pop()
  smokeb = lg.newSpriteBatch(dot, 600, "stream")
  dogb = lg.newSpriteBatch(dog_img, 80, "stream")

  sky_mesh = lg.newMesh({{0, 0, 0, 0, 1, 1, 1, 1}, {W, 0, 1, 0, 1, 1, 1, 1}, {W, GROUND, 1, 1, 1, 1, 1, 1},
                         {0, GROUND, 0, 1, 1, 1, 1, 1}}, "fan", "dynamic")
  lawn_mesh = lg.newMesh({{0, GROUND, 0, 0, 0.28, 0.62, 0.22, 1}, {W, GROUND, 1, 0, 0.28, 0.62, 0.22, 1},
                          {W, H, 1, 1, 0.12, 0.36, 0.12, 1}, {0, H, 0, 1, 0.12, 0.36, 0.12, 1}}, "fan", "static")
  local r = love.math.newRandomGenerator(1776)
  for i = 1, 120 do stars_pts[i] = {r:random() * W, r:random() * (GROUND - 120), 0.4 + r:random() * 0.6} end
end

-- ------------------------------------------------------------------ the flag's cloth
-- The flag's corner points this frame (for aiming at it): position of (u, v).
local function flag_point(u, v)
  local t, wind, yoff = S.t, S.wind, S.flag_yoff
  local amp = 30 * wind * u ^ 1.15 + 3 * u
  local ph = u * 9.0 - t * (3.0 + 2.4 * wind) + v * 0.9
  local z = amp * (sin(ph) + 0.28 * sin(2.3 * ph + 1.1 + v * 2.2 + t * 0.9))
  local droop = 1 - wind
  local x = FLAG_X + u * FW * (1 - 0.25 * droop * u) + z * 0.04   -- (more, and the cloth folds over itself)
  local y = FLAG_Y + yoff + v * FH * (1 - 0.04 * wind) + z * 0.5 + droop * u * u * FH * 0.5
  return x, y, ph, amp
end

local function update_cloth()
  local i0 = 0
  for j = 0, NV do
    local v = j / NV
    for i = 0, NU do
      local u = i / NU
      local x, y, ph, amp = flag_point(u, v)
      local k = min(1, amp / 14)
      local shade = 0.80 + 0.20 * cos(ph + 0.9) * k
      local light = S.light
      local q = vp[i0]
      q.x, q.y, q.u, q.v = x, y, u, v
      local s = clamp(shade, 0.4, 1)
      q.r = min(255, floor(255 * s * light[1]))
      q.g = min(255, floor(255 * s * light[2]))
      q.b = min(255, floor(255 * s * light[3]))
      q.a = 255
      i0 = i0 + 1
    end
  end
  mesh:setVertices(vdata)
end

-- ------------------------------------------------------------------ the eagle (shapes)
local EAGLE_BROWN = {0.36, 0.22, 0.12}
local function eagle_wing(x, y, s, ang, dir, shade)
  lg.push()
  lg.translate(x, y)
  lg.scale(dir * s, s)
  lg.rotate(ang)
  lg.setColor(EAGLE_BROWN[1] * shade, EAGLE_BROWN[2] * shade, EAGLE_BROWN[3] * shade, 1)
  lg.polygon("fill", 0, 0, 16, -4, 10, -40, -6, -58, -20, -50, -26, -14)
  -- the fingers at the tip
  lg.polygon("fill", -6, -58, -12, -72, -14, -54)
  lg.polygon("fill", -14, -54, -24, -66, -22, -48)
  lg.polygon("fill", 4, -50, 2, -66, -6, -56)
  lg.pop()
end

-- flying: wings flapping (flap 0..1 through a beat), facing dir (1 right, -1 left)
local function draw_eagle_flying(x, y, s, flap, dir)
  local ang = -0.9 + 1.5 * (0.5 + 0.5 * sin(flap * 2 * pi))
  eagle_wing(x - 4 * s * dir, y - 4 * s, s, ang + 0.25, dir, 0.7)
  -- tail, body, head
  lg.setColor(WHITE[1], WHITE[2], WHITE[3], 1)
  lg.polygon("fill", x - 30 * s * dir, y, x - 52 * s * dir, y - 9 * s, x - 54 * s * dir, y + 9 * s)
  lg.setColor(EAGLE_BROWN[1], EAGLE_BROWN[2], EAGLE_BROWN[3], 1)
  lg.ellipse("fill", x, y, 32 * s, 12 * s, 20)
  lg.setColor(WHITE[1], WHITE[2], WHITE[3], 1)
  lg.circle("fill", x + 30 * s * dir, y - 6 * s, 11 * s, 16)
  lg.setColor(1, 0.78, 0.1, 1)
  lg.polygon("fill", x + 38 * s * dir, y - 9 * s, x + 50 * s * dir, y - 4 * s, x + 40 * s * dir, y + 1 * s)
  lg.setColor(0.05, 0.05, 0.05, 1)
  lg.circle("fill", x + 33 * s * dir, y - 9 * s, 2 * s, 8)
  lg.setColor(1, 0.78, 0.1, 1)
  lg.rectangle("fill", x + 6 * s * dir - 3 * s, y + 10 * s, 6 * s, 6 * s)
  eagle_wing(x, y - 6 * s, s, ang, dir, 1)
end

-- perched on the pole's ball: upright, head turning (look -1..1), a tear maybe
local function draw_eagle_perched(x, y, s, look, tear)
  local dir = look >= 0 and 1 or -1
  lg.setColor(WHITE[1], WHITE[2], WHITE[3], 1)
  lg.polygon("fill", x - 8 * s, y + 18 * s, x + 8 * s, y + 18 * s, x + 12 * s, y + 40 * s, x - 12 * s, y + 40 * s)
  lg.setColor(EAGLE_BROWN[1], EAGLE_BROWN[2], EAGLE_BROWN[3], 1)
  lg.ellipse("fill", x, y + 4 * s, 15 * s, 24 * s, 20)
  lg.setColor(EAGLE_BROWN[1] * 0.7, EAGLE_BROWN[2] * 0.7, EAGLE_BROWN[3] * 0.7, 1)
  lg.ellipse("fill", x - 4 * s * dir, y + 8 * s, 10 * s, 20 * s, 16)
  lg.setColor(WHITE[1], WHITE[2], WHITE[3], 1)
  local hx = x + 3 * s * look
  lg.circle("fill", hx, y - 22 * s, 12 * s, 16)
  lg.setColor(1, 0.78, 0.1, 1)
  lg.polygon("fill", hx + 8 * s * dir, y - 25 * s, hx + 21 * s * dir, y - 20 * s, hx + 9 * s * dir, y - 15 * s)
  lg.setColor(0.05, 0.05, 0.05, 1)
  lg.circle("fill", hx + 4 * s * dir, y - 25 * s, 2 * s, 8)
  -- the brow: stern, always
  lg.setColor(0.85, 0.85, 0.85, 1)
  lg.setLineWidth(2 * s)
  lg.line(hx - 1 * s * dir, y - 30 * s, hx + 8 * s * dir, y - 27 * s)
  if tear then
    lg.setColor(0.55, 0.8, 1, 0.95)
    lg.circle("fill", hx + 4 * s * dir, y - 20 * s + tear * 60 * s, 2.6 * s, 10)
  end
  lg.setColor(1, 0.78, 0.1, 1)
  lg.rectangle("fill", x - 8 * s, y + 26 * s, 5 * s, 6 * s)
  lg.rectangle("fill", x + 3 * s, y + 26 * s, 5 * s, 6 * s)
end

-- Uncle Sam's hat (painted once into hat_img), on whoever's at (x, y) with radius r.
paint_hat = function(r)
  lg.push()
  lg.translate(32, 50)
  lg.setColor(BLUE[1], BLUE[2], BLUE[3], 1)
  lg.rectangle("fill", -r * 0.95, -r * 0.12, r * 1.9, r * 0.22)
  lg.setColor(WHITE[1], WHITE[2], WHITE[3], 1)
  lg.rectangle("fill", -r * 0.55, -r * 1.2, r * 1.1, r * 1.1)
  lg.setColor(RED[1], RED[2], RED[3], 1)
  for i = 0, 2 do lg.rectangle("fill", -r * 0.55 + i * r * 0.4 + r * 0.05, -r * 1.2, r * 0.18, r * 0.8) end
  lg.setColor(BLUE[1], BLUE[2], BLUE[3], 1)
  lg.rectangle("fill", -r * 0.55, -r * 0.42, r * 1.1, r * 0.3)
  lg.setColor(1, 1, 1, 1)
  draw_star(0, -r * 0.27, r * 0.12)
  lg.pop()
end
local function draw_hat(x, y, r, tilt)
  lg.setColor(1, 1, 1, 1)
  lg.draw(hat_img, x, y - r * 0.85, tilt or -0.12, r / 22, r / 22, 32, 50)
end

-- A little flag on a stick, waving (painted once into mini_img: 30 x 50, the stick's foot at 2, 48).
paint_mini = function()
  lg.setColor(0.6, 0.45, 0.3, 1)
  lg.rectangle("fill", 1, 2, 3, 48)
  for i = 0, 4 do
    local c = i % 2 == 0 and RED or WHITE
    lg.setColor(c[1], c[2], c[3], 1)
    lg.rectangle("fill", 4, 2 + i * 4, 25, 4)
  end
  lg.setColor(BLUE[1], BLUE[2], BLUE[3], 1)
  lg.rectangle("fill", 4, 2, 11, 12)
end
local function draw_mini_flag(x, y, t)
  lg.setColor(1, 1, 1, 1)
  lg.draw(mini_img, x - 2, y - 48, sin(t * 5) * 0.06, 1, 1 + sin(t * 9) * 0.04)
end

-- The laser cannon, in the colours.
local function draw_cannon(x, y)
  lg.push()
  lg.translate(x, y)
  lg.scale(1.7, 1.7)
  lg.translate(-x, -y)
  lg.setColor(BLUE[1], BLUE[2], BLUE[3], 1)
  lg.rectangle("fill", x - 5, y - 30, 10, 14)
  lg.rectangle("fill", x - 14, y - 20, 28, 8)
  for i = 0, 3 do
    local c = i % 2 == 0 and RED or WHITE
    lg.setColor(c[1], c[2], c[3], 1)
    lg.rectangle("fill", x - 30, y - 12 + i * 5, 60, 5)
  end
  lg.setColor(1, 1, 1, 1)
  draw_star(x, y - 22, 4)
  lg.pop()
end

-- A jet, side view, facing dir.
local function draw_jet(x, y, s, dir)
  lg.push()
  lg.translate(x, y)
  lg.scale(dir * s, s)
  lg.setColor(0.62, 0.66, 0.72, 1)
  lg.polygon("fill", 40, 0, 20, -6, -30, -6, -38, 0, -30, 5, 20, 5)
  lg.setColor(0.5, 0.54, 0.6, 1)
  lg.polygon("fill", 6, 0, -14, 22, -22, 22, -10, 0)
  lg.polygon("fill", -24, -4, -34, -20, -40, -20, -34, -2)
  lg.setColor(0.3, 0.6, 0.9, 1)
  lg.polygon("fill", 26, -5, 16, -11, 8, -6)
  lg.setColor(BLUE[1], BLUE[2], BLUE[3], 1)
  lg.circle("fill", -6, 0, 4, 10)
  lg.setColor(1, 1, 1, 1)
  lg.circle("fill", -6, 0, 1.6, 8)
  lg.pop()
end

-- ------------------------------------------------------------------ particles
local function spark(x, y, vx, vy, life, c, size, grav, add)
  local list = add and S.glow or S.debris
  if #list > (add and 900 or 500) then return end
  list[#list + 1] = {x = x, y = y, vx = vx, vy = vy, life = life, max = life, c = c, size = size or 3, g = grav or 200}
end

local FIREWORK_COLOURS = {{1, 0.25, 0.3}, {1, 1, 1}, {0.35, 0.5, 1}, {1, 0.85, 0.35}, {1, 0.4, 0.8}}
local function firework(x, y, big)
  local c = FIREWORK_COLOURS[R:random(1, #FIREWORK_COLOURS)]
  local c2 = FIREWORK_COLOURS[R:random(1, #FIREWORK_COLOURS)]
  local n = big and 90 or 55
  local sp = big and 260 or 190
  for i = 1, n do
    local a = i / n * 2 * pi + R:random() * 0.1
    local v = sp * (0.6 + R:random() * 0.45)
    spark(x, y, cos(a) * v, sin(a) * v, 1.4 + R:random() * 0.8, i % 3 == 0 and c2 or c, big and 9 or 7, 90, true)
  end
  spark(x, y, 0, 0, 0.25, {1, 1, 1}, 60, 0, true)
  C.sfx("pop")
  if R:random() < 0.6 then S.later[#S.later + 1] = {S.t + 0.35, "crackle"} end
end

-- A firework that writes a letter: its sparks fly out to the letter's dots and hang there.
local function letter_burst(x, y, ch)
  local g = LETTERS[ch]
  local cell = 17
  for row = 1, 7 do
    for col = 1, 5 do
      if g[row]:sub(col, col) == "X" then
        local tx, ty = x + (col - 3) * cell, y + (row - 4) * cell
        for k = 0, 1 do
          local p = {x = x, y = y, vx = 0, vy = 0, life = 3.6, max = 3.6, c = k == 0 and {1, 0.95, 0.85} or ({RED, WHITE, {0.4, 0.55, 1}})[(col + row) % 3 + 1],
                     size = k == 0 and 9 or 18, g = 0, tx = tx + (R:random() - 0.5) * 3, ty = ty + (R:random() - 0.5) * 3}
          S.glow[#S.glow + 1] = p
        end
      end
    end
  end
  spark(x, y, 0, 0, 0.3, {1, 1, 1}, 70, 0, true)
  C.sfx("pop")
  S.later[#S.later + 1] = {S.t + 0.3, "crackle"}
end

local function rocket(x, ty, big)
  S.rockets[#S.rockets + 1] = {x = x, y = GROUND - 10, ty = ty, vx = (R:random() - 0.5) * 40, big = big}
end

local function explode(x, y, c, n)
  for i = 1, n or 14 do
    local a = R:random() * 2 * pi
    local v = 60 + R:random() * 220
    spark(x, y, cos(a) * v, sin(a) * v - 60, 0.5 + R:random() * 0.7, c, 4, 380)
  end
  spark(x, y, 0, 0, 0.3, {1, 0.8, 0.4}, 50, 0, true)
  if S.t - (S.last_boom or -1) > 0.12 then S.last_boom = S.t C.sfx("boom") end
end

-- ------------------------------------------------------------------ the invaders
local ROW_KIND = {"squid", "crab", "crab", "octo", "octo"}
local ROW_COLOUR = {{1, 0.35, 0.85}, {0.4, 1, 0.5}, {0.4, 1, 0.5}, {0.35, 0.9, 1}, {0.35, 0.9, 1}}
local COLS, ROWS, CW, RH = 8, 5, 62, 44
local function invader_pos(r, c)
  return S.fx + (c - 1) * CW + CW / 2, S.fy + (r - 1) * RH
end
local function alive_count()
  local n = 0
  for r = 1, ROWS do for c = 1, COLS do if S.inv[r][c].alive then n = n + 1 end end end
  return n
end
local function kill(r, c, how)
  local e = S.inv[r][c]
  if not e.alive then return end
  e.alive = false
  local x, y = invader_pos(r, c)
  explode(x, y, ROW_COLOUR[r])
  S.score = S.score + (how == "eagle" and 200 or how == "jet" and 150 or 100)
  S.pops[#S.pops + 1] = {x = x, y = y, t = 0, s = "+" .. (how == "eagle" and 200 or how == "jet" and 150 or 100)}
end

-- ------------------------------------------------------------------ the show
function F.load(ctx)
  C = ctx
  W, H = ctx.W, ctx.H
end

-- Its pictures exist only while it plays: Home has ~35 MB on this cabinet, GPU memory included (2026-11-01:
-- the show on top of the menu's pictures ran the OOM killer).
local made = false
function F.stop()
  S = nil
  if not made then return end
  made = false
  for _, o in ipairs({dogb, atlas, pix, dot, glowb, smokeb, flagcv, mesh, vdata, cloud_img, dog_img, fence_img, hat_img,
                      mini_img, sky_mesh, lawn_mesh}) do
    if o then o:release() end
  end
  atlas, pix, dot, glowb, smokeb, flagcv, mesh, vdata = nil, nil, nil, nil, nil, nil, nil, nil
  cloud_img, dog_img, fence_img, hat_img, mini_img, sky_mesh, lawn_mesh = nil, nil, nil, nil, nil, nil, nil
  Q = {}
  for _, rows in pairs(SPR) do rows.x = nil end
end

local LABELS = {}
function F.start(seed, at)
  if not made then make_pictures() made = true end
  R = love.math.newRandomGenerator(seed or os.time())
  S = {t = 0, prev = -1, wind = 0.8, flag_yoff = 0, light = {1, 1, 1}, glow = {}, debris = {}, rockets = {},
       later = {}, pops = {}, holes = {}, taped = 0, score = 1776, fx = 120, fy = -260, dir = 1, step_t = 0,
       frame = 1, bullets = {}, shots = {}, fired_t = 0, cannon_x = W / 2, cannon_cool = 0, eagle = {mode = "away"},
       jets = {}, trail = {}, smoke = {}, fallen = {}, parade = {}, dogs = {}, confetti = {}, saucer = nil, pac = nil,
       labels = {}}
  S.inv = {}
  for r = 1, ROWS do
    S.inv[r] = {}
    for c = 1, COLS do S.inv[r][c] = {alive = true, kind = ROW_KIND[r]} end
  end
  paint_flag()
  -- the labels this show uses, painted a few a frame (a canvas switch mid-frame is costly on the Mali)
  for _, cp in ipairs(CAPTIONS) do S.labels[#S.labels + 1] = {cp[3], cp[4], cp[5]} end
  for _, l in ipairs({{"PARTYCADE", 64, 0xff4fd8}, {"PRESENTS", 30, 0x6ef0c8}, {"THE FREEDOM SHOW", 58, 0xffffff},
                      {"MISSION ACCOMPLISHED", 46, 0xffd23f}, {"U! S! A!", 96, 0xff3344}}) do
    S.labels[#S.labels + 1] = l
  end
  if at and at > 0 then
    -- Starting partway (a segment from the SHOWS section): the story so far, set up.
    S.t = at
    S.prev = at - 0.001
    if at > 20 then S.eagle = {mode = "perched"} end
    if at > 160 then S.fy = 80 end
    if at > 175 then
      -- the battle under way: holes in the flag, part of the fleet gone
      local holes = at >= 330 and 14 or math.min(14, math.floor((at - 175) / 8))
      for _ = 1, holes do
        local h = {u = 0.12 + R:random() * 0.85, v = 0.08 + R:random() * 0.84, r = 9 + R:random() * 8}
        S.holes[#S.holes + 1] = h
        burn_hole(h.u, h.v, h.r)
      end
      local kills = at >= 326 and 40 or math.min(23, math.floor((at - 175) / 4.5))
      local n = 0
      for r = ROWS, 1, -1 do
        for c = 1, COLS do
          if n < kills and (at >= 326 or R:random() < 0.6) then S.inv[r][c].alive = false n = n + 1 end
        end
      end
      S.score = 1776 + kills * 150
    end
    if at >= 360 then
      for _, h in ipairs(S.holes) do tape_hole(h.u, h.v, h.r) end
      S.taped = #S.holes
    end
  end
end

-- The segments for the SHOWS section: {start, title}; THUMB: the one whose picture stands for the whole show.
F.THUMB = 3
F.SEGMENTS = {{6, "MORNING IN AMERICA"}, {130, "RED ALERT"}, {170, "BATTLE OF THE BACKYARD"},
              {276, "THE FREEDOM PELLET"}, {296, "THE MOTHERSHIP"}, {330, "MISSION ACCOMPLISHED"},
              {430, "U-S-A FIREWORKS"}, {450, "SUNSET"}}

function F.act()
  local a = "open"
  for _, e in ipairs(ACTS) do if S.t >= e[1] then a = e[2] end end
  return a
end

function F.music()
  return MUSIC[F.act()]
end

-- true once, when the show's time passes T this frame
local function at(T) return S.prev < T and S.t >= T end

local function sky_at(t)
  for i = 1, #SKY - 1 do
    local a, b = SKY[i], SKY[i + 1]
    if t >= a[1] and t < b[1] then
      local k = ease((t - a[1]) / (b[1] - a[1]))
      local function mix(p, q) return {lerp(p[1], q[1], k), lerp(p[2], q[2], k), lerp(p[3], q[3], k)} end
      return mix(a[2], b[2]), mix(a[3], b[3]), lerp(a[4], b[4], k)
    end
  end
  local l = SKY[#SKY]
  return l[2], l[3], l[4]
end

local function eagle_fly(path, dur, after, kill_on)
  S.eagle = {mode = "flying", path = path, t0 = S.t, dur = dur, after = after, kill = kill_on}
end
local function bez(p, k)
  -- a cubic through four points {x, y}
  local u = 1 - k
  local x = u * u * u * p[1][1] + 3 * u * u * k * p[2][1] + 3 * u * k * k * p[3][1] + k * k * k * p[4][1]
  local y = u * u * u * p[1][2] + 3 * u * u * k * p[2][2] + 3 * u * k * k * p[3][2] + k * k * k * p[4][2]
  return x, y
end
local PERCH_X, PERCH_Y = POLE_X, POLE_TOP - 46

local function update_formation(dt, act)
  local beat = act == "alert" and 60 / 132 or 60 / 156
  if act == "alert" then
    -- descending into place
    S.fy = lerp(-260, 80, ease((S.t - 136) / 26))
  end
  local n = alive_count()
  local interval = beat * (act == "battle" and (0.35 + 0.65 * n / 40) or 1)
  S.step_t = S.step_t + dt
  if S.step_t >= interval then
    S.step_t = S.step_t - interval
    S.frame = 3 - S.frame
    S.fx = S.fx + S.dir * 12
    local w = COLS * CW
    if S.fx + w > W - 20 or S.fx < 20 then S.dir = -S.dir S.fx = S.fx + S.dir * 12 end
  end
  if act ~= "battle" or S.t > 326 then return end
  -- they shoot at the flag
  S.fired_t = S.fired_t - dt
  if S.fired_t <= 0 and n > 0 and S.t < 322 then
    S.fired_t = 0.7 + R:random() * 0.7
    local cols = {}
    for c = 1, COLS do for r = ROWS, 1, -1 do if S.inv[r][c].alive then cols[#cols + 1] = {r, c} break end end end
    local pick = cols[R:random(1, #cols)]
    local x, y = invader_pos(pick[1], pick[2])
    local u, v = 0.12 + R:random() * 0.85, 0.08 + R:random() * 0.84
    local tx, ty = flag_point(u, v)
    local d = sqrt((tx - x) ^ 2 + (ty - y) ^ 2)
    S.bullets[#S.bullets + 1] = {x = x, y = y + 16, tx = tx, ty = ty, u = u, v = v, t = 0, dur = d / 420, sx = x, sy = y + 16}
    C.sfx("zap", 0.7)
  end
end

local function update_battle(dt)
  local t = S.t
  -- the cannon: to the column with the lowest invader, fire when under it
  if t > 176 and t < 326 then
    local best, bx = -1, nil
    for c = 1, COLS do
      for r = ROWS, 1, -1 do
        if S.inv[r][c].alive then
          if r > best or (r == best and R:random() < 0.3) then best = r bx = select(1, invader_pos(r, c)) end
          break
        end
      end
    end
    if S.saucer and S.saucer.y > 0 and t > 306 then bx = S.saucer.x end
    if bx then
      local d = bx - S.cannon_x
      S.cannon_x = S.cannon_x + clamp(d, -280 * dt, 280 * dt)
      S.cannon_cool = S.cannon_cool - dt
      if abs(d) < 10 and S.cannon_cool <= 0 then
        -- (paced: a third of the fleet is the cannon's; the eagle, the jets and Pac-Man want theirs)
        S.cannon_cool = t > 300 and 0.5 or (4.5 + R:random() * 2.5)
        local miss = t < 300 and R:random() < 0.5 and (R:random() < 0.5 and -34 or 34) or 0
        S.shots[#S.shots + 1] = {x = S.cannon_x + miss, y = GROUND - 50}
        C.sfx("pew", 0.8)
      end
    end
  end
  for i = #S.shots, 1, -1 do
    local s = S.shots[i]
    s.y = s.y - 900 * dt
    local hit = false
    for r = ROWS, 1, -1 do
      for c = 1, COLS do
        local e = S.inv[r][c]
        if e.alive then
          local x, y = invader_pos(r, c)
          if abs(s.x - x) < 22 and abs(s.y - y) < 18 then kill(r, c, "cannon") hit = true break end
        end
      end
      if hit then break end
    end
    local sc = S.saucer
    if not hit and sc and abs(s.x - sc.x) < 42 and abs(s.y - sc.y) < 20 then
      hit = true
      sc.hp = sc.hp - 1
      sc.flash = 0.15
      explode(s.x, s.y, {1, 0.4, 0.4}, 6)
    end
    if hit or s.y < -20 then table.remove(S.shots, i) end
  end
  -- their bullets: to the flag, a hole where they land
  for i = #S.bullets, 1, -1 do
    local b = S.bullets[i]
    b.t = b.t + dt
    local k = b.t / b.dur
    b.x, b.y = lerp(b.sx, b.tx, k), lerp(b.sy, b.ty, k)
    if k >= 1 then
      if #S.holes < 16 then
        local r = 9 + R:random() * 8
        S.holes[#S.holes + 1] = {u = b.u, v = b.v, r = r}
        burn_hole(b.u, b.v, r)
      end
      for _ = 1, 8 do spark(b.x, b.y, (R:random() - 0.5) * 200, -R:random() * 150, 0.4, {1, 0.6, 0.2}, 3, 300, true) end
      table.remove(S.bullets, i)
    end
  end
  -- the eagle's dives (through the fullest column)
  local function dive()
    local bestc, most = 1, -1
    for c = 1, COLS do
      local n = 0
      for r = 1, ROWS do if S.inv[r][c].alive then n = n + 1 end end
      if n > most then most, bestc = n, c end
    end
    local x = select(1, invader_pos(1, bestc))
    C.sfx("screech")
    eagle_fly({{PERCH_X, PERCH_Y}, {x - 40, 760}, {x + 40, -260}, {x + 10, S.fy - 40}}, 2.2,
              {{x + 10, S.fy - 40}, {W - 60, 60}, {POLE_X + 260, 120}, {PERCH_X, PERCH_Y}}, true)
  end
  if at(204) or at(266) then dive() end
  -- the jets strafe row 3
  if at(232) then
    C.sfx("jet")
    for i = 1, 3 do
      S.jets[#S.jets + 1] = {x = W + 80 + (i == 2 and 0 or 70), y = S.fy + 2 * RH + (i - 2) * 46, vx = -520, dir = -1,
                             colour = ({RED, WHITE, BLUE})[i], strafe = i == 2}
    end
  end
  -- the FREEDOM PELLET: Pac-Man comes onto the lawn, eats it, the bottom two rows turn blue and drop
  if at(280) then S.pac = {x = -60, y = 900, dir = 1, state = "walk"} end
  if at(288) then
    C.log(string.format("freedom: pellet with %d invaders left", alive_count()))
    C.sfx("power")
    for r = 2, 5 do
      for c = 1, COLS do
        local e = S.inv[r][c]
        if e.alive then
          e.alive = false
          local x, y = invader_pos(r, c)
          S.fallen[#S.fallen + 1] = {x = x, y = y, vy = -60 - R:random() * 60, kind = e.kind, t = 0}
        end
      end
    end
  end
  -- the mothership
  if at(300) then S.saucer = {x = -60, y = 76, hp = 6, flash = 0} C.sfx("saucer") end
  local sc = S.saucer
  if sc then
    sc.x = sc.x + 110 * dt
    if sc.x > W + 60 then sc.x = -60 end
    sc.y = 76 + sin(S.t * 2) * 10
    sc.flash = max(0, sc.flash - dt)
    if sc.hp <= 0 or at(322) then
      for i = 1, 5 do S.later[#S.later + 1] = {S.t + i * 0.12, "boom"} end
      for i = 1, 6 do explode(sc.x + (R:random() - 0.5) * 60, sc.y + (R:random() - 0.5) * 30, {1, 0.3, 0.3}, 20) end
      for i = 1, 3 do firework(sc.x + (i - 2) * 50, sc.y + 20, true) end
      S.saucer = nil
      S.chain = S.t
      S.score = S.score + 1000
      S.pops[#S.pops + 1] = {x = sc.x, y = sc.y, t = 0, s = "+1000"}
    end
  end
  -- after the mothership: the rest go up one by one
  if S.chain and S.t - S.chain > 0.1 then
    S.chain = S.t
    for r = ROWS, 1, -1 do
      local done = false
      for c = 1, COLS do if S.inv[r][c].alive then kill(r, c, "cannon") done = true break end end
      if done then break end
    end
  end
  if at(328) then
    for r = 1, ROWS do for c = 1, COLS do if S.inv[r][c].alive then kill(r, c, "cannon") end end end
  end
end

local function start_parade(y)
  S.parade = {x = -80, y = y}
end

function F.update(dt)
  if not S then return false end
  -- the labels, two a frame
  for _ = 1, 2 do
    local l = table.remove(S.labels)
    if l then C.neon_img(l[1], l[2], l[3], 1) end
  end
  S.prev = S.t
  S.t = S.t + dt
  local t = S.t
  local act = F.act()
  -- wind: by act, with gusts
  local base = ({open = 0.6, morning = 0.75, alert = 1, battle = 0.95, victory = 0.85, sunset = 0.5})[act]
  S.wind = clamp(base + 0.15 * sin(t * 0.37) * sin(t * 0.11 + 1), 0.2, 1)
  -- the light on the flag
  local top, hor, dark = sky_at(t)
  S.light = {lerp(1, hor[1] * 0.5 + 0.55, 0.6), lerp(1, hor[2] * 0.5 + 0.5, 0.6), lerp(1, hor[3] * 0.5 + 0.55, 0.6)}
  if act == "alert" or act == "battle" then S.light = {1, 0.75, 0.75} end
  -- the flag goes up the pole (6-20 s)
  S.flag_yoff = lerp(GROUND - FLAG_Y - FH - 20, 0, ease((t - 7) / 13))
  if t < 7 then S.flag_yoff = GROUND end

  -- I: morning
  if at(24) then
    eagle_fly({{W + 80, 120}, {W - 150, 40}, {POLE_X + 260, 60}, {PERCH_X + 70, PERCH_Y - 60}}, 5,
              {{PERCH_X + 70, PERCH_Y - 60}, {PERCH_X + 40, PERCH_Y - 40}, {PERCH_X + 10, PERCH_Y - 10}, {PERCH_X, PERCH_Y}})
    C.sfx("screech")
  end
  if at(40) then start_parade(906) end
  if at(76) then start_parade(906) end
  if at(95) then
    C.sfx("jet")
    for i = 1, 3 do
      S.jets[#S.jets + 1] = {x = -100 - (i == 2 and 0 or 60), y = 180 + (i - 2) * 40, vx = 430, dir = 1, colour = ({RED, WHITE, BLUE})[i]}
    end
  end
  for _, T in ipairs({58, 62, 88, 118, 122}) do if at(T) then rocket(200 + R:random() * 400, 120 + R:random() * 140) end end

  -- II: red alert
  if at(130) or at(134) or at(138) then C.sfx("klaxon") end
  if at(150) then C.sfx("screech") S.eagle.look_fast = true end
  if act == "alert" or (act == "battle" and t < 330) then update_formation(dt, act) end
  if act == "battle" then update_battle(dt) end

  -- IV: victory
  if at(331) then C.sfx("cheer") end
  if t > 334 and t < 360 and S.taped < #S.holes and t - (S.tape_t or 0) > 1.1 then
    S.tape_t = t
    S.taped = S.taped + 1
    local h = S.holes[S.taped]
    tape_hole(h.u, h.v, h.r)
    C.sfx("tape")
  end
  if (act == "victory" and t > 338 and t < 440) then
    S.fw_t = (S.fw_t or 0) - dt
    if S.fw_t <= 0 then
      S.fw_t = 0.35 + R:random() * 0.6
      rocket(80 + R:random() * (W - 160), 80 + R:random() * 260, R:random() < 0.3)
    end
  end
  if act == "victory" and t < 362 and #S.confetti < 320 then
    for _ = 1, 2 do
      local c = ({RED, WHITE, BLUE, GOLD})[R:random(1, 4)]
      S.confetti[#S.confetti + 1] = {x = R:random() * W, y = -10, vx = (R:random() - 0.5) * 60, vy = 80 + R:random() * 90,
                                     rot = R:random() * 6, vr = (R:random() - 0.5) * 10, c = c, w = 6 + R:random() * 6}
    end
  end
  if t > 358 and t < 384 and R:random() < dt * 5 then
    S.dogs[#S.dogs + 1] = {x = 40 + R:random() * (W - 80), y = -40, vy = 120 + R:random() * 120, rot = R:random() * 6,
                           vr = (R:random() - 0.5) * 4}
  end
  for _, T in ipairs(CHANTS) do if at(T) then C.sfx("usa") C.sfx("cheer") end end
  if at(390) then S.tear = 0 end
  if at(433) then
    for i, ch in ipairs({"U", "S", "A"}) do
      S.rockets[#S.rockets + 1] = {x = 384 + (i - 2) * 190, y = GROUND - 10, ty = 230, vx = 0, letter = ch}
    end
    S.later[#S.later + 1] = {435.5, "cheer"}
  end
  if at(406) then start_parade(906) end

  -- V: sunset
  if act == "sunset" and t < 552 then
    S.fw_t = (S.fw_t or 0) - dt
    if S.fw_t <= 0 then S.fw_t = 5 + R:random() * 5 rocket(120 + R:random() * (W - 240), 120 + R:random() * 160) end
  end

  -- rockets, sparks, debris
  for i = #S.rockets, 1, -1 do
    local r = S.rockets[i]
    r.y = r.y - 520 * dt
    r.x = r.x + r.vx * dt
    spark(r.x, r.y + 6, (R:random() - 0.5) * 20, 60, 0.35, {1, 0.8, 0.5}, 3, 0, true)
    if r.y <= r.ty then
      if r.letter then letter_burst(r.x, r.y, r.letter) else firework(r.x, r.y, r.big) end
      table.remove(S.rockets, i)
    end
  end
  for _, list in ipairs({S.glow, S.debris}) do
    local j = 1
    for i = 1, #list do
      local p = list[i]
      p.life = p.life - dt
      if p.life > 0 and p.tx then
        local k = min(1, dt * 5)
        p.x, p.y = p.x + (p.tx - p.x) * k, p.y + (p.ty - p.y) * k + (p.max - p.life > 2.4 and 30 * dt or 0)
        list[j] = p
        j = j + 1
      elseif p.life > 0 then
        p.vy = p.vy + p.g * dt
        p.vx = p.vx * (1 - 0.8 * dt)
        p.x, p.y = p.x + p.vx * dt, p.y + p.vy * dt
        list[j] = p
        j = j + 1
      end
    end
    for i = j, #list do list[i] = nil end
  end
  for i = #S.later, 1, -1 do
    local l = S.later[i]
    if t >= l[1] then C.sfx(l[2]) table.remove(S.later, i) end
  end
  for i = #S.pops, 1, -1 do
    local p = S.pops[i]
    p.t = p.t + dt
    if p.t > 1 then table.remove(S.pops, i) end
  end
  -- jets and their smoke
  for i = #S.jets, 1, -1 do
    local j = S.jets[i]
    j.x = j.x + j.vx * dt
    j.puff = (j.puff or 0) + dt
    if j.puff > 0.03 then
      j.puff = 0
      S.trail[#S.trail + 1] = {x = j.x - j.dir * 36, y = j.y + 2, life = 2.2, c = j.colour}
    end
    if j.strafe then
      for r = 1, ROWS do
        for c = 1, COLS do
          if S.inv[r][c].alive then
            local x, y = invader_pos(r, c)
            if abs(x - j.x) < 30 and abs(y - j.y) < 16 then kill(r, c, "jet") end
          end
        end
      end
    end
    if (j.dir > 0 and j.x > W + 160) or (j.dir < 0 and j.x < -160) then table.remove(S.jets, i) end
  end
  if grill_on(t) then
    S.grill_puff = (S.grill_puff or 0) + dt
    if S.grill_puff > 0.18 then
      S.grill_puff = 0
      S.smoke[#S.smoke + 1] = {x = GRILL_X + (R:random() - 0.5) * 30, y = GRILL_Y - 34, life = 2.2,
                               c = {0.8, 0.8, 0.82}, rise = 40 + R:random() * 20, drift = 10 + R:random() * 10}
    end
  end
  for i = #S.smoke, 1, -1 do
    local p = S.smoke[i]
    p.life = p.life - dt
    p.y, p.x = p.y - p.rise * dt, p.x + p.drift * dt
    if p.life <= 0 then table.remove(S.smoke, i) end
  end
  for i = #S.trail, 1, -1 do
    local p = S.trail[i]
    p.life = p.life - dt
    p.y = p.y + 6 * dt
    if p.life <= 0 then table.remove(S.trail, i) end
  end
  -- the eagle
  local e = S.eagle
  if e.mode == "flying" then
    local k = (t - e.t0) / e.dur
    if k >= 1 then
      if e.after then eagle_fly(e.after, 2.6, nil, false)
      else S.eagle = {mode = "perched"} end
    else
      local x, y = bez(e.path, ease(k) * 0.3 + k * 0.7)
      e.dir = (e.x and x < e.x) and -1 or 1
      e.x, e.y = x, y
      if e.kill then
        for r = 1, ROWS do
          for c = 1, COLS do
            if S.inv[r][c].alive then
              local ix, iy = invader_pos(r, c)
              if abs(ix - x) < 24 and abs(iy - y) < 26 then kill(r, c, "eagle") end
            end
          end
        end
      end
    end
  end
  if S.tear then S.tear = S.tear + dt * 0.12 if S.tear > 1 then S.tear = nil end end
  -- Pac-Man and the fallen invaders
  for _, f in ipairs(S.fallen) do
    f.t = f.t + dt
    if not f.eaten then
      f.vy = f.vy + 500 * dt
      f.y = min(908, f.y + f.vy * dt)
    end
  end
  local p = S.pac
  if p then
    p.x = p.x + p.dir * (t > 288 and 200 or 49) * dt
    for _, f in ipairs(S.fallen) do
      if not f.eaten and f.y >= 900 and abs(f.x - p.x) < 20 then
        f.eaten = true
        S.score = S.score + 200
        S.pops[#S.pops + 1] = {x = f.x, y = 860, t = 0, s = "+200"}
        C.sfx("pew", 0.5)
      end
    end
    if p.x > W + 80 then
      if t < 300 then p.dir = -1 p.x = W + 60 else S.pac = nil end
    elseif p.x < -80 and p.dir < 0 then p.dir = 1 end
  end
  -- the parade
  if S.parade.x then
    S.parade.x = S.parade.x + 70 * dt
    if S.parade.x > W + 380 then S.parade = {} end
  end
  -- confetti, hot dogs
  for i = #S.confetti, 1, -1 do
    local c = S.confetti[i]
    c.x, c.y, c.rot = c.x + c.vx * dt + sin(t * 3 + i) * 20 * dt, c.y + c.vy * dt, c.rot + c.vr * dt
    if c.y > GROUND + 60 then table.remove(S.confetti, i) end
  end
  for i = #S.dogs, 1, -1 do
    local d = S.dogs[i]
    d.y, d.rot = d.y + d.vy * dt, d.rot + d.vr * dt
    if d.y > GROUND + 80 then table.remove(S.dogs, i) end
  end
  return t >= LEN
end

-- ------------------------------------------------------------------ drawing
local function draw_sky()
  local top, hor, dark = sky_at(S.t)
  sky_mesh:setVertex(1, 0, 0, 0, 0, top[1], top[2], top[3], 1)
  sky_mesh:setVertex(2, W, 0, 1, 0, top[1], top[2], top[3], 1)
  sky_mesh:setVertex(3, W, GROUND, 1, 1, hor[1], hor[2], hor[3], 1)
  sky_mesh:setVertex(4, 0, GROUND, 0, 1, hor[1], hor[2], hor[3], 1)
  lg.setColor(1, 1, 1, 1)
  lg.draw(sky_mesh)
  -- stars, when dark
  if dark > 0.2 then
    local pts = {}
    for i, s in ipairs(stars_pts) do
      local tw = 0.6 + 0.4 * sin(S.t * (1 + i % 5) + i)
      pts[#pts + 1] = {s[1], s[2], 1, 1, 1, s[3] * tw * (dark - 0.2)}
    end
    lg.setPointSize(2)
    lg.points(pts)
  end
  return dark
end

local function draw_sun(dark)
  local t = S.t
  if t > 6 and t < 140 then
    -- the morning sun: up out of the horizon, then high on the right
    local k = ease((t - 6) / 30)
    local x, y = lerp(560, 640, k), lerp(GROUND - 20, 110, k)
    local a = 1 - ease((t - 128) / 10)
    C.fx.glow(x, y, 220, 220, 1, 0.85, 0.5, 0.45 * a)
    lg.setColor(1, 0.95, 0.75, a)
    lg.circle("fill", x, y, 46, 48)
  elseif t > 450 then
    local k = ease((t - 450) / 110)
    local x, y = 600, lerp(420, GROUND + 60, k)
    C.fx.glow(x, y, 300, 220, 1, 0.5, 0.25, 0.5 * (1 - k * 0.6))
    lg.setColor(1, 0.65, 0.35, 1)
    lg.circle("fill", x, y, 70, 48)
  elseif dark > 0.8 then
    -- the moon at night
    lg.setColor(0.95, 0.93, 0.8, 0.9)
    lg.circle("fill", 650, 120, 30, 40)
  end
end

local function draw_clouds()
  local t = S.t
  local a = (t > 14 and t < 140) and min(1, (t - 14) / 8) * (1 - ease((t - 128) / 10)) or 0
  if t > 455 then a = min(1, (t - 455) / 10) * 0.7 end
  if a <= 0 then return end
  local tint = t > 400 and {1, 0.75, 0.6} or {1, 1, 1}
  for i = 0, 3 do
    local x = ((i * 260 + t * (10 + i * 4)) % (W + 300)) - 220
    local y = 70 + i * 52 + (i % 2) * 30
    lg.setColor(tint[1], tint[2], tint[3], a * (0.75 - i * 0.1))
    lg.draw(cloud_img, x, y, 0, 1 - i * 0.1, 1 - i * 0.1)
  end
end

local function draw_searchlights()
  local t = S.t
  if t < 134 or t > 340 then return end
  local a = min(1, (t - 134) / 4) * (1 - ease((t - 330) / 10))
  lg.setBlendMode("add")
  for i, bx in ipairs({190, 590}) do
    local ang = -pi / 2 + sin(t * (0.5 + i * 0.13) + i * 2) * 0.55
    local len = 1000
    local x2, y2 = bx + cos(ang - 0.07) * len, GROUND + sin(ang - 0.07) * len
    local x3, y3 = bx + cos(ang + 0.07) * len, GROUND + sin(ang + 0.07) * len
    lg.setColor(1, 0.95, 0.8, 0.10 * a)
    lg.polygon("fill", bx, GROUND, x2, y2, x3, y3)
    lg.setColor(1, 0.95, 0.8, 0.07 * a)
    lg.polygon("fill", bx, GROUND, bx + cos(ang - 0.03) * len, GROUND + sin(ang - 0.03) * len,
               bx + cos(ang + 0.03) * len, GROUND + sin(ang + 0.03) * len)
  end
  lg.setBlendMode("alpha")
end

local function draw_glow()
  glowb:clear()
  for _, p in ipairs(S.glow) do
    local k = p.life / p.max
    glowb:setColor(p.c[1], p.c[2], p.c[3], min(1, k * 1.6))
    local s = p.size / 8 * (0.6 + 0.4 * k)
    glowb:add(p.x, p.y, 0, s, s, 8, 8)
  end
  lg.setBlendMode("add")
  lg.setColor(1, 1, 1, 1)
  lg.draw(glowb)
  lg.setBlendMode("alpha")
end

local function draw_puffs(list)
  smokeb:clear()
  for _, p in ipairs(list) do
    local k = p.life / 2.2
    smokeb:setColor(p.c[1], p.c[2], p.c[3], k * 0.45)
    local sc = (6 + (1 - k) * 16) / 8
    smokeb:add(p.x, p.y, 0, sc, sc, 8, 8)
  end
  lg.setColor(1, 1, 1, 1)
  lg.draw(smokeb)
end
local function draw_trails()
  smokeb:clear()
  for _, p in ipairs(S.trail) do
    local k = p.life / 2.2
    smokeb:setColor(p.c[1], p.c[2], p.c[3], k * 0.6)
    local sc = (8 + (1 - k) * 18) / 8
    smokeb:add(p.x, p.y, 0, sc, sc, 8, 8)
  end
  lg.setColor(1, 1, 1, 1)
  lg.draw(smokeb)
  for _, j in ipairs(S.jets) do draw_jet(j.x, j.y, 1.1, j.dir) end
end

local function draw_pix()
  pix:clear()
  local act = F.act()
  if act == "alert" or act == "battle" then
    local f = S.frame
    for r = 1, ROWS do
      local c0 = ROW_COLOUR[r]
      for c = 1, COLS do
        local e = S.inv[r][c]
        if e.alive then
          local x, y = invader_pos(r, c)
          local q = Q[e.kind .. f]
          local w = SPR[e.kind .. f].w
          pix:setColor(c0[1], c0[2], c0[3], 1)
          pix:add(q, x, y, 0, 4, 4, w / 2, 4)
        end
      end
    end
  end
  if S.saucer then
    local sc = S.saucer
    if sc.flash > 0 then pix:setColor(1, 1, 1, 1) else pix:setColor(1, 0.25, 0.3, 1) end
    pix:add(Q.saucer, sc.x, sc.y, 0, 5, 5, 8, 3.5)
  end
  pix:setColor(1, 1, 1, 1)
  for _, s in ipairs(S.shots) do pix:add(Q.px, s.x - 2, s.y, 0, 4, 18) end
  for _, b in ipairs(S.bullets) do
    pix:setColor(0.6, 1, 0.4, 1)
    local zig = floor(b.t * 20) % 2 == 0 and 3 or -3
    pix:add(Q.px, b.x + zig, b.y, 0, 3, 12)
  end
  for _, p in ipairs(S.debris) do
    pix:setColor(p.c[1], p.c[2], p.c[3], min(1, p.life / p.max * 2))
    pix:add(Q.px, p.x, p.y, 0, p.size, p.size)
  end
  for _, c in ipairs(S.confetti) do
    pix:setColor(c.c[1], c.c[2], c.c[3], 1)
    pix:add(Q.px, c.x, c.y, c.rot, c.w, c.w * 0.5 * abs(sin(c.rot * 2)) + 1, 0.5, 0.5)
  end
  lg.setColor(1, 1, 1, 1)
  lg.draw(pix)
end

local function draw_flag_and_pole()
  -- the pole
  lg.setColor(0.78, 0.78, 0.82, 1)
  lg.rectangle("fill", POLE_X - 5, POLE_TOP, 10, GROUND - POLE_TOP)
  lg.setColor(1, 1, 1, 0.35)
  lg.rectangle("fill", POLE_X - 3, POLE_TOP, 2, GROUND - POLE_TOP)
  lg.setColor(GOLD[1], GOLD[2], GOLD[3], 1)
  lg.circle("fill", POLE_X, POLE_TOP - 6, 11, 20)
  lg.setColor(1, 1, 1, 0.6)
  lg.circle("fill", POLE_X - 3, POLE_TOP - 9, 3.5, 10)
  -- the cloth
  if S.t >= 7 then
    update_cloth()
    lg.setColor(1, 1, 1, 1)
    lg.draw(mesh)
  end
  -- the eagle
  local e = S.eagle
  if e.mode == "perched" then
    local look = sin(S.t * (e.look_fast and 1.6 or 0.45)) * 1.2
    if F.act() == "victory" or F.act() == "sunset" then look = 0.4 + sin(S.t * 0.3) * 0.2 end
    draw_eagle_perched(PERCH_X, PERCH_Y, 1.25, look, S.tear)
  elseif e.mode == "flying" and e.x then
    draw_eagle_flying(e.x, e.y, 1.3, S.t * 2.2, e.dir or 1)
  end
end

local function draw_ground(dark)
  local l = 1 - dark * 0.6
  local t = S.t
  if t > 450 then l = l * 0.85 end
  lg.setColor(l, l * (F.act() == "alert" and 0.8 or 1), l, 1)
  lg.draw(lawn_mesh)
  lg.setColor(l * 0.95, l * 0.95, l, 1)
  lg.draw(fence_img, 0, GROUND - 52)
end

local GHOST_COLOURS = {{1, 0.18, 0.2}, {1, 0.55, 0.85}, {0.25, 0.95, 1}, {1, 0.65, 0.2}}
-- The barbecue (morning, and again for the victory): Clyde at a kettle grill, flipping burgers.
local function draw_grill(t)
  local x, y = GRILL_X, GRILL_Y
  C.fx.ghost(x + 30, y - 46, 22, {1, 0.65, 0.2}, -1, t, false, false, 1)
  -- the spatula: up and down with each flip
  local flip = (t * 0.8) % 1
  local lift = flip < 0.3 and sin(flip / 0.3 * pi) * 22 or 0
  lg.setColor(0.6, 0.6, 0.65, 1)
  lg.setLineWidth(3)
  lg.line(x + 14, y - 40, x - 10, y - 28 - lift)
  lg.rectangle("fill", x - 22, y - 32 - lift, 14, 6)
  -- the grill: legs, kettle, grate
  lg.setColor(0.12, 0.12, 0.14, 1)
  lg.line(x - 30, y, x - 40, y + 26)
  lg.line(x + 30, y, x + 40, y + 26)
  lg.line(x, y + 4, x, y + 26)
  lg.arc("fill", "pie", x, y - 22, 40, 0, pi, 20)
  lg.setColor(0.35, 0.35, 0.38, 1)
  lg.rectangle("fill", x - 42, y - 24, 84, 4)
  -- burgers, one in the air
  lg.setColor(0.45, 0.25, 0.12, 1)
  lg.ellipse("fill", x - 22, y - 28, 11, 4, 12)
  lg.ellipse("fill", x + 4, y - 28, 11, 4, 12)
  local by = y - 28 - (flip < 0.3 and sin(flip / 0.3 * pi) * 40 or 0)
  lg.ellipse("fill", x + 24, by, 11, flip < 0.3 and 2 + abs(cos(flip / 0.3 * pi)) * 3 or 4, 12)
end
local function draw_lawn_life()
  local t = S.t
  if grill_on(t) then draw_grill(t) end
  -- the parade: Pac-Man in the hat, the ghosts with little flags
  local p = S.parade
  if p.x then
    local bob = abs(sin(t * 6)) * 4
    C.fx.chomper(p.x, p.y - bob, 22, 1, t, 1)
    draw_hat(p.x, p.y - bob, 22, -0.15)
    for i, c in ipairs(GHOST_COLOURS) do
      local x = p.x - 70 - (i - 1) * 64
      local b = abs(sin(t * 6 + i)) * 4
      C.fx.ghost(x, p.y - b, 20, c, 1, t + i, false, false, 1)
      draw_mini_flag(x + 18, p.y - b + 4, t + i)
    end
  end
  -- the fallen, scared invaders
  for _, f in ipairs(S.fallen) do
    if not f.eaten then
      local blink = t > 300 and floor(t * 6) % 2 == 0
      if blink then lg.setColor(1, 1, 1, 1) else lg.setColor(0.25, 0.35, 1, 1) end
      lg.draw(atlas, Q[f.kind .. (floor(t * 4) % 2 + 1)], f.x, f.y + sin(t * 20 + f.x) * 1.5, 0, 3.5, 3.5,
              SPR[f.kind .. "1"].w / 2, 4)
    end
  end
  if S.pac then
    local pc = S.pac
    local r = t > 288 and 30 or 22
    C.fx.chomper(pc.x, pc.y - r + 22, r, pc.dir, t, 1)
    draw_hat(pc.x, pc.y - r + 22, r, pc.dir > 0 and -0.15 or 0.15)
  end
  -- the pellet, before it is eaten
  if t > 280 and t < 288 then
    local a = 0.6 + 0.4 * sin(t * 10)
    C.fx.glow(330, 900, 40, 40, 1, 0.85, 0.3, a * 0.6)
    lg.setColor(1, 0.9, 0.5, 1)
    lg.circle("fill", 330, 900, 12, 20)
  end
  -- the cannon
  if t > 172 and t < 336 then draw_cannon(S.cannon_x, GROUND + 6) end
end

local function draw_dogs()
  if #S.dogs == 0 then return end
  dogb:clear()
  for _, d in ipairs(S.dogs) do dogb:add(d.x, d.y, d.rot, 1, 1, 40, 18) end
  lg.setColor(1, 1, 1, 1)
  lg.draw(dogb)
end

local ticker_x = 0
local function draw_hud()
  local t = S.t
  local act = F.act()
  -- the opening titles
  if act == "open" then
    local a1 = clamp(t / 1, 0, 1) * (1 - ease((t - 2.6) / 0.6))
    if a1 > 0 then
      C.neon_draw("PARTYCADE", 0, 380, 64, 0xff4fd8, 1.4, "center", W, a1)
      C.neon_draw("PRESENTS", 0, 470, 30, 0x6ef0c8, 0.8, "center", W, a1)
    end
    local a2 = ease((t - 3) / 0.8)
    if a2 > 0 then
      local sc = 0.85 + 0.15 * ease((t - 3) / 1.2)
      C.neon_draw("THE FREEDOM SHOW", 0, 420, 58, 0xffffff, 1.2, "center", W, a2, sc)
      for i = -2, 2 do
        local c = (i % 2 == 0) and RED or BLUE
        lg.setColor(c[1], c[2], c[3], a2)
        draw_star(W / 2 + i * 70, 530, 18, sin(t * 2 + i) * 0.3)
      end
    end
    return
  end
  -- captions
  for _, cp in ipairs(CAPTIONS) do
    if t >= cp[1] and t < cp[2] then
      local k = min(1, (t - cp[1]) / 0.5, (cp[2] - t) / 0.5)
      local y = (act == "alert" or act == "battle" or (act == "victory" and t < 400)) and 650 or 150
      if act == "victory" and t >= 400 then y = 210 end
      if cp[3] == "RED ALERT" and floor(t * 4) % 2 == 0 then k = k * 0.3 end
      C.neon_draw(cp[3], 0, y, cp[4], cp[5], 1, "center", W, k)
    end
  end
  -- the score (battle and after)
  if t > 172 and t < 450 then
    lg.setFont(C.font(26))
    local s = string.format("USA  %d", S.score)
    lg.setColor(0, 0, 0, 0.5)
    lg.print(s, 22, 18)
    lg.print("ALIENS  0", W - 22 - C.font(26):getWidth("ALIENS  0") + 2, 18)
    lg.setColor(1, 1, 1, 1)
    lg.print(s, 20, 16)
    lg.setColor(0.5, 1, 0.55, 1)
    lg.print("ALIENS  0", W - 24 - C.font(26):getWidth("ALIENS  0"), 16)
    lg.setFont(C.font(22))
    for _, p in ipairs(S.pops) do
      lg.setColor(1, 1, 0.6, 1 - p.t)
      lg.print(p.s, p.x - 20, p.y - 30 - p.t * 40)
    end
  end
  -- the invaders talk
  for _, tn in ipairs(TAUNTS) do
    if t >= tn[1] and t < tn[2] then
      local who
      for c = 1, COLS do for r = ROWS, 1, -1 do if not who and S.inv[r][c].alive then who = {r, c} end end end
      if who then
        local ix, iy = invader_pos(who[1], who[2])
        local f = C.font(20)
        local w = f:getWidth(tn[3]) + 28
        local bx = clamp(ix - w / 2, 12, W - w - 12)
        local by = iy + 30
        local a = min(1, (t - tn[1]) * 4, (tn[2] - t) * 4)
        lg.setColor(1, 1, 1, 0.95 * a)
        lg.rectangle("fill", bx, by, w, 40, 12, 12, 8)
        lg.polygon("fill", ix - 8, by, ix + 8, by, ix, by - 12)
        lg.setFont(f)
        lg.setColor(0.1, 0.05, 0.2, a)
        lg.print(tn[3], bx + 14, by + 9)
      end
    end
  end
  -- the news desk (red alert): a field reporter, live
  if t > 140 and t < 169 then
    local a = min(1, (t - 140) * 2, (169 - t) * 2)
    local y = 862
    lg.setColor(0.05, 0.06, 0.22, 0.9 * a)
    lg.rectangle("fill", 14, y, W - 28, 92, 10, 10, 8)
    lg.setColor(0.12, 0.2, 0.5, a)
    lg.rectangle("fill", 22, y + 8, 100, 76, 6, 6, 8)
    C.fx.ghost(72, y + 50, 22, {1, 0.18, 0.2}, 1, t, false, false, a)
    lg.setColor(0.2, 0.2, 0.25, a)
    lg.rectangle("fill", 88, y + 50, 4, 26)
    lg.circle("fill", 90, y + 48, 6, 10)
    lg.setFont(C.font(22))
    lg.setColor(1, 0.85, 0.3, a)
    lg.print("BLINKY GHOSTWORTH  ·  LIVE FROM THE BACKYARD", 136, y + 14)
    lg.setFont(C.font(20))
    lg.setColor(1, 1, 1, a)
    local q = t < 154 and "\"I'M BEING TOLD THESE ARE NOT FIREWORKS.\"" or "\"FOR ONCE, I'M NOT THE ONE BEING CHASED.\""
    lg.print(q, 136, y + 48)
  end
  -- EAGLE CAM: the single tear, up close
  if t > 388 and t < 404 then
    local a = min(1, (t - 388) * 2, (404 - t) * 2)
    local bx, by, bw, bh = 470, 606, 278, 176
    lg.setColor(0, 0, 0, 0.7 * a)
    lg.rectangle("fill", bx - 6, by - 6, bw + 12, bh + 12, 10, 10, 8)
    lg.setColor(0.12, 0.14, 0.4, a)
    lg.rectangle("fill", bx, by, bw, bh)
    local hx, hy = bx + 110, by + 96
    lg.setColor(EAGLE_BROWN[1], EAGLE_BROWN[2], EAGLE_BROWN[3], a)
    lg.polygon("fill", bx + 14, by + bh, bx + 44, by + bh - 46, bx + 176, by + bh - 46, bx + 206, by + bh)
    lg.setColor(1, 1, 1, a)
    lg.circle("fill", hx, hy, 58, 40)
    lg.setColor(1, 0.78, 0.1, a)
    lg.polygon("fill", hx + 40, hy - 14, hx + 110, hy + 10, hx + 44, hy + 30)
    lg.setColor(0.85, 0.6, 0.05, a)
    lg.polygon("fill", hx + 86, hy + 2, hx + 110, hy + 10, hx + 90, hy + 26)
    lg.setColor(0.05, 0.05, 0.05, a)
    lg.circle("fill", hx + 20, hy - 14, 7, 12)
    lg.setColor(0.7, 0.7, 0.72, a)
    lg.setLineWidth(5)
    lg.line(hx - 4, hy - 34, hx + 34, hy - 22)
    if S.tear then
      local k = S.tear
      lg.setColor(0.55, 0.82, 1, a)
      local ty = hy - 4 + k * 70
      lg.circle("fill", hx + 18, ty, 7, 14)
      lg.polygon("fill", hx + 12, ty - 2, hx + 24, ty - 2, hx + 18, ty - 14)
      lg.setColor(1, 1, 1, 0.8 * a)
      lg.circle("fill", hx + 15, ty - 2, 2, 6)
    end
    lg.setColor(RED[1], RED[2], RED[3], a)
    lg.rectangle("fill", bx, by, 112, 26)
    lg.setFont(C.font(18))
    lg.setColor(1, 1, 1, a)
    lg.print("EAGLE CAM", bx + 10, by + 3)
    if floor(t * 2) % 2 == 0 then lg.setColor(1, 0.2, 0.2, a) lg.circle("fill", bx + bw - 44, by + 14, 6, 10) end
    lg.setColor(1, 1, 1, a)
    lg.print("REC", bx + bw - 34, by + 4)
    lg.setColor(0, 0, 0, 0.6 * a)
    lg.rectangle("fill", bx, by + bh - 28, bw, 28)
    lg.setColor(0.7, 0.88, 1, a)
    lg.printf("IT'S NOT CRYING. IT'S FREEDOM.", bx, by + bh - 24, bw, "center")
  end
  -- MISSION ACCOMPLISHED: a banner that drops in
  if t > 330 and t < 398 then
    local k = ease((t - 330) / 1.2)
    local y = lerp(-120, 110, k)
    local a = 1 - ease((t - 394) / 4)
    lg.setColor(RED[1] * 0.7, RED[2] * 0.7, RED[3] * 0.7, 0.92 * a)
    lg.rectangle("fill", 40, y - 12, W - 80, 86, 10, 10, 8)
    lg.setColor(1, 1, 1, 0.9 * a)
    lg.setLineWidth(3)
    lg.rectangle("line", 48, y - 4, W - 96, 70, 8, 8, 8)
    C.neon_draw("MISSION ACCOMPLISHED", 0, y + 6, 46, 0xffd23f, 0.8, "center", W, a)
  end
  -- U! S! A!
  for _, T in ipairs(CHANTS) do
    if t >= T and t < T + 4 then
      local beat = ((t - T) * 2) % 1
      local sc = 1 + 0.15 * (1 - beat)
      C.neon_draw("U! S! A!", 0, 440, 96, 0xff3344, 1.4, "center", W, min(1, (T + 4 - t) * 2), sc)
    end
  end
  -- BREAKING NEWS lower third (alert) and the ticker (always after the opening)
  local text = TICKER[act]
  if text then
    text = text .. "     "
    local y = H - 62
    lg.setColor(0.05, 0.06, 0.22, 0.92)
    lg.rectangle("fill", 0, y, W, 50)
    local label = (act == "alert" or act == "battle") and "BREAKING" or (act == "victory" and "VICTORY" or "FREEDOM NEWS")
    lg.setFont(C.font(22))
    local lw = C.font(22):getWidth(label) + 28
    ticker_x = ticker_x - 110 * (S.dt or 0.016)
    local tw = C.font(22):getWidth(text)
    if ticker_x < -tw then ticker_x = ticker_x + tw end
    lg.setColor(1, 1, 1, 0.95)
    lg.print(text, lw + 10 + ticker_x, y + 13)
    lg.print(text, lw + 10 + ticker_x + tw, y + 13)
    local blink = (act == "alert") and (floor(t * 3) % 2 == 0) and 0.75 or 1
    lg.setColor(RED[1] * blink, RED[2] * blink, RED[3] * blink, 1)
    lg.rectangle("fill", 0, y, lw, 50)
    lg.setColor(1, 1, 1, 1)
    lg.print(label, 14, y + 13)
  end
end

function F.draw()
  if not S then return end
  local fade = clamp((S.t - 553) / 4, 0, 0.82)
  local dark = draw_sky()
  draw_sun(dark)
  draw_clouds()
  draw_searchlights()
  draw_glow()
  draw_trails()
  draw_pix()
  draw_flag_and_pole()
  draw_ground(dark)
  draw_lawn_life()
  if #S.smoke > 0 then draw_puffs(S.smoke) end
  draw_dogs()
  if fade > 0 then
    lg.setColor(0.01, 0.0, 0.04, fade)
    lg.rectangle("fill", 0, 0, W, H)
  end
  draw_hud()
end

-- (the ticker's speed follows the frame)
local upd = F.update
function F.update(dt)
  if S then S.dt = dt end
  return upd(dt)
end

return F
