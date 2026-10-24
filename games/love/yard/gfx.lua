-- The cart drawing API (CARTS.md § 4) on love.graphics: the GPU draws, at the panel's own resolution.
--
-- A cart draws in its logical picture (240x320 or 384x512). Everything here is drawn into one canvas the
-- size of the panel's portrait area (768x1024) through a scale of K = 768 / W, so shapes and text are
-- rendered sharp at full resolution instead of being drawn small and stretched. Layers are canvases at the
-- same scale. Colors are the cart's numbers: 0xRRGGBB opaque, 0xAARRGGBB see-through.
local bit = require("bit")
local band, rshift = bit.band, bit.rshift
local lg = love.graphics

local G = {}
local K, W, H = 1, 240, 320          -- scale, logical size
local screen                          -- the main canvas (W*K x H*K)
local target                          -- the canvas being drawn into (screen or a layer)
local target_k = 1                    -- that canvas's scale
local offx, offy = 0, 0
local shake_amt, flash_c, flash_left, flash_len = 0, 0, 0, 1
local glow_tex, white
local fonts, font_data = {}, {}
local tint_shader, light_mul, light_add
local image_bytes = 0
G.memory = function() return image_bytes end

-- ------------------------------------------------------------------ colors

local function rgba(c)
  c = c or 0xffffff
  local a = c >= 0x1000000 and band(rshift(c, 24), 255) or 255
  if c >= 0x1000000 and a == 0 then a = 255 end
  return band(rshift(c, 16), 255) / 255, band(rshift(c, 8), 255) / 255, band(c, 255) / 255, a / 255
end
G.rgba = rgba
local function setc(c) lg.setColor(rgba(c)) end

-- ------------------------------------------------------------------ targets and transforms

local function apply_transform()
  lg.origin()
  lg.scale(target_k)
  lg.translate(offx, offy)
end

local function set_target(canvas, k)
  target, target_k = canvas, k
  lg.setCanvas({canvas, stencil = true})
  lg.setScissor()
  apply_transform()
end

function G.init(w, h, k)
  W, H, K = w, h, k
  screen = lg.newCanvas(math.floor(W * K + 0.5), math.floor(H * K + 0.5), {msaa = G.msaa or 0})
  -- A soft round light: alpha (1 - d^2)^2, the falloff the software renderer's glow used.
  local n = 128
  local d = love.image.newImageData(n, n)
  d:mapPixel(function(x, y)
    local dx, dy = (x + 0.5) / n * 2 - 1, (y + 0.5) / n * 2 - 1
    local v = 1 - (dx * dx + dy * dy)
    if v < 0 then v = 0 end
    return 1, 1, 1, v * v
  end)
  glow_tex = lg.newImage(d)
  glow_tex:setFilter("linear", "linear")
  white = lg.newImage(love.image.newImageData(1, 1, "rgba8", "\255\255\255\255"))
  tint_shader = lg.newShader([[
    extern vec4 tint;
    vec4 effect(vec4 c, Image t, vec2 uv, vec2 sc) {
      vec4 p = Texel(t, uv);
      return vec4(mix(p.rgb, tint.rgb, tint.a), p.a) * c;
    }]])
  -- Light, as Lamp's software pass did it: warm light keeps red a little longer than blue.
  light_mul = lg.newShader([[
    vec4 effect(vec4 c, Image t, vec2 uv, vec2 sc) {
      float k = clamp(Texel(t, uv).r, 0.0, 1.0);
      return vec4(k * (0.75 + 0.25 * k), k * (0.85 + 0.15 * k), k, 1.0);
    }]])
  light_add = lg.newShader([[
    extern vec3 tint;
    vec4 effect(vec4 c, Image t, vec2 uv, vec2 sc) {
      float k = clamp(Texel(t, uv).r, 0.0, 1.0);
      return vec4(tint * (1.0 - k), 1.0);
    }]])
end

function G.begin_frame()
  offx, offy = 0, 0
  set_target(screen, K)
  lg.setBlendMode("alpha")
  lg.setLineJoin("bevel")
end

function G.screen() return screen end

