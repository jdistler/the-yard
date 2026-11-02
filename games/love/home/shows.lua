-- Home's idle shows, together: which ones there are, which one plays when (the calendar), and the SHOWS
-- section's screen of tiles, one for each segment of a show, to watch any part of it now.
--
--   shows.LIST                  {id, title, tint, blurb, module?} in the order of their cards
--   shows.segments(id)          {{start, title, scene?}, ...} (night: scene names; others: seconds)
--   shows.pick(now, game)       the show for this moment in AUTO (game: shows.game_window(now) from utgame.lua)
--   shows.open(ctx, id)         the tiles screen for a show; shows.handle(name) -> nil | "back" | {"play", id, i}
--   shows.draw(), shows.close()
-- A show module (freedom.lua, texas.lua, ...): load(ctx), start(seed, at), stop(), update(dt) -> ended,
-- draw(), music(), act(), SEGMENTS, LEN.
local lg = love.graphics
local S = {}
local C                                    -- Home's drawing helpers (set_ctx)

S.LIST = {
  {id = "night", title = "NIGHT SKY", tint = 0x8ab4ff,
   blurb = "Three hours of scenes under the stars, dusk to dawn."},
  {id = "freedom", title = "FREEDOM SHOW", tint = 0xff4a5a, module = "freedom",
   blurb = "The flag, the eagle, an invasion, and hot dogs. Very patriotic."},
  {id = "texas", title = "TEXAS", tint = 0xffb347, module = "texas",
   blurb = "A day across Texas: the Gulf, the Hill Country, Austin, the Panhandle, Big Bend."},
  {id = "longhorns", title = "LONGHORNS", tint = 0xff8c1a, module = "longhorns",
   blurb = "Game day on the Forty Acres. Hook 'em! Live scores on game days."},
  {id = "thanksgiving", title = "THANKSGIVING", tint = 0xe0903a, module = "thanksgiving",
   blurb = "The parade, the turkey on the run, and the table."},
  {id = "halloween", title = "HALLOWEEN", tint = 0xff8000, module = "halloween",
   blurb = "The ghosts' own holiday: the haunted house, jack-o'-lanterns, trick or treat, BOO!"},
  {id = "christmas", title = "CHRISTMAS", tint = 0x5fd16a, module = "christmas",
   blurb = "Snow on the fence, lights on the house, and a Texas Santa."},
}
S.BY_ID = {}
for _, s in ipairs(S.LIST) do S.BY_ID[s.id] = s end

local modules = {}
function S.module(id)
  local e = S.BY_ID[id]
  if not e or not e.module then return nil end
  if modules[id] == nil then
    local ok, m = pcall(require, e.module)
    modules[id] = ok and m or false
  end
  return modules[id] or nil
end
function S.available(id)
  return id == "night" or S.module(id) ~= nil
end

function S.segments(id)
  if id == "night" then return require("night").SEGMENTS end
  local m = S.module(id)
  return m and m.SEGMENTS or {}
end

-- ------------------------------------------------------------------ the calendar
-- The nth weekday (1 = Sunday) of a month, as a day of the month; n = -1: the last.
local function nth_weekday(year, month, wday, n)
  if n > 0 then
    local first = os.date("*t", os.time({year = year, month = month, day = 1, hour = 12}))
    return 1 + (wday - first.wday) % 7 + (n - 1) * 7
  end
  local last = os.date("*t", os.time({year = year, month = month + 1, day = 0, hour = 12}))
  return last.day - (last.wday - wday) % 7
end
S.nth_weekday = nth_weekday

