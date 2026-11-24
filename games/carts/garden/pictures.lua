-- Garden's pictures: the cast (drawn as in Tea and Band), the fairy, the flowers and what they want,
-- the visitors, the fairy ring, the packet shelf, the bouquet and the two skies.
-- main.lua owns the rules; everything here only draws. No rnd() in here: a hash of the frame instead.
local P = {}

local C = {
  CREAM = 0xfff6ea, GOLD = 0xf2c14e, MINT = 0x7ec8c3, LILAC = 0xb9a0e8, ROOF = 0xe86b9a, TEA = 0xc9865a,
  ORANGE = 0xf29a3a, GREY = 0x8a8f9c, INK = 0x3a2a44, WHITE = 0xfffcf8, SKY = 0x8ec6ff, CASTLE = 0xf4b6d0,
  BLUSH = alpha(0xff8fb0, 120), WOOD = 0xc88450, WOODL = 0xe4a46a, NIGHT = 0x2a1838,
  LEAF = 0x62cc6a, LEAFD = 0x3fa850, SOIL = 0xb07a52, SOILD = 0x8a5a3c, SUN = 0xffd84a, DROP = 0x5ab4ff,
}
P.C = C
local INK = C.INK
local STRIPES = {0xf2c14e, 0xe86b9a, 0x7ec8c3, 0xb9a0e8}
P.STRIPES = STRIPES
local BODY = {C.ORANGE, C.GREY, C.WHITE, C.CREAM}
local DARK = {0xd87a20, 0x666a78, 0xe8dccc, C.ORANGE}
local RAINBOW = {0xe86b9a, 0xf29a3a, 0xf2c14e, 0x7ec8c3, 0xb9a0e8, 0x8ac8ff}
P.RAINBOW = RAINBOW

local function fr() return game.frame end
-- A small deterministic scatter, so drawing never touches the game's random numbers.
local function hash(n)
  local v = sin(n * 12.9898) * 43758.5453
  return v - floor(v)
end
P.hash = hash

-- Painted once (CARTS.md, "Speed"): a figure is drawn into a layer the first time its pose is wanted and copied
-- after that. Every key names a pose out of a small fixed set (kind, colour, size step, ...), never a frame.
-- A bake is a canvas switch, so at most two new ones a frame; a pose not yet kept is drawn live that frame.
-- Only the GPU runtime keeps them (game.gpu): the C runtime's layers have no soft edges or see-through colour,
-- so there every figure is drawn live, exactly as before.
local kept, nbake, bake_f = {}, 0, -1
-- Blooms come in a colour and kind per garden, and a new garden brings new ones: a flower layer not drawn for
-- 900 frames is let go, so the pictures held are the garden's now, not every garden's so far.
local idle, IDLE = {}, 900
local function sweep(f)
  for key, last in pairs(idle) do
    if f - last > IDLE then
      unbake(key)
      kept[key], idle[key] = nil, nil
    end
  end
end
local function fig(key, w, h, ox, oy, x, y, paint, k, live, flower)
  if flower then
    local f = game.frame
    idle[key] = f
    if f % 600 == 0 then sweep(f) end
  end
  if not game.gpu then
    if live then live() else gfx.offset(x, y) paint() gfx.offset(0, 0) end
    return
  end
  local l = kept[key]
  if not l then
    local f = game.frame
    if f ~= bake_f then bake_f, nbake = f, 0 end
    if nbake >= 2 then
      if live then live() else gfx.offset(x, y) paint() gfx.offset(0, 0) end
      return
    end
    nbake = nbake + 1
    l = bake(key, w, h, function() gfx.offset(ox, oy) paint() gfx.offset(0, 0) end)
    kept[key] = l
  end
  if k and k ~= 1 then gfx.draw(l, x, y, {scale = k, ox = ox / w, oy = oy / h})
  else gfx.blit_key(l, floor(x - ox), floor(y - oy)) end
end

-- A sheet is many small figures painted into one layer in one go, the first time any is wanted, so a row of
-- them (a swarm, the shelf, the dots) is drawn from one picture and goes to the GPU as one draw.
-- Its cells are fixed: each is one pose out of a small set (colour, size step, ...).
local sheets = {}
local function sheet_make(name, width, cells)
  local x, y, rowh = 0, 0, 0
  for _, c in ipairs(cells) do
    if x + c.w > width then x, y, rowh = 0, y + rowh, 0 end
    c.x, c.y = x, y
    x, rowh = x + c.w, max(rowh, c.h)
  end
  sheets[name] = {width = width, height = y + rowh, cells = cells}
end
local function sheet_draw(name, i, x, y)
  local sh = sheets[name]
  local l = sh.layer
  if not l then
    l = bake("sheet:" .. name, sh.width, sh.height, function()
      for _, c in ipairs(sh.cells) do
        gfx.clip(c.x, c.y, c.w, c.h)
        gfx.offset(c.x + c.ox, c.y + c.oy)
        c.paint()
        gfx.offset(0, 0)
      end
      gfx.clip()
    end)
    sh.layer = l
  end
  local c = sh.cells[i]
  gfx.draw(l, floor(x - c.ox), floor(y - c.oy), {quad = {c.x, c.y, c.w, c.h}})
end
-- Where each kind of cell starts in the sheet "small" (built at the foot of this file).
local FF0, DOT0, MU0, PK0, BF0 = 0, 2, 9, 14, 26

-- The six flower colours, in the order the seeds come out of the pouch, and their one-word names.
P.COLS = {0xf47eb2, 0xffc83a, 0x6ab8ff, 0xb998f0, 0x68d8b8, 0xff8a6a}
P.CNAME = {"rose", "gold", "sky", "lilac", "mint", "coral"}
-- The six flower kinds, and the number of finished gardens that opens each packet.
P.KNAME = {"tulip", "daisy", "sunflower", "rose", "starlily", "rainbow"}
P.UNLOCK = {0, 1, 2, 4, 6, 9}

local function paw(x, y, col, r)
  gfx.circle_o(x, y, r or 5, col, INK, 1.5)
end

-- ------------------------------------------------------------------ the cats, as in Tea

-- who: 1 Pip, 2 Moth, 3 Pearl, 4 Nib. mood: "sleep", "happy" or nil (awake). lx: where the eyes look.
-- Drawn as three layers: the body (tail in five steps), the face (one per mood or blink) and, only when the
-- eyes are open, the eyes themselves, which follow lx. A size that is not a whole percent (a cat popping in)
-- is drawn live, as it always was.
local function cat_body(who, cx, cy, s, tail)
  local body, dark = BODY[who], DARK[who]
  local r = (who == 4 and 20 or 27) * s
  local ear = who == 2 and 1.45 or 1.25
  toon(function()
    toon.line(cx + r * 0.7, cy + r * 1.95, cx + r * 1.4, cy + r * 1.95, 8 * s, body)
    toon.line(cx + r * 1.4, cy + r * 1.95, cx + r * 1.62 + tail * r * 0.15, cy + r * 1.62, 8 * s, body)
    toon.circle(cx + r * 1.62 + tail * r * 0.15, cy + r * 1.58, 4.5 * s, who == 3 and C.WHITE or dark)
    toon.ellipse(cx, cy + r * 1.35, r * 1.05, r * 0.9, body)
    toon.tri(cx - r * 0.95, cy - r * 0.2, cx - r * 0.75, cy - r * ear, cx - r * 0.2, cy - r * 0.8, body)
    toon.tri(cx + r * 0.95, cy - r * 0.2, cx + r * 0.75, cy - r * ear, cx + r * 0.2, cy - r * 0.8, body)
    toon.ellipse(cx, cy, r, r * 0.92, body)
  end, 2.5, INK)
  gfx.tri(cx - r * 0.78, cy - r * 0.35, cx - r * 0.7, cy - r * 1.0, cx - r * 0.38, cy - r * 0.68, 0xffb8c8)
  gfx.tri(cx + r * 0.78, cy - r * 0.35, cx + r * 0.7, cy - r * 1.0, cx + r * 0.38, cy - r * 0.68, 0xffb8c8)
  if who == 2 then
    for k = -1, 1 do gfx.line(cx + k * r * 0.25, cy - r * 0.85, cx + k * r * 0.2, cy - r * 0.5, 3 * s, dark) end
  end
  if who == 1 then gfx.ellipse(cx, cy + r * 0.38, r * 0.55, r * 0.4, C.CREAM) end
  if who == 4 then
    gfx.ellipse(cx - r * 0.45, cy - r * 0.35, r * 0.3, r * 0.35, C.ORANGE)
    gfx.circle(cx + r * 0.3, cy + r * 1.3, r * 0.35, C.ORANGE)
  end
