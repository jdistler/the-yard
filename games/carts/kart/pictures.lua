-- Star Kart's pictures. main.lua owns the rules and fills P.S; everything here only draws. Nothing here uses
-- rnd() or reads the music clock (scenery is placed with small integer hashes, so a frame is the same on every
-- runtime). Two reused layers for ever: a sky strip for the race (repainted in place per track) and one scene
-- layer for the story, the garage, the map and the podium (repainted in place when the screen changes).
-- The race draws no full-screen alpha layer and allocates nothing per frame.
local P = {}

local C = {
  CREAM = 0xfff6ea, INK = 0x3a2a44, GOLD = 0xffd84a, ROSE = 0xe86b9a,
  RED = 0xe84855, BLUE = 0x4a90e2, GREEN = 0x58c860, PURPLE = 0x8a5cf5,
  CYAN = 0x7fe8ff, WHITE = 0xfffcf8, ORANGE = 0xf28c38, NAVY = 0x2a3a6a, PEACH = 0xffd0b0,
}
P.C = C
local INK, CREAM, GOLD, WHITE = C.INK, C.CREAM, C.GOLD, C.WHITE

local function hs(i, k) return (i * 7919 + k * 104729 + i * i * 31) % 1000 / 1000 end
local function fr() return game.frame end

-- ---------------------------------------------------------------- the data

-- the story's timeline (frames of the story screen)
P.STORY = {comet = 12, hit = 70, riv = 92, gap = 26, kart = 220, ["end"] = 380}
local ST = P.STORY
P.MAPMOVE = 34     -- the frame the marker starts to travel on the map
local MAPDUR = 60

P.TRACKS = {
  {name = "Meadow Circuit", theme = 1, sky1 = 0x66c2ff, sky2 = 0xbef0ff, grass1 = 0x62c462, grass2 = 0x52b052,
   road = 0x6e7282, kerb1 = 0xe84855, kerb2 = 0xfff6ea, rainbow = false, len = 3600},
  {name = "Beach Boardwalk", theme = 2, sky1 = 0x4ab8ff, sky2 = 0xffe8b0, grass1 = 0xf4d28a, grass2 = 0xe8c070,
   road = 0xb88652, kerb1 = 0x4ac8ff, kerb2 = 0xfff6ea, rainbow = false, len = 4200},
  {name = "Rainbow Skyway", theme = 3, sky1 = 0x1a1438, sky2 = 0x382068, grass1 = 0x241848, grass2 = 0x1c123a,
   road = 0x4a3a7a, kerb1 = 0xffd84a, kerb2 = 0x7fe8ff, rainbow = true, len = 4800},
}
local TRACKS = P.TRACKS

-- The rivals: our own cast. spd and lane (how fast and how wide it weaves) are rules; the rest is faces.
-- lose: the mood when you pass it or beat it; pod: its face on the podium when it did not win.
P.RIVALS = {
  {id = 1, name = "Ember", kind = "fox", col = 0xf28c38, trim = 0xffd84a, spd = 4.65, lane = 0.026, amp = 0.7, phase = 1.4,
   lose = "sulk", pod = "sulk", story = "taunt",
   words = {taunt = "Catch me!", lose = "Hmph!", sulk = "Hey!", bump = "Watch it!", cheer = "Yes!"}},
  {id = 2, name = "Bibi", kind = "bee", col = 0xffd838, trim = 0x3a2a44, spd = 4.50, lane = 0.017, amp = 0.6, phase = 2.8,
   lose = "cheer", pod = "cheer", story = "cheer",
   words = {taunt = "Zoom zoom!", lose = "Go you!", sulk = "Aww!", bump = "Oopsie!", cheer = "Hooray!"}},
  {id = 3, name = "Moss", kind = "frog", col = 0x58c860, trim = 0xfff6ea, spd = 4.35, lane = 0.011, amp = 0.55, phase = 4.2,
   lose = "yawn", pod = "yawn", story = "yawn",
   words = {taunt = "Ribbit.", lose = "Chill...", sulk = "Whoa!", bump = "Oof.", cheer = "Nice."}},
  {id = 4, name = "Pebble", kind = "penguin", col = 0x2a3a6a, trim = 0xf28c38, spd = 4.20, lane = 0.014, amp = 0.65, phase = 5.6,
   lose = "sulk", pod = "sulk", story = "taunt",
   words = {taunt = "Nope!", lose = "Brr!", sulk = "Hmph!", bump = "Hey!", cheer = "Fine!"}},
}
local RIVALS = P.RIVALS

-- Kart paint: unlocked by playing (main.lua says when). hint is what the locked swatch says.
P.PAINTS = {
  {name = "Cherry", col = 0xe84855, trim = 0x4a90e2, deco = 0, hint = ""},
  {name = "Sunny", col = 0xffc83a, trim = 0xff7a3a, deco = 1, hint = "1 race"},
  {name = "Minty", col = 0x58c8a0, trim = 0xfff6ea, deco = 2, hint = "3 races"},
  {name = "Grape", col = 0x8a5cf5, trim = 0xffd84a, deco = 1, hint = "6 races"},
  {name = "Bubblegum", col = 0xff8cc0, trim = 0x7fe8ff, deco = 3, hint = "1 cup"},
  {name = "Ocean", col = 0x3a8ae0, trim = 0xfff6ea, deco = 4, hint = "1 gold"},
  {name = "Rainbow", col = 0, trim = 0xffd84a, deco = 3, hint = "10 wins"},
}
local PAINTS = P.PAINTS
local function paint_col(pa)
  if pa.col == 0 then return hsv((fr() * 0.01) % 1, 0.6, 1) end
  return pa.col
end

local PLACE_STR = {"1ST", "2ND", "3RD", "4TH", "5TH"}
local ORD_STR = {"1st", "2nd", "3rd", "4th", "5th"}
local PTS_STR = {"+500", "+350", "+250", "+150", "+150"}
local MEDAL = {0xffd84a, 0xd8dce8, 0xd8905a, 0x9a8aa8, 0x9a8aa8}
local HY = 128

-- ---------------------------------------------------------------- road geometry (shared with main.lua)

function P.curve(d)
  return sin(d * 0.0045) * 44 + sin(d * 0.0019 + P.S.track) * 24
end

function P.project(wx, wd)
  local S = P.S
  local rel = wd - S.dist
  if rel < -60 or rel > 460 then return nil end
  local k = clamp(1 - rel / 460, 0, 1)
  local sy = lerp(HY, 396, k ^ 1.35)
  local halfw = lerp(42, 152, k ^ 1.25)
  local cx = W / 2 + (P.curve(wd) - P.curve(S.dist)) * (1 - k)
  return cx + wx * halfw, sy, lerp(0.32, 1.05, k ^ 1.2)
end
local project = P.project

-- ---------------------------------------------------------------- small drawing helpers

local function tri_o(x0, y0, x1, y1, x2, y2, col)   -- a triangle with an ink edge
  local cx, cy = (x0 + x1 + x2) / 3, (y0 + y1 + y2) / 3
  local k = 1.28
  gfx.tri(cx + (x0 - cx) * k, cy + (y0 - cy) * k, cx + (x1 - cx) * k, cy + (y1 - cy) * k,
    cx + (x2 - cx) * k, cy + (y2 - cy) * k, INK)
  gfx.tri(x0, y0, x1, y1, x2, y2, col)
end

local function smile(x, y, w, s, k)   -- k > 0 smiles, k < 0 frowns
  local h = k * s
  gfx.line(x - w, y, x - w * 0.5, y + h * 0.8, 1.8 * s, INK)
  gfx.line(x - w * 0.5, y + h * 0.8, x + w * 0.5, y + h * 0.8, 1.8 * s, INK)
  gfx.line(x + w * 0.5, y + h * 0.8, x + w, y, 1.8 * s, INK)
end

-- Eyes for a mood. (x, y) the middle, gap half the distance between, s the scale.
local function eyes(x, y, gap, s, m, white)
  if m == "happy" or m == "cheer" then
    for k = -1, 1, 2 do
      local ex = x + k * gap
      gfx.line(ex - 3.6 * s, y + 1.6 * s, ex, y - 2 * s, 2 * s, INK)
      gfx.line(ex, y - 2 * s, ex + 3.6 * s, y + 1.6 * s, 2 * s, INK)
    end
  elseif m == "yawn" then
    for k = -1, 1, 2 do gfx.line(x + k * gap - 3.4 * s, y, x + k * gap + 3.4 * s, y, 2 * s, INK) end
  elseif m == "bump" then
    for k = -1, 1, 2 do
      local ex = x + k * gap
      gfx.line(ex - 3 * s * k, y - 2.6 * s, ex + 2.4 * s * k, y, 2 * s, INK)
      gfx.line(ex - 3 * s * k, y + 2.6 * s, ex + 2.4 * s * k, y, 2 * s, INK)
    end
  elseif m == "taunt" then   -- half-lidded and smug
    for k = -1, 1, 2 do
      local ex = x + k * gap
      gfx.ellipse(ex, y + 0.6 * s, 3.4 * s, 2.6 * s, INK)
      gfx.circle(ex + 1 * s, y - 0.2 * s, 1 * s, WHITE)
      gfx.line(ex - 4 * s, y - 2.2 * s + k * 0.4 * s, ex + 4 * s, y - 2.2 * s - k * 0.4 * s, 1.8 * s, INK)
    end
  elseif m == "sulk" then
    for k = -1, 1, 2 do
      local ex = x + k * gap
      gfx.ellipse(ex, y, 3.3 * s, 4 * s, INK)
      gfx.circle(ex + 1 * s, y - 1.4 * s, 1.2 * s, WHITE)
      gfx.line(ex - 4 * s * k * -1, y - 5.2 * s, ex + 3.6 * s * -k, y - 3.4 * s, 1.8 * s, INK)
    end
    gfx.ellipse(x + gap + 2 * s, y + 6 * s, 1.5 * s, 2.4 * s, 0x7fd0ff)
  elseif m == "wow" then
    for k = -1, 1, 2 do
      local ex = x + k * gap
      gfx.circle(ex, y, 4.6 * s, WHITE)
      gfx.circle_o(ex, y, 4.6 * s, WHITE, INK, 1.2 * s)
      gfx.circle(ex, y, 1.8 * s, INK)
    end
  else
    for k = -1, 1, 2 do
      local ex = x + k * gap
      gfx.ellipse(ex, y, 3.2 * s, 4.2 * s, INK)
      gfx.circle(ex + 1 * s, y - 1.5 * s, 1.2 * s, WHITE)
    end
  end
