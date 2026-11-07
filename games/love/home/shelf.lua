-- The Shelf: the cartridge and arcade library on the microSD card, browsed inside Home (games/shelf/PLAN.md).
-- Home's GAMES cards open it at a row; choosing a game hands the screen to the player (games/native/play)
-- through homeloop ("shelf <system> <file>" request), and Home comes back here, on the same game.
--
-- Data (on the card, written on the PC by tools/shelf_index.py):
--   LIB/index.tsv                system, file, title, year, maker, art, tags, blurb, button names
--   LIB/art/<system>/<stem>.png  the box (consoles) or title screen (arcade), fitted to 180x240
--   LIB/recent.tsv               the last games played, newest first: system, file (written here)
-- Rows: PARTY PICKS (tag party: short turns, a score to beat), CONTINUE (recent), then one per system.
local S = {}
local lg = love.graphics

local LIB = os.getenv("SHELF_LIB") or "/mnt/sdcard/library"
local RET = os.getenv("SHELF_RET") or "/tmp/shelf.ret"
local IDLE_OUT = 120

local SYSTEMS = {
  {id = "arcade", name = "ARCADE", tint = 0xffb43c},
  {id = "nes", name = "NES", tint = 0xff5a5a},
  {id = "snes", name = "SUPER NINTENDO", tint = 0xa58bff},
  {id = "genesis", name = "GENESIS", tint = 0x4f9dff},
  {id = "gb", name = "GAME BOY", tint = 0xa8d84a},
  {id = "gba", name = "GAME BOY ADVANCE", tint = 0x8f7dff},
  {id = "sms", name = "MASTER SYSTEM", tint = 0xff6a5a},
  {id = "gg", name = "GAME GEAR", tint = 0x5fd0ff},
  {id = "pce", name = "PC ENGINE", tint = 0xffa04a},
  {id = "ngp", name = "NEO GEO POCKET", tint = 0x5aa8ff},
  {id = "sg", name = "SG-1000", tint = 0xc8c8d8},
}
local SYS = {}
for _, s in ipairs(SYSTEMS) do SYS[s.id] = s end
-- The deck's buttons per system when a game names none (games/native/play/play_sys.h).
local DEFAULT_LABELS = {
  arcade = "BUTTON 1|BUTTON 2|BUTTON 3", nes = "A|B", snes = "B|Y|A", genesis = "B|A|C", gb = "A|B",
  gba = "A|B|R", sms = "1|2", gg = "1|2", sg = "1|2", pce = "I|II", ngp = "A|B|OPTION",
}

local ctx, W, H
local games = {}        -- every game in the index
local rows = {}         -- {key, title, tint, games}
local sel, cols = 1, {}
local yscroll, xscroll = 1, {}
local t, idle = 0, 0
local hold = {}
local art = {}          -- path -> Image, false while asked, nil not asked
local art_order = {}    -- paths with an Image, oldest first (at most ART_KEEP)
local ART_KEEP, asking = 40, 0
local note, note_t

local function read_file(path)
  local f = io.open(path, "rb")
  if not f then return nil end
  local s = f:read("*a")
  f:close()
  return s
end

