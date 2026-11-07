-- Partycade Home: the front end. Neon arcade: a dark sky over a synthwave grid, a glowing marquee, and a
-- carousel of every game on the cabinet: the twelve classics (with their own logos, cut from the stock menu's
-- pictures by tools/home_art.py), our games, and the way to the original menu. EXPERIENCE.md is the design.
--
-- Home never runs a game itself. It writes what to run into HOME_REQ and quits; homeloop.sh runs it with the
-- whole machine and starts Home again, on the same card. Requests:
--   classic <index> <smoothing 0|1> <speed 0|1>    a stock emulator, as the stock menu's start.sh would
--   cart <id>                                      one of our games, on the GPU runtime
--   native <name>                                  a program in /data/Games (Orb)
--   yard                                           GPU yard, the whole Yard menu
--   stock                                          the original menu
-- The classics' speed and smoothing are the stock menu's own settings (Speed.cfg, Smoothing.cfg: a byte per game).
--
-- Before it quits for a game, Home paints that game's "get ready" picture into /dev/fb0 (splash.lua), which
-- the cabinet shows while the game loads; and, once per boot, the "welcome back" picture homeloop shows when
-- the game ends (HOME_BACK). HOME_RENDER=boot:PATH only renders the power-on picture to PATH (gzip) and quits
-- (cart home-pack runs it on the PC).

-- An error while the modules below load (before the full handler further down): log it and quit, so homeloop
-- moves on. LÖVE's own handler would keep its error screen up for good on a cabinet with no keyboard.
function love.errorhandler(msg)
  local text = "ERROR: " .. debug.traceback(tostring(msg), 2)
  local path = os.getenv("HOME_LOG")
  local f = path and io.open(path, "a")
  if f then f:write(text, "\n") f:close() else print(text) end
  return nil
end

local lg = love.graphics
local sound = require("sound")
local fx = require("fx")
local splash = require("splash")
local night = require("night")
local tv = require("tv")
local music = require("music")
local shows = require("shows")
local shelf = require("shelf")
local utgame = require("utgame")