end

local function mouth(x, y, s, m)
  if m == "cheer" or m == "happy" then
    gfx.ellipse(x, y + 1 * s, 4.2 * s, 3.2 * s, INK)
    gfx.ellipse(x, y + 2.4 * s, 2.6 * s, 1.5 * s, 0xff7a8a)
  elseif m == "taunt" then
    smile(x, y, 4.4 * s, s, 2.4)
    gfx.ellipse(x + 3 * s, y + 3 * s, 1.8 * s, 2.4 * s, 0xff7a8a)   -- tongue out
  elseif m == "sulk" then
    smile(x, y + 2 * s, 3.4 * s, s, -2.2)
  elseif m == "yawn" then
    gfx.ellipse(x, y + 1.6 * s, 3.4 * s, 4 * s, INK)
    gfx.ellipse(x, y + 3 * s, 2 * s, 1.6 * s, 0xff7a8a)
  elseif m == "bump" or m == "wow" then
    gfx.ellipse(x, y + 1.6 * s, 2.2 * s, 2.8 * s, INK)
  else
    smile(x, y, 3.6 * s, s, 1.8)
  end
end

-- ---------------------------------------------------------------- the heads

-- The head of a racer, front (back = false: a face) or from behind (back = true: ears and helmet).
-- kind fox bee frog penguin kid; (x, y) the middle of the head, s the scale (1 is 11 px of radius).
local function head(x, y, s, kind, col, trim, m, back)
  local r = 11 * s
  if kind == "fox" then
    tri_o(x - 9.5 * s, y - 4 * s, x - 8 * s, y - 17 * s, x - 1.5 * s, y - 8 * s, col)
    tri_o(x + 9.5 * s, y - 4 * s, x + 8 * s, y - 17 * s, x + 1.5 * s, y - 8 * s, col)
    gfx.circle_o(x, y, r, col, INK, 1.6 * s)
    if back then
      gfx.tri(x - 8.6 * s, y - 7 * s, x - 7.8 * s, y - 13 * s, x - 4.4 * s, y - 8 * s, 0xb85a28)
      gfx.tri(x + 8.6 * s, y - 7 * s, x + 7.8 * s, y - 13 * s, x + 4.4 * s, y - 8 * s, 0xb85a28)
      return
    end
    gfx.tri(x - 8.4 * s, y - 6.5 * s, x - 7.8 * s, y - 13 * s, x - 4.2 * s, y - 8 * s, 0xffc8c0)
    gfx.tri(x + 8.4 * s, y - 6.5 * s, x + 7.8 * s, y - 13 * s, x + 4.2 * s, y - 8 * s, 0xffc8c0)
    gfx.ellipse(x - 4.6 * s, y + 4.4 * s, 5.6 * s, 4.4 * s, CREAM)
    gfx.ellipse(x + 4.6 * s, y + 4.4 * s, 5.6 * s, 4.4 * s, CREAM)
    eyes(x, y - 2 * s, 4.6 * s, s, m)
    gfx.ellipse(x, y + 2.6 * s, 2 * s, 1.5 * s, INK)
    mouth(x, y + 5.4 * s, s * 0.9, m)
  elseif kind == "bee" then
    gfx.line(x - 4 * s, y - 8 * s, x - 8 * s, y - 16 * s, 2 * s, INK)
    gfx.line(x + 4 * s, y - 8 * s, x + 8 * s, y - 16 * s, 2 * s, INK)
    gfx.circle_o(x - 8 * s, y - 16.5 * s, 2.6 * s, 0xff7a8a, INK, 1.2 * s)
    gfx.circle_o(x + 8 * s, y - 16.5 * s, 2.6 * s, 0xff7a8a, INK, 1.2 * s)
    gfx.circle_o(x, y, r, col, INK, 1.6 * s)
    gfx.rect(x - 7.4 * s, y - 8 * s, 14.8 * s, 2.6 * s, INK)
    if back then
      gfx.rect(x - 10.2 * s, y - 2 * s, 20.4 * s, 2.6 * s, INK)
      gfx.rect(x - 9.4 * s, y + 4 * s, 18.8 * s, 2.6 * s, INK)
      return
    end
    eyes(x, y - 1 * s, 4.4 * s, s, m)
    gfx.ellipse(x - 7 * s, y + 4 * s, 2.4 * s, 1.6 * s, alpha(0xff6a8a, 150))
    gfx.ellipse(x + 7 * s, y + 4 * s, 2.4 * s, 1.6 * s, alpha(0xff6a8a, 150))
    mouth(x, y + 5.4 * s, s * 0.9, m)
  elseif kind == "frog" then
    gfx.circle_o(x - 6.4 * s, y - 8 * s, 5.4 * s, col, INK, 1.4 * s)
    gfx.circle_o(x + 6.4 * s, y - 8 * s, 5.4 * s, col, INK, 1.4 * s)
    gfx.circle_o(x, y + 1 * s, r, col, INK, 1.6 * s)
    if back then
      gfx.circle(x - 6.4 * s, y - 8.4 * s, 2 * s, 0x8ee890)
      gfx.circle(x + 6.4 * s, y - 8.4 * s, 2 * s, 0x8ee890)
      gfx.ellipse(x, y + 4 * s, 6 * s, 3 * s, 0x48a850)
      return
    end
    if m == "" or m == "bump" or m == "wow" or m == "sulk" or m == "taunt" then
      gfx.circle(x - 6.4 * s, y - 8 * s, 3.6 * s, WHITE)
      gfx.circle(x + 6.4 * s, y - 8 * s, 3.6 * s, WHITE)
    end
    eyes(x, y - 8 * s, 6.4 * s, s * 0.78, m)
    gfx.circle(x - 3 * s, y + 1 * s, 0.9 * s, 0x2a7a3a)
    gfx.circle(x + 3 * s, y + 1 * s, 0.9 * s, 0x2a7a3a)
    gfx.ellipse(x - 8 * s, y + 5 * s, 2.4 * s, 1.6 * s, alpha(0xff6a8a, 150))
    gfx.ellipse(x + 8 * s, y + 5 * s, 2.4 * s, 1.6 * s, alpha(0xff6a8a, 150))
    mouth(x, y + 5 * s, s * 1.1, m)
  elseif kind == "penguin" then
    gfx.circle_o(x, y, r, col, INK, 1.6 * s)
    if back then
      gfx.tri(x - 2 * s, y - 10 * s, x, y - 16 * s, x + 2 * s, y - 10 * s, col)
      gfx.ellipse(x - 5 * s, y - 4 * s, 2 * s, 3 * s, 0x4a5a9a)
      return
    end
    gfx.ellipse(x, y + 2.4 * s, 8.6 * s, 8 * s, WHITE)
    gfx.tri(x - 2.6 * s, y + 2.6 * s, x + 2.6 * s, y + 2.6 * s, x, y + 6.4 * s, 0xf28c38)
    eyes(x, y - 2 * s, 4.2 * s, s, m)
    gfx.ellipse(x - 7 * s, y + 3.6 * s, 2 * s, 1.5 * s, alpha(0xff6a8a, 150))
    gfx.ellipse(x + 7 * s, y + 3.6 * s, 2 * s, 1.5 * s, alpha(0xff6a8a, 150))
    if m == "sulk" or m == "bump" then smile(x, y + 8.4 * s, 2.6 * s, s, -1.8) end
  else   -- the kid in the helmet
    if back then
      gfx.circle_o(x, y, r + 1 * s, trim, INK, 1.6 * s)
      gfx.circle(x - 4 * s, y - 5 * s, 3 * s, alpha(WHITE, 140))
      gfx.star(x, y + 1 * s, 4.4 * s, 0, GOLD)
      return
    end
    gfx.circle_o(x, y - 1.5 * s, r + 1 * s, trim, INK, 1.6 * s)
    gfx.circle_o(x, y + 2 * s, 9.6 * s, C.PEACH, INK, 1.4 * s)
    gfx.rect(x - 8 * s, y - 5 * s, 16 * s, 2.6 * s, trim)
    gfx.star(x, y - 8.4 * s, 2.8 * s, 0, GOLD)
    eyes(x, y + 1 * s, 3.8 * s, s * 0.95, m)
    gfx.ellipse(x - 6.4 * s, y + 5 * s, 2.2 * s, 1.5 * s, alpha(0xff6a8a, 170))
    gfx.ellipse(x + 6.4 * s, y + 5 * s, 2.2 * s, 1.5 * s, alpha(0xff6a8a, 170))
    mouth(x, y + 5.6 * s, s * 0.9, m)
  end
