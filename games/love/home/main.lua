-- Partycade Home: the front end. Neon arcade: a dark sky over a synthwave grid, a glowing marquee, and a
-- carousel of every game on the cabinet: the twelve classics (with their own logos, cut from the stock menu's
-- pictures by tools/home_art.py), our games, and the way to the original menu.
--
-- Home never runs a game itself. It writes what to run into HOME_REQ and quits; homeloop.sh runs it with the
-- whole machine and starts Home again, on the same card. Requests:
--   classic <index> <smoothing 0|1> <speed 0|1>    a stock emulator, as the stock menu's start.sh would
--   cart <id>                                      one of our games, on the GPU runtime
--   native <name>                                  a program in /data/Games (Orb)
--   yard                                           GPU yard, the whole Yard menu
--   stock                                          the original menu
-- The classics' speed and smoothing are the stock menu's own settings (Speed.cfg, Smoothing.cfg: a byte per game).

local lg = love.graphics
local W, H = 768, 1024                       -- the upright picture; the panel shows the framebuffer turned
local headless = os.getenv("HOME_HEADLESS") == "1"
local ART = os.getenv("HOME_ART") or "/data/home/art"
local GAMES = os.getenv("HOME_GAMES") or "/data/Games"
local REQ = os.getenv("HOME_REQ")
local STATE = os.getenv("HOME_STATE")
local LOGF = os.getenv("HOME_LOG")
local IDLE_ATTRACT = tonumber(os.getenv("HOME_IDLE") or "") or 45   -- seconds without a press

local function log(...)
  local s = table.concat({...}, " ")
  if LOGF then
    local f = io.open(LOGF, "a")
    if f then f:write(string.format("%.2f %s\n", love.timer.getTime(), s)) f:close() end
  else
    print(s)
  end
end

local function read_file(path)
  local f = io.open(path, "rb")
  if not f then return nil end
  local s = f:read("*a")
  f:close()
  return s
end

-- ------------------------------------------------------------------ the games

local CLASSICS = {
  {title = "PAC-MAN", year = 1980, blurb = "Eat the dots. Mind the ghosts."},
  {title = "PAC & PAL", year = 1983, blurb = "Flip the cards, find the treats."},
  {title = "SUPER PAC-MAN", year = 1982, blurb = "Keys, doors, and a super-size power pellet."},
  {title = "PAC-MAN PLUS", year = 1982, blurb = "Pac-Man, with tricks in the maze."},
  {title = "PAC-LAND", year = 1984, blurb = "Run the whole town back to Fairyland."},
  {title = "PAC-MANIA", year = 1987, blurb = "Jump the ghosts in rolling 3-D mazes."},
  {title = "GALAGA", year = 1981, blurb = "Win your captured fighter back. Fly two."},
  {title = "GALAXIAN", year = 1979, blurb = "The swarm dives. Stay sharp."},
  {title = "MAPPY", year = 1983, blurb = "A police mouse, a mansion, trampolines."},
  {title = "DIG DUG", year = 1982, blurb = "Dig, pump, and drop the rocks."},
  {title = "DIG DUG II", year = 1985, blurb = "Sink the island under the monsters."},
  {title = "ROMPERS", year = 1989, blurb = "Push the walls down on the monsters."},
}
local OURS = {
  {id = "keep", title = "KEEP", tint = 0xff7a59, blurb = "Catch the falling fruit."},
  {id = "lamp", title = "LAMP", tint = 0xffc94a, blurb = "Wake the sleeping stars."},
  {id = "orb", title = "ORB", tint = 0xa98bff, blurb = "Dive down the glowing well.", native = "orb"},
  {id = "tea", title = "TEA", tint = 0xff9ccf, blurb = "Tea with the cats."},
  {id = "chest", title = "CHEST", tint = 0x7fd6a0, blurb = "The key, the chest, Zam."},
}
local SECTIONS = {
  {name = "CLASSICS", tint = 0xffd23f},
  {name = "THE YARD", tint = 0x6ef0c8},
  {name = "MORE", tint = 0x8ab4ff},
}

