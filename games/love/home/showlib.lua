-- What Home's idle shows share (texas.lua, longhorns.lua, thanksgiving.lua, christmas.lua): a show's pictures
-- made when it starts and given back when it stops (GPU memory is what this cabinet runs out of), skies,
-- particles (sparks, fireworks, smoke, confetti) drawn in one batch each, a waving cloth flag, captions in neon,
-- a news-style ticker, pixel sprites, and a clock with at(T).
--
--   local L = require("showlib")
--   local G = L.new(ctx)          per show: G:begin(seed) at its start, G:finish() at its stop
--   G:canvas(w, h, painter)       a picture painted once (released at finish)
--   G:sprite(rows, palette)       a pixel sprite: rows of characters, palette {char = {r, g, b}}
--   G:cloth(painter, tw, th)      a waving flag: :draw(x, y, w, h, t, wind, light)
--   G:spark(...) G:firework(x, y, big, colours) G:rocket(x, ty, opts) G:puff(...) G:confetti(n, colours)
--   G:step(dt)                    the clock and the particles; G:at(T) is true once, when the clock passes T
--   G:draw_back() / G:draw_front()  the particles behind the scenery (fireworks) and in front (smoke, confetti)
--   G:caption(text, y, px, colour, alpha)  (painted labels: G:label(text, px, colour) to paint ahead)
--   G:ticker(label, colour, text)
local lg = love.graphics
local ffi = require("ffi")
local L = {}

local sin, cos, floor, min, max, abs, sqrt, pi = math.sin, math.cos, math.floor, math.min, math.max, math.abs, math.sqrt, math.pi
function L.clamp(x, a, b) return x < a and a or x > b and b or x end
function L.ease(x) x = L.clamp(x, 0, 1) return x * x * (3 - 2 * x) end
function L.lerp(a, b, k) return a + (b - a) * k end
function L.mix(p, q, k) return {p[1] + (q[1] - p[1]) * k, p[2] + (q[2] - p[2]) * k, p[3] + (q[3] - p[3]) * k} end
function L.hex(c) return {floor(c / 65536) % 256 / 255, floor(c / 256) % 256 / 255, c % 256 / 255} end
-- 0 outside [a, b], 1 inside, easing over f seconds at each end
function L.window(t, a, b, f)
  f = f or 1
  return L.clamp(min((t - a) / f, (b - t) / f), 0, 1)
end

-- A five-pointed star, filled (concave: the inner pentagon and five tips).
function L.star(x, y, r, rot)
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

local G = {}
G.__index = G

function L.new(ctx)
  return setmetatable({C = ctx, W = ctx.W or 768, H = ctx.H or 1024, made = {}, labels = {}}, G)
end