end

-- A face for a chip, a bubble, a sticker: r is the head radius in pixels.
function P.portrait(x, y, r, kind, col, trim, m)
  head(x, y, r / 11, kind, col, trim, m or "", false)
end

-- ---------------------------------------------------------------- karts

local function deco_mark(x, y, s, deco, trim)
  if deco == 1 then
    gfx.rect(x - 2.6 * s, y - 8 * s, 5.2 * s, 20 * s, trim)
  elseif deco == 2 then
    gfx.circle(x - 8 * s, y + 4 * s, 2.4 * s, trim)
    gfx.circle(x, y + 7 * s, 2.4 * s, trim)
    gfx.circle(x + 8 * s, y + 4 * s, 2.4 * s, trim)
  elseif deco == 3 then
    gfx.star(x, y + 3 * s, 6 * s, 0, trim)
  elseif deco == 4 then
    gfx.line(x - 12 * s, y + 5 * s, x - 6 * s, y + 1 * s, 2.2 * s, trim)
    gfx.line(x - 6 * s, y + 1 * s, x, y + 5 * s, 2.2 * s, trim)
    gfx.line(x, y + 5 * s, x + 6 * s, y + 1 * s, 2.2 * s, trim)
    gfx.line(x + 6 * s, y + 1 * s, x + 12 * s, y + 5 * s, 2.2 * s, trim)
  end
end

-- A kart seen from behind. m: "" (the back of the head), "look" (turned to look back: a calm face) or a mood.
function P.kart(x, y, s, kind, col, trim, deco, lean, spin, star, m)
  local body = star and hsv((fr() * 0.06) % 1, 0.7, 1) or col
  if spin and spin > 0 then x = x + sin(fr() * 0.8) * 6 * s end
  gfx.ellipse(x, y + 16 * s, 22 * s, 6 * s, alpha(0x1a1428, 100))
  gfx.rrect_o(x - 21 * s, y + 1 * s, 9 * s, 15 * s, 3, INK, INK, 1)
  gfx.rrect_o(x + 12 * s, y + 1 * s, 9 * s, 15 * s, 3, INK, INK, 1)
  gfx.rrect(x - 19 * s, y + 3 * s, 2.4 * s, 10 * s, 1, 0x6a5a78)
  gfx.rrect(x + 16.6 * s, y + 3 * s, 2.4 * s, 10 * s, 1, 0x6a5a78)
  gfx.rrect_o(x - 16 * s, y - 8 * s, 32 * s, 21 * s, 7 * s, body, INK, 2 * s)
  deco_mark(x, y - 1 * s, s, deco, trim)
  gfx.rrect_o(x - 15 * s, y - 11 * s, 30 * s, 4.4 * s, 2, trim, INK, 1.4 * s)   -- the spoiler
  gfx.circle(x - 6 * s, y + 10 * s, 2.2 * s, 0x2a2030)
  gfx.circle(x + 6 * s, y + 10 * s, 2.2 * s, 0x2a2030)
  local hx = x + lean * 3 * s
  if m ~= "" and s >= 0.5 then
    head(hx, y - 16 * s, s, kind, col, trim, m == "look" and "" or m, false)
  else
    head(hx, y - 16 * s, s, kind, col, trim, "", true)
  end
end

-- A standing figure (podium, story): a body in the kart's colour with arms, under a head.
function P.figure(x, y, s, kind, col, trim, m, t, up)
  local bob = up and abs(sin(t * 0.22)) * 6 * s or 0
  y = y - bob
  gfx.ellipse(x, y + 1 * s, 16 * s, 4 * s, alpha(0x1a1428, 90))
  gfx.rrect_o(x - 9 * s, y - 14 * s, 7 * s, 14 * s, 3, INK, INK, 1)
  gfx.rrect_o(x + 2 * s, y - 14 * s, 7 * s, 14 * s, 3, INK, INK, 1)
  local sw = up and sin(t * 0.3) * 6 * s or 0
  gfx.line(x - 11 * s, y - 28 * s, x - 17 * s, y - (up and 46 or 20) * s + sw, 5 * s, INK)
  gfx.line(x + 11 * s, y - 28 * s, x + 17 * s, y - (up and 46 or 20) * s - sw, 5 * s, INK)
  gfx.line(x - 11 * s, y - 28 * s, x - 17 * s, y - (up and 46 or 20) * s + sw, 3 * s, col)
  gfx.line(x + 11 * s, y - 28 * s, x + 17 * s, y - (up and 46 or 20) * s - sw, 3 * s, col)
  gfx.rrect_o(x - 12 * s, y - 34 * s, 24 * s, 24 * s, 8 * s, col, INK, 2 * s)
  gfx.rrect(x - 8 * s, y - 20 * s, 16 * s, 4 * s, 2, trim)
  head(x, y - 44 * s, s * 1.15, kind, col, trim, m, false)
end

function P.cup(x, y, s, shine)
  if shine then gfx.glow(x, y - 12 * s, 34 * s, alpha(0xffe070, 120)) end
  gfx.rrect_o(x - 9 * s, y - 2 * s, 18 * s, 5 * s, 2, 0xe8a82c, INK, 1.4 * s)
  gfx.rect(x - 2.5 * s, y - 10 * s, 5 * s, 9 * s, 0xe8a82c)
  gfx.ring(x - 13 * s, y - 19 * s, 6 * s, 2.4 * s, 0xe8a82c)
  gfx.ring(x + 13 * s, y - 19 * s, 6 * s, 2.4 * s, 0xe8a82c)
  gfx.rrect_o(x - 13 * s, y - 32 * s, 26 * s, 24 * s, 9 * s, GOLD, INK, 1.8 * s)
  gfx.star(x, y - 20 * s, 6 * s, 0, 0xfff6c0)
  gfx.rrect(x - 9 * s, y - 29 * s, 3 * s, 14 * s, 1, alpha(WHITE, 160))
  if shine then gfx.star(x + 17 * s, y - 34 * s, 3 * s + sin(fr() * 0.2) * s, fr() * 0.05, WHITE) end
end

function P.item_icon(kind, x, y, r)
  if kind == "comet" then
    gfx.glow(x, y, r * 1.6, alpha(GOLD, 120))
    gfx.line(x - r * 1.3, y + r * 1.1, x - r * 0.2, y + r * 0.1, r * 0.5, alpha(0xff9a3a, 200))
    gfx.star(x, y, r, fr() * 0.1, GOLD)
  elseif kind == "seeker" then
    gfx.tri(x - r * 1.4, y - r * 0.9, x - r * 0.4, y - r * 0.1, x - r * 1.3, y + r * 0.4, 0xffd0f0)
    gfx.tri(x + r * 1.4, y - r * 0.9, x + r * 0.4, y - r * 0.1, x + r * 1.3, y + r * 0.4, 0xffd0f0)
    gfx.circle_o(x, y, r * 0.9, 0xff8ad0, INK, 1.6)
    gfx.circle(x - r * 0.3, y - r * 0.3, r * 0.25, WHITE)
    gfx.star(x, y + r * 0.1, r * 0.4, fr() * 0.15, GOLD)
  elseif kind == "bubble" then
    soap(x, y, r, C.CYAN)
  else
    gfx.circle_o(x, y, r * 0.95, 0xb890ff, INK, 1.6)
    gfx.line(x - r * 0.7, y + r * 0.1, x - r * 0.35, y - r * 0.4, 2.2, WHITE)
    gfx.line(x - r * 0.35, y - r * 0.4, x, y + r * 0.1, 2.2, WHITE)
    gfx.line(x, y + r * 0.1, x + r * 0.35, y - r * 0.4, 2.2, WHITE)
    gfx.line(x + r * 0.35, y - r * 0.4, x + r * 0.7, y + r * 0.1, 2.2, WHITE)
  end
end

-- ---------------------------------------------------------------- the two reused layers

local sky_l, sky_k = nil, -1
local scn_l, scn_k = nil, ""

local function cloud(x, y, s, a)
  gfx.ellipse(x, y, 22 * s, 7 * s, alpha(WHITE, a))
  gfx.ellipse(x - 10 * s, y - 5 * s, 12 * s, 8 * s, alpha(WHITE, a))
  gfx.ellipse(x + 8 * s, y - 7 * s, 14 * s, 9 * s, alpha(WHITE, a))
end

