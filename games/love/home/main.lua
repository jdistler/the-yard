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
-- Every change of scene goes through here (HOME_REFACTOR.md CP5): one place for what a scene needs on entering
-- or leaving; for now it notes the change for the hitch log (home_note).
function ST.go(name)
  if ST.scene ~= name and home_note then home_note("scene:" .. name) end
  ST.scene = name
end

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

-- rgb, fonts, neon labels, rrect: draw.lua (HOME_REFACTOR.md CP2)
local D = require("draw")
D.init(W)
local play = sound.play

-- ------------------------------------------------------------------ the games

-- catalog.lua (HOME_REFACTOR.md CP4)
local CAT = require("catalog")({ST = ST, log = log, read_file = read_file, shelf = shelf,
  shows = shows})

-- ------------------------------------------------------------------ the cards

-- cards.lua (HOME_REFACTOR.md CP4)
require("cards")({CAT = CAT, D = D, ST = ST, W = W,
  shelf = shelf})

-- ------------------------------------------------------------------ input

-- The deck, the keys, the 1P/2P rules, the press queue, HOME_SCRIPT: input.lua (HOME_REFACTOR.md CP2)
local I = require("input")

local t = 0                       -- the frame clock (seconds): the loop's; modules get it by sync_t

-- ------------------------------------------------------------------ state

-- homestate.lua (HOME_REFACTOR.md CP4)
local HS = require("homestate")({CAT = CAT, D = D, H = H, ST = ST,
  W = W, fx = fx, headless = headless, lg = lg, read_file = read_file, shows = shows, shelf = shelf, log = log})

-- ------------------------------------------------------------------ drawing

-- menu.lua (HOME_REFACTOR.md CP4)
local MENU = require("menu")({D = D, H = H, I = I, LEAVE = CAT.LEAVE,
  SECTIONS = CAT.SECTIONS, ST = ST, W = W, curtain_draw = HS.curtain_draw, fx = fx, items = CAT.items,
  lg = lg, night = night, shelf = shelf, shows = shows, t = t, tv = tv})

-- ------------------------------------------------------------------ the pictures between programs

-- "Get ready", "welcome back", power-on: pictures.lua (HOME_REFACTOR.md CP2)
local P = require("pictures")
P.init({W = W, draw_background = MENU.draw_background, ST = ST, shelf = shelf, fx = fx, LEAVE = CAT.LEAVE, splash = splash,
        BACK = ST.BACK, uptime = uptime, log = log})

-- ------------------------------------------------------------------ actions

-- actions.lua (HOME_REFACTOR.md CP4)
local A = require("actions")
A.init({CODE = HS.CODE, P = P, SECTIONS = CAT.SECTIONS, ST = ST, cfg_write = CAT.cfg_write,
        headless = headless, high_score = CAT.high_score, items = CAT.items, log = log, play = play, read_file = read_file,
        save_state = HS.save_state, splash = splash})

-- ------------------------------------------------------------------ the idle shows

-- idle.lua (HOME_REFACTOR.md CP4)
local IDLE = require("idle")({A = A, D = D, ST = ST, cfg_write = CAT.cfg_write,
  high_score = CAT.high_score, items = CAT.items, lg = lg, load_art = HS.load_art, log = log, manage_labels = HS.manage_labels,
  night = night, play = play, save_state = HS.save_state, shelf = shelf, shows = shows, t = t,
  tv = tv, utgame = utgame})

-- ------------------------------------------------------------------ the loop

