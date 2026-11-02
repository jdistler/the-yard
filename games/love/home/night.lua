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
  -- The ship follows the diver and fires.
  st.shipx = st.shipx or W / 2
  local want = dx or W / 2 + math.sin(s * 0.4) * 200
  st.shipx = st.shipx + (want - st.shipx) * 0.02
  lg.setColor(0.9, 0.95, 1, k)
  lg.draw(SP.ship, st.shipx, HZ - 26, 0, 3.2, 3.2, 4.5, 4.5)
  local shot = (s * 0.6) % 1
  if dx and shot < 0.5 then
    local by = HZ - 50 - shot * 2 * (HZ - 50 - (dy or 300))
    lg.setColor(1, 1, 0.6, k)
    lg.rectangle("fill", st.shipx - 1.5, by, 3, 14)
  end
end

-- 3. Constellations: stars come out, lines join them into a shape, it glows, it fades; the next one.
local SHAPES = {
  ghost = {{0, .5}, {.1, .2}, {.3, .05}, {.5, 0}, {.7, .05}, {.9, .2}, {1, .5}, {1, 1}, {.83, .85}, {.67, 1}, {.5, .85},
           {.33, 1}, {.17, .85}, {0, 1}, {0, .5}},
  cherry = {{.25, .7}, {.4, .3}, {.6, .05}, {.8, .35}, {.75, .75}, nil, {.6, .05}, {.45, .2}},
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

-- 5. An aurora: ribbons of light rippling across the sky.
local ribbon = nil
scenes.aurora = function(st, s, k)
  ribbon = ribbon or lg.newMesh(2 * 49, "strip", "stream")
  local cols = {{0.3, 1, 0.6}, {0.4, 0.8, 1}, {0.8, 0.4, 1}}
  lg.setBlendMode("add")
  for r = 1, 3 do
    local v = {}
    local base = 180 + r * 55
    local c = cols[r]
    for i = 0, 48 do
      local x = i / 48 * W
      local y = base + math.sin(x * 0.008 + s * 0.25 * r + r) * 45 + math.sin(x * 0.021 - s * 0.4) * 18
      local a = (0.18 + 0.12 * math.sin(x * 0.01 + s * 0.6 + r)) * k
      v[#v + 1] = {x, y - 110, 0, 0, c[1], c[2], c[3], 0}
      v[#v + 1] = {x, y, 0, 0, c[1], c[2], c[3], a}
    end
    ribbon:setVertices(v)
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
  local rise = ease(s / 10) * k
  for _, b in ipairs(st.b) do
    local top = HZ - b.h * rise
    lg.setColor(0.04, 0.02, 0.09, 0.95 * k)
    lg.rectangle("fill", b.x, top, b.w, HZ - top)
    local edge = b.hue < 0.5 and {1, 0.3, 0.85} or {0.3, 0.9, 1}
    lg.setColor(edge[1], edge[2], edge[3], 0.7 * k)
    lg.setLineWidth(2)
    lg.line(b.x, HZ, b.x, top, b.x + b.w, top, b.x + b.w, HZ)
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
  lg.print("STARLIGHT", bx - 290, by - 10)
end

-- 8. A UFO: it hums across, stops over a wandering ghost, beams it up, and goes.
scenes.ufo = function(st, s, k)
  local per = 30
  local t = s % per
  local gx = W * 0.55 + math.sin(math.floor(s / per) * 2.1) * 180
  local ux, uy
  if t < 10 then ux, uy = -120 + (gx + 120) * ease(t / 10), 300
  elseif t < 22 then ux, uy = gx, 300 + math.sin(t * 2) * 3
  else ux, uy = gx + (W + 160 - gx) * ease((t - 22) / 8), 300 - (t - 22) * 10 end
  -- The ghost: wanders on the horizon, then floats up in the beam.
  local lift = t < 13 and 0 or t < 21 and ease((t - 13) / 8) or 1
  if lift < 1 then
    local gy = HZ - 22 - lift * (HZ - 22 - uy - 20)
    local wob = t < 12 and math.sin(t * 2) * 30 or 0
    C.fx.ghost(gx + wob, gy, 18, {1, 0.55, 0.85}, 1, s, false, false, k)
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
      p[#p + 1] = {x, y}
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
    local f = math.min(1, left / seg)
    hx, hy = a[1] + (b[1] - a[1]) * f, a[2] + (b[2] - a[2]) * f
    if b[1] ~= a[1] then hdir = b[1] > a[1] and 1 or -1 end
    pts[#pts + 1], pts[#pts + 2] = hx, hy
    left = left - seg
  end
  if #pts >= 4 then
    lg.setLineJoin("bevel")
    lg.setLineWidth(30)
    lg.setColor(0.35, 0.15, 0.08, 0.9 * k)
    lg.line(pts)
    lg.setLineWidth(22)
    lg.setColor(0.02, 0.0, 0.04, k)
    lg.line(pts)
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
local function icon(name, x, y, a)
  if name == "cherry" then
    lg.setColor(0.3, 0.8, 0.3, a)
    lg.setLineWidth(2)
    lg.line(x - 6, y + 2, x + 2, y - 12, x + 8, y + 4)
    lg.setColor(1, 0.2, 0.25, a)
    lg.circle("fill", x - 7, y + 5, 7, 12)
    lg.circle("fill", x + 8, y + 7, 7, 12)
  elseif name == "ghost" then
    C.fx.ghost(x, y, 11, {0.3, 0.9, 1}, 1, love.timer.getTime(), false, false, a)
  elseif name == "star" then
    lg.setColor(1, 0.9, 0.3, a)
    local p = {}
    for i = 0, 9 do
      local r = i % 2 == 0 and 12 or 5
      local ang = -math.pi / 2 + i * math.pi / 5
      p[#p + 1], p[#p + 2] = x + math.cos(ang) * r, y + math.sin(ang) * r
    end
    lg.polygon("fill", p)
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
      icon(name, x, y, a)
    end
  end
end

local ORDER = {"chase", "swarm", "stars", "fireflies", "aurora", "meteors", "city", "ufo", "digger", "dream"}

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
    lg.setColor(0.95, 0.93, 0.8, 0.9)
    lg.circle("fill", mx, my, 34, 40)
    lg.setColor(0.07, 0.03, 0.14, 1)
    lg.circle("fill", mx + 14, my - 8, 30, 40)
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
                meteors = "METEOR SHOWER", city = "NEON CITY", ufo = "CLOSE ENCOUNTER", digger = "THE DIGGER", dream = "SWEET DREAMS"}
for _, name in ipairs(ORDER) do N.SEGMENTS[#N.SEGMENTS + 1] = {0, TITLES[name], name} end
N.SEGMENTS[#N.SEGMENTS + 1] = {DAWN, "DAWN"}
return N
