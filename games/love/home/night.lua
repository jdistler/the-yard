-- The night show: what Home does when nobody is playing (after the attract tour). A whole night, three hours
-- long, then it begins again: dusk, a night of scenes (a few minutes each, quiet sky between, a new order every
-- night), a rest stretch before dawn when everything dims right down, and dawn. A moon crosses the sky. The user
-- asked for it (2026-10-27: "much longer, more involved, a few hours cycle"); everything is drawn here from
-- shapes and little pixel sprites made in code.
--
--   night.load(ctx)            ctx: W, H, HORIZON, font, neon_draw, fx, log
--   night.draw(nt)             nt: seconds into the night (Home scales it by HOME_NIGHT_SPEED for tests)
--   night.scene_at(nt)         the scene's name at nt (tests, logs)
-- HOME_NIGHT_SCENE=name: that scene only, over and over (screenshots).
local lg = love.graphics
local N = {}
local C                                     -- the context from Home
local W, H, HZ
local CYCLE = 3 * 3600
local DUSK, REST, DAWN = 600, CYCLE - 1800, CYCLE - 900   -- dusk ends; the rest stretch; dawn
local FIRST = 120                            -- the first scene starts after two minutes of dusk
local only = os.getenv("HOME_NIGHT_SCENE")

local function clamp(x, a, b) return x < a and a or x > b and b or x end
local function ease(x) x = clamp(x, 0, 1) return x * x * (3 - 2 * x) end

-- A tiny deterministic generator (each night's order and each scene's layout come from its seed).
local function rng(seed)
  local s = seed % 2147483647
  if s <= 0 then s = s + 2147483646 end
  return function(a, b)
    s = s * 16807 % 2147483647
    local u = (s - 1) / 2147483646
    if a then return a + (b - a) * u end
    return u
  end
end

-- Pixel sprites from strings ("X" lit), white: tinted when drawn.
local function sprite(rows)
  local h, w = #rows, #rows[1]
  local d = love.image.newImageData(w, h)
  for y = 1, h do
    for x = 1, w do
      if rows[y]:sub(x, x) == "X" then d:setPixel(x - 1, y - 1, 1, 1, 1, 1) end
    end
  end
  local img = lg.newImage(d)
  d:release()
  img:setFilter("nearest", "nearest")
  return img
end
local SP = {}

-- ------------------------------------------------------------------ the scenes
-- Each: {name, run = function(st, s, k)} with st its own state table (made fresh for each showing, with a
-- seeded random), s seconds into the scene, k its fade (0..1, in over the first and out over the last 4 s).

local scenes = {}

-- 1. The chase along the horizon (the first night scene, kept).
scenes.chase = function(st, s, k)
  C.fx.draw_chase(s, HZ - 26, k)
end

-- 2. A swarm: a formation drifting in the sky; now and then one dives and loops back; a little ship patrols
--    the horizon and fires at it.
local SWARM_COLS = {{0.4, 0.9, 1}, {1, 0.4, 0.8}, {1, 0.85, 0.3}}
scenes.swarm = function(st, s, k)
  local cx, cy = W / 2 + math.sin(s * 0.25) * 140, 230 + math.sin(s * 0.7) * 10
  local frame = math.floor(s * 2) % 2
  local diver = math.floor(s / 7)
  local dk = (s % 7) / 7                     -- the dive: 0..1 over 7 s
  local dcol, drow = diver % 6, math.floor(diver / 6) % 3
  local dx, dy
  for row = 0, 2 do
    for col = 0, 5 do
      local x, y = cx + (col - 2.5) * 54, cy + row * 46
      local c = SWARM_COLS[row + 1]
      if col == dcol and row == drow and dk < 0.95 then
        -- Down in a loop toward the grid and back to its place.
        local a = dk * math.pi * 2
        x = x + math.sin(a) * 180 * (col < 3 and 1 or -1)
        y = y + (1 - math.cos(a)) * 230
        dx, dy = x, y
      end
      lg.setColor(c[1], c[2], c[3], k)
      lg.draw(SP.alien[frame + 1], x, y, 0, 3.4, 3.4, 5.5, 4)
    end
  end
  -- The ship follows the diver (dt-based) and fires from its locked X at shot time.
  local dt = clamp(s - (st.last_s or s), 0, 0.1)
  st.last_s = s
  st.shipx = st.shipx or W / 2
  local want = dx or W / 2 + math.sin(s * 0.4) * 200
  st.shipx = st.shipx + (want - st.shipx) * (1 - math.exp(-dt * 1.4))
  lg.setColor(0.9, 0.95, 1, k)
  lg.draw(SP.ship, st.shipx, HZ - 26, 0, 3.2, 3.2, 4.5, 4.5)
  local shot_id = math.floor(s * 0.6)
  local shot = (s * 0.6) % 1
  if dx and shot < 0.5 then
    if st.shot_id ~= shot_id then
      st.shot_id = shot_id
      st.shot_x = st.shipx
    end
    local sx = st.shot_x or st.shipx
    local by = HZ - 50 - shot * 2 * (HZ - 50 - (dy or 300))
    lg.setColor(1, 1, 0.6, k)
    lg.rectangle("fill", sx - 1.5, by, 3, 14)
  end
end