local function paint_sky(tr)
  local T = TRACKS[tr]
  if T.theme == 1 then
    gfx.vgrad(0, 0, W, 132, T.sky1, T.sky2)
    gfx.glow(310, 44, 48, alpha(0xfff2a0, 90))
    gfx.circle(310, 44, 17, 0xfff2a0)
    cloud(70, 36, 1, 220) cloud(200, 60, 0.8, 200) cloud(330, 84, 0.7, 190)
    gfx.ellipse(70, 134, 150, 34, 0x9ed88a)
    gfx.ellipse(300, 134, 170, 42, 0x8ccf7c)
    gfx.ellipse(190, 138, 160, 24, 0x7cc46c)
    -- the windmill
    gfx.tri(92, 112, 108, 112, 100, 84, 0xf4e4c8)
    gfx.rect(94, 106, 12, 8, 0xd8b890)
    gfx.tri(92, 84, 108, 84, 100, 74, C.RED)
    gfx.line(100, 84, 82, 70, 2.4, WHITE) gfx.line(100, 84, 118, 98, 2.4, WHITE)
    gfx.line(100, 84, 114, 66, 2.4, WHITE) gfx.line(100, 84, 86, 100, 2.4, WHITE)
    gfx.circle(100, 84, 3, INK)
    for i = 1, 14 do gfx.circle(hs(i, 3) * W, 108 + hs(i, 4) * 20, 2, hs(i, 5) < 0.5 and 0xffd84a or 0xff8aa8) end
  elseif T.theme == 2 then
    gfx.vgrad(0, 0, W, 100, T.sky1, T.sky2)
    gfx.glow(192, 96, 70, alpha(0xfff0b0, 110))
    gfx.circle(192, 96, 24, 0xfff0b0)
    cloud(60, 40, 0.9, 230) cloud(300, 54, 1, 210)
    gfx.vgrad(0, 96, W, 36, 0x4ac8ff, 0x2a9ae0)
    gfx.rect(0, 95, W, 2, alpha(WHITE, 180))
    for i = 1, 22 do
      local x, y = hs(i, 6) * W, 100 + hs(i, 7) * 26
      gfx.line(x, y, x + 8 + hs(i, 8) * 8, y, 1.4, alpha(WHITE, 150))
    end
    -- sailboats and gulls
    for _, b in ipairs({{64, 108, 1}, {312, 104, 0.8}}) do
      local x, y, s = b[1], b[2], b[3]
      gfx.rrect_o(x - 14 * s, y, 28 * s, 7 * s, 3, C.RED, INK, 1.2)
      gfx.line(x, y, x, y - 24 * s, 1.6, INK)
      gfx.tri(x + 2 * s, y - 2 * s, x + 2 * s, y - 22 * s, x + 16 * s, y - 2 * s, WHITE)
      gfx.tri(x - 2 * s, y - 2 * s, x - 2 * s, y - 18 * s, x - 12 * s, y - 2 * s, 0xffe8b0)
    end
    for _, g in ipairs({{130, 52}, {146, 60}, {250, 40}}) do
      gfx.line(g[1] - 6, g[2] + 2, g[1], g[2] - 2, 1.6, INK)
      gfx.line(g[1], g[2] - 2, g[1] + 6, g[2] + 2, 1.6, INK)
    end
    gfx.ellipse(344, 130, 46, 12, 0xf4d28a)
    gfx.line(344, 126, 350, 100, 3, 0x8a5a2c)
    for k = 0, 4 do
      local a = -0.6 + k * 0.5
      gfx.line(350, 100, 350 + cos(a) * 14, 100 - sin(a) * 6 + 6, 3, 0x48b858)
    end
  else
    gfx.vgrad(0, 0, W, 132, T.sky1, T.sky2)
    gfx.ellipse(120, 40, 140, 20, alpha(0x7fe8ff, 38))
    gfx.ellipse(280, 70, 150, 16, alpha(0xff8ad0, 34))
    gfx.ellipse(200, 100, 160, 14, alpha(0xb890ff, 40))
    for i = 1, 46 do
      gfx.circle(hs(i, 1) * W, hs(i, 2) * 118, 0.8 + hs(i, 3) * 1.2, alpha(0xdfe4ff, floor(70 + hs(i, 4) * 150)))
    end
    -- a ringed planet and a crescent moon
    gfx.ellipse(88, 52, 38, 8, 0xe8c8ff)
    gfx.circle_o(88, 52, 21, 0xb890ff, 0x6a4aaa, 1.5)
    gfx.circle(81, 45, 6, alpha(WHITE, 90))
    gfx.ellipse(88, 54, 38, 6, alpha(0xe8c8ff, 190))
    gfx.glow(316, 40, 40, alpha(0xfff0c8, 50))
    gfx.circle(316, 40, 15, 0xfff0c8)
    gfx.circle(322, 36, 13, 0x2c2060)
    -- far crystal spires
    for i = 0, 11 do
      local x = i * 36 + 8
      local h = 14 + hs(i, 9) * 26
      gfx.tri(x - 9, 132, x, 132 - h, x + 9, 132, i % 2 == 0 and 0x4a3a8a or 0x5a4a9a)
      gfx.tri(x - 3, 132, x, 132 - h, x + 4, 132, alpha(0xb8a8ff, 110))
    end
  end
end

-- A single scene layer, repainted in place when the screen (the key) changes.
local function scene(key, paint)
  if not scn_l then scn_l = gfx.layer(W, H) end
  if scn_k ~= key then
    scn_k = key
    scn_l:paint(paint)
  end
  gfx.blit(scn_l, 0, 0)
end

-- ---------------------------------------------------------------- the roadside, by track

local function side_object(th, kind, sx, sy, sc, idx)
  if th == 1 then
    if kind == 1 or kind == 2 then
      gfx.rect(sx - 3 * sc, sy - 22 * sc, 6 * sc, 22 * sc, 0x8a5a2c)
      gfx.circle(sx, sy - 30 * sc, 16 * sc, 0x3ea85a)
      gfx.circle(sx - 5 * sc, sy - 34 * sc, 8 * sc, 0x62c462)
      if kind == 2 then gfx.circle(sx + 7 * sc, sy - 26 * sc, 2.4 * sc, C.RED) gfx.circle(sx - 8 * sc, sy - 24 * sc, 2.4 * sc, C.RED) end
    elseif kind == 3 then
      gfx.circle(sx, sy - 6 * sc, 10 * sc, 0x48b858)
      gfx.circle(sx - 5 * sc, sy - 10 * sc, 2.6 * sc, 0xffd84a)
      gfx.circle(sx + 4 * sc, sy - 7 * sc, 2.6 * sc, 0xff8aa8)
      gfx.circle(sx + 1 * sc, sy - 13 * sc, 2.6 * sc, WHITE)
    else
      gfx.rect(sx - 1.6 * sc, sy - 24 * sc, 3.2 * sc, 24 * sc, 0x8a5a2c)
      gfx.rrect_o(sx - 11 * sc, sy - 30 * sc, 22 * sc, 12 * sc, 3, 0xffd84a, INK, 1.4)
      gfx.star(sx, sy - 24 * sc, 4 * sc, 0, C.RED)
    end
  elseif th == 2 then
    if kind == 1 or kind == 2 then   -- a palm
      gfx.line(sx, sy, sx + 5 * sc, sy - 22 * sc, 4 * sc, 0x9a6a38)
      gfx.line(sx + 5 * sc, sy - 22 * sc, sx + 3 * sc, sy - 36 * sc, 3.4 * sc, 0x9a6a38)
      local tx, ty = sx + 3 * sc, sy - 36 * sc
      gfx.line(tx, ty, tx - 16 * sc, ty + 8 * sc, 3 * sc, 0x38b05a)
      gfx.line(tx, ty, tx + 16 * sc, ty + 8 * sc, 3 * sc, 0x38b05a)
      gfx.line(tx, ty, tx - 9 * sc, ty - 8 * sc, 3 * sc, 0x48c868)
      gfx.line(tx, ty, tx + 9 * sc, ty - 8 * sc, 3 * sc, 0x48c868)
      gfx.circle(tx, ty + 2 * sc, 2.6 * sc, 0x6a4a28)
    elseif kind == 3 then   -- a beach umbrella
      gfx.line(sx, sy, sx, sy - 26 * sc, 2 * sc, 0xfff6ea)
      gfx.tri(sx - 17 * sc, sy - 24 * sc, sx + 17 * sc, sy - 24 * sc, sx, sy - 38 * sc, C.RED)
      gfx.tri(sx - 6 * sc, sy - 24 * sc, sx + 6 * sc, sy - 24 * sc, sx, sy - 38 * sc, WHITE)
    else   -- a sandcastle with a flag
      gfx.rrect_o(sx - 11 * sc, sy - 12 * sc, 22 * sc, 12 * sc, 2, 0xf0c070, INK, 1.2)
      gfx.rrect_o(sx - 6 * sc, sy - 20 * sc, 12 * sc, 9 * sc, 2, 0xf8d88a, INK, 1.2)
      gfx.line(sx, sy - 20 * sc, sx, sy - 30 * sc, 1.4, INK)
      gfx.tri(sx, sy - 30 * sc, sx + 8 * sc, sy - 27 * sc, sx, sy - 24 * sc, C.RED)
    end
  else
    if kind == 1 or kind == 2 then   -- a star lantern
      gfx.rect(sx - 1.4 * sc, sy - 26 * sc, 2.8 * sc, 26 * sc, 0x9a8ad0)
      gfx.glow(sx, sy - 30 * sc, 15 * sc, alpha(GOLD, 110))
      gfx.star(sx, sy - 30 * sc, 8 * sc, fr() * 0.03 + idx, GOLD)
    elseif kind == 3 then   -- a crystal
      gfx.tri(sx - 8 * sc, sy, sx - 2 * sc, sy - 26 * sc, sx + 4 * sc, sy, 0x7fe8ff)
      gfx.tri(sx - 1 * sc, sy, sx + 6 * sc, sy - 18 * sc, sx + 11 * sc, sy, 0xff8ad0)
      gfx.tri(sx - 6 * sc, sy, sx - 2 * sc, sy - 22 * sc, sx, sy, alpha(WHITE, 130))
    else   -- a floating ring
      local bob = sin(fr() * 0.08 + idx) * 3 * sc
      gfx.ring(sx, sy - 22 * sc + bob, 11 * sc, 3.4 * sc, hsv((idx * 0.13 + fr() * 0.004) % 1, 0.6, 1))
    end
  end