local items = {}
for i, c in ipairs(CLASSICS) do
  items[#items + 1] = {kind = "classic", index = i - 1, section = 1, title = c.title,
                       sub = c.year .. "  NAMCO", blurb = c.blurb, tint = 0xffd23f}
end
for _, g in ipairs(OURS) do
  items[#items + 1] = {kind = g.native and "native" or "cart", id = g.id, native = g.native, section = 2,
                       title = g.title, sub = "THE YARD", blurb = g.blurb, tint = g.tint}
end
-- HOME_MODE=preview (opened from a Yard row to try Home): the last card goes back to The Yard.
if os.getenv("HOME_MODE") == "preview" then
  items[#items + 1] = {kind = "stock", section = 3, title = "BACK TO THE YARD", sub = "HOME PREVIEW",
                       blurb = "Home is a preview for now: this goes back to The Yard.", tint = 0xff9c5a}
else
  items[#items + 1] = {kind = "yard", section = 3, title = "GPU YARD", sub = "THE WHOLE YARD",
                       blurb = "Every Yard game, in its own menu.", tint = 0x7fe8ff}
  items[#items + 1] = {kind = "stock", section = 3, title = "ORIGINAL MENU", sub = "ARCADE1UP",
                       blurb = "The cabinet's menu, as it came. Home is back at the next power-on.", tint = 0xff9c5a}
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
  lg.setColor(1, 1, 1, 1)
  lg.setColor(r * 0.35 + 0.65, g * 0.35 + 0.65, b * 0.35 + 0.65, 1)   -- the hot white core of a neon tube
  lg.printf(s, x, y, width or W, align or "center")
end

local function rrect(mode, x, y, w, h, r) lg.rectangle(mode, x, y, w, h, r, r, 16) end

-- Neon labels painted once into a picture (glow included): drawing one is a single quad. Live neon() was 17
-- prints a label, and Home ran at 48-55 fps on the cabinet (2026-10-27). All are painted in love.load, before
-- the first frame (a canvas switch mid-frame is costly on the Mali).
local neon_cache = {}
local function neon_img(s, px, c, glow)
  local key = s .. "|" .. px .. "|" .. c .. "|" .. (glow or 1)
  local e = neon_cache[key]
  if e then return e end
  local f = font(px)
  local pad = 10
  local cw, ch = f:getWidth(s) + pad * 2, f:getHeight() + pad * 2
  local cv = lg.newCanvas(math.max(1, cw), math.max(1, ch))
  lg.push("all")
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

-- ------------------------------------------------------------------ sound: a tiny chiptune synth

local RATE = 22050
local function note_hz(n) return 440 * 2 ^ ((n - 69) / 12) end
local function synth(notes, dur, wave, vol)
  -- notes: {{midi, start_s, len_s}, ...}; square or triangle, a short attack and a decay.
  local n = math.floor(dur * RATE)
  local sd = love.sound.newSoundData(n, RATE, 16, 1)
  local buf = {}
  for i = 0, n - 1 do buf[i] = 0 end
  for _, nt in ipairs(notes) do
    local hz, s0, len = note_hz(nt[1]), math.floor(nt[2] * RATE), math.floor(nt[3] * RATE)
    local per = RATE / hz
    for i = 0, len - 1 do
      local k = s0 + i
      if k >= n then break end
      local ph = (i % per) / per
      local v
      if (nt[4] or wave) == "tri" then v = ph < 0.5 and (ph * 4 - 1) or (3 - ph * 4) else v = ph < 0.5 and 1 or -1 end
      local env = math.min(1, i / 200) * (1 - i / len) ^ 1.6
      buf[k] = buf[k] + v * env * (nt[5] or vol)
    end
  end
  for i = 0, n - 1 do sd:setSample(i, math.max(-1, math.min(1, buf[i]))) end
  return love.audio.newSource(sd, "static")
