-- Band's pictures: the cast (drawn as in Tea), their instruments, the audience, the stage and the setlist.
-- main.lua owns the rules; everything here only draws. No rnd() in here: a hash of the frame instead.
local P = {}

local C = {
  CREAM = 0xfff6ea, GOLD = 0xf2c14e, MINT = 0x7ec8c3, LILAC = 0xb9a0e8, ROOF = 0xe86b9a, TEA = 0xc9865a,
  ORANGE = 0xf29a3a, GREY = 0x8a8f9c, INK = 0x3a2a44, WHITE = 0xfffcf8, SKY = 0x8ec6ff, CASTLE = 0xf4b6d0,
  BLUSH = alpha(0xff8fb0, 120), WOOD = 0xc88450, WOODL = 0xe4a46a, NIGHT = 0x2a1838,
}
P.C = C
local INK = C.INK
local STRIPES = {0xf2c14e, 0xe86b9a, 0x7ec8c3, 0xb9a0e8}
P.STRIPES = STRIPES
local BODY = {C.ORANGE, C.GREY, C.WHITE, C.CREAM}
local DARK = {0xd87a20, 0x666a78, 0xe8dccc, C.ORANGE}
local RAINBOW = {0xe86b9a, 0xf29a3a, 0xf2c14e, 0x7ec8c3, 0xb9a0e8, 0x8ac8ff}

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
local function fig(key, w, h, ox, oy, x, y, paint, k, live)
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