end

local function arch(d, col1, col2, star)
  local lx, ly, sc = project(-1.22, d)
  if not lx then return end
  local rx = project(1.22, d)
  local top = ly - 74 * sc
  gfx.rect(lx - 4 * sc, top, 8 * sc, 74 * sc, col1)
  gfx.rect(rx - 4 * sc, top, 8 * sc, 74 * sc, col1)
  local bw = (rx - lx) / 12
  for i = 0, 11 do
    gfx.rect(lx + i * bw, top - 4 * sc, bw + 1, 16 * sc, i % 2 == 0 and col1 or col2)
  end
  if star then gfx.star((lx + rx) / 2, top + 4 * sc, 12 * sc, fr() * 0.05, GOLD) end
end

-- ---------------------------------------------------------------- the race

local dord = {1, 2, 3, 4}

function P.race(S)
  local T = TRACKS[S.track]
  if sky_k ~= S.track then
    if not sky_l then sky_l = gfx.layer(W, 132) end
    sky_k = S.track
    sky_l:paint(function() paint_sky(S.track) end)
  end
  gfx.blit(sky_l, 0, 0)
  gfx.rect(0, HY, W, H - 32 - HY, T.grass1)
  if T.rainbow then
    for i = 1, 10 do   -- shooting sparkles on the grass
      local sx = (i * 53 + S.t * 0.4) % W
      gfx.circle(sx, 140 + (i * 29) % 40, (i % 2) + 1, alpha(WHITE, 150))
    end
  end

  -- Scrolling perspective road strips (fast & super smooth!).
  local th, dist = T.theme, S.dist
  local strips = 24
  local c0 = P.curve(dist)
  for i = 0, strips - 1 do
    local k0, k1 = i / strips, (i + 1) / strips
    local y0, y1 = lerp(HY, H - 32, k0 ^ 1.35), lerp(HY, H - 32, k1 ^ 1.35)
    local d0 = dist + (1 - k0) * 460
    local cx = W / 2 + (P.curve(d0) - c0) * (1 - k0)
    local hw = lerp(42, 152, k0 ^ 1.25)
    local band = floor(d0 / 48) % 2 == 0
    if band then gfx.rect(0, y0, W, y1 - y0 + 1, T.grass2) end
    local rcol = T.rainbow and hsv(((d0 * 0.002) % 1), 0.55, 0.88) or T.road
    gfx.rect(cx - hw - 10 * k0 - 2, y0, (hw + 10 * k0 + 2) * 2, y1 - y0 + 1, band and T.kerb1 or T.kerb2)
    gfx.rect(cx - hw, y0, hw * 2, y1 - y0 + 1, rcol)
    if th == 2 and not band then gfx.rect(cx - hw, y0, hw * 2, 1 + k0, 0x9a6c3c) end   -- boardwalk planks
    if band then gfx.rect(cx - 2 - k0 * 2, y0, 4 + k0 * 4, y1 - y0 + 1, alpha(CREAM, 170)) end
  end

  -- The roadside, far to near: trees, palms, lanterns by the track.
  local SP = 56
  local base = floor(dist / SP) * SP
  for i = 8, 0, -1 do
    local d = base + i * SP
    local idx = floor(d / SP)
    for side = -1, 1, 2 do
      local h = hs(idx, side + 3)
      if h < 0.85 then
        local sx, sy, sc = project(side * (1.32 + hs(idx, 9 + side) * 0.7), d)
        if sx then side_object(th, floor(h * 100) % 4 + 1, sx, sy, sc, idx) end
      end
    end
  end

  -- The last-stretch arch and the finish: a line, an arch of checks.
  local fd = T.len * 0.72
  if fd - dist < 460 and fd - dist > -60 then arch(fd, C.GOLD, C.WHITE, true) end
  local fx, fy, fs = project(0, T.len)
  if fx then
    local hw = 148 * fs
    for i = 0, 7 do
      gfx.rect(fx - hw + i * (hw / 4), fy - 5 * fs, hw / 4, 10 * fs, i % 2 == 0 and WHITE or INK)
    end
    arch(T.len, INK, WHITE, false)
  end

  -- Boost pads: rainbow chevrons.
  for _, p in ipairs(S.pads) do
    local sx, sy, sc = project(p.x, p.d)
    if sx then
      gfx.rrect_o(sx - 22 * sc, sy - 6 * sc, 44 * sc, 12 * sc, 4, hsv((fr() * 0.04) % 1, 0.8, 1), INK, 1.5)
      for k = -1, 1 do
        gfx.tri(sx + k * 10 * sc - 4 * sc, sy + 3 * sc, sx + k * 10 * sc + 4 * sc, sy + 3 * sc, sx + k * 10 * sc, sy - 3 * sc, alpha(INK, 190))
      end
    end
  end

  -- Item boxes.
  for _, b in ipairs(S.boxes) do
    if not b.gone then
      local sx, sy, sc = project(b.x, b.d)
      if sx then
        local bob = sin(fr() * 0.14 + b.d) * 3 * sc
        gfx.rrect_o(sx - 12 * sc, sy - 12 * sc + bob, 24 * sc, 24 * sc, 5, GOLD, INK, 2 * sc)
        gfx.text("?", sx, sy - 10 * sc + bob, max(10, floor(18 * sc)), INK, "center")
        if S.item then gfx.rrect(sx - 8 * sc, sy - 9 * sc + bob, 16 * sc, 3 * sc, 1, alpha(WHITE, 90)) end
      end
    end
  end

  -- Rivals, farthest first (a tiny sort in a table that is kept).
  local rv = S.rivals
  local n = #rv
  for i = 1, n do dord[i] = i end
  for i = 2, n do
    local v = dord[i]
    local j = i - 1
    while j >= 1 and rv[dord[j]].d < rv[v].d do dord[j + 1] = dord[j] j = j - 1 end
    dord[j + 1] = v
  end
  local zs = S.zap_t > 0 and 0.65 or 1
  local grid = S.phase == "grid"
  for q = 1, n do
    local r = rv[dord[q]]
    local sx, sy, sc = project(r.x, r.d)
    if sx then
      local d = r.def
      local m = r.mood_t > 0 and r.mood or (r.look == 1 and "look" or "")
      if grid then sy = sy + sin(fr() * 0.9 + r.phase) * 1.2 end
      P.kart(sx, sy, sc * zs, d.kind, d.col, d.trim, d.deco or 0, 0, r.spin, false, m)
    end
  end

  -- Seekers.
  for _, sh in ipairs(S.shells) do
    local sx, sy, sc = project(sh.x, sh.d)
    if sx then P.item_icon("seeker", sx, sy - 6 * sc, 11 * sc) end
  end

  -- Player kart!
  local px_scr = W / 2 + S.px * 145
  if S.boost_t > 0 or S.star_t > 0 then
    gfx.glow(px_scr, S.py + 12, 34, alpha(C.CYAN, 150))
    local ex = fr() % 6 < 3 and 5 or -5
    gfx.tri(px_scr - 7 + ex * 0.3, S.py + 14, px_scr + 7 + ex * 0.3, S.py + 14, px_scr, S.py + 34 + abs(ex), alpha(0xff9a3a, 210))
  end
  local pa = PAINTS[S.paint]
  local pm = S.pmood
  if pm == "ok" then pm = "look" end
  P.kart(px_scr, S.py, 1.15, "kid", paint_col(pa), pa.trim, pa.deco, S.lean, S.spin_t, S.star_t > 0, pm)
  if S.shield then soap(px_scr, S.py - 2, 34, C.CYAN) end

  P.hud(S)
end

-- ---------------------------------------------------------------- the race HUD