-- 3. Constellations: stars come out, lines join them into a shape, it glows, it fades; the next one.
local SHAPES = {
  ghost = {{0, .5}, {.1, .2}, {.3, .05}, {.5, 0}, {.7, .05}, {.9, .2}, {1, .5}, {1, 1}, {.83, .85}, {.67, 1}, {.5, .85},
           {.33, 1}, {.17, .85}, {0, 1}, {0, .5}},
  cherry = {{.28, .66}, {.42, .30}, {.60, .05}, {.78, .35}, {.74, .70}, nil, {.60, .05}, {.44, .18}, nil,
            {.28, .66}, {.16, .70}, {.12, .82}, {.20, .94}, {.34, .94}, {.42, .82}, {.38, .70}, {.28, .66}, nil,
            {.74, .70}, {.62, .74}, {.58, .86}, {.66, .98}, {.80, .98}, {.88, .86}, {.84, .74}, {.74, .70}},
  ship = {{.5, 0}, {.6, .35}, {1, .7}, {.65, .65}, {.55, 1}, {.45, 1}, {.35, .65}, {0, .7}, {.4, .35}, {.5, 0}},
  key = {{.2, .1}, {.4, 0}, {.5, .2}, {.4, .4}, {.2, .3}, {.2, .1}, nil, {.45, .35}, {.95, .9}, nil, {.8, .75}, {.7, .85},
         nil, {.9, .85}, {.8, .95}},
  star = {{.5, 0}, {.62, .35}, {1, .38}, {.7, .6}, {.8, 1}, {.5, .78}, {.2, 1}, {.3, .6}, {0, .38}, {.38, .35}, {.5, 0}},
  chomper = {{.95, .25}, {.75, .05}, {.5, 0}, {.25, .05}, {.05, .25}, {0, .5}, {.05, .75}, {.25, .95}, {.5, 1}, {.75, .95},
             {.95, .75}, {.5, .5}, {.95, .25}},
}
local SHAPE_ORDER = {"ghost", "cherry", "ship", "key", "star", "chomper"}
scenes.stars = function(st, s, k)
  local per = 40
  local i = math.floor(s / per)
  local t = s % per
  local name = SHAPE_ORDER[(i + (st.first or 0)) % #SHAPE_ORDER + 1]
  st.pos = st.pos or {}
  if not st.pos[i] then st.pos[i] = {st.r(110, 420), st.r(180, 420)} end
  local ox, oy = st.pos[i][1], st.pos[i][2]
  local size = 230
  local pts = SHAPES[name]
  local appear, draw_l, hold = 8, 12, 12
  local fade = t < appear + draw_l + hold and 1 or 1 - (t - appear - draw_l - hold) / 8
  fade = clamp(fade, 0, 1) * k
  -- The lines, drawn little by little.
  local nseg = 0
  for j = 1, #pts - 1 do if pts[j] and pts[j + 1] then nseg = nseg + 1 end end
  local shown = clamp((t - appear) / draw_l, 0, 1) * nseg
  lg.setLineWidth(2)
  local seg = 0
  for j = 1, #pts - 1 do
    local a, b = pts[j], pts[j + 1]
    if a and b then
      local f = clamp(shown - seg, 0, 1)
      if f > 0 then
        local x1, y1 = ox + a[1] * size, oy + a[2] * size
        local x2, y2 = x1 + (b[1] - a[1]) * size * f, y1 + (b[2] - a[2]) * size * f
        lg.setColor(0.55, 0.75, 1, 0.55 * fade)
        lg.line(x1, y1, x2, y2)
      end
      seg = seg + 1
    end
  end
  -- A shooting star now and then, across the whole sky.
  local sh = s % 14
  if sh < 1.6 then
    local f = sh / 1.6
    local sx0 = (math.floor(s / 14) * 197) % (W - 200) + 100
    local x, y = sx0 + f * 300, 90 + f * 140
    lg.setColor(1, 1, 1, math.sin(f * math.pi) * k)
    lg.setLineWidth(2)
    lg.line(x, y, x - 60, y - 28)
    lg.circle("fill", x, y, 2.5, 8)
  end
  -- The stars, brightening one by one.
  for j, p in ipairs(pts) do
    if p then
      local b = clamp((t - j * appear / #pts) / 1.5, 0, 1) * fade
      local tw = 0.7 + 0.3 * math.sin(s * 3 + j)
      C.fx.glow(ox + p[1] * size, oy + p[2] * size, 14, 14, 0.8, 0.9, 1, 0.5 * b * tw)
      lg.setColor(1, 1, 1, b)
      lg.circle("fill", ox + p[1] * size, oy + p[2] * size, 2.6, 8)
    end
  end
  -- Subtle constellation title fade-in during hold.
  if t > appear + draw_l - 1 then
    local ta = clamp((t - (appear + draw_l - 1)) / 2, 0, 1) * fade
    lg.setFont(C.font(18))
    lg.setColor(0.7, 0.85, 1, 0.55 * ta)
    lg.printf(string.upper(name), ox - 20, oy + size + 16, size + 40, "center")
  end
  lg.setLineWidth(1)
end

-- 4. Fireflies: they wander, gather into a word, hold it, and scatter.
local GLYPHS = {
  H = {"X...X", "X...X", "X...X", "XXXXX", "X...X", "X...X", "X...X"},
  I = {"XXXXX", "..X..", "..X..", "..X..", "..X..", "..X..", "XXXXX"},
  ["!"] = {"..X..", "..X..", "..X..", "..X..", "..X..", ".....", "..X.."},
  P = {"XXXX.", "X...X", "X...X", "XXXX.", "X....", "X....", "X...."},
  L = {"X....", "X....", "X....", "X....", "X....", "X....", "XXXXX"},
  A = {".XXX.", "X...X", "X...X", "XXXXX", "X...X", "X...X", "X...X"},
  Y = {"X...X", "X...X", ".X.X.", "..X..", "..X..", "..X..", "..X.."},
  ["?"] = {".XXX.", "X...X", "....X", "...X.", "..X..", ".....", "..X.."},
  Z = {"XXXXX", "....X", "...X.", "..X..", ".X...", "X....", "XXXXX"},
  G = {".XXX.", "X...X", "X....", "X.XXX", "X...X", "X...X", ".XXX."},
  O = {".XXX.", "X...X", "X...X", "X...X", "X...X", "X...X", ".XXX."},
  D = {"XXXX.", "X...X", "X...X", "X...X", "X...X", "X...X", "XXXX."},
  N = {"X...X", "XX..X", "X.X.X", "X..XX", "X...X", "X...X", "X...X"},
  T = {"XXXXX", "..X..", "..X..", "..X..", "..X..", "..X..", "..X.."},
  ["<"] = {"...X.", "..X..", ".X...", "X....", ".X...", "..X..", "...X."},
  ["3"] = {"XXXX.", "....X", "....X", ".XXX.", "....X", "....X", "XXXX."},
}
local WORDS = {"HI!", "PLAY?", "ZZZ", "<3", "GOOD", "NIGHT", "GG"}
local word_cache = {}
local function word_points(word)
  if word_cache[word] then return word_cache[word] end
  local pts = {}
  word_cache[word] = pts
  local cell = 15
  local ww = #word * 6 * cell
  local x0, y0 = (W - ww) / 2, 330
  for i = 1, #word do
    local g = GLYPHS[word:sub(i, i)]
    if g then
      for y = 1, 7 do
        for x = 1, 5 do
          if g[y]:sub(x, x) == "X" then pts[#pts + 1] = {x0 + ((i - 1) * 6 + x - 1) * cell, y0 + (y - 1) * cell} end
        end
      end
    end
  end
  return pts
end
local batch
local function fireflies(st, s, k, n, words)
  if not st.flies then
    st.flies = {}
    for i = 1, n do
      st.flies[i] = {x = st.r(0, W), y = st.r(150, HZ - 20), ph = st.r(0, 6.3), sp = st.r(0.2, 0.6)}
    end
  end
  local per = 36
  local wi = math.floor(s / per)
  local t = s % per
  local target = words and word_points(WORDS[(wi + (st.first or 0)) % #WORDS + 1]) or nil
  -- wander 14 s, gather 8 s, hold 8 s, scatter 6 s
  local pull = 0
  if target then
    if t >= 14 and t < 22 then pull = ease((t - 14) / 8)
    elseif t >= 22 and t < 30 then pull = 1
    elseif t >= 30 then pull = 1 - ease((t - 30) / 6) end
  end
  -- All the glows in one batch, from a glow texture their own size: Home's 128-px glow shrunk to 32 px (no
  -- mipmaps) held the cabinet at 50 fps; this one at 60 (2026-10-27).
  if not batch then
    local n = 32
    local d = love.image.newImageData(n, n)
    d:mapPixel(function(x, y)
      local dx, dy = (x + 0.5) / n * 2 - 1, (y + 0.5) / n * 2 - 1
      local v = math.max(0, 1 - (dx * dx + dy * dy))
      return 1, 1, 1, v * v
    end)
    local img = lg.newImage(d)
    d:release()
    img:setFilter("linear", "linear")
    batch = lg.newSpriteBatch(img, 256, "stream")
  end
  batch:clear()
  st.cores = st.cores or {}
  local cores = st.cores
  for i, f in ipairs(st.flies) do
    local wx = f.x + math.sin(s * f.sp + f.ph) * 60
    local wy = f.y + math.cos(s * f.sp * 0.8 + f.ph * 1.3) * 40
    local x, y = wx, wy
    local tp = target and target[(i - 1) % #target + 1]
    if tp and i <= #target then x, y = wx + (tp[1] - wx) * pull, wy + (tp[2] - wy) * pull end
    local blink = 0.5 + 0.5 * math.sin(s * 2.1 + f.ph * 3)
    -- In the word they stop blinking and shine, so it reads.
    local inword = (tp and i <= #target) and pull or 0
    blink = blink + (1 - blink) * inword
    batch:setColor(0.85, 1, 0.45, (0.35 + 0.3 * inword) * blink * k)
    batch:add(x, y, 0, 1, 1, 16, 16)
    local c = cores[i] or {}
    c[1], c[2], c[3], c[4] = x, y, (0.5 + 0.5 * blink) * k, 3 + 2 * inword
    cores[i] = c
  end
  lg.setBlendMode("add")
  lg.setColor(1, 1, 1, 1)
  lg.draw(batch)
  lg.setBlendMode("alpha")
  for _, c in ipairs(cores) do
    lg.setColor(1, 1, 0.75, c[3])
    lg.rectangle("fill", c[1] - c[4] / 2, c[2] - c[4] / 2, c[4], c[4])
  end
end
scenes.fireflies = function(st, s, k) fireflies(st, s, k, 110, true) end

-- 5. An aurora: ribbons of light rippling across the sky (pre-allocated vertices: zero per-frame GC).
local ribbon, aurora_verts = nil, nil
local AURORA_COLS = {{0.3, 1, 0.6}, {0.4, 0.8, 1}, {0.8, 0.4, 1}}
scenes.aurora = function(st, s, k)
  if not ribbon then
    ribbon = lg.newMesh(2 * 49, "strip", "stream")
    aurora_verts = {}
    for i = 1, 2 * 49 do aurora_verts[i] = {0, 0, 0, 0, 1, 1, 1, 0} end
  end
  lg.setBlendMode("add")
  for r = 1, 3 do
    local base = 180 + r * 55
    local c = AURORA_COLS[r]
    local c1, c2, c3 = c[1], c[2], c[3]
    for i = 0, 48 do
      local x = i / 48 * W
      local y = base + math.sin(x * 0.008 + s * 0.25 * r + r) * 45 + math.sin(x * 0.021 - s * 0.4) * 18
      local a = (0.18 + 0.12 * math.sin(x * 0.01 + s * 0.6 + r)) * k
      local v1 = aurora_verts[i * 2 + 1]
      v1[1], v1[2], v1[5], v1[6], v1[7], v1[8] = x, y - 110, c1, c2, c3, 0
      local v2 = aurora_verts[i * 2 + 2]
      v2[1], v2[2], v2[5], v2[6], v2[7], v2[8] = x, y, c1, c2, c3, a
    end
    ribbon:setVertices(aurora_verts)
    lg.setColor(1, 1, 1, 1)
    lg.draw(ribbon)
  end
  lg.setBlendMode("alpha")
end

-- 6. A meteor shower.
scenes.meteors = function(st, s, k)
  st.m = st.m or {}
  st.next = st.next or 0
  while s >= st.next do
    st.m[#st.m + 1] = {t0 = st.next, x = st.r(-100, W), y = st.r(40, 300), vx = st.r(260, 420), vy = st.r(140, 240)}
    st.next = st.next + st.r(0.15, 0.9)
  end
  -- every 20 s a big slow one, all the way to the horizon, and a soft glow where it lands
  local bt = s % 20
  if bt < 5 then
    local f = bt / 4
    local x0 = 80 + (math.floor(s / 20) * 233) % (W - 300)
    local bdx, bdy = 260, HZ - 70
    local x, y = x0 + f * bdx, 60 + f * bdy
    if f < 1 then
      local blen = math.sqrt(bdx * bdx + bdy * bdy)
      local ux, uy = bdx / blen, bdy / blen
      lg.setLineWidth(4)
      for j = 1, 6 do
        lg.setColor(1, 0.7 - j * 0.08, 0.4, (0.6 - j * 0.09) * k)
        lg.line(x - j * 34 * ux, y - j * 34 * uy, x - (j - 1) * 34 * ux, y - (j - 1) * 34 * uy)
      end
      C.fx.glow(x, y, 26, 26, 1, 0.8, 0.5, 0.7 * k)
    else
      local g = (bt - 4)
      C.fx.glow(x0 + bdx, HZ - 6, 60 * g + 20, 24, 1, 0.6, 0.3, 0.5 * (1 - g) * k)
    end
  end
  lg.setLineWidth(2)
  for i = #st.m, 1, -1 do
    local m = st.m[i]
    local a = s - m.t0
    if a > 1.6 then table.remove(st.m, i) else
      local x, y = m.x + m.vx * a, m.y + m.vy * a
      local f = math.sin(a / 1.6 * math.pi) * k
      lg.setColor(1, 0.9, 1, 0.8 * f)
      lg.line(x, y, x - m.vx * 0.12, y - m.vy * 0.12)
      lg.setColor(1, 1, 1, f)
      lg.circle("fill", x, y, 1.8, 6)
    end
  end
end

-- 7. A neon city: a skyline rises at the horizon, windows come and go, a blimp tows the name across.
scenes.city = function(st, s, k)
  if not st.b then
    st.b = {}
    local x = -10
    while x < W do
      local w = st.r(40, 90)
      st.b[#st.b + 1] = {x = x, w = w, h = st.r(70, 230), hue = st.r(0, 1), seed = math.floor(st.r(1, 1e6))}
      x = x + w + st.r(2, 10)
    end
  end
  local rise = ease(s / 10)
  for _, b in ipairs(st.b) do
    local top = HZ - b.h * rise
    lg.setColor(0.04, 0.02, 0.09, 0.95 * k)
    lg.rectangle("fill", b.x, top, b.w, HZ - top)
    local edge = b.hue < 0.5 and {1, 0.3, 0.85} or {0.3, 0.9, 1}
    lg.setColor(edge[1], edge[2], edge[3], 0.7 * k)
    lg.setLineWidth(2)
    lg.line(b.x, HZ, b.x, top, b.x + b.w, top, b.x + b.w, HZ)
    -- Rooftop aviation beacons on tall towers.
    if b.h > 165 and rise > 0.95 then
      local rx = b.x + b.w * 0.5
      lg.setColor(0.5, 0.5, 0.6, 0.7 * k)
      lg.setLineWidth(1.5)
      lg.line(rx, top, rx, top - 16)
      local pulse = 0.35 + 0.65 * math.max(0, math.sin(s * 3.2 + b.seed))
      lg.setColor(1, 0.18, 0.22, pulse * k)
      lg.circle("fill", rx, top - 17, 2.8, 8)
      if pulse > 0.75 then C.fx.glow(rx, top - 17, 14, 14, 1, 0.2, 0.2, 0.45 * pulse * k) end
    end
    -- Windows: each lit or dark by a slow hash of its place and the time.
    if rise > 0.95 then
      for wy = top + 14, HZ - 14, 18 do
        for wx = b.x + 8, b.x + b.w - 14, 14 do
          local h = math.sin(wx * 12.9898 + wy * 78.233 + b.seed + math.floor(s / 6 + wx * 0.01)) * 43758.5453
          if h - math.floor(h) > 0.55 then
            lg.setColor(1, 0.85, 0.45, 0.75 * k)
            lg.rectangle("fill", wx, wy, 6, 8)
          end
        end
      end
    end
  end
  -- The night train across the foot of the skyline, every 22 s, its windows lit.
  local tt = (s % 22) / 22
  if rise > 0.95 then
    local tx = W + 60 - tt * (W + 700)
    for c = 0, 6 do
      local cx = tx + c * 78
      lg.setColor(0.08, 0.05, 0.16, k)
      lg.rectangle("fill", cx, HZ - 26, 72, 22, 4, 4, 4)
      lg.setColor(0.3, 0.9, 1, 0.8 * k)
      lg.rectangle("line", cx, HZ - 26, 72, 22, 4, 4, 4)
      for w = 0, 3 do
        lg.setColor(1, 0.85, 0.45, 0.8 * k)
        lg.rectangle("fill", cx + 8 + w * 16, HZ - 21, 9, 7)
      end
    end
    C.fx.glow(tx - 6, HZ - 16, 30, 14, 1, 1, 0.8, 0.6 * k)
  end
  -- The blimp, once a minute.
  local bt = (s % 60) / 60
  local bx, by = -220 + bt * (W + 440), 300 + math.sin(s * 0.5) * 8
  lg.setColor(0.75, 0.75, 0.85, k)
  lg.ellipse("fill", bx, by, 70, 24, 32)
  lg.setColor(0.3, 0.3, 0.4, k)
  lg.rectangle("fill", bx - 14, by + 20, 28, 9)
  lg.setColor(1, 0.3, 0.85, k)
  lg.setLineWidth(1)
  lg.line(bx - 70, by, bx - 110, by + 4)
  lg.setColor(0.08, 0.04, 0.14, 0.9 * k)
  lg.rectangle("fill", bx - 300, by - 14, 190, 34)
  lg.setColor(1, 0.4, 0.88, k)
  lg.rectangle("line", bx - 300, by - 14, 190, 34)
  lg.setFont(C.font(22))
  lg.printf("STARLIGHT", bx - 300, by - 9, 190, "center")
end

-- 8. A UFO: it hums across, stops over a wandering ghost, beams it up, and goes.
local UFO_GHOSTS = {{1, 0.18, 0.2}, {1, 0.55, 0.85}, {0.25, 0.95, 1}, {1, 0.65, 0.2}}
scenes.ufo = function(st, s, k)
  local per = 30
  local cyc = math.floor(s / per)
  local t = s % per
  local gx = W * 0.55 + math.sin(cyc * 2.1) * 180
  local ux, uy
  if t < 10 then ux, uy = -120 + (gx + 120) * ease(t / 10), 300
  elseif t < 22 then ux, uy = gx, 300 + math.sin(t * 2) * 3
  else ux, uy = gx + (W + 160 - gx) * ease((t - 22) / 8), 300 - (t - 22) * 10 end
  -- The ghost: wanders on the horizon, then floats up in the beam.
  local lift = t < 13 and 0 or t < 21 and ease((t - 13) / 8) or 1
  local col_now = UFO_GHOSTS[cyc % #UFO_GHOSTS + 1]
  local col_prev = UFO_GHOSTS[(cyc - 1) % #UFO_GHOSTS + 1]
  -- (last cycle's ghost given back: dropped down a beam far off as the saucer leaves)
  if t > 24 and t < 29 and s >= per then
    local f = (t - 24) / 5
    local bx2 = ux - 40
    lg.setColor(0.6, 1, 0.8, 0.15 * k)
    lg.polygon("fill", bx2 - 12, uy + 10, bx2 + 12, uy + 10, bx2 + 40, HZ, bx2 - 40, HZ)
    C.fx.ghost(bx2, uy + 30 + f * (HZ - uy - 52), 14, col_prev, 1, s, false, false, k)
  end
  if lift < 1 then
    local gy = HZ - 22 - lift * (HZ - 22 - uy - 20)
    local damp = t < 10 and 1 or (1 - ease((t - 10) / 2.5))
    local wob = math.sin(t * 2) * 30 * damp
    local scared = t >= 11.5
    C.fx.ghost(gx + wob, gy, 18, col_now, math.cos(t * 2) >= 0 and 1 or -1, s, scared, false, k)
  end
  if t >= 11 and t < 21 then
    local b = math.min(1, (t - 11) / 1.5) * (t > 20 and (21 - t) or 1) * k
    lg.setColor(0.6, 1, 0.8, 0.22 * b)
    lg.polygon("fill", ux - 22, uy + 10, ux + 22, uy + 10, ux + 60, HZ, ux - 60, HZ)
  end
  -- The saucer.
  C.fx.glow(ux, uy, 90, 40, 0.5, 1, 0.8, 0.18 * k)
  lg.setColor(0.7, 0.75, 0.85, k)
  lg.ellipse("fill", ux, uy, 56, 16, 32)
  lg.setColor(0.5, 0.9, 1, 0.8 * k)
  lg.arc("fill", "pie", ux, uy - 4, 22, math.pi, 2 * math.pi, 20)
  for i = 0, 4 do
    local on = math.floor(s * 6 + i) % 2 == 0
    lg.setColor(on and 1 or 0.4, on and 0.85 or 0.3, 0.3, k)
    lg.circle("fill", ux - 36 + i * 18, uy + 4, 3.5, 8)
  end
end

-- 9. The digger: a little helmeted digger tunnels under the grid; its tunnel stays for the scene.
scenes.digger = function(st, s, k)
  if not st.path then
    -- A walk on a coarse grid under the horizon: right, down, right, up...
    local p = {{-20, HZ + 70}}
    local x, y = -20, HZ + 70
    while x < W + 40 do
      local dir = st.r() < 0.6 and "r" or "v"
      if dir == "r" then x = x + st.r(60, 140) else y = clamp(y + (st.r() < 0.5 and -1 or 1) * st.r(40, 90), HZ + 40, H - 40) end
      local prev = p[#p]
      if x ~= prev[1] or y ~= prev[2] then p[#p + 1] = {x, y} end
    end
    st.path = p
    local len = 0
    for i = 2, #p do len = len + math.abs(p[i][1] - p[i - 1][1]) + math.abs(p[i][2] - p[i - 1][2]) end
    st.len = len
  end
  local d = (s * 45) % (st.len + 300)
  -- The tunnel so far.
  local pts, left = {st.path[1][1], st.path[1][2]}, d
  local hx, hy, hdir = st.path[1][1], st.path[1][2], 1
  for i = 2, #st.path do
    local a, b = st.path[i - 1], st.path[i]
    local seg = math.abs(b[1] - a[1]) + math.abs(b[2] - a[2])
    if left <= 0 then break end
    if seg > 0 then
      local f = math.min(1, left / seg)
      hx, hy = a[1] + (b[1] - a[1]) * f, a[2] + (b[2] - a[2]) * f
      if b[1] ~= a[1] then hdir = b[1] > a[1] and 1 or -1 end
      pts[#pts + 1], pts[#pts + 2] = hx, hy
      left = left - seg
    end
  end
  if #pts >= 4 then
    lg.setLineJoin("bevel")
    lg.setLineWidth(30)
    lg.setColor(0.35, 0.15, 0.08, 0.9 * k)
    lg.line(pts)
    lg.setLineWidth(22)
    lg.setColor(0.02, 0.0, 0.04, k)
    lg.line(pts)
    lg.setLineJoin("miter")
    lg.setLineWidth(1)
  end
  -- Treasures buried along the way (cherries, gems): it digs to each, it sparkles, it's gone.
  if not st.gems then
    st.gems = {}
    for i = 3, #st.path - 1, 2 do st.gems[#st.gems + 1] = {st.path[i][1], st.path[i][2], math.floor(st.r(0, 3))} end
  end
  for _, g in ipairs(st.gems) do
    local dist = math.abs(g[1] - hx) + math.abs(g[2] - hy)

    -- (found: once the tunnel has gone past it)
    local found = false
    local acc = 0
    for i = 2, #st.path do
      local a, b = st.path[i - 1], st.path[i]
      if a[1] == g[1] and a[2] == g[2] then found = acc <= d break end
      acc = acc + math.abs(b[1] - a[1]) + math.abs(b[2] - a[2])
    end
    local age = d - acc
    if not found then
      lg.setColor(0.6, 0.4, 0.25, 0.5 * k)
      lg.circle("fill", g[1], g[2], 9, 10)
      if g[3] == 0 then lg.setColor(1, 0.25, 0.3, 0.8 * k) elseif g[3] == 1 then lg.setColor(0.4, 0.9, 1, 0.8 * k) else lg.setColor(1, 0.85, 0.3, 0.8 * k) end
      lg.circle("fill", g[1], g[2], 5, 8)
    elseif age < 60 then
      local f = age / 60
      C.fx.glow(g[1], g[2] - f * 40, 24, 24, 1, 0.9, 0.5, (1 - f) * 0.8 * k)
    end
  end
  -- The digger: a round body, a white helmet, a little pump.
  local bob = math.sin(s * 10) * 2
  lg.setColor(0.95, 0.95, 1, k)
  lg.circle("fill", hx, hy - 4 + bob, 11, 16)
  lg.setColor(0.25, 0.5, 1, k)
  lg.rectangle("fill", hx - 9, hy + 4 + bob, 18, 10, 3, 3)
  lg.setColor(0.2, 0.2, 0.3, k)
  lg.circle("fill", hx + hdir * 4, hy - 5 + bob, 2, 6)
  lg.setColor(1, 0.85, 0.3, k)
  lg.rectangle("fill", hdir > 0 and hx + 9 or hx - 19, hy + 5 + bob, 10, 3)
end

-- 10. The sign dreams: thought bubbles rise from it with what it dreams of.
local DREAMS = {"cherry", "ghost", "star", "heart", "key"}
local function icon(name, x, y, a, s)
  if name == "cherry" then
    lg.setColor(0.3, 0.8, 0.3, a)
    lg.setLineWidth(2)
    lg.line(x - 6, y + 2, x + 2, y - 12, x + 8, y + 4)
    lg.setColor(1, 0.2, 0.25, a)
    lg.circle("fill", x - 7, y + 5, 7, 12)
    lg.circle("fill", x + 8, y + 7, 7, 12)
  elseif name == "ghost" then
    C.fx.ghost(x, y, 11, {0.3, 0.9, 1}, 1, s, false, false, a)
  elseif name == "star" then
    lg.setColor(1, 0.9, 0.3, a)
    local ox, oy, ix, iy = {}, {}, {}, {}
    for i = 0, 4 do
      local ang = -math.pi / 2 + i * 2 * math.pi / 5
      ox[i], oy[i] = x + math.cos(ang) * 12, y + math.sin(ang) * 12
      ix[i], iy[i] = x + math.cos(ang + math.pi / 5) * 5, y + math.sin(ang + math.pi / 5) * 5
    end
    lg.polygon("fill", ix[0], iy[0], ix[1], iy[1], ix[2], iy[2], ix[3], iy[3], ix[4], iy[4])
    for i = 0, 4 do
      local j = (i + 4) % 5
      lg.polygon("fill", ox[i], oy[i], ix[i], iy[i], ix[j], iy[j])
    end
  elseif name == "heart" then
    lg.setColor(1, 0.35, 0.6, a)
    lg.circle("fill", x - 5, y - 3, 6, 12)
    lg.circle("fill", x + 5, y - 3, 6, 12)
    lg.polygon("fill", x - 11, y - 1, x + 11, y - 1, x, y + 12)
  else
    lg.setColor(1, 0.85, 0.3, a)
    lg.setLineWidth(3)
    lg.circle("line", x - 6, y, 5, 10)
    lg.line(x - 1, y, x + 12, y, x + 12, y + 5)
    lg.setLineWidth(1)
  end
end
scenes.dream = function(st, s, k)
  for i = 0, 3 do
    local b = s / 6 - i * 0.25
    local n = math.floor(b)
    local f = b - n
    if n >= 0 then
      local name = DREAMS[(n + i) % #DREAMS + 1]
      local x = W / 2 + 120 + math.sin(n * 1.7 + i) * 160
      local y = 210 + f * 220
      local a = math.sin(f * math.pi) * k
      lg.setColor(0.9, 0.9, 1, 0.12 * a)
      lg.circle("fill", x, y, 30, 24)
      lg.setColor(0.9, 0.9, 1, 0.5 * a)
      lg.setLineWidth(2)
      lg.circle("line", x, y, 30, 24)
      lg.circle("line", x - 30, y - 30, 7, 12)
      lg.circle("line", x - 42, y - 48, 4, 10)
      icon(name, x, y, a, s)
    end
  end
  lg.setLineWidth(1)
end

-- 11. The Drive-In: retro outdoor movie screen on the horizon, silhouetted cars dimming headlights,
--     flickering projector beam with moths, and tiny neon arcade silent-film loops.
local DRIVEIN_REELS = {"THE GREAT CHASE", "INVASION FROM MARS", "STARLIGHT ROMANCE"}
scenes.drivein = function(st, s, k)
  local sw, sh = 370, 206
  local sx, sy = (W - sw) / 2, HZ - sh - 78
  -- Support trusses and wooden/steel screen tower.
  lg.setColor(0.08, 0.06, 0.14, 0.95 * k)
  lg.rectangle("fill", sx - 16, sy - 26, sw + 32, sh + 42, 6, 6)
  lg.rectangle("fill", sx + 26, sy + sh + 16, 18, HZ - (sy + sh + 16))
  lg.rectangle("fill", sx + sw - 44, sy + sh + 16, 18, HZ - (sy + sh + 16))
  lg.setColor(0.16, 0.12, 0.26, 0.85 * k)
  lg.setLineWidth(2)
  lg.line(sx + 44, sy + sh + 18, sx + sw - 44, HZ - 6)
  lg.line(sx + sw - 44, sy + sh + 18, sx + 44, HZ - 6)
  -- Marquee neon trim & chasing bulbs along the top of the screen tower.
  lg.setColor(1, 0.35, 0.78, 0.8 * k)
  lg.rectangle("line", sx - 16, sy - 26, sw + 32, sh + 42, 6, 6)
  for i = 0, 14 do
    local bx = sx - 4 + i * ((sw + 8) / 14)
    local lit = (math.floor(s * 5) + i) % 3 == 0
    lg.setColor(1, lit and 0.92 or 0.5, lit and 0.55 or 0.3, (lit and 0.95 or 0.35) * k)
    lg.circle("fill", bx, sy - 14, lit and 2.8 or 2.0, 8)
  end
  -- Projector flicker and ambient screen glow.
  local flk = 0.92 + 0.08 * math.sin(s * 37) * math.cos(s * 19)
  C.fx.glow(W / 2, sy + sh / 2, 260, 160, 0.6, 0.8, 1, 0.16 * flk * k)
  -- Movie screen backdrop + silent-film reels clipped to the screen.
  lg.setColor(0.05, 0.07, 0.14, 0.96 * k)
  lg.rectangle("fill", sx, sy, sw, sh)
  local scx1, scy1 = lg.transformPoint(sx, sy)
  local scx2, scy2 = lg.transformPoint(sx + sw, sy + sh)
  lg.setScissor(math.floor(scx1), math.floor(scy1), math.max(0, math.floor(scx2 - scx1)), math.max(0, math.floor(scy2 - scy1)))
  local per = 20
  local reel = math.floor(s / per) % 3 + 1
  local rt = s % per
  if rt < 3.2 then
    -- Classic silent-film intertitle card.
    local ta = math.sin(clamp(rt / 3.2, 0, 1) * math.pi) * flk * k
    lg.setColor(0.06, 0.05, 0.1, 0.95 * k)
    lg.rectangle("fill", sx, sy, sw, sh)
    lg.setColor(0.95, 0.9, 0.75, 0.6 * ta)
    lg.setLineWidth(2)
    lg.rectangle("line", sx + 14, sy + 14, sw - 28, sh - 28, 4, 4)
    lg.setFont(C.font(16))
    lg.setColor(0.95, 0.9, 0.75, 0.75 * ta)
    lg.printf("REEL " .. reel, sx, sy + 58, sw, "center")
    lg.setFont(C.font(22))
    lg.setColor(1, 0.95, 0.82, ta)
    lg.printf(DRIVEIN_REELS[reel], sx + 20, sy + 94, sw - 40, "center")
  elseif reel == 1 then
    -- Reel 1: Neon maze corridor chase.
    local mt = rt - 3.2
    lg.setColor(0.18, 0.42, 1, 0.85 * flk * k)
    lg.setLineWidth(3)
    lg.line(sx + 10, sy + 72, sx + sw - 10, sy + 72)
    lg.line(sx + 10, sy + 142, sx + sw - 10, sy + 142)
    local p = (mt % 8) / 8
    local px = p < 0.5 and (sx - 20 + (sw + 60) * (p * 2)) or (sx + sw + 40 - (sw + 80) * ((p - 0.5) * 2))
    local cy = sy + 107
    for d = 0, 11 do
      local dx = sx + 28 + d * 28
      if (p < 0.5 and dx > px) or (p >= 0.5 and dx < px) then
        lg.setColor(1, 0.9, 0.6, 0.85 * flk * k)
        lg.circle("fill", dx, cy, d == 11 and 5 or 2.5, 8)
      end
    end
    C.fx.chomper(px, cy, 13, p < 0.5 and 1 or -1, s, flk * k)
    for gi = 1, 3 do
      local gx = p < 0.5 and (px - 36 - gi * 32) or (px - 36 - (4 - gi) * 32)
      C.fx.ghost(gx, cy, 12, UFO_GHOSTS[gi], p < 0.5 and 1 or -1, s + gi, p >= 0.5, false, flk * k)
    end
  elseif reel == 2 then
    -- Reel 2: Invasion from Mars — saucer over tiny skyline, hero ship zapping.
    local mt = rt - 3.2
    lg.setColor(0.12, 0.14, 0.28, 0.9 * k)
    for bi = 0, 7 do
      local bh = 28 + (bi * 17) % 34
      lg.rectangle("fill", sx + 12 + bi * 44, sy + sh - bh, 36, bh)
    end
    local ux = sx + sw / 2 + math.sin(mt * 1.1) * 110
    local uy = sy + 58 + math.sin(mt * 2.2) * 14
    lg.setColor(0.55, 1, 0.8, 0.18 * flk * k)
    lg.polygon("fill", ux - 12, uy + 8, ux + 12, uy + 8, ux + 32, sy + sh - 20, ux - 32, sy + sh - 20)
    lg.setColor(0.75, 0.85, 1, flk * k)
    lg.ellipse("fill", ux, uy, 28, 9, 20)
    lg.setColor(0.4, 0.95, 1, 0.9 * flk * k)
    lg.arc("fill", "pie", ux, uy - 2, 12, math.pi, 2 * math.pi, 14)
    local shipx = sx + sw / 2 + math.sin(mt * 0.85) * 90
    lg.setColor(1, 0.95, 0.7, flk * k)
    lg.draw(SP.ship, shipx, sy + sh - 20, 0, 2.2, 2.2, 4.5, 4.5)
    local shot = (mt * 1.4) % 1
    if shot < 0.6 then
      lg.setColor(1, 0.4, 0.8, flk * k)
      lg.rectangle("fill", shipx - 1.5, sy + sh - 32 - shot * 190, 3, 12)
    end
  else
    -- Reel 3: Starlight Romance — two ghosts meeting under a tiny moon with a rising heart.
    local mt = rt - 3.2
    local meet = ease(clamp(mt / 5, 0, 1))
    lg.setColor(0.95, 0.92, 0.75, 0.9 * flk * k)
    lg.circle("fill", sx + sw - 56, sy + 44, 18, 20)
    lg.setColor(0.05, 0.07, 0.14, 1)
    lg.circle("fill", sx + sw - 48, sy + 39, 15, 20)
    local g1x = sx + 52 + meet * 108
    local g2x = sx + sw - 52 - meet * 108
    local gy = sy + sh - 46
    C.fx.ghost(g1x, gy, 15, {0.25, 0.95, 1}, 1, s, false, false, flk * k)
    C.fx.ghost(g2x, gy, 15, {1, 0.55, 0.85}, -1, s + 1, false, false, flk * k)
    if meet > 0.7 then
      local hf = (mt * 0.45) % 1
      local hx, hy = sx + sw / 2, gy - 26 - hf * 74
      local ha = math.sin(hf * math.pi) * flk * k
      icon("heart", hx, hy, ha, s)
    end
  end
  -- Subtle film-grain scanline & dust scratch.
  local scratch_x = sx + ((math.floor(s * 12) * 73) % sw)
  lg.setColor(1, 1, 1, 0.08 * flk * k)
  lg.rectangle("fill", scratch_x, sy, 1, sh)
  lg.setScissor()
  -- Projector booth silhouette on the lower left + flickering beam cone with fluttering moths.
  local bx, by = 56, HZ + 24
  lg.setColor(0.06, 0.04, 0.12, 0.95 * k)
  lg.rectangle("fill", bx - 22, by - 24, 44, 34, 3, 3)
  lg.setColor(1, 0.95, 0.8, 0.9 * flk * k)
  lg.circle("fill", bx + 18, by - 14, 3.5, 8)
  lg.setBlendMode("add")
  lg.setColor(0.75, 0.85, 1, 0.075 * flk * k)
  lg.polygon("fill", bx + 18, by - 14, sx, sy, sx + sw, sy + sh)
  lg.setColor(0.85, 0.9, 1, 0.045 * flk * k)
  lg.polygon("fill", bx + 18, by - 14, sx, sy + sh, sx + sw, sy)
  lg.setBlendMode("alpha")
  -- Tiny moths fluttering inside the projector beam.
  for m = 1, 6 do
    local mf = 0.18 + ((m * 0.13 + math.sin(s * 0.4 + m) * 0.06) % 0.65)
    local mx = (bx + 18) + (sx + sw * 0.45 - (bx + 18)) * mf + math.sin(s * (3.5 + m * 0.6) + m * 2) * 18
    local my = (by - 14) + (sy + sh * 0.5 - (by - 14)) * mf + math.cos(s * (4.2 + m * 0.5) + m) * 12
    local wing = math.abs(math.sin(s * 18 + m * 3)) * 3.5
    lg.setColor(1, 0.95, 0.8, 0.7 * flk * k)
    lg.line(mx - wing, my - 1.5, mx, my, mx + wing, my - 1.5)
  end
  -- Silhouetted vintage cars parked facing the screen, dimming headlights as the movie starts.
  local head_a = clamp(1 - s / 4.5, 0.08, 1) * k
  for ci, cx in ipairs({148, 290, 478, 620}) do
    local cy = HZ - 4
    -- Speaker post beside each car.
    lg.setColor(0.18, 0.16, 0.26, 0.9 * k)
    lg.rectangle("fill", cx - 44, cy - 26, 3, 28)
    lg.rectangle("fill", cx - 47, cy - 30, 9, 6, 2, 2)
    -- Dimming headlight glow toward screen.
    if head_a > 0.02 then
      C.fx.glow(cx, cy - 20, 44, 18, 1, 0.92, 0.7, 0.22 * head_a)
    end
    -- Vintage car silhouette (rear view, wide fins).
    lg.setColor(0.05, 0.03, 0.1, 0.98 * k)
    lg.rectangle("fill", cx - 34, cy - 18, 68, 18, 5, 5)
    lg.polygon("fill", cx - 24, cy - 18, cx - 16, cy - 31, cx + 16, cy - 31, cx + 24, cy - 18)
    lg.setColor(0.18, 0.22, 0.36, 0.5 * flk * k)
    lg.polygon("fill", cx - 19, cy - 19, cx - 13, cy - 28, cx + 13, cy - 28, cx + 19, cy - 19)
    -- Warm red tail lights.
    lg.setColor(1, 0.18, 0.22, 0.75 * k)
    lg.rectangle("fill", cx - 31, cy - 14, 7, 4, 1, 1)
    lg.rectangle("fill", cx + 24, cy - 14, 7, 4, 1, 1)
  end
  lg.setLineWidth(1)
end

local ORDER = {"chase", "swarm", "stars", "fireflies", "aurora", "meteors", "city", "ufo", "digger", "dream", "drivein"}

-- ------------------------------------------------------------------ the night's timeline

-- The schedule of one night: scenes in a shuffled order (by the night's number), 3 to 5 minutes each,
-- 45 to 90 s of quiet sky between, from FIRST to REST.
local schedules = {}
local function schedule(night)
  if schedules[night] then return schedules[night] end
  local r = rng(night * 7919 + 17)
  local list = {}
  local t = FIRST
  local last
  local full = false
  -- (Until 2026-10-27 the inner loop's "no room" only left the deck, and the outer loop spun for ever: Home
  -- froze when a night's last gap was under a scene's length. Now no room ends the night's list; and a bound.)
  for _ = 1, 50 do
    if full or t >= REST - 120 then break end
    local deck = {}
    for i, n in ipairs(ORDER) do deck[i] = n end
    for i = #deck, 2, -1 do local j = math.floor(r(1, i + 0.999)) deck[i], deck[j] = deck[j], deck[i] end
    if deck[1] == last then deck[1], deck[#deck] = deck[#deck], deck[1] end
    for _, name in ipairs(deck) do
      local len = math.floor(r(180, 300))
      if t + len > REST - 30 then full = true break end
      list[#list + 1] = {name = name, t0 = t, len = len, seed = math.floor(r(1, 1e9))}
      t = t + len + math.floor(r(45, 90))
      last = name
    end
  end
  schedules[night] = list
  return list
end

function N.scene_at(nt)
  if only then return only end
  local night = math.floor(nt / CYCLE)
  local at = nt % CYCLE
  if at >= REST then return at >= DAWN and "dawn" or "rest" end
  for _, e in ipairs(schedule(night)) do
    if at >= e.t0 and at < e.t0 + e.len then return e.name, e end
  end
  return at < FIRST and "dusk" or "quiet"
end

-- The sky over the night: how dark, and a warm glow at the horizon at dusk and dawn.
local function sky(at)
  local dark, warm = 0.45, 0
  if at < DUSK then dark, warm = 0.15 + 0.3 * ease(at / DUSK), 1 - ease(at / DUSK) end
  if at >= REST and at < DAWN then dark = 0.45 + 0.4 * ease((at - REST) / 120) end
  if at >= DAWN then
    local u = (at - DAWN) / (CYCLE - DAWN)
    dark, warm = 0.85 - 0.75 * ease(u * 1.3), ease(u)
  end
  return dark, warm
end

local state, state_for = {}, nil
function N.draw(nt)
  local at = nt % CYCLE
  local dark, warm = sky(at)
  if only then dark, warm = 0.45, 0 end
  -- The warm horizon (dusk, dawn), then the dark of the night over everything.
  if warm > 0 then C.fx.glow(W / 2, HZ, 520, 260, 1, 0.45, 0.35, 0.35 * warm) end
  lg.setColor(0, 0, 0.02, dark)
  lg.rectangle("fill", 0, 0, W, H)
  -- The moon: up at dusk, across the sky, down by dawn.
  local u = clamp((at - 300) / (DAWN - 300), 0, 1)
  if only then u = 0.7 end
  if u > 0 and u < 1 then
    local mx, my = 60 + u * (W - 120), 560 - math.sin(u * math.pi) * 400
    C.fx.glow(mx, my, 90, 90, 0.8, 0.85, 1, 0.18)
    if not lg.getCanvas() then
      lg.stencil(function() lg.circle("fill", mx + 14, my - 8, 30, 40) end, "replace", 1)
      lg.setStencilTest("equal", 0)
      lg.setColor(0.95, 0.93, 0.8, 0.9)
      lg.circle("fill", mx, my, 34, 40)
      lg.setStencilTest()
    else
      -- Canvas-safe geometric crescent (zero opaque disc, no stencil buffer required).
      local R, r, dx, dy = 34, 30, 14, -8
      local d = math.sqrt(dx * dx + dy * dy)
      local base = math.atan2(dy, dx)
      local a1 = math.acos(clamp((R * R + d * d - r * r) / (2 * R * d), -1, 1))
      local a2 = math.acos(clamp((r * r + d * d - R * R) / (2 * r * d), -1, 1))
      local segs = 24
      lg.setColor(0.95, 0.93, 0.8, 0.9)
      for i = 0, segs - 1 do
        local f0, f1 = i / segs, (i + 1) / segs
        local o0 = base + a1 + (2 * math.pi - 2 * a1) * f0
        local o1 = base + a1 + (2 * math.pi - 2 * a1) * f1
        local n0 = base + math.pi - a2 + (2 * a2) * f0
        local n1 = base + math.pi - a2 + (2 * a2) * f1
        lg.polygon("fill",
          mx + math.cos(o0) * R, my + math.sin(o0) * R,
          mx + math.cos(o1) * R, my + math.sin(o1) * R,
          mx + dx + math.cos(n1) * r, my + dy + math.sin(n1) * r,
          mx + dx + math.cos(n0) * r, my + dy + math.sin(n0) * r)
      end
    end
  end
  -- The scene.
  local name, e = N.scene_at(nt)
  local s, len, seed
  if only then s, len, seed = nt, math.huge, 1
  elseif e then s, len, seed = at - e.t0, e.len, e.seed end
  if e or only then
    local key = only and "only" or (math.floor(nt / CYCLE) .. ":" .. e.t0)
    if state_for ~= key then
      state, state_for = {r = rng(seed)}, key
      state.first = math.floor(state.r(0, 6))
      if C.log then C.log("night scene " .. name) end
    end
    local k = math.min(1, s / 4, (len - s) / 4)
    scenes[name](state, s, clamp(k, 0, 1))
  elseif name == "rest" or name == "dawn" then
    -- The rest stretch: a few fireflies only.
    if state_for ~= "rest" then state, state_for = {r = rng(5)}, "rest" if C.log then C.log("night " .. name) end end
    local k = name == "rest" and 0.6 or clamp(1 - (at - DAWN) / 300, 0, 1) * 0.6
    fireflies(state, at - REST, k, 14, false)
  end
end

function N.load(ctx)
  C = ctx
  W, H, HZ = ctx.W, ctx.H, ctx.HORIZON
  SP.alien = {
    sprite({"..X.....X..", "...X...X...", "..XXXXXXX..", ".XX.XXX.XX.", "XXXXXXXXXXX", "X.XXXXXXX.X", "X.X.....X.X", "...XX.XX..."}),
    sprite({"..X.....X..", "X..X...X..X", "X.XXXXXXX.X", "XXX.XXX.XXX", "XXXXXXXXXXX", ".XXXXXXXXX.", "..X.....X..", ".X.......X."}),
  }
  SP.ship = sprite({"....X....", "....X....", "...XXX...", "..XXXXX..", ".XX.X.XX.", "XXXXXXXXX", "XX.XXX.XX", "X...X...X", "........."})
end

-- One scene only, over and over (the SHOWS section's tiles; nil: the whole night again).
function N.set_only(name)
  only = name
  state_for = nil
end

N.CYCLE = CYCLE
N.ORDER = ORDER
N.DAWN = DAWN
-- The night's segments for the SHOWS section: {start (seconds into the night), title, scene for set_only}
N.SEGMENTS = {{0, "DUSK"}}
local TITLES = {chase = "THE CHASE", swarm = "THE SWARM", stars = "STARFIELD", fireflies = "FIREFLIES", aurora = "AURORA",
                meteors = "METEOR SHOWER", city = "NEON CITY", ufo = "CLOSE ENCOUNTER", digger = "THE DIGGER", dream = "SWEET DREAMS",
                drivein = "THE DRIVE-IN"}
for _, name in ipairs(ORDER) do N.SEGMENTS[#N.SEGMENTS + 1] = {0, TITLES[name], name} end
N.SEGMENTS[#N.SEGMENTS + 1] = {DAWN, "DAWN"}
return N