local function split_tab(line)
  local out = {}
  for field in (line .. "\t"):gmatch("([^\t]*)\t") do out[#out + 1] = field end
  return out
end

local function fit(font, s, w, lines)
  if font:getWidth(s) <= w * (lines or 1) then
    local _, l = font:getWrap(s, w)
    if #l <= (lines or 1) then return s end
  end
  while #s > 1 do
    s = s:sub(1, -2)
    local _, l = font:getWrap(s .. "...", w)
    if #l <= (lines or 1) then return s .. "..." end
  end
  return s
end

local function load_recent()
  local out = {}
  for line in (read_file(LIB .. "/recent.tsv") or ""):gmatch("[^\n]+") do
    local f = split_tab(line)
    if f[1] and f[2] then out[#out + 1] = f[1] .. "/" .. f[2] end
  end
  return out
end

local function save_recent(g)
  local list = load_recent()
  local key = g.sys .. "/" .. g.file
  local out = {g.sys .. "\t" .. g.file}
  for _, k in ipairs(list) do
    if k ~= key and #out < 12 then
      local s, f = k:match("^([^/]+)/(.*)$")
      out[#out + 1] = s .. "\t" .. f
    end
  end
  local f = io.open(LIB .. "/recent.tsv", "w")
  if f then f:write(table.concat(out, "\n") .. "\n") f:close() end
end

local function build_rows()
  rows = {}
  local by_key, party = {}, {}
  for _, g in ipairs(games) do by_key[g.sys .. "/" .. g.file] = g end
  -- The arcade boards have Home's ARCADE section to themselves (a card each, with their high scores).
  for _, g in ipairs(games) do if g.tags.party and g.sys ~= "arcade" then party[#party + 1] = g end end
  table.sort(party, function(a, b) return a.title:lower() < b.title:lower() end)
  if #party > 0 then
    rows[#rows + 1] = {key = "party", title = "PARTY PICKS", sub = "short turns, a score to beat: pass the stick",
                       tint = 0xff4fd8, games = party}
  end
  local recent = {}
  for _, k in ipairs(load_recent()) do
    if by_key[k] and by_key[k].sys ~= "arcade" then recent[#recent + 1] = by_key[k] end
  end
  if #recent > 0 then
    rows[#rows + 1] = {key = "recent", title = "CONTINUE", sub = "played lately", tint = 0x6ef0c8, games = recent}
  end
  for _, s in ipairs(SYSTEMS) do
    if s.id == "arcade" then goto next_system end
    local list = {}
    for _, g in ipairs(games) do if g.sys == s.id then list[#list + 1] = g end end
    if #list > 0 then
      rows[#rows + 1] = {key = s.id, title = s.name, sub = #list .. (#list == 1 and " game" or " games"), tint = s.tint,
                         games = list}
    end
    ::next_system::
  end
  if sel > #rows then sel = math.max(1, #rows) end
end

local function load_index()
  games = {}
  local s = read_file(LIB .. "/index.tsv")
  if not s then return end
  for line in s:gmatch("[^\n]+") do
    if not line:match("^#") then
      local f = split_tab(line)
      if SYS[f[1]] and f[2] and f[2] ~= "" then
        local tags = {}
        for w in (f[7] or ""):gmatch("%S+") do tags[w] = true end
        local labels = {}
        for l in ((f[9] ~= nil and f[9] ~= "" and f[9]) or DEFAULT_LABELS[f[1]] or ""):gmatch("([^|]*)|?") do
          labels[#labels + 1] = l
          if #labels == 3 then break end
        end
        games[#games + 1] = {sys = f[1], file = f[2], title = f[3] ~= "" and f[3] or f[2], year = f[4] or "",
                             maker = f[5] or "", art = (f[6] or "") ~= "" and (LIB .. "/" .. f[6]) or nil, tags = tags,
                             blurb = f[8] or "", labels = labels, tint = tonumber(f[10] or "", 16)}
      end
    end
  end
end

-- ------------------------------------------------------------------ the interface Home uses

-- Read the card's index (before Home builds its cards; no drawing yet).
function S.init()
  load_index()
  build_rows()
end

function S.load(c)
  ctx = c
  W, H = c.W, c.H
end

-- The line under a GAMES card on Home's info panel: a few of the row's titles.
function S.card_blurb(key)
  local r
  for _, x in ipairs(rows) do if x.key == key then r = x end end
  if not r then return "" end
  local names = {}
  for i = 1, math.min(3, #r.games) do names[#names + 1] = r.games[i].title end
  local more = #r.games > 3 and (" and " .. (#r.games - 3) .. " more.") or "."
  return table.concat(names, ", ") .. more
end

-- Home's GAMES cards: one per row (PARTY PICKS, then each system with games).
function S.cards()
  local out = {}
  for _, r in ipairs(rows) do
    if r.key ~= "recent" then
      out[#out + 1] = {key = r.key, title = r.title, sub = r.sub, tint = r.tint, count = #r.games}
    end
  end
  return out
end

function S.count() return #games end

local function row_index(key)
  for i, r in ipairs(rows) do if r.key == key then return i end end
end

function S.enter(key)
  idle, note = 0, nil
  build_rows()
  sel = row_index(key) or 1
  yscroll = sel
end

-- Coming back from a game: the row and game it was started from (written just before the launch).
function S.returning()
  local r = read_file(RET)
  if not r then return nil end
  os.remove(RET)
  local key, file, failed = r:match("^(%S+)\t([^\t\n]+)\t?(%S*)")
  return key, file, failed == "failed"
end

function S.enter_at(key, file, failed)
  S.enter(key)
  local r = rows[sel]
  if r then
    for i, g in ipairs(r.games) do if g.file == file then cols[r.key] = i xscroll[r.key] = math.max(0, i - 2) end end
  end
  if failed then note, note_t = "That game didn't start. Its file may be damaged.", 6 end
end

-- ------------------------------------------------------------------ art

local function ask_art(path)
  if not path or art[path] ~= nil or asking >= 3 or not ctx.request_art then return end
  art[path] = false
  asking = asking + 1
  ctx.request_art("shelf:" .. path, path)
end

function S.art_ready(key, data)
  local path = key:sub(7)
  asking = math.max(0, asking - 1)
  if not data then return end
  local ok, img = pcall(lg.newImage, data)
  if not ok then return end
  art[path] = img
  art_order[#art_order + 1] = path
  while #art_order > ART_KEEP do
    local old = table.remove(art_order, 1)
    if art[old] then art[old]:release() end
    art[old] = nil
  end
end

function S.art_failed(key)
  asking = math.max(0, asking - 1)
  art[key:sub(7)] = nil
end


-- ------------------------------------------------------------------ arcade high scores

-- How each board keeps its table: LIB/scores.tsv (games/shelf/scores.tsv; tools/arcade_scores.py is the
-- reference decoder, keep the two in step). The tables themselves are the boards' own: MAME 2000 saves them
-- (saves/arcade/mame2000/hi/<set>.hi), or the board does in its settings memory (nvram/<set>.nv).
local SCORES
local function load_scores()
  SCORES = {}
  for line in (read_file(LIB .. "/scores.tsv") or ""):gmatch("[^\n]+") do
    if not line:match("^#") then
      local f = split_tab(line)
      if #f >= 12 then
        SCORES[f[1]] = {file = f[2], first = tonumber(f[3]), stride = tonumber(f[4]), count = tonumber(f[5]),
                        soff = tonumber(f[6]), slen = tonumber(f[7]), enc = f[8], mul = tonumber(f[9]),
                        noff = tonumber(f[10]), nlen = tonumber(f[11]), chars = f[12]}
      end
    end
  end
end

local LETTER_BASE = {t0a = 0x0a, t0b = 0x0b, t11 = 0x11}
local function letter(b, chars)
  if chars == "ascii" then
    if (b >= 0x41 and b <= 0x5a) or (b >= 0x61 and b <= 0x7a) or (b >= 0x30 and b <= 0x39) or b == 0x2e or b == 0x21 then
      return string.char(b):upper()
    end
    return " "
  end
  local base = LETTER_BASE[chars]
  if base and b >= base and b < base + 26 then return string.char(65 + b - base) end
  if b <= 9 then return tostring(b) end
  return " "
end

-- A board's table, best first: {{score, name}, ...}, or nil when it has none yet.
function S.arcade_table(set)
  if not SCORES then load_scores() end
  local sp = SCORES[set]
  if not sp then return nil end
  local dir = LIB .. "/saves/arcade/mame2000/"
  local data = read_file(sp.file == "hi" and (dir .. "hi/" .. set .. ".hi") or (dir .. "nvram/" .. set .. ".nv"))
  if not data then return nil end
  local first = sp.first
  if sp.file == "nv4" then
    -- A Williams board: four bits a byte. Pack the low nibbles from the first offset.
    local out = {}
    for i = sp.first + 1, #data - 1, 2 do
      out[#out + 1] = string.char((data:byte(i) % 16) * 16 + data:byte(i + 1) % 16)
    end
    data, first = table.concat(out), 0
  end
  local rows = {}
  for k = 0, sp.count - 1 do
    local at = first + k * sp.stride + 1
    local v, ok = 0, true
    for i = 0, sp.slen - 1 do
      local idx = sp.enc:match("le$") and (at + sp.soff + sp.slen - 1 - i) or (at + sp.soff + i)
      local b = data:byte(idx) or 0
      if sp.enc:match("^bcd") then
        local hi, lo = math.floor(b / 16), b % 16
        if hi > 9 or lo > 9 then ok = false break end
        v = v * 100 + hi * 10 + lo
      else
        v = v * 10 + (b <= 9 and b or 0)
      end
    end
    if ok and data:byte(at + sp.soff + sp.slen - 1) then
      local name = ""
      for i = 0, sp.nlen - 1 do name = name .. letter(data:byte(at + sp.noff + i) or 0, sp.chars) end
      rows[#rows + 1] = {v * sp.mul, (name:gsub("^%s+", ""):gsub("%s+$", ""):gsub("%s+", " "))}
    end
  end
  table.sort(rows, function(a, b) return a[1] > b[1] end)
  rows.nameless = sp.nlen == 0
  -- Initials Home asked for (initials.lua) where the board keeps none: names.tsv, by set and score.
  for line in (read_file(LIB .. "/saves/arcade/names.tsv") or ""):gmatch("[^\n]+") do
    local f = split_tab(line)
    if f[1] == set then
      for _, r in ipairs(rows) do
        if r[1] == tonumber(f[2]) and r[2] == "" then r[2] = f[3] end
      end
    end
  end
  if rows[1] and rows[1][2] ~= "" then rows.nameless = false end
  return #rows > 0 and rows or nil
end

function S.save_name(set, score, initials)
  os.execute("mkdir -p '" .. LIB .. "/saves/arcade'")
  local f = io.open(LIB .. "/saves/arcade/names.tsv", "a")
  if f then f:write(set .. "\t" .. math.floor(score) .. "\t" .. initials .. "\n") f:close() end
end

function S.commas(n)
  local s = tostring(math.floor(n))
  while true do
    local k
    s, k = s:gsub("^(%d+)(%d%d%d)", "%1,%2")
    if k == 0 then return s end
  end
end

-- The arcade boards for Home's ARCADE section, the walk-up score games first (games/shelf/curation.tsv tags
-- party), then the long ones (beat-'em-ups, run-and-guns).
local ARCADE_FIRST = {"dkong", "dkongjr", "mario", "joust", "defender", "frogger", "1942", "1943", "pang", "bublbobl",
                      "snowbros", "arkanoid", "bombjack", "commando", "elevator", "tron", "circus", "gng", "contra",
                      "strider"}
function S.arcade_games()
  local list, rank = {}, {}
  for i, id in ipairs(ARCADE_FIRST) do rank[id] = i end
  for _, g in ipairs(games) do
    if g.sys == "arcade" then
      g.set = g.file:gsub("%.zip$", "")
      list[#list + 1] = g
    end
  end
  table.sort(list, function(a, b)
    local ra, rb = rank[a.set] or 100, rank[b.set] or 100
    if ra ~= rb then return ra < rb end
    return a.title:lower() < b.title:lower()
  end)
  return list
end

function S.art_path(g) return g.art end

-- An arcade board's "get ready": its title screen, the scores to beat, the buttons, how to come back.
function S.picture_arcade(g, img, tint)
  ctx.backdrop()
  local rr, gg, bb = ctx.rgb(tint)
  ctx.fx.glow(W / 2, 300, 300, 240, rr, gg, bb, 0.35)
  if img then
    local iw, ih = img:getDimensions()
    local sc = math.min(250 / iw, 330 / ih)
    lg.setColor(1, 1, 1, 1)
    lg.draw(img, W / 2, 300, 0, sc, sc, iw / 2, ih / 2)
  end
  lg.setFont(ctx.font(38))
  lg.setColor(1, 1, 1, 1)
  lg.printf(fit(ctx.font(38), g.title, W - 80, 1), 40, 482, W - 80, "center")
  local t = S.arcade_table(g.set)
  if t then
    ctx.neon_draw("SCORES TO BEAT", 0, 540, 34, 0xffd23f, 1, "center", W)
    lg.setFont(ctx.font(26))
    for i = 1, math.min(5, #t) do
      local y = 590 + (i - 1) * 34
      lg.setColor(i == 1 and 1 or 0.9, i == 1 and 0.85 or 0.88, i == 1 and 0.3 or 1, 1)
      lg.printf(i .. ".", 150, y, 50, "right")
      lg.printf(t[i][2] ~= "" and t[i][2] or "---", 220, y, 200, "left")
      lg.printf(S.commas(t[i][1]), 400, y, 220, "right")
    end
  else
    ctx.neon_draw("GET READY!", 0, 560, 44, 0xffd23f, 1, "center", W)
  end
  lg.setColor(0.04, 0.0, 0.10, 0.85)
  ctx.rrect("fill", 60, 790, W - 120, 200, 24)
  lg.setColor(rr, gg, bb, 0.9)
  lg.setLineWidth(2)
  ctx.rrect("line", 60, 790, W - 120, 200, 24)
  lg.setFont(ctx.font(23))
  lg.setColor(0.92, 0.9, 1, 1)
  local lines = S.legend_lines(g)
  lines[#lines + 1] = "1-PLAYER   coin and start      2-PLAYER   coin"
  lines[#lines + 1] = "HOLD 1-PLAYER + 2-PLAYER   back to Home"
  lg.printf(table.concat(lines, "\n"), 60, 812, W - 120, "center")
end

-- ------------------------------------------------------------------ moving

local function cur_game()
  local r = rows[sel]
  return r and r.games[cols[r.key] or 1], r
end

local function move_row(d)
  local n = math.max(1, math.min(#rows, sel + d))
  if n ~= sel then sel = n ctx.play("move") end
end

local function move_col(d)
  local r = rows[sel]
  if not r then return end
  local c = cols[r.key] or 1
  local n = math.max(1, math.min(#r.games, c + d))
  if n ~= c then cols[r.key] = n ctx.play("move") end
end

function S.legend_lines(g)
  local l = g.labels
  local out = {}
  local names = {"LOWER", "TOP-LEFT", "TOP-RIGHT"}
  for i = 1, 3 do if l[i] and l[i] ~= "" then out[#out + 1] = names[i] .. "  " .. l[i] end end
  return out
end

-- The "get ready" picture: the box, the title, what the buttons do, how to come back.
local function picture_launch(g, r)
  ctx.backdrop()
  local rr, gg, bb = ctx.rgb(r.tint)
  ctx.fx.glow(W / 2, 330, 340, 260, rr, gg, bb, 0.35)
  local img = g.art and art[g.art]
  if img then
    local iw, ih = img:getDimensions()
    local s = math.min(300 / iw, 380 / ih)
    lg.setColor(1, 1, 1, 1)
    lg.draw(img, W / 2, 330, 0, s, s, iw / 2, ih / 2)
  end
  lg.setFont(ctx.font(40))
  lg.setColor(1, 1, 1, 1)
  lg.printf(fit(ctx.font(40), g.title, W - 80, 2), 40, 548, W - 80, "center")
  ctx.neon_draw("GET READY", 0, 640, 44, r.tint, 1, "center", W)
  lg.setColor(0.04, 0.0, 0.10, 0.85)
  ctx.rrect("fill", 60, 730, W - 120, 250, 24)
  lg.setColor(rr, gg, bb, 0.9)
  lg.setLineWidth(2)
  ctx.rrect("line", 60, 730, W - 120, 250, 24)
  lg.setFont(ctx.font(24))
  lg.setColor(0.92, 0.9, 1, 1)
  local lines = S.legend_lines(g)
  local start = g.sys == "arcade" and "1-PLAYER   coin and start" or "1-PLAYER   start / pause"
  lines[#lines + 1] = start
  lines[#lines + 1] = "HOLD 1-PLAYER + 2-PLAYER   back here"
  lg.printf(table.concat(lines, "\n"), 60, 756, W - 120, "center")
end

local function play_chosen()
  local g, r = cur_game()
  if not g then return end
  local f = io.open(RET, "w")
  if f then f:write(r.key .. "\t" .. g.file .. "\n") f:close() end
  save_recent(g)
  ctx.play("launch")
  ctx.request("shelf " .. g.sys .. " " .. g.file, function() picture_launch(g, r) end)
end

-- A press in the browser. Returns "exit" to leave for Home's menu.
function S.handle(name)
  idle = 0
  if name == "up" then move_row(-1)
  elseif name == "down" then move_row(1)
  elseif name == "left" then move_col(-1)
  elseif name == "right" then move_col(1)
  elseif name == "tl" then move_col(-5)
  elseif name == "tr" then move_col(5)
  elseif name == "low" or name == "1p" then play_chosen()
  elseif name == "2p" then
    ctx.play("back")
    return "exit"
  end
end

-- Held stick: after 0.35 s it repeats, faster the longer it is held.
local function repeat_held(dt)
  for _, d in ipairs({"up", "down", "left", "right"}) do
    if ctx.down[d] then
      local h = hold[d] or {held = 0, next = 0.35}
      h.held = h.held + dt
      if h.held >= h.next then
        h.next = h.held + (h.held > 1.5 and 1 / 14 or 1 / 7)
        if d == "up" then move_row(-1) elseif d == "down" then move_row(1)
        elseif d == "left" then move_col(-1) else move_col(1) end
        idle = 0
      end
      hold[d] = h
    else
      hold[d] = nil
    end
  end
end

function S.update(dt)
  t = t + dt
  idle = idle + dt
  repeat_held(dt)
  yscroll = yscroll + (sel - yscroll) * math.min(1, dt * 12)
  for _, r in ipairs(rows) do
    local want = math.max(0, (cols[r.key] or 1) - 2)
    xscroll[r.key] = (xscroll[r.key] or want) + (want - (xscroll[r.key] or want)) * math.min(1, dt * 12)
  end
  if note_t then note_t = note_t - dt if note_t <= 0 then note, note_t = nil, nil end end
  -- Art for what is on screen: the chosen game first, then the visible tiles.
  local g = cur_game()
  if g then ask_art(g.art) end
  for i = math.max(1, sel - 1), math.min(#rows, sel + 2) do
    local r = rows[i]
    local lo = math.max(1, math.floor(xscroll[r.key] or 0))
    for ci = lo, math.min(#r.games, lo + 5) do ask_art(r.games[ci].art) end
  end
  if idle > IDLE_OUT then return "exit" end
end

-- ------------------------------------------------------------------ drawing

local TOP, ROW_H, TW, TH, GAP = 470, 290, 150, 200, 22

local function draw_art(g, cx, cy, mw, mh, a)
  local img = g.art and art[g.art]
  if img then
    local iw, ih = img:getDimensions()
    local s = math.min(mw / iw, mh / ih)
    lg.setColor(1, 1, 1, a)
    lg.draw(img, cx, cy, 0, s, s, iw / 2, ih / 2)
    return iw * s, ih * s
  end
  -- No picture (yet): the title on a plain tile.
  lg.setColor(0.13, 0.08, 0.22, a)
  ctx.rrect("fill", cx - mw / 2, cy - mh / 2, mw, mh, 12)
  local f = ctx.font(20)
  lg.setFont(f)
  lg.setColor(0.92, 0.9, 1, a)
  local s = fit(f, g.title, mw - 16, 4)
  local _, l = f:getWrap(s, mw - 16)
  lg.printf(s, cx - mw / 2 + 8, cy - #l * f:getHeight() / 2, mw - 16, "center")
  return mw, mh
end

local function draw_info()
  local g, r = cur_game()
  local y0 = 100
  lg.setColor(0.04, 0.0, 0.10, 0.82)
  ctx.rrect("fill", 24, y0, W - 48, 330, 22)
  if not g then
    lg.setFont(ctx.font(28))
    lg.setColor(1, 1, 1, 1)
    lg.printf("No games card in the slot.", 48, y0 + 60, W - 96, "center")
    lg.setFont(ctx.font(20))
    lg.setColor(0.9, 0.88, 1, 0.9)
    lg.printf("Power off, put the YARD card in, power on.", 48, y0 + 110, W - 96, "center")
    return
  end
  local tr, tg, tb = ctx.rgb(r.tint)
  lg.setColor(tr, tg, tb, 0.7)
  lg.setLineWidth(2)
  ctx.rrect("line", 24, y0, W - 48, 330, 22)
  draw_art(g, 132, y0 + 165, 196, 290, 1)
  local x, wt = 252, W - 252 - 48
  local y = y0 + 22
  lg.setFont(ctx.font(32))
  lg.setColor(1, 1, 1, 1)
  local title = fit(ctx.font(32), g.title, wt, 2)
  lg.printf(title, x, y, wt, "left")
  local _, tl = ctx.font(32):getWrap(title, wt)
  y = y + #tl * 38 + 4
  local meta = {}
  if g.year ~= "" then meta[#meta + 1] = g.year end
  if g.maker ~= "" then meta[#meta + 1] = g.maker end
  meta[#meta + 1] = SYS[g.sys].name
  lg.setFont(ctx.font(19))
  lg.setColor(tr, tg, tb, 1)
  lg.printf(fit(ctx.font(19), table.concat(meta, "  ·  "), wt, 1), x, y, wt, "left")
  y = y + 32
  if g.blurb ~= "" then
    lg.setFont(ctx.font(22))
    lg.setColor(1, 0.94, 0.78, 1)
    local b = fit(ctx.font(22), g.blurb, wt, 3)
    lg.printf(b, x, y, wt, "left")
    local _, bl = ctx.font(22):getWrap(b, wt)
    y = y + #bl * 28 + 10
  end
  -- What the buttons do in this game.
  lg.setFont(ctx.font(17))
  lg.setColor(0.86, 0.84, 0.98, 0.9)
  local lines = S.legend_lines(g)
  local yb = math.max(y, y0 + 330 - 26 - #lines * 22 - 30)
  for i, l in ipairs(lines) do lg.print(l, x, yb + (i - 1) * 22) end
  -- Tags, bottom right.
  local tags = {}
  if g.tags.party then tags[#tags + 1] = "PARTY PICK" end
  if g.tags.solo then tags[#tags + 1] = "SAVES AS YOU GO" end
  if #tags > 0 then
    lg.setFont(ctx.font(16))
    lg.setColor(tr, tg, tb, 0.95)
    lg.printf(table.concat(tags, "  ·  "), x, y0 + 330 - 30, wt, "right")
  end
end

local function draw_rows()
  local first = math.max(1, math.floor(yscroll) - 1)
  for i = first, math.min(#rows, math.floor(yscroll) + 3) do
    local r = rows[i]
    local y = TOP + (i - yscroll) * ROW_H
    -- Rows above the chosen one fade out before they reach the info panel.
    local a = math.max(0, math.min(1, (y - 380) / 90))
    if a > 0 and y < H then
      local focus_row = i == sel
      local tr, tg, tb = ctx.rgb(r.tint)
      lg.setFont(ctx.font(focus_row and 24 or 20))
      lg.setColor(tr, tg, tb, a * (focus_row and 1 or 0.7))
      lg.print(r.title, 40, y - 36)
      lg.setFont(ctx.font(15))
      lg.setColor(0.8, 0.78, 0.92, a * 0.7)
      lg.printf(r.sub, 40, y - 30, W - 80, "right")
      local xs = xscroll[r.key] or 0
      local c = cols[r.key] or 1
      local lo = math.max(1, math.floor(xs))
      for ci = lo, math.min(#r.games, lo + 5) do
        local g = r.games[ci]
        local x = 40 + (ci - 1 - xs) * (TW + GAP)
        if x > -TW and x < W then
          local focus = focus_row and ci == c
          local s = focus and (1.08 + 0.02 * math.sin(t * 4)) or 1
          local cx, cy = x + TW / 2, y + TH / 2
          if focus then
            lg.setBlendMode("add")
            ctx.fx.glow(cx, cy, TW * 0.85, TH * 0.75, tr, tg, tb, 0.55)
            lg.setBlendMode("alpha")
          end
          local w, h = draw_art(g, cx, cy, TW * s, TH * s, a * ((focus_row or focus) and 1 or 0.75))
          if focus then
            lg.setColor(tr, tg, tb, 1)
            lg.setLineWidth(3)
            ctx.rrect("line", cx - w / 2 - 4, cy - h / 2 - 4, w + 8, h + 8, 8)
          end
          if focus_row then
            lg.setFont(ctx.font(15))
            lg.setColor(0.92, 0.9, 1, a * (focus and 1 or 0.7))
            if not g._cap then g._cap = fit(ctx.font(15), g.title, TW + GAP - 6, 1) end
            lg.printf(g._cap, x - GAP / 2 + 3, y + TH + 12, TW + GAP - 6, "center")
          end
        end
      end
      -- More in this row: a small arrow at the right edge.
      if lo + 4 < #r.games then
        lg.setColor(tr, tg, tb, a * 0.8)
        lg.polygon("fill", W - 18, y + TH / 2 - 14, W - 4, y + TH / 2, W - 18, y + TH / 2 + 14)
      end
    end
  end
end

local backdrop_mesh
function S.draw()
  -- A deep violet gradient in one pass, like the TV guide's (Home's whole sky under it is two more
  -- full-screen passes, and held this screen to 53 fps on the cabinet, 2026-11-07).
  if not backdrop_mesh then
    backdrop_mesh = lg.newMesh({{0, 0, 0, 0, 0.05, 0.02, 0.11, 1}, {W, 0, 0, 0, 0.05, 0.02, 0.11, 1},
                                {W, H, 0, 0, 0.13, 0.02, 0.16, 1}, {0, H, 0, 0, 0.13, 0.02, 0.16, 1}}, "fan", "static")
  end
  lg.setColor(1, 1, 1, 1)
  lg.draw(backdrop_mesh)
  ctx.neon_draw("GAMES", 30, 24, 44, 0xff4fd8, 1, "left", W)
  lg.setFont(ctx.font(20))
  lg.setColor(0.9, 0.86, 1, 0.8)
  lg.printf(#games .. " on the card", 0, 44, W - 36, "right")
  draw_rows()
  draw_info()
  -- Hint line at the bottom.
  lg.setColor(0.02, 0.0, 0.06, 0.85)
  lg.rectangle("fill", 0, H - 44, W, 44)
  lg.setFont(ctx.font(17))
  lg.setColor(0.86, 0.84, 0.98, 0.9)
  lg.printf("LOWER: play     STICK: browse     TOP BUTTONS: skip 5     2-PLAYER: back", 0, H - 32, W, "center")
  if note then
    lg.setColor(0.25, 0.02, 0.1, 0.92)
    ctx.rrect("fill", 60, 440, W - 120, 70, 16)
    lg.setFont(ctx.font(20))
    lg.setColor(1, 0.9, 0.92, 1)
    lg.printf(note, 70, 462, W - 140, "center")
  end
end

function S.quit()
  for _, img in pairs(art) do if img then img:release() end end
  art, art_order = {}, {}
end

return S