-- Shake, flash, and the quit meter are laid over the finished frame, as gfx_present did.
function G.finish_frame(quitting)
  set_target(screen, K)
  offx, offy = 0, 0
  apply_transform()
  if flash_left > 0 then
    local r, g, b, a = rgba(flash_c)
    lg.setColor(r, g, b, a * flash_left / flash_len)
    lg.rectangle("fill", 0, 0, W, H)
    flash_left = flash_left - 1
  end
  if quitting and quitting > 0 then
    local bw, bh = W * 3 / 4, W >= 300 and 44 or 34
    local bx, by = (W - bw) / 2, H / 2 - bh / 2
    lg.setColor(8 / 255, 6 / 255, 16 / 255, 220 / 255)
    lg.rectangle("fill", bx - 3, by - 3, bw + 6, bh + 6, 10, 10)
    lg.setColor(40 / 255, 34 / 255, 64 / 255, 240 / 255)
    lg.rectangle("fill", bx, by, bw, bh, 8, 8)
    lg.setColor(1, 200 / 255, 90 / 255)
    lg.rectangle("fill", bx + 4, by + bh - 14, (bw - 8) * math.min(1, quitting), 10, 4, 4)
    G.api.text("leaving...", W / 2, by + 4, W >= 300 and 18 or 14, 0xfff6ea, "center")
  end
  lg.setCanvas()
  lg.origin()
  local sx, sy = 0, 0
  if shake_amt > 0.3 then
    -- From the game's own generator, x then y, as gfx_present did: a seed replays the same game.
    sx = -shake_amt + 2 * shake_amt * G.rng_f()
    sy = -shake_amt + 2 * shake_amt * G.rng_f()
    shake_amt = shake_amt * 0.85
  else
    shake_amt = 0
  end
  return sx * K, sy * K
end

-- ------------------------------------------------------------------ shapes

local function segs(r) return math.max(10, math.min(72, math.floor(r * target_k * 0.7))) end

local api = {}
G.api = api

function api.clear(c)
  local r, g, b = rgba(c)
  lg.clear(r, g, b, 1)
end
function api.pixel(x, y, c) setc(c) lg.rectangle("fill", math.floor(x), math.floor(y), 1, 1) end
function api.rect(x, y, w, h, c)
  setc(c)
  lg.rectangle("fill", math.floor(x), math.floor(y), math.floor(w + 0.5), math.floor(h + 0.5))
end
function api.frame(x, y, w, h, t, c)
  setc(c)
  lg.rectangle("fill", x, y, w, t)
  lg.rectangle("fill", x, y + h - t, w, t)
  lg.rectangle("fill", x, y + t, t, h - 2 * t)
  lg.rectangle("fill", x + w - t, y + t, t, h - 2 * t)
end
local function grad(x, y, w, h, c0, c1, vertical)
  local r0, g0, b0, a0 = rgba(c0)
  local r1, g1, b1, a1 = rgba(c1)
  local v
  if vertical then
    v = {{x, y, 0, 0, r0, g0, b0, a0}, {x + w, y, 1, 0, r0, g0, b0, a0}, {x + w, y + h, 1, 1, r1, g1, b1, a1}, {x, y + h, 0, 1, r1, g1, b1, a1}}
  else
    v = {{x, y, 0, 0, r0, g0, b0, a0}, {x + w, y, 1, 0, r1, g1, b1, a1}, {x + w, y + h, 1, 1, r1, g1, b1, a1}, {x, y + h, 0, 1, r0, g0, b0, a0}}
  end
  local m = lg.newMesh(v, "fan", "stream")
  lg.setColor(1, 1, 1)
  lg.draw(m)
  m:release()
end
function api.vgrad(x, y, w, h, top, bottom) grad(x, y, w, h, top, bottom, true) end
function api.hgrad(x, y, w, h, left, right) grad(x, y, w, h, left, right, false) end
function api.circle(x, y, r, c)
  if r <= 0 then return end
  setc(c)
  lg.circle("fill", x, y, r, segs(r))