-- The holiday show for a date, if any: {show, why}
function S.holiday(d)
  local m, day, y = d.month, d.day, d.year
  if m == 12 and day <= 26 then return "christmas", "Christmas" end
  if m == 11 then
    local tg = nth_weekday(y, 11, 5, 4)                 -- Thanksgiving: the fourth Thursday
    if day >= tg - 3 and day <= tg + 3 then return "thanksgiving", "Thanksgiving week" end
  end
  if m == 10 and day >= 15 then return "halloween", "Halloween" end
  if m == 7 and day <= 7 then return "freedom", "the Fourth of July" end
  if m == 5 then
    local md = nth_weekday(y, 5, 2, -1)                 -- Memorial Day: the last Monday
    if day >= md - 2 and day <= md then return "freedom", "Memorial Day" end
  end
  if m == 9 then
    local ld = nth_weekday(y, 9, 2, 1)                  -- Labor Day: the first Monday
    if day >= ld - 2 and day <= ld then return "freedom", "Labor Day" end
  end
  if m == 3 and day == 2 then return "texas", "Texas Independence Day" end
  if (m == 3 and day >= 15) or (m == 4) then return "texas", "bluebonnet season" end
  return nil
end

local function football_season(d)
  return (d.month == 8 and d.day >= 20) or d.month >= 9 or d.month == 1 and d.day <= 20
end