end

local function cat_eyes_open(who, cx, cy, s, lx)
  local r = (who == 4 and 20 or 27) * s
  local ex, ey = r * 0.38, cy - r * 0.08
  local look = clamp(((lx or cx) - cx) * 0.02, -2.5, 2.5)
  for k = -1, 1, 2 do
    gfx.ellipse(cx + k * ex + look, ey, 5 * s, 6.5 * s, INK)
    gfx.circle(cx + k * ex + look + 1.5 * s, ey - 2.5 * s, 1.8 * s, C.WHITE)
  end
end

-- state: "happy", "sleep", "blink" or "open" (open eyes are not in the layer).
local function cat_face(who, cx, cy, s, state)
  local r = (who == 4 and 20 or 27) * s
  local ex, ey = r * 0.38, cy - r * 0.08
  if state == "happy" then
    for k = -1, 1, 2 do
      gfx.line(cx + k * ex - 5 * s, ey + 2, cx + k * ex, ey - 3 * s, 2.5 * s, INK)
      gfx.line(cx + k * ex, ey - 3 * s, cx + k * ex + 5 * s, ey + 2, 2.5 * s, INK)
    end
  elseif state == "sleep" then
    for k = -1, 1, 2 do
      gfx.line(cx + k * ex - 5 * s, ey - 1, cx + k * ex, ey + 2.5 * s, 2.2 * s, INK)
      gfx.line(cx + k * ex, ey + 2.5 * s, cx + k * ex + 5 * s, ey - 1, 2.2 * s, INK)
    end
  elseif state == "blink" then
    gfx.line(cx - ex - 5 * s, ey, cx - ex + 5 * s, ey, 2.5 * s, INK)
    gfx.line(cx + ex - 5 * s, ey, cx + ex + 5 * s, ey, 2.5 * s, INK)
  end
  gfx.ellipse(cx - r * 0.6, cy + r * 0.3, 5 * s, 3 * s, C.BLUSH)
  gfx.ellipse(cx + r * 0.6, cy + r * 0.3, 5 * s, 3 * s, C.BLUSH)
  gfx.tri(cx - 3.5 * s, cy + r * 0.2, cx + 3.5 * s, cy + r * 0.2, cx, cy + r * 0.32, C.ROOF)
  local happy = state == "happy"
  local my, mw, dip = cy + r * 0.36, (happy and 5.5 or 4.5) * s, (happy and 4 or 3) * s
  gfx.line(cx, my, cx - mw * 0.5, my + dip, 1.6 * s, INK)
  gfx.line(cx - mw * 0.5, my + dip, cx - mw, my + dip * 0.2, 1.6 * s, INK)
  gfx.line(cx, my, cx + mw * 0.5, my + dip, 1.6 * s, INK)
  gfx.line(cx + mw * 0.5, my + dip, cx + mw, my + dip * 0.2, 1.6 * s, INK)
  if happy then gfx.ellipse(cx, my + dip * 0.9, 2.2 * s, 1.6 * s, 0xff8fa8) end
  for k = -1, 1, 2 do
    gfx.line(cx + k * r * 0.35, cy + r * 0.3, cx + k * r * 1.05, cy + r * 0.2, 1, alpha(INK, 160))
    gfx.line(cx + k * r * 0.35, cy + r * 0.36, cx + k * r * 1.05, cy + r * 0.42, 1, alpha(INK, 160))
  end
  if who == 3 then
    gfx.tri(cx + r * 0.35, cy - r * 0.75, cx + r * 0.75, cy - r * 0.95, cx + r * 0.7, cy - r * 0.5, C.GOLD)
    gfx.tri(cx + r * 0.35, cy - r * 0.75, cx + r * 0.05, cy - r * 1.0, cx + r * 0.1, cy - r * 0.55, C.GOLD)
    gfx.circle_o(cx + r * 0.38, cy - r * 0.75, 3.5 * s, C.GOLD, INK, 1.5)
  end
end

function P.cat(who, cx, cy, s, mood, lx)
  local blink = ((fr() + (who - 1) * 47) % 200) < 7
  local tail = sin(fr() * 0.07 + who - 1) * 0.6
  local state = mood == "happy" and "happy" or (mood == "sleep" and "sleep" or (blink and "blink" or "open"))
  local s100 = floor(s * 100 + 0.5)
  if abs(s * 100 - s100) > 0.001 or s100 < 20 then
    cat_body(who, cx, cy, s, tail)
    cat_face(who, cx, cy, s, state)
    if state == "open" then cat_eyes_open(who, cx, cy, s, lx) end
    return
  end
  local sc = s100 / 100
  local r = (who == 4 and 20 or 27) * sc
  local tq = floor(tail / 0.3 + 0.5)
  local bl, br, bt, bb = ceil(1.05 * r + 4), ceil(1.75 * r + 7), ceil(1.45 * r + 5), ceil(2.25 * r + 5)
  fig(fmt("cat:%d:%d:%d", who, s100, tq), bl + br, bt + bb, bl, bt, cx, cy, function()
    cat_body(who, 0, 0, sc, tq * 0.3)
  end, 1, function() cat_body(who, cx, cy, s, tail) end)
  local fl, ft, fb = ceil(1.1 * r + 3), ceil(1.05 * r + 6), ceil(0.6 * r + 6)
  fig(fmt("catf:%d:%d:%s", who, s100, state), 2 * fl, ft + fb, fl, ft, cx, cy, function()
    cat_face(who, 0, 0, sc, state)
  end, 1, function() cat_face(who, cx, cy, s, state) end)
  if state == "open" then cat_eyes_open(who, cx, cy, s, lx) end
end

-- The Unicorn from the front, same white, gold horn and four-stripe mane as Tea's. x, y: the head's middle.
local function uni_body(x, y, s)
  toon(function()
    -- Wings, tucked behind the shoulders.
    for side = -1, 1, 2 do
      for k = 0, 2 do
        toon.circle(x + side * (38 + k * 9) * s, y + (30 - k * 9) * s, (11 - k * 2) * s, k == 2 and C.LILAC or C.WHITE)
      end
    end
    -- Mane falls down both sides, one stripe each.
    for side = -1, 1, 2 do
      for k = 0, 3 do
        local sx = x + side * (20 + k * 4) * s
        toon.line(sx, y - 14 * s, sx + side * (3 + k) * s, y + 46 * s, 6 * s, STRIPES[k + 1])
      end
    end
    -- Tail swish behind.
    toon.ellipse(x, y + 52 * s, 34 * s, 30 * s, C.WHITE)
    toon.ellipse(x, y, 24 * s, 26 * s, C.WHITE)
    toon.tri(x - 20 * s, y - 14 * s, x - 17 * s, y - 38 * s, x - 6 * s, y - 22 * s, C.WHITE)
    toon.tri(x + 20 * s, y - 14 * s, x + 17 * s, y - 38 * s, x + 6 * s, y - 22 * s, C.WHITE)
    toon.tri(x - 6 * s, y - 22 * s, x, y - 62 * s, x + 6 * s, y - 22 * s, C.GOLD)
  end, 2.5 * s, INK)
  gfx.line(x - 3.5 * s, y - 34 * s, x + 2.5 * s, y - 38 * s, 1.6 * s, 0xd8a03a)
  gfx.line(x - 3 * s, y - 44 * s, x + 2 * s, y - 48 * s, 1.6 * s, 0xd8a03a)
  gfx.tri(x - 16 * s, y - 20 * s, x - 15 * s, y - 33 * s, x - 9 * s, y - 23 * s, 0xffb8c8)
  gfx.tri(x + 16 * s, y - 20 * s, x + 15 * s, y - 33 * s, x + 9 * s, y - 23 * s, 0xffb8c8)
  -- Forelock: the four mane colours across the forehead.
  for k = 0, 3 do gfx.circle_o(x - 12 * s + k * 8 * s, y - 20 * s + (k % 2) * 3 * s, 5 * s, STRIPES[k + 1], INK, 1.5) end