end
function api.ellipse(x, y, rx, ry, c)
  if rx <= 0 or ry <= 0 then return end
  setc(c)
  lg.ellipse("fill", x, y, rx, ry, segs(math.max(rx, ry)))
end
function api.ring(x, y, r, thick, c)
  setc(c)
  lg.setLineWidth(thick)
  lg.circle("line", x, y, r, segs(r))
end
function api.rrect(x, y, w, h, r, c)
  if w <= 0 or h <= 0 then return end
  setc(c)
  r = math.min(r, w / 2, h / 2)
  lg.rectangle("fill", x, y, w, h, r, r, segs(r))
end
local function poly(pts, c)
  setc(c)
  if #pts == 6 or love.math.isConvex(pts) then
    lg.polygon("fill", pts)
  else
    local ok, tris = pcall(love.math.triangulate, pts)
    if ok then for _, t in ipairs(tris) do lg.polygon("fill", t) end end
  end
end
G.poly = poly
function api.tri(x0, y0, x1, y1, x2, y2, c) poly({x0, y0, x1, y1, x2, y2}, c) end
function api.poly(pts, c) poly(pts, c) end
function api.line(x0, y0, x1, y1, thick, c)
  setc(c)
  thick = thick or 1
  lg.setLineWidth(thick)
  lg.line(x0, y0, x1, y1)
  if thick > 1.5 then
    lg.circle("fill", x0, y0, thick / 2, 12)
    lg.circle("fill", x1, y1, thick / 2, 12)
  end
end
function api.glow(x, y, r, c)
  if r <= 0.5 then return end
  local cr, cg, cb, ca = rgba(c)
  lg.setBlendMode("add")
  lg.setColor(cr, cg, cb, ca)
  lg.draw(glow_tex, x - r, y - r, 0, 2 * r / 128, 2 * r / 128)
  lg.setBlendMode("alpha")
