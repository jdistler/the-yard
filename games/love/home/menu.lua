-- menu.lua: main.lua's "drawing" section, moved verbatim (HOME_REFACTOR.md CP4, tools/home_move.py).
-- Main's names it uses are mirrored here as locals of the same names. main.lua calls the function this
-- returns with them, where the section was: it fills the mirrors, then runs the section's text, so its
-- top-level statements run in the same order as before.
local M = {}
local D, H, I, LEAVE, SECTIONS, ST, W, curtain_draw, fx, items, lg, night, shelf, shows, t, tv
function M.sync_t(v) t = v end   -- (main assigns t; it hands the new value over)

return function(c)
D, H, I, LEAVE, SECTIONS, ST = c.D, c.H, c.I, c.LEAVE, c.SECTIONS, c.ST
W, curtain_draw, fx, items, lg, night = c.W, c.curtain_draw, c.fx, c.items, c.lg, c.night
shelf, shows, t, tv = c.shelf, c.shows, c.t, c.tv


-- A colour from the rainbow (0..1 around the wheel), as r, g, b for party mode.
local function hue(h)
  h = (h % 1) * 6
  local x = 1 - math.abs(h % 2 - 1)
  if h < 1 then return 1, x, 0.2 elseif h < 2 then return x, 1, 0.2 elseif h < 3 then return 0.2, 1, x
  elseif h < 4 then return 0.2, x, 1 elseif h < 5 then return x, 0.2, 1 else return 1, 0.2, x end
end
local hue_rgb = hue
hue = function(h, a) local r, g, b = hue_rgb(h) return r, g, b, a end
local sky
function ST.draw_world(dim)
  lg.setColor(1 - dim * 0.5, 1 - dim * 0.5, 1 - dim * 0.4, 1)
  lg.draw(ST.world, 0, 0)
  -- the sky alive: stars twinkling over the painted ones, a shooting star now and then
  for _, st in ipairs(ST.stars) do
    local tw = math.abs(math.sin(t * st[4] + st[3]))
    if tw > 0.7 then
      lg.setColor(1, 0.97, 0.88, (tw - 0.7) * 2.6 * st[5] * (1 - dim * 0.5))
      lg.rectangle("fill", st[1], st[2], st[6], st[6])
    end
  end
  fx.draw_shooting()
  -- the season's own life
  local wn = ST.world_name
  if wn == "christmas" then
    lg.setColor(1, 1, 1, 0.85)
    for i = 1, 70 do
      local x = (i * 97.3 + math.sin(t * 0.7 + i) * 30) % W
      local y = (i * 53.7 + t * (28 + (i % 5) * 8)) % (H + 20) - 10
      lg.circle("fill", x, y, 1.5 + (i % 3), 6)
    end
  elseif wn == "summer" or wn == "july4" or wn == "spring" then
    lg.setBlendMode("add")
    for i = 1, 22 do
      local on = math.sin(t * (1.2 + i % 4 * 0.3) + i * 1.7)
      if on > 0.4 then
        local x = (i * 61) % W + math.sin(t * 0.3 + i) * 30
        local y = 700 + (i * 37) % 90 + math.cos(t * 0.4 + i) * 16
        lg.setColor(0.75, 1, 0.3, (on - 0.4) * 1.4)
        lg.circle("fill", x, y, 3, 8)
      end
    end
    lg.setBlendMode("alpha")
  end
  if wn == "newyear" or wn == "july4" then
    -- a firework far off, every few seconds
    local cyc = t % 5
    if cyc < 1.6 then
      local k = cyc / 1.6
      local seed = math.floor(t / 5)
      local bx, by = 150 + (seed * 211) % 470, 300 + (seed * 97) % 180
      local cols = wn == "july4" and {{1, 0.3, 0.3}, {1, 1, 1}, {0.4, 0.6, 1}} or {{1, 0.85, 0.3}, {1, 0.4, 0.85}, {0.4, 0.9, 1}}
      local c = cols[seed % 3 + 1]
      lg.setBlendMode("add")
      for j = 1, 24 do
        local a = j / 24 * 2 * math.pi
        lg.setColor(c[1], c[2], c[3], (1 - k) * 0.9)
        lg.circle("fill", bx + math.cos(a) * 70 * k, by + math.sin(a) * 70 * k + k * k * 20, 2.5, 6)
      end
      lg.setBlendMode("alpha")
    end
  end
end