end

local function uni_eyes_open(x, y, s, lx)
  local ex, ey = 9 * s, y - 2 * s
  local look = clamp(((lx or x) - x) * 0.02, -2.5, 2.5)
  for k = -1, 1, 2 do
    gfx.ellipse(x + k * ex + look, ey, 5 * s, 6.5 * s, INK)
    gfx.circle(x + k * ex + look + 1.5 * s, ey - 2.5 * s, 1.8 * s, C.WHITE)
  end
end

local function uni_face(x, y, s, state)
  local ex, ey = 9 * s, y - 2 * s
  if state == "happy" then
    for k = -1, 1, 2 do
      gfx.line(x + k * ex - 5 * s, ey + 2, x + k * ex, ey - 3 * s, 2.5 * s, INK)
      gfx.line(x + k * ex, ey - 3 * s, x + k * ex + 5 * s, ey + 2, 2.5 * s, INK)
    end
  elseif state == "sleep" then
    for k = -1, 1, 2 do
      gfx.line(x + k * ex - 5 * s, ey - 1, x + k * ex, ey + 2.5 * s, 2.2 * s, INK)
      gfx.line(x + k * ex, ey + 2.5 * s, x + k * ex + 5 * s, ey - 1, 2.2 * s, INK)
    end
  elseif state == "blink" then
    gfx.line(x - ex - 5 * s, ey, x - ex + 5 * s, ey, 2.5 * s, INK)
    gfx.line(x + ex - 5 * s, ey, x + ex + 5 * s, ey, 2.5 * s, INK)
  end
  gfx.ellipse(x - 15 * s, y + 8 * s, 5 * s, 3 * s, C.BLUSH)
  gfx.ellipse(x + 15 * s, y + 8 * s, 5 * s, 3 * s, C.BLUSH)
  gfx.ellipse(x, y + 14 * s, 11 * s, 8 * s, 0xffe4ee)
  gfx.circle(x - 4 * s, y + 13 * s, 1.4 * s, alpha(INK, 190))
  gfx.circle(x + 4 * s, y + 13 * s, 1.4 * s, alpha(INK, 190))
  local happy = state == "happy"
  local my = y + 18 * s
  gfx.line(x - 4 * s, my, x, my + (happy and 4 or 2.5) * s, 1.6 * s, INK)
  gfx.line(x, my + (happy and 4 or 2.5) * s, x + 4 * s, my, 1.6 * s, INK)
end

function P.unicorn(x, y, s, mood, lx)
  local blink = (fr() % 210) < 7
  local state = mood == "happy" and "happy" or (mood == "sleep" and "sleep" or (blink and "blink" or "open"))
  local s100 = floor(s * 100 + 0.5)
  if abs(s * 100 - s100) > 0.001 or s100 < 20 then
    uni_body(x, y, s)
    uni_face(x, y, s, state)
    if state == "open" then uni_eyes_open(x, y, s, lx) end
    return
  end
  local sc = s100 / 100
  local bx, bt, bb = ceil(68 * sc), ceil(66 * sc), ceil(86 * sc)
  fig(fmt("uni:%d", s100), 2 * bx + 2, bt + bb + 2, bx + 1, bt + 1, x, y, function()
    uni_body(0, 0, sc)
  end, 1, function() uni_body(x, y, s) end)
  local fx, ft, fb = ceil(22 * sc), ceil(10 * sc) + 2, ceil(24 * sc) + 2
  fig(fmt("unif:%d:%s", s100, state), 2 * fx + 2, ft + fb, fx + 1, ft, x, y, function()
    uni_face(0, 0, sc, state)
  end, 1, function() uni_face(x, y, s, state) end)
  if state == "open" then uni_eyes_open(x, y, s, lx) end
end

-- ------------------------------------------------------------------ flowers

local function face(cx, cy, s, happy, cream)
  local ex = 5 * s
  local eye = cream and C.CREAM or INK
  if happy then
    for k = -1, 1, 2 do
      gfx.line(cx + k * ex - 3 * s, cy + s, cx + k * ex, cy - 2 * s, 1.8 * s, eye)
      gfx.line(cx + k * ex, cy - 2 * s, cx + k * ex + 3 * s, cy + s, 1.8 * s, eye)
    end
  else
    gfx.circle(cx - ex, cy, 2.2 * s, eye)
    gfx.circle(cx + ex, cy, 2.2 * s, eye)
    if not cream then
      gfx.circle(cx - ex + 0.8 * s, cy - 0.9 * s, 0.8 * s, C.WHITE)
      gfx.circle(cx + ex + 0.8 * s, cy - 0.9 * s, 0.8 * s, C.WHITE)
    end
  end
  if not cream then
    gfx.ellipse(cx - ex - 3 * s, cy + 4 * s, 3 * s, 2 * s, C.BLUSH)
    gfx.ellipse(cx + ex + 3 * s, cy + 4 * s, 3 * s, 2 * s, C.BLUSH)
  end
  gfx.line(cx - 3 * s, cy + 4 * s, cx, cy + 6.5 * s, 1.5 * s, eye)
  gfx.line(cx, cy + 6.5 * s, cx + 3 * s, cy + 4 * s, 1.5 * s, eye)
end

-- A flower head, outlined as one toon figure. kind 1..6 (tulip, daisy, sunflower, rose, star-lily, rainbow
-- rose), middle at cx, cy, scale s, petal colour col. It is two pictures, the petals and the face, so a
-- bloom on a bed is two kept layers (P.flower).
local function head_body(kind, cx, cy, s, col)
  local lite, dark = mix(col, 0xffffff, 0.5), mix(col, INK, 0.3)
  if kind == 1 then
    toon(function()
      toon.ellipse(cx, cy + 3 * s, 15 * s, 17 * s, col)
      toon.tri(cx - 15 * s, cy - 2 * s, cx - 13 * s, cy - 24 * s, cx - 2 * s, cy - 8 * s, col)
      toon.tri(cx + 15 * s, cy - 2 * s, cx + 13 * s, cy - 24 * s, cx + 2 * s, cy - 8 * s, col)
      toon.tri(cx - 9 * s, cy - 6 * s, cx, cy - 29 * s, cx + 9 * s, cy - 6 * s, col)
    end, 2, INK)
    gfx.ellipse(cx - 8 * s, cy, 2.5 * s, 8 * s, alpha(0xffffff, 100))
  elseif kind == 2 then
    toon(function()
      for k = 0, 7 do
        local a = k * 0.7854 + 0.2
        toon.line(cx + cos(a) * 9 * s, cy + sin(a) * 9 * s, cx + cos(a) * 21 * s, cy + sin(a) * 21 * s, 10 * s, col)
      end
      toon.circle(cx, cy, 11 * s, 0xffe36a)
    end, 2, INK)
  elseif kind == 3 then
    toon(function()
      for k = 0, 11 do
        local a = k * 0.5236
        toon.line(cx + cos(a) * 12 * s, cy + sin(a) * 12 * s, cx + cos(a) * 25 * s, cy + sin(a) * 25 * s, 8 * s, col)
      end
      toon.circle(cx, cy, 14 * s, 0x7a4a2a)
    end, 2, INK)
    for k = 0, 6 do
      gfx.circle(cx + cos(k * 0.9) * 9.5 * s, cy + sin(k * 0.9) * 9.5 * s, 1.1 * s, 0xa8703e)
    end
  elseif kind == 4 then
    toon(function()
      for k = 0, 5 do
        local a = k * 1.0472
        toon.circle(cx + cos(a) * 13 * s, cy + sin(a) * 13 * s, 10 * s, col)
      end
      toon.circle(cx, cy, 14 * s, lite)
    end, 2, INK)
    gfx.ring(cx, cy, 13 * s, 1.6, dark)
  elseif kind == 5 then
    toon(function()
      toon.tri(cx - 23 * s, cy + 13 * s, cx + 23 * s, cy + 13 * s, cx, cy - 27 * s, col)
      toon.tri(cx - 23 * s, cy - 13 * s, cx + 23 * s, cy - 13 * s, cx, cy + 27 * s, col)
      toon.circle(cx, cy, 11 * s, lite)
    end, 2, INK)
  else
    toon(function()
      for k = 0, 5 do
        local a = k * 1.0472
        toon.circle(cx + cos(a) * 13 * s, cy + sin(a) * 13 * s, 10 * s, RAINBOW[k + 1])
      end
      toon.circle(cx, cy, 14 * s, col)
    end, 2, INK)
    gfx.ring(cx, cy, 10 * s, 2, alpha(0xffffff, 150))
  end