end
local sfx = {}
local music
local function make_sounds()
  sfx.move = synth({{84, 0, 0.05}}, 0.06, "sq", 0.12)
  sfx.section = synth({{79, 0, 0.05}, {86, 0.05, 0.07}}, 0.13, "sq", 0.12)
  sfx.toggle = synth({{76, 0, 0.04}, {72, 0.04, 0.06}}, 0.11, "sq", 0.12)
  sfx.launch = synth({{72, 0, 0.08}, {76, 0.07, 0.08}, {79, 0.14, 0.08}, {84, 0.21, 0.30}}, 0.55, "sq", 0.14)
  -- The intro sting: an arpeggio up to a held chord.
  sfx.intro = synth({{60, 0, 0.12}, {64, 0.1, 0.12}, {67, 0.2, 0.12}, {72, 0.3, 0.12}, {76, 0.4, 0.12},
                     {79, 0.5, 0.9}, {72, 0.5, 0.9, "tri", 0.18}, {48, 0.5, 0.9, "tri", 0.22}}, 1.5, "sq", 0.11)
  -- Menu music: eight soft bars, bass and an arpeggio, looping.
  local notes, beat = {}, 60 / 112
  local prog = {{45, 57, 60, 64}, {41, 53, 57, 60}, {43, 55, 59, 62}, {40, 52, 55, 59}}
  for bar = 0, 7 do
    local ch = prog[bar % 4 + 1]
    for b8 = 0, 7 do
      local t = (bar * 8 + b8) * beat / 2
      if b8 % 2 == 0 then notes[#notes + 1] = {ch[1], t, beat * 0.45, "tri", 0.16} end
      notes[#notes + 1] = {ch[2 + b8 % 3] + 12, t, beat * 0.4, "sq", 0.035}
    end
  end
  music = synth(notes, 8 * 4 * beat, "sq", 0.04)
  music:setLooping(true)
  music:setVolume(0.55)
end
local function play(name)
  local s = sfx[name]
  if s then s:stop() s:play() end
end

-- ------------------------------------------------------------------ input

-- The cabinet's deck through SDL (games/love/yard/input.lua has the same map), and keys on a PC.
local JOY = {[1] = "low", [2] = "tl", [4] = "tr", [7] = "1p", [8] = "2p", [16] = "up", [17] = "left", [18] = "right",
             [19] = "down"}
local KEYS = {up = "up", down = "down", left = "left", right = "right", z = "low", x = "tl", c = "tr",
              ["1"] = "1p", ["2"] = "2p", ["return"] = "low", space = "low"}
local pressed_q = {}
local function press(name) pressed_q[#pressed_q + 1] = name end
function love.joystickpressed(_, b) if JOY[b] then press(JOY[b]) end end
function love.keypressed(k)
  if k == "escape" then love.event.quit(0) end
  if KEYS[k] then press(KEYS[k]) end
end

-- HOME_SCRIPT (tests): lines "<frame> press NAME", "<frame> shot PATH", "<frame> quit".
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
local scene = "intro"
local intro_t = 0
local idle = 0
local attract_t = 0
local launch_t, launch_item = 0, nil
local note, note_t = nil, 0
local art = {}
local stars = {}
local direct = not headless and os.getenv("HOME_CANVAS") ~= "1"
local canvas
local shot_req

local function load_state()
  local s = STATE and read_file(STATE)
  local n = s and tonumber(s:match("sel (%d+)"))
  if n and items[n] then sel, pos = n, n end
  return s and s:match("returned (.+)")
end
local function save_state(extra)
  if not STATE then return end
  local f = io.open(STATE, "w")
  if f then f:write("sel " .. sel .. "\n" .. (extra or "")) f:close() end
end

local function load_art()
  for _, it in ipairs(items) do
    if it.kind == "classic" then
      -- The classics' logos: cut from the stock menu by tools/home_art.py, on the cabinet only.
      local b = read_file(ART .. "/classic_" .. it.index .. ".png")
      if b then
        local ok, img = pcall(lg.newImage, love.filesystem.newFileData(b, "c.png"))
        if ok then img:setFilter("linear", "linear") it.art = img end
      end
    elseif it.id and love.filesystem.getInfo("art/" .. it.id .. ".png") then
      -- Our games: a frame of the game itself (cart shots), packed into home.love.
      it.shot = lg.newImage("art/" .. it.id .. ".png")
      it.shot:setFilter("linear", "linear")
    end
  end
end

-- ------------------------------------------------------------------ drawing

local function draw_background()
  -- The sky: deep violet to black, a slow color drift.
  local drift = math.sin(t * 0.07) * 0.5 + 0.5
  local top = {0.05 + 0.03 * drift, 0.02, 0.12 + 0.04 * (1 - drift)}
  local mid = {0.20, 0.03 + 0.03 * drift, 0.28}
  lg.setColor(1, 1, 1, 1)
  local m = lg.newMesh({{0, 0, 0, 0, top[1], top[2], top[3], 1}, {W, 0, 0, 0, top[1], top[2], top[3], 1},
                        {W, 760, 0, 0, mid[1], mid[2], mid[3], 1}, {0, 760, 0, 0, mid[1], mid[2], mid[3], 1}},
                       "fan", "stream")
  lg.draw(m)
  m:release()
  lg.setColor(0.02, 0.0, 0.05, 1)
  lg.rectangle("fill", 0, 760, W, H - 760)
  -- Stars.
  for _, s in ipairs(stars) do
    local tw = 0.45 + 0.55 * math.abs(math.sin(t * s[4] + s[3]))
    lg.setColor(1, 0.9, 1, tw * s[5])
    lg.rectangle("fill", s[1], s[2], s[6], s[6])
  end
  -- The sun on the horizon, striped.
  local cx, cy, r = W / 2, 760, 150
  for i = 0, 14 do
    local y0 = cy - r + i * 11
    local k = i / 14
    if y0 < cy then
      local hw = math.sqrt(math.max(0, r * r - (cy - y0 - 4) ^ 2))
      lg.setColor(1, 0.35 + 0.45 * (1 - k), 0.35 + 0.25 * k, 0.55)
      lg.rectangle("fill", cx - hw, y0, hw * 2, 11 - k * 6)
    end
  end
  -- The grid floor, rushing toward us.
  lg.setLineWidth(2)
  for i = -12, 12 do
    lg.setColor(1, 0.2, 0.75, 0.55)
    lg.line(W / 2 + i * 22, 760, W / 2 + i * 150, H)
  end
  local scroll = (t * 0.8) % 1
  for i = 0, 9 do
    local k = (i + scroll) / 10
    local y = 760 + (H - 760) * k * k
    lg.setColor(1, 0.25, 0.8, 0.15 + 0.6 * k)
    lg.line(0, y, W, y)
  end
  lg.setColor(1, 0.4, 0.9, 0.8)
  lg.line(0, 760, W, 760)
end

local function draw_marquee(alpha_k)
  local flick = (math.sin(t * 13) > 0.97) and 0.6 or 1
  lg.setColor(1, 1, 1, 1)
  neon_draw("PARTYCADE", 0, 34, 92, 0xff4fd8, 1.6, "center", W, flick * (alpha_k or 1))
  neon_draw("HOME", 0, 132, 26, 0x6ef0c8, 0.8, "center", W)
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
  lg.setColor(0.07, 0.03, 0.14, 0.88 * alpha)
  rrect("fill", x, y, cw, ch, 22)
  if it.art then
    local iw, ih = it.art:getDimensions()
    local s = math.min((cw - 24) / iw, (ch - 24) / ih)
    lg.setColor(1, 1, 1, alpha)
    lg.draw(it.art, cx, cy, 0, s, s, iw / 2, ih / 2)
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
    neon_draw(it.title, tx, cy - px * 0.75, 64, it.tint, 1.2, "center", x + cw - tx, alpha, px / 64)
    lg.setFont(font(math.max(12, math.floor(cw * 0.034))))
    lg.setColor(0.9, 0.88, 1, 0.85 * alpha)
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
    lg.setColor(0.9, 0.88, 1, 0.85 * alpha)
    lg.printf(it.blurb, tx + 8, cy + px * 0.55, x + cw - tx - 16, "center")
  else
    lg.setColor(1, 1, 1, alpha)
    local px = math.floor(cw * (#it.title > 9 and 0.11 or 0.15))
    neon_draw(it.title, x, cy - px * 0.62, 64, it.tint, 1.2, "center", cw, alpha, px / 64)
  end
  lg.setColor(r, g, b, (0.35 + 0.65 * focus) * alpha)
  lg.setLineWidth(focus > 0 and 3 or 2)
  rrect("line", x, y, cw, ch, 22)
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
      local alpha = math.max(0, 1 - a * 0.42) * math.min(1, (1.9 - a) * 2)
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
  lg.setColor(0.04, 0.0, 0.10, 0.82)
  rrect("fill", 40, y, W - 80, 196, 24)
  lg.setColor(rgb(it.tint, 0.8))
  lg.setLineWidth(2)
  rrect("line", 40, y, W - 80, 196, 24)
  neon_draw(it.title, 60, y + 14, 44, it.tint, 0.9, "left", W - 120)
  lg.setFont(font(20))
  lg.setColor(0.75, 0.7, 0.95, 1)
  lg.printf(it.sub, 60, y + 72, W - 120, "left")
  lg.setFont(font(24))
  lg.setColor(0.95, 0.93, 1, 1)
  lg.printf(it.blurb, 60, y + 100, W - 120, "left")
  if it.kind == "classic" then
    local i = it.index + 1
    local chips = {{"SPEED", speed[i] == 1 and "FAST" or "NORMAL", "LEFT TOP"}, {"SMOOTH", smooth[i] == 1 and "ON" or "OFF", "RIGHT TOP"}}
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

local function draw_hint(s, y, blink)
  local a = blink and (0.55 + 0.45 * math.sin(t * 5)) or 0.9
  lg.setFont(font(22))
  lg.setColor(0.85, 0.8, 1, a)
  lg.printf(s, 0, y, W, "center")
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

local function draw_scene()
  draw_background()
  if scene == "intro" then
    -- The marquee lights up letter by letter, with a stutter, then the menu fades in.
    local k = math.min(1, intro_t / 1.2)
    local word = "PARTYCADE"
    local n = math.floor(k * #word + 0.001)
    local shown = word:sub(1, n)
    if math.sin(intro_t * 40) > 0.6 and n < #word then shown = word:sub(1, math.max(0, n - 1)) end
    neon(shown, 0, 400, 104, 0xff4fd8, 1.8)
    if intro_t > 1.3 then
      local a = math.min(1, (intro_t - 1.3) / 0.4)
      lg.setColor(1, 1, 1, a)
      neon("ARCADE  HOME", 0, 530, 34, 0x6ef0c8, a)
    end
    return
  end
  draw_marquee()
  draw_tabs(items[sel].section)
  draw_carousel()
  if scene == "attract" then
    lg.setColor(0, 0, 0, 0.25)
    lg.rectangle("fill", 0, 780, W, H - 780)
    neon_draw("PRESS ANY BUTTON", 0, 860, 44, 0xffd23f, 1, "center", W, 0.6 + 0.4 * math.sin(t * 4))
    draw_hint("12 CLASSICS  +  THE YARD", 930, false)
  else
    draw_info()
    draw_hint("STICK  up/down choose  ·  left/right section  ·  LOWER BUTTON play", 1000 - 2, false)
  end
  draw_note()
  if launch_item then
    lg.setColor(1, 1, 1, math.max(0, math.min(1, (launch_t - 0.25) / 0.3)))
    lg.rectangle("fill", 0, 0, W, H)
  end
end

-- ------------------------------------------------------------------ actions

local function request(s)
  log("launch " .. s)
  save_state()
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

local function handle(name)
  idle = 0
  if scene == "intro" then
    scene = "menu"
    return
  end
  if scene == "attract" then
    scene = "menu"
    return
  end
  if launch_item then return end
  local it = items[sel]
  if name == "up" then move(-1)
  elseif name == "down" then move(1)
  elseif name == "left" then jump_section(-1)
  elseif name == "right" then jump_section(1)
  elseif (name == "tl" or name == "tr") and it.kind == "classic" then
    local i = it.index + 1
    if name == "tl" then speed[i] = 1 - speed[i] cfg_write("Speed.cfg", speed)
    else smooth[i] = 1 - smooth[i] cfg_write("Smoothing.cfg", smooth) end
    play("toggle")
  elseif name == "low" or name == "1p" then
    launch_item = it
    launch_t = 0
    play("launch")
  end
end

-- ------------------------------------------------------------------ the loop

function love.load()
  love.mouse.setVisible(false)
  local fd = love.filesystem.getInfo("fonts/Fredoka-SemiBold.ttf") and love.filesystem.newFileData("fonts/Fredoka-SemiBold.ttf")
  font_data = fd
  -- A black frame at once (the framebuffer showed white while loading, in GPU yard).
  if not headless then lg.clear(0, 0, 0, 1) lg.present() end
  math.randomseed(os.time())
  for i = 1, 90 do
    stars[i] = {math.random() * W, math.random() * 700, math.random() * 6, 0.5 + math.random() * 2,
                0.4 + math.random() * 0.6, math.random() < 0.15 and 3 or 2}
  end
  load_art()
  -- Paint every label now (see neon_img).
  neon_img("PARTYCADE", 92, 0xff4fd8, 1.6)
  neon_img("HOME", 26, 0x6ef0c8, 0.8)
  neon_img("PRESS ANY BUTTON", 44, 0xffd23f, 1)
  for _, it in ipairs(items) do
    neon_img(it.title, 64, it.tint, 1.2)
    neon_img(it.title, 44, it.tint, 0.9)
  end
  lg.setCanvas()
  make_sounds()
  local returned = load_state()
  if returned and returned:match("failed") then
    note, note_t = "That one didn't start. Pick another?", 4
  end
  if os.getenv("HOME_SKIP_INTRO") == "1" or (STATE and read_file(STATE)) then
    scene = "menu"       -- the intro is for power-on; coming back from a game goes straight to the menu
  else
    play("intro")
  end
  if not headless then music:play() end
  if headless or not direct then canvas = lg.newCanvas(W, H) end
  log("home start, " .. #items .. " items, scene " .. scene)
end

local fps_t, fps_n = 0, 0
function love.update(dt)
  fps_t, fps_n = fps_t + dt, fps_n + 1
  if fps_n == 300 then
    log(string.format("frames: %.1f fps (%.2f ms), scene %s", fps_n / fps_t, fps_t / fps_n * 1000, scene))
    fps_t, fps_n = 0, 0
  end
  dt = math.min(dt, 0.1)
  t = t + dt
  frame = frame + 1
  for _, c in ipairs(script) do
    if c[1] == frame then
      if c[2] == "press" then press(c[3])
      elseif c[2] == "shot" then shot_req = c[3]
      elseif c[2] == "quit" then love.event.quit(0) end
    end
  end
  for _, n in ipairs(pressed_q) do handle(n) end
  pressed_q = {}
  if scene == "intro" then
    intro_t = intro_t + dt
    if intro_t > 2.4 then scene = "menu" end
  end
  idle = idle + dt
  if scene == "menu" and idle > IDLE_ATTRACT then scene = "attract" attract_t = 0 end
  if scene == "attract" then
    attract_t = attract_t + dt
    if attract_t > 3.5 then attract_t = 0 sel = sel % #items + 1 end
  end
  pos = pos + (sel - pos) * math.min(1, dt * 11)
  if note then note_t = note_t - dt if note_t <= 0 then note = nil end end
  if launch_item then
    launch_t = launch_t + dt
    if launch_t > 0.6 then
      local s = launch(launch_item)
      launch_item = nil
      request(s)
    end
  end
end

function love.draw()
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
