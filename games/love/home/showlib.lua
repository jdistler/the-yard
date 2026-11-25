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
--   L.shot(lt, keys) G:look(x, y, z) G:unlook()   the camera: pushes, pans, cuts inside a scene
--   L.ghost(...) L.pac(...) L.hop(...) G:say(...)  the cast, big, with eyes that look and moods; speech bubbles
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
  -- (the trace: the cast drawn with fx's own ghost and chomper, as Valentine's and Easter do, counted too)
  local fx = ctx.fx
  if ctx.trace and fx and not fx.traced then
    fx.traced = true
    local g, c = fx.ghost, fx.chomper
    if g then fx.ghost = function(x, y, r, ...) if L.tracing then L.note_cast(x, y, r) end return g(x, y, r, ...) end end
    if c then fx.chomper = function(x, y, r, ...) if L.tracing then L.note_cast(x, y, r) end return c(x, y, r, ...) end end
  end
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
  self.gen = (self.gen or 0) + 1                  -- (pictures still on their way from a show before: not wanted)
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
  self.gen = (self.gen or 0) + 1
  for _, o in ipairs(self.made) do o:release() end
  self.made = {}
  self.glow, self.debris, self.smoke, self.rockets = {}, {}, {}, {}
end

-- A painted picture (tools/show_art.py: ETC1, 0.5 bytes a pixel on the Mali) from the SD card, or nil (no card,
-- not painted yet: the show draws its scene live instead). Load them in start(), behind Home's curtain; they go
-- with the show (finish).
local ART = os.getenv("HOME_SHOW_ART") or "/mnt/sdcard/partycade/art"
function G:art(show, name)
  if home_note then home_note("art:" .. show .. "/" .. name) end
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

-- A painted picture read and decoded by Home's worker (C.request_pkm), for a show that loads pictures while it
-- plays: G:art on a scene change stalled the picture 100-170 ms in the fade (Longhorns, Texas, 2026-11-25). cb(img)
-- comes a few frames later with the picture (nil: none), from Home's frame (homestate.lua's drain_worker), only if
-- this show is still the one playing. With no worker, at once.
local PENDING, serial = {}, 0
function G:art_async(show, name, cb)
  serial = serial + 1
  local key = "pkm:" .. serial
  PENDING[key] = {g = self, gen = self.gen, cb = cb}
  if not (self.C.request_pkm and self.C.request_pkm(key, ART .. "/" .. show .. "/" .. name .. ".pkm")) then
    PENDING[key] = nil
    cb(self:art(show, name))
  end
end
function L.pkm_ready(key, cd)
  local p = PENDING[key]
  PENDING[key] = nil
  if not p or p.g.gen ~= p.gen then
    if cd then pcall(function() cd:release() end) end
    return
  end
  local img
  if cd then
    local ok, im = pcall(lg.newImage, cd)
    pcall(function() cd:release() end)
    if ok then im:setFilter("linear", "linear") img = p.g:track(im) end
  end
  p.cb(img)
end

-- Whether a painted picture is there to load (without loading it: for a show that loads its pictures a scene at a
-- time and still wants to know, at the start, which live fallbacks it needs).
function G:has_art(show, name)
  if home_note then home_note("art:" .. show .. "/" .. name) end
  local f = io.open(ART .. "/" .. show .. "/" .. name .. ".pkm", "rb")
  if f then f:close() return true end
  return false
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

-- L.top_busy: set when a show writes across the top 90 px this frame (Home's on-air bug steps aside)
L.top_busy = 0
local function mark_top(y, x, w) if y < 90 and (x or 0) + (w or 9999) > 560 then L.top_busy = 1 end end

function G:caption(text, y, px, colour, alpha, sc)
  if alpha <= 0 then return end
  if self.cam then return self:after_cam(function() self:caption(text, y, px, colour, alpha, sc) end) end
  mark_top(y)
  if self.C.trace and alpha > 0.5 then self.C.trace("caption", text) end
  -- (a caption scaled every frame is resampled every frame, and soft: a pulse in size becomes one in brightness)
  if sc and sc ~= 1 then
    alpha = alpha * math.min(1, 0.82 + math.abs(sc - 1) * 3)
    sc = nil
  end
  self:use(text, px, colour)
  self.C.neon_draw(text, 0, y, px, colour, 1, "center", self.W, alpha, sc)
end

-- Starlight's wordmark, script neon (the shows' "STARLIGHT PRESENTS"); y: where the old caption's top was.
function G:brand(y, alpha)
  if alpha <= 0 or not self.C.brand_draw then return end
  if self.cam then return self:after_cam(function() self:brand(y, alpha) end) end
  self.C.brand_draw(y - 58, 62, alpha)