end

local function head_face(kind, cx, cy, s, happy)
  if kind == 1 then face(cx, cy + 4 * s, s, happy)
  elseif kind == 2 then face(cx, cy - s, 0.95 * s, happy)
  elseif kind == 3 then face(cx, cy - s, 0.95 * s, happy, true)
  else face(cx, cy - s, 0.9 * s, happy) end
end

function P.head(kind, cx, cy, s, col, happy)
  head_body(kind, cx, cy, s, col)
  -- The rainbow rose's soft light shimmers over its face.
  if kind == 6 then gfx.glow(cx, cy, 20 * s, alpha(0xffffff, 60 + floor(40 * sin(fr() * 0.1)))) end
  head_face(kind, cx, cy, s, happy)
end

-- How far a petal reaches from the middle, per kind: left/right, up, down (at scale 1).
local HX, HT, HB = {19, 28, 31, 25, 25, 25}, {31, 28, 31, 25, 29, 25}, {22, 28, 31, 25, 29, 25}
-- The size steps a bloom is kept at; a bloom between two steps is the nearer one, drawn a little larger or
-- smaller. Growing (0.45 up to 1) and the beat's bounce (up to 1.16) are the only times it is not step 1.
local RSTEP = {0.6, 1, 1.12}
local COLIX = {}
for i, c in ipairs(P.COLS) do COLIX[c] = i end

-- A flower head on a bed: petals and face as one kept layer per kind, colour, happiness and size step.
function P.flower(kind, cx, cy, s, col, happy)
  local ri = s < 0.8 and 1 or (s < 1.06 and 2 or 3)
  local R = RSTEP[ri]
  local ci = COLIX[col] or 0
  local hx, ht, hb = ceil(HX[kind] * R) + 2, ceil(HT[kind] * R) + 2, ceil(HB[kind] * R) + 2
  local k = s / R
  if abs(k - 1) < 0.002 then k = 1 end
  local hp = happy and 1 or 0
  -- The rainbow rose's soft light shimmers over its face: that one is drawn live, between petals and face.
  if kind == 6 then
    fig(fmt("hb:%d:%d:%d", kind, ci, ri), 2 * hx, ht + hb, hx, ht, cx, cy, function()
      head_body(kind, 0, 0, R, col)
    end, k, function() head_body(kind, cx, cy, s, col) end, true)
    gfx.glow(cx, cy, 20 * s, alpha(0xffffff, 60 + floor(40 * sin(fr() * 0.1))))
    local fx, ft, fb = ceil(13 * R) + 2, ceil(5.5 * R) + 2, ceil(8 * R) + 2
    fig(fmt("hf:%d:%d:%d", kind, hp, ri), 2 * fx, ft + fb, fx, ft, cx, cy, function()
      head_face(kind, 0, 0, R, happy)
    end, k, function() head_face(kind, cx, cy, s, happy) end)
    return
  end
  fig(fmt("hb:%d:%d:%d:%d", kind, ci, hp, ri), 2 * hx, ht + hb, hx, ht, cx, cy, function()
    head_body(kind, 0, 0, R, col)
    head_face(kind, 0, 0, R, happy)
  end, k, function() head_body(kind, cx, cy, s, col) head_face(kind, cx, cy, s, happy) end, true)
end

local HS = {0, 0, 24, 46, 60}

-- The stalk with its two leaves, and the bud on it. (x, y + 6) is the foot of the stalk, tx, ty its top.
local function stalk(x, y, st, tx, ty)
  toon(function()
    toon.line(x, y + 6, tx, ty, 5, C.LEAF)
    if st == 2 then
      toon.ellipse(tx - 8, ty + 3, 8, 4, C.LEAF)
      toon.ellipse(tx + 8, ty, 8, 4, C.LEAF)
    else
      local lx, ly = lerp(x, tx, 0.45), lerp(y + 6, ty, 0.45)
      toon.ellipse(lx - 10, ly - 3, 10, 4.5, C.LEAF)
      local mx, my = lerp(x, tx, 0.7), lerp(y + 6, ty, 0.7)
      toon.ellipse(mx + 10, my - 3, 10, 4.5, C.LEAF)
    end
  end, 2, INK)
end

local function bud(tx, ty, bs, col)
  toon(function()
    toon.ellipse(tx, ty - 9 * bs, 8 * bs, 11 * bs, col)
    toon.tri(tx - 6 * bs, ty - 12 * bs, tx, ty - 26 * bs, tx + 6 * bs, ty - 12 * bs, col)
    toon.tri(tx - 9 * bs, ty - 2, tx - 3, ty - 9 * bs, tx - 1, ty + 1, C.LEAFD)
    toon.tri(tx + 9 * bs, ty - 2, tx + 3, ty - 9 * bs, tx + 1, ty + 1, C.LEAFD)
  end, 2, INK)
  gfx.line(tx - 2, ty - 8 * bs, tx - 2, ty - 18 * bs, 2, alpha(0xffffff, 120))
end

-- One bed's plant. st 1 seed, 2 sprout, 3 bud, 4 bloom; k 0..1 how far into the stage it has grown.
-- sway: a sideways swing of the stem top; pulse: the flower singing now (0..1).
-- Once a stage has grown (k = 1) its stalk is a kept layer per pixel of sway, its bud one per colour.
function P.plant(x, y, st, k, kind, col, sway, pulse, happy)
  if st == 1 then
    local sq = 1 + (1 - k) * 0.5
    toon(function() toon.ellipse(x, y + 1, 6 * sq, 8 * sq, col) end, 1.8, INK)
    gfx.ellipse(x - 2, y - 1, 1.5, 3, alpha(0xffffff, 140))
    gfx.ellipse(x, y + 8, 14, 5, C.SOIL)
    return
  end
  local h = lerp(HS[st - 1], HS[st], k)
  local tx, ty = x + sway * (h / 60), y + 6 - h
  if k >= 1 then
    local sq = floor(sway + 0.5)
    local hh = HS[st]
    local ttx = sq * (hh / 60)
    local top = hh + 9
    fig(fmt("stalk:%d:%d", st, sq), 60, top + 8, 30, top, x, y + 6, function()
      stalk(0, -6, st, ttx, -hh)
    end, 1, function() stalk(x, y, st, tx, ty) end)
  else
    stalk(x, y, st, tx, ty)
  end
  if st == 3 then
    local bs = 0.7 + 0.3 * k
    if k >= 1 then
      fig(fmt("bud:%x", col), 30, 36, 15, 30, tx, ty, function() bud(0, 0, 1, col) end, 1, function() bud(tx, ty, 1, col) end, true)
    else
      bud(tx, ty, bs, col)
    end
  elseif st == 4 then
    local o = 0.45 + 0.55 * ease.out_back(min(1, k))
    local ps = o * (1 + 0.16 * pulse)
    P.flower(kind, tx, ty - 6 - 6 * pulse, ps, col, happy or pulse > 0.2)
  end
end