local function draw_background(dim)
  if ST.world then return ST.draw_world(dim) end
  -- The sky: deep violet to black, a slow color drift (one mesh, its colours updated).
  local drift = math.sin(t * 0.07) * 0.5 + 0.5
  local tr, tg, tb = 0.05 + 0.03 * drift, 0.02, 0.12 + 0.04 * (1 - drift)
  local mr, mg, mb = 0.20, 0.03 + 0.03 * drift, 0.28
  if not sky then
    sky = lg.newMesh(4, "fan", "dynamic")
  end
  sky:setVertices({{0, 0, 0, 0, tr, tg, tb, 1}, {W, 0, 0, 0, tr, tg, tb, 1},
                   {W, ST.HORIZON, 0, 0, mr, mg, mb, 1}, {0, ST.HORIZON, 0, 0, mr, mg, mb, 1}})
  lg.setColor(1, 1, 1, 1)
  lg.draw(sky)
  lg.setColor(0.02, 0.0, 0.05, 1)
  lg.rectangle("fill", 0, ST.HORIZON, W, H - ST.HORIZON)
  -- Stars.
  for _, s in ipairs(ST.stars) do
    local tw = 0.45 + 0.55 * math.abs(math.sin(t * s[4] + s[3]))
    lg.setColor(1, 0.9, 1, tw * s[5])
    lg.rectangle("fill", s[1], s[2], s[6], s[6])
  end
  fx.draw_shooting()
  -- The sun on the horizon, striped, with a warm haze.
  local cx, cy, r = W / 2, ST.HORIZON, 150
  fx.glow(cx, cy - 30, 250, 130, 1, 0.3, 0.55, 0.22 * (1 - dim))
  for i = 0, 14 do
    local y0 = cy - r + i * 11
    local k = i / 14
    if y0 < cy then
      local hw = math.sqrt(math.max(0, r * r - (cy - y0 - 4) ^ 2))
      lg.setColor(1, 0.35 + 0.45 * (1 - k), 0.35 + 0.25 * k, 0.55 * (1 - dim * 0.6))
      lg.rectangle("fill", cx - hw, y0, hw * 2, 11 - k * 6)
    end
  end
  -- The grid floor, rushing toward us.
  lg.setLineWidth(2)
  local ga = 1 - dim * 0.6
  for i = -12, 12 do
    if ST.party > 0 then lg.setColor(hue(i / 25 + t * 0.4, 0.7 * ga)) else lg.setColor(1, 0.2, 0.75, 0.55 * ga) end
    lg.line(W / 2 + i * 22, ST.HORIZON, W / 2 + i * 150, H)
  end
  local scroll = (t * 0.8) % 1
  for i = 0, 9 do
    local k = (i + scroll) / 10
    local y = ST.HORIZON + (H - ST.HORIZON) * k * k
    if ST.party > 0 then lg.setColor(hue(k + t * 0.6, (0.2 + 0.7 * k) * ga)) else lg.setColor(1, 0.25, 0.8, (0.15 + 0.6 * k) * ga) end
    lg.line(0, y, W, y)
  end
  lg.setColor(1, 0.4, 0.9, 0.8 * ga)
  lg.line(0, ST.HORIZON, W, ST.HORIZON)
end

