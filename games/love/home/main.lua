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

local lg = love.graphics
local sound = require("sound")
local fx = require("fx")
local splash = require("splash")

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
local DEEP_SLEEP = tonumber(os.getenv("HOME_DEEP") or "") or 900    -- seconds into the night scene
local HORIZON = 760

local function log(...)
  local s = table.concat({...}, " ")
  if LOGF then
    local f = io.open(LOGF, "a")
    if f then f:write(string.format("%.2f %s\n", love.timer.getTime(), s)) f:close() end
  else
    print(s)
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
-- stat: the save key The Yard shows, and how (games/carts/*/info.lua).
local OURS = {
  {id = "keep", title = "KEEP", tint = 0xff7a59, blurb = "Catch the falling fruit.", stat = {"best", "BEST %d"}},
  {id = "lamp", title = "LAMP", tint = 0xffc94a, blurb = "Wake the sleeping stars.", stat = {"best", "%d NIGHTS", "1 NIGHT"}},
  {id = "orb", title = "ORB", tint = 0xa98bff, blurb = "Dive down the glowing well.", native = "orb", stat = {"best", "BEST %d"}},
  {id = "tea", title = "TEA", tint = 0xff9ccf, blurb = "Tea with the cats.", stat = {"visits", "%d VISITS", "1 VISIT"}},
  {id = "chest", title = "CHEST", tint = 0x7fd6a0, blurb = "The key, the chest, Zam.", stat = {"gems", "%d GEMS", "1 GEM"}},
}
local SECTIONS = {
  {name = "CLASSICS", tint = 0xffd23f},
  {name = "THE YARD", tint = 0x6ef0c8},
  {name = "MORE", tint = 0x8ab4ff},
}
-- How to come back to Home from each kind of game (said on the info panel and on the "get ready" picture).
local LEAVE = {
  classic = {"HOLD  1-PLAYER  FOR 5 SECONDS", "to come back to Home (your high score is saved)"},
  cart = {"HOLD  1-PLAYER + 2-PLAYER", "to come back to Home"},
  native = {"HOLD  1-PLAYER + 2-PLAYER", "to come back to Home"},
  yard = {"HOLD  1-PLAYER + 2-PLAYER", "to come back to Home"},
}

local PREVIEW = os.getenv("HOME_MODE") == "preview"
local items = {}
for i, c in ipairs(CLASSICS) do
  items[#items + 1] = {kind = "classic", index = i - 1, section = 1, title = c.title,
                       sub = c.year .. "  NAMCO", blurb = c.blurb, tint = c.tint}
end
for _, g in ipairs(OURS) do
  items[#items + 1] = {kind = g.native and "native" or "cart", id = g.id, native = g.native, section = 2,
                       title = g.title, sub = "THE YARD", blurb = g.blurb, tint = g.tint, statdef = g.stat}
end
-- HOME_MODE=preview (opened from a Yard row to try Home): the last card goes back to The Yard.
if PREVIEW then
  items[#items + 1] = {kind = "stock", section = 3, title = "BACK TO THE YARD", sub = "HOME PREVIEW",
                       blurb = "Home is a preview for now: this goes back to The Yard.", tint = 0xff9c5a}
else
  items[#items + 1] = {kind = "yard", section = 3, title = "YARD MENU", sub = "THE WHOLE YARD",
                       blurb = "Every Yard game, in its own menu.", tint = 0x7fe8ff}
  items[#items + 1] = {kind = "stock", section = 3, title = "ORIGINAL MENU", sub = "ARCADE1UP",
                       blurb = "The menu as it came. On it, hold 1-PLAYER + 2-PLAYER to come back.", tint = 0xff9c5a}
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
local function font(px)
  if not fonts[px] then
    fonts[px] = font_data and lg.newFont(font_data, px) or lg.newFont(px)
  end
  return fonts[px]
end

-- Text with a neon glow: soft additive copies around it, then the text.
local function neon(s, x, y, px, c, glow, align, width)
  local f = font(px)
  lg.setFont(f)
  local r, g, b = rgb(c)
  glow = glow or 1
  if glow > 0 then
    lg.setBlendMode("add")
    for _, o in ipairs({{3, 0.10}, {6, 0.06}}) do
      local d, a = o[1], o[2] * glow
      lg.setColor(r, g, b, a)
      for k = 0, 7 do
        local ang = k * math.pi / 4
        lg.printf(s, x + math.cos(ang) * d, y + math.sin(ang) * d, width or W, align or "center")
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
  local key = s .. "|" .. px .. "|" .. c .. "|" .. (glow or 1)
  local e = neon_cache[key]
  if e then return e end
  local f = font(px)
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
  lg.draw(e.img, x + dx - e.pad * sc, y - e.pad * sc, 0, sc, sc)
  lg.setBlendMode("alpha")
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
local scene = "intro"           -- intro, menu, attract, night
local intro_t = 0
local idle = 0
local attract_t = 0
local launch_t, launch_item = 0, nil
local note, note_t = nil, 0
local stars = {}
local direct = not headless and os.getenv("HOME_CANVAS") ~= "1"
local canvas
local shot_req
local vol_level, vol_t, vol_read = nil, 0, nil
local night_t = 0
local menu_in = 0                 -- the menu fading in after the intro (seconds left)
local attract_sel                 -- the card before the attract tour: given back on waking
local returning = false           -- Home started again after a game (not at power-on)
local celebrate                   -- {score, title, tint, t}: back from a classic with a new high score
local party = 0                   -- party mode (the secret code): seconds left
local code_buf = {}
local CODE = {"up", "up", "down", "down", "left", "right", "left", "right", "tl", "low"}
local last_played                 -- the card of the last game played (state file)

local function load_state()
  local s = STATE and read_file(STATE)
  local n = s and tonumber(s:match("sel (%d+)"))
  if n and items[n] then sel, pos = n, n end
  local lp = s and tonumber(s:match("played (%d+)"))
  if lp and items[lp] then last_played = items[lp] end
  -- At power-on, never on the original menu's card (the last choice made before the power went off).
  if os.getenv("HOME_INTRO") == "1" and items[sel].kind == "stock" then sel, pos = 1, 1 end
  return s and s:match("returned (.+)")
end
local function save_state(extra, played)
  if not STATE then return end
  local lp = played
  if not lp and last_played then
    for k, it in ipairs(items) do if it == last_played then lp = k end end
  end
  local f = io.open(STATE, "w")
  if f then f:write("sel " .. sel .. "\n" .. (lp and ("played " .. lp .. "\n") or "") .. (extra or "")) f:close() end
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
local function draw_background(dim)
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

local function draw_marquee(alpha_k)
  -- A neon sign: now and then a tube stutters.
  -- A steady sign that breathes very slowly (the old tube stutter felt like a strobe light to the user).
  local flick = 0.92 + 0.08 * math.sin(t * 0.8)
  lg.setColor(1, 1, 1, 1)
  neon_draw("PARTYCADE", 0, 34, 92, 0xff4fd8, 1.6, "center", W, flick * (alpha_k or 1))
  neon_draw("HOME", 0, 132, 26, 0x6ef0c8, 0.8, "center", W, alpha_k)
end

local function draw_tabs(cur)
  local x = 84
  for i, s in ipairs(SECTIONS) do
    local on = i == cur
    lg.setFont(font(22))
    local w = font(22):getWidth(s.name) + 30
    local r, g, b = rgb(s.tint)
    if on then
      lg.setColor(r, g, b, 0.25)
      rrect("fill", x, 176, w, 36, 18)
      lg.setColor(r, g, b, 1)
      lg.setLineWidth(2)
      rrect("line", x, 176, w, 36, 18)
    end
    lg.setColor(r, g, b, on and 1 or 0.45)
    lg.print(s.name, x + 15, 182)
    x = x + w + 26
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
      alpha = alpha * math.max(0, math.min(1, (cy - cw * 0.29 - 200) / 70))
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
  lg.setFont(font(20))
  lg.setColor(0.75, 0.7, 0.95, 1)
  lg.printf(it.sub, 60, y + 72, W - 120, "left")
  if it.score or it.stat then
    lg.setFont(font(22))
    lg.setColor(1, 0.85, 0.3, 1)
    lg.printf(it.score and ("HIGH SCORE  " .. it.score) or it.stat, 60, y + 22, W - 120, "right")
  end
  lg.setFont(font(24))
  lg.setColor(0.95, 0.93, 1, 1)
  lg.printf(it.blurb, 60, y + 100, W - 120, "left")
  if it.kind == "classic" then
    local i = it.index + 1
    local chips = {{"SPEED", speed[i] == 1 and "FAST" or "NORMAL"}, {"SMOOTH", smooth[i] == 1 and "ON" or "OFF"}}
    local x = 60
    for _, c in ipairs(chips) do
      lg.setFont(font(19))
      local s = c[1] .. "  " .. c[2]
      local w = font(19):getWidth(s) + 26
      lg.setColor(1, 0.85, 0.3, 0.18)
      rrect("fill", x, y + 146, w, 32, 16)
      lg.setColor(1, 0.85, 0.3, 1)
      rrect("line", x, y + 146, w, 32, 16)
      lg.print(s, x + 13, y + 151)
      x = x + w + 14
    end
    lg.setColor(0.7, 0.65, 0.9, 0.9)
    lg.setFont(font(16))
    lg.print("top buttons change", x + 4, y + 155)
  end
end

local function draw_hint(s, y, alpha)
  lg.setFont(font(20))
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
  lg.setColor(0, 0, 0.02, 0.45)
  lg.rectangle("fill", 0, 0, W, H)
  -- The sign asleep: it breathes, slowly.
  local breath = 0.3 + 0.12 * math.sin(night_t * 1.1)
  fx.glow(W / 2, 80, 330, 60, 1, 0.3, 0.85, breath * 0.25)
  neon_draw("PARTYCADE", 0, 34, 92, 0xff4fd8, 1.6, "center", W, breath)
  -- A moon, and z's drifting up from the sign.
  fx.glow(620, 300, 90, 90, 0.8, 0.85, 1, 0.18)
  lg.setColor(0.95, 0.93, 0.8, 0.9)
  lg.circle("fill", 620, 300, 34, 40)
  lg.setColor(0.07, 0.03, 0.14, 1)
  lg.circle("fill", 634, 292, 30, 40)
  for i = 0, 2 do
    local k = ((night_t * 0.3) + i / 3) % 1
    local zx, zy = W / 2 + 260 + k * 60 + math.sin(k * 6) * 10, 120 - k * 110
    lg.setFont(font(math.floor(30 + k * 26)))
    lg.setColor(0.43, 0.94, 0.78, math.sin(k * math.pi) * 0.85)
    lg.print("z", zx, zy)
  end
  fx.draw_chase(night_t, HORIZON - 26, 1)
  draw_hint("press any button", 930, 0.35 + 0.25 * math.sin(t * 2))
  -- Deep sleep (15 minutes into the night): nearly black, only the sign breathing faintly; kind to the panel
  -- when the cabinet is left on.
  local deep = math.max(0, math.min(1, (night_t - DEEP_SLEEP) / 20))
  if deep > 0 then
    lg.setColor(0, 0, 0, 0.93 * deep)
    lg.rectangle("fill", 0, 0, W, H)
    neon_draw("PARTYCADE", 0, 34, 92, 0xff4fd8, 1.6, "center", W, deep * (0.08 + 0.06 * math.sin(night_t * 0.7)))
  end
end

-- The sign, unlit: the tubes dark, as on the power-on picture.
local SIGN_Y, SIGN_PX = 400, 104
local function sign_x()
  return math.floor((W - font(SIGN_PX):getWidth("PARTYCADE")) / 2)
end
local function draw_unlit_sign(a)
  lg.setFont(font(SIGN_PX))
  lg.setColor(0.32, 0.1, 0.3, a or 1)
  lg.print("PARTYCADE", sign_x(), SIGN_Y)
end

-- Power-on: the unlit sign lights letter by letter where it stands (with a stutter), "ARCADE HOME" comes
-- on, then the sign glides up into the marquee while the menu fades in (draw_scene's menu_in).
local INTRO_LEN = 2.6
local function draw_intro()
  local word = "PARTYCADE"
  if intro_t < 1.9 then
    local k = math.min(1, intro_t / 1.2)
    local n = math.floor(k * #word + 0.001)
    draw_unlit_sign()
    fx.glow(W / 2, SIGN_Y + 60, 380, 120, 1, 0.3, 0.85, 0.15 * k)
    if n > 0 then neon(word:sub(1, n), sign_x(), SIGN_Y, SIGN_PX, 0xff4fd8, 1.8, "left", W) end
    if intro_t > 1.3 then
      local a = math.min(1, (intro_t - 1.3) / 0.4)
      neon("ARCADE  HOME", 0, 530, 34, 0x6ef0c8, a)
    end
  else
    -- The glide: from the middle (104 px) to the marquee (92 px, y 34), easing out.
    local k = math.min(1, (intro_t - 1.9) / (INTRO_LEN - 1.9))
    local e = 1 - (1 - k) ^ 3
    local y = SIGN_Y + (34 - SIGN_Y) * e
    local sc = (SIGN_PX + (92 - SIGN_PX) * e) / 92
    fx.glow(W / 2, y + 60 * sc, 380, 120, 1, 0.3, 0.85, 0.15 * (1 - e))
    neon_draw("PARTYCADE", 0, y, 92, 0xff4fd8, 1.6, "center", W, 1, sc)
    if e < 1 then
      neon_draw("ARCADE  HOME", 0, 530 - 400 * e, 34, 0x6ef0c8, 0.8, "center", W, 1 - e)
    end
  end
end

local function draw_scene()
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
      draw_hint("12 CLASSICS  +  THE YARD", 930, 0.9)
    end
  else
    draw_info()
    draw_footer()
  end
  if menu_in > 0 then
    -- After the intro: the menu comes up under the sign.
    lg.setColor(0.02, 0.0, 0.05, menu_in / 0.45)
    lg.rectangle("fill", 0, 120, W, H - 120)
  end
  draw_volume()
  draw_celebration()
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
  neon_draw("PARTYCADE", 0, 34, 92, 0xff4fd8, 1.6, "center", W)
end

-- "Get ready": the game's logo (or name) big, and how to come back.
local function picture_launch(it)
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
  neon_draw("HOME", 0, 132, 26, 0x6ef0c8, 0.8, "center", W)
  draw_tabs(items[sel].section)
end

-- Power-on: the sign, warming up.
local function picture_boot()
  draw_background(0)
  draw_unlit_sign()
  lg.setFont(font(26))
  lg.setColor(0.85, 0.8, 1, 0.75)
  lg.printf("warming up the neon...", 0, 545, W, "center")
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

local function request(s, it)
  if it and (not headless or os.getenv("HOME_FB")) then pictures_for(it) end
  log("launch " .. s)
  -- The classic's high score as it was: on the way back, a higher one is celebrated.
  local played = nil
  if it and it.kind ~= "stock" then played = sel end
  save_state(it and it.kind == "classic" and ("score " .. it.index .. " " .. (high_score(it.index) or 0) .. "\n") or nil,
             played)
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
  if scene == "night" then
    -- The first press only wakes it.
    scene = "menu"
    if attract_sel then sel, pos = attract_sel, attract_sel end
    play("wake")
    if sound.music then sound.music:setVolume(0.55) end
    return
  end
  if launch_item then return end
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
  elseif name == "low" or name == "1p" then
    launch_item = it
    launch_t = 0
    play("launch")
  end
end

-- ------------------------------------------------------------------ the loop

function love.load()
  mark("love.load")
  love.mouse.setVisible(false)
  local fd = love.filesystem.getInfo("fonts/Fredoka-SemiBold.ttf") and love.filesystem.newFileData("fonts/Fredoka-SemiBold.ttf")
  font_data = fd
  math.randomseed(RENDER and 1 or os.time())   -- the PC-rendered picture is the same every build
  for i = 1, 90 do
    stars[i] = {math.random() * W, math.random() * 700, math.random() * 6, 0.5 + math.random() * 2,
                0.4 + math.random() * 0.6, math.random() < 0.15 and 3 or 2}
  end
  fx.load()
  if RENDER then
    -- Render a picture and quit (the PC build of the power-on picture): "boot:PATH".
    local kind, path = RENDER:match("^(%a+):(.+)$")
    local bytes = splash.render(kind == "back" and picture_back or picture_boot)
    splash.save(bytes, path, path:match("%.gz$") ~= nil)
    love.event.quit(0)
    return
  end
  load_state()
  if love.thread then
    worker = love.thread.newThread("worker.lua")
    worker:start()
    if not headless then love.thread.getChannel("home_work"):push({"music"}) end
  end
  load_art()
  mark("art")
  -- The labels in view now; the rest a few a frame, before the frame's drawing starts (see neon_img).
  neon_img("PARTYCADE", 92, 0xff4fd8, 1.6)
  neon_img("HOME", 26, 0x6ef0c8, 0.8)
  if scene == "intro" or os.getenv("HOME_INTRO") == "1" then neon_img("ARCADE  HOME", 34, 0x6ef0c8, 0.8) end
  for k, it in ipairs(items) do
    local job = function() neon_img(it.title, 64, it.tint, 1.2) neon_img(it.title, 44, it.tint, 0.9) end
    if math.abs(k - sel) <= 2 then job() else label_jobs[#label_jobs + 1] = job end
  end
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
  return false
end

local fps_t, fps_n = 0, 0
local last_letters = 0
function love.update(dt)
  fps_t, fps_n = fps_t + dt, fps_n + 1
  if fps_n == 300 then
    log(string.format("frames: %.1f fps (%.2f ms), scene %s", fps_n / fps_t, fps_t / fps_n * 1000, scene))
    fps_t, fps_n = 0, 0
  end
  dt = math.min(dt, 0.1)
  t = t + dt
  frame = frame + 1
  -- The music, made once the first frames are up (its 17 s of samples are the one slow thing to make).
  if worker then
    local msg = love.thread.getChannel("home_done"):pop()
    while msg do
      if msg[1] == "art" and msg[3] then items[msg[2]].art = art_image(msg[3])
      elseif msg[1] == "music" and not headless then
        sound.music_from(msg[2], scene == "night" and 0.12 or 0.55):play()
        log("music ready")
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
  if PREVIEW and down["1p"] and down["2p"] and not launch_item then
    hold_t = hold_t + dt
    idle = 0
    if hold_t >= HOLD_SECS then hold_t = 0 request("yard") end
  else
    hold_t = 0
  end
  if scene == "intro" then
    intro_t = intro_t + dt
    local letters = math.floor(math.min(1, intro_t / 1.2) * 9 + 0.001)
    if letters > last_letters then last_letters = letters play("tick") end
    if intro_t > INTRO_LEN then scene = "menu" menu_in = 0.45 end
  end
  idle = idle + dt
  if scene == "menu" and idle > IDLE_ATTRACT then scene = "attract" attract_t = 0 attract_sel = sel end
  if scene == "attract" then
    attract_t = attract_t + dt
    if attract_t > 3.5 then attract_t = 0 sel = sel % #items + 1 end
    if idle > IDLE_NIGHT then
      scene = "night"
      night_t = 0
      if sound.music then sound.music:setVolume(0.12) end
    end
  end
  if scene == "night" then
    night_t = night_t + dt
    if sound.music and night_t > DEEP_SLEEP then sound.music:setVolume(0.12 * math.max(0, 1 - (night_t - DEEP_SLEEP) / 20)) end
  end
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
      canvas:newImageData():encode("png", "shot.png")
      local d = read_file(love.filesystem.getSaveDirectory() .. "/shot.png")
      local f = d and io.open(shot_req, "wb")
      if f then f:write(d) f:close() end
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