-- ------------------------------------------------------------------ what a bed wants

-- A bubble over the bed with a picture in it: what = "seed", "drop", "sun" or "note". tx, ty: where the tail points.
function P.want(what, x, y, r, tx, ty, ci)
  toon(function()
    toon.tri(x - r * 0.4, y + r * 0.7, x + r * 0.4, y + r * 0.7, tx, ty, C.WHITE)
    toon.circle(x, y, r, C.WHITE)
  end, 2, INK)
  local s = r / 18
  if what == "seed" then
    toon(function() toon.ellipse(x, y + s, 7 * s, 10 * s, P.COLS[ci]) end, 1.6, INK)
    gfx.ellipse(x - 2 * s, y - 2 * s, 1.6 * s, 3.5 * s, alpha(0xffffff, 170))
    gfx.star(x + 9 * s, y - 9 * s, 3.5 * s, fr() * 0.05, C.GOLD)
  elseif what == "drop" then
    toon(function()
      toon.tri(x - 8 * s, y + 2 * s, x + 8 * s, y + 2 * s, x, y - 13 * s, C.DROP)
      toon.circle(x, y + 3 * s, 8.5 * s, C.DROP)
    end, 1.6, INK)
    gfx.ellipse(x - 3 * s, y + 3 * s, 2 * s, 3.5 * s, alpha(0xffffff, 190))
  elseif what == "sun" then
    local a0 = fr() * 0.03
    for k = 0, 7 do
      local a = a0 + k * 0.7854
      gfx.line(x + cos(a) * 9.5 * s, y + sin(a) * 9.5 * s, x + cos(a) * 15 * s, y + sin(a) * 15 * s, 4 * s, INK)
    end
    for k = 0, 7 do
      local a = a0 + k * 0.7854
      gfx.line(x + cos(a) * 9.5 * s, y + sin(a) * 9.5 * s, x + cos(a) * 15 * s, y + sin(a) * 15 * s, 2 * s, C.SUN)
    end
    gfx.circle_o(x, y, 8 * s, C.SUN, INK, 1.6)
  else
    gfx.line(x + 3 * s, y + 6 * s, x + 3 * s, y - 11 * s, 3.4 * s, INK)
    gfx.line(x + 3 * s, y - 11 * s, x + 10 * s, y - 4 * s, 4 * s, INK)
    gfx.ellipse_o(x - 2.5 * s, y + 7 * s, 6.5 * s, 5 * s, C.ROOF, INK, 1.6)
    gfx.line(x + 3 * s, y + 5 * s, x + 3 * s, y - 10 * s, 1.5 * s, C.ROOF)
    gfx.line(x + 3 * s, y - 10 * s, x + 9 * s, y - 4.5 * s, 2 * s, C.ROOF)
  end
end

-- A drifting music note, for the song she sings to a bud. a: 0..1 fade.
function P.note(x, y, s, col, a)
  local c = alpha(col, floor(255 * a))
  gfx.line(x + 4 * s, y + 3 * s, x + 4 * s, y - 14 * s, 2.4 * s, c)
  gfx.line(x + 4 * s, y - 14 * s, x + 10 * s, y - 8 * s, 2.6 * s, c)
  gfx.ellipse(x, y + 4 * s, 5.5 * s, 4 * s, c)
end

-- ------------------------------------------------------------------ the fairy, her pouch and the fairy ring

-- x, y: her head. dir: where she looks (-1, 0, 1). pc: pouch colour (next seed). flap: 0..1 wing.
-- At her usual size the wings (six beats), the dress and hair, the face (six looks), the pouch (one per colour)
-- and the wand's star (twelve turns) are kept layers; the wand and the pouch's string and glow stay live.
local function fairy_wings(x, y, s, wy)
  gfx.ellipse_o(x - 13 * s, y + 2 * s, 11 * s * wy, 17 * s, alpha(0xd8ecff, 215), INK, 1.5)
  gfx.ellipse_o(x + 13 * s, y + 2 * s, 11 * s * wy, 17 * s, alpha(0xd8ecff, 215), INK, 1.5)
  gfx.ellipse_o(x - 10 * s, y + 18 * s, 7 * s * wy, 10 * s, alpha(0xffd0ec, 215), INK, 1.5)
  gfx.ellipse_o(x + 10 * s, y + 18 * s, 7 * s * wy, 10 * s, alpha(0xffd0ec, 215), INK, 1.5)
end

local function fairy_body(x, y, s)
  toon(function()
    toon.tri(x - 13 * s, y + 38 * s, x + 13 * s, y + 38 * s, x, y + 14 * s, 0xc9a8f0)
    toon.circle(x + 11 * s, y - 8 * s, 6 * s, 0xf2a03a)
    toon.circle(x, y, 12 * s, 0xffe2cc)
  end, 2.2, INK)
  gfx.ellipse(x, y - 9 * s, 12 * s, 5.5 * s, 0xf2a03a)
  gfx.circle(x - 6 * s, y - 8 * s, 4 * s, 0xf2a03a)
  gfx.circle(x + 6 * s, y - 8 * s, 4 * s, 0xf2a03a)
  gfx.tri(x - 4 * s, y - 15 * s, x, y - 24 * s, x + 4 * s, y - 15 * s, C.SUN)
end

local function fairy_face(x, y, s, shut, dir)
  local ex = 4.5 * s
  local look = dir * 1.5 * s
  if shut then
    for k = -1, 1, 2 do
      gfx.line(x + k * ex + look - 3 * s, y + 1.5 * s, x + k * ex + look, y - 1.5 * s, 1.8 * s, INK)
      gfx.line(x + k * ex + look, y - 1.5 * s, x + k * ex + look + 3 * s, y + 1.5 * s, 1.8 * s, INK)
    end
  else
    gfx.circle(x - ex + look, y, 2.1 * s, INK)
    gfx.circle(x + ex + look, y, 2.1 * s, INK)
  end
  gfx.ellipse(x - 8.5 * s, y + 5 * s, 3 * s, 2 * s, C.BLUSH)
  gfx.ellipse(x + 8.5 * s, y + 5 * s, 3 * s, 2 * s, C.BLUSH)
  gfx.line(x - 3 * s, y + 6 * s, x, y + 8.5 * s, 1.5 * s, INK)
  gfx.line(x, y + 8.5 * s, x + 3 * s, y + 6 * s, 1.5 * s, INK)
end

local function fairy_pouch(px, py, s, pc)
  toon(function() toon.circle(px, py, 8.5 * s, pc) end, 2, INK)
  gfx.tri(px - 4 * s, py - 6 * s, px, py - 13 * s, px + 4 * s, py - 6 * s, 0xf4d8a0)
  gfx.circle(px - 3 * s, py - 2 * s, 2 * s, alpha(0xffffff, 130))
end