function P.hud(S)
  local T = TRACKS[S.track]
  local ph = S.phase
  local pl = PLACE_STR[S.place]
  -- Place, item slot, score
  gfx.rrect_o(10, 10, 82, 34, 10, CREAM, INK, 2)
  gfx.text(pl, 51, 14, 20, S.place == 1 and GOLD or C.PURPLE, "center", INK)
  gfx.rrect_o(W / 2 - 30, 8, 60, 44, 10, CREAM, INK, 2.5)
  if S.item then
    local shown = S.item
    if S.item_spin > 0 then
      local nm = {"comet", "seeker", "bubble", "wobble"}
      shown = nm[(floor(S.item_spin / 3) % 4) + 1]
    end
    P.item_icon(shown, W / 2, 30, 13)
  end
  gfx.rrect_o(W - 116, 10, 106, 34, 10, CREAM, INK, 2)
  gfx.text(tostring(S.score), W - 63, 16, 17, INK, "center")
  -- The track: a bar with every racer's face-colour on it
  local bx, bw = 72, W - 144
  meter(bx, 60, bw, 10, clamp(S.dist / T.len, 0, 1), GOLD)
  for _, r in ipairs(S.rivals) do
    gfx.circle_o(bx + clamp(r.d / T.len, 0, 1) * bw, 65, 4.6, r.def.col, INK, 1.4)
  end
  gfx.star(bx + clamp(S.dist / T.len, 0, 1) * bw, 65, 7, 0, WHITE)
  gfx.star(bx + clamp(S.dist / T.len, 0, 1) * bw, 65, 4.6, 0, C.RED)
  gfx.text("|>", bx + bw + 14, 56, 14, INK, "center")

  -- A rival's remark: a face, a name, a word
  if S.bub_t > 0 and S.bub_i > 0 then
    local d = RIVALS[S.bub_i]
    local lift = max(0, S.bub_t - 100) * 3
    local y = 80 - lift
    gfx.rrect_o(10, y, 176, 48, 12, CREAM, INK, 2.2)
    gfx.tri(34, y + 47, 50, y + 47, 36, y + 58, INK)
    gfx.tri(35, y + 45, 49, y + 45, 37, y + 55, CREAM)
    gfx.circle_o(36, y + 24, 19, 0xffffff, INK, 1.4)
    head(36, y + 26, 1.35, d.kind, d.col, d.trim, S.bub_mood, false)
    gfx.text(d.name, 62, y + 5, 13, C.PURPLE, "left")
    gfx.text(S.bub_word, 62, y + 22, 18, INK, "left")
  end

  if ph == "grid" then
    local g = S.pt
    gfx.rrect_o(W / 2 - 62, 82, 124, 42, 14, 0x2a2030, INK, 2.4)
    for k = 0, 2 do
      local on = g >= 12 + k * 22
      gfx.circle_o(W / 2 - 34 + k * 34, 103, 12, on and 0xff4a4a or 0x5a3a44, INK, 1.6)
      if on then gfx.glow(W / 2 - 34 + k * 34, 103, 18, alpha(0xff4a4a, 120)) end
    end
  elseif ph == "race" then
    if S.go_t < 46 then
      local k = 1 + (1 - S.go_t / 46) * 0.4
      gfx.text("GO!", W / 2, 128, floor(46 * k), 0x58e870, "center", INK)
    end
    if S.final_t > 0 then
      local k = 1 + sin(S.final_t * 0.4) * 0.06
      gfx.text("LAST STRETCH!", W / 2, 136, floor(30 * k), GOLD, "center", INK)
    end
  elseif ph == "finish" then
    P.finish_panel(S)
  end
end

function P.finish_panel(S)
  local rise = min(1, S.pt / 14)
  local y0 = 120 + (1 - rise) * -40
  local bw, bh = 336, 252
  local bx = (W - bw) / 2
  gfx.rrect_o(bx, y0, bw, bh, 16, CREAM, INK, 3)
  gfx.text("FINISH! " .. PLACE_STR[S.place], W / 2, y0 + 8, 30, S.place == 1 and GOLD or C.PURPLE, "center", INK)
  for rk = 1, 5 do
    local id = S.rord[rk]
    local y = y0 + 46 + (rk - 1) * 28
    local me = id == 0
    if me then gfx.rrect(bx + 10, y - 2, bw - 20, 26, 8, 0xffe9a0) end
    gfx.circle_o(bx + 28, y + 11, 10, MEDAL[rk], INK, 1.4)
    gfx.text(tostring(rk), bx + 28, y + 3, 13, INK, "center")
    if me then
      local pa = PAINTS[S.paint]
      head(bx + 62, y + 11, 0.85, "kid", paint_col(pa), pa.trim, S.pmood == "ok" and "" or "happy", false)
      gfx.text("You", bx + 86, y + 3, 16, INK, "left")
    else
      local d = RIVALS[id]
      local r = S.rivals[id]
      head(bx + 62, y + 12, 0.85, d.kind, d.col, d.trim, r.mood_t > 0 and r.mood or "", false)
      gfx.text(d.name, bx + 86, y + 3, 16, INK, "left")
    end
    gfx.text(PTS_STR[rk], bx + bw - 24, y + 3, 16, C.PURPLE, "right")
  end
  if S.new_paint > 0 and S.pt > 38 then
    local pa = PAINTS[S.new_paint]
    gfx.circle_o(bx + 40, y0 + bh - 24, 12, paint_col(pa), INK, 1.6)
    gfx.text("New paint: " .. pa.name .. "!", bx + 62, y0 + bh - 34, 16, 0xd0507a, "left")
  elseif S.pt > 50 and blink(40, 26) then
    gfx.text("PRESS TO GO ON!", W / 2, y0 + bh - 32, 16, INK, "center")
  end
end

-- ---------------------------------------------------------------- the story

local function paint_story()
  gfx.vgrad(0, 0, W, 270, 0x0e0c30, 0x3c2c78)
  gfx.rect(0, 270, W, H - 270, 0x241a58)
  for i = 1, 60 do
    gfx.circle(hs(i, 1) * W, hs(i, 2) * 250, 0.7 + hs(i, 3) * 1.2, alpha(0xdfe4ff, floor(60 + hs(i, 4) * 150)))
  end
  gfx.ellipse(70, 276, 150, 36, 0x2e2268)
  gfx.ellipse(330, 276, 160, 40, 0x2e2268)
  gfx.ellipse(192, 270, 70, 30, 0x3a2c7c)   -- the cup's hill
  gfx.ellipse(192, 266, 52, 20, 0x4a3a90)
  -- the road, winding to the hill
  gfx.poly({176, 274, 208, 274, 360, 512, 24, 512}, 0x4a3a7a)
  gfx.poly({176, 274, 182, 274, 52, 512, 24, 512}, C.GOLD)
  gfx.poly({208, 274, 202, 274, 332, 512, 360, 512}, C.CYAN)
  gfx.poly({179, 274, 205, 274, 340, 512, 44, 512}, 0x5c4a92)
  for i = 0, 6 do
    local k = i / 7
    local y = 290 + k * k * 210
    local wd = 2 + k * 7
    gfx.rect(192 - wd / 2, y, wd, 10 + k * 20, alpha(CREAM, 190))
  end
  for i = 0, 20 do   -- lantern dots along both sides
    local k = (i % 7) / 7
    local y = 284 + k * k * 214
    local off = 18 + (y - 274) * 0.62
    gfx.circle(192 - off - 6, y, 1.8 + k * 2, alpha(GOLD, 200))
    gfx.circle(192 + off + 6, y, 1.8 + k * 2, alpha(C.CYAN, 200))
  end
  gfx.rrect_o(34, 36, 316, 74, 18, 0x2a2058, GOLD, 3)   -- the title board
end

local SLOT = {{84, 372}, {148, 350}, {236, 350}, {300, 372}}
local STORY_LOOK = {taunt = "taunt", cheer = "cheer", yawn = "yawn"}

function P.story(S)
  local t = S.pt
  scene("story", paint_story)
  for i = 1, 8 do
    gfx.circle(hs(i, 7) * W, hs(i, 8) * 230, 1.2 + sin(fr() * 0.1 + i) * 0.7, alpha(WHITE, 180))
  end
  -- the title board
  gfx.text("STAR KART", W / 2, 44, 44, GOLD, "center", INK)
  gfx.text("the golden Star Cup", W / 2, 88, 15, C.CYAN, "center")
  -- the comet falls on the hill
  if t >= ST.comet and t < ST.hit then
    local k = (t - ST.comet) / (ST.hit - ST.comet)
    local cx, cy = lerp(380, 192, k), lerp(-20, 232, k * k)
    for j = 1, 7 do
      local kk = max(0, k - j * 0.025)
      local tx, ty = lerp(380, 192, kk), lerp(-20, 232, kk * kk)
      gfx.circle(tx, ty, 9 - j, alpha(0xffd0a0, 190 - j * 24))
    end
    gfx.glow(cx, cy, 26, alpha(0xfff0c0, 170))
    gfx.star(cx, cy, 10, t * 0.2, WHITE)
  end
  -- the golden Star Cup arrives and shines
  if t >= ST.hit then
    local k = min(1, (t - ST.hit) / 26)
    P.cup(192, 262, 1.5 * ease.out_back(k), true)
    if t % 6 < 3 then gfx.star(172 + (t * 7) % 40, 212 - (t * 3) % 24, 3, t * 0.1, WHITE) end
  end
  -- the rivals roll in, one by one, and take the grid
  for i = 1, 4 do
    local d = RIVALS[i]
    local t0 = ST.riv + (i - 1) * ST.gap
    if t >= t0 then
      local k = min(1, (t - t0) / 30)
      local fromx = (i <= 2) and -50 or W + 50
      local sx = lerp(fromx, SLOT[i][1], ease.out_cubic(k))
      local sy = SLOT[i][2] + (1 - k) * 60
      local m = ""
      if t >= ST.kart + 30 then m = STORY_LOOK[d.story] or "look" elseif k >= 1 then m = (t - t0) % 70 < 14 and "look" or "" end
      P.kart(sx, sy, 1.02, d.kind, d.col, d.trim, 0, (k < 1) and ((i <= 2) and 1 or -1) or 0, 0, false, m)
      if k >= 1 and t < ST.kart + 30 then
        gfx.text(d.name, sx, sy - 52, 13, WHITE, "center", INK)
      elseif k >= 1 then
        gfx.text(d.name, sx, sy + 20, 13, WHITE, "center", INK)
      end
    end
  end
  -- you roll in last, in your own paint
  if t >= ST.kart then
    local k = min(1, (t - ST.kart) / 40)
    local pa = PAINTS[S.paint]
    local y = lerp(600, 452, ease.out_cubic(k))
    P.kart(192, y, 1.3, "kid", paint_col(pa), pa.trim, pa.deco, 0, 0, false, k >= 1 and "happy" or "")
    if k >= 1 then
      gfx.text("You!", 192, y - 60, 15, GOLD, "center", INK)
    end
  end
  if t > 50 and blink(48, 32) then gfx.text("PRESS TO START", W / 2, 118, 17, WHITE, "center", INK) end