end

-- A caption on a dark plate (legible over a bright daytime sky).
function G:plate(text, y, px, colour, alpha)
  if alpha <= 0 then return end
  if self.cam then return self:after_cam(function() self:plate(text, y, px, colour, alpha) end) end
  mark_top(y)
  if self.C.trace and alpha > 0.5 then self.C.trace("plate", text) end
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
  a = a or 1
  if a > 0 then mark_top(y, x, w) end
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
  if self.cam then return self:after_cam(function() self:ticker(label, colour, text) end) end
  local C, W, H = self.C, self.W, self.H
  local y = H - 62
  text = text .. "     "
  lg.setColor(0.05, 0.06, 0.18, 0.88)
  lg.rectangle("fill", 0, y, W, 50)
  local f = C.font(22)
  lg.setFont(f)
  local lw = f:getWidth(label) + 28
  self.tick_x = (self.tick_x or 0) - 110 * (self.dt or 0.016)
  local tw = max(1, f:getWidth(text))
  if self.tick_x < -tw then self.tick_x = self.tick_x + tw end
  lg.setColor(1, 1, 1, 0.95)
  local tx = lw + 10 + self.tick_x
  while tx < W do
    lg.print(text, tx, y + 13)
    tx = tx + tw
  end
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
  lg.setLineWidth(1)
  lg.pop()
end

-- A live oak: a short trunk, a wide spreading crown.
function L.live_oak(x, y, s, sway)
  lg.setColor(0.28, 0.2, 0.14, 1)
  lg.polygon("fill", x - 8 * s, y, x + 8 * s, y, x + 5 * s, y - 40 * s, x - 5 * s, y - 40 * s)
  lg.setLineWidth(5 * s)
  lg.line(x, y - 34 * s, x - 34 * s, y - 56 * s)
  lg.line(x, y - 34 * s, x + 38 * s, y - 52 * s)
  lg.setLineWidth(1)
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

-- ------------------------------------------------------------------ the camera (SHOWS_BLUEPRINT.md: the camera moves too)
-- A scene's shots: keys {t, x, y, zoom[, "cut"]}, (x, y) the point of the picture at the screen's centre at time t.
-- Between keys the camera eases from one to the next; a key marked "cut" is jumped to at its time. The view is
-- kept inside the picture (W x H), so a painted backdrop never shows its edge.
function L.shot(lt, keys, W, H)
  W, H = W or 768, H or 1024
  local x, y, z
  local k1 = keys[1]
  if lt <= k1[1] then
    x, y, z = k1[2], k1[3], k1[4]
  else
    x, y, z = nil, nil, nil
    for i = 2, #keys do
      local k2 = keys[i]
      if lt < k2[1] then
        if k2[5] == "cut" then x, y, z = k1[2], k1[3], k1[4]
        else
          local f = L.ease((lt - k1[1]) / (k2[1] - k1[1]))
          x, y, z = L.lerp(k1[2], k2[2], f), L.lerp(k1[3], k2[3], f), L.lerp(k1[4], k2[4], f)
        end
        break
      end
      k1 = k2
    end
    if not x then x, y, z = k1[2], k1[3], k1[4] end
  end
  z = max(1, z)
  local hw, hh = W / 2 / z, H / 2 / z
  return L.clamp(x, hw, W - hw), L.clamp(y, hh, H - hh), z
end