end
function api.star(x, y, r, rot, c)
  local p = {}
  for i = 0, 9 do
    local a = rot - 1.5707963 + i * 0.6283185
    local rr = i % 2 == 1 and r * 0.45 or r
    p[#p + 1] = x + math.cos(a) * rr
    p[#p + 1] = y + math.sin(a) * rr
  end
  -- A star is star-shaped about its middle: a fan from the centre.
  setc(c)
  for i = 0, 9 do
    local j = (i + 1) % 10
    lg.polygon("fill", x, y, p[i * 2 + 1], p[i * 2 + 2], p[j * 2 + 1], p[j * 2 + 2])
  end
end
function api.heart(x, y, s, c)
  api.circle(x - s * 0.5, y - s * 0.2, s * 0.55, c)
  api.circle(x + s * 0.5, y - s * 0.2, s * 0.55, c)
  api.tri(x - s * 1.03, y, x + s * 1.03, y, x, y + s * 1.05, c)
  setc(c)
  lg.rectangle("fill", x - s * 0.5, y - s * 0.2, s, s * 0.4)
end
function api.circle_o(x, y, r, fill, ink, t)
  t = t or 2
  api.circle(x, y, r + t, ink)
  api.circle(x, y, r, fill)
end
function api.ellipse_o(x, y, rx, ry, fill, ink, t)
  t = t or 2
  api.ellipse(x, y, rx + t, ry + t, ink)
  api.ellipse(x, y, rx, ry, fill)
end
function api.rrect_o(x, y, w, h, r, fill, ink, t)
  t = t or 2
  api.rrect(x - t, y - t, w + 2 * t, h + 2 * t, r + t, ink)
  api.rrect(x, y, w, h, r, fill)
end
function api.dim(k)
  k = math.max(0, math.min(1, k))
  lg.setBlendMode("multiply", "premultiplied")
  lg.setColor(k, k, k, 1)
  lg.rectangle("fill", -offx, -offy, W, H)
  lg.setBlendMode("alpha")
end
function api.shake(a) if a > shake_amt then shake_amt = a end end
function api.flash(c, frames) flash_c, flash_left, flash_len = c, frames, math.max(1, frames) end
function api.offset(dx, dy)
  offx, offy = dx or 0, dy or 0
  apply_transform()
end
function api.clip(x, y, w, h)
  if not x then lg.setScissor() return end
  local k = target_k
  lg.setScissor(math.floor((x + offx) * k), math.floor((y + offy) * k), math.ceil(w * k), math.ceil(h * k))
end
function api.iris(x, y, r, c)
  lg.stencil(function() lg.circle("fill", x, y, math.max(0, r), 96) end, "replace", 1)
  lg.setStencilTest("equal", 0)
  setc(c or 0)
  lg.rectangle("fill", -offx - 2, -offy - 2, W + 4, H + 4)
  lg.setStencilTest()
end

-- ------------------------------------------------------------------ text

local function font(id, size)
  size = math.max(6, math.min(96, math.floor(size)))
  local key = id .. ":" .. size .. ":" .. target_k
  local f = fonts[key]
  if not f then
    local src = font_data[id] or font_data[0]
    local px = math.max(1, math.floor(size * target_k + 0.5))
    -- The C runtime (stb_truetype) sizes a font by ascent minus descent; FreeType sizes it by the em
    -- square. Rescale so "size 16" is the same height in both.
    local probe = lg.newFont(src, 100)
    local ratio = 100 / (probe:getAscent() - probe:getDescent())
    probe:release()
    f = lg.newFont(src, math.max(1, math.floor(px * ratio + 0.5)))
    f:setFilter("linear", "linear")
    fonts[key] = f
  end
  return f
end

function G.load_font(id, data) font_data[id] = data end
local next_font = 1
function api.font(bytes)
  if next_font >= 8 then error("that font did not load (TrueType, under 8 fonts)", 2) end
  local ok, fd = pcall(love.filesystem.newFileData, bytes, "cart-font.ttf")
  if not ok then error("that font did not load (TrueType)", 2) end
  font_data[next_font] = love.font.newRasterizer and fd or fd
  next_font = next_font + 1
  return next_font - 1
end

local function align_of(a) return a == "center" and 1 or a == "right" and 2 or 0 end

function api.text(s, x, y, size, color, align, outline, fid)
  s = tostring(s)
  if type(size) == "table" then
    local o = size
    size, color, align, outline, fid = o.size, o.color, o.align, o.outline, o.font
  end
  size = size or 16
  local f = font(fid or 0, size)
  local k = target_k
  local w = f:getWidth(s) / k
  local al = align_of(align)
  local px = x - (al == 1 and w / 2 or al == 2 and w or 0)
  lg.setFont(f)
  if outline and outline ~= 0 then
    local r = size >= 14 and math.floor((size + 6) / 12) or 1
    setc(outline)
    for i = 0, 7 do
      local a = i * math.pi / 4
      lg.print(s, px + math.cos(a) * r, y + math.sin(a) * r + (size >= 18 and 1 / k or 0), 0, 1 / k, 1 / k)
    end
  end
  setc(color or 0xffffff)
  lg.print(s, px, y, 0, 1 / k, 1 / k)
  return w
end
function api.textw(s, size, fid) return font(fid or 0, size or 16):getWidth(tostring(s)) / target_k end
function api.lineh(size, fid) return font(fid or 0, size or 16):getHeight() / target_k end
-- The 8x8 pixel font is the round font here, at the height it would have had.
function api.pixtext(s, x, y, scale, color, align, outline)
  return api.text(s, x, y, 9 * (scale or 1), color, align, outline)
end
function api.pixtextw(s, scale) return api.textw(s, 9 * (scale or 1)) end

-- ------------------------------------------------------------------ toon

local toon_pass, toon_t, toon_ink = 1, 2, 0x3a2a44
local toon = {}
G.toon = toon
setmetatable(toon, {__call = function(_, fn, t, ink)
  local keep_t, keep_ink = toon_t, toon_ink
  toon_t, toon_ink = t or 2, ink or 0x3a2a44
  for pass = 0, 1 do
    toon_pass = pass
    fn()
  end
  toon_pass, toon_t, toon_ink = 1, keep_t, keep_ink
end})
function G.toon_reset() toon_pass = 1 end
function toon.fill() return toon_pass == 1 end
function toon.circle(x, y, r, c)
  if toon_pass == 0 then api.circle(x, y, r + toon_t, toon_ink) else api.circle(x, y, r, c) end
end
function toon.ellipse(x, y, rx, ry, c)
  if toon_pass == 0 then api.ellipse(x, y, rx + toon_t, ry + toon_t, toon_ink) else api.ellipse(x, y, rx, ry, c) end
end
function toon.rrect(x, y, w, h, r, c)
  if toon_pass == 0 then api.rrect(x - toon_t, y - toon_t, w + 2 * toon_t, h + 2 * toon_t, r + toon_t, toon_ink)
  else api.rrect(x, y, w, h, r, c) end
end
function toon.line(x0, y0, x1, y1, thick, c)
  if toon_pass == 0 then api.line(x0, y0, x1, y1, thick + 2 * toon_t, toon_ink) else api.line(x0, y0, x1, y1, thick, c) end
end
function toon.poly(pts, c)
  if toon_pass == 0 then
    poly(pts, toon_ink)
    local n = #pts / 2
    for i = 0, n - 1 do
      local j = (i + n - 1) % n
      api.line(pts[j * 2 + 1], pts[j * 2 + 2], pts[i * 2 + 1], pts[i * 2 + 2], 2 * toon_t, toon_ink)
    end
  else
    poly(pts, c)
  end
end
function toon.tri(x0, y0, x1, y1, x2, y2, c) toon.poly({x0, y0, x1, y1, x2, y2}, c) end

-- ------------------------------------------------------------------ layers, images, art

local Img = {}
Img.__index = Img
function Img:w() return self.lw end
function Img:h() return self.lh end
function Img:paint(fn, color)
  if not self.canvas then error("only a layer can be painted into", 2) end
  local keep, keep_k, kx, ky = target, target_k, offx, offy
  offx, offy = 0, 0
  set_target(self.canvas, self.k)
  if color then
    local r, g, b = rgba(color)
    lg.clear(r, g, b, 1)
  else
    lg.clear(0, 0, 0, 0)
  end
  local ok, err = pcall(fn)
  offx, offy = kx, ky
  set_target(keep, keep_k)
  if not ok then error(err, 0) end
end

local function new_img(t) return setmetatable(t, Img) end
G.is_img = function(v) return getmetatable(v) == Img end

local live = setmetatable({}, {__mode = "k"})
local function count(t, bytes)
  t.bytes = bytes
  image_bytes = image_bytes + bytes
  live[t] = true
end
-- Released images give their bytes back (the cart's memory cap counts them).
function G.collect()
  local n = 0
  for t in pairs(live) do n = n + t.bytes end
  image_bytes = n
end

function api.layer(w, h)
  if w < 1 or h < 1 or w > 1024 or h > 1024 then error("a layer is 1 to 1024 pixels on a side", 2) end
  local k = K
  local cw, ch = math.ceil(w * k), math.ceil(h * k)
  if cw > 2048 or ch > 2048 then k = 2048 / math.max(w, h) cw, ch = math.ceil(w * k), math.ceil(h * k) end
  local c = lg.newCanvas(cw, ch)
  local t = new_img({canvas = c, lw = w, lh = h, k = k})
  count(t, cw * ch * 4)
  return t
end

function G.image_from_bytes(bytes, name)
  local ok, data = pcall(love.image.newImageData, love.filesystem.newFileData(bytes, name))
  if not ok then return nil end
  local im = lg.newImage(data)
  im:setFilter("nearest", "nearest")
  local t = new_img({image = im, lw = data:getWidth(), lh = data:getHeight(), k = 1})
  count(t, t.lw * t.lh * 4)
  return t
end

function api.art(rows, palette)
  if #rows < 1 or #rows > 64 then error("art wants 1 to 64 rows", 2) end
  local w = 0
  for _, r in ipairs(rows) do w = math.max(w, #r) end
  local d = love.image.newImageData(math.max(1, w), #rows)
  for y, r in ipairs(rows) do
    for x = 1, #r do
      local ch = r:sub(x, x)
      local c = palette[ch]
      if c and ch ~= "." and ch ~= " " then d:setPixel(x - 1, y - 1, rgba(c)) end
    end
  end
  local im = lg.newImage(d)
  im:setFilter("nearest", "nearest")
  local t = new_img({image = im, lw = w, lh = #rows, k = 1})
  count(t, w * #rows * 4)
  return t
end

local quads = setmetatable({}, {__mode = "k"})
function api.draw(img, x, y, o)
  if not G.is_img(img) then error("draw takes an image, art, or layer", 2) end
  local src = img.canvas or img.image
  local k = img.k
  local qx, qy, qw, qh = 0, 0, img.lw, img.lh
  local sx, sy, rot, ox, oy, alpha, tint = 1, 1, 0, 0, 0, 255, nil
  if o then
    if o.quad then qx, qy, qw, qh = o.quad[1], o.quad[2], o.quad[3], o.quad[4] end
    if o.scale then sx, sy = o.scale, o.scale end
    sx, sy = o.sx or sx, o.sy or sy
    rot = o.rot or 0
    ox, oy = (o.ox or 0) * qw, (o.oy or 0) * qh
    if o.flip then sx = -sx end
    alpha = o.alpha or 255
    tint = o.tint
  end
  if sx < 0 then ox = qw - ox end
  local q
  if qx ~= 0 or qy ~= 0 or qw ~= img.lw or qh ~= img.lh then
    quads[img] = quads[img] or {}
    local key = qx .. ":" .. qy .. ":" .. qw .. ":" .. qh
    q = quads[img][key]
    if not q then
      q = lg.newQuad(qx * k, qy * k, qw * k, qh * k, src:getDimensions())
      quads[img][key] = q
    end
  end
  lg.setColor(1, 1, 1, alpha / 255)
  if tint then
    local r, g, b, a = rgba(tint)
    tint_shader:send("tint", {r, g, b, a})
    lg.setShader(tint_shader)
  end
  if q then
    lg.draw(src, q, x, y, rot, sx / k, sy / k, ox * k, oy * k)
  else
    lg.draw(src, x, y, rot, sx / k, sy / k, ox * k, oy * k)
  end
  if tint then lg.setShader() end
end
function api.blit(l, x, y)
  if not (G.is_img(l) and l.canvas) then error("blit takes a layer; use gfx.draw for images", 2) end
  lg.setColor(1, 1, 1, 1)
  lg.setBlendMode("alpha", "premultiplied")
  lg.draw(l.canvas, math.floor(x), math.floor(y), 0, 1 / l.k, 1 / l.k)
  lg.setBlendMode("alpha")
end
function api.blit_key(l, x, y)
  if not (G.is_img(l) and l.canvas) then error("blit_key takes a layer", 2) end
  api.blit(l, x, y)
end

-- ------------------------------------------------------------------ light

local light = {}
G.light = light
local lc, lx, ly, lw, lh
function light.begin(x, y, w, h, ambient)
  x, y, w, h = x or 0, y or 0, w or W, h or H
  if not lc or lc:getWidth() ~= w or lc:getHeight() ~= h then lc = lg.newCanvas(w, h) lc:setFilter("linear", "linear") end
  lx, ly, lw, lh = x, y, w, h
  local keep, keep_k = target, target_k
  lg.push("all")
  lg.setCanvas(lc)
  lg.origin()
  local a = ambient or 0.1
  lg.clear(a, a, a, 1)
  lg.pop()
  set_target(keep, keep_k)
end
function light.add(x, y, r, k)
  if not lc or r <= 0 then return end
  local keep, keep_k = target, target_k
  lg.push("all")
  lg.setCanvas(lc)
  lg.origin()
  lg.setBlendMode("add")
  local v = k or 1
  lg.setColor(v, v, v, 1)
  lg.draw(glow_tex, x + offx - lx - r, y + offy - ly - r, 0, 2 * r / 128, 2 * r / 128)
  lg.pop()
  set_target(keep, keep_k)
end
function light.fill(k)
  if not lc then return end
  local keep, keep_k = target, target_k
  lg.push("all")
  lg.setCanvas(lc)
  lg.origin()
  lg.setBlendMode("add")
  lg.setColor(k, k, k, 1)
  lg.rectangle("fill", 0, 0, lw, lh)
  lg.pop()
  set_target(keep, keep_k)
end
function light.apply(tint)
  if not lc then return end
  lg.setColor(1, 1, 1, 1)
  lg.setShader(light_mul)
  lg.setBlendMode("multiply", "premultiplied")
  lg.draw(lc, lx - offx, ly - offy)
  local r, g, b = rgba(tint or 0x00000e)
  light_add:send("tint", {r, g, b})
  lg.setShader(light_add)
  lg.setBlendMode("add")
  lg.draw(lc, lx - offx, ly - offy)
  lg.setShader()
  lg.setBlendMode("alpha")
end

-- ------------------------------------------------------------------ particles

local parts = {}
local KINDS = {dot = 0, glow = 1, star = 2, heart = 3, square = 4, ring = 5, text = 6}
local P = {}
G.particles = P
function P.spawn(x, y, vx, vy, life, size, c, kind, grav, drag, spin, rng)
  if #parts >= 512 then table.remove(parts, 1) end
  local k = KINDS[kind or "dot"]
  if not k then error("no particle kind '" .. tostring(kind) .. "' (dot glow star heart square ring)", 2) end
  local p = {x = x, y = y, vx = vx, vy = vy, life = math.max(1, life), max = math.max(1, life), size = size, c = c,
             kind = k, grav = grav or 0, drag = drag or 0.98, spin = spin or 0, rot = 0}
  parts[#parts + 1] = p
  return p
end
function P.burst(x, y, n, speed, life, size, c, kind)
  local rf = G.rng_f
  for _ = 1, n do
    local a = rf() * 6.2831853
    local s = speed * (0.35 + 0.65 * rf())
    local p = P.spawn(x, y, math.cos(a) * s, math.sin(a) * s, math.floor(life / 2) + G.rng_int(0, math.floor(life / 2)),
      size, c, kind)
    p.rot = rf() * 6.28
    p.spin = -0.2 + 0.4 * rf()
  end
end
function P.text(x, y, c, s)
  local p = P.spawn(x, y, 0, -0.7, 50, 1, c, "text")
  p.drag = 0.97
  p.text = tostring(s)
end
function P.update()
  local j = 1
  for i = 1, #parts do
    local p = parts[i]
    parts[i] = nil
    p.life = p.life - 1
    if p.life > 0 then
      p.vy = p.vy + p.grav
      p.vx, p.vy = p.vx * p.drag, p.vy * p.drag
      p.x, p.y = p.x + p.vx, p.y + p.vy
      p.rot = p.rot + p.spin
      parts[j] = p
      j = j + 1
    end
  end
end
local function with_alpha(c, a)
  local base = c % 0x1000000
  return base + math.floor(a) * 0x1000000
end
function P.draw()
  for _, p in ipairs(parts) do
    local t = p.life / p.max
    local _, _, _, ca = rgba(p.c)
    local a = math.max(1, math.floor(ca * 255 * (t < 0.3 and t / 0.3 or 1)))
    local c = with_alpha(p.c, a)
    local s = p.size
    if p.kind == 1 then api.glow(p.x, p.y, s * (0.6 + 0.4 * t), c)
    elseif p.kind == 2 then api.star(p.x, p.y, s * (0.5 + 0.5 * t), p.rot, c)
    elseif p.kind == 3 then api.heart(p.x, p.y, s, c)
    elseif p.kind == 4 then api.rect(p.x - s / 2, p.y - s / 2, math.max(1, s), math.max(1, s), c)
    elseif p.kind == 5 then api.ring(p.x, p.y, s, 1.5, c)
    elseif p.kind == 6 then api.text(p.text, p.x, p.y, s >= 2 and 18 or 13, c, "center", with_alpha(0x14101e, a))
    else api.circle(p.x, p.y, s * (0.4 + 0.6 * t), c) end
  end
end
function P.clear() parts = {} end
function P.count() return #parts end

return G