function P.fairy(x, y, s, dir, happy, flap, pc, kind)
  local blink = (fr() % 190) < 6
  local t = fr()
  local wy = 0.7 + 0.3 * flap
  local s100 = floor(s * 100 + 0.5)
  local kept_s = abs(s * 100 - s100) < 0.001 and s100 >= 20
  local sc = s100 / 100
  if kept_s then
    local q = floor((wy - 0.7) / 0.06 + 0.5)
    local wx, wt, wb = ceil(27 * sc) + 2, ceil(18 * sc) + 2, ceil(30 * sc) + 2
    fig(fmt("fwing:%d:%d", s100, q), 2 * wx, wt + wb, wx, wt, x, y, function() fairy_wings(0, 0, sc, 0.7 + 0.06 * q) end, 1,
      function() fairy_wings(x, y, s, wy) end)
  else
    fairy_wings(x, y, s, wy)
  end
  -- Wand arm.
  local wx, wy2 = x + 25 * s, y - 2 * s + sin(t * 0.12) * 3
  gfx.line(x + 6 * s, y + 20 * s, wx, wy2 + 5 * s, 4 * s, INK)
  gfx.line(x + 6 * s, y + 20 * s, wx, wy2 + 5 * s, 2 * s, 0xffe2cc)
  gfx.line(wx, wy2 + 5 * s, wx + 3 * s, wy2 - 8 * s, 3 * s, 0xf4d8a0)
  gfx.glow(wx + 3 * s, wy2 - 10 * s, 14 * s, alpha(0xfff0a0, 140))
  if kept_s then
    local u = floor((t * 0.08 % 1.2566) / 1.2566 * 12 + 0.5) % 12
    local sr = 6 * s
    local hr = ceil(sr) + 2
    fig(fmt("fstar:%d:%d", s100, u), 2 * hr, 2 * hr, hr, hr, wx + 3 * s, wy2 - 10 * s, function()
      gfx.star(0, 0, 6 * sc, u / 12 * 1.2566, C.SUN)
    end, 1, function() gfx.star(wx + 3 * s, wy2 - 10 * s, sr, t * 0.08, C.SUN) end)
  else
    gfx.star(wx + 3 * s, wy2 - 10 * s, 6 * s, t * 0.08, C.SUN)
  end
  local shut = happy or blink
  if kept_s then
    local bl, br, bt, bb = ceil(15 * sc) + 3, ceil(19 * sc) + 3, ceil(26 * sc) + 3, ceil(40 * sc) + 3
    fig("fbody:" .. s100, bl + br, bt + bb, bl, bt, x, y, function() fairy_body(0, 0, sc) end, 1,
      function() fairy_body(x, y, s) end)
    local fx, ft, fb = ceil(14 * sc) + 2, ceil(5 * sc) + 2, ceil(10 * sc) + 2
    fig(fmt("fface:%d:%d:%d", s100, shut and 1 or 0, dir), 2 * fx, ft + fb, fx, ft, x, y, function()
      fairy_face(0, 0, sc, shut, dir)
    end, 1, function() fairy_face(x, y, s, shut, dir) end)
  else
    fairy_body(x, y, s)
    fairy_face(x, y, s, shut, dir)
  end
  -- The seed pouch, hanging at her side: its colour is the next seed's.
  local px, py = x - 17 * s, y + 30 * s + sin(t * 0.1) * 1.5
  gfx.line(x - 8 * s, y + 22 * s, px + 2 * s, py - 6 * s, 1.6, INK)
  if kept_s then
    local pr, pt, pb = ceil(11 * sc) + 2, ceil(14 * sc) + 2, ceil(11 * sc) + 2
    fig(fmt("fpouch:%d:%x", s100, pc), 2 * pr, pt + pb, pr, pt, px, py, function() fairy_pouch(0, 0, sc, pc) end, 1,
      function() fairy_pouch(px, py, s, pc) end)
  else
    fairy_pouch(px, py, s, pc)
  end
  gfx.glow(px, py, 14 * s, alpha(pc, 90))
end

