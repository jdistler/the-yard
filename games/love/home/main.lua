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
-- ST: Home's shared state and settings, the app table (HOME_REFACTOR.md CP3; it began as Starlight's state when
-- main.lua reached Lua's 200 locals)
local ST = {world_want = "base", L = require("showlib"), initials = require("initials"),
            hall = require("hall")}

local W, H = 768, 1024                       -- the upright picture; the panel shows the framebuffer turned
local headless = os.getenv("HOME_HEADLESS") == "1"
ST.ART = os.getenv("HOME_ART") or "/data/home/art"
ST.GAMES = os.getenv("HOME_GAMES") or "/data/Games"
ST.REQ = os.getenv("HOME_REQ")
ST.STATE = os.getenv("HOME_STATE")
ST.LOGF = os.getenv("HOME_LOG")
ST.BACK = os.getenv("HOME_BACK")                                  -- the welcome-back picture (homeloop)
ST.VOLUME_FILE = os.getenv("HOME_VOLUME") or "/data/spk_volume"
ST.RENDER = os.getenv("HOME_RENDER")
ST.IDLE_ATTRACT = tonumber(os.getenv("HOME_IDLE") or "") or 45    -- seconds without a press
ST.IDLE_NIGHT = tonumber(os.getenv("HOME_NIGHT") or "") or 180
ST.NIGHT_SPEED = tonumber(os.getenv("HOME_NIGHT_SPEED") or "") or 1   -- tests: the night fast-forwarded
-- HOME_SHOW=ID, ID:SECONDS or ID@SEGMENT (tests, thumbnails): straight into an idle show at start.
ST.SHOW_NOW = os.getenv("HOME_SHOW")
-- The idle shows (shows.lua). The SCHEDULE card under SHOWS picks which plays when nobody is playing (kept in
-- the state file): AUTO follows the calendar (shows.pick), or one show only.
ST.SHOW_MODES = {"auto"}
ST.SHOW_NAMES = {auto = "AUTO"}
for _, sh in ipairs(shows.LIST) do
  if shows.available(sh.id) then ST.SHOW_MODES[#ST.SHOW_MODES + 1] = sh.id ST.SHOW_NAMES[sh.id] = sh.title end
end
ST.show_mode = "auto"
ST.AUTO_NIGHT_BLOCK = 1800
ST.HORIZON = 760

-- (trimmed as it goes: a line every 5 s is ~2 MB a day, and homeloop only trims it when Home starts again)
ST.LOG_MAX = tonumber(os.getenv("HOME_LOG_MAX") or "") or 131072

local function log(...)
  local s = table.concat({...}, " ")
  if ST.LOGF then
    local f = io.open(ST.LOGF, "a")
    if f then
      if not ST.log_size then ST.log_size = f:seek("end") or 0 end
      local line = string.format("%.2f %s\n", love.timer.getTime(), s)
      f:write(line)
      f:close()
      ST.log_size = ST.log_size + #line
      if ST.log_size > ST.LOG_MAX then
        os.rename(ST.LOGF, ST.LOGF .. ".1")
        ST.log_size = 0
      end
    end
  else
    print(s)
  end
end

-- The modules Home can live without (guard.lua): an error turns one off, not Home. HOME_SAFE=1 is homeloop's
-- safe mode (Home failed twice as it started): they start off, and Home is the classics, the Yard and the shows.
do
  local guard, safe = require("guard"), os.getenv("HOME_SAFE") == "1"
  if safe then log("SAFE MODE: Home failed twice as it started; the Longhorns, TV and the games card are off") end
  local none = function() return {} end
  guard(utgame, "longhorns", {status = none, games = none, now = function() return os.time() end,
                              countdown = function() return nil end}, log, safe)
  guard(tv, "tv", {channel_count = function() return 0, 0, 0 end, has_playlists = function() return false end,
                   update = function() return "exit" end, handle = function() return "exit" end}, log, safe)
  guard(shelf, "games card", {cards = none, arcade_games = none, legend_lines = none, count = function() return 0 end,
                              card_blurb = function() return "" end, commas = function(n) return tostring(n) end,
                              update = function() return "exit" end, handle = function() return "exit" end},
        log, safe)
end

-- An error: into the log, and quit (homeloop starts Home again; then safe mode; then the stock menu). LÖVE's own
-- handler would leave its error screen up for good on a cabinet with no keyboard.
function love.errorhandler(msg)
  log("ERROR: " .. debug.traceback(tostring(msg), 2))
  return nil
end

-- Tests only (HOME_REFACTOR.md, the characterization tour): HOME_NOW fixes "now" for os.time/os.date (the menu's
-- season, the shows' schedule), so a scripted run draws the same pixels every time; HOME_SEED fixes the seed below.
do
  local now = tonumber(os.getenv("HOME_NOW") or "")
  if now then
    local real_time, real_date = os.time, os.date
    os.time = function(t) if t then return real_time(t) end return now end
    os.date = function(f, t) return real_date(f, t or now) end
  end
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
-- The Yard games, from their own info.lua (cartinfo.lua): title, tint, blurb, stat line, as The Yard shows them.
local OURS = require("cartinfo").list(log)
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
                       title = g.title, sub = "THE YARD", blurb = g.blurb, tint = g.tint, statdef = g}
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
  local s = read_file(ST.GAMES .. "/" .. name)
  local t = {}
  for i = 1, 12 do t[i] = s and s:byte(i) or 0 end
  return t
end
local function cfg_write(name, t)
  local f = io.open(ST.GAMES .. "/" .. name, "wb")
  if not f then return end
  local b = {}
  for i = 1, 12 do b[i] = string.char(t[i] == 1 and 1 or 0) end
  f:write(table.concat(b))
  f:close()
end
ST.speed, ST.smooth = cfg_read("Speed.cfg"), cfg_read("Smoothing.cfg")

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
  local s = ST.speed[index + 1] == 1 and e.fast and read_file(ST.GAMES .. "/" .. e.fast .. ".sav")
  s = s or read_file(ST.GAMES .. "/" .. e[1] .. ".sav")
  if not s or #s < 3 then return nil end
  local ok, v = pcall(e[2], s)
  return ok and v > 0 and v < 100000000 and v or nil
end

-- ------------------------------------------------------------------ colors and drawing

-- rgb, fonts, neon labels, rrect: draw.lua (HOME_REFACTOR.md CP2)
local D = require("draw")
D.init(W)

-- An arcade board's best score, and its line on the info panel ("23,310  JRN").
function ST.arcade_best(it)
  local t = shelf.arcade_table(it.id)
  return t and t[1][1] or 0
end
function ST.arcade_score_text(it)
  local t = shelf.arcade_table(it.id)
  if not t or t[1][1] <= 0 then return nil end
  if t[1][3] then return shelf.commas(t[1][1]) .. "  (HOUSE)" end   -- (no player record yet: the house's to beat)
  return shelf.commas(t[1][1]) .. (t[1][2] ~= "" and ("  " .. t[1][2]) or "")
end
for _, it in ipairs(items) do
  if it.kind == "arcade" then it.table = shelf.arcade_table(it.id) it.score = ST.arcade_score_text(it) end
end

-- FAVORITES (favs.lua): the game played last, then the most played, as cards that launch straight away.
ST.favs = require("favs")
do
  local stats = ST.favs.credit(ST.STATE)
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





-- The brand: STARLIGHT in its script neon (a painted label, like any other).
ST.BRAND, ST.C, ST.ACCENT = "Starlight", 0xffd36b, 0x6ef0c8
function ST.draw(x, y, px, alpha, sc, align, width)
  D.face = "script"
  D.neon_draw(ST.BRAND, x or 0, y, px, ST.C, 1.5, align or "center", width or W, alpha, sc)
  D.face = "round"
end
function ST.img(px)
  D.face = "script"
  local e = D.neon_img(ST.BRAND, px, ST.C, 1.5)
  D.face = "round"
  return e
end

local play = sound.play

-- ------------------------------------------------------------------ input

-- The deck, the keys, the 1P/2P rules, the press queue, HOME_SCRIPT: input.lua (HOME_REFACTOR.md CP2)
local I = require("input")

-- ------------------------------------------------------------------ state

ST.sel, ST.pos = 1, 1
local t = 0
ST.frame = 0
-- HOME_TRACE=PATH (tools/show_review.py): what a show does, as it plays, one line an event: "<show secs> <kind> ..."
-- (act: the scene; music: the song; sfx: a sound; cam x y zoom, 10 a second; say/caption/plate: words shown).
ST.TRACE = os.getenv("HOME_TRACE") and io.open(os.getenv("HOME_TRACE"), "w")
ST.trace_t, ST.trace_seen = nil, {}
local function trace(kind, a, b, c)
  if kind == "t" then ST.trace_t = a return end
  local when = ST.trace_t or ST.frame / 60
  if kind == "parts" then
    if ST.frame % 30 ~= 0 then return end
    ST.TRACE:write(string.format("%.2f parts %d %d\n", when, a, b))
    return
  end
  if kind == "crowd" then
    if ST.frame % 6 ~= 0 then return end
    ST.TRACE:write(string.format("%.2f crowd %s\n", when, a))
    return
  end
  if kind == "cast" then
    if ST.frame % 6 ~= 0 then return end
    ST.TRACE:write(string.format("%.2f cast %.0f %.0f %.0f\n", when, a, b or 0, c or 0))
    return
  end
  if kind == "cam" then
    if ST.frame % 6 ~= 0 then return end
    ST.TRACE:write(string.format("%.2f cam %.0f %.0f %.3f\n", when, a, b, c))
    return
  end
  if kind == "say" or kind == "caption" or kind == "plate" then
    -- (words are drawn every frame: once, then again only after a second away)
    local k = kind .. a
    local last = ST.trace_seen[k]
    ST.trace_seen[k] = ST.frame
    if last and ST.frame - last < 60 then return end
  end
  ST.TRACE:write(string.format("%.2f %s %s\n", when, kind, tostring(a)))
  if kind == "act" or kind == "music" then ST.TRACE:flush() end
end
ST.scene = "intro"           -- intro, menu, attract, night, show (an idle show), shows (a show's tiles), tv
ST.intro_t = 0
ST.idle = 0
ST.attract_t = 0
ST.launch_t, ST.launch_item = 0, nil
ST.note, ST.note_t = nil, 0
ST.stars = {}
-- The living menu's world (tools/art/home.py): a painting a season, on the SD card; nil: the synthwave grid.
ST.WORLD_ART = (os.getenv("HOME_SHOW_ART") or "/mnt/sdcard/partycade/art") .. "/home"
function ST.world_load(name)
  if ST.world and ST.world_name == name then return end
  if ST.world then ST.world:release() ST.world = nil end
  ST.world_name = name
  home_note("world:" .. name)
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
ST.direct = not headless and os.getenv("HOME_CANVAS") ~= "1"


ST.vol_level, ST.vol_t, ST.vol_read = nil, 0, nil
ST.night_t = 0
-- (ST.cur_show, ST.cur_show_id) -- the idle show playing (its module; nil for the night sky), and its id
-- A show's start behind a curtain: the screen black while it sets up (its pictures, its labels: 300 ms and more
-- on the cabinet, which froze whatever was moving), its clock still until frames come smoothly, then a fade in.

-- The curtain's step: true when the show may run as usual this frame.
local function curtain_step(dt)
  local cu = ST.curtain
  if not cu then return true end
  cu.n = cu.n + 1
  if cu.phase == "cover" then
    if cu.n >= 2 then home_note("show start") ST.cur_show.start(cu.seed, cu.at) cu.phase, cu.n = "settle", 0 end
    return false
  elseif cu.phase == "settle" then
    ST.cur_show.update(0)                                      -- (its labels paint; its clock stays)
    cu.good = dt < 0.025 and cu.good + 1 or 0
    cu.held = (cu.held or 0) + dt
    -- (from idle: the NOW SHOWING card holds a moment, to be read)
    if (cu.good >= 8 or cu.n > 240) and (not cu.card or cu.held > 3.2) then cu.phase = "fade" end
    return false
  end
  cu.f = cu.f + dt
  if cu.f >= 0.4 then ST.curtain = nil end
  return true
end

local function curtain_draw()
  local cu = ST.curtain
  if not cu then return end
  local a = cu.phase == "fade" and math.max(0, 1 - cu.f / 0.6) or 1
  lg.setColor(0.02, 0.01, 0.05, a)
  lg.rectangle("fill", 0, 0, W, H)
  if cu.card then
    -- NOW SHOWING: the brand, the show's name in its own colour, what it is
    local sh = shows.BY_ID[cu.card]
    if sh then
      local k = math.min(1, (cu.held or 0) / 0.5) * a
      fx.glow(W / 2, 470, 360, 220, D.rgb(sh.tint, 0.18 * k))
      ST.draw(0, 250, 72, k)
      D.neon_draw("NOW SHOWING", 0, 380, 30, ST.ACCENT, 0.8, "center", W, k)
      local px = math.min(72, 64 * 620 / (D.font(64):getWidth(sh.title) + 20))
      D.neon_draw(sh.title, 0, 440, 64, sh.tint, 1.2, "center", W, k, px / 64)
      lg.setFont(D.font(26))
      lg.setColor(0.93, 0.9, 1, 0.9 * k)
      lg.printf(sh.blurb, 80, 560, W - 160, "center")
    end
  end
end
ST.auto_night_t = 0            -- AUTO: how long the night sky has had its turn
ST.menu_in = 0                 -- the menu fading in after the intro (seconds left)
-- (ST.attract_sel) -- the card before the attract tour: given back on waking
ST.returning = false           -- Home started again after a game (not at power-on)
-- (ST.celebrate) -- {score, title, tint, t}: back from a classic with a new high score
ST.party = 0                   -- party mode (the secret code): seconds left
ST.code_buf = {}
local CODE = {"up", "up", "down", "down", "left", "right", "left", "right", "tl", "low"}
-- (ST.last_played) -- the card of the last game played (state file)

-- The cards' neon titles (two pictures each, ~0.2 MB of GPU memory per card): painted for the cards near the
-- chosen one, given back for the far ones (all of them painted, Home's labels alone were most of its 12 MB of
-- pictures, and GPU memory is what this cabinet runs out of).
ST.labels_for, ST.labels_sel = {}, nil
local function title_labels(it)
  D.neon_img(it.title, 64, it.tint, 1.2)
  D.neon_img(it.title, 44, it.tint, 0.9)
end
local function neon_release(s, px, c, glow)
  local key = s .. "|" .. px .. "|" .. c .. "|" .. (glow or 1) .. (D.face == "script" and "|s" or "")
  local e = D.neon_cache[key]
  if e then e.img:release() D.neon_cache[key] = nil end
end
local function manage_labels(all_now)
  if ST.labels_sel == ST.sel then return end
  ST.labels_sel = ST.sel
  for k, it in ipairs(items) do
    local d = math.abs(k - ST.sel)
    if d <= 3 and not ST.labels_for[k] then
      ST.labels_for[k] = true
      if all_now or d <= 1 then title_labels(it)
      else D.label_jobs[#D.label_jobs + 1] = function() if ST.labels_for[k] then title_labels(it) end end end
    elseif d > 5 and ST.labels_for[k] then
      ST.labels_for[k] = nil
      neon_release(it.title, 64, it.tint, 1.2)
      neon_release(it.title, 44, it.tint, 0.9)
    end
  end
end

local function load_state()
  local s = ST.STATE and read_file(ST.STATE)
  local n = s and (item_by_key(s:match("selkey (%S+)") or "") or tonumber(s:match("sel (%d+)")))
  if n and items[n] then ST.sel, ST.pos = n, n end
  local sm = s and s:match("show (%a+)")
  if sm and ST.SHOW_NAMES[sm] then ST.show_mode = sm end
  local lp = s and (item_by_key(s:match("playedkey (%S+)") or "") or tonumber(s:match("played (%d+)")))
  if lp and items[lp] then ST.last_played = items[lp] end
  -- At power-on, never on the original menu's card (the last choice made before the power went off).
  if os.getenv("HOME_INTRO") == "1" and items[ST.sel].kind == "stock" then ST.sel, ST.pos = 1, 1 end
  -- Nothing played yet: start on the first real card (Pac-Man), not on the empty FAVORITES card.
  if items[ST.sel].kind == "favhint" then ST.sel, ST.pos = 2, 2 end
  return s and s:match("returned (.+)")
end
local function save_state(extra, played)
  if not ST.STATE then return end
  local lp = played
  if not lp and ST.last_played then
    for k, it in ipairs(items) do if it == ST.last_played then lp = k end end
  end
  local f = io.open(ST.STATE, "w")
  if f then
    f:write("sel " .. ST.sel .. "\nselkey " .. item_key(items[ST.sel]) .. "\n" ..
            (lp and ("played " .. lp .. "\nplayedkey " .. item_key(items[lp]) .. "\n") or "") ..
            "show " .. ST.show_mode .. "\n" .. (extra or ""))
    f:close()
  end
end

-- The classics' logos (cut from the stock menu by tools/home_art.py, on the cabinet only). The cards in view
-- are loaded at once; the rest are decoded by the worker and arrive over the first frames.

local function art_image(data)
  local ok, img = pcall(lg.newImage, data, {mipmaps = true})
  if not ok then return nil end
  img:setFilter("linear", "linear")
  img:setMipmapFilter("linear")
  return img
end
local function art_path(it) return ST.ART .. "/classic_" .. it.index .. ".png" end
local function load_art()
  for k, it in ipairs(items) do
    if it.kind == "classic" then
      if math.abs(k - ST.sel) <= 2 or not ST.worker then
        local b = read_file(art_path(it))
        if b then
          local ok, data = pcall(love.image.newImageData, love.filesystem.newFileData(b, "c.png"))
          if ok then
            if it.art then it.art:release() end
            it.art = art_image(data)
            pcall(function() data:release() end)
          end
        end
      else
        love.thread.getChannel("home_work"):push({"art", k, art_path(it)})
      end
    elseif it.kind == "arcade" or it.kind == "game" then
      -- The board's title screen, from the card (decoded on the worker; the reply sets it.shot). Only the cards
      -- near the chosen one: all of them at once, with the browser's box art, ran Home out of memory.
      if it.game.art and not it.shot and not it.asked and math.abs(k - ST.sel) <= 3 then
        it.asked = true
        if ST.worker then love.thread.getChannel("home_work"):push({"art", k, it.game.art})
        else
          local b = read_file(it.game.art)
          local ok, data = pcall(function() return love.image.newImageData(love.filesystem.newFileData(b, "a.png")) end)
          if ok then
            it.shot = art_image(data)
            pcall(function() data:release() end)
          end
        end
      end
    elseif it.id and not it.shot and (math.abs(k - ST.sel) <= 2 or not ST.worker) and love.filesystem.getInfo("art/" .. it.id .. ".png") then
      -- Our games: a frame of the game itself (cart shots), packed into home.love (loaded near sel).
      it.shot = lg.newImage("art/" .. it.id .. ".png")
      it.shot:setFilter("linear", "linear")
    end
  end
end

-- ------------------------------------------------------------------ drawing

-- menu.lua (HOME_REFACTOR.md CP4)
local MENU = require("menu")({D = D, H = H, I = I, LEAVE = LEAVE,
  SECTIONS = SECTIONS, ST = ST, W = W, curtain_draw = curtain_draw, fx = fx, items = items,
  lg = lg, night = night, shelf = shelf, shows = shows, t = t, tv = tv})

-- ------------------------------------------------------------------ the pictures between programs

-- "Get ready", "welcome back", power-on: pictures.lua (HOME_REFACTOR.md CP2)
local P = require("pictures")
P.init({W = W, draw_background = MENU.draw_background, ST = ST, shelf = shelf, fx = fx, LEAVE = LEAVE, splash = splash,
        BACK = ST.BACK, uptime = uptime, log = log})

-- ------------------------------------------------------------------ actions

-- actions.lua (HOME_REFACTOR.md CP4)
local A = require("actions")
A.init({CODE = CODE, P = P, SECTIONS = SECTIONS, ST = ST, cfg_write = cfg_write,
        headless = headless, high_score = high_score, items = items, log = log, play = play, read_file = read_file,
        save_state = save_state, splash = splash})

-- ------------------------------------------------------------------ the idle shows

-- idle.lua (HOME_REFACTOR.md CP4)
local IDLE = require("idle")({A = A, D = D, ST = ST, cfg_write = cfg_write,
  high_score = high_score, items = items, lg = lg, load_art = load_art, log = log, manage_labels = manage_labels,
  night = night, play = play, save_state = save_state, shelf = shelf, shows = shows, t = t,
  tv = tv, utgame = utgame})

-- ------------------------------------------------------------------ the loop

-- The TV guide's and the Shelf's drawing helpers, and coming back from one of their programs. (Out of
-- love.load: LuaJIT allows a function 60 upvalues.)
local function shelf_setup()
  ST.hall.load({W = W, H = H, font = D.font, neon_draw = D.neon_draw, rgb = D.rgb, rrect = D.rrect, fx = fx, play = play,
                down = I.down, commas = shelf.commas,
                entries = function()
                  local out = {}
                  for k, it in ipairs(items) do
                    if it.kind == "arcade" then
                      it.table = shelf.arcade_table(it.id)
                      out[#out + 1] = {title = it.title, tint = it.tint, item = it, rows = it.table,
                                       launch = function() ST.sel, ST.pos = k, k ST.scene = "menu" ST.launch_item = it ST.launch_t = 0 end}
                    elseif it.kind == "classic" and it.score then
                      out[#out + 1] = {title = it.title, tint = it.tint, item = it, classic = true,
                                       rows = {{tonumber(it.score) or 0, "", false}},
                                       launch = function() ST.sel, ST.pos = k, k ST.scene = "menu" ST.launch_item = it ST.launch_t = 0 end}
                    end
                  end
                  return out
                end})
  ST.initials.load({W = W, H = H, font = D.font, neon_draw = D.neon_draw, rgb = D.rgb, rrect = D.rrect, fx = fx, play = play,
                    down = I.down, commas = shelf.commas,
                    done = function(it, score, initials)
                      shelf.save_name(it.id, score, initials)
                      it.table = shelf.arcade_table(it.id)
                      it.score = ST.arcade_score_text(it)
                      ST.celebrate = {score = shelf.commas(score), title = it.title .. "   ·   " .. initials, tint = it.tint, t = 0}
                      log("initials " .. it.id .. " " .. score .. " " .. initials)
                    end})
  -- Back from an arcade board with a better score than it had: the classics' celebration, with the initials.
  do
    local st = ST.STATE and read_file(ST.STATE) or ""
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
            ST.scene = "initials"
          else
            ST.celebrate = {score = shelf.commas(t[1][1]), title = it.title .. "   ·   " .. t[1][2], tint = it.tint, t = 0}
          end
        end
      end
    end
  end
  -- Live TV: the guide's lists, and coming back from a channel (tvloop wrote how it ended).
  tv.load({W = W, H = H, font = D.font, neon_draw = D.neon_draw, rgb = D.rgb, rrect = D.rrect, fx = fx, play = play,
           log = log, down = I.down, backdrop = P.backdrop,
           request = function(s, picture) A.request(s, nil, picture) end,
           save_picture = function(path, picture)
             if headless and not os.getenv("HOME_FB") then return end
             local ok, bytes = pcall(splash.render, picture)
             if ok then splash.save(bytes, path, true) end
           end})
  shelf.load({W = W, H = H, font = D.font, neon_draw = D.neon_draw, rgb = D.rgb, rrect = D.rrect, fx = fx, play = play,
              log = log, down = I.down, backdrop = P.backdrop,
              request_art = ST.worker and function(key, path) love.thread.getChannel("home_work"):push({"art", key, path}) end,
              request = function(s, picture, key) A.request(s, nil, picture, key) end})
  do
    -- Back from a game on the Shelf: the browser, on that game.
    local key, file, failed = shelf.returning()
    if key then
      for k, it in ipairs(items) do if it.kind == "shelf" and (it.row == key or (key == "recent" and it.row)) then ST.sel, ST.pos = k, k break end end
      ST.shelf_open(key, file, failed)
      ST.returning = true
    end
  end
end

function love.load()
  mark("love.load")
  love.mouse.setVisible(false)
  local fd = love.filesystem.getInfo("fonts/Fredoka-SemiBold.ttf") and love.filesystem.newFileData("fonts/Fredoka-SemiBold.ttf")
  D.font_data = fd
  D.script_data = love.filesystem.getInfo("fonts/Pacifico-Starlight.ttf") and love.filesystem.newFileData("fonts/Pacifico-Starlight.ttf")
  math.randomseed(ST.RENDER and 1 or tonumber(os.getenv("HOME_SEED") or "") or os.time())   -- (RENDER: the PC-rendered picture is the same every build)
  for i = 1, 90 do
    ST.stars[i] = {math.random() * W, math.random() * 700, math.random() * 6, 0.5 + math.random() * 2,
                0.4 + math.random() * 0.6, math.random() < 0.15 and 3 or 2}
  end
  fx.load()
  night.load({W = W, H = H, HORIZON = ST.HORIZON, font = D.font, neon_draw = D.neon_draw, fx = fx, log = log})
  music.log = log
  if not ST.RENDER then utgame.start(log) end
  local show_ctx = {W = W, H = H, font = D.font, neon_draw = D.neon_draw, neon_img = D.neon_img, neon_release = neon_release,
                    brand_draw = function(y, px, a) ST.draw(0, y, px, a) end,
                    fx = fx, sfx = music.sfx,
                    log = log, rgb = D.rgb}
  if ST.TRACE then
    D.trace_font = function(px) trace("font", px) end
    show_ctx.trace = trace
    show_ctx.sfx = function(name, gain) trace("sfx", name) music.sfx(name, gain) end
  end
  for _, sh in ipairs(shows.LIST) do
    local m = shows.module(sh.id)
    if m then m.load(show_ctx) end
  end
  if ST.RENDER then
    -- Render a picture and quit (the PC build of the power-on picture): "boot:PATH".
    local kind, path = ST.RENDER:match("^(%a+):(.+)$")
    ST.world_load("base")
    local bytes = splash.render(kind == "back" and P.picture_back or P.picture_boot)
    splash.save(bytes, path, path:match("%.gz$") ~= nil)
    love.event.quit(0)
    return
  end
  load_state()
  if love.thread then
    ST.worker = love.thread.newThread("worker.lua")
    ST.worker:start()
    -- (the music: its own thread, music.lua, started after the first frame)
  end
  load_art()
  mark("art")
  -- The labels in view now; the rest a few a frame, before the frame's drawing starts (see neon_img).
  ST.world_load(ST.world_want)
  ST.img(96)
  if ST.scene == "intro" or os.getenv("HOME_INTRO") == "1" then D.neon_img("ARCADE  ·  SHOWS  ·  TV", 34, ST.ACCENT, 0.8) end
  manage_labels(false)
  D.label_jobs[#D.label_jobs + 1] = function() D.neon_img("PRESS ANY BUTTON", 44, 0xffd23f, 1) end
  D.label_jobs[#D.label_jobs + 1] = function() D.neon_img("NEW HIGH SCORE!", 44, 0xffd23f, 1) end
  lg.setCanvas()
  mark("labels")
  sound.load()
  mark("sounds")
  local returned = load_state()
  if returned and returned:match("failed") then
    ST.note, ST.note_t = "That one didn't start. Pick another?", 4
  end
  do
    local st = ST.STATE and read_file(ST.STATE) or ""
    local idx, before = st:match("score (%d+) (%d+)")
    idx, before = tonumber(idx), tonumber(before)
    local now = idx and high_score(idx)
    if now and before and now > before and os.getenv("HOME_INTRO") ~= "1" then
      ST.celebrate = {score = now, title = CLASSICS[idx + 1].title, tint = CLASSICS[idx + 1].tint, t = 0}
      log("new high score " .. idx .. " " .. before .. " -> " .. now)
    end
  end
  if os.getenv("HOME_INTRO") ~= "1" and (os.getenv("HOME_SKIP_INTRO") == "1" or (ST.STATE and read_file(ST.STATE))) then
    ST.scene = "menu"       -- the intro is for power-on; coming back from a game goes straight to the menu
    ST.returning = ST.STATE ~= nil and read_file(ST.STATE) ~= nil and os.getenv("HOME_INTRO") ~= "1"
  else
    play("intro")
  end
  shelf_setup()
  ST.shows_ctx = {request_art = ST.worker and function(key, path)
                 love.thread.getChannel("home_work"):push({"art", key, path})
               end or nil, backdrop = P.backdrop, rgb = D.rgb, neon_draw = D.neon_draw, font = D.font, fx = fx, rrect = D.rrect, play = play}
  shows.set_ctx(ST.shows_ctx)
  for k, it in ipairs(items) do
    if it.kind == "tv" then
      local n, g, p = tv.channel_count()
      if n > 0 then
        it.blurb = p == 1 and string.format("%d groups from the Pink TV household. What the TVs are watching is at the top.", g)
                   or string.format("%d channels in %d groups, from %d playlists.", n, g, p)
      end
      if not tv.has_playlists() then it.blurb = "No TV playlists on this cabinet yet." end
    end
  end
  do
    local rc, idx = tv.returning()
    if rc then
      for k, it in ipairs(items) do if it.kind == "tv" then ST.sel, ST.pos = k, k end end
      if rc ~= 10 then
        ST.scene = "tv"
        tv.enter(rc, idx)
      else
        ST.scene = "menu"
      end
      ST.returning = true
    end
  end
  IDLE.show_card()
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
  if ST.SHOW_NOW then
    -- tests: straight into a show (ID, ID:SECONDS, ID@SEGMENT)
    local id, how, n = ST.SHOW_NOW:match("^(%a+)([:@]?)(%d*)$")
    if id and shows.available(id) then
      if how == "@" then IDLE.play_show(id, tonumber(n))
      else
        IDLE.play_show(id)
        if how == ":" and ST.curtain then ST.curtain.at = tonumber(n) ST.curtain.seed = 1 end
      end
    end
  end
  A.read_volume()
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
    if d then
      it.stat = require("cartinfo").stat(d, read_file(ST.GAMES .. "/" .. d.save .. ".sav"))
      log("yard card " .. it.id .. ": " .. it.title .. (it.stat and (" / " .. it.stat) or ""))
    end
  end
  -- Back from a game: a soft welcome (the celebration has its own fanfare).
  if ST.returning and not ST.celebrate then play("back") end
  if headless or not ST.direct then ST.canvas = lg.newCanvas(W, H) end
  log("home start, " .. #items .. " items, scene " .. ST.scene)
end

-- The worker waits for jobs: tell it to stop, so LÖVE's exit does not wait on it.
function love.quit()
  if ST.worker then love.thread.getChannel("home_work"):push({"quit"}) end
  tv.quit()
  shelf.quit()
  music.quit()
  return false
end

-- The song for what is on the screen (songs.lua; the night has one for each of its scenes), and its volume.
local NIGHT_SONG = {dusk = "dusk", quiet = "quiet", rest = "none", dawn = "dawn"}
local music_vol
local function music_tick()
  if ST.scene == "intro" then return end
  local want, vol, fade = "menu", 0.32, 1.2
  if ST.scene == "night" then
    local sc = night.scene_at(ST.night_t * ST.NIGHT_SPEED)
    want, vol, fade = NIGHT_SONG[sc] or sc, 0.26, 3
  elseif ST.scene == "show" and ST.cur_show then
    -- (behind the curtain, before the show has started, it isn't asked: silence until it has)
    if ST.curtain and ST.curtain.phase == "cover" then return end
    want, vol, fade = ST.cur_show.music(), 0.42, 2
    if ST.TRACE then
      if ST.cur_show.clock then trace("t", ST.cur_show.clock()) end
      if want ~= ST.trace_seen.music then ST.trace_seen.music = want trace("music", want) end
      local act = ST.cur_show.act and ST.cur_show.act()
      if act ~= ST.trace_seen.act then ST.trace_seen.act = act trace("act", act) end
    end
  elseif ST.scene == "tv" or ST.scene == "shelf" then want = "tv"
  elseif ST.scene == "attract" then want = "attract" end
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
  if cards_t <= 0 then cards_t = 30 IDLE.update_cards() end
  if ST.scene == "tv" then
    ST.idle = 0
    if tv.update(dt) == "exit" then ST.scene = "menu" end
  end
  if ST.scene == "shelf" then
    ST.idle = 0
    if shelf.update(dt) == "exit" then ST.shelf_close() end
  end
  if ST.scene == "initials" then
    ST.idle = 0
    if ST.initials.update(dt) == "done" then ST.scene = "menu" end
  end
  if ST.scene == "hall" then
    ST.idle = 0
    if ST.hall.update(dt) == "exit" then ST.scene = "menu" ST.near_sel = nil end
  end
  ST.idle = ST.idle + dt
  if ST.scene == "menu" and ST.idle > ST.IDLE_ATTRACT then ST.scene = "attract" ST.attract_t = 0 ST.attract_sel = ST.sel end
  if ST.scene == "attract" then
    ST.attract_t = ST.attract_t + dt
    if ST.attract_t > 3.5 then ST.attract_t = 0 ST.sel = ST.sel % #items + 1 end
    if ST.idle > ST.IDLE_NIGHT then IDLE.start_show() end
  end
  if ST.scene == "night" then
    ST.night_t = ST.night_t + dt
    ST.auto_night_t = ST.auto_night_t + dt
    -- AUTO: the night sky has had its half hour (or the Longhorns kick off): the calendar's show.
    if ST.show_mode == "auto" and not ST.demo and (ST.auto_night_t > ST.AUTO_NIGHT_BLOCK or ST.game_now.window) then
      local id = shows.pick(os.time(), ST.game_now, ST.auto_rot)
      if id ~= "night" then ST.auto_rot = ST.auto_rot + 1 IDLE.play_show(id) else ST.auto_night_t = 0 end
    end
  end
  if ST.scene == "show" and ST.cur_show then
    ST.idle = 0
    if curtain_step(dt) and ST.cur_show.update(dt) then
      if os.getenv("HOME_SHOW_ONCE") then love.event.quit(0) return end   -- (tools/show_lint.py)
      -- The show is over: its tiles again (watching one), the same show (one show only), or the night sky's
      -- turn (AUTO; the Longhorns go on while the game is on).
      if ST.demo then IDLE.open_tiles(ST.demo)
      elseif ST.show_mode ~= "auto" then IDLE.play_show(ST.show_mode)
      elseif ST.cur_show_id == "longhorns" and ST.game_now.window then IDLE.play_show("longhorns")
      else IDLE.play_show("night") end
    end
  end
  if ST.scene == "shows" then
    shows.update(dt)
    if ST.idle > ST.IDLE_NIGHT then shows.close() IDLE.start_show() end
  end
  music_tick()
end

local fps_t, fps_n = 0, 0
local last_letters = 0
local FIXED_DT = tonumber(os.getenv("HOME_DT") or "")   -- tests: every frame this long (PC renders of the shows)
local FPS_EVERY = tonumber(os.getenv("HOME_FPS_EVERY") or "") or 300   -- the frames line: every this many frames
local hitches = 0
-- What a frame did that can take time (SYSTEM_AUDIT.md B2): the loaders note it (home_note, a global so the
-- modules reach it), and a hitch is logged with the notes of the frame it happened in. Home's log had stalls of
-- 5 to 46 s with nothing saying what was being done.
ST.notes = {}
function home_note(s)
  local n = ST.notes
  if #n < 6 then n[#n + 1] = s end
end
function love.update(dt)
  if FIXED_DT then dt = FIXED_DT end
  -- a frame that took too long (a hitch you can see): logged with what was going on, the first 300 a run
  if dt > 0.045 and ST.frame > 10 and hitches < 300 then
    hitches = hitches + 1
    local avail = ""
    if dt > 0.25 then
      local mi = io.open("/proc/meminfo")
      local m = mi and mi:read("*a") or ""
      if mi then mi:close() end
      avail = ", available " .. (m:match("MemAvailable:%s*(%d+)") or "?") .. " kB"
    end
    log(string.format("hitch %d ms, scene %s%s, music %s, lua %d KB%s%s", dt * 1000, ST.scene,
                      ST.cur_show and ST.cur_show.act and (" " .. tostring(ST.cur_show_id) .. ":" .. tostring(ST.cur_show.act())) or "",
                      tostring(music.now), collectgarbage("count"), avail,
                      #ST.notes > 0 and (", did " .. table.concat(ST.notes, " ")) or ""))
  end
  for i = #ST.notes, 1, -1 do ST.notes[i] = nil end
  fps_t, fps_n = fps_t + dt, fps_n + 1
  if fps_n == FPS_EVERY then
    local st = lg.getStats()
    log(string.format("frames: %.1f fps (%.2f ms), scene %s, lua %d KB, textures %d KB (%d), draws %d", fps_n / fps_t,
                      fps_t / fps_n * 1000, ST.scene, collectgarbage("count"), st.texturememory / 1024, st.images + st.canvases,
                      st.drawcalls))
    fps_t, fps_n = 0, 0
  end
  dt = math.min(dt, 0.1)
  t = t + dt
  MENU.sync_t(t)
  IDLE.sync_t(t)
  ST.frame = ST.frame + 1
  if ST.frame == 3 and not headless then music.start() end
  utgame.update(dt)
  if ST.frame % 60 == 0 then ST.game_now = utgame.status() end
  local merr = music.check()
  if merr then log("music: " .. merr) end
  if ST.worker then
    -- At most 2 GPU texture uploads per frame so waking from idle never spikes Mali memory or hitches.
    local n_up = 0
    while n_up < 2 do
      local msg = love.thread.getChannel("home_done"):pop()
      if not msg then break end
      n_up = n_up + 1
      home_note("upload:" .. tostring(msg[2]))
      if msg[1] == "art" and type(msg[2]) == "string" and msg[2]:sub(1, 6) == "shelf:" then
        if msg[3] then shelf.art_ready(msg[2], msg[3]) else shelf.art_failed(msg[2]) end
      elseif msg[1] == "art" and type(msg[2]) == "string" then
        if msg[3] then shows.thumb_ready(msg[2], msg[3]) end
      elseif msg[1] == "art" and msg[3] then
        if not ST.menu_freed then
          local it = items[msg[2]]
          if it then
            if it.kind == "arcade" or it.kind == "game" then
              if it.shot then it.shot:release() end
              it.shot = art_image(msg[3])
            else
              if it.art then it.art:release() end
              it.art = art_image(msg[3])
            end
          end
        end
        pcall(function() msg[3]:release() end)   -- (always release decoded ImageData, even if menu_freed)
      end
    end
    local err = ST.worker:getError()
    if err then log("worker: " .. err) ST.worker = nil end
  end
  for _, c in ipairs(I.script) do
    if c[1] == ST.frame then
      if c[2] == "press" then I.control_down(c[3]) I.control_up(c[3])
      elseif c[2] == "down" then I.control_down(c[3])
      elseif c[2] == "up" then I.control_up(c[3])
      elseif c[2] == "shot" then ST.shot_req = c[3]
      elseif c[2] == "quit" then love.event.quit(0) end
    end
  end
  for _, n in ipairs(I.pressed_q) do IDLE.handle(n) end
  I.pressed_q = {}
  if not ST.menu_freed then manage_labels(false) end
  if PREVIEW and I.down["1p"] and I.down["2p"] and not ST.launch_item then
    I.hold_t = I.hold_t + dt
    ST.idle = 0
    if I.hold_t >= I.HOLD_SECS then I.hold_t = 0 A.request("yard") end
  else
    I.hold_t = 0
  end
  if ST.scene == "intro" then
    ST.intro_t = ST.intro_t + dt
    if ST.intro_t > 0.9 and not ST.stung then ST.stung = true music.sfx("sting", 0.9) end
    local letters = math.floor(math.min(1, ST.intro_t / 1.2) * 9 + 0.001)
    if letters > last_letters then last_letters = letters play("tick") end
    if ST.intro_t > MENU.INTRO_LEN then ST.scene = "menu" ST.menu_in = 0.45 end
  end
  update_idle(dt)
  fx.update(dt, ST.scene == "menu" or ST.scene == "attract" or ST.scene == "night")
  if ST.vol_t > 0 then ST.vol_t = ST.vol_t - dt end
  if ST.menu_in > 0 then ST.menu_in = math.max(0, ST.menu_in - dt) end
  if ST.party > 0 then ST.party = math.max(0, ST.party - dt) end
  if ST.celebrate then
    if ST.celebrate.t == 0 then play("fanfare") ST.confetti = nil end
    ST.celebrate.t = ST.celebrate.t + dt
    if ST.celebrate.t > 5 then ST.celebrate = nil end
  end
  if ST.vol_read then
    ST.vol_read = ST.vol_read - dt
    if ST.vol_read <= 0 then ST.vol_read = nil A.read_volume() end
  end
  ST.pos = ST.pos + (ST.sel - ST.pos) * math.min(1, dt * 11)
  if ST.scene ~= "hall" then ST.near_shots() end
  if ST.note then ST.note_t = ST.note_t - dt if ST.note_t <= 0 then ST.note = nil end end
  if ST.launch_item then
    ST.launch_t = ST.launch_t + dt
    if ST.launch_t > 0.6 then
      local it = ST.launch_item
      local s = A.launch(it)
      ST.launch_item = nil
      A.request(s, it)
    end
  end
end

local first_drawn = false
function love.draw()
  -- Labels still to paint: two a frame, before anything is drawn on the screen.
  for _ = 1, 2 do
    local job = table.remove(D.label_jobs, 1)
    if job then job() lg.setCanvas() end
  end
  if not first_drawn then
    first_drawn = true
    mark("first frame")
    local parts = {}
    for i, m in ipairs(marks) do parts[i] = string.format("%s %.2f", m[1], m[2]) end
    log("startup: " .. table.concat(parts, ", "))
  end
  if ST.canvas then
    lg.setCanvas(ST.canvas)
    lg.clear(0, 0, 0, 1)
    lg.origin()
    MENU.draw_scene()
    lg.setCanvas()
    if ST.shot_req then
      -- (straight to the file: two test runs at once would share a "shot.png" in the save directory)
      local d = ST.canvas:newImageData():encode("png"):getString()
      local f = io.open(ST.shot_req, "wb")
      if f then f:write(d) f:close() end
      if ST.TRACE then trace("shot", ST.shot_req) end
      ST.shot_req = nil
    end
    if not headless then
      lg.origin()
      local ww, wh = lg.getDimensions()
      lg.setColor(1, 1, 1, 1)
      lg.draw(ST.canvas, ww / 2, wh / 2, -math.pi / 2, 1, 1, W / 2, H / 2)
    end
  else
    -- Straight onto the framebuffer, turned (as GPU yard does: the canvas cost a whole extra pass).
    local ww, wh = lg.getDimensions()
    lg.origin()
    lg.translate(ww / 2, wh / 2)
    lg.rotate(-math.pi / 2)
    lg.translate(-W / 2, -H / 2)
    MENU.draw_scene()
  end
end