local W, H = 768, 1024                       -- the upright picture; the panel shows the framebuffer turned
local headless = os.getenv("HOME_HEADLESS") == "1"
local ART = os.getenv("HOME_ART") or "/data/home/art"
local GAMES = os.getenv("HOME_GAMES") or "/data/Games"
local REQ = os.getenv("HOME_REQ")
local STATE = os.getenv("HOME_STATE")
local LOGF = os.getenv("HOME_LOG")
local BACK = os.getenv("HOME_BACK")                                  -- the welcome-back picture (homeloop)
local VOLUME_FILE = os.getenv("HOME_VOLUME") or "/data/spk_volume"
local RENDER = os.getenv("HOME_RENDER")
local IDLE_ATTRACT = tonumber(os.getenv("HOME_IDLE") or "") or 45    -- seconds without a press
local IDLE_NIGHT = tonumber(os.getenv("HOME_NIGHT") or "") or 180
local NIGHT_SPEED = tonumber(os.getenv("HOME_NIGHT_SPEED") or "") or 1   -- tests: the night fast-forwarded
-- HOME_SHOW=ID, ID:SECONDS or ID@SEGMENT (tests, thumbnails): straight into an idle show at start.
local SHOW_NOW = os.getenv("HOME_SHOW")
-- The idle shows (shows.lua). The SCHEDULE card under SHOWS picks which plays when nobody is playing (kept in
-- the state file): AUTO follows the calendar (shows.pick), or one show only.
local SHOW_MODES = {"auto"}
local SHOW_NAMES = {auto = "AUTO"}
for _, sh in ipairs(shows.LIST) do
  if shows.available(sh.id) then SHOW_MODES[#SHOW_MODES + 1] = sh.id SHOW_NAMES[sh.id] = sh.title end
end
local show_mode = "auto"
local AUTO_NIGHT_BLOCK = 1800
local HORIZON = 760

-- (trimmed as it goes: a line every 5 s is ~2 MB a day, and homeloop only trims it when Home starts again)
local LOG_MAX = tonumber(os.getenv("HOME_LOG_MAX") or "") or 131072
local log_size
local function log(...)
  local s = table.concat({...}, " ")
  if LOGF then
    local f = io.open(LOGF, "a")
    if f then
      if not log_size then log_size = f:seek("end") or 0 end
      local line = string.format("%.2f %s\n", love.timer.getTime(), s)
      f:write(line)
      f:close()
      log_size = log_size + #line
      if log_size > LOG_MAX then
        os.rename(LOGF, LOGF .. ".1")
        log_size = 0
      end
    end
  else
    print(s)
  end
end

-- An error: into the log, and quit (homeloop starts Home again; twice in a row, the stock menu). LÖVE's own
-- handler would leave its error screen up for good on a cabinet with no keyboard.
function love.errorhandler(msg)
  log("ERROR: " .. debug.traceback(tostring(msg), 2))
  return nil
end

-- Startup marks (seconds since boot, /proc/uptime): logged once at the first frame. homeloop logs when it
-- started LÖVE, so the log shows where the wait goes.
local function uptime()
  local f = io.open("/proc/uptime", "r")
  local u = f and tonumber(f:read("*l"):match("^(%S+)"))
  if f then f:close() end
  return u or 0
end
local marks = {{"main.lua", uptime()}}
local function mark(name) marks[#marks + 1] = {name, uptime()} end

local function read_file(path)
  local f = io.open(path, "rb")
  if not f then return nil end
  local s = f:read("*a")
  f:close()
  return s
end

-- ------------------------------------------------------------------ the games

-- tint: each classic's own colour (its card's glow and frame), from its logo.
local CLASSICS = {
  {title = "PAC-MAN", year = 1980, tint = 0xffd23f, blurb = "Eat the dots. Mind the ghosts."},
  {title = "PAC & PAL", year = 1983, tint = 0xff9a3c, blurb = "Flip the cards, find the treats."},
  {title = "SUPER PAC-MAN", year = 1982, tint = 0xff8a4c, blurb = "Keys, doors, and a super-size power pellet."},
  {title = "PAC-MAN PLUS", year = 1982, tint = 0xff5aa8, blurb = "Pac-Man, with tricks in the maze."},
  {title = "PAC-LAND", year = 1984, tint = 0x5fd16a, blurb = "Run the whole town back to Fairyland."},
  {title = "PAC-MANIA", year = 1987, tint = 0x6aa8ff, blurb = "Jump the ghosts in rolling 3-D mazes."},
  {title = "GALAGA", year = 1981, tint = 0x3fd6c0, blurb = "Win your captured fighter back. Fly two."},
  {title = "GALAXIAN", year = 1979, tint = 0x4fe0a0, blurb = "The swarm dives. Stay sharp."},
  {title = "MAPPY", year = 1983, tint = 0x5ab8ff, blurb = "A police mouse, a mansion, trampolines."},
  {title = "DIG DUG", year = 1982, tint = 0xff7a4a, blurb = "Dig, pump, and drop the rocks."},
  {title = "DIG DUG II", year = 1985, tint = 0x9ad65a, blurb = "Sink the island under the monsters."},
  {title = "ROMPERS", year = 1989, tint = 0xff6a7a, blurb = "Push the walls down on the monsters."},
}
-- stat: the save key The Yard shows, and how (games/carts/*/info.lua).
local OURS = {
  {id = "keep", title = "KEEP", tint = 0xff7a59, blurb = "Catch the falling fruit.", stat = {"best", "BEST %d"}},
  {id = "lamp", title = "LAMP", tint = 0xffc94a, blurb = "Wake the sleeping stars.", stat = {"best", "%d NIGHTS", "1 NIGHT"}},
  {id = "orb", title = "ORB", tint = 0xa98bff, blurb = "Dive down the glowing well.", native = "orb", stat = {"best", "BEST %d"}},
  {id = "tea", title = "TEA", tint = 0xff9ccf, blurb = "Tea with the cats.", stat = {"visits", "%d VISITS", "1 VISIT"}},
  {id = "chest", title = "CHEST", tint = 0x7fd6a0, blurb = "The key, the chest, Zam.", stat = {"gems", "%d GEMS", "1 GEM"}},
}
local SECTIONS = {
  {name = "FAVORITES", tint = 0xff7ab8},
  {name = "CLASSICS", tint = 0xffd23f},
  {name = "ARCADE", tint = 0xffb43c},
  {name = "GAMES", tint = 0xff4fd8},
  {name = "THE YARD", tint = 0x6ef0c8},
  {name = "TV", tint = 0xff6b6b},
  {name = "SHOWS", tint = 0xff4a5a},
  {name = "EXTRAS", tint = 0x8ab4ff},
}
-- How to come back to Home from each kind of game (said on the info panel and on the "get ready" picture).
local LEAVE = {
  classic = {"HOLD  1-PLAYER  FOR 5 SECONDS", "to come back to Home (your high score is saved)"},
  cart = {"HOLD  1-PLAYER + 2-PLAYER", "to come back to Home"},
  native = {"HOLD  1-PLAYER + 2-PLAYER", "to come back to Home"},
  game = {"HOLD  1-PLAYER + 2-PLAYER", "to come back to Home"},
  arcade = {"HOLD  1-PLAYER + 2-PLAYER", "to come back to Home"},
  yard = {"HOLD  1-PLAYER + 2-PLAYER", "to come back to Home"},
}
-- (FAVORITES is section 1 and CLASSICS 2, written as numbers: main.lua is at Lua's 200-local limit)
local ARCADE_SECTION, GAMES_SECTION, YARD_SECTION, TV_SECTION, SHOWS_SECTION, MORE_SECTION = 3, 4, 5, 6, 7, 8

local PREVIEW = os.getenv("HOME_MODE") == "preview"
local items = {}
for i, c in ipairs(CLASSICS) do
  items[#items + 1] = {kind = "classic", index = i - 1, section = 2, title = c.title,
                       sub = c.year .. "  NAMCO", blurb = c.blurb, tint = c.tint}
end
-- The Shelf (shelf.lua): the games on the microSD card, a card per row (PARTY PICKS, then each system), each
-- opening the browser there. No card in the slot: one card that says so.
shelf.init()
-- The arcade boards on the card (shelf.lua): a card each, like the classics, with the board's own high-score
-- table (its top score and initials on the panel, the top five on the get-ready picture).
-- The Hall of Fame (hall.lua): every board's record and the players ranked across them, first in ARCADE.
if #shelf.arcade_games() > 0 then
  items[#items + 1] = {kind = "hall", section = ARCADE_SECTION, title = "HALL OF FAME", sub = "EVERY RECORD  ·  THE CHAMPIONS",
                       blurb = "The top score on every game, and who holds the most.", tint = 0xffd23f}
end
for _, g in ipairs(shelf.arcade_games()) do
  local meta = {}
  if g.year ~= "" then meta[#meta + 1] = g.year end
  if g.maker ~= "" then meta[#meta + 1] = g.maker:upper() end
  items[#items + 1] = {kind = "arcade", id = g.set, game = g, section = ARCADE_SECTION, title = g.title:upper(),
                       sub = table.concat(meta, "  "), blurb = g.blurb, tint = g.tint or 0xffb43c}
end
do
  local cards = shelf.cards()
  for _, c in ipairs(cards) do
    items[#items + 1] = {kind = "shelf", row = c.key, section = GAMES_SECTION, title = c.title,
                         sub = c.sub:upper(), blurb = shelf.card_blurb(c.key), tint = c.tint}
  end
  if #cards == 0 then
    items[#items + 1] = {kind = "shelf", section = GAMES_SECTION, title = "GAMES", sub = "THE GAMES CARD",
                         blurb = "Put the YARD card in the slot (power off first) for the arcade and console games.",
                         tint = 0xff4fd8}
  end
end
for _, g in ipairs(OURS) do
  items[#items + 1] = {kind = g.native and "native" or "cart", id = g.id, native = g.native, section = YARD_SECTION,
                       title = g.title, sub = "THE YARD", blurb = g.blurb, tint = g.tint, statdef = g.stat}
end
-- Live TV (tv.lua): one card, which opens the guide in Home itself.
items[#items + 1] = {kind = "tv", section = TV_SECTION, title = "LIVE TV", sub = "CHANNEL GUIDE",
                     blurb = "Live sports, news and locals.", tint = 0xff6b6b}
-- The idle shows (shows.lua): a card each (LOWER: its parts, to watch any of them), and the SCHEDULE.
for _, sh in ipairs(shows.LIST) do
  if shows.available(sh.id) then
    items[#items + 1] = {kind = "showcard", show = sh.id, section = SHOWS_SECTION, title = sh.title,
                         sub = "IDLE SHOW  ·  LOWER BUTTON: pick a part to watch", blurb = sh.blurb, tint = sh.tint}
  end
end
items[#items + 1] = {kind = "show", section = SHOWS_SECTION, title = "SCHEDULE", sub = "AUTO", blurb = "", tint = 0xff4a5a}
-- HOME_MODE=preview (opened from a Yard row to try Home): the last card goes back to The Yard.
if PREVIEW then
  items[#items + 1] = {kind = "stock", section = MORE_SECTION, title = "BACK TO THE YARD", sub = "HOME PREVIEW",
                       blurb = "Home is a preview for now: this goes back to The Yard.", tint = 0xff9c5a}
else
  items[#items + 1] = {kind = "yard", section = MORE_SECTION, title = "YARD MENU", sub = "THE WHOLE YARD",
                       blurb = "Every Yard game, in its own menu.", tint = 0x7fe8ff}
  items[#items + 1] = {kind = "stock", section = MORE_SECTION, title = "ORIGINAL MENU", sub = "ARCADE1UP",
                       blurb = "The menu as it came. On it, hold 1-PLAYER + 2-PLAYER to come back.", tint = 0xff9c5a}
end

-- A card's name in the state file (numbers move when cards are added).
local function item_key(it)
  -- (a FAVORITES card has its own name, so coming back from the original card returns to the original)
  return (it.fav and "fav:" or "") .. it.kind .. ":" .. tostring(it.id or it.show or it.index or it.title):gsub("%s", "_")
end
local function item_by_key(k)
  for i, it in ipairs(items) do if item_key(it) == k then return i end end
end

-- The stock menu's settings: one byte per classic.
local function cfg_read(name)
  local s = read_file(GAMES .. "/" .. name)
  local t = {}
  for i = 1, 12 do t[i] = s and s:byte(i) or 0 end
  return t
end
local function cfg_write(name, t)
  local f = io.open(GAMES .. "/" .. name, "wb")
  if not f then return end
  local b = {}
  for i = 1, 12 do b[i] = string.char(t[i] == 1 and 1 or 0) end
  f:write(table.concat(b))
  f:close()
end
local speed, smooth = cfg_read("Speed.cfg"), cfg_read("Smoothing.cfg")

-- The classics' high scores, from the boards' own save memory (each game its own layout). Every decoding was
-- checked against the score the game shows on its attract screen (2026-10-27, tools/cabview screenshots).
local function bcd(b) return math.floor(b / 16) * 10 + b % 16 end
local function bcd_be(s, at, n) local v = 0 for i = 0, n - 1 do v = v * 100 + bcd(s:byte(at + i) or 0) end return v end
local function bcd_le(s, at, n) local v = 0 for i = n - 1, 0, -1 do v = v * 100 + bcd(s:byte(at + i) or 0) end return v end
local function digits(s, at, n, low_first)
  local v = 0
  for i = 0, n - 1 do
    local d = s:byte(low_first and (at + n - 1 - i) or (at + i)) or 0
    if d > 9 then d = 0 end                 -- a blank
    v = v * 10 + d
  end
  return v
end
local function be32(s, at) local a, b, c, d = s:byte(at, at + 3) return ((a * 256 + b) * 256 + c) * 256 + d end
local function best(s, first, stride, count, f)
  local m = 0
  for k = 0, count - 1 do
    local at = first + k * stride
    if at + stride - 1 <= #s then m = math.max(m, f(s, at)) end
  end
  return m
end
-- index -> {save file, decoder}; "fast" games keep a second save (PacManFast.sav).
local SCORES = {
  [0] = {"PacMan", function(s) return bcd_le(s, 1, 3) end, fast = "PacManFast"},
  [1] = {"PacandPal", function(s) return best(s, 1, 8, 5, function(t, a) return bcd_be(t, a, 3) * 10 end) end},
  [2] = {"SuperPacMan", function(s) return best(s, 1, 8, 5, function(t, a) return bcd_be(t, a, 3) * 10 end) end},
  [3] = {"PacManPlus", function(s) return bcd_le(s, 1, 3) end, fast = "PacManPlusFast"},
  [4] = {"PacLand", function(s) return best(s, 1, 16, 5, function(t, a) return digits(t, a, 5) * 10 end) end},
  [5] = {"PacMania", function(s) return best(s, 2049, 8, 10, function(t, a) return bcd_be(t, a, 4) * 10 end) end},
  [6] = {"Galaga", function(s) return best(s, 1, 6, 5, function(t, a) return digits(t, a, 6, true) end) end},
  [7] = {"Galaxian", function(s) return bcd_le(s, 1, 3) end},
  [8] = {"Mappy", function(s) return best(s, 1, 8, 5, function(t, a) return bcd_be(t, a, 3) * 10 end) end},
  [9] = {"DigDug", function(s) return best(s, 1, 3, 5, function(t, a) return bcd_be(t, a, 3) end) end},
  [10] = {"DigDugII", function(s) return best(s, 1, 16, 5, function(t, a) return digits(t, a, 6) * 10 end) end},
  [11] = {"Rompers", function(s) return best(s, 2049, 4, 5, function(t, a) return be32(t, a) * 10 end) end},
}
local function high_score(index)
  local e = SCORES[index]
  if not e then return nil end
  local s = speed[index + 1] == 1 and e.fast and read_file(GAMES .. "/" .. e.fast .. ".sav")
  s = s or read_file(GAMES .. "/" .. e[1] .. ".sav")
  if not s or #s < 3 then return nil end
  local ok, v = pcall(e[2], s)
  return ok and v > 0 and v < 100000000 and v or nil
end

-- ------------------------------------------------------------------ colors and drawing

local function rgb(c, a)
  return math.floor(c / 65536) % 256 / 255, math.floor(c / 256) % 256 / 255, c % 256 / 255, a or 1
end

local fonts = {}
local font_data
-- Starlight's state, in one table (main.lua is at Lua's 200 locals): the script face, the world, the marquee
local ST = {script_fonts = {}, face = "round", world_want = "base", L = require("showlib"), initials = require("initials"),
            hall = require("hall")}
-- An arcade board's best score, and its line on the info panel ("23,310  JRN").
function ST.arcade_best(it)
  local t = shelf.arcade_table(it.id)
  return t and t[1][1] or 0
end
function ST.arcade_score_text(it)
  local t = shelf.arcade_table(it.id)
  if not t or t[1][1] <= 0 then return nil end
  return shelf.commas(t[1][1]) .. (t[1][2] ~= "" and ("  " .. t[1][2]) or "")
end
for _, it in ipairs(items) do
  if it.kind == "arcade" then it.table = shelf.arcade_table(it.id) it.score = ST.arcade_score_text(it) end
end

-- FAVORITES (favs.lua): the game played last, then the most played, as cards that launch straight away.
ST.favs = require("favs")
do
  local stats = ST.favs.credit(STATE)
  local last = ST.favs.last(stats)
  local order, seen = {}, {}
  if last then order[1], seen[last] = last, true end
  for _, k in ipairs(ST.favs.ranked(stats)) do
    if not seen[k] and #order < 8 then order[#order + 1], seen[k] = k, true end
  end
  local favs = {}
  for i, k in ipairs(order) do
    local base
    local sys, file = k:match("^game:([^/]+)/(.+)$")
    if sys then
      local g = shelf.find(sys, file)
      if g then
        base = {kind = "game", game = g, id = sys .. "/" .. file, title = g.title:upper(), blurb = g.blurb,
                tint = g.tint or 0xff4fd8}
      end
    else
      for _, it in ipairs(items) do if item_key(it) == k then base = it break end end
    end
    if base and base.kind ~= "stock" then
      local c = {}
      for kk, vv in pairs(base) do c[kk] = vv end
      c.section, c.fav, c.statkey = 1, true, k
      c.sub = (i == 1 and k == last and "LAST PLAYED  ·  " or "") .. ST.favs.line(stats[k])
      favs[#favs + 1] = c
    end
  end
  if #favs == 0 then
    favs[1] = {kind = "favhint", fav = true, section = 1, title = "FAVORITES", sub = "YOUR MOST-PLAYED GAMES",
               blurb = "Play anything and it lands here: the last game played, then the ones played most.", tint = 0xff7ab8}
  end
  for i = #favs, 1, -1 do table.insert(items, 1, favs[i]) end
end

local trace_font                            -- (HOME_TRACE: a new font made; set once the trace exists)
local function font(px)
  -- (whole pixels only: a size that changes smoothly, 22 + ph * 10, made a new font every frame, each with its
  -- glyph texture, until the cabinet ran out of memory 14 minutes into Texas, 2026-11-06)
  px = math.floor(px + 0.5)
  if not fonts[px] then
    if trace_font then trace_font(px) end
    fonts[px] = font_data and lg.newFont(font_data, px) or lg.newFont(px)
  end
  return fonts[px]
end
-- Starlight's wordmark face (Pacifico, OFL; a subset): the marquee and the brand's titles
function ST.script_font(px)
  px = math.floor(px + 0.5)
  if not ST.script_fonts[px] then
    ST.script_fonts[px] = ST.script_data and lg.newFont(ST.script_data, px) or font(px)
  end
  return ST.script_fonts[px]
end

-- Text with a neon glow: soft additive copies around it, then the text.
local function neon(s, x, y, px, c, glow, align, width)
  local f = ST.face == "script" and ST.script_font(px) or font(px)
  lg.setFont(f)
  local r, g, b = rgb(c)
  glow = glow or 1
  -- (white on white glow read as blur on the cabinet: pale labels get a crisp dark edge and only a faint glow;
  -- coloured ones keep their neon, tighter)
  local pale = math.min(r, g, b) > 0.75
  if pale then
    lg.setColor(0, 0, 0, 0.55)
    for k = 0, 7 do
      local ang = k * math.pi / 4
      lg.printf(s, x + math.floor(math.cos(ang) * 2 + 0.5), y + math.floor(math.sin(ang) * 2 + 0.5), width or W, align or "center")
    end
  end
  if glow > 0 then
    lg.setBlendMode("add")
    for _, o in ipairs(pale and {{3, 0.04}} or {{2, 0.12}, {4, 0.06}}) do
      local d, a = o[1], o[2] * glow
      lg.setColor(r, g, b, a)
      for k = 0, 7 do
        local ang = k * math.pi / 4
        lg.printf(s, x + math.floor(math.cos(ang) * d + 0.5), y + math.floor(math.sin(ang) * d + 0.5), width or W, align or "center")
      end
    end
    lg.setBlendMode("alpha")
  end
  lg.setColor(r * 0.35 + 0.65, g * 0.35 + 0.65, b * 0.35 + 0.65, 1)   -- the hot white core of a neon tube
  lg.printf(s, x, y, width or W, align or "center")
end

local function rrect(mode, x, y, w, h, r) lg.rectangle(mode, x, y, w, h, r, r, 16) end

-- Neon labels painted once into a picture (glow included): drawing one is a single quad. Live neon() was 17
-- prints a label, and Home ran at 48-55 fps on the cabinet (2026-10-27). All are painted in love.load, before
-- the first frame (a canvas switch mid-frame is costly on the Mali). Made with no scissor (see gfx.lua's
-- new_canvas: a clip carried onto a canvas left it unpainted).
local neon_cache = {}
local label_jobs = {}
local function neon_img(s, px, c, glow)
  px = math.floor(px + 0.5)                -- (whole pixels: one picture per text and size, not one a frame)
  local key = s .. "|" .. px .. "|" .. c .. "|" .. (glow or 1) .. (ST.face == "script" and "|s" or "")
  local e = neon_cache[key]
  if e then return e end
  local f = ST.face == "script" and ST.script_font(px) or font(px)
  local pad = 10
  local cw, ch = f:getWidth(s) + pad * 2, f:getHeight() + pad * 2
  lg.push("all")
  lg.setScissor()
  local cv = lg.newCanvas(math.max(1, cw), math.max(1, ch))
  lg.origin()
  lg.setCanvas(cv)
  lg.clear(0, 0, 0, 0)
  neon(s, pad, pad, px, c, glow, "left", cw)
  lg.pop()
  cv:setFilter("linear", "linear")
  e = {img = cv, w = cw, h = ch, pad = pad}
  neon_cache[key] = e
  return e
end
-- Draw a painted label: like neon(s, x, y, ...) with align over width; sc scales it about its top left.
local function neon_draw(s, x, y, px, c, glow, align, width, alpha, sc)
  local e = neon_img(s, px, c, glow)
  sc = sc or 1
  local w = e.w * sc
  local dx = align == "left" and 0 or align == "right" and (width - w + e.pad * sc * 2) or ((width or W) - w) / 2 + e.pad * sc
  local a = alpha or 1
  lg.setBlendMode("alpha", "premultiplied")
  lg.setColor(a, a, a, a)
  -- (on whole pixels: a label drawn at a half pixel is resampled, and soft)
  lg.draw(e.img, math.floor(x + dx - e.pad * sc + 0.5), math.floor(y - e.pad * sc + 0.5), 0, sc, sc)
  lg.setBlendMode("alpha")
end

-- The brand: STARLIGHT in its script neon (a painted label, like any other).
ST.BRAND, ST.C, ST.ACCENT = "Starlight", 0xffd36b, 0x6ef0c8
function ST.draw(x, y, px, alpha, sc, align, width)
  ST.face = "script"
  neon_draw(ST.BRAND, x or 0, y, px, ST.C, 1.5, align or "center", width or W, alpha, sc)
  ST.face = "round"
end
function ST.img(px)
  ST.face = "script"
  local e = neon_img(ST.BRAND, px, ST.C, 1.5)
  ST.face = "round"
  return e
end

local play = sound.play

-- ------------------------------------------------------------------ input

-- The cabinet's deck through SDL (games/love/yard/input.lua has the same map), and keys on a PC. Buttons 20
-- and 21 are volume down and up: the kernel changes the volume itself (volctrl.sh); Home only shows it.
local JOY = {[1] = "low", [2] = "tl", [4] = "tr", [7] = "1p", [8] = "2p", [16] = "up", [17] = "left", [18] = "right",
             [19] = "down", [20] = "voldown", [21] = "volup"}
local KEYS = {up = "up", down = "down", left = "left", right = "right", z = "low", x = "tl", c = "tr",
              ["1"] = "1p", ["2"] = "2p", ["return"] = "low", space = "low", ["-"] = "voldown", ["="] = "volup"}
-- Holding 1-player + 2-player for a second leaves the preview (The Yard's convention, with its meter), so 1P
-- launches on release, and only when 2P was not pressed with it.
local HOLD_SECS = 1
local pressed_q, down, both_seen, hold_t = {}, {}, false, 0
local function press(name) pressed_q[#pressed_q + 1] = name end
local down_at = {}
local function control_down(name)
  down[name] = true
  down_at[name] = love.timer.getTime()
  if (name == "1p" and down["2p"]) or (name == "2p" and down["1p"]) then both_seen = true end
  if name ~= "1p" and name ~= "2p" then press(name) end
end
local function control_up(name)
  -- A 1-player tap starts the game: only a press Home saw begin, and short. (Leaving a classic is a 5 s
  -- 1-player hold; let go after Home is back, and Home saw only the release: it started the game again,
  -- filmed 2026-10-27.)
  local seen = down[name] and down_at[name] and love.timer.getTime() - down_at[name] < 0.8
  down[name] = nil
  if name == "1p" and seen and not both_seen then press("1p") end
  if name == "2p" and seen and not both_seen and not down["1p"] then press("2p") end
  if not down["1p"] and not down["2p"] then both_seen = false end
end
function love.joystickpressed(_, b) if JOY[b] then control_down(JOY[b]) end end
function love.joystickreleased(_, b) if JOY[b] then control_up(JOY[b]) end end
function love.keypressed(k)
  if k == "escape" then love.event.quit(0) end
  if KEYS[k] then control_down(KEYS[k]) end
end
function love.keyreleased(k) if KEYS[k] then control_up(KEYS[k]) end end

-- HOME_SCRIPT (tests): lines "<frame> press NAME", "<frame> down NAME", "<frame> up NAME", "<frame> shot PATH",
-- "<frame> quit".
local script = {}
do
  local s = os.getenv("HOME_SCRIPT") and read_file(os.getenv("HOME_SCRIPT"))
  if s then
    for line in s:gmatch("[^\n]+") do
      local f, op, arg = line:match("^(%d+)%s+(%a+)%s*(.*)$")
      if f then script[#script + 1] = {tonumber(f), op, arg} end
    end
  end
end

-- ------------------------------------------------------------------ state

local sel, pos = 1, 1
local t, frame = 0, 0
-- HOME_TRACE=PATH (tools/show_review.py): what a show does, as it plays, one line an event: "<show secs> <kind> ..."
-- (act: the scene; music: the song; sfx: a sound; cam x y zoom, 10 a second; say/caption/plate: words shown).
local TRACE = os.getenv("HOME_TRACE") and io.open(os.getenv("HOME_TRACE"), "w")
local trace_t, trace_seen = nil, {}
local function trace(kind, a, b, c)
  if kind == "t" then trace_t = a return end
  local when = trace_t or frame / 60
  if kind == "parts" then
    if frame % 30 ~= 0 then return end
    TRACE:write(string.format("%.2f parts %d %d\n", when, a, b))
    return
  end
  if kind == "crowd" then
    if frame % 6 ~= 0 then return end
    TRACE:write(string.format("%.2f crowd %s\n", when, a))
    return
  end
  if kind == "cast" then
    if frame % 6 ~= 0 then return end
    TRACE:write(string.format("%.2f cast %.0f %.0f %.0f\n", when, a, b or 0, c or 0))
    return
  end
  if kind == "cam" then
    if frame % 6 ~= 0 then return end
    TRACE:write(string.format("%.2f cam %.0f %.0f %.3f\n", when, a, b, c))
    return
  end
  if kind == "say" or kind == "caption" or kind == "plate" then
    -- (words are drawn every frame: once, then again only after a second away)
    local k = kind .. a
    local last = trace_seen[k]
    trace_seen[k] = frame
    if last and frame - last < 60 then return end
  end
  TRACE:write(string.format("%.2f %s %s\n", when, kind, tostring(a)))
  if kind == "act" or kind == "music" then TRACE:flush() end
end
local scene = "intro"           -- intro, menu, attract, night, show (an idle show), shows (a show's tiles), tv
local intro_t = 0
local idle = 0
local attract_t = 0
local launch_t, launch_item = 0, nil
local note, note_t = nil, 0
local stars = {}
-- The living menu's world (tools/art/home.py): a painting a season, on the SD card; nil: the synthwave grid.
ST.WORLD_ART = (os.getenv("HOME_SHOW_ART") or "/mnt/sdcard/partycade/art") .. "/home"
function ST.world_load(name)
  if ST.world and ST.world_name == name then return end
  if ST.world then ST.world:release() ST.world = nil end
  ST.world_name = name
  local f = io.open(ST.WORLD_ART .. "/world_" .. name .. ".pkm", "rb")
  if not f then f = io.open(ST.WORLD_ART .. "/world_base.pkm", "rb") end
  if not f then return end
  local bytes = f:read("*a")
  f:close()
  local ok, img = pcall(function()
    local fd = love.filesystem.newFileData(bytes, "w.pkm")
    local cd = love.image.newCompressedData(fd)
    fd:release()
    local im = lg.newImage(cd)
    cd:release()
    return im
  end)
  if ok then img:setFilter("linear", "linear") ST.world = img end
end
local direct = not headless and os.getenv("HOME_CANVAS") ~= "1"
local canvas
local shot_req
local vol_level, vol_t, vol_read = nil, 0, nil
local night_t = 0
local cur_show, cur_show_id             -- the idle show playing (its module; nil for the night sky), and its id
-- A show's start behind a curtain: the screen black while it sets up (its pictures, its labels: 300 ms and more
-- on the cabinet, which froze whatever was moving), its clock still until frames come smoothly, then a fade in.
local curtain
-- The curtain's step: true when the show may run as usual this frame.
local function curtain_step(dt)
  local cu = curtain
  if not cu then return true end
  cu.n = cu.n + 1
  if cu.phase == "cover" then
    if cu.n >= 2 then cur_show.start(cu.seed, cu.at) cu.phase, cu.n = "settle", 0 end
    return false
  elseif cu.phase == "settle" then
    cur_show.update(0)                                      -- (its labels paint; its clock stays)
    cu.good = dt < 0.025 and cu.good + 1 or 0
    cu.held = (cu.held or 0) + dt
    -- (from idle: the NOW SHOWING card holds a moment, to be read)
    if (cu.good >= 8 or cu.n > 240) and (not cu.card or cu.held > 3.2) then cu.phase = "fade" end
    return false
  end
  cu.f = cu.f + dt
  if cu.f >= 0.4 then curtain = nil end
  return true
end

local function curtain_draw()
  local cu = curtain
  if not cu then return end
  local a = cu.phase == "fade" and math.max(0, 1 - cu.f / 0.6) or 1
  lg.setColor(0.02, 0.01, 0.05, a)
  lg.rectangle("fill", 0, 0, W, H)
  if cu.card then
    -- NOW SHOWING: the brand, the show's name in its own colour, what it is
    local sh = shows.BY_ID[cu.card]
    if sh then
      local k = math.min(1, (cu.held or 0) / 0.5) * a
      fx.glow(W / 2, 470, 360, 220, rgb(sh.tint, 0.18 * k))
      ST.draw(0, 250, 72, k)
      neon_draw("NOW SHOWING", 0, 380, 30, ST.ACCENT, 0.8, "center", W, k)
      local px = math.min(72, 64 * 620 / (font(64):getWidth(sh.title) + 20))
      neon_draw(sh.title, 0, 440, 64, sh.tint, 1.2, "center", W, k, px / 64)
      lg.setFont(font(26))
      lg.setColor(0.93, 0.9, 1, 0.9 * k)
      lg.printf(sh.blurb, 80, 560, W - 160, "center")
    end
  end
end
local auto_night_t = 0            -- AUTO: how long the night sky has had its turn
local menu_in = 0                 -- the menu fading in after the intro (seconds left)
local attract_sel                 -- the card before the attract tour: given back on waking
local returning = false           -- Home started again after a game (not at power-on)
local celebrate                   -- {score, title, tint, t}: back from a classic with a new high score
local party = 0                   -- party mode (the secret code): seconds left
local code_buf = {}
local CODE = {"up", "up", "down", "down", "left", "right", "left", "right", "tl", "low"}
local last_played                 -- the card of the last game played (state file)

-- The cards' neon titles (two pictures each, ~0.2 MB of GPU memory per card): painted for the cards near the
-- chosen one, given back for the far ones (all of them painted, Home's labels alone were most of its 12 MB of
-- pictures, and GPU memory is what this cabinet runs out of).
local labels_for, labels_sel = {}, nil
local function title_labels(it)
  neon_img(it.title, 64, it.tint, 1.2)
  neon_img(it.title, 44, it.tint, 0.9)
end
local function neon_release(s, px, c, glow)
  local key = s .. "|" .. px .. "|" .. c .. "|" .. (glow or 1) .. (ST.face == "script" and "|s" or "")
  local e = neon_cache[key]
  if e then e.img:release() neon_cache[key] = nil end
end
local function manage_labels(all_now)
  if labels_sel == sel then return end
  labels_sel = sel
  for k, it in ipairs(items) do
    local d = math.abs(k - sel)
    if d <= 3 and not labels_for[k] then
      labels_for[k] = true
      if all_now or d <= 1 then title_labels(it)
      else label_jobs[#label_jobs + 1] = function() if labels_for[k] then title_labels(it) end end end
    elseif d > 5 and labels_for[k] then
      labels_for[k] = nil
      neon_release(it.title, 64, it.tint, 1.2)
      neon_release(it.title, 44, it.tint, 0.9)
    end
  end
end

local function load_state()
  local s = STATE and read_file(STATE)
  local n = s and (item_by_key(s:match("selkey (%S+)") or "") or tonumber(s:match("sel (%d+)")))
  if n and items[n] then sel, pos = n, n end
  local sm = s and s:match("show (%a+)")
  if sm and SHOW_NAMES[sm] then show_mode = sm end
  local lp = s and (item_by_key(s:match("playedkey (%S+)") or "") or tonumber(s:match("played (%d+)")))
  if lp and items[lp] then last_played = items[lp] end
  -- At power-on, never on the original menu's card (the last choice made before the power went off).
  if os.getenv("HOME_INTRO") == "1" and items[sel].kind == "stock" then sel, pos = 1, 1 end
  -- Nothing played yet: start on the first real card (Pac-Man), not on the empty FAVORITES card.
  if items[sel].kind == "favhint" then sel, pos = 2, 2 end
  return s and s:match("returned (.+)")
end
local function save_state(extra, played)
  if not STATE then return end
  local lp = played
  if not lp and last_played then
    for k, it in ipairs(items) do if it == last_played then lp = k end end
  end
  local f = io.open(STATE, "w")
  if f then
    f:write("sel " .. sel .. "\nselkey " .. item_key(items[sel]) .. "\n" ..
            (lp and ("played " .. lp .. "\nplayedkey " .. item_key(items[lp]) .. "\n") or "") ..
            "show " .. show_mode .. "\n" .. (extra or ""))
    f:close()
  end
end

-- The classics' logos (cut from the stock menu by tools/home_art.py, on the cabinet only). The cards in view
-- are loaded at once; the rest are decoded by the worker and arrive over the first frames.
local worker
local function art_image(data)
  local ok, img = pcall(lg.newImage, data, {mipmaps = true})
  if not ok then return nil end
  img:setFilter("linear", "linear")
  img:setMipmapFilter("linear")
  return img
end
local function art_path(it) return ART .. "/classic_" .. it.index .. ".png" end
local function load_art()
  for k, it in ipairs(items) do
    if it.kind == "classic" then
      if math.abs(k - sel) <= 2 or not worker then
        local b = read_file(art_path(it))
        if b then
          local ok, data = pcall(love.image.newImageData, love.filesystem.newFileData(b, "c.png"))
          if ok then it.art = art_image(data) end
        end
      else
        love.thread.getChannel("home_work"):push({"art", k, art_path(it)})
      end
    elseif it.kind == "arcade" or it.kind == "game" then
      -- The board's title screen, from the card (decoded on the worker; the reply sets it.shot). Only the cards
      -- near the chosen one: all of them at once, with the browser's box art, ran Home out of memory.
      if it.game.art and not it.shot and not it.asked and math.abs(k - sel) <= 3 then
        it.asked = true
        if worker then love.thread.getChannel("home_work"):push({"art", k, it.game.art})
        else
          local b = read_file(it.game.art)
          local ok, data = pcall(function() return love.image.newImageData(love.filesystem.newFileData(b, "a.png")) end)
          if ok then it.shot = art_image(data) end
        end
      end
    elseif it.id and love.filesystem.getInfo("art/" .. it.id .. ".png") then
      -- Our games: a frame of the game itself (cart shots), packed into home.love.
      it.shot = lg.newImage("art/" .. it.id .. ".png")
      it.shot:setFilter("linear", "linear")
    end
  end
end

-- ------------------------------------------------------------------ drawing

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
  for _, st in ipairs(stars) do
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
                   {W, HORIZON, 0, 0, mr, mg, mb, 1}, {0, HORIZON, 0, 0, mr, mg, mb, 1}})
  lg.setColor(1, 1, 1, 1)
  lg.draw(sky)
  lg.setColor(0.02, 0.0, 0.05, 1)
  lg.rectangle("fill", 0, HORIZON, W, H - HORIZON)
  -- Stars.
  for _, s in ipairs(stars) do
    local tw = 0.45 + 0.55 * math.abs(math.sin(t * s[4] + s[3]))
    lg.setColor(1, 0.9, 1, tw * s[5])
    lg.rectangle("fill", s[1], s[2], s[6], s[6])
  end
  fx.draw_shooting()
  -- The sun on the horizon, striped, with a warm haze.
  local cx, cy, r = W / 2, HORIZON, 150
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
    if party > 0 then lg.setColor(hue(i / 25 + t * 0.4, 0.7 * ga)) else lg.setColor(1, 0.2, 0.75, 0.55 * ga) end
    lg.line(W / 2 + i * 22, HORIZON, W / 2 + i * 150, H)
  end
  local scroll = (t * 0.8) % 1
  for i = 0, 9 do
    local k = (i + scroll) / 10
    local y = HORIZON + (H - HORIZON) * k * k
    if party > 0 then lg.setColor(hue(k + t * 0.6, (0.2 + 0.7 * k) * ga)) else lg.setColor(1, 0.25, 0.8, (0.15 + 0.6 * k) * ga) end
    lg.line(0, y, W, y)
  end
  lg.setColor(1, 0.4, 0.9, 0.8 * ga)
  lg.line(0, HORIZON, W, HORIZON)
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
    rrect("fill", 64, 14, 640, 152, 14)
  end
  ST.draw_bulbs(a)
  fx.glow(W / 2, 92, 300, 70, 1, 0.75, 0.35, 0.16 * a)
  ST.draw(0, 24, 96, flick * a)
end

local function draw_tabs(cur)
  -- (26 px: readable from the couch; on a dark pill so the sky's stars don't fight them)
  local px, gap = 26, 10
  local total = 0
  for _, s in ipairs(SECTIONS) do total = total + font(px):getWidth(s.name) + 28 + gap end
  local x = math.floor((W - total + gap) / 2)
  if total - gap > W - 20 then
    -- Wider than the glass (eight sections since FAVORITES): slide so the chosen tab is in the middle.
    local cx = 0
    for i, s in ipairs(SECTIONS) do
      local w = font(px):getWidth(s.name) + 28
      if i == cur then cx = cx + w / 2 break end
      cx = cx + w + gap
    end
    local want = math.max(W - 10 - (total - gap), math.min(10, W / 2 - cx))
    ST.tab_x = ST.tab_x and (ST.tab_x + (want - ST.tab_x) * 0.2) or want
    x = math.floor(ST.tab_x)
  end
  lg.setColor(0.03, 0.02, 0.08, 0.6)
  rrect("fill", x - 10, 182, total - gap + 20, 46, 23)
  for i, s in ipairs(SECTIONS) do
    local on = i == cur
    lg.setFont(font(px))
    local w = font(px):getWidth(s.name) + 28
    local r, g, b = rgb(s.tint)
    if on then
      lg.setColor(r, g, b, 0.28)
      rrect("fill", x, 186, w, 38, 19)
      lg.setColor(r, g, b, 1)
      lg.setLineWidth(2)
      rrect("line", x, 186, w, 38, 19)
    end
    lg.setColor(r, g, b, on and 1 or 0.6)
    lg.print(s.name, x + 14, 190)
    x = x + w + gap
  end
  -- Now and next: tonight's show, the Longhorns' next game (set by update_cards)
  if ST.now_line then
    lg.setFont(font(20))
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
  local r, g, b = rgb(it.tint)
  if focus > 0 then
    -- The glow and the pulsing frame of the chosen card.
    local p = 0.75 + 0.25 * math.sin(t * 4)
    lg.setBlendMode("add")
    for k = 1, 4 do
      lg.setColor(r, g, b, 0.07 * focus * p)
      lg.setLineWidth(6 + k * 7)
      rrect("line", x - 6, y - 6, cw + 12, ch + 12, 26)
    end
    lg.setBlendMode("alpha")
  end
  lg.setColor(0.07, 0.03, 0.14, 0.9 * alpha)
  rrect("fill", x, y, cw, ch, 22)
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
    neon_draw(it.title, x, cy - px * 0.62, 64, it.tint, 1.2, "center", cw, alpha, px / 64)
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
      lg.setFont(font(math.floor(18 * sc)))
      lg.setColor(1, 0.85, 0.3, alpha)
      lg.printf("HIGH SCORE", tx, y + 22 * sc, tw, "center")
      lg.setFont(font(math.floor(46 * sc)))
      lg.setColor(1, 1, 1, alpha)
      lg.printf(shelf.commas(tbl[1][1]), tx, y + 46 * sc, tw, "center")
      if not tbl.nameless then
        neon_draw(tbl[1][2] ~= "" and tbl[1][2] or "---", tx, y + 100 * sc, 64, it.tint, 1.1, "center", tw, alpha, 0.62 * sc)
      end
      lg.setFont(font(math.floor(17 * sc)))
      for i = 2, math.min(3, #tbl) do
        lg.setColor(0.86, 0.84, 0.98, 0.85 * alpha)
        lg.printf(i .. ".  " .. (tbl.nameless and "" or ((tbl[i][2] ~= "" and tbl[i][2] or "---") .. "   ")) .. shelf.commas(tbl[i][1]), tx,
                  y + (170 + (i - 2) * 24) * sc, tw, "center")
      end
    else
      local px = math.min(cw * 0.09, 64 * tw / (font(64):getWidth(it.title) + 20))
      neon_draw(it.title, tx, cy - px * 0.75, 64, it.tint, 1.2, "center", tw, alpha, px / 64)
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
    neon_draw(it.title, tx, cy - px * 0.75, 64, it.tint, 1.2, "center", x + cw - tx, alpha, px / 64)
    lg.setFont(font(math.max(12, math.floor(cw * 0.034))))
    lg.setColor(0.9, 0.88, 1, 0.85 * alpha * focus)   -- the chosen card only: the panel below repeats it
    lg.printf(it.blurb, tx + 8, cy + px * 0.55, x + cw - tx - 16, "center")
  elseif it.kind == "show" or it.kind == "showcard" then
    -- An idle show (its picture), or the SCHEDULE (the show it is set to; a calendar for AUTO).
    local sc = ch / 260
    shows.icon(it.kind == "showcard" and it.show or show_mode, x + 40 * sc, cy, sc, alpha, t)
    local tx = x + 230 * sc
    local px = math.min(cw * 0.1, 64 * (x + cw - tx - 24) / (font(64):getWidth(it.title) + 20))
    neon_draw(it.title, tx, cy - px * 0.75, 64, it.tint, 1.2, "center", x + cw - tx, alpha, px / 64)
    if it.kind == "show" then
      lg.setFont(font(math.max(12, math.floor(cw * 0.036))))
      lg.setColor(1, 0.85, 0.3, alpha)
      lg.printf(SHOW_NAMES[show_mode], tx, cy + px * 0.5, x + cw - tx, "center")
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
    neon_draw(it.title, tx, cy - px * 0.75, 64, it.tint, 1.2, "center", x + cw - tx, alpha, px / 64)
    lg.setFont(font(math.max(12, math.floor(cw * 0.034))))
    lg.setColor(0.9, 0.88, 1, 0.85 * alpha * focus)
    lg.printf(it.blurb, tx + 8, cy + px * 0.55, x + cw - tx - 16, "center")
  else
    lg.setColor(1, 1, 1, alpha)
    local px = math.floor(cw * (#it.title > 9 and 0.11 or 0.15))
    if focus > 0.05 then fx.glow(cx, cy, cw * 0.42, ch * 0.3, r, g, b, 0.12 * focus * alpha) end
    neon_draw(it.title, x, cy - px * 0.62, 64, it.tint, 1.2, "center", cw, alpha, px / 64)
  end
  lg.setColor(r, g, b, (0.35 + 0.65 * focus) * alpha)
  lg.setLineWidth(focus > 0 and 3 or 2)
  rrect("line", x, y, cw, ch, 22)
  if it == last_played and focus > 0.3 then
    -- The game played last: a little tab on the card's top edge.
    lg.setFont(font(16))
    local tw = font(16):getWidth("LAST PLAYED") + 22
    lg.setColor(r, g, b, alpha)
    rrect("fill", cx - tw / 2, y - 13, tw, 26, 13)
    lg.setColor(0.06, 0.02, 0.12, alpha)
    lg.printf("LAST PLAYED", cx - tw / 2, y - 9, tw, "center")
  end
end

local function draw_carousel()
  -- The chosen card in the middle; its neighbours smaller and dimmer above and below, peeking out from behind.
  -- Drawn farthest first, so the chosen card is on top.
  local list = {}
  for k = math.floor(pos) - 2, math.floor(pos) + 2 do
    if items[k] then list[#list + 1] = k end
  end
  table.sort(list, function(p, q) return math.abs(p - pos) > math.abs(q - pos) end)
  for _, k in ipairs(list) do
    local it = items[k]
    local off = k - pos
    local a = math.abs(off)
    if a < 1.9 then
      local cw = 540 * (1 - math.min(a, 1.6) * 0.30)
      local cy = 505 + off * 225 * (1 - 0.18 * math.min(a, 1))
      local alpha = math.max(0, 1 - a * 0.5) * math.min(1, (1.9 - a) * 2)
      -- Fade out before reaching the marquee and the tabs (a card scrolling up slid under them).
      alpha = alpha * math.max(0, math.min(1, (cy - cw * 0.29 - 262) / 60))
      local focus = math.max(0, 1 - a * 2)
      if launch_item == it then cw = cw * (1 + 0.25 * math.min(1, launch_t / 0.5)) end
      draw_card(it, W / 2, cy, cw, focus, alpha)
    end
  end
end

local function draw_info()
  local it = items[sel]
  local y = 800
  lg.setColor(0.04, 0.0, 0.10, 0.84)
  rrect("fill", 40, y, W - 80, 196, 24)
  lg.setColor(rgb(it.tint, 0.8))
  lg.setLineWidth(2)
  rrect("line", 40, y, W - 80, 196, 24)
  neon_draw(it.title, 60, y + 14, 44, it.tint, 0.9, "left", W - 120)
  lg.setFont(font(22))
  lg.setColor(0.8, 0.76, 0.98, 1)
  lg.printf(it.sub, 60, y + 70, W - 120, "left")
  if it.score or it.stat then
    lg.setFont(font(22))
    lg.setColor(1, 0.85, 0.3, 1)
    lg.printf(it.score and ("HIGH SCORE  " .. it.score) or it.stat, 60, y + 22, W - 120, "right")
  end
  lg.setFont(font(26))
  lg.setColor(0.97, 0.95, 1, 1)
  lg.printf(it.blurb, 60, y + 100, W - 120, "left")
  if it.kind == "classic" then
    local i = it.index + 1
    local chips = {{"SPEED", speed[i] == 1 and "FAST" or "NORMAL"}, {"SMOOTH", smooth[i] == 1 and "ON" or "OFF"}}
    local x = 60
    for _, c in ipairs(chips) do
      lg.setFont(font(21))
      local s = c[1] .. "  " .. c[2]
      local w = font(21):getWidth(s) + 26
      lg.setColor(1, 0.85, 0.3, 0.18)
      rrect("fill", x, y + 146, w, 32, 16)
      lg.setColor(1, 0.85, 0.3, 1)
      rrect("line", x, y + 146, w, 32, 16)
      lg.print(s, x + 13, y + 151)
      x = x + w + 14
    end
    lg.setColor(0.78, 0.74, 0.95, 0.95)
    lg.setFont(font(19))
    lg.print("top buttons change", x + 4, y + 153)
  end
end

local function draw_hint(s, y, alpha)
  lg.setFont(font(21))
  lg.setColor(0.85, 0.8, 1, alpha or 0.9)
  lg.printf(s, 0, y, W, "center")
end

-- The bottom line: how to play, and, for the chosen game, how to come back from it.
local function draw_footer()
  local it = items[sel]
  local leave = LEAVE[it.kind]
  if leave and math.floor(t / 4) % 2 == 1 then
    draw_hint(it.kind == "classic" and "in the game:  hold 1-PLAYER for 5 seconds to come back"
              or "in the game:  hold 1-PLAYER + 2-PLAYER to come back", 999, 0.9)
  else
    draw_hint("STICK  choose  ·  LEFT/RIGHT  section  ·  LOWER BUTTON  play", 999, 0.9)
  end
end

-- NEW HIGH SCORE: a banner and confetti in the game's colour and its friends, for 5 s (any press keeps going).
local confetti
local function draw_celebration()
  if not celebrate then return end
  local c = celebrate
  if not confetti then
    confetti = {}
    local cols = {{rgb(c.tint)}, {1, 0.31, 0.85}, {0.43, 0.94, 0.78}, {1, 0.82, 0.25}, {0.55, 0.7, 1}}
    for i = 1, 140 do
      confetti[i] = {x = math.random() * W, y = -40 - math.random() * 900, vy = 260 + math.random() * 260,
                     sway = math.random() * 6, ph = math.random() * 6, w = 6 + math.random() * 8,
                     col = cols[math.random(#cols)]}
    end
  end
  local fade = math.min(1, c.t * 4, (5 - c.t) * 2)
  local pop = 1 + 0.15 * math.max(0, 1 - c.t * 3)
  local r, g, b = rgb(c.tint)
  -- The banner, over the chosen card.
  local by, bh = 395, 220
  fx.glow(W / 2, by + bh / 2, 380, 170, r, g, b, 0.35 * fade)
  lg.setColor(0.04, 0.0, 0.10, fade)
  rrect("fill", 44, by, W - 88, bh, 28)
  lg.setColor(r, g, b, fade)
  lg.setLineWidth(4)
  rrect("line", 44, by, W - 88, bh, 28)
  if not c.big then
    neon_draw("NEW HIGH SCORE!", 0, by + 22, 44, 0xffd23f, 1, "center", W, fade * (0.9 + 0.1 * math.sin(c.t * 2.5)), 1)
  end
  lg.setFont(font(math.floor((c.big and 64 or 72) * pop)))
  if c.big then lg.setColor(hue(c.t * 0.8, fade)) else lg.setColor(1, 1, 1, fade) end
  lg.printf(tostring(c.score), 0, by + (c.big and 50 or 80) - 36 * (pop - 1), W, "center")
  lg.setFont(font(24))
  lg.setColor(0.85, 0.8, 1, fade)
  lg.printf(c.title, 0, by + 172, W, "center")
  -- Confetti, over everything.
  for _, p in ipairs(confetti) do
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
  if not note then return end
  local a = math.min(1, note_t)
  lg.setColor(0.25, 0.02, 0.12, 0.92 * a)
  rrect("fill", 70, 240, W - 140, 60, 20)
  lg.setColor(1, 0.5, 0.6, a)
  rrect("line", 70, 240, W - 140, 60, 20)
  lg.setFont(font(22))
  lg.printf(note, 70, 256, W - 140, "center")
end

-- The hold meter, as The Yard draws it: a panel in the middle, a bar filling over the hold.
local function draw_hold()
  if hold_t <= 0 then return end
  local k = math.min(1, hold_t / HOLD_SECS)
  local bw, bh = W * 3 / 4, 110
  local bx, by = (W - bw) / 2, H / 2 - bh / 2
  lg.setColor(8 / 255, 6 / 255, 16 / 255, 0.9)
  rrect("fill", bx - 6, by - 6, bw + 12, bh + 12, 24)
  lg.setColor(40 / 255, 34 / 255, 64 / 255, 0.95)
  rrect("fill", bx, by, bw, bh, 20)
  lg.setColor(1, 200 / 255, 90 / 255)
  rrect("fill", bx + 10, by + bh - 34, (bw - 20) * k, 24, 10)
  lg.setColor(1, 246 / 255, 234 / 255)
  lg.setFont(font(40))
  lg.printf("back to The Yard...", bx, by + 12, bw, "center")
end

-- The volume meter: fifteen neon bars under the tabs, for a moment after a volume button.
local function draw_volume()
  if vol_t <= 0 or not vol_level then return end
  local a = math.min(1, vol_t * 3)
  local bw, bh = 520, 70
  local bx, by = (W - bw) / 2, 226
  lg.setColor(0.04, 0.0, 0.1, 0.9 * a)
  rrect("fill", bx, by, bw, bh, 20)
  lg.setColor(0.43, 0.94, 0.78, a)
  lg.setLineWidth(2)
  rrect("line", bx, by, bw, bh, 20)
  lg.setFont(font(22))
  lg.print(vol_level == 0 and "MUTED" or "VOLUME", bx + 20, by + 22)
  for i = 1, 15 do
    local on = i <= vol_level
    local h = 14 + i * 2
    local x = bx + 150 + (i - 1) * 23
    lg.setColor(0.43, 0.94, 0.78, (on and 1 or 0.18) * a)
    rrect("fill", x, by + bh / 2 + 22 - h, 14, h, 4)
  end
end

-- The night scene (idle a few minutes): the sky dims, the sign sleeps, a chase runs along the horizon.
local function draw_night()
  -- The show (night.lua): the sky through a whole night, the moon, and the scenes.
  local nt = night_t * NIGHT_SPEED
  night.draw(nt)
  -- The sign asleep: it breathes, slowly (dimmer in the rest stretch before dawn).
  local rest = night.scene_at(nt) == "rest" and 0.35 or 1
  local breath = (0.3 + 0.12 * math.sin(night_t * 1.1)) * rest
  fx.glow(W / 2, 80, 330, 60, 1, 0.75, 0.35, breath * 0.25)
  ST.draw(0, 24, 96, breath)
  for i = 0, 2 do
    local k = ((night_t * 0.3) + i / 3) % 1
    local zx, zy = W / 2 + 260 + k * 60 + math.sin(k * 6) * 10, 120 - k * 110
    lg.setFont(font(math.floor(30 + k * 26)))
    lg.setColor(0.43, 0.94, 0.78, math.sin(k * math.pi) * 0.85 * rest)
    lg.print("z", zx, zy)
  end
  draw_hint("press any button", 930, (0.35 + 0.25 * math.sin(t * 2)) * rest)
end

-- The sign, unlit: the board dark, its bulbs out, the tubes faintly there (the power-on picture).
local function draw_unlit_sign(a)
  ST.draw_bulbs(a or 1, 0)
  ST.face = "script"
  lg.setFont(ST.script_font(96))
  ST.face = "round"
  lg.setColor(0.28, 0.2, 0.12, a or 1)
  lg.printf(ST.BRAND, 0, 24 + 10, W, "center")
end

-- Power-on: the world comes up out of the dark; the bulbs light round the board in turn; STARLIGHT is written
-- across in neon, a spark at the pen; "ARCADE · SHOWS · TV" under it; then the menu fades in under the sign.
local INTRO_LEN = 3.0
local function draw_intro()
  local up = math.min(1, intro_t / 0.6)
  if up < 1 then
    lg.setColor(0, 0, 0, 1 - up)
    lg.rectangle("fill", 0, 0, W, H)
  end
  local lit = math.max(0, math.min(1, (intro_t - 0.3) / 1.0))
  ST.draw_bulbs(1, lit)
  local wk = math.max(0, math.min(1, (intro_t - 0.9) / 1.0))
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
  if intro_t > 1.9 then
    local a = math.min(1, (intro_t - 1.9) / 0.5)
    neon_draw("ARCADE  ·  SHOWS  ·  TV", 0, 470, 34, ST.ACCENT, 0.8, "center", W, a)
  end
end

local function draw_scene()
  if scene == "hall" then
    ST.hall.draw()
    draw_volume()
    return
  end
  if scene == "shelf" then
    shelf.draw()
    draw_volume()
    draw_note()
    return
  end
  if scene == "tv" then
    -- The guide draws its own quiet backdrop (Home's sky under it cost ~15 fps: two extra full-screen passes).
    tv.draw()
    draw_volume()
    draw_note()
    return
  end
  if scene == "show" and cur_show then
    -- An idle show draws the whole picture (freedom.lua, texas.lua, ...).
    ST.L.top_busy = 0
    cur_show.draw()
    -- the on-air bug: STARLIGHT, faint, in the corner; it fades away while the show writes up there
    ST.bug = math.max(0, math.min(1, (ST.bug or 1) + (ST.L.top_busy > 0 and -0.08 or 0.03)))
    if not curtain and ST.bug > 0 then ST.draw(W - 190, 8, 30, 0.38 * ST.bug, nil, "left", 180) end
    curtain_draw()
    draw_volume()
    return
  end
  if scene == "shows" then
    shows.draw()
    draw_volume()
    return
  end
  local dim = scene == "night" and 1 or 0
  draw_background(dim)
  if scene == "intro" then
    draw_intro()
    return
  end
  if scene == "night" then
    draw_night()
    return
  end
  draw_marquee()
  draw_tabs(items[sel].section)
  draw_carousel()
  if scene == "attract" then
    lg.setColor(0, 0, 0, 0.25)
    lg.rectangle("fill", 0, 780, W, H - 780)
    neon_draw("PRESS ANY BUTTON", 0, 860, 44, 0xffd23f, 1, "center", W, 0.6 + 0.4 * math.sin(t * 4))
    local it = items[sel]
    if it.score then
      draw_hint("HIGH SCORE  " .. it.score .. "  —  can you beat it?", 930, 0.9)
    else
      draw_hint(ST.now_line or "12 CLASSICS  ·  THE YARD  ·  SHOWS  ·  TV", 930, 0.9)
    end
  else
    draw_info()
    draw_footer()
  end
  if menu_in > 0 then
    -- After the intro: the menu comes up under the sign.
    lg.setColor(0.02, 0.0, 0.05, menu_in / 0.45 * 0.8)
    lg.rectangle("fill", 0, 178, W, H - 178)
  end
  draw_volume()
  draw_celebration()
  if scene == "initials" then ST.initials.draw() end
  draw_note()
  draw_hold()
  if launch_item then
    local r, g, b = rgb(launch_item.tint)
    local k = math.max(0, math.min(1, (launch_t - 0.25) / 0.3))
    lg.setColor(r * 0.16, g * 0.08, b * 0.2, k)        -- into a dark glow of the game's colour
    lg.rectangle("fill", 0, 0, W, H)
  end
end

-- ------------------------------------------------------------------ the pictures between programs

-- The backdrop of every picture: the sky, the grid and the sign, still.
local function backdrop()
  draw_background(0.3)
  ST.draw_bulbs(1)
  ST.draw(0, 24, 96, 1)
end

-- "Get ready": the game's logo (or name) big, and how to come back.
local function picture_launch(it)
  if it.kind == "arcade" then return shelf.picture_arcade(it.game, it.shot, it.tint) end
  if it.kind == "game" then return shelf.picture_game(it.game, it.shot, it.tint) end
  backdrop()
  local r, g, b = rgb(it.tint)
  fx.glow(W / 2, 430, 420, 240, r, g, b, 0.35)
  if it.art then
    local iw, ih = it.art:getDimensions()
    local s = math.min(620 / iw, 300 / ih)
    lg.setColor(1, 1, 1, 1)
    lg.draw(it.art, W / 2, 430, 0, s, s, iw / 2, ih / 2)
  else
    neon_draw(it.title, 0, 380, 64, it.tint, 1.2, "center", W, 1, #it.title > 9 and 1.1 or 1.5)
  end
  neon_draw("GET READY!", 0, 620, 44, 0xffd23f, 1, "center", W)
  local leave = LEAVE[it.kind]
  if leave then
    lg.setColor(0.04, 0.0, 0.10, 0.85)
    rrect("fill", 60, 800, W - 120, 130, 24)
    lg.setColor(r, g, b, 0.9)
    lg.setLineWidth(2)
    rrect("line", 60, 800, W - 120, 130, 24)
    neon_draw(leave[1], 0, 822, 34, it.tint, 0.8, "center", W)
    lg.setFont(font(24))
    lg.setColor(0.9, 0.88, 1, 1)
    lg.printf(leave[2], 60, 880, W - 120, "center")
  end
end

-- "Welcome back": Home's own sky with the sign and the tabs, as the menu will look in a moment.
local function picture_back()
  backdrop()
  draw_tabs(items[sel].section)
end

-- Power-on: the sign, warming up.
local function picture_boot()
  draw_background(0.35)
  draw_unlit_sign()
  lg.setFont(font(26))
  lg.setColor(1, 0.86, 0.6, 0.7)
  lg.printf("warming up the lights...", 0, 470, W, "center")
end

local function file_exists(p) local f = p and io.open(p, "rb") if f then f:close() return true end return false end

-- Just before quitting for a game: its picture on the screen, and the welcome-back picture for homeloop
-- (once per boot: it lives in /tmp).
local function pictures_for(it)
  local t0 = uptime()
  local ok, bytes = pcall(splash.render, function() picture_launch(it) end)
  if ok then splash.show(bytes) end
  if BACK and not file_exists(BACK) then
    local ok2, back = pcall(splash.render, picture_back)
    if ok2 then splash.save(back, BACK) end
  end
  log(string.format("pictures %s in %.2f s", ok and "shown" or ("failed: " .. tostring(bytes)), uptime() - t0))
end

-- ------------------------------------------------------------------ actions

local function request(s, it, picture, gamekey)
  if picture and (not headless or os.getenv("HOME_FB")) then
    local ok, bytes = pcall(splash.render, picture)
    if ok then splash.show(bytes) end
    if BACK and not file_exists(BACK) then
      local ok2, back = pcall(splash.render, picture_back)
      if ok2 then splash.save(back, BACK) end
    end
  elseif it and (not headless or os.getenv("HOME_FB")) then pictures_for(it) end
  log("launch " .. s)
  -- The classic's high score as it was: on the way back, a higher one is celebrated.
  local played = nil
  if it and it.kind ~= "stock" then played = sel end
  local extra = it and it.kind == "classic" and ("score " .. it.index .. " " .. (high_score(it.index) or 0) .. "\n")
                or it and it.kind == "arcade" and ("ascore " .. it.id .. " " .. ST.arcade_best(it) .. "\n") or ""
  -- (a Shelf game, from the browser or a FAVORITES card: favs.lua credits its play time to it)
  gamekey = gamekey or (it and it.kind == "game" and ("game:" .. it.game.sys .. "/" .. it.game.file))
  if gamekey then extra = extra .. "playedgame " .. gamekey .. "\n" end
  save_state(extra ~= "" and extra or nil, played)
  if REQ then
    local f = io.open(REQ, "w")
    if f then f:write(s .. "\n") f:close() end
  end
  love.event.quit(0)
end

local function launch(it)
  if it.kind == "classic" then
    local i = it.index + 1
    return "classic " .. it.index .. " " .. smooth[i] .. " " .. speed[i]
  elseif it.kind == "cart" then return "cart " .. it.id
  elseif it.kind == "native" then return "native " .. it.native
  elseif it.kind == "arcade" then return "shelf arcade " .. it.game.file
  elseif it.kind == "game" then return "shelf " .. it.game.sys .. " " .. it.game.file
  elseif it.kind == "yard" then return "yard"
  else return "stock" end
end

local function move(d)
  local old = items[sel].section
  sel = math.max(1, math.min(#items, sel + d))
  play(items[sel].section ~= old and "section" or "move")
end

local function jump_section(d)
  local cur = items[sel].section
  local want = math.max(1, math.min(#SECTIONS, cur + d))
  if want == cur then return end
  for i, it in ipairs(items) do
    if it.section == want then sel = i break end
  end
  play("section")
end

local function read_volume()
  local s = read_file(VOLUME_FILE)
  local n = s and tonumber(s:match("%d+"))
  if n then vol_level = math.max(0, math.min(15, n)) end
end

-- The secret code: up up down down left right left right, top-left (B), lower (A).
local code_before = {}            -- the card and settings before each press: the code's moves are undone
local function secret(name)
  code_buf[#code_buf + 1] = name
  code_before[#code_before + 1] = {sel = sel, speed = {unpack(speed)}, smooth = {unpack(smooth)}}
  if #code_buf > #CODE then table.remove(code_buf, 1) table.remove(code_before, 1) end
  if #code_buf < #CODE then return false end
  for i = 1, #CODE do if code_buf[i] ~= CODE[i] then return false end end
  local b = code_before[1]
  sel = b.sel
  for i = 1, 12 do
    if speed[i] ~= b.speed[i] or smooth[i] ~= b.smooth[i] then
      speed, smooth = b.speed, b.smooth
      cfg_write("Speed.cfg", speed)
      cfg_write("Smoothing.cfg", smooth)
      break
    end
  end
  code_buf, code_before = {}, {}
  return true
end

-- ------------------------------------------------------------------ the idle shows
local SHOW_BLURB = {
  auto = "Follows the calendar: Halloween to New Year's in season, the Longhorns on game days, Texas, Mission " ..
         "Control and the Freedom Show by day, the night sky at night. LOWER BUTTON: watch now.",
}
local function show_card()
  for _, it in ipairs(items) do
    if it.kind == "show" then
      it.sub = SHOW_NAMES[show_mode] .. "   ·   top buttons change it"
      it.blurb = SHOW_BLURB[show_mode] or (SHOW_NAMES[show_mode] .. " only, whenever nobody's playing. LOWER BUTTON: watch now.")
    end
  end
end
-- The idle shows need the GPU memory the menu's pictures hold: Home has ~35 MB on this cabinet and the Mali
-- driver keeps ~20 of it (2026-11-01: the Freedom Show over the menu's 12 MB of labels and logos ran the OOM
-- killer). So a show frees them, and waking paints them again (the cards in view at once, the rest a few a frame).
local menu_freed = false
local function free_menu_pictures()
  if menu_freed then return end
  menu_freed = true
  for _, it in ipairs(items) do
    if it.art then it.art:release() it.art = nil end
    if (it.kind == "arcade" or it.kind == "game") and it.shot then it.shot:release() it.shot = nil end
    it.asked = nil
  end
  for k, e in pairs(neon_cache) do e.img:release() neon_cache[k] = nil end
  if ST.world then ST.world:release() ST.world = nil ST.world_name = nil end
  for i = #label_jobs, 1, -1 do label_jobs[i] = nil end
  labels_for, labels_sel = {}, nil
  collectgarbage()
end
local demo                              -- started from a show's tiles: its id (back to them at the end)
local auto_rot = 0                      -- AUTO: ordinary days take turns
local function stop_show()
  if cur_show then cur_show.stop() cur_show = nil end
  curtain = nil
  night.set_only(nil)
  -- the show's painted labels go with it (in AUTO, show follows show with no menu between: they piled up)
  if menu_freed then
    for k, e in pairs(neon_cache) do e.img:release() neon_cache[k] = nil end
  end
end
-- Arcade and FAVORITES pictures follow the chosen card: asked for within 3, released beyond 5.
function ST.near_shots(all)
  if menu_freed or (ST.near_sel == sel and not all) then return end
  ST.near_sel = sel
  for k, it in ipairs(items) do
    if (it.kind == "arcade" or it.kind == "game") and it.game.art then
      local d = math.abs(k - sel)
      if (d <= 3 or (all and it.kind == "arcade")) and not it.shot and not it.asked and worker then
        it.asked = true
        love.thread.getChannel("home_work"):push({"art", k, it.game.art})
      elseif d > 5 and it.shot and not all then
        it.shot:release()
        it.shot, it.asked = nil, nil
      end
    end
  end
end

local function restore_menu_pictures()
  stop_show()
  if not menu_freed then return end
  menu_freed = false
  for k, e in pairs(neon_cache) do e.img:release() neon_cache[k] = nil end
  load_art()
  ST.world_load(ST.world_want)
  ST.img(96)
  labels_for, labels_sel = {}, nil
  manage_labels(false)
  label_jobs[#label_jobs + 1] = function() neon_img("PRESS ANY BUTTON", 44, 0xffd23f, 1) end
  lg.setCanvas()
end

-- The games browser takes the menu's pictures' memory while it's open (2026-11-07: both at once, with its box
-- art, ran Home out of memory), and gives it back on the way out.
function ST.shelf_open(row, file, failed)
  free_menu_pictures()
  scene = "shelf"
  if file then shelf.enter_at(row, file, failed) else shelf.enter(row) end
end
function ST.shelf_close()
  shelf.quit()
  scene = "menu"
  restore_menu_pictures()
end

-- Play a show (from its segment seg, if given; demo: from its tiles).
local function play_show(id, seg, from_demo)
  free_menu_pictures()
  stop_show()
  demo = from_demo and id or nil
  cur_show_id = id
  local sg = seg and seg > 0 and shows.segments(id)[seg] or nil
  if id == "night" then
    -- the night sky is the menu's world, darkened: its painting stays (384 KB)
    ST.world_load(ST.world_want)
    scene = "night"
    auto_night_t = 0
    night.set_only(sg and sg[3] or nil)
    night_t = (sg and not sg[3]) and sg[1] / NIGHT_SPEED or 0
  else
    cur_show = shows.module(id)
    if not cur_show then scene = "menu" restore_menu_pictures() return end
    scene = "show"
    curtain = {phase = "cover", n = 0, good = 0, f = 0, seed = os.time() + math.random(1, 1e6), at = sg and sg[1] or nil,
               card = (not from_demo and not os.getenv("HOME_SHOW")) and id or nil}
  end
  log("show " .. id .. (sg and (": " .. sg[2]) or ""))
end
-- The Longhorns' news for AUTO (utgame.status: the game window, game day, a big week, ...), every second.
local game_now = {}
-- Nobody has played for a while: the show for this mode (and the calendar).
local function start_show()
  local id = show_mode
  if id == "auto" then
    id = shows.pick(os.time(), game_now, auto_rot)
    auto_rot = auto_rot + 1
  end
  play_show(id)
end
-- The cards that say what's coming: the SCHEDULE (AUTO: what the calendar picks next) and the LONGHORNS (the
-- next game, the live score, the final). Every half minute, and when the mode changes.
local function update_cards()
  for _, it in ipairs(items) do
    if it.kind == "show" and show_mode == "auto" then
      local id = shows.pick(os.time(), game_now, auto_rot)
      it.sub = "AUTO   ·   UP NEXT: " .. (SHOW_NAMES[id] or "") .. "   ·   top buttons change it"
    elseif it.kind == "showcard" and it.show == "longhorns" then
      local g = utgame.game
      local text = shows.BY_ID.longhorns.blurb
      if g and g.kickoff then
        local now = utgame.now()
        local where = (g.home and "VS " or "AT ") .. string.upper(g.opp_loc ~= "" and g.opp_loc or g.opp)
        if g.state == "in" then
          text = string.format("LIVE NOW: TEXAS %d, %s %d  ·  %s%s", g.us or 0, g.opp_abbr, g.them or 0, string.upper(g.detail),
                               g.net and ("  ·  " .. g.net) or "")
        elseif g.state == "post" and now - g.kickoff < 24 * 3600 then
          text = string.format("FINAL: TEXAS %d, %s %d%s", g.us or 0, g.opp_abbr, g.them or 0, (g.us or 0) > (g.them or 0) and "  ·  HOOK 'EM!" or "")
        elseif g.state == "pre" and g.kickoff - now < 10 * 86400 then
          text = "NEXT: " .. where .. "  ·  " .. string.upper(os.date("%a %b %d, %I:%M %p", g.kickoff)):gsub(" 0", " ") ..
                 (g.net and ("  ·  " .. g.net) or "")
        end
      end
      it.blurb = text
    end
  end
  ST.update_world()
end

-- The world's season (the menu's painting) and the now-and-next line, from the calendar and the Longhorns' news.
local HOLIDAY_WORLD = {christmas = "christmas", newyear = "newyear", thanksgiving = "thanksgiving", halloween = "halloween",
                       valentine = "valentine", easter = "easter", freedom = "july4", space = "summer", texas = "spring"}
function ST.update_world()
  local now = os.time()
  local d = os.date("*t", now)
  local want = "base"
  local h = now > 1700000000 and shows.holiday(d)
  if game_now.window or game_now.gameday then want = "gameday"
  elseif h and HOLIDAY_WORLD[h] then want = HOLIDAY_WORLD[h]
  elseif d.month >= 6 and d.month <= 8 then want = "summer"
  elseif d.month >= 3 and d.month <= 5 then want = "spring" end
  ST.world_want = want
  if not menu_freed and ST.world_name ~= want then ST.world_load(want) end
  -- now and next
  local parts = {}
  if now > 1700000000 then
    local id = shows.pick(now, game_now, auto_rot)
    if SHOW_NAMES[id] and id ~= "night" then parts[#parts + 1] = "ON TONIGHT: " .. SHOW_NAMES[id] end
  end
  local g = utgame.game
  if g and g.kickoff then
    local un = utgame.now()
    if g.state == "in" then
      parts[#parts + 1] = string.format("LIVE: TEXAS %d, %s %d", g.us or 0, g.opp_abbr, g.them or 0)
    elseif g.state == "pre" and g.kickoff - un < 8 * 86400 then
      parts[#parts + 1] = "LONGHORNS " .. (g.home and "VS " or "AT ") .. string.upper(g.opp_abbr) .. " " ..
                          (string.upper(os.date("%a %I:%M %p", g.kickoff)):gsub(" 0", " "))
    end
  end
  ST.now_line = #parts > 0 and table.concat(parts, "   ·   ") or nil
end

local shows_ctx                          -- for the SHOWS tiles (love.load)
local function open_tiles(id)
  free_menu_pictures()
  stop_show()
  demo = nil
  shows.open(shows_ctx, id)
  scene = "shows"
end

local function handle(name)
  if name == "volup" or name == "voldown" then
    -- The kernel has changed it (volctrl.sh saves it); read it a moment later and show it.
    read_volume()
    vol_t, vol_read = 1.8, 0.2
    if scene ~= "night" then play("volume") end
    return
  end
  idle = 0
  if scene == "intro" then
    scene = "menu"
    menu_in = 0.3
    return
  end
  if scene == "attract" then
    scene = "menu"
    if attract_sel then sel = attract_sel end
    return
  end
  if scene == "night" or scene == "show" then
    -- The first press only wakes it: back to the show's tiles (watching one), or the menu.
    if demo then
      open_tiles(demo)
    else
      scene = "menu"
      if attract_sel then sel, pos = attract_sel, attract_sel end
      restore_menu_pictures()
    end
    play("wake")
    return
  end
  if scene == "shows" then
    local r = shows.handle(name)
    if r == "back" then
      shows.close()
      scene = "menu"
      restore_menu_pictures()
      play("back")
    elseif type(r) == "table" then
      shows.close()
      play("launch")
      play_show(r[2], r[3], true)
    end
    return
  end
  if scene == "tv" then
    if tv.handle(name) == "exit" then scene = "menu" end
    return
  end
  if scene == "shelf" then
    if shelf.handle(name) == "exit" then ST.shelf_close() end
    return
  end
  if scene == "initials" then
    ST.initials.handle(name)
    return
  end
  if scene == "hall" then
    if ST.hall.handle(name) == "exit" then scene = "menu" ST.near_sel = nil end
    return
  end
  if launch_item then return end
  if name == "2p" then return end
  if secret(name) then
    -- (the code's presses moved the cards and maybe a setting: put back as they were)
    for _, it in ipairs(items) do if it.kind == "classic" then it.score = high_score(it.index) end end
    party = 20
    celebrate = {score = "PARTY MODE", title = "you found the secret", tint = 0xff4fd8, t = 0, big = true}
    log("party mode")
    return
  end
  local it = items[sel]
  if name == "up" then move(-1)
  elseif name == "down" then move(1)
  elseif name == "left" then jump_section(-1)
  elseif name == "right" then jump_section(1)
  elseif (name == "tl" or name == "tr") and it.kind == "classic" then
    local i = it.index + 1
    if name == "tl" then
      speed[i] = 1 - speed[i]
      cfg_write("Speed.cfg", speed)
      it.score = high_score(it.index)      -- fast Pac-Man keeps its own high score
    else smooth[i] = 1 - smooth[i] cfg_write("Smoothing.cfg", smooth) end
    play("toggle")
  elseif (name == "low" or name == "1p") and returning and t < 0.6 then
    -- Just back from a game: a button still being mashed there (fire is the lower button) is not a choice.
    return
  elseif (name == "tl" or name == "tr") and it.kind == "show" then
    local i = 1
    for k, m in ipairs(SHOW_MODES) do if m == show_mode then i = k end end
    if name == "tr" then i = i % #SHOW_MODES + 1 else i = (i - 2) % #SHOW_MODES + 1 end
    show_mode = SHOW_MODES[i]
    show_card()
    update_cards()
    save_state()
    play("toggle")
  elseif (name == "low" or name == "1p") and it.kind == "show" then
    -- Watch it now (AUTO: what the calendar picks).
    attract_sel = sel
    play("launch")
    play_show(show_mode == "auto" and shows.pick(os.time(), game_now, auto_rot) or show_mode)
  elseif (name == "low" or name == "1p") and it.kind == "showcard" then
    attract_sel = sel
    play("launch")
    open_tiles(it.show)
  elseif (name == "low" or name == "1p") and it.kind == "favhint" then
    -- The empty FAVORITES card: nothing to start (a launch here would have been the original menu).
    play("back")
  elseif (name == "low" or name == "1p") and it.kind == "hall" then
    scene = "hall"
    ST.near_shots(true)   -- (its rows show every board's title screen)
    ST.hall.enter()
    play("launch")
  elseif (name == "low" or name == "1p") and it.kind == "shelf" then
    -- The browser opens in Home itself, at this card's row.
    if it.row then
      ST.shelf_open(it.row)
      play("launch")
    end
  elseif (name == "low" or name == "1p") and it.kind == "tv" then
    -- The guide opens in Home itself: no program to start.
    scene = "tv"
    tv.enter()
    play("launch")
  elseif name == "low" or name == "1p" then
    launch_item = it
    launch_t = 0
    play("launch")
  end
end

-- ------------------------------------------------------------------ the loop

-- The TV guide's and the Shelf's drawing helpers, and coming back from one of their programs. (Out of
-- love.load: LuaJIT allows a function 60 upvalues.)
local function shelf_setup()
  ST.hall.load({W = W, H = H, font = font, neon_draw = neon_draw, rgb = rgb, rrect = rrect, fx = fx, play = play,
                down = down, commas = shelf.commas,
                entries = function()
                  local out = {}
                  for k, it in ipairs(items) do
                    if it.kind == "arcade" then
                      it.table = shelf.arcade_table(it.id)
                      out[#out + 1] = {title = it.title, tint = it.tint, item = it, rows = it.table,
                                       launch = function() sel, pos = k, k scene = "menu" launch_item = it launch_t = 0 end}
                    elseif it.kind == "classic" and it.score then
                      out[#out + 1] = {title = it.title, tint = it.tint, item = it, classic = true,
                                       rows = {{tonumber(it.score) or 0, "", false}},
                                       launch = function() sel, pos = k, k scene = "menu" launch_item = it launch_t = 0 end}
                    end
                  end
                  return out
                end})
  ST.initials.load({W = W, H = H, font = font, neon_draw = neon_draw, rgb = rgb, rrect = rrect, fx = fx, play = play,
                    down = down, commas = shelf.commas,
                    done = function(it, score, initials)
                      shelf.save_name(it.id, score, initials)
                      it.table = shelf.arcade_table(it.id)
                      it.score = ST.arcade_score_text(it)
                      celebrate = {score = shelf.commas(score), title = it.title .. "   ·   " .. initials, tint = it.tint, t = 0}
                      log("initials " .. it.id .. " " .. score .. " " .. initials)
                    end})
  -- Back from an arcade board with a better score than it had: the classics' celebration, with the initials.
  do
    local st = STATE and read_file(STATE) or ""
    local set, before = st:match("ascore (%S+) (%d+)")
    before = tonumber(before)
    for _, it in ipairs(items) do
      if it.kind == "arcade" and it.id == set and before and os.getenv("HOME_INTRO") ~= "1" then
        local t = shelf.arcade_table(it.id)
        if t and t[1][1] > before then
          log("new arcade high score " .. set .. " " .. before .. " -> " .. t[1][1] .. " " .. t[1][2])
          if t[1][2] == "" then
            -- The board asked for no initials: Home does (initials.lua), then celebrates.
            ST.initials.start(it, t[1][1])
            scene = "initials"
          else
            celebrate = {score = shelf.commas(t[1][1]), title = it.title .. "   ·   " .. t[1][2], tint = it.tint, t = 0}
          end
        end
      end
    end
  end
  -- Live TV: the guide's lists, and coming back from a channel (tvloop wrote how it ended).
  tv.load({W = W, H = H, font = font, neon_draw = neon_draw, rgb = rgb, rrect = rrect, fx = fx, play = play,
           log = log, down = down, backdrop = backdrop,
           request = function(s, picture) request(s, nil, picture) end,
           save_picture = function(path, picture)
             if headless and not os.getenv("HOME_FB") then return end
             local ok, bytes = pcall(splash.render, picture)
             if ok then splash.save(bytes, path, true) end
           end})
  shelf.load({W = W, H = H, font = font, neon_draw = neon_draw, rgb = rgb, rrect = rrect, fx = fx, play = play,
              log = log, down = down, backdrop = backdrop,
              request_art = worker and function(key, path) love.thread.getChannel("home_work"):push({"art", key, path}) end,
              request = function(s, picture, key) request(s, nil, picture, key) end})
  do
    -- Back from a game on the Shelf: the browser, on that game.
    local key, file, failed = shelf.returning()
    if key then
      for k, it in ipairs(items) do if it.kind == "shelf" and (it.row == key or (key == "recent" and it.row)) then sel, pos = k, k break end end
      ST.shelf_open(key, file, failed)
      returning = true
    end
  end
end

function love.load()
  mark("love.load")
  love.mouse.setVisible(false)
  local fd = love.filesystem.getInfo("fonts/Fredoka-SemiBold.ttf") and love.filesystem.newFileData("fonts/Fredoka-SemiBold.ttf")
  font_data = fd
  ST.script_data = love.filesystem.getInfo("fonts/Pacifico-Starlight.ttf") and love.filesystem.newFileData("fonts/Pacifico-Starlight.ttf")
  math.randomseed(RENDER and 1 or os.time())   -- the PC-rendered picture is the same every build
  for i = 1, 90 do
    stars[i] = {math.random() * W, math.random() * 700, math.random() * 6, 0.5 + math.random() * 2,
                0.4 + math.random() * 0.6, math.random() < 0.15 and 3 or 2}
  end
  fx.load()
  night.load({W = W, H = H, HORIZON = HORIZON, font = font, neon_draw = neon_draw, fx = fx, log = log})
  music.log = log
  if not RENDER then utgame.start(log) end
  local show_ctx = {W = W, H = H, font = font, neon_draw = neon_draw, neon_img = neon_img, neon_release = neon_release,
                    brand_draw = function(y, px, a) ST.draw(0, y, px, a) end,
                    fx = fx, sfx = music.sfx,
                    log = log, rgb = rgb}
  if TRACE then
    trace_font = function(px) trace("font", px) end
    show_ctx.trace = trace
    show_ctx.sfx = function(name, gain) trace("sfx", name) music.sfx(name, gain) end
  end
  for _, sh in ipairs(shows.LIST) do
    local m = shows.module(sh.id)
    if m then m.load(show_ctx) end
  end
  if RENDER then
    -- Render a picture and quit (the PC build of the power-on picture): "boot:PATH".
    local kind, path = RENDER:match("^(%a+):(.+)$")
    ST.world_load("base")
    local bytes = splash.render(kind == "back" and picture_back or picture_boot)
    splash.save(bytes, path, path:match("%.gz$") ~= nil)
    love.event.quit(0)
    return
  end
  load_state()
  if love.thread then
    worker = love.thread.newThread("worker.lua")
    worker:start()
    -- (the music: its own thread, music.lua, started after the first frame)
  end
  load_art()
  mark("art")
  -- The labels in view now; the rest a few a frame, before the frame's drawing starts (see neon_img).
  ST.world_load(ST.world_want)
  ST.img(96)
  if scene == "intro" or os.getenv("HOME_INTRO") == "1" then neon_img("ARCADE  ·  SHOWS  ·  TV", 34, ST.ACCENT, 0.8) end
  manage_labels(false)
  label_jobs[#label_jobs + 1] = function() neon_img("PRESS ANY BUTTON", 44, 0xffd23f, 1) end
  label_jobs[#label_jobs + 1] = function() neon_img("NEW HIGH SCORE!", 44, 0xffd23f, 1) end
  lg.setCanvas()
  mark("labels")
  sound.load()
  mark("sounds")
  local returned = load_state()
  if returned and returned:match("failed") then
    note, note_t = "That one didn't start. Pick another?", 4
  end
  do
    local st = STATE and read_file(STATE) or ""
    local idx, before = st:match("score (%d+) (%d+)")
    idx, before = tonumber(idx), tonumber(before)
    local now = idx and high_score(idx)
    if now and before and now > before and os.getenv("HOME_INTRO") ~= "1" then
      celebrate = {score = now, title = CLASSICS[idx + 1].title, tint = CLASSICS[idx + 1].tint, t = 0}
      log("new high score " .. idx .. " " .. before .. " -> " .. now)
    end
  end
  if os.getenv("HOME_INTRO") ~= "1" and (os.getenv("HOME_SKIP_INTRO") == "1" or (STATE and read_file(STATE))) then
    scene = "menu"       -- the intro is for power-on; coming back from a game goes straight to the menu
    returning = STATE ~= nil and read_file(STATE) ~= nil and os.getenv("HOME_INTRO") ~= "1"
  else
    play("intro")
  end
  shelf_setup()
  shows_ctx = {request_art = worker and function(key, path)
                 love.thread.getChannel("home_work"):push({"art", key, path})
               end or nil, backdrop = backdrop, rgb = rgb, neon_draw = neon_draw, font = font, fx = fx, rrect = rrect, play = play}
  shows.set_ctx(shows_ctx)
  for k, it in ipairs(items) do
    if it.kind == "tv" then
      local n, g, p = tv.channel_count()
      if n > 0 then it.blurb = string.format("%d channels in %d groups, from %d playlists.", n, g, p) end
      if not tv.has_playlists() then it.blurb = "No TV playlists on this cabinet yet." end
    end
  end
  do
    local rc, idx = tv.returning()
    if rc then
      for k, it in ipairs(items) do if it.kind == "tv" then sel, pos = k, k end end
      if rc ~= 10 then
        scene = "tv"
        tv.enter(rc, idx)
      else
        scene = "menu"
      end
      returning = true
    end
  end
  show_card()
  if os.getenv("HOME_SHOW_LIST") then
    -- tools/show_thumbs.py: the shows and how many segments each has
    local f = io.open(os.getenv("HOME_SHOW_LIST"), "w")
    for _, sh in ipairs(shows.LIST) do
      if shows.available(sh.id) then
        local m = shows.module(sh.id)
        f:write(sh.id, " ", #shows.segments(sh.id), " ", (m and m.THUMB) or (sh.id == "night" and 7 or 1), "\n")
      end
    end
    f:close()
    if os.getenv("HOME_SHOW_SEGS") then
      -- tools/show_pulse.py: each segment's start (seconds) and title, and each show's length
      f = io.open(os.getenv("HOME_SHOW_SEGS"), "w")
      for _, sh in ipairs(shows.LIST) do
        local m = shows.module(sh.id)
        if m or sh.id == "night" then
          f:write(sh.id, " len ", m and m.LEN or 0, "\n")
          for _, sg in ipairs(shows.segments(sh.id)) do f:write(sh.id, " seg ", sg[1], " ", sg[2], "\n") end
        end
      end
      f:close()
    end
    love.event.quit(0)
    return
  end
  if SHOW_NOW then
    -- tests: straight into a show (ID, ID:SECONDS, ID@SEGMENT)
    local id, how, n = SHOW_NOW:match("^(%a+)([:@]?)(%d*)$")
    if id and shows.available(id) then
      if how == "@" then play_show(id, tonumber(n))
      else
        play_show(id)
        if how == ":" and curtain then curtain.at = tonumber(n) curtain.seed = 1 end
      end
    end
  end
  read_volume()
  local sc = {}
  for _, it in ipairs(items) do
    if it.kind == "classic" then
      it.score = high_score(it.index)
      sc[#sc + 1] = it.index .. "=" .. tostring(it.score)
    end
  end
  log("high scores: " .. table.concat(sc, " "))
  -- Our games: their save's number, as The Yard shows it.
  for _, it in ipairs(items) do
    local d = it.statdef
    local sv = d and read_file(GAMES .. "/" .. it.id .. ".sav")
    local n = sv and tonumber(sv:match(d[1] .. " (%d+)"))
    if n and n > 0 then it.stat = (n == 1 and d[3]) or string.format(d[2], n) end
  end
  -- Back from a game: a soft welcome (the celebration has its own fanfare).
  if returning and not celebrate then play("back") end
  if headless or not direct then canvas = lg.newCanvas(W, H) end
  log("home start, " .. #items .. " items, scene " .. scene)
end

-- The worker waits for jobs: tell it to stop, so LÖVE's exit does not wait on it.
function love.quit()
  if worker then love.thread.getChannel("home_work"):push({"quit"}) end
  tv.quit()
  shelf.quit()
  music.quit()
  return false
end

-- The song for what is on the screen (songs.lua; the night has one for each of its scenes), and its volume.
local NIGHT_SONG = {dusk = "dusk", quiet = "quiet", rest = "none", dawn = "dawn"}
local music_vol
local function music_tick()
  if scene == "intro" then return end
  local want, vol, fade = "menu", 0.32, 1.2
  if scene == "night" then
    local sc = night.scene_at(night_t * NIGHT_SPEED)
    want, vol, fade = NIGHT_SONG[sc] or sc, 0.26, 3
  elseif scene == "show" and cur_show then
    -- (behind the curtain, before the show has started, it isn't asked: silence until it has)
    if curtain and curtain.phase == "cover" then return end
    want, vol, fade = cur_show.music(), 0.42, 2
    if TRACE then
      if cur_show.clock then trace("t", cur_show.clock()) end
      if want ~= trace_seen.music then trace_seen.music = want trace("music", want) end
      local act = cur_show.act and cur_show.act()
      if act ~= trace_seen.act then trace_seen.act = act trace("act", act) end
    end
  elseif scene == "tv" or scene == "shelf" then want = "tv"
  elseif scene == "attract" then want = "attract" end
  -- (headless tests choose the song too, so a show that can't say which is caught on the PC, but play nothing)
  if headless then return end
  if vol ~= music_vol then music_vol = vol music.volume(vol, 1.5) end
  music.play(want, fade)
end

-- The TV guide, attract, and the idle shows (night sky, Freedom Show), with their music. (Out of love.update:
-- LuaJIT allows a function 60 upvalues.)
local cards_t = 0
local function update_idle(dt)
  cards_t = cards_t - dt
  if cards_t <= 0 then cards_t = 30 update_cards() end
  if scene == "tv" then
    idle = 0
    if tv.update(dt) == "exit" then scene = "menu" end
  end
  if scene == "shelf" then
    idle = 0
    if shelf.update(dt) == "exit" then ST.shelf_close() end
  end
  if scene == "initials" then
    idle = 0
    if ST.initials.update(dt) == "done" then scene = "menu" end
  end
  if scene == "hall" then
    idle = 0
    if ST.hall.update(dt) == "exit" then scene = "menu" ST.near_sel = nil end
  end
  idle = idle + dt
  if scene == "menu" and idle > IDLE_ATTRACT then scene = "attract" attract_t = 0 attract_sel = sel end
  if scene == "attract" then
    attract_t = attract_t + dt
    if attract_t > 3.5 then attract_t = 0 sel = sel % #items + 1 end
    if idle > IDLE_NIGHT then start_show() end
  end
  if scene == "night" then
    night_t = night_t + dt
    auto_night_t = auto_night_t + dt
    -- AUTO: the night sky has had its half hour (or the Longhorns kick off): the calendar's show.
    if show_mode == "auto" and not demo and (auto_night_t > AUTO_NIGHT_BLOCK or game_now.window) then
      local id = shows.pick(os.time(), game_now, auto_rot)
      if id ~= "night" then auto_rot = auto_rot + 1 play_show(id) else auto_night_t = 0 end
    end
  end
  if scene == "show" and cur_show then
    idle = 0
    if curtain_step(dt) and cur_show.update(dt) then
      if os.getenv("HOME_SHOW_ONCE") then love.event.quit(0) return end   -- (tools/show_lint.py)
      -- The show is over: its tiles again (watching one), the same show (one show only), or the night sky's
      -- turn (AUTO; the Longhorns go on while the game is on).
      if demo then open_tiles(demo)
      elseif show_mode ~= "auto" then play_show(show_mode)
      elseif cur_show_id == "longhorns" and game_now.window then play_show("longhorns")
      else play_show("night") end
    end
  end
  if scene == "shows" then
    shows.update(dt)
    if idle > IDLE_NIGHT then shows.close() start_show() end
  end
  music_tick()
end

local fps_t, fps_n = 0, 0
local last_letters = 0
local FIXED_DT = tonumber(os.getenv("HOME_DT") or "")   -- tests: every frame this long (PC renders of the shows)
local FPS_EVERY = tonumber(os.getenv("HOME_FPS_EVERY") or "") or 300   -- the frames line: every this many frames
local hitches = 0
function love.update(dt)
  if FIXED_DT then dt = FIXED_DT end
  -- a frame that took too long (a hitch you can see): logged with what was going on, the first 300 a run
  if dt > 0.045 and frame > 10 and hitches < 300 then
    hitches = hitches + 1
    log(string.format("hitch %d ms, scene %s%s, music %s, lua %d KB", dt * 1000, scene,
                      cur_show and cur_show.act and (" " .. tostring(cur_show_id) .. ":" .. tostring(cur_show.act())) or "",
                      tostring(music.now), collectgarbage("count")))
  end
  fps_t, fps_n = fps_t + dt, fps_n + 1
  if fps_n == FPS_EVERY then
    local st = lg.getStats()
    log(string.format("frames: %.1f fps (%.2f ms), scene %s, lua %d KB, textures %d KB (%d), draws %d", fps_n / fps_t,
                      fps_t / fps_n * 1000, scene, collectgarbage("count"), st.texturememory / 1024, st.images + st.canvases,
                      st.drawcalls))
    fps_t, fps_n = 0, 0
  end
  dt = math.min(dt, 0.1)
  t = t + dt
  frame = frame + 1
  if frame == 3 and not headless then music.start() end
  utgame.update(dt)
  if frame % 60 == 0 then game_now = utgame.status() end
  local merr = music.check()
  if merr then log("music: " .. merr) end
  if worker then
    local msg = love.thread.getChannel("home_done"):pop()
    while msg do
      if msg[1] == "art" and type(msg[2]) == "string" and msg[2]:sub(1, 6) == "shelf:" then
        if msg[3] then shelf.art_ready(msg[2], msg[3]) else shelf.art_failed(msg[2]) end
      elseif msg[1] == "art" and type(msg[2]) == "string" then
        if msg[3] then shows.thumb_ready(msg[2], msg[3]) end
      elseif msg[1] == "art" and msg[3] and not menu_freed then
        local it = items[msg[2]]
        if it.kind == "arcade" or it.kind == "game" then it.shot = art_image(msg[3]) else it.art = art_image(msg[3]) end
      end
      msg = love.thread.getChannel("home_done"):pop()
    end
    local err = worker:getError()
    if err then log("worker: " .. err) worker = nil end
  end
  for _, c in ipairs(script) do
    if c[1] == frame then
      if c[2] == "press" then control_down(c[3]) control_up(c[3])
      elseif c[2] == "down" then control_down(c[3])
      elseif c[2] == "up" then control_up(c[3])
      elseif c[2] == "shot" then shot_req = c[3]
      elseif c[2] == "quit" then love.event.quit(0) end
    end
  end
  for _, n in ipairs(pressed_q) do handle(n) end
  pressed_q = {}
  if not menu_freed then manage_labels(false) end
  if PREVIEW and down["1p"] and down["2p"] and not launch_item then
    hold_t = hold_t + dt
    idle = 0
    if hold_t >= HOLD_SECS then hold_t = 0 request("yard") end
  else
    hold_t = 0
  end
  if scene == "intro" then
    intro_t = intro_t + dt
    if intro_t > 0.9 and not ST.stung then ST.stung = true music.sfx("sting", 0.9) end
    local letters = math.floor(math.min(1, intro_t / 1.2) * 9 + 0.001)
    if letters > last_letters then last_letters = letters play("tick") end
    if intro_t > INTRO_LEN then scene = "menu" menu_in = 0.45 end
  end
  update_idle(dt)
  fx.update(dt, scene == "menu" or scene == "attract" or scene == "night")
  if vol_t > 0 then vol_t = vol_t - dt end
  if menu_in > 0 then menu_in = math.max(0, menu_in - dt) end
  if party > 0 then party = math.max(0, party - dt) end
  if celebrate then
    if celebrate.t == 0 then play("fanfare") confetti = nil end
    celebrate.t = celebrate.t + dt
    if celebrate.t > 5 then celebrate = nil end
  end
  if vol_read then
    vol_read = vol_read - dt
    if vol_read <= 0 then vol_read = nil read_volume() end
  end
  pos = pos + (sel - pos) * math.min(1, dt * 11)
  if scene ~= "hall" then ST.near_shots() end
  if note then note_t = note_t - dt if note_t <= 0 then note = nil end end
  if launch_item then
    launch_t = launch_t + dt
    if launch_t > 0.6 then
      local it = launch_item
      local s = launch(it)
      launch_item = nil
      request(s, it)
    end
  end
end

local first_drawn = false
function love.draw()
  -- Labels still to paint: two a frame, before anything is drawn on the screen.
  for _ = 1, 2 do
    local job = table.remove(label_jobs, 1)
    if job then job() lg.setCanvas() end
  end
  if not first_drawn then
    first_drawn = true
    mark("first frame")
    local parts = {}
    for i, m in ipairs(marks) do parts[i] = string.format("%s %.2f", m[1], m[2]) end
    log("startup: " .. table.concat(parts, ", "))
  end
  if canvas then
    lg.setCanvas(canvas)
    lg.clear(0, 0, 0, 1)
    lg.origin()
    draw_scene()
    lg.setCanvas()
    if shot_req then
      -- (straight to the file: two test runs at once would share a "shot.png" in the save directory)
      local d = canvas:newImageData():encode("png"):getString()
      local f = io.open(shot_req, "wb")
      if f then f:write(d) f:close() end
      if TRACE then trace("shot", shot_req) end
      shot_req = nil
    end
    if not headless then
      lg.origin()
      local ww, wh = lg.getDimensions()
      lg.setColor(1, 1, 1, 1)
      lg.draw(canvas, ww / 2, wh / 2, -math.pi / 2, 1, 1, W / 2, H / 2)
    end
  else
    -- Straight onto the framebuffer, turned (as GPU yard does: the canvas cost a whole extra pass).
    local ww, wh = lg.getDimensions()
    lg.origin()
    lg.translate(ww / 2, wh / 2)
    lg.rotate(-math.pi / 2)
    lg.translate(-W / 2, -H / 2)
    draw_scene()
  end
end