end

-- ---------------------------------------------------------------- the garage

local function paint_garage()
  gfx.vgrad(0, 0, W, H, 0x2c2160, 0x5a3a8a)
  gfx.rect(0, 262, W, 250, 0x3a2a6a)
  for i = 0, 12 do gfx.line(0, 262 + i * 22, W, 262 + i * 22, 1, alpha(0x1a1040, 90)) end
  -- the turntable
  gfx.ellipse(192, 206, 108, 20, 0x241a50)
  gfx.ellipse(192, 202, 100, 16, 0x6a5aa8)
  gfx.ellipse(192, 200, 92, 13, 0x8a7ac8)
  -- two shelves on brackets
  for _, y in ipairs({322, 408}) do
    gfx.rrect_o(16, y, W - 32, 9, 4, 0xb07a48, INK, 1.8)
    gfx.rect(52, y + 9, 5, 14, 0x7c5230)
    gfx.rect(W - 57, y + 9, 5, 14, 0x7c5230)
  end
end

local function lock(x, y)
  gfx.rrect(x - 5, y - 1, 10, 8, 2, 0x8a82a8)
  gfx.ring(x, y - 2, 3.6, 1.8, 0x8a82a8)
end

local function trophy_small(x, y, col, n, dim)
  local s = 0.8
  gfx.rrect_o(x - 9 * s * 1.5, y - 2 * s, 27 * s, 5 * s, 2, dim and 0x5a5078 or shade(col, 0.85), INK, 1.2)
  gfx.rect(x - 2 * s, y - 12 * s, 4 * s * 1.2, 11 * s, dim and 0x5a5078 or shade(col, 0.85))
  gfx.rrect_o(x - 13 * s, y - 34 * s, 26 * s, 24 * s, 8 * s * 0.8, dim and 0x6a6088 or col, INK, 1.5)
  if not dim then gfx.star(x, y - 22 * s, 5 * s, 0, WHITE) end
end

function P.garage(S)
  scene("garage", paint_garage)
  local t = S.pt
  gfx.text("STAR KART", W / 2, 8, 38, GOLD, "center", INK)
  if S.cups > 0 then
    P.cup(40, 62, 0.8, true)
    P.cup(W - 40, 62, 0.8, true)
  end
  -- the kart on its turntable, swaying
  local pa = PAINTS[S.paint]
  local sway = sin(t * 0.05) * 0.8
  P.kart(192, 150, 2, "kid", paint_col(pa), pa.trim, pa.deco, sway, 0, false, t % 160 > 120 and "happy" or "")
  gfx.text(pa.name, 192, 190, 16, WHITE, "center", INK)
  -- the arrows
  local ar = 4 + sin(t * 0.15) * 3
  gfx.tri(54 - ar, 150, 70 - ar, 136, 70 - ar, 164, GOLD)
  gfx.tri(W - 54 + ar, 150, W - 70 + ar, 136, W - 70 + ar, 164, GOLD)
  -- the swatches: unlocked ones glow, locked ones say how
  for k = 1, #PAINTS do
    local x = 192 + (k - 4) * 50
    local y = 240
    local p = PAINTS[k]
    if P.open(k) then
      local sel = k == S.paint
      if sel then gfx.glow(x, y, 26, alpha(GOLD, 120)) end
      gfx.circle_o(x, y, sel and 17 or 14, paint_col(p), INK, 2)
      gfx.circle(x - 4, y - 5, 3.2, alpha(WHITE, 160))
      if sel then gfx.ring(x, y, 20, 2.4, GOLD) end
      if S.new_paint == k and blink(30, 20) then gfx.star(x + 14, y - 14, 6, t * 0.1, WHITE) end
    else
      gfx.circle_o(x, y, 13, 0x4a4078, INK, 2)
      lock(x, y)
      gfx.text(p.hint, x, y + 17, 11, 0xc8c0e8, "center")
    end
  end
  -- shelf one: the cup trophies
  gfx.text("TROPHIES", 192, 286, 14, 0xc8c0e8, "center")
  local cols = {GOLD, 0xd8dce8, 0xd8905a}
  local cnt = {S.gold, S.silver, S.bronze}
  for k = 1, 3 do
    local x = 62 + (k - 1) * 70
    local has = cnt[k] > 0
    trophy_small(x, 326, cols[k], cnt[k], not has)
    if has then
      gfx.text("x" .. cnt[k], x + 22, 308, 15, WHITE, "left", INK)
      if S.fresh == k and S.pt < 90 and blink(24, 16) then gfx.star(x + 14, 292, 7, t * 0.1, WHITE) end
    end
  end
  -- the Star Cup itself, big, on the right of the shelf: it shines once you have won it
  P.cup(318, 326, S.cups > 0 and 1.15 or 0.95, S.cups > 0)
  if S.cups == 0 then gfx.rrect(300, 296, 36, 28, 8, alpha(0x1a1040, 150)) gfx.text("?", 318, 296, 22, 0xc8c0e8, "center") end
  gfx.text(S.cups > 0 and ("x" .. S.cups) or "win it!", 318, 332, 13, WHITE, "center", INK)
  -- shelf two: a medal for each track, and a sticker for each rival you have beaten
  for k = 1, #TRACKS do
    local x = 46 + (k - 1) * 40
    local pl = S.med[k]
    gfx.circle_o(x, 394, 13, pl > 0 and MEDAL[pl] or 0x4a4078, INK, 1.8)
    if pl > 0 then gfx.text(tostring(pl), x, 386, 14, INK, "center")
    else gfx.text("?", x, 386, 14, 0xc8c0e8, "center") end
  end
  for k = 1, 4 do
    local x = 190 + (k - 1) * 52
    local d = RIVALS[k]
    local beat = S.beat[k]
    gfx.circle_o(x, 388, 17, beat > 0 and WHITE or 0x4a4078, INK, 1.6)
    if beat > 0 then
      head(x, 390, 1.15, d.kind, d.col, d.trim, (t + k * 30) % 200 < 20 and "happy" or "", false)
      gfx.text(d.name, x, 408 + 2, 11, WHITE, "center", INK)
    else
      gfx.text("?", x, 378, 20, 0xc8c0e8, "center")
    end
  end
  gfx.text("MEDALS", 82, 355, 12, 0xc8c0e8, "center")
  gfx.text("BEAT THEM!", 268, 355, 12, 0xc8c0e8, "center")
  if S.pt > 20 and blink(48, 32) then gfx.text("PRESS TO RACE", W / 2, 446, 18, WHITE, "center", INK) end
end

-- ---------------------------------------------------------------- the map

local function d_col(id) return RIVALS[id].col end
local NODE = {{46, 262}, {130, 186}, {236, 246}, {306, 150}, {338, 64}}

local function paint_map(next)
  gfx.vgrad(0, 0, W, 300, 0x7fd0ff, 0xd8f4ff)
  cloud(60, 30, 0.9, 200) cloud(250, 22, 0.7, 190)
  -- the three lands
  gfx.ellipse(130, 206, 96, 50, 0x6cca5c)
  gfx.ellipse(110, 196, 60, 30, 0x84d874)
  gfx.ellipse(236, 262, 90, 36, 0xf4d28a)
  gfx.ellipse(210, 290, 120, 24, 0x4ac8ff)
  gfx.ellipse(306, 160, 70, 46, 0x6a50b0)
  gfx.ellipse(306, 150, 56, 34, 0x8a70d0)
  gfx.ellipse(338, 80, 44, 28, 0x58c860)
  for i = 1, 8 do   -- trees on the meadow, palms on the beach, stars on the sky island
    gfx.circle(90 + hs(i, 1) * 80, 186 + hs(i, 2) * 40, 5 + hs(i, 3) * 3, 0x3ea85a)
    gfx.line(200 + hs(i, 4) * 70, 262 + hs(i, 5) * 20, 204 + hs(i, 4) * 70, 250 + hs(i, 5) * 20, 2, 0x8a5a2c)
    gfx.circle(204 + hs(i, 4) * 70, 248 + hs(i, 5) * 20, 4, 0x38b05a)
    gfx.star(270 + hs(i, 6) * 70, 126 + hs(i, 7) * 50, 3 + hs(i, 8) * 2, hs(i, 9) * 6, 0xfff0a0)
  end
  gfx.rect(0, 296, W, 4, 0x8a5a2c)
  -- the road between the nodes: dashes, the finished legs painted gold
  for leg = 1, 4 do
    local a, b = NODE[leg], NODE[leg + 1]
    local done = leg < next
    local steps = 12
    for i = 0, steps - 1 do
      local k0, k1 = i / steps, (i + 0.55) / steps
      gfx.line(lerp(a[1], b[1], k0), lerp(a[2], b[2], k0), lerp(a[1], b[1], k1), lerp(a[2], b[2], k1),
        done and 6 or 4, done and GOLD or 0xfff6ea)
    end
  end
  -- the panel for the table
  gfx.rrect_o(10, 304, W - 20, 172, 16, CREAM, INK, 2.5)
