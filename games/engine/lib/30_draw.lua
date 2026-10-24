-- Drawing helpers: painting once and copying, faces, and the small pictures every game wants.

-- bake(key, w, h, paint): a layer painted once by paint() (drawing at the layer's own 0,0)
-- and kept. The same key hands back the same layer until unbake(key). This is how a busy
-- picture stays cheap: paint the hills once, copy them every frame.
local baked = {}
function bake(key, w, h, paint)
  local l = baked[key]
  if not l then
    l = gfx.layer(w, h)
    l:paint(paint)
    baked[key] = l
  end
  return l
end
function unbake(key)
  if key == nil then baked = {} else baked[key] = nil end
end

-- backdrop(key, paint): a whole-screen picture that never moves, painted once.
function backdrop(key, paint)
  gfx.blit(bake(key, W, H, paint), 0, 0)
end

-- stamp(key, w, h, ox, oy, x, y, paint): a figure painted once into a w x h layer, with
-- (ox, oy) its anchor inside the layer, drawn with the anchor at (x, y). Use a key that
-- names the pose, e.g. "cat:pip:happy".
function stamp(key, w, h, ox, oy, x, y, paint)
  gfx.blit_key(bake(key, w, h, function() gfx.offset(ox, oy) paint() gfx.offset(0, 0) end), floor(x - ox), floor(y - oy))
end

-- A soft shadow on the ground under something.
function shadow(x, y, w, a) gfx.ellipse(x, y, w, w * 0.28, alpha(0x1a2a1a, a or 90)) end

-- Text with the house look: round, outlined. size 12 to 48 or so. align "left" "center" "right".
function say_text(s, x, y, size, color, align, outline)
  return gfx.text(s, x, y, size or 16, color or pal.cream, align or "center", outline or pal.ink)
end

-- Cute faces. (x, y) is the middle between the eyes, s the scale (1 is a 20-pixel head).
face = {}
function face.eyes(x, y, gap, s, look_x, look_y, mood)
  look_x, look_y, s = look_x or 0, look_y or 0, s or 1
  if mood == "happy" then
    for k = -1, 1, 2 do
      local ex = x + k * gap
      gfx.line(ex - 4 * s, y + 2 * s, ex, y - 2 * s, 2.2 * s, pal.ink)
      gfx.line(ex, y - 2 * s, ex + 4 * s, y + 2 * s, 2.2 * s, pal.ink)
    end
  elseif mood == "blink" then
    for k = -1, 1, 2 do gfx.line(x + k * gap - 4 * s, y, x + k * gap + 4 * s, y, 2.2 * s, pal.ink) end
  else
    for k = -1, 1, 2 do
      local ex, ey = x + k * gap + look_x, y + look_y
      gfx.ellipse(ex, ey, 3.6 * s, 4.6 * s, pal.ink)
      gfx.circle(ex + 1.2 * s, ey - 1.8 * s, 1.4 * s, pal.white)
    end
  end
end
function face.blush(x, y, gap, s, a)
  s = s or 1
  gfx.ellipse(x - gap, y, 4 * s, 2.4 * s, alpha(pal.blush, a or 120))
  gfx.ellipse(x + gap, y, 4 * s, 2.4 * s, alpha(pal.blush, a or 120))
end
function face.smile(x, y, w, s, open)
  s = s or 1
  gfx.line(x - w, y - 1 * s, x, y + 2 * s, 1.6 * s, pal.ink)
  gfx.line(x, y + 2 * s, x + w, y - 1 * s, 1.6 * s, pal.ink)
  if open then gfx.ellipse(x, y + 2.5 * s, w * 0.4, 1.8 * s, 0xff8fa8) end
end
-- Blink now and then: true for a few frames every couple of seconds, offset per character.
function face.blinking(seed) return (game.frame + (seed or 0) * 47) % 190 < 7 end

-- A row of hearts: n full out of max, centred on x.
function hearts(n, max_n, x, y, size, full, empty)
  size = size or 6
  local step = size * 3.4
  local x0 = x - (max_n - 1) * step / 2
  for i = 1, max_n do
    local hx = x0 + (i - 1) * step
    gfx.heart(hx, y, size * 1.25, pal.ink)
    gfx.heart(hx, y, size, i <= n and (full or 0xff5a7a) or (empty or alpha(pal.ink, 140)))
    if i <= n then gfx.circle(hx - size * 0.4, y - size * 0.4, size * 0.2, alpha(0xffffff, 190)) end
  end
end

-- A meter: a rounded bar, k from 0 to 1.
function meter(x, y, w, h, k, color, back)
  gfx.rrect(x, y, w, h, h / 2, back or 0x2a2244)
  if k > 0 then gfx.rrect(x, y, max(h, w * clamp(k, 0, 1)), h, h / 2, color or pal.gold) end
end

-- A speech or thought bubble with a tail pointing down at (tx, ty).
function bubble(x, y, r, tx, ty, fill, ink)
  fill, ink = fill or pal.white, ink or pal.ink
  gfx.circle_o(x, y, r, fill, ink, 2.5)
  if tx then
    gfx.tri(tx - 8, y + r - 4, tx + 8, y + r - 4, tx, ty, ink)
    gfx.tri(tx - 6, y + r - 5, tx + 6, y + r - 5, tx, ty - 4, fill)
  end
end

-- A see-through soap bubble.
function soap(x, y, r, color, fill)
  local wob = sin(game.frame * 0.2) * 0.06
  if fill ~= false then gfx.ellipse(x, y, r * (1 + wob), r * (1 - wob), alpha(color, 70)) end
  gfx.ring(x, y, r, 3, alpha(color, 230))
  gfx.ellipse(x - r * 0.4, y - r * 0.45, r * 0.22, r * 0.12, alpha(0xffffff, 200))
end

-- Burst of something cheerful at (x, y).
fx = {}
function fx.pop(x, y, color, n) particles.burst(x, y, n or 14, 2.4, 30, 2.5, color or pal.gold, "star") end
function fx.dust(x, y) particles.burst(x, y, 8, 1.5, 20, 2, alpha(0xe8f0c0, 200), "dot") end
function fx.hearts(x, y, n) particles.burst(x, y, n or 10, 2, 34, 4, alpha(pal.rose, 230), "heart") end
function fx.label(x, y, text, color) particles.text(x, y, color or pal.gold, text) end
-- Confetti from the top of the screen.
function fx.confetti(n)
  for i = 1, n or 30 do
    particles.spawn(rnd(20, W - 20), rnd(-20, 30), rnd(-0.5, 0.5), rnd(0.6, 1.6), 140, rnd(3, 5),
      hsv(rnd(), 0.45, 1), i % 2 == 0 and "heart" or "star", 0, 1, rnd(-0.1, 0.1))
  end
end