-- The marquee's bulbs: round the board's frame (tools/art/home.py BOARD), a chase running round them.
ST.bulbs = {}
do
  local x0, y0, x1, y1 = 58, 8, 710, 172
  local per = 2 * ((x1 - x0) + (y1 - y0))
  local n = 72
  for i = 0, n - 1 do
    local d = i / n * per
    local x, y
    if d < x1 - x0 then x, y = x0 + d, y0
    elseif d < (x1 - x0) + (y1 - y0) then x, y = x1, y0 + d - (x1 - x0)
    elseif d < 2 * (x1 - x0) + (y1 - y0) then x, y = x1 - (d - (x1 - x0) - (y1 - y0)), y1
    else x, y = x0, y1 - (d - 2 * (x1 - x0) - (y1 - y0)) end
    ST.bulbs[#ST.bulbs + 1] = {x, y}
  end
end
-- lit: 0..1 (the intro lights them in turn)
function ST.draw_bulbs(alpha, lit)
  lit = lit or 1
  local n = #ST.bulbs
  local chase = math.floor(t * 8)
  for i, b in ipairs(ST.bulbs) do
    if i / n <= lit then
      local on = ((i + chase) % 3) ~= 0
      local k = (on and 1 or 0.35) * alpha
      lg.setColor(1, 0.86, 0.55, k * 0.35)
      lg.circle("fill", b[1], b[2], 7, 10)
      lg.setColor(1, 0.97, 0.85, k)
      lg.circle("fill", b[1], b[2], 3.2, 8)
    else
      lg.setColor(0.3, 0.27, 0.24, alpha)
      lg.circle("fill", b[1], b[2], 3.2, 8)
    end
  end
end

local function draw_marquee(alpha_k)
  -- The marquee: STARLIGHT in script neon on its board, the bulbs chasing round it; it breathes, slowly.
  local a = alpha_k or 1
  local flick = 0.93 + 0.07 * math.sin(t * 0.8)
  if not ST.world then
    lg.setColor(0.04, 0.02, 0.08, 0.85 * a)
    D.rrect("fill", 64, 14, 640, 152, 14)
  end
  ST.draw_bulbs(a)
  fx.glow(W / 2, 92, 300, 70, 1, 0.75, 0.35, 0.16 * a)
  ST.draw(0, 24, 96, flick * a)
end

local function draw_tabs(cur)
  -- (26 px: readable from the couch; on a dark pill so the sky's stars don't fight them)
  local px, gap = 26, 10
  local total = 0
  for _, s in ipairs(SECTIONS) do total = total + D.font(px):getWidth(s.name) + 28 + gap end
  local x = math.floor((W - total + gap) / 2)
  if total - gap > W - 20 then
    -- Wider than the glass (eight sections since FAVORITES): slide so the chosen tab is in the middle.
    local cx = 0
    for i, s in ipairs(SECTIONS) do
      local w = D.font(px):getWidth(s.name) + 28
      if i == cur then cx = cx + w / 2 break end
      cx = cx + w + gap
    end
    local want = math.max(W - 10 - (total - gap), math.min(10, W / 2 - cx))
    ST.tab_x = ST.tab_x and (ST.tab_x + (want - ST.tab_x) * 0.2) or want
    x = math.floor(ST.tab_x)
  end
  lg.setColor(0.03, 0.02, 0.08, 0.6)
  D.rrect("fill", x - 10, 182, total - gap + 20, 46, 23)
  for i, s in ipairs(SECTIONS) do
    local on = i == cur
    lg.setFont(D.font(px))
    local w = D.font(px):getWidth(s.name) + 28
    local r, g, b = D.rgb(s.tint)
    if on then
      lg.setColor(r, g, b, 0.28)
      D.rrect("fill", x, 186, w, 38, 19)
      lg.setColor(r, g, b, 1)
      lg.setLineWidth(2)
      D.rrect("line", x, 186, w, 38, 19)
    end
    lg.setColor(r, g, b, on and 1 or 0.6)
    lg.print(s.name, x + 14, 190)
    x = x + w + gap
  end
  -- Now and next: tonight's show, the Longhorns' next game (set by update_cards)
  if ST.now_line then
    lg.setFont(D.font(20))
    lg.setColor(0, 0, 0, 0.5)
    lg.printf(ST.now_line, 2, 240, W, "center")
    lg.setColor(1, 0.86, 0.5, 0.95)
    lg.printf(ST.now_line, 0, 238, W, "center")
  end
end

-- A card, centered on (cx, cy), of width cw.
local function draw_card(it, cx, cy, cw, focus, alpha)
  local ch = cw * 0.58
  local x, y = cx - cw / 2, cy - ch / 2
  local r, g, b = D.rgb(it.tint)
  if focus > 0 then
    -- The glow and the pulsing frame of the chosen card.
    local p = 0.75 + 0.25 * math.sin(t * 4)
    lg.setBlendMode("add")
    for k = 1, 4 do
      lg.setColor(r, g, b, 0.07 * focus * p)
      lg.setLineWidth(6 + k * 7)
      D.rrect("line", x - 6, y - 6, cw + 12, ch + 12, 26)
    end
    lg.setBlendMode("alpha")
  end
  lg.setColor(0.07, 0.03, 0.14, 0.9 * alpha)
  D.rrect("fill", x, y, cw, ch, 22)
  if it.art then
    -- A classic: its logo on a soft light of its own colour, gently breathing when chosen.
    local iw, ih = it.art:getDimensions()
    local s = math.min((cw - 56) / iw, (ch - 46) / ih)
    local breathe = 1 + 0.015 * focus * math.sin(t * 2.2)
    if focus > 0.05 then fx.glow(cx, cy, cw * 0.4, ch * 0.36, r, g, b, 0.3 * focus * alpha) end
    lg.setColor(1, 1, 1, alpha)
    lg.draw(it.art, cx, cy, 0, s * breathe, s * breathe, iw / 2, ih / 2)
  elseif it.kind == "classic" then
    -- No logo on this machine (a PC test): the name in neon.
    local px = math.floor(cw * (#it.title > 9 and 0.09 or 0.12))
    D.neon_draw(it.title, x, cy - px * 0.62, 64, it.tint, 1.2, "center", cw, alpha, px / 64)
  elseif it.kind == "arcade" then
    -- An arcade board: its title screen on the left, its leaderboard on the right (the board's own table).
    local aw = cw * 0.42
    if it.shot then
      -- (title screens: portrait for vertical boards, landscape for the rest; at most 45% of the card)
      local iw, ih = it.shot:getDimensions()
      local s = math.min((ch - 20) / ih, cw * 0.45 / iw)
      aw = iw * s
      lg.setColor(1, 1, 1, alpha)
      lg.draw(it.shot, x + 12, cy - ih * s / 2, 0, s, s)
      lg.setColor(r, g, b, 0.9 * alpha)
      lg.setLineWidth(2)
      lg.rectangle("line", x + 12, cy - ih * s / 2, iw * s, ih * s)
    end
    local tx = x + 24 + aw
    local tw = x + cw - tx - 16
    local sc = cw / 540
    local tbl = it.table
    if focus > 0.05 then fx.glow(tx + tw / 2, cy, tw * 0.55, ch * 0.4, r, g, b, 0.12 * focus * alpha) end
    if tbl and tbl[1][1] > 0 then
      lg.setFont(D.font(math.floor(18 * sc)))
      lg.setColor(1, 0.85, 0.3, alpha)
      local house = tbl[1][3]
      lg.printf(house and "SCORE TO BEAT" or "HIGH SCORE", tx, y + 22 * sc, tw, "center")
      lg.setFont(D.font(math.floor(46 * sc)))
      lg.setColor(1, 1, 1, alpha)
      lg.printf(shelf.commas(tbl[1][1]), tx, y + 46 * sc, tw, "center")
      if not tbl.nameless then
        D.neon_draw(house and "THE HOUSE" or (tbl[1][2] ~= "" and tbl[1][2] or "---"), tx, y + 100 * sc, 64,
                  house and 0x8a86a8 or it.tint, house and 0.5 or 1.1, "center", tw, alpha, (house and 0.42 or 0.62) * sc)
      end
      lg.setFont(D.font(math.floor(17 * sc)))
      for i = 2, math.min(3, #tbl) do
        lg.setColor(0.86, 0.84, 0.98, 0.85 * alpha)
        lg.printf(i .. ".  " .. (tbl.nameless and "" or ((tbl[i][2] ~= "" and tbl[i][2] or "---") .. "   ")) .. shelf.commas(tbl[i][1]), tx,
                  y + (170 + (i - 2) * 24) * sc, tw, "center")
      end
    else
      local px = math.min(cw * 0.09, 64 * tw / (D.font(64):getWidth(it.title) + 20))
      D.neon_draw(it.title, tx, cy - px * 0.75, 64, it.tint, 1.2, "center", tw, alpha, px / 64)
    end
  elseif it.shot then
    -- A portrait frame of the game on the left, the name in neon on the right.
    local iw, ih = it.shot:getDimensions()
    local s = (ch - 20) / ih
    lg.setColor(1, 1, 1, alpha)
    lg.draw(it.shot, x + 12, y + 10, 0, s, s)
    lg.setColor(r, g, b, 0.9 * alpha)
    lg.setLineWidth(2)
    lg.rectangle("line", x + 12, y + 10, iw * s, ih * s)
    local tx = x + 24 + iw * s
    local px = math.floor(cw * 0.12)
    if focus > 0.05 then fx.glow((tx + x + cw) / 2, cy, (x + cw - tx) * 0.5, ch * 0.35, r, g, b, 0.12 * focus * alpha) end
    D.neon_draw(it.title, tx, cy - px * 0.75, 64, it.tint, 1.2, "center", x + cw - tx, alpha, px / 64)
    lg.setFont(D.font(math.max(12, math.floor(cw * 0.034))))
    lg.setColor(0.9, 0.88, 1, 0.85 * alpha * focus)   -- the chosen card only: the panel below repeats it
    lg.printf(it.blurb, tx + 8, cy + px * 0.55, x + cw - tx - 16, "center")
  elseif it.kind == "show" or it.kind == "showcard" then
    -- An idle show (its picture), or the SCHEDULE (the show it is set to; a calendar for AUTO).
    local sc = ch / 260
    shows.icon(it.kind == "showcard" and it.show or ST.show_mode, x + 40 * sc, cy, sc, alpha, t)
    local tx = x + 230 * sc
    local px = math.min(cw * 0.1, 64 * (x + cw - tx - 24) / (D.font(64):getWidth(it.title) + 20))
    D.neon_draw(it.title, tx, cy - px * 0.75, 64, it.tint, 1.2, "center", x + cw - tx, alpha, px / 64)
    if it.kind == "show" then
      lg.setFont(D.font(math.max(12, math.floor(cw * 0.036))))
      lg.setColor(1, 0.85, 0.3, alpha)
      lg.printf(ST.SHOW_NAMES[ST.show_mode], tx, cy + px * 0.5, x + cw - tx, "center")
    end
  elseif it.id == "orb" then
    -- Orb: the glowing well, rings shrinking into the dark, a pilot falling in.
    local wx, wr = x + ch * 0.55, ch * 0.42
    lg.setBlendMode("add")
    for k = 0, 7 do
      local ph = ((t * 0.5 + k / 8) % 1)
      local rr = wr * (1 - ph)
      lg.setColor(0.66, 0.55, 1, 0.35 * ph * alpha)
      lg.setLineWidth(3)
      lg.circle("line", wx, cy, rr, 48)
    end
    lg.setColor(0.6, 0.5, 1, 0.25 * alpha)
    lg.circle("fill", wx, cy, wr * 0.25, 32)
    lg.setBlendMode("alpha")
    lg.setColor(1, 0.9, 0.5, alpha)
    lg.circle("fill", wx + math.sin(t * 2) * wr * 0.3, cy + math.cos(t * 1.3) * wr * 0.3, 5, 12)
    local tx = x + ch * 1.05
    local px = math.floor(cw * 0.12)
    D.neon_draw(it.title, tx, cy - px * 0.75, 64, it.tint, 1.2, "center", x + cw - tx, alpha, px / 64)
    lg.setFont(D.font(math.max(12, math.floor(cw * 0.034))))
    lg.setColor(0.9, 0.88, 1, 0.85 * alpha * focus)
    lg.printf(it.blurb, tx + 8, cy + px * 0.55, x + cw - tx - 16, "center")
  else
    lg.setColor(1, 1, 1, alpha)
    local px = math.floor(cw * (#it.title > 9 and 0.11 or 0.15))
    if focus > 0.05 then fx.glow(cx, cy, cw * 0.42, ch * 0.3, r, g, b, 0.12 * focus * alpha) end
    D.neon_draw(it.title, x, cy - px * 0.62, 64, it.tint, 1.2, "center", cw, alpha, px / 64)
  end
  lg.setColor(r, g, b, (0.35 + 0.65 * focus) * alpha)
  lg.setLineWidth(focus > 0 and 3 or 2)
  D.rrect("line", x, y, cw, ch, 22)
  if it == ST.last_played and focus > 0.3 then
    -- The game played last: a little tab on the card's top edge.
    lg.setFont(D.font(16))
    local tw = D.font(16):getWidth("LAST PLAYED") + 22
    lg.setColor(r, g, b, alpha)
    D.rrect("fill", cx - tw / 2, y - 13, tw, 26, 13)
    lg.setColor(0.06, 0.02, 0.12, alpha)
    lg.printf("LAST PLAYED", cx - tw / 2, y - 9, tw, "center")
  end
end

local function draw_carousel()
  -- The chosen card in the middle; its neighbours smaller and dimmer above and below, peeking out from behind.
  -- Drawn farthest first, so the chosen card is on top.
  local list = {}
  for k = math.floor(ST.pos) - 2, math.floor(ST.pos) + 2 do
    if items[k] then list[#list + 1] = k end
  end
  table.sort(list, function(p, q) return math.abs(p - ST.pos) > math.abs(q - ST.pos) end)
  for _, k in ipairs(list) do
    local it = items[k]
    local off = k - ST.pos
    local a = math.abs(off)
    if a < 1.9 then
      local cw = 540 * (1 - math.min(a, 1.6) * 0.30)
      local cy = 505 + off * 225 * (1 - 0.18 * math.min(a, 1))
      local alpha = math.max(0, 1 - a * 0.5) * math.min(1, (1.9 - a) * 2)
      -- Fade out before reaching the marquee and the tabs (a card scrolling up slid under them).
      alpha = alpha * math.max(0, math.min(1, (cy - cw * 0.29 - 262) / 60))
      local focus = math.max(0, 1 - a * 2)
      if ST.launch_item == it then cw = cw * (1 + 0.25 * math.min(1, ST.launch_t / 0.5)) end
      draw_card(it, W / 2, cy, cw, focus, alpha)
    end
  end
end

local function draw_info()
  local it = items[ST.sel]
  local y = 800
  lg.setColor(0.04, 0.0, 0.10, 0.84)
  D.rrect("fill", 40, y, W - 80, 196, 24)
  lg.setColor(D.rgb(it.tint, 0.8))
  lg.setLineWidth(2)
  D.rrect("line", 40, y, W - 80, 196, 24)
  D.neon_draw(it.title, 60, y + 14, 44, it.tint, 0.9, "left", W - 120)
  lg.setFont(D.font(22))
  lg.setColor(0.8, 0.76, 0.98, 1)
  lg.printf(it.sub, 60, y + 70, W - 120, "left")
  if it.score or it.stat then
    lg.setFont(D.font(22))
    lg.setColor(1, 0.85, 0.3, 1)
    local house = type(it.score) == "string" and it.score:find("HOUSE")
    lg.printf(it.score and ((house and "TO BEAT  " or "HIGH SCORE  ") .. it.score) or it.stat, 60, y + 22, W - 120, "right")
  end
  lg.setFont(D.font(26))
  lg.setColor(0.97, 0.95, 1, 1)
  lg.printf(it.blurb, 60, y + 100, W - 120, "left")
  if it.kind == "classic" then
    local i = it.index + 1
    local chips = {{"SPEED", ST.speed[i] == 1 and "FAST" or "NORMAL"}, {"SMOOTH", ST.smooth[i] == 1 and "ON" or "OFF"}}
    local x = 60
    for _, c in ipairs(chips) do
      lg.setFont(D.font(21))
      local s = c[1] .. "  " .. c[2]
      local w = D.font(21):getWidth(s) + 26
      lg.setColor(1, 0.85, 0.3, 0.18)
      D.rrect("fill", x, y + 146, w, 32, 16)
      lg.setColor(1, 0.85, 0.3, 1)
      D.rrect("line", x, y + 146, w, 32, 16)
      lg.print(s, x + 13, y + 151)
      x = x + w + 14
    end
    lg.setColor(0.78, 0.74, 0.95, 0.95)
    lg.setFont(D.font(19))
    lg.print("top buttons change", x + 4, y + 153)
  end
end

local function draw_hint(s, y, alpha)
  lg.setFont(D.font(21))
  lg.setColor(0.85, 0.8, 1, alpha or 0.9)
  lg.printf(s, 0, y, W, "center")
end

-- The bottom line: how to play, and, for the chosen game, how to come back from it.
local function draw_footer()
  local it = items[ST.sel]
  local leave = LEAVE[it.kind]
  if leave and math.floor(t / 4) % 2 == 1 then
    draw_hint(it.kind == "classic" and "in the game:  hold 1-PLAYER for 5 seconds to come back"
              or "in the game:  hold 1-PLAYER + 2-PLAYER to come back", 999, 0.9)
  else
    draw_hint("STICK  choose  ·  LEFT/RIGHT  section  ·  LOWER BUTTON  play", 999, 0.9)
  end
end

-- NEW HIGH SCORE: a banner and confetti in the game's colour and its friends, for 5 s (any press keeps going).

local function draw_celebration()
  if not ST.celebrate then return end
  local c = ST.celebrate
  if not ST.confetti then
    ST.confetti = {}
    local cols = {{D.rgb(c.tint)}, {1, 0.31, 0.85}, {0.43, 0.94, 0.78}, {1, 0.82, 0.25}, {0.55, 0.7, 1}}
    for i = 1, 140 do
      ST.confetti[i] = {x = math.random() * W, y = -40 - math.random() * 900, vy = 260 + math.random() * 260,
                     sway = math.random() * 6, ph = math.random() * 6, w = 6 + math.random() * 8,
                     col = cols[math.random(#cols)]}
    end
  end
  local fade = math.min(1, c.t * 4, (5 - c.t) * 2)
  local pop = 1 + 0.15 * math.max(0, 1 - c.t * 3)
  local r, g, b = D.rgb(c.tint)
  -- The banner, over the chosen card.
  local by, bh = 395, 220
  fx.glow(W / 2, by + bh / 2, 380, 170, r, g, b, 0.35 * fade)
  lg.setColor(0.04, 0.0, 0.10, fade)
  D.rrect("fill", 44, by, W - 88, bh, 28)
  lg.setColor(r, g, b, fade)
  lg.setLineWidth(4)
  D.rrect("line", 44, by, W - 88, bh, 28)
  if not c.big then
    D.neon_draw("NEW HIGH SCORE!", 0, by + 22, 44, 0xffd23f, 1, "center", W, fade * (0.9 + 0.1 * math.sin(c.t * 2.5)), 1)
  end
  lg.setFont(D.font(math.floor((c.big and 64 or 72) * pop)))
  if c.big then lg.setColor(hue(c.t * 0.8, fade)) else lg.setColor(1, 1, 1, fade) end
  lg.printf(tostring(c.score), 0, by + (c.big and 50 or 80) - 36 * (pop - 1), W, "center")
  lg.setFont(D.font(24))
  lg.setColor(0.85, 0.8, 1, fade)
  lg.printf(c.title, 0, by + 172, W, "center")
  -- Confetti, over everything.
  for _, p in ipairs(ST.confetti) do
    local y = p.y + p.vy * c.t
    if y < H + 20 then
      local x = p.x + math.sin(c.t * 3 + p.ph) * 30 * p.sway / 6
      lg.setColor(p.col[1], p.col[2], p.col[3], fade)
      lg.push()
      lg.translate(x, y)
      lg.rotate(c.t * 4 + p.ph)
      lg.rectangle("fill", -p.w / 2, -p.w / 4, p.w, p.w / 2)
      lg.pop()
    end
  end
end

local function draw_note()
  if not ST.note then return end
  local a = math.min(1, ST.note_t)
  lg.setColor(0.25, 0.02, 0.12, 0.92 * a)
  D.rrect("fill", 70, 240, W - 140, 60, 20)
  lg.setColor(1, 0.5, 0.6, a)
  D.rrect("line", 70, 240, W - 140, 60, 20)
  lg.setFont(D.font(22))
  lg.printf(ST.note, 70, 256, W - 140, "center")
end

-- The hold meter, as The Yard draws it: a panel in the middle, a bar filling over the hold.
local function draw_hold()
  if I.hold_t <= 0 then return end
  local k = math.min(1, I.hold_t / I.HOLD_SECS)
  local bw, bh = W * 3 / 4, 110
  local bx, by = (W - bw) / 2, H / 2 - bh / 2
  lg.setColor(8 / 255, 6 / 255, 16 / 255, 0.9)
  D.rrect("fill", bx - 6, by - 6, bw + 12, bh + 12, 24)
  lg.setColor(40 / 255, 34 / 255, 64 / 255, 0.95)
  D.rrect("fill", bx, by, bw, bh, 20)
  lg.setColor(1, 200 / 255, 90 / 255)
  D.rrect("fill", bx + 10, by + bh - 34, (bw - 20) * k, 24, 10)
  lg.setColor(1, 246 / 255, 234 / 255)
  lg.setFont(D.font(40))
  lg.printf("back to The Yard...", bx, by + 12, bw, "center")
end

-- The volume meter: fifteen neon bars under the tabs, for a moment after a volume button.
local function draw_volume()
  if ST.vol_t <= 0 or not ST.vol_level then return end
  local a = math.min(1, ST.vol_t * 3)
  local bw, bh = 520, 70
  local bx, by = (W - bw) / 2, 226
  lg.setColor(0.04, 0.0, 0.1, 0.9 * a)
  D.rrect("fill", bx, by, bw, bh, 20)
  lg.setColor(0.43, 0.94, 0.78, a)
  lg.setLineWidth(2)
  D.rrect("line", bx, by, bw, bh, 20)
  lg.setFont(D.font(22))
  lg.print(ST.vol_level == 0 and "MUTED" or "VOLUME", bx + 20, by + 22)
  for i = 1, 15 do
    local on = i <= ST.vol_level
    local h = 14 + i * 2
    local x = bx + 150 + (i - 1) * 23
    lg.setColor(0.43, 0.94, 0.78, (on and 1 or 0.18) * a)
    D.rrect("fill", x, by + bh / 2 + 22 - h, 14, h, 4)
  end
end

-- The night scene (idle a few minutes): the sky dims, the sign sleeps, a chase runs along the horizon.
local function draw_night()
  -- The show (night.lua): the sky through a whole night, the moon, and the scenes.
  local nt = ST.night_t * ST.NIGHT_SPEED
  night.draw(nt)
  -- The sign asleep: it breathes, slowly (dimmer in the rest stretch before dawn).
  local rest = night.scene_at(nt) == "rest" and 0.35 or 1
  local breath = (0.3 + 0.12 * math.sin(ST.night_t * 1.1)) * rest
  fx.glow(W / 2, 80, 330, 60, 1, 0.75, 0.35, breath * 0.25)
  ST.draw(0, 24, 96, breath)
  for i = 0, 2 do
    local k = ((ST.night_t * 0.3) + i / 3) % 1
    local zx, zy = W / 2 + 260 + k * 60 + math.sin(k * 6) * 10, 120 - k * 110
    lg.setFont(D.font(math.floor(30 + k * 26)))
    lg.setColor(0.43, 0.94, 0.78, math.sin(k * math.pi) * 0.85 * rest)
    lg.print("z", zx, zy)
  end
  draw_hint("press any button", 930, (0.35 + 0.25 * math.sin(t * 2)) * rest)
end

-- The sign, unlit: the board dark, its bulbs out, the tubes faintly there (the power-on picture).
local function draw_unlit_sign(a)
  ST.draw_bulbs(a or 1, 0)
  D.face = "script"
  lg.setFont(D.script_font(96))
  D.face = "round"
  lg.setColor(0.28, 0.2, 0.12, a or 1)
  lg.printf(ST.BRAND, 0, 24 + 10, W, "center")
end

-- Power-on: the world comes up out of the dark; the bulbs light round the board in turn; STARLIGHT is written
-- across in neon, a spark at the pen; "ARCADE · SHOWS · TV" under it; then the menu fades in under the sign.
local INTRO_LEN = 3.0
local function draw_intro()
  local up = math.min(1, ST.intro_t / 0.6)
  if up < 1 then
    lg.setColor(0, 0, 0, 1 - up)
    lg.rectangle("fill", 0, 0, W, H)
  end
  local lit = math.max(0, math.min(1, (ST.intro_t - 0.3) / 1.0))
  ST.draw_bulbs(1, lit)
  local wk = math.max(0, math.min(1, (ST.intro_t - 0.9) / 1.0))
  if wk < 1 then draw_unlit_sign() end
  if wk > 0 then
    -- the wordmark written across: a widening window over the painted label
    local e = ST.img(96)
    local x0 = math.floor((W - e.w) / 2)
    local wx = x0 + e.w * wk
    lg.setScissor(0, 0, math.floor(wx), H)
    ST.draw(0, 24, 96, 1)
    lg.setScissor()
    if wk < 1 then
      fx.glow(wx, 90, 40, 40, 1, 0.9, 0.6, 0.9)
      lg.setColor(1, 1, 0.9, 1)
      lg.circle("fill", wx, 90 + math.sin(wk * 9) * 16, 4, 8)
    end
    fx.glow(W / 2, 92, 300, 70, 1, 0.75, 0.35, 0.16 * wk)
  end
  if ST.intro_t > 1.9 then
    local a = math.min(1, (ST.intro_t - 1.9) / 0.5)
    D.neon_draw("ARCADE  ·  SHOWS  ·  TV", 0, 470, 34, ST.ACCENT, 0.8, "center", W, a)
  end
end

local function draw_scene()
  -- Waking: dark while the menu's pictures come back; once its labels are painted, the menu is drawn under the
  -- (opaque) cover, so whatever it still paints on first use is painted where nothing can be seen.
  if ST.wake and ST.wake.phase == "cover" and (ST.wake.n <= 2 or #D.label_jobs > 0) then
    lg.clear(0.02, 0.01, 0.05, 1)
    return
  end
  if ST.scene == "hall" then
    ST.hall.draw()
    draw_volume()
    return
  end
  if ST.scene == "shelf" then
    shelf.draw()
    draw_volume()
    draw_note()
    return
  end
  if ST.scene == "tv" then
    -- The guide draws its own quiet backdrop (Home's sky under it cost ~15 fps: two extra full-screen passes).
    tv.draw()
    draw_volume()
    draw_note()
    return
  end
  if ST.scene == "show" and ST.cur_show then
    -- An idle show draws the whole picture (freedom.lua, texas.lua, ...).
    ST.L.top_busy = 0
    ST.cur_show.draw()
    -- the on-air bug: STARLIGHT, faint, in the corner; it fades away while the show writes up there
    ST.bug = math.max(0, math.min(1, (ST.bug or 1) + (ST.L.top_busy > 0 and -0.08 or 0.03)))
    if not ST.curtain and ST.bug > 0 then ST.draw(W - 190, 8, 30, 0.38 * ST.bug, nil, "left", 180) end
    curtain_draw()
    draw_volume()
    return
  end
  if ST.scene == "shows" then
    shows.draw()
    draw_volume()
    return
  end
  local dim = ST.scene == "night" and 1 or 0
  draw_background(dim)
  if ST.scene == "intro" then
    draw_intro()
    return
  end
  if ST.scene == "night" then
    draw_night()
    return
  end
  draw_marquee()
  draw_tabs(items[ST.sel].section)
  draw_carousel()
  if ST.scene == "attract" then
    lg.setColor(0, 0, 0, 0.25)
    lg.rectangle("fill", 0, 780, W, H - 780)
    D.neon_draw("PRESS ANY BUTTON", 0, 860, 44, 0xffd23f, 1, "center", W, 0.6 + 0.4 * math.sin(t * 4))
    local it = items[ST.sel]
    if it.score then
      draw_hint("HIGH SCORE  " .. it.score .. "  —  can you beat it?", 930, 0.9)
    else
      draw_hint(ST.now_line or "12 CLASSICS  ·  THE YARD  ·  SHOWS  ·  TV", 930, 0.9)
    end
  else
    draw_info()
    draw_footer()
  end
  if ST.menu_in > 0 then
    -- After the intro: the menu comes up under the sign.
    lg.setColor(0.02, 0.0, 0.05, ST.menu_in / 0.45 * 0.8)
    lg.rectangle("fill", 0, 178, W, H - 178)
  end
  if ST.wake then
    lg.setColor(0.02, 0.01, 0.05, math.max(0, 1 - ST.wake.f / ST.WAKE_FADE))
    lg.rectangle("fill", 0, 0, W, H)
  end
  draw_volume()
  draw_celebration()
  if ST.scene == "initials" then ST.initials.draw() end
  draw_note()
  draw_hold()
  if ST.launch_item then
    local r, g, b = D.rgb(ST.launch_item.tint)
    local k = math.max(0, math.min(1, (ST.launch_t - 0.25) / 0.3))
    lg.setColor(r * 0.16, g * 0.08, b * 0.2, k)        -- into a dark glow of the game's colour
    lg.rectangle("fill", 0, 0, W, H)
  end
end


M.INTRO_LEN = INTRO_LEN
M.draw_background = draw_background
M.draw_scene = draw_scene
return M
end