-- The TV guide's and the Shelf's drawing helpers, and coming back from one of their programs. (Out of
-- love.load: LuaJIT allows a function 60 upvalues.)
local function shelf_setup()
  ST.hall.load({W = W, H = H, font = D.font, neon_draw = D.neon_draw, rgb = D.rgb, rrect = D.rrect, fx = fx, play = play,
                down = I.down, commas = shelf.commas,
                entries = function()
                  local out = {}
                  for k, it in ipairs(CAT.items) do
                    if it.kind == "arcade" then
                      it.table = shelf.arcade_table(it.id)
                      out[#out + 1] = {title = it.title, tint = it.tint, item = it, rows = it.table,
                                       launch = function() ST.sel, ST.pos = k, k ST.go("menu") ST.launch_item = it ST.launch_t = 0 end}
                    elseif it.kind == "classic" and it.score then
                      out[#out + 1] = {title = it.title, tint = it.tint, item = it, classic = true,
                                       rows = {{tonumber(it.score) or 0, "", false}},
                                       launch = function() ST.sel, ST.pos = k, k ST.go("menu") ST.launch_item = it ST.launch_t = 0 end}
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
    for _, it in ipairs(CAT.items) do
      if it.kind == "arcade" and it.id == set and before and os.getenv("HOME_INTRO") ~= "1" then
        local t = shelf.arcade_table(it.id)
        if t and t[1][1] > before then
          log("new arcade high score " .. set .. " " .. before .. " -> " .. t[1][1] .. " " .. t[1][2])
          if t[1][2] == "" then
            -- The board asked for no initials: Home does (initials.lua), then celebrates.
            ST.initials.start(it, t[1][1])
            ST.go("initials")
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
           request = function(s, picture) A.request(s, nil, picture) end})
  shelf.load({W = W, H = H, font = D.font, neon_draw = D.neon_draw, rgb = D.rgb, rrect = D.rrect, fx = fx, play = play,
              log = log, down = I.down, backdrop = P.backdrop,
              request_art = ST.worker and function(key, path) love.thread.getChannel("home_work"):push({"art", key, path}) end,
              request = function(s, picture, key) A.request(s, nil, picture, key) end})
  do
    -- Back from a game on the Shelf: the browser, on that game.
    local key, file, failed = shelf.returning()
    if key then
      for k, it in ipairs(CAT.items) do if it.kind == "shelf" and (it.row == key or (key == "recent" and it.row)) then ST.sel, ST.pos = k, k break end end
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
  local show_ctx = {W = W, H = H, font = D.font, neon_draw = D.neon_draw, neon_img = D.neon_img, neon_release = HS.neon_release,
                    brand_draw = function(y, px, a) ST.draw(0, y, px, a) end,
                    fx = fx, sfx = music.sfx,
                    log = log, rgb = D.rgb}
  if ST.TRACE then
    D.trace_font = function(px) HS.trace("font", px) end
    show_ctx.trace = HS.trace
    show_ctx.sfx = function(name, gain) HS.trace("sfx", name) music.sfx(name, gain) end
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
  HS.load_state()
  if love.thread then
    ST.worker = love.thread.newThread("worker.lua")
    ST.worker:start()
    -- (the music: its own thread, music.lua, started after the first frame)
  end
  HS.load_art()
  mark("art")
  -- The labels in view now; the rest a few a frame, before the frame's drawing starts (see neon_img).
  ST.world_load(ST.world_want, true)   -- (here, not in the worker: the first frame shows it)
  ST.img(96)
  if ST.scene == "intro" or os.getenv("HOME_INTRO") == "1" then D.neon_img("ARCADE  ·  SHOWS  ·  TV", 34, ST.ACCENT, 0.8) end
  HS.manage_labels(false)
  D.label_jobs[#D.label_jobs + 1] = function() D.neon_img("PRESS ANY BUTTON", 44, 0xffd23f, 1) end
  D.label_jobs[#D.label_jobs + 1] = function() D.neon_img("NEW HIGH SCORE!", 44, 0xffd23f, 1) end
  lg.setCanvas()
  mark("labels")
  sound.load()
  mark("sounds")
  local returned = HS.load_state()
  if returned and returned:match("failed") then
    ST.note, ST.note_t = "That one didn't start. Pick another?", 4
  end
  do
    local st = ST.STATE and read_file(ST.STATE) or ""
    local idx, before = st:match("score (%d+) (%d+)")
    idx, before = tonumber(idx), tonumber(before)
    local now = idx and CAT.high_score(idx)
    if now and before and now > before and os.getenv("HOME_INTRO") ~= "1" then
      ST.celebrate = {score = now, title = CAT.CLASSICS[idx + 1].title, tint = CAT.CLASSICS[idx + 1].tint, t = 0}
      log("new high score " .. idx .. " " .. before .. " -> " .. now)
    end
  end
  if os.getenv("HOME_INTRO") ~= "1" and (os.getenv("HOME_SKIP_INTRO") == "1" or (ST.STATE and read_file(ST.STATE))) then
    ST.go("menu")       -- the intro is for power-on; coming back from a game goes straight to the menu
    ST.returning = ST.STATE ~= nil and read_file(ST.STATE) ~= nil and os.getenv("HOME_INTRO") ~= "1"
  else
    play("intro")
  end
  shelf_setup()
  ST.shows_ctx = {request_art = ST.worker and function(key, path)
                 love.thread.getChannel("home_work"):push({"art", key, path})
               end or nil, backdrop = P.backdrop, rgb = D.rgb, neon_draw = D.neon_draw, font = D.font, fx = fx, rrect = D.rrect, play = play}
  shows.set_ctx(ST.shows_ctx)
  for k, it in ipairs(CAT.items) do
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
      for k, it in ipairs(CAT.items) do if it.kind == "tv" then ST.sel, ST.pos = k, k end end
      if rc ~= 10 then
        ST.tv_open(rc, idx)
      else
        ST.go("menu")
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
  for _, it in ipairs(CAT.items) do
    if it.kind == "classic" then
      it.score = CAT.high_score(it.index)
      sc[#sc + 1] = it.index .. "=" .. tostring(it.score)
    end
  end
  log("high scores: " .. table.concat(sc, " "))
  -- Our games: their save's number, as The Yard shows it.
  for _, it in ipairs(CAT.items) do
    local d = it.statdef
    if d then
      it.stat = require("cartinfo").stat(d, read_file(ST.GAMES .. "/" .. d.save .. ".sav"))
      log("yard card " .. it.id .. ": " .. it.title .. (it.stat and (" / " .. it.stat) or ""))
    end
  end
  -- Back from a game: a soft welcome (the celebration has its own fanfare).
  if ST.returning and not ST.celebrate then play("back") end
  if headless or not ST.direct then ST.canvas = lg.newCanvas(W, H) end
  log("home start, " .. #CAT.items .. " items, scene " .. ST.scene)
end

-- The worker waits for jobs: tell it to stop, so LÖVE's exit does not wait on it.
function love.quit()
  if ST.worker then love.thread.getChannel("home_work"):push({"quit"}) end
  tv.quit()
  shelf.quit()
  music.quit()
  return false
end

-- ------------------------------------------------------------------ the ticks

-- ticks.lua (HOME_REFACTOR.md CP4)
local TICK = require("ticks")({CAT = CAT, HS = HS, IDLE = IDLE, ST = ST,
  headless = headless, music = music, night = night, shelf = shelf, shows = shows, tv = tv})

-- ------------------------------------------------------------------ the frame

local last_letters = 0
-- the hitch and frames lines: diag.lua (HOME_REFACTOR.md CP5)
local DIAG = require("diag")
DIAG.init({ST = ST, log = log, music = music})
local FIXED_DT = tonumber(os.getenv("HOME_DT") or "")   -- tests: every frame this long (PC renders of the shows)
-- What a frame did that can take time (SYSTEM_AUDIT.md B2): the loaders note it (home_note, a global so the
-- modules reach it), and a hitch is logged with the notes of the frame it happened in. Home's log had stalls of
-- 5 to 46 s with nothing saying what was being done.
ST.notes = {}
function home_note(s)
  local n = ST.notes
  if #n < 10 then n[#n + 1] = s end
end
function love.update(dt)
  local u0 = love.timer.getTime()
  if FIXED_DT then dt = FIXED_DT end
  DIAG.frame(dt)
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
  HS.drain_worker()
  for _, c in ipairs(I.script) do
    if c[1] == ST.frame then
      if c[2] == "press" then I.control_down(c[3]) I.control_up(c[3])
      elseif c[2] == "down" then I.control_down(c[3])
      elseif c[2] == "up" then I.control_up(c[3])
      elseif c[2] == "shot" then ST.shot_req = c[3]
      elseif c[2] == "quit" then love.event.quit(0) end
    end
  end
  local h0 = love.timer.getTime()
  for _, n in ipairs(I.pressed_q) do IDLE.handle(n) end
  I.pressed_q = {}
  DIAG.slow("input", h0)
  ST.wake_step(dt)
  h0 = love.timer.getTime()
  if not ST.menu_freed then HS.manage_labels(false) end
  DIAG.slow("card labels", h0)
  if CAT.PREVIEW and I.down["1p"] and I.down["2p"] and not ST.launch_item then
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
    if ST.intro_t > MENU.INTRO_LEN then ST.go("menu") ST.menu_in = 0.45 end
  end
  TICK.update_idle(dt)
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
  h0 = love.timer.getTime()
  if ST.scene ~= "hall" then ST.near_shots() end
  DIAG.slow("card pictures", h0)
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
  DIAG.slow("update", u0)
end

local first_drawn = false
function love.draw()
  local d0 = love.timer.getTime()
  D.painted = 0
  -- Labels still to paint: two a frame, before anything is drawn on the screen
  -- (three behind the waking cover, where a long frame shows nothing moving)
  for _ = 1, ST.wake and ST.wake.phase == "cover" and 3 or 2 do
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
      if ST.TRACE then HS.trace("shot", ST.shot_req) end
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
  if D.painted > 0 then DIAG.slow("draw (" .. D.painted .. " labels painted)", d0) else DIAG.slow("draw", d0) end
end