-- Look through the camera (x, y at the screen's centre, zoomed z): everything drawn until G:unlook() is in the
-- picture's own coordinates. shake: a few pixels of jolt (a launch, a landing).
local NOCAM = os.getenv("HOME_NOCAM") == "1"     -- (tools/show_review.py: the world without the camera's moves)
function G:look(x, y, z, shake)
  if NOCAM then x, y, z, shake = self.W / 2, self.H / 2, 1, 0 end
  if shake and shake > 0 then z = max(z, 1 + shake / 500) end
  lg.push()
  lg.translate(self.W / 2, self.H / 2)
  if shake and shake > 0 then lg.translate((self.R:random() - 0.5) * shake, (self.R:random() - 0.5) * shake) end
  lg.scale(z, z)
  lg.translate(-x, -y)
  self.cam = {x, y, z}
  local tr = self.C.trace
  if tr then
    tr("t", self.t)
    tr("cam", x, y, z)
    L.tracing = true
    tr("cast", L.cast_px * 2, L.cast_sx or 0, L.cast_sy or 0)
    tr("parts", #self.smoke, #self.glow + #self.debris)
    if #L.cast_seen > 0 then tr("crowd", table.concat(L.cast_seen, " ")) end
    L.cast_px = 0
    L.cast_seen = {}
  end
  L.zoom = z
end
function G:unlook()
  lg.pop()
  L.zoom = 1
  self.cam = nil
  -- speech bubbles said under the camera: drawn now, at the screen's size (crisp, readable at any zoom)
  local q = self.says
  if q then
    self.says = nil
    for _, b in ipairs(q) do self:say(b[1], b[2], b[3], b[4], b[5], b[6]) end
  end
  -- captions and plates: on the screen, not in the picture
  q = self.afters
  if q then
    self.afters = nil
    for _, f in ipairs(q) do f() end
  end
end
function G:after_cam(f)
  self.afters = self.afters or {}
  self.afters[#self.afters + 1] = f
end
-- A point of the picture on the screen, through the camera (if one is looking).
function G:to_screen(x, y)
  local c = self.cam
  if not c then return x, y end
  return (x - c[1]) * c[3] + self.W / 2, (y - c[2]) * c[3] + self.H / 2
end

-- ------------------------------------------------------------------ the cast, big enough to follow
-- A ghost with eyes that look where it looks (lx, ly from -1 to 1), and a mood: nil, "sleep" (eyes shut),
-- "happy" (eyes as arcs), "scared" (blue, wavy mouth), "wide" (surprised: big pupils). al: alpha.
local function wobble_hem(x, y, r, t)
  local wob = floor(t * 8) % 2
  for i = 0, 2 do
    lg.circle("fill", x - r + r / 3 + i * r * 2 / 3, y + r * 0.75, r / 3 + (wob == i % 2 and 1 or -1) * r * 0.05, 12)
  end
end
-- (the trace, tools/show_review.py: the biggest of the cast drawn this frame, on the screen)
L.cast_px, L.zoom, L.tracing = 0, 1, false
L.cast_seen = {}
local function note_cast(x, y, r)
  -- the cast drawn this frame: each one's size and where it is on the screen (through every transform); the
  -- biggest kept apart (the hero's size)
  local sx, sy = lg.transformPoint(x, y)
  local ex = lg.transformPoint(x + r, y)
  local d = abs(ex - sx)
  if d > L.cast_px then L.cast_px, L.cast_sx, L.cast_sy = d, sx, sy end
  local seen = L.cast_seen
  if d >= 20 and #seen < 24 then seen[#seen + 1] = string.format("%.0f %.0f %.0f", d * 2, sx, sy) end
end
L.note_cast = note_cast
function L.ghost(x, y, r, c, t, lx, ly, mood, al)
  al = al or 1
  if L.tracing then note_cast(x, y, r) end
  lx, ly = lx or 0, ly or 0
  local body = mood == "scared" and {0.2, 0.3, 1} or c
  lg.setColor(body[1], body[2], body[3], al)
  lg.arc("fill", "pie", x, y, r, pi, 2 * pi, 24)
  lg.rectangle("fill", x - r, y, r * 2, r * 0.75)
  wobble_hem(x, y, r, t)
  if mood == "scared" then
    lg.setColor(1, 0.85, 0.75, al)
    lg.circle("fill", x - r * 0.35, y - r * 0.2, r * 0.13, 8)
    lg.circle("fill", x + r * 0.35, y - r * 0.2, r * 0.13, 8)
    lg.setLineWidth(max(1.5, r * 0.07))
    local pts = {}
    for i = 0, 6 do pts[#pts + 1] = x - r * 0.6 + i * r * 0.2 pts[#pts + 1] = y + r * 0.3 + (i % 2 == 0 and 0 or -r * 0.12) end
    lg.line(pts)
    lg.setLineWidth(1)
    return
  end
  for sx = -1, 1, 2 do
    local ex, ey = x + sx * r * 0.38, y - r * 0.15
    if mood == "sleep" then
      lg.setColor(0.1, 0.1, 0.2, al)
      lg.setLineWidth(max(1.5, r * 0.08))
      lg.line(ex - r * 0.2, ey, ex + r * 0.2, ey)
    elseif mood == "happy" then
      lg.setColor(1, 1, 1, al)
      lg.setLineWidth(max(2, r * 0.12))
      lg.arc("line", "open", ex, ey + r * 0.08, r * 0.2, pi * 1.1, pi * 1.9, 10)
    else
      lg.setColor(1, 1, 1, al)
      lg.ellipse("fill", ex, ey, r * 0.26, r * 0.32, 14)
      lg.setColor(0.15, 0.25, 0.9, al)
      local pr = mood == "wide" and r * 0.17 or r * 0.13
      lg.circle("fill", ex + lx * r * 0.12, ey + 0.03 * r + ly * r * 0.15, pr, 10)
    end
  end
  lg.setLineWidth(1)
end

-- Pac-Man: mouth chomping with t (open: a fixed opening instead, 0 shut to 1 wide), facing dir (radians;
-- 0 right, pi left).
function L.pac(x, y, r, dir, t, open, al)
  al = al or 1
  if L.tracing then note_cast(x, y, r) end
  local o = (open or (0.15 + 0.85 * abs(sin(t * 14)))) * 0.42
  lg.setColor(1, 0.86, 0.15, al)
  lg.arc("fill", "pie", x, y, r, dir + o, dir + 2 * pi - o, 28)
  lg.setColor(0.1, 0.05, 0.1, al)
  local cd, sd = cos(dir), sin(dir)
  if abs(cd) < 0.35 then
    lg.circle("fill", x - r * 0.45 * (sd < 0 and 1 or -1), y + r * 0.12 * (sd < 0 and -1 or 1), r * 0.11, 8)
  else
    local f = cd >= 0 and 1 or -1
    lg.circle("fill", x + r * 0.12 * f, y - r * 0.5, r * 0.11, 8)
  end
end

-- Where something on a path is at time t: keys {t, x, y[, "lin"]}, eased between keys (or straight, "lin"),
-- held before the first and after the last. Also returns the way it is going (-1 left, 1 right, 0 still).
function L.path(t, keys)
  local k1 = keys[1]
  if t <= k1[1] then return k1[2], k1[3], 0 end
  for i = 2, #keys do
    local k2 = keys[i]
    if t < k2[1] then
      local f = (t - k1[1]) / (k2[1] - k1[1])
      if k2[4] ~= "lin" then f = L.ease(f) end
      local dx = k2[2] - k1[2]
      return L.lerp(k1[2], k2[2], f), L.lerp(k1[3], k2[3], f), dx > 0.5 and 1 or (dx < -0.5 and -1 or 0)
    end
    k1 = k2
  end
  return k1[2], k1[3], 0
end

-- A hop: how high (0 to h) something bouncing every period seconds is at time t.
function L.hop(t, period, h)
  return abs(sin(t / period * pi)) * h
end

-- A speech bubble pointing down at (x, y): white, round, the words in ink. a: alpha (0 hides it).
function G:say(text, x, y, px, a, ink)
  if (a or 1) <= 0 then return end
  if self.cam then
    -- (under the camera: kept for G:unlook, at the screen's position)
    local sx, sy = self:to_screen(x, y)
    self.says = self.says or {}
    self.says[#self.says + 1] = {text, sx, sy, px, a, ink}
    return
  end
  if self.C.trace and a > 0.5 then self.C.trace("say", text) end
  local f = self.C.font(px)
  local w, h = f:getWidth(text) + px * 1.1, px * 1.7
  local bx = L.clamp(x - w / 2, 8, self.W - w - 8)
  local by = max(12, y - h - px * 0.7)
  local tx = L.clamp(x, bx + h * 0.55, bx + w - h * 0.55)
  lg.setColor(0, 0, 0, 0.35 * a)
  lg.rectangle("fill", bx + 3, by + 4, w, h, h / 2, h / 2, 12)
  lg.setColor(1, 1, 1, a)
  lg.rectangle("fill", bx, by, w, h, h / 2, h / 2, 12)
  lg.polygon("fill", tx - px * 0.32, by + h - 1, tx + px * 0.32, by + h - 1, L.clamp(x, bx + 4, bx + w - 4), max(by + h + 4, y))
  lg.setFont(f)
  ink = ink or {0.08, 0.08, 0.14}
  lg.setColor(ink[1], ink[2], ink[3], a)
  lg.printf(text, floor(bx + 0.5), floor(by + px * 0.32 + 0.5), w, "center")
end

-- ------------------------------------------------------------------ reusable high-detail props & helpers
-- Wayfarer sunglasses for ghosts (dual lenses covering full sclera, bridge, bright frame, temples, white glint)
-- or Pac-Man (direction-aware side lens + temple arm + frame + glint).
function L.shades(x, y, r, is_pac, lx, frame)
  local fc = frame or {0.95, 0.96, 1.0}
  if is_pac then
    local f = (lx or 1) >= 0 and 1 or -1
    local lw, lh = r * 0.54, r * 0.38
    local cx = x + f * r * 0.24
    local cy = y - r * 0.44
    -- temple arm reaching back across the head
    lg.setColor(fc[1], fc[2], fc[3], 1)
    lg.setLineWidth(max(2.5, r * 0.09))
    lg.line(cx - f * lw * 0.45, cy - lh * 0.18, x - f * r * 0.58, cy - lh * 0.06)
    -- bright frame rim + dark tinted lens
    lg.rectangle("fill", cx - lw / 2 - 2, cy - lh / 2 - 2, lw + 4, lh + 4, 6, 6, 6)
    lg.setColor(0.06, 0.08, 0.14, 1)
    lg.rectangle("fill", cx - lw / 2, cy - lh / 2, lw, lh, 5, 5, 6)
    -- crisp diagonal white specular sheen
    lg.setColor(1, 1, 1, 0.48)
    lg.polygon("fill", cx - lw * 0.28, cy + lh * 0.34, cx - lw * 0.05, cy - lh * 0.34,
               cx + lw * 0.16, cy - lh * 0.34, cx - lw * 0.07, cy + lh * 0.34)
    lg.setLineWidth(1)
    return
  end
  local ey = y - r * 0.16
  local lw, lh = r * 0.62, r * 0.58
  -- side temple arms + nose bridge
  lg.setColor(fc[1], fc[2], fc[3], 1)
  lg.setLineWidth(max(2.5, r * 0.09))
  lg.line(x - r * 0.94, ey - lh * 0.2, x + r * 0.94, ey - lh * 0.2)
  lg.arc("line", "open", x, ey - lh * 0.08, r * 0.14, pi, 2 * pi, 8)
  for sx = -1, 1, 2 do
    local ex = x + sx * r * 0.38
    -- outer frame rim
    lg.setColor(fc[1], fc[2], fc[3], 1)
    lg.rectangle("fill", ex - lw / 2 - 2, ey - lh / 2 - 2, lw + 4, lh + 4, 7, 7, 6)
    -- dark glossy lens
    lg.setColor(0.06, 0.08, 0.14, 1)
    lg.rectangle("fill", ex - lw / 2, ey - lh / 2, lw, lh, 5, 5, 6)
    -- diagonal specular glare stripe
    lg.setColor(1, 1, 1, 0.45)
    lg.polygon("fill", ex - lw * 0.3, ey + lh * 0.32, ex - lw * 0.04, ey - lh * 0.32,
               ex + lw * 0.18, ey - lh * 0.32, ex - lw * 0.08, ey + lh * 0.32)
  end
  lg.setLineWidth(1)
end

-- Crisp US flag with stripes, star-studded canton, and optional Apollo lunar top crossbar (opts.crossbar).
function L.flag_us(x, y, w, h, opts)
  local n = 13
  local sh = h / n
  for i = 0, n - 1 do
    if i % 2 == 0 then lg.setColor(0.82, 0.14, 0.18, 1) else lg.setColor(0.97, 0.96, 0.94, 1) end
    lg.rectangle("fill", x, y + i * sh, w, sh + 0.5)
  end
  local cw, ch = w * 0.42, sh * 7
  lg.setColor(0.10, 0.18, 0.46, 1)
  lg.rectangle("fill", x, y, cw, ch)
  lg.setColor(1, 1, 1, 0.95)
  for r = 0, 2 do
    for c = 0, 2 do
      lg.circle("fill", x + cw * (0.2 + c * 0.3), y + ch * (0.22 + r * 0.28), max(1.1, min(w, h) * 0.028), 6)
    end
  end
  if opts and opts.crossbar then
    lg.setColor(0.84, 0.86, 0.9, 1)
    lg.setLineWidth(2)
    lg.line(x - 2, y - 1, x + w + 2, y - 1)
    lg.setLineWidth(1)
  end
end

-- Soft ground contact shadow.
function L.shadow(x, y, rx, ry, a)
  lg.setColor(0, 0, 0, a or 0.24)
  lg.ellipse("fill", x, y, rx, ry or rx * 0.28, 16)
end


return L