-- The show for now (AUTO). game: true while a Longhorns game is on or near (utgame.lua). rot: a counter, so
-- ordinary days take turns.
function S.pick(now, game, rot)
  if game and S.available("longhorns") then return "longhorns" end
  if now < 1700000000 then
    local r = {"freedom", "texas"}
    return r[(rot or 0) % #r + 1]
  end
  local d = os.date("*t", now)
  -- (Halloween night is the point of Halloween)
  if d.month == 10 and d.day == 31 and d.hour >= 17 and S.available("halloween") then return "halloween" end
  if d.hour >= 22 or d.hour < 8 then return "night" end
  local h = S.holiday(d)
  if h and S.available(h) then return h end
  local r = {}
  for _, id in ipairs({"texas", "freedom", "longhorns"}) do
    if S.available(id) and (id ~= "longhorns" or football_season(d)) then r[#r + 1] = id end
  end
  if #r == 0 then return "night" end
  return r[(rot or 0) % #r + 1]
end

-- ------------------------------------------------------------------ the cards' pictures
-- A show's little picture in a 180 x 180 box (scaled by sc) at x, centred on cy.
local flags = {}
local function flag_canvas(kind)
  if flags[kind] then return flags[kind] end
  local cv = lg.newCanvas(150, 80)
  lg.push("all")
  lg.origin()
  lg.setCanvas(cv)
  lg.clear(0, 0, 0, 0)
  if kind == "us" then
    for i = 0, 12 do
      if i % 2 == 0 then lg.setColor(0.8, 0.11, 0.17, 1) else lg.setColor(0.97, 0.97, 0.95, 1) end
      lg.rectangle("fill", 0, i * 80 / 13, 150, 80 / 13 + 1)
    end
    lg.setColor(0.14, 0.2, 0.52, 1)
    lg.rectangle("fill", 0, 0, 60, 80 * 7 / 13)
    lg.setColor(1, 1, 1, 1)
    for row = 0, 4 do for c = 0, 4 do lg.circle("fill", 6 + c * 12 + (row % 2) * 6, 5 + row * 8, 1.6, 6) end end
  else
    -- the Lone Star flag
    lg.setColor(0.0, 0.16, 0.41, 1)
    lg.rectangle("fill", 0, 0, 50, 80)
    lg.setColor(1, 1, 1, 1)
    lg.rectangle("fill", 50, 0, 100, 40)
    lg.setColor(0.75, 0.04, 0.19, 1)
    lg.rectangle("fill", 50, 40, 100, 40)
    lg.setColor(1, 1, 1, 1)
    local p = {}
    for i = 0, 9 do
      local a = -math.pi / 2 + i * math.pi / 5
      local r = i % 2 == 0 and 15 or 6
      p[#p + 1] = 25 + math.cos(a) * r
      p[#p + 1] = 40 + math.sin(a) * r
    end
    for i = 1, 19, 4 do
      lg.polygon("fill", 25, 40, p[i], p[i + 1], p[(i + 1) % 20 + 1], p[(i + 1) % 20 + 2])
      lg.polygon("fill", 25, 40, p[(i + 1) % 20 + 1], p[(i + 1) % 20 + 2], p[(i + 3) % 20 + 1], p[(i + 3) % 20 + 2])
    end
  end
  lg.pop()
  flags[kind] = {cv = cv, q = {}}
  for i = 0, 14 do flags[kind].q[i] = lg.newQuad(i * 10, 0, 10, 80, 150, 80) end
  return flags[kind]
end

local function waving_flag(kind, x, y, sc, a, t)
  local f = flag_canvas(kind)
  lg.setColor(0.8, 0.8, 0.85, a)
  lg.rectangle("fill", x - 6 * sc, y - 8 * sc, 4 * sc, 170 * sc)
  lg.setColor(1, 0.82, 0.3, a)
  lg.circle("fill", x - 4 * sc, y - 10 * sc, 5 * sc, 12)
  for i = 0, 14 do
    local k = i / 14
    local wob = math.sin(t * 3.2 - i * 0.47) * 7 * k * sc
    local shade = 0.82 + 0.18 * math.cos(t * 3.2 - i * 0.47 + 0.8) * k
    lg.setColor(shade, shade, shade, a)
    lg.draw(f.cv, f.q[i], x + i * 10 * sc * 0.99, y + wob, 0, sc, sc)
  end
end

local function star(x, y, r, c, a)
  lg.setColor(c[1], c[2], c[3], a)
  local ox, oy, ix, iy = {}, {}, {}, {}
  for i = 0, 4 do
    local an = -math.pi / 2 + i * 2 * math.pi / 5
    ox[i], oy[i] = x + math.cos(an) * r, y + math.sin(an) * r
    ix[i], iy[i] = x + math.cos(an + math.pi / 5) * r * 0.38, y + math.sin(an + math.pi / 5) * r * 0.38
  end
  lg.polygon("fill", ix[0], iy[0], ix[1], iy[1], ix[2], iy[2], ix[3], iy[3], ix[4], iy[4])
  for i = 0, 4 do local j = (i + 4) % 5 lg.polygon("fill", ox[i], oy[i], ix[i], iy[i], ix[j], iy[j]) end
end
S.star = star

S.longhorn = function(...) return require("showlib").longhorn_head(...) end

local ORANGE = {0.75, 0.34, 0}
function S.icon(id, x, cy, sc, a, t)
  local y = cy - 70 * sc
  if id == "freedom" then waving_flag("us", x + 16 * sc, y, sc, a, t)
  elseif id == "texas" then waving_flag("tx", x + 16 * sc, y, sc, a, t)
  elseif id == "night" or id == "auto" then
    local mx, my = x + 90 * sc, cy - 10 * sc
    C.fx.glow(mx, my, 90 * sc, 90 * sc, 0.8, 0.85, 1, 0.15 * a)
    lg.setColor(0.95, 0.93, 0.8, a)
    lg.circle("fill", mx, my, 46 * sc, 40)
    lg.setColor(0.07, 0.03, 0.14, a)
    lg.circle("fill", mx + 20 * sc, my - 12 * sc, 40 * sc, 40)
    for i, p in ipairs({{20, -50}, {150, -60}, {130, 50}, {30, 60}}) do
      local tw = 0.5 + 0.5 * math.sin(t * 2 + i)
      star(x + p[1] * sc, cy + p[2] * sc, (6 + 3 * tw) * sc, {1, 1, 0.85}, a)
    end
    if id == "auto" then
      -- a calendar page in front
      lg.setColor(0.97, 0.97, 0.95, a)
      lg.rectangle("fill", x + 26 * sc, cy + 2 * sc, 70 * sc, 64 * sc, 6 * sc)
      lg.setColor(0.8, 0.11, 0.17, a)
      lg.rectangle("fill", x + 26 * sc, cy + 2 * sc, 70 * sc, 18 * sc, 6 * sc)
      lg.setColor(0.2, 0.2, 0.25, a)
      for r = 0, 2 do for c = 0, 3 do lg.rectangle("fill", x + (32 + c * 16) * sc, cy + (26 + r * 13) * sc, 9 * sc, 8 * sc) end end
    end
  elseif id == "longhorns" then
    C.fx.glow(x + 90 * sc, cy, 100 * sc, 80 * sc, 1, 0.5, 0.1, 0.25 * a)
    S.longhorn(x + 90 * sc, cy, 0.85 * sc, ORANGE, a)
  elseif id == "thanksgiving" then
    local bx, by = x + 90 * sc, cy + 10 * sc
    local fan = {{0.75, 0.25, 0.1}, {0.9, 0.55, 0.15}, {0.95, 0.75, 0.2}, {0.9, 0.55, 0.15}, {0.75, 0.25, 0.1}}
    for i, c in ipairs(fan) do
      local an = -math.pi / 2 + (i - 3) * 0.42
      lg.setColor(c[1], c[2], c[3], a)
      lg.ellipse("fill", bx + math.cos(an) * 46 * sc, by - 10 * sc + math.sin(an) * 46 * sc, 18 * sc, 34 * sc, 16)
    end
    lg.setColor(0.45, 0.27, 0.15, a)
    lg.circle("fill", bx, by, 40 * sc, 24)
    lg.circle("fill", bx + 30 * sc, by - 34 * sc, 15 * sc, 16)
    lg.setColor(1, 0.75, 0.1, a)
    lg.polygon("fill", bx + 42 * sc, by - 36 * sc, bx + 56 * sc, by - 31 * sc, bx + 42 * sc, by - 28 * sc)
    lg.setColor(0.85, 0.12, 0.12, a)
    lg.ellipse("fill", bx + 42 * sc, by - 22 * sc, 4 * sc, 9 * sc, 10)
    lg.setColor(0, 0, 0, a)
    lg.circle("fill", bx + 34 * sc, by - 38 * sc, 2.5 * sc, 8)
  elseif id == "christmas" then
    local bx, by = x + 90 * sc, cy
    lg.setColor(0.4, 0.25, 0.12, a)
    lg.rectangle("fill", bx - 9 * sc, by + 52 * sc, 18 * sc, 20 * sc)
    for i, w in ipairs({{70, 52}, {56, 20}, {42, -12}}) do
      lg.setColor(0.12, 0.5 + i * 0.05, 0.22, a)
      lg.polygon("fill", bx - w[1] * sc, by + w[2] * sc, bx + w[1] * sc, by + w[2] * sc, bx, by + (w[2] - 52) * sc)
    end
    local cols = {{1, 0.25, 0.25}, {0.3, 0.6, 1}, {1, 0.85, 0.2}, {1, 0.4, 0.8}}
    for i, p in ipairs({{-30, 40}, {22, 34}, {-12, 12}, {18, -6}, {-4, -24}, {34, 44}}) do
      local c = cols[(i + math.floor(t * 2)) % 4 + 1]
      lg.setColor(c[1], c[2], c[3], a)
      lg.circle("fill", bx + p[1] * sc, by + p[2] * sc, 5 * sc, 10)
    end
    star(bx, by - 66 * sc, 13 * sc, {1, 0.85, 0.2}, a)
  end
end

-- ------------------------------------------------------------------ the tiles screen
local cur, tiles, sel, scroll, thumbs, t = nil, {}, 1, 0, {}, 0
local TW, TH = 344, 172                         -- a tile
local COLS, X0, Y0, GAP = 2, 30, 214, 18

function S.set_ctx(ctx) C = ctx end
function S.open(ctx, id)
  C = ctx
  cur = S.BY_ID[id]
  tiles = {{title = "THE WHOLE SHOW", seg = 0}}
  for i, sg in ipairs(S.segments(id)) do
    local mm = math.floor(sg[1] / 60)
    tiles[#tiles + 1] = {title = sg[2], seg = i, when = sg[3] and "" or string.format("%d:%02d", mm, sg[1] % 60)}
  end
  sel, scroll, t = 1, 0, 0
  thumbs = {}
  for i, tl in ipairs(tiles) do
    local p = string.format("thumbs/%s_%d.png", id, tl.seg)
    if love.filesystem.getInfo(p) then
      local ok, img = pcall(lg.newImage, p)
      if ok then img:setFilter("linear", "linear") thumbs[i] = img end
    end
  end
end

function S.close()
  for _, img in pairs(thumbs) do img:release() end
  thumbs = {}
  cur = nil
end

function S.current() return cur and cur.id end

function S.handle(name)
  local n = #tiles
  if name == "2p" then return "back" end
  if name == "left" and sel % COLS == 0 then sel = sel - 1
  elseif name == "right" and sel % COLS == 1 and sel < n then sel = sel + 1
  elseif name == "up" and sel > COLS then sel = sel - COLS
  elseif name == "down" and sel + COLS <= n then sel = sel + COLS
  elseif name == "down" and sel < n and math.ceil(sel / COLS) < math.ceil(n / COLS) then sel = n
  elseif name == "low" or name == "1p" then
    return {"play", cur.id, tiles[sel].seg}
  else
    return nil
  end
  C.play("move")
  return nil
end

function S.update(dt)
  t = t + dt
  -- keep the chosen row in view
  local row = math.ceil(sel / COLS) - 1
  local want = math.max(0, row * (TH + GAP) - 2 * (TH + GAP))
  scroll = scroll + (want - scroll) * math.min(1, dt * 10)
end

function S.draw()
  if not cur then return end
  C.backdrop()
  lg.setColor(0.02, 0.0, 0.06, 0.82)
  lg.rectangle("fill", 0, 0, 768, 1024)
  local r, g, b = C.rgb(cur.tint)
  C.neon_draw(cur.title, 0, 40, 64, cur.tint, 1.2, "center", 768)
  lg.setFont(C.font(22))
  lg.setColor(0.9, 0.88, 1, 0.9)
  lg.printf(cur.blurb, 40, 128, 688, "center")
  for i, tl in ipairs(tiles) do
    local col, row = (i - 1) % COLS, math.floor((i - 1) / COLS)
    local x, y = X0 + col * (TW + 20), Y0 + row * (TH + GAP) - scroll
    if y > 150 and y < 960 then
      local on = i == sel
      local a = math.min(1, (y - 150) / 40, (960 - y) / 40)
      if on then C.fx.glow(x + TW / 2, y + TH / 2, TW * 0.6, TH * 0.7, r, g, b, 0.25 * a) end
      lg.setColor(0.07, 0.03, 0.14, 0.92 * a)
      C.rrect("fill", x, y, TW, TH, 16)
      local img = thumbs[i]
      if img then
        local iw, ih = img:getDimensions()
        local s = (TH - 16) / ih
        lg.setColor(1, 1, 1, a)
        lg.draw(img, x + 8, y + 8, 0, s, s)
      end
      local tx = x + 8 + (img and (TH - 16) * 0.75 + 12 or 12)
      lg.setFont(C.font(24))
      lg.setColor(on and 1 or 0.85, on and 1 or 0.83, on and 1 or 0.95, a)
      lg.printf(tl.title, tx, y + 22, x + TW - tx - 10, "left")
      if tl.when and tl.when ~= "" then
        lg.setFont(C.font(18))
        lg.setColor(r, g, b, 0.85 * a)
        lg.print(tl.when, tx, y + TH - 36)
      end
      lg.setColor(r, g, b, (on and 1 or 0.35) * a)
      lg.setLineWidth(on and 3 or 1.5)
      C.rrect("line", x, y, TW, TH, 16)
    end
  end
  lg.setColor(0.02, 0, 0.05, 0.85)
  lg.rectangle("fill", 0, 980, 768, 44)
  lg.setFont(C.font(20))
  lg.setColor(0.85, 0.8, 1, 0.9)
  lg.printf("STICK  choose  ·  LOWER BUTTON  watch  ·  2-PLAYER  back", 0, 990, 768, "center")
end

return S