-- ------------------------------------------------------------------ pictures
function G:track(o) self.made[#self.made + 1] = o return o end

function G:canvas(w, h, painter)
  local cv = self:track(lg.newCanvas(w, h))
  lg.push("all")
  lg.origin()
  lg.setCanvas(cv)
  lg.clear(0, 0, 0, 0)
  painter(w, h)
  lg.setCanvas()
  lg.pop()
  cv:setFilter("linear", "linear")
  return cv
end

function G:sprite(rows, palette)
  local w, h = #rows[1], #rows
  local d = love.image.newImageData(w, h)
  for y = 1, h do
    for x = 1, w do
      local c = palette[rows[y]:sub(x, x)]
      if c then d:setPixel(x - 1, y - 1, c[1], c[2], c[3], c[4] or 1) end
    end
  end
  local img = self:track(lg.newImage(d))
  img:setFilter("nearest", "nearest")
  return img
end

-- The shared pictures: a soft dot (sparks, smoke), a white pixel (debris, confetti), the sky's mesh.
function G:begin(seed)
  self.R = love.math.newRandomGenerator(seed or os.time())
  self.t, self.prev = 0, -1
  self.glow, self.debris, self.smoke, self.rockets, self.later = {}, {}, {}, {}, {}
  local n = 16
  local d = love.image.newImageData(n, n)
  d:mapPixel(function(x, y)
    local dx, dy = (x + 0.5) / n * 2 - 1, (y + 0.5) / n * 2 - 1
    local v = max(0, 1 - sqrt(dx * dx + dy * dy))
    return 1, 1, 1, v ^ 1.5
  end)
  self.dot = self:track(lg.newImage(d))
  local p = love.image.newImageData(1, 1)
  p:setPixel(0, 0, 1, 1, 1, 1)
  self.px = self:track(lg.newImage(p))
  self.glowb = self:track(lg.newSpriteBatch(self.dot, 1200, "stream"))
  self.smokeb = self:track(lg.newSpriteBatch(self.dot, 600, "stream"))
  self.pixb = self:track(lg.newSpriteBatch(self.px, 900, "stream"))
  self.skym = self:track(lg.newMesh({{0, 0, 0, 0}, {1, 0, 1, 0}, {1, 1, 1, 1}, {0, 1, 0, 1}}, "fan", "dynamic"))
  self.labels = {}
  self.used, self.sweep = {}, 0
end

-- A caption or plate drawn now: remembered, so a label not seen for 20 s can go (G:step).
function G:use(text, px, colour)
  self.used[text .. "|" .. px .. "|" .. colour] = {self.t, text, px, colour}
end

function G:finish()
  for _, o in ipairs(self.made) do o:release() end
  self.made = {}
  self.glow, self.debris, self.smoke, self.rockets = {}, {}, {}, {}
end

-- A painted picture (tools/show_art.py: ETC1, 0.5 bytes a pixel on the Mali) from the SD card, or nil (no card,
-- not painted yet: the show draws its scene live instead). Load them in start(), behind Home's curtain; they go
-- with the show (finish).
local ART = os.getenv("HOME_SHOW_ART") or "/mnt/sdcard/partycade/art"
function G:art(show, name)
  local f = io.open(ART .. "/" .. show .. "/" .. name .. ".pkm", "rb")
  if not f then return nil end
  local bytes = f:read("*a")
  f:close()
  -- (each copy let go as soon as the next is made: three copies of nine pictures at once, ~14 MB, helped run the
  -- cabinet out of memory)
  local ok, img = pcall(function()
    local fd = love.filesystem.newFileData(bytes, name .. ".pkm")
    bytes = nil
    local cd = love.image.newCompressedData(fd)
    fd:release()
    local im = lg.newImage(cd)
    cd:release()
    return im
  end)
  bytes = nil
  collectgarbage("step", 400)
  if not ok then
    if self.C.log then self.C.log("art " .. show .. "/" .. name .. ": " .. tostring(img)) end
    return nil
  end
  img:setFilter("linear", "linear")
  return self:track(img)
end

-- A label to paint ahead of its first use (two a frame, in step: a canvas switch mid-frame costs). when: the
-- show time it is first needed (painted 25 s ahead, so a long show doesn't hold them all at once); nil: now.
function G:label(text, px, colour, when)
  self.labels[#self.labels + 1] = {text, px, colour, when}
end

-- ------------------------------------------------------------------ the clock
function G:at(T) return self.prev < T and self.t >= T end

function G:later_sfx(t, name) self.later[#self.later + 1] = {t, name} end

function G:step(dt)
  local n = 0
  for i = #self.labels, 1, -1 do
    local l = self.labels[i]
    local when = l[4] or -1e9
    if when + 120 < self.t then
      table.remove(self.labels, i)                       -- (long past: started further on)
    elseif when <= self.t + 25 and n < 2 then
      table.remove(self.labels, i)
      self.C.neon_img(l[1], l[2], l[3], 1)
      self:use(l[1], l[2], l[3])
      if l[4] then self.used[l[1] .. "|" .. l[2] .. "|" .. l[3]][1] = max(self.t, l[4]) end
      n = n + 1
    end
  end
  -- labels not drawn for 20 s: released (painted again if they come back), so a long show holds only its
  -- current segment's
  self.sweep = self.sweep - dt
  if self.sweep <= 0 and self.C.neon_release then
    self.sweep = 5
    for k, u in pairs(self.used) do
      if self.t - u[1] > 20 then
        self.C.neon_release(u[2], u[3], u[4], 1)
        self.used[k] = nil
      end
    end
  end
  self.prev = self.t
  self.t = self.t + dt
  self.dt = dt
  for i = #self.rockets, 1, -1 do
    local r = self.rockets[i]
    r.y = r.y - (r.speed or 520) * dt
    r.x = r.x + (r.vx or 0) * dt
    self:spark(r.x, r.y + 6, (self.R:random() - 0.5) * 20, 60, 0.35, {1, 0.8, 0.5}, 3, 0, true)
    if r.y <= r.ty then
      if r.burst then r.burst(r.x, r.y) else self:firework(r.x, r.y, r.big, r.colours) end
      table.remove(self.rockets, i)
    end
  end
  for _, list in ipairs({self.glow, self.debris, self.smoke}) do
    local j = 1
    for i = 1, #list do
      local p = list[i]
      p.life = p.life - dt
      if p.life > 0 then
        if p.tx then
          local k = min(1, dt * 5)
          p.x, p.y = p.x + (p.tx - p.x) * k, p.y + (p.ty - p.y) * k
        else
          p.vy = p.vy + (p.g or 0) * dt
          if p.drag then p.vx = p.vx * (1 - p.drag * dt) end
          p.x, p.y = p.x + p.vx * dt, p.y + p.vy * dt
          if p.spin then p.rot = (p.rot or 0) + p.spin * dt end
        end
        list[j] = p
        j = j + 1
      end
    end
    for i = j, #list do list[i] = nil end
  end
  for i = #self.later, 1, -1 do
    local l = self.later[i]
    if self.t >= l[1] then self.C.sfx(l[2]) table.remove(self.later, i) end
  end
end

-- ------------------------------------------------------------------ particles
-- add: additive glow (fireworks, sparks, lights); else a solid square (debris)
function G:spark(x, y, vx, vy, life, c, size, grav, add)
  local list = add and self.glow or self.debris
  if #list > (add and 1000 or 600) then return end
  list[#list + 1] = {x = x, y = y, vx = vx, vy = vy, life = life, max = life, c = c, size = size or 3, g = grav or 200,
                     drag = 0.8}
end

local FIREWORK = {{1, 0.25, 0.3}, {1, 1, 1}, {0.35, 0.5, 1}, {1, 0.85, 0.35}, {1, 0.4, 0.8}}
function G:firework(x, y, big, colours)
  local R = self.R
  colours = colours or FIREWORK
  local c, c2 = colours[R:random(1, #colours)], colours[R:random(1, #colours)]
  local n = big and 90 or 55
  local sp = big and 260 or 190
  for i = 1, n do
    local a = i / n * 2 * pi + R:random() * 0.1
    local v = sp * (0.6 + R:random() * 0.45)
    self:spark(x, y, cos(a) * v, sin(a) * v, 1.4 + R:random() * 0.8, i % 3 == 0 and c2 or c, big and 9 or 7, 90, true)
  end
  self:spark(x, y, 0, 0, 0.25, {1, 1, 1}, 60, 0, true)
  self.C.sfx("pop")
  if R:random() < 0.6 then self:later_sfx(self.t + 0.35, "crackle") end
end

-- A rocket from the ground (ground y opts.from) to ty; opts: big, colours, burst(x, y)
function G:rocket(x, ty, opts)
  opts = opts or {}
  self.rockets[#self.rockets + 1] = {x = x, y = opts.from or 830, ty = ty, vx = (self.R:random() - 0.5) * 40,
                                     big = opts.big, colours = opts.colours, burst = opts.burst}
end

-- Smoke or a cloud puff: rises, grows, fades
function G:puff(x, y, c, rise, drift, life, size, alpha)
  if #self.smoke > 500 then return end
  self.smoke[#self.smoke + 1] = {x = x, y = y, vx = drift or 0, vy = -(rise or 40), life = life or 2.2, max = life or 2.2,
                                 c = c or {0.8, 0.8, 0.82}, size = size or 8, a = alpha or 0.45, g = 0}
end

-- Confetti from the top: n pieces (a frame), in these colours
function G:confetti(n, colours)
  local R = self.R
  for _ = 1, n do
    if #self.debris > 450 then return end
    local c = colours[R:random(1, #colours)]
    self.debris[#self.debris + 1] = {x = R:random() * self.W, y = -10, vx = (R:random() - 0.5) * 60, vy = 80 + R:random() * 90,
                                     life = 8, max = 8, c = c, size = 6 + R:random() * 6, g = 0, rot = R:random() * 6,
                                     spin = (R:random() - 0.5) * 10, confetti = true}
  end
end

function G:draw_back()
  local b = self.glowb
  b:clear()
  for _, p in ipairs(self.glow) do
    local k = p.life / p.max
    b:setColor(p.c[1], p.c[2], p.c[3], min(1, k * 1.6) * (p.a or 1))
    local s = p.size / 8 * (0.6 + 0.4 * k)
    b:add(p.x, p.y, 0, s, s, 8, 8)
  end
  lg.setBlendMode("add")
  lg.setColor(1, 1, 1, 1)
  lg.draw(b)
  lg.setBlendMode("alpha")
end

function G:draw_front()
  local s = self.smokeb
  s:clear()
  for _, p in ipairs(self.smoke) do
    local k = p.life / p.max
    s:setColor(p.c[1], p.c[2], p.c[3], k * p.a)
    local sc = (p.size + (1 - k) * p.size * 2) / 8
    s:add(p.x, p.y, 0, sc, sc, 8, 8)
  end
  lg.setColor(1, 1, 1, 1)
  lg.draw(s)
  local b = self.pixb
  b:clear()
  for _, p in ipairs(self.debris) do
    b:setColor(p.c[1], p.c[2], p.c[3], min(1, p.life / p.max * 3))
    if p.confetti then
      b:add(p.x, p.y, p.rot, p.size, p.size * 0.5 * abs(sin(p.rot * 2)) + 1, 0.5, 0.5)
    else
      b:add(p.x, p.y, 0, p.size, p.size)
    end
  end
  lg.draw(b)
end

-- ------------------------------------------------------------------ skies and text
-- A vertical gradient from top colour to bottom colour over x0..x1, y0..y1.
function G:gradient(x0, y0, x1, y1, top, bot, a)
  local m = self.skym
  a = a or 1
  m:setVertex(1, x0, y0, 0, 0, top[1], top[2], top[3], a)
  m:setVertex(2, x1, y0, 1, 0, top[1], top[2], top[3], a)
  m:setVertex(3, x1, y1, 1, 1, bot[1], bot[2], bot[3], a)
  m:setVertex(4, x0, y1, 0, 1, bot[1], bot[2], bot[3], a)
  lg.setColor(1, 1, 1, 1)
  lg.draw(m)
end

-- A sky from keyframes {t, top, horizon}: the colours at time t
function L.sky_at(keys, t)
  for i = 1, #keys - 1 do
    local a, b = keys[i], keys[i + 1]
    if t >= a[1] and t < b[1] then
      local k = L.ease((t - a[1]) / (b[1] - a[1]))
      return L.mix(a[2], b[2], k), L.mix(a[3], b[3], k)
    end
  end
  local l = keys[#keys]
  return l[2], l[3]
end

function G:caption(text, y, px, colour, alpha, sc)
  if alpha <= 0 then return end
  -- (a caption scaled every frame is resampled every frame, and soft: a pulse in size becomes one in brightness)
  if sc and sc ~= 1 then
    alpha = alpha * math.min(1, 0.82 + math.abs(sc - 1) * 3)
    sc = nil
  end
  self:use(text, px, colour)
  self.C.neon_draw(text, 0, y, px, colour, 1, "center", self.W, alpha, sc)
end

-- A caption on a dark plate (legible over a bright daytime sky).
function G:plate(text, y, px, colour, alpha)
  if alpha <= 0 then return end
  local sc = math.min(1, (self.W - 60) / (self.C.font(px):getWidth(text) + px * 1.2))
  local w = (self.C.font(px):getWidth(text) + px * 1.2) * sc
  local h = px * 1.55 * sc
  lg.setColor(0.03, 0.02, 0.08, 0.55 * alpha)
  lg.rectangle("fill", (self.W - w) / 2, y - px * 0.18 * sc, w, h, h / 2, h / 2, 12)
  self:use(text, px, colour)
  self.C.neon_draw(text, 0, y, px, colour, 1, "center", self.W, alpha, sc)
end

-- Plain text with a soft shadow (smaller writing: place names, credits).
function G:text(s, x, y, px, c, a, align, w)
  local f = self.C.font(px)
  lg.setFont(f)
  x, y = floor(x + 0.5), floor(y + 0.5)                   -- (whole pixels: crisp)
  lg.setColor(0, 0, 0, 0.55 * a)
  lg.printf(s, x + 2, y + 2, w or self.W, align or "center")
  lg.setColor(c[1], c[2], c[3], a)
  lg.printf(s, x, y, w or self.W, align or "center")
end

-- The crawl at the bottom: a label box and the text moving left.
function G:ticker(label, colour, text)
  local C, W, H = self.C, self.W, self.H
  local y = H - 62
  text = text .. "     "
  lg.setColor(0.05, 0.06, 0.18, 0.88)
  lg.rectangle("fill", 0, y, W, 50)
  local f = C.font(22)
  lg.setFont(f)
  local lw = f:getWidth(label) + 28
  self.tick_x = (self.tick_x or 0) - 110 * (self.dt or 0.016)
  local tw = f:getWidth(text)
  if self.tick_x < -tw then self.tick_x = self.tick_x + tw end
  lg.setColor(1, 1, 1, 0.95)
  lg.print(text, lw + 10 + self.tick_x, y + 13)
  lg.print(text, lw + 10 + self.tick_x + tw, y + 13)
  lg.setColor(colour[1], colour[2], colour[3], 1)
  lg.rectangle("fill", 0, y, lw, 50)
  lg.setColor(1, 1, 1, 1)
  lg.print(label, 14, y + 13)
end

-- ------------------------------------------------------------------ a waving flag
-- painter(w, h) paints the flag into its texture once. :draw(x, y, w, h, t, wind, light) drapes it from a pole
-- at x (its top-left corner at x, y), waving: wind 0 (hanging) to 1 (straight out).
local Cloth = {}
Cloth.__index = Cloth
pcall(ffi.cdef, "typedef struct { float x, y, u, v; uint8_t r, g, b, a; } show_vert;")

function G:cloth(painter, tw, th)
  local c = setmetatable({nu = 30, nv = 14}, Cloth)
  c.tex = self:canvas(tw, th, painter)
  local n = (c.nu + 1) * (c.nv + 1)
  c.data = self:track(love.data.newByteData(n * ffi.sizeof("show_vert")))
  c.vp = ffi.cast("show_vert*", c.data:getFFIPointer())
  c.mesh = self:track(lg.newMesh(n, "triangles", "stream"))
  local map = {}
  for j = 0, c.nv - 1 do
    for i = 0, c.nu - 1 do
      local a = j * (c.nu + 1) + i + 1
      local b, d, e = a + 1, a + c.nu + 1, a + c.nu + 2
      map[#map + 1] = a map[#map + 1] = b map[#map + 1] = d
      map[#map + 1] = b map[#map + 1] = e map[#map + 1] = d
    end
  end
  c.mesh:setVertexMap(map)
  c.mesh:setTexture(c.tex)
  return c
end

function Cloth:draw(X, Y, FW, FH, t, wind, light)
  light = light or {1, 1, 1}
  local i0 = 0
  local droop = 1 - wind
  for j = 0, self.nv do
    local v = j / self.nv
    for i = 0, self.nu do
      local u = i / self.nu
      local amp = (FW / 18) * wind * u ^ 1.15 + 3 * u
      local ph = u * 9.0 - t * (3.0 + 2.4 * wind) + v * 0.9
      local z = amp * (sin(ph) + 0.28 * sin(2.3 * ph + 1.1 + v * 2.2 + t * 0.9))
      local x = X + u * FW * (1 - 0.25 * droop * u) + z * 0.04
      local y = Y + v * FH * (1 - 0.04 * wind) + z * 0.5 + droop * u * u * FH * 0.5
      local k = min(1, amp / 14)
      local s = L.clamp(0.80 + 0.20 * cos(ph + 0.9) * k, 0.4, 1)
      local q = self.vp[i0]
      q.x, q.y, q.u, q.v = x, y, u, v
      q.r = min(255, floor(255 * s * light[1]))
      q.g = min(255, floor(255 * s * light[2]))
      q.b = min(255, floor(255 * s * light[3]))
      q.a = 255
      i0 = i0 + 1
    end
  end
  self.mesh:setVertices(self.data)
  lg.setColor(1, 1, 1, 1)
  lg.draw(self.mesh)
end

-- A flag pole with its gold ball, from the ground up to y.
function L.pole(x, top, ground)
  lg.setColor(0.78, 0.78, 0.82, 1)
  lg.rectangle("fill", x - 5, top, 10, ground - top)
  lg.setColor(1, 1, 1, 0.35)
  lg.rectangle("fill", x - 3, top, 2, ground - top)
  lg.setColor(1, 0.82, 0.3, 1)
  lg.circle("fill", x, top - 6, 11, 20)
end

-- The Lone Star flag, painted into a w x h texture (blue hoist with the white star, white over red).
function L.paint_texas(w, h)
  lg.setColor(0.0, 0.16, 0.41, 1)
  lg.rectangle("fill", 0, 0, w / 3, h)
  lg.setColor(0.97, 0.97, 0.95, 1)
  lg.rectangle("fill", w / 3, 0, w * 2 / 3, h / 2)
  lg.setColor(0.75, 0.04, 0.19, 1)
  lg.rectangle("fill", w / 3, h / 2, w * 2 / 3, h / 2)
  lg.setColor(0.97, 0.97, 0.95, 1)
  L.star(w / 6, h / 2, h * 0.25)
  lg.setColor(0, 0, 0, 0.035)
  for x = 0, w, 4 do lg.rectangle("fill", x, 0, 1, h) end
end

-- A longhorn steer, side view, walking (facing right); coat {base, patch}.
function L.steer(x, y, s, step, coat, horn)
  lg.push()
  lg.translate(x, y)
  lg.scale(s, s)
  lg.setColor(coat[1][1], coat[1][2], coat[1][3], 1)
  for i, lx in ipairs({-26, -14, 16, 28}) do
    local sw = sin(step + (i % 2) * pi) * 6
    lg.rectangle("fill", lx + sw * 0.5 - 3, 6, 6, 30)
  end
  lg.ellipse("fill", 0, 0, 40, 18, 20)
  if coat[2] then
    lg.setColor(coat[2][1], coat[2][2], coat[2][3], 1)
    lg.ellipse("fill", -12, -2, 12, 9, 12)
    lg.ellipse("fill", 14, 6, 9, 7, 12)
  end
  lg.setColor(coat[1][1], coat[1][2], coat[1][3], 1)
  lg.polygon("fill", 30, -12, 48, -10, 54, 8, 40, 8)
  lg.ellipse("fill", 52, 4, 9, 12, 12)
  lg.setColor(0.15, 0.1, 0.08, 1)
  lg.circle("fill", 55, 0, 1.8, 6)
  -- the horns: a long sweep out to each side (one toward us, one away), tips up
  lg.setColor(horn[1], horn[2], horn[3], 1)
  lg.setLineWidth(4)
  lg.line(48, -8, 34, -14, 14, -18, 0, -28, -4, -34)
  lg.line(50, -8, 62, -16, 82, -20, 96, -30, 100, -36)
  lg.setColor(0.25, 0.2, 0.15, 1)
  lg.line(-40, -2, -48, 14)
  lg.pop()
end

-- A live oak: a short trunk, a wide spreading crown.
function L.live_oak(x, y, s, sway)
  lg.setColor(0.28, 0.2, 0.14, 1)
  lg.polygon("fill", x - 8 * s, y, x + 8 * s, y, x + 5 * s, y - 40 * s, x - 5 * s, y - 40 * s)
  lg.setLineWidth(5 * s)
  lg.line(x, y - 34 * s, x - 34 * s, y - 56 * s)
  lg.line(x, y - 34 * s, x + 38 * s, y - 52 * s)
  for i, c in ipairs({{-46, -62, 30}, {-14, -74, 34}, {24, -70, 32}, {52, -58, 26}, {0, -56, 30}, {-30, -50, 22}, {34, -48, 22}}) do
    local g = 0.28 + (i % 3) * 0.04
    lg.setColor(0.12, g, 0.12, 1)
    lg.circle("fill", x + (c[1] + sin(sway + i) * 1.5) * s, y + c[2] * s, c[3] * s, 20)
  end
end

-- The longhorn: a steer's head with its sweep of horns (our own drawing), centred on x, y.
function L.longhorn_head(x, y, s, c, a)
  lg.setColor(c[1], c[2], c[3], a)
  local L, R = {}, {}
  -- the horns: a long shallow curve each side, tips turned up
  local horn = {{0, 0}, {18, -6}, {40, -9}, {62, -10}, {80, -14}, {92, -24}, {96, -34}, {92, -30}, {80, -20},
                {62, -2}, {40, 4}, {18, 8}, {0, 10}}
  for _, p in ipairs(horn) do
    L[#L + 1] = x - 22 * s - p[1] * s L[#L + 1] = y - 18 * s + p[2] * s
    R[#R + 1] = x + 22 * s + p[1] * s R[#R + 1] = y - 18 * s + p[2] * s
  end
  local function fill_strip(pts)
    local n = #pts / 2
    for i = 1, n / 2 - 1 do
      local a1, b1 = i, n - i + 1
      local a2, b2 = i + 1, n - i
      lg.polygon("fill", pts[a1 * 2 - 1], pts[a1 * 2], pts[a2 * 2 - 1], pts[a2 * 2], pts[b2 * 2 - 1], pts[b2 * 2],
                 pts[b1 * 2 - 1], pts[b1 * 2])
    end
  end
  fill_strip(L)
  fill_strip(R)
  -- the head: wide brow, long face to the muzzle
  lg.polygon("fill", x - 30 * s, y - 26 * s, x + 30 * s, y - 26 * s, x + 24 * s, y + 6 * s, x + 14 * s, y + 40 * s,
             x - 14 * s, y + 40 * s, x - 24 * s, y + 6 * s)
  lg.ellipse("fill", x, y + 40 * s, 16 * s, 10 * s, 16)
  lg.polygon("fill", x - 30 * s, y - 20 * s, x - 46 * s, y - 8 * s, x - 26 * s, y - 2 * s)
  lg.polygon("fill", x + 30 * s, y - 20 * s, x + 46 * s, y - 8 * s, x + 26 * s, y - 2 * s)
end

return L