-- The ring of toadstools round the bed she is at. cx, cy: the bed's soil; t: frames.
-- A toadstool is a kept layer in one of five sizes (sc is rounded to 0.1, under a pixel's difference).
local function mushroom(mx, my, sc)
  gfx.ellipse_o(mx, my - 3 * sc, 3.2 * sc, 5 * sc, C.CREAM, INK, 1.3)
  gfx.ellipse_o(mx, my - 8 * sc, 7.5 * sc, 5.5 * sc, 0xe85a6a, INK, 1.5)
  gfx.circle(mx - 2.5 * sc, my - 9 * sc, 1.3 * sc, C.WHITE)
  gfx.circle(mx + 2.5 * sc, my - 7 * sc, 1.1 * sc, C.WHITE)
end

function P.ring(cx, cy, t)
  for k = 0, 8 do
    local a = t * 0.012 + k * 0.6981
    local mx, my = cx + cos(a) * 52, cy + 13 + sin(a) * 19
    local sc = 0.85 + 0.2 * sin(a)
    local q = clamp(floor((sc - 0.65) / 0.1 + 0.5), 0, 4)
    if game.gpu then sheet_draw("small", MU0 + q + 1, mx, my) else mushroom(mx, my, sc) end
  end
  gfx.glow(cx, cy + 10, 52, alpha(0xfff0a0, 70 + floor(25 * sin(t * 0.14))))
end

-- ------------------------------------------------------------------ visitors

-- A butterfly. flap: 0..1 how open the wings are (eight steps: one pixel of wing each).
local function butterfly(x, y, col, flap)
  local w = 3 + 8 * flap
  local lite = mix(col, 0xffffff, 0.5)
  gfx.ellipse_o(x - 7, y - 3, w, 8, col, INK, 1.4)
  gfx.ellipse_o(x + 7, y - 3, w, 8, col, INK, 1.4)
  gfx.ellipse_o(x - 5, y + 5, w * 0.7, 5, lite, INK, 1.2)
  gfx.ellipse_o(x + 5, y + 5, w * 0.7, 5, lite, INK, 1.2)
  gfx.circle(x - 7, y - 4, 1.8 * flap + 0.6, C.WHITE)
  gfx.circle(x + 7, y - 4, 1.8 * flap + 0.6, C.WHITE)
  gfx.ellipse(x, y + 1, 2, 7, INK)
  gfx.line(x, y - 5, x - 3, y - 10, 1, INK)
  gfx.line(x, y - 5, x + 3, y - 10, 1, INK)
end

function P.butterfly(x, y, col, flap)
  if not game.gpu then return butterfly(x, y, col, flap) end
  local q = floor(flap * 8 + 0.5)
  sheet_draw("small", BF0 + (COLIX[col] - 1) * 9 + q + 1, x, y)
end

-- The bee. sq: how hard the beat just landed (0..1), it squashes; dir: -1 or 1.
function P.bee(x, y, sq, dir)
  local w = abs(sin(fr() * 0.9))
  gfx.ellipse_o(x - 3 * dir, y - 8 - w * 3, 6, 4 + w * 3, alpha(0xe8f4ff, 220), INK, 1.2)
  gfx.ellipse_o(x + 3 * dir, y - 8 - w * 3, 6, 4 + w * 3, alpha(0xe8f4ff, 220), INK, 1.2)
  local ry = 7 * (1 - 0.15 * sq)
  gfx.ellipse_o(x, y, 10 * (1 + 0.12 * sq), ry, C.SUN, INK, 1.8)
  gfx.line(x - 3, y - ry + 1, x - 3, y + ry - 1, 2.6, INK)
  gfx.line(x + 3, y - ry + 1, x + 3, y + ry - 1, 2.6, INK)
  gfx.circle_o(x + 10 * dir, y - 1, 5, C.SUN, INK, 1.6)
  gfx.circle(x + 11.5 * dir, y - 2, 1.3, INK)
  gfx.tri(x - 10 * dir, y - 2, x - 10 * dir, y + 2, x - 15 * dir, y, INK)
end

function P.ladybug(x, y, s, open)
  if open > 0 then
    gfx.ellipse_o(x - 5 * s, y - 6 * s - open * 4, 5 * s, 3 * s, alpha(0xe8f4ff, 220), INK, 1)
    gfx.ellipse_o(x + 5 * s, y - 6 * s - open * 4, 5 * s, 3 * s, alpha(0xe8f4ff, 220), INK, 1)
  end
  gfx.circle_o(x, y, 7 * s, 0xe84a4a, INK, 1.6)
  gfx.line(x, y - 6 * s, x, y + 6 * s, 1.4, INK)
  gfx.circle(x - 3 * s, y - 1 * s, 1.5 * s, INK)
  gfx.circle(x + 3 * s, y + 2 * s, 1.5 * s, INK)
  gfx.circle(x - 2.5 * s, y + 4 * s, 1.2 * s, INK)
  gfx.circle(x + 2.5 * s, y - 3 * s, 1.2 * s, INK)
  gfx.circle_o(x, y - 8 * s, 3.2 * s, INK, INK, 1)
end

-- dir: 1 crawling right, -1 left.
function P.snail(x, y, dir, t)
  gfx.line(x - dir * 36, y + 8, x - dir * 8, y + 8, 3, alpha(0xffffff, 70))
  toon(function()
    toon.ellipse(x, y + 5, 16, 5.5, 0xf0c8a0)
    toon.circle(x + dir * 15, y + 1, 5, 0xf0c8a0)
    toon.circle(x - dir * 2, y - 4, 10, 0xd8905c)
  end, 1.8, INK)
  gfx.ring(x - dir * 2, y - 4, 5.5, 1.5, 0xa8603a)
  gfx.circle(x - dir * 2, y - 4, 2, 0xa8603a)
  local nod = sin(t * 0.08) * 1.5
  for k = -1, 1, 2 do
    gfx.line(x + dir * (15 + k * 2.5), y - 1, x + dir * (17 + k * 4), y - 10 + nod, 1.5, INK)
    gfx.circle(x + dir * (17 + k * 4), y - 10 + nod, 2, INK)
  end
  gfx.circle(x + dir * 17, y + 2, 1.2, INK)
end

-- The rare hedgehog. curl: 0 walking .. 1 rolled in a ball.
function P.hedgehog(x, y, curl, dir)
  local r = 13 - curl * 2
  toon(function()
    for k = -3, 3 do
      toon.tri(x + k * 4 - 4, y - 4, x + k * 4 + 4, y - 4, x + k * 4 - dir * 1.5, y - r - 8 + abs(k) * 1.5, 0x8a5a40)
    end
    toon.ellipse(x, y + 2, r + 3, r, 0xb07850)
    if curl < 0.5 then toon.circle(x + dir * 12, y + 5, 6.5, 0xf4d8b8) end
    toon.ellipse(x - 6, y + r + 1, 4, 2.5, 0x8a5a40)
    toon.ellipse(x + 6, y + r + 1, 4, 2.5, 0x8a5a40)
  end, 2, INK)
  if curl < 0.5 then
    gfx.circle(x + dir * 14, y + 4, 1.5, INK)
    gfx.circle(x + dir * 18, y + 7, 2, INK)
  else
    gfx.circle(x - 3, y + 1, 1.5, INK)
    gfx.circle(x + 3, y + 1, 1.5, INK)
  end
end

local function firefly(x, y, lit)
  gfx.ellipse(x - 4, y - 3, 3.5, 1.8, alpha(0xffffff, 170))
  gfx.ellipse(x + 4, y - 3, 3.5, 1.8, alpha(0xffffff, 170))
  gfx.circle_o(x, y, 3.8, lit and 0xfff6a0 or 0xc8a850, INK, 1.2)
end

-- The light and the bug are drawn apart so a swarm's lights go down together (one blend change, not one each).
function P.firefly_glow(x, y, g)
  gfx.glow(x, y, 16, alpha(0xfff080, floor(150 * g)))
end

function P.firefly(x, y, g)
  if game.gpu then sheet_draw("small", FF0 + (g > 0.5 and 2 or 1), x, y) else firefly(x, y, g > 0.5) end
end

function P.rain_cloud(x, y)
  toon(function()
    toon.circle(x - 17, y + 4, 13, C.WHITE)
    toon.circle(x + 17, y + 4, 13, C.WHITE)
    toon.circle(x, y - 4, 18, C.WHITE)
    toon.circle(x - 6, y + 8, 12, C.WHITE)
    toon.circle(x + 7, y + 8, 12, C.WHITE)
  end, 2, INK)
  gfx.circle(x - 6, y - 2, 1.7, INK)
  gfx.circle(x + 6, y - 2, 1.7, INK)
  gfx.line(x - 3, y + 3, x, y + 5.5, 1.5, INK)
  gfx.line(x, y + 5.5, x + 3, y + 3, 1.5, INK)
end

-- The sun in the corner of the sky. glad: it beams.
-- The disc and face are two kept layers (glad or not); the twelve rays turn once every 43 frames, kept in
-- twelve turns of their ring, and drawn live only while the sun beams.
local function sun_rays(x, y, a0, r)
  for k = 0, 11 do
    local a = a0 + k * 0.5236
    gfx.line(x + cos(a) * (r + 5), y + sin(a) * (r + 5), x + cos(a) * (r + 13), y + sin(a) * (r + 13), 4.5, C.SUN)
  end
end

function P.sun(x, y, t, glad)
  local r = 22 + (glad and 4 or 0)
  gfx.glow(x, y, r * 2.6, alpha(0xfff0a0, glad and 150 or 90))
  local a0 = t * 0.012
  if glad then
    sun_rays(x, y, a0, r)
  else
    local q = floor((a0 % 0.5236) / 0.5236 * 12 + 0.5) % 12
    fig("sunr:" .. q, 80, 80, 40, 40, x, y, function() sun_rays(0, 0, q / 12 * 0.5236, 22) end, 1,
      function() sun_rays(x, y, a0, r) end)
  end
  fig(glad and "sund:1" or "sund:0", 64, 64, 32, 32, x, y, function()
    gfx.circle_o(0, 0, r, 0xffe680, INK, 2.5)
    face(0, -2, 1.1, glad)
  end, 1, function()
    gfx.circle_o(x, y, r, 0xffe680, INK, 2.5)
    face(x, y - 2, 1.1, glad)
  end)
end

-- ------------------------------------------------------------------ bouquets, vase and packets

-- n flowers tied with a ribbon. kinds, cis: arrays of kind and colour index. x, y: the middle of the heads.
function P.bouquet(x, y, s, n, kinds, cis, happy)
  local sp = 24 * s
  for k = 1, n do
    local hx = x + (k - (n + 1) / 2) * sp
    local hy = y + ((k == 2 or k == 3) and -14 * s or 0)
    gfx.line(x, y + 62 * s, hx, hy + 12 * s, 4 * s, INK)
    gfx.line(x, y + 62 * s, hx, hy + 12 * s, 2.4 * s, C.LEAF)
  end
  toon(function()
    toon.tri(x - 30 * s, y + 24 * s, x + 30 * s, y + 24 * s, x, y + 84 * s, C.CREAM)
  end, 2.2, INK)
  gfx.tri(x - 14 * s, y + 30 * s, x + 4 * s, y + 28 * s, x - 2 * s, y + 70 * s, alpha(0xf4b6d0, 200))
  for k = 1, n do
    local hx = x + (k - (n + 1) / 2) * sp
    local hy = y + ((k == 2 or k == 3) and -14 * s or 0)
    P.head(kinds[k], hx, hy, 0.82 * s, P.COLS[cis[k]], happy)
  end
  toon(function()
    toon.tri(x, y + 40 * s, x - 20 * s, y + 30 * s, x - 20 * s, y + 50 * s, C.ROOF)
    toon.tri(x, y + 40 * s, x + 20 * s, y + 30 * s, x + 20 * s, y + 50 * s, C.ROOF)
    toon.circle(x, y + 40 * s, 6 * s, C.ROOF)
  end, 2, INK)
end

-- A little glass vase of the last bouquet, from its saved colour indexes (0 = none).
function P.vase(x, y, c1, c2, c3, c4)
  local cs = {c1, c2, c3, c4}
  for k = 1, 4 do
    if cs[k] > 0 then
      local hx, hy = x + (k - 2.5) * 11, y - 22 - ((k == 2 or k == 3) and 6 or 0)
      gfx.line(x + (k - 2.5) * 3, y, hx, hy, 2, C.LEAFD)
      gfx.circle_o(hx, hy, 5.5, P.COLS[cs[k]], INK, 1.4)
      gfx.circle(hx, hy, 1.8, C.SUN)
    end
  end
  toon(function()
    toon.ellipse(x, y + 8, 12, 12, 0xcfe8ff)
    toon.rrect(x - 6, y - 4, 12, 10, 3, 0xcfe8ff)
  end, 1.8, INK)
  gfx.ellipse(x - 5, y + 6, 2, 5, alpha(0xffffff, 190))
end

-- A seed packet on the shelf. state: 0 locked, 1 open, 2 next to be planted. x: middle, y: top.
-- The packet itself is a kept layer per kind (locked or open); its glow and new-star stay live.
local function packet(kind, x, y, state)
  if state == 0 then
    gfx.rrect_o(x - 19, y, 38, 34, 5, 0xb8aec4, INK, 2)
    gfx.rrect_o(x - 8, y + 15, 16, 12, 3, 0x6a5a88, INK, 1.6)
    gfx.ring(x, y + 14, 5, 2.4, 0x6a5a88)
    gfx.circle(x, y + 21, 1.8, INK)
  else
    gfx.rrect_o(x - 19, y, 38, 34, 5, C.CREAM, INK, 2)
    gfx.rect(x - 17, y + 2, 34, 6, P.COLS[(kind - 1) % 6 + 1])
    P.head(kind, x, y + 20, 0.4, P.COLS[(kind - 1) % 6 + 1], false)
  end
end

function P.packet(kind, x, y, state, t, fresh)
  local lift = state == 2 and -abs(sin(t * 0.1)) * 3 or 0
  y = y + lift
  if state == 2 then gfx.glow(x, y + 16, 34, alpha(0xfff0a0, 150)) end
  local open = state == 0 and 0 or 1
  if game.gpu then sheet_draw("small", PK0 + (kind - 1) * 2 + open + 1, x, y) else packet(kind, x, y, open) end
  if open == 1 and fresh then gfx.star(x + 17, y + 3, 8 + sin(t * 0.2) * 2, t * 0.03, C.GOLD) end
end

-- The two boxes of the corner display (the blooms so far, and the count), and its dots (0 = empty).
function P.hud_left()
  fig("hud:l", 128, 30, 2, 2, 8, 8, function() gfx.rrect_o(0, 0, 124, 26, 11, C.CREAM, INK, 2) end)
end
function P.hud_right(x)
  fig("hud:r", 94, 30, 2, 2, x, 8, function()
    gfx.rrect_o(0, 0, 90, 26, 11, C.CREAM, INK, 2)
    P.head(1, 18, 17, 0.38, P.COLS[1], false)
  end)
end
local function dot(x, y, ci)
  if ci > 0 then gfx.circle_o(x, y, 7.5, P.COLS[ci], INK, 1.6)
  else gfx.circle_o(x, y, 6.5, 0xe8dccc, 0xb8a8b8, 1.5) end
end
function P.dot(x, y, ci)
  if game.gpu then sheet_draw("small", DOT0 + ci + 1, x, y) else dot(x, y, ci) end
end

-- ------------------------------------------------------------------ the sky and the meadow (painted once)

local BEDX = {84, 192, 300, 84, 192, 300}
local BEDY = {290, 280, 290, 404, 394, 404}
P.BEDX, P.BEDY = BEDX, BEDY

local function cloud(x, y, s, col)
  toon(function()
    toon.circle(x - 16 * s, y + 4 * s, 12 * s, col)
    toon.circle(x + 16 * s, y + 4 * s, 12 * s, col)
    toon.circle(x, y - 3 * s, 16 * s, col)
    toon.ellipse(x, y + 8 * s, 28 * s, 8 * s, col)
  end, 2, alpha(INK, 70))
end

-- dusk: false for the day. rainbow: the rare rainbow behind the hills. nunlocked: packets on the shelf.
function P.paint(dusk, rainbow, nunlocked)
  if dusk then
    gfx.vgrad(0, 0, W, 120, 0x2a2060, 0x6a3f8f)
    gfx.vgrad(0, 120, W, 100, 0x6a3f8f, 0xff9a86)
    for i = 1, 46 do
      gfx.circle(hash(i) * W, 8 + hash(i + 50) * 150, 0.8 + hash(i + 99) * 1.2, alpha(0xfff6c8, 190))
    end
    gfx.circle(330, 62, 24, 0xfff0c8)
    gfx.circle(340, 54, 21, 0x4a3478)
    gfx.glow(326, 66, 60, alpha(0xfff0c8, 60))
  else
    gfx.vgrad(0, 0, W, 215, 0x86ccff, 0xffeef6)
    cloud(70, 60, 1.1, 0xffffff)
    cloud(232, 98, 0.9, 0xffffff)
    cloud(150, 30, 0.7, 0xffffff)
    if rainbow then
      for i = 1, 6 do gfx.ring(192, 262, 198 - i * 9, 9, alpha(RAINBOW[i], 190)) end
    end
  end
  local h1, h2 = dusk and 0x4a6a8a or 0xa4e69c, dusk and 0x3a5a78 or 0x8adc86
  gfx.circle(70, 250, 92, h1)
  gfx.circle(325, 256, 100, h1)
  gfx.circle(210, 262, 70, h2)
  gfx.vgrad(0, 205, W, 275, dusk and 0x3a7a6e or 0x86dc82, dusk and 0x2a5a58 or 0x68c46a)
  -- Tufts, clover and little pebbles on the lawn.
  for i = 1, 60 do
    local gx, gy = 8 + hash(i * 3) * 368, 214 + hash(i * 3 + 1) * 258
    if gy > 214 then
      local g = dusk and 0x3f8a74 or 0x5cb860
      gfx.line(gx, gy, gx - 3, gy - 6, 2, g)
      gfx.line(gx, gy, gx + 1, gy - 8, 2, g)
      gfx.line(gx, gy, gx + 4, gy - 5, 2, g)
    end
  end
  for i = 1, 22 do
    local gx, gy = 10 + hash(i * 7 + 2) * 364, 222 + hash(i * 7 + 5) * 236
    gfx.circle(gx, gy, 2.2, dusk and 0xb8b0d8 or C.WHITE)
    gfx.circle(gx, gy, 0.9, C.SUN)
  end
  -- The fountain, in the middle of the far lawn.
  toon(function()
    toon.ellipse(192, 200, 40, 12, C.CREAM)
    toon.rrect(185, 168, 14, 30, 4, C.CREAM)
    toon.ellipse(192, 168, 24, 8, C.CREAM)
  end, 2.2, INK)
  gfx.ellipse(192, 201, 31, 7.5, dusk and 0x4a8ad0 or 0x7ec8ff)
  gfx.ellipse(192, 168, 17, 4.5, dusk and 0x4a8ad0 or 0x7ec8ff)
  -- Six mounds of soil.
  toon(function()
    for i = 1, 6 do toon.ellipse(BEDX[i], BEDY[i] + 10, 36, 13, C.SOIL) end
  end, 2.2, INK)
  for i = 1, 6 do
    gfx.ellipse(BEDX[i], BEDY[i] + 7, 27, 8, C.SOILD)
    gfx.circle(BEDX[i] - 18, BEDY[i] + 12, 2, 0xd8a87c)
    gfx.circle(BEDX[i] + 20, BEDY[i] + 13, 1.8, 0xd8a87c)
  end
  -- The shelf for the seed packets, along the bottom of the lawn.
  gfx.rrect_o(10, 436, 364, 44, 8, C.WOOD, INK, 2.5)
  gfx.rect(14, 440, 356, 4, C.WOODL)
  gfx.rect(14, 476, 356, 2, 0x9a6038)
end

-- The sheet "small": two fireflies, the seven dots, five toadstools, twelve seed packets and fifty-four
-- butterflies (six colours, nine wing beats). Order matters: it is the FF0..BF0 offsets above.
do
  local cells = {}
  local function add(w, h, ox, oy, paint) cells[#cells + 1] = {w = w, h = h, ox = ox, oy = oy, paint = paint} end
  for lit = 0, 1 do add(18, 12, 9, 6, function() firefly(0, 0, lit == 1) end) end
  for ci = 0, 6 do add(22, 22, 11, 11, function() dot(0, 0, ci) end) end
  for q = 0, 4 do add(22, 22, 11, 18, function() mushroom(0, 0, 0.65 + 0.1 * q) end) end
  for kind = 1, 6 do
    for open = 0, 1 do add(44, 42, 22, 3, function() packet(kind, 0, 0, open) end) end
  end
  for ci = 1, 6 do
    for q = 0, 8 do add(42, 26, 21, 14, function() butterfly(0, 0, P.COLS[ci], q / 8) end) end
  end
  sheet_make("small", 512, cells)
end

return P