-- Where each friend stands (the head's middle), and the id of its cast member in Tea's drawing.
-- 1 Unicorn, 2 Pip, 3 Moth, 4 Pearl, 5 Nib.
P.X = {192, 78, 96, 306, 288}
P.Y = {198, 222, 338, 222, 346}
P.NAME = {"Unicorn", "Pip", "Moth", "Pearl", "Nib"}
P.COL = {0xf4a6d0, 0xf29a3a, 0xa8b8d8, 0xfff6ea, 0xffd84a}   -- the friend's colour: lamp, halo, ring
P.WHO = {[2] = 1, [3] = 2, [4] = 3, [5] = 4}

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

-- ------------------------------------------------------------------ instruments

-- Pip's drum kit. y is Pip's head. k, sn, hh, cr: how hard the kick, snare, hat and crash just sounded (0..1).
function P.kit_back(x, y, cr, hh)
  gfx.line(x - 54, y + 8, x - 54, y + 72, 3, INK)
  gfx.line(x + 56, y + 20, x + 56, y + 72, 3, INK)
  local sh = sin(fr() * 1.7) * 2 * cr
  gfx.ellipse_o(x - 54 + sh, y + 6, 21, 5.5, C.GOLD, INK, 2)
  gfx.ellipse_o(x + 56, y + 16 - hh * 3, 17, 4.5, C.GOLD, INK, 2)
  gfx.ellipse_o(x + 56, y + 21, 17, 4.5, 0xe0a838, INK, 2)
  if cr > 0.2 then gfx.glow(x - 54, y + 6, 26, alpha(0xffe080, floor(150 * cr))) end
end

-- The front of the kit is three kept layers: the kick (five sizes) and the left tom (five heights), and the
-- right tom. k and sn are rounded to quarters: a drum moves a quarter of its hit at a time (under a pixel).
local function kick_paint(x, y, pk)
  gfx.circle_o(x, y, 31 * pk, C.ROOF, INK, 2.5)
  gfx.circle(x, y, 24 * pk, C.CREAM)
  gfx.star(x, y, 12 * pk, 0, C.GOLD)
  gfx.ring(x, y, 24 * pk, 1.5, INK)
end
local function tom_paint(x, y, sn, top)
  gfx.ellipse_o(x, y, 15, 11 + sn * 1.5, C.LILAC, INK, 2.5)
  gfx.ellipse(x, y - 3, 12, 6, top)
end

function P.kit_front(x, y, k, sn, lit)
  local kq, sq = floor(k * 4 + 0.5), floor(sn * 4 + 0.5)
  local pk = 1 + 0.1 * kq / 4
  fig("kick:" .. kq, 76, 76, 38, 38, x, y + 64, function() kick_paint(0, 0, pk) end, 1, function() kick_paint(x, y + 64, 1 + 0.1 * k) end)
  local top = sq > 1 and 0xffffff or C.CREAM
  fig(fmt("tomL:%d", sq), 40, 36, 20, 17, x - 32, y + 40, function() tom_paint(0, 0, sq / 4, top) end, 1,
    function() tom_paint(x - 32, y + 40, sn, sn > 0.3 and 0xffffff or C.CREAM) end)
  fig("tomR", 40, 36, 20, 17, x + 32, y + 40, function() tom_paint(0, 0, 0, C.CREAM) end, 1,
    function() tom_paint(x + 32, y + 40, 0, C.CREAM) end)
end

-- Sticks: paws at the cat's chest, tips come down onto the drums. l, r: the hit just made (0..1).
function P.sticks(x, y, col, l, r)
  paw(x - 15, y + 30, col)
  paw(x + 15, y + 30, col)
  gfx.line(x - 15, y + 30, x - 34, y + 14 + l * 20, 3, 0xf4d8a0)
  gfx.circle_o(x - 34, y + 14 + l * 20, 3.2, C.CREAM, INK, 1.2)
  gfx.line(x + 15, y + 30, x + 34, y + 14 + r * 20, 3, 0xf4d8a0)
  gfx.circle_o(x + 34, y + 14 + r * 20, 3.2, C.CREAM, INK, 1.2)
end

-- Moth's upright bass, standing at its side. a: how hard the last pluck was; string: which of four.
-- The body and the strings at rest are a kept layer (one per string that is not at rest); the string that
-- is being plucked is drawn live over it.
local function bass_body(bx, y, still)
  gfx.rrect_o(bx - 4.5, y - 54, 9, 70, 3, 0x6a4030, INK, 2)
  gfx.circle_o(bx, y - 58, 6, 0x6a4030, INK, 2)
  gfx.ellipse_o(bx, y + 52, 26, 34, C.TEA, INK, 2.5)
  gfx.ellipse_o(bx, y + 18, 18, 22, C.TEA, INK, 2.5)
  gfx.ellipse(bx, y + 40, 20, 14, C.TEA)
  gfx.ellipse(bx - 10, y + 52, 3, 8, alpha(INK, 170))
  gfx.ellipse(bx + 10, y + 52, 3, 8, alpha(INK, 170))
  gfx.rect(bx - 8, y + 64, 16, 3, 0x6a4030)
  for k = 0, 3 do
    if k + 1 ~= still then
      local sx = bx - 4.5 + k * 3
      gfx.line(sx, y - 54, sx, y + 6, 1.2, 0xfff6ea)
      gfx.line(sx, y + 6, sx, y + 64, 1.2, 0xfff6ea)
    end
  end
end

function P.bass(x, y, a, string)
  local bx = x + 50
  local j = a > 0.03 and string or 0
  fig("bass:" .. j, 60, 159, 30, 68, bx, y, function() bass_body(0, 0, j) end, 1, function() bass_body(bx, y, j) end)
  if j > 0 then
    local sx = bx - 4.5 + (string - 1) * 3
    local w = sin(fr() * 2.1) * 3.5 * a
    gfx.line(sx, y - 54, sx + w, y + 6, 1.2, 0xfff6ea)
    gfx.line(sx + w, y + 6, sx, y + 64, 1.2, 0xfff6ea)
  end
  if a > 0.3 then gfx.glow(bx, y + 28, 30, alpha(0xffd080, floor(110 * a))) end
end

-- Pearl's bell bars, in front of her. hit: 1..5 the bar struck, a: how recently.
-- The bars at rest, her paws and the left mallet are a kept layer (one per bar that is not at rest); the base,
-- the struck bar and the right mallet are live.
local BHS = {40, 35, 30, 25, 21}
local function bars_rest(x, y, col, lit)
  for k = 1, 5 do
    if k ~= lit then
      local bx = x - 40 + (k - 1) * 20
      local top = y + 64 - BHS[k]
      gfx.rrect_o(bx - 8, top, 16, BHS[k] - 2, 4, RAINBOW[k], INK, 2)
      gfx.circle(bx, top + 6, 2, alpha(INK, 150))
    end
  end
  paw(x - 14, y + 34, col)
  paw(x + 14, y + 34, col)
  gfx.line(x - 14, y + 34, x - 28, y + 22, 3, 0xf4d8a0)
  gfx.circle_o(x - 28, y + 22, 3.5, C.GOLD, INK, 1.2)
end

function P.bars(x, y, col, hit, a)
  local hs = BHS
  gfx.rrect(x - 50, y + 62, 100, 5, 2, 0x6a4030)
  local lit = (hit and a > 0.05) and hit or 0
  if lit > 0 then
    local k = lit
    local bx = x - 40 + (k - 1) * 20
    local top = y + 64 - hs[k] - a * 5
    gfx.rrect_o(bx - 8, top, 16, hs[k] - 2 + a * 5, 4, 0xffffff, INK, 2)
    gfx.circle(bx, top + 6, 2, alpha(INK, 150))
    gfx.glow(bx, top + 10, 22, alpha(RAINBOW[k], floor(190 * a)))
  end
  local ck = fmt("bars:%d:%x", lit, col)
  fig(ck, 104, 50, 52, 1, x, y + 16, function() bars_rest(0, -16, col, lit) end, 1, function() bars_rest(x, y, col, lit) end)
  local mx = hit and (x - 40 + (hit - 1) * 20) or x + 10
  local hy = y + 64 - (hit and hs[hit] or 30) - 6 - (1 - a) * 14
  gfx.line(x + 14, y + 34, mx, hy, 3, 0xf4d8a0)
  gfx.circle_o(mx, hy, 3.5, C.GOLD, INK, 1.2)
end

-- Nib's tambourine, shaken on the clap and the shaker. a: how recently.
-- The drum, its star (twelve turns) and its ring of jingles (sixteen turns) are kept layers; she shakes it
-- (x and y move) and the jingles race round when she does.
local function tamb_disc(tx, ty)
  gfx.circle_o(tx, ty, 16, C.GOLD, INK, 2.5)
  gfx.circle(tx, ty, 11, C.CREAM)
end
local function tamb_jingles(tx, ty, a0)
  for k = 0, 5 do
    local an = k * 1.0472 + a0
    gfx.circle_o(tx + cos(an) * 16, ty + sin(an) * 16, 3, 0xfff0a0, INK, 1)
  end
end

function P.tambourine(x, y, col, a)
  local tx, ty = x + 31 + sin(fr() * 1.3) * 3 * a, y + 12 - a * 5
  fig("tdisc", 40, 40, 20, 20, tx, ty, function() tamb_disc(0, 0) end, 1, function() tamb_disc(tx, ty) end)
  local u = floor((fr() * 0.05 % 1.2566) / 1.2566 * 12 + 0.5) % 12
  fig("tstar:" .. u, 16, 16, 8, 8, tx, ty, function() gfx.star(0, 0, 6, u / 12 * 1.2566, C.ROOF) end, 1,
    function() gfx.star(tx, ty, 6, fr() * 0.05, C.ROOF) end)
  local a0 = fr() * 0.02 * (1 + 8 * a)
  local q = floor((a0 % 1.0472) / 1.0472 * 16 + 0.5) % 16
  fig("tjing:" .. q, 44, 44, 22, 22, tx, ty, function() tamb_jingles(0, 0, q / 16 * 1.0472) end, 1,
    function() tamb_jingles(tx, ty, a0) end)
  paw(x + 14, y + 30, col, 4.5)
  paw(tx - 12, ty + 8, col, 4.5)
  if a > 0.3 then gfx.glow(tx, ty, 26, alpha(0xffe080, floor(120 * a))) end
end

-- The Unicorn's harp. x, y: her head. a: how recently she plucked; k: which of seven strings.
-- Behind the strings (hooves, board, the strings at rest) and the frame in front are two kept layers (one of
-- the first per string that is not at rest); the plucked string and her hooves on it are live between them.
local function harp_back(hx, hy, still)
  gfx.rrect_o(hx - 40, hy + 52, 80, 8, 4, 0xe0a838, INK, 2)
  gfx.poly({hx - 32, hy + 52, hx + 34, hy + 52, hx + 34, hy + 34, hx - 32, hy + 8}, 0xf2c14e)
  for i = 0, 6 do
    if i + 1 ~= still then
      local sx = hx - 28 + i * 9
      local top = hy + 8 + i * 3.7
      gfx.line(sx, top, sx, (top + hy + 52) / 2, 1.5, RAINBOW[i % 6 + 1])
      gfx.line(sx, (top + hy + 52) / 2, sx, hy + 52, 1.5, RAINBOW[i % 6 + 1])
    end
  end
end

local function harp_front(hx, hy)
  gfx.line(hx - 34, hy + 6, hx - 34, hy + 56, 6, INK)
  gfx.line(hx - 34, hy + 6, hx - 34, hy + 56, 3.5, C.GOLD)
  gfx.line(hx - 34, hy + 6, hx + 36, hy + 34, 6, INK)
  gfx.line(hx - 34, hy + 6, hx + 36, hy + 34, 3.5, C.GOLD)
  gfx.line(hx + 36, hy + 34, hx + 36, hy + 52, 6, INK)
  gfx.line(hx + 36, hy + 34, hx + 36, hy + 52, 3.5, C.GOLD)
  gfx.circle_o(hx - 34, hy + 4, 4.5, C.ROOF, INK, 1.5)
end

function P.harp(x, y, a, k)
  local hx, hy = x + 18, y + 44
  local j = a > 0.03 and k or 0
  fig("harpb:" .. j, 86, 68, 43, 4, hx, hy, function() harp_back(0, 0, j) end, 1, function() harp_back(hx, hy, j) end)
  if j > 0 then
    local i = k - 1
    local sx = hx - 28 + i * 9
    local top = hy + 8 + i * 3.7
    local w = sin(fr() * 2.3) * 3.5 * a
    gfx.line(sx, top, sx + w, (top + hy + 52) / 2, 1.5, RAINBOW[i % 6 + 1])
    gfx.line(sx + w, (top + hy + 52) / 2, sx, hy + 52, 1.5, RAINBOW[i % 6 + 1])
  end
  fig("harpf", 86, 68, 43, 4, hx, hy, function() harp_front(0, 0) end, 1, function() harp_front(hx, hy) end)
  local py = hy + 30 - a * 8
  gfx.circle_o(hx - 6, py, 6, C.WHITE, INK, 1.8)
  gfx.circle_o(hx + 16, py + 6 + a * 3, 6, C.WHITE, INK, 1.8)
  if a > 0.3 then gfx.glow(hx, hy + 30, 40, alpha(0xffe8a0, floor(110 * a))) end
end

-- ------------------------------------------------------------------ the audience

-- kind 1 bunny, 2 bird, 3 firefly, 4 hedgehog, 5 frog. x, y: its middle; up: a hop.
-- The ten fans (five kinds, glad or not) are cells of one sheet, so the whole audience is one draw; the
-- firefly's light is drawn apart, for all of them first.
local function fan(kind, x, y, glad)
  if kind == 1 then
    gfx.ellipse_o(x - 4, y - 12, 2.8, 7, C.WHITE, INK, 1.2)
    gfx.ellipse_o(x + 4, y - 12, 2.8, 7, C.WHITE, INK, 1.2)
    gfx.ellipse(x - 4, y - 12, 1.2, 4.5, 0xffb8c8)
    gfx.ellipse(x + 4, y - 12, 1.2, 4.5, 0xffb8c8)
    gfx.circle_o(x, y, 8, C.WHITE, INK, 1.5)
  elseif kind == 2 then
    gfx.circle_o(x, y, 8, C.SKY, INK, 1.5)
    gfx.tri(x - 2, y + 1, x + 2, y + 1, x, y + 5, C.ORANGE)
    gfx.ellipse(x - 7, y + 2, 3, 5, 0x5a9ee0)
    gfx.ellipse(x + 7, y + 2, 3, 5, 0x5a9ee0)
  elseif kind == 3 then
    gfx.ellipse(x - 5, y - 4, 4, 2, alpha(0xffffff, 170))
    gfx.ellipse(x + 5, y - 4, 4, 2, alpha(0xffffff, 170))
    gfx.circle_o(x, y, 6, 0xffe860, INK, 1.4)
  elseif kind == 4 then
    for k = -2, 2 do gfx.tri(x + k * 3.5 - 3, y - 3, x + k * 3.5 + 3, y - 3, x + k * 3.5, y - 12 + abs(k) * 2, 0x8a5a40) end
    gfx.circle_o(x, y, 8, 0xb07850, INK, 1.5)
    gfx.ellipse(x, y + 2, 5.5, 4.5, 0xf4d8b8)
  else
    gfx.circle_o(x - 4.5, y - 6, 3.5, 0x78d878, INK, 1.2)
    gfx.circle_o(x + 4.5, y - 6, 3.5, 0x78d878, INK, 1.2)
    gfx.circle_o(x, y, 8, 0x78d878, INK, 1.5)
  end
  if glad then
    gfx.line(x - 4.5, y - 1, x - 3, y - 3, 1.5, INK)
    gfx.line(x - 3, y - 3, x - 1.5, y - 1, 1.5, INK)
    gfx.line(x + 1.5, y - 1, x + 3, y - 3, 1.5, INK)
    gfx.line(x + 3, y - 3, x + 4.5, y - 1, 1.5, INK)
  else
    gfx.circle(x - 3, y - 2, 1.5, INK)
    gfx.circle(x + 3, y - 2, 1.5, INK)
  end
end

function P.fan_glow(kind, x, y, up)
  if kind ~= 3 then return end
  local g = 0.6 + 0.4 * sin(fr() * 0.15 + x)
  gfx.glow(x, y - up, 15, alpha(0xfff080, floor(120 * g)))
end

function P.fan(kind, x, y, up, glad)
  if game.gpu then sheet_draw("band", (kind - 1) * 2 + (glad and 1 or 0) + 1, x, y - up)
  else fan(kind, x, y - up, glad) end
end

local function flower(x, y, s, c)
  for k = 0, 4 do
    local a = k * 1.2566
    gfx.circle_o(x + cos(a) * 5 * s, y + sin(a) * 5 * s, 4.2 * s, c, INK, 1)
  end
  gfx.circle(x, y, 3 * s, C.GOLD)
end

-- The whole static room, painted once into the backdrop.
function P.paint_stage(sg, photos, arch)
  gfx.vgrad(0, 0, W, 262, sg.sky1, sg.sky2)
  for i = 1, 40 do
    gfx.circle(hash(i) * W, 30 + hash(i + 50) * 190, 0.8 + hash(i + 99) * 1.4, alpha(C.GOLD, 150))
  end
  -- The window: a tall arch onto the night, with the moon and the castle far away.
  gfx.rrect_o(110, 60, 164, 220, 80, mix(sg.sky1, 0x000000, 0.25), C.GOLD, 4)
  gfx.circle(228, 104, 19, 0xfff0c0)
  gfx.circle(236, 98, 16, mix(sg.sky1, sg.sky2, 0.4))
  for i = 1, 14 do gfx.circle(122 + hash(i + 7) * 140, 90 + hash(i + 30) * 90, 1.2, alpha(C.WHITE, 200)) end
  gfx.rect(124, 176, 136, 90, mix(sg.sky1, 0x000000, 0.45))
  gfx.rect(138, 150, 16, 30, mix(sg.sky1, 0x000000, 0.45))
  gfx.tri(134, 152, 146, 128, 158, 152, mix(sg.sky1, 0x000000, 0.45))
  gfx.rect(226, 140, 18, 40, mix(sg.sky1, 0x000000, 0.45))
  gfx.tri(222, 142, 235, 116, 248, 142, mix(sg.sky1, 0x000000, 0.45))
  -- Pictures on the wall: the party photos Tea took.
  for i = 1, photos do
    local px = i <= 2 and 34 or 292
    local py = 68 + ((i - 1) % 2) * 66
    gfx.rrect_o(px, py, 62, 52, 5, C.GOLD, INK, 2.5)
    gfx.rect(px + 5, py + 5, 52, 42, RAINBOW[i])
    gfx.tri(px + 5, py + 47, px + 31, py + 22, px + 57, py + 47, alpha(0xffffff, 120))
    gfx.star(px + 31, py + 26, 9, 0, C.GOLD)
    gfx.circle(px + 31, py + 26, 3, C.WHITE)
  end
  -- A flower arch round the window, once she has grown three gardens.
  if arch then
    for i = 0, 18 do
      local a = math.pi + i * math.pi / 18
      local fx, fy = 192 + cos(a) * 92, 142 + sin(a) * 92
      gfx.circle(fx + 5, fy + 4, 5, 0x5ab05a)
      flower(fx, fy, 1.05, RAINBOW[i % 6 + 1])
    end
    for i = 0, 3 do
      for side = -1, 1, 2 do
        gfx.circle(192 + side * 92 + side * 2, 150 + i * 16, 5, 0x5ab05a)
        flower(192 + side * 92, 150 + i * 16 + 3, 1.0, RAINBOW[(i + 2 + (side > 0 and 3 or 0)) % 6 + 1])
      end
    end
  end
  -- Floor: the stage, then the carpet the audience sits on.
  gfx.rect(0, 262, W, 158, C.WOOD)
  gfx.rect(0, 262, W, 6, 0x9a6038)
  for i = 1, 7 do gfx.rect(0, 262 + i * 20, W, 2, alpha(0x6a4030, 120)) end
  for i = 0, 10 do
    local sx = ((i * 71 + 30) % W)
    for r = 0, 6 do gfx.rect(sx + (r % 2) * 37, 268 + r * 20, 2, 18, alpha(0x6a4030, 90)) end
  end
  gfx.rect(0, 404, W, 16, C.WOODL)
  gfx.rect(0, 420, W, 4, INK)
  gfx.rect(0, 424, W, 56, 0x3a2050)
  gfx.rect(0, 424, W, 6, 0x4e2e68)
  -- Curtains and the lamp rail.
  for side = 0, 1 do
    local cx0 = side == 0 and 0 or W - 36
    gfx.rect(cx0, 0, 36, 262, 0xb8365e)
    for k = 0, 3 do gfx.rect(cx0 + 4 + k * 9, 20, 3, 242, 0x8a2446) end
    gfx.rect(side == 0 and 34 or W - 38, 0, 4, 262, 0x6a1c38)
  end
  gfx.rect(0, 0, W, 24, 0x2a1838)
  gfx.rect(0, 24, W, 3, 0x14081c)
  for i = 0, 11 do gfx.circle_o(18 + i * 32, 30, 11, 0xd04a78, INK, 1.5) end
end

-- ------------------------------------------------------------------ lamps and the song board

-- A lamp on the rail: cell 11 is unlit, 12 to 16 are lit in each friend's colour. Its light is drawn apart.
local function lamp(lit)
  gfx.tri(-8, 4, 8, 4, 12, 20, 0x555566)
  gfx.ellipse_o(0, 21, 12, 4, lit or 0x777788, INK, 1.5)
  gfx.rrect(-8, 0, 16, 8, 3, 0x3a3a48)
end
local LAMPCI = {}
for i, c in ipairs(P.COL) do LAMPCI[c] = i end

function P.lamp(x, lit, col)
  if game.gpu then sheet_draw("band", 11 + (lit and LAMPCI[col] or 0), x, 20)
  else gfx.offset(x, 20) lamp(lit and col or nil) gfx.offset(0, 0) end
end

function P.lamp_glow(x, col)
  gfx.glow(x, 42, 22, alpha(col, 190))
end

function P.song_icon(which, cx, cy, s, col, t)
  if which == 1 then
    gfx.circle_o(cx, cy, 26 * s, 0xfff0c0, INK, 2.5)
    gfx.circle(cx + 10 * s, cy - 6 * s, 22 * s, mix(col, 0x000000, 0.3))
    gfx.star(cx + 28 * s, cy - 16 * s, 8 * s, t * 0.5, C.GOLD)
    gfx.star(cx - 26 * s, cy + 22 * s, 6 * s, t * 0.4, C.GOLD)
  elseif which == 2 then
    gfx.rrect_o(cx - 22 * s, cy - 8 * s, 44 * s, 30 * s, 6 * s, C.ROOF, INK, 2.5)
    gfx.rect(cx - 19 * s, cy - 2 * s, 38 * s, 4 * s, C.CREAM)
    gfx.ellipse_o(cx, cy - 8 * s, 22 * s, 7 * s, C.CREAM, INK, 2.5)
    gfx.line(cx + 6 * s, cy - 16 * s, cx + 26 * s, cy - 34 * s, 3 * s, 0xf4d8a0)
    gfx.line(cx - 6 * s, cy - 16 * s, cx - 26 * s, cy - 34 * s, 3 * s, 0xf4d8a0)
  elseif which == 3 then
    gfx.line(cx, cy - 34 * s, cx, cy - 22 * s, 2.5 * s, INK)
    gfx.circle_o(cx, cy, 22 * s, 0xd8d8f0, INK, 2.5)
    for k = -2, 2 do gfx.line(cx + k * 8 * s, cy - 20 * s, cx + k * 8 * s, cy + 20 * s, 1.2, alpha(INK, 90)) end
    for k = -2, 2 do gfx.line(cx - 20 * s, cy + k * 8 * s, cx + 20 * s, cy + k * 8 * s, 1.2, alpha(INK, 90)) end
    gfx.rect(cx - 10 * s, cy - 14 * s, 8 * s, 8 * s, 0xff98c8)
    gfx.rect(cx + 2 * s, cy + 2 * s, 8 * s, 8 * s, 0x7fe8ff)
    gfx.rect(cx - 16 * s, cy + 4 * s, 8 * s, 8 * s, C.GOLD)
    gfx.glow(cx + 8 * s, cy - 8 * s, 14 * s, alpha(0xffffff, 130))
  else
    gfx.circle_o(cx, cy - 20 * s, 8 * s, 0xffe0c8, INK, 2)
    gfx.poly({cx - 6 * s, cy - 14 * s, cx + 6 * s, cy - 14 * s, cx + 26 * s, cy + 22 * s, cx - 26 * s, cy + 22 * s}, col)
    gfx.ellipse_o(cx, cy + 22 * s, 28 * s, 6 * s, mix(col, 0xffffff, 0.4), INK, 2)
    for k = 0, 2 do gfx.line(cx - 12 * s + k * 12 * s, cy - 6 * s, cx - 16 * s + k * 16 * s, cy + 18 * s, 1.5, alpha(0xffffff, 150)) end
  end
end

-- The sheet "band": the ten fans (cells 1 to 10), then six lamps (11 to 16).
do
  local cells = {}
  local function add(w, h, ox, oy, paint) cells[#cells + 1] = {w = w, h = h, ox = ox, oy = oy, paint = paint} end
  for kind = 1, 5 do
    for glad = 0, 1 do add(24, 32, 12, 22, function() fan(kind, 0, 0, glad == 1) end) end
  end
  add(28, 28, 14, 1, function() lamp(nil) end)
  for i = 1, 5 do add(28, 28, 14, 1, function() lamp(P.COL[i]) end) end
  sheet_make("band", 256, cells)
end

return P
