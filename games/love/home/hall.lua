-- The Hall of Fame: every arcade board's record in one place, and the cabinet's players ranked across all of
-- them. Opened from the HALL OF FAME card at the head of Home's ARCADE section.
--
-- Scores from different games can't be compared, so players are ranked by places instead: a record (1st) is
-- worth 3, a 2nd place 2, a 3rd 1, on every board. The boards' factory tables (games/shelf/defaults.tsv: the
-- CAPCOMs and JRNs) are "the house": shown, dimmed, and never counted for a player.
local Hall = {}
local lg = love.graphics

local ctx, W, H
local entries = {}   -- {title, tint, img, rows = {{score, name, house}...}, launch, classic}
local champs = {}    -- {name, points, firsts, seconds, thirds}
local sel, scroll, t, idle = 1, 1, 0, 0
local hold = {}
local backdrop_mesh

function Hall.load(c)
  ctx = c
  W, H = c.W, c.H
end

local function rank_players()
  local by = {}
  for _, e in ipairs(entries) do
    if not e.classic and e.rows then
      local place = 0
      for _, r in ipairs(e.rows) do
        if place >= 3 then break end
        place = place + 1
        local name = r[2]
        if not r[3] and name ~= "" then
          local c = by[name] or {name = name, points = 0, firsts = 0, seconds = 0, thirds = 0, games = {}}
          c.points = c.points + (4 - place)
          if place == 1 then c.firsts = c.firsts + 1 c.games[#c.games + 1] = e.title end
          if place == 2 then c.seconds = c.seconds + 1 end
          if place == 3 then c.thirds = c.thirds + 1 end
          by[name] = c
        end
      end
    end
  end
  champs = {}
  for _, c in pairs(by) do champs[#champs + 1] = c end
  table.sort(champs, function(a, b)
    if a.points ~= b.points then return a.points > b.points end
    if a.firsts ~= b.firsts then return a.firsts > b.firsts end
    return a.name < b.name
  end)
end

-- Called each time it opens: the tables as they are now.
function Hall.enter()
  entries = ctx.entries()
  -- Boards whose record a player holds first, then the house's, then the classics (scores only).
  table.sort(entries, function(a, b)
    local ka = a.classic and 2 or ((a.rows and a.rows[1] and not a.rows[1][3]) and 0 or 1)
    local kb = b.classic and 2 or ((b.rows and b.rows[1] and not b.rows[1][3]) and 0 or 1)
    if ka ~= kb then return ka < kb end
    return a.title < b.title
  end)
  rank_players()
  sel, scroll, idle = 1, 1, 0
end

local function move(d)
  local n = math.max(1, math.min(#entries, sel + d))
  if n ~= sel then sel = n ctx.play("move") end
end

function Hall.handle(name)
  idle = 0
  if name == "up" then move(-1)
  elseif name == "down" then move(1)
  elseif name == "left" or name == "tl" then move(-5)
  elseif name == "right" or name == "tr" then move(5)
  elseif name == "low" or name == "1p" then
    local e = entries[sel]
    if e and e.launch then ctx.play("launch") e.launch() end
  elseif name == "2p" then
    ctx.play("back")
    return "exit"
  end
end

function Hall.update(dt)
  t = t + dt
  idle = idle + dt
  for _, d in ipairs({"up", "down"}) do
    if ctx.down[d] then
      local h = hold[d] or {held = 0, next = 0.35}
      h.held = h.held + dt
      if h.held >= h.next then h.next = h.held + 0.09 move(d == "up" and -1 or 1) idle = 0 end
      hold[d] = h
    else
      hold[d] = nil
    end
  end
  -- Left alone, it reads itself out: a row every 2.5 s, round and round.
  if idle > 6 and #entries > 0 then
    local k = math.floor((idle - 6) / 2.5)
    sel = (k % #entries) + 1
  end
  scroll = scroll + (sel - scroll) * math.min(1, dt * 8)
  if idle > 180 then return "exit" end
end

-- ------------------------------------------------------------------ drawing

local GOLD, SILVER, BRONZE = 0xffd23f, 0xd8dcf0, 0xe0905a

local function podium(c, x, w, top, h, col, place)
  local r, g, b = ctx.rgb(col)
  -- the step
  lg.setColor(r, g, b, 0.18)
  ctx.rrect("fill", x, top, w, h, 14)
  lg.setColor(r, g, b, 0.9)
  lg.setLineWidth(3)
  ctx.rrect("line", x, top, w, h, 14)
  lg.setFont(ctx.font(26))
  lg.setColor(r, g, b, 1)
  lg.printf(place == 1 and "1ST" or place == 2 and "2ND" or "3RD", x, top + h - 40, w, "center")
  if not c then return end
  -- the champion on it
  local bob = math.sin(t * 2 + place) * 4
  if place == 1 then
    -- a crown
    local cx, cy = x + w / 2, top - 112 + bob
    lg.setColor(1, 0.82, 0.25, 1)
    lg.polygon("fill", cx - 34, cy + 18, cx - 34, cy - 10, cx - 17, cy + 4, cx, cy - 20, cx + 17, cy + 4, cx + 34, cy - 10,
               cx + 34, cy + 18)
    ctx.fx.glow(cx, cy, 70, 40, 1, 0.82, 0.25, 0.35)
  end
  ctx.neon_draw(c.name, x - 30, top - 92 + bob, 64, col, 1.2, "center", w + 60, 1, place == 1 and 1.1 or 0.85)
  lg.setFont(ctx.font(20))
  lg.setColor(1, 1, 1, 0.95)
  lg.printf(c.points .. " PTS", x, top + 14, w, "center")
  lg.setFont(ctx.font(16))
  lg.setColor(0.86, 0.84, 0.98, 0.9)
  lg.printf(c.firsts .. (c.firsts == 1 and " record" or " records"), x, top + 40, w, "center")
end

local function draw_champions()
  local y0 = 112
  lg.setFont(ctx.font(22))
  lg.setColor(1, 0.85, 0.3, 0.95)
  lg.printf("CHAMPIONS  ·  a record 3 points, 2nd 2, 3rd 1, on every game", 0, y0, W, "center")
  if #champs == 0 then
    lg.setFont(ctx.font(26))
    lg.setColor(0.92, 0.9, 1, 1)
    lg.printf("No champions yet.\nBeat a house record on any ARCADE game\nand your initials go up here.", 40, y0 + 90,
              W - 80, "center")
    return
  end
  local base = y0 + 340
  podium(champs[2], 64, 190, base - 120, 120, SILVER, 2)
  podium(champs[1], 289, 190, base - 170, 170, GOLD, 1)
  podium(champs[3], 514, 190, base - 90, 90, BRONZE, 3)
  -- 4th and on, one line
  if #champs > 3 then
    local more = {}
    for i = 4, math.min(8, #champs) do more[#more + 1] = i .. ". " .. champs[i].name .. " " .. champs[i].points end
    lg.setFont(ctx.font(18))
    lg.setColor(0.86, 0.84, 0.98, 0.85)
    lg.printf(table.concat(more, "     "), 0, base + 12, W, "center")
  end
end

local ROW_H, LIST_TOP = 104, 500

local function draw_row(e, y, focus, a)
  local r, g, b = ctx.rgb(e.tint or 0xffb43c)
  lg.setColor(0.07, 0.03, 0.14, (focus and 0.95 or 0.75) * a)
  ctx.rrect("fill", 28, y, W - 56, ROW_H - 12, 16)
  if focus then
    lg.setColor(r, g, b, a)
    lg.setLineWidth(3)
    ctx.rrect("line", 28, y, W - 56, ROW_H - 12, 16)
  end
  -- (the card's picture as it is now: it may arrive from the worker after the Hall opened)
  local img = e.img or (e.item and (e.item.shot or e.item.art))
  if img then
    local iw, ih = img:getDimensions()
    local s = math.min(110 / iw, (ROW_H - 24) / ih)
    lg.setColor(1, 1, 1, a)
    lg.draw(img, 40 + (110 - iw * s) / 2, y + 6 + (ROW_H - 24 - ih * s) / 2, 0, s, s)
  end
  local x = 166
  lg.setFont(ctx.font(22))
  lg.setColor(r, g, b, a)
  lg.printf(e.title, x, y + 10, 330, "left")
  local top = e.rows and e.rows[1]
  if top then
    lg.setFont(ctx.font(36))
    lg.setColor(1, 1, 1, (top[3] and 0.55 or 1) * a)
    lg.printf(ctx.commas(top[1]), x, y + 38, 300, "left")
    if top[2] ~= "" then
      ctx.neon_draw(top[2], W - 260, y + 18, 64, top[3] and 0x8a86a8 or (e.tint or GOLD), top[3] and 0.4 or 1.1, "center",
                    200, a, 0.7)
    end
    lg.setFont(ctx.font(14))
    if top[3] then
      lg.setColor(0.7, 0.68, 0.85, 0.8 * a)
      lg.printf("HOUSE", W - 260, y + 66, 200, "center")
    end
    local second = e.rows[2]
    if second then
      lg.setColor(0.8, 0.78, 0.92, 0.75 * a)
      lg.printf("2nd  " .. (second[2] ~= "" and second[2] or "---") .. "  " .. ctx.commas(second[1]), x + 160, y + 52, 200, "right")
    end
  else
    lg.setFont(ctx.font(18))
    lg.setColor(0.8, 0.78, 0.92, 0.7 * a)
    lg.printf("no scores yet", x, y + 46, 300, "left")
  end
end

function Hall.draw()
  if not backdrop_mesh then
    backdrop_mesh = lg.newMesh({{0, 0, 0, 0, 0.09, 0.03, 0.12, 1}, {W, 0, 0, 0, 0.09, 0.03, 0.12, 1},
                                {W, H, 0, 0, 0.03, 0.01, 0.06, 1}, {0, H, 0, 0, 0.03, 0.01, 0.06, 1}}, "fan", "static")
  end
  lg.setColor(1, 1, 1, 1)
  lg.draw(backdrop_mesh)
  -- Chaser bulbs along the top, the marquee's.
  for i = 0, 23 do
    local on = (math.floor(t * 8) + i) % 3 == 0
    lg.setColor(1, 0.85, 0.4, on and 1 or 0.25)
    lg.circle("fill", 20 + i * 31.5, 14, 4)
  end
  ctx.neon_draw("HALL OF FAME", 0, 30, 64, GOLD, 1.3, "center", W, 0.92 + 0.08 * math.sin(t * 3), 0.95)
  draw_champions()
  -- The records, the chosen one in the middle of the list.
  lg.setScissor(0, LIST_TOP - 6, W, H - LIST_TOP - 40)
  local first = math.max(1, math.floor(scroll) - 2)
  for i = first, math.min(#entries, first + 6) do
    local y = LIST_TOP + (i - scroll) * ROW_H + ROW_H
    if y > LIST_TOP - ROW_H and y < H - 40 then
      local a = math.max(0.25, math.min(1, 1 - math.abs(i - scroll) * 0.12))
      draw_row(entries[i], y, i == sel, a)
    end
  end
  lg.setScissor()
  lg.setColor(0.02, 0.0, 0.06, 0.9)
  lg.rectangle("fill", 0, H - 40, W, 40)
  lg.setFont(ctx.font(17))
  lg.setColor(0.86, 0.84, 0.98, 0.9)
  lg.printf("STICK: scroll     LOWER: play that game     2-PLAYER: back", 0, H - 30, W, "center")
end

return Hall