end

function P.map(S)
  scene("map" .. S.next, function() paint_map(S.next) end)
  local t = S.pt
  -- the nodes: flags, a place medal for finished races, the Star Cup at the end
  local names = {"Start", "Meadow", "Beach", "Skyway"}
  for k = 1, 4 do
    local n = NODE[k]
    if k == 1 then
      gfx.rect(n[1] - 1, n[2] - 20, 3, 22, INK)
      for i = 0, 3 do gfx.rect(n[1] + 2 + (i % 2) * 5, n[2] - 20 + floor(i / 2) * 5, 5, 5, WHITE) gfx.rect(n[1] + 7 - (i % 2) * 5, n[2] - 20 + floor(i / 2) * 5, 5, 5, INK) end
    else
      local tr = k - 1
      local pl = tr < S.next and S.cplace[tr] or 0
      local cur = tr == S.next
      gfx.circle_o(n[1], n[2], cur and 13 + sin(t * 0.2) * 1.5 or 11, pl > 0 and MEDAL[pl] or (cur and WHITE or 0xd8d0f0), INK, 2)
      gfx.text(pl > 0 and tostring(pl) or tostring(tr), n[1], n[2] - 8, 15, INK, "center")
    end
    gfx.text(names[k], n[1], n[2] + 15, 12, INK, "center", WHITE)
  end
  P.cup(NODE[5][1], NODE[5][2] + 14, 0.8, true)
  -- the kart travels from where it was to the next stop
  local a, b = NODE[S.next], NODE[S.next + 1]
  local k = clamp((t - P.MAPMOVE) / MAPDUR, 0, 1)
  k = ease.in_out(k)
  local mx, my = lerp(a[1], b[1], k), lerp(a[2], b[2], k)
  local pa = PAINTS[S.paint]
  P.kart(mx, my - 6, 0.7, "kid", paint_col(pa), pa.trim, pa.deco, 0, 0, false, k >= 1 and "happy" or "")
  gfx.text(S.next == 1 and "RACE 1: " .. TRACKS[1].name or ("RACE " .. S.next .. ": " .. TRACKS[S.next].name), W / 2, 4, 17, INK, "center", WHITE)
  -- the cup table
  gfx.text(S.next == 1 and "THE RACERS" or "CUP SCORE", W / 2, 308, 14, C.PURPLE, "center")
  for rk = 1, 5 do
    local id = S.order[rk]
    local y = 326 + (rk - 1) * 29
    local me = id == 0
    if me then gfx.rrect(18, y - 3, W - 36, 27, 9, 0xffe9a0) end
    gfx.circle_o(36, y + 10, 10, MEDAL[rk], INK, 1.4)
    gfx.text(tostring(rk), 36, y + 3, 13, INK, "center")
    if me then
      head(66, y + 11, 0.85, "kid", paint_col(pa), pa.trim, "", false)
      gfx.text("You", 86, y + 3, 16, INK, "left")
    else
      local d = RIVALS[id]
      head(66, y + 12, 0.85, d.kind, d.col, d.trim, (t + id * 40) % 180 < 18 and "taunt" or "", false)
      gfx.text(d.name, 86, y + 3, 16, INK, "left")
    end
    local pts = me and S.cup_pts or S.rcup[id]
    meter(176, y + 6, 118, 10, clamp(pts / 1500, 0, 1), me and GOLD or d_col(id))
    gfx.text(tostring(pts), W - 26, y + 3, 16, C.PURPLE, "right")
  end
  if t > 40 and blink(40, 26) then gfx.text("PRESS TO RACE", W / 2, 458, 14, INK, "center") end
end

-- ---------------------------------------------------------------- the podium

local STEP = {{192, 276, 112}, {88, 326, 104}, {296, 358, 104}}   -- 1st, 2nd, 3rd: centre x, top y, width
local FLOOR_X = {40, 344}

local function paint_podium()
  gfx.vgrad(0, 0, W, 400, 0x1a1040, 0x5a3a8a)
  gfx.rect(0, 400, W, 112, 0x2a1c58)
  for i = 1, 30 do gfx.circle(hs(i, 1) * W, hs(i, 2) * 120, 0.8 + hs(i, 3), alpha(0xdfe4ff, floor(60 + hs(i, 4) * 120))) end
  -- the curtains and bunting
  gfx.rect(0, 0, 36, 400, 0x8a2a4a) gfx.rect(W - 36, 0, 36, 400, 0x8a2a4a)
  for i = 0, 5 do
    gfx.rect(i * 6, 0, 2, 400, 0x6a1a3a) gfx.rect(W - 36 + i * 6, 0, 2, 400, 0x6a1a3a)
  end
  for i = 0, 11 do
    local x = 40 + i * 28
    gfx.tri(x, 96, x + 22, 96, x + 11, 118, ({C.RED, GOLD, C.CYAN, C.GREEN})[i % 4 + 1])
  end
  gfx.line(36, 94, W - 36, 94, 2, INK)
  -- the steps
  local nums = {"1", "2", "3"}
  for k = 1, 3 do
    local s = STEP[k]
    gfx.rrect_o(s[1] - s[3] / 2, s[2], s[3], 400 - s[2], 6, k == 1 and 0xe8b83c or 0x9a86c8, INK, 2.4)
    gfx.rect(s[1] - s[3] / 2 + 4, s[2] + 4, s[3] - 8, 6, alpha(WHITE, 90))
    gfx.text(nums[k], s[1], s[2] + 1, 30, INK, "center")
  end
  gfx.rect(0, 400, W, 4, INK)
end

local PODIUM_AT = {24 + 4 * 22, 24 + 3 * 22, 24 + 2 * 22, 24 + 1 * 22, 24}   -- the frame rank 1..5 arrives

function P.podium(S)
  scene("podium", paint_podium)
  local t = S.pt
  -- spotlights sweeping
  gfx.glow(192 + sin(t * 0.04) * 100, 230, 60, alpha(0xfff0c0, 50))
  gfx.glow(192 - sin(t * 0.05) * 90, 260, 50, alpha(C.CYAN, 36))
  gfx.text("THE STAR CUP", W / 2, 20, 34, GOLD, "center", INK)
  gfx.text(S.rank == 1 and "You won!" or ("Cup score: " .. S.cup_pts), W / 2, 60, 17, WHITE, "center", INK)
  -- the racers by cup rank
  for rk = 5, 1, -1 do
    local id = S.order[rk]
    local ta = PODIUM_AT[rk]
    if t >= ta then
      local k = min(1, (t - ta) / 22)
      local x, y, sz
      if rk <= 3 then x, y, sz = STEP[rk][1], STEP[rk][2], 1.0
      else x, y, sz = FLOOR_X[rk - 3], 396, 0.72 end
      y = y + (1 - ease.out_back(k)) * 140
      local kind, col, trim, m
      if id == 0 then
        local pa = PAINTS[S.paint]
        kind, col, trim = "kid", paint_col(pa), pa.trim
        m = rk == 1 and "cheer" or rk <= 3 and "happy" or ""
      else
        local d = RIVALS[id]
        kind, col, trim = d.kind, d.col, d.trim
        m = rk == 1 and "cheer" or (rk <= 3 and d.pod or (d.pod == "cheer" and "cheer" or "sulk"))
        if rk > 3 and d.pod == "yawn" then m = "yawn" end
      end
      local up = rk == 1 and k >= 1
      P.figure(x, y, sz, kind, col, trim, m, t, up or (id > 0 and RIVALS[id].pod == "cheer" and k >= 1))
      if rk <= 3 and k >= 1 then   -- the medal and the name on the step
        gfx.circle_o(x, y - 22 * sz, 5, MEDAL[rk], INK, 1.2)
        local nm = id == 0 and "You" or RIVALS[id].name
        local pts = id == 0 and S.cup_pts or S.rcup[id]
        gfx.text(nm .. " " .. pts, x, STEP[rk][2] + 34, 13, INK, "center")
      elseif k >= 1 then
        local nm = id == 0 and "You" or RIVALS[id].name
        gfx.text(nm, x, y + 6, 12, WHITE, "center", INK)
      end
      if rk == 1 and k >= 1 then P.cup(x, y - 112 - abs(sin(t * 0.22)) * 6, 0.95, true) end
    end
  end
  if t > 130 and blink(44, 30) then gfx.text("PRESS TO GO ON", W / 2, 446, 17, WHITE, "center", INK) end
  if S.new_paint > 0 and t > 170 then
    local pa = PAINTS[S.new_paint]
    gfx.rrect_o(48, 108, 288, 38, 14, CREAM, INK, 2.4)
    gfx.circle_o(76, 127, 11, paint_col(pa), INK, 1.6)
    gfx.text("New kart paint: " .. pa.name .. "!", 96, 117, 16, 0xd0507a, "left")
  end
end

return P
